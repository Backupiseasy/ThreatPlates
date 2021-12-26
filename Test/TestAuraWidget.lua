local units = {}

---------------------------------------------------------------------------------------------------
-- Prepare addon test environment
---------------------------------------------------------------------------------------------------

local RGB = function(red, green, blue, alpha)
  local color = { r = red/255, g = green/255, b = blue/255 }
  if alpha then color.a = alpha end
  return color
end

local TidyPlatesThreat = {
  db = {
    profile = {
      AuraWidget = {
        ON = false,	x = 0, y = 5, scale = 1,	anchor = "TOP",
        ShowEnemy = true,
        ShowFriendly = true,
        FilterMode = "all",
        FilterByType = {
          [1] = true,
          [2] = true,
          [3] = true,
          [4] = true,
          [5] = true,
          [6] = true
        },
        FilterBySpell = {},
        ShowTargetOnly = false,
        ShowCooldownSpiral = false,
        ShowStackCount = true,
        ShowAuraType = true,
        DefaultBuffColor = RGB(102, 0, 51, 1),
        DefaultDebuffColor = 	RGB(204, 0, 0, 1), --RGB(255, 0, 0, 1), -- DebuffTypeColor["none"]	= { r = 0.80, g = 0, b = 0 };
        SortOrder = "AtoZ",
        SortReverse = false,
        AlignmentH = "LEFT",
        AlignmentV = "BOTTOM",
        ModeIcon = {
          Columns = 5,
          Rows = 3,
          ColumnSpacing = 5,
          RowSpacing = 8,
          Style = "square",
        },
        ModeBar = {
          Enabled = false,
          BarHeight = 14,
          BarWidth = 100,
          BarSpacing = 2,
          MaxBars = 10,
          Texture = "Aluminium",
          Font = "Arial Narrow",
          FontSize = 10,
          FontColor = RGB(255, 255, 255),
          LabelTextIndent = 4,
          TimeTextIndent = 4,
          BackgroundTexture = "Blizzard",
          BackgroundColor = RGB(0, 0, 0, 0.3),
          BackgroundBorder = "Plain White", --"Blizzard Tooltip",
          BackgroundBorderEdgeSize = 2,
          BackgroundBorderInset = -4,
          BackgroundBorderColor = RGB(0, 0, 0, 0.3),
          ShowIcon = true,
          IconSpacing = 2,
          IconAlignmentLeft = true,
        },
      }
    }
  }
}

local Filter_ByAuraList =
  {}
--{
--  "Infizierte Wunden", -- [1]
--  "Offene Wunden", -- [2]
--  "Ashamanes Zerfetzen", -- [3]
--  "Ashamanes Raserei", -- [4]
--  "Blutige Pfoten", -- [5]
--  "Arroganz", -- [6]
--  "Brutaler Schwinger", -- [7]
--}

---------------------------------------------------------------------------------------------------
-- Necessary addon functions
---------------------------------------------------------------------------------------------------

local function DEBUG_PRINT_TABLE(data)
  local print_r_cache={}
  local function sub_print_r(data,indent)
    if (print_r_cache[tostring(data)]) then
      print (indent.."*"..tostring(data))
    else
      print_r_cache[tostring(data)]=true
      if (type(data)=="table") then
        for pos,val in pairs(data) do
          if (type(val)=="table") then
            print (indent.."["..pos.."] => "..tostring(data).." {")
            sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
            print (indent..string.rep(" ",string.len(pos)+6).."}")
          elseif (type(val)=="string") then
            print (indent.."["..pos..'] => "'..val..'"')
          else
            print (indent.."["..pos.."] => "..tostring(val))
          end
        end
      else
        print (indent..tostring(data))
      end
    end
  end
  if (type(data)=="table") then
    print (tostring(data).." {")
    sub_print_r(data,"  ")
    print ("}")
  else
    sub_print_r(data,"  ")
  end
end

local function DEBUG_AURA_LIST(data)
  local res = ""
  for pos,val in pairs(data) do
    local a = data[pos]
    if not a then
      res = res .. " nil"
    elseif not a.priority then
      res = res .. " nil(" .. a.name .. ")"
    else
      res = res .. a.name
    end
    if pos ~= #data then
      res = res .. " - "
    end
  end
  print ("Aura List = [ " .. res .. " ]")
end

---------------------------------------------------------------------------------------------------
-- WoW functions
---------------------------------------------------------------------------------------------------

