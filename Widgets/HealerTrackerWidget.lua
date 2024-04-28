-----------------------
-- Healer Tracker Widget
-----------------------
local ADDON_NAME, Addon = ...

local Widget = Addon.Widgets:NewWidget("HealerTracker")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local IsInInstance = IsInInstance
local GetUnitName = GetUnitName
local RequestBattlefieldScoreData, GetNumBattlefieldScores, GetBattlefieldScore = RequestBattlefieldScoreData, GetNumBattlefieldScores, GetBattlefieldScore
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local NotifyInspect, CanInspect, ClearInspectPlayer, GetInspectSpecialization = NotifyInspect, CanInspect, ClearInspectPlayer, GetInspectSpecialization

-- ThreatPlates APIs
local PlatesByGUID = Addon.PlatesByGUID

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

---------------------------------------------------------------------------------------------------
-- Compatibility functions for WoW Classic
---------------------------------------------------------------------------------------------------

-- if not Addon.IS_MAINLINE then
--   NotifyInspect = function() end
-- end

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
  --
  --[2050] = "PRIEST",     -- Holy Word: Serenity
  [596] = "PRIEST",      -- Prayer of Healing
  --[47788] = "PRIEST",    -- Guardian Spirit
  --[88625] = "PRIEST",    -- Holy Word: Chastise
  --[34861] = "PRIEST",    -- Holy Word: Sanctify
  [204883] = "PRIEST",   -- Circle of Healing
  --[372616] = "PRIEST",   -- Empyreal Blaze
  --[64843] = "PRIEST",    -- Divine Hymn
  --[64901] = "PRIEST",    -- Symbol of Hope
  --[200183] = "PRIEST",   -- Apotheosis
  --[265202] = "PRIEST",   -- Holy Word: Salvation
  --[372835] = "PRIEST",   -- Lightwell
  --
  --[197268] = "PRIEST",   -- Ray of Hope
  [289666] = "PRIEST",   -- Greater Heal
  --[328530] = "PRIEST",   -- Divine Ascension
  --[213610] = "PRIEST",   -- Holy Ward
  --[197268] = "PRIEST",   -- Ray of Hope


  -- Discipline Priest
  ----------
  [47540] = "PRIEST",  -- Penance
  --
  [194509] = "PRIEST", -- Power Word: Radiance
  --[33206] = "PRIEST", -- Pain Suppression
  [214621] = "PRIEST", -- Schism
  [129250] = "PRIEST", -- Power Word: Solace
  --[62618] = "PRIEST", -- Power Word: Barrier
  [204197] = "PRIEST", -- Purge of the Wicked
  --[47536] = "PRIEST",  -- Rapture
  [314867] = "PRIEST",  -- Shadow Covenant
  --[373178] = "PRIEST",  -- Light's Wrath
  --[123040] = "PRIEST",  -- Mindbender
  --
  --[197871] = "PRIEST",   -- Dark Archangel
  --[197862] = "PRIEST",   -- Archangel

  -- Druid (The affinity traits on the other specs makes this difficult)
  ---------
  [33763] = "DRUID", -- Lifebloom
  --[17116] = "DRUID", -- Nature's Swiftness
  [102351] = "DRUID", -- Cnenarion Ward
  [33763] = "DRUID", -- Nourish
  [81262] = "DRUID", -- Efflorescence
  --[740] = "DRUID", -- Tranquility
  --[102342] = "DRUID", -- Ironbark
  --[203651] = "DRUID", -- Overgrowth
  --[33891] = "DRUID", -- Incarnation: Tree of Life
  --[391528] = "DRUID", -- Convoke the Spirits
  [391888] = "DRUID", -- Adaptive Swarm -- Shared with Feral
  --[197721] = "DRUID", -- Flourish
  [392160] = "DRUID", -- Invigorate
  --


  -- Shaman
  ---------
  [61295] = "SHAMAN",  -- Riptide
  [77472] = "SHAMAN",  -- Healing Wave
  [73920] = "SHAMAN",  -- Healing Rain
  --[383009] = "SHAMAN",  -- Stormkeeper
  --[52127] = "SHAMAN",  -- Water Shield
  --[98008] = "SHAMAN", -- Spirit Link Totem
  --[157153] = "SHAMAN", -- Cloudburst Totem
  --[108280] = "SHAMAN",  -- Healing Tide Totem
  --[16190] = "SHAMAN", -- Mana Tide Totem
  [73685] = "SHAMAN",  -- Unleash Life
  --[198838] = "SHAMAN",  -- Earthen Wall Totem
  --[207399] = "SHAMAN",  -- Ancestral Protection Totem
  --[375982] = "SHAMAN", -- Primordial Wave
  [207778] = "SHAMAN", -- Downpour
  --[382029] = "SHAMAN", -- Ever-Rising Tide -- was only in Beta available
  --[114052] = "SHAMAN", -- Ascendance
  --[197995] = "SHAMAN", -- Wellspring
  --

  -- Paladin
  ----------
  [275773] = "PALADIN", -- Judgment
  --
  [20473] = "PALADIN", -- Holy Shock
  [82326] = "PALADIN", -- Holy Light
  [85222] = "PALADIN", -- Light of Dawn
  [223306] = "PALADIN", -- Bestow Faith
  --[31821] = "PALADIN", -- Aura Mastery
  [214202] = "PALADIN", -- Rule of Law
  [210294] = "PALADIN", -- Divine Favor
  --[114158] = "PALADIN", -- Light's Hammer
  [114165] = "PALADIN", -- Holy Prism
  --[183998] = "PALADIN", -- Licht des Märtyrers ??? Holy or all Paladins
  --[304971] = "PALADIN", -- Divine Toll  ??? Holy or all Paladins
  --[216331] = "PALADIN", -- Avenging Crusader
  --[384376] = "PALADIN", -- Avenging Wrath ??? Holy or all Paladins
  [148039] = "PALADIN", -- Barrier of Faith
  --[388007] = "PALADIN", -- Blessing of Summer


  -- Monk
  ---------
  [124682] = "MONK", -- Envelopping Mist
  [191837] = "MONK", -- Essence Font
  [115151] = "MONK", -- Renewing Mist
  --[116849] = "MONK", -- Life Cocoon
  [116680] = "MONK", -- Thunder Focus Tea
  --[115310] = "MONK", -- Revival
  --[388615] = "MONK", -- Restoral
  --[198898] = "MONK", -- Song of Chi-Ji
  [124081] = "MONK", -- Zen Pulse
  --[122281] = "MONK", -- Healing Elixir
  --[325197] = "MONK", -- Invoke Chi-Ji, the Red Crane
  --[322118] = "MONK", -- Invoke Yu'lon, the Jade Serpent
  --[196725] = "MONK", -- Refreshing Jade Wind
  --[197908] = "MONK", -- Mana Tea
  --[388193] = "MONK", -- Faeline Stomp
  --[386276] = "MONK", -- Bonedust Brew
  --
  [209584] = "MONK", -- Zen Focus Tea
  [205234] = "MONK", -- Healing Sphere


  -- Evoker - Preservation
  ---------
  [364343] = "EVOKER", -- Echo
  [382614] = "EVOKER", -- Dream Breath
  [366155] = "EVOKER", -- Reversion
  --[366155] = "EVOKER", -- Rewind
  [382731] = "EVOKER", -- Spiritbloom
  --[357170] = "EVOKER", -- Time Dilation
  --[370960] = "EVOKER", -- Emerald Communion
  [373861] = "EVOKER", -- Temporal Anomaly  
  --[359816] = "EVOKER", -- Dream Flight
  --[370537] = "EVOKER", -- Stasis  
  --
  --[377509] = "EVOKER", -- Dream Projection
}

