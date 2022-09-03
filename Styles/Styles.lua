---------------------------------------------------------------------------------------------------
-- Module: Style
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs = pairs

-- WoW APIs
local InCombatLockdown = InCombatLockdown
local UnitPlayerControlled, UnitIsUnit = UnitPlayerControlled, UnitIsUnit
local UnitIsOtherPlayersPet = UnitIsOtherPlayersPet
local UnitIsBattlePet, UnitCreatureType = UnitIsBattlePet, UnitCreatureType
local UnitCanAttack = UnitCanAttack

-- ThreatPlates APIs
local TOTEMS = Addon.TOTEMS
local GetUnitVisibility = Addon.GetUnitVisibility
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish
local Threat = Addon.Threat
local ActiveTheme = Addon.Theme
local NameTriggers, AuraTriggers, CastTriggers = Addon.Cache.CustomPlateTriggers.Name, Addon.Cache.CustomPlateTriggers.Aura, Addon.Cache.CustomPlateTriggers.Cast
local NameWildcardTriggers, TriggerWildcardTests = Addon.Cache.CustomPlateTriggers.NameWildcard, Addon.Cache.TriggerWildcardTests
local CustomStylesForAllInstances, CustomStylesForCurrentInstance = Addon.Cache.Styles.ForAllInstances, Addon.Cache.Styles.ForCurrentInstance

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: GetSpellInfo, UnitIsTapDenied

---------------------------------------------------------------------------------------------------
-- Module Setup
---------------------------------------------------------------------------------------------------
local StyleModule = Addon.Style

---------------------------------------------------------------------------------------------------
-- Wrapper functions for WoW Classic
---------------------------------------------------------------------------------------------------

if Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC then
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

local INSTANCE_TYPES = {
  none = false,
  pvp = false,
  arena = false,
  party = true,
  raid = true,
  scenario = true,
}

-- Mapping necessary - to removed it, config settings must be changed/migrated
-- Visibility        Scale / Alpha                  Threat System
local MAP_UNIT_TYPE_TO_TP_TYPE = {
  FriendlyPlayer   = "FriendlyPlayer",
  FriendlyNPC      = "FriendlyNPC",
  FriendlyTotem    = "Totem",
  FriendlyGuardian = "Guardian",
  FriendlyPet      = "Pet",
  FriendlyMinus    = "Minus",    -- Not sure if they exist ... but to be sure and avoid Lua errors
  EnemyPlayer      = "EnemyPlayer",
  EnemyNPC         = "EnemyNPC", -- / Boss / Elite = Normal / Boss / Elite
  EnemyTotem       = "Totem",
  EnemyGuardian    = "Guardian",
  EnemyPet         = "Pet",
  EnemyMinus       = "Minus",
  NeutralNPC       = "Neutral",
  NeutralMinus     = "Minus",
}

local REMAP_UNSUPPORTED_UNIT_TYPES = {
  NeutralTotem     = "FriendlyTotem",    -- When players are mind-controled, their totems turn neutral it seems (at least in Classic): https://www.curseforge.com/wow/addons/tidy-plates-threat-plates/issues/506
  NeutralGuardian  = "FriendlyGuardian",
  NeutralPet       = "FriendlyPet",      -- Sometimes, friendly pets turn into neutral pets when you lose control over them (e.g., in quests).
}

