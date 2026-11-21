# @project-version@ (@build-time@)

* Removed the chat message that auras can only be shown after combat has ended, as it was shown too often.
* Removed the options for coloring healthbars and names by target markers on Retail and WoW Forever, as WoW keeps target markers secret from addons there [Comment #8679137].
* Fixed Lua errors when logging out or reloading the UI while another addon changes WoW settings (CVars) during logout.
* Fixed a bug where the quest widget showed quest objectives of group members as the player's own, e.g., still showing the quest indicator after completing the quest.
* Fixed a bug where the quest widget did not show quest indicators in instances on WoW Forever (now without the quest progress there).
* Fixed a bug where an aura area anchored to another aura area was not positioned at its edge on Retail and WoW Forever, e.g., buffs overlapping debuffs.
* Fixed Lua errors after anchoring buffs, debuffs and crowd control to each other in a circle, as the options did not prevent this.
* Fixed a bug where combo points were not shown on a target that only became attackable after its nameplate appeared, e.g., an enemy leaving stealth to attack.
