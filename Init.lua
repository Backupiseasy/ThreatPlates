local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local next, setmetatable, getmetatable, rawset = next, setmetatable, getmetatable, rawset
local ipairs, type, insert = ipairs, type, table.insert
local string, format = string, format

-- ThreatPlates APIs


---------------------------------------------------------------------------------------------------
-- WoW Version Check
---------------------------------------------------------------------------------------------------
Addon.IS_CLASSIC = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
Addon.IS_TBC_CLASSIC = (GetClassicExpansionLevel and GetClassicExpansionLevel() == LE_EXPANSION_BURNING_CRUSADE)
Addon.IS_WRATH_CLASSIC = (GetClassicExpansionLevel and GetClassicExpansionLevel() == LE_EXPANSION_WRATH_OF_THE_LICH_KING)
Addon.IS_MAINLINE = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
-- Addon.IS_TBC_CLASSIC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC and LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_BURNING_CRUSADE)
-- Addon.IS_WRATH_CLASSIC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC and LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_WRATH_OF_THE_LICH_KING)
Addon.WOW_USES_CLASSIC_NAMEPLATES = (Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC)

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
local LibStub = LibStub
Addon.L = LibStub("AceLocale-3.0"):GetLocale("TidyPlatesThreat")

---------------------------------------------------------------------------------------------------
-- Define AceAddon TidyPlatesThreat
---------------------------------------------------------------------------------------------------
TidyPlatesThreat = LibStub("AceAddon-3.0"):NewAddon("TidyPlatesThreat", "AceConsole-3.0", "AceEvent-3.0")
-- Global for DBM to differentiate between Threat Plates and Tidy Plates: Threat
TidyPlatesThreatDBM = true

Addon.BackdropTemplate = BackdropTemplateMixin and "BackdropTemplate"

-- Use this once SetBackdrop backwards compatibility is removed
--if BackdropTemplateMixin then -- Shadowlands
--	Addon.BackdropTemplate = "BackdropTemplate"
--
--	Addon.SetBackdrop = function(frame, backdrop)
--		frame.backdropInfo = backdrop
--		frame:ApplyBackdrop()
--	end
--else
--	Addon.SetBackdrop = function(frame, backdrop)
--		frame:SetBackdrop(backdrop)
--	end
--end

---------------------------------------------------------------------------------------------------
-- Central addon constants
---------------------------------------------------------------------------------------------------

-- Returns if the currently active spec is tank (true) or dps/heal (false)
Addon.PlayerClass = select(2, UnitClass("player"))
Addon.PlayerName = select(1, UnitName("player"))

Addon.IS_CLASSIC = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
Addon.IS_TBC_CLASSIC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
Addon.IS_MAINLINE = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

---------------------------------------------------------------------------------------------------
-- Define table that contains all addon-global variables and functions
---------------------------------------------------------------------------------------------------
Addon.ThreatPlates = {}
Addon.Debug = {}
Addon.Theme = {}

Addon.PlatesCreated = {}
Addon.PlatesByUnit = {}
Addon.PlatesByGUID = {}

local ThreatPlates = Addon.ThreatPlates

-- Modules
Addon.Font = {}
Addon.Icon = {}
Addon.Animation = {}
Addon.Threat = {}
Addon.Color = {}
Addon.Transparency = {}
Addon.Scaling = {}
Addon.Style = {}
Addon.Localization = {}
-- Internal API
Addon.Data = {}
Addon.Logging = {}
Addon.Debug = {}

---------------------------------------------------------------------------------------------------
-- Caches to the reduce CPU load of expensive functions
---------------------------------------------------------------------------------------------------

-- Cache (weak table) for memoizing expensive text functions (like abbreviation, tranliteration)
local CacheCreateEntry = function(table, key)
	local entry = {}
	rawset(table, key, entry)
	return entry
end

local CreateTextCache = function()
	local text_cache = {}
	setmetatable(text_cache, {
		__mode = "kv",
		__index = CacheCreateEntry,
	})
	return text_cache
end

