---------------------------------------------------------------------------------------------------
-- Test functions: SetNameColor (in nametextcolor.lua)
---------------------------------------------------------------------------------------------------

local TEST_UNIT = {
  -- 1: Marked, NameOnly-Unique
  {
    isTapped = false, isMarked = true, raidIcon = "STAR", reaction = "FRIENDLY", type = "PLAYER", class = "DRUID",
    Test_style = "NameOnly-Unique",
    Test_unique_style =  { useColor = true, allowMarked = true, color = Addon.RGB(255, 255, 255) },
    Test_IsFriend = false, Test_IsGuildmate = false,
  },
  -- 2: Marked, NameOnly
  {
    isTapped = false, isMarked = true, raidIcon = "STAR", reaction = "FRIENDLY", type = "PLAYER", class = "DRUID",
    Test_style = "NameOnly",
    Test_unique_style =  { useColor = true, allowMarked = true, color = Addon.RGB(255, 255, 255) },
    Test_IsFriend = false, Test_IsGuildmate = false,
  },
  -- 3: NameOnly-Unique
  {
    isTapped = false, isMarked = false, raidIcon = "STAR", reaction = "FRIENDLY", type = "PLAYER", class = "DRUID",
    Test_style = "NameOnly-Unique",
    Test_unique_style =  { useColor = true, allowMarked = true, color = Addon.RGB(255, 255, 255) },
    Test_IsFriend = false, Test_IsGuildmate = false,
  },
  -- 4: Custom, Friendly
  {
    isTapped = false, isMarked = false, raidIcon = "STAR", reaction = "FRIENDLY", type = "PLAYER", class = "DRUID",
    Test_style = "dps",
    Test_unique_style =  { useColor = true, allowMarked = true, color = Addon.RGB(255, 255, 255) },
    Test_IsFriend = false, Test_IsGuildmate = false,
  },
  -- 5: HEALTH
  {
    isTapped = false, isMarked = false, raidIcon = "STAR", reaction = "FRIENDLY", type = "PLAYER", class = "DRUID",
    Test_style = "dps",
    Test_unique_style =  { useColor = true, allowMarked = true, color = Addon.RGB(255, 255, 255) },
    Test_IsFriend = false, Test_IsGuildmate = false,
  },
  -- 6: CLASS, Tapped
  {
    isTapped = true, isMarked = false, raidIcon = "STAR", reaction = "FRIENDLY", type = "NPC", class = "DRUID",
    Test_style = "dps",
    Test_unique_style =  { useColor = true, allowMarked = true, color = Addon.RGB(255, 255, 255) },
    Test_IsFriend = false, Test_IsGuildmate = false,
  },
  -- 7: CLASS, PLAYER, Friend
  {
    isTapped = false, isMarked = false, raidIcon = "STAR", reaction = "FRIENDLY", type = "PLAYER", class = "DRUID",
    Test_style = "dps",
    Test_unique_style =  { useColor = true, allowMarked = true, color = Addon.RGB(255, 255, 255) },
    Test_IsFriend = true, Test_IsGuildmate = false,
  },
  -- 8: CLASS, PLAYER, No Friend
  {
    isTapped = false, isMarked = false, raidIcon = "STAR", reaction = "FRIENDLY", type = "PLAYER", class = "DRUID",
    Test_style = "dps",
    Test_unique_style =  { useColor = true, allowMarked = true, color = Addon.RGB(255, 255, 255) },
    Test_IsFriend = false, Test_IsGuildmate = false,
  },
  -- 9: CLASS, NPC
  {
    isTapped = false, isMarked = false, raidIcon = "STAR", reaction = "FRIENDLY", type = "NPC", class = "DRUID",
    Test_style = "dps",
    Test_unique_style =  { useColor = true, allowMarked = true, color = Addon.RGB(255, 255, 255) },
    Test_IsFriend = false, Test_IsGuildmate = false,
  },
  -- 10: REACTION, Tapped
  {
    isTapped = true, isMarked = false, raidIcon = "STAR", reaction = "FRIENDLY", type = "PLAYER", class = "DRUID",
    Test_style = "dps",
    Test_unique_style =  { useColor = true, allowMarked = true, color = Addon.RGB(255, 255, 255) },
    Test_IsFriend = false, Test_IsGuildmate = false,
  },
  -- 11: REACTION, Player, Is Guild Member
  {
    isTapped = false, isMarked = false, raidIcon = "STAR", reaction = "FRIENDLY", type = "PLAYER", class = "DRUID",
    Test_style = "dps",
    Test_unique_style =  { useColor = true, allowMarked = true, color = Addon.RGB(255, 255, 255) },
    Test_IsFriend = false, Test_IsGuildmate = true,
  },
  -- 12: REACTION, Player, No Guild Member
  {
    isTapped = false, isMarked = false, raidIcon = "STAR", reaction = "FRIENDLY", type = "PLAYER", class = "DRUID",
    Test_style = "dps",
    Test_unique_style =  { useColor = true, allowMarked = true, color = Addon.RGB(255, 255, 255) },
    Test_IsFriend = false, Test_IsGuildmate = false,
  },
}


