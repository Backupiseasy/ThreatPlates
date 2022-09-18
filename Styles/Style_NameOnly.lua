local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local ART_PATH = ThreatPlates.Art
local EMPTY_TEXTURE = ART_PATH.."Empty"

-------------------------------------------------------------------------------------
-- Style: Text-Only for Headline-View
-------------------------------------------------------------------------------------

local function Create(name)
  local dbprofile = Addon.db.profile
  local db = dbprofile.settings
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
      height = 10,
      width = 120,
      x = 0,
      y = 0,
      anchor = "CENTER",
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
      texture = EMPTY_TEXTURE,
      width = 128,
      height = 64,
      x = 0,
      y = 0,
      anchor = "CENTER",
    },

    highlight = {
      texture = (dbprofile.HeadlineView.ShowMouseoverHighlight and ART_PATH.."Highlight") or EMPTY_TEXTURE,
      show = dbprofile.HeadlineView.ShowMouseoverHighlight,
    },

    castbar = {
      texture = Addon.LibSharedMedia:Fetch('statusbar', db.castbar.texture),
      backdrop = (db.castbar.ShowInHeadlineView and Addon.LibSharedMedia:Fetch('statusbar', db.castbar.backdrop, true)) or EMPTY_TEXTURE,
      width = db.castbar.width,
      height = db.castbar.height,
      x = db.castbar.x_hv,
      y = db.castbar.y_hv,
      anchor = "CENTER",
      show = db.castbar.ShowInHeadlineView,
    },

    castborder = {
      texture = (db.castbar.ShowInHeadlineView and db.castborder.show and ThreatPlates.Art .. db.castborder.texture) or EMPTY_TEXTURE,
      edgesize = db.castborder.EdgeSize,
      offset = db.castborder.Offset,
      show = true,
    },

    castnostop = {
      show = db.castbar.ShowInHeadlineView and db.castborder.show and db.castnostop.ShowOverlay,
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
      shadow = false,
      show = false,
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
      show = db.castbar.ShowInHeadlineView and db.spelltext.show,
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
      width = db.spellicon.scale,
      height = db.spellicon.scale,
      x = db.spellicon.x_hv,
      y = db.spellicon.y_hv,
      anchor = "CENTER", --db.spellicon.anchor,
      show = db.castbar.ShowInHeadlineView and db.spellicon.show,
    },

    raidicon = {
      width = db.raidicon.scale,
      height = db.raidicon.scale,
      x = db.raidicon.x_hv,
      y = db.raidicon.y_hv,
      anchor = "CENTER", --db.raidicon.anchor,
      show = db.raidicon.ShowInHeadlineView,
    },
  }
  return theme
end

-- Register style in ThreatPlates
Addon:RegisterTheme("NameOnly",Create)
Addon:RegisterTheme("NameOnly-Unique",Create)
