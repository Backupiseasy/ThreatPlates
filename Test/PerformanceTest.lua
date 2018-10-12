local TEST_VALUE = 5


local function test_global()
  local value = 0
  for i = 1, 1000000000 do
    value = TEST_VALUE
  end

  print(value)
end

local function run_global()
  local x = TEST_VALUE
end

local TestLocal = { TEST_VALUE = 5 }

function TestLocal:test_local()
  --local test_val = self.TEST_VALUE
  local value = 0
  for i = 1, 1000000000 do
    value = self.TEST_VALUE
  end

  print(value)
end

function TestLocal:run_local()
  local x = TEST_VALUE
end


--local start_time, end_time, testrun_time
--
--start_time = os.clock()
--test_global()
--end_time = os.clock()
--testrun_time = (end_time - start_time)
--
--print ("Global:", testrun_time)
--
--start_time = os.clock()
--TestLocal:test_local()
--end_time = os.clock()
--testrun_time = (end_time - start_time)
--
--print ("Local:", testrun_time)

------------------------------------------------

local start_time, end_time, testrun_time

start_time = os.clock()
for i = 1, 1000000000 do
  run_global()
end
end_time = os.clock()
testrun_time = (end_time - start_time)

print ("Global:", testrun_time)

start_time = os.clock()
for i = 1, 1000000000 do
  TestLocal:run_local()
end
end_time = os.clock()
testrun_time = (end_time - start_time)

print ("Local:", testrun_time)