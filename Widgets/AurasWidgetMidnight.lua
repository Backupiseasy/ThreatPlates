---------------------------------------------------------------------------------------------------
-- Auras Widget (Midnight / 12.1+)
--
-- Patch 12.1 makes C_UnitAuras.GetAuraSlots / AuraUtil.ForEachAura error while auras are secret
-- (combat, encounters, M+, PvP) and the caller is tainted. Display auras through Blizzard's
-- AuraContainer / AuraButton APIs instead of reading aura data in Lua.
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

if not Addon.ExpansionIsAtLeastMidnight then return end

local Widget = Addon.Widgets:NewWidget("Auras")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

local pairs, ipairs = pairs, ipairs
local min, max = min, max
local tonumber = tonumber
local tinsert = table.insert

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown

local FontUpdateText = Addon.Font.UpdateText
local MODE_FOR_STYLE, AnchorFrameTo = Addon.MODE_FOR_STYLE, Addon.AnchorFrameTo
local UnitIsUnitTP = Addon.UnitIsUnit
local AuraTriggerInitialize, AuraTriggerUpdateStyle = Addon.Style.AuraTriggerInitialize, Addon.Style.AuraTriggerUpdateStyle

---------------------------------------------------------------------------------------------------
-- AuraContainer availability
---------------------------------------------------------------------------------------------------

local HAS_AURA_CONTAINER = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate")

local FlowDirection = AnchorUtil and AnchorUtil.FlowDirection
local SortMethod = AuraContainerSortMethod
local SortDirection = AuraContainerSortDirection
local DispelStyle = Enum.CustomAuraButtonDispelTypeTextureStyle
local ShouldAurasBeSecret = C_Secrets and C_Secrets.ShouldAurasBeSecret

local GROUP_KEYS = { "Main", "Mine", "Important", "Dispellable", "CrowdControl", "Whitelist" }

---------------------------------------------------------------------------------------------------
-- Cached configuration
---------------------------------------------------------------------------------------------------

Widget.TEXTURE_BORDER = Addon.ADDON_DIRECTORY .. "Artwork\\squareline"

Widget.Buffs = { CenterAurasPositions = {} }
Widget.Debuffs = { CenterAurasPositions = {} }
Widget.CrowdControl = { CenterAurasPositions = {} }

local HideOmniCC, ShowDuration
local EnabledForStyle = {}
local AuraFilterSpellIDs = {
  Buffs = { include = {}, exclude = {} },
  Debuffs = { include = {}, exclude = {} },
  CrowdControl = { include = {}, exclude = {} },
}

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

local function CanRestyleButtons()
  if InCombatLockdown() then
    return false
  end
  if ShouldAurasBeSecret and ShouldAurasBeSecret() then
    return false
  end
  return true
end

local function GetSpellIDFromIdentifier(spell)
  local id = tonumber(spell)
  if id then
    return id
  end
  if not spell or spell == "" then
    return nil
  end

  if C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
    local ok, result = pcall(C_Spell.GetSpellIDForSpellIdentifier, spell)
    if ok and result then
      return result
    end
  end

  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spell)
    if ok and type(info) == "table" and info.spellID then
      return info.spellID
    end
  end
end

local function JoinFilter(...)
  local parts = {}
  for i = 1, select("#", ...) do
    local part = select(i, ...)
    if part and part ~= "" then
      tinsert(parts, part)
    end
  end
  return table.concat(parts, "|")
end

local function CopySpellSet(src)
  if not src or not next(src) then
    return nil
  end
  local copy = {}
  for spell_id in pairs(src) do
    copy[spell_id] = true
  end
  return copy
end

local function IsWhitelist(filter_mode)
  return filter_mode == "whitelist" or filter_mode == "Allow"
end

local function IsBlacklist(filter_mode)
  return filter_mode == "blacklist" or filter_mode == "Block"
end

---------------------------------------------------------------------------------------------------
-- Aura button visuals
---------------------------------------------------------------------------------------------------

