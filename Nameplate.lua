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
local WorldFrame, UIParent, INTERRUPTED = WorldFrame, UIParent, INTERRUPTED
local UnitName, UnitReaction, UnitClass = UnitName, UnitReaction, UnitClass
local UnitEffectiveLevel, UnitThreatSituation = UnitEffectiveLevel, UnitThreatSituation
local UnitChannelInfo, UnitPlayerControlled = UnitChannelInfo, UnitPlayerControlled
local UnitIsUnit, UnitIsPlayer = UnitIsUnit, UnitIsPlayer
local GetCreatureDifficultyColor, GetRaidTargetIndex = GetCreatureDifficultyColor, GetRaidTargetIndex
local GetTime, GetCVar, CombatLogGetCurrentEventInfo = GetTime, GetCVar, CombatLogGetCurrentEventInfo
local GetSpecialization, GetSpecializationInfo = GetSpecialization, GetSpecializationInfo
local GetNamePlates, GetNamePlateForUnit = C_NamePlate.GetNamePlates, C_NamePlate.GetNamePlateForUnit
local GetPlayerInfoByGUID, RAID_CLASS_COLORS = GetPlayerInfoByGUID, RAID_CLASS_COLORS
local IsInInstance, InCombatLockdown = IsInInstance, InCombatLockdown
local NamePlateDriverFrame = NamePlateDriverFrame

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local ThreatPlates = Addon.ThreatPlates
local L = Addon.L
local Widgets, Animations, Scaling, Transparency = Addon.Widgets, Addon.Animations, Addon.Scaling, Addon.Transparency
local RegisterEvent, UnregisterEvent = Addon.EventService.RegisterEvent, Addon.EventService.UnregisterEvent
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish
local ElementsCreated, ElementsUnitAdded, ElementsUnitRemoved = Addon.Elements.Created, Addon.Elements.UnitAdded, Addon.Elements.UnitRemoved
local ElementsUpdateStyle, ElementsUpdateSettings = Addon.Elements.UpdateStyle, Addon.Elements.UpdateSettings

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, UnitAffectingCombat, UnitCastingInfo, UnitClassification, UnitGUID, UnitHealth, UnitHealthMax, UnitIsTapDenied, UnitLevel, UnitSelectionColor

-- Constants
local CASTBAR_INTERRUPT_HOLD_TIME = Addon.CASTBAR_INTERRUPT_HOLD_TIME
local THREAT_REFERENCE = Addon.THREAT_REFERENCE

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
local SettingsShowEnemyBlizzardNameplates, SettingsShowFriendlyBlizzardNameplates
local ShowCastBars, PersonalNameplateHideBuffs
-- Cached CVARs
local AnimateHideNameplate, CVAR_nameplateMinAlpha, CVAR_nameplateMinScale

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
  unit.red, unit.green, unit.blue = _G.UnitSelectionColor(unitid)
  unit.reaction = GetReactionByColor(unit.red, unit.green, unit.blue) or "HOSTILE"

  -- Enemy players turn to neutral, e.g., when mounting a flight path mount, so fix reaction in that situations
  if unit.reaction == "NEUTRAL" and (unit.type == "PLAYER" or UnitPlayerControlled(unitid)) then
    unit.reaction = "HOSTILE"
  end

  unit.IsTapDenied = _G.UnitIsTapDenied(unitid)
end

