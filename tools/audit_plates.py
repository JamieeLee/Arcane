#!/usr/bin/env python3
"""Static ownership and regression guards for the Tiny Plates subsystem."""
from pathlib import Path
import re

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

require("CapturePoints" not in state and "RestorePoints" not in state,
        "Tiny Plates must not snapshot or restore game-owned WorldFrame anchors")
require("frame:SetPoint(" not in state and "frame:ClearAllPoints()" not in state,
        "native restoration must not reposition the moving WorldFrame plate")
require("SaveObjectState" in state and "object ~= plate" in state,
        "native state snapshots must not own plate visibility")
require('if state.shown then object:Show() else object:Hide() end' in state,
        "captured child visibility must be restored exactly")
require("if state.shown then frame:Show()" not in state,
        "restoration must never re-show a pooled root nameplate")
require("arcanePlatesNativeWidth" not in state
        and "arcanePlatesNativeScale" not in state
        and "arcanePlatesNativePoints" not in state,
        "native restoration must not restore stale root geometry")
require("regions[i]:Show()" not in state and "children[i]:Show()" not in state
        and "SetAlpha(1)" not in state,
        "do not use blanket show/alpha restoration when native state is unknown")
require("frame.arcanePlatesSourceBar = nil" in state
        and "frame.arcanePlatesStyledVisual = nil" in state,
        "recycled plates must discard stale native-child references")
require("bossGuardianNames = {}" in special and "bossGuardianUnitsByName = {}" in special,
        "boss identity indexes must be rebuilt together")
require("debuffCache[unitID]" in special,
        "fallback debuff API reads must be cached by unit")
require("runTimeRead" in special,
        "run time should be queried at most once per plate update")
require("local function ContainsStatusBar" not in visuals,
        "recursive status-bar search must have one implementation")
require("P.State.RegisterPlate" in controller and "P.Visuals.Apply(frame)" in controller,
        "controller must delegate registration and presentation to their owning modules")
require(re.search(r"if P\.Visuals\.Apply\(frame\) then[\s\S]+?frame\.arcanePlatesStyleRevision = styleRevision", controller) is not None,
        "style revision must be recorded only after application succeeds")
require("if oldOnHide then oldOnHide() end" in options,
        "Tiny Plates settings must preserve the parent frame's existing OnHide handler")
require("HasStatusBar" not in state,
        "duplicate HasStatusBar helper should be consolidated into ContainsStatusBar")


require("arcanePlatesStackOriginalWidth" not in visuals
        and "arcanePlatesStackPoint" not in visuals
        and "frame:ClearAllPoints()" not in visuals,
        "Tiny Plates visuals must not rewrite game-owned plate root geometry")

require("frame.arcanePlatesHiddenByOption = true" in visuals,
        "hiding regular plates must record an explicit reversible hidden state")
require("if frame.arcanePlatesHiddenByOption then" in visuals
        and "P.State.RestoreNativeState(frame)" in visuals
        and "CreatePlateOverlay(frame)" in visuals,
        "unchecking hide regular plates must restore native pieces and rebuild the Arcane overlay")
require("Hide regular plates" in options
        and "Unchecking restores the Arcane health bars" in options,
        "the option must explain that it restores Tiny Plates, not a stock renderer")
require("SetEnabled(false)" not in controller,
        "a rendering error must not disable the only enemy health-bar renderer")
require("SafeCall(\"plate discovery\", RegisterPlate, frame)" in controller
        and 'local scope = "plate " .. tostring(frame)' in controller
        and "SafeCall(scope, ApplyKnownPlate, frame, updateDebuffs)" in controller,
        "plate discovery and rendering errors must be isolated per frame")
hide_at = visuals.find('if not special and P.Option("hideShrunkPlates") then')
restore_at = visuals.find("if frame.arcanePlatesHiddenByOption then")
rebuild_at = visuals.find("if not CreatePlateOverlay(frame) then return false end")
require(hide_at >= 0 and restore_at > hide_at and rebuild_at > restore_at,
        "unhide must restore native pieces before rebuilding the Arcane bar")

print("Tiny Plates ownership and regression audits passed.")
