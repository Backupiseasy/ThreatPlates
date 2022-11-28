local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local gsub = gsub
local ceil = ceil
local string = string

-- WoW APIs
local UnitIsPlayer = UnitIsPlayer
local UnitPlayerControlled = UnitPlayerControlled
local UnitExists = UnitExists
local UnitName = UnitName
local UNIT_LEVEL_TEMPLATE = UNIT_LEVEL_TEMPLATE
local GetGuildInfo = GetGuildInfo
local UnitName = UnitName
local C_TooltipInfo_GetUnit, TooltipSurfaceArgs = C_TooltipInfo and C_TooltipInfo.GetUnit, TooltipUtil and TooltipUtil.SurfaceArgs

-- ThreatPlates APIs
local RGB = ThreatPlates.RGB
local RGB_P = ThreatPlates.RGB_P
local GetColorByHealthDeficit = ThreatPlates.GetColorByHealthDeficit
local Truncate
local TransliterateCyrillicLetters = Addon.TransliterateCyrillicLetters
local L = ThreatPlates.L

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: UnitClassification, UnitGetTotalAbsorbs

---------------------------------------------------------------------------------------------------
-- Functions for subtext from TidyPlates
---------------------------------------------------------------------------------------------------

local COLOR_ROLE = RGB(255, 255, 255, .7)
local COLOR_GUILD = RGB(178, 178, 229, .7)

local UnitSubtitles = {}

if not Addon.IS_MAINLINE then
  local ScannerName = "ThreatPlates_Tooltip_Subtext"
  local TooltipScanner = CreateFrame( "GameTooltip", ScannerName , nil, "GameTooltipTemplate" ) -- Tooltip name cannot be nil
  TooltipScanner:SetOwner( WorldFrame, "ANCHOR_NONE" )

  local TooltipScannerData = {
    lines = {
      [1] = {},
      [2] = {},
    }
  }

  -- Compatibility functions for tooltips in WoW Classic
  C_TooltipInfo_GetUnit = function(unitid)
    TooltipScanner:ClearLines()
		TooltipScanner:SetUnit(unitid)

    TooltipScannerData.lines[1].leftText = _G[ScannerName.."TextLeft1"]:GetText()
    TooltipScannerData.lines[2].leftText = _G[ScannerName.."TextLeft2"]:GetText()

    return TooltipScannerData
  end

  TooltipSurfaceArgs = function() end
end

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local Settings
local ShowHealth, ShowAbsorbs

local function GetUnitSubtitle(unit)
	-- Bypass caching while in an instance
	--if inInstance or (not UnitExists(unitid)) then return end
	if ( UnitIsPlayer(unit.unitid) or UnitPlayerControlled(unit.unitid) or (not UnitExists(unit.unitid))) then return end

	--local guid = UnitGUID(unit.unitid)
	local name = unit.name
	local subtitle = UnitSubtitles[name]

	if not subtitle then
		local tooltip_data = C_TooltipInfo_GetUnit(unit.unitid)
    TooltipSurfaceArgs(tooltip_data)
    
    if #tooltip_data.lines >= 2 then 
      TooltipSurfaceArgs(tooltip_data.lines[1])
      TooltipSurfaceArgs(tooltip_data.lines[2])

      name = tooltip_data.lines[1].leftText

      if name then name = gsub( gsub( (name), "|c........", "" ), "|r", "" ) else return end	-- Strip color escape sequences: "|c"
      if name ~= UnitName(unit.unitid) then return end	-- Avoid caching information for the wrong unit

      -- Tooltip Format Priority: Faction, Description, Level
      local tooltip_subtitle = tooltip_data.lines[2].leftText or ""

      if string.match(tooltip_subtitle, UNIT_LEVEL_TEMPLATE) then
        subtitle = ""
      else
        subtitle = tooltip_subtitle
      end
      
      UnitSubtitles[name] = subtitle
    end
	end

	-- Maintaining a cache allows us to avoid the hit
	if subtitle == "" then
		return nil
	else
		return subtitle
	end
