local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local InCombatLockdown = InCombatLockdown
local UnitIsConnected = UnitIsConnected

local RGB = ThreatPlates.RGB
local UnitIsOffTanked = ThreatPlates.UnitIsOffTanked
local OnThreatTable = ThreatPlates.OnThreatTable
local GetUniqueNameplateSetting = ThreatPlates.GetUniqueNameplateSetting
local SetStyle = TidyPlatesThreat.SetStyle

local COLOR_TRANSPARENT = RGB(0, 0, 0, 0, 0) -- opaque

local function ShowThreatGlow(unit)
  local db = TidyPlatesThreat.db.profile

  if db.ShowThreatGlowOnAttackedUnitsOnly then
    return OnThreatTable(unit)
  else
    return true
  end
end

local function SetThreatColor(unit)
  local db = TidyPlatesThreat.db.profile

  local c = COLOR_TRANSPARENT

  local unitid = unit.unitid
  if unitid == nil then
    return c.r, c.g, c.b, c.a
  end

  if InCombatLockdown() and unit.type == "NPC" and unit.reaction ~= "FRIENDLY" then
    local style = unit.TP_Style or SetStyle(unit)
    --    local style, unique_setting = TidyPlatesThreat.SetStyle(unit)

    if style == "unique" then
      local unique_setting = GetUniqueNameplateSetting(unit)
      if unique_setting.UseThreatGlow then
        -- set style to tank/dps or normal
        style = ThreatPlates.GetThreatStyle(unit)
      end
    end

    if not UnitIsConnected(unitid) then
      if ShowThreatGlow(unit) then
        c = db.ColorByReaction.DisconnectedUnit
      end
    elseif unit.isTapped then
      if ShowThreatGlow(unit) then
        c = db.ColorByReaction.TappedUnit
      end
    elseif style == "dps" or style == "tank" or (style == "normal" and unit.isInCombat) then
      if ShowThreatGlow(unit) then
        local show_offtank = db.threat.toggle.OffTank
        local threatSituation = unit.threatSituation
        if style == "tank" and show_offtank and UnitIsOffTanked(unit) then
          threatSituation = "OFFTANK"
        end
        c = db.settings[style]["threatcolor"][threatSituation]
      end
    end
  end

  return c.r, c.g, c.b, c.a
end

TidyPlatesThreat.SetThreatColor = SetThreatColor

--  elseif style == "tank" then
--    local show_offtank = db.threat.toggle.OffTank
--    if db.ShowThreatGlowOnAttackedUnitsOnly then
--      if OnThreatTable(unit) then
--        local threatSituation = unit.threatSituation
--        if show_offtank and UnitIsOffTanked(unit) then
--          threatSituation = "OFFTANK"
--        end
--        c = db.settings[style]["threatcolor"][threatSituation]
--      end
--    else
--      local threatSituation = unit.threatSituation
--      if show_offtank and UnitIsOffTanked(unit) then
--        threatSituation = "OFFTANK"
--      end
--      c = db.settings[style]["threatcolor"][threatSituation]
--    end
--  elseif style == "dps" or (style == "normal" and unit.isInCombat) then
--    -- problem with this is if threat system is enabled, it does not work for unique - which it should in this case!
--    if db.ShowThreatGlowOnAttackedUnitsOnly then
--      if OnThreatTable(unit) then
--        local threatSituation = unit.threatSituation
--        c = db.settings[style]["threatcolor"][threatSituation]
--      end
--    else
--      local threatSituation = unit.threatSituation
--      c = db.settings[style]["threatcolor"][threatSituation]
--    end