local function GetUnitType(unit)
  local unit_class
  -- not all combinations are possible in the game: Friendly Minus, Neutral Player/Totem/Pet
  if unit.type == "PLAYER" then
    unit_class = "Player"
  elseif unit.TotemSettings then
    unit_class = "Totem"
  elseif UnitIsOtherPlayersPet(unit.unitid) or UnitIsUnit(unit.unitid, "pet") then -- player pets are also considered guardians, so this check has priority
    -- ? Better to use UnitIsOwnerOrControllerOfUnit("player", unit.unitid) here?
    unit_class = "Pet"
  elseif UnitPlayerControlled(unit.unitid) then
    unit_class = "Guardian"
  elseif unit.isMini then
    unit_class = "Minus"
  else
    unit_class = "NPC"
  end

  -- Sometimes, friendly pets or totems turn into neutral when you lose control over them (e.g., in quests or
  -- when players are mind-controled). So map unknown neutral types (totems, pets, guardians) to friendly ones  
  local unit_type = REACTION_MAPPING[unit.reaction] .. unit_class
  unit_type = REMAP_UNSUPPORTED_UNIT_TYPES[unit_type] or unit_type

  unit.TP_DetailedUnitType = MAP_UNIT_TYPE_TO_TP_TYPE[unit_type]

  if unit.TP_DetailedUnitType == "EnemyNPC" then
    unit.TP_DetailedUnitType = (unit.isBoss and "Boss") or (unit.isElite and "Elite") or unit.TP_DetailedUnitType
  end

  if unit.IsTapDenied then
    unit.TP_DetailedUnitType = "Tapped"
  end

  -- If nameplate visibility is controlled by Wow itself (configured via CVars), this function is never used as
  -- nameplates aren't created in the first place (e.g. friendly NPCs, totems, guardians, pets, ...)
  return GetUnitVisibility(unit_type)
end

local function ShowUnit(unit)
  local show, headline_view = GetUnitType(unit)

  -- If a unit is targeted, show the nameplate if possible.
  show = show or unit.isTarget

  if not show then return false, false, headline_view end

  local e, b = (unit.isElite or unit.isRare), unit.isBoss
  local db_base = Addon.db.profile
  local db = db_base.Visibility

  local hide_unit_type = false
  if (e and db.HideElite) or (b and db.HideBoss) or (unit.TP_DetailedUnitType == "Tapped" and db.HideTapped) or (unit.TP_DetailedUnitType == "Guardian" and db.HideGuardian) then
    hide_unit_type = true
  elseif db.HideNormal and not (e or b) then
    hide_unit_type = true
  elseif UnitIsBattlePet(unit.unitid) then
    -- TODO: add configuration option for enable/disable
    hide_unit_type = true
  elseif db.HideFriendlyInCombat and unit.reaction == "FRIENDLY" and InCombatLockdown() then
    hide_unit_type = true
  end

  if hide_unit_type and not unit.isTarget then
    return show, hide_unit_type, headline_view
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

  return show, false, headline_view
end

-- Returns style based on threat (currently checks for in combat, should not do hat)
function StyleModule:GetThreatStyle(unit)
  -- style tank/dps only used for NPCs/non-player units
  if Threat:ShowFeedback(unit) then
    return Addon.GetPlayerRole()
  end

  return "normal"
end

local function GetStyleForPlate(custom_style)
  -- If a style is found with useStyle == false, that means that it's active, but only the icon will be shown.
  if custom_style.useStyle then
    return (custom_style.showNameplate and "unique") or (custom_style.ShowHeadlineView and "NameOnly-Unique") or "etotem"
  end
  --return nil
end

