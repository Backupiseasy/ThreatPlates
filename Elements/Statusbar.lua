local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local ipairs = ipairs

-- WoW APIs

-- ThreatPlates APIs
local LSM = Addon.ThreatPlates.Media
local Font = Addon.Font
local ANCHOR_POINT_TEXT = Addon.ANCHOR_POINT_TEXT

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS:

---------------------------------------------------------------------------------------------------
-- Methods of class Statusbar
---------------------------------------------------------------------------------------------------

local MODE_FOR_STYLE = {
  dps = "HealthbarMode",
  tank = "HealthbarMode",
  normal = "HealthbarMode",
  totem = "HealthbarMode",
  unique = "HealthbarMode",
  NameOnly = "NameMode",
  ["NameOnly-Unique"] = "NameMode",
}

local function AddTextArea(self, text_area)
  self.TextAreas[#self.TextAreas + 1] = text_area

  self[text_area] = self:CreateFontString(nil, "OVERLAY")
  self[text_area]:SetFont("Fonts\\FRIZQT__.TTF", 11)
end

local function UpdateSettings(self, db)
  self:SetSize(db.Width, db.Height)

  local texture = LSM:Fetch('statusbar', db.Texture)
  self:SetStatusBarTexture(texture)
  self.Background:SetTexture(texture)

  local border = self.Border

  local backdrop = border:GetBackdrop() or {}
  backdrop.edgeFile = LSM:Fetch('border', db.BorderTexture)
  backdrop.edgeSize = db.BorderEdgeSize
  backdrop.insets = backdrop.insets or {}
  backdrop.insets.left = db.BorderInset
  backdrop.insets.right = db.BorderInset
  backdrop.insets.top = db.BorderInset
  backdrop.insets.bottom = db.BorderInset
  border:SetBackdrop(backdrop)

  border:SetPoint("TOPLEFT", self, "TOPLEFT", - db.BorderOffset, db.BorderOffset)
  border:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", db.BorderOffset, - db.BorderOffset)

  local color = db.Color
  self:SetStatusBarColor(color.r, color.g, color.b, color.a)

  if db.BackgroundUseForegroundColor then
    self.Background:SetVertexColor(color.r, color.g, color.b, 0.3)
  else
    color = db.BackgroundColor
    self.Background:SetVertexColor(color.r, color.g, color.b, color.a)
  end

  if db.BorderUseForegroundColor then
    border:SetBackdropBorderColor(color.r, color.g, color.b, 1)
  elseif db.BorderUseBackgroundColor then
    color = db.BackgroundColor
    border:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
  else
    color = db.BorderColor
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

  local anchor = db.Anchor or "CENTER"
  self:ClearAllPoints()
  if db.InsideAnchor == false then
    local anchor_point_text = ANCHOR_POINT_TEXT[anchor]
    self:SetPoint(anchor_point_text[2], self:GetParent(), anchor_point_text[1], db.HorizontalOffset or 0, db.VerticalOffset or 0)
  else -- db.InsideAnchor not defined in settings or true
    self:SetPoint(anchor, self:GetParent(), anchor, db.HorizontalOffset or 0, db.VerticalOffset or 0)
  end
end

function Addon.CreateStatusbar(parent)
  local statusbar = _G.CreateFrame("StatusBar", nil, parent)

  statusbar:SetFrameLevel(parent:GetFrameLevel())
  statusbar:SetMinMaxValues(0, 100)

  statusbar.Background = statusbar:CreateTexture(nil, "BACKGROUND")
  statusbar.Background:SetAllPoints(statusbar)

  statusbar.Border = _G.CreateFrame("Frame", nil, statusbar)
  statusbar.Border:SetFrameLevel(statusbar:GetFrameLevel())

  statusbar.UpdateSettings = UpdateSettings
  statusbar.UpdatePositioning = UpdatePositioning
  statusbar.AddTextArea = AddTextArea

  statusbar.TextAreas = {}

  return statusbar
end

