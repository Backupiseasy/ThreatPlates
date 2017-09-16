---------------------------------------------------------------------------------------------------
-- Test functions: SetNameColor (in nametextcolor.lua)
---------------------------------------------------------------------------------------------------

local TEST_UNIT = {
  -- 1: Not connected
  {
    isTapped = false,
    reaction = "FRIENDLY", type = "PLAYER",
    unitid = "UnitIsConnected", Test_IsFriend = false, Test_IsGuildmate = false
  },
  -- 2: Tapped
  {
    isTapped = true,
    reaction = "FRIENDLY", type = "PLAYER",
    unitid = "", Test_IsFriend = false, Test_IsGuildmate = false
  },
  -- 3: Friend
  {
    isTapped = true,
    reaction = "FRIENDLY", type = "PLAYER",
    unitid = "", Test_IsFriend = true, Test_IsGuildmate = false
  },
  -- 4: Guildmate
  {
    isTapped = true,
    reaction = "FRIENDLY", type = "PLAYER",
    unitid = "", Test_IsFriend = false, Test_IsGuildmate = true
  },
  -- 5: Orange bar
  {
    isTapped = true,
    reaction = "HOSTILE", type = "NPC",
    unitid = "UnitCanAttack", Test_IsFriend = false, Test_IsGuildmate = true
  },
  -- 6: Default
  {
    isTapped = true,
    reaction = "FRIENDLY", type = "NPC",
    unitid = "UnitCanAttack", Test_IsFriend = false, Test_IsGuildmate = true
  },

}


function GetConfig(config_no)
  TidyPlatesThreat.db.profile.socialWidget.ShowFriendColor = true
  TidyPlatesThreat.db.profile.socialWidget.ShowGuildmateColor = true
  if config_no == 1 then
    return TEST_UNIT[config_no]
  elseif config_no == 2 then
    return TEST_UNIT[config_no]
  elseif config_no == 3 then
    return TEST_UNIT[config_no]
  elseif config_no == 4 then
    return TEST_UNIT[config_no]
  elseif config_no == 5 then
    return TEST_UNIT[config_no]
  elseif config_no == 6 then
    return TEST_UNIT[config_no]
  end
end

---------------------------------------------------------------------------------------------------

function UnitReaction(unitid)
  return ((unitid == "UnitCanAttack") and 3) or 1
end

local UnitIsConnected = UnitIsConnected
local UnitReaction = UnitReaction
local UnitCanAttack = UnitCanAttack
local FACTION_BAR_COLORS = FACTION_BAR_COLORS

local IsFriend
local IsGuildmate

local reference = {
  FRIENDLY = { NPC = "FriendlyNPC", PLAYER = "FriendlyPlayer", },
  HOSTILE = {	NPC = "HostileNPC", PLAYER = "HostilePlayer", },
  NEUTRAL = { NPC = "NeutralUnit", PLAYER = "NeutralUnit",	},
}

function GetColorByReaction_8_5_0(unit)
  local unit_reaction = unit.reaction
  local unit_type = unit.type
  local unit_id = unit.unitid

  local db = TidyPlatesThreat.db.profile
  local db_color = db.ColorByReaction

  local color
  if unit_id and not UnitIsConnected(unit_id) then
    color =  db_color.DisconnectedUnit
    return color.r, color.g, color.b
  elseif unit.isTapped then
    color =  db_color.TappedUnit
    return color.r, color.g, color.b
  elseif unit_reaction == "FRIENDLY" and unit_type == "PLAYER" then
    IsFriend = IsFriend or ThreatPlates.IsFriend
    IsGuildmate = IsGuildmate or ThreatPlates.IsGuildmate

    local db_social = db.socialWidget
    if db_social.ShowFriendColor and IsFriend(unit) then
      color =  db_social.FriendColor
      return color.r, color.g, color.b
    elseif db_social.ShowGuildmateColor and IsGuildmate(unit) then
      color =  db_social.GuildmateColor
      return color.r, color.g, color.b
    end
  elseif unit_reaction == "HOSTILE" and unit_type == "NPC" then
    local unit_attack = UnitCanAttack("player", unit_id)
    local wow_unit_reaction = UnitReaction("player", unit_id)
    if not unit_attack and wow_unit_reaction > 2 then
      color = FACTION_BAR_COLORS[wow_unit_reaction]
      return color.r, color.g, color.b
    end
  end

  color =  db_color[reference[unit_reaction][unit_type]]
  return color.r, color.g, color.b
end

function GetColorByReaction_Test(unit)
  local db = TidyPlatesThreat.db.profile
  local db_color = db.ColorByReaction

  local color
  if not UnitIsConnected(unit.unitid) then
    color =  db_color.DisconnectedUnit
  elseif unit.isTapped then
    color =  db_color.TappedUnit
  elseif unit.reaction == "FRIENDLY" and unit.type == "PLAYER" then
    IsFriend = IsFriend or ThreatPlates.IsFriend
    IsGuildmate = IsGuildmate or ThreatPlates.IsGuildmate

    local db_social = db.socialWidget
    if db_social.ShowFriendColor and IsFriend(unit) then
      color =  db_social.FriendColor
    elseif db_social.ShowGuildmateColor and IsGuildmate(unit) then
      color =  db_social.GuildmateColor
    else
      color = db_color[reference[unit.reaction][unit.type]]
    end
  elseif unit.type == "NPC" and not UnitCanAttack("player", unit.unitid) and UnitReaction("player", unit.unitid) == 3 then
    -- 1/2 is same color (red), 4 is neutral (yellow),5-8 is same color (green)
    color = FACTION_BAR_COLORS[3]
  else
    color = db_color[reference[unit.reaction][unit.type]]
  end

  return color.r, color.g, color.b
end

--function GetColorByReaction_Test(unit)
--  local unit_reaction = unit.reaction
--  local unit_type = unit.type
--  local unit_id = unit.unitid
--
--  local db = TidyPlatesThreat.db.profile
--  local db_color = db.ColorByReaction
--
--  local color
--  if unit_id and not UnitIsConnected(unit_id) then
--    color =  db_color.DisconnectedUnit
--  elseif unit.isTapped then
--    color =  db_color.TappedUnit
--  elseif unit_reaction == "FRIENDLY" and unit_type == "PLAYER" then
--    IsFriend = IsFriend or ThreatPlates.IsFriend
--    IsGuildmate = IsGuildmate or ThreatPlates.IsGuildmate
--
--    local db_social = db.socialWidget
--    if db_social.ShowFriendColor and IsFriend(unit) then
--      color =  db_social.FriendColor
--    elseif db_social.ShowGuildmateColor and IsGuildmate(unit) then
--      color =  db_social.GuildmateColor
--    end
--  elseif unit_reaction == "HOSTILE" and unit_type == "NPC" then
--    local unit_attack = UnitCanAttack("player", unit_id)
--    local wow_unit_reaction = UnitReaction("player", unit_id)
--    if not unit_attack and wow_unit_reaction > 2 then
--      color = FACTION_BAR_COLORS[wow_unit_reaction]
--    end
--  end
--
--  if not color then
--    color =  db_color[reference[unit_reaction][unit_type]]
--  end
--
--  return color.r, color.g, color.b
--end
