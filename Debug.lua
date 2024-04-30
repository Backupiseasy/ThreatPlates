local _, Addon = ...

-- Lua APIs

-- WoW APIs

-- ThreatPlates APIs
local Debug = Addon.Debug
local Meta = Addon.Meta

--------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------

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
  if not Addon.DEBUG then return end

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

Addon.Debug.PrintUnit = function(unitid)
	local plate = C_NamePlate.GetNamePlateForUnit(unitid)
	if not plate then return end

	local tp_frame = plate.TPFrame
	local unit = tp_frame.unit
	Addon.Logging.Debug("Unit:", UnitName(unitid), "=>", unitid)
	Addon.Logging.Debug("--- IDs -------------------------------------------------------")
	Addon.Logging.Debug("      ID: =", unit.unitid)
	Addon.Logging.Debug("      NPC ID: =", unit.NPCID)
	Addon.Logging.Debug("--- Visibility-------------------------------------------------")
	Addon.Logging.Debug("     Show UnitFrame =", plate.UnitFrame:IsShown())
	Addon.Logging.Debug("     Show TPFrame =", plate.TPFrame:IsShown())
	Addon.Logging.Debug("     Active =", plate.TPFrame.Active)
	Addon.Logging.Debug("-------------------------------------------------------------")

  if unitid then
		local tp_frame = plate.TPFrame
		local unit = tp_frame and tp_frame.unit

		if not Addon.IS_CLASSIC and not Addon.IS_TBC_CLASSIC and not Addon.IS_WRATH_CLASSIC then
			Addon.Logging.Debug("  UnitNameplateShowsWidgetsOnly = ", UnitNameplateShowsWidgetsOnly(unitid))
		end

    Addon.Logging.Debug("  Reaction = ", UnitReaction("player", unitid))
    local r, g, b, a = UnitSelectionColor(unitid, true)
    Addon.Logging.Debug("  SelectionColor: r =", ceil(r * 255), ", g =", ceil(g * 255), ", b =", ceil(b * 255), ", a =", ceil(a * 255))
		Addon.Logging.Debug("  -- Threat ---------------------------------")
		Addon.Logging.Debug("    UnitAffectingCombat = ", UnitAffectingCombat(unitid))
		Addon.Logging.Debug("    UnitThreatSituation = ", UnitThreatSituation("player", unitid))
		Addon.Logging.Debug("    Target Unit = ", UnitExists(unitid .. "target"))
		if unit then
			if unit.style == "unique" then
				Addon.Logging.Debug("    GetThreatSituation(Unique) = ", Addon.GetThreatSituation(unit, unit.style, Addon.db.profile.threat.toggle.OffTank))
			else
				Addon.Logging.Debug("    GetThreatSituation = ", Addon.GetThreatSituation(unit, Addon:GetThreatStyle(unit), Addon.db.profile.threat.toggle.OffTank))
			end
		end
		Addon.Logging.Debug("  -- Player Control ---------------------------------")
		Addon.Logging.Debug("    UnitPlayerControlled =", UnitPlayerControlled(unitid))
		Addon.Logging.Debug("    Player is UnitIsOwnerOrControllerOfUnit =", UnitIsOwnerOrControllerOfUnit("player", unitid))
		Addon.Logging.Debug("    Player Pet =", UnitIsUnit(unitid, "pet"))
    Addon.Logging.Debug("    IsOtherPlayersPet =", UnitIsOtherPlayersPet(unitid))
		if not Addon.IS_CLASSIC and not Addon.IS_TBC_CLASSIC and not Addon.IS_WRATH_CLASSIC then
			Addon.Logging.Debug("    IsBattlePet =", UnitIsBattlePet(unitid))
		end
		Addon.Logging.Debug("  -- PvP ---------------------------------")
		Addon.Logging.Debug("    PvP On =", UnitIsPVP(unitid))
		Addon.Logging.Debug("    PvP Sanctuary =", UnitIsPVPSanctuary(unitid))

    --		Addon.Logging.Debug("  isFriend = ", TidyPlatesUtilityInternal.IsFriend(unit.name))
    --		Addon.Logging.Debug("  isGuildmate = ", TidyPlatesUtilityInternal.IsGuildmate(unit.name))

		if unit then
			for key, val in pairs(unit) do
				Addon.Logging.Debug(key .. ":", val)
			end	
		else
			Addon.Logging.Debug("  <No TPFrame>")
		end
  end

  Addon.Logging.Debug("--------------------------------------------------------------")
end


function Debug:PrintTarget(unit)
  if Addon.DEBUG then 
    if unit.isTarget then
      self:PrintUnit(unit)
    end
  end
end

function Debug:PrintUnitData(unit, text)
  if Addon.DEBUG then
    Addon.Logging.Debug((unit.name or "<nil>") .. ":", text)
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