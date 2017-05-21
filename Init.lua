local ADDON_NAME, NAMESPACE = ...
NAMESPACE.ThreatPlates = {}
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------

local LS = LibStub
ThreatPlates.L = LS("AceLocale-3.0"):GetLocale("TidyPlatesThreat")
ThreatPlates.Media = LS("LibSharedMedia-3.0")
ThreatPlates.MediaWidgets = Media and LS("AceGUISharedMediaWidgets-1.0", false)
local L = ThreatPlates.L

--------------------------------------------------------------------------------------------------
-- General Functions
---------------------------------------------------------------------------------------------------

-- Create a percentage-based WoW color based on integer values from 0 to 255 with optional alpha value
local RGB = function(red, green, blue, alpha)
	local color = { r = red/255, g = green/255, b = blue/255 }
	if alpha then color.a = alpha end
	return color
end

local RGB_P = function(red, green, blue, alpha)
	return { r = red, g = green, b = blue, a = alpha}
end

local RGB_UNPACK = function(color)
	return color.r, color.g, color.b, color.a or 1
end

ThreatPlates.Update = function()
	-- ForceUpdate() is called in SetTheme()
	if (TidyPlatesOptions.ActiveTheme == ThreatPlates.THEME_NAME) then
		TidyPlates:SetTheme(ThreatPlates.THEME_NAME)
	end
	-- TidyPlates:ForceUpdate()
end

ThreatPlates.Meta = function(value)
	local meta
	if strlower(value) == "titleshort" then
		meta = "TP|cff89F559TP|r"
	else
		meta = GetAddOnMetadata("TidyPlates_ThreatPlates",value)
	end
	return meta or ""
end
ThreatPlates.Class = function()
	local _,class = UnitClass("Player")
	return class
end
ThreatPlates.Active = function()
	local val = GetSpecialization()
	return val
end

local function TotemNameBySpellID(number)
	local name = GetSpellInfo(number)
	if not name then
		return ""
	end
	return name
end

do
	ThreatPlates.HCC = {}
	for i=1,#CLASS_SORT_ORDER do
		local str = RAID_CLASS_COLORS[CLASS_SORT_ORDER[i]].colorStr;
		local str = gsub(str,"(ff)","",1)
		ThreatPlates.HCC[CLASS_SORT_ORDER[i]] = str;
	end
end

-- Helper Functions
ThreatPlates.STT = function(...)
	local s = {}
	local i, l
	for i = 1, select("#", ...) do
		l = select(i, ...)
		if l ~= "" then
			s[l] = true
		end
	end
	return s
end

ThreatPlates.TTS = function(s)
	local list
	for i=1,#s do
		if not list then
			list = tostring(s[i]).."\n"
		else
			local nL = s[i]
			if nL ~= "" then
				list = list..tostring(nL).."\n"
			else
				list = list..tostring(nL)
			end
		end
	end
	return list
end

ThreatPlates.CopyTable = function(input)
	local output = {}
	for k,v in pairs(input) do
		if type(v) == "table" then
			output[k] = ThreatPlates.CopyTable(v)
		else
			output[k] = v
		end
	end
	return output
end

----------------------------------------------------------------------------------------------------
-- Global constants
---------------------------------------------------------------------------------------------------

ThreatPlates.THEME_NAME = "Threat Plates"

ThreatPlates.Art = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\"
ThreatPlates.Widgets = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Widgets\\"
ThreatPlates.FullAlign = {TOPLEFT = "TOPLEFT",TOP = "TOP",TOPRIGHT = "TOPRIGHT",LEFT = "LEFT",CENTER = "CENTER",RIGHT = "RIGHT",BOTTOMLEFT = "BOTTOMLEFT",BOTTOM = "BOTTOM",BOTTOMRIGHT = "BOTTOMRIGHT"}
ThreatPlates.AlignH = {LEFT = "LEFT", CENTER = "CENTER", RIGHT = "RIGHT"}
ThreatPlates.AlignV = {BOTTOM = "BOTTOM", CENTER = "CENTER", TOP = "TOP"}
ThreatPlates.FontStyle = {
	NONE = L["None"],
	OUTLINE = L["Outline"],
	THICKOUTLINE = L["Thick Outline"],
	["NONE, MONOCHROME"] = L["No Outline, Monochrome"],
	["OUTLINE, MONOCHROME"] = L["Outline, Monochrome"],
	["THICKOUTLINE, MONOCHROME"] = L["Thick Outline, Monochrome"]
}
ThreatPlates.DebuffMode = {
	["whitelist"] = L["White List"],
	["blacklist"] = L["Black List"],
	["whitelistMine"] = L["White List (Mine)"],
	["blacklistMine"] = L["Black List (Mine)"],
	["all"] = L["All Auras"],
	["allMine"] = L["All Auras (Mine)"]
}

