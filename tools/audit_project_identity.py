#!/usr/bin/env python3
"""Keep Arcane's product identity, v0.6 metadata and retained integrations consistent."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    target = ROOT / path
    if not target.is_file():
        raise SystemExit("Project identity audit failed: missing " + path)
    return target.read_text(encoding="utf-8")

def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit("Project identity audit failed: " + message)

toc = read("Arcane.toc")
core = read("Core.lua")
readme = read("README.md")
version_toc = re.search(r"^## Version:\s*v?([0-9.]+)\s*$", toc, re.M)
version_core = re.search(r'^Arcane\.VERSION\s*=\s*"([0-9.]+)"', core, re.M)
version_readme = re.search(r"\*\*Current release:\s*v?([0-9.]+)\*\*", readme)
versions = [m.group(1) if m else None for m in (version_toc, version_core, version_readme)]
require(versions == ["0.6", "0.6", "0.6"],
        "Core.lua, Arcane.toc and README must all report the current v0.6 release")

required_modules = (
    "Plates/State.lua",
    "Plates/SpecialTargets.lua",
    "Plates/Visuals.lua",
    "Plates/Controller.lua",
    "Plates/Options.lua",
)
for module in required_modules:
    require(module in toc.splitlines(), "Arcane.toc must load " + module)
require("Plates/ArcanePlates.lua" not in toc and "Plates/ArcanePlatesOptions.lua" not in toc,
        "the old plate-controller file names must not remain in the load map")
require(not (ROOT / "Plates/ArcanePlates.lua").exists()
        and not (ROOT / "Plates/ArcanePlatesOptions.lua").exists(),
        "the old plate-controller source files must be removed")

for path in ("README.md", "Core/Options.lua", "Plates/Controller.lua",
             "Plates/Options.lua", "docs/ARCHITECTURE.md"):
    text = read(path)
    require("Tiny Plates" not in text and "ArcanePlates" not in text,
            path + " must use Arcane Nameplates branding, not retired feature names")

require("Arcane Nameplates" in read("README.md"), "README must use the current nameplate feature name")
require("Arcane Nameplates" in read("Plates/Options.lua"), "the in-game settings panel must use the current feature name")
require("AZSUNITS" in read("Plates/Controller.lua"), "the game's AZSUNITS integration channel must remain intact")
require("WorldFrame" in read("Plates/State.lua"), "native WorldFrame nameplate integration must remain intact")

startup = read("Core/Startup.lua")
timer = read("Timer/Timer.lua")
numbers = read("Numbers/Commands.lua")
require('"SmoothNumbers"' in startup and '"SmoothBossTimer"' in startup,
        "legacy addon IDs must remain detectable to prevent duplicate renderers")
require('OldAddon("SmoothBossTimer")' in timer,
        "the boss timer must retain its duplicate-addon guard")
require('OldAddon("SmoothNumbers")' in numbers,
        "damage numbers must retain their duplicate-addon guard")
require('title:SetText("Arcane Boss Timer")' in timer,
        "the timer settings window must use Arcane branding")

attribution = read("ATTRIBUTION.md")
license_path = "Nameplates-MIT-LICENSE.txt"
require("Valorless/ASTinyPlates" in attribution and license_path in attribution,
        "nameplate source attribution and the retained MIT notice must remain documented")
license_text = read(license_path)
require("MIT License" in license_text and "Copyright (c) 2026 Valorless" in license_text,
        "the original nameplate MIT license notice must be preserved")
workflow = read(".github/workflows/arcane-validation.yml")
require("python tools/audit_project_identity.py" in workflow,
        "the identity audit must run in CI")
require("Nameplates-MIT-LICENSE.txt" in workflow,
        "the original nameplate license must be included in test packages")

print("PASS: Arcane release metadata agrees on v0.6")
print("PASS: Arcane Nameplates uses Arcane-owned module and UI names")
print("PASS: game APIs and legacy duplicate-renderer guards remain intact")
print("PASS: upstream nameplate attribution and its MIT license are preserved")
