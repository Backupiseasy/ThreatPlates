---------------------------------------------------------------------------------------------------
-- Element: Threat
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local strsplit = strsplit

-- WoW APIs
local IsInInstance = IsInInstance
local UnitThreatSituation, UnitGroupRolesAssigned, UnitIsUnit = UnitThreatSituation, UnitGroupRolesAssigned, UnitIsUnit
local UnitGUID, UnitReaction, UnitIsTapDenied = UnitGUID, UnitReaction, UnitIsTapDenied

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local CLASSIFICATION_MAPPING = {
  ["boss"] = "Boss",
  ["worldboss"] = "Elite",
  ["rareelite"] = "Elite",
  ["elite"] = "Elite",
  ["rare"] = "Elite",
  ["normal"] = "Normal",
  ["minus"] = "Minus",
  ["trivial"] = "Minus",
}

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local CreatureCache = {}

local Settings
local ShowOnAttackedUnitsOnly, ShowOffTank, ShowInstancesOnly
local ThreatColor = {}

---------------------------------------------------------------------------------------------------
-- Returns if the unit is tanked by another tank or pet (not by the player character,
-- not by a dps)
---------------------------------------------------------------------------------------------------

-- Black Ox Statue of monks is: Creature with id 61146
-- Treants of druids is: Creature with id 103822
local function IsOffTankCreature(unitid)
  local guid = UnitGUID(unitid)

  if not guid then return false end

  local is_off_tank = CreatureCache[guid]
  if is_off_tank == nil then
    --local unit_type, server_id, instance_id, zone_uid, id, spawn_uid = string.match(guid, '^([^-]+)%-0%-([0-9A-F]+)%-([0-9A-F]+)%-([0-9A-F]+)%-([0-9A-F]+)%-([0-9A-F]+)$')
    --local unit_type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-", guid)
    local unit_type, _,  _, _, _, npc_id, _ = strsplit("-", guid)
    is_off_tank = (("61146" == npc_id or "103822" == npc_id) and "Creature" == unit_type)
    CreatureCache[guid] = is_off_tank
  end

  return is_off_tank
end

function Addon:UnitIsOffTanked(unit)
  local unitid = unit.unitid

  local threat_status = UnitThreatSituation("player", unitid) or 0
  if threat_status > 1 then -- tanked by player character
    return false
  end

  local target_of_unit = unitid .. "target"

  return ("TANK" == UnitGroupRolesAssigned(target_of_unit)) or UnitIsUnit(target_of_unit, "pet") or IsOffTankCreature(target_of_unit)
end

function Addon:OnThreatTable(unit)
  -- return  (unit.health < unit.healthmax) or (unit.InCombat or unit.ThreatStatus > 0) or (unit.isCasting == true) then

  --  local _, threatStatus = UnitDetailedThreatSituation("player", unit.unitid)
  --  return threatStatus ~= nil

  -- nil means player is not on unit's threat table - more acurate, but slower reaction time than the above solution
  -- return UnitThreatSituation("player", unit.unitid) ~= nil

  return unit.ThreatStatus ~= nil
end

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
  if UnitIsTapDenied(unit.unitid) then
    return "Tapped"
  elseif UnitReaction(unit.unitid, "player") == 4 then
    return "Neutral"
  end

  return CLASSIFICATION_MAPPING[unit.classification]
end

---------------------------------------------------------------------------------------------------
-- This function returns if threat feedback is enabled for the given unit. It does assume that
-- player (and unit) are in combat. It does not check for that.
---------------------------------------------------------------------------------------------------
function Addon:ShowThreatFeedback(unit)
  -- UnitCanAttack?
  --if not InCombatLockdown() or unit.type == "PLAYER" or UnitReaction(unit.unitid, "player") > 4 or not db.ON then
  if not Settings.ON or unit.type == "PLAYER" or UnitReaction(unit.unitid, "player") > 4 then
    return false
  end

  if not IsInInstance() and ShowInstancesOnly then
    return false
  end

  if Settings.toggle[GetUnitClassification(unit)] then
    return not Settings.nonCombat or Addon:OnThreatTable(unit)
  end

  return false
end

function Addon:ShowThreatGlowFeedback(unit)
  -- Check for Threat Glow enabled
  if unit.type == "PLAYER" or UnitReaction(unit.unitid, "player") > 4 then
    return false
  end

  -- Move ShowThreatGlowOnAttackedUnitsOnly to healtbar?-
  return not ShowOnAttackedUnitsOnly or Addon:OnThreatTable(unit)
end


function Addon:GetThreatColor(unit)
  -- Use either normal style colors (configured under Healthbar - Warning Glow) or threat system colors (if enabled)
  if Settings.ON and Settings.useHPColor then
    local style = (Addon.PlayerRoleIsTank and "tank") or "dps"

    if style == "tank" and ShowOffTank and Addon:UnitIsOffTanked(unit) then
      return ThreatColor[style]["OFFTANK"]
    else
      return ThreatColor[style][unit.ThreatLevel]
    end
  else
    return ThreatColor.normal[unit.ThreatLevel]
  end
end

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------

local Element = Addon.Elements.NewElement("Threat")

-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
--function Element.UnitAdded(tp_frame)
--end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.UnitRemoved(tp_frame)
--  tp_frame.visual.ThreatGlow:Hide() -- done in UpdateStyle
--end

--function Element.UpdateStyle(tp_frame, style)
--end

function Element.UpdateSettings()
  Settings = TidyPlatesThreat.db.profile.threat

  ShowOnAttackedUnitsOnly = TidyPlatesThreat.db.profile.ShowThreatGlowOnAttackedUnitsOnly
  ShowOffTank = TidyPlatesThreat.db.profile.toggle.OffTank
  ShowInstancesOnly = Settings.toggle.InstancesOnly

  for style, settings in pairs(TidyPlatesThreat.db.profile.settings) do
    ThreatColor[style] = settings.threatcolor
  end
end
