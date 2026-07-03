
# @project-version@ (@build-time@)

* Fixed settings migration bugs that could silently reset some Aura and Threat display options after updating.
* Fixed a bug where clicking on nameplates no longer worked correctly after changing certain Blizzard nameplate settings (e.g. Nameplate Size or Style), without needing a UI reload [Comment #8482].
* Fixed a Lua error that could occur for nameplates shown without a healthbar and name, e.g. totems showing only an icon.
* Fixed a Lua error on Classic Era when switching from a tank stance to a DPS stance in combat with off-tank detection enabled [GH-711].
