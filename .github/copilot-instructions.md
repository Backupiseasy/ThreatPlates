# Copilot / Coding Agent Notes for this Repository

Short: This repository is a World of Warcraft AddOn named `TidyPlates_ThreatPlates` (nameplates / threat). It contains Lua source code, XML/TOC files, artwork (BLP), localization files, and embedded libraries under `Libs/`.

**Goal**: Help coding agents make safe, fast, low-risk changes with minimal breakage.

## Trust Rules

- Trust this file first; only run additional repository searches if information is missing or contradictory.
- Change the smallest useful set of files for a PR.
- Do not introduce breaking AddOn API changes without asking first.

## Project Overview

- Type: WoW AddOn (TidyPlates-based nameplate/threat addon)
- Languages: Lua, XML, TOC, BLP assets
- Layout: Classic addon layout with `*.toc`, `*.xml`, and `*.lua`; embedded third-party libs in `Libs/`; localizations in `Locales/`.

## Runtime and Testing Environment

- Target runtime: WoW in-game Lua environment. Avoid language features requiring newer Lua versions than WoW supports.
- Local test: Existing WoW installation (`Interface/AddOns/...`) or test installation.
- WoW API reference: `https://github.com/Gethe/wow-ui-source` (branch `main` for the current live version).

## Build / Validate / Test

- No classic build pipeline is required. Typical workflow:
1. Source changes
2. Optional linting
3. Deploy/copy to `Interface/AddOns/`
4. In-game `/reload`

Recommended commands (Windows PowerShell/CMD):

- Optional lint:
  - Install: `luarocks install luacheck`
  - Local/full profile: `luacheck . --config .luacheckrc`
  - CI-style global-write gate: `luacheck . --config .luacheckrc.ci`
- Luacheck profiles in this repo:
  - `.luacheckrc`: broad local checks, excludes `Libs/`, `Test/`, `Source/`, `.release/`
  - `.luacheckrc.ci`: focused gate for accidental global writes (`W111`, `W112`)
- Global variable policy:
  - Avoid implicit globals; prefer `local` declarations.
  - If a global is intentional for WoW integration (e.g., slash commands, addon entrypoints), whitelist it explicitly in Luacheck config.
- Deployment test:
  - Copy addon folder to local WoW `Interface/AddOns/TidyPlates_ThreatPlates`
- In-game:
  - Start WoW, enable addon, run `/reload`, inspect error console.

Always run lint (if available) and a quick in-game reload test before PR.

## Common Pitfalls

- Wrong addon path: Verify `Interface/AddOns/` deployment path.
- Wrong TOC target: Verify Mainline vs Classic TOC target before editing.
- Missing localization keys: Check `Locales/*.lua` for nil-index issues.
- Embedded libs in `Libs/`: Avoid library upgrades without compatibility checks.

## CI / Workflows

- Check `.github/workflows/` before changes.
- If workflows exist, run equivalent local checks before opening a PR.
- If no CI exists, prioritize lint + in-game reload.

## Priority File Layout

Important root files:

- `Addon.lua` - central initialization
- `Init.lua` - startup/setup
- `ThreatPlates.xml` / `TidyPlates_ThreatPlates.toc` - manifest/UI declarations
- `README.md`, `CHANGELOG.md`
- `Options.lua`, `Database.lua`, `Nameplate.lua`

Important folders:

- `Elements/`
- `Libs/`
- `Locales/`
- `Artwork/`
- `Widgets/`, `Modules/`, `Styles/`
- `wow-ui-source-live/` (local UI source mirror, read-only reference)

## Change Guidelines

- Prefer minimal defensive fixes over broad refactors.
- Keep API and SavedVariables compatibility.
- If UI text changes, update localization files.

## Midnight Expansion Notes (`feature/midnight`)

This is the most critical section for AI agents working on this branch.

### Secret Values - Core Concept

Starting in Midnight (12.0), many unit-token APIs can return secret values in restricted contexts. Secret values are a special Lua type and can cause runtime errors when used in boolean, string, arithmetic, or table-key operations.

Mainline helper functions:

- `issecretvalue(x)`
- `canaccessvalue(x)`

Recommended file-level fallback boilerplate in files that consume unit APIs:

```lua
local issecretvalue = issecretvalue or function() return false end
local canaccessvalue = canaccessvalue or function() return true end
```

Do not rely on `value == nil` semantics with secret values.

