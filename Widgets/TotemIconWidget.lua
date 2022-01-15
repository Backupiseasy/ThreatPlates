---------------------------------------------------------------------------------------------------
-- Totem Icon Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = Addon.Widgets:NewWidget("TotemIcon")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs

-- ThreatPlates APIs

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

local PATH = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\TotemIconWidget\\"

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

--function Widget:UNIT_NAME_UPDATE()
--end
--
--function Widget:OnEnable()
--  self:SubscribeEvent("UNIT_NAME_UPDATE")
--end

function Widget:EnabledForStyle(style, unit)
	return (style == "totem" or style == "etotem")
end

function Widget:OnUnitAdded(widget_frame, unit)
  --local totem_id = TOTEMS[unit.name]

  local totem_settings = unit.TotemSettings
  if not totem_settings then
    widget_frame:Hide()
    return
  end

  local db = Addon.db.profile.totemWidget

  -- not used: db[totem_id].ShowIcon
  widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
  widget_frame:SetSize(db.scale, db.scale)

  local _, _, totem_icon = GetSpellInfo(totem_settings.SpellID)

  --widget_frame.Icon:SetTexCoord(0, 1, 0, 1)
  widget_frame.Icon:SetTexCoord(.08, .92, .08, .92)
  widget_frame.Icon:SetTexture(totem_icon)
  if totem_settings.Style == "special" then
   widget_frame.Border:SetTexture(PATH .. "SpecialTotemBorder")
  end

  widget_frame:Show()
end