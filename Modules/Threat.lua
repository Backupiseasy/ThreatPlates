---------------------------------------------------------------------------------------------------
-- Module: Threat
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local strsplit, pairs = strsplit, pairs

-- WoW APIs
local IsInInstance = IsInInstance
local UnitThreatSituation = UnitThreatSituation
local UnitIsPlayer, UnitPlayerControlled = UnitIsPlayer, UnitPlayerControlled
local UnitThreatSituation, UnitIsUnit, UnitExists, UnitGroupRolesAssigned = UnitThreatSituation, UnitIsUnit, UnitExists, UnitGroupRolesAssigned

-- WoW Classic APIs:
local GetPartyAssignment = GetPartyAssignment

-- ThreatPlates APIs
local THREAT_REFERENCE = Addon.THREAT_REFERENCE
local SubscribeEvent, PublishEvent,  UnsubscribeEvent = Addon.EventService.Subscribe, Addon.EventService.Publish, Addon.EventService.Unsubscribe
local Style, Color = Addon.Style, Addon.Color

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
-- Module Setup
---------------------------------------------------------------------------------------------------
local ThreatModule = Addon.Threat

---------------------------------------------------------------------------------------------------
-- Wrapper functions for WoW Classic
---------------------------------------------------------------------------------------------------

if Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC then
  UnitGroupRolesAssigned = function(target_unit)
    return (GetPartyAssignment("MAINTANK", target_unit) and "TANK") or "NONE"
  end
end

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local CreatureCache = {}

local Settings
local ShowOffTank, ShowInstancesOnly

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
local function IsOffTankCreature(unitid)
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

local function GetUnitClassification(unit)
  if unit.IsTapDenied then
    return "Tapped"
  elseif unit.reaction == "NEUTRAL" then
    return "Neutral"
  end

  return CLASSIFICATION_MAPPING[unit.classification]
end

---------------------------------------------------------------------------------------------------
-- Threat helper functions for the addon
---------------------------------------------------------------------------------------------------

function ThreatModule:OnThreatTable(unit)
  --  local _, threatStatus = UnitDetailedThreatSituation("player", unit.unitid)
  --  return threatStatus ~= nil

  -- nil means player is not on unit's threat table - more acurate, but slower reaction time than the above solution
  -- return UnitThreatSituation("player", unit.unitid) ~= nil

  return unit.ThreatLevel ~= nil
end

-- This function returns if threat feedback is enabled for the given unit. It does assume that
-- player (and unit) are in combat. It does not check for that.
function ThreatModule:ShowFeedback(unit)
  if unit.type == "PLAYER" or unit.reaction == "FRIENDLY" then
    return false
  end

  if not Addon.IsInPvEInstance and ShowInstancesOnly then
    return false
  end

  if Settings.toggle[GetUnitClassification(unit)] then
    return unit.ThreatLevel ~= nil
  end

  return false
end

---------------------------------------------------------------------------------------------------
-- Module code
---------------------------------------------------------------------------------------------------

local function CheckIfUnitIsOfftanked(unit, threat_level, other_player_has_aggro)
  -- Reset IsOfftanked if the player is tanking
  if other_player_has_aggro then
    if unit.style == "tank" and ShowOffTank then
      local target_unit = unit.unitid .. "target"

      -- Player does not tank the unit, so check if it is off-tanked:
      if UnitExists(target_unit) then
        if UnitIsPlayer(target_unit) or UnitPlayerControlled(target_unit) then
          local target_threat_situation = UnitThreatSituation(target_unit, unit.unitid) or 0
          if target_threat_situation > 1 then
            -- Target unit does tank unit, so check if target unit is a tank or an tank-like pet/guardian
            if ("TANK" == UnitGroupRolesAssigned(target_unit) and not UnitIsUnit("player", target_unit)) or UnitIsUnit(target_unit, "pet") or IsOffTankCreature(target_unit) then
              unit.IsOfftanked = true
            else
              -- Target unit does tank unit, but is not a tank or a tank-like pet/guardian
              unit.IsOfftanked = false
            end
          end
        end
      end
  
      -- Player does not tank the mob, but player might have been off-tanking before losing target.
      -- In that case, we assume that the mob is still securely off-tanked
      if unit.IsOfftanked then
        threat_level = "OFFTANK"
      end
    end
  else
    unit.IsOfftanked = false
  end

  return threat_level
