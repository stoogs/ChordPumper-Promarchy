# Changelog

All notable changes to ChordPumper Promarchy are documented here.

## 1.4.0 — 2026-08-31

- Added Core, Alternate, Colour, and repeatable Shuffle palettes for the `1–6` chord row.
- Kept generated chords constrained to each style's authored roots and chord vocabulary.
- Included a shuffled chord palette in whole-instrument randomization.

## 1.3.0 — 2026-08-31

- Added a compact 4×3 selector with twelve scales, including pentatonic, blues, minor variants, and all seven diatonic modes.
- Extended scale highlighting and every lock mode to all selectable scales.
- Made dimmed black keys opaque so white-key divider lines cannot show through them.

## 1.2.0 — 2026-08-31

- Renamed Nearest Note and Nearest Chord to the clearer Note Snap and Chord Snap.
- Made Chord Snap preserve the full chord shape and reject voicings with no exact in-scale transposition.
- Removed the internal `Fit` marker from chord history.
- Added distinct theme-derived feedback for requested and scale-corrected piano keys.
- Replaced the piano's fixed palette with the active Omarchy theme colors.

## 1.1.1 — 2026-08-31

- Enabled Nearest Note scale lock by default so scale selection has an immediate effect.
- Made root and scale-type selection activate Nearest Note when locking was Off.
- Added the active lock mode and available scale tones to the panel readout.

## 1.1.0 — 2026-08-31

- Added twelve-root major/minor scale lock with nearest-note, nearest-chord, and strict behavior.
- Added scale-tone highlighting on the piano keyboard.
- Added compact `Dom`, `Sus`, and `Dim` labels.
- Changed recent history to show played chord events instead of constituent chord tones.

## 1.0.0 — 2026-08-31

- Initial public release.
- Added a one-octave keyboard with physical and mouse input.
- Added FluidSynth and PipeWire playback.
- Added 24 style-specific chord palettes.
- Added six playable style chords and eight momentary or lockable shapes.
- Added style, chord, and chord-shape randomization.
- Added recent-note history.
- Added JSON project saving and Standard MIDI export.
