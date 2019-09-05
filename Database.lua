local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Stuff for handling the database with the SavedVariables of ThreatPlates (ThreatPlatesDB)
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local floor, select, unpack, type, min, pairs = floor, select, unpack, type, min, pairs

-- WoW APIs
local GetCVar, SetCVar = GetCVar, SetCVar
local UnitClass, GetSpecialization = UnitClass, GetSpecialization
local GetShapeshiftFormID = GetShapeshiftFormID
local BEAR_FORM, DIRE_BEAR_FORM = BEAR_FORM, 8

-- ThreatPlates APIs
local L = ThreatPlates.L
local TidyPlatesThreat = TidyPlatesThreat
local RGB = ThreatPlates.RGB

---------------------------------------------------------------------------------------------------
-- Global functions for accessing the configuration
---------------------------------------------------------------------------------------------------

-- Returns if the currently active spec is tank (true) or dps/heal (false)
Addon.PlayerClass = select(2, UnitClass("player"))

-- Tanks are only Warriors in Defensive Stance or Druids in Bear form
local PLAYER_IS_TANK_BY_CLASS = {
  WARRIOR = function()
    return GetShapeshiftFormID() == 18
  end,
  DRUID = function()
    local form_index = GetShapeshiftFormID()
    return form_index == BEAR_FORM or form_index == DIRE_BEAR_FORM
  end,
  PALADIN = function()
    return Addon.PlayerIsPaladinTank
  end,
  DEFAULT = function()
    return false
  end,
}

local PlayerIsTankByClassFunction = PLAYER_IS_TANK_BY_CLASS[Addon.PlayerClass] or PLAYER_IS_TANK_BY_CLASS["DEFAULT"]

function Addon:PlayerRoleIsTank()
  local db = TidyPlatesThreat.db
  if db.profile.optionRoleDetectionAutomatic then
    return PlayerIsTankByClassFunction()
  else
    return db.char.spec[1]
  end
end

-- Sets the role of the index spec or the active spec to tank (value = true) or dps/healing
function TidyPlatesThreat:SetRole(value)
  self.db.char.spec[1] = value
end

local function GetUnitVisibility(full_unit_type)
  local unit_visibility = TidyPlatesThreat.db.profile.Visibility[full_unit_type]

  -- assert (TidyPlatesThreat.db.profile.Visibility[full_unit_type], "missing unit type: ".. full_unit_type)

  local show = unit_visibility.Show
  if type(show) ~= "boolean" then
    show = (GetCVar(show) == "1")
  end

  return show, unit_visibility.UseHeadlineView
end

local function SetNamePlateClickThrough(friendly, enemy)
--  if InCombatLockdown() then
--    ThreatPlates.Print(L["Nameplate clickthrough cannot be changed while in combat."], true)
--  else
    local db = TidyPlatesThreat.db.profile
    db.NamePlateFriendlyClickThrough = friendly
    db.NamePlateEnemyClickThrough = enemy
    Addon:CallbackWhenOoC(function()
      C_NamePlate.SetNamePlateFriendlyClickThrough(friendly)
      C_NamePlate.SetNamePlateEnemyClickThrough(enemy)
    end, L["Nameplate clickthrough cannot be changed while in combat."])
--  end
end

