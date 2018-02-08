local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local GetTime = GetTime
local pairs = pairs
local floor = floor
local sort = sort
local math = math
local string = string
local tonumber = tonumber

-- WoW APIs
local DebuffTypeColor = DebuffTypeColor
local UnitAura = UnitAura
local CreateFrame = CreateFrame
local GetFramerate = GetFramerate
local UnitIsFriend = UnitIsFriend

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local RGB = ThreatPlates.RGB
local DEBUG = ThreatPlates.DEBUG

---------------------------------------------------------------------------------------------------
-- Aura Widget 2.0
---------------------------------------------------------------------------------------------------

local WidgetList = {}

local AuraMonitor = CreateFrame("Frame")
local isAuraEnabled = false

local UpdateWidget
-- Functions switched based on icon/bar mode
local CreateAuraFrame
local UpdateAuraFrame
local UpdateAuraInformation

local UnitAuraList = {}

local ConfigLastUpdate
local CONFIG_WideIcons = false
local CONFIG_ModeBar = false
local CONFIG_GridNoCols = 5
local CONFIG_GridNoRows = 3
local CONFIG_GridSpacingRows = 5
local CONFIG_GridSpacingCols = 8
local CONFIG_LabelLength = 0
local CONFIG_AuraLimit
local CONFIG_AuraWidth
local CONFIG_AuraHeight
local CONFIG_AuraWidgetHeight
local CONFIG_AuraWidgetWidth
local CONFIG_AuraWidgetOffset
local Filter_ByAuraList
local Filter_OnlyPlayerAuras = true
local AURA_FILTER_FRIENDLY = ""
local AURA_FILTER_ENEMY = ""

local AURA_TYPE_BUFF = 1
local AURA_TYPE_DEBUFF = 6

-- Get a clean version of the function...  Avoid OmniCC interference
local CooldownNative = CreateFrame("Cooldown", nil, WorldFrame)
local SetCooldown = CooldownNative.SetCooldown

local WideArt = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\AuraWidget\\AuraFrameWide"
local SquareArt = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\AuraWidget\\AuraFrameSquare"
local WideHighlightArt = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\AuraWidget\\AuraFrameHighlightWide"
local SquareHighlightArt = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\AuraWidget\\AuraFrameHighlightSquare"
local AuraFont = "FONTS\\ARIALN.TTF"

-- Debuffs are color coded, with poison debuffs having a green border, magic debuffs a blue border, diseases a brown border,
-- urses a purple border, and physical debuffs a red border
local AURA_TYPE = { Buff = 1, Curse = 2, Disease = 3, Magic = 4, Poison = 5, Debuff = 6, }

local GRID_LAYOUT = {
  LEFT = {
    BOTTOM =  {"BOTTOMLEFT", 1, 1},
    TOP =     {"TOPLEFT", 1, -1}
  },
  RIGHT = {
    BOTTOM =  {"BOTTOMRIGHT", -1, 1 },
    TOP =     {"TOPRIGHT", -1 , -1}
  }
}

---------------------------------------------------------------------------------------------------
-- Registers a callback, which polls the frame until it expires, then hides the frame and removes the callback
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
      -- Performance
      --			if frame.Expire and frame:GetParent():IsShown() then
      --        frame:Expire()
      --      end

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

local function GetColorForAura(aura)
	local db = TidyPlatesThreat.db.profile.AuraWidget

	local color
	if aura.effect == "HARMFUL" then
    color = db.DefaultDebuffColor
  else
    color = db.DefaultBuffColor
	end

  -- change order and add if to reduce runtime?
	if aura.type and db.ShowAuraType then
    color = DebuffTypeColor[aura.type]
	end

	return color
end

local function FilterWhitelist(spellfound, isMine)
  if spellfound == "All" or spellfound == true then
    return true
  elseif spellfound == "My" then
    return isMine
  end

  return false
end

local function FilterWhitelistMine(spellfound, isMine)
  if spellfound == "All" then
    return true
  elseif spellfound == "My" or spellfound == true then
    return isMine
  end

  return false
end

local function FilterAll(spellfound, isMine)
  return true
end

local function FilterAllMine(spellfound, isMine)
  return isMine
end

