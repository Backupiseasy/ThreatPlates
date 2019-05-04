local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------------------------
-- Variables and References
---------------------------------------------------------------------------------------------------------------------

-- Lua APIs
local _
local type, select, pairs, tostring  = type, select, pairs, tostring 			    -- Local function copy
local max, gsub, tonumber, math_abs = math.max, string.gsub, tonumber, math.abs

-- WoW APIs
local wipe = wipe
local WorldFrame, UIParent, CreateFrame, GameFontNormal, UNKNOWNOBJECT, INTERRUPTED = WorldFrame, UIParent, CreateFrame, GameFontNormal, UNKNOWNOBJECT, INTERRUPTED
local UnitName, UnitReaction, UnitClassification, UnitLevel, UnitClass = UnitName, UnitReaction, UnitClassification, UnitLevel, UnitClass
local UnitGUID, UnitEffectiveLevel, UnitSelectionColor, UnitThreatSituation =UnitGUID, UnitEffectiveLevel, UnitSelectionColor, UnitThreatSituation
local UnitHealth, UnitHealthMax, UnitAffectingCombat, UnitIsTapDenied = UnitHealth, UnitHealthMax, UnitAffectingCombat, UnitIsTapDenied
local UnitChannelInfo, UnitCastingInfo, UnitPlayerControlled = UnitChannelInfo, UnitCastingInfo, UnitPlayerControlled
local UnitIsUnit, UnitIsPlayer, UnitExists = UnitIsUnit, UnitIsPlayer, UnitExists
local GetCreatureDifficultyColor, GetRaidTargetIndex = GetCreatureDifficultyColor, GetRaidTargetIndex
local GetTime, GetCVar, Lerp, CombatLogGetCurrentEventInfo = GetTime, GetCVar, Lerp, CombatLogGetCurrentEventInfo
local GetSpecialization, GetSpecializationInfo = GetSpecialization, GetSpecializationInfo
local GetNamePlates, GetNamePlateForUnit = C_NamePlate.GetNamePlates, C_NamePlate.GetNamePlateForUnit
local GetPlayerInfoByGUID, RAID_CLASS_COLORS = GetPlayerInfoByGUID, RAID_CLASS_COLORS

-- ThreatPlates APIs
local ThreatPlates = Addon.ThreatPlates
local TidyPlatesThreat = TidyPlatesThreat
local Widgets = Addon.Widgets
local RegisterEvent, UnregisterEvent = Addon.EventService.RegisterEvent, Addon.EventService.UnregisterEvent
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish
local ElementsCreated, ElementsUnitAdded, ElementsUnitRemoved = Addon.Elements.Created, Addon.Elements.UnitAdded, Addon.Elements.UnitRemoved
local ElementsUpdateStyle, ElementsUpdateSettings = Addon.Elements.UpdateStyle, Addon.Elements.UpdateSettings

-- Constants
local CASTBAR_INTERRUPT_HOLD_TIME = Addon.CASTBAR_INTERRUPT_HOLD_TIME
local ON_UPDATE_INTERVAL = Addon.ON_UPDATE_PER_FRAME
local PLATE_FADE_IN_TIME = Addon.PLATE_FADE_IN_TIME
local THREAT_REFERENCE = Addon.THREAT_REFERENCE

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
--local PlateOnUpdateQueue = {}

local LastTargetPlate

-- External references to internal data
local PlatesCreated = Addon.PlatesCreated
local PlatesByUnit = Addon.PlatesByUnit
local PlatesByGUID = Addon.PlatesByGUID

---------------------------------------------------------------------------------------------------
-- Cached configuration settings (for performance reasons)
---------------------------------------------------------------------------------------------------
local SettingsEnabledFading
local SettingsOccludedAlpha, SettingsEnabledOccludedAlpha
local SettingsShowEnemyBlizzardNameplates, SettingsShowFriendlyBlizzardNameplates
local ShowCastBars

