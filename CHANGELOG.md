# @project-version@ (@build-time@)

* Fixed a bug where names on Blizzard's nameplates did not go back to Blizzard's font after disabling the custom font.
* Fixed a Lua error when switching from a profile with disabled auras to one with enabled auras.
* Fixed a Lua error when Blizzard's nameplates were shown for friendly units while a custom style with an aura trigger was enabled.
* Replaced the option "Only Names" in Blizzard's nameplate settings on WoW Classic, which no longer worked, with "Only Names for Friendly Players", as Classic now uses the same setting as Retail.
* Fixed a bug where the transparency for occluded units was only applied after opening the options dialog [GH-780].
* Fixed a bug where Blizzard's widgets (quest progress bars) disappeared from a nameplate when switching it from Threat Plates to Blizzard's nameplates without a UI reload.
