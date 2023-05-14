---------------------------------------------------------------------------------------------------
-- Module: Color - Nameplate color for Healthbar & Name
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local abs, floor, ceil, pairs = abs, floor, ceil, pairs

-- WoW APIs
local UnitCanAttack, UnitIsPVP, UnitPlayerControlled = UnitCanAttack, UnitIsPVP, UnitPlayerControlled
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- WoW Classic APIs:

-- ThreatPlates APIs
local SubscribeEvent, PublishEvent,  UnsubscribeEvent = Addon.EventService.Subscribe, Addon.EventService.Publish, Addon.EventService.Unsubscribe
local Style = Addon.Style
local RGB_P = Addon.RGB_P

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: UnitAffectingCombat

---------------------------------------------------------------------------------------------------
-- Module Setup
---------------------------------------------------------------------------------------------------
local ColorModule = Addon.Color

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local ColorByHealthIsEnabled = false
local ShowQuestUnit

---------------------------------------------------------------------------------------------------
-- Wrapper functions for WoW Classic
---------------------------------------------------------------------------------------------------

if Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC then
  -- Quest widget is not available in Classic
  ShowQuestUnit = function(...) return false end
end

---------------------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------------------

local TRANPARENT_COLOR = Addon.RGB(0, 0, 0, 0)

local UNIT_COLOR_MAP = {
  FRIENDLY = { 
    NPC = "FriendlyNPC", 
    PLAYER = { 
      -- Unit PvP - Friendly Player
      [true] = {
        -- Player Character PvP
        [true] = "FriendlyPlayerPvPOn", 
        [false] = "FriendlyPlayerPvPOn",
      },
      [false] = {
        -- Player Character PvP
        [true] = "FriendlyPlayer",
        [false] = "FriendlyPlayer",
      },
    },
  },
  HOSTILE = {	
    NPC = "HostileNPC", 
    PLAYER = {
      -- Unit PvP Hostile Player
      [true] = {
        -- Player Character PvP
        [true] = "HostilePlayer",
        [false] = "HostilePlayerPvPOnSelfPvPOff",
      },
      [false] = {
        -- Player Character PvP
        [true] = "FriendlyPlayer",
        [false] = "FriendlyPlayer",
      },
    },
  },
  NEUTRAL = { 
    NPC = "NeutralUnit", 
    PLAYER = {
      -- Unit PvP
      [true] = {
        -- Player Character PvP
        [true] = "NeutralUnit",
        [false] = "NeutralUnit",
      },
      [false] = {
        -- Player Character PvP
        [true] = "NeutralUnit",
        [false] = "NeutralUnit",
      },
    },
  }
}

---------------------------------------------------------------------------------------------------
-- Cached configuration settings (for performance reasons)
---------------------------------------------------------------------------------------------------
local SettingsBase, Settings, SettingsName
local ColorByReaction, ColorByHealth
local HealthbarColorFunctions = {}
local NameColorFunctions = {
  HealthbarMode = {},
  NameMode = {},
}
local NameCustomColor = {
  HealthbarMode = {},
  NameMode = {}
}
local ThreatColor = {}
local NameModeSettings = {
  HealthbarMode = {},
  NameMode = {},
}

---------------------------------------------------------------------------------------------------
-- ThreatPlates Frame functions to return the current color for healthbar/name based on settings
---------------------------------------------------------------------------------------------------

local function GetCustomStyleColor(unit)
  local unique_setting = unit.CustomPlateSettings
  return (unique_setting and unique_setting.UseThreatColor and unit.CombatColor) or unit.CustomColor
end

local function GetUnitColorByHealth(tp_frame)
  local unit = tp_frame.unit
  return unit.SituationalColor or unit.HealthColor
end

local function GetUnitColorByReaction(tp_frame)
  local unit = tp_frame.unit
  return unit.SituationalColor or unit.CombatColor or unit.ReactionColor
end

local function GetUnitColorByClass(tp_frame)
  local unit = tp_frame.unit
  return unit.SituationalColor or unit.CombatColor or unit.ClassColor or unit.ReactionColor
end

local function GetUnitColorCustomPlate(tp_frame)
  local unit = tp_frame.unit
  return unit.SituationalColor or GetCustomStyleColor(unit)
end

