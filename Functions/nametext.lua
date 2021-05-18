local ADDON_NAME, Addon = ...
local TidyPlatesThreat = TidyPlatesThreat

local function split(str)
  local parts = {}
  local i = 0
  for w in string.gmatch(str, "%S+") do
    parts[i] = w
    i = i + 1
  end
  return parts, i
end

function Addon:SetNameText(unit)
  local name = unit.name
  local style = unit.style

  -- Full names for friendly units or in Headline mode
  if unit.reaction == "FRIENDLY" or style == "NameOnly" or style == "NameOnly-Unique" then
    return name
  end

  local db = TidyPlatesThreat.db.profile
  local db_mode = db.settings.name
  local name_setting = db_mode.EnemyNameAbbreviation

  local parts, count = split(name)

  if name_setting == "LAST" then
    return parts[count - 1]
  elseif name_setting == "INITIALS" then
    local initials = {}
    for i, p in pairs(parts) do
      if i == count - 1 then
        initials[i] = p
      else
        initials[i] = string.sub(p, 0, 1)
      end
    end
    return table.concat(initials, ". ", 0)
  else
    return name
  end
end
