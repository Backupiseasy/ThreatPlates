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

-- ThreatPlates APIs
local RGB = Addon.RGB
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish
local GetThreatColor = Addon.Color.GetThreatColor
local BackdropTemplate = Addon.BackdropTemplate

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: UnitAffectingCombat

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
local TappedColor

---------------------------------------------------------------------------------------------------
-- Local threat functions
---------------------------------------------------------------------------------------------------

-- This function is only called if unit.ThreatLevel ~= nil meaning that the unit is in in combat with
-- the player
local function GetThreatGlowColor(unit)
  local color

  if unit.type == "NPC" and unit.reaction ~= "FRIENDLY" then    
    if unit.IsTapDenied then
      color = TappedColor
    else
      color = GetThreatColor(unit)
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
function Element.PlateCreated(tp_frame)
  local element_frame = CreateFrame("Frame", nil, tp_frame, BackdropTemplate)
  element_frame:SetFrameLevel(tp_frame:GetFrameLevel())

  element_frame:SetPoint("TOPLEFT", tp_frame, "TOPLEFT", - OFFSET_THREAT, OFFSET_THREAT)
  element_frame:SetPoint("BOTTOMRIGHT", tp_frame, "BOTTOMRIGHT", OFFSET_THREAT, - OFFSET_THREAT)
  element_frame:SetBackdrop(BACKDROP)

  element_frame:SetBackdropBorderColor(0, 0, 0, 0) -- Transparent color as default

  tp_frame.visual.ThreatGlow = element_frame
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
-- PlateStyle is always ~= "None" here
function Element.PlateUnitAdded(tp_frame)
  local unit = tp_frame.unit
  if tp_frame.style.threatborder.show and unit.ThreatLevel then
    local unique_setting = unit.CustomPlateSettings
    if not unique_setting or unique_setting.UseThreatGlow then
      local threatglow = tp_frame.visual.ThreatGlow
      threatglow:SetBackdropBorderColor(GetThreatGlowColor(unit))
      threatglow:Show()
    else
      tp_frame.visual.ThreatGlow:Hide()
    end
  else
    tp_frame.visual.ThreatGlow:Hide()
  end
end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.PlateUnitRemoved(tp_frame)
--  tp_frame.visual.ThreatGlow:Hide() -- done in UpdateStyle
--end

function Element.UpdateStyle(tp_frame, style, plate_style)
  if plate_style == "None" then
    tp_frame.visual.ThreatGlow:Hide()
  else
    Element.PlateUnitAdded(tp_frame)
  end
end

function Element.ThreatUpdate(tp_frame, unit)
  if plate_style == "None" then
    tp_frame.visual.ThreatGlow:Hide()
  else
    Element.PlateUnitAdded(tp_frame)
  end
end

function Element.UpdateSettings()
  local db = Addon.db.profile
  Settings = db.threat

  TappedColor = db.ColorByReaction.TappedUnit

  SubscribeEvent(Element, "ThreatUpdate", Element.ThreatUpdate)
end
