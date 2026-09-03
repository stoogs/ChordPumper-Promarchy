# Changelog

All notable changes to ChordPumper Promarchy are documented here.

## 1.7.0 — 2026-09-02

- Added a zero-setup Basic Keys synthesizer using Omarchy's packaged PipeWire playback tool.
- Kept the richer FluidSynth Acoustic Grand Piano as an automatically detected optional Pro engine.
- Added a compact Basic / Pro selector with clear optional-upgrade guidance.
- Made the unavailable Pro guidance friendly and clickable, linking directly to the optional FluidSynth setup.
- Bounded Basic synthesis voices, command queues, PCM output, diagnostics, and player teardown.
- Moved the one-command install to the top of the README and made the optional Pro command prominent.

## 1.6.5 — 2026-09-02

- Bound Python and FluidSynth execution to trusted packaged absolute paths.
- Walked and created every MIDI export directory from a trusted home-directory descriptor with no-follow checks.
- Kept the FluidSynth leader unreaped while verifying and escalating teardown across its complete process group.
- Added regression coverage for symlinked ancestors and a leader that exits while a TERM-ignoring descendant survives.
- Blocked out-of-range high voicings in the UI before playback or take history recording.

## 1.6.4 — 2026-09-01

- Made MIDI publication atomic, private, no-follow, and no-clobber.
- Added strict bounds for take history, export arguments, MIDI values, control messages, and generated output.
- Supervised FluidSynth as a process group with bounded diagnostic draining and complete quit/terminate/kill teardown.
- Rendered runtime status explicitly as plain text and stopped forwarding raw synthesizer diagnostics.
- Added regression tests for event validation and symlink-safe MIDI export.

## 1.6.3 — 2026-08-31

- Added a pixel-faithful live marketplace preview.
- Made the `1–0` chord tiles non-interactive so they no longer imply mouse selection or playback.
- Removed the unused chord-selection state from whole-instrument randomization.

## 1.6.2 — 2026-08-31

- Added a Clear MIDI control for starting a fresh take.
- Required a second confirmation click within five seconds before deleting session history.
- Made clearing reset both the complete MIDI event history and the visible Recent strip.

## 1.6.1 — 2026-08-31

- Replaced the wide bar label with a compact piano icon and retained the full name in its tooltip.
- Removed unused theory helpers left over from early prototypes.
- Cleaned the release documentation for the MIDI-only v1 workflow.

## 1.6.0 — 2026-08-31

- Changed MIDI export to include the complete session history of heard notes and chords in playback order.
- Added descriptive `style-key-scale-palette-date-time.mid` filenames.
- Removed project Save from the interface and engine because projects cannot yet be loaded.

## 1.5.0 — 2026-08-31

- Expanded the style chord row from six to ten playable slots mapped to `1–9` and `0`.
- Preserved each Core palette's original `1–6` mapping and added four genre-specific colour chords on `7–0`.
- Expanded Alternate, Colour, and Shuffle modes across all ten chord slots.

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
