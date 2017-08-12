require("ExternalWoWFunctions")
require("ExternalThreatPlatesFunctions")
require("ExternalDB")

require("TestNametextcolor")

local function is_table_equal(t1,t2,ignore_mt)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then return false end
  -- non-table types can be directly compared
  if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
  -- as well as tables which have the metamethod __eq
  local mt = getmetatable(t1)
  if not ignore_mt and mt and mt.__eq then return t1 == t2 end
  for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if v2 == nil or not is_table_equal(v1,v2) then return false end
  end
  for k2,v2 in pairs(t2) do
    local v1 = t1[k2]
    if v1 == nil or not is_table_equal(v1,v2) then return false end
  end
  return true
end

-----------------------------------------------------------------------------------------------------
-- Measure the runtime of different implementations
---------------------------------------------------------------------------------------------------

local TEST_ITERATIONS = 3000000
local TEST_CONFIGS = 12
local TEST_FUNCTIONS = {
  { SetNameColor_8_4_2 , "SetNameColor_8_4_2"},
  { SetNameColor_New , "SetNameColor_New"},
  { SetNameColor_Test , "SetNameColor_Test"},
}

local measure = {}
local results = {}

for function_no = 1, #TEST_FUNCTIONS do
  measure[function_no] = {}
  results[function_no] = {}

  local testrun_time = 0
  local testrun_result

  for config_no = 1, TEST_CONFIGS do
    results[function_no][config_no] = {}

    local unit = GetTextConfig(config_no)

    for testrun = 1, TEST_ITERATIONS do

      local test_func = TEST_FUNCTIONS[function_no][1]
      local start_time = os.clock()
      test_func(unit)
      testrun_result = table.pack(test_func(unit))
      local end_time = os.clock()

      testrun_time = testrun_time + (end_time - start_time)
    end

    results[function_no][config_no] = testrun_result
    --print ("Testrun:", TEST_FUNCTIONS[func][2], " => ", table.unpack(testrun_result))
  end

  measure[function_no] = testrun_time
end

-- Test if the results from all testing functions for all configs are the same
local error = false
for config_no = 1, TEST_CONFIGS do
  local first_result = results[1][config_no]
  for function_no = 2, #TEST_FUNCTIONS do
    local next_result = results[function_no][config_no]
    if not is_table_equal(first_result, next_result) then
      print ("Inkonsistent results detected:")
      print ("  - : Configuration ", config_no, ":", TEST_FUNCTIONS[1][2], "=", table.unpack(first_result))
      print ("  - : Configuration ", config_no, ":", TEST_FUNCTIONS[function_no][2], "=", table.unpack(next_result))
      error = true
    end
  end
end

if not error then
  for func = 1, #TEST_FUNCTIONS do
    io.write(TEST_FUNCTIONS[func][2]..": ")
    io.write("Avg: ")
    io.write(measure[func])
    io.write("\n")
  end
end
