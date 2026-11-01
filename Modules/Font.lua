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
local C_NamePlate = C_NamePlate
local CreateFontFamily = _G.CreateFontFamily

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

-- Blizzard's nameplate fonts are font families with one font per alphabet (see GameFonts.xml), and plain SetFont on
-- them only changes the font that GetFont reports. So back up (and restore) every alphabet's font object, including
-- its shadow, with the font file path as is (not via LibSharedMedia).
local FONT_ALPHABETS = { "roman", "korean", "simplifiedchinese", "traditionalchinese", "russian" }

local function BackupFontObject(font_object)
  local font, height, flags = font_object:GetFont()
  local r, g, b, a = font_object:GetShadowColor()
  local x, y = font_object:GetShadowOffset()
  return { Font = font, Height = height, Flags = flags, ShadowColor = { r, g, b, a }, ShadowOffset = { x, y } }
end

local function RestoreFontObject(font_object, backup)
  if not backup.Font then return end

  font_object:SetFont(backup.Font, backup.Height, backup.Flags)
  font_object:SetShadowColor(unpack(backup.ShadowColor))
  font_object:SetShadowOffset(unpack(backup.ShadowOffset))
end

local function BackupSystemFont(font_instance)
  if not font_instance then return end

  local backup = { Base = BackupFontObject(font_instance), Alphabets = {} }
  if font_instance.GetFontObjectForAlphabet then
    for _, alphabet in ipairs(FONT_ALPHABETS) do
      local font_object = font_instance:GetFontObjectForAlphabet(alphabet)
      if font_object then
        backup.Alphabets[alphabet] = BackupFontObject(font_object)
      end
    end
  end
  return backup
end

local function RestoreSystemFont(font_instance, backup)
  if not font_instance or not backup then return end

  RestoreFontObject(font_instance, backup.Base)
  for alphabet, alphabet_backup in pairs(backup.Alphabets) do
    local font_object = font_instance:GetFontObjectForAlphabet(alphabet)
    if font_object then
      RestoreFontObject(font_object, alphabet_backup)
    end
  end
end

