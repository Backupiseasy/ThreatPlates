---------------------------------------------------------------------------------------------------
-- Combo Points Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = Addon:NewWidget("ComboPoints")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame
local UnitClass, UnitCanAttack, UnitIsUnit = UnitClass, UnitCanAttack, UnitIsUnit
local GetComboPoints, UnitPower, UnitPowerMax = GetComboPoints, UnitPower, UnitPowerMax
local SPELL_POWER_CHI, SPELL_POWER_HOLY_POWER,SPELL_POWER_SOUL_SHARDS = SPELL_POWER_CHI, SPELL_POWER_HOLY_POWER, SPELL_POWER_SOUL_SHARDS
local GetSpecialization, SPEC_PALADIN_RETRIBUTION, SPEC_MONK_WINDWALKER = GetSpecialization, SPEC_PALADIN_RETRIBUTION, SPEC_MONK_WINDWALKER
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ComboPointWidget\\"

local WATCH_POWER_TYPES = {
  COMBO_POINTS = true,
  CHI = true,
  HOLY_POWER = true,
  SOUL_SHARDS = true,
}

local GetResourceOnTarget
local CurrentTarget

---------------------------------------------------------------------------------------------------
-- Combo Points Widget Functions
---------------------------------------------------------------------------------------------------

local function GetComboPointTarget()
--    local points = GetComboPoints("player", "target")
--    local maxPoints = UnitPowerMax("player", 4)
--
--    return points, maxPoints

  return GetComboPoints("player", "target")
end

local function GetChiTarget()
--    local points = UnitPower("player", SPELL_POWER_CHI)
--    local maxPoints = UnitPowerMax("player", SPELL_POWER_CHI)
--
--    return points, maxPoints

  return UnitPower("player", SPELL_POWER_CHI)
end

local function GetPaladinHolyPower()
--    local points = UnitPower("player", SPELL_POWER_HOLY_POWER)
--    local maxPoints = UnitPowerMax("player", SPELL_POWER_HOLY_POWER)
--
--    return points, maxPoints

  return UnitPower("player", SPELL_POWER_HOLY_POWER)
end

local function GetWarlockSoulShards()
--    local points = UnitPower("player", SPELL_POWER_SOUL_SHARDS)
--    local maxPoints = UnitPowerMax("player", SPELL_POWER_SOUL_SHARDS)
--
--    return points, maxPoints

  return UnitPower("player", SPELL_POWER_SOUL_SHARDS)
end

local function GetComboPointFunction()
  local _, player_class = UnitClass("player")
  local spec = GetSpecialization()

  if player_class == "MONK" and spec == SPEC_MONK_WINDWALKER then
    return GetChiTarget
  elseif player_class == "ROGUE" then
    return GetComboPointTarget
  elseif player_class == "DRUID" then
    -- optimal: check for affinity, only with feral combo points should be necessary
    return GetComboPointTarget
  elseif player_class == "PALADIN" and spec == SPEC_PALADIN_RETRIBUTION then
    return GetPaladinHolyPower
  elseif player_class == "WARLOCK" then
    return GetWarlockSoulShards
  end

  return nil
end

local function UpdateComboPoints(widget_frame)
  local points = GetResourceOnTarget()

  if points > 0 then
    widget_frame.Icon:SetTexture(PATH .. points)
  else
    widget_frame.Icon:SetTexture(nil)
  end
end

-- This event handler only watches for events of unit == "player"
local function EventHandler(event, unitid, power_type)
  -- BfA:   if event == "UNIT_POWER_UPDATE" and not WATCH_POWER_TYPES[power_type] then return end
  if event == "UNIT_POWER" and not WATCH_POWER_TYPES[power_type] then return end

  local plate = GetNamePlateForUnit("target")
  if plate and plate.TPFrame.widgets.ComboPoints:IsShown() then -- not necessary, prerequisite for IsShown(): plate.TPFrame.Active and
    UpdateComboPoints(plate.TPFrame.widgets.ComboPoints)
  end
end

function Widget:ACTIVE_TALENT_GROUP_CHANGED(...)
  self:OnEnable()
  self:PLAYER_TARGET_CHANGED()
