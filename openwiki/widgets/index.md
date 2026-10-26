# Files

- [Auras widgets](auras.md) - The two mutually exclusive implementations of the Auras widget - AurasWidget.lua, which scans and filters auras in Lua on older clients, and AurasWidgetMidnight.lua, which hands declarative filters to Blizzard's AuraContainer/AuraButton frames on clients with secret values - with their data flow, settings handling, pitfalls and limitations.
- [Other widgets](catalog.md) - Overview of every Threat Plates widget except Auras - what it shows, which kind of widget it is, on which clients it is loaded, which events drive it, and the pitfalls known from the code.
- [Widget framework](framework.md) - How Widgets/WidgetHandler.lua registers, enables, disables and drives widgets - widget kinds (per plate, target-only, focus-only), required and optional callbacks, per-plate widget frames, settings updates and their cost, and event subscription rules.
