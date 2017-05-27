local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Register media files that ThreatPlates needs at least (because of default settings)
---------------------------------------------------------------------------------------------------

ThreatPlates.Media:Register("statusbar", "ThreatPlatesBar", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\TP_BarTexture.tga]])
ThreatPlates.Media:Register("statusbar", "ThreatPlatesEmpty", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\Empty.tga]])
ThreatPlates.Media:Register("statusbar", "Aluminium", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\Aluminium.tga]])
ThreatPlates.Media:Register("statusbar", "Smooth", [[Interface\Addons\TidyPlates_ThreatPlates\Artwork\Smooth.tga]])
ThreatPlates.Media:Register("font", "Accidental Presidency",[[Interface\Addons\TidyPlates_ThreatPlates\Fonts\Accidental Presidency.ttf]])
ThreatPlates.Media:Register("font", "Cabin",[[Interface\Addons\TidyPlates_ThreatPlates\Fonts\Cabin.ttf]])
ThreatPlates.Media:Register("border", "squareline",[[Interface\Addons\TidyPlates_ThreatPlates\squareline.tga]])