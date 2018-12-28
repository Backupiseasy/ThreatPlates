local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------------------------
-- Variables and References
---------------------------------------------------------------------------------------------------------------------

-- Local References
local _
local type, select, pairs, tostring  = type, select, pairs, tostring 			    -- Local function copy
local max, tonumber, math_abs = math.max, tonumber, math.abs

-- WoW APIs
local wipe = wipe
local WorldFrame, UIParent, CreateFrame, GameFontNormal, UNKNOWNOBJECT, INTERRUPTED = WorldFrame, UIParent, CreateFrame, GameFontNormal, UNKNOWNOBJECT, INTERRUPTED
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local UnitName, UnitIsUnit, UnitReaction, UnitExists = UnitName, UnitIsUnit, UnitReaction, UnitExists
local UnitClassification = UnitClassification
local UnitLevel = UnitLevel
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitEffectiveLevel = UnitEffectiveLevel
local GetCreatureDifficultyColor = GetCreatureDifficultyColor
local UnitSelectionColor = UnitSelectionColor
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitThreatSituation = UnitThreatSituation
local UnitAffectingCombat = UnitAffectingCombat
local GetRaidTargetIndex = GetRaidTargetIndex
local UnitIsTapDenied = UnitIsTapDenied
local GetTime = GetTime
local UnitChannelInfo, UnitCastingInfo = UnitChannelInfo, UnitCastingInfo
local UnitPlayerControlled = UnitPlayerControlled
local GetCVar, Lerp, CombatLogGetCurrentEventInfo = GetCVar, Lerp, CombatLogGetCurrentEventInfo

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local Widgets = Addon.Widgets
local RegisterEvent, PublishEvent = Addon.EventService.RegisterEvent, Addon.EventService.Publish
local ElementsCreated, ElementsUnitData, ElementsUnitAdded, ElementsUnitRemoved = Addon.Elements.Created, Addon.Elements.UnitData, Addon.Elements.UnitAdded, Addon.Elements.UnitRemoved
local ElementsUpdateStyle, ElementsUpdateSettings = Addon.Elements.UpdateStyle, Addon.Elements.UpdateSettings

-- Constants

local CASTBAR_INTERRUPT_HOLD_TIME = Addon.CASTBAR_INTERRUPT_HOLD_TIME
local ON_UPDATE_INTERVAL = Addon.ON_UPDATE_PER_FRAME
local PLATE_FADE_IN_TIME = Addon.PLATE_FADE_IN_TIME

-- Internal Data
local LastTargetPlate
local ShowCastBars = true
local EMPTY_TEXTURE = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Empty"
local UpdateAll = false

local PlateOnUpdateQueue = {}

