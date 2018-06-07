---------------------------------------------------------------------------------------------------
-- Unique Icon Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Module = Addon:NewModule("UniqueIcon")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

---------------------------------------------------------------------------------------------------
-- Module functions for creation and update
---------------------------------------------------------------------------------------------------
function Module:Create(tp_frame)
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

function Module:IsEnabled()
  return TidyPlatesThreat.db.profile.uniqueWidget.ON
end

--function Module:UNIT_NAME_UPDATE()
--end
--
--function Module:OnEnable()
--  self:RegisterEvent("UNIT_NAME_UPDATE")
--end

function Module:EnabledForStyle(style, unit)
  return (style == "unique" or style == "NameOnly-Unique" or style == "etotem")
end

function Module:OnUnitAdded(widget_frame, unit)
  local db = TidyPlatesThreat.db.profile

	--local unique_setting = db.uniqueSettings.map[unit.name]
  local unique_setting = unit.CustomPlateSettings
	if not unique_setting or not unique_setting.showIcon then
		widget_frame:Hide()
		return
	end

	db = db.uniqueWidget

	-- Updates based on settings / unit style
  if unit.style == "NameOnly-Unique" then
    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x_hv, db.y_hv)
  else
    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
  end

	-- Updates based on settings
	widget_frame:SetSize(db.scale, db.scale)
	widget_frame.Icon:SetTexture(unique_setting.icon)

	widget_frame:Show()
end