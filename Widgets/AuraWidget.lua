local ADDON_NAME, NAMESPACE = ...
ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local RGB = ThreatPlates.RGB
local DEBUG = ThreatPlates.DEBUG


---------------------------------------------------------------------------------------------------
-- Aura Widget 2.0
---------------------------------------------------------------------------------------------------

	--Spinning Cooldown Frame
	--[[
	frame.Cooldown = CreateFrame("Cooldown", nil, frame, "TidyPlatesAuraWidgetCooldown")
	frame.Cooldown:SetAllPoints(frame)
	frame.Cooldown:SetReverse(true)
	frame.Cooldown:SetHideCountdownNumbers(true)
	--]]


TidyPlatesWidgets.DebuffWidgetBuild = 2

local PlayerGUID = UnitGUID("player")
local FilterFunction = function() return 1 end
local AuraMonitor = CreateFrame("Frame")
local WatcherIsEnabled = false
local WidgetList, WidgetGUID = {}, {}

local UpdateWidget

local TargetOfGroupMembers = {}
local inArena = false

local AuraLimit
local useWideIcons = false
local config_bar_mode = false
local config_grid_rows = 3
local config_grid_columns = 3
local config_grid_row_spacing = 5
local config_grid_column_spacing = 8
local config_max_label_text_length = 0

local function DummyFunction() end

local function DefaultPreFilterFunction() return true end
local function DefaultFilterFunction(aura, unit) if aura and aura.duration and (aura.duration < 30) then return true end end

local AuraFilterFunction = DefaultFilterFunction
local AuraHookFunction

local AURA_TARGET_HOSTILE = 1
local AURA_TARGET_FRIENDLY = 2

local AURA_TYPE_BUFF = 1
local AURA_TYPE_DEBUFF = 6

-- Get a clean version of the function...  Avoid OmniCC interference
local CooldownNative = CreateFrame("Cooldown", nil, WorldFrame)
local SetCooldown = CooldownNative.SetCooldown

local font_frame = CreateFrame("Frame", nil, WorldFrame)

local AuraType_Index = {
	["Buff"] = 1,
	["Curse"] = 2,
	["Disease"] = 3,
	["Magic"] = 4,
	["Poison"] = 5,
	["Debuff"] = 6,
}

local function SetFilter(func)
	if func and type(func) == "function" then
		FilterFunction = func
	end
end

local function GetAuraWidgetByGUID(guid)
	if guid then return WidgetGUID[guid] end
end

local function IsAuraShown(widget, aura)
		if widget and widget:IsShown() then
			return true
		end
end

---------------------------------------------------------------------------------------------------
-- PolledHideIn() - Registers a callback, which polls the frame until it expires, then hides the frame and removes the callback
---------------------------------------------------------------------------------------------------

local updateInterval = .5
local PolledHideIn
local Framelist = {}			-- Key = Frame, Value = Expiration Time
local Watcherframe = CreateFrame("Frame")
local WatcherframeActive = false
local select = select
local timeToUpdate = 0

local function CheckFramelist(self)
	local curTime = GetTime()
	if curTime < timeToUpdate then return end
	local framecount = 0
	timeToUpdate = curTime + updateInterval
	-- Cycle through the watchlist, hiding frames which are timed-out
	for frame, expiration in pairs(Framelist) do
		-- If expired...
		if expiration < curTime and frame.AuraInfo.Duration > 0 then
			if frame.Expire then frame:Expire() end

			frame:Hide()
			Framelist[frame] = nil
			--TidyPlates:RequestDelegateUpdate()		-- Request an Update on Delegate functions, so we can catch when auras fall off
		-- If still active...
		else
			-- Update the frame
			if frame.Poll then frame:Poll(expiration) end
			framecount = framecount + 1
		end
	end
	-- If no more frames to watch, unregister the OnUpdate script
	if framecount == 0 then Watcherframe:SetScript("OnUpdate", nil); WatcherframeActive = false end
end

local function PolledHideIn(frame, expiration)

	--frame.AuraInfo.Duration == 0
	if not expiration then
		frame:Hide()
		Framelist[frame] = nil
	else
		--print("Hiding in", expiration - GetTime())
		Framelist[frame] = expiration
		frame:Show()

		if not WatcherframeActive then
			Watcherframe:SetScript("OnUpdate", CheckFramelist)
			WatcherframeActive = true
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local isAuraEnabled

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
	-- for _, widget in pairs(WidgetList) do
	-- 	widget:Hide()
	-- end
	-- WidgetList = {}
-- end
-- ThreatPlatesWidgets.ClearAllAuraWidgets = ClearAllWidgets



