# Changelog

## v0.5 — November 8, 2026

- **Classic skill bar medallions:** use the supplied high-resolution gold dragon/A artwork on both default endcaps, mirrored on the right and aligned against Hybrid's lower ornamental tails. The bar rails, slots, spacing and other styles remain unchanged.
- **README preview:** replace the older preview image with a current in-game screenshot showing the v0.5 HUD.

## v0.4 — November 8, 2026

- **Standalone Stats window:** a movable, resizable tracker for 29 run stats, grouped by Offense, Survival, Area and DoTs, and Run. Choose the stats to show; increases and decreases briefly flash green and red.
- **Party shields:** party health bars now show detected absorb shields using Arcane's existing animated glass-and-stripe overlay.
- **Target portrait rings:** bosses and final bosses receive the original gold elite dragon ring; guardians receive the silver rare ring. The corrected segmented texture keeps the full ring intact.
- **Damage-number choices:** six optional custom fonts join the four built-in faces; six optional critical-hit backdrops add Flame, Frost, Arcane, Holy, Shadow and Storm treatments. The default backdrop remains None.
- **Minimap readability:** cache and lair markers fade near the player's arrow and return to full strength with distance.
- **Loot rarity correction:** Tier 0.5 set armor is identified as Epic (purple), while exact named Tier 0.5 weapons retain their Legendary rarity.

## v0.3

- **Three selectable skill-bar styles:** Classic Arcane remains the unchanged default for existing installs; Hybrid combines the gold Arcane A medallion on the left with the active class crest on the right; Full Class uses class-specific paired emblems, rails and tinted glass.
- **Nine class palettes:** Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock and Druid receive dedicated skill-bar styling. The selected style persists in `ArcaneDB.bar.style`.
- **Hybrid medallion treatments:** class-colored enamel variants are supplied for Warrior, Paladin, Rogue, Priest, Shaman, Mage and Warlock. Hunter and Druid retain the approved original green Arcane medallion; the gold dragon/A artwork is preserved.
- **Hybrid panel edge:** retain the complete right-hand panel endcap beneath the class crest so the bar does not appear cut off.

## v0.2

This release consolidates the current Arcane UI feature set and the previously recorded improvements below. Earlier internal development version labels are intentionally grouped into this release.

- **Skill bar branding:** replace both dragon endcaps with transparent gold-and-black Arcane A medallions; preserve the existing panel rails, slots, and spacing, and keep chat glass clear of the full medallion.
- **Loot pop-up:** Arcane shows item drops with their icon, name and rarity color, plus collection status; marks appear as separate notifications. Up to three stack and fade away. The game's own loot pop-up is restored when the Loot part is turned off.
- **Boss bars:** boss and mini-boss bars are 20% larger; the existing size setting still scales them on top.
- **Boss skulls:** boss skulls are 20% larger, with increased minimum and maximum sizes. Guardian skulls retain their previous apparent size.
- **Lua 5.0 compatibility:** the addon source targets the client's Lua 5.0 runtime.
- **Repository layout:** addon source modules and assets live at the repository root; release packages place them inside the required `Arcane/` install folder.
- **Tiny Plates:** regular nameplates now use Arcane's shared FRIZQT face, hostile-name color and layered enemy-red bars; bosses and guardians use the same bar style at full size. The health numbers inside the bars have their own Show health numbers toggle, independent of bar visibility. The game's health values, V visibility toggle and native restoration when Tiny Plates is off are preserved.
- **Bronze gold everywhere:** every frame's metal (your frame, your target and party, the boss bars, the minimap ring, the meter, the luck window and the rest) is the skill bar's bronze gold in every zone, instead of taking the zone's colors. The boss timer keeps its own.
- **Dragons:** both face out now, perched on the bar's ends with the end rail behind them.
- **The skill bar keeps one size:** it no longer grows when a run starts and the kills, gold and cache show up, or as their numbers get longer.
- **New skill bar look**, from your own bar picture: a painted golden dragon sits on each end of the bar, facing in, wings raised, with room so it never covers a slot; gold diamonds mark the middle of the top and bottom rails.

This section records the project's runtime constraints and observed Azeroth Survivors addon API. It is a maintainer reference, not a list of release changes. API observations should be checked against the live client before depending on them.
