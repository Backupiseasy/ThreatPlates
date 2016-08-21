local _, ns = ...
local t = ns.ThreatPlates
------------------------------
-- Elite Art Overlay Widget --
------------------------------
-- Notes:
-- * This is not a 'standard' widget. It's more a work around to display a more elegant elite border on the healthbar.
-- * Some would consider this a performance hit.

local function enabled()
	local db = TidyPlatesThreat.db.profile.settings.elitehealthborder
	return db.show
end

local function UpdateEliteFrameArtOverlay(frame, unit)
	local db = TidyPlatesThreat.db.profile.settings.elitehealthborder
	local S = TidyPlatesThreat.SetStyle(unit)
	if unit.isElite and S ~= "empty" and S~= "etotem" and S~= "NameOnly" then
		frame.Border:SetTexture(t.Art..db.texture)
		frame:Show()
	else
		frame:Hide()
	end
end

local function CreateEliteFrameArtOverlay(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetFrameLevel(parent.bars.healthbar:GetFrameLevel())
	frame:SetWidth(256)
	frame:SetHeight(64)
	frame:SetPoint("CENTER",parent,"CENTER")
	frame.Border = frame:CreateTexture(nil, "OVERLAY")
	frame.Border:SetAllPoints(frame)
	frame:Hide()
	frame.Update = UpdateEliteFrameArtOverlay
	return frame
end

ThreatPlatesWidgets.RegisterWidget("EliteBorder",CreateEliteFrameArtOverlay,false,enabled)
