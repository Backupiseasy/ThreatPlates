local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local EvaluateColorValueFromBoolean = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
local CreateColor = CreateColor

-- ThreatPlates APIs

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: 

---------------------------------------------------------------------------------------------------
-- Register events available in an expansion centrally
---------------------------------------------------------------------------------------------------

local WOW_EVENTS = {
  ACTIVE_TALENT_GROUP_CHANGED = Addon.ExpansionIsAtLeastCata,
  ARENA_OPPONENT_UPDATE = true, -- Added in 3.1.0 / 1.14.0
  BN_CONNECTED = true,
  BN_FRIEND_ACCOUNT_OFFLINE = true,
  BN_FRIEND_ACCOUNT_ONLINE = true,
  COMBAT_LOG_EVENT_UNFILTERED = not Addon.HAS_MIDNIGHT_API, -- Removed in Midnight; also ADDON_ACTION_FORBIDDEN on other clients with Midnight's API surface
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
  PLAYER_FLAGS_CHANGED = true,
  PLAYER_FOCUS_CHANGED = Addon.ExpansionIsAtLeastTBC,
  PLAYER_LOGIN = true,
  PLAYER_MAP_CHANGED = Addon.ExpansionIsAtLeastTWW, -- Added in 11.0.0 (TWW)
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
  UNIT_ABSORB_AMOUNT_CHANGED = Addon.WOW_FEATURE_ABSORBS, -- Absorbs (or at least absorbs functions) were added in Mists
  UNIT_AURA = true,
  UNIT_DISPLAYPOWER = true,
  UNIT_FACTION = true,
  UNIT_FLAGS = true,
  UNIT_HEAL_ABSORB_AMOUNT_CHANGED = Addon.WOW_FEATURE_ABSORBS, -- Absorbs (or at least absorbs functions) were added in Mists
  -- UNIT_HEALTH_FREQUENT is an old-classic-engine event, replaced by UNIT_HEALTH on the modern engine
  -- (Mainline, Mists Classic, and "WoW Forever" - see Addon.IS_FOREVER in Init.lua - all run the modern
  -- engine regardless of content/ruleset).
  UNIT_HEALTH = Addon.ExpansionIsAtLeastMists or Addon.IS_FOREVER, -- Shadowlands Patch 9.0.1 (2020-10-13): Fully replaces UNIT_HEALTH_FREQUENT
  UNIT_HEALTH_FREQUENT = not Addon.ExpansionIsAtLeastMists and not Addon.IS_FOREVER,
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
  UNIT_SPELLCAST_INTERRUPTED = Addon.HAS_MIDNIGHT_API,
  --UNIT_SPELLCAST_FAILED = Addon.HAS_MIDNIGHT_API,
  --UNIT_SPELLCAST_FAILED_QUIET = Addon.HAS_MIDNIGHT_API,
  UNIT_SPELLCAST_EMPOWER_START = Addon.ExpansionIsAtLeastDF,
  UNIT_SPELLCAST_EMPOWER_STOP = Addon.ExpansionIsAtLeastDF,
  UNIT_SPELLCAST_EMPOWER_UPDATE = Addon.ExpansionIsAtLeastDF,
  UNIT_SPELLCAST_INTERRUPTIBLE = true,
  UNIT_SPELLCAST_NOT_INTERRUPTIBLE = true,
  UNIT_SPELLCAST_START = true,
  UNIT_SPELLCAST_STOP = true,
  UNIT_SPELLCAST_SENT = Addon.HAS_MIDNIGHT_API,
  UNIT_TARGET = true,
  UNIT_THREAT_LIST_UPDATE = true,
  UNIT_THREAT_SITUATION_UPDATE = true,
  UPDATE_BATTLEFIELD_SCORE = Addon.ExpansionIsAtLeastCata,
  UPDATE_MOUSEOVER_UNIT = true,
  UPDATE_SHAPESHIFT_FORM = true,  
  UPDATE_UI_WIDGET = true, -- Added in 8.0.1 / 1.13.2
}

function Addon:ExpansionSupportsEvent(event, register_for_current_expansion)
  return register_for_current_expansion ~= false and WOW_EVENTS[event]
end

function Addon:RegisterEvent(event_handler_frame, event, register_for_current_expansion)
  if Addon:ExpansionSupportsEvent(event, register_for_current_expansion) then
    event_handler_frame:RegisterEvent(event)
  end
end

function Addon:RegisterUnitEvent(event_handler_frame, event, unitid, register_for_current_expansion)
  if Addon:ExpansionSupportsEvent(event, register_for_current_expansion) then 
    event_handler_frame:RegisterUnitEvent(event, unitid)
  end
end

function Addon:UnregisterEvent(event_handler_frame, event)
  -- Only need to check if event is known in the current expansion
  if WOW_EVENTS[event] then
    event_handler_frame:UnregisterEvent(event)
  end
end

