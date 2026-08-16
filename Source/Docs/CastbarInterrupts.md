# Castbar interrupts: Retail/Midnight vs. Classic

Background for `Elements/Castbar.lua` and the `UNIT_SPELLCAST_*`/`COMBAT_LOG_EVENT_UNFILTERED`
handlers in `Nameplate.lua`.

## Event model

WoW fires `UNIT_SPELLCAST_INTERRUPTED` for a plain (non-channeled) cast that gets interrupted,
and `UNIT_SPELLCAST_CHANNEL_STOP` (with a non-nil `interruptedBy` 4th arg) for an interrupted
channel. WoW never also fires `UNIT_SPELLCAST_STOP` for an interrupted cast, so these are the
only signal that the cast ended.

`Addon:UNIT_SPELLCAST_INTERRUPTED` is Retail/Midnight-only code: it calls `GetClassColor`
(`C_ClassColor.GetClassColor`, version support uncertain across older Classic tiers) and
`class_color:WrapTextInColorCode(...)`. `Compatibility.lua`'s `WOW_EVENTS` gates the *event*
itself to `Addon.ExpansionIsAtLeastMidnight`, and `Addon:UNIT_SPELLCAST_CHANNEL_STOP` - the only
other caller, a direct Lua call rather than event dispatch - additionally checks
`ExpansionIsAtLeastMidnight` before routing an interrupted channel there, so the function is
unreachable on Classic by construction, not just because `interrupted_by` empirically comes
back `nil` there (see below). On Classic, both paths instead fall through to
`Addon:UNIT_SPELLCAST_STOP`, which always calls itself to clear cast-tracking state regardless
of whether a name ends up being shown.

## Retail/Midnight

`interrupted_by` (the interruptor's GUID) is reliably populated. `Addon:UNIT_SPELLCAST_INTERRUPTED`
resolves the name directly (`GetPlayerInfoByGUID`, falling back to `ResolveNameFromGUID` -
`UnitNameFromGUID` where available, `UNKNOWNOBJECT` otherwise) and shows it immediately.

Colored via `GetClassColor(class):WrapTextInColorCode(name)` - both C-API calls, safe per the
Midnight secret-value rules (the resolved name can be a secret value there). Deliberately *not*
`Addon.ColorByClass`, which builds the colored string through Lua-side `..` concatenation and
would error on a secret name - a shared Classic/Midnight helper using `Addon.ColorByClass` was
tried and reverted for exactly this reason (broke on Midnight).

## Classic

`interrupted_by` comes back `nil` even for genuine interrupts (confirmed in-game on Mists
Classic, despite generated API docs claiming otherwise — a doc/runtime mismatch, not a bug in
this addon). `GetPlayerInfoByGUID` also only resolves player GUIDs, not NPC/pet interruptors.
So on Classic the interruptor's name is never known at the point the cast stops. Two-step fix:

1. `Addon:UNIT_SPELLCAST_STOP` unconditionally marks `castbar.InterruptSourceUnknown = true`
   (every stop *might* be an undetected interrupt in disguise — this is safe because step 2
   only ever fires for genuine interrupts anyway).
2. `Addon:COMBAT_LOG_EVENT_UNFILTERED` (`SPELL_INTERRUPT`) is the *only* source that reliably
   names the interruptor on Classic. It looks the affected plate up by `destGUID` (not by
   `castbar_id`/timing — `castbar_id` is already `nil` again by the time this fires) and, if
   `InterruptSourceUnknown` is still set, backfills the name (combat-log `sourceName`, realm
   suffix stripped, colored via `Addon.ColorByClass` - fine here, Classic has no secret values)
   and color/hold-time. The flag is cleared there and by the next `OnStartCasting` (a new cast
   supersedes a stale backfill target), so this survives arbitrarily long combat-log delivery
   delays instead of relying on a fixed timing window (an earlier version used a 0.3s grace
   window keyed off `castbar_id` and `IsShown()` — too fragile in practice; combat-log delivery
   can lag well over a second).

Confirmed in-game (Mists Classic, debug logging): `Addon:UNIT_SPELLCAST_STOP` reliably fires and
sets `InterruptSourceUnknown = true` *before* `SPELL_INTERRUPT` arrives, for both channeled and
plain (non-channeled) interrupted casts - Classic's server evidently always sends a stop signal
when a cast ends for any reason, unlike Retail/Midnight's model of separate `UNIT_SPELLCAST_STOP`
(normal completion only) vs. `UNIT_SPELLCAST_INTERRUPTED` (interrupted only, never both). An
earlier version of this code assumed Classic followed the Retail split (reasoning from
Retail/Midnight's `CastingBarFrame.lua` source, which doesn't apply to Classic's actual
server-side cast handling) and added a broader `InterruptSourceUnknown or castbar.IsCasting or
castbar.IsChanneling` trigger plus a redundant explicit stop call to cover a "normal cast never
gets stopped" case that, per this confirmed behavior, doesn't exist - reverted back to the
simpler `InterruptSourceUnknown`-only check.

Retail/Midnight and Classic each build their "INTERRUPTED [Name]" text independently
(`Addon:UNIT_SPELLCAST_INTERRUPTED` / `Addon:COMBAT_LOG_EVENT_UNFILTERED` respectively) rather
than through a shared helper - see the secret-value note above for why that consolidation didn't
hold up.

### Reference: how Plater handles this

Plater (`Tercioo/Plater-Nameplates`) uses the same shape — native `UNIT_SPELLCAST_INTERRUPTED`
plus a plain `SPELL_INTERRUPT` combat-log backfill for the name — for TBC/Mists Classic and
Retail. Its separate Classic-**Era**-only codebase (`Plater-Nameplates-Classic`) instead derives
cast start/stop/interrupt entirely from combat log (via `LibClassicCasterino`); TP had that
exact setup from 2019 until Feb 2024 (commit `768d21c2`), removed once WoW Classic Patch 1.15.0
added native cast-bar events. A full combat-log-only rewrite for TP was considered and declined
for the same reason — no Plater precedent exists for TBC/Mists Classic, and NPC cast durations
aren't available from combat log directly (`LibClassicCasterino` had to infer/cache them by
observing full cast cycles, which TP deliberately moved away from in 2024).

