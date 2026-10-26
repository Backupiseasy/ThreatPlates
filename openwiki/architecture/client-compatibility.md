---
type: architecture
title: Client and expansion compatibility
description: How one Threat Plates codebase detects the running WoW client (Retail/Midnight, WoW Forever, Classic Era and its seasons, TBC and Mists Classic) and branches API usage, data tables, events and features on load-time flags.
tags: [compatibility, clients, expansion, forever, classic, init]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-25T18:59:51.751Z
sources:
  - id: openwiki-source-014010f28568c5a3c3664449
    resource: repo://Addon.lua
  - id: openwiki-source-6eee19a5c8ad4d5edaf05fe2
    resource: repo://Compatibility.lua
  - id: openwiki-source-8e65c9af5eec1ce3c038cede
    resource: repo://Constants.lua
  - id: openwiki-source-4cfab5238eb54f18483ded92
    resource: repo://Init.lua
  - id: openwiki-source-7a3e837cfb6d3795c0c95431
    resource: repo://Nameplate.lua
  - id: openwiki-source-569cf3dd92228cb102027ee0
    resource: repo://Widgets/ArenaWidget.lua
  - id: openwiki-source-38f76d8a763c81931c0b6872
    resource: repo://Widgets/AurasWidget.lua
  - id: openwiki-source-a50841d1619063914118d2a2
    resource: repo://Widgets/AurasWidgetMidnight.lua
  - id: openwiki-source-5ecd0de809f0883fc426f8e2
    resource: repo://Widgets/BossModsWidget.lua
  - id: openwiki-source-45c8931b000866c388b94c2a
    resource: repo://Widgets/HealerTrackerWidget.lua
generated: { by: "claude-code", at: "2026-10-25T18:59:51.751Z" }
---

# Client and expansion compatibility

Threat Plates ships one codebase and one TOC for every supported client. Everything that differs between
clients is decided at load time in `Init.lua` and `Compatibility.lua`, which run before every other addon
file (see [Architecture overview](overview.md)). The rest of the code only reads the resulting flags.

## Client flags (`Init.lua`)

The client flags are plain booleans computed once:

| Flag | Condition | Meaning |
| --- | --- | --- |
| `Addon.IS_MAINLINE` | `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` | Retail (currently Midnight) |
| `Addon.IS_FOREVER` | `WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` | "WoW Forever" |
| `Addon.IS_CLASSIC` | `WOW_PROJECT_ID == WOW_PROJECT_CLASSIC` | Classic Era client only (incl. its seasons) |
| `Addon.IS_TBC_CLASSIC`, `IS_WRATH_CLASSIC`, `IS_CATA_CLASSIC`, `IS_MISTS_CLASSIC` | `GetClassicExpansionLevel() == LE_EXPANSION_*` | Classic progression clients |
| `Addon.IS_MIDNIGHT` | `select(4, GetBuildInfo()) >= 120000` | Interface version 12.x or later |

The client flags `IS_MAINLINE`, `IS_FOREVER`, `IS_CLASSIC` and the progression flags are mutually exclusive.
`WOW_PROJECT_CAMELOT` only exists on Forever, hence the existence check. Forever's first beta builds reported
`WOW_PROJECT_MAINLINE`; never detect Forever through "Mainline project id plus Classic expansion level".

### Classic Era seasons

Classic Era realm types share one client and differ only by `C_Seasons.GetActiveSeason()`:

- `IS_CLASSIC_SOM` - `Enum.SeasonID.SeasonOfMastery`
- `IS_CLASSIC_SOD` - `Enum.SeasonID.SeasonOfDiscovery`
- `IS_CLASSIC_ANNIVERSARY` - `Enum.SeasonID.Fresh` or `Enum.SeasonID.FreshHardcore`
- `IS_TBC_CLASSIC_ANNIVERSARY` - TBC client with season `125`, compared as a number because
  `Enum.SeasonID` has no name for it.

