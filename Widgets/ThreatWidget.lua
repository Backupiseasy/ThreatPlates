---------------------------------------------------------------------------------------------------
-- Threat Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewWidget("Threat")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local tostring = tostring
local string_format = string.format

-- WoW APIs
local UnitIsUnit, UnitDetailedThreatSituation = UnitIsUnit, UnitDetailedThreatSituation
local GetRaidTargetIndex = GetRaidTargetIndex
local IsInGroup, IsInRaid, GetNumGroupMembers, GetNumSubgroupMembers = IsInGroup, IsInRaid, GetNumGroupMembers, GetNumSubgroupMembers

-- ThreatPlates APIs
local GetThreatLevel = Addon.GetThreatLevel
local Font = Addon.Font

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ThreatWidget\\"
local REVERSE_THREAT_SITUATION = {
  HIGH = "LOW",
  MEDIUM ="MEDIUM",
  LOW = "HIGH",
}

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local Settings, SettingsArt, ThreatColors, ThreatDetailsFunction

---------------------------------------------------------------------------------------------------
-- Event handling stuff
---------------------------------------------------------------------------------------------------

function Widget:ThreatUpdate(tp_frame)
  local widget_frame = tp_frame.widgets.Threat
  if widget_frame.Active then
    self:UpdateFrame(widget_frame, tp_frame.unit)
  end
end

function Widget:TargetMarkerUpdate(tp_frame)
  local widget_frame = tp_frame.widgets.Threat
  if widget_frame.Active then
    self:UpdateFrame(widget_frame, tp_frame.unit)
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
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
  widget_frame.LeftTexture = widget_frame:CreateTexture(nil, "ARTWORK")
  widget_frame.RightTexture = widget_frame:CreateTexture(nil, "ARTWORK")
  widget_frame.RightTexture:SetPoint("LEFT", tp_frame.visual.Healthbar, "RIGHT", 4, 0)
  widget_frame.RightTexture:SetSize(64, 64)

  widget_frame.Percentage = widget_frame:CreateFontString(nil, "OVERLAY")
  widget_frame.Percentage:SetFont("Fonts\\FRIZQT__.TTF", 11)

  self:UpdateLayout(widget_frame)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  local db = Addon.db.profile.threat
  return db.art.ON or db.ThreatPercentage.Show
end

function Widget:OnEnable()
  self:SubscribeEvent("ThreatUpdate")
  self:SubscribeEvent("TargetMarkerUpdate")
end

-- function Widget:OnDisable()
--   self:UnsubscribeAllEvents()
-- end

function Widget:EnabledForStyle(style, unit)
  return not (unit.type == "PLAYER" or style == "NameOnly" or style == "NameOnly-Unique" or style == "etotem")
end

function Widget:OnUnitAdded(widget_frame, unit)
  local db = Addon.db.profile.threat.art

  if db.theme == "bar" then
    widget_frame.LeftTexture:ClearAllPoints()
    widget_frame.LeftTexture:SetSize(265, 64)
    widget_frame.LeftTexture:SetPoint("CENTER", widget_frame:GetParent(), "CENTER")
    widget_frame.LeftTexture:SetTexCoord(0, 1, 0, 1)

    widget_frame.RightTexture:Hide()
  else
    widget_frame.LeftTexture:ClearAllPoints()
    widget_frame.LeftTexture:SetSize(64, 64)
    widget_frame.LeftTexture:SetPoint("RIGHT", widget_frame:GetParent().visual.Healthbar, "LEFT", -4, 0)
    widget_frame.LeftTexture:SetTexCoord(0, 0.25, 0, 1)

    widget_frame.RightTexture:SetTexCoord(0.75, 1, 0, 1)
    widget_frame.RightTexture:Show()
  end

  self:UpdateFrame(widget_frame, unit)
end

