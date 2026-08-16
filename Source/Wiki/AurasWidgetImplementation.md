# Auras Widget — Implementation Reference (Midnight / Patch 12.1.0)

**Applies to:** `Widgets/AurasWidgetMidnight.lua` (the Auras widget on WoW Midnight / Patch 12.1.0
clients only — the non-Midnight/Classic widget, `Widgets/AurasWidget.lua`, uses the older
`AuraUtil.ForEachAura`/`C_UnitAuras` pull-based scanning and is out of scope here)

This page documents **how** the widget is built — which Blizzard API implements which piece of
behavior, and the API quirks/limitations relevant to it. For **what each Options toggle does**
(user-facing filter behavior, combination tables), see
[`AurasFilterCriteria.md`](AurasFilterCriteria.md) instead — the two pages are deliberately
non-overlapping.

---

## 1. Why `AuraContainer`/`AuraButton`

Aura data can be a *secret value* on Midnight and is not readable by addon-side Lua code
(`C_UnitAuras.GetUnitAuras`/`GetAuraSlots` can throw or return empty for nameplate unit tokens). The
`AuraContainer`/`AuraButton` intrinsic frame types sidestep this entirely: Blizzard's engine owns
aura fetching, filtering, and updating internally once an addon calls `container:SetUnit(unitToken)`
— no addon-side Lua access to aura data is needed at all. `SecureAuraHeaderTemplate` has been removed
from Mainline in favor of this; it's Blizzard's intended direction, not an optional extra.

This is the widget's only aura display path — there is no addon-side scanning fallback.
`HasAuraContainers` (feature-detected via
`C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate")`, since there's no dedicated
expansion-level flag for this) is kept only as a defensive guard.

---

## 2. Core API surface used — Layout & Appearance

Filter-composition API (`AddAuraGroup`'s `filterString`, `candidateFilters`,
`SetAuraGroupFilterString`/`CandidateFilters`, `SetUnit`, `SetEnabled`) is covered by §3/§4 and
`AurasFilterCriteria.md` instead — this table only covers what shapes how auras are laid out and how
each icon looks.

| API |
| --- |
| **`container:SetAuraGroupLayout(groupKey, { elementWidth, elementHeight, elementSpacing, lineSpacing })`**<br>Per-group flow-layout sizing/spacing hints. |
| **`container:SetFlowLayoutAnchorPoint/GrowthDirection/MaximumLineSize(...)`**<br>Container-wide grid layout: anchor corner, growth direction, wrap width. |
| **`container:SetAuraGroupMaxFrameCount(groupKey, n)`**<br>Caps how many auras a group displays; `0` disables the group entirely. |
| **`options.initializeFrame`** (passed to `AddAuraGroup`)<br>Callback that configures each `AuraButton` **once**, the first time Blizzard's internal frame pool creates it — not on reuse. See the create-time-only gotcha in §6. |
| **`AuraButton:SetIcon/SetDurationCooldown/SetDurationText/SetApplicationCount/AddDispelTypeTexture/SetMouseMotionEnabled/SetHideTooltipInCombat`**<br>Fixed, allow-listed `Set*` surface for configuring a button's appearance — no generic `SetScript`/event access. |
| **`PixelUtil.SetSize(auraButton, w, h)`**<br>Icon size — a plain frame-layout setter, not aura-data-specific, so it's callable despite `AuraButton`'s Forbidden Aspects. |
| **`container:GetAuraGroupFrame(groupKey, index)` / `GetAuraGroupFrameCount(groupKey)`**<br>Enumerate already-created `AuraButton`s in a group, to reapply appearance settings after the fact. See the pool-size gotcha in §6. |

