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
local floor, ceil = floor, ceil
local sort = sort
local math = math
local string = string
local tonumber = tonumber

-- WoW APIs
local CreateFrame, GetFramerate = CreateFrame, GetFramerate
local DebuffTypeColor = DebuffTypeColor
local UnitAura, UnitIsFriend, UnitIsUnit, UnitReaction = UnitAura, UnitIsFriend, UnitIsUnit, UnitReaction
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local Animations = Addon.Animations
local RGB = ThreatPlates.RGB
local DEBUG = ThreatPlates.DEBUG
local ON_UPDATE_INTERVAL = Addon.ON_UPDATE_INTERVAL
local ANCHOR_POINT_SETPOINT = ThreatPlates.ANCHOR_POINT_SETPOINT
local FLASH_DURATION = Addon.Animations.FLASH_DURATION

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
local AURA_TYPE = { Curse = 1, Disease = 2, Magic = 3, Poison = 4, }

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

local LOC_CHARM = 1
local LOC_FEAR = 2
local LOC_POLYMORPH = 3
local LOC_STUN = 4
local LOC_INCAPACITATE = 5
local LOC_SLEEP = 6
local LOC_DISORIENT = 7
local LOC_BANISH = 8
local LOC_HORROR = 9

local PC_SNARE = 50
local PC_ROOT = 51
local PC_DAZE = 52
local PC_GRIP = 53

local CC_SILENCE = 101

