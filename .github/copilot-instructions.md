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
- WoW API reference: Use **only** the following authoritative sources — no other sources:
  - WoW Wiki: `https://warcraft.wiki.gg/`
  - GitHub: `https://github.com/Gethe/wow-ui-source` (branch `live` for the current live version)
  - **MCP Server `wow-api`** (preferred for quick lookups — see below)

## WoW API MCP Server (`wow-api`)

The `wow-api` MCP server is configured globally and available in all workspaces. It indexes 8,000+ WoW API functions from the `ketho.wow-api` VS Code extension and should be the **first tool to reach for** when looking up API signatures, deprecations, enums, or events.

Available tools:

| Tool | Wann verwenden |
|---|---|
| `lookup_api(name)` | Genaue Signatur, Deprecation-Status und Wiki-Link einer Funktion |
| `search_api(query)` | Freitextsuche über alle API-Namen und Beschreibungen |
| `list_deprecated(filter?)` | Veraltete Funktionen mit Ersatz und Patch-Version |
| `get_namespace(name)` | Alle Funktionen eines `C_`-Namespace (z.B. `C_SpecializationInfo`) |
| `get_widget_methods(type)` | Methoden eines UI-Widget-Typs (z.B. `Frame`, `Button`) |
| `get_enum(name)` | Enum-Werte (z.B. `Enum.SpellBookSpellBank`) |
| `get_event(name)` | Event-Payload-Parameter (z.B. `ACTIVE_TALENT_GROUP_CHANGED`) |

**Kompatibilitäts-Shim-Muster** für APIs, die in Midnight unter `C_SpecializationInfo` verschoben wurden:

```lua
local GetSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or _G.GetSpecialization
local GetSpecializationInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or _G.GetSpecializationInfo
```

Dieses Muster ist verbindlich für alle Dateien, die diese APIs verwenden.

**Kanonisches Muster für `UnitIsUnit` (Midnight-sicher):**

Niemals `UnitIsUnit` direkt in Boolean-Kontexten aufrufen — immer `Addon.UnitIsUnit` (definiert in `Compatibility.lua`) verwenden:

```lua
-- Guard (boolean if-check):
if Addon.UnitIsUnit("player", unitid) then ... end

-- Stored result (boolean field):
unit.isTarget = Addon.UnitIsUnit("target", unitid)
```

`Addon.UnitIsUnit` gibt `false` zurück, wenn das Ergebnis ein Secret Value ist.

In Dateien mit vielen Aufrufen kann eine lokale Upvalue angelegt werden:

```lua
local UnitIsUnitTP = Addon.UnitIsUnit
```

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

## Known Open Issues (as of April 2026)

- `AurasWidgetMidnight.lua` `FilterEnemyBuffsBySpell()`: logic issue around permanent-duration auras.
- `Widgets/HealerTrackerWidget.lua:595`: possible secret GUID used as table key.
- `Init.lua`: duplicate `IS_TBC_CLASSIC` definition should be consolidated.

## Findings from Current Analysis (March–April 2026)

- No direct `table[UnitName(...)]` usage found in the addon.
- Confirmed open Midnight risks:
  - `Nameplate.lua`: `UnitHealth` / `UnitHealthMax` still use `or` fallbacks before later arithmetic.
  - `Widgets/SocialWidget.lua`: name/fullname concatenation and table-key lookups may still consume secret values.
  - `Elements/StatusText.lua`: `UnitSubtitles[tooltip_name] = subtitle` still needs a secret-value guard on the cache key.
  - `Elements/StatusText.lua`: `UnitHealthPercent(...)` is passed directly into `:format("%.f%%")`; keep this path open until `string.format` safety is proven.
  - `IgnoreUnitForThreatPlates`, `FrameOnShow`, `FrameOnUpdate`: `UnitIsUnit("player", ...)` calls lack `IsSecretValue` guards — **fixed** by replacing all unsafe `UnitIsUnit` calls in `Nameplate.lua` with `Addon.UnitIsUnit` (defined in `Compatibility.lua`).
- Closed findings from the March–April 2026 audit:
  - `Elements/Castbar.lua` / `Nameplate.lua` interruptibility handling is acceptable because downstream consumers use APIs documented with `SecretArguments = "AllowedWhenTainted"`.
  - `Nameplate.lua` cast-target display path is acceptable on Midnight because `UnitSpellTargetName()` returns a unit token and transliteration is a no-op on Midnight.
  - `Elements/Healthbar.lua` target-of-target text path is non-Midnight-only and not part of the Midnight risk surface.
  - `NAME_PLATE_UNIT_REMOVED` now clears the `PlatesByUnit["mouseover"]` stale reference before `wipe(unit)`, preventing a nil-style crash in `Transparency.lua:GetTransparency` when `UPDATE_MOUSEOVER_UNIT` fires during nameplate recycling (between Lua event handler calls, before the next frame boundary).
  - All bare `UnitIsUnit` calls in `Nameplate.lua` replaced with `Addon.UnitIsUnit`: covers `GetThreatPlateForUnit`, `SetUnitAttributeTarget`, `SetUnitAttributes`, `UnitIsSoftTarget`, `IgnoreUnitForThreatPlates`, `FrameOnShow`, `FrameOnUpdate`, and `Addon.UnitIsTarget`. Use `Addon.UnitIsUnit` (defined in `Compatibility.lua`) as the canonical safe replacement for raw `UnitIsUnit` in all boolean contexts.
  - `widgets.Quest = nil` crash in `QuestWidget:ThreatUpdate` and `RefreshCombatVisisbility` in epic battlegrounds fixed. Root cause: `EventService.UnsubscribeAll` did not remove internal TP-events (like `ThreatUpdate`) from `SubscribersByEvent` because it only checked `Addon:ExpansionSupportsEvent(event)` which returns `false` for internal events — so disabling the Quest widget left `ThreatUpdate` subscribed. Fixed in `EventService.UnsubscribeAll` by also checking `INTERNAL_EVENTS[event]`. The `EventService.UnsubscribeAll` pattern applies to all widgets that subscribe to internal TP-events — always verify that `UnsubscribeAll` is called in `OnDisable` (default behavior in `WidgetHandler:NewWidget`).
