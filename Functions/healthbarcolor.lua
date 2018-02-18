local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local floor = floor
local abs = abs

-- WoW APIs
local UnitIsConnected = UnitIsConnected
local UnitIsUnit = UnitIsUnit
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitReaction = UnitReaction
local UnitCanAttack = UnitCanAttack
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local FACTION_BAR_COLORS = FACTION_BAR_COLORS

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local GetUniqueNameplateSetting = ThreatPlates.GetUniqueNameplateSetting
local TOTEMS = Addon.TOTEMS
local OnThreatTable = ThreatPlates.OnThreatTable
local RGB_P = ThreatPlates.RGB_P
local IsFriend
local IsGuildmate
local ShowQuestUnit
local IsQuestUnit
local GetThreatStyle

local reference = {
  FRIENDLY = { NPC = "FriendlyNPC", PLAYER = "FriendlyPlayer", },
  HOSTILE = {	NPC = "HostileNPC", PLAYER = "HostilePlayer", },
  NEUTRAL = { NPC = "NeutralUnit", PLAYER = "NeutralUnit",	},
}

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
    local r,g,b = self:GetColorRGB()
    return r,g,b
end


local function UnitIsOffTanked(unit)
  local targetOf = unit.unitid.."target"
  local targetIsTank = UnitIsUnit(targetOf, "pet") or ("TANK" == UnitGroupRolesAssigned(targetOf))

  if targetIsTank and unit.threatValue < 2 then
    return true
  end

  return false
end

-- Threat System is OP, player is in combat, style is tank or dps
local function GetThreatColor(unit, style)
  local db = TidyPlatesThreat.db.profile
  local c

  if (db.threat.ON and db.threat.useHPColor and (style == "dps" or style == "tank")) then
    local show_offtank = db.threat.toggle.OffTank

    if db.threat.nonCombat then
      if OnThreatTable(unit) then
        local threatSituation = unit.threatSituation
        if style == "tank" and show_offtank and UnitIsOffTanked(unit) then
          threatSituation = "OFFTANK"
        end
        c = db.settings[style].threatcolor[threatSituation]
      end
    else
      local threatSituation = unit.threatSituation
      if style == "tank" and show_offtank and UnitIsOffTanked(unit) then
        threatSituation = "OFFTANK"
      end
      c = db.settings[style].threatcolor[threatSituation]
    end
  end

  return c
end

local function GetColorByHealthDeficit(unit)
  local db = TidyPlatesThreat.db.profile
  local pct = unit.health / unit.healthmax
  local r, g, b = CS:GetSmudgeColorRGB(db.aHPbarColor, db.bHPbarColor, pct)
  return RGB_P(r, g, b, 1)
end

local function GetColorByClass(unit)
  local db = TidyPlatesThreat.db.profile

  local c
  if unit.type == "PLAYER" then
    if unit.reaction == "HOSTILE" and db.allowClass then
      c = RAID_CLASS_COLORS[unit.class]
    elseif unit.reaction == "FRIENDLY" then
      local db_social = db.socialWidget
      if db_social.ShowFriendColor and IsFriend(unit) then
        c = db_social.FriendColor
      elseif db_social.ShowGuildmateColor and IsGuildmate(unit) then
        c = db_social.GuildmateColor
      elseif db.friendlyClass then
        c = RAID_CLASS_COLORS[unit.class]
      end
    end
  end

  return c
end

local function GetColorByReaction(unit)
  local db = TidyPlatesThreat.db.profile.ColorByReaction

  if unit.type == "NPC" and not UnitCanAttack("player", unit.unitid) and UnitReaction("player", unit.unitid) == 3 then
    -- 1/2 is same color (red), 4 is neutral (yellow),5-8 is same color (green)
    return db.UnfriendlyFaction
    --return FACTION_BAR_COLORS[3]
  end

  return db[reference[unit.reaction][unit.type]]
end

--local function GetColorByReaction(unit)
--  local db = TidyPlatesThreat.db.profile
--  local db_color = db.ColorByReaction
--
--  local color
--  if not UnitIsConnected(unit.unitid) then
--    color =  db_color.DisconnectedUnit
--  elseif unit.isTapped then
--    color =  db_color.TappedUnit
--  elseif unit.reaction == "FRIENDLY" and unit.type == "PLAYER" then
--    IsFriend = IsFriend or ThreatPlates.IsFriend
--    IsGuildmate = IsGuildmate or ThreatPlates.IsGuildmate
--
--    local db_social = db.socialWidget
--    if db_social.ShowFriendColor and IsFriend(unit) then
--      color =  db_social.FriendColor
--    elseif db_social.ShowGuildmateColor and IsGuildmate(unit) then
--      color =  db_social.GuildmateColor
--    else
--      -- wrong: next elseif missing here color = db_color[reference[unit.reaction][unit.type]]
--    end
--  elseif unit.type == "NPC" and not UnitCanAttack("player", unit.unitid) and UnitReaction("player", unit.unitid) == 3 then
--    -- 1/2 is same color (red), 4 is neutral (yellow),5-8 is same color (green)
--    color = FACTION_BAR_COLORS[3]
--  else
--    color = db_color[reference[unit.reaction][unit.type]]
--  end
--
--  return color
--end

