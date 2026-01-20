---------------------------------------------------------------------------------------------------
-- Auras Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

if not Addon.ExpansionIsAtLeastMidnight then return end

local Widget = Addon.Widgets:NewWidget("Auras")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local GetTime = GetTime
local pairs, ipairs = pairs, ipairs
local floor, ceil, min = floor, ceil, min
local sort = sort
local tonumber = tonumber

-- WoW APIs
local BUFF_MAX_DISPLAY = BUFF_MAX_DISPLAY
local GetFramerate = GetFramerate
local DebuffTypeColor = DebuffTypeColor
local UnitIsUnit = UnitIsUnit
local GetAuraSlots = C_UnitAuras and C_UnitAuras.GetAuraSlots
local GetAuraDataBySlot, GetAuraDataByAuraInstanceID = C_UnitAuras and C_UnitAuras.GetAuraDataBySlot, C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
local GetNamePlates, GetNamePlateForUnit = C_NamePlate.GetNamePlates, C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local AnimationStopFlash, AnimationFlash = Addon.Animation.StopFlash, Addon.Animation.Flash
local FontUpdateText = Addon.Font.UpdateText
local AuraTriggerInitialize, AuraTriggerUpdateStyle, AuraTriggerCheckIfActive = Addon.Style.AuraTriggerInitialize, Addon.Style.AuraTriggerUpdateStyle, Addon.Style.AuraTriggerCheckIfActive
local CUSTOM_GLOW_FUNCTIONS, CUSTOM_GLOW_WRAPPER_FUNCTIONS = Addon.CUSTOM_GLOW_FUNCTIONS, Addon.CUSTOM_GLOW_WRAPPER_FUNCTIONS
local BackdropTemplate = Addon.BackdropTemplate
local MODE_FOR_STYLE, AnchorFrameTo = Addon.MODE_FOR_STYLE, Addon.AnchorFrameTo
local IsSecretValue = Addon.IsSecretValue
local AbbreviateNumbers = AbbreviateNumbers

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, UnitAffectingCombat

---------------------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------------------

local GRID_LAYOUT = {
  LEFT = {
    BOTTOM =  { "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMLEFT", "TOPLEFT"   ,    1,  1},
    TOP    =  { "BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT",    "BOTTOMLEFT",    1, -1},
  },
  RIGHT = {
    BOTTOM =  { "BOTTOMRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "TOPRIGHT",    -1,  1},
    TOP    =  { "TOPRIGHT"   , "TOPLEFT",    "TOPRIGHT",    "BOTTOMRIGHT", -1, -1},
  },
}

Widget.TEXTURE_BORDER = Addon.ADDON_DIRECTORY .. "Artwork\\squareline"

-- Debuffs are color coded, with poison debuffs having a green border, magic debuffs a blue border, diseases a brown border,
-- urses a purple border, and physical debuffs a red border
Widget.AURA_TYPE = { Curse = 1, Disease = 2, Magic = 3, Poison = 4, }

Widget.ANCHOR_POINT_SETPOINT = Addon.ANCHOR_POINT_SETPOINT

-- Aura Grids
Widget.Buffs = {
  CenterAurasPositions = {},
}
Widget.Debuffs = {
  CenterAurasPositions = {}
}
Widget.CrowdControl = {
  CenterAurasPositions = {}
}

local DEBUFF_DISPLAY_COLOR_INFO = {
  [0] = DEBUFF_TYPE_NONE_COLOR,
  [1] = DEBUFF_TYPE_MAGIC_COLOR,
  [2] = DEBUFF_TYPE_CURSE_COLOR,
  [3] = DEBUFF_TYPE_DISEASE_COLOR,
  [4] = DEBUFF_TYPE_POISON_COLOR,
  [9] = DEBUFF_TYPE_BLEED_COLOR, -- enrage
  [11] = DEBUFF_TYPE_BLEED_COLOR,
}
local DispelColorCurve = C_CurveUtil.CreateColorCurve()
DispelColorCurve:SetType(Enum.LuaCurveType.Step)
for i, c in pairs(DEBUFF_DISPLAY_COLOR_INFO) do
  DispelColorCurve:AddPoint(i, c)
end

local DISPELL_TYPE_NAME = {
  -- https://wago.tools/db2/SpellDispelType
  None = 0,
  Magic = 1,
  Curse = 2,
  Disease = 3,
  Poison = 4,
  Enrage = 9,
  Bleed = 11,
}

---------------------------------------------------------------------------------------------------
-- Crowd Control Auras
---------------------------------------------------------------------------------------------------

local CROWD_CONTROL_SPELLS_BY_EXPANSION = {
  MAINLINE = {},
}

Widget.CROWD_CONTROL_SPELLS = CROWD_CONTROL_SPELLS_BY_EXPANSION[Addon.GetExpansionLevel()]

---------------------------------------------------------------------------------------------------
-- Global attributes
---------------------------------------------------------------------------------------------------
--local PLayerIsInCombat = false
--local DispellableDebuffCache = {}

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local HideOmniCC, SetNoCooldownCount, ShowDuration, SortFunction
local AuraHighlightEnabled, AuraHighlightStart, AuraHighlightStop, AuraHighlightStopPrevious, AuraHighlightOffset
local AuraHighlightColor = { 0, 0, 0, 0 }
local EnabledForStyle = {}

---------------------------------------------------------------------------------------------------
-- OnUpdate code - updates the auras remaining uptime and stacks and hides them after they expired
---------------------------------------------------------------------------------------------------

local function OnShowHookScript(widget_frame)
  widget_frame.Buffs.TimeSinceLastUpdate = 0
  widget_frame.Debuffs.TimeSinceLastUpdate = 0
  widget_frame.CrowdControl.TimeSinceLastUpdate = 0
end

---------------------------------------------------------------------------------------------------
-- Code for showing tooltips on auras
---------------------------------------------------------------------------------------------------

local AuraTooltip = CreateFrame("GameTooltip", "ThreatPlatesAuraTooltip", UIParent, "GameTooltipTemplate")
local AuraFrameOnEnter

local function AuraFrameOnLeave(self)
  AuraTooltip:Hide()
end

-- SetUnitBuffByAuraInstanceID, SetUnitDebuffByAuraInstanceID: Dragonflight - Patch 10.0.0
if Addon.ExpansionIsAtLeastMidnight then
  AuraFrameOnEnter = function(self)
    AuraTooltip:SetOwner(self, "ANCHOR_LEFT")
    AuraTooltip:SetUnitAuraByAuraInstanceID(self:GetParent():GetParent().unit.unitid, self.AuraData.auraInstanceID)

    -- Would show more information, but mainly about the spell, not the aura
    -- AuraTooltip:SetSpellByID(self.AuraData.spellId)
  end
elseif Addon.ExpansionIsAtLeastDF then
  AuraFrameOnEnter = function(self)
    AuraTooltip:SetOwner(self, "ANCHOR_LEFT")

    -- I really think that SetUnit...ByAuraInstanceID does not the filter parameter, but still ...
    if self.AuraData.effect == "HELPFUL" then
      AuraTooltip:SetUnitBuffByAuraInstanceID(self:GetParent():GetParent().unit.unitid, self.AuraData.auraInstanceID, self.AuraData.effect)
    else
      AuraTooltip:SetUnitDebuffByAuraInstanceID(self:GetParent():GetParent().unit.unitid, self.AuraData.auraInstanceID, self.AuraData.effect)
    end
  end
else  
  AuraFrameOnEnter = function(self)
    AuraTooltip:SetOwner(self, "ANCHOR_LEFT")
    AuraTooltip:SetUnitAura(self:GetParent():GetParent().unit.unitid, self.AuraData.auraInstanceID, self.AuraData.effect)
  end
end

---------------------------------------------------------------------------------------------------
-- Filtering and sorting functions
---------------------------------------------------------------------------------------------------

function Widget:GetColorForAura(aura)
	local db = self.db

  -- if aura.dispelName and db.ShowAuraType then
  --   return DebuffTypeColor[aura.dispelName]
  if aura.effect == "HARMFUL" then  
    return db.DefaultDebuffColor
  else
    return db.DefaultBuffColor
	end
end

local function FilterNone(show_aura, spellfound, is_mine, show_only_mine)
  return show_aura
end

local function FilterAllowlist(show_aura, spellfound, is_mine, show_only_mine)
  if spellfound == "All" then
    return show_aura
  elseif spellfound == true then
    return (show_only_mine == nil and show_aura) or (show_aura and ((show_only_mine and is_mine) or show_only_mine == false))
  elseif spellfound == "My" then
    return show_aura and is_mine
  end

  return false
end

local function FilterBlocklist(show_aura, spellfound, is_mine, show_only_mine)
  -- blacklist all auras, i.e., default is show all auras (no matter who casted it)
  --   spellfound = true or All - blacklist this aura (from all casters)
  --   spellfound = My          - blacklist only my aura
  --   spellfound = nil         - show aura (spell not found in blacklist)
  --   spellfound = Not         - show aura (found entry not relevant, ignore it)

  if spellfound == "All" or spellfound == true then
    return false
  elseif spellfound == "My" then
    return not is_mine
  elseif spellfound == "Not" then
    return true
  end

  return show_aura
end

Widget.FILTER_FUNCTIONS = {
  all = FilterNone,
  blacklist = FilterBlocklist,
  whitelist = FilterAllowlist,
  None = FilterNone,
  Block = FilterBlocklist,
  Allow = FilterAllowlist,
}

if Addon.WOW_FEATURE_BLIZZARD_AURA_FILTER then
  function Widget:FilterFriendlyDebuffsBySpell(db, aura, AuraFilterFunction)    
    local show_aura = db.ShowAllFriendly --or
    --                   (db.ShowBlizzardForFriendly and (aura.nameplateShowAll or (aura.nameplateShowPersonal and aura.CastByPlayer))) or
    --                   (db.ShowDispellable and aura.isStealable) or
    --                   (db.ShowBoss and aura.isBossAura) or
    --                   (aura.dispelName and db.FilterByType[self.AURA_TYPE[aura.dispelName]])

    -- local spellfound = self.AuraFilterDebuffs[aura.name] or self.AuraFilterDebuffs[aura.spellId]

    -- return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)
    
    return show_aura
  end

  function Widget:FilterEnemyDebuffsBySpell(db, aura, AuraFilterFunction)
    local show_aura = db.ShowAllEnemy 
                      or (db.ShowOnlyMine and aura.CastByPlayer) 
                      --or (db.ShowBlizzardForEnemy and aura.isNameplateOnly)

    -- local spellfound = self.AuraFilterDebuffs[aura.name] or self.AuraFilterDebuffs[aura.spellId]

    -- return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer, db.ShowOnlyMine)

    return show_aura
  end

  function Widget:FilterFriendlyCrowdControlBySpell(db, aura, AuraFilterFunction)
    local show_aura = db.ShowAllFriendly --or
    --                   (db.ShowBlizzardForFriendly and (aura.nameplateShowAll or (aura.nameplateShowPersonal and aura.CastByPlayer))) or
    --                   (db.ShowDispellable and aura.isStealable) or
    --                   (db.ShowBoss and aura.isBossAura)

    -- local spellfound = self.AuraFilterCrowdControl[aura.name] or self.AuraFilterCrowdControl[aura.spellId]

    -- return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)
    
    return show_aura
  end

  function Widget:FilterEnemyCrowdControlBySpell(db, aura, AuraFilterFunction)
    local show_aura = db.ShowAllEnemy --or
    --                   (db.ShowBlizzardForEnemy and (aura.nameplateShowAll or (aura.nameplateShowPersonal and aura.CastByPlayer)))

    -- local spellfound = self.AuraFilterCrowdControl[aura.name] or self.AuraFilterCrowdControl[aura.spellId]

    -- return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)

    return show_aura
  end  

  function Widget:FilterFriendlyBuffsBySpell(db, aura, AuraFilterFunction, unit)
    local show_aura = db.ShowAllFriendly 
          or (db.ShowOnFriendlyNPCs and unit.type == "NPC") 
          or (db.ShowOnlyMine and aura.CastByPlayer)
    --   (db.ShowPlayerCanApply and aura.canApplyAura)

    -- local spellfound = self.AuraFilterBuffs[aura.name] or self.AuraFilterBuffs[aura.spellId]

    --return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)

    return show_aura
  end

  function Widget:FilterEnemyBuffsBySpell(db, aura, AuraFilterFunction, unit)
    local show_aura = db.ShowAllEnemy 
                      or (db.ShowOnEnemyNPCs and unit.type == "NPC")

    if aura.duration and db.HideUnlimitedDuration then
      show_aura = false
    else
      show_aura = db.ShowAllEnemy or (db.ShowOnEnemyNPCs and unit.type == "NPC")
      --(db.ShowDispellable and aura.isStealable) or  (aura.dispelName == "Magic" and db.ShowMagic)
    end

    -- --  local show_aura = db.ShowAllEnemy or (db.ShowOnEnemyNPCs and unit.type == "NPC") or (db.ShowDispellable and aura.isStealable)
    -- local spellfound = self.AuraFilterBuffs[aura.name] or self.AuraFilterBuffs[aura.spellId]

    -- show_aura = AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)

    -- -- Checking unlimited auras after filter function results in the filter list not being able to overwrite
    -- -- the "Show Unlimited Buffs" settings
    -- if show_aura and (aura.duration <= 0) then
    --   show_aura =  db.ShowUnlimitedAlways or
    --     (db.ShowUnlimitedInCombat and unit.InCombat) or
    --     (db.ShowUnlimitedInInstances and Addon.IsInInstance) or
    --     (db.ShowUnlimitedOnBosses and unit.IsBossOrRare)
    --   unit.HasUnlimitedAuras = true
    -- end

    return show_aura
  end
