-----------------------
-- Healer Tracker Widget
--
-- Current logic for detecting healers:
--   World PvP: 
--     - combat log parsing => UnitIsHealer[GUID]
--   Battleground: 
--     - combat log parsing => UnitIsHealer[GUID]
--     - BG scoreboard      => UnitIsHealer[name] (GetSpecializationInfoByID since WoD)
--   Arena:
--     - opponent spec      => UnitIsHealer[GUID] (GetArenaOpponentSpec since MoP)
--
--  Lookup for healers when showing the nameplate:
--    name => GUID
--
-- TODO: use combat log parsing in Classic arenas (as specs are not available in Classic currently)
-- TODO: add option to enable HealerTracker by instance type
-----------------------
local ADDON_NAME, Addon = ...

local Widget = Addon.Widgets:NewWidget("HealerTracker")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local IsInInstance, InCombatLockdown = IsInInstance, InCombatLockdown
local UnitIsPVP, UnitIsPVPSanctuary = UnitIsPVP, UnitIsPVPSanctuary
local GetUnitName = GetUnitName
local RequestBattlefieldScoreData, GetNumBattlefieldScores, GetBattlefieldScore = RequestBattlefieldScoreData, GetNumBattlefieldScores, GetBattlefieldScore
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetArenaOpponentSpec = GetArenaOpponentSpec
local C_Timer_After = C_Timer.After

-- ThreatPlates APIs
local PlatesByGUID = Addon.PlatesByGUID

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

---------------------------------------------------------------------------------------------------
-- Compatibility functions for WoW Classic
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------------------
local HEALER_SPECIALIZATION_ID = {
  [105] = "Restoration Druid",
  [264] = "Restoration Shaman",
  [270] = "Mistweaver Monk",
  [257] = "Holy Priest",
  [65] = "Holy Paladin",
  [256] = "Discipline Priest",
  [1468] = "Preservation Evoker",
}

-- Store localized names for specializations for parsing the battleground score
local HEALER_CLASSES = {}
local HEALER_SPECS = {}

-- GetSpecializationInfoByID: Warlords of Draenor Patch 6.2.0 (2015-06-23): Added GetSpecializationInfoForSpecID()
if Addon.IS_MAINLINE then
  for specialization_id, _ in pairs(HEALER_SPECIALIZATION_ID) do
    local _, name, _, _, _, classFile, _ =  GetSpecializationInfoByID(specialization_id)
    HEALER_CLASSES[classFile] = true
    HEALER_SPECS[name] = true
  end
else
  HEALER_CLASSES.PRIEST = true
  HEALER_CLASSES.DRUID = true
  HEALER_CLASSES.SHAMAN = true
  HEALER_CLASSES.PALADIN = true
end

local SPELL_EVENTS = {
  ["SPELL_HEAL"] = true,
  ["SPELL_AURA_APPLIED"] = true,
  ["SPELL_CAST_START"] = true,
  ["SPELL_CAST_SUCCESS"] = true,
  ["SPELL_EMPOWER_START"] = true,
  ["SPELL_EMPOWER_END"] = true,
  ["SPELL_PERIODIC_HEAL"] = true,
}

