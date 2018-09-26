---------------------------------------------------------------------------------------------------
-- Threat related functions
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

-- Lua APIs
local string, strsplit = string, strsplit

-- WoW APIs
local UnitThreatSituation, UnitGroupRolesAssigned, UnitIsUnit = UnitThreatSituation, UnitGroupRolesAssigned, UnitIsUnit
local InCombatLockdown, IsInInstance = InCombatLockdown, IsInInstance
local UnitReaction, UnitIsTapDenied, UnitGUID = UnitReaction, UnitIsTapDenied, UnitGUID

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

Addon.CreatureCache = {}

---------------------------------------------------------------------------------------------------
-- @return    Returns if the unit is tanked by another tank or pet (not by the player character,
--            not by a dps)
--
-- @docu      Function is mostly called in combat situations with the character being the tank
--            (i.e., style == "tank")
---------------------------------------------------------------------------------------------------
function Addon:UnitIsOffTanked(unit)
  local unitid = unit.unitid

  local threat_status = UnitThreatSituation("player", unitid) or 0
  if threat_status > 1 then -- tanked by player character
    return false
  end

  local target_of_unit = unitid .. "target"

  return ("TANK" == UnitGroupRolesAssigned(target_of_unit)) or UnitIsUnit(target_of_unit, "pet") or self:IsBlackOxStatue(target_of_unit)
end

-- Black Ox Statue of monks is: Creature with id 61146
function Addon:IsBlackOxStatue(unitid)
  local guid = UnitGUID(unitid)

  if not guid then return false end

  local is_black_ox_statue = self.CreatureCache[guid]
  if is_black_ox_statue == nil then
    --local unit_type, server_id, instance_id, zone_uid, id, spawn_uid = string.match(guid, '^([^-]+)%-0%-([0-9A-F]+)%-([0-9A-F]+)%-([0-9A-F]+)%-([0-9A-F]+)%-([0-9A-F]+)$')
    --local unit_type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-", guid)
    local unit_type, _,  _, _, _, npc_id, _ = strsplit("-", guid)
    is_black_ox_statue = ("61146" == npc_id and "Creature" == unit_type)
    self.CreatureCache[guid] = is_black_ox_statue
  end

  return is_black_ox_statue
end

---------------------------------------------------------------------------------------------------
-- @return
--
-- @docu
---------------------------------------------------------------------------------------------------
function Addon:OnThreatTable(unit)
  -- "is unit inactive" from TidyPlates - fast, but doesn't meant that player is on threat table
  -- return  (unit.health < unit.healthmax) or (unit.isInCombat or unit.threatValue > 0) or (unit.isCasting == true) then

  --  local _, threatStatus = UnitDetailedThreatSituation("player", unit.unitid)
  --  return threatStatus ~= nil

  -- nil means player is not on unit's threat table - more acurate, but slower reaction time than the above solution
  return UnitThreatSituation("player", unit.unitid)
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
-- @return
--
-- @docu
---------------------------------------------------------------------------------------------------
function Addon:ShowThreatFeedback(unit)
  local db = TidyPlatesThreat.db.profile.threat

  -- UnitCanAttack?
  if not InCombatLockdown() or unit.type == "PLAYER" or UnitReaction(unit.unitid, "player") > 4 or not db.ON then
    return false
  end

  if not IsInInstance() and db.toggle.InstancesOnly then
    return false
  end

  if db.toggle[GetUnitClassification(unit)] then
    return not db.nonCombat or Addon:OnThreatTable(unit)
  end

  return false
end