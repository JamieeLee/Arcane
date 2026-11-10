#!/usr/bin/env python3
"""Static guardrails for the native text theme integration."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOC = (ROOT / "Arcane.toc").read_text(encoding="utf-8")
THEME = (ROOT / "Frames" / "NativeText.lua").read_text(encoding="utf-8")
STOCK = (ROOT / "Frames" / "StockErrors.lua").read_text(encoding="utf-8")
ARCH = (ROOT / "docs" / "ARCHITECTURE.md").read_text(encoding="utf-8")

assert "Frames/StockErrors.lua\nFrames/NativeText.lua" in TOC, (
    "Native text theming must load after stock notification setup"
)

for token in (
    "ZoneTextString",
    "SubZoneTextString",
    "ZoneTextFrame",
    "SubZoneTextFrame",
    "nativeSetZoneText(showPVPInfo)",
    "nativeSetZoneText(showPVPInfo)",
    "COMBAT_TEXT_TYPE_INFO",
    '"AURA_START"',
    '"AURA_END"',
    '"HEAL"',
    '"PERIODIC_HEAL"',
    "FrameL",
    "FrameM",
    "FrameR",
    "CRIMSON_LEFT",
    "C.TITLE_FONT",
):
    assert token in THEME, f"Native text theme is missing {token!r}"

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

print("PASS native zone labels keep the stock frames and fading behavior")
print("PASS floating status colors are applied through COMBAT_TEXT_TYPE_INFO")
print("PASS floating combat-text creation, filtering, scrolling and fade constants remain native")
print("PASS zone banner uses Arcane timer metal and crimson fill")
print("PASS stock gameplay notices retain their native MessageFrame handler")
