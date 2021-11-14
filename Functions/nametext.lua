local ADDON_NAME, Addon = ...
local TidyPlatesThreat = TidyPlatesThreat

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local table_concat = table.concat
local string_len = string.len

local SplitByWhitespace = Addon.SplitByWhitespace
local TransliterateCyrillicLetters = Addon.TransliterateCyrillicLetters

---------------------------------------------------------------------------------------------------
-- Functions for name text
---------------------------------------------------------------------------------------------------

function Addon:SetNameText(unit)
  local unit_name = unit.name
  local style = unit.style

  unit_name = TransliterateCyrillicLetters(unit_name)

  -- Full names in headline view
  if style == "NameOnly" or style == "NameOnly-Unique" then
    return unit_name
  end

  local db = Addon.db.profile.settings.name  
  local name_setting = (unit.reaction == "FRIENDLY" and db.AbbreviationForFriendlyUnits) or db.AbbreviationForEnemyUnits

  if name_setting == "FULL" then
    return unit_name
  elseif name_setting == "INITIALS" then
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
  else -- LAST
    local parts, count = SplitByWhitespace(unit_name)
    return parts[count]
  end
end
