local ADDON_NAME, Addon = ...
local TidyPlatesThreat = TidyPlatesThreat

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local table_concat = table.concat

local SplitByWhitespace = Addon.SplitByWhitespace

---------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------

local NAME_ABBREVIATION_FUNCTION = {
  FULL = function(unit_name) return unit_name end,
  INITIALS = function(unit_name) 
    local parts, count = SplitByWhitespace(unit_name)
    local initials = {}
    for i, p in pairs(parts) do
      if i == count then
        initials[i] = p
      else
        initials[i] = string.sub(p, 0, 1)
      end
    end
    return table_concat(initials, ". ")
  end,
  LAST = function(unit_name) 
    local parts, count = SplitByWhitespace(unit_name)
    return parts[count]
  end,
}

function Addon:SetNameText(unit)
  local name = unit.name
  local style = unit.style

  -- Full names in headline view
  if style == "NameOnly" or style == "NameOnly-Unique" then
    return name
  end

  local db = TidyPlatesThreat.db.profile.settings.name
  local name_setting = (unit.reaction == "FRIENDLY" and db.AbbreviationForFriendlyUnits) or db.AbbreviationForEnemyUnits

  return NAME_ABBREVIATION_FUNCTION[name_setting](name)
end
