---
type: subsystem
title: Auras widgets
description: The two mutually exclusive implementations of the Auras widget - AurasWidget.lua, which scans and filters auras in Lua on older clients, and AurasWidgetMidnight.lua, which hands declarative filters to Blizzard's AuraContainer/AuraButton frames on clients with secret values - with their data flow, settings handling, pitfalls and limitations.
tags: [auras, widget, midnight, auracontainer, filters, buffs, debuffs, crowd-control]
sources:
  - id: openwiki-source-38f76d8a763c81931c0b6872
    resource: repo://Widgets/AurasWidget.lua
  - id: openwiki-source-a50841d1619063914118d2a2
    resource: repo://Widgets/AurasWidgetMidnight.lua
generated: { by: "claude-code", at: "2026-10-28T19:52:11.033Z" }
verified:
  - by: openwiki/0.7.2
    at: 2026-10-28T19:52:11.033Z
---

# Auras widgets

The Auras widget shows buffs, debuffs and crowd control (CC) on nameplates in up to three grids. There are two
implementations, both registered as widget `"Auras"` and loaded from `Widgets.xml`; each returns at the top of the
file on the "wrong" client, so exactly one exists at runtime:

| File | Active when | Approach |
| --- | --- | --- |
| `Widgets/AurasWidget.lua` (~3,200 lines) | `not Addon.HAS_MIDNIGHT_API` (Classic clients) | reads aura data in Lua (`C_UnitAuras.GetAuraSlots`/`GetAuraDataBySlot`), filters, sorts and draws its own frames |
| `Widgets/AurasWidgetMidnight.lua` (~1,200 lines) | `Addon.HAS_MIDNIGHT_API` (Retail/Midnight, Forever) | configures Blizzard's `AuraContainer` frames, which fetch, filter and draw auras themselves |

Both use the same settings (`Addon.db.profile.AuraWidget`) and options, but some options are hidden or behave
differently on Midnight. The common widget contract is described in [Widget framework](framework.md).

## Pre-Midnight: `AurasWidget.lua`

- Subscribes to `UNIT_AURA` (plus target and combat events). `Widget:UNIT_AURA(unitid, update_info)` finds the
  active widget frame and runs `UpdateAuras`.
- `ProcessAllUnitAuras(unitid, effect)` collects all auras of `HELPFUL` or `HARMFUL` via `GetAuraSlots`/
  `GetAuraDataBySlot`. On Classic Era, buffs of hostile units come from a cache built from `UNIT_AURA` update info
  (`UnitAuraCache`) instead.
- Per aura type and reaction, filter functions (`FilterFriendlyBuffsBySpell`, `FilterEnemyBuffsBySpell`, ...)
  apply "mine only", dispellable, boss, Blizzard flags (where `WOW_FEATURE_BLIZZARD_AURA_FILTER`), and per-spell
  allow/block lists (`FilterBySpell`, parsed by `ParseSpellFilters`). Crowd control is detected from a per-client
  spell table (`CROWD_CONTROL_SPELLS_BY_EXPANSION[Addon.GetExpansionLevel()]`).
- Sorting (none, A-Z, time left, duration, creation), icon mode and bar mode, highlight/glow (LibCustomGlow),
  expiring flash, OmniCC support, "switch area by reaction" for friendly units, and a configuration/demo mode.
- Each aura is checked against aura-based custom style triggers (`StyleModule.AuraTriggerCheckIfActive`), then
  `AuraTriggerUpdateStyle` restyles the plate if a trigger appeared or disappeared (see
  [Styles and custom styles](../rendering/styles.md)).

`CLAUDE.md` mentions a permanent-duration-aura issue in a function `FilterEnemyBuffsBySpell()` that "no longer
exists". It does exist - in this file (`Widget:FilterEnemyBuffsBySpell`), not in the Midnight file - so that note
needs to be re-checked against this function.

## Midnight: `AurasWidgetMidnight.lua`

Aura data is secret on these clients, and the Lua pull APIs can throw or return nothing for nameplate tokens even
outside restrictions (they also throw under addon taint since 12.1.0 [GH-723]). Since Patch 12.1.0, Blizzard's
`AuraContainer`/`AuraButton` frame types do all aura fetching internally after `container:SetUnit(unit)`. This is
the widget's only display path; `HasAuraContainers` (template-existence check for `CustomAuraContainerTemplate`)
is a defensive guard.

### Containers and pooling

`AuraContainer`s cannot be created in combat, but Threat Plates creates widget frames lazily when Blizzard first
hands out a plate. Therefore `PreallocateAuraContainers()` creates 40 containers per aura type (`Buffs`,
`Debuffs`, `CrowdControl`) out of combat - from `OnEnable`, retried on `PLAYER_REGEN_ENABLED/DISABLED` - and
`Widget:Create` claims one per type with `AcquireAuraContainer`. Containers are never returned; if more than 40
plates get a widget frame, the pool is exhausted and an error is logged for that plate.

Each container gets one `AddAuraGroup` per key in `AURA_GROUP_KEYS` (e.g. Debuffs: `main`, `important`,
`importantpersonal`, `boss`, `priority`, `dispellable`, `dispeltype`). A group without configuration is disabled
with a max frame count of 0.

### Filters

