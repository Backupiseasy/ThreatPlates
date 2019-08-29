local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitIsPlayer = UnitIsPlayer
local UnitPlayerControlled = UnitPlayerControlled
local UnitExists = UnitExists
local UnitName = UnitName
local UNIT_LEVEL_TEMPLATE = UNIT_LEVEL_TEMPLATE
local UnitClassification = UnitClassification
local GetGuildInfo = GetGuildInfo
local UnitName = UnitName

local _G = _G
local gsub = gsub
local ceil = ceil
local format = format
local string = string

local TidyPlatesThreat = TidyPlatesThreat
local RGB = ThreatPlates.RGB
local RGB_P = ThreatPlates.RGB_P
local GetColorByHealthDeficit = ThreatPlates.GetColorByHealthDeficit

---------------------------------------------------------------------------------------------------
-- Functions for subtext from TidyPlates
---------------------------------------------------------------------------------------------------

local COLOR_ROLE = RGB(255, 255, 255, .7)
local COLOR_GUILD = RGB(178, 178, 229, .7)

local UnitSubtitles = {}
local ScannerName = "ThreatPlates_Tooltip_Subtext"
local TooltipScanner = CreateFrame( "GameTooltip", ScannerName , nil, "GameTooltipTemplate" ) -- Tooltip name cannot be nil
TooltipScanner:SetOwner( WorldFrame, "ANCHOR_NONE" )

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local Settings
local ShowHealth, ShowAbsorbs

---------------------------------------------------------------------------------------------------
-- Determine correct number units: Western or East Asian Nations (CJK)
---------------------------------------------------------------------------------------------------
local function TruncateWestern(value)
  if not TidyPlatesThreat.db.profile.text.truncate then
    return value
  end

  if value >= 1e6 then
    return format("%.1fm", value / 1e6)
  elseif value >= 1e4 then
    return format("%.1fk", value / 1e3)
  else
    return value
  end
end

local TruncateEastAsian = TruncateWestern
local Truncate = TruncateWestern

local MAP_LOCALE_TO_UNIT_SYMBOL = {
  koKR = { -- Korrean
    Unit_1K = "천",
    Unit_10K = "만",
    Unit_1B = "억",
  },
  zhCN = { -- Simplified Chinese
    Unit_1K = "千",
    Unit_10K = "万",
    Unit_1B = "亿",
  },
  zhTW = { -- Traditional Chinese
    Unit_1K = "千",
    Unit_10K = "萬",
    Unit_1B = "億",
  },
}

local locale = GetLocale()
if MAP_LOCALE_TO_UNIT_SYMBOL[locale] then
  local Format_Unit_1K = "%.1f" .. MAP_LOCALE_TO_UNIT_SYMBOL[locale].Unit_1K
  local Format_Unit_10K = "%.1f" .. MAP_LOCALE_TO_UNIT_SYMBOL[locale].Unit_10K
  local Format_Unit_1B = "%.1f" .. MAP_LOCALE_TO_UNIT_SYMBOL[locale].Unit_1B

  TruncateEastAsian = function(value)
    if not TidyPlatesThreat.db.profile.text.truncate then
      return value
    end

    if value >= 1e8 then
      return format(Format_Unit_1B, value / 1e8)
    elseif value >= 1e4 then
      return format(Format_Unit_10K, value / 1e4)
    elseif value >= 1e3 then
      return format(Format_Unit_1K, value / 1e3)
    else
      return value
    end
  end
end

