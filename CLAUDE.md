# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TidyPlates_ThreatPlates (TPTP) is a World of Warcraft AddOn (Lua/XML/TOC) that replaces Blizzard's default
nameplates with a highly customizable, threat-reactive nameplate system. A single codebase targets
Retail/Midnight and all Classic versions (Vanilla through Mists of Pandaria Classic) via expansion-compatibility
flags computed at load time.

- Curseforge: https://wow.curseforge.com/projects/tidy-plates-threat-plates
- Source: https://github.com/Backupiseasy/ThreatPlates
- Current branch `feature/midnight` targets the Midnight expansion (`Interface: 120005`).
- Versioning: major version = WoW expansion (7.x, 8.x, ...), minor = new functionality, patch = bugfixes.

## Build, Lint & Test

There is no compile step — the addon is loaded directly by the WoW client from this directory
(`Interface/AddOns/TidyPlates_ThreatPlates`).

- Lint, full local profile: `luacheck . --config .luacheckrc`
- Lint, CI gate (accidental-global-write check only, rules 111/112): `luacheck . --config .luacheckrc.ci`
- Both configs use `std = "lua51"`, exclude `Libs/`, `Test/`, `Source/`, `.release/`, and whitelist addon globals
  (`TidyPlatesThreat`, `SLASH_TPTP*`, `SlashCmdList`, `StaticPopupDialogs`, ...).
- Manual test: in-game `/reload` and check the Lua error console (BugSack/!BugGrabber recommended).
- No automated test runner; `Test/` contains standalone scripts/mocks (performance tests, API mocks), not wired
  into CI.
- Prefer minimal, defensive fixes over broad refactors; keep API and SavedVariables compatibility. If UI text
  changes, update `Locales/*.lua` too (see Changelog Workflow below for the separate changelog-string workflow).

### WoW API MCP server (`wow-api`)

If configured in this environment, the `wow-api` MCP server indexes 8,000+ WoW API functions (from the
`ketho.wow-api` extension) and is the first tool to reach for when looking up API signatures, deprecations,
enums, or events — faster than a web search of WoW Wiki/wow-ui-source for a quick lookup.

| Tool | When to use |
| --- | --- |
| `lookup_api(name)` | Exact signature, deprecation status, and wiki link for a function |
| `search_api(query)` | Free-text search over all API names/descriptions |
| `list_deprecated(filter?)` | Deprecated functions with their replacement and patch version |
| `get_namespace(name)` | All functions of a `C_` namespace (e.g. `C_SpecializationInfo`) |
| `get_widget_methods(type)` | Methods of a UI widget type (e.g. `Frame`, `Button`) |
| `get_enum(name)` | Enum values (e.g. `Enum.SpellBookSpellBank`) |
| `get_event(name)` | Event payload parameters (e.g. `ACTIVE_TALENT_GROUP_CHANGED`) |

Compatibility-shim pattern for APIs moved under `C_SpecializationInfo` on Midnight — mandatory in any file
using these APIs:

```lua
local GetSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or _G.GetSpecialization
local GetSpecializationInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or _G.GetSpecializationInfo
```

## Unified TOC

`TidyPlates_ThreatPlates.toc` is the single manifest for every supported client. Its `## Interface:` line is
comma-delimited (e.g. `120007, 11508, 20506, 50504`), which WoW clients (Mainline 10.2.7+, Classic Progression
4.4.0+, Classic Era 1.14.0+) read natively to pick the right ruleset — no per-flavor `.toc` files or packager
`-g`/`-S` build variants are needed. This is also the canonical load-order list and what CurseForge/Wago
packaging processes. Wrath (30405) and Cata (40402) are not yet supported and therefore not in the Interface
line (see the comment above it in the TOC).

## Architecture

### Load order (see `TidyPlates_ThreatPlates.toc`)

`Libs/` → `Locales/` → `ThreatPlates.xml` (shared templates) → `Init.lua` (expansion flags/globals) →
`Debug.lua` → `Compatibility.lua` (event/version shims) → `Modules/Localization.lua` → `EventService.lua` →
`CVarsManager.lua` → `Media.lua` → `Constants.lua` → `Modules/*.lua` → `Elements/*.lua` →
`Widgets/WidgetHandler.lua` → `Nameplate.lua` → `Database.lua` → `Addon.lua` → `Commands.lua` → `Options.lua` →
`Styles/*.lua` → `Widgets/*.lua`.

- `EventService.lua` is the obsolete old event handler code's replacement — the old code in
  `Widgets/WidgetHandler.lua` is intentionally commented out, not dead code to clean up casually.