`AuraContainer`s **cannot be created during combat**. Since TidyPlates creates widget frames lazily
the first time Blizzard hands out a nameplate (which can happen mid-pull), containers are
**pre-allocated in a pool** out of combat instead (`PreallocateAuraContainers`, called from
`Widget:OnEnable` and retried from `Widget:PLAYER_REGEN_ENABLED`/`DISABLED`; pool size `40` per aura
type) and claimed per-plate on demand (`AcquireAuraContainer`, called from `Widget:Create`) rather
than created lazily like the rest of this widget's frames.

---

## 3. Code map — concept → function → API

| Concept | Function(s) | API used |
| --- | --- | --- |
| Container pooling / pre-allocation | `PreallocateAuraContainers`, `AcquireAuraContainer`, `CreateAuraContainer` | `CreateFrame("AuraContainer", ...)`, `AddAuraGroup` |
| Per-toggle → filter composition | `GetFriendlyBuffsGroupConfigs`, `GetEnemyBuffsGroupConfigs`, `GetFriendlyDebuffsGroupConfigs`, `GetEnemyDebuffsGroupConfigs`, `GetCrowdControlFilterString` | build `filterString`/`candidateFilters` per group |
| Multi-toggle free combination + no-double-render guarantee | `BuildGroupConfigsFromConditions` | ordered cross-exclusion across groups (see §4) |
| Per-button visuals (icon, cooldown swipe, stack count, duration text, dispel-type border, tooltip) | `InitializeAuraButton` | `SetIcon`/`SetDurationCooldown`/`SetDurationText`/`SetApplicationCount`/`AddDispelTypeTexture`/`SetMouseMotionEnabled`/`PixelUtil.SetSize` |
| Live-reapplying icon size/tooltip/cooldown-spiral to already-created buttons | `ReapplyLiveAuraButtonSettings` | `GetAuraGroupFrame`/`GetAuraGroupFrameCount` + same `Set*` calls, deferred via `Addon.ExecuteAfterCombatEnds` |
| Sort order mapping | `GetSortMethod`, `GetSortDirection` | `AuraContainerSortMethod`/`AuraContainerSortDirection` enums |
| Grid layout / anchoring | `Widget:UpdateAuraContainer`, `GetFlowLayoutForAlignment` | `SetFlowLayoutAnchorPoint`/`GrowthDirection`/`MaximumLineSize`, `SetAuraGroupLayout`; addon's own `AnchorFrameTo` for positioning relative to the healthbar/sibling grid |
| Dispel-type border coloring | `InitializeAuraButton`, `BuildDispelTypeColorMap` | `AddDispelTypeTexture(texture, { style = Border, customDispelColorMap, ... })` |
| Per-plate update entry points | `Widget:OnUnitAdded` → `Widget:UpdateAuras` → `Widget:UpdateAurasGrids` → `Widget:UpdateAuraContainer` (×3, one per aura type) | — |

---

## 4. `BuildGroupConfigsFromConditions` — the multi-group combination algorithm

Buffs and Debuffs (both reactions) support independent, freely-combinable OR-conditions: each active
Options toggle becomes its own `AddAuraGroup`. An aura matching two simultaneously-active toggles
must render via exactly one group, never zero or two. `BuildGroupConfigsFromConditions` guarantees
this:

- Each condition, in the order its caller pushed it into the `conditions` list, gets every
  **earlier** condition's tokens negated (`!token`) and boolean `candidateFilters` fields forced
  `false` into its own filter — so a double-matching aura only ever satisfies the *first* group it
  matches, never a later one.
- Exclusion is **ordered, not symmetric**: each condition excludes only the conditions listed
  *before* it, never the ones after. Symmetric exclusion (every group excluding every other active
  condition from itself) would make a double-matching aura fail *both* groups' restrictions and
  vanish entirely. Ordered exclusion instead guarantees every aura shows via exactly one group: the
  earliest-listed condition it satisfies. Which condition "wins" for a double match is an arbitrary
  but deterministic tie-break (list order = push order in the calling `Get*GroupConfigs` function).