end

local function GetLevelDescription(unit)
	local classification = _G.UnitClassification(unit.unitid)
	local description

	if classification == "worldboss" then
		description = L["World Boss"]
	else
		if unit.level > 0 then
      description = L["Level "] .. unit.level
    else
      description = L["Level ??"]
    end

		if unit.isRare then
			if unit.isElite then
				description = description .. L[" (Rare Elite)"]
			else
				description = description .. L[" (Rare)"]
			end
		elseif unit.isElite then
			description = description .. L[" (Elite)"]
		end
	end

	return description, RGB_P(unit.levelcolorRed, unit.levelcolorGreen, unit.levelcolorBlue, .70)
end

local function DummyFunction() return nil, COLOR_ROLE end

-- return ceil(100 * (unit.health / unit.healthmax)) .. "%", GetColorByHealthDeficit(unit)
local function TextHealthPercentColored(unit)
  local text_health, text_absorbs, color = "", "", COLOR_ROLE

  if ShowAbsorbs then
    local absorbs_amount = _G.UnitGetTotalAbsorbs(unit.unitid) or 0
    if absorbs_amount > 0 then
      if Settings.AbsorbsAmount then
        if Settings.AbsorbsShorten then
          text_absorbs = Truncate(absorbs_amount)
        else
          text_absorbs = absorbs_amount
        end
      end

      if Settings.AbsorbsPercentage then
        local absorbs_percentage = ceil(100 * absorbs_amount / unit.healthmax) .. "%"

        if text_absorbs == "" then
          text_absorbs = absorbs_percentage
        else
          text_absorbs = text_absorbs .. " - " .. absorbs_percentage
        end
      end

      if text_absorbs ~= "" then
        text_absorbs = "[" .. text_absorbs .. "]"
      end
    end
  end

  if ShowHealth and (Settings.full or unit.health ~= unit.healthmax) then
    local HpPct, HpAmt, HpMax = "", "", ""

    if Settings.amount then
      if Settings.deficit and unit.health ~= unit.healthmax then
        HpAmt = "-" .. Truncate(unit.healthmax - unit.health)
      else
        HpAmt = Truncate(unit.health)
      end

      if Settings.max then
        if HpAmt ~= "" then
          HpMax = " / " .. Truncate(unit.healthmax)
        else
          HpMax = Truncate(unit.healthmax)
        end
      end
    end

    if Settings.percent then
      -- Blizzard calculation:
      -- local perc = math.ceil(100 * (UnitHealth(frame.displayedUnit)/UnitHealthMax(frame.displayedUnit)));

      local perc = ceil(100 * (unit.health / unit.healthmax))
      -- old: floor(100*(unit.health / unit.healthmax))

      if HpMax ~= "" or HpAmt ~= "" then
        HpPct = " - "..perc.."%"
      else
        HpPct = perc.."%"
      end
    end

    text_health = HpAmt .. HpMax .. HpPct
    color = GetColorByHealthDeficit(unit)
  end

  if text_health and text_absorbs then
    return text_health .. " " .. text_absorbs, color
  else
    return text_health .. text_absorbs, color
  end
end

-- Role, Guild or Level
local function TextRoleGuildLevel(unit)
  local color = COLOR_ROLE
  local description

	if unit.type == "NPC" then
		description = GetUnitSubtitle(unit)
	elseif unit.type == "PLAYER" then
		description = GetGuildInfo(unit.unitid)
    color = COLOR_GUILD
	end

	if not description then --  and unit.reaction ~= "FRIENDLY" then
		description, color = GetLevelDescription(unit)
		-- color = RGB_P(unit.levelcolorRed, unit.levelcolorGreen, unit.levelcolorBlue, .70)
	end

  description = TransliterateCyrillicLetters(description)

  return description, color
end

