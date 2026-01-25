local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Functions for changing and savely restoring CVars (mostly after login/logout/reload UI)
---------------------------------------------------------------------------------------------------

-- Lua APIs
local tostring, tonumber, string_format = tostring, tonumber, string.format

-- WoW APIs
local SetCVar, GetCVar, GetCVarDefault, GetCVarBool = C_CVar.SetCVar, C_CVar.GetCVar, C_CVar.GetCVarDefault, C_CVar.GetCVarBool

-- ThreatPlates APIs
local L = Addon.L

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
  nameplateLargeBottomInset = true, -- Removed in Midnight
  nameplateLargeTopInset = true,    -- Removed in Midnight
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
  nameplateShowFriendlyPlayers = true,
  nameplateShowFriendlyNPCs = true,
  nameplateShowFriendlyGuardians = true,
  nameplateShowFriendlyMinions = true,
  nameplateShowFriendlyPets = true,
  nameplateShowFriendlyTotems = true,
  nameplateShowFriendlyPlayerGuardians = true,
  nameplateShowFriendlyPlayerMinions = true,
  nameplateShowFriendlyPlayerPets = true,
  nameplateShowFriendlyPlayerTotems = true,
  nameplateShowOnlyNames = true,
  nameplateShowOnlyNameForFriendlyPlayerUnits = true,
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

local MONITORED_CVARS = {
  nameplateMinScale = true,
  nameplateMaxScale = true,
  nameplateLargerScale = true,
  nameplateSelectedScale = true,
  nameplateMinAlpha = true,
  nameplateMaxAlpha = true,
  nameplateOccludedAlphaMult = true,
  nameplateSelectedAlpha = true,
}

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

  SetCVar(cvar, value)
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
    SetCVar(cvar, db[cvar])
    db[cvar] = nil
  end
end

--function CVars:RestoreAllFromProfile()
--  local db = Addon.db.profile.CVarsBackup
--
--  for cvar, value in pairs(db) do
--    SetCVar(cvar, value)
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
  "nameplateMotion", "nameplateMotionSpeed", "nameplateOverlapH", "nameplateOverlapV",
  "nameplateMaxDistance", "nameplateTargetBehindMaxDistance",
  "nameplateShowOnlyNames", 
  "clampTargetNameplateToScreen",
  "nameplateResourceOnTarget",
  (not Addon.ExpansionIsAtLeastMidnight and "nameplateLargeTopInset") or nil, -- Removed in Midnight
  (not Addon.ExpansionIsAtLeastMidnight and "nameplateLargeBottomInset") or nil, -- Removed in Midnight
  (not Addon.ExpansionIsAtLeastMidnight and "nameplateOtherTopInset") or nil, -- Removed in Midnight
  (not Addon.ExpansionIsAtLeastMidnight and "nameplateOtherBottomInset") or nil, -- Removed in Midnight
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

local function SetCVarHook(name, value, c)
  if not MONITORED_CVARS[name] then return end

  -- if name == "nameplateMinScale" or name == "nameplateMaxScale" or name == "nameplateLargerScale" or name == "nameplateSelectedScale" then
  --   -- Update Hiding Nameplates only if something changed
  --   local enabled = Addon.Scaling.HidingNameplatesIsEnabled()
  --   local invalid = CVars.InvalidCVarsForHidingNameplates()
  --   if (enabled and invalid) or (not enabled and not invalid) then
  --     Addon.Scaling:UpdateSettings()
  --     --Addon:ForceUpdate()
  --   elseif invalid then
  --     Addon.Logging.Warning(L["Animations for hiding nameplates are being disabled as certain console variables (CVars) related to nameplate scaling are set in a way to prevent this feature from working."])
  --   end
  if name == "nameplateMinAlpha" or name == "nameplateMaxAlpha" or name == "nameplateOccludedAlphaMult" or name == "nameplateSelectedAlpha" then
    local enabled = Addon.Transparency.OcclusionDetectionIsEnabled()
    local invalid = CVars.InvalidCVarsForOcclusionDetection()
    -- Update Hiding Nameplates only if something changed
    if (enabled and invalid) or (not enabled and not invalid) then
      Addon.Transparency:UpdateSettings()
      --Addon:ForceUpdate()
    elseif invalid then
      Addon.Logging.Warning(L["Transparency for occluded units is being disabled as certain console variables (CVars) related to nameplate transparency are set in a way to prevent this feature from working."])
    end
  end
end