local HEALTHBAR_COLOR_FUNCTIONS = {
  REACTION = GetUnitColorByReaction,
  CLASS = GetUnitColorByClass,
  HEALTH = GetUnitColorByHealth,
}

local function GetUnitColorByHealthName(tp_frame)
  local unit = tp_frame.unit
  return unit.SituationalNameColor or unit.HealthColor
end

local function GetUnitColorByReactionName(tp_frame)
  local unit = tp_frame.unit
  return unit.SituationalNameColor or unit.CombatColor or unit.ReactionColor
end

local function GetUnitColorByClassName(tp_frame)
  local unit = tp_frame.unit
  return unit.SituationalNameColor or unit.CombatColor or unit.ClassColor or unit.ReactionColor
end

local function GetUnitColorCustomColorName(tp_frame)
  local unit = tp_frame.unit
  return unit.SituationalNameColor or NameCustomColor[tp_frame.PlateStyle][unit.reaction]
end

local function GetUnitColorCustomPlateName(tp_frame)
  local unit = tp_frame.unit

  if tp_frame.PlateStyle == "HealthbarMode" then
    return NameColorFunctions.HealthbarMode[unit.reaction](tp_frame)
  else
    return unit.SituationalNameColor or GetCustomStyleColor(unit)
  end
end

local NAME_COLOR_FUNCTIONS = {
  REACTION = GetUnitColorByReactionName,
  CLASS = GetUnitColorByClassName,
  HEALTH = GetUnitColorByHealthName,
  CUSTOM = GetUnitColorCustomColorName,
}

---------------------------------------------------------------------------------------------------
-- Functions to set color for healthbar, name, and status text
---------------------------------------------------------------------------------------------------

local function UpdatePlateColors(tp_frame)
  local color

  if tp_frame.style.healthbar.show then
    -- When a nameplate is initalized, colors (e.g., unit.ReactionColor) are not yet defined, so GetHealthbarColor
    -- returns nil
    color = tp_frame:GetHealthbarColor() or TRANPARENT_COLOR

    local healthbar = tp_frame.visual.Healthbar
    healthbar:SetStatusBarColor(color.r, color.g, color.b, 1)

    if not Settings.BackgroundUseForegroundColor then
      color = Settings.BackgroundColor
    end
    healthbar.Background:SetVertexColor(color.r, color.g, color.b, 1 - Settings.BackgroundOpacity)
  end

  color = tp_frame:GetNameColor() or TRANPARENT_COLOR
  if SettingsName[tp_frame.PlateStyle].Enabled then
    tp_frame.visual.NameText:SetTextColor(color.r, color.g, color.b)
  end
  PublishEvent("NameColorUpdate", tp_frame, color)
end

---------------------------------------------------------------------------------------------------
-- Color-colculating Functions
---------------------------------------------------------------------------------------------------

local HealthColorCache = {}
local CS = CreateFrame("ColorSelect")

--GetSmudgeColorRGB function - from: https://www.wowinterface.com/downloads/info22536-ColorSmudge.html
--arg1: color table in RGB {r=0,g=0,b=0}
--arg2: color table in RGB {r=1,g=1,b=1}
--arg3: percentage 0-100
function CS:GetSmudgeColorRGB(colorA, colorB, perc)
  perc = perc * 0.01

  self:SetColorRGB(colorA.r,colorA.g,colorA.b)
  local h1, s1, v1 = self:GetColorHSV()
  self:SetColorRGB(colorB.r,colorB.g,colorB.b)
  local h2, s2, v2 = self:GetColorHSV()
  local h3 = floor(h1-(h1-h2) * perc)
  if abs(h1-h2) > 180 then
    local radius = (360-abs(h1-h2)) * perc
    if h1 < h2 then
      h3 = floor(h1-radius)
      if h3 < 0 then
        h3 = 360+h3
      end
    else
      h3 = floor(h1+radius)
      if h3 > 360 then
        h3 = h3-360
      end
    end
  end

  local s3 = s1-(s1-s2) * perc
  local v3 = v1-(v1-v2) * perc
  self:SetColorHSV(h3, s3, v3)

  return self:GetColorRGB()
end

---------------------------------------------------------------------------------------------------
-- Functions to the the base color for a unit
---------------------------------------------------------------------------------------------------

