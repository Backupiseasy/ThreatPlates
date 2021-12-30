local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs, tonumber = pairs, tonumber

-- WoW APIs
local UnitExists = UnitExists
local GetCVar = GetCVar

-- ThreatPlates APIs
local TidyPlatesThreat, ThreatPlates = TidyPlatesThreat, Addon.ThreatPlates
local Animations = Addon.Animations
local Transparency = Addon.Transparency
local GetThreatLevel = Addon.GetThreatLevel
local PlatesByUnit = Addon.PlatesByUnit
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish
local L = Addon.L
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local UpdatePlate_SetAlpha, UpdatePlate_InitializeAlpha, UpdatePlate_Transparency

---------------------------------------------------------------------------------------------------
-- Cached configuration settings (for performance reasons)
---------------------------------------------------------------------------------------------------
local Settings, FadingIsEnabled
local SettingsOccludedAlpha, SettingsEnabledOccludedAlpha, FadeInOccludedUnitsIsEnabled, FadeOutOccludedUnitsIsEnabled
-- Cached CVARs
local CVAR_NameplateOccludedAlphaMult

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
		local transparency = TransparencySituational(unit)
		if transparency then
			return transparency
		end
	end

  local alpha = db[style].alpha[GetThreatLevel(unit, style, db.toggle.OffTank)]

  if db.AdditiveAlpha then
    alpha = alpha + TransparencyGeneral(unit) - 1
  end

  return alpha
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

local function GetTransparency(unit)
  return ALPHA_FUNCTIONS[unit.style](unit, unit.style)
end

local function UpdatePlate_SetAlphaWithFading(tp_frame, unit)
  local target_alpha = GetTransparency(unit)

  if target_alpha ~= tp_frame.CurrentAlpha then
    Animations:FadePlate(tp_frame, target_alpha)
    tp_frame.CurrentAlpha = target_alpha
  end
end

-- local function UpdatePlate_InitializeAlphaWithFading(tp_frame, unit)
--   local target_alpha = GetTransparency(unit)

--   Animations:ShowPlate(tp_frame, target_alpha)
--   --tp_frame.CurrentAlpha = target_alpha
-- end

local function UpdatePlate_SetAlphaNoFading(tp_frame, unit)
  local target_alpha = GetTransparency(unit)

  if target_alpha ~= tp_frame.CurrentAlpha then
    tp_frame:SetAlpha(target_alpha)
    tp_frame.CurrentAlpha = target_alpha
  end
end

local	function UpdatePlate_SetAlphaWithOcclusion(tp_frame, unit)
  if not tp_frame:IsShown() or (tp_frame.IsOccluded and not unit.isTarget) then
    return
  end

  UpdatePlate_SetAlpha(tp_frame, unit)
end

local function SetOccludedTransparencyWithFadingOnUpdate(self, frame)
  if not SettingsEnabledOccludedAlpha then return end

  local target_alpha
  local plate_alpha = frame.Parent:GetAlpha()
  local unit_was_occluded = false

  if plate_alpha < (CVAR_NameplateOccludedAlphaMult + 0.05) then
    frame.IsOccluded = true
    target_alpha = SettingsOccludedAlpha
  -- elseif frame.IsOccluded or not frame.CurrentAlpha then
    -- unit_was_occluded = frame.IsOccluded
    -- frame.IsOccluded = false
    -- target_alpha = GetTransparency(frame.unit)

  -- plate_alpha >= (CVAR_NameplateOccludedAlphaMult + 0.05)
  elseif frame.IsOccluded then
    frame.IsOccluded = false
    unit_was_occluded = true
    target_alpha = GetTransparency(frame.unit)
  -- elseif not frame.CurrentAlpha then
  --   frame.IsOccluded = false
  --   unit_was_occluded = false
  --   target_alpha = GetTransparency(frame.unit)
  end

  if target_alpha and target_alpha ~= frame.CurrentAlpha then
    if (frame.IsOccluded and not FadeOutOccludedUnitsIsEnabled) or (unit_was_occluded and not FadeInOccludedUnitsIsEnabled) then
      Animations:StopFade(frame)
      frame:SetAlpha(target_alpha)
      frame.IsShowing = false
    elseif frame.IsShowing then
      Animations:StopFade(frame)
      frame:SetAlpha(target_alpha)

      -- Disable showing only if plate is not occluded at least once
      if unit_was_occluded then
        frame.IsShowing = false
      end
    else
      Animations:FadePlate(frame, target_alpha)
      frame.IsShowing = false
    end

    frame.CurrentAlpha = target_alpha
  end
