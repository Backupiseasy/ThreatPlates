# @project-version@ (@build-time@)

* Fixed a Lua error when spending or regenerating Essence as an Evoker with the combo points widget enabled, caused by secret value restrictions [GH-776].
* Disabled the threat delta and tank value types of the threat widget on WoW Midnight and WoW Forever, as they cannot work with secret threat values.
* Fixed a bug where the mana text of the resource widget ignored the option "Metric Unit Symbols".
* Enabled the option "Metric Unit Symbols" again on WoW Midnight and WoW Forever. If it is disabled, numbers are now abbreviated in western style on these clients, regardless of the client language.
