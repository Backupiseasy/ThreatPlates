-- Split text into a list consisting of the strings in text,
-- separated by strings matching delimiter (which may be a pattern).
-- example: strsplit(",%s*", "Anna, Bob, Charlie,Dolores")
function strsplit(delimiter, text)
  local list = {}
  local pos = 1
  if strfind("", delimiter, 1) then -- this would result in endless loops
    error("delimiter matches empty string!")
  end
  while 1 do
    local first, last = strfind(text, delimiter, pos)
    if first then -- found?
      tinsert(list, strsub(text, pos, first-1))
      pos = last+1
    else
      tinsert(list, strsub(text, pos))
      break
    end
  end
  return list
end

---------------------------------------------------------------------------------------------------
-- Parse WoW combat logs for test data
---------------------------------------------------------------------------------------------------

local COMBAT_LOG_FILE = arg[1]
local AURA_WIDGET_TEST_DATA = "AuraWidget.data"

local file = io.open (AURA_WIDGET_TEST_DATA, "w+")
io.output(file)

for line in io.lines(COMBAT_LOG_FILE) do
  -- parse time
  local day, time, action, remaining = line:match("^(%d+%/%d+) (%d+:%d+:%d+%.%d+)  ([A-Z_]+),(.*)$") --

  if action == "SPELL_AURA_APPLIED"  or action == "SPELL_AURA_REMOVED" then
    io.write(line)
    io.write("\n")
  end
end

io.close(file)