local function StyleAuraButton(button, aura_type)
  local aura_grid = Widget[aura_type]
  if not aura_grid then
    return
  end

  local db_icon = aura_grid.db
  local db_widget = aura_grid.db_widget or Widget.db
  local width = aura_grid.IconWidth or (db_icon and db_icon.IconWidth) or 16
  local height = aura_grid.IconHeight or (db_icon and db_icon.IconHeight) or 16

  button:SetSize(width, height)

  if button.Icon then
    button.Icon:SetTexCoord(0.10, 1 - 0.07, 0.12, 1 - 0.12)
  end

  if button.Cooldown then
    local show_swipe = db_widget and db_widget.ShowCooldownSpiral
    button.Cooldown:SetDrawSwipe(show_swipe and true or false)
    button.Cooldown:SetDrawEdge(show_swipe and true or false)
    button.Cooldown.noCooldownCount = HideOmniCC
  end

  if button.TimeLeft then
    if ShowDuration then
      button.TimeLeft:Show()
      if db_icon and db_icon.Duration then
        FontUpdateText(button, button.TimeLeft, db_icon.Duration)
      end
    else
      button.TimeLeft:Hide()
    end
  end

  if button.Stacks then
    if db_widget and db_widget.ShowStackCount then
      button.Stacks:Show()
      if db_icon and db_icon.StackCount then
        FontUpdateText(button, button.Stacks, db_icon.StackCount)
      end
    else
      button.Stacks:Hide()
    end
  end

  if button.Border then
    local show_border = not db_icon or db_icon.ShowBorder
    button.Border:SetShown(show_border and true or false)
    if show_border and db_widget then
      local color
      if aura_type == "Buffs" then
        color = db_widget.DefaultBuffColor
      else
        color = db_widget.DefaultDebuffColor
      end
      if color then
        button.Border:SetVertexColor(color.r or 0, color.g or 0, color.b or 0, color.a or 1)
      end
    end
  end

  local show_tooltips = db_widget and db_widget.ShowTooltips
  if button.SetHideTooltipInCombat then
    button:SetHideTooltipInCombat(not show_tooltips)
  end
  if CanRestyleButtons() and button.SetMouseMotionEnabled then
    button:SetMouseMotionEnabled(show_tooltips and true or false)
  end
end

local function InitAuraButton(button, aura_type)
  local aura_grid = Widget[aura_type]
  local width = aura_grid and aura_grid.IconWidth or 16
  local height = aura_grid and aura_grid.IconHeight or 16
  button:SetSize(width, height)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(button)
  icon:SetTexCoord(0.10, 1 - 0.07, 0.12, 1 - 0.12)
  button.Icon = icon
  button:SetIcon(icon)

  local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  cooldown:SetAllPoints(button)
  cooldown:SetReverse(true)
  cooldown:SetHideCountdownNumbers(true)
  cooldown:SetDrawBling(false)
  cooldown.noCooldownCount = HideOmniCC
  button.Cooldown = cooldown
  button:SetDurationCooldown(cooldown)

  local overlay = CreateFrame("Frame", nil, button)
  overlay:SetAllPoints(button)
  overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)
  button.Overlay = overlay

  local border = overlay:CreateTexture(nil, "OVERLAY")
  border:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
  border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
  border:SetTexture(Widget.TEXTURE_BORDER)
  button.Border = border

  local show_helpful = aura_type == "Buffs"
  if button.SetAuraBorder then
    button:SetAuraBorder(border, {
      showIcon = false,
      showWhenHarmful = not show_helpful,
      showWhenHelpful = show_helpful,
      showWithoutDispelType = true,
      style = DispelStyle and DispelStyle.PreserveAsset,
    })
  end

  -- AuraContainer calls SetText immediately after initializeFrame. FontStrings must
  -- inherit a font template (or SetFont) before SetApplicationCount / SetDurationText.
  local stacks = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  stacks:SetJustifyH("RIGHT")
  stacks:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, 0)
  button.Stacks = stacks
  if button.SetApplicationCount then
    button:SetApplicationCount(stacks)
  end

  local time_left = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  time_left:SetJustifyH("RIGHT")
  time_left:SetPoint("TOPRIGHT", button, "TOPRIGHT", 1, 0)
  button.TimeLeft = time_left
  if button.SetDurationText then
    button:SetDurationText(time_left)
  end

  button.AuraType = aura_type
  StyleAuraButton(button, aura_type)

  local container = button:GetParent()
  if container then
    container.AuraButtons = container.AuraButtons or {}
    tinsert(container.AuraButtons, button)
  end
end

---------------------------------------------------------------------------------------------------
-- Filter construction
---------------------------------------------------------------------------------------------------

