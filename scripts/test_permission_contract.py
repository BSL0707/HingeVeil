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

    def test_reset_requires_confirmation_and_fixed_scope_helper(self):
        view = (ROOT / "Sources/HingeVeil/SettingsView.swift").read_text()
        self.assertIn("권한 복구…", view)
        method = self.controller.split("func requestPermissionRecovery()", 1)[1].split("private func consumePermissionRecovery()", 1)[0]
        self.assertIn("guard alert.runModal() == .alertFirstButtonReturn, !isReviewMode else { return }", method)
        self.assertIn("try session.commit()", method)
        self.assertIn("NSApp.terminate(nil)", method)
        self.assertNotIn("CGRequestScreenCaptureAccess", method)
        self.assertNotIn("Process()", self.controller)
        core = (ROOT / "Sources/HingeVeilCore/PermissionRecovery.swift").read_text()
        self.assertIn('["reset", "ScreenCapture", bundleID]', core)
        self.assertIn('bundleID = "com.bsl0707.hingeveil.preview"', core)
        self.assertIn("guard parentExited, request.isValid(now: now)", core)
        helper = (ROOT / "Sources/HingeVeilRecovery/main.swift").read_text()
        self.assertIn("getppid() == parent", helper)
        self.assertIn("SecCodeCheckValidity(guest, [], requirement)", helper)
        self.assertIn("String(data: commit, encoding: .utf8) == PermissionRecovery.commit", helper)
        self.assertIn('run("/usr/bin/tccutil", arguments: PermissionRecovery.resetArguments', helper)
        self.assertLess(helper.index("if fixture {"), helper.index('run("/usr/bin/tccutil"'))
        for forbidden in ["reset All", "/bin/sh", "sudo", "kTCCServiceAll"]:
            self.assertNotIn(forbidden, helper)

    def test_recovery_is_never_called_by_startup_or_timer(self):
        self.assertEqual(self.controller.count("func requestPermissionRecovery()"), 1)
        self.assertNotIn("requestPermissionRecovery()", self.controller.split("func requestPermissionRecovery()", 1)[0])
        launcher = (ROOT / "Sources/HingeVeil/PermissionRecoveryLauncher.swift").read_text()
        self.assertIn("fixture || PermissionRecovery.installedLocation(app)", launcher)
        self.assertIn("guard !committed else { return false }", launcher)
        self.assertNotIn("tccutil", launcher)

if __name__ == "__main__":
    unittest.main()