local function FilterBlacklist(spellfound, isMine)
  -- blacklist all auras, i.e., default is show all auras (no matter who casted it)
  --   spellfound = true or All - blacklist this aura (from all casters)
  --   spellfound = My          - blacklist only my aura
  --   spellfound = nil         - show aura (spell not found in blacklist)
  --   spellfound = Not         - show aura (found entry not relevant, ignore it)
  if spellfound == "All" or spellfound == true then
    return false
  elseif spellfound == "My" then
    return not isMine
  end

  return true
end

local function FilterBlacklistMine(spellfound, isMine)
  --  blacklist my auras, i.e., default is show all of my auras (non of other players/NPCs)
  --    spellfound = nil             - show my aura (not found in the blacklist)
  --    spellfound = Not             - show my aura (from all casters) - bypass blacklisting
  --    spellfound = My, true or All - blacklist my aura (auras from other casters are not shown either)
  if spellfound == nil then
    return isMine
  elseif spellfound == "Not" then
    return true
  end

  return false
end

local FILTER_FUNCTIONS = {
  whitelist = FilterWhitelist,
  whitelistMine = FilterWhitelistMine,
  all = FilterAll,
  allMine = FilterAllMine,
  blacklist = FilterBlacklist,
  blacklistMine = FilterBlacklistMine,
}

local PRIORITY_FUNCTIONS = {
  None = function(aura) return 0 end,
  AtoZ = function(aura) return aura.name end,
  TimeLeft = function(aura) return aura.expiration - GetTime() end,
  Duration = function(aura) return aura.duration end,
  Creation = function(aura) return aura.expiration - aura.duration end,
}

local function AuraFilterFunction(aura)
  local db = TidyPlatesThreat.db.profile.AuraWidget

  local isType
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

  if not isType then return false, nil, nil  end

  local mode = db.FilterMode
  local isMine = aura.caster == "player" or aura.caster == "pet" or aura.caster == "vehicle"

  local show_aura
  if mode == "BLIZZARD" then
    show_aura = aura.show_all or (aura.show_personal and isMine)
  else
    local spellfound = Filter_ByAuraList[aura.name] or Filter_ByAuraList[aura.spellid]

    local filter_func = FILTER_FUNCTIONS[mode]
    show_aura = filter_func(spellfound, isMine)
  end

  if not show_aura then return show_aura, nil, nil end

  local color = GetColorForAura(aura)

  local sort_order = db.SortOrder
  local priority = PRIORITY_FUNCTIONS[sort_order](aura)

  return show_aura, priority, color
end

local function AuraSortFunctionAtoZ(a, b)
  return a.priority < b.priority
end

local function AuraSortFunctionNum(a, b)
  if a.duration == 0 then
    return false
  elseif b.duration == 0 then
    return true
  else
    return a.priority < b.priority
  end
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

local function UpdateBarAuraInformation(frame) -- texture, duration, expiration, stacks, color, name)
  local db = TidyPlatesThreat.db.profile.AuraWidget

  local aura_info = frame.AuraInfo
  local name = aura_info.name
  local duration = aura_info.duration
  local texture = aura_info.texture
  local expiration = aura_info.expiration
  local stacks = aura_info.stacks
  local color = aura_info.color

  -- Expiration
  UpdateWidgetTimeBar(frame, expiration, duration)

  if db.ShowStackCount and stacks and stacks > 1 then
    frame.Stacks:SetText(stacks)
  else
    frame.Stacks:SetText("")
  end

  -- Icon
  if db.ModeBar.ShowIcon then
    frame.Icon:SetTexture(texture)
  end

  frame.LabelText:SetWidth(CONFIG_LabelLength - frame.TimeText:GetStringWidth())
  frame.LabelText:SetText(name)
  -- Highlight Coloring
  frame.Statusbar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)

  PolledHideIn(frame, expiration, duration)
end

local function UpdateIconAuraInformation(frame) -- texture, duration, expiration, stacks, color, name)
  local db = TidyPlatesThreat.db.profile.AuraWidget

  local aura_info = frame.AuraInfo
  local duration = aura_info.duration
  local texture = aura_info.texture
  local expiration = aura_info.expiration
  local stacks = aura_info.stacks
  local color = aura_info.color

  -- Expiration
  UpdateWidgetTimeIcon(frame, expiration, duration)

  if db.ShowStackCount and stacks and stacks > 1 then
    frame.Stacks:SetText(stacks)
  else
    frame.Stacks:SetText("")
  end

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

  -- Cooldown
  if duration and duration > 0 and expiration and expiration > 0 then
    SetCooldown(frame.Cooldown, expiration-duration, duration+.25)
  end

  PolledHideIn(frame, expiration, duration)