local CROWD_CONTROL_SPELLS = {
  -- Druid
  [33786] = LOC_BANISH,           -- Cyclone (PvP Talent, Restoration)
  [209753] = LOC_BANISH,          -- Cyclone (PvP Talent, Balance)
  [339] = PC_ROOT,                -- Entangling Roots
  [99] = LOC_INCAPACITATE,        -- Incapacitating Roar
  [203123] = LOC_STUN,            -- Maim
  [102359] = PC_ROOT,             -- Mass Entanglement (Talent)
  [5211] = LOC_STUN,              -- Mighty Bash (Talent)
  [163505] = LOC_STUN,            -- Rake
  [78675] = CC_SILENCE,           -- Solar Beam
  [61391] = PC_DAZE,              -- Typhoon (Talent)
  [106839] = CC_SILENCE,          -- Skull Bash

  -- Death Knight
  -- Demon Hunter

  -- Hunter
  [3355] = "Freezing Trap",
  [19577] = "Intimidation",
  [19386] = "Wyvern Sting",

  -- Mage
  [118] = "Polymorph", -- Sheep
  [28271] = "Polymorph", -- Turtle
  [28272] = "Polymorph", -- Pig
  [61305] = "Polymorph", -- Black Cat
  [61721] = "Polymorph", -- Rabbit
  [61025] = "Polymorph", -- Serpent
  [61780] = "Polymorph", -- Turkey
  [161372] = "Polymorph", -- Peacock
  [161355] = "Polymorph", -- Penguin
  [161353] = "Polymorph", -- Polar Bear Cub
  [161354] = "Polymorph", -- Monkey
  [126819] = "Polymorph", -- Porcupine
  [113724] = "Polymorph", -- Ring of Frost

  -- Paladin
  [20066] = "Repentence",

  -- Priest
  [605] = "Mind Control",

  -- Rogue

  -- Shaman
  [51514] = "Hex", -- Frog
  [210873] = "Hex", -- Compy
  [211004] = "Hex", -- Spider
  [211015] = "Hex", -- Cockroach
  [211010] = "Hex", -- Snake

  -- Warlock
  [5782] = "Fear",

  -- Warrior
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

local AuraFilterBuffs
local AuraFilterDebuffs
local AuraFilterCrowdControl

local AuraFilter = {
  Enemy = {
    Buffs = "",
    Debuffs = "",
    CrowdControl = "",
  },
  Friendly = {
    Buffs = "",
    Debuffs = "",
    CrowdControl = "",
  }
}

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

    local aura_frame
    local current_time = GetTime()
    for i = 1, widget_frame.Debuffs.ActiveAuras do
      aura_frame = widget_frame.Debuffs.AuraFrames[i]
      aura_frame:UpdateAuraTimer(aura_frame.AuraInfo.expiration, aura_frame.AuraInfo.duration)
    end

    for i = 1, widget_frame.Buffs.ActiveAuras do
      aura_frame = widget_frame.Buffs.AuraFrames[i]
      aura_frame:UpdateAuraTimer(aura_frame.AuraInfo.expiration, aura_frame.AuraInfo.duration)
    end

    for i = 1, widget_frame.CrowdControl.ActiveAuras do
      aura_frame = widget_frame.CrowdControl.AuraFrames[i]
      aura_frame:UpdateAuraTimer(aura_frame.AuraInfo.expiration, aura_frame.AuraInfo.duration)
    end
  end
end

local function UpdateWidgetTimeIcon(frame, expiration, duration)
  if expiration == 0 then
    frame.TimeLeft:SetText("")
    Animations:StopFlash(frame)
  else
    local timeleft = expiration - GetTime()

    if timeleft > 60 then
      frame.TimeLeft:SetText(floor(timeleft/60).."m")
    else
      frame.TimeLeft:SetText(floor(timeleft))
      --frame.TimeLeft:SetText(floor(timeleft*10)/10)

      local db = TidyPlatesThreat.db.profile.AuraWidget
      if db.FlashWhenExpiring and timeleft < db.FlashTime then
        Animations:Flash(frame, FLASH_DURATION)
      end
    end
  end
end

local function UpdateWidgetTimeBar(frame, expiration, duration)
  if duration == 0 then
    frame.TimeText:SetText("")
    frame.Statusbar:SetValue(100)
    Animations:StopFlash(frame)
  elseif expiration == 0 then
    frame.TimeText:SetText("")
    frame.Statusbar:SetValue(0)
    Animations:StopFlash(frame)
  else
    local timeleft = expiration - GetTime()

    if timeleft > 60 then
      frame.TimeText:SetText(floor(timeleft/60).."m")
    else
      frame.TimeText:SetText(floor(timeleft))

      local db = TidyPlatesThreat.db.profile.AuraWidget
      if db.FlashWhenExpiring and timeleft < db.FlashTime then
        Animations:Flash(frame, FLASH_DURATION)
      end
    end
    frame.Statusbar:SetValue(timeleft * 100 / duration)
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

  if aura.type and db.ShowAuraType then
    return DebuffTypeColor[aura.type]
  elseif aura.effect == "HARMFUL" then
    return db.DefaultDebuffColor
  else
    return db.DefaultBuffColor
	end
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

local function AuraFilterFunction(db, aura)
  -- only show aura types configured in the options
  if db.FilterByType and aura.type then
    if not db.FilterByType[AURA_TYPE[aura.type]] then return false end
  end

  local is_player_aura = aura.caster == "player" or aura.caster == "pet" or aura.caster == "vehicle"

  if db.FilterMode == "BLIZZARD" then
    return aura.ShowAll or (aura.ShowPersonal and is_player_aura)
  end

  local aura_filter
  if aura.CrowdControl then
    aura_filter = AuraFilterCrowdControl
  elseif aura.effect == "HELPFUL" then
    aura_filter = AuraFilterBuffs
  else
    aura_filter = AuraFilterDebuffs
  end

  local spellfound = aura_filter[aura.name] or aura_filter[aura.spellid]

  return FILTER_FUNCTIONS[db.FilterMode](spellfound, is_player_aura)
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

local function UpdateBarAuraInformation(frame) -- texture, duration, expiration, stacks, color, name)
  local db = TidyPlatesThreat.db.profile.AuraWidget

  local aura_info = frame.AuraInfo
  local stacks = aura_info.stacks
  local color = aura_info.color

  -- Expiration
  UpdateWidgetTimeBar(frame, aura_info.expiration, aura_info.duration)

  if db.ShowStackCount and stacks and stacks > 1 then
    frame.Stacks:SetText(stacks)
  else
    frame.Stacks:SetText("")
  end

  -- Icon
  if db.ModeBar.ShowIcon then
    frame.Icon:SetTexture(aura_info.texture)
  end

  frame.LabelText:SetWidth(CONFIG_LabelLength - frame.TimeText:GetStringWidth())
  frame.LabelText:SetText(aura_info.name)
  -- Highlight Coloring
  frame.Statusbar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)

  Animations:StopFlash(frame)

  frame:Show()
end

