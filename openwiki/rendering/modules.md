---
type: subsystem
title: "Modules: threat, color, transparency, scaling and helpers"
description: The shared, dot-called Modules of Threat Plates - threat level detection, healthbar and name colors, transparency, scaling, fonts, icons, animations and localization helpers - with their inputs, events and calling order.
tags: [modules, threat, color, transparency, scaling, font, animation, localization]
sources:
  - id: openwiki-source-8e65c9af5eec1ce3c038cede
    resource: repo://Constants.lua
  - id: openwiki-source-1a02b37819b8bcedff2783c0
    resource: repo://Modules/Animation.lua
  - id: openwiki-source-65a8e958e1c834c2baafb605
    resource: repo://Modules/Color.lua
  - id: openwiki-source-22264d8cde24d0fa142a234a
    resource: repo://Modules/Font.lua
  - id: openwiki-source-c4e0bc0805b92f228556e185
    resource: repo://Modules/Icon.lua
  - id: openwiki-source-0db67719773fe4ec9f9b9d56
    resource: repo://Modules/Modules.xml
  - id: openwiki-source-fba3ffd29735bf7da3a29a47
    resource: repo://Modules/Scaling.lua
  - id: openwiki-source-312a116495eb1f8e57717a6d
    resource: repo://Modules/Threat.lua
  - id: openwiki-source-0eaf2cc03cbb31b69fad2f30
    resource: repo://Modules/Transparency.lua
  - id: openwiki-source-7a3e837cfb6d3795c0c95431
    resource: repo://Nameplate.lua
  - id: openwiki-source-3109d6b4b39ada7d983ff1d5
    resource: repo://TidyPlates_ThreatPlates.toc
generated: { by: "claude-code", at: "2026-10-28T19:52:11.033Z" }
verified:
  - by: openwiki/0.7.2
    at: 2026-10-28T19:52:11.033Z
---

# Modules: threat, color, transparency, scaling and helpers

Modules (`Modules/`) are services used by the core, Elements and Widgets. They hold no per-plate frames of their
own; per-plate results are written to `tp_frame` (e.g. `HealthbarColor`, `CurrentAlpha`) or the `unit` table
(e.g. `ThreatLevel`).

## Conventions

- Each module fills a table pre-created in `Init.lua` (`Addon.Threat`, `Addon.Color`, `Addon.Transparency`,
  `Addon.Scaling`, `Addon.Font`, `Addon.Icon`, `Addon.Animation`, `Addon.Localization`; `Addon.Style` belongs
  to [Styles](styles.md)).
- Functions are **dot**-defined (`function ColorModule.UpdateStyle(tp_frame)`). Calling them with a colon passes
  the module table as the first argument. Import them as upvalues
  (`local FontUpdateText = Addon.Font.UpdateText`).
- `UpdateSettings()` caches settings in file-local variables and may swap implementations (e.g. with or without
  fading). `Addon:UpdateSettings()` calls them in this order: Localization, Font, Icon, Threat, Transparency,
  Scaling, Animation, Color, then all Elements.
- `Modules.xml` loads Font, Icon, Animation, Threat, Color, Transparency, Scaling (order is relevant).
  `Modules/Localization.lua` is loaded earlier from the TOC. `Modules/ColorImproved.lua` is an unfinished rewrite
  of `Color.lua`; it is not loaded and must not be deleted as dead code.

When a style is applied, `Styles.lua` calls `ColorModule.UpdateStyle`, `TransparencyModule.UpdateStyle` and
`ScalingModule.UpdateStyle` (in that order) before the Elements, because Elements use their results.

## Threat (`Modules/Threat.lua`)

Determines `unit.ThreatLevel` (`LOW`, `MEDIUM`, `HIGH` mapped from the threat situation 0-3 via
`Addon.THREAT_REFERENCE`, `OFFTANK`, or `nil` out of combat), `unit.InCombat`, `unit.HasThreatTable` and `unit.IsOfftanked`.

- **Threat table** (default): `UnitThreatSituation("player", unitid)` - not secret, so safe on all clients.
- **Heuristic** (when the threat table is off, or only in instances): looks at whether `<unitid>target` is the
  player or vehicle; driven by `UNIT_COMBAT`.
- **Off-tank detection**: for tanks, checks whether another tank, the player's pet or a tank-like creature
  (Black Ox Statue, Treants, Earth Elemental - parsed from the GUID) holds aggro.

`ThreatModule.SetUnitAttribute(unit)` sets the level on unit added without side effects;
`ThreatModule.Update(tp_frame)` (on `UNIT_THREAT_LIST_UPDATE`/`UNIT_THREAT_SITUATION_UPDATE`) and
`LeavingCombat()` change it through `UpdateThreatLevel`, which calls `StyleModule.Update` and publishes
`ThreatUpdate(tp_frame, unit)` when the level changes. `ThreatModule.ShowFeedback(unit)` decides whether threat
feedback applies (not for players or friendly units, optionally only in instances, per classification toggle).
On `HAS_MIDNIGHT_API` clients the threat table is forced and the heuristic and off-tank detection are off (secret
values; see [Secret values](../architecture/secret-values.md)). Pre-Mists tanks subscribe to
`UPDATE_SHAPESHIFT_FORM`, because the role there comes from the stance.

## Color (`Modules/Color.lua`)

Computes `tp_frame.HealthbarColor` and `tp_frame.NameColor` and publishes `HealthbarColorUpdate` and
`NameColorUpdate`, which the Healthbar, Name and StatusText elements apply.

