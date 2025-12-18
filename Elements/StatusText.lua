---------------------------------------------------------------------------------------------------
-- Element: Status Text
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local gsub, ceil, string = gsub, ceil, string

-- WoW APIs
local UnitIsPlayer, UnitPlayerControlled, UnitExists = UnitIsPlayer, UnitPlayerControlled, UnitExists
local UnitName = UnitName
local C_TooltipInfo_GetUnit = C_TooltipInfo and C_TooltipInfo.GetUnit
local UNIT_LEVEL_TEMPLATE = UNIT_LEVEL_TEMPLATE
local GetGuildInfo = GetGuildInfo

-- ThreatPlates APIs
local SubscribeEvent, PublishEvent,  UnsubscribeEvent = Addon.EventService.Subscribe, Addon.EventService.Publish, Addon.EventService.Unsubscribe
local RGB = Addon.RGB
local FontUpdateText = Addon.Font.UpdateText
local TransliterateCyrillicLetters = Addon.Localization.TransliterateCyrillicLetters
local L = Addon.L
local GetColorByHealthDeficit = Addon.Color.GetColorByHealthDeficit

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: UnitClassification, UnitGetTotalAbsorbs

local LineNoOfNPCRole

local COLOR_ROLE = RGB(255, 255, 255, .7)
local COLOR_GUILD = RGB(178, 178, 229, .7)

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local Truncate
local UnitSubtitles = {}

if not Addon.IS_MAINLINE then
  local ScannerName = "ThreatPlates_Tooltip_Subtext"
  local TooltipScanner = CreateFrame( "GameTooltip", ScannerName , nil, "GameTooltipTemplate" ) -- Tooltip name cannot be nil
  TooltipScanner:SetOwner( WorldFrame, "ANCHOR_NONE" )

  local TooltipScannerData = {
    lines = {
      [1] = {},
      [2] = {},
      [3] = {},      
    }
  }

  -- Compatibility functions for tooltips in WoW Classic
  C_TooltipInfo_GetUnit = function(unitid)
    TooltipScanner:ClearLines()
		TooltipScanner:SetUnit(unitid)

    TooltipScannerData.lines[1].leftText = _G[ScannerName.."TextLeft1"]:GetText()
    TooltipScannerData.lines[2].leftText = _G[ScannerName.."TextLeft2"]:GetText()
    TooltipScannerData.lines[3].leftText = _G[ScannerName .. "TextLeft3"]:GetText()

    return TooltipScannerData
  end
end

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local Settings, SettingsStatusText
local ModeSettings = {}
local ShowHealth, ShowAbsorbs
local StatusTextFunc = {
  HealthbarMode = {
    --FRIENDLY = {}, HOSTILE = {}, NEUTRAL = {}
  },
  NameMode = {
    --FRIENDLY = {}, HOSTILE = {}, NEUTRAL = {}
  }
}

---------------------------------------------------------------------------------------------------
-- Status text generating functions
---------------------------------------------------------------------------------------------------

local function GetLevelColor(unit)
  local level_color = unit.LevelColor
  level_color.a = .70
  return level_color
end

local function GetGuildColor(unit)
  return COLOR_GUILD
end

local function GetRoleColor(unit)
  return COLOR_ROLE
end

local function GetUnitSubtitle(unit)
  -- Bypass caching while in an instance
  --if inInstance or (not UnitExists(unitid)) then return end
  if UnitIsPlayer(unit.unitid) or UnitPlayerControlled(unit.unitid) or not UnitExists(unit.unitid) then return end

	--local guid = UnitGUID(unit.unitid)
	local name = unit.name
	local subtitle = UnitSubtitles[name]

	if not subtitle then
		local tooltip_data = C_TooltipInfo_GetUnit(unit.unitid)
    if tooltip_data then
      -- If colorbind mode is enabled, additional information (reputation) is shown in the tooltip
      -- before the NPC information (line 3 instead of line 2)      
      if #tooltip_data.lines >= LineNoOfNPCRole then 
        name = tooltip_data.lines[1].leftText

        if name then name = gsub( gsub( (name), "|c........", "" ), "|r", "" ) else return end	-- Strip color escape sequences: "|c"
        if name ~= UnitName(unit.unitid) then return end	-- Avoid caching information for the wrong unit

        -- Tooltip Format Priority: Faction, Description, Level
        local tooltip_subtitle = tooltip_data.lines[LineNoOfNPCRole].leftText or ""
        if string.match(tooltip_subtitle, UNIT_LEVEL_TEMPLATE) then
          subtitle = ""
        else
          subtitle = tooltip_subtitle
        end
        
        UnitSubtitles[name] = subtitle
      end
    end
	end

	-- Maintaining a cache allows us to avoid the hit
	if subtitle == "" then
		return nil
	else
		return subtitle
	end
