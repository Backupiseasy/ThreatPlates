---
type: subsystem
title: Elements
description: The always-present building blocks of a Threat Plates nameplate - how ElementHandler registers and drives them, the lifecycle hooks, and what each element (healthbar with absorbs, name, status text, castbar, level, classification, threat glow, raid marker, mouseover highlight) does.
tags: [elements, healthbar, absorbs, name, status-text, rendering]
sources:
  - id: openwiki-source-2b32510fb51ea7529fa5de93
    resource: repo://Elements/ElementHandler.lua
  - id: openwiki-source-2e898f0a8b59a083a80489b8
    resource: repo://Elements/Elements.xml
  - id: openwiki-source-3babb7e0272ba771750c1b2a
    resource: repo://Elements/Healthbar.lua
  - id: openwiki-source-b1cb8a5620a81f24d8fcc027
    resource: repo://Elements/Name.lua
  - id: openwiki-source-0617b26052092dfd264ac34f
    resource: repo://Elements/Statusbar.lua
  - id: openwiki-source-9f941e2d61eb287b4d62d04d
    resource: repo://Elements/StatusText.lua
  - id: openwiki-source-f05fe1718262283b50e8ba34
    resource: repo://Elements/ThreatGlow.lua
  - id: openwiki-source-74b884af48fed2a7832905b5
    resource: repo://Widgets/ExperienceWidget.lua
  - id: openwiki-source-e7384fc6a84ab77ee3ed1921
    resource: repo://Widgets/ScriptWidget.lua
generated: { by: "claude-code", at: "2026-10-28T19:52:11.033Z" }
verified:
  - by: openwiki/0.7.2
    at: 2026-10-28T19:52:11.033Z
---

# Elements

Elements are the parts every Threat Plates nameplate has, whether they are visible or not. They differ from
[Widgets](../widgets/framework.md): an element's frames are always created in `NAME_PLATE_CREATED`, elements
are not enabled/disabled as a whole, and they are hidden through their style instead.

## ElementHandler

`Elements/ElementHandler.lua` defines `Addon.Elements`:

- `Addon.Elements.NewElement(name)` returns a new element table `{ Name = name }`, appends it to
  `ElementsPriority` and stores it in `Elements[name]`. Registration order = load order in `Elements.xml` =
  call order.
- `PlateCreated(tp_frame)` - calls every element's `PlateCreated` (required).
- `PlateUnitAdded(tp_frame)` - calls `PlateUnitAdded` where defined; skipped entirely when
  `tp_frame.PlateStyle == "None"`.
- `UpdateStyle(tp_frame, style)` - calls `UpdateStyle(tp_frame, style, tp_frame.PlateStyle)` where defined.
- `UpdateSettings()` - calls `UpdateSettings()` where defined (from `Addon:UpdateSettings()`).

There is no `PlateUnitRemoved` loop (commented out). All element functions are dot-defined and receive
`tp_frame`; per-plate state lives in `tp_frame.visual.<Name>`.

Order matters for creation because elements build on each other: `Statusbar.lua` (a helper, not an element) and
`ElementHandler.lua` load first, then Healthbar, Name, StatusText, Castbar, SpellIcon (a texture on the
castbar), MouseoverHighlight (frames on the healthbar and name), ThreatGlow, TargetMarker, Classification
(textures and border on the healthbar), Level (font string on the healthbar).

When a style is applied (`Styles/Styles.lua`), `ElementHandler.UpdateStyle` runs after the Color, Transparency
and Scaling modules and before the widgets; `ElementHandler.PlateUnitAdded` runs right after the style when a
unit is added. Elements also subscribe to WoW and internal events directly. As ordinary subscribers they get WoW
events after the core has updated `tp_frame.unit`. Their handlers usually look up the plate with
`Addon:GetThreatPlateForUnit(unitid)` and return for inactive plates or `PlateStyle == "None"`.

Common rule in `UpdateStyle`: if `plate_style == "None"` (styles `empty`, `etotem`) or the style part's
`show` is false, hide the element and return. Many `PlateCreated` functions set a font right away, because
`SetText` on a font string without font raises a Lua error.

## The elements

### Healthbar (`Elements/Healthbar.lua`)

A `StatusBar` (`tp_frame.visual.Healthbar`, also `.healthbar` for WeakAuras compatibility) with border,
background, absorb bars and a target-of-target text (`healthbar.TargetUnit`).

- Values: `SetMinMaxValues(0, unit.healthmax)`/`SetValue(unit.health)` on unit added and on
  `UNIT_HEALTH`/`UNIT_HEALTH_FREQUENT`/`UNIT_MAXHEALTH`; absorb events refresh the absorb display.
- Color: `HealthbarColorUpdate(tp_frame, color)` published by the Color module. On `HAS_MIDNIGHT_API` clients the
  color is set on the status bar texture's vertex color. The border uses the custom style's border color, the
  foreground color or a fixed color.
- Absorbs (only with `WOW_FEATURE_ABSORBS`): two implementations chosen at load time. Pre-Midnight
  (`RenderNonMidnightAbsorbs`) computes heal absorbs and shields in Lua, like Blizzard's `CompactUnitFrame`.
  `HAS_MIDNIGHT_API` (`RenderMidnightAbsorbs`) uses one `UnitHealPredictionCalculator` per plate and passes
  only secret-safe values to status bars and `SetAlphaFromBoolean`; heal absorbs are hidden. Details in
  [Secret values](../architecture/secret-values.md).
