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

local WidgetList = {}

local AuraMonitor = CreateFrame("Frame")
local isAuraEnabled = false

local UpdateWidget
local UnitAuraList = {}

local CONFIG_LAST_UPDATE
local CONFIG_WIDE_ICONS = false
local CONFIG_MODE_BAR = false
local CONFIG_GRID_NO_COLS = 3
local CONFIG_GRID_SPACING_ROWS = 5
local CONFIG_GRID_SPACING_COLS = 8
local CONFIG_LABEL_LENGTH = 0
local CONFIG_AURA_LIMIT
local CONFIG_AURA_FRAME_HEIGHT
local CONFIG_AURA_FRAME_WIDTH
local CONFIG_AURA_FRAME_OFFSET
local Filter_ByAuraList

local AURA_TARGET_HOSTILE = 1
local AURA_TARGET_FRIENDLY = 2

local AURA_TYPE_BUFF = 1
local AURA_TYPE_DEBUFF = 6

-- Get a clean version of the function...  Avoid OmniCC interference
local CooldownNative = CreateFrame("Cooldown", nil, WorldFrame)
local SetCooldown = CooldownNative.SetCooldown

local font_frame = CreateFrame("Frame", nil, WorldFrame)

local WideArt = "Interface\\AddOns\\TidyPlatesWidgets\\Aura\\AuraFrameWide"
local SquareArt = "Interface\\AddOns\\TidyPlatesWidgets\\Aura\\AuraFrameSquare"
local WideHighlightArt = "Interface\\AddOns\\TidyPlatesWidgets\\Aura\\AuraFrameHighlightWide"
local SquareHighlightArt = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\AuraWidget\\AuraFrameHighlightSquare"
local AuraFont = "FONTS\\ARIALN.TTF"

local AuraType_Index = {
	["Buff"] = 1,
	["Curse"] = 2,
	["Disease"] = 3,
	["Magic"] = 4,
	["Poison"] = 5,
	["Debuff"] = 6,
}

