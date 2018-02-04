local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Register media files that ThreatPlates needs at least (because of default settings)
---------------------------------------------------------------------------------------------------
local Media = ThreatPlates.Media

Media:Register("statusbar", "ThreatPlatesBar", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_BarTexture.tga]])
Media:Register("statusbar", "ThreatPlatesEmpty", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\Empty.tga]])
Media:Register("statusbar", "Aluminium", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\Aluminium.tga]])
Media:Register("statusbar", "Smooth", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\Smooth.tga]])
Media:Register("font", "Accidental Presidency",[[Interface\Addons\TidyPlates_ThreatPlates\Fonts\Accidental Presidency.ttf]])
Media:Register("font", "Cabin",[[Interface\Addons\TidyPlates_ThreatPlates\Fonts\Cabin.ttf]])

Media:Register("border", "ThreatPlatesBorder",[[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_WhiteSquare.tga]])

-- Test borders
Media:Register("border", "TP_Border_1px", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_Border_1px.tga]])
Media:Register("border", "TP_Border_2px", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_Border_2px.tga]])
Media:Register("border", "TP_Border_3px", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_Border_3px.tga]])
Media:Register("border", "TP_Border_4px", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_Border_4px.tga]])
Media:Register("border", "TP_Threat", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_Threat.tga]])