local HEALER_SPELLS_RETAIL = {
  -- Holy Priest
  ----------
  [2060] = "PRIEST",     -- Heal
  [14914] = "PRIEST",    -- Holy Fire
  [527] = "PRIEST",      -- Purify
  --
  [2050] = "PRIEST",     -- Holy Word: Serenity
  [34861] = "PRIEST",    -- Holy Word: Sanctify
  --[47788] = "PRIEST",    -- Guardian Spirit
  --[88625] = "PRIEST",    -- Holy Word: Chastise
  [596] = "PRIEST",      -- Prayer of Healing
  [204883] = "PRIEST",   -- Circle of Healing
  --[64843] = "PRIEST",    -- Divine Hymn
  --[64901] = "PRIEST",    -- Symbol of Hope
  --[200183] = "PRIEST",   -- Apotheosis
  --[265202] = "PRIEST",   -- Holy Word: Salvation
  --[372835] = "PRIEST",   -- Lightwell
  
  -- Discipline Priest
  ----------
  [47540] = "PRIEST",  -- Penance
  --
  [194509] = "PRIEST",  -- Power Word: Radiance
  --[33206] = "PRIEST",   -- Pain Suppression
  --[271466] = "PRIEST",  -- Luminous Barrier
  --[62618] = "PRIEST", -- Power Word: Barrier
  [204197] = "PRIEST",  -- Purge of the Wicked
  --[47536] = "PRIEST",   -- Rapture
  --[421543] = "PRIEST",  -- Ultimate Penitence
  --[246287] = "PRIEST",  -- Evangelism
  --[123040] = "PRIEST",  -- Mindbender


  -- Druid
  ---------
  [18562] = "DRUID",   -- Swiftmend
  [212040] = "DRUID",  -- Revitalize
  --
  [33763] = "DRUID",   -- Lifebloom
  [132158] = "DRUID",  -- Nature's Swiftness
  --[102351] = "DRUID",  -- Cenarion Ward
  [145205] = "DRUID",  -- Efflorescence
  --[740] = "DRUID",     -- Tranquilit
  --[102342] = "DRUID",  -- Ironbark
  --[50464] = "DRUID",   -- Nourish
  --[102693] = "DRUID",  -- Grove Guardians
  --[203651] = "DRUID",  -- Overgrowth
  --[33891] = "DRUID",   -- Incarnation: Tree of Life
  --[391528] = "DRUID",  -- Convoke the Spirits
  --[392160] = "DRUID",  -- Invigorate
  --[197721] = "DRUID",  -- Flourish
  

  -- Shaman
  ---------
  [77130] = "SHAMAN",  -- Purify Spirit
  [52127] = "SHAMAN",  -- Water Shield
  --
  [61295] = "SHAMAN",  -- Riptide
  [73920] = "SHAMAN",  -- Healing Rain
  [77472] = "SHAMAN",  -- Healing Wave
  --[98008] = "SHAMAN",  -- Spirit Link Totem
  --[157153] = "SHAMAN", -- Cloudburst Totem
  --[108280] = "SHAMAN", -- Healing Tide Totem
  --[16190] = "SHAMAN",  -- Mana Tide Totem
  --[73685] = "SHAMAN",  -- Unleash Life
  --[198838] = "SHAMAN", -- Earthen Wall Totem
  --[207399] = "SHAMAN", -- Ancestral Protection Totem
  --[382021] = "SHAMAN", -- Earthliving Weapon
  --[114052] = "SHAMAN", -- Ascendance
  --[375982] = "SHAMAN", -- Primordial Wave
  --[197995] = "SHAMAN", -- Wellspring


  -- Paladin
  ----------
  [4987] = "PALADIN", -- Cleanse
  [82326] = "PALADIN", -- Holy Light
  [53563] = "PALADIN", -- Beacon of Light
  --
  [20473] = "PALADIN", -- Holy Shock
  [85222] = "PALADIN", -- Light of Dawn
  --[31821] = "PALADIN", -- Aura Mastery
  --[114165] = "PALADIN", -- Holy Prism
  --[148039] = "PALADIN", -- Barrier of Faith
  --[414273] = "PALADIN", -- Hand of Divinity
  [156910] = "PALADIN", -- Beacon of Faith
  [200025] = "PALADIN", -- Beacon of Virtue
  --[384376] = "PALADIN", -- Avenging Wrath ??? Holy or all Paladins
  --[216331] = "PALADIN", -- Avenging Crusader
  --[200652] = "PALADIN", -- Tyr's Deliverance
  --[388007] = "PALADIN", -- Blessing of Summer


  -- Monk
  ---------
  [115450] = "MONK", -- Detox
  --
  [124682] = "MONK", -- Envelopping Mist
  [116680] = "MONK", -- Thunder Focus Tea
  [115151] = "MONK", -- Renewing Mist
  --[116849] = "MONK", -- Life Cocoon
  [115294] = "MONK", -- Mana Tea
  --[197908] = "MONK", -- Mana Tea
  --[115310] = "MONK", -- Revival
  --[388615] = "MONK", -- Restoral
  --[325197] = "MONK", -- Invoke Chi-Ji, the Red Crane
  --[322118] = "MONK", -- Invoke Yu'lon, the Jade Serpent
  --[388193] = "MONK", -- Jadefire Stomp
  --[399491] = "MONK", -- Sheilun's Gift

  -- Evoker - Preservation
  ---------
  [360823] = "EVOKER", -- Naturalize
  --
  [364343] = "EVOKER", -- Echo
  [382614] = "EVOKER", -- Dream Breath
  --[355936] = "EVOKER", -- Dream Breath
  [366155] = "EVOKER", -- Reversion
  --[366155] = "EVOKER", -- Rewind
  [382731] = "EVOKER", -- Spiritbloom
  --[357170] = "EVOKER", -- Time Dilation
  --[370960] = "EVOKER", -- Emerald Communion
  --[373861] = "EVOKER", -- Temporal Anomaly  
  --[359816] = "EVOKER", -- Dream Flight
  --[370537] = "EVOKER", -- Stasis  
}