## Single visibility authority

Both branches above funnel into this: `castbar:UpdateVisibility(tp_frame)` (`Elements/Castbar.lua`
- a method on the castbar frame itself, alongside `castbar:UpdateForCast(unit)`) is the *only*
place allowed to call `Show`/`Hide`/`SetShown` on the castbar or `SpellText` for cast-state-driven
visibility — style updates, cast start/stop, and interrupts all just set state (`unit.isCasting`,
`unit.IsInterrupted`, `castbar.PostCastHoldTime`) and call it to reconcile, instead of deciding
visibility themselves.

This exists because a `StyleModule.Update` triggered mid-interrupt (e.g. from
`Addon:UNIT_SPELLCAST_STOP`'s `CastTriggerReset`, or literally any other unit event firing
during combat) used to hide the castbar/`SpellText` independently and unconditionally, cutting
the interrupt display short before `CASTBAR_INTERRUPT_HOLD_TIME` elapsed.

`castbar.PostCastHoldTime` (counted down in `OnUpdate`/`OnUpdateMidnight` in `Elements/Castbar.lua`)
is what actually owns hiding the display once the hold time expires; the `OnHide` hook re-shows
the frame if something hides it early while `PostCastHoldTime` is still running.

## Revalidation vs. interrupt hold

`HandlePlateUnitAdded` (`Nameplate.lua`) re-runs for a plate that never actually changed unit
whenever `ScheduleNameplateRevalidation` fires (`UNIT_FACTION`/`UNIT_FLAGS`). That re-run's
`SetUnitAttributes`/`Element.PlateUnitAdded` unconditionally reset `unit.IsInterrupted` and
`castbar.PostCastHoldTime`, assuming a fresh occupant, which can cut an in-progress interrupt hold
short.

Two mitigations were tried:

