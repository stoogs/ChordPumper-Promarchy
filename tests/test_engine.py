import json
import os
import tempfile
import unittest
from pathlib import Path

from engine.chordpumper_engine import (
    MAX_EVENTS,
    MAX_EVENTS_JSON_BYTES,
    atomic_write_no_follow,
    midi_bytes,
    parse_events,
)


class EventValidationTests(unittest.TestCase):
    def test_accepts_bounded_integer_notes(self):
        self.assertEqual(parse_events('[{"notes":[0,60,127]}]'), [[0, 60, 127]])

    def test_rejects_non_integer_and_out_of_range_notes(self):
        for note in (True, 60.5, "60", -1, 128):
            with self.subTest(note=note), self.assertRaises(ValueError):
                parse_events(json.dumps([{"notes": [note]}]))

    def test_rejects_too_many_events(self):
        raw = json.dumps([{"notes": [60]}] * (MAX_EVENTS + 1))
        with self.assertRaises(ValueError):
            parse_events(raw)

    def test_rejects_oversized_json_before_parsing(self):
        with self.assertRaises(ValueError):
            parse_events(" " * (MAX_EVENTS_JSON_BYTES + 1))

    def test_midi_has_standard_header(self):
        self.assertTrue(midi_bytes(110, [[60, 64, 67]]).startswith(b"MThd"))


class AtomicExportTests(unittest.TestCase):
    def test_refuses_symlink_without_touching_its_target(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            victim = directory / "victim"
            victim.write_bytes(b"keep me")
            output = directory / "take.mid"
            output.symlink_to(victim)

            with self.assertRaises(FileExistsError):
                atomic_write_no_follow(output, b"safe midi")

            self.assertTrue(output.is_symlink())
            self.assertEqual(victim.read_bytes(), b"keep me")

    def test_publishes_new_file_with_private_permissions(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            output = Path(temporary_directory) / "take.mid"
            atomic_write_no_follow(output, b"safe midi")
            self.assertEqual(output.read_bytes(), b"safe midi")
            self.assertEqual(os.stat(output).st_mode & 0o777, 0o600)

    def test_rejects_symlinked_output_directory(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            real_directory = root / "real"
            real_directory.mkdir()
            linked_directory = root / "linked"
            linked_directory.symlink_to(real_directory, target_is_directory=True)

            with self.assertRaises(OSError):
                atomic_write_no_follow(linked_directory / "take.mid", b"blocked")


if __name__ == "__main__":
    unittest.main()
