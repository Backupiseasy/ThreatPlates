local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local ART_PATH = ThreatPlates.Art
local MEDIA_PATH = ThreatPlates.Media
local EMPTY_TEXTURE = ART_PATH.."Empty"

-------------------------------------------------------------------------------------
-- Style: Text-Only for Headline-View
-------------------------------------------------------------------------------------

local function Create(self,name)
  local db = self.db.profile.settings
  local dbprofile = self.db.profile
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
      -- Texture Coordinates
      left = 0,
      right = 1,
      top = 0,
      bottom = 1,
    },

    highlight = {
      texture = (dbprofile.HeadlineView.ShowMouseoverHighlight and ART_PATH.."Highlight") or EMPTY_TEXTURE,
      show = true,
    },

    castbar = {
      texture = ThreatPlates.Media:Fetch('statusbar', db.castbar.texture),
      backdrop = (db.castbar.ShowInHeadlineView and ThreatPlates.Media:Fetch('statusbar', db.castbar.backdrop, true)) or EMPTY_TEXTURE,
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

    name = {
      typeface = MEDIA_PATH:Fetch('font', db.name.typeface),
      size = dbprofile.HeadlineView.name.size,
      width = db.name.width, -- use same as for healthbar view
      height = db.name.height, -- use same as for healthbar view
      x = dbprofile.HeadlineView.name.x,
      y = dbprofile.HeadlineView.name.y,
      align = dbprofile.HeadlineView.name.align,
      anchor = "CENTER",
      vertical = dbprofile.HeadlineView.name.vertical,
      shadow = db.name.shadow, -- or: true,
      flags = db.name.flags, -- or: true
      show = true,
    },

    level = {
      typeface = MEDIA_PATH:Fetch('font', db.level.typeface),
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
      typeface = MEDIA_PATH:Fetch('font', db.name.typeface),
      size = dbprofile.HeadlineView.customtext.size,
      width = db.customtext.width, -- use same as for healthbar view
      height = db.customtext.height, -- use same as for healthbar view
      x = dbprofile.HeadlineView.customtext.x,
      y = dbprofile.HeadlineView.customtext.y,
      align = dbprofile.HeadlineView.customtext.align,
      anchor = "CENTER",
      vertical = dbprofile.HeadlineView.customtext.vertical,
      shadow = db.name.shadow,
      flags = db.name.flags,
      show = true,
    },

    spelltext = {
      typeface = ThreatPlates.Media:Fetch('font', db.spelltext.typeface),
      size = db.spelltext.size,
      width = db.spelltext.width,
      height = db.spelltext.height,
      x = db.spelltext.x_hv,
      y = db.spelltext.y_hv,
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
      -- Texture Coordinates
      left = 0,
      right = 1,
      top = 0,
      bottom = 1,
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
      texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
      width = db.raidicon.scale,
      height = db.raidicon.scale,
      x = db.raidicon.x_hv,
      y = db.raidicon.y_hv,
      anchor = "CENTER", --db.raidicon.anchor,
      show = db.raidicon.ShowInHeadlineView,
    },

    threatcolor = {
      LOW = { r = 0, g = 0, b = 0, a = 0 },
      MEDIUM = { r = 0, g = 0, b = 0, a = 0 },
      HIGH = { r = 0, g = 0, b = 0, a = 0 },
    }
  }
  return theme
end

-- Register style in ThreatPlates
Addon:RegisterTheme("NameOnly",Create)
Addon:RegisterTheme("NameOnly-Unique",Create)
