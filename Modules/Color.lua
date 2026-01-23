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
local StyleModule = Addon.Style
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
-- Constants
---------------------------------------------------------------------------------------------------

local TRANSPARENT_COLOR = Addon.RGB(0, 0, 0, 0)
local MIDNIGHT_HEALTH_COLOR_WRAPPER = Addon.RGB(1, 1, 1)

---------------------------------------------------------------------------------------------------
-- Cached configuration settings (for performance reasons)
---------------------------------------------------------------------------------------------------
local ColorByHealthIsEnabled = false
local SettingsBase, Settings, SettingsName
local ColorByReaction, ColorByHealth
local HealthbarColorFunctions = {}
local NameCustomColor = {
  HealthbarMode = {},
  NameMode = {}
}
local ThreatColor = {}
local NameColorFunctions = {
  HealthbarMode = {},
  NameMode = {},
}
local NameModeSettings = {
  HealthbarMode = {},
  NameMode = {},
}

---------------------------------------------------------------------------------------------------
-- Color by health
---------------------------------------------------------------------------------------------------

local HealthColorCache = {}
local CS = CreateFrame("ColorSelect")
local HealthColorCurve

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
-- Color by unit reaction 
---------------------------------------------------------------------------------------------------

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

local function GetColorByReaction(unit)
  -- PvP coloring based on: https://wowpedia.fandom.com/wiki/PvP_flag
  -- Coloring for pets is the same as for the player controlling the pet
  local unit_type = (UnitPlayerControlled(unit.unitid) and "PLAYER") or unit.type
  
  local color
  -- * For players and their pets
  if unit_type == "PLAYER" then
    if ColorByReaction.IgnorePvPStatus or Addon.IsInPvPInstance then
      color = (unit.reaction == "HOSTILE" and ColorByReaction.HostilePlayer) or ColorByReaction.FriendlyPlayer
    else
      local unit_is_pvp = UnitIsPVP(unit.unitid) or false
      local player_is_pvp = UnitIsPVP("player") or false
      color = ColorByReaction[UNIT_COLOR_MAP[unit.reaction][unit_type][unit_is_pvp][player_is_pvp]]
    end
  -- * From here: For NPCs (without pets)
  elseif unit.blue < 0.1 and unit.green > 0.5 and unit.green < 0.6 and unit.red > 0.9 then
    -- Unfriendly NPCs are shown with a brown healthbar color. 
    -- These NPCs can have a UnitReaction of 3 (neutral) or 4 (hostile), e.g., Addled Enforcer in The Ringing Deeps.
    -- Checking for UnitReaction("player", unit.unitid) == 3 will not work reliably.
    -- Before TWW, I thought that only non-attackable units are shown in brown, but in TWW there are now 
    -- also attackable unfriendly NPCs with brown healthbars. 
    color = ColorByReaction.UnfriendlyFaction
  else
    color = ColorByReaction[UNIT_COLOR_MAP[unit.reaction][unit_type]]
  end

  return color
end

if Addon.ExpansionIsAtLeastMidnight then
  ColorModule.GetColorByHealthDeficit = function(unit)
    return UnitHealthPercent(unit.unitid, true, HealthColorCurve)
  end
else
  ColorModule.GetColorByHealthDeficit = function(unit)
    local health_pct = ceil(100 * unit.health / unit.healthmax)

    local color = HealthColorCache[health_pct]
    if not color then
      color = RGB_P(CS:GetSmudgeColorRGB(ColorByHealth.Low, ColorByHealth.High, health_pct))
      HealthColorCache[health_pct] = color
    end

    return color
  end
end

-- Works as all functions using this function are triggerd by the NameColorChanged event
local GetColorByHealth = ColorModule.GetColorByHealthDeficit

---------------------------------------------------------------------------------------------------
-- Color by class
---------------------------------------------------------------------------------------------------

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

  return color
end