local GRID_LAYOUT = {
  LEFT = {
    BOTTOM =  {"BOTTOMLEFT", "BOTTOMLEFT" , "TOPLEFT", "LEFT", "RIGHT" , 1, 1},
    TOP =     {"TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "LEFT", "RIGHT", 1, -1}
  },
  RIGHT = {
    BOTTOM =  {"BOTTOMRIGHT", "BOTTOMRIGHT", "TOPRIGHT", "RIGHT", "LEFT", -1, 1 },
    TOP =     {"TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "RIGHT", "LEFT", -1 , -1}
  }
}

---------------------------------------------------------------------------------------------------
-- PolledHideIn() - Registers a callback, which polls the frame until it expires, then hides the frame and removes the callback
---------------------------------------------------------------------------------------------------

local watcher_frame = CreateFrame("Frame")
local watcher_frame_active = false

local UPDATE_INTERVAL = 0.5 -- Default for icon mode is 0.5, for bar mode "1 / GetFramerate()" is used for smooth updates -- GetFramerate() in frames/second
local time_to_update = 0
local framelist = {}			-- Key = Frame, Value = Expiration Time

local PolledHideIn

local function CheckFramelist(self)
  -- update only every UpdateInterval seconds
  local cur_time = GetTime()
  if cur_time < time_to_update then return end
  time_to_update = cur_time + UPDATE_INTERVAL

  local framecount = 0
	-- Cycle through the watchlist, hiding frames which are timed-out
	for frame, expiration in pairs(framelist) do
    -- frame here is a single aura frame, not the aura widget frame
		-- If expired...
    local duration = frame.AuraInfo.duration

		if expiration < cur_time and duration > 0 then
      --DEBUG ("Expire Aura: ", frame:GetParent().unitid, frame.AuraInfo.name)
			if frame.Expire and frame:GetParent():IsShown() then
        frame:Expire()
      end

			frame:Hide()
			framelist[frame] = nil
		else
      -- If still shown ... update the frame
			if frame.Poll and frame:GetParent():IsShown() then
        frame:Poll(expiration, duration)
      end
      framecount = framecount + 1
    end
	end

	-- If no more frames to watch, unregister the OnUpdate script
	if framecount == 0 then
    watcher_frame:SetScript("OnUpdate", nil)
    watcher_frame_active = false
  end
end

local function PolledHideIn(frame, expiration, duration)
  if not expiration then
		frame:Hide()
		framelist[frame] = nil
  else
		framelist[frame] = expiration
		frame:Show()

    if not watcher_frame_active then
			watcher_frame:SetScript("OnUpdate", CheckFramelist)
			watcher_frame_active = true
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

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

local function GetColorForAura(aura)
	local db = TidyPlatesThreat.db.profile.AuraWidget

	local color
	if aura.effect == "HARMFUL" then
    color = db.DefaultDebuffColor
  else
    color = db.DefaultBuffColor
	end

	if aura.type and db.ShowAuraType then
    color = DebuffTypeColor[aura.type]
	end

	return color
end

local function AuraFilterFunction(aura)
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

	local priority

  local sort_order = db.SortOrder
  if sort_order == "AtoZ" then
		priority = aura.name
	elseif sort_order == "TimeLeft" then
	  priority = aura.expiration - GetTime()
	elseif sort_order == "Duration" then
 		priority = aura.duration
  elseif sort_order == "Creation" then
    priority = aura.expiration - aura.duration
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

local function AuraSortFunctionNum(a, b)
  local order

  -- handling invalid entries in the aura array (necessary to avoid memory extensive array creation)
  if a == nil and b == nil then
    order = false
  elseif a == nil then
    order = false
  elseif b == nil then
    order = true
  end

  if not a.priority and not b.priority then
    order = false
  elseif not a.priority then
    order = false
  elseif not b.priority then
    order = true
  end

  if order ~= nil then return order end

  if a.duration == 0 then
    order = false
  elseif b.duration == 0 then
    order = true
  else
    order = a.priority < b.priority
  end

  local sort_reverse = TidyPlatesThreat.db.profile.AuraWidget.SortReverse
  if sort_reverse then
    order = not order
  end

  return order
end

local function AuraSortFunctionAtoZ(a, b)
  local order

  -- handling invalid entries in the aura array (necessary to avoid memory extensive array creation)
  if a == nil and b == nil then
    order = false
  elseif a == nil then
    order = false
  elseif b == nil then
    order = true
  end

  if not a.priority and not b.priority then
    order = false
  elseif not a.priority then
    order = false
  elseif not b.priority then
    order = true
  end

  if order ~= nil then return order end

  order = a.priority > b.priority

  local sort_reverse = TidyPlatesThreat.db.profile.AuraWidget.SortReverse
  if sort_reverse then
    order = not order
  end

  return order
end

-------------------------------------------------------------
-- Widget Object Functions
-------------------------------------------------------------

local function UpdateWidgetTimeIcon(frame, expiration, duration)
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

local function UpdateWidgetTimeBar(frame, expiration, duration)
	if duration == 0 then
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
		frame.Statusbar:SetValue(timeleft * 100 / duration)
	end
end

local function UpdateWidgetTime(frame, expiration, duration)
	if CONFIG_MODE_BAR then
		UpdateWidgetTimeBar(frame, expiration, duration)
	else
		UpdateWidgetTimeIcon(frame, expiration, duration)
	end
end

local function UpdateAuraFrame(frame) -- texture, duration, expiration, stacks, color, name)
  local db = TidyPlatesThreat.db.profile.AuraWidget

  local aura_info = frame.AuraInfo
  local name = aura_info.name
  local duration = aura_info.duration
  local texture = aura_info.texture
  local expiration = aura_info.expiration
  local stacks = aura_info.stacks
  local color = aura_info.color

  -- Expiration
  UpdateWidgetTime(frame, expiration, duration)

  if db.ShowStackCount and stacks and stacks > 1 then
    frame.Stacks:SetText(stacks)
  else
    frame.Stacks:SetText("")
  end

  if CONFIG_MODE_BAR then
--      frame.Statusbar:SetWidth(db.BarWidth)

    -- Icon
    if db.ModeBar.ShowIcon then
      frame.Icon:SetTexture(texture)
    end

    frame.LabelText:SetWidth(CONFIG_LABEL_LENGTH - frame.TimeText:GetStringWidth())
    frame.LabelText:SetText(name)
    --			if TidyPlatesThreat.db.profile.AuraWidget.ShowStackCount and stacks and stacks > 1 then
    --				frame.LabelText:SetText(frame.AuraInfo.Name .. " [" .. stacks .. "]")
    --			else
    --				frame.LabelText:SetText(frame.AuraInfo.Name)
    --			end

    -- Highlight Coloring
    frame.Statusbar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
  else
    frame.Icon:SetTexture(texture)

    -- Highlight Coloring
    if db.ShowAuraType then
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

  PolledHideIn(frame, expiration, duration)
end

local function UpdateIconGrid(frame, unitid)
  if not unitid then return end

  local unitReaction
  if UnitIsFriend("player", unitid) then
    unitReaction = AURA_TARGET_FRIENDLY
  else
    unitReaction = AURA_TARGET_HOSTILE
  end

  local aura_count = 1

  -- Cache displayable auras
  ------------------------------------------------------------------------------------------------------
  -- This block will go through the auras on the unit and make a list of those that should
  -- be displayed, listed by priority.
  local searchedDebuffs, searchedBuffs = false, false
  local auraFilter = "HARMFUL"

  local auraIndex = 0
  repeat
    auraIndex = auraIndex + 1
    -- Example: Gnaw , false, icon, 0 stacks, nil type, duration 1, expiration 8850.436, caster pet, false, false, 91800
    local name, _, icon, stacks, auraType, duration, expiration, caster, _, _, spellid = UnitAura(unitid, auraIndex, auraFilter)		-- UnitaAura

    -- Auras are evaluated by an external function
    -- Pre-filtering before the icon grid is populated
    if name then
      UnitAuraList[aura_count] = UnitAuraList[aura_count] or {}
      aura = UnitAuraList[aura_count]

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
      aura.priority = nil

      local show, priority, color = AuraFilterFunction(aura)
      -- Store Order/Priority
      if show then
        aura.priority = priority
        aura.color = color

        aura_count = aura_count + 1
        --storedAuras[storedAuraCount] = aura
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
  aura_count = aura_count - 1

  -- invalidate all entries after storedAuraCount
  for i = aura_count + 1, #UnitAuraList do
    UnitAuraList[i].priority = nil
  end

  -- Display Auras
  ------------------------------------------------------------------------------------------------------
  local aura_frame_list = frame.AuraFrames
  local max_auras_no = min(aura_count, CONFIG_AURA_LIMIT)

  if aura_count > 0 then
    --ThreatPlates.DEBUG_AURA_LIST(UnitAuraList)
    local sort_order = TidyPlatesThreat.db.profile.AuraWidget.SortOrder
    if sort_order ~= "None" then
      if sort_order == "AtoZ" then
        sort(UnitAuraList, AuraSortFunctionAtoZ)
      else
        sort(UnitAuraList, AuraSortFunctionNum)
      end
    end

    --local aura_info_list = frame.AuraInfos
    for index = 1, max_auras_no do
      local aura = UnitAuraList[index]

      if aura.spellid and aura.expiration then
        local aura_frame = aura_frame_list[index]
        --aura_info_list[index] = aura_info_list[index] or {}
        --local aura_info = aura_info_list[index]

        local aura_info = aura_frame.AuraInfo
        aura_info.name = aura.name
        aura_info.duration = aura.duration
        aura_info.texture = aura.texture
        aura_info.expiration = aura.expiration
        aura_info.stacks = aura.stacks
        aura_info.color = aura.color

        -- Call function to display the aura
        UpdateAuraFrame(aura_frame) -- aura.texture, aura.duration, aura.expiration, aura.stacks, aura.color, aura.name)
      end
    end

  end

  -- Clear extra slots
  for index = max_auras_no + 1, CONFIG_AURA_LIMIT do
    --UpdateAuraFrame(aura_frame_list[index])
    PolledHideIn(aura_frame_list[index])
  end
