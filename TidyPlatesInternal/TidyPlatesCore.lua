local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------------------------
-- Variables and References
---------------------------------------------------------------------------------------------------------------------
local TidyPlatesCore = CreateFrame("Frame", nil, WorldFrame)

-- Local References
local _
local max, gsub, tonumber = math.max, string.gsub, tonumber
local select, pairs, tostring = select, pairs, tostring 			    -- Local function copy

-- WoW APIs
local wipe, strsplit = wipe, strsplit
local WorldFrame, UIParent, INTERRUPTED = WorldFrame, UIParent, INTERRUPTED
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local UnitName, UnitIsUnit, UnitReaction, UnitExists = UnitName, UnitIsUnit, UnitReaction, UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local UnitEffectiveLevel = UnitEffectiveLevel
local GetCreatureDifficultyColor = GetCreatureDifficultyColor
local UnitThreatSituation = UnitThreatSituation
local GetRaidTargetIndex = GetRaidTargetIndex
local GetTime = GetTime
local UnitChannelInfo  = UnitChannelInfo
local UnitPlayerControlled = UnitPlayerControlled
local GetCVarBool, CombatLogGetCurrentEventInfo = C_CVar.GetCVarBool, CombatLogGetCurrentEventInfo
local GetPlayerInfoByGUID, RAID_CLASS_COLORS = GetPlayerInfoByGUID, RAID_CLASS_COLORS
local UnitNameplateShowsWidgetsOnly = UnitNameplateShowsWidgetsOnly

-- ThreatPlates APIs
local Widgets = Addon.Widgets
local Animations = Addon.Animations
local CVars = Addon.CVars
local BackdropTemplate = Addon.BackdropTemplate
local TransliterateCyrillicLetters = Addon.TransliterateCyrillicLetters

local GetNameForNameplate
local UnitCastingInfo

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, UnitAffectingCombat, UnitCastingInfo, UnitClassification, UnitGUID, UnitHealth, UnitHealthMax, UnitIsTapDenied, UnitLevel, UnitSelectionColor

---------------------------------------------------------------------------------------------------
-- Wrapper functions for WoW Classic
---------------------------------------------------------------------------------------------------

if Addon.IS_CLASSIC then
  GetNameForNameplate = function(plate) return plate:GetName():gsub("NamePlate", "Plate") end
  UnitEffectiveLevel = function(...) return _G.UnitLevel(...) end

  UnitChannelInfo = function(...)
    local text, _, texture, startTime, endTime, _, _, _, spellID = Addon.LibClassicCasterino:UnitChannelInfo(...)

    -- With LibClassicCasterino, startTime is nil sometimes which means that no casting information
    -- is available
    if not startTime or not endTime then
      text = nil
    end

    return text, text, texture, startTime, endTime, false, false, spellID
  end

  UnitCastingInfo = function(...)
    local text, _, texture, startTime, endTime, _, _, _, spellID = Addon.LibClassicCasterino:UnitCastingInfo(...)

    -- With LibClassicCasterino, startTime is nil sometimes which means that no casting information
    -- is available
    if not startTime or not endTime then
      text = nil
    end

    return text, text, texture, startTime, endTime, false, nil, false, spellID
  end

  -- Not available in BC Classic, introduced in patch 9.0.1
  UnitNameplateShowsWidgetsOnly = function() return false end
elseif Addon.IS_TBC_CLASSIC then
  GetNameForNameplate = function(plate) return plate:GetName() end
  UnitEffectiveLevel = function(...) return _G.UnitLevel(...) end

  -- name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID
  UnitChannelInfo = function(...)
    local name, text, texture, startTime, endTime, isTradeSkill, spellID = _G.UnitChannelInfo(...)
    return name, text, texture, startTime, endTime, isTradeSkill, false, spellID
  end

  -- name, text, texture, startTime, endTime, isTradeSkill, _, notInterruptible, spellID
  UnitCastingInfo = function(...)
    -- In BC Classic, UnitCastingInfo does not return notInterruptible
    local name, text, texture, startTime, endTime, isTradeSkill, spellID = _G.UnitCastingInfo(...)
    return name, text, texture, startTime, endTime, isTradeSkill, nil, false, spellID
  end

  -- Not available in BC Classic, introduced in patch 9.0.1
  UnitNameplateShowsWidgetsOnly = function() return false end
elseif Addon.IS_WRATH_CLASSIC then
  GetNameForNameplate = function(plate) return plate:GetName() end
  UnitEffectiveLevel = function(...) return _G.UnitLevel(...) end

  UnitCastingInfo = _G.UnitCastingInfo

  -- Not available in WotLK Classic, introduced in patch 9.0.1
  UnitNameplateShowsWidgetsOnly = function() return false end
else
  GetNameForNameplate = function(plate) return plate:GetName() end

  UnitCastingInfo = function(...) return _G.UnitCastingInfo(...) end
end

-- Constants
-- Raid Icon Reference
local RaidIconCoordinate = {
  ["STAR"] = { x = 0, y =0 },
  ["CIRCLE"] = { x = 0.25, y = 0 },
  ["DIAMOND"] = { x = 0.5, y = 0 },
  ["TRIANGLE"] = { x = 0.75, y = 0},
  ["MOON"] = { x = 0, y = 0.25},
  ["SQUARE"] = { x = .25, y = 0.25},
  ["CROSS"] = { x = .5, y = 0.25},
  ["SKULL"] = { x = .75, y = 0.25},
}

local CASTBAR_INTERRUPT_HOLD_TIME = Addon.CASTBAR_INTERRUPT_HOLD_TIME
local ON_UPDATE_INTERVAL = Addon.ON_UPDATE_PER_FRAME
local PLATE_FADE_IN_TIME = Addon.PLATE_FADE_IN_TIME

-- Internal Data
local PlatesCreated, PlatesVisible, PlatesByUnit, PlatesByGUID = {}, {}, {}, {}
local nameplate, extended, visual			    	-- Temp/Local References
local unit, unitcache, style, stylename 	  -- Temp/Local References
local LastTargetPlate, LastFocusPlate
local ShowCastBars = true
local EMPTY_TEXTURE = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Empty"
local UpdateAll = false

local PlateOnUpdateQueue = {}

