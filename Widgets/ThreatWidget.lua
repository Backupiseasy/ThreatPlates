---------------------------------------------------------------------------------------------------
-- Threat Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewWidget("Threat")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local UnitIsUnit = UnitIsUnit
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetRaidTargetIndex = GetRaidTargetIndex

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local GetThreatSituation = Addon.GetThreatSituation
local LibThreatClassic = Addon.LibThreatClassic
local PlatesByGUID = Addon.PlatesByGUID

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

local function UNIT_THREAT_LIST_UPDATE_CLASSIC(lib_name, unit_guid, target_guid, threat)
  local plate = PlatesByGUID[target_guid]
  if plate then
    local unitid = plate.TPFrame.unit.unitid
    if not unitid or unitid == "player" or UnitIsUnit("player", unitid) then return end

    if plate.TPFrame.Active then
      local widget_frame = plate.TPFrame.widgets.Threat
      if widget_frame.Active then
        Widget:UpdateFrame(widget_frame, plate.TPFrame.unit)
      end
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
  widget_frame.LeftTexture = widget_frame:CreateTexture(nil, "OVERLAY", 6)
  widget_frame.RightTexture = widget_frame:CreateTexture(nil, "OVERLAY", 6)
  widget_frame.RightTexture:SetPoint("LEFT", tp_frame.visual.healthbar, "RIGHT", 4, 0)
  widget_frame.RightTexture:SetSize(64, 64)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  return TidyPlatesThreat.db.profile.threat.art.ON
end

function Widget:OnEnable()
  if Addon.CLASSIC then
    LibThreatClassic.RegisterCallback(TidyPlatesThreat, "ThreatUpdated", UNIT_THREAT_LIST_UPDATE_CLASSIC)
  else
    self:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
  end
  self:RegisterEvent("RAID_TARGET_UPDATE")
end

function Widget:OnDisable()
  if Addon.CLASSIC then
    LibThreatClassic.UnregisterCallback(TidyPlatesThreat, "ThreatUpdated")
  else
    self:UnregisterEvent("UNIT_THREAT_LIST_UPDATE")
  end
  self:UnregisterEvent("RAID_TARGET_UPDATE")
end


function Widget:EnabledForStyle(style, unit)
  return not (unit.type == "PLAYER" or style == "NameOnly" or style == "NameOnly-Unique" or style == "etotem")
end

function Widget:OnUnitAdded(widget_frame, unit)
  local db = TidyPlatesThreat.db.profile.threat.art

  if db.theme == "bar" then
    widget_frame.LeftTexture:ClearAllPoints(widget_frame)
    widget_frame.LeftTexture:SetSize(265, 64)
    widget_frame.LeftTexture:SetPoint("CENTER", widget_frame:GetParent(), "CENTER")
    widget_frame.LeftTexture:SetTexCoord(0, 1, 0, 1)

    widget_frame.RightTexture:Hide()
  else
    widget_frame.LeftTexture:ClearAllPoints(widget_frame)
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

  if GetRaidTargetIndex(unit.unitid) and db.marked.art then
    widget_frame:Hide()
    return
  end

  if not Addon:ShowThreatFeedback(unit) then
    widget_frame:Hide()
    return
  end

  local unique_setting = unit.CustomPlateSettings
  if not unique_setting or not unique_setting.UseThreatColor then
    widget_frame:Hide()
    return
  end

  local style = (Addon:PlayerRoleIsTank() and "tank") or "dps"

  local threat_situation = GetThreatSituation(unit, style, db.toggle.OffTank)
  if style ~= "tank" then
    -- Tanking uses regular textures / swapped for dps / healing
    threat_situation = REVERSE_THREAT_SITUATION[threat_situation]
  end

  if db.art.theme == "bar" then
    widget_frame.LeftTexture:SetTexture(PATH .. db.art.theme.."\\".. threat_situation)
  else
    widget_frame.LeftTexture:SetTexture(PATH .. db.art.theme.."\\".. threat_situation)
    widget_frame.RightTexture:SetTexture(PATH .. db.art.theme.."\\".. threat_situation)
  end

  widget_frame:Show()
end

-- Load settings from the configuration which are shared across all aura widgets
-- used (for each widget) in UpdateWidgetConfig
--function Widget:UpdateSettings()
--  self.db = TidyPlatesThreat.db.profile.Threat
--
--  for _, tp_frame in pairs(Addon.PlatesCreated) do
--    local widget_frame = tp_frame.widgets.UniqueIcon
--
--    -- widget_frame could be nil if the widget as disabled and is enabled as part of a profile switch
--    -- For these frames, UpdateAuraWidgetLayout will be called anyway when the widget is initalized
--    -- (which happens after the settings update)
--    if widget_frame and tp_frame.Active then
--      -- Update the style as custom nameplates might have been changed and some units no longer
--      -- may be unique
--      Addon:SetStyle(widget_frame.unit)
--      self:OnUnitAdded(widget_frame, widget_frame.unit)
--    end
--  end
--end