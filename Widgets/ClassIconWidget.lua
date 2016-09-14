-----------------------
-- Class Icon Widget --
-----------------------
local path = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ClassIconWidget\\"

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

local function UpdateClassIconWidget(frame, unit)
	local S = TidyPlatesThreat.SetStyle(unit)
	if (not enabled()) or S == "NameOnly" or S == "etotem" or S == "empty" then frame:Hide(); return end

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
		elseif unit.reation == "HOSTILE" then -- hostile player, always show icon if enabled at all
 			class = unit.class
		end
	end

	if class then -- Value shouldn't need to change
		UpdateSettings(frame)
		frame.Icon:SetTexture(path..db.classWidget.theme.."\\"..class)
		frame:Show()
	else
		frame:Hide()
	end
end

local function CreateClassIconWidget(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetHeight(64)
	frame:SetWidth(64)
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	frame.Icon:SetAllPoints(frame)
	frame:Hide()
	frame.Update = UpdateClassIconWidget
	return frame
end

ThreatPlatesWidgets.RegisterWidget("ClassIconWidget",CreateClassIconWidget,false,enabled)

ThreatPlatesWidgets.CreateClassIconWidget = CreateClassIconWidget