local function CandidateFilters(include, exclude)
  local filters
  if include and next(include) then
    filters = filters or {}
    filters.includeSpellIDs = CopySpellSet(include)
  end
  if exclude and next(exclude) then
    filters = filters or {}
    filters.excludeSpellIDs = CopySpellSet(exclude)
  end
  return filters
end

local function AddGroup(groups, key, filter, include, exclude, max_count)
  if not filter or max_count == 0 then
    return
  end
  tinsert(groups, {
    key = key,
    filter = filter,
    candidates = CandidateFilters(include, exclude),
    maxCount = max_count,
  })
end

local function BuildGroupsForType(aura_type, unit, exclude_cc)
  local db = Widget.db[aura_type]
  local aura_grid = Widget[aura_type]
  local groups = {}
  local max_count = aura_grid and aura_grid.MaxAuras or 10
  local is_friendly = unit.reaction == "FRIENDLY"
  local is_npc = unit.type == "NPC"
  local spell_ids = AuraFilterSpellIDs[aura_type]
  local include = spell_ids and spell_ids.include
  local exclude = spell_ids and spell_ids.exclude
  local filter_mode = db.FilterMode
  local cc_neg = (aura_type == "Debuffs" and exclude_cc) and "!CROWD_CONTROL" or nil

  local enabled
  if is_friendly then
    enabled = db.ShowFriendly
  else
    enabled = db.ShowEnemy
  end
  if not enabled then
    return groups
  end

  if IsWhitelist(filter_mode) then
    local base
    if aura_type == "Buffs" then
      base = JoinFilter("HELPFUL", "INCLUDE_NAME_PLATE_ONLY")
    elseif aura_type == "CrowdControl" then
      base = JoinFilter("HARMFUL", "CROWD_CONTROL", "INCLUDE_NAME_PLATE_ONLY")
    else
      base = JoinFilter("HARMFUL", "INCLUDE_NAME_PLATE_ONLY", cc_neg)
    end
    AddGroup(groups, "Whitelist", base, include, nil, max_count)
    return groups
  end

  local blacklist = IsBlacklist(filter_mode) and exclude or nil

  if aura_type == "CrowdControl" then
    AddGroup(groups, "CrowdControl", JoinFilter("HARMFUL", "CROWD_CONTROL", "INCLUDE_NAME_PLATE_ONLY"), nil, blacklist, max_count)
    return groups
  end

  if aura_type == "Buffs" then
    local show_all = (is_friendly and db.ShowAllFriendly) or (not is_friendly and db.ShowAllEnemy)
    local show_npcs = (is_friendly and db.ShowOnFriendlyNPCs) or (not is_friendly and db.ShowOnEnemyNPCs)
    local show_dispellable = not is_friendly and db.ShowDispellable
    local show_mine = db.ShowOnlyMine

    if show_all or (show_npcs and is_npc) then
      AddGroup(groups, "Main", JoinFilter("HELPFUL", "INCLUDE_NAME_PLATE_ONLY"), nil, blacklist, max_count)
    else
      if show_mine then
        AddGroup(groups, "Mine", JoinFilter("HELPFUL", "PLAYER", "INCLUDE_NAME_PLATE_ONLY"), nil, blacklist, max_count)
      end
      if show_dispellable then
        AddGroup(groups, "Dispellable", JoinFilter("HELPFUL", "RAID_PLAYER_DISPELLABLE", "INCLUDE_NAME_PLATE_ONLY", show_mine and "!PLAYER" or nil), nil, blacklist, max_count)
      end
      -- Friendly buffs with no matching toggle still show nothing, matching previous behaviour.
      if not show_mine and not show_dispellable and not show_all and not (show_npcs and is_npc) then
        -- Keep empty groups so the container stays disabled.
      end
    end
    return groups
  end

  -- Debuffs
  local show_all = (is_friendly and db.ShowAllFriendly) or (not is_friendly and db.ShowAllEnemy)
  local show_mine = not is_friendly and db.ShowOnlyMine
  local show_blizzard = not is_friendly and db.ShowBlizzardForEnemy
  local show_dispellable = is_friendly and db.ShowDispellable

  if show_all then
    AddGroup(groups, "Main", JoinFilter("HARMFUL", "INCLUDE_NAME_PLATE_ONLY", cc_neg), nil, blacklist, max_count)
  else
    if show_mine then
      AddGroup(groups, "Mine", JoinFilter("HARMFUL", "PLAYER", "INCLUDE_NAME_PLATE_ONLY", cc_neg), nil, blacklist, max_count)
    end
    if show_blizzard then
      AddGroup(groups, "Important", JoinFilter("HARMFUL", "IMPORTANT", "INCLUDE_NAME_PLATE_ONLY", show_mine and "!PLAYER" or nil, cc_neg), nil, blacklist, max_count)
    end
    if show_dispellable then
      AddGroup(groups, "Dispellable", JoinFilter("HARMFUL", "RAID_PLAYER_DISPELLABLE", "INCLUDE_NAME_PLATE_ONLY", cc_neg), nil, blacklist, max_count)
    end
  end

  return groups
