---------------------------------------------------------------------------------------------------
-- Test functions: SetNameColor (in nametextcolor.lua)
---------------------------------------------------------------------------------------------------

local TEST_UNIT = {
  -- 1: General - Marked
  {
    isMarked = true, isMouseover = false, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "normal", Test_threat_style = "dps",
  },
  -- 2: General - Mouseover
  {
    isMarked = false, isMouseover = true, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "normal", Test_threat_style = "dps",
  },
  -- 3: General - isCasting
  {
    isMarked = false, isMouseover = false, isCasting = true, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "normal", Test_threat_style = "dps",
  },
  -- 4: General - Target
  {
    isMarked = false, isMouseover = false, isCasting = false, reaction = "FRIENDLY",
    isTarget = true,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "normal", Test_threat_style = "dps",
  },
  -- 5: General - normal
  {
    isMarked = false, isMouseover = false, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "normal", Test_threat_style = "dps",
  },

  -- 6: Threat - useAlpha = true
  {
    isMarked = false, isMouseover = false, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "dps", Test_threat_style = "dps",
  },
  -- 7: Threat - useAlpha = false, marked.alpha = true -> Situational
  {
    isMarked = false, isMouseover = true, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "dps", Test_threat_style = "dps",
  },
  -- 8: Threat - useAlpha = false, marked.alpha = false
  {
    isMarked = false, isMouseover = false, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "tank", Test_threat_style = "dps",
  },

  -- 9: Unique - normal
  {
    isMarked = false, isMouseover = false, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "normal", Test_threat_style = "dps",
    Test_unique_style =  { overrideAlpha = true, UseThreatColor = true, alpha = 0.3 },
  },
  -- 10: Unique - normal
  {
    isMarked = false, isMouseover = false, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "normal", Test_threat_style = "dps",
    Test_unique_style =  { overrideAlpha = false, UseThreatColor = true, alpha = 0.3 },
  },
  -- 11: Unique - normal
  {
    isMarked = false, isMouseover = false, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "normal", Test_threat_style = "dps",
    Test_unique_style =  { overrideAlpha = false, UseThreatColor = false, alpha = 0.3 },
  },

  -- 12: NameOnly - normal
  {
    isMarked = false, isMouseover = false, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "NameOnly", Test_threat_style = "dps",
    Test_unique_style =  { overrideAlpha = true, UseThreatColor = true, alpha = 0.3 },
  },
  -- 13: NameOnly - normal
  {
    isMarked = false, isMouseover = false, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "NameOnly", Test_threat_style = "dps",
    Test_unique_style =  { overrideAlpha = true, UseThreatColor = true, alpha = 0.3 },
  },

  -- 14: UnqiueNameOnly - normal - useAlpha = true
  {
    isMarked = false, isMouseover = false, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "NameOnly", Test_threat_style = "dps",
    Test_unique_style =  { overrideAlpha = true, UseThreatColor = true, alpha = 0.3 },
  },
  -- 15-- : UnqiueNameOnly - normal
  {
    isMarked = false, isMouseover = false, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "NameOnly", Test_threat_style = "dps",
    Test_unique_style =  { overrideAlpha = true, UseThreatColor = true, alpha = 0.3 },
  },
  -- 16: UnqiueNameOnly - normal
  {
    isMarked = false, isMouseover = false, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "NameOnly", Test_threat_style = "dps",
    Test_unique_style =  { overrideAlpha = false, UseThreatColor = true, alpha = 0.3 },
  },
  -- 17: UnqiueNameOnly - normal
  {
    isMarked = false, isMouseover = false, isCasting = false, reaction = "FRIENDLY",
    isTarget = false,
    threatSituation = "HIGH",
    TP_DetailedUnitType = "FriendlyNPC",
    Test_style = "NameOnly", Test_threat_style = "dps",
    Test_unique_style =  { overrideAlpha = false, UseThreatColor = false, alpha = 0.3 },
  },
}

--TidyPlatesThreat.db.profile.HeadlineView.useAlpha = false


