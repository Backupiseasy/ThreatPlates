local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------------------------
-- Variables and References
---------------------------------------------------------------------------------------------------------------------

-- Lua APIs
local _
local type, select, pairs, tostring  = type, select, pairs, tostring 			    -- Local function copy
local max, gsub, tonumber, math_abs = math.max, string.gsub, tonumber, math.abs

-- WoW APIs
local wipe, strsplit = wipe, strsplit
local WorldFrame, UIParent, INTERRUPTED = WorldFrame, UIParent, INTERRUPTED
local UnitName, UnitReaction, UnitClass, UnitPVPName = UnitName, UnitReaction, UnitClass, UnitPVPName
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
local ElementsCreated, ElementsUnitAdded, ElementsUnitRemoved = Addon.Elements.Created, Addon.Elements.UnitAdded, Addon.Elements.UnitRemoved
local ElementsUpdateStyle, ElementsUpdateSettings = Addon.Elements.UpdateStyle, Addon.Elements.UpdateSettings
local Threat, Style, Localization = Addon.Threat, Addon.Style, Addon.Localization
local Scaling, Transparency, Animations, Icons, Font = Addon.Scaling, Addon.Transparency, Addon.Animations, Addon.Icons, Addon.Font
local BackdropTemplate = Addon.BackdropTemplate

local GetNameForNameplate
local UnitCastingInfo

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, UnitAffectingCombat, UnitCastingInfo, UnitClassification, UnitGUID, UnitHealth, UnitHealthMax, UnitIsTapDenied, UnitLevel, UnitSelectionColor

-- Constants
local CASTBAR_INTERRUPT_HOLD_TIME = Addon.CASTBAR_INTERRUPT_HOLD_TIME

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
else
  GetNameForNameplate = function(plate) return plate:GetName() end

  UnitCastingInfo = function(...) return _G.UnitCastingInfo(...) end
end

---------------------------------------------------------------------------------------------------------------------
--  Initialize unit data after NAME_PLATE_UNIT_ADDED and update it
---------------------------------------------------------------------------------------------------------------------
local RAID_ICON_LIST = { "STAR", "CIRCLE", "DIAMOND", "TRIANGLE", "MOON", "SQUARE", "CROSS", "SKULL" }

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
-- if not unitid or unitid == "player" or UnitIsUnit("player", unitid) then return end
-- local plate = GetNamePlateForUnit(unitid)

-- Special unitids (target, personal nameplate) are skipped as they are not added to PlatesByUnit in NAME_PLATE_UNIT_ADDED
local tp_frame = self.PlatesByUnit[unitid]
if tp_frame and tp_frame.Active then
  return tp_frame
end
end

function Addon:GetThreatPlateForGUID(guid)
local plate = self.PlatesByGUID[guid]
if plate and plate.TPFrame.Active then
  return plate.TPFrame
end
end

---------------------------------------------------------------------------------------------------------------------
-- Functions for setting unit attributes
---------------------------------------------------------------------------------------------------------------------

local function SetUnitAttributeName(unit, unitid)
  -- Can be UNKNOWNOBJECT => UNIT_NAME_UPDATE
  local unit_name, realm = UnitName(unitid)

  if unit.type == "PLAYER" then
    local db = Addon.db.profile.settings.name

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
  unit.reaction = MAP_UNIT_REACTION[UnitReaction(unitid, "player")] or GetReactionByColor(unit.red, unit.green, unit.blue)

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

