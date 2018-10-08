local _, Addon = ...
local t = Addon.ThreatPlates

local EMPTY_TEXTURE = t.Art .. "Empty"

local function Create(self,name)
	local db = self.db.profile.settings
	local theme = {

		frame = {
			width = db.frame.width,
			height = db.frame.height,
			x = db.frame.x,
			y = db.frame.y,
			anchor = "CENTER",
		},

		healthbar = {
			texture = EMPTY_TEXTURE,
			backdrop = EMPTY_TEXTURE,
			width = 120,
			height = 10,
			x = 0,
			y = 0,
			anchor = "CENTER",
			orientation = "HORIZONTAL",
			show = false,
		},

		healthborder = {
			show = false,
			-- Not used:
			texture = EMPTY_TEXTURE,
			edgesize = 0,
			offset = 0,
		},

		eliteborder = {
			show = false,
			-- Not used:
			texture = "TP_EliteBorder_Default",
		},

		threatborder = {
			show = false,
			-- Not used:
			texture =	EMPTY_TEXTURE,
			width = 256,
			height = 64,
			x = 0,
			y = 0,
			anchor = "CENTER",
      -- Texture Coordinates
      left = 0,
      right = 1,
      top = 0,
      bottom = 1,
		},

		highlight = {
			show = false,
			-- Not used:
			texture =	EMPTY_TEXTURE,
		},

		castbar = {
			show = false,
			-- Not used:
			texture = EMPTY_TEXTURE,
			backdrop = EMPTY_TEXTURE,
			width = 0,
			height = 0,
			x = 0,
			y = 0,
			anchor = "CENTER",
		},

		castborder = {
			show = false,
			-- Not used:
			texture = EMPTY_TEXTURE,
			edgesize = 0,
			offset = 0,
		},

		castnostop = {
			show = false,
		},

		name = {
			typeface =						t.Media:Fetch('font', db.name.typeface),
			size = db.name.size,
			width = db.name.width,
			height = db.name.height,
			x = db.name.x,
			y = db.name.y,
			align = db.name.align,
			anchor = "CENTER",
			vertical = db.name.vertical,
			shadow = false,
			flags = db.spelltext.flags,
			show = false,
		},

		level = {
			typeface =						t.Media:Fetch('font', db.level.typeface),
			size = db.level.size,
			width = db.level.width,
			height = db.level.height,
			x = db.level.x,
			y = db.level.y,
			align = db.level.align,
			anchor = "CENTER",
			vertical = db.level.vertical,
			shadow = false,
			flags = db.spelltext.flags,
			show = false,
		},

		customtext = {
			typeface =						t.Media:Fetch('font', db.customtext.typeface),
			size = db.customtext.size,
			width = db.customtext.width,
			height = db.customtext.height,
			x = db.customtext.x,
			y = db.customtext.y,
			align = db.customtext.align,
			anchor = "CENTER",
			vertical = db.customtext.vertical,
			shadow = true,
			flags = db.spelltext.flags,
			show = false,
		},

		spelltext = {
			typeface =						t.Media:Fetch('font', db.spelltext.typeface),
			size = db.spelltext.size,
			width = db.spelltext.width,
			height = db.spelltext.height,
			x = db.spelltext.x,
			y = db.spelltext.y,
			align = db.spelltext.align,
			anchor = "CENTER",
			vertical = db.spelltext.vertical,
			shadow = true,
			flags = db.spelltext.flags,
			show = false,
		},

		skullicon = {
			show = false,
			-- Not used:
      texture = EMPTY_TEXTURE,
			width = 0,
			height = 0,
			x = 0,
			y = 0,
			anchor = "CENTER"
		},

		eliteicon = {
			show = false,
			-- Not used:
			texture = EMPTY_TEXTURE,
			width = 0,
			height = 0,
			x = 0,
			y = 0,
			anchor = "CENTER",
			-- Texture Coordinates
			left = 0,
			right = 1,
			top = 0,
			bottom = 1,
		},

		spellicon = {
			show = false,
			-- Not used:
			width = (db.spellicon.scale),
			height = (db.spellicon.scale),
			x = (db.spellicon.x),
			y = (db.spellicon.y),
			anchor = "CENTER", --(db.spellicon.anchor),
		},

		raidicon = {
			show = false,
			-- Not used:
      texture = EMPTY_TEXTURE,
			width = (db.raidicon.scale),
			height = (db.raidicon.scale),
			x = (db.raidicon.x),
			y = (db.raidicon.y),
			anchor = "CENTER", --(db.raidicon.anchor),
		},

		threatcolor = {
			LOW = { r = 0, g = 0, b = 0, a = 0 },
			MEDIUM = { r = 0, g = 0, b = 0, a = 0 },
			HIGH = { r = 0, g = 0, b = 0, a = 0 },
		}
	}
	return theme
end

local themeList = {
	"empty",
	"etotem",
}

do
	for i=1,#themeList do
    Addon:RegisterTheme(themeList[i],Create)
	end
end
