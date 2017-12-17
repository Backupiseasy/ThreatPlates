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
Media:Register("border", "squareline",[[Interface\Addons\TidyPlates_ThreatPlates\Artwork\squareline.tga]])