---------------------------------------------------------------------------------------------------
-- Threat related functions
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

-- WoW APIs

local UnitThreatSituation, UnitGroupRolesAssigned, UnitIsUnit = UnitThreatSituation, UnitGroupRolesAssigned, UnitIsUnit

---------------------------------------------------------------------------------------------------
-- @return    Returns if the unit is tanked by another tank or pet (not by the player character,
--            not by a dps)
--
-- @docu      Function is mostly called in combat situations with the character being the tank
--            (i.e., style == "tank")
---------------------------------------------------------------------------------------------------

function Addon:UnitIsOffTanked(unit)
  local unitid = unit.unitid

  local threat_status = UnitThreatSituation("player", unitid) or 0
  if threat_status > 1 then -- tanked by player character
    return false
  end

  local target_of_unit = unitid .. "target"
  return UnitIsUnit(target_of_unit, "pet") or ("TANK" == UnitGroupRolesAssigned(target_of_unit))
end

--function Addon:UnitIsOffTanked(unit)
--  local targetOf = unit.unitid.."target"
--  local targetIsTank = UnitIsUnit(targetOf, "pet") or ("TANK" == UnitGroupRolesAssigned(targetOf))
--
--  if targetIsTank and unit.threatValue < 2 then
--    return true
--  end
--
--  return false
--end
