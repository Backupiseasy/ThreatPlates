local ADDON_NAME, Addon = ...
local TidyPlatesThreat = TidyPlatesThreat

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local table_concat = table.concat
local string_len  = string.len

-- ThreatPlates APIs
local SplitByWhitespace = Addon.SplitByWhitespace
local TransliterateCyrillicLetters = Addon.TransliterateCyrillicLetters
local TextCache = Addon.Cache.Texts

---------------------------------------------------------------------------------------------------
-- Functions for name text
---------------------------------------------------------------------------------------------------

function Addon:SetNameText(unit)
  local unit_name = TransliterateCyrillicLetters(unit.name)
 
  -- Full names in headline view
  local style = unit.style
  if unit.type == "PLAYER" or style == "NameOnly" or style == "NameOnly-Unique" then
    return unit_name
  end

  local db = Addon.db.profile.settings.name  
  local name_setting = (unit.reaction == "FRIENDLY" and db.AbbreviationForFriendlyUnits) or db.AbbreviationForEnemyUnits

  if name_setting == "FULL" then
    return unit_name
  else
    -- Use unit name here to not use the transliterated text
    local cache_entry = TextCache[unit.name]

    local abbreviated_name = cache_entry.Abbreviation
    if not abbreviated_name then
      local parts, count = SplitByWhitespace(unit_name)
      if name_setting == "INITIALS" then
        local initials = {}
        for i, p in pairs(parts) do
          if i == count then
            initials[i] = p
          else
            initials[i] = string.sub(p, 0, 1)
          end
        end
        abbreviated_name = table_concat(initials, ". ")
      else -- LAST
        abbreviated_name = parts[count]
      end

      cache_entry.Abbreviation = abbreviated_name
    end

    return abbreviated_name
  end
end
