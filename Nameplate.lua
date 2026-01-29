local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------------------------
-- Variables and References
---------------------------------------------------------------------------------------------------------------------

-- Lua APIs
local _
local type, select, pairs, tostring  = type, select, pairs, tostring 			    -- Local function copy
local max, gsub, tonumber, math_abs = math.max, string.gsub, tonumber, math.abs
local next = next

-- WoW APIs
local wipe, strsplit = wipe, strsplit
local WorldFrame, UIParent, INTERRUPTED = WorldFrame, UIParent, INTERRUPTED
local UnitExists, UnitName, UnitReaction, UnitClass, UnitPVPName = UnitExists, UnitName, UnitReaction, UnitClass, UnitPVPName
local UnitEffectiveLevel = UnitEffectiveLevel
local UnitChannelInfo, UnitPlayerControlled = UnitChannelInfo, UnitPlayerControlled
local UnitIsUnit, UnitIsPlayer = UnitIsUnit, UnitIsPlayer
local GetCreatureDifficultyColor, GetRaidTargetIndex = GetCreatureDifficultyColor, GetRaidTargetIndex
local GetTime, CombatLogGetCurrentEventInfo = GetTime, CombatLogGetCurrentEventInfo
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local IsInInstance, InCombatLockdown = IsInInstance, InCombatLockdown
local NamePlateDriverFrame, UnitNameplateShowsWidgetsOnly = NamePlateDriverFrame, UnitNameplateShowsWidgetsOnly
local GetSpecializationInfo, GetSpecialization = GetSpecializationInfo, GetSpecialization

-- ThreatPlates APIs
local L = Addon.L
local Widgets = Addon.Widgets
local CVars = Addon.CVars
local RegisterEvent, UnregisterEvent = Addon.EventService.RegisterEvent, Addon.EventService.UnregisterEvent
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish
local AnchorFrameTo = Addon.AnchorFrameTo
local IsSecretValue = Addon.IsSecretValue

local TransliterateCyrillicLetters = Addon.Localization.TransliterateCyrillicLetters
local SetNamesFonts = Addon.Font.SetNamesFonts
local StyleModule, ColorModule, ThreatModule = Addon.Style, Addon.Color, Addon.Threat
local ScalingModule, TransparencyModule = Addon.Scaling, Addon.Transparency

local ElementsPlateCreated, ElementsPlateUnitAdded, ElementsPlateUnitRemoved = Addon.Elements.PlateCreated, Addon.Elements.PlateUnitAdded, Addon.Elements.PlateUnitRemoved
local ElementsUpdateStyle, ElementsUpdateSettings = Addon.Elements.UpdateStyle, Addon.Elements.UpdateSettings
local BackdropTemplate = Addon.BackdropTemplate

local GetNameForNameplate
local UnitCastingInfo

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, UnitAffectingCombat, UnitCastingInfo, UnitClassification, UnitGUID, UnitHealth, UnitHealthMax, UnitIsTapDenied, UnitLevel, UnitSelectionColor

-- * Structure of Theat Plates UI elements
-- Modules
--   These are components that need to be called in a certain order, so they are called directly, e.g., from Nameplate.lua, but also from other files.  
--   Event handling for these components is centralized in Nameplate.lua.
-- Elements
--   These are UI elements that implement features of Threat Plates. It is not important in what order they are called as they do not depend on each other. 
--   They only depend on the core module (Nameplate.lua) and other modules. 
--   They can receive events, but only after the event was processed by core and modules.
--   The difference to widgets is that these elements are always created when a nameplate is created, although they might not be shown.
-- Widgets
--   Like elements, but widgets can be disabled (in which case they are not created and do not impact performance at all)
--   They can receive events, but only after the event was processed by core/modules and elements.

-- Constants
local CASTBAR_INTERRUPT_HOLD_TIME = Addon.CASTBAR_INTERRUPT_HOLD_TIME

local IGNORED_UNITS = {
  target = true,
  player = true,
  focus =  true,
  anyenemy = true,
  anyfriend = true,
  softenemy = true,
  softfriend = true,
  -- any/softinteract does not seem to be necessary here
}

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
--local PlateOnUpdateQueue = {}
local LastTargetPlate = {
  target = nil,
  softfriend = nil,
  softinteract = nil,
  softenemy = nil
}
local LastFocusPlate

-- External references to internal data
local PlatesCreated = Addon.PlatesCreated
local PlatesByUnit = Addon.PlatesByUnit
local PlatesByGUID = Addon.PlatesByGUID

---------------------------------------------------------------------------------------------------
-- Cached configuration settings (for performance reasons)
---------------------------------------------------------------------------------------------------
local SettingsShowEnemyBlizzardNameplates, SettingsShowFriendlyBlizzardNameplates, SettingsHideBuffsOnPersonalNameplate
local SettingsShowOnlyNames
local TargetStyleForEnemy, TargetStyleForFriend, TargetStyleForInteract
local ShowCastBars

---------------------------------------------------------------------------------------------------
-- Wrapper functions for WoW Classic
---------------------------------------------------------------------------------------------------

if Addon.IS_CLASSIC then
  GetNameForNameplate = function(plate) return plate:GetName():gsub("NamePlate", "Plate") end

    -- Fix for UnitChannelInfo not working on WoW Classic
  -- Based on code from LibClassicCasterino and ClassicCastbars
  local CHANNELED_SPELL_INFO_BY_ID = {
    -- DRUID
    [17401] = 10,  -- Hurricane
    [740] = 10,    -- Tranquility

    -- HUNTER
    [6197] = 60,     -- Eagle Eye
    [1002] = 60,     -- Eyes of the Beast
    [136] = 5,       -- Mend Pet
    [1515] = 20,     -- Tame Beast
    [1510] = 6,      -- Volley

    -- MAGE    
    [5143] = 5,       -- Arcane Missiles
    [7268] = 3,       -- Arcane Missiles
    [10] = 8,         -- Blizzard
    [12051] = 8,      -- Evocation
    [401417] = 3,     -- Regeneration
    [412510] = 3,     -- Mass Regeneration

    -- PRIEST
    [605] = 3,      -- Mind Control
    [15407] = 3,    -- Mind Flay
    [413259] = 5,   -- Mind Sear
    [2096] = 60,    -- Mind Vision
    -- [402174] = 1,   -- Penance
    [402277] = 2,   -- Penance
    [10797] = 6,    -- Starshards, Nightelf

    -- SHAMAN

    -- WARLOCK
    [689] = 5,       -- Drain Life
    [5138] = 5,      -- Drain Mana
    [1120] = 15,     -- Drain Soul
    [126] = 45,      -- Eye of Kilrogg
    [755] = 10,      -- Health Funnel
    [1949] = 15,     -- Hellfire
    [437169] = 120,  -- Portal of Summoning
    [5740] = 8,      -- Rain of Fire
    -- Ritual of Doom, Level 60
    [698] = 5,       -- Ritual of Summoning
    [6358] = 15,    -- Seduction (Succubus)
    [17854] = 10,   -- Consume Shadows (Voidwalker)

    -- MISC
    [13278] = 4,    -- Gnomish Death Ray
    [20577] = 10,   -- Cannibalize
    [746] = 6,      -- First Aid

    -- NPCs
    [16430] = 12,   -- Soul Tap - Thuzadin Necromancer
    [24323] = 8,    -- Blood Siphon - Hakkar
    [24322] = 8,    -- Blood Siphon - Hakkar

    [7290] = 10,    -- Soul Siphon
    [27640] = 3,    -- Baron Rivendare's Soul Drain
    [27177] = 10,   -- Defile
    [27286] = 1,    -- Shadow Wrath 
    [20687] = 10,   -- Starfall
    
    [433797] = 7,    -- SoD: Bladestorm, Blademasters in Ashenvale
    [404373] = 10,   -- SoD: Bubble Beam, Baron Aquanis in Baron Aquanis

    -- SoD Patch 1.15.1
    [432439] = 30,  -- Channel
    [438714] = 10,  -- Furnace Surge
    [434584] = 5,   -- Gnomeregan Smash
    [436027] = 3,   -- Grubbis Mad!
    [435450] = 15,  -- Rune Scrying
    [434869] = 2,   -- Shadow Ritual of Sacrifice
    [436818] = 9,   -- Sprocketfire Breath
  }

  -- Convert key ID to name to avoid handling all different spell ranks (which have the same name, but different IDs)
  local CHANNELED_SPELL_INFO_BY_NAME = {}
  for spell_id, channel_cast_time in pairs(CHANNELED_SPELL_INFO_BY_ID) do
    CHANNELED_SPELL_INFO_BY_NAME[_G.GetSpellInfo(spell_id)] = channel_cast_time
  end

  -- Classic Era: name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID
  UnitChannelInfo = function(unitid, event_spellid)
    local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, _ = _G.UnitChannelInfo(unitid)

    if not event_spellid then
      local plate = PlatesByUnit[unitid]
      if plate then 
        event_spellid = plate.TPFrame.unit.ChannelEventSpellID
      end
    end

    if not name and event_spellid then 
      name, _, texture = _G.GetSpellInfo(event_spellid)

      local channel_cast_time = name and CHANNELED_SPELL_INFO_BY_NAME[name]
      if channel_cast_time then
        endTime = (GetTime() + channel_cast_time) * 1000
        startTime = GetTime() * 1000

        plate.TPFrame.unit.ChannelEventSpellID = event_spellid

        return name, name, texture, startTime, endTime, isTradeSkill, notInterruptible, event_spellid
      end
    end

    return name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID
  end

  UnitCastingInfo = _G.UnitCastingInfo

  -- UnitNameplateShowsWidgetsOnly: SL - Patch 9.0.1 (2020-10-13): Added.
  UnitNameplateShowsWidgetsOnly = function() return false end
