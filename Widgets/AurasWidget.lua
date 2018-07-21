---------------------------------------------------------------------------------------------------
-- Auras Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon:NewWidget("Auras")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local GetTime = GetTime
local pairs = pairs
local floor, ceil = floor, ceil
local sort = sort
local math = math
local string = string
local tonumber = tonumber

-- WoW APIs
local CreateFrame, GetFramerate = CreateFrame, GetFramerate
local DebuffTypeColor = DebuffTypeColor
local UnitAura, UnitIsFriend, UnitIsUnit, UnitReaction, UnitIsPlayer, UnitPlayerControlled = UnitAura, UnitIsFriend, UnitIsUnit, UnitReaction, UnitIsPlayer, UnitPlayerControlled
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local Animations = Addon.Animations
local Font = Addon.Font
local UpdateTextPosition = Addon.Font.UpdateTextPosition
local RGB = ThreatPlates.RGB
local DEBUG = ThreatPlates.DEBUG

-- Default for icon mode is 0.5, for bar mode "1 / GetFramerate()" is used for smooth updates -- GetFramerate() in frames/second
local UPDATE_INTERVAL = Addon.ON_UPDATE_INTERVAL

---------------------------------------------------------------------------------------------------
-- Auras Widget Functions
---------------------------------------------------------------------------------------------------

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

--local TEXTURE_BORDER = Addon.ADDON_DIRECTORY .. "Widgets\\AuraWidget\\TP_AuraFrameBorder"
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
-- Get a clean version of the function...  Avoid OmniCC interference
local CooldownNative = CreateFrame("Cooldown", nil, WorldFrame)
Widget.SetCooldown = CooldownNative.SetCooldown

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

local CC_SILENCE = 101

Widget.CROWD_CONTROL_SPELLS = {
  -- Druid
  [81261] = CC_SILENCE,           -- Solar Beam (Moonkin)
  [339] = PC_ROOT,                -- Entangling Roots
  [5211] = LOC_STUN,              -- Mighty Bash (Talent)
  [61391] = PC_DAZE,              -- Typhoon (Talent)
  [102359] = PC_ROOT,             -- Mass Entanglement (Talent)
  [203123] = LOC_STUN,            -- Maim (Feral)
  [163505] = LOC_STUN,            -- Rake (Feral)
  [99] = LOC_INCAPACITATE,        -- Incapacitating Roar (Guardian)
  [127797] = PC_DAZE,             -- Ursol's Vortex
  [33786] = LOC_BANISH,           -- Cyclone (PvP Talent, Restoration)
  [209753] = LOC_BANISH,          -- Cyclone (PvP Talent, Balance)
  [2637] = LOC_SLEEP,             -- Hibernate

  -- Death Knight
  [108194] = LOC_STUN,             -- Asphyxiate
  [47476] = LOC_STUN,              -- Strangulate (PvP Talent)
  [45524] = PC_SNARE,              -- Chains of Ice
  [111673] = LOC_CHARM,            -- Control Undead

  -- Demon Hunter
  [211881] = LOC_STUN,             -- Fel Eruption (Talent)
  [217832] = LOC_INCAPACITATE,     -- Imprison
  [179057] = LOC_STUN,             -- Chaos Nova

  -- Hunter
  [147362] = CC_SILENCE,        -- Counter Shot
  [19577] = LOC_STUN,           -- Intimidation
  [5116] = PC_DAZE,             -- Concussive Shot
  [187651] = LOC_INCAPACITATE,  -- Freezing Trap
  [213691] = LOC_INCAPACITATE,  -- Scatter Shot
  [19386] = LOC_SLEEP,          -- Wyvern Sting

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
  [113724] = LOC_STUN,      -- Ring of Frost
  [2139] = CC_SILENCE,      -- Counterspell
  [31661] = LOC_DISORIENT,  -- Dragon's Breath
  [122] = PC_ROOT,          -- Frost Nova
  [231596] = PC_ROOT,       -- Freeze (Pet)
  [31589] = PC_SNARE,       -- Slow (Pet)
  [236299] = PC_SNARE,      -- Arcane Barrage + Chrono Shift (Talent)

  -- Paladin
  [853] = LOC_STUN,             -- Hammer of Justice
  [115750] = LOC_DISORIENT,     -- Blinding Light
  [96231] = CC_SILENCE,         -- Rebuke
  [173315] = LOC_INCAPACITATE,  -- Repentance

  -- Priest
  [15487] = CC_SILENCE,      -- Silence
  [205369] = LOC_STUN,       -- Mind Bomb
  [8122] = LOC_FEAR,         -- Psychic Scream
  [605] = LOC_CHARM,         -- Mind Control
  [9484] = LOC_POLYMORPH,    -- Shackle Undead
  [88625] = LOC_STUN,        -- Holy Word: Chastise

  -- Rogue
  [2094] = LOC_DISORIENT,  -- Blind
  [1833] = LOC_STUN,       -- Cheap Shot
  [1776] = LOC_STUN,       -- Gouge
  [408] = LOC_STUN,        -- Kidney Shot
  [6770] = LOC_STUN,       -- Sap

  -- Shaman
  [51485] = PC_ROOT,         -- Earthgrab Totem
  [192058] = LOC_STUN,       -- Lightning Surge Totem
  [2484] = PC_SNARE,         -- Earthbind Totem
  [211015] = LOC_POLYMORPH,  -- Hex (Cockroach)
  [211010] = LOC_POLYMORPH,  -- Hex (Snake)
  [51514] = LOC_POLYMORPH,   -- Hex (Frog)
  [211004] = LOC_POLYMORPH,  -- Hex (Spider)
  [210873] = LOC_POLYMORPH,  -- Hex (Compy)

  -- Warlock
  [6789] = LOC_INCAPACITATE,  -- Mortal Coil
  [5484] = LOC_FEAR,          -- Howl of Terror
  [30283] = LOC_STUN,         -- Shadowfury
  [710] = LOC_BANISH,         -- Banish
  [5782] = LOC_FEAR,          -- Fear

  -- Warrior
  [132168] = LOC_STUN,      -- Shockwave
  [107570] = LOC_STUN,      -- Storm Bolt
  [103828] = LOC_STUN,      -- Warbringer
  [236027] = PC_SNARE,      -- Intercept - Slow
  [105771] = PC_ROOT,       -- Intercept - Charge
  [127724] = PC_ROOT,       -- Intercept - Charge
  [118000] = LOC_STUN,      -- Dragon Roar
  [1715] = PC_SNARE,        -- Hamstring
  [5246] = LOC_FEAR,        -- Intimidating Shout

  -- Monk
  [115078] = LOC_STUN,        -- Paralysis
  [119381] = LOC_STUN,        -- Leg Sweep
  [116095] = PC_SNARE,        -- Disable
  [116705] = CC_SILENCE,      -- Spear Hand Strike
}

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
    local current_time = GetTime()
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
    return true
  elseif spellfound == true then
    return (show_only_mine and is_mine) or show_only_mine == false
  elseif spellfound == "My" then
    return is_mine
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

