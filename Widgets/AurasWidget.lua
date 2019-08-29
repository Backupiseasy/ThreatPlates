---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Auras Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewWidget("Auras")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local GetTime = GetTime
local pairs = pairs
local floor, ceil = floor, ceil
local sort = sort
local tonumber = tonumber

-- WoW APIs
local CreateFrame, GetFramerate = CreateFrame, GetFramerate
local DebuffTypeColor = DebuffTypeColor
local UnitAura, UnitIsUnit, UnitReaction = UnitAura, UnitIsUnit, UnitReaction
local UnitAffectingCombat = UnitAffectingCombat
local GetNamePlates, GetNamePlateForUnit = C_NamePlate.GetNamePlates, C_NamePlate.GetNamePlateForUnit
local IsInInstance = IsInInstance

-- ThreatPlates APIs
local LibCustomGlow = Addon.LibCustomGlow
local TidyPlatesThreat = TidyPlatesThreat
local Animations = Addon.Animations
local Font = Addon.Font

local LibClassicDurations = LibStub("LibClassicDurations")
LibClassicDurations:Register("ThreatPlates")

---------------------------------------------------------------------------------------------------
-- Aura Highlighting
---------------------------------------------------------------------------------------------------

local CUSTOM_GLOW_FUNCTIONS = {
  Button = { "ButtonGlow_Start", "ButtonGlow_Stop", 8 },
  Pixel = { "PixelGlow_Start", "PixelGlow_Stop", 3 },
  AutoCast = { "AutoCastGlow_Start", "AutoCastGlow_Stop", 4 },
}

---------------------------------------------------------------------------------------------------
-- Auras Widget Functions
---------------------------------------------------------------------------------------------------

local AuraTooltip = CreateFrame("GameTooltip", "ThreatPlatesAuraTooltip", UIParent, "GameTooltipTemplate")

local GRID_LAYOUT = {
  LEFT = {
    BOTTOM =  {"BOTTOMLEFT", 1, 1},
    TOP =     {"TOPLEFT", 1, -1}
  },
  RIGHT = {
    BOTTOM =  {"BOTTOMRIGHT", -1, 1 },
    TOP =     {"TOPRIGHT", -1 , -1}
  },
}

Widget.TEXTURE_BORDER = Addon.ADDON_DIRECTORY .. "Artwork\\squareline"

-- Debuffs are color coded, with poison debuffs having a green border, magic debuffs a blue border, diseases a brown border,
-- urses a purple border, and physical debuffs a red border
Widget.AURA_TYPE = { Curse = 1, Disease = 2, Magic = 3, Poison = 4, }

Widget.FLASH_DURATION = Addon.Animations.FLASH_DURATION
Widget.ANCHOR_POINT_SETPOINT = Addon.ANCHOR_POINT_SETPOINT
Widget.PRIORITY_FUNCTIONS = {
  None = function(aura) return 0 end,
  AtoZ = function(aura) return aura.name end,
  TimeLeft = function(aura) return aura.expiration - GetTime() end,
  Duration = function(aura) return aura.duration end,
  Creation = function(aura) return aura.expiration - aura.duration end,
}
Widget.CenterAurasPositions = {}
Widget.UnitAuraList = {}

local LOC_CHARM = 1         -- Aura: Possess
local LOC_FEAR = 2          -- Mechanic: Fleeing
local LOC_POLYMORPH = 3     -- Aura: Change Model,
local LOC_STUN = 4          -- Aura: Stun
local LOC_INCAPACITATE = 5
local LOC_SLEEP = 6         -- Mechanic: Asleep
local LOC_DISORIENT = 7     -- Aura: Confuse
local LOC_BANISH = 8
local LOC_HORROR = 9

-- Polymorph: Aura: Pacify & Silence
-- Hex: Aura: Confuse

local PC_SNARE = 50         -- Mechanic: Snared
local PC_ROOT = 51          -- Mechanic: Rooted
local PC_DAZE = 52
local PC_GRIP = 53
local PC_DISARM = 54        -- Apply Aura: Disarm
local PC_DPUSHBACK = 55     -- Apply Aura: Disarm

local CC_SILENCE = 101