else
  -- ShowBlizzard... is not supported in Classic
  function Widget:FilterFriendlyDebuffsBySpell(db, aura, AuraFilterFunction)
    local show_aura = db.ShowAllFriendly or
      -- (db.ShowBlizzardForFriendly and (aura.nameplateShowAll or (aura.nameplateShowPersonal and aura.CastByPlayer))) or
      (db.ShowDispellable and aura.isStealable) or
      (db.ShowBoss and aura.isBossAura) or
      (aura.dispelName and db.FilterByType[self.AURA_TYPE[aura.dispelName]])

    local spellfound = self.AuraFilterDebuffs[aura.name] or self.AuraFilterDebuffs[aura.spellId]

    return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)
  end

  function Widget:FilterEnemyDebuffsBySpell(db, aura, AuraFilterFunction)
    local show_aura = db.ShowAllEnemy or
      (db.ShowOnlyMine and aura.CastByPlayer) --or
      -- (db.ShowBlizzardForEnemy and (aura.nameplateShowAll or (aura.nameplateShowPersonal and aura.CastByPlayer)))

    local spellfound = self.AuraFilterDebuffs[aura.name] or self.AuraFilterDebuffs[aura.spellId]

    return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer, db.ShowOnlyMine)
  end

  function Widget:FilterFriendlyCrowdControlBySpell(db, aura, AuraFilterFunction)
    local show_aura = db.ShowAllFriendly or
      --(db.ShowBlizzardForFriendly and (aura.nameplateShowAll or (aura.nameplateShowPersonal and aura.CastByPlayer))) or
      (db.ShowDispellable and aura.isStealable) or
      (db.ShowBoss and aura.isBossAura)

    local spellfound = self.AuraFilterCrowdControl[aura.name] or self.AuraFilterCrowdControl[aura.spellId]

    return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)
  end

  function Widget:FilterEnemyCrowdControlBySpell(db, aura, AuraFilterFunction)
    local show_aura = true
      --db.ShowAllEnemy or
      --(db.ShowBlizzardForEnemy and (aura.nameplateShowAll or (aura.nameplateShowPersonal and aura.CastByPlayer)))

    local spellfound = self.AuraFilterCrowdControl[aura.name] or self.AuraFilterCrowdControl[aura.spellId]

    return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)
  end

  function Widget:FilterFriendlyBuffsBySpell(db, aura, AuraFilterFunction, unit)
    local show_aura = db.ShowAllFriendly or
      (db.ShowOnFriendlyNPCs and unit.type == "NPC") or
      (db.ShowOnlyMine and aura.CastByPlayer) or
      (db.ShowPlayerCanApply and aura.canApplyAura)

    local spellfound = self.AuraFilterBuffs[aura.name] or self.AuraFilterBuffs[aura.spellId]

    return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)
  end

  function Widget:FilterEnemyBuffsBySpell(db, aura, AuraFilterFunction, unit)
    local show_aura
    if aura.duration <= 0 and db.HideUnlimitedDuration then
      show_aura = false
    else
      show_aura = db.ShowAllEnemy or (db.ShowOnEnemyNPCs and unit.type == "NPC") or (db.ShowDispellable and aura.isStealable) or
        (aura.dispelName == "Magic" and db.ShowMagic)
    end

    --  local show_aura = db.ShowAllEnemy or (db.ShowOnEnemyNPCs and unit.type == "NPC") or (db.ShowDispellable and aura.isStealable)
    local spellfound = self.AuraFilterBuffs[aura.name] or self.AuraFilterBuffs[aura.spellId]

    show_aura = AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)

    -- Checking unlimited auras after filter function results in the filter list not being able to overwrite
    -- the "Show Unlimited Buffs" settings
    if show_aura and (aura.duration <= 0) then
      show_aura =  db.ShowUnlimitedAlways or
        (db.ShowUnlimitedInCombat and unit.InCombat) or
        (db.ShowUnlimitedInInstances and Addon.IsInInstance) or
        (db.ShowUnlimitedOnBosses and unit.IsBossOrRare)
      unit.HasUnlimitedAuras = true
    end

    return show_aura
  end
end

---------------------------------------------------------------------------------------------------
-- Aura Sorting
---------------------------------------------------------------------------------------------------

local PRIORITY_FUNCTIONS = {
  None = function(aura) return 0 end,
  AtoZ = function(aura) return aura.name end,
  TimeLeft = function(aura) return aura.expirationTime - GetTime() end,
  Duration = function(aura) return aura.duration end,
  Creation = function(aura) return aura.expirationTime - aura.duration end,
}

local function AuraSortFunctionAtoZ(a, b)
  return a.priority < b.priority
end

local function AuraSortFunctionZtoA(a, b)
  return a.priority > b.priority
end

-- For auras without duration duration and expirationTime are 0, so sorting by TimeLeft, Duration, and Creation
-- does not work in that case. We will just sort by name for these auras
local function AuraSortFunctionNumAscending(a, b)
  if a.duration == 0 then
    if b.duration == 0 then
      return a.name < b.name
    else
      return false
    end
  elseif b.duration == 0 then
    if a.duration == 0 then
      return a.name < b.name
    else
      return true
    end
  else
    return a.priority < b.priority
  end
end

local function AuraSortFunctionNumDescending(a, b)
  if a.duration == 0 then
    if b.duration == 0 then
      return a.name > b.name
    else
      return true
    end
  elseif b.duration == 0 then
    if a.duration == 0 then
      return a.name > b.name
    else
      return false
    end
  else
    return a.priority > b.priority
  end
end

local SORT_FUNCTIONS = {
  None = nil,
  AtoZ = {
    Default = AuraSortFunctionAtoZ,
    Reverse = AuraSortFunctionZtoA,
  },
  TimeLeft = {
    Default = AuraSortFunctionNumAscending,
    Reverse = AuraSortFunctionNumDescending,
  },
  Duration = {
    Default = AuraSortFunctionNumAscending,
    Reverse = AuraSortFunctionNumDescending,
  },
  Creation = {
    Default = AuraSortFunctionNumAscending,
    Reverse = AuraSortFunctionNumDescending,
  },
}

local function SortAurasByPriority(unit_auras)
  if #unit_auras >= 0 and SortFunction then
    sort(unit_auras, SortFunction)
  end
end

---------------------------------------------------------------------------------------------------
-- Auras Module / Handler 
---------------------------------------------------------------------------------------------------

local UnitAuraWrapper
local ProcessAllUnitAuras

