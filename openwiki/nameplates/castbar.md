---
type: subsystem
title: Castbar and interrupts
description: How Threat Plates tracks casts, channels and empowered casts on nameplates, draws the castbar with either secret-safe timer objects or Lua arithmetic, shows the interrupter's name on Retail/Forever and Classic, and keeps castbar visibility consistent.
tags: [castbar, spellcast, interrupts, combat-log, nameplate, midnight]
sources:
  - id: openwiki-source-b28f0469e713ffab5d099af7
    resource: repo://Elements/Castbar.lua
  - id: openwiki-source-7a3e837cfb6d3795c0c95431
    resource: repo://Nameplate.lua
  - id: openwiki-source-8c1a2f1346df95ad59b63c21
    resource: repo://Styles/Styles.lua
generated: { by: "claude-code", at: "2026-10-28T19:52:11.033Z" }
verified:
  - by: openwiki/0.7.2
    at: 2026-10-28T19:52:11.033Z
---

# Castbar and interrupts

Cast handling is split between the core (`Nameplate.lua`, event handlers and `OnStartCasting`) and the Castbar
element (`Elements/Castbar.lua`, frames, color, `OnUpdate` and visibility). The spell icon is a separate element
(`Elements/SpellIcon.lua`) whose texture is a child of the castbar.

## Events

All `UNIT_SPELLCAST_*` events are registered by `Addon:EnableEvents()` with `Addon` as main subscriber. Every
handler first returns for `IGNORED_UNITS` (`target`, `player`, `focus`, soft-target tokens - they are updated
through their `nameplateN` token) and when castbars are off (`ShowCastBars`, i.e. castbar enabled for healthbar
or headline view).

| Event | Handler |
| --- | --- |
| `UNIT_SPELLCAST_START` | `OnStartCasting(..., channeled = false)` |
| `UNIT_SPELLCAST_CHANNEL_START`, `_CHANNEL_UPDATE`, `_EMPOWER_START` | `OnStartCasting(..., channeled = true)` |
| `UNIT_SPELLCAST_DELAYED`, `_EMPOWER_UPDATE` | `UnitSpellcastMidway`: refresh if `castbar_id == castbar.CastbarID` |
| `UNIT_SPELLCAST_INTERRUPTIBLE`, `_NOT_INTERRUPTIBLE` | `UnitSpellcastInterruptible`: refresh if `castbar.CastbarID` is set |
| `UNIT_SPELLCAST_STOP` | clear cast state if `castbar_id == castbar.CastbarID` |
| `UNIT_SPELLCAST_CHANNEL_STOP`, `_EMPOWER_STOP` | interrupted (`interrupted_by ~= nil`) on `HAS_MIDNIGHT_API` -> `UNIT_SPELLCAST_INTERRUPTED`, otherwise `UNIT_SPELLCAST_STOP` |
| `UNIT_SPELLCAST_INTERRUPTED` | only registered on `HAS_MIDNIGHT_API` clients |
| `COMBAT_LOG_EVENT_UNFILTERED` | only pre-Midnight, only with "show interrupt source" |

On Midnight, `UNIT_SPELLCAST_INTERRUPTIBLE`/`NOT_INTERRUPTIBLE` carry only the unit token, which is why the
interruptible handler guards on `castbar.CastbarID ~= nil` instead of a cast id. The guard is deliberately not
`castbar:IsShown()`: a style change can hide the castbar while the cast continues. (A former generic handler
compared `castbar_id ~= castbar.CastbarID` with `castbar_id = nil` and so never applied interruptibility
changes.)

## `OnStartCasting`

`OnStartCasting(tp_frame, unitid, cast_guid, event_spell_id, castbar_id, channeled)` reads the cast live:

1. If the plate is hidden, only reconcile visibility and return.
2. Read `UnitChannelInfo` or `UnitCastingInfo` (Classic shims in `Nameplate.lua`, see
   [Client and expansion compatibility](../architecture/client-compatibility.md)) and store
   `castbar.CastbarID = castbar_id or <castBarID from the info call>`.
3. No cast or a tradeskill -> reconcile visibility and return.
4. Pre-Midnight: check cast-based custom style triggers (`StyleModule.CastTriggerCheckIfActive`) and, if the
   style changes, `StyleModule.Update`.
5. If the current style has no castbar and no cast trigger is active, return.
6. Set `unit.isCasting = true`, `unit.IsInterrupted = false`, `unit.CastIsNotInterruptible`, and clear
   `castbar.InterruptSourceUnknown`.
7. Set spell text, spell icon, cast target name and timing (see below), call `castbar:UpdateForCast(unit)`
   (color, interrupt shield/border/overlay, spark), publish `CastingStarted` the first time, and reconcile
   visibility.

`RefreshCastbar(tp_frame, unitid)` (exported as `Addon.RefreshCastbar`) is the single entry point for "is the
unit casting right now?": it calls `OnStartCasting` for an active cast or channel, otherwise only reconciles
visibility. It runs at the end of every nameplate refresh and style application.

### Two timing paths