end

-- (Re)Draw grid with aura frames
local function UpdateAuraFrameGrid(frame)
  local aura_frame_list = frame.AuraFrames
  --local aura_info_list = frame.AuraInfos

  --  for index = 1, aura_no do
  --    local aura = UnitAuraList[index]
  --

  for index = 1, CONFIG_AURA_LIMIT do
    local aura_frame = aura_frame_list[index]

    if aura_frame:IsShown() then
    -- Call function to display the aura
      UpdateAuraFrame(aura_frame) --, aura_info.texture, aura_info.duration, aura_info.expiration, aura_info.stacks, aura_info.color, aura_info.name)
    else
      break
    end
  end

--  -- Clear Extra Slots
--    UpdateAuraFrame(aura_frames[index])
--  for index = aura_no + 1, CONFIG_AURA_LIMIT do
--  end
end

local function ExpireFunction(icon)
	-- local frame = icon.Parent
	UpdateWidget(icon:GetParent())
end

-------------------------------------------------------------
-- Watcher for auras on units (gaining and losing buffs/debuffs)
-------------------------------------------------------------

local function EventUnitAura(unitid)
  if unitid then
    -- WidgetList contains the units that are tracked, i.e. for which currently nameplates are shown
    local frame = WidgetList[unitid]

    if frame then
      UpdateWidget(frame)
    end
  end
