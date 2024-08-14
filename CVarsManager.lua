local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Functions for changing and savely restoring CVars (mostly after login/logout/reload UI)
---------------------------------------------------------------------------------------------------

-- Lua APIs
local tostring, string_format = tostring, string.format

-- WoW APIs
local GetCVar, GetCVarDefault, GetCVarBool = GetCVar, GetCVarDefault, C_CVar.GetCVarBool

-- ThreatPlates APIs
local L = ThreatPlates.L

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: SetCVar

Addon.CVars = {}

local CVars = Addon.CVars

local COMBAT_PROTECTED = {
  -- Miscellaneous
  uiScale = true,
  -- Nameplate CVars
  nameplateLargeBottomInset = true,
  nameplateLargeTopInset = true,
  nameplateMaxAlpha = true,
  nameplateMaxDistance = true,
  nameplateMinAlpha = true,
  nameplateMotion = true,
  nameplateMotionSpeed = true,
  nameplateOccludedAlphaMult = true,
  nameplateOtherBottomInset = true,
  nameplateOtherTopInset = true,
  nameplateOverlapH = true,
  nameplateOverlapV = true,
  nameplateResourceOnTarget = true,
  nameplateSelectedAlpha = true,
  nameplateNotSelectedAlpha = true,
  nameplateTargetBehindMaxDistance = true,
  -- Nameplate Visibility CVars
  nameplateShowAll = true,
  nameplateShowFriends = true,
  nameplateShowEnemies = true,
  nameplateShowEnemyGuardians = true,
  nameplateShowEnemyMinions = true,
  nameplateShowEnemyMinus = true,
  nameplateShowEnemyPets = true,
  nameplateShowEnemyTotems = true,
  nameplateShowFriendlyGuardians = true,
  nameplateShowFriendlyMinions = true,
  nameplateShowFriendlyNPCs = true,
  nameplateShowFriendlyPets = true,
  nameplateShowFriendlyTotems = true,
  nameplateShowOnlyNames = true,
  -- Soft Target CVars
  SoftTargetForce = true,
  SoftTargetEnemy = true,
  SoftTargetNameplateEnemy = true,
  SoftTargetIconEnemy = true,
  SoftTargetNameplateFriend = true,
  SoftTargetIconFriend = true,
  SoftTargetInteract = true,
  SoftTargetNameplateInteract = true,
  SoftTargetIconInteract = true,
  SoftTargetIconGameObject = true,
  SoftTargetLowPriorityIcons = true,
  -- Name CVars
  UnitNameFriendlyPlayerName = true,
  UnitNameFriendlyPetName = true,
  UnitNameFriendlyGuardianName = true,
  UnitNameFriendlyTotemName = true,
  UnitNameFriendlyMinionName = true,
}

---------------------------------------------------------------------------------------------------
-- Initialize CVars for Threat Plates
---------------------------------------------------------------------------------------------------

-- Set these CVars after login/reloading the UI
function CVars:Initialize(cvar, value)
  -- Fix for: Friendly Nameplates Name Only Mode in Raids and Dungeons for Patch 10.0.5
  -- https://www.wowhead.com/de/news/update-solution-to-friendly-nameplates-name-only-mode-in-raids-and-dungeons-for-331178
  -- /script C_CVar.RegisterCVar("nameplateShowOnlyNames")
  -- Registering only has to be done once, but the value seems to be reset to 0 after every reload 
  if C_CVar.GetCVar("nameplateShowOnlyNames") == nil then
    C_CVar.RegisterCVar("nameplateShowOnlyNames")
  end

  -- ! The CVar nameplateShowOnlyNames is not persistently stored by WoW, so we have to restore its value
  -- ! after every login/reloading the UI.
  self:SetBool("nameplateShowOnlyNames", Addon.db.profile.BlizzardSettings.Names.ShowOnlyNames)

  -- Sync internal settings with Blizzard CVars
  -- SetCVar("ShowClassColorInNameplate", 1)

  --  local db = Addon.db.profile.threat
  --  -- Required for threat/aggro detection
  --  if db.ON and (GetCVar("threatWarning") ~= 3) then
  --    SetCVar("threatWarning", 3)
  --  elseif not db.ON and (GetCVar("threatWarning") ~= 0) then
  --    SetCVar("threatWarning", 0)
  --  end
end

---------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------