local HEALER_SPELLS_CATA = {
  -- Holy Priest
  ----------
  -- Key Abilities: Renew, Flash Heal, Prayer of Healing, Greater Heal, Lightwell
  [47788] = "PRIEST",  -- Guardian Spirit
  [34861] = "PRIEST",  -- Circle of Healing
  [14751] = "PRIEST",  -- Chakra
  [88625] = "PRIEST",  -- Holy Word: Chastise
  [88684] = "PRIEST",  -- Holy Word: Serenity
  [88685] = "PRIEST",  -- Holy Word: Sanctuary
  [724] = "PRIEST",    -- Lightwell
  [19236] = "PRIEST",  -- Desperate Prayer
  [101062] = "PRIEST", -- Flash Heal with Surge of Light proc
  --
  --[139] = "PRIEST",  -- Renew
  --[2061] = "PRIEST", -- Flash Heal
  --[596] = "PRIEST",  -- Prayer of Healing
  --[2060] = "PRIEST", -- Greater Heal


  -- Dicipline Priest
  ----------
  -- Key Abilities: Power Word: Shield, Power Word: Fortitude, Inner Fire, Mana Burn, Power Infusion
  -- [47540] = "PRIEST", -- Penance
  [62618] = "PRIEST", -- Power Word: Barrier
  [33206] = "PRIEST", -- Pain Suppression
  [73413] = "PRIEST", -- Inner Will
  [10060] = "PRIEST", -- Power Infusion
  [87151] = "PRIEST", -- Archangel
  --
  --[47750] = "PRIEST", -- Penance
  --[17] = "PRIEST",   -- Power Word: Shield
  --[588] = "PRIEST",  -- Inner Fire
  --[8129] = "PRIEST", -- Mana Burn

  -- Druid
  ---------
  -- Key Abilities: Regrowth, Rejuvenation, Healting Touch, Rebirth, Tranquility
  [17116] = "DRUID", -- Nature's Swiftness
  [48438] = "DRUID", -- Wild Growth
  [33891] = "DRUID", -- Tree of Life (Aura)
  --
  --[18562] = "DRUID", -- Swiftmend
  --[8936] = "DRUID",  -- Regrowth
  --[774] = "DRUID",   -- Rejuvenation
  --[5185] = "DRUID",  -- Healing Touch
  --[20484] = "DRUID", -- Rebirth
  --[740] = "DRUID",   -- Tranquility

  -- Shaman
  ---------
  -- Key Abilities: Healing Wave, Lesser Healing Wave, Chain Heal, Mana Tide Totem
  [16188] = "SHAMAN", -- Nature's Swiftness
  [16190] = "SHAMAN", -- Mana Tide Totem
  [98008] = "SHAMAN", -- Spirit Link Totem
  [61295] = "SHAMAN", -- Riptide
  -- 
  --[974] = "SHAMAN",   -- Earth Shield
  --[51886] = "SHAMAN", -- Cleanse Spirit
  --[55198] = "SHAMAN", -- Tidal Force
  --[331] = "SHAMAN",  -- Healing Wave
  --[8004] = "SHAMAN", -- Healing Surge

  -- Paladin
  ----------
  -- Key Abilities: Holy Light, Flash of Light, Seal of Light, Lay on Hands, Holy Shock
  [85222] = "PALADIN", -- Light of Dawn
  [31821] = "PALADIN", -- Aura Mastery
  [53563] = "PALADIN", -- Beacon of Light
  [20216] = "PALADIN", -- Divine Favor
  --
  --[31842] = "PALADIN", -- Divine Favor
  --[20473] = "PALADIN", -- Holy Shock
  --[82326] = "PALADIN", -- Divine Light
  --[19750] = "PALADIN", -- Flash of Light
  --[20165] = "PALADIN", -- Seal of Light
}

