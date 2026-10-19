import tempfile
import unittest
from pathlib import Path
from audit_publication import scan_text, source_files, png_metadata, allowed_source_path, scan_source_data

class AuditTests(unittest.TestCase):
    def test_secrets_are_redacted(self):
        fake = "gh" + "p_" + "A" * 36
        found = scan_text(fake, "fixture.txt")
        self.assertEqual(found[0]["rule"], "github_token")
        self.assertNotIn(fake, str(found))
    def test_private_path_is_reported_without_value(self):
        value = "/" + "Users/" + "example-person/file"
        found = scan_text(value, "fixture.txt")
        self.assertEqual(found[0]["rule"], "private_home_path")
        self.assertNotIn(value, str(found))
    def test_regular_swift_tokens_are_not_credentials(self):
        self.assertEqual(scan_text("let token = generation\nlet key = id", "sample.swift"), [])
    def test_allowlist_excludes_build_and_rejects_unexpected_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "Sources").mkdir()
            (root / "Sources" / "App.swift").write_text("import Foundation")
            (root / "Build").mkdir()
            (root / "Build" / "private.log").write_text("do not export")
            (root / ".env").write_text("fixture")
            files, findings = source_files(root)
            self.assertEqual([p.name for p in files], ["App.swift"])
            self.assertTrue(any(item["file"] == ".env" for item in findings))
    def test_symlinks_are_not_followed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "Sources").mkdir()
            (root / "Sources" / "link").symlink_to(root / "outside")
            _, findings = source_files(root)
            self.assertEqual(findings[0]["rule"], "symlink")
    def test_non_png_has_no_png_metadata(self):
        self.assertEqual(png_metadata(b"not an image"), [])
    def test_github_allowlist_is_explicit(self):
        self.assertTrue(allowed_source_path(".github/workflows/ci.yml"))
        self.assertFalse(allowed_source_path(".github/workflows/deploy.yml"))
        self.assertFalse(allowed_source_path("Sources/.env"))
        self.assertFalse(allowed_source_path("Sources/cache.pyc"))
        self.assertFalse(allowed_source_path("../README.md"))
        self.assertFalse(allowed_source_path("/README.md"))
    def test_invalid_png_cannot_hide_binary(self):
        found, _ = scan_source_data(b"not png", "Sources/fake.png")
        self.assertEqual(found[0]["rule"], "invalid_png")
    def test_new_signing_key_types_are_not_allowlisted(self):
        self.assertFalse(allowed_source_path("Sources/signing.p8"))
        self.assertFalse(allowed_source_path("Sources/signing.provisionprofile"))

if __name__ == "__main__":
    unittest.main()
