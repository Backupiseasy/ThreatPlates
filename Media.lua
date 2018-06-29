local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs

-- ThreatPlates APIs
local Media = ThreatPlates.Media
--local koKR, ruRU, zhCN, zhTW, western = Media.LOCALE_BIT_koKR, Media.LOCALE_BIT_ruRU, Media.LOCALE_BIT_zhCN, Media.LOCALE_BIT_zhTW, Media.LOCALE_BIT_western

ThreatPlates.Art = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\"

---------------------------------------------------------------------------------------------------
-- Register media files that ThreatPlates needs at least (because of default settings)
---------------------------------------------------------------------------------------------------

-- -----
--   STATUSBAR
-- -----
Media:Register("statusbar", "ThreatPlatesBar", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_BarTexture.tga]])
Media:Register("statusbar", "ThreatPlatesEmpty", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\Empty.tga]])
Media:Register("statusbar", "Aluminium", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\Aluminium.tga]])
Media:Register("statusbar", "Smooth", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\Smooth.tga]])

-- -----
--   FONT
-- -----
Media:Register("font", "Accidental Presidency",[[Interface\Addons\TidyPlates_ThreatPlates\Fonts\Accidental Presidency.ttf]])
Media:Register("font", "Cabin",[[Interface\Addons\TidyPlates_ThreatPlates\Fonts\Cabin.ttf]]) --, koKR + ruRU + zhCN + zhTW + western)

-- -----
--  BORDER
-- ----
Media:Register("border", "ThreatPlatesBorder",[[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_WhiteSquare.tga]])

-- Test borders
--Media:Register("border", "TP_Border_1px", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_Border_1px.tga]])
--Media:Register("border", "TP_Border_2px", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_Border_2px.tga]])
--Media:Register("border", "TP_Border_3px", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_Border_3px.tga]])
--Media:Register("border", "TP_Border_4px", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_Border_4px.tga]])
--Media:Register("border", "TP_Threat", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_Threat.tga]])
