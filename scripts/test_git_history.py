import subprocess
import tempfile
import unittest
from pathlib import Path
from check_git_history import audit_history

class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.run_git("init", "-q")
        self.run_git("config", "user.name", "Fixture")
        self.run_git("config", "user.email", "fixture" + "@" + "users.noreply.github.com")
        # Ensure test commits cannot invoke a user's configured signing program.
        self.run_git("config", "commit.gpgsign", "false")
        (self.root / "Sources").mkdir()

    def run_git(self, *args):
        return subprocess.run(["git", "-C", str(self.root), *args], check=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def commit(self):
        self.run_git("add", ".")
        self.run_git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "fixture")

    def test_clean_commits_and_index(self):
        (self.root / "Sources/App.swift").write_text("import Foundation\n")
        self.commit()
        report = audit_history(self.root)
        self.assertEqual(report["commits_scanned"], 1)
        self.assertEqual(report["findings"], [])

    def test_deleted_secret_is_still_found_in_history(self):
        fake = "gh" + "p_" + "A" * 36
        path = self.root / "Sources/App.swift"
        path.write_text(fake)
        self.commit()
        path.write_text("import Foundation\n")
        self.commit()
        report = audit_history(self.root)
        self.assertTrue(any(item["rule"] == "github_token" for item in report["findings"]))
        self.assertNotIn(fake, str(report))

    def test_staged_excluded_path_is_reported(self):
        (self.root / ".env").write_text("fixture")
        self.run_git("add", ".env")
        self.assertTrue(any(item["rule"] == "excluded_git_path" for item in audit_history(self.root)["findings"]))

    def test_parent_repository_is_rejected(self):
        with self.assertRaises(ValueError):
            audit_history(self.root / "Sources")

    def test_staged_symlink_is_rejected(self):
        (self.root / "Sources/link.txt").symlink_to(self.root / "outside")
        self.run_git("add", "Sources/link.txt")
        self.assertTrue(any(item["rule"] == "git_link_or_submodule" for item in audit_history(self.root)["findings"]))

    def test_uninitialized_folder_is_explicit(self):
        with tempfile.TemporaryDirectory() as other:
            self.assertEqual(audit_history(other)["status"], "not_initialized")

    def test_personal_commit_email_is_redacted(self):
        private_alias = "person" + "@" + "example.invalid"
        self.run_git("config", "user.email", private_alias)
        (self.root / "Sources/App.swift").write_text("import Foundation\n")
        self.commit()
        report = audit_history(self.root)
        self.assertTrue(any(item["rule"] == "email_address" for item in report["findings"]))
        self.assertNotIn(private_alias, str(report))
