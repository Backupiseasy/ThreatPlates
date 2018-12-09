local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Define table that contains all addon-global variables and functions
---------------------------------------------------------------------------------------------------
Addon.ThreatPlates = {}
Addon.Debug = {}

local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

local UnitPlayerControlled = UnitPlayerControlled

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
local LibStub = LibStub

ThreatPlates.L = LibStub("AceLocale-3.0"):GetLocale("TidyPlatesThreat")
ThreatPlates.Media = LibStub("LibSharedMedia-3.0")

---------------------------------------------------------------------------------------------------
-- Define AceAddon TidyPlatesThreat
---------------------------------------------------------------------------------------------------
TidyPlatesThreat = LibStub("AceAddon-3.0"):NewAddon("TidyPlatesThreat", "AceConsole-3.0", "AceEvent-3.0")
-- Global for DBM to differentiate between Threat Plates and Tidy Plates: Threat
TidyPlatesThreatDBM = true

--------------------------------------------------------------------------------------------------
-- General Functions
---------------------------------------------------------------------------------------------------

-- Create a percentage-based WoW color based on integer values from 0 to 255 with optional alpha value
ThreatPlates.RGB = function(red, green, blue, alpha)
	local color = { r = red/255, g = green/255, b = blue/255 }
	if alpha then color.a = alpha end
	return color
end

ThreatPlates.RGB_P = function(red, green, blue, alpha)
	return { r = red, g = green, b = blue, a = alpha}
end

ThreatPlates.RGB_UNPACK = function(color)
	return color.r, color.g, color.b, color.a or 1
end

-- thanks to https://github.com/Perkovec/colorise-lua
ThreatPlates.HEX2RGB = function (hex)
  hex = hex:gsub("#","")
  return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
end

ThreatPlates.Update = function()
	Addon:ForceUpdate()
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
	local concat_result = ThreatPlates.CopyTable(base_table)

	for i = 1, #table_to_concat do
		concat_result[#concat_result + 1] = table_to_concat[i]
	end

	return concat_result
end

ThreatPlates.Dump = function(value, index)
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