### When WoW API Values Become Secret (General)

In Mainline/Midnight, API docs use metadata flags that indicate when values may become secret. Use these flags as the primary source of truth:

- `SecretWhen...` on functions/events: The return/event payload can become secret when the corresponding restriction is active.
Examples: `SecretWhenUnitIdentityRestricted`, `SecretWhenUnitPowerRestricted`, `SecretWhenUnitSpellCastRestricted`, `SecretWhenUnitAuraRestricted`, `SecretWhenUnitComparisonRestricted`.
- `SecretReturns = true`: Return values can be secret even if the function still returns a value.
- `ConditionalSecret = true` on fields: Individual return fields may become secret depending on context.
- `SecretArguments = AllowedWhenUntainted` / `AllowedWhenTainted`: Callability in tainted vs untainted context is documented separately from whether returned data is secret.

Practical rule of thumb:

- Expect secret values especially for unit identity, aura, spellcast, comparison, health/power/threat, and related unit-derived data in restricted contexts.
- Addon restriction states (`C_RestrictedActions`, `AddOnRestrictionType`: Combat, Encounter, ChallengeMode, PvPMatch, Map) are strong indicators that restricted behavior can be active.
- There is no single universal pre-check that guarantees non-secret results for all APIs; always validate consumed values with `issecretvalue` / `Addon.IsSecretValue` before boolean tests, math, string ops, or table indexing.

### Required Guards by Category

Boolean/unit-token checks:

```lua
local result = UnitIsUnit(unit1, unit2)
if issecretvalue(result) then result = false end
```

GUID as table key:

```lua
local guid = UnitGUID(unit)
if not guid or issecretvalue(guid) then return end
tbl[guid] = data
```

SpellID as table key:

```lua
if issecretvalue(spellID) then return end
local data = spellTable[spellID]
```

Numeric values (`UnitHealth`, `UnitHealthMax`, `UnitPower`, `UnitStagger`):

```lua
local hp = UnitHealth(unit)
if issecretvalue(hp) then return end
```

Names/strings:

```lua
local name = UnitName(unit)
if not name or issecretvalue(name) then return end
```

Hard rule for Midnight-safe code:

- Never use a unit name as a table index/key when that value is a secret value.
- This applies to names read directly from `UnitName(...)` and to cached names such as `unit.name`.
- Use GUID-based keys (`UnitGUID(unit)` / `unit.guid`) or other non-secret stable identifiers whenever possible.

Castbar interruptibility:

```lua
local _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
if notInterruptible and not issecretvalue(notInterruptible) then
  -- safe usage
end
```

Midnight note: `UNIT_SPELLCAST_INTERRUPTIBLE` and `UNIT_SPELLCAST_NOT_INTERRUPTIBLE` no longer include `castbarID` in payload.

### Features Disabled on `feature/midnight`

- Off-tank detection (do not re-enable)
- Name abbreviation/transliteration (guarded by feature flags in `Modules/Localization.lua`)
- `Widgets/HealerTrackerWidget.lua` (do not re-enable without explicit request)
- NPCID parsing from GUID structure (not reliable on Midnight)

### Visibility and Architecture

- In Midnight use `SetAlpha(0/1)` for visibility transitions instead of `Show()/Hide()`.
- ThreatPlates architecture is frame overlay on top of Blizzard nameplates.

### Safe Tooltip Scanning in Midnight

- Read unit tooltips via `C_TooltipInfo.GetUnit(unitid)` (addon wrapper: `Addon.C_TooltipInfo_GetUnit_*`).
- Validate every extracted field before use: `Addon.IsSecretValue(value)`.
- Never use secret values as table keys.
- Never pass secret values into string operations (`match`, `gsub`, `format`, concatenation).
- Optional early return can be implemented with local defensive checks when a unit is known to be in a restricted context.
- Prefer `UnitGUID(unitid)`-based cache keys over name-based keys.

### `Enum.TooltipDataLineType` Note

- There is no dedicated unit-level line type (no `UnitLevel`).
- Available level-like types include `ItemLevel`, `ItemUpgradeLevel`, and `RestrictedLevel`.
- Unit level lines must be identified by tooltip context/text, not by a dedicated line type enum value.

### Additional Midnight Rules from AddOn Ecosystem Scan

The following implementation rules were repeatedly observed in other AddOns with `Interface: 120001` and should be treated as practical safety constraints for Midnight code:

Data Safety:
- Always check potentially restricted values with `issecretvalue` / `Addon.IsSecretValue` before using them.
- Never do Lua arithmetic (`+`, `-`, `*`, `/`) on secret values.
- Never compare secret values with `<`, `>`, `==`, `~=`, or use them in ordering logic directly.
- Never index a table that may itself be secret, and never use a secret value as a table key.
- Blizzard localization helpers `AbbreviateNumbers`, `AbbreviateLargeNumbers`, and `BreakUpLargeNumbers` are documented with `SecretArguments = "AllowedWhenTainted"` and can be used as display sinks for secret numeric values.
- There is no equivalent verified API metadata for Lua `string.format`; do not assume raw `format` on secret values is safe without explicit documentation or runtime proof.
- For GUID/name/id processing, validate first, then parse/split/match.
- Prefer stable identifier flow (GUID-based), while still guarding GUID access itself for secret restrictions.

UI Safety:
- If values are secret in restricted contexts, degrade gracefully (skip/hide/fallback) instead of forcing computation.
- For status bars, pass raw values to C-side frame APIs (`SetMinMaxValues`, `SetValue`) and avoid Lua-side fraction math.
- For text output, prefer safe formatting/display paths over Lua-side value manipulation.
- Sanitize external text/sender/message inputs before UI usage when values may be secret.

Event Safety:
- Keep castbar interruptibility handling robust and event-driven; do not depend on `castbarID` payload presence.
- Treat `pcall` as a limited fallback only; it is not a full replacement for explicit secret-value checks.

## Architecture Notes

- `EventService.lua`: central pub/sub event layer.
- Old event handler code in `Widgets/WidgetHandler.lua` is obsolete and intentionally commented out.
- Widgets may omit `OnEnable`/`OnDisable` if no lifecycle logic is needed.
- `Init.lua` has duplicate `IS_TBC_CLASSIC` definitions (non-breaking redundancy).

## Known Open Issues (as of Feb 2026)

- `AurasWidgetMidnight.lua` `FilterEnemyBuffsBySpell()`: logic issue around permanent-duration auras.
- `Widgets/HealerTrackerWidget.lua:595`: possible secret GUID used as table key.
- `Init.lua`: duplicate `IS_TBC_CLASSIC` definition should be consolidated.

## Findings from Current Analysis (March 2026)

- No direct `table[UnitName(...)]` usage found in the addon.
- Confirmed open Midnight risks:
  - `Nameplate.lua`: `UnitHealth` / `UnitHealthMax` still use `or` fallbacks before later arithmetic.
  - `Widgets/SocialWidget.lua`: name/fullname concatenation and table-key lookups may still consume secret values.
  - `Elements/StatusText.lua`: `UnitSubtitles[tooltip_name] = subtitle` still needs a secret-value guard on the cache key.
  - `Elements/StatusText.lua`: `UnitHealthPercent(...)` is passed directly into `:format("%.f%%")`; keep this path open until `string.format` safety is proven.
- Closed findings from the March 2026 audit:
  - `Elements/Castbar.lua` / `Nameplate.lua` interruptibility handling is acceptable because downstream consumers use APIs documented with `SecretArguments = "AllowedWhenTainted"`.
  - `Nameplate.lua` cast-target display path is acceptable on Midnight because `UnitSpellTargetName()` returns a unit token and transliteration is a no-op on Midnight.
  - `Elements/Healthbar.lua` target-of-target text path is non-Midnight-only and not part of the Midnight risk surface.
- For new implementations: avoid any name-based keys (`UnitName`, `unit.name`); prefer GUID-based keys.

## First Commands to Run

- `luacheck . --config .luacheckrc.ci`
- `luacheck . --config .luacheckrc`
- Deploy addon and perform an in-game `/reload` smoke test

## If Something Breaks

- Check WoW error console first.
- Revert only the smallest change causing the issue.
- On Midnight, investigate secret-value behavior before assuming ordinary nil/boolean errors.

## Before Opening a PR

1. No new lint warnings/errors.
2. In-game reload test passes without Lua errors.
3. PR description explains backward compatibility and manual validation performed.
4. On Midnight, verify secret-value guards and avoid unsafe unit-value handling.

---

If uncertain, re-verify assumptions against repo root files (`README.md`, `*.toc`, `Libs/`, `Locales/`, `.github/workflows/`) before broad changes.

Work small, testable, and backward-compatible.