-- Cached CVARs (updated on every PLAYER_ENTERING_WORLD event
local CVAR_NameplateOccludedAlphaMult

---------------------------------------------------------------------------------------------------------------------
-- Core Function Declaration
---------------------------------------------------------------------------------------------------------------------
local UpdatePlate_SetAlpha, UpdatePlate_SetAlphaOnUpdate, UpdatePlate_Transparency

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

--function Addon.ForEachPlate(functionToRun, ...)
--  local frame
--  for _, plate in pairs(GetNamePlates()) do
--    frame = plate.TPFrame
--    if frame and frame.Active then
--      functionToRun(frame, ...)
--    end
--  end
--end
--
--function Addon:ForEachPlate(functionToRun, ...)
--  local frame
--  for _, plate in pairs(GetNamePlates()) do
--    frame = plate.TPFrame
--    if frame and frame.Active then
--      self[functionToRun](self, frame, ...)
--    end
--  end
--end

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

local function UpdateUnitLevel(unit, unitid)
  local unit_level = UnitEffectiveLevel(unitid)
  unit.level = unit_level
  unit.LevelColor = GetCreatureDifficultyColor(unit_level)
end

local function UpdateUnitReaction(unit, unitid)
  unit.red, unit.green, unit.blue = UnitSelectionColor(unitid)
  unit.reaction = GetReactionByColor(unit.red, unit.green, unit.blue) or "HOSTILE"

  -- Enemy players turn to neutral, e.g., when mounting a flight path mount, so fix reaction in that situations
  if unit.reaction == "NEUTRAL" and (unit.type == "PLAYER" or UnitPlayerControlled(unitid)) then
    unit.reaction = "HOSTILE"
  end

  unit.isTapped = UnitIsTapDenied(unitid)
end

local function InitializeUnit(unit, unitid)
  -- Unit data that does not change after nameplate creation
  unit.unitid = unitid
  unit.guid = UnitGUID(unitid)

  unit.isBoss = UnitLevel(unitid) == -1

  unit.classification = (unit.isBoss and "boss") or UnitClassification(unitid)
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
  end

  -- Can be UNKNOWNOBJECT => UNIT_NAME_UPDATE
  unit.name = UnitName(unitid)

  -- Health and Absorbs => UNIT_HEALTH_FREQUENT, UNIT_MAXHEALTH & UNIT_ABSORB_AMOUNT_CHANGED
  unit.health = UnitHealth(unitid) or 0
  unit.healthmax = UnitHealthMax(unitid) or 1
  -- unit.Absorbs = UnitGetTotalAbsorbs(unitid) or 0

  -- Casting => UNIT_SPELLCAST_*
  -- Initialized in OnUpdateCastMidway in OnShowNameplate
  -- unit.isCasting = false
  -- unit.spellIsShielded = notInterruptible

  -- Target and Mouseover => PLAYER_TARGET_CHANGED, UPDATE_MOUSEOVER_UNIT
  unit.isTarget = UnitIsUnit("target", unitid)
  unit.isMouseover = UnitIsUnit("mouseover", unitid)

  -- Threat and Combat => UNIT_THREAT_LIST_UPDATE
  local threat_status = UnitThreatSituation("player", unitid)
  unit.ThreatStatus = threat_status
  unit.ThreatLevel = THREAT_REFERENCE[threat_status]
  unit.InCombat = UnitAffectingCombat(unitid)

  -- Target Mark => RAID_TARGET_UPDATE
  unit.TargetMarker = RAID_ICON_LIST[GetRaidTargetIndex(unitid)]

  -- Level => UNIT_LEVEL
  UpdateUnitLevel(unit, unitid)

  -- Reaction => UNIT_FACTION
  UpdateUnitReaction(unit, unitid)
end

---------------------------------------------------------------------------------------------------------------------
-- Nameplate Updating:
---------------------------------------------------------------------------------------------------------------------

-- OnShowCastbar
local function OnStartCasting(tp_frame, unitid, channeled)
  local unit, visual, style = tp_frame.unit, tp_frame.visual, tp_frame.style

  local castbar = tp_frame.visual.Castbar
  if not tp_frame:IsShown() or not style.castbar.show then
    castbar:Hide()
    return
  end

  local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID

  if channeled then
    name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(unitid)
    castbar.IsChanneling = true
    castbar.IsCasting = false

    castbar.Value = (endTime / 1000) - GetTime()
    castbar.MaxValue = (endTime - startTime) / 1000
    castbar:SetMinMaxValues(0, castbar.MaxValue)
    castbar:SetValue(castbar.Value)
  else
    name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unitid)
    castbar.IsCasting = true
    castbar.IsChanneling = false

    castbar.Value = GetTime() - (startTime / 1000)
    castbar.MaxValue = (endTime - startTime) / 1000
    castbar:SetMinMaxValues(0, castbar.MaxValue)
    castbar:SetValue(castbar.Value)
  end

  if isTradeSkill then return end

  unit.isCasting = true
  unit.spellIsShielded = notInterruptible

  visual.SpellText:SetText(text)
  visual.SpellIcon:SetTexture(texture)
  --visual.SpellIcon:SetDrawLayer("ARTWORK", 7)

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
    tp_frame.visual.Castbar:Hide()
  end
