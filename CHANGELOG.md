# @project-version@ (@build-time@)

This is a basic version with Midnight support. Expect lots of missing features and Lua errors. Report any bugs at https://github.com/Backupiseasy/ThreatPlates/issues.

* Coloring modes for friendly and enemy units can now be configured separately in health bar and name-only mode.
* Added a highlight border for custom style icons (like totems)
* Added an option to show/hide the source unit for a interrupt.
* Added animations for nameplates when they change size.
* Added Masque support for (some) icons.
* Added options to configure parent frame and frame strata of Threat Plates [GH-193, GH-399].
* Removed Disconnected option for coloring of healthbars.
* Fixed a bug that prevented the target highlight from being shown in headline view mode.
* Updated integrated libraries (Ace3 r1387-alpha, LibSharedMedia-3.0 v11.2.1)
 
Beta changes:
* Fixed a Lua error that occurred when opening the options dialog [Comment #7994].
* Fixed a Lua error that occurred when a boss's faction changed [Comment #7984].
* Disabled abbreviation for unit names and transliteration of cyrillic letters as this does not work in Midnight anymore with secret values [Comment #7978].
* Fixed a Lua error that occurred on Paladins in TBC Classic [Comment #7895].
* Fixed a Lua error that occurred when opening options which hovering over a nameplate.
* Fixed a Lua error that occurred when hovering over a nameplate [Comment #7849]
* Fixed a bug that prevented any nameplates from being updated [Comment #7961].
* Hopefully fixed Lua errors that occurred because of accessing nameplates using unit tokens that are not allowed for this purpose (arenaN, bossN) [Comment #7944, #7939,# 7938, GH-654].
* Disabled HealerTracker widget because of BG scoreboard restrictions.
* Fixed a Lua error that occurred due to an error in the code for disabling off-tank detection for Midnight [Comment #7923, #7922, #7916, #7917, #7915].
* Disabled cast target in instances as UnitName returns secret values [Comment #7885].
* Disabled off-tank detection as UnitIsUnit returns secret values [Comment #7898].
* Fixed wrong header for key bindings in WoW options in WoW Midnight.
* Fixed a Lua error that occurred when WoW events for protected nameplates were processed (e..g, friendy players in instances) [Comment #7870]
* Consolidated accessing nameplates using unitid into central defined functions to reduce errors caused by non/wrong initialized Threat Plates. This should fix Comment #7870.
* Made some code Midnight only to fix Lua errors in other versions of WoW.
* Fixed different nameplate size for Threat Plates in 13.x release. 
* Fixed a root cause for lots of Lua errors caused by secret values (but probably not all of them).
* Fixed several Lua errors caused by secret values [GH-639].
* Fixed frame strata for Threat Plates (BACKGROUND) [GH-637].
* Fixed wrong definitions for WoW API function LoadAddOn [GH-638].
* Fixed several Lua errors caused by nameplate size changes. 
* Updated nameplate show/hide CVars (partially).
* Health-based coloring for healthbar, name, and status text now works in WoW Midnight.
* Fixed a Lua error that occurred when setting a target marker [Comment #7826, #7821]
* Fixed a Lua error that occurred when occluded transparency was enabled [GH-631].
* Fixed a Lua error that occurred when mouseover transparency was enabled [GH-631].
* Fixed a Lua error when health-based coloring for healthbar or name was used (health-based coloring is disabled for now) [GH-633].
* Fixed interface version for WoW Retail (12.0.0).