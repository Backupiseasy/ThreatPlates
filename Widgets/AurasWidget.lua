---------------------------------------------------------------------------------------------------
-- Auras Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon:NewWidget("Auras")

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
local CreateFrame, GetFramerate = CreateFrame, GetFramerate
local DebuffTypeColor = DebuffTypeColor
local UnitAura, UnitIsFriend, UnitIsUnit = UnitAura, UnitIsFriend, UnitIsUnit
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local RGB = ThreatPlates.RGB
local DEBUG = ThreatPlates.DEBUG
local ON_UPDATE_INTERVAL = Addon.ON_UPDATE_INTERVAL

---------------------------------------------------------------------------------------------------
-- Auras Widget Functions
---------------------------------------------------------------------------------------------------

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
  },
}

-- Functions switched based on icon/bar mode
local CreateAuraFrame
local UpdateAuraFrame
local UpdateAuraInformation

local UnitAuraList = {}

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
local CONFIG_CenterAurasPositions = {}

local Filter_ByAuraList
local Filter_OnlyPlayerAuras = true
local AURA_FILTER_FRIENDLY = ""
local AURA_FILTER_ENEMY = ""

local AURA_TYPE_BUFF = 1
local AURA_TYPE_DEBUFF = 6

-- Default for icon mode is 0.5, for bar mode "1 / GetFramerate()" is used for smooth updates -- GetFramerate() in frames/second
local UPDATE_INTERVAL = ON_UPDATE_INTERVAL


-- Get a clean version of the function...  Avoid OmniCC interference
local CooldownNative = CreateFrame("Cooldown", nil, WorldFrame)
local SetCooldown = CooldownNative.SetCooldown

local CurrentTarget

---------------------------------------------------------------------------------------------------
-- OnUpdate code - updates the auras remaining uptime and stacks and hides them after they expired
---------------------------------------------------------------------------------------------------

local function OnUpdateAurasWidget(widget_frame, elapsed)
  -- Update the number of seconds since the last update
  widget_frame.TimeSinceLastUpdate = widget_frame.TimeSinceLastUpdate + elapsed

  if widget_frame.TimeSinceLastUpdate >= UPDATE_INTERVAL then
    --print ("AurasWidget: OnUpdate handler called -", widget_frame.unit.name, widget_frame.TimeSinceLastUpdate)
    -- print ("AurasWidget: Active auras -", widget_frame.ActiveAuras)

    widget_frame.TimeSinceLastUpdate = 0

    local current_time = GetTime()
    for i = 1, widget_frame.ActiveAuras do
      local aura_frame = widget_frame.AuraFrames[i]
      aura_frame:UpdateAuraTimer(aura_frame.AuraInfo.expiration, aura_frame.AuraInfo.duration)
    end
  end
end

local function OnShowHookScript(widget_frame)
  --print ("AurasWidget: OnShow hook script called")
  widget_frame.TimeSinceLastUpdate = 0
end

--local function OnHideHookScript(widget_frame)
--  widget_frame:UnregisterAllEvents()
--end

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

  frame:Show()
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
    SetCooldown(frame.Cooldown, expiration - duration, duration + .25)
  else
    frame.Cooldown:Clear()
  end

  frame:Show()
end

