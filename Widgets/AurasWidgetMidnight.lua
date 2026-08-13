---------------------------------------------------------------------------------------------------
-- Auras Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

if not Addon.ExpansionIsAtLeastMidnight then return end

local Widget = Addon.Widgets:NewWidget("Auras")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local min = min

-- ThreatPlates APIs
local FontUpdateText = Addon.Font.UpdateText
local AuraTriggerInitialize, AuraTriggerUpdateStyle = Addon.Style.AuraTriggerInitialize, Addon.Style.AuraTriggerUpdateStyle
local MODE_FOR_STYLE, AnchorFrameTo = Addon.MODE_FOR_STYLE, Addon.AnchorFrameTo
local UnitIsUnitTP = Addon.UnitIsUnit

-- Patch 12.1.0: AuraContainer/AuraButton is Blizzard's replacement for addon-side aura scanning
-- (AuraUtil.ForEachAura/C_UnitAuras.GetUnitAuras) - it's secret-safe by design (Blizzard owns aura
-- fetching internally once SetUnit() is called), whereas the old addon-side pull model can throw or
-- come back empty for nameplate unit tokens even outside restricted periods [GH-723]. This is the
-- only aura display path in this widget; there is no addon-side fallback. Feature-detected the same
-- way Plater-Nameplates does it, since there is no dedicated expansion-level flag for this - only a
-- template-existence check.
local HasAuraContainers = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") and true or false
local AuraContainerSortMethod = _G.AuraContainerSortMethod
local AuraContainerSortDirection = _G.AuraContainerSortDirection

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, UIParent, InCombatLockdown, AnchorUtil, PixelUtil

---------------------------------------------------------------------------------------------------
-- Crowd Control Auras
---------------------------------------------------------------------------------------------------

local CROWD_CONTROL_SPELLS_BY_EXPANSION = {
  MAINLINE = {},
}

Widget.CROWD_CONTROL_SPELLS = CROWD_CONTROL_SPELLS_BY_EXPANSION[Addon.GetExpansionLevel()]

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local HideOmniCC, ShowDuration
local EnabledForStyle = {}

---------------------------------------------------------------------------------------------------
-- AuraContainer (Patch 12.1.0)
---------------------------------------------------------------------------------------------------
-- Buffs, Debuffs, and CrowdControl are all AuraContainer-driven, for both friendly and enemy units.
--
-- Known simplifications versus the addon's pre-AuraContainer Filter*BySpell functions:
-- - Buffs and Debuffs (both reactions) support independent, freely-combinable OR-conditions via one
--   AddAuraGroup per condition (see BuildGroupConfigsFromConditions and its callers). ShowAll*/
--   ShowOn*NPCs always short-circuit into a single unrestricted group first, though - "All on NPCs" is
--   conceptually "All, but scoped to NPCs", not a peer condition, and can't be freely combined with
--   the others the normal way (no candidateFilters field for "unit is an NPC" to cross-exclude it
--   with). Debuffs additionally supports MaxDuration (enemy only) as an AND-restriction on top of
--   whichever OR-condition(s) are active. CrowdControl (either reaction) is still single-condition
--   only (All vs. Dispellable, a plain "elseif") - not converted to the multi-group pattern.
-- - A crowd-control-classified aura is strictly exclusive to the CrowdControl grid (filtered out of
--   Debuffs via "!CROWD_CONTROL"); the old per-aura fallback (show as a normal debuff if the
--   CC-specific filter rejects it) is not replicated.
-- - SwitchAreaByReaction (swapping which screen position shows buffs vs. debuffs for friendly units)
--   is not implemented - each AuraContainer's aura type (buff/debuff) is now fixed to its own screen
--   position for both reactions.
-- - SortOrder "Duration"/"Creation" have no AuraContainerSortMethod equivalent and fall back to
--   Default (None/AtoZ/TimeLeft+Reverse are supported via GetSortMethod/GetSortDirection).
-- - Per-spell FilterBySpell (spell name/ID text list) is not implemented; candidateFilters.
--   includeSpellIDs/excludeSpellIDs would only be usable for Debuffs+CrowdControl on enemies anyway
--   (Blizzard restricts spell-ID candidate filters to helpful-on-assistable/harmful-on-non-assistable).
-- - Dispel-type border coloring is not implemented (SetAuraBorder rendered incorrectly in testing -
--   most buffs have no dispel type to begin with).
-- - Visual settings (font/size/tooltip/stack count/duration text visibility) are only applied once,
--   at pool-creation time - changing them in Options during the same session does not re-skin
--   already-pooled AuraButtons (Forbidden Aspects mean there is no per-aura Lua hook to reapply
--   style on demand, unlike the old manual icon-frame system).
-- - The demo/preview "Configuration Mode" and the aura-trigger custom-plate-style system (both
--   already non-functional prior to this) have no equivalent hook into AuraContainer and remain
--   unavailable.
-- - Debuffs' "dispeltype" group (FilterByType[1-4]) does not exclude the other Debuffs groups from
--   itself (an aura matching a checked dispel type AND e.g. Boss shows via both groups); this is a
--   real gap, unlike the reverse direction (other groups excluding checked dispel types from
--   themselves via candidateFilters.excludeDispelTypes), which is handled - see
--   GetEnemyDebuffsGroupConfigs/GetFriendlyDebuffsGroupConfigs.

