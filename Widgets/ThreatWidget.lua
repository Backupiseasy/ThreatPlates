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
local CreateFrame, InCombatLockdown, UNKNOWNOBJECT = CreateFrame, InCombatLockdown, UNKNOWNOBJECT
local UnitIsUnit, UnitThreatSituation, UnitIsPlayer = UnitIsUnit, UnitThreatSituation, UnitIsPlayer
local UnitReaction, UnitIsTapDenied, UnitLevel, UnitClassification, UnitName = UnitReaction, UnitIsTapDenied, UnitLevel, UnitClassification, UnitName
local IsInInstance = IsInInstance
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetRaidTargetIndex = GetRaidTargetIndex

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local OnThreatTable = ThreatPlates.OnThreatTable

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
  if not unitid or unitid == "player" or UnitIsUnit("player", unitid) then return end

  local plate = GetNamePlateForUnit(unitid)
  if plate then
    self:UpdateFrame(plate.TPFrame.widgets.Threat, plate.TPFrame.unit)
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
  return not (unit.type == "PLAYER" or style == "NameOnly" or style == "NameOnly-Unique" or style == "etotem")
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

local CLASSIFICATION_MAPPING = {
  ["worldboss"] = "Elite",
  ["rareelite"] = "Elite",
  ["elite"] = "Elite",
  ["rare"] = "Elite",
  ["normal"] = "Normal",
  ["minus"] = "Minus",
  ["trivial"] = "Minus",
}

--toggle = {
--  ["Boss"]	= true,
--  ["Elite"]	= true,
--  ["Normal"]	= true,
--  ["Neutral"]	= true,
--  ["Minus"] 	= true,
--  ["Tapped"] 	= true,
--  ["OffTank"] = true,
--},

local function GetUnitClassification(unit)
  local unit_reaction = UnitReaction(unit.unitid, "player")

  --  if unit_reaction < 4 then
  --    return nil -- Friendly Unit
  if UnitIsTapDenied(unit.unitid) then
    return "Tapped"
  elseif unit_reaction == 4 then
    return "Neutral"
  elseif unit.isBoss then
    return "Boss"
  end

  return CLASSIFICATION_MAPPING[unit.classification]
end

local function ShowThreatFeedback(unit)
  local db = TidyPlatesThreat.db.profile.threat

  -- UnitCanAttack?
  if not InCombatLockdown() or unit.type == "PLAYER" or UnitReaction(unit.unitid, "player") > 4 or not db.ON then
    return false
  end

  if not IsInInstance() and db.toggle.InstancesOnly then
    return false
  end

  if db.toggle[GetUnitClassification(unit)] then
    return not db.nonCombat or OnThreatTable(unit)
  end

  return false
end

function Module:UpdateFrame(widget_frame, unit)
  local db = TidyPlatesThreat.db.profile.threat

  if GetRaidTargetIndex(unit.unitid) and db.marked.art then
    widget_frame:Hide()
    return
  end

  if not ShowThreatFeedback(unit) then
    widget_frame:Hide()
    return
  end

  local name, _ = UnitName(unit.unitid) or UNKNOWNOBJECT, nil
  local unique_setting = TidyPlatesThreat.db.profile.uniqueSettings.map[name]
  if unique_setting then
    if not unique_setting.useStyle or not unique_setting.UseThreatColor then
      widget_frame:Hide()
      return
    end
  end

  local style = (TidyPlatesThreat:GetSpecRole() and "tank") or "dps"

  local threat_value = UnitThreatSituation("player", unit.unitid) or 0
  local threat_situation = THREAT_REFERENCE[threat_value]

  if style == "tank" then -- Tanking uses regular textures / swapped for dps / healing
    if db.toggle.OffTank and Addon:UnitIsOffTanked(unit) then
      threat_situation = "OFFTANK"
    end
  else -- dps or normal
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

--function Module:OnUpdateStyle(widget_frame, unit)
--  self:UpdateFrame(widget_frame, unit)
--end