local DEPRECATED_UNIQUE_SETTINGS = {
  map = {},
  ["**"] = {
    name = "<Enter name here>",
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "",
    scale = 1,
    alpha = 1,
    color = {
      r = 1,
      g = 1,
      b = 1
    },
  },
  [1] = {
    name = L["Shadow Fiend"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U1",
    scale = 0.45,
    alpha = 1,
    color = {
      r = 0.61,
      g = 0.40,
      b = 0.86
    },
  },
  [2] = {
    name = L["Spirit Wolf"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U2",
    scale = 0.45,
    alpha = 1,
    color = {
      r = 0.32,
      g = 0.7,
      b = 0.89
    },
  },
  [3] = {
    name = L["Ebon Gargoyle"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U3",
    scale = 0.45,
    alpha = 1,
    color = {
      r = 1,
      g = 0.71,
      b = 0
    },
  },
  [4] = {
    name = L["Water Elemental"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U4",
    scale = 0.45,
    alpha = 1,
    color = {
      r = 0.33,
      g = 0.72,
      b = 0.44
    },
  },
  [5] = {
    name = L["Treant"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U5",
    scale = 0.45,
    alpha = 1,
    color = {
      r = 1,
      g = 0.71,
      b = 0
    },
  },
  [6] = {
    name = L["Viper"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U6",
    scale = 0.45,
    alpha = 1,
    color = {
      r = 0.39,
      g = 1,
      b = 0.11
    },
  },
  [7] = {
    name = L["Venomous Snake"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U6",
    scale = 0.45,
    alpha = 1,
    color = {
      r = 0.75,
      g = 0,
      b = 0.02
    },
  },
  [8] = {
    name = L["Army of the Dead Ghoul"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U7",
    scale = 0.45,
    alpha = 1,
    color = {
      r = 0.87,
      g = 0.78,
      b = 0.88
    },
  },
  [9] = {
    name = L["Shadowy Apparition"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U8",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.62,
      g = 0.19,
      b = 1
    },
  },
  [10] = {
    name = L["Shambling Horror"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U9",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.69,
      g = 0.26,
      b = 0.25
    },
  },
  [11] = {
    name = L["Web Wrap"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U10",
    scale = 0.75,
    alpha = 1,
    color = {
      r = 1,
      g = 0.39,
      b = 0.96
    },
  },
  [12] = {
    name = L["Immortal Guardian"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U11",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.33,
      g = 0.33,
      b = 0.33
    },
  },
  [13] = {
    name = L["Marked Immortal Guardian"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U12",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.75,
      g = 0,
      b = 0.02
    },
  },
  [14] = {
    name = L["Empowered Adherent"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U13",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.29,
      g = 0.11,
      b = 1
    },
  },
  [15] = {
    name = L["Deformed Fanatic"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U14",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.55,
      g = 0.7,
      b = 0.29
    },
  },
  [16] = {
    name = L["Reanimated Adherent"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U15",
    scale = 1,
    alpha = 1,
    color = {
      r = 1,
      g = 0.88,
      b = 0.61
    },
  },
  [17] = {
    name = L["Reanimated Fanatic"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U15",
    scale = 1,
    alpha = 1,
    color = {
      r = 1,
      g = 0.88,
      b = 0.61
    },
  },
  [18] = {
    name = L["Bone Spike"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U16",
    scale = 1,
    alpha = 1,
    color = {
      r = 1,
      g = 1,
      b = 1
    },
  },
  [19] = {
    name = L["Onyxian Whelp"],
    showNameplate = false,
    ShowHealthbarView = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U17",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.33,
      g = 0.28,
      b = 0.71
    },
  },
  [20] = {
    name = L["Gas Cloud"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U18",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.96,
      g = 0.56,
      b = 0.07
    },
  },
  [21] = {
    name = L["Volatile Ooze"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U19",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.36,
      g = 0.95,
      b = 0.33
    },
  },
  [22] = {
    name = L["Darnavan"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U20",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.78,
      g = 0.61,
      b = 0.43
    },
  },
  [23] = {
    name = L["Val'kyr Shadowguard"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U21",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.47,
      g = 0.89,
      b = 1
    },
  },
  [24] = {
    name = L["Kinetic Bomb"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U22",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.91,
      g = 0.71,
      b = 0.1
    },
  },
  [25] = {
    name = L["Lich King"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U23",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.77,
      g = 0.12,
      b = 0.23
    },
  },
  [26] = {
    name = L["Raging Spirit"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U24",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.77,
      g = 0.27,
      b = 0
    },
  },
  [27] = {
    name = L["Drudge Ghoul"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = false,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U25",
    scale = 0.85,
    alpha = 1,
    color = {
      r = 0.43,
      g = 0.43,
      b = 0.43
    },
  },
  [28] = {
    name = L["Living Inferno"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U27",
    scale = 1,
    alpha = 1,
    color = {
      r = 0,
      g = 1,
      b = 0
    },
  },
  [29] = {
    name = L["Living Ember"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = false,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U28",
    scale = 0.60,
    alpha = 0.75,
    color = {
      r = 0.25,
      g = 0.25,
      b = 0.25
    },
  },
  [30] = {
    name = L["Fanged Pit Viper"],
    showNameplate = false,
    ShowHealthbarView = true,
    ShowHeadlineView = false,
    showIcon = false,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "",
    scale = 0,
    alpha = 0,
    color = {
      r = 1,
      g = 1,
      b = 1
    },
  },
  [31] = {
    name = L["Canal Crab"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U29",
    scale = 1,
    alpha = 1,
    color = {
      r = 0,
      g = 1,
      b = 1
    },
  },
  [32] = {
    name = L["Muddy Crawfish"],
    showNameplate = true,
    ShowHeadlineView = false,
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U30",
    scale = 1,
    alpha = 1,
    color = {
      r = 0.96,
      g = 0.36,
      b = 0.34
    },
  },
}

--local DEPRECATED_ICON_DEFAULTS = {
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U1"] = "spell_shadow_shadowfiend.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U2"] = "spell_shaman_feralspirit.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U3"] = "Ability_hunter_pet_bat.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U4"] = "Spell_frost_summonwaterelemental_2.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U5"] = "ability_druid_forceofnature.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U6"] = "Ability_hunter_snaketrap.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U7"] = "spell_deathknight_armyofthedead.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U8"] = "ability_priest_shadowyapparition.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U9"] = "ability_warrior_shockwave.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U10"] = "spell_nature_web.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U11"] = "spell_shadow_mindtwisting.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U12"] = "ability_hunter_markedfordeath.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U13"] = "spell_shadow_twistedfaith.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U14"] = "Spell_deathknight_thrash_ghoul.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U15"] = "Spell_shadow_raisedead.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U16"] = ".blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U17"] = "Inv_misc_head_dragon_black.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U18"] = "inv_inscription_inkorange01.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U19"] = "inv_inscription_inkgreen03.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U20"] = "inv_misc_head_scourge_01.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U21"] = "Ability_druid_flightform.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U22"] = "spell_holy_circleofrenewal.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U23"] = "achievement_boss_lichking.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U24"] = "ability_warlock_eradication.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U25"] = "spell_shadow_deadofnight.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U26"] = "spell_arcane_prismaticcloak.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U27"] = "Spell_fire_elemental_totem.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U28"] = "Spell_fire_totemofwrath.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U29"] = "inv_jewelcrafting_truesilvercrab.blp",
--  ["Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U30"] = "inv_misc_food_92_lobster.blp",
--}

---------------------------------------------------------------------------------------------------
-- Functions for migration of SavedVariables settings
---------------------------------------------------------------------------------------------------

local function GetDefaultSettingsV1(defaults)
  local new_defaults = ThreatPlates.CopyTable(defaults)

  local db = new_defaults.profile
  db.allowClass = false
  db.friendlyClass = false
  db.optionRoleDetectionAutomatic = false
  --db.HeadlineView.width = 116
  db.text.amount = true
  db.AuraWidget.ModeBar.Texture = "Aluminium"
  db.uniqueWidget.scale = 35
  db.uniqueWidget.y = 24
  db.questWidget.ON = false
  db.questWidget.ShowInHeadlineView = false
  db.questWidget.ModeHPBar = true
  db.ResourceWidget.BarTexture = "Aluminium"
  db.settings.elitehealthborder.show = true
  db.settings.healthborder.texture = "TP_Border_Default"
  db.settings.healthbar.texture = "ThreatPlatesBar"
  db.settings.healthbar.backdrop = "ThreatPlatesEmpty"
  db.settings.healthbar.BackgroundOpacity = 1
  db.settings.castborder.texture = "TP_CastBarOverlay"
  db.settings.castbar.texture = "ThreatPlatesBar"
  db.settings.name.typeface = "Accidental Presidency"
  db.settings.name.width = 116
  db.settings.name.size = 14
  db.settings.level.typeface = "Accidental Presidency"
  db.settings.level.size = 12
  db.settings.level.height  = 14
  db.settings.level.x = 50
  db.settings.level.vertical = "TOP"
  db.settings.customtext.typeface = "Accidental Presidency"
  db.settings.customtext.size = 12
  db.settings.customtext.y = 1
  db.settings.spelltext.typeface = "Accidental Presidency"
  db.settings.spelltext.size = 12
  db.settings.spelltext.y = -13
  db.settings.spelltext.y_hv = -13
  db.settings.eliteicon.x = 64
  db.settings.eliteicon.y = 9
  db.settings.skullicon.x = 55
  db.settings.raidicon.y = 27
  db.threat.dps.HIGH = 1.25
  db.threat.tank.LOW = 1.25

  return new_defaults
end

local function SwitchToDefaultSettingsV1()
  local db = TidyPlatesThreat.db
  local current_profile = db:GetCurrentProfile()

  db:SetProfile("_ThreatPlatesInternal")

  local defaults = ThreatPlates.GetDefaultSettingsV1(ThreatPlates.DEFAULT_SETTINGS)
  db:RegisterDefaults(defaults)

  db:SetProfile(current_profile)
  db:DeleteProfile("_ThreatPlatesInternal")
end

local function SwitchToCurrentDefaultSettings()
  local db = TidyPlatesThreat.db
  local current_profile = db:GetCurrentProfile()

  db:SetProfile("_ThreatPlatesInternal")

  db:RegisterDefaults(ThreatPlates.DEFAULT_SETTINGS)

  db:SetProfile(current_profile)
  db:DeleteProfile("_ThreatPlatesInternal")
end

-- The version number must have a pattern like a.b.c; the rest of string (e.g., "Beta1" is ignored)
-- everything else (e.g., older version numbers) is set to 0
local function VersionToNumber(version)
  --  local len, v1, v2, v3, v4
  --  _, len, v1, v2 = version:find("(%d+)%.(%d+)")
  --  if len then
  --    version = version:sub(len + 1)
  --    _, len, v3 = version:find("%.(%d+)")
  --    if len then
  --      version = version:sub(len + 1)
  --      _, len, v4 = version:find("%.(%d+)")
  --    end
  --  end
  --
  --  return floor(v1 * 1e9 + v2 * 1e6 + v3 * 1e3 + v4)

  local v1, v2, v3 = version:match("(%d+)%.(%d+)%.(%d+)")
  v1, v2, v3 = v1 or 0, v2 or 0, v3 or 0

  return floor(v1 * 1e6 + v2 * 1e3 + v3)
end

local function CurrentVersionIsOlderThan(current_version, max_version)
  return VersionToNumber(current_version) < VersionToNumber(max_version)
end

local function DatabaseEntryExists(db, keys)
  for index = 1, #keys do
    db = db[keys[index]]
    if db == nil then
      return false
    end
  end
  return true
end

local function DatabaseEntryDelete(db, keys)
  for index = 1, #keys - 1 do
    db = db[keys[index]]
    if not db then
      return
    end
  end
  db[keys[#keys]] = nil
end

local function MigrateNamesColor(profile_name, profile)
  local entry = {"settings", "name", "color"}

  local old_color = { r = 1, g = 1, b = 1 }
  if DatabaseEntryExists(profile, entry) then
    local db = profile.settings.name
    local color = db.color

    color.r = color.r or old_color.r
    color.g = color.g or old_color.g
    color.b = color.b or old_color.b

    db.EnemyTextColor = ThreatPlates.CopyTable(color)
    db.FriendlyTextColor = ThreatPlates.CopyTable(color)

    DatabaseEntryDelete(profile, entry)
  end
end

local function MigrationBlizzFadeA(profile_name, profile)
  local entry = {"blizzFadeA" }

  if DatabaseEntryExists(profile, entry) then
    profile.nameplate = profile.nameplate or {}

    -- default for blizzFadeA.toggle was true
    if profile.blizzFadeA.toggle ~= nil then
      profile.nameplate.toggle = profile.nameplate.toggle or {}
      profile.nameplate.toggle.NonTargetA = profile.blizzFadeA.toggle
    end

    -- default for blizzFadeA.amount was -0.3
    if profile.blizzFadeA.amount ~= nil then
      profile.nameplate.alpha = profile.nameplate.alpha or {}

      local db = profile.nameplate.alpha
      local amount = profile.blizzFadeA.amount
      if amount <= 0 then
        db.NonTarget = min(1, 1 + amount)
      end
    end

    DatabaseEntryDelete(profile, entry)
  end
end

local function MigrationTargetScale(profile_name, profile)
  if DatabaseEntryExists(profile, { "nameplate", "scale", "Target" }) then
    profile.nameplate.scale.Target = profile.nameplate.scale.Target - 1
  end

  if DatabaseEntryExists(profile, { "nameplate", "scale", "NoTarget" }) then
    profile.nameplate.scale.NoTarget = profile.nameplate.scale.NoTarget - 1
  end
end

local function MigrateCustomTextShow(profile_name, profile)
  local entry = {"settings", "customtext", "show"}

  -- default for db.show was true
  if DatabaseEntryExists(profile, entry) then
    local db = profile.settings.customtext
    db.FriendlySubtext = "NONE"
    db.EnemySubtext = "NONE"

    DatabaseEntryDelete(profile, entry)
  end
end

local function MigrateCastbarColoring(profile_name, profile)
  -- default for castbarColor.toggle was true
  local entry = { "castbarColor", "toggle" }
  if DatabaseEntryExists(profile, entry) and profile.castbarColor.toggle == false then
    profile.castbarColor = RGB(255, 255, 0, 1)
    profile.castbarColorShield = RGB(255, 255, 0, 1)
    DatabaseEntryDelete(profile, entry)
    DatabaseEntryDelete(profile, { "castbarColorShield", "toggle" })
  end

  -- default for castbarColorShield.toggle was true
  local entry = { "castbarColorShield", "toggle" }
  if DatabaseEntryExists(profile, entry) and profile.castbarColorShield.toggle == false then
    profile.castbarColorShield = profile.castbarColor or { r = 1, g = 0.56, b = 0.06, a = 1 }
    DatabaseEntryDelete(profile, entry)
  end
end

local function MigrationTotemSettings(profile_name, profile)
  local entry = { "totemSettings" }
  if DatabaseEntryExists(profile, entry) then
    for key, value in pairs(profile.totemSettings) do
      if type(value) == "table" then -- omit hideHealthbar setting and skip if new default totem settings
        value.Style = value[7] or profile.totemSettings[key].Style
        value.Color = value.color or profile.totemSettings[key].Color
        if value[1] == false then
          value.ShowNameplate = false
        end
        if value[2] == false then
          value.ShowHPColor = false
        end
        if value[3] == false then
          value.ShowIcon = false
        end

        value[7] = nil
        value.color = nil
        value[1] = nil
        value[2] = nil
        value[3] = nil
      end
    end
  end
end

local function MigrateBorderTextures(profile_name, profile)
  if DatabaseEntryExists(profile, { "settings", "elitehealthborder", "texture" } ) then
    if profile.settings.elitehealthborder.texture == "TP_HealthBarEliteOverlay" then
      profile.settings.elitehealthborder.texture = "TP_EliteBorder_Default"
    else -- TP_HealthBarEliteOverlayThin
      profile.settings.elitehealthborder.texture = "TP_EliteBorder_Thin"
    end
  end

  if DatabaseEntryExists(profile, { "settings", "healthborder", "texture" } ) then
    if profile.settings.healthborder.texture == "TP_HealthBarOverlay" then
      profile.settings.healthborder.texture = "TP_Border_Default"
    else -- TP_HealthBarOverlayThin
      profile.settings.healthborder.texture = "TP_Border_Thin"
    end
  end

  if DatabaseEntryExists(profile, { "settings", "castborder", "texture" } ) then
    if profile.settings.castborder.texture == "TP_CastBarOverlay" then
      profile.settings.castborder.texture = "TP_Castbar_Border_Default"
    else -- TP_CastBarOverlayThin
      profile.settings.castborder.texture = "TP_Castbar_Border_Thin"
    end
  end
end

local function MigrationAurasSettings(profile_name, profile)
  if DatabaseEntryExists(profile, { "AuraWidget" } ) then
    profile.AuraWidget.Debuffs = profile.AuraWidget.Debuffs or {}
    profile.AuraWidget.Buffs = profile.AuraWidget.Buffs or {}
    profile.AuraWidget.CrowdControl = profile.AuraWidget.CrowdControl or {}

    if DatabaseEntryExists(profile, { "AuraWidget", "ShowDebuffsOnFriendly", } ) and profile.AuraWidget.ShowDebuffsOnFriendly then
      profile.AuraWidget.Debuffs.ShowFriendly = true
    end
    DatabaseEntryDelete(profile, { "AuraWidget", "ShowDebuffsOnFriendly", } )

    -- Don't migration FilterByType, does not make sense
    DatabaseEntryDelete(profile, { "AuraWidget", "FilterByType", } )


    if DatabaseEntryExists(profile, { "AuraWidget", "ShowFriendly", } ) and not profile.AuraWidget.ShowFriendly then
      profile.AuraWidget.Debuffs.ShowFriendly = false
      profile.AuraWidget.Buffs.ShowFriendly = false
      profile.AuraWidget.CrowdControl.ShowFriendly = false

      DatabaseEntryDelete(profile, { "AuraWidget", "ShowFriendly", } )
    end

    if DatabaseEntryExists(profile, { "AuraWidget", "ShowEnemy", } ) and not profile.AuraWidget.ShowEnemy then
      profile.AuraWidget.Debuffs.ShowEnemy = false
      profile.AuraWidget.Buffs.ShowEnemy = false
      profile.AuraWidget.CrowdControl.ShowEnemy = false

      DatabaseEntryDelete(profile, { "AuraWidget", "ShowEnemy", } )
    end

    if DatabaseEntryExists(profile, { "AuraWidget", "FilterBySpell", } ) then
      profile.AuraWidget.Debuffs.FilterBySpell = profile.AuraWidget.FilterBySpell
      DatabaseEntryDelete(profile, { "AuraWidget", "FilterBySpell", } )
    end

    if DatabaseEntryExists(profile, { "AuraWidget", "FilterMode", } ) then
      if profile.AuraWidget.FilterMode == "BLIZZARD" then
        profile.AuraWidget.Debuffs.FilterMode = "blacklist"
        profile.AuraWidget.Debuffs.ShowAllEnemy = false
        profile.AuraWidget.Debuffs.ShowOnlyMine = false
        profile.AuraWidget.Debuffs.ShowBlizzardForEnemy = true
      else
        profile.AuraWidget.Debuffs.FilterMode = profile.AuraWidget.FilterMode:gsub("Mine", "")
      end
      DatabaseEntryDelete(profile, { "AuraWidget", "FilterMode", } )
    end

    if DatabaseEntryExists(profile, { "AuraWidget", "scale", } ) then
      profile.AuraWidget.Debuffs.Scale = profile.AuraWidget.scale
      DatabaseEntryDelete(profile, { "AuraWidget", "scale", } )
    end
  end
end

local function MigrationAurasSettingsFix(profile_name, profile)
  if DatabaseEntryExists(profile, { "AuraWidget", "Debuffs", "FilterMode", } ) and profile.AuraWidget.Debuffs.FilterMode == "BLIZZARD" then
    profile.AuraWidget.Debuffs.FilterMode = "blacklist"
    profile.AuraWidget.Debuffs.ShowAllEnemy = false
    profile.AuraWidget.Debuffs.ShowOnlyMine = false
    profile.AuraWidget.Debuffs.ShowBlizzardForEnemy = true
  end
  if DatabaseEntryExists(profile, { "AuraWidget", "Buffs", "FilterMode", } ) and profile.AuraWidget.Buffs.FilterMode == "BLIZZARD" then
    profile.AuraWidget.Buffs.FilterMode = "blacklist"
  end
  if DatabaseEntryExists(profile, { "AuraWidget", "CrowdControl", "FilterMode", } ) and profile.AuraWidget.CrowdControl.FilterMode == "BLIZZARD" then
    profile.AuraWidget.CrowdControl.FilterMode = "blacklist"
  end
end

local function MigrateAuraWidget(profile_name, profile)
  if DatabaseEntryExists(profile, { "debuffWidget" }) then
    if not profile.AuraWidget.ON and not profile.AuraWidget.ShowInHeadlineView then
      profile.AuraWidget = profile.AuraWidget or {}
      profile.AuraWidget.ModeIcon = profile.AuraWidget.ModeIcon or {}

      local default_profile = ThreatPlates.DEFAULT_SETTINGS.profile.AuraWidget
      profile.AuraWidget.FilterMode = profile.debuffWidget.mode                     or default_profile.FilterMode
      profile.AuraWidget.ModeIcon.Style = profile.debuffWidget.style                or default_profile.ModeIcon.Style
      profile.AuraWidget.ShowTargetOnly = profile.debuffWidget.targetOnly           or default_profile.ShowTargetOnly
      profile.AuraWidget.ShowCooldownSpiral = profile.debuffWidget.cooldownSpiral   or default_profile.ShowCooldownSpiral
      profile.AuraWidget.ShowFriendly = profile.debuffWidget.showFriendly           or default_profile.ShowFriendly
      profile.AuraWidget.ShowEnemy = profile.debuffWidget.showEnemy                 or default_profile.ShowEnemy
      profile.AuraWidget.scale = profile.debuffWidget.scale                         or default_profile.scale

      if profile.debuffWidget.displays then
        profile.AuraWidget.FilterByType = ThreatPlates.CopyTable(profile.debuffWidget.displays)
      end

      if profile.debuffWidget.filter then
        profile.AuraWidget.FilterBySpell = ThreatPlates.CopyTable(profile.debuffWidget.filter)
      end

      -- DatabaseEntryDelete(profile, { "debuffWidget" }) -- TODO
    end
  end
end

local function MigrationForceFriendlyInCombat(profile_name, profile)
  if DatabaseEntryExists(profile, { "HeadlineView" }) then
    if profile.HeadlineView.ForceFriendlyInCombat == true then
      profile.HeadlineView.ForceFriendlyInCombat = "NAME"
    elseif profile.HeadlineView.ForceFriendlyInCombat == false then
      profile.HeadlineView.ForceFriendlyInCombat = "NONE"
    end
  end
end

local function SetValueOrDefault(old_value, default_value)
  if old_value ~= nil then
    return old_value
  else
    return default_value
  end
end

local function MigrationComboPointsWidget(profile_name, profile)
  if DatabaseEntryExists(profile, { "comboWidget" }) then
    profile.ComboPoints = profile.ComboPoints or {}

    local default_profile = ThreatPlates.DEFAULT_SETTINGS.profile.ComboPoints
    profile.ComboPoints.ON = SetValueOrDefault(profile.comboWidget.ON, default_profile.ON)
    profile.ComboPoints.Scale = SetValueOrDefault(profile.comboWidget.scale, default_profile.Scale)
    profile.ComboPoints.x = SetValueOrDefault(profile.comboWidget.x, default_profile.x)
    profile.ComboPoints.y = SetValueOrDefault(profile.comboWidget.y, default_profile.y)
    profile.ComboPoints.x_hv = SetValueOrDefault(profile.comboWidget.x_hv, default_profile.x_hv)
    profile.ComboPoints.y_hv = SetValueOrDefault(profile.comboWidget.y_hv, default_profile.y_hv)
    profile.ComboPoints.ShowInHeadlineView = SetValueOrDefault(profile.comboWidget.ShowInHeadlineView, default_profile.ShowInHeadlineView)

    DatabaseEntryDelete(profile, { "comboWidget" })
  end
end

local function MigrationThreatDetection(profile_name, profile)
  if DatabaseEntryExists(profile, { "threat", "nonCombat" }) then
    local default_profile = ThreatPlates.DEFAULT_SETTINGS.profile.threat
    profile.threat.UseThreatTable = SetValueOrDefault(profile.threat.nonCombat, default_profile.UseThreatTable)
    --DatabaseEntryDelete(profile, { "threat", "nonCombat" })
  end
end

local function GetValueOrDefault(old_value, default_value)
  if old_value ~= nil then
    return old_value
  else
    return default_value
  end
end

Addon.MigrationCustomNameplatesV1 = function()
  local defaults = ThreatPlates.CopyTable(TidyPlatesThreat.db.defaults)
  TidyPlatesThreat.db:RegisterDefaults({})

  -- Set default to empty so that new defaul values don't impact the migration
  for profile_name, profile in pairs(TidyPlatesThreat.db.profiles) do
    if DatabaseEntryExists(profile, { "uniqueSettings" }) then
      local settings = profile.uniqueSettings

      local custom_plates_to_keep = {}
      for index, unique_unit in pairs(settings) do
        -- Don't change entries map and ["**"]
        if type(index) == "number" then
          if unique_unit.name and unique_unit.name ~= "<Enter name here>" then
            custom_plates_to_keep[index] = unique_unit
          end

          settings[index] = nil
        end
      end

      local slot_counter = 0
      for index, unique_unit in pairs(custom_plates_to_keep) do
        -- As default values are now different, copy the deprecated slots default value
        local deprecated_settings = DEPRECATED_UNIQUE_SETTINGS[index] or DEPRECATED_UNIQUE_SETTINGS["**"]

        unique_unit.showNameplate = GetValueOrDefault(unique_unit.showNameplate, deprecated_settings.showNameplate)
        unique_unit.ShowHeadlineView = GetValueOrDefault(unique_unit.ShowHeadlineView, deprecated_settings.ShowHeadlineView)
        unique_unit.showIcon = GetValueOrDefault(unique_unit.showIcon, deprecated_settings.showIcon)
        unique_unit.useStyle = GetValueOrDefault(unique_unit.useStyle, deprecated_settings.useStyle)
        unique_unit.useColor = GetValueOrDefault(unique_unit.useColor, deprecated_settings.useColor)
        unique_unit.UseThreatColor = GetValueOrDefault(unique_unit.UseThreatColor, deprecated_settings.UseThreatColor)
        unique_unit.UseThreatGlow = GetValueOrDefault(unique_unit.UseThreatGlow, deprecated_settings.UseThreatGlow)
        unique_unit.allowMarked = GetValueOrDefault(unique_unit.allowMarked, deprecated_settings.allowMarked)
        unique_unit.overrideScale = GetValueOrDefault(unique_unit.overrideScale, deprecated_settings.overrideScale)
        unique_unit.overrideAlpha = GetValueOrDefault(unique_unit.overrideAlpha, deprecated_settings.overrideAlpha)
        -- Replace the old Threat Plates internal icons with the WoW original ones
        --unique_unit.icon = GetValueOrDefault(DEPRECATED_ICON_DEFAULTS[unique_unit.icon] or unique_unit.icon, DEPRECATED_ICON_DEFAULTS[deprecated_settings.icon])
        unique_unit.icon = GetValueOrDefault(unique_unit.icon, deprecated_settings.icon)
        unique_unit.SpellID = GetValueOrDefault(unique_unit.SpellID, deprecated_settings.SpellID)
        unique_unit.scale = GetValueOrDefault(unique_unit.scale, deprecated_settings.scale)
        unique_unit.alpha = GetValueOrDefault(unique_unit.alpha, deprecated_settings.alpha)

        unique_unit.color = GetValueOrDefault(unique_unit.color, {})
        unique_unit.color.r = GetValueOrDefault(unique_unit.color.r, deprecated_settings.color.r)
        unique_unit.color.g = GetValueOrDefault(unique_unit.color.g, deprecated_settings.color.g)
        unique_unit.color.b = GetValueOrDefault(unique_unit.color.b, deprecated_settings.color.b)

        -- #settings + 1 does not work here as settings also has entries for map, ** which interfere with #
        slot_counter = slot_counter + 1
        settings[slot_counter] = unique_unit
      end
    end
  end

  defaults.profile.uniqueSettings = ThreatPlates.CopyTable(ThreatPlates.DEFAULT_SETTINGS.profile.uniqueSettings)
  TidyPlatesThreat.db:RegisterDefaults(defaults)
  TidyPlatesThreat.db.global.CustomNameplatesVersion = 2
end

Addon.SetDefaultsForCustomNameplates = function()
  if TidyPlatesThreat.db.global.CustomNameplatesVersion > 1 then return end

  local defaults = ThreatPlates.CopyTable(TidyPlatesThreat.db.defaults)
  defaults.profile.uniqueSettings = DEPRECATED_UNIQUE_SETTINGS
  TidyPlatesThreat.db:RegisterDefaults(defaults)
end

---- Settings in the SavedVariables file that should be migrated and/or deleted
local DEPRECATED_SETTINGS = {
--  NamesColor = { MigrateNamesColor, },                        -- settings.name.color
--  CustomTextShow = { MigrateCustomTextShow, },                -- settings.customtext.show
--  BlizzFadeA = { MigrationBlizzFadeA, },                      -- blizzFadeA.toggle and blizzFadeA.amount
--  TargetScale = { MigrationTargetScale, "8.5.0" },            -- nameplate.scale.Target/NoTarget
--  --AuraWidget = { MigrateAuraWidget, "8.6.0" },              -- disabled until someone requests it
--  AlphaFeatures = { "alphaFeatures" },
--  AlphaFeatureHeadlineView = { "alphaFeatureHeadlineView" },
--  AlphaFeatureAuraWidget2= { "alphaFeatureAuraWidget2" },
--  AlphaFriendlyNameOnly = { "alphaFriendlyNameOnly" },
--  HVBlizzFarding = { "HeadlineView", "blizzFading" },         -- (removed in 8.5.1)
--  HVBlizzFadingAlpha = { "HeadlineView", "blizzFadingAlpha"}, -- (removed in 8.5.1)
--  HVNameWidth = { "HeadlineView", "name", "width" },          -- (removed in 8.5.0)
--  HVNameHeight = { "HeadlineView", "name", "height" },        -- (removed in 8.5.0)
--  DebuffWidget = { "debuffWidget" },                          -- (removed in 8.6.0)
--  OldSettings = { "OldSettings" },                            -- (removed in 8.7.0)
--  CastbarColoring = { MigrateCastbarColoring },              -- (removed in 8.7.0)
--  TotemSettings = { MigrationTotemSettings, "8.7.0" },        -- (changed in 8.7.0)
--  Borders = { MigrateBorderTextures, "8.7.0" },               -- (changed in 8.7.0)
--  UniqueSettingsList = { "uniqueSettings", "list" },          -- (removed in 8.7.0, cleanup added in 8.7.1)
--  Auras = { MigrationAurasSettings, "9.0.0" },                -- (changed in 9.0.0)
--  AurasFix = { MigrationAurasSettingsFix },                   -- (changed in 9.0.4 and 9.0.9)
--  MigrationComboPointsWidget = { MigrationComboPointsWidget, "9.1.0" },  -- (changed in 9.1.0)
--  ForceFriendlyInCombatEx = { MigrationForceFriendlyInCombat }, -- (changed in 9.1.0)
--  HeadlineViewEnableToggle = { "HeadlineView", "ON" },        -- (removed in 9.1.0)
--  ThreatDetection = { MigrationThreatDetection, "9.1.3" },  -- (changed in 9.1.0)
  -- hideNonCombat = { "threat", "hideNonCombat" },        -- (removed in ...)
  -- nonCombat = { "threat", "nonCombat" },                -- (removed in 9.1.0)
}

local function MigrateDatabase(current_version)
  TidyPlatesThreat.db.global.MigrationLog = nil
  --TidyPlatesThreat.db.global.MigrationLog = {}

  local profile_table = TidyPlatesThreat.db.profiles
  for key, entry in pairs(DEPRECATED_SETTINGS) do
    local action = entry[1]

    if type(action) == "function" then
      local max_version = entry[2]
      if not max_version or CurrentVersionIsOlderThan(current_version, max_version) then

        -- iterate over all profiles and migrate values
        --TidyPlatesThreat.db.global.MigrationLog[key] = "Migration" .. (max_version and ( " because " .. current_version .. " < " .. max_version) or "")
        for profile_name, profile in pairs(profile_table) do
          action(profile_name, profile)
        end
      end
    else
      -- iterate over all profiles and delete the old config entry
      --TidyPlatesThreat.db.global.MigrationLog[key] = "DELETED"
      for profile_name, profile in pairs(profile_table) do
        DatabaseEntryDelete(profile, entry)
      end
    end
  end
end

Addon.MigrateDatabase = MigrateDatabase

-----------------------------------------------------
-- External
-----------------------------------------------------

ThreatPlates.GetDefaultSettingsV1 = GetDefaultSettingsV1
ThreatPlates.SwitchToCurrentDefaultSettings = SwitchToCurrentDefaultSettings
ThreatPlates.SwitchToDefaultSettingsV1 = SwitchToDefaultSettingsV1
ThreatPlates.MigrateDatabase = MigrateDatabase

ThreatPlates.GetUnitVisibility = GetUnitVisibility
ThreatPlates.SetNamePlateClickThrough = SetNamePlateClickThrough