local function InitializeUnit(unit, unitid)
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
  unit.TargetMarker = RAID_ICON_LIST[GetRaidTargetIndex(unitid)]

  Threat:SetUnitAttributeThreat(unit, unitid)
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

  local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID
  if channeled then
    name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(unitid)
  else
    name, text, texture, startTime, endTime, isTradeSkill, _, notInterruptible, spellID = UnitCastingInfo(unitid)
  end

  if not name or isTradeSkill then
    castbar:Hide()
    return 
  end

  unit.isCasting = true
  unit.IsInterrupted = false
  unit.spellIsShielded = notInterruptible

  local plate_style = Addon.ActiveCastTriggers and Style:ProcessCastTriggers(unit, spellID, name)
  if plate_style and plate_style ~= tp_frame.stylename then
    Style:Update(tp_frame)
    style = tp_frame.style
  end

  -- Custom nameplates might trigger cause of a cast, but still stay in a style that does not
  -- show the castbar
  if not style.castbar.show then
    castbar:Hide()
    return
  end

  visual.SpellText:SetText(text)
  visual.SpellIcon:SetTexture(texture)

  local target_unit_name = UnitName(unit.unitid .. "target")
  -- There are situations when UnitName returns nil (OnHealthUpdate, hypothesis: health update when the unit died tiggers this, but then there is no target any more)
  if target_unit_name then
    local _, class_name = UnitClass(target_unit_name)
    castbar.CastTarget:SetText(Addon.ColorByClass(class_name, Localization:TransliterateCyrillicLetters(target_unit_name)))
  else
    castbar.CastTarget:SetText(nil)
  end

  castbar.IsCasting = not channeled
  castbar.IsChanneling = channeled

  -- Sometimes startTime/endTime are nil (even in Retail). Not sure if name is always nil is this case as well, just to be sure here
  -- I think this should not be necessary, name should be nil in this case, but not sure.
  endTime = endTime or 0
  startTime = startTime or 0
  if channeled then
    castbar.Value = (endTime / 1000) - GetTime()
  else
    castbar.Value = GetTime() - (startTime / 1000)
  end
  castbar.MaxValue = (endTime - startTime) / 1000
  castbar:SetMinMaxValues(0, castbar.MaxValue)
  castbar:SetValue(castbar.Value)
  castbar:SetAllColors(Addon:SetCastbarColor(unit))
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
    tp_frame.visual.Castbar:Hide()
  end
end

---------------------------------------------------------------------------------------------------------------------
--  Nameplate Styler: These functions parses the definition table for a nameplate's requested style.
---------------------------------------------------------------------------------------------------------------------

local function UpdateStyle(tp_frame, style, stylename)
  -- Frame
  tp_frame:ClearAllPoints()
  tp_frame:SetPoint(style.frame.anchor, tp_frame.Parent, style.frame.anchor, style.frame.x, style.frame.y)
  tp_frame:SetSize(style.healthbar.width, style.healthbar.height)

  ElementsUpdateStyle(tp_frame, style)
  Widgets:OnUnitAdded(tp_frame, tp_frame.unit)

--  if not tp_frame.TestBackground then
--    tp_frame.TestBackground = tp_frame:CreateTexture(nil, "BACKGROUND")
--    tp_frame.TestBackground:SetAllPoints(tp_frame)
--    tp_frame.TestBackground:SetTexture(Addon.LibSharedMedia:Fetch('statusbar', Addon.db.profile.AuraWidget.BackgroundTexture))
--    tp_frame.TestBackground:SetVertexColor(0,0,0,0.5)
--  end
end

SubscribeEvent(Addon, "StyleUpdate", UpdateStyle)

---------------------------------------------------------------------------------------------------------------------
-- Create / Hide / Show Event Handlers
---------------------------------------------------------------------------------------------------------------------

local function UpdateNameplateStyle(plate, unitid)
  if UnitReaction(unitid, "player") > 4 then
    if SettingsShowFriendlyBlizzardNameplates then
      plate.UnitFrame:Show()
      plate.TPFrame:Hide()
      plate.TPFrame.Active = false
    else
      plate.UnitFrame:Hide()
      plate.TPFrame:Show()
      plate.TPFrame.Active = true
    end
  elseif SettingsShowEnemyBlizzardNameplates then
    plate.UnitFrame:Show()
    plate.TPFrame:Hide()
    plate.TPFrame.Active = false
  else
    plate.UnitFrame:Hide()
    plate.TPFrame:Show()
    plate.TPFrame.Active = true
  end
