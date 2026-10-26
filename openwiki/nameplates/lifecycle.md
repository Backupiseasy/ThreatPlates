---
type: subsystem
title: Nameplate lifecycle
description: What Nameplate.lua does from NAME_PLATE_CREATED through NAME_PLATE_UNIT_ADDED and NAME_PLATE_UNIT_REMOVED - the tp_frame and unit data model, plate registries, the Active flag, unit data refresh and revalidation, hiding and anchoring against Blizzard's pooled frames, and the click area.
tags: [nameplate, lifecycle, unit-data, pooling, blizzard-nameplates, hit-test]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-25T18:59:51.751Z
sources:
  - id: openwiki-source-014010f28568c5a3c3664449
    resource: repo://Addon.lua
  - id: openwiki-source-7a3e837cfb6d3795c0c95431
    resource: repo://Nameplate.lua
  - id: openwiki-source-6794fbfa2ece0a99802c941d
    resource: repo://Widgets/WidgetHandler.lua
generated: { by: "claude-code", at: "2026-10-25T18:59:51.751Z" }
---

# Nameplate lifecycle

`Nameplate.lua` is the core of the addon. It owns the nameplate frames, reads unit data from the WoW API into
a per-plate table, and decides whether Threat Plates or Blizzard's own nameplate is shown for a unit.

## Data model

For every Blizzard nameplate frame (`plate`, e.g. `NamePlate3`) Threat Plates creates one child frame
`plate.TPFrame`, called `tp_frame` in the code:

| Field | Content |
| --- | --- |
| `tp_frame.Parent` | the Blizzard `plate` |
| `tp_frame.unit` | unit data: `unitid`, `guid`, `name`, `basename`, `type` (`PLAYER`/`NPC`), `class`, `reaction`, `level`, `health`, `healthmax`, `classification`, `isBoss/isElite/isRare`, target/focus/mouseover flags, casting state, raid marker, threat, style name, custom style data, ... |
| `tp_frame.visual` | frames of the Elements (`Healthbar`, `NameText`, `Castbar`, ...) |
| `tp_frame.widgets` | widget frames by widget name (see [Widget framework](../widgets/framework.md)) |
| `tp_frame.style`, `stylename`, `PlateStyle` | current style table, its name and mode (`HealthbarMode`, `NameMode`, `None`) |
| `tp_frame.Active` | Threat Plates is responsible for and shows this plate |
| `tp_frame.HitTestFrame` | invisible frame defining the clickable area |

Widget frames keep a reference to the same `unit` table (`widget_frame.unit = tp_frame.unit`), so the unit
table's identity must survive the lifetime of the plate. `NAME_PLATE_UNIT_REMOVED` therefore clears it in place
with `wipe` instead of assigning a new table.

### Registries

- `Addon.PlatesCreated[plate] = tp_frame` - every plate ever created (plates are pooled and reused).
- `Addon.PlatesByUnit[unitid] = tp_frame` - plates with a unit, keyed by `nameplateN` token.
- `Addon.PlatesByGUID[guid] = plate` - only written for non-secret GUIDs; only cleared on unit removal on
  clients without `HAS_MIDNIGHT_API`.
- `PlatesByMetaUnit` (file-local) - plates for `target`, `focus`, `mouseover` and the soft targets, see
  [Target, soft target, mouseover and focus](targets-mouseover-focus.md).

Accessors: `Addon:GetThreatPlateForUnit(unitid)` (resolves meta tokens through `C_NamePlate.GetNamePlateForUnit`,
`nameplateN` tokens through `PlatesByUnit`, and only returns active plates that are not the player),
`GetThreatPlateForTarget`, `GetThreatPlateForFocus`, `GetThreatPlateForGUID`, and the iterator
`Addon:GetActiveThreatPlates()` over active plates in `PlatesByUnit`.

### The `Active` flag

`tp_frame.Active` is set by `ShowBlizzardNameplate`: `true` when Threat Plates is shown, `false` when Blizzard's
plate should be shown for this reaction (the "Show Blizzard Nameplates" settings for friendly/enemy units) and on
`NAME_PLATE_UNIT_REMOVED`.

- `Active == true` implies the unit table is filled (`unit.unitid ~= nil`).
- The reverse does not hold: a plate in `PlatesByUnit` can have unit data but be inactive because Blizzard's
  plate is shown for it.
- Code that reads `unit.unitid` outside the unit-added path must check `Active` first (the accessors above
  do).

## `NAME_PLATE_CREATED`

