# Auras Widget — Filter Criteria Reference (Midnight / Patch 12.1.0)

**Applies to:** `Widgets/AurasWidgetMidnight.lua` (the Auras widget on WoW Midnight / Patch 12.1.0
clients, built on Blizzard's `AuraContainer`/`AuraButton` API)

---

## Background

On Midnight, the Auras widget no longer scans auras in Lua — it hands a declarative filter to
Blizzard's `AuraContainer`, which does the scanning itself (aura data can be a *secret value* on this
client and is not readable by addon code). Each Options toggle below maps to either an **`AuraFilters`
filter-string token** (e.g. `PLAYER`, `DISPELLABLE`, `IMPORTANT`) or a **`candidateFilters` field**
(e.g. `isBossAura`, `maxDuration`), a separate, more granular restriction Blizzard added in Patch
12.1.0. For how the widget is built (pooling, the multi-group combination algorithm, API quirks and
gotchas discovered along the way), see [`AurasWidgetImplementation.md`](AurasWidgetImplementation.md)
instead — this page only covers what each toggle *does*.

All filter strings additionally always carry the aura type (`HELPFUL` for Buffs, `HARMFUL` for
Debuffs/CrowdControl) and `INCLUDE_NAME_PLATE_ONLY` (without this token, auras Blizzard flags as
nameplate-only are silently excluded — not repeated per row below).

Where a row says "**not implemented**", the Options toggle exists and is clickable but currently has
no effect on Midnight — a known gap, not a setting you're misusing.

---

## Buffs — Friendly

