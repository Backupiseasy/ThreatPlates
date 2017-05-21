local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Stuff for handling the configuration of Threat Plates - ThreatPlatesDB
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local L = ThreatPlates.L
local RGB = ThreatPlates.RGB

local InCombatLockdown = InCombatLockdown

---------------------------------------------------------------------------------------------------
-- Color definitions
---------------------------------------------------------------------------------------------------

ThreatPlates.COLOR_TAPPED = RGB(110, 110, 110, 1)	-- grey
ThreatPlates.COLOR_TRANSPARENT = RGB(0, 0, 0, 0, 0) -- opaque
ThreatPlates.COLOR_DC = RGB(128, 128, 128, 1) -- dray, darker than tapped color
ThreatPlates.COLOR_FRIEND = RGB(29, 39, 61) -- Blizzard friend dark blue
ThreatPlates.COLOR_GUILD = RGB(60, 168, 255) -- light blue

---------------------------------------------------------------------------------------------------
-- Global contstants for options
---------------------------------------------------------------------------------------------------

ThreatPlates.ANCHOR_POINT = { TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right", LEFT = "Left", CENTER = "Center", RIGHT = "Right", BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom ", BOTTOMRIGHT = "Bottom Right" }
ThreatPlates.ANCHOR_POINT_SETPOINT = {
  TOPLEFT = {"TOPLEFT", "BOTTOMLEFT"},
  TOP = {"TOP", "BOTTOM"},
  TOPRIGHT = {"TOPRIGHT", "BOTTOMRIGHT"},
  LEFT = {"LEFT", "RIGHT"},
  CENTER = {"CENTER", "CENTER"},
  RIGHT = {"RIGHT", "LEFT"},
  BOTTOMLEFT = {"BOTTOMLEFT", "TOPLEFT"},
  BOTTOM = {"BOTTOM", "TOP"},
  BOTTOMRIGHT = {"BOTTOMRIGHT", "TOPRIGHT"}
}

ThreatPlates.ENEMY_TEXT_COLOR = {
  CLASS = "By Class",
  CUSTOM = "By Custom Color",
  REACTION = "By Reaction",
  HEALTH = "By Health",
}
-- "By Threat", "By Level Color", "By Normal/Elite/Boss"
ThreatPlates.FRIENDLY_TEXT_COLOR = {
  CLASS = "By Class",
  CUSTOM = "By Custom Color",
  REACTION = "By Reaction",
  HEALTH = "By Health",
}
ThreatPlates.ENEMY_SUBTEXT = {
  NONE = "None",
  HEALTH = "Percent Health",
  ROLE = "NPC Role",
  ROLE_GUILD = "NPC Role, Guild",
  ROLE_GUILD_LEVEL = "NPC Role, Guild, or Level",
  LEVEL = "Level",
  ALL = "Everything"
}
-- NPC Role, Guild, or Quest", "Quest",
ThreatPlates.FRIENDLY_SUBTEXT = {
  NONE = "None",
  HEALTH = "Percent Health",
  ROLE = "NPC Role",
  ROLE_GUILD = "NPC Role, Guild",
  ROLE_GUILD_LEVEL = "NPC Role, Guild, or Level",
  LEVEL = "Level",
  ALL = "Everything"
}
-- "NPC Role, Guild, or Quest", "Quest"

---------------------------------------------------------------------------------------------------
-- Global functions for accessing the configuration
---------------------------------------------------------------------------------------------------

local function GetUnitVisibility(full_unit_type)
  local unit_visibility = TidyPlatesThreat.db.profile.Visibility[full_unit_type]

  local show = unit_visibility.Show
  if type(show) ~= "boolean" then
    show = (GetCVar(show) == "1")
  end

  return show, unit_visibility.UseHeadlineView
end

local function SetNamePlateClickThrough(friendly, enemy)
  if InCombatLockdown() then
    ThreatPlates.Print(L["Nameplate clickthrough cannot be changed while in combat."], true)
  else
    local db = TidyPlatesThreat.db.profile
    db.NamePlateFriendlyClickThrough = friendly
    db.NamePlateEnemyClickThrough = enemy
    C_NamePlate.SetNamePlateFriendlyClickThrough(friendly)
    C_NamePlate.SetNamePlateEnemyClickThrough(enemy)
  end
end

local function SyncWithGameSettings(friendly, enemy)
  if not InCombatLockdown() then
    local db = TidyPlatesThreat.db.profile
    C_NamePlate.SetNamePlateFriendlyClickThrough(db.NamePlateFriendlyClickThrough)
    C_NamePlate.SetNamePlateEnemyClickThrough(db.NamePlateEnemyClickThrough)
  end
end