local function GetUnitSubtitle(unit)
	-- Bypass caching while in an instance
	--if inInstance or (not UnitExists(unitid)) then return end
	if ( UnitIsPlayer(unit.unitid) or UnitPlayerControlled(unit.unitid) or (not UnitExists(unit.unitid))) then return end

	--local guid = UnitGUID(unit.unitid)
	local name = unit.name
	local subTitle = UnitSubtitles[name]

	if not subTitle then
		TooltipScanner:ClearLines()
		TooltipScanner:SetUnit(unit.unitid)

		local TooltipTextLeft1 = _G[ScannerName.."TextLeft1"]
		local TooltipTextLeft2 = _G[ScannerName.."TextLeft2"]
		--local TooltipTextLeft3 = _G[ScannerName.."TextLeft3"]
		--local TooltipTextLeft4 = _G[ScannerName.."TextLeft4"]

		name = TooltipTextLeft1:GetText()

		if name then name = gsub( gsub( (name), "|c........", "" ), "|r", "" ) else return end	-- Strip color escape sequences: "|c"
		if name ~= UnitName(unit.unitid) then return end	-- Avoid caching information for the wrong unit


		-- Tooltip Format Priority:  Faction, Description, Level
		local toolTipText = TooltipTextLeft2:GetText() or ""

		if string.match(toolTipText, UNIT_LEVEL_TEMPLATE) then
			subTitle = ""
		else
			subTitle = toolTipText
		end

		UnitSubtitles[name] = subTitle
	end

	-- Maintaining a cache allows us to avoid the hit
	if subTitle == "" then
		return nil
	else
		return subTitle
	end
end

local function GetLevelDescription(unit)
	local classification = UnitClassification(unit.unitid)
	local description

	if classification == "worldboss" then
		description = "World Boss"
	else
		if unit.level > 0 then
      description = "Level " .. unit.level
    else
      description = "Level ??"
    end

		if unit.isRare then
			if unit.isElite then
				description = description .. " (Rare Elite)"
			else
				description = description .. " (Rare)"
			end
		elseif unit.isElite then
			description = description .. " (Elite)"
		end
	end

	return description, RGB_P(unit.levelcolorRed, unit.levelcolorGreen, unit.levelcolorBlue, .70)
end

local function DummyFunction() return nil, COLOR_ROLE end

-- return ceil(100 * (unit.health / unit.healthmax)) .. "%", GetColorByHealthDeficit(unit)
local function TextHealthPercentColored(unit)
  local text_health, text_absorbs, color = "", "", COLOR_ROLE

  --local absorbs_amount = UnitGetTotalAbsorbs(unit.unitid) or 0
  --if ShowAbsorbs and absorbs_amount > 0 then
  --  if Settings.AbsorbsAmount then
  --    if Settings.AbsorbsShorten then
  --      text_absorbs = Truncate(absorbs_amount)
  --    else
  --      text_absorbs = absorbs_amount
  --    end
  --  end
  --
  --  if Settings.AbsorbsPercentage then
  --    local absorbs_percentage = ceil(100 * absorbs_amount / unit.healthmax) .. "%"
  --
  --    if text_absorbs == "" then
  --      text_absorbs = absorbs_percentage
  --    else
  --      text_absorbs = text_absorbs .. " - " .. absorbs_percentage
  --    end
  --  end
  --
  --  if text_absorbs ~= "" then
  --    text_absorbs = "[" .. text_absorbs .. "]"
  --  end
  --end

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

	return description, color
end

-- NPC Role
local function TextNPCRole(unit)
  local color = COLOR_ROLE
  local description

	if unit.type == "NPC" then
    description = GetUnitSubtitle(unit)
  end

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

function Addon:SetCustomText(unit)
  local style = unit.style

	local db = TidyPlatesThreat.db.profile
	if style == "NameOnly" or style == "NameOnly-Unique" then
		db = db.HeadlineView
	else
		db = db.settings.customtext
	end

	local customtext = (unit.reaction == "FRIENDLY" and db.FriendlySubtext) or db.EnemySubtext

	if customtext == "NONE" then return nil, COLOR_ROLE end

	local func = SUBTEXT_FUNCTIONS[customtext]
	local subtext, color = func(unit)

	if db.SubtextColorUseHeadline then
		return subtext, Addon:SetNameColor(unit)
	elseif db.SubtextColorUseSpecific then
		return subtext, color.r, color.g, color.b, color.a
	end

	local color = db.SubtextColor
	return subtext, color.r, color.g, color.b, color.a
end

function Addon:UpdateConfigurationStatusText()
  Settings = TidyPlatesThreat.db.profile.text

  Truncate = (Settings.LocalizedUnitSymbol and TruncateEastAsian) or TruncateWestern

  ShowAbsorbs = Settings.AbsorbsAmount or Settings.AbsorbsPercentage
  ShowHealth = Settings.amount or Settings.percent
end

