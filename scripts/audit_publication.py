#!/usr/bin/env python3
"""Heuristic source/app audit. Reports locations only, never matched values."""
import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import struct

ROOT_FILES = {
    "Package.swift", "Info.plist", "build.sh", ".gitignore", "README.md",
    "README.ko.md", "PROVENANCE.md", "LICENSE-STATUS.md", "SECURITY.md",
    "SOURCE-MANIFEST.json", "LICENSE", "CONTRIBUTING.md", "CHANGELOG.md",
    ".gitattributes", ".editorconfig",
}
ROOT_DIRS = {"Sources", "Tests", "Docs", "scripts", ".github"}
GITHUB_FILES = {
    ".github/workflows/ci.yml", ".github/dependabot.yml",
    ".github/ISSUE_TEMPLATE/bug_report.yml", ".github/ISSUE_TEMPLATE/feature_request.yml",
    ".github/ISSUE_TEMPLATE/config.yml", ".github/pull_request_template.md",
}
EXCLUDED_ROOTS = {".build", "Build", "Previews", "Backups", ".git", ".swiftpm", ".DS_Store"}
FORBIDDEN_SUFFIXES = {
    ".p12", ".pfx", ".p8", ".key", ".pem", ".cer", ".der", ".keystore",
    ".mobileprovision", ".provisionprofile", ".mov", ".mp4", ".log", ".trace",
    ".dmg", ".zip", ".pyc",
}
SOURCE_SUFFIXES = {".swift", ".metal", ".strings", ".txt", ".png", ".sh", ".py", ".md", ".yml", ".yaml"}
MAX_SOURCE_BYTES = 16 * 1024 * 1024
PATTERNS = {
    "private_key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----"),
    "github_token": re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{35,})\b"),
    "api_secret": re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{24,}\b"),
    "aws_access_key": re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    "slack_token": re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b"),
    "private_home_path": re.compile(r"/" r"Users/" r"[^/\s\"']+|/" r"home/" r"[^/\s\"']+|[A-Za-z]:\\Users\\[^\\\s]+"),
    "email_address": re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"),
    "assigned_secret": re.compile(r"""(?i)\b(?:api_key|apikey|secret_key|password|access_token)\s*[:=]\s*["'][^"'\s]{8,}["']"""),
}

def scan_text(text, label):
    findings = []
    for rule, pattern in PATTERNS.items():
        for match in pattern.finditer(text):
            findings.append({"rule": rule, "file": label, "line": text.count("\n", 0, match.start()) + 1})
    return findings

def allowed_source_path(relative):
    path = PurePosixPath(relative)
    parts = path.parts
    if not parts or path.is_absolute() or ".." in parts or "\\" in relative:
        return False
    if len(parts) == 1:
        return relative in ROOT_FILES
    if parts[0] == ".github":
        return relative in GITHUB_FILES
    return (parts[0] in ROOT_DIRS
            and not any(part.startswith(".") or part in {"__pycache__", "Backups", "Build", "Previews"} for part in parts[1:])
            and path.suffix.lower() in SOURCE_SUFFIXES)

def scan_source_data(data, label):
    findings, metadata = [], []
    if len(data) > MAX_SOURCE_BYTES:
        return [{"rule": "oversize_source_file", "file": label}], metadata
    if PurePosixPath(label).suffix.lower() in FORBIDDEN_SUFFIXES or PurePosixPath(label).name.startswith(".env"):
        findings.append({"rule": "excluded_file_type", "file": label})
    if PurePosixPath(label).suffix.lower() == ".png":
        if not data.startswith(b"\x89PNG\r\n\x1a\n"):
            findings.append({"rule": "invalid_png", "file": label})
        chunks = png_metadata(data)
        if chunks:
            metadata.append({"file": label, "metadata_chunks": chunks})
    else:
        try:
            findings += scan_text(data.decode("utf-8"), label)
        except UnicodeDecodeError:
            findings.append({"rule": "unexpected_binary", "file": label})
    return findings, metadata

