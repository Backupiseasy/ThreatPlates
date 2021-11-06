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
local string, format = string, format

-- WoW APIs
local UnitPlayerControlled = UnitPlayerControlled

-- ThreatPlates APIs
Addon.IS_CLASSIC = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
Addon.IS_TBC_CLASSIC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
Addon.IS_MAINLINE = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

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

Addon.Animations = {}
Addon.Cache = {
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

Addon.LoadOnDemandLibraries = function()
	local db = Addon.db.profile

	-- Enable or disable LibDogTagSupport based on custom status text being actually used
	if db.HeadlineView.FriendlySubtext == "CUSTOM" or db.HeadlineView.EnemySubtext == "CUSTOM" or db.settings.customtext.FriendlySubtext == "CUSTOM" or db.settings.customtext.EnemySubtext == "CUSTOM" then
		if Addon.LibDogTag == nil then
			LoadAddOn("LibDogTag-3.0")
			Addon.LibDogTag = LibStub("LibDogTag-3.0", true)
			if not Addon.LibDogTag then
				Addon.LibDogTag = false
				ThreatPlates.Print(L["Custom status text requires LibDogTag-3.0 to function."], true)
			else
				LoadAddOn("LibDogTag-Unit-3.0")
			  if not LibStub("LibDogTag-Unit-3.0", true) then
					Addon.LibDogTag = false
					ThreatPlates.Print(L["Custom status text requires LibDogTag-Unit-3.0 to function."], true)
				elseif not Addon.LibDogTag.IsLegitimateUnit or not Addon.LibDogTag.IsLegitimateUnit["nameplate1"] then
					Addon.LibDogTag = false
					ThreatPlates.Print(L["Your version of LibDogTag-Unit-3.0 does not support nameplates. You need to install at least v90000.3 of LibDogTag-Unit-3.0."], true)
				end
			end
		end
	end
end

Addon.Truncate = function(value)
	local abs_value = (value > 0 and value) or (-1 * value)

	if abs_value >= 1e6 then
		return format("%.1fm", value / 1e6)
	elseif abs_value >= 1e4 then
		return format("%.1fk", value / 1e3)
	else
		return value
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

--------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------------------------
-- Some functions to fix TidyPlates bugs
---------------------------------------------------------------------------------------------------

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

-- With TidyPlates:
--local function FixUpdateUnitCondition(unit)
--	local unitid = unit.unitid
--
--	-- Enemy players turn to neutral, e.g., when mounting a flight path mount, so fix reaction in that situations
--	if unit.reaction == "NEUTRAL" and (unit.type == "PLAYER" or UnitPlayerControlled(unitid)) then
--		unit.reaction = "HOSTILE"
--	end
--end

--------------------------------------------------------------------------------------------------
-- Debug Functions
---------------------------------------------------------------------------------------------------

Addon.PrintMessage = function(channel, ...)
	--local verbose = Addon.db.profile.verbose
	if channel == "DEBUG" and Addon.DEBUG then
		print("|cff89F559TP|r - |cff0000ff" .. channel .. "|r:", ...)
	elseif channel == "ERROR" then
		print("|cff89F559TP|r - |cffff0000" .. channel .. "|r:", ...)
	elseif channel == "WARNING" then
		print("|cff89F559TP|r - |cffff8000" .. channel .. "|r:", ...)
	else
		print("|cff89F559TP|r:", channel, ...)
	end
end

Addon.PrintDebugMessage = function(...)
	Addon.PrintMessage("DEBUG", ...)
end

Addon.PrintErrorMessage = function(...)
	Addon.PrintMessage("ERROR", ...)
end

Addon.PrintWarningMessage = function(...)
	Addon.PrintMessage("WARNING", ...)
end

local function DEBUG(...)
  print (ThreatPlates.Meta("titleshort") .. "-Debug:", ...)
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
            ThreatPlates.DEBUG (indent.."["..tostring(pos).."] => "..tostring(data).." {")
            sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
            ThreatPlates.DEBUG (indent..string.rep(" ",string.len(pos)+6).."}")
          elseif (type(val)=="string") then
            ThreatPlates.DEBUG (indent.."["..tostring(pos)..'] => "'..val..'"')
          else
            ThreatPlates.DEBUG (indent.."["..tostring(pos).."] => "..tostring(val))
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

local function DEBUG_PRINT_UNIT(unit, full_info)
	DEBUG("Unit:", unit.name)
	DEBUG("-------------------------------------------------------------")
	for key, val in pairs(unit) do
		DEBUG(key .. ":", val)
  end

  if full_info and unit.unitid then
    --		DEBUG("  isFriend = ", TidyPlatesUtilityInternal.IsFriend(unit.name))
    --		DEBUG("  isGuildmate = ", TidyPlatesUtilityInternal.IsGuildmate(unit.name))
    DEBUG("  IsOtherPlayersPet = ", UnitIsOtherPlayersPet(unit))
		if not Addon.IS_TBC_CLASSIC and not Addon.IS_CLASSIC then
			DEBUG("  IsBattlePet = ", UnitIsBattlePet(unit.unitid))
		end
    DEBUG("  PlayerControlled = ", UnitPlayerControlled(unit.unitid))
    DEBUG("  CanAttack = ", UnitCanAttack("player", unit.unitid))
    DEBUG("  Reaction = ", UnitReaction("player", unit.unitid))
    local r, g, b, a = UnitSelectionColor(unit.unitid, true)
    DEBUG("  SelectionColor: r =", ceil(r * 255), ", g =", ceil(g * 255), ", b =", ceil(b * 255), ", a =", ceil(a * 255))
		DEBUG("  Threat ---------------------------------")
		DEBUG("    UnitAffectingCombat = ", UnitAffectingCombat(unit.unitid))
		DEBUG("    Addon:OnThreatTable = ", Addon:OnThreatTable(unit))
		DEBUG("    UnitThreatSituation = ", UnitThreatSituation("player", unit.unitid))
		DEBUG("    Target Unit = ", UnitExists(unit.unitid .. "target"))
		if unit.style == "unique" then
			DEBUG("    GetThreatSituation(Unique) = ", Addon.GetThreatSituation(unit, unit.style, Addon.db.profile.threat.toggle.OffTank))
		else
			DEBUG("    GetThreatSituation = ", Addon.GetThreatSituation(unit, Addon:GetThreatStyle(unit), Addon.db.profile.threat.toggle.OffTank))
		end
  else
    DEBUG("  <no unit id>")
  end

  DEBUG("--------------------------------------------------------------")
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

Addon.DebugPrintCaches = function()
	print ("Wildcard Unit Test Cache:")
	for k, v in pairs(Addon.Cache.TriggerWildcardTests) do
		print ("  " .. k .. ":", v)
	end
end

---------------------------------------------------------------------------------------------------
-- Expoerted local functions
---------------------------------------------------------------------------------------------------

-- With TidyPlates:
--ThreatPlates.FixUpdateUnitCondition = FixUpdateUnitCondition

ThreatPlates.DEBUG = DEBUG
ThreatPlates.DEBUG_PRINT_TABLE = DEBUG_PRINT_TABLE
ThreatPlates.DEBUG_PRINT_UNIT = DEBUG_PRINT_UNIT
ThreatPlates.DEBUG_PRINT_TARGET = DEBUG_PRINT_TARGET
ThreatPlates.DEBUG_AURA_LIST = DEBUG_AURA_LIST


