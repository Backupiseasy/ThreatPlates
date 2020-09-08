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

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local GetThreatSituation = Addon.GetThreatSituation
local PlatesByGUID = Addon.PlatesByGUID
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
  return TidyPlatesThreat.db.profile.threat.art.ON or TidyPlatesThreat.db.profile.threatWidget.ThreatPercentage.Show
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
  local db = TidyPlatesThreat.db.profile.threat.art

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

function Widget:UpdateFrame(widget_frame, unit)
  local db = TidyPlatesThreat.db.profile.threat

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

  if Settings.ThreatPercentage.Show then
    local _, _, scaledPercentage, _, _ = UnitDetailedThreatSituation("player", unit.unitid)
    if scaledPercentage then
      widget_frame.Percentage:SetText(string_format("%.0f%%", scaledPercentage))

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
  local width, height = widget_frame:GetSize()
  widget_frame.Percentage:SetSize(width, height)
end

function Widget:UpdateSettings()
  Settings = TidyPlatesThreat.db.profile.threatWidget
  SettingsArt = TidyPlatesThreat.db.profile.threat.art
  ThreatColors = TidyPlatesThreat.db.profile.settings
end