end

-- Update spell currently being cast
local function UnitSpellcastMidway(unitid, ...)
  if not ShowCastBars then return end

  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    OnUpdateCastMidway(tp_frame, unitid)
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
--    tp_frame.TestBackground:SetTexture(ThreatPlates.Media:Fetch('statusbar', TidyPlatesThreat.db.profile.AuraWidget.BackgroundTexture))
--    tp_frame.TestBackground:SetVertexColor(0,0,0,0.5)
--  end
end

SubscribeEvent(Addon, "StyleUpdate", UpdateStyle)

---------------------------------------------------------------------------------------------------------------------
-- Create / Hide / Show Event Handlers
---------------------------------------------------------------------------------------------------------------------

function Addon:UpdateNameplateStyle(plate, unitid)
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

local	function OnNewNameplate(plate)
  -- Parent could be: WorldFrame, UIParent, plate
  local tp_frame = CreateFrame("Frame",  "ThreatPlatesFrame" .. plate:GetName(), WorldFrame)
  tp_frame:Hide()

  tp_frame:SetFrameStrata("BACKGROUND")
  tp_frame:EnableMouse(false)
  tp_frame.Parent = plate
  --extended:SetAllPoints(plate)
  plate.TPFrame = tp_frame

  -- Tidy Plates Frame References
  local visual = {}
  tp_frame.visual = visual

  -- Status Bars
  local textframe = CreateFrame("Frame", nil, tp_frame)
  textframe:SetAllPoints()
  textframe:SetFrameLevel(tp_frame:GetFrameLevel() + 6)
  visual.textframe = textframe

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
  --ElementsUnitData(tp_frame)

  tp_frame.stylename = ""

  tp_frame.IsOccluded = false
  tp_frame.CurrentAlpha = nil
  tp_frame:SetAlpha(0)

  -- Update LastTargetPlate as target units may leave the screen, lose their nameplate and
  -- get a new one when the enter the screen again
  if unit.isTarget then
    LastTargetPlate = tp_frame
  end

  PlatesByUnit[unitid] = tp_frame
  PlatesByGUID[unit.guid] = plate

  -- Initialized nameplate style
  Addon:UpdateNameplateStyle(plate, unitid)
  Addon.InitializeStyle(tp_frame)

  -- Initialize scale and transparency
  tp_frame:SetScale(Addon.UIScale * Addon:SetScale(tp_frame.unit))
  UpdatePlate_Transparency(tp_frame, unit)

  ElementsUnitAdded(tp_frame)

  -- Call this after the plate is shown as OnStartCasting checks if the plate is shown; if not, the castbar is hidden and
  -- nothing is updated
  OnUpdateCastMidway(tp_frame, unitid)
end

-- OnResetNameplate
local function OnResetNameplate(plate)
  -- plate here always is a Threat Plates frame
  OnShowNameplate(plate, plate.TPFrame.unit.unitid)
end

---------------------------------------------------------------------------------------------------------------------
-- Nameplate Transparency:
---------------------------------------------------------------------------------------------------------------------

local function UpdatePlate_SetAlphaWithFading(tp_frame, unit)
  local target_alpha = Addon:GetAlpha(unit)

  if target_alpha ~= tp_frame.CurrentAlpha then
    Addon.Animations:StopFadeIn(tp_frame)
    Addon.Animations:FadeIn(tp_frame, target_alpha, PLATE_FADE_IN_TIME)
    tp_frame.CurrentAlpha = target_alpha
  end
end

local function UpdatePlate_SetAlphaNoFading(tp_frame, unit)
  local target_alpha = Addon:GetAlpha(unit)

  if target_alpha ~= tp_frame.CurrentAlpha then
    tp_frame:SetAlpha(target_alpha)
    tp_frame.CurrentAlpha = target_alpha
  end
end

local	function UpdatePlate_SetAlphaWithOcclusion(tp_frame, unit)
  if not tp_frame:IsShown() or (tp_frame.IsOccluded and not unit.isTarget) then
    return
  end

  UpdatePlate_SetAlpha(tp_frame, unit)
end