local function UpdateIconGrid(widget_frame, unitid)
  local db = TidyPlatesThreat.db.profile.AuraWidget
  local BLIZZARD_ShowAll = false

  local aura_filter = "NONE"
  -- TODO: Should this not be rather UnitReaction(unitid, "player") > 4, like everywhere else?
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

  local aura_frame_list = widget_frame.AuraFrames
  if aura_filter == "NONE" then
    -- If widget_frame is hidden here, calling PolledHideIn should not be necessary - Test!
    for index = 1, CONFIG_AuraLimit do
      aura_frame_list[index]:Hide()
    end
    widget_frame.ActiveAuras = 0
    widget_frame:Hide()
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
    -- BfA: Blizzard Code:local name, texture, count, debuffType, duration, expirationTime, caster, _, nameplateShowPersonal, spellId, _, _, _, nameplateShowAll = UnitAura(unit, i, filter);
    -- BfA: local name, icon, stacks, auraType, duration, expiration, caster, _, nameplateShowPersonal, spellid, _, _, _, nameplateShowAll = UnitAura(unitid, index, effect .. aura_filter)
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

  --    print ("AurasWidget: HIDING widget because of active auras")
  --    widget_frame:Hide()

  widget_frame.ActiveAuras = max_auras_no

  -- Clear extra slots
  for index = max_auras_no + 1, CONFIG_AuraLimit do
    aura_frame_list[index]:Hide()
  end

  if max_auras_no > 0 then
    if TidyPlatesThreat.db.profile.AuraWidget.ShowTargetOnly then
      if not UnitIsUnit("target", widget_frame.unit.unitid) then
        widget_frame:Hide()
        return
      end

      CurrentTarget = widget_frame
    end

    --print ("AurasWidget: SHOWING widget because of active auras")
    widget_frame:Show()

    if not CONFIG_ModeBar and db.CenterAuras then
      local point, relativeTo, relativePoint, xOfs, yOfs = widget_frame:GetPoint(1)

      local aura_no = widget_frame.ActiveAuras
      if aura_no > CONFIG_GridNoCols then
        aura_no = CONFIG_GridNoCols
      end

      widget_frame:SetPoint(point, relativeTo, relativePoint, db.x + CONFIG_CenterAurasPositions[aura_no], yOfs)
    end
  else
    widget_frame:Hide()
  end
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

local function CreateIconAuraFrame(parent)
  local db = TidyPlatesThreat.db.profile.AuraWidget.ModeBar

  local frame = CreateFrame("Frame", nil, parent)

  frame.Icon = frame:CreateTexture(nil, "ARTWORK", 0)

  frame.Cooldown = CreateFrame("Cooldown", nil, frame, "ThreatPlatesAuraWidgetCooldown")
  frame.Cooldown:SetAllPoints(frame.Icon)
  frame.Cooldown:SetReverse(true)
  frame.Cooldown:SetHideCountdownNumbers(true)

  frame.Border = frame:CreateTexture(nil, "ARTWORK", 1)
  frame.BorderHighlight = frame:CreateTexture(nil, "ARTWORK", 2)
  frame.Stacks = frame.Cooldown:CreateFontString(nil, "OVERLAY")

  --  Time Text
  frame.TimeLeft = frame.Cooldown:CreateFontString(nil, "OVERLAY")
  frame.TimeLeft:SetFont(AuraFont ,9, "OUTLINE")
  frame.TimeLeft:SetShadowOffset(1, -1)
  frame.TimeLeft:SetShadowColor(0,0,0,1)
  frame.TimeLeft:SetPoint("RIGHT", 0, 8)
  frame.TimeLeft:SetSize(26, 16)
  frame.TimeLeft:SetJustifyH("RIGHT")

  frame.UpdateAuraTimer = UpdateWidgetTimeIcon
  frame:Hide()

  frame.AuraInfo = {
    name = "",
    duration = 0,
    texture = "",
    expiration = 0,
    stacks = 0,
    color = 0
  }

  return frame
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
    frame.Cooldown:SetDrawSwipe(true)
    --frame.Cooldown:SetFrameLevel(frame:GetParent():GetFrameLevel() + 10)
  else
    frame.Cooldown:SetDrawEdge(false)
    frame.Cooldown:SetDrawSwipe(false)
  end
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

  frame.UpdateAuraTimer = UpdateWidgetTimeBar
  frame:Hide()

  frame.AuraInfo = {
    name = "",
    duration = 0,
    texture = "",
    expiration = 0,
    stacks = 0,
    color = 0
  }

  return frame
end

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

---------------------------------------------------------------------------------------------------
-- Creation and update functions
---------------------------------------------------------------------------------------------------