function GetConfig(config_no)
  TidyPlatesThreat.db.profile.nameplate.toggle.MarkedA = true
  TidyPlatesThreat.db.profile.nameplate.toggle.MouseoverUnitAlpha = true
  TidyPlatesThreat.db.profile.nameplate.toggle.CastingUnitAlpha = true
  TidyPlatesThreat.db.profile.nameplate.toggle.TargetA = true
  TidyPlatesThreat.db.profile.blizzFadeA.toggle = false
  if config_no == 1 then
    return TEST_UNIT[config_no]
  elseif config_no == 2 then
    return TEST_UNIT[config_no]
  elseif config_no == 3 then
    return TEST_UNIT[config_no]
  elseif config_no == 4 then
    return TEST_UNIT[config_no]
  elseif config_no == 5 then
    return TEST_UNIT[config_no]
  elseif config_no == 6 then
    TidyPlatesThreat.db.profile.threat.useAlpha = true
    return TEST_UNIT[config_no]
  elseif config_no == 7 then
    TidyPlatesThreat.db.profile.threat.useAlpha = false
    TidyPlatesThreat.db.profile.threat.marked.alpha = true
    return TEST_UNIT[config_no]
  elseif config_no == 8 then
    TidyPlatesThreat.db.profile.threat.marked.alpha = false
    return TEST_UNIT[config_no]
  elseif config_no == 9 then
    return TEST_UNIT[config_no]
  elseif config_no == 10 then
    return TEST_UNIT[config_no]
  elseif config_no == 11 then
    return TEST_UNIT[config_no]
  elseif config_no == 12 then
    TidyPlatesThreat.db.profile.threat.useAlpha = true
    return TEST_UNIT[config_no]
  elseif config_no == 13 then
    TidyPlatesThreat.db.profile.threat.useAlpha = false
    return TEST_UNIT[config_no]
  elseif config_no == 14 then
    TidyPlatesThreat.db.profile.threat.useAlpha = true
    return TEST_UNIT[config_no]
  elseif config_no == 15 then
    TidyPlatesThreat.db.profile.threat.useAlpha = false
    return TEST_UNIT[config_no]
  elseif config_no == 16 then
    return TEST_UNIT[config_no]
  elseif config_no == 17 then
    return TEST_UNIT[config_no]
  end
end

---------------------------------------------------------------------------------------------------

local reference = {
  FRIENDLY = { NPC = "FriendlyNPC", PLAYER = "FriendlyPlayer", },
  HOSTILE = {	NPC = "HostileNPC", PLAYER = "HostilePlayer", },
  NEUTRAL = { NPC = "NeutralUnit", PLAYER = "NeutralUnit",	},
}

TidyPlatesThreat.SetStyle = function(unit)
  return unit.Test_style, unit.Test_unique_style
end

ThreatPlates.GetUniqueNameplateSetting = function(unit)
  return unit.Test_unique_style
end

ThreatPlates.UnitIsOffTanked = function(unit)
  return false
end

ThreatPlates.GetThreatStyle = function(unit)
  return unit.Test_threat_style
end

function UnitExists(unitid)
  return true
end

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

  if unit.isMarked and db.toggle.MarkedA then
    return db.alpha.Marked
  elseif unit.isMouseover and db.toggle.MouseoverUnitAlpha then
    return db.alpha.MouseoverUnit
  elseif unit.isCasting then
    local unit_friendly = (unit.reaction == "FRIENDLY")
    if unit_friendly and db.toggle.toggle.CastingUnitAlpha then
      return db.alpha.CastingUnit
    elseif not unit_friendly and db.toggle.CastingEnemyUnitAlpha then
      return db.alpha.CastingEnemyUnit
    end
  end

  return nil
end

local function TransparencyGeneral(unit)
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

  -- Do checks for target settings:
  local db_blizz = TidyPlatesThreat.db.profile.blizzFadeA
  local target_exists = UnitExists("target")
  if target_exists then
    if unit.isTarget and db.toggle.TargetA then
      return db.alpha.Target
    elseif not unit.isTarget and db_blizz.toggle then
      return db_blizz.amount
    end
  elseif db.toggle.NoTargetA then
    return db.alpha.NoTarget
  end

  -- units will always be set to this alpha
  return db.alpha[unit.TP_DetailedUnitType] or 1 -- This should also return for totems.
end

local function TransparencyThreat(unit, style)
  local db = TidyPlatesThreat.db.profile.threat

  if not db.useAlpha then
    return TransparencyGeneral(unit)
  end

  if db.marked.alpha then
    -- or: copy just the situational transparency stuff to this line
    -- Or: return GetGeneralAlpha(unit)

    local tranparency = TransparencySituational(unit)
    if tranparency then
      return tranparency
    end
  end

  local threatSituation = unit.threatSituation
  if style == "tank" and db.toggle.OffTank and UnitIsOffTanked(unit) then
    threatSituation = "OFFTANK"
  end
  return db[style].alpha[threatSituation]

  --	if TidyPlatesThreat:GetSpecRole() then
  --		if db.toggle.OffTank and UnitIsOffTanked(unit) then
  --			threatSituation = "OFFTANK"
  --		end
  --		return db["tank"].alpha[threatSituation]
  --	else
  --		return db["dps"].alpha[threatSituation]
  --	end
end

local function AlphaNormal(unit, non_combat_transparency)
  -- called with style == NameOnly, Unique, Unique-NameOnly


  -- dps/tank, only if
  --  InCombatLockdown() and unit.type == "NPC" and unit.reaction ~= "FRIENDLY" and db.ON and ShowThreatFeedback()
  local style = ThreatPlates.GetThreatStyle(unit)
  if style == "normal" then -- no: totem, etotem, emptya
    return non_combat_transparency or TransparencyGeneral(unit)
  else -- dps, tank
    return TransparencyThreat(unit, style)
  end

  --  local db = TidyPlatesThreat.db.profile.threat
  --	if InCombatLockdown() and db.ON and db.useAlpha then
  --		-- use general alpha, if threat scaling is disabled for marked units
  --		if unit.isMarked and db.marked.alpha then
  --			return override_alpha or TransparencyGeneral(unit), non_target_alpha
  --		else
  --			-- style == "tank" or style == "dps" means, that ShowThreatFeedback(unit) is true anyway
  --			--			if ShowThreatFeedback(unit) then
  --			--				return GetThreatAlpha(unit), non_target_alpha
  --			--			end
  --		end
  --	end
  --
  --	return override_alpha or TransparencyGeneral(unit), non_target_alpha
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
  --	dps = AlphaNormal,
  --	tank = AlphaNormal,
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

