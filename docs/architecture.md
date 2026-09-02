# Architecture

ChordPumper Promarchy has three small layers.

## Omarchy interface

- `manifest.json` declares one `bar-widget` entry point.
- `BarWidget.qml` provides the bar button and forwards panel lifecycle methods.
- `Panel.qml` owns the visual interface, keyboard focus, transport actions, and audio process.

The plugin uses the existing long-running Quickshell process. It never starts another Quickshell instance.

## Music model

- `Model.js` contains note names, intervals, chord construction, full chord names, and keyboard mapping.
- `Styles.js` contains the 24 musical palettes. Each style supplies six foundational chords, four generated colour slots, and eight chord shapes.

These files are deliberately deterministic. No remote model, API, or network access is involved.

## Audio and export engine

`engine/chordpumper_engine.py` uses only the Python standard library. QML invokes the packaged `/usr/bin/python3` path. In Basic mode the engine generates bounded 48 kHz stereo PCM and streams it to Omarchy's validated `/usr/bin/pw-cat`. In Pro mode it validates and starts only the packaged `/usr/bin/fluidsynth` executable with an official root-owned FluidR3 SoundFont. Auto mode prefers Pro when both optional components pass validation and otherwise selects Basic. Both modes accept JSON messages such as:

```json
{"type":"note_on","note":60,"velocity":104}
{"type":"note_off","note":60}
{"type":"all_off"}
```

The QML process remains responsible for key state. Closing the panel sends note-off and all-notes-off messages to prevent stuck voices. Control lines and every note, velocity, program, active voice, and queued Basic-audio command are bounded before processing. The selected external audio player runs in its own process group and its diagnostic pipe is continuously drained into a bounded buffer. Shutdown retains the unreaped leader as a stable identity while checking descendants, then escalates the complete group through graceful stop, termination, and a final kill before reaping the leader.

MIDI export runs as a short-lived process. Up to 4,096 take-history events are generated directly as a format-0 Standard MIDI file with 480 ticks per quarter note and one beat per played gesture. Event count, per-event notes, JSON argument size, values, tempo, and final track size are independently bounded. The engine opens the account home as a trusted directory descriptor, walks or creates each fixed export component with no-follow checks, retains the final directory descriptor, and publishes a private random temporary file atomically without following or replacing an existing entry.

## Trust boundary

The plugin runs with normal user permissions, as all Omarchy shell plugins do. It launches only Python, Omarchy's PipeWire player, and optionally FluidSynth; it has no network code and writes beneath `~/Music/ChordPumper Promarchy` only after an explicit user action. Dynamic engine status is rendered as plain text in QML.
