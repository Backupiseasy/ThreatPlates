local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Stuff for handling the database with the SavedVariables of ThreatPlates (ThreatPlatesDB)
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local InCombatLockdown = InCombatLockdown
local RGB = ThreatPlates.RGB
local L = ThreatPlates.L

---------------------------------------------------------------------------------------------------
-- Global functions for accessing the configuration
---------------------------------------------------------------------------------------------------

-- Returns if the currently active spec is tank (true) or dps/heal (false)
function TidyPlatesThreat:GetSpecRole()
  local active_role

  if (self.db.profile.optionRoleDetectionAutomatic) then
    active_role = ThreatPlates.SPEC_ROLES[ThreatPlates.Class()][ThreatPlates.Active()]
    if not active_role then active_role = false end
  else
    active_role = self.db.char.spec[ThreatPlates.Active()]
  end

  return active_role
end

-- Sets the role of the index spec or the active spec to tank (value = true) or dps/healing
function TidyPlatesThreat:SetRole(value,index)
  if index then
    self.db.char.spec[index] = value
  else
    self.db.char.spec[ThreatPlates.Active()] = value
  end
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
-- Functions for migration of SavedVariables settings
---------------------------------------------------------------------------------------------------

local function GetDefaultSettingsV1(defaults)
  local new_defaults = ThreatPlates.CopyTable(defaults)

  local db = new_defaults.profile
  db.allowClass = false
  db.friendlyClass = false
  db.optionRoleDetectionAutomatic = false
  db.HeadlineView.width = 116
  db.text.amount = true
  db.AuraWidget.ModeBar.Texture = "Aluminium"
  db.uniqueWidget.scale = 35
  db.uniqueWidget.y = 24
  db.questWidget.ON = false
  db.questWidget.ShowInHeadlineView = false
  db.questWidget.ModeHPBar = true
  db.ResourceWidget.BarTexture = "Aluminium"
  db.settings.elitehealthborder.show = true
  db.settings.healthborder.texture = "TP_HealthBarOverlay"
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

local function MigrateNamesColor(profile_name, profile)
  local old_color = { r = 1, g = 1, b = 1 }

  if profile.settings and profile.settings.name and profile.settings.name.color then
    local db = profile.settings.name
    local color = db.color

    color.r = color.r or old_color.r
    color.g = color.g or old_color.g
    color.b = color.b or old_color.b

    db.EnemyTextColor = ThreatPlates.CopyTable(color)
    db.FriendlyTextColor = ThreatPlates.CopyTable(color)
    db.color = nil
  end
end

local function MigrateCustomTextShow(profile_name, profile)
  -- default for blizzFadeA.amount was -0.3
  if profile.blizzFadeA and profile.blizzFadeA.amount ~= nil then
    local db = profile.blizzFadeA

    local amount = db.amount
    if amount <= 0 then
      db.amount = 1 + amount
    end
  end
end

local function MigrationBlizzFadeA(profile_name, profile)
  -- default for db.show was true
  if profile.settings and profile.settings.customtext and profile.settings.customtext.show ~= nil then
    local db = profile.settings.customtext
    db.FriendlySubtext = "NONE"
    db.EnemySubtext = "NONE"
    db.show = nil
  end
end

local function DeleteDatabaseEntry(db, entry)
  local head = table.remove(entry, 1)
  if #entry == 0 then
    db[head] = nil
  elseif db ~= nil then
    DeleteDatabaseEntry(db[head], entry)
  end
end

---- Settings in the SavedVariables file that should be migrated and/or deleted
local DEPRECATED_SETTINGS = {
  MigrateNamesColor, -- settings.name.color
  MigrateCustomTextShow, -- settings.customtext.show
  MigrationBlizzFadeA, -- blizzFadeA.toggle and blizzFadeA.amount
  { "alphaFeatures" },
  { "alphaFeatureHeadlineView" },
  { "alphaFeatureAuraWidget2" },
  -- { "alphaFriendlyNameOnly" },
  -- { "HeadlineView", "blizzFading" },    -- in release 8.6 (removed in 8.5.1)
  -- { "HeadlineView", "blizzFadingAlpha"},-- in release 8.6 (removed in 8.5.1)
  -- { "HeadlineView", "name", "width" },  -- in release 8.6 (removed in 8.5.0)
  -- { "HeadlineView", "name", "height" }, -- in release 8.6 (removed in 8.5.0)
}

local function MigrateDatabase()
  ThreatPlates.Print(L["Migrating deprecated settings in configuration ..."])

  local profile_table = TidyPlatesThreat.db.profiles
  for i, entry in ipairs(DEPRECATED_SETTINGS) do

    -- iterate over all profiles
    for profile_name, profile in pairs(profile_table) do

      if type(entry) == "function" then
        entry(profile_name, profile)
      else
        -- delete the old config entry
        DeleteDatabaseEntry(profile, ThreatPlates.CopyTable(entry))
      end
    end
  end
end

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
ThreatPlates.MigrateDatabase = MigrateDatabase

--ThreatPlates.UpdateConfiguration = UpdateConfiguration
--ThreatPlates.MigrateDatabase = MigrateDatabase
ThreatPlates.GetUnitVisibility = GetUnitVisibility
ThreatPlates.SetNamePlateClickThrough = SetNamePlateClickThrough
ThreatPlates.SyncWithGameSettings = SyncWithGameSettings