- The `"dispeltype"` condition key is exempt from this exclusion loop: `candidateFilters.includeDispelTypes`
  is a table, not a plain boolean/token, so it can't be negated the same way. Instead, every *other*
  group gets `candidateFilters.excludeDispelTypes` set to the checked dispel types whenever a
  `"dispeltype"` group exists, so the exclusion direction is reversed for that one case (everyone
  else excludes it, instead of it excluding everyone before it).
- `All`/`All on NPCs` toggles always short-circuit into a single unrestricted group instead of
  joining the free combination — "All on NPCs" has no `candidateFilters` equivalent for "unit is an
  NPC" to cross-exclude it with, so treating it as a peer condition would duplicate every other
  active toggle's auras on NPC targets.

`CrowdControl` (either reaction) is still single-condition only (`GetCrowdControlFilterString`, a
plain `elseif`) — not converted to this pattern, since it only ever has one or two toggles to begin
with.

---

## 5. Aura filtering — the `Get*GroupConfigs` functions

Five functions turn today's Options settings into the `conditions` list `BuildGroupConfigsFromConditions`
(§4) consumes, one per aura-type/reaction combination. Each returns a table keyed by group name →
`{ filterString, candidateFilters }`; a group key from `AURA_GROUP_KEYS[aura_type]` missing from the
result means "disable this group" (`Widget:UpdateAuraContainer` sets its `maxFrameCount` to `0`).

- **`GetFriendlyBuffsGroupConfigs(db, unit)`** / **`GetEnemyBuffsGroupConfigs(db, unit)`** — `All`/
  `All on NPCs` (`unit.type == "NPC"`, checked in Lua since no `candidateFilters` field exists for
  "unit is an NPC") short-circuit into one unrestricted `"main"` group (also carrying `maxDuration`,
  see below). Otherwise: Friendly pushes `"main"` (Mine, `PLAYER` token), `"canapply"` (Player Can
  Apply, `candidateFilters.canApplyAura`), `"bigdefensive"` (Big Defensives, `BIG_DEFENSIVE` token);
  Enemy pushes `"dispellable"` (`DISPELLABLE` token) and `"magic"`
  (`candidateFilters.includeDispelTypes = { Magic = true }`). `MaxDurationFriendly` /
  `MaxDurationEnemy` - separate fields per reaction, moved here from Debuffs on 2026-08-16 - is
  stamped onto every resulting group's `candidateFilters.maxDuration` in a pass *after*
  `BuildGroupConfigsFromConditions` returns, since it's an AND-restriction on top of whichever
  OR-condition(s) ended up active (including `All`), not a condition/group of its own.
- **`GetFriendlyDebuffsGroupConfigs(db)`** / **`GetEnemyDebuffsGroupConfigs(db)`** — `All` short-circuits
  into one unrestricted `"main"` group. Otherwise, Boss (`"boss"`, `candidateFilters.isBossAura`) is always its
  own condition; Enemy additionally pushes `"main"` (Mine, `PLAYER` token — see the
  `isFromPlayerOrPlayerPet` gotcha in §6) and `"priority"` (`candidateFilters.isPriorityAura`).
  Blizzard is two peer groups, not one: `"important"` (`PLAYER` token + `candidateFilters.nameplateShowAll`)
  and `"importantpersonal"` (`PLAYER` token + `candidateFilters.nameplateShowPersonal`, with
  `nameplateShowAll` explicitly forced `false` to avoid double-rendering an aura that happens to carry
  both flags) — a single `AddAuraGroup` can't express "field A OR field B" since `candidateFilters`
  entries are ANDed together, so the two Blizzard curation flags (matches the legacy widget's
  `aura.nameplateShowAll or (aura.nameplateShowPersonal and aura.CastByPlayer)` — see the `IMPORTANT`
  gotcha in §6) need two groups. `"importantpersonal"` is built by cloning `"important"`'s
  already-fully-excluded result (same exclusions against Mine/Boss/Priority/dispeltype) rather than
  pushed through `BuildGroupConfigsFromConditions` as its own condition — both would carry the
  identical `PLAYER` token, and ordered exclusion would negate the earlier one's token into the later
  one's filter string (`PLAYER|!PLAYER`, a self-contradiction matching nothing). Both are hardcoded to
  always require `PLAYER`, not conditional on Mine, so "Blizzard" always means "my own Blizzard-
  flagged debuffs" rather than "anyone's" — checking Mine alongside it can't narrow the result
  further, since Mine's own group is already a superset.
  Dispellable + Dispel Type are combined rather than independent conditions: a `"dispeltype"` group is
  only ever pushed while Dispellable is checked, always carries the `DISPELLABLE` token plus
  `candidateFilters.includeDispelTypes` for whichever Curse/Disease/Magic/Poison boxes are checked —
  Enemy additionally adds the `PLAYER` token to this same group when Mine is also checked, so Mine +
  Dispellable + a checked type combine into "only my dispellable auras of that type". No duration cap
  exists for Debuffs — `MaxDuration` lives on Buffs only (see above), not Debuffs.