---------------------------------------------------------------------------------------------------
-- Filtering and sorting functions
---------------------------------------------------------------------------------------------------

-- Information from Widget:
-- aura.spellid, aura.name, aura.expiration, aura.stacks,
-- aura.caster, aura.duration, aura.texture,
-- aura.type, aura.reaction
-- return value: show, priority, r, g, b (color for ?)

-- Debuffs are color coded, with poison debuffs having a green border, magic debuffs a blue border, diseases a brown border,
-- urses a purple border, and physical debuffs a red border
local AURA_TYPE = { Buff = 1, Curse = 2, Disease = 3, Magic = 4, Poison = 5, Debuff = 6, }

local AURA_TYPE_COLORS = {
		Curse = RGB(255, 0, 255),
		Disease = RGB(128, 51, 0),
		Magic = RGB(0, 102, 255),
		Poison = RGB(0, 255, 0),
	}

local Filter_ByAuraList

local function GetColorForAura(aura)
	local db = TidyPlatesThreat.db.profile.AuraWidget

	local color
	if aura.effect == "HARMFUL" then
		color = db.DefaultDebuffColor
	else
		color = db.DefaultBuffColor
	end

	if db.ShowAuraType then
		color = AURA_TYPE_COLORS[aura.type] or color
	end

	return color
end

local function AuraFilter(aura)
	local db = TidyPlatesThreat.db.profile.AuraWidget
	local isType, isShown

	if aura.reaction == AURA_TARGET_HOSTILE and db.ShowEnemy then
		isShown = true
	elseif aura.reaction == AURA_TARGET_FRIENDLY and db.ShowFriendly then
		isShown = true
	end

	if aura.effect == "HELPFUL" and db.FilterByType[AURA_TYPE.Buff] then
		isType = true
	elseif aura.effect == "HARMFUL" and db.FilterByType[AURA_TYPE.Debuff] then
		-- only show aura types configured in the options
		if aura.type then
			isType = db.FilterByType[AURA_TYPE[aura.type]]
		else
			isType = true
		end
	end

	local show_aura = false
	if isShown and isType then
		local mode = db.FilterMode
		local spellfound = Filter_ByAuraList[aura.name] or Filter_ByAuraList[aura.spellid]
		if spellfound then spellfound = true end
		local isMine = (aura.caster == "player") or (aura.caster == "pet")

		if mode == "whitelist" then
			show_aura = spellfound
		elseif mode == "whitelistMine" then
			if isMine then
				show_aura = spellfound
			end
		elseif mode == "all" then
			show_aura = true
		elseif mode == "allMine" then
			if isMine then
				show_aura = true
			end
		elseif mode == "blacklist" then
			show_aura = not spellfound
		elseif mode == "blacklistMine" then
			if isMine then
				show_aura = not spellfound
			end
		end
	end

	local color = GetColorForAura(aura)

	local priority = aura.expiration - aura.duration

	if db.SortOrder == "AtoZ" then
		priority = aura.name
	elseif db.SortOrder == "TimeLeft" then
		priority = aura.expiration - GetTime()
	elseif db.SortOrder == "Duration" then
		priority = aura.duration
	end

 	return show_aura, priority, color
end

local function PrepareFilter()
	local filter = TidyPlatesThreat.db.profile.AuraWidget.FilterBySpell
	Filter_ByAuraList = {}

	for key, value in pairs(filter) do
		-- remove comments and whitespaces from the filter (string)
		local pos = value:find("%-%-")
		if pos then value = value:sub(1, pos - 1) end
		value = value:match("^%s*(.-)%s*$")

		-- separete filter by name and ID for more efficient aura filtering
		local value_no = tonumber(value)
		if value_no then
			Filter_ByAuraList[value_no] = true
		elseif value ~= '' then
			Filter_ByAuraList[value] = true
		end
	end
end

-----------------------------------------------------
-- Default Filter
-----------------------------------------------------
local function DefaultFilterFunction(debuff)
	if (debuff.duration < 600) then
		return true
	end
end

-----------------------------------------------------
-- General Events
-----------------------------------------------------

local function EventUnitAura(unitid)
	local frame

	if unitid then frame = WidgetList[unitid] end

	--print ("EventUnitAura: ", frame, unitid)
	if frame then UpdateWidget(frame) end

end

-----------------------------------------------------
-- Function Reference Lists
-----------------------------------------------------

local AuraEvents = {
	--["UNIT_TARGET"] = EventUnitTarget,
	["UNIT_AURA"] = EventUnitAura,
}

local function AuraEventHandler(frame, event, ...)
	local unitid = ...

	if event then
		local eventFunction = AuraEvents[event]
		eventFunction(...)
	end

