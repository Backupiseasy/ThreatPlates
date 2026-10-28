---
type: subsystem
title: Options UI and propagating setting changes
description: How the Threat Plates options dialog (Options.lua, AceConfig) is built and opened, how a changed setting is written and pushed to live nameplates (SetValue, UpdateSpecial, ReloadTheme, ForceUpdate, UpdatePlatesVisible), why modules cache settings, and how changes are deferred in combat.
tags: [options, aceconfig, settings, update-propagation, combat-lockdown]
sources:
  - id: openwiki-source-014010f28568c5a3c3664449
    resource: repo://Addon.lua
  - id: openwiki-source-a005aa6baf1b38dbdae356fb
    resource: repo://Bindings.xml
  - id: openwiki-source-cfe0b084e5798ad70d26514c
    resource: repo://Commands.lua
  - id: openwiki-source-7a3e837cfb6d3795c0c95431
    resource: repo://Nameplate.lua
  - id: openwiki-source-c9c2cf708e7c112ce26d2e49
    resource: repo://Options.lua
  - id: openwiki-source-6794fbfa2ece0a99802c941d
    resource: repo://Widgets/WidgetHandler.lua
generated: { by: "claude-code", at: "2026-10-28T19:52:11.033Z" }
verified:
  - by: openwiki/0.7.2
    at: 2026-10-28T19:52:11.033Z
---

# Options UI and propagating setting changes

`Options.lua` (about 11,800 lines) builds the options dialog with AceConfig-3.0/AceConfigDialog-3.0. Players open
it with `/tptp` (no argument), the addon compartment button or Blizzard's settings panel (a small stub registered
in `OnInitialize` with an "Open Options" button).

## Building and opening the dialog

- The full options table is created lazily: `Addon:OpenOptions()` -> `RegisterOptionsTable()` ->
  `CreateOptionsTable()` on first use, then registered as `Addon.ADDON_NAME` ("Threat Plates") with a default size
  of 1000 x 640.
- Top-level tabs come from builder functions (`CreateVisibilityTab`, `CreateAppearanceTab`,
  `CreateHealthbarOptions`, `CreateCastbarOptions`, `CreateNameOptions`, `CreateWidgetOptions`,
  `CreateAurasWidgetOptions`, `CreateTotemOptions`, custom styles, ...) and reusable entry helpers
  (`GetRangeEntry`, `GetFontEntry`, `GetPlacementEntry`, `GetTransparencyEntry`, ...).
- The profiles tab is AceDBOptions' table, enhanced with LibDualSpec where available, plus import/export
  buttons (see [Database, profiles and migrations](database-and-profiles.md)).
- Options for features a client does not have are hidden with flags (`WOW_FEATURE_FOCUS`, `HAS_MIDNIGHT_API`,
  CVar availability, ...).
- Custom style slots are generated (`CreateCustomNameplatesGroup`) and regenerated after profile changes and
  `ConfigTableChanged`.

## Writing a setting

The root table sets `get = GetValue` and `set = SetValue`. An option's `arg` is the key path into
`Addon.db.profile`, e.g. `arg = { "HeadlineView", "ForceNonAttackableUnits" }`. `GetValue`/`SetValueGeneral`
walk that path; color options use `SetValueColor`.

`SetValue(info, ...)` then decides how to propagate the change:

1. If `info.arg[1]` is a widget's settings key in `WIDGET_INFO` (e.g. `AuraWidget` -> widget `Auras`,
   `questWidget` -> `Quest`):
   - if the change toggled whether the widget is enabled, `Addon.Widgets:InitializeWidget(name)` enables or
     disables it;
   - else, for widgets with `UpdateSettings = true`, `Addon.Widgets:UpdateSettings(name)`;
   - else `Addon:ForceUpdate()`.
   Flags per widget add `Addon:ForceUpdate()` (`ForceUpdate`), `Addon:UpdateSettings()` (`UpdateAllSettings`)
   or `Addon:PublishToEachPlate(event)` (`PublishEvent`, e.g. `SituationalColorUpdate` for Quest/Target/Focus,
   `ClassColorUpdate` for Social).
