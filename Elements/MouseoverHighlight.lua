---------------------------------------------------------------------------------------------------
-- Element: Moueover Highlight
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local CreateFrame = CreateFrame

-- WoW APIs
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local UnitIsUnit = UnitIsUnit

-- ThreatPlates APIs
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish

local OFFSET_HIGHLIGHT = 1
local ART_PATH = ThreatPlates.Art
local NAME_STYLE_TEXTURE = ART_PATH .. "Highlight"
local HEALTHBAR_STYLE_TEXTURE = ART_PATH .. "TP_HealthBar_Highlight"
local BACKDROP = {
  edgeFile = ART_PATH .. "TP_WhiteSquare",
  edgeSize = 1,
}

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local MouseoverHighlightFrame = CreateFrame("Frame", nil)
local CurrentMouseoverPlate
local CurrentMouseoverUnitID

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------
local Element = Addon.Elements.NewElement("MouseoverHighlight")

---------------------------------------------------------------------------------------------------
-- Mouseover Highlight Frame for detecting when mouseover ends for a unit
---------------------------------------------------------------------------------------------------

local function HideMouseoverHighlightFrame()
  if CurrentMouseoverUnitID then
    local tp_frame = CurrentMouseoverPlate
    tp_frame.unit.isMouseover = false
    tp_frame.visual.healthbar.MouseoverHighlight:Hide()

    PublishEvent("MouseoverOnLeave", tp_frame)
    CurrentMouseoverUnitID = nil
  end

  MouseoverHighlightFrame:Hide()
end

local function OnUpdateMouseoverHighlight(frame, elapsed)
  -- Mouseover unit may have been removed from nameplate (e.g., unit died) or unit may have lost mouseover
  if not CurrentMouseoverPlate.Active or UnitIsUnit("mouseover", CurrentMouseoverUnitID) then return end

  HideMouseoverHighlightFrame()
end

MouseoverHighlightFrame:SetScript("OnUpdate", OnUpdateMouseoverHighlight)
MouseoverHighlightFrame:Hide()

---------------------------------------------------------------------------------------------------
-- Core element code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
  -- Highlight for healthbar
  local healthbar = tp_frame.visual.healthbar
  healthbar.Highlight = CreateFrame("Frame", nil, healthbar)
  healthbar.Highlight:SetPoint("TOPLEFT", healthbar, "TOPLEFT", - OFFSET_HIGHLIGHT, OFFSET_HIGHLIGHT)
  healthbar.Highlight:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMRIGHT", OFFSET_HIGHLIGHT, - OFFSET_HIGHLIGHT)
  healthbar.Highlight:SetBackdrop(BACKDROP)
  healthbar.Highlight:SetBackdropBorderColor(1, 1, 1, 1)

  healthbar.HighlightTexture = healthbar.Highlight:CreateTexture(nil, "ARTWORK", 0)
  healthbar.HighlightTexture:SetTexture(HEALTHBAR_STYLE_TEXTURE)
  healthbar.HighlightTexture:SetBlendMode("ADD")
  healthbar.HighlightTexture:SetAllPoints(healthbar)

  -- Highlight for name
  healthbar.NameHighlight = healthbar:CreateTexture(nil, "ARTWORK") -- required for Headline View
  healthbar.NameHighlight:SetTexture(NAME_STYLE_TEXTURE)
  healthbar.NameHighlight:SetAllPoints(tp_frame.visual.name)
  healthbar.NameHighlight:SetBlendMode("ADD")

  healthbar.Highlight:Hide() -- HighlightTexture is shown/hidden together with Highlight
  healthbar.NameHighlight:Hide()
end

---- Called in processing event: NAME_PLATE_UNIT_ADDED
--function Element.UnitAdded(tp_frame)
--end
--
---- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.UnitRemoved(tp_frame)
--end
--
---- Called in processing event: UpdateStyle in Nameplate.lua
function Element.UpdateStyle(tp_frame, style)
  local healthbar = tp_frame.visual.healthbar
  if style.healthbar.show then
    healthbar.MouseoverHighlight = healthbar.Highlight
    healthbar.NameHighlight:Hide()
  else
    healthbar.MouseoverHighlight = healthbar.NameHighlight
    healthbar.Highlight:Hide()
  end

  healthbar.MouseoverHighlight:SetShown(tp_frame.unit.isMouseover and style.highlight.show and not tp_frame.unit.isTarget)

--  if tp_frame.unit.isMouseover then
--    local healthbar = tp_frame.visual.healthbar
--
--    if style.highlight.show and not tp_frame.unit.isTarget then
--      if style.healthbar.show then
--        -- Nameplate Style: Healthbar
--        healthbar.Highlight:Show()
--        healthbar.NameHighlight:Hide()
--      else
--        -- Nameplate Style: Name
--        healthbar.Highlight:Hide()
--        healthbar.NameHighlight:Show()
--      end
--    else
--      healthbar.Highlight:Hide()
--      healthbar.NameHighlight:Hide()
--    end
--  end
end

--function Element.UpdateSettings()
--end

-- Registered in Nameplate.lua
function Element.UPDATE_MOUSEOVER_UNIT()
  if UnitIsUnit("mouseover", "player") then return end -- TODO: target as well?

  local plate = GetNamePlateForUnit("mouseover")

  -- Check for TPFrame.Active to prevent accessing the personal resource bar
  if not plate or not plate.TPFrame.Active then return end

  HideMouseoverHighlightFrame()

  local tp_frame = plate.TPFrame
  tp_frame.unit.isMouseover = true
  tp_frame.visual.healthbar.MouseoverHighlight:SetShown(tp_frame.style.highlight.show and not tp_frame.unit.isTarget)

--  if style.highlight.show and not tp_frame.unit.isTarget then
--    local healthbar = tp_frame.visual.healthbar
--    if style.healthbar.show then
--      -- Nameplate Style: Healthbar
--      healthbar.Highlight:Show()
--      healthbar.NameHighlight:Hide()
--    else
--      -- Nameplate Style: Name
--      healthbar.Highlight:Hide()
--      healthbar.NameHighlight:Show()
--    end
--  end

  CurrentMouseoverUnitID = tp_frame.unit.unitid
  CurrentMouseoverPlate = tp_frame
  MouseoverHighlightFrame:Show()

  PublishEvent("MouseoverOnEnter", tp_frame)
end

SubscribeEvent(Element, "PLAYER_TARGET_CHANGED", Element.UPDATE_MOUSEOVER_UNIT)