end

-------------------------------------------------------------
-- Widget Object Functions
-------------------------------------------------------------

local function UpdateWidgetTimeIcon(frame, expiration)
	if expiration == 0 then
		frame.TimeLeft:SetText("")
	else
		local timeleft = expiration - GetTime()
		if timeleft > 60 then
			frame.TimeLeft:SetText(floor(timeleft/60).."m")
		else
			frame.TimeLeft:SetText(floor(timeleft))
			--frame.TimeLeft:SetText(floor(timeleft*10)/10)
		end
	end
end

local function UpdateWidgetTimeBar(frame, expiration)
	if frame.AuraInfo.Duration == 0 then
		frame.TimeText:SetText("")
		frame.Statusbar:SetValue(100)
	elseif expiration == 0 then
		frame.TimeText:SetText("")
		frame.Statusbar:SetValue(0)
	else
		local timeleft = expiration - GetTime()
		if timeleft > 60 then
			frame.TimeText:SetText(floor(timeleft/60).."m")
		else
			frame.TimeText:SetText(floor(timeleft))
		end
		frame.Statusbar:SetValue(timeleft * 100 / frame.AuraInfo.Duration)
	end
end

local function UpdateWidgetTime(frame, expiration)
	if config_bar_mode then
		UpdateWidgetTimeBar(frame, expiration)
	else
		UpdateWidgetTimeIcon(frame, expiration)
	end
end

local function UpdateAuraFrame(frame, texture, duration, expiration, stacks, color)
	if frame and texture and expiration then
		local db = TidyPlatesThreat.db.profile.AuraWidget.ModeBar

		-- Expiration
		UpdateWidgetTime(frame, expiration)

		if config_bar_mode then
			frame.Statusbar:SetWidth(db.BarWidth)

			-- Icon
			if db.ShowIcon then
				frame.Icon:SetTexture(texture)
			end

			frame.LabelText:SetWidth(config_max_label_text_length - frame.TimeText:GetStringWidth())
			if stacks and stacks > 1 then
				frame.LabelText:SetText(frame.AuraInfo.Name .. " [" .. stacks .. "]")
			else
				frame.LabelText:SetText(frame.AuraInfo.Name)
			end

			-- Highlight Coloring
			frame.Statusbar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
		else
			frame.Icon:SetTexture(texture)

			if stacks and stacks > 1 then
				frame.Stacks:SetText(stacks)
			else
				frame.Stacks:SetText("")
			end

			-- Highlight Coloring
			if TidyPlatesThreat.db.profile.AuraWidget.ShowAuraType then
				frame.BorderHighlight:SetVertexColor(color.r, color.g, color.b)
				frame.BorderHighlight:Show()
				frame.Border:Hide()
			else
				frame.BorderHighlight:Hide()
				frame.Border:Show()
			end

			-- [[ Cooldown
			if duration and duration > 0 and expiration and expiration > 0 then
				SetCooldown(frame.Cooldown, expiration-duration, duration+.25)
			end
			--]]
		end

		--frame:Show()
		PolledHideIn(frame, expiration)
	elseif frame then
		PolledHideIn(frame)
	end
end

local function AuraSortFunction(a,b)
	local db = TidyPlatesThreat.db.profile.AuraWidget
	if db.SortReverse then
		return a.priority > b.priority
	else
		return a.priority < b.priority
	end
end

