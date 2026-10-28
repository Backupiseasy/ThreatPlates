---
type: reference
title: Other widgets
description: Overview of every Threat Plates widget except Auras - what it shows, which kind of widget it is, on which clients it is loaded, which events drive it, and the pitfalls known from the code.
tags: [widgets, quest, threat, combo-points, resource, bossmods, arena, social, experience, healer-tracker, target-art]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-28T19:58:16.774Z
sources:
  - id: openwiki-source-65a8e958e1c834c2baafb605
    resource: repo://Modules/Color.lua
  - id: openwiki-source-569cf3dd92228cb102027ee0
    resource: repo://Widgets/ArenaWidget.lua
  - id: openwiki-source-5ecd0de809f0883fc426f8e2
    resource: repo://Widgets/BossModsWidget.lua
  - id: openwiki-source-73156574f9a151563ae65aba
    resource: repo://Widgets/ClassIconWidget.lua
  - id: openwiki-source-49541d7e6f523e64845042e5
    resource: repo://Widgets/ComboPointsWidget.lua
  - id: openwiki-source-74b884af48fed2a7832905b5
    resource: repo://Widgets/ExperienceWidget.lua
  - id: openwiki-source-45c8931b000866c388b94c2a
    resource: repo://Widgets/HealerTrackerWidget.lua
  - id: openwiki-source-4174717d9513e533ba3cdafd
    resource: repo://Widgets/QuestWidget.lua
  - id: openwiki-source-dbafaf2d926d138e0d3c5f5a
    resource: repo://Widgets/ResourceWidget.lua
  - id: openwiki-source-3591a6eb088065fd73abe2aa
    resource: repo://Widgets/SocialWidget.lua
  - id: openwiki-source-0a31e436682c2bf333a46db9
    resource: repo://Widgets/TargetArtWidget.lua
  - id: openwiki-source-58005e377c00ab0f1169379c
    resource: repo://Widgets/ThreatWidget.lua
  - id: openwiki-source-b7ac150bb24719a1847041c1
    resource: repo://Widgets/TotemIconWidget.lua
  - id: openwiki-source-1a5a5f227c83fc5a4a86a9b2
    resource: repo://Widgets/UniqueIconWidget.lua
  - id: openwiki-source-6794fbfa2ece0a99802c941d
    resource: repo://Widgets/WidgetHandler.lua
generated: { by: "claude-code", at: "2026-10-28T19:58:16.774Z" }
---

# Other widgets

