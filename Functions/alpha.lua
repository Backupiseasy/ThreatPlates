local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitExists = UnitExists
local InCombatLockdown = InCombatLockdown

local TidyPlatesThreat = TidyPlatesThreat
local UnitIsOffTanked = ThreatPlates.UnitIsOffTanked
local GetUniqueNameplateSetting = ThreatPlates.GetUniqueNameplateSetting
local ShowThreatFeedback = ThreatPlates.ShowThreatFeedback
local SetStyle = TidyPlatesThreat.SetStyle

local function GetGeneralAlpha(unit)
	local db = TidyPlatesThreat.db.profile.nameplate


	-- Do checks for target settings, must be spelled out to avoid issues
	local target_exists = UnitExists("target")
	if (target_exists and unit.isTarget) and db.toggle.TargetA then
		return db.alpha.Target
	elseif not target_exists and db.toggle.NoTargetA then
		if unit.isMarked and db.toggle.MarkedA then
			return db.alpha.Marked
		else
			return db.alpha.NoTarget
    end
  end

  -- units will always be set to this alpha
  if unit.isMarked and db.toggle.MarkedA then
    return db.alpha.Marked
  elseif unit.isMouseover and db.toggle.MouseoverUnitAlpha then
    return db.alpha.MouseoverUnit
  elseif unit.isCasting then
    local unit_friendly = (unit.reaction == "FRIENDLY")
    if unit_friendly and db.toggle.CastingUnitAlpha then
      return db.alpha.CastingUnit
    elseif not unit_friendly and db.toggle.CastingEnemyUnitAlpha then
      return db.alpha.CastingEnemyUnit
    end
  end

	return db.alpha[unit.TP_DetailedUnitType] or 1 -- This should also return for totems.
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

local function AlphaNormal(unit, override_alpha)
	local db = TidyPlatesThreat.db.profile.blizzFadeA

	local non_target_alpha = 0
	if db.toggle and not unit.isTarget and UnitExists("Target") then
		non_target_alpha = db.amount
	end

	db = TidyPlatesThreat.db.profile.threat
	if InCombatLockdown() and db.ON and db.useAlpha then
		-- use general alpha, if threat scaling is disabled for marked units
		if unit.isMarked and db.marked.alpha then
			return override_alpha or GetGeneralAlpha(unit), non_target_alpha
		else
			if ShowThreatFeedback(unit) then
				return GetThreatAlpha(unit), non_target_alpha
			end
		end
  end

  return override_alpha or GetGeneralAlpha(unit), non_target_alpha
end

local function AlphaUnique(unit)
	local unique_setting = GetUniqueNameplateSetting(unit)

	if unique_setting.overrideAlpha then
		return AlphaNormal(unit)
	elseif unique_setting.UseThreatColor then
    local alpha, _ = AlphaNormal(unit, unique_setting.alpha)
		return alpha, 0
  end

  return unique_setting.alpha, 0
end

local function AlphaUniqueNameOnly(unit)
	local db = TidyPlatesThreat.db.profile.HeadlineView
	local unique_setting = GetUniqueNameplateSetting(unit)

	if unique_setting.overrideAlpha then
		if db.useAlpha then
			return AlphaNormal(unit)
    end

    -- ignore all alpha settings for healthbar view
    if db.blizzFading and not unit.isTarget and UnitExists("Target") then
      return 1, db.blizzFadingAlpha
    end

    return 1, 0
	elseif unique_setting.UseThreatColor then
    local alpha, _ = AlphaNormal(unit, unique_setting.alpha)
    return alpha, 0
  end

  return unique_setting.alpha, 0
end

local function AlphaEmpty(unit)
	return 0, 0
end

local function AlphaNameOnly(unit)
	local db = TidyPlatesThreat.db.profile.HeadlineView

	if db.useAlpha then
		return AlphaNormal(unit)
  end

  -- ignore all alpha settings for healthbar view
  if db.blizzFading and not unit.isTarget and UnitExists("Target") then
    return 1, db.blizzFadingAlpha
  end

	return 1, 0
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

  local alpha_func = ALPHA_FUNCTIONS[style]
	local alpha, alpha_non_target = alpha_func(unit)

	return alpha + alpha_non_target
end

TidyPlatesThreat.SetAlpha = SetAlpha