local function TextRoleGuild(unit)
	local color = COLOR_ROLE
	local description

	if unit.type == "NPC" then
		description = GetUnitSubtitle(unit)
	elseif unit.type == "PLAYER" then
		description = GetGuildInfo(unit.unitid)
    color = COLOR_GUILD
	end

  description = TransliterateCyrillicLetters(description)

	return description, color
end

-- NPC Role
local function TextNPCRole(unit)
  local color = COLOR_ROLE
  local description

	if unit.type == "NPC" then
    description = GetUnitSubtitle(unit)
  end

  description = TransliterateCyrillicLetters(description)

  return description, color
end

-- Level
local function TextLevelColored(unit)
	return GetLevelDescription(unit)
end

-- Guild, Role, Level, Health
local function TextAll(unit)
	if unit.health < unit.healthmax then
		return TextHealthPercentColored(unit)
	else
		return TextRoleGuildLevel(unit)
	end
end

local SUBTEXT_FUNCTIONS =
{
	NONE = DummyFunction,
	HEALTH = TextHealthPercentColored,
	ROLE = TextNPCRole,
	ROLE_GUILD = TextRoleGuild,
	ROLE_GUILD_LEVEL = TextRoleGuildLevel,
	LEVEL = TextLevelColored,
	ALL = TextAll,
}

---------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------

local function GetStatusTextSettings(unit)
  local style = unit.style

  local db = Addon.db.profile
  if style == "NameOnly" or style == "NameOnly-Unique" then
    db = db.HeadlineView
  else
    db = db.settings.customtext
  end

  local status_text_function = (unit.reaction == "FRIENDLY" and db.FriendlySubtext) or db.EnemySubtext

  return db, status_text_function
end

function Addon.SetCustomText(tp_frame, unit)
  -- Set Special-Case Regions
  if not tp_frame.style.customtext.show then return end

  local customtext = tp_frame.visual.customtext

  local db, status_text_function = GetStatusTextSettings(unit)
  if status_text_function == "NONE" then
    customtext:SetText("")
    customtext:SetTextColor(COLOR_ROLE.r, COLOR_ROLE.g, COLOR_ROLE.b, COLOR_ROLE.a) -- This should not be necessary ...
  elseif status_text_function ~= "CUSTOM" then
    local func = SUBTEXT_FUNCTIONS[status_text_function]
    local subtext, color = func(unit)

    if db.SubtextColorUseHeadline then
      color.r, color.g, color.b, color.a = Addon:SetNameColor(unit)
    elseif not db.SubtextColorUseSpecific then
      color = db.SubtextColor
    end

    customtext:SetText(subtext or "")
    customtext:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
  elseif not Addon.LibDogTag then -- status_text_function == "CUSTOM"
    customtext:SetText("")
  end
end

function Addon.UpdateStyleForStatusText(tp_frame, unit)
  if not Addon.LibDogTag then return end

  local db, status_text_function = GetStatusTextSettings(unit)
  if status_text_function == "CUSTOM" then
    local custom_dog_tag_text = (unit.reaction == "FRIENDLY" and db.FriendlySubtextCustom) or db.EnemySubtextCustom
    Addon.LibDogTag:AddFontString(tp_frame.visual.customtext, tp_frame, custom_dog_tag_text, "Unit", { unit = unit.unitid })
  else
    Addon.LibDogTag:RemoveFontString(tp_frame.visual.customtext)
  end
end

function Addon:UpdateConfigurationStatusText()
  Settings = self.db.profile.text

  if Settings.truncate then
    Truncate = self.Truncate
  else
    Truncate = function(value) return value end
  end

  if self.IS_CLASSIC or self.IS_TBC_CLASSIC or self.IS_WRATH_CLASSIC then
    ShowAbsorbs = false
  else
    ShowAbsorbs = Settings.AbsorbsAmount or Settings.AbsorbsPercentage
  end

  ShowHealth = Settings.amount or Settings.percent
end

