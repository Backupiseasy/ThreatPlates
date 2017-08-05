-----------------------------------------------------------------------------------------------------
-- Test functions: SetNameColor (in nametextcolor.lua)
---------------------------------------------------------------------------------------------------

local reference = {
  FRIENDLY = { NPC = "FriendlyNPC", PLAYER = "FriendlyPlayer", },
  HOSTILE = {	NPC = "HostileNPC", PLAYER = "HostilePlayer", },
  NEUTRAL = { NPC = "NeutralUnit", PLAYER = "NeutralUnit",	},
}

TidyPlatesThreat.SetStyle = function(unit)
  return unit.Test_style, unit.Test_unique_style
end

ThreatPlates.GetUniqueNameplateSetting = function(unit)
  return unit.Test_unique_style
end

local function NameColorInternal(unit)
  local db = TidyPlatesThreat.db.profile.ColorByReaction

  local color
  if unit.unitid and not UnitIsConnected(unit.unitid) then
    color = db.DisconnectedUnit
  elseif unit.isTapped then
    color = db.TappedUnit
  end

  return color
end

local function NameColorSocial(unit)
  local IsFriend = TidyPlatesThreat.IsFriend
  local IsGuildmate = TidyPlatesThreat.IsGuildmate
  local db = TidyPlatesThreat.db.profile.socialWidget

  local color

  if unit.reaction == "FRIENDLY" then
    if db.ShowFriendColor and IsFriend(unit) then
      color = db.FriendColor
    elseif db.ShowGuildmateColor and IsGuildmate(unit) then
      color = db.GuildmateColor
    end
  end

  return color
end

local function NameColorCustom(unit, db_mode)
  local unit_reaction = unit.reaction
  if unit_reaction == "FRIENDLY" then
    return db_mode.FriendlyTextColor
  else
    return db_mode.EnemyTextColor
  end
end

local function NameColorReaction(unit, db_mode)
  local db = TidyPlatesThreat.db.profile
  return NameColorInternal(unit) or NameColorSocial(unit) or db.ColorByReaction[reference[unit.reaction][unit.type]]
end

local function NameColorClass(unit, db_mode)
  return NameColorInternal(unit) or NameColorSocial(unit) or RAID_CLASS_COLORS[unit.class] or NameColorReaction(unit)
end

local function NameColorClass_Test(unit, db_mode)
  --return NameColorInternal(unit) or NameColorSocial(unit) or RAID_CLASS_COLORS[unit.class] or NameColorReaction(unit)
  local color

  local db = TidyPlatesThreat.db.profile.ColorByReaction
  if unit.unitid and not UnitIsConnected(unit.unitid) then
    color = db.DisconnectedUnit
  elseif unit.isTapped then
    color = db.TappedUnit
  else
    local IsFriend = TidyPlatesThreat.IsFriend
    local IsGuildmate = TidyPlatesThreat.IsGuildmate

    db = TidyPlatesThreat.db.profile.socialWidget
    if unit.reaction == "FRIENDLY" then
      if db.ShowFriendColor and IsFriend(unit) then
        color = db.FriendColor
      elseif db.ShowGuildmateColor and IsGuildmate(unit) then
        color = db.GuildmateColor
      end
    end

    if not color then
      color = RAID_CLASS_COLORS[unit.class]
    end

    if not color then
      color = db.ColorByReaction[reference[unit.reaction][unit.type]]
    end
  end

  return color
end

local FUNCTIONS_TEST = {
  CUSTOM = NameColorCustom,
  HEALTH = GetColorByHealthDeficit,
  CLASS = NameColorClass_Test,
  REACTION = NameColorReaction,
}

local SetStyle = TidyPlatesThreat.SetStyle
local GetUniqueNameplateSetting = ThreatPlates.GetUniqueNameplateSetting
local GetColorByHealthDeficit = GetColorByHealthDeficit
local UnitIsConnected = UnitIsConnected
local IsFriend = IsFriend
local IsGuildmate = IsGuildmate
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local TidyPlatesThreat = TidyPlatesThreat

