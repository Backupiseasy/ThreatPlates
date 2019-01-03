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
local ShowOnAttackedUnitsOnly
local ThreatColor, TappedColor

---------------------------------------------------------------------------------------------------
-- Local threat functions
---------------------------------------------------------------------------------------------------

local function ShowThreatGlow(unit)
  if ShowOnAttackedUnitsOnly then
    return Addon:OnThreatTable(unit)
  else
    return true
  end
end

local function GetThreatColor(unit)
  local color

  if unit.isTapped and ShowThreatGlow(unit) then
    color = TappedColor
  elseif unit.type == "NPC" and unit.reaction ~= "FRIENDLY" then
    local unique_setting = unit.CustomPlateSettings

    --if unit.type == "NPC" and UnitAffectingCombat("player") and UnitReaction(unit.unitid, "player") <= 4 then
    if (not unique_setting or (unique_setting and unique_setting.UseThreatGlow)) and Addon:ShowThreatGlowFeedback(unit) then
      -- Use either normal style colors (configured under Healthbar - Warning Glow) or threat system colors (if enabled)
      if Settings.ON and Settings.useHPColor then
        color = Addon:GetThreatColor()
      else
        color = ThreatColor[unit.ThreatLevel]
      end
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

function Element.UpdateStyle(tp_frame, style)
  local unit = tp_frame.unit

  if unit.ThreatStatus and style.threatborder.show then
    local threatglow = tp_frame.visual.ThreatGlow
    threatglow:SetBackdropBorderColor(GetThreatColor(unit))
    threatglow:Show()
  else
    tp_frame.visual.ThreatGlow:Hide()
  end
end

function Element.ThreatUpdate(tp_frame, unit)
  if unit.ThreatStatus and tp_frame.style.threatborder.show then
    local threatglow = tp_frame.visual.ThreatGlow
    threatglow:SetBackdropBorderColor(GetThreatColor(unit))
    threatglow:Show()
  else
    tp_frame.visual.ThreatGlow:Hide()
  end
end

function Element.UpdateSettings()
  Settings = TidyPlatesThreat.db.profile.threat

  ShowOnAttackedUnitsOnly = TidyPlatesThreat.db.profile.ShowThreatGlowOnAttackedUnitsOnly

  ThreatColor = Settings.settings.normal.threatcolor
  TappedColor = Settings.ColorByReaction.TappedUnit

  SubscribeEvent(Element, "ThreatUpdate", Element.ThreatUpdate)
end
