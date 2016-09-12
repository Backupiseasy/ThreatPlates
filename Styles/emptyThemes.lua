local _, ns = ...
local t = ns.ThreatPlates

local function Create(self,name)
	local db = self.db.profile.settings
	local theme = {}
	theme = {
		hitbox = { width = 124,	height = 30,	},
		frame = {
			emptyTexture =					t.Art.."Empty",
			width = 124,
			height = 30,
			x = 0,
			y = 0,
			anchor = "CENTER",
		},
		threatborder = {
			texture =						t.Art.."Empty",
			elitetexture =					t.Art.."Empty",
			width = 256,
			height = 64,
			x = 0,
			y = 0,
			anchor = "CENTER",
		},
		healthborder = {
			texture = 						t.Art.."Empty",
			glowtexture = 					t.Art.."Empty",
			elitetexture = 					t.Art.."Empty",
			width = 256,
			height = 64,
			x = 0,
			y = 0,
			anchor = "CENTER",
		},
		castborder = {
			texture =						t.Art.."Empty",
			width = 256,
			height = 64,
			x = 0,
			y = -15,
			anchor = "CENTER",
		},
		castnostop = {
			texture =						t.Art.."Empty",
			width = 256,
			height = 64,
			x = 0,
			y = -15,
			anchor = "CENTER",
		},
		healthbar = {
			texture = 						t.Art.."Empty",
			width = 120,
			height = 10,
			x = 0,
			y = 0,
			anchor = "CENTER",
			orientation = "HORIZONTAL",
		},
		castbar = {
			texture =						t.Art.."Empty",
			width = 120,
			height = 10,
			x = 0,
			y = -15,
			anchor = "CENTER",
			orientation = "HORIZONTAL",
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
			show = false,
		},
		skullicon = {
			width = (db.skullicon.scale),
			height = (db.skullicon.scale),
			x = (db.skullicon.x),
			y = (db.skullicon.y),
			anchor = (db.skullicon.anchor),
			show = false,
		},
		customart = {
			width = (db.customart.scale),
			height = (db.customart.scale),
			x = (db.customart.x),
			y = (db.customart.y),
			anchor = (db.customart.anchor),
			show = false,
		},
		spellicon = {
			width = (db.spellicon.scale),
			height = (db.spellicon.scale),
			x = (db.spellicon.x),
			y = (db.spellicon.y),
			anchor = (db.spellicon.anchor),
			show = false,
		},
		raidicon = {
			width = (db.raidicon.scale),
			height = (db.raidicon.scale),
			x = (db.raidicon.x),
			y = (db.raidicon.y),
			anchor = (db.raidicon.anchor),
			show = false,
		},
		eliteicon = {
      texture = t.Art.."Empty",
      show = false,
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
		t.RegisterTheme(themeList[i],Create)
	end
end