-- Cached CVARs (updated on every PLAYER_ENTERING_WORLD event
local CVAR_NameplateOccludedAlphaMult
-- Cached database settings
local SettingsEnabledFading
local SettingsOccludedAlpha, SettingsEnabledOccludedAlpha
local SettingsShowEnemyBlizzardNameplates, SettingsShowFriendlyBlizzardNameplates

-- External references to internal data
local PlatesCreated = Addon.PlatesCreated
local PlatesVisible = Addon.PlatesVisible
local PlatesByUnit = Addon.PlatesByUnit
local PlatesByGUID = Addon.PlatesByGUID

Addon.Theme = {}
local ActiveTheme = Addon.Theme

---------------------------------------------------------------------------------------------------------------------
-- Core Function Declaration
---------------------------------------------------------------------------------------------------------------------
-- Helpers
local function IsPlateShown(plate) return plate and plate:IsShown() end

-- Queueing
local function SetUpdateMe(plate) plate.UpdateMe = true end
local function SetUpdateAll() UpdateAll = true end

-- Indicators
local UpdatePlate_SetAlpha, UpdatePlate_SetAlphaOnUpdate
local UpdatePlate_Transparency

---------------------------------------------------------------------------------------------------------------------
--  Unit Updates: Updates Unit Data, Requests indicator updates
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

local THREAT_REFERENCE = {
  [0] = "LOW",
  [1] = "MEDIUM",
  [2] = "MEDIUM",
  [3] = "HIGH",
}

-- UpdateUnitIdentity: Updates Low-volatility Unit Data
-- (This is essentially static data)
--------------------------------------------------------
local function UpdateUnitIdentity(unit, unitid)
  unit.unitid = unitid
  unit.guid = UnitGUID(unitid)

  unit.classification = UnitClassification(unitid)
  unit.isElite = ELITE_REFERENCE[unit.classification] or false
  unit.isRare = RARE_REFERENCE[unit.classification] or false
  unit.isMini = unit.classification == "minus"

  unit.isBoss = UnitLevel(unitid) == -1
  if unit.isBoss then
    unit.classification = "boss"
  end
  unit.IsBossOrRare = (unit.isBoss or unit.isRare)

  if UnitIsPlayer(unitid) then
    _, unit.class = UnitClass(unitid)
    unit.type = "PLAYER"
  else
    unit.class = ""
    unit.type = "NPC"
  end
end

-- GetUnitReaction: Determines the reaction, and type of unit from the health bar color
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

local function UpdateUnitReaction(unit, unitid)
  unit.red, unit.green, unit.blue = UnitSelectionColor(unitid)
  unit.reaction = GetReactionByColor(unit.red, unit.green, unit.blue) or "HOSTILE"

  -- Enemy players turn to neutral, e.g., when mounting a flight path mount, so fix reaction in that situations
  if unit.reaction == "NEUTRAL" and (unit.type == "PLAYER" or UnitPlayerControlled(unitid)) then
    unit.reaction = "HOSTILE"
  end
end

local function UpdateUnitCondition(unit, unitid)
  -- Unit Reaction
  unit.red, unit.green, unit.blue = UnitSelectionColor(unitid)

  unit.reaction = GetReactionByColor(unit.red, unit.green, unit.blue) or "HOSTILE"
  -- Enemy players turn to neutral, e.g., when mounting a flight path mount, so fix reaction in that situations
  if unit.reaction == "NEUTRAL" and (unit.type == "PLAYER" or UnitPlayerControlled(unitid)) then
    unit.reaction = "HOSTILE"
  end

  unit.health = UnitHealth(unitid) or 0
  unit.healthmax = UnitHealthMax(unitid) or 1

  unit.isTapped = UnitIsTapDenied(unitid)
end

local function UpdateUnitContext(unit, unitid)
  -- Required here for initialization in OnShowNameplate as the corresponding events won't be triggerd, e.g., when
  -- enabling/disabling nameplates
  -- Also: for config changes which reset all plates without calling TARGET_CHANGED, MOUSEOVER, ...
  unit.isTarget = UnitIsUnit("target", unitid)
  unit.isMouseover = UnitIsUnit("mouseover", unitid) -- or move that to MouseoverHighlight.UnitData
end

---------------------------------------------------------------------------------------------------------------------
-- Nameplate Updating:
---------------------------------------------------------------------------------------------------------------------

-- UpdateIndicator_CustomScaleText: Updates indicators for custom text and scale
local function UpdateIndicator_CustomScale(tp_frame, unit)
  local style = tp_frame.style

  --if unit.health and (extended.requestedAlpha > 0) then
  --if unit.health and extended.CurrentAlpha > 0 then
  if unit.health then
    -- Scale
    tp_frame:SetScale(Addon.UIScale * Addon:SetScale(unit))

    Addon:UpdateIndicatorNameplateColor(tp_frame)
  end
end

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
  unit.spellInterruptible = not unit.spellIsShielded

  visual.SpellText:SetText(text)
  visual.SpellIcon:SetTexture(texture)
  --visual.SpellIcon:SetDrawLayer("ARTWORK", 7)

  castbar:SetAllColors(Addon:SetCastbarColor(unit))
  castbar:SetShownInterruptOverlay(unit.spellIsShielded)

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

local function UpdateStyle(tp_frame)
  local style = tp_frame.style

  -- Frame
  tp_frame:ClearAllPoints()
  tp_frame:SetPoint(style.frame.anchor, tp_frame.Parent, style.frame.anchor, style.frame.x, style.frame.y)
  tp_frame:SetSize(style.healthbar.width, style.healthbar.height)

  ElementsUpdateStyle(tp_frame, style)

--  if not tp_frame.TestBackground then
--    tp_frame.TestBackground = tp_frame:CreateTexture(nil, "BACKGROUND")
--    tp_frame.TestBackground:SetAllPoints(tp_frame)
--    tp_frame.TestBackground:SetTexture(ThreatPlates.Media:Fetch('statusbar', TidyPlatesThreat.db.profile.AuraWidget.BackgroundTexture))
--    tp_frame.TestBackground:SetVertexColor(0,0,0,0.5)
--  end
end

---------------------------------------------------------------------------------------------------------------------
-- Nameplate Script Handlers
---------------------------------------------------------------------------------------------------------------------

-- CheckNameplateStyle
local function CheckNameplateStyle(tp_frame)
  local unit = tp_frame.unit

  local new_stylename = Addon:SetStyle(unit)
  local new_style = ActiveTheme[new_stylename]

  if tp_frame.stylename ~= new_stylename then
    tp_frame.stylename = new_stylename
    tp_frame.style = new_style
    unit.style = new_stylename

    UpdateStyle(tp_frame)
--      local headline_mode_after = (stylename == "NameOnly" or stylename == "NameOnly-Unique")
--      if headline_mode_before ~= headline_mode_after then
--        print ("Change of nameplate mode:", unit.name, headline_mode_before, "=>", headline_mode_after)
--      end

    -- TOOD: optimimze that - call OnUnitAdded only when the plate is initialized the first time for a unit, not if only the style changes
    Widgets:OnUnitAdded(tp_frame, unit)
    --Addon:WidgetsModeChanged(extended, unit)
  end
end

-- UpdateUnitCache
local function UpdateUnitCache(tp_frame, unit)
  local unitcache = tp_frame.unitcache
  for key, value in pairs(unit) do
    unitcache[key] = value
  end
end

-- ProcessUnitChanges
local function ProcessUnitChanges(tp_frame)
  local unit, unitcache, style = tp_frame.unit, tp_frame.unitcache, tp_frame.style

  -- Unit Cache: Determine if data has changed
  local unitchanged = false

  for key, value in pairs(unit) do
    if unitcache[key] ~= value then
      unitchanged = true
      break -- one change is enough to update the unit
    end
  end

  -- Update Style/Indicators
  if unitchanged or UpdateAll or (not style) then
    CheckNameplateStyle(tp_frame)
  end

  -- Update Delegates
  UpdatePlate_Transparency(tp_frame, unit)
  UpdateIndicator_CustomScale(tp_frame, unit)

  -- Cache the old unit information
  UpdateUnitCache(tp_frame, unit)
end

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
  tp_frame.unitcache = {}
end

-- OnShowNameplate
local function OnShowNameplate(plate, unitid)
  local tp_frame = plate.TPFrame
  local unit = tp_frame.unit

  UpdateUnitIdentity(unit, unitid)
  unit.name, _ = UnitName(unitid)

  tp_frame.stylename = ""

  tp_frame.IsOccluded = false
  tp_frame.CurrentAlpha = nil
  tp_frame:SetAlpha(0)

  PlatesVisible[plate] = unitid
  PlatesByUnit[unitid] = tp_frame
  PlatesByGUID[unit.guid] = plate

  Addon:UpdateNameplateStyle(plate, unitid)

  -- Update state data for which there are no events when players enters world

  ElementsUnitData(tp_frame)

  UpdateUnitContext(unit, unitid)
  UpdateUnitCondition(unit, unitid)	-- This updates a bunch of properties

  Addon:UnitStyle_NameDependent(unit)
  ProcessUnitChanges(tp_frame)

  ElementsUnitAdded(tp_frame)

  -- Call this after the plate is shown as OnStartCasting checks if the plate is shown; if not, the castbar is hidden and
  -- nothing is updated
  OnUpdateCastMidway(tp_frame, unitid)
end

-- OnUpdateNameplate
local function OnUpdateNameplate(plate)
  local tp_frame = plate.TPFrame
  local unit = tp_frame.unit
  local unitid = unit.unitid

  --Addon:UpdateUnitIdentity(plate.TPFrame, unitid)
  --UpdateUnitContext(unit, unitid)
  UpdateUnitCondition(unit, unitid)	-- This updates a bunch of properties
  ProcessUnitChanges(tp_frame)
  OnUpdateCastMidway(tp_frame, unitid)
end

-- OnHealthUpdate
local function OnHealthUpdate(plate)
  local tp_frame = plate.TPFrame
  local unit = tp_frame.unit
  local unitid = unit.unitid

  UpdateUnitCondition(unit, unitid)
  ProcessUnitChanges(tp_frame)
  OnUpdateCastMidway(tp_frame, unitid)

  -- Fix a bug where the overlay for non-interruptible casts was shown even for interruptible casts when entering combat while the unit was already casting
  --    if unit.isCasting and visual.castbar:IsShown()then
  --      visual.castbar:SetShownInterruptOverlay(unit.spellIsShielded)
  --    end
end

-- OnResetNameplate
local function OnResetNameplate(plate)
  -- wipe(plate.TPFrame.unit)
  wipe(plate.TPFrame.unitcache)

  OnShowNameplate(plate, PlatesVisible[plate])
end


-- Update individual plate
local function UnitConditionChanged(unitid)
  if UnitIsUnit("player", unitid) then return end -- skip personal resource bar

  local plate = GetNamePlateForUnit(unitid)
  if plate then
    OnHealthUpdate(plate)
  end
end

-- Update everything
local function WorldConditionChanged()
  SetUpdateAll()
end

---------------------------------------------------------------------------------------------------------------------
-- Indicators: These functions update the color, texture, strings, and frames within a style.
---------------------------------------------------------------------------------------------------------------------

-- Update the health bar and name coloring, if needed
function Addon:UpdateIndicatorNameplateColor(tp_frame)
  local visual = tp_frame.visual

  if visual.Healthbar:IsShown() then
    visual.Healthbar:SetAllColors(Addon:SetHealthbarColor(tp_frame.unit))
  end
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
function Addon:DisableCastBars() ShowCastBars = false end
function Addon:EnableCastBars() ShowCastBars = true end

function Addon:ForceUpdate()
  wipe(PlateOnUpdateQueue)

  Addon:UpdateConfigurationStatusText()
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
    PlateOnUpdateQueue[#PlateOnUpdateQueue + 1] = UpdatePlate_SetAlphaOnUpdate
  else
    UpdatePlate_Transparency = UpdatePlate_SetAlpha
  end

  for plate in pairs(self.PlatesVisible) do
    if plate.TPFrame.Active then
      OnResetNameplate(plate)
    end
  end
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
  "PLAYER_LOGIN",
  "PLAYER_LOGOUT",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_REGEN_DISABLED",

  "NAME_PLATE_CREATED",
  "NAME_PLATE_UNIT_ADDED",
  "NAME_PLATE_UNIT_REMOVED",

  "PLAYER_TARGET_CHANGED",
  --PLAYER_FOCUS_CHANGED = WorldConditionChanged, -- no idea why we shoul listen for this event
  UPDATE_MOUSEOVER_UNIT = Addon.Elements.GetElement("MouseoverHighlight").UPDATE_MOUSEOVER_UNIT,
  "RAID_TARGET_UPDATE",

  "UNIT_NAME_UPDATE",
  --"UNIT_MAXHEALTH",
  "UNIT_HEALTH_FREQUENT",
  --"UNIT_ABSORB_AMOUNT_CHANGED",
  "UNIT_THREAT_LIST_UPDATE",
  "UNIT_FACTION",
  UNIT_LEVEL = Addon.Elements.GetElement("Level").UNIT_LEVEL,

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

  PLAYER_CONTROL_LOST = WorldConditionChanged,
  PLAYER_CONTROL_GAINED = WorldConditionChanged,

  "COMBAT_LOG_EVENT_UNFILTERED",
  "UI_SCALE_CHANGED",

  --"PLAYER_ALIVE",
  --"PLAYER_LEAVING_WORLD",
  --"PLAYER_TALENT_UPDATE"

  -- CVAR_UPDATE,
  -- DISPLAY_SIZE_CHANGED,     -- Blizzard also uses this event
  -- VARIABLES_LOADED,         -- Blizzard also uses this event
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

function Addon:PLAYER_LOGIN(...)
  TidyPlatesThreat.db.profile.cache = {}

  if TidyPlatesThreat.db.char.welcome then
    ThreatPlates.Print(L["|cff89f559Threat Plates:|r Welcome back |cff"]..ThreatPlates.HCC[self.PlayerClass]..UnitName("player").."|r!!")
  end
end

function Addon:PLAYER_LOGOUT(...)
  TidyPlatesThreat.db.profile.cache = {}
end

-- Fired when the player enters the world, reloads the UI, enters/leaves an instance or battleground, or respawns at a graveyard.
-- Also fires any other time the player sees a loading screen
function Addon:PLAYER_ENTERING_WORLD()
  -- Sync internal settings with Blizzard CVars
  -- SetCVar("ShowClassColorInNameplate", 1)

  local db = TidyPlatesThreat.db.profile.questWidget
  if db.ON or db.ShowInHeadlineView then
    self.CVars:Set("showQuestTrackingTooltips", 1)
    --SetCVar("showQuestTrackingTooltips", 1)
  else
    self.CVars:RestoreFromProfile("showQuestTrackingTooltips")
  end

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

--  local tp_frame
--  for plate, _ in pairs(PlatesVisible) do
--    tp_frame = plate.TPFrame
--    print ("Combat ended ", tp_frame.unit.unitid, "-", tp_frame.unit.InCombat)
--    if tp_frame.unit.InCombat then
--      PublishEvent("CombatEnded", tp_frame)
--    end
--  end

  SetUpdateAll()
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

  SetUpdateAll()
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
  tp_frame:Hide()

  PlatesVisible[plate] = nil
  PlatesByUnit[unitid] = nil
  if tp_frame.unit.guid then -- maybe hide directly after create with unit added?
    PlatesByGUID[tp_frame.unit.guid] = nil
  end

  ElementsUnitRemoved(tp_frame)
  Widgets:OnUnitRemoved(tp_frame, tp_frame.unit)

  wipe(tp_frame.unit)
  wipe(tp_frame.unitcache)

  -- Remove anything from the function queue
  plate.UpdateMe = false
end

function Addon:UNIT_NAME_UPDATE(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    local unit, stylename = tp_frame.unit, tp_frame.stylename

    unit.name, _ = UnitName(unitid)

    --Addon:UnitStyle_UnitType(extended, unit)
    local plate_style = Addon:UnitStyle_NameDependent(unit)
    if plate_style ~= stylename then
      -- Totem or Custom Nameplate
      --print ("Unit Style changed:", plate_style, "=>", extended.stylename)
      ProcessUnitChanges(tp_frame)
    end
  end
end

function Addon:PLAYER_TARGET_CHANGED()
  -- Target Castbar Offset
  local tp_frame
  if LastTargetPlate and LastTargetPlate.TPFrame.Active then
    tp_frame = LastTargetPlate.TPFrame

    tp_frame.unit.isTarget = false
    LastTargetPlate = nil

    PublishEvent("TargetLost", tp_frame)
  end

  local plate = GetNamePlateForUnit("target")
  --if plate and plate.TPFrame and plate.TPFrame.stylename ~= "" then
  if plate and plate.TPFrame.Active then
    tp_frame = plate.TPFrame

    tp_frame.unit.isTarget = true
    LastTargetPlate = plate

    PublishEvent("TargetGained", tp_frame)
  end

  SetUpdateAll()
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

function  Addon:UNIT_THREAT_LIST_UPDATE(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    local threat_status = UnitThreatSituation("player", unitid)

    local unit = tp_frame.unit
    -- If threat_status is nil, unit is leaving combat
    if threat_status == nil then
      unit.ThreatStatus = nil
    elseif threat_status ~= unit.ThreatStatus then
      unit.ThreatStatus = threat_status
      unit.ThreatLevel = THREAT_REFERENCE[threat_status]
      unit.InCombat = UnitAffectingCombat(unitid)

      -- plate.UpdateMe = true -- transparency, scale, and color still must be updated this way

      -- UpdateUnitContext(unit, unitid)
      -- ProcessUnitChanges()
      CheckNameplateStyle(tp_frame)
      UpdatePlate_Transparency(tp_frame, unit)
      UpdateIndicator_CustomScale(tp_frame, unit)
      UpdateUnitCache(tp_frame, unit)
    end

    PublishEvent("ThreatUpdate", tp_frame, unit)
  end
end

-- Update all elements that depend on the unit's reaction towards the player
function Addon:UNIT_FACTION(unitid)
  if unitid == "player" then
    SetUpdateAll() -- Update all plates
  else
    -- Update just the unitid's plate
    local plate = GetNamePlateForUnit(unitid)
    if plate and plate.TPFrame.Active then
      local tp_frame = plate.TPFrame
      local unit = tp_frame.unit

      UpdateUnitCondition(unit, unitid)
      ProcessUnitChanges(tp_frame)
    end
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
    castbar.IsCasting = false
    castbar.IsChanneling = false

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
        sourceName, _ = UnitName(sourceName) or sourceName, nil
        local _, class = UnitClass(sourceName)
        if class then
          sourceName = "|cff" .. ThreatPlates.HCC[class] .. sourceName .. "|r"
        end

        visual.SpellText:SetText(INTERRUPTED .. " [" .. sourceName .. "]")
        local _, max_val = castbar:GetMinMaxValues()
        castbar:SetValue(max_val)
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
  Addon:UIScaleChanged()
  Addon:ForceUpdate()
end

---------------------------------------------------------------------------------------------------------------------
-- Nameplate Detection & Update Loop
---------------------------------------------------------------------------------------------------------------------

local TidyPlatesCore = CreateFrame("Frame", nil, WorldFrame)
TidyPlatesCore:SetFrameStrata("TOOLTIP") 	-- When parented to WorldFrame, causes OnUpdate handler to run close to last

-- OnUpdate; This function is run frequently, on every clock cycle
local function OnUpdate(self, e)
  local plate, curChildren

  for plate in pairs(PlatesVisible) do
    local UpdateMe = UpdateAll or plate.UpdateMe
    local UpdateHealth = plate.UpdateHealth

    -- Check for an Update Request
    if UpdateMe or UpdateHealth then
      print ("Nameplate - OnUpdate:", plate.TPFrame.unit.unitid)

      if not UpdateMe then
        OnHealthUpdate(plate)
      else
        OnUpdateNameplate(plate)
      end
      plate.UpdateMe = false
      plate.UpdateHealth = false
    end

    -- This would be useful for alpha fades
    -- But right now it's just going to get set directly
    -- extended:SetAlpha(extended.requestedAlpha)
  end

  -- Reset Mass-Update Flag
  UpdateAll = false
end

TidyPlatesCore:SetScript("OnUpdate", OnUpdate)
