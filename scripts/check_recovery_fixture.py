#!/usr/bin/env python3
"""Exercise private-pipe helper handshake using only the mock reset backend."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "Build/HingeVeil.app/Contents/MacOS/HingeVeil"

def check():
    for flag, expected in [
        ("--check-permission-recovery", "passed=true, parentExited=true, mockReset=1, mockRelaunch=1"),
        ("--check-recovery-cancel", "Recovery cancel fixture: passed=true"),
    ]:
        process = subprocess.Popen([str(APP), flag], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        # Reap the parent before draining inherited helper output. Otherwise a
        # zombie PID still answers kill(pid, 0), correctly blocking the reset.
        try:
            code = process.wait(timeout=8)
            stdout, stderr = process.communicate(timeout=15)
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()
            raise
        output = stdout + stderr
        if code or expected not in output or "NO OS permission changes" not in output:
            raise RuntimeError(f"Safe recovery fixture failed: {flag}: {output}")
        print(output.strip())
    helper = APP.parent.parent / "Helpers/HingeVeilRecovery"
    invalid = subprocess.run([str(helper), "--recover", "1"], capture_output=True, timeout=3)
    if invalid.returncode != 2:
        raise RuntimeError("Helper accepted an invalid parent")
    print("Recovery process fixtures passed; no OS permission changes.")

if __name__ == "__main__":
    check()
