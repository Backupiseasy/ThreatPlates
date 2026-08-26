local _, Addon = ...

local EMPTY_TEXTURE = Addon.PATH_ARTWORK .. "Empty"

local function Create(name)
	local db = Addon.db.profile.settings
	local theme = {

		frame = {
			x = db.frame.x,
			y = db.frame.y,
			anchor = "CENTER",
		},

		healthbar = {
			texture = EMPTY_TEXTURE,
			backdrop = EMPTY_TEXTURE,
			x = 0,
			y = 0,
			anchor = "CENTER",
			orientation = "HORIZONTAL",
			show = false,
			HOSTILE = {
				width = 120,
				height = 10,
      },
      NEUTRAL = {
				width = 120,
				height = 10,
      },
      FRIENDLY = {
				width = 120,
				height = 10,
      },
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

		level = {
			typeface =						Addon.LibSharedMedia:Fetch('font', db.level.typeface),
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

		spelltext = {
			typeface =						Addon.LibSharedMedia:Fetch('font', db.spelltext.typeface),
			size = db.spelltext.size,
			width = db.spelltext.width,
			height = db.spelltext.height,
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
			width = (db.raidicon.scale),
			height = (db.raidicon.scale),
			x = (db.raidicon.x),
			y = (db.raidicon.y),
			anchor = "CENTER", --(db.raidicon.anchor),
		},
	}
	return theme
end

local themeList = {
	"empty",
	"etotem", -- Now, used for nameplates with certain widgets, but no healthbar and name
}

do
	for i=1,#themeList do
    Addon:RegisterTheme(themeList[i],Create)
	end
end