- Widgets may omit `OnEnable`/`OnDisable` entirely if no lifecycle logic is needed.

### Expansion / version compatibility (`Init.lua`, `Compatibility.lua`)

Flags computed once at load and used everywhere to branch behavior:

- `Addon.IS_MAINLINE`, `Addon.IS_CLASSIC`, `Addon.IS_MISTS_CLASSIC`, `Addon.IS_MIDNIGHT`, plus
  `IS_TBC_CLASSIC` / `IS_WRATH_CLASSIC` / `IS_CATA_CLASSIC` / `IS_CLASSIC_SOM` / `IS_CLASSIC_SOD`.
- `Addon.IS_CLASSIC` and its siblings cross-check `GetClassicExpansionLevel()` in addition to
  `WOW_PROJECT_ID`/`WOW_PROJECT_CLASSIC`, because `WOW_PROJECT_ID` alone is unreliable on some official
  Blizzard clients — see "'WoW Forever' — an Official Client With Midnight's API Surface" below.
- `Addon.ExpansionIsAtLeastX` (X = TBC, Wrath, Cata, Mists, WoD, Legion, BfA, Shadowlands, DF, TWW, Midnight) —
  always `true` on Mainline, otherwise compares `GetClassicExpansionLevel()`.
- `Addon.HAS_MIDNIGHT_API` (`Addon.ExpansionIsAtLeastMidnight or Addon.IS_FOREVER`) — true whenever the running
  client's *engine* has Midnight's API/secret-value surface, regardless of its *ruleset*. Use this (not
  `Addon.ExpansionIsAtLeastMidnight`) for any branch that exists purely to pick the secret-value-safe/modern
  API code path; keep `Addon.ExpansionIsAtLeastMidnight` itself for genuine ruleset/feature decisions.
- `Addon.WOW_USES_CLASSIC_NAMEPLATES` — true for Classic-style nameplates (Vanilla..WoD, excluding Mists
  Classic, which uses the modern nameplate API).
- `Compatibility.lua`'s `WOW_EVENTS` table + `Addon:RegisterEvent` / `RegisterUnitEvent` / `UnregisterEvent` gate
  WoW event registration per expansion — events that don't exist for the running client are silently skipped.
  `/tptp debug Compatibility` empirically tries registering every event in the table and reports mismatches.

### Event system (`EventService.lua`)

Central pub/sub for both real WoW events and internal TP events (`INTERNAL_EVENTS`, e.g. `ThreatUpdate`,
`CastingStarted`/`CastingStopped`, `MouseoverOnEnter`/`MouseoverOnLeave`, `TargetGained`):

- `EventService.Subscribe(subscriber, event, func, register_for_current_expansion)` / `Unsubscribe` /
  `UnsubscribeAll(subscriber)`.
- `EventService.Publish(event, ...)` fans out to all subscribers.
- A single `EventHandlerFrame` dispatches all registered WoW events through `EventHandler`.
- Widgets/modules typically subscribe in `OnEnable` and must call `UnsubscribeAll` in `OnDisable` — note
  `UnsubscribeAll` also checks `INTERNAL_EVENTS`, since `Addon:ExpansionSupportsEvent` returns `false` for
  internal (non-WoW) events. Always verify `UnsubscribeAll` is called in `OnDisable` for widgets that subscribe
  to internal TP-events (default behavior in `WidgetHandler:NewWidget`) — a widget left subscribed after being
  disabled can crash other code that assumes its state was torn down (historical bug: `widgets.Quest = nil`
  crash in `QuestWidget:ThreatUpdate` in epic battlegrounds, because `UnsubscribeAll` originally only checked
  `Addon:ExpansionSupportsEvent(event)`, which is `false` for internal events, so `ThreatUpdate` stayed
  subscribed after the Quest widget was disabled; fixed by also checking `INTERNAL_EVENTS[event]`).

### Nameplate lifecycle (`Nameplate.lua`)

- `NAME_PLATE_CREATED` → `NAME_PLATE_UNIT_ADDED` → `HandlePlateUnitAdded(plate, unitid)`: calls
  `SetUnitAttributes(unit, unitid)` (sets `unit.unitid`), then `SetNameplateVisibility(plate, unitid)` (sets
  `tp_frame.Active`).
- `NAME_PLATE_UNIT_REMOVED`: sets `tp_frame.Active = false` and `wipe(tp_frame.unit)` — the only place that
  clears `unit.unitid`.
- **Invariant**: `tp_frame.Active == true` ⟺ `tp_frame.unit.unitid ~= nil`. Code that reads `unit.unitid` outside
  the unit-added path must check `tp_frame.Active` first.
