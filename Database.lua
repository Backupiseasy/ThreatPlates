local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Stuff for handling the database with the SavedVariables of ThreatPlates (ThreatPlatesDB)
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local floor = floor
local unpack = unpack
local type = type
local min = min
local pairs = pairs

-- WoW APIs
local InCombatLockdown = InCombatLockdown
local GetCVar = GetCVar

-- ThreatPlates APIs
local L = ThreatPlates.L
local TidyPlatesThreat = TidyPlatesThreat

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
    --TidyPlatesThreat.db.global.MigrationLog[profile_name .. "MigrationTargetScaleTarget"] = "Migrating Target from " .. profile.nameplate.scale.Target .. " to " .. (profile.nameplate.scale.Target - 1)
    profile.nameplate.scale.Target = profile.nameplate.scale.Target - 1
  end

  if DatabaseEntryExists(profile, { "nameplate", "scale", "NoTarget" }) then
    --TidyPlatesThreat.db.global.MigrationLog[profile_name .. "MigrationTargetScaleNoTarget"] = "Migrating NoTarget from " .. profile.nameplate.scale.NoTarget .. " to " .. (profile.nameplate.scale.NoTarget - 1)
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

---- Settings in the SavedVariables file that should be migrated and/or deleted
local DEPRECATED_SETTINGS = {
  NamesColor = { MigrateNamesColor, },  -- settings.name.color
  CustomTextShow = { MigrateCustomTextShow, }, -- settings.customtext.show
  BlizzFadeA = { MigrationBlizzFadeA, }, -- blizzFadeA.toggle and blizzFadeA.amount
  TargetScale= { MigrationTargetScale, "8.5.0" }, -- nameplate.scale.Target/NoTarget
  AlphaFeatures = { "alphaFeatures" },
  AlphaFeatureHeadlineView = { "alphaFeatureHeadlineView" },
  AlphaFeatureAuraWidget2= { "alphaFeatureAuraWidget2" },
  -- { "alphaFriendlyNameOnly" },
  -- { "HeadlineView", "blizzFading" },    -- in release 8.6 (removed in 8.5.1)
  -- { "HeadlineView", "blizzFadingAlpha"},-- in release 8.6 (removed in 8.5.1)
  -- { "HeadlineView", "name", "width" },  -- in release 8.6 (removed in 8.5.0)
  -- { "HeadlineView", "name", "height" }, -- in release 8.6 (removed in 8.5.0)
}

local function MigrateDatabase(current_version)
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
      -- TidyPlatesThreat.db.global.MigrationLog[key] = "DELETED"
      for profile_name, profile in pairs(profile_table) do
        DatabaseEntryDelete(profile, entry)
      end
    end
  end
end

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

-----------------------------------------------------
-- External
-----------------------------------------------------

ThreatPlates.GetDefaultSettingsV1 = GetDefaultSettingsV1
ThreatPlates.SwitchToCurrentDefaultSettings = SwitchToCurrentDefaultSettings
ThreatPlates.SwitchToDefaultSettingsV1 = SwitchToDefaultSettingsV1
ThreatPlates.MigrateDatabase = MigrateDatabase

ThreatPlates.GetUnitVisibility = GetUnitVisibility
ThreatPlates.SetNamePlateClickThrough = SetNamePlateClickThrough
ThreatPlates.SyncWithGameSettings = SyncWithGameSettings