---
type: subsystem
title: Styles and custom styles
description: How Threat Plates builds its themes, picks a style for every unit (visibility, headline view, custom style triggers, threat styles), applies a style to a nameplate in a fixed order, and runs scripted custom styles through the Script widget.
tags: [styles, themes, custom-styles, triggers, headline-view, scripting]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-25T18:59:51.751Z
sources:
  - id: openwiki-source-cfe0b084e5798ad70d26514c
    resource: repo://Commands.lua
  - id: openwiki-source-c1d47e467fe7b701bf0b87e3
    resource: repo://Database.lua
  - id: openwiki-source-8010ad23cdbb1990bedd5d0e
    resource: repo://EventService.lua
  - id: openwiki-source-c9c2cf708e7c112ce26d2e49
    resource: repo://Options.lua
  - id: openwiki-source-34441aa52cf534e5ac2e8a8a
    resource: repo://Styles/basicThemes.lua
  - id: openwiki-source-8f30e52eb10735a101a75e11
    resource: repo://Styles/emptyThemes.lua
  - id: openwiki-source-cf9327f03199cf771747ccc9
    resource: repo://Styles/init.lua
  - id: openwiki-source-8cacd0abe81a9744eecbd6ca
    resource: repo://Styles/Style_NameOnly.lua
  - id: openwiki-source-8c1a2f1346df95ad59b63c21
    resource: repo://Styles/Styles.lua
  - id: openwiki-source-e7384fc6a84ab77ee3ed1921
    resource: repo://Widgets/ScriptWidget.lua
  - id: openwiki-source-6794fbfa2ece0a99802c941d
    resource: repo://Widgets/WidgetHandler.lua
generated: { by: "claude-code", at: "2026-10-25T18:59:51.751Z" }
---

# Styles and custom styles

A **style** decides what a nameplate looks like: healthbar view, headline (name-only) view, a custom style, or
nothing. `Styles/` holds the theme definitions and `Styles/Styles.lua` (`Addon.Style`, used as `StyleModule`)
chooses and applies them.

## Themes

`Styles/init.lua` keeps a registry: `Addon:RegisterTheme(name, create)` stores a constructor (an error is logged
for duplicate names), `Addon:SetThemes()` calls every constructor and stores the result in `Addon.Theme[name]`.
`SetThemes` runs in `Addon:ReloadTheme()` and when LibSharedMedia registers new media, so themes are snapshots of
the current settings (textures resolved through LibSharedMedia, sizes, positions, `show` flags per part).

| Style name | Defined in | Mode (`tp_frame.PlateStyle`) | Used for |
| --- | --- | --- | --- |
| `normal`, `dps`, `tank` | `basicThemes.lua` | `HealthbarMode` | healthbar view; `dps`/`tank` when threat feedback applies |
| `totem` | `basicThemes.lua` | `HealthbarMode` | player totems with nameplate |
| `unique` | `basicThemes.lua` | `HealthbarMode` | custom style with healthbar |
| `NameOnly`, `NameOnly-Unique` | `Style_NameOnly.lua` | `NameMode` | headline view, custom style in headline view |
| `empty` | `emptyThemes.lua` | `None` | hidden nameplate |
| `etotem` | `emptyThemes.lua` | `None` | icon-only (custom style/totem icon, widgets without healthbar and name) |

All themes have the same parts (`healthbar` with per-reaction `width`/`height`, `healthborder`, `eliteborder`,
`threatborder`, `highlight`, `castbar`, `castborder`, `castnostop`, `level`, `spelltext`, `skullicon`, `eliteicon`,
`spellicon`, `raidicon`, ...), so Elements can read `style.<part>` without checks. Empty themes set `show = false`.

## Choosing a style: `SetStyle(unit)`

