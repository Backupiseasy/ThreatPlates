------------------------
-- Combo Point Widget --
------------------------
local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitCanAttack = UnitCanAttack
local UnitGUID = UnitGUID
local GetComboPoints = GetComboPoints
local UnitPowerMax = UnitPowerMax
local GetSpecialization = GetSpecialization
local SPEC_MONK_WINDWALKER = SPEC_MONK_WINDWALKER
local UnitPower = UnitPower
local SPELL_POWER_CHI = SPELL_POWER_CHI
local SPEC_PALADIN_RETRIBUTION = SPEC_PALADIN_RETRIBUTION
local SPELL_POWER_HOLY_POWER = SPELL_POWER_HOLY_POWER
local SPELL_POWER_SOUL_SHARDS = SPELL_POWER_SOUL_SHARDS
local UnitClass = UnitClass
local SPEC_MONK_WINDWALKER = SPEC_MONK_WINDWALKER


local TidyPlatesThreat = TidyPlatesThreat
local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ComboPointWidget\\"
local WidgetList = {}
local watcherIsEnabled = false

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
-- 	for _, widget in pairs(WidgetList) do
-- 		widget:Hide()
-- 	end
-- 	WidgetList = {}
-- end
-- ThreatPlatesWidgets.ClearAllComboPointWidgets = ClearAllWidgets

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function GetComboPointTarget()
  local points = GetComboPoints("player", "target")
  local maxPoints = UnitPowerMax("player", 4)

  return points, maxPoints
end

local function GetChiTarget()
  if GetSpecialization() ~= SPEC_MONK_WINDWALKER then return end

  local points = UnitPower("player", SPELL_POWER_CHI)
  local maxPoints = UnitPowerMax("player", SPELL_POWER_CHI)

  return points, maxPoints
end

local function GetPaladinHolyPower()
  if GetSpecialization() ~= SPEC_PALADIN_RETRIBUTION then return end

  local points = UnitPower("player", SPELL_POWER_HOLY_POWER)
  local maxPoints = UnitPowerMax("player", SPELL_POWER_HOLY_POWER)

  return points, maxPoints
end

local function GetWarlockSoulShards()
  local points = UnitPower("player", SPELL_POWER_SOUL_SHARDS)
  local maxPoints = UnitPowerMax("player", SPELL_POWER_SOUL_SHARDS)

  return points, maxPoints
end


local GetResourceOnTarget
local LocalName, PlayerClass = UnitClass("player")

if PlayerClass == "MONK" then
  GetResourceOnTarget = GetChiTarget
elseif PlayerClass == "ROGUE" then
  GetResourceOnTarget = GetComboPointTarget
elseif PlayerClass == "DRUID" then
  GetResourceOnTarget = GetComboPointTarget
-- Added holy power as combo points for retribution paladin
elseif PlayerClass == "PALADIN" then
  GetResourceOnTarget = GetPaladinHolyPower
elseif PlayerClass == "WARLOCK" then
  GetResourceOnTarget = GetWarlockSoulShards
else
  GetResourceOnTarget = function() end
end

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function UpdateSettings(frame)
  local db = TidyPlatesThreat.db.profile.comboWidget

  frame:SetPoint("CENTER", frame:GetParent(), "CENTER", db.x, db.y)
  frame:SetScale(db.scale)
  frame.Icon:SetAllPoints(frame)
end

-- Update Graphics - overwritten
-- unit can be null because called from WatcherFrame
local function UpdateWidgetFrame(frame, unit)
  local points, maxPoints

  if UnitCanAttack("player", "target") then
    points, maxPoints = GetResourceOnTarget()
  end

  if points and points > 0 then
    local db = TidyPlatesThreat.db.profile.comboWidget

    local style = unit.TP_Style
    if style == "NameOnly" or style == "NameOnly-Unique" then
      frame:SetPoint("CENTER", frame:GetParent(), "CENTER", db.x_hv, db.y_hv)
    else
      frame:SetPoint("CENTER", frame:GetParent(), "CENTER", db.x, db.y)
    end

    frame.Icon:SetTexture(PATH ..points)
    --frame:SetScale(db.scale)

    frame:Show()
  else
    frame:_Hide()
  end
end

-- Context
local function UpdateWidgetContext(frame, unit)
  local guid = unit.guid

  -- Add to Widget List
  if guid then
    if frame.guid then WidgetList[frame.guid] = nil end
    frame.guid = guid
    frame.unit = unit
    WidgetList[guid] = frame
  end

  -- -- Update Widget
  if UnitGUID("target") == guid then
    UpdateWidgetFrame(frame, unit)
  else
    frame:_Hide()
  end
