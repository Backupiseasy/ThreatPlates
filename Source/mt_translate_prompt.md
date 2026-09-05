# MT translate deDE prompt

Run this locally via Claude Code (not in CI - no `ANTHROPIC_API_KEY` is wired into any
workflow for this). It fills genuine deDE translation gaps in the sync PR opened by
`.github/workflows/sync_localization_translations.yml`, without ever touching an existing
community translation.

```
Translate new/untranslated deDE strings for the TidyPlates_ThreatPlates WoW addon.

0. Check out the sync PR's branch, not whatever branch is currently checked out locally:
   - If not given explicitly, find the branch: `gh pr list --search "Update localization
     files from CurseForge" --state open` (or ask the user which PR). The branch name is
     `localization-sync-<ref>` per sync_localization_translations.yml.
   - Note the current branch/HEAD so you can return to it afterward.
   - Run `git status` - if there are uncommitted changes, stop and ask the user how to
     proceed rather than switching branches over them.
   - `git fetch origin <branch>`, then `git checkout -B <branch> origin/<branch>` (creates
     or resets a local branch to exactly match the remote PR branch - do not build on a
     stale local copy if one already exists). Note: this only resets the branch's commit
     pointer - if the local branch already pointed at the same commit as origin (no
     divergence), it is a no-op for the working tree, and uncommitted local changes
     silently survive it. If the user has explicitly asked to discard uncommitted
     changes and restart, also run `git checkout -- <changed files>` (or `git reset
     --hard` if unsure what all is affected) to actually clear the working tree - do not
     assume the checkout -B above did this.
1. Run `python Source/localization_tool.py check` and shortlist every key present in
   `Locales/enUS.lua` whose `Locales/deDE.lua` entry is either missing entirely, or
   present with a value identical to its key.
   For every key in the second group (present, value == key), open `Locales/deDE.lua`
   and check the line immediately above that entry: only if it is exactly
   `--[[Translation missing --]]` is this a genuine untranslated gap (CurseForge's
   placeholder convention). If that comment is absent, the identical value is an
   intentional translation (a loanword kept in English on purpose, e.g. "Buffs" or
   "Tank") - leave it untouched and drop it from the shortlist.
   Expect a large fraction of the shortlist to be this false positive, not a real gap -
   e.g. 51 of 115 shortlisted keys in one run against PR #740.
