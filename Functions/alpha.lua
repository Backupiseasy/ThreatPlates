local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitExists = UnitExists
local InCombatLockdown = InCombatLockdown

local UnitIsOffTanked = TidyPlatesThreat.UnitIsOffTanked
local OnThreatTable = TidyPlatesThreat.OnThreatTable
local GetUniqueNameplateSetting = TidyPlatesThreat.GetUniqueNameplateSetting
local GetSimpleUnitType = TidyPlatesThreat.GetSimpleUnitType
local SetStyle = TidyPlatesThreat.SetStyle

local function GetGeneralAlpha(unit)
	local db = TidyPlatesThreat.db.profile.nameplate

	--local unit_type = GetDetailedUnitType(unit)
	local unit_type = unit.TP_DetailedUnitType
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
		if unit.isMarked and db.toggle.MarkedA then
			alpha = db.alpha.Marked
		elseif unit.isCasting and db.toggle.CastingUnitAlpha then
			alpha = db.alpha.CastingUnit
		elseif unit.isMouseover and db.toggle.MouseoverUnitAlpha then
			alpha = db.alpha.MouseoverUnit
		end
	end
	return alpha
end

local function GetThreatAlpha(unit)

	local db = TidyPlatesThreat.db.profile.threat

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

local function AlphaNormal(unit)
	local db = TidyPlatesThreat.db.profile.blizzFadeA
	local alpha, non_target_alpha = 0, 0

	if db.toggle and not unit.isTarget and UnitExists("Target") then
		non_target_alpha = db.amount
	end

	db = TidyPlatesThreat.db.profile.threat
	if InCombatLockdown() and db.ON and db.useScale then
		-- use general alpha, if threat scaling is disabled for marked units
		if unit.isMarked and db.marked.scale then
			alpha = GetGeneralAlpha(unit)
		else
			local T = GetSimpleUnitType(unit)
			if db.toggle[T] then
				if db.nonCombat then
					if OnThreatTable(unit) then
						alpha = GetThreatAlpha(unit)
					else
						alpha = GetGeneralAlpha(unit)
					end
				else
					alpha = GetThreatAlpha(unit)
				end
			else
				alpha = GetGeneralAlpha(unit)
			end
		end
	else
		alpha = GetGeneralAlpha(unit)
	end

	return alpha, non_target_alpha
end

local function AlphaUnique(unit)
	local db = TidyPlatesThreat.db.profile.blizzFadeA
	local unique_setting = GetUniqueNameplateSetting(unit)
	local alpha, non_target_alpha = 0, 0

	if db.toggle and not unit.isTarget and UnitExists("Target") then
		non_target_alpha = db.amount
	end

	if unique_setting.overrideAlpha then
		alpha = AlphaNormal(unit)
	else
		alpha = unique_setting.alpha
	end

	return alpha, non_target_alpha
end

local function AlphaUniqueNameOnly(unit)
	local db = TidyPlatesThreat.db.profile.HeadlineView
	local unique_setting = GetUniqueNameplateSetting(unit)
	local alpha, non_target_alpha = 0, 0

	if unique_setting.overrideAlpha then
		if db.useAlpha then
			alpha = AlphaNormal(unit)
		end
	else
		alpha = unique_setting.alpha

		if db.blizzFading and not unit.isTarget and UnitExists("Target") then
			non_target_alpha = db.blizzFadingAlpha
		end
	end

	return alpha, non_target_alpha
end

local function AlphaEmpty(unit)
	local db = TidyPlatesThreat.db.profile.blizzFadeA
	local alpha, non_target_alpha = 0, 0

	if db.toggle and not unit.isTarget and UnitExists("Target") then
		non_target_alpha = db.amount
	end

	return alpha, non_target_alpha
end

local function AlphaNameOnly(unit)
	local db = TidyPlatesThreat.db.profile.HeadlineView
	local alpha, non_target_alpha = 0, 0

	if db.useAlpha then
		alpha = AlphaNormal(unit)
	else
		alpha = 1 -- ignore all alpha settings for healthbar view
		if db.blizzFading and not unit.isTarget and UnitExists("Target") then
			non_target_alpha = db.blizzFadingAlpha
		end
	end

	return alpha, non_target_alpha
end

local ALPHA_FUNCTIONS = {
	dps = AlphaNormal,
	tank = AlphaNormal,
	normal = AlphaNormal,
	totem = AlphaNormal,
	unique = AlphaUnique,
	empty = AlphaEmpty,
	etotem = AlphaEmpty,
	NameOnly = AlphaNameOnly,
	["NameOnly-Unique"] = AlphaUniqueNameOnly,
}

local function SetAlpha(unit)
	-- sometimes SetAlpha is called without calling OnUpdate/OnContextUpdate first, so TP_Style may not be initialized
	local style = unit.TP_Style or SetStyle(unit)

	if not style then
		style = SetStyle(unit)
	end

	local alpha, alpha_non_target = ALPHA_FUNCTIONS[style](unit)

	return alpha + alpha_non_target
end

TidyPlatesThreat.SetAlpha = SetAlpha
