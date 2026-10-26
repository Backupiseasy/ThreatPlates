# Files

- [Client and expansion compatibility](client-compatibility.md) - How one Threat Plates codebase detects the running WoW client (Retail/Midnight, WoW Forever, Classic Era and its seasons, TBC and Mists Classic) and branches API usage, data tables, events and features on load-time flags.
- [Event system](event-system.md) - EventService.lua is the single dispatcher for WoW events and Threat Plates' internal events - main subscriber vs. subscribers, unit events, per-client gating, publishing, unsubscription rules and their pitfalls.
- [Architecture overview](overview.md) - How Threat Plates is loaded and initialized - TOC load order, the shared Addon namespace table, AceAddon OnInitialize, and how the core, Modules, Elements, Widgets and Styles divide the work of drawing a nameplate.
- [Secret values (Midnight and Forever)](secret-values.md) - How Threat Plates handles WoW's secret values on clients with Midnight's API surface - what they are, which data is affected, the guard patterns and safe sinks used in the code, disabled features, and open issues.
