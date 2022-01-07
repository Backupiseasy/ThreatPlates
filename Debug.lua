local _, Addon = ...

-- Lua APIs

-- WoW APIs

-- ThreatPlates APIs
local Debug = Addon.Debug
local ThreatPlates = Addon.ThreatPlates
local Meta = Addon.Meta

--------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------

Debug.Enabled = true

--------------------------------------------------------------------------------------------------
-- Debug tools
---------------------------------------------------------------------------------------------------

Debug.Dump = function(value, index)
  if not IsAddOnLoaded("Blizzard_DebugTools") then
    LoadAddOn("Blizzard_DebugTools")
  end
  local i
  if index and type(index) == "number" then
    i = index
  else
    i = 1
  end
  DevTools_Dump(value, i)
end

--------------------------------------------------------------------------------------------------
-- Debug Functions
---------------------------------------------------------------------------------------------------

local function Print(...)
  print (Meta("titleshort") .. "-Debug:", ...)
end

-- Function from: https://coronalabs.com/blog/2014/09/02/tutorial-printing-table-contents/
function Debug:PrintTable(data)
  if not self.Enabled then return end

  local print_r_cache = {}

  local function sub_print_r(data,indent)
    if (print_r_cache[tostring(data)]) then
      Addon.Logging.Debug(indent.."*"..tostring(data))
    else
      print_r_cache[tostring(data)]=true
      if (type(data)=="table") then
        for pos,val in pairs(data) do
          if (type(val)=="table") then
            Addon.Logging.Debug(indent.."["..tostring(pos).."] => "..tostring(data).." {")
            sub_print_r(val,indent..string.rep(" ",string.len(tostring(pos))+8))
            Addon.Logging.Debug(indent..string.rep(" ",string.len(tostring(pos))+6).."}")
          elseif (type(val)=="string") then
            Addon.Logging.Debug(indent.."["..tostring(pos)..'] => "'..val..'"')
          else
            Addon.Logging.Debug(indent.."["..tostring(pos).."] => "..tostring(val))
          end
        end
      else
        Addon.Logging.Debug(indent..tostring(data))
      end
    end
  end

  if (type(data)=="table") then
    Addon.Logging.Debug(tostring(data).." {")
    sub_print_r(data,"  ")
    Addon.Logging.Debug("}")
  else
    sub_print_r(data,"  ")
  end
end

function Debug:PrintUnit(unit, full_info)
  if not self.Enabled then return end

  Addon.Logging.Debug("Unit:", unit.name)
  Addon.Logging.Debug("-------------------------------------------------------------")
  for key, val in pairs(unit) do
    Addon.Logging.Debug(key .. ":", val)
  end

  if full_info and unit.unitid then
    --		DEBUG("  isFriend = ", Addon:IsFriend(unit.name))
    --		DEBUG("  isGuildmate = ", Addon:IsGuildmate(unit.name))
    Addon.Logging.Debug("  IsOtherPlayersPet = ", UnitIsOtherPlayersPet(unit))
    Addon.Logging.Debug("  IsBattlePet = ", UnitIsBattlePet(unit.unitid))
    Addon.Logging.Debug("  PlayerControlled = ", UnitPlayerControlled(unit.unitid))
    Addon.Logging.Debug("  CanAttack = ", UnitCanAttack("player", unit.unitid))
    Addon.Logging.Debug("  Reaction = ", UnitReaction("player", unit.unitid))
    local r, g, b, a = UnitSelectionColor(unit.unitid, true)
    Addon.Logging.Debug("  SelectionColor: r =", ceil(r * 255), ", g =", ceil(g * 255), ", b =", ceil(b * 255), ", a =", ceil(a * 255))
  else
    Addon.Logging.Debug("  <no unit id>")
  end

  Addon.Logging.Debug("--------------------------------------------------------------")
end


function Debug:PrintTarget(unit)
  if not self.Enabled then return end

  if unit.isTarget then
    self:PrintUnit(unit)
  end
end

function Debug:ColorToString(color, ...)
  local r, b, g, a
  if not color then
    return "(nil)"
  elseif type(color) == "table" then
    r, b, g, a = color.r, color.g, color.b, color.a
  else
    r, b, g, a = color, ...
  end



  if a then
    r, b, g, a = ceil(r * 255), ceil(g * 255), ceil(b * 255), ceil(a * 255)
    return string.format("%i / %i / %i / %i", r, g, b, a)
  else
    r, b, g = ceil(r * 255), ceil(g * 255), ceil(b * 255)
    return string.format("%i / %i / %i", r, g, b)
  end
end

function Debug:TableSize(table)
  local size = 0

  if type(table) == "table" then
    for key, _ in pairs(table) do
      size = size + 1
    end
  end

  return size
end

Addon.Debug.PrintCaches = function()
	print ("Wildcard Unit Test Cache:")
	for k, v in pairs(Addon.Cache.TriggerWildcardTests) do
		print ("  " .. k .. ":", v)
	end
end