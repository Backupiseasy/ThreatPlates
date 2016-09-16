local ADDON_NAME, NAMESPACE = ...
ThreatPlates = NAMESPACE.ThreatPlates

------------------------------
-- Elite Art Overlay Widget --
------------------------------
-- Notes:
-- * This is not a 'standard' widget. It's more a work around to display a more elegant elite border on the healthbar.
-- * Some would consider this a performance hit.

local WidgetList = {}

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function enabled()
	local db = TidyPlatesThreat.db.profile.settings.elitehealthborder
	return db.show
end

-- hides/destroys all widgets of this type created by Threat Plates
local function ClearAllWidgets()
	for _, widget in pairs(WidgetList) do
		widget:Hide()
	end
	WidgetList = {}		
end
ThreatPlatesWidgets.ClearAllEliteArtOverlayWidgets = ClearAllWidgets

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function UpdateWidgetFrame(frame, unit)
	local db = TidyPlatesThreat.db.profile.settings.elitehealthborder
	local S = TidyPlatesThreat.SetStyle(unit)
	if unit.isElite and S ~= "empty" and S~= "etotem" and S~= "NameOnly" then
		frame.Border:SetTexture(ThreatPlates.Art..db.texture)
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
	frame:SetFrameLevel(parent.bars.healthbar:GetFrameLevel())
	frame:SetWidth(256)
	frame:SetHeight(64)
	frame:SetPoint("CENTER",parent,"CENTER")
	frame.Border = frame:CreateTexture(nil, "OVERLAY")
	frame.Border:SetAllPoints(frame)

	--------------------------------------
	-- End Custom Code

	-- Required Widget Code
	frame.UpdateContext = UpdateWidgetContext
	frame.Update = UpdateWidgetFrame
	frame._Hide = frame.Hide
	frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end

	return frame
end

ThreatPlatesWidgets.RegisterWidget("EliteBorder", CreateWidgetFrame, false, enabled)
