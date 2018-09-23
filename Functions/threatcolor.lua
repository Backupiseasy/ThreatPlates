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
  local color

--  if not unit.unitid then
--    return c.r, c.g, c.b, c.a -- transparent color
--  end
--

  local db = TidyPlatesThreat.db.profile
  if not UnitIsConnected(unit.unitid) then
    color = db.ColorByReaction.DisconnectedUnit
  elseif unit.isTapped then
    color = db.ColorByReaction.TappedUnit
  elseif unit.type == "NPC" and unit.reaction ~= "FRIENDLY" then
    local style = unit.style
    if style == "unique" then
      local unique_setting = unit.CustomPlateSettings
      if unique_setting.UseThreatGlow then
        -- set style to tank/dps or normal
        style = Addon:GetThreatStyle(unit)
      end
    end

    if style == "dps" or style == "tank" or (style == "normal" and InCombatLockdown()) then
      color = Addon:GetThreatColor(unit, style, db.ShowThreatGlowOnAttackedUnitsOnly)
    end
  end

  color = color or COLOR_TRANSPARENT

  return color.r, color.g, color.b, color.a
end