# "WoW Forever" Compatibility Findings

A running audit of "WoW Forever" - an official Blizzard client/product running parallel to Retail and WoW
Classic, not a third-party client - that TidyPlates_ThreatPlates was found to misbehave on. Companion to the
Midnight secret-value audit in `CLAUDE.md`; read that first for the guard-pattern catalogue this document
assumes.

## Client identification (raw signals, via `/tptp version`)

| Signal | Value |
| --- | --- |
| `WOW_PROJECT_ID` | `1` (`== WOW_PROJECT_MAINLINE`) |
| `WOW_PROJECT_CLASSIC` | `2` |
| `GetClassicExpansionLevel()` | `0` (`LE_EXPANSION_CLASSIC`, Vanilla) |
| `GetServerExpansionLevel()` | `0` |
| `GetBuildInfo()` | version `1.60.1`, build `69913`, Interface `16001` |
| `.build.info` product | `wow_classic_beta` |
| `issecretvalue` | present - unit data (health, etc.) comes back as secret values |

## Root cause

The client reports `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` - a combination Blizzard's other Classic
Era/TBC/Wrath/Cata/Mists clients don't produce (those all report `WOW_PROJECT_ID == WOW_PROJECT_CLASSIC`) -
while `GetClassicExpansionLevel()` correctly reports Vanilla-level content. This is expected for this
client/product specifically: "WoW Forever" is Blizzard's own new version running parallel to Retail and WoW
Classic, not a spoofed or third-party report. The
client runs Blizzard's modern (Midnight-era) engine end to end: full secret-value restrictions, and (per
`/tptp debug MidnightAPI`, see below) **100% of the Midnight-exclusive APIs this addon depends on are
present**. Only the *content/ruleset* is old (Vanilla); the *engine/API surface* is fully modern.

This addon's code conflated those two axes almost everywhere (`Addon.ExpansionIsAtLeastMidnight` was
used both for "is the ruleset Midnight" and "does the engine have Midnight's API/secret-value
restrictions"), which is what caused every crash below.

## New flags (`Init.lua`)

| Flag | Meaning | Formula |
| --- | --- | --- |
| `Addon.IS_CLASSIC` | Vanilla-level content | `WOW_PROJECT_ID == WOW_PROJECT_CLASSIC` **or** `GetClassicExpansionLevel() == LE_EXPANSION_CLASSIC` |
| `Addon.IS_MAINLINE` | Retail ruleset (not the Forever product) | `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` **and not** `Addon.IS_FOREVER` |
| `Addon.IS_FOREVER` | The WOW_PROJECT_ID-vs-GetClassicExpansionLevel mismatch itself, i.e. the "WoW Forever" product specifically | `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` **and** `GetClassicExpansionLevel()` resolves to a real level |
| `Addon.HAS_MIDNIGHT_API` | Engine has Midnight's API/secret-value surface, regardless of ruleset | `Addon.ExpansionIsAtLeastMidnight` **or** `Addon.IS_FOREVER` |

**Rule of thumb:** use `Addon.HAS_MIDNIGHT_API` for "which code path handles this API/secret-value
correctly", use `Addon.ExpansionIsAtLeastMidnight` only for genuine ruleset/feature decisions (e.g. the
intentionally-disabled features listed in `CLAUDE.md`).

## Diagnostic chat commands added

| Command | What it does |
| --- | --- |
| `/tptp version` | Prints detected client version/expansion, `Addon.IS_*` flags, and the raw signals table above. |
| `/tptp debug Compatibility` | Tries registering every event in `WOW_EVENTS` on a throwaway frame via `pcall`; reports mismatches against the table. Blind spot: can't detect `ADDON_ACTION_FORBIDDEN` (taint-context-dependent, not a plain Lua error - see below). |
| `/tptp debug MidnightAPI` | Existence-checks Midnight-exclusive APIs this addon's code depends on (grouped by subsystem), no calls made. Also lives in `Commands.lua` now (moved from `Compatibility.lua`). |

### `/tptp debug MidnightAPI` result on "WoW Forever": **33/33 available**