local function UpdateIconAuraInformation(frame) -- texture, duration, expiration, stacks, color, name)
  local db = TidyPlatesThreat.db.profile.AuraWidget

  local aura_info = frame.AuraInfo
  local duration = aura_info.duration
  local expiration = aura_info.expiration
  local stacks = aura_info.stacks
  local color = aura_info.color

  -- Expiration
  UpdateWidgetTimeIcon(frame, aura_info.expiration, aura_info.duration)

  if db.ShowStackCount and stacks and stacks > 1 then
    frame.Stacks:SetText(stacks)
  else
    frame.Stacks:SetText("")
  end

  frame.Icon:SetTexture(aura_info.texture)

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

  Animations:StopFlash(frame)

  frame:Show()
end

local function UpdateUnitAuras(frame, unitid, effect, aura_filter, BLIZZARD_ShowAll, show_cc)
  local aura_frame_list = frame.AuraFrames
  if aura_filter == "NONE" then
    -- If widget_frame is hidden here, calling PolledHideIn should not be necessary - Test!
    for i = 1, CONFIG_AuraLimit do
      aura_frame_list[i]:Hide()
    end
    frame.ActiveAuras = 0
    frame:Hide()
    return
  end

  -- This block will go through the auras on the unit and make a list of those that should
  -- be displayed, listed by priority.
  local db = TidyPlatesThreat.db.profile.AuraWidget
  local sort_order = db.SortOrder
  if sort_order ~= "None" then
    UnitAuraList = {}
  end

  local aura
  local aura_count = 1
  local crowd_control_debuffs = {}
  local old_debuffs = UnitAuraList

--  if UnitIsUnit("target", unitid) then
--    print ("Filter: ", effect .. aura_filter, BLIZZARD_ShowAll)
--  end

  local show_aura, rank, canStealOrPurge, canApplyAura, isBossDebuff, isCastByPlayer
  for i = 1, 40 do
    -- Auras are evaluated by an external function - pre-filtering before the icon grid is populated
    UnitAuraList[aura_count] = UnitAuraList[aura_count] or {}
    aura = UnitAuraList[aura_count]

    -- BfA: Blizzard Code:local name, texture, count, debuffType, duration, expirationTime, caster, _, nameplateShowPersonal, spellId, _, _, _, nameplateShowAll = UnitAura(unit, i, filter);
    -- BfA: local name, icon, stacks, auraType, duration, expiration, caster, _, nameplateShowPersonal, spellid, _, _, _, nameplateShowAll = UnitAura(unitid, index, effect .. aura_filter)

    -- name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod

    aura.name, rank, aura.texture, aura.stacks, aura.type, aura.duration, aura.expiration, aura.caster,
      canStealOrPurge, aura.ShowPersonal, aura.spellid, canApplyAura, isBossDebuff, isCastByPlayer, aura.ShowAll
      = UnitAura(unitid, i, effect .. aura_filter)

--    if UnitIsUnit("target", unitid) then
--      print ("  Spell: ", aura.name)
--    end

    if not aura.name then break end

    aura.unit = unitid
    aura.effect = effect
    aura.ShowAll = aura.ShowAll or BLIZZARD_ShowAll --(unitReaction == AURA_TARGET_FRIENDLY and aura_filter == "|RAID")
    aura.CrowdControl = (show_cc and CROWD_CONTROL_SPELLS[aura.spellid])

--    if aura.CrowdControl or CROWD_CONTROL_SPELLS[aura.spellid] then
--      -- Crowd Control Spell
--      print ("CROWD CONTROL: ", aura.name, show_cc)
--    end

    -- Store Order/Priority
    if aura.CrowdControl then
      show_aura =  AuraFilterFunction(db.CrowdControl, aura)
    else
      show_aura =  AuraFilterFunction((aura.effect == "HARMFUL" and db.Debuffs) or db.Buffs, aura)
    end

    if show_aura then
      aura.color = GetColorForAura(aura)
      aura.priority = PRIORITY_FUNCTIONS[db.SortOrder](aura)

      aura_count = aura_count + 1
    end
  end

  -- Sort all auras
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

  -- Show auras
  local max_auras_no = aura_count -- min(aura_count, CONFIG_AuraLimit)
  if CONFIG_AuraLimit < max_auras_no then
    max_auras_no = CONFIG_AuraLimit
  end

  local aura_count_cc = 1
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
    aura_count_cc = 1
    local aura_frame_list_cc = frame:GetParent().CrowdControl.AuraFrames

    for index = index_start, index_end, index_step do
      local aura = UnitAuraList[index]

      if aura.spellid and aura.expiration then
        local aura_frame
        if aura.CrowdControl then
          aura_frame = aura_frame_list_cc[aura_count_cc]
          aura_count_cc = aura_count_cc + 1
        else
          aura_frame = aura_frame_list[aura_count]
          aura_count = aura_count + 1
        end


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
  aura_count_cc = aura_count_cc - 1

  frame.ActiveAuras = max_auras_no - aura_count_cc
  -- Clear extra slots
  for i = max_auras_no + 1, CONFIG_AuraLimit do
    aura_frame_list[i]:Hide()
  end

  if effect == "HARMFUL" then
    frame:GetParent().CrowdControl.ActiveAuras = aura_count_cc
    --print ("CC ActiveAuras: ", frame:GetParent().CrowdControl.ActiveAuras)

    for i = aura_count_cc + 1, CONFIG_AuraLimit do
      frame:GetParent().CrowdControl.AuraFrames[i]:Hide()
    end
  end
