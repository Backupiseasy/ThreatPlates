local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local InCombatLockdown = InCombatLockdown
local UnitPlayerControlled, UnitIsUnit = UnitPlayerControlled, UnitIsUnit
local UnitIsOtherPlayersPet = UnitIsOtherPlayersPet
local UnitIsBattlePet = UnitIsBattlePet
local UnitCanAttack = UnitCanAttack

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local TOTEMS = Addon.TOTEMS
local GetUnitVisibility = ThreatPlates.GetUnitVisibility
local NameTriggers, AuraTriggers, CastTriggers = Addon.Cache.CustomPlateTriggers.Name, Addon.Cache.CustomPlateTriggers.Aura, Addon.Cache.CustomPlateTriggers.Cast
local NameWildcardTriggers, TriggerWildcardTests = Addon.Cache.CustomPlateTriggers.NameWildcard, Addon.Cache.TriggerWildcardTests

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: GetSpellInfo, UnitIsTapDenied

---------------------------------------------------------------------------------------------------
-- Wrapper functions for WoW Classic
---------------------------------------------------------------------------------------------------

if Addon.CLASSIC then
  UnitIsBattlePet = function(...) return false end
end

---------------------------------------------------------------------------------------------------
-- Helper functions for styles and functions
---------------------------------------------------------------------------------------------------

local REACTION_MAPPING = {
  FRIENDLY = "Friendly",
  HOSTILE = "Enemy",
  NEUTRAL = "Neutral",
}

-- Mapping necessary - to removed it, config settings must be changed/migrated
-- Visibility        Scale / Alpha                  Threat System
local MAP_UNIT_TYPE_TO_TP_TYPE = {
  FriendlyPlayer   = "FriendlyPlayer",
  FriendlyNPC      = "FriendlyNPC",
  FriendlyTotem    = "Totem",
  FriendlyGuardian = "Guardian",
  FriendlyPet      = "Pet",
  EnemyPlayer      = "EnemyPlayer",
  EnemyNPC         = "EnemyNPC", -- / Boss / Elite = Normal / Boss / Elite
  EnemyTotem       = "Totem",
  EnemyGuardian    = "Guardian",
  EnemyPet         = "Pet",
  EnemyMinus       = "Minus", --                   = Minus
  NeutralNPC       = "Neutral", --                 = Neutral
  NeutralGuardian  = "Guardian",
  NeutralMinus     = "Minus" --                    = Minus
  --                  Tapped                       = Tapped
}

--local function GetUnitType(unit)
--  local faction = REACTION_MAPPING[unit.reaction]
--  local unit_class
--
--  -- not all combinations are possible in the game: Friendly Minus, Neutral Player/Totem/Pet
--  if unit.type == "PLAYER" then
--    unit_class = "Player"
--    unit.TP_DetailedUnitType = faction .. "Player"
--  elseif unit.TotemSettings then
--    unit_class = "Totem"
--    unit.TP_DetailedUnitType = "Totem"
--  elseif UnitIsOtherPlayersPet(unit.unitid) then -- player pets are also considered guardians, so this check has priority
--    unit_class = "Pet"
--    unit.TP_DetailedUnitType = "Pet"
--  elseif UnitPlayerControlled(unit.unitid) then
--    unit_class = "Guardian"
--    unit.TP_DetailedUnitType = "Guardian"
--  elseif unit.isMini then
--    unit_class = "Minus"
--    unit.TP_DetailedUnitType = "Minus"
--  else
--    unit_class = "NPC"
--    unit.TP_DetailedUnitType = (faction == "Neutral" and "Neutral") or (faction .. unit_class)
--  end
--
--  return faction, unit_class
--end

