---
type: concept
title: Secret values (Midnight and Forever)
description: How Threat Plates handles WoW's secret values on clients with Midnight's API surface - what they are, which data is affected, the guard patterns and safe sinks used in the code, disabled features, and open issues.
tags: [midnight, forever, secret-values, taint, safety, guards]
sources:
  - id: openwiki-source-6eee19a5c8ad4d5edaf05fe2
    resource: repo://Compatibility.lua
  - id: openwiki-source-b28f0469e713ffab5d099af7
    resource: repo://Elements/Castbar.lua
  - id: openwiki-source-3babb7e0272ba771750c1b2a
    resource: repo://Elements/Healthbar.lua
  - id: openwiki-source-9f941e2d61eb287b4d62d04d
    resource: repo://Elements/StatusText.lua
  - id: openwiki-source-57cb6ded340fc795e5ebd185
    resource: repo://Elements/TargetMarker.lua
  - id: openwiki-source-65a8e958e1c834c2baafb605
    resource: repo://Modules/Color.lua
  - id: openwiki-source-7dcd90c3fda730b2fc776be4
    resource: repo://Modules/Localization.lua
  - id: openwiki-source-312a116495eb1f8e57717a6d
    resource: repo://Modules/Threat.lua
  - id: openwiki-source-7a3e837cfb6d3795c0c95431
    resource: repo://Nameplate.lua
  - id: openwiki-source-8c1a2f1346df95ad59b63c21
    resource: repo://Styles/Styles.lua
  - id: openwiki-source-45c8931b000866c388b94c2a
    resource: repo://Widgets/HealerTrackerWidget.lua
generated: { by: "claude-code", at: "2026-10-25T18:59:51.751Z" }
verified:
  - by: openwiki/0.7.2
    at: 2026-10-28T19:52:11.033Z
---

# Secret values (Midnight and Forever)

On clients with Midnight's API surface (`Addon.HAS_MIDNIGHT_API`: Retail/Midnight and WoW Forever), many unit
APIs can return **secret values** in restricted contexts (combat, encounters, PvP matches, ...). A secret value is
a distinct Lua type: it is truthy and not `nil`, but arithmetic, comparisons, string operations or using it as a
table key raise an error in addon code. This is the most important constraint for any change on unit-data paths.

## Detection helpers

- `Addon.IsSecretValue` = `_G.issecretvalue` or a function that always returns `false` (`Compatibility.lua`),
  so the same code also runs on pre-Midnight clients. Files import it as `local IsSecretValueTP =
  Addon.IsSecretValue`.
- The canonical source for *when* a value can be secret is Blizzard's API documentation metadata
  (`SecretWhen...`, `SecretReturns`, `ConditionalSecret`, `NeverSecret`, `SecretArguments`). Look it up instead
  of guessing; there is no single pre-check that guarantees non-secret results.

## Rules, as applied in the code

**Branch on `HAS_MIDNIGHT_API`, not on `ExpansionIsAtLeastMidnight`**, whenever a branch exists to choose the
secret-safe code path. Many pre-Midnight branches do plain arithmetic and carry a comment that every client with
secret values takes the other branch (e.g. `ColorModule.GetColorByHealthDeficit`, `TextHealthPercentColored`).

**Never use raw `UnitIsUnit`/`UnitIsPVP` in a boolean context.** `Addon.UnitIsUnit` and `Addon.UnitIsPVP` return
`false` for a secret result on `HAS_MIDNIGHT_API` clients and are the plain API otherwise. Convention:
`local UnitIsUnitTP = Addon.UnitIsUnit`. Even `UnitIsUnit("player", unitid)` can be secret (observed with
`"targettarget"`), which is why `GetThreatPlateForUnit` uses the wrapper in addition to the `unitid == "player"`
check.

**Guard before Lua-side operations** - arithmetic, comparisons, `string.format/match/gsub`, table indexing:

