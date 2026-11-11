#!/usr/bin/env python3
"""Extract a versioned GitHub release body from the canonical README."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if len(sys.argv) != 3:
    print("Usage: extract_release_notes.py VERSION OUTPUT_PATH", file=sys.stderr)
    raise SystemExit(2)

version = sys.argv[1].lstrip("v")
if not version or any(ch not in "0123456789." for ch in version):
    print(f"Invalid release version: {sys.argv[1]}", file=sys.stderr)
    raise SystemExit(2)

tag = f"v{version}"
start = f"<!-- RELEASE_NOTES_{tag}_BEGIN -->"
end = f"<!-- RELEASE_NOTES_{tag}_END -->"
readme = (ROOT / "README.md").read_text(encoding="utf-8")
if start not in readme or end not in readme:
    print(f"FAIL: README is missing the complete {tag} release-note block", file=sys.stderr)
    raise SystemExit(1)

body = readme.split(start, 1)[1].split(end, 1)[0].strip()
if not body.startswith("### Arcane UI " + tag):
    print(f"FAIL: {tag} release-note block must start with its matching title", file=sys.stderr)
    raise SystemExit(1)
body = "# " + body[len("### "):]
if len(body.splitlines()) < 3:
    print(f"FAIL: {tag} release-note block is unexpectedly short", file=sys.stderr)
    raise SystemExit(1)

output = Path(sys.argv[2])
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(body + "\n", encoding="utf-8")
print(f"PASS: extracted {tag} release notes from README to {output}")