local function UpdateIconGrid(frame, unitid)

		if not unitid then return end

		local unitReaction
		if UnitIsFriend("player", unitid) then unitReaction = AURA_TARGET_FRIENDLY
		else unitReaction = AURA_TARGET_HOSTILE end

		local AuraFrames = frame.AuraFrames
		local storedAuras = {}
		local storedAuraCount = 0

		-- Cache displayable auras
		------------------------------------------------------------------------------------------------------
		-- This block will go through the auras on the unit and make a list of those that should
		-- be displayed, listed by priority.
		local auraIndex = 0
		local moreAuras = true

		local searchedDebuffs, searchedBuffs = false, false
		local auraFilter = "HARMFUL"

		repeat

			auraIndex = auraIndex + 1

			local aura = {}

			do
				local name, _, icon, stacks, auraType, duration, expiration, caster, _, _, spellid = UnitAura(unitid, auraIndex, auraFilter)		-- UnitaAura

				aura.name = name
				aura.texture = icon
				aura.stacks = stacks
				aura.type = auraType
				aura.effect = auraFilter
				aura.duration = duration
				aura.reaction = unitReaction
				aura.expiration = expiration
				aura.caster = caster
				aura.spellid = spellid
				aura.unit = unitid 		-- unitid of the plate
			end

			-- Gnaw , false, icon, 0 stacks, nil type, duration 1, expiration 8850.436, caster pet, false, false, 91800

			-- Auras are evaluated by an external function
			-- Pre-filtering before the icon grid is populated
			if aura.name then
				local show, priority, color = AuraFilterFunction(aura)
				-- Store Order/Priority
				if show then
					aura.priority = priority or 10
					aura.color = color

					storedAuraCount = storedAuraCount + 1
					storedAuras[storedAuraCount] = aura
				end
			else
				if auraFilter == "HARMFUL" then
					searchedDebuffs = true
					auraFilter = "HELPFUL"
					auraIndex = 0
				else
					searchedBuffs = true
				end
			end

		until (searchedDebuffs and searchedBuffs)

		-- Display Auras
		------------------------------------------------------------------------------------------------------
		local AuraSlotCount = 1
		if storedAuraCount > 0 then
			--frame:Show()
			sort(storedAuras, AuraSortFunction)

			for index = 1, storedAuraCount do
				if AuraSlotCount > AuraLimit then break end
				local aura = storedAuras[index]
				if aura.spellid and aura.expiration then

				  local aura_frame = AuraFrames[AuraSlotCount]
					aura_frame.AuraInfo.Duration = aura.duration
					aura_frame.AuraInfo.Name = aura.name

					-- Call function to display the aura
					UpdateAuraFrame(aura_frame, aura.texture, aura.duration, aura.expiration, aura.stacks, aura.color)

					AuraSlotCount = AuraSlotCount + 1
					frame.currentAuraCount = index
				end
			end

		end

		-- Clear Extra Slots
		for index = AuraSlotCount, AuraLimit do UpdateAuraFrame(AuraFrames[index]) end
end

function UpdateWidget(frame)
	local db = TidyPlatesThreat.db.profile.AuraWidget

	UpdateIconGrid(frame, frame.unitid)

	frame:SetScale(db.scale)
	-- if not frame.Background then
	-- 	frame.Background = frame:CreateTexture(nil, "BACKGROUND")
	-- 	frame.Background:SetAllPoints()
	-- 	frame.Background:SetTexture(ThreatPlates.Media:Fetch('statusbar', db.BackgroundTexture))
	-- 	frame.Background:SetVertexColor(0,0,0,1)
	-- end
	if db.ModeBar.Enabled then
		frame:SetPoint("CENTER", frame:GetParent(), 0, db.y)
	else
		frame:SetPoint(db.anchor, frame:GetParent(), db.x, db.y)
	end
end

local function ClearWidgetContext(frame)
	for unitid, widget in pairs(WidgetList) do
		if frame == widget then WidgetList[unitid] = nil end
	end
end

local function ExpireFunction(icon)
	-- local frame = icon.Parent
	UpdateWidget(icon:GetParent())
end

-------------------------------------------------------------
-- Widget Frames
-------------------------------------------------------------
local WideArt = "Interface\\AddOns\\TidyPlatesWidgets\\Aura\\AuraFrameWide"
local SquareArt = "Interface\\AddOns\\TidyPlatesWidgets\\Aura\\AuraFrameSquare"
local WideHighlightArt = "Interface\\AddOns\\TidyPlatesWidgets\\Aura\\AuraFrameHighlightWide"
local SquareHighlightArt = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\AuraWidget\\AuraFrameHighlightSquare"
local AuraFont = "FONTS\\ARIALN.TTF"

local function Enable()
	AuraMonitor:SetScript("OnEvent", AuraEventHandler)

	for event in pairs(AuraEvents) do AuraMonitor:RegisterEvent(event) end

	--TidyPlatesUtility:EnableGroupWatcher()
	WatcherIsEnabled = true
end

local function Disable()
	AuraMonitor:SetScript("OnEvent", nil)
	AuraMonitor:UnregisterAllEvents()
	WatcherIsEnabled = false
end

local function enabled()
	local active = (not TidyPlatesThreat.db.profile.debuffWidget.ON) and TidyPlatesThreat.db.profile.AuraWidget.ON

	if active then
		if not isAuraEnabled then
			Enable()
			isAuraEnabled = true
		end
	else
		if isAuraEnabled then
			Disable()
			isAuraEnabled = false
		end
	end

	return active
end
---------------------------------------------------------------------------------------------------
-- Functions for icon mode
---------------------------------------------------------------------------------------------------

