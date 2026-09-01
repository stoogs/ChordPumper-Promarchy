#!/usr/bin/env python3
"""Dependency-free audio and MIDI engine for ChordPumper Promarchy."""

from __future__ import annotations

import argparse
from collections import deque
import glob
import json
import os
import secrets
import signal
import shutil
import struct
import subprocess
import sys
import threading
from pathlib import Path

MAX_EVENTS = 4096
MAX_NOTES_PER_EVENT = 16
MAX_EVENTS_JSON_BYTES = 512 * 1024
MAX_CONTROL_LINE_BYTES = 4096
MAX_MIDI_BYTES = 4 * 1024 * 1024
MAX_SYNTH_LOG_LINES = 64
MAX_SYNTH_LOG_LINE_CHARS = 512

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


def atomic_write_no_follow(output: Path, data: bytes) -> None:
    """Atomically publish output without following or replacing symlinks."""
    output = output.expanduser()
    if output.name in ("", ".", ".."):
        raise ValueError("output must name a MIDI file")
    output.parent.mkdir(mode=0o700, parents=True, exist_ok=True)

    directory_flags = os.O_RDONLY | os.O_DIRECTORY
    if hasattr(os, "O_NOFOLLOW"):
        directory_flags |= os.O_NOFOLLOW
    directory_fd = os.open(output.parent, directory_flags)
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
        if Path(candidate).is_file():
            return candidate
    for pattern in ("/usr/share/soundfonts/*.sf2", "/usr/share/sounds/sf2/*.sf2"):
        matches = sorted(glob.glob(pattern))
        if matches:
            return matches[0]
    raise RuntimeError("no SoundFont found; install soundfont-fluid")


def serve() -> int:
    executable = shutil.which("fluidsynth")
    if not executable:
        raise RuntimeError("FluidSynth is not installed")
    soundfont = find_soundfont()
    synth = subprocess.Popen(
        [executable, "-a", "pipewire", "-g", "0.65", "-n", soundfont],
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        start_new_session=True,
    )
    if synth.stdin is None:
        raise RuntimeError("could not open FluidSynth control channel")

    synth_log: deque[str] = deque(maxlen=MAX_SYNTH_LOG_LINES)

    def drain_synth_stderr() -> None:
        if synth.stderr is None:
            return
        while True:
            chunk = synth.stderr.read(MAX_SYNTH_LOG_LINE_CHARS)
            if not chunk:
                break
            synth_log.append(chunk.rstrip())

    stderr_thread = threading.Thread(target=drain_synth_stderr, daemon=True)
    stderr_thread.start()

    def request_shutdown(signum, _frame) -> None:
        raise SystemExit(128 + signum)

    signal.signal(signal.SIGINT, request_shutdown)
    signal.signal(signal.SIGTERM, request_shutdown)

    def command(value: str) -> None:
        synth.stdin.write(value + "\n")
        synth.stdin.flush()

    def bounded_int(message: dict, name: str, minimum: int, maximum: int, default=None) -> int:
        value = message.get(name, default)
        if isinstance(value, bool) or not isinstance(value, int):
            raise ValueError(f"{name} must be an integer")
        if not minimum <= value <= maximum:
            raise ValueError(f"{name} must be between {minimum} and {maximum}")
        return value

    def stop_synth() -> None:
        try:
            command("cc 0 123 0")
            command("quit")
        except (BrokenPipeError, OSError):
            pass
        try:
            synth.wait(timeout=2)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(synth.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                synth.wait(timeout=2)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(synth.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                synth.wait(timeout=2)
        stderr_thread.join(timeout=1)

    try:
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
        stop_synth()
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
