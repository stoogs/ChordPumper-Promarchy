#!/usr/bin/env python3
"""Dependency-free audio and MIDI engine for ChordPumper Promarchy."""

from __future__ import annotations

import argparse
import glob
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

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
    parsed = json.loads(raw)
    if not isinstance(parsed, list) or not parsed:
        raise ValueError("played history is empty")
    events = []
    for event in parsed:
        notes = event.get("notes") if isinstance(event, dict) else None
        if not isinstance(notes, list) or not notes:
            raise ValueError("every played event needs at least one note")
        clean_notes = [int(note) for note in notes]
        if any(note < 0 or note > 127 for note in clean_notes):
            raise ValueError("MIDI notes must be between 0 and 127")
        events.append(clean_notes)
    return events


def midi_bytes(tempo: int, events: list[list[int]]) -> bytes:
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
    header = b"MThd" + struct.pack(">IHHH", 6, 0, 1, ticks)
    return header + b"MTrk" + struct.pack(">I", len(track)) + bytes(track)


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
    )
    if synth.stdin is None:
        raise RuntimeError("could not open FluidSynth control channel")

    def command(value: str) -> None:
        synth.stdin.write(value + "\n")
        synth.stdin.flush()

    command("prog 0 0")
    print(json.dumps({"type": "ready", "soundfont": soundfont}), flush=True)
    try:
        for line in sys.stdin:
            try:
                message = json.loads(line)
                kind = message.get("type")
                if kind == "note_on":
                    command(f"noteon 0 {int(message['note'])} {int(message.get('velocity', 100))}")
                elif kind == "note_off":
                    command(f"noteoff 0 {int(message['note'])}")
                elif kind == "program":
                    command(f"prog 0 {int(message['program'])}")
                elif kind == "all_off":
                    command("cc 0 123 0")
                elif kind == "quit":
                    break
            except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
                print(json.dumps({"type": "error", "message": str(error)}), flush=True)
    finally:
        try:
            command("cc 0 123 0")
            command("quit")
        except (BrokenPipeError, OSError):
            pass
        try:
            synth.wait(timeout=2)
        except subprocess.TimeoutExpired:
            synth.terminate()
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
    output.parent.mkdir(parents=True, exist_ok=True)

    output.write_bytes(midi_bytes(args.tempo, events))
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