end

local function UpdatePositionAuraGrid(frame, y_offset)
  local db = TidyPlatesThreat.db.profile.AuraWidget

  local auras_no = frame.ActiveAuras
  if auras_no == 0 then
    frame:Hide()
  else
    if CONFIG_ModeBar then
      frame:SetPoint(ANCHOR_POINT_SETPOINT[db.anchor][2], frame:GetParent():GetParent(), ANCHOR_POINT_SETPOINT[db.anchor][1], db.x, db.y + y_offset)
      frame:SetHeight(ceil(frame.ActiveAuras / CONFIG_GridNoCols) * (CONFIG_AuraHeight + CONFIG_AuraWidgetOffset))
    else
      if db.CenterAuras then
        if auras_no > CONFIG_GridNoCols then
          auras_no = CONFIG_GridNoCols
        end

        frame:SetPoint(ANCHOR_POINT_SETPOINT[db.anchor][2], frame:GetParent():GetParent(), ANCHOR_POINT_SETPOINT[db.anchor][1], db.x + CONFIG_CenterAurasPositions[auras_no], db.y + y_offset)
        frame:SetHeight(ceil(frame.ActiveAuras / CONFIG_GridNoCols) * (CONFIG_AuraHeight + CONFIG_AuraWidgetOffset))
      else
        frame:SetPoint(ANCHOR_POINT_SETPOINT[db.anchor][2], frame:GetParent():GetParent(), ANCHOR_POINT_SETPOINT[db.anchor][1], db.x, db.y + y_offset)
        frame:SetHeight(ceil(frame.ActiveAuras / CONFIG_GridNoCols) * (CONFIG_AuraHeight + CONFIG_AuraWidgetOffset))
      end
    end

    frame:Show()
  end
end

local function UpdateIconGrid(widget_frame, unitid)
  local db = TidyPlatesThreat.db.profile.AuraWidget

  if db.ShowTargetOnly then
    if not UnitIsUnit("target", unitid) then
      widget_frame:Hide()
      return
    end

    CurrentTarget = widget_frame
  end

  local BLIZZARD_ShowAll = false

  --local aura_filter2 = (UnitReaction(unitid, "player") > 4 and AuraFilter.Friendly) or AuraFilter.Enemy

  local aura_filter_buffs, aura_filter_debuffs = "NONE", "NONE"
  local unit_is_friendly = UnitReaction(unitid, "player") > 4
  if unit_is_friendly then -- friendly or better
    if db.Debuffs.ShowFriendly or db.CrowdControl.ShowFriendly then
      aura_filter_debuffs = AuraFilter.Friendly.Debuffs
      BLIZZARD_ShowAll = (AuraFilter.Friendly.Debuffs == '|RAID')
    end
    if db.Buffs.ShowFriendly then
      aura_filter_buffs = AuraFilter.Friendly.Buffs
      BLIZZARD_ShowAll = (AuraFilter.Friendly.Buffs == '|RAID')
    end
  else
    -- aura_filter_debuffs = ((db.Debuffs.ShowEnemy or db.CrowdControl.ShowEnemy) and AuraFilter.Enemy.Debuffs) or "NONE"
    -- aura_filter_buffs = (db.Buffs.ShowEnemy and AuraFilter.Enemy.Buffs) or "NONE"
    if db.Debuffs.ShowEnemy or db.CrowdControl.ShowEnemy then
      aura_filter_debuffs = AuraFilter.Enemy.Debuffs
    end
    if db.Buffs.ShowEnemy then
      aura_filter_buffs = AuraFilter.Enemy.Buffs
    end
  end

  local show_CC = (unit_is_friendly and db.CrowdControl.ShowFriendly) or (not unit_is_friendly and db.CrowdControl.ShowEnemy)

  UpdateUnitAuras(widget_frame.Debuffs, unitid, "HARMFUL", aura_filter_debuffs, BLIZZARD_ShowAll, show_CC)
  UpdateUnitAuras(widget_frame.Buffs, unitid, "HELPFUL", aura_filter_buffs, BLIZZARD_ShowAll, false)

  --print ("CCs: ", widget_frame.CrowdControl.ActiveAuras)

  --print ("AurasWidget: #Debuffs: ", widget_frame.Debuffs.ActiveAuras)
  --print ("AurasWidget: #Buffs: ", widget_frame.Buffs.ActiveAuras)
  local buffs_active, debuffs_active, cc_active = widget_frame.Buffs.ActiveAuras > 0, widget_frame.Debuffs.ActiveAuras > 0, widget_frame.CrowdControl.ActiveAuras > 0

  if buffs_active or debuffs_active or cc_active then
    local frame_auras_one, frame_auras_two
    local auras_one_active, auras_two_active
    local scale_auras_one, scale_auras_two

    if unit_is_friendly then
