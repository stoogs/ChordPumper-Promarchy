#!/usr/bin/env python3
"""Dependency-free audio and MIDI engine for ChordPumper Promarchy."""

from __future__ import annotations

import argparse
from array import array
from collections import deque
import json
import math
import os
import pwd
import queue
import re
import secrets
import signal
import stat
import struct
import subprocess
import sys
import threading
import time
from pathlib import Path

MAX_EVENTS = 4096
MAX_NOTES_PER_EVENT = 16
MAX_EVENTS_JSON_BYTES = 512 * 1024
MAX_CONTROL_LINE_BYTES = 4096
MAX_MIDI_BYTES = 4 * 1024 * 1024
MAX_SYNTH_LOG_LINES = 64
MAX_SYNTH_LOG_LINE_CHARS = 512
TRUSTED_FLUIDSYNTH = Path("/usr/bin/fluidsynth")
TRUSTED_PW_CAT = Path("/usr/bin/pw-cat")
EXPORT_DIRECTORY_PARTS = ("Music", "ChordPumper Promarchy")
EXPORT_FILENAME_PATTERN = re.compile(r"[a-z0-9][a-z0-9-]{0,199}\.mid")
BASIC_SAMPLE_RATE = 48_000
BASIC_CHANNELS = 2
BASIC_CHUNK_FRAMES = 1024
MAX_BASIC_VOICES = 32

def variable_length(value: int) -> bytes:
    buffer = value & 0x7F
    result = bytearray()
    while value >> 7:
        value >>= 7
        buffer <<= 8
        buffer |= (value & 0x7F) | 0x80
    while True:
        result.append(buffer & 0xFF)
        if buffer & 0x80:
            buffer >>= 8
        else:
            return bytes(result)


def parse_events(raw: str) -> list[list[int]]:
    if len(raw.encode("utf-8")) > MAX_EVENTS_JSON_BYTES:
        raise ValueError("played history exceeds the 512 KiB export limit")
    parsed = json.loads(raw)
    if not isinstance(parsed, list) or not parsed:
        raise ValueError("played history is empty")
    if len(parsed) > MAX_EVENTS:
        raise ValueError(f"played history exceeds {MAX_EVENTS} events")
    events = []
    for event in parsed:
        notes = event.get("notes") if isinstance(event, dict) else None
        if not isinstance(notes, list) or not notes:
            raise ValueError("every played event needs at least one note")
        if len(notes) > MAX_NOTES_PER_EVENT:
            raise ValueError(f"an event exceeds {MAX_NOTES_PER_EVENT} notes")
        if any(isinstance(note, bool) or not isinstance(note, int) for note in notes):
            raise ValueError("MIDI notes must be integers")
        clean_notes = list(notes)
        if any(note < 0 or note > 127 for note in clean_notes):
            raise ValueError("MIDI notes must be between 0 and 127")
        events.append(clean_notes)
    return events


def midi_bytes(tempo: int, events: list[list[int]]) -> bytes:
    if not 30 <= tempo <= 300:
        raise ValueError("tempo must be between 30 and 300 BPM")
    if not 1 <= len(events) <= MAX_EVENTS:
        raise ValueError(f"MIDI export requires 1 to {MAX_EVENTS} events")
    for notes in events:
        if not 1 <= len(notes) <= MAX_NOTES_PER_EVENT:
            raise ValueError(f"each MIDI event requires 1 to {MAX_NOTES_PER_EVENT} notes")
        if any(isinstance(note, bool) or not isinstance(note, int) or not 0 <= note <= 127 for note in notes):
            raise ValueError("MIDI notes must be integers between 0 and 127")
    ticks = 480
    event_ticks = ticks
    track = bytearray()
    microseconds = round(60_000_000 / tempo)
    track += b"\x00\xff\x51\x03" + microseconds.to_bytes(3, "big")
    track += b"\x00\xff\x58\x04\x04\x02\x18\x08"
    track += b"\x00\xc0\x00"  # Acoustic grand piano.

    for notes in events:
        for note in notes:
            track += b"\x00\x90" + bytes((note, 92))
        for index, note in enumerate(notes):
            track += variable_length(event_ticks if index == 0 else 0)
            track += b"\x80" + bytes((note, 0))

    track += b"\x00\xff\x2f\x00"
    if len(track) > MAX_MIDI_BYTES:
        raise ValueError("constructed MIDI track exceeds 4 MiB")
    header = b"MThd" + struct.pack(">IHHH", 6, 0, 1, ticks)
    return header + b"MTrk" + struct.pack(">I", len(track)) + bytes(track)