end

local function UpdateIconGrid(frame, unitid)
  if not unitid then return end

  local db = TidyPlatesThreat.db.profile.AuraWidget
  local BLIZZARD_ShowAll = false

  local aura_filter = "NONE"
  local unit_is_friend = UnitIsFriend("player", unitid)
  if unit_is_friend then
    if db.ShowFriendly then
      aura_filter = AURA_FILTER_FRIENDLY
      BLIZZARD_ShowAll = (AURA_FILTER_FRIENDLY == '|RAID')
    end
  else
    if db.ShowEnemy then
      aura_filter = AURA_FILTER_ENEMY
    end
  end

  local aura_frame_list = frame.AuraFrames
  if aura_filter == "NONE" then
    for index = 1, CONFIG_AuraLimit do
      PolledHideIn(aura_frame_list[index])
    end
    return
  end

  -- Cache displayable auras
  ------------------------------------------------------------------------------------------------------
  -- This block will go through the auras on the unit and make a list of those that should
  -- be displayed, listed by priority.
  local searchedDebuffs, searchedBuffs = false, false

  --  GetUnitAuras(UnitAuraList2, unitReaction, unitid, "HARMFUL")
  --  GetUnitAuras(UnitAuraList2, unitReaction, unitid, "HELPFUL")

  local sort_order = db.SortOrder
  if sort_order ~= "None" then
    UnitAuraList = {}
  end

  local aura
  local aura_count = 1
  local index = 0

  local effect = "HARMFUL"
  repeat
    index = index + 1
    -- Example: Gnaw , false, icon, 0 stacks, nil type, duration 1, expiration 8850.436, caster pet, false, false, 91800
    local name, _, icon, stacks, auraType, duration, expiration, caster, _, nameplateShowPersonal, spellid, _, _, _, nameplateShowAll = UnitAura(unitid, index, effect .. aura_filter)

    -- Auras are evaluated by an external function
    -- Pre-filtering before the icon grid is populated
    if name then
      UnitAuraList[aura_count] = UnitAuraList[aura_count] or {}
      aura = UnitAuraList[aura_count]
      --      local aura = {}

      aura.name = name
      aura.texture = icon
      aura.stacks = stacks
      aura.type = auraType
      aura.effect = effect
      aura.duration = duration
      --aura.reaction = unitReaction
      aura.expiration = expiration
      aura.show_personal = nameplateShowPersonal
      aura.show_all = nameplateShowAll or BLIZZARD_ShowAll --(unitReaction == AURA_TARGET_FRIENDLY and aura_filter == "|RAID")
      aura.caster = caster
      aura.spellid = spellid
      aura.unit = unitid 		-- unitid of the plate

      local show, priority, color = AuraFilterFunction(aura)
      -- Store Order/Priority
      if show then
        aura.priority = priority
        aura.color = color

        aura_count = aura_count + 1
        --UnitAuraList[aura_count] = aura
      end
    else
      if db.FilterMode == "BLIZZARD" then break end -- skip HELPFUL auras

      if not searchedDebuffs then
        searchedDebuffs = true
        effect = "HELPFUL"
        index = 0
      else
        searchedBuffs = true
      end
    end

  until (searchedDebuffs and searchedBuffs)

  if sort_order == "None" then
    -- invalidate all entries after storedAuraCount
    -- if number of auras to show was decreased, remove any overflow aura frames
    local i = aura_count
    aura = UnitAuraList[i]
    while aura do
      aura.priority = nil
      i = i + 1
      aura = UnitAuraList[i]
    end
  else
    UnitAuraList[aura_count] = nil
  end

  aura_count = aura_count - 1

  -- Display Auras
  local max_auras_no = aura_count -- min(aura_count, CONFIG_AuraLimit)
  if CONFIG_AuraLimit < max_auras_no then
    max_auras_no = CONFIG_AuraLimit
  end

  if aura_count > 0 then
    if sort_order ~= "None" then
      if sort_order == "AtoZ" then
        sort(UnitAuraList, AuraSortFunctionAtoZ)
      else
        sort(UnitAuraList, AuraSortFunctionNum)
      end
    end

    local index_start, index_end, index_step
    if db.SortReverse then
      index_start, index_end, index_step = max_auras_no, 1, -1
    else
      index_start, index_end, index_step = 1, max_auras_no, 1
    end

    aura_count = 1
    for index = index_start, index_end, index_step do
      local aura = UnitAuraList[index]

      if aura.spellid and aura.expiration then
        local aura_frame = aura_frame_list[aura_count]
        aura_count = aura_count + 1
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
        UpdateAuraInformation(aura_frame)
      end
    end

  end

  -- Clear extra slots
  for index = max_auras_no + 1, CONFIG_AuraLimit do
    PolledHideIn(aura_frame_list[index])
  end
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
  local db = TidyPlatesThreat.db.profile.AuraWidget

	if not (db.ON or db.ShowInHeadlineView) then
    if isAuraEnabled then
      Disable()
      isAuraEnabled = false
    end
	else
    if not isAuraEnabled then
      Enable()
      isAuraEnabled = true
    end
  end

	return db.ON