```lua
local guid = UnitGUID(unitid)
if not guid or issecretvalue(guid) then return end
tbl[guid] = data
```

`RefreshUnitData` (`Nameplate.lua`) only stores `PlatesByGUID[guid]` if the GUID is not secret. Never key a
table by `UnitName` / `unit.name`.

**Secret booleans in an `if` are not safe either.** `if secret then` on a secret *boolean* threw "attempt to
perform boolean test on field ... (a secret boolean value, while execution tainted by ...)" in
`Elements/Castbar.lua`. The castbar therefore uses
`Addon.EvaluateColorValueFromBoolean(unit.CastIsNotInterruptible, shield_color, normal_color)` (built on
`C_CurveUtil.EvaluateColorValueFromBoolean`) and `SetAlphaFromBoolean` for the interrupt shield, border and
overlay instead of `SetShown`. `unit.CastIsNotInterruptible` is the only secret boolean stored in the `unit`
table.

**Comparing with `nil` is allowed** (`value ~= nil`), verified in-game on Forever; e.g.
`Elements/TargetMarker.lua` compares `unit.TargetMarkerIcon ~= nil`. Any other comparison is forbidden.

**`..` concatenation does not throw**; it produces a secret result. Guard the consumer of the result (table key,
comparison, pattern), not the concatenation. `Addon:UNIT_SPELLCAST_INTERRUPTED` builds
`INTERRUPTED .. " [" .. name .. "]"` from a possibly secret name and passes it to `SetText` without a guard.

**Pass secret values straight into C-API sinks** that accept them: `FontString:SetText`,
`StatusBar:SetMinMaxValues/SetValue/SetTimerDuration`, `Texture:SetTexture`, `SetRaidTargetIconTexture`,
`SetAlphaFromBoolean`, `C_ColorUtil.WrapTextInColor`, `C_ClassColor.GetClassColor`, `C_Intl.Transliterate`, and
the number formatters `AbbreviateNumbers`/`AbbreviateLargeNumbers`/`BreakUpLargeNumbers`. Examples:

- Castbar timing: `UnitCastingDuration`/`UnitChannelDuration` objects go to `castbar:SetTimerDuration`; the
  Midnight `OnUpdate` reads `Duration:GetRemainingDuration()` instead of doing time arithmetic.
- Class colors: `GetColorForClass` (`Modules/Color.lua`) uses `C_ClassColor.GetClassColor` for a secret class
  token instead of indexing the class color table.
- Health color: `UnitHealthPercent(unitid, true, HealthColorCurve)` returns the color directly.
- Number text: `Addon.Truncate` is `AbbreviateNumbers` on these clients; the Western/East Asian Lua formatters
  are only installed when `HAS_MIDNIGHT_API` is false.
- Transliteration: on these clients `TransliterateCyrillicLetters` hands the text to `C_Intl.Transliterate`
  and never inspects or caches it.
- Raid markers: with `HAS_MIDNIGHT_API`, `unit.TargetMarkerIcon` is the raw (possibly secret) index, passed to
  `SetRaidTargetIconTexture`; `RAID_TARGET_UPDATE` then publishes `TargetMarkerUpdate` without comparing.

**Status bars:** set raw values with `SetMinMaxValues`/`SetValue`, avoid Lua-side fraction math, and degrade
gracefully (skip, hide, fall back) when a value is secret.

**`pcall` is only a limited fallback.** It does not catch `ADDON_ACTION_FORBIDDEN` (taint is tied to the calling
context) or a comparison that silently yields the wrong result.

## Absorb bar specifics

The absorb amount from `UnitHealPredictionCalculator` is secret, so Lua cannot tell whether a shield exists.
`RenderMidnightAbsorbs` (`Elements/Healthbar.lua`) always shows the absorb status bar (with a fill of 0 when
there is none) and uses `SetAlphaFromBoolean(absorb_clamped, ...)` for the over-absorb spark and overshield.
Because a freshly shown bar briefly rendered at full width, `Show()` is deferred by one frame
(`C_Timer.After(0)`, guarded by `AbsorbWanted`/`AbsorbShowPending`). Heal absorbs are hidden on these clients.
Do not print values of this bar for debugging - `GetAlpha()` and texture widths are secret and turn the chat
line into `???`.

