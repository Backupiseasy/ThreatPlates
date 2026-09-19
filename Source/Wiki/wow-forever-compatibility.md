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
| 10 | `Widgets/AurasWidget.lua:6` / `Widgets/AurasWidgetMidnight.lua:6` (widget selection) | Live crash: `GetAuraSlots(): Auras cannot be accessed when secret while tainted by 'TidyPlates_ThreatPlates'` - the old widget was active, hit a taint restriction (not a plain Lua error) the rebuilt Midnight widget was specifically built to avoid | Both file-top guards swapped to `Addon.HAS_MIDNIGHT_API` (was an open 🟠 High finding, now confirmed and fixed) |
| 11 | `Nameplate.lua` `OnStartCasting` (castbar timing) | Live crash: arithmetic on secret `startTime` in the legacy castbar-timing branch | `Addon.HAS_MIDNIGHT_API` picks the Midnight-safe `castbar:SetTimerDuration(...)` path instead of raw `startTime`/`endTime` arithmetic. This path also calls `UnitSpellTargetName`, `UnitSpellTargetClass`, `UnitChannelDuration`, `UnitCastingDuration`, `WrapTextInColor`, `GetClassColor`, and the `castbar:SetTimerDuration(...)` frame method - all 7 confirmed present via the 33/33 `/tptp debug MidnightAPI` re-run above. |
| 12 | `Nameplate.lua` `OnStartCasting` (`CastTriggerCheckIfActive`/`CastTriggerUpdateStyle`) | Latent: `CastTriggers[spell_id] or CastTriggers[spell_name]` keys a table with secret `spell_id`/`name` - not yet triggered live only because `Addon.ActiveCastTriggers` was `false` in the crash report | Both calls skipped `if not Addon.HAS_MIDNIGHT_API` (matches why this custom-plate-by-cast feature is already skipped on real Midnight - it fundamentally can't key a table on a secret spell id) |
| 13 | `Nameplate.lua` `SetUnitAttributeTargetMarker` + its `RAID_TARGET_UPDATE` comparison | Latent: `else` branch used `raid_icon_index` (potentially secret) as a `TARGET_MARKER_LIST`/`MENTOR_ICON_LIST` table key; the companion `~=` comparison of the result in `RAID_TARGET_UPDATE` would also be unsafe once `unit.TargetMarkerIcon` can be secret | Both converted to `Addon.HAS_MIDNIGHT_API` |
| 14 | `Nameplate.lua` `SetShownBlizzardPlate` / its `hooksecurefunc(..., "Show", ...)` companion / `CanChangeHitTestPoints` gate | Latent: legacy branch calls plain `SetShown()`/`Show()`/`Hide()` on Blizzard's native nameplate `UnitFrame`, which `CLAUDE.md`'s own "Use SetAlpha(0/1) instead of Show()/Hide()" rule exists specifically because these can hit frame-protection/taint errors on the modern engine (same category as the `ADDON_ACTION_FORBIDDEN` in fix #7) | All three converted to `Addon.HAS_MIDNIGHT_API` |
| 15 | `Compatibility.lua` (`WOW_EVENTS.UNIT_SPELLCAST_INTERRUPTED` / `_SENT`) + `Nameplate.lua`'s `UNIT_SPELLCAST_CHANNEL_STOP` dispatch | Same "Retail/Midnight-only code" pattern as fix #5 - these events/the routing to `Addon:UNIT_SPELLCAST_INTERRUPTED` were gated on ruleset instead of engine | All three converted to `Addon.HAS_MIDNIGHT_API` |
| 16 | `Compatibility.lua` (`Addon.UnitIsUnit` / `Addon.UnitIsPVP` definitions) | Was an open 🔴 Critical finding - not yet confirmed by a live crash, fixed proactively while working through the castbar cluster since it's the addon's most-used safe-wrapper pair | Both converted to `Addon.HAS_MIDNIGHT_API` |
| 17 | `Modules/Color.lua` (`GetSituationalColorForHealthbar`/`GetSituationalColorForName`'s raid-mark coloring) | Latent, discovered as a direct side effect of fix #13: `SettingsBase.settings.raidicon.hpMarked[unit.TargetMarkerIcon]` keys a table with `unit.TargetMarkerIcon`, which fix #13 made carry the raw (potentially secret) value on Forever | Both `use_target_mark_color` gates converted to `Addon.HAS_MIDNIGHT_API` (raid-mark-based healthbar/name coloring is disabled there, same as on real Midnight) |
| 18 | `Widgets/AurasWidgetMidnight.lua` `InitializeAuraButton` + `ReapplyLiveAuraButtonSettings` (dispel-border re-color) | Live crash on re-opening Options (confirmed out of combat, in an unrestricted rest zone - **not** secret-value/taint-related): `Display element '...DispelBorder...' has already been added` from `AddDispelTypeTexture` right after `RemoveDispelTypeTexture(1)` on the same button, reproduced on ~90+ buttons at once (not intermittent). **Root cause found**: Warcraft Wiki documents an upcoming Blizzard API contract change to `AddDispelTypeTexture`/`RemoveDispelTypeTexture` - pre-change, `AddDispelTypeTexture` returns an index and `RemoveDispelTypeTexture(index)` takes that index; post-change, `AddDispelTypeTexture` returns nothing, `RemoveDispelTypeTexture(region)` takes the region object itself, and `AddDispelTypeTexture` now errors on a duplicate region (it didn't before). **Not yet live on retail** (retail was on 12.1.0 as of this session) - the client this reproduced on already has the newer contract, meaning it tracks a build ahead of live retail (see "Publishing / TOC compatibility" above re: its `wow_classic_beta` product/build-track). The old `RemoveDispelTypeTexture(1)` call never matched the real registration on such a client, so the border was never removed before the next `AddDispelTypeTexture` re-added it. Uncaught, this broke the entire `WidgetHandler:InitializeAllWidgets()` call and everything after it in `Options.lua`'s open sequence, because `Addon.ExecuteAfterCombatEnds` runs synchronously out of combat with no `pcall` boundary above it. | `InitializeAuraButton` now stores whatever `AddDispelTypeTexture` returns (`auraButton.DispelBorderRegistration` - an index pre-change, `nil` post-change); `ReapplyLiveAuraButtonSettings` removes using that stored value (falling back to the region object itself when `nil`), so removal self-adapts to either API generation without a hardcoded version check. **Confirmed live**: user reports no errors currently known, including via `/tptp` (which reopens Options, the original repro path) - upgraded from "Hopefully fixed" to "Fixed" in the changelog. The `pcall` safety net added alongside this fix was later removed on explicit maintainer instruction ("pcall versteckt Fehler, die aufgezeigt werden müssen") now that the fix is confirmed working - a failure here should surface as a visible error (signalling the API-generation detection is wrong for that client), not be silently swallowed. |
| 19 | `Elements/Castbar.lua:154,165` (`UpdateForCast`'s `InterruptShield`/`InterruptBorder`/`InterruptOverlay`) | Was an open 🟡 finding - not confirmed by a live crash, fixed on explicit maintainer instruction to assume Forever behaves like Midnight here (`show = unit.CastIsNotInterruptible` can be secret; the legacy branch's `SetShown()`/`Show()`/`Hide()` aren't documented `SecretArguments = "AllowedWhenTainted"` the way `SetAlphaFromBoolean` is) | Both converted to `Addon.HAS_MIDNIGHT_API`. At the time this was written, `GetCastbarColor` (line 115) was believed safe as-is because its legacy branch only does a bare truthy `if`/`elseif` check on `unit.CastIsNotInterruptible` - **this assumption was disproved live, see fix #20**. |
| 20 | `Elements/Castbar.lua:124` (`GetCastbarColor`'s branch selector, `elseif unit.CastIsNotInterruptible then`) | Live crash: `attempt to perform boolean test on field 'CastIsNotInterruptible' (a secret boolean value, while execution tainted by 'TidyPlates_ThreatPlates')` - directly disproves the fix #19 assumption (and the guard-pattern catalogue's former blanket claim) that a bare truthy check on a secret value is always safe | Branch selector converted to `Addon.HAS_MIDNIGHT_API`, same as fix #19 - Forever now uses the Midnight-safe color path instead of the legacy truthy check. **`CLAUDE.md` corrected**: a secret *boolean* field read in a branch condition (as opposed to a plain truthy/non-nil check on a value of unknown type) can still throw when execution is tainted - the "truthiness is always safe" guidance was too broad and is now scoped accordingly. This also opened a real risk category (see "Open findings" below), not just a completeness nice-to-have: any other bare `if`/`elseif unit.SomeBooleanField then` on a value that can be secret is a candidate for the same crash. |
| 21-23 | `Addon.lua` (`OnInitialize`, AceDB creation) - **all attempts reverted, not addon-fixable** | Reported as "options don't persist across reload": `ThreatPlatesDB` (SavedVariables) is `nil` when `ADDON_LOADED` fires, so `AceDB:New()` creates a blank profile that is saved over the real one on the next `/reload`. Two fixes were tried and disproved live: (#21) re-running `CreateAceDatabase()` at `PLAYER_LOGIN`, which cannot work because `AceDB:New()` itself assigns a blank table to the nil global (`tbl = _G[name]; if not tbl then tbl = {}; _G[name] = tbl end`), so a later nil-check can't tell real data from the placeholder; (#22) deferring the entire AceDB setup to `PLAYER_LOGIN` and never touching the global before that. A purely observational watcher (object identity, polled every 0.2s for 30s, across three `/reload`s and one full relog) showed `ThreatPlatesDB` never receives real data on that client - the only identity change was the addon's own blank `AceDB:New()` table. The SavedVariables *file* is correct on disk, saving works; only loading fails. | **No addon-side fix exists** (no file-I/O API for SavedVariables) - very likely a client bug, to be reported upstream. All code from #21/#22 and the watcher was reverted; `Addon.lua` is back to its original single `OnInitialize()`. Do not re-add either pattern without new evidence (also documented in `CLAUDE.md`). |
| 24 | `Elements/Castbar.lua` (`PlateCreated`, OnUpdate selection) | Castbars were never shown on nameplates (also see fixes #11, #19, #20). `OnStartCasting` uses the Midnight timer path (`castbar.Duration` via `SetTimerDuration`) on `Addon.HAS_MIDNIGHT_API`, but the castbar's `OnUpdate` was picked by `Addon.ExpansionIsAtLeastMidnight`: on Forever the legacy `Value`/`MaxValue` `OnUpdate` ran with `0`/`0` and hid the castbar right after the cast started | New local `CastbarOnUpdate = Addon.HAS_MIDNIGHT_API and OnUpdateMidnight or OnUpdate`, used by `PlateCreated` and when leaving config mode. **Confirmed in-game.** |
| 25 | `Elements/Castbar.lua` (`UpdateVisibility`, `Addon:ConfigCastbar`) | Castbar config mode did not show the castbar (regression of the `UpdateVisibility` refactor, not Forever-specific): `ForceUpdate` -> `RefreshCastbar` -> `UpdateVisibility` calls the native `SetShown(false)` while no cast is active (the `Hide` override installed by config mode does not intercept it), and the config-mode `OnUpdate` only runs on a shown frame, so it never ran again | `UpdateVisibility` returns early (`Show()`) for the config-mode plate; leaving config mode now restores `CastbarOnUpdate` (it hard-coded the legacy `OnUpdate`, wrong on Midnight/Forever) and clears `EnabledConfigMode` before hiding. **Confirmed in-game.** |
| 26 | `Modules/Threat.lua` (`UpdateSettings`) | Lua error `attempt to compare local 'target_threat_situation' (a secret number value, while execution tainted by 'TidyPlates_ThreatPlates')` in `CheckIfUnitIsOfftanked` while tanking: off-tank detection is disabled on Midnight via `ExpansionIsAtLeastMidnight`, which is `false` on Forever although `UnitThreatSituation` returns secrets there | `UseThreatTable`, `UseHeuristicInInstances` and `ShowOffTank` now use `Addon.HAS_MIDNIGHT_API` (threat table only, no off-tank detection, no heuristic - same as Midnight). **Confirmed in-game.** |
| 27 | Feature gates: `Modules/Localization.lua` (2), `Styles/Styles.lua` (2), `Elements/Name.lua`, `Elements/StatusText.lua` (`GetUnitSubtitle`), `Elements/TargetMarker.lua`, `Elements/Healthbar.lua` (4: target-of-target text x3, status-bar color), `Nameplate.lua` (2: NPC-ID from GUID, `PlatesByGUID` cleanup), `Widgets/QuestWidget.lua` (2: group roster tracking), `Widgets/AurasWidgetMidnight.lua` (`HideOmniCC`), `Options.lua` (45 visibility toggles) | Several branches that exist to avoid secret values (unit names/GUIDs as table keys or in `gsub`/`strsplit`, raid-marker icon in string concatenation, tooltip name matching, `Addon.Truncate` doing arithmetic on health, target-of-target `UnitName`) or that mirror Midnight-only features (aura and other option panels) were still keyed on `ExpansionIsAtLeastMidnight`, so Forever took the legacy path although it loads Midnight's Auras widget and returns secrets | All converted to `Addon.HAS_MIDNIGHT_API`; no ruleset-only use of `ExpansionIsAtLeastMidnight` remains (see "Remaining occurrences" below). Consequences on Forever: name-based custom-plate triggers, name transliteration/abbreviation, NPC-ID parsing (`unit.NPCID` is `nil`), target-of-target text and quest group tracking are disabled like on Midnight; totem/pet detection and raid-marker icons use the secret-safe code. **Confirmed in-game:** names, status text (incl. subtitles), raid markers, healthbar colors (also in combat, config mode), Cyrillic names, `NPCID == nil` without errors, quest widget. Still to verify: see "Verification status". |
| 28 | `Widgets/BossModsWidget.lua`, `Widgets/HealerTrackerWidget.lua`, `Widgets/StealthWidget.lua` | These widgets are intentionally disabled on Midnight (`CLAUDE.md`) but were still loaded on Forever (guard was `ExpansionIsAtLeastMidnight`); they parse names/GUIDs/auras with the legacy code | File-top guards switched to `Addon.HAS_MIDNIGHT_API`. `StealthWidget.lua` additionally returns on `Addon.IS_CLASSIC` instead of creating a dummy `{}` widget there (`if Addon.HAS_MIDNIGHT_API or Addon.IS_CLASSIC then return end`); as a consequence `Addon.Data.StealthDetectionAuras/Units` (only read into a table constructor in `Widgets/ScriptWidget.lua`, `nil` is harmless) no longer exist on Classic. **Confirmed in-game:** BossMods and HealerTracker are gone after `/reload` (options tabs hidden), Stealth was never shown. |
| 29 | `Constants.lua` (friendly unit type CVars) | The friendly NPC/minion/pet/guardian/totem settings had no effect: Midnight renamed the CVars (`nameplateShowFriendlyPlayerMinions/-Pets/-Guardians/-Totems`, `nameplateShowFriendlyNpcs`) and Forever uses the new names; the old ones return `nil` there (`nameplateShowFriendlyNPCs`/`...Npcs` resolve to the same CVar, names are case-insensitive) | `Show = (Addon.HAS_MIDNIGHT_API and <new name>) or <old name>` for all five. **Verified with in-game `GetCVar` checks** (see "CVar check" below). |
| 30 | `Database.lua` (aura sort order migration) | "Duration"/"Creation" sort orders have no equivalent in the Midnight Auras widget (their toggles are hidden by fix #27), but existing Forever profiles keep the stored value because the migration only ran for `ExpansionIsAtLeastMidnight` | Migration entry `Version = Addon.HAS_MIDNIGHT_API`; comment updated. Not yet verified in-game. |
| 31 | `CVarsManager.lua` (`CVars:IsAvailable`), `Options.lua` (`ShowResources`), `Addon.lua` (login) | The option "Resources on Targets" was shown (and its CVar set at every login) although `nameplateResourceOnTarget` does not exist on Forever (`GetCVar` returns `nil`) | New `CVars:IsAvailable(cvar)` (`GetCVar(cvar) ~= nil`); the option is hidden and the login `OverwriteBool` skipped when the CVar is missing. **Confirmed in-game:** option is hidden on Forever. |
| 32 | `Options.lua` (`MaxDistance` slider) | The maximum of the nameplate max distance slider was 20 on Forever: `Addon.GetExpansionLevel()` returns `LE_EXPANSION_CLASSIC` there, but the client's default `nameplateMaxDistance` is 45 (above every Classic limit) and it does not clamp the CVar (setting `1000` reads back `1000`), so the real limit can't be measured | Slider maximum uses the `MAINLINE` entry (100) when `Addon.HAS_MIDNIGHT_API`. **Confirmed in-game:** 100 can be set and survives `/reload`. |
| 33 | `Nameplate.lua` (`NamePlateDriverFrame_AcquireUnitFrame`) | Nameplates briefly showed the wrong name/reaction (a neutral unit as an enemy) and then disappeared, reproduced twice on the same plate (`nameplate2`) with a neutral and a hostile NPC (not Forever-specific; the pooling exists on Mists Classic and the modern engine, Forever just triggered it). The `/tptp debug` dump was fully correct (`Active`, `TPFrame:IsShown()`, name, reaction, style), so it was not a data problem. Root cause: Blizzard pools its nameplate `UnitFrame`s and hands a plate a different, already flagged instance on `NAME_PLATE_UNIT_ADDED`; `plate.TPFrame:SetPoint("CENTER", plate.UnitFrame, ...)` only ran the first time a `unit_frame` was seen (regression from commit `8f3ccf29`, 2026-01-27), so TPFrame stayed anchored to a previously used instance - drawn over another plate, then without any anchor once that instance was released. In-game check: `TPFrame:GetPoint()`'s relative frame was not `plate.UnitFrame`, `IsVisible()` true, alpha 1, `GetLeft()` returned nothing | `SetPoint` moved out of the once-per-frame block, runs on every acquire (the hooks stay once-per-frame). **Confirmed in-game:** no recurrence. Does **not** make `ScheduleNameplateRevalidation` or the Blizzard-plate `OnShow`/`Show` hooks obsolete (different mechanisms: stale unit data, resp. Blizzard's own plate staying visible); some older "wrong name in BG/Arena" reports may have been this bug, which cannot be told apart retroactively. |

The "suboptimal but safe" state from the previous revision of this document (fixes #1/#2 using inline
guards instead of reusing Midnight's curve-based implementation) has been resolved - see the updated
fixes #1/#2 above.

### CVar check on Forever (chat script, `GetCVar`)

| CVar(s) | Result |
| --- | --- |
| `nameplateShowFriendlyNpcs` (= `...NPCs`), `nameplateShowFriendlyPlayerMinions/-Pets/-Guardians/-Totems` | exist (new Midnight names) |
| `nameplateShowFriendlyMinions/-Pets/-Guardians/-Totems` (old names) | `nil` - do not exist |
| `nameplateShowAll`, `...Enemies`, `...EnemyMinus/-Pets/-Guardians/-Minions/-Totems`, `...FriendlyPlayers`, `...OnlyNames`, `...OnlyNameForFriendlyPlayerUnits`, `...DebuffsOnFriendly` | exist |
| `nameplateMin/MaxScale`, `nameplateSelectedScale`, `nameplateMin/Max/Selected/NotSelectedAlpha`, `nameplateOccludedAlphaMult`, `nameplateMaxDistance` (default 45), `nameplateTargetBehindMaxDistance`, `nameplateOverlapH/V` | exist |
| `nameplateResourceOnTarget` | `nil` - handled by fix #31 |
| `nameplateGlobalScale`, `nameplateLargerScale` | `nil` - only used in commented-out code / a database delete entry (`CVars.InvalidCVarsForHidingNameplates`, `FixCVarsForHidingNameplates`, all callers are commented out), no action needed |


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

## Open findings

**Status**: no crash or misbehaviour is currently known on Forever. Every former occurrence of
`Addon.ExpansionIsAtLeastMidnight` that was a *code-path* decision (as opposed to a genuine ruleset decision) has
been reviewed and converted to `Addon.HAS_MIDNIGHT_API` (fixes #1-#20, #24-#32); the audit table that used to list
them as "unreviewed" is superseded by the summary below.

### Remaining occurrences of `Addon.ExpansionIsAtLeastMidnight`

| Location | Why it stays |
| --- | --- |
| `Init.lua` | Definition (`Addon.ExpansionIsAtLeastMidnight = Addon.IS_MIDNIGHT`) and the composition of `Addon.HAS_MIDNIGHT_API` |
| `Commands.lua`, `Modules/Color.lua` | Comments / commented-out code only |

`Options.lua`'s former 45 occurrences are now `HAS_MIDNIGHT_API` too (they decide which options panel matches the
Auras widget that is actually loaded, see fix #27). `Localization.lua`'s name-abbreviation/transliteration and
`NPCID` parsing are disabled on Forever the same way they are on Midnight (fix #27).

### 🟠 Risk category: bare truthy checks on secret *boolean* fields

Fix #20 (`Castbar.lua`) disproved the former blanket claim that `if secret_value then` is always safe. It is safe
for plain truthy/non-nil checks, but a secret **boolean** field read directly in a branch condition
(`if unit.SomeBooleanField then` / `elseif ... then`) can still throw "attempt to perform boolean test on field
'...' (a secret boolean value, while execution tainted by ...)". A systematic grep for other bare-boolean-field
branch conditions on values that can be secret (candidates: other `unit.*` boolean fields set from secret-prone
APIs, like `CastIsNotInterruptible`) has **not** been done - reactive, as new crash reports come in.

### Known pre-existing issues (not Forever-specific)

- `Elements/StatusText.lua` (`GetUnitSubtitle`): `UnitSubtitles[tooltip_name] = subtitle` has no secret-value guard on the
  cache key. On Midnight this path has not caused errors so far, so it is left as is.
- `CVarsManager.lua` `CVars:CVarExists` reads an undefined variable (`addon` instead of `Addon`), so it most likely
  always returns a truthy value; new code uses `CVars:IsAvailable` instead.

## Verification status (in-game, Forever)

| Topic | Status |
| --- | --- |
| Castbar (nameplates), castbar config mode | ✅ confirmed (fixes #24, #25) |
| Threat / tanking (no off-tank detection) | ✅ confirmed (fix #26) |
| Names, NPC subtitles, status text | ✅ confirmed |
| Raid target markers | ✅ confirmed |
| Healthbar colors (also in combat), healthbar config mode | ✅ confirmed |
| Cyrillic names displayed correctly | ✅ confirmed |
| `unit.NPCID == nil` without errors (`/tptp unit`) | ✅ confirmed |
| Quest widget without errors | ✅ confirmed |
| BossMods / HealerTracker gone, Stealth not shown | ✅ confirmed |
| Friendly-unit CVar names, nameplate CVar existence | ✅ confirmed (chat script) |
| "Resources on Targets" hidden | ✅ confirmed |
| Max distance slider up to 100, survives `/reload` | ✅ confirmed |
| Health text with "Truncate Text" on/off (amount, deficit, max), also in combat | ⏳ open |
| Options window: all tabs open without errors, Auras tab shows Midnight options | ⏳ open |
| Styles: totem and pet nameplates recognized | ⏳ open |
| Aura sort order migration ("Duration"/"Creation" -> "None" on an existing profile) | ⏳ open |
| Castbar interrupt shield/border/overlay on a non-interruptible cast (fix #19) | ⏳ open |
| Experience widget on an NPC with Blizzard's experience bar (`NPCID` is `nil` now, so it hides itself, as on Midnight) | ⏳ open, low priority |


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

**Update**: fix #18 above found direct evidence that Forever isn't merely running an older snapshot of
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

1. Finish the open items of the "Verification status" table above.
2. Report the SavedVariables loading problem (fixes #21-23) upstream; there is no addon-side fix.
3. Keep using `Addon.HAS_MIDNIGHT_API` (never `Addon.ExpansionIsAtLeastMidnight`) for any new code that only
   exists to pick the secret-value-safe/modern API path, and feature-detect specific API shapes where possible
   (Forever tracks a build ahead of live retail, see fix #18).
4. If further "boolean test on field" crashes show up, do the systematic grep pass described under the 🟠 risk
   category.
