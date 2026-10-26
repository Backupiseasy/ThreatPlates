---
type: subsystem
title: Widget framework
description: How Widgets/WidgetHandler.lua registers, enables, disables and drives widgets - widget kinds (per plate, target-only, focus-only), required and optional callbacks, per-plate widget frames, settings updates and their cost, and event subscription rules.
tags: [widgets, widgethandler, lifecycle, events, settings]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-25T18:59:51.751Z
sources:
  - id: openwiki-source-cfe0b084e5798ad70d26514c
    resource: repo://Commands.lua
  - id: openwiki-source-6794fbfa2ece0a99802c941d
    resource: repo://Widgets/WidgetHandler.lua
generated: { by: "claude-code", at: "2026-10-25T18:59:51.751Z" }
---

# Widget framework

Widgets are optional nameplate features (auras, quest icons, combo points, ...). Unlike
[Elements](../rendering/elements.md) they can be switched off completely: a disabled widget creates no frames
and receives no events. `Widgets/WidgetHandler.lua` (`Addon.Widgets`) manages them; it is loaded from the TOC
before `Nameplate.lua`, the widgets themselves load at the end through `Widgets.xml`.

## Registering a widget

```lua
local Widget = Addon.Widgets:NewWidget("ClassIcon")        -- one frame per nameplate
local Widget = Addon.Widgets:NewTargetWidget("ComboPoints") -- one frame, moved to the (soft) target
local Widget = Addon.Widgets:NewFocusWidget("Focus")        -- one frame, moved to the focus
```

`NewWidget` returns a table with `Name`, a back reference `WidgetHandler`, event wrappers (`SubscribeEvent`,
`SubscribeUnitEvent`, `PublishEvent`, `UnsubscribeEvent`, `UnsubscribeAllEvents`), helpers (`UpdateAllFrames`,
`UpdateAllFramesWithPublish`, `GetWidgetFrameForUnit`) and defaults: `OnEnable` does nothing, `OnDisable` calls
`UnsubscribeAllEvents()`. Widget functions are colon methods (`function Widget:OnUnitAdded(widget_frame, unit)`).

## Callbacks

| Callback | Required | Called |
| --- | --- | --- |
| `IsEnabled()` | yes | by `InitializeWidget` and the options setter; reads the widget's enable settings (often also caches `self.db`) |
| `Create(tp_frame)` | yes | per plate (or once for target/focus widgets) when the widget is enabled or a plate is created |
| `EnabledForStyle(style, unit)` | yes | whenever a style is applied; decides `widget_frame.Active` |
| `OnUnitAdded(widget_frame, unit)` | yes (per-plate) | when the plate gets a unit or a style is applied and the widget is active for it |
| `OnTargetUnitAdded/Removed(tp_frame, unit)` | target-only | when a (soft) target plate is styled / removed |
| `OnFocusUnitAdded/Removed` | focus-only | same for the focus |
| `OnEnable()` / `OnDisable()` | no | after enabling (subscribe events here) / when disabling |
| `UpdateSettings()` | no | before enabling and on settings changes |
| `UpdateLayout(widget_frame)` | no | for every created plate after `UpdateSettings` |
| `UpdateFrame(widget_frame, unit)` | no | from `UpdateAllFrames` |
| `OnUnitRemoved(widget_frame, unit)` | no | on `NAME_PLATE_UNIT_REMOVED` |

Simple examples: `ClassIconWidget.lua` (no `OnDisable`, Masque group in `OnEnable`), `TotemIconWidget.lua`
(one event, `UNIT_NAME_UPDATE`).

## Lifecycle

`WidgetHandler:InitializeAllWidgets()` (from `Addon:ReloadTheme()`, `UpdateSpecial`, LibSharedMedia updates)
initializes the Script widget first, then all others. `InitializeWidget(name)`:

- `IsEnabled()` true -> `UpdateSettings(name)` (widget `UpdateSettings`, then `UpdateLayoutOfAllPlates` for
  per-plate widgets) -> `EnableWidget(name)`;
