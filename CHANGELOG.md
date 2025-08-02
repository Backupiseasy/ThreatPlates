# @project-version@ (@build-time@)

* Added support for enabling and disabling custom nameplates in instances by instance ID in Delves [GH-593].
* Removed soft-target support for the Resource widgets resource update tracking for soft-targets is not currently supported by the WoW API. Additionally, resource updates for the current target were not working if soft-targeting was disabled in WoW [GH-590].
* Fixed a bug in the Resource widget that was preventing the visibility settings for players and NPCs being working as intended.
* Fixed a bug in the BossMods widget that was preventing the label from being disabled [Comment #7702]. The transparency setting has also been removed, as color and transparency are already set by the BossMods addon.
* Fixed a Lua error that occurred when entering a full icon path in the custom nameplate icon selection [GH-595].
* Fixed a bug affecting event registration compatibility across all versions of WoW.
* In the BossMods widget, the borders around the icons are now removed automatically.
* Improved DBM integration for BossMods widget so that DBM's own aura and timer icons are shown when BossMods widget is disabled.