end

local AuraEvents = {
  --["UNIT_TARGET"] = EventUnitTarget,
  ["UNIT_AURA"] = EventUnitAura,
}

local function AuraEventHandler(frame, event, ...)
  --local unitid = ...
  if event then
    local eventFunction = AuraEvents[event]
    eventFunction(...)
  end
end

local function Enable()
	AuraMonitor:SetScript("OnEvent", AuraEventHandler)

	for event in pairs(AuraEvents) do
		AuraMonitor:RegisterEvent(event)
	end
end

local function Disable()
	AuraMonitor:SetScript("OnEvent", nil)
	AuraMonitor:UnregisterAllEvents()

--	for unitid, widget in pairs(WidgetList) do
--		if frame == widget then WidgetList[unitid] = nil end
--	end
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
-- Functions for icon and bar mode
---------------------------------------------------------------------------------------------------

local function TransformWideAura(frame)
	frame:SetSize(26.5, 14.5)
	-- Icon
	frame.Icon:SetAllPoints(frame)
	frame.Icon:SetTexCoord(.07, 1-.07, .23, 1-.23)  -- obj:SetTexCoord(left,right,top,bottom)
	-- Border
  frame.Border:SetPoint("CENTER", 1, -2)
  frame.Border:SetSize(32, 32)
	frame.Border:SetTexture(WideArt)
	-- Highlight
	--frame.BorderHighlight:SetAllPoints(frame.Border) -- Border is off when switching between bar and icon mode, if this statement is used
  frame.BorderHighlight:SetPoint("CENTER", 1, -2)
  frame.BorderHighlight:SetSize(32, 32)
	frame.BorderHighlight:SetTexture(WideHighlightArt)
end

local function TransformSquareAura(frame)
	frame:SetSize(16.5, 14.5)
	-- Icon
	frame.Icon:SetAllPoints(frame)
	frame.Icon:SetTexCoord(.10, 1-.07, .12, 1-.12)  -- obj:SetTexCoord(left,right,top,bottom)
	-- Border
  frame.Border:SetPoint("CENTER", 0, -2)
  frame.Border:SetSize(32, 32)
	frame.Border:SetTexture(SquareArt)
	-- Highlight
	--frame.BorderHighlight:SetAllPoints(frame.Border) -- Border is off when switching between bar and icon mode, if this statement is used
  frame.BorderHighlight:SetPoint("CENTER", 0, -2)
  frame.BorderHighlight:SetSize(32, 32)
	frame.BorderHighlight:SetTexture(SquareHighlightArt)
end

local function CreateAuraFrame(parent)
	local db = TidyPlatesThreat.db.profile.AuraWidget.ModeBar

	local frame = CreateFrame("Frame", nil, parent)

	frame.Icon = frame:CreateTexture(nil, "BACKGROUND")

	frame.Border = frame:CreateTexture(nil, "ARTWORK")
	frame.BorderHighlight = frame:CreateTexture(nil, "ARTWORK")

	frame.Cooldown = CreateFrame("Cooldown", nil, frame, "TidyPlatesAuraWidgetCooldown")
	frame.Cooldown:SetAllPoints(frame.Icon)
	frame.Cooldown:SetReverse(true)
	frame.Cooldown:SetHideCountdownNumbers(true)

  --  Time Text
  frame.TimeLeft = frame:CreateFontString(nil, "OVERLAY")
  frame.TimeLeft:SetFont(AuraFont ,9, "OUTLINE")
  frame.TimeLeft:SetShadowOffset(1, -1)
  frame.TimeLeft:SetShadowColor(0,0,0,1)
  frame.TimeLeft:SetPoint("RIGHT", 0, 8)
  frame.TimeLeft:SetSize(26, 16)
  frame.TimeLeft:SetJustifyH("RIGHT")

  --  Stacks
  frame.Stacks = frame:CreateFontString(nil, "OVERLAY")
