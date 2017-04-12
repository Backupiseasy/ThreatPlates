---------------
-- Unique Icon Widget
---------------

local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- local WidgetList = {}

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function enabled()
	return TidyPlatesThreat.db.profile.uniqueWidget.ON
end

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
-- 	for _, widget in pairs(WidgetList) do
-- 		widget:Hide()
-- 	end
-- 	WidgetList = {}
-- end
-- ThreatPlatesWidgets.ClearAllUniqueIconWidgets = ClearAllWidgets

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function UpdateSettings(frame)
  local db = TidyPlatesThreat.db.profile.uniqueWidget
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", frame:GetParent(), db.x, db.y)

  local size = db.scale
  frame:SetSize(size, size)
end

local function UpdateWidgetFrame(frame, unit)
	local db = TidyPlatesThreat.db.profile.uniqueSettings
	local isShown = false
	if tContains(db.list, unit.name) then
		local s
		for k,v in pairs(db.list) do
			if v == unit.name then
				s = db[k]
				break
			end
		end
		if s and s.showIcon then
			frame.Icon:SetTexture(s.icon)
			isShown = true
		end
	end

	if isShown then
		frame:Show()
	else
		frame:_Hide()
	end
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
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()

	-- Custom Code III
	--------------------------------------
	frame:SetSize(64, 64)

	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	frame.Icon:SetAllPoints(frame)

  UpdateSettings(frame)
  frame.UpdateConfig = UpdateSettings
	--------------------------------------
	-- End Custom Code

	-- Required Widget Code
	frame.UpdateContext = UpdateWidgetContext
	frame.Update = UpdateWidgetFrame
	frame._Hide = frame.Hide
	frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end

	return frame
end

ThreatPlatesWidgets.RegisterWidget("UniqueIconWidgetTPTP", CreateWidgetFrame, false, enabled)