local function GetColorByHealth(unit)
  local health_pct = ceil(100 * unit.health / unit.healthmax)

  local health_color = HealthColorCache[health_pct]
  if not health_color then
    health_color = RGB_P(CS:GetSmudgeColorRGB(ColorByHealth.Low, ColorByHealth.High, health_pct))
    HealthColorCache[health_pct] = health_color
    --print ("Color: Adding color for", health_pct, "=>", Addon.Debug:ColorToString(health_color))
  end

  unit.HealthColor = health_color
end

-- Works as all functions using this function are triggerd by the NameColorChanged event
Addon.GetColorByHealthDeficit = function(unit)
  return unit.HealthColor
end

local function GetColorByReaction(unit)
    -- PvP coloring based on: https://wowpedia.fandom.com/wiki/PvP_flag
  -- Coloring for pets is the same as for the player controlling the pet
  local unit_type = (UnitPlayerControlled(unit.unitid) and "PLAYER") or unit.type
  -- * For players and their pets
  if unit_type == "PLAYER" then
    if ColorByReaction.IgnorePvPStatus or Addon.IsInPvPInstance then
      unit.ReactionColor = (unit.reaction == "HOSTILE" and ColorByReaction.HostilePlayer) or ColorByReaction.FriendlyPlayer
    else
      local unit_is_pvp = UnitIsPVP(unit.unitid) or false
      local player_is_pvp = UnitIsPVP("player") or false
      unit.ReactionColor = ColorByReaction[UNIT_COLOR_MAP[unit.reaction][unit_type][unit_is_pvp][player_is_pvp]]
    end
  -- * From here: For NPCs (without pets)
  elseif not UnitCanAttack("player", unit.unitid) and unit.blue < 0.1 and unit.green > 0.5 and unit.green < 0.6 and unit.red > 0.9 then
    -- Handle non-attackable units with brown healtbars - currently, I know no better way to detect this.
    unit.ReactionColor = ColorByReaction.UnfriendlyFaction
  else
    unit.ReactionColor = ColorByReaction[UNIT_COLOR_MAP[unit.reaction][unit_type]]
  end
end

local function GetColorByClass(unit, plate_style)
  local color

  if unit.type == "PLAYER" then
    if unit.reaction == "HOSTILE" then
      color = SettingsBase.Colors.Classes[unit.class]
    elseif unit.reaction == "FRIENDLY" then
      local db_social = SettingsBase.socialWidget
      if db_social.ShowFriendColor and Addon:IsFriend(unit, plate_style) then
        color = db_social.FriendColor
      elseif db_social.ShowGuildmateColor and Addon:IsGuildmate(unit, plate_style) then
        color = db_social.GuildmateColor
      else
        color = SettingsBase.Colors.Classes[unit.class]
      end
    end
  end

  unit.ClassColor = color
end

local function GetCustomStyleColor(unit)
  local color

  local unique_setting = unit.CustomPlateSettings

--  -- Threat System is should also be used for custom nameplate (in combat with thread system on)
--  if unique_setting and not unique_setting.UseThreatColor then
--    unit.CombatColor = nil
--    return nil
--  end

  if unique_setting and unique_setting.useColor then
    color = unique_setting.color
  else
    local totem_settings = unit.TotemSettings
    if totem_settings and totem_settings.ShowHPColor then
      color = totem_settings.Color
    end
  end

  unit.CustomColor = color

  return color
end

function ColorModule:GetThreatColor(unit)
  return unit.CombatColor
end

-- Threat System is OP, player is in combat, style is tank or dps
local function SetCombatColor(unit)
  -- For styles normal, totem, empty, no threat feedback i shown
  -- Style custom is handled by the part below
  local style = (unit.CustomPlateSettings and Style:GetThreatStyle(unit)) or unit.style

  if style == "dps" or style == "tank" then
    unit.CombatColor = ThreatColor[style][unit.ThreatLevel]
  else
    unit.CombatColor = nil
  end
end

