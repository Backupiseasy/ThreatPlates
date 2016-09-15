local ADDON_NAME, NAMESPACE = ...
ThreatPlates = NAMESPACE.ThreatPlates

-----------------------
-- Class Icon Widget --
-----------------------
local path = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ClassIconWidget\\"
local WidgetList = {}

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function enabled()
	local db = TidyPlatesThreat.db.profile.classWidget
	return db.ON
end

local function UpdateSettings(frame)
	local db = TidyPlatesThreat.db.profile.classWidget
	frame:SetHeight(db.scale)
	frame:SetWidth(db.scale)
	frame:SetPoint((db.anchor), frame:GetParent(), (db.x), (db.y))
end

-- hides/destroys all widgets of this type created by Threat Plates
local function ClearAllWidgets()
	for _, widget in pairs(WidgetList) do
		widget:Hide()
	end
end
ThreatPlatesWidgets.ClearAllClassIconWidgets = ClearAllWidgets

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

-- Update Graphics
local function UpdateWidgetFrame(frame, unit)
	local S = TidyPlatesThreat.SetStyle(unit)
	if (not enabled()) or S == "NameOnly" or S == "etotem" or S == "empty" then frame:_Hide(); return end

	local db = TidyPlatesThreat.db.profile
	local class

	if unit.class and unit.type == "PLAYER" then
 		if unit.reaction == "FRIENDLY" and db.friendlyClassIcon then
			if db.cacheClass and unit.guid then
				local _, Class = GetPlayerInfoByGUID(unit.guid)
				if not db.cache[unit.name] then
					if db.cacheClass then
						db.cache[unit.name] = Class
					end
					class = Class
				else
					class = db.cache[unit.name]
				end
			else
 				class = unit.class
			end
		elseif unit.reaction == "HOSTILE" then -- hostile player, always show icon if enabled at all
 			class = unit.class
		end
	end

	if class then -- Value shouldn't need to change
		UpdateSettings(frame)
		frame.Icon:SetTexture(path..db.classWidget.theme.."\\"..class)
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
	frame:SetHeight(64)
	frame:SetWidth(64)
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
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

ThreatPlatesWidgets.RegisterWidget("ClassIconWidget", CreateWidgetFrame, true, enabled)