## Threat is only secret for some unit pairs

`UnitThreatSituation("player", unitid)` is not secret, so `Modules/Threat.lua` may compare and index with it. A
compound token as first unit (`unitid .. "target"`, used by off-tank detection) is secret. The threat module
therefore forces the threat table and disables the heuristic and off-tank detection on `HAS_MIDNIGHT_API`
(`UseThreatTable = Settings.UseThreatTable or Addon.HAS_MIDNIGHT_API`, `ShowOffTank = ... and not
Addon.HAS_MIDNIGHT_API`). `C_Secrets.Should...BeSecret` functions answer such questions without being in combat.

## Features disabled or reduced on `HAS_MIDNIGHT_API`

Do not re-enable these without an explicit decision:

- Off-tank detection and the threat heuristic in instances (`Modules/Threat.lua`).
- NPC-ID parsing from the GUID (`unit.NPCID` stays `nil`), and with it name-based custom style triggers
  (`ProcessNameTriggers`) and cast triggers (`CastTriggerCheckIfActive` keys by spell id/name).
- `PlatesByGUID` is not cleared on unit removal (GUIDs may be secret).
- The HealerTracker and BossMods widgets are not loaded; the pre-Midnight `AurasWidget.lua` is replaced by
  `AurasWidgetMidnight.lua`.
- `COMBAT_LOG_EVENT_UNFILTERED` is not registered; interrupts use `UNIT_SPELLCAST_INTERRUPTED`.
- The Lua-based number abbreviation is replaced by `AbbreviateNumbers`. Cyrillic transliteration still works,
  but only through `C_Intl.Transliterate`.

The arena healer detection cannot simply come back: since Patch 12.1.5, `GetArenaOpponentSpec` always returns
secrets, so the spec id cannot be a table key.

## Open issues (re-verify before acting)

These were found in earlier analysis passes; the code they refer to was still present when this page was
written:

- `Elements/StatusText.lua`, `GetUnitSubtitle`: on `HAS_MIDNIGHT_API` the tooltip name check is skipped and
  `UnitSubtitles[tooltip_name] = subtitle` uses the tooltip name as key without a secret guard (only
  `tooltip_subtitle` is checked).
- `Elements/StatusText.lua`: `("%.f%%"):format(UnitHealthPercent(...))` passes a possibly secret number into
  `string.format`, whose safety with secret values is not documented.
- `Widgets/HealerTrackerWidget.lua`: `if not guid then return end` before `UnitIsHealer[guid] = role` does not
  catch a secret GUID. The widget is not loaded on `HAS_MIDNIGHT_API`, so this only matters if pre-Midnight
  clients ever return secret GUIDs.
- `Widgets/ExperienceWidget.lua`: `not UnitIsOwnerOrControllerOfUnit(...)` can be secret; it is only
  unreachable because `unit.NPCID` is `nil` on these clients.
- `Nameplate.lua`: health values get `or` fallbacks before arithmetic in some places; worth an audit pass.
- `AurasWidgetMidnight.lua`, future per-spell filters: since 12.1.5 `candidateFilters.includeSpellIDs` rejects
  all auras on units where spell-id filtering is not permitted - set it only where allowed.

A full audit of secret booleans (2026-10-07, against the `forever` branch of wow-ui-source) found no further
case; repeat it when a new unit API is used or the metadata changes. Details and remaining in-game checks are
in `Source/Plans/WoWForeverCompatibility.md`.

Related: [Client and expansion compatibility](client-compatibility.md), [Castbar and interrupts](../nameplates/castbar.md),
[Auras widgets](../widgets/auras.md).
