local ADDON_NAME, NAMESPACE = ...
ThreatPlates = NAMESPACE.ThreatPlates

-----------------------
-- Class Icon Widget --
-----------------------
local path = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ClassIconWidget\\"
-- local WidgetList = {}

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function enabled()
	return TidyPlatesThreat.db.profile.classWidget.ON
end

local function UpdateWidgetConfig(frame, class)
	local db = TidyPlatesThreat.db.profile.classWidget
	frame:SetHeight(db.scale)
	frame:SetWidth(db.scale)
	frame:SetPoint(db.anchor, frame:GetParent(), db.x, db.y)

	if class then
		frame.Icon:SetTexture(path..db.theme.."\\"..class)
	end
end

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
-- 	for _, widget in pairs(WidgetList) do
-- 		widget:Hide()
-- 	end
-- 	WidgetList = {} -- should not be necessary, as Hide() does that, just to be sure
-- end
-- ThreatPlatesWidgets.ClearAllClassIconWidgets = ClearAllWidgets

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

-- Update Graphics
local function UpdateWidgetFrame(frame, unit, style)
	--local S = TidyPlatesThreat.SetStyle(unit)
	if not style then style = TidyPlatesThreat.SetStyle(unit) end
	--if (not enabled()) or S == "NameOnly" or S == "etotem" or S == "empty" then frame:_Hide(); return end
	if style == "NameOnly" or style == "etotem" or style == "empty" then frame:_Hide(); return end

	-- TODO: optimization - is it necessary to determine the class everytime this function is called on only if the guid changes?
	local db = TidyPlatesThreat.db.profile
	local class
	if unit.type == "PLAYER" then
		if unit.reaction == "HOSTILE" then
			class = unit.class
		elseif unit.reaction == "FRIENDLY" and db.friendlyClassIcon then
			-- if db.cacheClass and unit.guid then
			-- 	-- local _, Class = GetPlayerInfoByGUID(unit.guid)
			-- 	if not db.cache[unit.name] then
			-- 		db.cache[unit.name] = unit.class
			-- 		class = unit.class
			-- 	else
			-- 		class = db.cache[unit.name]
			-- 	end
			-- else
 				class = unit.class
			-- end
		end
	end

	if class then -- Value shouldn't need to change
		UpdateWidgetConfig(frame, class)
		frame:Show()
	else
		frame:_Hide()
	end
end

-- Context - GUID or unitid should only change here, i.e., class changes should be determined here
local function UpdateWidgetContext(frame, unit, style)
	local guid = unit.guid
	frame.guid = guid

	-- Add to Widget List
	-- if guid then
	-- 	WidgetList[guid] = frame
	-- end

	-- Custom Code II
	--------------------------------------
	if UnitGUID("target") == guid then
		UpdateWidgetFrame(frame, unit, style)
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
	frame:SetHeight(64)
	frame:SetWidth(64)
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	frame.Icon:SetAllPoints(frame)

	frame.UpdateConfig = UpdateWidgetConfig
	--------------------------------------
	-- End Custom Code

	-- Required Widget Code
	frame.UpdateContext = UpdateWidgetContext
	frame.Update = UpdateWidgetFrame
	frame._Hide = frame.Hide
	frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end

	return frame
end

ThreatPlatesWidgets.RegisterWidget("ClassIconWidget", CreateWidgetFrame, false, enabled)
