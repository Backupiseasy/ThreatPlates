# @project-version@ (@build-time@)

* Added Hex, Earthbind Totem, and Earthgrab Totem (Shaman) to Auras widget as CC aura for Wrath Classic.
* Fixed a Lua error that could occur when numeric aura sorting (e.g., by duration or time left) was enabled [Comment #6629, #Issue 591].
* Fixed a bug with tooltip scanning (e.g., for Quest widget) which resulted in the same line showing multiple times in the tooltip [GH-368].
* Fixed a bug with Combo Points widget where Evoker essence was not being updated properly when not target was selected.
* Updated tooltip code to new API introduced with Patch 10.0.2.
* Removed Threat Plates welcome message at login [Comment #6655].
* Upgrade integrated libraries (LibSharedMedia v10.0.1, Ace3 vr1297-alpha, LibCustomGlow v1.0.3-5-ge685cd9-alpha).