function SetAlpha_8_5_0(unit)
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

local function TransparencyGeneral_Test2(unit)
  local db = TidyPlatesThreat.db.profile.nameplate

  local tranparency = TransparencySituational(unit)
  if tranparency then
    return tranparency
  end

  -- Do checks for target settings:
  local db_blizz = TidyPlatesThreat.db.profile.blizzFadeA
  local target_exists = UnitExists("target")
  if target_exists then
    if unit.isTarget and db.toggle.TargetA then
      return db.alpha.Target
    elseif not unit.isTarget and db_blizz.toggle then
      return db_blizz.amount
    end
  elseif db.toggle.NoTargetA then
    return db.alpha.NoTarget
  end

  -- units will always be set to this alpha
  return db.alpha[unit.TP_DetailedUnitType] or 1 -- This should also return for totems.
end

local function TransparencyThreat_Test2(unit, style)
  local db = TidyPlatesThreat.db.profile.threat

  if not db.useAlpha then
    return TransparencyGeneral_Test2(unit)
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
  return db[style].alpha[threatSituation]
end

local function AlphaNormal_Test2(unit, non_combat_transparency)
  local style = GetThreatStyle(unit)
  if style == "normal" then -- no: totem, etotem, emptya
    return non_combat_transparency or TransparencyGeneral_Test2(unit)
  else -- dps, tank
    return TransparencyThreat_Test2(unit, style)
  end
end

local function AlphaUnique_Test2(unit)
  local unique_setting = GetUniqueNameplateSetting(unit)

  if unique_setting.overrideAlpha then
    return AlphaNormal_Test2(unit)
  elseif unique_setting.UseThreatColor then
    return AlphaNormal_Test2(unit, unique_setting.alpha)
  end

  return unique_setting.alpha
end

local function AlphaUniqueNameOnly_Test2(unit)
  local unique_setting = GetUniqueNameplateSetting(unit)

  if unique_setting.overrideAlpha then
    local db = TidyPlatesThreat.db.profile.HeadlineView
    if db.useAlpha then
      return AlphaNormal_Test2(unit)
    end

    return 1
  elseif unique_setting.UseThreatColor then
    return AlphaNormal_Test2(unit, unique_setting.alpha)
  end

  return unique_setting.alpha
end

local function TransparencyNameOnly_Test2(unit)
  local db = TidyPlatesThreat.db.profile.HeadlineView

  if db.useAlpha then
    return AlphaNormal_Test2(unit)
  end

  return 1
end

local ALPHA_FUNCTIONS_Test2 = {
  dps = TransparencyThreat_Test2,
  tank = TransparencyThreat_Test2,
  normal = TransparencyGeneral_Test2,
  totem = TransparencyGeneral_Test2,
  unique = AlphaUnique_Test2,
  empty = TransparencyEmpty,
  etotem = TransparencyEmpty_Test2,
  NameOnly = TransparencyNameOnly_Test2,
  ["NameOnly-Unique"] = AlphaUniqueNameOnly_Test2,
}

function SetAlpha_Test2(unit)
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

function SetAlpha_Test(unit)
  -- sometimes SetAlpha is called without calling OnUpdate/OnContextUpdate first, so TP_Style may not be initialized
  local style = unit.TP_Style or SetStyle(unit)

  local non_combat_transparency
  if style == "empty" or style == "etotem" then
    return 0.01
  elseif style == "unique" then
    local unique_setting = GetUniqueNameplateSetting(unit)

    if unique_setting.overrideAlpha then
      style = ThreatPlates.GetThreatStyle(unit)
    elseif unique_setting.UseThreatColor then
      style = ThreatPlates.GetThreatStyle(unit)
      non_combat_transparency = unique_setting.alpha
    else
      return unique_setting.alpha
    end
  elseif style == "NameOnly-Unique" then

    local unique_setting = GetUniqueNameplateSetting(unit)

    if unique_setting.overrideAlpha then
      local db = TidyPlatesThreat.db.profile.HeadlineView
      if db.useAlpha then
        style = ThreatPlates.GetThreatStyle(unit)
      else
        return 1
      end
    elseif unique_setting.UseThreatColor then
      style = ThreatPlates.GetThreatStyle(unit)
      non_combat_transparency = unique_setting.alpha
    else
      return unique_setting.alpha
    end
  elseif style == "NameOnly" then
    local db = TidyPlatesThreat.db.profile.HeadlineView
    if db.useAlpha then
      style = ThreatPlates.GetThreatStyle(unit)
    else
      return 1
    end
  end

  if style == "normal" or style == "totem" then
    return non_combat_transparency or TransparencyGeneral(unit)
  else -- dps, tank
    return TransparencyThreat(unit, style)
  end
end