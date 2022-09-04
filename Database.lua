local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Stuff for handling the database with the SavedVariables of ThreatPlates (ThreatPlatesDB)
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local floor, select, unpack, type, pairs = floor, select, unpack, type, pairs
local math_min = math.min

-- WoW APIs
local GetCVar = GetCVar
local UnitClass = UnitClass

-- ThreatPlates APIs
local L = ThreatPlates.L
local RGB = ThreatPlates.RGB

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: GetSpecialization

---------------------------------------------------------------------------------------------------
-- Global functions for accessing the configuration
---------------------------------------------------------------------------------------------------

if Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC then
  local GetShapeshiftFormID = GetShapeshiftFormID
  local BEAR_FORM, DIRE_BEAR_FORM = BEAR_FORM, 8

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
      return Addon.PlayerIsTank
    end,
    DEATHKNIGHT = function()
      return Addon.PlayerIsTank
    end,
    DEFAULT = function()
      return false
    end,
  }

  local PlayerIsTankByClassFunction = PLAYER_IS_TANK_BY_CLASS[Addon.PlayerClass] or PLAYER_IS_TANK_BY_CLASS["DEFAULT"]

  function Addon:PlayerRoleIsTank()
    local db = Addon.db
    if db.profile.optionRoleDetectionAutomatic then
      return PlayerIsTankByClassFunction()
    else
      return db.char.spec[1]
    end
  end

  -- Sets the role of the index spec or the active spec to tank (value = true) or dps/healing
  function Addon:SetRole(value)
    Addon.db.char.spec[1] = value
  end
else
  local PLAYER_ROLE_BY_SPEC = ThreatPlates.SPEC_ROLES[Addon.PlayerClass]

  function Addon:PlayerRoleIsTank()
    local db = Addon.db
    if db.profile.optionRoleDetectionAutomatic then
      return PLAYER_ROLE_BY_SPEC[_G.GetSpecialization()] or false
    else
      return db.char.spec[_G.GetSpecialization()]
    end
  end

  -- Sets the role of the index spec or the active spec to tank (value = true) or dps/healing
  function Addon:SetRole(value,index)
    if index then
      Addon.db.char.spec[index] = value
    else
      Addon.db.char.spec[_G.GetSpecialization()] = value
    end
  end
end

local function GetUnitVisibility(full_unit_type)
  local unit_visibility = Addon.db.profile.Visibility[full_unit_type]

  -- assert (Addon.db.profile.Visibility[full_unit_type], "missing unit type: ".. full_unit_type)

  local show = unit_visibility.Show
  if type(show) ~= "boolean" then
    show = (GetCVar(show) == "1")
  end

  return show, unit_visibility.UseHeadlineView
end

local function SetNamePlateClickThrough(friendly, enemy)
--  if InCombatLockdown() then
--    Addon.Logging.Info(L["Nameplate clickthrough cannot be changed while in combat."])
--  else
    local db = Addon.db.profile
    db.NamePlateFriendlyClickThrough = friendly
    db.NamePlateEnemyClickThrough = enemy
    Addon:CallbackWhenOoC(function()
      C_NamePlate.SetNamePlateFriendlyClickThrough(friendly)
      C_NamePlate.SetNamePlateEnemyClickThrough(enemy)
    end, L["Nameplate clickthrough cannot be changed while in combat."])
--  end
end

