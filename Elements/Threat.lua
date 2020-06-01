---------------------------------------------------------------------------------------------------
-- Element: Threat
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local strsplit, pairs = strsplit, pairs

-- WoW APIs
local IsInInstance = IsInInstance
local UnitReaction = UnitReaction

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: UnitAffectingCombat, UnitGUID

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

local OFFTANK_PETS = {
  ["61146"] = true,  -- Monk's Black Ox Statue
  ["103822"] = true, -- Druid's Force of Nature Treants
  ["95072"] = true,  -- Shaman's Earth Elemental
}

-- Black Ox Statue of monks is: Creature with id 61146
-- Treants of druids is: Creature with id 103822
function Addon.IsOffTankCreature(unitid)
  local guid = _G.UnitGUID(unitid)

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
  if unit.IsTapDenied then
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
  --if not InCombatLockdown() or unit.type == "PLAYER" or UnitReaction(unit.unitid, "player") > 4 or not db.ON then
  if not Settings.ON or unit.type == "PLAYER" or UnitReaction(unit.unitid, "player") > 4 then
    return false
  end

  local isInstance, _ = IsInInstance()
  if not isInstance and ShowInstancesOnly then
    return false
  end

  if Settings.toggle[GetUnitClassification(unit)] then
    if Settings.UseThreatTable then
      if isInstance and Settings.UseHeuristicInInstances then
        return _G.UnitAffectingCombat(unit.unitid)
      else
        return Addon:OnThreatTable(unit)
      end
    else
      return _G.UnitAffectingCombat(unit.unitid)
    end
  end

  return false
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
  ShowOffTank = Settings.toggle.OffTank
  ShowInstancesOnly = Settings.toggle.InstancesOnly

  for style, settings in pairs(TidyPlatesThreat.db.profile.settings) do
    if settings.threatcolor then -- there are several subentries unter settings. Only use style subsettings like unique, normal, dps, ...
      ThreatColor[style] = settings.threatcolor
    end
  end
end
