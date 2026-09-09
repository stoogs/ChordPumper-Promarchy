import re
import unittest
from pathlib import Path


PANEL = Path(__file__).resolve().parents[1] / "Panel.qml"


class PanelLayoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = PANEL.read_text(encoding="utf-8")

    def integer_property(self, name: str) -> int:
        match = re.search(rf"readonly property int {re.escape(name)}: (\d+)", self.source)
        self.assertIsNotNone(match, f"Panel.qml must declare {name}")
        return int(match.group(1))

    def test_synth_row_fits_design_width(self):
        panel = self.integer_property("synthPanelBudget")
        left = (
            self.integer_property("synthMainLabelWidth")
            + self.integer_property("synthVoiceDropdownWidth")
            + 3
            * (
                self.integer_property("synthParameterLabelWidth")
                + self.integer_property("synthParameterSliderWidth")
                + self.integer_property("synthInnerGap")
            )
            + 4 * self.integer_property("synthControlGap")
        )
        cutoff = (
            self.integer_property("synthCutoffShortcutWidth")
            + self.integer_property("synthCutoffLabelWidth")
            + self.integer_property("synthCutoffSliderWidth")
            + 12  # Two fixed 6px gaps in characterControls.
        )
        outer_gaps = 2 * self.integer_property("synthOuterGap")
        self.assertLessEqual(left + cutoff + outer_gaps, panel)

    def test_instrument_selector_order(self):
        organ = self.source.index('text: "Organ"')
        keyboard = self.source.index('text: "Keyboard"')
        piano = self.source.index('text: "Piano"')
        synth = self.source.index('text: "Synth"')
        self.assertLess(organ, keyboard)
        self.assertLess(keyboard, piano)
        self.assertLess(piano, synth)

    def test_keyboard_uses_fluid_engine(self):
        self.assertIn('function activateKeyboard() { selectAudioBackend("keyboard-fluid") }', self.source)
        self.assertNotIn('Electric Soul', self.source)

    def test_header_text_cannot_overlap_controls(self):
        self.assertIn('width: Math.max(0, parent.width - headerControls.width', self.source)
        self.assertIn('clip: true', self.source)
        self.assertGreaterEqual(self.source.count('elide: Text.ElideRight'), 2)

    def test_random_button_is_icon_only(self):
        random_button = self.source.index('tooltipText: "Randomize everything"')
        self.assertIn('text: ""', self.source[random_button - 100:random_button])
        self.assertIn('width: Style.spacing.controlHeight', self.source[random_button:random_button + 300])

    def test_compact_chord_key_strip_and_octave_two(self):
        self.assertIn('+ " · " + modelData.roman', self.source)
        self.assertIn('octave = Math.max(2, octave - 1)', self.source)

    def test_velvet_choir_replaces_neon_keys(self):
        self.assertNotIn('Neon Keys', self.source)
        self.assertIn('Velvet Choir', self.source)

    def test_distinct_dark_synth_voices(self):
        self.assertNotIn('Deep Orbit', self.source)
        self.assertNotIn('Acid Fizz', self.source)
        self.assertIn('Shadow Cello', self.source)
        self.assertNotIn('Acid Growl', self.source)
        self.assertIn('Iron Cathedral', self.source)

    def test_cinematic_synth_replacements(self):
        self.assertNotIn('Soft Pulse', self.source)
        self.assertNotIn('Analog Brass', self.source)
        self.assertIn('Moon Harp', self.source)
        self.assertIn('Aurora Flute', self.source)
        self.assertNotIn('Warm Pad', self.source)
        self.assertNotIn('Juno Silk', self.source)
        self.assertIn('Analogue Silk', self.source)


if __name__ == "__main__":
    unittest.main()
