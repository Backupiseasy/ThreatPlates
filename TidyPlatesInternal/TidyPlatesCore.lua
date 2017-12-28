local addonName, addon = ...

-- Tidy Plates - SMILE! :-D

---------------------------------------------------------------------------------------------------------------------
-- Variables and References
---------------------------------------------------------------------------------------------------------------------
local TidyPlatesCore = CreateFrame("Frame", nil, WorldFrame)
TidyPlatesInternal = {}

-- Local References
local _
local max = math.max
local select, pairs, tostring  = select, pairs, tostring 			    -- Local function copy
local CreateTidyPlatesInternalStatusbar = CreateTidyPlatesInternalStatusbar			    -- Local function copy

-- WoW APIs
local wipe = wipe
local WorldFrame, UIParent = WorldFrame, UIParent
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local UnitName = UnitName
local UnitIsUnit = UnitIsUnit
local UNKNOWNOBJECT = UNKNOWNOBJECT
local UnitExists = UnitExists
local CreateFrame = CreateFrame
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

-- Internal Data
local Plates, PlatesVisible, PlatesFading, GUID = {}, {}, {}, {}	            	-- Plate Lists
local PlatesByUnit = {}
local nameplate, extended, visual, carrier, plateid			    	-- Temp/Local References
local unit, unitcache, style, stylename, unitchanged, threatborder	    			-- Temp/Local References
local numChildren = -1                                                              -- Cache the current number of plates
local activetheme = {}                                                              -- Table Placeholder
local InCombat, HasTarget, HasMouseover = false, false, false					    -- Player State Data
local EnableFadeIn = true
local ShowCastBars = true
local EMPTY_TEXTURE = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Empty"
local ResetPlates, UpdateAll = false, false
local OverrideFonts = false

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
local OnShowNameplate, OnHideNameplate, OnUpdateNameplate, OnResetNameplate
local OnHealthUpdate, UpdateUnitCondition
local UpdateUnitContext, OnRequestWidgetUpdate, OnRequestDelegateUpdate
local UpdateUnitIdentity, UnitNameUpdate
local OnNewNameplate

-- Main Loop
local OnUpdate
local ForEachPlate

