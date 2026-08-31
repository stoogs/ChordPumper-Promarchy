# Architecture

ChordPumper Promarchy has three small layers.

## Omarchy interface

- `manifest.json` declares one `bar-widget` entry point.
- `BarWidget.qml` provides the bar button and forwards panel lifecycle methods.
- `Panel.qml` owns the visual interface, keyboard focus, transport actions, and audio process.

The plugin uses the existing long-running Quickshell process. It never starts another Quickshell instance.

## Music model

- `Model.js` contains note names, intervals, chord construction, full chord names, and keyboard mapping.
- `Styles.js` contains the 24 musical palettes. Each style supplies six progression chords and eight chord shapes.

These files are deliberately deterministic. No remote model, API, or network access is involved.

## Audio and export engine

`engine/chordpumper_engine.py` uses only the Python standard library. In server mode it starts FluidSynth with the installed FluidR3 SoundFont and accepts JSON messages such as:

```json
{"type":"note_on","note":60,"velocity":104}
{"type":"note_off","note":60}
{"type":"all_off"}
```

The QML process remains responsible for key state. Closing the panel sends note-off and all-notes-off messages to prevent stuck voices.

Save and MIDI modes run as short-lived processes. MIDI output is generated directly as a format-0 Standard MIDI file with 480 ticks per quarter note.

## Trust boundary

The plugin runs with normal user permissions, as all Omarchy shell plugins do. It launches only Python and FluidSynth, has no network code, and writes beneath `~/Music/ChordPumper Promarchy` only after an explicit user action.
