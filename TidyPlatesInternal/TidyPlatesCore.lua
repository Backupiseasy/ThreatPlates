local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------------------------
-- Variables and References
---------------------------------------------------------------------------------------------------------------------
local TidyPlatesCore = CreateFrame("Frame", nil, WorldFrame)
TidyPlatesInternal = {}

-- Local References
local _
local max, tonumber = math.max, tonumber
local select, pairs, tostring  = select, pairs, tostring 			    -- Local function copy
local CreateTidyPlatesInternalStatusbar = CreateTidyPlatesInternalStatusbar			    -- Local function copy

-- WoW APIs
local wipe = wipe
local WorldFrame, UIParent, CreateFrame, GameFontNormal, UNKNOWNOBJECT, INTERRUPTED = WorldFrame, UIParent, CreateFrame, GameFontNormal, UNKNOWNOBJECT, INTERRUPTED
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local UnitName, UnitIsUnit, UnitReaction, UnitExists = UnitName, UnitIsUnit, UnitReaction, UnitExists
local UnitPVPName = UnitPVPName
local UnitClassification = UnitClassification
local UnitLevel = UnitLevel
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitEffectiveLevel = UnitEffectiveLevel
local GetCreatureDifficultyColor = GetCreatureDifficultyColor
local UnitSelectionColor = UnitSelectionColor
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitThreatSituation = UnitThreatSituation
local UnitAffectingCombat = UnitAffectingCombat
local GetRaidTargetIndex = GetRaidTargetIndex
local UnitIsTapDenied = UnitIsTapDenied
local GetTime = GetTime
local UnitChannelInfo, UnitCastingInfo = UnitChannelInfo, UnitCastingInfo
local UnitPlayerControlled = UnitPlayerControlled
local GetCVar, Lerp = GetCVar, Lerp

-- Internal Data
local Plates, PlatesFading = {}, {}	            	-- Plate Lists
local PlatesVisible, PlatesByUnit, PlatesByGUID = {}, {}, {}
local nameplate, extended, visual			    	-- Temp/Local References
local unit, unitcache, style, stylename, unitchanged	    			-- Temp/Local References
local numChildren = -1                                                              -- Cache the current number of plates
local activetheme = {}                                                              -- Table Placeholder
local InCombat, HasTarget, HasMouseover = false, false, false					    -- Player State Data
local LastTargetPlate
local EnableFadeIn = true
local ShowCastBars = true
local EMPTY_TEXTURE = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Empty"
local ResetPlates, UpdateAll = false, false
local OverrideFonts = false

-- External references to internal data
Addon.PlatesVisible = PlatesVisible
Addon.PlatesByUnit = PlatesByUnit
Addon.PlatesByGUID = PlatesByGUID

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

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

-- Constants
local CASTBAR_FLASH_DURATION = 1.2
--local CASTBAR_FLASH_MIN_ALPHA = 0.4

---------------------------------------------------------------------------------------------------------------------
-- Core Function Declaration
---------------------------------------------------------------------------------------------------------------------
-- Helpers
local function ClearIndices(t) if t then for i,v in pairs(t) do t[i] = nil end return t end end
local function IsPlateShown(plate) return plate and plate:IsShown() end

-- Queueing
local function SetUpdateMe(plate) plate.UpdateMe = true end
local function SetUpdateAll() UpdateAll = true end
local function SetUpdateHealth(source) source.parentPlate.UpdateHealth = true end

-- Overriding
local function BypassFunction() return true end
local ShowBlizzardPlate		-- Holder for later

-- Style
local UpdateStyle

-- Indicators
local UpdateIndicator_CustomScaleText, UpdateIndicator_Standard, UpdateIndicator_CustomAlpha
local UpdateIndicator_Level, UpdateIndicator_ThreatGlow, UpdateIndicator_RaidIcon
local UpdateIndicator_EliteIcon, UpdateIndicator_UnitColor, UpdateIndicator_Name
local UpdateIndicator_HealthBar, UpdateIndicator_Target
local OnUpdateCasting, OnStartCasting, OnStopCasting, OnUpdateCastMidway

-- Event Functions
local OnNewNameplate, OnShowNameplate, OnHideNameplate, OnUpdateNameplate, OnResetNameplate
local OnHealthUpdate, UpdateUnitCondition
local UpdateUnitContext, UpdateUnitIdentity

-- Main Loop
local OnUpdate
local ForEachPlate

-- UpdateReferences
local function UpdateReferences(plate)
	nameplate = plate
	extended = plate.TPFrame

	unit = extended.unit
	unitcache = extended.unitcache
	visual = extended.visual
	style = extended.style
end

---------------------------------------------------------------------------------------------------------------------
-- Nameplate Detection & Update Loop
---------------------------------------------------------------------------------------------------------------------

do
	-- Local References
	local WorldGetNumChildren, WorldGetChildren = WorldFrame.GetNumChildren, WorldFrame.GetChildren

	-- ForEachPlate
	function ForEachPlate(functionToRun, ...)
		for plate in pairs(PlatesVisible) do
			if plate.TPFrame.Active then
				functionToRun(plate, ...)
			end
		end
	end

  -- OnUpdate; This function is run frequently, on every clock cycle
	function OnUpdate(self, e)
		-- Poll Loop
    local plate, curChildren

    -- Detect when cursor leaves the mouseover unit
		if HasMouseover and not UnitExists("mouseover") then
			HasMouseover = false
			SetUpdateAll()
		end

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

	-- ApplyPlateExtesion
	function OnNewNameplate(plate)
    -- Tidy Plates Frame
    --------------------------------
    plate.TPFrame = CreateFrame("Frame",  "ThreatPlatesFrame" .. numChildren, UIParent)

    local extended = plate.TPFrame
    extended:EnableMouse(false)
    extended:SetAllPoints(plate)
    extended:SetFrameStrata("BACKGROUND")

		-- Add Graphical Elements
		local visual = {}

    -- Status Bars
    local castbar = Addon:CreateCastbar(extended)

    --    extended.FadeOut = extended:CreateAnimationGroup()
