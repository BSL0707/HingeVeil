#!/usr/bin/env python3
"""Offline heuristic audit of the index and all reachable Git commits. Never prints values."""
import argparse
import json
from pathlib import Path
import re
import subprocess

from audit_publication import allowed_source_path, scan_source_data, scan_text, MAX_SOURCE_BYTES

def git(root, *args, allow_failure=False):
    result = subprocess.run(["git", "-C", str(root), *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode and not allow_failure:
        raise ValueError("Git inspection failed; raw command output was withheld.")
    return result

def audit_history(root):
    root = Path(root).resolve()
    result = git(root, "rev-parse", "--show-toplevel", allow_failure=True)
    report = {"status": "not_initialized", "commits_scanned": 0, "unique_file_versions_scanned": 0,
              "findings": [], "limitations": "Heuristic checks only; unreachable objects, reflogs, remotes, Git LFS, stashes and untracked files are not certified."}
    if result.returncode:
        if (root / ".git").exists():
            raise ValueError("A Git marker exists but cannot be inspected.")
        return report
    if Path(result.stdout.decode().strip()).resolve() != root:
        raise ValueError("Refusing to inspect a parent or different repository.")
    if git(root, "rev-parse", "--is-shallow-repository").stdout.strip() == b"true":
        raise ValueError("A shallow clone cannot establish a full reachable-history check; fetch full history first.")
    commits = git(root, "rev-list", "--all").stdout.decode().splitlines()
    if len(commits) > 5000:
        raise ValueError("History exceeds the 5,000-commit safety limit; arrange a dedicated audit.")
    report["status"] = "checked"
    seen = set()

    def inspect(mode, object_type, oid, path, context):
        if not allowed_source_path(path):
            report["findings"].append({"rule": "excluded_git_path", "file": path, "context": context})
        if mode not in {"100644", "100755"} or object_type != "blob":
            report["findings"].append({"rule": "git_link_or_submodule", "file": path, "context": context})
            return
        identity = (oid, path)
        if identity in seen:
            return
        seen.add(identity)
        if len(seen) > 100000:
            raise ValueError("File-version safety limit reached; arrange a dedicated audit.")
        size = int(git(root, "cat-file", "-s", oid).stdout)
        if size > MAX_SOURCE_BYTES:
            report["findings"].append({"rule": "oversize_git_blob", "file": path, "context": context})
            return
        found, metadata = scan_source_data(git(root, "cat-file", "blob", oid).stdout, path)
        found += [{"rule": "png_metadata", "file": item["file"]} for item in metadata]
        report["findings"] += [dict(item, context=context) for item in found]

    for record in git(root, "ls-files", "--stage", "-z").stdout.split(b"\0"):
        if not record:
            continue
        header, raw_path = record.split(b"\t", 1)
        mode, oid, stage = header.decode().split()
        path = raw_path.decode("utf-8")
        if stage != "0":
            report["findings"].append({"rule": "unmerged_index", "file": path})
            continue
        inspect(mode, "blob", oid, path, "index")
    for commit in commits:
        metadata = git(root, "cat-file", "commit", commit).stdout.decode("utf-8", errors="replace")
        # GitHub no-reply addresses are public commit aliases, not private emails.
        metadata = re.sub(r"[A-Za-z0-9._%+-]+@users\.noreply\.github\.com", "PUBLIC_NOREPLY", metadata)
        report["findings"] += scan_text(metadata, "commit:" + commit[:12])
        for record in git(root, "ls-tree", "-r", "-z", "--full-tree", commit).stdout.split(b"\0"):
            if record:
                header, raw_path = record.split(b"\t", 1)
                mode, kind, oid = header.decode().split()
                inspect(mode, kind, oid, raw_path.decode("utf-8"), commit[:12])
        report["commits_scanned"] += 1
    report["unique_file_versions_scanned"] = len(seen)
    return report

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    try:
        report = audit_history(args.root)
    except (ValueError, UnicodeError, OSError):
        print(json.dumps({"status": "incomplete", "error": "History inspection could not complete. Check repository root, full history and safety limits; raw values withheld."}))
        return 1
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 1 if report["findings"] else 0

if __name__ == "__main__":
    raise SystemExit(main())
