local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local floor = floor
local abs = abs

-- WoW APIs
local UnitIsConnected, UnitCanAttack, UnitIsPVP = UnitIsConnected, UnitCanAttack, UnitIsPVP
local UnitIsPlayer, UnitPlayerControlled = UnitIsPlayer, UnitPlayerControlled
local UnitThreatSituation, UnitIsUnit, UnitExists, UnitGroupRolesAssigned = UnitThreatSituation, UnitIsUnit, UnitExists, UnitGroupRolesAssigned
local IsInInstance = IsInInstance
-- WoW Classic APIs:
local GetPartyAssignment = GetPartyAssignment

-- ThreatPlates APIs
local IsOffTankCreature = Addon.IsOffTankCreature
local TOTEMS = Addon.TOTEMS
local IGNORED_STYLES = Addon.IGNORED_STYLES_WITH_NAMEMODE
local RGB, RGB_P = ThreatPlates.RGB, ThreatPlates.RGB_P
local IsFriend
local IsGuildmate
local ShowQuestUnit

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: UnitAffectingCombat, UnitHealth, UnitHealthMax

---------------------------------------------------------------------------------------------------
-- Wrapper functions for WoW Classic
---------------------------------------------------------------------------------------------------

-- Quest tooltips: not sure since when available
if not Addon.IS_MAINLINE then -- 
  -- UnitGroupRolesAssigned does still not seem to work in Classic
  UnitGroupRolesAssigned = function(target_unit)
    return (GetPartyAssignment("MAINTANK", target_unit) and "TANK") or "NONE"
  end

  -- Quest widget is not available in Classic
  ShowQuestUnit = function(...) return false end
end

---------------------------------------------------------------------------------------------------
--
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

local CS = CreateFrame("ColorSelect")

function CS:GetSmudgeColorRGB(colorA, colorB, perc)
  self:SetColorRGB(colorA.r,colorA.g,colorA.b)
  local h1, s1, v1 = self:GetColorHSV()
  self:SetColorRGB(colorB.r,colorB.g,colorB.b)
  local h2, s2, v2 = self:GetColorHSV()
  local h3 = floor(h1-(h1-h2)*perc)
  if abs(h1-h2) > 180 then
        local radius = (360-abs(h1-h2))*perc
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

local function GetThreatSituation(unit, style, enable_off_tank)
  local threat_status = UnitThreatSituation("player", unit.unitid)

  local threat_situation, other_player_has_aggro
  if threat_status then
    threat_situation = unit.threatSituation
    other_player_has_aggro = (threat_status < 2)
  else
    -- if (IsInInstance() and db.threat.UseHeuristicInInstances) or not db.threat.UseThreatTable then
    -- Should not be necessary here as GetThreatSituation is only called if either a threat table is available
    -- or the heuristic is enabled

    local target_unit = unit.unitid .. "target"
    if UnitExists(target_unit) and not unit.isCasting then
      if UnitIsUnit(target_unit, "player") or UnitIsUnit(target_unit, "vehicle") then
        threat_situation = "HIGH"
      else
        threat_situation = "LOW"
      end

      unit.threatSituation = threat_situation
    else
      threat_situation = unit.threatSituation
    end

    other_player_has_aggro = (threat_situation == "LOW")
  end

  -- Reset "unit.IsOfftanked" if the player is tanking
  if not other_player_has_aggro then
    unit.IsOfftanked = false
  elseif style == "tank" and enable_off_tank and other_player_has_aggro then
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
            -- Reset "unit.IsOfftanked"
            -- Target unit does tank unit, but is not a tank or a tank-like pet/guardian
            unit.IsOfftanked = false
          end
        end
      end
    end

    -- Player does not tank the unit, but it might have been off-tanked before losing target.
    -- If so, assume that it is still securely off-tanked
    if unit.IsOfftanked then
      threat_situation = "OFFTANK"
    end
  end

  return threat_situation
end

function Addon:GetThreatColor(unit, style, use_threat_table)
  local db = Addon.db.profile

  local color

  local on_threat_table
  if use_threat_table then
    if IsInInstance() and db.threat.UseHeuristicInInstances then
      -- Use threat detection heuristic in instance
      on_threat_table = _G.UnitAffectingCombat(unit.unitid)
    else
      on_threat_table = Addon:OnThreatTable(unit)
    end
  else
    -- Use threat detection heuristic
    on_threat_table = _G.UnitAffectingCombat(unit.unitid)
  end

  if on_threat_table then
    color = db.settings[style].threatcolor[GetThreatSituation(unit, style, db.threat.toggle.OffTank)]
  end

  return color
end

