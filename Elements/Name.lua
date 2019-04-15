---------------------------------------------------------------------------------------------------
-- Element: Name
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs

-- ThreatPlates APIs
local PlatesByUnit = Addon.PlatesByUnit
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish
local SetFontJustify = Addon.Font.SetJustify

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------
local Element = Addon.Elements.NewElement("Name")

---------------------------------------------------------------------------------------------------
-- Core element code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
  local name_text = tp_frame.visual.textframe:CreateFontString(nil, "ARTWORK", 0)

  tp_frame.visual.NameText = name_text
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function Element.UnitAdded(tp_frame)
  local name_text = tp_frame.visual.NameText
  local unit = tp_frame.unit

  name_text:SetText(unit.name)
end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.UnitRemoved(tp_frame)
--end

---- Called in processing event: UpdateStyle in Nameplate.lua
function Element.UpdateStyle(tp_frame, style, plate_style)
  local name_text = tp_frame.visual.NameText
  local name_style = style.name

  -- At least font must be set as otherwise it results in a Lua error when UnitAdded with SetText is called
  name_text:SetFont(name_style.typeface, name_style.size, name_style.flags)

  if plate_style == "NONE" or not name_style.show then
    name_text:Hide()
    return
  end

  SetFontJustify(name_text, name_style.align, name_style.vertical)

  if name_style.shadow then
    name_text:SetShadowColor(0,0,0, 1)
    name_text:SetShadowOffset(1, -1)
  else
    name_text:SetShadowColor(0,0,0,0)
  end

  name_text:SetSize(name_style.width, name_style.height)
  name_text:ClearAllPoints()
  name_text:SetPoint(name_style.anchor, tp_frame, name_style.anchor, name_style.x, name_style.y)

  name_text:Show()
end

--function Element.UpdateSettings()
--end

local function UNIT_NAME_UPDATE(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    tp_frame.visual.NameText:SetText(tp_frame.unit.name)
  end
end

SubscribeEvent(Element, "UNIT_NAME_UPDATE", UNIT_NAME_UPDATE)