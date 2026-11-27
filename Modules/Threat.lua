---------------------------------------------------------------------------------------------------
-- Module: Threat
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local strsplit = strsplit

-- WoW APIs
local UnitPlayerControlled = UnitPlayerControlled
local UnitThreatSituation, UnitIsUnit, UnitExists = UnitThreatSituation, UnitIsUnit, UnitExists
local UnitGroupRolesAssigned, GetPartyAssignment = UnitGroupRolesAssigned, GetPartyAssignment
local IsInInstance = IsInInstance
local IsInRaid, GetNumGroupMembers, GetNumSubgroupMembers = IsInRaid, GetNumGroupMembers, GetNumSubgroupMembers
local C_Timer_After = C_Timer.After

-- ThreatPlates APIs
local THREAT_REFERENCE = Addon.THREAT_REFERENCE
local SubscribeEvent, PublishEvent,  UnsubscribeEvent = Addon.EventService.Subscribe, Addon.EventService.Publish, Addon.EventService.Unsubscribe
local StyleModule = Addon.Style
local IsSecretValue, UnitIsUnitTP = Addon.IsSecretValue, Addon.UnitIsUnit

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
-- Local variables
---------------------------------------------------------------------------------------------------
local CreatureCache = {}

local Settings
local ShowOffTank, ShowOffTankPets, ShowInstancesOnly, UseThreatTable, UseHeuristicInInstances

---------------------------------------------------------------------------------------------------
-- Off-tank guardians: guardians that can tank, but don't have a pet unit token (so they are not part of the off-tank
-- cache below). They can only be found as the target of a mob, identified by their NPC ID from the GUID. Therefore,
-- they are only detected on clients without Midnight's API surface: there, the mob's target can be secret and NPC-ID
-- parsing from GUIDs is disabled.
---------------------------------------------------------------------------------------------------

local OFFTANK_PETS = {
  ["61146"] = true,  -- Monk's Black Ox Statue
  ["103822"] = true, -- Druid's Force of Nature Treants
  ["95072"] = true,  -- Shaman's Earth Elemental
}

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

---------------------------------------------------------------------------------------------------
-- Off-tank cache
--
-- Off-tanking is detected by checking the threat situation of the other tanks and the pets of the group for the mob
-- (not via the mob's target, which can be secret on clients with Midnight's API surface). This cache contains the
-- unit tokens to check, so that only a few units have to be queried per nameplate instead of the whole group.
--
-- A group member is a tank only if its assigned group role is TANK or it's a main tank in a raid. Specialization,
-- stance, or auras are not used: a player with role DAMAGER counts as damage dealer even with a tank specialization.
-- Every existing pet of the group counts.
--
-- The cache is rebuilt completely (at most 40 members and 40 pets) after group, role, and pet changes. Events only
-- schedule a rebuild for the next frame, so bursts of GROUP_ROSTER_UPDATE (e.g., when joining a raid) cause only one.
---------------------------------------------------------------------------------------------------

-- Separate subscriber for EventService: there is only one handler per subscriber and event, and ThreatModule
-- (un)subscribes PLAYER_ENTERING_WORLD for the threat heuristic itself.
local OffTankCache = {}

local OffTankUnits = {}       -- Unit tokens of group members with role TANK or main tank (e.g. "party2", "raid17")
local OffTankPetUnits = {}    -- Unit tokens of existing pets of the group (e.g. "pet", "partypet1", "raidpet12")
local OffTankCacheEnabled = false
local OffTankCachePetsEnabled = false -- Option "Pets as Off-Tanks": without it, no pets are cached and UNIT_PET is not needed
local OffTankCacheDirty = true
local OffTankCacheRebuildScheduled = false

-- The assigned role was readable in instances, encounters and Mythic+ (tested on Retail). If it should ever be secret,
-- the group member simply does not count as tank.
local function UnitIsAssignedTank(unitid)
  if GetPartyAssignment("MAINTANK", unitid) then
    return true
  end

  local role = UnitGroupRolesAssigned(unitid)
  return not IsSecretValue(role) and role == "TANK"
end