--    local anim = extended.FadeOut:CreateAnimation("Alpha")
--    anim:SetOrder(1)
--    --anim:SetFromAlpha(1)
--    anim:SetToAlpha(0)
--    anim:SetDuration(1)
--    anim = extended.FadeOut:CreateAnimation("Scale")
--    anim:SetOrder(2)
--    anim:SetFromScale(1, 1)
--    anim:SetToScale(0.5, 0.5)
--    anim:SetDuration(1)
--    extended.FadeOut:SetScript("OnFinished", function(self)
--      extended:Hide()
--    end)
--
--    extended.FadeIn = extended:CreateAnimationGroup()
--    local anim = extended.FadeIn:CreateAnimation("Alpha")
--    anim:SetOrder(1)
--    anim:SetFromAlpha(0)
--    anim:SetToAlpha(1)
--    anim:SetDuration(1)
--    anim = extended.FadeIn:CreateAnimation("Scale")
--    anim:SetOrder(2)
--    anim:SetFromScale(0, 0)
--    anim:SetToScale(1, 1)
--    anim:SetDuration(1)
--    extended.FadeIn:SetScript("OnFinished", function(self)
--      extended:Show()
--    end)

    --		local healthbar = CreateTidyPlatesInternalStatusbar(extended)
--		healthbar.Backdrop:SetDrawLayer("BORDER",-8)
--    healthbar.Bar:SetDrawLayer("BORDER",-7)
    local healthbar = Addon:CreateHealthbar(extended)
		local textFrame = CreateFrame("Frame", nil, extended)

		textFrame:SetAllPoints()

		--extended.widgetParent = widgetParent
		visual.healthbar = healthbar
		visual.castbar = castbar
    visual.textframe = textFrame

		-- Parented to Health Bar - Lower Frame
    visual.threatborder = healthbar.ThreatBorder
    visual.healthborder = healthbar.Border
    visual.eliteborder = healthbar.EliteBorder
    visual.highlight = healthbar:CreateTexture(nil, "ARTWORK") -- required for Headline View

    -- Parented to Extended - Middle Frame
    visual.raidicon = textFrame:CreateTexture(nil, "ARTWORK", 5)
    visual.skullicon = textFrame:CreateTexture(nil, "ARTWORK", 2)
    visual.eliteicon = textFrame:CreateTexture(nil, "ARTWORK", 1)
    visual.target = textFrame:CreateTexture(nil, "BACKGROUND")

		-- TextFrame
    visual.name  = textFrame:CreateFontString(nil, "ARTWORK", 0)
		visual.name:SetFont("Fonts\\FRIZQT__.TTF", 11)
		visual.customtext = textFrame:CreateFontString(nil, "ARTWORK", -1)
		visual.customtext:SetFont("Fonts\\FRIZQT__.TTF", 11)
		visual.level = textFrame:CreateFontString(nil, "ARTWORK", -2)
		visual.level:SetFont("Fonts\\FRIZQT__.TTF", 11)

		-- Cast Bar Frame - Highest Frame
		visual.castborder = castbar.Border
		visual.spellicon = castbar.Overlay:CreateTexture(nil, "ARTWORK", 7)

		visual.spelltext = castbar.Overlay:CreateFontString(nil, "OVERLAY")
		visual.spelltext:SetFont("Fonts\\FRIZQT__.TTF", 11)

    -- Set Base Properties
		visual.raidicon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    visual.highlight:SetAllPoints(visual.name)
    visual.highlight:SetBlendMode("ADD")

		--healthbar:SetFrameStrata("BACKGROUND")
		--castbar:SetFrameStrata("BACKGROUND")
		--textFrame:SetFrameStrata("BACKGROUND")
    --widgetParent:SetFrameStrata("BACKGROUND")

    castbar:SetFrameLevel(extended:GetFrameLevel() + 4)
    healthbar:SetFrameLevel(extended:GetFrameLevel() + 5)
    textFrame:SetFrameLevel(extended:GetFrameLevel() + 6)

    castbar:Hide()
		castbar:SetStatusBarColor(1,.8,0)

    -- Tidy Plates Frame References
		extended.visual = visual

		-- Allocate Tables
		extended.style,
		extended.unit,
		extended.unitcache,
		extended.stylecache,
		extended.widgets = {}, {}, {}, {}, {}
		extended.stylename = ""
  end
end

