local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------------------------
-- Variables and References
---------------------------------------------------------------------------------------------------------------------
local TidyPlatesCore = CreateFrame("Frame", nil, WorldFrame)

-- Local References
local _
local max, gsub, tonumber = math.max, string.gsub, tonumber
local select, pairs, tostring  = select, pairs, tostring 			    -- Local function copy

-- WoW APIs
local wipe = wipe
local WorldFrame, UIParent, CreateFrame, INTERRUPTED = WorldFrame, UIParent, CreateFrame, INTERRUPTED
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local UnitName, UnitIsUnit, UnitReaction, UnitExists = UnitName, UnitIsUnit, UnitReaction, UnitExists
local UnitClassification = UnitClassification
local UnitLevel = UnitLevel
local UnitIsPlayer = UnitIsPlayer
local UnitClass, UnitBuff = UnitClass, UnitBuff
local UnitGUID = UnitGUID
local GetCreatureDifficultyColor = GetCreatureDifficultyColor
local UnitSelectionColor = UnitSelectionColor
local UnitAffectingCombat = UnitAffectingCombat
local GetRaidTargetIndex = GetRaidTargetIndex
local UnitIsTapDenied = UnitIsTapDenied
local GetTime = GetTime
local UnitPlayerControlled = UnitPlayerControlled
local GetCVar, Lerp, CombatLogGetCurrentEventInfo = GetCVar, Lerp, CombatLogGetCurrentEventInfo
local GetPlayerInfoByGUID, RAID_CLASS_COLORS = GetPlayerInfoByGUID, RAID_CLASS_COLORS

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local Widgets = Addon.Widgets
local Animations = Addon.Animations
local LibThreatClassic = Addon.LibThreatClassic
local LibClassicCasterino = Addon.LibClassicCasterino
--local RMH_GetCreatureIDFromKey = RealMobHealth.GetCreatureIDFromKey

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
local LastTargetPlate
local ShowCastBars = true
local EMPTY_TEXTURE = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Empty"
local UpdateAll = false

local PlateOnUpdateQueue = {}

