local _, ns = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitIsOffTanked = TidyPlatesThreat.UnitIsOffTanked
local SetStyle = TidyPlatesThreat.SetStyle
local GetDetailedUnitType = TidyPlatesThreat.GetDetailedUnitType

local function GetGeneralAlpha(unit)
	local db = TidyPlatesThreat.db.profile.nameplate

	local unit_type = GetDetailedUnitType(unit)
	local alpha = db.alpha[unit_type] or 1 -- This should also return for totems.

	-- Do checks for target settings, must be spelled out to avoid issues
	if (UnitExists("target") and unit.isTarget) and db.toggle.TargetA then
		alpha = db.alpha.Target
	elseif not UnitExists("target") and db.toggle.NoTargetA then
		if unit.isMarked and db.toggle.MarkedA then
			alpha = db.alpha.Marked
		else
			alpha = db.alpha.NoTarget
		end
	else -- units will always be set to this alpha
		if unit.isCasting and db.toggle.CastingUnitAlpha then
			alpha = db.alpha.CastingUnit
		elseif unit.isMarked and db.toggle.MarkedA then
			alpha = db.alpha.Marked
		elseif unit.isMouseover and db.toggle.MouseoverUnitAlpha then
			alpha = db.alpha.MouseoverUnit
		end
	end
	return alpha
end

local function GetThreatAlpha(unit)
	local db = TidyPlatesThreat.db.profile.threat
	if InCombatLockdown() and (db.ON and db.useAlpha) then
		if unit.isMarked and db.marked.alpha then
			return GetGeneralAlpha(unit)
		else
			local threatSituation = unit.threatSituation
			if TidyPlatesThreat:GetSpecRole() then
				if db.toggle.OffTank and UnitIsOffTanked(unit) then
					threatSituation = "OFFTANK"
				end
				return db["tank"].alpha[threatSituation]
			else
				return db["dps"].alpha[threatSituation]
			end
		end
	else
		return GetGeneralAlpha(unit)
	end
end

local function SetAlpha(unit)
	local db = TidyPlatesThreat.db.profile
	local style, unique_style = SetStyle(unit)

	local alpha = 0
	local nonTargetAlpha = 0

	if db.blizzFadeA.toggle and not unit.isTarget and UnitExists("Target") then
		nonTargetAlpha = db.blizzFadeA.amount
	end

	if style == "unique" or style == "NameOnly-Unique" then
		if not unique_style.overrideAlpha then
			alpha = unique_style.alpha
		elseif db.HeadlineView.useAlpha then
			alpha = GetThreatAlpha(unit)
		else
			alpha = 1
			if db.HeadlineView.blizzFading and not unit.isTarget and UnitExists("Target") then
				nonTargetAlpha = db.HeadlineView.blizzFadingAlpha
			else
				nonTargetAlpha = 1
			end
		end
	elseif style == "empty" then -- etotem alpha will still be at totem level
		alpha = 0
	elseif style == "NameOnly" then
		if db.HeadlineView.useAlpha then
			alpha = GetThreatAlpha(unit)
		else
			alpha = 1 -- ignore all alpha settings for healthbar view
			if db.HeadlineView.blizzFading and not unit.isTarget and UnitExists("Target") then
				nonTargetAlpha = db.HeadlineView.blizzFadingAlpha
			else
				nonTargetAlpha = 1
			end
		end
	else
		alpha = GetThreatAlpha(unit)
	end

	if not alpha then
		alpha = 0
	end
	return alpha + nonTargetAlpha
end

TidyPlatesThreat.SetAlpha = SetAlpha
