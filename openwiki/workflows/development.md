---
type: workflow
title: Development workflow
description: How to work on Threat Plates - running the addon from the repository, linting with luacheck, testing in-game with debug commands and forced secret-value restrictions, branching, changelog rules and the coding conventions that matter most.
tags: [development, luacheck, testing, debugging, changelog, conventions, branching]
sources:
  - id: openwiki-source-0a794ce9aca922a34bf9e225
    resource: repo://.luacheckrc
  - id: openwiki-source-6191cd82e5e42ffea2c7efe7
    resource: repo://.luacheckrc.ci
  - id: openwiki-source-ca6cb4b1a14fd7969dfae3ec
    resource: repo://CHANGELOG.md
  - id: openwiki-source-cfe0b084e5798ad70d26514c
    resource: repo://Commands.lua
  - id: openwiki-source-91e15362f68ac2a704047cc1
    resource: repo://Debug.lua
  - id: openwiki-source-4cfab5238eb54f18483ded92
    resource: repo://Init.lua
  - id: openwiki-source-3109d6b4b39ada7d983ff1d5
    resource: repo://TidyPlates_ThreatPlates.toc
generated: { by: "claude-code", at: "2026-10-28T19:58:16.774Z" }
verified:
  - by: openwiki/0.7.2
    at: 2026-10-28T19:58:16.774Z
---

# Development workflow

## Running the addon

There is no build step. The repository folder is the addon folder: link or copy it as
`Interface/AddOns/TidyPlates_ThreatPlates` into each WoW client (Retail, Classic Era, TBC/Mists Classic, Forever)
and `/reload` after a change. The TOC's `## Version: @project-version@` stays unreplaced in a source checkout,
which turns on development mode:

- `Addon.DEBUG = Addon.Meta("version") == "@project-version@"` (`Commands.lua`) - enables
  `Addon.Logging.Debug` output and the debug chat commands.
- `TidyPlatesThreat:VersionIsAtLeast()` is always true.

Install BugSack/!BugGrabber to see Lua errors.

## Linting

```sh
luacheck . --config .luacheckrc      # full local profile
luacheck . --config .luacheckrc.ci   # only accidental global writes (warnings 111/112)
```

Both use `std = "lua51"`, no line length limit, exclude `Libs/`, `Source/` and `.release/`, and whitelist the
addon's real globals (`TidyPlatesThreat`, `TidyPlatesThreatDBM`, `TidyPlatesThreat_OnAddonCompartmentClick`, the
`SLASH_TPTP*` commands, `SlashCmdList`, `StaticPopupDialogs`). New globals must be added there - but usually a new
global is a bug (missing `local`). No GitHub workflow currently runs luacheck; the `.ci` config is the gate to
use locally before pushing.

There is no automated test runner for the Lua code. The only automated tests are for the localization tooling
(`Source/test_localization_tool.py`, pytest; see [Localization pipeline](localization.md)).

## Testing in-game

Debug commands (development builds only, `/tptp <command>`, implemented in `ChatCommandDebug`):

| Command | Shows / does |
| --- | --- |
| `version` | addon version, client version, build, Interface number, `GetExpansionLevel()` (also for the Forever entry in the TOC) |
| `unit` | the `unit` table of the target's (or mouseover's) plate (`Addon.Debug.PrintUnit`) |
| `debug WidgetHandler` / `debug EventService` / `debug Color` / `debug <Widget>` | widget states and events, event registrations (main-subscriber events no longer registered at WoW in red), color calculation, widget-specific dumps |
| `threat`, `reaction`, `role`, `auras`, `guid` | threat values, reaction data, spec roles, aura fields and filter tokens, NPC id of the target |
| `searchdb <text>` | settings keys matching the text |
| `cache`, `custom-styles`, `cleanup-custom-styles` | caches, custom style list, remove empty custom styles |
| `version-history` | manual checks of `Addon.CurrentVersionIsOlderThan` |
| `test` | scratch command for ad-hoc checks on the target's plate |
| `restrictions [combat\|encounter\|challenge\|pvp\|map]` | toggles the `secret*RestrictionsForced` CVars to force secret-value restrictions outside combat; without argument all off |

The `restrictions` command is the way to test [secret-value](../architecture/secret-values.md) code paths
without a real encounter. `C_Secrets.Should...BeSecret` functions answer whether a given call would be secret.
Debug output is plain English - never wrap it in `L[...]`.

