# Files

- [Game CVars management](cvars.md) - How Threat Plates reads, sets, backs up and restores WoW console variables (CVars), defers combat-protected changes, reacts to CVar changes by other code, and automates nameplate visibility in combat and instances.
- [Database, profiles and migrations](database-and-profiles.md) - How Threat Plates stores its settings with AceDB-3.0 in ThreatPlatesDB, where the defaults come from, how profiles, dual-spec switching and the two default designs work, how settings are migrated between versions, and how profiles and custom styles are imported and exported.
- [Options UI and propagating setting changes](options-and-updates.md) - How the Threat Plates options dialog (Options.lua, AceConfig) is built and opened, how a changed setting is written and pushed to live nameplates (SetValue, UpdateSpecial, ReloadTheme, ForceUpdate, UpdatePlatesVisible), why modules cache settings, and how changes are deferred in combat.