-- Check if a unit is a totem or a custom nameplates (e.g., after UNIT_NAME_UPDATE)
-- Depends on:
--   * unit.name
function StyleModule:ProcessNameTriggers(unit)
  local plate_style, custom_style, totem_settings
  local name_custom_style = NameTriggers[unit.name] or NameTriggers[unit.NPCID]
  if name_custom_style and name_custom_style.Enable.UnitReaction[unit.reaction] then
    custom_style = name_custom_style
    plate_style = GetStyleForPlate(custom_style)
  elseif Addon.ActiveWildcardTriggers and unit.type == "NPC" then
    local cached_custom_style = TriggerWildcardTests[unit.name]

    if cached_custom_style == nil then
      cached_custom_style = false

      local trigger
      for i = 1, #NameWildcardTriggers do
        trigger = NameWildcardTriggers[i]
        --print ("Name Wildcard: ", unit.name, "=>", trigger[1], unit.name:find(trigger[1]))
        if unit.name:find(trigger[1]) then

          -- Static checks (based on not changing criterien (like unit type).
          if trigger[2].Enable.UnitReaction[unit.reaction] then
            custom_style = trigger[2]
            plate_style = GetStyleForPlate(custom_style)

            cached_custom_style = {
              Style = plate_style,
              CustomStyle = custom_style
            }

            -- Breaking here without plate_style being set means that only the icon part will be used from the custom style
            break
          end
        end
      end

      -- Add custom style, if one was found, or false if there is no custom style for this unit
      TriggerWildcardTests[unit.name] = cached_custom_style
    elseif cached_custom_style ~= false then
      custom_style = cached_custom_style.CustomStyle
      plate_style = cached_custom_style.Style
    end
  end

  if not plate_style and UnitCreatureType(unit.unitid) == Addon.TotemCreatureType then
    -- Check for player totems and ignore NPC totems
    local totem_id = TOTEMS[unit.name]
    if totem_id then
      local db = Addon.db.profile.totemSettings
      totem_settings = db[totem_id]
      if totem_settings.ShowNameplate then
        plate_style = (db.hideHealthbar and "etotem") or "totem"
      else
        plate_style = "etotem"
      end
    end
  end

  -- Conditions:
  --   * custom_style == nil: No custom style found
  --   * custom_style ~= nil: Custom style found, active
  --   * plate_style == nil: Appearance part of style will not be used, only icon will be shown (if custom_style ~= nil)

  -- Set these values to nil if not custom nameplate or totem
  unit.CustomPlateSettings = custom_style
  unit.TotemSettings = totem_settings

  return plate_style
end

function StyleModule:AuraTriggerInitialize(unit)
  if Addon.ActiveAuraTriggers then
    unit.PreviousCustomStyleAura = unit.CustomStyleAura
    unit.CustomStyleAura = nil
  end
end

function StyleModule:AuraTriggerUpdateStyle(unit)
  -- Set the style if a aura trigger for a custom nameplate was found or the aura trigger
  -- is no longer there
  if Addon.ActiveAuraTriggers and (unit.CustomStyleAura or unit.PreviousCustomStyleAura) then 
    local tp_frame = Addon:GetThreatPlateForUnit(unit.unitid)
    self:Update(tp_frame)
  end
end

function StyleModule:AuraTriggerCheckIfActive(unit, aura_id, aura_name, aura_cast_by_player)
  -- Do this to prevent overwrite the first aura trigger custom style found (which is the one being used)
  if not Addon.ActiveAuraTriggers or unit.CustomStyleAura then return false end

  local unique_settings = AuraTriggers[aura_id] or AuraTriggers[aura_name]
  -- Check if enabled for unit's faction and check for show only my auras
  if unique_settings and unique_settings.useStyle and unique_settings.Enable.UnitReaction[unit.reaction] and (not unique_settings.Trigger.Aura.ShowOnlyMine or aura_cast_by_player) then
    -- As this is called for every aura on a unit, never set it to false (overwriting a previous true value)
    unit.CustomStyleAura = (unique_settings.showNameplate and "unique") or (unique_settings.ShowHeadlineView and "NameOnly-Unique") or "etotem"
    unit.CustomPlateSettingsAura = unique_settings

    local _, _, icon = _G.GetSpellInfo(aura_id)
    unique_settings.AutomaticIcon = icon
    return true
  else
    return false
  end
end

function StyleModule:ProcessCastTriggers(unit, spell_id, spell_name)
  local plate_style

  local unique_settings = CastTriggers[spell_id] or CastTriggers[spell_name] or NameTriggers["Test"]
  if unique_settings and unique_settings.useStyle and unique_settings.Enable.UnitReaction[unit.reaction] then
    plate_style = (unique_settings.showNameplate and "unique") or (unique_settings.ShowHeadlineView and "NameOnly-Unique") or "etotem"

    unit.CustomStyleCast = plate_style
    unit.CustomPlateSettingsCast = unique_settings

    local _, _, icon = _G.GetSpellInfo(spell_id)
    unique_settings.AutomaticIcon = icon
  end

  return plate_style
end

function StyleModule:SetStyle(unit)
  local show, hide_unit_type, headline_view = ShowUnit(unit)

  -- Nameplate is disabled in General - Visibility
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
  	style = self:ProcessNameTriggers(unit) or (headline_view and "NameOnly")
  end
	  
  -- Dynamic enable checks for custom styles
  -- Only check it once if custom style is used for multiple mobs
  -- only check it once when entering a dungeon, not on every style change
  -- Array by instance ID and all enabled styles?
  local custom_style = unit.CustomPlateSettings
  if custom_style then
    if Addon.IsInPvEInstance then
      if not CustomStylesForAllInstances[custom_style] and not CustomStylesForCurrentInstance[custom_style] then
      -- Without cache: if not custom_style.Enable.Instances or (custom_style.Enable.InstanceIDs.Enable and not CustomStylesForCurrentInstance[custom_style]) then
        style = nil
        unit.CustomPlateSettings = nil
      end
    elseif not custom_style.Enable.OutOfInstances then
      style = nil
      unit.CustomPlateSettings = nil
    end
  end

  -- Hidden nameplates might be shown if a custom style is defined for them (Visibility - Hide Nameplates)
  if hide_unit_type and style ~= "unique" and style ~= "NameOnly-Unique" then
    return "empty", nil
  end

  -- if not style and Addon:ShowFeedback(unit) then
  --   -- could call GetThreatStyle here, but that would at a tiny overhead
  --   -- style tank/dps only used for hostile (enemy, neutral) NPCs
  --   style = Addon.GetPlayerRole()
  -- end

  -- return style or "normal"

  -- style should never be false here (only nil or "totem", ...)
  return style or self:GetThreatStyle(unit)
end

local NAMEPLATE_MODE_BY_THEME = {
  dps = "HealthbarMode",
  tank = "HealthbarMode",
  normal = "HealthbarMode",
  totem = "HealthbarMode",
  unique = "HealthbarMode",
  empty = "None",
  etotem = "None",
  NameOnly = "NameMode",
  ["NameOnly-Unique"] = "NameMode",
}

function StyleModule:Update(tp_frame)
  local unit = tp_frame.unit

  local old_custom_style = unit.CustomPlateSettings
  local stylename = self:SetStyle(unit)

  if tp_frame.stylename ~= stylename then
    local style = ActiveTheme[stylename]

    tp_frame.PlateStyle = NAMEPLATE_MODE_BY_THEME[stylename]
    tp_frame.stylename = stylename
    tp_frame.style = style
    unit.style = stylename

    PublishEvent("StyleUpdate", tp_frame, style, stylename)
  elseif (stylename == "unique" or stylename == "NameOnly-Unique") and unit.CustomPlateSettings ~= old_custom_style then
    -- Update the unique icon widget and style may be the same, but a different trigger might be active, e.g.,
    -- if two aura triggers fired
      Addon.UpdateCustomStyleIcon(tp_frame, unit)
      PublishEvent("StyleUpdate", tp_frame, ActiveTheme[stylename], stylename)
  end
end

function StyleModule:UpdateName(tp_frame)
  local stylename = self:ProcessNameTriggers(tp_frame.unit)

  if stylename and tp_frame.stylename ~= stylename then
    local style = ActiveTheme[stylename]

    tp_frame.PlateStyle = NAMEPLATE_MODE_BY_THEME[stylename]
    tp_frame.stylename = stylename
    tp_frame.style = style
    tp_frame.unit.style = stylename

    PublishEvent("StyleUpdate", tp_frame, style, stylename)
  end
end