local function TransformWideAura(frame)
	frame:SetWidth(26.5)
	frame:SetHeight(14.5)
	-- Icon
	frame.Icon:SetAllPoints(frame)
	frame.Icon:SetTexCoord(.07, 1-.07, .23, 1-.23)  -- obj:SetTexCoord(left,right,top,bottom)
	-- Border
	frame.Border:SetWidth(32);
	frame.Border:SetHeight(32)
	frame.Border:SetPoint("CENTER", 1, -2)
	frame.Border:SetTexture(WideArt)
	-- Highlight
	--frame.BorderHighlight:SetAllPoints(frame.Border)
	-- frame.BorderHighlight:SetTexture(WideHighlightArt)
	frame.BorderHighlight:SetWidth(32);
	frame.BorderHighlight:SetHeight(32)
	frame.BorderHighlight:SetPoint("CENTER", 1, -2)
	frame.BorderHighlight:SetTexture(WideHighlightArt)
	--  Time Text
	frame.TimeLeft:SetFont(AuraFont ,9, "OUTLINE")
	frame.TimeLeft:SetShadowOffset(1, -1)
	frame.TimeLeft:SetShadowColor(0,0,0,1)
	frame.TimeLeft:SetPoint("RIGHT", 0, 8)
	frame.TimeLeft:SetWidth(26)
	frame.TimeLeft:SetHeight(16)
	frame.TimeLeft:SetJustifyH("RIGHT")
	--  Stacks
	frame.Stacks:SetFont(AuraFont,10, "OUTLINE")
	frame.Stacks:SetShadowOffset(1, -1)
	frame.Stacks:SetShadowColor(0,0,0,1)
	frame.Stacks:SetPoint("RIGHT", 0, -6)
	frame.Stacks:SetWidth(26)
	frame.Stacks:SetHeight(16)
	frame.Stacks:SetJustifyH("RIGHT")
end

local function TransformSquareAura(frame)
	frame:SetWidth(16.5)
	frame:SetHeight(14.5)
	-- Icon
	frame.Icon:SetAllPoints(frame)
	frame.Icon:SetTexCoord(.10, 1-.07, .12, 1-.12)  -- obj:SetTexCoord(left,right,top,bottom)
	-- Border
	frame.Border:SetWidth(32);
	frame.Border:SetHeight(32)
	frame.Border:SetPoint("CENTER", 0, -2)
	frame.Border:SetTexture(SquareArt)
	-- Highlight
	-- frame.BorderHighlight:SetAllPoints(frame.Border)
	-- frame.BorderHighlight:SetTexture(SquareHighlightArt)
	frame.BorderHighlight:SetWidth(32);
	frame.BorderHighlight:SetHeight(32)
	frame.BorderHighlight:SetPoint("CENTER", 0, -2)
	frame.BorderHighlight:SetTexture(SquareHighlightArt)
	--  Time Text
	frame.TimeLeft:SetFont(AuraFont ,9, "OUTLINE")
	frame.TimeLeft:SetShadowOffset(1, -1)
	frame.TimeLeft:SetShadowColor(0,0,0,1)
	frame.TimeLeft:SetPoint("RIGHT", 0, 8)
	frame.TimeLeft:SetWidth(26)
	frame.TimeLeft:SetHeight(16)
	frame.TimeLeft:SetJustifyH("RIGHT")
	--  Stacks
	frame.Stacks:SetFont(AuraFont,10, "OUTLINE")
	frame.Stacks:SetShadowOffset(1, -1)
	frame.Stacks:SetShadowColor(0,0,0,1)
	frame.Stacks:SetPoint("RIGHT", 0, -6)
	frame.Stacks:SetWidth(26)
	frame.Stacks:SetHeight(16)
	frame.Stacks:SetJustifyH("RIGHT")
end

---------------------------------------------------------------------------------------------------
-- Functions for bar mode
---------------------------------------------------------------------------------------------------