local function SetConsoleVariable(cvar, value)
  -- Store in settings to be able to restore it later, but don't overwrite an existing value unless the current value
  -- is different from the backup value and the new value TP wants to set. In that case, the CVars was changed since
  -- last login with TP by the player or another addon.
  local db = Addon.db.profile.CVarsBackup

  value = tostring(value) -- convert to string, otherwise the following comparisons would compare numbers with strings
  local current_value = GetCVar(cvar)
  local backup_value = db[cvar]

  if (value ~= current_value) and (current_value ~= backup_value) then
    db[cvar] = current_value
  end

  _G.SetCVar(cvar, value)
end

function CVars:Set(cvar, value)
  if COMBAT_PROTECTED[cvar] then
    Addon:CallbackWhenOoC(function()
      SetConsoleVariable(cvar, value)
    end, L["Unable to change the following console variable while in combat: "] .. cvar .. ". ")
  else
    SetConsoleVariable(cvar, value)
  end
end

function CVars:SetBool(cvar, value)
  self:Set(cvar, (value and 1) or 0)
end

function CVars:SetToDefault(cvar)
  if COMBAT_PROTECTED[cvar] then
    Addon:CallbackWhenOoC(function()
      _G.SetCVar(cvar, GetCVarDefault(cvar))
      Addon.db.profile.CVarsBackup[cvar] = nil
    end, L["Unable to change the following console variable while in combat: "] .. cvar .. ". ")
  else
    _G.SetCVar(cvar, GetCVarDefault(cvar))
    Addon.db.profile.CVarsBackup[cvar] = nil
  end
end

function CVars:Overwrite(cvar, value)
  if COMBAT_PROTECTED[cvar] then
    Addon:CallbackWhenOoC(function()
      _G.SetCVar(cvar, value)
    end, L["Unable to change the following console variable while in combat: "] .. cvar .. ". ")
  else
    _G.SetCVar(cvar, value)
  end
end

function CVars:OverwriteBool(cvar, value)
  self:Overwrite(cvar, (value and 1) or 0)
end

function CVars:RestoreFromProfile(cvar)
  local db = Addon.db.profile.CVarsBackup

  if db[cvar] then
    _G.SetCVar(cvar, db[cvar])
    db[cvar] = nil
  end
end

--function CVars:RestoreAllFromProfile()
--  local db = Addon.db.profile.CVarsBackup
--
--  for cvar, value in pairs(db) do
--    _G.SetCVar(cvar, value)
--    db[cvar] = nil
--  end
--end

function CVars:Get(cvar)
  return GetCVar(cvar)
end

function CVars:GetAsNumber(cvar)
  local value = GetCVar(cvar)
  local numeric_value = tonumber(value)

  if not numeric_value then
    Addon.Logging.Warning(string_format(L["CVar %s has an invalid value: %s. The value must be a number. Using the default value for this CVar instead."], cvar, value))
    numeric_value = tonumber(GetCVarDefault(cvar))
  end

 return numeric_value
end

function CVars:GetAsBool(cvar)
  return GetCVarBool(cvar)
end

---------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------

-- From addon: AdvancedInterfaceOptions
function CVars:CVarExists(cvar)
	return not not select(2, pcall(function() return addon.GetCVarInfo(cvar) end))
end

local RESET_TO_DEFAULT = {
  "nameplateOtherTopInset", "nameplateOtherBottomInset", "nameplateLargeTopInset", "nameplateLargeBottomInset",
  "nameplateMotion", "nameplateMotionSpeed", "nameplateOverlapH", "nameplateOverlapV",
  "nameplateMaxDistance", "nameplateTargetBehindMaxDistance",
  "nameplateShowOnlyNames", 
  "clampTargetNameplateToScreen",
  "nameplateResourceOnTarget",
  -- "nameplateGlobalScale" -- Reset it to 1, if it get's somehow corrupted
  -- Action Target
  "SoftTargetEnemy", "SoftTargetNameplateEnemy", "SoftTargetIconEnemy",
  "SoftTargetFriend", "SoftTargetNameplateFriend", "SoftTargetIconFriend",
  "SoftTargetInteract", "SoftTargetNameplateInteract", "SoftTargetIconInteract",
  "SoftTargetIconGameObject", "SoftTargetLowPriorityIcons",
}

function CVars:ResetToDefaults()
  for k, v in pairs(RESET_TO_DEFAULT) do
    if self:CVarExists(k) then
      self:SetToDefault(v)
    end
  end
end