---------------------------------------------------------------------------------------------------
-- Color for custom styles
---------------------------------------------------------------------------------------------------

local function GetCustomStyleColor(unit)
  local color

  --  -- Threat System is should also be used for custom nameplate (in combat with thread system on)
  --  if unique_setting and not unique_setting.UseThreatColor then
  --    unit.CombatColor = nil
  --    return nil
  --  end
  
  local unique_setting = unit.CustomPlateSettings
  if unique_setting and unique_setting.useColor then
    color = unique_setting.color
  else
    local totem_settings = unit.TotemSettings
    if totem_settings and totem_settings.ShowHPColor then
      color = totem_settings.Color
    end
  end

  return color
end

---------------------------------------------------------------------------------------------------
-- Color by threat
---------------------------------------------------------------------------------------------------

-- Threat System is OP, player is in combat, style is tank or dps
local function GetCombatColor(unit)
  -- For styles normal, totem, empty, no threat feedback i shown
  -- Style custom is handled by the part below
  local style = (unit.CustomPlateSettings and StyleModule.GetThreatStyle(unit)) or unit.style

  local color
  if style == "dps" or style == "tank" then
    color = ThreatColor[style][unit.ThreatLevel]
  end

  return color
end

ColorModule.GetThreatColor = GetCombatColor

---------------------------------------------------------------------------------------------------
-- Color by situation
---------------------------------------------------------------------------------------------------

---- Sitational Color - Order is: target, target marked, tapped, quest)
local function GetSituationalColorForHealthbar(unit, plate_style)
  -- Not situational coloring for totems (currently)
  if unit.TotemSettings then return end

  local color
  -- NameModeSettings.HealthbarMode.UseTargetColoring = SettingsBase.targetWidget.ModeHPBar
  if unit.isTarget and SettingsBase.targetWidget.ModeHPBar then
    color = SettingsBase.targetWidget.HPBarColor
  elseif unit.IsFocus and SettingsBase.FocusWidget.ModeHPBar then
    color = SettingsBase.FocusWidget.HPBarColor
  else
    local use_target_mark_color
    if not Addon.ExpansionIsAtLeastMidnight and unit.TargetMarkerIcon then
      if unit.CustomPlateSettings then
        use_target_mark_color = unit.CustomPlateSettings.allowMarked
      else
        use_target_mark_color = Settings.UseRaidMarkColoring
      end
    end

    if use_target_mark_color then
      color = SettingsBase.settings.raidicon.hpMarked[unit.TargetMarkerIcon]
    elseif unit.IsTapDenied then
      color = ColorByReaction.TappedUnit
    elseif Addon.ShowQuestUnit(unit) and Addon:IsPlayerQuestUnit(unit) then
      color = SettingsBase.questWidget.HPBarColor
    end
  end

  return color
end

-- Sitational Color - Order is: target, target marked, tapped, quest)
local function GetSituationalColorForName(unit, plate_style)
  -- Not situational coloring for totems (currently)
  if unit.TotemSettings then return end

  local color
  if unit.isTarget and SettingsBase.targetWidget.ModeNames then
    color = SettingsBase.targetWidget.HPBarColor
  elseif unit.IsFocus and SettingsBase.FocusWidget.ModeNames then
    color = SettingsBase.FocusWidget.HPBarColor
  else
    local use_target_mark_color
    if not Addon.ExpansionIsAtLeastMidnight and unit.TargetMarkerIcon then
      if unit.CustomPlateSettings then
        use_target_mark_color = unit.CustomPlateSettings.allowMarked
      else
        use_target_mark_color = SettingsName[plate_style].UseRaidMarkColoring
      end
    end

    if use_target_mark_color then
      color = SettingsBase.settings.raidicon.hpMarked[unit.TargetMarkerIcon]
    elseif unit.IsTapDenied and plate_style == "NameMode" then
      color = ColorByReaction.TappedUnit
    end
  end

  return color
