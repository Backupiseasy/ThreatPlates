# @project-version@ (@build-time@)

* Changed shortened numbers in texts (e.g., health, absorbs, threat value) to be shortened from 1k on instead of from 10k on, e.g., 5400 is now shown as 5.4k [GH-367, Comment #8755251].
* Fixed a bug where the automation for friendly nameplates in combat showed nameplates for friendly NPCs after combat (or in combat) although they were disabled [Comment #100005983].
* Added the highlighting of mobs tanked by another tank (off-tank) on Retail and WoW Forever again and changed how off-tanks are detected in all WoW versions: other players count as off-tanks if they have the tank role or are main tank in a raid, and pets of all group members count as well.
* Changed the role options in WoW Classic and WoW Forever so that the tank/DPS selection is disabled while automatic role detection is enabled, as in Retail.
* Changed the automatic role detection in WoW Classic and WoW Forever so that players with the tank role in their group or main tank in a raid are always detected as tank, also without a tank stance, form or aura.
* Added the option "Pets as Off-Tanks" to disable highlighting mobs tanked by pets or guardians of the group as off-tanked.