Widget.CROWD_CONTROL_SPELLS = {
  -- Druid
  [339] = PC_ROOT,                -- Entangling Roots
  [5211] = LOC_STUN,              -- Mighty Bash (Talent)
  [61391] = PC_DAZE,              -- Typhoon (Talent)
  [102359] = PC_ROOT,             -- Mass Entanglement (Talent)
  [2637] = LOC_SLEEP,             -- Hibernate
  [45334] = LOC_SLEEP,             -- Immobilized from Wild Charge (Bear) (Blizzard)
  [50259] = LOC_SLEEP,             -- Dazed from Wild Charge (Cat)
  -- Balance Druid
  [81261] = CC_SILENCE,           -- Solar Beam
  [209753] = LOC_BANISH,          -- Cyclone (Honor)
  [209749] = PC_DISARM,          -- Faerie Swarm (Honor) & PC_SNARE
  -- Feral Druid
  [163505] = LOC_STUN,            -- Rake
  [203123] = LOC_STUN,            -- Maim
  -- Guardian Druid
  [99] = LOC_INCAPACITATE,        -- Incapacitating Roar
  [202244] = LOC_INCAPACITATE,    -- Overrun (Honor)
  -- Restoration Druid
  [127797] = PC_DAZE,             -- Ursol's Vortex
  [33786] = LOC_BANISH,           -- Cyclone (Honor)

  -- Death Knight
  [273977] = PC_SNARE,            -- Grip of the Dead (Talent)
  [45524] = PC_SNARE,             -- Chains of Ictggtse
  [111673] = LOC_CHARM,           -- Control Undead
  --[77606] = LOC_CHARM,            -- Dark Simulacrum (Honor) -- no CC aura
  -- Blood
  [221562] = LOC_STUN,            -- Asphyxiate (Blood, Blizzard)
  [47476] = CC_SILENCE,           -- Strangulate (Honor)
  -- Frost
  [108194] = LOC_STUN,            -- Asphyxiate (Unholy/Frost, Blizzard)
  [207167] = LOC_DISORIENT,       -- Blinding Sleet (Talent, Blizzard)
  [204085] = PC_ROOT,             -- Deathchill (Honor)
  [204206] = PC_SNARE,            -- Chilled from Chill Streasek (Honor)
  [233395] = PC_ROOT,             -- Frozen Center (Honor)
  [279303] = PC_SNARE,            -- Frost Breath from Frostwyrm's Fury (Talent)
  --[211793] = PC_SNARE,            -- Remorseless Winter - not shown because uptime to high
  -- Unholy
  [200646] = PC_SNARE,            -- Unholy Mutation (Honor)

  -- Demon Hunter
  [217832] = LOC_INCAPACITATE,     -- Imprison (Blizzard)
  [221527] = LOC_INCAPACITATE,     -- Imprison with PvP talent Detainment (Blizzard)
  -- Vengeance Demon Hunter
  [207685] = LOC_DISORIENT,        -- Sigil of Misery (Blizzard)
  [204490] = CC_SILENCE,           -- Sigil of Silence (Blizzard)
  [204843] = PC_SNARE,             -- Sigil of Chains
  [205630] = LOC_STUN,             -- Illidan's Grasp
  [208618] = LOC_STUN,             -- Illidan's Grasp Stun
  -- Havoc Demon Hunter
  [179057] = LOC_STUN,             -- Chaos Nova (Blizzard)
  [200166] = LOC_STUN,             -- Metamorphosis (Blizzard)
  [198813] = PC_SNARE,             -- Vengeful Retreat
  [213405] = PC_SNARE,             -- Master of the Glaive (Talent)
  [211881] = LOC_STUN,             -- Fel Eruption (Talent, Blizzard)

  -- Hunter
  [5116] = PC_DAZE,             -- Concussive Shot
  [3355] = LOC_INCAPACITATE,    -- Freezing Trap (Blizzard)
  [24394] = LOC_STUN,           -- Intimidation (Blizzard)
  [117405] = PC_ROOT,           -- Binding Shot
  [202914] = CC_SILENCE,        -- Spider Sting (Honor)
  [135299] = PC_SNARE,          -- Tar Trap (Honor)
  --[147362] = CC_SILENCE,        -- Counter Shot
  -- Beast Mastery
  -- Marksmanship
  [213691] = LOC_INCAPACITATE,  -- Scatter Shot (Honor)
  [186387] = PC_SNARE,          -- Bursting Shot
  -- Survival
  [162480] = LOC_INCAPACITATE,  -- Steel Trap (Blizzard)
  [212638] = PC_ROOT,           -- Tracker's Net
  [190927] = PC_ROOT,           -- Harpoon
  [195645] = PC_SNARE,          -- Wing Clip
  [203337] = LOC_INCAPACITATE,  -- Freezing Trap with Diamond Ice
  --[187707] = CC_SILENCE,        -- Muzzle

  -- Mage
  [61780] = LOC_POLYMORPH,  -- Polymorph (Turkey)
  [161353] = LOC_POLYMORPH, -- Polymorph (Polar Bear Cub)
  [28272] = LOC_POLYMORPH,  -- Polymorph (Pig)
  [28271] = LOC_POLYMORPH,  -- Polymorph (Turtle)
  [161354] = LOC_POLYMORPH, -- Polymorph (Monkey)
  [118] = LOC_POLYMORPH,    -- Polymorph (Sheep)
  [126819] = LOC_POLYMORPH, -- Polymorph (Porcupine)
  [61305] = LOC_POLYMORPH,  -- Polymorph (Black Cat)
  [61721] = LOC_POLYMORPH,  -- Polymorph (Rabbit)
  [161372] = LOC_POLYMORPH, -- Polymorph (Peacock)
  [161355] = LOC_POLYMORPH, -- Polymorph (Penguin)
  [277787] = LOC_POLYMORPH, -- Polymorph (Direhorn)
  [277792] = LOC_POLYMORPH, -- Polymorph (Bumblebee)
  -- [2139] = CC_SILENCE,      -- Counterspell -- does not leave a debuff on target
  [122] = PC_ROOT,          -- Frost Nova (Blizzard)
  [82691] = LOC_STUN,       -- Ring of Frost (Talent, Blizzard)
  -- Arcane Mage
  [31589] = PC_SNARE,       -- Slow
  [236299] = PC_SNARE,      -- Arcane Barrage with Chrono Shift (Talent)
  -- Fire Mage
  [31661] = LOC_DISORIENT,  -- Dragon's Breath (Blizzard)
  [2120] = PC_SNARE,        -- Flamestrike
  [157981] = PC_SNARE,      -- Blast Wave (Talent)
  -- Frost Mage
  -- [205708] = PC_SNARE,      -- Chilled
  [33395] = PC_ROOT,        -- Freeze (Blizzard)
  [212792] = PC_SNARE,      -- Cone of Cold
  [157997] = PC_ROOT,       -- Ice Nova (Talent)
  [228600] = PC_ROOT,       -- Glacial Spike (Talent, Blizzard)

  -- Paladin
  [20066] = LOC_INCAPACITATE,   -- Repentance (Blizzard)
  [853] = LOC_STUN,             -- Hammer of Jeustice (Blizzard)
  [105421] = LOC_DISORIENT,     -- Blinding Light (Blizzard)
  --[96231] = CC_SILENCE,       -- Rebuke
  -- Holy
  -- Protection
  [31935] = CC_SILENCE,         -- Avenger's Shield (Blizzard)
  [217824] = CC_SILENCE,        -- Shield of Virtue
  --[204242] = PC_SNARE,        -- Consecrated Ground - same aura as Consecration
  -- Retribution
  -- [205273] = PC_SNARE,       -- Wake of Ashes - from Artefact weapon
  [255937] = PC_SNARE,          -- Wake of Ashes - Talent
  [183218] = PC_SNARE,          -- Hand of Hindrance

  -- Priest
  [8122] = LOC_FEAR,            -- Psychic Scream (Blizzard)
  [605] = LOC_CHARM,            -- Mind Control (Blizzard)
  [204263] = PC_SNARE,          -- Shining Force
  [9484] = LOC_POLYMORPH,       -- Shackle Undead (Blizzard)
  -- Discipline
  -- Holy
  [200200] = LOC_STUN,          -- Censure for Holy Word: Chastise
  [200196] = LOC_INCAPACITATE,  -- Holy Word: Chastise (Blizzard)
  -- Shadow
  [205369] = LOC_STUN,          -- Mind Bomb (Blizzard)
  [15487] = CC_SILENCE,         -- Silence (Blizzard)
  [64044] = LOC_STUN,           -- Psychic Horror (Blizzard)
  --[15407] = PC_SNARE,           -- Mind Flay - not shown as very high uptime
  [87204] = LOC_FEAR,           -- Sin and Punishment, fear effect after dispell of Vampiric Touch ?87204

  -- Rogue
  [1833] = LOC_STUN,       -- Cheap Shot (Blizzard)
  [6770] = LOC_STUN,       -- Sap (Blizzard)
  [2094] = LOC_DISORIENT,  -- Blind
  [408] = LOC_STUN,        -- Kidney Shot (Blizzard)
  [212183] = LOC_STUN,     -- Smoke Bomb (Honor)
  [248744] = PC_SNARE,     -- Shiv (Honor)
  [1330] = CC_SILENCE,     -- Garrote (Blizzard)
  -- Assassination
  -- [3409] = LOC_STUN,    -- Crippling Poison - Not shown as 100% uptime
  -- Outlaw
  [207777] = PC_DISARM,    -- Dismantle (Honor)
  [1776] = LOC_STUN,       -- Gouge (Blizzard)
  [185763] = PC_SNARE,     -- Pistol Shot
  [199804] = LOC_STUN,     -- Between the Eyes (Blizzard)
  -- Subtlety
  [206760] = PC_SNARE,     -- Night Terrors

  -- Shaman
  [51514] = LOC_POLYMORPH,      -- Hex (Frog) (Blizzard)
  [210873] = LOC_POLYMORPH,     -- Hex (Compy) (Blizzard)
  [211004] = LOC_POLYMORPH,     -- Hex (Spider) (Blizzard)
  [211010] = LOC_POLYMORPH,     -- Hex (Snake) (Blizzard)
  [211015] = LOC_POLYMORPH,     -- Hex (Cockroach) (Blizzard)
  [269352] = LOC_POLYMORPH,     -- Hex (Skeletal Hatchling) (Blizzard)
  [277778] = LOC_POLYMORPH,     -- Hex (Zandalari Tendonripper) (Blizzard)
  [277784] = LOC_POLYMORPH,     -- Hex (Wicker Mongrel) (Blizzard)
  [118905] = LOC_STUN,          -- Static Charge from Capacitor Totem
  -- [57994] = CC_SILENCE,         -- Wind Shear
  [3600] = PC_SNARE,            -- Earthbind Totem
  -- Elemental
  [51490] = PC_SNARE,           -- Thunderstorm
  [204399] = LOC_STUN,          -- Stun aura from Earthfury (Honor)
  [196840] = PC_SNARE,          -- Frost Shock
  [204437] = LOC_STUN,          -- Lightning Lasso (Honor)
  -- Enhancement
  -- [196834] = PC_SNARE,          -- Frostbrand - Not shown as ability is part of the rotation
  [197214] = LOC_INCAPACITATE,  -- Sundering
  -- [197385] = PC_SNARE,          -- Fury of Air - Not shown as too much uptime
  -- Restoration
  [64695] = PC_ROOT,            -- Earthgrab Totem (Blizzard)

  -- Warlock
  [6789] = LOC_INCAPACITATE,  -- Mortal Coil (Blizzard)s
  [118699] = LOC_FEAR,        -- Fear (Blizzard)
  [710] = LOC_BANISH,         -- Banish (Blizzard)
  [30283] = LOC_STUN,         -- Shadowfury (Blizzard)
  -- [19647] = LOC_STUN,         -- Spell Lock aura from Call Felhunter
  [1098] = LOC_CHARM,         -- Enslave Demon
  [6358] = LOC_DISORIENT,     -- Seduction from Command Demon (Apply Aura: Stun) (Blizzard)
  -- Affliction
  [278350] = PC_SNARE,        -- Vile Taint
  [196364] = CC_SILENCE,      -- Unstable Affliction, silence effect after dispell of Unstable Affliction
  -- Demonology
  [213688] = LOC_STUN,        -- Fel Cleave aura from Call Fel Lord (Honor)
  -- Destruction
  [233582] = PC_SNARE,        -- Entrenched in Flame

  -- Warrior
  [105771] = PC_ROOT,       -- Intercept - Charge
  [5246] = LOC_FEAR,        -- Intimidating Shout (Blizzard)
  [132169] = LOC_STUN,      -- Storm Bolt (Talent, Blizzard)
  --[6552] = CC_SILENCE,      -- Pummel -- does not leave a debuff on target
  -- Arms Warrior
  [1715] = PC_SNARE,        -- Hamstring
  [236077] = PC_DISARM,      -- Disarm (PvP)
  -- Fury Warrior
  [12323] = PC_SNARE,       -- Piercing Howl
  -- Protection Warrior
  [132168] = LOC_STUN,      -- Shockwave (Blizzard)
  [118000] = LOC_STUN,      -- Dragon Roar (Talent, Blizzard)
  -- [6343] = PC_SNARE,        -- Thunder Clap
  [199042] = LOC_STUN,      -- Thunderstruck (PvP, Blizzard)
  [199085] = LOC_STUN,      -- Warpath (PvP, Blizzard)

  -- Monk
  -- [116189] = PC_SNARE,      -- Provoke
  [115078] = LOC_STUN,      -- Paralysis (Blizzard)se
  -- [116705] = CC_SILENCE,    -- Spear Hand Strike
  [119381] = LOC_STUN,      -- Leg Sweep (Blizzard)
  [233759] = PC_DISARM,     -- Grapple Weapon
  -- Brewmaster
  -- [121253] = PC_SNARE,      -- Keg Smash - not shown as high uptime
  -- [196733] = PC_SNARE,      -- Special Delivery - not shown as high uptime
  [202274] = LOC_DISORIENT, -- Incendiary Brew from Incendiary Breath
  [202346] = LOC_STUN,      -- Double Barrel
  -- Mistweaver
  [198909] = LOC_DISORIENT, -- Song of Chi-Ji (Blizzard)
  -- Windwalker
  [116095] = PC_SNARE,      -- Disable
  [123586] = PC_SNARE,      -- Flying Serpent Kick

  -- Racial Traits
  [255723] = LOC_STUN,      -- Bull Rush (Highmountain Tauren)
  [20549] = LOC_STUN,       -- War Stomp (Tauren)
  [260369] = PC_SNARE,      -- Arcane Pulse (Nightborne)
  [107079] = LOC_STUN,      -- Quaking Palm (Pandarian)
}