local function CreateAuraFrame(parent)
	local db = TidyPlatesThreat.db.profile.AuraWidget.ModeBar

	local frame = CreateFrame("Frame", nil, parent)

	frame.unit = nil

	frame.Icon = frame:CreateTexture(nil, "BACKGROUND")

	frame.Border = frame:CreateTexture(nil, "ARTWORK")
	frame.BorderHighlight = frame:CreateTexture(nil, "ARTWORK")

	frame.Cooldown = CreateFrame("Cooldown", nil, frame, "TidyPlatesAuraWidgetCooldown")
	frame.Cooldown:SetAllPoints(frame.Icon)
	frame.Cooldown:SetReverse(true)
	frame.Cooldown:SetHideCountdownNumbers(true)
	-- Text
	--frame.TimeLeft = frame.Cooldown:CreateFontString(nil, "OVERLAY")
	--frame.Stacks = frame.Cooldown:CreateFontString(nil, "OVERLAY")
	frame.TimeLeft = frame:CreateFontString(nil, "OVERLAY")
	frame.TimeLeft:SetFont(AuraFont ,9, "OUTLINE")
	frame.Stacks = frame:CreateFontString(nil, "OVERLAY")
	frame.Stacks:SetFont(AuraFont,10, "OUTLINE")

	frame.Statusbar = CreateFrame("StatusBar", nil, frame)
	frame.Statusbar:SetMinMaxValues(0, 100)

	frame.Background = frame.Statusbar:CreateTexture(nil, "BACKGROUND")
	frame.Background:SetAllPoints()

	frame.LabelText = frame.Statusbar:CreateFontString(nil, "OVERLAY")
	frame.LabelText:SetFont(ThreatPlates.Media:Fetch('font', db.Font), db.FontSize)
	frame.LabelText:SetJustifyH("LEFT")
	frame.LabelText:SetShadowOffset(1, -1)
	frame.LabelText:SetMaxLines(1)

	frame.TimeText = frame.Statusbar:CreateFontString(nil, "OVERLAY")
	frame.TimeText:SetFont(ThreatPlates.Media:Fetch('font', db.Font), db.FontSize)
	frame.TimeText:SetJustifyH("RIGHT")
	frame.TimeText:SetShadowOffset(1, -1)

	-- Information about the currently displayed aura
	frame.AuraInfo = {
		Name = "",
		Duration = 0,
		-- Icon = "",
		-- Stacks = 0,
		-- Expiration = 0,
		-- Type = "",
	}

	frame.Expire = ExpireFunction
	frame.Poll = UpdateWidgetTime
	frame:Hide()

	return frame
end

local function UpdateAuraFrame(frame)
	-- local backdrop = {
	-- 	-- path to the background texture
	-- 	bgFile = ThreatPlates.Media:Fetch('statusbar', db.BackgroundTexture),
	-- 	-- path to the border texture
	-- 	edgeFile = ThreatPlates.Media:Fetch('border', db.BackgroundBorder),
	-- 	-- true to repeat the background texture to fill the frame, false to scale it
	-- 	tile = false,
	-- 	-- size (width or height) of the square repeating background tiles (in pixels)
	-- 	tileSize = db.BackgroundBorderEdgeSize,
	-- 	-- thickness of edge segments and square size of edge corners (in pixels)
	-- 	edgeSize = db.BackgroundBorderEdgeSize,
	-- 	-- distance from the edges of the frame to those of the background texture (in pixels)
	-- 	insets = { left = db.BackgroundBorderInset, right = db.BackgroundBorderInset, top = db.BackgroundBorderInset, bottom = db.BackgroundBorderInset }
	-- }
	-- bar.Border = CreateFrame("Frame", nil, bar)
	-- --bar.Border:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
	-- --bar.Border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
	-- bar.Border:SetAllPoints(true)
	-- bar.Border:SetBackdrop(backdrop)
	-- bar.Border:SetFrameLevel(bar:GetFrameLevel())
	-- --bar:SetBackdropColor(db.BackgroundColor.r, db.BackgroundColor.g, db.BackgroundColor.b, db.BackgroundColor.a)
	-- bar:SetBackdropColor(1, 1, 1, 0)
	-- bar:SetBackdropBorderColor(db.BackgroundBorderColor.r, db.BackgroundBorderColor.g, db.BackgroundBorderColor.b, db.BackgroundBorderColor.a)
	-- --bar:SetBackdrop(backdrop)

	local db = TidyPlatesThreat.db.profile.AuraWidget.ModeBar

	if config_bar_mode then
		frame.Statusbar:SetWidth(db.BarWidth)
		frame.Statusbar:SetHeight(db.BarHeight)
		frame.Statusbar:SetStatusBarTexture(ThreatPlates.Media:Fetch('statusbar', db.Texture))
		frame.Statusbar:GetStatusBarTexture():SetHorizTile(false)
		frame.Statusbar:GetStatusBarTexture():SetVertTile(false)

		frame.Background:SetTexture(ThreatPlates.Media:Fetch('statusbar', db.BackgroundTexture))
		frame.Background:SetVertexColor(db.BackgroundColor.r, db.BackgroundColor.g, db.BackgroundColor.b, db.BackgroundColor.a)

		frame.LabelText:SetPoint("LEFT", frame.Statusbar, "LEFT", db.LabelTextIndent, 0)
		frame.LabelText:SetFont(ThreatPlates.Media:Fetch('font', db.Font), db.FontSize)
		frame.LabelText:SetTextColor(db.FontColor.r, db.FontColor.g, db.FontColor.b)

		frame.TimeText:SetPoint("RIGHT", frame.Statusbar, "RIGHT", - db.TimeTextIndent, 0)
		frame.TimeText:SetFont(ThreatPlates.Media:Fetch('font', db.Font), db.FontSize)
		frame.TimeText:SetTextColor(db.FontColor.r, db.FontColor.g, db.FontColor.b)

		frame.Icon:SetWidth(db.BarHeight)
		frame.Icon:SetHeight(db.BarHeight)
		frame.Icon:SetAllPoints(frame)

		-- width and position calculations
		local frame_width = db.BarWidth
		if db.ShowIcon then
			frame_width = frame_width + db.BarHeight + db.IconSpacing
		end
		frame:SetWidth(frame_width)
		frame:SetHeight(db.BarHeight)

		if db.ShowIcon then
			frame.Icon:ClearAllPoints()
			--frame.Statusbar:ClearAllPoints()
			if db.IconAlignmentLeft then
				frame.Icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
				frame.Statusbar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", db.BarHeight + db.IconSpacing, 0)
			else
				frame.Statusbar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
				frame.Icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", db.BarWidth + db.IconSpacing, 0)
			end
		else
			--frame.Statusbar:ClearAllPoints()
			frame.Statusbar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
		end

		frame.Statusbar:Show()
		if db.ShowIcon then
			frame.Icon:Show()
		else
			frame.Icon:Hide()
		end

		frame.Border:Hide()
		frame.BorderHighlight:Hide()
		frame.Cooldown:Hide()
		frame.TimeLeft:Hide()
		frame.Stacks:Hide()
	else
		-- Apply Style
		if useWideIcons then TransformWideAura(frame) else TransformSquareAura(frame) end

		if TidyPlatesThreat.db.profile.AuraWidget.ShowCooldownSpiral then
			frame.Cooldown:SetDrawEdge(true)
			frame.Cooldown:SetDrawEdge(true)
		else
			frame.Cooldown:SetDrawEdge(false)
			frame.Cooldown:SetDrawSwipe(false)
		end

		frame.Statusbar:Hide()
		-- frame.Background:Hide()
		-- frame.LabelText:Hide()
		-- frame.LabelTime:Hide()

		frame.Icon:Show()
		frame.Border:Show()
		frame.BorderHighlight:Show()
		frame.TimeLeft:Show()
		frame.Stacks:Show()
	end