local function UpdatePlate_SetAlphaWithFadingOcclusionOnUpdate(tp_frame, unit)
  local target_alpha

  local plate_alpha = tp_frame.Parent:GetAlpha()
  if plate_alpha < (CVAR_NameplateOccludedAlphaMult + 0.05) then
    tp_frame.IsOccluded = true
    target_alpha = SettingsOccludedAlpha
  elseif tp_frame.IsOccluded or not tp_frame.CurrentAlpha then
    tp_frame.IsOccluded = false
    target_alpha = Addon:GetAlpha(unit)
  end

  if target_alpha and target_alpha ~= tp_frame.CurrentAlpha then
    Addon.Animations:StopFadeIn(tp_frame)

    if tp_frame.IsOccluded then
      tp_frame:SetAlpha(target_alpha)
    else
      Addon.Animations:FadeIn(tp_frame, target_alpha, PLATE_FADE_IN_TIME)
    end

    tp_frame.CurrentAlpha = target_alpha
  end
end

local function UpdatePlate_SetAlphaNoFadingOcclusionOnUpdate(tp_frame, unit)
  local target_alpha

  local plate_alpha = tp_frame.Parent:GetAlpha()
  if plate_alpha < (CVAR_NameplateOccludedAlphaMult + 0.05) then
    tp_frame.IsOccluded = true
    target_alpha = SettingsOccludedAlpha
  elseif tp_frame.IsOccluded or not tp_frame.CurrentAlpha then
    tp_frame.IsOccluded = false
    target_alpha = Addon:GetAlpha(unit)
  end

  if target_alpha and target_alpha ~= tp_frame.CurrentAlpha then
    tp_frame:SetAlpha(target_alpha)
    tp_frame.CurrentAlpha = target_alpha
  end
end

--------------------------------------------------------------------------------------------------------------
-- Misc. Utility
--------------------------------------------------------------------------------------------------------------