local function min(a, b)
  return math.min(a,b)
end

local function sort(t, f)
  return table.sort(t, f)
end

local function UnitIsFriend(unit1, unit2)
  if unit2:match("^Player-") then
    return true
  else
    return false
  end
end

local function UnitAura(unitid, index, filter)
  local target_unit = units[unitid]

  if target_unit then
    if filter:match("|PLAYER") then
      filter = filter .. "_PLAYER"
    end
    local aura = target_unit[filter][index]
    --Addon.Debug:PrintTable(target_unit)
    if aura then
      return aura.name, aura.rank, aura.icon, aura.stacks, aura.auraType, aura.duration, aura.expiration, aura.caster, aura.isStealable , aura.nameplateShowPersonal , aura.spellid
    end
  end

  return nil
end

local function GetTime()
  return os.time()
end

-- Units to test: Aura Widget

local AURA_TARGET_HOSTILE = 1
local AURA_TARGET_FRIENDLY = 2
local AURA_TYPE = { Buff = 1, Curse = 2, Disease = 3, Magic = 4, Poison = 5, Debuff = 6, }
local CONFIG_AURA_LIMIT = 10

local UnitAuraList = {}

DebuffTypeColor = { };
DebuffTypeColor["none"]	= { r = 0.80, g = 0, b = 0 };
DebuffTypeColor["Magic"]	= { r = 0.20, g = 0.60, b = 1.00 };
DebuffTypeColor["Curse"]	= { r = 0.60, g = 0.00, b = 1.00 };
DebuffTypeColor["Disease"]	= { r = 0.60, g = 0.40, b = 0 };
DebuffTypeColor["Poison"]	= { r = 0.00, g = 0.60, b = 0 };
DebuffTypeColor[""]	= DebuffTypeColor["none"];

local function UpdateAuraFrame(aura_frame)
  return
end

local function PolledHideIn(aura_frame)
  return
end

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

  local show_aura, color, priority = false, nil, nil
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

  if show_aura then
    color = GetColorForAura(aura)

    priority = aura.expiration - aura.duration

    if db.SortOrder == "AtoZ" then
      priority = aura.name
    elseif db.SortOrder == "TimeLeft" then
      priority = aura.expiration - GetTime()
    elseif db.SortOrder == "Duration" then
      priority = aura.duration
    end
  end

  return show_aura, priority, color
end

local function AuraSortFunction(a, b)

  local order
  -- handling invalid entries in the aura array (necessary to avoid memory extensive array creation)
  if a == nil or (a.priority == nil) then
    order = false
  elseif b == nil or (b.priority == nil) then
    order = true
  end

  if order ~= nil then return order end

  local db = TidyPlatesThreat.db.profile.AuraWidget
  if db.SortOrder == "AtoZ" then
    order = a.priority < b.priority
  else
    --  if a.duration == 0 and b.duration == 0 then
    --    order = false
    if a.duration == 0 then
      order = false
    elseif b.duration == 0 then
      order = true
    else
      order = a.priority < b.priority
    end
  end

  if db.SortReverse then
    order = not order
  end

  return order
end

local function AuraSortFunctionSimpleAtoZ(a, b)
  local db = TidyPlatesThreat.db.profile.AuraWidget

  if db.SortReverse then
    return a.priority > b.priority
  else
    return a.priority < b.priority
  end
end

local function AuraSortFunctionSimpleNum(a, b)
  local order

  if a.duration == 0 then
    order = false
  elseif b.duration == 0 then
    order = true
  else
    order = a.priority < b.priority
  end

  local db = TidyPlatesThreat.db.profile.AuraWidget
  if db.SortReverse then
    order = not order
  end

  return order
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

local function UpdateIconGrid_NoSorting(frame, unitid)
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
--    --ThreatPlates.DEBUG_AURA_LIST(UnitAuraList)
--    local sort_order = TidyPlatesThreat.db.profile.AuraWidget.SortOrder
--    if sort_order ~= "None" then
--      if sort_order == "AtoZ" then
--        sort(UnitAuraList, AuraSortFunctionAtoZ)
--      else
--        sort(UnitAuraList, AuraSortFunctionNum)
--      end
--    end

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

local function UpdateIconGrid_831(frame, unitid)
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

