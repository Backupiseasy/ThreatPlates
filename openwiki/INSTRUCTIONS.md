# OpenWiki brief for Threat Plates

Threat Plates (TidyPlates_ThreatPlates) is a World of Warcraft addon written in Lua/XML. It replaces
Blizzard's nameplates with customizable, threat-reactive nameplates. One codebase supports Retail
(Midnight), "WoW Forever" and the Classic clients (Classic Era up to Mists of Pandaria Classic).

## Audience

Developers who change or review the addon's code, including AI coding agents. Not players - there is no
need to explain how to use the addon in-game, except where it helps to understand a code path.

## Language

Write the wiki in English, like the code, the comments and `CLAUDE.md`.

## Priorities

Document these systems in depth, with their control flow, invariants and failure behavior:

1. Nameplate lifecycle (`Nameplate.lua`): plate creation, unit added/removed, recycling of plates and
   unit frames, target/soft-target/mouseover/focus handling, revalidation of stale unit data.
2. Event system (`EventService.lua`, `Compatibility.lua`): WoW events vs. internal TP events,
   subscription/unsubscription rules, per-expansion event gating.
3. Client and expansion compatibility (`Init.lua`, `Compatibility.lua`): the `IS_*`, `ExpansionIsAtLeast*`
   and `HAS_MIDNIGHT_API` flags, `GetExpansionLevel()`, and how "WoW Forever" differs from Classic Era.
4. Secret values on Midnight and Forever: which APIs return them, the guard patterns the code uses, and the
   safe C-API pass-through sinks.
5. Visual pipeline: Styles -> Modules -> Elements -> Widgets, with the different registration and calling
   conventions of each layer (dot vs. colon functions) and the order in which `Styles/Styles.lua` drives
   them.
6. Widgets framework (`Widgets/WidgetHandler.lua`) and the larger widgets (Auras, especially
   `AurasWidgetMidnight.lua`, Quest, Threat, ComboPoints, Resource, BossMods).
7. Settings: AceDB profiles, defaults (`Database.lua`, `Constants.lua`), migrations, and how option
   changes reach live nameplates (`Options.lua`, `Addon:ReloadTheme()`).
8. Development workflows: lint (`luacheck`), manual testing in-game, localization pipeline
   (`Source/`, `.github/workflows/`), changelog workflow, branching and release packaging (`.pkgmeta`,
   TOC).

## Sources to use

- `CLAUDE.md` holds verified, hard-won knowledge (pitfalls, historical bugs, in-game verifications). Use
  it, but verify each statement against the current code before stating it as fact.
- `Source/Docs/` and `Source/Plans/` contain design notes and open plans. Mark content from plans as
  planned or open, not as implemented behavior.

## Do not

- Do not document third-party libraries in `Libs/` beyond how the addon uses them.
- Do not document the content of `Locales/*.lua`; they are generated.
- Do not describe commented-out legacy code (e.g. the old event handler in `Widgets/WidgetHandler.lua`)
  as active behavior.
- Do not mention private or local-only addons or tools.
