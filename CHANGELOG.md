
# @project-version@ (@build-time@)

* Fixed settings migration bugs that could silently reset some Aura and Threat display options after updating.
* Fixed a bug where clicking on nameplates no longer worked correctly after changing certain Blizzard nameplate settings (e.g. Nameplate Size or Style), without needing a UI reload [Comment #8482].
* Fixed a Lua error that could occur for nameplates shown without a healthbar and name, e.g. totems showing only an icon.
* Fixed the issue of nameplates not stacking or overlapping on Retail and Mists Classic. The parent frame setting has been replaced with a new nameplate size option (Big/Normal) [Comment #8361, GH-706, GH-521, GH-447, GH-620].