def directory_open_flags() -> int:
    directory_flags = os.O_RDONLY | os.O_DIRECTORY
    if hasattr(os, "O_NOFOLLOW"):
        directory_flags |= os.O_NOFOLLOW
    if hasattr(os, "O_CLOEXEC"):
        directory_flags |= os.O_CLOEXEC
    return directory_flags


def trusted_home_path() -> Path:
    return Path(pwd.getpwuid(os.getuid()).pw_dir)


def open_export_directory(home: Path) -> int:
    """Walk/create the export tree from a retained trusted home descriptor."""
    current_fd = os.open(home, directory_open_flags())
    try:
        for component in EXPORT_DIRECTORY_PARTS:
            try:
                next_fd = os.open(component, directory_open_flags(), dir_fd=current_fd)
            except FileNotFoundError:
                try:
                    os.mkdir(component, mode=0o700, dir_fd=current_fd)
                except FileExistsError:
                    pass
                next_fd = os.open(component, directory_open_flags(), dir_fd=current_fd)
            details = os.fstat(next_fd)
            if not stat.S_ISDIR(details.st_mode) or details.st_uid != os.getuid():
                os.close(next_fd)
                raise PermissionError("MIDI export directories must be owned by the current user")
            os.close(current_fd)
            current_fd = next_fd
        return current_fd
    except BaseException:
        os.close(current_fd)
        raise


def atomic_write_no_follow(output: Path, data: bytes, *, home: Path | None = None) -> None:
    """Atomically publish beneath trusted home without following any tree symlink."""
    trusted_home = home if home is not None else trusted_home_path()
    expected_parent = trusted_home.joinpath(*EXPORT_DIRECTORY_PARTS)
    if not output.is_absolute() or output.parent != expected_parent:
        raise ValueError("MIDI output must be directly beneath the configured export directory")
    if not EXPORT_FILENAME_PATTERN.fullmatch(output.name):
        raise ValueError("MIDI output filename is invalid")

    directory_fd = open_export_directory(trusted_home)
    temporary_name = f".{output.name}.{secrets.token_hex(12)}.tmp"
    file_fd = -1
    try:
        file_flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
        if hasattr(os, "O_NOFOLLOW"):
            file_flags |= os.O_NOFOLLOW
        file_fd = os.open(temporary_name, file_flags, 0o600, dir_fd=directory_fd)
        view = memoryview(data)
        while view:
            written = os.write(file_fd, view)
            if written <= 0:
                raise OSError("could not complete MIDI export")
            view = view[written:]
        os.fsync(file_fd)
        os.close(file_fd)
        file_fd = -1
        os.link(
            temporary_name,
            output.name,
            src_dir_fd=directory_fd,
            dst_dir_fd=directory_fd,
            follow_symlinks=False,
        )
        os.unlink(temporary_name, dir_fd=directory_fd)
        os.fsync(directory_fd)
    finally:
        if file_fd >= 0:
            os.close(file_fd)
        try:
            os.unlink(temporary_name, dir_fd=directory_fd)
        except FileNotFoundError:
            pass
        os.close(directory_fd)