-- Cached CVARs (updated on every PLAYER_ENTERING_WORLD event
local CVAR_NameplateOccludedAlphaMult
-- Cached database settings
local SettingsEnabledFading
local SettingsOccludedAlpha, SettingsEnabledOccludedAlpha
local SettingsShowEnemyBlizzardNameplates, SettingsShowFriendlyBlizzardNameplates

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

local UpdateIndicator_CustomText, UpdateIndicator_CustomScale, UpdateIndicator_CustomScaleText, UpdateIndicator_Standard
local UpdateIndicator_Level, UpdateIndicator_RaidIcon
local UpdateIndicator_EliteIcon, UpdateIndicator_Name
local UpdateIndicator_HealthBar
local OnStartCasting, OnStopCasting, OnUpdateCastMidway

-- Event Functions
local OnNewNameplate, OnShowNameplate, OnUpdateNameplate, OnResetNameplate
local OnHealthUpdate, ProcessUnitChanges

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
--  Nameplate Extension: Applies scripts, hooks, and adds additional frame variables and regions
---------------------------------------------------------------------------------------------------------------------
do

	function OnNewNameplate(plate)
    -- Parent could be: WorldFrame, UIParent, plate
    local extended = CreateFrame("Frame",  "ThreatPlatesFrame" .. plate:GetName():gsub("NamePlate", "Plate"), WorldFrame)
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
    local textframe = CreateFrame("Frame", nil, extended)

		textframe:SetAllPoints()
    textframe:SetFrameLevel(extended:GetFrameLevel() + 6)

    --extended.widgetParent = widgetParent
		visual.healthbar = healthbar
		visual.castbar = castbar
    visual.textframe = textframe

		-- Parented to Health Bar - Lower Frame
    visual.threatborder = healthbar.ThreatBorder
    visual.healthborder = healthbar.Border
    visual.eliteborder = healthbar.EliteBorder

    -- Parented to Extended - Middle Frame
    visual.raidicon = textframe:CreateTexture(nil, "ARTWORK", 5)
    visual.skullicon = textframe:CreateTexture(nil, "ARTWORK", 2)
    visual.eliteicon = textframe:CreateTexture(nil, "ARTWORK", 1)

		-- TextFrame
    visual.name = textframe:CreateFontString(nil, "ARTWORK", 0)
		visual.name:SetFont("Fonts\\FRIZQT__.TTF", 11)
		visual.customtext = textframe:CreateFontString(nil, "ARTWORK", -1)
		visual.customtext:SetFont("Fonts\\FRIZQT__.TTF", 11)
		visual.level = textframe:CreateFontString(nil, "ARTWORK", -2)
		visual.level:SetFont("Fonts\\FRIZQT__.TTF", 11)

		-- Cast Bar Frame - Highest Frame
		visual.castborder = castbar.Border
		visual.spellicon = castbar.Overlay:CreateTexture(nil, "ARTWORK", 7)
		visual.spelltext = castbar.Overlay:CreateFontString(nil, "OVERLAY")
		visual.spelltext:SetFont("Fonts\\FRIZQT__.TTF", 11)
    visual.spelltext:SetWordWrap(false)

    visual.Highlight = Addon:Element_Mouseover_Create(extended)

    -- Set Base Properties
		-- visual.raidicon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")

    extended.widgets = {}

		--Addon:CreateExtensions(extended)
    Addon.Widgets:OnPlateCreated(extended)

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
    stylename = Addon:SetStyle(unit)
    extended.style = activetheme[stylename]

		style = extended.style

		if style and (extended.stylename ~= stylename) then
      UpdateStyle()
			extended.stylename = stylename
			unit.style = stylename

      --Addon:CreateExtensions(extended, unit.unitid, stylename)
      -- TOOD: optimimze that - call OnUnitAdded only when the plate is initialized the first time for a unit, not if only the style changes
      Widgets:OnUnitAdded(extended, unit)
      --Addon:WidgetsModeChanged(extended, unit)
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
  end

	-- OnShowNameplate
	function OnShowNameplate(plate, unitid)
    UpdateReferences(plate)

    Addon:UpdateUnitIdentity(unit, unitid)

    unit.name, _ = UnitName(unitid)
    unit.IsInterrupted = false

    extended.stylename = ""

    extended.IsOccluded = false
    extended.CurrentAlpha = nil
    extended:SetAlpha(0)

    PlatesVisible[plate] = unitid
    PlatesByUnit[unitid] = plate
    PlatesByGUID[unit.guid] = plate

    Addon:UpdateUnitContext(unit, unitid)
    Addon:UnitStyle_NameDependent(unit)
    ProcessUnitChanges()

		--Addon:UpdateExtensions(extended, unit.unitid, stylename)

    Addon:UpdateNameplateStyle(nameplate, unitid)

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

-- GetUnitReaction: Determines the reaction, and type of unit from the health bar color
local function GetReactionByColor(red, green, blue)
  if red < .1 then 	-- Friendly
    return "FRIENDLY"
  elseif red > .5 then
    if green > .9 then return "NEUTRAL"
    else return "HOSTILE" end
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
  unit.guid = UnitGUID(unitid)

  unit.classification = UnitClassification(unitid)
  unit.isElite = EliteReference[unit.classification] or false
  unit.isRare = RareReference[unit.classification] or false
  unit.isMini = unit.classification == "minus"

  unit.isBoss = UnitLevel(unitid) == -1
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
  end
end

-- UpdateUnitContext: Updates Target/Mouseover
function Addon:UpdateUnitContext(unit, unitid)
  unit.isMouseover = UnitIsUnit("mouseover", unitid)
  unit.isTarget = UnitIsUnit("target", unitid) -- required here for config changes which reset all plates without calling TARGET_CHANGED, MOUSEOVER, ...

  Addon:UpdateUnitCondition(unit, unitid)	-- This updates a bunch of properties
end

-- UpdateUnitCondition: High volatility data
function Addon:UpdateUnitCondition(unit, unitid)
  unit.level = UnitLevel(unitid)

  local c = GetCreatureDifficultyColor(unit.level)
  unit.levelcolorRed, unit.levelcolorGreen, unit.levelcolorBlue = c.r, c.g, c.b

  unit.red, unit.green, unit.blue = UnitSelectionColor(unitid)

  unit.reaction = GetReactionByColor(unit.red, unit.green, unit.blue) or "HOSTILE"
  -- Enemy players turn to neutral, e.g., when mounting a flight path mount, so fix reaction in that situations
  if unit.reaction == "NEUTRAL" and (unit.type == "PLAYER" or UnitPlayerControlled(unitid)) then
    unit.reaction = "HOSTILE"
  end

  unit.health, unit.healthmax = Addon.GetUnitHealth(unitid)

  unit.threatValue = LibThreatClassic:UnitThreatSituation("player", unitid) or 0
  unit.threatSituation = ThreatReference[unit.threatValue]
  unit.isInCombat = UnitAffectingCombat(unitid)

  local raidIconIndex = GetRaidTargetIndex(unitid)

  if raidIconIndex then
    unit.raidIcon = RaidIconList[raidIconIndex]
    unit.isMarked = true
  else
    unit.isMarked = false
  end

  unit.isTapped = UnitIsTapDenied(unitid)
end

---------------------------------------------------------------------------------------------------------------------
-- Indicators: These functions update the color, texture, strings, and frames within a style.
---------------------------------------------------------------------------------------------------------------------

-- Update the health bar and name coloring, if needed
function Addon:UpdateIndicatorNameplateColor(tp_frame)
  local visual = tp_frame.visual

  if visual.healthbar:IsShown() then
    visual.healthbar:SetAllColors(Addon:SetHealthbarColor(tp_frame.unit))

    -- Updates warning glow for threat
    if visual.threatborder:IsShown() then
      visual.threatborder:SetBackdropBorderColor(Addon:SetThreatColor(tp_frame.unit))
    end
  end

  if visual.name:IsShown() then
    visual.name:SetTextColor(Addon:SetNameColor(tp_frame.unit))
  end
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
		visual.name:SetText(unit.name)
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
      visual.level:SetText(unit.level)
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
      visual.eliteicon:SetVertexColor(0.8, 0.8, 0.8)
      visual.eliteicon:SetShown(style.eliteicon.show)
      visual.eliteborder:SetBackdropBorderColor(0.8, 0.8, 0.8)
      visual.eliteborder:SetShown(style.eliteborder.show)
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

			-- Set Special-Case Regions
			if style.customtext.show then
        local text, r, g, b, a = Addon:SetCustomText(unit)
        visual.customtext:SetText( text or "")
        visual.customtext:SetTextColor(r or 1, g or 1, b or 1, a or 1)
			end

      Addon:UpdateIndicatorNameplateColor(extended)
		end
	end

  function UpdateIndicator_CustomText(tp_frame)
    local style = tp_frame.style.customtext
    local unit = tp_frame.unit
    local customtext = tp_frame.visual.customtext

    if style.show then
      local text, r, g, b, a = Addon:SetCustomText(unit)
      customtext:SetText( text or "")
      customtext:SetTextColor(r or 1, g or 1, b or 1, a or 1)
    end
  end

	-- OnShowCastbar
	function OnStartCasting(plate, unitid, channeled)
    UpdateReferences(plate)

    local castbar = extended.visual.castbar
    if not extended:IsShown() or not style.castbar.show then
      castbar:Hide()
      return
    end

    local name, icon, startTime, endTime, spellID

    if channeled then
      name, _, icon, startTime, endTime, _, _, _, spellID = LibClassicCasterino:UnitChannelInfo(unitid)
      if not startTime then
        castbar:Hide()
        return
      end

      castbar.IsChanneling = true
      castbar.IsCasting = false

      castbar.Value = (endTime / 1000) - GetTime()
      castbar.MaxValue = (endTime - startTime) / 1000
      castbar:SetMinMaxValues(0, castbar.MaxValue)
      castbar:SetValue(castbar.Value)
    else
      name, _, icon, startTime, endTime, _, _, _, spellID = LibClassicCasterino:UnitCastingInfo(unitid)
      if not startTime then
        castbar:Hide()
        return
      end

      castbar.IsCasting = true
      castbar.IsChanneling = false

      castbar.Value = GetTime() - (startTime / 1000)
      castbar.MaxValue = (endTime - startTime) / 1000
      castbar:SetMinMaxValues(0, castbar.MaxValue)
      castbar:SetValue(castbar.Value)
    end

    --if isTradeSkill then return end

    unit.isCasting = true
    unit.spellIsShielded = false -- Classic does not provide this information
    unit.spellInterruptible = not unit.spellIsShielded

    visual.spelltext:SetText(name)
    visual.spellicon:SetTexture(icon)
    --visual.spellicon:SetDrawLayer("ARTWORK", 7)

    castbar:SetAllColors(Addon:SetCastbarColor(unit))
    castbar:SetFormat(unit.spellIsShielded)

    UpdateIndicator_CustomScaleText()
    UpdatePlate_Transparency(extended, unit)

    castbar:Show()
  end

	-- OnHideCastbar
	function OnStopCasting(plate)
    UpdateReferences(plate)

    local castbar = extended.visual.castbar
    castbar.IsCasting = false
    castbar.IsChanneling = false
    unit.isCasting = false

    --UpdateIndicator_CustomScaleText()
    UpdateIndicator_CustomScale(extended, unit)
    UpdatePlate_Transparency(extended, unit)
  end

	function OnUpdateCastMidway(plate, unitid)
    if not ShowCastBars then return end

    -- Check to see if there's a spell being cast
    if LibClassicCasterino:UnitCastingInfo(unitid) then
      OnStartCasting(plate, unitid, false)
    elseif LibClassicCasterino:UnitChannelInfo(unitid) then
      OnStartCasting(plate, unitid, true)
    else
      visual.castbar:Hide()
    end
  end

end -- End Indicator section

--------------------------------------------------------------------------------------------------------------
-- WoW Event Handlers: sends event-driven changes to the appropriate gather/update handler.
--------------------------------------------------------------------------------------------------------------

do
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

  local function FrameOnShow(UnitFrame)
    -- Hide nameplates that have not yet an unit added
    if not UnitFrame.unit then
      UnitFrame:Hide()
    end

    local db = TidyPlatesThreat.db.profile

    -- Skip the personal resource bar of the player character, don't unhook scripts as nameplates, even the personal
    -- resource bar, get re-used
--    if UnitIsUnit(UnitFrame.unit, "player") then -- or: ns.PlayerNameplate == GetNamePlateForUnit(UnitFrame.unit)
--      if db.PersonalNameplate.HideBuffs then
--        UnitFrame.BuffFrame:Hide()
----      else
----        UnitFrame.BuffFrame:Show()
--      end
--      return
--    end

    -- Hide ThreatPlates nameplates if Blizzard nameplates should be shown for friendly units
    if UnitReaction(UnitFrame.unit, "player") > 4 then
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

      local unitid = plate.UnitFrame.unit
      if unitid and UnitIsUnit(unitid, "player") then
        return
      end

      plate.TPFrame:SetFrameLevel(plate:GetFrameLevel() * 10)

--    for i = 1, #PlateOnUpdateQueue do
--      PlateOnUpdateQueue[i](plate, plate.TPFrame.unit)
--    end

      if SettingsEnabledOccludedAlpha then
        UpdatePlate_SetAlphaOnUpdate(plate.TPFrame, plate.TPFrame.unit)
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

  function CoreEvents:PLAYER_ENTERING_WORLD()
		TidyPlatesCore:SetScript("OnUpdate", OnUpdate)
  end

	function CoreEvents:NAME_PLATE_CREATED(plate)
    OnNewNameplate(plate)

    if plate.UnitFrame then -- not plate.TPFrame.onShowHooked then
      plate.UnitFrame:HookScript("OnShow", FrameOnShow)
      -- TODO: Idea from ElvUI, I think
      -- plate.TPFrame.onShowHooked = true
    end

    plate:HookScript('OnHide', FrameOnHide)
    plate:HookScript('OnUpdate', FrameOnUpdate)

    Addon.PlatesCreated[plate] = plate.TPFrame
  end

	-- Payload: { Name = "unitToken", Type = "string", Nilable = false },
	function CoreEvents:NAME_PLATE_UNIT_ADDED(unitid)
    -- Player's personal resource bar is currently not handled by Threat Plates
    -- OnShowNameplate is not called on it, therefore plate.TPFrame.Active is nil
    if UnitIsUnit("player", unitid) then return end

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

    -- Remove anything from the function queue
    frame.UpdateMe = false
  end

  function CoreEvents:UNIT_NAME_UPDATE(unitid)
    if UnitIsUnit("player", unitid) then return end -- Skip personal resource bar

    local plate = GetNamePlateForUnit(unitid) -- can plate ever be nil here?

    -- Plate can be nil here, if unitid is party1, partypet4 or something like that
    if plate and plate.TPFrame.Active then
      UpdateReferences(plate)
      unit.name, _ = UnitName(unitid)

      --Addon:UnitStyle_UnitType(extended, unit)
      local plate_style = Addon:UnitStyle_NameDependent(unit)
      if plate_style ~= extended.stylename then
        -- Totem or Custom Nameplate
        ProcessUnitChanges()
      else
        -- just update the name
        UpdateIndicator_Name()
        UpdateIndicator_CustomText(extended) -- if it's an NPC, subtitle is saved by name, change that to guid/unitid
      end
    end
  end

  function CoreEvents:PLAYER_TARGET_CHANGED()
    -- Target Castbar Offset
    local visual, style, extended
    if LastTargetPlate and LastTargetPlate.TPFrame.Active then
      extended = LastTargetPlate.TPFrame
      visual = extended.visual
      style = extended.style
      visual.castbar:ClearAllPoints()
      visual.spelltext:ClearAllPoints()
      visual.castbar:SetPoint(style.castbar.anchor or "CENTER", extended, style.castbar.x or 0, style.castbar.y or 0)
      visual.spelltext:SetPoint(style.spelltext.anchor or "CENTER", extended, style.spelltext.x or 0, style.spelltext.y or 0)
      --visual.spellicon:SetPoint(style.spellicon.anchor or "CENTER", extended, style.spellicon.x or 0, style.spellicon.y or 0)

      LastTargetPlate = nil

      -- Update mouseover, if the mouse was hovering over the targeted unit
      extended.unit.isTarget = false
      CoreEvents:UPDATE_MOUSEOVER_UNIT()
    end

    local plate = GetNamePlateForUnit("target")
    --if plate and plate.TPFrame and plate.TPFrame.stylename ~= "" then
    if plate and plate.TPFrame.Active then
      extended = plate.TPFrame
      visual = extended.visual
      style = extended.style
      visual.castbar:ClearAllPoints()
      visual.spelltext:ClearAllPoints()
      local db = TidyPlatesThreat.db.profile.settings.castbar
      visual.castbar:SetPoint(style.castbar.anchor or "CENTER", extended, style.castbar.x + db.x_target or 0, style.castbar.y + db.y_target or 0)
      visual.spelltext:SetPoint(style.spelltext.anchor or "CENTER", extended, style.spelltext.x + db.x_target or 0, style.spelltext.y + db.y_target or 0)
      --visual.spellicon:SetPoint(style.spellicon.anchor or "CENTER", extended, style.spellicon.x + db.x_target or 0, style.spellicon.y + db.y_target or 0)

      LastTargetPlate = plate

      extended.unit.isTarget = true
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

  function CoreEvents:UNIT_HEALTH_FREQUENT(unitid)
    local plate = GetNamePlateForUnit(unitid)

    if plate and plate.TPFrame.Active then
      OnHealthUpdate(plate)
      --Addon:UpdateExtensions(plate.TPFrame, unitid, plate.TPFrame.stylename)
    end
	end

  function CoreEvents:UNIT_MAXHEALTH(unitid)
    local plate = GetNamePlateForUnit(unitid)

    if plate and plate.TPFrame.Active then
      OnHealthUpdate(plate)
      --Addon:UpdateExtensions(plate.TPFrame, unitid, plate.TPFrame.stylename)
    end
  end

  --function Addon.RMH_HEALTH_UPDATE(event, creatureKey, maxHealth)
  --  print ("RMH_HEALTH_UPDATE:", creatureKey, maxHealth)
  --
  --  if creatureKey then
  --    CoreEvents:UNIT_MAXHEALTH(RMH_GetCreatureIDFromKey(creatureKey))
  --  --else
  --  --  -- creatureKey and maxHealth are nil if more than one creature was affected
  --  --  SetUpdateAll()
  --  end
  --end

  -- LibThreatClassic - Event: ThreatUpdated
  function Addon.UNIT_THREAT_LIST_UPDATE(lib_name, unit_guid, target_guid, threat)
    local plate = PlatesByGUID[target_guid]
    if plate then
      local unitid = plate.TPFrame.unit.unitid
      if not unitid or unitid == "player" or unitid == "target" then return end

      --local threat_value = UnitThreatSituation("player", unitid) or 0
      --if threat_value ~= plate.TPFrame.unit.threatValue then
      if (LibThreatClassic:UnitThreatSituation("player", unitid) or 0) ~= plate.TPFrame.unit.threatValue then

        --OnHealthUpdate(plate)

        plate.UpdateMe = true

        -- TODO: Optimize this - only update elements that need updating
        -- Don't use OnHealthUpdate(), more like: OnThreatUpdate()
        -- UpdateReferences(plate)
        --Addon:UpdateUnitCondition(unit, unitid)
        --        unit.threatValue = UnitThreatSituation("player", unitid) or 0
        --        unit.threatSituation = ThreatReference[unit.threatValue]
        --        unit.isInCombat = UnitAffectingCombat(unitid)
        --ProcessUnitChanges()
        --OnUpdateCastMidway(nameplate, unit.unitid)
      end
    end
  end

  function CoreEvents:PLAYER_REGEN_ENABLED()
		SetUpdateAll()
	end

	function CoreEvents:PLAYER_REGEN_DISABLED()
		SetUpdateAll()
	end

	function Addon.UNIT_SPELLCAST_START(event, unitid)
    if UnitIsUnit("player", unitid) or unitid == "target" or not ShowCastBars then return end

    local plate = GetNamePlateForUnit(unitid)
		if plate and plate.TPFrame.Active then
      OnStartCasting(plate, unitid, false)
		end
	end

  function Addon.UnitSpellcastMidway(event, unitid)
    if UnitIsUnit("player", unitid) or unitid == "target" or not ShowCastBars then return end

    local plate = GetNamePlateForUnit(unitid)
    if plate then
      OnUpdateCastMidway(plate, unitid)
    end
   end

  function Addon.UNIT_SPELLCAST_STOP(event, unitid)
    if UnitIsUnit("player", unitid) or unitid == "target" or not ShowCastBars then return end

    -- plate can be nil, e.g., if unitid = player, combat ends and the player resource bar is already hidden
    -- when the cast stops (because it's not shown out of combat)
    local plate = GetNamePlateForUnit(unitid)
    if plate and plate.TPFrame.Active then
      OnStopCasting(plate)
    end
  end

	function Addon.UNIT_SPELLCAST_CHANNEL_START(event, unitid)
    if UnitIsUnit("player", unitid) or unitid == "target" or not ShowCastBars then return end

		local plate = GetNamePlateForUnit(unitid)
		if plate and plate.TPFrame.Active then
			OnStartCasting(plate, unitid, true)
      --late.TPFrame.visual.castbar:Show()
		end
	end

	function Addon.UNIT_SPELLCAST_CHANNEL_STOP(event, unitid)
    if UnitIsUnit("player", unitid) or unitid == "target" or not ShowCastBars then return end

    local plate = GetNamePlateForUnit(unitid)
    if plate and plate.TPFrame.Active then
      OnStopCasting(plate)
		end
	end

  function Addon.UNIT_SPELLCAST_INTERRUPTED(event, unitid, castGUID, spellID, interrupterName, interrupterGUID)
    if UnitIsUnit("player", unitid) or unitid == "target" or not ShowCastBars then return end

    local plate = GetNamePlateForUnit(unitid)
    if plate and plate.TPFrame.Active then
      if plate.TPFrame.style.castbar.show then
        UpdateReferences(plate)

        interrupterName = gsub(interrupterName, "%-[^|]+", "") -- UnitName(sourceName) only works in groups
        local _, class_id = GetPlayerInfoByGUID(interrupterGUID)
        if class_id then
          --local color_str = (RAID_CLASS_COLORS[classId] and RAID_CLASS_COLORS[classId].colorStr) or ""
          interrupterName = "|c" .. RAID_CLASS_COLORS[class_id].colorStr .. interrupterName .. "|r"
        end
        visual.spelltext:SetText(INTERRUPTED .. " [" .. interrupterName .. "]")

        local castbar = visual.castbar
        local _, max_val = castbar:GetMinMaxValues()
        castbar:SetValue(max_val)
        castbar.Spark:Hide()

        local color = TidyPlatesThreat.db.profile.castbarColorInterrupted
        castbar:SetStatusBarColor(color.r, color.g, color.b, color.a)
        castbar.FlashTime = CASTBAR_INTERRUPT_HOLD_TIME

        -- Code from OnStopCasting
        castbar.IsCasting = false
        castbar.IsChanneling = false
        unit.isCasting = false
        UpdateIndicator_CustomScale(extended, unit)
        UpdatePlate_Transparency(extended, unit)

        unit.IsInterrupted = true

        -- OnStopCasting is hiding the castbar and may be triggered before or after SPELL_INTERRUPT
        -- So we have to show the castbar again or not hide it if the interrupt message should still be shown.
        castbar:Show()
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

	--function CoreEvents:UNIT_ABSORB_AMOUNT_CHANGED(unitid)
	--	local plate = GetNamePlateForUnit(unitid)
  --
	--	if plate and plate.TPFrame.Active then
  --    local tp_frame = plate.TPFrame
  --    local unit = tp_frame.unit
  --    local unitid  = unit.unitid
  --
  --    -- As this does not use OnUpdate with OnHealthUpdate, we have to update this values here
  --    unit.health = UnitHealth(unit.unitid) or 0
  --    unit.healthmax = UnitHealthMax(unit.unitid) or 1
  --
	--		Addon:UpdateExtensions(tp_frame, unitid, tp_frame.stylename)
  --    UpdateIndicator_CustomText(tp_frame)
	--	end
  --end

  --function CoreEvents:UNIT_HEAL_ABSORB_AMOUNT_CHANGED(unitid)
  --  local plate = GetNamePlateForUnit(unitid)
  --
  --  if plate and plate.TPFrame.Active then
  --    Addon:UpdateExtensions(plate.TPFrame, unitid, plate.TPFrame.stylename)
  --  end
  --end

  -- Update all elements that depend on the unit's reaction towards the player
  function CoreEvents:UNIT_FACTION(unitid)
    if unitid == "player" then
      SetUpdateAll() -- Update all plates
    else
      -- Update just the unitid's plate
      local plate = GetNamePlateForUnit(unitid)
      if plate and plate.TPFrame.Active then
        UpdateReferences(plate)
        Addon:UpdateUnitCondition(unit, unitid)
        ProcessUnitChanges()
      end
    end
  end

  local RIGHTEOUS_FURY_SPELL_IDs = { 20468, 20469, 20470, 25780 }

  -- Only registered for player unit
  function CoreEvents:UNIT_AURA(unitid)
    local _, name, spellId
    for i = 1, 40 do
      name , _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i, "PLAYER")
      if not name then
        break
      elseif spellId == 25780 then --RIGHTEOUS_FURY_SPELL_IDs[spellId] then
        Addon.PlayerIsPaladinTank = true
        return
      end
    end

    Addon.PlayerIsPaladinTank = false
  end

  -- The following events should not have worked before adjusting UnitSpellcastMidway
--	CoreEvents.UNIT_SPELLCAST_DELAYED = UnitSpellcastMidway
--	CoreEvents.UNIT_SPELLCAST_CHANNEL_UPDATE = UnitSpellcastMidway
	--CoreEvents.UNIT_SPELLCAST_INTERRUPTIBLE = UnitSpellcastMidway
	--CoreEvents.UNIT_SPELLCAST_NOT_INTERRUPTIBLE = UnitSpellcastMidway
  -- UNIT_SPELLCAST_FAILED
  -- UNIT_SPELLCAST_INTERRUPTED

	CoreEvents.UNIT_LEVEL = UnitConditionChanged
	--CoreEvents.UNIT_THREAT_SITUATION_UPDATE = UnitConditionChanged -- did not work anyway (no unitid)
  CoreEvents.RAID_TARGET_UPDATE = WorldConditionChanged
	--CoreEvents.PLAYER_FOCUS_CHANGED = WorldConditionChanged
	CoreEvents.PLAYER_CONTROL_LOST = WorldConditionChanged
	CoreEvents.PLAYER_CONTROL_GAINED = WorldConditionChanged

	-- Registration of Blizzard Events
	TidyPlatesCore:SetFrameStrata("TOOLTIP") 	-- When parented to WorldFrame, causes OnUpdate handler to run close to last
	TidyPlatesCore:SetScript("OnEvent", EventHandler)
	for eventName in pairs(CoreEvents) do TidyPlatesCore:RegisterEvent(eventName) end

  if Addon.PlayerClass == "PALADIN" then
    TidyPlatesCore:RegisterUnitEvent("UNIT_AURA", "player")
  end
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
	local fontgroup = {"name", "level", "spelltext", "customtext"}

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

--    if not extended.TestBackground then
--      extended.TestBackground = extended:CreateTexture(nil, "BACKGROUND")
--      extended.TestBackground:SetAllPoints(extended)
--      extended.TestBackground:SetTexture(ThreatPlates.Media:Fetch('statusbar', TidyPlatesThreat.db.profile.AuraWidget.BackgroundTexture))
--      extended.TestBackground:SetVertexColor(0,0,0,0.5)
--    end

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

    -- Healthbar
		SetAnchorGroupObject(visual.healthbar, style.healthbar, extended)
		visual.healthbar:SetHealthBarTexture(style.healthbar)
		visual.healthbar:SetStatusBarBackdrop(style.healthbar.backdrop, style.healthborder.texture, style.healthborder.edgesize, style.healthborder.offset)
		visual.healthborder:SetShown(style.healthborder.show)
    visual.healthbar:SetEliteBorder(style.eliteborder.texture)

    -- Castbar
    SetAnchorGroupObject(visual.castbar, style.castbar, extended)
    visual.castbar:SetStatusBarTexture(style.castbar.texture or EMPTY_TEXTURE)
    visual.castbar:SetStatusBarBackdrop(style.castbar.backdrop, style.castborder.texture, style.castborder.edgesize, style.castborder.offset)
    visual.castborder:SetShown(style.castborder.show)
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
      visual.raidicon:SetDrawLayer("ARTWORK", 5)
    end
    -- TOODO: does not really work with ForceUpdate() as isMarked is not set there (no call to UpdateUnitCondition)
    if not unit.isMarked then
      visual.raidicon:Hide()
    end

    visual.castbar:ClearAllPoints()
    visual.spelltext:ClearAllPoints()
    --visual.spellicon:ClearAllPoints()

    if UnitIsUnit("target", unit.unitid) then
      local db = TidyPlatesThreat.db.profile.settings.castbar
      SetObjectAnchor(visual.castbar, style.castbar.anchor or "CENTER", extended, style.castbar.x + db.x_target or 0, style.castbar.y + db.y_target or 0)
      SetObjectAnchor(visual.spelltext, style.spelltext.anchor or "CENTER", extended, style.spelltext.x + db.x_target or 0, style.spelltext.y + db.y_target or 0)
      --SetObjectAnchor(visual.spellicon, style.spellicon.anchor or "CENTER", extended, style.spellicon.x + db.x_target or 0, style.spellicon.y + db.y_target or 0)
    else
      SetObjectAnchor(visual.castbar, style.castbar.anchor or "CENTER", extended, style.castbar.x or 0, style.castbar.y or 0)
      SetObjectAnchor(visual.spelltext, style.spelltext.anchor or "CENTER", extended, style.spelltext.x or 0, style.spelltext.y or 0)
      --SetObjectAnchor(visual.spellicon, style.spellicon.anchor or "CENTER", extended, style.spellicon.x or 0, style.spellicon.y or 0)
    end

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
  local db = TidyPlatesThreat.db.profile.Scale
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
        extended.Background = CreateFrame("Frame", nil, plate)
        extended.Background:SetBackdrop({
          bgFile = ThreatPlates.Art .. "TP_WhiteSquare.tga",
          edgeFile = ThreatPlates.Art .. "TP_WhiteSquare.tga",
          edgeSize = 2,
          insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        extended.Background:SetBackdropColor(0,0,0,.3)
        extended.Background:SetBackdropBorderColor(0, 0, 0, 0.8)
        extended.Background:SetPoint("CENTER", ConfigModePlate.UnitFrame, "CENTER")
        extended.Background:SetSize(TidyPlatesThreat.db.profile.settings.frame.width, TidyPlatesThreat.db.profile.settings.frame.height)
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
        ThreatPlates.Print("Please select a target unit to enable configuration mode.", true)
      end
    end
  elseif ConfigModePlate then
    local background = ConfigModePlate.TPFrame.Background
    background:SetPoint("CENTER", ConfigModePlate.UnitFrame, "CENTER")
    background:SetSize(TidyPlatesThreat.db.profile.settings.frame.width, TidyPlatesThreat.db.profile.settings.frame.height)
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

  Addon:UpdateConfigurationStatusText()

  CVAR_NameplateOccludedAlphaMult = tonumber(GetCVar("nameplateOccludedAlphaMult"))

  local db = TidyPlatesThreat.db.profile

  SettingsShowFriendlyBlizzardNameplates = db.ShowFriendlyBlizzardNameplates
  SettingsShowEnemyBlizzardNameplates = db.ShowEnemyBlizzardNameplates

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

  for plate in pairs(self.PlatesVisible) do
    if plate.TPFrame.Active then
      OnResetNameplate(plate)
    end
  end
end

function Addon:ForceUpdateOnNameplate(plate)
  OnResetNameplate(plate)
end