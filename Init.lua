local ADDON_NAME, NAMESPACE = ...

NAMESPACE.ThreatPlates = {}
local t = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------

local LS = LibStub
t.L = LS("AceLocale-3.0"):GetLocale("TidyPlatesThreat")
t.Media = LS("LibSharedMedia-3.0")
t.MediaWidgets = Media and LS("AceGUISharedMediaWidgets-1.0", false)
local L = t.L

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

t.Update = function()
	-- ForceUpdate() is called in SetTheme()
	if (TidyPlatesOptions.ActiveTheme == t.THEME_NAME) then
		TidyPlates:SetTheme(t.THEME_NAME)
	end
	-- TidyPlates:ForceUpdate()
end

t.Meta = function(value)
	local meta
	if strlower(value) == "titleshort" then
		meta = "TP|cff89F559TP|r"
	else
		meta = GetAddOnMetadata("TidyPlates_ThreatPlates",value)
	end
	return meta or ""
end
t.Class = function()
	local _,class = UnitClass("Player")
	return class
end
t.Active = function()
	local val = GetSpecialization()
	return val
end

do
	t.HCC = {}
	for i=1,#CLASS_SORT_ORDER do
		local str = RAID_CLASS_COLORS[CLASS_SORT_ORDER[i]].colorStr;
		local str = gsub(str,"(ff)","",1)
		t.HCC[CLASS_SORT_ORDER[i]] = str;
	end
end
-- Helper Functions
t.STT = function(...)
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
t.TTS = function(s)
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

t.CopyTable = function(input)
	local output = {}
	for k,v in pairs(input) do
		if type(v) == "table" then
			output[k] = t.CopyTable(v)
		else
			output[k] = v
		end
	end
	return output
end

----------------------------------------------------------------------------------------------------
-- Global constants
---------------------------------------------------------------------------------------------------

t.THEME_NAME = "Threat Plates"

t.Art = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\"
t.Widgets = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Widgets\\"
t.FullAlign = {TOPLEFT = "TOPLEFT",TOP = "TOP",TOPRIGHT = "TOPRIGHT",LEFT = "LEFT",CENTER = "CENTER",RIGHT = "RIGHT",BOTTOMLEFT = "BOTTOMLEFT",BOTTOM = "BOTTOM",BOTTOMRIGHT = "BOTTOMRIGHT"}
t.AlignH = {LEFT = "LEFT", CENTER = "CENTER", RIGHT = "RIGHT"}
t.AlignV = {BOTTOM = "BOTTOM", CENTER = "CENTER", TOP = "TOP"}
t.FontStyle = {
	NONE = L["None"],
	OUTLINE = L["Outline"],
	THICKOUTLINE = L["Thick Outline"],
	["NONE, MONOCHROME"] = L["No Outline, Monochrome"],
	["OUTLINE, MONOCHROME"] = L["Outline, Monochrome"],
	["THICKOUTLINE, MONOCHROME"] = L["Thick Outline, Monochrome"]
}
t.DebuffMode = {
	["whitelist"] = L["White List"],
	["blacklist"] = L["Black List"],
	["whitelistMine"] = L["White List (Mine)"],
	["blacklistMine"] = L["Black List (Mine)"],
	["all"] = L["All Auras"],
	["allMine"] = L["All Auras (Mine)"]
}

t.SPEC_ROLES = {
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

t.DEBUG = function(...)
  --print ("DEBUG: ", ...)
end

t.DEBUG_SIZE = function(msg, data)
  if type(data) == "table" then
    local no = 0
    for k, v in pairs(data) do no = no + 1 end
    t.DEBUG(msg, no)
  else
    t.DEBUG(msg, "<no table>")
  end
end

-- Function from: https://coronalabs.com/blog/2014/09/02/tutorial-printing-table-contents/
t.DEBUG_PRINT_TABLE = function(data)
  local print_r_cache={}
  local function sub_print_r(data,indent)
    if (print_r_cache[tostring(data)]) then
      t.DEBUG (indent.."*"..tostring(data))
    else
      print_r_cache[tostring(data)]=true
      if (type(data)=="table") then
        for pos,val in pairs(data) do
          if (type(val)=="table") then
            t.DEBUG (indent.."["..pos.."] => "..tostring(data).." {")
            sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
            t.DEBUG (indent..string.rep(" ",string.len(pos)+6).."}")
          elseif (type(val)=="string") then
            t.DEBUG (indent.."["..pos..'] => "'..val..'"')
          else
            t.DEBUG (indent.."["..pos.."] => "..tostring(val))
          end
        end
      else
        t.DEBUG (indent..tostring(data))
      end
    end
  end
  if (type(data)=="table") then
    t.DEBUG (tostring(data).." {")
    sub_print_r(data,"  ")
    t.DEBUG ("}")
  else
    sub_print_r(data,"  ")
  end
end

t.DEBUG_AURA_LIST = function(data)
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
	t.DEBUG("Aura List = [ " .. res .. " ]")
end
	
t.DEBUG_PRINT_TARGET = function(unit)
  if unit.isTarget then
    t.DEBUG("unit.name = ", unit.name)
    t.DEBUG("unit.unitID = ", unit.unitID)
    t.DEBUG("unit.type = ", unit.type)
    t.DEBUG("unit.class = ", unit.class)
    t.DEBUG("unit.reaction = ", unit.reaction)
    t.DEBUG("unit.isMini = ", unit.isMini)
    t.DEBUG("unit.isTapped = ", unit.isTapped)
    t.DEBUG("unit.isElite = ", unit.isBoss)
    t.DEBUG("unit.isBoss = ", unit.isElite)
    t.DEBUG("unit SetStyle = ", style)
    t.DEBUG("unit GetType = ", TidyPlatesThreat.GetType(unit))
    t.DEBUG("unit.isPet = ", UnitIsOtherPlayersPet(unit))
    t.DEBUG("unit.isControlled = ", UnitPlayerControlled(unit.unitid))
    t.DEBUG("unit.isBattlePet = ", UnitIsBattlePet(unit.unitid))
    t.DEBUG("unit.canAttack = ", UnitCanAttack("player", unit.unitid))

    t.DEBUG("unit.isFriend = ", TidyPlatesUtility.IsFriend(unit.name))
    t.DEBUG("unit.isGuildmate = ", TidyPlatesUtility.IsGuildmate(unit.name))

    -- local enemy_totems = GetCVar("nameplateShowEnemyTotems")
    -- local enemy_guardians = GetCVar("nameplateShowEnemyGuardians")
    -- local enemy_pets = GetCVar("nameplateShowEnemyPets")
    -- local enemy_minus = GetCVar("nameplateShowEnemyMinus")
    -- print ("CVars Enemy: totems = ", enemy_totems, " / guardians = ", enemy_guardians, " / pets = ", enemy_pets, " / minus = ", enemy_minus)
    --
    -- local friendly_totems = GetCVar("nameplateShowFriendlyTotems")
    -- local friendly_guardians = GetCVar("nameplateShowFriendlyGuardians")
    -- local friendly_pets = GetCVar("nameplateShowFriendlyPets")
    -- print ("CVars Friendly: totems = ", friendly_totems, " / guardians = ", friendly_guardians, " / pets = ", friendly_pets)
  end
end

---------------------------------------------------------------------------------------------------
-- Expoerted local functions
---------------------------------------------------------------------------------------------------

t.RGB = RGB
t.RGB_P = RGB_P
t.RGB_UNPACK = RGB_UNPACK