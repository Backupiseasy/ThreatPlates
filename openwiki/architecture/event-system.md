---
type: architecture
title: Event system
description: EventService.lua is the single dispatcher for WoW events and Threat Plates' internal events - main subscriber vs. subscribers, unit events, per-client gating, publishing, unsubscription rules and their pitfalls.
tags: [events, eventservice, pubsub, wow-events, internal-events]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-25T18:59:51.751Z
sources:
  - id: openwiki-source-014010f28568c5a3c3664449
    resource: repo://Addon.lua
  - id: openwiki-source-cfe0b084e5798ad70d26514c
    resource: repo://Commands.lua
  - id: openwiki-source-6eee19a5c8ad4d5edaf05fe2
    resource: repo://Compatibility.lua
  - id: openwiki-source-8010ad23cdbb1990bedd5d0e
    resource: repo://EventService.lua
  - id: openwiki-source-7a3e837cfb6d3795c0c95431
    resource: repo://Nameplate.lua
  - id: openwiki-source-a50841d1619063914118d2a2
    resource: repo://Widgets/AurasWidgetMidnight.lua
  - id: openwiki-source-4174717d9513e533ba3cdafd
    resource: repo://Widgets/QuestWidget.lua
  - id: openwiki-source-6794fbfa2ece0a99802c941d
    resource: repo://Widgets/WidgetHandler.lua
generated: { by: "claude-code", at: "2026-10-25T18:59:51.751Z" }
---

# Event system

`EventService.lua` (loaded right after `Compatibility.lua`) is the only place where Threat Plates registers WoW
events. It replaced the old per-widget event handling; that code in `Widgets/WidgetHandler.lua` is
intentionally kept as comments and is not active.

## Data structures

| Table | Content |
| --- | --- |
| `RegisteredEvents[event]` | the one **main subscriber** of a WoW event: a function, or `Addon` itself |
| `SubscribersByEvent[event][subscriber]` | further subscribers: `true` (call the method named like the event) or a function |
| `RegisteredUnitEvents[unitid]` | one frame per unit token; `frame.Events[event][subscriber]` like above |
| `INTERNAL_EVENTS` | names of Threat Plates' own events (never registered at WoW) |

A single `EventHandlerFrame` receives all non-unit WoW events. Unit events get their own frame per unit token
(`SubscribeUnitEvent`), created lazily and registered with `RegisterUnitEvent`.

## API

- `EventService.RegisterEvent(event, func)` - sets the main subscriber (`func` or `Addon`). The WoW event is
  registered only when there was no main subscriber before. Only one main subscriber is supported; a second
  call replaces the first.
- `EventService.UnregisterEvent(event)` - clears the main subscriber and unregisters the WoW event only if no
  other subscriber remains.
- `EventService.Subscribe(subscriber, event, func)` - adds a subscriber. Registers the WoW event if there is
  no main subscriber yet and the event is not internal.
- `EventService.SubscribeUnitEvent(subscriber, event, unitid, func)` - adds a subscriber for one unit token.
- `EventService.Publish(event, ...)` - calls all subscribers of an (internal) event.
- `EventService.Unsubscribe(subscriber, event)` / `UnsubscribeAll(subscriber)` - remove a subscriber from one or
  all events, including unit events.

Every entry point first checks `INTERNAL_EVENTS[event] or Addon:ExpansionSupportsEvent(event, ...)` and returns
silently otherwise, so code can subscribe to events that do not exist on the running client.

### Calling conventions

How a handler is called depends on how it was registered. Getting this wrong shifts all parameters:

| Registration | Handler call |
| --- | --- |
| `RegisterEvent(event)` (main = `Addon`) | `Addon[event](Addon, ...)` - e.g. `function Addon:UNIT_HEALTH(unitid)` |
| `RegisterEvent(event, func)` | `func(...)` |
| `Subscribe(s, event)` | `s[event](s, ...)` - e.g. `function Widget:QUEST_LOG_UPDATE(...)` |
| `Subscribe(s, event, func)` | `func(...)` (no event name) |
| `SubscribeUnitEvent(s, event, unitid)` | `s[event](s, ...)` |
| `SubscribeUnitEvent(s, event, unitid, func)` | `func(event, ...)` - **with** the event name |
| `Publish(event, ...)` | as for `Subscribe` |

For a WoW event, `EventHandler` calls the main subscriber first and then all other subscribers. This is how
Modules, Elements and Widgets see an event only after the core (`Nameplate.lua`) has updated the `unit` table.
The order among the other subscribers is the undefined `pairs` order.

Widgets get thin wrappers (`self:SubscribeEvent`, `self:SubscribeUnitEvent`, `self:PublishEvent`,
`self:UnsubscribeEvent`, `self:UnsubscribeAllEvents`) from `WidgetHandler:NewWidget`; see
[Widget framework](../widgets/framework.md).

## Per-client gating

`Compatibility.lua` defines `WOW_EVENTS`, mapping every WoW event the addon uses to a boolean for the running
client (e.g. `COMBAT_LOG_EVENT_UNFILTERED = not Addon.HAS_MIDNIGHT_API`,
`UNIT_HEALTH_FREQUENT = not Addon.ExpansionIsAtLeastMists and not Addon.IS_FOREVER`).
`Addon:ExpansionSupportsEvent(event, register_for_current_expansion)` returns the entry unless the caller passes
`false`. An event missing from `WOW_EVENTS` is never registered - add new WoW events there first. See
[Client and expansion compatibility](client-compatibility.md).