- `PlayerTargetChanged(...)` is the shared handler for `PLAYER_TARGET_CHANGED`, `PLAYER_SOFT_FRIEND_CHANGED`,
  `PLAYER_SOFT_ENEMY_CHANGED`, and `PLAYER_SOFT_INTERACT_CHANGED`.
- **Stale unit data after nameplate recycling**: WoW can reassign a nameplate's unit token to a different unit
  without firing `NAME_PLATE_UNIT_REMOVED` first, and `UNIT_FACTION`/`UNIT_FLAGS` can fire before the client has
  actually received the server's updated name/health/GUID for that token (confirmed independently by Plater's
  `Plater.ScheduleUpdateForNameplate`, which documents the same client/server sync lag). Symptom: a nameplate
  shows the previous occupant's name and/or health (frozen, not updating) — reported in battlegrounds, arenas,
  and raids [Comment #8228, #8363, #8408, #8433]. Mitigated by `ScheduleNameplateRevalidation(plate, unitid,
  delay)` in `Nameplate.lua`, which re-runs `HandlePlateUnitAdded` after a short delay (0 frames for
  `UNIT_FACTION`/`UNIT_FLAGS`, 0.5s for a detected double `NAME_PLATE_UNIT_ADDED` without an intervening
  `REMOVED`), guarded against the plate having legitimately moved on in the meantime. This is a *data* problem
  (TP's own `unit` table is wrong); see the next bullet for a look-alike that is a *placement* problem.
- **`plate.UnitFrame` is pooled — re-anchor `TPFrame` on every acquire**: on Mists Classic and the modern engine
  (Midnight, "WoW Forever"), Blizzard's `NamePlateBaseMixin:AcquireUnitFrame` takes an arbitrary frame from a pool on
  every `NAME_PLATE_UNIT_ADDED` and `ReleaseUnitFrame` sets `plate.UnitFrame = nil` on `REMOVED`, so a plate can get
  a *different* (already `unit_frame.ThreatPlates`-flagged) instance each time. `tp_frame` is a child of `plate` but
  is anchored (`CENTER`) to `plate.UnitFrame`, so `NamePlateDriverFrame_AcquireUnitFrame` (`Nameplate.lua`) must
  call `SetPoint` on **every** acquire, outside the "first time this `unit_frame` is seen" block that installs the
  hooks. Symptom when it doesn't (regression from 2026-01-27, fixed 13.3.0): all TP data is correct
  (`Active == true`, `TPFrame:IsShown()`, right name/reaction/style, alpha 1) but the plate is briefly drawn over
  another unit (wrong name/reaction) and then vanishes — the stale anchor points at a frame that is now either
  released (no points) or used by another plate. Diagnose in-game with `/run local p =
  C_NamePlate.GetNamePlateForUnit("target"); local _, rel = p.TPFrame:GetPoint(); print(rel == p.UnitFrame,
  p.TPFrame:IsVisible(), p.TPFrame:GetAlpha(), p.TPFrame:GetLeft())` — `false` (and no `GetLeft`) confirms it.
  Related: Blizzard's `AcquireUnitFrame` post-hook runs before `plate.UnitFrame` is assigned, hence the manual
  re-call from `Addon:NAME_PLATE_UNIT_ADDED`/`ScheduleNameplateRevalidation`. Also note that
  `SetShownBlizzardPlate`'s protected branch does `ClearAllPoints()`+`SetParent(nil)` on `UnitFrame` — anything
  anchored to it loses its rect while it is reparented, so prefer anchoring to the (stable) `plate` for new frames.
- **Event-ordering rule**: WoW script handlers (`OnShow`, `OnHide`, `OnEvent`) fire **synchronously** when the
  corresponding C-side API is called (confirmed by WoW Wiki's `ScriptRegion:Show()` docs) — `Show()` fires
  `OnShow` immediately within the same call, and `HookScript("OnShow", ...)` hooks run synchronously too. Game
  events like `UPDATE_MOUSEOVER_UNIT` and `UNIT_FACTION` are **not** documented to fire inside a running Lua
  call; they fire between Lua event handler calls (empirically observed: `UNIT_FACTION` fires between
  `NAME_PLATE_UNIT_REMOVED` and `NAME_PLATE_UNIT_ADDED` in solo-shuffle). Rule: always clear derived state
  (mouseover, focus, target references) **before** calling `wipe(unit)` in `NAME_PLATE_UNIT_REMOVED`, so any
  subsequent event handler still finds valid unit data. (This is also why `NAME_PLATE_UNIT_REMOVED` clears the
  `PlatesByUnit["mouseover"]` stale reference before `wipe(unit)` — it used to nil-crash
  `Transparency.lua:GetTransparency` when `UPDATE_MOUSEOVER_UNIT` fired mid-recycling.)
- **Personal nameplate filtering**: five locations filter the player's own nameplate; all must stay consistent:
  1. `GetThreatPlateForUnit`: `unitid == "player"` (literal string guard).
  2. `GetThreatPlateForUnit`: `Addon.UnitIsUnit("player", unitid)` — **not** redundant with #1:
     `UnitIsUnit("player", unitid)` can return a secret value even with `"player"` as the first argument (a
     real crash was observed with `unitid = "targettarget"` in a PvP/Encounter restriction context) — the safe
     wrapper is required here.
  3. `IgnoreUnitForThreatPlates`: gate for `NAME_PLATE_UNIT_ADDED` and `FrameOnShow` — uses `Addon.UnitIsUnit`.
  4. `FrameOnShow`: `Addon.UnitIsUnit(unitid, "player")`.
  5. `FrameOnUpdate`: `Addon.UnitIsUnit(plate.UnitFrame.unit or "", "player")`.

### Visual pipeline: Styles → Modules → Elements → Widgets

- **Styles** (`Styles/`): `Addon:RegisterTheme(name, create)` / `Addon:SetThemes()` populate `Addon.Theme`.
  `StyleModule.SetStyle(unit)` picks a style name (`normal`, `dps`, `tank`, `Unique`, `NameOnly`, `Empty`,
  `Totem`, `Etotem`, `NameOnly-Unique`, ...) from unit type, custom plate triggers, and threat situation.
  `StyleModule.Update(tp_frame)` (`Styles/Styles.lua`) applies the chosen style and drives, in order:
  `ColorModule.UpdateStyle` → `TransparencyModule.UpdateStyle` → `ScalingModule.UpdateStyle` →
  `ElementHandler.UpdateStyle` (all Elements) → `WidgetHandler:OnUnitAdded` (all enabled Widgets) →
  `Addon:UpdateCastbar`.

Modules, Elements and Widgets model different things and use different calling conventions:

| | Modules (`Modules/`) | Elements (`Elements/`) | Widgets (`Widgets/`, `WidgetHandler.lua`) |
| --- | --- | --- | --- |
| Registration | `local XModule = Addon.X` (pre-existing singleton table, e.g. `Addon.Font`) | `Addon.Elements.NewElement("Name")` → ordered `ElementsPriority` + `Elements` lookup | `Addon.Widgets:NewWidget("Name")` (or `:NewTargetWidget`/`:NewFocusWidget` for target-/focus-only) |
| Function syntax | **dot**, no `self` (`function FontModule.UpdateText(...)`) | **dot**, no `self` (`function Element.PlateCreated(...)`) | **colon**, `self` = the widget singleton (`function Widget:OnUnitAdded(...)`) |
| Per-plate state | none — stateless utility/service, shared by Elements and Widgets | `tp_frame.visual.<Name>` — part of the core nameplate | `tp_frame.widgets[<Name>]` — separate child frame with its own `.Active`/`.unit` |
| Present on every plate? | n/a | always (hidden via `UpdateStyle` if `style.show == false` / `plate_style == "None"`) | only if `IsEnabled()` and `EnabledForStyle()` |
| Driven by | direct calls from `Styles.lua` / `CVarsManager.lua` / `Options.lua` / other modules | `ElementHandler` loop over `ElementsPriority` (registration order matters) | `WidgetHandler` loops over `EnabledWidgets` / target-/focus-only lists |
| Lifecycle hooks (all optional unless noted) | `UpdateSettings()`, `UpdateStyle(tp_frame)` | `PlateCreated` (required), `PlateUnitAdded`, `PlateUnitRemoved`, `UpdateStyle(tp_frame, style, plate_style)`, `UpdateSettings()` | `IsEnabled`/`Create`/`EnabledForStyle`/`OnUnitAdded` (required), `OnEnable`/`OnDisable` (default no-op / unsubscribe-all), `UpdateFrame`, `UpdateLayout`, `UpdateSettings`, `OnTarget-/FocusUnitAdded/Removed` |
| WoW event subscriptions | rare/none | rare (e.g. `Elements/Level.lua` subscribes `UNIT_LEVEL` directly) | common — primary event layer, via `function Widget:EVENT_NAME(...)` |
| Examples | Font, Icon, Animation, Threat, Color, Transparency, Scaling, Localization | Healthbar, Name, Castbar, SpellIcon, StatusText, MouseoverHighlight, ThreatGlow, TargetMarker, Classification, Level | Auras, ComboPoints, Quest, Threat, TotemIcon, Arena, BossMods, Social, Stealth, Experience, Resource, ClassIcon, UniqueIcon, TargetArt, HealerTracker, Script |

`WidgetHandler:InitializeAllWidgets()` enables/disables each widget based on `IsEnabled()`. A widget without
extra lifecycle logic may omit `OnEnable`/`OnDisable` entirely.

**Pitfall — dot vs. colon calls**: Module and Element API functions are dot-defined (no `self`). Calling one
with `:` (e.g. `Font:UpdateText(...)` instead of `Addon.Font.UpdateText(...)`) silently injects the module
table as an extra leading argument and shifts every real argument by one position. If the receiver isn't even a
defined local/global (e.g. a stray `Animation:Flash(...)` where only `AnimationFlash` was imported), it's
instead an immediate "attempt to index a nil value" error. The established convention is to import module
functions as local upvalues (`local FontUpdateText = Addon.Font.UpdateText`,
`local AnimationFlash, AnimationStopFlash = Addon.Animation.Flash, Addon.Animation.StopFlash`) and call them as
plain functions.

### Database / profiles (`Database.lua`, `Addon.lua`)

AceDB-3.0 based: `Addon.db.profile` (per-character: frame/healthbar/castbar/color/nameplate/totemSettings/custom
plates), `Addon.db.global`, `Addon.db.char`. Defaults come from `Addon.GetDefaultSettingsV1()` (`Database.lua`)
plus `Addon.DEFAULT_SETTINGS` (`Constants.lua`). `Addon:ReloadTheme()` (`Addon.lua`) re-creates themes/custom
plates and pushes settings to all active nameplates after a profile change.

## Midnight (`feature/midnight`) — Secret Values

This branch targets the Midnight expansion (`Interface: 120005`), where many unit-token APIs can return
**secret values** — a distinct Lua type that errors on boolean/arithmetic/string/table-key use, yet is truthy
and not `nil`. This is the most critical section for any change touching unit-data paths on this branch.

### Core concept

Mainline/Midnight expose `issecretvalue(x)` and `canaccessvalue(x)`. Recommended file-level fallback
boilerplate in any file consuming unit APIs (so the same code also loads on pre-Midnight clients):

```lua
local issecretvalue = issecretvalue or function() return false end
local canaccessvalue = canaccessvalue or function() return true end
```

Do not rely on `value == nil` semantics with secret values — a secret value is truthy and not `nil`.

### When WoW API values become secret

WoW API docs use metadata flags that indicate when a value may become secret — use these as the primary
source of truth (via the `wow-api` MCP server or wow-ui-source, not guessing):

- `SecretWhen...` on functions/events: the return/event payload can become secret when the corresponding
  restriction is active. Examples: `SecretWhenUnitIdentityRestricted`, `SecretWhenUnitPowerRestricted`,
  `SecretWhenUnitSpellCastRestricted`, `SecretWhenUnitAuraRestricted`, `SecretWhenUnitComparisonRestricted`.
- `SecretReturns = true`: return values can be secret even if the function still returns a value.
- `ConditionalSecret = true` on fields: individual return fields may become secret depending on context.
- `SecretArguments = "AllowedWhenUntainted"` / `"AllowedWhenTainted"`: callability in tainted vs. untainted
  context is documented separately from whether the returned data is secret.

Practical rule of thumb: expect secret values especially for unit identity, aura, spellcast, comparison,
health/power/threat, and related unit-derived data in restricted contexts (`C_RestrictedActions`,
`AddOnRestrictionType`: Combat, Encounter, ChallengeMode, PvPMatch, Map are strong indicators). There is no
single universal pre-check that guarantees non-secret results for all APIs; always validate consumed values
with `issecretvalue` / `Addon.IsSecretValue` before boolean tests, math, string ops, or table indexing.

### Canonical patterns (mandatory for any new code touching unit APIs)

- Never call raw `UnitIsUnit` in a boolean context — use `Addon.UnitIsUnit` (`Compatibility.lua`), which returns
  `false` for secret results. Local upvalue convention: `local UnitIsUnitTP = Addon.UnitIsUnit`.
- Guard before any Lua-side operation (arithmetic, comparison, string format/match/concat, table key):
  `if issecretvalue(value) then ... end`.
- Never use `UnitName(...)` / `unit.name` as a table key — use `UnitGUID(unit)` / `unit.guid` instead, and
  still guard the GUID itself (`if not guid or issecretvalue(guid) then return end` before using it as a key).
- **Correction (was previously stated as unconditionally safe)**: a Lua truthiness check
  (`if secret_value then`) alone does **not** guarantee safety. Secret values are truthy (neither `nil` nor
  `false`), so `if secret_value then` never errors — but a *boolean* secret value (from `and`/`or`/`not`
  logic upstream, e.g. `unit.CastIsNotInterruptible`) can still throw `attempt to perform boolean test on
  field '...' (a secret boolean value, while execution tainted by '<addon>')` on a plain
  `if unit.SomeBooleanField then` / `elseif unit.SomeBooleanField then` check, confirmed live on a client
  with Midnight's API surface (`Elements/Castbar.lua`'s `GetCastbarColor`, `elseif
  unit.CastIsNotInterruptible then`). Whether a given secret value is safe to test this way appears to
  depend on execution being tainted, not just on the value's Lua type — treat any secret **boolean** field
  read in a branch condition as unsafe by default and guard it (`if issecretvalue(value) then ... end`)
  or route it through the Midnight-safe code path, the same as arithmetic/comparison values.
- **Safe C-API pass-through**: a (possibly secret) value may be passed directly into a WoW C-API sink that
  accepts it as a parameter (`FontString:SetText`, `C_ColorUtil.WrapTextInColor`, `C_ClassColor.GetClassColor`,
  `Texture:SetTexture`, `StatusBar:SetValue`, `SetMinMaxValues`) — no `IsSecretValueTP` guard needed for a pure
  pass-through path, e.g. `castbar.CastTarget:SetText(WrapTextInColor(UnitSpellTargetName(unitid), color))` is
  safe as long as no Lua string op touches the value first. Blizzard's `AbbreviateNumbers`,
  `AbbreviateLargeNumbers`, and `BreakUpLargeNumbers` are documented `SecretArguments = "AllowedWhenTainted"`
  and are safe display sinks for secret numeric values. There is no equivalent verified API metadata for Lua
  `string.format`; do not assume raw `format` on a secret value is safe without explicit documentation or
  runtime proof.
- Never do Lua arithmetic (`+ - * /`) or comparisons (`< > == ~=`) on secret values, and never index a table
  that may itself be secret.
- For status bars, pass raw values to C-side frame APIs (`SetMinMaxValues`, `SetValue`) and avoid Lua-side
  fraction math. If a value is secret in a restricted context, degrade gracefully (skip/hide/fallback) instead
  of forcing computation.
- `UNIT_SPELLCAST_INTERRUPTIBLE` / `UNIT_SPELLCAST_NOT_INTERRUPTIBLE` carry only `{ unitTarget }` on Midnight
  (no `castGUID`/`spellID`/`castBarID`); `Nameplate.lua`'s `UnitSpellcastInterruptible` guards on
  `castbar.CastbarID ~= nil` (set in `OnStartCasting`, cleared in `UNIT_SPELLCAST_STOP`) instead of the missing
  event parameter — **not** `castbar:IsShown()`, since a style change can hide the castbar while a cast is
  still active. (Historical bug this pattern fixed: the generic `UnitSpellcastMidway` always bailed at
  `castbar_id ~= castbar.CastbarID`, nil ≠ ID, so interruptibility updates — castbar color, shield, overlay —
  were never applied.)
- Treat `pcall` as a limited fallback only; it is not a full replacement for explicit secret-value checks (it
  catches a thrown Lua error, but not e.g. an `ADDON_ACTION_FORBIDDEN` taint error, which is tied to the
  calling context rather than the value itself, or silent wrong behavior from an unguarded comparison that
  happens not to throw).

Example guards by category:

```lua
-- Boolean/unit-token result
local result = UnitIsUnit(unit1, unit2)
if issecretvalue(result) then result = false end