--  DEBUG_AURA_LIST(UnitAuraList)

  -- invalidate all entries after storedAuraCount
  for i = aura_count + 1, #UnitAuraList do
    UnitAuraList[i].priority = nil
  end

  -- Display Auras
  ------------------------------------------------------------------------------------------------------
  local aura_frame_list = frame.AuraFrames
  local max_auras_no = min(aura_count, CONFIG_AURA_LIMIT)

  if aura_count > 0 then
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

local function UpdateIconGrid_NoArrayCreation_WithSort(frame, unitid)
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

  local UnitAuraList2 = {}

  local auraIndex = 0
  repeat
    auraIndex = auraIndex + 1
    -- Example: Gnaw , false, icon, 0 stacks, nil type, duration 1, expiration 8850.436, caster pet, false, false, 91800
    local name, _, icon, stacks, auraType, duration, expiration, caster, _, _, spellid = UnitAura(unitid, auraIndex, auraFilter)		-- UnitaAura

    -- Auras are evaluated by an external function
    -- Pre-filtering before the icon grid is populated
    if name then
      UnitAuraList2[aura_count] = UnitAuraList2[aura_count] or {}
      aura = UnitAuraList2[aura_count]

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

  -- Display Auras
  ------------------------------------------------------------------------------------------------------
  local aura_frame_list = frame.AuraFrames
  local max_auras_no = min(aura_count, CONFIG_AURA_LIMIT)

  if aura_count > 0 then
    --ThreatPlates.DEBUG_AURA_LIST(UnitAuraList2)
    sort(UnitAuraList2, AuraSortFunction)

    --local aura_info_list = frame.AuraInfos
    for index = 1, max_auras_no do
      local aura = UnitAuraList2[index]

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