---- Sitational Color - Order is: target, target marked, tapped, quest)
--local function GetSituationalColorHealthbar(unit, plate_style)
--  -- Not situational coloring for totems (currently)
--  if unit.TotemSettings then return end
--
--  local color
--  -- NameModeSettings.HealthbarMode.UseTargetColoring = SettingsBase.targetWidget.ModeHPBar
--  if unit.isTarget and SettingsBase.targetWidget.ModeHPBar then
--    color = SettingsBase.targetWidget.HPBarColor
--  else
--    local use_target_mark_color
--    if unit.CustomPlateSettings then
--      use_target_mark_color = unit.TargetMarker and unit.CustomPlateSettings.allowMarked
--    else
--      use_target_mark_color = unit.TargetMarker and Settings.UseRaidMarkColoring
--    end
--
--    if use_target_mark_color then
--      color = SettingsBase.settings.raidicon.hpMarked[unit.TargetMarker]
--    elseif unit.IsTapDenied then
--      color = ColorByReaction.TappedUnit
--    elseif Addon:ShowQuestUnit(unit) and Addon:IsPlayerQuestUnit(unit) then
--      -- Unit is quest target
--      color = SettingsBase.questWidget.HPBarColor
--    end
--  end
--
--  unit.SituationalColor = color
--end
--
---- Sitational Color - Order is: target, target marked, tapped, quest)
--local function GetSituationalColorName(unit, plate_style)
--  -- Not situational coloring for totems (currently)
--  if unit.TotemSettings then return end
--
--  local mode_settings = NameModeSettings[plate_style]
--
--  local color
--  if unit.isTarget and mode_settings.UseTargetColoring then
--    color = SettingsBase.targetWidget.HPBarColor
--  else
--    local use_target_mark_color
--    if unit.CustomPlateSettings then
--      use_target_mark_color = unit.TargetMarker and unit.CustomPlateSettings.allowMarked
--    else
--      use_target_mark_color = unit.TargetMarker and mode_settings.UseRaidMarkColoring
--    end
--
--    if use_target_mark_color then
--      color = SettingsBase.settings.raidicon.hpMarked[unit.TargetMarker]
--    elseif unit.IsTapDenied and tp_frame.PlateStyle == "NameMode" then
--      color = ColorByReaction.TappedUnit
--    end
--  end
--
--  unit.SituationalNameColor = color
--end

-- Sitational Color - Order is: target, target marked, tapped, quest)
local function GetSituationalColor(unit, plate_style)
  -- Not situational coloring for totems (currently)
  if unit.TotemSettings then return end

  local healthbar_color, name_color

  local mode_settings = NameModeSettings[plate_style]
  if unit.isTarget then
    -- NameModeSettings.HealthbarMode.UseTargetColoring = SettingsBase.targetWidget.ModeHPBar
    healthbar_color = NameModeSettings.HealthbarMode.UseTargetColoring and SettingsBase.targetWidget.HPBarColor
    name_color = mode_settings.UseTargetColoring and SettingsBase.targetWidget.HPBarColor
  elseif unit.IsFocus then
    healthbar_color = NameModeSettings.HealthbarMode.UseFocusColoring and SettingsBase.FocusWidget.HPBarColor
    name_color = mode_settings.UseFocusColoring and SettingsBase.FocusWidget.HPBarColor
  end

  ShowQuestUnit = ShowQuestUnit or Addon.ShowQuestUnit

  if not healthbar_color then
    local use_target_mark_color
    if unit.CustomPlateSettings then
      use_target_mark_color = unit.TargetMarker and unit.CustomPlateSettings.allowMarked
    else
      use_target_mark_color = unit.TargetMarker and Settings.UseRaidMarkColoring
    end

    if use_target_mark_color then
      healthbar_color = SettingsBase.settings.raidicon.hpMarked[unit.TargetMarker]
    elseif unit.IsTapDenied then
      healthbar_color = ColorByReaction.TappedUnit
    elseif ShowQuestUnit(unit) and Addon:IsPlayerQuestUnit(unit) then
      healthbar_color = SettingsBase.questWidget.HPBarColor
    end
  end

  if not name_color then
    local use_target_mark_color
    if unit.CustomPlateSettings then
      use_target_mark_color = unit.TargetMarker and unit.CustomPlateSettings.allowMarked
    else
      use_target_mark_color = unit.TargetMarker and mode_settings.UseRaidMarkColoring
    end

    if use_target_mark_color then
      name_color = SettingsBase.settings.raidicon.hpMarked[unit.TargetMarker]
    elseif unit.IsTapDenied and plate_style == "NameMode" then
      name_color = ColorByReaction.TappedUnit
    end
  end

  unit.SituationalColor = healthbar_color
  unit.SituationalNameColor = name_color
