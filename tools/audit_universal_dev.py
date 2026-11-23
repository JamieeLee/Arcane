#!/usr/bin/env python3
"""DEV-only invariants for the single visual UX."""
from pathlib import Path
R = Path(__file__).resolve().parents[1]
def source(name): return (R / name).read_text(encoding="utf-8")
def test(ok, why):
    if not ok: raise SystemExit("FAIL: universal DEV UX: " + why)
style, opts, bar = (source(x) for x in ("SkillBar/Styles.lua","Core/Options.lua","SkillBar/Bar.lua"))
test("if C.UniversalUX then return UNIVERSAL end" in style, "universal mode not forced")
test("Universal UX (DEV)" in opts and "StyleChoice(C.BarStyles." not in opts, "old selector still exposed")
test(all(x in style for x in ("CLASSIC", "HYBRID", "FULL_CLASS", "CONTROLLER")), "legacy renderer lost")
test("C.ControllerUX = Theme" in source("Themes/Controller/Controller.lua"), "controller source lost")
test(all(x in bar for x in ("NeckSlot","Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot")), "jewelry slot lost")
level = source("Frames/LevelUps.lua")
test(all(x in level for x in ('ART .. "Tome"','ART .. "BookClassOrbit"','AZS_OpenStoredLevels','NativeStoring()')), "stored-level feature lost")
pets = source("Windows/Pets.lua")
test(all(x in pets for x in ("CircleTexture", "CircleCooldown", "SkillRim", "SkillEmpty", "TogglePetAutocast", "CastPetAction")), "pet circle or actions lost")
test('C.Panel(root, false)' not in pets and 'root.deco' not in pets,
     "the pet strip must have no always-visible outer panel")
test('C.Movable(root, "pets", "Pet bar"' in pets and 'root:SetScale(db.scale)' in pets,
     "pet icons must still move and scale together through the regular mover")
test('f:SetPoint("TOPLEFT", ArcanePlayer, "BOTTOMLEFT", 86, -7)' in pets,
     "keep pet strip at existing position until player approves a new center")
test(all("C.WindowPal()" in source(x) for x in ("Windows/Stats.lua","Windows/Meter.lua","Windows/Luck.lua")), "utility accent routing missing")
print("PASS: one universal DEV UX; all legacy source and active gameplay contracts retained")