-- Cached CVARs (updated on every PLAYER_ENTERING_WORLD event
local CVAR_NameplateOccludedAlphaMult
-- Cached database settings
local SettingsEnabledFading
local SettingsOccludedAlpha, SettingsEnabledOccludedAlpha
local SettingsShowEnemyBlizzardNameplates, SettingsShowFriendlyBlizzardNameplates, SettingsHideBuffsOnPersonalNameplate
local SettingsTargetUnitHide, SettingsShowOnlyForTarget
local SettingsShowOnlyNames

-- External references to internal data
Addon.PlatesCreated = PlatesCreated
Addon.PlatesVisible = PlatesVisible
Addon.PlatesByUnit = PlatesByUnit
Addon.PlatesByGUID = PlatesByGUID
Addon.Theme = {}

local activetheme = Addon.Theme

---------------------------------------------------------------------------------------------------------------------
-- Core Function Declaration
---------------------------------------------------------------------------------------------------------------------
-- Helpers
local function IsPlateShown(plate) return plate and plate:IsShown() end

-- Queueing
local function SetUpdateMe(plate) plate.UpdateMe = true end
local function SetUpdateAll() UpdateAll = true end

-- Style
local UpdateStyle

-- Indicators
local UpdatePlate_SetAlpha, UpdatePlate_SetAlphaOnUpdate
local UpdatePlate_Transparency

local UpdateIndicator_CustomScale, UpdateIndicator_CustomScaleText, UpdateIndicator_Standard
local UpdateIndicator_Level, UpdateIndicator_RaidIcon
local UpdateIndicator_EliteIcon, UpdateIndicator_Name
local UpdateIndicator_HealthBar
local OnUpdateCasting, OnStartCasting, OnStopCasting, OnUpdateCastMidway

-- Event Functions
local OnNewNameplate, OnShowNameplate, OnUpdateNameplate, OnResetNameplate
local OnHealthUpdate, ProcessUnitChanges
local UNIT_TARGET

-- Main Loop
local OnUpdate

-- UpdateReferences
local function UpdateReferences(plate)
	nameplate = plate
	extended = plate.TPFrame

	unit = extended.unit
	unitcache = extended.unitcache
	visual = extended.visual
	style = extended.style
end

-- UpdateUnitCache
local function UpdateUnitCache() for key, value in pairs(unit) do unitcache[key] = value end end

---------------------------------------------------------------------------------------------------------------------
-- Nameplate Detection & Update Loop
---------------------------------------------------------------------------------------------------------------------

do
  -- OnUpdate; This function is run frequently, on every clock cycle
	function OnUpdate(self, e)
		-- Poll Loop
    local plate, curChildren

    for plate in pairs(PlatesVisible) do
			local UpdateMe = UpdateAll or plate.UpdateMe
			local UpdateHealth = plate.UpdateHealth

			-- Check for an Update Request
			if UpdateMe or UpdateHealth then
				if not UpdateMe then
					OnHealthUpdate(plate)
        else
          OnUpdateNameplate(plate)
				end
				plate.UpdateMe = false
				plate.UpdateHealth = false
      end

		-- This would be useful for alpha fades
		-- But right now it's just going to get set directly
		-- extended:SetAlpha(extended.requestedAlpha)
		end

		-- Reset Mass-Update Flag
		UpdateAll = false
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Functions for setting unit attributes
---------------------------------------------------------------------------------------------------------------------

local function SetUnitAttributeName(unitid, unit_type)
  local unit_name, realm = UnitName(unitid)

  if unit_type == "PLAYER" then
    local db = Addon.db.profile.settings.name

    if db.ShowTitle then
      unit_name = UnitPVPName(unitid)
    end

    if db.ShowRealm and realm then
      unit_name = unit_name .. " - " .. realm
    end
  end

  return unit_name
end

---------------------------------------------------------------------------------------------------------------------
--  Nameplate Extension: Applies scripts, hooks, and adds additional frame variables and regions
---------------------------------------------------------------------------------------------------------------------
do

	function OnNewNameplate(plate)
    -- Parent could be: WorldFrame, UIParent, plate
    local extended = _G.CreateFrame("Frame",  "ThreatPlatesFrame" .. GetNameForNameplate(plate), WorldFrame)
    extended:Hide()

    extended:SetFrameStrata("BACKGROUND")
    extended:EnableMouse(false)
    extended.Parent = plate
    --extended:SetAllPoints(plate)
    plate.TPFrame = extended

    -- Tidy Plates Frame References
    local visual = {}
    extended.visual = visual

    -- Add Graphical Elements

    -- Status Bars
    local castbar = Addon:CreateCastbar(extended)
    local healthbar = Addon:CreateHealthbar(extended)
    local textframe = _G.CreateFrame("Frame", nil, extended)

		textframe:SetAllPoints()

		visual.healthbar = healthbar
		visual.castbar = castbar
    visual.textframe = textframe

		-- Parented to Health Bar - Lower Frame
    visual.threatborder = healthbar.ThreatBorder
    visual.healthborder = healthbar.Border
    visual.eliteborder = healthbar.EliteBorder

    -- Parented to Extended - Middle Frame
    visual.raidicon = textframe:CreateTexture(nil, "OVERLAY", nil, 7)
    visual.eliteicon = healthbar:CreateTexture(nil, "OVERLAY", nil, 1)
    visual.skullicon = healthbar:CreateTexture(nil, "OVERLAY", nil, 2)

		-- TextFrame
    visual.name = textframe:CreateFontString(nil, "ARTWORK")
		visual.name:SetFont("Fonts\\FRIZQT__.TTF", 11)
    visual.name:SetWordWrap(false) -- otherwise text is wrapped when plate is scaled down
    visual.customtext = textframe:CreateFontString(nil, "ARTWORK")
		visual.customtext:SetFont("Fonts\\FRIZQT__.TTF", 11)
    visual.customtext:SetWordWrap(false) -- otherwise text is wrapped when plate is scaled down
		-- Level text is not shown in headline view, so anchoring it to the healthbar is ok
    visual.level = healthbar:CreateFontString(nil, "ARTWORK")
		visual.level:SetFont("Fonts\\FRIZQT__.TTF", 11)

		-- Cast Bar Frame - Highest Frame
		visual.spellicon = castbar:CreateTexture(nil, "OVERLAY", nil, 7)
		visual.spelltext = castbar:CreateFontString(nil, "ARTWORK")
		visual.spelltext:SetFont("Fonts\\FRIZQT__.TTF", 11)
    visual.spelltext:SetWordWrap(false) -- otherwise text is wrapped when plate is scaled down

    visual.Highlight = Addon:Element_Mouseover_Create(extended)

    -- Set Base Properties
		-- visual.raidicon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")

    extended.widgets = {}

		Addon.CreateExtensions(extended)
    Widgets:OnPlateCreated(extended)

    -- Allocate Tables
    extended.style = {}
    extended.stylename = ""
    extended.unit = {}
    extended.unitcache = {}
  end
end

---------------------------------------------------------------------------------------------------------------------
-- Nameplate Script Handlers
---------------------------------------------------------------------------------------------------------------------

do
	-- CheckNameplateStyle
	local function CheckNameplateStyle()
    local old_custom_style = unit.CustomPlateSettings

    stylename = Addon:SetStyle(unit)
    extended.style = activetheme[stylename]

		style = extended.style

		if style and (extended.stylename ~= stylename) then
      extended.stylename = stylename
      unit.style = stylename
      UpdateStyle()

      Addon.CreateExtensions(extended, unit.unitid, stylename)
      Widgets:OnUnitAdded(extended, unit)
    else
      -- Update the unique icon widget and style may be the same, but a different trigger might be active, e.g.,
      -- if two aura triggers fired
      if (stylename == "unique" or stylename == "NameOnly-Unique") and unit.CustomPlateSettings ~= old_custom_style then
        Addon.UpdateCustomStyleIcon(extended, unit)
      end

--      local unique_icon_widget = Widgets.Widgets.UniqueIcon
--      if (stylename == "unique" or stylename == "NameOnly-Unique") and unit.CustomPlateSettings ~= old_custom_style and unique_icon_widget then
--        unique_icon_widget:OnUnitAdded(extended.widgets.UniqueIcon, unit)
--      end
    end
	end

	-- ProcessUnitChanges
	function ProcessUnitChanges()
    -- Unit Cache: Determine if data has changed
    local unitchanged = false

    for key, value in pairs(unit) do
      if unitcache[key] ~= value then
        unitchanged = true
        break -- one change is enough to update the unit
      end
    end

    -- Update Style/Indicators
    if unitchanged or UpdateAll or (not style) then
      CheckNameplateStyle()
      UpdateIndicator_Standard()
      UpdateIndicator_HealthBar()
    end

    -- Update Delegates
    UpdateIndicator_CustomScaleText()
    UpdatePlate_Transparency(extended, unit)

    -- Cache the old unit information
    UpdateUnitCache()
	end

	---------------------------------------------------------------------------------------------------------------------
	-- Create / Hide / Show Event Handlers
	---------------------------------------------------------------------------------------------------------------------

  function Addon:UpdateNameplateStyle(plate, unitid)
    if UnitReaction(unitid, "player") > 4 then
      if SettingsShowFriendlyBlizzardNameplates then
        plate.UnitFrame:Show()
        plate.TPFrame:Hide()
        plate.TPFrame.Active = false
      else
        plate.UnitFrame:Hide()
        plate.TPFrame:Show()
        plate.TPFrame.Active = true
      end
    elseif SettingsShowEnemyBlizzardNameplates then
      plate.UnitFrame:Show()
      plate.TPFrame:Hide()
      plate.TPFrame.Active = false
    else
      plate.UnitFrame:Hide()
      plate.TPFrame:Show()
      plate.TPFrame.Active = true
    end

    --local show_plate = (UnitReaction(unitid, "player") > 4 and SettingsShowFriendlyBlizzardNameplates) or SettingsShowEnemyBlizzardNameplates
    --plate.UnitFrame:SetShown(show_plate)
    --plate.TPFrame:SetShown(not show_plate)
    --plate.TPFrame.Active = not show_plate
  end

	-- OnShowNameplate
	function OnShowNameplate(plate, unitid)
    UpdateReferences(plate)

    Addon:UpdateUnitIdentity(unit, unitid)

    unit.name = SetUnitAttributeName(unitid, unit.type)
    unit.isCasting = false
    unit.IsInterrupted = false
    visual.castbar.FlashTime = 0  -- Set FlashTime to 0 so that the castbar is actually hidden (see statusbar OnHide hook function OnHideCastbar)

    extended.stylename = ""

    extended.IsOccluded = false
    extended.CurrentAlpha = nil
    extended:SetAlpha(0)

    PlatesVisible[plate] = unitid
    PlatesByUnit[unitid] = plate
    PlatesByGUID[unit.guid] = plate

    Addon:UpdateUnitContext(unit, unitid)
    Addon.UnitStyle_NameDependent(unit)
    ProcessUnitChanges()

		Addon.UpdateExtensions(extended, unit.unitid, stylename)

    Addon:UpdateNameplateStyle(plate, unitid)

    UNIT_TARGET("UNIT_TARGET", unitid) -- requires tp_frame.Active, which is set in UpdateNameplateStyle

    -- Call this after the plate is shown as OnStartCasting checks if the plate is shown; if not, the castbar is hidden and
    -- nothing is updated
    OnUpdateCastMidway(plate, unitid)
  end

	-- OnUpdateNameplate
	function OnUpdateNameplate(plate)
    -- Gather Information
    local unitid = PlatesVisible[plate]
    UpdateReferences(plate)

		--Addon:UpdateUnitIdentity(plate.TPFrame, unitid)
    Addon:UpdateUnitContext(unit, unitid)
		ProcessUnitChanges()
		OnUpdateCastMidway(plate, unitid)
	end

	-- OnHealthUpdate
	function OnHealthUpdate(plate)
		local unitid = PlatesVisible[plate]
    UpdateReferences(plate)

    Addon:UpdateUnitCondition(unit, unitid)
    ProcessUnitChanges()
    OnUpdateCastMidway(nameplate, unit.unitid)

    -- Fix a bug where the overlay for non-interruptible casts was shown even for interruptible casts when entering combat while the unit was already casting
    --    if unit.isCasting and visual.castbar:IsShown()then
    --      visual.castbar:SetShownInterruptOverlay(unit.spellIsShielded)
    --    end

    --UpdateIndicator_HealthBar()		-- Just to be on the safe side
  end

  -- OnResetNameplate
	function OnResetNameplate(plate)
    -- wipe(plate.TPFrame.unit)
    wipe(plate.TPFrame.unitcache)

    OnShowNameplate(plate, PlatesVisible[plate])
	end
end


---------------------------------------------------------------------------------------------------------------------
--  Unit Updates: Updates Unit Data, Requests indicator updates
---------------------------------------------------------------------------------------------------------------------
local RaidIconList = { "STAR", "CIRCLE", "DIAMOND", "TRIANGLE", "MOON", "SQUARE", "CROSS", "SKULL" }

local MAP_UNIT_REACTION = {
  [1] = "HOSTILE",
  [2] = "HOSTILE",
  [3] = "HOSTILE",
  [4] = "NEUTRAL",
  [5] = "FRIENDLY",
  [6] = "FRIENDLY",
  [7] = "FRIENDLY",
  [8] = "FRIENDLY",
}

-- GetUnitReaction: Determines the reaction, and type of unit from the health bar color
local function GetReactionByColor(red, green, blue)
  if red < .1 then 	-- Friendly
    return "FRIENDLY"
  elseif red > .5 then
    if green > .9 then
      return "NEUTRAL"
    else
      return "HOSTILE"
    end
  else
    return "HOSTILE"
  end
end

local EliteReference = {
  ["elite"] = true,
  ["rareelite"] = true,
  ["worldboss"] = true,
}

local RareReference = {
  ["rare"] = true,
  ["rareelite"] = true,
}

local ThreatReference = {
  [0] = "LOW",
  [1] = "MEDIUM",
  [2] = "MEDIUM",
  [3] = "HIGH",
}

-- UpdateUnitIdentity: Updates Low-volatility Unit Data
-- (This is essentially static data)
--------------------------------------------------------
function Addon:UpdateUnitIdentity(unit, unitid)
  unit.unitid = unitid
  unit.guid = _G.UnitGUID(unitid)

  unit.classification = _G.UnitClassification(unitid)
  unit.isElite = EliteReference[unit.classification] or false
  unit.isRare = RareReference[unit.classification] or false
  unit.isMini = unit.classification == "minus"

  unit.isBoss = UnitEffectiveLevel(unitid) == -1
  if unit.isBoss then
    unit.classification = "boss"
  end
  unit.IsBossOrRare = (unit.isBoss or unit.isRare)

  if UnitIsPlayer(unitid) then
    _, unit.class = UnitClass(unitid)
    unit.type = "PLAYER"
  else
    unit.class = ""
    unit.type = "NPC"

    local _, _, _, _, _, npc_id = strsplit("-", unit.guid or "")
    unit.NPCID = npc_id
  end
end

-- UpdateUnitContext: Updates Target/Mouseover
function Addon:UpdateUnitContext(unit, unitid)
  unit.isMouseover = UnitIsUnit("mouseover", unitid)
  unit.isTarget = UnitIsUnit("target", unitid) -- required here for config changes which reset all plates without calling TARGET_CHANGED, MOUSEOVER, ...
  unit.IsFocus = UnitIsUnit("focus", unitid) -- required here for config changes which reset all plates without calling TARGET_CHANGED, MOUSEOVER, ...

  Addon:UpdateUnitCondition(unit, unitid)	-- This updates a bunch of properties
end

-- UpdateUnitCondition: High volatility data
function Addon:UpdateUnitCondition(unit, unitid)
  unit.level = UnitEffectiveLevel(unitid)

  local c = GetCreatureDifficultyColor(unit.level)
  unit.levelcolorRed, unit.levelcolorGreen, unit.levelcolorBlue = c.r, c.g, c.b

  unit.red, unit.green, unit.blue = _G.UnitSelectionColor(unitid)

  unit.reaction = MAP_UNIT_REACTION[UnitReaction(unitid, "player")] or GetReactionByColor(unit.red, unit.green, unit.blue)
  -- Enemy players turn to neutral, e.g., when mounting a flight path mount, so fix reaction in that situations
  if unit.reaction == "NEUTRAL" and (unit.type == "PLAYER" or UnitPlayerControlled(unitid)) then
    unit.reaction = "HOSTILE"
  end

  unit.health = _G.UnitHealth(unitid) or 0
  unit.healthmax = _G.UnitHealthMax(unitid) or 1

  unit.threatValue = UnitThreatSituation("player", unitid) or 0
  unit.threatSituation = ThreatReference[unit.threatValue]
  unit.isInCombat = _G.UnitAffectingCombat(unitid)

  local raidIconIndex = GetRaidTargetIndex(unitid)

  if raidIconIndex then
    unit.raidIcon = RaidIconList[raidIconIndex]
    unit.isMarked = true
  else
    unit.isMarked = false
  end

  unit.isTapped = _G.UnitIsTapDenied(unitid)
end

---------------------------------------------------------------------------------------------------------------------
-- Indicators: These functions update the color, texture, strings, and frames within a style.
---------------------------------------------------------------------------------------------------------------------

-- Update the health bar and name coloring, if needed
function Addon:UpdateIndicatorNameplateColor(tp_frame)
  local visual = tp_frame.visual
  local healthbar = visual.healthbar

  if healthbar:IsShown() then
    healthbar:SetAllColors(Addon:SetHealthbarColor(tp_frame.unit))

    -- Updates warning glow for threat
    if visual.threatborder:IsShown() then
      visual.threatborder:SetBackdropBorderColor(Addon:SetThreatColor(tp_frame.unit))
    end
  end

  if visual.name:IsShown() then
    visual.name:SetTextColor(Addon:SetNameColor(tp_frame.unit))
  end

  -- Update nameplate's target unit's color
  healthbar:ShowTargetUnit()
end

function Addon.UpdateCustomStyleAfterAuraTrigger(unit)
  UpdateReferences(GetNamePlateForUnit(unit.unitid))
  ProcessUnitChanges()
end

---------------------------------------------------------------------------------------------------------------------
-- Nameplate Transparency:
---------------------------------------------------------------------------------------------------------------------

local function UpdatePlate_SetAlphaWithFading(tp_frame, unit)
  local target_alpha = Addon:GetAlpha(unit)

  if target_alpha ~= tp_frame.CurrentAlpha then
    --Animations:StopFadeIn(tp_frame)
    --Animations:FadeIn(tp_frame, target_alpha, PLATE_FADE_IN_TIME)
    Animations:FadePlate(tp_frame, target_alpha, PLATE_FADE_IN_TIME)
    tp_frame.CurrentAlpha = target_alpha
  end
end

local function UpdatePlate_SetAlphaNoFading(tp_frame, unit)
  local target_alpha = Addon:GetAlpha(unit)

  if target_alpha ~= tp_frame.CurrentAlpha then
    tp_frame:SetAlpha(target_alpha)
    tp_frame.CurrentAlpha = target_alpha
  end
end

local	function UpdatePlate_SetAlphaWithOcclusion(tp_frame, unit)
  if not tp_frame:IsShown() or (tp_frame.IsOccluded and not unit.isTarget) then
    return
  end

  UpdatePlate_SetAlpha(tp_frame, unit)
end

local function UpdatePlate_SetAlphaWithFadingOcclusionOnUpdate(tp_frame, unit)
  local target_alpha

  local plate_alpha = tp_frame.Parent:GetAlpha()
  if plate_alpha < (CVAR_NameplateOccludedAlphaMult + 0.05) then
    tp_frame.IsOccluded = true
    target_alpha = SettingsOccludedAlpha
  elseif tp_frame.IsOccluded or not tp_frame.CurrentAlpha then
    tp_frame.IsOccluded = false
    target_alpha = Addon:GetAlpha(unit)
  end

  if target_alpha and target_alpha ~= tp_frame.CurrentAlpha then
    --Animations:StopFadeIn(tp_frame)
    Animations:StopFade(tp_frame)

    if tp_frame.IsOccluded then
      tp_frame:SetAlpha(target_alpha)
    else
      --Animations:FadeIn(tp_frame, target_alpha, PLATE_FADE_IN_TIME)
      Animations:FadePlate(tp_frame, target_alpha, PLATE_FADE_IN_TIME)
    end

    tp_frame.CurrentAlpha = target_alpha
  end
end

local function UpdatePlate_SetAlphaNoFadingOcclusionOnUpdate(tp_frame, unit)
  local target_alpha

  local plate_alpha = tp_frame.Parent:GetAlpha()
  if plate_alpha < (CVAR_NameplateOccludedAlphaMult + 0.05) then
    tp_frame.IsOccluded = true
    target_alpha = SettingsOccludedAlpha
  elseif tp_frame.IsOccluded or not tp_frame.CurrentAlpha then
    tp_frame.IsOccluded = false
    target_alpha = Addon:GetAlpha(unit)
  end

  if target_alpha and target_alpha ~= tp_frame.CurrentAlpha then
    tp_frame:SetAlpha(target_alpha)
    tp_frame.CurrentAlpha = target_alpha
  end
end

---------------------------------------------------------------------------------------------------------------------
-- Nameplate Updating:
---------------------------------------------------------------------------------------------------------------------

do
	-- UpdateIndicator_HealthBar: Updates the value on the health bar
	function UpdateIndicator_HealthBar()
		visual.healthbar:SetMinMaxValues(0, unit.healthmax)
    visual.healthbar:SetValue(unit.health)
  end

	function UpdateIndicator_Name()
		visual.name:SetText(Addon:SetNameText(unit))
    visual.name:SetTextColor(Addon:SetNameColor(unit))
	end

	function UpdateIndicator_Level()
		if unit.isBoss and style.skullicon.show then
      visual.level:Hide()
      visual.skullicon:Show()
    else
      visual.skullicon:Hide()
    end

		if unit.level < 0 then
      visual.level:SetText("")
		else
      visual.level:SetText((unit.isElite and "+" or "") .. unit.level)
    end

    visual.level:SetTextColor(unit.levelcolorRed, unit.levelcolorGreen, unit.levelcolorBlue)
	end

	-- UpdateIndicator_RaidIcon
	function UpdateIndicator_RaidIcon()
    --    if unit.isMarked and RaidIconCoordinate[unit.raidIcon] == nil then
    --      ThreatPlates.DEBUG("UpdateIndicator_RaidIcon:", unit.unitid, "- isMarked:", unit.isMarked, "/ raidIcon:", unit.raidIcon)
    --      ThreatPlates.DEBUG("UpdateIndicator_RaidIcon: RaidIconCoordinate:", RaidIconCoordinate[unit.raidIcon])
    --    end

    if unit.isMarked and style.raidicon.show then
      local iconCoord = RaidIconCoordinate[unit.raidIcon]
      if iconCoord then
        visual.raidicon:Show()
        visual.raidicon:SetTexCoord(iconCoord.x, iconCoord.x + 0.25, iconCoord.y,  iconCoord.y + 0.25)
      else
        visual.raidicon:Hide()
      end
    else
      visual.raidicon:Hide()
    end
	end


	-- UpdateIndicator_EliteIcon: Updates the border overlay art and threat glow to Elite or Non-Elite art
	function UpdateIndicator_EliteIcon()
    if unit.isRare then
      visual.eliteicon:SetShown(style.eliteicon.show)
      visual.eliteborder:SetShown(style.eliteborder.show)

      if unit.isElite then
        visual.eliteicon:SetVertexColor(0.804, 0.498, 0.196)
        visual.eliteborder:SetBackdropBorderColor(0.804, 0.498, 0.196)
      else
        visual.eliteicon:SetVertexColor(0.8, 0.8, 0.8)
        visual.eliteborder:SetBackdropBorderColor(0.8, 0.8, 0.8)
      end
    elseif unit.isElite then
      visual.eliteicon:SetVertexColor(1, 0.85, 0)
      visual.eliteicon:SetShown(style.eliteicon.show)
      visual.eliteborder:SetBackdropBorderColor(1, 0.85, 0, 1)
      visual.eliteborder:SetShown(style.eliteborder.show)
    else
      visual.eliteicon:Hide()
      visual.eliteborder:Hide()
    end
	end

	-- UpdateIndicator_Standard: Updates Non-Delegate Indicators
	function UpdateIndicator_Standard()
		if IsPlateShown(nameplate) then -- why this check only only here?
			if unitcache.name ~= unit.name then UpdateIndicator_Name() end
			if unitcache.level ~= unit.level then UpdateIndicator_Level() end
			UpdateIndicator_RaidIcon()

			if (unitcache.isElite ~= unit.isElite) or (unitcache.isRare ~= unit.isRare) then
        UpdateIndicator_EliteIcon()
      end
		end
	end

  function UpdateIndicator_CustomScale(tp_frame, unit)
    tp_frame:SetScale(Addon.UIScale * Addon:SetScale(unit))
  end

	-- UpdateIndicator_CustomScaleText: Updates indicators for custom text and scale
	function UpdateIndicator_CustomScaleText()
		--if unit.health and (extended.requestedAlpha > 0) then
    --if unit.health and extended.CurrentAlpha > 0 then
    if unit.health then
			-- Scale
      extended:SetScale(Addon.UIScale * Addon:SetScale(unit))
      Addon.SetCustomText(extended, unit)
      Addon:UpdateIndicatorNameplateColor(extended)
		end
	end

	-- OnShowCastbar
	function OnStartCasting(plate, unitid, channeled)
    UpdateReferences(plate)

    local castbar = extended.visual.castbar
    if not extended:IsShown() then
      castbar:Hide()
      return
    end

    local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID
    if channeled then
      name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(unitid)
		else
      name, text, texture, startTime, endTime, isTradeSkill, _, notInterruptible, spellID = UnitCastingInfo(unitid)
    end

    if not name or isTradeSkill then
      castbar:Hide()
      return
    end

    local plate_style = Addon.ActiveCastTriggers and Addon.UnitStyle_CastDependent(unit, spellID, name)

    -- Abort here as casts can now switch nameplate styles (e.g,. from headline to healthbar view
    if not (style.castbar.show or plate_style) then
      castbar:Hide()
      return
    end

    unit.isCasting = true
    unit.IsInterrupted = false
    unit.spellIsShielded = notInterruptible
		unit.spellInterruptible = not notInterruptible

    --if plate_style and plate_style ~= extended.stylename then
    if plate_style ~= extended.stylename then
      ProcessUnitChanges()
    else
      UpdateIndicator_CustomScaleText()
      UpdatePlate_Transparency(extended, unit)
    end

    -- Custom nameplates might trigger cause of a cast, but still stay in a style that does not
    -- show the castbar
    if not style.castbar.show then
      castbar:Hide()
      return
    end

    visual.spelltext:SetText(text)
		visual.spellicon:SetTexture(texture)

    local target_unit_name = UnitName(unit.unitid .. "target")
    -- There are situations when UnitName returns nil (OnHealthUpdate, hypothesis: health update when the unit died tiggers this, but then there is no target any more)
    if target_unit_name then
      local _, class_name = UnitClass(target_unit_name)
      castbar.CastTarget:SetText(Addon.ColorByClass(class_name, TransliterateCyrillicLetters(target_unit_name)))
    else
      castbar.CastTarget:SetText(nil)
    end

    castbar.IsCasting = not channeled
    castbar.IsChanneling = channeled

    -- Sometimes startTime/endTime are nil (even in Retail). Not sure if name is always nil is this case as well, just to be sure here
    -- I think this should not be necessary, name should be nil in this case, but not sure.
    endTime = endTime or 0
    startTime = startTime or 0
    if channeled then
      castbar.Value = (endTime / 1000) - GetTime()
    else
      castbar.Value = GetTime() - (startTime / 1000)
    end
    castbar.MaxValue = (endTime - startTime) / 1000
    castbar:SetMinMaxValues(0, castbar.MaxValue)
    castbar:SetValue(castbar.Value)
    castbar:SetAllColors(Addon:SetCastbarColor(unit))
    castbar:SetFormat(unit.spellIsShielded)

    castbar:Show()
	end

	-- OnHideCastbar
	function OnStopCasting(plate)
    UpdateReferences(plate)

    local castbar = extended.visual.castbar
    castbar.IsCasting = false
    castbar.IsChanneling = false
    unit.isCasting = false

    if unit.CustomStyleCast then
      unit.CustomStyleCast = false
      ProcessUnitChanges()
    else
      UpdateIndicator_CustomScale(extended, unit)
      UpdatePlate_Transparency(extended, unit)
    end
	end

	function OnUpdateCastMidway(plate, unitid)
		if not ShowCastBars then return end

		-- Check to see if there's a spell being cast
		if UnitCastingInfo(unitid) then
      OnStartCasting(plate, unitid, false)
    elseif UnitChannelInfo(unitid) then
      OnStartCasting(plate, unitid, true)
    else
      -- It would be better to check for IsInterrupted here and not hide it if that is true
      -- Not currently sure though, if that might work with the Hide() calls in OnStartCasting
      visual.castbar:Hide()
    end
	end

end -- End Indicator section

--------------------------------------------------------------------------------------------------------------
-- WoW Event Handlers: sends event-driven changes to the appropriate gather/update handler.
--------------------------------------------------------------------------------------------------------------

----------------------------------------
-- Frequently Used Event-handling Functions
----------------------------------------
-- Update individual plate
local function UnitConditionChanged(event, unitid)
  if UnitIsUnit("player", unitid) then return end -- skip personal resource bar

  local plate = GetNamePlateForUnit(unitid)
  if plate then
    OnHealthUpdate(plate)
  end
end

-- Update everything
local function WorldConditionChanged()
  SetUpdateAll()
end

local function ClassicBlizzardNameplatesSetAlpha(UnitFrame, alpha)
  if Addon.WOW_USES_CLASSIC_NAMEPLATES then
    UnitFrame.LevelFrame:SetAlpha(alpha)
  else
    UnitFrame.ClassificationFrame:SetAlpha(alpha)
  end
end

local function FrameOnShow(UnitFrame)
  local unitid = UnitFrame.unit

  -- Hide nameplates that have not yet an unit added
  if not unitid then
    UnitFrame:Hide()
    return
  end

  if UnitNameplateShowsWidgetsOnly(unitid) then
    -- Don't show ThreatPlates for widget-only nameplates (since Shadowlands)
    return
  end

  -- Skip the personal resource bar of the player character, don't unhook scripts as nameplates, even the personal
  -- resource bar, get re-used
  if UnitIsUnit(unitid, "player") then -- or: ns.PlayerNameplate == GetNamePlateForUnit(UnitFrame.unit)
    if SettingsHideBuffsOnPersonalNameplate then
      UnitFrame.BuffFrame:Hide()
    --      else
    --        UnitFrame.BuffFrame:Show()
    end
    -- Just an else with the part below should work also
    return
  end

  if SettingsShowOnlyNames then
    ClassicBlizzardNameplatesSetAlpha(UnitFrame, 0)
  end

  -- Hide ThreatPlates nameplates if Blizzard nameplates should be shown for friendly units
  if UnitReaction(unitid, "player") > 4 then
    UnitFrame:SetShown(SettingsShowFriendlyBlizzardNameplates)
  else
    UnitFrame:SetShown(SettingsShowEnemyBlizzardNameplates)
  end
end

-- Frame: self = plate
local function FrameOnUpdate(plate, elapsed)
  -- Update the number of seconds since the last update
  plate.TimeSinceLastUpdate = (plate.TimeSinceLastUpdate or 0) + elapsed

  if plate.TimeSinceLastUpdate >= ON_UPDATE_INTERVAL then
    plate.TimeSinceLastUpdate = 0

    local tp_frame = plate.TPFrame
    if not tp_frame.Active or UnitIsUnit(plate.UnitFrame.unit or "", "player") then
      return
    end
    
    tp_frame:SetFrameLevel(plate:GetFrameLevel() * 10)

--    for i = 1, #PlateOnUpdateQueue do
--      PlateOnUpdateQueue[i](plate, plate.TPFrame.unit)
--    end

    if SettingsEnabledOccludedAlpha then
      UpdatePlate_SetAlphaOnUpdate(tp_frame, tp_frame.unit)
    end
  end
end

-- Frame: self = plate
local function FrameOnHide(plate)
  plate.TPFrame:Hide()
end

---------------------------------------------------------------------------------------------------
-- Event Handling
---------------------------------------------------------------------------------------------------

local CoreEvents = {}
Addon.EventHandler = CoreEvents

local function EventHandler(self, event, ...)
  CoreEvents[event](event, ...)
end

local function NamePlateDriverFrame_AcquireUnitFrame(_, plate)
  local unit_frame = plate.UnitFrame
  if not unit_frame:IsForbidden() and not unit_frame.ThreatPlates then
    unit_frame.ThreatPlates = true
    unit_frame:HookScript("OnShow", FrameOnShow)
  end
end

function CoreEvents:PLAYER_LOGIN()
  -- Fix for Blizzard default plates being shown at random times
  -- Works for Mainline and Wrath Classic
  if NamePlateDriverFrame and NamePlateDriverFrame.AcquireUnitFrame then
    hooksecurefunc(NamePlateDriverFrame, "AcquireUnitFrame", NamePlateDriverFrame_AcquireUnitFrame)
  end
end

function CoreEvents:PLAYER_ENTERING_WORLD()
  TidyPlatesCore:SetScript("OnUpdate", OnUpdate)
end

function CoreEvents:NAME_PLATE_CREATED(plate)
  OnNewNameplate(plate)

  -- NamePlateDriverFrame.AcquireUnitFrame is not used in Classic
  if (Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC) and plate.UnitFrame then
    NamePlateDriverFrame_AcquireUnitFrame(nil, plate)
  end

  plate:HookScript('OnHide', FrameOnHide)
  plate:HookScript('OnUpdate', FrameOnUpdate)

  Addon.PlatesCreated[plate] = plate.TPFrame
end

-- Payload: { Name = "unitToken", Type = "string", Nilable = false },
function CoreEvents:NAME_PLATE_UNIT_ADDED(unitid)
  -- Player's personal resource bar is currently not handled by Threat Plates
  -- OnShowNameplate is not called on it, therefore plate.TPFrame.Active is nil
  if UnitIsUnit("player", unitid) or UnitNameplateShowsWidgetsOnly(unitid) then return end

  OnShowNameplate(GetNamePlateForUnit(unitid), unitid)
end

function CoreEvents:NAME_PLATE_UNIT_REMOVED(unitid)
  local plate = GetNamePlateForUnit(unitid)
  local frame = plate.TPFrame

  frame.Active = false
  frame:Hide()

  PlatesVisible[plate] = nil
  PlatesByUnit[unitid] = nil
  if frame.unit.guid then -- maybe hide directly after create with unit added?
    PlatesByGUID[frame.unit.guid] = nil
  end

  Widgets:OnUnitRemoved(frame, frame.unit)

  wipe(frame.unit)
  wipe(frame.unitcache)

  --frame.style = nil
  -- Set stylename to nil as CheckNameplateStyle compares the new style with the previous style.
  -- In both are unique, the nameplate is not updated to the correct custom style, but uses the
  -- previous one, I think
  frame.stylename = nil

  -- Remove anything from the function queue
  frame.UpdateMe = false
end

function CoreEvents:UNIT_NAME_UPDATE(unitid)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if unitid == "target" or UnitIsUnit("player", unitid) then return end

  local plate = GetNamePlateForUnit(unitid) -- can plate ever be nil here?

  -- Plate can be nil here, if unitid is party1, partypet4 or something like that
  if plate and plate.TPFrame.Active then
    UpdateReferences(plate)
    unit.name = SetUnitAttributeName(unitid, unit.type)

    --Addon:UnitStyle_UnitType(extended, unit)
    local plate_style = Addon.UnitStyle_NameDependent(unit)
    if plate_style and plate_style ~= extended.stylename then
      -- Totem or Custom Nameplate
      ProcessUnitChanges()
    else
      -- just update the name
      UpdateIndicator_Name()
      -- if it's an NPC, subtitle is saved by name, change that to guid/unitid
      Addon.SetCustomText(extended, extended.unit)
    end
  end
end

function CoreEvents:PLAYER_TARGET_CHANGED()
  -- Target Castbar Offset
  local castbar, style, extended
  if LastTargetPlate and LastTargetPlate.TPFrame.Active then
    extended = LastTargetPlate.TPFrame
    castbar = extended.visual.castbar
    style = extended.style
    castbar:ClearAllPoints()
    castbar:SetPoint(style.castbar.anchor or "CENTER", extended, style.castbar.x or 0, style.castbar.y or 0)

    LastTargetPlate = nil

    -- Update mouseover, if the mouse was hovering over the targeted unit
    extended.unit.isTarget = false
    if SettingsShowOnlyForTarget then
      extended.visual.healthbar:HideTargetUnit()
    end
    CoreEvents:UPDATE_MOUSEOVER_UNIT()
  end

  local plate = GetNamePlateForUnit("target")
  --if plate and plate.TPFrame and plate.TPFrame.stylename ~= "" then
  if plate and plate.TPFrame.Active then
    extended = plate.TPFrame
    castbar = extended.visual.castbar
    style = extended.style
    castbar:ClearAllPoints()
    local db = Addon.db.profile.settings.castbar
    castbar:SetPoint(style.castbar.anchor or "CENTER", extended, style.castbar.x + db.x_target or 0, style.castbar.y + db.y_target or 0)

    LastTargetPlate = plate

    extended.unit.isTarget = true
    UNIT_TARGET("UNIT_TARGET", extended.unit.unitid)
  end

  SetUpdateAll()
end

UNIT_TARGET = function(event, unitid)
  -- Skip special unit ids (which are updated with their nameplate unit id anyway) and personal nameplate
  if SettingsTargetUnitHide or unitid == "target" or UnitIsUnit("player", unitid) then return end

  local plate = GetNamePlateForUnit(unitid)
  if plate and plate.TPFrame.Active then
    local healthbar = plate.TPFrame.visual.healthbar

    if SettingsShowOnlyForTarget and not UnitIsUnit("target", unitid) then
      healthbar:HideTargetUnit()
      return
    end

    healthbar:ShowTargetUnit(unitid)
  end
end

local function PLAYER_FOCUS_CHANGED(event)
  local extended
  if LastFocusPlate and LastFocusPlate.TPFrame.Active then
    LastFocusPlate.TPFrame.unit.IsFocus = false
    LastFocusPlate = nil
    -- Update mouseover, if the mouse was hovering over the targeted unit
    CoreEvents:UPDATE_MOUSEOVER_UNIT()
  end

  local plate = GetNamePlateForUnit("focus")
  if plate and plate.TPFrame.Active then
    plate.TPFrame.unit.IsFocus = true
    LastFocusPlate = plate
  end

  SetUpdateAll()
end

function CoreEvents:UPDATE_MOUSEOVER_UNIT()
  if UnitIsUnit("mouseover", "player") then return end

  local plate = GetNamePlateForUnit("mouseover")
  if plate and plate.TPFrame.Active then -- check for Active to prevent accessing the personal resource bar
    local frame = plate.TPFrame
    frame.unit.isMouseover = true
    Addon:Element_Mouseover_Update(frame)
    UpdateIndicator_CustomScale(frame, frame.unit)
    UpdatePlate_Transparency(frame, frame.unit)
  end
end

local function UNIT_HEALTH(event, unitid)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if unitid == "target" or UnitIsUnit("player", unitid) then return end

  local plate = GetNamePlateForUnit(unitid)
  local tp_frame = plate and plate.TPFrame -- or nil, false if plate == nil
  if tp_frame then
    --if not tp_frame.Active then
    --  print ("UNIT_HEALTH on non-active nameplate:", tp_frame.unit.name)
    --end

    --if tp_frame.Active then
    --if tp_frame:IsShown() then
    local visual = tp_frame.visual
    if tp_frame.Active or (tp_frame:IsShown() and (visual.healthbar:IsShown() or visual.customtext:IsShown())) then
      OnHealthUpdate(plate)
      Addon.UpdateExtensions(plate.TPFrame, unitid, plate.TPFrame.stylename)
    end
  end

  --local tp_frame = plate and plate.TPFrame -- or nil, false if plate == nil
  --if tp_frame and tp_frame.Active then
  --  OnHealthUpdate(plate)
  --  Addon.UpdateExtensions(plate.TPFrame, unitid, plate.TPFrame.stylename)
  --end
end

function CoreEvents:UNIT_MAXHEALTH(unitid)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if unitid == "target" or UnitIsUnit("player", unitid) then return end

  local plate = GetNamePlateForUnit(unitid)
  if plate and plate.TPFrame.Active then
    OnHealthUpdate(plate)
    Addon.UpdateExtensions(plate.TPFrame, unitid, plate.TPFrame.stylename)
  end
end

function CoreEvents:UNIT_THREAT_LIST_UPDATE(unitid)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if unitid == "target" or UnitIsUnit("player", unitid) then return end

  local plate = PlatesByUnit[unitid]
  if plate then
    --local threat_value = UnitThreatSituation("player", unitid) or 0
    --if threat_value ~= plate.TPFrame.unit.threatValue then
    if (UnitThreatSituation("player", unitid) or 0) ~= plate.TPFrame.unit.threatValue then

      --OnHealthUpdate(plate)

      plate.UpdateMe = true

      -- TODO: Optimize this - only update elements that need updating
      -- Don't use OnHealthUpdate(), more like: OnThreatUpdate()
      -- UpdateReferences(plate)
      --Addon:UpdateUnitCondition(unit, unitid)
      --        unit.threatValue = UnitThreatSituation("player", unitid) or 0
      --        unit.threatSituation = ThreatReference[unit.threatValue]
      --        unit.isInCombat = _G.UnitAffectingCombat(unitid)
      --ProcessUnitChanges()
      --OnUpdateCastMidway(nameplate, unit.unitid)
    end

    -- UNIT_TARGET does not update correctly, so use this in in-combat situations as a work-around
    UNIT_TARGET("UNIT_TARGET", unitid)
  end
end

function CoreEvents:PLAYER_REGEN_ENABLED()
  SetUpdateAll()
end

function CoreEvents:PLAYER_REGEN_DISABLED()
  SetUpdateAll()
end

local function UNIT_SPELLCAST_START(event, unitid, ...)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if unitid == "target" or UnitIsUnit("player", unitid) or not ShowCastBars then return end

  local plate = GetNamePlateForUnit(unitid)
  if plate and plate.TPFrame.Active then
    OnStartCasting(plate, unitid, false)
  end
end

-- Update spell currently being cast
local function UnitSpellcastMidway(event, unitid, ...)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if unitid == "target" or UnitIsUnit("player", unitid) or not ShowCastBars then return end

  local plate = GetNamePlateForUnit(unitid)
  if plate then
    UpdateReferences(plate)
    OnUpdateCastMidway(plate, unitid)
  end
end

local function UNIT_SPELLCAST_STOP(event, unitid, ...)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if unitid == "target" or UnitIsUnit("player", unitid) or not ShowCastBars then return end

  -- plate can be nil, e.g., if unitid = player, combat ends and the player resource bar is already hidden
  -- when the cast stops (because it's not shown out of combat)
  local plate = GetNamePlateForUnit(unitid)
  if plate and plate.TPFrame.Active then
    OnStopCasting(plate)
  end
end

local function UNIT_SPELLCAST_CHANNEL_START(event, unitid, ...)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if unitid == "target" or UnitIsUnit("player", unitid) or not ShowCastBars then return end

  local plate = GetNamePlateForUnit(unitid)
  if plate and plate.TPFrame.Active then
    OnStartCasting(plate, unitid, true)
    --late.TPFrame.visual.castbar:Show()
  end
end

local function UNIT_SPELLCAST_CHANNEL_STOP(event, unitid, ...)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if unitid == "target" or UnitIsUnit("player", unitid) or not ShowCastBars then return end

  local plate = GetNamePlateForUnit(unitid)
  if plate and plate.TPFrame.Active then
    OnStopCasting(plate)
  end
end

function Addon.UNIT_SPELLCAST_INTERRUPTED(event, unitid, castGUID, spellID, sourceName, interrupterGUID)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if unitid == "target" or UnitIsUnit("player", unitid) or not ShowCastBars then return end

  local plate = GetNamePlateForUnit(unitid)

  if plate and plate.TPFrame.Active then
    if sourceName then
      UpdateReferences(plate)

      local castbar = visual.castbar
      if castbar:IsShown() then
        local db = Addon.db.profile

        sourceName = gsub(sourceName, "%-[^|]+", "") -- UnitName(sourceName) only works in groups
        local _, class_name = GetPlayerInfoByGUID(interrupterGUID)
        visual.spelltext:SetText(INTERRUPTED .. " [" .. Addon.ColorByClass(class_name, TransliterateCyrillicLetters(sourceName)) .. "]")

        local _, max_val = castbar:GetMinMaxValues()
        castbar:SetValue(max_val)
        castbar.Spark:Hide()

        local color = db.castbarColorInterrupted
        castbar:SetStatusBarColor(color.r, color.g, color.b, color.a)
        castbar.FlashTime = CASTBAR_INTERRUPT_HOLD_TIME

        -- Code from OnStopCasting
        castbar.IsCasting = false
        castbar.IsChanneling = false
        unit.isCasting = false
        UpdateIndicator_CustomScale(extended, unit)
        UpdatePlate_Transparency(extended, unit)

        -- I am assuming that OnStopCasting is called always when a cast is interrupted from
        -- _STOP events
        unit.IsInterrupted = true

        -- Should not be necessary any longer ... as OnStopCasting is not hiding the castbar anymore
        castbar:Show()
      end
    else
      OnStopCasting(plate)
    end
  end
end

function CoreEvents:COMBAT_LOG_EVENT_UNFILTERED()
  local timeStamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

  if event == "SPELL_INTERRUPT" then
    local plate = PlatesByGUID[destGUID]

    if plate and plate.TPFrame.Active then
      UpdateReferences(plate)

      local castbar = visual.castbar
      if castbar:IsShown() then
        local db = Addon.db.profile
        sourceName = gsub(sourceName, "%-[^|]+", "") -- UnitName(sourceName) only works in groups
        local _, class_name = GetPlayerInfoByGUID(sourceGUID)
        visual.spelltext:SetText(INTERRUPTED .. " [" .. Addon.ColorByClass(class_name, TransliterateCyrillicLetters(sourceName)) .. "]")

        local _, max_val = castbar:GetMinMaxValues()
        castbar:SetValue(max_val)
        castbar.Spark:Hide()

        local color = db.castbarColorInterrupted
        castbar:SetStatusBarColor(color.r, color.g, color.b, color.a)
        castbar.FlashTime = CASTBAR_INTERRUPT_HOLD_TIME

        -- I am assuming that OnStopCasting is called always when a cast is interrupted from
        -- _STOP events
        unit.IsInterrupted = true

        -- Should not be necessary any longer ... as OnStopCasting is not hiding the castbar anymore
        castbar:Show()
      end
    end
  end
end

--  local function ConvertPixelsToUI(pixels, frameScale)
--    local physicalScreenHeight = select(2, GetPhysicalScreenSize())
--    return (pixels * 768.0)/(physicalScreenHeight * frameScale)
--  end

function CoreEvents:UI_SCALE_CHANGED()
  Addon:UIScaleChanged()
  Addon:ForceUpdate()
end

local function UNIT_ABSORB_AMOUNT_CHANGED(event, unitid)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if unitid == "target" or UnitIsUnit("player", unitid) then return end

  local plate = GetNamePlateForUnit(unitid)
  if plate and plate.TPFrame.Active then
    local tp_frame = plate.TPFrame
    local unit = tp_frame.unit
    local unitid  = unit.unitid

    -- As this does not use OnUpdate with OnHealthUpdate, we have to update this values here
    unit.health = _G.UnitHealth(unit.unitid) or 0
    unit.healthmax = _G.UnitHealthMax(unit.unitid) or 1

    Addon.UpdateExtensions(tp_frame, unitid, tp_frame.stylename)
    Addon.SetCustomText(tp_frame, unit)
  end
end

local function UNIT_HEAL_ABSORB_AMOUNT_CHANGED(event, unitid)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if unitid == "target" or UnitIsUnit("player", unitid) then return end

  local plate = GetNamePlateForUnit(unitid)
  if plate and plate.TPFrame.Active then
    Addon.UpdateExtensions(plate.TPFrame, unitid, plate.TPFrame.stylename)
  end
end

-- Update all elements that depend on the unit's reaction towards the player
function CoreEvents:UNIT_FACTION(unitid)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if unitid == "target" then
    return
  elseif unitid == "player" then
    SetUpdateAll() -- Update all plates
  else
    -- Update just the unitid's plate
    local plate = GetNamePlateForUnit(unitid)
    if plate and plate.TPFrame.Active then
      UpdateReferences(plate)
      Addon:UpdateUnitCondition(unit, unitid)
      -- If Blizzard-style nameplates are used, we also need to check if TP plates are disabled/enabled now
      Addon:UpdateNameplateStyle(plate, unitid)
      ProcessUnitChanges()
    end
  end
end

-- Only registered for player unit
local TANK_AURA_SPELL_IDs = {
  [20468] = true, [20469] = true, [20470] = true, [25780] = true, -- Paladin Righteous Fury
  [48263] = true -- Deathknight Frost Presence
}
local function UNIT_AURA(event, unitid)
  local _, name, spellId
  for i = 1, 40 do
    name , _, _, _, _, _, _, _, _, spellId = _G.UnitBuff("player", i, "PLAYER")
    if not name then
      break
    elseif TANK_AURA_SPELL_IDs[spellId] then
      Addon.PlayerIsTank = true
      return
    end
  end

  Addon.PlayerIsTank = false
end

--  function CoreEvents:UNIT_SPELLCAST_INTERRUPTED(unitid, lineid, spellid)
--    if unitid == "target" or UnitIsUnit("player", unitid) or not ShowCastBars then return end
--  end

if Addon.IS_CLASSIC then
  Addon.UNIT_SPELLCAST_START = UNIT_SPELLCAST_START
  Addon.UNIT_SPELLCAST_STOP = UNIT_SPELLCAST_STOP
  Addon.UNIT_SPELLCAST_CHANNEL_START = UNIT_SPELLCAST_CHANNEL_START
  Addon.UNIT_SPELLCAST_CHANNEL_STOP = UNIT_SPELLCAST_CHANNEL_STOP
  Addon.UnitSpellcastMidway = UnitSpellcastMidway
  CoreEvents.UNIT_HEALTH_FREQUENT = UNIT_HEALTH
else
  -- The following events should not have worked before adjusting UnitSpellcastMidway
  CoreEvents.UNIT_SPELLCAST_START = UNIT_SPELLCAST_START
  CoreEvents.UNIT_SPELLCAST_STOP = UNIT_SPELLCAST_STOP
  CoreEvents.UNIT_SPELLCAST_CHANNEL_START = UNIT_SPELLCAST_CHANNEL_START
  CoreEvents.UNIT_SPELLCAST_CHANNEL_STOP = UNIT_SPELLCAST_CHANNEL_STOP

  CoreEvents.UNIT_SPELLCAST_DELAYED = UnitSpellcastMidway
  CoreEvents.UNIT_SPELLCAST_CHANNEL_UPDATE = UnitSpellcastMidway
  -- UNIT_SPELLCAST_SUCCEEDED
  -- UNIT_SPELLCAST_FAILED
  -- UNIT_SPELLCAST_FAILED_QUIET
  -- UNIT_SPELLCAST_INTERRUPTED - handled by COMBAT_LOG_EVENT_UNFILTERED / SPELL_INTERRUPT as it's the only way to find out the interruptorom
  -- UNIT_SPELLCAST_SENT

  CoreEvents.PLAYER_FOCUS_CHANGED = PLAYER_FOCUS_CHANGED

  if Addon.IS_MAINLINE then
    CoreEvents.UNIT_SPELLCAST_INTERRUPTIBLE = UnitSpellcastMidway
    CoreEvents.UNIT_SPELLCAST_NOT_INTERRUPTIBLE = UnitSpellcastMidway

    CoreEvents.UNIT_ABSORB_AMOUNT_CHANGED = UNIT_ABSORB_AMOUNT_CHANGED
    CoreEvents.UNIT_HEAL_ABSORB_AMOUNT_CHANGED = UNIT_HEAL_ABSORB_AMOUNT_CHANGED

    -- UNIT_HEALTH_FREQUENT no longer supported in Retail since 9.0.1
    CoreEvents.UNIT_HEALTH = UNIT_HEALTH
  else
    CoreEvents.UNIT_HEALTH_FREQUENT = UNIT_HEALTH
  end
end

CoreEvents.UNIT_LEVEL = UnitConditionChanged
--CoreEvents.UNIT_THREAT_SITUATION_UPDATE = UnitConditionChanged -- did not work anyway (no unitid)
CoreEvents.RAID_TARGET_UPDATE = WorldConditionChanged
CoreEvents.PLAYER_CONTROL_LOST = WorldConditionChanged
CoreEvents.PLAYER_CONTROL_GAINED = WorldConditionChanged

-- Registration of Blizzard Events
TidyPlatesCore:SetFrameStrata("TOOLTIP") 	-- When parented to WorldFrame, causes OnUpdate handler to run close to last
TidyPlatesCore:SetScript("OnEvent", EventHandler)
for eventName in pairs(CoreEvents) do TidyPlatesCore:RegisterEvent(eventName) end

CoreEvents.UNIT_TARGET = UNIT_TARGET

-- Do this after events are registered, otherwise UNIT_AURA would be registered as a general event, not only as
-- an unit event.
if ((Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC) and Addon.PlayerClass == "PALADIN") or (Addon.IS_WRATH_CLASSIC and Addon.PlayerClass == "DEATHKNIGHT") then
  CoreEvents.UNIT_AURA = UNIT_AURA
  TidyPlatesCore:RegisterUnitEvent("UNIT_AURA", "player")
  -- UNIT_AURA does not seem to be fired after login (even when buffs are active)
  UNIT_AURA()
end

---------------------------------------------------------------------------------------------------------------------
--  Nameplate Styler: These functions parses the definition table for a nameplate's requested style.
---------------------------------------------------------------------------------------------------------------------
do
	-- Helper Functions
	local function SetObjectShape(object, width, height)
    object:SetWidth(width)
    object:SetHeight(height)
  end

  local function SetObjectJustify(object, horz, vert)
    local align_horz, align_vert = object:GetJustifyH(), object:GetJustifyV()
    if align_horz ~= horz or align_vert ~= vert then
      object:SetJustifyH(horz)
      object:SetJustifyV(vert)

      -- Set text to nil to enforce text string update, otherwise updates to justification will not take effect
      local text = object:GetText()
      object:SetText(nil)
      object:SetText(text)
    end
  end

  local function SetObjectAnchor(object, anchor, anchorTo, x, y)
    object:ClearAllPoints()
    object:SetPoint(anchor, anchorTo, anchor, x, y)
  end

  local function SetObjectTexture(object, texture)
    object:SetTexture(texture)
  end

  local function SetObjectBartexture(obj, tex, ori, crop)
    obj:SetStatusBarTexture(tex)
    obj:SetOrientation(ori)
  end

	local function SetObjectFont(object,  font, size, flags)
		object:SetFont(font, size or 10, flags)
	end

	-- SetObjectShadow:
	local function SetObjectShadow(object, shadow)
		if shadow then
			object:SetShadowColor(0,0,0, 1)
			object:SetShadowOffset(1, -1)
		else
      object:SetShadowColor(0,0,0,0)
    end
	end

	-- SetFontGroupObject
	local function SetFontGroupObject(object, objectstyle)
		if objectstyle then
      SetObjectFont(object, objectstyle.typeface, objectstyle.size, objectstyle.flags)
      SetObjectJustify(object, objectstyle.align or "CENTER", objectstyle.vertical or "BOTTOM")
      SetObjectShadow(object, objectstyle.shadow)
		end
	end

	-- SetAnchorGroupObject
	local function SetAnchorGroupObject(object, objectstyle, anchorTo)
		if objectstyle and anchorTo then
			SetObjectShape(object, objectstyle.width or 128, objectstyle.height or 16) --end
			SetObjectAnchor(object, objectstyle.anchor or "CENTER", anchorTo, objectstyle.x or 0, objectstyle.y or 0)
		end
	end

	-- SetTextureGroupObject
	local function SetTextureGroupObject(object, objectstyle)
		if objectstyle then
			if objectstyle.texture then
        SetObjectTexture(object, objectstyle.texture or EMPTY_TEXTURE)
      end
			object:SetTexCoord(objectstyle.left or 0, objectstyle.right or 1, objectstyle.top or 0, objectstyle.bottom or 1)
		end
	end

	-- Style Groups
	local fontgroup = {"name", "level", "customtext"}
  -- "spelltext",

	local anchorgroup = {
		"name",  "spelltext", "customtext", "level", "spellicon", "raidicon", "skullicon"
    -- "threatborder", "castborder", "castnostop", "eliteicon", "target"
  }

	local texturegroup = {
    "skullicon", "spellicon",
    -- "highlight", threatborder, "castborder", "castnostop", "eliteicon", "target"
  }

	-- UpdateStyle:
	function UpdateStyle()
		local index

    -- Frame
    SetObjectAnchor(extended, style.frame.anchor or "CENTER", nameplate, style.frame.x or 0, style.frame.y or 0)
    extended:SetSize(style.healthbar.width, style.healthbar.height)

    -- Anchorgroup
		for index = 1, #anchorgroup do
			local objectname = anchorgroup[index]
			local object, objectstyle = visual[objectname], style[objectname]

			if objectstyle and objectstyle.show then
				SetAnchorGroupObject(object, objectstyle, extended)
				visual[objectname]:Show()
			else
        visual[objectname]:Hide()
      end
		end

    -- Font Group
    for index = 1, #fontgroup do
      local objectname = fontgroup[index]
      local object, objectstyle = visual[objectname], style[objectname]

      SetFontGroupObject(object, objectstyle)
    end

    local db = Addon.db.profile.settings

    -- Healthbar
		SetAnchorGroupObject(visual.healthbar, style.healthbar, extended)
    visual.healthbar:UpdateLayout(db, style)

    -- Castbar
    SetAnchorGroupObject(visual.castbar, style.castbar, extended)
    visual.castbar:UpdateLayout(db, style)
    -- Set castbar color here otherwise it may be shown sometimes with non-initialized backdrop color (white)
    if visual.castbar:IsShown() then
      visual.castbar:SetAllColors(Addon:SetCastbarColor(unit))
    end

    -- Texture
    for index = 1, #texturegroup do
      local objectname = texturegroup[index]
      local object, objectstyle = visual[objectname], style[objectname]

      SetTextureGroupObject(object, objectstyle)
    end
    Addon:Element_Mouseover_Configure(visual.Highlight, style.highlight)

    -- Show certain elements, don't change anything else
--		for index = 1, #showgroup do
--			local objectname = showgroup[index]
--			visual[objectname]:SetShown(style[objectname].show)
--		end
    visual.threatborder:SetShown(style.threatborder.show)

    -- Raid Icon Texture
		if style.raidicon and style.raidicon.texture then
			visual.raidicon:SetTexture(style.raidicon.texture)
    end
    -- TOODO: does not really work with ForceUpdate() as isMarked is not set there (no call to UpdateUnitCondition)
    if not unit.isMarked then
      visual.raidicon:Hide()
    end

    db = Addon.db.profile.settings.castbar

    visual.castbar:ClearAllPoints()
    if UnitIsUnit("target", unit.unitid) then
      SetObjectAnchor(visual.castbar, style.castbar.anchor or "CENTER", extended, style.castbar.x + db.x_target or 0, style.castbar.y + db.y_target or 0)
    else
      SetObjectAnchor(visual.castbar, style.castbar.anchor or "CENTER", extended, style.castbar.x or 0, style.castbar.y or 0)
    end

    -- Spell name
    SetFontGroupObject(visual.spelltext, style.spelltext)
    SetObjectShape(visual.spelltext, style.spelltext.width, style.spelltext.height)
    visual.spelltext:ClearAllPoints()
    visual.spelltext:SetPoint("CENTER", visual.castbar, "CENTER", db.SpellNameText.HorizontalOffset, db.SpellNameText.VerticalOffset)
    visual.spelltext:SetShown(style.spelltext.show)

    -- Remaining cast time
    SetObjectFont(visual.castbar.casttime, style.spelltext.typeface, style.spelltext.size, style.spelltext.flags)
    SetObjectJustify(visual.castbar.casttime, db.CastTimeText.Font.HorizontalAlignment, db.CastTimeText.Font.VerticalAlignment)
    SetObjectShadow(visual.castbar.casttime, style.spelltext.shadow)
    visual.castbar.casttime:SetSize(visual.castbar:GetSize())
    visual.castbar.casttime:ClearAllPoints()
    visual.castbar.casttime:SetPoint("CENTER", visual.castbar, "CENTER", db.CastTimeText.HorizontalOffset, db.CastTimeText.VerticalOffset)
    visual.castbar.casttime:SetShown(db.ShowCastTime)

    Addon.UpdateStyleForStatusText(extended, unit)

    -- Hide Stuff
    if style.eliteicon and style.eliteicon.show then
      SetAnchorGroupObject(visual.eliteicon, style.eliteicon, extended)
    end
    SetTextureGroupObject(visual.eliteicon, style.eliteicon)
    UpdateIndicator_EliteIcon()

		if not unit.isBoss then visual.skullicon:Hide() end
  end
end

--------------------------------------------------------------------------------------------------------------
-- Misc. Utility
--------------------------------------------------------------------------------------------------------------

-- Blizzard default nameplates always have the same size, no matter what the UI scale actually is
function Addon:UIScaleChanged()
  local db = Addon.db.profile.Scale
  if db.IgnoreUIScale then
    self.UIScale = 1  -- Code for anchoring TPFrame to WorldFrame/Blizzard nameplate instead of UIParent
    --self.UIScale = 1 / UIParent:GetEffectiveScale()
  else
    --self.UIScale = 1
    self.UIScale = UIParent:GetEffectiveScale() -- Code for anchoring TPFrame to WorldFrame/Blizzard nameplate instead of UIParent

    if db.PixelPerfectUI then
      local physicalScreenHeight = select(2, GetPhysicalScreenSize())
      self.UIScale = 768.0 / physicalScreenHeight
    end
  end
end

local ConfigModePlate

function Addon:ConfigClickableArea(toggle_show)
  if toggle_show then
    if ConfigModePlate then
      local extended = ConfigModePlate.TPFrame

      extended.Background:Hide()
      extended.Background = nil
      extended:SetScript('OnHide', nil)

      ConfigModePlate = nil
    else
      ConfigModePlate = GetNamePlateForUnit("target")
      if ConfigModePlate then
        local extended = ConfigModePlate.TPFrame

        -- Draw background to show for clickable area
        extended.Background = _G.CreateFrame("Frame", nil, ConfigModePlate, BackdropTemplate)
        extended.Background:SetBackdrop({
          bgFile = ThreatPlates.Art .. "TP_WhiteSquare.tga",
          edgeFile = ThreatPlates.Art .. "TP_WhiteSquare.tga",
          edgeSize = 2,
          insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        extended.Background:SetBackdropColor(0,0,0,.3)
        extended.Background:SetBackdropBorderColor(0, 0, 0, 0.8)
        extended.Background:SetPoint("CENTER", ConfigModePlate.UnitFrame, "CENTER")

        local width, height
        if extended.unit.reaction == "FRIENDLY" then          
          width, height = C_NamePlate.GetNamePlateFriendlySize()
        else
          width, height = C_NamePlate.GetNamePlateEnemySize()
        end
        extended.Background:SetSize(width, height)

        extended.Background:Show()

        -- remove the config background if the nameplate is hidden to prevent it
        -- from being shown again when the nameplate is reused at a later date
        extended:HookScript('OnHide', function(self)
          self.Background:Hide()
          self.Background = nil
          self:SetScript('OnHide', nil)
          ConfigModePlate = nil
        end)
      else
        Addon.Logging.Warning("Please select a target unit to enable configuration mode.")
      end
    end
  elseif ConfigModePlate then
    local background = ConfigModePlate.TPFrame.Background
    background:SetPoint("CENTER", ConfigModePlate.UnitFrame, "CENTER")
    background:SetSize(Addon.db.profile.settings.frame.width, Addon.db.profile.settings.frame.height)
  end
end

--------------------------------------------------------------------------------------------------------------
-- External Commands: Allows widgets and themes to request updates to the plates.
-- Useful to make a theme respond to externally-captured data (such as the combat log)
--------------------------------------------------------------------------------------------------------------
function Addon:DisableCastBars() ShowCastBars = false end
function Addon:EnableCastBars() ShowCastBars = true end

function Addon:ForceUpdate()
  wipe(PlateOnUpdateQueue)

  -- Clear cache for texts as e.g., abbreviation mode might have changed
  wipe(Addon.Cache.Texts)
  Addon:UpdateConfigurationLocalization()
  Addon:UpdateConfigurationStatusText()

  CVAR_NameplateOccludedAlphaMult = CVars:GetAsNumber("nameplateOccludedAlphaMult")

  local db = Addon.db.profile

  SettingsShowFriendlyBlizzardNameplates = db.ShowFriendlyBlizzardNameplates
  SettingsShowEnemyBlizzardNameplates = db.ShowEnemyBlizzardNameplates
  SettingsHideBuffsOnPersonalNameplate = db.PersonalNameplate.HideBuffs  -- Check for Addon.WOW_USES_CLASSIC_NAMEPLATES not necessary as there is no player nameplate with classic nameplates

  if db.Transparency.Fading then
    UpdatePlate_SetAlpha = UpdatePlate_SetAlphaWithFading
    UpdatePlate_SetAlphaOnUpdate = UpdatePlate_SetAlphaWithFadingOcclusionOnUpdate
  else
    UpdatePlate_SetAlpha = UpdatePlate_SetAlphaNoFading
    UpdatePlate_SetAlphaOnUpdate = UpdatePlate_SetAlphaNoFadingOcclusionOnUpdate
  end

  SettingsEnabledOccludedAlpha = db.nameplate.toggle.OccludedUnits
  SettingsOccludedAlpha = db.nameplate.alpha.OccludedUnits

  if SettingsEnabledOccludedAlpha then
    UpdatePlate_Transparency = UpdatePlate_SetAlphaWithOcclusion
    PlateOnUpdateQueue[#PlateOnUpdateQueue + 1] = UpdatePlate_SetAlphaOnUpdate
  else
    UpdatePlate_Transparency = UpdatePlate_SetAlpha
  end

  SettingsTargetUnitHide = not db.settings.healthbar.TargetUnit.Show
  SettingsShowOnlyForTarget = db.settings.healthbar.TargetUnit.ShowOnlyForTarget
  if SettingsTargetUnitHide then
    TidyPlatesCore:UnregisterEvent("UNIT_TARGET")
  else
    TidyPlatesCore:RegisterEvent("UNIT_TARGET")
  end

  SettingsShowOnlyNames = CVars:GetAsBool("nameplateShowOnlyNames") and Addon.db.profile.BlizzardSettings.Names.Enabled
  
  for plate, unitid in pairs(self.PlatesVisible) do
    -- If Blizzard default plates are enabled (which means that these nameplates are not active), we need
    -- to check if they are enabled, so that Active is set correctly and plates are updated shown correctly.
    if not plate.TPFrame.Active then
      Addon:UpdateNameplateStyle(plate, unitid)
    end

    if plate.TPFrame.Active then
      OnResetNameplate(plate)
    end
  end
end

function Addon:ForceUpdateOnNameplate(plate)
  OnResetNameplate(plate)
end

function Addon:ForceUpdateFrameOnShow()
  SettingsShowOnlyNames = CVars:GetAsBool("nameplateShowOnlyNames") and Addon.db.profile.BlizzardSettings.Names.Enabled
  for plate, _ in pairs(Addon.PlatesVisible) do
    ClassicBlizzardNameplatesSetAlpha(plate.UnitFrame, SettingsShowOnlyNames and 0 or 1)
  end
end