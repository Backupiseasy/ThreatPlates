---------------------------------------------------------------------------------------------------
-- Module: Scaling
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local UnitExists = UnitExists

-- ThreatPlates APIs
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish
local Style = Addon.Style
local TransparencyModule, ScalingModule = Addon.Transparency, Addon.Scaling
local AnimationScalePlate, AnimationStopScale, AnimationHidePlate = Addon.Animation.ScalePlate, Addon.Animation.StopScale, Addon.Animation.HidePlate
local CVars = Addon.CVars
local MathClamp = Addon.Clamp

---------------------------------------------------------------------------------------------------
-- Module Setup
---------------------------------------------------------------------------------------------------
local ScalingModule = Addon.Scaling

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local ScalePlate

---------------------------------------------------------------------------------------------------
-- Cached configuration settings (for performance reasons)
---------------------------------------------------------------------------------------------------
local Settings

-- Cached CVARs
local AnimateHideNameplate, CVAR_nameplateMinAlpha, CVAR_nameplateMinScale

local function ScaleSituational(unit)
	local db = Addon.db.profile.nameplate

	-- Do checks for situational scale settings:
	if unit.TargetMarkerIcon and db.toggle.MarkedS then
		return db.scale.Marked
	elseif unit.isMouseover and not Addon.UnitIsTarget(unit.unitid) and db.toggle.MouseoverUnitScale then
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
	if not Addon.UnitIsTarget(unit.unitid) then
		-- Do checks for situational scale settings:
		local scale = ScaleSituational(unit)
		if scale then
			return scale
		end
	end

	-- Do checks for target settings:
	local db = Addon.db.profile.nameplate

	local target_scale
	if Addon.TargetUnitExists() then
		local unit_is_target = Addon.UnitIsTarget(unit.unitid)
		if unit_is_target and db.toggle.TargetS then
			target_scale = db.scale.Target
		elseif not unit_is_target and db.toggle.NonTargetS then
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
	local db = Addon.db.profile.threat

	if not db.useScale then
		return ScaleGeneral(unit)
	end

	if db.marked.scale then
		local scale = ScaleSituational(unit)
		if scale then
			return scale
		end
	end

	local scale = db[style].scale[unit.ThreatLevel]

	if db.AdditiveScale then
		scale = scale + ScaleGeneral(unit)
	end

	return scale
end

local function ScaleNormal(unit, non_combat_scale)
	local style = Style:GetThreatStyle(unit)
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
		local db = Addon.db.profile.HeadlineView
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
	local db = Addon.db.profile.HeadlineView

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

local function GetScale(unit)
	local scale = SCALE_FUNCTIONS[unit.style](unit, unit.style)
	-- scale may be set to 0 in the options dialog
	return MathClamp(scale, 0.3, scale)
end

local function ScalePlateWithAnimation(frame, scale)
	AnimationScalePlate(frame, scale)
end

local function ScalePlateWithoutAnimation(frame, scale)
	frame:SetScale(scale)
end

function ScalingModule.UpdateStyle(tp_frame)
  tp_frame.HidingScale = nil

	AnimationStopScale(tp_frame)
	tp_frame:SetScale(Addon.UIScale * GetScale(tp_frame.unit))
end

function ScalingModule.HideNameplate(tp_frame)
  if AnimateHideNameplate then
		local scale = tp_frame.Parent:GetScale()
    if scale < CVAR_nameplateMinScale then
      if not tp_frame.HidingScale then
        AnimationHidePlate(tp_frame)
        tp_frame.HidingScale = scale + 0.01
      end

      if scale < tp_frame.HidingScale then
        tp_frame.HidingScale = scale
      elseif tp_frame.HidingScale ~= -1 then
        -- Scale down stoppted and reversed - plate is no longer hiding
				TransparencyModule.UpdateStyle(tp_frame)
				ScalingModule.UpdateStyle(tp_frame)
        tp_frame.HidingScale = -1
      end
    else -- scale >= CVAR_nameplateMinScale
      tp_frame.HidingScale = nil
    end
  end
end

function ScalingModule.UpdateSettings()
	Settings = Addon.db.profile.Animations

	if Settings.ScaleToDuration > 0 then
		ScalePlate = ScalePlateWithAnimation
	else
		ScalePlate = ScalePlateWithoutAnimation
	end

  if Settings.HidePlateDuration > 0 and (Settings.HidePlateFadeOut or Settings.HidePlateScaleDown) then
    if CVars.InvalidCVarsForHidingNameplates() then
      AnimateHideNameplate = false
    else
      AnimateHideNameplate = true
      CVAR_nameplateMinScale = CVars:GetAsNumber("nameplateMinScale") * CVars:GetAsNumber("nameplateGlobalScale")
      CVAR_nameplateMinAlpha = CVars:GetAsNumber("nameplateMinAlpha")
    end
  else
    AnimateHideNameplate = false
  end
end

function ScalingModule.HidingNameplatesIsEnabled()
	return AnimateHideNameplate
end

---------------------------------------------------------------------------------------------------
-- React to events that could change the nameplate scale/size
---------------------------------------------------------------------------------------------------

local function SituationalEvent(tp_frame)
	ScalePlate(tp_frame, Addon.UIScale * GetScale(tp_frame.unit))
end

-- Update the target unit and all non-target units
local function TargetGained(tp_frame)
  local ui_scale = Addon.UIScale

  -- Update the nameplate of the current target unit
	ScalePlate(tp_frame, ui_scale * GetScale(tp_frame.unit))

  local db = Addon.db.profile.nameplate
  if db.toggle.NonTargetS then
    -- Update all non-target units
		for _, active_tp_frame in Addon:GetActiveThreatPlates() do
      if not Addon.UnitIsTarget(active_tp_frame.unit.unitid) then
				ScalePlate(active_tp_frame, ui_scale * GetScale(active_tp_frame.unit))
      end
		end
  end
end

-- Update all units unless there is a new target unit (TargetGained will be called then anyway)
local function TargetLost(tp_frame)
  local ui_scale = Addon.UIScale

  -- Update the nameplate of the unit that lost the target
	ScalePlate(tp_frame, ui_scale * GetScale(tp_frame.unit))

  if UnitExists("target") then return end

  -- Update all units as there is no target now (except the unit that lost the target as it was already updated above
  for _, active_tp_frame in Addon:GetActiveThreatPlates() do
    if active_tp_frame ~= tp_frame then
			ScalePlate(active_tp_frame, ui_scale * GetScale(active_tp_frame.unit))
    end
  end
end

SubscribeEvent(ScalingModule, "MouseoverOnEnter", SituationalEvent)
SubscribeEvent(ScalingModule, "MouseoverOnLeave", SituationalEvent)
SubscribeEvent(ScalingModule, "CastingStarted", SituationalEvent)
SubscribeEvent(ScalingModule, "CastingStopped", SituationalEvent)
SubscribeEvent(ScalingModule, "TargetMarkerUpdate", SituationalEvent)
SubscribeEvent(ScalingModule, "TargetGained", TargetGained)
SubscribeEvent(ScalingModule, "TargetLost", TargetLost)
SubscribeEvent(ScalingModule, "FactionUpdate", SituationalEvent)
SubscribeEvent(ScalingModule, "ThreatUpdate", SituationalEvent)