def find_soundfont() -> str:
    preferred = [
        "/usr/share/soundfonts/FluidR3_GM.sf2",
        "/usr/share/soundfonts/FluidR3_GM2-2.sf2",
    ]
    for candidate in preferred:
        path = Path(candidate)
        try:
            details = path.stat()
        except FileNotFoundError:
            continue
        if stat.S_ISREG(details.st_mode) and details.st_uid == 0 and not details.st_mode & 0o022:
            return candidate
    raise RuntimeError("no SoundFont found; install soundfont-fluid")


def trusted_packaged_executable(path: Path, display_name: str) -> str:
    try:
        details = path.stat()
    except FileNotFoundError as error:
        raise RuntimeError(f"{display_name} is unavailable at {path}") from error
    if (
        not stat.S_ISREG(details.st_mode)
        or details.st_uid != 0
        or details.st_mode & 0o022
        or not details.st_mode & stat.S_IXUSR
    ):
        raise RuntimeError(f"{path} is not a trusted packaged executable")
    return str(path)


def trusted_fluidsynth() -> str:
    return trusted_packaged_executable(TRUSTED_FLUIDSYNTH, "FluidSynth")


def trusted_pw_cat() -> str:
    return trusted_packaged_executable(TRUSTED_PW_CAT, "PipeWire playback")


def pro_audio_available() -> bool:
    try:
        trusted_fluidsynth()
        find_soundfont()
    except RuntimeError:
        return False
    return True


def process_group_members(group_id: int, leader_pid: int) -> set[int]:
    """Return every non-leader PID still carrying the stable process-group ID."""
    members: set[int] = set()
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        if pid == leader_pid:
            continue
        try:
            stat_line = (entry / "stat").read_text()
            remainder = stat_line[stat_line.rfind(")") + 2 :].split()
            process_group = int(remainder[2])
        except (FileNotFoundError, IndexError, ValueError):
            continue
        if process_group == group_id:
            members.add(pid)
    return members


def leader_exited_unreaped(leader_pid: int) -> bool:
    try:
        result = os.waitid(os.P_PID, leader_pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
    except ChildProcessError as error:
        raise RuntimeError("FluidSynth leader lost before supervised reap") from error
    return result is not None


def wait_for_process_group(leader_pid: int, group_id: int, timeout: float) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if leader_exited_unreaped(leader_pid) and not process_group_members(group_id, leader_pid):
            return True
        time.sleep(0.02)
    return leader_exited_unreaped(leader_pid) and not process_group_members(group_id, leader_pid)


def signal_process_group(group_id: int, signal_number: int) -> None:
    try:
        os.killpg(group_id, signal_number)
    except ProcessLookupError:
        pass


def stop_process_group(
    process: subprocess.Popen,
    graceful_shutdown,
    stderr_thread: threading.Thread | None,
    *,
    process_name: str = "audio backend",
    graceful_timeout: float = 2.0,
    terminate_timeout: float = 2.0,
    kill_timeout: float = 2.0,
) -> None:
    """Stop the complete group under an unreaped, non-reusable leader identity."""
    leader_pid = process.pid
    group_id = leader_pid  # Guaranteed by Popen(start_new_session=True).
    try:
        graceful_shutdown()
    except (BrokenPipeError, OSError, RuntimeError):
        pass

    group_stopped = wait_for_process_group(leader_pid, group_id, graceful_timeout)
    if not group_stopped:
        signal_process_group(group_id, signal.SIGTERM)
        group_stopped = wait_for_process_group(leader_pid, group_id, terminate_timeout)
    if not group_stopped:
        signal_process_group(group_id, signal.SIGKILL)
        group_stopped = wait_for_process_group(leader_pid, group_id, kill_timeout)
    if not group_stopped:
        raise RuntimeError(f"{process_name} process group did not stop after SIGKILL")

    try:
        process.wait(timeout=1.0)
    except (subprocess.TimeoutExpired, OSError) as error:
        raise RuntimeError(f"{process_name} leader could not be reaped") from error
    finally:
        if stderr_thread is not None:
            stderr_thread.join(timeout=1.0)
            if stderr_thread.is_alive():
                if process.stderr is not None:
                    process.stderr.close()
                stderr_thread.join(timeout=1.0)
        for stream in (process.stdin, process.stdout, process.stderr):
            if stream is not None and not stream.closed:
                stream.close()
        if stderr_thread is not None and stderr_thread.is_alive():
            raise RuntimeError(f"{process_name} diagnostic drain did not stop")


def bounded_int(message: dict, name: str, minimum: int, maximum: int, default=None) -> int:
    value = message.get(name, default)
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"{name} must be an integer")
    if not minimum <= value <= maximum:
        raise ValueError(f"{name} must be between {minimum} and {maximum}")
    return value