--local function FilterWhitelistMine(show_aura, spellfound, is_mine)
--  return show_aura
--
----  if spellfound == "All" then
----    return true
----  elseif spellfound == "My" or spellfound == true then
----    return isMine
----  end
----
----  return false
--end
--
--local function FilterAllMine(show_aura, spellfound, is_mine)
--  return show_aura
--
--  --  return is_mine
--end
--
--local function FilterBlacklistMine(show_aura, spellfound, is_mine)
--  --  blacklist my auras, i.e., default is show all of my auras (non of other players/NPCs)
--  --    spellfound = nil             - show my aura (not found in the blacklist)
--  --    spellfound = Not             - show my aura (from all casters) - bypass blacklisting
--  --    spellfound = My, true or All - blacklist my aura (auras from other casters are not shown either)
--
--  return show_aura
--
----  if spellfound == nil then
----    return isMine
----  elseif spellfound == "Not" then
----    return true
----  end
----
----  return false
--end

Widget.FILTER_FUNCTIONS = {
  all = FilterAll,
  blacklist = FilterBlacklist,
  whitelist = FilterWhitelist,
--  allMine = FilterAllMine,
--  blacklistMine = FilterBlacklistMine,
--  whitelistMine = FilterWhitelistMine,
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

function Widget:FilterFriendlyBuffsBySpell(db, aura, AuraFilterFunction)
  local show_aura = db.ShowAllFriendly or
                    (db.ShowOnFriendlyNPCs and aura.UnitIsNPC) or
                    (db.ShowPlayerCanApply and aura.PlayerCanApply)

  local spellfound = self.AuraFilterBuffs[aura.name] or self.AuraFilterBuffs[aura.spellid]

  return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)
end

function Widget:FilterEnemyBuffsBySpell(db, aura, AuraFilterFunction)
  local show_aura

  if db.HideUnlimitedDuration and aura.duration <= 0 then
    show_aura = false
  else
    show_aura = db.ShowAllEnemy or (db.ShowOnEnemyNPCs and aura.UnitIsNPC) or (db.ShowDispellable and aura.StealOrPurge)
  end

  local spellfound = self.AuraFilterBuffs[aura.name] or self.AuraFilterBuffs[aura.spellid]

  return AuraFilterFunction(show_aura, spellfound, aura.CastByPlayer)
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

