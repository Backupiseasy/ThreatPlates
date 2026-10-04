# @project-version@ (@build-time@)

* Added support for WoW Forever.
* Added support for WoW Forever's character surnames - full names (first and last) are now shown on nameplates, with a new option to show first names only.
* Enabled Focus widget on WoW Forever.
* Fixed a Lua error re-applying aura appearance settings (e.g. re-opening the options window), caused by an upcoming Blizzard API change (not yet live on retail, but on Forever).
* Fixed a bug where a nameplate briefly showed the wrong name/reaction and then disappeared, caused by Blizzard re-using its internal nameplate frames for different units.
* Fixed the friendly/enemy click-through options not being applied to units whose nameplate is shown by Blizzard instead of Threat Plates.
* Fixed Threat Plates' nameplate size settings changing the clickable area of Blizzard's own nameplates (e.g., friendly units in instances).
* Fixed the "Show Focus" option for the Headline View not working.
* Fixed the Focus and mouseover highlights not being shown in Headline View.
* Fixed a Lua error when selecting the "Crescent" texture for the Target or Focus highlight.
* Fixed the options for showing friendly minions, pets, guardians, totems, and NPCs having no effect (checkboxes could not be checked) [Comment #8597].
* Disabled the options for showing friendly pets, guardians, and totems if showing friendly players is disabled, as Blizzard does not show these nameplates then.
* Fixed a bug where the absorb bar briefly showed at full width when a new nameplate was displayed.
* Enabled target of target names again on WoW Midnight and WoW Forever [Comment #8697].
* Updated integrated libraries (Ace3 r1414-alpha, LibDualSpec-1.0 v1.35.0, LibSharedMedia-3.0 v12.1.0).
* Fixed several bugs where the Social widget did not recognize friends and guild members (e.g., friends from the in-game friend list, Battle.net friends coming online, or characters with surnames on WoW Forever).
* Fixed Cyrillic, Chinese, and Korean characters in nameplate texts being shown as squares, caused by the selected font not containing these characters [GH-751].
* Enabled the option "Transliterate Cyrillic Letters" again on WoW Forever and on WoW Midnight (from patch 12.1.5 on), using a new Blizzard API for transliteration that also works with restricted names (e.g., in combat or battlegrounds).
* Added options to enable stacking of enemy and friendly nameplates [Comment #8734].
* Fixed an error message about dual-spec support not being available on Classic Era realms without dual specialization, and removed the options for spec-based profiles there.
* Removed the options for the personal nameplate (hiding buffs and showing Blizzard's resources on the target nameplate), as Blizzard replaced the personal nameplate with the personal resource display and removed both features.

## WoW Forever Beta

* Fixed automatic role detection not recognizing Druids in Bear Form as tanks.
* Fixed a Lua error for Paladins (and some other classes), caused by changes to the Blizzard API used for role detection [Comment #8694].
* Changed automatic role detection to also use Blizzard's own tank detection, so that tank auras gained in combat (e.g. Righteous Fury) are recognized.
* Fixed Lua errors on login and nameplates not working, caused by a change in the latest beta patch to how the client identifies itself [GH-753].
* Fixed a bug where the Quest widget also highlighted units for quest objectives of other group members.
* Fixed a Lua error when a Battle.net friend is online, caused by Blizzard API changes [Comment #8723].
* Fixed the transparency for occluded units not working, caused by a change in the latest beta patch to how the client identifies itself.
* Fixed the Quest widget not recognizing quests whose data was not yet available when they were accepted.
