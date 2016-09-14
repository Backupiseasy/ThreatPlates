local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

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

-- activetheme is the table, not just the name
local function CreateWidgets(plate, activetheme)
	if activetheme then
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
	end
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
					-- TODO: unit sometimes seems to be nil, no idea why
				if unit then
					w[k]:Update(unit)
					if v.isContext then
						w[k]:UpdateContext(unit)
					end
				end
			end
		end
	end
end
ThreatPlatesWidgets.RegisterWidget = RegisterWidget
ThreatPlatesWidgets.UnregisterWidget = UnregisterWidget
ThreatPlatesWidgets.CreateWidgets = CreateWidgets
ThreatPlatesWidgets.UpdatePlate = UpdatePlate
