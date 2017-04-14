local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitThreatSituation = UnitThreatSituation
local GetUnitVisibility = ThreatPlates.GetUnitVisibility


---------------------------------------------------------------------------------------------------
-- Helper functions for styles and functions
---------------------------------------------------------------------------------------------------
local function OnThreatTable(unit)
  -- "is unit inactive" from TidyPlates - fast, but doesn't meant that player is on threat table
  -- return  (unit.health < unit.healthmax) or (unit.isInCombat or unit.threatValue > 0) or (unit.isCasting == true) then

  -- nil means player is not on unit's threat table - more acurate, but slower reaction time than the above solution
  return UnitThreatSituation("player", unit.unitid)
end


local function GetGeneral(unit)
  -- guild/friend/...?

  -- missing from UnitClassification:
  --   trivial:  for low-level targets that would not reward experience or honor (UnitIsTrivial() would return '1')

  local t = unit.isTapped
  local o, b, r, e, m = unit.reaction, unit.isBoss, unit.isRare, unit.isElite, unit.isMini

  if t then
    return "Tapped"
  elseif o == "NEUTRAL" then
    return  "Neutral"
  elseif m then
    return "Minus"
  elseif b then
    return "Boss"
  elseif r or e then
    return "Elite"
  else
    return "Normal"
  end

end

local function GetDetailedUnitType(unit)
  local t, m = unit.isTapped, unit.isMini
  local totem =  TidyPlatesThreat.ThreatPlates_Totems[unit.name]

  if t then
    return "Tapped"
  elseif totem then
    return "Totem"
  elseif UnitIsOtherPlayersPet(unit.unitid) then -- player pets are also considered guardians, so this check has priority
    return "Pet"
  elseif m then
    return "Minus"
  else
    local o, y = unit.reaction, unit.type
    if o == "FRIENDLY" then
      if y == "PLAYER" then
        return "FriendlyPlayer"
      elseif UnitPlayerControlled(unit.unitid) then
        return "Guardian"
      else
        return "FriendlyNPC"
      end
    elseif o == "HOSTILE" then
      local b, r, e = unit.isBoss, unit.isRare, unit.isElite
      if b then
        return "Boss"
      elseif r or e then
        return "Elite"
      elseif y == "PLAYER" then
        return "EnemyPlayer"
      elseif UnitPlayerControlled(unit.unitid) then
        return "Guardian"
      else
        return "EnemyNPC"
      end
    else -- o == "NEUTRAL"
      return  "Neutral"
    end
  end
end

local function GetType(unit)
  local db = TidyPlatesThreat.db.profile
  local unitRank

  local totem =  TidyPlatesThreat.ThreatPlates_Totems[unit.name]
  local unique = tContains(db.uniqueSettings.list, unit.name)
  local general_type = GetGeneral(unit)

  if totem then
    unitRank = "Totem"
  elseif unique then
    for k_c,k_v in pairs(db.uniqueSettings.list) do
      if k_v == unit.name then
        if db.uniqueSettings[k_c].useStyle then
          unitRank = "Unique"
        else
          unitRank = general_type
        end
      end
    end
  else
    unitRank = general_type
  end

  return unitRank, general_type
end

local function GetUniqueType(unit)
  local db = TidyPlatesThreat.db.profile
  local unitRank

  local totem = TidyPlatesThreat.ThreatPlates_Totems[unit.name]
  local unique = tContains(db.uniqueSettings.list, unit.name)

  if totem then
    unitRank = "Totem"
  elseif unique then
    for k_c,k_v in pairs(db.uniqueSettings.list) do
      if k_v == unit.name then
        if db.uniqueSettings[k_c].useStyle then
          unitRank = "Unique"
        end
      end
    end
  end

  return unitRank
end

