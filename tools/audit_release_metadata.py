#!/usr/bin/env python3
"""Keep Arcane release metadata, single-document policy and publishing workflow aligned."""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "0.7.6"
VERSION_TAG = "v" + VERSION
RELEASE_ASSET = f"ArcaneV{VERSION}.zip"
ARTIFACT_PREFIX = f"Arcane-v{VERSION}-test-"
RELEASE_NOTES_OUTPUT = f"$RUNNER_TEMP/ArcaneV{VERSION}-release-notes.md"
RELEASE_DATE = "November 10, 2026"

checks = (
    (ROOT / "Core.lua", f'Arcane.VERSION = "{VERSION}"', "Core.VERSION must match the release version"),
    (ROOT / "Arcane.toc", f"## Version: {VERSION_TAG}", "TOC version must match the release version"),
    (ROOT / "README.md", f"**Current release: {VERSION_TAG}**", "README current release must match"),
    (ROOT / "README.md", RELEASE_ASSET, "README installer filename must match"),
    (ROOT / "README.md", f"### {VERSION_TAG} — {RELEASE_DATE}", "README changelog must include the dated current release section"),
    (ROOT / "README.md", f"### Arcane UI {VERSION_TAG}", "README must contain the detailed current release notes"),
    (ROOT / "README.md", f"<!-- RELEASE_NOTES_{VERSION_TAG}_BEGIN -->", "README must mark the current release-note block"),
    (ROOT / "README.md", f"<!-- RELEASE_NOTES_{VERSION_TAG}_END -->", "README must close the current release-note block"),
    (ROOT / "README.md", "### Documentation rule — one Markdown file", "README must document the single-file policy"),
    (ROOT / "README.md", "## Architecture and module ownership", "README must contain the consolidated architecture guide"),
    (ROOT / "README.md", "## Attribution and project provenance", "README must contain the consolidated attribution record"),
    (ROOT / "ATTRIBUTION.txt", "Upstream project:", "The package attribution text file must exist"),
    (ROOT / "ATTRIBUTION.txt", "Valorless/ASTinyPlates", "The package attribution file must preserve Nameplates provenance"),
    (ROOT / ".github/workflows/arcane-audit.yml", ARTIFACT_PREFIX, "CI artifact prefix must match the release version"),
    (ROOT / ".github/workflows/arcane-audit.yml", f'archive="$RUNNER_TEMP/{RELEASE_ASSET}"', "CI installer filename must match the release asset"),
    (ROOT / ".github/workflows/arcane-audit.yml", f'test -s "release-assets/{RELEASE_ASSET}"', "release job must verify the downloaded installer filename"),
    (ROOT / ".github/workflows/arcane-audit.yml", f'- "{VERSION_TAG}"', "CI must run for the release tag"),
    (ROOT / ".github/workflows/arcane-audit.yml", f"Audit {VERSION_TAG} release metadata consistency", "CI must run the matching metadata audit"),
    (ROOT / ".github/workflows/arcane-audit.yml", f"if: github.ref == 'refs/tags/{VERSION_TAG}'", "release job must be restricted to the matching tag"),
    (ROOT / ".github/workflows/arcane-audit.yml", f'test "$GITHUB_REF_NAME" = "{VERSION_TAG}"', "release job must verify the tag name"),
    (ROOT / ".github/workflows/arcane-audit.yml", "gh release create", "the validated tag build must publish a GitHub Release"),
    (ROOT / ".github/workflows/arcane-audit.yml", 'if gh release view "$GITHUB_REF_NAME" >/dev/null 2>&1; then', "release publishing must handle a release that already exists"),
    (ROOT / ".github/workflows/arcane-audit.yml", f'gh release upload "$GITHUB_REF_NAME" "release-assets/{RELEASE_ASSET}" --clobber', "reruns must replace the existing release ZIP instead of failing"),
    (ROOT / ".github/workflows/arcane-audit.yml", 'gh release edit "$GITHUB_REF_NAME"', "reruns must keep the existing release title and notes current"),
    (ROOT / ".github/workflows/arcane-audit.yml", "GH_TOKEN: ${{ github.token }}", "release publishing must authenticate with the Actions token"),
    (ROOT / ".github/workflows/arcane-audit.yml", "gh run download", "release job must download the package from this workflow run"),
    (ROOT / ".github/workflows/arcane-audit.yml", f'--title "Arcane UI {VERSION_TAG}"', "GitHub release title must match the tag"),
    (ROOT / ".github/workflows/arcane-audit.yml", f'--notes-file "{RELEASE_NOTES_OUTPUT}"', "GitHub release notes must be extracted from the canonical README"),
    (ROOT / ".github/workflows/arcane-audit.yml", f'python tools/extract_release_notes.py {VERSION} "{RELEASE_NOTES_OUTPUT}"', "release workflow must extract the versioned notes from README"),
    (ROOT / ".github/workflows/arcane-audit.yml", '"Arcane/ATTRIBUTION.txt"', "the install ZIP must retain the plain-text attribution notice"),
)
for path, expected, message in checks:
    if not path.exists() or expected not in path.read_text(encoding="utf-8"):
        print("FAIL:", message, file=sys.stderr)
        raise SystemExit(1)

readme = (ROOT / "README.md").read_text(encoding="utf-8")
workflow = (ROOT / ".github" / "workflows" / "arcane-audit.yml").read_text(encoding="utf-8")
if any(name in readme for name in ("ArcaneV0.7.5.zip", "ArcaneV0.7.4.zip", "ArcaneV0.7.3.zip")):
    print("FAIL: README still points at an older installer", file=sys.stderr)
    raise SystemExit(1)
if any(name in workflow for name in ("Arcane-v0.7.5-test-", "Arcane-v0.7.4-test-", "Arcane-v0.7.3-test-")):
    print("FAIL: CI still labels test packages with an older release version", file=sys.stderr)
    raise SystemExit(1)

markdown_files = sorted(
    p.relative_to(ROOT).as_posix()
    for p in ROOT.rglob("*.md")
    if ".git" not in p.parts
)
if markdown_files != ["README.md"]:
    print("FAIL: README.md must be the only Markdown file; found: " + ", ".join(markdown_files), file=sys.stderr)
    raise SystemExit(1)

# Exercise the same extractor used by the release workflow, not just its source text.
with tempfile.TemporaryDirectory(prefix="arcane-release-notes-") as temp_dir:
    output = Path(temp_dir) / "release-notes.md"
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "extract_release_notes.py"), VERSION, str(output)],
        cwd=ROOT, text=True, capture_output=True
    )
    if result.returncode != 0:
        print("FAIL: release-note extraction failed: " + result.stderr.strip(), file=sys.stderr)
        raise SystemExit(1)
    extracted = output.read_text(encoding="utf-8")
    if not extracted.startswith(f"# Arcane UI {VERSION_TAG}") or "Gold cache markers" not in extracted:
        print("FAIL: extracted release notes are incomplete or mismatched", file=sys.stderr)
        raise SystemExit(1)

print(f"PASS: Arcane {VERSION_TAG} metadata, single-Markdown policy, attribution, CI package and tag publishing metadata are consistent")