---------------------------------------------------------------------------------------------------------------------
-- Nameplate Script Handlers
---------------------------------------------------------------------------------------------------------------------
do
	-- UpdateUnitCache
	local function UpdateUnitCache() for key, value in pairs(unit) do unitcache[key] = value end end

	-- CheckNameplateStyle
	local function CheckNameplateStyle()
    stylename = Addon:SetStyle(unit)
    extended.style = activetheme[stylename]

		style = extended.style

		if style and (extended.stylename ~= stylename) then
			UpdateStyle()
			extended.stylename = stylename
			unit.style = stylename
    end
	end

	-- ProcessUnitChanges
	local function ProcessUnitChanges()
			-- Unit Cache: Determine if data has changed
			unitchanged = false

			for key, value in pairs(unit) do
				if unitcache[key] ~= value then
					unitchanged = true
				end
      end

			-- Update Style/Indicators
			if unitchanged or UpdateAll or (not style) then --
				CheckNameplateStyle()
				UpdateIndicator_Standard()
				UpdateIndicator_HealthBar()
				UpdateIndicator_Target()
			end

			-- Update Widgets
			Addon:OnUpdate(extended, unit)

			-- Update Delegates
			UpdateIndicator_ThreatGlow()
			UpdateIndicator_CustomAlpha()
			UpdateIndicator_CustomScaleText()

			-- Cache the old unit information
			UpdateUnitCache()
	end

--[[
	local function HideWidgets(plate)
		if plate.TPFrame and plate.TPFrame.widgets then
			local widgetTable = plate.TPFrame.widgets
			for widgetIndex, widget in pairs(widgetTable) do
				widget:Hide()
				--widgetTable[widgetIndex] = nil
			end
		end
	end

--]]

	---------------------------------------------------------------------------------------------------------------------
	-- Create / Hide / Show Event Handlers
	---------------------------------------------------------------------------------------------------------------------

	-- OnShowNameplate
	function OnShowNameplate(plate, unitid)
    UpdateReferences(plate)

    wipe(extended.unit)
    wipe(extended.unitcache)
    --extended.unit = {}
    --extended.unitcache = {}

    unit.frame = extended
		unit.alpha = 0
		unit.isTarget = false
		unit.isMouseover = false
    unit.unitid = unitid
    unit.guid = UnitGUID(unitid)
    unit.isCasting = false

    --extended.unitcache = ClearIndices(extended.unitcache)
		extended.stylename = ""
		extended.Active = true

    PlatesVisible[plate] = unitid
    PlatesByUnit[unitid] = plate
    PlatesByGUID[unit.guid] = plate

		-- For Fading In
		PlatesFading[plate] = EnableFadeIn
		extended.requestedAlpha = 0
    -- extended:Hide()		-- Yes, it seems counterintuitive, but...
    -- extended:SetAlpha(0)

		-- Graphics
		visual.castbar:Hide()
		visual.highlight:Hide()
    visual.healthbar.Highlight:Hide()

		-- Widgets/Extensions
		-- This goes here because a user might change widget settings after nameplates have been created
		Addon:OnInitialize(extended, activetheme)

    if TidyPlatesThreat.db.profile.ShowFriendlyBlizzardNameplates and UnitReaction(unitid, "player") > 4 then
      plate.UnitFrame:Show()
      plate.TPFrame:Hide()
      --extended.Active = false
    else
      plate.UnitFrame:Hide()
      plate.TPFrame:Show()
      --extended.Active = true
      --plate.TPFrame.FadeIn:Play()
    end

    -- Skip the initial data gather and let the second cycle do the work.
		plate.UpdateMe = true
  end


	-- OnHideNameplate
	function OnHideNameplate(plate, unitid)
		UpdateReferences(plate)
    extended:Hide()
    --extended.FadeOut:Play()

    extended.Active = false

		PlatesVisible[plate] = nil
		PlatesByUnit[unitid] = nil
    if unit.guid then -- maybe hide directly after create with unit added?
      PlatesByGUID[unit.guid] = nil
    end

    visual.castbar:Hide()
		--visual.castbar:SetScript("OnUpdate", nil)
		unit.isCasting = false

		-- Remove anything from the function queue
		plate.UpdateMe = false

		for widgetname, widget in pairs(extended.widgets) do
      widget:Hide()
    end
	end

	-- OnUpdateNameplate
	function OnUpdateNameplate(plate)
    -- Gather Information
    local unitid = PlatesVisible[plate]
    UpdateReferences(plate)

		UpdateUnitIdentity(unitid)
		UpdateUnitContext(plate, unitid)
		ProcessUnitChanges()
		OnUpdateCastMidway(plate, unitid)
	end

	-- OnHealthUpdate
	function OnHealthUpdate(plate)
		local unitid = PlatesVisible[plate]

		UpdateUnitCondition(plate, unitid)
		ProcessUnitChanges()

    -- Fix a bug where the overlay for non-interruptible casts was shown even for interruptible casts when entering combat while the unit was already casting
    if unit.isCasting then
      visual.castbar:SetShownInterruptOverlay(unit.spellIsShielded)
    end

    UpdateIndicator_HealthBar()		-- Just to be on the safe side
  end

  -- OnResetNameplate
	function OnResetNameplate(plate)
    plate.UpdateMe = true

    local extended = plate.TPFrame
		extended.unitcache = ClearIndices(extended.unitcache)
		extended.stylename = ""

    OnShowNameplate(plate, PlatesVisible[plate])
	end
end