---------------------------------------------------------------------------------------------------
-- Global attributes
---------------------------------------------------------------------------------------------------
local PLayerIsInInstance = false
--local PLayerIsInCombat = false

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local HideOmniCC, ShowDuration
local AuraHighlightEnabled, AuraHighlightStart, AuraHighlightStop, AuraHighlightStopPrevious, AuraHighlightOffset
local AuraHighlightColor = { 0, 0, 0, 0 }

---------------------------------------------------------------------------------------------------
-- OnUpdate code - updates the auras remaining uptime and stacks and hides them after they expired
---------------------------------------------------------------------------------------------------

local function OnUpdateAurasWidget(widget_frame, elapsed)
  -- Update the number of seconds since the last update
  widget_frame.TimeSinceLastUpdate = widget_frame.TimeSinceLastUpdate + elapsed

  local widget = widget_frame.Widget
  if widget_frame.TimeSinceLastUpdate >= widget.UpdateInterval then
    widget_frame.TimeSinceLastUpdate = 0

    local aura_frame
    for i = 1, widget_frame.Debuffs.ActiveAuras do
      aura_frame = widget_frame.Debuffs.AuraFrames[i]
      widget:UpdateWidgetTime(aura_frame, aura_frame.AuraExpiration, aura_frame.AuraDuration)
    end

    for i = 1, widget_frame.Buffs.ActiveAuras do
      aura_frame = widget_frame.Buffs.AuraFrames[i]
      widget:UpdateWidgetTime(aura_frame, aura_frame.AuraExpiration, aura_frame.AuraDuration)
    end

    for i = 1, widget_frame.CrowdControl.ActiveAuras do
      aura_frame = widget_frame.CrowdControl.AuraFrames[i]
      widget:UpdateWidgetTime(aura_frame, aura_frame.AuraExpiration, aura_frame.AuraDuration)
    end
  end
end

local function OnShowHookScript(widget_frame)
  widget_frame.TimeSinceLastUpdate = 0
end

--local function OnHideHookScript(widget_frame)
--  widget_frame:UnregisterAllEvents()
--end

---------------------------------------------------------------------------------------------------
-- Filtering and sorting functions
---------------------------------------------------------------------------------------------------

function Widget:GetColorForAura(aura)
	local db = self.db

  if aura.type and db.ShowAuraType then
    return DebuffTypeColor[aura.type]
  elseif aura.effect == "HARMFUL" then
    return db.DefaultDebuffColor
  else
    return db.DefaultBuffColor
	end
end

local function FilterAll(show_aura, spellfound, is_mine, show_only_mine)
  return show_aura
end

local function FilterWhitelist(show_aura, spellfound, is_mine, show_only_mine)
  if spellfound == "All" then
    return show_aura
  elseif spellfound == true then
    return (show_only_mine == nil and show_aura) or (show_aura and ((show_only_mine and is_mine) or show_only_mine == false))
  elseif spellfound == "My" then
    return show_aura and is_mine
  end

  return false
end

local function FilterBlacklist(show_aura, spellfound, is_mine, show_only_mine)
  -- blacklist all auras, i.e., default is show all auras (no matter who casted it)
  --   spellfound = true or All - blacklist this aura (from all casters)
  --   spellfound = My          - blacklist only my aura
  --   spellfound = nil         - show aura (spell not found in blacklist)
  --   spellfound = Not         - show aura (found entry not relevant, ignore it)

  if spellfound == "All" or spellfound == true then
    return false
  elseif spellfound == "My" then
    return not is_mine
  elseif spellfound == "Not" then
    return true
  end

  return show_aura
end

Widget.FILTER_FUNCTIONS = {
  all = FilterAll,
  blacklist = FilterBlacklist,
  whitelist = FilterWhitelist,
}

function Widget:FilterFriendlyDebuffsBySpell(db, aura, AuraFilterFunction)
  local show_aura = db.ShowAllFriendly or
                    (db.ShowBlizzardForFriendly and (aura.ShowAll or (aura.ShowPersonal and aura.CastByPlayer))) or
                    (db.ShowDispellable and aura.StealOrPurge) or
                    (db.ShowBoss and aura.BossDebuff) or
                    (aura.type and db.FilterByType[self.AURA_TYPE[aura.type]])

  local spellfound = self.AuraFilterDebuffs[aura.name] or self.AuraFilterDebuffs[aura.spellid]

  return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)
end

function Widget:FilterEnemyDebuffsBySpell(db, aura, AuraFilterFunction)
  local show_aura = db.ShowAllEnemy or
                    (db.ShowOnlyMine and aura.CastByPlayer) or
                    (db.ShowBlizzardForEnemy and (aura.ShowAll or (aura.ShowPersonal and aura.CastByPlayer)))

  local spellfound = self.AuraFilterDebuffs[aura.name] or self.AuraFilterDebuffs[aura.spellid]

  return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer, db.ShowOnlyMine)
end

function Widget:FilterFriendlyBuffsBySpell(db, aura, AuraFilterFunction, unit)
  local show_aura = db.ShowAllFriendly or
                    (db.ShowOnFriendlyNPCs and unit.type == "NPC") or
                    (db.ShowOnlyMine and aura.CastByPlayer) or
                    (db.ShowPlayerCanApply and aura.PlayerCanApply)

  local spellfound = self.AuraFilterBuffs[aura.name] or self.AuraFilterBuffs[aura.spellid]

  return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)
end

function Widget:FilterEnemyBuffsBySpell(db, aura, AuraFilterFunction, unit)
  local show_aura
  if aura.duration <= 0 and db.HideUnlimitedDuration then
    show_aura = false
  else
    show_aura = db.ShowAllEnemy or (db.ShowOnEnemyNPCs and unit.type == "NPC") or (db.ShowDispellable and aura.StealOrPurge) or
                (aura.type == "Magic" and db.ShowMagic)
  end

  --  local show_aura = db.ShowAllEnemy or (db.ShowOnEnemyNPCs and unit.type == "NPC") or (db.ShowDispellable and aura.StealOrPurge)
  local spellfound = self.AuraFilterBuffs[aura.name] or self.AuraFilterBuffs[aura.spellid]

  show_aura = AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)

  -- Checking unlimited auras after filter function results in the filter list not being able to overwrite
  -- the "Show Unlimited Buffs" settings
  if show_aura and (aura.duration <= 0) then
    show_aura =  db.ShowUnlimitedAlways or
                (db.ShowUnlimitedInCombat and unit.isInCombat) or
                (db.ShowUnlimitedInInstances and PLayerIsInInstance) or
                (db.ShowUnlimitedOnBosses and unit.IsBossOrRare)
    unit.HasUnlimitedAuras = true
  end

  return show_aura
end

function Widget:FilterFriendlyCrowdControlBySpell(db, aura, AuraFilterFunction)
  local show_aura = db.ShowAllFriendly or
                    (db.ShowBlizzardForFriendly and (aura.ShowAll or (aura.ShowPersonal and aura.CastByPlayer))) or
                    (db.ShowDispellable and aura.StealOrPurge) or
                    (db.ShowBoss and aura.BossDebuff)

  local spellfound = self.AuraFilterCrowdControl[aura.name] or self.AuraFilterCrowdControl[aura.spellid]

  return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)
end