Addon.LEGACY_CUSTOM_NAMEPLATES = {
  ["**"] = {
    Name = "",
    Trigger = {
      Type = "Name",
      Name = {
        Input = "<Enter name here>",
        AsArray = {}, -- Generated after entering Input with Addon.Split
      },
      Aura = {
        Input = "",
        AsArray = {}, -- Generated after entering Input with Addon.Split
      },
      Cast = {
        Input = "",
        AsArray = {}, -- Generated after entering Input with Addon.Split
      },
      Script = {
        -- Only here to avoid Lua errors without adding to may checks for this particular trigger
        Input = "",
        AsArray = {}, -- Generated after entering Input with Addon.Split
      }
    },
    Effects = {
      Glow = {
        Frame = "None",
        Type = "Pixel",
        CustomColor = false,
        Color = { 0.95, 0.95, 0.32, 1 },
      },
    },
    showNameplate = true,
    ShowHeadlineView = false,
    Enable = {
      Never = false,
      UnitReaction = {
        FRIENDLY = true,
        NEUTRAL = true,
        HOSTILE = true,
      },
      OutOfInstances = true,
      InInstances = true,
      InstanceIDs = {
        Enabled = false,
        IDs = "",
      }
    },
    showIcon = true,
    useStyle = true,
    useColor = true,
    UseThreatColor = false,
    UseThreatGlow = false,
    allowMarked = true,
    overrideScale = false,
    overrideAlpha = false,
    UseAutomaticIcon = false, -- Default: true
    -- AutomaticIcon = "number",
    icon = "",                -- Default: "INV_Misc_QuestionMark.blp"
    -- SpellID = "number",
    -- SpellName = "string",
    scale = 1,
    alpha = 1,
    color = {
      r = 1,
      g = 1,
      b = 1,
    },
    Scripts = {
      Type = "Standard",
      Function = "OnUnitAdded",
      Event = "",
      Code = {
        Functions = {},
        Events = {},
        Legacy = {}
      },
    }
  },
  [1] = {
    Trigger = { Type = "Name"; Name = { Input = L["Shadow Fiend"], AsArray = { L["Shadow Fiend"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U1",
    scale = 0.45,
    color = {
      r = 0.61,
      g = 0.40,
      b = 0.86
    },
  },
  [2] = {
    Trigger = { Type = "Name"; Name = { Input = L["Spirit Wolf"], AsArray = { L["Spirit Wolf"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U2",
    scale = 0.45,
    color = {
      r = 0.32,
      g = 0.7,
      b = 0.89
    },
  },
  [3] = {
    Trigger = { Type = "Name"; Name = { Input = L["Ebon Gargoyle"], AsArray = { L["Ebon Gargoyle"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U3",
    scale = 0.45,
    color = {
      r = 1,
      g = 0.71,
      b = 0
    },
  },
  [4] = {
    Trigger = { Type = "Name"; Name = { Input = L["Water Elemental"], AsArray = { L["Water Elemental"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U4",
    scale = 0.45,
    color = {
      r = 0.33,
      g = 0.72,
      b = 0.44
    },
  },
  [5] = {
    Trigger = { Type = "Name"; Name = { Input = L["Treant"], AsArray = { L["Treant"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U5",
    scale = 0.45,
    color = {
      r = 1,
      g = 0.71,
      b = 0
    },
  },
  [6] = {
    Trigger = { Type = "Name"; Name = { Input = L["Viper"], AsArray = { L["Viper"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U6",
    scale = 0.45,
    color = {
      r = 0.39,
      g = 1,
      b = 0.11
    },
  },
  [7] = {
    Trigger = { Type = "Name"; Name = { Input = L["Venomous Snake"], AsArray = { L["Venomous Snake"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U6",
    scale = 0.45,
    color = {
      r = 0.75,
      g = 0,
      b = 0.02
    },
  },
  [8] = {
    Trigger = { Type = "Name"; Name = { Input = L["Army of the Dead Ghoul"], AsArray = { L["Army of the Dead Ghoul"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U7",
    scale = 0.45,
    color = {
      r = 0.87,
      g = 0.78,
      b = 0.88
    },
  },
  [9] = {
    Trigger = { Type = "Name"; Name = { Input = L["Shadowy Apparition"], AsArray = { L["Shadowy Apparition"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U8",
    color = {
      r = 0.62,
      g = 0.19,
      b = 1
    },
  },
  [10] = {
    Trigger = { Type = "Name"; Name = { Input = L["Shambling Horror"], AsArray = { L["Shambling Horror"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U9",
    color = {
      r = 0.69,
      g = 0.26,
      b = 0.25
    },
  },
  [11] = {
    Trigger = { Type = "Name"; Name = { Input = L["Web Wrap"], AsArray = { L["Web Wrap"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U10",
    scale = 0.75,
    color = {
      r = 1,
      g = 0.39,
      b = 0.96
    },
  },
  [12] = {
    Trigger = { Type = "Name"; Name = { Input = L["Immortal Guardian"], AsArray = { L["Immortal Guardian"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U11",
    color = {
      r = 0.33,
      g = 0.33,
      b = 0.33
    },
  },
  [13] = {
    Trigger = { Type = "Name"; Name = { Input = L["Marked Immortal Guardian"], AsArray = { L["Marked Immortal Guardian"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U12",
    color = {
      r = 0.75,
      g = 0,
      b = 0.02
    },
  },
  [14] = {
    Trigger = { Type = "Name"; Name = { Input = L["Empowered Adherent"], AsArray = { L["Empowered Adherent"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U13",
    color = {
      r = 0.29,
      g = 0.11,
      b = 1
    },
  },
  [15] = {
    Trigger = { Type = "Name"; Name = { Input = L["Deformed Fanatic"], AsArray = { L["Deformed Fanatic"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U14",
    color = {
      r = 0.55,
      g = 0.7,
      b = 0.29
    },
  },
  [16] = {
    Trigger = { Type = "Name"; Name = { Input = L["Reanimated Adherent"], AsArray = { L["Reanimated Adherent"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U15",
    color = {
      r = 1,
      g = 0.88,
      b = 0.61
    },
  },
  [17] = {
    Trigger = { Type = "Name"; Name = { Input = L["Reanimated Fanatic"], AsArray = { L["Reanimated Fanatic"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U15",
    color = {
      r = 1,
      g = 0.88,
      b = 0.61
    },
  },
  [18] = {
    Trigger = { Type = "Name"; Name = { Input = L["Bone Spike"], AsArray = { L["Bone Spike"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U16",
  },
  [19] = {
    Trigger = { Type = "Name"; Name = { Input = L["Onyxian Whelp"], AsArray = { L["Onyxian Whelp"] } } },
    showNameplate = false,
    ShowHealthbarView = true,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U17",
    color = {
      r = 0.33,
      g = 0.28,
      b = 0.71
    },
  },
  [20] = {
    Trigger = { Type = "Name"; Name = { Input = L["Gas Cloud"], AsArray = { L["Gas Cloud"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U18",
    color = {
      r = 0.96,
      g = 0.56,
      b = 0.07
    },
  },
  [21] = {
    Trigger = { Type = "Name"; Name = { Input = L["Volatile Ooze"], AsArray = { L["Volatile Ooze"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U19",
    color = {
      r = 0.36,
      g = 0.95,
      b = 0.33
    },
  },
  [22] = {
    Trigger = { Type = "Name"; Name = { Input = L["Darnavan"], AsArray = { L["Darnavan"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U20",
    color = {
      r = 0.78,
      g = 0.61,
      b = 0.43
    },
  },
  [23] = {
    Trigger = { Type = "Name"; Name = { Input = L["Val'kyr Shadowguard"], AsArray = { L["Val'kyr Shadowguard"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U21",
    color = {
      r = 0.47,
      g = 0.89,
      b = 1
    },
  },
  [24] = {
    Trigger = { Type = "Name"; Name = { Input = L["Kinetic Bomb"], AsArray = { L["Kinetic Bomb"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U22",
    color = {
      r = 0.91,
      g = 0.71,
      b = 0.1
    },
  },
  [25] = {
    Trigger = { Type = "Name"; Name = { Input = L["Lich King"], AsArray = { L["Lich King"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U23",
    color = {
      r = 0.77,
      g = 0.12,
      b = 0.23
    },
  },
  [26] = {
    Trigger = { Type = "Name"; Name = { Input = L["Raging Spirit"], AsArray = { L["Raging Spirit"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U24",
    color = {
      r = 0.77,
      g = 0.27,
      b = 0
    },
  },
  [27] = {
    Trigger = { Type = "Name"; Name = { Input = L["Drudge Ghoul"], AsArray = { L["Drudge Ghoul"] } } },
    showIcon = false,
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U25",
    scale = 0.85,
    color = {
      r = 0.43,
      g = 0.43,
      b = 0.43
    },
  },
  [28] = {
    Trigger = { Type = "Name"; Name = { Input = L["Living Inferno"], AsArray = { L["Living Inferno"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U27",
    color = {
      r = 0,
      g = 1,
      b = 0
    },
  },
  [29] = {
    Trigger = { Type = "Name"; Name = { Input = L["Living Ember"], AsArray = { L["Living Ember"] } } },
    showIcon = false,
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
    Trigger = { Type = "Name"; Name = { Input = L["Fanged Pit Viper"], AsArray = { L["Fanged Pit Viper"] } } },
    showNameplate = false,
    ShowHealthbarView = true,
    showIcon = false,
    scale = 0,
    alpha = 0,
  },
  [31] = {
    Trigger = { Type = "Name"; Name = { Input = L["Canal Crab"], AsArray = { L["Canal Crab"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U29",
    color = {
      r = 0,
      g = 1,
      b = 1
    },
  },
  [32] = {
    Trigger = { Type = "Name"; Name = { Input = L["Muddy Crawfish"], AsArray = { L["Muddy Crawfish"] } } },
    icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U30",
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
  db.AuraWidget.Buffs.ModeBar.Texture = "Aluminium"
  db.AuraWidget.Debuffs.ModeBar.Texture = "Aluminium"
  db.AuraWidget.CrowdControl.ModeBar.Texture = "Aluminium"
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
  db.settings.eliteicon.x = 64
  db.settings.eliteicon.y = 9
  db.settings.skullicon.x = 55
  db.settings.raidicon.y = 27
  db.threat.dps.HIGH = 1.25
  db.threat.tank.LOW = 1.25

  return new_defaults
end

local function SwitchToDefaultSettingsV1()
  local db = Addon.db
  local current_profile = db:GetCurrentProfile()

  db:SetProfile("_ThreatPlatesInternal")

  local defaults = ThreatPlates.GetDefaultSettingsV1(ThreatPlates.DEFAULT_SETTINGS)
  db:RegisterDefaults(defaults)

  db:SetProfile(current_profile)
  db:DeleteProfile("_ThreatPlatesInternal")
end

local function SwitchToCurrentDefaultSettings()
  local db = Addon.db
  local current_profile = db:GetCurrentProfile()

  db:SetProfile("_ThreatPlatesInternal")

  db:RegisterDefaults(ThreatPlates.DEFAULT_SETTINGS)

  db:SetProfile(current_profile)
  db:DeleteProfile("_ThreatPlatesInternal")
end

-- The version number must have a pattern like a.b.c; the rest of string (e.g., "Beta1" is ignored)
-- everything else (e.g., older version numbers) is set to 0
local function VersionToNumber(version)
  local v1, v2, v3 = version:match("(%d+)%.(%d+)%.(%d+)")
  v1, v2, v3 = v1 or 0, v2 or 0, v3 or 0

  local v_alpha = version:match("alpha(%d+)") or 255
  local v_beta = version:match("beta(%d+)") or 255

  return floor(v1 * 1e6 + v2 * 1e3 + v3), floor(v_beta * 1e3 + v_alpha)
end

local function CurrentVersionIsOlderThan(current_version, max_version)
  local current_version_no, current_version_test = VersionToNumber(current_version)
  local max_version_no, max_version_test = VersionToNumber(max_version)

  if current_version_no == max_version_no then
    return current_version_test < max_version_test
  else
    return current_version_no < max_version_no
  end
end
Addon.CurrentVersionIsOlderThan = CurrentVersionIsOlderThan

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

local function GetValueOrDefault(old_value, default_value)
  if old_value ~= nil then
    return old_value
  else
    return default_value
  end
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
        db.NonTarget = math_min(1, 1 + amount)
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

local function MigrationComboPointsWidget(profile_name, profile)
  if DatabaseEntryExists(profile, { "comboWidget" }) then
    profile.ComboPoints = profile.ComboPoints or {}

    local default_profile = ThreatPlates.DEFAULT_SETTINGS.profile.ComboPoints
    profile.ComboPoints.ON = GetValueOrDefault(profile.comboWidget.ON, default_profile.ON)
    profile.ComboPoints.Scale = GetValueOrDefault(profile.comboWidget.scale, default_profile.Scale)
    profile.ComboPoints.x = GetValueOrDefault(profile.comboWidget.x, default_profile.x)
    profile.ComboPoints.y = GetValueOrDefault(profile.comboWidget.y, default_profile.y)
    profile.ComboPoints.x_hv = GetValueOrDefault(profile.comboWidget.x_hv, default_profile.x_hv)
    profile.ComboPoints.y_hv = GetValueOrDefault(profile.comboWidget.y_hv, default_profile.y_hv)
    profile.ComboPoints.ShowInHeadlineView = GetValueOrDefault(profile.comboWidget.ShowInHeadlineView, default_profile.ShowInHeadlineView)

    DatabaseEntryDelete(profile, { "comboWidget" })
  end
end

local function MigrationThreatDetection(profile_name, profile)
  if DatabaseEntryExists(profile, { "threat", "nonCombat" }) then
    local default_profile = ThreatPlates.DEFAULT_SETTINGS.profile.threat
    profile.threat.UseThreatTable = GetValueOrDefault(profile.threat.nonCombat, default_profile.UseThreatTable)
    --DatabaseEntryDelete(profile, { "threat", "nonCombat" })
  end
end

local function MigrationCustomPlatesV1(profile_name, profile)
  -- This migration function is called with an empty default profile, so CustomNameplatesVersion is nil if it is still the default value (1)
  if Addon.db.global.CustomNameplatesVersion then return end

  if DatabaseEntryExists(profile, { "uniqueSettings" }) then
    local custom_styles = profile.uniqueSettings
    local custom_plates_to_keep = {}

    for index, unique_unit in pairs(custom_styles) do

      -- Don't change entries map and ["**"]
      if type(index) == "number" then
        -- Trigger.Type must be Name as before migration (in V1) that's the only trigger type available
        if DatabaseEntryExists(unique_unit, { "Trigger", "Name", "Input" }) and unique_unit.Trigger.Name.Input ~= "<Enter name here>" then
          -- and unique_unit.Trigger.Name.Input ~= nil
          custom_plates_to_keep[index] = unique_unit
        end
      end

      custom_styles[index] = nil
    end

    for index, unique_unit in pairs(custom_plates_to_keep) do
      -- As default values are now different, copy the deprecated slots default value
      local deprecated_settings = ThreatPlates.CopyTable(Addon.LEGACY_CUSTOM_NAMEPLATES["**"])
      Addon.MergeIntoTable(deprecated_settings, Addon.LEGACY_CUSTOM_NAMEPLATES[index])

      -- Name trigger is already migrated properly when loading 9.2.0 the very first time
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
      unique_unit.UseAutomaticIcon = GetValueOrDefault(unique_unit.UseAutomaticIcon, deprecated_settings.UseAutomaticIcon)
      unique_unit.SpellID = GetValueOrDefault(unique_unit.SpellID, deprecated_settings.SpellID)
      unique_unit.scale = GetValueOrDefault(unique_unit.scale, deprecated_settings.scale)
      unique_unit.alpha = GetValueOrDefault(unique_unit.alpha, deprecated_settings.alpha)

      unique_unit.color = GetValueOrDefault(unique_unit.color, {})
      unique_unit.color.r = GetValueOrDefault(unique_unit.color.r, deprecated_settings.color.r)
      unique_unit.color.g = GetValueOrDefault(unique_unit.color.g, deprecated_settings.color.g)
      unique_unit.color.b = GetValueOrDefault(unique_unit.color.b, deprecated_settings.color.b)

      custom_styles[#custom_styles + 1] = unique_unit
    end
  end
end

local function MigrateCustomStylesToV3(profile_name, profile)
  -- if Addon.db.global.CustomNameplatesVersion > 2 then return end

  if DatabaseEntryExists(profile, { "uniqueSettings" }) then
    local custom_styles = profile.uniqueSettings

    custom_styles.map = nil

    for index, unique_unit in pairs(custom_styles) do
      unique_unit.Trigger = unique_unit.Trigger or {}
      unique_unit.Trigger.Name = unique_unit.Trigger.Name or {}

      if unique_unit.name and unique_unit.name ~= "<Enter name here>" and (unique_unit.Trigger.Name.Input == nil or unique_unit.Trigger.Name.Input == "<Enter name here>") and (unique_unit.Trigger.Type == nil or unique_unit.Trigger.Type == "Name") then
        unique_unit.Trigger.Type = "Name" -- should not be necessary as it is the default value
        unique_unit.Trigger.Name.Input = unique_unit.name
        unique_unit.Trigger.Name.AsArray = { unique_unit.Trigger.Name.Input }

        -- Set automatic icon detection for all existing custom nameplates to false
        unique_unit.UseAutomaticIcon = false
        unique_unit.icon = GetValueOrDefault(unique_unit.icon, (Addon.IS_CLASSIC and "Spell_nature_spiritwolf.blp") or "spell_shadow_shadowfiend.blp")
      end
    end
  end
end

local function MigrateSpelltextPosition(profile_name, profile)
  if DatabaseEntryExists(profile, { "settings", "spelltext" } ) then
    local default_profile = ThreatPlates.DEFAULT_SETTINGS.profile

    profile.settings = profile.settings or {}
    profile.settings.castbar = profile.settings.castbar or {}
    profile.settings.castbar.SpellNameText = profile.settings.castbar.SpellNameText or {}

    if DatabaseEntryExists(profile, { "settings", "spelltext", "x" } ) then
      profile.settings.castbar.SpellNameText.HorizontalOffset = profile.settings.spelltext.x - 2
      profile.settings.spelltext = profile.settings.spelltext or {}
      profile.settings.spelltext.align = GetValueOrDefault(profile.settings.spelltext.align, "CENTER")
    end

    if DatabaseEntryExists(profile, { "settings", "spelltext", "y" } ) then
      profile.settings.castbar.SpellNameText.VerticalOffset = profile.settings.spelltext.y + 15
      profile.settings.spelltext = profile.settings.spelltext or {}
      profile.settings.spelltext.vertical = GetValueOrDefault(profile.settings.spelltext.vertical, "CENTER")
    end

    DatabaseEntryDelete(profile, { "settings", "spelltext", "x" })
    DatabaseEntryDelete(profile, { "settings", "spelltext", "y" })
    DatabaseEntryDelete(profile, { "settings", "spelltext", "x_hv" })
    DatabaseEntryDelete(profile, { "settings", "spelltext", "y_hv" })
  end
end

local function FixTargetFocusTexture(profile_name, profile)
  if DatabaseEntryExists(profile, { "targetWidget", "theme" } ) then
    if not Addon.TARGET_TEXTURES[profile.targetWidget.theme] then
      profile.targetWidget.theme = ThreatPlates.DEFAULT_SETTINGS.profile.targetWidget.theme
    end
  end

  if DatabaseEntryExists(profile, { "FocusWidget", "theme" } ) then
    if not Addon.TARGET_TEXTURES[profile.FocusWidget.theme] then
      profile.FocusWidget.theme = ThreatPlates.DEFAULT_SETTINGS.profile.FocusWidget.theme
    end
  end
end

local function RenameFilterMode(profile_name, profile)
  local FilterModeMapping = {
    whitelist = "Allow",
    blacklist = "Block",
    all = "None",
  }

  -- Part after or is just a fail-save, should never be called (as code is only executed once, after 9.3.0).
  if DatabaseEntryExists(profile, { "AuraWidget", "Debuffs", "FilterMode" } ) then
    profile.AuraWidget.Debuffs.FilterMode = FilterModeMapping[profile.AuraWidget.Debuffs.FilterMode] or profile.AuraWidget.Debuffs.FilterMode
  end
  if DatabaseEntryExists(profile, { "AuraWidget", "Buffs", "FilterMode" } ) then
    profile.AuraWidget.Buffs.FilterMode = FilterModeMapping[profile.AuraWidget.Buffs.FilterMode] or profile.AuraWidget.Buffs.FilterMode
  end
  if DatabaseEntryExists(profile, { "AuraWidget", "CrowdControl", "FilterMode" } ) then
    profile.AuraWidget.CrowdControl.FilterMode = FilterModeMapping[profile.AuraWidget.CrowdControl.FilterMode] or profile.AuraWidget.CrowdControl.FilterMode
  end
end

local function MigrateCustomStyles(profile_name, profile)
  if DatabaseEntryExists(profile, { "uniqueSettings" }) then
    local custom_styles = profile.uniqueSettings

    custom_styles.map = nil

    for index, imported_custom_style in pairs(custom_styles) do
      -- Import all values from the custom style as long the are valid entries with the correct type
      -- based on the default custom style "**"
      local custom_style = Addon.ImportCustomStyle(imported_custom_style)
      custom_styles[index] = custom_style

      -- If there is no WoW event after the migration, set the currently selected event to nil
      if not next(custom_style.Scripts.Code.Events) then
        custom_style.Scripts.Event = ""
      end
    end
  end
end

local function DisableShowBlizzardAurasForClassic(profile_name, profile)
  if DatabaseEntryExists(profile, { "AuraWidget", "Debuffs", } ) then
    if profile.AuraWidget.Debuffs.ShowBlizzardForFriendly then
      profile.AuraWidget.Debuffs.ShowAllFriendly = true
      profile.AuraWidget.Debuffs.ShowBlizzardForFriendly = false
      profile.AuraWidget.Debuffs.ShowDispellable = false
      profile.AuraWidget.Debuffs.ShowBoss = false
    end

    if profile.AuraWidget.Debuffs.ShowBlizzardForEnemy then
      profile.AuraWidget.Debuffs.ShowOnlyMine = true
    end
  end
  if DatabaseEntryExists(profile, { "AuraWidget", "CrowdControl", } ) then
    if profile.AuraWidget.CrowdControl.ShowBlizzardForFriendly then
      profile.AuraWidget.CrowdControl.ShowAllFriendly = true
      profile.AuraWidget.CrowdControl.ShowBlizzardForFriendly = false
      profile.AuraWidget.CrowdControl.ShowDispellable = false
      profile.AuraWidget.CrowdControl.ShowBoss = false
    end

    if profile.AuraWidget.CrowdControl.ShowBlizzardForEnemy then
      profile.AuraWidget.CrowdControl.ShowAllEnemy = true
      profile.AuraWidget.CrowdControl.ShowBlizzardForEnemy = false
    end
  end
end

local function MigrateAurasWidgetV2(_, profile)
  local default_profile = ThreatPlates.DEFAULT_SETTINGS.profile

  local function MigrateFontSettings(aura_type, font_area)
    local profile_aura_type_modebar = profile.AuraWidget[aura_type].ModeBar
    local default_profile_modebar = default_profile.AuraWidget[aura_type].ModeBar

    profile_aura_type_modebar[font_area] = profile_aura_type_modebar[font_area] or {}
    profile_aura_type_modebar[font_area].Font = profile_aura_type_modebar[font_area].Font or {}

    profile_aura_type_modebar[font_area].Font.Typeface = GetValueOrDefault(profile.AuraWidget.ModeBar.Font, default_profile_modebar[font_area].Font.Typeface)
    if aura_type ~= "CrowdControl" then
      profile_aura_type_modebar[font_area].Font.Size = GetValueOrDefault(profile.AuraWidget.ModeBar.FontSize, default_profile_modebar[font_area].Font.Size)
      profile_aura_type_modebar[font_area].Font.Color = GetValueOrDefault(profile.AuraWidget.ModeBar.FontColor, default_profile_modebar[font_area].Font.Color)
    end
  end

  local function MigrateAuraTypeEntry(aura_type)
    --if DatabaseEntryExists(profile, { "AuraWidget", aura_type} ) then
    local default_profile_aura_type = default_profile.AuraWidget[aura_type]
    local profile_aura_type = profile.AuraWidget[aura_type]
    local profile_aura_widget = profile.AuraWidget

    profile_aura_type.ModeIcon = profile_aura_type.ModeIcon or {}
    profile_aura_type.ModeBar = profile_aura_type.ModeBar or {}
    -- For the CrowdControl area, only migrate some selected settings, as most settings for icon/bar mode are meant for buffs/debuffs
    if aura_type ~= "CrowdControl" then
      profile_aura_type.AlignmentV = GetValueOrDefault(profile_aura_widget.AlignmentV, default_profile_aura_type.AlignmentV)
      profile_aura_type.AlignmentH = GetValueOrDefault(profile_aura_widget.AlignmentH, default_profile_aura_type.AlignmentH)
      profile_aura_type.CenterAuras = GetValueOrDefault(profile_aura_widget.CenterAuras, default_profile_aura_type.CenterAuras)

      Addon.MergeIntoTable(profile_aura_type.ModeIcon, profile_aura_widget.ModeIcon)
      Addon.MergeIntoTable(profile_aura_type.ModeBar, profile_aura_widget.ModeBar)
    end

    if profile_aura_type.Scale then
      profile_aura_type.ModeIcon.Style = "custom" -- If scale was changed, style must be custom so that the custom icon size is used
      profile_aura_type.ModeIcon.IconWidth = profile_aura_type.Scale * default_profile_aura_type.ModeIcon.IconWidth
      profile_aura_type.ModeIcon.IconHeight = profile_aura_type.Scale * default_profile_aura_type.ModeIcon.IconHeight
    end

    if DatabaseEntryExists(profile, { "AuraWidget", "ModeBar"} ) then
      MigrateFontSettings(aura_type, "Label")
      MigrateFontSettings(aura_type, "Duration")
      MigrateFontSettings(aura_type, "StackCount")

      if aura_type ~= "CrowdControl" then
        profile_aura_type.ModeBar.Label.HorizontalOffset = GetValueOrDefault(profile_aura_widget.ModeBar.LabelTextIndent, default_profile_aura_type.ModeBar.Label.HorizontalOffset)
        profile_aura_type.ModeBar.Duration.HorizontalOffset = GetValueOrDefault(profile_aura_widget.ModeBar.TimeTextIndent, default_profile_aura_type.ModeBar.Duration.HorizontalOffset)
      end
    end
    --end
  end

  if DatabaseEntryExists(profile, { "AuraWidget", } ) then
    profile.AuraWidget.Buffs = profile.AuraWidget.Buffs or {}
    profile.AuraWidget.Debuffs = profile.AuraWidget.Debuffs or {}
    profile.AuraWidget.CrowdControl = profile.AuraWidget.CrowdControl or {}

    profile.AuraWidget.Debuffs.HealthbarMode = profile.AuraWidget.Debuffs.HealthbarMode or {}
    profile.AuraWidget.Debuffs.NameMode = profile.AuraWidget.Debuffs.NameMode or {}

    profile.AuraWidget.Debuffs.HealthbarMode.HorizontalOffset = GetValueOrDefault(profile.AuraWidget.x, default_profile.AuraWidget.Debuffs.HealthbarMode.HorizontalOffset)
    profile.AuraWidget.Debuffs.HealthbarMode.VerticalOffset = GetValueOrDefault(profile.AuraWidget.y, default_profile.AuraWidget.Debuffs.HealthbarMode.VerticalOffset)
    profile.AuraWidget.Debuffs.HealthbarMode.Anchor = GetValueOrDefault(profile.AuraWidget.anchor, default_profile.AuraWidget.Debuffs.HealthbarMode.Anchor)
    profile.AuraWidget.Debuffs.NameMode.HorizontalOffset = GetValueOrDefault(profile.AuraWidget.x, default_profile.AuraWidget.Debuffs.NameMode.HorizontalOffset)
    profile.AuraWidget.Debuffs.NameMode.VerticalOffset = GetValueOrDefault(profile.AuraWidget.y, default_profile.AuraWidget.Debuffs.NameMode.VerticalOffset)
    profile.AuraWidget.Debuffs.NameMode.Anchor = GetValueOrDefault(profile.AuraWidget.anchor, default_profile.AuraWidget.Debuffs.NameMode.Anchor)

    profile.AuraWidget.Buffs.ModeBar = profile.AuraWidget.Buffs.ModeBar or {}
    profile.AuraWidget.Debuffs.ModeBar = profile.AuraWidget.Debuffs.ModeBar or {}
    profile.AuraWidget.CrowdControl.ModeBar = profile.AuraWidget.CrowdControl.ModeBar or {}

    MigrateAuraTypeEntry("Buffs")
    MigrateAuraTypeEntry("Debuffs")
    MigrateAuraTypeEntry("CrowdControl")

    if DatabaseEntryExists(profile, { "AuraWidget", "ModeBar"} ) then
      profile.AuraWidget.Buffs.ModeBar.Enabled = GetValueOrDefault(profile.AuraWidget.ModeBar.Enabled, default_profile.AuraWidget.Buffs.ModeBar.Enabled)
      profile.AuraWidget.Debuffs.ModeBar.Enabled = GetValueOrDefault(profile.AuraWidget.ModeBar.Enabled, default_profile.AuraWidget.Debuffs.ModeBar.Enabled)
    end

    DatabaseEntryDelete(profile, { "AuraWidget", "x" })
    DatabaseEntryDelete(profile, { "AuraWidget", "y" })
    DatabaseEntryDelete(profile, { "AuraWidget", "x_hv" }) -- never used
    DatabaseEntryDelete(profile, { "AuraWidget", "y_hv" }) -- never used
    DatabaseEntryDelete(profile, { "AuraWidget", "anchor" })
    DatabaseEntryDelete(profile, { "AuraWidget", "AlignmentH" })
    DatabaseEntryDelete(profile, { "AuraWidget", "AlignmentV" })
    DatabaseEntryDelete(profile, { "AuraWidget", "CenterAuras" })

    DatabaseEntryDelete(profile, { "AuraWidget", "Buffs", "Scale" })
    DatabaseEntryDelete(profile, { "AuraWidget", "Debuffs", "Scale" })
    DatabaseEntryDelete(profile, { "AuraWidget", "CrowdControl", "Scale" })

    DatabaseEntryDelete(profile, { "AuraWidget", "ModeIcon" })
    DatabaseEntryDelete(profile, { "AuraWidget", "ModeBar" })
  end
end

local function MigrateFixAurasCyclicAnchoring(_, profile)
  local buffs_anchor_to = ThreatPlates.DEFAULT_SETTINGS.profile.AuraWidget.Buffs.AnchorTo
  local debuffs_anchor_to = ThreatPlates.DEFAULT_SETTINGS.profile.AuraWidget.Debuffs.AnchorTo
  local cc_anchor_to = ThreatPlates.DEFAULT_SETTINGS.profile.AuraWidget.CrowdControl.AnchorTo

  if DatabaseEntryExists(profile, { "AuraWidget", "Buffs", "AnchorTo" } ) then
    buffs_anchor_to = profile.AuraWidget.Buffs.AnchorTo
  end
  if DatabaseEntryExists(profile, { "AuraWidget", "Debuffs", "AnchorTo" } ) then
    debuffs_anchor_to = profile.AuraWidget.Debuffs.AnchorTo
  end
  if DatabaseEntryExists(profile, { "AuraWidget", "CrowdControl", "AnchorTo" } ) then
    cc_anchor_to = profile.AuraWidget.CrowdControl.AnchorTo
  end

  -- Should not be necessary, just to be sure
  profile.AuraWidget = profile.AuraWidget or {}
  profile.AuraWidget.Debuffs = profile.AuraWidget.Debuffs or {}
  profile.AuraWidget.Buffs = profile.AuraWidget.Buffs or {}

  -- Check for cyclic dependencies
  if buffs_anchor_to == "Debuffs" and debuffs_anchor_to == "Buffs" then
    profile.AuraWidget.Debuffs.AnchorTo = "Healthbar"
  elseif buffs_anchor_to == "CrowdControl" and cc_anchor_to == "Buffs" then
    profile.AuraWidget.Buffs.AnchorTo = "Healthbar"
  elseif debuffs_anchor_to == "CrowdControl" and cc_anchor_to == "Debuffs" then
    profile.AuraWidget.Debuffs.AnchorTo = "Healthbar"
  end
end

local function MigrateThreatValue(_, profile)
  local default_profile = ThreatPlates.DEFAULT_SETTINGS.profile

  if DatabaseEntryExists(profile, { "threatWidget", "ThreatPercentage" } ) then
    profile.threatWidget.ThreatPercentage.ShowInGroups = GetValueOrDefault(profile.threatWidget.ThreatPercentage.OnlyInGroups, default_profile.threatWidget.ThreatPercentage.OnlyInGroups)
    print (profile.threatWidget.ThreatPercentage.Show)
    if profile.threatWidget.ThreatPercentage.Show == false then
      profile.threatWidget.ThreatPercentage.ShowAlways = false -- is also the default value
      profile.threatWidget.ThreatPercentage.ShowInGroups = false
      profile.threatWidget.ThreatPercentage.ShowWithPet = false
    end
  end

  DatabaseEntryDelete(profile, { "threatWidget", "ThreatPercentage", "Show" })
  DatabaseEntryDelete(profile, { "threatWidget", "ThreatPercentage", "OnlyInGroups" })
end

local TEST_FUNCTIONS = {
  MigrateFixAurasCyclicAnchoring = MigrateFixAurasCyclicAnchoring
}

Addon.TestMigrateDatabase = function(migration_function)
  local profile_table = Addon.db.profiles
  local current_profile = Addon.db:GetCurrentProfile()

  -- local defaults = ThreatPlates.CopyTable(Addon.db.defaults)
  -- Addon.db:RegisterDefaults({})

  TEST_FUNCTIONS[migration_function](current_profile, Addon.db.profiles[current_profile])

  -- Addon.db:RegisterDefaults(defaults)

  -- Cleanup database - remove default values from SavedVariables
  for profile_name, profile in pairs(profile_table) do
    Addon.db:SetProfile(profile_name)
  end
  Addon.db:SetProfile(current_profile)
end

-- Settings in the SavedVariables file that should be migrated and/or deleted
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
  { "debuffWidget" },                                                     -- (removed in 8.6.0)
  { "OldSettings" },                                                      -- (removed in 8.7.0)
  { MigrateCastbarColoring },                                             -- (removed in 8.7.0)
  { MigrationTotemSettings, "8.7.0", Version = not Addon.IS_CLASSIC },    -- (changed in 8.7.0)
  { MigrateBorderTextures, "8.7.0", Version = not Addon.IS_CLASSIC },   -- (changed in 8.7.0)
  { "uniqueSettings", "list" },                                           -- (removed in 8.7.0, cleanup added in 8.7.1)
  { MigrationAurasSettings, "9.0.0", Version = not Addon.IS_CLASSIC },    -- (changed in 9.0.0)
  { MigrationAurasSettingsFix },                                          -- (changed in 9.0.4 and 9.0.9)
  { MigrationComboPointsWidget, "9.1.0", Version = not Addon.IS_CLASSIC },-- (changed in 9.1.0)
  { MigrationForceFriendlyInCombat },                                     -- (changed in 9.1.0)
  { "HeadlineView", "ON" },                                               -- (removed in 9.1.0)
  { MigrationThreatDetection, "9.1.3", Version = not Addon.IS_CLASSIC },  -- (changed in 9.1.0)
  -- { "threat", "hideNonCombat" },                                       -- (removed in ...)
  -- { "threat", "nonCombat" },                                           -- (removed in 9.1.0)
  { MigrateCustomStylesToV3, (Addon.IS_CLASSIC and "1.4.0") or "9.2.2" },
  { MigrateSpelltextPosition, (Addon.IS_CLASSIC and "1.4.0") or "9.2.0", NoDefaultProfile = true },
  { FixTargetFocusTexture, NoDefaultProfile = true },
  { RenameFilterMode, NoDefaultProfile = true, "9.3.0"},
  { "cache" },
  { "Automation", "SmallPlatesInInstances" }, -- Removed in 10.1.8
  { "CVarsBackup", "nameplateGlobalScale" },  -- Removed in 10.1.8
  { MigrationCustomPlatesV1, NoDefaultProfile = true, "10.2.0"},
  { MigrateCustomStyles, NoDefaultProfile = true, "10.2.0", CleanupDatabase = true },
  { DisableShowBlizzardAurasForClassic, "10.2.1", Version = (Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC) },
  { MigrateAurasWidgetV2, "10.3.0-beta2", NoDefaultProfile = true , CleanupDatabase = true },
  { "AuraWidget", "scale" },  -- Removed in 10.3.0
  { MigrateFixAurasCyclicAnchoring, "10.3.1", NoDefaultProfile = true, CleanupDatabase = true },
  { MigrateThreatValue, "10.3.6", NoDefaultProfile = true, CleanupDatabase = true },
}

local function MigrateDatabase(current_version)
  Addon.db.global.MigrationLog = nil
  --Addon.db.global.MigrationLog = {}

  local cleanup_database_after_migration = false
  local profile_table = Addon.db.profiles
  for index, entry in ipairs(DEPRECATED_SETTINGS) do
    local action = entry[1]

    if type(action) == "function" then
      if entry.Version == nil or entry.Version == true then
        local max_version = entry[2]
        if not max_version or CurrentVersionIsOlderThan(current_version, max_version) then
          local defaults
          if entry.NoDefaultProfile then
            defaults = ThreatPlates.CopyTable(Addon.db.defaults) -- Should move that before the for loop
            Addon.db:RegisterDefaults({})
          end

          -- iterate over all profiles and migrate values
          --Addon.db.global.MigrationLog[key] = "Migration" .. (max_version and ( " because " .. current_version .. " < " .. max_version) or "")
          for profile_name, profile in pairs(profile_table) do
            action(profile_name, profile)
          end

          if entry.NoDefaultProfile then
            Addon.db:RegisterDefaults(defaults)
          end

          cleanup_database_after_migration = cleanup_database_after_migration or entry.CleanupDatabase
        end

        -- Postprocessing, if necessary
        -- action = entry[3]
        -- if action and type(action) == "function" then
        --   action()
        -- end
      end
    else
      -- iterate over all profiles and delete the old config entry
      --Addon.db.global.MigrationLog[key] = "DELETED"
      for profile_name, profile in pairs(profile_table) do
        DatabaseEntryDelete(profile, entry)
      end
    end
  end
  
  -- Switch through all profiles to cleanup configuration (removing settings with default values from the file)
  if cleanup_database_after_migration then
    local current_profile = Addon.db:GetCurrentProfile()
    for profile_name, profile in pairs(profile_table) do
      Addon.db:SetProfile(profile_name)
    end
    Addon.db:SetProfile(current_profile)
  end
end

Addon.MigrateDatabase = MigrateDatabase

-----------------------------------------------------
-- Schema validation and other check functions for the settings file
-----------------------------------------------------

--
--local VERSION_TO_CUSTOM_STYLE_SCHEMA_MAPPING = {
--  ["9.2.0"] = CUSTOM_STYLE_SCHEMA_VERSIONS.V3
--}
--
--Addon.CheckCustomStyleSchema = function(custom_style, version)
--  ThreatPlates.DEBUG_PRINT_TABLE(custom_style)
--end

local SETTINGS_TYPE_CHECK = {
  icon = { number = true, string = true },
  -- Not part of default values, dynamically inserted
  AutomaticIcon = { number = true },
  SpellID = { number = true },
  SpellName = { number = true },
}

local CUSTOM_STYLE_TYPE_CHECK = {
  icon = { number = true, string = true },
  -- Not part of default values, dynamically inserted
  AutomaticIcon = { number = true },
  SpellID = { number = true },
  SpellName = { number = true },
}

-- Updates existing entries in current settings  with the corresponding values from the
-- update-from settings
-- If an entry in update-from settings does not exist in the current settings, it's ignored
local function UpdateFromSettings(current_settings, update_from_settings)
  for key, current_value in pairs(current_settings) do
    local update_from_value = update_from_settings[key]

    if update_from_value ~= nil then
      if type(current_value) == "table" then
        -- If entry in update-from custom style is not a table as well, ignore it
        if type(update_from_value) == "table" then
          UpdateFromSettings(current_value, update_from_value)
        end
      else
        local type_is_ok

        local valid_types = SETTINGS_TYPE_CHECK[key]
        if valid_types then
          type_is_ok = valid_types[type(update_from_value)]
        else
          type_is_ok = (type(current_value) == type(update_from_value))
        end

        if type_is_ok then
          current_settings[key] = update_from_value
        end
      end
    end
  end
end

-- Updates existing entries in custom style with the corresponding value from the
-- update-from custom style
-- In an entry in update-from custom style does not exist in custom style, it's ignored
local function UpdateFromCustomStyle(custom_style, update_from_custom_style)
  for key, current_value in pairs(custom_style) do
    local update_from_value = update_from_custom_style[key]

    if update_from_value ~= nil then
      if type(current_value) == "table" then
        if key == "Code" then
          -- First copy any legacy code that already exists. New legacy code is appended.
          custom_style.Code.Legacy = update_from_value.Legacy or ""
          update_from_value.Legacy = nil

          -- Script code array is empty in default settings, so UpdateFromCustomStyle does not work here
          for event_type, value in pairs(update_from_value) do
            if event_type == "Functions" then
              for event, script_code in pairs(value) do
                if Addon.SCRIPT_FUNCTIONS.Standard[event] or Addon.SCRIPT_FUNCTIONS.TargetOnly[event] or Addon.SCRIPT_FUNCTIONS.FocusOnly[event] then
                  custom_style.Code.Functions[event] = script_code
                else
                  custom_style.Code.Legacy = custom_style.Code.Legacy .. "-- " .. event .. ":\n" .. script_code .. "\n\n"
                end
              end
            elseif event_type == "Events" then
              Addon.MergeIntoTable(custom_style.Code[event_type], value)
            else
              custom_style.Code.Legacy = custom_style.Code.Legacy .. "-- " .. event_type .. ":\n" .. value .. "\n\n"
            end
          end
        elseif type(update_from_value) == "table" then
          -- If entry in update-from custom style is not a table as well, ignore it
          UpdateFromCustomStyle(current_value, update_from_value)
        end
      else
        local type_is_ok

        local valid_types = CUSTOM_STYLE_TYPE_CHECK[key]
        if valid_types then
          type_is_ok = valid_types[type(update_from_value)]
        else
          type_is_ok = type(current_value) == type(update_from_value)
        end

        if type_is_ok then
          custom_style[key] = update_from_value
        end
      end
    end
  end
end

local function UpdateRuntimeValueFromCustomStyle(custom_style, imported_custom_style, key)
  local valid_types = CUSTOM_STYLE_TYPE_CHECK[key]
  if valid_types and valid_types[type(imported_custom_style[key])] then
    custom_style[key] = imported_custom_style[key]
  end
end

Addon.ImportCustomStyle = function(imported_custom_style)
  local custom_style = ThreatPlates.CopyTable(ThreatPlates.DEFAULT_SETTINGS.profile.uniqueSettings["**"])

  UpdateFromCustomStyle(custom_style, imported_custom_style)

  -- Generate the AsArray version of the input, so that the imported custom_style is consistent (it should be, but
  -- just to be safe)
  custom_style.Trigger.Name.AsArray = Addon.Split(custom_style.Trigger.Name.Input)
  custom_style.Trigger.Aura.AsArray = Addon.Split(custom_style.Trigger.Aura.Input)
  custom_style.Trigger.Cast.AsArray = Addon.Split(custom_style.Trigger.Cast.Input)
  -- Script Input and AsArray don't have any valuable information

  -- No need to import AutomaticIcon as it is set/overwritten, when a aura or cast trigger are detected
  UpdateRuntimeValueFromCustomStyle(custom_style, imported_custom_style, "SpellID")
  UpdateRuntimeValueFromCustomStyle(custom_style, imported_custom_style, "SpellName")

  return custom_style
end

local function MigrateProfile(profile, profile_name, profile_version)
  for key, entry in pairs(DEPRECATED_SETTINGS) do
    local action = entry[1]

    if type(action) == "function" then
      local max_version = entry[2]
      if not max_version or CurrentVersionIsOlderThan(profile_version, max_version) then
        action(profile_name, profile)
      end

      -- Postprocessing, if necessary
      -- action = entry[3]
      -- if action and type(action) == "function" then
      --   action()
      -- end
    else
      DatabaseEntryDelete(profile, entry)
    end
  end
end

Addon.ImportProfile = function(profile, profile_name, profile_version)
  -- Migrate the profile to the current version
  -- Using pcall here to catch errors in the migration code - should not happen, but still ...
  local migration_successful, return_value = pcall(MigrateProfile, profile, profile_name, profile_version)
  if not migration_successful then
    Addon.Logging.Error(L["Failed to migrate the imported profile to the current settings format because of an internal error. Please report this issue at the Threat Plates homepage at CurseForge: "] .. return_value)
  else
    -- Create a new profile with default settings:
    Addon.db:SetProfile(profile_name) --will create a new profile

    -- Custom styles must be handled seperately
    local custom_styles = ThreatPlates.CopyTable(profile.uniqueSettings)
    for index, _ in pairs(profile.uniqueSettings) do
      table.remove(profile.uniqueSettings, index)
    end

    -- Merge the migrated profile to import into this new profile
    UpdateFromSettings(Addon.db.profile, profile)

    -- Now merge back the custom styles
    for index, imported_custom_style in pairs(custom_styles) do
      -- Import all values from the custom style as long the are valid entries with the correct type
      -- based on the default custom style "**"
      local custom_style = Addon.ImportCustomStyle(imported_custom_style)
      table.insert(Addon.db.profile.uniqueSettings, index, custom_style)
    end
  end
end

-----------------------------------------------------
-- External
-----------------------------------------------------

ThreatPlates.GetDefaultSettingsV1 = GetDefaultSettingsV1
ThreatPlates.SwitchToCurrentDefaultSettings = SwitchToCurrentDefaultSettings
ThreatPlates.SwitchToDefaultSettingsV1 = SwitchToDefaultSettingsV1
ThreatPlates.MigrateDatabase = MigrateDatabase

ThreatPlates.GetUnitVisibility = GetUnitVisibility
ThreatPlates.SetNamePlateClickThrough = SetNamePlateClickThrough
