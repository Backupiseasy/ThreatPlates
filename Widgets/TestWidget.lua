---------------------------------------------------------------------------------------------------
-- Test Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewWidget("Test")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local WidgetFrame

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

function Widget:IsEnabled()
  return Addon.db.profile.TestWidget.ON
end

function Widget:EnabledForStyle(style, unit)
  return not (style == "NameOnly" or style == "NameOnly-Unique" or style == "etotem")
end

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
-- 	for _, widget in pairs(WidgetList) do
-- 		widget:Hide()
-- 	end
-- 	WidgetList = {}
-- end
-- ThreatPlatesWidgets.ClearAllTargetArtWidgets = ClearAllWidgets

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

function Widget:OnUnitAdded(widget_frame, unit)
  widget_frame:Show()

  local db = Addon.db.profile.TestWidget

  widget_frame:ClearAllPoints()
  widget_frame:SetPoint("CENTER", widget_frame:GetParent(), "CENTER", 0, 50)
  widget_frame:SetSize(db.BarWidth, db.BarHeight)
  widget_frame:SetStatusBarTexture(ThreatPlates.Media:Fetch('statusbar', db.BarTexture))
  widget_frame:SetScale(db.Scale)
  widget_frame:SetMinMaxValues(0, 100)
  widget_frame:SetValue(50)
  widget_frame:SetStatusBarColor(0, 1, 0)

  widget_frame.Border:ClearAllPoints()
  widget_frame.Border:SetPoint("TOPLEFT", widget_frame, "TOPLEFT", -db.Offset, db.Offset)
  widget_frame.Border:SetPoint("BOTTOMRIGHT", widget_frame, "BOTTOMRIGHT", db.Offset, -db.Offset)

  widget_frame.Border:SetBackdrop({
    bgFile = ThreatPlates.Media:Fetch('statusbar', db.BorderBackground),
    edgeFile = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\TargetArtWidget\\glow", --ThreatPlates.Media:Fetch('border', db.BorderTexture),
    edgeSize = db.EdgeSize,
    insets = { left = db.Inset, right = db.Inset, top = db.Inset, bottom = db.Inset },
  })

  widget_frame.Border:SetBackdropColor(1, 1, 1, 0.7)
  widget_frame.Border:SetBackdropBorderColor(1, 0, 0, 1)
end

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("StatusBar", nil, tp_frame)
  widget_frame:Hide()

  widget_frame:SetPoint("Center", tp_frame, "TOP", 0, 10)

  widget_frame.Border = CreateFrame("Frame", nil, widget_frame)
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel())
  widget_frame.Border:SetFrameLevel(widget_frame:GetFrameLevel())

  return widget_frame
end