-- Defined here as it's used for configuration mode even in Mainline
local function ProcessAllUnitAurasClassic(unitid, effect)
  local _
  local unit_auras = {}

  for i = 1, 40 do
    local aura = {}

    aura.name, aura.icon, aura.applications, aura.dispelName, aura.duration, aura.expirationTime, aura.sourceUnit,
      aura.isStealable, aura.nameplateShowPersonal, aura.spellId, aura.canApplyAura, aura.isBossAura, _, aura.nameplateShowAll =
      UnitAuraWrapper(unitid, i, effect)

    if aura.name then 
      aura.auraInstanceID = i

      aura.duration = aura.duration or 0

      unit_auras[#unit_auras + 1] = aura
      -- if aura.sourceUnit == "player" then
      --   Addon.Logging.Debug("Aura:", aura.name, "=> ID:", aura.spellId)
      -- end
    else
      break
    end
  end

  return unit_auras
end

-- UnitAuraSlots: BfA - Patch 8.2.5 (2019-09-24): Added.
-- C_UnitAuras.GetAuraSlots: DF - Patch 10.2.5 (2024-01-16): Deprecated. Replaced by C_UnitAuras.GetAuraSlots.
if Addon.IS_MAINLINE then  
  ProcessAllUnitAuras = function(unitid, effect)
    -- local _
    -- local unit_auras = {}

    -- local aura_max_display = (effect == "HARMFUL" and DEBUFF_MAX_DISPLAY) or BUFF_MAX_DISPLAY

    -- -- AuraUtil.ForEachAura(unitid, effect, BUFF_MAX_DISPLAY, function(unit_aura_info)
    -- --   unit_aura_info.duration = unit_aura_info.duration or 0
    -- --   unit_auras[#unit_auras + 1] = unit_aura_info
    -- --   -- Addon.Logging.Debug("Aura:", aura.name, "=> ID:", aura.spellId)
    -- -- end, true)

    -- -- AuraUtil.ForEachAura:
    -- local continuation_token
    -- repeat
    --   -- continuationToken is the first return value of UnitAuraSlots
    --   local slots = { GetAuraSlots(unitid, effect, aura_max_display, continuation_token) }
    --   continuation_token = slots[1]

    --   for i = 2, #slots do
    --     local unit_aura_info = GetAuraDataBySlot(unitid, slots[i])  
    --     -- Without this check, there will be a Lua error when a priest mindcontrolls another player as 
    --     -- unit_aura_info is nil here in this case
    --     if type(unit_aura_info) ~= nil then
    --       --unit_aura_info.duration = unit_aura_info.duration or 0
    --       unit_auras[#unit_auras + 1] = unit_aura_info

    --       print(unit_aura_info.name, "=>", not C_UnitAuras.IsAuraFilteredOutByInstanceID(unitid, unit_aura_info.auraInstanceID, 'HARMFUL|PLAYER'))
    --     end
    --   end
    -- until continuation_token == nil

    -- return unit_auras

    local unit_auras = {}
    local function HandleAura(aura)
      unit_auras[#unit_auras + 1] = aura
      
      aura.CastByPlayer = not C_UnitAuras.IsAuraFilteredOutByInstanceID(unitid, aura.auraInstanceID, "HARMFUL|PLAYER")
    end
    AuraUtil.ForEachAura(unitid, effect, nil, HandleAura, true)

    return unit_auras
  end
else
  UnitAuraWrapper = UnitAura -- will be overwritten for Classic (but not for TBC or Wrath Classic)
  ProcessAllUnitAuras = ProcessAllUnitAurasClassic
end

local function IgnoreAuraUpdateForUnit(widget_frame, unit)
  -- ! "Target Only" only supports the direct target, not action targets
  local unit_is_target = UnitIsUnit("target", unit.unitid)
  if Widget.db.ShowTargetOnly then
    if unit_is_target then
      Widget.CurrentTarget = widget_frame
    elseif not Addon.ActiveAuraTriggers then
      -- Continue with aura scanning for non-target units if there are aura triggers that might change the nameplates style
      widget_frame:Hide()
      return true
    end
  end

  AuraTriggerInitialize(unit)

  widget_frame.HideAuras = not EnabledForStyle[unit.style] or (Widget.db.ShowTargetOnly and not unit_is_target)  
end

local function AuraGridUpdateForUnitNotNecessary(widget_frame, unit)
  AuraTriggerUpdateStyle(unit)

  if widget_frame.HideAuras then
    widget_frame:Hide()
    return true
  end
end

local AuraGridUpdate = {
  Buffs = false,
  Debuffs = false,
  CrowdControl = false,
  --   BuffsAuraFrames = {},
  --   DebuffsAuraFrames = {},
  --   CrowdControlAuraFrames = {},
  AuraFrames  ={}
}

local function FlagAuraGridForUpdate(aura_grid_update, is_crowdcontrol_aura, is_harmfull)
  if is_crowdcontrol_aura then -- is_harmfull is true in this case
    aura_grid_update.CrowdControl = true
  elseif is_harmfull then
    aura_grid_update.Debuffs = true
  else
    aura_grid_update.Buffs = true
  end
end

function Widget:UNIT_AURA(unitid, unit_aura_update_info)
  local widget_frame = self:GetWidgetFrameForUnit(unitid)
  if widget_frame then 
    widget_frame.Widget:UpdateAuras(widget_frame, widget_frame.unit)
  end
end

local StartTimeForAura = {}

function Widget:UNIT_AURA(unitid, update_info)
  local widget_frame = self:GetWidgetFrameForUnit(unitid)
  if widget_frame then 
    widget_frame.Widget:UpdateAuras(widget_frame, widget_frame.unit)

    if update_info and update_info.addedAuras then
      local start_time = GetTime()
      for _, aura_data in ipairs(update_info.addedAuras) do
        StartTimeForAura[aura_data.auraInstanceID] = start_time
        local aura_frame = widget_frame.UnitAuras[aura_data.auraInstanceID]
        if aura_frame then
          aura_frame.Cooldown:SetCooldownDuration(aura_data.duration) --, modRate)
        end
      end
    end

    if update_info and update_info.removedAuraInstanceIDs then
      for _, aura_instance_id in ipairs(update_info.removedAuraInstanceIDs) do
        StartTimeForAura[aura_instance_id] = nil
      end
    end
  end
end

-- Struct UnitAuraInfo: https://wowpedia.fandom.com/wiki/Struct_UnitAuraInfo
--   dispelName is the UnitAura return value for the auraType ("" is enrage, nil/"none" for unspecified and "Disease", "Poison", "Curse", "Magic" for other types.	
-- local function UnitAuraEventHandler(widget_frame, event, unitid, unit_aura_update_info)
--   local unit = widget_frame.unit

--   if widget_frame.Active then
--     if unit_aura_update_info == nil or unit_aura_update_info.isFullUpdate then
--       widget_frame.Widget:UpdateAuras(widget_frame, widget_frame.unit)
--     else
--       if IgnoreAuraUpdateForUnit(widget_frame, unit) then return end

--       -- Current implementation: updates a aura grid frame only if either a shown aura is removed or a new
--       -- aura should be shown (considering filter settings)
--       local aura_grid_update = AuraGridUpdate
--       aura_grid_update.Buffs = false
--       aura_grid_update.Debuffs = false
--       aura_grid_update.CrowdControl = false

--       local db = Widget.db
--       local enabled_cc = (unit.reaction == "FRIENDLY" and db.CrowdControl.ShowFriendly) or db.CrowdControl.ShowEnemy

--       if unit_aura_update_info.addedAuras ~= nil then
--         for _, unit_aura_info in ipairs(unit_aura_update_info.addedAuras) do
--           local is_crowdcontrol_aura = enabled_cc -- and Widget.CROWD_CONTROL_SPELLS[unit_aura_info.spellId]

--           FlagAuraGridForUpdate(aura_grid_update, is_crowdcontrol_aura, unit_aura_info.isHarmful)
--           -- print("  Add =>", aura_data.name, ":", grid_name)            
--         end                  
--       end

--       if unit_aura_update_info.updatedAuraInstanceIDs ~= nil then
--         for _, aura_instance_id in ipairs(unit_aura_update_info.updatedAuraInstanceIDs) do
--           local aura_frame = widget_frame.UnitAuras[aura_instance_id]
--           if aura_frame then
--             -- Just update the corresponding aura_frame
--             local aura_data = aura_frame.AuraData
            
--             -- local grid_name = (aura_data.CrowdControl and "CrowdControl") or (aura_data.effect == "HARMFUL" and "Debuffs") or "Buffs"
--             -- print("  Update =>", aura_data.name, ":", grid_name, "-", aura_data.auraInstanceID)        

--             -- Update the aura data from the unit_aura_info
--             local unit_aura_info = GetAuraDataByAuraInstanceID(unitid, aura_data.auraInstanceID)
--             -- If unit_aura_info is nil, this means that the aura expired, so nothing to do here
--             if unit_aura_info then
--               -- for k, v in pairs(unit_aura_info) do
--               --   if unit_aura_info[k] ~= aura_data.UnitAuraInfo[k] and 
--               --     k ~= "points" and k ~= "expirationTime" and k ~= "applications" and k ~= "duration" and k ~= "sourceUnit" then
--               --     print("  -", k, ":", aura_data.UnitAuraInfo[k], "=>", unit_aura_info[k])
--               --   end
--               -- end

--               -- Updates for the following attributes seem to be happinging and relevant:
--               --   applications (stacks)
--               --   duration (including expirationTime)
--               -- Irrelevant are:
--               --   points
--               --   sourceUnit - What does this mean? Is the aura overwritten? E.g. mouseover => nameplateXX, nil => nameplateXX

--               -- If the attribute changes that is used for sorting, we have to update the whole grid
--               -- ? Is it really worth handling this special case considering the performance impact?
--               --FlagAuraGridForUpdate(aura_grid_update, aura_data.CrowdControl, aura_data.effect == "HARMFUL")

--               FlagAuraGridForUpdate(aura_grid_update, aura_data.CrowdControl, aura_data.effect == "HARMFUL")

--               -- if unit_aura_info.duration ~= aura_data.duration and (db.SortOrder == "Duration" or db.SortOrder == "TimeLeft") then
--               --   FlagAuraGridForUpdate(aura_grid_update, aura_data.CrowdControl, aura_data.effect == "HARMFUL")
--               -- else
--               --   aura_data.applications = unit_aura_info.applications
--               --   -- Although only the duration change is imporatant, we need to update expirationTime as well as
--               --   -- otherwise calculation of the remaining duration would be wrong
--               --   aura_data.duration = unit_aura_info.duration
--               --   aura_data.expirationTime = unit_aura_info.expirationTime
                
--               --   -- ! This is not necessary, if the corresponding aura grid will be updated anyway ...
--               --   aura_grid_update.AuraFrames[#aura_grid_update.AuraFrames + 1] = aura_frame
--               -- end
--             end
--           end                  
--         end
--       end
    
--       if unit_aura_update_info.removedAuraInstanceIDs ~= nil then
--         for _, aura_instance_id in ipairs(unit_aura_update_info.removedAuraInstanceIDs) do
--           local aura_frame = widget_frame.UnitAuras[aura_instance_id]
--           if aura_frame then
--             FlagAuraGridForUpdate(aura_grid_update, aura_frame.AuraData.CrowdControl, aura_frame.AuraData.effect == "HARMFUL")
--             -- print("  Delete =>", aura_data.name, ":", grid_name)            
--           end                  
--         end
--       end      

--       local update_buff_grid, update_debuff_grid, update_cc_grid = aura_grid_update.Buffs, aura_grid_update.Debuffs, aura_grid_update.CrowdControl

--       if unit.reaction == "FRIENDLY" then -- friendly or better
--         local buff_aura_grid = (db.SwitchAreaByReaction and widget_frame.Debuffs) or widget_frame.Buffs
--         local debuff_aura_grid = (db.SwitchAreaByReaction and widget_frame.Buffs) or widget_frame.Debuffs        

--         if update_buff_grid then
--           Widget:UpdateUnitAuras(buff_aura_grid, unit, db.Buffs.ShowFriendly, false, Widget.FilterFriendlyBuffsBySpell, Widget.FilterFriendlyCrowdControlBySpell, "HELPFUL", db.Buffs.FilterMode)
--         end
--         if update_debuff_grid or update_cc_grid then
--           Widget:UpdateUnitAuras(debuff_aura_grid, unit, db.Debuffs.ShowFriendly, enabled_cc, Widget.FilterFriendlyDebuffsBySpell, Widget.FilterFriendlyCrowdControlBySpell, "HARMFUL", db.Debuffs.FilterMode)
--         end
--       else
--         if update_buff_grid then
--           Widget:UpdateUnitAuras(widget_frame.Buffs, unit, db.Buffs.ShowEnemy, false, Widget.FilterEnemyBuffsBySpell, Widget.FilterEnemyCrowdControlBySpell, "HELPFUL", db.Buffs.FilterMode)
--         end
--         if update_debuff_grid or update_cc_grid then
--           Widget:UpdateUnitAuras(widget_frame.Debuffs, unit, db.Debuffs.ShowEnemy, enabled_cc, Widget.FilterEnemyDebuffsBySpell, Widget.FilterEnemyCrowdControlBySpell, "HARMFUL", db.Debuffs.FilterMode)
--         end
--       end

--       if AuraGridUpdateForUnitNotNecessary(widget_frame, unit) then return end
      
--       -- Aura grids have to be updated here only when auras changed, not necessarily because ActiveAuras > 0
--       if update_buff_grid then
--         Widget:UpdatePositionAuraGrid(widget_frame, "Buffs", unit.style)
--       -- else
--       --   for i = #aura_grid_update.BuffsAuraFrames, 1, -1 do
--       --     Widget.Buffs:UpdateAuraInformation(aura_grid_update.BuffsAuraFrames[i])
--       --     aura_grid_update.BuffsAuraFrames[i] = nil
--       --   end
--       end
--       if update_debuff_grid then
--         Widget:UpdatePositionAuraGrid(widget_frame, "Debuffs", unit.style)
--       -- else
--       --   for i = #aura_grid_update.DebuffsAuraFrames, 1, -1 do
--       --     Widget.Debuffs:UpdateAuraInformation(aura_grid_update.DebuffsAuraFrames[i])
--       --     aura_grid_update.DebuffsAuraFrames[i] = nil
--       --   end
--       end
--       if update_cc_grid then
--         Widget:UpdatePositionAuraGrid(widget_frame, "CrowdControl", unit.style)
--       -- else
--       --   for i = #aura_grid_update.CrowdControlAuraFrames, 1, -1 do
--       --     Widget.CrowdControl:UpdateAuraInformation(aura_grid_update.CrowdControlAuraFrames[i])
--       --     aura_grid_update.CrowdControlAuraFrames[i] = nil
--       --   end
--       end

--       -- Update aura frames directly if their aura grid was not updated anyway
--       --for i = 1, #aura_grid_update.AuraFrames do
--       for i = #aura_grid_update.AuraFrames, 1, -1 do
--         local aura_frame = aura_grid_update.AuraFrames[i]
--         local aura_data = aura_frame.AuraData

--         if not update_cc_grid and aura_data.CrowdControl then
--           Widget.CrowdControl:UpdateAuraInformation(aura_frame)
--         elseif not update_debuff_grid and aura_data.effect == "HARMFUL" then
--           Widget.Debuffs:UpdateAuraInformation(aura_frame)
--         elseif not update_buff_grid and aura_data.effect == "HELPFUL" then
--           Widget.Buffs:UpdateAuraInformation(aura_frame)
--         end

--         aura_grid_update.AuraFrames[i] = nil
--       end

--       if widget_frame.Buffs.ActiveAuras > 0 or widget_frame.Debuffs.ActiveAuras > 0 or widget_frame.CrowdControl.ActiveAuras > 0 then
--         widget_frame.CrowdControl:SetShown(enabled_cc)
--         widget_frame:Show()
--       else
--         widget_frame:Hide()
--       end
--     end
--   end
-- end

-------------------------------------------------------------
-- Widget Object Functions
-------------------------------------------------------------

-- local function ShouldShowAura(widget_frame, unit, aura)
--   -- CastByPlayer is also used by aura trigger custom styles (only my auras)
  
--   -- aura.caster => aura.sourceUnit
--   -- aura.StealOrPurge => aura.isStealable
--   -- aura.texture => aura.icon
--   -- aura.stacks => aura.applications
--   -- aura.expiration => aura.expirationTime
--   -- Fehlt: 
--   --   aura.dispelName
  
--   -- Neu:
--   --   aura.isRaid
--   --   aura.isNameplateOnly
--   --   aura.timeMod?
--   --   aura.auraInstanceID
--   --   aura.isHarmful, aura.isHelpful
  
--   aura.CastByPlayer = aura.isFromPlayerOrPlayerPet or aura.sourceUnit == "vehicle"

--   UnitStyle_AuraTrigger_CheckIfActive(unit, aura.spellId, aura.name, aura.CastByPlayer)

--   -- Workaround or hack, currently, for making aura-triggered custom nameplates work even on nameplates that do
--   -- not show auras currently without a big overhead
--   if widget_frame.HideAuras then return false end

  
--   local show_aura = false
  
--   local db_auras = (aura.isHarmful and Widget.db.Debuffs) or Widget.db.Buffs
--   local db_crowdcontrol = Widget.db.CrowdControl

--   local AuraFilterFunction = Widget.FILTER_FUNCTIONS[db_auras.FilterMode]
--   local AuraFilterFunctionCC = Widget.FILTER_FUNCTIONS[db_crowdcontrol.FilterMode]

--   local enabled_auras, enabled_cc, SpellFilter, SpellFilterCC
--   if unit.reaction == "FRIENDLY" then 
--     if aura.isHarmful then
--       enabled_auras = Widget.db.Debuffs.ShowFriendly
--       enabled_cc = db_crowdcontrol.ShowFriendly
--       SpellFilter = Widget.FilterFriendlyDebuffsBySpell
--     else
--       enabled_auras = Widget.db.Buffs.ShowFriendly
--       enabled_cc = false
--       SpellFilter = Widget.FilterFriendlyBuffsBySpell
--     end
--     SpellFilterCC = Widget.FilterFriendlyCrowdControlBySpell
--   else
--     if aura.isHarmful then
--       enabled_auras = Widget.db.Debuffs.ShowEnemy
--       enabled_cc = db_crowdcontrol.ShowEnemy
--       SpellFilter = Widget.FilterEnemyDebuffsBySpell
--     else
--       enabled_auras = Widget.db.Buffs.ShowEnemy
--       enabled_cc = false
--       SpellFilter = Widget.FilterEnemyBuffsBySpell
--     end
--     SpellFilterCC = Widget.FilterEnemyCrowdControlBySpell
--   end

--   -- --
--   -- local filters = {
--   --   FRIENDLY = {
--   --     [true] = {
--   --       EnabledAuras = Widget.db.Debuffs.ShowFriendly,
--   --       EnabledCC = db_crowdcontrol.ShowFriendly,
--   --       SpellFilter = Widget.FilterFriendlyDebuffsBySpell,
--   --       SpellFilterCC = Widget.FilterFriendlyCrowdControlBySpell,
--   --     },
--   --     [false] = {
--   --       EnabledAuras = Widget.db.Buffs.ShowFriendly,
--   --       EnabledCC = false,
--   --       SpellFilter = Widget.FilterFriendlyBuffsBySpell,
--   --       SpellFilterCC = Widget.FilterFriendlyCrowdControlBySpell,
--   --     }
--   --   },
--   --   HOSTILE = {
--   --     [true] = {
--   --     },
--   --     [false] = {
--   --     }
--   --   }
--   -- }
--   -- filters.NEUTRAL = filters.HOSTILE
--   -- local filter_unit = filters[unit.reaction][aura.isHarmful]

--   aura.effect = (aura.isHarmful and "HARMFUL") or "HELPFUL"
--   aura.CrowdControl = (enabled_cc and Widget.CROWD_CONTROL_SPELLS[aura.spellId])

--   if aura.CrowdControl then
--     show_aura = SpellFilterCC(Widget, Widget.db, aura, AuraFilterFunctionCC)
    
--     -- Show crowd control auras that are not shown in Blizard mode as normal debuffs
--     if not show_aura and enabled_auras then
--       aura.CrowdControl = false
--       show_aura = SpellFilter(Widget, db_auras, aura, AuraFilterFunction)
--     end
--   elseif enabled_auras then
--     show_aura = SpellFilter(Widget, db_auras, aura, AuraFilterFunction, unit)
--   end

--   if show_aura then
--     aura.color = Widget:GetColorForAura(aura)
--     aura.priority = Widget.PRIORITY_FUNCTIONS[Widget.db.SortOrder](aura)
--   end

--   return show_aura
-- end

-- function Widget:UpdateUnitAurasTest(aura_grid_frame, unit, enabled_auras, enabled_cc, SpellFilter, SpellFilterCC, effect, filter_mode)
--   --AuraUtil.ForEachAura("player", effect, nil, HandleAura, true)

--   local function HandleAura(aura_info)
--     print("====> Aura:", aura_info.name)
--     Addon.Debug.PrintTable(aura_info)
--   end

--   local function ForEachAuraHelper(unit, filter, func, continuationToken, ...)
-- 		-- continuationToken is the first return value of UnitAuraSlots()
-- 		local n = select('#', ...);
-- 		for i=1, n do
-- 			local slot = select(i, ...);
--       local auraInfo = C_UnitAuras.GetAuraDataBySlot(unit, slot);
--       func(auraInfo);
-- 		end
-- 		return continuationToken;
-- 	end

--   local unit = "player"
  
--   local continuation_token
--   repeat
--     -- continuationToken is the first return value of UnitAuraSltos
--     local slots = { UnitAuraSlots(unit, effect, BUFF_MAX_DISPLAY, continuation_token) }
--     continuation_token = slots[1]

--     for i = 2, #slots do
--       local aura_data = C_UnitAuras.GetAuraDataBySlot(unit, slots[i])      
--       print("====> Aura:", aura_data.name)
--       Addon.Debug.PrintTable(aura_data)

--       print(">>>>", UnitAuraBySlot(unit, slots[i]))
--     end

--     --continuationToken = ForEachAuraHelper(unit, effect, HandleAura, UnitAuraSlots(unit, effect, nil, continuationToken))
--   until continuation_token == nil
-- end
  
-- function Widget:HandleAura(widget_frame, unit, slot, effect, enabled_auras, enabled_cc, SpellFilter, SpellFilterCC, filter_mode)
--   local db = self.db
--   local db_auras = (effect == "HARMFUL" and db.Debuffs) or db.Buffs
--   local unitid = unit.unitid
--   local UnitAuraList = {}

--   local AuraFilterFunction = self.FILTER_FUNCTIONS[filter_mode]
--   local AuraFilterFunctionCC = self.FILTER_FUNCTIONS[db.CrowdControl.FilterMode]

--   -- Auras are evaluated by an external function - pre-filtering before the icon grid is populated
--   UnitAuraList[aura_count] = UnitAuraList[aura_count] or {}
--   local aura = UnitAuraList[aura_count]

--   -- * Using variable names from UNIT_AURA updatedAuraInfos here to avoid to much copying of variables
--   -- TBC Classic, Retail:
--   -- name, icon, count, dispelName, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, nameplateShowAll, timeMod, ...
--   aura.name, aura.icon, aura.applications, aura.dispelName, aura.duration, aura.expirationTime, aura.sourceUnit,
--     aura.isStealable, aura.nameplateShowPersonal, aura.spellId, aura.canApplyAura, aura.isBossAura, _, aura.nameplateShowAll =
--     UnitAuraWrapper(unitid, slot)
  
--   -- ShowPesonal: Debuffs  that are shown on Blizzards nameplate, no matter who casted them (and
--   -- nameplateShowAll: Debuffs
--   if not aura.name then 
--     return false
--   end

--   -- Addon.Logging.Debug("Aura:", aura.name, "=> ID:", aura.spellId)

--   -- CastByPlayer is also used by aura trigger custom styles (only my auras)
--   aura.CastByPlayer = (aura.sourceUnit == "player" or aura.sourceUnit == "pet" or aura.sourceUnit == "vehicle")
--   --aura.CastByPlayer = aura.isFromPlayerOrPlayerPet or aura.sourceUnit == "vehicle"

--   UnitStyle_AuraTrigger_CheckIfActive(unit, aura.spellId, aura.name, aura.CastByPlayer)

--   -- Cache dispellable debuffs for more efficient checks with the UNIT_AURA event
--   --DispellableDebuffCache[aura.spellId] = aura.isStealable

--   -- Workaround or hack, currently, for making aura-triggered custom nameplates work even on nameplates that do
--   -- not show auras currently without a big overhead
--   local show_aura = false
--   if not widget_frame.HideAuras then
--     aura.effect = effect
--     aura.CrowdControl = (enabled_cc and self.CROWD_CONTROL_SPELLS[aura.spellId])
    
--     -- Store Order/Priority
--     if aura.CrowdControl then
--       show_aura = SpellFilterCC(self, db.CrowdControl, aura, AuraFilterFunctionCC)

--       -- Show crowd control auras that are not shown in Blizard mode as normal debuffs
--       if not show_aura and enabled_auras then
--         aura.CrowdControl = false
--         show_aura = SpellFilter(self, db_auras, aura, AuraFilterFunction)
--       end
--     elseif enabled_auras then
--       show_aura = SpellFilter(self, db_auras, aura, AuraFilterFunction, unit)
--     end

--     if show_aura then
--       aura.color = self:GetColorForAura(aura)
--       aura.priority = self.PRIORITY_FUNCTIONS[db.SortOrder](aura)

--       local aura_data = GetAuraDataBySlot(unitid, slot)   
--       aura.auraInstanceID = aura_data.auraInstanceID
--       aura.AuraData = aura_data

--       aura_count = aura_count + 1
--     end

--     -- local show_aura_new = ShouldShowAura(widget_frame, unit, aura)
--     -- if show_aura ~= show_aura_new then
--     --   print("Compare:", aura.name, " = ", show_aura, "=> New:", show_aura_new)
--     -- end
--   end

--   return show_aura
-- end

function Widget:UpdateUnitAuras(aura_grid_frame, unit, enabled_auras, enabled_cc, SpellFilter, SpellFilterCC, effect, filter_mode)
  --local aura_grid_frame = widget_frame[aura_type]
  --local enabled_auras = frame.AuraGrid[aura_type].ShowFriendly
  --local filter_mode = frame.AuraGrid[aura_type].FilterMode
  local aura_grid = aura_grid_frame.AuraGrid

  -- If debuffs are disabled, but CCs are enabled, we should just hide debuffs, but still process all auras to be able to show CC debuffs
  if not (enabled_auras or enabled_cc) then 
    aura_grid_frame.ActiveAuras = 0
    aura_grid:HideNonActiveAuras(aura_grid_frame)
    aura_grid_frame:Hide()
    return
  end 

  -- Show the aura grid (for debuffs) as it might be hidden when the nameplate was, e.g., used for friendly units where debuffs&CCs are disabled, 
  -- and then is re-used for enemy units where these are enabled.
  aura_grid_frame:Show()

  local db = self.db
  -- Optimization for auras sorting

  aura_grid_frame.Filter = effect -- Used for showning the correct tooltip
  local widget_frame = aura_grid_frame:GetParent()
  unit.HasUnlimitedAuras = false
  local unitid = unit.unitid

  local db_auras = (effect == "HARMFUL" and db.Debuffs) or db.Buffs
  local AuraFilterFunction = self.FILTER_FUNCTIONS[filter_mode]
  local AuraFilterFunctionCC = self.FILTER_FUNCTIONS[db.CrowdControl.FilterMode]

  local unit_auras_to_show = {}

  local unit_auras = ProcessAllUnitAuras(unitid, effect)
  for i = 1, #unit_auras do
    local aura = unit_auras[i]

    -- if C_Spell.IsSpellImportant(aura.spellId) then
    --   print("Aura:", aura.name)
    -- end

    -- CastByPlayer is also used by aura trigger custom styles (only my auras)
    -- aura.CastByPlayer aura.sourceUnit == "player" or aura.sourceUnit == "pet" or aura.sourceUnit == "vehicle")

    -- Cache dispellable debuffs for more efficient checks with the UNIT_AURA event
    -- DispellableDebuffCache[aura.spellId] = aura.isStealable

    -- AuraTriggerCheckIfActive(unit, aura.spellId, aura.name, aura.CastByPlayer)
    
    -- Workaround or hack, currently, for making aura-triggered custom nameplates work even on nameplates that do
    -- not show auras currently without a big overhead
    if not widget_frame.HideAuras then
      local show_aura

      aura.effect = effect
      -- aura.CrowdControl = enabled_cc and self.CROWD_CONTROL_SPELLS[aura.spellId]
      
      -- Store Order/Priority
      if aura.CrowdControl then

        show_aura = SpellFilterCC(self, db.CrowdControl, aura, AuraFilterFunctionCC)

        -- Show crowd control auras that are not shown in Blizard mode as normal debuffs
        if not show_aura and enabled_auras then
          aura.CrowdControl = false
          show_aura = SpellFilter(self, db_auras, aura, AuraFilterFunction)
        end
      elseif enabled_auras then
        show_aura = SpellFilter(self, db_auras, aura, AuraFilterFunction, unit)
      end

      if show_aura then
        aura.color = self:GetColorForAura(aura)
        -- aura.priority = PRIORITY_FUNCTIONS[db.SortOrder](aura)

        unit_auras_to_show[#unit_auras_to_show + 1] = aura
      end

      -- local show_aura_new = ShouldShowAura(widget_frame, unit, aura)
      -- if show_aura ~= show_aura_new then
      --   print("Compare:", aura.name, " = ", show_aura, "=> New:", show_aura_new)
      -- end
    end
  end

  if widget_frame.HideAuras then return end

  -- Show auras
  local aura_grid_cc = self.CrowdControl
  local aura_grid_frame_cc = widget_frame.CrowdControl

  -- Sort auras based on order criteria
  -- SortAurasByPriority(unit_auras_to_show)

  local aura_count = 0
  local aura_count_cc = 0
  for index = 1, #unit_auras_to_show do
    local aura_frame
    
    local aura = unit_auras_to_show[index]
    if aura.spellId and aura.expirationTime then
      if aura.CrowdControl then
        -- Don't show CCs beyond MaxAuras, sorting should be correct here
        if aura_count_cc < aura_grid_cc.MaxAuras then
          aura_count_cc = aura_count_cc + 1
          aura_frame = aura_grid_cc:GetAuraFrame(aura_grid_frame_cc, aura_count_cc)
        end
      else
        if aura_count < aura_grid.MaxAuras then
          aura_count = aura_count + 1
          aura_frame = aura_grid:GetAuraFrame(aura_grid_frame, aura_count)
        end          
      end

      -- aura_frame is nil here when the max amount of auras is already shown
      if aura_frame then
        widget_frame.UnitAuras[aura.auraInstanceID] = aura_frame

        aura_frame.unitid = unit.unitid
        aura_frame.AuraData = aura
        -- Call function to display the aura
        if aura.CrowdControl then
          aura_grid_cc:UpdateAuraInformation(aura_frame)
        else
          aura_grid:UpdateAuraInformation(aura_frame)
        end
      end

      -- Both aura areas (buffs/debuffs) and crowd control are filled up, no further processing necessary
      if aura_count >= aura_grid.MaxAuras and aura_count_cc >= aura_grid_cc.MaxAuras then
        break
      end
    end
  end

  -- Hide non-active aura slots
  aura_grid_frame.ActiveAuras = aura_count
  aura_grid:HideNonActiveAuras(aura_grid_frame, true)

  if effect == "HARMFUL" then
    aura_grid_frame_cc.ActiveAuras = aura_count_cc
    -- If scanning debuffs, also hide non-active CC aura slots
    aura_grid_cc:HideNonActiveAuras(aura_grid_frame_cc)
  end
end

-- local function CenterAuraGrid(aura_grid, aura_grid_frame, db_aura_grid)
--   local auras_no = aura_grid_frame.ActiveAuras
--   if aura_grid.IconMode and auras_no > 0 then
--     local x_offset = 0
--     if db_aura_grid.CenterAuras then
--       -- Re-anchor the first frame, if auras should be centered
--       x_offset = (auras_no < aura_grid.Columns) and aura_grid.CenterAurasPositions[auras_no] or 0
--     end
--     local align_layout = aura_grid.AlignLayout
--     local aura_one = aura_grid_frame.AuraFrames[1]
--     aura_one:ClearAllPoints()
--     aura_one:SetPoint(align_layout[3], aura_grid_frame, (aura_grid.AuraWidgetOffset + x_offset) * align_layout[5], (aura_grid.AuraWidgetOffset + aura_grid.RowSpacing) * align_layout[6])
--   end
-- end

-- function Widget:ResizeAurasOfAuraGrid(aura_grid, aura_grid_frame)
--   local db_aura_grid = aura_grid.db
--   local aura_frame_list = aura_grid_frame.AuraFrames
--   local auras_no = aura_grid_frame.ActiveAuras

--   print ("No: ", auras_no)
--   local auras_no = aura_grid_frame.ActiveAuras
--   for index = 1, auras_no do
--     local aura_frame = aura_frame_list[index]
--     aura_frame:SetSize(db_aura_grid.IconWidth, db_aura_grid.IconHeight)

--     -- Need to do this because of different offset
--     local align_layout = aura_grid.AlignLayout
--     aura_frame:ClearAllPoints()
--     if index == 1 then
--       aura_frame:SetPoint(align_layout[3], aura_grid_frame, aura_grid.AuraWidgetOffset * align_layout[5], (aura_grid.AuraWidgetOffset + aura_grid.RowSpacing) * align_layout[6])
--     elseif (index - 1) % aura_grid.Columns == 0 then
--       aura_frame:SetPoint(align_layout[3], aura_frame_list[index - aura_grid.Columns], align_layout[4], 0, aura_grid.RowSpacing * align_layout[6])
--     else
--       aura_frame:SetPoint(align_layout[1], aura_frame_list[index - 1], align_layout[2], aura_grid.ColumnSpacing * align_layout[5], 0)
--     end
--   end

--   -- Re-center aura area as size has changed now
--   -- CenterAuraGrid(aura_grid, aura_grid_frame, db_aura_grid)
--   if aura_grid.IconMode and auras_no > 0 then
--     local x_offset = 0
--     if db_aura_grid.CenterAuras then
--       -- Re-anchor the first frame, if auras should be centered
--       x_offset = (auras_no < aura_grid.Columns) and aura_grid.CenterAurasPositions[auras_no] or 0
--     end
--     local align_layout = aura_grid.AlignLayout
--     local aura_one = aura_grid_frame.AuraFrames[1]
--     aura_one:ClearAllPoints()
--     aura_one:SetPoint(align_layout[3], aura_grid_frame, (aura_grid.AuraWidgetOffset + x_offset) * align_layout[5], (aura_grid.AuraWidgetOffset + aura_grid.RowSpacing) * align_layout[6])
--   end

--   aura_grid_frame:SetHeight(ceil(auras_no / aura_grid.Columns) * (aura_grid.AuraHeight + aura_grid.AuraWidgetOffset) +
--   aura_grid.RowSpacing + aura_grid.AuraWidgetOffset)
-- end

function Widget:UpdatePositionAuraGrid(widget_frame, aura_type, unit_style)
  local db = self.db

  local aura_grid = self[aura_type]
  local aura_grid_frame = widget_frame[aura_type]
  local auras_no = aura_grid_frame.ActiveAuras

  -- if not aura_grid_frame.TestBackground then
  --  aura_grid_frame.TestBackground = aura_grid_frame:CreateTexture(nil, "BACKGROUND")
  --  aura_grid_frame.TestBackground:SetAllPoints(aura_grid_frame)
  --  aura_grid_frame.TestBackground:SetTexture(Addon.LibSharedMedia:Fetch('statusbar', Addon.db.profile.AuraWidget.BackgroundTexture))
  --  aura_grid_frame.TestBackground:SetVertexColor(0,0,0,0.5)
  -- end

  local db_aura_grid = db[aura_type]
  local anchor_to_db = db_aura_grid.AnchorTo
  local anchor_to = (anchor_to_db == "Healthbar" and aura_grid_frame:GetParent()) or widget_frame[anchor_to_db]

  AnchorFrameTo(db_aura_grid[MODE_FOR_STYLE[unit_style]], aura_grid_frame, anchor_to)
  if aura_grid.IconMode and auras_no > 0 then
    local x_offset = 0
    if db_aura_grid.CenterAuras then
      -- Re-anchor the first frame, if auras should be centered
      x_offset = (auras_no < aura_grid.Columns) and aura_grid.CenterAurasPositions[auras_no] or 0
    end
    local align_layout = aura_grid.AlignLayout
    local aura_one = aura_grid_frame.AuraFrames[1]
    aura_one:ClearAllPoints()
    aura_one:SetPoint(align_layout[3], aura_grid_frame, (aura_grid.AuraWidgetOffset + x_offset) * align_layout[5], (aura_grid.AuraWidgetOffset + aura_grid.RowSpacing) * align_layout[6])
  end

  aura_grid_frame:SetHeight(ceil(auras_no / aura_grid.Columns) * (aura_grid.AuraHeight + aura_grid.AuraWidgetOffset) +
    aura_grid.RowSpacing + aura_grid.AuraWidgetOffset)
end

function Widget:UpdateAurasGrids(widget_frame, unit)
  local db = self.db

  widget_frame.UnitAuras = {}

  local enabled_cc
  if unit.reaction == "FRIENDLY"  then -- friendly or better
    enabled_cc = db.CrowdControl.ShowFriendly
    
    local buff_aura_grid = (db.SwitchAreaByReaction and widget_frame.Debuffs) or widget_frame.Buffs
    local debuff_aura_grid = (db.SwitchAreaByReaction and widget_frame.Buffs) or widget_frame.Debuffs        
    
    self:UpdateUnitAuras(buff_aura_grid, unit, db.Buffs.ShowFriendly, false, self.FilterFriendlyBuffsBySpell, self.FilterFriendlyCrowdControlBySpell, "HELPFUL", db.Buffs.FilterMode)
    self:UpdateUnitAuras(debuff_aura_grid, unit, db.Debuffs.ShowFriendly, enabled_cc, self.FilterFriendlyDebuffsBySpell, self.FilterFriendlyCrowdControlBySpell, "HARMFUL", db.Debuffs.FilterMode)
  else
    enabled_cc = db.CrowdControl.ShowEnemy
    
    self:UpdateUnitAuras(widget_frame.Buffs, unit, db.Buffs.ShowEnemy, false, self.FilterEnemyBuffsBySpell, self.FilterEnemyCrowdControlBySpell, "HELPFUL", db.Buffs.FilterMode)
    self:UpdateUnitAuras(widget_frame.Debuffs, unit, db.Debuffs.ShowEnemy, enabled_cc, self.FilterEnemyDebuffsBySpell, self.FilterEnemyCrowdControlBySpell, "HARMFUL", db.Debuffs.FilterMode)
  end

  if AuraGridUpdateForUnitNotNecessary(widget_frame, unit) then return end

  if widget_frame.Buffs.ActiveAuras > 0 or widget_frame.Debuffs.ActiveAuras > 0 or widget_frame.CrowdControl.ActiveAuras > 0 then
    self:UpdatePositionAuraGrid(widget_frame, "Buffs", unit.style)
    self:UpdatePositionAuraGrid(widget_frame, "Debuffs", unit.style)

    if enabled_cc then
      self:UpdatePositionAuraGrid(widget_frame, "CrowdControl", unit.style)
      widget_frame.CrowdControl:Show()
    else
      widget_frame.CrowdControl:Hide()
    end

    widget_frame:Show()
  else
    widget_frame:Hide()
  end

  -- if unit_is_friendly and db.SwitchScaleByReaction then
  --   aura_grid_frame:SetHeight(ceil(auras_no / aura_grid.Columns) * (aura_grid.AuraHeight + aura_grid.AuraWidgetOffset) +
  --   aura_grid.RowSpacing + aura_grid.AuraWidgetOffset)
  -- end

  -- if unit_is_friendly then
  --   frame_auras_one, frame_auras_two = widget_frame.Buffs, widget_frame.Debuffs
  --   auras_one_active, auras_two_active = buffs_active, debuffs_active
  --   if db.SwitchScaleByReaction then
  --     scale_auras_one, scale_auras_two = db.Debuffs.Scale, db.Buffs.Scale
  --   else
  --     scale_auras_one, scale_auras_two = db.Buffs.Scale, db.Debuffs.Scale
  --   end
  -- else
  --   frame_auras_one, frame_auras_two = widget_frame.Debuffs, widget_frame.Buffs
  --   auras_one_active, auras_two_active = debuffs_active, buffs_active
  --   scale_auras_one, scale_auras_two = db.Debuffs.Scale, db.Buffs.Scale
  -- end

  -- if unit_is_friendly and db.SwitchScaleByReaction then
  --   print (unit.name, "=> Switch By Reaction")
  --   -- self:ResizeAurasOfAuraGrid(widget_frame, "Buffs", "Debuffs") 
  --   -- self:ResizeAurasOfAuraGrid(widget_frame, "Debuffs", "Buffs")
  --   self:ResizeAurasOfAuraGrid(self.Buffs, widget_frame.Debuffs)
  --   self:ResizeAurasOfAuraGrid(self.Debuffs, widget_frame.Buffs)

  --   widget_frame.IsSwitchedByReaction = true
  -- else
  --   widget_frame.IsSwitchedByReaction = false
  -- end
end

function Widget:UpdateAuras(widget_frame, unit)
  if not IgnoreAuraUpdateForUnit(widget_frame, unit) then 
    self:UpdateAurasGrids(widget_frame, unit)
 end
end

---------------------------------------------------------------------------------------------------
-- Creation and update functions
---------------------------------------------------------------------------------------------------

local function OnUpdateAuraGridFrame(self, elapsed)
  -- Update the number of seconds since the last update
  self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed

  if self.TimeSinceLastUpdate >= self.AuraGrid.UpdateInterval then
    self.TimeSinceLastUpdate = 0

    local aura_frame
    for i = 1, self.ActiveAuras do
      aura_frame = self.AuraFrames[i]
      self.AuraGrid:UpdateWidgetTime(aura_frame, aura_frame.AuraData.expirationTime, aura_frame.AuraData.duration)
    end
  end
end

function Widget:UpdateAuraGridLayout(widget_frame, aura_type)
  local aura_grid = self[aura_type]
  local aura_grid_frame = widget_frame[aura_type]
  local aura_frame_list = aura_grid_frame.AuraFrames

  local no_auras = #aura_frame_list

  -- If the number of auras to show was decreased, remove any overflow aura frames
  if no_auras > aura_grid.MaxAuras then
    for i = no_auras, aura_grid.MaxAuras + 1, -1 do
      aura_frame_list[i]:Hide()
      aura_frame_list[i] = nil
    end
    no_auras = aura_grid.MaxAuras
  end

  -- When called from Create(), #aura_frame_list is 0, so nothing will be done here
  -- When called from after a settings update, delete aura frames with wrong layout (icon/bar mode) and update all other aura frames
  local icon_mode = aura_grid.IconMode
  local aura_frame
  for i = no_auras, 1, -1 do
    aura_frame = aura_frame_list[i]
    if icon_mode then
      if aura_frame.Border then
        aura_grid:UpdateAuraFramePosition(aura_frame_list, aura_grid_frame, aura_frame, i)
        aura_grid:UpdateAuraFrame(aura_frame)
      else
        aura_frame:Hide()
        aura_frame_list[i] = nil
      end
    else
      if aura_frame.Statusbar then
        aura_grid:UpdateAuraFramePosition(aura_frame_list, aura_grid_frame, aura_frame, i)
        aura_grid:UpdateAuraFrame(aura_frame)
      else
        aura_frame:Hide()
        aura_frame_list[i] = nil
      end
    end
  end

  aura_grid_frame:SetSize(aura_grid.AuraWidgetWidth, aura_grid.AuraWidgetHeight)

  if ShowDuration or not aura_grid.IconMode then
    aura_grid_frame:SetScript("OnUpdate", OnUpdateAuraGridFrame)
  else
    aura_grid_frame:SetScript("OnUpdate", nil)
  end

  aura_grid_frame:SetFrameLevel(widget_frame:GetFrameLevel())
end

-- Initialize the aura grid layout, don't update auras themselves as not unitid know at this point
function Widget:UpdateLayout(widget_frame)
  local frame_level
  if self.db.FrameOrder == "HEALTHBAR_AURAS" then
    frame_level = widget_frame:GetParent():GetFrameLevel() + 1
  else
    frame_level = widget_frame:GetParent():GetFrameLevel() + 9
  end
  widget_frame:SetFrameLevel(frame_level)

  -- ClearAllPoints here as otherwise Lua errors might occur if the old anchoring and the new anchoring
  -- are cyclic temporarily
  widget_frame.Buffs:ClearAllPoints()
  widget_frame.Debuffs:ClearAllPoints()
  widget_frame.CrowdControl:ClearAllPoints()
  
  self:UpdateAuraGridLayout(widget_frame, "Buffs")
  self:UpdateAuraGridLayout(widget_frame, "Debuffs")
  self:UpdateAuraGridLayout(widget_frame, "CrowdControl")
end

function Widget:PLAYER_TARGET_CHANGED()
  if not self.db.ShowTargetOnly then return end

  if self.CurrentTarget then
    self.CurrentTarget:Hide()
    self.CurrentTarget = nil
  end

  local plate = GetNamePlateForUnit("target")
  if plate and plate.TPFrame.Active then
    self.CurrentTarget = plate.TPFrame.widgets.Auras

    if self.CurrentTarget.Active then
      self:UpdateAuras(self.CurrentTarget, plate.TPFrame.unit)
    end
  end
end


function Widget:PLAYER_REGEN_ENABLED()
  -- It seems that unitid here can be nil when using the healthstone while in combat
  -- assert (unit.unitid ~= nil, "Auras: PLAYER_REGEN_ENABLED - unitid =", unit.unitid)

  for unitid, tp_frame in Addon:GetActiveThreatPlates() do
    local widget_frame = self:GetWidgetFrameForUnit(unitid)
    if widget_frame then 
      local unit = tp_frame.unit
      if unit.HasUnlimitedAuras then
        self:UpdateAuras(widget_frame, unit)
      end
    end
  end
end

Widget.PLAYER_REGEN_DISABLED = Widget.PLAYER_REGEN_ENABLED

---------------------------------------------------------------------------------------------------
-- Auras Area
---------------------------------------------------------------------------------------------------

local function CreateAuraGrid(self, parent)
  local aura_grid_frame = _G.CreateFrame("Frame", nil, parent)
  aura_grid_frame.AuraFrames = {}
  aura_grid_frame.ActiveAuras = 0
  aura_grid_frame.AuraGrid = self

  return aura_grid_frame
end

local function HideNonActiveAuras(self, aura_grid_frame, stop_highlight)
  local aura_frames = aura_grid_frame.AuraFrames
  for i = aura_grid_frame.ActiveAuras + 1, #aura_frames do
    aura_frames[i]:Hide()
    if stop_highlight then
      AuraHighlightStop(aura_frames[i].Highlight)
    end
  end
end

local function UpdateAuraFramePosition(self, aura_frame_list, aura_grid_frame, aura_frame, no)
  local align_layout = self.AlignLayout
  aura_frame:ClearAllPoints()
  if no == 1 then
    aura_frame:SetPoint(align_layout[3], aura_grid_frame, self.AuraWidgetOffset * align_layout[5], (self.AuraWidgetOffset + self.RowSpacing) * align_layout[6])
  elseif (no - 1) % self.Columns == 0 then
    aura_frame:SetPoint(align_layout[3], aura_frame_list[no - self.Columns], align_layout[4], 0, self.RowSpacing * align_layout[6])
  else
    aura_frame:SetPoint(align_layout[1], aura_frame_list[no - 1], align_layout[2], self.ColumnSpacing * align_layout[5], 0)
  end
end

local function GetAuraFrame(self, aura_grid_frame, no)
  local aura_frame_list = aura_grid_frame.AuraFrames

  local aura_frame = aura_frame_list[no]
  if aura_frame == nil then
    -- Should always be #aura_frame_list + 1
    aura_frame = self:CreateAuraFrame(aura_grid_frame)

    self:UpdateAuraFramePosition(aura_frame_list, aura_grid_frame, aura_frame, no)
    self:UpdateAuraFrame(aura_frame)

    aura_frame_list[no] = aura_frame
  end

  return aura_frame
end

---------------------------------------------------------------------------------------------------
-- Functions for the aura grid with icons
---------------------------------------------------------------------------------------------------

local function CreateAuraFrameIconMode(self, parent)
  local frame = _G.CreateFrame("Frame", nil, parent)
  frame:SetFrameLevel(parent:GetFrameLevel())

  frame.Icon = frame:CreateTexture(nil, "ARTWORK", nil, -5)
  frame.Border = _G.CreateFrame("Frame", nil, frame, BackdropTemplate)
  frame.Border:SetFrameLevel(parent:GetFrameLevel())
  frame.Cooldown = Addon.CreateCooldown(frame, HideOmniCC)

  frame.Highlight = _G.CreateFrame("Frame", nil, frame)
  frame.Highlight:SetFrameLevel(parent:GetFrameLevel())
  frame.Highlight:SetPoint("CENTER")

  -- Use a seperate frame for text elements as a) using frame as parent results in the text being shown below
  -- the cooldown frame and b) using the cooldown frame results in the text not being visible if there is no
  -- cooldown (i.e., duration and expiration are nil which is true for auras with unlimited duration)
  local text_frame = _G.CreateFrame("Frame", nil, frame)
  text_frame:SetFrameLevel(parent:GetFrameLevel())
  text_frame:SetAllPoints(frame.Icon)
  frame.Stacks = text_frame:CreateFontString(nil, "OVERLAY")
  frame.TimeLeft = text_frame:CreateFontString(nil, "OVERLAY")

  frame:Hide()

  return frame
end

local function UpdateAuraFrameIconMode(self, frame)
  local db = self.db_widget

  frame.Cooldown:SetShownSwipe(db.ShowCooldownSpiral, HideOmniCC)
  if ShowDuration then
    frame.TimeLeft:Show()
  else
    frame.TimeLeft:Hide()
  end

  -- Add tooltips to icons

  if db.ShowTooltips then
    frame:SetScript("OnEnter", AuraFrameOnEnter)
    frame:SetScript("OnLeave", AuraFrameOnLeave)
  else
    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)
  end
  -- Setting the OnEnter/Leave, OnMouseDown/Up script automatically implies EnableMouse(true)
  -- And with that, right clicking and moving the camera does not work anymore when hovering over an aura.
  frame:EnableMouse(false)
  frame:SetMouseMotionEnabled(true)

  db = self.db

  -- Icon
  frame:SetSize(db.IconWidth, db.IconHeight)
  frame.Icon:SetAllPoints(frame)
  --frame.Icon:SetTexCoord(.07, 1-.07, .23, 1-.23) -- Style: Widee
  frame.Icon:SetTexCoord(.10, 1-.07, .12, 1-.12)  -- Style: Square - remove border from icons

  if db.ShowBorder then
    local offset, edge_size, inset = 2, 8, 0
    frame.Border:ClearAllPoints()
    frame.Border:SetPoint("TOPLEFT", frame, "TOPLEFT", -offset, offset)
    frame.Border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offset, -offset)
    frame.Border:SetBackdrop({
      edgeFile = Widget.TEXTURE_BORDER,
      edgeSize = edge_size,
      insets = { left = inset, right = inset, top = inset, bottom = inset },
    })
    frame.Border:SetBackdropBorderColor(0, 0, 0, 1)
    frame.Border:Show()

  else
    frame.Border:Hide()
  end

  AuraHighlightStopPrevious(frame.Highlight)
  if AuraHighlightEnabled then
    frame.Highlight:SetSize(frame:GetWidth() + AuraHighlightOffset, frame:GetHeight() + AuraHighlightOffset)
  end

  FontUpdateText(frame, frame.TimeLeft, db.Duration)
  FontUpdateText(frame, frame.Stacks, db.StackCount)
end

local function UpdateAuraInformationIconMode(self, aura_frame) -- texture, duration, expiration, stacks, color, name)
  local duration = aura_frame.AuraData.duration
  local expiration = aura_frame.AuraData.expirationTime
  local stacks = aura_frame.AuraData.applications
  local color = aura_frame.AuraData.color
  
  -- Expiration
  self:UpdateWidgetTime(aura_frame, expiration, duration)

  local db_widget = self.db_widget
  if db_widget.ShowStackCount then
    local stacks = C_UnitAuras.GetAuraApplicationDisplayCount(aura_frame.unitid, aura_frame.AuraData.auraInstanceID)
    aura_frame.Stacks:SetText(stacks)
    aura_frame.Stacks:Show()
  else
    aura_frame.Stacks:Hide()
  end

  aura_frame.Icon:SetTexture(aura_frame.AuraData.icon)

  -- Highlight Coloring
  if self.db.ShowBorder then
    if db_widget.ShowAuraType then
      -- local dispel_type = DISPELL_TYPE_NAME[aura_frame.AuraData.dispelName]
      -- print("Dispel Type:", aura_frame.AuraData.dispelName, dispel_type)
      -- if aura_frame.AuraData.dispelName then
      --   aura_frame.Border:SetBackdropBorderColor(DispelColorCurve:Evaluate(DISPELL_TYPE_NAME[aura_frame.AuraData.dispelType]))
        aura_frame.Border:SetBackdropBorderColor(color.r, color.g, color.b, 1)
      -- end
    end
  end

  if not IsSecretValue(duration) then
    if AuraHighlightEnabled then
      if aura_frame.AuraData.isStealable then
        AuraHighlightStart(aura_frame.Highlight, AuraHighlightColor, 0)
      else
        AuraHighlightStop(aura_frame.Highlight)
      end
    end
    
    aura_frame.Cooldown:Set(expiration - duration, duration + .25)
    AnimationStopFlash(aura_frame)
  end
  
  aura_frame:Show()
end

-- local AbbrevOptions = {
--    breakpointData= {
--       {breakpoint = 3600, fractionDivisor = 3600, significandDivisor = 1/1, abbreviation = "", abbreviationIsGlobal = false}, 
--       {breakpoint = 60, fractionDivisor = 60, significandDivisor = 1/1, abbreviation = "", abbreviationIsGlobal = false},
--       {breakpoint = 0, fractionDivisor = 1, significandDivisor = 1/1, abbreviation = "", abbreviationIsGlobal = false}
-- }}

-- local AbbrevOptionsUnit = {
--    breakpointData= {
--       {breakpoint = 3600, fractionDivisor = 3600, significandDivisor = 1/1, abbreviation = "h", abbreviationIsGlobal = false}, 
--       {breakpoint = 60, fractionDivisor = 60, significandDivisor = 1/1, abbreviation = "m", abbreviationIsGlobal = false},
--       {breakpoint = 0, fractionDivisor = 1, significandDivisor = 1/1, abbreviation = "", abbreviationIsGlobal = false}
-- }}

-- local function GetAbbreviatedTime(seconds)
--   return AbbreviateNumbers(seconds, AbbrevOptions)
-- end

-- local TimeFormatter = CreateFromMixins(SecondsFormatterMixin)
-- TimeFormatter:Init(0, SecondsFormatter.Abbreviation.OneLetter, false, true)
-- TimeFormatter:Init(
--   SecondsFormatterConstants.ZeroApproximationThreshold,
--   SecondsFormatter.Abbreviation.OneLetter,
--   SecondsFormatterConstants.DontRoundUpLastUnit,
--   SecondsFormatterConstants.ConvertToLower,
--   SecondsFormatterConstants.RoundUpIntervals)
-- TimeFormatter:SetDesiredUnitCount(1)
-- TimeFormatter:SetMinInterval(SecondsFormatter.Interval.Minutes)
-- TimeFormatter:SetStripIntervalWhitespace(true)

local function UpdateWidgetTimeIconMode(self, aura_frame, expiration, duration)
  local timeleft = C_UnitAuras.GetAuraDuration(aura_frame.unitid, aura_frame.AuraData.auraInstanceID)
  if timeleft then
    aura_frame.TimeLeft:SetAlphaFromBoolean(timeleft:IsZero(), 0, 1)
    -- -- "%.1f"    
    aura_frame.TimeLeft:SetFormattedText("%d", timeleft:GetRemainingDuration())

    -- Unit is hostile and debuff - short duration format
    -- if (UnitReaction("player", aura_frame.unitid) < 5) and aura_frame.isHarmful then
    -- -- "%.1f"    
    --   aura_frame.TimeLeft:SetFormattedText("%d", timeleft:GetRemainingDuration())
    -- else
    --   aura_frame.TimeLeft:SetText(TimeFormatter:Format(timeleft:GetRemainingDuration(), false, true))
    -- end

    aura_frame.Cooldown:SetCooldownFromDurationObject(timeleft)
  else
    aura_frame.TimeLeft:SetText()
  end

  -- AnimationStopFlash(aura_frame)
  -- local db_widget = self.db_widget
  -- if db_widget.FlashWhenExpiring and timeleft < db_widget.FlashTime then
  --   AnimationFlash(aura_frame)
  -- end
end

---------------------------------------------------------------------------------------------------
-- Functions for the aura grid with bars
---------------------------------------------------------------------------------------------------

local function CreateAuraFrameBarMode(self, parent)
  local db = self.db
  local font = Addon.LibSharedMedia:Fetch('font', db.Font)

  -- frame is probably not necessary, should be ok do add everything to the statusbar frame
  local frame = _G.CreateFrame("Frame", nil, parent)
  frame:SetFrameLevel(parent:GetFrameLevel())

  frame.Statusbar = _G.CreateFrame("StatusBar", nil, frame)
  frame.Statusbar:SetFrameLevel(parent:GetFrameLevel())
  frame.Statusbar:SetMinMaxValues(0, 100)

  frame.Background = frame.Statusbar:CreateTexture(nil, "BACKGROUND", nil, 0)
  frame.Background:SetAllPoints()

  frame.Highlight = _G.CreateFrame("Frame", nil, frame)
  frame.Highlight:SetFrameLevel(parent:GetFrameLevel())

  frame.Icon = frame:CreateTexture(nil, "ARTWORK", nil, -5)

  frame.Stacks = frame.Statusbar:CreateFontString(nil, "OVERLAY")
  frame.Stacks:SetAllPoints(frame.Icon)
  --frame.Stacks:SetFont("Fonts\\FRIZQT__.TTF", 11)

  frame.LabelText = frame.Statusbar:CreateFontString(nil, "OVERLAY")
  frame.LabelText:SetAllPoints(frame.Statusbar)
  frame.TimeText = frame.Statusbar:CreateFontString(nil, "OVERLAY")
  frame.TimeText:SetAllPoints(frame.Statusbar)

  frame.Cooldown = Addon.CreateCooldown(frame, HideOmniCC)

  frame:Hide()

  return frame
end

local function UpdateAuraFrameBarMode(self, frame)
  local db = self.db_widget

  frame.Cooldown:SetShownSwipe(db.ShowCooldownSpiral, HideOmniCC)
  if ShowDuration then
    frame.TimeText:Show()
  else
    frame.TimeText:Hide()
  end

  -- Add tooltips to icons
  if db.ShowTooltips then
    frame:SetScript("OnEnter", AuraFrameOnEnter)
    frame:SetScript("OnLeave", AuraFrameOnLeave)
  else
    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)
  end
  -- Setting the OnEnter/Leave, OnMouseDown/Up script automatically implies EnableMouse(true)
  -- And with that, right clicking and moving the camera does not work anymore when hovering over an aura.
  frame:EnableMouse(false)
  frame:SetMouseMotionEnabled(true)

  db = self.db
  local font = Addon.LibSharedMedia:Fetch('font', db.Font)

  -- width and position calculations
  local frame_width = db.BarWidth
  if db.ShowIcon then
    frame_width = frame_width + db.BarHeight + db.IconSpacing
  end
  frame:SetSize(frame_width, db.BarHeight)

  frame.Background:SetTexture(Addon.LibSharedMedia:Fetch('statusbar', db.BackgroundTexture))
  frame.Background:SetVertexColor(db.BackgroundColor.r, db.BackgroundColor.g, db.BackgroundColor.b, db.BackgroundColor.a)

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

    FontUpdateText(frame.Icon, frame.Stacks, db.StackCount)

    frame.Icon:SetTexCoord(0, 1, 0, 1)
    frame.Icon:SetSize(db.BarHeight, db.BarHeight)
    frame.Icon:Show()
  else
    frame.Statusbar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.Icon:Hide()
  end

  FontUpdateText(frame.Statusbar, frame.LabelText, db.Label)
  FontUpdateText(frame.Statusbar, frame.TimeText, db.Duration)

  AuraHighlightStopPrevious(frame.Highlight)
  if AuraHighlightEnabled then
    local aura_highlight = frame.Highlight

    aura_highlight:ClearAllPoints()
    if self.db_widget.Highlight.Type == "ActionButton" then
      -- Align to icon because of bad scaling otherwise
      local offset = - (AuraHighlightOffset * 0.5)
      if db.IconAlignmentLeft then
        aura_highlight:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", offset, offset)
      else
        aura_highlight:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", db.BarWidth + db.IconSpacing + offset, offset)
      end
      aura_highlight:SetSize(db.BarHeight + AuraHighlightOffset, db.BarHeight + AuraHighlightOffset)
    else
      aura_highlight:SetPoint("CENTER")
      aura_highlight:SetSize(frame:GetWidth() + AuraHighlightOffset, frame:GetHeight() + AuraHighlightOffset)
    end
  end

  frame.Statusbar:SetSize(db.BarWidth, db.BarHeight)
  frame.Statusbar:SetStatusBarTexture(Addon.LibSharedMedia:Fetch('statusbar', db.Texture))
  frame.Statusbar:GetStatusBarTexture():SetHorizTile(false)
  frame.Statusbar:GetStatusBarTexture():SetVertTile(false)