-- Initialize the aura grid layout, don't update auras themselves as not unitid know at this point
local function CreateAuraWidgetLayout(widget_frame)
  local db = TidyPlatesThreat.db.profile.AuraWidget

  local align_layout = GRID_LAYOUT[db.AlignmentH][db.AlignmentV]

  local aura_frame_list = widget_frame.AuraFrames
  local pos_x, pos_y

  local frame
  for i = 1, CONFIG_AuraLimit do
    frame = aura_frame_list[i]
    if frame == nil then
      frame = CreateAuraFrame(widget_frame)
      aura_frame_list[i] = frame
    else
      if CONFIG_ModeBar then
        if not frame.Statusbar then
          frame:Hide()
          frame = CreateAuraFrame(widget_frame)
          aura_frame_list[i] = frame
        end
      else
        if not frame.Border then
          frame:Hide()
          frame = CreateAuraFrame(widget_frame)
          aura_frame_list[i] = frame
        end
      end
    end

    pos_x = (i - 1) % CONFIG_GridNoCols
    pos_x = (pos_x * CONFIG_AuraWidth + CONFIG_AuraWidgetOffset) * align_layout[2]

    pos_y = math.floor((i - 1) / CONFIG_GridNoCols)
    pos_y = (pos_y * CONFIG_AuraHeight + CONFIG_AuraWidgetOffset) * align_layout[3]

    -- anchor the frame
    frame:ClearAllPoints()
    frame:SetPoint(align_layout[1], widget_frame, pos_x, pos_y)

    UpdateAuraFrame(frame)
  end

  -- if number of auras to show was decreased, remove any overflow aura frames
  for i = #aura_frame_list, CONFIG_AuraLimit + 1, -1 do
    aura_frame_list[i]:Hide()
    aura_frame_list[i] = nil
  end

  widget_frame:ClearAllPoints()
  widget_frame:SetPoint(ThreatPlates.ANCHOR_POINT_SETPOINT[db.anchor][2], widget_frame:GetParent(), ThreatPlates.ANCHOR_POINT_SETPOINT[db.anchor][1], db.x, db.y)
  widget_frame:SetSize(CONFIG_AuraWidgetWidth, CONFIG_AuraWidgetHeight)
  widget_frame:SetScale(db.scale)

  if TidyPlatesThreat.db.profile.AuraWidget.FrameOrder == "HEALTHBAR_AURAS" then
    widget_frame:SetFrameLevel(widget_frame:GetFrameLevel() + 3)
  else
    widget_frame:SetFrameLevel(widget_frame:GetFrameLevel() + 9)
  end
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
    UPDATE_INTERVAL = ON_UPDATE_INTERVAL

    CONFIG_AuraWidgetOffset = (db.ShowAuraType and 2) or 1
    CONFIG_AuraWidth = ((CONFIG_WideIcons and 26.5) or 16.5)
    CONFIG_AuraHeight = 14.5
    -- Optimized calculation based on: CONFIG_AURA_FRAME_WIDTH = (CONFIG_AURA_FRAME_WIDTH + (CONFIG_AURA_FRAME_OFFSET * 2)) * CONFIG_GRID_NO_COLS + ((CONFIG_GRID_SPACING_COLS - (CONFIG_AURA_FRAME_OFFSET * 2)) * (CONFIG_GRID_NO_COLS - 1))
    CONFIG_AuraWidgetWidth = (CONFIG_AuraWidth * CONFIG_GridNoCols) + (CONFIG_GridSpacingCols * CONFIG_GridNoCols) - CONFIG_GridSpacingCols + (CONFIG_AuraWidgetOffset * 2)

    CreateAuraFrame = CreateIconAuraFrame
    UpdateAuraFrame = UpdateIconAuraFrame
    UpdateAuraInformation = UpdateIconAuraInformation

    for i = 1, CONFIG_GridNoCols do
      local active_auras_width = (CONFIG_AuraWidth * i) + (CONFIG_GridSpacingCols * i) - CONFIG_GridSpacingCols + (CONFIG_AuraWidgetOffset * 2)
      CONFIG_CenterAurasPositions[i] = (CONFIG_AuraWidgetWidth - active_auras_width) / 2
    end
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
end