Addon.Cache = {
	Texts = CreateTextCache(),
	TriggerWildcardTests = {},
	CustomPlateTriggers = {
		Name = {},
		NameWildcard = {},
		Aura = {},
		Cast = {},
		Script = {},
	},
		Styles = {
		ForAllInstances = {},
		PerInstance = {},
		ForCurrentInstance = {},
	}
}

---------------------------------------------------------------------------------------------------
-- Aura Highlighting
---------------------------------------------------------------------------------------------------
local function Wrapper_ButtonGlow_Start(frame, color, framelevel)
	Addon.LibCustomGlow.ButtonGlow_Start(frame, color, nil, framelevel)
end

local function Wrapper_PixelGlow_Start(frame, color, framelevel)
	Addon.LibCustomGlow.PixelGlow_Start(frame, color, nil, nil, nil, nil, nil, nil, nil, nil, framelevel)
end

local function Wrapper_AutoCastGlow_Start(frame, color, framelevel)
	Addon.LibCustomGlow.AutoCastGlow_Start(frame, color, nil, nil, nil, nil, nil, nil, framelevel)
end

Addon.CUSTOM_GLOW_FUNCTIONS = {
	Button = { "ButtonGlow_Start", "ButtonGlow_Stop", 8 },
	Pixel = { "PixelGlow_Start", "PixelGlow_Stop", 3 },
	AutoCast = { "AutoCastGlow_Start", "AutoCastGlow_Stop", 4 },
}

Addon.CUSTOM_GLOW_WRAPPER_FUNCTIONS = {
	ButtonGlow_Start = Wrapper_ButtonGlow_Start,
	PixelGlow_Start = Wrapper_PixelGlow_Start,
	AutoCastGlow_Start = Wrapper_AutoCastGlow_Start,
}

--------------------------------------------------------------------------------------------------
-- General Functions
---------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
-- Utils: Handling of colors
---------------------------------------------------------------------------------------------------

-- Create a percentage-based WoW color based on integer values from 0 to 255 with optional alpha value
Addon.RGB = function(red, green, blue, alpha)
  local color = { r = red/255, g = green/255, b = blue/255 }
  if alpha then color.a = alpha end
  return color
end

Addon.RGB_P = function(red, green, blue, alpha)
  return { r = red, g = green, b = blue, a = alpha}
end

Addon.RGB_WITH_HEX = function(red, green, blue, alpha)
	local color = Addon.RGB(red, green, blue, alpha)
	color.colorStr = CreateColor(color.r, color.g, color.b, color.a):GenerateHexColor()
	return color
end

-- thanks to https://github.com/Perkovec/colorise-lua
Addon.HEX2RGB = function (hex)
  hex = hex:gsub("#","")
  return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
end

Addon.ClassColorAsHex = function(class)
  local str = RAID_CLASS_COLORS[class].colorStr;
  return gsub(str, "(ff)", "", 1)
end

Addon.ColorByClass = function(class_name, text)
	if class_name then
		return "|c" .. Addon.db.profile.Colors.Classes[class_name].colorStr .. text .. "|r"
	else
		return text
	end
end

-- Addon.ColorByClassUnitID = function(unitid, text)
-- 	local _, class_name = UnitClass(unitid)
-- 	return Addon.ColorByClass(class_name, text)
-- end

--------------------------------------------------------------------------------------------------
-- Utility functions
--------------------------------------------------------------------------------------------------

Addon.Meta = function(value)
	local meta
	if strlower(value) == "titleshort" then
		meta = "|cff89F559TP|r"
	else
		meta = GetAddOnMetadata("TidyPlates_ThreatPlates",value)
	end
	return meta or ""
end

ThreatPlates.HCC = {}
for i=1,#CLASS_SORT_ORDER do
	local str = RAID_CLASS_COLORS[CLASS_SORT_ORDER[i]].colorStr;
	local str = gsub(str,"(ff)","",1)
	ThreatPlates.HCC[CLASS_SORT_ORDER[i]] = str;
end

-- Helper Functions
Addon.STT = function(...)
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

Addon.TTS = function(s)
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