end

local function EnabledInHeadlineView()
  return TidyPlatesThreat.db.profile.AuraWidget.ShowInHeadlineView
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

local function CreateBarAuraFrame(parent)
  local db = TidyPlatesThreat.db.profile.AuraWidget.ModeBar
  local font = ThreatPlates.Media:Fetch('font', db.Font)

  -- frame is probably not necessary, should be ok do add everything to the statusbar frame
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetFrameLevel(parent:GetFrameLevel())

  frame.Statusbar = CreateFrame("StatusBar", nil, frame)
  frame:SetFrameLevel(parent:GetFrameLevel())
  frame.Statusbar:SetMinMaxValues(0, 100)

  frame.Background = frame.Statusbar:CreateTexture(nil, "BACKGROUND", 0)
  frame.Background:SetAllPoints()

  frame.Icon = frame:CreateTexture(nil, "OVERLAY", 1)
  frame.Stacks = frame.Statusbar:CreateFontString(nil, "OVERLAY")

  frame.LabelText = frame.Statusbar:CreateFontString(nil, "OVERLAY")
  frame.LabelText:SetFont(font, db.FontSize)
  frame.LabelText:SetJustifyH("LEFT")
  frame.LabelText:SetShadowOffset(1, -1)
  frame.LabelText:SetMaxLines(1)

  frame.TimeText = frame.Statusbar:CreateFontString(nil, "OVERLAY")
  frame.TimeText:SetFont(font, db.FontSize)
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
  frame.Poll = UpdateWidgetTimeBar
  frame:Hide()

  return frame
end

local function CreateIconAuraFrame(parent)
  local db = TidyPlatesThreat.db.profile.AuraWidget.ModeBar

  local frame = CreateFrame("Frame", nil, parent)
  frame:SetFrameLevel(parent:GetFrameLevel())

  frame.Icon = frame:CreateTexture(nil, "ARTWORK", 0)
  frame.Border = frame:CreateTexture(nil, "ARTWORK", 1)
  frame.BorderHighlight = frame:CreateTexture(nil, "ARTWORK", 2)
  frame.Stacks = frame:CreateFontString(nil, "OVERLAY")
  frame.Cooldown = CreateFrame("Cooldown", nil, frame, "TidyPlatesAuraWidgetCooldown")
  frame:SetFrameLevel(parent:GetFrameLevel())
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

  frame.AuraInfo = {
    name = "",
    duration = 0,
    texture = "",
    expiration = 0,
    stacks = 0,
    color = 0
  }

  frame.Expire = ExpireFunction
  frame.Poll = UpdateWidgetTimeIcon
  frame:Hide()

  return frame