function GetConfig(config_no)
  if config_no == 1 then
    return TEST_UNIT[config_no]
  elseif config_no == 2 then
    Addon.db.profile.HeadlineView.UseRaidMarkColoring = true
    return TEST_UNIT[config_no]
  elseif config_no == 3 then
    return TEST_UNIT[config_no]
  elseif config_no == 4 then
    Addon.db.profile.settings.name.FriendlyTextColorMode = "CUSTOM"
    return TEST_UNIT[config_no]
  elseif config_no == 5 then
    Addon.db.profile.settings.name.FriendlyTextColorMode = "HEALTH"
    return TEST_UNIT[config_no]
  elseif config_no == 6 then
    Addon.db.profile.settings.name.FriendlyTextColorMode = "CLASS"
    return TEST_UNIT[config_no]
  elseif config_no == 7 then
    return TEST_UNIT[config_no]
  elseif config_no == 8 then
    return TEST_UNIT[config_no]
  elseif config_no == 9 then
    return TEST_UNIT[config_no]
  elseif config_no == 10 then
    Addon.db.profile.settings.name.FriendlyTextColorMode = "REACTION"
    return TEST_UNIT[config_no]
  elseif config_no == 11 then
    return TEST_UNIT[config_no]
  else --if config_no == 12 then
    return TEST_UNIT[config_no]
  end
end

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

local TidyPlatesThreat = TidyPlatesThreat
local GetColorByHealthDeficit = ThreatPlates.GetColorByHealthDeficit
local SetStyle = TidyPlatesThreat.SetStyle
local GetUniqueNameplateSetting = ThreatPlates.GetUniqueNameplateSetting
local IsFriend
local IsGuildmate
local IsFriend_Test
local IsGuildmate_Test

function SetNameColor_Test(unit)
  local style = unit.TP_Style or SetStyle(unit)
  local unique_setting = unit.TP_UniqueSetting or GetUniqueNameplateSetting(unit)

  local db = Addon.db.profile
  local db_mode = db.settings.name
  if style == "NameOnly" or style == "NameOnly-Unique" then
    db_mode = db.HeadlineView
  end

  local color
  -- local unique_setting = GetUniqueNameplateSetting(unit)
  if unit.isMarked then
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
  local db_color = db.ColorByReaction
  local mode = (unit_reaction == "FRIENDLY" and db_mode.FriendlyTextColorMode) or db_mode.EnemyTextColorMode

  IsFriend_Test = IsFriend_Test or ThreatPlates.IsFriend
  IsGuildmate_Test = IsGuildmate_Test or ThreatPlates.IsGuildmate

  if style == "NameOnly-Unique" and unique_setting.useColor then
    color = unique_setting.color
    return color.r, color.g, color.b
  elseif mode == "CUSTOM" then
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
      color =  db_color.DisconnectedUnit
      return color.r, color.g, color.b
    elseif unit.isTapped then
      color =  db_color.TappedUnit
      return color.r, color.g, color.b
    elseif unit.type == "PLAYER" then
      if unit_reaction == "FRIENDLY" then
        local db_social = db.socialWidget
        if db_social.ShowFriendColor and IsFriend_Test(unit) then
          color =  db_social.FriendColor
          return color.r, color.g, color.b
        elseif db_social.ShowGuildmateColor and IsGuildmate_Test(unit) then
          color =  db_social.GuildmateColor
          return color.r, color.g, color.b
        end
      end

      color =  RAID_CLASS_COLORS[unit.class]
      return color.r, color.g, color.b
    end

    color =  db_color[reference[unit_reaction][unit.type]]
    return color.r, color.g, color.b
  end

  -- Default: By Reaction
  if unit.unitid and not UnitIsConnected(unit.unitid) then
    color =  db_color.DisconnectedUnit
    return color.r, color.g, color.b
  elseif unit.isTapped then
    color =  db_color.TappedUnit
    return color.r, color.g, color.b
  elseif unit_reaction == "FRIENDLY" and unit.type == "PLAYER" then
    local db_social = db.socialWidget
    if db_social.ShowFriendColor and IsFriend_Test(unit) then
      color =  db_social.FriendColor
      return color.r, color.g, color.b
    elseif db_social.ShowGuildmateColor and IsGuildmate_Test(unit) then
      color =  db_social.GuildmateColor
      return color.r, color.g, color.b
    end
  end

  color =  db_color[reference[unit_reaction][unit.type]]
  return color.r, color.g, color.b
end

