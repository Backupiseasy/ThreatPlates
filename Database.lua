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
local GetCVar = GetCVar

-- ThreatPlates APIs
local L = Addon.L
local TidyPlatesThreat = TidyPlatesThreat
local RGB = Addon.RGB

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS:

---------------------------------------------------------------------------------------------------
-- Global functions for accessing the configuration
---------------------------------------------------------------------------------------------------

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
  local db = TidyPlatesThreat.db.profile
  db.NamePlateFriendlyClickThrough = friendly
  db.NamePlateEnemyClickThrough = enemy
  Addon:CallbackWhenOoC(function()
    C_NamePlate.SetNamePlateFriendlyClickThrough(friendly)
    C_NamePlate.SetNamePlateEnemyClickThrough(enemy)
  end, L["Nameplate clickthrough cannot be changed while in combat."])
end

Addon.LEGACY_CUSTOM_NAMEPLATES = {
  ["**"] = {
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
  local new_defaults = Addon.CopyTable(defaults)

  local db = new_defaults.profile
  -- Migrated to Healthbar.FriendlyUnitMode/EnemyUnitMode:
  -- db.allowClass = false, db.friendlyClass = false
  db.Healthbar.FriendlyUnitMode = "REACTION"
  db.Healthbar.EnemyUnitMode = "REACTION"
  db.Healthbar.BackgroundOpacity = 1
  db.optionRoleDetectionAutomatic = false
  --db.HeadlineView.width = 116 -- No longer used
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
  db.settings.castborder.texture = "TP_CastBarOverlay"
  db.settings.castbar.texture = "ThreatPlatesBar"
  db.Name.HealthbarMode.Font.Typeface = "Accidental Presidency"
  db.Name.HealthbarMode.Font.Width = 116
  db.Name.HealthbarMode.Font.Size = 14
  db.settings.level.typeface = "Accidental Presidency"
  db.settings.level.size = 12
  db.settings.level.height  = 14
  db.settings.level.x = 50
  db.settings.level.vertical = "TOP"
  db.StatusText.HealthbarMode.Font.Typeface = "Accidental Presidency"
  db.StatusText.HealthbarMode.Font.Size = 12
  db.StatusText.HealthbarMode.Font.VerticalOffset = 1
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

local function CurrentVersionIsLowerThan(current_version, max_version)
  return VersionToNumber(current_version) < VersionToNumber(max_version)
end

---------------------------------------------------------------------------------------------------
-- Functions to access or manipulate entries
---------------------------------------------------------------------------------------------------

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

local function DatabaseEntryGetCurrentValue(profile, deprecated_entry)
  local keys = deprecated_entry
  local value = profile

  for index = 1, #keys do
    --print ("    -->", keys[index], value[keys[index]])
    value = value[keys[index]]
    -- If value is nil, the current profile uses the default value for this setting, so no migration required
    if value == nil then
      return nil
    end
  end

  -- Delete the deprecated entry (not nil) from the profile
  --DatabaseEntryDelete(profile, deprecated_entry)

  return value
end

local function DatabaseEntrySetValueOrDefault(old_value, default_value)
  if old_value ~= nil then
    return old_value
  else
    return default_value
  end
end

---------------------------------------------------------------------------------------------------
-- Migration functions for more complicated migrations
---------------------------------------------------------------------------------------------------

--local function MigrateNamesColor(profile_name, profile)
--  local entry = {"settings", "name", "color"}
--
--  local old_color = { r = 1, g = 1, b = 1 }
--  if DatabaseEntryExists(profile, entry) then
--    local db = profile.settings.name
--    local color = db.color
--
--    color.r = color.r or old_color.r
--    color.g = color.g or old_color.g
--    color.b = color.b or old_color.b
--
--    db.EnemyTextColor = Addon.CopyTable(color)
--    db.FriendlyTextColor = Addon.CopyTable(color)
--
--    DatabaseEntryDelete(profile, entry)
--  end
--end

--local function MigrationBlizzFadeA(profile_name, profile)
--  local entry = {"blizzFadeA" }
--
--  if DatabaseEntryExists(profile, entry) then
--    profile.nameplate = profile.nameplate or {}
--
--    -- default for blizzFadeA.toggle was true
--    if profile.blizzFadeA.toggle ~= nil then
--      profile.nameplate.toggle = profile.nameplate.toggle or {}
--      profile.nameplate.toggle.NonTargetA = profile.blizzFadeA.toggle
--    end
--
--    -- default for blizzFadeA.amount was -0.3
--    if profile.blizzFadeA.amount ~= nil then
--      profile.nameplate.alpha = profile.nameplate.alpha or {}
--
--      local db = profile.nameplate.alpha
--      local amount = profile.blizzFadeA.amount
--      if amount <= 0 then
--        db.NonTarget = math_min(1, 1 + amount)
--      end
--    end
--
--    DatabaseEntryDelete(profile, entry)
--  end
--end

--local function MigrationTargetScale(profile_name, profile)
--  if DatabaseEntryExists(profile, { "nameplate", "scale", "Target" }) then
--    profile.nameplate.scale.Target = profile.nameplate.scale.Target - 1
--  end
--
--  if DatabaseEntryExists(profile, { "nameplate", "scale", "NoTarget" }) then
--    profile.nameplate.scale.NoTarget = profile.nameplate.scale.NoTarget - 1
--  end
--end

--local function MigrateCustomTextShow(profile_name, profile)
--  local entry = {"settings", "customtext", "show"}
--
--  -- default for db.show was true
--  if DatabaseEntryExists(profile, entry) then
--    local db = profile.settings.customtext
--    db.FriendlySubtext = "NONE"
--    db.EnemySubtext = "NONE"
--
--    DatabaseEntryDelete(profile, entry)
--  end
--end

--local function MigrateAuraWidget(profile_name, profile)
--  if DatabaseEntryExists(profile, { "debuffWidget" }) then
--    if not profile.AuraWidget.ON and not profile.AuraWidget.ShowInHeadlineView then
--      profile.AuraWidget = profile.AuraWidget or {}
--      profile.AuraWidget.ModeIcon = profile.AuraWidget.ModeIcon or {}
--
--      local default_profile = ThreatPlates.DEFAULT_SETTINGS.profile.AuraWidget
--      profile.AuraWidget.FilterMode = profile.debuffWidget.mode                     or default_profile.FilterMode
--      profile.AuraWidget.ModeIcon.Style = profile.debuffWidget.style                or default_profile.ModeIcon.Style
--      profile.AuraWidget.ShowTargetOnly = profile.debuffWidget.targetOnly           or default_profile.ShowTargetOnly
--      profile.AuraWidget.ShowCooldownSpiral = profile.debuffWidget.cooldownSpiral   or default_profile.ShowCooldownSpiral
--      profile.AuraWidget.ShowFriendly = profile.debuffWidget.showFriendly           or default_profile.ShowFriendly
--      profile.AuraWidget.ShowEnemy = profile.debuffWidget.showEnemy                 or default_profile.ShowEnemy
--      profile.AuraWidget.scale = profile.debuffWidget.scale                         or default_profile.scale
--
--      if profile.debuffWidget.displays then
--        profile.AuraWidget.FilterByType = Addon.CopyTable(profile.debuffWidget.displays)
--      end
--
--      if profile.debuffWidget.filter then
--        profile.AuraWidget.FilterBySpell = Addon.CopyTable(profile.debuffWidget.filter)
--      end
--
--      -- DatabaseEntryDelete(profile, { "debuffWidget" }) -- TODO
--    end
--  end
--end

--local function MigrateCastbarColoring(profile_name, profile)
--  -- default for castbarColor.toggle was true
--  local entry = { "castbarColor", "toggle" }
--  if DatabaseEntryExists(profile, entry) and profile.castbarColor.toggle == false then
--    profile.castbarColor = RGB(255, 255, 0, 1)
--    profile.castbarColorShield = RGB(255, 255, 0, 1)
--    DatabaseEntryDelete(profile, entry)
--    DatabaseEntryDelete(profile, { "castbarColorShield", "toggle" })
--  end
--
--  -- default for castbarColorShield.toggle was true
--  local entry = { "castbarColorShield", "toggle" }
--  if DatabaseEntryExists(profile, entry) and profile.castbarColorShield.toggle == false then
--    profile.castbarColorShield = profile.castbarColor or { r = 1, g = 0.56, b = 0.06, a = 1 }
--    DatabaseEntryDelete(profile, entry)
--  end
--end

--local function MigrationTotemSettings(profile_name, profile)
--  local entry = { "totemSettings" }
--  if DatabaseEntryExists(profile, entry) then
--    for key, value in pairs(profile.totemSettings) do
--      if type(value) == "table" then -- omit hideHealthbar setting and skip if new default totem settings
--        value.Style = value[7] or profile.totemSettings[key].Style
--        value.Color = value.color or profile.totemSettings[key].Color
--        if value[1] == false then
--          value.ShowNameplate = false
--        end
--        if value[2] == false then
--          value.ShowHPColor = false
--        end
--        if value[3] == false then
--          value.ShowIcon = false
--        end
--
--        value[7] = nil
--        value.color = nil
--        value[1] = nil
--        value[2] = nil
--        value[3] = nil
--      end
--    end
--  end
--end

--local function MigrateBorderTextures(profile_name, profile)
--  if DatabaseEntryExists(profile, { "settings", "elitehealthborder", "texture" } ) then
--    if profile.settings.elitehealthborder.texture == "TP_HealthBarEliteOverlay" then
--      profile.settings.elitehealthborder.texture = "TP_EliteBorder_Default"
--    else -- TP_HealthBarEliteOverlayThin
--      profile.settings.elitehealthborder.texture = "TP_EliteBorder_Thin"
--    end
--  end
--
--  if DatabaseEntryExists(profile, { "settings", "healthborder", "texture" } ) then
--    if profile.settings.healthborder.texture == "TP_HealthBarOverlay" then
--      profile.settings.healthborder.texture = "TP_Border_Default"
--    else -- TP_HealthBarOverlayThin
--      profile.settings.healthborder.texture = "TP_Border_Thin"
--    end
--  end
--
--  if DatabaseEntryExists(profile, { "settings", "castborder", "texture" } ) then
--    if profile.settings.castborder.texture == "TP_CastBarOverlay" then
--      profile.settings.castborder.texture = "TP_Castbar_Border_Default"
--    else -- TP_CastBarOverlayThin
--      profile.settings.castborder.texture = "TP_Castbar_Border_Thin"
--    end
--  end
--end

--local function MigrationAurasSettings(profile_name, profile)
--  if DatabaseEntryExists(profile, { "AuraWidget" } ) then
--    profile.AuraWidget.Debuffs = profile.AuraWidget.Debuffs or {}
--    profile.AuraWidget.Buffs = profile.AuraWidget.Buffs or {}
--    profile.AuraWidget.CrowdControl = profile.AuraWidget.CrowdControl or {}
--
--    if DatabaseEntryExists(profile, { "AuraWidget", "ShowDebuffsOnFriendly", } ) and profile.AuraWidget.ShowDebuffsOnFriendly then
--      profile.AuraWidget.Debuffs.ShowFriendly = true
--    end
--    DatabaseEntryDelete(profile, { "AuraWidget", "ShowDebuffsOnFriendly", } )
--
--    -- Don't migration FilterByType, does not make sense
--    DatabaseEntryDelete(profile, { "AuraWidget", "FilterByType", } )
--
--
--    if DatabaseEntryExists(profile, { "AuraWidget", "ShowFriendly", } ) and not profile.AuraWidget.ShowFriendly then
--      profile.AuraWidget.Debuffs.ShowFriendly = false
--      profile.AuraWidget.Buffs.ShowFriendly = false
--      profile.AuraWidget.CrowdControl.ShowFriendly = false
--
--      DatabaseEntryDelete(profile, { "AuraWidget", "ShowFriendly", } )
--    end
--
--    if DatabaseEntryExists(profile, { "AuraWidget", "ShowEnemy", } ) and not profile.AuraWidget.ShowEnemy then
--      profile.AuraWidget.Debuffs.ShowEnemy = false
--      profile.AuraWidget.Buffs.ShowEnemy = false
--      profile.AuraWidget.CrowdControl.ShowEnemy = false
--
--      DatabaseEntryDelete(profile, { "AuraWidget", "ShowEnemy", } )
--    end
--
--    if DatabaseEntryExists(profile, { "AuraWidget", "FilterBySpell", } ) then
--      profile.AuraWidget.Debuffs.FilterBySpell = Addon.CopyTable(profile.AuraWidget.FilterBySpell)
--      DatabaseEntryDelete(profile, { "AuraWidget", "FilterBySpell", } )
--    end
--
--    if DatabaseEntryExists(profile, { "AuraWidget", "FilterMode", } ) then
--      if profile.AuraWidget.FilterMode == "BLIZZARD" then
--        profile.AuraWidget.Debuffs.FilterMode = "blacklist"
--        profile.AuraWidget.Debuffs.ShowAllEnemy = false
--        profile.AuraWidget.Debuffs.ShowOnlyMine = false
--        profile.AuraWidget.Debuffs.ShowBlizzardForEnemy = true
--      else
--        profile.AuraWidget.Debuffs.FilterMode = profile.AuraWidget.FilterMode:gsub("Mine", "")
--      end
--      DatabaseEntryDelete(profile, { "AuraWidget", "FilterMode", } )
--    end
--
--    if DatabaseEntryExists(profile, { "AuraWidget", "scale", } ) then
--      profile.AuraWidget.Debuffs.Scale = DatabaseEntrySetValueOrDefault(profile.AuraWidget.scale, ThreatPlates.DEFAULT_SETTINGS.profile.AuraWidget.Debuffs.Scale)
--      DatabaseEntryDelete(profile, { "AuraWidget", "scale", } )
--    end
--  end
--end

--local function MigrationAurasSettingsFix(profile_name, profile)
--  if DatabaseEntryExists(profile, { "AuraWidget", "Debuffs", "FilterMode", } ) and profile.AuraWidget.Debuffs.FilterMode == "BLIZZARD" then
--    profile.AuraWidget.Debuffs.FilterMode = "blacklist"
--    profile.AuraWidget.Debuffs.ShowAllEnemy = false
--    profile.AuraWidget.Debuffs.ShowOnlyMine = false
--    profile.AuraWidget.Debuffs.ShowBlizzardForEnemy = true
--  end
--  if DatabaseEntryExists(profile, { "AuraWidget", "Buffs", "FilterMode", } ) and profile.AuraWidget.Buffs.FilterMode == "BLIZZARD" then
--    profile.AuraWidget.Buffs.FilterMode = "blacklist"
--  end
--  if DatabaseEntryExists(profile, { "AuraWidget", "CrowdControl", "FilterMode", } ) and profile.AuraWidget.CrowdControl.FilterMode == "BLIZZARD" then
--    profile.AuraWidget.CrowdControl.FilterMode = "blacklist"
--  end
--end

local function GetValueOrDefault(old_value, default_value)
  if old_value ~= nil then
    return old_value
  else
    return default_value
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

local function MigrateCustomStylesToV3(profile_name, profile)
  -- if TidyPlatesThreat.db.global.CustomNameplatesVersion > 2 then return end

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

        --unique_unit.name = nil

        -- Set automatic icon detection for all existing custom nameplates to false
        unique_unit.UseAutomaticIcon = false
        unique_unit.icon = GetValueOrDefault(unique_unit.icon, (Addon.CLASSIC and "Spell_nature_spiritwolf.blp") or "spell_shadow_shadowfiend.blp")
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

---------------------------------------------------------------------------------------------------
-- Main migration function & settings
---------------------------------------------------------------------------------------------------

---- Settings in the SavedVariables file that should be migrated and/or deleted
local MIGRATION_FUNCTIONS = {
--  NamesColor = { MigrateNamesColor, },                        -- settings.name.color
--  CustomTextShow = { MigrateCustomTextShow, },                -- settings.customtext.show
--  BlizzFadeA = { MigrationBlizzFadeA, },                      -- blizzFadeA.toggle and blizzFadeA.amount
--  TargetScale = { MigrationTargetScale, "8.5.0" },            -- nameplate.scale.Target/NoTarget
--  --AuraWidget = { MigrateAuraWidget, "8.6.0" },              -- disabled until someone requests it
--  CastbarColoring = { MigrateCastbarColoring },               -- (removed in 8.7.0)
--  TotemSettings = { MigrationTotemSettings, "8.7.0" },        -- (changed in 8.7.0)
--  Borders = { MigrateBorderTextures, "8.7.0" },               -- (changed in 8.7.0)
--  Auras = { MigrationAurasSettings, "9.0.0" },                -- (changed in 9.0.0)
--  AurasFix = { MigrationAurasSettingsFix },                   -- (changed in 9.0.4 and 9.0.9)
  ["9.1.0"] = {
    MigrationForceFriendlyInCombat,
  },
  ["9.2.0"] = {
    SpelltextPosition = { MigrateSpelltextPosition, NoDefaultProfile = true },
    FixTargetFocusTexture = { FixTargetFocusTexture, NoDefaultProfile = true },
  },
  ["9.2.2"] = {
    MigrationCustomPlatesV3 = { MigrateCustomStylesToV3},
  },
  ["10.0.0"] = {
    -- MigrateDeprecatedSettingsEntries, -- TODO
  },
}

local ENTRIES_TO_DELETE = {
  ["8.5.0"] = {
    { "alphaFeatures" },
    { "alphaFeatureHeadlineView" },
    { "alphaFeatureAuraWidget2" },
    { "alphaFriendlyNameOnly" },
    { "HeadlineView", "name", "width" },
    { "HeadlineView", "name", "height" },
  },
  ["8.5.1"] = {
    { "HeadlineView", "blizzFading" },
    { "HeadlineView", "blizzFadingAlpha"},
  },
  ["8.7.0"] = {
    { "debuffWidget" },
  },
  ["8.7.0"] = {
    { "uniqueSettings", "list" },
    { "OldSettings" },
  },
  ["9.1.0"] = {
    { "HeadlineView", "ON" },
  },
  ["9.2.0"] = {
    { "ShowThreatGlowOffTank" }, -- never used
    { "ColorByReaction", "DisconnectedUnit" },
    { "tidyplatesFade" },
    { "threat", "nonCombat" }, -- migrated in 9.1.3
    { "healthColorChange" },
    { "allowClass" },
    { "friendlyClass" },
    { "threat", "hideNonCombat" },
    { "aHPbarColor", },
    { "bHPbarColor", },
    { "settings", "name", },
    { "HeadlineView", "name", },
    { "blizzFadeS", },
    { "cache", },
    { "cacheClass", },
    { "customColor", },
  },
}

local ENTRIES_TO_RENAME = {
  ["9.1.0"] = {
    { Deprecated = { "comboWidget", "ON" }, New = { "ComboPoints", "ON" }, },
    { Deprecated = { "comboWidget", "ShowInHeadlineView" }, New = { "ComboPoints", "ShowInHeadlineView" }, },
    { Deprecated = { "comboWidget", "scale" }, New = { "ComboPoints", "Scale" }, },
    { Deprecated = { "comboWidget", "x" }, New = { "ComboPoints", "x" }, },
    { Deprecated = { "comboWidget", "y" }, New = { "ComboPoints", "y" }, },
    { Deprecated = { "comboWidget", "x_hv" }, New = { "ComboPoints", "x_hv" }, },
    { Deprecated = { "comboWidget", "y_hv" }, New = { "ComboPoints", "y_hv" }, },
  },
  ["9.1.3"] = {
    { Deprecated = { "threat", "nonCombat" }, New = { "threat", "UseThreatTable" }, },
  },
  ["10.0.0"] = {
    -- Color settings for healthbar and name
    { Deprecated = { "settings", "healthbar", "BackgroundUseForegroundColor" }, New = { "Healthbar", "BackgroundUseForegroundColor" }, },
    { Deprecated = { "settings", "healthbar", "BackgroundOpacity" }, New = { "Healthbar", "BackgroundOpacity" }, },
    { Deprecated = { "settings", "healthbar", "BackgroundColor" }, New = { "Healthbar", "BackgroundColor" }, },
    { Deprecated = { "settings", "raidicon", "hpColor" }, New = { "Healthbar", "UseRaidMarkColoring" }, },
    { Deprecated = { "settings", "name", "FriendlyTextColorMode" }, New = { "Name", "HealthbarMode", "FriendlyUnitMode" }, },
    { Deprecated = { "settings", "name", "FriendlyTextColor" }, New = { "Name", "HealthbarMode", "FriendlyTextColor" }, },
    { Deprecated = { "settings", "name", "EnemyTextColorMode" }, New = { "Name", "HealthbarMode", "EnemyUnitMode" }, },
    { Deprecated = { "settings", "name", "EnemyTextColor" }, New = { "Name", "HealthbarMode", "EnemyTextColor" }, },
    { Deprecated = { "settings", "name", "UseRaidMarkColoring" }, New = { "Name", "HealthbarMode", "UseRaidMarkColoring" }, },
    { Deprecated = { "HeadlineView", "FriendlyTextColorMode" }, New = { "Name", "NameMode", "FriendlyUnitMode" }, },
    { Deprecated = { "HeadlineView", "FriendlyTextColor" }, New = { "Name", "NameMode", "FriendlyTextColor" }, },
    { Deprecated = { "HeadlineView", "EnemyTextColorMode" }, New = { "Name", "NameMode", "EnemyUnitMode" }, },
    { Deprecated = { "HeadlineView", "EnemyTextColor" }, New = { "Name", "NameMode", "EnemyTextColor" }, },
    { Deprecated = { "HeadlineView", "UseRaidMarkColoring" }, New = { "Name", "NameMode", "UseRaidMarkColoring" }, },
    -- Customtext is now Status Text
    { Deprecated = { "settings", "customtext", "x" }, New = { "StatusText", "HealthbarMode", "HorizontalOffset" }, },
    { Deprecated = { "settings", "customtext", "y" }, New = { "StatusText", "HealthbarMode", "VerticalOffset" }, },
    { Deprecated = { "settings", "customtext", "typeface" }, New = { "StatusText", "HealthbarMode", "Font", "Typeface" }, },
    { Deprecated = { "settings", "customtext", "size" }, New = { "StatusText", "HealthbarMode", "Font", "Size" }, },
    { Deprecated = { "settings", "customtext", "width" }, New = { "StatusText", "HealthbarMode", "Font", "Width" }, },
    { Deprecated = { "settings", "customtext", "height" }, New = { "StatusText", "HealthbarMode", "Font", "Height" }, },
    { Deprecated = { "settings", "customtext", "align" }, New = { "StatusText", "HealthbarMode", "Font", "HorizontalAlignment" }, },
    { Deprecated = { "settings", "customtext", "vertical" }, New = { "StatusText", "HealthbarMode", "Font", "VerticalAlignment" }, },
    { Deprecated = { "settings", "customtext", "shadow" }, New = { "StatusText", "HealthbarMode", "Font", "Shadow" }, },
    { Deprecated = { "settings", "customtext", "flags" }, New = { "StatusText", "HealthbarMode", "Font", "flags" }, },
    { Deprecated = { "settings", "customtext", "FriendlySubtext" }, New = { "StatusText", "HealthbarMode", "FriendlySubtext" }, },
    { Deprecated = { "settings", "customtext", "EnemySubtext" }, New = { "StatusText", "HealthbarMode", "EnemySubtext" }, },
    { Deprecated = { "settings", "customtext", "SubtextColorUseHeadline" }, New = { "StatusText", "HealthbarMode", "SubtextColorUseHeadline" }, },
    { Deprecated = { "settings", "customtext", "SubtextColorUseSpecific" }, New = { "StatusText", "HealthbarMode", "SubtextColorUseSpecific" }, },
    { Deprecated = { "settings", "customtext", "SubtextColor" }, New = { "StatusText", "HealthbarMode", "SubtextColor" }, },
    { Deprecated = { "HeadlineView", "customtext", "x" }, New = { "StatusText", "NameMode", "HorizontalOffset" }, },
    { Deprecated = { "HeadlineView", "customtext", "y" }, New = { "StatusText", "NameMode", "VerticalOffset" }, },
    { Deprecated = { "HeadlineView", "customtext", "size" }, New = { "StatusText", "NameMode", "Font", "Size" }, },
    { Deprecated = { "HeadlineView", "customtext", "align" }, New = { "StatusText", "NameMode", "Font", "HorizontalAlignment" }, },
    { Deprecated = { "HeadlineView", "customtext", "vertical" }, New = { "StatusText", "NameMode", "Font", "VerticalAlignment" }, },
    -- Name settings for healthbar and headline view
    { Deprecated = { "HeadlineView", "name", "size" }, New = { "Name", "NameMode", "Size" }, },
    { Deprecated = { "HeadlineView", "name", "x" }, New = { "Name", "NameMode", "HorizontalOffset" }, },
    { Deprecated = { "HeadlineView", "name", "y" }, New = { "Name", "NameMode", "VerticalOffset" }, },
    { Deprecated = { "HeadlineView", "name", "align" }, New = { "Name", "NameMode", "Font", "HorizontalAlignment" }, },
    { Deprecated = { "HeadlineView", "name", "vertical" }, New = { "Name", "NameMode", "Font", "VerticalAlignment" }, },
    { Deprecated = { "settings", "name", "show" }, New = { "Name", "HealthbarMode", "Enabled" }, },
    { Deprecated = { "settings", "name", "x" }, New = { "Name", "HealthbarMode", "HorizontalOffset" }, },
    { Deprecated = { "settings", "name", "y" }, New = { "Name", "HealthbarMode", "VerticalOffset" }, },
    { Deprecated = { "settings", "name", "typeface" }, New = { "Name", "HealthbarMode", "Font", "Typeface" }, },
    { Deprecated = { "settings", "name", "size" }, New = { "Name", "HealthbarMode", "Font", "Size", }, },
    { Deprecated = { "settings", "name", "shadow" }, New = { "Name", "HealthbarMode", "Font", "Shadow" }, },
    { Deprecated = { "settings", "name", "flags" }, New = { "Name", "HealthbarMode", "Font", "flags" }, },
    { Deprecated = { "settings", "name", "align" }, New = { "Name", "HealthbarMode", "Font", "HorizontalAlignment" }, },
    { Deprecated = { "settings", "name", "vertical" }, New = { "Name", "HealthbarMode", "Font", "VerticalAlignment" }, },
    { Deprecated = { "settings", "name", "width" }, New = { "Name", "HealthbarMode", "Font", "Width" }, },
    { Deprecated = { "settings", "name", "height" }, New = { "Name", "HealthbarMode", "Font", "Height" }, },
    { Deprecated = { "Transparency", "Fadeing" }, New = { "Animations", "EnableFading" }, },
    -- Others
    { Deprecated = { "HeadlineView", "ShowTargetHighlight" }, New = { "targetWidget", "ShowInHeadlineView" }, },
    { Deprecated = { "HeadlineView", "ShowFocusHighlight" }, New = { "FocusWidget", "ShowInHeadlineView" }, },
  },
}

local function ExecuteMigrationFunctions(current_version)
  local profile_table = TidyPlatesThreat.db.profiles

  for max_version, entries in pairs(MIGRATION_FUNCTIONS) do
    if CurrentVersionIsLowerThan(current_version, max_version) then
      for key, migration_info in pairs(entries) do
        local migration_function, no_default_profile

        if type(migration_info) == "table" then
          no_default_profile = migration_info.NoDefaultProfile
          migration_function = migration_info[1]
        else
          migration_function = migration_info
        end

        local defaults
        if no_default_profile then
          defaults = ThreatPlates.CopyTable(TidyPlatesThreat.db.defaults)
          TidyPlatesThreat.db:RegisterDefaults({})
        end

        -- iterate over all profiles and migrate values
        --TidyPlatesThreat.db.global.MigrationLog[key] = "Migration" .. (max_version and ( " because " .. current_version .. " < " .. max_version) or "")
        for profile_name, profile in pairs(profile_table) do
          migration_function(profile_name, profile)
        end

        if no_default_profile then
          TidyPlatesThreat.db:RegisterDefaults(defaults)
        end

        -- Postprocessing, if necessary
        -- action = entry[3]
        -- if action and type(action) == "function" then
        --   action()
        -- end
      end
    end
  end
end

function Addon.MigrateDatabase(current_version)
  TidyPlatesThreat.db.global.MigrationLog = nil

  ExecuteMigrationFunctions(current_version)

  local profile_table = TidyPlatesThreat.db.profiles

  for max_version, entries in pairs(ENTRIES_TO_RENAME) do
    if CurrentVersionIsLowerThan(current_version, max_version) then

      --print ("Migrating", max_version, "...")

      for i = 1, #entries do
        local deprecated_entry = entries[i].Deprecated
        local new_entry = entries[i].New

        -- Iterate over all profiles, copy the deprecated entry to the new entry and delete the deprecated entry
        for profile_name, profile in pairs(profile_table) do
          local current_value = DatabaseEntryGetCurrentValue(profile, deprecated_entry)
          if current_value ~= nil then
            --print ("    " .. profile_name ..":", table.concat(deprecated_entry, "."), "=>", table.concat(new_entry, "."), "=", current_value)

            -- Iterate to the new entry in the current profile
            local value = profile
            for index = 1, #new_entry - 1 do
              local key = new_entry[index]
              -- If value[key] does not exist, create an empty hash table
              -- As the current entry is not the last one, it cannot be a leave, i.e., it must be a table
              value[key] = value[key] or {}
              value = value[key]
            end

            -- We only iterate to the next-to-last entry, as we need to overwrite it:
            value[new_entry[#new_entry]] = current_value
            -- And delete the deprecated entry
            DatabaseEntryDelete(profile, deprecated_entry)
          end
        end
      end
    end
  end

  for max_version, entries in pairs(ENTRIES_TO_DELETE) do
    if CurrentVersionIsLowerThan(current_version, max_version) then
      -- iterate over all profiles and delete the old config entry
      --TidyPlatesThreat.db.global.MigrationLog[key] = "DELETED"
      for i = 1, #entries do
        for profile_name, profile in pairs(profile_table) do
          if DatabaseEntryExists(profile, entries[i]) then
            --print ("  " .. profile_name ..": Deleting", table.concat(entries[i], "."))
            DatabaseEntryDelete(profile, entries[i])
          end
        end
      end
    end
  end
end

local function DeleteEntry(current_entry, default_entry, path)
  for key, current_value in pairs(current_entry) do
    if key ~= "uniqueSettings" then
      local current_path = path .. "." .. key

      local default_value = default_entry[key]
      if default_value == nil then
        ThreatPlates.Print(L["    Deleting "] .. current_path .. " = " .. tostring(current_value), true)
        -- Delete current entry
      elseif type(current_value) == "table" then
        if type(default_value) == "table" then
          -- Skip entries that ahve a default value of {} (all values there are ok, I guess)
          if not (type(default_value) == "table" and #default_value == 0) then
            DeleteEntry(current_value, default_value, current_path)
          end
        else -- This should never happen - i.e. an old entry (which was a table) is re-used as simple value)
          print ("  =>", current_path ..": Type Mismatch - New Value is no table!")
        end
      end
    end
  end
end

Addon.MigrationCustomNameplatesV1 = function()
  local defaults = ThreatPlates.CopyTable(TidyPlatesThreat.db.defaults)
  TidyPlatesThreat.db:RegisterDefaults({})

  -- Set default to empty so that new defaul values don't impact the migration
  for profile_name, profile in pairs(TidyPlatesThreat.db.profiles) do
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
        local deprecated_settings = Addon.LEGACY_CUSTOM_NAMEPLATES[index] or Addon.LEGACY_CUSTOM_NAMEPLATES["**"]

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

  defaults.profile.uniqueSettings = ThreatPlates.CopyTable(ThreatPlates.DEFAULT_SETTINGS.profile.uniqueSettings)
  TidyPlatesThreat.db:RegisterDefaults(defaults)
  TidyPlatesThreat.db.global.CustomNameplatesVersion = 2
end

Addon.SetDefaultsForCustomNameplates = function()
  if TidyPlatesThreat.db.global.CustomNameplatesVersion > 1 then return end

  local defaults = Addon.CopyTable(TidyPlatesThreat.db.defaults)
  defaults.profile.uniqueSettings = Addon.LEGACY_CUSTOM_NAMEPLATES
  TidyPlatesThreat.db:RegisterDefaults(defaults)
end

function Addon:DeleteDeprecatedSettings()
  local profile_table = TidyPlatesThreat.db.profiles

  for profile_name, profile in pairs(profile_table) do
    ThreatPlates.Print(L["  Profile: "] .. profile_name, true)
    DeleteEntry(profile, ThreatPlates.DEFAULT_SETTINGS.profile, "")
  end
end

-----------------------------------------------------
-- Schema validation and other check functions for the settings file
-----------------------------------------------------

local CUSTOM_STYLE_TYPE_CHECK = {
  icon = { number = true, string = true },
  -- Not part of default values, dynamically inserted
  AutomaticIcon = { number = true },
  SpellID = { number = true },
  SpellName = { number = true },
}

--
--local VERSION_TO_CUSTOM_STYLE_SCHEMA_MAPPING = {
--  ["9.2.0"] = CUSTOM_STYLE_SCHEMA_VERSIONS.V3
--}
--
--Addon.CheckCustomStyleSchema = function(custom_style, version)
--  ThreatPlates.DEBUG_PRINT_TABLE(custom_style)
--end

-- Updates existing entries in custom style with the corresponding value from the
-- update-from custom style
-- In an entry in update-from custom style does not exist in custom style, it's ignored
local function UpdateFromCustomStyle(custom_style, update_from_custom_style)
  for key, current_value in pairs(custom_style) do
    local update_from_value = update_from_custom_style[key]

    if update_from_value ~= nil then
      if type(current_value) == "table" then
        -- If entry in update-from custom style is not a table as well, ignore it
        if type(update_from_value) == "table" then
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

  -- No need to import AutomaticIcon as it is set/overwritten, when a aura or cast trigger are detected
  UpdateRuntimeValueFromCustomStyle(custom_style, imported_custom_style, "SpellID")
  UpdateRuntimeValueFromCustomStyle(custom_style, imported_custom_style, "SpellName")

  return custom_style
end

-----------------------------------------------------
-- External
-----------------------------------------------------

ThreatPlates.GetDefaultSettingsV1 = GetDefaultSettingsV1
ThreatPlates.SwitchToCurrentDefaultSettings = SwitchToCurrentDefaultSettings
ThreatPlates.SwitchToDefaultSettingsV1 = SwitchToDefaultSettingsV1

ThreatPlates.GetUnitVisibility = GetUnitVisibility
ThreatPlates.SetNamePlateClickThrough = SetNamePlateClickThrough