---------------------------------------------------------------------------------------------------
-- Functions for configuration migration
---------------------------------------------------------------------------------------------------
local Defaults_V1 = {
  allowClass = false,
  friendlyClass = false,
  optionRoleDetectionAutomatic = false,
  HeadlineView = {
    width = 116,
  },
  text = {
    amount = true,
  },
  AuraWidget = {
    ModeBar = {
      Texture = "Smooth",
    },
  },
  uniqueWidget = {
    scale = 35,
    y = 24,
  },
  questWidget = {
    ON = false,
    ModeHPBar = true,
  },
  ResourceWidget  = {
    BarTexture = "Smooth"
  },
  settings = {
    elitehealthborder = {
      show = true,
    },
    healthborder = {
      texture = "TP_HealthBarOverlay",
    },
    healthbar = {
      texture = "ThreatPlatesBar",
      backdrop = "ThreatPlatesEmpty",
      BackgroundOpacity = 1,
    },
    castborder = {
      texture = "ThreatPlatesBar",
    },
    castbar = {
      texture = "ThreatPlatesBar",
    },
    name = {
      typeface = "Accidental Presidency",
      width = 116,
      size = 14,
    },
    level = {
      typeface = "Accidental Presidency",
      size = 12,
      height  = 14,
      x = 50,
      vertical  = "TOP"
    },
    customtext = {
      typeface = "Accidental Presidency",
      size = 12,
      y = 1,
    },
    spelltext = {
      typeface = "Accidental Presidency",
      size = 12,
      y = -13,
      y_hv  = -13,
    },
    eliteicon = {
      x = 64,
      y = 9,
    },
    skullicon = {
      x = 55,
    },
    raidicon = {
      y = 27,
      y_hv = 27,
    },
  },
  threat = {
    dps = {
      HIGH = 1.25,
    },
    tank = {
      LOW = 1.25,
    },
  },
}

local function UpdateAceDB(current_defaults, new_defaults)
  for key, new_value in pairs(new_defaults) do
    if type(new_value) == "table" then
      UpdateAceDB(current_defaults[key], new_defaults[key])
    else
      current_defaults[key] = new_defaults[key]
     end
  end
end

local function GetDefaultSettingsV1(defaults)
  local new_defaults = ThreatPlates.CopyTable(defaults)

--  local db = new_defaults.profile
--  db.allowClass = false
--  db.friendlyClass = false
--  db.optionRoleDetectionAutomatic = false
--  db.HeadlineView.width = 116
--  db.text.amount = true
--  db.AuraWidget.ModeBar.Texture = "Smooth"
--  db.uniqueWidget.scale = 35
--  db.uniqueWidget.y = 24
--  db.questWidget.ON = false
--  db.questWidget.ModeHPBar = true
--  db.ResourceWidget.BarTexture = "Smooth"
--  db.settings.elitehealthborder.show = true
--  db.settings.healthborder.texture = "TP_HealthBarOverlay"
--  db.settings.healthbar.texture = "ThreatPlatesBar"
--  db.settings.healthbar.backdrop = "ThreatPlatesEmpty"
--  db.settings.healthbar.BackgroundOpacity = 1
--  db.settings.castborder.texture = "ThreatPlatesBar"
--  db.settings.castbar.texture = "ThreatPlatesBar"
--  db.settings.name.typeface = "Accidental Presidency"
--  db.settings.name.width = 116
--  db.settings.name.size = 14
--  db.settings.level.typeface = "Accidental Presidency"
--  db.settings.level.size = 12
--  db.settings.level.height  = 14
--  db.settings.level.x = 50
--  db.settings.level.vertical = "TOP"
--  db.settings.customtext.typeface = "Accidental Presidency"
--  db.settings.customtext.size = 12
--  db.settings.customtext.y = 1
--  db.settings.spelltext.typeface = "Accidental Presidency"
--  db.settings.spelltext.size = 12
--  db.settings.spelltext.y = -13
--  db.settings.spelltext.y_hv = -13
--  db.settings.eliteicon.x = 64
--  db.settings.eliteicon.y = 9
--  db.settings.skullicon.x = 55
--  db.settings.raidicon.y = 27
--  db.settings.raidicon.y_hv = 27
--  db.threat.dps.HIGH = 1.25
--  db.threat.tank.LOW = 1.25

  UpdateAceDB(new_defaults.profile, Defaults_V1)

  return new_defaults
end

local function SwitchToDefaultSettingsV1()
  local db = TidyPlatesThreat.db
  local current_profile = db:GetCurrentProfile()

  db:SetProfile("_ThreatPlatesInternal")

  local defaults = ThreatPlates.GetDefaultSettingsV1(TidyPlatesThreat.DEFAULT_SETTINGS)
  db:RegisterDefaults(defaults)

  db:SetProfile(current_profile)
  db:DeleteProfile("_ThreatPlatesInternal")
end

local function SwitchToCurrentDefaultSettings()
  local db = TidyPlatesThreat.db
  local current_profile = db:GetCurrentProfile()

  db:SetProfile("_ThreatPlatesInternal")

  db:RegisterDefaults(TidyPlatesThreat.DEFAULT_SETTINGS)

  db:SetProfile(current_profile)
  db:DeleteProfile("_ThreatPlatesInternal")
end