-- Without this, auras Blizzard flags as nameplate-only are silently excluded (AuraUtil.lua's
-- IncludeNameplateOnly doc comment). Blizzard's own default nameplates always include this token in
-- both their buff and debuff filter strings (Blizzard_NamePlateAuras.lua) - matched here for parity.
local NAMEPLATE_ONLY = "INCLUDE_NAME_PLATE_ONLY"

local AURA_CONTAINER_POOL_SIZE = 40 -- matches the practical max concurrent nameplate count (same assumption Plater-Nameplates uses)
local AURA_CONTAINER_TYPES = { "Buffs", "Debuffs", "CrowdControl" }
-- AddAuraGroup keys declared per aura type - Debuffs (either reaction) and Buffs (friendly) get one
-- group per independent OR-condition (see GetEnemyDebuffsGroupConfigs/GetFriendlyDebuffsGroupConfigs/
-- GetFriendlyBuffsGroupConfigs); Buffs (enemy) and CrowdControl (either reaction) only ever use "main".
local AURA_GROUP_KEYS = {
  Buffs = { "main", "canapply", "bigdefensive", "dispellable", "magic" },
  Debuffs = { "main", "important", "boss", "priority", "dispellable", "dispeltype" },
  CrowdControl = { "main" },
}
local DISPEL_TYPE_NAMES = { "Curse", "Disease", "Magic", "Poison" } -- index matches Debuffs.FilterByType[1..4]

local AuraContainerPool = { Buffs = {}, Debuffs = {}, CrowdControl = {} }
local NextAuraContainerIndex = { Buffs = 1, Debuffs = 1, CrowdControl = 1 }

local function InitializeAuraButton(auraButton, aura_type)
  local db_icon = Widget.db[aura_type].ModeIcon

  auraButton.Icon = auraButton:CreateTexture(nil, "ARTWORK", nil, -5)
  auraButton.Icon:SetAllPoints(auraButton)
  auraButton.Icon:SetTexCoord(.10, 1 - .07, .12, 1 - .12) -- Style: Square - remove border from icons
  auraButton:SetIcon(auraButton.Icon)

  auraButton.Cooldown = Addon.CreateCooldown(auraButton, HideOmniCC)
  auraButton.Cooldown:SetShownSwipe(Widget.db.ShowCooldownSpiral, HideOmniCC)
  auraButton:SetDurationCooldown(auraButton.Cooldown)

  if Widget.db.ShowStackCount then
    -- Font must be set before SetApplicationCount below: it triggers an immediate
    -- UpdateAuraDisplay() -> FontString:SetText(), which errors ("Font not set") on a FontString
    -- that was just created with CreateFontString(nil, ...) and has no font applied yet.
    auraButton.Stacks = auraButton:CreateFontString(nil, "OVERLAY")
    auraButton.Stacks:SetJustifyH("right")
    auraButton.Stacks:SetPoint("BOTTOMRIGHT", 3, -2)
    FontUpdateText(auraButton, auraButton.Stacks, db_icon.StackCount)
    auraButton:SetApplicationCount(auraButton.Stacks)
  end

  if ShowDuration then
    -- Same font-before-Set* ordering requirement as SetApplicationCount above.
    auraButton.TimeLeft = auraButton:CreateFontString(nil, "OVERLAY")
    FontUpdateText(auraButton, auraButton.TimeLeft, db_icon.Duration)
    auraButton:SetDurationText(auraButton.TimeLeft)
  end

  -- AuraButton tooltips are managed by Blizzard automatically; no AuraFrameOnEnter/GameTooltip code
  -- needed on our side, just whether mouse interaction is enabled at all.
  auraButton:SetMouseMotionEnabled(Widget.db.ShowTooltips)
  auraButton:SetHideTooltipInCombat(true)

  PixelUtil.SetSize(auraButton, db_icon.IconWidth, db_icon.IconHeight)
end

