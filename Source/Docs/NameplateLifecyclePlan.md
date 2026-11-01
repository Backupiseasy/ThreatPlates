# Nameplate lifecycle: implementation plan

Branch: `feature/nameplate-lifecycle` (created from `release/13.3` @ `cc69d850`, rebased onto `develop` @ `5c347f60`
on 2026-10-30). Target version: 13.4.0.

Background: comparison of how Plater and Platynator handle `NAME_PLATE_CREATED` / `NAME_PLATE_UNIT_ADDED` /
`NAME_PLATE_UNIT_REMOVED`, anchor their own frames and hide Blizzard's `plate.UnitFrame`, versus TP's
implementation in `Nameplate.lua`. This document turns the derived improvements (P1-P8 plus the low-priority
items L1-L3) into an ordered, testable implementation plan.

## 0. Reference facts

Verified against `wow-ui-source` (live, classic, classic_era, classic_anniversary):

- `NamePlateBaseMixin:AcquireUnitFrame` (`Blizzard_NamePlateBase.lua`):
  `self.UnitFrame = driver:AcquireUnitFrame(self); UnitFrame:SetParent(self); UnitFrame:SetAllPoints(self)`.
  So `UnitFrame`'s center is always `plate`'s center on the modern driver.
- `NamePlateDriverMixin:AcquireUnitFrame` only returns `pool:Acquire()`. TP's
  `hooksecurefunc(NamePlateDriverFrame, "AcquireUnitFrame", ...)` therefore runs **before** `plate.UnitFrame` is
  assigned (after a release it is `nil`), so on the modern driver the hook itself does nothing. The effective
  work is done by the manual call in `Addon:NAME_PLATE_UNIT_ADDED`.
- `NamePlateBaseMixin:ReleaseUnitFrame` sets `plate.UnitFrame = nil` on `REMOVED`.
- `NamePlateUnitFrameMixin:OnUnitSet` re-registers all Blizzard unit-frame events on every `ADDED`, and
  `OnUnitCleared` removes them. Unregistering events for one plate lifetime is therefore self-healing.
- The **old** Classic driver (`wow-ui-source-classic_beta/.../TBC|Vanilla/Blizzard_NamePlates.lua`) anchors
  `UnitFrame` with `SetPoint("TOPLEFT", plate, "TOPLEFT")` only (no `SetAllPoints`). There, `UnitFrame`'s
  center matches `plate`'s center only if both sizes match. **Not live anywhere** (see "Verification results").

### Verification results (2026-09-25)

- UI source: `Blizzard_NamePlateBase.lua` and `Blizzard_NamePlates.lua` are identical (ignoring CR/whitespace)
  between classic_era, classic_anniversary, classic (Mists) and live. `Blizzard_NamePlateUnitFrame.lua` is
  identical between all Classic flavors and differs from live by 74 lines (Retail-only features). The old
  TOPLEFT driver only exists in the outdated `classic_beta` snapshot.
- In-game, driver check `p.AcquireUnitFrame ~= nil`: `true` on all plates on Retail and Classic Era.
- In-game, `IsAnchoringRestricted()`: `plate`, `UnitFrame` and `TPFrame` are all `true` on Retail and Classic Era
  (open world, out of combat). Position queries (`GetPoint`, `GetCenter`, `GetLeft`) throw `Can't measure
  restricted regions`, size queries (`GetWidth`) work. Positions can therefore not be measured; the P1 tests
  below use a visual A/B re-anchor instead.
- In-game, Classic Era: re-anchoring `TPFrame` of 30+ live plates from `UnitFrame` to `plate` (`ClearAllPoints` +
  `SetPoint("CENTER", p)`) caused no visible layout change.
- Consequence: P1 needs no flavor gate; the `ANCHOR_TPFRAME_TO_UNITFRAME` flag was dropped in favor of a comment
  (runtime detection would be `plate.AcquireUnitFrame == nil`, should the old driver ever come back).
- Side finding: `Addon:NAME_PLATE_CREATED`'s `not Addon.ExpansionIsAtLeastMists and plate.UnitFrame` branch is based
  on an outdated assumption (Classic Era uses the pooled driver too). Harmless, since `plate.UnitFrame` is `nil`
  at `CREATED` there. Cleanup scheduled with L1.

Reference implementations:

| Topic | Plater (`Plater.lua`) | Platynator (`Display/Initialize.lua`) |
| --- | --- | --- |
| Own frame anchor | Parent `plateFrame`, `SetAllPoints` | `SetPoint("CENTER", nameplate, "CENTER", 0, offsetY)` |
| Hide Blizzard plate | `hooksecurefunc(UnitFrame, "Show")`; protected → `ClearAllPoints`+`SetParent(nil)`, else `Hide()`; `UnregisterAllEvents` | `UnitFrame:SetParent(hiddenFrame)` + `UnregisterAllEvents` on every `ADDED` |
| Hook marker | `HOOKED_BLIZZARD_PLATEFRAMES[tostring(UnitFrame)]` | none |
| Revalidation | One timer per plate (`HasUpdateScheduled`), replaced/cancelled, cancelled on `REMOVED` | Uninstall/Install |
| Missed `REMOVED` | `UNIT_FLAGS`: no plate but cached → run `REMOVED` | - |
| Classification change | `REMOVED`+`ADDED` | Design reassignment |
| Stacking (Midnight) | `SetStackingBoundsFrame(stackSizeFrame)` | `SetStackingBoundsFrame(stackRegion)` |

## 1. Order and dependencies

```
P7 ─┐
P1 ─┼─> L1 (hidden parent, drop Show watchdog)
    └─> P8 (stacking bounds; reuses the plate-anchored helper-frame pattern) ─> P8b (later, TP-size-based stacking)
P2 ─> P3 ─> P4
P5 (independent)
P10 ─> P9 (hit-test area: clamp first, then scale with TPFrame)
P6 (optional, after L1)
L2, L3 (measure first, may be dropped)
```

One commit per item. Run `luacheck . --config .luacheckrc.ci` before each commit and `/reload` smoke test
on Retail/Midnight.

## 2. Items

### P7: Keep hook marker out of Blizzard's frame (trivial, do first) — DONE (`47d61a38`)

- **Problem**: `unit_frame.ThreatPlates = true` (`Nameplate.lua`, `NamePlateDriverFrame_AcquireUnitFrame`)
  writes an addon key onto a (possibly secure) Blizzard frame.
- **Change**: `local HookedUnitFrames = setmetatable({}, { __mode = "k" })`, next to
  `BlizzardPlateOrigParent`. Replace the flag check/assignment with `HookedUnitFrames[unit_frame]`.
- **Check**: `grep -n "\.ThreatPlates\b"` across the repo (also `Widgets/`, `Commands.lua` debug output) for
  other readers. Currently only `Nameplate.lua` uses it.
- **Test**: `/reload`, move through many plates, and verify that the OnShow/Show hooks still attach exactly
  once per pooled instance (temporary debug counter).
- **Changelog**: none (internal).

