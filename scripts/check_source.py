#!/usr/bin/env python3
"""Check source package consistency without capture, hardware access or network calls."""
import json
from pathlib import Path
import plistlib
import re
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent

def check_source(root=ROOT):
    root = Path(root)
    info = plistlib.loads((root / "Info.plist").read_bytes())
    failures = []
    version = info["CFBundleShortVersionString"]
    for locale in ("en", "ko"):
        manual = (root / "Docs" / f"Manual.{locale}.md").read_bytes()
        bundled = (root / "Sources/HingeVeilCore/Resources" / f"Manual.{locale}.txt").read_bytes()
        if manual != bundled:
            failures.append("manual_resource_mismatch:" + locale)
        if version not in (root / ("README.md" if locale == "en" else "README.ko.md")).read_text():
            failures.append("readme_version_mismatch:" + locale)
    license_text = (root / "LICENSE").read_text()
    if not license_text.startswith("MIT License\n\nCopyright (c) 2026 bsl lab\n"):
        failures.append("license_identity_mismatch")
    if "Permission is hereby granted, free of charge" not in license_text or "THE SOFTWARE IS PROVIDED" not in license_text:
        failures.append("license_text_incomplete")
    workflow = (root / ".github/workflows/ci.yml").read_text()
    if "pull_request_target" in workflow or "secrets." in workflow or "self-hosted" in workflow:
        failures.append("unsafe_ci_context")
    if "contents: read" not in workflow or "persist-credentials: false" not in workflow:
        failures.append("ci_privilege_settings_missing")
    if not re.search(r"uses: actions/checkout@[a-f0-9]{40}\b", workflow):
        failures.append("checkout_not_pinned")
    docs = list(root.glob("*.md")) + list((root / "Docs").glob("*.md"))
    for document in docs:
        for target in re.findall(r"\[[^\]]*\]\(([^\s)]+)\)", document.read_text()):
            if "://" in target or target.startswith("#"):
                continue
            resolved = (document.parent / unquote(target.split("#", 1)[0])).resolve()
            if not resolved.is_relative_to(root.resolve()) or not resolved.exists():
                failures.append("broken_local_link:" + str(document.relative_to(root)))
    return {"version": version, "publisher": "bsl lab", "license": "MIT", "failures": failures}

if __name__ == "__main__":
    report = check_source()
    print(json.dumps(report, indent=2))
    raise SystemExit(1 if report["failures"] else 0)