All widgets follow the contract in [Widget framework](framework.md). The Auras widget has a page of its own
([Auras widgets](auras.md)); scripted custom styles (Script widget) are described in
[Styles and custom styles](../rendering/styles.md#scripted-custom-styles-widgetsscriptwidgetlua).

## Overview

| Widget (name) | File | Kind | Loaded on | Shows |
| --- | --- | --- | --- | --- |
| Quest | `QuestWidget.lua` | per plate | Mists+ and Forever | quest icon/progress on quest units; quest healthbar color |
| Threat | `ThreatWidget.lua` | per plate | all | threat textures and threat percentage |
| ComboPoints | `ComboPointsWidget.lua` | target-only | all | combo points, chi, holy power, soul shards, essence, runes, ... of the player |
| Resource | `ResourceWidget.lua` | target-only | all | the target's power bar/text |
| TargetArt | `TargetArtWidget.lua` | target-only | all | highlight of target and soft targets (also soft-target icons) |
| Focus | `TargetArtWidget.lua` | focus-only | where focus exists | highlight of the focus |
| ClassIcon | `ClassIconWidget.lua` | per plate | all | class icon of players |
| TotemIcon | `TotemIconWidget.lua` | per plate | all | icon of known player totems |
| UniqueIcon | `UniqueIconWidget.lua` | per plate | all | icon (or portrait) and glow of custom styles |
| Social | `SocialWidget.lua` | per plate | all | friend/Battle.net friend/guild icon, faction icon; friend/guild healthbar colors |
| Arena | `ArenaWidget.lua` | per plate | not Classic Era, not Forever | arena number/icon of opponents and party members |
| Experience | `ExperienceWidget.lua` | per plate | BfA+ (i.e. Retail) | experience bar of NPCs with Blizzard's UI widget (companions like Farseer Ori) |
| BossMods | `BossModsWidget.lua` | per plate | not with `HAS_MIDNIGHT_API` | boss mod (DBM) nameplate auras and timers |
| HealerTracker | `HealerTrackerWidget.lua` | per plate | not with `HAS_MIDNIGHT_API` | healer icon on enemy players |
| Script | `ScriptWidget.lua` | per plate | all (if scripting enabled) | custom script code |

"Loaded on" is decided by an early `return` at the top of each file. `WIDGET_INFO` in `Options.lua` maps the
settings key of each widget to its name (e.g. `questWidget` -> `Quest`) and decides how an options change is
propagated (see [Options UI and propagating setting changes](../settings/options-and-updates.md)).

## Notes per widget

### Quest

- Determines quest units from the unit tooltip (`Addon.C_TooltipInfo_GetUnit_Quest`): on `HAS_MIDNIGHT_API`
  clients by tooltip line types (`QuestTitle`, `QuestPlayer`, `QuestObjective`), elsewhere by line colors of the
  hidden tooltip scanner. Objectives of other group members are skipped (group roster kept outside Midnight).
- Caches the quest log (`QUEST_LOG_UPDATE`, `QUEST_ACCEPTED`, `QUEST_REMOVED`, `QUEST_WATCH_UPDATE`,
  `QUEST_DATA_LOAD_RESULT`, `UNIT_QUEST_LOG_CHANGED`), handles combat visibility (`PLAYER_REGEN_*`, `ThreatUpdate`).
- Exports `Addon.ShowQuestUnit(unit)` and `Addon:IsPlayerQuestUnit(unit)`, used by the Color module for the quest
  healthbar color; option changes publish `SituationalColorUpdate`.
- Forces the CVar `showQuestTrackingTooltips` to 1.
- Tooltip lines contain only the first name, so on Forever it compares with `UnitName("player")`, not with
  `Addon.PlayerName` (which includes the surname).
- History: a disabled Quest widget used to stay subscribed to `ThreatUpdate` and crashed in epic battlegrounds
  (fixed in `EventService.UnsubscribeAll`).

### Threat

Enabled by threat art or any threat percentage option. For non-player units it shows left/right threat textures
(per theme, reversed for dps/heal) and the threat percentage from `UnitDetailedThreatSituation` (text and color
optional), refreshed on `UNIT_THREAT_LIST_UPDATE`, `TargetMarkerUpdate` and `GROUP_ROSTER_UPDATE`. Uses the
threat level computed by the Threat module (see [Modules](../rendering/modules.md)).

### ComboPoints

Target-only widget with one shared frame that is moved to the current target (or the soft-enemy target if the
target cannot be attacked). `IsEnabled()` determines the player's power type for the current class/spec
(`DetermineUnitPower`) and is false if the spec has none. It subscribes to `ACTIVE_TALENT_GROUP_CHANGED` and
`TRAIT_CONFIG_UPDATED` already in `IsEnabled()`, so a spec change can enable the widget later; `OnDisable` keeps
those two while the widget is configured on. Power updates come from player unit events (`UNIT_POWER_UPDATE`,
`UNIT_POWER_FREQUENT` for Evokers, `UNIT_MAXPOWER`, `UNIT_POWER_POINT_CHARGE`), runes from `RUNE_POWER_UPDATE`,
druid forms from `UPDATE_SHAPESHIFT_FORM`.

Code detail: `self:SubscribeEvent("ACTIVE_TALENT_GROUP_CHANGED", Addon.ExpansionIsAtLeastMists)` passes the
boolean as the handler argument (the widget wrapper's second parameter is `func`, not an expansion flag). It only
works because `true`/`false` both end up as "call the method", and `WOW_EVENTS` gates the event anyway.

### Resource

Target-only: power bar and/or text for the target (`UnitPowerType`, alternate power colors, optional "alternate
power only"). Skips a secret max power value. Events: `PLAYER_TARGET_CHANGED`, `UNIT_POWER_UPDATE` and
`UNIT_DISPLAYPOWER` for `"target"`.

### TargetArt and Focus

One highlight frame per target token (`target`, `softenemy`, `softfriend`, `softinteract`), reparented to the
plate of that unit on the corresponding change event; themes as side textures or border, name mode texture in
headline view, optional soft-target icons depending on the soft-target icon CVars. The Focus widget in the same
file works the same way for `focus`. See [Target, soft target, mouseover and focus](../nameplates/targets-mouseover-focus.md).

### ClassIcon, TotemIcon, UniqueIcon

- ClassIcon: icon per class for hostile/friendly players (separate toggles); hides itself if `unit.class` is
  secret (Arenas/Battlegrounds on 12.1+).
- TotemIcon: active for `totem`/`etotem` styles of units recognized as player totems, icon per totem spell id;
  refreshed on `UNIT_NAME_UPDATE`.
- UniqueIcon: enabled when any custom style uses an icon or glow (`Addon.UseUniqueWidget`); shows the custom
  style's icon, the aura/cast spell icon (`AutomaticIcon`) or the unit portrait (refreshed on
  `UNIT_PORTRAIT_UPDATE`), and LibCustomGlow effects.
- ClassIcon and UniqueIcon register Masque groups (see [Modules](../rendering/modules.md#icon-modulesiconlua)).

### Social

Keeps lists of guild members, friends and Battle.net friends **keyed by GUID** (secret GUIDs are skipped), from
`GUILD_ROSTER_UPDATE`, `FRIENDLIST_UPDATE` and `BN_*` events. Shows an icon and a faction icon on player plates,
and provides `Addon:IsFriend`/`Addon:IsGuildmate` for friend and guild healthbar colors (publishes
`ClassColorUpdate`). The open item in `CLAUDE.md` about name-based keys in this widget is outdated: lookups are
GUID-based now.

### Arena

Shows arena numbers (or icons) for opponents (`ARENA_OPPONENT_UPDATE`) and optionally for party members
(`GROUP_ROSTER_UPDATE`), active only in arenas (`PLAYER_ENTERING_WORLD`, not in brawls).

### Experience

Experience bar for NPCs that Blizzard shows with a status bar UI widget, mapped by NPC id to the UI widget id
(table from ElvUI); hides Blizzard's widget container for these NPCs while enabled; refreshed on
`UPDATE_UI_WIDGET`. It depends on `unit.NPCID`, which is `nil` on `HAS_MIDNIGHT_API` clients, so on Retail it
always hides itself. It is not loaded on Forever at all (`ExpansionIsAtLeastBfA` is false there), so the open
Forever check for it in `Source/Plans/WoWForeverCompatibility.md` does not apply.

### BossMods

Integration with boss mods through DBM's callbacks (`DBM:RegisterCallback`): `BossMod_ShowNameplateAura`/
`HideNameplateAura` and timer callbacks show spell icons with durations on boss/add nameplates; `TidyPlatesThreatDBM` (global) tells
DBM that Threat Plates supports it. Not loaded on `HAS_MIDNIGHT_API` clients.

### HealerTracker

Detects enemy healers from the combat log, the battleground score board and arena opponent specs, keyed by GUID,
and shows an icon. Not loaded on `HAS_MIDNIGHT_API` clients (combat log unavailable; `GetArenaOpponentSpec`
always returns secrets since 12.1.5). Its `if not guid then return end` does not catch secret GUIDs, see
[Secret values](../architecture/secret-values.md#open-issues-re-verify-before-acting).