end

local function SetOccludedTransparencyWithoutFadingOnUpdate(self, frame)
  if not SettingsEnabledOccludedAlpha then return end

  local target_alpha
  local plate_alpha = frame.Parent:GetAlpha()

  if plate_alpha < (CVAR_NameplateOccludedAlphaMult + 0.05) then
    frame.IsOccluded = true
    target_alpha = SettingsOccludedAlpha
  elseif frame.IsOccluded or not frame.CurrentAlpha then
    frame.IsOccluded = false
    target_alpha = GetTransparency(frame.unit)
  end

  if target_alpha and target_alpha ~= frame.CurrentAlpha then
    frame:SetAlpha(target_alpha)
    frame.CurrentAlpha = target_alpha
  end
end

function Transparency:Initialize(frame)
  Animations:StopFade(frame)
  frame:SetAlpha(0)

  frame.CurrentAlpha = nil
  frame.IsOccluded = false
  frame.IsShowing = true

  -- Plate is not yet shown here and not yet occluded, so adjust the alpha with or without fading
  UpdatePlate_InitializeAlpha(frame, frame.unit)
  -- Also initialize occlusion here to avoid a short flicker of the nameplate if occlusion is enabled
  SetOccludedTransparencyWithoutFadingOnUpdate(Transparency, frame)
end

function Transparency:UpdateSettings()
  Settings = TidyPlatesThreat.db.profile

  CVAR_NameplateOccludedAlphaMult = tonumber(GetCVar("nameplateOccludedAlphaMult"))

  FadingIsEnabled = Settings.Animations.FadeToDuration > 0

  UpdatePlate_InitializeAlpha = UpdatePlate_SetAlphaNoFading
  if FadingIsEnabled then
    UpdatePlate_SetAlpha = UpdatePlate_SetAlphaWithFading
    --UpdatePlate_InitializeAlpha = UpdatePlate_InitializeAlphaWithFading
    Transparency.SetOccludedTransparency = SetOccludedTransparencyWithFadingOnUpdate
  else
    UpdatePlate_SetAlpha = UpdatePlate_SetAlphaNoFading
    --UpdatePlate_InitializeAlpha = UpdatePlate_SetAlphaNoFading
    Transparency.SetOccludedTransparency = SetOccludedTransparencyWithoutFadingOnUpdate
  end

  SettingsEnabledOccludedAlpha = Settings.nameplate.toggle.OccludedUnits
  SettingsOccludedAlpha = Settings.nameplate.alpha.OccludedUnits

  if SettingsEnabledOccludedAlpha then
    if Addon.CVars.InvalidCVarsForOcclusionDetection() then
      SettingsEnabledOccludedAlpha = false
      UpdatePlate_Transparency = UpdatePlate_SetAlpha
      ThreatPlates.Print(L["Transparency for occluded units is being disabled as certain console variables (CVars) related to nameplate transparency are set in a way to prevent this feature from working."], true)
    else
      UpdatePlate_Transparency = UpdatePlate_SetAlphaWithOcclusion
    end
  else
    UpdatePlate_Transparency = UpdatePlate_SetAlpha
  end

  FadeInOccludedUnitsIsEnabled = Settings.Animations.FadeInOccludedUnits
  FadeOutOccludedUnitsIsEnabled = Settings.Animations.FadeOutOccludedUnits
end

function Transparency:OcclusionDetectionIsEnabled()
	return SettingsEnabledOccludedAlpha
end

---------------------------------------------------------------------------------------------------
-- React to events that could change the nameplate scale/size
---------------------------------------------------------------------------------------------------

-- Move UpdatePlate_SetAlpha to this file
local function SituationalEvent(tp_frame)
  if not tp_frame:IsShown() or (tp_frame.IsOccluded and not tp_frame.unit.isTarget) then
    return
  end

  local target_alpha = GetTransparency(tp_frame.unit)

	if target_alpha ~= tp_frame.CurrentAlpha then
    if FadingIsEnabled then
      Animations:StopFade(tp_frame)
    end
		tp_frame:SetAlpha(target_alpha)
		tp_frame.CurrentAlpha = target_alpha
    --tp_frame.IsShowing = false
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