elseif Addon.IS_TBC_CLASSIC then
  GetNameForNameplate = function(plate) return plate:GetName() end

  -- name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID
  UnitChannelInfo = function(...)
    local name, text, texture, startTime, endTime, isTradeSkill, spellID = _G.UnitChannelInfo(...)
    return name, text, texture, startTime, endTime, isTradeSkill, false, spellID
  end

  -- name, text, texture, startTime, endTime, isTradeSkill, _, notInterruptible, spellID
  UnitCastingInfo = function(...)
    -- In BC Classic, UnitCastingInfo does not return notInterruptible
    local name, text, texture, startTime, endTime, isTradeSkill, spellID = _G.UnitCastingInfo(...)
    return name, text, texture, startTime, endTime, isTradeSkill, nil, false, spellID
  end

  -- UnitNameplateShowsWidgetsOnly: SL - Patch 9.0.1 (2020-10-13): Added.
  UnitNameplateShowsWidgetsOnly = function() return false end
elseif Addon.ExpansionIsBetween(LE_EXPANSION_WRATH_OF_THE_LICH_KING, LE_EXPANSION_BATTLE_FOR_AZEROTH) then
  GetNameForNameplate = function(plate) return plate:GetName() end
  UnitCastingInfo = _G.UnitCastingInfo
  -- UnitNameplateShowsWidgetsOnly: SL - Patch 9.0.1 (2020-10-13): Added.
  UnitNameplateShowsWidgetsOnly = function() return false end
else
  GetNameForNameplate = function(plate) return plate:GetName() end
  UnitCastingInfo = _G.UnitCastingInfo
end

---------------------------------------------------------------------------------------------------------------------
--  Initialize unit data after NAME_PLATE_UNIT_ADDED and update it
---------------------------------------------------------------------------------------------------------------------
local TARGET_MARKER_LIST = { 
  "STAR", "CIRCLE", "DIAMOND", "TRIANGLE", "MOON", "SQUARE", "CROSS", "SKULL", 
}

local MENTOR_ICON_LIST = { 
  [15] = "GREEN_FLAG",
  [16] = "MURLOC", 
}

local ELITE_REFERENCE = {
  ["elite"] = true,
  ["rareelite"] = true,
  ["worldboss"] = true,
}

local RARE_REFERENCE = {
  ["rare"] = true,
  ["rareelite"] = true,
}

local MAP_UNIT_REACTION = {
  [1] = "HOSTILE",
  [2] = "HOSTILE",
  [3] = "HOSTILE",
  [4] = "NEUTRAL",
  [5] = "FRIENDLY",
  [6] = "FRIENDLY",
  [7] = "FRIENDLY",
  [8] = "FRIENDLY",
}

local function GetReactionByColor(red, green, blue)
  if red < .1 then 	-- Friendly
    return "FRIENDLY"
  elseif red > .5 then
    if green > .9 then
      return "NEUTRAL"
    else
      return "HOSTILE"
    end
  end
end

---------------------------------------------------------------------------------------------------------------------
-- Functions for accessing nameplate frames
---------------------------------------------------------------------------------------------------------------------

function Addon:GetThreatPlateForUnit(unitid)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if not unitid or unitid == "player" or UnitIsUnit("player", unitid) then return end

  -- Special unitids (target, personal nameplate) are skipped as they are not added to PlatesByUnit in NAME_PLATE_UNIT_ADDED
  -- local tp_frame = self.PlatesByUnit[unitid]
  -- if tp_frame and tp_frame.Active then
  local plate = GetNamePlateForUnit(unitid)
  if plate and plate.TPFrame.Active then
    return plate.TPFrame
  end
end

-- function Addon:GetNonIgnoredThreatPlateForUnit(unitid)
--   -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
--   if IGNORED_UNITS[unitid] then return end

--   return self:GetThreatPlateForUnit(unitid)
-- end

function Addon:GetThreatPlateForTarget()
  local plate = GetNamePlateForUnit("target")
  if plate and plate.TPFrame.Active then
     return plate.TPFrame
  end
end

function Addon:GetThreatPlateForGUID(guid)
  local plate = self.PlatesByGUID[guid]
  if plate and plate.TPFrame.Active then
    return plate.TPFrame
  end
end

function Addon:GetActiveThreatPlates()
  local function ActiveTPFrameIterator(t, unitid)
    local tp_frame
    repeat
      unitid, tp_frame = next(t, unitid)
      if tp_frame and tp_frame.Active then
        return unitid, tp_frame
      end
    until not tp_frame 
    return nil
  end

 return ActiveTPFrameIterator, self.PlatesByUnit, nil
 
  -- local plates_by_unit = self.PlatesByUnit
  -- return function()
  --   local index
  --   repeat
  --     local unitid, tp_frame = next(plates_by_unit, index)
  --     if tp_frame and tp_frame.Active then
  --       index = unitid
  --       return unitid, tp_frame
  --     end
  --   until not tp_frame
  --   return nil
  -- end
end

---------------------------------------------------------------------------------------------------------------------
-- Functions for setting unit attributes
---------------------------------------------------------------------------------------------------------------------

local function SetUnitAttributeName(unit, unitid)
  -- Can be UNKNOWNOBJECT => UNIT_NAME_UPDATE
  local unit_name, realm = UnitName(unitid)
  -- Let's preserve the unaltered name for the custom styles check…
  unit.basename = unit_name

  if unit.type == "PLAYER" then
    local db = Addon.db.profile.Name.HealthbarMode

    if db.ShowTitle then
      unit_name = UnitPVPName(unitid)
    end

    if db.ShowRealm and realm then
      unit_name = unit_name .. " - " .. realm
    end
  end

  unit.name = unit_name
end

local function SetUnitAttributeReaction(unit, unitid)
  -- Reaction => UNIT_FACTION
  unit.red, unit.green, unit.blue = _G.UnitSelectionColor(unitid)
  unit.reaction = MAP_UNIT_REACTION[UnitReaction("player", unitid)] or GetReactionByColor(unit.red, unit.green, unit.blue)

  -- Enemy players turn to neutral, e.g., when mounting a flight path mount, so fix reaction in that situations
  if unit.reaction == "NEUTRAL" and (unit.type == "PLAYER" or UnitPlayerControlled(unitid)) then
    unit.reaction = "HOSTILE"
  end

  unit.IsTapDenied = _G.UnitIsTapDenied(unitid)
end

local function SetUnitAttributeLevel(unit, unitid)
  -- Level => UNIT_LEVEL
  local unit_level = UnitEffectiveLevel(unitid)
  unit.level = unit_level
  unit.LevelColor = GetCreatureDifficultyColor(unit_level)
end

local function SetUnitAttributeHealth(unit, unitid)
  -- Health and Absorbs => UNIT_HEALTH_FREQUENT, UNIT_MAXHEALTH & UNIT_ABSORB_AMOUNT_CHANGED
  unit.health = _G.UnitHealth(unitid) or 0
  unit.healthmax = _G.UnitHealthMax(unitid) or 1
  -- unit.Absorbs = UnitGetTotalAbsorbs(unitid) or 0
end

local function SetUnitAttributeTargetMarker(unit, unitid)
  local raid_icon_index = GetRaidTargetIndex(unitid)
  if Addon.ExpansionIsAtLeastMidnight then 
    unit.TargetMarkerIcon = raid_icon_index
    unit.MentorIcon = raid_icon_index
  else
    unit.TargetMarkerIcon = TARGET_MARKER_LIST[raid_icon_index]
    unit.MentorIcon = MENTOR_ICON_LIST[raid_icon_index]
  end
end

local function SetUnitAttributeTarget(unit)
  local unitid = unit.unitid
  unit.isTarget = UnitIsUnit("target", unitid) -- required here for config changes which reset all plates without calling TARGET_CHANGED, MOUSEOVER, ...
  
  unit.IsSoftEnemyTarget = UnitIsUnit("softenemy", unitid)
  unit.IsSoftFriendTarget = UnitIsUnit("softfriend", unitid)
  unit.IsSoftInteractTarget = UnitIsUnit("softinteract", unitid)

  unit.IsSoftTarget = unit.isTarget or unit.IsSoftEnemyTarget or unit.IsSoftFriendTarget or unit.IsSoftInteractTarget
end

local function SetUnitAttributes(unit, unitid)
  -- Unit data that does not change after nameplate creation
  unit.unitid = unitid
  unit.guid = _G.UnitGUID(unitid)
  
  unit.isBoss = UnitEffectiveLevel(unitid) == -1

  unit.classification = (unit.isBoss and "boss") or _G.UnitClassification(unitid)
  unit.isElite = ELITE_REFERENCE[unit.classification] or false
  unit.isRare = RARE_REFERENCE[unit.classification] or false
  unit.IsBossOrRare = (unit.isBoss or unit.isRare)

  if UnitIsPlayer(unitid) then
    local _, unit_class = UnitClass(unitid)
    unit.class = unit_class
    unit.type = "PLAYER"
  else
    unit.class = ""
    unit.type = "NPC"

    if not Addon.ExpansionIsAtLeastMidnight then
      local _, _, _, _, _, npc_id = strsplit("-", unit.guid or "")
      unit.NPCID = npc_id
    end
  end

  SetUnitAttributeReaction(unit, unitid)
  SetUnitAttributeLevel(unit, unitid)
  SetUnitAttributeName(unit, unitid)
  SetUnitAttributeHealth(unit, unitid)
  
  -- Casting => UNIT_SPELLCAST_*
  -- Initialized in OnStartCasting in HandlePlateUnitAdded, but only when unit is currently casting
  unit.isCasting = false
  unit.IsInterrupted = false
  
  -- Target, Focus, and Mouseover => PLAYER_TARGET_CHANGED, UPDATE_MOUSEOVER_UNIT, PLAYER_FOCUS_CHANGED
  SetUnitAttributeTarget(unit, unitid)
  unit.IsFocus = UnitIsUnit("focus", unitid) -- required here for config changes which reset all plates without calling TARGET_CHANGED, MOUSEOVER, ...
  unit.isMouseover = UnitIsUnit("mouseover", unitid)
  
  -- Target Mark => RAID_TARGET_UPDATE
  SetUnitAttributeTargetMarker(unit, unitid)
