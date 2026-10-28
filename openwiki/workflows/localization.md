---
type: workflow
title: Localization pipeline
description: How user-facing text in Threat Plates is localized - L[] usage, the generated enUS.lua, Source/localization_tool.py, the GitHub workflows that sync with CurseForge, the local machine-translation step for German, and the rules for developers.
tags: [localization, curseforge, translations, github-actions, python, enus]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-25T18:59:51.751Z
sources:
  - id: openwiki-source-2a0324af3c7c060ac88fc5fa
    resource: repo://.github/workflows/check_localization.yml
  - id: openwiki-source-2fbd01a0cc3409fac44f3ba8
    resource: repo://.github/workflows/publish_localization_to_curseforge.yml
  - id: openwiki-source-92110222dd71350d7d24202f
    resource: repo://.github/workflows/sync_localization_translations.yml
  - id: openwiki-source-4cfab5238eb54f18483ded92
    resource: repo://Init.lua
  - id: openwiki-source-fe621ab2278c291c76680ab5
    resource: repo://Source/Docs/LocalizationUpdateProcess.md
  - id: openwiki-source-d8fa7ef255102fa907b229b6
    resource: repo://Source/localization_tool.py
generated: { by: "claude-code", at: "2026-10-25T18:59:51.751Z" }
---

# Localization pipeline

## In the code

- All user-facing text is wrapped as `L["..."]` with `local L = Addon.L`. `Addon.L` is
  `LibStub("AceLocale-3.0"):GetLocale("TidyPlatesThreat")` (`Init.lua`).
- `Locales/*.lua` hold the tables; only locales loaded in `Locales/Locales.xml` are active (some files exist but
  are commented out there for translation quality reasons).
- `enUS` is registered as the silent default locale, so a key missing from a locale (or from `enUS.lua` itself)
  shows the key text in-game instead of an error.
- Keys that are built dynamically (`L[expr]`) must have their possible values listed in
  `Source/LocalizationSpecialPhraseKeys.lua`, which also documents key/value overrides
  (e.g. `L["Minuss"] = "Minors"`).
- **Never edit `Locales/*.lua` by hand** when adding, changing or removing a string - neither `enUS.lua` nor
  translations. The pipeline does it; manual edits only cause merge conflicts with the sync pull request.
- **Debug output is not localized.** Everything reachable only through `ChatCommandDebug` (`/tptp` debug
  commands, `/tptp version`) uses plain English literals.

Runtime text helpers (fonts per locale, number abbreviation, transliteration) live in `Modules/Localization.lua`
and are described in [Modules](../rendering/modules.md#localization-moduleslocalizationlua).

## `Source/localization_tool.py`

An AST-based tool (Python, `luaparser`) that replaced an older regex-based Lua/shell setup. Subcommands:

| Command | Does |
| --- | --- |
| `extract` | scan all addon `.lua` files for `L[...]` keys (plus the special-keys registry); warns about undocumented dynamic keys |
| `check` | fail if code uses keys missing from `enUS.lua`; print per-locale completeness (human-reviewed vs. machine-translated) |
| `generate-enus [--prune]` | regenerate `Locales/enUS.lua` from the scan; `--prune` drops keys no longer used |
| `upload --token` | upload enUS phrases to CurseForge (phrases no longer present are deleted there) |
| `pull --token [--locale]` | download translations for enabled locales without losing existing local ones (`preserve_existing_translations`) |
| `push-translation --locale deDE --token` | upload only entries still marked `--[[Machine translation --]]` |

Tests: `Source/test_localization_tool.py` (pytest) - the only automated tests in the repository.

## Flow

1. **Sync** (`.github/workflows/sync_localization_translations.yml`; on push to `main` or `release/*` with Lua or
   locale changes, weekly on Monday, or manually): `extract` -> `generate-enus --prune` -> `pull`, then opens or
   updates the pull request "Update localization files from CurseForge" on `localization-sync-<branch>`.
   `hotfix/*` is no trigger on purpose. It uses a personal access token (`PAT_TOKEN`) so that checks run on the
   bot's pull request without manual approval, and skips the run triggered by merging its own pull request.
   This workflow never writes to CurseForge.
2. **Check** (`.github/workflows/check_localization.yml`; every push and pull request with Lua/locale changes):
   runs `check`, fails on missing enUS keys, and posts a sticky pull request comment with the completeness
   table.
3. **German machine translation** (manual, local): if the comment lists new deDE gaps, run
   `Source/mt_translate_prompt.md` with an AI coding assistant on the sync branch. It skips false positives,
   keys of removed features and NPC/unit names used for matching, follows the established German terminology,
   marks new entries with `--[[Machine translation --]]`, shows the diff and waits for confirmation before
   pushing to the same branch. Deliberately not in CI (no API key in the repository).
4. **Merge** the sync pull request, preferably as squash merge (the self-skip guard matches the pull request
   title).
5. **Publish** (`.github/workflows/publish_localization_to_curseforge.yml`; push to `main` touching
   `Locales/enUS.lua`): `extract` -> `upload` -> `pull --locale deDE` (not committed; narrows races) ->
   `push-translation --locale deDE`. The only step that writes to CurseForge.

When a translator edits a machine-translated key on CurseForge, the next `pull` replaces the line without the
marker, so the key counts as human-reviewed. To accept a machine translation unchanged, remove its marker line
by hand - `pull` never adds markers.

## Consequence for developers

After adding a new `L["..."]` string on a feature branch, `check_localization.yml` fails on that branch and on
`develop` with "key(s) used in code but missing from Locales/enUS.lua" until a sync pull request for `main` or a
`release/*` branch is merged. That is expected; do not fix it by editing `enUS.lua`.

Housekeeping: sync pull requests of abandoned branches stay open and must be closed by hand; before merging an
old one, check that it does not overwrite translations made since. Full details:
`Source/Docs/LocalizationUpdateProcess.md`.

Related: [Development workflow](development.md), [Release and packaging](release-packaging.md).