--      if db.SwitchScaleByReaction then
--        scale_buffs, scale_debuffs = scale_debuffs, scale_buffs
--      end
--
--        -- Position the different aura frames so that they are stacked one above the other
--      y_offset = (db.y / scale_buffs) - db.y
--      UpdatePositionAuraGrid(widget_frame.Buffs, y_offset)
--
--      local height_buffs = (buffs_active and (widget_frame.Buffs:GetHeight() * scale_buffs)) or 0
--      y_offset = (height_buffs / scale_debuffs) + (db.y / scale_debuffs) - db.y
--      UpdatePositionAuraGrid(widget_frame.Debuffs, y_offset)
--
--      y_offset = ((debuffs_active and (widget_frame.Debuffs:GetHeight() * scale_debuffs / scale_cc)) or 0)
--      y_offset = y_offset + (height_buffs / scale_cc) + (db.y / scale_cc) - db.y
--      UpdatePositionAuraGrid(widget_frame.CrowdControl, y_offset)

      frame_auras_one, frame_auras_two = widget_frame.Buffs, widget_frame.Debuffs
      auras_one_active, auras_two_active = buffs_active, debuffs_active
      if db.SwitchScaleByReaction then
        scale_auras_one, scale_auras_two = db.Debuffs.Scale, db.Buffs.Scale
      else
        scale_auras_one, scale_auras_two = db.Buffs.Scale, db.Debuffs.Scale
      end

    else
--      -- Position the different aura frames so that they are stacked one above the other
--      y_offset = (db.y / scale_debuffs) - db.y
--      UpdatePositionAuraGrid(widget_frame.Debuffs, y_offset)
--
--      local height_debuffs = (debuffs_active and (widget_frame.Debuffs:GetHeight() * scale_debuffs)) or 0
--      y_offset = (height_debuffs / scale_buffs) + (db.y / scale_buffs) - db.y
--      UpdatePositionAuraGrid(widget_frame.Buffs, y_offset)
--      --print ("Buff Height: ", widget_frame.Buffs.ActiveAuras, widget_frame.Buffs:GetHeight())
--      -- print ("Buff Pos: ", y_offset)
--
--      y_offset = ((buffs_active and (widget_frame.Buffs:GetHeight() * scale_buffs / scale_cc)) or 0)
--      y_offset = y_offset + (height_debuffs / scale_cc) + (db.y / scale_cc) - db.y
--      UpdatePositionAuraGrid(widget_frame.CrowdControl, y_offset)
--      --print ("CC Height: ", widget_frame.CrowdControl.ActiveAuras, widget_frame.CrowdControl:GetHeight())
--      --print ("CC Pos: ", y_offset)

      frame_auras_one, frame_auras_two = widget_frame.Debuffs, widget_frame.Buffs
      auras_one_active, auras_two_active = debuffs_active, buffs_active
      scale_auras_one, scale_auras_two = db.Debuffs.Scale, db.Buffs.Scale
    end

    local scale_cc = db.CrowdControl.Scale

    -- Position the different aura frames so that they are stacked one above the other
    local y_offset = (db.y / scale_auras_one) - db.y
    UpdatePositionAuraGrid(frame_auras_one, y_offset)

    local height_auras_one = (auras_one_active and (frame_auras_one:GetHeight() * scale_auras_one)) or 0
    y_offset = (height_auras_one / scale_auras_two) + (db.y / scale_auras_two) - db.y
    UpdatePositionAuraGrid(frame_auras_two, y_offset)

    if show_CC then
      y_offset = ((auras_two_active and (frame_auras_two:GetHeight() * scale_auras_two / scale_cc)) or 0)
      y_offset = y_offset + (height_auras_one / scale_cc) + (db.y / scale_cc) - db.y
      UpdatePositionAuraGrid(widget_frame.CrowdControl, y_offset)
    else
      widget_frame.CrowdControl:Hide()
    end