1. **Visibility and view** (`ShowUnit` -> `GetUnitType`): the unit type is built from reaction and class
   (`FriendlyPlayer`, `EnemyNPC`, `NeutralNPC`, totem, pet, guardian, minus, ...), stored as
   `unit.TP_DetailedUnitType` (`Boss`, `Elite`, `Tapped` refine it), and looked up with `Addon.GetUnitVisibility`
   (show flag, which may name a CVar, and "use headline view"). A (soft) target is always shown. Hiding rules
   (elite, boss, tapped, guardians, normal units, battle pets, friendly units in combat) and headline view
   rules (force healthbar on target, force headline out of combat / for non-attackable units / for friendly units
   in combat) are applied here.
2. Not shown -> `empty`.
3. **Custom style triggers**, in priority order: cast trigger (`unit.CustomStyleCast`), aura trigger
   (`unit.CustomStyleAura`), then name triggers and totems (`ProcessNameTriggers`), else `NameOnly` for headline
   view.
4. **Instance restrictions** of the custom style (all instances, specific instance IDs via
   `Addon.Cache.Styles.ForCurrentInstance`, or outside instances) can drop it again.
5. Hidden unit types stay `empty` unless a custom style with nameplate is active; dead units are `empty` (not
   hidden, so Feign Death still works [GH-583]); a unit that no longer exists becomes `etotem`.
