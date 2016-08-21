---------------
-- Unique Icon Widget
---------------

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

local function UpdateUniqueIconWidget(frame, unit)
	local db = TidyPlatesThreat.db.profile.uniqueSettings
	local isShown = false
	if enabled then
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
		frame:Hide()
	end
end

local function CreateUniqueIconWidget(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetWidth(64)
	frame:SetHeight(64)
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	frame.Icon:SetPoint("CENTER",frame)
	frame.Icon:SetAllPoints(frame)
	frame:Hide()
	frame.Update = UpdateUniqueIconWidget
	return frame
end

ThreatPlatesWidgets.RegisterWidget("UniqueIconWidget",CreateUniqueIconWidget,false,enabled)