--    local frame = widget_frame.Debuffs
--    if not frame.TestBackground then
--      frame.TestBackground = frame:CreateTexture(nil, "BACKGROUND")
--    end
--    frame.TestBackground:SetAllPoints(frame)
--    frame.TestBackground:SetTexture(ThreatPlates.Media:Fetch('statusbar', "Smooth"))
--    frame.TestBackground:SetVertexColor(0,0,0,1)
--    frame = widget_frame.Buffs
--    if not frame.TestBackground then
--      frame.TestBackground = frame:CreateTexture(nil, "BACKGROUND")
--    end
--    frame.TestBackground:SetAllPoints(frame)
--    frame.TestBackground:SetTexture(ThreatPlates.Media:Fetch('statusbar', "Smooth"))
--    frame.TestBackground:SetVertexColor(0,0,0,1)
--    frame = widget_frame.CrowdControl
--    if not frame.TestBackground then
--      frame.TestBackground = frame:CreateTexture(nil, "BACKGROUND")
--    end
--    frame.TestBackground:SetAllPoints(frame)
--    frame.TestBackground:SetTexture(ThreatPlates.Media:Fetch('statusbar', "Smooth"))
--    frame.TestBackground:SetVertexColor(0,0,0,1)

    widget_frame:Show()
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

--
--  db = TidyPlatesThreat.db.profile.AuraWidget
--  if  db.SwitchScaleByReaction and UnitReaction(frame.AuraInfo.unit, "player") > 4 then
--    if frame.AuraInfo.CrowdControl then
--      frame.SetScale(db.CrowdControl.Scale)
--    elseif frame.AuraInfo.effent == "HELPFUL" then
--      frame:SetScale(db.Debuffs.Scale)
--    else
--      frame:SetScale(db.Buffs.Scale)
--    end
--  else
--    if frame.AuraInfo.CrowdControl then
--      frame.SetScale(db.CrowdControl.Scale)
--    elseif frame.AuraInfo.effent == "HELPFUL" then
--      frame:SetScale(db.Buffs.Scale)
--    else
--      frame:SetScale(db.Debuffs.Scale)
--    end
--  end
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

local function CreateAuraGrid(frame)
  local db = TidyPlatesThreat.db.profile.AuraWidget

  local align_layout = GRID_LAYOUT[db.AlignmentH][db.AlignmentV]

  local aura_frame_list = frame.AuraFrames
  local pos_x, pos_y

  local aura_frame
  for i = 1, CONFIG_AuraLimit do
    aura_frame = aura_frame_list[i]
    if aura_frame == nil then
      aura_frame = CreateAuraFrame(frame)
      aura_frame_list[i] = aura_frame
    else
      if CONFIG_ModeBar then
        if not aura_frame.Statusbar then
          aura_frame:Hide()
          aura_frame = CreateAuraFrame(frame)
          aura_frame_list[i] = aura_frame
        end
      else
        if not aura_frame.Border then
          aura_frame:Hide()
          aura_frame = CreateAuraFrame(frame)
          aura_frame_list[i] = aura_frame
        end
      end
    end

    pos_x = (i - 1) % CONFIG_GridNoCols
    pos_x = (pos_x * CONFIG_AuraWidth + CONFIG_AuraWidgetOffset) * align_layout[2]

    pos_y = floor((i - 1) / CONFIG_GridNoCols)
    pos_y = (pos_y * CONFIG_AuraHeight + CONFIG_AuraWidgetOffset) * align_layout[3]

    -- anchor the frame
    aura_frame:ClearAllPoints()
    aura_frame:SetPoint(align_layout[1], frame, pos_x, pos_y)

    UpdateAuraFrame(aura_frame)
  end

  -- if number of auras to show was decreased, remove any overflow aura frames
  for i = #aura_frame_list, CONFIG_AuraLimit + 1, -1 do
    aura_frame_list[i]:Hide()
    aura_frame_list[i] = nil
  end

  frame:SetSize(CONFIG_AuraWidgetWidth, CONFIG_AuraWidgetHeight)
