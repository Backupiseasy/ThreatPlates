local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local SystemFont_NamePlate, SystemFont_NamePlateFixed = SystemFont_NamePlate, SystemFont_NamePlateFixed
local SystemFont_LargeNamePlate, SystemFont_LargeNamePlateFixed = SystemFont_LargeNamePlate, SystemFont_LargeNamePlateFixed

-- ThreatPlates APIs
local ANCHOR_POINT_TEXT = Addon.ANCHOR_POINT_TEXT

-- Cached database settings

local Font = {}
Addon.Font = Font

---------------------------------------------------------------------------------------------------
-- Backup system fonts for recovery if necessary
---------------------------------------------------------------------------------------------------

local function BackupSystemFont(font_instance)
  local font_name, font_height, font_flags = font_instance:GetFont()

  return {
    Typeface = font_name,
    Size = font_height,
    flags = font_flags
  }
end

Font.DefaultSystemFonts = {
  NamePlate = BackupSystemFont(SystemFont_NamePlate),
  NamePlateFixed = BackupSystemFont(SystemFont_NamePlateFixed),
  LargeNamePlate = BackupSystemFont(SystemFont_LargeNamePlate),
  LargeNamePlateFixed = BackupSystemFont(SystemFont_LargeNamePlateFixed),
}

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------

function Font:UpdateTextFont(font, db)
  font:SetFont(Addon.LibSharedMedia:Fetch('font', db.Typeface), db.Size, db.flags)

  if db.Shadow then
    font:SetShadowOffset(1, -1)
    font:SetShadowColor(0, 0, 0, 1)
  else
    font:SetShadowColor(0, 0, 0, 0)
  end

  if db.Color then
    font:SetTextColor(db.Color.r, db.Color.g, db.Color.b, db.Transparency or 1)
  end

  font:SetJustifyH(db.HorizontalAlignment or "CENTER")
  font:SetJustifyV(db.VerticalAlignment or "CENTER")

  -- Set text to nil to enforce text string update, otherwise updates to justification will not take effect
  local text = font:GetText()
  font:SetText(nil)
  font:SetText(text)
end

function Font:UpdateText(parent, font, db)
  self:UpdateTextFont(font, db.Font)

  local anchor = db.Anchor or "CENTER"

  font:ClearAllPoints()
  if db.InsideAnchor == false then
    local anchor_point_text = ANCHOR_POINT_TEXT[anchor]
    font:SetPoint(anchor_point_text[2], parent, anchor_point_text[1], db.HorizontalOffset or 0, db.VerticalOffset or 0)
  else -- db.InsideAnchor not defined in settings or true
    font:SetPoint(anchor, parent, anchor, db.HorizontalOffset or 0, db.VerticalOffset or 0)
  end
end

function Font:UpdateTextSize(parent, font, db)
  local width, height = parent:GetSize()
  if db.AutoSizing == nil or db.AutoSizing then
    font:SetSize(width, height)
    font:SetWordWrap(false)
  else
    font:SetSize(db.Width, font:GetLineHeight() * font:GetMaxLines())
    font:SetWordWrap(db.WordWrap)
    font:SetNonSpaceWrap(true)
  end
end

---------------------------------------------------------------------------------------------------
-- Configure system fonts
---------------------------------------------------------------------------------------------------

local function UpdateSystemFont(obj, db)
  local font, height, flags = db.Typeface, db.Size, db.flags
  obj:SetFont(Addon.LibSharedMedia:Fetch('font', font), height, flags)

  if db.Shadow then
    local color = db.ShadowColor
    obj:SetShadowColor(color.r, color.g, color.b, color.a)
    obj:SetShadowOffset(db.ShadowHorizontalOffset, db.ShadowVerticalOffset)
  else
    obj:SetShadowColor(0, 0, 0, 0)
  end
end

function Font:SetNamesFonts()
  local db = Addon.db.profile.BlizzardSettings.Names
  if db.Enabled then
    db = db.Font
    UpdateSystemFont(SystemFont_NamePlate, db)
    UpdateSystemFont(SystemFont_NamePlateFixed, db)
    UpdateSystemFont(SystemFont_LargeNamePlate, db)
    UpdateSystemFont(SystemFont_LargeNamePlateFixed, db)
  end
end

function Font:ResetNamesFonts()
  UpdateSystemFont(SystemFont_NamePlate, self.DefaultSystemFonts.NamePlate)
  UpdateSystemFont(SystemFont_NamePlateFixed, self.DefaultSystemFonts.NamePlateFixed)
  UpdateSystemFont(SystemFont_LargeNamePlate, self.DefaultSystemFonts.LargeNamePlate)
  UpdateSystemFont(SystemFont_LargeNamePlateFixed, self.DefaultSystemFonts.LargeNamePlateFixed)
end

---------------------------------------------------------------------------------------------------
-- Update of settings
---------------------------------------------------------------------------------------------------

-- function Font:UpdateConfiguration()
-- end