end

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
local function UpdateBarAuraFrame(frame)
  local db = TidyPlatesThreat.db.profile.AuraWidget.ModeBar
  local font = ThreatPlates.Media:Fetch('font', db.Font)

  -- width and position calculations
  local frame_width = db.BarWidth
  if db.ShowIcon then
    frame_width = frame_width + db.BarHeight + db.IconSpacing
  end
  frame:SetSize(frame_width, db.BarHeight)

  frame.Background:SetTexture(ThreatPlates.Media:Fetch('statusbar', db.BackgroundTexture))
  frame.Background:SetVertexColor(db.BackgroundColor.r, db.BackgroundColor.g, db.BackgroundColor.b, db.BackgroundColor.a)

  frame.LabelText:SetPoint("LEFT", frame.Statusbar, "LEFT", db.LabelTextIndent, 0)
  frame.LabelText:SetFont(font, db.FontSize)
  frame.LabelText:SetTextColor(db.FontColor.r, db.FontColor.g, db.FontColor.b)

  frame.TimeText:SetPoint("RIGHT", frame.Statusbar, "RIGHT", - db.TimeTextIndent, 0)
  frame.TimeText:SetFont(font, db.FontSize)
  frame.TimeText:SetTextColor(db.FontColor.r, db.FontColor.g, db.FontColor.b)

  frame.Icon:ClearAllPoints()
  frame.Statusbar:ClearAllPoints()

  if db.ShowIcon then
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
    frame.Stacks:SetFont(font, db.FontSize, "OUTLINE")
    frame.Stacks:SetShadowOffset(1, -1)
    frame.Stacks:SetShadowColor(0,0,0,1)
    frame.Stacks:SetTextColor(db.FontColor.r, db.FontColor.g, db.FontColor.b)

    frame.Icon:SetTexCoord(0, 1, 0, 1)
    frame.Icon:SetSize(db.BarHeight, db.BarHeight)
    frame.Icon:Show()
  else
    frame.Statusbar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.Icon:Hide()
  end

  frame.Statusbar:SetSize(db.BarWidth, db.BarHeight)
  --    frame.Statusbar:SetWidth(db.BarWidth)
  frame.Statusbar:SetStatusBarTexture(ThreatPlates.Media:Fetch('statusbar', db.Texture))
  frame.Statusbar:GetStatusBarTexture():SetHorizTile(false)
  frame.Statusbar:GetStatusBarTexture():SetVertTile(false)
--    frame.Statusbar:Show()
end

local function UpdateIconAuraFrame(frame)
  local db = TidyPlatesThreat.db.profile.AuraWidget.ModeIcon

  if CONFIG_WideIcons then
    TransformWideAura(frame)
  else
    TransformSquareAura(frame)
  end

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

--  frame.Icon:Show()
--  frame.Border:Show()
--  frame.BorderHighlight:Show()
--  frame.TimeLeft:Show()
end

---------------------------------------------------------------------------------------------------
-- Creation and update functions
---------------------------------------------------------------------------------------------------

