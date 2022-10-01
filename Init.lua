local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Define table that contains all addon-global variables and functions
---------------------------------------------------------------------------------------------------
Addon.ThreatPlates = {}
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local string, floor = string, floor
local rawset = rawset

-- WoW APIs
local UnitClass = UnitClass

-- ThreatPlates APIs
local UnitDetailedThreatSituation = UnitDetailedThreatSituation

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
ThreatPlates.L = LibStub("AceLocale-3.0"):GetLocale("TidyPlatesThreat")

Addon.BackdropTemplate = BackdropTemplateMixin and "BackdropTemplate"

local L = ThreatPlates.L

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
-- Define AceAddon TidyPlatesThreat
---------------------------------------------------------------------------------------------------
TidyPlatesThreat = LibStub("AceAddon-3.0"):NewAddon("TidyPlatesThreat", "AceConsole-3.0", "AceEvent-3.0")
-- Global for DBM to differentiate between Threat Plates and Tidy Plates: Threat
TidyPlatesThreatDBM = true

-- Returns if the currently active spec is tank (true) or dps/heal (false)
Addon.PlayerClass = select(2, UnitClass("player"))
Addon.PlayerName = select(1, UnitName("player"))

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

---------------------------------------------------------------------------------------------------
-- Caches to the reduce CPU load of expensive functions
---------------------------------------------------------------------------------------------------

Addon.Animations = {}
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
-- Internal API
Addon.Data = {}
Addon.Logging = {}
Addon.Debug = {}

---------------------------------------------------------------------------------------------------
-- Addon-wide wrapper functions for WoW Classic
---------------------------------------------------------------------------------------------------

if Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC then
  Addon.UnitDetailedThreatSituationWrapper = function(source, target)
    local is_tanking, status, threatpct, rawthreatpct, threat_value = UnitDetailedThreatSituation(source, target)

    if (threat_value) then
      threat_value = floor(threat_value / 100)
    end

    return is_tanking, status, threatpct, rawthreatpct, threat_value
  end
else
	Addon.UnitDetailedThreatSituationWrapper = UnitDetailedThreatSituation
end

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

Addon.LoadOnDemandLibraries = function()
	local db = Addon.db.profile

	-- Enable or disable LibDogTagSupport based on custom status text being actually used
	if db.HeadlineView.FriendlySubtext == "CUSTOM" or db.HeadlineView.EnemySubtext == "CUSTOM" or db.settings.customtext.FriendlySubtext == "CUSTOM" or db.settings.customtext.EnemySubtext == "CUSTOM" then
		if Addon.LibDogTag == nil then
			LoadAddOn("LibDogTag-3.0")
			Addon.LibDogTag = LibStub("LibDogTag-3.0", true)
			if not Addon.LibDogTag then
				Addon.LibDogTag = false
				Addon.Logging.Error(L["Custom status text requires LibDogTag-3.0 to function."])
			else
				LoadAddOn("LibDogTag-Unit-3.0")
			  if not LibStub("LibDogTag-Unit-3.0", true) then
					Addon.LibDogTag = false
					Addon.Logging.Error(L["Custom status text requires LibDogTag-Unit-3.0 to function."])
				elseif not Addon.LibDogTag.IsLegitimateUnit or not Addon.LibDogTag.IsLegitimateUnit["nameplate1"] then
					Addon.LibDogTag = false
					Addon.Logging.Error(L["Your version of LibDogTag-Unit-3.0 does not support nameplates. You need to install at least v90000.3 of LibDogTag-Unit-3.0."])
				end
			end
		end
	end
end

--------------------------------------------------------------------------------------------------
-- Utils: Handling of colors
---------------------------------------------------------------------------------------------------

-- Create a percentage-based WoW color based on integer values from 0 to 255 with optional alpha value
ThreatPlates.RGB = function(red, green, blue, alpha)
	local color = { r = red/255, g = green/255, b = blue/255 }
	if alpha then color.a = alpha end
	return color
end

ThreatPlates.RGB_WITH_HEX = function(red, green, blue, alpha)
	local color = ThreatPlates.RGB(red, green, blue, alpha)
	color.colorStr = CreateColor(color.r, color.g, color.b, color.a):GenerateHexColor()
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
---------------------------------------------------------------------------------------------------

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
	local concat_result = ThreatPlates.CopyTable(base_table)

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
-- Debug functions
---------------------------------------------------------------------------------------------------

