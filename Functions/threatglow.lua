---------------------------------------------------------------------------------------------------
-- Element: Warning Glow for Threat
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

-- Lua APIs

-- WoW APIs

-- ThreatPlates APIs

local function ProcessThreatUpdate(subscriber, tp_frame, unit)
  print ("ThreatGlow: ThreatUpdate - Threat update for unit ", unit.unitid)

  local threatglow = tp_frame.visual.threatborder
  if unit.ThreatStatus and tp_frame.style.threatborder.show then
    print ("unit.ThreatLevel ", unit.ThreatLevel)
    print ("Showing: ", Addon:SetThreatColor(unit))
    threatglow:SetBackdropBorderColor(Addon:SetThreatColor(unit))
    threatglow:Show()
  else
    print ("Hiding")
    threatglow:Hide()
  end
end

Addon.EventService.Subscribe("ThreatGlow", "ThreatUpdate", ProcessThreatUpdate)