function Widget:FilterEnemyCrowdControlBySpell(db, aura, AuraFilterFunction)
  local show_aura = db.ShowAllEnemy or
                    (db.ShowBlizzardForEnemy and (aura.ShowAll or (aura.ShowPersonal and aura.CastByPlayer)))

  local spellfound = self.AuraFilterCrowdControl[aura.name] or self.AuraFilterCrowdControl[aura.spellid]

  return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)
end

Widget.AuraSortFunctionAtoZ = function(a, b)
  return a.priority < b.priority
end

Widget.AuraSortFunctionNum = function(a, b)
  if a.duration == 0 then
    return false
  elseif b.duration == 0 then
    return true
  end

  return a.priority < b.priority
end

-------------------------------------------------------------
-- Widget Object Functions
-------------------------------------------------------------

function Widget:UpdateUnitAuras(frame, unit, enabled_auras, enabled_cc, SpellFilter, SpellFilterCC, filter_mode)
  local aura_frames = frame.AuraFrames
  if not (enabled_auras or enabled_cc) then
    for i = 1, self.MaxAurasPerGrid do
      aura_frames[i]:Hide()
    end
    frame.ActiveAuras = 0
    frame:Hide()

    -- Also for frame:GetParent().CrowdControl?
    return
  end

  local UnitAuraList = self.UnitAuraList
  local db = self.db
  -- Optimization for auras sorting
  local sort_order = db.SortOrder
  if sort_order ~= "None" then
    UnitAuraList = {}
  end

  local widget_frame = frame:GetParent()
  unit.HasUnlimitedAuras = false
  local effect = frame.Filter
  local unitid = unit.unitid

  local db_auras = (effect == "HARMFUL" and db.Debuffs) or db.Buffs
  local AuraFilterFunction = self.FILTER_FUNCTIONS[filter_mode]
  local AuraFilterFunctionCC = self.FILTER_FUNCTIONS[db.CrowdControl.FilterMode]
  local GetAuraPriority = self.PRIORITY_FUNCTIONS[sort_order]

  local aura, show_aura
  local aura_count = 1
  local isCastByPlayer
  for i = 1, 40 do
    show_aura = false

    -- Auras are evaluated by an external function - pre-filtering before the icon grid is populated
    UnitAuraList[aura_count] = UnitAuraList[aura_count] or {}
    aura = UnitAuraList[aura_count]

    -- Blizzard Code:local name, texture, count, debuffType, duration, expirationTime, caster, _, nameplateShowPersonal, spellId, _, _, _, nameplateShowAll = UnitAura(unit, i, filter);
    --aura.name, aura.texture, aura.stacks, aura.type, aura.duration, aura.expiration, aura.caster,
    --  aura.StealOrPurge, aura.ShowPersonal, aura.spellid, aura.PlayerCanApply, aura.BossDebuff, isCastByPlayer, aura.ShowAll =
    --  UnitAura(unitid, i, effect)

    aura.name, aura.texture, aura.stacks, aura.type, aura.duration, aura.expiration, aura.caster,
    aura.StealOrPurge, aura.ShowPersonal, aura.spellid, aura.PlayerCanApply, aura.BossDebuff, isCastByPlayer, aura.ShowAll =
    LibClassicDurations:UnitAura(unitid, i, effect)

    -- ShowPesonal: Debuffs  that are shown on Blizzards nameplate, no matter who casted them (and
    -- ShowAll: Debuffs
    if not aura.name then break end

    --aura.unit = unitid
    aura.Index = i
    aura.effect = effect
    aura.ShowAll = aura.ShowAll
    aura.CrowdControl = (enabled_cc and self.CROWD_CONTROL_SPELLS[aura.spellid])
    aura.CastByPlayer = (aura.caster == "player" or aura.caster == "pet" or aura.caster == "vehicle")

    -- Store Order/Priority
    if aura.CrowdControl then
      show_aura = SpellFilterCC(self, db.CrowdControl, aura, AuraFilterFunctionCC)

      -- Show crowd control auras that are not shown in Blizard mode as normal debuffs
      if not show_aura and enabled_auras then
        aura.CrowdControl = false
        show_aura = SpellFilter(self, db_auras, aura, AuraFilterFunction)
      end
    elseif enabled_auras then
      show_aura = SpellFilter(self, db_auras, aura, AuraFilterFunction, unit)

      --      if show_aura and effect == "HELPFUL" and unit.reaction ~= "FRIENDLY" then
      --        unit.HasUnlimitedAuras = unit.HasUnlimitedAuras or (aura.duration <= 0)
      --        show_aura = self:FilterEnemyBuffsBySpellDynamic(db_auras, aura, unit)
      --      end
    end

    if show_aura then
      aura.color = self:GetColorForAura(aura)
      aura.priority = GetAuraPriority(aura)

      aura_count = aura_count + 1
    end
  end

  -- Sort all auras
  if sort_order == "None" then
    -- invalidate all entries after storedAuraCount
    -- if number of auras to show was decreased, remove any overflow aura frames
    local i = aura_count
    aura = UnitAuraList[i]
    while aura do
      aura.priority = nil
      i = i + 1
      aura = UnitAuraList[i]
    end
  else
    UnitAuraList[aura_count] = nil
  end

  aura_count = aura_count - 1

  -- Show auras
  local max_auras_no = aura_count -- min(aura_count, CONFIG_AuraLimit)
  if self.MaxAurasPerGrid < max_auras_no then
    max_auras_no = self.MaxAurasPerGrid
  end

  local aura_count_cc = 1
  if aura_count > 0 then
    if sort_order ~= "None" then
      if sort_order == "AtoZ" then
        sort(UnitAuraList, self.AuraSortFunctionAtoZ)
      else
        sort(UnitAuraList, self.AuraSortFunctionNum)
      end
    end

    local index_start, index_end, index_step
    if db.SortReverse then
      index_start, index_end, index_step = max_auras_no, 1, -1
    else
      index_start, index_end, index_step = 1, max_auras_no, 1
    end

    aura_count = 1
    aura_count_cc = 1
    local aura_frames_cc = widget_frame.CrowdControl.AuraFrames

    for index = index_start, index_end, index_step do
      aura = UnitAuraList[index]

      if aura.spellid and aura.expiration then
        local aura_frame
        if aura.CrowdControl then
          aura_frame = aura_frames_cc[aura_count_cc]
          aura_count_cc = aura_count_cc + 1
        else
          aura_frame = aura_frames[aura_count]
          aura_count = aura_count + 1
        end

        aura_frame.AuraName = aura.name
        aura_frame.AuraDuration = aura.duration
        aura_frame.AuraTexture = aura.texture
        aura_frame.AuraExpiration = aura.expiration
        aura_frame.AuraStacks = aura.stacks
        aura_frame.AuraColor = aura.color
        aura_frame.AuraStealOrPurge = aura.StealOrPurge

        -- Information for aura tooltips
        aura_frame.AuraIndex = aura.Index

        -- Call function to display the aura
        self:UpdateAuraInformation(aura_frame)
      end
    end

  end
  aura_count_cc = aura_count_cc - 1

  aura_count = max_auras_no - aura_count_cc
  frame.ActiveAuras = aura_count
  -- Clear extra slots
  for i = aura_count + 1, self.MaxAurasPerGrid do
    aura_frames[i]:Hide()
    AuraHighlightStop(aura_frames[i].Highlight)
  end

  if effect == "HARMFUL" then
    local aura_frames_cc = widget_frame.CrowdControl
    aura_frames_cc.ActiveAuras = aura_count_cc

    local aura_frame_list_cc = aura_frames_cc.AuraFrames
    for i = aura_count_cc + 1, self.MaxAurasPerGrid do
      aura_frame_list_cc[i]:Hide()
    end
  end

end

function Widget:UpdatePositionAuraGrid(frame, y_offset)
  local db = self.db

  local auras_no = frame.ActiveAuras
  if auras_no == 0 then
    frame:Hide()
  else
    local anchor = self.ANCHOR_POINT_SETPOINT[db.anchor]

    frame:ClearAllPoints()
    if self.IconMode and db.CenterAuras then
      if auras_no > self.GridNoCols then
        auras_no = self.GridNoCols
      end

      frame:SetPoint(anchor[2], frame:GetParent():GetParent(), anchor[1], db.x + self.CenterAurasPositions[auras_no], db.y + y_offset)
      frame:SetHeight(ceil(frame.ActiveAuras / self.GridNoCols) * (self.AuraHeight + self.AuraWidgetOffset))
    else
      frame:SetPoint(anchor[2], frame:GetParent():GetParent(), anchor[1], db.x, db.y + y_offset)
      frame:SetHeight(ceil(frame.ActiveAuras / self.GridNoCols) * (self.AuraHeight + self.AuraWidgetOffset))
    end

    frame:Show()
  end
end

function Widget:UpdateIconGrid(widget_frame, unit)
  local db = self.db
  local unitid = unit.unitid

  if db.ShowTargetOnly then
    if not UnitIsUnit("target", unitid) then
      widget_frame:Hide()
      return
    end

    self.CurrentTarget = widget_frame
  end

  local enabled_cc
  local unit_is_friendly = UnitReaction(unitid, "player") > 4
  if unit_is_friendly then -- friendly or better
    enabled_cc = db.CrowdControl.ShowFriendly

    self:UpdateUnitAuras(widget_frame.Debuffs, unit, db.Debuffs.ShowFriendly, enabled_cc, self.FilterFriendlyDebuffsBySpell, self.FilterFriendlyCrowdControlBySpell, db.Debuffs.FilterMode)
    self:UpdateUnitAuras(widget_frame.Buffs, unit, db.Buffs.ShowFriendly, false, self.FilterFriendlyBuffsBySpell, self.FilterFriendlyCrowdControlBySpell, db.Buffs.FilterMode)
  else
    enabled_cc = db.CrowdControl.ShowEnemy

    self:UpdateUnitAuras(widget_frame.Debuffs, unit, db.Debuffs.ShowEnemy, enabled_cc, self.FilterEnemyDebuffsBySpell, self.FilterEnemyCrowdControlBySpell, db.Debuffs.FilterMode)
    self:UpdateUnitAuras(widget_frame.Buffs, unit, db.Buffs.ShowEnemy, false, self.FilterEnemyBuffsBySpell, self.FilterEnemyCrowdControlBySpell, db.Buffs.FilterMode)
  end

  local buffs_active, debuffs_active, cc_active = widget_frame.Buffs.ActiveAuras > 0, widget_frame.Debuffs.ActiveAuras > 0, widget_frame.CrowdControl.ActiveAuras > 0

  if buffs_active or debuffs_active or cc_active then
    local frame_auras_one, frame_auras_two
    local auras_one_active, auras_two_active
    local scale_auras_one, scale_auras_two

    if unit_is_friendly then
      frame_auras_one, frame_auras_two = widget_frame.Buffs, widget_frame.Debuffs
      auras_one_active, auras_two_active = buffs_active, debuffs_active
      if db.SwitchScaleByReaction then
        scale_auras_one, scale_auras_two = db.Debuffs.Scale, db.Buffs.Scale
      else
        scale_auras_one, scale_auras_two = db.Buffs.Scale, db.Debuffs.Scale
      end
    else
      frame_auras_one, frame_auras_two = widget_frame.Debuffs, widget_frame.Buffs
      auras_one_active, auras_two_active = debuffs_active, buffs_active
      scale_auras_one, scale_auras_two = db.Debuffs.Scale, db.Buffs.Scale
    end

    local scale_cc = db.CrowdControl.Scale

    -- Position the different aura frames so that they are stacked one above the other
    local y_offset = (db.y / scale_auras_one) - db.y
    self:UpdatePositionAuraGrid(frame_auras_one, y_offset)

    local height_auras_one = (auras_one_active and (frame_auras_one:GetHeight() * scale_auras_one)) or 0
    y_offset = (height_auras_one / scale_auras_two) + (db.y / scale_auras_two) - db.y
    self:UpdatePositionAuraGrid(frame_auras_two, y_offset)

    if enabled_cc then
      y_offset = ((auras_two_active and (frame_auras_two:GetHeight() * scale_auras_two / scale_cc)) or 0)
      y_offset = y_offset + (height_auras_one / scale_cc) + (db.y / scale_cc) - db.y
      self:UpdatePositionAuraGrid(widget_frame.CrowdControl, y_offset)
    else
      widget_frame.CrowdControl:Hide()
    end

    widget_frame:Show()
  else
    widget_frame:Hide()
  end
end

---------------------------------------------------------------------------------------------------
-- Functions for cooldown handling incl. OmniCC support
---------------------------------------------------------------------------------------------------

local function CreateCooldown(parent)
  -- When the cooldown shares the frameLevel of its parent, the icon texture can sometimes render
  -- ontop of it. So it looks like it's not drawing a cooldown but it's just hidden by the icon.

  local cooldown_frame = CreateFrame("Cooldown", nil, parent, "ThreatPlatesAuraWidgetCooldown")
  cooldown_frame:SetAllPoints(parent.Icon)
  cooldown_frame:SetReverse(true)
  cooldown_frame:SetHideCountdownNumbers(true)
  cooldown_frame.noCooldownCount = HideOmniCC

  return cooldown_frame
end

local function UpdateCooldown(cooldown_frame, db)
  if db.ShowCooldownSpiral then
    cooldown_frame:SetDrawEdge(true)
    cooldown_frame:SetDrawSwipe(true)
  else
    cooldown_frame:SetDrawEdge(false)
    cooldown_frame:SetDrawSwipe(false)
  end

  -- Fix for OmnniCC cooldown numbers being shown on auras
  if cooldown_frame.noCooldownCount ~= HideOmniCC then
    cooldown_frame.noCooldownCount = HideOmniCC
    -- Force an update on OmniCC cooldowns
    cooldown_frame:Hide()
    cooldown_frame:Show()
  end
end

local function SetCooldown(cooldown_frame, duration, expiration)
  if duration and expiration and duration > 0 and expiration > 0 then
    cooldown_frame:SetCooldown(expiration - duration, duration + .25)
  else
    cooldown_frame:Clear()
  end
end

---------------------------------------------------------------------------------------------------
-- Functions for showing tooltips on auras
---------------------------------------------------------------------------------------------------

local function AuraFrameOnEnter(self)
  AuraTooltip:SetOwner(self, "ANCHOR_LEFT")
  AuraTooltip:SetUnitAura(self:GetParent():GetParent().unit.unitid, self.AuraIndex, self:GetParent().Filter)
end

local function AuraFrameOnLeave(self)
  AuraTooltip:Hide()
end

---------------------------------------------------------------------------------------------------
-- Functions for the aura grid with icons
---------------------------------------------------------------------------------------------------

function Widget:CreateAuraFrameIconMode(parent)
  local db = self.db_icon

  local frame = CreateFrame("Frame", nil, parent)
  frame:SetFrameLevel(parent:GetFrameLevel())

  frame.Icon = frame:CreateTexture(nil, "ARTWORK", 0)
  frame.Border = CreateFrame("Frame", nil, frame)
  frame.Border:SetFrameLevel(parent:GetFrameLevel())
  frame.Cooldown = CreateCooldown(frame)

  frame.Highlight = CreateFrame("Frame", nil, frame)
  frame.Highlight:SetFrameLevel(parent:GetFrameLevel())
  frame.Highlight:SetPoint("CENTER")

  -- Use a seperate frame for text elements as a) using frame as parent results in the text being shown below
  -- the cooldown frame and b) using the cooldown frame results in the text not being visible if there is no
  -- cooldown (i.e., duration and expiration are nil which is true for auras with unlimited duration)
  local text_frame = CreateFrame("Frame", nil, frame)
  text_frame:SetFrameLevel(parent:GetFrameLevel() + 9) -- +9 as the glow is set to +8 by LibCustomGlow
  text_frame:SetAllPoints(frame.Icon)
  frame.Stacks = text_frame:CreateFontString(nil, "OVERLAY")
  frame.TimeLeft = text_frame:CreateFontString(nil, "OVERLAY")

  frame:Hide()

  return frame