end

---------------------------------------------------------------------------------------------------
-- ThreatPlates Frame functions to return the current color for healthbar/name based on settings
---------------------------------------------------------------------------------------------------

local function GetUnitColorByCustomStyle(unit)
  local unique_setting = unit.CustomPlateSettings
  return (unique_setting and unique_setting.UseThreatColor and GetCombatColor(unit)) or GetCustomStyleColor(unit)
end

local function GetUnitColorByHealth(tp_frame)
  local unit = tp_frame.unit
  return GetSituationalColorForHealthbar(unit, tp_frame.PlateStyle) or GetColorByHealth(unit)
end

local function GetUnitColorByReaction(tp_frame)
  local unit = tp_frame.unit
  return GetSituationalColorForHealthbar(unit, tp_frame.PlateStyle) or GetCombatColor(unit) or GetColorByReaction(unit)
end

local function GetUnitColorByClass(tp_frame)
  local unit = tp_frame.unit
  local plate_style = tp_frame.PlateStyle
  return GetSituationalColorForHealthbar(unit, plate_style) or GetCombatColor(unit) or GetColorByClass(unit, plate_style) or GetColorByReaction(unit)
end

local function GetUnitColorCustomPlate(tp_frame)
  local unit = tp_frame.unit
  return GetSituationalColorForHealthbar(unit, tp_frame.PlateStyle) or GetUnitColorByCustomStyle(unit)
end

local HEALTHBAR_COLOR_FUNCTIONS = {
  REACTION = GetUnitColorByReaction,
  CLASS = GetUnitColorByClass,
  HEALTH = GetUnitColorByHealth,
}

local function GetUnitColorByHealthName(tp_frame)
  local unit = tp_frame.unit
  return GetSituationalColorForName(unit, tp_frame.PlateStyle) or GetColorByHealth(unit)
end

local function GetUnitColorByReactionName(tp_frame)
  local unit = tp_frame.unit
  return GetSituationalColorForName(unit, tp_frame.PlateStyle) or GetCombatColor(unit) or GetColorByReaction(unit)
end

local function GetUnitColorByClassName(tp_frame)
  local unit = tp_frame.unit
  local plate_style = tp_frame.PlateStyle
  return GetSituationalColorForName(unit, plate_style) or GetCombatColor(unit) or GetColorByClass(unit, plate_style) or GetColorByReaction(unit)
end

local function GetUnitColorCustomColorName(tp_frame)
  local unit = tp_frame.unit
  return GetSituationalColorForName(unit, tp_frame.PlateStyle) or NameCustomColor[tp_frame.PlateStyle][unit.reaction]
end

local function GetUnitColorCustomPlateName(tp_frame)
  local unit = tp_frame.unit

  if tp_frame.PlateStyle == "HealthbarMode" then
    return NameColorFunctions.HealthbarMode[unit.reaction](tp_frame)
  else
    return GetSituationalColorForName(unit, tp_frame.PlateStyle) or GetUnitColorByCustomStyle(unit)
  end
end

local NAME_COLOR_FUNCTIONS = {
  REACTION = GetUnitColorByReactionName,
  CLASS = GetUnitColorByClassName,
  HEALTH = GetUnitColorByHealthName,
  CUSTOM = GetUnitColorCustomColorName,
}

---------------------------------------------------------------------------------------------------
-- Core module code
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Functions to set color for healthbar, name, and status text
---------------------------------------------------------------------------------------------------

