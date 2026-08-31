# ChordPumper Promarchy

ChordPumper Promarchy is a keyboard-driven chord, harmony, and MIDI sketchpad for the Omarchy Quattro shell. It turns the Omarchy bar into a quick musical notebook: play a piano, voice chords from the home row, audition style-aware progressions, randomize a four-bar idea, and export the result as standard MIDI.

## Features

- Low-latency FluidSynth playback through PipeWire
- One-octave computer-keyboard piano with mouse support
- 24 musical style palettes
- Six playable, style-aware progression chords
- Eight momentary or lockable chord shapes per style
- Four-bar progression generator
- Recent-note history
- JSON project saving
- Standard MIDI file export
- Theme-aware Omarchy panel and bar widget

## Requirements

- Omarchy with the Quattro plugin runtime
- Python 3
- FluidSynth
- FluidR3 General MIDI SoundFont

Install the audio dependencies through Omarchy:

```sh
omarchy pkg add fluidsynth soundfont-fluid
```

The plugin bundles no SoundFont, samples, or third-party Python packages.

## Install

```sh
omarchy plugin add https://github.com/stoogs/ChordPumper-Promarchy.git --enable
```

The plugin ID is `io.github.stoogs.chordpumper-promarchy`. If it is enabled but not visible, place it in the center section:

```sh
omarchy bar put io.github.stoogs.chordpumper-promarchy --section center
```

Click **♪ Chords** in the bar to open the instrument.

## Controls

### Piano

| Action | Keys |
| --- | --- |
| White notes, C through B | `A S D F G H J` |
| Black notes | `W E T Y U` |
| Octave down / up | `Z` / `X` |
| Close panel | `Escape` |

### Style chords

Hold `1` through `6` to play the six named progression chords supplied by the active style. The chord stops when the number key is released.

### Chord shapes

The eight visible shapes map left-to-right to:

```text
C V B N M , . /
```

- Hold a shape key to use it temporarily on the piano.
- Release it to return to single-note mode or the clicked lock.
- Click a shape to lock it across every piano root.
- Click the locked shape again to unlock it.

### Styles

Click the style selector for a 6×4 table, or press `<` to move to the next style.

Included styles:

| | | | |
| --- | --- | --- | --- |
| Pop | Rock | Indie | Folk |
| Country | Blues | Soul | Funk |
| R&B | Disco | House | Techno |
| Ambient | Dream Pop | Lo-fi | Synthwave |
| Cinematic | Epic | Jazz | Neo-Soul |
| Bossa Nova | Gospel | Reggae | Classical |

Every style defines both its six progression chords and eight chord-shape choices. Chords are written in full in the interface for clarity.

## Random, Save, and MIDI

**Random** selects one of the 24 styles and generates a four-bar progression from that style's harmonic vocabulary.

**Save** writes the current project to:

```text
~/Music/ChordPumper Promarchy/Untitled.chordpumper.json
```

**Export MIDI** writes a format-0 Standard MIDI file to:

```text
~/Music/ChordPumper Promarchy/Untitled.mid
```

The files can be imported into Bitwig, Reaper, Ardour, Ableton Live, Logic, or another MIDI-capable workstation.

## How it works

The QML interface runs inside the existing Omarchy shell process. It starts the bundled Python engine as a child process and sends newline-delimited JSON note events over standard input. The engine controls FluidSynth, while its dependency-free MIDI writer handles saving and export.

See [Architecture](docs/architecture.md) for the component and security model.

## Privacy and security

Omarchy plugins run unsandboxed with the current user's permissions. ChordPumper Promarchy:

- Runs only its bundled Python engine and the system FluidSynth executable.
- Does not use the network.
- Does not request elevated privileges.
- Writes files only after Save or Export MIDI is clicked.
- Writes only beneath `~/Music/ChordPumper Promarchy` by default.
- Does not modify Omarchy configuration directly.

Audio dependencies are installed separately and explicitly by the user.

## Remove

```sh
omarchy plugin remove io.github.stoogs.chordpumper-promarchy
```

If no other software needs the optional audio packages, they can also be removed:

```sh
omarchy pkg drop fluidsynth soundfont-fluid
```

Saved projects and MIDI files under `~/Music/ChordPumper Promarchy` are not deleted automatically.

## Development

Validate the repository without installing it:

```sh
omarchy plugin validate .
python3 -m py_compile engine/chordpumper_engine.py
```

The shell hot-reloads installed user plugin files. Follow [Contributing](CONTRIBUTING.md) for the development and test checklist.

## License

MIT. See [LICENSE](LICENSE).
