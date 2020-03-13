-----------------------------------------------------------------------------------------------------
-- ThreatPlates functions required for testing (but not tested themselves)
---------------------------------------------------------------------------------------------------

ThreatPlates = {}
TidyPlatesThreat = {}

Addon.RGB = function(red, green, blue, alpha)
  local color = { r = red/255, g = green/255, b = blue/255 }
  if alpha then color.a = alpha end
  return color
end

Addon.RGB_P = function(red, green, blue, alpha)
  return { r = red, g = green, b = blue, a = alpha}
end

Addon.L = {}

ThreatPlates.IsFriend = function(unit)
  return unit.Test_IsFriend
end

ThreatPlates.IsGuildmate = function(unit)
  return unit.Test_IsGuildmate
end

ThreatPlates.GetColorByHealthDeficit = function(unit)
  return Addon.RGB(230, 100, 0, 1)
end
