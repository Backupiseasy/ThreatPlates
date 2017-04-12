local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitIsOffTanked = TidyPlatesThreat.UnitIsOffTanked
local COLOR_TRANSPARENT = ThreatPlates.COLOR_TRANSPARENT

local function SetThreatColor(unit)
  local db = TidyPlatesThreat.db.profile
  local style, unique_setting = TidyPlatesThreat.SetStyle(unit)

  local c = COLOR_TRANSPARENT

  if style == "unique" and unique_setting.UseThreatGlow then
    -- set style to tank/dps or normal
    style = TidyPlatesThreat.GetThreatStyle(unit)
  end

  if unit.isTapped then
    local tapped_color = db.ColorByReaction.TappedUnit
    if db.ShowThreatGlowOnAttackedUnitsOnly then
      if unit.threatValue > 0 then
        c = tapped_color
      end
    else
      c = tapped_color
    end
--  elseif style == "tank" then
--    local show_offtank = db.threat.toggle.OffTank
--    if db.ShowThreatGlowOnAttackedUnitsOnly then
--      if unit.threatValue > 0 then
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
--      if unit.threatValue > 0 then
--        local threatSituation = unit.threatSituation
--        c = db.settings[style]["threatcolor"][threatSituation]
--      end
--    else
--      local threatSituation = unit.threatSituation
--      c = db.settings[style]["threatcolor"][threatSituation]
--    end
  elseif style == "dps" or style == "tank" or (style == "normal" and unit.isInCombat) then
    -- problem with this is if threat system is enabled, it does not work for unique - which it should in this case!
    local show_offtank = db.threat.toggle.OffTank

    if db.ShowThreatGlowOnAttackedUnitsOnly then
      if unit.threatValue > 0 then
        local threatSituation = unit.threatSituation
        if style == "tank" and show_offtank and UnitIsOffTanked(unit) then
          threatSituation = "OFFTANK"
        end
        c = db.settings[style]["threatcolor"][threatSituation]
      end
    else
      local threatSituation = unit.threatSituation
      if style == "tank" and show_offtank and UnitIsOffTanked(unit) then
        threatSituation = "OFFTANK"
      end
      c = db.settings[style]["threatcolor"][threatSituation]
    end
  end

  return c.r, c.g, c.b, c.a
end

TidyPlatesThreat.SetThreatColor = SetThreatColor