-- Diagnostic pass over every event this addon knows about (Compatibility.lua's WOW_EVENTS table): tries
-- to register each one on a throwaway frame via pcall, so a client that rejects/removed an event (hard
-- Lua error, not just "event never fires") can never bring down the whole addon here. Reports every event
-- that failed, together with whether WOW_EVENTS already expected that (its flag says "not supported" for
-- the current expansion) or not (flag says "supported", i.e. WOW_EVENTS is now wrong and needs updating).
-- Blind spot: an ADDON_ACTION_FORBIDDEN taint error (as opposed to a plain Lua error) is tied to the
-- calling context, not just the event name, so it will not necessarily reproduce here even for an event
-- that does fail this way when registered from the addon's normal (non-diagnostic) code paths.
-- Invoke with /tptp debug Compatibility.
function Addon:DebugCompatibility()
  local frame = CreateFrame("Frame")
  local mismatched_events, failed_count, mismatch_count, total_count = {}, 0, 0, 0

  -- Sort event names first so output order is stable and deterministic across runs.
  local event_names = {}
  for event in pairs(WOW_EVENTS) do
    event_names[#event_names + 1] = event
  end
  table.sort(event_names)

  for _, event in ipairs(event_names) do
    total_count = total_count + 1
    local success = pcall(frame.RegisterEvent, frame, event)
    if success then
      frame:UnregisterEvent(event)
    else
      failed_count = failed_count + 1
      if WOW_EVENTS[event] then
        mismatch_count = mismatch_count + 1
        mismatched_events[mismatch_count] = event
        Addon.Logging.Print("  FAILED:", event, "(WOW_EVENTS says supported - MISMATCH)")
      else
        Addon.Logging.Print("  FAILED:", event, "(WOW_EVENTS already says unsupported - OK)")
      end
    end
  end

  Addon.Logging.Print(("Compatibility check done: %d/%d events failed to register, %d mismatch(es) with WOW_EVENTS."):format(failed_count, total_count, mismatch_count))
  if mismatch_count > 0 then
    Addon.Logging.Print("Mismatched events - WOW_EVENTS needs updating (copy this line):")
    Addon.Logging.Print(table.concat(mismatched_events, ", "))
  else
    Addon.Logging.Print("No mismatches - WOW_EVENTS is up to date for this client.")
  end
end

---------------------------------------------------------------------------------------------------
-- Tooltip handling
---------------------------------------------------------------------------------------------------

-- C_TooltipInfo.GetUnit was added in 10.0.2. Confirmed present on official Blizzard clients with Midnight's
-- API surface too (e.g. "WoW Forever" - see Addon.IS_FOREVER in Init.lua), despite being below Dragonflight
-- ruleset-wise, so those get the modern branch here as well instead of the legacy tooltip-scanner below.
if Addon.ExpansionIsAtLeastDF or Addon.IS_FOREVER then
  Addon.C_TooltipInfo_GetUnit_NPCRole = C_TooltipInfo.GetUnit
  Addon.C_TooltipInfo_GetUnit_Quest = C_TooltipInfo.GetUnit
else
  local ScannerName = "ThreatPlates_Tooltip_Subtext"
  local TooltipScanner = CreateFrame( "GameTooltip", ScannerName , nil, "GameTooltipTemplate" ) -- Tooltip name cannot be nil
  TooltipScanner:SetOwner( WorldFrame, "ANCHOR_NONE" )

  local TooltipScannerData = {
    lines = {
      [1] = {},
      [2] = {},
      [3] = {},
      [4] = {},
      [5] = {},
    }
  }

  local function CreateLineData(line, with_color)
    local line_id = ScannerName .. "TextLeft" .. tostring(line)

    TooltipScannerData.lines[line].leftText = _G[line_id]:GetText()
    if with_color then
      TooltipScannerData.lines[line].leftColor = RGB_P(_G[line_id]:GetTextColor())
    end
  end

  -- Compatibility functions for tooltips in WoW Classic
  Addon.C_TooltipInfo_GetUnit_NPCRole = function(unitid)
    TooltipScanner:ClearLines()
		TooltipScanner:SetUnit(unitid)

    CreateLineData(1) 
    CreateLineData(2)
    CreateLineData(3)
    
    return TooltipScannerData
  end

  Addon.C_TooltipInfo_GetUnit_Quest = function(unitid)
    TooltipScanner:ClearLines()
		TooltipScanner:SetUnit(unitid)

    CreateLineData(3, true)
    CreateLineData(4, true)
    CreateLineData(5, true)
    
    return TooltipScannerData
  end
end

-- Quest widget is not available in Classic (Vanilla, TBC, Wrath). Official Blizzard clients with
-- Midnight's API surface (e.g. "WoW Forever" - see Addon.IS_FOREVER in Init.lua) do have working quest tooltip data
-- despite the Classic-level ruleset, so they're excluded from this stub.
if not Addon.ExpansionIsAtLeastMists and not Addon.IS_FOREVER then
  Addon.ShowQuestUnit = function(...) return false end
end

---------------------------------------------------------------------------------------------------
-- Midnight
---------------------------------------------------------------------------------------------------

Addon.IsSecretValue = _G.issecretvalue or function() return false end

-- Safe wrapper for UnitIsUnit: returns false instead of a secret value when the result is restricted.
-- Use this instead of the raw UnitIsUnit() call wherever the result is used in a boolean context.
-- Guarded on Addon.HAS_MIDNIGHT_API (not Addon.ExpansionIsAtLeastMidnight): secret values also occur on
-- any client with Midnight's API surface, not just Midnight itself (e.g. "WoW Forever" - see
-- Addon.IS_FOREVER in Init.lua).
if Addon.HAS_MIDNIGHT_API then
  function Addon.UnitIsUnit(unit1, unit2)
    local result = UnitIsUnit(unit1, unit2)
    return not Addon.IsSecretValue(result) and result
  end
else
  Addon.UnitIsUnit = UnitIsUnit
end

-- Safe wrapper for UnitIsPVP: returns false instead of a secret value when the result is restricted.
-- Use this instead of the raw UnitIsPVP() call wherever the result is used in a boolean context.
if Addon.HAS_MIDNIGHT_API then
  function Addon.UnitIsPVP(unitid)
    local result = UnitIsPVP(unitid)
    return not Addon.IsSecretValue(result) and result
  end
else
  Addon.UnitIsPVP = UnitIsPVP
end

function Addon.EvaluateColorValueFromBoolean(boolean, color_if_true, color_if_false)
  local r = EvaluateColorValueFromBoolean(boolean, color_if_true.r, color_if_false.r)
  local g = EvaluateColorValueFromBoolean(boolean, color_if_true.g, color_if_false.g)
  local b = EvaluateColorValueFromBoolean(boolean, color_if_true.b, color_if_false.b)
  local a = EvaluateColorValueFromBoolean(boolean, color_if_true.a, color_if_false.a)
  return CreateColor(r, g, b, a)
end

---------------------------------------------------------------------------------------------------
-- Deprecated Blizzard API compatibility wrappers
---------------------------------------------------------------------------------------------------
-- These old globals are being replaced by namespaced C_* APIs, but the C_* replacements are not yet
-- available on all currently supported clients (e.g. C_CombatLog/C_PvP are missing on Classic Era/
-- Anniversary as of this writing). Fall back to the old global if the new API is not present.

-- IsSpellKnown/IsPlayerSpell -> C_SpellBook: confirmed available on all currently supported clients,
-- including Classic Era.
if C_SpellBook then
  local IsSpellInSpellBook = C_SpellBook.IsSpellInSpellBook
  local IsSpellKnown = C_SpellBook.IsSpellKnown
  -- Enum.SpellBookSpellBank ships together with C_SpellBook, so it is guaranteed to exist whenever C_SpellBook does.
  local SPELLBOOK_BANK_PET = Enum.SpellBookSpellBank.Pet
  local SPELLBOOK_BANK_PLAYER = Enum.SpellBookSpellBank.Player

  function Addon.IsSpellKnown(spellID, isPet)
    return IsSpellInSpellBook(spellID, isPet and SPELLBOOK_BANK_PET or SPELLBOOK_BANK_PLAYER, false)
  end

  function Addon.IsPlayerSpell(spellID)
    return IsSpellKnown(spellID, SPELLBOOK_BANK_PLAYER)
  end
else
  Addon.IsSpellKnown = IsSpellKnown
  Addon.IsPlayerSpell = IsPlayerSpell
end

-- CombatLogGetCurrentEventInfo -> C_CombatLog.GetCurrentEventInfo: confirmed missing on Classic Era/Anniversary.
Addon.CombatLogGetCurrentEventInfo = (C_CombatLog and C_CombatLog.GetCurrentEventInfo) or CombatLogGetCurrentEventInfo

-- GetBattlefieldScore -> C_PvP.GetScoreInfo: confirmed missing on all Classic clients so far. Only name and
-- talentSpec are used anywhere in this addon, so the wrapper returns just those two values instead of the
-- full legacy 17-value tuple.
if C_PvP and C_PvP.GetScoreInfo then
  local GetScoreInfo = C_PvP.GetScoreInfo

  function Addon.GetBattlefieldScore(playerIndex)
    local scoreInfo = GetScoreInfo(playerIndex)
    return scoreInfo and scoreInfo.name, scoreInfo and scoreInfo.talentSpec
  end
else
  local GetBattlefieldScore = GetBattlefieldScore

  function Addon.GetBattlefieldScore(playerIndex)
    local name, _, _, _, _, _, _, _, _, _, _, _, _, _, _, talentSpec = GetBattlefieldScore(playerIndex)
    return name, talentSpec
  end
end