end

function Widget:PLAYER_TARGET_CHANGED()
  if CurrentTarget then
    CurrentTarget:Hide()
    CurrentTarget = nil
  end

  local plate = GetNamePlateForUnit("target")
  if plate and plate.TPFrame.Active and UnitCanAttack("player", "target") and GetResourceOnTarget then
    CurrentTarget = plate.TPFrame.widgets.ComboPoints
    if CurrentTarget.Active then
      UpdateComboPoints(CurrentTarget)
      CurrentTarget:Show()
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  widget_frame:SetSize(64, 64)
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
  widget_frame.Icon = widget_frame:CreateTexture(nil, "OVERLAY")
  widget_frame.Icon:SetAllPoints(tp_frame)
  -- End Custom Code

  -- Required Widget Code
  return widget_frame
end

function Widget:IsEnabled()
  return TidyPlatesThreat.db.profile.comboWidget.ON or TidyPlatesThreat.db.profile.comboWidget.ShowInHeadlineView
end

-- EVENTS:
-- UNIT_COMBO_POINTS: -- combo points also fire UNIT_POWER
-- BfA: UNIT_POWER_UPDATE: "unitID", "powerType"  -- CHI, COMBO_POINTS + Remove UNIT_POWER
-- UNIT_POWER: "unitID", "powerType"  -- CHI, COMBO_POINTS
-- UNIT_DISPLAYPOWER: Fired when the unit's mana stype is changed. Occurs when a druid shapeshifts as well as in certain other cases.
--   unitID
-- UNIT_AURA: unitID
-- UNIT_FLAGS: unitID
-- BfA: UNIT_POWER_FREQUENT: unitToken, powerToken

function Widget:OnEnable()
  GetResourceOnTarget = GetComboPointFunction()

  if GetResourceOnTarget then
    -- BfA: self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player", EventHandler) + remove UNIT_POWER
    self:RegisterUnitEvent("UNIT_POWER", "player", EventHandler)
    -- self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player", EventHandler)
    self:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player", EventHandler)
    self:RegisterUnitEvent("UNIT_FLAGS", "player", EventHandler)
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
  else
    self:UnregisterEvent("UNIT_POWER")
    self:UnregisterEvent("UNIT_DISPLAYPOWER")
    self:UnregisterEvent("UNIT_FLAGS")
  end

  self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
end

function Widget:EnabledForStyle(style, unit)
  -- Unit can get attackable at some point in time (e.g., after a roleplay sequence
  -- if not UnitCanAttack("player", "target") then return false end

  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return TidyPlatesThreat.db.profile.comboWidget.ShowInHeadlineView
  elseif style ~= "etotem" then
    return TidyPlatesThreat.db.profile.comboWidget.ON
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  local db = TidyPlatesThreat.db.profile.comboWidget

  -- Updates based on settings / unit style
  if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), "CENTER", db.x_hv, db.y_hv)
  else
    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), "CENTER", db.x, db.y)
  end

  -- Updates based on settings
  widget_frame:SetScale(db.scale)
  widget_frame.Icon:SetAllPoints(widget_frame)

  -- Updates based on unit status
  if UnitIsUnit("target", unit.unitid) and UnitCanAttack("player", "target") and GetResourceOnTarget then
    UpdateComboPoints(widget_frame)
    widget_frame:Show()
    CurrentTarget = widget_frame
  else
    widget_frame:Hide()
  end

  -- self:OnTargetChanged(widget_frame, unit)
end

--function Widget:OnUpdateStyle(widget_frame, unit)
--  local db = TidyPlatesThreat.db.profile.comboWidget
--  -- Updates based on settings / unit style
--  if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
--    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), "CENTER", db.x_hv, db.y_hv)
--  else
--    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), "CENTER", db.x, db.y)
--  end
--end

--function Widget:OnTargetChanged(widget_frame, unit)
--  if UnitIsUnit("target", unit.unitid) and UnitCanAttack("player", "target") and GetResourceOnTarget then
--    UpdateComboPoints(widget_frame)
--    widget_frame:Show()
--  else
--    widget_frame:Hide()
--  end
--end