---- Entries in the config db that should be migrated and deleted
--local DEPRECATED_DB_ENTRIES = {
--  alphaFeatures = true,
--  optionSpecDetectionAutomatic = true,
--  alphaFeatureHeadlineView = ConvertHeadlineView, -- migrate to headlineView.enabled
--}
--
---- Remove all deprected Entries
---- Called whenever the addon is loaded and a new version number is detected
--local function DeleteDeprecatedEntries()
--  -- determine current addon version and compare it with the DB version
--  local db_global = TidyPlatesThreat.db.global
--
--
--  -- Profiles:
--  if db_global.version ~= tostring(ThreatPlates.Meta("version")) then
--    -- addon version is newer that the db version => check for old entries
--    for profile, profile_table in pairs(TidyPlatesThreat.db.profiles) do
--      -- iterate over all profiles
--      for key, func in pairs(DEPRECATED_DB_ENTRIES) do
--        if profile_table[key] ~= nil then
--          if DEPRECATED_DB_ENTRIES[key] == true then
--            ThreatPlates.Print ("Deleting deprecated DB entry \"" .. tostring(key) .. "\"")
--            profile_table[key] = nil
--          elseif type(DEPRECATED_DB_ENTRIES[key]) == "function" then
--            ThreatPlates.Print ("Converting deprecated DB entry \"" .. tostring(key) .. "\"")
--            DEPRECATED_DB_ENTRIES[key](profile_table)
--          end
--        end
--      end
--    end
--  end
--end

-- convert current aura widget settings to aura widget 2.0
--local function ConvertAuraWidget1(profile_name, profile)
--  local old_setting = profile.debuffWidget
--  ThreatPlates.Print (L"xxxxProfile "] .. profile_name .. L": Converting settings from aura widget to aura widget 2.0 ..."])
--  if old_setting and not profile.AuraWidget then
--    ThreatPlates.Print (L"Profile "] .. profile_name .. L": Converting settings from aura widget to aura widget 2.0 ..."])
--    profile.AuraWidget = {}
--    local new_setting = profile.AuraWidget
--    if not new_setting.ModeIcon then
--      new_setting.ModeIcon = {}
--    end
--
--    new_setting.scale = old_setting.scale
--    new_setting.FilterMode = old_setting.style
--    new_setting.FilterMode = old_setting.mode
--    new_setting.ModeIcon.Style = old_setting.style
--    new_setting.ShowTargetOnly = old_setting.targetOnly
--    new_setting.ShowCooldownSpiral = old_setting.cooldownSpiral
--    new_setting.ShowFriendly = old_setting.showFriendly
--    new_setting.ShowEnemy = old_setting.showEnemy
--
--    if old_setting.filter then
--      new_setting.FilterBySpell = ThreatPlates.CopyTable(old_setting.filter)
--    end
--    if old_setting.displays then
--      new_setting.FilterByType = ThreatPlates.CopyTable(old_setting.displays)
--    end
--    old_setting.ON = false
--    print ("debuffWidget: ", profile.debuffWidget.ON)
--  end
--end

--local function MigrateDatabase()
--  -- determine current addon version and compare it with the DB version
--  local db_global = TidyPlatesThreat.db.global
--
--  --  -- addon version is newer that the db version => check for old entries
--  --	if db_global.version ~= tostring(ThreatPlates.Meta("version")) then
--  -- iterate over all profiles
--  local db
--  for name, profile in pairs(TidyPlatesThreat.db.profiles) do
--    ConvertAuraWidget1(name, profile)
--  end
--  --	end
--end

-- Update the configuration file:
--  - convert deprecated settings to their new counterpart
-- Called whenever the addon is loaded and a new version number is detected
--local function UpdateConfiguration()
--  -- determine current addon version and compare it with the DB version
--  local db_global = TidyPlatesThreat.db.global
--
--  --  -- addon version is newer that the db version => check for old entries
--  --	if db_global.version ~= tostring(ThreatPlates.Meta("version")) then
--  -- iterate over all profiles
--  for name, profile in pairs(TidyPlatesThreat.db.profiles) do
--    -- ConvertAuraWidget1(name, profile)
--  end
--  --	end
--end

--local CleanupDatabase()
--  delete internal profile, if still there: db:DeleteProfile("_ThreatPlatesInternal")
--then

-----------------------------------------------------
-- External
-----------------------------------------------------

ThreatPlates.GetDefaultSettingsV1 = GetDefaultSettingsV1
ThreatPlates.SwitchToCurrentDefaultSettings = SwitchToCurrentDefaultSettings
ThreatPlates.SwitchToDefaultSettingsV1 = SwitchToDefaultSettingsV1

--ThreatPlates.UpdateConfiguration = UpdateConfiguration
--ThreatPlates.MigrateDatabase = MigrateDatabase
ThreatPlates.GetUnitVisibility = GetUnitVisibility
ThreatPlates.SetNamePlateClickThrough = SetNamePlateClickThrough
ThreatPlates.SyncWithGameSettings = SyncWithGameSettings
