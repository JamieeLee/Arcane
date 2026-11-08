#!/usr/bin/env python3
"""Static ownership and regression guards for the Tiny Plates subsystem."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
TOC = (ROOT / "Arcane.toc").read_text(encoding="utf-8")
PLATE_FILES = [
    "Plates/State.lua",
    "Plates/SpecialTargets.lua",
    "Plates/Visuals.lua",
    "Plates/ArcanePlates.lua",
    "Plates/ArcanePlatesOptions.lua",
]
sources = {name: (ROOT / name).read_text(encoding="utf-8") for name in PLATE_FILES}

def require(condition, message):
    if not condition:
        raise SystemExit("Tiny Plates audit failed: " + message)

positions = [TOC.find(name) for name in PLATE_FILES]
require(all(pos >= 0 for pos in positions), "all plate modules must be listed in Arcane.toc")
require(positions == sorted(positions), "plate dependency/load order is incorrect")
require(TOC.find("Core/Bars.lua") < positions[0], "shared Core bar renderer must load before Tiny Plates")

state = sources["Plates/State.lua"]
special = sources["Plates/SpecialTargets.lua"]
visuals = sources["Plates/Visuals.lua"]
controller = sources["Plates/ArcanePlates.lua"]
options = sources["Plates/ArcanePlatesOptions.lua"]

require("GetNumPoints" in state and "frame:GetPoint(i)" in state,
        "native state must capture every anchor point")
require("SaveObjectState" in state and "object ~= plate" in state,
        "native state snapshots must not own plate visibility")
require('if state.shown then object:Show() else object:Hide() end' in state,
        "captured child visibility must be restored exactly")
require("if state.shown then frame:Show()" not in state,
        "restoration must never re-show a pooled root nameplate")
require("styled:ClearAllPoints()" not in state,
        "native restoration must not recenter replacement visuals")
require("else\\n\\t\\tlocal regions" not in state,
        "do not use blanket show-all fallback for unknown native state")
require("bossGuardianNames = {}" in special and "bossGuardianUnitsByName = {}" in special,
        "boss identity indexes must be rebuilt together")
require("debuffCache[unitID]" in special,
        "fallback debuff API reads must be cached by unit")
require("runTimeRead" in special,
        "run time should be queried at most once per plate update")
require("local function ContainsStatusBar" not in visuals,
        "duplicate recursive status-bar search must live in the state module")
require("P.State.RegisterPlate" in controller and "P.Visuals.Apply(frame)" in controller,
        "controller must delegate registration and presentation to their owning modules")
require("frame.arcanePlatesStyleRevision = styleRevision" in controller,
        "successful style applications must record their revision")
require(re.search(r"if P\\.Visuals\\.Apply\\(frame\\) then[\\s\\S]+?frame\\.arcanePlatesStyleRevision = styleRevision", controller) is not None,
        "style revision must be recorded only after application succeeds")
require("if oldOnHide then oldOnHide() end" in options,
        "Tiny Plates settings must preserve the parent frame's existing OnHide handler")
require("HasStatusBar" not in state,
        "duplicate HasStatusBar helper should be consolidated into ContainsStatusBar")

print("Tiny Plates ownership and regression audits passed.")