end

function Widget:UpdateAuraFrameIconMode(frame)
  local db = self.db

  UpdateCooldown(frame.Cooldown, db)
  if ShowDuration then
    frame.TimeLeft:Show()
  else
    frame.TimeLeft:Hide()
  end

  -- Add tooltips to icons
  if db.ShowTooltips then
    frame:SetScript("OnEnter", AuraFrameOnEnter)
    frame:SetScript("OnLeave", AuraFrameOnLeave)
  else
    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)
  end

  db = self.db_icon
  -- Icon
  frame:SetSize(db.IconWidth, db.IconHeight)
  frame.Icon:SetAllPoints(frame)
  --frame.Icon:SetTexCoord(.07, 1-.07, .23, 1-.23) -- Style: Widee
  frame.Icon:SetTexCoord(.10, 1-.07, .12, 1-.12)  -- Style: Square - remove border from icons

  if db.ShowBorder then
    local offset, edge_size, inset = 2, 8, 0
    frame.Border:ClearAllPoints()
    frame.Border:SetPoint("TOPLEFT", frame, "TOPLEFT", -offset, offset)
    frame.Border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offset, -offset)
    frame.Border:SetBackdrop({
      edgeFile = self.TEXTURE_BORDER,
      edgeSize = edge_size,
      insets = { left = inset, right = inset, top = inset, bottom = inset },
    })
    frame.Border:SetBackdropBorderColor(0, 0, 0, 1)
    frame.Border:Show()

  else
    frame.Border:Hide()
  end

  AuraHighlightStopPrevious(frame.Highlight)
  if AuraHighlightEnabled then
    frame.Highlight:SetSize(frame:GetWidth() + AuraHighlightOffset, frame:GetHeight() + AuraHighlightOffset)
  end

  Font:UpdateText(frame, frame.TimeLeft, db.Duration)
  Font:UpdateText(frame, frame.Stacks, db.StackCount)
