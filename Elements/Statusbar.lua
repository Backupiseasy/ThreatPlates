local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local ipairs = ipairs

-- WoW APIs

-- ThreatPlates APIs
local Font = Addon.Font
local BackdropTemplate = Addon.BackdropTemplate
local MODE_FOR_STYLE, ANCHOR_POINT_TEXT = Addon.MODE_FOR_STYLE, Addon.ANCHOR_POINT_TEXT

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS:

---------------------------------------------------------------------------------------------------
-- Methods of class Statusbar
---------------------------------------------------------------------------------------------------

local function AddTextArea(self, text_area)
  self.TextAreas[#self.TextAreas + 1] = text_area

  self[text_area] = self:CreateFontString(nil, "OVERLAY")
  self[text_area]:SetFont("Fonts\\FRIZQT__.TTF", 11)
end

local function UpdateSettings(self, db)
  self:SetSize(db.Width, db.Height)

  local texture = Addon.LibSharedMedia:Fetch('statusbar', db.Texture)
  self:SetStatusBarTexture(texture)
  self.Background:SetTexture(texture)

  self.Border:SetBackdrop({
    bgFile = Addon.LibSharedMedia:Fetch('statusbar', texture),
    edgeFile = Addon.LibSharedMedia:Fetch('border', db.BorderTexture),
    edgeSize = db.BorderEdgeSize,
    insets = {
      left = db.BorderInset,
      right = db.BorderInset,
      top = db.BorderInset,
      bottom = db.BorderInset,
    }
  })

  local border = self.Border
  border:SetPoint("TOPLEFT", self, "TOPLEFT", - db.BorderOffset, db.BorderOffset)
  border:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", db.BorderOffset, - db.BorderOffset)

  local bar_foreground_color = db.BarForegroundColor
  self:SetStatusBarColor(bar_foreground_color.r, bar_foreground_color.g, bar_foreground_color.b, bar_foreground_color.a)

  if db.BarBackgroundUseForegroundColor then
    self.Background:SetVertexColor(bar_foreground_color.r, bar_foreground_color.g, bar_foreground_color.b, 0.3)
  else
    local color = db.BarBackgroundColor
    self.Background:SetVertexColor(color.r, color.g, color.b, color.a)
  end

  if db.BackgroundUseForegroundColor then
    border:SetBackdropColor(bar_foreground_color.r, bar_foreground_color.g, bar_foreground_color.b, 0.3)
  else
    local color = db.BackgroundColor
    border:SetBackdropColor(color.r, color.g, color.b, color.a)
  end

  if db.BorderUseBarForegroundColor then
    border:SetBackdropBorderColor(bar_foreground_color.r, bar_foreground_color.g, bar_foreground_color.b, 1)
  elseif db.BorderUseBackgroundColor then
    if db.BackgroundUseForegroundColor then
      border:SetBackdropBorderColor(bar_foreground_color.r, bar_foreground_color.g, bar_foreground_color.b, 1)
    else
      local color = db.BackgroundColor
      border:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
    end
  else
    local color = db.BorderColor
    border:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
  end

  for _, text_area in ipairs(self.TextAreas) do
    self[text_area]:SetSize(db.Width, db.Height)
    if db[text_area].Show then
      Font:UpdateText(self, self[text_area], db[text_area])
      self[text_area]:Show()
    else
      self[text_area]:Hide()
    end
  end
end

local function UpdatePositioning(self, unit, db)
  db = db[MODE_FOR_STYLE[unit.style]]

  self:ClearAllPoints()
  self.Background:ClearAllPoints()

  local anchor = db.Anchor or "CENTER"
  if db.InsideAnchor == false then
    local anchor_point_text = ANCHOR_POINT_TEXT[anchor]
    self:SetPoint(anchor_point_text[2], self:GetParent(), anchor_point_text[1], db.HorizontalOffset or 0, db.VerticalOffset or 0)
  else -- db.InsideAnchor not defined in settings or true
    self:SetPoint(anchor, self:GetParent(), anchor, db.HorizontalOffset or 0, db.VerticalOffset or 0)
  end

  self.Background:SetPoint("TOPLEFT", self:GetStatusBarTexture(), "TOPRIGHT")
  self.Background:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT")
end

function Addon.CreateStatusbar(parent)
  local statusbar = _G.CreateFrame("StatusBar", nil, parent)

  statusbar:SetFrameLevel(parent:GetFrameLevel())
  statusbar:SetMinMaxValues(0, 100)

  statusbar.Background = statusbar:CreateTexture(nil, "ARTWORK")

  statusbar.Border = _G.CreateFrame("Frame", nil, statusbar, BackdropTemplate)
  statusbar.Border:SetFrameLevel(statusbar:GetFrameLevel())

  statusbar.UpdateSettings = UpdateSettings
  statusbar.UpdatePositioning = UpdatePositioning
  statusbar.AddTextArea = AddTextArea

  statusbar.TextAreas = {}

  return statusbar
end

