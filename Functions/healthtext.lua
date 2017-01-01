local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

local function Truncate(value)
	if TidyPlatesThreat.db.profile.text.truncate then
		if value >= 1e6 then
			return format('%.1fm', value / 1e6)
		elseif value >= 1e4 then
			return format('%.1fk', value / 1e3)
		else
			return value
		end
	else
		return value
	end
end

local function SetCustomText(unit)
	local db = TidyPlatesThreat.db.profile.text
	local S = TidyPlatesThreat.SetStyle(unit)

	-- Headline View (alpha feature) uses TidyPlatesHub config and functionality
	if ThreatPlates.AlphaFeatureHeadlineView() and (S == "NameOnly") then
		return TidyPlatesHubFunctions.SetCustomTextBinary(unit)
	end

	if (not db.full and unit.health == unit.healthmax) then
		return ""
	end
	local HpPct = ""
	local HpAmt = ""
	local HpMax = ""

	if db.amount then

		if db.deficit and unit.health ~= unit.healthmax then
			HpAmt = "-"..Truncate(unit.healthmax - unit.health)
		else
			HpAmt = Truncate(unit.health)
		end

		if db.max then
			if HpAmt ~= "" then
				HpMax = " / "..Truncate(unit.healthmax)
			else
				HpMax = Truncate(unit.healthmax)
			end
		end
	end

	if db.percent then
		-- Blizzard calculation:
		-- local perc = math.ceil(100 * (UnitHealth(frame.displayedUnit)/UnitHealthMax(frame.displayedUnit)));

		local perc = math.ceil(100 * (unit.health / unit.healthmax))
		-- old: floor(100*(unit.health / unit.healthmax))

		if HpMax ~= "" or HpAmt ~= "" then
			HpPct = " - "..perc.."%"
		else
			HpPct = perc.."%"
		end
	end

	return HpAmt..HpMax..HpPct
end

TidyPlatesThreat.SetCustomText = SetCustomText