-- UpdateReferences
local function UpdateReferences(plate)
	nameplate = plate
	extended = plate.TP_Extended

	carrier = plate.TP_Carrier
	unit = extended.unit
	unitcache = extended.unitcache
	visual = extended.visual
	style = extended.style
	threatborder = visual.threatborder
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
			if plate.TP_Extended.Active then
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
			local carrier = plate.TP_Carrier
			local extended = plate.TP_Extended

			-- Check for an Update Request
			if UpdateMe or UpdateHealth then
				if not UpdateMe then
					OnHealthUpdate(plate)
				else
					OnUpdateNameplate(plate)
				end
				plate.UpdateMe = false
				plate.UpdateHealth = false

				plate:GetChildren():Hide()

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
	function OnNewNameplate(plate, plateid)
    -- Tidy Plates Frame
    --------------------------------
		local carrier
		local frameName = "ThreatPlatesCarrier"..numChildren

		carrier = CreateFrame("Frame", frameName, WorldFrame)
		local extended = CreateFrame("Frame", nil, carrier)

		plate.TP_Carrier = carrier
		plate.TP_Extended = extended

		-- Add Graphical Elements
		local visual = {}
		-- Status Bars
		local castbar = CreateTidyPlatesInternalStatusbar(extended)
		castbar.Backdrop:SetDrawLayer("BACKGROUND",-8)
		castbar.Bar:SetDrawLayer("BACKGROUND",-7)
		local healthbar = CreateTidyPlatesInternalStatusbar(extended)
		healthbar.Backdrop:SetDrawLayer("BORDER",-8)
		healthbar.Bar:SetDrawLayer("BORDER",-7)
		--local textFrame = CreateFrame("Frame", nil, healthbar)
		local textFrame = CreateFrame("Frame", nil, extended)
		--local widgetParent = CreateFrame("Frame", nil, textFrame)

		textFrame:SetAllPoints()

		--extended.widgetParent = widgetParent
		visual.healthbar = healthbar
		visual.castbar = castbar
    visual.textframe = textFrame

		-- Parented to Health Bar - Lower Frame
    visual.threatborder = healthbar:CreateTexture(nil, "BORDER", 2)
    visual.healthborder = healthbar:CreateTexture(nil, "BORDER", 0)
		visual.highlight = healthbar:CreateTexture(nil, "ARTWORK")
    -- Parented to Extended - Middle Frame
    visual.raidicon = textFrame:CreateTexture(nil, "ARTWORK", 5)
    visual.skullicon = textFrame:CreateTexture(nil, "ARTWORK", 2)
    visual.eliteicon = textFrame:CreateTexture(nil, "ARTWORK", 1)
    visual.target = textFrame:CreateTexture(nil, "BACKGROUND") -- next visual.highlight -5?
		-- TextFrame
    visual.name  = textFrame:CreateFontString(nil, "ARTWORK", 0)
    visual.customtext = textFrame:CreateFontString(nil, "ARTWORK", -1)
		visual.level = textFrame:CreateFontString(nil, "ARTWORK", -2)
		-- Cast Bar Frame - Highest Frame
    visual.spellicon = castbar:CreateTexture(nil, "BACKGROUND", 7)
    visual.castnostop = castbar:CreateTexture(nil, "BACKGROUND", 2)
    visual.castborder = castbar:CreateTexture(nil, "BACKGROUND", 1)
		visual.spelltext = castbar:CreateFontString(nil, "BACKGROUND")
		-- Set Base Properties
		visual.raidicon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
		visual.highlight:SetAllPoints(visual.healthborder)
		visual.highlight:SetBlendMode("ADD")

		extended:SetFrameStrata("BACKGROUND")
		healthbar:SetFrameStrata("BACKGROUND")
		castbar:SetFrameStrata("BACKGROUND")
		textFrame:SetFrameStrata("BACKGROUND")
    --widgetParent:SetFrameStrata("BACKGROUND")

    castbar:SetFrameLevel(extended:GetFrameLevel() - 1)
    healthbar:SetFrameLevel(extended:GetFrameLevel())
    textFrame:SetFrameLevel(extended:GetFrameLevel() + 1)

		castbar:Hide()
		castbar:SetStatusBarColor(1,.8,0)
		carrier:SetSize(16, 16)

    -- Tidy Plates Frame References
		extended.visual = visual

		-- Allocate Tables
		extended.style,
		extended.unit,
		extended.unitcache,
		extended.stylecache,
		extended.widgets
			= {}, {}, {}, {}, {}

		extended.stylename = ""

		carrier:SetPoint("CENTER", plate, "CENTER")
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
		if activetheme.SetStyle then				-- If the active theme has a style selection function, run it..
			stylename = activetheme.SetStyle(unit)
			extended.style = activetheme[stylename]
		else 										-- If no style function, use the base table
			extended.style = activetheme;
			stylename = tostring(activetheme)
		end

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
			if unitchanged or UpdateAll or (not style)then --
				CheckNameplateStyle()
				UpdateIndicator_Standard()
				UpdateIndicator_HealthBar()
				UpdateIndicator_Target()
			end

			-- Update Widgets
			if activetheme.OnUpdate then activetheme.OnUpdate(extended, unit) end

			-- Update Delegates
			UpdateIndicator_ThreatGlow()
			UpdateIndicator_CustomAlpha()
			UpdateIndicator_CustomScaleText()

			-- Cache the old unit information
			UpdateUnitCache()
	end

