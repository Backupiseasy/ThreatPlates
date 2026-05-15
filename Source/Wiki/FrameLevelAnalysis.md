# Frame Level Analysis — TidyPlates_ThreatPlates

**Date:** 2026-05-12  
**Branch:** `feature/1205`

---

## Fundamentals

- **N** = `plate:GetFrameLevel()` (Blizzard nameplate frame level, varies per nameplate)
- **tp_frame** = ThreatPlates overlay, parent = `WorldFrame`, level = N (synchronized via `OnUpdate`)
- **HbOCb** = `HealthbarOverCastbar` (default)
- **CbOHb** = `CastbarOverHealthbar`
- Draw layer order within a frame (bottom → top): `BACKGROUND < BORDER < ARTWORK < OVERLAY < HIGHLIGHT`
- Sublevel within a draw layer: lower number = further back

---

## Frames — Level Overview

### Core Frames

| Frame | HbOCb | CbOHb | Creation Level | Source |
|---|---|---|---|---|
| `tp_frame` | N | N | N | `Nameplate.lua` OnUpdate |
| `HitTestFrame` *(Midnight)* | N | N | N (inherited) | `Nameplate.lua` |
| `ThreatGlow` | **N+4** | **N+3** | N+0 ⚠ | `Healthbar.lua` UpdateStyle: frame_level−1 |
| `textframe` | **N+5** | **N+4** | N+0 (inherited) | `Healthbar.lua` UpdateStyle: frame_level |

### Healthbar Group

| Frame | HbOCb | CbOHb | Creation Level | Source |
|---|---|---|---|---|
| `healthbar` | **N+5** | **N+4** | N+5 | `Healthbar.lua` UpdateStyle |
| `healthbar.Border` | N+4 | N+3 | N+5 ⚠ | `Healthbar.lua` UpdateStyle: frame_level−1 |
| `EliteBorder` | N+5 | N+4 | N+6 ⚠ | `Classification.lua` PlateCreated; `Healthbar.lua` UpdateStyle: frame_level |
| `healthbar.Highlight` | **N+5** | **N+5** | N+5 | `MouseoverHighlight.lua`; ⚠ not updated by UpdateStyle |

### Castbar Group

| Frame | HbOCb | CbOHb | Creation Level | Source |
|---|---|---|---|---|
| `castbar` | **N+2** | **N+5** | N+0 (inherited) | `Castbar.lua` UpdateStyle |
| `castbar.Border` | N+2 | N+5 | N+0 (inherited) | `Castbar.lua` UpdateStyle: castbar:GetFrameLevel() |
| `castbar.InterruptBorder` | N+2 | N+5 | N+0 (inherited) | `Castbar.lua`; SetFrameLevel commented out → inherits castbar |
| `castbar.Overlay` | N+2 | N+5 | N+0 (inherited) | `Castbar.lua`; SetFrameLevel commented out → inherits castbar |

### Widgets

| Widget Frame | Level HbOCb | Level CbOHb | Source |
|---|---|---|---|
| `AurasWidget.widget_frame` | **N+1** | **N+9** | `AurasWidget.lua` UpdateLayout |
| `AurasWidget.Buffs / Debuffs / CrowdControl` | = widget_frame | = widget_frame | `UpdateAuraGridLayout` |
| Aura icon/bar frames (incl. Border, Highlight, text_frame) | = widget_frame | = widget_frame | SetFrameLevel(aura_grid_frame:GetFrameLevel()) |
| `ArenaWidget.widget_frame` | N+7 | N+7 | |
| `BossModsWidget.widget_frame` | **N+0** | **N+0** | ⚠ Same level as tp_frame |
| `BossModsWidget.icon_frame` | N+0 | N+0 | = widget_frame |
| `BossModsWidget.icon_frame.Highlight` | **N+15** | **N+15** | ⚠ Extreme jump from N+0 |
| `ClassIconWidget.widget_frame` | N+7 | N+7 | |
| `ComboPointsWidget.widget_frame` | N+7 | N+7 | |
| `HealerTrackerWidget.frame` | N+7 | N+7 | |
| `QuestWidget.widget_frame` | N+7 | N+7 | |
| `ResourceWidget.widget_frame` | N+8 | N+8 | |
| `ResourceWidget.statusbar` | N+8 | N+8 | = widget_frame:GetFrameLevel() |
| `ResourceWidget.statusbar.Border` | N+8 | N+8 | ⚠ Same level as statusbar (≠ healthbar.Border pattern) |
| `ScriptWidget.widget_frame` | **N+0** | **N+0** | ⚠ Same level as tp_frame |
| `SocialWidget.widget_frame` | N+7 | N+7 | |
| `StealthWidget.widget_frame` | N+9 | N+9 | |
| `ThreatWidget.widget_frame` | N+7 | N+7 | |
| `TotemIconWidget.widget_frame` | N+7 | N+7 | |
| `UniqueIconWidget.widget_frame` | N+14 | N+14 | |
| `UniqueIconWidget.Highlight` | N+15 | N+15 | |

