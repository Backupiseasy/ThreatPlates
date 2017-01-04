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

-- General Functions
---------------------------------------------------------------------------------------------------

t.DEBUG = function(...)
	--print ("DEBUG: ", ...)
end

t.PrintTargetInfo = function(unit)
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

t.Update = function()
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
-- Constants
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
