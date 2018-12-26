local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Element: Moueover Highlight
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local CreateFrame = CreateFrame

-- WoW APIs
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local UnitIsUnit = UnitIsUnit

-- ThreatPlates APIs
local ON_UPDATE_PER_FRAME = Addon.ON_UPDATE_PER_FRAME
local OFFSET_HIGHLIGHT = 1
local ART_PATH = ThreatPlates.Art

local NAME_STYLE_TEXTURE = ART_PATH .. "Highlight"
local HEALTHBAR_STYLE_TEXTURE = ART_PATH .. "TP_HealthBar_Highlight"

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------

local Element = Addon.Elements.NewElement("MouseoverHighlight")

local MouseoverHighlightFrame = CreateFrame("Frame", nil)
local CurrentMouseoverPlate
local CurrentMouseoverUnitID

local function HideMouseoverHighlightFrame()
  if CurrentMouseoverUnitID then
    print ("Hiding previous Mouseover Highlight Plate")

    local tp_frame = CurrentMouseoverPlate
    tp_frame.unit.isMouseover = false

    local healthbar = tp_frame.visual.healthbar
    healthbar.Highlight:Hide()
    healthbar.NameHighlight:Hide()

    --PublishEvent("MouseoverOnLeave", tp_frame)
    CurrentMouseoverPlate.Parent.UpdateMe = true
    CurrentMouseoverUnitID = nil
  end

  MouseoverHighlightFrame:Hide()
end

local function HideMouseoverHighlight()
  local tp_frame = CurrentMouseoverPlate

  tp_frame.unit.isMouseover = false

  local healthbar = tp_frame.visual.healthbar
  healthbar.Highlight:Hide()
  healthbar.NameHighlight:Hide()
end

local function OnUpdateMouseoverHighlight(frame, elapsed)
  print ("OnUpdateMouseoverHighlight:")

  if UnitIsUnit("mouseover", CurrentMouseoverUnitID) then return end

  print ("UPDATE_MOUSEOVER_UNIT: Leaving => ", CurrentMouseoverUnitID)

  HideMouseoverHighlightFrame()
end

MouseoverHighlightFrame:SetScript("OnUpdate", OnUpdateMouseoverHighlight)
MouseoverHighlightFrame:Hide()

-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
  -- Highlight for healthbar
  local healthbar = tp_frame.visual.healthbar
  healthbar.Highlight = CreateFrame("Frame", nil, healthbar)
  healthbar.Highlight:SetPoint("TOPLEFT", healthbar, "TOPLEFT", - OFFSET_HIGHLIGHT, OFFSET_HIGHLIGHT)
  healthbar.Highlight:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMRIGHT", OFFSET_HIGHLIGHT, - OFFSET_HIGHLIGHT)
  healthbar.Highlight:SetBackdrop({
    edgeFile = ART_PATH .. "TP_WhiteSquare",
    edgeSize = 1,
  })
  healthbar.Highlight:SetBackdropBorderColor(1, 1, 1, 1)

  healthbar.HighlightTexture = healthbar.Highlight:CreateTexture(nil, "ARTWORK", 0)
  healthbar.HighlightTexture:SetTexture(HEALTHBAR_STYLE_TEXTURE)
  healthbar.HighlightTexture:SetBlendMode("ADD")
  healthbar.HighlightTexture:SetAllPoints(healthbar)
  --frame.HighlightTexture:SetVertexColor(1,0,0,1)

  -- Highlight for name
  healthbar.NameHighlight = healthbar:CreateTexture(nil, "ARTWORK") -- required for Headline View
  healthbar.NameHighlight:SetTexture(NAME_STYLE_TEXTURE)
  healthbar.NameHighlight:SetAllPoints(tp_frame.visual.name)
  healthbar.NameHighlight:SetBlendMode("ADD")

  healthbar.Highlight:Hide() -- HighlightTexture is shown/hidden together with Highlight
  healthbar.NameHighlight:Hide()
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function Element.UnitAdded(tp_frame)
end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
function Element.UnitRemoved(tp_frame)
end

function Element.UpdateStyle(tp_frame, style)
--  local element_frame = tp_frame.visual.MouseoverHightlight
--
--  if not style.highlight.show then
--    -- Nameplate Style: empty or mouseover highlight disabled
--    element_frame:Hide()
--  elseif tp_frame.unit.isTarget then
--    -- .Highlight and .NameHighlight are alwways hidden by default, don't show them on targeted units
--    -- but show the frame so that the OnUpdateHighlight function is called when the mouse curser leaves the
--    -- unit
--    element_frame.Highlight:Hide()
--    element_frame.NameHighlight:Hide()
--  elseif style.healthbar.show then
--    -- Nameplate Style: Healthbar
--    element_frame.Highlight:Show()
--    element_frame.NameHighlight:Hide()
--  else
--    -- Nameplate Style: Name
--    element_frame.Highlight:Hide()
--    element_frame.NameHighlight:Show()
--  end
end

function Element.UpdateSettings()
end

function Element.UPDATE_MOUSEOVER_UNIT()
  if UnitIsUnit("mouseover", "player") then return end -- TODO: target as well?

  local plate = GetNamePlateForUnit("mouseover")

  -- check for Active to prevent accessing the personal resource bar
  if not plate or not plate.TPFrame.Active then return end

  local tp_frame = plate.TPFrame

  tp_frame.unit.isMouseover = true

  --PublishEvent("MouseoverOnEnter", tp_frame)
  --UpdateIndicator_CustomScale(tp_frame, tp_frame.unit)
  --UpdatePlate_Transparency(tp_frame, tp_frame.unit)


  print ("UPDATE_MOUSEOVER_UNIT: Entering => ", tp_frame.unit.unitid)

  local healthbar = tp_frame.visual.healthbar
  local style = tp_frame.style
  if style.highlight.show then
    if tp_frame.unit.isTarget then
      -- .Highlight and .NameHighlight are alwways hidden by default, don't show them on targeted units
      -- but show the frame so that the OnUpdateHighlight function is called when the mouse curser leaves the
      -- unit
      healthbar.Highlight:Hide()
      healthbar.NameHighlight:Hide()
    elseif style.healthbar.show then
      -- Nameplate Style: Healthbar
      healthbar.Highlight:Show()
      healthbar.NameHighlight:Hide()
    else
      -- Nameplate Style: Name
      healthbar.Highlight:Hide()
      healthbar.NameHighlight:Show()
    end

    CurrentMouseoverUnitID = tp_frame.unit.unitid
    CurrentMouseoverPlate = tp_frame
    MouseoverHighlightFrame:Show()
  else
    -- Nameplate Style: empty or mouseover highlight disabled
    HideMouseoverHighlightFrame()
  end
end

Addon.EventService.Subscribe(Element, "UPDATE_MOUSEOVER_UNIT", Element.UPDATE_MOUSEOVER_UNIT)
--Addon.EventService.Subscribe(Element, "MouseoverOnEnter", Element.UPDATE_MOUSEOVER_UNIT)