1. **Reduce how often revalidation fires at all** - kept. `Addon:UNIT_FLAGS` fires very
   frequently - any combat/PvP-flag toggle on a tracked unit, not just BG flag carriers - so,
   mirroring Plater's own `UNIT_FLAGS` handler (`Plater.lua`, comment: *"triggers several times, a
   schedule is used to only update once"*), it now only reacts when something actually relevant
   changed: `unit.reaction` crossing a hostile/neutral/friendly boundary, `UnitCanAttack` toggling
   (tracked in a new `unit.CanAttack` field, set here), or the plate not yet being `Active`. When
   it does react, it calls the same `ApplyReactionUpdate(tp_frame, unitid)` helper as
   `Addon:UNIT_FACTION` (immediate light update: `SetNameplateVisibility`, then if `Active`
   `SetUnitAttributeReaction`/`ApplyPlateHitTest`/`StyleModule.Update`/
   `PublishEvent("FactionUpdate", ...)` - extracted from `Addon:UNIT_FACTION`'s two branches,
   which now share it too), *plus* `ScheduleNameplateRevalidation` - exactly `Addon:UNIT_FACTION`'s
   per-unit branch shape, kept deliberately even after adding the gate: the light update alone
   doesn't re-read name/health/GUID, so it can't catch a silent nameplate token reassignment (the
   documented stale-data bug class `ScheduleNameplateRevalidation` exists for in the first place) -
   only the frequency of firing was the actual problem, not the fact that it revalidates at all.
   `Addon:UNIT_FACTION` itself has no such gate (matches Plater, whose `UNIT_FACTION` handler
   schedules unconditionally too - `UNIT_FACTION` firing is inherently already a real
   faction/reaction change, unlike the noisier `UNIT_FLAGS`).
2. **Survive revalidation when it does fire** - tried, then dropped. `HandlePlateUnitAdded` used
   to snapshot `unit.IsInterrupted`/`castbar.PostCastHoldTime` before `SetUnitAttributes` reset
   them and restore both afterward for a same-GUID refresh. Checked how Plater handles the same
   scenario: it has an identical "was this unit already on-screen" check
   (`NAMEPLATES_ON_SCREEN_CACHE[unitID]` in `Plater.lua`'s `NAME_PLATE_UNIT_ADDED` handler,
   triggering the same kind of delayed `Plater.ScheduleUpdateForNameplate(..., 0.5)`
   revalidation) - its `RunScheduledUpdate` only saves/restores user-script-set bar sizes and
   border color across that revalidation, nothing about cast/interrupt state. Matched that: a
   dropped interrupt display on revalidation is acceptable, same as it already was for
   `Addon:UpdatePlatesVisible`/`Addon:ForceUpdateOnNameplate` (settings changes never preserved it
   either). In-game debug logging (Mists Classic) confirmed this is low-impact in practice - across
   a multi-minute combat log with several interrupts, revalidation-of-an-actively-interrupted-unit
   never actually occurred. Dropping the snapshot/restore also removed an ordering hazard the
   preservation approach had: `RefreshCastbar` (presentation's last step) reads
   `unit.IsInterrupted`/`castbar.PostCastHoldTime` to decide visibility, so a restore step had to
   run strictly between the rest of presentation and `RefreshCastbar` - easy to get wrong once
   `HandlePlateUnitAdded` was split into reusable `RefreshUnitData`/`RefreshPlatePresentation`
   pieces (see below). With no restore step, `RefreshCastbar` is just presentation's natural last
   step, no special positioning needed.

`HandlePlateUnitAdded` itself is now a thin wrapper: `RefreshUnitData` (re-reads from WoW APIs -
`SetUnitAttributes`, `PlatesByUnit`/`PlatesByGUID` bookkeeping, `ThreatModule.SetUnitAttribute`)
followed by `RefreshPlatePresentation` (everything computed from that data - visibility, style,
widgets, `RefreshCastbar`). `Addon:UpdatePlatesVisible`/`Addon:ForceUpdateOnNameplate` (triggered
by local settings/profile changes, not server-side unit events) call `RefreshPlatePresentation`
directly, skipping the unnecessary data re-read.
