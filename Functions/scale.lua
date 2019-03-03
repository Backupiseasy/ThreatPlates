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
local GetThreatSituation = Addon.GetThreatSituation

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

	local threatSituation = GetThreatSituation(unit, style, db.toggle.OffTank)
	if db.AdditiveScale then
		return db[style].scale[threatSituation] + ScaleGeneral(unit)
	end

	return db[style].scale[threatSituation]
end

local function ScaleNormal(unit, non_combat_scale)
	local style = Addon:GetThreatStyle(unit)
	if style == "normal" then
		return non_combat_scale or ScaleGeneral(unit)
	else -- dps, tank
		return ScaleGeneral(unit, style)
	end
end

local function ScaleUnique(unit)
	local unique_setting = unit.CustomPlateSettings

	if unique_setting.overrideScale then
		return  ScaleNormal(unit)
	elseif unique_setting.UseThreatColor then
		return ScaleNormal(unit, unique_setting.scale)
  end

  return unique_setting.scale
end

local function ScaleUniqueNameOnly(unit)
	local unique_setting = unit.CustomPlateSettings

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
  local scale = SCALE_FUNCTIONS[unit.style](unit, unit.style)

	-- scale may be set to 0 in the options dialog
	if scale < 0.3 then
		return 0.3
	end

	return scale
end