local function UpdatePlateColors(tp_frame)
  -- When a nameplate is initalized, colors (e.g., unit.ReactionColor) are not yet defined, so GetHealthbarColor
  -- returns nil
  -- local color = tp_frame:GetHealthbarColor() or TRANPARENT_COLOR

  -- local healthbar = tp_frame.visual.Healthbar
  -- healthbar:SetStatusBarColor(color.r, color.g, color.b, 1)
  -- if not Settings.BackgroundUseForegroundColor then
  --   color = Settings.BackgroundColor
  -- end
  -- healthbar.Background:SetVertexColor(color.r, color.g, color.b, 1 - Settings.BackgroundOpacity)

  -- color = tp_frame:GetNameColor() or TRANPARENT_COLOR
  -- if SettingsName[tp_frame.PlateStyle].Enabled then
  --   tp_frame.visual.NameText:SetTextColor(color.r, color.g, color.b, color.a)
  -- end

  -- When a nameplate is initalized, colors (e.g., unit.ReactionColor) are not yet defined, so GetHealthbarColor
  -- returns nil
  tp_frame.HealthbarColor = tp_frame:GetHealthbarColor() or TRANSPARENT_COLOR
  PublishEvent("HealthbarColorUpdate", tp_frame, tp_frame.HealthbarColor)

  tp_frame.NameColor = tp_frame:GetNameColor() or TRANSPARENT_COLOR
  PublishEvent("NameColorUpdate", tp_frame, tp_frame.NameColor)
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
-- function ColorModule.PlateUnitAdded(tp_frame)
--   if tp_frame.PlateStyle == "None" then return end
  
--   UpdatePlateColors(tp_frame)
-- end

-- Called in processing event: UpdateStyle in Nameplate.lua
function ColorModule.UpdateStyle(tp_frame, style)
  if tp_frame.PlateStyle == "None" then return end

  local unit = tp_frame.unit

  local unique_setting = unit.CustomPlateSettings
  local totem_settings = unit.TotemSettings

  if (unique_setting and unique_setting.useColor) or (totem_settings and totem_settings.ShowHPColor) then
    tp_frame.GetHealthbarColor = GetUnitColorCustomPlate
    tp_frame.GetNameColor = GetUnitColorCustomPlateName
  else
    tp_frame.GetHealthbarColor = HealthbarColorFunctions[unit.reaction]
    tp_frame.GetNameColor = NameColorFunctions[tp_frame.PlateStyle][unit.reaction]
  end

  UpdatePlateColors(tp_frame)
end

local function UNIT_HEALTH(unitid)
  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame and tp_frame.PlateStyle ~= "None" then
    UpdatePlateColors(tp_frame)
  end
end

local function ThreatUpdate(tp_frame)
  if tp_frame.PlateStyle == "None" then return end

  UpdatePlateColors(tp_frame)
end

local function IsColorByHealth(tp_frame)
  return tp_frame.GetHealthbarColor == GetUnitColorByHealth and tp_frame.GetNameColor == GetUnitColorByHealth
end

local function FactionUpdate(tp_frame)
  if tp_frame.PlateStyle == "None" or IsColorByHealth(tp_frame) then return end

  -- Only update reaction color if color mode ~= "HEALTH" for healthbar and name
  UpdatePlateColors(tp_frame)
end

local function SituationalColorUpdate(tp_frame)
  if tp_frame.PlateStyle == "None" then return end

  UpdatePlateColors(tp_frame)
end

local function ClassColorUpdate(tp_frame)
  if tp_frame.PlateStyle == "None" or IsColorByHealth(tp_frame) then return end

  -- Only update reaction color if color mode ~= "HEALTH" for healthbar and name
  -- No tapped unit detection necessary as this event only fires for player nameplates (which cannot be tapped, I hope)
  UpdatePlateColors(tp_frame)
end

