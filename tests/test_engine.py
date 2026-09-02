import json
import os
import signal
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path

from engine.chordpumper_engine import (
    MAX_EVENTS,
    MAX_EVENTS_JSON_BYTES,
    atomic_write_no_follow,
    midi_bytes,
    parse_events,
    process_group_members,
    stop_process_group,
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
    def output_path(self, home: Path, name: str = "take.mid") -> Path:
        return home / "Music" / "ChordPumper Promarchy" / name

    def test_refuses_symlink_without_touching_its_target(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory)
            output = self.output_path(home)
            output.parent.mkdir(parents=True)
            victim = home / "victim"
            victim.write_bytes(b"keep me")
            output.symlink_to(victim)

            with self.assertRaises(FileExistsError):
                atomic_write_no_follow(output, b"safe midi", home=home)

            self.assertTrue(output.is_symlink())
            self.assertEqual(victim.read_bytes(), b"keep me")

    def test_publishes_new_file_with_private_permissions(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory)
            output = self.output_path(home)
            atomic_write_no_follow(output, b"safe midi", home=home)
            self.assertEqual(output.read_bytes(), b"safe midi")
            self.assertEqual(os.stat(output).st_mode & 0o777, 0o600)

    def test_rejects_symlinked_output_directory(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory)
            music_directory = home / "Music"
            music_directory.mkdir()
            real_directory = home / "real"
            real_directory.mkdir()
            linked_directory = music_directory / "ChordPumper Promarchy"
            linked_directory.symlink_to(real_directory, target_is_directory=True)

            with self.assertRaises(OSError):
                atomic_write_no_follow(self.output_path(home), b"blocked", home=home)

    def test_rejects_symlinked_ancestor(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory)
            real_directory = home / "redirected"
            real_directory.mkdir()
            (home / "Music").symlink_to(real_directory, target_is_directory=True)

            with self.assertRaises(OSError):
                atomic_write_no_follow(self.output_path(home), b"blocked", home=home)
            self.assertEqual(list(real_directory.iterdir()), [])

    def test_rejects_output_outside_fixed_tree(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory)
            with self.assertRaises(ValueError):
                atomic_write_no_follow(home / "elsewhere.mid", b"blocked", home=home)


class ProcessGroupTests(unittest.TestCase):
    def test_kills_term_ignoring_descendant_after_leader_exits(self):
        child_code = (
            "import signal,time;"
            "signal.signal(signal.SIGTERM, signal.SIG_IGN);"
            "print('ready', flush=True);"
            "time.sleep(60)"
        )
        leader_code = (
            "import subprocess,sys;"
            f"child=subprocess.Popen([sys.executable,'-c',{child_code!r}],"
            "stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True);"
            "child.stdout.readline();"
            "print(child.pid, flush=True)"
        )
        leader = subprocess.Popen(
            [sys.executable, "-c", leader_code],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
        )
        self.assertIsNotNone(leader.stdout)
        self.assertIsNotNone(leader.stderr)
        child_pid = int(leader.stdout.readline())
        drain_thread = threading.Thread(target=leader.stderr.read, daemon=True)
        drain_thread.start()
        time.sleep(0.1)
        try:
            stop_process_group(
                leader,
                lambda: None,
                drain_thread,
                graceful_timeout=0.05,
                terminate_timeout=0.1,
                kill_timeout=2.0,
            )
            self.assertEqual(process_group_members(leader.pid, leader.pid), set())
            self.assertFalse(Path(f"/proc/{child_pid}").exists())
        finally:
            try:
                os.killpg(leader.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            try:
                leader.wait(timeout=1)
            except subprocess.TimeoutExpired:
                pass


if __name__ == "__main__":
    unittest.main()