- **`GetCrowdControlFilterString(db, is_friendly)`** — not multi-group, a plain `elseif`: `All`
  (either reaction) returns an unrestricted Crowd Control filter string; Friendly with Dispellable
  checked adds the `DISPELLABLE` token (gated on `is_friendly` since the Enemy Options panel exposes
  no such toggle — reading `db.ShowDispellable` unconditionally would key off a boolean the Enemy UI
  can never set); otherwise returns `nil` (group disabled). Its plain-string return (not the
  group-keyed table shape the other four produce) is wrapped into the same shape via the
  `SingleGroupConfig` helper before reaching `Widget:UpdateAuraContainer`.

---

## 6. Blizzard API quirks relevant to this widget

Confirmed by reading Blizzard's own Lua source (`Interface/AddOns/Blizzard_AuraContainer/*.lua`)
and/or in-game testing. Worth knowing before touching this code.

- **`GetAuraGroupFrameCount(groupKey)` returns frame *pool* size, not live/displayed aura count.**
  Per `Blizzard_AuraContainerFrameProviders.lua`,
  `AuraContainerCustomFrameProviderMixin:GetOwnedFrameCount` → `#self.ownedFrames`. The pool grows in
  batches and never shrinks, so this number reflects the group's historical peak, not its current
  state. No safely addon-exposed "currently active aura count" API exists on `AuraContainer`
  (`GetAuraGroupFrame`/`GetAuraGroupFrameCount`/`HasAuraGroup` are the only public
  frame-introspection methods); `AuraButton:IsShown()` per-frame might work but is unverified.
- **`candidateFilters.isFromPlayerOrPlayerPet` does not actually restrict anything** on this
  client/patch — a group configured with it still shows auras from every caster, not just the
  player/pet. The `PLAYER` filter-string token (older, part of the classic `AuraFilters` vocabulary)
  is used instead everywhere "cast by me or my pet" filtering is needed. Root cause is unconfirmed —
  worth rechecking if other boolean `candidateFilters` fields ever show similarly inert behavior.
