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
local GetNamePlates, GetNamePlateForUnit = C_NamePlate.GetNamePlates, C_NamePlate.GetNamePlateForUnit
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local IsInInstance, InCombatLockdown = IsInInstance, InCombatLockdown
local NamePlateDriverFrame, UnitNameplateShowsWidgetsOnly = NamePlateDriverFrame, UnitNameplateShowsWidgetsOnly
local GetSpecializationInfo, GetSpecialization = GetSpecializationInfo, GetSpecialization

-- ThreatPlates APIs
local ThreatPlates = Addon.ThreatPlates
local L = Addon.L
local Widgets = Addon.Widgets
local CVars = Addon.CVars
local RegisterEvent, UnregisterEvent = Addon.EventService.RegisterEvent, Addon.EventService.UnregisterEvent
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish
local TransliterateCyrillicLetters = Addon.Localization.TransliterateCyrillicLetters
local ThreatSetUnitAttribute, ThreatLeavingCombat, ThreatUpdate = Addon.Threat.SetUnitAttribute, Addon.Threat.LeavingCombat, Addon.Threat.Update
local SetOccludedTransparency = Addon.Transparency.SetOccludedTransparency
local ScalingHideNameplate = Addon.Scaling.HideNameplate
local SetCastbarColor = Addon.Color.SetCastbarColor
local SetNamesFonts = Addon.Font.SetNamesFonts
local CastTriggerCheckIfActive, CastTriggerUpdateStyle, CastTriggerReset = Addon.Style.CastTriggerCheckIfActive, Addon.Style.CastTriggerUpdateStyle, Addon.Style.CastTriggerReset

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

