---------------------------------------------------------------------------------------------------
-- Totem Icon Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = Addon.Widgets:NewWidget("TotemIcon")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local tostring = tostring

-- ThreatPlates APIs

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
	-- Required Widget Code
	local widget_frame = _G.CreateFrame("Frame", nil, tp_frame)
	widget_frame:Hide()

	-- Custom Code
	--------------------------------------
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
  widget_frame.Icon = widget_frame:CreateTexture(nil, "OVERLAY")
  widget_frame.Border = widget_frame:CreateTexture(nil, "OVERLAY", nil, 1)

  widget_frame.Icon:SetAllPoints(widget_frame)
  widget_frame.Border:SetAllPoints(widget_frame)
	--------------------------------------
	-- End Custom Code

	return widget_frame
end

function Widget:IsEnabled()
	return Addon.db.profile.totemWidget.ON
end

function Widget:UNIT_NAME_UPDATE(unitid)
  local widget_frame = self:GetWidgetFrameForUnit(unitid)
  if widget_frame then
    self:OnUnitAdded(widget_frame, unitid)
  end
end

function Widget:OnEnable()
  
  self:SubscribeEvent("UNIT_NAME_UPDATE")
end

function Widget:EnabledForStyle(style, unit)
	return (style == "totem" or style == "etotem") and unit.TP_DetailedUnitType == "Totem"
end

function Widget:OnUnitAdded(widget_frame, unit)
  local totem_settings = unit.TotemSettings
  if not totem_settings then
    widget_frame:Hide()
    return
  end

  local db = Addon.db.profile.totemWidget

  -- not used: db[totem_id].ShowIcon
  widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
  widget_frame:SetSize(db.scale, db.scale)
  Addon:SetIconTexture(widget_frame.Icon, "Totem." .. tostring(totem_settings.SpellID), unit.unitid)

  if totem_settings.Style == "special" then
    widget_frame.Border:SetTexture("Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\TotemIconWidget\\SpecialTotemBorder")
  else
    widget_frame.Border:SetTexture()
  end

  widget_frame:Show()
end

function Widget:PrintDebug()
  for icon_id, icon in pairs (getmetatable(Addon.IconTextures).__index) do
    if icon_id:sub(1, 6) == "Totem." then
      Addon.Logging.Debug("    ", icon_id .. ":", icon)
    end
  end 
end