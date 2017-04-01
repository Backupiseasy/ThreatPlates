local _, ns = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitIsOffTanked = TidyPlatesThreat.UnitIsOffTanked

local function GetGeneralAlpha(unit)
	local unitType = TidyPlatesThreat.GetType(unit)
	local db = TidyPlatesThreat.db.profile.nameplate
	local alpha = 0

	if unit.isTapped then
		alpha = db.alpha["Tapped"] or 1 --alpha = db.alpha["Tapped"]
	elseif unitType and unitType ~="empty" then
	 	alpha = db.alpha[unitType] or 1 -- This should also return for totems.
	end

	-- Do checks for target settings, must be spelled out to avoid issues
	if (UnitExists("target") and unit.isTarget) and db.toggle.TargetA then
		alpha = db.alpha.Target
	elseif not UnitExists("target") and db.toggle.NoTargetA then
		if unit.isMarked and db.toggle.MarkedA then
			alpha = db.alpha.Marked
		else
			alpha = db.alpha.NoTarget
		end
	else -- Marked units will always be set to this alpha
		if unit.isMarked and db.toggle.MarkedA then
			alpha = db.alpha.Marked
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

	local alpha = 0
	local nonTargetAlpha = 0

	if db.blizzFadeA.toggle and not unit.isTarget and UnitExists("Target") then
		nonTargetAlpha = db.blizzFadeA.amount
	end

	if style == "unique" then
		for k,v in pairs(db.uniqueSettings.list) do
			if v == unit.name then
				if not db.uniqueSettings[k].overrideAlpha then
					alpha = db.uniqueSettings[k].alpha
				else
					alpha = GetThreatAlpha(unit)
				end
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
