# @project-version@ (@build-time@)

This is a basic version with Midnight support. Expect lots of missing features and Lua errors. Report any bugs at https://github.com/Backupiseasy/ThreatPlates/issues.

* Coloring modes for friendly and enemy units can now be configured separately in health bar and name-only mode.
* Added a highlight border for custom style icons (like totems)
* Added an option to show/hide the source unit for a interrupt.
* Added animations for nameplates when they change size.
* Added Masque support for (some) icons.
* Removed Disconnected option for coloring of healthbars.
* Updated integrated libraries (Ace3 r1387-alpha, LibSharedMedia-3.0 v11.2.1)

Beta changes:
* Fixed a Lua error that occurred when setting a target marker [Comment #7826, #7821]
* Fixed a Lua error that occurred when occluded transparency was enabled [GH-631].
* Fixed a Lua error that occurred when mouseover transparency was enabled [GH-631].
* Fixed a Lua error when health-based coloring for healthbar or name was used (health-based coloring is disabled for now) [GH-633].