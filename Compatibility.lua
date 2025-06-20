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
-- Compatibility between retail and classic versions of WoW
---------------------------------------------------------------------------------------------------

local WOW_EVENTS = {
  ACTIVE_TALENT_GROUP_CHANGED = Addon.ExpansionIsAtLeastMists,
  ARENA_OPPONENT_UPDATE = Addon.ExpansionIsAtLeastMists,
  BN_CONNECTED = Addon.ExpansionIsAtLeastMists,
  BN_FRIEND_ACCOUNT_OFFLINE = Addon.ExpansionIsAtLeastMists,
  BN_FRIEND_ACCOUNT_ONLINE = Addon.ExpansionIsAtLeastMists,
  FRIENDLIST_UPDATE = Addon.ExpansionIsAtLeastMists,
  GUILD_ROSTER_UPDATE = Addon.ExpansionIsAtLeastMists,
  PLAYER_ENTERING_WORLD = true,
  PLAYER_FOCUS_CHANGED = Addon.ExpansionIsAtLeastMists,
  PLAYER_REGEN_DISABLED = Addon.ExpansionIsAtLeastMists,
  PLAYER_REGEN_ENABLED = Addon.ExpansionIsAtLeastMists,
  PLAYER_SOFT_ENEMY_CHANGED = true,
  PLAYER_SOFT_FRIEND_CHANGED = true,
  PLAYER_SOFT_INTERACT_CHANGED = true,
  PLAYER_TARGET_CHANGED = true,
  RAID_TARGET_UPDATE = Addon.ExpansionIsAtLeastMists,
  RUNE_POWER_UPDATE = Addon.ExpansionIsAtLeastWrath,
  RUNE_TYPE_UPDATE = Addon.ExpansionIsBetween(LE_EXPANSION_WRATH_OF_THE_LICH_KING, LE_EXPANSION_LEGION),
  TRAIT_CONFIG_UPDATED = Addon.ExpansionIsAtLeastMists,
  UNIT_DISPLAYPOWER = true,
  UNIT_MAXPOWER = true,
  UNIT_NAME_UPDATE = Addon.ExpansionIsAtLeastMists,
  UNIT_PORTRAIT_UPDATE = Addon.ExpansionIsAtLeastMists,
  UNIT_POWER_FREQUENT = true,
  UNIT_POWER_POINT_CHARGE = Addon.IS_MAINLINE,
  UNIT_POWER_UPDATE = true,
  UNIT_THREAT_LIST_UPDATE = Addon.ExpansionIsAtLeastMists,
  UPDATE_BATTLEFIELD_SCORE = Addon.ExpansionIsAtLeastMists,
  UPDATE_SHAPESHIFT_FORM = true,  
  PVP_MATCH_ACTIVE = Addon.IS_MAINLINE
}

function Addon:RegisterEvent(event_handler_frame, event, min_expansion)
  if min_expansion and not Addon.ExpansionIsAtLeast(min_expansion) then return end

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

function Addon:DebugCompatibility()
  local frame = CreateFrame("Frame")
  for event, is_supported in pairs(WOW_EVENTS) do
    local success, result = pcall(frame.RegisterEvent, frame, event)
    if success then
      Addon.Logging.Debug("    ", event .. ": OK")
    else
      Addon.Logging.Debug("    ", event .. ": FAILED =>", result)
    end
  end
end