local function InitializeUnit(unit, unitid)
  -- Unit data that does not change after nameplate creation
  unit.unitid = unitid
  unit.guid = _G.UnitGUID(unitid)

  unit.isBoss = _G.UnitLevel(unitid) == -1

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
  end

  -- Can be UNKNOWNOBJECT => UNIT_NAME_UPDATE
  unit.name = UnitName(unitid)

  -- Health and Absorbs => UNIT_HEALTH_FREQUENT, UNIT_MAXHEALTH & UNIT_ABSORB_AMOUNT_CHANGED
  unit.health = _G.UnitHealth(unitid) or 0
  unit.healthmax = _G.UnitHealthMax(unitid) or 1
  -- unit.Absorbs = UnitGetTotalAbsorbs(unitid) or 0

  -- Casting => UNIT_SPELLCAST_*
  -- Initialized in OnUpdateCastMidway in OnShowNameplate, but only when unit is currently casting
  unit.isCasting = false
  unit.IsInterrupted = false

  -- Target, Focus, and Mouseover => PLAYER_TARGET_CHANGED, UPDATE_MOUSEOVER_UNIT, PLAYER_FOCUS_CHANGED
  unit.isTarget = UnitIsUnit("target", unitid)
  unit.IsFocus = UnitIsUnit("focus", unitid) -- required here for config changes which reset all plates without calling TARGET_CHANGED, MOUSEOVER, ...
  unit.isMouseover = UnitIsUnit("mouseover", unitid)

  -- Threat and Combat => UNIT_THREAT_LIST_UPDATE
  local threat_status = UnitThreatSituation("player", unitid)
  unit.ThreatStatus = threat_status
  unit.ThreatLevel = THREAT_REFERENCE[threat_status]
  unit.InCombat = _G.UnitAffectingCombat(unitid)

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
  if not tp_frame:IsShown() then
    castbar:Hide()
    return
  end

  local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID
  if channeled then
    name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(unitid)
    castbar.Value = (endTime / 1000) - GetTime()
  else
    name, text, texture, startTime, endTime, isTradeSkill, _, notInterruptible, spellID = _G.UnitCastingInfo(unitid)
    castbar.Value = GetTime() - (startTime / 1000)
  end

  if not name or isTradeSkill then
    castbar:Hide()
    return
  end

  if not name or isTradeSkill then
    castbar:Hide()
    return
  end

  local plate_style = Addon.ActiveCastTriggers and Addon.UnitStyle_CastDependent(unit, spellID, name)

  -- Abort here as casts can now switch nameplate styles (e.g,. from headline to healthbar view
  if not (style.castbar.show or plate_style) then
    castbar:Hide()
    return
  end

  unit.isCasting = true
  unit.IsInterrupted = false
  unit.spellIsShielded = notInterruptible

  --if plate_style and plate_style ~= extended.stylename then
  if plate_style ~= tp_frame.stylename then
    PublishEvent("CustomStyleUpdate", tp_frame)
  end

  -- Custom nameplates might trigger cause of a cast, but still stay in a style that does not
  -- show the castbar
  if not style.castbar.show then
    castbar:Hide()
    return
  end

  visual.SpellText:SetText(text)
  visual.SpellIcon:SetTexture(texture)

  castbar.IsCasting = not channeled
  castbar.IsChanneling = channeled

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
  if _G.UnitCastingInfo(unitid) then
    OnStartCasting(tp_frame, unitid, false)
  elseif UnitChannelInfo(unitid) then
    OnStartCasting(tp_frame, unitid, true)
  else
    -- It would be better to check for IsInterrupted here and not hide it if that is true
    -- Not currently sure though, if that might work with the Hide() calls in OnStartCasting
    tp_frame.visual.Castbar:Hide()
  end
end

-- Update spell currently being cast
local function UnitSpellcastMidway(unitid, ...)
  if unitid == "target" or UnitIsUnit("player", unitid) or not ShowCastBars then return end

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
--    tp_frame.TestBackground:SetTexture(Addon.LSM:Fetch('statusbar', TidyPlatesThreat.db.profile.AuraWidget.BackgroundTexture))
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
  local tp_frame = _G.CreateFrame("Frame",  "ThreatPlatesFrame" .. plate:GetName(), WorldFrame)
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
  textframe:SetFrameLevel(tp_frame:GetFrameLevel() + 6)
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
  tp_frame.IsShowing = true
  tp_frame.IsHidden = false
  tp_frame.visual.Castbar.FlashTime = 0  -- Set FlashTime to 0 so that the castbar is actually hidden (see statusbar OnHide hook function OnHideCastbar)

  -- Update LastTargetPlate as target units may leave the screen, lose their nameplate and
  -- get a new one when the enter the screen again
  if unit.isTarget then
    LastTargetPlate = tp_frame
  end

  PlatesByUnit[unitid] = tp_frame
  PlatesByGUID[unit.guid] = plate

  -- Initialized nameplate style
  Addon.InitializeStyle(tp_frame)
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
        tp_frame.Background = _G.CreateFrame("Frame", nil, ConfigModePlate)
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

        local width, height = TidyPlatesThreat.db.profile.settings.frame.width, TidyPlatesThreat.db.profile.settings.frame.height

        local min_scale = tonumber(GetCVar("nameplateMinScale"))
        --local selected_scale = tonumber(GetCVar("nameplateSelectedScale"))
        local global_scale = tonumber(GetCVar("nameplateGlobalScale"))
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
  Transparency:UpdateSettings()
  Scaling:UpdateSettings()
  Animations:UpdateSettings()

  local db = TidyPlatesThreat.db.profile

  SettingsShowFriendlyBlizzardNameplates = db.ShowFriendlyBlizzardNameplates
  SettingsShowEnemyBlizzardNameplates = db.ShowEnemyBlizzardNameplates

  if TidyPlatesThreat.db.profile.settings.castnostop.ShowInterruptSource then
    RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  else
    UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  end

  if db.Animations.HidePlateDuration > 0 and (db.Animations.HidePlateFadeOut or db.Animations.HidePlateScaleDown) then
    AnimateHideNameplate = true
    CVAR_nameplateMinScale = tonumber(GetCVar("nameplateMinScale"))
    CVAR_nameplateMinAlpha = tonumber(GetCVar("nameplateMinAlpha"))
  else
    AnimateHideNameplate = false
  end

  ShowCastBars = db.settings.castbar.show or db.settings.castbar.ShowInHeadlineView
  PersonalNameplateHideBuffs = db.PersonalNameplate.HideBuffs

  self:ACTIVE_TALENT_GROUP_CHANGED() -- to update the player's role
end

function Addon:UpdateAllPlates()
  for unitid, frame in pairs(PlatesByUnit) do
    -- No need to update only active nameplates, as this is only done when settings are changed, so performance is
    -- not really an issue.
    OnShowNameplate(frame.Parent, unitid)
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

---------------------------------------------------------------------------------------------------------------------
-- Handling of WoW events
---------------------------------------------------------------------------------------------------------------------

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
  "PLAYER_FOCUS_CHANGED",
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
  -- UNIT_SPELLCAST_SUCCEEDED
  -- UNIT_SPELLCAST_FAILED
  -- UNIT_SPELLCAST_INTERRUPTED
  -- UNIT_SPELLCAST_FAILED_QUIET
  -- UNIT_SPELLCAST_INTERRUPTED - handled by COMBAT_LOG_EVENT_UNFILTERED / SPELL_INTERRUPT as it's the only way to find out the interruptorom
  -- UNIT_SPELLCAST_SENT

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

  -- Skip the personal resource bar of the player character, don't unhook scripts as nameplates, even the personal
  -- resource bar, get re-used
  if UnitIsUnit(UnitFrame.unit, "player") then -- or: ns.PlayerNameplate == GetNamePlateForUnit(UnitFrame.unit)
    if PersonalNameplateHideBuffs then
      UnitFrame.BuffFrame:Hide()
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
  -- Skip nameplates not handled by TP: Blizzard default plates (if configured) and the personal nameplate
  -- if not plate.TPFrame.Active then return end
  local unitid = plate.UnitFrame.unit
  if unitid and UnitIsUnit(unitid, "player") then
    return
  end

  local tp_frame = plate.TPFrame
  tp_frame:SetFrameLevel(plate:GetFrameLevel() * 10)

  --    for i = 1, #PlateOnUpdateQueue do
  --      PlateOnUpdateQueue[i](plate, tp_frame.unit)
  --    end

  Transparency:SetOccludedTransparency(tp_frame)

  --local scale = plate:GetScale()
  --local alpha = plate:GetAlpha()

  --if scale ~= plate.PreviousScale then
  --  plate.Time = (plate.Time and plate.Time + elapsed) or 0
  --  print (tp_frame.unit.name, "=> [" .. tostring(plate.Time) .. "] Alpha =", alpha, "  ---  Scale:", scale)
  --  plate.PreviousScale = scale
  --end

  -- TODO: Think about moving this part of the code to Animations
  if AnimateHideNameplate then
    -- Phase-out nameplates that will be hidden (e.g., the unit died)
    -- Heuristic for determining of the nameplate is displayed (scaling up) or hidden (scaling down)
    -- The first time the plate's scale passes the min scale, it should be fully displayed.
    if plate:GetScale() < CVAR_nameplateMinScale then -- plate alpha already used (and adjusted) for occlusion detection
      -- or plate:GetAlpha() < CVAR_nameplateMinAlpha then
      if not tp_frame.IsShowing and not tp_frame.IsHidden then
        Animations:HidePlate(tp_frame)
        tp_frame.IsHidden = true
      end
    else
      tp_frame.IsShowing = false
    end
  end

  if plate:GetScale() >= CVAR_nameplateMinScale then -- plate alpha already used (and adjusted) for occlusion detection
    tp_frame.IsShowing = false
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
    --_G.SetCVar("showQuestTrackingTooltips", 1)
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
  --    _G.SetCVar("threatWarning", 3)
  --  elseif not db.ON and (GetCVar("threatWarning") ~= 0) then
  --    _G.SetCVar("threatWarning", 0)
  --  end

  local db = TidyPlatesThreat.db.profile.Automation
  local isInstance, _ = IsInInstance()

  -- Dont't use automation for friendly nameplates if in an instance and Hide Friendly Nameplates is enabled
  if db.FriendlyUnits ~= "NONE" and not (isInstance and db.HideFriendlyUnitsInInstances) then
    _G.SetCVar("nameplateShowFriends", (db.FriendlyUnits == "SHOW_COMBAT" and 0) or 1)
  end
  if db.EnemyUnits ~= "NONE" then
    _G.SetCVar("nameplateShowEnemies", (db.EnemyUnits == "SHOW_COMBAT" and 0) or 1)
  end
end

-- Fires when the player enters combat status
function Addon:PLAYER_REGEN_DISABLED()
  local db = TidyPlatesThreat.db.profile.Automation
  local isInstance, _ = IsInInstance()

  -- Dont't use automation for friendly nameplates if in an instance and Hide Friendly Nameplates is enabled
  if db.FriendlyUnits ~= "NONE" and not (isInstance and db.HideFriendlyUnitsInInstances) then
    _G.SetCVar("nameplateShowFriends", (db.FriendlyUnits == "SHOW_COMBAT" and 1) or 0)
  end

  if db.EnemyUnits ~= "NONE" then
    _G.SetCVar("nameplateShowEnemies", (db.EnemyUnits == "SHOW_COMBAT" and 1) or 0)
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
  tp_frame.IsHiding = nil

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

function Addon:PLAYER_FOCUS_CHANGED()
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

function Addon:UNIT_HEALTH_FREQUENT(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    local unit = tp_frame.unit

    unit.health = _G.UnitHealth(unitid) or 0
    unit.healthmax = _G.UnitHealthMax(unitid) or 1
  end
end

function Addon:UNIT_MAXHEALTH(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    local unit = tp_frame.unit

    unit.health = _G.UnitHealth(unitid) or 0
    unit.healthmax = _G.UnitHealthMax(unitid) or 1
  end
end

function Addon:UNIT_THREAT_LIST_UPDATE(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    local threat_status = UnitThreatSituation("player", unitid)

    local unit = tp_frame.unit
    --if threat_status == unit.ThreatStatus and UnitIsUnit("target", unitid) then
    --  print ("Threat: No Update =>", threat_status, "=", unit.ThreatStatus)
    --  print ("Threat: Level =>", unit.ThreatLevel)
    --  print ("Threat: Offtanked =>", unit.IsOfftanked)
    --  print ("Combat Color:", unit.CombatColor)
    --end

    -- If threat_status is nil, unit is leaving combat
    if threat_status == nil then
      unit.ThreatStatus = nil
      PublishEvent("ThreatUpdate", tp_frame, unit)
    else --if threat_status ~= unit.ThreatStatus then
      unit.ThreatStatus = threat_status
      unit.ThreatLevel = THREAT_REFERENCE[threat_status]
      unit.InCombat = _G.UnitAffectingCombat(unitid)
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
  if unitid == "target" or UnitIsUnit("player", unitid) or not ShowCastBars then return end

  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    OnStartCasting(tp_frame, unitid, false)
  end
end

function Addon:UNIT_SPELLCAST_CHANNEL_START(unitid)
  if unitid == "target" or UnitIsUnit("player", unitid) or not ShowCastBars then return end

  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    OnStartCasting(tp_frame, unitid, true)
  end
end

-- Used for UNIT_SPELLCAST_STOP and UNIT_SPELLCAST_CHANNEL_STOP
function Addon:UNIT_SPELLCAST_STOP(unitid)
  if unitid == "target" or UnitIsUnit("player", unitid) or not ShowCastBars then return end

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

--  function CoreEvents:UNIT_SPELLCAST_INTERRUPTED(unitid, lineid, spellid)
--    if unitid == "target" or UnitIsUnit("player", unitid) or not ShowCastBars then return end
--  end

function Addon:COMBAT_LOG_EVENT_UNFILTERED()
  local timeStamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

  if event == "SPELL_INTERRUPT" then
    local plate = PlatesByGUID[destGUID]

    if plate and plate.TPFrame.Active then
      local visual = plate.TPFrame.visual

      local castbar = visual.Castbar
      if castbar:IsShown() then
        local db = TidyPlatesThreat.db.profile
        sourceName = gsub(sourceName, "%-[^|]+", "") -- UnitName(sourceName) only works in groups

        local _, class_id = GetPlayerInfoByGUID(sourceGUID)
        if class_id then
          sourceName = "|c" .. db.Colors.Classes[class_id].colorStr .. sourceName .. "|r"
        end

        visual.SpellText:SetText(INTERRUPTED .. " [" .. sourceName .. "]")

        local _, max_val = castbar:GetMinMaxValues()
        castbar:SetValue(max_val)
        castbar.Spark:Hide()

        local color = db.castbarColorInterrupted
        castbar:SetStatusBarColor(color.r, color.g, color.b, color.a)
        castbar.FlashTime = CASTBAR_INTERRUPT_HOLD_TIME

        -- I am assuming that OnStopCasting is called always when a cast is interrupted from
        -- _STOP events
        plate.TPFrame.unit.IsInterrupted = true

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
