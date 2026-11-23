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
test('function M.MedallionSide()' in style and 'function M.SetMedallionSide(side)' in style
     and 'side ~= "OFF"' in style,
     "medallion must support saved left/right/off choices")
test('db.medallionSide = side' in style and 'panel.barStyleMedallionSide == medalSide' in style,
     "medallion placement must persist and invalidate artwork layout")
test('medalSide == "LEFT" and panel.endLeft or panel.endRight' in style and
     'classSide == "LEFT" and 1 or 2' in style,
     "moving A must exchange it with the class emblem and underlying endcap")
test('o.medallionSide = C.Button(' in opts and 'C.BarStyles.SetMedallionSide(' in opts
     and '"Arcane A: Off"' in opts and 'side == "RIGHT" and "OFF"' in opts,
     "arcane left/right/off selection must be available in the DEV options hub")
test('medalSide == "OFF"' in style and 'C.Vis(panel.hybridArcane, false)' in style
     and 'C.Vis(panel.hybridGem, false)' in style
     and 'PlaceEmblem(panel.classEmblems[1], panel.frame, "LEFT", theme.emblem)' in style
     and 'PlaceEmblem(panel.classEmblems[2], panel.frame, "RIGHT", theme.emblem)' in style,
     "Off must hide the Arcane medallion and restore two Full Class class ornaments")
test("C.ControllerUX = Theme" in source("Themes/Controller/Controller.lua"), "controller source lost")
test(all(x in bar for x in ("NeckSlot","Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot")), "jewelry slot lost")
level = source("Frames/LevelUps.lua")
test(all(x in level for x in ('ART .. "TomeNatural"','ART .. "BookClassOrbit"','AZS_OpenStoredLevels','NativeStoring()')), "stored-level feature lost")
test('function M.BookClassSuffix()' in style and 'local theme = CurrentTheme()' in style,
     "book class selector must reuse canonical Full Class resolution")
test('C.BarStyles.BookClassSuffix()' in level and
     'root.book:SetTexture(ART .. "TomeNatural" .. (suffix or ""))' in level,
     "stored-level book must apply class texture only on palette changes")
test("build_tome_classes.py" in source(".github/workflows/arcane-audit.yml") and
     all("TomeNatural" + name + ".blp" in source(".github/workflows/arcane-audit.yml")
         for name in ("Warrior", "Paladin", "Hunter", "Rogue", "Priest",
                      "Shaman", "Mage", "Warlock", "Druid")),
     "CI must generate and verify nine class-colored BLP2 books")
test("StylesData.lua" in source("tools/build_tome_classes.py") and
     "TomeNatural.tga" in source("tools/build_tome_classes.py"),
     "nine variants must share the existing class colors and neutral art")
test("build_tome_natural.py" in source(".github/workflows/arcane-audit.yml")
     and "Tome.tga" in source("tools/build_tome_natural.py")
     and "TomeNatural.tga" in source("tools/build_tome_natural.py"),
     "new skin must be generated in CI from the intact original Controller book")
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
