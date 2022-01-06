local _, Addon = ...
local t = Addon.ThreatPlates

local ThemeTable = {}

function Addon:RegisterTheme(name, create)
	if not ThemeTable[name] then
		ThemeTable[name] = {
			name = name,
			create = create
		}
	else
		Addon.Logging.Error("Theme by the name of '"..name.."' already exists.")
	end
end

function Addon:SetThemes()
	for k, v in pairs(ThemeTable) do
		self.Theme[v.name] = v.create(v.name)
	end
end