local function GetUnitAuras(UnitAuraList, unitReaction, unitid, filter)
  local start_index = #UnitAuraList
  local aura, aura_filter

  local db = TidyPlatesThreat.db.profile.AuraWidget
  local mode = db.FilterMode
  if mode == "whitelistMine" or mode == "blacklistMine" or mode == "allMine" then
    aura_filter = filter .. "|PLAYER"
  else
    aura_filter = filter
  end

  local index = 1
  repeat
    -- Example: Gnaw , false, icon, 0 stacks, nil type, duration 1, expiration 8850.436, caster pet, false, false, 91800
    local name, _, icon, stacks, auraType, duration, expiration, caster, _, _, spellid = UnitAura(unitid, index, aura_filter)
    -- Auras are evaluated by an external function
    -- Pre-filtering before the icon grid is populated
    if name then
      aura = {}
      aura.name = name
      aura.texture = icon
      aura.stacks = stacks
      aura.type = auraType
      aura.effect = filter
      aura.duration = duration
      aura.reaction = unitReaction
      aura.expiration = expiration
      aura.caster = caster
      aura.spellid = spellid
      aura.unit = unitid 		-- unitid of the plate

      local show, priority, color = AuraFilterFunction(aura)
      if show then
        aura.priority = priority
        aura.color = color
        UnitAuraList[#UnitAuraList + 1] = aura
      end

      index = index + 1
    else
      break
    end
  until false
end

local function AuraSortFunctionAtoZ_Baseline(a, b)
  local db = TidyPlatesThreat.db.profile.AuraWidget

  if db.SortReverse then
    return a.priority > b.priority
  else
    return a.priority < b.priority
  end
end

local function AuraSortFunctionNum_Baseline(a, b)
  local order

  if a.duration == 0 then
    order = false
  elseif b.duration == 0 then
    order = true
  else
    order = a.priority < b.priority
  end

  local db = TidyPlatesThreat.db.profile.AuraWidget
  if db.SortReverse then
    order = not order
  end

  return order
end

local function UpdateIconGrid_Baseline(frame, unitid)
  if not unitid then return end

  local unitReaction
  if UnitIsFriend("player", unitid) then
    unitReaction = AURA_TARGET_FRIENDLY
  else
    unitReaction = AURA_TARGET_HOSTILE
  end

  -- Cache displayable auras
  ------------------------------------------------------------------------------------------------------
  -- This block will go through the auras on the unit and make a list of those that should
  -- be displayed, listed by priority.
  local searchedDebuffs, searchedBuffs = false, false
  local auraFilter = "HARMFUL"

  --  GetUnitAuras(UnitAuraList2, unitReaction, unitid, "HARMFUL")
  --  GetUnitAuras(UnitAuraList2, unitReaction, unitid, "HELPFUL")

  local sort_order = TidyPlatesThreat.db.profile.AuraWidget.SortOrder
  if sort_order ~= "None" then
    UnitAuraList = {}
  end

  local aura_count = 1
  local index = 0
  repeat
    index = index + 1
    -- Example: Gnaw , false, icon, 0 stacks, nil type, duration 1, expiration 8850.436, caster pet, false, false, 91800
    local name, _, icon, stacks, auraType, duration, expiration, caster, _, _, spellid = UnitAura(unitid, index, auraFilter)		-- UnitaAura

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
      aura.effect = auraFilter
      aura.duration = duration
      aura.reaction = unitReaction
      aura.expiration = expiration
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
      if auraFilter == "HARMFUL" then
        searchedDebuffs = true
        auraFilter = "HELPFUL"
        index = 0
      else
        searchedBuffs = true
      end
    end

  until (searchedDebuffs and searchedBuffs)

  if sort_order == "None" then
    -- invalidate all entries after storedAuraCount
    for i = aura_count, #UnitAuraList do
      UnitAuraList[i].priority = nil
    end
  else
    UnitAuraList[aura_count] = nil
    --    for i = aura_count + 1, #UnitAuraList do
    --      UnitAuraList[i] = nil
    --    end
  end

  aura_count = aura_count - 1

  -- Display Auras
  local aura_frame_list = frame.AuraFrames
  local max_auras_no = min(aura_count, CONFIG_AURA_LIMIT)

  if aura_count > 0 then
    if sort_order ~= "None" then
      --ThreatPlates.DEBUG_AURA_LIST(UnitAuraList)
      if sort_order == "AtoZ" then
        sort(UnitAuraList, AuraSortFunctionAtoZ_Baseline)
      else
        sort(UnitAuraList, AuraSortFunctionNum_Baseline)
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

local function AuraSortFunctionAtoZ_Testing(a, b)
  return a.priority < b.priority
end

local function AuraSortFunctionNum_Testing(a, b)
  local order

  if a.duration == 0 then
    order = false
  elseif b.duration == 0 then
    order = true
  else
    order = a.priority < b.priority
  end

  return order
end
local function UpdateIconGrid_Testing(frame, unitid)
  if not unitid then return end

  local unitReaction
  if UnitIsFriend("player", unitid) then
    unitReaction = AURA_TARGET_FRIENDLY
  else
    unitReaction = AURA_TARGET_HOSTILE
  end

  -- Cache displayable auras
  ------------------------------------------------------------------------------------------------------
  -- This block will go through the auras on the unit and make a list of those that should
  -- be displayed, listed by priority.
  local searchedDebuffs, searchedBuffs = false, false
  local auraFilter = "HARMFUL"

  --  GetUnitAuras(UnitAuraList2, unitReaction, unitid, "HARMFUL")
  --  GetUnitAuras(UnitAuraList2, unitReaction, unitid, "HELPFUL")

  local sort_order = TidyPlatesThreat.db.profile.AuraWidget.SortOrder
  if sort_order ~= "None" then
    UnitAuraList = {}
  end

  local aura
  local aura_count = 1
  local index = 0
  repeat
    index = index + 1
    -- Example: Gnaw , false, icon, 0 stacks, nil type, duration 1, expiration 8850.436, caster pet, false, false, 91800
    local name, _, icon, stacks, auraType, duration, expiration, caster, _, _, spellid = UnitAura(unitid, index, auraFilter)		-- UnitaAura

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
      aura.effect = auraFilter
      aura.duration = duration
      aura.reaction = unitReaction
      aura.expiration = expiration
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
      if auraFilter == "HARMFUL" then
        searchedDebuffs = true
        auraFilter = "HELPFUL"
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
  local aura_frame_list = frame.AuraFrames
  local max_auras_no = min(aura_count, CONFIG_AURA_LIMIT)

  if aura_count > 0 then
    if sort_order ~= "None" then
      --ThreatPlates.DEBUG_AURA_LIST(UnitAuraList)
      if sort_order == "AtoZ" then
        sort(UnitAuraList, AuraSortFunctionAtoZ_Testing)
        --sort(UnitAuraList, AuraSortFunctionAtoZ_Baseline)
      else
        sort(UnitAuraList, AuraSortFunctionNum_Testing)
        --sort(UnitAuraList, AuraSortFunctionNum_Baseline)
      end
    end

    --local aura_info_list = frame.AuraInfos
    local index_start, index_end, index_step
    if TidyPlatesThreat.db.profile.AuraWidget.SortReverse then
      index_start, index_end, index_step = max_auras_no, 1, -1
    else
      index_start, index_end, index_step = 1, max_auras_no, 1
    end

    for index = index_start, index_end, index_step do
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

-- measure runtime for fixed numer of funtion calls


local frame = {}
frame.AuraFrames = {}
for c = 1, CONFIG_AURA_LIMIT do
  frame.AuraFrames[c] = {}
  frame.AuraFrames[c].AuraInfo = {}
end

---------------------------------------------------------------------------------------------------
-- Measure the runtime of different implementations
---------------------------------------------------------------------------------------------------
local AURA_WIDGET_TEST_DATA = "AuraWidget-Skorpyron.data"
local TEST_FUNCTIONS = {
--  { UpdateIconGrid_NoSorting , "UpdateIconGrid_NoSorting", },
--  { UpdateIconGrid_831 , "UpdateIconGrid_831", },
--  { UpdateIconGrid_NoArrayCreation_WithSort , "UpdateIconGrid_NoArrayCreation_WithSort", },
  { UpdateIconGrid_Baseline , "UpdateIconGrid_Baseline", },
  { UpdateIconGrid_Testing , "UpdateIconGrid_Testing", },
}
local TEST_FILTERS = { "allMine", } -- ,"allMine", } --"whitelist" }
local TEST_SORTING = { "None", "AtoZ" } -- , "AtoZ", "None" } --, "Duration", "None"}
local UPDATE_INTERVAL = 100
local NO_ITERATIONS = 10

