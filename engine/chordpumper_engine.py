#!/usr/bin/env python3
"""Dependency-free audio and MIDI engine for ChordPumper Promarchy."""

from __future__ import annotations

import argparse
from collections import deque
import json
import os
import pwd
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
EXPORT_DIRECTORY_PARTS = ("Music", "ChordPumper Promarchy")
EXPORT_FILENAME_PATTERN = re.compile(r"[a-z0-9][a-z0-9-]{0,199}\.mid")

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


def trusted_fluidsynth() -> str:
    try:
        details = TRUSTED_FLUIDSYNTH.stat()
    except FileNotFoundError as error:
        raise RuntimeError("FluidSynth is not installed at /usr/bin/fluidsynth") from error
    if (
        not stat.S_ISREG(details.st_mode)
        or details.st_uid != 0
        or details.st_mode & 0o022
        or not details.st_mode & stat.S_IXUSR
    ):
        raise RuntimeError("/usr/bin/fluidsynth is not a trusted packaged executable")
    return str(TRUSTED_FLUIDSYNTH)


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
        raise RuntimeError("FluidSynth process group did not stop after SIGKILL")

    try:
        process.wait(timeout=1.0)
    except (subprocess.TimeoutExpired, OSError) as error:
        raise RuntimeError("FluidSynth leader could not be reaped") from error
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
            raise RuntimeError("FluidSynth diagnostic drain did not stop")


def serve() -> int:
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

    def bounded_int(message: dict, name: str, minimum: int, maximum: int, default=None) -> int:
        value = message.get(name, default)
        if isinstance(value, bool) or not isinstance(value, int):
            raise ValueError(f"{name} must be an integer")
        if not minimum <= value <= maximum:
            raise ValueError(f"{name} must be between {minimum} and {maximum}")
        return value

    def graceful_stop() -> None:
        if synth.stdin is None:
            return
        try:
            command("cc 0 123 0")
            command("quit")
        finally:
            if synth.stdin is not None and not synth.stdin.closed:
                synth.stdin.close()

    try:
        if synth.stdin is None or synth.stderr is None:
            raise RuntimeError("could not open FluidSynth supervision channels")
        stderr_thread = threading.Thread(target=drain_synth_stderr, daemon=True)
        stderr_thread.start()
        signal.signal(signal.SIGINT, request_shutdown)
        signal.signal(signal.SIGTERM, request_shutdown)
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        command("prog 0 0")
        print(json.dumps({"type": "ready", "soundfont": soundfont}), flush=True)
        while True:
            line = sys.stdin.readline(MAX_CONTROL_LINE_BYTES + 1)
            if not line:
                break
            try:
                if len(line.encode("utf-8")) > MAX_CONTROL_LINE_BYTES:
                    while line and not line.endswith("\n"):
                        line = sys.stdin.readline(MAX_CONTROL_LINE_BYTES + 1)
                    raise ValueError("control message exceeds 4096 bytes")
                message = json.loads(line)
                if not isinstance(message, dict):
                    raise ValueError("control message must be an object")
                kind = message.get("type")
                if kind == "note_on":
                    note = bounded_int(message, "note", 0, 127)
                    velocity = bounded_int(message, "velocity", 1, 127, 100)
                    command(f"noteon 0 {note} {velocity}")
                elif kind == "note_off":
                    command(f"noteoff 0 {bounded_int(message, 'note', 0, 127)}")
                elif kind == "program":
                    command(f"prog 0 {bounded_int(message, 'program', 0, 127)}")
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
            stop_process_group(synth, graceful_stop, stderr_thread)
        finally:
            signal.signal(signal.SIGINT, old_sigint)
            signal.signal(signal.SIGTERM, old_sigterm)
            signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("midi", "serve"))
    parser.add_argument("--output")
    parser.add_argument("--tempo", type=int, default=110)
    parser.add_argument("--events")
    args = parser.parse_args()

    if args.action == "serve":
        try:
            return serve()
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
