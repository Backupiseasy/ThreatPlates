---------------------------------------------------------------------------------------------------
-- Module: Font
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local SystemFont_NamePlate, SystemFont_NamePlateFixed = SystemFont_NamePlate, SystemFont_NamePlateFixed
local SystemFont_LargeNamePlate, SystemFont_LargeNamePlateFixed = SystemFont_LargeNamePlate, SystemFont_LargeNamePlateFixed
local SystemFont_NamePlate_Outlined = _G.SystemFont_NamePlate_Outlined
local C_Timer_After = C_Timer.After

-- ThreatPlates APIs
local ANCHOR_POINT_TEXT = Addon.ANCHOR_POINT_TEXT

-- Cached database settings
local Settings

---------------------------------------------------------------------------------------------------
-- Module Setup
---------------------------------------------------------------------------------------------------
local FontModule = Addon.Font

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

local DefaultSystemFonts = {
  NamePlate = BackupSystemFont(SystemFont_NamePlate),
  NamePlateFixed = BackupSystemFont(SystemFont_NamePlateFixed),
  LargeNamePlate = BackupSystemFont(SystemFont_LargeNamePlate),
  LargeNamePlateFixed = BackupSystemFont(SystemFont_LargeNamePlateFixed),
  NamePlateOutlined = SystemFont_NamePlate_Outlined and BackupSystemFont(SystemFont_NamePlate_Outlined),
}

---------------------------------------------------------------------------------------------------
-- UI utility functions
---------------------------------------------------------------------------------------------------

function Addon.AnchorFrameTo(db, frame, parent_frame)
  frame:ClearAllPoints()

  local anchor = db.Anchor or "CENTER"
  if db.InsideAnchor == false then
    local anchor_point_text = ANCHOR_POINT_TEXT[anchor]
    frame:SetPoint(anchor_point_text[2], parent_frame, anchor_point_text[1], db.HorizontalOffset or 0, db.VerticalOffset or 0)
  else -- db.InsideAnchor not defined in settings or true
    frame:SetPoint(anchor, parent_frame, anchor, db.HorizontalOffset or 0, db.VerticalOffset or 0)
  end
end

local AnchorFrameTo = Addon.AnchorFrameTo

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------

function FontModule.SetJustify(font_string, horz, vert)
  local align_horz, align_vert = font_string:GetJustifyH(), font_string:GetJustifyV()
  if align_horz ~= horz or align_vert ~= vert then
    font_string:SetJustifyH(horz)
    font_string:SetJustifyV(vert)

    -- Set text to nil to enforce text string update, otherwise updates to justification will not take effect
    local text = font_string:GetText()
    font_string:SetText(nil)
    font_string:SetText(text)
  end
end

local function UpdateTextFont(font, db)
  font:SetFont(Addon.LibSharedMedia:Fetch('font', db.Typeface), db.Size, db.flags)

  font:SetShadowOffset(0, 0)
  font:SetShadowColor(1, 0, 0, 0)

  if db.Shadow then
    font:SetShadowOffset(1, -1)
    font:SetShadowColor(0, 0, 0, 1)
  else
    font:SetShadowColor(0, 0, 0, 0)
  end

  font:SetShadowOffset(3, -3)
  font:SetShadowColor(0, 0, 0, 1)

  if db.Color then
    font:SetTextColor(db.Color.r, db.Color.g, db.Color.b, db.Transparency or 1)
  end

  FontModule.SetJustify(font, db.HorizontalAlignment or "CENTER", db.VerticalAlignment or "MIDDLE")

  -- Set text to nil to enforce text string update, otherwise updates to justification will not take effect
  local text = font:GetText()
  font:SetText(nil)
  font:SetText(text)
end

function FontModule.UpdateText(parent, font, db)
  UpdateTextFont(font, db.Font)
  AnchorFrameTo(db, font, parent)
end

function FontModule.UpdateTextSize(parent, font, db)
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

local IsNameFontReapplyScheduled = false

local function ReapplyNow()
  if Settings.Enabled then
    FontModule.SetNamesFonts(true)
  end
end

local function ReapplyNowAndReset()
  ReapplyNow()
  IsNameFontReapplyScheduled = false
end

local function ReapplyNameFonts()
  if IsNameFontReapplyScheduled then return end

  IsNameFontReapplyScheduled = true

  -- Blizzard resets SystemFont_NamePlate* asynchronously after certain UI events
  -- (e.g. nameplate size changes, options panel show/hide). Two delayed passes are
  -- needed to reliably override the font: one next-frame pass to catch the first
  -- reset, and a second pass ~100 ms later to catch any further late resets before
  -- clearing the guard flag.
  C_Timer_After(0, ReapplyNow)
  C_Timer_After(0.1, ReapplyNowAndReset)
end

function FontModule.SetNamesFonts(skip_reapply)
  if not Settings.Enabled then return end

  local db = Settings.Font
  UpdateSystemFont(SystemFont_NamePlate, db)
  UpdateSystemFont(SystemFont_NamePlateFixed, db)
  UpdateSystemFont(SystemFont_LargeNamePlate, db)
  UpdateSystemFont(SystemFont_LargeNamePlateFixed, db)
  if SystemFont_NamePlate_Outlined then
    UpdateSystemFont(SystemFont_NamePlate_Outlined, db)
  end

  if not skip_reapply then
    ReapplyNameFonts()
  end
end

function FontModule.ResetNamesFonts()
  UpdateSystemFont(SystemFont_NamePlate, DefaultSystemFonts.NamePlate)
  UpdateSystemFont(SystemFont_NamePlateFixed, DefaultSystemFonts.NamePlateFixed)
  UpdateSystemFont(SystemFont_LargeNamePlate, DefaultSystemFonts.LargeNamePlate)
  UpdateSystemFont(SystemFont_LargeNamePlateFixed, DefaultSystemFonts.LargeNamePlateFixed)
  if SystemFont_NamePlate_Outlined and DefaultSystemFonts.NamePlateOutlined then
    UpdateSystemFont(SystemFont_NamePlate_Outlined, DefaultSystemFonts.NamePlateOutlined)
  end
end

---------------------------------------------------------------------------------------------------
-- Update of settings
---------------------------------------------------------------------------------------------------

function FontModule.UpdateSettings()
  Settings = Addon.db.profile.BlizzardSettings.Names
end