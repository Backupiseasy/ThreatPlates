local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Functions for changing and savely restoring CVars (mostly after login/logout/reload UI)
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs, tonumber, tostring = pairs, tonumber, tostring

-- WoW APIs
local SetCVar, GetCVar, GetCVarDefault = SetCVar, GetCVar, GetCVarDefault

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local L = ThreatPlates.L

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

  SetCVar(cvar, value)
end

function CVars:Set(cvar, value)
  SetConsoleVariable(cvar, value)
end

function CVars:SetToDefault(cvar)
  SetCVar(cvar, GetCVarDefault(cvar))
  TidyPlatesThreat.db.profile.CVarsBackup[cvar] = nil
end

function CVars:RestoreFromProfile(cvar)
  local db = TidyPlatesThreat.db.profile.CVarsBackup

  if db[cvar] then
    SetCVar(cvar, db[cvar])
    db[cvar] = nil
  end
end

--function CVars:RestoreAllFromProfile()
--  local db = TidyPlatesThreat.db.profile.CVarsBackup
--
--  for cvar, value in pairs(db) do
--    SetCVar(cvar, value)
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
      SetCVar(cvar, GetCVarDefault())
      TidyPlatesThreat.db.profile.CVarsBackup[cvar] = nil
    end, L["Unable to change the following console variable while in combat: "] .. cvar .. ". ")
  else
    SetCVar(cvar, GetCVarDefault())
    TidyPlatesThreat.db.profile.CVarsBackup[cvar] = nil
  end
end

function CVars:OverwriteProtected(cvar, value)
  if COMBAT_PROTECTED[cvar] then
    Addon:CallbackWhenOoC(function()
      SetCVar(cvar, value)
    end, L["Unable to change the following console variable while in combat: "] .. cvar .. ". ")
  else
    SetCVar(cvar, value)
  end
end

function CVars:OverwriteBoolProtected(cvar, value)
  self:OverwriteProtected(cvar, (value and 1) or 0)
end