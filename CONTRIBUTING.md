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
python3 -m unittest discover -s tests -v
```

Then verify:

- Bar click, shell summon, Escape, and shell hide
- Physical and mouse note-on/note-off
- No stuck notes after closing the panel
- All 24 style choices
- `1–9` and `0` chord playback
- Core, Alternate, Colour, and repeated Shuffle chord palettes for every style
- Momentary and locked chord shapes
- All scale roots, all twelve scale types, and all four scale-lock modes
- Requested keys use the accent color and snapped destination notes use the urgent color
- Piano colors update correctly when the active Omarchy theme changes
- Style cycling with `<`
- Random style, chord, and chord-shape selection
- Empty-history handling and full played-history MIDI export
- Atomic MIDI export and event/value limit regression tests
- Symlinked export-ancestor and surviving process-group descendant regression tests
- Clear MIDI confirmation, five-second cancellation, and new-take behavior
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

Display names should remain clear and compact. Use the established `Dom`, `Sus`, and `Dim` abbreviations for long qualities rather than exposing internal quality codes.

## Pull requests

Keep changes focused, document visible behavior, and update `CHANGELOG.md` when appropriate. Do not commit generated MIDI, SoundFonts, package caches, or Python bytecode.