local DefaultSystemFonts = {
  NamePlate = BackupSystemFont(SystemFont_NamePlate),
  NamePlateFixed = BackupSystemFont(SystemFont_NamePlateFixed),
  LargeNamePlate = BackupSystemFont(SystemFont_LargeNamePlate),
  LargeNamePlateFixed = BackupSystemFont(SystemFont_LargeNamePlateFixed),
  NamePlateOutlined = BackupSystemFont(SystemFont_NamePlate_Outlined),
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

---------------------------------------------------------------------------------------------------
-- Font families: fallback fonts for Cyrillic and CJK characters
---------------------------------------------------------------------------------------------------

-- A font file only contains glyphs for some alphabets, so text in other alphabets (e.g., Cyrillic or Chinese names)
-- is shown as squares. A font family lets the client pick the font file per alphabet, like Blizzard's own nameplate
-- fonts do [GH-751].
local USE_FONT_FAMILIES = CreateFontFamily ~= nil

local FONT_FAMILY_FALLBACK_FILES = {
  russian = "Fonts\\FRIZQT___CYR.TTF",
  korean = "Fonts\\2002.TTF",
  simplifiedchinese = "Fonts\\ARKai_T.ttf",
  traditionalchinese = "Fonts\\blei00d.TTF",
}

-- On these clients, the selected font is (by default) a font for the client's alphabet, so it's used for that
-- alphabet instead of the fallback font
local LOCALE_ALPHABET = {
  ruRU = "russian",
  koKR = "korean",
  zhCN = "simplifiedchinese",
  zhTW = "traditionalchinese",
}
local CLIENT_ALPHABET = LOCALE_ALPHABET[GetLocale()]

local FontFamilies = {}
local FontFamilyCount = 0

local function SetShadow(font, shadow)
  if shadow then
    font:SetShadowOffset(1, -1)
    font:SetShadowColor(0, 0, 0, 1)
  else
    font:SetShadowColor(0, 0, 0, 0)
  end
end

local function GetFontFamily(file, size, flags, shadow)
  flags = flags or ""
  local key = file .. "|" .. tostring(size) .. "|" .. flags .. "|" .. tostring(shadow or false)

  local font_family = FontFamilies[key]
  if font_family == nil then
    local members = {
      { alphabet = "roman", file = file, height = size, flags = flags },
    }
    for alphabet, fallback_file in pairs(FONT_FAMILY_FALLBACK_FILES) do
      local member_file = (alphabet == CLIENT_ALPHABET) and file or fallback_file
      members[#members + 1] = { alphabet = alphabet, file = member_file, height = size, flags = flags }
    end

    FontFamilyCount = FontFamilyCount + 1
    local success, result = pcall(CreateFontFamily, ADDON_NAME .. "FontFamily" .. FontFamilyCount, members)
    -- Remember failures (false) so that creating the font family is not tried again
    font_family = success and result or false
    FontFamilies[key] = font_family

    -- The text is rendered with the member fonts of the font family, so a shadow set on the font string itself is
    -- ignored. Like with Blizzard's font families (defined in XML), the shadow must be set on the member fonts.
    if font_family then
      SetShadow(font_family, shadow)
      for i = 1, #members do
        local member_font = font_family:GetFontObjectForAlphabet(members[i].alphabet)
        if member_font then
          SetShadow(member_font, shadow)
        end
      end
    end
  end

  return font_family
end

-- Drop-in replacement for font_string:SetFont(file, size, flags) that adds fallback fonts for other alphabets. It
-- also sets the shadow, as the shadow of texts using a font family must be set on the font family's fonts.
function FontModule.SetFont(font_string, file, size, flags, shadow)
  local font_family = USE_FONT_FAMILIES and file and GetFontFamily(file, size, flags, shadow)
  if not font_family then
    font_string:SetFont(file, size, flags)
  elseif font_string:GetFontObject() ~= font_family then
    -- SetFontObject also applies the font object's text color, so keep the current one (e.g., set by the Color module)
    local r, g, b, a = font_string:GetTextColor()
    font_string:SetFontObject(font_family)
    font_string:SetTextColor(r, g, b, a)
  end

  SetShadow(font_string, shadow)
end

local FontSetFont = FontModule.SetFont

-- Sets an initial font for font strings whose font is later updated with FontModule.SetFont. A font set with
-- SetFont overrides any font object set later with SetFontObject, so it must not be used with font families.
function FontModule.SetInitialFont(font_string)
  if USE_FONT_FAMILIES then
    font_string:SetFontObject(SystemFont_NamePlate)
  else
    font_string:SetFont("Fonts\\FRIZQT__.TTF", 11)
  end
end

local function UpdateTextFont(font, db)
  FontSetFont(font, Addon.LibSharedMedia:Fetch('font', db.Typeface), db.Size, db.flags, db.Shadow)

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

-- Blizzard sets the text height of the name and health texts per font string (SetTextHeight in
-- NamePlateUnitFrameMixin:ApplyFrameOptions), but only when a nameplate is set up. Changing the font objects (as
-- SetNamesFonts does) overrides that height, so restore it on Blizzard's currently shown nameplates.
local function RestoreBlizzardTextHeights()
  local setup_options = _G.NamePlateSetupOptions
  local text_height = setup_options and setup_options.healthBarFontHeight
  if not text_height then return end

  for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
    local unit_frame = plate.UnitFrame
    if unit_frame and not unit_frame:IsForbidden() then
      if unit_frame.name then
        unit_frame.name:SetTextHeight(text_height)
      end
      local healthbar = unit_frame.HealthBarsContainer and unit_frame.HealthBarsContainer.healthBar
      if healthbar then
        for _, key in ipairs({ "Text", "LeftText", "RightText" }) do
          if healthbar[key] then
            healthbar[key]:SetTextHeight(text_height)
          end
        end
      end
    end
  end
end

function FontModule.ResetNamesFonts()
  RestoreSystemFont(SystemFont_NamePlate, DefaultSystemFonts.NamePlate)
  RestoreSystemFont(SystemFont_NamePlateFixed, DefaultSystemFonts.NamePlateFixed)
  RestoreSystemFont(SystemFont_LargeNamePlate, DefaultSystemFonts.LargeNamePlate)
  RestoreSystemFont(SystemFont_LargeNamePlateFixed, DefaultSystemFonts.LargeNamePlateFixed)
  RestoreSystemFont(SystemFont_NamePlate_Outlined, DefaultSystemFonts.NamePlateOutlined)

  RestoreBlizzardTextHeights()
end

---------------------------------------------------------------------------------------------------
-- Update of settings
---------------------------------------------------------------------------------------------------

function FontModule.UpdateSettings()
  Settings = Addon.db.profile.BlizzardSettings.Names
end