-----------------------
-- Healer Tracker Widget --
-----------------------
local ADDON_NAME, Addon = ...

local Widget = Addon.Widgets:NewWidget("HealerTracker")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local GetTime = GetTime
local CreateFrame = CreateFrame
local RequestBattlefieldScoreData, GetNumBattlefieldScores = RequestBattlefieldScoreData, GetNumBattlefieldScores
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\HealerTrackerWidget\\"
local HEALER_SPECS = {
  ["Restoration"] = true,
  ["Mistweaver"] = true,
  ["Holy"] = true,
  ["Discipline"] = true
}

local HEALER_SPELLS = {
  -- Priest
  ----------
  [47540] = "PRIEST", -- Penance
  [88625] = "PRIEST", -- Holy Word: Chastise
  [88684] = "PRIEST", -- Holy Word: Serenity
  [88685] = "PRIEST", -- Holy Word: Sanctuary
  [89485] = "PRIEST", -- Inner Focus
  [10060] = "PRIEST", -- Power Infusion
  [33206] = "PRIEST", -- Pain Suppression
  [62618] = "PRIEST", -- Power Word: Barrier
  [724] = "PRIEST", -- Lightwell
  [14751] = "PRIEST", -- Chakra
  [34861] = "PRIEST", -- Circle of Healing
  [47788] = "PRIEST", -- Guardian Spirit

  -- Druid (The affinity traits on the other specs makes this difficult)
  ---------
  [17116] = "DRUID", -- Nature's Swiftness
  [33891] = "DRUID", -- Tree of Life
  [33763] = "DRUID", -- Lifebloom
  [88423] = "DRUID", -- Nature's Cure
  [102342] = "DRUID", -- Ironbark
  [145205] = "DRUID", -- Efflorescence
  [740] = "DRUID", -- Tranquility

  -- Shaman
  ---------
  [17116] = "SHAMAN", -- Nature's Swiftness
  [16190] = "SHAMAN", -- Mana Tide Totem
  [61295] = "SHAMAN", -- Riptide
  [5394] = "SHAMAN", -- Healing Stream Totem
  [1064] = "SHAMAN", -- Chain Heal
  [77130] = "SHAMAN", -- Purify Spirit
  [77472] = "SHAMAN", -- Healing Wave
  [98008] = "SHAMAN", -- Spirit Link Totem

  -- Paladin
  ----------
  [20473] = "PALADIN", -- Holy Shock
  [53563] = "PALADIN", -- Beacon of Light
  [31821] = "PALADIN", -- Aura Mastery
  [85222] = "PALADIN", -- Light of Dawn
  [4987] = "PALADIN", -- Cleanse
  [82326] = "PALADIN", -- Holy Light

  -- Monk
  ---------
  [115175] = "MONK", -- Soothing Mist
  [115294] = "MONK", -- Mana Tea
  [115310] = "MONK", -- Revival
  [116680] = "MONK", -- Thunder Focus Tea
  [116849] = "MONK", -- Life Cocoon
  [116995] = "MONK", -- Surging mist
  [119611] = "MONK", -- Renewing mist
  [132120] = "MONK", -- Envelopping Mist
}

---------------------------------------------------------------------------------------------------
-- Variables
---------------------------------------------------------------------------------------------------

local healerList = {
  guids = {},
  names = {}
}

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function UpdateSettings(frame)
  local db = TidyPlatesThreat.db.profile.healerTracker
  local size = db.scale
  local alpha = db.alpha

  frame:SetSize(size, size)
  frame:SetAlpha(alpha)
end

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

--NOTE: used for testing
--local function dumpLists()
--	print("dumping lists")
--
--	print("name")
--	for i, v in ipairs(healerList.names) do
--		print(v)
--	end
--
--	print("guid")
--	for i, v in ipairs(healerList.guids) do
--		print(v)
--	end
--end

local function IsHealerSpec(spec)
  return HEALER_SPECS[spec] == true
end

local function IsHealer(guid)
  return healerList.guids[guid] == true
end

local nextUpdate = 0
local function RequestBgScoreData()
  local now = GetTime()

  --throttle update to every 3 seconds
  if now > nextUpdate then
    nextUpdate = now + 3
  else
    return
  end

  RequestBattlefieldScoreData()
end

--look at the scoreboard and assign healers from there
local function FindHealersInBgScoreboard()
  local scores = GetNumBattlefieldScores()

  for i = 1, scores do
    local name, killingBlows, honorableKills, deaths, honorGained, faction, race, class, classToken, damageDone, healingDone, bgRating, ratingChange, preMatchMMR, mmrChange, talentSpec = GetBattlefieldScore(i)

    if IsHealerSpec(talentSpec) then
      name = string.gsub(name, "-.+", "") --remove realm part of name
      healerList.names[name] = true
    end
  end

  --dumpLists()
end

local SPELL_EVENTS = {
  ["SPELL_HEAL"] = true,
  ["SPELL_AURA_APPLIED"] = true,
  ["SPELL_CAST_START"] = true,
  ["SPELL_CAST_SUCCESS"] = true,
  ["SPELL_PERIODIC_HEAL"] = true,
}

local function FindHealersViaCombatLog(...)
  local timestamp, combatevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlag, spellid = CombatLogGetCurrentEventInfo();

  if sourceGUID and sourceName and SPELL_EVENTS[combatevent] and HEALER_SPELLS[spellid] then
    healerList.guids[sourceGUID] = true
  end
end

local function ResolveName(unit)
  if healerList.names[unit.name] then --a healer identified via scoreboard, add it to main guid list
    healerList.guids[unit.guid] = true
  end
end

function Widget:UPDATE_BATTLEFIELD_SCORE()
  FindHealersInBgScoreboard()
end

--triggered when enter and leave instances
function Widget:PLAYER_ENTERING_WORLD()
  healerList.names = table.wipe(healerList.names)
  healerList.guids = table.wipe(healerList.guids)
end

function Widget:COMBAT_LOG_EVENT_UNFILTERED(...)
  FindHealersViaCombatLog(...)
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local frame = CreateFrame("Frame", nil, tp_frame)
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
  return TidyPlatesThreat.db.profile.healerTracker.ON or TidyPlatesThreat.db.profile.healerTracker.ShowInHeadlineView
end

function Widget:OnEnable()
  self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function Widget:EnabledForStyle(style, unit)
  if unit.type ~= "PLAYER" then return false end

  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return TidyPlatesThreat.db.profile.healerTracker.ShowInHeadlineView
  elseif style ~= "etotem" then
    return TidyPlatesThreat.db.profile.healerTracker.ON
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  local db = TidyPlatesThreat.db.profile.healerTracker

  --Deathknights can be picked up as 'healers' thanks to Dark Simulacrum, so just ignore them.
  if unit.class == "DEATHKNIGHT" then
    widget_frame:Hide()
    return
  end

  UpdateSettings(widget_frame)

  RequestBgScoreData()
  ResolveName(unit)

  widget_frame:SetPoint(db.anchor, widget_frame:GetParent(), db.x, db.y)
  widget_frame.Icon:SetTexture(PATH .. "healer")

  if IsHealer(unit.guid) then --show it
    widget_frame:Show()
  else --hide it
    widget_frame:Hide()
  end
end