`ColorModule.UpdateStyle` picks the color functions per plate: custom style/totem colors when configured,
otherwise per reaction the configured mode (`REACTION`, `CLASS`, `HEALTH`, for names also `CUSTOM`). Each mode
is a priority chain, e.g. for class mode:
situational color (target, focus, raid marker, tapped, quest unit) -> threat color (if "use threat color" and
the style is `dps`/`tank`) -> class color -> reaction color.

- Reaction colors consider PvP flags of unit and player (`UNIT_COLOR_MAP`) and detect Blizzard's brown
  "unfriendly" NPC color from the selection color.
- Class colors use the configured table, or `C_ClassColor.GetClassColor` for a secret class token; friends and
  guildmates can get special colors (Social widget).
- Health colors interpolate between the low and high color in HSV (cached per percent), or on
  `HAS_MIDNIGHT_API` come from `UnitHealthPercent` with a color curve.
- Raid marker colors are disabled on `HAS_MIDNIGHT_API` (the marker index can be secret).
- `ColorModule.GetThreatColor` is exported for the ThreatGlow element and widgets.

Recomputed on `UNIT_HEALTH`, `ThreatUpdate`, target/focus/marker changes, `FactionUpdate`,
`SituationalColorUpdate` (e.g. quest status) and `ClassColorUpdate` (friend/guild status).

## Transparency (`Modules/Transparency.lua`) and Scaling (`Modules/Scaling.lua`)

Both have the same structure: a function per style name (`ALPHA_FUNCTIONS`, `SCALE_FUNCTIONS`) computes the
value from

1. situational settings (raid marker, mouseover, casting) - never for the target,
2. target / non-target / no-target settings (additive or absolute),
3. per-unit-type values (`unit.TP_DetailedUnitType`),
4. for threat styles: per threat level, optionally additive.

`empty` has alpha 0 and a minimal scale. Scale is clamped to at least 0.3 and multiplied with `Addon.UIScale`.
`UpdateStyle` resets the frame (alpha 0, stop animations) and sets the new value; on situational internal events
(`MouseoverOnEnter/Leave`, `CastingStarted/Stopped`, `TargetGained/Lost`, `TargetMarkerUpdate`, `FactionUpdate`,
`ThreatUpdate`) the plate is updated, on `TargetExistsChanged` all active plates.

Transparency also implements **occlusion**: `FrameOnUpdate` calls `TransparencyModule.SetOccludedTransparency`
every frame; a plate whose Blizzard alpha drops to `nameplateOccludedAlphaMult` is treated as occluded and gets
the occluded alpha (target excepted), optionally faded. It is disabled when the CVars do not allow detection
(`CVars.InvalidCVarsForOcclusionDetection`).

Custom styles that use the threat system and headline view with "use alpha/scaling" get the threat-based alpha
and scale for `dps`/`tank` threat styles; with threat alpha/scale turned off, a custom style keeps its own value.
See [Target, soft target, mouseover and focus](../nameplates/targets-mouseover-focus.md#threat-style-of-custom-styles-and-headline-view).

## Font (`Modules/Font.lua`)

- `Addon.AnchorFrameTo(db, frame, parent)` - generic anchoring from a settings table.
- `FontModule.SetFont(font_string, file, size, flags, shadow)` - replacement for `SetFont` that uses font
  families with fallback fonts for other alphabets where available and sets the shadow on the family's fonts.
  `SetInitialFont` must be used for font strings later set through `SetFont`.
- `UpdateText(parent, font, db)`, `UpdateTextSize(parent, font, db)`, `SetJustify` - apply text settings
  (re-setting the text forces a justification update).
- `SetNamesFonts()` / `ResetNamesFonts()` - override Blizzard's `SystemFont_NamePlate*` fonts for names on
  Blizzard plates; re-applied after one frame and after 0.1 s, because Blizzard resets them asynchronously.

## Icon (`Modules/Icon.lua`)

`IconModule.CreateIcon(widget, parent)` creates either a plain texture or, with Masque enabled, an
`ActionButtonTemplate` button in a Masque group registered with `RegisterMasqueGroup(widget, name)`. Icons get
`SetIconTexture`, `SetTPIconTexture`, `GetIconTexture` and `GetParentFrame`, so widgets work the same with and
without Masque. Borderless icons crop the texture coordinates.

Whether Masque is used is read once, at the first `IconModule.UpdateSettings()`, and kept until the UI is reloaded
(as the option says). Existing icons are either Masque buttons or textures; switching the setting on a profile
change or reset would access them as the wrong type and caused Lua errors before 13.3.4.

## Animation (`Modules/Animation.lua`)

One hidden frame (`ThreatPlatesAnimation`) runs an `OnUpdate` over all frames currently animated:
`FadePlate`/`StopFade` (alpha), `ScalePlate`/`StopScale` (scale), `Flash`/`StopFlash`. Durations come from the
Animations settings; a duration of 0 makes Transparency and Scaling set values directly.

## Localization (`Modules/Localization.lua`)

Runtime text helpers (not the translation tables, see [Localization pipeline](../workflows/localization.md)):

- default fonts per client locale (`Addon.DEFAULT_FONT`, `Addon.DEFAULT_SMALL_FONT`),
- the localized totem creature type (`Addon.TotemCreatureType`),
- `Addon.Truncate` - `AbbreviateNumbers` by default and always on `HAS_MIDNIGHT_API`; otherwise a Western or
  East Asian (`万`/`億`) formatter,
- `TransliterateCyrillicLetters(text)` - a Lua table-based transliteration with cache; on `HAS_MIDNIGHT_API`
  `C_Intl.Transliterate` (if present, `TransliterationIsSupported`) without inspecting the text.

Related: [Elements](elements.md), [Styles and custom styles](styles.md).
