# Nameplate lifecycle: implementation plan

Branch: `feature/nameplate-lifecycle` (created from `release/13.3` @ `cc69d850`). Target version: 13.4.0.

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
    └─> P8 (stacking bounds; reuses the plate-anchored helper-frame pattern)
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

### P2: Deduplicate and cancel revalidation timers

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

### P3: Harden `NAME_PLATE_UNIT_REMOVED`

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

### P4: Recover from a missed `NAME_PLATE_UNIT_REMOVED`

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

### P5: Handle `UNIT_CLASSIFICATION_CHANGED`

- **Problem**: TP ignores it, so elite/rare/normal changes (e.g. rare timers, scripted encounter phases) keep
  the old style, custom style trigger and classification icon.
- **Change**:
  1. `Compatibility.lua` `WOW_EVENTS`: `UNIT_CLASSIFICATION_CHANGED = true` (verify existence per flavor
     with `wow-api` `get_event` and `/tptp debug Compatibility`, and gate if necessary).
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
- **Test**: rare that turns elite/normal, target dummy with changing classification, `/tptp debug Compatibility`
  on all flavors.
- **Changelog**: `Fixed a bug where nameplates did not update their style when a unit's classification (e.g.
  elite or rare) changed.`

### P8: Use `SetStackingBoundsFrame` (Midnight API)

- **Problem**: Blizzard stacks TP plates using its default bounds, not TP's actual plate size. Plater and
  Platynator both provide a stacking frame.
- **Change**:
  1. `HandlePlateCreated`: `tp_frame.StackingBoundsFrame = CreateFrame("Frame", nil, plate)`, anchored
     `CENTER` to `plate` (same pattern and same scale reasoning as `HitTestFrame`).
  2. New `ApplyPlateStackingBounds(tp_frame)`, called from `RefreshPlatePresentation` and wherever
     `ApplyPlateHitTest` is called for size changes (`SetNamePlateClickThrough` / `SetBaseNamePlateSize`):
     guard `if not plate.SetStackingBoundsFrame then return end`. If `tp_frame.Active`, size it from the
     per-reaction healthbar size (or `db.settings.frame` as a first iteration) and call
     `plate:SetStackingBoundsFrame(frame)`. Otherwise restore Blizzard's bounds (check the API docs for
     `nil`/`UnitFrame` as argument).
  3. Check the combat-restriction behavior (like `CanChangeHitTestPoints` for hit tests) in
     `FrameAPINamePlateDocumentation.lua`.
  4. Optional follow-up: a separate stacking size setting, since stacking area ≠ click area.
- **Test**: stacking on/off (`nameplateStackingTypes`), dense packs, different healthbar sizes friendly/enemy,
  Headline View, mixed Blizzard plates.
- **Changelog**: `Changed stacking of nameplates to use the actual size of Threat Plates' nameplates.`

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

### P10: Clamp the clickable area to the plate size and make the limit visible

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
- Changelog: **one shared entry for the whole plan** (decided 2026-09-25) in the 13.4.0 block:
  `* Reworked how nameplates are added, removed, and anchored to make them more reliable, especially when
  Blizzard re-uses its internal nameplate frames for different units.` The per-item "Changelog" lines above are
  only wording suggestions and are not added separately. Adjust the shared entry if an item adds a clearly
  user-visible change of its own (e.g. P8 stacking, P6 performance) that deserves its own bullet.
