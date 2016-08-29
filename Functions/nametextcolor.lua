local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

local function SetNameColor(unit)
	local db = TidyPlatesThreat.db.profile.settings.name.color
	local S = TidyPlatesThreat.SetStyle(unit)

	-- Headline View (alpha feature) uses TidyPlatesHub config and functionality
	if ThreatPlates.AlphaFeatureHeadlineView() and (S == "NameOnly") then
		return TidyPlatesHubFunctions.SetNameColor(unit)
	else
		return db.r, db.g, db.b
	end
end

TidyPlatesThreat.SetNameColor = SetNameColor
