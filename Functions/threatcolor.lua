local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local InCombatLockdown, IsInInstance = InCombatLockdown, IsInInstance
local UnitIsConnected = UnitIsConnected

-- ThreatPlates APIs
local RGB = ThreatPlates.RGB

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: UnitAffectingCombat

local COLOR_TRANSPARENT = RGB(0, 0, 0, 0) -- opaque

---------------------------------------------------------------------------------------------------
-- Wrapper functions for WoW Classic
---------------------------------------------------------------------------------------------------

local function ShowThreatGlow(unit)
  local db = Addon.db.profile

  if db.ShowThreatGlowOnAttackedUnitsOnly then
    if IsInInstance() and db.threat.UseHeuristicInInstances then
      return _G.UnitAffectingCombat(unit.unitid)
    else
      return Addon:OnThreatTable(unit)
    end
  else
    return _G.UnitAffectingCombat(unit.unitid)
  end
end

function Addon:SetThreatColor(unit)
  local color

  local db = Addon.db.profile
  if not UnitIsConnected(unit.unitid) and ShowThreatGlow(unit) then
    color = db.ColorByReaction.DisconnectedUnit
  elseif unit.isTapped and ShowThreatGlow(unit) then
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

    -- Split this up into two if-parts, otherweise there is an inconsistency between
    -- healthbar color and threat glow at the beginning of a combat when the player
    -- is already in combat, but not yet on the mob's threat table for a sec or so.
    if db.threat.ON and db.threat.useHPColor then
      if style == "dps" or style == "tank" then
        color = Addon:GetThreatColor(unit, style, db.ShowThreatGlowOnAttackedUnitsOnly) -- ShowThreatGlowOnAttackedUnitsOnly is ignored in WoW Classic
      end
    elseif InCombatLockdown() and (style == "normal" or style == "dps" or style == "tank") then
      color = Addon:GetThreatColor(unit, style, db.ShowThreatGlowOnAttackedUnitsOnly)   -- ShowThreatGlowOnAttackedUnitsOnly is ignored in WoW Classic
    end
  end

  color = color or COLOR_TRANSPARENT

  return color.r, color.g, color.b, color.a
end