require("ExternalWoWFunctions")
require("ExternalThreatPlatesFunctions")
require("ExternalDB")

require("TestNametextcolor")

-----------------------------------------------------------------------------------------------------
-- Measure the runtime of different implementations
---------------------------------------------------------------------------------------------------

local ITERATIONS = 10000000
local TEST_FUNCTIONS = {
  { SetNameColor_8_4_2 , "SetNameColor_8_4_2", },
  { SetNameColor_New , "SetNameColor_New", },
  { SetNameColor_Test , "SetNameColor_Test", },
}

local TEST_UNIT = {
  isTapped = false,
  isMarked = false,
  --isMarked = true,
  raidIcon = "STAR",
  reaction = "FRIENDLY",
  -- reaction = "HOSTILE"
  type = "PLAYER",
  --type = "NPC",
  class = "DRUID",
  --
  Test_style = "NameOnly", -- "NameOnly", "NameOnly-Unique"
  Test_unique_style =  {
    useColor = true,
    allowMarked = true,
    color = ThreatPlates.RGB(255, 255, 255)
  },
  Test_IsFriend = false,
  Test_IsGuildmate = false,
}

local measure = {}
for func = 1, #TEST_FUNCTIONS do
  measure[func] = {}

  local testrun_time = 0
  local testrun_result

  for testrun = 1, ITERATIONS do

    -- prepare parameters for test functions
    -- TEST_UNIT.type = "NPC"
    TidyPlatesThreat.db.profile.HeadlineView.UseRaidMarkColoring = true

    local test_func = TEST_FUNCTIONS[func][1]
    local start_time = os.clock()
    test_func(TEST_UNIT)
    --testrun_result = table.pack(test_func(TEST_UNIT))
    local end_time = os.clock()

    testrun_time = testrun_time + (end_time - start_time)
  end

  --print ("Testrun:", TEST_FUNCTIONS[func][2], " => ", table.unpack(testrun_result))
  measure[func] = testrun_time
end

for func = 1, #TEST_FUNCTIONS do
  io.write(TEST_FUNCTIONS[func][2]..": ")
  io.write("Avg: ")
  io.write(measure[func])
  io.write("\n")
end