end

---------------------------------------------------------------------------------------------------
-- Container layout / groups
---------------------------------------------------------------------------------------------------

local function GetFlowOptions(aura_type)
  local db = Widget.db[aura_type]
  local aura_grid = Widget[aura_type]
  local grow_right = db.AlignmentH ~= "RIGHT"
  local grow_up = db.AlignmentV ~= "TOP"

  local anchor
  if grow_right then
    anchor = grow_up and "BOTTOMLEFT" or "TOPLEFT"
  else
    anchor = grow_up and "BOTTOMRIGHT" or "TOPRIGHT"
  end

  local horizontal = (FlowDirection and (grow_right and FlowDirection.Right or FlowDirection.Left)) or (grow_right and 1 or 2)
  local vertical = (FlowDirection and (grow_up and FlowDirection.Up or FlowDirection.Down)) or (grow_up and 3 or 4)

  local width = aura_grid.IconWidth or 16
  local height = aura_grid.IconHeight or 16
  local spacing_x = aura_grid.ColumnSpacing or 5
  local spacing_y = aura_grid.RowSpacing or 8
  local columns = aura_grid.Columns or 5
  local line_size = columns * width + max(columns - 1, 0) * spacing_x

  return {
    anchor = anchor,
    horizontal = horizontal,
    vertical = vertical,
    layout = {
      elementSpacing = spacing_x,
      lineSpacing = spacing_y,
      elementWidth = width,
      elementHeight = height,
    },
    lineSize = line_size,
  }
end

local function GetSortOptions()
  local method = SortMethod and SortMethod.Default
  local direction = SortDirection and SortDirection.Normal
  local order = Widget.db.SortOrder
  if SortMethod then
    if order == "TimeLeft" or order == "Duration" or order == "Creation" then
      method = SortMethod.Expiration or SortMethod.ExpirationOnly or method
    end
  end
  if Widget.db.SortReverse and SortDirection then
    direction = SortDirection.Reverse
  end
  return method, direction
end

local function EnsureGroups(container, aura_type)
  if not HAS_AURA_CONTAINER then
    return
  end

  container.Groups = container.Groups or {}
  local flow = GetFlowOptions(aura_type)
  local sort_method, sort_direction = GetSortOptions()

  for index, group_key in ipairs(GROUP_KEYS) do
    if not container.Groups[group_key] then
      local layout = {}
      for k, v in pairs(flow.layout) do
        layout[k] = v
      end
      layout.layoutIndex = index

      container:AddAuraGroup(group_key, "", {
        maxFrameCount = 0,
        sortMethod = sort_method,
        sortDirection = sort_direction,
        initializeFrame = function(button)
          InitAuraButton(button, aura_type)
        end,
        layout = layout,
      })
      container.Groups[group_key] = true
    end
  end
end

local function DisableAllGroups(container)
  if not container.Groups then
    return
  end
  for group_key in pairs(container.Groups) do
    container:SetAuraGroupFilterString(group_key, "")
    container:SetAuraGroupMaxFrameCount(group_key, 0)
  end
end

local function ApplyGroups(container, filter_type, unit, exclude_cc)
  if not HAS_AURA_CONTAINER then
    return
  end

  local layout_type = container.AuraType or filter_type
  EnsureGroups(container, layout_type)
  DisableAllGroups(container)

  local flow = GetFlowOptions(layout_type)
  container:SetFlowLayoutAnchorPoint(flow.anchor)
  container:SetFlowLayoutGrowthDirection(flow.horizontal, flow.vertical)
  container:SetFlowLayoutMaximumLineSize(flow.lineSize)

  local sort_method, sort_direction = GetSortOptions()
  local groups = BuildGroupsForType(filter_type, unit, exclude_cc)
  local enabled = #groups > 0

  for index, group in ipairs(groups) do
    if container.Groups[group.key] then
      local layout = {}
      for k, v in pairs(flow.layout) do
        layout[k] = v
      end
      layout.layoutIndex = index

      container:SetAuraGroupFilterString(group.key, group.filter)
      container:SetAuraGroupCandidateFilters(group.key, group.candidates or {})
      container:SetAuraGroupMaxFrameCount(group.key, group.maxCount)
      container:SetAuraGroupSortMethod(group.key, sort_method, sort_direction)
      container:SetAuraGroupLayout(group.key, layout)
    end
  end

  container:SetSize(1, 1)
  return enabled
