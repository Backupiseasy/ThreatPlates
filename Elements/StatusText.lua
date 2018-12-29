---------------------------------------------------------------------------------------------------
-- Element: Status Text
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
local Element = Addon.Elements.NewElement("StatusText")

---------------------------------------------------------------------------------------------------
-- Core element code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
  local status_text = tp_frame.visual.textframe:CreateFontString(nil, "ARTWORK", -1)

  tp_frame.visual.StatusText = status_text
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function Element.UnitAdded(tp_frame)
  local status_text = tp_frame.visual.StatusText

  local text, r, g, b, a = Addon:SetCustomText(tp_frame.unit)
  status_text:SetText(text or "")
  status_text:SetTextColor(r or 1, g or 1, b or 1, a or 1)
end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.UnitRemoved(tp_frame)
--end

---- Called in processing event: UpdateStyle in Nameplate.lua
function Element.UpdateStyle(tp_frame, style)
  local status_text = tp_frame.visual.StatusText
  local style = style.customtext

  -- At least font must be set as otherwise it results in a Lua error when UnitAdded with SetText is called
  status_text:SetFont(style.typeface, style.size, style.flags)

  if style.show then
    SetFontJustify(status_text, style.align, style.vertical)

    if style.shadow then
      status_text:SetShadowColor(0,0,0, 1)
      status_text:SetShadowOffset(1, -1)
    else
      status_text:SetShadowColor(0,0,0,0)
    end

    status_text:SetSize(style.width, style.height)
    status_text:ClearAllPoints()
    status_text:SetPoint(style.anchor, tp_frame, style.anchor, style.x, style.y)

    status_text:Show()
  else
    status_text:Hide()
    end
end

--function Element.UpdateSettings()
--end

local function StatusTextUpdateByUnit(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    Element.UnitAdded(tp_frame)
  end
end

SubscribeEvent(Element, "UNIT_NAME_UPDATE", StatusTextUpdateByUnit)
SubscribeEvent(Element, "UNIT_LEVEL", StatusTextUpdateByUnit)
SubscribeEvent(Element, "UNIT_HEALTH_FREQUENT", StatusTextUpdateByUnit)
-- TODO: Subscribe/unsubscribe to this event based on settings
SubscribeEvent(Element, "ThreatUpdate", Element.UnitAdded)

-- Missing: Updates to Guild information (like entering new guild)