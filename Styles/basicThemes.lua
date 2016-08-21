local _, ns = ...
local t = ns.ThreatPlates

local function Create(self,name)
  local db = self.db.profile.settings
  local theme = {}
  theme = {
    hitbox = {
      width = 128,
      height = 24,
    },
    frame = {
      emptyTexture = t.Art.."Empty",
      width = 124,
      height = 30,
      x = db.frame.x,
      y = db.frame.y,
      anchor = "CENTER",
    },
    threatborder = {
      texture = t.Art.."TP_Threat",
      width = 256,
      height = 64,
      x = 0,
      y = 0,
      anchor = "CENTER",
      show = db.threatborder.show,
    },
    highlight = {
      texture = t.Art..db.highlight.texture,
      width = 256,
      height = 64,
      x = 0,
      y = 0,
      anchor = "CENTER",
    },
    healthborder = {
      texture = t.Art..db.healthborder.texture,
      backdrop = t.Art..db.healthborder.backdrop,
      width = 256,
      height = 64,
      x = 0,
      y = 0,
      anchor = "CENTER",
      show = db.healthborder.show,
    },
    eliteicon = {
      texture = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\EliteArtWidget\\"..db.eliteicon.theme,
      width = db.eliteicon.scale,
      height = db.eliteicon.scale,
      x = db.eliteicon.x,
      y = db.eliteicon.y,
      anchor = db.eliteicon.anchor,
      show = db.eliteicon.show,
    },
    castborder = {
      texture = t.Art..db.castborder.texture,
      width = 256,
      height = 64,
      x = db.castborder.x,
      y = db.castborder.y,
      anchor = "CENTER",
      show = db.castborder.show,
    },
    castnostop = {
      texture = t.Art.."TP_CastBarLock",
      width = 256,
      height = 64,
      x = db.castnostop.x,
      y = db.castnostop.y,
      anchor = "CENTER",
      show = db.castnostop.show,
    },
    healthbar = {
      texture = t.Media:Fetch('statusbar', db.healthbar.texture),
      width = 120,
      height = 10,
      x = 0,
      y = 0,
      anchor = "CENTER",
      orientation = "HORIZONTAL",
    },
    target = {
      texture = "",
      width = 0,
      height = 0,
      x = 0,
      y = 0,
      anchor = "CENTER",
      show = false,
    },
    castbar = {
      texture = t.Media:Fetch('statusbar', db.castbar.texture),
      width = 120,
      height = 10,
      x = db.castbar.x,
      y = db.castbar.y,
      anchor = "CENTER",
      orientation = "HORIZONTAL",
    },
    name = {
      typeface = t.Media:Fetch('font', db.name.typeface),
      size = db.name.size,
      width = db.name.width,
      height = db.name.height,
      x = db.name.x,
      y = db.name.y,
      align = db.name.align,
      anchor = "CENTER",
      vertical = db.name.vertical,
      shadow = db.name.shadow,
      flags = db.name.flags,
      show = db.name.show,
    },
    level = {
      typeface = t.Media:Fetch('font', db.level.typeface),
      size = db.level.size,
      width = db.level.width,
      height = db.level.height,
      x = db.level.x,
      y = db.level.y,
      align = db.level.align,
      anchor = "CENTER",
      vertical = db.level.vertical,
      shadow = db.level.shadow,
      flags = db.level.flags,
      show = db.level.show,
    },
    customtext = {
      typeface = t.Media:Fetch('font', db.customtext.typeface),
      size = db.customtext.size,
      width = db.customtext.width,
      height = db.customtext.height,
      x = db.customtext.x,
      y = db.customtext.y,
      align = db.customtext.align,
      anchor = "CENTER",
      vertical = db.customtext.vertical,
      shadow = db.customtext.shadow,
      flags = db.customtext.flags,
      show = db.customtext.show,
    },
    spelltext = {
      typeface = t.Media:Fetch('font', db.spelltext.typeface),
      size = db.spelltext.size,
      width = db.spelltext.width,
      height = db.spelltext.height,
      x = db.spelltext.x,
      y = db.spelltext.y,
      align = db.spelltext.align,
      anchor = "CENTER",
      vertical = db.spelltext.vertical,
      shadow = db.spelltext.shadow,
      flags = db.spelltext.flags,
      show = db.spelltext.show,
    },
    skullicon = {
      width = (db.skullicon.scale),
      height = (db.skullicon.scale),
      x = (db.skullicon.x),
      y = (db.skullicon.y),
      anchor = (db.skullicon.anchor),
      show = db.skullicon.show,
    },
    customart = { -- Depreciated?
      width = 256,
      height = 64,
      x = 0,
      y = 0,
      anchor = "CENTER",
      show = db.customart.show,
    },
    spellicon = {
      width = (db.spellicon.scale),
      height = (db.spellicon.scale),
      x = (db.spellicon.x),
      y = (db.spellicon.y),
      anchor = (db.spellicon.anchor),
      show = db.spellicon.show,
    },
    raidicon = {
      width = (db.raidicon.scale),
      height = (db.raidicon.scale),
      x = (db.raidicon.x),
      y = (db.raidicon.y),
      anchor = (db.raidicon.anchor),
      show = db.raidicon.show,
    }
  }
  local threat = db[name].threatcolor
  theme.threatcolor = {
    LOW = {
      r = threat.LOW.r,
      g = threat.LOW.g,
      b = threat.LOW.b,
      a = threat.LOW.a
    },
    MEDIUM = {
      r = threat.MEDIUM.r,
      g = threat.MEDIUM.g,
      b = threat.MEDIUM.b,
      a = threat.MEDIUM.a
    },
    HIGH = {
      r = threat.HIGH.r,
      g = threat.HIGH.g,
      b = threat.HIGH.b,
      a = threat.HIGH.a
    },
  }
  return theme
end

local themeList = {
  "dps",
  "tank",
  "normal",
  "totem",
  "unique"
}

do
  for i=1,#themeList do
    t.RegisterTheme(themeList[i],Create)
  end
end
