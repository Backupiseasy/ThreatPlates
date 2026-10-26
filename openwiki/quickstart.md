---
type: guide
title: Quickstart
description: Entry point to the Threat Plates developer wiki - what the addon is, how the code is organized, the five rules to know before changing anything, and a task-to-page routing map.
tags: [quickstart, overview, navigation]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-25T18:59:51.751Z
sources:
  - id: openwiki-source-3109d6b4b39ada7d983ff1d5
    resource: repo://TidyPlates_ThreatPlates.toc
generated: { by: "claude-code", at: "2026-10-25T18:59:51.751Z" }
---

# Quickstart

Threat Plates (`TidyPlates_ThreatPlates`) is a World of Warcraft addon in Lua/XML that replaces Blizzard's
nameplates with configurable, threat-reactive nameplates. One codebase and one TOC serve Retail (Midnight),
WoW Forever, Classic Era (with its seasons), TBC Anniversary and Mists Classic. There is no build step; the
repository folder is loaded by the client directly.

## Code map

| Area | Files | Page |
| --- | --- | --- |
| Load order, `Addon` namespace, initialization | `TidyPlates_ThreatPlates.toc`, `Init.lua`, `Addon.lua` | [Architecture overview](architecture/overview.md) |
| Client detection and API shims | `Init.lua`, `Compatibility.lua` | [Client and expansion compatibility](architecture/client-compatibility.md) |
| Event dispatch | `EventService.lua` | [Event system](architecture/event-system.md) |
| Secret values (Midnight, Forever) | everywhere unit data is read | [Secret values](architecture/secret-values.md) |
| Nameplate core | `Nameplate.lua` | [Nameplate lifecycle](nameplates/lifecycle.md), [Target, soft target, mouseover and focus](nameplates/targets-mouseover-focus.md), [Castbar and interrupts](nameplates/castbar.md) |
| Styles and custom styles | `Styles/` | [Styles and custom styles](rendering/styles.md) |
| Modules (threat, color, alpha, scale, fonts, ...) | `Modules/` | [Modules](rendering/modules.md) |
| Elements (healthbar, name, status text, ...) | `Elements/` | [Elements](rendering/elements.md) |
| Widgets | `Widgets/` | [Widget framework](widgets/framework.md), [Auras widgets](widgets/auras.md), [Other widgets](widgets/catalog.md) |
| Settings | `Database.lua`, `Constants.lua`, `Options.lua`, `CVarsManager.lua` | [Database, profiles and migrations](settings/database-and-profiles.md), [Options UI and propagating setting changes](settings/options-and-updates.md), [Game CVars management](settings/cvars.md) |
| Tooling and process | `.luacheckrc*`, `Commands.lua`, `Source/`, `.github/workflows/`, `.pkgmeta` | [Development workflow](workflows/development.md), [Localization pipeline](workflows/localization.md), [Release and packaging](workflows/release-packaging.md) |

`Libs/` (third-party libraries) and `Locales/` (generated translations) are not documented here.

## Five rules before changing code

1. **Secret values**: on `HAS_MIDNIGHT_API` clients, unit API results can be secret. Do not compare, compute,
   pattern-match or use them as table keys; use `Addon.UnitIsUnit`, `IsSecretValue` guards, GUID keys and C-API
   sinks.
2. **Client branches**: `Addon.HAS_MIDNIGHT_API` for API code paths, `Addon.IS_FOREVER` explicitly for Forever
   (it is not Classic Era), `WOW_EVENTS` for new events.
3. **Dot vs. colon**: Modules/Elements are dot functions, Widgets colon methods.
4. **`tp_frame.Active`** must be true before using `tp_frame.unit.unitid` outside the unit-added path; clear
   references before wiping unit data.
5. **Settings and text**: new settings need defaults (and migrations when renamed); UI text goes through `L[...]`,
   never edit `Locales/*.lua` by hand; keep `UpdateSettings` of widgets cheap.

## Where to start for common tasks

| Task | Read |
| --- | --- |
| A nameplate shows the wrong unit, vanishes or keeps old data | [Nameplate lifecycle](nameplates/lifecycle.md) (revalidation, pooled unit frames) |
| Target/mouseover highlight, scale or alpha is wrong | [Target, soft target, mouseover and focus](nameplates/targets-mouseover-focus.md), [Modules](rendering/modules.md) |
| "attempt to ... a secret value" error | [Secret values](architecture/secret-values.md) |
| Castbar does not show, hide or color correctly | [Castbar and interrupts](nameplates/castbar.md) |
| Add or change a setting / option | [Options UI and propagating setting changes](settings/options-and-updates.md), [Database, profiles and migrations](settings/database-and-profiles.md) |
| Add a new widget | [Widget framework](widgets/framework.md) |
| Auras missing or wrong on Retail | [Auras widgets](widgets/auras.md) |
| Something only breaks on Forever or Classic | [Client and expansion compatibility](architecture/client-compatibility.md) |
| An event handler is not called | [Event system](architecture/event-system.md) |
| Prepare a release / changelog entry | [Release and packaging](workflows/release-packaging.md), [Development workflow](workflows/development.md) |

## Known issues found while writing this wiki

Code observations that are not verified in-game; each is described on the linked page:

- Unsubscribing the last widget from an event can unregister it for the core's main handler
  ([Event system](architecture/event-system.md#pitfall-unsubscribing-can-unregister-the-main-subscribers-event)).
- `Style:GetThreatStyle(unit)` called with a colon disables threat alpha/scale for custom styles and headline view
  ([Target, soft target, mouseover and focus](nameplates/targets-mouseover-focus.md#known-bug-threat-style-lookup-with-a-colon)).
- WoW event scripts of custom styles receive the payload instead of the event name
  ([Styles and custom styles](rendering/styles.md#observations-from-reading-the-code-unverified)).
- Possible stuck cast state after `UNIT_SPELLCAST_INTERRUPTED` without interrupter
  ([Castbar and interrupts](nameplates/castbar.md#observations-from-reading-the-code-unverified)).
- Absorb style check uses the style table instead of its name ([Elements](rendering/elements.md)).
- `OpenOptionsDialog` references an undefined variable ([Options](settings/options-and-updates.md)).
