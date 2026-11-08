# @project-version@ (@build-time@)

* Fixed a Lua error when enabling or disabling the interact icon for the target in the options.
* Fixed a bug where, after a loading screen, nameplates in headline view of units that were not targeted showed the target highlight of the healthbar view.
* Fixed a bug where some widgets no longer updated after a profile change or after disabling and enabling them, e.g., the combo points widget only showed the first combo point until switching targets [PR GH-782 by malcyon].
* Fixed a bug where the combo points widget could show the combo points of another enemy (e.g., the soft target instead of the target) or, on WoW Forever, was not updated when building combo points on a new enemy did not change their number.
