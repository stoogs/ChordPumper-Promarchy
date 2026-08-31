#!/usr/bin/env python3
"""Dependency-free audio, project, and MIDI engine for ChordPumper Promarchy."""

from __future__ import annotations

import argparse
import glob
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

NOTE_OFFSETS = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
                "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
INTERVALS = {
    "maj": (0, 4, 7), "min": (0, 3, 7), "7": (0, 4, 7, 10),
    "maj7": (0, 4, 7, 11), "min7": (0, 3, 7, 10),
    "sus2": (0, 2, 7), "sus4": (0, 5, 7), "dim": (0, 3, 6),
    "aug": (0, 4, 8), "add9": (0, 4, 7, 14),
    "maj9": (0, 4, 7, 11, 14), "min9": (0, 3, 7, 10, 14),
    "9": (0, 4, 7, 10, 14), "11": (0, 4, 7, 10, 14, 17),
    "min11": (0, 3, 7, 10, 14, 17), "13": (0, 4, 7, 10, 14, 21),
    "dim7": (0, 3, 6, 9), "6": (0, 4, 7, 9),
    "min6": (0, 3, 7, 9), "5": (0, 7), "7sus4": (0, 5, 7, 10),
    "m7b5": (0, 3, 6, 10), "maj7#11": (0, 4, 7, 11, 18),
}


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


def parse_progression(raw: str) -> list[dict[str, str]]:
    chords = []
    for token in raw.split(","):
        root, quality = token.strip().split(":", 1)
        if root not in NOTE_OFFSETS or quality not in INTERVALS:
            raise ValueError(f"Unsupported chord: {token}")
        chords.append({"root": root, "quality": quality})
    if not 1 <= len(chords) <= 16:
        raise ValueError("A project needs between 1 and 16 bars")
    return chords


def project_data(tempo: int, progression: list[dict[str, str]]) -> dict:
    return {
        "version": 1,
        "tempo": tempo,
        "timeSignature": [4, 4],
        "key": "C",
        "scale": "major",
        "bars": len(progression),
        "tracks": {"chords": progression, "melody": []},
    }


def midi_bytes(tempo: int, progression: list[dict[str, str]]) -> bytes:
    ticks = 480
    bar_ticks = ticks * 4
    track = bytearray()
    microseconds = round(60_000_000 / tempo)
    track += b"\x00\xff\x51\x03" + microseconds.to_bytes(3, "big")
    track += b"\x00\xff\x58\x04\x04\x02\x18\x08"
    track += b"\x00\xc0\x00"  # Acoustic grand piano.

    for chord in progression:
        root_midi = 60 + NOTE_OFFSETS[chord["root"]]
        notes = [root_midi + interval for interval in INTERVALS[chord["quality"]]]
        for note in notes:
            track += b"\x00\x90" + bytes((note, 92))
        for index, note in enumerate(notes):
            track += variable_length(bar_ticks if index == 0 else 0)
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
    parser.add_argument("action", choices=("save", "midi", "serve"))
    parser.add_argument("--output")
    parser.add_argument("--tempo", type=int, default=110)
    parser.add_argument("--progression", default="C:maj,A:min,F:maj,G:maj")
    args = parser.parse_args()

    if args.action == "serve":
        try:
            return serve()
        except RuntimeError as error:
            print(json.dumps({"type": "error", "message": str(error)}), flush=True)
            return 1
    if not args.output:
        parser.error("--output is required for save and midi")
    if not 30 <= args.tempo <= 300:
        parser.error("tempo must be between 30 and 300 BPM")
    progression = parse_progression(args.progression)
    output = Path(args.output).expanduser()
    output.parent.mkdir(parents=True, exist_ok=True)

    if args.action == "save":
        output.write_text(json.dumps(project_data(args.tempo, progression), indent=2) + "\n")
    else:
        output.write_bytes(midi_bytes(args.tempo, progression))
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
