local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

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
local SetStyle = TidyPlatesThreat.SetStyle
local GetThreatStyle = ThreatPlates.GetThreatStyle

local function TransparencySituational(unit)
	local db = TidyPlatesThreat.db.profile.nameplate

	-- Do checks for situational transparency settings:
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

	return nil
end

local function TransparencyGeneral(unit)
	-- Do checks for situational transparency settings:
	local tranparency = TransparencySituational(unit)
	if tranparency then
		return tranparency
  end

	-- Do checks for target settings:
	local db = TidyPlatesThreat.db.profile.nameplate
	local target_exists = UnitExists("target")

	local target_alpha
	if target_exists then
		if unit.isTarget and db.toggle.TargetA then
			target_alpha = db.alpha.Target
		elseif not unit.isTarget and db.toggle.NonTargetA then
				target_alpha = db.alpha.NonTarget
		end
	elseif db.toggle.NoTargetA then
		target_alpha = db.alpha.NoTarget
	end

	if target_alpha then
		--if db.alpha.AddTargetAlpha then
    if db.alpha.AbsoluteTargetAlpha then
			-- units will always be set to this alpha
      return target_alpha
    end

    return (db.alpha[unit.TP_DetailedUnitType] or 1) + target_alpha - 1
  end

	return db.alpha[unit.TP_DetailedUnitType] or 1
end

local function TransparencyThreat(unit, style)
	local db = TidyPlatesThreat.db.profile.threat

	if not db.useAlpha then
		return TransparencyGeneral(unit)
	end

	if db.marked.alpha then
		local tranparency = TransparencySituational(unit)
		if tranparency then
			return tranparency
		end
	end

  local threatSituation = unit.threatSituation
  if style == "tank" and db.toggle.OffTank and UnitIsOffTanked(unit) then
    threatSituation = "OFFTANK"
	end

	if db.AdditiveAlpha then
		return db[style].alpha[threatSituation] + TransparencyGeneral(unit) - 1
	end

  return db[style].alpha[threatSituation]
end

local function AlphaNormal(unit, non_combat_transparency)
  local style = GetThreatStyle(unit)
  if style == "normal" then
    return non_combat_transparency or TransparencyGeneral(unit)
  else -- dps, tank
    return TransparencyThreat(unit, style)
  end
end

local function AlphaUnique(unit)
	local unique_setting = GetUniqueNameplateSetting(unit)

	if unique_setting.overrideAlpha then
		return AlphaNormal(unit)
	elseif unique_setting.UseThreatColor then
    return AlphaNormal(unit, unique_setting.alpha)
  end

  return unique_setting.alpha
end

local function AlphaUniqueNameOnly(unit)
	local unique_setting = GetUniqueNameplateSetting(unit)

  if unique_setting.overrideAlpha then
    local db = TidyPlatesThreat.db.profile.HeadlineView
    if db.useAlpha then
			return AlphaNormal(unit)
    end

    return 1
	elseif unique_setting.UseThreatColor then
    return AlphaNormal(unit, unique_setting.alpha)
  end

  return unique_setting.alpha
end

local function TransparencyEmpty(unit)
	return 0
end

local function TransparencyNameOnly(unit)
	local db = TidyPlatesThreat.db.profile.HeadlineView

	if db.useAlpha then
    return AlphaNormal(unit)
  end

	return 1
end

local ALPHA_FUNCTIONS = {
	dps = TransparencyThreat,
	tank = TransparencyThreat,
	normal = TransparencyGeneral,
	totem = TransparencyGeneral,
	unique = AlphaUnique,
	empty = TransparencyEmpty,
	etotem = TransparencyEmpty,
	NameOnly = TransparencyNameOnly,
	["NameOnly-Unique"] = AlphaUniqueNameOnly,
}

local function SetAlpha(unit)
	-- sometimes SetAlpha is called without calling OnUpdate/OnContextUpdate first, so TP_Style may not be initialized
	local style = unit.TP_Style or SetStyle(unit)

  local alpha_func = ALPHA_FUNCTIONS[style]

  local alpha = alpha_func(unit, style)
  -- There is a bug in TidyPlates which hides the nameplate forever if alpha is set to 0 at some point
  if alpha <= 0 then
    return 0.01
  end

  return alpha
end

TidyPlatesThreat.SetAlpha = SetAlpha