local HEALER_SPELLS_CLASSIC = {
  -- Holy Priest
  ----------
  -- Key Abilities: Renew, Flash Heal, Prayer of Healing, Greater Heal, Lightwell
  [47788] = "PRIEST", -- Guardian Spirit
  [34861] = "PRIEST", -- Circle of Healing
    [34863] = "PRIEST",   -- Rank 2
    [34864] = "PRIEST",   -- Rank 3
    [34865] = "PRIEST",   -- Rank 4
    [34866] = "PRIEST",   -- Rank 5
    [48088] = "PRIEST",   -- Rank 6
    [48089] = "PRIEST",   -- Rank 7  
  [724] = "PRIEST",   -- Lightwell
    [27870] = "PRIEST",   -- Rank 2
    [27871] = "PRIEST",   -- Rank 3
    [28275] = "PRIEST",   -- Rank 4
    [48086] = "PRIEST",   -- Rank 5
    [48087] = "PRIEST",   -- Rank 5
  [19236] = "PRIEST", -- Desperate Prayer
    [19238] = "PRIEST",   -- Rank 2
    [19240] = "PRIEST",   -- Rank 3
    [19241] = "PRIEST",   -- Rank 4
    [19242] = "PRIEST",   -- Rank 5
    [19243] = "PRIEST",   -- Rank 6
    [25437] = "PRIEST",   -- Rank 7  
    [48172] = "PRIEST",   -- Rank 8
    [48173] = "PRIEST",   -- Rank 9  
  --
  --[139] = "PRIEST",  -- Renew
  --[2061] = "PRIEST", -- Flash Heal
  --[596] = "PRIEST",  -- Prayer of Healing
  --[2060] = "PRIEST", -- Greater Heal


  -- Dicipline Priest
  ----------
  -- Key Abilities: Power Word: Shield, Power Word: Fortitude, Inner Fire, Mana Burn, Power Infusion
  -- [47540] = "PRIEST", -- Penance
  --   [53005] = "PRIEST",   -- Rank 2
  --   [53006] = "PRIEST",   -- Rank 3
  --   [53007] = "PRIEST",   -- Rank 4  
  [47750] = "PRIEST",   -- Penance
    [52983] = "PRIEST",   -- Rank 2
    [52984] = "PRIEST",   -- Rank 3
    [52985] = "PRIEST",   -- Rank 4  
  [33206] = "PRIEST", -- Pain Suppression
  [10060] = "PRIEST", -- Power Infusion
  --
  --[17] = "PRIEST",   -- Power Word: Shield
  --[1243] = "PRIEST", -- Power Word: Fortitude
  --[588] = "PRIEST",  -- Inner Fire
  --[8129] = "PRIEST", -- Mana Burn

  -- Druid
  ---------
  -- Key Abilities: Regrowth, Rejuvenation, Healting Touch, Rebirth, Tranquility
  [48438] = "DRUID", -- Wild Growth
    [53248] = "DRUID",   -- Rank 2
    [53249] = "DRUID",   -- Rank 3
    [53251] = "DRUID",   -- Rank 4  
  [33891] = "DRUID", -- Tree of Life (Aura)
  [18562] = "DRUID", -- Swiftmend
  [17116] = "DRUID", -- Nature's Swiftness
  --
  --[8936] = "DRUID",  -- Regrowth
  --[774] = "DRUID",   -- Rejuvenation
  --[5185] = "DRUID",  -- Healing Touch
  --[20484] = "DRUID", -- Rebirth
  --[740] = "DRUID",   -- Tranquility

  -- Shaman
  ---------
  -- Key Abilities: Healing Wave, Lesser Healing Wave, Chain Heal, Mana Tide Totem
  [61295] = "SHAMAN", -- Riptide
    [61299] = "SHAMAN",   -- Rank 2
    [61300] = "SHAMAN",   -- Rank 3
    [61301] = "SHAMAN",   -- Rank 4  
  [974] = "SHAMAN",   -- Earth Shield
    [32593] = "SHAMAN",   -- Rank 2
    [32594] = "SHAMAN",   -- Rank 3
    [49283] = "SHAMAN",   -- Rank 4
    [49284] = "SHAMAN",   -- Rank 5
  [16190] = "SHAMAN", -- Mana Tide Totem
  [51886] = "SHAMAN", -- Cleanse Spirit
  [16188] = "SHAMAN", -- Nature's Swiftness
  [55198] = "SHAMAN", -- Tidal Force
  -- 
  --[331] = "SHAMAN", -- Healing Wave
  --[8004] = "SHAMAN", -- Lesser Healing Wave
  --[8166] = "SHAMAN", -- Chain Heal

  -- Paladin
  ----------
  -- Key Abilities: Holy Light, Flash of Light, Seal of Light, Lay on Hands, Holy Shock
  [53563] = "PALADIN", -- Beacon of Light
  [31842] = "PALADIN", -- Divine Illumination
  [20473] = "PALADIN", -- Holy Shock
    [20929] = "PALADIN",   -- Rank 2
    [20930] = "PALADIN",   -- Rank 3
    [27174] = "PALADIN",   -- Rank 4
    [33072] = "PALADIN",   -- Rank 5
    [48824] = "PALADIN",   -- Rank 6
    [48825] = "PALADIN",   -- Rank 7
  [20216] = "PALADIN", -- Divine Favor
  [31821] = "PALADIN", -- Aura Mastery
  --
  --[82326] = "PALADIN", -- Holy Light
  --[19750] = "PALADIN", -- Flash of Light
  --[20165] = "PALADIN", -- Seal of Light
  --[48788] = "PALADIN", -- Lay on Hands
}