- **`IMPORTANT` only ever applies to helpful auras.** Per `AuraFilters`' own doc comment ("helpful
  auras that show on enemy nameplates even if non-stealable"), combining it with `HARMFUL` matches
  nothing at all. `candidateFilters.nameplateShowAll` (Blizzard's own default-nameplate curation flag)
  has no such helpful-only restriction and is used instead wherever "what Blizzard's own nameplates
  would show" semantics are needed — though for Enemy Debuffs' "Blizzard" toggle this is further
  scoped to `PLAYER` on top, by deliberate design (see §5), so it no longer literally means "what
  Blizzard would show for anyone", only for the player.
- **`includeSpellIDs`/`excludeSpellIDs` are reaction-restricted; other `candidateFilters` boolean
  fields are not.** Per `Blizzard_AuraContainerUtil.lua`'s `DoesAuraPassCandidateFilters`, only the
  two spell-ID checks are gated behind `CanApplyIdentityCandidateFilters` (valid only for Friendly
  Buffs and Enemy Debuffs/CrowdControl, silently no-op elsewhere). `isBossAura`/`includeDispelTypes`/
  `canApplyAura`/etc. are checked unconditionally for every reaction/aura-type combination.
- **`AuraButton`'s `initializeFrame` callback runs exactly once per physical frame**, at the moment
  Blizzard's internal frame-pool provider creates it (`Blizzard_AuraContainerFrameProviders.lua`,
  `AuraContainerCustomFrameProviderMixin:CreateFrame`, wrapped in `securecallfunction`) — never again
  on reuse/recycling. Any setting only ever applied inside `InitializeAuraButton` is therefore
  create-time-only unless something else re-applies it later. `ReapplyLiveAuraButtonSettings` does
  this for icon size/tooltip-enable/cooldown-spiral (plain `Set*` calls, safe to repeat) by
  enumerating already-created buttons via `GetAuraGroupFrame`/`GetAuraGroupFrameCount` and calling the
  same setters again from `Widget:UpdateSettings`. Stack count/duration text visibility and the
  dispel-type border toggle (`ShowAuraType`) are **not** covered by this — those conditionally
  *create* child textures/fontstrings once, rather than just setting a property, and there's no
  retroactive create/destroy path built for that; changing them in Options only affects newly-pooled
  buttons.
- **`AuraButton` carries `AccessRestrictionFlags = DenyTaintedAccessWhenAurasAreSecret`**
  (`Blizzard_AuraContainerShared.lua`). `InitializeAuraButton`'s calls run inside Blizzard's own
  `securecallfunction` wrapper and are therefore not tainted; `ReapplyLiveAuraButtonSettings`'s calls
  happen from plain (tainted) addon code instead. Whether this restriction actually covers layout
  setters like `SetSize` (versus only aura-data-revealing methods) isn't confirmed from source alone.
  `ReapplyLiveAuraButtonSettings` is deferred via `Addon.ExecuteAfterCombatEnds` like every other
  setting this addon can't safely change mid-combat, rather than risk it erroring on individual
  buttons.
- **No script-hook or callback exists on `AuraButton` for addon-attached visual effects** (glow
  outlines, flash-on-expiring), per a full read of the `AuraButton` mixin. `LibCustomGlow`/
  `Animation.Flash`-style hooks cannot attach.
- **No `OnSizeChanged`/reliable `GetHeight`/`GetPoint` on these Forbidden-Aspect containers** — calls
  throw "Can't measure restricted regions". This is why `UpdateAuraContainer`'s sibling-anchor offset
  uses the sibling's *configured* max height (`Rows * IconHeight + ...`) rather than its actual
  current rendered height — a container can't reliably report its own live size to another container
  trying to anchor below/above it.
- **`AuraContainerSortMethod` has no duration/creation-time sort value** — only
  `Default`/`BigDefensive`/`UnitFrameDebuff`/`ImportantOnly`/`Expiration`/`ExpirationOnly`/`Name`/
  `NameOnly`/`AuraInstanceIDOnly`. `SortOrder` settings of `"Duration"`/`"Creation"` fall back to
  `Default` (`GetSortMethod`).
- **`AddDispelTypeTexture`'s `customDispelColorMap` wants real `Color` objects** (`:GetRGBA()`
  callable), not plain `{r=, g=, b=}` tables — `_G.DebuffTypeColor` (and this widget's own fallback
  table) provide the latter, so `BuildDispelTypeColorMap` wraps each entry in `_G.CreateColor(...)`.
  `customDispelColorCurve` (a `C_CurveUtil` color curve) is the alternative Blizzard also supports,
  but needs a curve object; `customDispelColorMap` is functionally equivalent for this use case and
  needs no such object.
