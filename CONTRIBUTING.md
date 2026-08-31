# Contributing

Contributions, new musical styles, bug reports, and accessibility improvements are welcome.

## Development setup

1. Use an up-to-date Omarchy installation.
2. Install `fluidsynth` and `soundfont-fluid` with `omarchy pkg add`.
3. Fork and clone this repository.
4. Install the fork with `omarchy plugin add <your-git-url> --enable`.
5. Edit the installed user-owned copy under `~/.config/omarchy/plugins/io.github.stoogs.chordpumper-promarchy/` while testing.

Never edit packaged files beneath `/usr/share/omarchy`.

## Validation

Run before submitting a change:

```sh
omarchy plugin validate .
python3 -m py_compile engine/chordpumper_engine.py
```

Then verify:

- Bar click, shell summon, Escape, and shell hide
- Physical and mouse note-on/note-off
- No stuck notes after closing the panel
- All 24 style choices
- `1–6` chord playback
- Momentary and locked chord shapes
- Style cycling with `<`
- Random progression generation
- Save and MIDI export
- Shell restart and plugin re-enable

Inspect runtime errors with:

```sh
qs log -p "$OMARCHY_PATH/shell" --tail 150
```

## Adding a style

Styles live in `Styles.js`. Each entry must contain exactly:

- A unique, readable style name
- Eight supported chord-shape quality codes
- Six chord entries expressed as root offset, quality code, and harmonic label

Add any new quality to all three locations:

1. `Model.js` interval definitions
2. `Model.js` full-name definitions
3. `engine/chordpumper_engine.py` MIDI interval definitions

Display names must be written in full; do not expose unexplained quality codes in the interface.

## Pull requests

Keep changes focused, document visible behavior, and update `CHANGELOG.md` when appropriate. Do not commit generated MIDI, saved projects, SoundFonts, package caches, or Python bytecode.