end

local function UpdateAuraInformationBarMode(self, aura_frame) -- texture, duration, expiration, stacks, color, name)
  local db = self.db

  local duration = aura_frame.AuraData.duration
  local expiration = aura_frame.AuraData.expirationTime
  local stacks = aura_frame.AuraData.applications
  local color = aura_frame.AuraData.color

  -- Expiration
  self:UpdateWidgetTime(aura_frame, expiration, duration)

  if self.db_widget.ShowStackCount then
    local stacks = C_UnitAuras.GetAuraApplicationDisplayCount(aura_frame.unitid, aura_frame.AuraData.auraInstanceID)
    
     -- Stacks are either shown on the icon or as postfix to the aura name when
    -- a) OmniCC is enabled (which shows the CD on the icon) or the icon is disabled
    if not db.ShowIcon or not HideOmniCC then
      aura_frame.Stacks:Hide()
      aura_frame.AuraData.name = aura_frame.AuraData.name .. " (" .. stacks .. ")"
    else
      aura_frame.Stacks:SetText(stacks)
      aura_frame.Stacks:Show()
    end
  else
    aura_frame.Stacks:Hide()
  end

  -- Icon
  if db.ShowIcon then
    aura_frame.Icon:SetTexture(aura_frame.AuraData.icon)
  end

  if AuraHighlightEnabled then
    if aura_frame.AuraData.isStealable then
      AuraHighlightStart(aura_frame.Highlight, AuraHighlightColor, 0)
    else
      AuraHighlightStop(aura_frame.Highlight)
    end
  end

  aura_frame.LabelText:SetText(aura_frame.AuraData.name)
  -- Highlight Coloring
  aura_frame.Statusbar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)

  aura_frame.Cooldown:Set(duration, expiration)
  AnimationStopFlash(aura_frame)

  aura_frame:Show()