end

local function UpdateThreatStatus(unit)
  unit.InCombat = _G.UnitAffectingCombat(unit.unitid)

  -- ? Does it make sense to also check for this here: UnitThreatSituation("pet", unit.unitid)?
  local threat_status = UnitThreatSituation("player", unit.unitid)
  if threat_status then
    unit.HasThreatTable = true
    return CheckIfUnitIsOfftanked(unit, THREAT_REFERENCE[threat_status], threat_status < 2)
  end
end
  
local function UpdateThreatStatusHeuristic(unit)
  if unit.InCombat and Addon.PlayerIsInCombat and (not Addon.UseThreatTable or (Addon.UseHeuristicInInstances and Addon.IsInPvEInstance)) then
    local threat_level
    
    local target_unit = unit.unitid .. "target"
    if UnitExists(target_unit) and not unit.isCasting then
      -- If the unit attacks a player's pet, this is not considered as the player having aggro, but the unit being off-tanked by the pet
      if UnitIsUnit(target_unit, "player") or UnitIsUnit(target_unit, "vehicle") then
        threat_level = "HIGH"
      else
        threat_level = "LOW"
      end
    else
      threat_level = unit.ThreatLevel or "LOW"
    end

    return CheckIfUnitIsOfftanked(unit, threat_level, (threat_level == "LOW"))
  end
end

local function UpdateThreatLevel(tp_frame, unit, threat_level)
  if threat_level == nil or threat_level ~= unit.ThreatLevel then
    unit.ThreatLevel = threat_level
    Style:Update(tp_frame)
    PublishEvent("ThreatUpdate", tp_frame, unit)
  end
end

-- Component Attributes: Threat
--   InCombat
--   ThreatLevel
--   IsOfftanked
--   HasThreatTable
function ThreatModule:SetUnitAttribute(tp_frame)
  local unit = tp_frame.unit
  
  -- As the unit is initialized (everything is nil) here, if threat_level is not nil here, HasThreatTable is true, 
  -- so no need to check it here
  local threat_level = UpdateThreatStatus(unit) or UpdateThreatStatusHeuristic(unit)
  -- Don't call UpdateThreatLevel here as we don't have to update style or fire a ThreatUpdate event here
  unit.ThreatLevel = threat_level
end

-- threat_level is nil when UNIT_THREAT_LIST_UPDATE fires at the beginning or end of combat
function ThreatModule:ThreatUpdate(tp_frame)
  UpdateThreatLevel(tp_frame, tp_frame.unit, UpdateThreatStatus(tp_frame.unit))
end

-- Heuristic: Player has to be in combat for it to be used
function ThreatModule:ThreatUpdateHeuristic(tp_frame)
  local unit = tp_frame.unit
  
  -- Only assume that the unit is out of combat, when it is not on any unit's threat table
  if not unit.HasThreatTable then
    if self.UseThreatTable or (self.UseHeuristicInInstances and not Addon.IsInPvEInstance) or not InCombatLockdown() then
      if unit.ThreatLevel then      
        UpdateThreatLevel(tp_frame, unit, nil)
      end
    else
      unit.InCombat = _G.UnitAffectingCombat(unit.unitid)
      local threat_level = UpdateThreatStatusHeuristic(unit)
      UpdateThreatLevel(tp_frame, unit, threat_level)
    end
  end
end

-- function ThreatModule:EnteringCombat()
--   for _, tp_frame in Addon:GetActiveThreatPlates() do
--     local threat_level = UpdateThreatStatus(tp_frame.unit)
--     UpdateThreatLevel(tp_frame, tp_frame.unit, threat_level)
--   end
-- end