end

---------------------------------------------------------------------------------------------------
-- Core module code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function ColorModule:Initialize(tp_frame)
  if tp_frame.PlateStyle == "None" then return end
  
  local unit = tp_frame.unit

  --GetSituationalColorHealthbar(unit, tp_frame.PlateStyle)
  --GetSituationalColorName(unit, tp_frame.PlateStyle)
  GetSituationalColor(unit, tp_frame.PlateStyle)

  -- Not sure if this checks are 100% correct, might be just easier to initialize all colors anyway
  --if tp_frame.GetHealthbarColor == GetUnitColorByHealth or tp_frame.GetNameColor == GetUnitColorByHealthName or unit.CustomColor then
  if ColorByHealthIsEnabled or unit.CustomColor then
    GetColorByHealth(unit)
  end

  if not (tp_frame.GetHealthbarColor == GetUnitColorByHealth and tp_frame.GetNameColor == GetUnitColorByHealthName) then
--    print ("Unit:", unit.name)
    GetColorByReaction(unit)
    GetColorByClass(unit, tp_frame.PlateStyle)
--    print ("  Reaction:", Addon.Debug:ColorToString(unit.ReactionColor))
--    print ("  Class:", Addon.Debug:ColorToString(unit.ClassColor))
  end

  SetCombatColor(unit)

  UpdatePlateColors(tp_frame)
  --print ("Unit:", unit.name, "-> Updating Plate Colors:", Addon.Debug:ColorToString(tp_frame:GetHealthbarColor()))
end

-- Called in processing event: UpdateStyle in Nameplate.lua
function ColorModule:UpdateStyle(tp_frame, style)
  if tp_frame.PlateStyle == "None" then return end
  
  local unit = tp_frame.unit

  --local color = (style == "unique") and GetCustomStyleColor(unit)
  local color = GetCustomStyleColor(unit)

  -- As combat color is set to nil when a custom style is used, it has to be re-evaluated here
  SetCombatColor(tp_frame.unit)

  if color then
    tp_frame.GetHealthbarColor = GetUnitColorCustomPlate
    tp_frame.GetNameColor = GetUnitColorCustomPlateName
  else
    tp_frame.GetHealthbarColor = HealthbarColorFunctions[unit.reaction]
    tp_frame.GetNameColor = NameColorFunctions[tp_frame.PlateStyle][unit.reaction]
  end

  self:Initialize(tp_frame)

  UpdatePlateColors(tp_frame)
end

local function UNIT_HEALTH(unitid)
  local plate = GetNamePlateForUnit(unitid)
  local tp_frame = plate and plate.TPFrame
  if tp_frame and tp_frame.Active and tp_frame.PlateStyle ~= "None" then
    --print ("Color - UNIT_HEALTH:", unitid)

    GetColorByHealth(tp_frame.unit)
    UpdatePlateColors(tp_frame)
  end
end

local function CombatUpdate(tp_frame)
  if tp_frame.PlateStyle ~= "None" then
    SetCombatColor(tp_frame.unit)
    UpdatePlateColors(tp_frame)

    PublishEvent("ThreatColorUpdate", tp_frame)
  end
end

local function FactionUpdate(tp_frame)
  -- Only update reaction color if color mode ~= "HEALTH" for healthbar and name
  if tp_frame.PlateStyle ~= "None" and not (tp_frame.GetHealthbarColor == GetUnitColorByHealth and tp_frame.GetNameColor == GetUnitColorByHealth) then
      local unit = tp_frame.unit

      -- Tapped is detected by a UNIT_FACTION event (I think), but handled as a situational color change
      -- Update situational color if unit is now tapped or was tapped
      if unit.IsTapDenied or unit.SituationalColor == ColorByReaction.TappedUnit then
        --GetSituationalColorHealthbar(unit, tp_frame.PlateStyle)
        --GetSituationalColorName(unit, tp_frame.PlateStyle)
        GetSituationalColor(unit, tp_frame.PlateStyle)
      end

      GetColorByReaction(unit)
      UpdatePlateColors(tp_frame)

      --print ("Color - ReactionUpdate:", tp_frame.unit.unitid)
  end
end