--  frame.Stacks:SetFont(AuraFont,10, "OUTLINE")
--  frame.Stacks:SetShadowOffset(1, -1)
--  frame.Stacks:SetShadowColor(0,0,0,1)
--  frame.Stacks:SetPoint("RIGHT", 0, -6)
--  frame.Stacks:SetSize(26, 16)
--  frame.Stacks:SetJustifyH("RIGHT")

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

  frame.AuraInfo = {
		name = "",
		duration = 0,
    texture = "",
    expiration = 0,
    stacks = 0,
    color = 0
  }

	frame.Expire = ExpireFunction
	frame.Poll = UpdateWidgetTime
	frame:Hide()

	return frame
end

local function UpdateAuraLayout(frame)
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

	if CONFIG_MODE_BAR then
    local db = TidyPlatesThreat.db.profile.AuraWidget.ModeBar

    -- width and position calculations
    local frame_width = db.BarWidth
    if db.ShowIcon then
      frame_width = frame_width + db.BarHeight + db.IconSpacing
    end
    frame:SetSize(frame_width, db.BarHeight)

		frame.Background:SetTexture(ThreatPlates.Media:Fetch('statusbar', db.BackgroundTexture))
		frame.Background:SetVertexColor(db.BackgroundColor.r, db.BackgroundColor.g, db.BackgroundColor.b, db.BackgroundColor.a)

		frame.LabelText:SetPoint("LEFT", frame.Statusbar, "LEFT", db.LabelTextIndent, 0)
		frame.LabelText:SetFont(ThreatPlates.Media:Fetch('font', db.Font), db.FontSize)
		frame.LabelText:SetTextColor(db.FontColor.r, db.FontColor.g, db.FontColor.b)

		frame.TimeText:SetPoint("RIGHT", frame.Statusbar, "RIGHT", - db.TimeTextIndent, 0)
		frame.TimeText:SetFont(ThreatPlates.Media:Fetch('font', db.Font), db.FontSize)
		frame.TimeText:SetTextColor(db.FontColor.r, db.FontColor.g, db.FontColor.b)

    frame.Icon:ClearAllPoints()
    frame.Statusbar:ClearAllPoints()
		if db.ShowIcon then
			--frame.Statusbar:ClearAllPoints()
			if db.IconAlignmentLeft then
				frame.Icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
				frame.Statusbar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", db.BarHeight + db.IconSpacing, 0)
			else
        frame.Icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", db.BarWidth + db.IconSpacing, 0)
        frame.Statusbar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
			end
      frame.Stacks:SetAllPoints(frame.Icon)
      frame.Stacks:SetSize(db.BarHeight, db.BarHeight)
      frame.Stacks:SetJustifyH("CENTER")
      frame.Stacks:SetFont(ThreatPlates.Media:Fetch('font', db.Font), db.FontSize, "OUTLINE")
      frame.Stacks:SetShadowOffset(1, -1)
      frame.Stacks:SetShadowColor(0,0,0,1)
      frame.Stacks:SetTextColor(db.FontColor.r, db.FontColor.g, db.FontColor.b)
		else
--      frame.Icon:SetAllPoints(frame)
			frame.Statusbar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
		end

    frame.Statusbar:SetSize(db.BarWidth, db.BarHeight)
--    frame.Statusbar:SetWidth(db.BarWidth)
    frame.Statusbar:SetStatusBarTexture(ThreatPlates.Media:Fetch('statusbar', db.Texture))
    frame.Statusbar:GetStatusBarTexture():SetHorizTile(false)
    frame.Statusbar:GetStatusBarTexture():SetVertTile(false)
    frame.Icon:SetTexCoord(0, 1, 0, 1)
    frame.Icon:SetSize(db.BarHeight, db.BarHeight)

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
	else
    local db = TidyPlatesThreat.db.profile.AuraWidget.ModeIcon

		if CONFIG_WIDE_ICONS then TransformWideAura(frame) else TransformSquareAura(frame) end

    frame.Stacks:SetFont(AuraFont,10, "OUTLINE")
    frame.Stacks:SetShadowOffset(1, -1)
    frame.Stacks:SetShadowColor(0,0,0,1)
    frame.Stacks:ClearAllPoints()
    frame.Stacks:SetPoint("RIGHT", 0, -6)
    frame.Stacks:SetSize(26, 16)
    frame.Stacks:SetJustifyH("RIGHT")

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
  end