local IGNORED_UNITIDS = {
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
local LastTargetPlate, LastFocusPlate

-- External references to internal data
local PlatesCreated = Addon.PlatesCreated
local PlatesByUnit = Addon.PlatesByUnit
local PlatesByGUID = Addon.PlatesByGUID

---------------------------------------------------------------------------------------------------
-- Cached configuration settings (for performance reasons)
---------------------------------------------------------------------------------------------------
local SettingsShowEnemyBlizzardNameplates, SettingsShowFriendlyBlizzardNameplates, SettingsHideBuffsOnPersonalNameplate
local SettingsShowOnlyNames
local ShowCastBars

---------------------------------------------------------------------------------------------------
-- Wrapper functions for WoW Classic
---------------------------------------------------------------------------------------------------

if Addon.IS_CLASSIC then
  GetNameForNameplate = function(plate) return plate:GetName():gsub("NamePlate", "Plate") end
  UnitEffectiveLevel = function(...) return _G.UnitLevel(...) end

  UnitChannelInfo = function(...)
    local text, _, texture, startTime, endTime, _, _, _, spellID = Addon.LibClassicCasterino:UnitChannelInfo(...)

    -- With LibClassicCasterino, startTime is nil sometimes which means that no casting information
    -- is available
    if not startTime or not endTime then
      text = nil
    end

    return text, text, texture, startTime, endTime, false, false, spellID
  end

  UnitCastingInfo = function(...)
    local text, _, texture, startTime, endTime, _, _, _, spellID = Addon.LibClassicCasterino:UnitCastingInfo(...)

    -- With LibClassicCasterino, startTime is nil sometimes which means that no casting information
    -- is available
    if not startTime or not endTime then
      text = nil
    end

    return text, text, texture, startTime, endTime, false, nil, false, spellID
  end

  -- Not available in Classic, introduced in patch 9.0.1
  UnitNameplateShowsWidgetsOnly = function() return false end
elseif Addon.IS_TBC_CLASSIC then
  GetNameForNameplate = function(plate) return plate:GetName() end
  UnitEffectiveLevel = function(...) return _G.UnitLevel(...) end

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

  -- Not available in BC Classic, introduced in patch 9.0.1
  UnitNameplateShowsWidgetsOnly = function() return false end
elseif Addon.IS_WRATH_CLASSIC then
  GetNameForNameplate = function(plate) return plate:GetName() end
  UnitEffectiveLevel = function(...) return _G.UnitLevel(...) end

  UnitCastingInfo = _G.UnitCastingInfo

  -- Not available in WotLK Classic, introduced in patch 9.0.1
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

local function IsMentorMarkerIcon(target_marker)
  return target_marker == "MURLOC" or target_marker == "GREEN_FLAG"
end

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
  if IGNORED_UNITIDS[unitid] or UnitIsUnit("player", unitid) then return end

  -- Special unitids (target, personal nameplate) are skipped as they are not added to PlatesByUnit in NAME_PLATE_UNIT_ADDED
  local tp_frame = self.PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    return tp_frame
  end
end

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
  unit.TargetMarkerIcon = TARGET_MARKER_LIST[raid_icon_index]
  unit.MentorIcon = MENTOR_ICON_LIST[raid_icon_index]
end

local function SetUnitAttributes(unit, unitid)
  -- Unit data that does not change after nameplate creation
  unit.unitid = unitid
  unit.guid = _G.UnitGUID(unitid)

  unit.isBoss = UnitEffectiveLevel(unitid) == -1

  unit.classification = (unit.isBoss and "boss") or _G.UnitClassification(unitid)
  unit.isElite = ELITE_REFERENCE[unit.classification] or false
  unit.isRare = RARE_REFERENCE[unit.classification] or false
  unit.isMini = (unit.classification == "minus")
  unit.IsBossOrRare = (unit.isBoss or unit.isRare)

  if UnitIsPlayer(unitid) then
    local _, unit_class = UnitClass(unitid)
    unit.class = unit_class
    unit.type = "PLAYER"
  else
    unit.class = ""
    unit.type = "NPC"

    local _, _, _, _, _, npc_id = strsplit("-", unit.guid or "")
    unit.NPCID = npc_id
  end

  SetUnitAttributeReaction(unit, unitid)
  SetUnitAttributeLevel(unit, unitid)
  SetUnitAttributeName(unit, unitid)
  SetUnitAttributeHealth(unit, unitid)

  -- Casting => UNIT_SPELLCAST_*
  -- Initialized in OnUpdateCastMidway in OnShowNameplate, but only when unit is currently casting
  unit.isCasting = false
  unit.IsInterrupted = false

  -- Target, Focus, and Mouseover => PLAYER_TARGET_CHANGED, UPDATE_MOUSEOVER_UNIT, PLAYER_FOCUS_CHANGED
  unit.isTarget = UnitIsUnit("target", unitid)
  unit.IsFocus = UnitIsUnit("focus", unitid) -- required here for config changes which reset all plates without calling TARGET_CHANGED, MOUSEOVER, ...
  unit.isMouseover = UnitIsUnit("mouseover", unitid)
 
  -- Target Mark => RAID_TARGET_UPDATE
  SetUnitAttributeTargetMarker(unit, unitid)
end

---------------------------------------------------------------------------------------------------------------------
-- Nameplate Updating:
---------------------------------------------------------------------------------------------------------------------

-- OnShowCastbar
local function OnStartCasting(tp_frame, unitid, channeled)
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
    name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, _, numStages = UnitChannelInfo(unitid)
  else
    name, text, texture, startTime, endTime, isTradeSkill, _, notInterruptible, spellID = UnitCastingInfo(unitid)
  end

  if not name or isTradeSkill then
    castbar:Hide()
    return 
  end

  CastTriggerCheckIfActive(unit, spellID, name)

  -- Abort here as casts can now switch nameplate styles (e.g,. from headline to healthbar view
  if not style.castbar.show and not unit.CustomStyleCast then
    castbar:Hide()
    return
  end

  unit.isCasting = true
  unit.IsInterrupted = false
  unit.spellIsShielded = notInterruptible

  if CastTriggerUpdateStyle(unit) then
    StyleModule:Update(tp_frame)
    -- style = tp_frame.style
  end

  visual.SpellText:SetText(text)
  visual.SpellIcon:SetTexture(texture)

  local target_unit_name = UnitName(unit.unitid .. "target")
  -- There are situations when UnitName returns nil (OnHealthUpdate, hypothesis: health update when the unit died tiggers this, but then there is no target any more)
  if target_unit_name then
    local _, class_name = UnitClass(target_unit_name)
    castbar.CastTarget:SetText(Addon.ColorByClass(class_name, TransliterateCyrillicLetters(target_unit_name)))
  else
    castbar.CastTarget:SetText(nil)
  end

  -- Although Evoker's empowered casts are considered channeled, time (and therefore growth direction)
  -- is calculated like for normal casts. Therefore: castbar.IsCasting = true
  castbar.IsCasting = not channeled or (numStages and numStages > 0)
  castbar.IsChanneling = not castbar.IsCasting

  -- Sometimes startTime/endTime are nil (even in Retail). Not sure if name is always nil is this case as well, just to be sure here
  -- I think this should not be necessary, name should be nil in this case, but not sure.
  endTime = endTime or 0
  startTime = startTime or 0
  if castbar.IsChanneling then
    castbar.Value = (endTime / 1000) - GetTime()
  else
    castbar.Value = GetTime() - (startTime / 1000)
  end
  castbar.MaxValue = (endTime - startTime) / 1000
  castbar:SetMinMaxValues(0, castbar.MaxValue)
  castbar:SetValue(castbar.Value)
  castbar:SetAllColors(SetCastbarColor(unit))
  castbar:SetFormat(unit.spellIsShielded)

  -- Only publish this event once (OnStartCasting is called for re-freshing as well)
  if not castbar:IsShown() then
    PublishEvent("CastingStarted", tp_frame)
  end

  castbar:Show()
end

local function OnUpdateCastMidway(tp_frame, unitid)
  if not ShowCastBars then return end

  -- Check to see if there's a spell being cast
  if UnitCastingInfo(unitid) then
    OnStartCasting(tp_frame, unitid, false)
  elseif UnitChannelInfo(unitid) then
    OnStartCasting(tp_frame, unitid, true)
  else
    -- It would be better to check for IsInterrupted here and not hide it if that is true
    -- Not currently sure though, if that might work with the Hide() calls in OnStartCasting
    tp_frame.visual.CastbaMor:Hide()
  end
end

---------------------------------------------------------------------------------------------------------------------
-- Create / Hide / Show Event Handlers
---------------------------------------------------------------------------------------------------------------------

local function IgnoreUnitForThreatPlates(unitid)
  return UnitIsUnit("player", unitid) or UnitNameplateShowsWidgetsOnly(unitid) or not UnitExists(unitid)
end

-- local function HideNameplate(plate)
--   plate.UnitFrame:Hide()
--   plate.TPFrame:Hide()
--   plate.TPFrame.Active = false
-- end

local function ShowBlizzardNameplate(plate, show_blizzard_plate)
  plate.UnitFrame:SetShown(show_blizzard_plate)
  plate.TPFrame:SetShown(not show_blizzard_plate)
  plate.TPFrame.Active = not show_blizzard_plate
end

-- This function should only be called for visible nameplates: PlatesVisible[plate] ~= nil
local function SetNameplateVisibility(plate, unitid)
  -- ! Interactive objects do also have nameplates. We should not mess with the visibility the of these objects.
  -- if not PlatesVisible[plate] then return end
  
  -- We cannot use unit.reaction here as it is not guaranteed that it's update whenever this function 
  -- is called (see UNIT_FACTION).  
  local unit_reaction = UnitReaction("player", unitid) or 0
  if unit_reaction > 4 then
    ShowBlizzardNameplate(plate, SettingsShowFriendlyBlizzardNameplates)
  else
    ShowBlizzardNameplate(plate, SettingsShowEnemyBlizzardNameplates)
  end
end

local	function HandlePlateCreated(plate)
  -- Parent could be: WorldFrame, UIParent, plate
  local tp_frame = _G.CreateFrame("Frame",  "ThreatPlatesFrame" .. GetNameForNameplate(plate), WorldFrame)
  tp_frame:Hide()
  tp_frame:SetFrameStrata("BACKGROUND")
  tp_frame:EnableMouse(false)
  tp_frame.Parent = plate
  plate.TPFrame = tp_frame

  -- Tidy Plates Frame References
  tp_frame.visual = {}
  -- Allocate Tables
  tp_frame.style = {}
  tp_frame.unit = {}

  local textframe = _G.CreateFrame("Frame", nil, tp_frame)
  textframe:SetAllPoints()
  tp_frame.visual.textframe = textframe

  -- Create graphical elements and widgets
  ElementsPlateCreated(tp_frame)
  Widgets:OnPlateCreated(tp_frame)
end

-- OnShowNameplate
local function HandlePlateUnitAdded(plate, unitid)
  local tp_frame = plate.TPFrame
  local unit = tp_frame.unit

  -- Set unit attributes
  -- Update modules, then elements, then widgets

  -- Initialize unit data for which there are no events when players enters world or that
  -- do not change over the nameplate lifetime
  SetUnitAttributes(unit, unitid)
  ThreatSetUnitAttribute(tp_frame)

  PlatesByUnit[unitid] = tp_frame
  PlatesByGUID[unit.guid] = plate

  -- Update LastTargetPlate as target units may leave the screen, lose their nameplate and
  -- get a new one when the enter the screen again
  if unit.isTarget then
    LastTargetPlate = tp_frame
  end

  SetNameplateVisibility(plate, unitid)

  -- Initialized nameplate style based on unit added
  StyleModule:PlateUnitAdded(tp_frame)
  -- TODO: This is not ideal/correct as Style:Update calls ElementsUpdateStyle
  ElementsPlateUnitAdded(tp_frame)

  -- Call this after the plate is shown as OnStartCasting checks if the plate is shown; if not, the castbar is hidden and
  -- nothing is updated
  OnUpdateCastMidway(tp_frame, unitid)
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
          bgFile = ThreatPlates.Art .. "TP_WhiteSquare.tga",
          edgeFile = ThreatPlates.Art .. "TP_WhiteSquare.tga",
          edgeSize = 2,
          insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        tp_frame.Background:SetBackdropColor(0,0,0,.3)
        tp_frame.Background:SetBackdropBorderColor(0, 0, 0, 0.8)
        tp_frame.Background:SetPoint("CENTER", ConfigModePlate.UnitFrame, "CENTER")

        local width, height
        if ConfigModePlate.unit.reaction == "FRIENDLY" then          
          width, height = C_NamePlate.GetNamePlateFriendlySize()
        else
          width, height = C_NamePlate.GetNamePlateEnemySize()
        end
        ConfigModePlate.Background:SetSize(width, height)

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
    background:SetSize(Addon.db.profile.settings.frame.width, Addon.db.profile.settings.frame.height)
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

  if db.settings.castnostop.ShowInterruptSource then
    RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  else
    UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  end

  ShowCastBars = db.settings.castbar.show or db.settings.castbar.ShowInHeadlineView
  
  -- ? Not sure if this is still necessary after moving registering events to Addon.lua - OnInitialize
  if not (Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC) then
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

local function ClassicBlizzardNameplatesSetAlpha(UnitFrame, alpha)
  if Addon.WOW_USES_CLASSIC_NAMEPLATES then
    UnitFrame.LevelFrame:SetAlpha(alpha)
  else
    UnitFrame.ClassificationFrame:SetAlpha(alpha)
  end
end

function Addon:ForceUpdateFrameOnShow()
  SettingsShowOnlyNames = CVars:GetAsBool("nameplateShowOnlyNames") and Addon.db.profile.BlizzardSettings.Names.Enabled
  for plate, _ in pairs(Addon.PlatesVisible) do
    ClassicBlizzardNameplatesSetAlpha(plate.UnitFrame, SettingsShowOnlyNames and 0 or 1)
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

local function FrameOnShow(UnitFrame)
  local unitid = UnitFrame.unit

  -- Hide nameplates that have not yet an unit added
  if not unitid then 
    -- ? Not sure if Hide() is really needed here or if even TPFrame should also be hidden here ...
    UnitFrame:Hide()
    return
  end

  -- Don't show ThreatPlates for ignored units (e.g., widget-only nameplates (since Shadowlands))
  if IgnoreUnitForThreatPlates(unitid) then
    UnitFrame:GetParent().TPFrame:Hide()
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
  
    -- Hide ThreatPlates nameplates if Blizzard nameplates should be shown for friendly units
    -- Not sure if unit.reaction will always be correctly set here, so:
    local unit_reaction = UnitReaction("player", unitid) or 0
    if unit_reaction > 4 then
      UnitFrame:SetShown(SettingsShowFriendlyBlizzardNameplates)
    else
      UnitFrame:SetShown(SettingsShowEnemyBlizzardNameplates)
    end
  end
end

-- Frame: self = plate
local function FrameOnUpdate(plate, elapsed)
  -- Skip nameplates not handled by TP: Blizzard default plates (if configured) and the personal nameplate
  local tp_frame = plate.TPFrame
  if not tp_frame.Active or UnitIsUnit(plate.UnitFrame.unit or "", "player") then
    return
  end

  tp_frame:SetFrameLevel(plate:GetFrameLevel() * 10)

  --    for i = 1, #PlateOnUpdateQueue do
  --      PlateOnUpdateQueue[i](plate, tp_frame.unit)
  --    end

  ScalingHideNameplate(tp_frame)
  -- Do this after the hiding stuff, to correctly set the occluded transparency
  SetOccludedTransparency(tp_frame)
end

-- Frame: self = plate
local function FrameOnHide(plate)
  plate.TPFrame:Hide()
end

--------------------------------------------------------------------------------------------------------------
-- WoW Event Handling: Event handling functions
--------------------------------------------------------------------------------------------------------------

local function NamePlateDriverFrame_AcquireUnitFrame(_, plate)
  local unit_frame = plate.UnitFrame
  if not unit_frame:IsForbidden() and not unit_frame.ThreatPlates then
    unit_frame.ThreatPlates = true
    unit_frame:HookScript("OnShow", FrameOnShow)
  end
end

function Addon:PLAYER_LOGIN(...)
  -- Fix for Blizzard default plates being shown at random times
  -- Works for Mainline and Wrath Classic
  if NamePlateDriverFrame and NamePlateDriverFrame.AcquireUnitFrame then
    hooksecurefunc(NamePlateDriverFrame, "AcquireUnitFrame", NamePlateDriverFrame_AcquireUnitFrame)
  end
end

--function Addon:PLAYER_LOGOUT(...)
--end

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
  local db = Addon.db.profile.questWidget
  if not (Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC) then
    if db.ON or db.ShowInHeadlineView then
      self.CVars:Set("showQuestTrackingTooltips", 1)
      --_G.SetCVar("showQuestTrackingTooltips", 1)
    else
      self.CVars:RestoreFromProfile("showQuestTrackingTooltips")
    end
  end

  -- This code must be executed every time the player enters a instance (dungeon, raid, ...)
  db = Addon.db.profile.Automation
  
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
  ThreatLeavingCombat()
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

  -- NamePlateDriverFrame.AcquireUnitFrame is not used in Classic
  if (Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC) and plate.UnitFrame then
    NamePlateDriverFrame_AcquireUnitFrame(nil, plate)
  end

  plate:HookScript('OnHide', FrameOnHide)
  plate:HookScript('OnUpdate', FrameOnUpdate)
  
  PlatesCreated[plate] = plate.TPFrame
end

-- Payload: { Name = "unitToken", Type = "string", Nilable = false },
function Addon:NAME_PLATE_UNIT_ADDED(unitid)
    -- Player's personal nameplate:
  --   This nameplate is currently not handled by Threat Plates - OnShowNameplate is not called on it, therefore plate.TPFrame.Active is nil
  -- Nameplates for non-existing units:
  --   There are some nameplates for units that do not exists, e.g. Ring of Transference in Oribos. For the time being, we don't show them.
  --   Without not UnitExists(unitid) they would be shown as nameplates with health 0 and maybe cause Lua errors

  if not IgnoreUnitForThreatPlates(unitid) then
    HandlePlateUnitAdded(GetNamePlateForUnit(unitid), unitid)
  end
end

function Addon:NAME_PLATE_UNIT_REMOVED(unitid)
  local plate = GetNamePlateForUnit(unitid)
  local tp_frame = plate.TPFrame

  tp_frame.Active = false

  -- Update LastTargetPlate as target units may leave the screen, lose their nameplate and
  -- get a new one when the enter the screen again
  if tp_frame.unit.isTarget then
    LastTargetPlate = nil
  end

  PlatesByUnit[unitid] = nil
  if tp_frame.unit.guid then -- maybe hide directly after create with unit added?
    PlatesByGUID[tp_frame.unit.guid] = nil
  end

  ElementsPlateUnitRemoved(tp_frame)
  Widgets:OnUnitRemoved(tp_frame, tp_frame.unit)

  wipe(tp_frame.unit)

  -- Set stylename to nil as CheckNameplateStyle compares the new style with the previous style.
  -- If both are unique, the nameplate is not updated to the correct custom style, but uses the
  -- previous one, I think
  tp_frame.stylename = nil
end

function Addon:UNIT_NAME_UPDATE(unitid)
  local tp_frame = self:GetThreatPlateForUnit(unitid)
  if tp_frame then
    SetUnitAttributeName(tp_frame.unit, unitid)
    StyleModule:UpdateName(tp_frame)
  end
end

function Addon:PLAYER_TARGET_CHANGED()
  -- If the previous target unit's nameplate is still shown, update it:
    if LastTargetPlate and LastTargetPlate.Active then
      LastTargetPlate.unit.isTarget = false
      PublishEvent("TargetLost", LastTargetPlate)

      LastTargetPlate = nil
    end

    local plate = GetNamePlateForUnit("target")
    --if plate and plate.TPFrame and plate.TPFrame.stylename ~= "" then
    if plate and plate.TPFrame.Active then
      LastTargetPlate = plate.TPFrame

      LastTargetPlate.unit.isTarget = true
      PublishEvent("TargetGained", LastTargetPlate)
    end
end

local function PLAYER_FOCUS_CHANGED()
  if LastFocusPlate and LastFocusPlate.Active then
    LastFocusPlate.unit.IsFocus = false
    PublishEvent("FocusLost", LastTargetPlate)

    LastFocusPlate = nil
  end

  local plate = GetNamePlateForUnit("focus")
  if plate and plate.TPFrame.Active then
    LastFocusPlate = plate.TPFrame

    LastFocusPlate.unit.IsFocus = true
    PublishEvent("FocusGained", LastTargetPlate)
  end
end

function Addon:RAID_TARGET_UPDATE()
  for unitid, tp_frame in self:GetActiveThreatPlates() do
    local unit = tp_frame.unit

    -- Only update plates that changed
    local previous_target_marker_icon = unit.TargetMarkerIcon
    local previous_mentor_icon = unit.MentorIcon
    local previous_icon = unit.TargetMarkerIcon or unit.MentorIcon
    SetUnitAttributeTargetMarker(unit, unitid)
    if previous_target_marker_icon ~= unit.TargetMarkerIcon or previous_mentor_icon ~= unit.MentorIcon then
      PublishEvent("TargetMarkerUpdate", tp_frame)
    end
  end
end

local function UNIT_HEALTH(unitid)
  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    SetUnitAttributeHealth(tp_frame.unit, unitid)  
  end
end

function Addon:UNIT_MAXHEALTH(unitid)
  local tp_frame = self:GetThreatPlateForUnit(unitid)
  if tp_frame then
    SetUnitAttributeHealth(tp_frame.unit, unitid)  
  end
end

function Addon:UNIT_THREAT_LIST_UPDATE(unitid)
  local tp_frame = self:GetThreatPlateForUnit(unitid)
  if tp_frame then
    ThreatUpdate(tp_frame)
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
    for unitid, tp_frame in pairs(PlatesByUnit) do
      SetNameplateVisibility(tp_frame.Parent, unitid)
    end

    for unitid_frame, tp_frame in self:GetActiveThreatPlates() do
      SetUnitAttributeReaction(tp_frame.unit, unitid_frame)
      StyleModule:Update(tp_frame)
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
        StyleModule:Update(tp_frame)
        PublishEvent("FactionUpdate", tp_frame)
      end
    end
  end
end

function Addon:UNIT_LEVEL(unitid)
  local tp_frame = self:GetThreatPlateForUnit(unitid)
  if tp_frame then
    SetUnitAttributeLevel(tp_frame.unit, unitid)
  end
end

local function UNIT_SPELLCAST_START(unitid, ...)
  -- Special unitids (target, personal nameplate) are skipped as they are not added to PlatesByUnit in NAME_PLATE_UNIT_ADDED
  if not ShowCastBars then return end

  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    OnStartCasting(tp_frame, unitid, false)
  end
end

-- Update spell currently being cast
local function UnitSpellcastMidway(unitid, ...)
  -- Special unitids (target, personal nameplate) are skipped as they are not added to PlatesByUnit in NAME_PLATE_UNIT_ADDED
  if not ShowCastBars then return end

  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    OnUpdateCastMidway(tp_frame, unitid)
  end
end

-- Used for UNIT_SPELLCAST_STOP and UNIT_SPELLCAST_CHANNEL_STOP
local function UNIT_SPELLCAST_STOP(unitid, ...)
  -- Special unitids (target, personal nameplate) are skipped as they are not added to PlatesByUnit in NAME_PLATE_UNIT_ADDED
  if not ShowCastBars then return end

  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    tp_frame.unit.isCasting = false

    local castbar = tp_frame.visual.Castbar
    castbar.IsChanneling = false
    castbar.IsCasting = false

    if CastTriggerReset() then
      StyleModule:Update(tp_frame)
    end

    PublishEvent("CastingStopped", tp_frame)
  end
end

local function UNIT_SPELLCAST_CHANNEL_START(unitid, ...)
  -- Special unitids (target, personal nameplate) are skipped as they are not added to PlatesByUnit in NAME_PLATE_UNIT_ADDED
  if not ShowCastBars then return end

  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    OnStartCasting(tp_frame, unitid, true)
  end
end

local UNIT_SPELLCAST_CHANNEL_STOP = UNIT_SPELLCAST_STOP

--  function CoreEvents:UNIT_SPELLCAST_INTERRUPTED(unitid, lineid, spellid)
--    if unitid == "target" or UnitIsUnit("player", unitid) or not ShowCastBars then return end
--  end

function Addon.UNIT_SPELLCAST_INTERRUPTED(event, unitid, castGUID, spellID, sourceName, interrupterGUID)
  -- Special unitids (target, personal nameplate) are skipped as they are not added to PlatesByUnit in NAME_PLATE_UNIT_ADDED
  if not ShowCastBars then return end

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

function Addon:UI_SCALE_CHANGED()
  Addon:ForceUpdate()
end

---------------------------------------------------------------------------------------------------------------------
-- Handling of WoW events
---------------------------------------------------------------------------------------------------------------------

local ENABLED_EVENTS = {
  "PLAYER_ENTERING_WORLD",
  "PLAYER_LOGIN",
  -- "PLAYER_LOGOUT",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_REGEN_DISABLED",

  "NAME_PLATE_CREATED",
  "NAME_PLATE_UNIT_ADDED",
  "NAME_PLATE_UNIT_REMOVED",

  "PLAYER_TARGET_CHANGED",
  "PLAYER_FOCUS_CHANGED",
  UPDATE_MOUSEOVER_UNIT = Addon.Elements.GetElement("MouseoverHighlight").UPDATE_MOUSEOVER_UNIT,
  "RAID_TARGET_UPDATE",

  "UNIT_NAME_UPDATE",
  "UNIT_MAXHEALTH",
  "UNIT_THREAT_LIST_UPDATE",
  "UNIT_FACTION",
  "UNIT_LEVEL",
  
  --PLAYER_CONTROL_LOST = ..., -- Does not seem to be necessary
  --PLAYER_CONTROL_GAINED = ...,  -- Does not seem to be necessary

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

-- Only registered for player unit
local TANK_AURA_SPELL_IDs = {
  [20468] = true, [20469] = true, [20470] = true, [25780] = true, -- Paladin Righteous Fury
  [48263] = true -- Deathknight Frost Presence
}
local function UNIT_AURA(event, unitid)
  local _, name, spellId
  for i = 1, 40 do
    name , _, _, _, _, _, _, _, _, spellId = _G.UnitBuff("player", i, "PLAYER")
    if not name then
      break
    elseif TANK_AURA_SPELL_IDs[spellId] then
      Addon.PlayerIsTank = true
      return
    end
  end

  Addon.PlayerIsTank = false
end

-- For Classic and TBC Classic, player role must be determined based on standes:
if Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC then
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

  -- Do this after events are registered, otherwise UNIT_AURA would be registered as a general event, not only as
  -- an unit event.
  -- No need to check here for (Addon.IS_WRATH_CLASSIC and Addon.PlayerClass == "DEATHKNIGHT") as deathknights
  -- are only available in Wrath Classic
  if Addon.PlayerClass == "PALADIN" or Addon.PlayerClass == "DEATHKNIGHT" then
    Addon.UNIT_AURA = UNIT_AURA
    Addon.EventService.SubscribeUnitEvent(Addon, "UNIT_AURA", "player")
    -- UNIT_AURA does not seem to be fired after login (even when buffs are active)
    UNIT_AURA()
  end
else
  function Addon:ACTIVE_TALENT_GROUP_CHANGED()
    local player_specialization = GetSpecialization()
    if player_specialization then
      local db = Addon.db
      if db.profile.optionRoleDetectionAutomatic then
        local role = select(5, GetSpecializationInfo(player_specialization))
        Addon.PlayerRole = (role == "TANK" and "tank") or "dps"
      else
        local role = db.char.spec[player_specialization]
        Addon.PlayerRole = (role == true and "tank") or "dps"
      end
    end
  end
  
  function Addon.GetPlayerRole()
    return Addon.PlayerRole
  end
  
  ENABLED_EVENTS.ACTIVE_TALENT_GROUP_CHANGED = Addon.ACTIVE_TALENT_GROUP_CHANGED
end

if Addon.IS_CLASSIC then
    -- Events for LibClassicCasterion
  Addon.UNIT_SPELLCAST_START = function(event, ...) UNIT_SPELLCAST_START(...) end
  Addon.UNIT_SPELLCAST_STOP = function(event, ...) UNIT_SPELLCAST_STOP(...) end
  Addon.UNIT_SPELLCAST_CHANNEL_START = function(event, ...) UNIT_SPELLCAST_CHANNEL_START(...) end
  Addon.UNIT_SPELLCAST_CHANNEL_STOP = function(event, ...) UNIT_SPELLCAST_CHANNEL_STOP(...) end
  Addon.UnitSpellcastMidway = function(event, ...) UnitSpellcastMidway(...) end
  ENABLED_EVENTS.UNIT_HEALTH_FREQUENT = UNIT_HEALTH
else
  -- The following events should not have worked before adjusting UnitSpellcastMidway
  ENABLED_EVENTS.UNIT_SPELLCAST_START = UNIT_SPELLCAST_START
  ENABLED_EVENTS.UNIT_SPELLCAST_DELAYED = UnitSpellcastMidway
  ENABLED_EVENTS.UNIT_SPELLCAST_STOP = UNIT_SPELLCAST_STOP

  ENABLED_EVENTS.UNIT_SPELLCAST_CHANNEL_START = UNIT_SPELLCAST_CHANNEL_START
  ENABLED_EVENTS.UNIT_SPELLCAST_CHANNEL_UPDATE = UnitSpellcastMidway
  ENABLED_EVENTS.UNIT_SPELLCAST_CHANNEL_STOP = UNIT_SPELLCAST_CHANNEL_STOP

  -- UNIT_SPELLCAST_SUCCEEDED
  -- UNIT_SPELLCAST_FAILED
  -- UNIT_SPELLCAST_FAILED_QUIET
  -- UNIT_SPELLCAST_INTERRUPTED - handled by COMBAT_LOG_EVENT_UNFILTERED / SPELL_INTERRUPT as it's the only way to find out the interruptorom
  -- UNIT_SPELLCAST_SENT

  ENABLED_EVENTS.PLAYER_FOCUS_CHANGED = PLAYER_FOCUS_CHANGED

  if Addon.IS_MAINLINE then
    ENABLED_EVENTS.UNIT_SPELLCAST_INTERRUPTIBLE = UnitSpellcastMidway
    ENABLED_EVENTS.UNIT_SPELLCAST_NOT_INTERRUPTIBLE = UnitSpellcastMidway

    ENABLED_EVENTS.UNIT_SPELLCAST_EMPOWER_START = UNIT_SPELLCAST_CHANNEL_START
    ENABLED_EVENTS.UNIT_SPELLCAST_EMPOWER_UPDATE = UnitSpellcastMidway
    ENABLED_EVENTS.UNIT_SPELLCAST_EMPOWER_STOP = UNIT_SPELLCAST_CHANNEL_STOP

    -- ENABLED_EVENTS.PLAYER_SOFT_FRIEND_CHANGED = PLAYER_SOFT_FRIEND_CHANGED
    -- ENABLED_EVENTS.PLAYER_SOFT_ENEMY_CHANGED = PLAYER_SOFT_ENEMY_CHANGED
    -- ENABLED_EVENTS.PLAYER_SOFT_INTERACT_CHANGED = PLAYER_SOFT_INTERACT_CHANGED

    -- UNIT_HEALTH_FREQUENT no longer supported in Retail since 9.0.1
    ENABLED_EVENTS.UNIT_HEALTH = UNIT_HEALTH -- UNIT_HEALTH_FREQUENT no longer supported in Retail since 9.0.1
  else
    ENABLED_EVENTS.UNIT_HEALTH_FREQUENT = UNIT_HEALTH
  end
end

function Addon:EnableEvents()
  for index, event_or_func in pairs(ENABLED_EVENTS) do
    if type(index) == "number" then
      RegisterEvent(event_or_func)
    else
      RegisterEvent(index, event_or_func)
    end
  end
end

-- Does not seem to be necessary as the addon is disabled in general
--local function DisableEvents()
--  for i = 1, #EVENTS do
--    Addon:UnregisterEvent(EVENTS[i])
--  end
--end

