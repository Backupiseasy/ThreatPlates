local _, ns = ...
local t = ns.ThreatPlates

if not TidyPlatesThemeList[THREAT_PLATES_NAME] then
	TidyPlatesThemeList[THREAT_PLATES_NAME] = {}
end

local ThemeTable = {}

local function RegisterTheme(name,create)
	if not ThemeTable[name] then
		ThemeTable[name] = {
			name = name,
			create = create
		}
	else
		t.Print("Theme by the name of '"..name.."' already exists.")
	end
end

local function SetThemes(self)
	for k, v in pairs(ThemeTable) do
		TidyPlatesThemeList[THREAT_PLATES_NAME][v.name] = v.create(self,v.name)
	end
end

local function GetTheme(name)
	return ThemeTable[name]
end

t.RegisterTheme = RegisterTheme
t.SetThemes = SetThemes