ThreatPlates.SPEC_ROLES = {
	DEATHKNIGHT = { true, false, false },
	DEMONHUNTER = { false, true },
	DRUID 			= { false, false, true, false },
	HUNTER			= { false, false, false },
	MAGE				= { false, false, false },
	MONK 				= { true, false, false },
	PALADIN 		= { false, true, false },
	PRIEST			= { false, false, false },
	ROGUE				= { false, false, false },
	SHAMAN			= { false, false, false },
	WARLOCK			= { false, false, false },
	WARRIOR			= { false, false, true },
}

--------------------------------------------------------------------------------------------------
-- Debug Functions
---------------------------------------------------------------------------------------------------

local function DEBUG(...)
  print ("DEBUG: ", ...)
end

-- Function from: https://coronalabs.com/blog/2014/09/02/tutorial-printing-table-contents/
local function DEBUG_PRINT_TABLE(data)
  local print_r_cache={}
  local function sub_print_r(data,indent)
    if (print_r_cache[tostring(data)]) then
      ThreatPlates.DEBUG (indent.."*"..tostring(data))
    else
      print_r_cache[tostring(data)]=true
      if (type(data)=="table") then
        for pos,val in pairs(data) do
          if (type(val)=="table") then
            ThreatPlates.DEBUG (indent.."["..pos.."] => "..tostring(data).." {")
            sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
            ThreatPlates.DEBUG (indent..string.rep(" ",string.len(pos)+6).."}")
          elseif (type(val)=="string") then
            ThreatPlates.DEBUG (indent.."["..pos..'] => "'..val..'"')
          else
            ThreatPlates.DEBUG (indent.."["..pos.."] => "..tostring(val))
          end
        end
      else
        ThreatPlates.DEBUG (indent..tostring(data))
      end
    end
  end
  if (type(data)=="table") then
    ThreatPlates.DEBUG (tostring(data).." {")
    sub_print_r(data,"  ")
    ThreatPlates.DEBUG ("}")
  else
    sub_print_r(data,"  ")
  end
end

local function DEBUG_PRINT_UNIT(unit)
	DEBUG("Unit:", unit.name)
	DEBUG("  -------------------------------------------------------------")
	DEBUG_PRINT_TABLE(unit)
	if unit.unitid then
		DEBUG("  isPet = ", UnitIsOtherPlayersPet(unit))
		DEBUG("  isControlled = ", UnitPlayerControlled(unit.unitid))
		DEBUG("  isBattlePet = ", UnitIsBattlePet(unit.unitid))
		DEBUG("  canAttack = ", UnitCanAttack("player", unit.unitid))
		DEBUG("  isFriend = ", TidyPlatesUtility.IsFriend(unit.name))
		DEBUG("  isGuildmate = ", TidyPlatesUtility.IsGuildmate(unit.name))
		DEBUG("  --------------------------------------------------------------")
	else
		DEBUG("  <no unit id>")
		DEBUG("  --------------------------------------------------------------")
	end
end

local function DEBUG_PRINT_TARGET(unit)
  if unit.isTarget then
		DEBUG_PRINT_UNIT(unit)
  end
end

local function DEBUG_AURA_LIST(data)
	local res = ""
	for pos,val in pairs(data) do
		local a = data[pos]
		if not a then
			res = res .. " nil"
		elseif not a.priority then
			res = res .. " nil(" .. a.name .. ")"
		else
			res = res .. a.name
		end
		if pos ~= #data then
			res = res .. " - "
		end
	end
	ThreatPlates.DEBUG("Aura List = [ " .. res .. " ]")
end

---------------------------------------------------------------------------------------------------
-- Expoerted local functions
---------------------------------------------------------------------------------------------------

ThreatPlates.RGB = RGB
ThreatPlates.RGB_P = RGB_P
ThreatPlates.RGB_UNPACK = RGB_UNPACK
ThreatPlates.TotemNameBySpellID = TotemNameBySpellID

-- debug functions
ThreatPlates.DEBUG = DEBUG
ThreatPlates.DEBUG_PRINT_TABLE = DEBUG_PRINT_TABLE
ThreatPlates.DEBUG_PRINT_UNIT = DEBUG_PRINT_UNIT
ThreatPlates.DEBUG_PRINT_TARGET = DEBUG_PRINT_TARGET
ThreatPlates.DEBUG_AURA_LIST = DEBUG_AURA_LIST
--ThreatPlates.DEBUG = function(...) end
--ThreatPlates.DEBUG_PRINT_TABLE = function(...) end
--ThreatPlates.DEBUG_PRINT_TARGET = function(...) end
--ThreatPlates.DEBUG_AURA_LIST = function(...) end