local function AddToAuraList(list, aura)
  local aura_index
  for i, a in ipairs(list) do
    if a.sourceGUID == aura.sourceGUID and a.spellId == aura.spellid then
      -- overwrite aura
      aura_index = i
      break
    end
  end
  if not aura_index then
    aura_index = #list + 1
    list[aura_index] = {}
  end

  list[aura_index] = aura
end

local function RemoveFromAuraList(list, sourceGUID, spellId)
  if list then
    for i = #list, 1, -1 do
      local a = list[i]
      if list[i].sourceGUID == sourceGUID and list[i].spellId == spellId then
        table.remove(list, i)
      end
    end
  end
end

local function DoTestRun(test_func)
  local testrun_time = 0
  local last_update
  for line in io.lines(AURA_WIDGET_TEST_DATA) do
    -- parse time
    local day, time_h, time_m, time_s, time_ms, action, remaining = line:match("^(%d+%/%d+) (%d+):(%d+):(%d+)%.(%d+)  ([A-Z_]+),(.*)$") --

    if action == "SPELL_AURA_APPLIED" then
      -- 11/9 22:24:28.707  SPELL_AURA_APPLIED,Player-581-043D8C8E,"Salassion-Blackrock",0x40511,0x0,Creature-0-1463-1648-27373-114360-00002393A3,"Hyrja",0x10a48,0x0,6795,"Knurren",0x1,DEBUFF
      local sourceGUID, sourceName, sourceFlags, x4, destGUID, destName, detFlags, x8, spellId, spellName, spellSchool, auraType = remaining:match('([^,]+),(\"?.+\"?),([^,]+),([^,]+),([^,]+),(\".+\"),([^,]+),([^,]+),([^,]+),(\".+\"),([^,]+),([^,]+)')

      if not sourceGUID or not sourceName or not sourceName or not sourceFlags or not x4 or not destGUID or not destName or not detFlags or not x8 or not spellId or not spellName or not spellSchool or not auraType then
        print (remaining)
        print (sourceGUID, sourceName, sourceFlags, x4, destGUID, destName, detFlags, x8, spellId, spellName, spellSchool, auraType)
      end

      local target_unit = units[destGUID]

      if not target_unit then
        units[destGUID] = {}
        target_unit = units[destGUID]
        target_unit.HELPFUL = {}
        target_unit.HARMFUL = {}
        target_unit.HELPFUL_PLAYER = {}
        target_unit.HARMFUL_PLAYER = {}
      end

      local aura = {}
      aura.name = spellName
      aura.rank = 1
      aura.icon = [[C:\Games\World of Warcraft\Interface\AddOns\TidyPlates_ThreatPlates\Artwork\Aluminium]]
      aura.stacks = 1
      aura.auraType = auraType
      aura.duration = math.random(20)
      aura.expiration = os.time() + aura.duration
      if sourceName == "\"Salassion-Blackrock\"" then
        sourceName = "player"
      end
      aura.caster = sourceName
      aura.isStealable = false
      aura.nameplateShowPersonal = false
      aura.spellid = spellId
      aura.sourceGUID = sourceGUID

      if auraType == "BUFF" then
        AddToAuraList(target_unit.HELPFUL, aura)
        if sourceName == "player" then
          AddToAuraList(target_unit.HELPFUL_PLAYER, aura)
        end
      elseif auraType == "DEBUFF" then
        AddToAuraList(target_unit.HARMFUL, aura)
        if sourceName == "player" then
          AddToAuraList(target_unit.HARMFUL_PLAYER, aura)
        end
      else
        print ("Unknown aura type: ", auraType)
      end
      --      if destName == "\"Salassion-Blackrock\"" then
      --        DEBUG_PRINT_TABLE(target_unit)
      --      end
    elseif action == "SPELL_AURA_REMOVED" then
      -- 11/9 22:24:28.403  SPELL_AURA_REMOVED,Player-581-0450EA8A,"Tuønetar-Blackrock",0x514,0x0,Player-581-043D8C8E,"Salassion-Blackrock",0x40511,0x0,57934,"Schurkenhandel",0x1,BUFF
      local sourceGUID, sourceName, sourceFlags, x4, destGUID, destName, detFlags, x8, spellId, spellName, spellSchool, auraType = remaining:match("([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")
      --print ("Remove Aura:", spellName, "on", destName, "from", sourceName)

      local target_unit = units[destGUID]
      if target_unit then
        RemoveFromAuraList(target_unit.HELPFUL, sourceGUID, spellId)
        RemoveFromAuraList(target_unit.HELPFUL_PLAYER, sourceGUID, spellId)
        RemoveFromAuraList(target_unit.HARMFUL, sourceGUID, spellId)
        RemoveFromAuraList(target_unit.HARMFUL_PLAYER, sourceGUID, spellId)
      end
    end

    local current_time = (time_h * 60 * 60 * 1000) + (time_m * 60 * 1000) + (time_s * 1000) + time_ms
    if not last_update or last_update + UPDATE_INTERVAL < current_time then
      last_update = current_time
      --print ("Updating ...", current_time, time_h..":"..time_m..":"..time_s.."."..time_ms)

      for guid, unit in pairs(units) do
        local start_time = os.clock()
        test_func(frame, guid)
        local end_time = os.clock()
        testrun_time = testrun_time + (end_time - start_time)
      end
    end
  end

  return testrun_time
