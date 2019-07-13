---------------------------------------------------------------------------------------------------
-- Unique Icon Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = Addon.Widgets:NewWidget("UniqueIcon")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local type = type

-- WoW APIs
local CreateFrame = CreateFrame

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

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
  return TidyPlatesThreat.db.profile.uniqueWidget.ON
end

--function Widget:UNIT_NAME_UPDATE()
--end
--
--function Widget:OnEnable()
--  self:RegisterEvent("UNIT_NAME_UPDATE")
--end

function Widget:EnabledForStyle(style, unit)
  return (style == "unique" or style == "NameOnly-Unique" or style == "etotem")
end

function Widget:OnUnitAdded(widget_frame, unit)
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

  local icon_texture = unique_setting.icon

  if type(icon_texture) == "string" and icon_texture:sub(-4) == ".blp" then
	  widget_frame.Icon:SetTexture("Interface\\Icons\\" .. unique_setting.icon)
  else
    widget_frame.Icon:SetTexture(icon_texture)
  end

	widget_frame:Show()
end