local HEALER_CATA_RETAIL = {
  -- Holy Priest
  ----------
  [2060] = "PRIEST",     -- Heal
  [14914] = "PRIEST",    -- Holy Fire
  --
  --[2050] = "PRIEST",     -- Holy Word: Serenity
  [596] = "PRIEST",      -- Prayer of Healing
  --[47788] = "PRIEST",    -- Guardian Spirit
  --[88625] = "PRIEST",    -- Holy Word: Chastise
  --[34861] = "PRIEST",    -- Holy Word: Sanctify
  [204883] = "PRIEST",   -- Circle of Healing
  --[372616] = "PRIEST",   -- Empyreal Blaze
  --[64843] = "PRIEST",    -- Divine Hymn
  --[64901] = "PRIEST",    -- Symbol of Hope
  --[200183] = "PRIEST",   -- Apotheosis
  --[265202] = "PRIEST",   -- Holy Word: Salvation
  --[372835] = "PRIEST",   -- Lightwell
  --
  --[197268] = "PRIEST",   -- Ray of Hope
  [289666] = "PRIEST",   -- Greater Heal
  --[328530] = "PRIEST",   -- Divine Ascension
  --[213610] = "PRIEST",   -- Holy Ward
  --[197268] = "PRIEST",   -- Ray of Hope


  -- Discipline Priest
  ----------
  [47540] = "PRIEST",  -- Penance
  --
  [194509] = "PRIEST", -- Power Word: Radiance
  --[33206] = "PRIEST", -- Pain Suppression
  [214621] = "PRIEST", -- Schism
  [129250] = "PRIEST", -- Power Word: Solace
  --[62618] = "PRIEST", -- Power Word: Barrier
  [204197] = "PRIEST", -- Purge of the Wicked
  --[47536] = "PRIEST",  -- Rapture
  [314867] = "PRIEST",  -- Shadow Covenant
  --[373178] = "PRIEST",  -- Light's Wrath
  --[123040] = "PRIEST",  -- Mindbender
  --
  --[197871] = "PRIEST",   -- Dark Archangel
  --[197862] = "PRIEST",   -- Archangel

  -- Druid (The affinity traits on the other specs makes this difficult)
  ---------
  [33763] = "DRUID", -- Lifebloom
  --[17116] = "DRUID", -- Nature's Swiftness
  [102351] = "DRUID", -- Cnenarion Ward
  [33763] = "DRUID", -- Nourish
  [81262] = "DRUID", -- Efflorescence
  --[740] = "DRUID", -- Tranquility
  --[102342] = "DRUID", -- Ironbark
  --[203651] = "DRUID", -- Overgrowth
  --[33891] = "DRUID", -- Incarnation: Tree of Life
  --[391528] = "DRUID", -- Convoke the Spirits
  [391888] = "DRUID", -- Adaptive Swarm -- Shared with Feral
  --[197721] = "DRUID", -- Flourish
  [392160] = "DRUID", -- Invigorate
  --


  -- Shaman
  ---------
  [61295] = "SHAMAN",  -- Riptide
  [77472] = "SHAMAN",  -- Healing Wave
  [73920] = "SHAMAN",  -- Healing Rain
  --[383009] = "SHAMAN",  -- Stormkeeper
  --[52127] = "SHAMAN",  -- Water Shield
  --[98008] = "SHAMAN", -- Spirit Link Totem
  --[157153] = "SHAMAN", -- Cloudburst Totem
  --[108280] = "SHAMAN",  -- Healing Tide Totem
  --[16190] = "SHAMAN", -- Mana Tide Totem
  [73685] = "SHAMAN",  -- Unleash Life
  --[198838] = "SHAMAN",  -- Earthen Wall Totem
  --[207399] = "SHAMAN",  -- Ancestral Protection Totem
  --[375982] = "SHAMAN", -- Primordial Wave
  [207778] = "SHAMAN", -- Downpour
  --[382029] = "SHAMAN", -- Ever-Rising Tide -- was only in Beta available
  --[114052] = "SHAMAN", -- Ascendance
  --[197995] = "SHAMAN", -- Wellspring
  --

  -- Paladin
  ----------
  [275773] = "PALADIN", -- Judgment
  --
  [20473] = "PALADIN", -- Holy Shock
  [82326] = "PALADIN", -- Holy Light
  [85222] = "PALADIN", -- Light of Dawn
  [223306] = "PALADIN", -- Bestow Faith
  --[31821] = "PALADIN", -- Aura Mastery
  [214202] = "PALADIN", -- Rule of Law
  [210294] = "PALADIN", -- Divine Favor
  --[114158] = "PALADIN", -- Light's Hammer
  [114165] = "PALADIN", -- Holy Prism
  --[183998] = "PALADIN", -- Licht des Märtyrers ??? Holy or all Paladins
  --[304971] = "PALADIN", -- Divine Toll  ??? Holy or all Paladins
  --[216331] = "PALADIN", -- Avenging Crusader
  --[384376] = "PALADIN", -- Avenging Wrath ??? Holy or all Paladins
  [148039] = "PALADIN", -- Barrier of Faith
  --[388007] = "PALADIN", -- Blessing of Summer


  -- Monk
  ---------
  [124682] = "MONK", -- Envelopping Mist
  [191837] = "MONK", -- Essence Font
  [115151] = "MONK", -- Renewing Mist
  --[116849] = "MONK", -- Life Cocoon
  [116680] = "MONK", -- Thunder Focus Tea
  --[115310] = "MONK", -- Revival
  --[388615] = "MONK", -- Restoral
  --[198898] = "MONK", -- Song of Chi-Ji
  [124081] = "MONK", -- Zen Pulse
  --[122281] = "MONK", -- Healing Elixir
  --[325197] = "MONK", -- Invoke Chi-Ji, the Red Crane
  --[322118] = "MONK", -- Invoke Yu'lon, the Jade Serpent
  --[196725] = "MONK", -- Refreshing Jade Wind
  --[197908] = "MONK", -- Mana Tea
  --[388193] = "MONK", -- Faeline Stomp
  --[386276] = "MONK", -- Bonedust Brew
  --
  [209584] = "MONK", -- Zen Focus Tea
  [205234] = "MONK", -- Healing Sphere


  -- Evoker - Preservation
  ---------
  [364343] = "EVOKER", -- Echo
  [382614] = "EVOKER", -- Dream Breath
  [366155] = "EVOKER", -- Reversion
  --[366155] = "EVOKER", -- Rewind
  [382731] = "EVOKER", -- Spiritbloom
  --[357170] = "EVOKER", -- Time Dilation
  --[370960] = "EVOKER", -- Emerald Communion
  [373861] = "EVOKER", -- Temporal Anomaly  
  --[359816] = "EVOKER", -- Dream Flight
  --[370537] = "EVOKER", -- Stasis  
  --
  --[377509] = "EVOKER", -- Dream Projection
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
  HEALER_SPELLS = HEALER_CATA_RETAIL
else
  HEALER_SPELLS = HEALER_SPELLS_RETAIL
end

---------------------------------------------------------------------------------------------------
-- Variables
---------------------------------------------------------------------------------------------------
local HealerByName = {}
local HealerByGUID = {}
--local IsBattleground
local BattlefieldScoreDataRequestPending = false
local DebugHealerInfoSource = {}

---------------------------------------------------------------------------------------------------
-- Functions
---------------------------------------------------------------------------------------------------

local function RegisterHealerByGUID(unit_guid, unit_is_healer)
  HealerByGUID[unit_guid] = unit_is_healer

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
    
    --HealerByName[name] = HEALER_SPECS[talentSpec] ~= nil
    if HealerByName[name] == nil then
      HealerByName[name] = HEALER_SPECS[talentSpec] ~= nil
    end
  end

  BattlefieldScoreDataRequestPending = false
end

-- * It seems that scoreboard and combatlog will catch all healers before any inspect information
-- * is received, so disabling this for the time being
-- function Widget:INSPECT_READY(inspecteeGUID)
--   if HealerByGUID[inspecteeGUID] == nil then 
--     local plate = PlatesByGUID[inspecteeGUID]
--     if plate then
--       local specialization_id = GetInspectSpecialization(plate.TPFrame.unit.unitid)
--       RegisterHealerByGUID(inspecteeGUID, HEALER_SPECIALIZATION_ID[specialization_id] ~= nil)
      
--       DebugHealerInfoSource[inspecteeGUID] = HEALER_SPECIALIZATION_ID[specialization_id] and { Name = plate.TPFrame.unit.name, Source = "INSPECT"} or nil
--     end
--   end
  
--   ClearInspectPlayer()
-- end

--triggered when enter and leave instances
function Widget:PLAYER_ENTERING_WORLD()
  HealerByName = {}
  HealerByGUID = {}

  -- local _, instance_type = IsInInstance()
  -- if instance_type == "pvp" then
  --   --IsBattleground = true
    
  --   self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  --   -- if Addon.IS_MAINLINE then
  --   --   self:RegisterEvent("INSPECT_READY")
  --   -- end
  -- else
  --   --IsBattleground = false
    
  --   self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  --   -- if Addon.IS_MAINLINE then
  --   --   self:UnregisterEvent("INSPECT_READY")
  --   -- end
  -- end
end

function Widget:COMBAT_LOG_EVENT_UNFILTERED(...)
  local _, combatevent, _, sourceGUID, sourceName, _, _, _, _, _, _, spellid = CombatLogGetCurrentEventInfo()
  --local _, combatevent, _, sourceGUID, _, _, _, _, _, _, _, spellid = CombatLogGetCurrentEventInfo()

  if sourceGUID and SPELL_EVENTS[combatevent] and not HealerByGUID[sourceGUID] and HEALER_SPELLS[spellid] then
    RegisterHealerByGUID(sourceGUID, true)

    --DebugHealerInfoSource[sourceGUID] = { Name = sourceName, Source = "COMBATLOG"}
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local frame = _G.CreateFrame("Frame", nil, tp_frame)
  frame:Hide()

  -- Custom Code III
  --------------------------------------
  frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
  frame.Icon = frame:CreateTexture(nil, "OVERLAY")
  frame.Icon:SetAllPoints(frame)
  --------------------------------------
  -- End Custom Code

  return frame
end

function Widget:IsEnabled()
  local db = Addon.db.profile.healerTracker
  return db.ON or db.ShowInHeadlineView
end

function Widget:OnEnable()
  -- We could register/unregister this when entering/leaving the battlefield, but as it only fires when
  -- in a bg, that does not really matter
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  if Addon.IS_MAINLINE then
    -- We don't need to register this for Classic, as GetBattlefieldScore does not return talentSpec information
    self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
  end
end

function Widget:EnabledForStyle(style, unit)
  -- Deathknights can be picked up as 'healers' thanks to Dark Simulacrum, so just ignore them.
  if unit.type ~= "PLAYER" or not HEALER_CLASSES[unit.class] then return false end

  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return Addon.db.profile.healerTracker.ShowInHeadlineView
  elseif style ~= "etotem" then
    return Addon.db.profile.healerTracker.ON
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  -- if not IsBattleground then
  --   widget_frame:Hide()
  --   return
  -- end

  -- HealerByGUID or HealerByName
  --    true:  Healer
  --    false: No healer
  --    nil:   Not yet checked
  local unit_is_healer = HealerByGUID[unit.guid]
  if unit_is_healer == nil then
    -- Healer identified via scoreboard?
    unit_is_healer = HealerByName[GetUnitName(unit.unitid, true)]
    if unit_is_healer == nil then
      -- if CanInspect(unit.unitid) then
      --   NotifyInspect(unit.unitid)    
      -- end

      if not BattlefieldScoreDataRequestPending then 
        BattlefieldScoreDataRequestPending = true
        RequestBattlefieldScoreData()
      end
    else
      HealerByGUID[unit.guid] = unit_is_healer
      
      --DebugHealerInfoSource[unit.guid] = { Name = unit.name, Source = "SCOREBOARD"}
    end
  end

  if unit_is_healer then
    local db = Addon.db.profile.healerTracker

    widget_frame:SetSize(db.scale, db.scale)
    widget_frame:SetAlpha(db.alpha)

    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
      widget_frame:SetPoint(db.anchor, widget_frame:GetParent(), db.x_hv, db.y_hv)
    else
      widget_frame:SetPoint(db.anchor, widget_frame:GetParent(), db.x, db.y)
    end
  
    widget_frame.Icon:SetTexture("Interface\\Icons\\Achievement_Guild_DoctorIsIn")
    
    widget_frame:Show()
  else
    widget_frame:Hide()
  end
end

function Widget:PrintDebug()
  Addon.Logging.Debug(Widget.Name .. ":")
  for guid, info in pairs(DebugHealerInfoSource) do
    Addon.Logging.Debug("    ", info.Name, "(", guid, ")", "=>", info.Source)
  end
end