2. Cross-check the remaining shortlist against actual code usage - a key can sit in
   `Locales/enUS.lua` (and pass step 1's placeholder check) while nothing in the addon
   references it anymore, e.g. leftover options from a removed feature that
   `generate-enus` never pruned by default. Reuse the tool's own scan instead of
   re-implementing it: a short script (see step 5 for the throwaway-script pattern)
   importing `scan_repository` and `registry_path_for`/`extract_registry_keys` from
   `Source/localization_tool.py` gives the same `used_keys` set `cmd_generate_enus`
   itself uses (static `L["..."]` calls plus `Source/LocalizationSpecialPhraseKeys.lua`
   registry entries). Any shortlisted key not in that set is dead, not a real gap - do
   not translate it. Flag these to the user instead and suggest running
   `generate-enus --prune` to drop them from `Locales/enUS.lua` (the corresponding
   `Locales/deDE.lua` placeholder disappears with them on the next check - no separate
   cleanup needed once the enUS key is gone). One run against PR #740 initially
   translated 27 dead keys this way (an entire removed nameplate-overlap feature) before
   `--prune` caught it after the fact - this check exists to catch it before
   translating, not after.
3. Before translating, run `grep -n 'Name = { Input = L\["' Database.lua` to get the
   full list of keys used as literal in-game unit/NPC name matches (e.g.
   `Name = { Input = L["Treant"], AsArray = { L["Treant"] } }`), and cross-check it
   against the remaining shortlist. For any overlap, do not guess a translation -
   getting Blizzard's official localized name wrong silently breaks the name-matching
   feature instead of just reading oddly. Skip these keys (leave them as gaps for a
   human to fill with the correct in-game name) and list them separately in the summary
   shown to the user.
4. For each remaining key, translate the English source value into German for a World
   of Warcraft nameplate/threat addon options UI (labels, tooltips, dropdown
   descriptions). Keep translations concise (this is options-panel UI, not prose).
   Before translating, search the *whole* of Locales/deDE.lua (not just alphabetically
   adjacent entries) for existing real (non-placeholder) translations that share the
   same terminology or word stem (e.g. grep "Dispellable"/"Magic"/"Curse" to find this
   project renders them "Bannbar"/"Magie"/"Fluch") and reuse that exact vocabulary. Also
   look for structurally similar sibling strings (same sentence shape, e.g. another
   "X is now |cff...STATUS!|r" message) and copy their established convention verbatim
   rather than deciding fresh - e.g. this project keeps "ON!"/"OFF!" in English inside
   otherwise-German status messages.
5. Preserve exactly, character-for-character, any of: %s/%d-style format specifiers,
   |cffXXXXXX...|r color codes, \n literals, and {...}-style placeholders.
6. Write each translation into Locales/deDE.lua as a single-line L["key"] = "translation"
   entry, immediately preceded by the comment line
   --[[Machine translation --]]
   (matches CurseForge's own --[[Translation missing --]] convention already handled by
   the existing tooling in Source/localization_tool.py - see MT_MARKER_COMMENT there).
   For more than a handful of entries, hand-editing scattered lines in an editor is
   error-prone (marker/entry pairs can slip out of sync, quoting can be broken) - prefer
   writing a small throwaway Python script that imports parse_lua_file/lua_quote from
   Source/localization_tool.py, locates each key's existing assignment line via the AST
   (same technique parse_mt_marked_keys uses), and replaces/appends lines programmatically;
   delete the script afterward. This keeps every write AST-quoted and verifiable by
   construction instead of by hand.
7. Run `python Source/localization_tool.py check` again to confirm no regressions, and
   that the new keys show up under "machine-translated pending review" rather than lumped
   into the human-translated count.
8. Show the user the full diff (git diff Locales/deDE.lua) and, alongside it, an
   English -> German overview table of every string translated in this run (one row per
   key), plus a short note of what was deliberately skipped and why (step 1's false
   positives, step 2's dead/unused-in-code keys, step 3's name-match keys). Wait for
   explicit confirmation before doing anything else in this step. Do not commit or push
   without that confirmation.
9. Once confirmed: git add Locales/deDE.lua, then
   git commit -m "Add machine-translated deDE strings for review", then git push origin
   <branch> (the exact branch checked out in step 0 - do not rely on "current branch"
   being right by this point). This adds a commit to the existing sync PR rather than
   creating a new one.
10. Clean up the local checkout: `git checkout <branch you noted in step 0>`, then
    `git branch -D <branch>` to delete the local copy of the PR branch. The remote PR
    branch (and the PR itself) is untouched by this - only the throwaway local tracking
    branch created in step 0 is removed, so a stale local branch doesn't linger or
    conflict with a future run.

Do not touch any other locale file. Do not modify already-translated (non-placeholder)
deDE entries under any circumstances - only fill genuine gaps.
```

## What happens to these entries afterward

- `.github/workflows/check_localization.yml` re-runs on the PR after this step's push and
  shows the marker-tagged keys as "machine-translated pending review" in its sticky
  comment, distinct from human-reviewed translations.
- Once the PR merges and that change reaches `main`,
  `.github/workflows/publish_localization_to_curseforge.yml` uploads exactly the
  marker-tagged deDE keys to CurseForge via `python Source/localization_tool.py
  push-translation --locale deDE --token "$CF_API_KEY"` - see that workflow and
  `select_mt_keys_for_push()` in `Source/localization_tool.py`.
- If a community translator supplies a real translation for a marker-tagged key on
  CurseForge before the next `pull`, that `pull` overwrites the marker-tagged line with
  CurseForge's export (which never carries the marker) - the key silently becomes
  human-reviewed with no extra bookkeeping needed.
