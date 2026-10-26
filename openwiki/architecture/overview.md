---
type: architecture
title: Architecture overview
description: How Threat Plates is loaded and initialized - TOC load order, the shared Addon namespace table, AceAddon OnInitialize, and how the core, Modules, Elements, Widgets and Styles divide the work of drawing a nameplate.
tags: [architecture, load-order, initialization, aceaddon, modules, elements, widgets, styles]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-25T18:59:51.751Z
sources:
  - id: openwiki-source-014010f28568c5a3c3664449
    resource: repo://Addon.lua
  - id: openwiki-source-2e898f0a8b59a083a80489b8
    resource: repo://Elements/Elements.xml
  - id: openwiki-source-4cfab5238eb54f18483ded92
    resource: repo://Init.lua
  - id: openwiki-source-0db67719773fe4ec9f9b9d56
    resource: repo://Modules/Modules.xml
  - id: openwiki-source-7a3e837cfb6d3795c0c95431
    resource: repo://Nameplate.lua
  - id: openwiki-source-cf9327f03199cf771747ccc9
    resource: repo://Styles/init.lua
  - id: openwiki-source-8c1a2f1346df95ad59b63c21
    resource: repo://Styles/Styles.lua
  - id: openwiki-source-3109d6b4b39ada7d983ff1d5
    resource: repo://TidyPlates_ThreatPlates.toc
generated: { by: "claude-code", at: "2026-10-25T18:59:51.751Z" }
---

# Architecture overview

Threat Plates is a World of Warcraft addon in Lua/XML. There is no build step: the client loads the files
listed in `TidyPlates_ThreatPlates.toc` directly from the addon folder.

## Load order

The TOC is also the canonical load order. Files run top to bottom, each receiving the addon's private namespace
table as the second vararg (`local ADDON_NAME, Addon = ...`):

1. `Libs\Libs.xml`, `Locales\Locales.xml` - embedded libraries (Ace3, LibSharedMedia, LibCustomGlow, LibDeflate,
   LibDualSpec, ...) and the generated localization tables.
2. `ThreatPlates.xml` - shared XML templates.
3. `Init.lua` - client/expansion flags, the AceAddon object `TidyPlatesThreat`, empty module tables, caches,
   logging and table helpers.
4. `Debug.lua`, `Compatibility.lua` (event table and API shims), `Modules\Localization.lua`.
5. `EventService.lua`, `CVarsManager.lua`, `Media.lua`, `Constants.lua`.
6. `Modules\Modules.xml` (Font, Icon, Animation, Threat, Color, Transparency, Scaling),
   `Elements\Elements.xml` (Statusbar, ElementHandler, then the elements in priority order),
   `Widgets\WidgetHandler.lua`.
7. `Nameplate.lua` (the core), `Database.lua`, `Addon.lua`, `Commands.lua`, `AceGUIPreviewImage.lua`,
   `Options.lua`.
8. `Styles\Styles.xml` (theme registry, themes, `Styles.lua`), `Widgets\Widgets.xml` (all widgets).

Because a file can only see what earlier files defined, `Init.lua` pre-creates the shared module tables
(`Addon.Threat`, `Addon.Style`, `Addon.Color`, `Addon.Transparency`, `Addon.Scaling`, `Addon.Font`, `Addon.Icon`,
`Addon.Animation`, `Addon.Localization`). Earlier files capture the table reference, later files fill in the
functions. That is why `Nameplate.lua` can import `Addon.Style` although `Styles\Styles.lua` loads after it;
it must look the functions up at call time (`StyleModule.Update(tp_frame)`), not cache them as upvalues at load
time.

## The `Addon` namespace

`Addon` is the private table shared by all files. Besides the module tables it holds:

- client flags and helpers (see [Client and expansion compatibility](client-compatibility.md)),
- the nameplate registries `Addon.PlatesCreated`, `Addon.PlatesByUnit`, `Addon.PlatesByGUID`,
- `Addon.Theme` (styles by name), `Addon.Cache` (text cache, custom style trigger caches),
- `Addon.db` (the AceDB database, see [Database, profiles and migrations](../settings/database-and-profiles.md)),
- event handlers as methods, e.g. `function Addon:NAME_PLATE_UNIT_ADDED(unitid)`.

