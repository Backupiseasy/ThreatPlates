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

---------------------------------------------------------------------------------------------------
-- Functions handling transparency of nameplates
---------------------------------------------------------------------------------------------------

local function TransparencySituational(unit)
	local db = TidyPlatesThreat.db.profile.nameplate

	-- Do checks for situational transparency settings:
	if unit.isMarked and db.toggle.MarkedA then
		return db.alpha.Marked
	elseif unit.isMouseover and not unit.isTarget and db.toggle.MouseoverUnitAlpha then
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
  -- Target always has priority
  if not unit.isTarget then
    -- Do checks for situational transparency settings:
    local tranparency = TransparencySituational(unit)
    if tranparency then
      return tranparency
    end
  end

	-- Do checks for target settings:
	local db = TidyPlatesThreat.db.profile.nameplate

  local target_alpha
	if UnitExists("target") then
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

	local threatSituation = GetThreatSituation(unit, style, db.toggle.OffTank)
	if db.AdditiveAlpha then
		return db[style].alpha[threatSituation] + TransparencyGeneral(unit) - 1
	end

  return db[style].alpha[threatSituation]
end

local function AlphaNormal(unit, non_combat_transparency)
  local style = Addon:GetThreatStyle(unit)
  if style == "normal" then
    return non_combat_transparency or TransparencyGeneral(unit)
  else -- dps, tank
    return TransparencyThreat(unit, style)
  end
end

local function AlphaUnique(unit)
	local unique_setting = unit.CustomPlateSettings

	if unique_setting.overrideAlpha then
		return AlphaNormal(unit)
	elseif unique_setting.UseThreatColor then
    return AlphaNormal(unit, unique_setting.alpha)
  end

  return unique_setting.alpha
end

local function AlphaUniqueNameOnly(unit)
	local unique_setting = unit.CustomPlateSettings

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
	etotem = TransparencyGeneral,
	NameOnly = TransparencyNameOnly,
	["NameOnly-Unique"] = AlphaUniqueNameOnly,
}

function Addon:GetAlpha(unit)
  return ALPHA_FUNCTIONS[unit.style](unit, unit.style)
end