-- Maps the widget's SortOrder setting to the closest AuraContainerSortMethod. Duration/Creation have
-- no equivalent sort method and fall back to Default.
local function GetSortMethod(sort_order)
  if sort_order == "AtoZ" then
    return AuraContainerSortMethod.Name
  elseif sort_order == "TimeLeft" then
    return AuraContainerSortMethod.Expiration
  end

  return AuraContainerSortMethod.Default
end

local function GetSortDirection(sort_reverse)
  return sort_reverse and AuraContainerSortDirection.Reverse or AuraContainerSortDirection.Normal
end

local function CreateAuraContainer(aura_type)
  local container = _G.CreateFrame("AuraContainer", nil, _G.UIParent, "CustomAuraContainerTemplate")
  local effect = (aura_type == "Buffs" and "HELPFUL") or "HARMFUL"
  local group_options = {
    initializeFrame = function(auraButton) InitializeAuraButton(auraButton, aura_type) end,
    sortMethod = GetSortMethod(Widget.db.SortOrder),
    sortDirection = GetSortDirection(Widget.db.SortReverse),
  }

  for _, group_key in ipairs(AURA_GROUP_KEYS[aura_type]) do
    container:AddAuraGroup(group_key, effect, group_options)
  end
  container:SetEnabled(false)

  return container
end

-- AuraContainers cannot be created during combat, so the pools are built once up front (called from
-- Widget:OnEnable, which runs at login/reload - effectively always out of combat - and retried from
-- Widget:PLAYER_REGEN_ENABLED/DISABLED in case the widget was first enabled mid-combat) rather than
-- lazily per-plate like the rest of this widget's frames.
local function PreallocateAuraContainers()
  if not HasAuraContainers then return end

  if _G.InCombatLockdown() then
    Addon.Logging.Debug("    Auras: could not pre-allocate AuraContainer pools - in combat, will retry after combat ends.")
    return
  end

  for _, aura_type in ipairs(AURA_CONTAINER_TYPES) do
    local pool = AuraContainerPool[aura_type]
    if #pool == 0 then
      for i = 1, AURA_CONTAINER_POOL_SIZE do
        pool[i] = CreateAuraContainer(aura_type)
      end
    end
  end
end

local function AcquireAuraContainer(aura_type)
  local pool = AuraContainerPool[aura_type]
  local index = NextAuraContainerIndex[aura_type]
  local container = pool[index]
  if container then
    NextAuraContainerIndex[aura_type] = index + 1
  else
    Addon.Logging.Error("|cffFF8800[AuraDebug]|r", aura_type, "pool exhausted at index", index, "- this plate will show no", aura_type)
  end

  return container
end

-- Composes the AuraFilters string/candidateFilters for each type/reaction combination from today's
-- boolean settings. See the simplifications note above the pool constant.