function SetNameColor_Test(unit)

  local style = unit.TP_Style or SetStyle(unit)

  local db = TidyPlatesThreat.db.profile
  local db_mode = db.settings.name
  if style == "NameOnly" or style == "NameOnly-Unique" then
    db_mode = db.HeadlineView
  end

  local color
  if unit.isMarked then
    local unique_setting = GetUniqueNameplateSetting(unit)
    if style == "NameOnly-Unique" and unique_setting.useColor then
      if unique_setting.allowMarked then
        color = db.settings.raidicon.hpMarked[unit.raidIcon]
        return color.r, color.g, color.b
      end
    elseif db_mode.UseRaidMarkColoring then
      color =  db.settings.raidicon.hpMarked[unit.raidIcon]
      return color.r, color.g, color.b
    end
  end

  local unit_reaction = unit.reaction
  local mode = (unit_reaction == "FRIENDLY" and db_mode.FriendlyTextColorMode) or db_mode.EnemyTextColorMode

  if mode == "CUSTOM" then
    if unit_reaction == "FRIENDLY" then
      color = db_mode.FriendlyTextColor
      return color.r, color.g, color.b
    else
      color = db_mode.EnemyTextColor
      return color.r, color.g, color.b
    end
  elseif mode == "HEALTH" then
    local color =  GetColorByHealthDeficit(unit)
    return color.r, color.g, color.b
  elseif mode == "CLASS" then
    if unit.unitid and not UnitIsConnected(unit.unitid) then
      color =  db.DisconnectedUnit
      return color.r, color.g, color.b
    elseif unit.isTapped then
      color =  db.TappedUnit
      return color.r, color.g, color.b
    elseif unit.type == "PLAYER" then
      if unit_reaction == "FRIENDLY" then
        local db_social = db.socialWidget
        if db_social.ShowFriendColor and IsFriend(unit) then
          color =  db_social.FriendColor
          return color.r, color.g, color.b
        elseif db_social.ShowGuildmateColor and IsGuildmate(unit) then
          color =  db_social.GuildmateColor
          return color.r, color.g, color.b
        end
      end

      color =  RAID_CLASS_COLORS[unit.class]
      return color.r, color.g, color.b
    end

    color =  db.ColorByReaction[reference[unit_reaction][unit.type]]
    return color.r, color.g, color.b
  end

  -- Default: By Reaction
  if unit.unitid and not UnitIsConnected(unit.unitid) then
    color =  db.DisconnectedUnit
    return color.r, color.g, color.b
  elseif unit.isTapped then
    color =  db.TappedUnit
    return color.r, color.g, color.b
  elseif unit_reaction == "FRIENDLY" and unit.type == "PLAYER" then
    local db_social = db.socialWidget
    if db_social.ShowFriendColor and IsFriend(unit) then
      color =  db_social.FriendColor
      return color.r, color.g, color.b
    elseif db_social.ShowGuildmateColor and IsGuildmate(unit) then
      color =  db_social.GuildmateColor
      return color.r, color.g, color.b
    end
  end

  color =  db.ColorByReaction[reference[unit_reaction][unit.type]]
  return color.r, color.g, color.b
end

function SetNameColor_Test_Internal(unit)
  local SetStyle = TidyPlatesThreat.SetStyle
  local GetUniqueNameplateSetting = ThreatPlates.GetUniqueNameplateSetting

  local style = unit.TP_Style or SetStyle(unit)

  local db = TidyPlatesThreat.db.profile
  local db_mode = db.settings.name
  if style == "NameOnly" or style == "NameOnly-Unique" then
    db_mode = db.HeadlineView
  end

  local color
  if unit.isMarked then
    local unique_setting = GetUniqueNameplateSetting(unit)
    if style == "NameOnly-Unique" and unique_setting.useColor then
      if unique_setting.allowMarked then
        return db.settings.raidicon.hpMarked[unit.raidIcon]
      end
    elseif db_mode.UseRaidMarkColoring then
      return db.settings.raidicon.hpMarked[unit.raidIcon]
    end
  end

  local unit_reaction = unit.reaction
  local mode = (unit_reaction == "FRIENDLY" and db_mode.FriendlyTextColorMode) or db_mode.EnemyTextColorMode

  if mode == "CUSTOM" then
    if unit_reaction == "FRIENDLY" then
      return db_mode.FriendlyTextColor
    else
      return db_mode.EnemyTextColor
    end
  elseif mode == "HEALTH" then
    return GetColorByHealthDeficit(unit)
  elseif mode == "CLASS" then
    if unit.unitid and not UnitIsConnected(unit.unitid) then
      return db.DisconnectedUnit
    elseif unit.isTapped then
      return db.TappedUnit
    elseif unit.type == "PLAYER" then
      if unit_reaction == "FRIENDLY" then
        local db_social = db.socialWidget
        if db_social.ShowFriendColor and IsFriend(unit) then
          return db_social.FriendColor
        elseif db_social.ShowGuildmateColor and IsGuildmate(unit) then
          return db_social.GuildmateColor
        end
      end

      return RAID_CLASS_COLORS[unit.class]
    end

    return db.ColorByReaction[reference[unit_reaction][unit.type]]
  end

  -- Default: By Reaction
  if unit.unitid and not UnitIsConnected(unit.unitid) then
    return db.DisconnectedUnit
  elseif unit.isTapped then
    return db.TappedUnit
  elseif unit_reaction == "FRIENDLY" and unit.type == "PLAYER" then
    local db_social = db.socialWidget
    if db_social.ShowFriendColor and IsFriend(unit) then
      return db_social.FriendColor
    elseif db_social.ShowGuildmateColor and IsGuildmate(unit) then
      return db_social.GuildmateColor
    end
  end

  return db.ColorByReaction[reference[unit_reaction][unit.type]]
