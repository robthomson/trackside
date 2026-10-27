#!/usr/bin/env python3
"""
Check a Trackside package zip the way the Ethos package installer reads it:
ethos_lua_manifest.json at the root, valid fields, and file patterns that
select real files including main.lua.

Usage: python bin/package/validate_manifest.py trackside-0.1.0.zip
"""

from __future__ import annotations

import fnmatch
import json
import re
import sys
from pathlib import PurePosixPath
from zipfile import ZipFile

MANIFEST = "ethos_lua_manifest.json"
KEY_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")
FOLDER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")


def fail(msg: str) -> None:
    raise SystemExit(f"[validate] FAIL: {msg}")


def select(pattern: str, files: list[str]) -> set[str]:
    p = pattern.replace("\\", "/").strip("/").lower()
    parts = p.split("/")
    if not p or any(s in ("", ".", "..") for s in parts) or re.match(r"^[a-z]:", p):
        fail(f"bad files pattern {pattern!r}")
    if "**" in p and not (parts[-1] == "**" and all("**" not in s for s in parts[:-1])):
        fail(f"'**' must be the last whole segment in {pattern!r}")
    if p == "**":
        return set(files)
    if p.endswith("/**"):
        prefix = p[:-3] + "/"
        return {f for f in files if f.startswith(prefix)}
    want = PurePosixPath(p).parts
    return {f for f in files
            if len(PurePosixPath(f).parts) == len(want)
            and all(fnmatch.fnmatchcase(a, b) for a, b in zip(PurePosixPath(f).parts, want))}


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    path = sys.argv[1]
    with ZipFile(path) as z:
        files = sorted({i.filename.replace("\\", "/").strip("/").lower() for i in z.infolist() if not i.is_dir()})
        if MANIFEST not in files:
            fail("ethos_lua_manifest.json missing at the zip root")
        m = json.loads(z.read(MANIFEST).decode("utf-8"))

    for field in ("manifestVersion", "name", "key", "version", "folder", "files"):
        if field not in m:
            fail(f"manifest field {field!r} missing")
    if m["manifestVersion"] != 1:
        fail("manifestVersion must be 1")
    if not isinstance(m["name"], str) or not 1 <= len(m["name"]) <= 128:
        fail("name must be 1-128 characters")
    if not KEY_RE.fullmatch(str(m["key"])):
        fail("key: 1-128 of letters, digits, . _ : - (starting with a letter or digit)")
    if not VERSION_RE.fullmatch(str(m["version"])):
        fail("version must be X.Y.Z")
    if not FOLDER_RE.fullmatch(str(m["folder"])):
        fail("folder: 1-64 of letters, digits, . _ - (starting with a letter or digit)")
    notes = m.get("releaseNotes")
    if notes is not None:
        content = notes if isinstance(notes, str) else notes.get("content") if isinstance(notes, dict) else None
        if not isinstance(content, str) or len(content) > 32000:
            fail("releaseNotes must be text up to 32000 characters")
        if isinstance(notes, dict) and notes.get("format") not in ("markdown", "text"):
            fail("releaseNotes.format must be markdown or text")
    if not isinstance(m["files"], list) or not m["files"]:
        fail("files must be a non-empty list")

    chosen: set[str] = set()
    for pattern in m["files"]:
        chosen |= select(pattern, files)
    if not chosen:
        fail("files patterns select nothing")
    if not any(PurePosixPath(f).name in ("main.lua", "main.luac") for f in chosen):
        fail("files must include main.lua")

    print(f"[validate] OK: {path} ({len(chosen)} files, version {m['version']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