**All**/**All on NPCs** short-circuit into a single unrestricted group (like everywhere else "All"
appears); otherwise Mine/Player Can Apply/Big Defensives are independent, **freely-combinable**
OR-conditions via one `AddAuraGroup` each, cross-excluding each other so a multi-matching aura isn't
shown twice. "All on NPCs" itself can't be freely combined with the other three the same way — it's
conceptually "All, but scoped to NPCs", not a peer condition (no `candidateFilters` field exists for
"unit is an NPC" to cross-exclude it with) — so it stays a short-circuit alongside "All".

| Options toggle | Shows | DB field | Technical | Note |
| --- | --- | --- | --- | --- |
| Show Buffs | — | `ShowFriendly` | group master switch | not a filter itself, gates the whole aura type |
| All | Every buff on friendly units | `ShowAllFriendly` | no restriction beyond `HELPFUL` | |
| All on NPCs | Every buff, but only on friendly NPCs (not friendly players) | `ShowOnFriendlyNPCs` | no restriction, **only when the unit is an NPC** | checked on the addon side, since no `AuraFilters` token for "unit is an NPC" exists; short-circuits like All (see above) |
| Mine | Buffs that you (or your pet) cast | `ShowOnlyMine` | `PLAYER` token | |
| Player Can Apply | Buffs you could apply yourself, regardless of who actually cast them | `ShowPlayerCanApply` | `candidateFilters.canApplyAura = true` | |
| Big Defensives | Buffs Blizzard classifies as big defensive cooldowns | `ShowFriendlyBigDefensives` | `BIG_DEFENSIVE` token | |
| Max Duration | Hides buffs whose total duration exceeds the set number of seconds (0 = off) | `MaxDurationFriendly` (seconds, 0 = off) | `candidateFilters.maxDuration` | applies on top of whichever toggle(s) above are active, including All; any non-zero value also hides permanent (duration-less) buffs — useful for filtering out passive self-buffs (flasks, food, Well Fed, ...); moved here from Debuffs (2026-08-16), where a duration cap made less sense |

**Combinations** ("–" = doesn't matter, Max Duration omitted — it's a cap applied after the union, not part of it):

| All | All on NPCs | Mine | Can Apply | Big Def. | Shown on NPCs | Shown on players |
| --- | --- | --- | --- | --- | --- | --- |
| ✅ | – | – | – | – | Everything | Everything |
| ❌ | ✅ | ❌ | ❌ | ❌ | Everything | Nothing |
| ❌ | ✅ | ✅ | – | – | Everything (NPCs wins) | Mine only |
| ❌ | ✅ | – | ✅ | – | Everything (NPCs wins) | Can Apply only |
| ❌ | ✅ | – | – | ✅ | Everything (NPCs wins) | Big Defensives only |
| ❌ | ✅ | ✅ | ✅ | ✅ | Everything (NPCs wins) | Union of all three |
| ❌ | ❌ | ✅ | ❌ | ❌ | Mine only | same |
| ❌ | ❌ | ❌ | ✅ | ❌ | Can Apply only | same |
| ❌ | ❌ | ❌ | ❌ | ✅ | Big Defensives only | same |
| ❌ | ❌ | ✅ | ✅ | ❌ | Mine ∪ Can Apply | same |
| ❌ | ❌ | ✅ | ❌ | ✅ | Mine ∪ Big Defensives | same |
| ❌ | ❌ | ❌ | ✅ | ✅ | Can Apply ∪ Big Defensives | same |
| ❌ | ❌ | ✅ | ✅ | ✅ | Union of all three | same |
| ❌ | ❌ | ❌ | ❌ | ❌ | Nothing | Nothing |

"All on NPCs" only ever affects NPC targets — on players it has no effect regardless of whether it's
checked, and the union of Mine/Can Apply/Big Defensives applies the same way on both target types.

## Buffs — Enemy

Same pattern as Friendly above: All/All on NPCs short-circuit; Dispellable/Magic are independent,
freely-combinable OR-conditions.

| Options toggle | Shows | DB field | Technical | Note |
| --- | --- | --- | --- | --- |
| Show Buffs | — | `ShowEnemy` | group master switch | |
| All | Every buff on enemy units | `ShowAllEnemy` | no restriction beyond `HELPFUL` | |
| All on NPCs | Every buff, but only on enemy NPCs (not enemy players) | `ShowOnEnemyNPCs` | no restriction, **only when the unit is an NPC** | checked on the addon side; short-circuits like All |
| Dispellable | Buffs you can dispel/purge/steal | `ShowDispellable` | `DISPELLABLE` token | Patch 12.1.0 token — dispellable by anyone, broader than the older "a raid member's kit can dispel this specifically" token |
| Magic | Buffs of dispel type Magic | `ShowMagic` | `candidateFilters.includeDispelTypes = { Magic = true }` | |
| Max Duration | Hides buffs whose total duration exceeds the set number of seconds (0 = off) | `MaxDurationEnemy` (seconds, 0 = off) | `candidateFilters.maxDuration` | separate setting from the Friendly Buffs Max Duration above — changing one doesn't affect the other; applies on top of whichever toggle(s) above are active, including All |

**Combinations** (Max Duration omitted — it's a cap applied after the union, not part of it):

| All | All on NPCs | Dispellable | Magic | Shown on NPCs | Shown on players |
| --- | --- | --- | --- | --- | --- |
| ✅ | – | – | – | Everything | Everything |
| ❌ | ✅ | ❌ | ❌ | Everything | Nothing |
| ❌ | ✅ | ✅ | – | Everything (NPCs wins) | Dispellable only |
| ❌ | ✅ | – | ✅ | Everything (NPCs wins) | Magic only |
| ❌ | ✅ | ✅ | ✅ | Everything (NPCs wins) | Dispellable ∪ Magic |
| ❌ | ❌ | ✅ | ❌ | Dispellable only | same |
| ❌ | ❌ | ❌ | ✅ | Magic only | same |
| ❌ | ❌ | ✅ | ✅ | Dispellable ∪ Magic | same |
| ❌ | ❌ | ❌ | ❌ | Nothing | Nothing |

## Debuffs — Friendly

Same freely-combinable multi-group pattern as Debuffs — Enemy below (fewer toggles: no Mine/Blizzard/
Priority equivalent exposed for friendly): **All** short-circuits everything into a single
unrestricted group; otherwise Dispellable/Boss/dispel-type are each their own `AddAuraGroup`, cross-
excluding each other so a multi-matching aura isn't shown twice. **Exception**: Dispellable and Dispel
Type are combined, not independent — see below.

| Options toggle | Shows | DB field | Technical | Note |
| --- | --- | --- | --- | --- |
| Show Debuffs | — | `ShowFriendly` | group master switch | |
| All | Every debuff on friendly units (except crowd control, which has its own grid) | `ShowAllFriendly` | Crowd Control excluded (own grid) | |
| Dispellable | Debuffs you can dispel/cleanse, restricted to the dispel types checked below | `ShowDispellable` | `DISPELLABLE` token, CC excluded | |
| Boss | Debuffs applied by a boss (raid/dungeon encounter) | `ShowBoss` | `candidateFilters.isBossAura = true` | separate DB field from Enemy's `ShowBossEnemy` — changing one doesn't affect the other |
| Curse / Disease / Magic / Poison | Dispellable debuffs of the checked dispel type(s) | `FilterByType[1..4]` | `candidateFilters.includeDispelTypes = {...}` | **combined with Dispellable (2026-08-15)**, not independent — grayed out and inert unless Dispellable is also checked; separate DB field from Enemy's `FilterByTypeEnemy[1..4]`; when active, Boss excludes these checked dispel types from itself (`excludeDispelTypes`), so a matching aura only shows once, via this group; defaults to all four checked |

**Combinations** (Dispel Type = at least one of Curse/Disease/Magic/Poison checked; a checked Dispel
Type only has any effect while Dispellable is also on):

| All | Dispellable | Boss | Dispel Type | Shown |
| --- | --- | --- | --- | --- |
| ✅ | – | – | – | Everything (CC excluded) |
| ❌ | ✅ | ❌ | ✅ | Dispellable debuffs of the checked type(s) only |
| ❌ | ✅ | ❌ | ❌ | Nothing from Dispellable (no type checked = no match) |
| ❌ | ❌ | ✅ | – | Boss only (Dispel Type ignored/grayed out) |
| ❌ | ✅ | ✅ | ✅ | Boss ∪ (dispellable debuffs of the checked type(s)) |
| ❌ | ❌ | ❌ | – | Nothing (Dispel Type grayed out, has no effect on its own) |

## Debuffs — Enemy

The richest filter set, and the only one where toggles are **freely combinable** rather than mutually
exclusive: **All** short-circuits everything into a single unrestricted group; otherwise, every toggle
below is evaluated independently and an aura matching several toggles is still only shown once (never
duplicated).

| Options toggle | Shows | DB field | Technical | Note |
| --- | --- | --- | --- | --- |
| Mine | Debuffs that you (or your pet) applied | `ShowOnlyMine` | `PLAYER` token | |
| Blizzard | Debuffs **you applied** that Blizzard itself would also show on its own default nameplates | `ShowBlizzardForEnemy` | `PLAYER` token + (`candidateFilters.nameplateShowAll = true` **or** `nameplateShowPersonal = true`), two peer groups | not the `IMPORTANT` token — that only ever applies to helpful auras per its own doc comment, so combined with `HARMFUL` it matches nothing. Two separate Blizzard curation flags exist: `nameplateShowAll` (shown for anyone) and `nameplateShowPersonal` (shown only when self-applied, which is why it needs the `PLAYER` restriction to make sense) — both map to real `candidateFilters` fields, matching the legacy widget's `aura.nameplateShowAll or (aura.nameplateShowPersonal and aura.CastByPlayer)`. `PLAYER` is hardcoded by deliberate design (2026-08-16) — "Blizzard" always means "mine, and Blizzard-flagged", not "anyone's Blizzard-flagged debuffs" (checking Mine+Blizzard together can't narrow it further, since Mine's own set is already the superset) — see `AurasWidgetImplementation.md` |
| Boss | Debuffs applied by a boss (raid/dungeon encounter) | `ShowBossEnemy` | `candidateFilters.isBossAura = true` | |
| Priority | Debuffs Blizzard flags as high priority | `ShowPriority` | `candidateFilters.isPriorityAura = true` | a general UI-sort flag, distinct from Blizzard above (which is nameplate-curation-specific) |
| Dispellable | Debuffs you can dispel/cleanse, restricted to the dispel types checked below | `ShowDispellableEnemy` | `DISPELLABLE` token | separate setting from the Friendly Debuffs Dispellable toggle — changing one doesn't affect the other |
| Curse / Disease / Magic / Poison | Dispellable debuffs of the checked dispel type(s) (optionally further restricted to Mine, see below) | `FilterByTypeEnemy[1..4]` | `candidateFilters.includeDispelTypes = {...}` | **combined with Dispellable (2026-08-15)**, not independent — grayed out and inert unless Dispellable is also checked; the other toggles above exclude these checked dispel types from themselves (`excludeDispelTypes`) whenever active, so a matching aura only shows once, via this group; defaults to all four checked |

No Max Duration here — moved to Buffs (2026-08-16), where a duration cap makes more practical sense
(filtering out passive self-buffs) than for Debuffs.

Dispel Type was **intentionally independent** of the Dispellable toggle until 2026-08-15 (matched the
non-Midnight widget's behavior at the time); both were changed together so it's now gated behind
Dispellable being enabled instead — see the table row above. Mine is also folded into the Dispellable +
Dispel Type group when both are active, so e.g. Mine + Dispellable + Curse shows only *your own*
dispellable Curse debuffs, not everyone's.

**Combinations**: 5 independent toggles (Mine/Blizzard/Boss/Priority/Dispellable, with Dispel Type
folded into Dispellable) means 32 possible on/off combinations — too many to usefully enumerate. The
rule is always the same though: **shown = union of every checked toggle's own set** (each row's "Shows"
column above), and an aura matching several checked toggles at once still only renders once. A few
examples:

| Active toggles | Shown |
| --- | --- |
| All | Everything (All is a full short-circuit) |
| (none) | Nothing |
| Mine | Only debuffs you (or your pet) applied |
| Boss | Boss-applied debuffs only |
| Dispellable + Curse | Dispellable Curse debuffs from anyone |
| Mine + Dispellable + Curse | Dispellable Curse debuffs from you only |
| Blizzard + Priority + Dispellable + (all 4 dispel types checked) | Union of your own Blizzard-flagged debuffs, Priority's set, and every dispellable debuff regardless of type |

## CrowdControl — Friendly

| Options toggle | Shows | DB field | Technical | Note |
| --- | --- | --- | --- | --- |
| Show Crowd Control | — | `ShowFriendly` | group master switch | |
| All | Every crowd-control effect (stun, fear, root, ...) on friendly units | `ShowAllFriendly` | Crowd Control auras | |
| Dispellable | Crowd-control effects you can dispel/cleanse | `ShowDispellable` | `DISPELLABLE` token | fixed 2026-08-15, previously silently ignored |

Not multi-group — a plain `elseif` (still mutually exclusive, unlike Buffs/Debuffs above):

| All | Dispellable | Shown |
| --- | --- | --- |
| ✅ | ❌ | Every CC effect |
| ❌ | ✅ | Only dispellable CC effects |
| ❌ | ❌ | Nothing |

## CrowdControl — Enemy

| Options toggle | Shows | DB field | Technical | Note |
| --- | --- | --- | --- | --- |
| Show Crowd Control | — | `ShowEnemy` | group master switch | |
| All | Every crowd-control effect (stun, fear, root, ...) on enemy units | `ShowAllEnemy` | Crowd Control auras | |

Only one toggle exists here (no Dispellable equivalent in the Enemy Midnight panel) — either every CC
effect shows (All on) or none do (All off), no combinations possible.

Friendly and Enemy Crowd Control currently use the identical underlying filter once enabled — only
whether the group is shown at all differs per reaction.