`Widget:UpdateAurasGrids` builds per aura type and reaction a set of groups
(`GetFriendlyBuffsGroupConfigs`, `GetEnemyBuffsGroupConfigs`, `GetFriendlyDebuffsGroupConfigs`,
`GetEnemyDebuffsGroupConfigs`, `GetCrowdControlFilterString`), each a filter string (`HELPFUL|PLAYER|...`,
always with `INCLUDE_NAME_PLATE_ONLY`; Debuffs exclude `CROWD_CONTROL`, which has its own grid) plus
`candidateFilters` (`isBossAura`, `canApplyAura`, `includeDispelTypes`, `maxDuration`, ...).

Options toggles are freely combinable OR conditions: `BuildGroupConfigsFromConditions` turns each active toggle
into a group and makes every later group exclude the earlier ones, so an aura matching several toggles is shown
exactly once (symmetric exclusion would hide it completely). "All"/"All on NPCs" short-circuit into one
unrestricted group. The user-facing meaning of every toggle is documented in
`Source/Docs/AurasFilterCriteria.md`, the implementation details and API quirks in
`Source/Docs/AurasWidgetImplementation.md`.

`UpdateAuraContainer` also applies layout (`SetAuraGroupLayout`, flow layout anchor/growth/line size), sorting
(`AtoZ` -> `Name`, `TimeLeft` -> `Expiration`; "Duration"/"Creation" have no equivalent and fall back to
`Default`), and anchoring between grids.

"Switch area by reaction" (friendly units only; CrowdControl is never swapped) swaps the **filters**, not the
layouts, of the Buffs and Debuffs containers in `Widget:UpdateAurasGrids`: friendly buffs are shown in the Debuffs
area and vice versa, each with all settings of the area it is shown in. Each container therefore also declares
the aura group keys of the other type's friendly groups (`AURA_GROUP_KEYS`), as groups cannot be added later.
Until 13.3.4 the layouts were swapped, so swapped auras kept the settings of their own area [GH-770].

### Button appearance

`InitializeAuraButton` runs once per physical `AuraButton`, when Blizzard's pool creates it (inside
`securecallfunction`): icon with tex coords per style and a square mask, a sliced square dispel-type border
(`AddDispelTypeTexture` with `style = PreserveAsset` and a custom color map whose `"None"` key provides the
default buff/debuff color), cooldown swipe, stack count and duration text. The duration text gets a step color
curve (`SetDurationText` with `textColor`) for "highlight expiring" - the Midnight replacement for flashing icons,
which `AuraButton` cannot support.

### Live settings updates and their cost

`Widget:UpdateSettings` does two things:

1. `ReapplyLiveAuraButtonSettings(aura_type)` updates already pooled buttons (size, tooltips, cooldown spiral,
   stack/duration text, duration color curve, border color). It is deferred until after combat and skipped in
   arenas/battlegrounds (buttons are forbidden while their auras are secret). It touches every button of every
   pooled container - up to 5200 buttons, ~0.13 ms each - and once froze the game for 1-2 seconds on every custom
   style change, because `UpdateSettings` runs for unrelated changes too. It is therefore gated by three settings
   signatures: `GetLiveAuraButtonSettingsSignature`, `GetLiveAuraBorderSettingsSignature` (border re-registration
   is ~85% of the cost per button) and `GetLiveAuraDurationColorSettingsSignature`. **A setting newly read in this
   loop must be added to the matching signature**, otherwise its change is skipped until `/reload`.
2. `self:UpdateAllFrames()` re-runs `UpdateAuras` for all active plates, so filter, layout and sort changes apply
   immediately.

Whether a border exists at all (`ShowBorder`) remains create-time-only: adding/removing the dispel texture binding
on buttons that already showed an aura did not work reliably, so only re-coloring an already registered border is
done live.

### API shape detection for dispel borders

`AddDispelTypeTexture`/`RemoveDispelTypeTexture` changed their contract (Forever first, Retail with 12.1.5): no
return value instead of an index, removal by texture region instead of index, and an error when a region is added
twice. Instead of a client or version check, `InitializeAuraButton` stores whatever `AddDispelTypeTexture` returns
in `auraButton.DispelBorderRegistration`, and removal uses `auraButton.DispelBorderRegistration or
auraButton.DispelBorder`. This shape detection is the pattern to follow for future API differences.

### Not available on Midnight

- Bar mode, glow/highlight of stealable auras, icon flashing, configuration/demo mode
  (`ToggleConfigurationMode` and `PrintDebug` are stubs), centered auras, "Duration"/"Creation" sort.
- Per-spell allow/block lists. If ever built with `candidateFilters.includeSpellIDs`/`excludeSpellIDs`: since
  12.1.5 such a group rejects **all** auras on units where spell-ID filtering is not permitted, so set them only
  for the reactions where they are allowed.
- Aura-based custom style triggers: the widget calls `AuraTriggerInitialize`/`AuraTriggerUpdateStyle`, but never
  `AuraTriggerCheckIfActive`, because aura data is not readable.
- Sorting is per group; with several active toggles, the groups are shown one after another, not merged into one
  sort order. Blizzard's own nameplates show the same "time left" order quirks.
- OmniCC support is off (`HideOmniCC` is forced on these clients).