---------------------------------------------------------------------------------------------------------------------
--  Unit Updates: Updates Unit Data, Requests indicator updates
---------------------------------------------------------------------------------------------------------------------
do
	local RaidIconList = { "STAR", "CIRCLE", "DIAMOND", "TRIANGLE", "MOON", "SQUARE", "CROSS", "SKULL" }

	-- GetUnitAggroStatus: Determines if a unit is attacking, by looking at aggro glow region
	local function GetUnitAggroStatus( threatRegion )
		if not  threatRegion:IsShown() then return "LOW", 0 end

		local red, green, blue, alpha = threatRegion:GetVertexColor()
		local opacity = threatRegion:GetVertexColor()

		if threatRegion:IsShown() and (alpha < .9 or opacity < .9) then
			-- Unfinished
		end

		if red > 0 then
			if green > 0 then
				if blue > 0 then return "MEDIUM", 1 end
				return "MEDIUM", 2
			end
			return "HIGH", 3
		end
	end

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
	function UpdateUnitIdentity(unitid)
		unit.unitid = unitid
    unit.name = UnitName(unitid)
    unit.pvpname = UnitPVPName(unitid)
    unit.rawName = unit.name  -- gsub(unit.name, " %(%*%)", "")

		local classification = UnitClassification(unitid)

		unit.isBoss = UnitLevel(unitid) == -1
		unit.isDangerous = unit.isBoss

		unit.isElite = EliteReference[classification]
		unit.isRare = RareReference[classification]
		unit.isMini = classification == "minus"
		--unit.isPet = UnitIsOtherPlayersPet(unitid)

		if UnitIsPlayer(unitid) then
			_, unit.class = UnitClass(unitid)
			unit.type = "PLAYER"
		else
			unit.class = ""
			unit.type = "NPC"
		end
	end

  -- UpdateUnitContext: Updates Target/Mouseover
	function UpdateUnitContext(plate, unitid)
		UpdateReferences(plate)

		unit.isMouseover = UnitIsUnit("mouseover", unitid)
		unit.isTarget = UnitIsUnit("target", unitid)
		unit.isFocus = UnitIsUnit("focus", unitid)

		unit.guid = UnitGUID(unitid)

		UpdateUnitCondition(plate, unitid)	-- This updates a bunch of properties

    Addon:OnContextUpdate(extended, unit)
		Addon:OnUpdate(extended, unit)
	end

	-- UpdateUnitCondition: High volatility data
	function UpdateUnitCondition(plate, unitid)
		UpdateReferences(plate)

		unit.level = UnitEffectiveLevel(unitid)

		local c = GetCreatureDifficultyColor(unit.level)
		unit.levelcolorRed, unit.levelcolorGreen, unit.levelcolorBlue = c.r, c.g, c.b

		unit.red, unit.green, unit.blue = UnitSelectionColor(unitid)

		unit.reaction = GetReactionByColor(unit.red, unit.green, unit.blue) or "HOSTILE"
    -- Enemy players turn to neutral, e.g., when mounting a flight path mount, so fix reaction in that situations
    if unit.reaction == "NEUTRAL" and (unit.type == "PLAYER" or UnitPlayerControlled(unitid)) then
      unit.reaction = "HOSTILE"
    end

		unit.health = UnitHealth(unitid) or 0
		unit.healthmax = UnitHealthMax(unitid) or 1

		unit.threatValue = UnitThreatSituation("player", unitid) or 0
		unit.threatSituation = ThreatReference[unit.threatValue]
		unit.isInCombat = UnitAffectingCombat(unitid)

		local raidIconIndex = GetRaidTargetIndex(unitid)

		if raidIconIndex then
			unit.raidIcon = RaidIconList[raidIconIndex]
			unit.isMarked = true
		else
			unit.isMarked = false
		end

		-- Unfinished....
		unit.isTapped = UnitIsTapDenied(unitid)
		--unit.isInCombat = false
		--unit.platetype = 2 -- trivial mini mob

	end
end		-- End of Nameplate/Unit Events