- Target of target: name of `<unitid>target` (optionally only for your target, only in combat, not yourself,
  class colored); updated on `UNIT_TARGET`, `ThreatUpdate`, `TargetGained/Lost` - subscribed only while the
  option is on.
- Frame levels depend on "healthbar over castbar"; the healthbar sets the levels of border, elite border,
  threat glow and `textframe` too.
- Config mode cycles through fixed health/absorb scenarios on all visible plates.

### Name (`Elements/Name.lua`)

`NameText` font string on `textframe`. On `HAS_MIDNIGHT_API` clients `unit.name` (possibly secret) goes through
transliteration straight into `SetText`. Elsewhere NPC names in healthbar view can be abbreviated to initials or
the last word, cached in `Addon.Cache.Texts`. Name mode settings are completed from healthbar mode settings
(font, size). Color comes from `NameColorUpdate`. `UpdateSettings` also triggers
`Addon.Widgets:UpdateSettings("TargetArt")`, whose layout depends on name settings.

### StatusText (`Elements/StatusText.lua`)

The subtext below the name, chosen per mode and reaction: `HEALTH`, `ROLE` (NPC subtitle from the tooltip),
`ROLE_GUILD`, `ROLE_GUILD_LEVEL`, `LEVEL`, `ALL`, `CUSTOM` (LibDogTag, loaded on demand) or none.

- Health text on `HAS_MIDNIGHT_API` uses `UnitHealth`, `UnitHealthMissing`, `UnitHealthMax` and
  `UnitHealthPercent` with `Addon.Truncate` (`AbbreviateNumbers`) and hides itself at full health through the
  text alpha from a step curve. `ALL` always shows role/guild/level there, because "health equals max health"
  cannot be compared.
- NPC subtitles come from `Addon.C_TooltipInfo_GetUnit_NPCRole`, line 2 (line 3 with colorblind mode), and are
  cached by name.
- Health events are subscribed only if some mode shows health; `UNIT_HEALTH_FREQUENT` on Classic Era, TBC and
  Wrath, otherwise `UNIT_HEALTH` and `UNIT_ABSORB_AMOUNT_CHANGED`.

### Castbar and SpellIcon

See [Castbar and interrupts](../nameplates/castbar.md). The castbar element owns the frames, color,
interrupt shield/border/overlay, `OnUpdate` and the single visibility function `castbar:UpdateVisibility`.
SpellIcon is just a positioned texture whose content `OnStartCasting` sets.

### MouseoverHighlight

Two highlight variants: a bordered frame with an additive texture over the healthbar, and an additive texture
over the name for headline view. `UpdateStyle` picks one as `healthbar.MouseoverHighlight`. It is shown on
`MouseoverOnEnter` unless the unit is the target, hidden on `MouseoverOnLeave` and `TargetGained`, and re-shown
on `TargetLost` if the unit is still under the mouse. See
[Target, soft target, mouseover and focus](../nameplates/targets-mouseover-focus.md).

### ThreatGlow

A backdrop frame around `tp_frame` colored by `Addon.Color.GetThreatColor` (or the tapped color) for hostile
NPCs with a threat level; hidden otherwise or if a custom style disables it. Refreshed on `ThreatUpdate`.

### TargetMarker

Raid target icon texture on `textframe`. Pre-Midnight it maps the raid marker index to a configurable icon;
with `HAS_MIDNIGHT_API` the possibly secret index is passed to `SetRaidTargetIconTexture`. Refreshed on the
internal `TargetMarkerUpdate` event.

### Classification

Skull icon for bosses, elite/rare icon and an elite border around the healthbar, colored for rare, rare elite
and elite units.

### Level

Level text on the healthbar (`+` suffix for elites, empty for level `-1`), colored with `unit.LevelColor`
(difficulty color for attackable units). Refreshed on `UNIT_LEVEL`.

### Statusbar helper (`Elements/Statusbar.lua`)

`Addon.CreateStatusbar(parent)` builds a reusable status bar with background, border and named text areas
(`AddTextArea`, `UpdateSettings(db)`, `UpdatePositioning(unit, db)`). The Experience widget uses it, and the
Script widget exposes it to custom scripts as `CreateStatusBar`; it is not an element itself.

## Absorbs and styles without healthbar

Both absorb implementations and the healthbar config mode check `IGNORED_STYLES[tp_frame.stylename]`
(`Addon.IGNORED_STYLES_WITH_NAMEMODE`, keyed by style name). For headline view and empty styles they hide all
absorb elements and skip the calculation. Because of that, `Element.UpdateStyle` calls `UpdateAbsorbs` on every
client with absorbs (`Addon.WOW_FEATURE_ABSORBS`), so the absorbs are rendered again when a nameplate switches back
to the healthbar view (e.g., when the unit is targeted). Until 13.3.4 the check used `tp_frame.style` (the style
table), never matched, and absorbs were computed for every style.

Related: [Styles and custom styles](styles.md), [Modules](modules.md).