---

## Textures — Overview (relative to parent frame)

Textures within a frame are stacked by draw layer and sublevel, independent of frame level.

### `healthbar` — Textures

| Texture | Draw Layer | Sub | Notes |
|---|---|---|---|
| `healthbar.Background` | ARTWORK | 0 | Bar background (the area to the right of the fill) |
| StatusBar fill (internal) | ARTWORK | 0 | Actual fill of the StatusBar |
| `healthbar.Absorbs` | ARTWORK | 2 | Absorb bar |
| `healthbar.HealAbsorb` | ARTWORK | 2 | Heal absorb bar (black) |
| `healthbar.Absorbs.Overlay` | ARTWORK | 3 | Striped overlay on absorb |
| `healthbar.HealAbsorbLeftShadow` | ARTWORK | 3 | |
| `healthbar.HealAbsorbRightShadow` | ARTWORK | 3 | |
| `healthbar.Absorbs.Spark` | ARTWORK | 4 | Over-absorb spark |
| `healthbar.HealAbsorbGlow` | ARTWORK | 4 | Over-absorb glow |
| `LevelText` | ARTWORK | 0 | FontString (`Level.lua`) |
| `healthbar.TargetUnit` | OVERLAY | 0 | FontString; above all ARTWORK textures |
| `elite_icon` | OVERLAY | 1 | `Classification.lua` |
| `skull_icon` | OVERLAY | 2 | `Classification.lua` |

### `healthbar.Highlight` — Textures

| Texture | Draw Layer | Sub | Notes |
|---|---|---|---|
| `HighlightTexture` | ARTWORK | 0 | `MouseoverHighlight.lua` |

### `castbar` — Textures

| Texture | Draw Layer | Sub | Notes |
|---|---|---|---|
| `castbar.Background` | ARTWORK | 0 | |
| StatusBar fill (internal) | ARTWORK | 0 | |
| `castbar.Spark` | ARTWORK | 1 | Cast spark |
| `castbar.CastTarget` | ARTWORK | 0 | FontString (name of the cast target) |
| `SpellIcon` | OVERLAY | 7 | `SpellIcon.lua`; highest sublevel on castbar |

### `castbar.Overlay` — Textures

| Texture | Draw Layer | Sub | Notes |
|---|---|---|---|
| `spell_text` (SpellText) | ARTWORK | 0 | FontString |
| `castbar.CastTime` | ARTWORK | 0 | FontString |
| `castbar.InterruptOverlay` | ARTWORK | 2 | |
| `castbar.InterruptShield` | OVERLAY | 0 | Above all ARTWORK on Overlay frame |

### `textframe` — Textures

| Texture | Draw Layer | Sub | Notes |
|---|---|---|---|
| `NameText` | ARTWORK | 0 | FontString (`Name.lua`) |
| `StatusText` | ARTWORK | 0 | FontString (`StatusText.lua`) |
| `TargetMarker` | OVERLAY | 7 | `TargetMarker.lua` |

### `BossModsWidget.icon_frame` — Textures

| Texture | Draw Layer | Sub | Notes |
|---|---|---|---|
| `Icon` | BORDER | 0 | |
| `Time` | OVERLAY | 0 | FontString |
| `Label` | OVERLAY | 0 | FontString |

---

## Inconsistencies and Issues

### [I-1] `healthbar.Highlight` not updated by UpdateStyle — BUG CANDIDATE

**Problem:** `healthbar.Highlight` is created in `MouseoverHighlight.lua` (`PlateCreated`) using `healthbar:GetFrameLevel()`. At that point the healthbar is at its initial level (N+5, set in `PlateCreated`). `UpdateStyle` sets the healthbar to **N+4** in **CbOHb** mode, but the Highlight frame stays at **N+5** — placing it **1 level above** the healthbar. In HbOCb mode both are at N+5 (same level, not above).

**Impact:** In CbOHb mode the mouseover Highlight frame is at a different level than the healthbar. Subtle, since the highlight is visually on the healthbar (same `SetAllPoints`), but any frames positioned between N+4 and N+5 could be inadvertently covered by the Highlight.