end

---------------------------------------------------------------------------------------------------
-- Creation and update functions
---------------------------------------------------------------------------------------------------

local function UpdateWidgetConfig(aura_widget_frame)
	local aura_frame_list = aura_widget_frame.AuraFrames
	for index = 1, AuraLimit do
		local frame = aura_frame_list[index] or CreateAuraFrame(aura_widget_frame)
		aura_frame_list[index] = frame
		UpdateAuraFrame(frame)

		-- anchor the frame
		frame:ClearAllPoints()
		if index == 1 then
			local frame_width = 0

			local db = TidyPlatesThreat.db.profile.AuraWidget.ModeBar
			if db.Enabled then
				frame_width = db.BarWidth
				if db.ShowIcon then
					frame_width = frame_width + db.BarHeight + db.IconSpacing
				end
			else
				frame_width = 16.5
				if useWideIcons then frame_width = 26.5 end
				frame_width = frame_width * config_grid_columns + (config_grid_column_spacing - 1) * config_grid_columns
			end
			frame:SetPoint("LEFT", aura_widget_frame, (aura_widget_frame:GetWidth() - frame_width) / 2, 0)
		elseif ((index - 1) % config_grid_columns) == 0 then
			frame:SetPoint("BOTTOMLEFT", aura_frame_list[index - config_grid_columns], "TOPLEFT", 0, config_grid_row_spacing)
		else
			frame:SetPoint("LEFT", aura_frame_list[index - 1], "RIGHT", config_grid_column_spacing, 0)
		end
	end

	-- if MaxBars was decreased, remove any overflow aura frames
	for index = AuraLimit + 1, #aura_frame_list do
		local frame = aura_frame_list[index]
		aura_frame_list[index] = nil
		PolledHideIn(frame)
	end
end

