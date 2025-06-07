local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs

-- ThreatPlates APIs

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: 

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------

local WOW_EVENTS = {
  ACTIVE_TALENT_GROUP_CHANGED = Addon.ExpansionIsAtLeastMists,
  TRAIT_CONFIG_UPDATED = Addon.ExpansionIsAtLeastMists,
  PLAYER_ENTERING_WORLD = true,
  PLAYER_TARGET_CHANGED = true,
  PLAYER_SOFT_ENEMY_CHANGED = true,
  UNIT_MAXPOWER = true,
  UNIT_POWER_FREQUENT = true,
  UNIT_POWER_UPDATE = true,
  UNIT_DISPLAYPOWER = true,
  UNIT_POWER_POINT_CHARGE = Addon.IS_MAINLINE,
  UPDATE_SHAPESHIFT_FORM = true,
  RUNE_POWER_UPDATE = Addon.ExpansionIsAtLeastWrath,
  RUNE_TYPE_UPDATE = Addon.ExpansionIsBetween(LE_EXPANSION_WRATH_OF_THE_LICH_KING, LE_EXPANSION_LEGION),
  UPDATE_BATTLEFIELD_SCORE = Addon.ExpansionIsAtLeastMists,
  ARENA_OPPONENT_UPDATE = Addon.ExpansionIsAtLeastMists,
}

function Addon:RegisterEvent(event_handler_frame, event)
  if WOW_EVENTS[event] then
    event_handler_frame:RegisterEvent(event)
  end
end

function Addon:RegisterUnitEvent(event_handler_frame, event, unit)
  if WOW_EVENTS[event] then
    event_handler_frame:RegisterUnitEvent(event, unit)
  end
end

function Addon:UnregisterEvent(event_handler_frame, event)
  if WOW_EVENTS[event] then
    event_handler_frame:UnregisterEvent(event)
  end
end