end

local function UpdateWidgetTimeBarMode(self, aura_frame, expiration, duration)
  local timeleft = C_UnitAuras.GetAuraDuration(aura_frame.unitid, aura_frame.AuraData.auraInstanceID)
  if timeleft then
    aura_frame.TimeText:SetAlphaFromBoolean(timeleft:IsZero(), 0, 1)

    if timeleft:GetTotalDuration() == 0 then
      aura_frame.Statusbar:SetValue(100)
      --AnimationStopFlash(aura_frame)
    -- elseif expiration == 0 then
    --   aura_frame.TimeText:SetText("")
    --   aura_frame.Statusbar:SetValue(0)
      --AnimationStopFlash(aura_frame)
    else
      local db = self.db_widget

      
      if db.ShowDuration then
        aura_frame.TimeText:SetFormattedText("%d", timeleft:GetRemainingDuration())
      else
        aura_frame.TimeText:SetText()
      end
      -- if db.FlashWhenExpiring and timeleft < db.FlashTime then
      --   AnimationFlash(aura_frame)
      -- end

      aura_frame.Statusbar:SetTimerDuration(timeleft, 0)
    end
  else
    aura_frame.TimeText:SetText()
  end
end

local function UpdateWidgetTimeBarModeNoDuration(self, aura_frame, expiration, duration)
  if duration == 0 then
    aura_frame.Statusbar:SetValue(100)
    --AnimationStopFlash(aura_frame)
  elseif expiration == 0 then
    aura_frame.Statusbar:SetValue(0)
    --AnimationStopFlash(aura_frame)
  else
    local timeleft = expiration - GetTime()
    if timeleft > 60 then
      aura_frame.TimeText:SetText(floor(timeleft/60).."m")
    else
      aura_frame.TimeText:SetText(floor(timeleft))
    end

    local db = self.db_widget
    if db.FlashWhenExpiring and timeleft < db.FlashTime then
      Animation:Flash(aura_frame)
    end

    aura_frame.Statusbar:SetValue(timeleft * 100 / duration)
  end