end

local function CreateAuraContainer(parent, aura_type)
  if not HAS_AURA_CONTAINER then
    local frame = CreateFrame("Frame", nil, parent)
    frame:Hide()
    frame.AuraType = aura_type
    frame.AuraButtons = {}
    return frame
  end

  local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
  container:SetEnabled(false)
  container:Hide()
  container:SetSize(1, 1)
  container.AuraType = aura_type
  container.AuraButtons = {}
  EnsureGroups(container, aura_type)
  return container
end

local function RestyleContainerButtons(container, aura_type)
  if not CanRestyleButtons() then
    return
  end
  local buttons = container.AuraButtons
  if not buttons then
    return
  end
  for i = 1, #buttons do
    StyleAuraButton(buttons[i], aura_type)
  end
end

---------------------------------------------------------------------------------------------------
-- Positioning
---------------------------------------------------------------------------------------------------

function Widget:UpdatePositionAuraGrid(widget_frame, aura_type, unit_style)
  local db = self.db[aura_type]
  local container = widget_frame[aura_type]
  local anchor_to_db = db.AnchorTo
  local anchor_to = (anchor_to_db == "Healthbar" and widget_frame) or widget_frame[anchor_to_db]

  AnchorFrameTo(db[MODE_FOR_STYLE[unit_style]], container, anchor_to)
end

---------------------------------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------------------------------

local function ShouldHideForUnit(widget_frame, unit)
  local unit_is_target = UnitIsUnitTP("target", unit.unitid)
  if Widget.db.ShowTargetOnly then
    if unit_is_target then
      Widget.CurrentTarget = widget_frame
    else
      return true
    end
  end

  if not EnabledForStyle[unit.style] then
    return true
  end

  return false
end

function Widget:UpdateAuras(widget_frame, unit)
  if not widget_frame or not unit or not unit.unitid then
    return
  end

  AuraTriggerInitialize(unit)

  if ShouldHideForUnit(widget_frame, unit) then
    if widget_frame.Buffs.SetEnabled then widget_frame.Buffs:SetEnabled(false) end
    if widget_frame.Debuffs.SetEnabled then widget_frame.Debuffs:SetEnabled(false) end
    if widget_frame.CrowdControl.SetEnabled then widget_frame.CrowdControl:SetEnabled(false) end
    widget_frame:Hide()
    AuraTriggerUpdateStyle(unit)
    return
  end

  local db = self.db
  local is_friendly = unit.reaction == "FRIENDLY"
  local enabled_cc = is_friendly and db.CrowdControl.ShowFriendly or db.CrowdControl.ShowEnemy

  local buff_container = widget_frame.Buffs
  local debuff_container = widget_frame.Debuffs
  if db.SwitchAreaByReaction and is_friendly then
    buff_container = widget_frame.Debuffs
    debuff_container = widget_frame.Buffs
  end

  local buffs_on = ApplyGroups(buff_container, "Buffs", unit, false)
  local debuffs_on = ApplyGroups(debuff_container, "Debuffs", unit, enabled_cc)
  local cc_on = enabled_cc and ApplyGroups(widget_frame.CrowdControl, "CrowdControl", unit, false) or false
  if not enabled_cc then
    DisableAllGroups(widget_frame.CrowdControl)
  end

  if buff_container.SetUnit then
    buff_container:SetUnit(unit.unitid)
    buff_container:SetEnabled(buffs_on and true or false)
  end
  if debuff_container.SetUnit then
    debuff_container:SetUnit(unit.unitid)
    debuff_container:SetEnabled(debuffs_on and true or false)
  end
  if widget_frame.CrowdControl.SetUnit then
    widget_frame.CrowdControl:SetUnit(unit.unitid)
    widget_frame.CrowdControl:SetEnabled(cc_on and true or false)
  end

  self:UpdatePositionAuraGrid(widget_frame, "Buffs", unit.style)
  self:UpdatePositionAuraGrid(widget_frame, "Debuffs", unit.style)
  self:UpdatePositionAuraGrid(widget_frame, "CrowdControl", unit.style)

  if buffs_on then buff_container:Show() else buff_container:Hide() end
  if debuffs_on then debuff_container:Show() else debuff_container:Hide() end
  if cc_on then widget_frame.CrowdControl:Show() else widget_frame.CrowdControl:Hide() end

  widget_frame:Show()
  AuraTriggerUpdateStyle(unit)
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:UpdateLayout(widget_frame)
  local frame_level
  if self.db.FrameOrder == "HEALTHBAR_AURAS" then
    frame_level = widget_frame:GetParent():GetFrameLevel() + 1
  else
    frame_level = widget_frame:GetParent():GetFrameLevel() + 9
  end
  widget_frame:SetFrameLevel(frame_level)

  widget_frame.Buffs:ClearAllPoints()
  widget_frame.Debuffs:ClearAllPoints()
  widget_frame.CrowdControl:ClearAllPoints()

  widget_frame.Buffs:SetFrameLevel(frame_level)
  widget_frame.Debuffs:SetFrameLevel(frame_level)
  widget_frame.CrowdControl:SetFrameLevel(frame_level)

  RestyleContainerButtons(widget_frame.Buffs, "Buffs")
  RestyleContainerButtons(widget_frame.Debuffs, "Debuffs")
  RestyleContainerButtons(widget_frame.CrowdControl, "CrowdControl")
