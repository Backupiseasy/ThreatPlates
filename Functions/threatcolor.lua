local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
--local UnitThreatSituation = UnitThreatSituation
local InCombatLockdown = InCombatLockdown
local UnitThreatSituation = UnitThreatSituation

local UnitIsOffTanked = TidyPlatesThreat.UnitIsOffTanked
local OnThreatTable = TidyPlatesThreat.OnThreatTable
local COLOR_TRANSPARENT = ThreatPlates.COLOR_TRANSPARENT

local function SetThreatColor(unit)
  local c = COLOR_TRANSPARENT

  if InCombatLockdown() and unit.reaction ~= "FRIENDLY" and unit.type == "NPC" then
    local db = TidyPlatesThreat.db.profile
    local style, unique_setting = TidyPlatesThreat.SetStyle(unit)

    if style == "unique" and unique_setting.UseThreatGlow then
      -- set style to tank/dps or normal
      style = TidyPlatesThreat.GetThreatStyle(unit)
    end

    if unit.isTapped then
      local tapped_color = db.ColorByReaction.TappedUnit
      if db.ShowThreatGlowOnAttackedUnitsOnly then
        if OnThreatTable(unit) then
          c = tapped_color
        end
      else
        c = tapped_color
      end
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
    elseif style == "dps" or style == "tank" or (style == "normal" and unit.isInCombat) then
      -- problem with this is if threat system is enabled, it does not work for unique - which it should in this case!
      local show_offtank = db.threat.toggle.OffTank

      if db.ShowThreatGlowOnAttackedUnitsOnly then
        if OnThreatTable(unit) then
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
  end

  return c.r, c.g, c.b, c.a
end

TidyPlatesThreat.SetThreatColor = SetThreatColor