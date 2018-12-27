---------------------------------------------------------------------------------------------------
-- Element: Unit Level
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local UnitEffectiveLevel, GetCreatureDifficultyColor = UnitEffectiveLevel, GetCreatureDifficultyColor

-- ThreatPlates APIs
local PlatesByUnit = Addon.PlatesByUnit
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------

local Element = Addon.Elements.NewElement("Level")


-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
  local leveltext = tp_frame.visual.textframe:CreateFontString(nil, "ARTWORK", -2)

  tp_frame.visual.LevelText = leveltext
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function Element.UnitData(tp_frame)
  local unit = tp_frame.unit

  local unit_level = UnitEffectiveLevel(unit.unitid)
  local level_color = GetCreatureDifficultyColor(unit_level)

  unit.level = unit_level
  unit.levelcolorRed, unit.levelcolorGreen, unit.levelcolorBlue = level_color.r, level_color.g, level_color.b
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function Element.UnitAdded(tp_frame)
  local leveltext = tp_frame.visual.LevelText
  local unit = tp_frame.unit

  local unit_level = unit.level
  if unit_level < 0 then
    leveltext:SetText("")
  else
    leveltext:SetText(unit_level)
  end

  leveltext:SetTextColor(unit.levelcolorRed, unit.levelcolorGreen, unit.levelcolorBlue)
end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.UnitRemoved(tp_frame)
--  tp_frame.visual.ThreatGlow:Hide() -- done in UpdateStyle
--end

local function SetObjectJustify(object, horz, vert)
  local align_horz, align_vert = object:GetJustifyH(), object:GetJustifyV()
  if align_horz ~= horz or align_vert ~= vert then
    object:SetJustifyH(horz)
    object:SetJustifyV(vert)

    -- Set text to nil to enforce text string update, otherwise updates to justification will not take effect
    local text = object:GetText()
    object:SetText(nil)
    object:SetText(text)
  end
end

function Element.UpdateStyle(tp_frame, style)
  local leveltext = tp_frame.visual.LevelText
  local style = style.level

  -- At least font must be set as otherwise it results in a Lua error when UnitAdded with SetText is called
  leveltext:SetFont(style.typeface, style.size, style.flags)

  if style.show then
    SetObjectJustify(leveltext, style.align, style.vertical)

    if style.shadow then
      leveltext:SetShadowColor(0,0,0, 1)
      leveltext:SetShadowOffset(1, -1)
    end

    leveltext:SetSize(style.width, style.height)
    leveltext:ClearAllPoints()
    leveltext:SetPoint(style.anchor, tp_frame, style.anchor, style.x, style.y)

    leveltext:Show()
  else
    leveltext:Hide()
  end
end

function Element.UNIT_LEVEL(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    Element.UnitData(tp_frame)
    Element.UnitAdded(tp_frame)
  end
end