local function UpdateAuraWidgetLayout(widget_frame)
  -- Update aura layout if change to layout config since (last_update)
  -- redraw auras (as, e.g., filters may be changed - "soft config changes"
  if ConfigLastUpdate > widget_frame.last_update then
    --assert(false, "CONFIG_LAST_UPDATE")
    local db = TidyPlatesThreat.db.profile.AuraWidget

    local align_layout = GRID_LAYOUT[db.AlignmentH][db.AlignmentV]

    local aura_frame_list = widget_frame.AuraFrames
    local pos_x, pos_y
    local frame
    for index = 1, CONFIG_AuraLimit do
--      local frame = aura_frame_list[index] or CreateAuraFrameLayout(widget_frame)
--      aura_frame_list[index] = frame

      frame = aura_frame_list[index]
      if frame == nil then
        frame = CreateAuraFrame(widget_frame)
        aura_frame_list[index] = frame
      else
--        if (CONFIG_ModeBar and not frame.Statusbar) or (not CONFIG_ModeBar and not frame.Border) then
--          PolledHideIn(frame)
--          frame = CreateAuraFrame(widget_frame)
--          aura_frame_list[index] = frame
--        end
        if CONFIG_ModeBar then
          if not frame.Statusbar then
            PolledHideIn(frame)
            frame = CreateAuraFrame(widget_frame)
            aura_frame_list[index] = frame
          end
        else
          if not frame.Border then
            PolledHideIn(frame)
            frame = CreateAuraFrame(widget_frame)
            aura_frame_list[index] = frame
          end
        end
      end

      -- anchor the frame
      pos_x = (index - 1) % CONFIG_GridNoCols
      pos_x = (pos_x * CONFIG_AuraWidth + CONFIG_AuraWidgetOffset) * align_layout[2]

      pos_y = math.floor((index - 1) / CONFIG_GridNoCols)
      pos_y = (pos_y * CONFIG_AuraHeight + CONFIG_AuraWidgetOffset) * align_layout[3]

      -- anchor the frame
      frame:ClearAllPoints()
      frame:SetPoint(align_layout[1], widget_frame, pos_x, pos_y)

      UpdateAuraFrame(frame)
    end

    -- if number of auras to show was decreased, remove any overflow aura frames
    local index = CONFIG_AuraLimit + 1
    frame = aura_frame_list[index]
    while frame do
      PolledHideIn(frame)
      aura_frame_list[index] = nil
      index = index + 1
      frame = aura_frame_list[index]
    end
    --    for index = CONFIG_AuraLimit + 1, #aura_frame_list do
    --      local frame = aura_frame_list[index]
    --      aura_frame_list[index] = nil
    --      PolledHideIn(frame)
    --    end

    UpdateIconGrid(widget_frame, widget_frame.unitid)

    widget_frame:ClearAllPoints()
    widget_frame:SetPoint(ThreatPlates.ANCHOR_POINT_SETPOINT[db.anchor][2], widget_frame:GetParent(), ThreatPlates.ANCHOR_POINT_SETPOINT[db.anchor][1], db.x, db.y)
    widget_frame:SetSize(CONFIG_AuraWidgetWidth, CONFIG_AuraWidgetHeight)
    widget_frame:SetScale(db.scale)

    if db.FrameOrder == "HEALTHBAR_AURAS" then
      widget_frame:SetFrameLevel(widget_frame:GetParent():GetFrameLevel() + 3)
    else
      widget_frame:SetFrameLevel(widget_frame:GetParent():GetFrameLevel() + 9)
    end

    widget_frame.last_update = GetTime()
  end

end

-- Initialize the aura grid layout, don't update auras themselves as not unitid know at this point
local function CreateAuraWidgetLayout(widget_frame)
  local db = TidyPlatesThreat.db.profile.AuraWidget

  local align_layout = GRID_LAYOUT[db.AlignmentH][db.AlignmentV]

  local aura_frame_list = widget_frame.AuraFrames
  local pos_x, pos_y
  for index = 1, CONFIG_AuraLimit do
    --    local frame = aura_frame_list[index] or CreateAuraFrameLayout(widget_frame)
    --    aura_frame_list[index] = frame
    local frame = CreateAuraFrame(widget_frame)
    aura_frame_list[index] = frame

    pos_x = (index - 1) % CONFIG_GridNoCols
    pos_x = (pos_x * CONFIG_AuraWidth + CONFIG_AuraWidgetOffset) * align_layout[2]

    pos_y = math.floor((index - 1) / CONFIG_GridNoCols)
    pos_y = (pos_y * CONFIG_AuraHeight + CONFIG_AuraWidgetOffset) * align_layout[3]

    -- anchor the frame
    --frame:ClearAllPoints()
    frame:SetPoint(align_layout[1], widget_frame, pos_x, pos_y)

    UpdateAuraFrame(frame)
  end

  --widget_frame:ClearAllPoints()
  widget_frame:SetPoint(ThreatPlates.ANCHOR_POINT_SETPOINT[db.anchor][2], widget_frame:GetParent(), ThreatPlates.ANCHOR_POINT_SETPOINT[db.anchor][1], db.x, db.y)
  widget_frame:SetSize(CONFIG_AuraWidgetWidth, CONFIG_AuraWidgetHeight)
  widget_frame:SetScale(db.scale)

  widget_frame.last_update = GetTime()
end

function UpdateWidget(frame)
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
    if old_frame ~= frame then
      WidgetList[unitid] = frame
      UpdateIconGrid(frame, frame.unitid)
    end
  end

	-- Custom Code II
	--------------------------------------
  if TidyPlatesThreat.db.profile.AuraWidget.ShowTargetOnly and not unit.isTarget then
    frame:_Hide()
  else
    frame:Show()
  end
	--------------------------------------
	-- End Custom Code
end

local function ForceAurasUpdate()
  ConfigLastUpdate = GetTime()
end

local function PrepareFilter()
  local db = TidyPlatesThreat.db.profile.AuraWidget

  Filter_ByAuraList = {}
  Filter_OnlyPlayerAuras = true

  local modifier, spell
  for key, value in pairs(db.FilterBySpell) do
    -- remove comments and whitespaces from the filter (string)
    local pos = value:find("%-%-")
    if pos then value = value:sub(1, pos - 1) end
    value = value:match("^%s*(.-)%s*$")  -- remove any leading/trailing whitespaces from the line

    -- value:match("^%s*(%w+)%s*(.-)%s*$")  -- remove any leading/trailing whitespaces from the line
    if value:sub(1, 4) == "All " then
      modifier = "All"
      spell = value:match("^All%s*(.-)$")
      Filter_OnlyPlayerAuras = false
    elseif value:sub(1, 3) == "My " then
      modifier = "My"
      spell = value:match("^My%s*(.-)$")
    elseif value:sub(1, 4) == "Not " then
      modifier = "Not"
      spell = value:match("^Not%s*(.-)$")
      Filter_OnlyPlayerAuras = false
    else
      modifier = true
      spell = value
    end

    -- separete filter by name and ID for more efficient aura filtering
    local spell_no = tonumber(spell)
    if spell_no then
      Filter_ByAuraList[spell_no] = modifier
    elseif spell ~= '' then
      Filter_ByAuraList[spell] = modifier
    end
  end

  if db.FilterMode == "BLIZZARD" then
    -- Blizzard default is
    --   UnitReaction <=4: filter = "HARMFUL|INCLUDE_NAME_PLATE_ONLY"
    --   UnitReaction >4: filter = "NONE" or filter = "HARMFUL|RAID" (with showAll) if nameplateShowDebuffsOnFriendly == true (for 7.3)
    AURA_FILTER_ENEMY = "|INCLUDE_NAME_PLATE_ONLY"
    AURA_FILTER_FRIENDLY = (db.ShowDebuffsOnFriendly and '|RAID') or "NONE"
  elseif string.find(db.FilterMode, "Mine") and Filter_OnlyPlayerAuras then
    AURA_FILTER_ENEMY = "|PLAYER"
    AURA_FILTER_FRIENDLY = "|PLAYER"
  else
    AURA_FILTER_ENEMY = ""
    AURA_FILTER_FRIENDLY = ""
  end

  ConfigLastUpdate = GetTime()
end

-- Load settings from the configuration which are shared across all aura widgets
-- used (for each widget) in UpdateWidgetConfig
local function ConfigAuraWidget()
	local db = TidyPlatesThreat.db.profile.AuraWidget

  CONFIG_WideIcons = (db.ModeIcon.Style == "wide")
  CONFIG_ModeBar = db.ModeBar.Enabled

  if CONFIG_ModeBar then
    local db_mode = db.ModeBar
    CONFIG_GridNoRows = db_mode.MaxBars
    CONFIG_GridNoCols = 1
    CONFIG_GridSpacingRows = db_mode.BarSpacing
    CONFIG_GridSpacingCols = 0
		CONFIG_LabelLength = db_mode.BarWidth - db_mode.LabelTextIndent - db_mode.TimeTextIndent - (db_mode.FontSize / 5)
    UPDATE_INTERVAL = 1 / GetFramerate()

    CONFIG_AuraWidgetOffset = 0
    CONFIG_AuraWidth = db_mode.BarWidth
    CONFIG_AuraHeight = db_mode.BarHeight
    CONFIG_AuraWidgetWidth = CONFIG_AuraWidth
    if db_mode.ShowIcon then
      CONFIG_AuraWidgetWidth = CONFIG_AuraWidth + db_mode.BarHeight + db_mode.IconSpacing
    end

    CreateAuraFrame = CreateBarAuraFrame
    UpdateAuraFrame = UpdateBarAuraFrame
    UpdateAuraInformation = UpdateBarAuraInformation
  else
    local db_mode = db.ModeIcon
    CONFIG_GridNoRows = db_mode.Rows
    CONFIG_GridNoCols = db_mode.Columns
    CONFIG_GridSpacingRows = db_mode.RowSpacing
    CONFIG_GridSpacingCols = db_mode.ColumnSpacing
    UPDATE_INTERVAL = 0.5

    CONFIG_AuraWidgetOffset = (db.ShowAuraType and 2) or 1
    CONFIG_AuraWidth = ((CONFIG_WideIcons and 26.5) or 16.5)
    CONFIG_AuraHeight = 14.5
    -- Optimized calculation based on: CONFIG_AURA_FRAME_WIDTH = (CONFIG_AURA_FRAME_WIDTH + (CONFIG_AURA_FRAME_OFFSET * 2)) * CONFIG_GRID_NO_COLS + ((CONFIG_GRID_SPACING_COLS - (CONFIG_AURA_FRAME_OFFSET * 2)) * (CONFIG_GRID_NO_COLS - 1))
    CONFIG_AuraWidgetWidth = (CONFIG_AuraWidth * CONFIG_GridNoCols) + (CONFIG_GridSpacingCols * CONFIG_GridNoCols) - CONFIG_GridSpacingCols + (CONFIG_AuraWidgetOffset * 2)

    CreateAuraFrame = CreateIconAuraFrame
    UpdateAuraFrame = UpdateIconAuraFrame
    UpdateAuraInformation = UpdateIconAuraInformation
	end
  CONFIG_AuraWidgetHeight = (CONFIG_AuraHeight * CONFIG_GridNoRows) + (CONFIG_GridSpacingRows * CONFIG_GridNoRows) - CONFIG_GridSpacingRows + (CONFIG_AuraWidgetOffset * 2)

  CONFIG_AuraLimit = CONFIG_GridNoRows * CONFIG_GridNoCols
  CONFIG_AuraWidth = CONFIG_AuraWidth + CONFIG_GridSpacingCols
  CONFIG_AuraHeight = CONFIG_AuraHeight + CONFIG_GridSpacingRows

  if db.FilterMode == "BLIZZARD" then
    -- Blizzard default is
    --   UnitReaction <=4: filter = "HARMFUL|INCLUDE_NAME_PLATE_ONLY"
    --   UnitReaction >4: filter = "NONE" or filter = "HARMFUL|RAID" (with showAll) if nameplateShowDebuffsOnFriendly == true (for 7.3)
    AURA_FILTER_ENEMY = "|INCLUDE_NAME_PLATE_ONLY"
    AURA_FILTER_FRIENDLY = (db.ShowDebuffsOnFriendly and '|RAID') or "NONE"
  elseif string.find(db.FilterMode, "Mine") and Filter_OnlyPlayerAuras then
    AURA_FILTER_ENEMY = "|PLAYER"
    AURA_FILTER_FRIENDLY = "|PLAYER"
  else
    AURA_FILTER_ENEMY = ""
    AURA_FILTER_FRIENDLY = ""
  end

	ConfigLastUpdate = GetTime()
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

	-- Custom Code III
	--------------------------------------
  if TidyPlatesThreat.db.profile.AuraWidget.FrameOrder == "HEALTHBAR_AURAS" then
    frame:SetFrameLevel(plate:GetFrameLevel() + 3)
  else
    frame:SetFrameLevel(plate:GetFrameLevel() + 9)
  end
	frame:SetSize(128, 32)
	frame.AuraFrames = {}
  --UpdateWidgetConfig(frame)
  CreateAuraWidgetLayout(frame)
	--------------------------------------
	-- End Custom Code

	-- Required Widget Code
  frame.Update = UpdateWidgetContext
  frame.UpdateContext = UpdateWidgetContext
	frame.UpdateConfig = UpdateAuraWidgetLayout
	frame._Hide = frame.Hide
	frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end

	return frame
end

-----------------------------------------------------
-- External
-----------------------------------------------------

ThreatPlatesWidgets.ConfigAuraWidget = ConfigAuraWidget
ThreatPlatesWidgets.ConfigAuraWidgetFilter = PrepareFilter
ThreatPlatesWidgets.ForceAurasUpdate = ForceAurasUpdate

-----------------------------------------------------
-- Register widget
-----------------------------------------------------

ThreatPlatesWidgets.RegisterWidget("AuraWidget2TPTP", CreateAuraWidget, false, enabled, EnabledInHeadlineView)
