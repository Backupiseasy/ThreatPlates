local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local CreateFrame = CreateFrame

-- WoW APIs
local UnitExists, UnitIsUnit = UnitExists, UnitIsUnit

-- ThreatPlates APIs

local OFFSET_HIGHLIGHT = 1
local ART_PATH = ThreatPlates.Art

---------------------------------------------------------------------------------------------------
-- Module code
---------------------------------------------------------------------------------------------------

local function OnUpdateHighlight(tp_frame)
  --if not (UnitExists("mouseover") and UnitIsUnit("mouseover", tp_frame.unit.unitid)) then
  if not UnitIsUnit("mouseover", tp_frame.unit.unitid) then
    tp_frame.unit.isMouseover = false
    -- More general solution, better would be to implement a callback and just update everything
    -- on the old mouseover nameplate that depends on mouseover
    --Addon:UpdateNameplate(tp_frame, "Mouseover")
    Addon.PlatesByUnit[tp_frame.unit.unitid].UpdateMe = true
    tp_frame.visual.Highlight:Hide()
  end
end

function Addon:Module_Mouseover_Update(tp_frame)
  local frame = tp_frame.visual.Highlight
  if not tp_frame.unit.isTarget and tp_frame.style.highlight.show then
    if tp_frame.style.healthbar.show then -- healthbar view
      frame.Highlight:Show()
    else
      frame.NameHighlight:Show()
    end
    frame:Show()
  else
    frame:Hide()
  end
end

function Addon:Module_Mouseover_Configure(frame, style_highlight)
  frame.NameHighlight:SetTexture(style_highlight.texture)
end

function Addon:Module_Mouseover_Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetFrameLevel(parent:GetFrameLevel() + 1)

  -- Highlight for healthbar
  local healthbar = parent.visual.healthbar
  frame.Highlight = CreateFrame("Frame", nil, healthbar)
  frame.Highlight:SetPoint("TOPLEFT", healthbar, "TOPLEFT", - OFFSET_HIGHLIGHT, OFFSET_HIGHLIGHT)
  frame.Highlight:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMRIGHT", OFFSET_HIGHLIGHT, - OFFSET_HIGHLIGHT)
  frame.Highlight:SetBackdrop({
    edgeFile = ART_PATH .. "TP_WhiteSquare",
    edgeSize = 1,
  })
  frame.Highlight:SetBackdropBorderColor(1, 1, 1, 1)

  frame.HighlightTexture = frame.Highlight:CreateTexture(nil, "ARTWORK", 0)
  frame.HighlightTexture:SetTexture(ART_PATH .. "TP_HealthBar_Highlight")
  frame.HighlightTexture:SetBlendMode("ADD")
  frame.HighlightTexture:SetAllPoints(healthbar)
  --frame.HighlightTexture:SetVertexColor(1,0,0,1)

  -- Highlight for name
  frame.NameHighlight = healthbar:CreateTexture(nil, "ARTWORK") -- required for Headline View
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