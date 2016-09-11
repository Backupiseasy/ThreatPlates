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

---------------------------------------------------------------------------------------------------
-- Global constants
---------------------------------------------------------------------------------------------------

THREAT_PLATES_NAME = "Threat Plates"
ADDON_NAME = "TidyPlatesThreat"

---------------------------------------------------------------------------------------------------
-- General Functions
---------------------------------------------------------------------------------------------------

t.DEBUG = function(...)
	print ("DEBUG: ", ...)
end

t.Update = function()
	-- TODO: check if all of it here is necessary
	if (TidyPlatesOptions.ActiveTheme == THREAD_PLATES_NAME) then
		TidyPlates:SetTheme(THREAD_PLATES_NAME)
	end
	TidyPlatesThreat.ApplyProfileSettings()

	-- reload theme is deprecated and empty, ForceUpdate() is called in SetTheme()
	--TidyPlates:ReloadTheme()
	--TidyPlates:ForceUpdate()
end
t.Meta = function(value)
	local meta
	if strlower(value) == "title" then
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
