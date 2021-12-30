local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Functions for changing and savely restoring CVars (mostly after login/logout/reload UI)
---------------------------------------------------------------------------------------------------

-- Lua APIs
local tostring = tostring

-- WoW APIs
local GetCVar, GetCVarDefault = GetCVar, GetCVarDefault
local IsInInstance = IsInInstance
local NamePlateDriverFrame = NamePlateDriverFrame

-- ThreatPlates APIs
local TidyPlatesThreat, ThreatPlates = TidyPlatesThreat, Addon.ThreatPlates
local L = Addon.L

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: SetCVar

Addon.CVars = {}

local CVars = Addon.CVars

local COMBAT_PROTECTED = {
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
  nameplateTargetBehindMaxDistance = true,
  -- Nameplate CVars
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
}

local MONITORED_CVARS = {
  NamePlateVerticalScale = true,
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
  local db = TidyPlatesThreat.db.profile.CVarsBackup

  value = tostring(value) -- convert to string, otherwise the following comparisons would compare numbers with strings
  local current_value = GetCVar(cvar)
  local backup_value = db[cvar]

  if (value ~= current_value) and (current_value ~= backup_value) then
    db[cvar] = current_value
  end

  _G.SetCVar(cvar, value)
end

function CVars:Set(cvar, value)
  SetConsoleVariable(cvar, value)
end

function CVars:SetToDefault(cvar)
  _G.SetCVar(cvar, GetCVarDefault(cvar))
  TidyPlatesThreat.db.profile.CVarsBackup[cvar] = nil
end

function CVars:RestoreFromProfile(cvar)
  local db = TidyPlatesThreat.db.profile.CVarsBackup

  if db[cvar] then
    _G.SetCVar(cvar, db[cvar])
    db[cvar] = nil
  end
end

--function CVars:RestoreAllFromProfile()
--  local db = TidyPlatesThreat.db.profile.CVarsBackup
--
--  for cvar, value in pairs(db) do
--    _G.SetCVar(cvar, value)
--    db[cvar] = nil
--  end
--end

--function CVars:GetAsNumber(cvar)
--  local value = tonumber(GetCVar(cvar))
--
--  if not value then
--    value = tonumber(GetCVarDefault(cvar))
--  end
--
--  return value
--end

---------------------------------------------------------------------------------------------------
-- Set CVars in a safe way when in combat
---------------------------------------------------------------------------------------------------

function CVars:SetProtected(cvar, value)
  if COMBAT_PROTECTED[cvar] then
    Addon:CallbackWhenOoC(function()
      SetConsoleVariable(cvar, value)
    end, L["Unable to change the following console variable while in combat: "] .. cvar .. ". ")
  else
    SetConsoleVariable(cvar, value)
  end
end

function CVars:SetBoolProtected(cvar, value)
  self:SetProtected(cvar, (value and 1) or 0)
end

function CVars:SetToDefaultProtected(cvar)
  if COMBAT_PROTECTED[cvar] then
    Addon:CallbackWhenOoC(function()
      _G.SetCVar(cvar, GetCVarDefault())
      TidyPlatesThreat.db.profile.CVarsBackup[cvar] = nil
    end, L["Unable to change the following console variable while in combat: "] .. cvar .. ". ")
  else
    _G.SetCVar(cvar, GetCVarDefault())
    TidyPlatesThreat.db.profile.CVarsBackup[cvar] = nil
  end
end

function CVars:OverwriteProtected(cvar, value)
  if COMBAT_PROTECTED[cvar] then
    Addon:CallbackWhenOoC(function()
      _G.SetCVar(cvar, value)
    end, L["Unable to change the following console variable while in combat: "] .. cvar .. ". ")
  else
    _G.SetCVar(cvar, value)
  end
end

function CVars:OverwriteBoolProtected(cvar, value)
  self:OverwriteProtected(cvar, (value and 1) or 0)
end

local function SetCVarHook(name, value, c)
  if not MONITORED_CVARS[name] then return end

  -- Used as detection for switching between small and large nameplates
  if name == "NamePlateVerticalScale" then
    local db = TidyPlatesThreat.db.profile.Automation
    local isInstance, _ = IsInInstance()

    if not NamePlateDriverFrame:IsUsingLargerNamePlateStyle() then
      -- reset to previous setting
      CVars:RestoreFromProfile("nameplateGlobalScale")
    elseif db.SmallPlatesInInstances and isInstance then
      CVars:Set("nameplateGlobalScale", 0.4)
    end

    Addon:CallbackWhenOoC(function() Addon:SetBaseNamePlateSize() end)
  elseif name == "nameplateMinScale" or name == "nameplateMaxScale" or name == "nameplateLargerScale" or name == "nameplateSelectedScale" then
    -- Update Hiding Nameplates only if something changed
    local enabled = Addon.Scaling:HidingNameplatesIsEnabled()
    local invalid = CVars.InvalidCVarsForHidingNameplates()
    if (enabled and invalid) or (not enabled and not invalid) then
      Addon.Scaling:UpdateSettings()
      --Addon:ForceUpdate()
    elseif invalid then
      ThreatPlates.Print(L["Animations for hiding nameplates are being disabled as certain console variables (CVars) related to nameplate scaling are set in a way to prevent this feature from working."], true)
    end
  elseif name == "nameplateMinAlpha" or name == "nameplateMaxAlpha" or name == "nameplateOccludedAlphaMult" or name == "nameplateSelectedAlpha" then
    local enabled = Addon.Transparency:OcclusionDetectionIsEnabled()
    local invalid = CVars.InvalidCVarsForOcclusionDetection()
    -- Update Hiding Nameplates only if something changed
    if (enabled and invalid) or (not enabled and not invalid) then
      Addon.Transparency:UpdateSettings()
    --Addon:ForceUpdate()
    elseif invalid then
      ThreatPlates.Print(L["Transparency for occluded units is being disabled as certain console variables (CVars) related to nameplate transparency are set in a way to prevent this feature from working."], true)
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
  local nameplateMinScale = tonumber(GetCVar("nameplateMinScale"))
  local nameplateMaxScale = tonumber(GetCVar("nameplateMaxScale"))
  local nameplateLargerScale = tonumber(GetCVar("nameplateLargerScale"))
  local nameplateSelectedScale = tonumber(GetCVar("nameplateSelectedScale"))

  return nameplateMinScale >= nameplateMaxScale or nameplateMinScale >= nameplateLargerScale or nameplateMinScale >= nameplateSelectedScale
end

function CVars.FixCVarsForHidingNameplates()
  CVars.SetToDefault("nameplateMinScale")
  CVars.SetToDefault("nameplateMaxScale")
  CVars.SetToDefault("nameplateLargerScale")
  CVars.SetToDefault("nameplateSelectedScale")
end

function CVars.InvalidCVarsForOcclusionDetection()
  local nameplateMinAlpha = tonumber(GetCVar("nameplateMinAlpha"))
  local nameplateMaxAlpha = tonumber(GetCVar("nameplateMaxAlpha"))
  local nameplateOccludedAlphaMult = tonumber(GetCVar("nameplateOccludedAlphaMult"))
  local nameplateSelectedAlpha = tonumber(GetCVar("nameplateSelectedAlpha"))

  return nameplateMinAlpha ~= 1 or nameplateMaxAlpha ~= 1 or nameplateOccludedAlphaMult > 0.9 or nameplateSelectedAlpha ~= 1
end

function CVars.FixCVarsForOcclusionDetection()
  _G.SetCVar("nameplateMinAlpha", 1)
  CVars.SetToDefault("nameplateMaxAlpha")          -- Default: 1.0
  CVars.SetToDefault("nameplateOccludedAlphaMult") -- Default: 0.4
  CVars.SetToDefault("nameplateSelectedAlpha")     -- Default: 1.0

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