**Suggested fix:** Add the following to `Healthbar.lua` `UpdateStyle` after `healthbar:SetFrameLevel(frame_level)`:
```lua
if healthbar.Highlight then
  healthbar.Highlight:SetFrameLevel(frame_level)
end
```

---

### [I-2] `EliteBorder` creation level ≠ runtime level

**Problem:** `Classification.lua` creates `EliteBorder` with `healthbar:GetFrameLevel() + 1` = N+6 (at `PlateCreated` time). `UpdateStyle` then sets it to `frame_level` = N+5 (HbOCb) or N+4 (CbOHb). Before the very first `UpdateStyle` call the level is wrong.

**Impact:** No practical visual problem since `UpdateStyle` always runs before the frame becomes visible. The code is misleading nonetheless.

**Suggested fix:** Create `EliteBorder` in `Classification.lua` with `healthbar:GetFrameLevel()` (without +1).

---

### [I-3] `ThreatGlow` creation level ≠ runtime level

**Problem:** `ThreatGlow.lua` creates `ThreatGlow` with `tp_frame:GetFrameLevel()` = N+0. `UpdateStyle` sets it to `frame_level - 1` = N+4 (HbOCb) / N+3 (CbOHb).

**Impact:** Same pattern as I-2 — no real visual problem, but inconsistent creation.

---

### [I-4] Two different border level patterns

**Problem:** Two incompatible conventions exist for frame borders:

| Location | Pattern | Result |
|---|---|---|
| `healthbar.Border` | `SetFrameLevel(frame_level - 1)` | Border **behind** the bar |
| `Addon.CreateStatusbar` (ResourceWidget) | `SetFrameLevel(statusbar:GetFrameLevel())` | Border at the **same level** as the bar |

**Impact:** No runtime bug since the border backdrop color renders correctly in both cases. Can cause confusion when creating new StatusBars by analogy with either variant.

---

### [I-5] `BossModsWidget` and `ScriptWidget` at N+0 — Design issue

**Problem:** Both widget frames are set to `tp_frame:GetFrameLevel()` = N+0 — the same level as `tp_frame` itself. They are covered by all other frames (ThreatGlow N+3/4, healthbar N+4/5, castbar N+2/5, etc.).

**Impact:** Visibility of these widgets depends entirely on them being positioned outside the healthbar's screen area. Functionally correct, but fragile. `BossModsWidget.icon_frame.Highlight` then jumps from N+0 to **N+15** — consistent with `UniqueIconWidget.Highlight` (N+15), but the contrast with the widget frame level (N+0) is striking.

---

### [I-6] `textframe` and `healthbar` at the same frame level in HbOCb

**Problem:** In HbOCb: `healthbar` = N+5, `textframe` = N+5 (identical). The ARTWORK FontStrings on `textframe` (`NameText`, `StatusText`) compete within the same draw layer with ARTWORK textures on `healthbar` (`Background`, `Absorbs`, etc.).

**Impact:** The render order of two ARTWORK contents on different frames at the same frame level is determined by frame creation order (later-created frames render on top). Since `textframe` and `healthbar` do not spatially overlap in the default layout (textframe is typically positioned above or below the healthbar), there is no visual problem — but the setup is fragile with unusual layout configurations.

---

## Visual Stack Order (HbOCb, bottom to top)

```
N+0   tp_frame, HitTestFrame, BossModsWidget, ScriptWidget
N+1   AurasWidget (HbOCb)
N+2   castbar, castbar.Border, castbar.InterruptBorder, castbar.Overlay
N+3   (empty)
N+4   healthbar.Border, ThreatGlow
N+5   healthbar, textframe, EliteBorder, healthbar.Highlight (*)
        └─ ARTWORK:  Background, Fill, Absorbs (sub 2-4), HealAbsorb (sub 2-4)
        └─ OVERLAY:  TargetUnit, elite_icon (sub 1), skull_icon (sub 2)
        └─ textframe ARTWORK: NameText, StatusText
        └─ textframe OVERLAY: TargetMarker (sub 7)
        └─ castbar OVERLAY: SpellIcon (sub 7)
N+7   Arena, ClassIcon, ComboPoints, HealerTracker, Quest, Social, Threat, Totem
N+8   ResourceWidget
N+9   StealthWidget, AurasWidget (CbOHb)
N+14  UniqueIconWidget
N+15  UniqueIconWidget.Highlight, BossModsWidget.icon_frame.Highlight
```

(*) `healthbar.Highlight` stays at N+5 in CbOHb, placing it 1 level above the healthbar (N+4) — see [I-1].