- **`customDispelColorMap`'s lookup key for an aura with no dispel type is the literal string
  `"None"`** (`Blizzard_CustomAuraButton.lua`'s `GetDispelTypeMapKey`: `auraData.dispelName or
  "None"`) - not documented anywhere obvious, found by reading the source. This is what makes
  `AuraWidget.DefaultBuffColor`/`DefaultDebuffColor` (Options: Appearance → Highlight → Buff/Debuff
  Color) work at all: `GetDispelTypeColorMapForAuraType` adds a `"None"` entry to a per-aura_type copy
  of `DISPEL_TYPE_COLOR_MAP`, and `showWithoutDispelType = true` on `AddDispelTypeTexture` makes the
  border draw for every aura instead of only dispel-typed ones - matching the legacy widget's
  `Widget:GetColorForAura`, which likewise colors every aura, not just dispel-typed ones.

---

## 7. Not implemented / not feasible on `AuraContainer` today

"Feasible" means a concrete Blizzard API exists to build it; "Not feasible" means the underlying
capability doesn't exist for addon code on `AuraButton`/`AuraContainer` as of Patch 12.1.0.

| Feature | Status | 12.1.0 API path | Feasible? |
| --- | --- | --- | --- |
| Bar display mode | hidden (Options) | `SetDurationBar(statusBar, options)` exists on `AuraButton` | **Yes** — not built yet |
| Highlight/glow (stealable-aura outline) | inert, not gated | none — no hook point (§6) | **No** |
| Flash-on-expiring | inert, not gated | none — same as Highlight | **No** |
| `SortOrder`: Duration / Creation | inert, falls back to Default | no enum value exists (§6) | **No** |
| Config/Demo preview mode | stubbed (`Widget:ToggleConfigurationMode` no-ops) | none — `AuraContainer` only ever shows real data for a real `SetUnit()` token | **No**, not with the current mechanism |
| `SwitchAuraAreaByReaction` | inert, not gated | pure Lua-side (`unit.reaction` is non-secret) — not an API blocker, just not wired in | **Yes** — trivial |
| Per-spell whitelist/blacklist | hidden (Options) | `candidateFilters.includeSpellIDs`/`excludeSpellIDs`, reaction-restricted (§6) | **Yes, partially** |
| "Dispellable (only me)" for Enemy Debuffs | not implemented | no Blizzard token/candidateFilters field for player-personal dispel capability exists — would need a static class/spec→dispel-type lookup table instead | **Yes, via workaround** |
| Dynamic sibling-height anchoring (no wasted vertical gap above an empty grid) | not implemented (static max-height used instead) | none found — `GetAuraGroupFrameCount` is pool size not live count (§6), no `GetHeight` on Forbidden containers | **No**, not with a currently-known API |
| `CenterAuras` | inert, not gated | pure Lua-side layout math (center the flow-layout group instead of growing from the alignment corner) — not an API blocker, just not wired into `UpdateAuraContainer`'s layout code | **Yes** — not built yet |
| `ModeIcon.ShowBorder` (generic icon border, independent of dispel-type coloring) | inert, only reachable via Options when Icon Style = Custom | none found for a plain non-dispel-type border texture beyond what `InitializeAuraButton` already draws | **Yes** — a plain `CreateTexture` border, same mechanism as the dispel-type border, just unconditional |

---

## 8. References

- WoW API wiki: [`API_types/AuraFilters`](https://warcraft.wiki.gg/wiki/API_types/AuraFilters)
- Blizzard source (`Interface/AddOns/Blizzard_AuraContainer/`): `Blizzard_CustomAuraContainer.lua`,
  `Blizzard_AuraContainerFrameProviders.lua`, `Blizzard_AuraContainerUtil.lua`,
  `Blizzard_AuraContainerShared.lua`, `Blizzard_AuraButton.lua`/`.xml`, `Blizzard_CustomAuraButton.lua`