end

Addon.UpdateNameplateStyle = UpdateNameplateStyle

local	function OnNewNameplate(plate)
  -- Parent could be: WorldFrame, UIParent, plate
  local tp_frame = _G.CreateFrame("Frame",  "ThreatPlatesFrame" .. GetNameForNameplate(plate), WorldFrame)
  tp_frame:Hide()
  tp_frame:SetFrameStrata("BACKGROUND")
  tp_frame:EnableMouse(false)
  tp_frame.Parent = plate
  plate.TPFrame = tp_frame

  -- Tidy Plates Frame References
  tp_frame.visual = {}

  -- Status Bars
  local textframe = _G.CreateFrame("Frame", nil, tp_frame)
  textframe:SetAllPoints()
  tp_frame.visual.textframe = textframe

  -- Add Graphical Elements
  ElementsCreated(tp_frame)

  tp_frame.widgets = {}
  Widgets:OnPlateCreated(tp_frame)

  -- Allocate Tables
  tp_frame.style = {}
  tp_frame.stylename = ""
  tp_frame.unit = {}
end

-- OnShowNameplate
local function OnShowNameplate(plate, unitid)
  local tp_frame = plate.TPFrame
  local unit = tp_frame.unit

  -- Initialize unit data for which there are no events when players enters world or that
  -- do not change over the nameplate lifetime
  InitializeUnit(unit, unitid)

  tp_frame.stylename = ""
  tp_frame.visual.Castbar.FlashTime = 0  -- Set FlashTime to 0 so that the castbar is actually hidden (see statusbar OnHide hook function OnHideCastbar)

  -- Update LastTargetPlate as target units may leave the screen, lose their nameplate and
  -- get a new one when the enter the screen again
  if unit.isTarget then
    LastTargetPlate = tp_frame
  end

  PlatesByUnit[unitid] = tp_frame
  PlatesByGUID[unit.guid] = plate

  -- Initialized nameplate style
  Style:Update(tp_frame)
  -- Initialize scale and transparency
  Transparency:Initialize(tp_frame)
  Scaling:Initialize(tp_frame)
  ElementsUnitAdded(tp_frame)

  UpdateNameplateStyle(plate, unitid)

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
        tp_frame.Background:SetSize(Addon.db.profile.settings.frame.width, Addon.db.profile.settings.frame.height)

        local width, height = Addon.db.profile.settings.frame.width, Addon.db.profile.settings.frame.height

        local min_scale = CVars:GetAsNumber("nameplateMinScale")
        --local selected_scale = CVars:GetAsNumber("nameplateSelectedScale")
        local global_scale = CVars:GetAsNumber("nameplateGlobalScale")
        local current_scale = global_scale * min_scale

        width = width * current_scale
        height = height * current_scale

        tp_frame.Background:SetSize(width, height)
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

  Localization:UpdateSettings()
  Font:UpdateSettings()
  Icons:UpdateSettings()
  Threat:UpdateSettings()
  Transparency:UpdateSettings()
  Scaling:UpdateSettings()
  Animations:UpdateSettings()
  ElementsUpdateSettings()

  local db = Addon.db.profile

  SettingsShowFriendlyBlizzardNameplates = db.ShowFriendlyBlizzardNameplates
  SettingsShowEnemyBlizzardNameplates = db.ShowEnemyBlizzardNameplates
  SettingsHideBuffsOnPersonalNameplate = db.PersonalNameplate.HideBuffs

  if db.settings.castnostop.ShowInterruptSource then
    RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  else
    UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  end

  ShowCastBars = db.settings.castbar.show or db.settings.castbar.ShowInHeadlineView

  if not (Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC) then
    self:ACTIVE_TALENT_GROUP_CHANGED() -- to update the player's role
  end
end