function ColorModule.UpdateSettings()
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
  -- Initialize the ColorCurve for health-based coloring (retail/Midnight)
  if Addon.ExpansionIsAtLeastMidnight then
    HealthColorCurve = C_CurveUtil.CreateColorCurve()
    HealthColorCurve:AddPoint(0.0, CreateColor(ColorByHealth.Low.r, ColorByHealth.Low.g, ColorByHealth.Low.b))
    HealthColorCurve:AddPoint(1.0, CreateColor(ColorByHealth.High.r, ColorByHealth.High.g, ColorByHealth.High.b))
  end

  HealthColorCache = {}

  -- NameModeSettings.HealthbarMode.UseTargetColoring = SettingsBase.targetWidget.ModeNames
  -- NameModeSettings.HealthbarMode.UseFocusColoring = SettingsBase.FocusWidget.ModeNames
  -- NameModeSettings.HealthbarMode.UseRaidMarkColoring = SettingsName.HealthbarMode.UseRaidMarkColoring
  -- NameModeSettings.NameMode.UseTargetColoring = SettingsBase.targetWidget.ModeNames
  -- NameModeSettings.NameMode.UseFocusColoring = SettingsBase.FocusWidget.ModeNames
  -- NameModeSettings.NameMode.UseRaidMarkColoring = SettingsName.NameMode.UseRaidMarkColoring

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
    SubscribeEvent(ColorModule, "ThreatUpdate", ThreatUpdate)
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

    if Addon.IS_MAINLINE then
      UnsubscribeEvent(ColorModule, "UNIT_HEALTH", UNIT_HEALTH)
    else
      UnsubscribeEvent(ColorModule, "UNIT_HEALTH_FREQUENT", UNIT_HEALTH)
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

function ColorModule.SetCastbarColor(unit)
	if not unit.unitid then return end

	local db = Addon.db.profile

	local c
	-- Because of this ordering, IsInterrupted must be set to false when a new cast is cast. Otherwise
  -- the interrupt color may be shown for a cast
	if unit.IsInterrupted then
		c = db.castbarColorInterrupted
	-- elseif unit.spellIsShielded then
	-- 	c = db.castbarColorShield
	else
		c = db.castbarColor
	end

	db = db.settings.castbar
	if db.BackgroundUseForegroundColor then
		return c.r, c.g, c.b, c.a, c.r, c.g, c.b, 1 - db.BackgroundOpacity, 0, 0, 0
	else
		local color = db.BackgroundColor
		return c.r, c.g, c.b, c.a, color.r, color.g, color.b, 1 - db.BackgroundOpacity, 0, 0, 0
	end
end

function ColorModule.PrintDebug() 
  local plate = C_NamePlate.GetNamePlateForUnit("target")
  if not plate or not plate.TPFrame then return end

  local tp_frame = plate.TPFrame
  Addon.Logging.Debug("Color Module Settings:")
  Addon.Logging.Debug("  Color:", Addon.Debug:ColorToString(tp_frame:GetHealthbarColor()))
  Addon.Logging.Debug("  Color by Health:", IsColorByHealth(tp_frame))
  Addon.Logging.Debug("  Type:")
  Addon.Logging.Debug("    By Reaction:", Addon.Debug:ColorToString(GetUnitColorByReaction(tp_frame)))
  Addon.Logging.Debug("    By Class:", Addon.Debug:ColorToString(GetUnitColorByClass(tp_frame)))
  Addon.Logging.Debug("    By Health:", Addon.Debug:ColorToString(GetUnitColorByHealth(tp_frame)))
  Addon.Logging.Debug("    By CustomPlate:", Addon.Debug:ColorToString(GetUnitColorCustomPlate(tp_frame)))
  local plate_style, unit = tp_frame.PlateStyle, tp_frame.unit
  Addon.Logging.Debug("  - Situational:", Addon.Debug:ColorToString(GetSituationalColorForHealthbar(unit, plate_style)))
  Addon.Logging.Debug("  - Combat:", Addon.Debug:ColorToString(GetCombatColor(unit, plate_style)))
  Addon.Logging.Debug("  - Class:", Addon.Debug:ColorToString(GetColorByClass(unit, plate_style)))
  Addon.Logging.Debug("  - Reaction:", Addon.Debug:ColorToString(GetColorByReaction(unit, plate_style)))

  UpdatePlateColors(tp_frame)
end