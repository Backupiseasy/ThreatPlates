---
type: subsystem
title: Target, soft target, mouseover and focus
description: How Threat Plates tracks which nameplate is the target, a soft target, the mouseover unit or the focus, which internal events it publishes for them, and how transparency, scaling, highlights and the target/focus widgets react.
tags: [target, soft-target, mouseover, focus, events, transparency, scaling]
sources:
  - id: openwiki-source-7202aa0fc899f694222f9477
    resource: repo://Elements/MouseoverHighlight.lua
  - id: openwiki-source-fba3ffd29735bf7da3a29a47
    resource: repo://Modules/Scaling.lua
  - id: openwiki-source-0eaf2cc03cbb31b69fad2f30
    resource: repo://Modules/Transparency.lua
  - id: openwiki-source-7a3e837cfb6d3795c0c95431
    resource: repo://Nameplate.lua
  - id: openwiki-source-0a31e436682c2bf333a46db9
    resource: repo://Widgets/TargetArtWidget.lua
generated: { by: "claude-code", at: "2026-10-28T19:52:11.033Z" }
verified:
  - by: openwiki/0.7.2
    at: 2026-10-28T19:52:11.033Z
---

# Target, soft target, mouseover and focus

The "meta units" `target`, `softenemy`, `softfriend`, `softinteract`, `focus` and `mouseover` are WoW unit tokens
that point at some other unit. `Nameplate.lua` maps each of them to the Threat Plates frame currently showing
that unit, publishes internal events when the mapping changes, and keeps flags in the unit table.

## State

- `PlatesByMetaUnit[meta_unitid] = tp_frame` (file-local in `Nameplate.lua`) - the frame per meta unit.
- Unit flags set in `SetUnitAttributes` and on changes: `unit.isTarget`, `unit.IsSoftEnemyTarget`,
  `unit.IsSoftFriendTarget`, `unit.IsSoftInteractTarget`, `unit.IsSoftTarget` (any of them), `unit.IsFocus`,
  `unit.isMouseover`. All are computed with the secret-safe `Addon.UnitIsUnit`.

### Soft targets count as target only if enabled

`Addon:UpdateSettings()` installs two functions depending on the "target style for soft enemy/friend/interact"
settings:

- `Addon.TargetUnitExists()` - does a (counting) target exist?
- `Addon.UnitIsTarget(unitid)` - is this unit the (counting) target?

Without soft-target styles they only check `"target"`. Callers must always go through `Addon.TargetUnitExists` /
`Addon.UnitIsTarget` and must not cache them as upvalues, because `UpdateSettings` replaces them.

## Target changes

`PLAYER_TARGET_CHANGED`, `PLAYER_SOFT_ENEMY_CHANGED`, `PLAYER_SOFT_FRIEND_CHANGED` and
`PLAYER_SOFT_INTERACT_CHANGED` all call `PlayerTargetChanged(meta_unitid)`:

1. **Old target** - if `PlatesByMetaUnit[meta_unitid]` is set, clear it. If that frame still has a unit,
   re-read its target flags; if it is active, `StyleModule.Update` and publish `TargetLost(tp_frame)`.
2. **New target** - `C_NamePlate.GetNamePlateForUnit(meta_unitid)`; if a frame exists, store it. If it is
   active, re-read its target flags, `StyleModule.Update` and publish `TargetGained(tp_frame)`.
3. **Existence** - if `Addon.TargetUnitExists()` differs from the value after the previous call, publish
   `TargetExistsChanged` (no payload).

`TargetLost`/`TargetGained` only concern the nameplate of the old/new target and only fire if it has an active
Threat Plates frame. `TargetExistsChanged` fires regardless of nameplates (e.g. a friendly target while friendly
nameplates are disabled); subscribe to it for anything that depends on whether a target exists at all, such as
"no target" vs. "non-target" transparency and scale of all other plates.

With only target nameplates shown, WoW sends the change event before the new target's plate exists. The new
target is then picked up by `NAME_PLATE_UNIT_ADDED`.

### Keeping references in sync with pooled plates

A unit can get a different plate (and with it a different `tp_frame`) while it stays the target. Observed: with
a friendly NPC targeted, toggling `nameplateShowFriendlyNpcs` off and on moved the target from `NamePlate3` to
`NamePlate10`. Therefore `UpdateTargetMetaUnitReferences(tp_frame, unitid)` runs in `HandlePlateUnitAdded`
(point the target and soft-target entries at this frame if it is that unit) and in `NAME_PLATE_UNIT_REMOVED`
(drop entries pointing at this frame). Without this, `PlayerTargetChanged` sent `TargetLost` to a stale frame and
the re-added plate kept its target scale, alpha and color. Check a unit's plate in-game with
`/run local p=C_NamePlate.GetNamePlateForUnit("target") print(p and p:GetName())`.

