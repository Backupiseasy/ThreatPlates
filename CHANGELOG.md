# @project-version@ (@build-time@)

* Fixed a Lua error in WoW Midnight that occurred when nameplates were accessed, which was caused by restrictions on secret values [GH-678, GH-677, GH-676, Comment #8210, #8209, #8205].
* Fixed a bug that caused the interrupt shield to be displayed even when it was disabled [Comment #8162, #8163, GH-672].
* Fixed a bug where a Evoker's cast bar was not hidden after an empowered cast had finished [Comment #8126].
* Totems should now be recognized correctly in WoW Midnight again as long as they are not protected with secret values [Comment #8106].
* Fixed threat colors/scale being stuck in DPS mode after login until the options dialog was opened or a setting was changed. The player role (tank vs. DPS/healer) is now correctly initialized on login [Comment #7947, #8086, #8184, #8187, #8190].