`HandlePlateCreated(plate)` creates `tp_frame` (named `ThreatPlatesFrame<plate name>`) with mouse disabled,
`HitTestFrame` (parented to `plate`, not `tp_frame`, so it does not inherit Threat Plates' scale), frame strata,
`SetIgnoreParentAlpha/Scale(true)` (plate alpha and scale are neutralized; Threat Plates computes its own),
`tp_frame.GetAnchor` for other addons (e.g. BigDebuffs), a `textframe`, then all Elements
(`ElementsPlateCreated`) and enabled Widgets (`Widgets:OnPlateCreated`). The plate's `OnHide` hides `tp_frame`;
its `OnUpdate` keeps the frame level, applies occlusion transparency and re-anchors Blizzard's widget container.

## `NAME_PLATE_UNIT_ADDED`

`Addon:NAME_PLATE_UNIT_ADDED(unitid)` skips units for which `IgnoreUnitForThreatPlates` is true: the player,
widget-only nameplates (`UnitNameplateShowsWidgetsOnly`) and game objects (fishing bobbers and other
soft-interact objects, left completely to Blizzard). For all others:

1. `HandlePlateUnitAdded(plate, unitid)`:
   - `RefreshUnitData` - `SetUnitAttributes` reads all unit data (`unitid`, GUID, classification, type/class,
     NPC id pre-Midnight, reaction, level, name, health, cast flags reset, target/focus/mouseover flags, raid
     marker), registers the plate in `PlatesByUnit`/`PlatesByGUID`, and sets the threat attributes.
   - `UpdateTargetMetaUnitReferences` - points `target`/soft-target entries of `PlatesByMetaUnit` at this plate.
   - `RefreshPlatePresentation` - `SetNameplateVisibility` (sets `Active`), `SetNamePlateSimplified(unitid,
     false)`, `ApplyPlateHitTest`, Blizzard widget container, `StyleModule.PlateUnitAdded` (chooses and applies
     the style, see [Styles](../rendering/styles.md)), `ElementsPlateUnitAdded`, `RefreshCastbar`.
2. `NamePlateDriverFrame_AcquireUnitFrame(nil, plate)` - anchors and hooks the Blizzard unit frame (below).
3. Schedule a revalidation (below) if the unit token was already in `PlatesByUnit` without a removal in between
   or the player is in a PvP instance (0.5 s), or if `plate.UnitFrame` does not exist yet (next frame).

## `NAME_PLATE_UNIT_REMOVED`

Order matters - derived state is cleared before the unit data:

1. If this plate is the mouseover plate, `RemoveMouseoverFromNameplate()` (publishes `MouseoverOnLeave` while
   the style is still valid).
2. `UpdateTargetMetaUnitReferences(tp_frame, nil)` - drop target/soft-target references to this plate.
3. `Active = false`, remove from `PlatesByUnit` (and `PlatesByGUID` pre-Midnight).
4. `Widgets:OnUnitRemoved` - deactivate widget frames.
5. Restore Blizzard's widget container, `wipe(tp_frame.unit)`, `tp_frame.stylename = nil` (so the next unit
   is always restyled).

Game events can arrive between two handlers (e.g. `UNIT_FACTION` between `REMOVED` and `ADDED` in solo shuffle,
`UPDATE_MOUSEOVER_UNIT` while a plate is recycled). Clearing references first is what keeps those handlers from
reading a wiped unit table; this ordering fixed a crash in `Transparency.lua:GetTransparency`.

## Unit data updates

Unit events go to `Addon` as main subscriber, skip `IGNORED_UNITS` (meta tokens like `target`; their plate gets
the event through its `nameplateN` token), and update the matching field:

| Event | Update |
| --- | --- |
| `UNIT_NAME_UPDATE` | name, then `StyleModule.UpdateName` (name triggers) |
| `UNIT_HEALTH` / `UNIT_HEALTH_FREQUENT` | health, then `StyleModule.Update` |
| `UNIT_MAXHEALTH` | health |
| `UNIT_LEVEL` | level and level color |
| `UNIT_THREAT_LIST_UPDATE`, `UNIT_THREAT_SITUATION_UPDATE` | `ThreatModule.Update` |
| `UNIT_FACTION` | `ApplyReactionUpdate` + revalidation; for `"player"` all plates |
| `UNIT_FLAGS` | `ApplyReactionUpdate` + revalidation, only if reaction or attackability changed or the plate is not active |
| `RAID_TARGET_UPDATE` | raid markers of all active plates, `TargetMarkerUpdate` |

`ApplyReactionUpdate` re-decides visibility (the unit may switch between Threat Plates and Blizzard plates),
re-reads the reaction, re-applies the click area, updates the style and publishes `FactionUpdate`. `UNIT_FACTION`
deliberately uses `PlatesByUnit` instead of `GetThreatPlateForUnit`, because the plate may not be active yet.

