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

	--local unit_type = GetDetailedUnitType(unit)
	local unit_type = unit.TP_DetailedUnitType
  local scale = db.scale[unit_type] or 1 -- This should also return for totems.

	-- Do checks for target settings, must be spelled out to avoid issues
	local target_exists = UnitExists("target")
	if (target_exists and unit.isTarget) and db.toggle.TargetS then
		scale = db.scale.Target
	elseif not target_exists and db.toggle.NoTargetS then
		if unit.isMarked and db.toggle.MarkedS then
			scale = db.scale.Marked
		else
			scale = db.scale.NoTarget
		end
	else -- units will always be set to this scale
		if unit.isMarked and db.toggle.MarkedS then
			scale = db.scale.Marked
		elseif unit.isCasting and db.toggle.CastingUnitScale then
			scale = db.scale.CastingUnit
    elseif unit.isMouseover and db.toggle.MouseoverUnitScale then
      scale = db.scale.MouseoverUnit
    end
  end
	return scale
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
	local scale

	if InCombatLockdown() and db.ON and db.useScale then
		-- use general scale, if threat scaling is disabled for marked units
		if unit.isMarked and db.marked.scale then
			scale = override_scale or GetGeneralScale(unit)
		else
			if ShowThreatFeedback(unit) then
				scale = GetThreatScale(unit)
			else
				scale = override_scale or GetGeneralScale(unit)
			end
		end
 	else
		scale = override_scale or GetGeneralScale(unit)
	end

	return scale
end

local function ScaleUnique(unit)
	local unique_setting = GetUniqueNameplateSetting(unit)
	local scale

	if unique_setting.overrideScale then
		scale = ScaleNormal(unit)
	elseif unique_setting.UseThreatColor then
		scale = ScaleNormal(unit, unique_setting.scale)
	else
		scale = unique_setting.scale
	end

	return scale
end

local function ScaleUniqueNameOnly(unit)
	local db = TidyPlatesThreat.db.profile.HeadlineView
	local unique_setting = GetUniqueNameplateSetting(unit)
	local scale = 1

	if unique_setting.overrideScale then
		if db.useScaling then
			scale = ScaleNormal(unit)
		end
	elseif unique_setting.UseThreatColor then
		scale = ScaleNormal(unit, unique_setting.scale)
	else
		scale = unique_setting.scale
	end

	return scale
end

local function ScaleEmpty(unit)
	return 0.01
end

local function ScaleNameOnly(unit)
	local db = TidyPlatesThreat.db.profile.HeadlineView
	local scale = 1

	if db.useScaling then
		scale = ScaleNormal(unit)
	end

	return scale
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

	local scale = SCALE_FUNCTIONS[style](unit)

	-- scale may be set to 0 in the options dialog
	if scale <= 0 then
		scale = 0.01
	end

	return scale -- + nonTargetScale
end

TidyPlatesThreat.SetScale = SetScale