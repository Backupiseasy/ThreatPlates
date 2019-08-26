---------------------------------------------------------------------------------------------------
-- Threat related functions
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

-- Lua APIs
local string, strsplit = string, strsplit

-- WoW APIs
local InCombatLockdown, IsInInstance = InCombatLockdown, IsInInstance
local UnitReaction, UnitIsTapDenied, UnitGUID, UnitAffectingCombat = UnitReaction, UnitIsTapDenied, UnitGUID, UnitAffectingCombat

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local LibThreatClassic = Addon.LibThreatClassic

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

local CreatureCache = {}

---------------------------------------------------------------------------------------------------
-- @return    Returns if the unit is tanked by another tank or pet (not by the player character,
--            not by a dps)
--
-- @docu      Function is mostly called in combat situations with the character being the tank
--            (i.e., style == "tank")
---------------------------------------------------------------------------------------------------

local OFFTANK_PETS = {
  ["61146"] = true,  -- Monk's Black Ox Statue
  ["103822"] = true, -- Druid's Force of Nature Treants
  ["95072"] = true,  -- Shaman's Earth Elemental
}

-- Black Ox Statue of monks is: Creature with id 61146
-- Treants of druids is: Creature with id 103822
function Addon.IsOffTankCreature(unitid)
  local guid = UnitGUID(unitid)

  if not guid then return false end

  local is_off_tank = CreatureCache[guid]
  if is_off_tank == nil then
    --local unit_type, server_id, instance_id, zone_uid, id, spawn_uid = string.match(guid, '^([^-]+)%-0%-([0-9A-F]+)%-([0-9A-F]+)%-([0-9A-F]+)%-([0-9A-F]+)%-([0-9A-F]+)$')
    --local unit_type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-", guid)
    local unit_type, _,  _, _, _, npc_id, _ = strsplit("-", guid)
    is_off_tank = OFFTANK_PETS[npc_id] and "Creature" == unit_type
    CreatureCache[guid] = is_off_tank
  end

  return is_off_tank
end

function Addon:OnThreatTable(unit)
  --  local _, threatStatus = UnitDetailedThreatSituation("player", unit.unitid)
  --  return threatStatus ~= nil

  -- nil means player is not on unit's threat table - more acurate, but slower reaction time than the above solution
  -- return UnitThreatSituation("player", unit.unitid) ~= nil

  local _, _, scaledPercent, _, threatValue = LibThreatClassic:UnitDetailedThreatSituation("player", unit.unitid)
  return scaledPercent and scaledPercent > 0
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

function Addon:ShowThreatFeedback(unit)
  local db = TidyPlatesThreat.db.profile.threat

  if not InCombatLockdown() or unit.type == "PLAYER" or UnitReaction(unit.unitid, "player") > 4 or not db.ON then
    return false
  end

  local isInstance, _ = IsInInstance()
  if not isInstance and db.toggle.InstancesOnly then
    return false
  end

  if db.toggle[GetUnitClassification(unit)] then
    if db.UseThreatTable then
      if isInstance and db.UseHeuristicInInstances then
        return UnitAffectingCombat(unit.unitid)
      else
        return Addon:OnThreatTable(unit)
      end
    else
      return UnitAffectingCombat(unit.unitid)
    end
  end

  return false
end