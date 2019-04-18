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
local TidyPlatesThreat = TidyPlatesThreat
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
local TargetHighlightDisabled

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
    tp_frame.visual.Healthbar.MouseoverHighlight:Hide()

    PublishEvent("MouseoverOnLeave", tp_frame)
    CurrentMouseoverUnitID = nil
  end

  MouseoverHighlightFrame:Hide()
end

local function OnUpdateMouseoverHighlight(frame, elapsed)
  -- Mouseover unit may have been removed from nameplate (e.g., unit died) or unit may have lost mouseover
  if not CurrentMouseoverPlate.Active then
    -- No need to hide stuff of set isMouseover to false as the plate was already wiped
    CurrentMouseoverUnitID = nil
    MouseoverHighlightFrame:Hide()
  elseif not UnitIsUnit("mouseover", CurrentMouseoverUnitID) then
    HideMouseoverHighlightFrame()
  end
end

MouseoverHighlightFrame:SetScript("OnUpdate", OnUpdateMouseoverHighlight)
MouseoverHighlightFrame:Hide()

---------------------------------------------------------------------------------------------------
-- Core element code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
  -- Highlight for healthbar
  local healthbar = tp_frame.visual.Healthbar
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
  healthbar.NameHighlight = tp_frame:CreateTexture(nil, "ARTWORK") -- required for Headline View
  healthbar.NameHighlight:SetTexture(NAME_STYLE_TEXTURE)
  healthbar.NameHighlight:SetBlendMode("ADD")
  healthbar.NameHighlight:SetAllPoints(tp_frame.visual.NameText)
  
  healthbar.Highlight:Hide() -- HighlightTexture is shown/hidden together with Highlight
  healthbar.NameHighlight:Hide()
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
--function Element.UnitAdded(tp_frame)
--end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.UnitRemoved(tp_frame)
--end

-- Called in processing event: UpdateStyle in Nameplate.lua
function Element.UpdateStyle(tp_frame, style, plate_style)
  local healthbar = tp_frame.visual.Healthbar

  if plate_style == "NONE" or TargetHighlightDisabled then
    healthbar.Highlight:Hide()
    healthbar.NameHighlight:Hide()
    return
  end

  if style.healthbar.show then
    healthbar.MouseoverHighlight = healthbar.Highlight
    healthbar.NameHighlight:Hide()
  else
    healthbar.MouseoverHighlight = healthbar.NameHighlight
    healthbar.Highlight:Hide()
  end

  healthbar.MouseoverHighlight:SetShown(tp_frame.unit.isMouseover and style.highlight.show and (not tp_frame.unit.isTarget or TargetHighlightDisabled))
end

function Element.UpdateSettings()
  TargetHighlightDisabled = not (TidyPlatesThreat.db.profile.targetWidget.ON or TidyPlatesThreat.db.profile.HeadlineView.ShowTargetHighlight)
end

-- Registered in Nameplate.lua
function Element.UPDATE_MOUSEOVER_UNIT()
  if UnitIsUnit("mouseover", "player") then return end -- TODO: target as well?

  local plate = GetNamePlateForUnit("mouseover")

  -- Check for TPFrame.Active to prevent accessing the personal resource bar
  if not plate or not plate.TPFrame.Active then return end

  HideMouseoverHighlightFrame()

  local tp_frame = plate.TPFrame
  tp_frame.unit.isMouseover = true
  tp_frame.visual.Healthbar.MouseoverHighlight:SetShown(tp_frame.style.highlight.show and (not tp_frame.unit.isTarget or TargetHighlightDisabled))

  CurrentMouseoverUnitID = tp_frame.unit.unitid
  CurrentMouseoverPlate = tp_frame
  MouseoverHighlightFrame:Show()

  PublishEvent("MouseoverOnEnter", tp_frame)
end

SubscribeEvent(Element, "PLAYER_TARGET_CHANGED", Element.UPDATE_MOUSEOVER_UNIT)