--[[
	local function HideWidgets(plate)
		if plate.TP_Extended and plate.TP_Extended.widgets then
			local widgetTable = plate.TP_Extended.widgets
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

		-- or unitid = plate.namePlateUnitToken
		UpdateReferences(plate)

		carrier:Show()

		PlatesVisible[plate] = unitid
		PlatesByUnit[unitid] = plate

		unit.frame = extended
		unit.alpha = 0
		unit.isTarget = false
		unit.isMouseover = false
		unit.unitid = plateid
		extended.unitcache = ClearIndices(extended.unitcache)
		extended.stylename = ""
		extended.Active = true

		visual.highlight:Hide()

		wipe(extended.unit)
		wipe(extended.unitcache)


		-- For Fading In
		PlatesFading[plate] = EnableFadeIn
		extended.requestedAlpha = 0
		--extended.visibleAlpha = 0
		extended:Hide()		-- Yes, it seems counterintuitive, but...
		extended:SetAlpha(0)

		-- Graphics
		unit.isCasting = false
		visual.castbar:Hide()
		visual.highlight:Hide()


		-- Widgets/Extensions
		-- This goes here because a user might change widget settings after nameplates have been created
		if activetheme.OnInitialize then activetheme.OnInitialize(extended, activetheme) end

		-- Skip the initial data gather and let the second cycle do the work.
		plate.UpdateMe = true
	end


	-- OnHideNameplate
	function OnHideNameplate(plate, unitid)
		--plate.TP_Extended:Hide()
		plate.TP_Carrier:Hide()

		UpdateReferences(plate)

		extended.Active = false

		PlatesVisible[plate] = nil
		PlatesByUnit[unitid] = nil

		visual.castbar:Hide()
		visual.castbar:SetScript("OnUpdate", nil)
		unit.isCasting = false

		-- Remove anything from the function queue
		plate.UpdateMe = false

		for widgetname, widget in pairs(extended.widgets) do widget:Hide() end
	end

	-- OnUpdateNameplate
	function OnUpdateNameplate(plate)
		-- And stay down!
		-- plate:GetChildren():Hide()

		-- Gather Information
		local unitid = PlatesVisible[plate]
		UpdateReferences(plate)

		UpdateUnitIdentity(unitid)
		UpdateUnitContext(plate, unitid)
		ProcessUnitChanges()
		OnUpdateCastMidway(plate, unitid)

--    if unit.unitid and UnitIsUnit("target", unit.unitid) then
--      visual.castbar:Show()
--      visual.castnostop:Show()
--      visual.castborder:Show()
--      visual.spellicon:SetTexture(GetSpellTexture("Mondfeuer"))
--      visual.spellicon:Show()
--      visual.spelltext:SetText("Moonfire")
--      visual.spelltext:Show()
--    end
	end

	-- OnHealthUpdate
	function OnHealthUpdate(plate)
		local unitid = PlatesVisible[plate]

		UpdateUnitCondition(plate, unitid)
		ProcessUnitChanges()
		UpdateIndicator_HealthBar()		-- Just to be on the safe side
  end


     -- OnResetNameplate
	function OnResetNameplate(plate)
		local extended = plate.TP_Extended
		plate.UpdateMe = true
		extended.unitcache = ClearIndices(extended.unitcache)
		extended.stylename = ""
		local unitid = PlatesVisible[plate]

		OnShowNameplate(plate, unitid)
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
		local guid

		UpdateReferences(plate)

		unit.isMouseover = UnitIsUnit("mouseover", unitid)
		unit.isTarget = UnitIsUnit("target", unitid)
		unit.isFocus = UnitIsUnit("focus", unitid)

		unit.guid = UnitGUID(unitid)

		UpdateUnitCondition(plate, unitid)	-- This updates a bunch of properties

		if activetheme.OnContextUpdate then activetheme.OnContextUpdate(extended, unit) end
		if activetheme.OnUpdate then activetheme.OnUpdate(extended, unit) end
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

	-- OnRequestWidgetUpdate: Calls Update on just the Widgets
	function OnRequestWidgetUpdate(plate)
		if not IsPlateShown(plate) then return end
		UpdateReferences(plate)
		if activetheme.OnContextUpdate then activetheme.OnContextUpdate(extended, unit) end
		if activetheme.OnUpdate then activetheme.OnUpdate(extended, unit) end
	end

	-- OnRequestDelegateUpdate: Updates just the delegate function indicators
	function OnRequestDelegateUpdate(plate)
			if not IsPlateShown(plate) then return end
			UpdateReferences(plate)
			UpdateIndicator_ThreatGlow()
			UpdateIndicator_CustomAlpha()
			UpdateIndicator_CustomScaleText()
	end


end		-- End of Nameplate/Unit Events


---------------------------------------------------------------------------------------------------------------------
-- Indicators: These functions update the color, texture, strings, and frames within a style.
---------------------------------------------------------------------------------------------------------------------
do
	local color = {}
	local threatborder, alpha, forcealpha, scale


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
		if activetheme.SetNameColor then
			visual.name:SetTextColor(activetheme.SetNameColor(unit))
		else visual.name:SetTextColor(1,1,1,1) end
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
		if not style.threatborder.show then return end
		threatborder = visual.threatborder
		if activetheme.SetThreatColor then

			threatborder:SetVertexColor(activetheme.SetThreatColor(unit) )
		else
			if InCombat and unit.reaction ~= "FRIENDLY" and unit.type == "NPC" then
				local color = style.threatcolor[unit.threatSituation]
				threatborder:Show()
				threatborder:SetVertexColor(color.r, color.g, color.b, (color.a or 1))
			else threatborder:Hide() end
		end
	end


	-- UpdateIndicator_Target
	function UpdateIndicator_Target()
		if unit.isTarget and style.target.show then visual.target:Show() else visual.target:Hide() end
		if unit.isMouseover and not unit.isTarget then visual.highlight:Show() else visual.highlight:Hide() end
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
		threatborder = visual.threatborder
		if unit.isElite and style.eliteicon.show then visual.eliteicon:Show() else visual.eliteicon:Hide() end
	end


	-- UpdateIndicator_UnitColor: Update the health bar coloring, if needed
	function UpdateIndicator_UnitColor()
		-- Set Health Bar
		if activetheme.SetHealthbarColor then
			visual.healthbar:SetAllColors(activetheme.SetHealthbarColor(unit))

		else visual.healthbar:SetStatusBarColor(unit.red, unit.green, unit.blue) end

		-- Name Color
		if activetheme.SetNameColor then
			visual.name:SetTextColor(activetheme.SetNameColor(unit))
		else visual.name:SetTextColor(1,1,1,1) end
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
		if activetheme.SetAlpha then
			--local previousAlpha = extended.requestedAlpha
			extended.requestedAlpha = activetheme.SetAlpha(unit) or previousAlpha or unit.alpha or 1
		else
			extended.requestedAlpha = unit.alpha or 1
		end

		if extended.requestedAlpha > 0 then
			extended:SetAlpha(extended.requestedAlpha)
			if nameplate:IsShown() then extended:Show() end
		else
			extended:Hide()        -- FRAME HIDE TEST
		end
	end


	-- UpdateIndicator_CustomScaleText: Updates indicators for custom text and scale
	function UpdateIndicator_CustomScaleText()
		threatborder = visual.threatborder

		if unit.health and (extended.requestedAlpha > 0) then
			-- Scale
			if activetheme.SetScale then
				scale = activetheme.SetScale(unit)
				if scale then extended:SetScale( scale )end
			end

			-- Set Special-Case Regions
			if style.customtext.show then
				if activetheme.SetCustomText then
					local text, r, g, b, a = activetheme.SetCustomText(unit)
					visual.customtext:SetText( text or "")
					visual.customtext:SetTextColor(r or 1, g or 1, b or 1, a or 1)
				else visual.customtext:SetText("") end
			end

			UpdateIndicator_UnitColor()
		end
	end


	local function OnUpdateCastBarForward(self)
		local currentTime = GetTime() * 1000
		--local startTime, endTime = self:GetMinMaxValues()

		--if currentTime > endTime then OnStopCasting(self)
		--else self:SetValue(currentTime) end

		self:SetValue(currentTime)
	end


	local function OnUpdateCastBarReverse(self)
		local currentTime = GetTime() * 1000
		local startTime, endTime = self:GetMinMaxValues()

		--if currentTime > endTime then OnStopCasting(self)
		--else self:SetValue((endTime + startTime) - currentTime) end

		self:SetValue((endTime + startTime) - currentTime)
	end



	-- OnShowCastbar
	function OnStartCasting(plate, unitid, channeled)
		UpdateReferences(plate)
		--if not extended:IsShown() then return end
		if not extended:IsShown() then return end

		local castBar = extended.visual.castbar

		local name, subText, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible

		if channeled then
			name, subText, text, texture, startTime, endTime, isTradeSkill, notInterruptible = UnitChannelInfo(unitid)
			castBar:SetScript("OnUpdate", OnUpdateCastBarReverse)
		else
			name, subText, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unitid)
			castBar:SetScript("OnUpdate", OnUpdateCastBarForward)
		end

		if isTradeSkill then return end

		unit.isCasting = true
		unit.spellIsShielded = notInterruptible
		unit.spellInterruptible = not unit.spellIsShielded

		visual.spelltext:SetText(text)
		visual.spellicon:SetTexture(texture)
    visual.spellicon:SetDrawLayer("BACKGROUND", 7)
		castBar:SetMinMaxValues( startTime, endTime )

		local r, g, b, a = 1, 1, 0, 1

    castBar:SetAllColors(activetheme.SetCastbarColor(unit))

		if unit.spellIsShielded then
			   visual.castnostop:Show(); visual.castborder:Hide()
		else visual.castnostop:Hide(); visual.castborder:Show() end

		UpdateIndicator_CustomScaleText()
		UpdateIndicator_CustomAlpha()

		castBar:Show()

	end


	-- OnHideCastbar
	function OnStopCasting(plate)

		UpdateReferences(plate)

		if not extended:IsShown() then return end
		local castBar = extended.visual.castbar

		castBar:Hide()
		castBar:SetScript("OnUpdate", nil)

		unit.isCasting = false
		UpdateIndicator_CustomScaleText()
		UpdateIndicator_CustomAlpha()
	end



	function OnUpdateCastMidway(plate, unitid)
		if not ShowCastBars then return end

		local currentTime = GetTime() * 1000

		-- Check to see if there's a spell being cast
		if UnitCastingInfo(unitid) then OnStartCasting(plate, unitid, false)
		else
		-- See if one is being channeled...
			if UnitChannelInfo(unitid) then OnStartCasting(plate, unitid, true) end
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

  local function UnitNameUpdate(event, unitid)
    if UnitIsUnit("player", unitid) then return end -- skip personal resource bar

    local plate = GetNamePlateForUnit(unitid)
    if plate then
      UpdateReferences(plate)

      if unit.name == UNKNOWNOBJECT then
        unit.name = UnitName(unitid) or ""
        UpdateIndicator_Name()
      end
    end
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

	function CoreEvents:NAME_PLATE_CREATED(...)
		local plate = ...
		local BlizzardFrame = plate:GetChildren()

		-- hooksecurefunc([table,] "function", hookfunc)

		--BlizzardFrame._Show = BlizzardFrame.Show	-- Store this for later
		--BlizzardFrame.Show = BlizzardFrame.Hide			-- Try this to keep the plate from showing up
		-- --BlizzardFrame.Show = BypassFunction			-- Try this to keep the plate from showing up
		OnNewNameplate(plate)
	 end

	function CoreEvents:NAME_PLATE_UNIT_ADDED(...)
		local unitid = ...
		local plate = GetNamePlateForUnit(unitid);

		-- Personal Display
		if UnitIsUnit("player", unitid) then
			-- plate:GetChildren():_Show()
		-- Normal Plates
		else
			plate:GetChildren():Hide()
			OnShowNameplate(plate, unitid)
		end

	end

	function CoreEvents:NAME_PLATE_UNIT_REMOVED(...)
		local unitid = ...
		local plate = GetNamePlateForUnit(unitid);

		OnHideNameplate(plate, unitid)
	end

	function CoreEvents:PLAYER_TARGET_CHANGED()
		HasTarget = UnitExists("target") == true;
		SetUpdateAll()
	end

	function CoreEvents:UNIT_HEALTH_FREQUENT(...)
		local unitid = ...
		local plate = PlatesByUnit[unitid]

		if plate then OnHealthUpdate(plate) end
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

	function CoreEvents:UNIT_SPELLCAST_START(...)
		local unitid = ...

 		if UnitIsUnit("player", unitid) or not ShowCastBars then return end

		local plate = GetNamePlateForUnit(unitid)

		if plate then
			OnStartCasting(plate, unitid, false)
		end
	end


	 function CoreEvents:UNIT_SPELLCAST_STOP(...)
		local unitid = ...
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

  -- The following events should not have worked before adjusting UnitSpellcastMidway
	CoreEvents.UNIT_SPELLCAST_DELAYED = UnitSpellcastMidway
	CoreEvents.UNIT_SPELLCAST_CHANNEL_UPDATE = UnitSpellcastMidway
	CoreEvents.UNIT_SPELLCAST_INTERRUPTIBLE = UnitSpellcastMidway
	CoreEvents.UNIT_SPELLCAST_NOT_INTERRUPTIBLE = UnitSpellcastMidway

	CoreEvents.UNIT_LEVEL = UnitConditionChanged
	--CoreEvents.UNIT_THREAT_SITUATION_UPDATE = UnitConditionChanged -- did not work anyway (no unitid)
	CoreEvents.UNIT_FACTION = WorldConditionChanged
  CoreEvents.UNIT_NAME_UPDATE = UnitNameUpdate

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
	local function SetObjectShape(object, width, height) object:SetWidth(width); object:SetHeight(height) end
	local function SetObjectJustify(object, horz, vert) object:SetJustifyH(horz); object:SetJustifyV(vert) end
	local function SetObjectAnchor(object, anchor, anchorTo, x, y) object:ClearAllPoints();object:SetPoint(anchor, anchorTo, anchor, x, y) end
	local function SetObjectTexture(object, texture) object:SetTexture(texture) end
	local function SetObjectBartexture(obj, tex, ori, crop) obj:SetStatusBarTexture(tex); obj:SetOrientation(ori); end

	local function SetObjectFont(object,  font, size, flags)
		if (not OverrideFonts) and font then
			object:SetFont(font, size or 10, flags)
		--else
		--	object:SetFontObject("SpellFont_Small")
		end
	end --FRIZQT__ or ARIALN.ttf  -- object:SetFont("FONTS\\FRIZQT__.TTF", size or 12, flags)


	-- SetObjectShadow:
	local function SetObjectShadow(object, shadow)
		if shadow then
			object:SetShadowColor(0,0,0, 1)
			object:SetShadowOffset(1, -1)
		else object:SetShadowColor(0,0,0,0) end
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
			if objectstyle.texture then SetObjectTexture(object, objectstyle.texture or EMPTY_TEXTURE) end
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

	local anchorgroup = {"healthborder", "threatborder", "castborder", "castnostop",
						"name",  "spelltext", "customtext", "level",
						"spellicon", "raidicon", "skullicon", "eliteicon", "target"}

	local bargroup = {"castbar", "healthbar"}

	local texturegroup = { "castborder", "castnostop", "healthborder", "threatborder", "eliteicon",
						"skullicon", "highlight", "target", "spellicon", }
--  local texturegroup = {
--    { "castborder",   "BACKGROUND", 1 },
--    { "castnostop",   "BACKGROUND", 2 },
--    { "spellicon",    "BACKGROUND", 7 },
--    { "healthborder", "BORDER", 0 },
--    { "threatborder", "BORDER", 2 },
--    { "highlight",    "ARTWORK", 0 },
--    { "eliteicon",    "ARTWORK", 1 },
--    { "skullicon",    "ARTWORK", 2 },
--    { "target",       "BACKGROUND", 0 },
--  }

	-- UpdateStyle:
	function UpdateStyle()
		local index

		-- Frame
		SetAnchorGroupObject(extended, style.frame, carrier)

		-- Anchorgroup
		for index = 1, #anchorgroup do
			local objectname = anchorgroup[index]
			local object, objectstyle = visual[objectname], style[objectname]
			if objectstyle and objectstyle.show then
				SetAnchorGroupObject(object, objectstyle, extended)
				visual[objectname]:Show()
			else visual[objectname]:Hide() end
		end

		-- Bars
		for index = 1, #bargroup do
			local objectname = bargroup[index]
			local object, objectstyle = visual[objectname], style[objectname]
			if objectstyle then SetBarGroupObject(object, objectstyle, extended) end
		end
		-- Texture
    for index = 1, #texturegroup do
      local objectname = texturegroup[index]
      local object, objectstyle = visual[objectname], style[objectname]
      SetTextureGroupObject(object, objectstyle)
    end
--		for index = 1, #texturegroup do
--			local objectname = texturegroup[index][1]
--			local object, objectstyle = visual[objectname], style[objectname]
--			SetTextureGroupObject(object, objectstyle)
--      --object:SetDrawLayer(texturegroup[index][2], texturegroup[index][3])
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
		-- Hide Stuff
		if not unit.isElite then visual.eliteicon:Hide() end
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

addon.UseTheme = UseTheme

local function GetTheme()
	return activetheme
end

TidyPlatesInternal.GetTheme = GetTheme

--------------------------------------------------------------------------------------------------------------
-- Misc. Utility
--------------------------------------------------------------------------------------------------------------
local function OnResetWidgets(plate)
	-- At some point, we're going to have to manage the widgets a bit better.

	local extended = plate.TP_Extended
	local widgets = extended.widgets

	for widgetName, widgetFrame in pairs(widgets) do
		widgetFrame:Hide()
		--widgets[widgetName] = nil			-- Nilling the frames may cause leakiness.. or at least garbage collection
	end

	plate.UpdateMe = true
end

--------------------------------------------------------------------------------------------------------------
-- External Commands: Allows widgets and themes to request updates to the plates.
-- Useful to make a theme respond to externally-captured data (such as the combat log)
--------------------------------------------------------------------------------------------------------------
function TidyPlatesInternal:DisableCastBars() ShowCastBars = false end
function TidyPlatesInternal:EnableCastBars() ShowCastBars = true end

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