Useful one-liners from past investigations:

```lua
-- Which plate frame does the target use? (plates are pooled)
/run local p=C_NamePlate.GetNamePlateForUnit("target") print(p and p:GetName())
-- Is TPFrame anchored to the current unit frame?
/run local p=C_NamePlate.GetNamePlateForUnit("target"); local _, rel = p.TPFrame:GetPoint(); print(rel == p.UnitFrame, p.TPFrame:IsVisible(), p.TPFrame:GetAlpha(), p.TPFrame:GetLeft())
```

Test on every client a change can affect: a branch on `HAS_MIDNIGHT_API`, `IS_CLASSIC`, `IS_FOREVER` etc. has
code paths that only run there (see [Client and expansion compatibility](../architecture/client-compatibility.md)).

## Branches

- `main` - released versions, tagged (`13.3.3`, ...).
- `release/<major.minor>` - the upcoming release.
- `develop` - integration branch.
- `feature/<name>` for new features, `hotfix/<name>` for bug fixes, branched from `develop`.

Versioning: major = WoW expansion (13 = Midnight), minor = new functionality, patch = bug fixes.

## Changelog

Two files must stay in sync for every user-facing change:

- `TidyPlates_ThreatPlates_Changes.log` - full history, newest version block at the top
  (`<version> (<YYYY-MM-DD>)` between dashed lines).
- `CHANGELOG.md` - only the entries of the current unreleased top block, under `# @project-version@ (@build-time@)`;
  the packager uses it as release notes.

If the top block of the log is already released (its version is tagged), start a new block (next patch version,
today's date); otherwise append to the top block. Then replace the content of `CHANGELOG.md` with all entries of
that block. An "Updated integrated libraries" entry always stays the last one.

Entry style: one `* ` bullet per change, past-tense verb (`Fixed`, `Added`, `Changed`, `Removed`, `Updated`,
`Hopefully fixed` if unverified), player-facing symptom first, optional root cause as `, caused by ...` in terms
of WoW behavior (never internal function names), references before the final period: `[Comment #NNNN]`,
`[GH-NNN]`, `[PR GH-NNN by author]`. Never invent reference numbers.

## Conventions that prevent most bugs

- **Secret values**: on unit-data paths, use `Addon.UnitIsUnit`/`Addon.UnitIsPVP`, guard with `IsSecretValue`
  before comparisons, arithmetic, string patterns and table keys, key tables by GUID, pass raw values to C-API
  sinks. Details: [Secret values](../architecture/secret-values.md).
- **Client branches**: `HAS_MIDNIGHT_API` for API/secret-value code paths, `ExpansionIsAtLeastMidnight` only for
  ruleset decisions, `or Addon.IS_FOREVER` explicitly for Forever features; detect API shapes instead of
  versions where they differ.
- **Specialization APIs**: always use the `C_SpecializationInfo ... or _G.GetSpecialization` shim.
- **Dot vs. colon**: Modules and Elements are dot-defined, Widgets colon-defined. Import module functions as local
  upvalues. A colon call on a dot function silently shifts all arguments (see the former bug in
  [Target, soft target, mouseover and focus](../nameplates/targets-mouseover-focus.md#threat-style-of-custom-styles-and-headline-view)).
- **Upvalue caching**: cache WoW API functions and settings as file locals for speed, but not values that are
  replaced at runtime (`Addon.UnitIsTarget`, `Addon.TargetUnitExists`).
- **New tables instead of `wipe`**, except where other code holds a reference to the table (e.g. `tp_frame.unit`,
  custom style trigger caches).
- **Events**: subscribe in `OnEnable`, rely on `UnsubscribeAll` in `OnDisable`; add new WoW events to
  `WOW_EVENTS` in `Compatibility.lua`. WoW events never fire inside another event handler; script handlers do
  (`OnShow` inside `Show()`, `CVAR_UPDATE` inside `C_CVar.SetCVar`).
- **Settings**: new or renamed settings need defaults in `Constants.lua` and, for renamed/moved keys, a migration
  in `Database.lua`. Keep SavedVariables compatible.
- **UI text**: wrap in `L["..."]`, never edit `Locales/*.lua` by hand.
- Prefer minimal, defensive fixes over refactors; commented-out legacy code (e.g. in `WidgetHandler.lua`) and
  `Modules/ColorImproved.lua` (unfinished rewrite) are intentional.
