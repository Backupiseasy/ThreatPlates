------------------------
-- Combo Point Widget --
------------------------
local path = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ComboPointWidget\\"

local WidgetList = {}

local Anticipation =  GetSpellInfo(114015)

local function enabled()
	local db = TidyPlatesThreat.db.profile.comboWidget
	return db.ON
end

-- Update Graphics
local function UpdateWidgetFrame(frame)
	local points
	if UnitExists("target") then
		points = GetComboPoints("player", "target")
	end
	if points and points > 0 and enabled() then
		if points > 4 then
			local name, _, _, count = UnitAura("player", Anticipation)

			if name and count > 0 then
				points = points + count
			end
		end
		local db = TidyPlatesThreat.db.profile.comboWidget
		--frame:SetFrameLevel(frame:GetParent().bars.healthbar:GetFrameLevel()+2)
		frame.Icon:SetTexture(path..points)
		frame:SetScale(db.scale)
		frame:SetPoint("CENTER",frame:GetParent(),"CENTER",db.x,db.y)
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

	-- Update Widget
	if UnitGUID("target") == guid then
		UpdateWidgetFrame(frame)
	else
		frame:_Hide()
	end
end

local function ClearWidgetContext(frame)
	local guid = frame.guid
	if guid then
		WidgetList[guid] = nil
		frame.guid = nil
	end
end

-- Watcher Frame
local WatcherFrame = CreateFrame("Frame", nil, WorldFrame )
local isEnabled = false
WatcherFrame:RegisterEvent("UNIT_COMBO_POINTS")

local function WatcherFrameHandler(frame, event, unitid)
	local guid = UnitGUID("target")
	if guid then
		local widget = WidgetList[guid]
		if widget then
			UpdateWidgetFrame(widget)
		end
	end
end

local function EnableWatcherFrame(arg)
	if arg then
		WatcherFrame:SetScript("OnEvent", WatcherFrameHandler); isEnabled = true
	else WatcherFrame:SetScript("OnEvent", nil); isEnabled = false end
end

-- Widget Creation
local function CreateWidgetFrame(parent)
	-- Required Widget Code
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()

	-- Custom Code
	frame:SetFrameLevel(parent:GetFrameLevel()+2)
	local db = TidyPlatesThreat.db.profile.comboWidget
	frame:SetPoint("CENTER",parent,"CENTER",db.x,db.y)
	frame:SetHeight(64)
	frame:SetWidth(64)
	frame:SetScale(db.scale)
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	-- frame.Icon:SetTexture(path..points)
	frame.Icon:SetAllPoints(frame)
	-- End Custom Code

	-- Required Widget Code
	frame.UpdateContext = UpdateWidgetContext
	frame.Update = UpdateWidgetContext
	frame._Hide = frame.Hide
	frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end
	if not isEnabled then EnableWatcherFrame(true) end
	return frame
end

ThreatPlatesWidgets.RegisterWidget("ComboPointWidget",CreateWidgetFrame,true,enabled)