All season flags are additionally gated on the client flag (`Addon.IS_CLASSIC and C_Seasons and ...`), so they
are `false`/`nil` on clients without `C_Seasons`.

## Expansion level helpers

- `Addon.ExpansionIsAtLeast(expansion_id)` returns `true` on Mainline unconditionally, otherwise compares
  `GetClassicExpansionLevel() >= expansion_id`.
- Precomputed flags: `ExpansionIsAtLeastTBC`, `Wrath`, `Cata`, `Mists`, `WoD`, `Legion`, `BfA`,
  `Shadowlands`, `DF`, `TWW`; `ExpansionIsAtLeastMidnight` is an alias of `IS_MIDNIGHT`. There is no
  `ExpansionIsAtLeastClassic`.
- `Addon.ExpansionIsBetween(start, end)` compares the Classic expansion level and returns `false` when
  `GetClassicExpansionLevel` does not exist (Mainline). It does not work for `LE_EXPANSION_CLASSIC` as start.
- `Addon.GetExpansionLevel()` returns the key for expansion-specific data tables: `"MAINLINE"`,
  `"FOREVER"`, `LE_EXPANSION_CLASSIC` for Classic Era, otherwise `GetClassicExpansionLevel()`.

Every table indexed with `GetExpansionLevel()` needs a `FOREVER` entry or must map Forever explicitly. Examples:

- `Constants.lua`: `TOTEM_DATA_BY_EXPANSION` has a `FOREVER` entry (Classic Era's totems without Fire Nova and
  Tranquil Air Totem, plus Decoy Totem) and is read as `TOTEM_DATA_BY_EXPANSION[Addon.GetExpansionLevel()]`.
- `Widgets/QuestWidget.lua` maps Forever to `"MAINLINE"` for its objective parser patterns.
- `Options.lua` uses `"MAINLINE"` for the max-distance slider on all `HAS_MIDNIGHT_API` clients.

## "WoW Forever" is not Classic

Forever reports `LE_EXPANSION_CLASSIC` as expansion level, so every `ExpansionIsAtLeastX` is `false` there. That
says nothing about its features: Forever runs Classic-rules content on Blizzard's modern engine with Midnight's
API surface. Rules that follow from this:

- `IS_CLASSIC` excludes Forever. Code that should apply to both checks `Addon.IS_CLASSIC or Addon.IS_FOREVER`
  (e.g. totem ranks in `Addon:InitializeTotemInformation`, the Arena widget's early `return`).
- A Forever feature beyond Vanilla is enabled with an explicit `or Addon.IS_FOREVER` or a `WOW_FEATURE_*`
  flag, never derived from the expansion level.
- Forever runs a build ahead of live Retail, so it can get an API change first. For an API whose shape differs
  between clients, detect the shape that is there instead of checking a client flag (see
  [Auras widgets](../widgets/auras.md)).

## `HAS_MIDNIGHT_API` vs. `ExpansionIsAtLeastMidnight`

`Addon.HAS_MIDNIGHT_API = Addon.ExpansionIsAtLeastMidnight or Addon.IS_FOREVER` is true whenever the client's
engine has Midnight's API and secret-value surface. Use it for any branch that only picks the modern or
secret-value-safe code path. Keep `ExpansionIsAtLeastMidnight` for genuine ruleset decisions. Examples of
`HAS_MIDNIGHT_API` branches:

- `Widgets/AurasWidget.lua` returns early on it, `Widgets/AurasWidgetMidnight.lua` returns early without it.
- `Widgets/BossModsWidget.lua` and `Widgets/HealerTrackerWidget.lua` are not loaded on it.
- `COMBAT_LOG_EVENT_UNFILTERED` is not registered on it; `UNIT_SPELLCAST_INTERRUPTED` only is.

See [Secret values](secret-values.md) for what this flag protects against.

## Feature flags

| Flag | Definition | Used for |
| --- | --- | --- |
| `WOW_FEATURE_FOCUS` | `ExpansionIsAtLeastTBC or IS_FOREVER` | `PLAYER_FOCUS_CHANGED` registration |
| `WOW_FEATURE_REGIONAL_SURNAMES` | Forever and `RegionalUniqueNamesEnabled()` | `UnitName`'s 2nd return is a surname, not a realm |
| `WOW_FEATURE_BLIZZARD_AURA_FILTER` | `ExpansionIsAtLeast(LE_EXPANSION_LEGION)` | `nameplateShowAll`/`nameplateShowPersonal` aura fields |
| `WOW_FEATURE_ABSORBS` | `type(_G.UnitGetTotalAbsorbs) == "function"` | absorb events and bars; detected by API, not expansion |

`Addon.GetUnitNameWithSurname(unitid, show_surname)` appends the surname with Forever's separator constant
(fallback `" "`), and checks the 2nd return with `Addon.IsSecretValue` before comparing it.

## API wrappers

Wrappers hide API differences so callers use one name:

- `Init.lua`: `Addon.UnitDetailedThreatSituationWrapper` (Classic scales the raw threat value down by 100),
  `Addon.IsSoloShuffle` (stub returning `false` outside Mainline), `Addon.GetSpellInfo` (`C_Spell.GetSpellInfo` on
  Mainline/Mists Classic/Forever, a table-returning wrapper around `_G.GetSpellInfo` elsewhere).
- `Compatibility.lua`: `Addon.C_TooltipInfo_GetUnit_NPCRole`/`_Quest` (`C_TooltipInfo.GetUnit` on DF+ and
  Forever, a hidden `GameTooltip` scanner elsewhere), `Addon.IsSpellKnown`/`IsPlayerSpell` (`C_SpellBook` when
  present), `Addon.CombatLogGetCurrentEventInfo`, `Addon.GetBattlefieldScore` (returns only name and
  talent spec), and `Addon.ShowQuestUnit` stubbed to `false` below Mists unless Forever.
- `Nameplate.lua`: `UnitChannelInfo`/`UnitCastingInfo` shims for Classic Era (channel durations from a spell
  table) and TBC (missing `notInterruptible`), `UnitNameplateShowsWidgetsOnly` stub before Shadowlands, and a
  Forever-specific level difficulty color via `NameplateLevelFrameMixin:GetDifficultyColor`.
- Mandatory shim in every file that uses specialization APIs:
  `local GetSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or _G.GetSpecialization`.

## Events per client

`Compatibility.lua`'s `WOW_EVENTS` maps each WoW event to a boolean for the running client, e.g.
`UNIT_HEALTH` on Mists+ or Forever and `UNIT_HEALTH_FREQUENT` otherwise. Events with a falsy entry are silently
not registered. Details in [Event system](event-system.md).

## Dual specialization and LibDualSpec

`TidyPlatesThreat:OnInitialize` (`Addon.lua`) hands the AceDB database to LibDualSpec only if
`not Addon.IS_CLASSIC or Addon.IS_CLASSIC_SOD or Addon.IS_CLASSIC_ANNIVERSARY`. Plain Classic Era and Hardcore
have no dual specialization, and LibDualSpec either refused to load or errored there depending on its version.
Forever is covered by `not Addon.IS_CLASSIC`.

Player role detection follows the same split in `Nameplate.lua`: from Mists on it uses
`GetSpecialization`/`ACTIVE_TALENT_GROUP_CHANGED`; before that (and on Forever) it uses class/stance/aura
heuristics, preferring `UnitHasEffectivelyTankAura` where it exists and is not secret.

## Open verification items

`Source/Plans/WoWForeverCompatibility.md` tracks Forever checks still open in-game (e.g. friendly guardian
nameplates, health text truncation, options tabs, totem/pet style detection). Treat them as unverified.
