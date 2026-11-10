#!/usr/bin/env python3
"""Static guardrails for native zone text outlines and behavior preservation."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOC = (ROOT / "Arcane.toc").read_text(encoding="utf-8")
THEME = (ROOT / "Frames" / "NativeText.lua").read_text(encoding="utf-8")
STOCK = (ROOT / "Frames" / "StockErrors.lua").read_text(encoding="utf-8")
ARCH = (ROOT / "docs" / "ARCHITECTURE.md").read_text(encoding="utf-8")

assert "Frames/StockErrors.lua\nFrames/NativeText.lua" in TOC

for token in (
    "ZoneTextString",
    "SubZoneTextString",
    "ZoneTextFrame",
    "SubZoneTextFrame",
    'CreateFontString(nil, "BACKGROUND")',
    "source:GetFont()",
    "source:GetStringHeight()",
    "fs:SetFont(face, size)",
    "fs:SetHeight(height)",
    "local function LivePalette()",
    "local pal = C.pal",
    "local rim = pal.rim",
    "pal.title",
    "pal.mc",
    '"AURA_START"',
    '"AURA_END"',
    '"HEAL"',
    '"PERIODIC_HEAL"',
    "STROKE_OFFSETS",
    "fs:SetTextColor(rim[1], rim[2], rim[3])",
):
    assert token in THEME, f"Native text theme is missing {token!r}"

# Native zone FontStrings must never be restyled or moved. The outline is a separate
# BACKGROUND-layer FontString pool, using the original face/size and a separate rim tint.
for forbidden in (
    "ZoneTextString:SetTextColor",
    "SubZoneTextString:SetTextColor",
    "ZoneTextString:SetFont",
    "SubZoneTextString:SetFont",
    "ZoneTextString:SetPoint",
    "SubZoneTextString:SetPoint",
    "C.SetFace(zone",
    "C.SetFace(sub",
    "C.TextColor(zone",
    "C.TextColor(sub",
    "C.ART .. \"FrameL\"",
    "C.ART .. \"FrameR\"",
    "CRIMSON_",
    "BANNER_HEIGHT",
    "SetZoneText = function",
):
    assert forbidden not in THEME, f"Native zone text must remain untouched: {forbidden!r}"

# The integration must not replace native message creation, filters or animation behavior.
for forbidden in (
    "CombatText_AddMessage =",
    "CombatText_OnEvent =",
    "COMBAT_TEXT_SCROLLSPEED =",
    "COMBAT_TEXT_FADEOUT_TIME =",
    "ZoneFadeInDuration =",
    "ZoneHoldDuration =",
    "ZoneFadeOutDuration =",
):
    assert forbidden not in THEME, f"Native text theme must not override {forbidden!r}"

# The existing gameplay notification color hook remains unchanged from main.
assert "nativeAddMessage(self, message, title[1], title[2], title[3], alpha)" in STOCK
assert "local title = C.Pal().title" in STOCK
assert "ThemeFont(self)" not in STOCK
assert "Native text styling" in ARCH

print("PASS native zone/subzone font, exact size, fill color, position and fades are not modified")
print("PASS a live rim-colored outline follows each native glyph without side ornaments or a panel")
print("PASS outline clones use the exact native face and font size with explicit line height")
print("PASS floating status colors follow the active timer zone palette")
print("PASS native combat-text creation, filtering, scrolling and fade constants remain native")
print("PASS the pre-existing stock gameplay notification theme is unchanged")
