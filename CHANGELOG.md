
# @project-version@ (@build-time@)

* Fixed an issue where the target border could disappear after switching target from a distant mob (target-only nameplate) to a new target [Comment #8340].
* Fixed aura icon tooltips not showing reliably in WoW Classic versions [Comment #8183, #8226].
* Fixed "Force View for Target" not switching from Headline View to Healthbar View when targeting a unit that was not taking damage (e.g. friendly units out of combat) [Comment #8308].
* Fixed Blizzard name font changes not applying reliably by re-applying nameplate font overrides (including SystemFont_NamePlate_Outlined) after delayed UI updates [Comment #8230].
* Fixed a Lua error caused by click-through nameplate APIs not available anymore in Mists Classic [GH-690, GH-691, GH-686].
* Fixed a Lua error caused by changes to nameplate sizing APIs in Mists Classic [GH-690, GH-691, GH-686].
* Fixed a Lua error caused by debuff type colors no longer available in the WoW API in Mists Classic.
* Fixed a bug where Blizzard default nameplates were not clickable when enabled for friendly or enemy units.
* Fixed a bug where the clickable area was to small when WorldFrame was selected as parent frame for Threat Plates.
* Fixed a bug where the clickable area was not adjusted correctly when the parent frame for Threat Plates was switched until the UI was reloaded.
* Hopefully fixed enemy nameplates incorrectly showing friendly player names instead of correct enemy names in battlegrounds and arenas on WoW Midnight [Comment #8228].