---------------------------------------------------------------------------------------------------------------------
-- Indicators: These functions update the color, texture, strings, and frames within a style.
---------------------------------------------------------------------------------------------------------------------
do
	local color = {}
	local alpha, forcealpha, scale


	-- UpdateIndicator_HealthBar: Updates the value on the health bar
	function UpdateIndicator_HealthBar()
		visual.healthbar:SetMinMaxValues(0, unit.healthmax)
		visual.healthbar:SetValue(unit.health)
	end


	-- UpdateIndicator_Name:
	function UpdateIndicator_Name()
		visual.name:SetText(unit.name)
		--unit.pvpname

		-- Name Color
    visual.name:SetTextColor(Addon:SetNameColor(unit))
	end


	-- UpdateIndicator_Level:
	function UpdateIndicator_Level()
		if unit.isBoss and style.skullicon.show then visual.level:Hide(); visual.skullicon:Show() else visual.skullicon:Hide() end

		if unit.level < 0 then visual.level:SetText("")
		else visual.level:SetText(unit.level) end
		visual.level:SetTextColor(unit.levelcolorRed, unit.levelcolorGreen, unit.levelcolorBlue)
	end


	-- UpdateIndicator_ThreatGlow: Updates the aggro glow
	function UpdateIndicator_ThreatGlow()
		if not style.threatborder.show then
      return
    end

    visual.threatborder:SetBackdropBorderColor(Addon:SetThreatColor(unit))
	end


	-- UpdateIndicator_Target
	function UpdateIndicator_Target()
    visual.target:SetShown(unit.isTarget and style.target.show)

		if unit.isMouseover and not unit.isTarget and style.highlight.show then
      if style.healthbar.show then -- healthbar view
        visual.healthbar.Highlight:Show()
      else
        visual.highlight:Show()
      end
    else
      visual.highlight:Hide()
      visual.healthbar.Highlight:Hide()
    end
	end

	-- UpdateIndicator_RaidIcon
	function UpdateIndicator_RaidIcon()
		if unit.isMarked and style.raidicon.show then
			visual.raidicon:Show()
			local iconCoord = RaidIconCoordinate[unit.raidIcon]
			visual.raidicon:SetTexCoord(iconCoord.x, iconCoord.x + 0.25, iconCoord.y,  iconCoord.y + 0.25)
		else visual.raidicon:Hide() end
	end


	-- UpdateIndicator_EliteIcon: Updates the border overlay art and threat glow to Elite or Non-Elite art
	function UpdateIndicator_EliteIcon()
		if unit.isElite and style.eliteicon.show then
      visual.eliteicon:Show()
    else
      visual.eliteicon:Hide()
    end
	end


	-- UpdateIndicator_UnitColor: Update the health bar coloring, if needed
	function UpdateIndicator_UnitColor()
		-- Set Health Bar
		visual.healthbar:SetAllColors(Addon:SetHealthbarColor(unit))

		-- Name Color
    visual.name:SetTextColor(Addon:SetNameColor(unit))
	end

	-- UpdateIndicator_Standard: Updates Non-Delegate Indicators
	function UpdateIndicator_Standard()
		if IsPlateShown(nameplate) then
			if unitcache.name ~= unit.name then UpdateIndicator_Name() end
			if unitcache.level ~= unit.level then UpdateIndicator_Level() end
			UpdateIndicator_RaidIcon()
			if unitcache.isElite ~= unit.isElite then UpdateIndicator_EliteIcon() end
		end
	end


	-- UpdateIndicator_CustomAlpha: Calls the alpha delegate to get the requested alpha
	function UpdateIndicator_CustomAlpha(event)
    extended.requestedAlpha = Addon:SetAlpha(unit) or unit.alpha or 1
    extended:SetAlpha(extended.requestedAlpha)
	end


	-- UpdateIndicator_CustomScaleText: Updates indicators for custom text and scale
	function UpdateIndicator_CustomScaleText()
		if unit.health and (extended.requestedAlpha > 0) then
			-- Scale
      scale = Addon.UIScale * Addon:SetScale(unit)
      extended:SetScale(scale)

			-- Set Special-Case Regions
			if style.customtext.show then
        local text, r, g, b, a = Addon:SetCustomText(unit)
        visual.customtext:SetText( text or "")
        visual.customtext:SetTextColor(r or 1, g or 1, b or 1, a or 1)
			end

			UpdateIndicator_UnitColor()
		end
	end

	-- OnShowCastbar
	function OnStartCasting(plate, unitid, channeled)
    UpdateReferences(plate)

		-- style may be uninitialized (empty) here (e.g., when reloading)
    if not (extended:IsShown() and style.castbar and style.castbar.show) then
      return
    end
    --if not extended:IsShown() then return end

    local castbar = extended.visual.castbar
    local name, subText, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible

    if channeled then
			name, subText, text, texture, startTime, endTime, isTradeSkill, notInterruptible = UnitChannelInfo(unitid)
      castbar.IsChanneling = true
      castbar.IsCasting = false
		else
			name, subText, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unitid)
      castbar.IsCasting = true
      castbar.IsChanneling = false
		end

		if isTradeSkill then return end

		unit.isCasting = true
		unit.spellIsShielded = notInterruptible
		unit.spellInterruptible = not unit.spellIsShielded

		visual.spelltext:SetText(text)
		visual.spellicon:SetTexture(texture)
    visual.spellicon:SetDrawLayer("BACKGROUND", 7)

		--castBar:SetMinMaxValues( startTime, endTime )
    castbar.Value = GetTime() - (startTime / 1000)
    castbar.MaxValue = (endTime - startTime) / 1000
    castbar:SetMinMaxValues(0, castbar.MaxValue)

    castbar:SetAllColors(Addon:SetCastbarColor(unit))
    visual.castbar:SetShownInterruptOverlay(unit.spellIsShielded)

		UpdateIndicator_CustomScaleText()
		UpdateIndicator_CustomAlpha()

		castbar:Show()
	end

	-- OnHideCastbar
	function OnStopCasting(plate)
    UpdateReferences(plate)
    local castbar = extended.visual.castbar
    castbar.IsCasting = false
    castbar.IsChanneling = false
    unit.isCasting = false

    --castBar:SetScript("OnUpdate", nil)
    -- castbar:Hide() -- hiden in castbar's OnUpdateCastbar function

		UpdateIndicator_CustomScaleText()
		UpdateIndicator_CustomAlpha()
	end

	function OnUpdateCastMidway(plate, unitid)
		if not ShowCastBars then return end

		local currentTime = GetTime() * 1000

		-- Check to see if there's a spell being cast
		if UnitCastingInfo(unitid) then
      --OnStartCasting(plate, unitid, false)
    else
      -- See if one is being channeled...
			if UnitChannelInfo(unitid) then
        --OnStartCasting(plate, unitid, true)
      end
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

	-- Update spell currently being cast
	local function UnitSpellcastMidway(event, unitid, ...)
		if UnitIsUnit("player", unitid) or not ShowCastBars then return end
		local plate = GetNamePlateForUnit(unitid);
		if plate then
			OnUpdateCastMidway(plate, unitid)
		end
	 end

  local function FrameOnShow(UnitFrame)
    -- Hide namepaltes that have not yet an unit added
    if not UnitFrame.unit then
      UnitFrame:Hide()
    end

    -- Skip the personal resource bar of the player character, don't unhook scripts as nameplates, even the personal
    -- resource bar, get re-used
    if UnitIsUnit(UnitFrame.unit, "player") then -- or: ns.PlayerNameplate == GetNamePlateForUnit(UnitFrame.unit)
      return
    end

    -- Hide ThreatPlates nameplates if Blizzard nameplates should be shown for friendly units
    UnitFrame:SetShown(TidyPlatesThreat.db.profile.ShowFriendlyBlizzardNameplates and UnitReaction(UnitFrame.unit, "player") > 4)
  end

  -- Frame: self = plate
  local function FrameOnUpdate(plate)
    local unitid = plate.UnitFrame.unit
    if unitid and UnitIsUnit(unitid, "player") then
      return
    end

    plate.TPFrame:SetFrameLevel(plate:GetFrameLevel() * 10)
  end

  -- Frame: self = plate
  local function FrameOnHide(plate)
    plate.TPFrame:Hide()
    --extended.FadeOut:Play()
  end

  local CoreEvents = {}

	local function EventHandler(self, event, ...)
		CoreEvents[event](event, ...)
	end

	----------------------------------------
	-- Game Events
	----------------------------------------
	function CoreEvents:PLAYER_ENTERING_WORLD()
		TidyPlatesCore:SetScript("OnUpdate", OnUpdate);
	end

	function CoreEvents:NAME_PLATE_CREATED(plate)
    OnNewNameplate(plate)

    if plate.UnitFrame then -- not plate.TPFrame.onShowHooked then
      plate.UnitFrame:HookScript("OnShow", FrameOnShow)
      -- plate.TPFrame.onShowHooked = true
    end
    plate:HookScript('OnHide', FrameOnHide)
    plate:HookScript('OnUpdate', FrameOnUpdate)
  end

	-- Payload: { Name = "unitToken", Type = "string", Nilable = false },
	function CoreEvents:NAME_PLATE_UNIT_ADDED(unitid)
    -- Handle personal resource bar, currently it's ignored by Threat Plates
		if not UnitIsUnit("player", unitid) then
      --local plate = GetNamePlateForUnit(unitid)
      --plate.UnitFrame:SetShown(TidyPlatesThreat.db.profile.ShowFriendlyBlizzardNameplates and UnitReaction(unitid, "player") > 4)
      --plate:GetChildren():Hide()
			OnShowNameplate(GetNamePlateForUnit(unitid), unitid)
		--else
			--addon.PlayerNameplate = plate
			--print ("NAME_PLATE_UNIT_ADDED: player frame")
		end
	end

	function CoreEvents:NAME_PLATE_UNIT_REMOVED(unitid)
		local plate = GetNamePlateForUnit(unitid);

		OnHideNameplate(plate, unitid)
	end

	function CoreEvents:PLAYER_TARGET_CHANGED()
    -- Target Castbar Offset
    local visual, style, extended
    if LastTargetPlate then
      extended = LastTargetPlate.TPFrame
      visual = extended.visual
      style = extended.style
      visual.castbar:ClearAllPoints()
      visual.spelltext:ClearAllPoints()
      visual.castbar:SetPoint(style.castbar.anchor or "CENTER", extended, style.castbar.x or 0, style.castbar.y or 0)
      visual.spelltext:SetPoint(style.spelltext.anchor or "CENTER", extended, style.spelltext.x or 0, style.spelltext.y or 0)
      --visual.spellicon:SetPoint(style.spellicon.anchor or "CENTER", extended, style.spellicon.x or 0, style.spellicon.y or 0)

      LastTargetPlate = nil
    end

    local plate = GetNamePlateForUnit("target")
    if plate and plate.TPFrame and plate.TPFrame.stylename ~= "" then
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
    end

    SetUpdateAll()
	end

	function CoreEvents:UNIT_HEALTH_FREQUENT(unitid)
		local plate = PlatesByUnit[unitid]

		if plate then
      OnHealthUpdate(plate)
    end
	end

	function CoreEvents:PLAYER_REGEN_ENABLED()
		InCombat = false
		SetUpdateAll()
	end

	function CoreEvents:PLAYER_REGEN_DISABLED()
		InCombat = true
		SetUpdateAll()
	end

	function CoreEvents:UPDATE_MOUSEOVER_UNIT(...)
		if UnitExists("mouseover") then
			HasMouseover = true
			SetUpdateAll()
		end
	end

	function CoreEvents:UNIT_SPELLCAST_START(unitid)
 		if UnitIsUnit("player", unitid) or not ShowCastBars then return end

		local plate = GetNamePlateForUnit(unitid)

		if plate then
      OnStartCasting(plate, unitid, false)
		end
	end


	 function CoreEvents:UNIT_SPELLCAST_STOP(unitid)
		if UnitIsUnit("player", unitid) or not ShowCastBars then return end

		local plate = GetNamePlateForUnit(unitid)

		if plate then
			OnStopCasting(plate)
		end
	 end

	function CoreEvents:UNIT_SPELLCAST_CHANNEL_START(...)
		local unitid = ...
		if UnitIsUnit("player", unitid) or not ShowCastBars then return end

		local plate = GetNamePlateForUnit(unitid)

		if plate then
			OnStartCasting(plate, unitid, true)
		end
	end

	function CoreEvents:UNIT_SPELLCAST_CHANNEL_STOP(...)
		local unitid = ...
		if UnitIsUnit("player", unitid) or not ShowCastBars then return end

		local plate = GetNamePlateForUnit(unitid)

		if plate then
			OnStopCasting(plate)
		end
	end

  function CoreEvents:COMBAT_LOG_EVENT_UNFILTERED(...)
    local timeStamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags  = ...

    if (event == "SPELL_INTERRUPT") then
      local plate = PlatesByGUID[destGUID]

      if plate then
        UpdateReferences(plate)

        local castbar = visual.castbar
        if unit.isTarget then
          local _, class = UnitClass(sourceName)
          if class then
            sourceName = "|cff" .. ThreatPlates.HCC[class] .. sourceName .. "|r"
          end

          visual.spelltext:SetText(INTERRUPTED .. " [" .. sourceName .. "]")
          local _, max_val = castbar:GetMinMaxValues()
          castbar:SetValue(max_val)
          local color = TidyPlatesThreat.db.profile.castbarColorInterrupted
          castbar:SetStatusBarColor(color.r, color.g, color.b, color.a)
          castbar.FlashTime = CASTBAR_FLASH_DURATION
          castbar:Show() -- OnStopCasting is hiding the castbar and triggered before SPELL_INTERRUPT, so we have to show the castbar again
          --castbar:SetAllColors(1, 0, 1, 1, 0, 0, 0, 1)
          --castbar.Flash:Play()
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
  end

  function CoreEvents:UNIT_NAME_UPDATE(unitid)
    if UnitIsUnit("player", unitid) then return end -- skip personal resource bar

    local plate = GetNamePlateForUnit(unitid)
    if plate then
      UpdateReferences(plate)

      if unit.name == UNKNOWNOBJECT then
        -- UpdateUnitIdentity()
        unit.name = UnitName(unitid)
        unit.pvpname = UnitPVPName(unitid)
        unit.rawName = unit.name
        UpdateIndicator_Name()
      end
    end
  end

  -- The following events should not have worked before adjusting UnitSpellcastMidway
	CoreEvents.UNIT_SPELLCAST_DELAYED = UnitSpellcastMidway
	CoreEvents.UNIT_SPELLCAST_CHANNEL_UPDATE = UnitSpellcastMidway
	CoreEvents.UNIT_SPELLCAST_INTERRUPTIBLE = UnitSpellcastMidway
	CoreEvents.UNIT_SPELLCAST_NOT_INTERRUPTIBLE = UnitSpellcastMidway

	CoreEvents.UNIT_LEVEL = UnitConditionChanged
	--CoreEvents.UNIT_THREAT_SITUATION_UPDATE = UnitConditionChanged -- did not work anyway (no unitid)
	CoreEvents.UNIT_FACTION = WorldConditionChanged
  CoreEvents.RAID_TARGET_UPDATE = WorldConditionChanged
	CoreEvents.PLAYER_FOCUS_CHANGED = WorldConditionChanged
	CoreEvents.PLAYER_CONTROL_LOST = WorldConditionChanged
	CoreEvents.PLAYER_CONTROL_GAINED = WorldConditionChanged

	-- Registration of Blizzard Events
	TidyPlatesCore:SetFrameStrata("TOOLTIP") 	-- When parented to WorldFrame, causes OnUpdate handler to run close to last
	TidyPlatesCore:SetScript("OnEvent", EventHandler)
	for eventName in pairs(CoreEvents) do TidyPlatesCore:RegisterEvent(eventName) end
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
    object:SetJustifyH(horz)
    object:SetJustifyV(vert)
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
		if (not OverrideFonts) and font then
			object:SetFont(font, size or 10, flags)
		--else
		--	object:SetFontObject("SpellFont_Small")
		end
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

	-- SetBarGroupObject
	local function SetBarGroupObject(object, objectstyle, anchorTo)
		if objectstyle then
			SetAnchorGroupObject(object, objectstyle, anchorTo)
			SetObjectBartexture(object, objectstyle.texture or EMPTY_TEXTURE, objectstyle.orientation or "HORIZONTAL")
			if objectstyle.backdrop then
				object:SetBackdropTexture(objectstyle.backdrop)
			end
			object:SetTexCoord(objectstyle.left, objectstyle.right, objectstyle.top, objectstyle.bottom)
		end
	end

	-- Style Groups
	local fontgroup = {"name", "level", "spelltext", "customtext"}

	local anchorgroup = {
		"name",  "spelltext", "customtext", "level",
		"spellicon", "raidicon", "skullicon", "eliteicon", "target"
    -- "threatborder", "castborder", "castnostop",
  }

	local bargroup = { } --"castbar" }

	local texturegroup = {
    "eliteicon",
    "skullicon", "highlight", "target", "spellicon",
    -- threatborder, "castborder", "castnostop",
  }

  --local showgroup = { "healthborder" }

	-- UpdateStyle:
	function UpdateStyle()
		local index

		-- Frame
    --SetAnchorGroupObject(extended, style.frame, nameplate)
    SetObjectAnchor(extended, style.frame.anchor or "CENTER", nameplate, style.frame.x or 0, style.frame.y or 0)
    extended:SetAllPoints(nameplate)

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

    -- Bars
		for index = 1, #bargroup do
			local objectname = bargroup[index]
			local object, objectstyle = visual[objectname], style[objectname]

			if objectstyle then
        SetBarGroupObject(object, objectstyle, extended)
      end
    end

		-- Healthbar
		SetAnchorGroupObject(visual.healthbar, style.healthbar, extended)
		visual.healthbar:SetStatusBarTexture(style.healthbar.texture or EMPTY_TEXTURE)
		--visual.healthbar:SetOrientation(style.healthbar.orientation or "HORIZONTAL")
		visual.healthbar:SetStatusBarBackdrop(style.healthbar.backdrop, style.healthborder.texture, style.healthborder.edgesize, style.healthborder.offset)
		visual.healthborder:SetShown(style.healthborder.show)
    visual.healthbar:SetEliteBorder(style.eliteborder.texture)

    -- Castbar
    SetAnchorGroupObject(visual.castbar, style.castbar, extended)
    visual.castbar:SetStatusBarTexture(style.castbar.texture or EMPTY_TEXTURE)
    --visual.healthbar:SetOrientation(style.healthbar.orientation or "HORIZONTAL")
    visual.castbar:SetStatusBarBackdrop(style.castbar.backdrop, style.castborder.texture, style.castborder.edgesize, style.castborder.offset)
    visual.castborder:SetShown(style.castborder.show)

    -- Texture
    for index = 1, #texturegroup do
      local objectname = texturegroup[index]
      local object, objectstyle = visual[objectname], style[objectname]

      SetTextureGroupObject(object, objectstyle)
    end

    -- Show certain elements, don't change anything else