def read_control_line() -> dict | None:
    line = sys.stdin.readline(MAX_CONTROL_LINE_BYTES + 1)
    if not line:
        return None
    if len(line.encode("utf-8")) > MAX_CONTROL_LINE_BYTES:
        while line and not line.endswith("\n"):
            line = sys.stdin.readline(MAX_CONTROL_LINE_BYTES + 1)
        raise ValueError("control message exceeds 4096 bytes")
    message = json.loads(line)
    if not isinstance(message, dict):
        raise ValueError("control message must be an object")
    return message


def serve_basic(pro_available: bool) -> int:
    executable = trusted_pw_cat()
    shutdown_signals = {signal.SIGINT, signal.SIGTERM}
    old_sigint = signal.getsignal(signal.SIGINT)
    old_sigterm = signal.getsignal(signal.SIGTERM)
    previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, shutdown_signals)
    try:
        player = subprocess.Popen(
            [
                executable,
                "--playback",
                "--raw",
                "--rate", str(BASIC_SAMPLE_RATE),
                "--channels", str(BASIC_CHANNELS),
                "--format", "s16",
                "--latency", str(BASIC_CHUNK_FRAMES),
                "-",
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            start_new_session=True,
        )
    except BaseException:
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        raise

    audio_commands: queue.Queue[tuple] = queue.Queue(maxsize=256)
    writer_stop = threading.Event()
    writer_errors: deque[str] = deque(maxlen=1)
    player_log: deque[str] = deque(maxlen=MAX_SYNTH_LOG_LINES)
    stderr_thread: threading.Thread | None = None
    writer_thread: threading.Thread | None = None

    def request_shutdown(signum, _frame) -> None:
        raise SystemExit(128 + signum)

    def drain_player_stderr() -> None:
        if player.stderr is None:
            return
        while True:
            chunk = player.stderr.read(MAX_SYNTH_LOG_LINE_CHARS)
            if not chunk:
                break
            player_log.append(chunk.decode("utf-8", errors="replace").rstrip())

    def write_basic_audio() -> None:
        voices: dict[int, dict[str, float | bool]] = {}
        character = 50
        try:
            while not writer_stop.is_set():
                released_this_batch: set[int] = set()
                while True:
                    try:
                        item = audio_commands.get_nowait()
                    except queue.Empty:
                        break
                    kind = item[0]
                    if kind == "character":
                        character = item[1]
                        continue
                    if kind == "note_on":
                        note, velocity = item[1], item[2]
                        if note in voices and note in released_this_batch:
                            voices[note]["released"] = False
                            voices[note]["release"] = 1.0
                            voices[note]["velocity"] = velocity / 127.0
                            released_this_batch.discard(note)
                            continue
                        brightness = max(0.48, min(1.12, 1.0 - (note - 54) * 0.025))
                        low_blend = max(0.0, min(1.0, (note - 36) / 12.0))
                        low_taming = 0.62 + 0.38 * low_blend
                        if note not in voices and len(voices) >= MAX_BASIC_VOICES:
                            voices.pop(next(iter(voices)))
                        voices[note] = {
                            "phase": 0.0,
                            "age": 0.0,
                            "phase_step": 2.0 * math.pi * 440.0 * (2.0 ** ((note - 69) / 12.0)) / BASIC_SAMPLE_RATE,
                            "fundamental": 0.88 + 0.12 * low_blend,
                            "second": 0.34 * brightness * low_taming,
                            "third": 0.11 * (brightness ** 1.35) * low_taming,
                            "level": 1.28 - 0.28 * low_blend,
                            "upper_warmth": max(0.0, min(
                                0.40,
                                (note - 59) * 0.008 if note < 72
                                else 0.10 + (note - 72) * 0.0125,
                            )),
                            "velocity": velocity / 127.0,
                            "released": False,
                            "release": 1.0,
                            "release_rate": 0.9988 + 0.00075 * low_blend,
                        }
                    elif kind == "note_off" and item[1] in voices:
                        voices[item[1]]["released"] = True
                        released_this_batch.add(item[1])
                    elif kind == "all_off":
                        for voice in voices.values():
                            voice["released"] = True
                        released_this_batch.update(voices)

                pcm = array("h")
                remove_notes: set[int] = set()
                for _frame in range(BASIC_CHUNK_FRAMES):
                    mixed = 0.0
                    for note, voice in voices.items():
                        phase = float(voice["phase"])
                        age = float(voice["age"])
                        release = float(voice["release"])
                        attack = min(1.0, age / (BASIC_SAMPLE_RATE * 0.0015))
                        harmonic_scale = 0.65 + character * 0.007
                        tone = (
                            float(voice["fundamental"]) * math.sin(phase)
                            + harmonic_scale * float(voice["second"]) * math.sin(phase * 2.0)
                            + harmonic_scale * float(voice["third"]) * math.sin(phase * 3.0)
                        ) / 1.45
                        upper_warmth = float(voice["upper_warmth"])
                        if upper_warmth > 0.0:
                            rounded_tone = math.tanh(tone * 1.6) / 1.6
                            tone = tone * (1.0 - upper_warmth) + rounded_tone * upper_warmth
                        mixed += tone * attack * release * float(voice["velocity"]) * float(voice["level"])
                        voice["phase"] = (phase + float(voice["phase_step"])) % (2.0 * math.pi)
                        voice["age"] = age + 1.0
                        if bool(voice["released"]):
                            release *= float(voice["release_rate"])
                            voice["release"] = release
                            if release < 0.001:
                                remove_notes.add(note)
                    clean = mixed * 0.27
                    softly_driven = math.tanh(clean * 2.0) / 2.0
                    drive_mix = character * 0.004
                    shaped = clean * (1.0 - drive_mix) + softly_driven * drive_mix
                    sample = max(-32767, min(32767, round(shaped * 32767)))
                    pcm.append(sample)
                    pcm.append(sample)
                for note in remove_notes:
                    voices.pop(note, None)
                if player.stdin is None:
                    raise RuntimeError("PipeWire playback channel is unavailable")
                player.stdin.write(pcm.tobytes())
                player.stdin.flush()
        except (BrokenPipeError, OSError, RuntimeError) as error:
            if not writer_stop.is_set():
                writer_errors.append(str(error)[:256])
        finally:
            writer_stop.set()

    def queue_audio(item: tuple) -> None:
        if writer_errors:
            raise RuntimeError("Basic audio output stopped")
        try:
            audio_commands.put_nowait(item)
        except queue.Full as error:
            raise ValueError("basic audio command queue is full") from error

    def graceful_stop() -> None:
        writer_stop.set()
        if writer_thread is not None:
            writer_thread.join(timeout=1.0)
        if player.stdin is not None and not player.stdin.closed:
            player.stdin.close()

    try:
        if player.stdin is None or player.stderr is None:
            raise RuntimeError("could not open PipeWire supervision channels")
        stderr_thread = threading.Thread(target=drain_player_stderr, daemon=True)
        writer_thread = threading.Thread(target=write_basic_audio, daemon=True)
        stderr_thread.start()
        writer_thread.start()
        signal.signal(signal.SIGINT, request_shutdown)
        signal.signal(signal.SIGTERM, request_shutdown)
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        print(json.dumps({
            "type": "ready",
            "backend": "basic",
            "proAvailable": pro_available,
        }), flush=True)
        requested_notes: set[int] = set()
        while True:
            try:
                message = read_control_line()
                if message is None:
                    break
                kind = message.get("type")
                if kind == "note_on":
                    note = bounded_int(message, "note", 0, 127)
                    velocity = bounded_int(message, "velocity", 1, 127, 100)
                    if note in requested_notes:
                        continue
                    if note not in requested_notes and len(requested_notes) >= MAX_BASIC_VOICES:
                        raise ValueError(f"basic audio supports at most {MAX_BASIC_VOICES} active voices")
                    queue_audio(("note_on", note, velocity))
                    requested_notes.add(note)
                elif kind == "note_off":
                    note = bounded_int(message, "note", 0, 127)
                    queue_audio(("note_off", note))
                    requested_notes.discard(note)
                elif kind == "all_off":
                    queue_audio(("all_off",))
                    requested_notes.clear()
                elif kind == "program":
                    bounded_int(message, "program", 0, 127)
                elif kind == "character":
                    character = bounded_int(message, "value", 0, 100)
                    queue_audio(("character", character))
                elif kind == "quit":
                    break
                else:
                    raise ValueError("unsupported control message type")
            except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
                print(json.dumps({"type": "error", "message": str(error)[:256]}), flush=True)
    finally:
        signal.pthread_sigmask(signal.SIG_BLOCK, shutdown_signals)
        try:
            stop_process_group(
                player,
                graceful_stop,
                stderr_thread,
                process_name="PipeWire player",
            )
        finally:
            writer_stop.set()
            if writer_thread is not None:
                writer_thread.join(timeout=1.0)
            writer_alive = writer_thread is not None and writer_thread.is_alive()
            signal.signal(signal.SIGINT, old_sigint)
            signal.signal(signal.SIGTERM, old_sigterm)
            signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
            if writer_alive:
                raise RuntimeError("Basic audio writer did not stop")
    return 0


def serve_fluid() -> int:
    executable = trusted_fluidsynth()
    soundfont = find_soundfont()
    shutdown_signals = {signal.SIGINT, signal.SIGTERM}
    old_sigint = signal.getsignal(signal.SIGINT)
    old_sigterm = signal.getsignal(signal.SIGTERM)
    previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, shutdown_signals)
    try:
        synth = subprocess.Popen(
            [executable, "-a", "pipewire", "-g", "0.65", "-n", soundfont],
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
            start_new_session=True,
        )
    except BaseException:
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        raise
    stderr_thread: threading.Thread | None = None
    synth_log: deque[str] = deque(maxlen=MAX_SYNTH_LOG_LINES)

    def drain_synth_stderr() -> None:
        if synth.stderr is None:
            return
        while True:
            chunk = synth.stderr.read(MAX_SYNTH_LOG_LINE_CHARS)
            if not chunk:
                break
            synth_log.append(chunk.rstrip())

    def request_shutdown(signum, _frame) -> None:
        raise SystemExit(128 + signum)

    def command(value: str) -> None:
        if synth.stdin is None:
            raise RuntimeError("could not open FluidSynth control channel")
        synth.stdin.write(value + "\n")
        synth.stdin.flush()

    def graceful_stop() -> None:
        if synth.stdin is None:
            return
        try:
            command("cc 0 123 0")
            command("quit")
        finally:
            if synth.stdin is not None and not synth.stdin.closed:
                synth.stdin.close()

    def set_cinematic(value: int) -> None:
        width = max(0.0, (value - 50) / 50.0)
        if value == 0:
            command("cc 0 91 40")
            command("cc 0 93 0")
            command("cc 0 11 127")
            command("set synth.chorus.depth 4.25")
            command("set synth.chorus.level 0.60")
            command("set synth.chorus.nr 3")
            return
        command(f"cc 0 91 {min(127, 40 + round(value * 0.87))}")
        command(f"cc 0 93 {round(value * 0.50)}")
        command(f"cc 0 11 {max(120, 127 - round(value * 0.07))}")
        command(f"set synth.chorus.depth {4.25 + width * 13.75:.2f}")
        command(f"set synth.chorus.level {0.60 + width * 0.50:.2f}")
        command(f"set synth.chorus.nr {3 + round(width * 2)}")

    try:
        if synth.stdin is None or synth.stderr is None:
            raise RuntimeError("could not open FluidSynth supervision channels")
        stderr_thread = threading.Thread(target=drain_synth_stderr, daemon=True)
        stderr_thread.start()
        signal.signal(signal.SIGINT, request_shutdown)
        signal.signal(signal.SIGTERM, request_shutdown)
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        command("prog 0 0")
        print(json.dumps({
            "type": "ready",
            "backend": "fluid",
            "proAvailable": True,
            "soundfont": soundfont,
        }), flush=True)
        while True:
            try:
                message = read_control_line()
                if message is None:
                    break
                kind = message.get("type")
                if kind == "note_on":
                    note = bounded_int(message, "note", 0, 127)
                    velocity = bounded_int(message, "velocity", 1, 127, 100)
                    command(f"noteon 0 {note} {velocity}")
                elif kind == "note_off":
                    command(f"noteoff 0 {bounded_int(message, 'note', 0, 127)}")
                elif kind == "program":
                    command(f"prog 0 {bounded_int(message, 'program', 0, 127)}")
                elif kind == "cinematic":
                    set_cinematic(bounded_int(message, "value", 0, 100))
                elif kind == "all_off":
                    command("cc 0 123 0")
                elif kind == "quit":
                    break
                else:
                    raise ValueError("unsupported control message type")
            except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
                print(json.dumps({"type": "error", "message": str(error)[:256]}), flush=True)
    finally:
        signal.pthread_sigmask(signal.SIG_BLOCK, shutdown_signals)
        try:
            stop_process_group(
                synth,
                graceful_stop,
                stderr_thread,
                process_name="FluidSynth",
            )
        finally:
            signal.signal(signal.SIGINT, old_sigint)
            signal.signal(signal.SIGTERM, old_sigterm)
            signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
    return 0


