local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local UnitExists = UnitExists

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local UnitIsOffTanked = ThreatPlates.UnitIsOffTanked
local GetUniqueNameplateSetting = ThreatPlates.GetUniqueNameplateSetting
local GetThreatStyle = ThreatPlates.GetThreatStyle

local function ScaleSituational(unit)
	local db = TidyPlatesThreat.db.profile.nameplate

	-- Do checks for situational scale settings:
	if unit.isMarked and db.toggle.MarkedS then
		return db.scale.Marked
	elseif unit.isMouseover and not unit.isTarget and db.toggle.MouseoverUnitScale then
		return db.scale.MouseoverUnit
	elseif unit.isCasting then
		local unit_friendly = (unit.reaction == "FRIENDLY")
		if unit_friendly and db.toggle.CastingUnitScale then
			return db.scale.CastingUnit
		elseif not unit_friendly and db.toggle.CastingEnemyUnitScale then
			return db.scale.CastingEnemyUnit
		end
	end

	return nil
end

local function ScaleGeneral(unit)
	-- Target always has priority
	if not unit.isTarget then
		-- Do checks for situational scale settings:
		local scale = ScaleSituational(unit)
		if scale then
			return scale
		end
	end

	-- Do checks for target settings:
	local db = TidyPlatesThreat.db.profile.nameplate

	local target_scale
	if UnitExists("target") then
		if unit.isTarget and db.toggle.TargetS then
			target_scale = db.scale.Target
		elseif not unit.isTarget and db.toggle.NonTargetS then
			target_scale = db.scale.NonTarget
		end
	elseif db.toggle.NoTargetS then
		target_scale = db.scale.NoTarget
  end

	if target_scale then
		--if db.alpha.AddTargetAlpha then
		if db.scale.AbsoluteTargetScale then
			-- units will always be set to this alpha
			return target_scale
		end

		--return (db.scale[unit.TP_DetailedUnitType] or 1) + target_scale - 1
		return (db.scale[unit.TP_DetailedUnitType] or 1) + target_scale
	end

  return db.scale[unit.TP_DetailedUnitType] or 1 -- This should also return for totems.
end

local function ScaleThreat(unit, style)
	local db = TidyPlatesThreat.db.profile.threat

	if not db.useScale then
		return ScaleGeneral(unit)
	end

	if db.marked.scale then
		local scale = ScaleSituational(unit)
		if scale then
			return scale
		end
	end

	local threatSituation = unit.threatSituation
	if style == "tank" and db.toggle.OffTank and UnitIsOffTanked(unit) then
		threatSituation = "OFFTANK"
	end

	if db.AdditiveScale then
		return db[style].scale[threatSituation] + ScaleGeneral(unit)
	end

	return db[style].scale[threatSituation]
end

local function ScaleNormal(unit, non_combat_scale)
	local style = GetThreatStyle(unit)
	if style == "normal" then
		return non_combat_scale or ScaleGeneral(unit)
	else -- dps, tank
		return ScaleGeneral(unit, style)
	end
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
	local unique_setting = GetUniqueNameplateSetting(unit)

	if unique_setting.overrideScale then
		local db = TidyPlatesThreat.db.profile.HeadlineView
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
	return 0
end

local function ScaleNameOnly(unit)
	local db = TidyPlatesThreat.db.profile.HeadlineView

	if db.useScaling then
		return ScaleNormal(unit)
	end

	return 1
end

local SCALE_FUNCTIONS = {
	dps = ScaleThreat,
	tank = ScaleThreat,
	normal = ScaleGeneral,
	totem = ScaleGeneral,
	unique = ScaleUnique,
	empty = ScaleEmpty,
	etotem = ScaleGeneral,
	NameOnly = ScaleNameOnly,
	["NameOnly-Unique"] = ScaleUniqueNameOnly,
}

function Addon:SetScale(unit)
	if not unit.unitid then return 1 end -- unitid is used in UnitIsOffTanked

	-- sometimes SetScale is called without calling OnUpdate/OnContextUpdate first, so TP_Style may not be initialized
	-- true for SetAlpha, not sure for SetScale
	local style = unit.TP_Style or Addon:SetStyle(unit)

  local scale_func = SCALE_FUNCTIONS[style]

  local scale = scale_func(unit, style)

	-- scale may be set to 0 in the options dialog
	if scale < 0.3 then
		return 0.3
	end

	return scale
end
