local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

-----------------------
-- Widget for Testing--
-----------------------

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function enabled()
  return TidyPlatesThreat.db.profile.TestWidget.ON
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

local function UpdateSettings(frame)
  local db = TidyPlatesThreat.db.profile.TestWidget

  frame:SetSize(db.BarWidth, db.BarHeight)
  frame:SetStatusBarTexture(ThreatPlates.Media:Fetch('statusbar', db.BarTexture))
  frame:SetScale(db.Scale)
  frame:SetMinMaxValues(0, 100)
  frame:SetValue(50)
  frame:SetStatusBarColor(0, 1, 0)

  frame.Border:ClearAllPoints()
  frame.Border:SetPoint("TOPLEFT", frame, "TOPLEFT", -db.Offset, db.Offset)
  frame.Border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", db.Offset, -db.Offset)

  frame.Border:SetBackdrop({
    bgFile = ThreatPlates.Media:Fetch('statusbar', db.BorderBackground),
    edgeFile = ThreatPlates.Media:Fetch('border', db.BorderTexture),
    edgeSize = db.EdgeSize,
    insets = { left = db.Inset, right = db.Inset, top = db.Inset, bottom = db.Inset },
  })

  frame.Border:SetBackdropColor(1, 1, 1, 0.7)
  frame.Border:SetBackdropBorderColor(1, 0, 0, 1)
end

local function UpdateWidgetFrame(frame, unit)
  frame:Show()
end

-- Context
local function UpdateWidgetContext(frame, unit)
  local guid = unit.guid
  frame.guid = guid

  -- Add to Widget List
  -- if guid then
  -- 	WidgetList[guid] = frame
  -- end

  -- Custom Code II
  --------------------------------------
  if UnitGUID("target") == guid then
    UpdateWidgetFrame(frame, unit)
  else
    frame:_Hide()
  end
  --------------------------------------
  -- End Custom Code
end

local function ClearWidgetContext(frame)
  local guid = frame.guid
  if guid then
    -- WidgetList[guid] = nil
    frame.guid = nil
  end
end

local function CreateWidgetFrame(parent)
  -- Required Widget Code
  local frame = CreateFrame("StatusBar", nil, parent)
  frame:Hide()

  -- Custom Code III
  --------------------------------------
  frame:SetPoint("Center", parent, "TOP", 0, 10)

  frame.Border = CreateFrame("Frame", nil, frame)
  frame:SetFrameLevel(parent:GetFrameLevel())
  frame.Border:SetFrameLevel(frame:GetFrameLevel())

  UpdateSettings(frame)
  frame.UpdateConfig = UpdateSettings
  --------------------------------------
  -- End Custom Code

  -- Required Widget Code
  frame.UpdateContext = UpdateWidgetContext
  frame.Update = UpdateWidgetFrame
  frame._Hide = frame.Hide
  frame.Hide = function() ClearWidgetContext(frame); frame:_Hide()
  end

  return frame
end