def serve(backend: str) -> int:
    pro_available = pro_audio_available()
    selected = "fluid" if backend == "auto" and pro_available else backend
    if selected == "auto":
        selected = "basic"
    if selected == "fluid":
        if not pro_available:
            raise RuntimeError("Pro audio requires FluidSynth and the FluidR3 SoundFont")
        return serve_fluid()
    if selected == "basic":
        return serve_basic(pro_available)
    raise RuntimeError("unsupported audio backend")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("midi", "serve"))
    parser.add_argument("--output")
    parser.add_argument("--tempo", type=int, default=110)
    parser.add_argument("--events")
    parser.add_argument("--backend", choices=("auto", "basic", "fluid"), default="auto")
    args = parser.parse_args()

    if args.action == "serve":
        try:
            return serve(args.backend)
        except RuntimeError as error:
            print(json.dumps({"type": "error", "message": str(error)}), flush=True)
            return 1
    if not args.output:
        parser.error("--output is required for midi")
    if not 30 <= args.tempo <= 300:
        parser.error("tempo must be between 30 and 300 BPM")
    if not args.events:
        parser.error("--events is required for midi")
    events = parse_events(args.events)
    output = Path(args.output).expanduser()
    atomic_write_no_follow(output, midi_bytes(args.tempo, events))
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