end

---------------------------------------------------------------------------------------------------
-- Creation and update functions
---------------------------------------------------------------------------------------------------

local function UpdateWidgetConfig(widget_frame)
	widget_frame.last_update = GetTime()

  local db = TidyPlatesThreat.db.profile.AuraWidget

  local align_layout = GRID_LAYOUT[db.AlignmentH][db.AlignmentV]
  local aura_frame_list = widget_frame.AuraFrames
  for index = 1, CONFIG_AURA_LIMIT do
    local frame = aura_frame_list[index] or CreateAuraFrame(widget_frame)
    aura_frame_list[index] = frame

    -- anchor the frame
		frame:ClearAllPoints()
    if index == 1 then
      frame:SetPoint(align_layout[1], widget_frame, align_layout[6] * CONFIG_AURA_FRAME_OFFSET, align_layout[7] * CONFIG_AURA_FRAME_OFFSET)
		elseif ((index - 1) % CONFIG_GRID_NO_COLS) == 0 then
      frame:SetPoint(align_layout[2], aura_frame_list[index - CONFIG_GRID_NO_COLS], align_layout[3], 0, align_layout[7] * CONFIG_GRID_SPACING_ROWS)
    else
      frame:SetPoint(align_layout[4], aura_frame_list[index - 1], align_layout[5], align_layout[6] * CONFIG_GRID_SPACING_COLS, 0)
		end

    UpdateAuraLayout(frame)
	end

	-- if MaxBars was decreased, remove any overflow aura frames
	for index = CONFIG_AURA_LIMIT + 1, #aura_frame_list do
		local frame = aura_frame_list[index]
		aura_frame_list[index] = nil
		PolledHideIn(frame)
  end

  --UpdateAuraFrameGrid(widget_frame)
  -- UpdateWidget(widget_frame)
  UpdateIconGrid(widget_frame, widget_frame.unitid)

  widget_frame:ClearAllPoints()
  widget_frame:SetPoint(ThreatPlates.ANCHOR_POINT_SETPOINT[db.anchor][2], widget_frame:GetParent(), ThreatPlates.ANCHOR_POINT_SETPOINT[db.anchor][1], db.x, db.y)
  widget_frame:SetSize(CONFIG_AURA_FRAME_WIDTH, CONFIG_AURA_FRAME_HEIGHT)
  widget_frame:SetScale(db.scale)
end

function UpdateWidget(frame)
	if CONFIG_LAST_UPDATE > frame.last_update then
		-- ThreatPlates.DEBUG("Update Delay: ", frame.unit.name, frame.unitid)
		UpdateWidgetConfig(frame)
	end

	UpdateIconGrid(frame, frame.unitid)
--  if not frame.Background then
--    frame.Background = frame:CreateTexture(nil, "BACKGROUND")
--    frame.Background:SetAllPoints()
--    frame.Background:SetTexture(ThreatPlates.Media:Fetch('statusbar', TidyPlatesThreat.db.profile.AuraWidget.BackgroundTexture))
--    frame.Background:SetVertexColor(0,0,0,1)
--  end
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
    if not old_frame then
      UpdateWidget(frame)
    end
    WidgetList[unitid] = frame
	end

	-- Custom Code II
	--------------------------------------
  local db = TidyPlatesThreat.db.profile.AuraWidget
  if db.ShowTargetOnly and not unit.isTarget then
    frame:_Hide()
  else
--    if not frame:IsShown() then
--      UpdateWidget(frame)
--    end
		frame:Show()
	end
	--------------------------------------
	-- End Custom Code
end

