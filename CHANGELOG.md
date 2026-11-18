# @project-version@ (@build-time@)

* Removed the chat message that auras can only be shown after combat has ended, as it was shown too often.
* Removed the options for coloring healthbars and names by target markers on Retail and WoW Forever, as WoW keeps target markers secret from addons there [Comment #8679137].
* Fixed Lua errors when logging out or reloading the UI while another addon changes WoW settings (CVars) during logout.
* Fixed a bug where the quest widget showed quest objectives of group members as the player's own, e.g., still showing the quest indicator after completing the quest.
* Fixed a bug where the quest widget did not show quest indicators in instances on WoW Forever (now without the quest progress there).