end

-- Level
local function GetLevelDescription(unit)
  local classification = _G.UnitClassification(unit.unitid)
  local description

  if classification == "worldboss" then
    description = L["World Boss"]
  else
    if unit.level > 0 then
      description = L["Level "] .. unit.level
    else
      description =  L["Level ??"]
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

  return description, GetLevelColor
end

local TextHealthPercentColored

if Addon.ExpansionIsAtLeastMidnight then
  TextHealthPercentColored = function(unit)
    local text_health, text_absorbs, color = "", "", GetRoleColor

    if ShowAbsorbs then
      local absorbs_amount = _G.UnitGetTotalAbsorbs(unit.unitid) or 0
      
      if Settings.AbsorbsShorten then
        text_absorbs = Truncate(absorbs_amount)
      else
        text_absorbs = absorbs_amount
      end

      text_absorbs = "[" .. text_absorbs .. "]"
    end

    if ShowHealth then
      local HpPct, HpAmt, HpMax = "", "", ""

      if Settings.amount then
        --if Settings.deficit and (unit.health ~= unit.healthmax) then
        if Settings.deficit then
          HpAmt = ("-%s"):format(Truncate(UnitHealthMissing(unit.unitid)))
        else
          HpAmt = Truncate(UnitHealth(unit.unitid))
        end

        if Settings.max then
          HpMax = (" / %s"):format(Truncate(UnitHealthMax(unit.unitid)))
        end
      end

      if Settings.percent then
        HpPct = ("%.f%%"):format(UnitHealthPercent(unit.unitid, true))
        if Settings.amount then
          HpPct = (" - %s"):format(HpPct)
        end
      end

      --text_health = ("%s%s%s"):format(HpAmt, HpMax, HpPct)
      text_health = HpAmt .. HpMax .. HpPct
      color = GetColorByHealthDeficit
    end

    if text_health and text_absorbs then
      return text_health .. " " .. text_absorbs, color
    else
      return text_health .. text_absorbs, color
    end
  end
else
  TextHealthPercentColored = function(unit)
    local text_health, text_absorbs, color = "", "", GetRoleColor

    if ShowAbsorbs then
      local absorbs_amount = _G.UnitGetTotalAbsorbs(unit.unitid) or 0
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
      color = GetColorByHealthDeficit
    end

    if text_health and text_absorbs then
      return text_health .. " " .. text_absorbs, color
    else
      return text_health .. text_absorbs, color
    end
  end
end

-- Role, Guild or Level
local function TextRoleGuildLevel(unit)
  local color = GetRoleColor
  local description

  if unit.type == "NPC" then
    description = GetUnitSubtitle(unit)
  elseif unit.type == "PLAYER" then
    description = GetGuildInfo(unit.unitid)
    color = GetGuildColor
  end

  if not description then --  and unit.reaction ~= "FRIENDLY" then
    description, color = GetLevelDescription(unit)
  end

  description = TransliterateCyrillicLetters(description)

  return description, color
end

local function TextRoleGuild(unit)
  local color = GetRoleColor
  local description

  if unit.type == "NPC" then
    description = GetUnitSubtitle(unit)
  elseif unit.type == "PLAYER" then
    description = GetGuildInfo(unit.unitid)
    color = GetGuildColor
  end

  description = TransliterateCyrillicLetters(description)

  return description, color
end

-- NPC Role
local function TextNPCRole(unit)
  local description

  if unit.type == "NPC" then
    description = GetUnitSubtitle(unit)
  end

  description = TransliterateCyrillicLetters(description)

  return description, GetRoleColor
end

-- Guild, Role, Level, Health
local function TextAll(unit)
  if unit.health ~= unit.healthmax then
    return TextHealthPercentColored(unit)
  else
    return TextRoleGuildLevel(unit)
  end
end

local function TextCustom(unit)
  if not Addon.LibDogTag then
    return "", GetRoleColor
  end
end

