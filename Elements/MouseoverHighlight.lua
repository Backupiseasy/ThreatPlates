---------------------------------------------------------------------------------------------------
-- Element: Moueover Highlight
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local UnitIsUnit = UnitIsUnit

-- ThreatPlates APIs
local BackdropTemplate = Addon.BackdropTemplate
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

local OFFSET_HIGHLIGHT = 1
local NAME_STYLE_TEXTURE = Addon.PATH_ARTWORK .. "Highlight"
local HEALTHBAR_STYLE_TEXTURE = Addon.PATH_ARTWORK .. "TP_HealthBar_Highlight"
local BACKDROP = {
  edgeFile = Addon.PATH_ARTWORK .. "TP_WhiteSquare",
  edgeSize = 1,
}

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local TargetHighlightEnabledForStyle = {}

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------
local Element = Addon.Elements.NewElement("MouseoverHighlight")

---------------------------------------------------------------------------------------------------
-- Core element code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_CREATED
function Element.PlateCreated(tp_frame)
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

  healthbar.MouseoverHighlight = healthbar.Highlight
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

  TargetHighlightEnabledForStyle["NameOnly"] = db.targetWidget.ShowInHeadlineView
  TargetHighlightEnabledForStyle["NameOnly-Unique"] = db.targetWidget.ShowInHeadlineView
  TargetHighlightEnabledForStyle["dps"] = db.targetWidget.ON
  TargetHighlightEnabledForStyle["tank"] = db.targetWidget.ON
  TargetHighlightEnabledForStyle["normal"] = db.targetWidget.ON
  TargetHighlightEnabledForStyle["totem"] = db.targetWidget.ON
  TargetHighlightEnabledForStyle["unique"] = db.targetWidget.ON
end

-- Registered in Nameplate.lua
local function MouseoverOnEnter(tp_frame)  
  local unit = tp_frame.unit
  tp_frame.visual.Healthbar.MouseoverHighlight:SetShown(tp_frame.style.highlight.show and TargetHighlightEnabledForStyle[unit.style] and not unit.isTarget)
end

local function MouseoverOnLeave(tp_frame)
  tp_frame.visual.Healthbar.MouseoverHighlight:Hide()
end

local function TargetLost(tp_frame)
  --local plate = Addon.PlatesByUnit["mouseover"]
  --if plate and plate = tp_frame.Parent then
  if UnitIsUnit("mouseover", tp_frame.unit.unitid) then
    MouseoverOnEnter(tp_frame)
  end
end

SubscribeEvent(Element, "MouseoverOnEnter", MouseoverOnEnter)
SubscribeEvent(Element, "MouseoverOnLeave", MouseoverOnLeave)
SubscribeEvent(Element, "TargetGained", MouseoverOnLeave)
SubscribeEvent(Element, "TargetLost", TargetLost)