function Widget:UpdateUnitAuras(frame, effect, unitid, enabled_auras, enabled_cc, SpellFilter, SpellFilterCC, filter_mode)
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

  local db_auras = (effect == "HARMFUL" and db.Debuffs) or db.Buffs
  local AuraFilterFunction = self.FILTER_FUNCTIONS[filter_mode]
  local AuraFilterFunctionCC = self.FILTER_FUNCTIONS[db.CrowdControl.FilterMode]
  local GetAuraPriority = self.PRIORITY_FUNCTIONS[sort_order]

  local aura, show_aura
  local aura_count = 1
  local rank, isCastByPlayer
  for i = 1, 40 do
    show_aura = false

    -- Auras are evaluated by an external function - pre-filtering before the icon grid is populated
    UnitAuraList[aura_count] = UnitAuraList[aura_count] or {}
    aura = UnitAuraList[aura_count]

    -- Blizzard Code:local name, texture, count, debuffType, duration, expirationTime, caster, _, nameplateShowPersonal, spellId, _, _, _, nameplateShowAll = UnitAura(unit, i, filter);
    aura.name, aura.texture, aura.stacks, aura.type, aura.duration, aura.expiration, aura.caster,
      aura.StealOrPurge, aura.ShowPersonal, aura.spellid, aura.PlayerCanApply, aura.BossDebuff, isCastByPlayer, aura.ShowAll
      = UnitAura(unitid, i, effect)

    -- ShowPesonal: Debuffs  that are shown on Blizzards nameplate, no matter who casted them (and
    -- ShowAll: Debuffs

    if not aura.name then break end

    aura.unit = unitid
    aura.UnitIsNPC = not (UnitIsPlayer(unitid) or UnitPlayerControlled(unitid))
    aura.effect = effect
    aura.ShowAll = aura.ShowAll
    aura.CrowdControl = (enabled_cc and self.CROWD_CONTROL_SPELLS[aura.spellid])
    aura.CastByPlayer = (aura.caster == "player" or aura.caster == "pet" or aura.caster == "vehicle")

    -- Store Order/Priority
    if aura.CrowdControl then
      show_aura = SpellFilterCC(self, db.CrowdControl, aura, AuraFilterFunctionCC)

      -- Show crowd control auras that are not shown in Blizard mode as normal debuffs
      if not show_aura then
        aura.CrowdControl = false
        show_aura = SpellFilter(self, db_auras, aura, AuraFilterFunction)
      end
    elseif enabled_auras then
      show_aura = SpellFilter(self, db_auras, aura, AuraFilterFunction)
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
    local aura_frames_cc = frame:GetParent().CrowdControl.AuraFrames

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

        -- Call function to display the aura
        self:UpdateAuraInformation(aura_frame)
      end
    end

  end
  aura_count_cc = aura_count_cc - 1

  frame.ActiveAuras = max_auras_no - aura_count_cc
  -- Clear extra slots
  for i = max_auras_no + 1, self.MaxAurasPerGrid do
    aura_frames[i]:Hide()
  end

  if effect == "HARMFUL" then
    local aura_frames_cc = frame:GetParent().CrowdControl
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

function Widget:UpdateIconGrid(widget_frame, unitid)
  local db = self.db

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

    self:UpdateUnitAuras(widget_frame.Debuffs, "HARMFUL", unitid, db.Debuffs.ShowFriendly, enabled_cc, self.FilterFriendlyDebuffsBySpell, self.FilterFriendlyCrowdControlBySpell, db.Debuffs.FilterMode)
    self:UpdateUnitAuras(widget_frame.Buffs, "HELPFUL", unitid, db.Buffs.ShowFriendly, false, self.FilterFriendlyBuffsBySpell, self.FilterFriendlyCrowdControlBySpell, db.Buffs.FilterMode)
  else
    enabled_cc = db.CrowdControl.ShowEnemy

    self:UpdateUnitAuras(widget_frame.Debuffs, "HARMFUL", unitid, db.Debuffs.ShowEnemy, enabled_cc, self.FilterEnemyDebuffsBySpell, self.FilterEnemyCrowdControlBySpell, db.Debuffs.FilterMode)
    self:UpdateUnitAuras(widget_frame.Buffs, "HELPFUL", unitid, db.Buffs.ShowEnemy, false, self.FilterEnemyBuffsBySpell, self.FilterEnemyCrowdControlBySpell, db.Buffs.FilterMode)
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
-- Functions for the aura grid with icons
---------------------------------------------------------------------------------------------------

function Widget:CreateAuraFrameIconMode(parent)
  local db = self.db_icon

  local frame = CreateFrame("Frame", nil, parent)

  frame.Icon = frame:CreateTexture(nil, "ARTWORK", 0)
  frame.Border = CreateFrame("Frame", nil, frame)

  frame.Cooldown = CreateFrame("Cooldown", nil, frame, "ThreatPlatesAuraWidgetCooldown")
  frame.Cooldown:SetAllPoints(frame.Icon)
  frame.Cooldown:SetReverse(true)
  frame.Cooldown:SetHideCountdownNumbers(true)

  frame.Stacks = frame.Cooldown:CreateFontString(nil, "OVERLAY")
  frame.TimeLeft = frame.Cooldown:CreateFontString(nil, "OVERLAY")

  frame:Hide()

  return frame
end

function Widget:UpdateAuraFrameIconMode(frame)
  local db = self.db

  if db.ShowCooldownSpiral then
    frame.Cooldown:SetDrawEdge(true)
    frame.Cooldown:SetDrawSwipe(true)
    --frame.Cooldown:SetFrameLevel(frame:GetParent():GetFrameLevel() + 10)
  else
    frame.Cooldown:SetDrawEdge(false)
    frame.Cooldown:SetDrawSwipe(false)
  end

  local show_aura_type = db.ShowAuraType

  db = self.db_icon
  -- Icon
  frame:SetSize(db.IconWidth, db.IconHeight)
  frame.Icon:SetAllPoints(frame)
  --frame.Icon:SetTexCoord(.07, 1-.07, .23, 1-.23) -- Style: Widee
  frame.Icon:SetTexCoord(.10, 1-.07, .12, 1-.12)  -- Style: Square - remove border from icons

  if db.ShowBorder then
   --local offset, edge_size, inset = 1, 4, 0
    local offset, edge_size, inset = 2, 8, 0
--    local offset, edge_size = 2, 8
--    if not show_aura_type then
--      offset, edge_size = 1, 4
--    end
--    local db_test = TidyPlatesThreat.db.profile.TestWidget
--    local offset, edge_size, inset = db_test.Offset, db_test.EdgeSize, db_test.Inset
--    if not show_aura_type then
--      offset, edge_size, inset = db_test.Offset, db_test.EdgeSize, db_test.Inset
--      frame.Border:SetBackdropBorderColor(0, 0, 0, 1)
--    end

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
  if db.ModeIcon.ShowBorder and db.ShowAuraType then
    frame.Border:SetBackdropBorderColor(color.r, color.g, color.b, 1)
  end

  -- Cooldown
  if duration and duration > 0 and expiration and expiration > 0 then
    self.SetCooldown(frame.Cooldown, expiration - duration, duration + .25)
  else
    frame.Cooldown:Clear()
  end

  Animations:StopFlash(frame)

  frame:Show()
end

function Widget:UpdateWidgetTimeIconMode(frame, expiration, duration)
  local db = self.db

  if expiration == 0 then
    frame.TimeLeft:SetText("")
    Animations:StopFlash(frame)
  else
    local timeleft = expiration - GetTime()

    if db.ShowDuration then
      if timeleft > 60 then
        frame.TimeLeft:SetText(floor(timeleft/60).."m")
      else
        frame.TimeLeft:SetText(floor(timeleft))
      end

      if db.FlashWhenExpiring and timeleft < db.FlashTime then
        Animations:Flash(frame, self.FLASH_DURATION)
      end
    else
      frame.TimeLeft:SetText("")

      if db.FlashWhenExpiring and timeleft < db.FlashTime then
        Animations:Flash(frame, self.FLASH_DURATION)
      end
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
  frame:SetFrameLevel(parent:GetFrameLevel())
  frame.Statusbar:SetMinMaxValues(0, 100)

  frame.Background = frame.Statusbar:CreateTexture(nil, "BACKGROUND", 0)
  frame.Background:SetAllPoints()

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

  frame:Hide()

  return frame
end

function Widget:UpdateAuraFrameBarMode(frame)
  local db = self.db_bar
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
    frame.Stacks:SetAllPoints(frame.Icon)
    frame.Stacks:SetSize(db.BarHeight, db.BarHeight)
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

  frame.Statusbar:SetSize(db.BarWidth, db.BarHeight)
  --    frame.Statusbar:SetWidth(db.BarWidth)
  frame.Statusbar:SetStatusBarTexture(ThreatPlates.Media:Fetch('statusbar', db.Texture))
  frame.Statusbar:GetStatusBarTexture():SetHorizTile(false)
  frame.Statusbar:GetStatusBarTexture():SetVertTile(false)
--    frame.Statusbar:Show()
end

function Widget:UpdateAuraInformationBarMode(frame) -- texture, duration, expiration, stacks, color, name)
  local db = self.db

  local stacks = frame.AuraStacks
  local color = frame.AuraColor

  -- Expiration
  self:UpdateWidgetTime(frame, frame.AuraExpiration, frame.AuraDuration)

  if db.ShowStackCount and stacks > 1 then
    frame.Stacks:SetText(stacks)
  else
    frame.Stacks:SetText("")
  end

  -- Icon
  if db.ModeBar.ShowIcon then
    frame.Icon:SetTexture(frame.AuraTexture)
  end

  frame.LabelText:SetWidth(self.LabelLength - frame.TimeText:GetStringWidth())
  frame.LabelText:SetText(frame.AuraName)
  -- Highlight Coloring
  frame.Statusbar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)

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

  if self.db.FrameOrder == "HEALTHBAR_AURAS" then
    widget_frame:SetFrameLevel(widget_frame:GetFrameLevel() + 3)
  else
    widget_frame:SetFrameLevel(widget_frame:GetFrameLevel() + 9)
  end
