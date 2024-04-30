---------------------------------------------------------------------------------------------------
-- Element: Moueover Highlight
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local UnitIsUnit = UnitIsUnit

-- ThreatPlates APIs
local BackdropTemplate = Addon.BackdropTemplate
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

local OFFSET_HIGHLIGHT = 1
local ART_PATH = ThreatPlates.Art
local NAME_STYLE_TEXTURE = ART_PATH .. "Highlight"
local HEALTHBAR_STYLE_TEXTURE = ART_PATH .. "TP_HealthBar_Highlight"
local BACKDROP = {
  edgeFile = ART_PATH .. "TP_WhiteSquare",
  edgeSize = 1,
}

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local TargetHighlightEnabledForStyle = {
  etotem = false,
  empty = false
}

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local MouseoverHighlightFrame = _G.CreateFrame("Frame", nil)
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
function Element.Create(tp_frame)
  -- Highlight for healthbar

  local healthbar = tp_frame.visual.Healthbar
  healthbar.Highlight = _G.CreateFrame("Frame", nil, healthbar, BackdropTemplate)
  healthbar.Highlight:SetFrameLevel(healthbar:GetFrameLevel())
  healthbar.Highlight:SetPoint("TOPLEFT", healthbar, "TOPLEFT", - OFFSET_HIGHLIGHT, OFFSET_HIGHLIGHT)
  healthbar.Highlight:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMRIGHT", OFFSET_HIGHLIGHT, - OFFSET_HIGHLIGHT)
  healthbar.Highlight:SetBackdrop(BACKDROP)
  healthbar.Highlight:SetBackdropBorderColor(1, 1, 1, 1)

  healthbar.HighlightTexture = healthbar.Highlight:CreateTexture(nil, "ARTWORK", nil, 0)
  healthbar.HighlightTexture:SetTexture(HEALTHBAR_STYLE_TEXTURE)
  healthbar.HighlightTexture:SetBlendMode("ADD")
  healthbar.HighlightTexture:SetAllPoints(healthbar)
  --frame.HighlightTexture:SetVertexColor(1, 0, 0,1) -- Color it for testing purposes

  -- Highlight for name
  healthbar.NameHighlight = tp_frame:CreateTexture(nil, "ARTWORK") -- required for Headline View
  healthbar.NameHighlight:SetTexture(NAME_STYLE_TEXTURE)
  healthbar.NameHighlight:SetBlendMode("ADD")
  healthbar.NameHighlight:SetAllPoints(tp_frame.visual.NameText)

  healthbar.Highlight:Hide() -- HighlightTexture is shown/hidden together with Highlight
  healthbar.NameHighlight:Hide()
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
--function Element.PlateUnitAdded(tp_frame)
--end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.PlateUnitRemoved(tp_frame)
--end

-- Called in processing event: UpdateStyle in Nameplate.lua
function Element.UpdateStyle(tp_frame, style, plate_style)
  local healthbar = tp_frame.visual.Healthbar

  if plate_style == "None" then
    healthbar.Highlight:Hide()
    healthbar.NameHighlight:Hide()
    -- Also set MouseoverHighlight, as it might be accessed in UPDATE_MOUSEOVER_UNIT
    healthbar.MouseoverHighlight = healthbar.Highlight
  else
    if style.healthbar.show then
      healthbar.MouseoverHighlight = healthbar.Highlight
      healthbar.NameHighlight:Hide()
    else
      healthbar.MouseoverHighlight = healthbar.NameHighlight
      healthbar.Highlight:Hide()
    end
  
    local unit = tp_frame.unit
    healthbar.MouseoverHighlight:SetShown(unit.isMouseover and style.highlight.show and TargetHighlightEnabledForStyle[unit.style] and not unit.isTarget)  
  end
end

function Element.UpdateSettings()
  local db = Addon.db.profile

  TargetHighlightEnabledForStyle["NameOnly"] = db.HeadlineView.ShowTargetHighlight
  TargetHighlightEnabledForStyle["NameOnly-Unique"] = db.HeadlineView.ShowTargetHighlight
  TargetHighlightEnabledForStyle["dps"] = db.targetWidget.ON
  TargetHighlightEnabledForStyle["tank"] = db.targetWidget.ON
  TargetHighlightEnabledForStyle["normal"] = db.targetWidget.ON
  TargetHighlightEnabledForStyle["totem"] = db.targetWidget.ON
  TargetHighlightEnabledForStyle["unique"] = db.targetWidget.ON
end

-- Registered in Nameplate.lua
function Element.UPDATE_MOUSEOVER_UNIT()
  if UnitIsUnit("mouseover", "player") then return end -- TODO: target as well?

  local plate = GetNamePlateForUnit("mouseover")

  -- Check for TPFrame.Active to prevent accessing the personal resource bar
  if not plate or not plate.TPFrame.Active then return end

  HideMouseoverHighlightFrame()

  local tp_frame = plate.TPFrame
  local unit = tp_frame.unit
  unit.isMouseover = true
  tp_frame.visual.Healthbar.MouseoverHighlight:SetShown(tp_frame.style.highlight.show and TargetHighlightEnabledForStyle[unit.style] and not unit.isTarget)

  CurrentMouseoverUnitID = tp_frame.unit.unitid
  CurrentMouseoverPlate = tp_frame
  MouseoverHighlightFrame:Show()

  PublishEvent("MouseoverOnEnter", tp_frame)
end

SubscribeEvent(Element, "PLAYER_TARGET_CHANGED", Element.UPDATE_MOUSEOVER_UNIT)
--SubscribeEvent(Element, "PLAYER_FOCUS_CHANGED", Element.UPDATE_MOUSEOVER_UNIT)
