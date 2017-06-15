local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

local function SetCastbarColor(unit)
	local db = TidyPlatesThreat.db.profile
	local c = {r = 1,g = 1,b = 0,a = 1}
	if db.castbarColor.toggle then
		if unit.spellIsShielded and db.castbarColorShield.toggle then
			c = db.castbarColorShield
		else
			c = db.castbarColor
		end
	end
	return c.r, c.g, c.b, c.a
end

TidyPlatesThreat.SetCastbarColor = SetCastbarColor