local HEALER_SPELLS

if Addon.IS_CLASSIC then
  HEALER_SPELLS = HEALER_SPELLS_CLASSIC
elseif Addon.IS_TBC_CLASSIC then
  HEALER_SPELLS = HEALER_SPELLS_CLASSIC
elseif Addon.IS_WRATH_CLASSIC then
  HEALER_SPELLS = HEALER_SPELLS_CLASSIC
elseif Addon.IS_CATA_CLASSIC then
  HEALER_SPELLS = HEALER_SPELLS_CATA
else
  HEALER_SPELLS = HEALER_SPELLS_RETAIL
end

---------------------------------------------------------------------------------------------------
-- Variables
---------------------------------------------------------------------------------------------------
local UnitIsHealer = {}
local UnitGUIDByName = {}
local PlayerIsInBattleground = false
local PlayerIsInWorldPvPArea = false
local CheckPvPStateIsEnabled = false
local CombatLogParsingIsEnabled = false
local BattlefieldScoreDataRequestPending = false
local DebugHealerInfoSource = {}

---------------------------------------------------------------------------------------------------
-- Functions
---------------------------------------------------------------------------------------------------

local function UpdateNameplateByGUID(unit_guid)
  local plate = PlatesByGUID[unit_guid]
  if plate and plate.TPFrame.Active then
    local widget_frame = plate.TPFrame.widgets[Widget.Name]
    if widget_frame.Active then
      Widget:OnUnitAdded(widget_frame, plate.TPFrame.unit)
    end  
  end
end

---------------------------------------------------------------------------------------------------
-- Process events
---------------------------------------------------------------------------------------------------

function Widget:UPDATE_BATTLEFIELD_SCORE()
  --look at the scoreboard and assign healers from there
  for i = 1, GetNumBattlefieldScores() do
    local name, _, _, _, _, _, _, _, _, _, _, _, _, _, _, talentSpec = GetBattlefieldScore(i)
    if UnitIsHealer[name] == nil then
      local is_healer_spec = HEALER_SPECS[talentSpec]
      UnitIsHealer[name] = (is_healer_spec and "HEALER") or "DPS"

      local unit_guid = UnitGUIDByName[unit_name]
      if unit_guid and is_healer_spec then
        UpdateNameplateByGUID(unit_guid)
      end
    end
  end

  BattlefieldScoreDataRequestPending = false