local function RebuildOffTankCache()
  local tank_units, pet_units = {}, {}

  local function AddGroupMember(unitid, pet_unitid)
    if UnitExists(unitid) and UnitIsAssignedTank(unitid) then
      tank_units[#tank_units + 1] = unitid
    end

    if OffTankCachePetsEnabled and UnitExists(pet_unitid) then
      pet_units[#pet_units + 1] = pet_unitid
    end
  end

  if OffTankCachePetsEnabled and UnitExists("pet") then
    pet_units[#pet_units + 1] = "pet"
  end

  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unitid = "raid" .. i
      -- The player's own entry: its pet is already added as "pet". If the comparison is secret, the player might be
      -- added as tank, which is harmless: the player's own threat is only checked if another unit has aggro.
      if not UnitIsUnitTP(unitid, "player") then
        AddGroupMember(unitid, "raidpet" .. i)
      end
    end
  else
    -- partyN never contains the player
    for i = 1, GetNumSubgroupMembers() do
      AddGroupMember("party" .. i, "partypet" .. i)
    end
  end

  OffTankUnits, OffTankPetUnits = tank_units, pet_units
  OffTankCacheDirty = false
end

local function RebuildOffTankCacheIfDirty()
  OffTankCacheRebuildScheduled = false
  if OffTankCacheDirty then
    RebuildOffTankCache()
  end
end

-- In PvP instances (battlegrounds, arenas), there is no threat, so the cache is kept empty and not updated there.
-- The cache stays dirty, so that it is rebuilt after leaving the PvP instance.
local function InvalidateOffTankCache()
  OffTankCacheDirty = true
  if not OffTankCacheRebuildScheduled and not Addon.IsInPvPInstance then
    OffTankCacheRebuildScheduled = true
    C_Timer_After(0, RebuildOffTankCacheIfDirty)
  end
end

local function ClearOffTankCache()
  OffTankUnits, OffTankPetUnits = {}, {}
  OffTankCacheDirty = true
end

-- Addon.IsInPvPInstance is already updated here, as Addon:PLAYER_ENTERING_WORLD is the main subscriber of this event
-- and called before all other subscribers (see EventService)
local function OffTankCacheEnteringWorld()
  if Addon.IsInPvPInstance then
    ClearOffTankCache()
  else
    InvalidateOffTankCache()
  end
end

local function EnableOffTankCache()
  SubscribeEvent(OffTankCache, "GROUP_ROSTER_UPDATE", InvalidateOffTankCache)
  SubscribeEvent(OffTankCache, "PLAYER_ROLES_ASSIGNED", InvalidateOffTankCache)
  -- UNIT_PET is (un)subscribed in UpdateSettings, depending on the option "Pets as Off-Tanks"
  SubscribeEvent(OffTankCache, "PLAYER_ENTERING_WORLD", OffTankCacheEnteringWorld)
  -- Safety net on entering combat, in case a group or role change was missed by the events above
  SubscribeEvent(OffTankCache, "PLAYER_REGEN_DISABLED", InvalidateOffTankCache)
  InvalidateOffTankCache()
end

local function DisableOffTankCache()
  Addon.EventService.UnsubscribeAll(OffTankCache)
  ClearOffTankCache()
end

-- Returns the cached unit tokens of the other tanks and the pets of the group (rebuilt first, if outdated).
-- Returns empty lists in PvP instances.
function ThreatModule.GetOffTankUnits()
  if OffTankCacheDirty and not Addon.IsInPvPInstance then
    RebuildOffTankCache()
  end

  return OffTankUnits, OffTankPetUnits
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

-- This function returns if threat feedback is enabled for the given unit. It does assume that
-- player (and unit) are in combat. It does not check for that.
function ThreatModule.ShowFeedback(unit)
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

-- Returns true if the unit is tanking the mob (threat situation 2 or 3), false if not or if that is secret.
-- No UnitExists/UnitIsVisible check needed: UnitThreatSituation returns nil for a unit token that became empty since
-- the last cache rebuild (tested), and group members are always visible to the client (warcraft.wiki.gg).
local function UnitHoldsAggro(unitid, mob_unitid)
  local threat_situation = UnitThreatSituation(unitid, mob_unitid)
  return threat_situation ~= nil and not IsSecretValue(threat_situation) and threat_situation >= 2
end

-- Returns true if one of the other tanks or a pet of the group (if enabled) is tanking the mob
local function IsUnitOfftankedByGroup(mob_unitid)
  local tank_units, pet_units = ThreatModule.GetOffTankUnits()

  for i = 1, #tank_units do
    if UnitHoldsAggro(tank_units[i], mob_unitid) then
      return true
    end
  end

  -- Empty if the option "Pets as Off-Tanks" is disabled
  for i = 1, #pet_units do
    if UnitHoldsAggro(pet_units[i], mob_unitid) then
      return true
    end
  end

  return false
end

-- Returns true if an off-tank guardian without pet unit token (OFFTANK_PETS) is tanking the mob.
-- Only used on clients without Midnight's API surface (see OFFTANK_PETS).
local function IsUnitOfftankedByGuardian(mob_unitid)
  local target_unitid = mob_unitid .. "target"
  return UnitExists(target_unitid) and UnitPlayerControlled(target_unitid) and IsOffTankCreature(target_unitid) and
    (UnitThreatSituation(target_unitid, mob_unitid) or 0) >= 2
end

-- Off-tank state is calculated anew every time, so it never sticks after another tank lost aggro.
local function CheckIfUnitIsOfftanked(unit, threat_level, other_player_has_aggro)
  unit.IsOfftanked = (other_player_has_aggro and ShowOffTank and Addon.GetPlayerRole() == "tank" and
    (IsUnitOfftankedByGroup(unit.unitid) or
      (ShowOffTankPets and not Addon.HAS_MIDNIGHT_API and IsUnitOfftankedByGuardian(unit.unitid)))) or false

  return (unit.IsOfftanked and "OFFTANK") or threat_level
end

local function UpdateThreatStatus(unit)
  unit.InCombat = _G.UnitAffectingCombat(unit.unitid)

  -- ? Does it make sense to also check for this here: UnitThreatSituation("pet", unit.unitid)?
  local threat_status = UnitThreatSituation("player", unit.unitid)
  if IsSecretValue(threat_status) then
    return nil
  elseif threat_status then
    unit.HasThreatTable = true
    return CheckIfUnitIsOfftanked(unit, THREAT_REFERENCE[threat_status], threat_status < 2)
  end

  -- The player is not on the mob's threat table, but another tank or a pet of the group might be tanking it
  local threat_level = CheckIfUnitIsOfftanked(unit, nil, true)
  if threat_level then
    -- Otherwise, the threat heuristic (UpdateHeuristic) would reset it as the unit seems to have no threat table
    unit.HasThreatTable = true
  end

  return threat_level
end
  
local function UpdateThreatStatusHeuristic(unit)
  if unit.InCombat and Addon.PlayerIsInCombat and (not UseThreatTable or (UseHeuristicInInstances and Addon.IsInPvEInstance)) then
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
      threat_level = (unit.ThreatLevel ~= "OFFTANK" and unit.ThreatLevel) or "LOW"
    end

    return CheckIfUnitIsOfftanked(unit, threat_level, (threat_level == "LOW"))
  end
end

local function UpdateThreatLevel(tp_frame, unit, threat_level)
  if threat_level == nil or threat_level ~= unit.ThreatLevel then
    unit.ThreatLevel = threat_level
    StyleModule.Update(tp_frame)
    PublishEvent("ThreatUpdate", tp_frame, unit)
  end
end

-- Component Attributes: Threat
--   InCombat
--   ThreatLevel
--   IsOfftanked
--   HasThreatTable
function ThreatModule.SetUnitAttribute(unit)
  -- Don't call UpdateThreatLevel here — no style update or ThreatUpdate event needed during unit initialization.
  unit.ThreatLevel = UpdateThreatStatus(unit) or UpdateThreatStatusHeuristic(unit)
end

-- threat_level is nil when UNIT_THREAT_LIST_UPDATE fires at the beginning or end of combat
function ThreatModule.Update(tp_frame)
  UpdateThreatLevel(tp_frame, tp_frame.unit, UpdateThreatStatus(tp_frame.unit))
end

-- Heuristic: Player has to be in combat for it to be used
local function UpdateHeuristic(tp_frame)
  local unit = tp_frame.unit
  
  -- Only assume that the unit is out of combat, when it is not on any unit's threat table
  if not unit.HasThreatTable then
    if UseThreatTable or (UseHeuristicInInstances and not Addon.IsInPvEInstance) or not InCombatLockdown() then
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

-- function ThreatModule.EnteringCombat()
--   for _, tp_frame in Addon:GetActiveThreatPlates() do
--     local threat_level = UpdateThreatStatus(tp_frame.unit)
--     UpdateThreatLevel(tp_frame, tp_frame.unit, threat_level)
--   end
-- end

function ThreatModule.LeavingCombat()
  for unitid, tp_frame in Addon:GetActiveThreatPlates() do
    tp_frame.unit.InCombat = _G.UnitAffectingCombat(unitid)
    -- No need to query threat, just set it to nil (as no longer in combat)
    UpdateThreatLevel(tp_frame, tp_frame.unit, nil)
  end
end

local function ProcessEventUpdateThreatHeuristic(unitTarget, event, flagText, amount, schoolMask)
  local tp_frame = Addon:GetThreatPlateForUnit(unitTarget)
  if tp_frame then
    UpdateHeuristic(tp_frame)
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
  --UseHeuristicInInstances is true as this function is only enabled in this case
  if IsInInstance() then
    SubscribeThreatHeuristicEvents()
  else
    UnubscribeThreatHeuristicEvents()
  end
end

local function UpdateAllActivePlates()
  for _, tp_frame in Addon:GetActiveThreatPlates() do
    StyleModule.Update(tp_frame)
  end
end

function ThreatModule.UpdateSettings()
  Settings = Addon.db.profile.threat

  -- The threat heuristic is disabled on every client with Midnight's API surface (Addon.HAS_MIDNIGHT_API, not just
  -- Midnight itself): UnitIsUnit on the mob's target returns secret values there.
  UseThreatTable = Settings.UseThreatTable or Addon.HAS_MIDNIGHT_API
  UseHeuristicInInstances = Settings.UseHeuristicInInstances and not Addon.HAS_MIDNIGHT_API
  ShowOffTank = Settings.toggle.OffTank
  ShowOffTankPets = Settings.toggle.OffTankPets
  ShowInstancesOnly = Settings.toggle.InstancesOnly

  -- "OFFTANK" is only valid while the player is in tank role; recalculate when the role changes.
  -- Only relevant before Mists: GetPlayerRole() reads live stance data there. From Mists onwards the
  -- role is spec-based (cached in Addon.PlayerRole via ACTIVE_TALENT_GROUP_CHANGED), so stance changes
  -- do not affect role and subscribing to UPDATE_SHAPESHIFT_FORM would be a no-op.
  if ShowOffTank and not Addon.ExpansionIsAtLeastMists then
    SubscribeEvent(ThreatModule, "UPDATE_SHAPESHIFT_FORM", UpdateAllActivePlates)
  else
    UnsubscribeEvent(ThreatModule, "UPDATE_SHAPESHIFT_FORM", UpdateAllActivePlates)
  end

  -- Off-tank cache for the off-tank detection. UpdateSettings is called several times in a row for unrelated
  -- changes, so only enable/disable it when the setting actually changed.
  local use_off_tank_cache = ShowOffTank and true or false
  local use_off_tank_pets = use_off_tank_cache and ShowOffTankPets and true or false

  if use_off_tank_pets ~= OffTankCachePetsEnabled then
    OffTankCachePetsEnabled = use_off_tank_pets
    if use_off_tank_pets then
      SubscribeEvent(OffTankCache, "UNIT_PET", InvalidateOffTankCache)
    else
      UnsubscribeEvent(OffTankCache, "UNIT_PET")
    end
    -- Add or remove the pets (only if the cache stays enabled, otherwise it's (re)built or cleared below anyway)
    if use_off_tank_cache == OffTankCacheEnabled and use_off_tank_cache then
      InvalidateOffTankCache()
    end
  end

  if use_off_tank_cache ~= OffTankCacheEnabled then
    OffTankCacheEnabled = use_off_tank_cache
    if use_off_tank_cache then
      EnableOffTankCache()
    else
      DisableOffTankCache()
    end
  end

  -- SubscribeEvent(ThreatModule, "UNIT_THREAT_SITUATION_UPDATE", function(unitid) end)

  -- If heuristic is enabled in general (not self.UseThreatTable), then we don't need PLAYER_ENTERING_WORLD
  if not UseThreatTable then
    SubscribeThreatHeuristicEvents()
    UnsubscribeEvent(ThreatModule, "PLAYER_ENTERING_WORLD", RegisterEventsforThreatHeuristic)
  elseif UseHeuristicInInstances then
    SubscribeEvent(ThreatModule, "PLAYER_ENTERING_WORLD", RegisterEventsforThreatHeuristic)
  else
    UnubscribeThreatHeuristicEvents()
    UnsubscribeEvent(ThreatModule, "PLAYER_ENTERING_WORLD", RegisterEventsforThreatHeuristic)
  end
end
