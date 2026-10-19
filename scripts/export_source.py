#!/usr/bin/env python3
"""Create a local source-only ZIP after a heuristic audit. Never uploads."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile
from audit_publication import audit, source_files

def export(root, destination):
    root = Path(root).resolve()
    destination = Path(destination).resolve()
    if destination.exists():
        raise FileExistsError("Refusing to overwrite an existing archive.")
    report = audit(root)
    if report["findings"] or report["png_metadata_for_review"]:
        raise ValueError("Audit findings must be resolved before exporting.")
    files, findings = source_files(root)
    if findings:
        raise ValueError("The source allowlist is not clean.")
    entries = []
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            relative = path.relative_to(root).as_posix()
            if relative == "SOURCE-MANIFEST.json":
                continue
            data = path.read_bytes()
            name = "HingeVeil/" + relative
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 18, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (0o100755 if path.suffix == ".sh" else 0o100644) << 16
            archive.writestr(info, data)
            entries.append({"path": relative, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
        manifest = {"status": "local source export; not uploaded", "license": report["license_status"], "files": entries}
        info = zipfile.ZipInfo("HingeVeil/SOURCE-MANIFEST.json", date_time=(2026, 10, 18, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(info, json.dumps(manifest, indent=2, ensure_ascii=False).encode("utf-8"))
    return len(entries)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    print(json.dumps({"source_files": export(args.root, args.destination), "uploaded": False}))
