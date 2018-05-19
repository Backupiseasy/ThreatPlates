---------------------------------------------------------------------------------------------------
-- Threat Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Module = Addon:NewModule("Threat")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame
local UnitIsUnit, UnitThreatSituation = UnitIsUnit, UnitThreatSituation
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetRaidTargetIndex = GetRaidTargetIndex

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local UnitIsOffTanked = ThreatPlates.UnitIsOffTanked
local ShowThreatFeedback = ThreatPlates.ShowThreatFeedback
local GetUniqueNameplateSetting = ThreatPlates.GetUniqueNameplateSetting


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

function Module:UNIT_THREAT_LIST_UPDATE(unitid)
  if not unitid or unitid == 'player' or UnitIsUnit('player', unitid) then return end

  local plate = GetNamePlateForUnit(unitid)
  if plate then
    self:UpdateFrame(plate.TPFrame.widgets["Threat"], plate.TPFrame.unit)
  end
end

function Module:RAID_TARGET_UPDATE(...)
  self:UpdateAllFrames()
end

---------------------------------------------------------------------------------------------------
-- Module functions for creation and update
---------------------------------------------------------------------------------------------------

function Module:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
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

function Module:IsEnabled()
  return TidyPlatesThreat.db.profile.threat.art.ON
end

function Module:OnEnable()
  Module:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
  Module:RegisterEvent("RAID_TARGET_UPDATE")
end

function Module:EnabledForStyle(style, unit)
  return unit.type == "NPC" and not (style == "NameOnly" or style == "NameOnly-Unique" or style == "etotem")
end

function Module:OnUnitAdded(widget_frame, unit)
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

function Module:UpdateFrame(widget_frame, unit)
  local db = TidyPlatesThreat.db.profile.threat

  if GetRaidTargetIndex(unit.unitid) and db.marked.art then
    widget_frame:Hide()
    return
  end

  local style = unit.TP_Style

  if style == "unique" then
    local unique_setting = GetUniqueNameplateSetting(unit)
    if unique_setting.UseThreatColor then
      -- set style to tank/dps or normal
      style = ThreatPlates.GetThreatStyle(unit)
    end
  end

  -- Check for InCombatLockdown() and unit.type == "NPC" and unit.reaction ~= "FRIENDLY" not necessary
  -- for dps/tank as these styles automatically require that

  if not ((style  == "dps" or style == "tank") and ShowThreatFeedback(unit)) then
    widget_frame:Hide()
    return
  end

  unit.threatValue = UnitThreatSituation("player", unit.unitid) or 0
  unit.threatSituation = THREAT_REFERENCE[unit.threatValue]

  local threatLevel = "MEDIUM"
  if style == "tank" then -- Tanking uses regular textures / swapped for dps / healing
    if db.toggle.OffTank and UnitIsOffTanked(unit) then
      threatLevel = "OFFTANK"
    else
      threatLevel = unit.threatSituation
    end
  else -- dps or normal
    threatLevel = REVERSE_THREAT_SITUATION[unit.threatSituation]
  end

  if db.art.theme == "bar" then
    widget_frame.LeftTexture:SetTexture(PATH .. db.art.theme.."\\"..threatLevel)
  else
    widget_frame.LeftTexture:SetTexture(PATH .. db.art.theme.."\\"..threatLevel)
    widget_frame.RightTexture:SetTexture(PATH .. db.art.theme.."\\"..threatLevel)
  end

  widget_frame:Show()
end