local function GetUnitType(unit)
  local faction = REACTION_MAPPING[unit.reaction]
  local unit_class

  -- not all combinations are possible in the game: Friendly Minus, Neutral Player/Totem/Pet
  if unit.type == "PLAYER" then
    unit_class = "Player"
  elseif unit.TotemSettings then
    unit_class = "Totem"
  elseif UnitIsOtherPlayersPet(unit.unitid) or UnitIsUnit(unit.unitid, "pet") then -- player pets are also considered guardians, so this check has priority
    unit_class = "Pet"
  elseif UnitPlayerControlled(unit.unitid) then
    unit_class = "Guardian"
  elseif unit.isMini then
    unit_class = "Minus"
  else
    unit_class = "NPC"
  end

  unit.TP_DetailedUnitType = MAP_UNIT_TYPE_TO_TP_TYPE[faction .. unit_class]

  if unit.TP_DetailedUnitType == "EnemyNPC" then
    unit.TP_DetailedUnitType = (unit.isBoss and "Boss") or (unit.isElite and "Elite") or unit.TP_DetailedUnitType
  end

  if _G.UnitIsTapDenied(unit.unitid) then
    unit.TP_DetailedUnitType = "Tapped"
  end

  return faction .. unit_class
end

local function ShowUnit(unit)
  -- If nameplate visibility is controlled by Wow itself (configured via CVars), this function is never used as
  -- nameplates aren't created in the first place (e.g. friendly NPCs, totems, guardians, pets, ...)
  local unit_type = GetUnitType(unit)
  local show, headline_view = GetUnitVisibility(unit_type)

  if not show then return false end

  local e, b, t = (unit.isElite or unit.isRare), unit.isBoss, _G.UnitIsTapDenied(unit.unitid)
  local db_base = TidyPlatesThreat.db.profile
  local db = db_base.Visibility

  if (e and db.HideElite) or (b and db.HideBoss) or (t and db.HideTapped) then
    return false
  elseif db.HideNormal and not (e or b) then
    return false
  elseif UnitIsBattlePet(unit.unitid) then
    -- TODO: add configuration option for enable/disable
    return false
  elseif db.HideFriendlyInCombat and unit.reaction == "FRIENDLY" and InCombatLockdown() then
    return false
  end

--  if full_unit_type == "EnemyNPC" then
--    if b then
--      unit.TP_DetailedUnitType = "Boss"
--    elseif e then
--      unit.TP_DetailedUnitType = "Elite"
--    end
--  end

--  if t then
--    --unit.TP_DetailedUnitType = "Tapped"
--    show = not db.HideTapped
--  end

  db = db_base.HeadlineView
  if db.ForceHealthbarOnTarget and unit.isTarget then
    headline_view = false
  elseif db.ForceOutOfCombat and not InCombatLockdown() then
    headline_view = true
  elseif db.ForceNonAttackableUnits and unit.reaction ~= "FRIENDLY" and not UnitCanAttack("player", unit.unitid) then
    headline_view = true
  elseif unit.reaction == "FRIENDLY" and InCombatLockdown() then
    if db.ForceFriendlyInCombat == "NAME" then
      headline_view = true
    elseif db.ForceFriendlyInCombat == "HEALTHBAR" then
      headline_view = false
    end
  end

  return show, headline_view
end

-- Returns style based on threat (currently checks for in combat, should not do hat)
function Addon:GetThreatStyle(unit)
  -- style tank/dps only used for NPCs/non-player units
  if Addon:ShowThreatFeedback(unit) then
    return (Addon:PlayerRoleIsTank() and "tank") or "dps"
  end

  return "normal"
end