end

function Widget:UpdateAuraInformationIconMode(frame) -- texture, duration, expiration, stacks, color, name)
  local duration = frame.AuraDuration
  local expiration = frame.AuraExpiration
  local stacks = frame.AuraStacks
  local color = frame.AuraColor

  -- Expiration
  self:UpdateWidgetTime(frame, expiration, duration)

  local db = self.db
  if db.ShowStackCount and stacks > 1 then
    frame.Stacks:SetText(stacks)
  else
    frame.Stacks:SetText("")
  end

  frame.Icon:SetTexture(frame.AuraTexture)

  -- Highlight Coloring
  if db.ModeIcon.ShowBorder then
    if db.ShowAuraType then
      frame.Border:SetBackdropBorderColor(color.r, color.g, color.b, 1)
    end
  end

  if AuraHighlightEnabled then
    if frame.AuraStealOrPurge then
      AuraHighlightStart(frame.Highlight, AuraHighlightColor)
    else
      AuraHighlightStop(frame.Highlight)
    end
  end

  SetCooldown(frame.Cooldown, duration, expiration)
  Animations:StopFlash(frame)

  frame:Show()
end

function Widget:UpdateWidgetTimeIconMode(frame, expiration, duration)
  if expiration == 0 then
    frame.TimeLeft:SetText("")
    Animations:StopFlash(frame)
  else
    local timeleft = expiration - GetTime()
    if timeleft > 60 then
      frame.TimeLeft:SetText(floor(timeleft/60).."m")
    else
      frame.TimeLeft:SetText(floor(timeleft))
    end

    local db = self.db
    if db.FlashWhenExpiring and timeleft < db.FlashTime then
      Animations:Flash(frame, self.FLASH_DURATION)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Functions for the aura grid with bars
---------------------------------------------------------------------------------------------------

function Widget:CreateAuraFrameBarMode(parent)
  local db = self.db_bar
  local font = ThreatPlates.Media:Fetch('font', db.Font)

  -- frame is probably not necessary, should be ok do add everything to the statusbar frame
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetFrameLevel(parent:GetFrameLevel())

  frame.Statusbar = CreateFrame("StatusBar", nil, frame)
  frame.Statusbar:SetFrameLevel(parent:GetFrameLevel())
  frame.Statusbar:SetMinMaxValues(0, 100)

  frame.Background = frame.Statusbar:CreateTexture(nil, "BACKGROUND", 0)
  frame.Background:SetAllPoints()

  frame.Highlight = CreateFrame("Frame", nil, frame)
  frame.Highlight:SetFrameLevel(parent:GetFrameLevel())

  frame.Icon = frame:CreateTexture(nil, "OVERLAY", 1)
  frame.Stacks = frame.Statusbar:CreateFontString(nil, "OVERLAY")

  frame.LabelText = frame.Statusbar:CreateFontString(nil, "OVERLAY")
  frame.LabelText:SetFont(font, db.FontSize)
  frame.LabelText:SetJustifyH("LEFT")
  frame.LabelText:SetShadowOffset(1, -1)
  frame.LabelText:SetMaxLines(1)

  frame.TimeText = frame.Statusbar:CreateFontString(nil, "OVERLAY")
  frame.TimeText:SetFont(font, db.FontSize)
  frame.TimeText:SetJustifyH("RIGHT")
  frame.TimeText:SetShadowOffset(1, -1)

  frame.Cooldown = CreateCooldown(frame)

  frame:Hide()

  return frame
end

function Widget:UpdateAuraFrameBarMode(frame)
  local db = self.db

  UpdateCooldown(frame.Cooldown, db)
  if ShowDuration then
    frame.TimeText:Show()
  else
    frame.TimeText:Hide()
  end

  -- Add tooltips to icons
  if db.ShowTooltips then
    frame:SetScript("OnEnter", AuraFrameOnEnter)
    frame:SetScript("OnLeave", AuraFrameOnLeave)
  else
    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)
  end

  db = self.db_bar
  local font = ThreatPlates.Media:Fetch('font', db.Font)

  -- width and position calculations
  local frame_width = db.BarWidth
  if db.ShowIcon then
    frame_width = frame_width + db.BarHeight + db.IconSpacing
  end
  frame:SetSize(frame_width, db.BarHeight)

  frame.Background:SetTexture(ThreatPlates.Media:Fetch('statusbar', db.BackgroundTexture))
  frame.Background:SetVertexColor(db.BackgroundColor.r, db.BackgroundColor.g, db.BackgroundColor.b, db.BackgroundColor.a)

  frame.LabelText:SetPoint("LEFT", frame.Statusbar, "LEFT", db.LabelTextIndent, 0)
  frame.LabelText:SetFont(font, db.FontSize)
  frame.LabelText:SetTextColor(db.FontColor.r, db.FontColor.g, db.FontColor.b)

  frame.TimeText:SetPoint("RIGHT", frame.Statusbar, "RIGHT", - db.TimeTextIndent, 0)
  frame.TimeText:SetFont(font, db.FontSize)
  frame.TimeText:SetTextColor(db.FontColor.r, db.FontColor.g, db.FontColor.b)

  frame.Icon:ClearAllPoints()
  frame.Statusbar:ClearAllPoints()

  if db.ShowIcon then
    if db.IconAlignmentLeft then
      frame.Icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
      frame.Statusbar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", db.BarHeight + db.IconSpacing, 0)
    else
      frame.Icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", db.BarWidth + db.IconSpacing, 0)
      frame.Statusbar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    end
    frame.Stacks:SetPoint("CENTER", frame.Icon, "CENTER")
    --frame.Stacks:SetAllPoints(frame.Icon)
    --frame.Stacks:SetSize(db.BarHeight, db.BarHeight)
    frame.Stacks:SetJustifyH("CENTER")
    frame.Stacks:SetFont(font, db.FontSize, "OUTLINE")
    frame.Stacks:SetShadowOffset(1, -1)
    frame.Stacks:SetShadowColor(0,0,0,1)
    frame.Stacks:SetTextColor(db.FontColor.r, db.FontColor.g, db.FontColor.b)

    frame.Icon:SetTexCoord(0, 1, 0, 1)
    frame.Icon:SetSize(db.BarHeight, db.BarHeight)
    frame.Icon:Show()
  else
    frame.Statusbar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.Icon:Hide()
  end

  AuraHighlightStopPrevious(frame.Highlight)
  if AuraHighlightEnabled then
    local aura_highlight = frame.Highlight

    aura_highlight:ClearAllPoints()
    if self.db.Highlight.Type == "ActionButton" then
      -- Align to icon because of bad scaling otherwise
      local offset = - (AuraHighlightOffset * 0.5)
      if db.IconAlignmentLeft then
        aura_highlight:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", offset, offset)
      else
        aura_highlight:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", db.BarWidth + db.IconSpacing + offset, offset)
      end
      aura_highlight:SetSize(db.BarHeight + AuraHighlightOffset, db.BarHeight + AuraHighlightOffset)
    else
      aura_highlight:SetPoint("CENTER")
      aura_highlight:SetSize(frame:GetWidth() + AuraHighlightOffset, frame:GetHeight() + AuraHighlightOffset)
    end
  end

  frame.Statusbar:SetSize(db.BarWidth, db.BarHeight)
  --    frame.Statusbar:SetWidth(db.BarWidth)
  frame.Statusbar:SetStatusBarTexture(ThreatPlates.Media:Fetch('statusbar', db.Texture))
  frame.Statusbar:GetStatusBarTexture():SetHorizTile(false)
  frame.Statusbar:GetStatusBarTexture():SetVertTile(false)
--    frame.Statusbar:Show()
end

function Widget:UpdateAuraInformationBarMode(frame) -- texture, duration, expiration, stacks, color, name)
  local db = self.db

  local duration = frame.AuraDuration
  local expiration = frame.AuraExpiration
  local stacks = frame.AuraStacks
  local color = frame.AuraColor

  -- Expiration
  self:UpdateWidgetTime(frame, expiration, duration)

  if db.ShowStackCount and stacks > 1 then
    if HideOmniCC then
      frame.Stacks:SetText(stacks)
    else
      frame.Stacks:SetText("")
      frame.AuraName = frame.AuraName .. " (" .. stacks .. ")"
    end
  else
    frame.Stacks:SetText("")
  end

  -- Icon
  if db.ModeBar.ShowIcon then
    frame.Icon:SetTexture(frame.AuraTexture)
  end

  if AuraHighlightEnabled then
    if frame.AuraStealOrPurge then
      AuraHighlightStart(frame.Highlight, AuraHighlightColor)
    else
      AuraHighlightStop(frame.Highlight)
    end
  end

  frame.LabelText:SetWidth(self.LabelLength - frame.TimeText:GetStringWidth())
  frame.LabelText:SetText(frame.AuraName)
  -- Highlight Coloring
  frame.Statusbar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)

  SetCooldown(frame.Cooldown, duration, expiration)
  Animations:StopFlash(frame)

  frame:Show()
