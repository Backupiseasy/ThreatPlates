# Localization Update Process

This page documents the end-to-end flow for keeping `Locales/*.lua` in sync with the code and with
CurseForge (CF) community translations — from a new `L["..."]` string appearing in code to it
showing up translated in-game. Two GitHub Actions workflows and one locally-run AI-assistant prompt
make up the pipeline; each step below is marked **Automatic** (CI, no action needed) or **Manual**
(a human has to do something).

For the deDE-specific machine-translation step itself, see
[`mt_translate_prompt.md`](../mt_translate_prompt.md). This page is the surrounding process it fits
into.

---

## Overview

```
new L["..."] in code
        │
        ▼
[Automatic] sync_localization_translations.yml   (push to main/release/*/hotfix/*, weekly, or manual)
        │  extract → generate-enus --prune → pull → open/update PR
        ▼
"Update localization files from CurseForge" PR
        │
        ├─ [Automatic] check_localization.yml posts a sticky comment: missing keys +
        │              per-locale completeness (human-reviewed vs. machine-translated pending review)
        │
        ├─ [Manual, only if deDE gaps are listed] run mt_translate_prompt.md locally
        │
        └─ [Manual] review diff, merge PR (squash-merge — see "Merge method" below)
                │
                ▼
        target branch (main/release/*/hotfix/*) updated
                │
                ▼ (only if the branch merges into `main`)
[Automatic] publish_localization_to_curseforge.yml   (push to main, path: Locales/enUS.lua)
        │  extract → upload (enUS → CF) → pull deDE → push-translation (MT deDE → CF)
        ▼
CurseForge project updated (new enUS phrases + MT deDE translations)
```

---

## Step 1 — [Automatic] `sync_localization_translations.yml`

Runs on push to `main`, `release/*`, `hotfix/*`; also weekly (catches CF-side community translation
edits with no accompanying code change) and via manual `workflow_dispatch`.

1. `extract` — scans all `.lua` files for `L["..."]` calls.
2. `generate-enus --prune` — regenerates `Locales/enUS.lua` mechanically from that scan (plus
   `Source/LocalizationSpecialPhraseKeys.lua` for documented dynamic-key overrides). `--prune` drops
   any enUS key the scan no longer finds — safe because every dynamic `L[expr]` site the AST scan
   can't resolve is expected to already have its possible keys documented in that registry file; see
   `cmd_generate_enus`'s docstring in `Source/localization_tool.py` for the full reasoning.
3. `pull` — downloads current CF translations for every `Locales.xml`-enabled locale.
4. Opens (or updates, if one is already open) a PR titled **"Update localization files from
   CurseForge"** on branch `localization-sync-<ref>`.

Nothing to do here unless something looks wrong in the resulting PR (see Step 2).

## Step 2 — [Automatic] `check_localization.yml` comment on the PR

Posts a sticky comment on the sync PR with:

- Any key used in code but missing from `enUS.lua` (should never happen if Step 1 ran cleanly).
- Per-locale completion, split as e.g.:
  `deDE : 928/1016 (91.3%) human-reviewed, +37 machine-translated pending review (95.0% total)  51 missing`
  — human-reviewed vs. machine-translated-pending-review counts come from whether a
  `--[[Machine translation --]]` marker comment sits directly above the entry in `Locales/deDE.lua`.

Read this to decide whether Step 3 is needed.

## Step 3 — [Manual, only if deDE has new gaps] Run the MT prompt locally

If the comment from Step 2 lists new/untranslated deDE strings, run
[`Source/mt_translate_prompt.md`](../mt_translate_prompt.md) via an AI coding assistant with local
git/shell access (e.g. Claude Code, or an equivalent agentic tool), pointed at the sync PR's branch.
It:

- Filters out false positives (keys that already carry an intentional English-loanword translation,
  not a real CF placeholder gap).
- Filters out keys still reachable only via a since-removed feature (dead code the scan no longer
  finds, `--prune` territory, not a translation gap) and keys used as literal in-game NPC/unit name
  matches (never guess those — a wrong Blizzard-official name silently breaks the match).
- Translates the remainder, reusing this project's established German terminology, and marks each
  new entry with `--[[Machine translation --]]`.
- Shows the full diff and an English → German overview table, and waits for explicit confirmation
  before committing/pushing anything.
- Commits and pushes onto the *same* PR branch (adds a commit to the existing sync PR, never opens
  a new one).

This is deliberately **not** wired into CI — no AI-provider API key is set up as a secret in this
repo for it. It runs under the maintainer's own AI-assistant session/subscription instead of a
metered API billed straight to the repo.

## Step 4 — [Manual] Review and merge the sync PR

Review the diff (mechanical enUS regeneration + pulled community translations + any MT deDE
additions) like any other PR, then merge.

**Merge method: prefer squash-merge over rebase-merge.** `sync_localization_translations.yml` has a
self-skip guard (`!contains(github.event.head_commit.message, 'Update localization files from
CurseForge')`) so merging its own PR back into a trigger branch doesn't immediately re-open a
duplicate PR. Squash-merge and ordinary merge-commit both default to the PR title as the resulting
commit message, so the guard matches. Rebase-merge instead lands each original commit with its own
message — if the last one isn't the PR title, the guard misses and the workflow harmlessly (but
uselessly) re-runs.

## Step 5 — [Automatic, main only] `publish_localization_to_curseforge.yml`

Triggers on push to `main` touching `Locales/enUS.lua` — i.e. only once the merged change from Step 4
reaches `main` (directly, or via a later `release/*` → `main` merge as part of the normal release
process; that later merge is outside this pipeline's scope).

1. `extract` (fresh scan of `main`).
2. `upload` — pushes new/changed enUS phrases to CF (`DeletePhrase`: a phrase no longer present is
   removed from CF too, e.g. after a wording fix).
3. `pull --locale deDE` — refreshes the runner's local `deDE.lua` from CF (not committed) so the
   next step only pushes keys still genuinely MT-pending, narrowing the window where a community
   translation landing in between could get overwritten.
4. `push-translation --locale deDE` — uploads *only* the still-`--[[Machine translation --]]`-marked
   deDE entries to CF (`DoNothing`: never deletes a community translation for a key outside that
   narrow set).

Nothing to do here — this is the only step in the whole pipeline that actually writes to CurseForge,
and it's fully automatic once code reaches `main`.

## After CF is updated

Once a community translator edits a marker-tagged key on CF, the next Step 1 `pull` overwrites that
line with CF's export (which never carries the marker) — the key silently becomes human-reviewed,
no manual bookkeeping needed anywhere in this pipeline.

---

## Manual housekeeping (not part of the automated flow)

- **Stale sync PRs on abandoned branches.** A `localization-sync-<branch>` PR only updates in place
  for pushes to the *same* branch; a hotfix/release branch that's merged forward and then abandoned
  (not deleted) leaves its sync PR open forever with nobody closing it. Check periodically
  (`gh pr list --search "Update localization files from CurseForge" --state open`) and close/merge
  as appropriate. Before merging one, check whether its "new" enUS strings were already
  machine-translated on another branch in the meantime — merging an old pull would overwrite a
  proper translation with CF's untranslated placeholder from before it existed.
- **Branch cleanup after merge.** `delete_branch_on_merge` is enabled repo-wide, so GitHub
  auto-deletes a `localization-sync-*` branch once its PR is merged (does *not* apply to PRs closed
  without merging, or to branches that already existed before this setting was turned on).
