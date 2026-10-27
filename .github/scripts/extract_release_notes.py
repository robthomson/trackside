#!/usr/bin/env python3
"""
Print one version's section of Releases.md: the lines under "# <version>" up to
the next "# " heading. Falls back to "Trackside <version>" if there is none.

Usage: python .github/scripts/extract_release_notes.py 0.1.0 Releases.md
"""

import sys


def main() -> int:
    version, path = sys.argv[1], sys.argv[2]
    out, found = [], False
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("# "):
                if found:
                    break
                found = line[2:].strip() == version
            elif found:
                out.append(line)
    text = "".join(out).strip()
    sys.stdout.reconfigure(encoding="utf-8")
    print(text if text else f"Trackside {version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