-- Check if a unit is a totem or a custom nameplates (e.g., after UNIT_NAME_UPDATE)
-- Depends on:
--   * unit.name
function Addon.UnitStyle_NameDependent(unit)
  local plate_style

  local db = TidyPlatesThreat.db.profile

  local totem_settings
  local unique_settings = NameTriggers[unit.name]

  if unique_settings and unique_settings.useStyle and unique_settings.Enable.UnitReaction[unit.reaction] then
    plate_style = (unique_settings.showNameplate and "unique") or (unique_settings.ShowHeadlineView and "NameOnly-Unique") or "etotem"
  elseif Addon.ActiveWildcardTriggers and unit.type == "NPC" then
    local unit_test = TriggerWildcardTests[unit.name]

    if unit_test == nil then
      for i = 1, #NameWildcardTriggers do
        local trigger = NameWildcardTriggers[i]
        --print ("Name Wildcard: ", unit.name, "=>", trigger[1], unit.name:find(trigger[1]))
        if unit.name:find(trigger[1]) then
          unique_settings = trigger[2]
          plate_style = (unique_settings.showNameplate and "unique") or (unique_settings.ShowHeadlineView and "NameOnly-Unique") or "etotem"
          break
        end
      end

      TriggerWildcardTests[unit.name] = (plate_style and { plate_style, unique_settings }) or false
    elseif unit_test ~= false then
      plate_style = unit_test[1]
      unique_settings = unit_test[2]
    end
  end

  if not plate_style then
    -- Check for totem
    local totem_id = TOTEMS[unit.name]
    if totem_id then
      totem_settings = db.totemSettings[totem_id]
      if totem_settings.ShowNameplate then
        plate_style = (db.totemSettings.hideHealthbar and "etotem") or "totem"
      else
        plate_style = "empty"
      end
    end
  end

  -- Set these values to nil if not custom nameplate or totem
  unit.CustomPlateSettings = unique_settings
  unit.TotemSettings = totem_settings

  return plate_style
end

local UnitStyle_NameDependent = Addon.UnitStyle_NameDependent

function Addon.UnitStyle_AuraDependent(unit, aura_id, aura_name)
  local plate_style

  local unique_settings = AuraTriggers[aura_id] or AuraTriggers[aura_name]
  if unique_settings and unique_settings.useStyle and unique_settings.Enable.UnitReaction[unit.reaction] then
    plate_style = (unique_settings.showNameplate and "unique") or (unique_settings.ShowHeadlineView and "NameOnly-Unique") or "etotem"

    -- As this is called for every aura on a unit, never set it to false (overwriting a previous true value)
    if plate_style then
      unit.CustomStyleAura = plate_style
      unit.CustomPlateSettingsAura = unique_settings

      local _, _, icon = _G.GetSpellInfo(aura_id)
      unique_settings.AutomaticIcon = icon
    end
  end

  return plate_style
end

function Addon.UnitStyle_CastDependent(unit, spell_id, spell_name)
  local plate_style

  local unique_settings = CastTriggers[spell_id] or CastTriggers[spell_name]
  if unique_settings and unique_settings.useStyle and unique_settings.Enable.UnitReaction[unit.reaction] then
    plate_style = (unique_settings.showNameplate and "unique") or (unique_settings.ShowHeadlineView and "NameOnly-Unique") or "etotem"

    if plate_style then
      unit.CustomStyleCast = plate_style
      unit.CustomPlateSettingsCast = unique_settings

      local _, _, icon = _G.GetSpellInfo(spell_id)
      unique_settings.AutomaticIcon = icon
    end
  end

  return plate_style
end

-- Depends on:
--   * unit.reaction
--   * unit.name
--   * unit.type
--   * unit.classification
--   * unit.isBoss, isRare, isElite, isMini
--   * unit.isTapped
--   * UnitReaction
--   * UnitThreatSituation
--   * UnitIsTapDenied
--   * UnitIsOtherPlayersPet
--   * UnitPlayerControlled
--   ...
function Addon:SetStyle(unit)
  local show, headline_view = ShowUnit(unit)

  if not show then
    return "empty", nil
  end

  -- Check if custom nameplate should be used for the unit:
  local style
  if unit.CustomStyleCast then
    style = unit.CustomStyleCast
    unit.CustomPlateSettings = unit.CustomPlateSettingsCast
  elseif unit.CustomStyleAura then
    style = unit.CustomStyleAura
    unit.CustomPlateSettings = unit.CustomPlateSettingsAura
  else
    style = UnitStyle_NameDependent(unit) or (headline_view and "NameOnly")
  end

  --if not style and unit.reaction ~= "FRIENDLY" then
  if not style and Addon:ShowThreatFeedback(unit) then
    -- could call GetThreatStyle here, but that would at a tiny overhead
    -- style tank/dps only used for hostile (enemy, neutral) NPCs
    style = (Addon:PlayerRoleIsTank() and "tank") or "dps"
  end

  return style or "normal"
end