end

-- Combat log parsing for spells is enabled 
--   in battlegrounds (but not in other instances) or
--   in world PvP, i.e, the player has PvP enabled
-- For efficiency reasons, combat log parsing will be disabled in 
--   sanctuaries
--   when leaving combat with a delay of 5 min
function Widget:COMBAT_LOG_EVENT_UNFILTERED(...)
  local _, combatevent, _, sourceGUID, _, _, _, _, _, _, _, spellid = CombatLogGetCurrentEventInfo()
  if sourceGUID and SPELL_EVENTS[combatevent] and not UnitIsHealer[sourceGUID] and HEALER_SPELLS[spellid] then
    UnitIsHealer[sourceGUID] = "HEALER"

    UpdateNameplateByGUID(sourceGUID)

    --local _, combatevent, _, sourceGUID, sourceName, _, _, _, _, _, _, spellid = CombatLogGetCurrentEventInfo()
    --DebugHealerInfoSource[sourceGUID] = { Name = sourceName, Source = "COMBATLOG"}
  end
end

function Widget:PLAYER_ENTERING_WORLD()
  UnitIsHealer = {}
  UnitGUIDByName = {}

  local in_instance, instance_type = IsInInstance()
  PlayerIsInBattleground = (instance_type == "pvp")
  PlayerIsInWorldPvPArea = (instance_type == "none")

  if PlayerIsInBattleground then
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  else
    self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  end
end

-- PLAYER_REGEN_* is only enabled when PvP is enabled for the player
function Widget:PLAYER_REGEN_DISABLED()
  -- Enable/disable combat log parsing for spell detection when entering combat only
  -- in world PvP.
  if CombatLogParsingIsEnabled or not PlayerIsInWorldPvPArea or UnitIsPVPSanctuary("player") then return end

  Widget:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  CombatLogParsingIsEnabled = true
end

local function DisableCombatLogParsing()
  Widget:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  CombatLogParsingIsEnabled = false
end

function Widget:PLAYER_REGEN_ENABLED()
  if not CombatLogParsingIsEnabled then return end

  C_Timer_After(360, function()
    if not InCombatLockdown() then
      DisableCombatLogParsing()
    end
  end)
end

-- MAX_ARENA_ENEMIES is not defined in Classic
local ArenaUnitIdToNumber = {}
for i = 1, (MAX_ARENA_ENEMIES or 5) do
  ArenaUnitIdToNumber["arena" .. i] = i
end

-- Added: Added in 3.1.0 / 1.14.0
function Widget:ARENA_OPPONENT_UPDATE(unitid, update_reason)
  if update_reason ~= "seen" then return end

  -- Unit name can be UNKNOWN here
  local guid = _G.UnitGUID(unitid)
  if not guid then return end

  local spec_id = GetArenaOpponentSpec(ArenaUnitIdToNumber[unitid])
  local role = (HEALER_SPECIALIZATION_ID[spec_id] and "HEALER") or "DPS"
  UnitIsHealer[guid] = role
end

function Widget:PLAYER_FLAGS_CHANGED(unitid)
  -- This function is only registered for the player unit, so no need to check
  -- unitid here
  if UnitIsPVP("player") then
    if not CheckPvPStateIsEnabled then
      self:RegisterEvent("PLAYER_REGEN_ENABLED")
      self:RegisterEvent("PLAYER_REGEN_DISABLED")
      CheckPvPStateIsEnabled = true
    end
  else
    if CheckPvPStateIsEnabled then
      self:UnregisterEvent("PLAYER_REGEN_ENABLED")
      self:UnregisterEvent("PLAYER_REGEN_DISABLED")
      DisableCombatLogParsing()
      CheckPvPStateIsEnabled = false
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local frame = _G.CreateFrame("Frame", nil, tp_frame)
  frame:Hide()

  frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
  frame.Icon = frame:CreateTexture(nil, "OVERLAY")
  frame.Icon:SetAllPoints(frame)

  self:UpdateLayout(frame)

  return frame
end

function Widget:IsEnabled()
  local db = Addon.db.profile.healerTracker
  return db.ON or db.ShowInHeadlineView
end

