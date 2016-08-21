local function SetThreatColor(unit)
	local style = TidyPlatesThreat.SetStyle(unit)
	local c = {r = "0", g = "0", b = "0", a = "0"}
	if style == "dps" or style == "tank" or style == "normal" and InCombatLockdown() then
		c = TidyPlatesThreat.db.profile.settings[style]["threatcolor"][unit.threatSituation]
	end
	return c.r, c.g, c.b, c.a	
end

TidyPlatesThreat.SetThreatColor = SetThreatColor