function CVars.RegisterCVarHook()
  -- Tracking of CVars based on code from AdvancedInterfaceOptions
  --hooksecurefunc("SetCVar", SetCVarHook) -- /script SetCVar(cvar, value)
  if C_CVar and C_CVar.SetCVar then
    hooksecurefunc(C_CVar, "SetCVar", SetCVarHook) -- C_CVar.SetCVar(cvar, value)
  end
  hooksecurefunc("ConsoleExec", function(msg)
    local cmd, cvar, value = msg:match("^(%S+)%s+(%S+)%s*(%S*)")
    if cmd then
      if cmd:lower() == 'set' then -- /console SET cvar value
        SetCVarHook(cvar, value)
      else -- /console cvar value
        SetCVarHook(cmd, cvar)
      end
    end
  end)
end

function CVars.InvalidCVarsForHidingNameplates()
  local nameplateMinScale = CVars:GetAsNumber("nameplateMinScale")
  local nameplateMaxScale = CVars:GetAsNumber("nameplateMaxScale")
  local nameplateLargerScale = CVars:GetAsNumber("nameplateLargerScale")
  local nameplateSelectedScale = CVars:GetAsNumber("nameplateSelectedScale")

  return nameplateMinScale >= nameplateMaxScale or nameplateMinScale >= nameplateLargerScale or nameplateMinScale >= nameplateSelectedScale
end

function CVars.FixCVarsForHidingNameplates()
  SetCVar("nameplateMinScale", 0.8)       -- Default: 0.8, (TBC) Classic: 1.0
  SetCVar("nameplateMaxScale", 1.0)       -- Default: 1.0
  SetCVar("nameplateLargerScale", 1.2)    -- Default: 1.2
  SetCVar("nameplateSelectedScale", 1.2)  -- Default: 1.2, (TBC) Classic: 1.0
end

function CVars.InvalidCVarsForOcclusionDetection()
  local nameplateMinAlpha = CVars:GetAsNumber("nameplateMinAlpha")
  local nameplateMaxAlpha = CVars:GetAsNumber("nameplateMaxAlpha")
  local nameplateOccludedAlphaMult = CVars:GetAsNumber("nameplateOccludedAlphaMult")
  local nameplateSelectedAlpha = CVars:GetAsNumber("nameplateSelectedAlpha")

  local invalid = nameplateMinAlpha ~= 1 or nameplateMaxAlpha ~= 1 or nameplateOccludedAlphaMult > 0.9 or nameplateSelectedAlpha ~= 1

  -- Occlusion detection does not work when a target is selected in Classic, see https://github.com/Stanzilla/WoWUIBugs/issues/134
  if not Addon.IS_MAINLINE then
    local nameplateNotSelectedAlpha = CVars:GetAsNumber("nameplateNotSelectedAlpha")
    return invalid or nameplateNotSelectedAlpha ~= 1
  end

  return invalid
end

function CVars.FixCVarsForOcclusionDetection()
  SetCVar("nameplateMinAlpha", 1.0)          -- Default: 0.6, (TBC) Classic: 1.0
  SetCVar("nameplateMaxAlpha", 1.0)          -- Default: 1.0
  SetCVar("nameplateOccludedAlphaMult", 0.4) -- Default: 0.4, (TBC) Classic: 1.0
  SetCVar("nameplateSelectedAlpha", 1.0)     -- Default: 1.0

  -- Occlusion detection does not work when a target is selected in Classic, see https://github.com/Stanzilla/WoWUIBugs/issues/134
  if not Addon.IS_MAINLINE then
    SetCVar("nameplateNotSelectedAlpha", 1)  -- Default: 0.5
  end

  -- Legacy Code:
  -- Addon.CVars:Set("nameplateMinAlpha", 1)
  -- Addon.CVars:Set("nameplateMaxAlpha", 1)

  -- -- Create enough separation between occluded and not occluded nameplates, even for targeted units
  -- local occluded_alpha_mult = tonumber(GetCVar("nameplateOccludedAlphaMult"))
  -- if occluded_alpha_mult > 0.9  then
  --   occluded_alpha_mult = 0.9
  --   Addon.CVars:Set("nameplateOccludedAlphaMult", occluded_alpha_mult)
  -- end

  -- local selected_alpha =  tonumber(GetCVar("nameplateSelectedAlpha"))
  -- if not selected_alpha or (selected_alpha < occluded_alpha_mult + 0.1) then
  --   selected_alpha = occluded_alpha_mult + 0.1
  --   Addon.CVars:Set("nameplateSelectedAlpha", selected_alpha)
  -- end
end

