local Masque = LibStub("Masque", true)
local group

---------------------
-- Widget Handling --
---------------------

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
	local w = plate.widgets
	for k,v in pairs(ThreatPlatesWidgets.list) do
		if v.enabled() then
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
ThreatPlatesWidgets.RegisterWidget = RegisterWidget
ThreatPlatesWidgets.UnregisterWidget = UnregisterWidget
ThreatPlatesWidgets.CreateWidgets = CreateWidgets
ThreatPlatesWidgets.UpdatePlate = UpdatePlate