local function UnitAuraEventHandler(widget_frame, event, unitid)
  --print ("AurasWidget: UNIT_AURA: ", event, unitid)
  if unitid ~= widget_frame.unit.unitid then
    print ("AurasWidget: UNIT_AURA for", unitid)
    print ("AurasWidget: Plate Active:", Addon.PlatesByUnit[unitid].Active)
    print ("AurasWidget: Plate Unit:", Addon.PlatesByUnit[unitid].TPFrame.unit.unitid)
    print ("AurasWidget: Plate WidgetFrame:", Addon.PlatesByUnit[unitid].TPFrame.widgets.Auras, Addon.PlatesByUnit[unitid].TPFrame.widgets.Auras.Active, Addon.PlatesByUnit[unitid].TPFrame.widgets.Auras == widget_frame)
    print ("Unit:")
    print ("Unit Name:", UnitName(unitid))
    print ("Unit is Player:", UnitIsPlayer(unitid))
    return
  end

  --  -- Skip player (cause TP does not handle player nameplate) and target (as it is updated via it's actual unitid anyway)
  --  if unitid == "player" or unitid == "target" then return end

  if widget_frame.Active then
    UpdateIconGrid(widget_frame, unitid)

--    if not widget_frame.TestBackground then
--      widget_frame.TestBackground = widget_frame:CreateTexture(nil, "BACKGROUND")
--    end
--    widget_frame.TestBackground:SetAllPoints(widget_frame)
--    widget_frame.TestBackground:SetTexture(ThreatPlates.Media:Fetch('statusbar', "Smooth"))
--    widget_frame.TestBackground:SetVertexColor(0,0,0,0.5)
  end

  -- Nameplates are re-used. Old events are unregistered when the unit is added, but if the nameplate is not
  -- shown for this unit, this does not happen. So do it here the first time we get an event for this unit.
  --print ("Unregistering events")
  --widget_frame:UnregisterAllEvents()

end

--function Widget:UNIT_AURA(unitid)
--  -- Skip player (cause TP does not handle player nameplate) and target (as it is updated via it's actual unitid anyway)
--  if unitid == "player" or unitid == "target" then return end
--
--  local plate = GetNamePlateForUnit(unitid)
--  if plate and plate.TPFrame.Active then -- plate maybe nil as not all UNIT_AURA events are on units with nameplates
--    local widget_frame = plate.TPFrame.widgets.Auras
--    if widget_frame.Active then
--      print ("AurasWidget: UNIT_AURA for", unitid)
--      UpdateIconGrid(widget_frame, unitid)
--    end
--  end
--end

function Widget:PLAYER_TARGET_CHANGED()
  if not TidyPlatesThreat.db.profile.AuraWidget.ShowTargetOnly then return end

  if CurrentTarget then
    CurrentTarget:Hide()
    CurrentTarget = nil
  end

  local plate = GetNamePlateForUnit("target")
  if plate and plate.TPFrame.Active then
    CurrentTarget = plate.TPFrame.widgets.Auras

    if CurrentTarget.Active and CurrentTarget.ActiveAuras > 0 then
      print ("AurasWidget: SHOWING widget because of active auras")
      CurrentTarget:Show()
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------
  widget_frame.AuraFrames = {}
  widget_frame.ActiveAuras = 0

  --CreateAuraWidgetLayout(widget_frame)

  widget_frame:SetScript("OnEvent", UnitAuraEventHandler)
  widget_frame:SetScript("OnUpdate", OnUpdateAurasWidget)
  widget_frame:HookScript("OnShow", OnShowHookScript)
  -- widget_frame:HookScript("OnHide", OnHideHookScript)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  return TidyPlatesThreat.db.profile.AuraWidget.ON or TidyPlatesThreat.db.profile.AuraWidget.ShowInHeadlineView
end

function Widget:OnEnable()
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function Widget:OnDisable()
  for plate, _ in pairs(Addon.PlatesVisible) do
    plate.TPFrame.widgets.Auras:UnregisterAllEvents()
  end
end

function Widget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return TidyPlatesThreat.db.profile.AuraWidget.ShowInHeadlineView
  elseif style ~= "etotem" then
    return TidyPlatesThreat.db.profile.AuraWidget.ON
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  CreateAuraWidgetLayout(widget_frame)

  widget_frame:UnregisterAllEvents()
  widget_frame:RegisterUnitEvent("UNIT_AURA", unit.unitid)

  UpdateIconGrid(widget_frame, unit.unitid)
end

function Widget:OnUnitRemoved(widget_frame)
  widget_frame:UnregisterAllEvents()
end

-----------------------------------------------------
-- External
-----------------------------------------------------

ThreatPlatesWidgets.ConfigAuraWidget = ConfigAuraWidget
ThreatPlatesWidgets.ConfigAuraWidgetFilter = PrepareFilter