end

---------------------------------------------------------------------------------------------------
-- Action Target Support
---------------------------------------------------------------------------------------------------

local function SoftTargetExists()
	return UnitExists("target") or 
		(TargetStyleForEnemy and UnitExists("softenemy")) or 
		(TargetStyleForFriend and UnitExists("softfriend")) or 
		(TargetStyleForInteract and UnitExists("softinteract"))
end

local function UnitIsSoftTarget(unitid)
	return UnitIsUnit("target", unitid) or 
		(TargetStyleForEnemy and UnitIsUnit("softenemy", unitid)) or 
		(TargetStyleForFriend and UnitIsUnit("softfriend", unitid))	or 
		(TargetStyleForInteract and UnitIsUnit("softinteract", unitid))
end

---------------------------------------------------------------------------------------------------------------------
-- Nameplate Updating:
---------------------------------------------------------------------------------------------------------------------

local function OnStartCasting(tp_frame, unitid, channeled, event_spellid)
  local unit, visual, style = tp_frame.unit, tp_frame.visual, tp_frame.style

  local castbar = tp_frame.visual.Castbar
  -- Don't check for or style.castbar.show here as depending on the cast the nameplate style can change (with then
  -- a castbar that should be shown).
  if not tp_frame:IsShown() then
    castbar:Hide()
    return
  end

  local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, numStages
  if channeled then
    name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, _, numStages = UnitChannelInfo(unitid, event_spellid)
  else
    name, text, texture, startTime, endTime, isTradeSkill, _, notInterruptible, spellID = UnitCastingInfo(unitid)
  end

  if not name or isTradeSkill then
    castbar:Hide()
    return 
  end

  if not IsSecretValue(name) then
    StyleModule.CastTriggerCheckIfActive(unit, spellID, name)
  end

  -- Abort here as casts can now switch nameplate styles (e.g,. from headline to healthbar view
  if not style.castbar.show and not unit.CustomStyleCast then
    castbar:Hide()
    return
  end

  unit.isCasting = true
  unit.IsInterrupted = false
  unit.spellIsShielded = notInterruptible

  if StyleModule.CastTriggerUpdateStyle(unit) then
    StyleModule:Update(tp_frame)
    -- style = tp_frame.style
  end

  visual.SpellText:SetText(text)
  visual.SpellIcon:SetTexture(texture)

  if not Addon.ExpansionIsAtLeastMidnight then
    local target_unit_name = UnitName(unit.unitid .. "target")
    -- There are situations when UnitName returns nil (OnHealthUpdate, hypothesis: health update when the unit died tiggers this, but then there is no target any more)
    if target_unit_name then
      local _, class_name = UnitClass(target_unit_name)
      castbar.CastTarget:SetText(Addon.ColorByClass(class_name, TransliterateCyrillicLetters(target_unit_name)))
    else
      castbar.CastTarget:SetText(nil)
    end
  end

  castbar:SetReverseFill(castbar.IsChanneling)

  if Addon.ExpansionIsAtLeastMidnight then
    -- Although Evoker's empowered casts are considered channeled, time (and therefore growth direction)
    -- is calculated like for normal casts. Therefore: castbar.IsCasting = true
    castbar.IsCasting = not channeled --or (numStages and numStages > 0)

    -- Sometimes startTime/endTime are nil (even in Retail). Not sure if name is always nil is this case as well, just to be sure here
    -- I think this should not be necessary, name should be nil in this case, but not sure.
    local current_time = GetTimePreciseSec() * 1000
    if type(startTime) == "nil" then
      startTime = current_time
    end
    if type(endTime) == "nil" then
      endTime = current_time
    end

    -- castbar.MinValue = startTime
    -- castbar.MaxValue = endTime
    castbar:SetMinMaxValues(startTime, endTime)
    castbar:SetValue(current_time)
    castbar:SetAllColors(ColorModule.SetCastbarColor(unit))
    castbar:SetFormat(unit.spellIsShielded)
  else
    -- Although Evoker's empowered casts are considered channeled, time (and therefore growth direction)
    -- is calculated like for normal casts. Therefore: castbar.IsCasting = true
    castbar.IsCasting = not channeled or (numStages and numStages > 0)

    -- Sometimes startTime/endTime are nil (even in Retail). Not sure if name is always nil is this case as well, just to be sure here
    -- I think this should not be necessary, name should be nil in this case, but not sure.
    local current_time = GetTime()
    endTime = endTime or current_time
    startTime = startTime or current_time
    castbar.Value = current_time - (startTime / 1000)

    castbar.MaxValue = (endTime - startTime) / 1000   
    castbar:SetMinMaxValues(0, castbar.MaxValue)
    castbar:SetValue(castbar.Value)
    castbar:SetAllColors(ColorModule.SetCastbarColor(unit))
    castbar:SetFormat(unit.spellIsShielded)
  end

  castbar.IsChanneling = not castbar.IsCasting

  -- Only publish this event once (OnStartCasting is called for re-freshing as well)
  if not castbar:IsShown() then
    PublishEvent("CastingStarted", tp_frame)
  end

  castbar:Show()
end

local function UpdateCastbar(tp_frame, unitid)
  if not ShowCastBars then return end

  if tp_frame.unit.isCasting then 
    -- Check to see if there's a spell being cast
    OnStartCasting(tp_frame, unitid, tp_frame.visual.Castbar.IsChanneling)
  else
    -- It would be better to check for IsInterrupted here and not hide it if that is true
    -- Not currently sure though, if that might work with the Hide() calls in OnStartCasting
    tp_frame.visual.Castbar:Hide()
  end
end

---------------------------------------------------------------------------------------------------------------------
-- Widget Container Handling
---------------------------------------------------------------------------------------------------------------------

local function WidgetContainerReset(plate) 
  local widget_container = plate.TPFrame.WidgetContainer
  if widget_container then
    widget_container:SetParent(plate)
    widget_container:SetIgnoreParentScale(false)
    widget_container:ClearAllPoints()
    widget_container:SetPoint("TOP", plate.castBar, "BOTTOM")
  end
end

local function WidgetContainerAcquire(plate)
  local tp_frame = plate.TPFrame
  local widget_container = plate.UnitFrame.WidgetContainer
  if widget_container and tp_frame.Active then
    tp_frame.WidgetContainer = widget_container
    widget_container:SetParent(tp_frame)
    widget_container:SetIgnoreParentScale(true)
    widget_container:SetScale(Addon.db.profile.BlizzardSettings.Widgets.Scale)
    AnchorFrameTo(Addon.db.profile.BlizzardSettings.Widgets, widget_container, tp_frame)
  end
end

local function WidgetContainerAnchor(tp_frame)
  if tp_frame.WidgetContainer then
    AnchorFrameTo(Addon.db.profile.BlizzardSettings.Widgets, tp_frame.WidgetContainer, tp_frame)
  end
end

---------------------------------------------------------------------------------------------------------------------
-- Handle default nameplate visibility
---------------------------------------------------------------------------------------------------------------------

local function IgnoreUnitForThreatPlates(unitid)
  return UnitIsUnit("player", unitid) or UnitNameplateShowsWidgetsOnly(unitid)
end

local SetShownBlizzardPlate

if Addon.ExpansionIsAtLeastMidnight then
  SetShownBlizzardPlate = function(unit_frame, show)
    unit_frame:SetAlpha(show and 1 or 0)
  end
else
  SetShownBlizzardPlate = function(unit_frame, show)
    unit_frame:SetShown(show)
  end  
end

local function ShowBlizzardNameplate(plate, show_blizzard_plate)
  SetShownBlizzardPlate(plate.UnitFrame, show_blizzard_plate)

  if show_blizzard_plate then
    --plate.UnitFrame:Show()
    WidgetContainerReset(plate)
    plate.TPFrame:Hide()
    plate.TPFrame.Active = false
  else
    --plate.UnitFrame:Hide()
    plate.TPFrame:Show()
    plate.TPFrame.Active = true
  end
end

local function SetNameplateVisibility(plate, unitid)
  -- ! Interactive objects do also have nameplates. We should not mess with the visibility the of these objects.
  -- We cannot use unit.reaction here as it is not guaranteed that it's update whenever this function is called (see UNIT_FACTION).  local unit_reaction = UnitReaction("player", unitid) or 0
  local unit_reaction = UnitReaction("player", unitid) or 0
  if unit_reaction > 4 then
    ShowBlizzardNameplate(plate, SettingsShowFriendlyBlizzardNameplates)
  else
    ShowBlizzardNameplate(plate, SettingsShowEnemyBlizzardNameplates)
  end
end

local function ThreatPlatesIsActive(unitid)
  local unit_reaction = UnitReaction("player", unitid) or 0
  if unit_reaction > 4 then
    return not SettingsShowFriendlyBlizzardNameplates
  else
    return not SettingsShowEnemyBlizzardNameplates
  end
end

local function GetAnchorForThreatPlateFrame(self)
  local visual = self.visual
  if visual.healthbar:IsShown() then
    return visual.healthbar, self
  elseif visual.name:IsShown() then
    return visual.name, self
  else -- this could happen for personal nameplate which is not handled by TP
    return self, self
  end
end

local function GetAnchorForThreatPlateExternal(self)
  local unit_frame = self.Parent.UnitFrame
  if ThreatPlatesIsActive(unit_frame.unit) then
    return GetAnchorForThreatPlateFrame(self)
  else
    return unit_frame, unit_frame
  end
end

local function ClassicBlizzardNameplatesSetAlpha(UnitFrame, alpha)
  if Addon.WOW_USES_CLASSIC_NAMEPLATES then
    UnitFrame.LevelFrame:SetAlpha(alpha)
  else
    UnitFrame.ClassificationFrame:SetAlpha(alpha)
  end
end

-- Hide ThreatPlates nameplates if Blizzard nameplates should be shown for friendly/enemy units
local function SetVisibilityOfBlizzardNameplate(UnitFrame, unitid)
  -- Not sure if unit.reaction will always be correctly set here, so:
  local unit_reaction = UnitReaction("player", unitid) or 0
  if unit_reaction > 4 then
    SetShownBlizzardPlate(UnitFrame, SettingsShowFriendlyBlizzardNameplates)
    --UnitFrame:SetShown(SettingsShowFriendlyBlizzardNameplates)
  else
    SetShownBlizzardPlate(UnitFrame, SettingsShowEnemyBlizzardNameplates)
    --UnitFrame:SetShown(SettingsShowEnemyBlizzardNameplates)
  end
end


local function FrameOnShow(UnitFrame)
  local unitid = UnitFrame.unit
  
  -- Hide nameplates that have not yet an unit added
  if not unitid then 
    -- ? Not sure if Hide() is really needed here or if even TPFrame should also be hidden here ...
    SetShownBlizzardPlate(UnitFrame, false)
    return
  end

  -- Don't show ThreatPlates for ignored units (e.g., widget-only nameplates (since Shadowlands))
  if IgnoreUnitForThreatPlates(unitid) then
    if UnitFrame:GetParent().TPFrame then
      UnitFrame:GetParent().TPFrame:Hide()
    end
    return
  end


  if UnitIsUnit(unitid, "player") then -- or: ns.PlayerNameplate == GetNamePlateForUnit(UnitFrame.unit)
    -- Skip the personal resource bar of the player character, don't unhook scripts as nameplates, even the personal
    -- resource bar, get re-used
    if SettingsHideBuffsOnPersonalNameplate then
      UnitFrame.BuffFrame:Hide()
    end
  else
    if SettingsShowOnlyNames then
      ClassicBlizzardNameplatesSetAlpha(UnitFrame, 0)
    end
  
    SetVisibilityOfBlizzardNameplate(UnitFrame, unitid)
  end
end

-- Frame: self = plate
local function FrameOnUpdate(plate, elapsed)
  -- Skip nameplates not handled by TP: Blizzard default plates (if configured) and the personal nameplate
  local tp_frame = plate.TPFrame
  if not tp_frame.Active or UnitIsUnit(plate.UnitFrame.unit or "", "player") then
    return
  end

  tp_frame:SetFrameLevel(plate:GetFrameLevel())

  --    for i = 1, #PlateOnUpdateQueue do
  --      PlateOnUpdateQueue[i](plate, tp_frame.unit)
  --    end

  --ScalingModule.HideNameplate(tp_frame)
  -- Do this after the hiding stuff, to correctly set the occluded transparency
  TransparencyModule:SetOccludedTransparency(tp_frame)

  WidgetContainerAnchor(tp_frame)
end

-- Frame: self = plate
local function FrameOnHide(plate)
  plate.TPFrame:Hide()
end

---------------------------------------------------------------------------------------------------------------------
-- Nameplate event handling
---------------------------------------------------------------------------------------------------------------------

local function NamePlateDriverFrame_AcquireUnitFrame(_, plate)
  local unit_frame = plate.UnitFrame
  if unit_frame and not unit_frame:IsForbidden() and not unit_frame.ThreatPlates then
    unit_frame.ThreatPlates = true
    unit_frame:HookScript("OnShow", FrameOnShow)
    
    -- Shameless copy from Plater - prevent Blizzard plates from showing when their alpha is changed
    -- as they are currently hidden using with SetAlpha(0)
    if Addon.ExpansionIsAtLeastMidnight then
      local locked = false
      hooksecurefunc(unit_frame, "SetAlpha", function(self)
        if locked or self:IsForbidden() then return end

        locked = true
        SetVisibilityOfBlizzardNameplate(self, self.unit)
        --self:SetAlpha(0)
        locked = false
      end)
    end
    
    plate.TPFrame:SetPoint("CENTER", plate.UnitFrame, "CENTER")
    --plate.Background:SetAllPoints(plate.TPFrame)
  end
end

local	function HandlePlateCreated(plate)
  -- Parent could be: WorldFrame, UIParent, plate
  -- Hierarchy and Scaling: UIParent scales with the UI size setting. Parent frames to WorldFrame (or nil) to make them ignore the UI scale.
  -- Visibility: Elements attached directly to WorldFrame remain visible even when the main UI is hidden (Alt+Z).
  -- Use UIParent (Default): For almost all addons, chat frames, action bars, and UI elements.
  -- WorldFrame: For elements that must sit behind the UI or remain visible when the UI is hidden (e.g., custom 3D effects, background custom textures). 
  -- => Using World Frame is wrong!
  local tp_frame = _G.CreateFrame("Frame",  "ThreatPlatesFrame" .. GetNameForNameplate(plate), WorldFrame, BackdropTemplate)
  tp_frame:SetFrameStrata("BACKGROUND")
  tp_frame:EnableMouse(false)

  -- Size is set in Styles.lua
  
  tp_frame.Parent = plate
  plate.TPFrame = tp_frame

  -- ! Can be used by other addons (e.g., BigDebuffs) to get the correct anchor for its content
  tp_frame.GetAnchor = GetAnchorForThreatPlateExternal
  
  -- plate.Background = _G.CreateFrame("Frame", nil, plate, BackdropTemplate)
  -- plate.Background:EnableMouse(false)
  -- plate.Background:SetBackdrop({
  --   bgFile = Addon.PATH_ARTWORK .. "TP_WhiteSquare.tga",
  --   edgeFile = Addon.PATH_ARTWORK .. "TP_WhiteSquare.tga",
  --   edgeSize = 2,
  --   insets = { left = 0, right = 0, top = 0, bottom = 0 },
  -- })
  -- plate.Background:SetBackdropColor(0,0,0,.3)
  -- plate.Background:SetBackdropBorderColor(0, 0, 0, 0.8)
  -- plate.Background:Show()
  
  tp_frame.visual = {}
  tp_frame.style = {}
  tp_frame.unit = {}

  local textframe = _G.CreateFrame("Frame", nil, tp_frame)
  textframe:SetAllPoints()
  tp_frame.visual.textframe = textframe

  -- Create graphical elements and widgets
  ElementsPlateCreated(tp_frame)
  Widgets:OnPlateCreated(tp_frame)
end

-- HandlePlateUnitAdded
local function HandlePlateUnitAdded(plate, unitid)
  local tp_frame = plate.TPFrame
  local unit = tp_frame.unit

  if Addon.ExpansionIsAtLeastMidnight then
    --C_NamePlateManager.SetNamePlateSimplified(unitid, false)

    -- if not InCombatLockdown() then
    --   C_NamePlateManager.SetNamePlateHitTestFrame(unitid, tp_frame)
    -- -- else
    -- --   plate.UnitFrame.HitTestFrame:SetParent(plate.UnitFrame)
    -- --   plate.UnitFrame.HitTestFrame:ClearAllPoints()
    -- --   plate.UnitFrame.HitTestFrame:SetAllPoints(tp_frame)
    -- end

    -- plate.UnitFrame.HitTestFrame:SetParent(plate.unitFrame)
    -- plate.UnitFrame.HitTestFrame:ClearAllPoints()
    -- plate.UnitFrame.HitTestFrame:SetPoint("TOPLEFT", plate.unitFrame, "TOPLEFT")
    -- plate.UnitFrame.HitTestFrame:SetPoint("BOTTOMRIGHT", plate.unitFrame, "BOTTOMRIGHT")

    -- C_Timer.After(0.1, function()
    --   if not plate.UnitFrame then return end

    --   plate.TPAnchorFrame:ClearAllPoints()
    --   if SettingsShowOnlyNames then
    --     plate.TPAnchorFrame:SetParent(plate)
    --     plate.TPAnchorFrame:Hide()
    --   else
    --     plate.TPAnchorFrame:SetParent(plate.UnitFrame.healthBar)
    --     plate.TPAnchorFrame:Show()
    --   end
    --   plate.TPAnchorFrame:SetPoint("topright", plate.UnitFrame.healthBar, "topright")
    --   plate.TPAnchorFrame:SetPoint("bottomleft", plate.UnitFrame.healthBar, "bottomleft")
    --   plate.TPAnchorFrame:SetFrameStrata(plate.UnitFrame.healthBar:GetFrameStrata())
    --   plate.TPAnchorFrame:SetFrameLevel(plate.UnitFrame.healthBar:GetFrameLevel()+1)
    -- end)
  

    -- local healthbar = tp_frame.visual.Healthbar
    -- plate.TPAnchorFrame:ClearAllPoints()
    -- plate.TPAnchorFrame:SetParent(healthbar)
    -- plate.TPAnchorFrame:SetPoint("topright", healthbar, "topright")
    -- plate.TPAnchorFrame:SetPoint("bottomleft", healthbar, "bottomleft")
    -- plate.TPAnchorFrame:Show()

    -- plate.Background:SetAllPoints(plate.UnitFrame.HitTestFrame)
  end

  -- Set unit attributes
  -- Update modules, then elements, then widgets

  -- Initialize unit data for which there are no events when players enters world or that
  -- do not change over the nameplate lifetime
  SetUnitAttributes(unit, unitid)
  PlatesByUnit[unitid] = tp_frame
  if not Addon.ExpansionIsAtLeastMidnight then
    PlatesByGUID[unit.guid] = plate
  end

  -- Initialized nameplate style based on unit added
  ThreatModule.SetUnitAttribute(tp_frame)
  SetNameplateVisibility(plate, unitid)
  WidgetContainerAcquire(plate)
  -- ColorModule/TransparencyModule/ScalingModule are called in StyleModule.PlateUnitAdded
  StyleModule.PlateUnitAdded(tp_frame)
  -- TODO: This is not ideal/correct as Style.Update calls ElementsUpdateStyle
  ElementsPlateUnitAdded(tp_frame)

  -- Call this after the plate is shown as OnStartCasting checks if the plate is shown; if not, the castbar is hidden and
  -- nothing is updated
  UpdateCastbar(tp_frame, unitid)
end

--------------------------------------------------------------------------------------------------------------
-- Misc. Utility
--------------------------------------------------------------------------------------------------------------

-- Blizzard default nameplates always have the same size, no matter what the UI scale actually is
function Addon:UIScaleChanged()
  local db = Addon.db.profile.Scale
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
      local tp_frame = ConfigModePlate.TPFrame

      tp_frame.Background:Hide()
      tp_frame.Background = nil
      tp_frame:SetScript('OnHide', nil)

      ConfigModePlate = nil
    else
      ConfigModePlate = GetNamePlateForUnit("target")
      if ConfigModePlate then
        local tp_frame = ConfigModePlate.TPFrame

        -- Draw background to show for clickable area
        tp_frame.Background = _G.CreateFrame("Frame", nil, ConfigModePlate, BackdropTemplate)
        tp_frame.Background:SetBackdrop({
          bgFile = Addon.PATH_ARTWORK .. "TP_WhiteSquare.tga",
          edgeFile = Addon.PATH_ARTWORK .. "TP_WhiteSquare.tga",
          edgeSize = 2,
          insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        tp_frame.Background:SetBackdropColor(0,0,0,.3)
        tp_frame.Background:SetBackdropBorderColor(0, 0, 0, 0.8)
        tp_frame.Background:SetPoint("CENTER", ConfigModePlate.UnitFrame, "CENTER")

        if Addon.ExpansionIsAtLeastMidnight then
          tp_frame.Background:ClearAllPoints()
          tp_frame.Background:SetAllPoints(ConfigModePlate.UnitFrame.HitTestFrame)
        else
          local width, height
          if tp_frame.unit.reaction == "FRIENDLY" then          
            width, height = C_NamePlate.GetNamePlateFriendlySize()
          else
            width, height = C_NamePlate.GetNamePlateEnemySize()
          end
          tp_frame.Background:SetSize(width, height)

        end

        tp_frame.Background:Show()

        -- remove the config background if the nameplate is hidden to prevent it
        -- from being shown again when the nameplate is reused at a later date
        tp_frame:HookScript('OnHide', function(self)
          self.Background:Hide()
          self.Background = nil
          self:SetScript('OnHide', nil)
          ConfigModePlate = nil
        end)
      else
        Addon.Logging.Warning(L["Please select a target unit to enable configuration mode."])
      end
    end
  elseif ConfigModePlate then
    local background = ConfigModePlate.TPFrame.Background
    background:SetPoint("CENTER", ConfigModePlate.UnitFrame, "CENTER")
    background:SetSize(ConfigModePlate.TPFrame:GetWidth(), ConfigModePlate.TPFrame:GetHeight())
  end
end

--------------------------------------------------------------------------------------------------------------
-- External Commands: Allows widgets and themes to request updates to the plates.
-- Useful to make a theme respond to externally-captured data (such as the combat log)
--------------------------------------------------------------------------------------------------------------

function Addon:UpdateSettings()
  --wipe(PlateOnUpdateQueue)

  Addon.Localization.UpdateSettings()
  --Font:UpdateSettings()
  Addon.Icon.UpdateSettings()
  Addon.Threat.UpdateSettings()
  Addon.Transparency.UpdateSettings()
  Addon.Scaling.UpdateSettings()
  Addon.Animation.UpdateSettings()
  Addon.Color.UpdateSettings()
  ElementsUpdateSettings()

  local db = Addon.db.profile

  SettingsShowFriendlyBlizzardNameplates = db.ShowFriendlyBlizzardNameplates
  SettingsShowEnemyBlizzardNameplates = db.ShowEnemyBlizzardNameplates
  SettingsHideBuffsOnPersonalNameplate = db.PersonalNameplate.HideBuffs -- Check for Addon.WOW_USES_CLASSIC_NAMEPLATES not necessary as there is no player nameplate with classic nameplates
  SettingsShowOnlyNames = CVars:GetAsBool("nameplateShowOnlyNames") and Addon.db.profile.BlizzardSettings.Names.Enabled

  TargetStyleForEnemy = db.targetWidget.SoftTarget.TargetStyleForEnemy
  TargetStyleForFriend = db.targetWidget.SoftTarget.TargetStyleForFriend
  TargetStyleForInteract = db.targetWidget.SoftTarget.TargetStyleForInteract
  
  if TargetStyleForEnemy or TargetStyleForFriend or TargetStyleForInteract then
    Addon.TargetUnitExists = SoftTargetExists
    Addon.UnitIsTarget = UnitIsSoftTarget
  else
    Addon.TargetUnitExists = function() return UnitExists("target") end
    Addon.UnitIsTarget = function(unitid) return UnitIsUnit("target", unitid) end
  end

  if db.settings.castnostop.ShowInterruptSource then
    RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  else
    UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  end
  
  ShowCastBars = db.settings.castbar.show or db.settings.castbar.ShowInHeadlineView
  
  -- ? Not sure if this is still necessary after moving registering events to Addon.lua - OnInitialize
  if Addon.IS_MAINLINE then
    self:ACTIVE_TALENT_GROUP_CHANGED() -- to update the player's role
  end
end

function Addon:UpdateAllPlates()
    -- No need to update only active nameplates, as this is only done when settings are changed, so performance is
    -- not really an issue.
  for unitid, tp_frame in pairs(PlatesByUnit) do
    HandlePlateUnitAdded(tp_frame.Parent, unitid)
  end
end

function Addon:PublishToEachPlate(event)
  -- ? Check for Active not necessary, but should prevent unnecessary updates to Blizzard default plates
  for _, tp_frame in Addon:GetActiveThreatPlates() do
    PublishEvent(event, tp_frame)
  end
end

function Addon:ForceUpdate()
  Addon:UpdateSettings()
  Addon:UpdateAllPlates()
end

function Addon:ForceUpdateOnNameplate(plate)
  HandlePlateUnitAdded(plate, plate.TPFrame.unit.unitid)
end

function Addon:ForceUpdateFrameOnShow()
  SettingsShowOnlyNames = CVars:GetAsBool("nameplateShowOnlyNames") and Addon.db.profile.BlizzardSettings.Names.Enabled
  for _, tp_frame in Addon:GetActiveThreatPlates() do
    ClassicBlizzardNameplatesSetAlpha(tp_frame.Parent.UnitFrame, SettingsShowOnlyNames and 0 or 1)
  end
end

--------------------------------------------------------------------------------------------------------------
-- WoW Event Handling: helper functions
--------------------------------------------------------------------------------------------------------------

local TaskQueueOoC = {}

function Addon:CallbackWhenOoC(func, msg)
  if InCombatLockdown() then
    if msg then
      Addon.Logging.Warning(msg .. L[" The change will be applied after you leave combat."])
    end
    TaskQueueOoC[#TaskQueueOoC + 1] = func
  else
    func()
  end
end

--------------------------------------------------------------------------------------------------------------
-- WoW Event Handling: Event handling functions
--------------------------------------------------------------------------------------------------------------

function Addon:PLAYER_LOGIN(...)
  -- Fix for Blizzard default plates being shown at random times
  -- Works now in all WoW versions
  if NamePlateDriverFrame and NamePlateDriverFrame.AcquireUnitFrame then
    hooksecurefunc(NamePlateDriverFrame, "AcquireUnitFrame", NamePlateDriverFrame_AcquireUnitFrame)
  end
end

local PVE_INSTANCE_TYPES = {
  --none = false,
  --pvp = false,
  --arena = false,
  party = true,
  raid = true,
  scenario = true,
}

local PVP_INSTANCE_TYPES = {
  --none = false,
  pvp = true,
  arena = true,
  --party = false,
  --raid = false,
  --scenario = false,
}

-- Fired when the player enters the world, reloads the UI, enters/leaves an instance or battleground, or respawns at a graveyard.
-- Also fires any other time the player sees a loading screen
function Addon:PLAYER_ENTERING_WORLD(initialLogin, reloadingUI)
  -- This code must be executed every time the player enters a instance (dungeon, raid, ...)
  local db = Addon.db.profile.Automation
  
  local is_in_instance, instance_type = IsInInstance()
  Addon.IsInInstance = is_in_instance
  Addon.IsInPvEInstance = PVE_INSTANCE_TYPES[instance_type]
  Addon.IsInPvPInstance = PVP_INSTANCE_TYPES[instance_type]

  if db.ShowFriendlyUnitsInInstances then
    if Addon.IsInPvEInstance then
      CVars:Set("nameplateShowFriends", 1)
    else
      -- Restore the value from before entering the instance
      CVars:RestoreFromProfile("nameplateShowFriends")
    end
  elseif db.HideFriendlyUnitsInInstances then
    if Addon.IsInPvEInstance then  
      CVars:Set("nameplateShowFriends", 0)
    else
      -- Restore the value from before entering the instance
      CVars:RestoreFromProfile("nameplateShowFriends")
    end
  end

  if Addon.db.profile.BlizzardSettings.Names.ShowPlayersInInstances then
    if Addon.IsInPvEInstance then  
      CVars:Set("UnitNameFriendlyPlayerName", 1)
      -- CVars:Set("UnitNameFriendlyPetName", 1)
      -- CVars:Set("UnitNameFriendlyGuardianName", 1)
      CVars:Set("UnitNameFriendlyTotemName", 1)
      -- CVars:Set("UnitNameFriendlyMinionName", 1)
    else
      -- Restore the value from before entering the instance
      CVars:RestoreFromProfile("UnitNameFriendlyPlayerName")
      -- CVars:RestoreFromProfile("UnitNameFriendlyPetName")
      -- CVars:RestoreFromProfile("UnitNameFriendlyGuardianName")
      CVars:RestoreFromProfile("UnitNameFriendlyTotemName")
      -- CVars:RestoreFromProfile("UnitNameFriendlyMinionName")
    end  
  end
  
  -- Update custom styles for the current instance
  Addon.UpdateStylesForCurrentInstance()

  -- Call some events manually to initialize nameplates correctly as these events are not called upon login
  --   * Scale is initalized via UNIT_FACTION as this event fires at PLAYER_ENTERING_WORLD for every unit visible
  --   * Transparency is initalized via UNIT_FACTION as this event fires at PLAYER_ENTERING_WORLD for every unit visible

  -- Adjust clickable area if we are in an instance. Otherwise the scaling of friendly nameplates' healthbars will
  -- be bugged
  Addon:SetBaseNamePlateSize()
  SetNamesFonts()

  -- ARENA_OPPONENT_UPDATE is also fired in BGs, at least in Classic, so it's only enabled when solo shuffles
  -- are available (as it's currently only needed for these kind of arenas)
  if Addon.IsSoloShuffle() then
    RegisterEvent("ARENA_OPPONENT_UPDATE")
  else
    UnregisterEvent("ARENA_OPPONENT_UPDATE")
  end
end

-- Instances without PLAYER_ENTERING_WORLD event on enter (or leave), hence "walk-in".
-- Currently only delves; possibly there are more.
-- To avoid redundant calls, make sure to only add instance IDs here that do not trigger the PLAYER_ENTERING_WORLD event.
local WalkInInstances = {
  -- Delves
  -- TWW Vanilla
  ["2664"] = true, -- Fungal Folly
  ["2679"] = true, -- Mycomancer Cavern
  ["2680"] = true, -- Earthcrawl Mines
  ["2681"] = true, -- Kriegval's Rest
  ["2683"] = true, -- The Waterworks
  ["2684"] = true, -- The Dread Pit
  ["2685"] = true, -- Skittering Breach
  ["2686"] = true, -- Nightfall Sanctum
  ["2687"] = true, -- The Sinkhole
  ["2688"] = true, -- The Spiral Weave
  ["2689"] = true, -- Tak-Rethan Abyss
  ["2690"] = true, -- The Underkeep
  ["2767"] = true, -- The Sinkhole
  ["2768"] = true, -- Tak-Rethan Abyss
  ["2836"] = true, -- Earthcrawl Mines
  ["2682"] = true, -- Zekvir's Lair; boss delve
  -- TWW Undermine
  ["2815"] = true, -- Excavation Site 9
  ["2826"] = true, -- Sidestreet Sluice
  ["2831"] = true, -- Demolition Dome; boss delve
  -- TWW Karesh
  ["2803"] = true, -- Archival Assault
  ["2951"] = true, -- Voidrazor Sanctuary; boss delve
}

function Addon:PLAYER_MAP_CHANGED(_, previousID, currentID)
  if WalkInInstances[tostring(currentID)] or WalkInInstances[tostring(previousID)] then
    -- The event fires very early, too early for GetInstanceInfo to retrieve the new ID.
    -- A delay of `0` (aka next frame) seems to be enough in *many* cases, but sometimes not;
    -- no idea what this depends on (server lag?); so using a delay like 1 or 3s is probably better.
    -- A too long delay might cause trouble if the player starts combat immediately after entering/leaving the instance.
    -- Note: Instead of delaying, we could also pass the ID as argument, but this would require various changes down the line.
    C_Timer.After(3, Addon.PLAYER_ENTERING_WORLD)
  end
end

-- Fires when the player leaves combat status
-- Syncs addon settings with game settings in case changes weren't possible during startup, reload
-- or profile reset because character was in combat.
function Addon:PLAYER_REGEN_ENABLED()
  Addon.PlayerIsInCombat = false

  -- Execute functions which will fail when executed while in combat
  for i = #TaskQueueOoC, 1, -1 do -- add -1 so that an empty list does not result in a Lua error
    TaskQueueOoC[i]()
    TaskQueueOoC[i] = nil
  end

  --  local db = Addon.db.profile.threat
  --  -- Required for threat/aggro detection
  --  if db.ON and (GetCVar("threatWarning") ~= 3) then
  --    _G.SetCVar("threatWarning", 3)
  --  elseif not db.ON and (GetCVar("threatWarning") ~= 0) then
  --    _G.SetCVar("threatWarning", 0)
  --  end

  local db = Addon.db.profile.Automation

  -- Dont't use automation for friendly nameplates if in an instance and Hide Friendly Nameplates is enabled
  if db.FriendlyUnits ~= "NONE" and not (Addon.IsInInstance and db.HideFriendlyUnitsInInstances) then
    _G.SetCVar("nameplateShowFriends", (db.FriendlyUnits == "SHOW_COMBAT" and 0) or 1)
  end
  if db.EnemyUnits ~= "NONE" then
    _G.SetCVar("nameplateShowEnemies", (db.EnemyUnits == "SHOW_COMBAT" and 0) or 1)
  end

  -- Also does a style update and fires event ThreatUpdate
  ThreatModule.LeavingCombat()
end

-- Fires when the player enters combat status
function Addon:PLAYER_REGEN_DISABLED()
  Addon.PlayerIsInCombat = true

  local db = Addon.db.profile.Automation

  -- Dont't use automation for friendly nameplates if in an instance and Hide Friendly Nameplates is enabled
  if db.FriendlyUnits ~= "NONE" and not (Addon.IsInInstance and db.HideFriendlyUnitsInInstances) then
    _G.SetCVar("nameplateShowFriends", (db.FriendlyUnits == "SHOW_COMBAT" and 1) or 0)
  end

  if db.EnemyUnits ~= "NONE" then
    _G.SetCVar("nameplateShowEnemies", (db.EnemyUnits == "SHOW_COMBAT" and 1) or 0)
  end

  -- Also does a style update and fires event ThreatUpdate
  -- ThreatEnteringCombat()
end

function Addon:NAME_PLATE_CREATED(plate)
  HandlePlateCreated(plate)

  -- NamePlateDriverFrame.AcquireUnitFrame is not used in Classic before Mists
  if not Addon.ExpansionIsAtLeastMists and plate.UnitFrame then
    NamePlateDriverFrame_AcquireUnitFrame(nil, plate)
  end

  plate:HookScript('OnHide', FrameOnHide)
  plate:HookScript('OnUpdate', FrameOnUpdate)
  
  PlatesCreated[plate] = plate.TPFrame
end

-- Payload: { Name = "unitToken", Type = "string", Nilable = false },
function Addon:NAME_PLATE_UNIT_ADDED(unitid)
  -- Player's personal nameplate:
  --   This nameplate is currently not handled by Threat Plates - HandlePlateUnitAdded is not called on it, therefore plate.TPFrame.Active is nil
  -- Nameplates for GameObjects:
  --   There are some nameplates for GameObjects, e.g. Ring of Transference in Oribos. For the time being, we don't show them.
  --   Current assumption: for units of type "GameObject", UnitExists always returns false
  --   If TP would show them, the would show as nameplates with health 0 and maybe cause Lua errors
  -- Nameplates with widgets:
  --   If the nameplate only has widgets, don't create a Threat Plate for it and let WoW handle everything,
  --   otherwise show a Threat Plate and additionally show the widget container

  if not IgnoreUnitForThreatPlates(unitid) then
    local plate = GetNamePlateForUnit(unitid)
    HandlePlateUnitAdded(plate, unitid)
    
    NamePlateDriverFrame_AcquireUnitFrame(nil, plate)
  end
end

function Addon:NAME_PLATE_UNIT_REMOVED(unitid)
  local plate = GetNamePlateForUnit(unitid)
  local tp_frame = plate.TPFrame

  tp_frame.Active = false

  PlatesByUnit[unitid] = nil
  if not Addon.ExpansionIsAtLeastMidnight then
    if tp_frame.unit.guid then -- maybe hide directly after create with unit added?
      PlatesByGUID[tp_frame.unit.guid] = nil
    end
  end

  ElementsPlateUnitRemoved(tp_frame)
  Widgets:OnUnitRemoved(tp_frame, tp_frame.unit)
  
  WidgetContainerReset(plate)

  wipe(tp_frame.unit)

  -- Set stylename to nil as CheckNameplateStyle compares the new style with the previous style.
  -- If both are unique, the nameplate is not updated to the correct custom style, but uses the
  -- previous one, I think
  tp_frame.stylename = nil

  -- plate.TPAnchorFrame:ClearAllPoints()
  -- plate.TPAnchorFrame:SetParent(plate)
  -- plate.TPAnchorFrame:SetSize(110, 45)
end

function Addon:UNIT_NAME_UPDATE(unitid)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if IGNORED_UNITS[unitid] then return end

  local tp_frame = self:GetThreatPlateForUnit(unitid)
  if tp_frame then
    SetUnitAttributeName(tp_frame.unit, unitid)
    StyleModule.UpdateName(tp_frame)
  end
end


local function PlayerTargetChanged(target_unitid)
  -- If the previous target unit's nameplate is still shown, update it:
  local plate = LastTargetPlate[target_unitid]
  if plate and plate.TPFrame.Active then
    SetUnitAttributeTarget(plate.TPFrame.unit)
    PublishEvent("TargetLost", plate.TPFrame)

    LastTargetPlate[target_unitid] = nil

    -- Update mouseover, if the mouse was hovering over the targeted unit
    Addon:UPDATE_MOUSEOVER_UNIT()
  end

  plate = GetNamePlateForUnit(target_unitid)
  if plate and plate.TPFrame.Active then
    LastTargetPlate[target_unitid] = plate

    SetUnitAttributeTarget(plate.TPFrame.unit)
    PublishEvent("TargetGained", plate.TPFrame)
  end
end

-- If only target nameplates are shonw, only the event for loosing the (soft) target is fired, but no event
-- for the new (soft) target is fired. The new target nameplate must be handled via NAME_PLATE_UNIT_ADDED.

function Addon:PLAYER_TARGET_CHANGED()
  PlayerTargetChanged("target")
end

function Addon:PLAYER_SOFT_FRIEND_CHANGED()
  PlayerTargetChanged("softfriend")
end

function Addon:PLAYER_SOFT_ENEMY_CHANGED()
  PlayerTargetChanged("softenemy")
end

function Addon:PLAYER_SOFT_INTERACT_CHANGED()
  PlayerTargetChanged("softinteract")
end

function Addon:PLAYER_FOCUS_CHANGED()
  if LastFocusPlate and LastFocusPlate.TPFrame.Active then
    LastFocusPlate.TPFrame.unit.IsFocus = false
    PublishEvent("FocusLost", LastFocusPlate.TPFrame)
    LastFocusPlate = nil
    -- Update mouseover, if the mouse was hovering over the targeted unit
    Addon:UPDATE_MOUSEOVER_UNIT()
  end

  local plate = GetNamePlateForUnit("focus")
  if plate and plate.TPFrame.Active then
    plate.TPFrame.unit.IsFocus = true
    PublishEvent("FocusGained", plate.TPFrame)
    LastFocusPlate = plate
  end
end

Addon.UPDATE_MOUSEOVER_UNIT = Addon.Elements.GetElement("MouseoverHighlight").UPDATE_MOUSEOVER_UNIT

function Addon:RAID_TARGET_UPDATE()
  for unitid, tp_frame in self:GetActiveThreatPlates() do
    local unit = tp_frame.unit

    -- Only update plates that changed
    local previous_target_marker_icon = unit.TargetMarkerIcon
    local previous_mentor_icon = unit.MentorIcon
    local previous_icon = unit.TargetMarkerIcon or unit.MentorIcon
    SetUnitAttributeTargetMarker(unit, unitid)
    if Addon.ExpansionIsAtLeastMidnight or previous_target_marker_icon ~= unit.TargetMarkerIcon or previous_mentor_icon ~= unit.MentorIcon then
      PublishEvent("TargetMarkerUpdate", tp_frame)
    end
  end
end

function Addon:UNIT_HEALTH(unitid)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if IGNORED_UNITS[unitid] then return end
  
  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    SetUnitAttributeHealth(tp_frame.unit, unitid)  

    if tp_frame.Active then
      StyleModule.Update(tp_frame)
    end
  end
end

Addon.UNIT_HEALTH_FREQUENT = Addon.UNIT_HEALTH

function Addon:UNIT_MAXHEALTH(unitid)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if IGNORED_UNITS[unitid] then return end

  local tp_frame = self:GetThreatPlateForUnit(unitid)
  if tp_frame then
    SetUnitAttributeHealth(tp_frame.unit, unitid)  
  end
end

function Addon:UNIT_THREAT_LIST_UPDATE(unitid)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if IGNORED_UNITS[unitid] then return end

  local tp_frame = self:GetThreatPlateForUnit(unitid)
  if tp_frame then
    ThreatModule.Update(tp_frame)
  end
end

-- Update all elements that depend on the unit's reaction towards the player
function Addon:UNIT_FACTION(unitid)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if unitid == "target" then
    return
  elseif unitid == "player" then
    -- We first need to check if TP is active or not on a nameplate. After a faction change, other nameplates might be active
    -- (friendly/hostile) than before. So, we need to update Active first (as GetActiveThreatPlates only iterates over active
    for plate_unitid, tp_frame in pairs(PlatesByUnit) do
      SetNameplateVisibility(tp_frame.Parent, plate_unitid)
    end

    for unitid_frame, tp_frame in self:GetActiveThreatPlates() do
      SetUnitAttributeReaction(tp_frame.unit, unitid_frame)
      StyleModule.Update(tp_frame)
      PublishEvent("FationUpdate", tp_frame)
    end
  else
    -- It seems that (at least) in solo shuffles, the UNIT_FACTION event is fired in between the events
    -- NAME_PLATE_UNIT_REMOVE and NAME_PLATE_UNIT_ADDED. As SetNameplateVisibility sets the TPFrame Active, this results 
    -- in Lua errors, so basically we cannot use it here to check if the plate is active.
    local plate = GetNamePlateForUnit(unitid)
    local tp_frame = PlatesByUnit[unitid]
    if plate and tp_frame then
      -- If Blizzard-style nameplates are used, we also need to check if TP plates are disabled/enabled now
      -- This also needs to be done no matter if the plate is Active or not as units with
      -- mindcontrolled
      SetUnitAttributeReaction(tp_frame.unit, unitid)
      SetNameplateVisibility(plate, unitid)
      if tp_frame.Active then
        StyleModule.Update(tp_frame)
        PublishEvent("FactionUpdate", tp_frame)
      end
    end
  end
end

function Addon:UNIT_LEVEL(unitid)
  -- Skip special unitids (they are updated via their nameplate unitid) and personal nameplate
  if IGNORED_UNITS[unitid] then return end

  local tp_frame = self:GetThreatPlateForUnit(unitid)
  if tp_frame then
    SetUnitAttributeLevel(tp_frame.unit, unitid)
  end
end

-- Update spell currently being cast
local function UnitSpellcastMidway(event, unitid, ...)
  -- Special unitids (target, personal nameplate) are skipped as they are not added to PlatesByUnit in NAME_PLATE_UNIT_ADDED
  if IGNORED_UNITS[unitid] or not ShowCastBars then return end

  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    OnStartCasting(tp_frame, unitid, tp_frame.visual.Castbar.IsChanneling)
  end
end

function Addon:UNIT_SPELLCAST_START(unitid, ...)
  -- Special unitids (target, personal nameplate) are skipped as they are not added to PlatesByUnit in NAME_PLATE_UNIT_ADDED
  if IGNORED_UNITS[unitid] or not ShowCastBars then return end

  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    OnStartCasting(tp_frame, unitid, false)
  end
end

function Addon:UNIT_SPELLCAST_STOP(unitid, ...)
  -- Special unitids (target, personal nameplate) are skipped as they are not added to PlatesByUnit in NAME_PLATE_UNIT_ADDED
  if IGNORED_UNITS[unitid] or not ShowCastBars then return end

  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    tp_frame.unit.isCasting = false

    local castbar = tp_frame.visual.Castbar
    castbar.IsChanneling = false
    castbar.IsCasting = false

    if StyleModule.CastTriggerReset(tp_frame.unit) then
      StyleModule.Update(tp_frame)
    end

    PublishEvent("CastingStopped", tp_frame)
  end
end

function Addon:UNIT_SPELLCAST_CHANNEL_START(unitid, _, spellid)
  -- Special unitids (target, personal nameplate) are skipped as they are not added to PlatesByUnit in NAME_PLATE_UNIT_ADDED
  if IGNORED_UNITS[unitid] or not ShowCastBars then return end

  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    OnStartCasting(tp_frame, unitid, true, spellid)
  end
end

Addon.UNIT_SPELLCAST_CHANNEL_UPDATE = Addon.UNIT_SPELLCAST_CHANNEL_START
Addon.UNIT_SPELLCAST_DELAYED = UnitSpellcastMidway
Addon.UNIT_SPELLCAST_CHANNEL_STOP = Addon.UNIT_SPELLCAST_STOP

Addon.UNIT_SPELLCAST_INTERRUPTIBLE = UnitSpellcastMidway
Addon.UNIT_SPELLCAST_NOT_INTERRUPTIBLE = UnitSpellcastMidway

Addon.UNIT_SPELLCAST_EMPOWER_START = Addon.UNIT_SPELLCAST_CHANNEL_START
Addon.UNIT_SPELLCAST_EMPOWER_UPDATE = UnitSpellcastMidway
Addon.UNIT_SPELLCAST_EMPOWER_STOP = Addon.UNIT_SPELLCAST_STOP

--  function CoreEvents:UNIT_SPELLCAST_INTERRUPTED(unitid, lineid, spellid)
--    if unitid == "target" or UnitIsUnit("player", unitid) or not ShowCastBars then return end
--  end

function Addon.UNIT_SPELLCAST_INTERRUPTED(event, unitid, castGUID, spellID, sourceName, interrupterGUID)
  -- Special unitids (target, personal nameplate) are skipped as they are not added to PlatesByUnit in NAME_PLATE_UNIT_ADDED
  if IGNORED_UNITS[unitid] or not ShowCastBars then return end

  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    if sourceName then
      local visual = tp_frame.visual
      local castbar = visual.Castbar
      if castbar:IsShown() then
        sourceName = gsub(sourceName, "%-[^|]+", "") -- UnitName(sourceName) only works in groups
        local _, class_name = GetPlayerInfoByGUID(interrupterGUID)
        visual.SpellText:SetText(INTERRUPTED .. " [" .. Addon.ColorByClass(class_name, TransliterateCyrillicLetters(sourceName)) .. "]")

        local _, max_val = castbar:GetMinMaxValues()
        castbar:SetValue(max_val)
        castbar.Spark:Hide()

        local color = Addon.db.profile.castbarColorInterrupted
        castbar:SetStatusBarColor(color.r, color.g, color.b, color.a)
        castbar.FlashTime = CASTBAR_INTERRUPT_HOLD_TIME

        UNIT_SPELLCAST_STOP("UNIT_SPELLCAST_STOP", unitid)

        -- I am assuming that OnStopCasting is called always when a cast is interrupted from
        -- _STOP events
        tp_frame.unit.IsInterrupted = true

        -- Should not be necessary any longer ... as OnStopCasting is not hiding the castbar anymore
        castbar:Show()
      end
    else
      UNIT_SPELLCAST_STOP("UNIT_SPELLCAST_STOP", unitid)
    end
  end
end

function Addon:COMBAT_LOG_EVENT_UNFILTERED()
  local timeStamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

  if event == "SPELL_INTERRUPT" then
    local tp_frame = self:GetThreatPlateForGUID(destGUID)
    if tp_frame then
      local visual = tp_frame.visual

      local castbar = visual.Castbar
      if castbar:IsShown() then
        sourceName = gsub(sourceName, "%-[^|]+", "") -- UnitName(sourceName) only works in groups
        local _, class_name = GetPlayerInfoByGUID(sourceGUID)
        visual.SpellText:SetText(INTERRUPTED .. " [" .. Addon.ColorByClass(class_name, TransliterateCyrillicLetters(sourceName)) .. "]")

        local _, max_val = castbar:GetMinMaxValues()
        castbar:SetValue(max_val)
        castbar.Spark:Hide()

        local color = Addon.db.profile.castbarColorInterrupted
        castbar:SetStatusBarColor(color.r, color.g, color.b, color.a)
        castbar.FlashTime = CASTBAR_INTERRUPT_HOLD_TIME

        -- I am assuming that OnStopCasting is called always when a cast is interrupted from
        -- _STOP events
        tp_frame.unit.IsInterrupted = true

        -- Should not be necessary any longer ... as OnStopCasting is not hiding the castbar anymore
        castbar:Show()
      end
    end
  end
end

--  local function ConvertPixelsToUI(pixels, frameScale)
--    local physicalScreenHeight = select(2, GetPhysicalScreenSize())
--    return (pixels * 768.0)/(physicalScreenHeight * frameScale)
--  end

function Addon:ARENA_OPPONENT_UPDATE(unitid, update_reason)
  -- Event is only registered in solo shuffles, so no need to check here for that
  if update_reason == "seen" then
    local tp_frame = Addon:GetThreatPlateForUnit(unitid)
    if tp_frame then
      StyleModule.Update(tp_frame)
    end

    -- local plate = PlatesByUnit[unitid]
    -- if plate then
    --   Addon:ForceUpdateOnNameplate(plate)
    -- end
  end

  -- Not sure if needed after the addition for enemy/friendly health bar sizes
  -- Addon:SetBaseNamePlateSize()
end

function Addon:UI_SCALE_CHANGED()
  Addon:ForceUpdate()
end

---------------------------------------------------------------------------------------------------------------------
-- Handling of WoW events
---------------------------------------------------------------------------------------------------------------------

local ENABLED_EVENTS = {
  "PLAYER_ENTERING_WORLD",
  "PLAYER_MAP_CHANGED",
  "PLAYER_LOGIN",
  -- "PLAYER_LOGOUT",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_REGEN_DISABLED",

  "NAME_PLATE_CREATED",
  "NAME_PLATE_UNIT_ADDED",
  "NAME_PLATE_UNIT_REMOVED",

  "PLAYER_TARGET_CHANGED",
  "PLAYER_SOFT_FRIEND_CHANGED",
  "PLAYER_SOFT_ENEMY_CHANGED",
  "PLAYER_SOFT_INTERACT_CHANGED",
  "PLAYER_FOCUS_CHANGED",

  "UPDATE_MOUSEOVER_UNIT",
  "RAID_TARGET_UPDATE",

  "UNIT_NAME_UPDATE",
  "UNIT_MAXHEALTH",
  "UNIT_HEALTH",
  "UNIT_HEALTH_FREQUENT",
  "UNIT_THREAT_LIST_UPDATE",
  "UNIT_FACTION",
  "UNIT_LEVEL",
  
  -- The following events should not have worked before adjusting UnitSpellcastMidway
  "UNIT_SPELLCAST_START",
  "UNIT_SPELLCAST_DELAYED",
  "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_CHANNEL_START",
  "UNIT_SPELLCAST_CHANNEL_UPDATE",
  "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_INTERRUPTIBLE",
  "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
  -- UNIT_SPELLCAST_SUCCEEDED
  -- UNIT_SPELLCAST_FAILED
  -- UNIT_SPELLCAST_FAILED_QUIET
  -- UNIT_SPELLCAST_INTERRUPTED - handled by COMBAT_LOG_EVENT_UNFILTERED / SPELL_INTERRUPT as it's the only way to find out the interruptorom
  -- UNIT_SPELLCAST_SENT
  "UNIT_SPELLCAST_EMPOWER_START",
  "UNIT_SPELLCAST_EMPOWER_UPDATE",
  "UNIT_SPELLCAST_EMPOWER_STOP",

  --PLAYER_CONTROL_LOST = ..., -- Does not seem to be necessary
  --PLAYER_CONTROL_GAINED = ...,  -- Does not seem to be necessary

  -- "ARENA_OPPONENT_UPDATE", -- registered in PLAYER_ENTERING_WORLD when entering a solo shuffle
  "UI_SCALE_CHANGED",

  --"PLAYER_ALIVE",
  --"PLAYER_LEAVING_WORLD",
  --"PLAYER_TALENT_UPDATE"

  -- CVAR_UPDATE,
  -- DISPLAY_SIZE_CHANGED,     -- Blizzard also uses this event
  -- VARIABLES_LOADED,         -- Blizzard also uses this event

  -- Depending on settings, registered or unregistered in ForceUpdate
  -- "COMBAT_LOG_EVENT_UNFILTERED",
}

-- GetSpecialization: Mists - Patch 5.0.4 (2012-08-28): Replaced GetPrimaryTalentTree.
if Addon.ExpansionIsAtLeastMists then
  function Addon:ACTIVE_TALENT_GROUP_CHANGED()
    local player_specialization = GetSpecialization()
    if player_specialization then
      local db = Addon.db
      if db.profile.optionRoleDetectionAutomatic then
        local role = select(5, GetSpecializationInfo(player_specialization))
        Addon.PlayerRole = (role == "TANK" and "tank") or "dps"
      else
        Addon.PlayerRole = (db.char.spec[player_specialization] and "tank") or "dps"
      end
    end
  end
  
  function Addon.GetPlayerRole()
    return Addon.PlayerRole
  end
  
  ENABLED_EVENTS.ACTIVE_TALENT_GROUP_CHANGED = Addon.ACTIVE_TALENT_GROUP_CHANGED
else
  -- GetShapeshiftFormID: not sure when removed
  local GetShapeshiftFormID = GetShapeshiftFormID
  local BEAR_FORM, DIRE_BEAR_FORM = BEAR_FORM, 8

  -- Tanks are only Warriors in Defensive Stance or Druids in Bear form
  local PLAYER_IS_TANK_BY_CLASS = {
    WARRIOR = function()
      return GetShapeshiftFormID() == 18
    end,
    DRUID = function()
      local form_index = GetShapeshiftFormID()
      return form_index == BEAR_FORM or form_index == DIRE_BEAR_FORM
    end,
    PALADIN = function()
      return Addon.PlayerIsTank
    end,
    DEATHKNIGHT = function()
      return Addon.PlayerIsTank
    end,
    -- Tanks in WoW Classic Season of Discovery:
    SHAMAN = function()
      return Addon.PlayerIsTank
    end,
    WARLOCK = function()
      return Addon.PlayerIsTank
    end,
    ROGUE = function()
      return Addon.PlayerIsTank -- Set in RUNE_UPDATED and PLAYER_EQUIPMENT_CHANGED
    end,
    DEFAULT = function()
      return false
    end,    
  }

  local PlayerIsTankByClassFunction = PLAYER_IS_TANK_BY_CLASS[Addon.PlayerClass] or PLAYER_IS_TANK_BY_CLASS["DEFAULT"]

  function Addon.GetPlayerRole()
    local db = Addon.db

    local role
    if db.profile.optionRoleDetectionAutomatic then
      role = PlayerIsTankByClassFunction()
    else
      role = db.char.spec[1]
    end

    return (role == true and "tank") or "dps"
  end

  -- Only registered for player unit
  local TANK_AURA_SPELL_IDs = {
    [20468] = true, [20469] = true, [20470] = true, [25780] = true, -- Paladin Righteous Fury
    [48263] = true,   -- Deathknight Blood Presence
    [407627] = true,  -- Paladin Righteous Fury (Season of Discovery)
    [408680] = true,  -- Shaman Way of Earth (Season of Discovery)
    [403789] = true,  -- Warlock Metamorphosis (Season of Discovery)
    -- Rogue tanks are detected using IsSpellKnown (as there is no buff for Just a Flesh Wound)
  }  
  function Addon:UNIT_AURA(event, unitid)
    for i = 1, 40 do
      local name , _, _, _, _, _, _, _, _, spellId = _G.UnitBuff("player", i, "PLAYER")
      if not name then
        break
      elseif TANK_AURA_SPELL_IDs[spellId] then
        Addon.PlayerIsTank = true
        return
      end
    end
  
    Addon.PlayerIsTank = false
  end

  function Addon:RUNE_UPDATED()
    Addon.PlayerIsTank = IsSpellKnown(400014, false) -- Just a Flesh Wound (Season of Discovery)
  end

  Addon.PLAYER_EQUIPMENT_CHANGED = Addon.RUNE_UPDATED

  if Addon.IS_CLASSIC_SOD and Addon.PlayerClass == "ROGUE" then
    RegisterEvent("RUNE_UPDATED")
    RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    -- As these events don't fire after login, call them directly to initialize Addon.PlayerIsTank
    Addon:RUNE_UPDATED()
  end  

  -- No need to check here for (Addon.IS_WRATH_CLASSIC and Addon.PlayerClass == "DEATHKNIGHT") as deathknights
  -- are only available in Wrath Classic
  local ENABLE_UNIT_AURA_FOR_CLASS = {
    PALADIN = Addon.ExpansionIsBetween(LE_EXPANSION_CLASSIC, LE_EXPANSION_LEGION),
    DEATHKNIGHT = Addon.ExpansionIsBetween(LE_EXPANSION_WRATH_OF_THE_LICH_KING, LE_EXPANSION_LEGION),
    -- For Season of Discovery
    SHAMAN = Addon.IS_CLASSIC_SOD,
    WARLOCK = Addon.IS_CLASSIC_SOD,
    ROGUE = Addon.IS_CLASSIC_SOD,
  }
  if ENABLE_UNIT_AURA_FOR_CLASS[Addon.PlayerClass] then
    Addon.EventService.SubscribeUnitEvent(Addon, "UNIT_AURA", "player")
    -- UNIT_AURA does not seem to be fired after login (even when buffs are active)
    UNIT_AURA()
  end
end

function Addon:EnableEvents()
  for index_or_event, value in pairs(ENABLED_EVENTS) do
    if type(index_or_event) == "number" then
      RegisterEvent(value)
    elseif value then
      RegisterEvent(index_or_event)
    end
  end
end

-- Does not seem to be necessary as the addon is disabled in general
--local function DisableEvents()
--  for i = 1, #EVENTS do
--    Addon:UnregisterEvent(EVENTS[i])
--  end
--end