-- Function from: https://coronalabs.com/blog/2014/09/02/tutorial-printing-table-contents/
Addon.Debug.PrintTable = function(data)
  local print_r_cache={}
  local function sub_print_r(data,indent)
    if (print_r_cache[tostring(data)]) then
			Addon.Logging.Debug(indent.."*"..tostring(data))
    else
      print_r_cache[tostring(data)]=true
      if (type(data)=="table") then
        for pos,val in pairs(data) do
          if (type(val)=="table") then
						Addon.Logging.Debug(indent.."["..tostring(pos).."] => "..tostring(data).." {")
            sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
						Addon.Logging.Debug(indent..string.rep(" ",string.len(pos)+6).."}")
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
	Addon.Logging.Debug("Unit:", unit.name, "=>", unitid)
	Addon.Logging.Debug("-------------------------------------------------------------")
	Addon.Logging.Debug("  Show UnitFrame =", plate.UnitFrame:IsShown())
	Addon.Logging.Debug("  Show TPFrame =", plate.TPFrame:IsShown())
	Addon.Logging.Debug("  Active =", plate.TPFrame.Active)
	Addon.Logging.Debug("-------------------------------------------------------------")
  if tp_frame and unit and unit.unitid then
		if not Addon.IS_CLASSIC and not Addon.IS_TBC_CLASSIC and not Addon.IS_WRATH_CLASSIC then
			Addon.Logging.Debug("  UnitNameplateShowsWidgetsOnly = ", UnitNameplateShowsWidgetsOnly(unit.unitid))
		end
    Addon.Logging.Debug("  Reaction = ", UnitReaction("player", unit.unitid))
    local r, g, b, a = UnitSelectionColor(unit.unitid, true)
    Addon.Logging.Debug("  SelectionColor: r =", ceil(r * 255), ", g =", ceil(g * 255), ", b =", ceil(b * 255), ", a =", ceil(a * 255))
		Addon.Logging.Debug("  -- Threat ---------------------------------")
		Addon.Logging.Debug("    UnitAffectingCombat = ", UnitAffectingCombat(unit.unitid))
		Addon.Logging.Debug("    Addon:OnThreatTable = ", Addon:OnThreatTable(unit))
		Addon.Logging.Debug("    UnitThreatSituation = ", UnitThreatSituation("player", unit.unitid))
		Addon.Logging.Debug("    Target Unit = ", UnitExists(unit.unitid .. "target"))
		if unit.style == "unique" then
			Addon.Logging.Debug("    GetThreatSituation(Unique) = ", Addon.GetThreatSituation(unit, unit.style, Addon.db.profile.threat.toggle.OffTank))
		else
			Addon.Logging.Debug("    GetThreatSituation = ", Addon.GetThreatSituation(unit, Addon:GetThreatStyle(unit), Addon.db.profile.threat.toggle.OffTank))
		end
		Addon.Logging.Debug("  -- Player Control ---------------------------------")
		Addon.Logging.Debug("    UnitPlayerControlled =", UnitPlayerControlled(unit.unitid))
		Addon.Logging.Debug("    Player is UnitIsOwnerOrControllerOfUnit =", UnitIsOwnerOrControllerOfUnit("player", unit.unitid))
		Addon.Logging.Debug("    Player Pet =", UnitIsUnit(unit.unitid, "pet"))
    Addon.Logging.Debug("    IsOtherPlayersPet =", UnitIsOtherPlayersPet(unit.unitid))
		if not Addon.IS_CLASSIC and not Addon.IS_TBC_CLASSIC and not Addon.IS_WRATH_CLASSIC then
			Addon.Logging.Debug("    IsBattlePet =", UnitIsBattlePet(unit.unitid))
		end
		Addon.Logging.Debug("  -- PvP ---------------------------------")
		Addon.Logging.Debug("    PvP On =", UnitIsPVP(unit.unitid))
		Addon.Logging.Debug("    PvP Sanctuary =", UnitIsPVPSanctuary(unit.unitid))

    --		Addon.Logging.Debug("  isFriend = ", TidyPlatesUtilityInternal.IsFriend(unit.name))
    --		Addon.Logging.Debug("  isGuildmate = ", TidyPlatesUtilityInternal.IsGuildmate(unit.name))

		for key, val in pairs(unit) do
			Addon.Logging.Debug(key .. ":", val)
		end	
	else
    Addon.Logging.Debug("  <No TPFrame>")
  end

  Addon.Logging.Debug("--------------------------------------------------------------")
end


--local function DEBUG_PRINT_TARGET(unit)
--  if unit.isTarget then
--		DEBUG_PRINT_UNIT(unit)
--  end
--end
--
--local function DEBUG_AURA_LIST(data)
--	local res = ""
--	for pos,val in pairs(data) do
--		local a = data[pos]
--		if not a then
--			res = res .. " nil"
--		elseif not a.priority then
--			res = res .. " nil(" .. a.name .. ")"
--		else
--			res = res .. a.name
--		end
--		if pos ~= #data then
--			res = res .. " - "
--		end
--	end
--	ThreatPlates.DEBUG("Aura List = [ " .. res .. " ]")
--end

Addon.Debug.PrintCaches = function()
	print ("Wildcard Unit Test Cache:")
	for k, v in pairs(Addon.Cache.TriggerWildcardTests) do
		print ("  " .. k .. ":", v)
	end
end