--		for index = 1, #showgroup do
--			local objectname = showgroup[index]
--			visual[objectname]:SetShown(style[objectname].show)
--		end

		-- Raid Icon Texture
		if style and style.raidicon and style.raidicon.texture then
			visual.raidicon:SetTexture(style.raidicon.texture)
      visual.raidicon:SetDrawLayer("ARTWORK", 5)
    end

		-- Font Group
		for index = 1, #fontgroup do
			local objectname = fontgroup[index]
			local object, objectstyle = visual[objectname], style[objectname]

			SetFontGroupObject(object, objectstyle)
    end

    visual.castbar:ClearAllPoints()
    visual.spelltext:ClearAllPoints()
    --visual.spellicon:ClearAllPoints()

    if unit.isTarget then
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
		if unit.isElite and style.eliteborder.show then
      visual.eliteborder:Show()
    else
      visual.eliteborder:Hide()
      visual.eliteicon:Hide()
    end
		if not unit.isBoss then visual.skullicon:Hide() end

		if not unit.isTarget then visual.target:Hide() end
		if not unit.isMarked then visual.raidicon:Hide() end
  end
end

--------------------------------------------------------------------------------------------------------------
-- Theme Handling
--------------------------------------------------------------------------------------------------------------
local function UseTheme(theme)
	if theme and type(theme) == 'table' and not theme.IsShown then
		activetheme = theme 						-- Store a local copy
		ResetPlates = true
	end
