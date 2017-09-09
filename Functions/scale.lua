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

local function GetGeneralScale(unit)
	local db = TidyPlatesThreat.db.profile.nameplate

	-- Do checks for target settings, must be spelled out to avoid issues
	local target_exists = UnitExists("target")
	if (target_exists and unit.isTarget) and db.toggle.TargetS then
		return db.scale.Target
	elseif not target_exists and db.toggle.NoTargetS then
		if unit.isMarked and db.toggle.MarkedS then
			return db.scale.Marked
		else
			return db.scale.NoTarget
		end
  end

  -- units will always be set to this scale
  if unit.isMarked and db.toggle.MarkedS then
    return db.scale.Marked
  elseif unit.isMouseover and db.toggle.MouseoverUnitScale then
    return db.scale.MouseoverUnit
  elseif unit.isCasting then
    local unit_friendly = (unit.reaction == "FRIENDLY")
    if unit_friendly and db.toggle.CastingUnitScale then
      return db.scale.CastingUnit
    elseif not unit_friendly and db.toggle.CastingEnemyUnitScale then
      return db.scale.CastingEnemyUnit
    end
  end

  return db.scale[unit.TP_DetailedUnitType] or 1 -- This should also return for totems.
end

local function GetThreatScale(unit)
	local db = TidyPlatesThreat.db.profile.threat

	local threatSituation = unit.threatSituation
	if TidyPlatesThreat:GetSpecRole() then
		if db.toggle.OffTank and UnitIsOffTanked(unit) then
			threatSituation = "OFFTANK"
		end
		return db["tank"].scale[threatSituation]
	else
		return db["dps"].scale[threatSituation]
	end
end

local function ScaleNormal(unit, override_scale)
	local db = TidyPlatesThreat.db.profile.threat

	if InCombatLockdown() and db.ON and db.useScale then
		-- use general scale, if threat scaling is disabled for marked units
		if unit.isMarked and db.marked.scale then
			return override_scale or GetGeneralScale(unit)
		else
			if ShowThreatFeedback(unit) then
				return GetThreatScale(unit)
			end
		end
	end

  return override_scale or GetGeneralScale(unit)
end

local function ScaleUnique(unit)
	local unique_setting = GetUniqueNameplateSetting(unit)

	if unique_setting.overrideScale then
		return  ScaleNormal(unit)
	elseif unique_setting.UseThreatColor then
		return ScaleNormal(unit, unique_setting.scale)
  end

  return unique_setting.scale
end

local function ScaleUniqueNameOnly(unit)
	local db = TidyPlatesThreat.db.profile.HeadlineView
	local unique_setting = GetUniqueNameplateSetting(unit)

	if unique_setting.overrideScale then
		if db.useScaling then
			return ScaleNormal(unit)
		end

		return 1
	elseif unique_setting.UseThreatColor then
		return ScaleNormal(unit, unique_setting.scale)
  end

  return unique_setting.scale
end

local function ScaleEmpty(unit)
	return 0.01
end

local function ScaleNameOnly(unit)
	local db = TidyPlatesThreat.db.profile.HeadlineView

	if db.useScaling then
		return ScaleNormal(unit)
	end

	return 1
end

local SCALE_FUNCTIONS = {
	dps = ScaleNormal,
	tank = ScaleNormal,
	normal = ScaleNormal,
	totem = ScaleNormal,
	unique = ScaleUnique,
	empty = ScaleEmpty,
	etotem = ScaleEmpty,
	NameOnly = ScaleNameOnly,
	["NameOnly-Unique"] = ScaleUniqueNameOnly,
}

local function SetScale(unit)
	-- sometimes SetScale is called without calling OnUpdate/OnContextUpdate first, so TP_Style may not be initialized
	-- true for SetAlpha, not sure for SetScale
	local style = unit.TP_Style or SetStyle(unit)

	--local nonTargetScale = 0
	--if db.blizzFadeS.toggle and not unit.isTarget then
	--nonTargetScale = db.blizzFadeS.amount
	--end

  local scale_func = SCALE_FUNCTIONS[style]
  local scale = scale_func(unit)

	-- scale may be set to 0 in the options dialog
	if scale <= 0 then
		return 0.01
	end

	return scale -- + nonTargetScale
end

TidyPlatesThreat.SetScale = SetScale