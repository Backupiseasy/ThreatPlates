---------------------------------------------------------------------------------------------------
-- Element: Warning Glow for Threat
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local CreateFrame = CreateFrame
local InCombatLockdown, IsInInstance = InCombatLockdown, IsInInstance
local UnitIsConnected, UnitAffectingCombat = UnitIsConnected, UnitAffectingCombat

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local RGB = Addon.RGB
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish

local OFFSET_THREAT = 7.5
local ART_PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Artwork\\"
local BACKDROP = {
  edgeFile = ART_PATH .. "TP_Threat",
  edgeSize = 12,
  --insets = { left = 0, right = 0, top = 0, bottom = 0 },
}
local COLOR_TRANSPARENT = RGB(0, 0, 0, 0) -- opaque

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local Settings
local ShowOnAttackedUnitsOnly, UseHeuristicInInstances
local ThreatColorWOThreatSystem, TappedColor

---------------------------------------------------------------------------------------------------
-- Local threat functions
---------------------------------------------------------------------------------------------------

local function ShowThreatGlow(unit)
  if ShowOnAttackedUnitsOnly then
    if IsInInstance() and UseHeuristicInInstances then
      return UnitAffectingCombat(unit.unitid)
    else
      return Addon:OnThreatTable(unit)
    end
  else
    return UnitAffectingCombat(unit.unitid)
  end
end

local function GetThreatGlowColor(unit)
  local color

  if unit.isTapped and ShowThreatGlow(unit) then
    color = TappedColor
  elseif unit.type == "NPC" and unit.reaction ~= "FRIENDLY" then
    local style = unit.style

    local unique_setting = unit.CustomPlateSettings
    if unique_setting and unique_setting.UseThreatGlow then
      -- set style to tank/dps or normal
      style = Addon:GetThreatStyle(unit)
    end

    -- Split this up into two if-parts, otherweise there is an inconsistency between
    -- healthbar color and threat glow at the beginning of a combat when the player
    -- is already in combat, but not yet on the mob's threat table for a sec or so.
    if Settings.ON and Settings.useHPColor then
      if style == "dps" or style == "tank" then
        color = Addon:GetThreatColor(unit, style, ShowOnAttackedUnitsOnly)
      end
    elseif InCombatLockdown() and (style == "normal" or style == "dps" or style == "tank") then
      color = Addon:GetThreatColor(unit, style, ShowOnAttackedUnitsOnly)
    end
  end

  color = color or COLOR_TRANSPARENT

  return color.r, color.g, color.b, color.a
end

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------

local Element = Addon.Elements.NewElement("ThreatGlow")

-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
  local element_frame = CreateFrame("Frame", nil, tp_frame)
  element_frame:SetFrameLevel(tp_frame:GetFrameLevel())

  element_frame:SetPoint("TOPLEFT", tp_frame, "TOPLEFT", - OFFSET_THREAT, OFFSET_THREAT)
  element_frame:SetPoint("BOTTOMRIGHT", tp_frame, "BOTTOMRIGHT", OFFSET_THREAT, - OFFSET_THREAT)
  element_frame:SetBackdrop(BACKDROP)

  element_frame:SetBackdropBorderColor(0, 0, 0, 0) -- Transparent color as default

  tp_frame.visual.ThreatGlow = element_frame
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
--function Element.UnitAdded(tp_frame)
--end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.UnitRemoved(tp_frame)
--  tp_frame.visual.ThreatGlow:Hide() -- done in UpdateStyle
--end

function Element.UpdateStyle(tp_frame, style, plate_style)
  local threatglow = tp_frame.visual.ThreatGlow

  if plate_style == "None" or not style.threatborder.show then
    threatglow:Hide()
    return
  end

  local unit = tp_frame.unit
  if unit.ThreatStatus then
    threatglow:SetBackdropBorderColor(GetThreatGlowColor(unit))
    threatglow:Show()
  else
    threatglow:Hide()
  end
end

function Element.ThreatUpdate(tp_frame, unit)
  if unit.ThreatStatus and tp_frame.style.threatborder.show then
    local threatglow = tp_frame.visual.ThreatGlow
    threatglow:SetBackdropBorderColor(GetThreatGlowColor(unit))
    threatglow:Show()
  else
    tp_frame.visual.ThreatGlow:Hide()
  end
end

function Element.UpdateSettings()
  local db = TidyPlatesThreat.db.profile
  Settings = db.threat

  ShowOnAttackedUnitsOnly = db.ShowThreatGlowOnAttackedUnitsOnly
  UseHeuristicInInstances = db.UseHeuristicInInstances

  ThreatColorWOThreatSystem = db.settings.normal.threatcolor
  TappedColor = db.ColorByReaction.TappedUnit

  SubscribeEvent(Element, "ThreatUpdate", Element.ThreatUpdate)
end