end

-- Initialize the aura grid layout, don't update auras themselves as not unitid know at this point
local function CreateAuraWidgetLayout(widget_frame)
  CreateAuraGrid(widget_frame.Buffs)
  CreateAuraGrid(widget_frame.Debuffs)
  CreateAuraGrid(widget_frame.CrowdControl)

  local db = TidyPlatesThreat.db.profile.AuraWidget

  if db.SwitchScaleByReaction and UnitReaction(widget_frame.unit.unitid, "player") > 4 then
    widget_frame.Buffs:SetScale(db.Debuffs.Scale)
    widget_frame.Debuffs:SetScale(db.Buffs.Scale)
  else
    widget_frame.Buffs:SetScale(db.Buffs.Scale)
    widget_frame.Debuffs:SetScale(db.Debuffs.Scale)
  end
  widget_frame.CrowdControl:SetScale(db.CrowdControl.Scale)

  widget_frame.Debuffs:SetPoint(ThreatPlates.ANCHOR_POINT_SETPOINT[db.anchor][2], widget_frame:GetParent(), ThreatPlates.ANCHOR_POINT_SETPOINT[db.anchor][1], db.x, db.y)
  widget_frame.Buffs:SetPoint(ThreatPlates.ANCHOR_POINT_SETPOINT[db.anchor][2], widget_frame:GetParent(), ThreatPlates.ANCHOR_POINT_SETPOINT[db.anchor][1], db.x, db.y)
  --widget_frame.Stun:SetPoint("BOTTOM", widget_frame.Buffs, "TOP", 0, CONFIG_GridSpacingRows)

  if TidyPlatesThreat.db.profile.AuraWidget.FrameOrder == "HEALTHBAR_AURAS" then
    widget_frame:SetFrameLevel(widget_frame:GetFrameLevel() + 3)
  else
    widget_frame:SetFrameLevel(widget_frame:GetFrameLevel() + 9)
  end
end


local function ParseFilter(aura_type, db)
  local filter = {}
  local only_player_auras = true

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
      only_player_auras = false
    elseif value:sub(1, 3) == "My " then
      modifier = "My"
      spell = value:match("^My%s*(.-)$")
    elseif value:sub(1, 4) == "Not " then
      modifier = "Not"
      spell = value:match("^Not%s*(.-)$")
      only_player_auras = false
    else
      modifier = true
      spell = value
    end

    -- separete filter by name and ID for more efficient aura filtering
    local spell_no = tonumber(spell)
    if spell_no then
      filter[spell_no] = modifier
    elseif spell ~= '' then
      filter[spell] = modifier
    end
  end

  if aura_type == "Buffs" then
    if db.FilterMode == "BLIZZARD" then
      -- Blizzard default is
      --   UnitReaction <=4: filter = "HARMFUL|INCLUDE_NAME_PLATE_ONLY"
      --   UnitReaction >4: filter = "NONE" or filter = "HARMFUL|RAID" (with showAll) if nameplateShowDebuffsOnFriendly == true (for 7.3)
      AuraFilter.Enemy.Buffs = "|INCLUDE_NAME_PLATE_ONLY"
      AuraFilter.Friendly.Buffs = '|RAID'


  --    AURA_FILTER_ENEMY = "|INCLUDE_NAME_PLATE_ONLY"
  --    AURA_FILTER_FRIENDLY = (db.ShowDebuffsOnFriendly and '|RAID') or "NONE"
    elseif string.find(db.FilterMode, "Mine") and only_player_auras then
      AuraFilter.Enemy.Buffs = "|PLAYER"
      AuraFilter.Friendly.Buffs = "|PLAYER"

  --    AURA_FILTER_ENEMY = "|PLAYER"
  --    AURA_FILTER_FRIENDLY = "|PLAYER"
    else
      AuraFilter.Enemy.Buffs = ""
      AuraFilter.Friendly.Buffs = ""

  --    AURA_FILTER_ENEMY = ""
  --    AURA_FILTER_FRIENDLY = ""
    end
  elseif aura_type == "Debuffs" then
    if db.FilterMode == "BLIZZARD" then
      AuraFilter.Enemy.Debuffs = "|INCLUDE_NAME_PLATE_ONLY"
      AuraFilter.Friendly.Debuffs = (db.ShowDebuffsOnFriendly and '|RAID') or "NONE"
    elseif string.find(db.FilterMode, "Mine") and only_player_auras then
      AuraFilter.Enemy.Debuffs = "|PLAYER"
      AuraFilter.Friendly.Debuffs = "|PLAYER"
    else
      AuraFilter.Enemy.Debuffs = "NONE"
      AuraFilter.Friendly.Debuffs = "NONE"
    end
  else -- aura_type == "CrowdControl"
    if db.FilterMode == "BLIZZARD" then
      -- Do not override more generall debuff filter
      if AuraFilter.Enemy.Debuffs == "|PLAYER" then
        -- Switch to most general filter
        AuraFilter.Enemy.Debuffs = ""
        AuraFilter.Friendly.Debuffs = ""
      end
    elseif string.find(db.FilterMode, "Mine") and only_player_auras then
      -- Do not override more generall debuff filter
      if AuraFilter.Enemy.Debuffs == "|INCLUDE_NAME_PLATE_ONLY" then
        -- Switch to most general filter
        AuraFilter.Enemy.Debuffs = ""
        AuraFilter.Friendly.Debuffs = ""
      end
    else
      AuraFilter.Enemy.Debuffs = ""
      AuraFilter.Friendly.Debuffs = ""
    end
  end
  return filter