- For new implementations: avoid any name-based keys (`UnitName`, `unit.name`); prefer GUID-based keys.
- For new implementations: never call raw `UnitIsUnit` in a boolean context — always use `Addon.UnitIsUnit` instead.

### Nameplate Recycling / Event Ordering (Nameplate.lua)

WoW script handlers (`OnShow`, `OnHide`, `OnEvent`) fire **synchronously** when the corresponding C-side API is called — this is confirmed by WoW Wiki (`ScriptRegion:Show()` docs). Specifically: `Show()` fires `OnShow` immediately within the same call; `HookScript("OnShow", ...)` hooks therefore also run synchronously. Game events like `UPDATE_MOUSEOVER_UNIT` and `UNIT_FACTION` are **not** documented to fire inside a running Lua call; they fire between Lua event handler calls (empirically observed: `UNIT_FACTION` fires between `NAME_PLATE_UNIT_REMOVED` and `NAME_PLATE_UNIT_ADDED` in solo-shuffle, as noted in the `UNIT_FACTION` comment). Rule: always clear derived state (mouseover, focus, target references) **before** calling `wipe(unit)` in `NAME_PLATE_UNIT_REMOVED`, so that any subsequent event handler still finds valid unit data.

### Personal Nameplate Filter Points (Nameplate.lua)

Five locations filter the player's own nameplate; all must stay consistent:
1. `GetThreatPlateForUnit` line ~347: `unitid == "player"` (literal string guard).
2. `GetThreatPlateForUnit` line ~358: `Addon.UnitIsUnit("player", unitid)` — **not** redundant: `UnitIsUnit("player", unitid)` can return a secret value even with `"player"` as the first argument (crash with `unitid = "targettarget"` in a PvP/Encounter restriction context). `UnitIsUnitTP` is required here.
3. `IgnoreUnitForThreatPlates`: gate for `NAME_PLATE_UNIT_ADDED` and `FrameOnShow` — uses `Addon.UnitIsUnit` (safe).
4. `FrameOnShow`: `Addon.UnitIsUnit(unitid, "player")` — uses safe wrapper.
5. `FrameOnUpdate`: `Addon.UnitIsUnit(plate.UnitFrame.unit or "", "player")` — uses safe wrapper.

## First Commands to Run

- `luacheck . --config .luacheckrc.ci`
- `luacheck . --config .luacheckrc`
- Deploy addon and perform an in-game `/reload` smoke test

## If Something Breaks

- Check WoW error console first.
- Revert only the smallest change causing the issue.
- On Midnight, investigate secret-value behavior before assuming ordinary nil/boolean errors.

## Changelog Guidelines

Two changelog files must be kept in sync for every change:

- `CHANGELOG.md` — used by the packager/release tool; contains only the entries for the **current (upcoming) release** under the `# @project-version@ (@build-time@)` header.
- `TidyPlates_ThreatPlates_Changes.log` — the full project history; new entries are prepended at the top.

### Entry Format

- One bullet per logical change, starting with `* `.
- Begin with a capital letter; no trailing period.
- Reference CurseForge comments as `[Comment #NNNN]` (comma-separated for multiple: `[Comment #NNNN, #MMMM]`).
- Reference GitHub issues/PRs as `[GH-NNN]` or `[PR GH-NNN by author]`.
- Both reference types may be combined in one bracket: `[GH-NNN, Comment #MMMM]`.
- Do **not** invent reference numbers; only include those explicitly provided.

### Version Block Format (`TidyPlates_ThreatPlates_Changes.log`)

```
------------------------------------------------------
<version> (<date YYYY-MM-DD>)
------------------------------------------------------
* Entry one.
* Entry two [Comment #NNNN].
```

### Workflow

**If the change is the first change after a release (i.e. the last released tag matches the current top version block in `Changes.log`):**

1. Create a **new version block** at the top of `TidyPlates_ThreatPlates_Changes.log` with an incremented patch version (e.g. `13.0.8` → `13.0.9`) and today's date.
2. Add the new entry to that new block.
3. Replace the full content of the `# @project-version@ (@build-time@)` block in `CHANGELOG.md` with **only** the entries from the new version block.

**If there are already unreleased entries in the top version block (no matching tag yet):**

1. Add the new entry to the **bottom** of the current (top) version block in `TidyPlates_ThreatPlates_Changes.log`.
2. Replace the full content of the `# @project-version@ (@build-time@)` block in `CHANGELOG.md` with **all** entries from that same version block (i.e. it always reflects exactly the entries for the upcoming release).

**Always:**
- Never carry over entries from older (released) version blocks into `CHANGELOG.md`.
- `CHANGELOG.md` always reflects exactly the entries of the single upcoming (unreleased) version block.

## Before Opening a PR

1. No new lint warnings/errors.
2. In-game reload test passes without Lua errors.
3. PR description explains backward compatibility and manual validation performed.
4. On Midnight, verify secret-value guards and avoid unsafe unit-value handling.
5. Both `CHANGELOG.md` and `TidyPlates_ThreatPlates_Changes.log` are updated and consistent.

---

If uncertain, re-verify assumptions against repo root files (`README.md`, `*.toc`, `Libs/`, `Locales/`, `.github/workflows/`) before broad changes.

Work small, testable, and backward-compatible.
