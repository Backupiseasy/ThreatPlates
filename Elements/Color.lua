---------------------------------------------------------------------------------------------------
-- Element: Nameplate Color (for Healthbar & Name)
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local abs, floor, ceil = abs, floor, ceil

-- WoW APIs
local UnitReaction = UnitReaction
local UnitCanAttack = UnitCanAttack
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

-- ThreatPlates APIs
local ThreatPlates = Addon.ThreatPlates
local PlatesByUnit = Addon.PlatesByUnit
local TidyPlatesThreat = TidyPlatesThreat
local SubscribeEvent, PublishEvent,  UnsubscribeEvent = Addon.EventService.Subscribe, Addon.EventService.Publish, Addon.EventService.Unsubscribe
local RGB_P = Addon.RGB_P

local REACTION_REFERENCE = {
  FRIENDLY = { NPC7 = "FriendlyNPC", PLAYER = "FriendlyPlayer", },
  HOSTILE = {	NPC = "HostileNPC", PLAYER = "HostilePlayer", },
  NEUTRAL = { NPC = "NeutralUnit", PLAYER = "NeutralUnit",	},
}

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local SettingsBase, Settings, SettingsName
local ColorByReaction, ColorByHealth
local HealthbarColorFunctions = {}
local NameColorFunctions = {
  HEALTHBAR = {},
  NAME = {},
  NONE = {}, -- If color mode is NONE, the name color function should never been called (as name is not shown)
}
local NameCustomColor = {
  HEALTHBAR = {},
  NAME = {}
}
local TargetMarkColoring = {}

---------------------------------------------------------------------------------------------------
-- ThreatPlates Frame functions to return the current color for healthbar/name based on settings
---------------------------------------------------------------------------------------------------

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

local function GetUnitColorCustomColor(tp_frame)
  local unit = tp_frame.unit

  -- PlateStyle should never be "NONE" here as healthbar and/or name are not shown in this case
  assert (tp_frame.PlateStyle ~= "NONE", "PlateStyle 'NONE' detected in Color.GetUnitColorCustomColor")
  return NameCustomColor[tp_frame.PlateStyle][unit.reaction]
end

local function GetUnitColorCustomPlate(tp_frame)
  local unit = tp_frame.unit
  return unit.SituationalColor or unit.CombatColor or unit.CustomColor
end

