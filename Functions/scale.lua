local _, ns = ...
local t = ns.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitIsOffTanked = TidyPlatesThreat.UnitIsOffTanked
local SetStyle = TidyPlatesThreat.SetStyle
local GetDetailedUnitType = TidyPlatesThreat.GetDetailedUnitType

local function GetGeneralScale(unit)
	local db = TidyPlatesThreat.db.profile.nameplate

	local unit_type = GetDetailedUnitType(unit)
  local scale = db.scale[unit_type] or 1 -- This should also return for totems.

	-- Do checks for target settings, must be spelled out to avoid issues
	if (UnitExists("target") and unit.isTarget) and db.toggle.TargetS then
		scale = db.scale.Target
	elseif not UnitExists("target") and db.toggle.NoTargetS then
		if unit.isMarked and db.toggle.MarkedS then
			scale = db.scale.Marked
		else
			scale = db.scale.NoTarget
		end
	else -- units will always be set to this scale
		if unit.isCasting and db.toggle.CastingUnitScale then
			scale = db.scale.CastingUnit
		elseif unit.isMarked and db.toggle.MarkedS then
			scale = db.scale.Marked
    elseif unit.isMouseover and db.toggle.MouseoverUnitScale then
      scale = db.scale.MouseoverUnit
    end
  end
	return scale
end

local function GetThreatScale(unit, style)
	local db = TidyPlatesThreat.db.profile.threat
	if InCombatLockdown() and (db.ON and db.useScale) then
		if unit.isMarked and db.marked.scale then
			return GetGeneralScale(unit)
		else
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
 	else
		return GetGeneralScale(unit)
	end
end

local function SetScale(unit)
	local db = TidyPlatesThreat.db.profile
	local style, unique_style = SetStyle(unit)

	local scale = 0
	local nonTargetScale = 0
	--if db.blizzFadeS.toggle and not unit.isTarget then
		--nonTargetScale = db.blizzFadeS.amount
	--end

	if style == "unique" or style == "NameOnly-Unique" then
    if not unique_style.overrideScale then
			scale = unique_style.scale
		elseif db.HeadlineView.useScaling then
			scale = GetThreatScale(unit)
		else
			scale = 1
		end
	elseif style == "empty" then -- etotem scale will still be at totem level
		scale = 0
	elseif style == "NameOnly" then
		if db.HeadlineView.useScaling then
			scale = GetThreatScale(unit)
		else
			scale = 1
		end
	else
		scale = GetThreatScale(unit)
	end

	if scale <= 0 then
		scale = 0.01
	end
	return scale -- + nonTargetScale
end

TidyPlatesThreat.SetScale = SetScale