- otherwise `DisableWidget(name)`, which does nothing if the widget was not enabled.

**`EnableWidget`**: per-plate widgets are added to `EnabledWidgets`; for every plate in `Addon.PlatesCreated`
(not only visible ones - plates are reused) a frame is created if missing (`tp_frame.widgets[name] =
widget:Create(tp_frame)`); for active plates `widget_frame.unit`, `widget_frame.Active` (`stylename ~= "empty"
and EnabledForStyle(...)`) and `OnUnitAdded` are set/called. Target/focus widgets just call `Create()` once.
`OnEnable()` runs **last**, so no event can arrive before the frames exist.

**`DisableWidget`**: calls `OnDisable()`, then hides all widget frames (per-plate) or calls
`OnTargetUnitRemoved`/`OnFocusUnitRemoved`. Target-only widgets must hide their frame in `OnDisable`.

**Per plate** (from the core):

- `OnPlateCreated(tp_frame)` creates frames for all enabled per-plate widgets.
- `OnUnitAdded(tp_frame, unit)` - called by `Styles.lua` whenever a style is applied - calls target and focus
  widgets if the unit is a (soft) target / the focus, and re-evaluates `Active` and `OnUnitAdded` for every
  enabled per-plate widget (hiding inactive frames).
- `OnUnitRemoved(tp_frame, unit)` deactivates and hides all frames and calls the optional callbacks.

`widget_frame.unit` is the plate's `unit` table itself, so a widget always sees current unit data; it is wiped on
unit removal.

## Settings updates and their cost

A widget's `UpdateSettings` runs far more often than its own settings change: `InitializeAllWidgets()` calls it
for **every** enabled widget on every custom style option and every profile change, often two or three times per
change. Keep it cheap or skip work whose inputs did not change. Historical bug: the Midnight auras widget
restyled all 5200 pooled aura buttons on every call and froze the game for 1-2 s; it now compares settings
signatures (see [Auras widgets](auras.md)). The per-plate refresh at the end of `UpdateSettings`
(`UpdateAllFrames`) is cheap (about 5 ms for 40 plates).

Every setting that changes the result of `IsEnabled()` must be set through the options' `SetValue` path, which
compares `IsEnabled()` before and after and re-initializes the widget; otherwise only `UpdateSettings` runs and,
for example, events stay unregistered. How a changed option reaches a widget is described in
[Options UI and propagating setting changes](../settings/options-and-updates.md).

## Events

- Subscribe in `OnEnable`, rely on the default `OnDisable` (or call `UnsubscribeAllEvents`) to unsubscribe,
  including internal events like `ThreatUpdate`. A widget that stays subscribed after being disabled can crash
  code that assumes its state was torn down.
- `self:SubscribeEvent(event)` calls `Widget:EVENT(...)`; `self:SubscribeEvent(event, func)` calls `func(...)`
  without the event name; the second argument is a function, not an expansion flag. Unit events
  (`self:SubscribeUnitEvent(event, unitid, func)`) pass the event name to `func`. See
  [Event system](../architecture/event-system.md) for the conventions and a pitfall: unsubscribing the last
  subscriber of an event can also unregister it for the core's main handler.
- `GetWidgetFrameForUnit(unitid)` returns the active frame of this widget for a unit, or `nil`.
- `UpdateAllFramesWithPublish(event)` updates all active frames and publishes an internal event per plate (e.g.
  `ClassColorUpdate` from the Social widget, so healthbar colors are recomputed).

The old event handling in `WidgetHandler.lua` (per-widget event frames) is intentionally kept as comments; it is
not active. One leftover: the `SubscribeUnitEvent` wrapper still creates a new unused `EventHandlerFrame` on every
call.

## Debugging

`/tptp debug WidgetHandler` (development builds) prints each widget's state and subscribed events;
`/tptp debug <WidgetName>` calls the widget's `PrintDebug`.
