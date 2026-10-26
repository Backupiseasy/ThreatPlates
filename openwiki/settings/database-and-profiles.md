---
type: subsystem
title: Database, profiles and migrations
description: How Threat Plates stores its settings with AceDB-3.0 in ThreatPlatesDB, where the defaults come from, how profiles, dual-spec switching and the two default designs work, how settings are migrated between versions, and how profiles and custom styles are imported and exported.
tags: [database, acedb, profiles, migrations, savedvariables, import-export]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-25T18:59:51.751Z
sources:
  - id: openwiki-source-014010f28568c5a3c3664449
    resource: repo://Addon.lua
  - id: openwiki-source-8e65c9af5eec1ce3c038cede
    resource: repo://Constants.lua
  - id: openwiki-source-c1d47e467fe7b701bf0b87e3
    resource: repo://Database.lua
  - id: openwiki-source-c9c2cf708e7c112ce26d2e49
    resource: repo://Options.lua
generated: { by: "claude-code", at: "2026-10-25T18:59:51.751Z" }
---

# Database, profiles and migrations

All settings live in the SavedVariables table `ThreatPlatesDB` (declared in the TOC), managed by AceDB-3.0 and
available as `Addon.db` after `TidyPlatesThreat:OnInitialize()`.

## Layout

| Scope | Content |
| --- | --- |
| `Addon.db.global` | `version` (last addon version that ran), `DefaultsVersion` (`SMOOTH` or `CLASSIC`), `CustomNameplatesVersion`, `ScriptingIsEnabled` |
| `Addon.db.char` | `spec` - per specialization `true` (tank) / `false` (dps/heal); on pre-Mists clients only `[1]` is used |
| `Addon.db.profile` | everything else: visibility per unit type, healthbar/castbar/name/status text, colors, transparency/scale, threat, widgets, custom styles (`uniqueSettings`), totems (`totemSettings`), automation, `CVarsBackup`, ... |

`Addon.DEFAULT_SETTINGS` in `Constants.lua` is the AceDB defaults table (`global`, `char`, `profile`). AceDB only
writes values that differ from the defaults, so a removed or renamed default silently changes behavior for
everybody who never touched the setting.

Some defaults are computed at load time, e.g. the totem settings from `TOTEM_DATA_BY_EXPANSION` for the running
client (`GetDefaultTotemSettings`), so defaults differ between clients.

### Two default designs

`Addon.GetDefaultSettingsV1(defaults)` (`Database.lua`) derives the old "Classic" look from the current defaults.
`OnInitialize` uses it if `ThreatPlatesDB.global.DefaultsVersion == "CLASSIC"`. Switching in the options
(`SwitchToDefaultSettingsV1` / `SwitchToCurrentDefaultSettings`) registers the other defaults through a temporary
profile `_ThreatPlatesInternal` and then reloads the theme.

## Profiles

- Created with `LibStub('AceDB-3.0'):New('ThreatPlatesDB', defaults, 'Default')`.
- `OnProfileChanged`, `OnProfileCopied` and `OnProfileReset` call `Addon:ProfChange()` (`Options.lua`), which
  runs `Addon:ReloadTheme()`, updates option preview images and rebuilds the custom style option groups.
- Where dual specialization exists, the database is handed to LibDualSpec in `OnInitialize` so that spec-based
  profile switching works right after login (it used to only work after opening the options) [GH-685]. Not on
  plain Classic Era / Hardcore (see [Client and expansion compatibility](../architecture/client-compatibility.md)).
- `/tptp profile <name>` switches profiles from chat.
- `OnDatabaseShutdown` sets `Addon.IsShuttingDown`, which stops internal event publishing: on logout AceDB strips
  defaults while nameplates are still being removed (see [Event system](../architecture/event-system.md)).

### Tank role per specialization

`Addon:CheckForFirstStartUp()` fills missing entries of `db.char.spec` from the specialization's role (Mists+).
With automatic role detection off, `Addon.PlayerRole` is read from this table; the `/tptptank`, `/tptpdps` and
`/tptptoggle` commands change it.

## Migrations

`CheckForFirstStartUp` compares `db.global.version` with the running version (`Addon.Meta("version")`). If it
changed (and is not empty, i.e. not a fresh install), `Addon.MigrateDatabase(old_version)` runs, then
`global.version` is updated.

- `MIGRATION_FUNCTIONS_BY_VERSION` maps a version string to a list of steps:
  - `{ Type = "Rename", FromKey = {...}, ToKey = {...} }` - move a value (only if it is set, i.e. not default),
  - `{ Type = "Delete", Key = {...} }` - remove an entry,
  - `{ Type = "Migrate", Name = ..., Function = f, Version = cond, NoDefaultProfile = bool }` - custom code.
    `Version` is a condition: the step only runs if it is `nil` or `true` (e.g. `Addon.IS_CLASSIC`,
    `Addon.HAS_MIDNIGHT_API`). `NoDefaultProfile` temporarily registers empty defaults, so the function sees only
    the values stored in the profile.
- Versions are sorted with `CurrentVersionIsOlderThan`; for a profile, every step of a version newer than the
  profile's version runs, oldest first. Versions compare as `major.minor.patch`, with `alphaN`/`betaN` builds
  ordered before the release.
- `MigrateDatabase` migrates every profile, then switches through all profiles once so AceDB removes values equal
  to the defaults.
- `TidyPlatesThreat:VersionIsAtLeast(v)` is always true for development builds (`@project-version@`).

Recent examples: `13.1.0` migrates the auras sort order on `HAS_MIDNIGHT_API` clients, `13.3.0` deletes the old
expiring-color settings. Add a new entry for every renamed, moved or removed setting, keyed by the version that
introduces the change.

## Import and export

The profile options get two extra buttons (`AddImportExportOptions` in `Options.lua`):

- **Export**: `{ Version, ProfileName, Profile = Addon.db.profile }` -> AceSerializer -> LibDeflate compression ->
  printable encoding, shown in an AceGUI edit box.
- **Import**: decode -> decompress -> deserialize; a version mismatch only warns. A free profile name is chosen
  (`Name (1)`, ...). `Addon.ImportProfile(profile, name, version)` migrates the imported data with `MigrateProfile`
  (in `pcall`), creates the new profile and copies only keys that exist in the current settings and have the
  same type (`UpdateFromSettings`, with a few allowed type exceptions). Custom styles are rebuilt one by one with
  `Addon.ImportCustomStyle`, starting from the default custom style and re-generating the trigger arrays.

`Addon.RestoreLegacyCustomNameplates()` (`/tptp legacy-custom-styles`) re-adds the old default custom styles
(`Addon.LEGACY_CUSTOM_NAMEPLATES`) that were removed when custom styles were migrated to the current format.

## SavedVariables pitfall on WoW Forever (resolved)

Earlier WoW Forever builds did not load `ThreatPlatesDB` at all; Blizzard fixed it in the client. Re-running
`CreateAceDatabase()` at `PLAYER_LOGIN` or deferring the AceDB setup were tried and reverted: AceDB replaces a
`nil` global with an empty table immediately, and the client never injected the data later. Addons cannot read
SavedVariables files themselves, so such a bug can only be fixed by the client.

Related: [Options UI and propagating setting changes](options-and-updates.md), [Game CVars management](cvars.md).