-- Context Update (mouseover, target change)
local function UpdateWidgetContext(frame, unit)
	local unitid = unit.unitid
	frame.unit = unit
	frame.unitid = unitid

	-- Add to Widget List
	-- if guid then
	-- 	WidgetList[guid] = frame
	-- end
	if unitid then
		local old_frame = WidgetList[unitid]
		WidgetList[unitid] = frame
		if old_frame ~= frame then
			--DEBUG("Updateing new frame")
			UpdateWidgetConfig(frame, unit)
		end
	end


	-- Custom Code II
	--------------------------------------
	if TidyPlatesThreat.db.profile.AuraWidget.ShowTargetOnly and not unit.isTarget then
		frame:_Hide()
	else
		-- UpdateWidgetConfig(frame, unit)
		UpdateWidget(frame)
		frame:Show()
	end
	--------------------------------------
	-- End Custom Code
end

local function UpdateFromProfile()
	local db = TidyPlatesThreat.db.profile.AuraWidget

	if db.ModeIcon.Style == "square" then
		useWideIcons = false
	else
		useWideIcons = true
	end

	if db.ModeBar.Enabled then
		config_bar_mode = true
		config_grid_rows = db.ModeBar.MaxBars
		config_grid_columns = 1
		config_grid_row_spacing = db.ModeBar.BarSpacing
		config_grid_column_spacing = 0
		config_max_label_text_length = db.ModeBar.BarWidth - db.ModeBar.LabelTextIndent - db.ModeBar.TimeTextIndent - (db.ModeBar.FontSize / 5)
	else
		config_bar_mode = false
		config_grid_rows = db.ModeIcon.Rows
		config_grid_columns = db.ModeIcon.Columns
		config_grid_row_spacing = db.ModeIcon.RowSpacing
		config_grid_column_spacing = db.ModeIcon.ColumnSpacing
	end
	AuraLimit = config_grid_rows * config_grid_columns
end

-- Create the Main Widget Body and Icon Array
local function CreateAuraWidget(parent, style)
	-- Required Widget Code
	local frame = CreateFrame("Frame", nil, parent)
	--frame:Hide()
	frame:Show()

	-- Custom Code III
	--------------------------------------
	local db = TidyPlatesThreat.db.profile.AuraWidget

	-- Create Base frame
	frame:SetWidth(128)
	frame:SetHeight(32)
	--frame:SetPoint(db.anchor, parent, db.x, db.y)
	frame:SetFrameLevel(parent:GetFrameLevel() + 1)

	frame.AuraFrames = {}
	frame.Filter = nil
	AuraFilterFunction = AuraFilter
	-- Create Icon Grid
	if not AuraLimit then UpdateFromProfile() end
	UpdateWidgetConfig(frame)
	--------------------------------------
	-- End Custom Code

	-- Required Widget Code
	frame.UpdateContext = UpdateWidgetContext
	frame.Update = UpdateWidgetContext
	frame.UpdateConfig = UpdateWidgetConfig
	frame._Hide = frame.Hide
	frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end

	return frame
end

local function UpdateAuraWidgetSettings()
	UpdateFromProfile()

	-- Update all widgets
	for unitid, widget in pairs(WidgetList) do
		UpdateWidgetConfig(widget)
	end

	TidyPlates:ForceUpdate()
end



-----------------------------------------------------
-- External
-----------------------------------------------------

ThreatPlatesWidgets.UpdateAuraWidgetSettings = UpdateAuraWidgetSettings

-----------------------------------------------------
-- Soon to be deprecated
-----------------------------------------------------

local PlayerDispelCapabilities = {
	["Curse"] = false,
	["Disease"] = false,
	["Magic"] = false,
	["Poison"] = false,
}

local function UpdatePlayerDispelTypes()
	PlayerDispelCapabilities["Curse"] = IsSpellKnown(51886) or IsSpellKnown(475) or IsSpellKnown(2782)
	PlayerDispelCapabilities["Poison"] = IsSpellKnown(2782) or IsSpellKnown(32375) or IsSpellKnown(4987) or (IsSpellKnown(527) and IsSpellKnown(33167))
	PlayerDispelCapabilities["Magic"] = (IsSpellKnown(4987) and IsSpellKnown(53551)) or (IsSpellKnown(2782) and IsSpellKnown(88423)) or (IsSpellKnown(527) and IsSpellKnown(33167)) or (IsSpellKnown(51886) and IsSpellKnown(77130)) or IsSpellKnown(32375)
	PlayerDispelCapabilities["Disease"] = IsSpellKnown(4987) or IsSpellKnown(528)
end

local function CanPlayerDispel(debuffType)
	return PlayerDispelCapabilities[debuffType or ""]
end

--TidyPlatesWidgets.CanPlayerDispel = CanPlayerDispel

ThreatPlatesWidgets.RegisterWidget("AuraWidget-2.0", CreateAuraWidget, false, enabled)
ThreatPlatesWidgets.PrepareFilterAuraWidget = PrepareFilter
