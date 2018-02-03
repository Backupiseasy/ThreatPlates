-----------------------
-- Class Icon Widget --
-----------------------
local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ClassIconWidget\\"
local PATH_THEME
-- local WidgetList = {}
-- local Masque = LibStub("Masque", true)
-- local group

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function enabled()
	return TidyPlatesThreat.db.profile.classWidget.ON
end

local function EnabledInHeadlineView()
	return TidyPlatesThreat.db.profile.classWidget.ShowInHeadlineView
end

local function UpdateSettings(frame)
	local db = TidyPlatesThreat.db.profile.classWidget
	local size = db.scale
	frame:SetSize(size, size)
	PATH_THEME = PATH .. db.theme .."\\"
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
local function UpdateWidgetFrame(frame, unit)
	local db = TidyPlatesThreat.db.profile

	local class
	if unit.type == "PLAYER" then
		if unit.reaction == "HOSTILE" and db.HostileClassIcon then
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
		db = TidyPlatesThreat.db.profile.classWidget
		local style = unit.TP_Style
		if style == "NameOnly" or style == "NameOnly-Unique" then
			frame:SetPoint("CENTER", frame:GetParent(), db.x_hv, db.y_hv)
		else
			frame:SetPoint("CENTER", frame:GetParent(), db.x, db.y)
		end

		frame.Icon:SetTexture(PATH_THEME .. class)

		-- if Masque then
		-- 	group = Masque:Group("TidyPlatesThreat")
		-- 	group:ReSkin(frame)
		-- end

		frame:Show()
	else
		frame:_Hide()
	end
end

-- Context - GUID or unitid should only change here, i.e., class changes should be determined here
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

-- local function Reskin()
-- 	print ("Masque: Reskin")
-- end

local function CreateWidgetFrame(parent)
	-- Required Widget Code
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()

	-- Custom Code III
	--------------------------------------
	frame:SetFrameLevel(parent:GetFrameLevel() + 7)
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	frame.Icon:SetAllPoints(frame)

	-- if Masque then
	-- 	if not group then
	--  		group = Masque:Group("TidyPlatesThreat")
	-- 	end
	-- 	--Masque:Register("TidyPlatesThreat", Reskin)
	-- 	group:AddButton(frame)
	-- end

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

ThreatPlatesWidgets.RegisterWidget("ClassIconWidgetTPTP", CreateWidgetFrame, false, enabled, EnabledInHeadlineView)