-- Blizzard default nameplates always have the same size, no matter what the UI scale actually is
function Addon:UIScaleChanged()
  local db = TidyPlatesThreat.db.profile.Scale
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
        tp_frame.Background = CreateFrame("Frame", nil, ConfigModePlate)
        tp_frame.Background:SetBackdrop({
          bgFile = ThreatPlates.Art .. "TP_WhiteSquare.tga",
          edgeFile = ThreatPlates.Art .. "TP_WhiteSquare.tga",
          edgeSize = 2,
          insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        tp_frame.Background:SetBackdropColor(0,0,0,.3)
        tp_frame.Background:SetBackdropBorderColor(0, 0, 0, 0.8)
        tp_frame.Background:SetPoint("CENTER", ConfigModePlate.UnitFrame, "CENTER")
        tp_frame.Background:SetSize(TidyPlatesThreat.db.profile.settings.frame.width, TidyPlatesThreat.db.profile.settings.frame.height)
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
        ThreatPlates.Print("Please select a target unit to enable configuration mode.", true)
      end
    end
  elseif ConfigModePlate then
    local background = ConfigModePlate.TPFrame.Background
    background:SetPoint("CENTER", ConfigModePlate.UnitFrame, "CENTER")
    background:SetSize(TidyPlatesThreat.db.profile.settings.frame.width, TidyPlatesThreat.db.profile.settings.frame.height)
  end
end

--------------------------------------------------------------------------------------------------------------
-- External Commands: Allows widgets and themes to request updates to the plates.
-- Useful to make a theme respond to externally-captured data (such as the combat log)
--------------------------------------------------------------------------------------------------------------

function Addon:UpdateSettings()
  --wipe(PlateOnUpdateQueue)

  ElementsUpdateSettings()

  CVAR_NameplateOccludedAlphaMult = tonumber(GetCVar("nameplateOccludedAlphaMult"))

  local db = TidyPlatesThreat.db.profile

  SettingsShowFriendlyBlizzardNameplates = db.ShowFriendlyBlizzardNameplates
  SettingsShowEnemyBlizzardNameplates = db.ShowEnemyBlizzardNameplates

  if db.Transparency.Fading then
    UpdatePlate_SetAlpha = UpdatePlate_SetAlphaWithFading
    UpdatePlate_SetAlphaOnUpdate = UpdatePlate_SetAlphaWithFadingOcclusionOnUpdate
  else
    UpdatePlate_SetAlpha = UpdatePlate_SetAlphaNoFading
    UpdatePlate_SetAlphaOnUpdate = UpdatePlate_SetAlphaNoFadingOcclusionOnUpdate
  end

  SettingsEnabledOccludedAlpha = db.nameplate.toggle.OccludedUnits
  SettingsOccludedAlpha = db.nameplate.alpha.OccludedUnits

  if SettingsEnabledOccludedAlpha then
    UpdatePlate_Transparency = UpdatePlate_SetAlphaWithOcclusion
    --PlateOnUpdateQueue[#PlateOnUpdateQueue + 1] = UpdatePlate_SetAlphaOnUpdate
  else
    UpdatePlate_Transparency = UpdatePlate_SetAlpha
  end

  if TidyPlatesThreat.db.profile.settings.castnostop.ShowInterruptSource then
    RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  else
    UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  end

  ShowCastBars = db.settings.castbar.show or db.settings.castbar.ShowInHeadlineView

  self:ACTIVE_TALENT_GROUP_CHANGED() -- to update the player's role
end

function Addon:UpdateAllPlates()
  local frame
  for _, plate in pairs(GetNamePlates()) do
    frame = plate.TPFrame
    if frame and frame.Active then
      -- TODO: Better would be to implement a custom event SettingsUpdate
      OnResetNameplate(plate)
    end
  end
end

function Addon:PublishToEachPlate(event)
  local frame
  for _, plate in pairs(GetNamePlates()) do
    frame = plate.TPFrame
    if frame and frame.Active then
      PublishEvent(event, frame)
    end
  end
end

function Addon:ForceUpdate()
  Addon:UpdateSettings()
  Addon:UpdateAllPlates()
end

function Addon:ForceUpdateOnNameplate(plate)
  OnResetNameplate(plate)
end

---------------------------------------------------------------------------------------------------------------------
-- Handling of WoW events
---------------------------------------------------------------------------------------------------------------------

local IsInInstance, InCombatLockdown = IsInInstance, InCombatLockdown
local NamePlateDriverFrame = NamePlateDriverFrame
local SetCVar = SetCVar
local L = ThreatPlates.L

local TaskQueueOoC = {}

local ENABLED_EVENTS = {
  "PLAYER_ENTERING_WORLD",
  -- "PLAYER_LOGIN",
  -- "PLAYER_LOGOUT",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_REGEN_DISABLED",

  "NAME_PLATE_CREATED",
  "NAME_PLATE_UNIT_ADDED",
  "NAME_PLATE_UNIT_REMOVED",

  "PLAYER_TARGET_CHANGED",
  --PLAYER_FOCUS_CHANGED = ..., -- no idea why we shoul listen for this event
  UPDATE_MOUSEOVER_UNIT = Addon.Elements.GetElement("MouseoverHighlight").UPDATE_MOUSEOVER_UNIT,
  "RAID_TARGET_UPDATE",

  "UNIT_NAME_UPDATE",
  "UNIT_MAXHEALTH",
  "UNIT_HEALTH_FREQUENT",
  --"UNIT_ABSORB_AMOUNT_CHANGED",
  "UNIT_THREAT_LIST_UPDATE",
  "UNIT_FACTION",
  "UNIT_LEVEL",

  "UNIT_SPELLCAST_START",
  UNIT_SPELLCAST_DELAYED = UnitSpellcastMidway,
  "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_CHANNEL_START",
  UNIT_SPELLCAST_CHANNEL_UPDATE = UnitSpellcastMidway,
  "UNIT_SPELLCAST_CHANNEL_STOP",
  UNIT_SPELLCAST_INTERRUPTIBLE = UnitSpellcastMidway,
  UNIT_SPELLCAST_NOT_INTERRUPTIBLE = UnitSpellcastMidway,
  -- UNIT_SPELLCAST_FAILED
  -- UNIT_SPELLCAST_FAILED_QUIET
  -- UNIT_SPELLCAST_INTERRUPTED

  --PLAYER_CONTROL_LOST = ..., -- Does not seem to be necessary
  --PLAYER_CONTROL_GAINED = ...,  -- Does not seem to be necessary

  "UI_SCALE_CHANGED",
  "ACTIVE_TALENT_GROUP_CHANGED",

  --"PLAYER_ALIVE",
  --"PLAYER_LEAVING_WORLD",
  --"PLAYER_TALENT_UPDATE"

  -- CVAR_UPDATE,
  -- DISPLAY_SIZE_CHANGED,     -- Blizzard also uses this event
  -- VARIABLES_LOADED,         -- Blizzard also uses this event

  -- Depending on settings, registered or unregistered in ForceUpdate
  -- "COMBAT_LOG_EVENT_UNFILTERED",
}

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
--    TidyPlatesThreat:UnregisterEvent(EVENTS[i])
--  end
--end

--------------------------------------------------------------------------------------------------------------
-- WoW Event Handling: helper functions
--------------------------------------------------------------------------------------------------------------

function Addon:CallbackWhenOoC(func, msg)
  if InCombatLockdown() then
    if msg then
      ThreatPlates.Print(msg .. L[" The change will be applied after you leave combat."], true)
    end
    TaskQueueOoC[#TaskQueueOoC + 1] = func
  else
    func()
  end
end

local function FrameOnShow(UnitFrame)
  -- Hide nameplates that have not yet an unit added
  if not UnitFrame.unit then
    UnitFrame:Hide()
  end

  local db = TidyPlatesThreat.db.profile

  -- Skip the personal resource bar of the player character, don't unhook scripts as nameplates, even the personal
  -- resource bar, get re-used
  if UnitIsUnit(UnitFrame.unit, "player") then -- or: ns.PlayerNameplate == GetNamePlateForUnit(UnitFrame.unit)
    if db.PersonalNameplate.HideBuffs then
      UnitFrame.BuffFrame:Hide()
      --      else
      --        UnitFrame.BuffFrame:Show()
    end
    return
  end

  -- Hide ThreatPlates nameplates if Blizzard nameplates should be shown for friendly units
  if UnitReaction(UnitFrame.unit, "player") > 4 then
    UnitFrame:SetShown(SettingsShowFriendlyBlizzardNameplates)
  else
    UnitFrame:SetShown(SettingsShowEnemyBlizzardNameplates)
  end
end

-- Frame: self = plate
local function FrameOnUpdate(plate, elapsed)
  local ON_UPDATE_INTERVAL = ON_UPDATE_INTERVAL
  local SettingsEnabledOccludedAlpha, UpdatePlate_SetAlphaOnUpdate = SettingsEnabledOccludedAlpha, UpdatePlate_SetAlphaOnUpdate
  local UnitIsUnit = UnitIsUnit

  -- Update the number of seconds since the last update
  plate.TimeSinceLastUpdate = (plate.TimeSinceLastUpdate or 0) + elapsed

  if plate.TimeSinceLastUpdate >= ON_UPDATE_INTERVAL then
    plate.TimeSinceLastUpdate = 0

    local unitid = plate.UnitFrame.unit
    if unitid and UnitIsUnit(unitid, "player") then
      return
    end

    local tp_frame = plate.TPFrame
    tp_frame:SetFrameLevel(plate:GetFrameLevel() * 10)

    --    for i = 1, #PlateOnUpdateQueue do
    --      PlateOnUpdateQueue[i](plate, tp_frame.unit)
    --    end

    if SettingsEnabledOccludedAlpha then
      UpdatePlate_SetAlphaOnUpdate(tp_frame, tp_frame.unit)
    end
  end
end

-- Frame: self = plate
local function FrameOnHide(plate)
  plate.TPFrame:Hide()
end

--------------------------------------------------------------------------------------------------------------
-- WoW Event Handling: Event handling functions
--------------------------------------------------------------------------------------------------------------

--function Addon:PLAYER_LOGIN(...)
--end
--
--function Addon:PLAYER_LOGOUT(...)
--end

-- Fired when the player enters the world, reloads the UI, enters/leaves an instance or battleground, or respawns at a graveyard.
-- Also fires any other time the player sees a loading screen
function Addon:PLAYER_ENTERING_WORLD(initialLogin, reloadingUI)
  local db = TidyPlatesThreat.db.profile.questWidget
  if db.ON or db.ShowInHeadlineView then
    self.CVars:Set("showQuestTrackingTooltips", 1)
    --SetCVar("showQuestTrackingTooltips", 1)
  else
    self.CVars:RestoreFromProfile("showQuestTrackingTooltips")
  end

  -- This code must be executed every time the player enters a instance (dungeon, raid, ...)
  db = TidyPlatesThreat.db.profile.Automation
  local isInstance, instanceType = IsInInstance()

  if db.HideFriendlyUnitsInInstances and isInstance then
    self.CVars:Set("nameplateShowFriends", 0)
  else
    -- reset to previous setting
    self.CVars:RestoreFromProfile("nameplateShowFriends")
  end

  if db.SmallPlatesInInstances and NamePlateDriverFrame:IsUsingLargerNamePlateStyle() and isInstance then
    self.CVars:Set("nameplateGlobalScale", 0.4)
  else
    -- reset to previous setting
    self.CVars:RestoreFromProfile("nameplateGlobalScale")
  end

  -- Call some events manually to initialize nameplates correctly as these events are not called upon login
  --   * Scale is initalized via UNIT_FACTION as this event fires at PLAYER_ENTERING_WORLD for every unit visible
  --   * Transparency is initalized via UNIT_FACTION as this event fires at PLAYER_ENTERING_WORLD for every unit visible
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

  --  local db = TidyPlatesThreat.db.profile.threat
  --  -- Required for threat/aggro detection
  --  if db.ON and (GetCVar("threatWarning") ~= 3) then
  --    SetCVar("threatWarning", 3)
  --  elseif not db.ON and (GetCVar("threatWarning") ~= 0) then
  --    SetCVar("threatWarning", 0)
  --  end

  local db = TidyPlatesThreat.db.profile.Automation
  local isInstance, _ = IsInInstance()

  -- Dont't use automation for friendly nameplates if in an instance and Hide Friendly Nameplates is enabled
  if db.FriendlyUnits ~= "NONE" and not (isInstance and db.HideFriendlyUnitsInInstances) then
    SetCVar("nameplateShowFriends", (db.FriendlyUnits == "SHOW_COMBAT" and 0) or 1)
  end
  if db.EnemyUnits ~= "NONE" then
    SetCVar("nameplateShowEnemies", (db.EnemyUnits == "SHOW_COMBAT" and 0) or 1)
  end
end

-- Fires when the player enters combat status
function Addon:PLAYER_REGEN_DISABLED()
  local db = TidyPlatesThreat.db.profile.Automation
  local isInstance, _ = IsInInstance()

  -- Dont't use automation for friendly nameplates if in an instance and Hide Friendly Nameplates is enabled
  if db.FriendlyUnits ~= "NONE" and not (isInstance and db.HideFriendlyUnitsInInstances) then
    SetCVar("nameplateShowFriends", (db.FriendlyUnits == "SHOW_COMBAT" and 1) or 0)
  end

  if db.EnemyUnits ~= "NONE" then
    SetCVar("nameplateShowEnemies", (db.EnemyUnits == "SHOW_COMBAT" and 1) or 0)
  end
end

function Addon:NAME_PLATE_CREATED(plate)
  OnNewNameplate(plate)

  if plate.UnitFrame then -- not plate.TPFrame.onShowHooked then
    plate.UnitFrame:HookScript("OnShow", FrameOnShow)
    -- TODO: Idea from ElvUI, I think
    -- plate.TPFrame.onShowHooked = true
  end

  plate:HookScript('OnHide', FrameOnHide)
  plate:HookScript('OnUpdate', FrameOnUpdate)

  PlatesCreated[plate] = plate.TPFrame
end

-- Payload: { Name = "unitToken", Type = "string", Nilable = false },
function Addon:NAME_PLATE_UNIT_ADDED(unitid)
  -- Player's personal resource bar is currently not handled by Threat Plates
  -- OnShowNameplate is not called on it, therefore plate.TPFrame.Active is nil
  if UnitIsUnit("player", unitid) then return end

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

  tp_frame:Hide()

  PlatesByUnit[unitid] = nil
  if tp_frame.unit.guid then -- maybe hide directly after create with unit added?
    PlatesByGUID[tp_frame.unit.guid] = nil
  end

  ElementsUnitRemoved(tp_frame)
  Widgets:OnUnitRemoved(tp_frame, tp_frame.unit)

  wipe(tp_frame.unit)

  -- Remove anything from the function queue
  plate.UpdateMe = false
end

function Addon:UNIT_NAME_UPDATE(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    tp_frame.unit.name = UnitName(unitid)
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

function Addon:UNIT_HEALTH_FREQUENT(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    local unit = tp_frame.unit

    unit.health = UnitHealth(unitid) or 0
    unit.healthmax = UnitHealthMax(unitid) or 1
  end
end

function Addon:UNIT_MAXHEALTH(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    local unit = tp_frame.unit

    unit.health = UnitHealth(unitid) or 0
    unit.healthmax = UnitHealthMax(unitid) or 1
  end
end

function Addon:UNIT_THREAT_LIST_UPDATE(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    local threat_status = UnitThreatSituation("player", unitid)

    local unit = tp_frame.unit
    -- If threat_status is nil, unit is leaving combat
    if threat_status == nil then
      unit.ThreatStatus = nil
      PublishEvent("ThreatUpdate", tp_frame, unit)
    elseif threat_status ~= unit.ThreatStatus then
      unit.ThreatStatus = threat_status
      unit.ThreatLevel = THREAT_REFERENCE[threat_status]
      unit.InCombat = UnitAffectingCombat(unitid)
      PublishEvent("ThreatUpdate", tp_frame, unit)
    end
  end
end

-- Update all elements that depend on the unit's reaction towards the player
function Addon:UNIT_FACTION(unitid)
  -- I assume here that, if the player's faction changes, also UNIT_FACTION events for all other
  -- units are fired

  -- So, just update just the unitid's plate
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    UpdateUnitReaction(tp_frame.unit, unitid)
    PublishEvent("FactionUpdate", tp_frame)
  end

  --  if unitid == "player" then
--    for _, tp_frame in pairs(PlatesByUnit) do
--      UpdateUnitReaction(tp_frame.unit, unitid)
--      PublishEvent("FationUpdate", tp_frame)
--    end
--  else
--    -- Update just the unitid's plate
--    local tp_frame = PlatesByUnit[unitid]
--    if tp_frame and tp_frame.Active then
--      UpdateUnitReaction(tp_frame.unit, unitid)
--      PublishEvent("FationUpdate", tp_frame)
--    end
--  end
end

function Addon:UNIT_LEVEL(unitid)
  -- Update just the unitid's plate
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    UpdateUnitLevel(tp_frame.unit, unitid)
  end
end

function Addon:UNIT_SPELLCAST_START(unitid)
  if not ShowCastBars then return end

  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    OnStartCasting(tp_frame, unitid, false)
  end
end

function Addon:UNIT_SPELLCAST_CHANNEL_START(unitid)
  if not ShowCastBars then return end

  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    OnStartCasting(tp_frame, unitid, true)
  end
end

-- Used for UNIT_SPELLCAST_STOP and UNIT_SPELLCAST_CHANNEL_STOP
function Addon:UNIT_SPELLCAST_STOP(unitid)
  if not ShowCastBars then return end

  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    tp_frame.unit.isCasting = false

    local castbar = tp_frame.visual.Castbar
    castbar.IsChanneling = false
    castbar.IsCasting = false

    PublishEvent("CastingStopped", tp_frame)
  end
end

Addon.UNIT_SPELLCAST_CHANNEL_STOP = Addon.UNIT_SPELLCAST_STOP

function Addon:COMBAT_LOG_EVENT_UNFILTERED()
  local timeStamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

  if event == "SPELL_INTERRUPT" then
    local plate = PlatesByGUID[destGUID]

    if plate and plate.TPFrame.Active then
      local visual = plate.TPFrame.visual

      local castbar = visual.Castbar
      if castbar:IsShown() then
        sourceName = gsub(sourceName, "%-[^|]+", "") -- UnitName(sourceName) only works in groups

        local _, class_id = GetPlayerInfoByGUID(sourceGUID)
        if class_id then
          --local color_str = (RAID_CLASS_COLORS[classId] and RAID_CLASS_COLORS[classId].colorStr) or ""
          sourceName = "|c" .. RAID_CLASS_COLORS[class_id].colorStr .. sourceName .. "|r"
        end

        visual.SpellText:SetText(INTERRUPTED .. " [" .. sourceName .. "]")

        local _, max_val = castbar:GetMinMaxValues()
        castbar:SetValue(max_val)
        castbar.Spark:Hide()

        local color = TidyPlatesThreat.db.profile.castbarColorInterrupted
        castbar:SetStatusBarColor(color.r, color.g, color.b, color.a)
        castbar.FlashTime = CASTBAR_INTERRUPT_HOLD_TIME
        -- OnStopCasting is hiding the castbar and may be triggered before or after SPELL_INTERRUPT
        -- So we have to show the castbar again or not hide it if the interrupt message should still be shown.
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

function Addon:ACTIVE_TALENT_GROUP_CHANGED()
  local db = TidyPlatesThreat.db
  if db.profile.optionRoleDetectionAutomatic then
    local role = select(5, GetSpecializationInfo(GetSpecialization()))
    Addon.PlayerRole = (role == "TANK" and "tank") or "dps"
  else
    local role = db.char.spec[GetSpecialization()]
    Addon.PlayerRole = (role == true and "tank") or "dps"
  end
end
