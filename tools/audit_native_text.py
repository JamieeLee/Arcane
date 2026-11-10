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
    "fs:SetFont(face, size)",
    "TimerRim()",
    "local p = C.pal",
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
# BACKGROUND-layer FontString pool, using the original face/size and a separate tint.
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

assert "nativeAddMessage(self, message, title[1], title[2], title[3], alpha)" in STOCK
assert "ThemeFont(self)" in STOCK
assert "Native text styling" in ARCH

print("PASS native zone/subzone font, size, fill color, position and fades are not modified")
print("PASS a rim-colored text outline follows each native glyph with no side ornaments or panel")
print("PASS outline uses the original font face and exact font size")
print("PASS floating status colors use the active Arcane palette")
print("PASS native combat-text creation, filtering, scrolling and fade constants remain native")
print("PASS stock gameplay notices retain their native MessageFrame handler")
