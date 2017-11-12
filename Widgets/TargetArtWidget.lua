-----------------------
-- Target Art Widget --
-----------------------
local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitGUID = UnitGUID

local path = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\TargetArtWidget\\"
-- local WidgetList = {}

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function enabled()
	return TidyPlatesThreat.db.profile.targetWidget.ON
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
  local db = TidyPlatesThreat.db.profile.targetWidget

  if db.ON then
    frame.Icon:SetTexture(path..db.theme)
    frame.Icon:SetVertexColor(db.r, db.g, db.b, db.a)

    if db.theme == "default" or db.theme == "squarethin" then
      frame.Icon:SetDrawLayer("OVERLAY", -7)
    else
      frame.Icon:SetDrawLayer("OVERLAY", 7)
    end

    frame:Show()
    frame.Icon:Show()
  else
    frame:_Hide()
    frame.Icon:Hide()
  end
end

local function UpdateWidgetFrame(frame, unit)
  frame:Show()
  frame.Icon:Show()
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
    frame.Icon:Hide()
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
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()

	-- Custom Code III
	--------------------------------------
	-- framelevel of Target Highlight must be the same as visual.target (target highlight of TidyPlates)
  -- that is: extended.healthbar.textFrame, texture target (BACKGROUND)
	frame:SetFrameLevel(parent:GetFrameLevel())
	frame:SetSize(256, 64)
	frame:SetPoint("CENTER", parent, "CENTER")

  frame.Icon = parent.visual.name:GetParent():CreateTexture(nil, "OVERLAY")
  frame.Icon:SetAllPoints(frame)
  frame.Icon:Hide()

  UpdateSettings(frame)
  frame.UpdateConfig = UpdateSettings
	--------------------------------------
	-- End Custom Code

	-- Required Widget Code
	frame.UpdateContext = UpdateWidgetContext
	frame.Update = UpdateWidgetFrame
	frame._Hide = frame.Hide
	-- Have to add frame.Icon:Hide() also here as the frame is no longer the parent of the icon since a fix to widget layering
	frame.Hide = function()
		ClearWidgetContext(frame)
		frame.Icon:Hide()
		frame:_Hide()
	end

	return frame
end

ThreatPlatesWidgets.RegisterWidget("TargetArtWidgetTPTP", CreateWidgetFrame, true, enabled)
