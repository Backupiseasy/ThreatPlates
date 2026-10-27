# @project-version@ (@build-time@)

* Fixed a bug where auras on friendly units kept the settings of their own area when "Swap Area By Reaction" was enabled [GH-770].
* Fixed a Lua error when resetting a profile to its default settings (or switching to another profile) while Masque was enabled. A changed Masque setting is now applied after the next UI reload.
* Fixed threat-based transparency and scale for custom styles that use the threat system and for nameplates in headline view [GH-623].
* Fixed several script functions of custom styles not being called or not receiving the documented parameters.
* Fixed enabling or disabling a script-triggered custom style with "Never" only taking effect after a UI reload.