end

--local function UpdateWidgetContext(frame, unit)
--  local guid = unit.guid
--
--  if not guid then
--    frame:_Hide()
--    return
--  end
--
--  local old_guid = frame.guid
--  if old_guid then WidgetList[old_guid] = nil end
--  frame.guid = guid
--  frame.unit = unit
--  WidgetList[guid] = frame
--
--  if UnitGUID("target") == guid then
--    UpdateWidgetFrame(frame, unit)
--  else
--    frame:_Hide()
--  end
--end

local function ClearWidgetContext(frame)
  local guid = frame.guid
  if guid then
    WidgetList[guid] = nil
    frame.guid = nil
    frame.unit = nil
  end
end

-- Watcher Frame
local WatcherFrame = CreateFrame("Frame", nil, WorldFrame )

-- EVENTS:
-- UNIT_COMBO_POINTS: -- combo points also fire UNIT_POWER
-- UNIT_POWER: "unitID", "powerType"  -- CHI, COMBO_POINTS
-- UNIT_DISPLAYPOWER: unitID
-- UNIT_AURA: unitID
-- UNIT_FLAGS: unitID

local WATCH_POWER_TYPES = {
  COMBO_POINTS = true,
  CHI = true,
  HOLY_POWER = true,
  SOUL_SHARDS = true,
}

local function WatcherFrameHandler(frame, event, unitid, power_type)
  -- only watch for player events
  if unitid ~= "player" then return end
  if event == "UNIT_POWER" and not WATCH_POWER_TYPES[power_type] then return end

  local guid = UnitGUID("target")
  if guid then
    local widget = WidgetList[guid]
    if widget then
      if widget.unit then
        UpdateWidgetFrame(widget, widget.unit)
      end
    end				-- To update all, use: for guid, widget in pairs(WidgetList) do UpdateWidgetFrame(widget) end
  end
end

--local function WatcherFrameHandler(frame, event, unitid)
--  local guid = UnitGUID("target")
--  if not guid then return end
--
--  local widget = WidgetList[guid]
--  if not widget then return end
--
--  local unit = widget.unit
--  if not unit then return end
--
--  UpdateWidgetFrame(widget, unit)
--  -- To update all, use: for guid, widget in pairs(WidgetList) do UpdateWidgetFrame(widget) end
--end

local function EnableWatcher()
  WatcherFrame:SetScript("OnEvent", WatcherFrameHandler)
  --WatcherFrame:RegisterEvent("UNIT_COMBO_POINTS")
  WatcherFrame:RegisterEvent("UNIT_POWER")
  WatcherFrame:RegisterEvent("UNIT_DISPLAYPOWER")
  --WatcherFrame:RegisterEvent("UNIT_AURA")
  WatcherFrame:RegisterEvent("UNIT_FLAGS")
  watcherIsEnabled = true
end

local function DisableWatcher()
  WatcherFrame:UnregisterAllEvents()
  WatcherFrame:SetScript("OnEvent", nil)
  watcherIsEnabled = false
end

local function enabled()
  local db = TidyPlatesThreat.db.profile.comboWidget

  if not (db.ON or db.ShowInHeadlineView) then
    if watcherIsEnabled then DisableWatcher()	end
  else
    if not watcherIsEnabled then EnableWatcher() end
  end

  return db.ON
end

local function EnabledInHeadlineView()
  return TidyPlatesThreat.db.profile.comboWidget.ShowInHeadlineView
end

-- Widget Creation
local function CreateWidgetFrame(parent)
  -- Required Widget Code
  local frame = CreateFrame("Frame", nil, parent)
  frame:Hide()

  -- Custom Code
  frame:SetSize(64, 64)
  frame:SetFrameLevel(parent:GetFrameLevel() + 7)

  frame.Icon = frame:CreateTexture(nil, "OVERLAY")

  UpdateSettings(frame)
  frame.UpdateConfig = UpdateSettings
  -- End Custom Code

  -- Required Widget Code
  frame.UpdateContext = UpdateWidgetContext
  frame.Update = UpdateWidgetFrame
  frame._Hide = frame.Hide
  frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end

  -- should not be necessary
  if not watcherIsEnabled then EnableWatcher() end
  return frame
end

ThreatPlatesWidgets.RegisterWidget("ComboPointWidgetTPTP", CreateWidgetFrame, true, enabled, EnabledInHeadlineView)
ThreatPlatesWidgets.ComboPointWidgetDisableWatcher = DisableWatcher