--local HEALTHBAR_COLOR_FUNCTIONS = {
--  --  NameOnly = nil,
--  --  empty = nil,
--  --  etotem = nil,
--  unique = UniqueHealthbarColor,
--  totem = TotemHealthbarColor,
--  normal = DefaultHealthbarColor,
--  tank = ThreatHealthbarColor,
--  dps = ThreatHealthbarColor,
--}

function Addon:SetHealthbarColor(unit)
  if not unit.unitid then return end

  local style = unit.TP_Style or Addon:SetStyle(unit)
  local unique_setting = unit.TP_UniqueSetting or GetUniqueNameplateSetting(unit)
  if style == "NameOnly" or style == "NameOnly-Unique" or style == "empty" or style == "etotem" then return end

  ShowQuestUnit = ShowQuestUnit or ThreatPlates.ShowQuestUnit
  IsQuestUnit = IsQuestUnit or ThreatPlates.IsQuestUnit
  GetThreatStyle = GetThreatStyle or ThreatPlates.GetThreatStyle
  IsFriend = IsFriend or ThreatPlates.IsFriend
  IsGuildmate = IsGuildmate or ThreatPlates.IsGuildmate

  local db = TidyPlatesThreat.db.profile
  local db_color = db.ColorByReaction

  local c
  if unit.isTarget and db.targetWidget.ModeHPBar then
    c = db.targetWidget.HPBarColor
  elseif style == "unique" then
    -- Custom nameplate style defined for unit (does not work for totems right now)
    if unit.isMarked and unique_setting.allowMarked then
      -- Unit is marked
      local db_raidicon = db.settings.raidicon
      c = db_raidicon.hpMarked[unit.raidIcon]
    elseif ShowQuestUnit(unit) and IsQuestUnit(unit) then
      -- Unit is quest target
      c = db.questWidget.HPBarColor
    else
      if not UnitIsConnected(unit.unitid) then
        c = db_color.DisconnectedUnit
      elseif unit.isTapped then
        c = db_color.TappedUnit
      elseif unique_setting.UseThreatColor then
        -- Threat System is should also be used for custom nameplate (in combat with thread system on)
        c = GetThreatColor(unit, GetThreatStyle(unit))
      end

      if not c and unique_setting.useColor then
        c = unique_setting.color
      end

      -- otherwise color defaults to class or reaction color (or WoW defaults, at the end)
      if not c then
        c = GetColorByClass(unit)
      end
      if not c then
        c = GetColorByReaction(unit)
      end
    end
  elseif style == "totem" then
    -- currently, no raid marked color (or quest color) for totems, also no custom nameplates
    local tS = db.totemSettings[TOTEMS[unit.name]]
    if tS.ShowHPColor then
      c = tS.Color
    end
    -- otherwise color defaults to WoW defaults
  else
    -- branch for standard coloring (ByHealth or ByClass, ByReaction, ByThreat), style = normal, tank, dps
    -- (healthbar disabled for empty, etotem, NameOnly)
    local db_raidicon = db.settings.raidicon
    if unit.isMarked and db_raidicon.hpColor then
      c = db_raidicon.hpMarked[unit.raidIcon]
    elseif ShowQuestUnit(unit) and IsQuestUnit(unit) then
      -- small bug here: tapped targets should not be quest marked!
      c = db.questWidget.HPBarColor
    elseif db.healthColorChange then
      c = GetColorByHealthDeficit(unit)
    else
      -- order is ThreatSystem, ByClass, ByReaction, WoW Default
      if not UnitIsConnected(unit.unitid) then
        c = db_color.DisconnectedUnit
      elseif unit.isTapped then
        c = db_color.TappedUnit
      else
        c = GetThreatColor(unit, style)
      end

      if not c then
        c = GetColorByClass(unit)
      end

      if not c then
        c = GetColorByReaction(unit)
      end
    end
  end

  -- if no color was found, default back to WoW default colors (based on GetSelectionColor)
  local color_r, color_g, color_b
  if c then
    color_r, color_g, color_b = c.r, c.g, c.b
  else
    color_r, color_g, color_b = unit.red, unit.green, unit.blue
  end

  -- set background color for healthbar
  local db_healthbar = db.settings.healthbar
  local color_bg_r, color_bg_g, color_bg_b, bg_alpha
  if db_healthbar.BackgroundUseForegroundColor then
    color_bg_r, color_bg_g, color_bg_b, bg_alpha = color_r, color_g, color_b, 1 - db_healthbar.BackgroundOpacity
  else
    local color = db_healthbar.BackgroundColor
    color_bg_r, color_bg_g, color_bg_b, bg_alpha = color.r, color.g, color.b, 1 - db_healthbar.BackgroundOpacity
  end

  return color_r, color_g, color_b, nil, color_bg_r, color_bg_g, color_bg_b, bg_alpha
end

ThreatPlates.GetColorByHealthDeficit = GetColorByHealthDeficit
ThreatPlates.GetColorByClass = GetColorByClass
ThreatPlates.GetColorByReaction = GetColorByReaction
ThreatPlates.UnitIsOffTanked = UnitIsOffTanked