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

-- ThreatPlates APIs
local L = ThreatPlates.L
local TidyPlatesThreat = TidyPlatesThreat
local RGB = Addon.RGB

---------------------------------------------------------------------------------------------------
-- Global functions for accessing the configuration
---------------------------------------------------------------------------------------------------

-- Sets the role of the index spec or the active spec to tank (value = true) or dps/healing
function TidyPlatesThreat:SetRole(value,index)
  if index then
    self.db.char.spec[index] = value
  else
    self.db.char.spec[GetSpecialization()] = value
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
      C_NamePlate.SetNamePlateFriendlyClickThrough(friendly)
      C_NamePlate.SetNamePlateEnemyClickThrough(enemy)
    end, L["Nameplate clickthrough cannot be changed while in combat."])
--  end
end

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
  db.StatusText.HealthbarMode.Font.Typeface = "Accidental Presidency"
  db.StatusText.HealthbarMode.Font.Size = 12
  db.StatusText.HealthbarMode.Font.VerticalOffset = 1
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
--        db.NonTarget = min(1, 1 + amount)
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

local function MigrationForceFriendlyInCombat(profile_name, profile)
  if DatabaseEntryExists(profile, { "HeadlineView" }) then
    if profile.HeadlineView.ForceFriendlyInCombat == true then
      profile.HeadlineView.ForceFriendlyInCombat = "NAME"
    elseif profile.HeadlineView.ForceFriendlyInCombat == false then
      profile.HeadlineView.ForceFriendlyInCombat = "NONE"
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
  }
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
  ["9.2.0"] = {
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
    -- Others
    { Deprecated = { "HeadlineView", "ShowTargetHighlight" }, New = { "targetWidget", "ShowInHeadlineView" }, },
  },
}

local function ExecuteMigrationFunctions(current_version)
  local profile_table = TidyPlatesThreat.db.profiles

  for max_version, entries in pairs(MIGRATION_FUNCTIONS) do
    if CurrentVersionIsLowerThan(current_version, max_version) then
      for key, migration_function in pairs(entries) do
        -- iterate over all profiles and migrate values
        --TidyPlatesThreat.db.global.MigrationLog[key] = "Migration" .. (max_version and ( " because " .. current_version .. " < " .. max_version) or "")
        for profile_name, profile in pairs(profile_table) do
          migration_function(profile_name, profile)
        end
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

local function DeleteEntry(current_entry, default_entry, prefix)
  for key, value in pairs(current_entry) do
    if key ~= "uniqueSettings" then
      local entry = prefix .. "." .. key
      if default_entry[key] == nil then
        print ("  =>", entry ..":", value)
        -- Delete current entry
      elseif type(value) == "table" then
        if type(default_entry[key]) == "table" then
          DeleteEntry(value, default_entry[key], entry)
        else -- This should never happen - i.e. an old entry (which was a table) is re-used as simple value)
          print ("  =>", entry ..": Type Mismatch - New Value is no table!")
        end
      end
    end
  end
end

function Addon:DeleteDeprecatedSettings()
  local profile_table = TidyPlatesThreat.db.profiles

  for profile_name, profile in pairs(profile_table) do
    print ("Profile:", profile_name)
    DeleteEntry(profile, ThreatPlates.DEFAULT_SETTINGS.profile, profile_name)
  end
end

-----------------------------------------------------
-- External
-----------------------------------------------------

ThreatPlates.GetDefaultSettingsV1 = GetDefaultSettingsV1
ThreatPlates.SwitchToCurrentDefaultSettings = SwitchToCurrentDefaultSettings
ThreatPlates.SwitchToDefaultSettingsV1 = SwitchToDefaultSettingsV1

ThreatPlates.GetUnitVisibility = GetUnitVisibility
ThreatPlates.SetNamePlateClickThrough = SetNamePlateClickThrough
