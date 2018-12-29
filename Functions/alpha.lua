local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs = pairs

-- WoW APIs
local UnitExists = UnitExists

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local PlatesByUnit = Addon.PlatesByUnit
local PlayerRoleIsTank = Addon.PlayerRoleIsTank
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------
local Element = "Transparency"

---------------------------------------------------------------------------------------------------
-- Functions handling transparency of nameplates
---------------------------------------------------------------------------------------------------

local function TransparencySituational(unit)
	local db = TidyPlatesThreat.db.profile.nameplate

	-- Do checks for situational transparency settings:
	if unit.TargetMarker and db.toggle.MarkedA then
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

  local threatSituation = unit.ThreatLevel or "LOW"
	local style = (PlayerRoleIsTank() and "tank") or "dps"

  if style == "tank" and db.toggle.OffTank and Addon:UnitIsOffTanked(unit) then
    threatSituation = "OFFTANK"
	end

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

-- TODO: Better integrate this with occlusion transparency
-- Move UpdatePlate_SetAlpha to this file
local function SituationalEvent(tp_frame)
  if not tp_frame:IsShown() or (tp_frame.IsOccluded and not tp_frame.unit.isTarget) then
    return
  end

  local target_alpha = Addon:GetAlpha(tp_frame.unit)

	if target_alpha ~= tp_frame.CurrentAlpha then
		tp_frame:SetAlpha(target_alpha)
		tp_frame.CurrentAlpha = target_alpha
	end
end

-- Update the target unit and all non-target units
local function TargetGained(tp_frame)
  -- Update the nameplate of the current target unit
  SituationalEvent(tp_frame)

  local db = TidyPlatesThreat.db.profile.nameplate
  if db.toggle.NonTargetA then
    -- Update all non-target units
    for _, frame in pairs(PlatesByUnit) do
      if not frame.unit.isTarget and frame.Active then
        SituationalEvent(frame)
      end
    end
  end
end

-- Update all units unless there is a new target unit (TargetGained will be called then anyway)
local function TargetLost(tp_frame)
  -- Update the nameplate of the unit that lost the target
  SituationalEvent(tp_frame)

  if UnitExists("target") then return end

  -- Update all units as there is no target now (except the unit that lost the target as it was already updated above
  for _, frame in pairs(PlatesByUnit) do
    if frame ~= tp_frame and frame.Active then
      SituationalEvent(frame)
    end
  end
end

SubscribeEvent(Element, "MouseoverOnEnter", SituationalEvent)
SubscribeEvent(Element, "MouseoverOnLeave", SituationalEvent)
SubscribeEvent(Element, "CastingStarted", SituationalEvent)
SubscribeEvent(Element, "CastingStopped", SituationalEvent)
SubscribeEvent(Element, "TargetMarkerUpdate", SituationalEvent)
SubscribeEvent(Element, "TargetGained", TargetGained)
SubscribeEvent(Element, "TargetLost", TargetLost)
SubscribeEvent(Element, "FactionUpdate", SituationalEvent)
SubscribeEvent(Element, "ThreatUpdate", SituationalEvent)