2. Otherwise: theme settings (`settings.*`, some headline view settings) first rebuild the themes with
   `Addon:SetThemes()`, then `Addon:ForceUpdate()`.

Some options use their own setters: CVar options (see [Game CVars management](cvars.md)), custom style options,
which call `UpdateSpecial` (`Addon.UpdateCustomStyles`), and a few that call `Addon:ReloadTheme()` directly.

A widget's enable state is evaluated through `widget:IsEnabled()`. Every setting that influences `IsEnabled` must
go through this setter path; otherwise only `UpdateSettings` runs and, e.g., events are not registered (see the
comment block in `Widgets/WidgetHandler.lua`).

## Update functions, from cheap to expensive

| Function | Does |
| --- | --- |
| `Addon:ForceUpdateOnNameplate(tp_frame)` | re-apply presentation of one plate (`RefreshPlatePresentation`) |
| `Addon:UpdatePlatesVisible()` | re-derive the name and re-apply presentation for every plate in `PlatesByUnit` |
| `Addon:UpdateSettings()` | re-read cached settings of all Modules and Elements, soft-target functions, castbar flags, interrupt-source event, click area (after combat) |
| `Addon:ForceUpdate()` | `UpdateSettings()` + `UpdatePlatesVisible()` |
| `UpdateSpecial()` (`Addon.UpdateCustomStyles`) | rebuild custom style triggers, `InitializeAllWidgets()`, `ForceUpdate()` |
| `Addon:ReloadTheme()` | `SetThemes`, custom styles, icon textures, `UpdateSettings`, `InitializeAllWidgets`, UI scale, click area, all plates, frame properties of all created plates |
| `Addon:ProfChange()` | `ReloadTheme()` (twice, around the option table refresh) + option previews |

None of them re-read unit data from the WoW API; that only happens on unit events and revalidation (see
[Nameplate lifecycle](../nameplates/lifecycle.md)).

### Why settings are cached

Modules, Elements and Widgets copy settings into file-local variables in `UpdateSettings()` instead of reading
`Addon.db.profile` on every event, for performance. Consequences:

- A new setting must be read in the relevant `UpdateSettings()` and the option must trigger it, or the change only
  applies after `/reload`.
- `UpdateSettings` can run often and for unrelated changes: `UpdateSpecial` and `ReloadTheme` call
  `InitializeAllWidgets()`, which runs `UpdateSettings` of **every** enabled widget, sometimes two or three times
  per change. It must be cheap or skip unchanged work (see the auras settings signatures in
  [Auras widgets](../widgets/auras.md)).

## Changes in combat

Protected actions (CVar writes, nameplate size) cannot run in combat:

- `Addon.ExecuteAfterCombatEnds(func, msg)` queues `func` (with a warning when `msg` is given) and runs it in
  `PLAYER_REGEN_ENABLED`, or immediately out of combat.
- `Addon.ExecuteOnlyOoC(func)` refuses with an error in combat.

## Chat commands (`Commands.lua`)

- `/tptp` - options; `/tptp help`, `/tptp profile <name>`, `/tptp legacy-custom-styles`, `/tptp toggle-scripting`,
  `/tptp clickable-area` (shows the click area of all plates).
- `/tptptank`, `/tptpdps`, `/tptptoggle` - manual role switch (only without automatic role detection);
  `/tptpverbose` - toggle feedback messages.
- In development builds (`Addon.DEBUG`, i.e. version `@project-version@`) further debug commands are available
  (see [Development workflow](../workflows/development.md)).

Keybindings (`Bindings.xml`) call `TidyPlatesThreat:ToggleNameplateMode*`, which flip `UseHeadlineView` per unit
type group and call `Addon:ForceUpdate()`.

## Opening the options from outside

`TidyPlatesThreat:OpenOptionsDialog(group)` registers the options table, opens the dialog for
`Addon.ADDON_NAME` and selects the BossMods widget group for `group == "BossMods"`. No caller exists in the addon
itself; the entry point used internally is `Addon:OpenOptions()`. (Until 13.3.4 it referenced an undefined `t`
and would have raised an error.)