function SetNameColor_New(unit)
  local style = unit.TP_Style or SetStyle(unit)
  local unique_setting = unit.TP_UniqueSetting or GetUniqueNameplateSetting(unit)

  local db = Addon.db.profile
  local db_mode = db.settings.name
  if style == "NameOnly" or style == "NameOnly-Unique" then
    db_mode = db.HeadlineView
  end

  local color
  -- local unique_setting = GetUniqueNameplateSetting(unit)
  if unit.isMarked then
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
  local db_color = db.ColorByReaction
  local mode = (unit_reaction == "FRIENDLY" and db_mode.FriendlyTextColorMode) or db_mode.EnemyTextColorMode

  IsFriend_Test = IsFriend_Test or ThreatPlates.IsFriend
  IsGuildmate_Test = IsGuildmate_Test or ThreatPlates.IsGuildmate

  if style == "NameOnly-Unique" and unique_setting.useColor then
    color = unique_setting.color
    return color.r, color.g, color.b
  elseif mode == "CUSTOM" then
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
      color =  db_color.DisconnectedUnit
      return color.r, color.g, color.b
    elseif unit.isTapped then
      color =  db_color.TappedUnit
      return color.r, color.g, color.b
    elseif unit.type == "PLAYER" then
      if unit_reaction == "FRIENDLY" then
        local db_social = db.socialWidget
        if db_social.ShowFriendColor and IsFriend_Test(unit) then
          color =  db_social.FriendColor
          return color.r, color.g, color.b
        elseif db_social.ShowGuildmateColor and IsGuildmate_Test(unit) then
          color =  db_social.GuildmateColor
          return color.r, color.g, color.b
        end
      end

      color =  RAID_CLASS_COLORS[unit.class]
      return color.r, color.g, color.b
    end

    color =  db_color[reference[unit_reaction][unit.type]]
    return color.r, color.g, color.b
  end

  -- Default: By Reaction
  if unit.unitid and not UnitIsConnected(unit.unitid) then
    color =  db_color.DisconnectedUnit
    return color.r, color.g, color.b
  elseif unit.isTapped then
    color =  db_color.TappedUnit
    return color.r, color.g, color.b
  elseif unit_reaction == "FRIENDLY" and unit.type == "PLAYER" then
    local db_social = db.socialWidget
    if db_social.ShowFriendColor and IsFriend_Test(unit) then
      color =  db_social.FriendColor
      return color.r, color.g, color.b
    elseif db_social.ShowGuildmateColor and IsGuildmate_Test(unit) then
      color =  db_social.GuildmateColor
      return color.r, color.g, color.b
    end
  end

  color =  db_color[reference[unit_reaction][unit.type]]
  return color.r, color.g, color.b
end

function SetNameColor_8_4_2(unit)
  local style = unit.TP_Style or SetStyle(unit)
  local unique_style = unit.TP_UniqueSetting or GetUniqueNameplateSetting(unit)

  local db = Addon.db.profile
  -- 8.4.2: local style, unique_style = TidyPlatesThreat.SetStyle(unit)

  local color
  local db_mode = db.settings.name
  if style == "NameOnly" or style == "NameOnly-Unique" then
    db_mode = db.HeadlineView
  end

  if unit.isMarked then
    if style == "NameOnly-Unique" and unique_style.useColor then
      if unique_style.allowMarked then
        color = db.settings.raidicon.hpMarked[unit.raidIcon]
      end
    elseif db_mode.UseRaidMarkColoring then
      color = db.settings.raidicon.hpMarked[unit.raidIcon]
    end
  end

  IsFriend = IsFriend or ThreatPlates.IsFriend
  IsGuildmate = IsGuildmate or ThreatPlates.IsGuildmate
  -- 8.4.2: local IsFriend = TidyPlatesThreat.IsFriend
  -- 8.4.2: local IsGuildmate = TidyPlatesThreat.IsGuildmate
  local unit_reaction = unit.reaction

  if not color then -- By Class or By Health
    if style == "NameOnly-Unique" and unique_style.useColor then
      color = unique_style.color
    elseif unit_reaction == "FRIENDLY" then
      if db_mode.FriendlyTextColorMode == "CUSTOM" then -- By Custom Color
        color = db_mode.FriendlyTextColor
      elseif db_mode.FriendlyTextColorMode == "CLASS" and unit.type == "PLAYER" then -- By Class
        local db_social = db.socialWidget
        if unit.unitid and not UnitIsConnected(unit.unitid) then
          color =  db.ColorByReaction.DisconnectedUnit
        elseif db_social.ShowFriendColor and IsFriend(unit) then
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
        if unit.unitid and not UnitIsConnected(unit.unitid) then
          color =  db.ColorByReaction.DisconnectedUnit
        else
          color = RAID_CLASS_COLORS[unit.class]
        end
      elseif db_mode.EnemyTextColorMode == "HEALTH" then
        color = GetColorByHealthDeficit(unit)
      end
    end
  end

  if not color then -- Default: By Reaction
    if unit.unitid and not UnitIsConnected(unit.unitid) then
      color = db.ColorByReaction.DisconnectedUnit
    elseif unit.isTapped then
      color = db.ColorByReaction.TappedUnit
    elseif unit_reaction == "FRIENDLY" then
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

	return color.r, color.g, color.b
end