end

Addon.UseTheme = UseTheme

local function GetTheme()
	return activetheme
end

TidyPlatesInternal.GetTheme = GetTheme

--------------------------------------------------------------------------------------------------------------
-- Misc. Utility
--------------------------------------------------------------------------------------------------------------
local function OnResetWidgets(plate)
	-- At some point, we're going to have to manage the widgets a bit better.

	local extended = plate.TPFrame
	local widgets = extended.widgets

	for widgetName, widgetFrame in pairs(widgets) do
		widgetFrame:Hide()
		--widgets[widgetName] = nil			-- Nilling the frames may cause leakiness.. or at least garbage collection
	end

	plate.UpdateMe = true
end


function Addon:UIScaleChanged()
  local db = TidyPlatesThreat.db.profile.Scale
  if db.IgnoreUIScale then
    Addon.UIScale = 1 / UIParent:GetEffectiveScale()
  else
    Addon.UIScale = 1

    if db.PixelPerfectUI then
      local physicalScreenHeight = select(2, GetPhysicalScreenSize())
      Addon.UIScale = 768.0 / physicalScreenHeight
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

--local function OnUpdateSettings(plate)
--  local extended = plate.TPFrame
--  local healthbar = extended.visual.healthbar
--
--  print ("OnUpdateSettings")
--  healthbar:SetSize(extended.style.healthbar.width, extended.style.healthbar.height)
--end