### P1: Anchor `TPFrame` and `HitTestFrame` to `plate`, not `plate.UnitFrame` — DONE

- **Problem**: `TPFrame` is anchored to the pooled `plate.UnitFrame`. This caused the 13.3.0 regression
  (stale anchor after pool reassignment). `SetShownBlizzardPlate`'s protected branch (`ClearAllPoints` +
  `SetParent(nil)` on `UnitFrame`) also destroys `TPFrame`'s rect while the Blizzard plate is hidden that way.
  `ApplyPlateHitTest` anchors `HitTestFrame` to `plate.UnitFrame` too, and `plate:SetAllHitTestPoints(plate.UnitFrame)`
  errors if `UnitFrame` is `nil`.
- **Change**:
  1. `HandlePlateCreated`: `tp_frame:SetPoint("CENTER", plate, "CENTER")` once.
  2. `NamePlateDriverFrame_AcquireUnitFrame`: remove the `plate.TPFrame:SetPoint(...)` line. Keep the
     `BlizzardPlateOrigParent` reset and hook installation.
  3. `ApplyPlateHitTest`: `tp_frame.HitTestFrame:SetPoint("CENTER", plate, "CENTER")`. Guard the Blizzard
     branch: `elseif not tp_frame.Active then if plate.UnitFrame then plate:SetAllHitTestPoints(plate.UnitFrame) end`.
  4. ~~Flavor gate~~: not needed, see "Verification results". No flag; the old-driver caveat is documented in
     the code comment and CLAUDE.md.
  5. `CVarsManager.lua`: comment at `RESYNC_NATIVE_SIZE_CVARS` updated (`HitTestFrame` is anchored to `plate`).
- **Docs** (done): rewrote the "Anchoring" part of the comment block above `IgnoreUnitForThreatPlates`
  (`Nameplate.lua`). Replaced the CLAUDE.md bullet "`plate.UnitFrame` is pooled - re-anchor `TPFrame` on every
  acquire" with "never anchor TP frames to it", and added the bullet "Nameplate frames are restricted regions - no
  position queries", which includes a diagnostic that does not measure.
- **Test** (positions cannot be measured, see "Verification results"):
  - Visual A/B, already done on Classic Era before the change: re-anchor live plates via `/run` and compare
    screenshots.
  - After the change: `/run for _,p in ipairs(C_NamePlate.GetNamePlates())do print(p:GetName(),p.AcquireUnitFrame~=nil,p.TPFrame and p.TPFrame:IsVisible())end`
    shows `true true` for TP-handled plates.
  - Position identical to before (screenshot comparison) with Nameplate Size Normal/Big, Headline View,
    mouseover/target scaling, custom styles with offsets.
  - Mixed mode (Blizzard plates for friendly units) plus reaction change (mind control, duels).
  - BG/arena/raid: no vanishing or misplaced plates.
  - Config mode plate (`ConfigModePlate`, uses `HitTestFrame`).
  - All flavors: Retail/Midnight, WoW Forever, Mists Classic, Classic Era/Anniversary, SoD.
- **Changelog**: `Fixed a bug where nameplates were sometimes briefly shown on top of a different unit or
  disappeared, caused by Blizzard reusing its nameplate frames.` (only if not already covered by the 13.3.0 entry)

### P2: Deduplicate and cancel revalidation timers — IMPLEMENTED, in-game test pending

- **Problem**: `ScheduleNameplateRevalidation` uses `C_Timer.After` without a handle. `UNIT_FACTION` fires
  for every visible unit at `PLAYER_ENTERING_WORLD`, and `UNIT_FACTION`+`UNIT_FLAGS` bursts create several full
  `HandlePlateUnitAdded` runs per plate. Timers survive `REMOVED`.
- **Change**: two slots per plate (the 0-frame and 0.5 s delays serve different purposes and must not swallow
  each other):
  ```lua
  local function ScheduleNameplateRevalidation(plate, unitid, delay)
    delay = delay or 0
    local tp_frame = plate.TPFrame
    local timers = tp_frame.RevalidationTimers
    local slot = (delay > 0 and "delayed") or "immediate"
    local timer = timers[slot]
    if timer and not timer:IsCancelled() then
      if timer.unitid == unitid then return end
      timer:Cancel()
    end
    timer = C_Timer.NewTimer(delay, function(self)
      if timers[slot] ~= self then return end
      timers[slot] = nil
      if PlatesByUnit[unitid] == tp_frame and tp_frame.unit.unitid == unitid then
        HandlePlateUnitAdded(plate, unitid)
        NamePlateDriverFrame_AcquireUnitFrame(nil, plate)
      end
    end)
    timer.unitid = unitid
    timers[slot] = timer
  end
  ```
  `tp_frame.RevalidationTimers = {}` in `HandlePlateCreated`. New `CancelNameplateRevalidation(tp_frame)`,
  called in `NAME_PLATE_UNIT_REMOVED` before `wipe(tp_frame.unit)`.