end

function Widget:Create(tp_frame)
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()
  widget_frame:SetAllPoints(tp_frame)
  widget_frame.Widget = self

  widget_frame.Buffs = CreateAuraContainer(widget_frame, "Buffs")
  widget_frame.Debuffs = CreateAuraContainer(widget_frame, "Debuffs")
  widget_frame.CrowdControl = CreateAuraContainer(widget_frame, "CrowdControl")

  self:UpdateLayout(widget_frame)
  return widget_frame
end

function Widget:IsEnabled()
  self.db = Addon.db.profile.AuraWidget
  return self.db.ON or self.db.ShowInHeadlineView
end

function Widget:OnEnable()
  self:SubscribeEvent("PLAYER_TARGET_CHANGED")
end

function Widget:EnabledForStyle(style, unit)
  if style == "NameOnly" or style == "NameOnly-Unique" then
    return self.db.ShowInHeadlineView or Addon.ActiveAuraTriggers
  elseif style ~= "etotem" then
    return self.db.ON or Addon.ActiveAuraTriggers
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  self:UpdateAuras(widget_frame, unit)
end

function Widget:OnUnitRemoved(widget_frame, unit)
  if widget_frame.Buffs.SetEnabled then
    widget_frame.Buffs:SetEnabled(false)
    widget_frame.Debuffs:SetEnabled(false)
    widget_frame.CrowdControl:SetEnabled(false)
  end
  widget_frame:Hide()
end

function Widget:PLAYER_TARGET_CHANGED()
  if not self.db.ShowTargetOnly then
    return
  end

  if self.CurrentTarget then
    self.CurrentTarget:Hide()
    if self.CurrentTarget.Buffs.SetEnabled then
      self.CurrentTarget.Buffs:SetEnabled(false)
      self.CurrentTarget.Debuffs:SetEnabled(false)
      self.CurrentTarget.CrowdControl:SetEnabled(false)
    end
    self.CurrentTarget = nil
  end

  local tp_frame = Addon:GetThreatPlateForTarget()
  if tp_frame then
    self.CurrentTarget = tp_frame.widgets.Auras
    if self.CurrentTarget and self.CurrentTarget.Active then
      self:UpdateAuras(self.CurrentTarget, tp_frame.unit)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------------------------------