local function SituationalColorUpdate(tp_frame)
  if tp_frame.PlateStyle ~= "None" then
    --GetSituationalColorHealthbar(unit, tp_frame.PlateStyle)
    --GetSituationalColorName(unit, tp_frame.PlateStyle)
    GetSituationalColor(tp_frame.unit, tp_frame.PlateStyle)
    UpdatePlateColors(tp_frame)

    --print ("Color - Situational Update:", tp_frame.unit.name .. "(" .. tp_frame.unit.unitid .. ") =>", tp_frame.unit.SituationalColor)
  end
end

local function ClassColorUpdate(tp_frame)
  -- Only update reaction color if color mode ~= "HEALTH" for healthbar and name
  if tp_frame.PlateStyle ~= "None" and not (tp_frame.GetHealthbarColor == GetUnitColorByHealth and tp_frame.GetNameColor == GetUnitColorByHealth) then
      -- No tapped unit detection necessary as this event only fires for player nameplates (which cannot be tapped, I hope)
      GetColorByClass(tp_frame.unit, tp_frame.PlateStyle)
      UpdatePlateColors(tp_frame)
  end
end

function ColorModule:UpdateSettings()
  SettingsBase = Addon.db.profile
  Settings = SettingsBase.Healthbar
  SettingsName = SettingsBase.Name

  --  Functions to calculate the healthbar/name color for a unit based
  HealthbarColorFunctions["FRIENDLY"] = HEALTHBAR_COLOR_FUNCTIONS[Settings.FriendlyUnitMode]
  HealthbarColorFunctions["HOSTILE"] = HEALTHBAR_COLOR_FUNCTIONS[Settings.EnemyUnitMode]
  HealthbarColorFunctions["NEUTRAL"] = HealthbarColorFunctions["HOSTILE"]

  NameColorFunctions["HealthbarMode"]["FRIENDLY"] = NAME_COLOR_FUNCTIONS[SettingsName.HealthbarMode.FriendlyUnitMode]
  NameColorFunctions["HealthbarMode"]["HOSTILE"] = NAME_COLOR_FUNCTIONS[SettingsName.HealthbarMode.EnemyUnitMode]
  NameColorFunctions["HealthbarMode"]["NEUTRAL"] = NameColorFunctions["HealthbarMode"]["HOSTILE"]

  NameColorFunctions["NameMode"]["FRIENDLY"] = NAME_COLOR_FUNCTIONS[SettingsName.NameMode.FriendlyUnitMode]
  NameColorFunctions["NameMode"]["HOSTILE"] = NAME_COLOR_FUNCTIONS[SettingsName.NameMode.EnemyUnitMode]
  NameColorFunctions["NameMode"]["NEUTRAL"] = NameColorFunctions["NameMode"]["HOSTILE"]

  --  Custom color for Name text in healthbar and name mode
  NameCustomColor["HealthbarMode"]["FRIENDLY"] = SettingsName.HealthbarMode.FriendlyTextColor
  NameCustomColor["HealthbarMode"]["HOSTILE"] = SettingsName.HealthbarMode.EnemyTextColor
  NameCustomColor["HealthbarMode"]["NEUTRAL"] = NameCustomColor["HealthbarMode"]["HOSTILE"]

  NameCustomColor["NameMode"]["FRIENDLY"] = SettingsName.NameMode.FriendlyTextColor
  NameCustomColor["NameMode"]["HOSTILE"] = SettingsName.NameMode.EnemyTextColor
  NameCustomColor["NameMode"]["NEUTRAL"] = NameCustomColor["NameMode"]["HOSTILE"]

  ColorByReaction = SettingsBase.ColorByReaction
  ColorByHealth = SettingsBase.ColorByHealth

  NameModeSettings.HealthbarMode.UseTargetColoring = SettingsBase.targetWidget.ModeNames
  NameModeSettings.HealthbarMode.UseFocusColoring = SettingsBase.FocusWidget.ModeNames
  NameModeSettings.HealthbarMode.UseRaidMarkColoring = SettingsName.HealthbarMode.UseRaidMarkColoring
  NameModeSettings.NameMode.UseTargetColoring = SettingsBase.targetWidget.ModeNames
  NameModeSettings.NameMode.UseFocusColoring = SettingsBase.FocusWidget.ModeNames
  NameModeSettings.NameMode.UseRaidMarkColoring = SettingsName.NameMode.UseRaidMarkColoring

  for style, settings in pairs(Addon.db.profile.settings) do
    -- there are several subentries unter settings. Only use style subsettings like unique, normal, dps, ...
    if settings.threatcolor then
      ThreatColor[style] = settings.threatcolor
    end
  end

  -- Subscribe/unsubscribe to events based on settings
  if SettingsBase.threat.useHPColor or SettingsBase.settings.threatborder.show  and
    not (Settings.FriendlyUnitMode == "HEALTH" and Settings.EnemyUnitMode == "HEALTH" and
      SettingsName.HealthbarMode.FriendlyUnitMode == "HEALTH" and SettingsName.HealthbarMode.EnemyUnitMode == "HEALTH" and
      SettingsName.NameMode.FriendlyUnitMode == "HEALTH" and SettingsName.NameMode.EnemyUnitMode == "HEALTH") then
    SubscribeEvent(ColorModule, "ThreatUpdate", CombatUpdate)
  else
    UnsubscribeEvent(ColorModule, "ThreatUpdate")
  end

  local SettingsStatusText = Addon.db.profile.StatusText
  if Settings.FriendlyUnitMode == "HEALTH" or Settings.EnemyUnitMode == "HEALTH" or
    SettingsName.HealthbarMode.FriendlyUnitMode == "HEALTH" or SettingsName.HealthbarMode.EnemyUnitMode == "HEALTH" or
    SettingsName.NameMode.FriendlyUnitMode == "HEALTH" or SettingsName.NameMode.EnemyUnitMode == "HEALTH" or
    SettingsStatusText.HealthbarMode.FriendlySubtext == "HEALTH" or SettingsStatusText.HealthbarMode.EnemySubtext == "HEALTH" or
    SettingsStatusText.NameMode.FriendlySubtext == "HEALTH" or SettingsStatusText.NameMode.EnemySubtext == "HEALTH" then
    
    ColorByHealthIsEnabled = true
    
    if Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC then
      SubscribeEvent(ColorModule, "UNIT_HEALTH_FREQUENT", UNIT_HEALTH)
    else
      SubscribeEvent(ColorModule, "UNIT_HEALTH", UNIT_HEALTH)
    end
  else
    ColorByHealthIsEnabled = false

    if Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC then
      UnsubscribeEvent(ColorModule, "UNIT_HEALTH_FREQUENT", UNIT_HEALTH)
    else
      UnsubscribeEvent(ColorModule, "UNIT_HEALTH", UNIT_HEALTH)
    end
  end

  SubscribeEvent(ColorModule, "TargetGained", SituationalColorUpdate)
  SubscribeEvent(ColorModule, "TargetLost", SituationalColorUpdate)
  SubscribeEvent(ColorModule, "FocusGained", SituationalColorUpdate)
  SubscribeEvent(ColorModule, "FocusLost", SituationalColorUpdate)
  SubscribeEvent(ColorModule, "TargetMarkerUpdate", SituationalColorUpdate)
  SubscribeEvent(ColorModule, "FactionUpdate", FactionUpdate) -- Updates on faction information for units
  SubscribeEvent(ColorModule, "SituationalColorUpdate", SituationalColorUpdate) -- Updates on e.g., quest information or target status for units
  SubscribeEvent(ColorModule, "ClassColorUpdate", ClassColorUpdate) -- Updates on friend/guildmate information for units (part of class info currently)

  --wipe(HealthColorCache)
end

function ColorModule:SetCastbarColor(unit)
	if not unit.unitid then return end

	local db = Addon.db.profile

	local c
	-- Because of this ordering, IsInterrupted must be set to false when a new cast is cast. Otherwise
  -- the interrupt color may be shown for a cast
	if unit.IsInterrupted then
		c = db.castbarColorInterrupted
	elseif unit.spellIsShielded then
		c = db.castbarColorShield
	else
		c = db.castbarColor
	end

	db = db.settings.castbar
	if db.BackgroundUseForegroundColor then
		return c.r, c.g, c.b, c.a, c.r, c.g, c.b, 1 - db.BackgroundOpacity
	else
		local color = db.BackgroundColor
		return c.r, c.g, c.b, c.a, color.r, color.g, color.b, 1 - db.BackgroundOpacity
	end
end