local STATUS_TEXT_REFERENCE =
{
  -- NONE , nil for this
  HEALTH = TextHealthPercentColored,
  ROLE = TextNPCRole,
  ROLE_GUILD = TextRoleGuild,
  ROLE_GUILD_LEVEL = TextRoleGuildLevel,
  LEVEL = GetLevelDescription,
  ALL = TextAll,
  CUSTOM = TextCustom,
}

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------
local Element = Addon.Elements.NewElement("StatusText")

---------------------------------------------------------------------------------------------------
-- Core element code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_CREATED
function Element.PlateCreated(tp_frame)
  local status_text = tp_frame.visual.textframe:CreateFontString(nil, "ARTWORK")
  -- At least font must be set as otherwise it results in a Lua error when UnitAdded with SetText is called
  status_text:SetFont("Fonts\\FRIZQT__.TTF", 11)
  status_text:SetWordWrap(false) -- otherwise text is wrapped when plate is scaled down

  tp_frame.visual.StatusText = status_text
end

local function SetStatusText(tp_frame)
  local unit = tp_frame.unit
    
  local status_text_func = StatusTextFunc[tp_frame.PlateStyle][unit.reaction]

  local status_text, color
  if status_text_func then
    local subtext, color_func = status_text_func(unit)
    if subtext then
      status_text = subtext

      local db = ModeSettings[tp_frame.PlateStyle]
      if db.SubtextColorUseHeadline then
        color = tp_frame:GetNameColor()
      elseif db.SubtextColorUseSpecific then
        color = color_func(unit)
      else
        color = db.SubtextColor
      end
    end
  end

  local status_text_frame = tp_frame.visual.StatusText
  status_text_frame:SetText(status_text)
  if status_text then
    status_text_frame:SetTextColor(color.r, color.g, color.b, color.a)
  end
end

local function StyleUpdate(tp_frame, style, stylename)
  if Addon.LibDogTag then
    local unit = tp_frame.unit

    if StatusTextFunc[tp_frame.PlateStyle][unit.reaction] == TextCustom then 
      local db = ModeSettings[tp_frame.PlateStyle]
      local custom_dog_tag_text = (unit.reaction == "FRIENDLY" and db.FriendlySubtextCustom) or db.EnemySubtextCustom
      Addon.LibDogTag:AddFontString(tp_frame.visual.StatusText, tp_frame, custom_dog_tag_text, "Unit", { unit = unit.unitid })
    else
      Addon.LibDogTag:RemoveFontString(tp_frame.visual.StatusText)
    end
  end
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function Element.PlateUnitAdded(tp_frame)
  SetStatusText(tp_frame)
  StyleUpdate(tp_frame, tp_frame.style, tp_frame.stylename)
end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.PlateUnitRemoved(tp_frame)
--end

---- Called in processing event: UpdateStyle in Nameplate.lua
function Element.UpdateStyle(tp_frame, style, plate_style)
  local status_text = tp_frame.visual.StatusText

  if plate_style == "None" then
    status_text:Hide()
    return
  end

  local db = ModeSettings[tp_frame.PlateStyle]

  status_text:SetSize(db.Font.Width, db.Font.Height)
  FontUpdateText(tp_frame, status_text, db)

  status_text:Show()
end

-- Text and color may change
local function StatusTextUpdateByUnit(unitid)
  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame and tp_frame.PlateStyle ~= "None" then
    SetStatusText(tp_frame)
  end
end

local function HealthUpdate(unitid)
  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame and tp_frame.PlateStyle ~= "None" then
    local status_text_func = StatusTextFunc[tp_frame.PlateStyle][tp_frame.unit.reaction]
    if status_text_func == TextHealthPercentColored or status_text_func == TextAll then
      SetStatusText(tp_frame)
    end
  end
end

local function NameColorUpdate(tp_frame, color)
  if ModeSettings[tp_frame.PlateStyle].SubtextColorUseHeadline then
    tp_frame.visual.StatusText:SetTextColor(color.r, color.g, color.b, color.a)
  end
end

