
# @project-version@ (@build-time@)

* Fixed a Lua error in the Auras widget that occurred in Bar Mode with "Show Duration" disabled, or when an aura's flash-when-expiring animation triggered.
* Fixed the threat glow border being shown on hidden nameplates (like totems without healthbar) in combat.
* Fixed a Lua error on custom nameplates using the healthbar style [Comment #8438].
* Fixed a Lua error that occurred when opening the options while a custom nameplate with an icon was shown [Comment #8439].
* Fixed a bug where icons for custom styles and class icons were not displayed due to incorrect internal texture handling.
* Hopefully fixed a bug preventing arena numbers from working in WoW Midnight [Comment #8310, GH-645].