- **`HAS_MIDNIGHT_API`** - start/end times are secret. The castbar gets a duration object
  (`UnitCastingDuration`/`UnitChannelDuration`) via `SetTimerDuration(duration, Immediate, direction)`, and
  `OnUpdateMidnight` writes `Duration:GetRemainingDuration()` to the bar and the cast time text. The cast target
  is `UnitSpellTargetName`, colored with `C_ColorUtil.WrapTextInColor` and `C_ClassColor.GetClassColor`.
- **Other clients** - `castbar.Value`/`MaxValue` are computed in Lua from start/end times and advanced in
  `OnUpdate`. Empowered casts count as casting (`numStages > 0`). The cast target is `<unitid>target`.

`CastbarOnUpdate` is chosen once at load with the same `HAS_MIDNIGHT_API` condition. The two sides must match,
otherwise the legacy `OnUpdate` would see no `MaxValue` and hide the bar immediately.

## Interrupts

WoW signals an interrupted plain cast with `UNIT_SPELLCAST_INTERRUPTED` and an interrupted channel with
`UNIT_SPELLCAST_CHANNEL_STOP` and a non-nil `interruptedBy`. For a plain cast, WoW also fires
`UNIT_SPELLCAST_STOP` right after `UNIT_SPELLCAST_INTERRUPTED` (verified on Retail 12.1.5 for a kick, a stun and
movement). Background: `Source/Docs/CastbarInterrupts.md` (it still mentions a `ResolveNameFromGUID` helper; the
code calls `UnitNameFromGUID` directly).

**Retail/Forever** (`Addon:UNIT_SPELLCAST_INTERRUPTED`):

- With "show interrupt source" off, it just calls `UNIT_SPELLCAST_STOP` right away. The `STOP` event WoW sends
  afterwards is then ignored, because `castbar.CastbarID` is already cleared.
- Otherwise it resolves the interrupter from the GUID (`GetPlayerInfoByGUID`, fallback `UnitNameFromGUID`),
  transliterates and colors it with `class_color:WrapTextInColorCode` (C-API, safe for a secret name - not
  `Addon.ColorByClass`, which concatenates in Lua and broke on Midnight), shows `INTERRUPTED [name]`, fills the
  bar, sets the interrupted color and `PostCastHoldTime = CASTBAR_INTERRUPT_HOLD_TIME`, sets
  `unit.IsInterrupted`, then calls `UNIT_SPELLCAST_STOP` and reconciles visibility.
- It returns early when `castbar_id ~= castbar.CastbarID`, the castbar is hidden, or `interrupted_by` is `nil`.
  The cast still ends then: the `UNIT_SPELLCAST_STOP` that WoW fires after the interrupt clears
  `unit.isCasting`/`CastbarID`.

**Classic** - `interrupted_by` is `nil` even for real interrupts (confirmed on Mists Classic), so:

1. `UNIT_SPELLCAST_STOP` always sets `castbar.InterruptSourceUnknown = true`.
2. `Addon:COMBAT_LOG_EVENT_UNFILTERED` handles `SPELL_INTERRUPT`, finds the plate by `destGUID`
   (`GetThreatPlateForGUID`), and only if `InterruptSourceUnknown` is still set fills in the name from the combat
   log (realm stripped, `Addon.ColorByClass`), color and hold time. The flag is cleared there and by the next
   `OnStartCasting`, so a late combat-log entry still finds the right cast. In-game logging showed that `STOP`
   always arrives before `SPELL_INTERRUPT` on Classic.

## Visibility: a single authority

`castbar:UpdateVisibility(tp_frame)` is the only place that shows or hides the castbar and the spell text for
cast state. Everything else sets state and calls it:

```lua
show_castbar   = style.castbar.show and (unit.isCasting or unit.IsInterrupted or castbar.PostCastHoldTime > 0)
show_spelltext = show_castbar and style.spelltext.show   -- text is cleared when hidden
```

It exists because unrelated style updates during combat used to hide the castbar and cut the interrupt display
short. `PostCastHoldTime` is counted down in `OnUpdate`/`OnUpdateMidnight`, which hide the bar (and reset
`unit.IsInterrupted`) when it reaches zero; an `OnHide` hook re-shows the bar if something hides it earlier.
`Element.PlateUnitAdded` resets `PostCastHoldTime` to 0 for a new unit, and `Element.UpdateStyle` positions and
styles all parts but leaves visibility to `UpdateVisibility`.

A revalidation of an unchanged plate (`ScheduleNameplateRevalidation`) resets interrupt state as well. That is
accepted: preserving it was tried and dropped, and it rarely happens during an interrupt hold. See
[Nameplate lifecycle](lifecycle.md).

The castbar moves by a configurable offset when its unit is the target (`TargetGained`/`TargetLost`
subscription).

## Config mode

`Addon:ConfigCastbar()` (a button in the castbar options) shows a fake cast on the target's plate: it replaces the castbar's
`OnUpdate` with a function drawing a static "Portal: Darnassus" cast and replaces `castbar.Hide` with a no-op;
`UpdateVisibility` keeps the config plate shown. Turning config mode off restores both.

## Observations from reading the code (unverified)

- `OnStartCasting` stores `castbar.CastbarID` before it returns for a style without castbar, so `CastbarID` can
  be set while nothing is shown.

Related: [Secret values](../architecture/secret-values.md), [Elements](../rendering/elements.md).