end

function Widget:UpdateWidgetTimeBarMode(frame, expiration, duration)
  if duration == 0 then
    frame.TimeText:SetText("")
    frame.Statusbar:SetValue(100)
    Animations:StopFlash(frame)
  elseif expiration == 0 then
    frame.TimeText:SetText("")
    frame.Statusbar:SetValue(0)
    Animations:StopFlash(frame)
  else
    local db = self.db

    local timeleft = expiration - GetTime()

    if db.ShowDuration then
      if timeleft > 60 then
        frame.TimeText:SetText(floor(timeleft/60).."m")
      else
        frame.TimeText:SetText(floor(timeleft))
      end

      if db.FlashWhenExpiring and timeleft < db.FlashTime then
        Animations:Flash(frame, self.FLASH_DURATION)
      end
    else
      frame.TimeText:SetText("")

      if db.FlashWhenExpiring and timeleft < db.FlashTime then
        Animations:Flash(frame, self.FLASH_DURATION)
      end
    end

    frame.Statusbar:SetValue(timeleft * 100 / duration)
  end
end

function Widget:UpdateWidgetTimeBarModeNoDuration(frame, expiration, duration)
  if duration == 0 then
    frame.Statusbar:SetValue(100)
    Animations:StopFlash(frame)
  elseif expiration == 0 then
    frame.Statusbar:SetValue(0)
    Animations:StopFlash(frame)
  else
    local timeleft = expiration - GetTime()
    if timeleft > 60 then
      frame.TimeText:SetText(floor(timeleft/60).."m")
    else
      frame.TimeText:SetText(floor(timeleft))
    end

    local db = self.db
    if db.FlashWhenExpiring and timeleft < db.FlashTime then
      Animations:Flash(frame, self.FLASH_DURATION)
    end

    frame.Statusbar:SetValue(timeleft * 100 / duration)
  end
end

---------------------------------------------------------------------------------------------------
-- Creation and update functions
---------------------------------------------------------------------------------------------------

function Widget:CreateAuraGrid(frame)
  local aura_frame_list = frame.AuraFrames
  local pos_x, pos_y

  local aura_frame
  for i = 1, self.MaxAurasPerGrid do
    aura_frame = aura_frame_list[i]
    if aura_frame == nil then
      aura_frame = self:CreateAuraFrame(frame)
      aura_frame_list[i] = aura_frame
    else
      if self.IconMode then
        if not aura_frame.Border then
          aura_frame:Hide()
          aura_frame = self:CreateAuraFrame(frame)
          aura_frame_list[i] = aura_frame
        end
      else
        if not aura_frame.Statusbar then
          aura_frame:Hide()
          aura_frame = self:CreateAuraFrame(frame)
          aura_frame_list[i] = aura_frame
        end
      end
    end

    local align_layout = self.AlignLayout

    pos_x = (i - 1) % self.GridNoCols
    pos_x = (pos_x * self.AuraWidth + self.AuraWidgetOffset) * align_layout[2]

    pos_y = floor((i - 1) / self.GridNoCols)
    pos_y = (pos_y * self.AuraHeight + self.AuraWidgetOffset) * align_layout[3]

    -- anchor the frame
    aura_frame:ClearAllPoints()
    aura_frame:SetPoint(align_layout[1], frame, pos_x, pos_y)

    self:UpdateAuraFrame(aura_frame)
  end

  -- if number of auras to show was decreased, remove any overflow aura frames
  for i = #aura_frame_list, self.MaxAurasPerGrid + 1, -1 do
    aura_frame_list[i]:Hide()
    aura_frame_list[i] = nil
  end

  frame:SetSize(self.AuraWidgetWidth, self.AuraWidgetHeight)
end

-- Initialize the aura grid layout, don't update auras themselves as not unitid know at this point
function Widget:UpdateAuraWidgetLayout(widget_frame)
  self:CreateAuraGrid(widget_frame.Buffs)
  self:CreateAuraGrid(widget_frame.Debuffs)
  self:CreateAuraGrid(widget_frame.CrowdControl)

  if ShowDuration or not self.IconMode then
    widget_frame:SetScript("OnUpdate", OnUpdateAurasWidget)
  else
    widget_frame:SetScript("OnUpdate", nil)
  end

  if self.db.FrameOrder == "HEALTHBAR_AURAS" then
    widget_frame:SetFrameLevel(widget_frame:GetParent():GetFrameLevel() + 3)
  else
    widget_frame:SetFrameLevel(widget_frame:GetParent():GetFrameLevel() + 9)
  end
  widget_frame.Buffs:SetFrameLevel(widget_frame:GetFrameLevel())
  widget_frame.Debuffs:SetFrameLevel(widget_frame:GetFrameLevel())
  widget_frame.CrowdControl:SetFrameLevel(widget_frame:GetFrameLevel())
end

