---------------------------------------------------------------------------------------------------
-- Totem Icon Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = Addon.Widgets:NewWidget("TotemIcon")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local PATH = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\TotemIconWidget\\"

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
	-- Required Widget Code
	local widget_frame = CreateFrame("Frame", nil, tp_frame)
	widget_frame:Hide()

	-- Custom Code
	--------------------------------------
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
  widget_frame.Icon = widget_frame:CreateTexture(nil, "OVERLAY")
  widget_frame.Icon:SetAllPoints(widget_frame)
	--------------------------------------
	-- End Custom Code

	return widget_frame
end

function Widget:IsEnabled()
	return TidyPlatesThreat.db.profile.totemWidget.ON
end

--function Widget:UNIT_NAME_UPDATE()
--end
--
--function Widget:OnEnable()
--  self:RegisterEvent("UNIT_NAME_UPDATE")
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

  local db = TidyPlatesThreat.db.profile.totemWidget

  -- not used: db[totem_id].ShowIcon
  widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
  widget_frame:SetSize(db.scale, db.scale)
  widget_frame.Icon:SetTexture(PATH .. totem_settings.Style .. "\\" .. totem_settings.ID)

  widget_frame:Show()
end