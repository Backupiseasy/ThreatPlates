local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

-- Lua APIs

-- WoW APIs
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local function SetCastbarColor(unit)
	if not unit.unitid then return end

	local db = TidyPlatesThreat.db.profile

	local c
	if unit.spellIsShielded then
		c = db.castbarColorShield
	else
		c = db.castbarColor
	end

	-- With TidyPlates:
	-- set background color for castbar
	-- There are LUA errors when calling GetNamePlateForUnit with a nil unitid
	-- Don't know why this could happen here, but the nameplate should be invalid / not visible anyway
	--	local plate = GetNamePlateForUnit(unit.unitid)
	--	if plate and plate.extended then
	--
	--		db = db.settings.castbar
	--		if db.BackgroundUseForegroundColor then
	--			plate.extended.visual.castbar.Backdrop:SetVertexColor(c.r, c.g, c.b, db.BackgroundOpacity)
	--		else
	--			local color = db.BackgroundColor
	--			plate.extended.visual.castbar.Backdrop:SetVertexColor(color.r, color.g, color.b, db.BackgroundOpacity)
	--		end
	--	end

	db = db.settings.castbar
	if db.BackgroundUseForegroundColor then
		return c.r, c.g, c.b, c.a, c.r, c.g, c.b, 1 - db.BackgroundOpacity
	else
		local color = db.BackgroundColor
		return c.r, c.g, c.b, c.a, color.r, color.g, color.b, 1 - db.BackgroundOpacity
	end

	-- With TidyPlates:
	--return c.r, c.g, c.b, c.a
end

TidyPlatesThreat.SetCastbarColor = SetCastbarColor