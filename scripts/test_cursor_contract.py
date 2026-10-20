"""Screen capture must never burn a second cursor into effect frames."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parent.parent

class CursorContractTests(unittest.TestCase):
    def test_stream_excludes_cursor_without_hiding_system_cursor(self):
        capture = (ROOT / "Sources/HingeVeil/DesktopCapture.swift").read_text()
        self.assertRegex(capture, r"config\.showsCursor\s*=\s*false\b")
        self.assertNotRegex(capture, r"showsCursor\s*=\s*true\b")
        for source in (ROOT / "Sources").rglob("*.swift"):
            self.assertNotRegex(source.read_text(), r"NSCursor\s*\.\s*(?:hide|unhide)\s*\(")
        self.assertIn("config.capturesAudio = false", capture)

if __name__ == "__main__":
    unittest.main()
