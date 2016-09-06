local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

--local Masque = LibStub("Masque", true)
--local group

---------------------
-- Widget Handling --
---------------------

-- Information about widget layering, from highest to lowest
--    +2: combo points
-- 		+1: auras
--  widgets: frame level + 3
--  highest frame: cast bar -> spell icon, spell text
--  middle frame: raid icon, elite icon, skull icon, target
--    customtext, name, level
--  lower frame: healthbar -> health border, threat border, highlight (like healborder)
-- Current state:
--   name text is layered above combo point widget

ThreatPlatesWidgets = {}
ThreatPlatesWidgets.list = {}

local function RegisterWidget(name,create,isContext,enabled)
	if not ThreatPlatesWidgets.list[name] then
		ThreatPlatesWidgets.list[name] = {
			name = name,
			create = create,
			isContext = isContext,
			enabled = enabled
		}
	end
end

local function UnregisterWidget(name)
	if ThreatPlatesWidgets.list[name] then
		ThreatPlatesWidgets.list[name] = nil
	end
end

local function CreateWidgets(plate)
	local w = plate.widgets
	for k,v in pairs(ThreatPlatesWidgets.list) do
		if v.enabled() then
			if not w[k] then
				local widget
				widget = v.create(plate)
				w[k] = widget
			end
		else
			if w[k] then
				w[k]:Hide()
				w[k] = nil
			end
		end
	end

	--  Substsitute spell icon to be able to skin it using Masque
	-- if Masque then
	-- 	local frame = CreateFrame("Button", "Button_Spellicon", parent, "ActionButtonTemplate")
	-- 	frame:EnableMouse(false)
	-- 	frame.Icon = plate.visual.spellicon
	-- 	frame.Icon:SetAllPoints(frame)
	-- 	plate.visual.spellicon = frame
	--
	-- 	frame.SetTexCoord = function (left, right, top, bottom)
	-- 		frame.Icon:SetTexCoord(left, right, top, bottom)
	-- 	end
	-- 	frame.SetTexture = function (texture)
	-- 		frame.Icon:SetTexture(texture)
	-- 	end
	--
	-- 	if not group then
	--  		group = Masque:Group("TidyPlatesThreat")
	-- 	end
	-- 	group:AddButton(frame)
	-- end
end

local function UpdatePlate(plate, unit)
	local style = TidyPlatesThreat.SetStyle(unit)
	local w = plate.widgets
	for k,v in pairs(ThreatPlatesWidgets.list) do
		-- Diable all widgets in headline view mode
		if v.enabled() then
			if 	ThreatPlates.AlphaFeatureHeadlineView() and (style == "NameOnly") then
					w[k]:Hide()
			else
				if not w[k] then CreateWidgets(plate) end
				w[k]:Update(unit)
				if v.isContext then
					w[k]:UpdateContext(unit)
				end
			end
		end

	-- if Masque then
	-- 	local frame = CreateFrame("Button", "Button_Spellicon", parent, "ActionButtonTemplate")
	-- 	frame:EnableMouse(false)
	-- 	frame.Icon = plate.visual.spellicon
	-- 	frame.Icon:SetAllPoints(frame)
	-- 	plate.visual.spellicon = frame
	--
	-- 	frame.SetTexCoord = function (left, right, top, bottom)
	-- 		frame.Icon:SetTexCoord(left, right, top, bottom)
	-- 	end
	-- 	frame.SetTexture = function (texture)
	-- 		frame.Icon:SetTexture(texture)
	-- 	end
	--
	-- 	if not group then
	--  		group = Masque:Group("TidyPlatesThreat")
	-- 	end
	-- 	group:AddButton(frame)
	-- end

	end
end
ThreatPlatesWidgets.RegisterWidget = RegisterWidget
ThreatPlatesWidgets.UnregisterWidget = UnregisterWidget
ThreatPlatesWidgets.CreateWidgets = CreateWidgets
ThreatPlatesWidgets.UpdatePlate = UpdatePlate