-- Shared multi-group builder: turns a list of independent OR-conditions into one AddAuraGroup config
-- per condition. base_filter_parts is the always-present prefix (aura type plus any fixed exclusions,
-- e.g. {"HARMFUL", "!CROWD_CONTROL", NAMEPLATE_ONLY}). dispel_types/has_dispel_type (optional) apply
-- candidateFilters.excludeDispelTypes to every non-"dispeltype" condition - a "dispeltype" condition's
-- own candidateFilters.includeDispelTypes is a table, so it can't be negated into a "!token"/
-- false-boolean like every other condition; this is the inverse fix for that (see the comment on
-- GetEnemyDebuffsGroupConfigs for the full duplication story this prevents).
--
-- Exclusion is *ordered*, not symmetric: each condition excludes only the conditions *before* it in
-- the list, never the ones after. Excluding every other condition in both directions (as an earlier
-- version of this function did) means an aura matching two simultaneously-active conditions fails
-- *both* groups' restrictions and vanishes entirely - neither shown twice nor once, just gone. Ordered
-- exclusion instead gives every aura exactly one home: it shows via the earliest-listed condition it
-- satisfies, and every later condition explicitly excludes that earlier one from itself. Which
-- condition "wins" for a double-matching aura is an arbitrary but deterministic tie-break (list order
-- = the order each condition is pushed into `conditions` by the caller); the important part is that it
-- always shows via exactly one group.
--
-- Returns a table keyed by group name -> { filterString = ..., candidateFilters = ... }; a group key
-- from AURA_GROUP_KEYS[aura_type] missing from the result means "disable this group" (caller sets
-- maxFrameCount to 0).
local function BuildGroupConfigsFromConditions(conditions, base_filter_parts, dispel_types, has_dispel_type)
  local configs = {}
  for i, condition in ipairs(conditions) do
    local filter_parts = {}
    for _, part in ipairs(base_filter_parts) do
      filter_parts[#filter_parts + 1] = part
    end
    local candidate_filters = {}
    for field, value in pairs(condition.candidateFilters) do
      candidate_filters[field] = value
    end
    for _, token in ipairs(condition.filterTokens) do
      filter_parts[#filter_parts + 1] = token
    end

    if condition.key ~= "dispeltype" then
      for j = 1, i - 1 do
        local other = conditions[j]
        for _, token in ipairs(other.filterTokens) do
          filter_parts[#filter_parts + 1] = "!" .. token
        end
        for field, value in pairs(other.candidateFilters) do
          if type(value) == "boolean" and candidate_filters[field] == nil then
            candidate_filters[field] = false
          end
        end
      end

      if has_dispel_type then
        candidate_filters.excludeDispelTypes = dispel_types
      end
    end

    configs[condition.key] = { filterString = table.concat(filter_parts, "|"), candidateFilters = candidate_filters }
  end

  return configs
end

-- Buffs (friendly): ShowAllFriendly/ShowOnFriendlyNPCs (unit.type == "NPC" only) short-circuit into an
-- unrestricted "main" group, same as "All" everywhere else - "All on NPCs" is conceptually "All, but
-- scoped to NPCs", not a peer condition, so it can't be freely combined with Mine/CanApply/
-- BigDefensives the normal way (there's no candidateFilters field for "unit is an NPC" to cross-
-- exclude it with; combining it as a peer group would double-render every other active condition's
-- auras on NPC targets). Otherwise Mine/PlayerCanApply/BigDefensives are independent,
-- freely-combinable OR-conditions.
local function GetFriendlyBuffsGroupConfigs(db, unit)
  if db.ShowAllFriendly or (db.ShowOnFriendlyNPCs and unit.type == "NPC") then
    return { main = { filterString = "HELPFUL|" .. NAMEPLATE_ONLY, candidateFilters = {} } }
  end

  local conditions = {}
  if db.ShowOnlyMine then
    conditions[#conditions + 1] = { key = "main", filterTokens = { "PLAYER" }, candidateFilters = {} }
  end
  if db.ShowPlayerCanApply then
    conditions[#conditions + 1] = { key = "canapply", filterTokens = {}, candidateFilters = { canApplyAura = true } }
  end
  if db.ShowFriendlyBigDefensives then
    conditions[#conditions + 1] = { key = "bigdefensive", filterTokens = { "BIG_DEFENSIVE" }, candidateFilters = {} }
  end

  return BuildGroupConfigsFromConditions(conditions, { "HELPFUL", NAMEPLATE_ONLY })
end

-- Buffs (enemy): same pattern as Friendly above - ShowAllEnemy/ShowOnEnemyNPCs short-circuit,
-- Dispellable/Magic are independent, freely-combinable OR-conditions.
local function GetEnemyBuffsGroupConfigs(db, unit)
  if db.ShowAllEnemy or (db.ShowOnEnemyNPCs and unit.type == "NPC") then
    return { main = { filterString = "HELPFUL|" .. NAMEPLATE_ONLY, candidateFilters = {} } }
  end

  local conditions = {}
  if db.ShowDispellable then
    -- DISPELLABLE (Patch 12.1.0): dispellable by anyone, not just RAID_PLAYER_DISPELLABLE's "a raid
    -- member's kit can dispel this specifically" - broader, matches what the "Dispellable" label implies.
    conditions[#conditions + 1] = { key = "dispellable", filterTokens = { "DISPELLABLE" }, candidateFilters = {} }
  end
  if db.ShowMagic then
    conditions[#conditions + 1] = { key = "magic", filterTokens = {}, candidateFilters = { includeDispelTypes = { Magic = true } } }
  end

  return BuildGroupConfigsFromConditions(conditions, { "HELPFUL", NAMEPLATE_ONLY })
end

-- Debuffs (friendly): same multi-group independent-OR-condition pattern as Debuffs (enemy) below
-- (Dispellable/Boss/FilterByType are the legacy friendly-only fields, see the note above their
-- Constants.lua defaults). ShowAllFriendly short-circuits everything into "main" alone.
local function GetFriendlyDebuffsGroupConfigs(db)
  if db.ShowAllFriendly then
    return { main = { filterString = "HARMFUL|!CROWD_CONTROL|" .. NAMEPLATE_ONLY, candidateFilters = {} } }
  end

  local conditions = {}
  if db.ShowDispellable then
    conditions[#conditions + 1] = { key = "dispellable", filterTokens = { "DISPELLABLE" }, candidateFilters = {} }
  end
  if db.ShowBoss then
    conditions[#conditions + 1] = { key = "boss", filterTokens = {}, candidateFilters = { isBossAura = true } }
  end

  local dispel_types, has_dispel_type = {}, false
  for i, dispel_name in ipairs(DISPEL_TYPE_NAMES) do
    if db.FilterByType[i] then
      dispel_types[dispel_name] = true
      has_dispel_type = true
    end
  end
  if has_dispel_type then
    conditions[#conditions + 1] = { key = "dispeltype", filterTokens = {}, candidateFilters = { includeDispelTypes = dispel_types } }
  end

  return BuildGroupConfigsFromConditions(conditions, { "HARMFUL", "!CROWD_CONTROL", NAMEPLATE_ONLY }, dispel_types, has_dispel_type)
end

local function GetCrowdControlFilterString(db, is_friendly)
  if db.ShowAllFriendly or db.ShowAllEnemy then
    return "HARMFUL|CROWD_CONTROL|" .. NAMEPLATE_ONLY
  elseif is_friendly and db.ShowDispellable then
    -- ShowDispellable only has a Friendly Options entry (Enemy Midnight panel exposes no such
    -- toggle) - gate on is_friendly to keep it from also gating on a Boolean the enemy UI can't set.
    return "HARMFUL|CROWD_CONTROL|DISPELLABLE|" .. NAMEPLATE_ONLY
  end

  return nil
end

-- Builds the full set of AddAuraGroup configs (per AURA_GROUP_KEYS.Debuffs key) for enemy-reaction
-- Debuffs from today's boolean settings. ShowAllEnemy short-circuits everything into "main" alone.
-- Otherwise each of ShowOnlyMine ("main"), ShowBlizzardForEnemy ("important", IMPORTANT auras),
-- ShowBoss ("boss", candidateFilters.isBossAura), ShowPriority ("priority",
-- candidateFilters.isPriorityAura), and ShowDispellable ("dispellable", DISPELLABLE auras) is an
-- independent, freely-combinable OR-condition: every group's filter string/candidateFilters excludes
-- every *earlier-listed* active condition (see BuildGroupConfigsFromConditions), so an aura matching
-- more than one toggle is always assigned to exactly one group - the earliest one it satisfies -
-- instead of showing twice or (with the naive "exclude every other condition in both directions"
-- approach this used to have) vanishing from both. FilterByType[1-4] ("dispeltype") is
-- built the same way, but since candidateFilters.includeDispelTypes is a table (not a plain boolean/
-- token), it can't be negated into the other groups' filters the same way - instead, every other
-- group explicitly excludes the checked dispel types via candidateFilters.excludeDispelTypes, so an
-- aura matching e.g. both a checked dispel type and Boss only ever shows via "dispeltype".
--
-- Returns a table keyed by group name -> { filterString = ..., candidateFilters = ... }; a group
-- key that's missing from the result means "disable this group" (caller sets maxFrameCount to 0).
local function GetEnemyDebuffsGroupConfigs(db)
  -- maxDuration (Patch 12.1.0): non-nil implicitly hides permanent auras too, per Blizzard's own
  -- documentation - applied as an extra AND-restriction on every active group below (not its own
  -- OR-condition/group), regardless of which other toggle(s) are active.
  local max_duration = (db.MaxDuration and db.MaxDuration > 0) and db.MaxDuration or nil

  if db.ShowAllEnemy then
    return { main = { filterString = "HARMFUL|!CROWD_CONTROL|" .. NAMEPLATE_ONLY, candidateFilters = { maxDuration = max_duration } } }
  end

  local conditions = {}
  if db.ShowOnlyMine then
    conditions[#conditions + 1] = { key = "main", filterTokens = {}, candidateFilters = { isFromPlayerOrPlayerPet = true } }
  end
  if db.ShowBlizzardForEnemy then
    conditions[#conditions + 1] = { key = "important", filterTokens = { "IMPORTANT" }, candidateFilters = {} }
  end
  if db.ShowBossEnemy then
    conditions[#conditions + 1] = { key = "boss", filterTokens = {}, candidateFilters = { isBossAura = true } }
  end
  if db.ShowPriority then
    conditions[#conditions + 1] = { key = "priority", filterTokens = {}, candidateFilters = { isPriorityAura = true } }
  end
  if db.ShowDispellableEnemy then
    conditions[#conditions + 1] = { key = "dispellable", filterTokens = { "DISPELLABLE" }, candidateFilters = {} }
  end

  local dispel_types, has_dispel_type = {}, false
  for i, dispel_name in ipairs(DISPEL_TYPE_NAMES) do
    if db.FilterByTypeEnemy[i] then
      dispel_types[dispel_name] = true
      has_dispel_type = true
    end
  end
  if has_dispel_type then
    conditions[#conditions + 1] = { key = "dispeltype", filterTokens = {}, candidateFilters = { includeDispelTypes = dispel_types } }
  end

  local configs = BuildGroupConfigsFromConditions(conditions, { "HARMFUL", "!CROWD_CONTROL", NAMEPLATE_ONLY }, dispel_types, has_dispel_type)
  for _, config in pairs(configs) do
    config.candidateFilters.maxDuration = max_duration
  end

  return configs
end

-- Derives AuraContainer flow-layout anchor/growth direction from the widget's AlignmentH/AlignmentV
-- settings (same semantics as the addon's other grid-layout alignment settings).
local function GetFlowLayoutForAlignment(alignment_h, alignment_v)
  local anchor_point = alignment_v .. alignment_h
  local horizontal_direction = (alignment_h == "LEFT") and AnchorUtil.FlowDirection.Right or AnchorUtil.FlowDirection.Left
  local vertical_direction = (alignment_v == "BOTTOM") and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down

  return anchor_point, horizontal_direction, vertical_direction
end

-- Configures the plate's pooled AuraContainer for aura_type ("Buffs"/"Debuffs"/"CrowdControl") for
-- the current settings/unit and assigns the unit to it. Returns true if the container was enabled
-- for this unit - the container manages its own aura-level visibility internally and
-- asynchronously, so there is no "has active auras" count available here; callers use this return
-- value (whether display was enabled at all, independent of actual aura presence) as a stand-in.
-- group_configs: table keyed by group name ("main", and for Debuffs also "important"/"boss"/
-- "priority"/"dispellable"/"dispeltype") -> { filterString = ..., candidateFilters = ... }. A group
-- key from AURA_GROUP_KEYS[aura_type] missing from group_configs is disabled (maxFrameCount = 0).
-- Buffs/CrowdControl callers only ever populate "main"; Debuffs callers may populate several.
function Widget:UpdateAuraContainer(widget_frame, aura_type, group_configs, unit)
  local container = widget_frame[aura_type .. "AuraContainer"]
  if not container then return false end

  if not group_configs or not next(group_configs) then
    container:SetEnabled(false)
    return false
  end

  local db = self.db[aura_type]
  local db_icon = db.ModeIcon
  local max_auras = min(db_icon.MaxAuras, db_icon.Rows * db_icon.Columns)
  local anchor_point, horizontal_direction, vertical_direction = GetFlowLayoutForAlignment(db.AlignmentH, db.AlignmentV)
  local sort_method = GetSortMethod(self.db.SortOrder)
  local sort_direction = GetSortDirection(self.db.SortReverse)
  local layout = {
    elementWidth = db_icon.IconWidth,
    elementHeight = db_icon.IconHeight,
    elementSpacing = db_icon.ColumnSpacing,
    lineSpacing = db_icon.RowSpacing,
  }

  for _, group_key in ipairs(AURA_GROUP_KEYS[aura_type]) do
    local config = group_configs[group_key]
    if config then
      container:SetAuraGroupFilterString(group_key, config.filterString)
      container:SetAuraGroupCandidateFilters(group_key, config.candidateFilters)
      container:SetAuraGroupMaxFrameCount(group_key, max_auras)
      container:SetAuraGroupSortMethod(group_key, sort_method, sort_direction)
      container:SetAuraGroupLayout(group_key, layout)
    else
      -- Not an active condition this update - disable without touching its filter string.
      container:SetAuraGroupMaxFrameCount(group_key, 0)
    end
  end

  container:SetFlowLayoutAnchorPoint(anchor_point)
  container:SetFlowLayoutGrowthDirection(horizontal_direction, vertical_direction)
  container:SetFlowLayoutMaximumLineSize(db_icon.Columns * (db_icon.IconWidth + db_icon.ColumnSpacing))

  container:SetUnit(unit.unitid)
  container:SetEnabled(true)

  -- AnchorTo can reference "Healthbar" (this widget's own frame) or another aura type's name
  -- ("Buffs"/"Debuffs"/"CrowdControl", meaning "stack above/below that grid"). We cannot anchor
  -- directly to that sibling AuraContainer's live edge: its size changes dynamically as auras are
  -- added/removed, and addons have no OnSizeChanged access to react to that (Forbidden Aspects
  -- block it) - the anchor would only ever reflect whatever the sibling's size happened to be at our
  -- last update, causing overlap as it grows afterwards. Instead, anchor to Healthbar like the
  -- sibling itself does, and add the sibling's *configured* (not live) max height to the offset, so
  -- there's always enough room regardless of how many auras it's currently showing.
  --
  -- Dynamic sizing was attempted (candidateFilters-free counter via
  -- CustomAuraContainerSharedMixin:GetAuraGroupFrameCount) but reverted: that counter reflects the
  -- group's frame *pool* size (grows in batches, never shrinks), not the currently-displayed aura
  -- count, so it made the reserved height "stuck at historical peak" instead of "always max" - a
  -- different bug, not a fix. No safely addon-exposed "currently active aura count" API was found;
  -- revisit if Blizzard ever exposes one.
  local anchor_to_db = db.AnchorTo
  local anchor_config = db[MODE_FOR_STYLE[unit.style]]
  local anchor_to = widget_frame

  if anchor_to_db ~= "Healthbar" then
    local sibling_icon = self.db[anchor_to_db].ModeIcon
    local sibling_height = sibling_icon.Rows * sibling_icon.IconHeight + (sibling_icon.Rows - 1) * sibling_icon.RowSpacing
    anchor_config = {
      Anchor = anchor_config.Anchor,
      InsideAnchor = anchor_config.InsideAnchor,
      HorizontalOffset = anchor_config.HorizontalOffset,
      VerticalOffset = (anchor_config.VerticalOffset or 0) + sibling_height,
    }
  end

  AnchorFrameTo(anchor_config, container, anchor_to)

  return true
end

---------------------------------------------------------------------------------------------------
-- Auras Module / Handler
---------------------------------------------------------------------------------------------------

local function IgnoreAuraUpdateForUnit(widget_frame, unit)
  -- ! "Target Only" only supports the direct target, not action targets
  local unit_is_target = UnitIsUnitTP("target", unit.unitid)
  if Widget.db.ShowTargetOnly then
    if unit_is_target then
      Widget.CurrentTarget = widget_frame
    elseif not Addon.ActiveAuraTriggers then
      -- Continue with aura scanning for non-target units if there are aura triggers that might change the nameplates style
      widget_frame:Hide()
      return true
    end
  end

  AuraTriggerInitialize(unit)

  widget_frame.HideAuras = not EnabledForStyle[unit.style] or (Widget.db.ShowTargetOnly and not unit_is_target)
end

local function AuraGridUpdateForUnitNotNecessary(widget_frame, unit)
  AuraTriggerUpdateStyle(unit)

  if widget_frame.HideAuras then
    widget_frame:Hide()
    return true
  end
end

-- Wraps a plain filter string into the single-"main"-group config shape UpdateAuraContainer expects.
local function SingleGroupConfig(filter_string, candidate_filters)
  return filter_string and { main = { filterString = filter_string, candidateFilters = candidate_filters or {} } } or nil
end

function Widget:UpdateAurasGrids(widget_frame, unit)
  local db = self.db
  local is_friendly = unit.reaction == "FRIENDLY"

  -- Deliberately not "is_friendly and X or Y": when X is a legitimate nil/false (e.g. no friendly
  -- toggle matches this unit), that idiom falls through to Y - the *other* reaction's settings -
  -- instead of correctly yielding "nothing to show" for this reaction.
  local buffs_configs, debuffs_configs, enabled_cc
  if is_friendly then
    buffs_configs = db.Buffs.ShowFriendly and GetFriendlyBuffsGroupConfigs(db.Buffs, unit)
    debuffs_configs = db.Debuffs.ShowFriendly and GetFriendlyDebuffsGroupConfigs(db.Debuffs)
    enabled_cc = db.CrowdControl.ShowFriendly
  else
    buffs_configs = db.Buffs.ShowEnemy and GetEnemyBuffsGroupConfigs(db.Buffs, unit)
    debuffs_configs = db.Debuffs.ShowEnemy and GetEnemyDebuffsGroupConfigs(db.Debuffs)
    enabled_cc = db.CrowdControl.ShowEnemy
  end
  local cc_configs = enabled_cc and SingleGroupConfig(GetCrowdControlFilterString(db.CrowdControl, is_friendly))

  local buffs_active = self:UpdateAuraContainer(widget_frame, "Buffs", buffs_configs, unit)
  local debuffs_active = self:UpdateAuraContainer(widget_frame, "Debuffs", debuffs_configs, unit)
  local cc_active = self:UpdateAuraContainer(widget_frame, "CrowdControl", cc_configs, unit)

  if AuraGridUpdateForUnitNotNecessary(widget_frame, unit) then
    for _, aura_type in ipairs(AURA_CONTAINER_TYPES) do
      local container = widget_frame[aura_type .. "AuraContainer"]
      if container then container:SetEnabled(false) end
    end
    return
  end

  if buffs_active or debuffs_active or cc_active then
    widget_frame:Show()
  else
    widget_frame:Hide()
  end
end

function Widget:UpdateAuras(widget_frame, unit)
  if not IgnoreAuraUpdateForUnit(widget_frame, unit) then
    self:UpdateAurasGrids(widget_frame, unit)
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = _G.CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------
  widget_frame:SetAllPoints(tp_frame)

  for _, aura_type in ipairs(AURA_CONTAINER_TYPES) do
    local container = AcquireAuraContainer(aura_type)
    if container then
      container:SetParent(widget_frame)
      container:SetEnabled(false)
      widget_frame[aura_type .. "AuraContainer"] = container
    end
  end

  widget_frame.Widget = self

  self:UpdateLayout(widget_frame)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  self.db = Addon.db.profile.AuraWidget
  return self.db.ON or self.db.ShowInHeadlineView
end

function Widget:OnEnable()
  self:SubscribeEvent("PLAYER_TARGET_CHANGED")
  self:SubscribeEvent("PLAYER_REGEN_ENABLED")
  self:SubscribeEvent("PLAYER_REGEN_DISABLED")

  PreallocateAuraContainers()
end

function Widget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return self.db.ShowInHeadlineView or Addon.ActiveAuraTriggers
  elseif style ~= "etotem" then
    return self.db.ON or Addon.ActiveAuraTriggers
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  self:UpdateAuras(widget_frame, unit)
end

-- Initialize the aura container layout, don't update auras themselves as not unitid know at this point
function Widget:UpdateLayout(widget_frame)
  local frame_level
  if self.db.FrameOrder == "HEALTHBAR_AURAS" then
    frame_level = widget_frame:GetParent():GetFrameLevel() + 1
  else
    frame_level = widget_frame:GetParent():GetFrameLevel() + 9
  end
  widget_frame:SetFrameLevel(frame_level)

  for _, aura_type in ipairs(AURA_CONTAINER_TYPES) do
    local container = widget_frame[aura_type .. "AuraContainer"]
    if container then
      container:SetFrameLevel(frame_level)
    end
  end
end

function Widget:PLAYER_TARGET_CHANGED()
  if not self.db.ShowTargetOnly then return end

  if self.CurrentTarget then
    self.CurrentTarget:Hide()
    self.CurrentTarget = nil
  end

  local tp_frame = Addon:GetThreatPlateForTarget()
  if tp_frame then
    self.CurrentTarget = tp_frame.widgets.Auras

    if self.CurrentTarget.Active then
      self:UpdateAuras(self.CurrentTarget, tp_frame.unit)
    end
  end
end

function Widget:PLAYER_REGEN_ENABLED()
  -- Retries pool creation if the widget was first enabled mid-combat (e.g. /reload during a fight),
  -- so the AuraContainer pools never got a chance to be created. No-op once the pools already exist.
  -- Also fires (harmlessly, InCombatLockdown() guards it) on the aliased PLAYER_REGEN_DISABLED.
  PreallocateAuraContainers()
end

Widget.PLAYER_REGEN_DISABLED = Widget.PLAYER_REGEN_ENABLED

-- Load settings from the configuration which are shared across all aura widgets
-- used (for each widget) in UpdateWidgetConfig
function Widget:UpdateSettings()
  self.db = Addon.db.profile.AuraWidget

  HideOmniCC = not self.db.ShowOmniCC or Addon.ExpansionIsAtLeastMidnight
  ShowDuration = self.db.ShowDuration and HideOmniCC

  EnabledForStyle["NameOnly"] = self.db.ShowInHeadlineView
  EnabledForStyle["NameOnly-Unique"] = self.db.ShowInHeadlineView
  EnabledForStyle["dps"] = self.db.ON
  EnabledForStyle["tank"] = self.db.ON
  EnabledForStyle["normal"] = self.db.ON
  EnabledForStyle["totem"] = self.db.ON
  EnabledForStyle["unique"] = self.db.ON
  EnabledForStyle["etotem"] = false
  EnabledForStyle["empty"] = false
end

---------------------------------------------------------------------------------------------------
-- Configuration Mode / Debug - stubs only, kept so external call sites (Options.lua's
-- "Configuration Mode" toggle, Commands.lua's "/tptp debug Auras ...") don't error. Neither the
-- demo/preview aura fabrication nor the debug aura dump has an equivalent hook into AuraContainer
-- (Blizzard owns aura fetching internally via SetUnit() on a real unit token).
---------------------------------------------------------------------------------------------------

function Widget:ToggleConfigurationMode()
  Addon.Logging.Debug("    Auras: configuration/preview mode is not available with AuraContainer.")
end

function Widget:PrintDebug(command)
  Addon.Logging.Debug("    Auras: per-aura debug dump is not available with AuraContainer.")
end
