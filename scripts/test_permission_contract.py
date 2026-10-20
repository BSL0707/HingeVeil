"""Static integration checks: never trigger an OS permission dialog in CI."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent

class PermissionContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.controller = (ROOT / "Sources/HingeVeil/AppController.swift").read_text()

    def test_system_request_is_only_in_explicit_button_handler(self):
        self.assertEqual(self.controller.count("CGRequestScreenCaptureAccess()"), 1)
        handler = self.controller.split("func requestPermission()", 1)[1].split("func openPermissionSettings()", 1)[0]
        self.assertIn("permissionState.beginRequest()", handler)
        self.assertIn("CGRequestScreenCaptureAccess()", handler)

    def test_effect_and_test_recheck_without_requesting(self):
        for name in ["setEnabled(_ value: Bool)", "runTest()"]:
            method = self.controller.split("func " + name, 1)[1].split("\n    func ", 1)[0]
            self.assertIn("refreshPermission(announce: true)", method)
            self.assertNotIn("requestPermission()", method)

    def test_foreground_refresh_is_read_only_and_throttled(self):
        self.assertIn("NSApplication.didBecomeActiveNotification", self.controller)
        self.assertIn("NSApp.isActive && now - lastPermissionCheck >= 1", self.controller)
        refresh = self.controller.split("func refreshPermission(", 1)[1].split("func requestPermission()", 1)[0]
        self.assertIn("CGPreflightScreenCaptureAccess()", refresh)
        self.assertNotIn("CGRequestScreenCaptureAccess", refresh)
        self.assertIn("await capture.stop()", refresh)

    def test_reset_is_documented_but_never_executed_by_app(self):
        view = (ROOT / "Sources/HingeVeil/SettingsView.swift").read_text()
        self.assertIn("tccutil reset ScreenCapture com.bsl0707.hingeveil.preview", view)
        for source in (ROOT / "Sources").rglob("*.swift"):
            self.assertNotIn('URL(fileURLWithPath: "/usr/bin/tccutil")', source.read_text())
        self.assertNotIn("Process()", self.controller)

if __name__ == "__main__":
    unittest.main()
