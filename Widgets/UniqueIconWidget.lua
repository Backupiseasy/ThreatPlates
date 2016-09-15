local ADDON_NAME, NAMESPACE = ...
ThreatPlates = NAMESPACE.ThreatPlates

---------------
-- Unique Icon Widget
---------------
local WidgetList = {}

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function enabled()
	local db = TidyPlatesThreat.db.profile.uniqueWidget
	return db.ON
end

local function UpdateSettings(frame)
	local db = TidyPlatesThreat.db.profile.uniqueWidget
	frame:SetHeight(db.scale)
	frame:SetWidth(db.scale)
	frame:SetPoint(db.anchor, frame:GetParent(), db.x, db.y)
end

-- hides/destroys all widgets of this type created by Threat Plates
local function ClearAllWidgets()
	for _, widget in pairs(WidgetList) do
		widget:Hide()
	end
end
ThreatPlatesWidgets.ClearAllUniqueIconWidgets = ClearAllWidgets

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function UpdateWidgetFrame(frame, unit)
	local db = TidyPlatesThreat.db.profile.uniqueSettings
	local isShown = false
	if enabled() then
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
	end
	if isShown then
		UpdateSettings(frame)
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
	if guid then
		WidgetList[guid] = frame
	end

	-- Custom Code II
	--------------------------------------
	-- if UnitGUID("target") == guid then
	-- 	UpdateWidgetFrame(frame, unit)
	-- else
	-- 	frame:_Hide()
	-- end
	--------------------------------------
	-- End Custom Code
end

local function ClearWidgetContext(frame)
	local guid = frame.guid
	if guid then
		WidgetList[guid] = nil
		frame.guid = nil
	end
end

local function CreateWidgetFrame(parent)
	-- Required Widget Code
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()

	-- Custom Code III
	--------------------------------------
	frame:SetWidth(64)
	frame:SetHeight(64)
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	frame.Icon:SetPoint("CENTER",frame)
	frame.Icon:SetAllPoints(frame)
	--------------------------------------
	-- End Custom Code

	-- Required Widget Code
	frame.UpdateContext = UpdateWidgetContext
	frame.Update = UpdateWidgetFrame
	frame._Hide = frame.Hide
	frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end

	return frame
end

ThreatPlatesWidgets.RegisterWidget("UniqueIconWidget", CreateWidgetFrame, true, enabled)