Addon.Split = function(split_string)
	local result = {}
	for entry in string.gmatch(split_string, "[^;]+") do
		result[#result + 1] = entry:gsub("^%s*(.-)%s*$", "%1")
	end

	return result
end

Addon.SplitByWhitespace = function(split_string)
	local parts = {}

	for w in split_string:gmatch("%S+") do
		parts[#parts + 1] = w
	end

	return parts, #parts
end

--------------------------------------------------------------------------------------------------
-- Logging Functions
---------------------------------------------------------------------------------------------------

local function LogMessage(channel, ...)
	-- Meta("titleshort")
	if channel == "DEBUG" then
		print("|cff89F559TP|r - |cff0000ff" .. channel .. "|r:", ...)
	elseif channel == "ERROR" then
		print("|cff89F559TP|r - |cffff0000" .. channel .. "|r:", ...)
	elseif channel == "WARNING" then
		print("|cff89F559TP|r - |cffff8000" .. channel .. "|r:", ...)
	else
		print("|cff89F559TP|r:", channel, ...)
	end
end

Addon.Logging.Debug = function(...)
	if Addon.DEBUG then
		LogMessage("DEBUG", ...)
	end
end

Addon.Logging.Error = function(...)
	LogMessage("ERROR", ...)
end

Addon.Logging.Warning = function(...)
	LogMessage("WARNING", ...)
end

Addon.Logging.Info = function(...)
	if Addon.db.profile.verbose or Addon.DEBUG then
		LogMessage(...)
	end
end

Addon.Logging.Print = function(...)
	LogMessage(...)
end

--------------------------------------------------------------------------------------------------
-- Functions for working with tables
---------------------------------------------------------------------------------------------------

local function DeepCopyTable(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[DeepCopyTable(orig_key)] = DeepCopyTable(orig_value)
		end
		setmetatable(copy, DeepCopyTable(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

Addon.CopyTable = function(input)
	local output = {}
	for k,v in pairs(input) do
		if type(v) == "table" then
			output[k] = Addon.CopyTable(v)
		else
			output[k] = v
		end
	end
	return output
end

Addon.MergeIntoTable = function(target, source)
	if source == nil then return end

	for k,v in pairs(source) do
		if type(v) == "table" then
			target[k] = target[k] or {}
			Addon.MergeIntoTable(target[k], v)
		else
			target[k] = v
		end
	end
end

Addon.MergeDefaultsIntoTable = function(target, defaults)
	for k,v in pairs(defaults) do
		if type(v) == "table" then
			target[k] = target[k] or {}
			Addon.MergeDefaultsIntoTable(target[k], v)
		else
			target[k] = target[k] or v
		end
	end
end

Addon.ConcatTables = function(base_table, table_to_concat)
	local concat_result = Addon.CopyTable(base_table)

	for i = 1, #table_to_concat do
		concat_result[#concat_result + 1] = table_to_concat[i]
	end

	return concat_result
end

Addon.CheckTableStructure = function(reference_structure, table_to_check)
	if table_to_check == nil then
		return false
	end

	for k,v in pairs(reference_structure) do
		if table_to_check[k] == nil or type(table_to_check[k]) ~= type(v) then
			return false
		elseif type(v) == "table" then
			if not Addon.CheckTableStructure(v, table_to_check[k]) then
				return false
			end
		end
	end

	return true
end

--
-- Flattens a hierarchy of tables into a single array containing all
-- of the values.
--
Addon.FlattenTable = function(arr, ...)
	local result = {}

	local function LocalFlatten(arr)
		for _, v in ipairs(arr) do
			if type(v) == "table" then
				LocalFlatten(v)
			else
				insert(result, v)
			end
		end
	end

	LocalFlatten(arr)

	local arg = { ... }
	for i = 1, #arg do
		result[#result + 1] = arg[i]
	end

	return result
end

Addon.DebugPrintCaches = function()
	print ("Wildcard Unit Test Cache:")
	for k, v in pairs(Addon.Cache.TriggerWildcardTests) do
		print ("  " .. k .. ":", v)
	end
end
