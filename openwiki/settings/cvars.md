---
type: subsystem
title: Game CVars management
description: How Threat Plates reads, sets, backs up and restores WoW console variables (CVars), defers combat-protected changes, reacts to CVar changes by other code, and automates nameplate visibility in combat and instances.
tags: [cvars, settings, combat-lockdown, automation, nameplates]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-25T18:59:51.751Z
sources:
  - id: openwiki-source-1b5e3561fa0fdbc6190a91df
    resource: repo://CVarsManager.lua
  - id: openwiki-source-7a3e837cfb6d3795c0c95431
    resource: repo://Nameplate.lua
  - id: openwiki-source-c9c2cf708e7c112ce26d2e49
    resource: repo://Options.lua
generated: { by: "claude-code", at: "2026-10-25T18:59:51.751Z" }
---

# Game CVars management

Many nameplate behaviors are controlled by WoW console variables (CVars): which nameplates exist at all
(`nameplateShowEnemies`, `nameplateShowFriendlyNpcs`, ...), distances, overlap, alpha multipliers, soft targeting,
name display. `CVarsManager.lua` (`Addon.CVars`, loaded before `Constants.lua`) wraps all CVar writes.

## API

| Function | Behavior |
| --- | --- |
| `CVars:Set(cvar, value)` / `SetBool` | set and **back up** the previous value in `profile.CVarsBackup` |
| `CVars:Overwrite(cvar, value)` / `OverwriteBool` | set without backup |
| `CVars:OverwriteBitfield(cvar, index, value)` | set one flag of a bitfield CVar (`C_CVar.SetCVarBitfield`) |
| `CVars:SetToDefault(cvar)` | reset to the client default and drop the backup |
| `CVars:RestoreFromProfile(cvar)` | restore the backed-up value and drop the backup |
| `CVars:Get`, `GetAsNumber`, `GetAsBool` | read; `GetAsNumber` warns and falls back to the default for non-numeric values |
| `CVars:IsAvailable(cvar)` | `GetCVar(cvar) ~= nil` - the client knows the CVar |
| `CVars:ResetToDefaults()` | reset overlap, motion speed, distances, insets, `nameplateShowOnlyNames` and soft-target CVars, where available |

**Backup rule** (`SetConsoleVariable`): the current value is stored only if it differs both from the new value and
from the stored backup. So the backup keeps the player's own value across repeated `Set` calls, but is replaced
if the player or another addon changed the CVar since.

**Combat protection**: CVars in `COMBAT_PROTECTED` (nameplate alpha/distance/overlap/inset/visibility CVars,
soft-target CVars, friendly name CVars, `uiScale`) cannot be changed in combat. `Set`, `SetToDefault`,
`Overwrite` and `OverwriteBitfield` route them through `Addon.ExecuteAfterCombatEnds`, which queues the change
with a warning and runs it in `PLAYER_REGEN_ENABLED`. `nameplateTopInset`/`BottomInset` were added after
verifying in-game that they are blocked in combat since Patch 12.1.5. `RestoreFromProfile` does not use this
queue.

## Initialization

`CVars:Initialize()` (in `OnInitialize`) registers `nameplateShowOnlyNames` if the client does not know it (a fix
for name-only friendly plates in instances since 10.0.5) and re-applies its value from the profile on every
login, because WoW does not persist it.

## Reacting to CVar changes: the CVar hook

`CVars.RegisterCVarHook()` post-hooks `C_CVar.SetCVar` and `ConsoleExec` (`/console`), so changes from Blizzard's
options, other addons or macros are seen. `SetCVarHook` only looks at `MONITORED_CVARS`:

- For CVars that make Blizzard recompute the native plate size (`nameplateSize`, `nameplateStyle`, class color and
  aura scale CVars), it calls `Addon:SetBaseNamePlateSize()` after combat, because the hit-test frame is anchored
  to Blizzard's unit frame and could otherwise keep a stale clickable area.
- For alpha CVars, if occlusion transparency is enabled, it re-runs `Addon.Transparency.UpdateSettings()` when
  occlusion detection becomes possible or impossible, and warns when the CVars prevent it.

### CVar requirements of features

- Occlusion transparency needs `nameplateMinAlpha`, `nameplateMaxAlpha` and `nameplateSelectedAlpha` = 1 and
  `nameplateOccludedAlphaMult` <= 0.9; on Classic clients (not Mainline, not Forever) also
  `nameplateNotSelectedAlpha` = 1, because of a Blizzard bug with selected targets.
  `CVars.FixCVarsForOcclusionDetection()` sets these values.
- `InvalidCVarsForHidingNameplates`/`FixCVarsForHidingNameplates` belong to a disabled "hide nameplate"
  animation and are only referenced from commented-out code.

## Options

`Options.lua` binds CVar options with `SetValueCVar`/`SetValueCVarBool` (`Overwrite`, no backup),
`CVarsManagerSetBool` (`SetBool`, with backup) and getters reading the live CVar. Options for CVars a client does
not know are hidden (`CVarIsUnavailable` uses `C_CVar.GetCVarInfo`). Nameplate stacking uses the bitfield CVar
`nameplateStackingTypes` indexed by `Enum.NamePlateStackType` (replacement of the removed `nameplateMotion`; works
on Retail 12.1.5 and Forever).

## Automation (`Nameplate.lua`)

- **Combat** (`profile.Automation.FriendlyUnits` / `EnemyUnits`: `NONE`, show in combat, hide in combat):
  `PLAYER_REGEN_DISABLED`/`ENABLED` set `nameplateShowFriendlyPlayers`, `nameplateShowFriendlyNpcs` and
  `nameplateShowEnemies` directly with `_G.SetCVar`, bypassing the combat queue; at the combat boundary the change
  is allowed. Friendly automation is skipped in instances while "hide friendly units in instances" is on.
- **Instances** (`PLAYER_ENTERING_WORLD`, plus `PLAYER_MAP_CHANGED` with a 3 s delay for delves, which do not fire
  `PLAYER_ENTERING_WORLD`): "show/hide friendly units in instances" sets the friendly nameplate CVars with
  `CVars:Set` inside PvE instances and restores them from the backup outside; "show player names in instances"
  does the same for `UnitNameFriendlyPlayerName` and `UnitNameFriendlyTotemName`.
- The Quest widget forces `showQuestTrackingTooltips` to 1 (`Overwrite`), because it reads quest data from
  tooltips.

Because visibility CVars decide whether Blizzard creates a nameplate at all, toggling them recycles plates; see
[Target, soft target, mouseover and focus](../nameplates/targets-mouseover-focus.md) for the effect on target
references.

Related: [Options UI and propagating setting changes](options-and-updates.md),
[Database, profiles and migrations](database-and-profiles.md).
