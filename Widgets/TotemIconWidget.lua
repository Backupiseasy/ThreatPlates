---------------------------------------------------------------------------------------------------
-- Totem Icon Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Module = Addon:NewModule("TotemIcon")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local TOTEMS = Addon.TOTEMS
local PATH = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\TotemIconWidget\\"

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
	return TidyPlatesThreat.db.profile.totemWidget.ON
end

--function Module:UNIT_NAME_UPDATE()
--end
--
--function Module:OnEnable()
--  self:RegisterEvent("UNIT_NAME_UPDATE")
--end

function Module:EnabledForStyle(style, unit)
	return (style == "totem" or style == "etotem")
end

function Module:OnUnitAdded(widget_frame, unit)
  local totem_id = TOTEMS[unit.name]

  if not totem_id then
    widget_frame:Hide()
    return
  end

  local db = TidyPlatesThreat.db.profile.totemWidget

  -- not used: db[totem_id].ShowIcon
  widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
  widget_frame:SetSize(db.scale, db.scale)
  widget_frame.Icon:SetTexture(PATH .. TidyPlatesThreat.db.profile.totemSettings[totem_id].Style .. "\\" .. totem_id)

  widget_frame:Show()
end