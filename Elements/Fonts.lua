local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs

-- ThreatPlates APIs
local ANCHOR_POINT_TEXT = Addon.ANCHOR_POINT_TEXT

local Font = {}
Addon.Font = Font

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------

function Font:UpdateTextFont(font, db)
  font:SetFont(ThreatPlates.Media:Fetch('font', db.Typeface), db.Size, db.flags)

  if db.Shadow then
    font:SetShadowOffset(1, -1)
    font:SetShadowColor(0, 0, 0, 1)
  else
    font:SetShadowColor(0, 0, 0, 0)
  end

  font:SetTextColor(db.Color.r, db.Color.g, db.Color.b, db.Transparency)

  --font:SetPoint("CENTER", 0, 8)
  font:SetJustifyH(db.HorizontalAlignment)
  font:SetJustifyV(db.VerticalAlignment)
end

function Font:UpdateText(parent, font, db)
  self:UpdateTextFont(font, db.Font)

  font:ClearAllPoints()
  if db.InsideAnchor then
    font:SetPoint(db.Anchor, parent, db.Anchor, db.HorizontalOffset, db.VerticalOffset)
  else
    local anchor_point_text = ANCHOR_POINT_TEXT[db.Anchor]
    font:SetPoint(anchor_point_text[2], parent, anchor_point_text[1], db.HorizontalOffset, db.VerticalOffset)
  end
end