end

local function UnitAuraEventHandler(widget_frame, event, unitid)
  --  -- Skip player (cause TP does not handle player nameplate) and target (as it is updated via it's actual unitid anyway)
  --  if unitid == "player" or unitid == "target" then return end

  if widget_frame.Active then
    widget_frame.Widget:UpdateIconGrid(widget_frame, unitid)
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
      self:UpdateIconGrid(self.CurrentTarget, plate.TPFrame.unit.unitid)
    end
  end
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

  widget_frame.Buffs = CreateFrame("Frame", nil, widget_frame)
  widget_frame.Buffs.AuraFrames = {}
  widget_frame.Buffs.ActiveAuras = 0

  widget_frame.CrowdControl = CreateFrame("Frame", nil, widget_frame)
  widget_frame.CrowdControl.AuraFrames = {}
  widget_frame.CrowdControl.ActiveAuras = 0

  widget_frame.Widget = self

  self:UpdateAuraWidgetLayout(widget_frame)

  widget_frame:SetScript("OnEvent", UnitAuraEventHandler)
  widget_frame:SetScript("OnUpdate", OnUpdateAurasWidget)
  widget_frame:HookScript("OnShow", OnShowHookScript)
  -- widget_frame:HookScript("OnHide", OnHideHookScript)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  return self.db.ON or self.db.ShowInHeadlineView
end

function Widget:OnEnable()
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
  -- LOSS_OF_CONTROL_ADDED
  -- LOSS_OF_CONTROL_UPDATE
end

function Widget:OnDisable()
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

  if db.SwitchScaleByReaction and UnitReaction(widget_frame.unit.unitid, "player") > 4 then
    widget_frame.Buffs:SetScale(db.Debuffs.Scale)
    widget_frame.Debuffs:SetScale(db.Buffs.Scale)
  else
    widget_frame.Buffs:SetScale(db.Buffs.Scale)
    widget_frame.Debuffs:SetScale(db.Debuffs.Scale)
  end
  widget_frame.CrowdControl:SetScale(db.CrowdControl.Scale)

  widget_frame:UnregisterAllEvents()
  widget_frame:RegisterUnitEvent("UNIT_AURA", unit.unitid)

  self:UpdateIconGrid(widget_frame, unit.unitid)
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

  -- Mine does not make sense here, so ignore it.
  if self.db.Debuffs.ShowAllEnemy then
    self.FilterModeEnemyDebuffs = self.db.Debuffs.FilterMode
  elseif self.db.Debuffs.ShowOnlyMine then
    self.FilterModeEnemyDebuffs = self.db.Debuffs.FilterMode .. "Mine"
  else
    self.FilterModeEnemyDebuffs = "all"
  end

  self:UpdateSettings()
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
  self.UpdateWidgetTime = self.UpdateWidgetTimeBarMode
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

  for plate, tp_frame in pairs(Addon.PlatesCreated) do
    local widget_frame = tp_frame.widgets.Auras

    self:UpdateAuraWidgetLayout(widget_frame)
    if tp_frame.Active then
      self:OnUnitAdded(widget_frame, widget_frame.unit)
    end
  end
end