def source_files(root):
    root = Path(root)
    files, findings = [], []
    for entry in sorted(root.iterdir()):
        if entry.name in EXCLUDED_ROOTS:
            continue
        if entry.is_symlink():
            findings.append({"rule": "symlink", "file": entry.name})
        elif entry.is_file() and entry.name in ROOT_FILES:
            files.append(entry)
        elif entry.is_dir() and entry.name in ROOT_DIRS:
            for current, dirs, names in os.walk(entry, followlinks=False):
                for name in list(dirs):
                    path = Path(current) / name
                    if path.is_symlink():
                        findings.append({"rule": "symlink", "file": path.relative_to(root).as_posix()})
                        dirs.remove(name)
                    elif name == "__pycache__":
                        dirs.remove(name)
                for name in sorted(names):
                    path = Path(current) / name
                    label = path.relative_to(root).as_posix()
                    if path.is_symlink():
                        findings.append({"rule": "symlink", "file": label})
                    elif not allowed_source_path(label):
                        findings.append({"rule": "unexpected_source_path", "file": label})
                    else:
                        files.append(path)
        else:
            findings.append({"rule": "unexpected_root_item", "file": entry.name})
    return sorted(files), findings

def png_metadata(data):
    kinds = []
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return kinds
    offset = 8
    while offset + 12 <= len(data):
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        if offset + size + 12 > len(data):
            return kinds + ["INVALID_CHUNK"]
        if kind in {b"eXIf", b"tEXt", b"zTXt", b"iTXt"}:
            kinds.append(kind.decode("ascii"))
        offset += size + 12
        if kind == b"IEND":
            break
    return kinds

def audit(root, app=None):
    root = Path(root).resolve()
    files, findings = source_files(root)
    metadata = []
    for path in files:
        label = path.relative_to(root).as_posix()
        if path.stat().st_size > MAX_SOURCE_BYTES:
            findings.append({"rule": "oversize_source_file", "file": label})
            continue
        detected, chunks = scan_source_data(path.read_bytes(), label)
        findings += detected
        metadata += chunks
    app_files = 0
    if app is not None:
        app = Path(app).resolve()
        if not app.is_relative_to(root / "Build"):
            raise ValueError("Only the prepared project's Build app may be scanned.")
        for path in sorted(app.rglob("*")):
            if path.is_symlink():
                findings.append({"rule": "app_symlink", "file": "APP/" + path.relative_to(app).as_posix()})
            elif path.is_file():
                app_files += 1
                # Latin-1 preserves ASCII strings in Mach-O and resource data.
                findings += scan_text(path.read_bytes().decode("latin-1"), "APP/" + path.relative_to(app).as_posix())
    package = (root / "Package.swift").read_text()
    capture = (root / "Sources/HingeVeil/DesktopCapture.swift").read_text()
    swift = "\n".join(path.read_text() for path in files if path.suffix == ".swift")
    network_apis = [name for name in ["URLSession", "NWConnection", "URLRequest", "AVAssetWriter", "SCRecordingOutput"] if name in swift]
    license_path = root / "LICENSE"
    mit_selected = license_path.is_file() and license_path.read_text().startswith("MIT License\n\nCopyright (c) 2026 bsl lab\n")
    return {
        "scope": "allowlisted source" + (" and prepared app" if app is not None else ""),
        "source_file_count": len(files),
        "app_file_count": app_files,
        "findings": findings,
        "png_metadata_for_review": metadata,
        "license_status": "MIT_selected_by_owner_rights_review_not_certified" if mit_selected else "pending_owner_choice_and_rights_review",
        "external_swift_package_declarations": bool(re.search(r"\.package\s*\(", package)),
        "named_network_or_recording_apis_in_swift": network_apis,
        "audio_capture_configured_off": "config.capturesAudio = false" in capture,
        "microphone_capture_configured_off": "config.captureMicrophone = false" in capture,
        "limitations": "Pattern matching is not proof of no secrets, vulnerabilities, dependencies, ownership disputes, or third-party rights."
    }

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--app", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = audit(args.root, args.app)
    output = json.dumps(report, indent=2, ensure_ascii=False)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output + "\n", encoding="utf-8")
    print(output)
    return 1 if report["findings"] or report["png_metadata_for_review"] else 0

if __name__ == "__main__":
    raise SystemExit(main())