function Addon:UpdateAllPlates()
  for unitid, tp_frame in pairs(PlatesByUnit) do
    -- If Blizzard default plates are enabled (which means that these nameplates are not active), we need
    -- to check if they are enabled, so that Active is set correctly and plates are updated shown correctly.
    if not tp_frame.Active then
      UpdateNameplateStyle(tp_frame.Parent, unitid)
    end
    -- No need to update only active nameplates, as this is only done when settings are changed, so performance is
    -- not really an issue.
    OnShowNameplate(tp_frame.Parent, unitid)
  end
end

function Addon:PublishToEachPlate(event)
  for _, frame in pairs(PlatesByUnit) do
    if frame.Active then -- not necessary, but should prevent unnecessary updates to Blizzard default plates
      PublishEvent(event, frame)
    end
  end
end

function Addon:ForceUpdate()
  Addon:UpdateSettings()
  Addon:UpdateAllPlates()
end

function Addon:ForceUpdateOnNameplate(plate)
  OnShowNameplate(plate, plate.TPFrame.unit.unitid)
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
    UnitFrame:Hide()
  end

  -- Don't show ThreatPlates for widget-only nameplates (since Shadowlands)
  if UnitNameplateShowsWidgetsOnly(unitid) then return end

  -- Skip the personal resource bar of the player character, don't unhook scripts as nameplates, even the personal
  -- resource bar, get re-used
  if UnitIsUnit(unitid, "player") then -- or: ns.PlayerNameplate == GetNamePlateForUnit(UnitFrame.unit)
    if SettingsHideBuffsOnPersonalNameplate then
      UnitFrame.BuffFrame:Hide()
    end
    -- Just an else with the part below should work also
    return
  end

  -- Hide ThreatPlates nameplates if Blizzard nameplates should be shown for friendly units
  if UnitReaction(unitid, "player") > 4 then
    UnitFrame:SetShown(SettingsShowFriendlyBlizzardNameplates)
  else
    UnitFrame:SetShown(SettingsShowEnemyBlizzardNameplates)
  end

  -- -- Don't show ThreatPlates for widget-only nameplates (since Shadowlands)
  -- if UnitNameplateShowsWidgetsOnly(unitid) then 
  --   return 
  -- elseif UnitIsUnit(unitid, "player") then -- or: ns.PlayerNameplate == GetNamePlateForUnit(UnitFrame.unit)      
  --   -- Skip the personal resource bar of the player character, don't unhook scripts as nameplates, even the personal
  --   -- resource bar, get re-used
  --   if SettingsHideBuffsOnPersonalNameplate then
  --     UnitFrame.BuffFrame:Hide()
  --   end
  --   -- Just an else with the part below should work also
  --   return
  -- else
  --   -- Hide ThreatPlates nameplates if Blizzard nameplates should be shown for friendly units
  --   if UnitReaction(unitid, "player") > 4 then
  --     UnitFrame:SetShown(SettingsShowFriendlyBlizzardNameplates)
  --   else
  --     UnitFrame:SetShown(SettingsShowEnemyBlizzardNameplates)
  --   end
  -- end
  
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

  Scaling:HideNameplate(tp_frame)
  -- Do this after the hiding stuff, to correctly set the occluded transparency
  Transparency:SetOccludedTransparency(tp_frame)
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
  if NamePlateDriverFrame and NamePlateDriverFrame.AcquireUnitFrame then
    hooksecurefunc(NamePlateDriverFrame, "AcquireUnitFrame", NamePlateDriverFrame_AcquireUnitFrame)
  end
end

--function Addon:PLAYER_LOGOUT(...)
--end

