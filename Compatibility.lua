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
  ACTIVE_TALENT_GROUP_CHANGED = Addon.ExpansionIsAtLeastCata,
  ARENA_OPPONENT_UPDATE = true, -- Added in 3.1.0 / 1.14.0
  BN_CONNECTED = true,
  BN_FRIEND_ACCOUNT_OFFLINE = true,
  BN_FRIEND_ACCOUNT_ONLINE = true,
  COMBAT_LOG_EVENT_UNFILTERED = true,
  FRIENDLIST_UPDATE = true,
  GUILD_ROSTER_UPDATE = true,
  GROUP_LEFT = true,
  GROUP_ROSTER_UPDATE = true,   -- Added in 5.0.4 / 1.13.2, also can be registered in Cata Classic
  NAME_PLATE_CREATED = true,
  NAME_PLATE_UNIT_ADDED = true,
  NAME_PLATE_UNIT_REMOVED = true,
  PLAYER_CONTROL_GAINED = true,
  PLAYER_CONTROL_LOST = true,
  PLAYER_ENTERING_WORLD = true,
  RUNE_UPDATED = Addon.IS_CLASSIC_SOD, -- Only needed for Rogue rune detection in SoD Classic
  PLAYER_FLAGS_CHANGED = true,
  PLAYER_FOCUS_CHANGED = Addon.ExpansionIsAtLeastTBC,
  PLAYER_LOGIN = true,
  PLAYER_REGEN_DISABLED = true,
  PLAYER_REGEN_ENABLED = true,
  PLAYER_SOFT_ENEMY_CHANGED = true,
  PLAYER_SOFT_FRIEND_CHANGED = true,
  PLAYER_SOFT_INTERACT_CHANGED = true,
  PLAYER_TARGET_CHANGED = true,
  PVP_MATCH_ACTIVE = Addon.IS_MAINLINE, -- BfA Patch 8.2.0 (2019-06-25): Added.
  QUEST_ACCEPTED = true,
  QUEST_DATA_LOAD_RESULT = Addon.IS_MAINLINE, -- Added in 8.2.5
  QUEST_LOG_UPDATE = true,
  QUEST_REMOVED = true,
  QUEST_WATCH_UPDATE = true,
  RAID_TARGET_UPDATE = true,
  RUNE_POWER_UPDATE = Addon.ExpansionIsAtLeastWrath,
  RUNE_TYPE_UPDATE = Addon.ExpansionIsBetween(LE_EXPANSION_WRATH_OF_THE_LICH_KING, LE_EXPANSION_LEGION),
  RUNE_UPDATED = Addon.IS_CLASSIC_SOD, -- Only needed for Rogue rune detection in SoD Classic
  TRAIT_CONFIG_UPDATED = Addon.ExpansionIsAtLeastCata, 
  UI_SCALE_CHANGED = true,
  UNIT_ABSORB_AMOUNT_CHANGED = Addon.WOW_FEATURE_ABSORBS,       -- Absorbs should have been added with Mists
  UNIT_AURA = true,
  UNIT_DISPLAYPOWER = true,
  UNIT_FACTION = true,
  UNIT_HEAL_ABSORB_AMOUNT_CHANGED = Addon.WOW_FEATURE_ABSORBS,  -- Absorbs should have been added with Mists
  UNIT_HEALTH = Addon.ExpansionIsAtLeastMists, -- Shadowlands Patch 9.0.1 (2020-10-13): Fully replaces UNIT_HEALTH_FREQUENT
  UNIT_HEALTH_FREQUENT = not Addon.ExpansionIsAtLeastMists,
  UNIT_LEVEL = true,
  UNIT_MAXHEALTH = true,
  UNIT_MAXPOWER = true,
  UNIT_NAME_UPDATE = true,
  UNIT_PORTRAIT_UPDATE = true,
  UNIT_POWER_FREQUENT = true, -- Added in 4.3.0 / 1.13.2
  UNIT_POWER_POINT_CHARGE = Addon.IS_MAINLINE, -- Shadowlands Patch 9.0.1 (2020-10-13): Added.
  UNIT_POWER_UPDATE = true,
  UNIT_QUEST_LOG_CHANGED = true,
  UNIT_SPELLCAST_CHANNEL_START = true,
  UNIT_SPELLCAST_CHANNEL_STOP = true,
  UNIT_SPELLCAST_CHANNEL_UPDATE = true,
  UNIT_SPELLCAST_DELAYED = true,
  UNIT_SPELLCAST_EMPOWER_START = Addon.ExpansionIsAtLeastDF,
  UNIT_SPELLCAST_EMPOWER_STOP = Addon.ExpansionIsAtLeastDF,
  UNIT_SPELLCAST_EMPOWER_UPDATE = Addon.ExpansionIsAtLeastDF,
  UNIT_SPELLCAST_INTERRUPTIBLE = true,
  UNIT_SPELLCAST_NOT_INTERRUPTIBLE = true,
  UNIT_SPELLCAST_START = true,
  UNIT_SPELLCAST_STOP = true,
  UNIT_TARGET = true,
  UNIT_THREAT_LIST_UPDATE = true,
  UPDATE_BATTLEFIELD_SCORE = Addon.ExpansionIsAtLeastCata,
  UPDATE_MOUSEOVER_UNIT = true,
  UPDATE_SHAPESHIFT_FORM = true,  
  UPDATE_UI_WIDGET = true, -- Added in 8.0.1 / 1.13.2
}

--local DebugUnknowEvents = {}

function Addon:ExpansionSupportsEvent(event, register_for_current_expansion)
  -- if WOW_EVENTS[event] == nil then DebugUnknowEvents[event] = true end

  return register_for_current_expansion ~= false and WOW_EVENTS[event]
end

function Addon:RegisterEvent(event_handler_frame, event, register_for_current_expansion)
  if not Addon:ExpansionSupportsEvent(event, register_for_current_expansion) then return end

  if WOW_EVENTS[event] then
    event_handler_frame:RegisterEvent(event)
  end
end

function Addon:RegisterUnitEvent(event_handler_frame, event, unit, register_for_current_expansion)
  if not Addon:ExpansionSupportsEvent(event, register_for_current_expansion) then return end

  if WOW_EVENTS[event] then
    event_handler_frame:RegisterUnitEvent(event, unit)
  end
end

function Addon:UnregisterEvent(event_handler_frame, event, register_for_current_expansion)
  if not Addon:ExpansionSupportsEvent(event, register_for_current_expansion) then return end

  if WOW_EVENTS[event] then
    event_handler_frame:UnregisterEvent(event)
  end
end

function Addon:DebugCompatibility()
  local frame = CreateFrame("Frame")
  
  for event, is_supported in pairs(WOW_EVENTS) do
    local success, result = pcall(frame.RegisterEvent, frame, event)
    if not success then
      Addon.Logging.Debug("    ", event .. ": FAILED =>", (not WOW_EVENTS[event] and "CORRECT") or "ERROR")
    elseif not WOW_EVENTS[event] then
      Addon.Logging.Debug("    ", event .. ": OK => DISABLED")      
    end
  end

  if DebugUnknowEvents then
    Addon.Logging.Debug("    Failed Events")      
    for event, _ in pairs(DebugUnknowEvents) do
      Addon.Logging.Debug("      =>", event)      
    end
  end
end
