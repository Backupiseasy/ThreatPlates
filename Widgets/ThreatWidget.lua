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
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetRaidTargetIndex = GetRaidTargetIndex
local IsInRaid, GetNumGroupMembers, GetNumSubgroupMembers = IsInRaid, GetNumGroupMembers, GetNumSubgroupMembers

-- ThreatPlates APIs
local GetThreatSituation = Addon.GetThreatSituation
local Font = Addon.Font

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ThreatWidget\\"
local THREAT_REFERENCE = {
  [0] = "LOW",
  [1] = "MEDIUM",
  [2] = "MEDIUM",
  [3] = "HIGH",
}
local REVERSE_THREAT_SITUATION = {
  HIGH = "LOW",
  MEDIUM ="MEDIUM",
  LOW = "HIGH",
}

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local Settings, SettingsArt, ThreatColors

---------------------------------------------------------------------------------------------------
-- Event handling stuff
---------------------------------------------------------------------------------------------------

function Widget:UNIT_THREAT_LIST_UPDATE(unitid)
  if not unitid or unitid == "player" or UnitIsUnit("player", unitid) then return end

  local plate = GetNamePlateForUnit(unitid)
  if plate and plate.TPFrame.Active then
    local widget_frame = plate.TPFrame.widgets.Threat
    if widget_frame.Active then
      self:UpdateFrame(widget_frame, plate.TPFrame.unit)
    end
  end
end

function Widget:RAID_TARGET_UPDATE()
  self:UpdateAllFrames()
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
  widget_frame.RightTexture:SetPoint("LEFT", tp_frame.visual.healthbar, "RIGHT", 4, 0)
  widget_frame.RightTexture:SetSize(64, 64)

  widget_frame.Percentage = widget_frame:CreateFontString(nil, "OVERLAY")
  widget_frame.Percentage:SetFont("Fonts\\FRIZQT__.TTF", 11)

  self:UpdateLayout(widget_frame)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  return Addon.db.profile.threat.art.ON or Addon.db.profile.threatWidget.ThreatPercentage.Show
end

function Widget:OnEnable()
  self:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
  self:RegisterEvent("RAID_TARGET_UPDATE")
end

function Widget:OnDisable()
  self:UnregisterEvent("UNIT_THREAT_LIST_UPDATE")
  self:UnregisterEvent("RAID_TARGET_UPDATE")
end


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
    widget_frame.LeftTexture:SetPoint("RIGHT", widget_frame:GetParent().visual.healthbar, "LEFT", -4, 0)
    widget_frame.LeftTexture:SetTexCoord(0, 0.25, 0, 1)

    widget_frame.RightTexture:SetTexCoord(0.75, 1, 0, 1)
    widget_frame.RightTexture:Show()
  end

  self:UpdateFrame(widget_frame, unit)
end

local function GetDetailedThreatPercentage(unitid)
  local is_tanking, status, scaled_percentage, _, threat_value = UnitDetailedThreatSituation("player", unitid)
  if status == nil then return nil, nil end

  local threat_diff = 0
  print("Tanking:", is_tanking)
  if is_tanking then
    -- Determine threat diff by finding the next highest raid/party member threat
    local group_type = IsInRaid() and "raid" or "party"
    local num_group_members = (group_type == "raid" and GetNumGroupMembers()) or GetNumSubgroupMembers()
    
    local top_other_threat
    local index_str, scaled_percentage_other, _
    for i = 1, num_group_members do
      index_str = tostring(i)
      _, _, scaled_percentage_other, _, _ = UnitDetailedThreatSituation(group_type .. index_str, unitid)
      if scaled_percentage_other and scaled_percentage_other > top_other_threat then
        top_other_threat = scaled_percentage_other
      end

      _, _, scaled_percentage_other, _, _ = UnitDetailedThreatSituation(group_type .."pet" .. index_str, unitid)
      if scaled_percentage_other and scaled_percentage_other > top_other_threat then
        top_other_threat = scaled_percentage_other
      end
    end

    if top_other_threat then
      threat_diff = scaled_percentage - top_other_threat
    end
  else
    -- Determine raw threat deficit by scaled % of target threat
    if threat_value == 0 or scaled_percentage == 0 then
      threat_diff = 0
    else
      threat_diff = scaled_percentage
    end
  end

  -- Show threat delta if non-zero
  local percentage_text = string_format("%.0f%%", threat_diff)
  if threat_diff > 0 then
    percentage_text = "+" .. percentage_text
  end

  return status, percentage_text
end

local function GetDetailedThreatValue(unitid)
  local is_tanking, status, scaled_percentage, _, threat_value = UnitDetailedThreatSituation("player", unitid)
  if status == nil then return nil, nil end

  local threat_diff = 0
  if is_tanking then
    -- Determine threat diff by finding the next highest raid/party member threat
    local group_type = IsInRaid() and "raid" or "party"
    local num_group_members = (group_type == "raid" and GetNumGroupMembers()) or GetNumSubgroupMembers()
    
    local top_other_threat
    local index_str, threat_value_other, _
    for i = 1, num_group_members do
      index_str = tostring(i)
      _, _, _, _, threat_value_other = UnitDetailedThreatSituation(group_type .. index_str, unitid)
      if threat_value_other and threat_value_other > top_other_threat then
        top_other_threat = threat_value_other
      end

      _, _, _, _, threat_value_other = UnitDetailedThreatSituation(group_type .."pet" .. index_str, unitid)
      if threat_value_other and threat_value_other > top_other_threat then
        top_other_threat = threat_value_other
      end
    end

    if top_other_threat then
      threat_diff = threat_value - top_other_threat
    end
  else
    -- Determine raw threat deficit by scaled <% of target threat
    if threat_value == 0 or scaled_percentage == 0 then
      threat_diff = 0
    else
      threat_diff = threat_value - threat_value / (scaled_percentage / 100)
    end
  end

  -- Show threat delta if non-zero
  local percentage_text = Addon.Truncate(threat_diff)
  if threat_diff > 0 then
    percentage_text = "+" .. percentage_text
  end

  return status, percentage_text
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

  local width, height = widget_frame:GetSize()
  widget_frame.Percentage:SetSize(width, height)

  -- As the widget is enabled, textures or percentages must be enabled.
  local style = (Addon:PlayerRoleIsTank() and "tank") or "dps"
  local threat_situation = GetThreatSituation(unit, style, db.toggle.OffTank)

  -- Show threat art (textures)
  if SettingsArt.ON and not (GetRaidTargetIndex(unit.unitid) and db.marked.art) then
    local texture = PATH
    if style ~= "tank" then
      -- Tanking uses regular textures / swapped for dps / healing
      texture = texture .. db.art.theme.."\\".. REVERSE_THREAT_SITUATION[threat_situation]
    else
      texture = texture .. db.art.theme.."\\".. threat_situation
    end

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

  local db_threat_situation = Settings.ThreatPercentage
  if db_threat_situation.Show then
    local status, percentage_text = THREAT_DETAILS_FUNTIONS[db_threat_situation.Type](unit.unitid)
    if status ~= nil then
      widget_frame.Percentage:SetText(percentage_text)

      local color
      if Settings.ThreatPercentage.UseThreatColor then
        color = ThreatColors[style].threatcolor[threat_situation]
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
  Settings = Addon.db.profile.threatWidget
  SettingsArt = Addon.db.profile.threat.art
  ThreatColors = Addon.db.profile.settings
end