end

function Widget:ParseSpellFilters()
  local db = TidyPlatesThreat.db.profile.AuraWidget

  AuraFilterBuffs = ParseFilter("Buffs", db.Buffs)
  AuraFilterDebuffs = ParseFilter("Debuffs", db.Debuffs)
  AuraFilterCrowdControl = ParseFilter("CrowdControl", db.CrowdControl)

--  print ("Debuff FilterMode: ", db.Debuffs.FilterMode)
--  print ("Debuff Filter: ", db.Debuffs.FilterBySpell)
--
--  print ("Debuffs - Friendly: ", AuraFilter.Friendly.Debuffs)
--  print ("Debuffs - Enemy: ", AuraFilter.Enemy.Debuffs)
--  print ("Debuffs - Filter: ")
--  for k, v in pairs(AuraFilterDebuffs) do
--    print ("  ", k, "=", v)
--  end
end

-- Load settings from the configuration which are shared across all aura widgets
-- used (for each widget) in UpdateWidgetConfig
function Widget:UpdateSettings()
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
end

local function UnitAuraEventHandler(widget_frame, event, unitid)
  --print ("AurasWidget: UNIT_AURA: ", event, unitid)
--  if unitid ~= widget_frame.unit.unitid then
--    print ("AurasWidget: UNIT_AURA for", unitid)
--    print ("AurasWidget: Plate Active:", Addon.PlatesByUnit[unitid].Active)
--    print ("AurasWidget: Plate Unit:", Addon.PlatesByUnit[unitid].TPFrame.unit.unitid)
--    print ("AurasWidget: Plate WidgetFrame:", Addon.PlatesByUnit[unitid].TPFrame.widgets.Auras, Addon.PlatesByUnit[unitid].TPFrame.widgets.Auras.Active, Addon.PlatesByUnit[unitid].TPFrame.widgets.Auras == widget_frame)
--    print ("Unit:")
--    print ("Unit Name:", UnitName(unitid))
--    print ("Unit is Player:", UnitIsPlayer(unitid))
--    return
--  end

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
  widget_frame:SetSize(10, 10)
  widget_frame:SetPoint("CENTER", tp_frame, "CENTER")

  widget_frame.Debuffs = CreateFrame("Frame", nil, widget_frame)
  widget_frame.Debuffs.AuraFrames = {}
  widget_frame.Debuffs.ActiveAuras = 0

  widget_frame.Buffs = CreateFrame("Frame", nil, widget_frame)
  widget_frame.Buffs.AuraFrames = {}
  widget_frame.Buffs.ActiveAuras = 0

  widget_frame.CrowdControl = CreateFrame("Frame", nil, widget_frame)
  widget_frame.CrowdControl.AuraFrames = {}
  widget_frame.CrowdControl.ActiveAuras = 0

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
  -- LOSS_OF_CONTROL_ADDED
  -- LOSS_OF_CONTROL_UPDATE
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