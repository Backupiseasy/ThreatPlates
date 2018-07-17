local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local InCombatLockdown = InCombatLockdown
local UnitIsConnected = UnitIsConnected

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local RGB = ThreatPlates.RGB

local COLOR_TRANSPARENT = RGB(0, 0, 0, 0) -- opaque

local function ShowThreatGlow(unit)
  local db = TidyPlatesThreat.db.profile

  if db.ShowThreatGlowOnAttackedUnitsOnly then
    return Addon:OnThreatTable(unit)
  else
    return true
  end
end

function Addon:SetThreatColor(unit)
  local c = COLOR_TRANSPARENT

  if not unit.unitid then
    return c.r, c.g, c.b, c.a -- transparent color
  end

  if InCombatLockdown() and unit.type == "NPC" and unit.reaction ~= "FRIENDLY" then
    local style = unit.style

    if style == "unique" then
      local unique_setting = unit.CustomPlateSettings
      if unique_setting.UseThreatGlow then
        -- set style to tank/dps or normal
        style = Addon:GetThreatStyle(unit)
      end
    end

    local db = TidyPlatesThreat.db.profile
    if not UnitIsConnected(unit.unitid) then
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
        if style == "tank" and show_offtank and Addon:UnitIsOffTanked(unit) then
          threatSituation = "OFFTANK"
        end
        c = db.settings[style]["threatcolor"][threatSituation]
      end
    end
  end

  return c.r, c.g, c.b, c.a
end