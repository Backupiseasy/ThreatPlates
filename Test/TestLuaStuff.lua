---------------------------------------------------------------------------------------------------
-- Test functions: Absorbs displayed on healthbar
---------------------------------------------------------------------------------------------------

local TEST_UNIT = {
  -- 1: Absorbs, without absorbbar
  {
    Test_extended = {
      visual = {
        absorbbar = nil,
        healthbar = true,
      },
    },
    Test_unitid = "unit1", Test_style = "normal",
  },
  -- 2: Absorbs, with absorbbar
  {
    Test_extended = {
      visual = {
        absorbbar = true,
        healthbar = true,
      },
    },
    Test_unitid = "unit1", Test_style = "normal",
  },
  -- 3: No Absorbs
  {
    Test_extended = {
      visual = {
        absorbbar = true,
        healthbar = true,
      },
    },
    Test_unitid = "unit1", Test_style = "normal",
  },
}

function GetConfig(config_no)
  if config_no == 1 then
    return TEST_UNIT[config_no]
  elseif config_no == 2 then
    return TEST_UNIT[config_no]
  elseif config_no == 3 then
    TidyPlatesThreat.db.profile.settings.healthbar.ShowAbsorbs = false
    return TEST_UNIT[config_no]
  end
end

---------------------------------------------------------------------------------------------------

local ENABLE_ABSORB = false

local IGNORED_STYLES = {
  NameOnly = true,
  ["NameOnly-Unique"] = true,
  etotem = true,
  empty= true,
}

local visual, absorbbar

local function CreateExtensions_Global_Test(extended)
  local db = TidyPlatesThreat.db.profile.settings.healthbar
  ENABLE_ABSORB = db.ShowAbsorbs

  local visual = extended.visual
  local absorbbar = visual.absorbbar

  if ENABLE_ABSORB then
    if not absorbbar then
      -- check if absorbbar and glow are created at the samel level as healthbar
      local healthbar = visual.healthbar
    else
      local color = db.AbsorbColor
    end
  else
    -- do nothing
  end
end

local function UpdateExtensions_Global_Test(extended, unitid, style)
  if not ENABLE_ABSORB then return end

  local visual = extended.visual
  local absorbbar = visual.absorbbar

  if IGNORED_STYLES[style] then
    return
  end
end

local function CreateExtensions_Global(extended)
  local db = TidyPlatesThreat.db.profile.settings.healthbar
  ENABLE_ABSORB = db.ShowAbsorbs

  local visual = extended.visual
  local absorbbar = visual.absorbbar

  if ENABLE_ABSORB then
    if not absorbbar then
      -- check if absorbbar and glow are created at the samel level as healthbar
      local healthbar = visual.healthbar
    else
      local color = db.AbsorbColor
    end
  else
    -- do nothing
  end
end

local function UpdateExtensions_Global(extended, unitid, style)
  if not ENABLE_ABSORB then return end
  
  local visual = extended.visual
  local absorbbar = visual.absorbbar

  if IGNORED_STYLES[style] then
    return
  end
end

local function CreateExtensions_DB(extended)
  local db = TidyPlatesThreat.db.profile.settings.healthbar
  local visual = extended.visual
  local absorbbar = visual.absorbbar

  if db.ShowAbsorbs then
    if not absorbbar then
      -- check if absorbbar and glow are created at the samel level as healthbar
      local healthbar = visual.healthbar
    else
      local color = db.AbsorbColor
    end
  else
    -- do nothing
  end
end

local function UpdateExtensions_DB(extended, unitid, style)
  local db = TidyPlatesThreat.db.profile.settings.healthbar
  if not db.ShowAbsorbs then return end

  local visual = extended.visual
  local absorbbar = visual.absorbbar

  if IGNORED_STYLES[style] then
    return
  end
end

local function CreateExtensions_NoOpt(extended)
  local visual = extended.visual
  local absorbbar = visual.absorbbar

  if TidyPlatesThreat.db.profile.settings.healthbar.ShowAbsorbs then
    if not absorbbar then
      -- check if absorbbar and glow are created at the samel level as healthbar
      local healthbar = visual.healthbar
    else
      local color = TidyPlatesThreat.db.profile.settings.healthbar.AbsorbColor
    end
  else
    -- do nothing
  end
end

local function UpdateExtensions_NoOpt(extended, unitid, style)
  if not TidyPlatesThreat.db.profile.settings.healthbar.ShowAbsorbs then return end

  local visual = extended.visual
  local absorbbar = visual.absorbbar

  if IGNORED_STYLES[style] then
    return
  end  
end

function Absorbs_Global_Test(unit)
  CreateExtensions_Global_Test(unit.Test_extended)
  for i=1, 100 do
    UpdateExtensions_Global_Test(unit.Test_extended, unit.Test_unitid, unit.Test_style)
  end
end

function Absorbs_Global(unit)
  CreateExtensions_Global(unit.Test_extended)
  for i=1, 100 do
    UpdateExtensions_Global(unit.Test_extended, unit.Test_unitid, unit.Test_style)
  end
end

function Absorbs_DB(unit)
  CreateExtensions_DB(unit.Test_extended)
  for i=1, 100 do
    UpdateExtensions_DB(unit.Test_extended, unit.Test_unitid, unit.Test_style)
  end
end

function Absorbs_NoOpt(unit)
  CreateExtensions_NoOpt(unit.Test_extended)
  for i=1, 100 do
    UpdateExtensions_NoOpt(unit.Test_extended, unit.Test_unitid, unit.Test_style)
  end
end