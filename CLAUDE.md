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

## Multi-TOC Layout

- `TidyPlates_ThreatPlates.toc` — the packager-facing manifest with `#@version-x@` / `#@end-version-x@`
  conditional blocks (retail/classic/tbc/wrath/cata/mists). This is the canonical load-order list and what
  CurseForge/Wago packaging processes.
- `TidyPlates_ThreatPlates-{Mainline,Vanilla,TBC,Wrath,Cata,Mists}.toc` — single-`Interface:` TOCs for local
  testing against one specific client (e.g. `-Mainline.toc` = 120005, `-Mists.toc` = 50504). `.pkgmeta` excludes
  these from packaged releases.

## Architecture

### Load order (see `TidyPlates_ThreatPlates.toc`)

`Libs/` → `Locales/` → `ThreatPlates.xml` (shared templates) → `Init.lua` (expansion flags/globals) →
`Debug.lua` → `Compatibility.lua` (event/version shims) → `Modules/Localization.lua` → `EventService.lua` →
`CVarsManager.lua` → `Media.lua` → `Constants.lua` → `Modules/*.lua` → `Elements/*.lua` →
`Widgets/WidgetHandler.lua` → `Nameplate.lua` → `Database.lua` → `Addon.lua` → `Commands.lua` → `Options.lua` →
`Styles/*.lua` → `Widgets/*.lua`.

### Expansion / version compatibility (`Init.lua`, `Compatibility.lua`)

Flags computed once at load and used everywhere to branch behavior:

- `Addon.IS_MAINLINE`, `Addon.IS_CLASSIC`, `Addon.IS_MISTS_CLASSIC`, `Addon.IS_MIDNIGHT`, plus
  `IS_TBC_CLASSIC` / `IS_WRATH_CLASSIC` / `IS_CATA_CLASSIC` / `IS_CLASSIC_SOM` / `IS_CLASSIC_SOD`.
- `Addon.ExpansionIsAtLeastX` (X = TBC, Wrath, Cata, Mists, WoD, Legion, BfA, Shadowlands, DF, TWW, Midnight) —
  always `true` on Mainline, otherwise compares `GetClassicExpansionLevel()`.
- `Addon.WOW_USES_CLASSIC_NAMEPLATES` — true for Classic-style nameplates (Vanilla..WoD, excluding Mists
  Classic, which uses the modern nameplate API).
- `Compatibility.lua`'s `WOW_EVENTS` table + `Addon:RegisterEvent` / `RegisterUnitEvent` / `UnregisterEvent` gate
  WoW event registration per expansion — events that don't exist for the running client are silently skipped.

### Event system (`EventService.lua`)

Central pub/sub for both real WoW events and internal TP events (`INTERNAL_EVENTS`, e.g. `ThreatUpdate`,
`CastingStarted`/`CastingStopped`, `MouseoverOnEnter`/`MouseoverOnLeave`, `TargetGained`):

- `EventService.Subscribe(subscriber, event, func, register_for_current_expansion)` / `Unsubscribe` /
  `UnsubscribeAll(subscriber)`.
- `EventService.Publish(event, ...)` fans out to all subscribers.
- A single `EventHandlerFrame` dispatches all registered WoW events through `EventHandler`.
- Widgets/modules typically subscribe in `OnEnable` and must call `UnsubscribeAll` in `OnDisable` — note
  `UnsubscribeAll` also checks `INTERNAL_EVENTS`, since `Addon:ExpansionSupportsEvent` returns `false` for
  internal (non-WoW) events.

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
- WoW script handlers (`OnShow`/`OnHide`/`OnEvent`) can fire **synchronously** inside another handler when a
  C-side API like `Frame:Show()` is called — don't assume strictly sequential handler ordering when reasoning
  about re-entrancy (e.g. target-change vs. nameplate-creation races).

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
and not `nil`.

Canonical patterns (mandatory for any new code touching unit APIs):

- Never call raw `UnitIsUnit` in a boolean context — use `Addon.UnitIsUnit` (`Compatibility.lua`), which returns
  `false` for secret results. Local upvalue convention: `local UnitIsUnitTP = Addon.UnitIsUnit`.
- Guard before any Lua-side operation (arithmetic, comparison, string format/match/concat, table key):
  `if issecretvalue(value) then ... end` (fallback boilerplate:
  `local issecretvalue = issecretvalue or function() return false end`).
- Never use `UnitName(...)` / `unit.name` as a table key — use `UnitGUID(unit)` / `unit.guid` instead.
- Passing a (possibly secret) value straight into a WoW C-API sink (`FontString:SetText`, `WrapTextInColor`,
  `GetClassColor`, `StatusBar:SetValue`, `SetMinMaxValues`) is safe — only Lua-side manipulation needs guarding.
- `UNIT_SPELLCAST_INTERRUPTIBLE` / `UNIT_SPELLCAST_NOT_INTERRUPTIBLE` carry only `{ unitTarget }` on Midnight (no
  `castGUID`); `Nameplate.lua`'s `UnitSpellcastInterruptible` guards on `castbar.CastbarID ~= nil` instead of the
  missing event parameter.
- Use `SetAlpha(0/1)` rather than `Show()`/`Hide()` for visibility transitions on Midnight.

Features intentionally disabled on `feature/midnight` (do not re-enable without explicit request): off-tank
detection, name abbreviation/transliteration (`Modules/Localization.lua` feature flags),
`Widgets/HealerTrackerWidget.lua`, NPC-ID parsing from GUID structure.

The full guard-pattern catalogue and the running secret-value audit live in `.github/copilot-instructions.md` —
consult it before touching any unit-data path on this branch.

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

Entry format: one `* `-bullet per logical change, capitalized, no trailing period. Reference CurseForge comments
as `[Comment #NNNN]` and GitHub issues/PRs as `[GH-NNN]` or `[PR GH-NNN by author]` (combinable as
`[GH-NNN, Comment #MMMM]`) — never invent reference numbers.

If the last released tag matches the current top version block, start a **new** version block (incremented
patch version, today's date) before adding the entry; otherwise append to the existing top (unreleased) block.
