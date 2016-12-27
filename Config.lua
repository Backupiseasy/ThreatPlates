local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Stuff for handling the configuration of Threat Plates - ThreatPlatesDB
---------------------------------------------------------------------------------------------------

local L = ThreatPlates.L

local function UpdateDefaultProfile()
  local db = TidyPlatesThreat.db

  -- change the settings of the default profile
  local current_profile = db:GetCurrentProfile()
  db:SetProfile("Default")

  db.profile.optionRoleDetectionAutomatic = true
  db.profile.debuffWidget.ON = false
  db.profile.ShowThreatGlowOnAttackedUnitsOnly = true
  db.profile.AuraWidget.ON = true
  db.profile.text.amount = false
  db.profile.settings.healthborder.texture = "TP_HealthBarOverlayThin"
  db.profile.settings.healthbar.texture = "Aluminium"
  db.profile.settings.castbar.texture = "Aluminium"
  db.profile.settings.name.typeface = "Friz Quadrata TT"
  db.profile.settings.name.size = 10
  db.profile.settings.level.typeface = "Friz Quadrata TT"
  db.profile.settings.level.size = 9
  db.profile.settings.level.width = 22
  db.profile.settings.level.x = 49
  db.profile.settings.level.y = -2
  db.profile.settings.customtext.typeface = "Friz Quadrata TT"
  db.profile.settings.customtext.size = 9
  db.profile.settings.customtext.y = 0
  db.profile.settings.spelltext.typeface = "Friz Quadrata TT"
  db.profile.settings.spelltext.size = 8
  db.profile.settings.spelltext.y = -15
  db.profile.threat.useScale = false
  db.profile.threat.art.ON = false
  db.profile.questWidget.ON = true
  db.profile.questWidget.ModeHPBar = false

  db:SetProfile(current_profile)

  if current_profile == "Default" then
    ThreatPlates.SetThemes(TidyPlatesThreat)
    TidyPlates:ForceUpdate()
  end
end

--local function UpdateSettingValue(old_setting, key, new_setting, new_key)
--  if not new_key then
--    new_key = key
--  end
--
--  local value = old_setting[key]
--  if value then
--    if type(value) == "table" then
--      new_setting[new_key] = t.CopyTable(value)
--    else
--      new_setting[new_key] = value
--    end
--  end
--end

-- convert current aura widget settings to aura widget 2.0
local function ConvertAuraWidget1(profile_name, profile)
  local old_setting = profile.debuffWidget
  if old_setting then
    ThreatPlates.Print (L["Profile "] .. profile_name .. L[": Converting settings from aura widget to aura widget 2.0 ..."])
    local new_setting = profile.AuraWidget

    if not new_setting then new_setting = {} end
    if not new_setting.ModeIcon then new_setting.ModeIcon = {} end

    new_setting.y = old_setting.y
    new_setting.scale = old_setting.scale
    new_setting.anchor = old_setting.anchor
    new_setting.FilterMode = old_setting.style
    new_setting.FilterMode = old_setting.mode
    new_setting.ModeIcon.Style = old_setting.style
    new_setting.ShowTargetOnly = old_setting.targetOnly
    new_setting.ShowCooldownSpiral = old_setting.cooldownSpiral
    new_setting.ShowFriendly = old_setting.showFriendly
    new_setting.ShowEnemy = old_setting.showEnemy

    if old_setting.filter then new_setting.FilterBySpell = ThreatPlates.CopyTable(old_setting.filter) end
    if old_setting.displays then new_setting.FilterByType = ThreatPlates.CopyTable(old_setting.displays) end
  end
end

-- Update the configuration file:
--  - convert deprecated settings to their new counterpart
-- Called whenever the addon is loaded and a new version number is detected
local function UpdateConfiguration()
  -- determine current addon version and compare it with the DB version
  local db_global = TidyPlatesThreat.db.global

  --  -- addon version is newer that the db version => check for old entries
  --	if db_global.version ~= tostring(ThreatPlates.Meta("version")) then
  -- iterate over all profiles
  for name, profile in pairs(TidyPlatesThreat.db.profiles) do
    ConvertAuraWidget1(name, profile)
  end
  --	end
end

-----------------------------------------------------
-- External
-----------------------------------------------------

ThreatPlates.UpdateDefaultProfile = UpdateDefaultProfile
ThreatPlates.UpdateConfiguration = UpdateConfiguration
