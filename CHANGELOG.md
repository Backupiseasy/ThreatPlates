# @project-version@ (@build-time@)

* Added support for enabling and disabling custom nameplates in instances by instance ID in Delves [GH-593].
* Fixed a bug in the BossMods widget that was preventing the label from being disabled [Comment #7702]. The transparency setting has also been removed, as color and transparency are already set by the BossMods addon.
* Fixed a Lua error that occurred when entering a full icon path in the custom nameplate icon selection [GH-595].
* In the BossMods widget, the borders around the icons are now removed automatically.
* Improved DBM integration for BossMods widget so that DBM's own aura and timer icons are shown when BossMods widget is disabled.