`ExpansionSupportsEvent` returns `false` for internal events, so every unsubscribe path must also check
`INTERNAL_EVENTS`. `UnsubscribeAll` does this; it was missing once, which left a disabled Quest widget subscribed
to `ThreatUpdate` and crashed in epic battlegrounds.

## Internal events

Published by the core and modules, mostly with the nameplate's `tp_frame` as payload:

| Event | Payload | Published by |
| --- | --- | --- |
| `ThreatUpdate` | `tp_frame`, `unitid` | threat module |
| `MouseoverOnEnter` / `MouseoverOnLeave` | `tp_frame` | `UPDATE_MOUSEOVER_UNIT` handling |
| `CastingStarted` / `CastingStopped` | `tp_frame` | castbar handling |
| `TargetGained` / `TargetLost` | `tp_frame` | `PlayerTargetChanged` |
| `TargetExistsChanged` | - | `PlayerTargetChanged`, after the two above |
| `FocusGained` / `FocusLost` | `tp_frame` | `PLAYER_FOCUS_CHANGED` |
| `TargetMarkerUpdate` | `tp_frame` | `RAID_TARGET_UPDATE` |
| `FactionUpdate` | `tp_frame` | reaction changes (`UNIT_FACTION`, `UNIT_FLAGS`) |
| `SituationalColorUpdate`, `ClassColorUpdate`, `ThreatColorUpdate`, `NameColorUpdate`, `HealthbarColorUpdate` | `tp_frame` (+ color) | color re-evaluation |

`Addon:PublishToEachPlate(event)` publishes one event for every active nameplate.

`Publish` does nothing once `Addon.IsShuttingDown` is set by AceDB's `OnDatabaseShutdown` callback. On logout or
reload, AceDB strips profile defaults while `NAME_PLATE_UNIT_REMOVED` still fires for every plate; handlers of
e.g. `MouseoverOnLeave` would then read missing settings and error.

## Core events (`Nameplate.lua`)

`Addon:EnableEvents()` is called from `TidyPlatesThreat:OnInitialize` (so `PLAYER_LOGIN` is not missed) and
registers `Addon` as main subscriber for everything in `ENABLED_EVENTS`: login/world/combat
(`PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `PLAYER_MAP_CHANGED`, `PLAYER_REGEN_ENABLED/DISABLED`), the nameplate
events, target/soft-target/focus/mouseover changes, `RAID_TARGET_UPDATE`, unit data events (name, health, max
health, threat, faction, flags, level), all spellcast events and `UI_SCALE_CHANGED`. From Mists on,
`ACTIVE_TALENT_GROUP_CHANGED` is added.

Some events are registered conditionally at runtime:

- `COMBAT_LOG_EVENT_UNFILTERED` - in `Addon:UpdateSettings()` when "show interrupt source" is enabled (only on
  clients where the event is allowed).
- `ARENA_OPPONENT_UPDATE` - in `PLAYER_ENTERING_WORLD` only inside a solo shuffle.
- `RUNE_UPDATED`, `PLAYER_EQUIPMENT_CHANGED` - Season of Discovery rogues (tank detection).
- `UNIT_AURA` for `"player"` - Classic tank-aura classes, via `SubscribeUnitEvent(Addon, ...)`.

## Ordering facts

- WoW events never fire inside another Lua event handler. Script handlers (`OnShow`, `OnHide`) do fire
  synchronously when the corresponding API is called. Verified exception: `CVAR_UPDATE` fires inside
  `C_CVar.SetCVar`.
- Between two handlers anything can happen: `UNIT_FACTION` was observed between `NAME_PLATE_UNIT_REMOVED` and
  `NAME_PLATE_UNIT_ADDED` in solo shuffles. Clear derived state (mouseover, target references) before wiping
  unit data; see [Nameplate lifecycle](../nameplates/lifecycle.md).

## Pitfall: unsubscribing can unregister the main subscriber's event

Found by reading the code, not verified in-game. `UnregisterGameEvent` unregisters a WoW event from its frame as
soon as the last *subscriber* is removed. It does not check whether `RegisteredEvents[event]` still has a main
subscriber. `Subscribe` also only registers at WoW if there is no main subscriber. Taken together:

1. `Addon` is main subscriber of `PLAYER_REGEN_ENABLED`; the Auras and Quest widgets subscribe to it too.
2. Both widgets are disabled at runtime. Their default `OnDisable` calls `UnsubscribeAllEvents`, and the last
   removal unregisters `PLAYER_REGEN_ENABLED` from `EventHandlerFrame`.
3. `Addon:PLAYER_REGEN_ENABLED` no longer runs, so tasks queued with `Addon.ExecuteAfterCombatEnds` are not
   executed and the combat automation of nameplates stops. Re-enabling a widget does not register the event
   again, because a main subscriber exists. A `/reload` restores it.

`UnsubscribeAll` also visits events whose subscriber table is already empty, so any later `UnsubscribeAll` can
unregister such an event again. Other core events with only optional subscribers are affected the same way, e.g.
`PLAYER_TARGET_CHANGED` (subscribed by the Auras, ComboPoints, Resource and TargetArt widgets; the subscription in
`Elements/Classification.lua` is commented out) and `PLAYER_ENTERING_WORLD` (Quest, ComboPoints, Arena widgets,
and the Threat module only while the heuristic is used in instances; `ThreatModule.UpdateSettings` also calls
`Unsubscribe` for it on every settings update). A fix would check `RegisteredEvents[event]` before
unregistering.

## Debugging

`Addon:PrintEventService()` lists main subscribers, subscribers per event and unit events.
`Addon:DebugWidgetHandler()` prints for each widget whether it is enabled and which events it holds. Both are
reachable through the debug chat commands (see [Development workflow](../workflows/development.md)).