-- Load settings from the configuration which are shared across all aura widgets
-- used (for each widget) in UpdateWidgetConfig
local function ConfigAuraWidget()
	local db = TidyPlatesThreat.db.profile.AuraWidget

  local use_wide_icons = (db.ModeIcon.Style == "wide")

  local frame_width = 0
  local frame_height = 14.5
  local frame_offset = 0
  local grid_no_rows
  local grid_no_cols
  local grid_spacing_rows
  local grid_spacing_cols

  local modebar = db.ModeBar.Enabled

  if modebar then
    local db_mode = db.ModeBar
    grid_no_rows = db_mode.MaxBars
    grid_no_cols = 1
    grid_spacing_rows = db_mode.BarSpacing
    grid_spacing_cols = 0
		CONFIG_LABEL_LENGTH = db_mode.BarWidth - db_mode.LabelTextIndent - db_mode.TimeTextIndent - (db_mode.FontSize / 5)
    UPDATE_INTERVAL = 1 / GetFramerate()

    frame_height = db_mode.BarHeight
    frame_width = db_mode.BarWidth
    if db_mode.ShowIcon then
      frame_width = frame_width + db_mode.BarHeight + db_mode.IconSpacing
    end
	else
    local db_mode = db.ModeIcon
    grid_no_rows = db_mode.Rows
    grid_no_cols = db_mode.Columns
    grid_spacing_rows = db_mode.RowSpacing
    grid_spacing_cols = db_mode.ColumnSpacing
    UPDATE_INTERVAL = 0.5

    frame_offset = (db.ShowAuraType and 2) or 1
    frame_width = (use_wide_icons and 26.5) or 16.5
    -- Optimized calculation based on: CONFIG_AURA_FRAME_WIDTH = (CONFIG_AURA_FRAME_WIDTH + (CONFIG_AURA_FRAME_OFFSET * 2)) * CONFIG_GRID_NO_COLS + ((CONFIG_GRID_SPACING_COLS - (CONFIG_AURA_FRAME_OFFSET * 2)) * (CONFIG_GRID_NO_COLS - 1))
    frame_width = (frame_width * grid_no_cols) + (grid_spacing_cols * grid_no_cols) - grid_spacing_cols + (frame_offset * 2)
	end
  frame_height = (frame_height * grid_no_rows) + (grid_spacing_rows * grid_no_rows) - grid_spacing_rows + (frame_offset * 2)

  CONFIG_AURA_FRAME_WIDTH = frame_width
  CONFIG_AURA_FRAME_HEIGHT = frame_height
  CONFIG_AURA_FRAME_OFFSET = frame_offset
  CONFIG_GRID_NO_COLS = grid_no_cols
  CONFIG_AURA_LIMIT = grid_no_rows * grid_no_cols
  CONFIG_GRID_SPACING_ROWS = grid_spacing_rows
  CONFIG_GRID_SPACING_COLS = grid_spacing_cols
  CONFIG_WIDE_ICONS = use_wide_icons
  CONFIG_MODE_BAR = modebar

	CONFIG_LAST_UPDATE = GetTime()
end

local function ClearWidgetContext(frame)
--  for unitid, widget in pairs(WidgetList) do
--    if frame == widget then WidgetList[unitid] = nil end
--  end
  local unitid = frame.unitid
  if unitid then
    WidgetList[unitid] = nil
    -- updates keep rolling in even after hiding a aura widget frame, if unit or unitid
    -- is needed to process these updates, uncomment the following two lines
    frame.unitid = nil
    frame.unit = nil
  end
end

-- Create the Main Widget Body and Icon Array
local function CreateAuraWidget(plate)
	-- Required Widget Code
	local frame = CreateFrame("Frame", nil, plate)
	frame:Hide()
	--frame:Show()

	-- Custom Code III
	--------------------------------------
	frame:SetSize(128, 32)
	frame:SetFrameLevel(plate:GetFrameLevel() + 1)
	frame.AuraFrames = {}
	--frame.AuraInfos = {}
  UpdateWidgetConfig(frame)
	--------------------------------------
	-- End Custom Code

	-- Required Widget Code
  frame.Update = UpdateWidgetContext
  frame.UpdateContext = UpdateWidgetContext
	frame.UpdateConfig = UpdateWidgetConfig
	frame._Hide = frame.Hide
	frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end

	return frame
end

-----------------------------------------------------
-- External
-----------------------------------------------------

ThreatPlatesWidgets.ConfigAuraWidget = ConfigAuraWidget
ThreatPlatesWidgets.PrepareFilterAuraWidget = PrepareFilter

-----------------------------------------------------
-- Register widget
-----------------------------------------------------

ThreatPlatesWidgets.RegisterWidget("AuraWidget2TPTP", CreateAuraWidget, false, enabled)
