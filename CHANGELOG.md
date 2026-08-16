# @project-version@ (@build-time@)

* Fix Lua error when displaying auras on nameplates caused by restrictions on secret values [GH-723].
* Rebuilt the Auras widget on top of Patch 12.1.0's new AuraContainer API, since the old aura-scanning method no longer works reliably. Currently only rudimentary aura features are available as a result.
* Fixed a bug where the castbar sometimes did not show who interrupted a cast [Comment #8481, Comment #8489].
* Fixed a bug where the castbar kept filling after a cast was interrupted, even though the interrupter's name was shown correctly [Comment #8589].