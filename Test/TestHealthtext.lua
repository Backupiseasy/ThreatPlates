---------------------------------------------------------------------------------------------------
-- Prepare addon test environment
---------------------------------------------------------------------------------------------------
local TidyPlatesThreat = {
  db = {
    profile = {
      text = {
        amount = true,
        percent = true,
        full = false,
        max = true,
        deficit = false,
        truncate = true
      },
    },
  },
}

TidyPlatesThreat.SetStyle = function()
  return "normal"
end

local ThreatPlates = {}
ThreatPlates.AlphaFeatureHeadlineView = function()
  return false
end

local function format(text_format, value)
  return string.format(text_format, value)
end

local function Truncate(value)
  if TidyPlatesThreat.db.profile.text.truncate then
    if value >= 1e6 then
      return format('%.1fm', value / 1e6)
    elseif value >= 1e4 then
      return format('%.1fk', value / 1e3)
    else
      return value
    end
  else
    return value
  end
end

local function SetCustomText_Original(unit)
  local db = TidyPlatesThreat.db.profile.text
  local S = TidyPlatesThreat.SetStyle(unit)

  -- Headline View (alpha feature) uses TidyPlatesHub config and functionality
  if ThreatPlates.AlphaFeatureHeadlineView() and (S == "NameOnly") then
    return TidyPlatesHubFunctions.SetCustomTextBinary(unit)
  end

  if (not db.full and unit.health == unit.healthmax) then
    return ""
  end
  local HpPct = ""
  local HpAmt = ""
  local HpMax = ""

  if db.amount then

    if db.deficit and unit.health ~= unit.healthmax then
      HpAmt = "-"..Truncate(unit.healthmax - unit.health)
    else
      HpAmt = Truncate(unit.health)
    end

    if db.max then
      if HpAmt ~= "" then
        HpMax = " / "..Truncate(unit.healthmax)
      else
        HpMax = Truncate(unit.healthmax)
      end
    end
  end

  if db.percent then
    -- Blizzard calculation:
    -- local perc = math.ceil(100 * (UnitHealth(frame.displayedUnit)/UnitHealthMax(frame.displayedUnit)));

    local perc = math.ceil(100 * (unit.health / unit.healthmax))
    -- old: floor(100*(unit.health / unit.healthmax))

    if HpMax ~= "" or HpAmt ~= "" then
      HpPct = " - "..perc.."%"
    else
      HpPct = perc.."%"
    end
  end

  return HpAmt..HpMax..HpPct
end

local function SetCustomText_Testing(unit)
  local db = TidyPlatesThreat.db.profile.text
  local S = TidyPlatesThreat.SetStyle(unit)

  -- Headline View (alpha feature) uses TidyPlatesHub config and functionality
  if ThreatPlates.AlphaFeatureHeadlineView() and (S == "NameOnly") then
    return TidyPlatesHubFunctions.SetCustomTextBinary(unit)
  end

  if (not db.full and unit.health == unit.healthmax) then
    return ""
  end

  local healthtext = {}
  local i = 1

  local HpPct = ""
  local HpAmt = ""
  local HpMax = ""

  if db.amount then

    if db.deficit and unit.health ~= unit.healthmax then
      healthtext[i] = "-"
      healthtext[i + 1] = Truncate(unit.healthmax - unit.health)
      i = i + 2
      --HpAmt = "-"..Truncate(unit.healthmax - unit.health)
    else
      --HpAmt = Truncate(unit.health)
      healthtext[i] = Truncate(unit.health)
      i = i + 1
    end

    if db.max then
      if i > 1 then
        --HpMax = " / "..Truncate(unit.healthmax)
        healthtext[i] = " / "
        healthtext[i + 1] = Truncate(unit.healthmax)
        i = i + 2
      else
        healthtext[i] = Truncate(unit.healthmax)
        i = i + 1
        --HpMax = Truncate(unit.healthmax)
      end
    end
  end

  if db.percent then
    -- Blizzard calculation:
    -- local perc = math.ceil(100 * (UnitHealth(frame.displayedUnit)/UnitHealthMax(frame.displayedUnit)));

    local perc = math.ceil(100 * (unit.health / unit.healthmax))
    -- old: floor(100*(unit.health / unit.healthmax))

    if i > 1 then
      healthtext[i] = " - "
      healthtext[i + 1] = perc
      healthtext[i + 2] = "%"
      --HpPct = " - "..perc.."%"
    else
      healthtext[i] = perc
      healthtext[i + 1] = "%"
      --HpPct = perc.."%"
    end
  end

  return table.concat(healthtext)
end

---------------------------------------------------------------------------------------------------
-- Measure the runtime of different implementations
---------------------------------------------------------------------------------------------------
local TEST_FUNCTIONS = {
  { SetCustomText_Original , "SetCustomText_Original", },
  { SetCustomText_Testing , "SetCustomText_Testing", },
}

local test_unit = {}
test_unit.healthmax = 100000

local measure = {}
for func = 1, #TEST_FUNCTIONS do
  measure[func] = {}

  local testrun_time = 0

  for testrun = 1, 10000 do
    for health_value = 1, 1000 do

      local start_time = os.clock()
      test_unit.health = health_value * 100
      local text_format = TEST_FUNCTIONS[func][1](test_unit)
      local end_time = os.clock()

      testrun_time = testrun_time + (end_time - start_time)
      assert(text_format == SetCustomText_Original(test_unit), "Wrong format calculation in "..TEST_FUNCTIONS[func][2]..": "..text_format..", should be "..SetCustomText_Original(test_unit))
    end
  end

  measure[func] = testrun_time
end

for func = 1, #TEST_FUNCTIONS do
  io.write(TEST_FUNCTIONS[func][2]..": ")
  io.write("Avg: ")
  io.write(measure[func])
  io.write("\n")
end