end

---------------------------------------------------------------------------------------------------
--    if frame and frame.Active then
--      local widget_frame = frame.widgets.Auras
--      local unit = frame.unit
--
--      if widget_frame.Active and unit.HasUnlimitedAuras then
--        unit.InCombat = _G.UnitAffectingCombat(unit.unitid)
--        self:UpdateIconGrid(widget_frame, unit)
--      end
--    end
--  end
--end
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = _G.CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------
  widget_frame:SetAllPoints(tp_frame)

  widget_frame.Buffs = self.Buffs:Create(widget_frame)
  widget_frame.Debuffs = self.Debuffs:Create(widget_frame)
  widget_frame.CrowdControl = self.CrowdControl:Create(widget_frame)

  widget_frame.Widget = self

  self:UpdateLayout(widget_frame)

  widget_frame:HookScript("OnShow", OnShowHookScript)
  -- widget_frame:HookScript("OnHide", OnHideHookScript)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  self.db = Addon.db.profile.AuraWidget
  return self.db.ON or self.db.ShowInHeadlineView
end

function Widget:OnEnable()
  self:SubscribeEvent("PLAYER_TARGET_CHANGED")
  self:SubscribeEvent("PLAYER_REGEN_ENABLED")
  self:SubscribeEvent("PLAYER_REGEN_DISABLED")
  self:SubscribeEvent("UNIT_AURA")
  -- LOSS_OF_CONTROL_ADDED
  -- LOSS_OF_CONTROL_UPDATE
