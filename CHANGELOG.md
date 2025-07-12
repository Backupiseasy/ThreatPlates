# @project-version@ (@build-time@)

* Removed soft-target support for the Resource widgets resource update tracking for soft-targets is not currently supported by the WoW API. Additionally, resource updates for the current target were not working if soft-targeting was disabled in WoW [GH-590].
* Fixed a bug in the Resource widget that was preventing the visibility settings for players and NPCs being working as intended.
* Fixed a bug affecting event registration compatibility across all versions of WoW.