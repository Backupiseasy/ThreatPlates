# Files

- [Castbar and interrupts](castbar.md) - How Threat Plates tracks casts, channels and empowered casts on nameplates, draws the castbar with either secret-safe timer objects or Lua arithmetic, shows the interrupter's name on Retail/Forever and Classic, and keeps castbar visibility consistent.
- [Nameplate lifecycle](lifecycle.md) - What Nameplate.lua does from NAME_PLATE_CREATED through NAME_PLATE_UNIT_ADDED and NAME_PLATE_UNIT_REMOVED - the tp_frame and unit data model, plate registries, the Active flag, unit data refresh and revalidation, hiding and anchoring against Blizzard's pooled frames, and the click area.
- [Target, soft target, mouseover and focus](targets-mouseover-focus.md) - How Threat Plates tracks which nameplate is the target, a soft target, the mouseover unit or the focus, which internal events it publishes for them, and how transparency, scaling, highlights and the target/focus widgets react.
