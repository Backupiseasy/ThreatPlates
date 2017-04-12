-------------------------------------------------------------------------------
-- Totem Icon Widget
-------------------------------------------------------------------------------
local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local TotemNameBySpellID = ThreatPlates.TotemNameBySpellID

local path = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\TotemIconWidget\\"
-- local WidgetList = {}

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function enabled()
	return TidyPlatesThreat.db.profile.totemWidget.ON
end

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
-- 	for _, widget in pairs(WidgetList) do
-- 		widget:Hide()
-- 	end
-- end
-- ThreatPlatesWidgets.ClearAllTotemIconWidgets = ClearAllWidgets

-------------------------------------------------------------------------------
-- Totem data - define it one time for the whole addon
-------------------------------------------------------------------------------

TOTEM_DATA = {
	-- Totems from Totem Mastery
	[1]  = {202188, "M1",  "b8d1ff"}, 	-- Resonance Totem
	[2]  = {210651, "M2",	 "b8d1ff"},		-- Storm Totem
	[3]  = {210657, "M3",  "b8d1ff"},		-- Ember Totem
	[4]  = {210660, "M4",  "b8d1ff"},		-- Tailwind Totem

	-- Totems from spezialization
	[5]  = {98008,  "S1",  "ffb31f"},		-- Spirit Link Totem
	[6]  = {5394,	  "S2",  "ffb31f"},		-- Healing Stream Totem
	[7]  = {108280, "S3",  "ffb31f"},		-- Healing Tide Totem
	[8]  = {160161, "S4",  "ffb31f"}, 	-- Earthquake Totem
	[9]  = {2484, 	"S5",	 "ffb31f"},  	-- Earthbind Totem (added patch 7.2, TP v8.4.0)

	-- Lonely fire totem
	[10] = {192222, "F1",  "ff8f8f"}, 	-- Liquid Magma Totem

  -- Totems from talents
	[11] = {157153, "N1",  "4c9900"},		-- Cloudburst Totem
	[12] = {51485,  "N2",  "4c9900"},		-- Earthgrab Totem
	[13] = {192058, "N3",  "4c9900"},		-- Lightning  Surge Totem
	[14] = {207399, "N4",  "4c9900"},		-- Ancestral Protection Totem
	[15] = {192077, "N5",  "4c9900"},		-- Wind Rush Totem
	[16] = {196932, "N6",  "4c9900"},		-- Voodoo Totem
	[17] = {198838, "N7",  "4c9900"},		-- Earthen Shield Totem

	-- Totems from PVP talents
	[18] = {204331, "P1",  "2b76ff"},	-- Counterstrike Totem
	[19] = {204330, "P2",  "2b76ff"},	-- Skyfury Totem
	[20] = {204332, "P3",  "2b76ff"},	-- Windfury Totem
	[21] = {204336, "P4",  "2b76ff"},	-- Grounding Totem
}

-- Totems data as needed by the options dialog
ThreatPlatesWidgets.TOTEM_DATA = TOTEM_DATA

-- Totems data as in this file
ThreatPlates_Totems_Config = { hideHealthbar = false, }
ThreatPlates_Totems = {}
do
	for i=1,#TOTEM_DATA do
		ThreatPlates_Totems[TotemNameBySpellID(TOTEM_DATA[i][1])] = TOTEM_DATA[i][2]
		local color = TOTEM_DATA[i][3]
		local color_r = tonumber("0x"..color:sub(1,2))/255
		local color_g = tonumber("0x"..color:sub(3,4))/255
		local color_b = tonumber("0x"..color:sub(5,6))/255
		--	["Reference"] = {allow totem nameplate, allow hp color, r, g, b, show icon, style}
		ThreatPlates_Totems_Config[TOTEM_DATA[i][2]] = {
			true, -- allow totem nameplate
			true, -- allow hp color
			true, -- show icon
			nil,
			nil,
			nil,
			"normal", -- style
			color = {r = color_r, g = color_g, b = color_b }, -- r, g, b,
		}

	end
end

-- Totems data as needed for initial/default config
ThreatPlatesWidgets.TOTEM_SETTINGS = ThreatPlates_Totems_Config

-------------------------------------------------------------------------------

local function GetTotemInfo(name)
	local totem = ThreatPlates_Totems[name]
	local db = TidyPlatesThreat.db.profile.totemSettings
	if totem then
		local texture =  path..db[totem][7].."\\"..totem
		return db[totem][3],texture
	else
		return false, nil
	end
end

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function UpdateSettings(frame)
	local db = TidyPlatesThreat.db.profile.totemWidget
	local size = db.scale
	frame:SetSize(size, size)
	frame:SetPoint(db.anchor, frame:GetParent(), db.x, db.y)
end

local function UpdateWidgetFrame(frame, unit)
	local isActive, texture = GetTotemInfo(unit.name)
	if isActive then
		frame.Icon:SetTexture(texture)
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

local function CreateWidgetFrame(parent)
	-- Required Widget Code
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()

	-- Custom Code III
	--------------------------------------
	frame:SetSize(64, 64)
	frame:SetFrameLevel(frame:GetParent():GetFrameLevel()+1)

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

ThreatPlatesWidgets.RegisterWidget("TotemIconWidgetTPTP", CreateWidgetFrame, false, enabled)