local function ShowUnit(unit)
  local db = TidyPlatesThreat.db.profile
  local faction = ""
  local unit_type = "NPC"
  local show = false
  local headline_view = false

  local unit_type = GetUniqueType(unit)

  -- if unit_type then => unique type (totem or unique) - totems shown/hidden by Blizzard CVars, so no extra check necessary
  -- headline view, tapped not working for unique, totem because of this if here
  if unit_type then
    show = true
  else
    if unit.reaction == "NEUTRAL" then
      faction = "Neutral"
      if unit.isMini then
        unit_type = "Minor"
      elseif UnitPlayerControlled(unit.unitid) then
        unit_type = "Guardian"
      else  --if unit.type == "NPC" then
        unit_type = "NPC"
      end
    else
      if unit.reaction == "FRIENDLY" then
        faction = "Friendly"
      elseif unit.reaction == "HOSTILE" then
        faction = "Enemy"
      end

      if unit.reaction == "HOSTILE" and unit.isMini then -- no minor mobs for friendly, as far as I know
        unit_type = "Minor"
      elseif unit.type == "PLAYER" then
        unit_type = "Player"
      elseif UnitIsOtherPlayersPet(unit.unitid) then -- player pets are also considered guardians, so this check has priority
        unit_type =  "Pet"
      elseif UnitPlayerControlled(unit.unitid) then
        unit_type = "Guardian"
      else --if unit.type == "NPC" then
        unit_type = "NPC"
      end
    end

    show, headline_view = GetUnitVisibility(faction..unit_type)

    if not db.HeadlineView.ON then
      headline_view = false
    elseif db.HeadlineView.ForceHealthbarOnTarget and unit.isTarget then
      headline_view = false
    elseif db.HeadlineView.ForceOutOfCombat and not InCombatLockdown() then
      headline_view = true
    end

    local e, b, t = (unit.isElite or unit.isRare), unit.isBoss, unit.isTapped
    local visibility = db.Visibility
    local hide_n, hide_e, hide_b, hide_t = visibility.HideNormal , visibility.HideElite, visibility.HideBoss, visibility.HideTapped
    if (e and hide_e) or (b and hide_b) or (t and hide_t) then
      show = false
    elseif hide_n and not (e or b) then
      show = false
    elseif unit.unitid and UnitIsBattlePet(unit.unitid) then
      -- TODO: add configuration option for enable/disable
      show = false
    end
  end

  return show, unit_type, headline_view
end

local function IsUnitActive(unit)
  return (unit.health < unit.healthmax) or (unit.threatValue > 1) or unit.isMarked	-- or unit.isInCombat
end

-- Returns style based on threat (currently checks for in combat, should not do hat)
local function GetThreatStyle(unit)
  local db = TidyPlatesThreat.db.profile
  local style

  -- style tank/dps only used for NPCs/non-player units
  if InCombatLockdown() and unit.type == "NPC" and db.threat.ON then
    --		if db.threat.toggle[T] then
      if db.threat.nonCombat  then
        -- db.thread.nonCombat not nessessary in following if statement?!?
        if (unit.isInCombat or (unit.health < unit.healthmax)) and db.threat.nonCombat then
          if TidyPlatesThreat:GetSpecRole() then
            style = "tank"
          else
            style = "dps"
          end
        end
      else
        if TidyPlatesThreat:GetSpecRole()	then
          style = "tank"
        else
          style = "dps"
        end
      end
--		end
  end
  if not style then
    style = "normal"
  end

  return style
end

local function SetStyle(unit)
  local db = TidyPlatesThreat.db.profile
  local style, unique_setting

  local  show, unit_type, headline_view = ShowUnit(unit)

  if not show then
    style = "empty"
  elseif unit_type == "Totem" then
    local tS = db.totemSettings[TidyPlatesThreat.ThreatPlates_Totems[unit.name]]
    if tS[1] then
      if db.totemSettings.hideHealthbar then
        style = "etotem"
      else
        style = "totem"
      end
    end
  elseif unit_type == "Unique" then
    for k_c,k_v in pairs(db.uniqueSettings.list) do
      if k_v == unit.name then
        unique_setting = db.uniqueSettings[k_c]
        if unique_setting.showNameplate then
          style = "unique"
        end
      end
    end
  else
    if headline_view then
      style = "NameOnly"
    elseif unit_type then
      if unit.reaction == "FRIENDLY" then
        style = "normal"
      else
        local T = GetGeneral(unit)
        -- style tank/dps only used for NPCs/non-player units, old: unit.class == "UNKNOWN"
        if InCombatLockdown() and unit.type == "NPC" and db.threat.ON then
          if db.threat.toggle[T] then
            if db.threat.nonCombat  then
              -- db.thread.nonCombat not nessessary in following if statement?!?
              if (unit.isInCombat or (unit.health < unit.healthmax)) and db.threat.nonCombat then
                if TidyPlatesThreat:GetSpecRole() then
                  style = "tank"
                else
                  style = "dps"
                end
              end
            else
              if TidyPlatesThreat:GetSpecRole()	then
                style = "tank"
              else
                style = "dps"
              end
            end
          end
        end
        if not style then
          style = "normal"
        end
      end
    end
  end

  -- t.PrintTargetInfo(unit)
  if not style then style = "etotem" end

  return style, unique_setting
end

TidyPlatesThreat.GetGeneral = GetGeneral
TidyPlatesThreat.GetType = GetType
TidyPlatesThreat.GetDetailedUnitType = GetDetailedUnitType
TidyPlatesThreat.SetStyle = SetStyle
TidyPlatesThreat.GetThreatStyle = GetThreatStyle
TidyPlatesThreat.OnThreatTable = OnThreatTable
