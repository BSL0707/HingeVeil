import hashlib
import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from check_source import check_source
from export_source import export

ROOT = Path(__file__).resolve().parent.parent

class ExportTests(unittest.TestCase):
    def test_source_consistency(self):
        self.assertEqual(check_source(ROOT)["failures"], [])

    def test_export_is_source_only_with_correct_manifest(self):
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "source.zip"
            count = export(ROOT, destination)
            with zipfile.ZipFile(destination) as archive:
                names = archive.namelist()
                self.assertEqual(len(names), len(set(names)))
                self.assertFalse(any(any(part in {"Build", ".build", "Backups", "Previews", ".git", "__pycache__"} for part in Path(name).parts) for name in names))
                self.assertIn("HingeVeil/LICENSE", names)
                self.assertIn("HingeVeil/.github/workflows/ci.yml", names)
                manifest = json.loads(archive.read("HingeVeil/SOURCE-MANIFEST.json"))
                self.assertEqual(len(names), count + 1)
                self.assertEqual(len(manifest["files"]), count)
                for entry in manifest["files"]:
                    path = Path(entry["path"])
                    self.assertFalse(path.is_absolute() or ".." in path.parts)
                    data = archive.read("HingeVeil/" + entry["path"])
                    self.assertEqual(entry["sha256"], hashlib.sha256(data).hexdigest())
                    self.assertEqual(entry["bytes"], len(data))

    def test_export_does_not_overwrite(self):
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "source.zip"
            destination.write_bytes(b"keep")
            with self.assertRaises(FileExistsError):
                export(ROOT, destination)
            self.assertEqual(destination.read_bytes(), b"keep")

    def test_export_blocks_unexpected_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "Package.swift").write_text("import PackageDescription")
            (root / "Sources/HingeVeil").mkdir(parents=True)
            (root / "Sources/HingeVeil/DesktopCapture.swift").write_text("fixture")
            (root / ".env").write_text("fixture")
            with self.assertRaises(ValueError):
                export(root, root / "source.zip")

if __name__ == "__main__":
    unittest.main()