--------------------------------------------------------------------------------------------------------------
-- External Commands: Allows widgets and themes to request updates to the plates.
-- Useful to make a theme respond to externally-captured data (such as the combat log)
--------------------------------------------------------------------------------------------------------------
function TidyPlatesInternal:DisableCastBars() ShowCastBars = false end
function TidyPlatesInternal:EnableCastBars() ShowCastBars = true end

--function TidyPlatesInternal:UpdateSettings() ForEachPlate(OnUpdateSettings) end
function TidyPlatesInternal:ForceUpdate() ForEachPlate(OnResetNameplate) end
function TidyPlatesInternal:ResetWidgets() ForEachPlate(OnResetWidgets) end
function TidyPlatesInternal:Update() SetUpdateAll() end

function TidyPlatesInternal:RequestUpdate(plate) if plate then SetUpdateMe(plate) else SetUpdateAll() end end

function TidyPlatesInternal:ActivateTheme(theme) if theme and type(theme) == 'table' then TidyPlatesInternal.ActiveThemeTable, activetheme = theme, theme; ResetPlates = true; end end
function TidyPlatesInternal.OverrideFonts( enable) OverrideFonts = enable; end

-- Old and needing deleting - Just here to avoid errors
function TidyPlatesInternal:EnableFadeIn() EnableFadeIn = true; end
function TidyPlatesInternal:DisableFadeIn() EnableFadeIn = nil; end
TidyPlatesInternal.RequestWidgetUpdate = TidyPlatesInternal.RequestUpdate
TidyPlatesInternal.RequestDelegateUpdate = TidyPlatesInternal.RequestUpdate