All of `issecretvalue`, `CreateUnitHealPredictionCalculator`, `UnitGetDetailedHealPrediction`, the 5
`Enum.Unit*Mode` heal-prediction enums, `UnitHealthPercent`, `C_CurveUtil.*` (3 functions),
`Enum.LuaCurveType`, `C_ClassColor.GetClassColor`, `C_Spell.GetSpellInfo`, `C_PvP.IsSoloShuffle`,
`C_TooltipInfo.GetUnit`, `Enum.TooltipDataLineType`, all 6 `C_UnitAuras.*` functions,
`GetServerExpansionLevel`, `UnitSpellTargetName`, `UnitSpellTargetClass`, `UnitChannelDuration`,
`UnitCastingDuration`, `WrapTextInColor`, `GetClassColor`, the `SetAlphaFromBoolean` frame mixin method,
and the `SetTimerDuration` frame mixin method are present. **This client's engine has full Midnight API
parity across every subsystem this addon uses** - there is no known API this addon needs that Forever
lacks. This confirms fix #11 (castbar) is fully safe, not just crash-free.

## Confirmed fixes this session

| # | File:Line | Symptom | Fix |
| --- | --- | --- | --- |
| 1 | `Elements/StatusText.lua` (`TextHealthPercentColored`, `TextAll`, alpha-fade selector, curve creation) | Lua error comparing secret `unit.health` | Originally fixed with inline `IsSecretValueTP` guards (degraded gracefully); later superseded - all 4 branch selectors converted to `Addon.HAS_MIDNIGHT_API` so Forever reuses Midnight's real curve-based implementation, and the now-dead inline guards were removed again |
| 2 | `Modules/Color.lua` (`GetColorByHealthDeficit`, curve creation) | Same, in the legacy branch's health-percent color calc | Originally an inline guard falling back to full-health color when secret; later superseded the same way as fix #1 - converted to `Addon.HAS_MIDNIGHT_API`, dead guard removed |
| 3 | `Init.lua` (`Addon.GetSpellInfo` selection) | `attempt to call a nil value` (`_G.GetSpellInfo` doesn't exist) | `elseif Addon.IS_MISTS_CLASSIC or Addon.IS_FOREVER then` picks the `C_Spell.GetSpellInfo` branch (3-way split, not literally `HAS_MIDNIGHT_API` - Mists Classic needs the same branch but isn't "Midnight API") |
| 4 | `Nameplate.lua:131` (legacy-classic quirks block) | Same root cause, would have crashed on next reload (`_G.GetSpellInfo` in a static load-time loop) | `if Addon.IS_CLASSIC and not Addon.HAS_MIDNIGHT_API then` |
| 5 | `Compatibility.lua` (`WOW_EVENTS.UNIT_HEALTH` / `UNIT_HEALTH_FREQUENT`) | Healthbar/status text stopped updating (`UNIT_HEALTH_FREQUENT` doesn't exist on the modern engine) | `Addon.ExpansionIsAtLeastMists or Addon.IS_FOREVER` (different axis than Midnight - this is the Mists-era event changeover, not migrated to `HAS_MIDNIGHT_API`) |
| 6 | `Elements/StatusText.lua:545,554` (event subscribe selection) | Same | `and not Addon.HAS_MIDNIGHT_API` |
| 7 | `Compatibility.lua` (`WOW_EVENTS.COMBAT_LOG_EVENT_UNFILTERED`) | `ADDON_ACTION_FORBIDDEN` calling `RegisterEvent` during addon init | `not Addon.HAS_MIDNIGHT_API` |
| 8 | `Elements/Healthbar.lua` (absorb rendering, 6 sites: creation, selection, frame levels, config-mode preview) | Lua error comparing secret `health`/`health_max` in the legacy absorb code | All 6 sites converted to `Addon.HAS_MIDNIGHT_API` - Forever now runs the full Midnight-safe absorb pipeline (`CreateUnitHealPredictionCalculator`, `OvershieldBar`, `MidnightAbsorbSpark`) instead of raw arithmetic |
| 9 | `Widgets/QuestWidget.lua` (file-level gate, objective regex lookup, `IsQuestUnit` tooltip-line parsing x2) | Whole widget never loaded on a Classic-level `Addon.GetExpansionLevel()`; would then have hit a `nil`-index crash in the objective regex table, and misparsed real `C_TooltipInfo.GetUnit()` line data with the old `.leftColor` heuristic | File-gate and regex-table lookup: `or Addon.IS_FOREVER` / `Addon.IS_FOREVER and "MAINLINE" or ...`; both `.type`-based tooltip-line branches: `Addon.HAS_MIDNIGHT_API`. Also fixed the sibling `Addon.C_TooltipInfo_GetUnit_Quest`/`_NPCRole` assignment (`Compatibility.lua`, gated on `Addon.ExpansionIsAtLeastDF`, same issue) and `Addon.ShowQuestUnit` (gated on `Addon.ExpansionIsAtLeastMists`) - both now also check `Addon.IS_FOREVER`. User-confirmed: quest tooltips work on Forever. |
| 10 | `Widgets/AurasWidget.lua:6` / `Widgets/AurasWidgetMidnight.lua:6` (widget selection) | Live crash: `GetAuraSlots(): Auras cannot be accessed when secret while tainted by 'TidyPlates_ThreatPlates'` - the old widget was active, hit a taint restriction (not a plain Lua error) the rebuilt Midnight widget was specifically built to avoid | Both file-top guards swapped to `Addon.HAS_MIDNIGHT_API` (was: 🟠 High open finding below, now confirmed and fixed) |
| 11 | `Nameplate.lua` `OnStartCasting` (castbar timing) | Live crash: arithmetic on secret `startTime` in the legacy castbar-timing branch | `Addon.HAS_MIDNIGHT_API` picks the Midnight-safe `castbar:SetTimerDuration(...)` path instead of raw `startTime`/`endTime` arithmetic. This path also calls `UnitSpellTargetName`, `UnitSpellTargetClass`, `UnitChannelDuration`, `UnitCastingDuration`, `WrapTextInColor`, `GetClassColor`, and the `castbar:SetTimerDuration(...)` frame method - all 7 confirmed present via the 33/33 `/tptp debug MidnightAPI` re-run above. |
| 12 | `Nameplate.lua` `OnStartCasting` (`CastTriggerCheckIfActive`/`CastTriggerUpdateStyle`) | Latent: `CastTriggers[spell_id] or CastTriggers[spell_name]` keys a table with secret `spell_id`/`name` - not yet triggered live only because `Addon.ActiveCastTriggers` was `false` in the crash report | Both calls skipped `if not Addon.HAS_MIDNIGHT_API` (matches why this custom-plate-by-cast feature is already skipped on real Midnight - it fundamentally can't key a table on a secret spell id) |
| 13 | `Nameplate.lua` `SetUnitAttributeTargetMarker` + its `RAID_TARGET_UPDATE` comparison | Latent: `else` branch used `raid_icon_index` (potentially secret) as a `TARGET_MARKER_LIST`/`MENTOR_ICON_LIST` table key; the companion `~=` comparison of the result in `RAID_TARGET_UPDATE` would also be unsafe once `unit.TargetMarkerIcon` can be secret | Both converted to `Addon.HAS_MIDNIGHT_API` |
| 14 | `Nameplate.lua` `SetShownBlizzardPlate` / its `hooksecurefunc(..., "Show", ...)` companion / `CanChangeHitTestPoints` gate | Latent: legacy branch calls plain `SetShown()`/`Show()`/`Hide()` on Blizzard's native nameplate `UnitFrame`, which `CLAUDE.md`'s own "Use SetAlpha(0/1) instead of Show()/Hide()" rule exists specifically because these can hit frame-protection/taint errors on the modern engine (same category as the `ADDON_ACTION_FORBIDDEN` in fix #7) | All three converted to `Addon.HAS_MIDNIGHT_API` |
| 15 | `Compatibility.lua` (`WOW_EVENTS.UNIT_SPELLCAST_INTERRUPTED` / `_SENT`) + `Nameplate.lua`'s `UNIT_SPELLCAST_CHANNEL_STOP` dispatch | Same "Retail/Midnight-only code" pattern as fix #5 - these events/the routing to `Addon:UNIT_SPELLCAST_INTERRUPTED` were gated on ruleset instead of engine | All three converted to `Addon.HAS_MIDNIGHT_API` |
| 16 | `Compatibility.lua` (`Addon.UnitIsUnit` / `Addon.UnitIsPVP` definitions) | Was the 🔴 Critical open finding below - not yet confirmed by a live crash, fixed proactively while working through the castbar cluster since it's the addon's most-used safe-wrapper pair | Both converted to `Addon.HAS_MIDNIGHT_API` |
| 17 | `Modules/Color.lua` (`GetSituationalColorForHealthbar`/`GetSituationalColorForName`'s raid-mark coloring) | Latent, discovered as a direct side effect of fix #13: `SettingsBase.settings.raidicon.hpMarked[unit.TargetMarkerIcon]` keys a table with `unit.TargetMarkerIcon`, which fix #13 made carry the raw (potentially secret) value on Forever | Both `use_target_mark_color` gates converted to `Addon.HAS_MIDNIGHT_API` (raid-mark-based healthbar/name coloring is disabled there, same as on real Midnight) |
| 18 | `Widgets/AurasWidgetMidnight.lua` `InitializeAuraButton` + `ReapplyLiveAuraButtonSettings` (dispel-border re-color) | Live crash on re-opening Options (confirmed out of combat, in an unrestricted rest zone - **not** secret-value/taint-related): `Display element '...DispelBorder...' has already been added` from `AddDispelTypeTexture` right after `RemoveDispelTypeTexture(1)` on the same button, reproduced on ~90+ buttons at once (not intermittent). **Root cause found**: Warcraft Wiki documents an upcoming Blizzard API contract change to `AddDispelTypeTexture`/`RemoveDispelTypeTexture` - pre-change, `AddDispelTypeTexture` returns an index and `RemoveDispelTypeTexture(index)` takes that index; post-change, `AddDispelTypeTexture` returns nothing, `RemoveDispelTypeTexture(region)` takes the region object itself, and `AddDispelTypeTexture` now errors on a duplicate region (it didn't before). **Not yet live on retail** (retail was on 12.1.0 as of this session) - the client this reproduced on already has the newer contract, meaning it tracks a build ahead of live retail (see "Publishing / TOC compatibility" above re: its `wow_classic_beta` product/build-track). The old `RemoveDispelTypeTexture(1)` call never matched the real registration on such a client, so the border was never removed before the next `AddDispelTypeTexture` re-added it. Uncaught, this broke the entire `WidgetHandler:InitializeAllWidgets()` call and everything after it in `Options.lua`'s open sequence, because `Addon.ExecuteAfterCombatEnds` runs synchronously out of combat with no `pcall` boundary above it. | `InitializeAuraButton` now stores whatever `AddDispelTypeTexture` returns (`auraButton.DispelBorderRegistration` - an index pre-change, `nil` post-change); `ReapplyLiveAuraButtonSettings` removes using that stored value (falling back to the region object itself when `nil`), so removal self-adapts to either API generation without a hardcoded version check. **Confirmed live**: user reports no errors currently known, including via `/tptp` (which reopens Options, the original repro path) - upgraded from "Hopefully fixed" to "Fixed" in the changelog. The `pcall` safety net added alongside this fix was later removed on explicit maintainer instruction ("pcall versteckt Fehler, die aufgezeigt werden müssen") now that the fix is confirmed working - a failure here should surface as a visible error (signalling the API-generation detection is wrong for that client), not be silently swallowed. |
| 19 | `Elements/Castbar.lua:154,165` (`UpdateForCast`'s `InterruptShield`/`InterruptBorder`/`InterruptOverlay`) | Was the 🟡 open finding below - not confirmed by a live crash, fixed on explicit maintainer instruction to assume Forever behaves like Midnight here (`show = unit.CastIsNotInterruptible` can be secret; the legacy branch's `SetShown()`/`Show()`/`Hide()` aren't documented `SecretArguments = "AllowedWhenTainted"` the way `SetAlphaFromBoolean` is) | Both converted to `Addon.HAS_MIDNIGHT_API`. At the time this was written, `GetCastbarColor` (line 115) was believed safe as-is because its legacy branch only does a bare truthy `if`/`elseif` check on `unit.CastIsNotInterruptible` - **this assumption was disproved live, see fix #20**. |
| 20 | `Elements/Castbar.lua:124` (`GetCastbarColor`'s branch selector, `elseif unit.CastIsNotInterruptible then`) | Live crash: `attempt to perform boolean test on field 'CastIsNotInterruptible' (a secret boolean value, while execution tainted by 'TidyPlates_ThreatPlates')` - directly disproves the fix #19 assumption (and the guard-pattern catalogue's former blanket claim) that a bare truthy check on a secret value is always safe | Branch selector converted to `Addon.HAS_MIDNIGHT_API`, same as fix #19 - Forever now uses the Midnight-safe color path instead of the legacy truthy check. **`CLAUDE.md` corrected**: a secret *boolean* field read in a branch condition (as opposed to a plain truthy/non-nil check on a value of unknown type) can still throw when execution is tainted - the "truthiness is always safe" guidance was too broad and is now scoped accordingly. This also reopens the ⚪ unreviewed list below as a real risk category, not just a completeness nice-to-have: any other bare `if`/`elseif unit.SomeBooleanField then` on a value that can be secret is a candidate for the same crash. |
| 21 | `Addon.lua` `OnInitialize` (AceDB creation) - **first attempt, confirmed NOT sufficient, see #22** | Root cause of the maintainer-reported "options don't persist across reload" bug, confirmed via Discord by another addon author hitting the same thing: `ThreatPlatesDB` (SavedVariables) can still be `nil` when `ADDON_LOADED` fires (the event that triggers `OnInitialize`) - only reliably populated by `PLAYER_LOGIN`. `LibStub('AceDB-3.0'):New(...)` then silently creates a blank in-memory profile instead of loading the real saved one, and the next save (e.g. the very next `/reload`) overwrites the real data on disk with that blank profile. Confirmed via direct inspection of `WTF/Account/.../SavedVariables/TidyPlates_ThreatPlates.lua` on the maintainer's live client showing a stripped-down profile after a reload where settings had just been changed. Ruled out before finding the real cause: file permissions/ownership (checked directly, fine), a Mac/OS-specific issue (no evidence), a keybind toggling settings (maintainer confirmed "nothing bound"). | Factored AceDB creation out of `OnInitialize` into `CreateAceDatabase()`. If `ThreatPlatesDB == nil` at `OnInitialize` time, a one-shot `PLAYER_LOGIN` handler re-runs `CreateAceDatabase()` plus everything that depends on the real profile once the real SavedVariables are actually available. **Maintainer-confirmed live: did NOT fix the bug** ("Laden von SV in PLAYER_LOGIN hat das Problem nicht behoben") - see fix #22 for the actual root cause of why this didn't work and the corrected fix. |
| 22 | `Addon.lua` `OnInitialize`/`InitializeAddonNow` (AceDB creation, corrected) | Why fix #21 didn't work: `AceDB-3.0.lua`'s `AceDB:New()` does `tbl = _G[name]; if not tbl then tbl = {}; _G[name] = tbl end` - the moment `LibStub('AceDB-3.0'):New('ThreatPlatesDB', ...)` sees the global as `nil`, it creates a blank table and assigns it into that global itself, synchronously. Fix #21 called `CreateAceDatabase()` unconditionally in `OnInitialize` even when `ThreatPlatesDB` was `nil`, which means `ThreatPlatesDB` was never `nil` again for the rest of that session, regardless of whether the client ever actually injected the real saved data afterwards - the later PLAYER_LOGIN "recovery" pass could no longer distinguish "real data arrived" from "still reading back our own blank placeholder" using a plain nil-check, and most likely kept re-saving that blank profile right back over the real one on the next `/reload`. Diagnostic that found this: an unconditional print at the top of `OnInitialize` and again in the PLAYER_LOGIN handler, both just checking `ThreatPlatesDB == nil` - confirmed `true` then `false` on the maintainer's client, which looked like the recovery was working, but a bare non-nil check can't tell a real profile apart from AceDB's own blank one. | Restructured so `OnInitialize` never calls `CreateAceDatabase()` (or anything depending on `Addon.db`, now factored into `InitializeAddonNow()`) while `ThreatPlatesDB` is `nil` - the entire body is deferred to a one-shot `PLAYER_LOGIN` handler instead, so the addon never touches/creates the SV global before the client has a chance to populate it with the real data. Since deferring past `Addon:EnableEvents()` means the addon's own `Addon:PLAYER_LOGIN()` handler (`Nameplate.lua`) would miss the real event through the normal dispatch (it already fired by the time this runs), it's invoked directly at the end of the deferred path to compensate. **Confirmed live: fixes the "AceDB self-pollution" problem, but does NOT fix the underlying persistence bug** - see fix #23. Never touching the global early is still strictly correct and is kept. |
| 23 | (finding, confirmed NOT addon-fixable) `Addon.lua` diagnostic watcher | `ThreatPlatesDB` never loads real data into the Lua environment on this client, confirmed on **both** `/reload` and a full logout/login (character-select cycle) - not `/reload`-specific. A purely observational watcher (no side effects - see `Addon.lua`, top of file) polled `ThreatPlatesDB`'s table identity every 0.2s for 30s after `ADDON_LOADED`, across three `/reload` tests and one full relog. Every time, **exactly one** identity change occurred (~2.1-6.8s after `ADDON_LOADED`, timing varies more with a full login, understandably), and was confirmed via direct object-identity comparison (`Addon.Debug_SelfCreatedSV`, set right after `CreateAceDatabase()` returns) to be **fix #22's own blank AceDB creation**, never an external reassignment. No second identity change ever occurred in the rest of each 30s window, on any of the four tests. More severe than the original Discord report ("populated by PLAYER_LOGIN") suggested. The SavedVariables *file* itself is confirmed correct and current on disk (direct inspection of `WTF/Account/.../SavedVariables/TidyPlates_ThreatPlates.lua` showed the just-made change present) - saving works fine; only loading is affected, and apparently unconditionally so on this client, not just after `/reload`. | **No addon-side fix exists.** Addons have no file-I/O API to read SavedVariables themselves - the C-side client is the only thing that can inject that data into the Lua global, and it isn't doing so on this client within any observed timeframe (30s, `/reload` or full relog). This is very likely a genuine bug in the "WoW Forever" client itself, outside this addon's control - worth reporting upstream to whoever maintains that client/product. **Update**: on maintainer instruction, fixes #21 and #22 (the `CreateAceDatabase()`/`InitializeAddonNow()` restructuring in `Addon.lua`, and the diagnostic watcher) were **reverted entirely** rather than kept as "correct but insufficient" - `Addon.lua` is back to its pre-investigation state. Rationale: neither fixed the actual bug, so keeping the extra indirection/complexity around `OnInitialize` had no upside; `git log`/this document are the record of what was tried, not the live source. If revisited, start from `Addon.lua`'s original single `OnInitialize()` body, not from the reverted `InitializeAddonNow()` structure. The maintainer-facing conclusion stands regardless of the code revert: settings changes save correctly, but silently revert to defaults every session on this client until Blizzard/the client fixes SavedVariables loading. |

The "suboptimal but safe" state from the previous revision of this document (fixes #1/#2 using inline
guards instead of reusing Midnight's curve-based implementation) has been resolved - see the updated
fixes #1/#2 above.

### Reverted (false positives, not actually broken)

Nine `WOW_EVENTS` entries (`COMBAT_LOG_EVENT_UNFILTERED`, `GROUP_LEFT`, `GROUP_ROSTER_UPDATE`,
`QUEST_ACCEPTED`, `QUEST_DATA_LOAD_RESULT`, `QUEST_LOG_UPDATE`, `QUEST_REMOVED`, `QUEST_WATCH_UPDATE`,
`UNIT_AURA`, `UNIT_PORTRAIT_UPDATE`) had been manually set to `false` before `/tptp debug Compatibility`
existed, on suspicion. The tool showed they all register without error - reverted to their original
values.

### Non-Forever bugs found and fixed along the way

- `Commands.lua`: a stray `print(event)` in `Addon:RegisterEvent` spammed chat on every real event
  registration - removed.
- `Compatibility.lua`: dead code referencing a commented-out `DebugUnknowEvents` local - removed.
- `Commands.lua`: a dead, unreachable duplicate `elseif command == "version"` branch - renamed the live
  code to `version-history` (kept as a manual `CurrentVersionIsOlderThan` test, per "no automated test
  runner" in `CLAUDE.md`).

## Open findings - not yet investigated/fixed

Ranked by how likely they are to actually break on "WoW Forever" (or a similar client), based on API
knowledge from this session but **not yet confirmed by a live crash report**.

**Status as of this session's end**: user reports no errors currently known during general play, including
via `/tptp` (reopens Options). The only remaining previously-open item (🟡 Castbar `ShowInterruptShield`) has
since been fixed on explicit instruction - see fix #19 above. No 🔴/🟠/🟡 items remain open from that pass;
see 🟠 below for a new risk category found afterward, plus the ⚪ unreviewed table.

### 🟠 New risk category: bare truthy checks on secret *boolean* fields

Fix #20 (`Castbar.lua:124`) disproved this document's and `CLAUDE.md`'s former blanket claim that
`if secret_value then` is always safe with secret values. It's safe for plain truthy/non-nil checks, but a
secret **boolean** field read directly in a branch condition (`if unit.SomeBooleanField then` /
`elseif ... then`) can still throw "attempt to perform boolean test on field '...' (a secret boolean value,
while execution tainted by ...)". Not yet done: a systematic grep for other bare-boolean-field branch
conditions on values that can be secret (candidates: other `unit.*` boolean fields set from secret-prone
APIs, similar to `CastIsNotInterruptible`) - deferred to "reactive, as new crash reports come in" like the ⚪
table below, but flagged here explicitly since it's a newly-discovered class of risk, not just unreviewed
completeness.

### ⚪ Unreviewed - remaining `Addon.ExpansionIsAtLeastMidnight` occurrences by file

Not yet gone through individually. Many are almost certainly fine as-is (deliberate ruleset/feature
decisions, or pure UI-visibility toggles with no secret-value exposure) rather than API-surface bugs -
`Options.lua`'s 45 in particular are believed to be options-panel `hidden = ...` toggles only.

| File | Count | Notes |
| --- | --- | --- |
| `Options.lua` | 45 | Believed to be UI-visibility toggles only (low risk) |
| `Compatibility.lua` | 0 remaining | Fully reviewed and converted (fixes #7, #15, #16) |
| `Nameplate.lua` | 2 remaining (NPCID parsing, `PlatesByGUID` cleanup) | Reviewed - see fixes #4, #11-15. NPCID-from-GUID parsing left as `Addon.ExpansionIsAtLeastMidnight`: `CLAUDE.md` documents this as an intentional Midnight exclusion (accuracy, not a crash risk), not something to extend to Forever without being asked. `PlatesByGUID[guid] = nil` cleanup on `NAME_PLATE_UNIT_REMOVED` left as-is: no evidence `guid` itself is secret (it wasn't in any of this session's crash dumps) - looks like an architectural simplification for Midnight, not a per-instance secret-value risk. |
| `Modules/Color.lua` | 0 remaining | Fully reviewed and converted (fixes #2, #17) |
| `Elements/StatusText.lua` | 1 remaining (`GetUnitSubtitle`, NPC-role tooltip color stripping) | Reviewed but **not fixed** - separate, pre-existing (not Forever-specific) inconsistency: this check is keyed on `Addon.ExpansionIsAtLeastMidnight` but the tooltip data source it reacts to (`Addon.C_TooltipInfo_GetUnit_NPCRole`) is keyed on `Addon.ExpansionIsAtLeastDF or Addon.IS_FOREVER` (fix #9) - was already inconsistent for any DF-through-TWW-era Mainline client before Midnight or Forever existed. Out of scope here; no live crash evidence. |
| `Constants.lua` | 5 | Unreviewed |
| `Widgets/QuestWidget.lua` | 2 remaining (667, 677) | Reviewed - see fix #9 above. `GROUP_ROSTER_UPDATE`/`GROUP_LEFT` subscriptions only feed the legacy `.leftColor` group-tracking path, unused once `Addon.HAS_MIDNIGHT_API` selects the `.type`-based path; left as harmless dead-weight subscriptions rather than converted |
| `Modules/Threat.lua` | 3 | Unreviewed |
| `Styles/Styles.lua` | 2 | Unreviewed |
| `Modules/Localization.lua` | 2 | Likely the intentionally-disabled name-abbreviation feature (`CLAUDE.md`) - do not "fix" without explicit request |
| `Widgets/StealthWidget.lua` | 1 | Disables the whole widget on Midnight - deliberate, per file-top guard |
| `Widgets/HealerTrackerWidget.lua` | 1 | Intentionally disabled on Midnight per `CLAUDE.md` - do not re-enable without explicit request |
| `Widgets/BossModsWidget.lua` | 1 | Unreviewed |
| `Elements/TargetMarker.lua` | 1 | Unreviewed |
| `Elements/Name.lua` | 1 | Unreviewed |
| `Database.lua` | 1 | Profile-migration `Version` flag - ruleset-scoped, low risk |

## Publishing / TOC compatibility

Forever's reported Interface (`16001`, per `GetBuildInfo()`'s own 4th return value, confirmed via
`/tptp version` - not a value this addon computes itself) **is now in**
`TidyPlates_ThreatPlates.toc`'s `## Interface:` line (`120100, 11509, 20506, 50504, 16001`), added on
explicit maintainer request, overriding the original recommendation below to leave it out. The reasoning
against it still stands as a known, accepted trade-off, not a mistake:

- Forever's own version climbs over time (per the project's name), so the `16001` entry will go stale with
  no warning - re-check via `/tptp version` if reports come in of the addon being marked out of date on
  that client again.
- Meaningless to CurseForge/WoWInterface/Wago/Retail/Classic - just an extra, inert entry in the public
  manifest for the vast majority of users.
- Before this change, the addon already loaded and ran on Forever regardless (confirmed by this entire
  document's worth of live crash reports), because Blizzard's own `checkAddonVersion` CVar / "Load out of
  date AddOns" checkbox (AddOn List screen, character select) bypasses an Interface mismatch - either the
  user had it enabled, or Forever's client has that check relaxed/disabled itself. Adding `16001` removes
  the need for that checkbox specifically for this addon on that client.
- The `BigWigsMods/packager` release action (`-e -l -n "ThreatPlates-{project-version}"` in
  `_package_release.yml`) does not validate or reject Interface numbers either way - it passes `16001`
  through unmodified, no packager changes needed.

**Update**: fix #18 below found direct evidence that Forever isn't merely running an older snapshot of
Midnight's API surface - it tracks a build genuinely *ahead of* live retail (an unreleased
`AddDispelTypeTexture`/`RemoveDispelTypeTexture` API contract change, not live on retail as of this session,
already active on Forever). Consistent with its `wow_classic_beta` product/build-track. This means "confirmed
present on Forever" is not a permanent guarantee even for APIs that exist today - Forever may pick up further
upstream Blizzard API changes before they reach live retail, ahead of when this addon's own retail-targeted
code gets updated for them. This is orthogonal to the TOC's `16001` entry above (that only controls whether
the client loads the addon *at all* - it says nothing about which APIs that specific load has); code-level
compatibility still has to come from `Addon.HAS_MIDNIGHT_API`-style capability flags, or better, feature-
detecting the specific API shape actually used (as fix #18 now does for this one), which age better than any
snapshot of "what Forever currently reports."

## Recommended next steps

1. Fix #22 (SavedVariables/`PLAYER_LOGIN` deferred init, corrected) is implemented and syntax-checked but
   **not yet confirmed in-game** - fix #21 looked plausible from its own diagnostic output too and still
   turned out not to work, so this needs an actual `/reload` test (change a setting, reload, verify it
   stuck), not just a repeat of the same nil-check-based diagnostic.
2. Fix #19 (Castbar interrupt shield/border/overlay) was applied on assumption, not diagnosed from a live
   crash or confirmed after the fix - worth a live interrupt-shield test on Forever when convenient.
3. Work through the ⚪ unreviewed table file by file as time allows, or reactively as new crash reports
   come in from continued play-testing - each one is now a quick `Addon.ExpansionIsAtLeastMidnight` →
   `Addon.HAS_MIDNIGHT_API` swap once confirmed to be about API surface rather than ruleset.
4. The 🟠 bare-truthy-check-on-secret-boolean risk category (see fix #20) hasn't had a systematic grep
   pass yet - worth one if further "boolean test on field" crashes show up.