-- Threat System is OP, player is in combat, style is tank or dps
local function GetColorByThreat(unit, style)
  local db = Addon.db.profile
  local c

  if (db.threat.ON and db.threat.useHPColor and (style == "dps" or style == "tank")) then
    c = Addon:GetThreatColor(unit, style, db.threat.UseThreatTable)
  end

  return c
end

local function GetColorByHealthDeficit(unit)
  local db = Addon.db.profile

  local pct = (_G.UnitHealth(unit.unitid) or 0) / (_G.UnitHealthMax(unit.unitid) or 1)
  local r, g, b = CS:GetSmudgeColorRGB(db.aHPbarColor, db.bHPbarColor, pct)
  return RGB_P(r, g, b, 1)
end

local function GetColorByClass(unit)
  local db = Addon.db.profile

  local c
  if unit.type == "PLAYER" then
    if unit.reaction == "HOSTILE" and db.allowClass then
      c = db.Colors.Classes[unit.class]
    elseif unit.reaction == "FRIENDLY" then
      local db_social = db.socialWidget
      if db_social.ShowFriendColor and IsFriend(unit) then
        c = db_social.FriendColor
      elseif db_social.ShowGuildmateColor and IsGuildmate(unit) then
        c = db_social.GuildmateColor
      elseif db.friendlyClass then
        c = db.Colors.Classes[unit.class]
      end
    end
  end

  return c
end

local function GetColorByReaction(unit)
  local db = Addon.db.profile.ColorByReaction

  -- PvP coloring based on: https://wowpedia.fandom.com/wiki/PvP_flag
  -- Coloring for pets is the same as for the player controlling the pet
  local unit_type = (UnitPlayerControlled(unit.unitid) and "PLAYER") or unit.type
  local color
  -- * For players and their pets
  if unit_type == "PLAYER" then
    if db.IgnorePvPStatus or Addon.IsInPvPInstance then
      color = (unit.reaction == "HOSTILE" and db.HostilePlayer) or db.FriendlyPlayer
    else
      local unit_is_pvp = UnitIsPVP(unit.unitid) or false
      local player_is_pvp = UnitIsPVP("player") or false
      color = db[UNIT_COLOR_MAP[unit.reaction][unit_type][unit_is_pvp][player_is_pvp]]
    end
  -- * From here: For NPCs (without pets)
  elseif not UnitCanAttack("player", unit.unitid) and unit.blue < 0.1 and unit.green > 0.5 and unit.green < 0.6 and unit.red > 0.9 then
    -- Handle non-attackable units with brown healtbars - currently, I know no better way to detect this.
    color = db.UnfriendlyFaction
  else
    color = db[UNIT_COLOR_MAP[unit.reaction][unit_type]]
  end

  return color
end

function Addon:SetHealthbarColor(unit)
  local style = unit.style

  if IGNORED_STYLES[style] then return end
  
  local unique_setting = unit.CustomPlateSettings

  ShowQuestUnit = ShowQuestUnit or ThreatPlates.ShowQuestUnit
  IsFriend = IsFriend or ThreatPlates.IsFriend
  IsGuildmate = IsGuildmate or ThreatPlates.IsGuildmate

  local db = Addon.db.profile
  local db_color = db.ColorByReaction

  local c
  if unit.isTarget and db.targetWidget.ModeHPBar then
    c = db.targetWidget.HPBarColor
  elseif unit.IsFocus and db.FocusWidget.ModeHPBar then
    c = db.FocusWidget.HPBarColor
  elseif style == "unique" then
    -- Custom nameplate style defined for unit (does not work for totems right now)
    if unit.isMarked and unique_setting.allowMarked then
      -- Unit is marked
      local db_raidicon = db.settings.raidicon
      c = db_raidicon.hpMarked[unit.raidIcon]
    else
      if not UnitIsConnected(unit.unitid) then
        c = db_color.DisconnectedUnit
      elseif unit.isTapped then
        c = db_color.TappedUnit
      elseif ShowQuestUnit(unit) and Addon:IsPlayerQuestUnit(unit) then
        -- Unit is quest target
        c = db.questWidget.HPBarColor
      elseif unique_setting.UseThreatColor then
        -- Threat System is should also be used for custom nameplate (in combat with thread system on)
        c = GetColorByThreat(unit, Addon:GetThreatStyle(unit))
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
    elseif db.healthColorChange then
      c = GetColorByHealthDeficit(unit)
    else
      -- order is ThreatSystem, ByClass, ByReaction, WoW Default
      if not UnitIsConnected(unit.unitid) then
        c = db_color.DisconnectedUnit
      elseif unit.isTapped then
        c = db_color.TappedUnit
      elseif ShowQuestUnit(unit) and Addon:IsPlayerQuestUnit(unit) then
        c = db.questWidget.HPBarColor
      else
        c = GetColorByThreat(unit, style)
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
Addon.GetThreatSituation = GetThreatSituation