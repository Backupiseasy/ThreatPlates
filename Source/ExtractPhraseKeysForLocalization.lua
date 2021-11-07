local lfs = require("lfs")

-- Ignore the following directories or files 
local BLOCK_FILES_AND_DIRS = {
  ".git",
  ".github",
  ".idea",
  ".release",
  "Libs",
  "Locales",
  "Source",
  "Test",
}

local ALLOW_FILES_AND_DIRS = {
  "Elements",
  "Fonts",
  "Functions",
  "Styles",
  "TidyPlatesInternal",
  "Widgets",
  -- Also, all Lua files in the working directory are scanned.
}

local function string_starts(String,Start)
  return string.sub(String,1,string.len(Start))==Start
end

local function string_ends(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

-- This function takes two arguments:
-- - the directory to walk recursively;
-- - an optional function that takes a file name as argument, and returns a boolean.
function ScanDirectory(self, working_dir)
  return coroutine.wrap(function()
    for f in lfs.dir(self) do
      if f ~= "." and f ~= ".." then
        local _f = self .. "/" .. f
        if lfs.attributes(_f, "mode") == "file" and string_ends(_f, ".lua") then
          coroutine.yield(_f)
        elseif lfs.attributes(_f, "mode") == "directory" then
          local allow_dir = true

          for _, block_prefix in ipairs(BLOCK_FILES_AND_DIRS) do
            if string_starts(_f, working_dir .. "/" .. block_prefix) then
              allow_dir = false
              break
            end
          end

          if allow_dir then
            allow_dir = false
            for _, allow_prefix in ipairs(ALLOW_FILES_AND_DIRS) do
              if string_starts(_f, working_dir .. "/" .. allow_prefix) then
                allow_dir = true
                break
              end
            end
  
            if allow_dir then
              for n in ScanDirectory(_f, working_dir, fn) do
                coroutine.yield(n)
              end
            end
          end 
        end
      end
    end
  end)
end

-- Prefix to all files if this script is run from a subdir, for example
local function ParseFile(file_name)
  local phrase_keys = {}
  local file = assert(io.open(string.format("%s%s", "", file_name), "r"), "Error opening file " .. file_name)
  local text = file:read("*all")
  file:close()

  for match in string.gmatch(text, "L%[\"(.-)\"%]") do
    if not match:find('"%.%.(.+)%.%."') then
      phrase_keys[#phrase_keys + 1] = match
    end
end

  return phrase_keys
end

do
  -- Get the current directory (must be Addons/TidyPlates_ThreatPlates)
  local working_dir = arg[1] or os.getenv("PWD")
 
  local phrase_keys = {}

  for file_name in ScanDirectory(working_dir, working_dir) do
    local phrase_keys_in_file = ParseFile(file_name)
    for _, phrase_key in ipairs(phrase_keys_in_file) do
      phrase_keys[phrase_key] = true
    end
  end

  local sorted_phrase_keys = {}
  for key, _ in pairs(phrase_keys) do
    sorted_phrase_keys[#sorted_phrase_keys + 1] = key
  end
  table.sort(sorted_phrase_keys)

  local special_phrase_keys_file = assert(io.open("Source/LocalizationSpecialPhraseKeys.lua", "r"), "Error opening file Source/LocalizationSpecialPhraseKeys.lua")
  local special_phrase_keys = special_phrase_keys_file:read("*all")

  local phrase_keys_import_file_name = arg[2] or "phrase_keys_export_file.txt"
  local phrase_keys_import_file = assert(io.open(phrase_keys_import_file_name, "w"), "Error opening file " .. phrase_keys_import_file_name)
  phrase_keys_import_file:write(special_phrase_keys)

  for _, phrase_key in ipairs(sorted_phrase_keys) do
    phrase_keys_import_file:write(string.format("L[\"%s\"] = true\n", phrase_key))
  end

  print("(" .. #sorted_phrase_keys .. ") " .. phrase_keys_import_file_name)

  phrase_keys_import_file:close()
end