## Focus

`Addon:PLAYER_FOCUS_CHANGED()` (registered only where focus exists, `WOW_FEATURE_FOCUS`) resets the old focus
frame (`IsFocus = false`, `FocusLost` if active) and sets the new one from `Addon:GetThreatPlateForFocus()`
(`IsFocus = true`, `FocusGained`). Unlike the target, focus changes do not trigger a style update. Focus is not in
`TARGET_META_UNITS`, so it is not re-synced on plate recycling.

## Mouseover

`Addon:UPDATE_MOUSEOVER_UNIT()`:

1. `RemoveMouseoverFromNameplate()` - clear `isMouseover` on the previous frame (also when inactive, so switching
   between Threat Plates and Blizzard plates stays correct), publish `MouseoverOnLeave` if active, drop the
   reference.
2. If `GetThreatPlateForUnit("mouseover")` returns a frame (active, not the player), set `isMouseover`, store it
   and publish `MouseoverOnEnter`.
3. Start a 0.1 s ticker (`MouseoverMonitor`) that calls `RemoveMouseoverFromNameplate()` and stops once
   `UnitExists("mouseover")` is false. WoW does not fire an event when the mouse leaves a unit.

`NAME_PLATE_UNIT_REMOVED` removes the mouseover reference before wiping unit data (see
[Nameplate lifecycle](lifecycle.md)).

## Consumers

| Consumer | Events | Reaction |
| --- | --- | --- |
| `Modules/Transparency.lua` | `MouseoverOnEnter/Leave`, `CastingStarted/Stopped`, `TargetMarkerUpdate`, `TargetGained/Lost`, `FactionUpdate`, `ThreatUpdate` | recompute alpha of that plate |
| | `TargetExistsChanged` | recompute alpha of all active plates |
| `Modules/Scaling.lua` | same set | recompute scale of that plate / all plates |
| `Modules/Color.lua` | `TargetGained/Lost`, `FocusGained/Lost`, `TargetMarkerUpdate` | situational healthbar/name color |
| `Elements/MouseoverHighlight.lua` | `MouseoverOnEnter/Leave`, `TargetGained`, `TargetLost` | show/hide highlight; never on the target; on `TargetLost` re-show if the unit is still under the mouse |
| `Elements/Castbar.lua` | `TargetGained/Lost` | target castbar offset |
| `Elements/Healthbar.lua` | `TargetGained/Lost` | "show only for target" mode |
| `Widgets/TargetArtWidget.lua` (target-only widget) | `PLAYER_TARGET_CHANGED` + soft-target events | one highlight frame per target token, reparented to the target's plate |
| Focus widget (same file, focus-only widget) | `PLAYER_FOCUS_CHANGED` | one focus highlight frame |

Transparency and scaling use a priority order: the target never gets situational values; otherwise raid marker,
mouseover and casting override the target/non-target/no-target settings, which in turn add to (or with
"absolute" replace) the per-unit-type value. Threat styles (`dps`/`tank`) use the threat settings instead.

## Threat style of custom styles and headline view

`Modules/Transparency.lua` (`AlphaNormal`) and `Modules/Scaling.lua` (`ScaleNormal`) look up the threat style with
`Style.GetThreatStyle(unit)` (dot call - `GetThreatStyle` is dot-defined). For a custom style with "use threat
color" and for headline view with "use alpha/scaling", a `dps`/`tank` threat style therefore gets the threat-based
alpha and scale (`TransparencyThreat`/`ScaleThreat`); a `normal` threat style gets the general values. A custom style
that uses the threat system passes its own alpha/scale as `non_combat_*` value: it is used instead of the general
value when threat alpha/scale is turned off, and as base value for additive threat alpha/scale.

Until 13.3.4 the lookup was a colon call (`Style:GetThreatStyle(unit)`), which passed the `Style` table as unit,
so the threat style was always `"normal"` and threat alpha/scale were never applied there [GH-623]. The bug came
from commit `08f1fa77`, which turned the method into a dot function without updating its callers.

Related: [Modules](../rendering/modules.md), [Other widgets](../widgets/catalog.md).