local function UnitAuraEventHandler(widget_frame, event, unitid)
  --  -- Skip player (cause TP does not handle player nameplate) and target (as it is updated via it's actual unitid anyway)
  --  if unitid == "player" or unitid == "target" then return end

  if widget_frame.Active then
    widget_frame.Widget:UpdateIconGrid(widget_frame, widget_frame:GetParent().unit)
  end
end

function Widget:PLAYER_TARGET_CHANGED()
  if not self.db.ShowTargetOnly then return end

  if self.CurrentTarget then
    self.CurrentTarget:Hide()
    self.CurrentTarget = nil
  end

  local plate = GetNamePlateForUnit("target")
  if plate and plate.TPFrame.Active then
    self.CurrentTarget = plate.TPFrame.widgets.Auras

    if self.CurrentTarget.Active then
      self:UpdateIconGrid(self.CurrentTarget, plate.TPFrame.unit)
    end
  end
end

function Widget:PLAYER_REGEN_ENABLED()
  -- It seems that unitid here can be nil when using the healthstone while in combat
  -- assert (unit.unitid ~= nil, "Auras: PLAYER_REGEN_ENABLED - unitid =", unit.unitid)

  local frame
  for _, plate in pairs(GetNamePlates()) do
    frame = plate and plate.TPFrame
    if frame and frame.Active then
      local widget_frame = frame.widgets.Auras
      local unit = frame.unit

      if widget_frame.Active and unit.HasUnlimitedAuras then
        unit.isInCombat = UnitAffectingCombat(unit.unitid)
        self:UpdateIconGrid(widget_frame, unit)
      end
    end
  end
end

function Widget:PLAYER_REGEN_DISABLED()
  --PLayerIsInCombat = true

  for plate, _ in pairs(Addon.PlatesVisible) do
    local widget_frame = plate.TPFrame.widgets.Auras
    local unit = plate.TPFrame.unit

    if widget_frame.Active and unit.HasUnlimitedAuras then
      unit.isInCombat = UnitAffectingCombat(unit.unitid)
      self:UpdateIconGrid(widget_frame, unit)
    end
  end
end

function Widget:PLAYER_ENTERING_WORLD()
  PLayerIsInInstance = IsInInstance()
end


---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------
  widget_frame:SetSize(10, 10)
  widget_frame:SetPoint("CENTER", tp_frame, "CENTER")

  widget_frame.Debuffs = CreateFrame("Frame", nil, widget_frame)
  widget_frame.Debuffs.AuraFrames = {}
  widget_frame.Debuffs.ActiveAuras = 0
  widget_frame.Debuffs.Filter = "HARMFUL"

  widget_frame.Buffs = CreateFrame("Frame", nil, widget_frame)
  widget_frame.Buffs.AuraFrames = {}
  widget_frame.Buffs.ActiveAuras = 0
  widget_frame.Buffs.Filter = "HELPFUL"

  widget_frame.CrowdControl = CreateFrame("Frame", nil, widget_frame)
  widget_frame.CrowdControl.AuraFrames = {}
  widget_frame.CrowdControl.ActiveAuras = 0
  widget_frame.CrowdControl.Filter = "HARMFUL"

  widget_frame.Widget = self

  self:UpdateAuraWidgetLayout(widget_frame)

  widget_frame:SetScript("OnEvent", UnitAuraEventHandler)
  widget_frame:HookScript("OnShow", OnShowHookScript)
  -- widget_frame:HookScript("OnHide", OnHideHookScript)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  self.db = TidyPlatesThreat.db.profile.AuraWidget
  return self.db.ON or self.db.ShowInHeadlineView
end

function Widget:OnEnable()
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  -- LOSS_OF_CONTROL_ADDED
  -- LOSS_OF_CONTROL_UPDATE
end

function Widget:OnDisable()
  self:UnregisterAllEvents()
  for plate, _ in pairs(Addon.PlatesVisible) do
    plate.TPFrame.widgets.Auras:UnregisterAllEvents()
  end
end

function Widget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return self.db.ShowInHeadlineView
  elseif style ~= "etotem" then
    return self.db.ON
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  local db = self.db

  if db.SwitchScaleByReaction and UnitReaction(unit.unitid, "player") > 4 then
    widget_frame.Buffs:SetScale(db.Debuffs.Scale)
    widget_frame.Debuffs:SetScale(db.Buffs.Scale)
  else
    widget_frame.Buffs:SetScale(db.Buffs.Scale)
    widget_frame.Debuffs:SetScale(db.Debuffs.Scale)
  end
  widget_frame.CrowdControl:SetScale(db.CrowdControl.Scale)

  widget_frame:UnregisterAllEvents()
  widget_frame:RegisterUnitEvent("UNIT_AURA", unit.unitid)

  self:UpdateIconGrid(widget_frame, unit)
end

function Widget:OnUnitRemoved(widget_frame)
  widget_frame:UnregisterAllEvents()
end

local function ParseFilter(filter_by_spell)
  local filter = {}
  local only_player_auras = true

  local modifier, spell
  for key, value in pairs(filter_by_spell) do
    -- remove comments and whitespaces from the filter (string)
    local pos = value:find("%-%-")
    if pos then value = value:sub(1, pos - 1) end
    value = value:match("^%s*(.-)%s*$")  -- remove any leading/trailing whitespaces from the line

    -- value:match("^%s*(%w+)%s*(.-)%s*$")  -- remove any leading/trailing whitespaces from the line
    if value:sub(1, 4) == "All " then
      modifier = "All"
      spell = value:match("^All%s*(.-)$")
      only_player_auras = false
    elseif value:sub(1, 3) == "My " then
      modifier = "My"
      spell = value:match("^My%s*(.-)$")
    elseif value:sub(1, 4) == "Not " then
      modifier = "Not"
      spell = value:match("^Not%s*(.-)$")
      only_player_auras = false
    else
      modifier = true
      spell = value
    end

    -- separete filter by name and ID for more efficient aura filtering
    local spell_no = tonumber(spell)
    if spell_no then
      filter[spell_no] = modifier
    elseif spell ~= '' then
      filter[spell] = modifier
    end
  end

  return filter
end

function Widget:ParseSpellFilters()
  self.db = TidyPlatesThreat.db.profile.AuraWidget

  self.AuraFilterBuffs = ParseFilter(self.db.Buffs.FilterBySpell)
  self.AuraFilterDebuffs = ParseFilter(self.db.Debuffs.FilterBySpell)
  self.AuraFilterCrowdControl = ParseFilter(self.db.CrowdControl.FilterBySpell)
end

function Widget:UpdateSettingsIconMode()
  self.db_icon = self.db.ModeIcon
  local db = self.db_icon

  self.UpdateInterval = Addon.ON_UPDATE_INTERVAL

  self.GridNoCols = db.Columns
  --self.GridNoRows = db.Rows

  --self.GridSpacingCols = db.ColumnSpacing
  --self.GridSpacingRows = db.RowSpacing

  self.AuraWidgetOffset = (self.db.ShowAuraType and 2) or 1

  self.AuraWidth = db.IconWidth + db.ColumnSpacing
  self.AuraHeight = db.IconHeight + db.RowSpacing

  self.AuraWidgetWidth = (db.IconWidth * db.Columns) + (db.ColumnSpacing * db.Columns) - db.ColumnSpacing + (self.AuraWidgetOffset * 2)
  self.AuraWidgetHeight = (db.IconHeight * db.Rows) + (db.RowSpacing * db.Rows) - db.RowSpacing + (self.AuraWidgetOffset * 2)

  for i = 1, db.Columns do
    local active_auras_width = (db.IconWidth * i) + (db.ColumnSpacing * i) - db.ColumnSpacing + (self.AuraWidgetOffset * 2)
    self.CenterAurasPositions[i] = (self.AuraWidgetWidth - active_auras_width) / 2
  end

  self.MaxAurasPerGrid = db.Rows * db.Columns

  self.CreateAuraFrame = self.CreateAuraFrameIconMode
  self.UpdateAuraFrame = self.UpdateAuraFrameIconMode
  self.UpdateAuraInformation = self.UpdateAuraInformationIconMode
  self.UpdateWidgetTime = self.UpdateWidgetTimeIconMode
end

function Widget:UpdateSettingsBarMode()
  self.db_bar = self.db.ModeBar
  local db = self.db_bar

  self.UpdateInterval = 1 / GetFramerate()

  self.GridNoCols = 1
  --self.GridNoRows = db.MaxBars

  --self.GridSpacingCols = 0
  --self.GridSpacingRows = db.BarSpacing

  self.AuraWidgetOffset = 0

  self.AuraWidth = db.BarWidth
  self.AuraHeight = db.BarHeight + db.BarSpacing

  if db.ShowIcon then
    self.AuraWidgetWidth = db.BarWidth + db.BarHeight + db.IconSpacing
  else
    self.AuraWidgetWidth = db.BarWidth
  end
  self.AuraWidgetHeight = (db.BarHeight * db.MaxBars) + (db.BarSpacing * db.MaxBars) - db.BarSpacing + (self.AuraWidgetOffset * 2)

  self.LabelLength = db.BarWidth - db.LabelTextIndent - db.TimeTextIndent - (db.FontSize / 5)

  self.MaxAurasPerGrid = db.MaxBars

  self.CreateAuraFrame = self.CreateAuraFrameBarMode
  self.UpdateAuraFrame = self.UpdateAuraFrameBarMode
  self.UpdateAuraInformation = self.UpdateAuraInformationBarMode

  if ShowDuration then
    self.UpdateWidgetTime = self.UpdateWidgetTimeBarMode
  else
    self.UpdateWidgetTime = self.UpdateWidgetTimeBarModeNoDuration
  end
end

-- Load settings from the configuration which are shared across all aura widgets
-- used (for each widget) in UpdateWidgetConfig
function Widget:UpdateSettings()
  self.db = TidyPlatesThreat.db.profile.AuraWidget

  self.IconMode = not self.db.ModeBar.Enabled
  if self.IconMode then
    self.UpdateSettingsIconMode(self)
  else
    self.UpdateSettingsBarMode(self)
  end

  self.AlignLayout = GRID_LAYOUT[self.db.AlignmentH][self.db.AlignmentV]

  self:ParseSpellFilters()

  HideOmniCC = not self.db.ShowOmniCC
  ShowDuration = self.db.ShowDuration and not self.db.ShowOmniCC
  --  -- Don't update any widget frame if the widget isn't enabled.
--  if not self:IsEnabled() then return end

  -- Highlighting
  AuraHighlightEnabled = self.db.Highlight.Enabled
  AuraHighlightStart = LibCustomGlow[CUSTOM_GLOW_FUNCTIONS[self.db.Highlight.Type][1]]
  AuraHighlightStopPrevious = AuraHighlightStop or LibCustomGlow.PixelGlow_Stop
  AuraHighlightStop = LibCustomGlow[CUSTOM_GLOW_FUNCTIONS[self.db.Highlight.Type][2]]
  AuraHighlightOffset = CUSTOM_GLOW_FUNCTIONS[self.db.Highlight.Type][3]

  local color = (self.db.Highlight.CustomColor and self.db.Highlight.Color) or ThreatPlates.DEFAULT_SETTINGS.profile.AuraWidget.Highlight.Color
  AuraHighlightColor[1] = color.r
  AuraHighlightColor[2] = color.g
  AuraHighlightColor[3] = color.b
  AuraHighlightColor[4] = color.a

  for plate, tp_frame in pairs(Addon.PlatesCreated) do
    local widget_frame = tp_frame.widgets.Auras

    -- widget_frame could be nil if the widget as disabled and is enabled as part of a profile switch
    -- For these frames, UpdateAuraWidgetLayout will be called anyway when the widget is initalized
    -- (which happens after the settings update)
    if widget_frame then
      self:UpdateAuraWidgetLayout(widget_frame)
      if tp_frame.Active then -- equals: plate is visible, i.e., show currently
        self:OnUnitAdded(widget_frame, widget_frame.unit)
      end
    end
  end

  --Addon:ForceUpdate()
end

