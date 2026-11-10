# Arcane UI module map

This document describes the source layout and the runtime rules behind it. The addon targets the Azeroth Survivors 1.12.1 client and its Lua 5.0 runtime.

## Runtime entry point

- `Arcane.toc` is the authoritative file list and load order. Do not rely on folder enumeration or alphabetical ordering.
- `Core.lua` creates the global `Arcane` namespace and the stable asset/font paths.
- Files under `Core/` add shared services. `Core/Startup.lua` is deliberately last among Core modules so the card-screen handler and all registered services exist before startup callbacks run.
- Localized dictionaries load after Core localization, before feature modules use them.
- Feature modules register their initialization callbacks while their files load. The client dispatches initialization after the addon files have loaded.

## Folder ownership

| Folder | Responsibility |
| --- | --- |
| `Core/` | Shared math, drawing, language/font handling, saved settings, stock-HUD handoff, bars, sizing, panels, safe calls, movement, options, commands, cards and shared unit-frame helpers. |
| `Locales/` | English source strings and translated dictionaries. |
| `Timer/` | Boss timer data and its renderer/controller. |
| `Numbers/` | Damage-number configuration, combat intake, icons, labels, world anchors, layout, culling, placement, animation, lifecycle, options and commands. |
| `SkillBar/` | Class/style data, visual style controller and the skill-slot/XP renderer. |
| `Frames/` | Bosses, skulls, the player frame, party, downed-player and stored-level-up frames, stock notifications and native text styling. |
| `Minimap/` | Minimap presentation, edge button, cache pins and lair pins. |
| `Windows/` | Tally, meter, damage/healing, pets, luck, summary, character, stats, talents and chat windows. |
| `Nameplates/` | Arcane Nameplates replacement and its options. |
| `Loot/` | Loot-set data and loot notifications. |

## Shared components

Shared behavior belongs to one owner under `Core/`; feature modules should call it rather than copy it. For example, the player and party frames now use `Core/UnitFrames.lua` for health-number formatting and the mana/rage/focus/energy palettes.

Use a shared helper when the behavior and its contract are genuinely the same. Do not merge controls that only look similar but have different interaction, lifecycle or visual requirements. Keep feature-specific tuning close to the feature that owns it.

## Load-order and compatibility rules

- Keep `Art/` and `Fonts/` at the addon root. `Arcane.ART` and existing game texture paths depend on those locations; this refactor does not move or rename assets.
- Use paths relative to the addon folder in `Arcane.toc`. Add each Lua file explicitly and in dependency order.
- Target Lua 5.0: use `table.getn`, `string.find` captures and `math.mod` where needed. Do not introduce newer syntax or APIs.
- Keep each loaded Lua chunk below the 200 file-scope-local limit.
- Keep game-facing frame names, saved-variable keys, slash commands, asset paths and public `Arcane.*` integration points stable unless a behavior change is intentional.
- When extracting code, preserve the original statements and lexical locals first. Move one responsibility at a time; do not mix a structural move with a visual redesign.
- Run the repository architecture audits and Lua compilation. Those use Lua 5.1 as a syntax check only; test runtime behavior in the actual Lua 5.0 client.

## Next candidates for smaller modules

The largest remaining feature files are candidates for later, isolated extractions: `Timer/Timer.lua`, `Windows/Meter.lua` and `Windows/Character.lua`. Each owns a coherent feature but may still contain internal responsibilities worth separating when the boundaries are clear. Split those by data intake, presentation, interaction and lifecycle only when the boundaries can be kept explicit and the live client can verify the result.

## Arcane Nameplates

Arcane Nameplates is split by responsibility rather than by individual helper:
- `Nameplates/State.lua` owns native plate discovery, child-state snapshots and safe visibility restoration.
- `Nameplates/SpecialTargets.lua` owns boss/guardian identity and debuff presentation.
- `Nameplates/Visuals.lua` owns replacement bars, labels and plate styling.
- `Nameplates/ArcaneNameplates.lua` owns discovery cadence, update scheduling and addon lifecycle.
- `Nameplates/ArcaneNameplatesOptions.lua` owns the settings UI and saved option access.

The controller delegates to these modules in TOC order. Arcane Nameplates is Arcane's required enemy-plate renderer and remains active whenever Arcane is loaded. The game's native `V` command owns enemy-plate visibility. Azeroth Survivors creates anonymous `Button` children under `WorldFrame`, hides retired plates, and reuses free pool slots. The Arcane replacement bar is parented to the same button, so it follows the game's show/hide state without binding or overriding `V`. The registry is therefore bounded by the game's high-water plate pool; no guessed cleanup timer is needed. There is no second hide checkbox and no stock-renderer fallback.

Arcane-owned code uses the `C.Nameplates` namespace and `arcaneNameplates*` frame state. The existing `ArcaneDB.nameplates` saved-settings key is intentionally retained so upgrades keep custom colors and display preferences. `AZSUNITS`, `AZS_UNITS` and the other `AZS_*` names belong to Azeroth Survivors and must remain unchanged; they are integration contracts, not Arcane branding.


Arcane Nameplates does not own the `WorldFrame` plate root's dimensions, scale or projected position. Azeroth Survivors updates the root anchor as units move; Arcane Nameplates anchors its overlay to the native health bar and restores only native child visibility/alpha that it changed.

## Native text styling

`Frames/NativeText.lua` adds a colored outline behind the game's native zone/subzone announcement strings and themes the existing floating combat text. Blizzard still creates messages, applies visibility settings, chooses message types, animates/fades floating lines, and owns the zone announcement lifecycle. Arcane does not replace `CombatText_AddMessage`, rewrite its event handlers, or change scroll/fade constants.

The native `ZoneTextString` and `SubZoneTextString` are never restyled or moved. Their original font face, exact font size, fill color (including PvP context colors), anchors, text and native fade remain intact. Eight offset copies of the current glyphs are drawn on the native frame's BACKGROUND layer, behind the untouched native FontString. The copies use the native face and exact size, with an explicit measured line height, and are tinted with `Arcane.pal.rim`—the same live zone-rim color used by the timer's metal trim. There are no side ornaments, banner, background panel or extra zone text.

The floating positive aura/cast and healing categories use `Arcane.pal.title` and `Arcane.pal.mc`, respectively, so the colors follow the timer's interpolated zone palette. The existing floating-text font-string pool uses Arcane typography without changing its point size, text-height animation, visibility settings or scroll/fade timing. The native gameplay notification feed remains `UIErrorsFrame`; its existing title-color hook is unchanged. Lua script errors remain separate. Live-client testing is still required in the 1.12.1 / Lua 5.0 client.