-- GUID as table key
local guid = UnitGUID(unit)
if not guid or issecretvalue(guid) then return end
tbl[guid] = data

-- Numeric value (UnitHealth, UnitHealthMax, UnitPower, UnitStagger, ...)
local hp = UnitHealth(unit)
if issecretvalue(hp) then return end

-- Name/string
local name = UnitName(unit)
if not name or issecretvalue(name) then return end

-- Castbar interruptibility
local _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
if notInterruptible and not issecretvalue(notInterruptible) then
  -- safe usage
end
```

### Safe tooltip scanning

- Read unit tooltips via `C_TooltipInfo.GetUnit(unitid)` (addon wrapper: `Addon.C_TooltipInfo_GetUnit_*`).
- Validate every extracted field before use with `Addon.IsSecretValue(value)`; never use a secret value as a
  table key or pass it into a Lua string operation (`match`, `gsub`, `format`, concatenation).
- Prefer `UnitGUID(unitid)`-based cache keys over name-based keys.
- `Enum.TooltipDataLineType` has no dedicated unit-level line type (no `UnitLevel`); the closest are
  `ItemLevel`/`ItemUpgradeLevel` (`RestrictedLevel` was removed in 12.0.1). A unit-level line must be
  identified by tooltip context/text, not by a dedicated line-type enum value.

### "WoW Forever" — an official client with Midnight's API surface

"WoW Forever" is an official Blizzard client/product running parallel to Retail and WoW Classic, not a
third-party or spoofed client. It reports `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` while running
Classic-rules content on Blizzard's modern (Midnight-era) engine — full secret-value restrictions and API
parity with Midnight, confirmed via `/tptp debug MidnightAPI`. `Addon.IS_FOREVER` detects this; `Addon.HAS_MIDNIGHT_API`
(see "Expansion / version compatibility" above) is the flag to use for any branch that exists to pick the
secret-value-safe/modern API code path — keep `Addon.ExpansionIsAtLeastMidnight` itself for genuine
ruleset/feature decisions. Full findings, confirmed fixes, and the open-items list:
`Source/Wiki/wow-forever-compatibility.md`.

### SavedVariables can be `nil` at `ADDON_LOADED` — confirmed client bug, confirmed NOT addon-fixable

Confirmed independently by another addon author on Discord: on some clients (observed on "WoW Forever"), the
SavedVariables global table (`ThreatPlatesDB`) can still be `nil` when `ADDON_LOADED` fires — the event
`AceAddon-3.0` uses to trigger `OnInitialize`. The Discord report suggested it's "only reliably populated
later, by `PLAYER_LOGIN`" - **this addon's own live testing disproved that** for at least one affected
client: see below.

**No source-code fix is in this codebase for this** — two attempts were tried and reverted after live
testing showed neither worked; see `Source/Wiki/wow-forever-compatibility.md` fixes #21-#23 for the full
diagnostic trail (a stray `CreateAceDatabase()` call unconditionally re-run at `PLAYER_LOGIN`, then a
correctly-deferred-but-still-insufficient version that never touched the SV global before `PLAYER_LOGIN`).
Both are gone from `Addon.lua` now - do not re-add either pattern without new evidence, since both are
confirmed dead ends on the client where this was diagnosed:

- **Why re-running `CreateAceDatabase()` at `PLAYER_LOGIN` doesn't work**: `AceDB-3.0.lua`'s `AceDB:New()`
  does `tbl = _G[name]; if not tbl then tbl = {}; _G[name] = tbl end` - the moment it sees the global as
  `nil`, it creates a blank table and assigns it into that global itself, synchronously. Calling
  `CreateAceDatabase()` while `ThreatPlatesDB` is still `nil` means the global is never `nil` again for the
  rest of the session regardless of whether the client ever actually injects the real saved data afterwards,
  so a later nil-check-based "recovery" can't tell "real data arrived" apart from "still reading back our
  own blank placeholder".
- **Why deferring the entire AceDB setup to `PLAYER_LOGIN` (never touching the global before then) doesn't
  work either**: a purely observational polling watcher (object-identity-based, not content-based, so it
  couldn't be fooled by the addon's own setup code writing real-looking values - e.g. computed frame sizes -
  into a fresh blank profile) found that `ThreatPlatesDB` never receives real data at all on the affected
  client - not at `ADDON_LOADED`, not at `PLAYER_LOGIN`, not within 30 seconds afterward, and not even
  across a full logout/login (character-select cycle, not just `/reload`). The only table-identity change
  observed in every test was the addon's own blank `AceDB:New()`-created placeholder - never an external
  reassignment.

**Conclusion**: the SavedVariables *file* itself was confirmed correct and current on disk in every test -
saving works. Only loading is affected, and it fails unconditionally on the affected client, not just after
`/reload`. Since addons have no file-I/O API to read SavedVariables themselves, **there is no addon-side fix
possible** - the client itself must inject the data, and on the affected client it apparently never does.
Treat this as a client bug to report upstream (to whoever maintains that client/product), not something to
keep chasing with more addon-side event-timing fixes, unless new evidence (e.g. a different affected client,
or a confirmed later trigger point) emerges.

### Features intentionally disabled on `feature/midnight`

Do not re-enable without explicit request: off-tank detection, name abbreviation/transliteration
(`Modules/Localization.lua` feature flags), `Widgets/HealerTrackerWidget.lua`, NPC-ID parsing from GUID
structure.

### Known open issues / unverified findings

Point-in-time notes from past analysis passes — re-verify before relying on them, since the code moves:

- `Widgets/HealerTrackerWidget.lua`: `UnitGUID(unitid)` is checked with `if not guid then return end`, which
  does **not** catch a secret (truthy, non-nil) GUID before it's used as a `UnitIsHealer[guid]` table key —
  needs an `issecretvalue(guid)` guard too. (This widget is disabled on Midnight/`HAS_MIDNIGHT_API` clients
  entirely — see above — but the same file also runs pre-Midnight, where the GUID could still be a secret
  value in a restricted context depending on future API changes.)
- `AurasWidgetMidnight.lua`: a past pass flagged a permanent-duration-aura logic issue in a function named
  `FilterEnemyBuffsBySpell()` — that function no longer exists under that name (renamed/refactored since), so
  this finding needs to be re-derived against the current code before acting on it.
- `Nameplate.lua`: `UnitHealth`/`UnitHealthMax` results still get `or` fallbacks before later arithmetic in a
  few call sites — worth a guard-pattern audit pass.
- `Widgets/SocialWidget.lua`: name/fullname concatenation and table-key lookups may still consume secret
  values without a guard.
- `Elements/StatusText.lua`: `UnitSubtitles[tooltip_name] = subtitle` still needs a secret-value guard on the
  cache key; `UnitHealthPercent(...)` is passed directly into `:format("%.f%%")` — keep this path open until
  `string.format` safety on a secret value is proven (see the `string.format` caveat above).

## WoW API Reference

- WoW Wiki: https://warcraft.wiki.gg/
- UI source (current live build): https://github.com/Gethe/wow-ui-source (branch `live`)
- A local read-only mirror of that source is available as an additional working directory
  (`wow-ui-source-live`).

## Changelog Workflow

Two files must stay in sync for every user-facing change:

- `TidyPlates_ThreatPlates_Changes.log` — full project history; new version blocks/entries are prepended at the
  top:
  ```
  ------------------------------------------------------
  <version> (<date YYYY-MM-DD>)
  ------------------------------------------------------
  * Entry one.
  * Entry two [Comment #NNNN].
  ```
- `CHANGELOG.md` — mirrors **only** the entries of the current unreleased (top) version block in
  `TidyPlates_ThreatPlates_Changes.log`; consumed by the packager via `# @project-version@ (@build-time@)`.

Entry format: one `* `-bullet per logical change, starting with a capitalized past-tense verb (`Fixed`, `Added`,
`Changed`, `Removed`, `Updated`, `Rebuilt`; use `Hopefully fixed` when the fix is unverified), ending with a
period. Reference CurseForge comments as `[Comment #NNNN]` (comma-separated for multiple:
`[Comment #NNNN, #MMMM]`) and GitHub issues/PRs as `[GH-NNN]` or `[PR GH-NNN by author]` (combinable as
`[GH-NNN, Comment #MMMM]`), placed right before the final period — never invent reference numbers.

Wording, derived from the existing log:

- Lead with the user-visible symptom in plain, player-facing language (e.g. "a Lua error", "a bug where
  nameplates showed the wrong name", "missing text shadows"), never with the internal fix or code change.
- Optionally add root cause with a `, caused by ...` clause, phrased in terms of WoW/Blizzard behavior (a
  client-side API change, a secret-value restriction, a specific patch) — never in terms of TPTP's internal
  functions, files, or variables.
- Two recurring shapes: `Fixed a Lua error when <doing X>, caused by <Y>.` and `Fixed a bug where <symptom>,
  caused by <Y> [ref].`
- One bullet per independent change, even closely related ones (e.g. two separate library updates each get
  their own bullet).

Workflow:

- **If the last released tag matches the current top version block** (i.e. this is the first change since that
  release): create a **new** version block at the top of `TidyPlates_ThreatPlates_Changes.log` (incremented
  patch version, today's date), add the entry there, then replace the full content of the
  `# @project-version@ (@build-time@)` block in `CHANGELOG.md` with only that new block's entries.
- **Otherwise** (there are already unreleased entries in the top version block): append the new entry to the
  bottom of that top block in `TidyPlates_ThreatPlates_Changes.log`, then replace the full content of the
  `# @project-version@ (@build-time@)` block in `CHANGELOG.md` with **all** entries from that same version
  block — `CHANGELOG.md` always reflects exactly the entries of the single upcoming (unreleased) version block,
  never entries carried over from older, already-released blocks.
