#!/usr/bin/env python3
"""
Build the Trackside package zip (installable with Ethos Suite, or unzip the
trackside/ folder onto the radio's SCRIPTS folder).

Zip layout:
    ethos_lua_manifest.json
    trackside/...              copy of src/trackside (no .luac)

The staged main.lua gets trackside.BUILD = "<artifact version>", so the radio
shows which build it runs (Check setup). The manifest version must be X.Y.Z:
it is taken from the artifact version when that starts with X.Y.Z, otherwise
from trackside.VERSION in main.lua.

Usage:
    python bin/package/build_package.py --artifact-version 0.1.0
    python bin/package/build_package.py --artifact-version commit-abc1234 --output-dir dist
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import tempfile
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

REPO = Path(__file__).resolve().parents[2]
SRC = REPO / "src" / "trackside"
FOLDER = "trackside"
MANIFEST = "ethos_lua_manifest.json"

# Saved by Ethos Suite to recognise updates: never change after a release.
PACKAGE_KEY = "com.github.robthomson.trackside"
PACKAGE_NAME = "Trackside"

VERSION_RE = re.compile(r'trackside\.VERSION\s*=\s*"(\d+\.\d+\.\d+)"')
BUILD_RE = re.compile(r'(trackside\.BUILD\s*=\s*")([^"]*)(")')
XYZ_RE = re.compile(r"^(\d+\.\d+\.\d+)")
NOTES_MAX = 32000
SKIP = shutil.ignore_patterns("*.luac", "__pycache__", "*.tmp")


def base_version() -> str:
    m = VERSION_RE.search((SRC / "main.lua").read_text(encoding="utf-8"))
    if not m:
        raise SystemExit("[package] trackside.VERSION not found in main.lua")
    return m.group(1)


def manifest_version(artifact_version: str) -> str:
    m = XYZ_RE.match(artifact_version)
    return m.group(1) if m else base_version()


def stamp_build(main_lua: Path, artifact_version: str) -> None:
    text = main_lua.read_text(encoding="utf-8")
    text, n = BUILD_RE.subn(lambda m: m.group(1) + artifact_version + m.group(3), text, count=1)
    if n != 1:
        raise SystemExit("[package] trackside.BUILD not found in main.lua")
    main_lua.write_text(text, encoding="utf-8", newline="")


def release_notes(path: str | None) -> dict | None:
    if not path:
        return None
    content = Path(path).read_text(encoding="utf-8").strip()
    if not content:
        return None
    if len(content) > NOTES_MAX:
        raise SystemExit(f"[package] release notes over {NOTES_MAX} characters")
    return {"format": "markdown", "content": content}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--artifact-version", required=True, help="e.g. 0.1.0, 0.2.0-rc1, commit-abc1234")
    ap.add_argument("--artifact-name", help="zip file name (default trackside-<version>.zip)")
    ap.add_argument("--output-dir", default=".")
    ap.add_argument("--release-notes-file", help="markdown embedded in the manifest")
    args = ap.parse_args()

    out_dir = Path(args.output_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    zip_path = out_dir / (args.artifact_name or f"trackside-{args.artifact_version}.zip")
    version = manifest_version(args.artifact_version)

    with tempfile.TemporaryDirectory(prefix="trackside-package-") as tmp:
        root = Path(tmp)
        shutil.copytree(SRC, root / FOLDER, ignore=SKIP)
        stamp_build(root / FOLDER / "main.lua", args.artifact_version)

        files = sorted(p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file())
        manifest = {
            "manifestVersion": 1,
            "name": PACKAGE_NAME,
            "key": PACKAGE_KEY,
            "version": version,
            "folder": FOLDER,
            "files": [f"{FOLDER}/**"],
        }
        notes = release_notes(args.release_notes_file)
        if notes:
            manifest["releaseNotes"] = notes
        (root / MANIFEST).write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

        if zip_path.exists():
            zip_path.unlink()
        with ZipFile(zip_path, "w", compression=ZIP_DEFLATED, compresslevel=9) as z:
            z.write(root / MANIFEST, MANIFEST)
            for rel in files:
                z.write(root / rel, rel)

    print(f"[package] {zip_path.name}: version {version}, build {args.artifact_version}, {len(files)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
