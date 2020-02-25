local ADDON_NAME, Addon = ...

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

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local next, setmetatable, getmetatable = next, setmetatable, getmetatable
local ipairs, type, insert = ipairs, type, table.insert

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
local LibStub = LibStub

ThreatPlates.L = LibStub("AceLocale-3.0"):GetLocale("TidyPlatesThreat")
ThreatPlates.Media = LibStub("LibSharedMedia-3.0")
Addon.LibCustomGlow = LibStub("LibCustomGlow-1.0")
Addon.LibAceConfigDialog = LibStub("AceConfigDialog-3.0")

---------------------------------------------------------------------------------------------------
-- Define AceAddon TidyPlatesThreat
---------------------------------------------------------------------------------------------------
TidyPlatesThreat = LibStub("AceAddon-3.0"):NewAddon("TidyPlatesThreat", "AceConsole-3.0", "AceEvent-3.0")
-- Global for DBM to differentiate between Threat Plates and Tidy Plates: Threat
TidyPlatesThreatDBM = true

Addon.Animations = {}

--------------------------------------------------------------------------------------------------
-- General Functions
---------------------------------------------------------------------------------------------------

Addon.Meta = function(value)
	local meta
	if strlower(value) == "titleshort" then
		meta = "|cff89F559TP|r"
	else
		meta = GetAddOnMetadata("TidyPlates_ThreatPlates",value)
	end
	return meta or ""
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

--------------------------------------------------------------------------------------------------
-- Functions to work with colors
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

Addon.RGB_UNPACK = function(color)
  return color.r, color.g, color.b, color.a or 1
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

Addon.CopyTable = DeepCopyTable

--Addon.CopyTable = function(input)
--	local output = {}
--	for k,v in pairs(input) do
--		if type(v) == "table" then
--			output[k] = Addon.CopyTable(v)
--		else
--			output[k] = v
--		end
--	end
--	return output
--end

Addon.MergeIntoTable = function(target, source)
  for k,v in pairs(source) do
    if type(v) == "table" then
      Addon.MergeIntoTable(target[k], v)
    else
      target[k] = v
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