local HEALTHBAR_COLOR_MODE_REFERENCE = {
  REACTION = GetUnitColorByReaction,
  CLASS = GetUnitColorByClass,
  HEALTH = GetUnitColorByHealth,
  CUSTOM = GetUnitColorCustomColor,
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

local function GetUnitColorCustomPlateName(tp_frame)
  local unit = tp_frame.unit

  if tp_frame.PlateStyle == "HEALTHBAR" then
    return NameColorFunctions.HEALTHBAR[unit.reaction](tp_frame)
  else
    return unit.SituationalNameColor or unit.CombatColor or unit.CustomColor
  end
end

local NAME_COLOR_MODE_REFERENCE = {
  REACTION = GetUnitColorByReactionName,
  CLASS = GetUnitColorByClassName,
  HEALTH = GetUnitColorByHealthName,
  CUSTOM = GetUnitColorCustomColor,
}

---------------------------------------------------------------------------------------------------
-- Functions to set color for healthbar, name, and status text
---------------------------------------------------------------------------------------------------

local function UpdatePlateColors(tp_frame)
  local fg_color

  if tp_frame.style.healthbar.show then
    fg_color = tp_frame:GetHealthbarColor()

    local bg_color
    if Settings.BackgroundUseForegroundColor then
      bg_color = fg_color
    else
      bg_color = Settings.BackgroundColor
    end

    local healthbar = tp_frame.visual.Healthbar
    healthbar:SetStatusBarColor(fg_color.r, fg_color.g, fg_color.b, 1)
    healthbar.Border:SetBackdropColor(bg_color.r, bg_color.g, bg_color.b, 1 - Settings.BackgroundOpacity)
  end

  if tp_frame.style.name.show then
    fg_color = tp_frame:GetNameColor()

    tp_frame.visual.NameText:SetTextColor(fg_color.r, fg_color.g, fg_color.b)
  end
end

local function UpdateStatusTextColor(tp_frame, fg_color)
  local style = tp_frame.style

  if style.customtext.show then
    local db = TidyPlatesThreat.db.profile
    if style == "NameOnly" or style == "NameOnly-Unique" then
      db = db.HeadlineView
    else
      db = db.settings.customtext
    end

--    local subtext, color = Addon:SetNameColor(unit)
--    if db.SubtextColorUseHeadline then
--      return subtext, Addon:SetNameColor(unit)
--    elseif db.SubtextColorUseSpecific then
--      return subtext, color.r, color.g, color.b, color.a
--    end

    local status_text = tp_frame.visual.StatusText


    local _, r, g, b, a = Addon:SetCustomText(tp_frame.unit)
    status_text:SetTextColor(fg_color.r, fg_color.g, fg_color.b, fg_color.a)
  end
end

---------------------------------------------------------------------------------------------------
-- Color-colculating Functions
---------------------------------------------------------------------------------------------------

local HealthColorCache = {}
local CS = CreateFrame("ColorSelect")

function CS:GetSmudgeColorRGB(colorA, colorB, perc)
  self:SetColorRGB(colorA.r,colorA.g,colorA.b)
  local h1, s1, v1 = self:GetColorHSV()
  self:SetColorRGB(colorB.r,colorB.g,colorB.b)
  local h2, s2, v2 = self:GetColorHSV()
  local h3 = floor(h1-(h1-h2)*perc)
  if abs(h1-h2) > 180 then
    local radius = (360-abs(h1-h2))*perc/100
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
  local s3 = s1-(s1-s2)*perc
  local v3 = v1-(v1-v2)*perc
  self:SetColorHSV(h3, s3, v3)

  return self:GetColorRGB()
end

---------------------------------------------------------------------------------------------------
-- Still to migrate
---------------------------------------------------------------------------------------------------

local function GetColorByHealthDeficit(unit)
  local db = TidyPlatesThreat.db.profile
  local pct = unit.health / unit.healthmax
  local r, g, b = CS:GetSmudgeColorRGB(db.ColorByHealth.Low, db.ColorByHealth.High, pct)
  return RGB_P(r, g, b, 1)
end

ThreatPlates.GetColorByHealthDeficit = GetColorByHealthDeficit

---------------------------------------------------------------------------------------------------
-- Functions to the the base color for a unit
---------------------------------------------------------------------------------------------------

-- Threat System is OP, player is in combat, style is tank or dps
local function GetColorByHealth(unit)
  local health_pct = ceil(100 * (unit.health / unit.healthmax))
  local health_color = HealthColorCache[health_pct]

  if not health_color then
    print ("Cache: ", health_color)
    health_color = RGB_P(CS:GetSmudgeColorRGB(ColorByHealth.Low, ColorByHealth.High, unit.health / unit.healthmax))
    HealthColorCache[health_pct] = health_color
    print ("Color: Adding color for", health_pct, "%: ", health_color.r, health_color.g, health_color.b, " / ", CS:GetSmudgeColorRGB(ColorByHealth.Low, ColorByHealth.High, unit.health / unit.healthmax))
  end

  --color.r, color.g, color.b = CS:GetSmudgeColorRGB(ColorByHealth.Low, ColorByHealth.High, unit.health / unit.healthmax)
  --return color

  unit.HealthColor = health_color
  return health_color
end

local function GetColorByReaction(unit)
  local color

  if unit.isTapped then
    color = ColorByReaction.TappedUnit
  elseif unit.type == "NPC" and not UnitCanAttack("player", unit.unitid) and UnitReaction("player", unit.unitid) == 3 then
    -- 1/2 is same color (red), 4 is neutral (yellow),5-8 is same color (green)
    color = ColorByReaction.UnfriendlyFaction
    --return FACTION_BAR_COLORS[3]
  else
    color = ColorByReaction[REACTION_REFERENCE[unit.reaction][unit.type]]
  end

  unit.ReactionColor = color

  return color
end

local function GetColorByClass(unit)
  local color

  if unit.type == "PLAYER" then
    if unit.reaction == "HOSTILE" then
      color = RAID_CLASS_COLORS[unit.class]
    elseif unit.reaction == "FRIENDLY" then
      local db_social = SettingsBase.socialWidget
      if db_social.ShowFriendColor and Addon:IsFriend(unit) then
        color = db_social.FriendColor
      elseif db_social.ShowGuildmateColor and Addon:IsGuildmate(unit) then
        color = db_social.GuildmateColor
      else
        color = RAID_CLASS_COLORS[unit.class]
      end
    end
  end

  unit.ClassColor = color

  return color
end

local function GetCustomStyleColor(unit)
  local color

  local unique_setting = unit.CustomPlateSettings
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

-- Threat System is OP, player is in combat, style is tank or dps
local function GetCombatColor(unit)
  local db = SettingsBase.threat
  local color

  -- Threat System is should also be used for custom nameplate (in combat with thread system on)
  local unique_setting = unit.CustomPlateSettings
  if unique_setting and not unique_setting.UseThreatColor then
    unit.CombatColor = nil
    return
  end

  if db.useHPColor and Addon:ShowThreatFeedback(unit) then
    local style = (Addon.PlayerRoleIsTank and "tank") or "dps"
    if style == "tank" and db.toggle.OffTank and Addon:UnitIsOffTanked(unit) then
      color = SettingsBase.settings[style].threatcolor["OFFTANK"]
    else
      color = SettingsBase.settings[style].threatcolor[unit.ThreatLevel]
    end
  end

  unit.CombatColor = color

  return color
end

-- Current situational colors are:
--   Target, Target Mark, Quest Target
local function GetSituationalColor(unit)
  local color

  -- Not situational coloring for totems (currently)
  if not unit.TotemSettings then
    if unit.isTarget and SettingsBase.targetWidget.ModeHPBar then
      color = SettingsBase.targetWidget.HPBarColor
    else
      local use_target_mark_color
      if unit.CustomPlateSettings then
        use_target_mark_color = unit.TargetMarker and unit.CustomPlateSettings.allowMarked
      else
        use_target_mark_color = unit.TargetMarker and Settings.UseRaidMarkColoring
      end

      if use_target_mark_color then
        color = SettingsBase.settings.raidicon.hpMarked[unit.TargetMarker]
      elseif Addon:ShowQuestUnit(unit) and Addon:IsPlayerQuestUnit(unit) then
        -- Unit is quest target
        color = SettingsBase.questWidget.HPBarColor
      end
    end
  end

  unit.SituationalColor = color

  return color
end

local function GetSituationalColorName(unit, tp_frame)
  local color

  -- Not situational coloring for totems (currently)
  if not unit.TotemSettings then
    if unit.isTarget and SettingsBase.targetWidget.ModeNames then
      color = SettingsBase.targetWidget.HPBarColor
    else
      local use_target_mark_color
      if unit.CustomPlateSettings then
        use_target_mark_color = unit.TargetMarker and unit.CustomPlateSettings.allowMarked
      else
        use_target_mark_color = unit.TargetMarker and TargetMarkColoring[tp_frame.PlateStyle]
      end

      if use_target_mark_color then
        color = SettingsBase.settings.raidicon.hpMarked[unit.TargetMarker]
      elseif Addon:ShowQuestUnit(unit) and Addon:IsPlayerQuestUnit(unit) then
        -- Unit is quest target
        color = SettingsBase.questWidget.HPBarColor
      end
    end
  end

  unit.SituationalNameColor = color

  return color
end

---------------------------------------------------------------------------------------------------
-- Element code for Healthbar Color
---------------------------------------------------------------------------------------------------

local Element = Addon.Elements.NewElement("Color")

---------------------------------------------------------------------------------------------------
-- Core element code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function Element.UnitAdded(tp_frame)
  local unit = tp_frame.unit

  GetSituationalColor(unit)
  GetSituationalColorName(unit, tp_frame)

  -- Not sure if this checks are 100% correct, might be just easier to initialize all colors anyway
  if tp_frame.GetHealthbarColor == GetUnitColorByHealth or tp_frame.GetNameColor == GetUnitColorByHealth or unit.CustomColor then
    GetColorByHealth(unit)
  end

  if not (tp_frame.GetHealthbarColor == GetUnitColorByHealth and tp_frame.GetNameColor == GetUnitColorByHealth) then
    GetColorByReaction(unit)
    GetColorByClass(unit)
  end

  UpdatePlateColors(tp_frame)
end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.UnitRemoved(tp_frame)
--end

-- Called in processing event: UpdateStyle in Nameplate.lua
function Element.UpdateStyle(tp_frame, style)
  local unit = tp_frame.unit

  local color = GetCustomStyleColor(unit)
  if color then
--    if tp_frame.PlateStyle == "HEALTHBAR" then
--      tp_frame.GetHealthbarColor = GetUnitColorCustomPlate
--      tp_frame.GetNameColor = NameColorFunctions[tp_frame.PlateStyle][unit.reaction]
--    else
--      tp_frame.GetHealthbarColor = GetUnitColorCustomPlate -- does not matter
--      tp_frame.GetNameColor = GetUnitColorCustomPlate
--    end
    tp_frame.GetHealthbarColor = GetUnitColorCustomPlate
    tp_frame.GetNameColor = GetUnitColorCustomPlateName
  else
    tp_frame.GetHealthbarColor = HealthbarColorFunctions[unit.reaction]
    tp_frame.GetNameColor = NameColorFunctions[tp_frame.PlateStyle][unit.reaction]
  end
end

local function UNIT_HEALTH(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    print ("Color - UNIT_HEALTH:", unitid)

    GetColorByHealth(tp_frame.unit)
    UpdatePlateColors(tp_frame)
  end
end

local function SituationalUpdate(tp_frame)
--  print ("Unit:", unit.name)
--  local r, g, b, a = tp_frame.visual.Healthbar:GetStatusBarColor()
--  print ("  - Healthbar:", r, g, b, a)
--  r, g, b, a = tp_frame.visual.Healthbar.Border:GetBackdropColor()
--  print ("  - Background:", r, g, b, a)
--  r, g, b, a = tp_frame.visual.Healthbar.Absorbs:GetVertexColor()
--  print ("  - Healthbar Absorbs:", r, g, b, a)
--
  GetSituationalColor(tp_frame.unit)
  GetSituationalColorName(tp_frame.unit, tp_frame)
  UpdatePlateColors(tp_frame)

  print ("Color - Situational Update:", tp_frame.unit.name .. "(" .. tp_frame.unit.unitid .. ") =>", tp_frame.unit.SituationalColor)
end

local function CombatUpdate(tp_frame)
  GetCombatColor(tp_frame.unit)
  UpdatePlateColors(tp_frame)

  print ("Color - CombatUpdate:", tp_frame.unit.name .. "(" .. tp_frame.unit.unitid .. ") =>", tp_frame.unit.ThreatLevel)
end

local function FactionUpdate(tp_frame)
  local unit = tp_frame.unit

  -- Only update faction if not a custom nameplate with custom color or mode ~= "HEALTH"
  -- not unit.CustomColor and
  if not (tp_frame.GetHealthbarColor == GetUnitColorByHealth and tp_frame.GetNameColor == GetUnitColorByHealth) then
    GetColorByReaction(unit)
    UpdatePlateColors(tp_frame)

    print ("Color - ReactionUpdate:", tp_frame.unit.unitid)
  end
end

function Element.UpdateSettings()
  SettingsBase = TidyPlatesThreat.db.profile
  Settings = SettingsBase.Healthbar
  SettingsName = SettingsBase.Name

  --  Functions to calculate the healthbar/name color for a unit based
  HealthbarColorFunctions["FRIENDLY"] = HEALTHBAR_COLOR_MODE_REFERENCE[Settings.FriendlyUnitMode]
  HealthbarColorFunctions["HOSTILE"] = HEALTHBAR_COLOR_MODE_REFERENCE[Settings.EnemyUnitMode]
  HealthbarColorFunctions["NEUTRAL"] = HealthbarColorFunctions["HOSTILE"]

  NameColorFunctions["HEALTHBAR"]["FRIENDLY"] = NAME_COLOR_MODE_REFERENCE[SettingsName.HealthbarMode.FriendlyUnitMode]
  NameColorFunctions["HEALTHBAR"]["HOSTILE"] = NAME_COLOR_MODE_REFERENCE[SettingsName.HealthbarMode.EnemyUnitMode]
  NameColorFunctions["HEALTHBAR"]["NEUTRAL"] = NameColorFunctions["HEALTHBAR"]["HOSTILE"]

  NameColorFunctions["NAME"]["FRIENDLY"] = NAME_COLOR_MODE_REFERENCE[SettingsName.NameMode.FriendlyUnitMode]
  NameColorFunctions["NAME"]["HOSTILE"] = NAME_COLOR_MODE_REFERENCE[SettingsName.NameMode.EnemyUnitMode]
  NameColorFunctions["NAME"]["NEUTRAL"] = NameColorFunctions["NAME"]["HOSTILE"]

  --  Custom color for Name text in healthbar and name mode
  NameCustomColor["HEALTHBAR"]["FRIENDLY"] = SettingsName.HealthbarMode.FriendlyTextColor
  NameCustomColor["HEALTHBAR"]["HOSTILE"] = SettingsName.HealthbarMode.EnemyTextColor
  NameCustomColor["HEALTHBAR"]["NEUTRAL"] = NameCustomColor["HEALTHBAR"]["NEUTRAL"]

  NameCustomColor["NAME"]["FRIENDLY"] = SettingsName.NameMode.FriendlyTextColor
  NameCustomColor["NAME"]["HOSTILE"] = SettingsName.NameMode.EnemyTextColor
  NameCustomColor["NAME"]["NEUTRAL"] = NameCustomColor["NAME"]["NEUTRAL"]

  ColorByReaction = SettingsBase.ColorByReaction
  ColorByHealth = SettingsBase.ColorByHealth

  TargetMarkColoring["HEALTHBAR"] = SettingsName.HealthbarMode.UseRaidMarkColoring
  TargetMarkColoring["NAME"] = SettingsName.NameMode.UseRaidMarkColoring

  -- Subscribe/unsubscribe to events based on settings
  if SettingsBase.threat.ON and SettingsBase.threat.useHPColor and
    not (Settings.FriendlyUnitMode == "HEALTH" and Settings.EnemyUnitMode == "HEALTH" and
      SettingsName.HealthbarMode.FriendlyUnitMode == "HEALTH" and SettingsName.HealthbarMode.EnemyUnitMode == "HEALTH" and
      SettingsName.NameMode.FriendlyUnitMode == "HEALTH" and SettingsName.NameMode.EnemyUnitMode == "HEALTH") then
    SubscribeEvent(Element, "ThreatUpdate", CombatUpdate)
  else
    UnsubscribeEvent(Element, "ThreatUpdate")
  end

  if Settings.FriendlyUnitMode == "HEALTH" or Settings.EnemyUnitMode == "HEALTH" or
    SettingsName.HealthbarMode.FriendlyUnitMode == "HEALTH" or SettingsName.HealthbarMode.EnemyUnitMode == "HEALTH" or
    SettingsName.NameMode.FriendlyUnitMode == "HEALTH" or SettingsName.NameMode.EnemyUnitMode == "HEALTH" then
    SubscribeEvent(Element, "UNIT_HEALTH", UNIT_HEALTH)
  else
    UnsubscribeEvent(Element, "UNIT_HEALTH", UNIT_HEALTH)
  end

  --SubscribeEvent(Element, "UNIT_HEALTH_FREQUENT", UNIT_HEALTH_FREQUENT)
  SubscribeEvent(Element, "TargetGained", SituationalUpdate)
  SubscribeEvent(Element, "TargetLost", SituationalUpdate)
  SubscribeEvent(Element, "TargetMarkerUpdate", SituationalUpdate)
  SubscribeEvent(Element, "FactionUpdate", FactionUpdate) -- Updates on faction (including social) information for units
  SubscribeEvent(Element, "QuestUpdate", SituationalUpdate) -- Updates on quests information for units

  print ("Wiping HealthColorCache")
  wipe(HealthColorCache)
end