end


local measure = {}
for func = 1, #TEST_FUNCTIONS do
  measure[func] = {}

  for filter_mode = 1, #TEST_FILTERS do
    measure[func][filter_mode] = {}

    TidyPlatesThreat.db.profile.AuraWidget.FilterMode = TEST_FILTERS[filter_mode]

    for sort_mode = 1, #TEST_SORTING do
      measure[func][filter_mode][sort_mode] = {}

      TidyPlatesThreat.db.profile.AuraWidget.SortOrder = TEST_SORTING[sort_mode]

      for iteration = 1, NO_ITERATIONS do
        units = {}
        UnitAuraList = {}
        local testrun_time = DoTestRun(TEST_FUNCTIONS[func][1])

        measure[func][filter_mode][sort_mode][iteration] = testrun_time
      end
    end
  end
end

-- Print results
io.write("Test;Filter;Sorting;")
for iteration = 1, NO_ITERATIONS do
  io.write("Run "..iteration..";")
end
io.write("Average\n")

for func = 1, #TEST_FUNCTIONS do

  for filter_mode = 1, #TEST_FILTERS do

    for sort_mode = 1, #TEST_SORTING do
      local measure_sum = 0
      io.write(TEST_FUNCTIONS[func][2].." ("..TEST_FILTERS[filter_mode].." / "..TEST_SORTING[sort_mode]..")"..";")
      io.write(TEST_FILTERS[filter_mode]..";"..TEST_SORTING[sort_mode]..";")

      for iteration = 1, NO_ITERATIONS do
        io.write(string.gsub(string.format("%.3f", measure[func][filter_mode][sort_mode][iteration]), "%.", ",")..";")
        measure_sum = measure_sum + measure[func][filter_mode][sort_mode][iteration]
      end
      io.write(string.gsub(string.format("%.3f", measure_sum/#measure[func][filter_mode][sort_mode]), "%.", ","))
      io.write("\n")
    end
  end
end
