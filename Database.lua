local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

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
local SetCVar = SetCVar

-- ThreatPlates APIs
local L = ThreatPlates.L
local TidyPlatesThreat = TidyPlatesThreat
local RGB = ThreatPlates.RGB

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
--  if InCombatLockdown() then
--    ThreatPlates.Print(L["Nameplate clickthrough cannot be changed while in combat."], true)
--  else
    local db = TidyPlatesThreat.db.profile
    db.NamePlateFriendlyClickThrough = friendly
    db.NamePlateEnemyClickThrough = enemy
    Addon:CallbackWhenOoC(function()
      C_NamePlate.
      SetNamePlateFriendlyClickThrough(friendly)
      C_NamePlate.SetNamePlateEnemyClickThrough(enemy)
    end, L["Nameplate clickthrough cannot be changed while in combat."])
--  end
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

local function MigrateAuraWidget(profile_name, profile)
  if DatabaseEntryExists(profile, { "debuffWidget" }) then
    if not profile.AuraWidget.ON and not profile.AuraWidget.ShowInHeadlineView then
      profile.AuraWidget = profile.AuraWidget or {}
      profile.AuraWidget.ModeIcon = profile.AuraWidget.ModeIcon or {}

      profile.AuraWidget.FilterMode = profile.debuffWidget.mode
      profile.AuraWidget.ModeIcon.Style = profile.debuffWidget.style
      profile.AuraWidget.ShowTargetOnly = profile.debuffWidget.targetOnly
      profile.AuraWidget.ShowCooldownSpiral = profile.debuffWidget.cooldownSpiral
      profile.AuraWidget.ShowFriendly = profile.debuffWidget.showFriendly
      profile.AuraWidget.ShowEnemy = profile.debuffWidget.showEnemy
      profile.AuraWidget.scale = profile.debuffWidget.scale

      if profile.debuffWidget.displays then
        profile.AuraWidget.FilterByType = ThreatPlates.CopyTable(profile.debuffWidget.displays)
      end

      if profile.debuffWidget.filter then
        profile.AuraWidget.FilterBySpell = ThreatPlates.CopyTable(profile.debuffWidget.filter)
      end

      -- DatabaseEntryDelete(profile, { "debuffWidget" })
    end
  end
end

---- Settings in the SavedVariables file that should be migrated and/or deleted
local DEPRECATED_SETTINGS = {
  NamesColor = { MigrateNamesColor, },                        -- settings.name.color
  CustomTextShow = { MigrateCustomTextShow, },                -- settings.customtext.show
  BlizzFadeA = { MigrationBlizzFadeA, },                      -- blizzFadeA.toggle and blizzFadeA.amount
  TargetScale = { MigrationTargetScale, "8.5.0" },            -- nameplate.scale.Target/NoTarget
  --AuraWidget = { MigrateAuraWidget, "8.6.0" },              -- disabled until someone requests it
  AlphaFeatures = { "alphaFeatures" },
  AlphaFeatureHeadlineView = { "alphaFeatureHeadlineView" },
  AlphaFeatureAuraWidget2= { "alphaFeatureAuraWidget2" },
  AlphaFriendlyNameOnly = { "alphaFriendlyNameOnly" },
  HVBlizzFarding = { "HeadlineView", "blizzFading" },         -- (removed in 8.5.1)
  HVBlizzFadingAlpha = { "HeadlineView", "blizzFadingAlpha"}, -- (removed in 8.5.1)
  HVNameWidth = { "HeadlineView", "name", "width" },          -- (removed in 8.5.0)
  HVNameHeight = { "HeadlineView", "name", "height" },        -- (removed in 8.5.0)
  DebuffWidget = { "debuffWidget" },                          -- (removed in 8.6.0)
  OldSettings = { "OldSettings" },                            -- (removed in 8.7.0)
  CastbarColoring = { MigrateCastbarColoring, },              -- (removed in 8.7.0)
  TotemSettings = { MigrationTotemSettings, "8.7.0" },        -- (changed in 8.7.0)
  Borders = { MigrateBorderTextures, "8.7.0" },               -- (changed in 8.7.0)
  UniqueSettingsList = { "uniqueSettings", "list" },          -- (removed in 8.7.0, cleanup added in 8.7.1)
}

local function MigrateDatabase(current_version)
  TidyPlatesThreat.db.global.MigrationLog = nil
  -- TidyPlatesThreat.db.global.MigrationLog = {}

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

-----------------------------------------------------
-- External
-----------------------------------------------------

ThreatPlates.GetDefaultSettingsV1 = GetDefaultSettingsV1
ThreatPlates.SwitchToCurrentDefaultSettings = SwitchToCurrentDefaultSettings
ThreatPlates.SwitchToDefaultSettingsV1 = SwitchToDefaultSettingsV1
ThreatPlates.MigrateDatabase = MigrateDatabase

ThreatPlates.GetUnitVisibility = GetUnitVisibility
ThreatPlates.SetNamePlateClickThrough = SetNamePlateClickThrough