end

function Widget:OnDisable()
  self:UnsubscribeAllEvents()

  for _, plate in pairs(GetNamePlates()) do
    local tp_frame = plate and plate.TPFrame
    if tp_frame and tp_frame.Active then
      tp_frame.widgets.Auras:UnsubscribeAllEvents()
    end
  end
end

function Widget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return self.db.ShowInHeadlineView or Addon.ActiveAuraTriggers
  elseif style ~= "etotem" then
    return self.db.ON or Addon.ActiveAuraTriggers
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  local db = self.db

  -- if db.SwitchScaleByReaction and UnitReaction("player", unit.unitid) > 4 then
  --   print ("Scale: Buffs =", self.SwitchScaleBuffsFactor, "- Debuffs =", self.SwitchScaleDebuffsFactor)
  --   widget_frame.Buffs:SetScale(self.SwitchScaleBuffsFactor)
  --   widget_frame.Debuffs:SetScale(self.SwitchScaleDebuffsFactor)
  -- else
  --   widget_frame.Buffs:SetScale(1)
  --   widget_frame.Debuffs:SetScale(1)
  -- end
  
  self:UpdateAuras(widget_frame, unit)
end

-- function Widget:OnUnitRemoved(widget_frame, unit)
-- end

local function ParseFilter(filter_by_spell)
  local filter = {}
  local only_player_auras = true

  local modifier, spell
  for key, value in pairs(filter_by_spell) do
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

  return filter
end

function Widget:ParseSpellFilters()
  self.db = Addon.db.profile.AuraWidget

  self.AuraFilterBuffs = ParseFilter(self.db.Buffs.FilterBySpell)
  self.AuraFilterDebuffs = ParseFilter(self.db.Debuffs.FilterBySpell)
  self.AuraFilterCrowdControl = ParseFilter(self.db.CrowdControl.FilterBySpell)
end

-- function Widget:UpdateSizeDataIconMode(aura_grid, db)
--   aura_grid.AuraWidth = db.IconWidth + db.ColumnSpacing
--   aura_grid.AuraHeight = db.IconHeight + db.RowSpacing
--   aura_grid.RowSpacing = db.RowSpacing
--   aura_grid.ColumnSpacing = db.ColumnSpacing

--   aura_grid.AuraWidgetWidth = (db.IconWidth * db.Columns) + (db.ColumnSpacing * db.Columns) - db.ColumnSpacing + (aura_grid.AuraWidgetOffset * 2)
--   aura_grid.AuraWidgetHeight = (db.IconHeight * db.Rows) + (db.RowSpacing * db.Rows) - db.RowSpacing + (aura_grid.AuraWidgetOffset * 2)

--   for i = 1, db.Columns do
--     local active_auras_width = (db.IconWidth * i) + (db.ColumnSpacing * i) - db.ColumnSpacing + (aura_grid.AuraWidgetOffset * 2)
--     aura_grid.CenterAurasPositions[i] = (aura_grid.AuraWidgetWidth - active_auras_width) / 2
--   end
-- end

function Widget:UpdateSettingsIconMode(aura_type, filter)
  local aura_grid = self[aura_type]

  local db = self.db[aura_type].ModeIcon
  aura_grid.db = db
  aura_grid.db_widget = self.db

  aura_grid.UpdateInterval = Addon.ON_UPDATE_INTERVAL
  aura_grid.AlignLayout = GRID_LAYOUT[self.db[aura_type].AlignmentH][self.db[aura_type].AlignmentV]

  aura_grid.Columns = db.Columns
  aura_grid.MaxAuras = min(db.MaxAuras, db.Rows * db.Columns)

  aura_grid.AuraWidgetOffset = (self.db.ShowAuraType and 2) or 1

  aura_grid.AuraWidth = db.IconWidth + db.ColumnSpacing
  aura_grid.AuraHeight = db.IconHeight + db.RowSpacing
  aura_grid.RowSpacing = db.RowSpacing
  aura_grid.ColumnSpacing = db.ColumnSpacing

  aura_grid.AuraWidgetWidth = (db.IconWidth * db.Columns) + (db.ColumnSpacing * db.Columns) - db.ColumnSpacing + (aura_grid.AuraWidgetOffset * 2)
  aura_grid.AuraWidgetHeight = (db.IconHeight * db.Rows) + (db.RowSpacing * db.Rows) - db.RowSpacing + (aura_grid.AuraWidgetOffset * 2)

  for i = 1, db.Columns do
    local active_auras_width = (db.IconWidth * i) + (db.ColumnSpacing * i) - db.ColumnSpacing + (aura_grid.AuraWidgetOffset * 2)
    aura_grid.CenterAurasPositions[i] = (aura_grid.AuraWidgetWidth - active_auras_width) / 2
  end

  aura_grid.CreateAuraFrame = CreateAuraFrameIconMode
  aura_grid.UpdateAuraFrame = UpdateAuraFrameIconMode
  aura_grid.UpdateAuraInformation = UpdateAuraInformationIconMode
  aura_grid.UpdateWidgetTime = UpdateWidgetTimeIconMode

  aura_grid.Create = CreateAuraGrid
  aura_grid.GetAuraFrame = GetAuraFrame
  aura_grid.UpdateAuraFramePosition = UpdateAuraFramePosition
  aura_grid.HideNonActiveAuras = HideNonActiveAuras
