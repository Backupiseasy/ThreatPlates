# @project-version@ (@build-time@)

This is a basic version with Midnight support. Expect lots of missing features and Lua errors. Report any bugs at https://github.com/Backupiseasy/ThreatPlates/issues.

* Disabled status text option Everything in WoW Midnight due to restrictions on secret values.
* Disabled showing the name of a unit's target in WoW Midnight due to restrictions on accessing a unit's target [GH-662].
* Health status text can be hidden again at full health for WoW Midnight.
* Fixed a Lua error that occurred when another addon tried to anchor itself to a Threat Plate [GH-660].
* Disabled OmniCC option in Auras widget as OmniCC no longer is available in WoW Midnight [GH-659].
* Updated integrated libraries (Ace3 r1390, LibCustomGlow to 1.0.4-9-g51de51c-alpha, LibDualSpec v1.29.0)