-----------------------
-- Class Icon Widget --
-----------------------
local path = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ClassIconWidget\\"
local Masque = LibStub("Masque", true)

local function enabled()
	local db = TidyPlatesThreat.db.profile.classWidget
	return db.ON
end

local function UpdateSettings(frame)
	local db = TidyPlatesThreat.db.profile.classWidget
	frame:SetHeight(db.scale)
	frame:SetWidth(db.scale)
	frame:SetPoint((db.anchor), frame:GetParent(), (db.x), (db.y))

	if Masque then
		group = Masque:Group("TidyPlatesThreat")
		group:ReSkin(frame)
	end
end

local function UpdateClassIconWidget(frame, unit)
	local db = TidyPlatesThreat.db.profile
	local S = TidyPlatesThreat.SetStyle(unit)
	if (not enabled()) or S == "NameOnly" then frame:Hide(); return end

	local class
	--print ("unit.reation = ", unit.reaction, "  -- unit.type = ", unit.type)

	-- if unit.class and (unit.class ~= "UNKNOWN") and (unit.type ~= "NPC")then
	-- 	class = unit.class
	-- elseif db.friendlyClassIcon then
	-- 	if unit.guid then
	-- 		local _, Class = GetPlayerInfoByGUID(unit.guid)
	-- 		if not db.cache[unit.name] then
	-- 			if db.cacheClass then
	-- 				db.cache[unit.name] = Class
	-- 			end
	-- 			class = Class
	-- 		else
	-- 			class = db.cache[unit.name]
	-- 		end
	-- 	end
	-- end

	if db.friendlyClassIcon and unit.reaction == "FRIENDLY" and unit.type == "PLAYER" then
			if unit.guid then
				local _, Class = GetPlayerInfoByGUID(unit.guid)
				if not db.cache[unit.name] then
					if db.cacheClass then
						db.cache[unit.name] = Class
					end
					class = Class
				else
					class = db.cache[unit.name]
				end
			end
	elseif unit.type == "PLAYER" then
			class = unit.class
	end

	if class then -- Value shouldn't need to change
		UpdateSettings(frame)
		frame.Icon:SetTexture(path..db.classWidget.theme.."\\"..class)
		frame:Show()
	else
		frame:Hide()
	end
end

-- local function Reskin()
-- 	print ("Masque: Reskin")
-- end

local function CreateClassIconWidget(parent)
	local db = TidyPlatesThreat.db.profile.classWidget
	local frame
	if Masque then
		frame = CreateFrame("Button", "mybutton", parent, "ActionButtonTemplate")
		frame:EnableMouse(false)
	else
		frame = CreateFrame("Frame", nil, parent)
	end

	frame:SetHeight(db.scale)
	frame:SetWidth(db.scale)
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	frame.Icon:SetAllPoints(frame)
	frame:Hide()
	frame.Update = UpdateClassIconWidget

	if Masque then
		group = Masque:Group("TidyPlatesThreat")
		--Masque:Register("TidyPlatesThreat", Reskin)
		group:AddButton(frame)
	end

	return frame
end

ThreatPlatesWidgets.RegisterWidget("ClassIconWidget",CreateClassIconWidget,false,enabled)

ThreatPlatesWidgets.CreateClassIconWidget = CreateClassIconWidget