6. Otherwise `GetThreatStyle(unit)`: `dps`/`tank` (the player's role) when `ThreatModule.ShowFeedback` is true,
   else `normal`.

A custom style maps to `unique` (show nameplate), `NameOnly-Unique` (headline view) or `etotem` (icon only).
Unit type mappings exist for odd cases, e.g. neutral totems/pets of mind-controlled players are treated as
friendly. Totem and pet detection use the creature type id and secret-safe checks on `HAS_MIDNIGHT_API` clients.

### Custom style triggers

`Addon:InitializeCustomNameplates()` (`Options.lua`) builds the trigger caches from
`Addon.db.profile.uniqueSettings` on every theme reload and options change:

- `Addon.Cache.CustomPlateTriggers.Name[name]`, `.Aura[id_or_name]`, `.Cast[id_or_name]` - direct lookups;
- `.NameWildcard` - list of `{ pattern, custom_style }` for names with `*`, results cached per unit name in
  `Addon.Cache.TriggerWildcardTests`;
- `.Script` - custom styles of type Script or with attached script code;
- flags `Addon.ActiveAuraTriggers`, `ActiveCastTriggers`, `ActiveWildcardTriggers`, `ActiveScriptTrigger`;
- per-instance caches (`Addon.Cache.Styles.ForAllInstances`, `PerInstance`), resolved for the current instance by
  `Addon.UpdateStylesForCurrentInstance()` on `PLAYER_ENTERING_WORLD`.

The caches are cleared with `wipe` because other files hold references to these tables.

Name triggers match `unit.name`, `unit.NPCID` or `unit.basename`. Aura triggers are evaluated by the Auras widget
(`StyleModule.AuraTriggerCheckIfActive` per aura, `AuraTriggerUpdateStyle` afterwards), cast triggers in
`OnStartCasting` (`CastTriggerCheckIfActive`, `CastTriggerUpdateStyle`) and reset in `UNIT_SPELLCAST_STOP`
(`CastTriggerReset`). On `HAS_MIDNIGHT_API` clients name and cast triggers are skipped, because names and spell ids
may be secret and cannot be table keys.

## Applying a style

```lua
StyleModule.PlateUnitAdded(tp_frame)  -- on NAME_PLATE_UNIT_ADDED: SetStyle + SetNameplateStyle
StyleModule.Update(tp_frame)          -- on data changes: only restyle if the name or custom style changed
StyleModule.UpdateName(tp_frame)      -- on UNIT_NAME_UPDATE: re-run name triggers
```

`SetNameplateStyle` stores `tp_frame.stylename`, `tp_frame.style` (the theme table), `tp_frame.PlateStyle` and
`unit.style`, then `UpdateNameplateStyle` applies it in a fixed order:

1. `tp_frame:SetSize(...)` from the healthbar size for the unit's reaction,
2. `ColorModule.UpdateStyle`, `TransparencyModule.UpdateStyle`, `ScalingModule.UpdateStyle`,
3. `ElementsUpdateStyle(tp_frame, style)` - all Elements,
4. `Widgets:OnUnitAdded(tp_frame, unit)` - all enabled Widgets re-check `EnabledForStyle` and update,
5. `Addon.RefreshCastbar(tp_frame, unitid)`.

`Update` compares the new style name with `tp_frame.stylename`; `unique`/`NameOnly-Unique` are re-applied if the
custom style itself changed. Because `NAME_PLATE_UNIT_REMOVED` resets `stylename` to `nil`, a recycled plate is
always restyled. Callers of `Update`: health events, target changes, threat changes, reaction changes, casts with
cast triggers, aura triggers, arena opponent updates.

`GetThreatStyle` is dot-defined. Two callers in `Transparency.lua` and `Scaling.lua` call it with a colon, which is
a bug (see [Modules](modules.md)).

## Scripted custom styles (`Widgets/ScriptWidget.lua`)

Scripting must be enabled globally (`Addon.db.global.ScriptingIsEnabled`, toggled by a `/tptp` command). The Script
widget is initialized before all other widgets (`InitializeAllWidgets`), so other widgets can rely on it.

- Scripts are Lua function bodies stored per custom style and event (`Scripts.Code.Functions`) or per WoW event
  (`Scripts.Code.Events`). `Addon.LoadScript` compiles them with `loadstring("return " .. code)` into a sandbox
  environment (`setfenv`), caching by code text.
- The environment exposes `ThreatPlates.Environment` (`Style`, `Profile`), an API table
  (`SetTextureForIcon`, crowd-control aura data, logging, `CreateStatusBar`), `PlatesByUnit`/`PlatesByGUID`, and
  `_G` through a proxy. Security-relevant functions and tables (mail, trade, guild management, `SlashCmdList`,
  ...) are replaced by proxies that only log a warning. The docs warn that the sandbox is not fully secure.
- Supported functions per script type (`Addon.SCRIPT_FUNCTIONS`): `IsEnabled`, `OnEnable`, `OnDisable`,
  `EnabledForStyle`, `Create`, `UpdateFrame`, `UpdateSettings`, `UpdateLayout`, `OnUnitAdded`/`OnUnitRemoved`
  (standard), `OnTargetUnitAdded/Removed` (target-only), `OnFocusUnitAdded/Removed` (focus-only), `OnUpdate`
  and WoW events.
- Script-triggered styles run on all plates (`ScriptsForAllPlates`); scripts attached to a trigger-based style
  run only on plates whose `unit.CustomPlateSettings` is that style (`ScriptsByCustomStyle`). Every call goes
  through `pcall` and logs errors with the style name.
- User documentation: `Source/Wiki/ScriptingCustomStyles.md` (marked as unstable API).

### Observations from reading the code (unverified)

- WoW event scripts are subscribed with `self:SubscribeEvent(event, HandleWoWEvent)`. A function subscriber is
  called as `func(...)` without the event name (see [Event system](../architecture/event-system.md)), but
  `HandleWoWEvent(event, ...)` expects the event name first and looks up `ScriptsForWoWEvents[event]`. The lookup
  therefore uses the event's first payload value, and WoW event scripts would never run.
- `Widget:OnUnitRemoved` passes the undefined global `tp_frame` (always `nil`) to `OnTargetUnitRemoved` scripts.
- In `Widget:UpdateSettings`, the error message for a failing `UpdateSettings` script of a trigger-based style
  uses the undefined `return_value` instead of `error_message`, and `IsEnabled` returning false does not
  disable such scripts (unlike script-triggered ones).

Related: [Nameplate lifecycle](../nameplates/lifecycle.md), [Elements](elements.md),
[Widget framework](../widgets/framework.md).
