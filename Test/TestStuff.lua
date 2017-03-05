-- Function from: https://coronalabs.com/blog/2014/09/02/tutorial-printing-table-contents/
local t = {}

t.DEBUG = function(...)
  print ("DEBUG: ", ...)
end

t.DEBUG_PRINT_TABLE = function(data)
  local print_r_cache={}
  local function sub_print_r(data,indent)
    if (print_r_cache[tostring(data)]) then
      t.DEBUG (indent.."*"..tostring(data))
    else
      print_r_cache[tostring(data)]=true
      if (type(data)=="table") then
        for pos,val in pairs(data) do
          if (type(val)=="table") then
            t.DEBUG (indent.."["..pos.."] => "..tostring(data).." {")
            sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
            t.DEBUG (indent..string.rep(" ",string.len(pos)+6).."}")
          elseif (type(val)=="string") then
            t.DEBUG (indent.."["..pos..'] => "'..val..'"')
          else
            t.DEBUG (indent.."["..pos.."] => "..tostring(val))
          end
        end
      else
        t.DEBUG (indent..tostring(data))
      end
    end
  end
  if (type(data)=="table") then
    t.DEBUG (tostring(data).." {")
    sub_print_r(data,"  ")
    t.DEBUG ("}")
  else
    sub_print_r(data,"  ")
  end
end

local test_array = {}

for i = 1, 5 do
  local content = test_array[i] or {}
  test_array[i] = content
  content.val = i
end

t.DEBUG_PRINT_TABLE(test_array)

