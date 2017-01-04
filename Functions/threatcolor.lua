local ADDON_NAME, NAMESPACE = ...
ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local RGB = ThreatPlates.RGB
local TRANSPARENT_COLOR = RGB(0, 0, 0, 0)

local function SetThreatColor(unit)
	local db = TidyPlatesThreat.db.profile
	local style = TidyPlatesThreat.SetStyle(unit)

	local c = TRANSPARENT_COLOR
	if style == "dps" or style == "tank" or style == "normal" and InCombatLockdown() then
		if db.ShowThreatGlowOnAttackedUnitsOnly and unit.unitid then
			local _, threatStatus = UnitDetailedThreatSituation("player", unit.unitid);
			if (threatStatus ~= nil) then
				c = db.settings[style]["threatcolor"][unit.threatSituation]
			end
		else
			c = db.settings[style]["threatcolor"][unit.threatSituation]
		end
	end
	return c.r, c.g, c.b, c.a
end

TidyPlatesThreat.SetThreatColor = SetThreatColor
