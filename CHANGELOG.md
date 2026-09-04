# @project-version@ (@build-time@)

* Rebuilt the absorb display on the nameplate's healthbar on WoW Midnight, which had stopped working due to secret value restrictions.
* Fixed enemy nameplates in Arenas and Battlegrounds sometimes showing a previous unit's name, health, or missing debuffs right after entering, caused by client-side data for freshly assigned nameplates not being fully available yet [Comment #8285, Comment #8310, Comment #8648].
* Fixed Blizzard's default nameplates sometimes staying visible on top Threat Plates instead of being replaced, most noticeable in Arenas and Battlegrounds [Comment #8129, Comment #8285].
* Fixed a Lua error in the Class Icon widget in Arenas and Battlegrounds, caused by Blizzard now returning class information as a secret value for hostile players there [Comment #8626].
* Fixed a Lua error when re-applying Aura widget appearance settings in an Arena or Battleground as aura information is secret there.
* Fixed a Lua error in Social widget in Arenas and Battlegrounds, caused by Blizzard now returning name/realm information as a secret value for hostile players there.
* Fixed missing text shadows on nameplate text (name, level, status text, auras, and other widgets) on TBC Classic [GH-734].
* Fixed absorb and heal absorb display not working on Mists Classic despite the options being available.