function ThreatModule:LeavingCombat()
  for unitid, tp_frame in Addon:GetActiveThreatPlates() do
    tp_frame.unit.InCombat = _G.UnitAffectingCombat(unitid)
    -- No need to query threat, just set it to nil (as no longer in combat)
    UpdateThreatLevel(tp_frame, tp_frame.unit, nil)
  end
end

local function ProcessEventUpdateThreatHeuristic(unitTarget, event, flagText, amount, schoolMask)
  local tp_frame = Addon:GetThreatPlateForUnit(unitTarget)
  if tp_frame then
    ThreatModule:ThreatUpdateHeuristic(tp_frame)
  end
end

local function SubscribeThreatHeuristicEvents()
  SubscribeEvent(ThreatModule, "UNIT_COMBAT", ProcessEventUpdateThreatHeuristic)
  
  -- Currently, the cast functions in Nameplates.lua call ThreatModule:ThreatUpdateHeuristic directly. 
  -- SubscribeEvent(ThreatModule, "UNIT_SPELLCAST_START", ProcessEventUpdateThreatHeuristic)
  -- SubscribeEvent(ThreatModule, "UNIT_SPELLCAST_CHANNEL_START", ProcessEventUpdateThreatHeuristic)
  -- SubscribeEvent(ThreatModule, "UNIT_SPELLCAST_STOP", ProcessEventUpdateThreatHeuristic)
  -- SubscribeEvent(ThreatModule, "UNIT_SPELLCAST_CHANNEL_STOP", ProcessEventUpdateThreatHeuristic)
end

local function UnubscribeThreatHeuristicEvents()
  UnsubscribeEvent(ThreatModule, "UNIT_COMBAT", ProcessEventUpdateThreatHeuristic)
  
  -- UnsubscribeEvent(ThreatModule, "UNIT_SPELLCAST_START", ProcessEventUpdateThreatHeuristic)
  -- UnsubscribeEvent(ThreatModule, "UNIT_SPELLCAST_CHANNEL_START", ProcessEventUpdateThreatHeuristic)
  -- UnsubscribeEvent(ThreatModule, "UNIT_SPELLCAST_STOP", ProcessEventUpdateThreatHeuristic)
  -- UnsubscribeEvent(ThreatModule, "UNIT_SPELLCAST_CHANNEL_STOP", ProcessEventUpdateThreatHeuristic)
end

local function RegisterEventsforThreatHeuristic()
  --self.UseHeuristicInInstances is true as this function is only enabled in this case
  if IsInInstance() then
    SubscribeThreatHeuristicEvents()
  else
    UnubscribeThreatHeuristicEvents()
  end
end

function ThreatModule:UpdateSettings()
  Settings = Addon.db.profile.threat

  self.UseThreatTable = Settings.UseThreatTable
  self.UseHeuristicInInstances = Settings.UseHeuristicInInstances
  ShowOffTank = Settings.toggle.OffTank
  ShowInstancesOnly = Settings.toggle.InstancesOnly

  -- SubscribeEvent(ThreatModule, "UNIT_THREAT_SITUATION_UPDATE", function(unitid) end)

  -- If heuristic is enabled in general (not self.UseThreatTable), then we don't need PLAYER_ENTERING_WORLD
  if not self.UseThreatTable then
    SubscribeThreatHeuristicEvents()
    UnsubscribeEvent(ThreatModule, "PLAYER_ENTERING_WORLD", RegisterEventsforThreatHeuristic)
  elseif self.UseHeuristicInInstances then
    SubscribeEvent(ThreatModule, "PLAYER_ENTERING_WORLD", RegisterEventsforThreatHeuristic)
  else
    UnubscribeThreatHeuristicEvents()
    UnsubscribeEvent(ThreatModule, "PLAYER_ENTERING_WORLD", RegisterEventsforThreatHeuristic)
  end
end
