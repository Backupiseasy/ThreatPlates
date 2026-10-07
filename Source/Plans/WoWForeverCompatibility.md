# "WoW Forever" Compatibility - Open Items

Threat Plates runs on "WoW Forever" without a known crash or misbehaviour. What is left are the in-game checks
below. The rules that came out of this work (client detection, `Addon.HAS_MIDNIGHT_API`, secret values) are in
`CLAUDE.md`; this file only tracks what is still open and can be deleted once the table is done.

The full findings (client signals, all 35 fixes with their symptoms, CVar checks, TOC reasoning) were removed
from this file; they are in the git history, last complete version in commit `a9eed14b`.

## Verification status (in-game, Forever)

| Topic | Status |
| --- | --- |
| Castbar (nameplates), castbar config mode | ✅ confirmed |
| Threat / tanking (no off-tank detection) | ✅ confirmed |
| Names, NPC subtitles, status text | ✅ confirmed |
| Raid target markers | ✅ confirmed |
| Healthbar colors (also in combat), healthbar config mode | ✅ confirmed |
| Cyrillic names displayed correctly | ✅ confirmed |
| `unit.NPCID == nil` without errors (`/tptp unit`) | ✅ confirmed |
| Quest widget without errors | ✅ confirmed |
| BossMods / HealerTracker gone | ✅ confirmed |
| Friendly-unit CVar names, nameplate CVar existence | ✅ confirmed (chat script) |
| "Resources on Targets" hidden | ✅ confirmed |
| Max distance slider up to 100, survives `/reload` | ✅ confirmed |
| Friendly pets / totems get no nameplate while friendly players are disabled | ✅ confirmed |
| SavedVariables are loaded again | ✅ fixed by Blizzard in the client |
| Friendly guardians get no nameplate while friendly players are disabled (option disabled based on assumption, not individually verified) | ⏳ open |
| Health text with "Truncate Text" on/off (amount, deficit, max), also in combat | ⏳ open |
| Options window: all tabs open without errors, Auras tab shows Midnight options | ⏳ open |
| Styles: totem and pet nameplates recognized | ⏳ open |
| Aura sort order migration ("Duration"/"Creation" -> "None" on an existing profile) | ⏳ open |
| Castbar interrupt shield/border/overlay on a non-interruptible cast | ⏳ open |
| Experience widget on an NPC with Blizzard's experience bar (`NPCID` is `nil` now, so it hides itself, as on Midnight) | ⏳ open, low priority |

## Secret-value audit (done 2026-10-07, no finding)

Question: is there another secret **boolean** read directly in a branch condition, like the
`unit.CastIsNotInterruptible` crash in `Elements/Castbar.lua`?

Method: every function with secret-return metadata (`SecretWhen...`, `SecretReturns`, per-field
`ConditionalSecret`/`NeverSecret`) in `Blizzard_APIDocumentationGenerated` of wow-ui-source's `forever` branch was
matched against all call sites in the addon (without `Libs/` and `Source/`), plus every `unit.<field> = ...`
assignment and every unit API called directly in a branch condition.

| Secret boolean source | Consumers | Status |
| --- | --- | --- |
| `notInterruptible` of `UnitCastingInfo`/`UnitChannelInfo` -> `unit.CastIsNotInterruptible` (the only secret boolean stored in the `unit` table) | `Elements/Castbar.lua`: `GetCastbarColor`, `UpdateForCast` | Guarded by `HAS_MIDNIGHT_API`. `isTradeskill` is `NeverSecret`, so `if not name or isTradeSkill` in `OnStartCasting` is fine |
| `UnitIsUnit` | `Addon.UnitIsUnit` wrapper everywhere; raw calls in `Modules/Threat.lua` (off-tank detection, heuristic), `Styles/Styles.lua` (`IsPlayerPetUnit`), `Widgets/AurasWidget.lua` | Raw calls are either guarded with `IsSecretValueTP` (`Styles.lua`), in a legacy branch/file not used with `HAS_MIDNIGHT_API`, or unreachable there (off-tank detection and the heuristic are off) |
| `UnitIsPVP` | `Addon.UnitIsPVP` wrapper; raw only with `"player"` (`Modules/Color.lua`) and in `HealerTrackerWidget.lua` | Fine (`"player"` is never identity-restricted; the widget is not loaded) |
| `UnitIsOwnerOrControllerOfUnit` | `Widgets/ExperienceWidget.lua` (`OnUnitAdded`) | Unreachable with `HAS_MIDNIGHT_API`: `unit.NPCID` is `nil`, so `not widget_id` short-circuits first |
| `UnitHasEffectivelyTankAura` | `Nameplate.lua` (`PlayerHasTankAura`) | Guarded with `IsSecretValueTP` |
| `clamped` of the absorb calculator | `Elements/Healthbar.lua` (`RenderMidnightAbsorbs`) | Only passed to `SetAlphaFromBoolean` |

Two suspected non-boolean cases turned out to be safe, both verified in-game: comparing a secret value with `nil`
(`Elements/TargetMarker.lua`), and `UnitThreatSituation("player", unitid)` (`Modules/Threat.lua`), which is not
secret. The reasoning and the test commands are in `CLAUDE.md` ("Secret-value audit").

## Next steps

1. Finish the open items of the verification table, then delete this file and the references to it in `CLAUDE.md`.
2. If a "boolean test on field" crash shows up despite the audit, re-run the pass described above - the secret
   metadata of the API has changed then.
