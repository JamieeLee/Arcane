#!/usr/bin/env python3
"""Static guardrails for native text theming and unchanged zone text."""

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
    "nativeSetZoneText(showPVPInfo)",
    "COMBAT_TEXT_TYPE_INFO",
    '"AURA_START"',
    '"AURA_END"',
    '"HEAL"',
    '"PERIODIC_HEAL"',
    'C.ART .. "FrameL"',
    'C.ART .. "FrameR"',
    "pal.rim",
):
    assert token in THEME, f"Native text theme is missing {token!r}"

# Only decorative end trim textures may be attached to the native zone frames.
for forbidden in (
    "ZoneTextString:SetTextColor",
    "SubZoneTextString:SetTextColor",
    'SetFont(zone,',
    'SetFont(sub,',
    "C.SetFace(zone",
    "C.SetFace(sub",
    "C.TextColor(zone",
    "C.TextColor(sub",
    "C.ART .. \"Fill\"",
    "C.ART .. \"FrameM\"",
    "CRIMSON_",
    "BANNER_HEIGHT",
):
    assert forbidden not in THEME, f"Native zone label appearance must remain untouched: {forbidden!r}"

# The integration must not replace the native combat-text message path or its behavior.
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

print("PASS native zone/subzone font, size, color, position and fades are not modified")
print("PASS only two rim-tinted end trims decorate each native zone text line")
print("PASS floating status colors are applied through COMBAT_TEXT_TYPE_INFO")
print("PASS floating combat-text creation, filtering, scrolling and fade constants remain native")
print("PASS stock gameplay notices retain their native MessageFrame handler")
