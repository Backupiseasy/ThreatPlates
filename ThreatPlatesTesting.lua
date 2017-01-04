-- Lua implementation of PHP scandir function
function string.ends(String,End)
  return End=='' or string.sub(String,-string.len(End))==End
end

function string.starts(String,Start)
  return string.sub(String,1,string.len(Start))==Start
end

function lines_from(file)
  lines = {}
  for line in io.lines(file) do
    lines[#lines + 1] = line
  end
  return lines
end

function GetDirectories(directory)
  local i, t, popen = 0, {}, io.popen
  local pfile = popen('dir "'..directory..'" /b /ad')
  for filename in pfile:lines() do
    i = i + 1
    t[i] = filename
  end
  pfile:close()
  return t
end

function GetAllFiles(directory)
  local i, t, popen = 0, {}, io.popen
  local pfile = popen('dir "'..directory..'" /b /s')
  for filename in pfile:lines() do
    i = i + 1
    t[i] = filename
  end
  pfile:close()
  return t
end

do
  local file_list = GetAllFiles([[C:\Games\World of Warcraft\Interface\AddOns\TidyPlates_ThreatPlates]])

  for i=1, #file_list do
    if string.ends(file_list[i], ".lua") and
       not string.starts(file_list[i], [[C:\Games\World of Warcraft\Interface\AddOns\TidyPlates_ThreatPlates\Libs]]) and
       not string.starts(file_list[i], [[C:\Games\World of Warcraft\Interface\AddOns\TidyPlates_ThreatPlates\Locales]]) then

      local lines_in_file = lines_from(file_list[i])
      for line=1, #lines_in_file do
        for w in lines_in_file[line]:gmatch("L%b[]") do
          print (w)
        end
      end
    end
  end
end