function Element.UpdateSettings()
  Settings = Addon.db.profile.text
  SettingsStatusText = Addon.db.profile.StatusText

  if Settings.truncate then
    Truncate = Addon.Truncate
  else
    Truncate = function(value) return value end
  end

  -- Absorbs: Mists - Added
  if Addon.WOW_FEATURE_ABSORBS then
    ShowAbsorbs = Settings.AbsorbsAmount or Settings.AbsorbsPercentage
  else
    ShowAbsorbs = false
  end
  ShowHealth = Settings.amount or Settings.percent

  LineNoOfNPCRole = (Addon.CVars:GetAsBool("colorblindMode") and 3) or 2

  StatusTextFunc["HealthbarMode"]["FRIENDLY"] = STATUS_TEXT_REFERENCE[SettingsStatusText.HealthbarMode.FriendlySubtext]
  StatusTextFunc["HealthbarMode"]["HOSTILE"] = STATUS_TEXT_REFERENCE[SettingsStatusText.HealthbarMode.EnemySubtext]
  StatusTextFunc["HealthbarMode"]["NEUTRAL"] = StatusTextFunc["HealthbarMode"]["HOSTILE"]

  StatusTextFunc["NameMode"]["FRIENDLY"] = STATUS_TEXT_REFERENCE[SettingsStatusText.NameMode.FriendlySubtext]
  StatusTextFunc["NameMode"]["HOSTILE"] = STATUS_TEXT_REFERENCE[SettingsStatusText.NameMode.EnemySubtext]
  StatusTextFunc["NameMode"]["NEUTRAL"] = StatusTextFunc["NameMode"]["HOSTILE"]

  ModeSettings["HealthbarMode"] = SettingsStatusText.HealthbarMode

  -- Settings for name mode are not complete, so complete them with the corresponding setttings from the healthbar mode
  ModeSettings["NameMode"] = Addon.CopyTable(SettingsStatusText.NameMode)
  ModeSettings["NameMode"].Font.Typeface = SettingsStatusText.HealthbarMode.Font.Typeface
  ModeSettings["NameMode"].Font.flags = SettingsStatusText.HealthbarMode.Font.flags
  ModeSettings["NameMode"].Font.Shadow = SettingsStatusText.HealthbarMode.Font.Shadow
  ModeSettings["NameMode"].Font.Width = SettingsStatusText.HealthbarMode.Font.Width
  ModeSettings["NameMode"].Font.Height = SettingsStatusText.HealthbarMode.Font.Height

  if SettingsStatusText.HealthbarMode.SubtextColorUseHeadline or SettingsStatusText.NameMode.SubtextColorUseHeadline then
    SubscribeEvent(Element, "NameColorUpdate", NameColorUpdate)
  else
    UnsubscribeEvent(Element, "NameColorUpdate", NameColorUpdate)
  end

  if SettingsStatusText.HealthbarMode.FriendlySubtext == "HEALTH" or SettingsStatusText.HealthbarMode.FriendlySubtext == "ALL" or
    SettingsStatusText.HealthbarMode.EnemySubtext == "HEALTH" or SettingsStatusText.HealthbarMode.EnemySubtext == "ALL" or
    SettingsStatusText.NameMode.FriendlySubtext == "HEALTH" or SettingsStatusText.NameMode.FriendlySubtext == "ALL" or
    SettingsStatusText.NameMode.EnemySubtext == "HEALTH" or SettingsStatusText.NameMode.EnemySubtext == "ALL" then

    if Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC then
      SubscribeEvent(Element, "UNIT_HEALTH_FREQUENT", HealthUpdate)
    else
      SubscribeEvent(Element, "UNIT_HEALTH", HealthUpdate)
      SubscribeEvent(Element, "UNIT_ABSORB_AMOUNT_CHANGED", HealthUpdate)
    end

    SubscribeEvent(Element, "UNIT_MAXHEALTH", HealthUpdate)
  else
    if Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC then
      UnsubscribeEvent(Element, "UNIT_HEALTH_FREQUENT", HealthUpdate)
    else
      UnsubscribeEvent(Element, "UNIT_HEALTH", HealthUpdate)
      UnsubscribeEvent(Element, "UNIT_ABSORB_AMOUNT_CHANGED", HealthUpdate)
    end

    UnsubscribeEvent(Element, "UNIT_MAXHEALTH", HealthUpdate)
  end

  -- Update TargetArt widget as it depends on some settings here
  Addon.Widgets:UpdateSettings("TargetArt")
end

--local function GuildRosterUpdate(local_change)
--  print ("GuildRosterUpdate: ", local_change)
--end

SubscribeEvent(Element, "UNIT_NAME_UPDATE", StatusTextUpdateByUnit)
SubscribeEvent(Element, "UNIT_LEVEL", StatusTextUpdateByUnit)
--SubscribeEvent(Element, "StyleUpdate", StyleUpdate)

-- For now: ignore Guild Roster events
--SubscribeEvent(Element, "GUILD_ROSTER_UPDATE", StatusTextUpdateByUnit)