-- Fired when the player enters the world, reloads the UI, enters/leaves an instance or battleground, or respawns at a graveyard.
-- Also fires any other time the player sees a loading screen
function Addon:PLAYER_ENTERING_WORLD(initialLogin, reloadingUI)
  local db = Addon.db.profile.questWidget
  if not (Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC) then
    if db.ON or db.ShowInHeadlineView then
      self.CVars:Set("showQuestTrackingTooltips", 1)
      --_G.SetCVar("showQuestTrackingTooltips", 1)
    else
      self.CVars:RestoreFromProfile("showQuestTrackingTooltips")
    end
  end

  -- This code must be executed every time the player enters a instance (dungeon, raid, ...)
  db = Addon.db.profile.Automation
  local isInstance, instance_type = IsInInstance()

  --Addon.IsInInstance = isInstance
  Addon.IsInPvEInstance = isInstance and (instance_type == "party" or instance_type == "raid")
  Addon.IsInPvPInstance = isInstance and (instance_type == "arena" or instance_type == "pvp")
  
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
  Font:SetNamesFonts()
end

-- Fires when the player leaves combat status
-- Syncs addon settings with game settings in case changes weren't possible during startup, reload
-- or profile reset because character was in combat.
function Addon:PLAYER_REGEN_ENABLED()
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
  local isInstance, _ = IsInInstance()

  -- Dont't use automation for friendly nameplates if in an instance and Hide Friendly Nameplates is enabled
  if db.FriendlyUnits ~= "NONE" and not (isInstance and db.HideFriendlyUnitsInInstances) then
    _G.SetCVar("nameplateShowFriends", (db.FriendlyUnits == "SHOW_COMBAT" and 0) or 1)
  end
  if db.EnemyUnits ~= "NONE" then
    _G.SetCVar("nameplateShowEnemies", (db.EnemyUnits == "SHOW_COMBAT" and 0) or 1)
  end

  Style:EnteringOrLeavingCombat()
end

-- Fires when the player enters combat status
function Addon:PLAYER_REGEN_DISABLED()
  local db = Addon.db.profile.Automation
  local isInstance, _ = IsInInstance()

  -- Dont't use automation for friendly nameplates if in an instance and Hide Friendly Nameplates is enabled
  if db.FriendlyUnits ~= "NONE" and not (isInstance and db.HideFriendlyUnitsInInstances) then
    _G.SetCVar("nameplateShowFriends", (db.FriendlyUnits == "SHOW_COMBAT" and 1) or 0)
  end

  if db.EnemyUnits ~= "NONE" then
    _G.SetCVar("nameplateShowEnemies", (db.EnemyUnits == "SHOW_COMBAT" and 1) or 0)
  end

  Style:EnteringOrLeavingCombat()
end

function Addon:NAME_PLATE_CREATED(plate)
  OnNewNameplate(plate)

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
  -- player and target work as unitid, but are the NAME_PLATE_UNIT_ADDED is fired for the actual nameplate id
  -- The player's personal resource bar is currently not supported by Threat Plates.
  -- OnShowNameplate is not called on it, therefore plate.TPFrame.Active is nil
  if UnitIsUnit("player", unitid) or UnitNameplateShowsWidgetsOnly(unitid) then return end

  OnShowNameplate(GetNamePlateForUnit(unitid), unitid)
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

  ElementsUnitRemoved(tp_frame)
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
    Style:UpdateName(tp_frame)
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
  for unitid, tp_frame in pairs(PlatesByUnit) do
    local target_marker = RAID_ICON_LIST[GetRaidTargetIndex(unitid)]
    -- Only update plates that changed
    if target_marker ~= tp_frame.unit.TargetMarker then
      tp_frame.unit.TargetMarker = target_marker
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
    Threat:ThreatUpdate(tp_frame)
  end
end