local function GetDetailedThreatPercentage(unitid, db_threat_value)
  local is_tanking, status, scaled_percentage, _, _ = UnitDetailedThreatSituation("player", unitid)
  if status == nil then return nil, nil end

  local threat_value_text = ""
  local second_unit_threat_diff = 0
  if is_tanking then
    -- Determine threat diff by finding the next highest raid/party member threat
    
    --local group_size = (IsInRaid() and GetNumGroupMembers()) or (IsInGroup() and GetNumSubgroupMembers()) or 0
    local group_type = (IsInRaid() and "raid") or "party"
    local num_group_members = (group_type == "raid" and GetNumGroupMembers()) or GetNumSubgroupMembers()

    local second_unit_by_threat
    local second_unit_threat_percentage = 0
    for i = 1, num_group_members do
      local index_str = tostring(i)
      local group_unit_id = group_type .. index_str

      local _, _, group_unit_threat_percentage, _, _ = UnitDetailedThreatSituation(group_unit_id, unitid)
      if group_unit_threat_percentage and group_unit_threat_percentage > second_unit_threat_percentage then
        second_unit_threat_percentage = group_unit_threat_percentage
        second_unit_by_threat = group_unit_id
      end

      group_unit_id = group_type .."pet" .. index_str
      _, _, group_unit_threat_percentage, _, _ = UnitDetailedThreatSituation(group_unit_id, unitid)
      if group_unit_threat_percentage and group_unit_threat_percentage > second_unit_threat_percentage then
        second_unit_threat_percentage = group_unit_threat_percentage
        second_unit_by_threat = group_unit_id
      end
    end

    if second_unit_by_threat then
      -- threat diff should be negative, when player is tanking: -1 * (scaled_percentage - second_unit_threat_percentage)
      second_unit_threat_diff = second_unit_threat_percentage - scaled_percentage
      if db_threat_value.SecondPlayersName then
        threat_value_text = UnitName(second_unit_by_threat) .. ": "
      end
    end
  else
    second_unit_threat_diff = scaled_percentage or 0
  end

  -- Show threat delta if non-zero
  if second_unit_threat_diff > 0 then
    threat_value_text = threat_value_text .. "+"
  end
  threat_value_text = threat_value_text .. string_format("%.0f%%", second_unit_threat_diff)

  return status, threat_value_text
end

local function GetDetailedThreatValue(unitid, db_threat_value)
  local is_tanking, status, scaled_percentage, _, threat_value = UnitDetailedThreatSituation("player", unitid)
  if status == nil then return nil, nil end

  local threat_value_text = ""
  local second_unit_threat_diff = 0
  if is_tanking then
    -- Determine threat diff by finding the next highest raid/party member threat
    local group_type = (IsInRaid() and "raid") or "party"
    local num_group_members = (group_type == "raid" and GetNumGroupMembers()) or GetNumSubgroupMembers()

    local second_unit_by_threat
    local second_unit_threat_value = 0
    for i = 1, num_group_members do   
      local index_str = tostring(i)
      local group_unit_id = group_type .. index_str
      
      -- Only compare player's threat values to other group memebers, not to the player itself (in raid with GetNumGroupMembers)
      if not UnitIsUnit("player", group_unit_id) then
        local _, _, _, _, group_unit_threat_value = UnitDetailedThreatSituation(group_unit_id, unitid)
        if group_unit_threat_value and group_unit_threat_value > second_unit_threat_value then
          second_unit_threat_value = group_unit_threat_value
          second_unit_by_threat = group_unit_id
        end
      end

      group_unit_id = group_type .."pet" .. index_str
      _, _, _, _, group_unit_threat_value = UnitDetailedThreatSituation(group_unit_id, unitid)
      if group_unit_threat_value and group_unit_threat_value > second_unit_threat_value then
        second_unit_threat_value = group_unit_threat_value
        second_unit_by_threat = group_unit_id
      end
    end

    if second_unit_by_threat then
      -- threat diff should be negative, when player is tanking: -1 * (threat_value - second_unit_threat_value)
      second_unit_threat_diff = second_unit_threat_value - threat_value
      if db_threat_value.SecondPlayersName then
        threat_value_text = UnitName(second_unit_by_threat) .. ": "
      end
    end
  else
    -- Determine raw threat deficit by scaled <% of target threat
    if second_unit_threat_diff ~= 0 and scaled_percentage ~= 0 then
      second_unit_threat_diff = second_unit_threat_diff - second_unit_threat_diff / (scaled_percentage / 100)
    end
  end

  -- Show threat delta if non-zero
  if second_unit_threat_diff > 0 then
    threat_value_text = threat_value_text .. "+"
  end
  threat_value_text = threat_value_text .. Addon.Truncate(second_unit_threat_diff)

  return status, threat_value_text
