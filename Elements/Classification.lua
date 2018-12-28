---------------------------------------------------------------------------------------------------
-- Element: Unit Classification
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local CreateFrame = CreateFrame

-- ThreatPlates APIs
local ThreatPlates = Addon.ThreatPlates
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish

local ELITE_BACKDROP = {
  TP_EliteBorder_Default = {
    edgeFile = ThreatPlates.Art .. "TP_WhiteSquare",
    edgeSize = 1.5,
    offset = 1.8,
  },
  TP_EliteBorder_Thin = {
    edgeFile = ThreatPlates.Art .. "TP_WhiteSquare",
    edgeSize = 0.9,
    offset = 1.1,
  }
}

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------
local Element = Addon.Elements.NewElement("Classification")

---------------------------------------------------------------------------------------------------
-- Core element code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
  local textframe = tp_frame.visual.textframe

  local skull_icon = textframe:CreateTexture(nil, "ARTWORK", 2)
  local elite_icon = textframe:CreateTexture(nil, "ARTWORK", 1)
  --local rareicon = textframe:CreateTexture(nil, "ARTWORK", 1)

  local healthbar = tp_frame.visual.Healthbar
  local elite_border = CreateFrame("Frame", nil, healthbar)
  elite_border:SetFrameLevel(healthbar:GetFrameLevel() + 1)

  tp_frame.visual.SkullIcon = skull_icon
  tp_frame.visual.EliteIcon = elite_icon
  tp_frame.visual.EliteBorder = elite_border
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function Element.UnitAdded(tp_frame)
  local unit, visual = tp_frame.unit, tp_frame.visual

  if unit.isRare then
    visual.EliteIcon:SetVertexColor(0.8, 0.8, 0.8)
    visual.EliteBorder:SetBackdropBorderColor(0.8, 0.8, 0.8)
  elseif unit.isElite then
    visual.EliteIcon:SetVertexColor(1, 0.85, 0)
    visual.EliteBorder:SetBackdropBorderColor(1, 0.85, 0, 1)
  end
end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.UnitRemoved(tp_frame)
--end

---- Called in processing event: UpdateStyle in Nameplate.lua
function Element.UpdateStyle(tp_frame, style)
  local unit, visual = tp_frame.unit, tp_frame.visual

  local skull_icon, skull_style = visual.SkullIcon, style.skullicon
  if unit.isBoss and skull_style.show then
    skull_icon:SetTexture(skull_style.texture)
    skull_icon:SetSize(skull_style.width, skull_style.height)
    skull_icon:ClearAllPoints()
    skull_icon:SetPoint(skull_style.anchor, tp_frame, skull_style.anchor, skull_style.x, skull_style.y)
    skull_icon:Show()
  else
    skull_icon:Hide()
  end

  local elite_icon, elite_style = visual.EliteIcon, style.eliteicon
  if (unit.isRare or unit.isElite) and elite_style.show then
    elite_icon:SetTexture(elite_style.texture)
    elite_icon:SetSize(elite_style.width, elite_style.height)
    elite_icon:ClearAllPoints()
    elite_icon:SetPoint(elite_style.anchor, tp_frame, elite_style.anchor, elite_style.x, elite_style.y)
    elite_icon:Show()
  else
    elite_icon:Hide()
  end

  local elite_border, border_style = visual.EliteBorder, style.eliteborder
  if (unit.isRare or unit.isElite) and border_style.show then
    local backdrop = ELITE_BACKDROP[border_style.texture]
    local healthbar = visual.Healthbar
    elite_border:SetPoint("TOPLEFT", healthbar, "TOPLEFT", - backdrop.offset, backdrop.offset)
    elite_border:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMRIGHT", backdrop.offset, - backdrop.offset)
    elite_border:SetBackdrop({
      edgeFile = backdrop.edgeFile,
      edgeSize = backdrop.edgeSize,
      --insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    elite_border:Show()
  else
    elite_border:Hide()
  end
end

--function Element.UpdateSettings()
--end

--SubscribeEvent(Element, "PLAYER_TARGET_CHANGED", Element.UPDATE_MOUSEOVER_UNIT)
