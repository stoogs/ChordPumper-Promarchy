# Publishing checklist

## Repository

- Public GitHub repository
- `manifest.json` at repository root
- Namespaced ID: `io.github.stoogs.chordpumper-promarchy`
- README, MIT license, changelog, and removal instructions
- Dependencies and unsandboxed permission boundary documented
- No symlinks, SoundFonts, generated MIDI, saved projects, or bytecode

## Validate

```sh
omarchy plugin validate .
python3 -m py_compile engine/chordpumper_engine.py
```

Install from the public repository and repeat the manual checklist in `CONTRIBUTING.md` before marketplace submission.

## Marketplace submission

Submit the public repository at:

<https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml>

Recommended listing values:

- Category: **Widgets**
- Tags: **Media**, **Bar**, **Quickshell**
- Suggested missing tag: **Music**
- Maintainer notes: Requires the official Arch packages `fluidsynth` and `soundfont-fluid`. The plugin runs a bundled standard-library Python process and FluidSynth with normal user permissions. It uses no network and writes only user-requested MIDI files under `~/Music/ChordPumper Promarchy`.

Automated validation checks the repository's current commit. Submit only after pushing the validated release commit.
