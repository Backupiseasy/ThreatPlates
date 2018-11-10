local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Functions for changing and savely restoring CVars (mostly after login/logout/reload UI)
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs, tonumber = pairs, tonumber

-- WoW APIs
local SetCVar, GetCVar, GetCVarDefault = SetCVar, GetCVar, GetCVarDefault

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local L = ThreatPlates.L

Addon.CVars = {}

local CVars = Addon.CVars

--local COMBAT_PROTECTED = {
--  nameplateMinAlpha = true,
--  nameplateMaxAlpha = true,
--  nameplateSelectedAlpha = true,
--  nameplateOccludedAlphaMult = true,
--}

local function SetConsoleVariable(cvar, value)
  -- Store in settings to be able to restore it later, but don't overwrite an existing value unless the current value
  -- is different from the backup value and the new value TP wants to set. In that case, the CVars was changed since
  -- last login with TP by the player or another addon.
  local db = TidyPlatesThreat.db.profile.CVarsBackup

  local backup_value = db[cvar]
  local current_value = GetCVar(cvar)
  if (value ~= current_value) and (current_value ~= backup_value) then
    db[cvar] = current_value
  end

  SetCVar(cvar, value)
end

--function CVars:Set(cvar, value)
--
--  if COMBAT_PROTECTED[cvar] then
--    Addon:CallbackWhenOoC(function() SetConsoleVariable(cvar, value) end, L["Unable to change the following console variable while in combat: "] .. cvar .. ". ")
--  else
--    SetConsoleVariable(cvar, value)
--  end
--end

function CVars:Set(cvar, value)
  SetConsoleVariable(cvar, value)
end

function CVars:SetToDefault(cvar)
  SetCVar(cvar, GetCVarDefault())
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
