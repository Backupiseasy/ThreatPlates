-- Lua implementation of PHP scandir function
local TPTP_DIRECTORY = [[D:\Games\World of Warcraft - Test\Interface\AddOns\TidyPlates_ThreatPlates]]
--local TPTP_DIRECTORY = [[C:\Games\World of Warcraft\Interface\AddOns\TidyPlates_ThreatPlates]]
local IGNORE_LIST = {
  TPTP_DIRECTORY .. [[\Libs]],
  TPTP_DIRECTORY ..[[\Locales]]
}

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
  local locale_strings = {}

  local file_list = GetAllFiles(TPTP_DIRECTORY)

  for i=1, #file_list do
    if string.ends(file_list[i], ".lua") and
       not string.starts(file_list[i], IGNORE_LIST[1]) and not string.starts(file_list[i], IGNORE_LIST[2]) then

      local lines_in_file = lines_from(file_list[i])
      for line=1, #lines_in_file do
        for w in lines_in_file[line]:gmatch("L%b[]") do
          if not w:find('%.%.%s*%b""') and not w:find('%b""%s*%.%.') then
            locale_strings[w] = true
          end
        end
      end
    end
  end

  local result = {}
  for key, value in pairs(locale_strings) do
    result[#result+1] = key
  end

  table.sort(result)
  for i = 1, #result do
    print (result[i].." = true")
  end
end