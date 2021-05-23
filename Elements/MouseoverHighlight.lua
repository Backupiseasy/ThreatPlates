local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local UnitExists, UnitIsUnit = UnitExists, UnitIsUnit

-- ThreatPlates APIs
local BackdropTemplate = Addon.BackdropTemplate

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

local OFFSET_HIGHLIGHT = 1
local ART_PATH = ThreatPlates.Art

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local TargetHighlightEnabledForStyle = {
  etotem = false,
  empty = false
}

------------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------

local function OnUpdateHighlight(tp_frame)
  --if not (UnitExists("mouseover") and UnitIsUnit("mouseover", tp_frame.unit.unitid)) then
  if not UnitIsUnit("mouseover", tp_frame.unit.unitid) then
    tp_frame.unit.isMouseover = false
    tp_frame.visual.Highlight:Hide()

    Addon.PlatesByUnit[tp_frame.unit.unitid].UpdateMe = true
    -- More general solution, better would be to implement a callback and just update everything
    -- on the old mouseover nameplate that depends on mouseover
    --Addon:UpdateIndicatorScaleAndAlpha(tp_frame)
  end
end

function Addon:Element_Mouseover_Update(tp_frame)
  -- Don't show highlight for target units or if it's disabled
  if (tp_frame.unit.isTarget and TargetHighlightEnabledForStyle[tp_frame.unit.style]) or not tp_frame.style.highlight.show then
    -- frame.Highlight and frame.Highlight are always hidden by default, don't show them on targeted units
    -- but show the frame so that the OnUpdateHighlight function is called when the mouse curser leaves the
    -- unit
    tp_frame.visual.Highlight:Show()
    return
  end

  local frame = tp_frame.visual.Highlight
  if tp_frame.style.healthbar.show then
    frame.Highlight:Show()
  else
    frame.NameHighlight:Show()
  end

  frame:Show()
end

-- Update settings that are global for all nameplates
function Addon:Element_Mouseover_Configure(frame, style_highlight)
  -- TODO: Move this to Create as the texture is not changed in Threat Plates
  frame.NameHighlight:SetTexture(style_highlight.texture)
end

function Addon.Element_Mouseover_UpdateSettings()
  local db = Addon.db.profile
  TargetHighlightEnabledForStyle["NameOnly"] = db.HeadlineView.ShowTargetHighlight
  TargetHighlightEnabledForStyle["NameOnly-Unique"] = db.HeadlineView.ShowTargetHighlight
  TargetHighlightEnabledForStyle["dps"] = db.targetWidget.ON
  TargetHighlightEnabledForStyle["tank"] = db.targetWidget.ON
  TargetHighlightEnabledForStyle["normal"] = db.targetWidget.ON
  TargetHighlightEnabledForStyle["totem"] = db.targetWidget.ON
  TargetHighlightEnabledForStyle["unique"] = db.targetWidget.ON
end

function Addon:Element_Mouseover_Create(parent)
  local frame = _G.CreateFrame("Frame", nil, parent)

  local healthbar = parent.visual.healthbar
  local frame_level = healthbar:GetFrameLevel()
  frame:SetFrameLevel(frame_level)

  -- Highlight for healthbar
  frame.Highlight = _G.CreateFrame("Frame", nil, healthbar, BackdropTemplate)
  frame.Highlight:SetFrameLevel(frame_level)
  frame.Highlight:SetPoint("TOPLEFT", healthbar, "TOPLEFT", - OFFSET_HIGHLIGHT, OFFSET_HIGHLIGHT)
  frame.Highlight:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMRIGHT", OFFSET_HIGHLIGHT, - OFFSET_HIGHLIGHT)
  frame.Highlight:SetBackdrop({
    edgeFile = ART_PATH .. "TP_WhiteSquare",
    edgeSize = 1,
  })
  frame.Highlight:SetBackdropBorderColor(1, 1, 1, 1)

  frame.HighlightTexture = frame.Highlight:CreateTexture(nil, "ARTWORK", nil, 0)
  frame.HighlightTexture:SetTexture(ART_PATH .. "TP_HealthBar_Highlight")
  frame.HighlightTexture:SetBlendMode("ADD")
  frame.HighlightTexture:SetAllPoints(healthbar)
  --frame.HighlightTexture:SetVertexColor(1, 0, 0,1) -- Color it for testing purposes

  -- Highlight for name
  frame.NameHighlight = frame:CreateTexture(nil, "ARTWORK") -- required for Headline View
  frame.NameHighlight:SetAllPoints(parent.visual.name)
  frame.NameHighlight:SetBlendMode("ADD")

  frame.Highlight:Hide() -- HighlightTexture is shown/hidden together with Highlight
  frame.NameHighlight:Hide()
  frame:Hide()

  frame:SetScript("OnUpdate", function() OnUpdateHighlight(parent) end)
  frame:HookScript("OnHide", function()
    frame.Highlight:Hide()
    frame.NameHighlight:Hide()
  end)

  return frame
end