- **Test**: log the number of `HandlePlateUnitAdded` calls per plate during login/zoning in a crowded area and
  in a BG, before and after. Stale-name bug scenarios ([Comment #8228, #8363, #8408, #8433]) must stay fixed.
- **Changelog**: none, or `Improved performance when entering the world or zoning with many nameplates visible.`

- **Implemented** (`Nameplate.lua`): as sketched above. The callback uses the timer passed by `C_Timer.NewTimer`
  (`function(self)`; verified in-game on 2026-09-30 that the timer itself is passed, `arg == t` was `true`).
  `CancelNameplateRevalidation` cancels and clears the two slots directly (no loop, no new table per
  `NAME_PLATE_UNIT_REMOVED`, no `wipe()`). CLAUDE.md "Stale unit data after nameplate recycling" is updated.

### P3: Harden `NAME_PLATE_UNIT_REMOVED` — IMPLEMENTED, mostly verified (BG/arena pending)

- **Problem**: `GetNamePlateForUnit(unitid)` is not nil-guarded. Teardown also runs for plates that `ADDED`
  deliberately skipped (personal plate, widget-only plates).
- **Change**:
  ```lua
  local plate = GetNamePlateForUnit(unitid)
  local tp_frame = PlatesByUnit[unitid] or (plate and plate.TPFrame)
  if not tp_frame then return end
  local was_added = PlatesByUnit[unitid] ~= nil
  -- mouseover cleanup, Active = false, CancelNameplateRevalidation (P2) - always
  if was_added then
    -- PlatesByUnit/PlatesByGUID cleanup, Widgets:OnUnitRemoved, WidgetContainerReset(tp_frame.Parent)
  end
  wipe(tp_frame.unit); tp_frame.stylename = nil
  ```
  Use `tp_frame.Parent` instead of the looked-up `plate` everywhere below the guard.
- **Check**: `Widgets:OnUnitRemoved` and `WidgetContainerReset` have no side effects that ignored plates rely
  on (e.g. a widget-only plate that was TP-active earlier in the same plate lifetime).
- **Test**: personal resource display on/off, widget-only plates (Oribos / Dornogal objects, quest objects),
  soft-interact objects, BG spam.
- **Changelog**: `Fixed a Lua error that could occur when a nameplate was removed.` (only if a real error was
  reproduced or reported)

- **Implemented** (`Nameplate.lua`): as sketched. The frame comes from `PlatesByUnit[unitid]` first, then
  `GetNamePlateForUnit`, with an early return if neither exists. `was_added = PlatesByUnit[unitid] == tp_frame`.
  Always run: mouseover/target meta-unit cleanup, `Active = false`, `CancelNameplateRevalidation`,
  `wipe(tp_frame.unit)`, `stylename = nil`. Only if `was_added`: `PlatesByUnit`/`PlatesByGUID`,
  `Widgets:OnUnitRemoved`, `WidgetContainerReset(tp_frame.Parent)`. `wipe()` stays as before (existing code; the
  no-`wipe` rule applies to new tables). Check result: `Widgets:OnUnitRemoved` only acts on `unit.IsSoftTarget` /
  `unit.IsFocus`, which are never set for skipped plates. `WidgetContainerReset` on a skipped plate could re-parent a
  stale `tp_frame.WidgetContainer` (a pooled Blizzard frame from an earlier unit, possibly in use by another plate)
  to this plate, so skipping it is a fix, not just an optimization. CLAUDE.md "Nameplate lifecycle" is updated.

### P4: Recover from a missed `NAME_PLATE_UNIT_REMOVED` — IMPLEMENTED, in-game test pending

- **Problem**: In PvP, Blizzard can drop a plate without `REMOVED` (see the comment in `ShowBlizzardNameplate`).
  TP then keeps a stale `PlatesByUnit[unitid]`.
- **Change**: in `Addon:UNIT_FLAGS` and in the per-unit branch of `Addon:UNIT_FACTION`, before any other work:
  ```lua
  if PlatesByUnit[unitid] and not GetNamePlateForUnit(unitid) then
    Addon:NAME_PLATE_UNIT_REMOVED(unitid)   -- relies on P3's PlatesByUnit fallback
    return
  end
  ```
  Solo-shuffle ordering (UNIT_FACTION between REMOVED and ADDED) is unaffected: `PlatesByUnit[unitid]` is
  already `nil` then.
- **Depends on**: P3.
- **Test**: arena/BG, stealth/feign death, mind control, units leaving range at the edge of view distance.
- **Changelog**: `Hopefully fixed a bug where a nameplate kept showing outdated information after its unit
  was no longer visible.`

- **Implemented** (`Nameplate.lua`): helper `RemoveStalePlateForUnit(unitid)` (defined before `UNIT_FACTION`),
  called at the start of `UNIT_FLAGS` and of the per-unit branch of `UNIT_FACTION`, and additionally for every
  entry in the `UNIT_FACTION("player")` loop over `PlatesByUnit`. Clearing the current key during a `pairs` traversal
  is allowed in Lua. No changelog bullet of its own (covered by the shared 13.4.0 entry). CLAUDE.md "Nameplate
  lifecycle" is updated.

### P5: Handle `UNIT_CLASSIFICATION_CHANGED` — IMPLEMENTED, functional test not easily possible

- **Problem**: TP ignores it, so elite/rare/normal changes (e.g. rare timers, scripted encounter phases) keep
  the old style, custom style trigger and classification icon.
- **Change**:
  1. `Compatibility.lua` `WOW_EVENTS`: `UNIT_CLASSIFICATION_CHANGED = true` (verify existence per flavor
     with `wow-api` `get_event` and an in-game event registration check, and gate if necessary).
  2. `Nameplate.lua` `ENABLED_EVENTS`: add it.
  3. Handler:
     ```lua
     function Addon:UNIT_CLASSIFICATION_CHANGED(unitid)
       if IGNORED_UNITS[unitid] then return end
       local tp_frame = PlatesByUnit[unitid]
       if tp_frame then
         HandlePlateUnitAdded(tp_frame.Parent, unitid)
       end
     end
     ```
     A full refresh like Plater, since the event is rare and classification feeds style selection.
- **Test**: rare that turns elite/normal, target dummy with changing classification, in-game event registration check
  on all flavors.
- **Changelog**: `Fixed a bug where nameplates did not update their style when a unit's classification (e.g.
  elite or rare) changed.`

- **Implemented**: `UNIT_CLASSIFICATION_CHANGED = true` in `WOW_EVENTS` (the event exists in the UI source of live,
  classic, classic_era, classic_anniversary and forever; Blizzard's own `Blizzard_NamePlateClassificationFrame` uses
  it), added to `ENABLED_EVENTS`, and the handler as sketched (after `UNIT_LEVEL`). In addition, it calls
  `RemoveStalePlateForUnit` (P4) first. Changelog: own bullet in the 13.4.0 block, `Fixed a bug where nameplates did
  not update their style when a unit's classification (e.g., elite or rare) changed.`

### P8: Use `SetStackingBoundsFrame` — IMPLEMENTED, verified on Retail

**Decision (2026-09-26)**: TP plates stack with the size of Blizzard's hit-test area (= same spacing as Blizzard's
plates), and Blizzard-shown plates exactly like Blizzard. The spacing is scaled for all plates by the existing
`nameplateOverlapH/V` CVars (TP's "Horizontal/Vertical Overlap" options). The interim "Stacking Width/Height"
options (a factor on the size) were **removed again**: they duplicated Overlap, which works on Retail and Classic Era
with stacking on, with TP enabled and disabled, for Blizzard-shown and TP plates (verified in-game 2026-09-26). P8
is active on all clients that implement `plate:SetStackingBoundsFrame` (a real method on Retail, "WoW Forever" and
Classic Era; all clients share the same nameplate API).

**In-game results (Retail, 2026-09-25)**, step by step:
1. Hidden, empty frame: **no stacking at all** with TP enabled, for TP *and* Blizzard-shown plates. Showing the
   frame alone did not help. Stashing P8 + `/reload` restored stacking, so P8 was the cause. Fix: frame shown,
   with a fully transparent texture (same as Plater and Platynator). After that, stacking works and toggling
   stacking on/off is applied correctly.
2. TP's click-area size (140 x 20) → TP plates stacked tighter than Blizzard's plates.
3. Whole plate (`SetAllPoints(plate)`, 172.5 x 60.3) → *all* plates, including Blizzard-shown ones, stacked wider
   than with TP disabled, so Blizzard's default is not the plate.
4. Temporary `/tptp stacking-test hittest` (stacking frame anchored like `UpdateHitTestArea`) → Blizzard-shown
   plates got the native spacing. Blizzard's default stacking bounds = its hit-test area.
5. Final implementation, same camera and same CVars (`nameplateOverlapH/V` 1.12/1.66), TP disabled vs. enabled:
   identical spacing (the lower rows match to the pixel, the upper ones differ by a few px from perspective).
   (`nameplateOverlapV` 2 vs. 1.66 made no visible difference at first, which led to the wrong conclusion that
   Overlap had no effect on Midnight. A later test with 0.5 vs. 2.0 showed it does, see the decision above.)

- **Problem**: Blizzard stacks TP plates using its default bounds, not TP's actual plate size. Plater and
  Platynator both provide a stacking frame.
- **API facts**: `SetStackingBoundsFrame(frame)` has no `RequiresCanChangeHitTestPoints` precondition (unlike the
  hit-test API), and `frame` is not nilable, so there is no "reset to Blizzard default". A no-op Lua stub exists in
  `NamePlateScriptBaseMixin`, but real nameplates have the real method (checked in-game on Forever and Classic Era).
  Blizzard's own UI never calls it.
  Reference: Plater always sets its own frame (size = click space × overlap scale, anchored to its unit frame, or
  to the plate when Blizzard's plate is shown), and Platynator uses its design's "stack" region.
- **Implemented** (`Nameplate.lua`):
  1. `HandlePlateCreated`: `tp_frame.StackingBoundsFrame` (parent `plate`, shown, no mouse, fully transparent
     texture). Only created if `plate.SetStackingBoundsFrame` exists.
  2. `AnchorToBlizzardHitTestArea(frame, unit_frame)`: anchors to Blizzard's healthbar/name like
     `UpdateHitTestArea` (with or without the name, depending on `NamePlateSetupOptions.unitNameInsideHealthBar`).
  3. `ApplyPlateStackingBounds(tp_frame)`: Blizzard-shown plate → anchored to Blizzard's hit-test area (live).
     TP plate → size of that area (measured on the hidden `UnitFrame`, cached, fallback plate size), `CENTER` on
     `plate`. Then `plate:SetStackingBoundsFrame(frame)`.
  4. (Removed: "Stacking Width/Height" options.)
  5. Called at the start of `ApplyPlateHitTest`, *before* its `CanChangeHitTestPoints` early return, so it also
     runs in combat and at all of its call sites (`RefreshPlatePresentation`, `ApplyReactionUpdate`,
     `SetNamePlateClickThrough` → `SetBaseNamePlateSize`).
- **"Only names" (Retail, `nameplateShowOnlyNameForFriendlyPlayerUnits`, outside instances with Blizzard plates for
  friendly units)**: without TP, Blizzard still stacks those plates, only tighter than normal plates. With TP, the
  spacing stayed the same regardless of the CVar. A first fix (per-UnitFrame hook on `UpdateShowOnlyName`) was
  reverted as too complicated. Implemented instead:
  - `AnchorToBlizzardHitTestArea` anchors to the name only in "only name" mode (second return value `only_name`).
    TP plates never take their cached size from such a UnitFrame.
  - Live CVar toggle: `CVarsManager.lua` subscribes to `CVAR_UPDATE` (`CVAR_UPDATE_HANDLERS`, defined next to
    `MONITORED_CVARS`, + `CVarUpdateHook`) and calls
    `Addon.UpdateStackingBoundsOfAllPlates()` (all plates in `PlatesByUnit`, incl. Blizzard-shown ones). No double
    processing: the CVar is not in `MONITORED_CVARS`. Verified with a (since removed) debug trace: `CVAR_UPDATE` fires
    synchronously inside `C_CVar.SetCVar`, only on an actual value change, and after Blizzard's own handling.
  - Analysis: inside instances, friendly plates are *forbidden* plates (own pool and events
    `FORBIDDEN_NAME_PLATE_*`, not registered by TP), so TP never touches them. Outside instances, TP handles
    Blizzard-shown friendly plates via `NAME_PLATE_UNIT_ADDED` (stacking bounds and hit-test, see P10).
  - Verified in-game (Retail, 2026-09-26): "only names" stacks as tight as without TP, the live CVar toggle takes
    effect immediately (so Blizzard's `CVAR_UPDATE` handling does run first), and enemy TP plates are unaffected.
- **Code check "Blizzard-shown plates = Blizzard's spacing"** (2026-09-26) closed two gaps:
  - Plates ignored by TP (`IgnoreUnitForThreatPlates`: widget-only, personal) kept TP's stacking bounds from a
    previous unit on the pooled plate. `NAME_PLATE_UNIT_ADDED` now resets them via `ApplyPlateStackingBounds`
    (`Active` is false there).
  - `nameplateStyle` (name inside/above the healthbar) and `nameplateSize` changes only re-applied active TP plates.
    Both are now in `CVAR_UPDATE_HANDLERS` → `UpdateStackingBoundsOfAllPlates`.
  - Covered paths: ADDED/revalidation, `ApplyReactionUpdate`, `UNIT_FACTION("player")`, Blizzard/TP option toggle
    (`ForceUpdate` → `UpdatePlatesVisible`), live healthbar resizes (anchored), "only name" CVar (`CVAR_UPDATE`),
    forbidden plates in instances (never touched).
- **Review (2026-09-26)**:
  - Fixed: in an instance, right after combat, `GetSize` on the stacking frame (anchored to Blizzard's `UnitFrame`)
    returned secret numbers, so the `width > 0` comparison threw. The measurement is now guarded with
    `IsSecretValueTP` (the cache keeps the last valid size). Without a cached size, TP plates use
    `SetAllPoints(plate)` instead of reading `plate:GetWidth()`.
  - Fixed: the "only name" branch only applies where Blizzard clears the hit-test area (`unit_frame.UpdateHitTestArea`
    exists, Retail). Classic sets the same hit-test area in `ApplyFrameOptions` and keeps it in "only name" mode.
  - Removed the redundant `EnableMouse(false)` and the outdated "modern engine only" comment.
- **Verified in-game (Retail, 2026-09-26)**: TP plates and Blizzard-shown plates stack like with TP disabled,
  Overlap H/V works with TP on (both plate kinds), the "only names" load and live toggle work, `nameplateStyle`
  changes apply immediately, and instance incl. end of combat shows no errors (after the secret-size fix).
- **Still to test**: Classic Era with the current code (spacing TP on vs. off, Overlap still working, "only names"
  like without TP after the `UpdateHitTestArea` check), widget-only plates.
- **Related, for P10**: `ApplyPlateHitTest` makes Blizzard-shown "only name" plates clickable (Blizzard clears their
  hit-test area) and replaces Blizzard's exact hit-test area of normal Blizzard-shown plates with the whole plate.
- The temporary `/tptp stacking-test` command used for the tests above has been removed again.
- **Changelog**: covered by the shared 13.4.0 entry (the options bullet was removed together with the options).

### P8b (later): Stacking spacing that follows TP's own plate size

- **Idea**: with P8, TP plates always stack with Blizzard's hit-test area size, even if TP's healthbar is much larger
  or smaller. Instead, apply Blizzard's formula to TP's *own* elements: anchor the stacking frame to TP's name and
  healthbar (name top to healthbar bottom, ±10, half the healthbar height). Same TP size as Blizzard → same
  spacing, other sizes adapt automatically and live. Overlap keeps scaling on top.
- **Cases to cover** (collected 2026-09-25/26):
  - Healthbar size settings (friendly/enemy) and custom styles with their own healthbar size.
  - Headline View (name only): name bounds, analogous to Blizzard's "only name" mode.
  - Individual plate scaling (target/mouseover/threat scale, scale animations): should the stacking area of a
    scaled-up target plate grow with it? Anchoring into `TPFrame` does this automatically, but may make plates
    re-stack/jitter during scale animations (compare the cross-hierarchy anchoring issue noted in
    `ApplyPlateHitTest`). Alternative: size-based (like P8 now), updated from `ScalingModule` on scale changes.
  - Plate-level elements outside name/healthbar (castbar below, auras/widgets above): included or not?
- **Why not Overlap**: the Overlap CVars are global (they also change Blizzard-shown plates) and belong to the user.
- **Why not own "Stacking Width/Height" options**: tried in P8 and removed, since they duplicated Overlap.
- **Risks**: style-dependent layouts (name/healthbar hidden, Headline View, custom styles), jitter while scaling.
  Sizes read from frames anchored to Blizzard's frames can be secret, so prefer TP's own configured sizes over
  measuring where possible.

### Follow-ups collected during P1/P8 (not yet assigned)

- **Overlap option descriptions** (`Options.lua`, "Horizontal/Vertical Overlap"): mention that they scale the spacing
  of *stacked* nameplates and have no effect when stacking is off. New locale strings (new keys, keep the old
  translations until the next CurseForge sync).
- **Double processing of `nameplateSize`/`nameplateStyle`** (harmless): `CVAR_UPDATE` (inside `SetCVar`) and then
  `SetCVarHook` → `SetBaseNamePlateSize` both re-apply stacking for active TP plates, both after Blizzard's update.
  `SetCVarHook` is still needed for the hit-test. Could be simplified if P9/P10 move the hit-test update to
  `CVAR_UPDATE` as well.
- **Ignored plates on CVar changes**: `UpdateStackingBoundsOfAllPlates` iterates `PlatesByUnit`, which does not
  contain plates TP ignores (widget-only). They are anchored to Blizzard's elements and follow size changes live.
  Only a switch of the anchor variant (`nameplateStyle`: name inside/above the healthbar) stays stale until the
  plate is re-added.
- **Secret sizes audit**: TP reads sizes of its own frames in 9 places (`Elements/Healthbar.lua` absorbs,
  `Elements/Castbar.lua` spark, `Widgets/AurasWidget.lua` highlight, `Widgets/ComboPointsWidget.lua`,
  `Widgets/ThreatWidget.lua`, `Modules/Font.lua`). No errors so far (sizes set explicitly by TP), but check whether any
  of these frames can inherit a secret size from Blizzard frames. If so, guard with `IsSecretValueTP`.
- **"WoW Forever"**: P8 not tested with the current code (the method exists there and is real, checked in-game).
  Considered unnecessary for now.
- **Remove dead personal-nameplate code**: there is no `"player"` nameplate anymore on Retail or Classic Era
  (verified in-game 2026-10-30, see the P3 checks). TP code and options that only act on that plate can no longer
  have any effect:
  - The four filter locations in CLAUDE.md "Personal nameplate filtering" (`GetThreatPlateForUnit`,
    `IgnoreUnitForThreatPlates`, `FrameOnShow`, `FrameOnUpdate`).
  - The `PersonalNameplate.HideBuffs` option (`SettingsHideBuffsOnPersonalNameplate`, the personal-plate branch in
    `FrameOnShow`) and its option UI/locale strings.
  - The `nameplateResourceOnTarget` CVar handling (`PersonalNameplate.ShowResourceOnTarget`, `Addon.lua`,
    `CVarsManager.lua`, options).
  - Any remaining "personal nameplate" option texts and defaults (`Constants.lua`, `Database.lua`).
  Plan: remove the options and their handling (keep SavedVariables compatible, defaults may simply stay unused or be
  cleaned up with a profile migration if needed). For the `"player"` guards, decide per location. The cheap
  `unitid == "player"` / `UnitIsUnitTP` checks also protect against `"player"` reaching code paths through other
  unit tokens (e.g. target/mouseover being the player), so keep them where that is possible. Verify each removal
  against the current Blizzard source (`Blizzard_NamePlates`, `Blizzard_PersonalResourceDisplay`) on all flavors.
  Changelog bullet if options are removed (e.g. `Removed the options for the personal nameplate, which no longer
  exists in WoW.`).
- **Hit-test of Blizzard-shown plates** (whole plate instead of Blizzard's area, "only name" plates clickable) and
  re-binding blocked in combat: see P10.

### P6 (optional): Unregister Blizzard unit-frame events while TP handles the plate

- **Problem**: the hidden Blizzard `UnitFrame` keeps processing `UNIT_AURA`, health, cast and threat events.
  Plater and Platynator both switch them off.
- **Constraint**: events are only restored by Blizzard's `OnUnitSet` on the next `ADDED`. A mid-lifetime switch
  from TP to the Blizzard plate (reaction change in mixed mode, option toggle) would leave a dead Blizzard plate
  until the next `ADDED`. Calling `OnUnitSet` from addon code is not an option (taint).
- **Change**:
  1. Only enable when TP handles both reactions
     (`not SettingsShowFriendlyBlizzardNameplates and not SettingsShowEnemyBlizzardNameplates`). Otherwise do
     nothing.
  2. In `NAME_PLATE_UNIT_ADDED` (and revalidation) after `HandlePlateUnitAdded`, when `tp_frame.Active` and
     `not unit_frame:IsForbidden()`: `UnregisterAllEvents()` on `unit_frame`,
     `unit_frame.HealthBarsContainer.healthBar`, `unit_frame.castBar or unit_frame.CastBarsContainer.castBar`
     and `unit_frame.AurasFrame` (verify each against the current `Blizzard_NamePlateUnitFrame.lua`).
  3. On option change to "show Blizzard plates": print a hint that it applies to newly shown nameplates, or
     suggest `/reload`.
  4. Start behind a local constant. Promote to a (hidden) option only after testing.
- **Risk**: `ADDON_ACTION_BLOCKED` / taint on protected frames. Test in combat, in arenas and in encounters.
  Blizzard's WidgetContainer (reparented to TP) must keep working. Test widget plates.
- **Test**: CPU profiling (`/tptp` profiling or `debugprofilestop`) in a 20+ plate pull, with and without.
- **Changelog**: `Improved performance by disabling updates of hidden Blizzard nameplates.`

### L1: Hide Blizzard's plate through a hidden parent and drop the Show watchdog

- **Idea** (Platynator): `local HiddenParent = CreateFrame("Frame"); HiddenParent:Hide()`. In the Midnight
  branch of `SetShownBlizzardPlate`, `show=false` → `SetParent(HiddenParent)` (keep the anchors, so no
  `ClearAllPoints`), for protected and non-protected frames alike. `show=true` → `SetParent(plate)`.
  Blizzard's own `Show()`/animation calls then stay invisible, and only `AcquireUnitFrame` (every `ADDED`)
  re-parents, which TP already re-applies in `ADDED`.
- **Follow-up**: `BlizzardPlateOrigParent` is no longer needed (restore target is always the plate). The
  `hooksecurefunc(unit_frame, "Show")` watchdog and possibly the `OnShow` hook become obsolete. Remove them only
  after tests show that nothing else re-parents the frame (grep `SetParent` in `Blizzard_NamePlates*`).
- **Also**: remove the outdated `not Addon.ExpansionIsAtLeastMists and plate.UnitFrame` branch in
  `Addon:NAME_PLATE_CREATED` (all clients use the pooled driver, see "Verification results").
- **Depends on**: P1 (TPFrame must not depend on `UnitFrame`'s rect).
- **Test**: aggro flash, fade animations, BG/arena in continuous combat, mixed mode, `/reload` in combat.
- **Changelog**: `Fixed a bug where Blizzard's default nameplates sometimes showed up behind Threat Plates.`
  (only if observed)

### L2: Pre-allocation of TP frames (measure first)

- **Idea** (Platynator): build frames before they are needed (staggered, one per frame after `PLAYER_LOGIN`),
  and only re-parent at `NAME_PLATE_CREATED`.
- **Step 1, measurement**: `debugprofilestop()` around `HandlePlateCreated`. Log max/avg in a first pull with
  many new plates (in combat).
- **Step 2, only if spikes are relevant** (for example > 2 ms per plate): pool of pre-built `TPFrame`s,
  `SetParent(plate)` plus setting `tp_frame.Parent` on acquire.
- **Open issues**: frames are named `"ThreatPlatesFrame" .. GetNameForNameplate(plate)` (names cannot change;
  check external addons that use these names). Elements/widgets store `plate` references at creation.
- **Expected outcome**: probably dropped. TP's `CREATED` cost is one-time per plate and the pool is at most ~40.

### L3: `SetFlattensRenderLayers` / `SetCollapsesLayout` (measure first)

- **Idea** (Platynator `NameplateMixin:OnLoad`): fewer draw batches and no layout work for hidden children.
- **Checks**: method availability per flavor (guard with `if tp_frame.SetFlattensRenderLayers`). Flattening
  changes the draw order between child frames, so re-check against `Source/Docs/FrameLevelAnalysis.md`
  (castbar/auras/widgets over healthbar, text frame).
- **Test**: visual layering screenshots for all widget combinations, plus FPS/CPU comparison in large pulls.
- **Changelog**: `Improved rendering performance of nameplates.` (only if measurable)

### Hit-test findings (in-game, Retail, 2026-09-25)

Basis for P9/P10 (also recorded in CLAUDE.md, "Hit-test (clickable) area"):

| Test | Result |
| --- | --- |
| `HitTestFrame:SetSize(300,100)` in and out of combat, no re-bind | no effect, which was misleading at first; see the clamp below |
| `SetSize(300,100)` + `plate:SetAllHitTestPoints(HitTestFrame)` (`CanChangeHitTestPoints() == true`) | no effect beyond the old area (plate: 172.5 x 60.3) |
| `SetSize(30,6)` + re-bind | only the tiny area was clickable |
| `SetSize(plate - 4)` + re-bind | the whole area was clickable |
| `SetSize(30,6)` **in combat, no re-bind** | only the tiny area was clickable, so the area follows the frame live |
| `SetSize(30,6)` with the frame **hidden** (TP default), no re-bind | only the tiny area was clickable, so a hidden frame works |

Conclusions: the bound `HitTestFrame` can be resized at any time (also in combat). Re-binding is blocked in
combat except on the `ADDED` tick. The clickable area is clamped to `plate`'s bounds, and `C_NamePlate.SetNamePlateSize` is
no option (global, distorts Blizzard's plates, which also exist in pure TP mode).

### P10: Clamp the clickable area to the plate size and make the limit visible — IN PROGRESS (branch `feature/nameplate-clickable-area`)

- **Problem**: with a wide healthbar (or large manual click area), `HitTestFrame` exceeds `plate` and the clickable
  area is silently cut off. `ConfigClickableArea` shows an area that is partly not clickable.
- **Change**:
  1. `ApplyPlateHitTest` (and P9's resize helper): `width = min(width, plate:GetWidth())`,
     `height = min(height, plate:GetHeight())`. Size reads are allowed on restricted regions. Account for the scale
     difference once P9 gives `HitTestFrame` its own scale (compare in the same coordinate space: divide by the
     `HitTestFrame` scale).
  2. Options: extend the description of the clickable-area settings (`Options.lua`, `SyncWithHealthbar` and the
     width/height sliders) with a note that the area cannot exceed Blizzard's nameplate size, which is adjustable via
     Blizzard's "Nameplate Size" setting. Add the new string to `Locales/*.lua`.
  3. Re-apply when the native plate size changes. `CVarsManager`'s `RESYNC_NATIVE_SIZE_CVARS` path already calls
     `SetBaseNamePlateSize` (out of combat).
- **Test**: healthbar width 250 → click area = plate width, and `ConfigClickableArea` shows the clamped area. Change
  Blizzard's nameplate size and check that the clamp follows.
- **Also (found with P8, pre-existing since 13.3.0)**: for plates shown by Blizzard (not click-through),
  `ApplyPlateHitTest` binds the hit-test to `plate.UnitFrame`, i.e. the whole plate instead of Blizzard's exact area.
  In "only name" mode, it also overrides Blizzard's cleared hit-test, so friendly names become clickable. Option:
  bind to a frame anchored via `AnchorToBlizzardHitTestArea`, and in "only name" mode leave the hit-test alone.

- **Implemented so far** (branch `feature/nameplate-clickable-area`, created from `feature/nameplate-lifecycle` @
  `44425c72`):
  1. `ApplyPlateHitTest`: width/height of `HitTestFrame` are clamped to `plate:GetSize()`. Guarded with
     `IsSecretValueTP` (sizes of nameplate frames can be secret in restricted contexts), so no clamping then.
     `HitTestFrame` has no own scale yet, so both sizes are in the same coordinate space. Revisit with P9.
  2. Options: an always visible description at the top of the "Clickable Area" group (`GetDescriptionEntry`):
     `The clickable area cannot be larger than Blizzard's nameplate. Its size is set with Blizzard's nameplate size
     options.` (new key in `Locales/enUS.lua`; other locales via the CurseForge sync). A first version put the text
     into the tooltips of "Healthbar Sync" and the four sliders, which was hard to notice.
  3. Re-apply on native size changes: no change. `SetCVarHook` → `SetBaseNamePlateSize` →
     `SetNamePlateClickThrough` → `ApplyPlateHitTest` already runs for `RESYNC_NATIVE_SIZE_CVARS` (out of combat).
     Open question for the test: does `plate:GetSize()` already return the new size at that point (the CVar update
     is synchronous, the plate resize might only happen later)?
  4. New option "Blizzard Nameplate Size" (range 1-5, CVar `nameplateSize`) in the "Clickable Area" group. Layout:
     description, "Healthbar Sync", "Blizzard Nameplate Size", the four width/height sliders, then "Configuration
     Mode" on its own line (full width). The option's tooltip only describes the CVar and its effect on Blizzard's
     own plates; the clamp is explained by the group description (no overlap). Explicit `get = GetValueCVarNumber`, `set = SetValueCVar`, since
     the group's `get` reads the profile. Hidden if the client doesn't know the CVar (`CVarIsUnavailable`).
     `nameplateSize` added to `COMBAT_PROTECTED` (`CVarsManager.lua`), so a change in combat is applied after combat.
     The clickable area follows via `SetCVarHook` → `SetBaseNamePlateSize`. Two new locale strings. Changelog:
     `Added an option for the size of Blizzard's nameplates to the clickable area settings, as it limits the
     clickable area of nameplates.`
- **Still open in P10**: the "Also" item above (hit-test of Blizzard-shown plates: Blizzard's exact area instead of
  the whole plate, leave "only name" plates unclickable).
- Note: `localization_tool.py check` reports 7 keys missing from `Locales/enUS.lua` that came with `develop` (e.g.
  `Bottom Inset`, motion speed). Not part of P10; fix separately on `develop`.

### P9: Let the clickable area scale with `TPFrame` (target/mouseover/threat scale, custom styles)

- **Problem**: `ScalingModule` scales only `TPFrame`. `HitTestFrame` keeps the base size from `db.settings.frame`,
  so enlarged target plates and custom styles with other healthbar sizes keep the default click area. Blizzard's
  own plate scaling currently *does* affect `HitTestFrame` (a child of `plate` without `SetIgnoreParentScale`),
  unlike `TPFrame`.
- **Feasible in combat**: yes, the area follows the bound frame live (see "Hit-test findings").
- **Change**:
  1. `HitTestFrame:SetIgnoreParentScale(true)`, so it uses the same scale basis as `TPFrame` and Blizzard's plate
     scaling no longer affects it (consistent with `TPFrame`).
  2. Wherever `TPFrame:SetScale(...)` is applied (`Modules/Scaling.lua`: `ScalePlate`, scale animations), apply the
     same scale to `HitTestFrame`. Prefer `SetScale` over anchoring `HitTestFrame` to `TPFrame` (the existing comment
     in `ApplyPlateHitTest` warns about cross-hierarchy anchoring to a scaled frame).
  3. Size from the active style's healthbar (`UpdateNameplateStyle` in `Styles/Styles.lua`) when `SyncWithHealthbar`
     is on, instead of the reaction-based `db.settings.frame`. Keep the manual values when it is off. Headline View
     keeps the current behavior (decided 2026-09-25).
  4. Revisit `SetBaseNamePlateSize`'s "Big" division by `plate_scale`. With a shared scale basis it should become
     unnecessary.
  5. Clamp with P10.
- **Risk**: extra `UPDATE_MOUSEOVER_UNIT` / flicker at the plate edges during mouseover scale animations. Test
  explicitly (hover at the edge while the scale-up animation runs).
- **Test**: target scale > 1, so the click area grows with the plate (up to the clamp). Mouseover scale animation
  without flicker. Custom style with a different healthbar size. All of this in combat.

## 3. Test matrix (per item, as applicable)

| Scenario | Retail/Midnight | WoW Forever | Mists Classic | Classic Era / Anniversary / SoD |
| --- | --- | --- | --- | --- |
| Open world, many plates, zoning | x | x | x | x |
| BG / arena (solo shuffle) | x | | x | x |
| Raid/dungeon encounter (secret values) | x | x | | |
| Mixed mode (Blizzard friendly plates) | x | x | x | x |
| Headline view, Big/Normal size, mouseover scale | x | x | x | x |
| Personal resource display, widget-only plates | x | x | x | |
| Config mode plate | x | x | x | x |

Error console: BugSack/!BugGrabber, with no `ADDON_ACTION_BLOCKED`/`FORBIDDEN` entries.

## 4. Documentation / changelog

- CLAUDE.md: update the "Nameplate lifecycle" section (anchoring invariant after P1, revalidation timer slots after
  P2, missed-REMOVED recovery after P4, stacking bounds after P8, hidden parent after L1).
- `Nameplate.lua` comment block "How TP and Blizzard's own nameplate relate": rewrite after P1/L1.
- Changelog: **one shared entry for the whole plan** (decided 2026-09-25) in the 13.4.0 block (appended to `develop`'s existing 13.4.0 block after the rebase):
  `* Reworked how nameplates are added, removed, and anchored to make them more reliable, especially when
  Blizzard re-uses its internal nameplate frames for different units.` The per-item "Changelog" lines above are
  only wording suggestions and are not added separately. Adjust the shared entry if an item adds a clearly
  user-visible change of its own (e.g. P8 stacking, P6 performance) that deserves its own bullet.

## 5. Final verification before merge (open checks, kept up to date)

Checks that are still open for implemented items (committed, or marked "not committed yet"). Everything here must
pass (or be consciously waived) before the branch is merged. Add new entries as items are implemented, add the commit
hash once committed, and tick or remove them when done. "(old base)" marks checks that passed before the rebase onto
`develop` (2026-10-30) and are covered again by "Re-test after the rebase" under General.

**P7 — hook marker table** (`54969ccb`)
- [ ] OnShow/Show hooks attach exactly once per pooled `UnitFrame` instance (no duplicate hooks after long sessions;
      temporary debug counter or `/tptp debug`), Retail and Classic.

**P1 — anchoring to `plate`** (`db3241ed`)
- [x] Retail: plates at the same position as before, no errors (tested before the P1 commit) (old base).
- [x] Classic Era: re-anchoring 30+ live plates from `UnitFrame` to `plate` caused no visible change (A/B test
      before the change) (old base).
- [ ] Classic Anniversary / Mists: plates at the same position as before.
- [ ] Retail and Classic Era in detail: Nameplate size Normal/Big, Headline View, mouseover/target scaling, custom
      styles with offsets.
- [ ] Clickable area and click-through (friendly/enemy), mixed mode (Blizzard plates for friendly units), reaction
      change (duel, mind control).
- [ ] `ConfigClickableArea` and `/tptp clickable-area` show the expected areas.
- [ ] "WoW Forever" (optional, waived for now).

**P8 — stacking bounds** (`e8388865`)
- [x] Retail: TP and Blizzard-shown plates stack like with TP disabled, Overlap H/V works with TP on, "only names"
      on load and live toggle, `nameplateStyle` change, instance incl. end of combat (no secret-size error)
      (old base, re-test pending).
- [ ] Classic Era with the current code: spacing TP on vs. off (same camera/CVars), Overlap H/V still works with
      stacking on, "only names" like without TP (no name-only branch there, since `UpdateHitTestArea` is missing).
- [ ] Classic Anniversary / Mists: smoke test (stacking on/off, no errors).
- [ ] Widget-only plates (quest objects, vehicles) stack like with TP disabled, also after the plate showed a TP
      unit before (pooled plate reset). Same scenario as the P3 widget-only check, one test covers both.
- [ ] `CVAR_UPDATE` handlers on Classic: toggling `nameplateSize`/`nameplateStyle` causes no errors (CVars may not
      exist there; events for unknown CVars simply never fire).
- [ ] "WoW Forever" (optional, waived for now; the method exists there and is real).

**P2 — revalidation timers** (`685f9438`) — Retail and Classic Era
- [ ] Reaction/attackability changes still apply immediately outside PvP (duel start/end, mind control), i.e. the
      next-frame slot is not swallowed by a pending 0.5 s revalidation of the same unit (BG case: see "BG / arena").
- [ ] Entering the world / zoning with many plates (city, portal): no errors, plates correct.
- [ ] No errors when plates are removed while a revalidation is pending (fast zoning with loading screen, quickly
      leaving range while plates appear).
- [ ] Optional: fewer `HandlePlateUnitAdded` runs when entering the world or zoning (temporary counter for
      scheduled/dropped/replaced/run, removed again afterwards).
- [ ] Longer normal session: no new BugSack entries.

**P3 — hardened `NAME_PLATE_UNIT_REMOVED`** (`8f81e89a`) — Retail and Classic Era
- [x] ~~Personal resource display on/off~~: not applicable. There is no nameplate for `"player"` anymore (verified
      in-game 2026-10-30, `C_NamePlate.GetNamePlateForUnit("player")` is `nil` with `nameplateShowSelf` = 1 on Retail
      and Classic Era). Retail shows the personal resource display as its own frame (`PersonalResourceDisplayFrame`,
      parent `UIParent`, addon `Blizzard_PersonalResourceDisplay`). Classic doesn't load that addon at all
      (`AllowLoadGameType: mainline`).
- [x] Widget-only plates appear and disappear without errors (2026-10-30, rebased code).
- [x] Widget-only plates (quest objects with progress bars, Dornogal/Oribos objects, vehicles): Blizzard's widgets stay in the right place on TP plates and on other plates (no widget
      container "jumping" to another plate). Same scenario as the P8 widget-only check, one test covers both (2026-10-30).
- [x] Soft-interact objects (e.g. fishing bobber, mailbox): no errors when they appear/disappear (2026-10-30).

**P4 — missed `NAME_PLATE_UNIT_REMOVED`** (`b4383106`) — Retail and Classic Era
- [ ] Open world: units leaving range at the edge of view distance, stealth (rogue/druid), feign death, mind control:
      no errors, no plates left behind showing an old unit.
- [x] Changing your own faction/reaction (e.g. duel start/end, or anything that fires `UNIT_FACTION` for "player"):
      no errors, all plates update (2026-10-30).

**P5 — `UNIT_CLASSIFICATION_CHANGED`** (`44425c72`) — Retail and Classic Era
- [x] In-game event registration check on Retail: 0 mismatches, `UNIT_CLASSIFICATION_CHANGED` and `CVAR_UPDATE`
      register fine (2026-10-30).
- [ ] Same check on Classic Era, Anniversary, Mists.
- [ ] (Not easily testable, waive if no suitable unit is found.) A unit whose classification changes while its plate is visible (e.g. a rare that becomes normal, scripted
      encounter phases, units that turn elite): style, custom style trigger and classification icon update without
      leaving and re-entering range.
- [ ] No errors / no noticeable hitches when the event fires (it causes a full plate refresh).

**P10 — clamp clickable area** (committed, hash added with the next commit; branch `feature/nameplate-clickable-area`) — Retail and Classic Era
- [x] Healthbar width 250 (or manual click area larger than the plate): configuration mode shows the clamped area,
      and exactly that area is clickable (2026-11-01).
- [x] Change Blizzard's nameplate size: the clamp follows (configuration mode after the change) (2026-11-01).
- [x] Options: description at the top of the "Clickable Area" group, layout as described in P10 (2026-11-01).
- [ ] Instance/BG: no errors from secret plate sizes in `ApplyPlateHitTest`.
- [ ] "Blizzard Nameplate Size" option: shows the current value (also after changing it in Blizzard's options),
      changing it resizes Blizzard's plates and the clamp follows; in combat the change is applied after combat.
      Shown on Retail and Classic Era (both have the CVar).

**BG / arena (one PvP session covers checks from P1, P2, P3, P4 and P8)** — Retail and Classic Era
- [ ] P2: Stale name/health stays fixed ([Comment #8228, #8363, #8408, #8433]). Right after entering, enemy plates
      show the correct name and health, nothing frozen from the previous unit. Also check this in a raid.
- [ ] P2: Reaction/attackability changes apply immediately (e.g. BG flag carrier), i.e. the next-frame slot is not
      swallowed by the 0.5 s revalidation that every `NAME_PLATE_UNIT_ADDED` schedules in PvP instances.
- [ ] P1: no vanishing or misplaced plates (also in a raid).
- [ ] P3: many plates appearing/disappearing (incl. solo shuffle rounds): no errors, target/mouseover/focus
      highlights correct.
- [ ] P8: no errors from secret sizes (`ApplyPlateStackingBounds`), stacking stays correct.
- [ ] P4: no plates left behind after units vanish without a regular removal (stealth, death, leaving range,
      arena opponents between solo shuffle rounds).
- [ ] No `ADDON_ACTION_BLOCKED`/`ADDON_ACTION_FORBIDDEN` entries during the whole session.

**General**
- [ ] Re-test after the rebase onto `develop` (2026-10-30): all checks above that were ticked against the old base
      (e.g. P8 on Retail) once more against the rebased code, at least a smoke test on Retail and Classic Era.
- [ ] `luacheck . --config .luacheckrc.ci` clean, and no new warnings in `luacheck . --config .luacheckrc` for touched files.
- [ ] BugSack/!BugGrabber: no errors, no `ADDON_ACTION_BLOCKED`/`ADDON_ACTION_FORBIDDEN` entries over a longer
      session (open world, instance, BG) on Retail and Classic.
- [ ] No temporary test/debug code left (`/tptp stacking-test`, CVAR_UPDATE trace, `/run` helpers in code).
- [ ] Changelog: 13.4.0 block and `CHANGELOG.md` in sync, entries still accurate for all committed items.
- [ ] CLAUDE.md and this plan consistent with the final code (item statuses, verification results).
- [ ] Follow-ups (section "Follow-ups collected during P1/P8") reviewed: either assigned to an item or consciously
      deferred.

## 6. Before release: remove temporary debug code

Temporary diagnostics added during testing. They only print in unpackaged/source builds (`Addon.Logging.Debug`,
`Addon.DEBUG`), but must be removed before the branch is merged or released. Each is marked `TEMPORARY` in the code
(`grep -n "TEMPORARY" *.lua`).

- [ ] `Nameplate.lua`, `RemoveStalePlateForUnit` (P4): `Addon.Logging.Debug("Missed NAME_PLATE_UNIT_REMOVED caught up
      for", ...)`. Shows whether missed `REMOVED` events actually occur. Note the result in P4 before removing it.