end

local THREAT_DETAILS_FUNTIONS = {
  SCALED_PERCENTAGE = function(unitid)
    local _, status, scaled_percentage, _, _ = UnitDetailedThreatSituation("player", unitid)
    return status, string_format("%.0f%%", scaled_percentage)
  end,
  RAW_PERCENTAGE = function(unitid)
    local _, status, _, raw_percentage, _ = UnitDetailedThreatSituation("player", unitid)
    return status, string_format("%.0f%%", raw_percentage)
  end,
  DETAILED_PERCENTAGE = GetDetailedThreatPercentage,
  DETAILED_VALUE = GetDetailedThreatValue,
}

function Widget:UpdateFrame(widget_frame, unit)
  local db = Addon.db.profile.threat

  if not Addon:ShowThreatFeedback(unit) then
    widget_frame:Hide()
    return
  end

  -- unique_setting.useStyle is already checked when setting the style of the nameplate (to custom)
  local unique_setting = unit.CustomPlateSettings
  if unique_setting and not unique_setting.UseThreatColor then
    widget_frame:Hide()
    return
  end

  widget_frame.Percentage:SetHeight(widget_frame:GetHeight())

  local style = Addon.GetPlayerRole()
  local threat_level = GetThreatLevel(unit, style, db.toggle.OffTank)

  -- Show threat art (textures)
  if SettingsArt.ON and not (GetRaidTargetIndex(unit.unitid) and db.marked.art) then
    if style ~= "tank" then
      -- Tanking uses regular textures / swapped for dps / healing
      threat_level = REVERSE_THREAT_SITUATION[threat_level]
    end

    local texture = PATH .. db.art.theme.."\\".. threat_level
    if db.art.theme == "bar" then
      widget_frame.LeftTexture:SetTexture(texture)
      widget_frame.LeftTexture:Show()
    else
      widget_frame.LeftTexture:SetTexture(texture)
      widget_frame.RightTexture:SetTexture(texture)
      widget_frame.LeftTexture:Show()
      widget_frame.RightTexture:Show()
    end
  else
    widget_frame.LeftTexture:Hide()
    widget_frame.RightTexture:Hide()
  end

  local db_threat_value = Settings.ThreatPercentage
  if db_threat_value.Show and (not db_threat_value.OnlyInGroups or IsInGroup()) then
    local status, percentage_text = ThreatDetailsFunction(unit.unitid, db_threat_value)
    if status ~= nil then
      widget_frame.Percentage:SetText(percentage_text)
  
      local color
      if Settings.ThreatPercentage.UseThreatColor then
        color = ThreatColors[style].threatcolor[threat_level]
      else
        color = Settings.ThreatPercentage.CustomColor
      end
      widget_frame.Percentage:SetTextColor(color.r, color.g, color.b)

      widget_frame.Percentage:Show()
    else
      widget_frame.Percentage:Hide()
    end
  else
    widget_frame.Percentage:Hide()
  end

  widget_frame:Show()
end

function Widget:UpdateLayout(widget_frame)
  -- widget_frame:ClearAllPoints()
  widget_frame:SetAllPoints(widget_frame:GetParent())

  Font:UpdateText(widget_frame, widget_frame.Percentage, Settings.ThreatPercentage)
end

function Widget:UpdateSettings()
  Settings = Addon.db.profile.threat
  SettingsArt = Settings.art
  ThreatColors = Addon.db.profile.settings

  ThreatDetailsFunction = THREAT_DETAILS_FUNTIONS[Settings.ThreatPercentage.Type]
end