## Stale data and revalidation

WoW can reassign a plate's unit token to a different unit without a `NAME_PLATE_UNIT_REMOVED`, and
`UNIT_FACTION`/`UNIT_FLAGS` can fire before the client has the server's new name, health or GUID for the token.
Symptom: a plate shows the previous unit's name or a frozen health bar (reported in battlegrounds, arenas,
raids). `ScheduleNameplateRevalidation(plate, unitid, delay)` re-runs `HandlePlateUnitAdded` and the unit frame
anchoring after `delay` (0 = next frame), but only if the plate still belongs to that token
(`PlatesByUnit[unitid] == tp_frame and tp_frame.unit.unitid == unitid`).

A revalidation resets cast and interrupt state like a new unit would; see
[Castbar and interrupts](castbar.md). Settings changes use `RefreshPlatePresentation` alone
(`Addon:UpdatePlatesVisible`, `Addon:ForceUpdateOnNameplate`), because the unit data did not change.

## Blizzard's nameplate: hiding, anchoring, pooling

Threat Plates never removes Blizzard's `plate.UnitFrame`. Exactly one of the two is visible per plate.

**Anchoring** - `NamePlateDriverFrame_AcquireUnitFrame` is hooked onto Blizzard's
`NamePlateDriverFrame:AcquireUnitFrame` in `PLAYER_LOGIN` (before Mists Classic it is called directly in
`NAME_PLATE_CREATED`). It anchors `tp_frame` with `SetPoint("CENTER", unit_frame, "CENTER")` on **every**
acquire. On Mists Classic and the modern engine Blizzard pools unit frames: each `NAME_PLATE_UNIT_ADDED` can give
the plate a different instance, and `ReleaseUnitFrame` sets `plate.UnitFrame = nil`. Anchoring only on first
sight left `tp_frame` attached to a frame now used by another plate (plate drawn over another unit, then
vanishing - a regression fixed in 13.3.0). Blizzard's hook runs before `plate.UnitFrame` is assigned, hence the
manual second call from `NAME_PLATE_UNIT_ADDED` and the revalidation.

**Hooks** - the first time a unit frame is seen it is flagged (`unit_frame.ThreatPlates = true`) and gets
`HookScript("OnShow", FrameOnShow)`; on `HAS_MIDNIGHT_API` clients also `hooksecurefunc(unit_frame, "Show",
...)`. Both re-apply the show/hide decision when Blizzard's code shows its plate again (aggro flash, fade
animations, pooling).

**Hiding** (`SetShownBlizzardPlate`, `HAS_MIDNIGHT_API` only; other clients use `SetShown`):

- show: restore a saved parent and anchor, `Show()` only if not shown (the `Show` hook would recurse
  otherwise), `SetAlpha(1)`;
- hide a protected frame: save the parent in the weak table `BlizzardPlateOrigParent`, then `ClearAllPoints()` +
  `SetParent(nil)` - Blizzard's secure code would silently revert `Hide()`/`SetAlpha(0)` on a protected frame;
- hide otherwise: `Hide()`.

The saved parent is discarded on every acquire, because a pooled frame may now belong to another plate. Anything
anchored to `UnitFrame` loses its position while it is reparented, so anchor new frames to `plate` instead.

## Click area

`ApplyPlateHitTest(tp_frame)` sets the plate's hit-test region with the per-plate C++ API (works in combat;
skipped when `plate:CanChangeHitTestPoints()` is false):

- click-through enabled for the unit's reaction -> `ClearAllHitTestPoints()`;
- Blizzard plate shown -> Blizzard's unit frame bounds;
- otherwise `HitTestFrame`, sized from `settings.frame.width/height` (or the friendly values) and anchored to
  `plate.UnitFrame` - not to the scaled `tp_frame`, which made WoW re-evaluate the bounds on every `SetScale` and
  fire spurious `UPDATE_MOUSEOVER_UNIT` events.

`Addon:SetBaseNamePlateSize()` (`Addon.lua`) derives the frame size from the healthbar size when "sync with
healthbar" is on, then calls `Addon.SetNamePlateClickThrough()` for all active plates. `C_NamePlate.SetNamePlateSize`
is not used. `Addon:ConfigClickableArea` draws the area on the target's plate for configuration.

## Personal nameplate

The player's own nameplate is filtered in four places that must stay consistent: `GetThreatPlateForUnit`
(`unitid == "player"` and `Addon.UnitIsUnit("player", unitid)`), `IgnoreUnitForThreatPlates` (unit added and
`FrameOnShow`) and `FrameOnUpdate`. On current clients the personal resource display is a separate frame, so
`C_NamePlate.GetNamePlateForUnit("player")` returns `nil`.