local function ParseFilter(filter_by_spell)
  local include, exclude = {}, {}
  if type(filter_by_spell) ~= "table" then
    return include, exclude
  end

  for _, value in pairs(filter_by_spell) do
    if type(value) == "string" then
      local pos = value:find("%-%-")
      if pos then
        value = value:sub(1, pos - 1)
      end
      value = value:match("^%s*(.-)%s*$")

      local modifier, spell
      if value:sub(1, 4) == "All " then
        modifier = "All"
        spell = value:match("^All%s*(.-)$")
      elseif value:sub(1, 3) == "My " then
        modifier = "My"
        spell = value:match("^My%s*(.-)$")
      elseif value:sub(1, 4) == "Not " then
        modifier = "Not"
        spell = value:match("^Not%s*(.-)$")
      else
        modifier = true
        spell = value
      end

      local spell_id = GetSpellIDFromIdentifier(spell)
      if spell_id then
        if modifier == "Not" then
          -- "Not" entries are ignore-rules for blacklist semantics; skip for include lists.
        else
          include[spell_id] = true
          exclude[spell_id] = true
        end
      end
    end
  end

  return include, exclude
end

function Widget:ParseSpellFilters()
  self.db = Addon.db.profile.AuraWidget
  local buff_include, buff_exclude = ParseFilter(self.db.Buffs.FilterBySpell)
  local debuff_include, debuff_exclude = ParseFilter(self.db.Debuffs.FilterBySpell)
  local cc_include, cc_exclude = ParseFilter(self.db.CrowdControl.FilterBySpell)

  AuraFilterSpellIDs.Buffs.include, AuraFilterSpellIDs.Buffs.exclude = buff_include, buff_exclude
  AuraFilterSpellIDs.Debuffs.include, AuraFilterSpellIDs.Debuffs.exclude = debuff_include, debuff_exclude
  AuraFilterSpellIDs.CrowdControl.include, AuraFilterSpellIDs.CrowdControl.exclude = cc_include, cc_exclude
end

function Widget:UpdateSettingsIconMode(aura_type)
  local aura_grid = self[aura_type]
  local db = self.db[aura_type].ModeIcon
  aura_grid.db = db
  aura_grid.db_widget = self.db
  aura_grid.IconMode = true
  aura_grid.Columns = db.Columns
  aura_grid.MaxAuras = min(db.MaxAuras, db.Rows * db.Columns)
  aura_grid.IconWidth = db.IconWidth
  aura_grid.IconHeight = db.IconHeight
  aura_grid.ColumnSpacing = db.ColumnSpacing
  aura_grid.RowSpacing = db.RowSpacing
end

function Widget:UpdateSettingsBarMode(aura_type)
  local aura_grid = self[aura_type]
  local db = self.db[aura_type].ModeBar
  aura_grid.db = db
  aura_grid.db_widget = self.db
  -- Bar mode cannot show aura names while auras are secret. Use stacked icons instead.
  aura_grid.IconMode = false
  aura_grid.Columns = 1
  aura_grid.MaxAuras = db.MaxBars
  aura_grid.IconWidth = db.ShowIcon and db.BarHeight or db.BarWidth
  aura_grid.IconHeight = db.BarHeight
  aura_grid.ColumnSpacing = 0
  aura_grid.RowSpacing = db.BarSpacing
end

function Widget:UpdateSettings()
  self.db = Addon.db.profile.AuraWidget

  self.Buffs.IconMode = not self.db.Buffs.ModeBar.Enabled
  self.Debuffs.IconMode = not self.db.Debuffs.ModeBar.Enabled
  self.CrowdControl.IconMode = not self.db.CrowdControl.ModeBar.Enabled

  if self.Buffs.IconMode then
    self:UpdateSettingsIconMode("Buffs")
  else
    self:UpdateSettingsBarMode("Buffs")
  end
  if self.Debuffs.IconMode then
    self:UpdateSettingsIconMode("Debuffs")
  else
    self:UpdateSettingsBarMode("Debuffs")
  end
  if self.CrowdControl.IconMode then
    self:UpdateSettingsIconMode("CrowdControl")
  else
    self:UpdateSettingsBarMode("CrowdControl")
  end

  self:ParseSpellFilters()

  HideOmniCC = not self.db.ShowOmniCC
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
-- Configuration / debug
---------------------------------------------------------------------------------------------------

function Widget:ToggleConfigurationMode()
  Addon.Logging.Warning("Aura configuration preview is not available in Midnight 12.1 because aura data is secret.")
end

function Widget:PrintDebug(command)
  Addon.Logging.Debug("Auras widget is using Blizzard AuraContainer (12.1). GetAuraSlots is no longer called.")
  if command == "enable" then
    Addon.Logging.Debug("    Buff whitelist/blacklist IDs:", AuraFilterSpellIDs.Buffs.include and "set" or "none")
  end
end
