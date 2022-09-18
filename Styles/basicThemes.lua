local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local ART_PATH = ThreatPlates.Art
local EMPTY_TEXTURE = ART_PATH.."Empty"

local function Create(name)
  local db = Addon.db.profile.settings
  local theme = {

    frame = {
      width = db.frame.width,
      height = db.frame.height,
      x = db.frame.x,
      y = db.frame.y,
      anchor = "CENTER",
    },

    healthbar = {
      texture = Addon.LibSharedMedia:Fetch('statusbar', db.healthbar.texture),
      backdrop = Addon.LibSharedMedia:Fetch('statusbar', db.healthbar.backdrop, true),
      width = db.healthbar.width,
      height = db.healthbar.height,
      x = 0,
      y = 0,
      anchor = "CENTER",
      show = true,
    },

    healthborder = {
      texture = (db.healthborder.show and ThreatPlates.Art .. db.healthborder.texture) or EMPTY_TEXTURE,
      edgesize = db.healthborder.EdgeSize,
      offset = db.healthborder.Offset,
      show = true,
    },

    eliteborder = {
      texture = db.elitehealthborder.texture,
      show = db.elitehealthborder.show,
    },

    threatborder = {
      texture = ThreatPlates.Art.."TP_Threat",
      width = 256,
      height = 64,
      x = 0,
      y = 0,
      anchor = "CENTER",
      show = db.threatborder.show,
    },

    highlight = {
      show = db.highlight.show,
      -- Not used:
      texture = EMPTY_TEXTURE,
    },

    castbar = {
      texture = Addon.LibSharedMedia:Fetch('statusbar', db.castbar.texture),
      backdrop = (db.castbar.show and Addon.LibSharedMedia:Fetch('statusbar', db.castbar.backdrop, true)) or EMPTY_TEXTURE,
      width = db.castbar.width,
      height = db.castbar.height,
      x = db.castbar.x,
      y = db.castbar.y,
      anchor = "CENTER",
      show = db.castbar.show,
    },

    castborder = {
      texture = (db.castborder.show and ThreatPlates.Art .. db.castborder.texture) or EMPTY_TEXTURE,
      edgesize = db.castborder.EdgeSize,
      offset = db.castborder.Offset,
      show = true,
    },

    castnostop = {
      show = db.castborder.show and db.castnostop.ShowOverlay,
    },

    level = {
      typeface = Addon.LibSharedMedia:Fetch('font', db.level.typeface),
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

    spelltext = {
      typeface = Addon.LibSharedMedia:Fetch('font', db.spelltext.typeface),
      size = db.spelltext.size,
      width = db.spelltext.width,
      height = db.spelltext.height,
      align = db.spelltext.align,
      anchor = "CENTER",
      vertical = db.spelltext.vertical,
      shadow = db.spelltext.shadow,
      flags = db.spelltext.flags,
      show = db.spelltext.show,
    },

    skullicon = {
      texture = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
      width = (db.skullicon.scale),
      height = (db.skullicon.scale),
      x = (db.skullicon.x),
      y = (db.skullicon.y),
      anchor = "CENTER", --(db.skullicon.anchor),
      show = db.skullicon.show,
    },

    eliteicon = {
      texture = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\EliteArtWidget\\"..db.eliteicon.theme,
      width = db.eliteicon.scale,
      height = db.eliteicon.scale,
      x = db.eliteicon.x,
      y = db.eliteicon.y,
      anchor = "CENTER",  --db.eliteicon.anchor,
      show = db.eliteicon.show,
    },

    spellicon = {
      width = (db.spellicon.scale),
      height = (db.spellicon.scale),
      x = (db.spellicon.x),
      y = (db.spellicon.y),
      anchor = "CENTER", --(db.spellicon.anchor),
      show = db.spellicon.show,
    },

    raidicon = {
      width = (db.raidicon.scale),
      height = (db.raidicon.scale),
      x = (db.raidicon.x),
      y = (db.raidicon.y),
      anchor = "CENTER", --(db.raidicon.anchor),
      show = db.raidicon.show,
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
    Addon:RegisterTheme(themeList[i], Create)
  end
end