end

--function SetNameColor_Test(unit)
--  local color = SetNameColor_Test_Internal(unit)
--  return color.r, color.g, color.b, 1
--end

local FUNCTIONS = {
  CUSTOM = NameColorCustom,
  HEALTH = GetColorByHealthDeficit,
  CLASS = NameColorClass,
  REACTION = NameColorReaction,
}

function SetNameColor_New(unit)
  local SetStyle = TidyPlatesThreat.SetStyle
  local GetUniqueNameplateSetting = ThreatPlates.GetUniqueNameplateSetting

  local style = unit.TP_Style or SetStyle(unit)

  local db = TidyPlatesThreat.db.profile
  local db_mode = db.settings.name
  if style == "NameOnly" or style == "NameOnly-Unique" then
    db_mode = db.HeadlineView
  end

  local color

  if unit.isMarked then
    local unique_setting = GetUniqueNameplateSetting(unit)
    if style == "NameOnly-Unique" and unique_setting.useColor then
      if unique_setting.allowMarked then
        color = db.settings.raidicon.hpMarked[unit.raidIcon]
      end
    elseif db_mode.UseRaidMarkColoring then
      color = db.settings.raidicon.hpMarked[unit.raidIcon]
    end
  end

  if not color then
    local func
    local unit_reaction = unit.reaction
    if unit_reaction == "FRIENDLY" then
      func = FUNCTIONS[db_mode.FriendlyTextColorMode]
    else
      func = FUNCTIONS[db_mode.EnemyTextColorMode]
    end

    -- if no color was found, default back to WoW default colors (based on GetSelectionColor)
    color = func(unit, db_mode) or { r = unit.red, g = unit.green, b = unit.blue}
  end

  return color.r, color.g, color.b, 1
end

function SetNameColor_8_4_2(unit)
  local db = TidyPlatesThreat.db.profile
  local style, unique_style = TidyPlatesThreat.SetStyle(unit)

  local color
  local db_mode = db.settings.name
  if style == "NameOnly" or style == "NameOnly-Unique" then
    db_mode = db.HeadlineView
  end

  if unit.unitid and not UnitIsConnected(unit.unitid) then
    color = db.ColorByReaction.DisconnectedUnit
  elseif unit.isTapped then
    color = db.ColorByReaction.TappedUnit
  elseif unit.isMarked then
    if style == "NameOnly-Unique" and unique_style.useColor then
      if unique_style.allowMarked then
        color = db.settings.raidicon.hpMarked[unit.raidIcon]
      end
    elseif db_mode.UseRaidMarkColoring then
      color = db.settings.raidicon.hpMarked[unit.raidIcon]
    end
  end

  local IsFriend = TidyPlatesThreat.IsFriend
  local IsGuildmate = TidyPlatesThreat.IsGuildmate
  local unit_reaction = unit.reaction

  if not color then -- By Class or By Health
    if style == "NameOnly-Unique" and unique_style.useColor then
      color = unique_style.color
    elseif unit_reaction == "FRIENDLY" then
      if db_mode.FriendlyTextColorMode == "CUSTOM" then -- By Custom Color
        color = db_mode.FriendlyTextColor
      elseif db_mode.FriendlyTextColorMode == "CLASS" and unit.type == "PLAYER" then -- By Class
        local db_social = db.socialWidget
        if db_social.ShowFriendColor and IsFriend(unit) then
          color = db_social.FriendColor
        elseif db_social.ShowGuildmateColor and IsGuildmate(unit) then
          color = db_social.GuildmateColor
        else
          color = RAID_CLASS_COLORS[unit.class]
        end
      elseif db_mode.FriendlyTextColorMode == "HEALTH" then
        color = GetColorByHealthDeficit(unit)
      end
    else
      if db_mode.EnemyTextColorMode == "CUSTOM" then -- By Custom Color
        color = db_mode.EnemyTextColor
      elseif db_mode.EnemyTextColorMode == "CLASS" and unit.type == "PLAYER" then -- By Class
        color = RAID_CLASS_COLORS[unit.class]
      elseif db_mode.EnemyTextColorMode == "HEALTH" then
        color = GetColorByHealthDeficit(unit)
      end
    end
  end

  if not color then -- Default: By Reaction
    if unit_reaction == "FRIENDLY" then
      local db_social = db.socialWidget
      if db_social.ShowFriendColor and IsFriend(unit) then
        color = db_social.FriendColor
      elseif db_social.ShowGuildmateColor and IsGuildmate(unit) then
        color = db_social.GuildmateColor
      else
        color = db.ColorByReaction[reference[unit_reaction][unit.type]]
      end
    else
      color = db.ColorByReaction[reference[unit_reaction][unit.type]]
    end
  end

  -- if no color was found, default back to WoW default colors (based on GetSelectionColor)
  if not color then
    color = { r = unit.red, g = unit.green, b = unit.blue}
  end

	return color.r, color.g, color.b, 1
end