function Widget:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterUnitEvent("PLAYER_FLAGS_CHANGED", "player")
  
  -- We could register/unregister this when entering/leaving the battlefield, but as it only fires when
  -- in a bg, that does not really matter
  -- We don't need to register this for Classic, as GetBattlefieldScore does not return talentSpec information  
  if Addon.IS_MAINLINE then
    self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
  end

  -- ARENA_OPPONENT_UPDATE uses a player spec to determine its role. 
  -- API function GetArenaOpponentSpec was added in 5.0.4
  if Addon.ExpansionIsAtLeast(LE_EXPANSION_MISTS_OF_PANDARIA) then
    self:RegisterEvent("ARENA_OPPONENT_UPDATE")
  end

  -- It seems that PLAYER_FLAGS_CHANGED does not fire when loggin in/reloading the UI, so we need to call it
  -- directly here to initialize combat log parsing.
  self:PLAYER_FLAGS_CHANGED("player")
end

function Widget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return Addon.db.profile.healerTracker.ShowInHeadlineView
  elseif style ~= "etotem" then
    return Addon.db.profile.healerTracker.ON
  end
end

local PlayerRoleIsHealer
  
if Addon.IS_MAINLINE then
  PlayerRoleIsHealer = function(unit)
    local unit_name = GetUnitName(unit.unitid, true)
    local is_healer = UnitIsHealer[unit_name]
    
    if is_healer == nil then
      -- Battleground: request battlefield score update, World PvP: do nothing
      if PlayerIsInBattleground and not UnitGUIDByName[unit_name] then
        -- Healer is not yet known from battlefield score board, so store it's guid.
        -- So that later, when the healer is found, the healer's namemplate can be updated
        UnitGUIDByName[unit_name] = unit.guid

        if not BattlefieldScoreDataRequestPending then 
          BattlefieldScoreDataRequestPending = true
          RequestBattlefieldScoreData()
        end
      end
      
      -- Fallback: check if unit role is known from combat log parsing or spec (in arenas)
      is_healer = UnitIsHealer[unit.guid]
    end

    return is_healer == "HEALER"
  end
else
  PlayerRoleIsHealer = function(unit)
    return UnitIsHealer[unit.guid] == "HEALER"
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  -- Deathknights can be picked up as 'healers' thanks to Dark Simulacrum, so just ignore them.
  if unit.type ~= "PLAYER" or not HEALER_CLASSES[unit.class] then return end

  -- Don't check for UnitIsPvP or UnitIsPVPSanctuary here as this widget is not updated when PvP status changes
  -- or the player enters a sanctuary. 
  if not Addon.IsInPvPInstance and not PlayerIsInWorldPvPArea then return end

  if PlayerRoleIsHealer(unit) then
    local db = Addon.db.profile.healerTracker
    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
      widget_frame:SetPoint(db.anchor, widget_frame:GetParent(), db.x_hv, db.y_hv)
    else
      widget_frame:SetPoint(db.anchor, widget_frame:GetParent(), db.x, db.y)
    end
  
    widget_frame:Show()
  else
    widget_frame:Hide()
  end
end

function Widget:UpdateLayout(widget_frame)
  local db = Addon.db.profile.healerTracker

  widget_frame:SetSize(db.scale, db.scale)
  widget_frame:SetAlpha(db.alpha)

  widget_frame.Icon:SetTexture("Interface\\Icons\\Achievement_Guild_DoctorIsIn")
end

function Widget:PrintDebug()
  Addon.Logging.Debug(Widget.Name .. ":")
  Addon.Logging.Debug("    Arena or BG:", Addon.IsInPvPInstance)  
  Addon.Logging.Debug("    BG:", PlayerIsInBattleground)
  Addon.Logging.Debug("    World PvP:", PlayerIsInWorldPvPArea)
  Addon.Logging.Debug("    World PvP w/o PvP or Sanctuary:", PlayerIsInWorldPvPArea and UnitIsPVP("player") and not UnitIsPVPSanctuary("player"))
  Addon.Logging.Debug("    Combatlog Partsing enabled:", CombatLogParsingIsEnabled)
  for id, info in pairs(DebugHealerInfoSource) do
    Addon.Logging.Debug("    ", info.Name, "(", id, ")", "=>", info.Source)
  end
end