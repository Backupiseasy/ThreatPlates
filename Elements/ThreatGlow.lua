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
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish

local OFFSET_THREAT = 7.5
local ART_PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Artwork\\"
local BACKDROP = {
  edgeFile = ART_PATH .. "TP_Threat",
  edgeSize = 12,
  --insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------

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

function Element.UpdateStyle(tp_frame, style)
  tp_frame.visual.ThreatGlow:SetShown(tp_frame.unit.ThreatStatus and style.threatborder.show)
end

function Element.ThreatUpdate(tp_frame, unit)
  local threatglow = tp_frame.visual.ThreatGlow
  if unit.ThreatStatus and tp_frame.style.threatborder.show then
    threatglow:SetBackdropBorderColor(Addon:SetThreatColor(unit))
    threatglow:Show()
  else
    threatglow:Hide()
  end
end

SubscribeEvent(Element, "ThreatUpdate", Element.ThreatUpdate)