Only a few real globals exist: `TidyPlatesThreat` (the AceAddon object), `TidyPlatesThreatDBM` (a flag for DBM),
the SavedVariables `ThreatPlatesDB`, key binding and addon compartment functions. The luacheck configs whitelist
them.

## Initialization

`TidyPlatesThreat:OnInitialize()` in `Addon.lua` runs when AceAddon sees `ADDON_LOADED`:

1. Create the AceDB database `ThreatPlatesDB` with `Addon.DEFAULT_SETTINGS`; register it with LibDualSpec where
   dual specialization exists.
2. Fetch libraries (AceConfigDialog, LibSharedMedia, LibCustomGlow, optional Masque and LibDogTag).
3. Register profile callbacks (`ProfChange`), the shutdown flag and LibSharedMedia callbacks.
4. Register the options table and the `/tptp` chat command.
5. `CVars:Initialize()`, `CheckForFirstStartUp()` (spec roles, database migration on version change),
   `CheckForIncompatibleAddons()`.
6. `Addon:EnableEvents()` - register all core WoW events (see [Event system](event-system.md)).
7. `CVars.RegisterCVarHook()`.
8. `Addon:ReloadTheme()` - build themes and custom styles, read settings, initialize widgets, scale and click
   area, then update all plates.

`OnEnable`/`OnDisable` are not used. `Addon:PLAYER_LOGIN` hooks `NamePlateDriverFrame.AcquireUnitFrame` and
initializes the player role; `Addon:PLAYER_ENTERING_WORLD` applies instance-dependent CVars and custom styles.

`Addon:ReloadTheme()` is also the handler for profile changes and runs the same steps again; see
[Options UI and propagating setting changes](../settings/options-and-updates.md).

## Layers that draw a nameplate

For every Blizzard nameplate frame (`plate`) the core creates one Threat Plates frame, `plate.TPFrame`
(`tp_frame`), with the tables `tp_frame.unit` (unit data), `tp_frame.visual` (elements), `tp_frame.style`
and `tp_frame.widgets`. Four kinds of code work on it:

| Layer | Files | What it is | Calling convention |
| --- | --- | --- | --- |
| Core | `Nameplate.lua` | nameplate lifecycle, unit data, WoW events | `Addon:EVENT(...)` methods, local functions |
| Styles | `Styles/` | pick a style per unit and drive all others | `StyleModule.Update(tp_frame)` (dot) |
| Modules | `Modules/` | stateless services: threat, color, transparency, scaling, font, icon, animation, localization | dot functions, no `self` |
| Elements | `Elements/` | always-present parts of a plate: healthbar, name, castbar, status text, ... | dot functions, registered with `Addon.Elements.NewElement` |
| Widgets | `Widgets/` | optional, separately enabled features: auras, quest, combo points, ... | colon methods, `self` is the widget |

Event flow: the core receives a WoW event as main subscriber, updates `tp_frame.unit`, and usually calls
`StyleModule.Update(tp_frame)`. Modules, Elements and Widgets then get the same WoW event as ordinary
subscribers, or one of the internal events the core publishes.

When a unit is added or its style changes, `Styles.lua` applies the style in a fixed order: Color,
Transparency and Scaling modules, then all elements (`ElementHandler.UpdateStyle`), then all enabled widgets
(`WidgetHandler:OnUnitAdded`), then the castbar. Details in [Styles and custom styles](../rendering/styles.md).

The `Nameplate.lua` header describes the intent of the split: Modules must be called in a certain order and are
called directly; Elements are independent of each other and always created; Widgets are like Elements but are
only created when enabled, so disabled widgets cost nothing.

Mixing up dot and colon calls is a common bug: `Font:UpdateText(...)` on a dot-defined module function passes
the module table as an extra first argument. Import module functions as local upvalues instead
(`local FontUpdateText = Addon.Font.UpdateText`).

## Where to go next

- [Nameplate lifecycle](../nameplates/lifecycle.md) - what happens from `NAME_PLATE_CREATED` to
  `NAME_PLATE_UNIT_REMOVED`.
- [Elements](../rendering/elements.md), [Modules](../rendering/modules.md),
  [Widget framework](../widgets/framework.md) - the individual layers.
- [Secret values](secret-values.md) - mandatory reading before touching unit API code.