end


-- function Widget:UpdateSizeDataBarMode(aura_grid, db)
--   aura_grid.AuraWidth = db.BarWidth
--   aura_grid.AuraHeight = db.BarHeight + db.BarSpacing
--   aura_grid.RowSpacing = db.BarSpacing
--   aura_grid.ColumnSpacing = 0

--   if db.ShowIcon then
--     aura_grid.AuraWidgetWidth = db.BarWidth + db.BarHeight + db.IconSpacing
--   else
--     aura_grid.AuraWidgetWidth = db.BarWidth
--   end
--   aura_grid.AuraWidgetHeight = (db.BarHeight * db.MaxBars) + (db.BarSpacing * db.MaxBars) - db.BarSpacing + (aura_grid.AuraWidgetOffset * 2)
-- end

function Widget:UpdateSettingsBarMode(aura_type, filter)
  local aura_grid = self[aura_type]

  local db = self.db[aura_type].ModeBar
  aura_grid.db = db
  aura_grid.db_widget = self.db

  aura_grid.UpdateInterval = 1 / GetFramerate()
  aura_grid.AlignLayout = GRID_LAYOUT[self.db[aura_type].AlignmentH][self.db[aura_type].AlignmentV]

  aura_grid.Columns = 1
  aura_grid.MaxAuras = db.MaxBars

  aura_grid.AuraWidgetOffset = 0

  aura_grid.AuraWidth = db.BarWidth
  aura_grid.AuraHeight = db.BarHeight + db.BarSpacing
  aura_grid.RowSpacing = db.BarSpacing
  aura_grid.ColumnSpacing = 0

  if db.ShowIcon then
    aura_grid.AuraWidgetWidth = db.BarWidth + db.BarHeight + db.IconSpacing
  else
    aura_grid.AuraWidgetWidth = db.BarWidth
  end
  aura_grid.AuraWidgetHeight = (db.BarHeight * db.MaxBars) + (db.BarSpacing * db.MaxBars) - db.BarSpacing + (aura_grid.AuraWidgetOffset * 2)

  aura_grid.CreateAuraFrame = CreateAuraFrameBarMode
  aura_grid.UpdateAuraFrame = UpdateAuraFrameBarMode
  aura_grid.UpdateAuraInformation = UpdateAuraInformationBarMode

  if ShowDuration then
    aura_grid.UpdateWidgetTime = UpdateWidgetTimeBarMode
  else
    aura_grid.UpdateWidgetTime = UpdateWidgetTimeBarMode
  end

  aura_grid.Create = CreateAuraGrid
  aura_grid.GetAuraFrame = GetAuraFrame
  aura_grid.UpdateAuraFramePosition = UpdateAuraFramePosition
  aura_grid.HideNonActiveAuras = HideNonActiveAuras
end

-- Load settings from the configuration which are shared across all aura widgets
-- used (for each widget) in UpdateWidgetConfig
function Widget:UpdateSettings()
  self.db = Addon.db.profile.AuraWidget

  self.Buffs.IconMode = not self.db.Buffs.ModeBar.Enabled
  self.Debuffs.IconMode = not self.db.Debuffs.ModeBar.Enabled
  self.CrowdControl.IconMode = not self.db.CrowdControl.ModeBar.Enabled

  if self.Buffs.IconMode then
    self:UpdateSettingsIconMode("Buffs")
  else
    self:UpdateSettingsBarMode("Buffs")
  end

  if self.Debuffs.IconMode then
    self:UpdateSettingsIconMode("Debuffs")
  else
    self:UpdateSettingsBarMode("Debuffs")
  end

  if self.CrowdControl.IconMode then
    self:UpdateSettingsIconMode("CrowdControl")
  else
    self:UpdateSettingsBarMode("CrowdControl")
  end

  -- local buffs_size = (self.Buffs.IconMode and max(self.db.Buffs.ModeIcon.IconWidth, self.db.Buffs.ModeIcon.IconHeight)) or self.db.Buffs.ModeBar.BarHeight
  -- local debuffs_size = (self.Debuffs.IconMode and max(self.db.Debuffs.ModeIcon.IconWidth, self.db.Debuffs.ModeIcon.IconHeight)) or self.db.Debuffs.ModeBar.BarHeight

  -- self.SwitchScaleBuffsFactor = debuffs_size/ buffs_size
  -- self.SwitchScaleDebuffsFactor = buffs_size / debuffs_size

  self:ParseSpellFilters()

  SetNoCooldownCount = OmniCC and OmniCC.Cooldown and OmniCC.Cooldown.SetNoCooldownCount
  HideOmniCC = not self.db.ShowOmniCC  

  ShowDuration = self.db.ShowDuration and not self.db.ShowOmniCC
  --  -- Don't update any widget frame if the widget isn't enabled.
--  if not self:IsEnabled() then return end

  -- Highlighting
  AuraHighlightEnabled = self.db.Highlight.Enabled
  local glow_function = CUSTOM_GLOW_FUNCTIONS[self.db.Highlight.Type][1]
  AuraHighlightStart = CUSTOM_GLOW_WRAPPER_FUNCTIONS[glow_function] or Addon.LibCustomGlow[glow_function]
  AuraHighlightStopPrevious = AuraHighlightStop or Addon.LibCustomGlow.PixelGlow_Stop
  AuraHighlightStop = Addon.LibCustomGlow[CUSTOM_GLOW_FUNCTIONS[self.db.Highlight.Type][2]]
  AuraHighlightOffset = CUSTOM_GLOW_FUNCTIONS[self.db.Highlight.Type][3]

  local color = (self.db.Highlight.CustomColor and self.db.Highlight.Color) or Addon.DEFAULT_SETTINGS.profile.AuraWidget.Highlight.Color
  AuraHighlightColor[1] = color.r
  AuraHighlightColor[2] = color.g
  AuraHighlightColor[3] = color.b
  AuraHighlightColor[4] = color.a

  EnabledForStyle["NameOnly"] = self.db.ShowInHeadlineView
  EnabledForStyle["NameOnly-Unique"] = self.db.ShowInHeadlineView
  EnabledForStyle["dps"] = self.db.ON
  EnabledForStyle["tank"] = self.db.ON
  EnabledForStyle["normal"] = self.db.ON
  EnabledForStyle["totem"] = self.db.ON
  EnabledForStyle["unique"] = self.db.ON
  EnabledForStyle["etotem"] = false
  EnabledForStyle["empty"] = false

  local sort_function = SORT_FUNCTIONS[self.db.SortOrder]
  if sort_function then  
    SortFunction = sort_function[self.db.SortReverse and "Reverse" or "Default"]
  else
    SortFunction = nil
  end
end

---------------------------------------------------------------------------------------------------
-- Configuration Mode
---------------------------------------------------------------------------------------------------

local EnabledConfigMode = false
local OldUnitAura, OldProcessAllUnitAuras
local Timer

local ConfigModeAuras = {
  HARMFUL = {},
  HELPFUL = {}
}

local DEMO_AURA_ICONS = {
  Buffs = { 136085, 132179, 135869, 135962, 135902, 136205, 136114, 136148, 132333 },
  Debuffs = { 132122, 132212, 135812, 135959, 136207, 132273, 135813, 136118, 132155 },
  CrowdControl = { 132114, 132118, 136071, 135963, 136184, 136175, 135849, 136183, 132316 },
}

local function GenerateDemoAuras()
  for no = 1, 40 do
    -- aura.name, aura.icon, aura.applications, aura.dispelName, aura.duration, aura.expirationTime, aura.sourceUnit,
    -- aura.isStealable, aura.nameplateShowPersonal, aura.spellId, aura.canApplyAura, aura.isBossAura, _, aura.nameplateShowAll =
    local random_name = tostring(math.random(1, 40))

    local aura_duration = math.random(3, 120)
    local aura_expiration = GetTime() + aura_duration
    local aura_name, aura_texture, aura_stacks, aura_type, aura_caster, aura_spellid, aura_steal, aura_show_all
    if no % 2 == 0 then
      aura_name = "Rake" .. random_name
      aura_texture = DEMO_AURA_ICONS.Debuffs[math.random(1, #DEMO_AURA_ICONS.Debuffs)]
      aura_stacks, aura_type, aura_caster, aura_spellid, aura_steal, aura_show_all = 3, nil, "player", 1822, false, false
    else
      aura_name = "Bash" .. random_name
      aura_texture = DEMO_AURA_ICONS.CrowdControl[math.random(1, #DEMO_AURA_ICONS.CrowdControl)]
      aura_stacks, aura_type, aura_caster, aura_spellid, aura_steal, aura_show_all = 2, nil, "player", 5211, false, true
    end
    ConfigModeAuras.HARMFUL[no] = { aura_name, aura_texture, aura_stacks, aura_type, aura_duration, aura_expiration, aura_caster, aura_steal, false, aura_spellid, true, false, true, aura_show_all, 1 }

    aura_name = "Regrowth" .. random_name
    aura_expiration = GetTime() + aura_duration
    aura_texture = DEMO_AURA_ICONS.Buffs[math.random(1, #DEMO_AURA_ICONS.Buffs)]
    aura_stacks, aura_type, aura_caster, aura_spellid, aura_steal = 5, "Magic", "nameplate1", 8936, no % 5 == 0
    ConfigModeAuras.HELPFUL[no] = { aura_name, aura_texture, aura_stacks, aura_type, aura_duration, aura_expiration, aura_caster, aura_steal, false, aura_spellid, true, false, true, false, 1 }
  end
end

local function TimerCallback()
  for no = 40, 1, -1 do
    local aura = ConfigModeAuras.HARMFUL[no]
    if aura and aura[6] < GetTime() then
      table.remove(ConfigModeAuras.HARMFUL, no)
    end
    aura = ConfigModeAuras.HELPFUL[no]
    if aura and aura[6] < GetTime() then
      table.remove(ConfigModeAuras.HELPFUL, no)
    end
  end

  if #ConfigModeAuras.HARMFUL + #ConfigModeAuras.HELPFUL == 0 then
    GenerateDemoAuras()
  end

  for _, tp_frame in Addon:GetActiveThreatPlates() do
    Widget:UpdateAuras(tp_frame.widgets.Auras, tp_frame.unit)
  end
end

local function UnitAuraForConfigurationMode(unitid, i, effect)
  local aura = ConfigModeAuras[effect][i]
  if aura then
    return unpack(aura)
  else
    return nil
  end
end

local function ProcessAllUnitAurasConfigMode(unitid, effect)
  local unit_auras = {}

  for i = 1, 40 do
    local aura = {}

    aura.name, aura.icon, aura.applications, aura.dispelName, aura.duration, aura.expirationTime, aura.sourceUnit,
      aura.isStealable, aura.nameplateShowPersonal, aura.spellId, aura.canApplyAura, aura.isBossAura, aura.castByPlayer, aura.nameplateShowAll =
      UnitAuraForConfigurationMode(unitid, i, effect)

    if aura.name then 
      aura.auraInstanceID = i
      unit_auras[#unit_auras + 1] = aura
    else
      break
    end
  end

  return unit_auras
end

local ProcessAllUnitAurasBackup

function Widget:ToggleConfigurationMode()
  if not EnabledConfigMode then
    EnabledConfigMode = true

    GenerateDemoAuras()
    ProcessAllUnitAurasBackup = ProcessAllUnitAuras
    ProcessAllUnitAuras = ProcessAllUnitAurasConfigMode

    Addon:ForceUpdate()
    Timer = C_Timer.NewTicker(0.5, TimerCallback)
  else
    EnabledConfigMode = false

    ProcessAllUnitAuras = ProcessAllUnitAurasBackup
    Timer:Cancel()

    Addon:ForceUpdate()
  end
end

local ProcessAllUnitAuras_NoDebug = ProcessAllUnitAuras

function Widget:PrintDebug(command)
  if command == "enable" then
    Addon.Logging.Debug("    Debugging mode enabled.")
    ProcessAllUnitAuras_NoDebug = ProcessAllUnitAuras
    ProcessAllUnitAuras = function(unitid, effect)
      local unit_auras = ProcessAllUnitAuras_NoDebug(unitid, effect)
      
      for k, aura in pairs(unit_auras) do
        if aura.sourceUnit == "player" then
          Addon.Logging.Debug("    Aura:", aura.name, "=> ID:", aura.spellId, "( Dispell:", aura.isStealable, ")")
        end
      end

      return unit_auras
    end
  else
    Addon.Logging.Debug("    Debugging mode disabled.")
    ProcessAllUnitAuras = ProcessAllUnitAuras_NoDebug
  end
end