-- Update all elements that depend on the unit's reaction towards the player
function Addon:UNIT_FACTION(unitid)
  -- TODO: I assume here that, if the player's faction changes, also UNIT_FACTION events for all other units are fired

  if unitid == "target" then
    return
  elseif unitid == "player" then
   for _, tp_frame in pairs(PlatesByUnit) do
     SetUnitAttributeReaction(tp_frame.unit, unitid)
     Style:Update(tp_frame)
     PublishEvent("FationUpdate", tp_frame)
   end
  else
    local tp_frame = self:GetThreatPlateForUnit(unitid)
    if tp_frame then
      SetUnitAttributeReaction(tp_frame.unit, unitid)
      Style:Update(tp_frame)
      PublishEvent("FactionUpdate", tp_frame)
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
    Threat:ThreatUpdateHeuristic(tp_frame)
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

    Threat:ThreatUpdateHeuristic(tp_frame)
    if tp_frame.unit.CustomStyleCast then
      tp_frame.unit.CustomStyleCast = false
      Style:Update(tp_frame)
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
    Threat:ThreatUpdateHeuristic(tp_frame)
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
        visual.SpellText:SetText(INTERRUPTED .. " [" .. Addon.ColorByClass(class_name, Localization:TransliterateCyrillicLetters(sourceName)) .. "]")

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
        visual.SpellText:SetText(INTERRUPTED .. " [" .. Addon.ColorByClass(class_name, Localization:TransliterateCyrillicLetters(sourceName)) .. "]")

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
local RIGHTEOUS_FURY_SPELL_IDs = { [20468] = true, [20469] = true, [20470] = true, [25780] = true }
local function UNIT_AURA(event, unitid)
  local _, name, spellId
  for i = 1, 40 do
    name , _, _, _, _, _, _, _, _, spellId = _G.UnitBuff("player", i, "PLAYER")
    if not name then
      break
    elseif RIGHTEOUS_FURY_SPELL_IDs[spellId] then
      Addon.PlayerIsPaladinTank = true
      return
    end
  end

  Addon.PlayerIsPaladinTank = false
end

-- For Classic and TBC Classic, player role must be determined based on standes:
if Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC then
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
      return Addon.PlayerIsPaladinTank
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
  if Addon.PlayerClass == "PALADIN" then
    Addon.UNIT_AURA = UNIT_AURA
    Addon.EventService.SubscribeUnitEvent(Addon, "UNIT_AURA", "player")
    -- UNIT_AURA does not seem to be fired after login (even when buffs are active)
    UNIT_AURA()
  end
else
  function Addon:ACTIVE_TALENT_GROUP_CHANGED()
    local db = Addon.db
    if db.profile.optionRoleDetectionAutomatic then
      local role = select(5, GetSpecializationInfo(GetSpecialization()))
      Addon.PlayerRole = (role == "TANK" and "tank") or "dps"
    else
      local role = db.char.spec[GetSpecialization()]
      Addon.PlayerRole = (role == true and "tank") or "dps"
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
  ENABLED_EVENTS.UNIT_SPELLCAST_STOP = UNIT_SPELLCAST_STOP
  ENABLED_EVENTS.UNIT_SPELLCAST_CHANNEL_START = UNIT_SPELLCAST_CHANNEL_START
  ENABLED_EVENTS.UNIT_SPELLCAST_CHANNEL_STOP = UNIT_SPELLCAST_CHANNEL_STOP

  ENABLED_EVENTS.UNIT_SPELLCAST_DELAYED = UnitSpellcastMidway
  ENABLED_EVENTS.UNIT_SPELLCAST_CHANNEL_UPDATE = UnitSpellcastMidway
  -- UNIT_SPELLCAST_SUCCEEDED
  -- UNIT_SPELLCAST_FAILED
  -- UNIT_SPELLCAST_FAILED_QUIET
  -- UNIT_SPELLCAST_INTERRUPTED - handled by COMBAT_LOG_EVENT_UNFILTERED / SPELL_INTERRUPT as it's the only way to find out the interruptorom
  -- UNIT_SPELLCAST_SENT

  ENABLED_EVENTS.PLAYER_FOCUS_CHANGED = PLAYER_FOCUS_CHANGED

  if Addon.IS_MAINLINE then
    ENABLED_EVENTS.UNIT_SPELLCAST_INTERRUPTIBLE = UnitSpellcastMidway
    ENABLED_EVENTS.UNIT_SPELLCAST_NOT_INTERRUPTIBLE = UnitSpellcastMidway

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

