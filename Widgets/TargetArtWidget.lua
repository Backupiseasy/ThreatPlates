---------------------------------------------------------------------------------------------------
-- Target Art Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local FocusWidget = (not Addon.CLASSIC and Addon.Widgets:NewFocusWidget("Focus")) or {}
local Widget = Addon.Widgets:NewTargetWidget("TargetArt")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local abs, max, min = abs, max, min

-- WoW APIs
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

local ART_PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\TargetArtWidget\\"
local BACKDROP = {
  default = {
    edgeFile = ThreatPlates.Art .. "TP_WhiteSquare",
    edgeSize = 1.8,
    offset = 4,
  },
  squarethin = {
    edgeFile = ThreatPlates.Art .. "TP_WhiteSquare",
    edgeSize = 1,
    offset = 3,
  },
  threat_glow = {
    edgeFile = ThreatPlates.Art .. "TP_Threat",
    edgeSize = 10,
    offset = 5,
  },
  glow = {
    bgFile = ThreatPlates.Art .. "TP_WhiteSquare",
    edgeFile = ART_PATH .. "glow_border",
    edgeSize = 10,
    offset = 5,
    insets = { left = 5, right = 5, top = 5, bottom = 5 }
  },
}

local WidgetFrame

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local Settings, FocusSettings
local SettingsHV, FocusSettingsHV

local UpdateTexture, ShowBorder, NameModeOffsetX, NameModeOffsetY

local FocusWidgetFrame
local FocusUpdateTexture, FocusShowBorder, FocusNameModeOffsetX, FocusNameModeOffsetY

---------------------------------------------------------------------------------------------------
-- Common functions for target and focus widget
---------------------------------------------------------------------------------------------------

local function UpdateBorderTexture(db, widget_frame, texture_frame)
  local backdrop = BACKDROP[db.theme]
  texture_frame:SetBackdrop({
    bgFile = backdrop.bgFile,
    edgeFile = backdrop.edgeFile,
    edgeSize = backdrop.edgeSize,
    insets = backdrop.insets or { left = 0, right = 0, top = 0, bottom = 0 }
  })

  local offset = backdrop.offset
  texture_frame:SetPoint("TOPLEFT", widget_frame, "TOPLEFT", - offset, offset)
  texture_frame:SetPoint("BOTTOMRIGHT", widget_frame, "BOTTOMRIGHT", offset, - offset)

  texture_frame:SetBackdropBorderColor(db.r, db.g, db.b, db.a)
  texture_frame:SetBackdropColor(db.r, db.g, db.b, db.a - 0.70) -- 80/255 => 1 - 0.69

  texture_frame.LeftTexture:Hide()
  texture_frame.RightTexture:Hide()
end

local function UpdateSideTexture(db, widget_frame, texture_frame)
  local left_texture, right_texture = texture_frame.LeftTexture, texture_frame.RightTexture

  left_texture:SetTexture(ART_PATH .. db.theme)
  left_texture:SetTexCoord(0, 1, 0, 1)
  left_texture:SetVertexColor(db.r, db.g, db.b, db.a)
  left_texture:SetSize(db.Size, db.Size)
  left_texture:ClearAllPoints()
  left_texture:SetPoint("RIGHT", widget_frame, "LEFT", db.HorizontalOffset, db.VerticalOffset)

  right_texture:SetTexture(ART_PATH .. db.theme)
  right_texture:SetTexCoord(1, 0, 0, 1)
  right_texture:SetVertexColor(db.r, db.g, db.b, db.a)
  right_texture:SetSize(db.Size, db.Size)
  right_texture:ClearAllPoints()
  right_texture:SetPoint("LEFT", widget_frame, "RIGHT", -db.HorizontalOffset, db.VerticalOffset)

  left_texture:Show()
  right_texture:Show()
  texture_frame:SetBackdrop(nil)
end

local function UpdateCenterTexture(db, widget_frame, texture_frame)
  local left_texture, right_texture = texture_frame.LeftTexture, texture_frame.RightTexture

  left_texture:SetTexture(ART_PATH .. db.theme)
  left_texture:SetTexCoord(0, 1, 0, 1)
  left_texture:SetVertexColor(db.r, db.g, db.b, db.a)
  left_texture:SetSize(db.Size, db.Size)
  left_texture:ClearAllPoints()
  left_texture:SetPoint("CENTER", widget_frame, "CENTER", db.HorizontalOffset, db.VerticalOffset)

  left_texture:Show()
  right_texture:Hide()
  texture_frame:SetBackdrop(nil)
end

local UPDATE_TEXTURE_FUNCTIONS = {
  default = UpdateBorderTexture,
  squarethin = UpdateBorderTexture,
  arrows = UpdateSideTexture,
  arrow_down = UpdateCenterTexture,
  arrow_less_than = UpdateSideTexture,
  glow = UpdateBorderTexture,
  threat_glow = UpdateBorderTexture,
  arrows_legacy = UpdateSideTexture,
  bubble = UpdateSideTexture,
  crescent = UpdateSideTexture,
}

local FRAME_LEVEL_BY_TEXTURE = {
  default = 6,
  squarethin = 6,
  arrows = 14,
  arrow_down = 14,
  arrow_less_than = 14,
  glow = 4,
  threat_glow = 4,
  arrows_legacy = 14,
  bubble = 14,
  crescent = 14,
}

local function GetHeadlineViewHeight(db_name, db_statustext)
  return abs(max(db_name.VerticalOffset, db_statustext.VerticalOffset) - min(db_name.VerticalOffset, db_statustext.VerticalOffset)) + (db_name.Font.Size + db_statustext.Font.Size) / 2
end

local function GetTargetTextureY(db_name, db_statustext)
  if db_name.VerticalOffset >= db_statustext.VerticalOffset then
    -- name above status text
    return db_name.VerticalOffset - 10 + (db_name.Font.Size / 2) - ((GetHeadlineViewHeight(db_name, db_statustext) - 18) / 2)
  else
    -- status text above name
    return db_name.VerticalOffset - 10 + (db_statustext.Font.Size / 2) - ((GetHeadlineViewHeight(db_name, db_statustext) - 18) / 2)
  end
end

---------------------------------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------------------------------

function Widget:PLAYER_TARGET_CHANGED()
  local plate = GetNamePlateForUnit("target")

  local tp_frame = plate and plate.TPFrame
  if tp_frame and tp_frame.Active then
    self:OnTargetUnitAdded(tp_frame, tp_frame.unit)
  else
    WidgetFrame:Hide()
    WidgetFrame:SetParent(nil)
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create()
  if not WidgetFrame then
    local widget_frame = _G.CreateFrame("Frame", nil)
    widget_frame:Hide()

    WidgetFrame = widget_frame

    local healthbar_mode_frame = _G.CreateFrame("Frame", nil, widget_frame)
    healthbar_mode_frame:SetFrameLevel(widget_frame:GetFrameLevel())
    healthbar_mode_frame.LeftTexture = widget_frame:CreateTexture(nil, "BACKGROUND", 0)
    healthbar_mode_frame.RightTexture = widget_frame:CreateTexture(nil, "BACKGROUND", 0)
    widget_frame.HealthbarMode = healthbar_mode_frame

    widget_frame.NameModeTexture = widget_frame:CreateTexture(nil, "BACKGROUND", 0)
    widget_frame.NameModeTexture:SetTexture(ThreatPlates.Art .. "Target")

    self:UpdateLayout()
  end

  self:PLAYER_TARGET_CHANGED()
end

function Widget:IsEnabled()
  return Settings.ON or Settings.ShowInHeadlineView
end

function Widget:OnEnable()
  self:SubscribeEvent("PLAYER_TARGET_CHANGED")
end

function Widget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return Settings.ShowInHeadlineView
  elseif style ~= "etotem" then
    return Settings.ON
  end

  return false
end

function Widget:OnTargetUnitAdded(tp_frame, unit)
  local widget_frame = WidgetFrame

  if self:EnabledForStyle(unit.style, unit) then
    widget_frame:SetParent(tp_frame)
    widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + FRAME_LEVEL_BY_TEXTURE[Settings.theme])
    widget_frame:ClearAllPoints()
    widget_frame:SetAllPoints(tp_frame)

    local healthbar_mode_frame = widget_frame.HealthbarMode
    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
      healthbar_mode_frame.LeftTexture:Hide()
      healthbar_mode_frame.RightTexture:Hide()
      healthbar_mode_frame:Hide()

      widget_frame.NameModeTexture:Show()
    else
      if ShowBorder then
        healthbar_mode_frame:Show()
        healthbar_mode_frame.LeftTexture:Hide()
        healthbar_mode_frame.RightTexture:Hide()
      else
        healthbar_mode_frame:Hide()
        healthbar_mode_frame.LeftTexture:Show()
        healthbar_mode_frame.RightTexture:SetShown(UpdateTexture ~= UpdateCenterTexture)
      end

      widget_frame:SetAllPoints(tp_frame.visual.Healthbar)
      widget_frame.NameModeTexture:Hide()
    end

    widget_frame:Show()
  else
    widget_frame:Hide()
    widget_frame:SetParent(nil)
  end
end

function Widget:OnTargetUnitRemoved()
  WidgetFrame:Hide()
end

function Widget:UpdateLayout()
  local widget_frame = WidgetFrame

  UpdateTexture(Settings, widget_frame, widget_frame.HealthbarMode)
  local db = TidyPlatesThreat.db.profile
  widget_frame.NameModeTexture:SetSize(128, 32 * GetHeadlineViewHeight(db.Name.NameMode, db.StatusText.NameMode) / 18)
  widget_frame.NameModeTexture:SetPoint("CENTER", widget_frame, "CENTER", NameModeOffsetX, NameModeOffsetY)
end

function Widget:UpdateSettings()
  local db = TidyPlatesThreat.db.profile
  Settings = db.targetWidget

  NameModeOffsetX = db.Name.NameMode.HorizontalOffset
  NameModeOffsetY = GetTargetTextureY(db.Name.NameMode, db.StatusText.NameMode)

  UpdateTexture = UPDATE_TEXTURE_FUNCTIONS[Settings.theme]
  ShowBorder = UpdateTexture ~= UpdateSideTexture and UpdateTexture ~= UpdateCenterTexture

  Widget:UpdateAllFramesAfterSettingsUpdate()
end

function Widget:UpdateAllFramesAfterSettingsUpdate()
  -- Update the widget if it was already created (not true for immediately after Reload UI or if it was never enabled
  -- in this since last Reload UI)
  if WidgetFrame then
    self:UpdateLayout()
    self:PLAYER_TARGET_CHANGED()
  end
end

---------------------------------------------------------------------------------------------------
-- Focus Widget functions
---------------------------------------------------------------------------------------------------

function FocusWidget:PLAYER_FOCUS_CHANGED()
  local plate = GetNamePlateForUnit("focus")

  local tp_frame = plate and plate.TPFrame
  if tp_frame and tp_frame.Active then
    self:OnFocusUnitAdded(tp_frame, tp_frame.unit)
  else
    FocusWidgetFrame:Hide()
    FocusWidgetFrame:SetParent(nil)
  end
end

function FocusWidget:Create()
  if not FocusWidgetFrame then
    local widget_frame = _G.CreateFrame("Frame", nil)
    widget_frame:Hide()

    FocusWidgetFrame = widget_frame

    local healthbar_mode_frame = _G.CreateFrame("Frame", nil, widget_frame)
    healthbar_mode_frame:SetFrameLevel(widget_frame:GetFrameLevel())
    healthbar_mode_frame.LeftTexture = widget_frame:CreateTexture(nil, "BACKGROUND", 0)
    healthbar_mode_frame.RightTexture = widget_frame:CreateTexture(nil, "BACKGROUND", 0)
    widget_frame.HealthbarMode = healthbar_mode_frame

    widget_frame.NameModeTexture = widget_frame:CreateTexture(nil, "BACKGROUND", 0)
    widget_frame.NameModeTexture:SetTexture(ThreatPlates.Art .. "Target")

    self:UpdateLayout()
  end

  self:PLAYER_FOCUS_CHANGED()
end

function FocusWidget:IsEnabled()
  return FocusSettings.ON or FocusSettings.FocusSettings
end

function FocusWidget:OnEnable()
  self:SubscribeEvent("PLAYER_FOCUS_CHANGED")
end

function FocusWidget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return FocusSettings.FocusSettings
  elseif style ~= "etotem" then
    return FocusSettings.ON
  end

  return false
end

function FocusWidget:OnFocusUnitAdded(tp_frame, unit)
  local widget_frame = FocusWidgetFrame

  if self:EnabledForStyle(unit.style, unit) then
    widget_frame:SetParent(tp_frame)
    widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + FRAME_LEVEL_BY_TEXTURE[FocusSettings.theme])
    widget_frame:ClearAllPoints()
    widget_frame:SetAllPoints(tp_frame.visual.healthbar)

    local healthbar_mode_frame = widget_frame.HealthbarMode
    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
      healthbar_mode_frame.LeftTexture:Hide()
      healthbar_mode_frame.RightTexture:Hide()
      healthbar_mode_frame:Hide()

      local db = FocusSettings
      widget_frame.NameModeTexture:SetVertexColor(db.r, db.g, db.b, db.a)
      widget_frame.NameModeTexture:Show()
    else
      if FocusShowBorder then
        healthbar_mode_frame:Show()
        healthbar_mode_frame.LeftTexture:Hide()
        healthbar_mode_frame.RightTexture:Hide()
      else
        healthbar_mode_frame:Hide()
        healthbar_mode_frame.LeftTexture:Show()
        healthbar_mode_frame.RightTexture:SetShown(FocusUpdateTexture ~= UpdateCenterTexture)
      end

      widget_frame.NameModeTexture:Hide()
    end

    widget_frame:Show()
  else
    widget_frame:Hide()
    widget_frame:SetParent(nil)
  end
end

function FocusWidget:OnFocusUnitRemoved()
  FocusWidgetFrame:Hide()
end

function FocusWidget:UpdateLayout()
  local widget_frame = FocusWidgetFrame

  FocusUpdateTexture(FocusSettings, widget_frame, widget_frame.HealthbarMode)
  local db = TidyPlatesThreat.db.profile
  widget_frame.NameModeTexture:SetSize(128, 32 * GetHeadlineViewHeight(db.Name.NameMode, db.StatusText.NameMode) / 18)
  widget_frame.NameModeTexture:SetPoint("CENTER", widget_frame, "CENTER", FocusNameModeOffsetX, FocusNameModeOffsetY)
end

function FocusWidget:UpdateSettings()
  local db = TidyPlatesThreat.db.profile
  FocusSettings = db.FocusWidget

  FocusNameModeOffsetX = db.Name.NameMode.HorizontalOffset
  FocusNameModeOffsetY = GetTargetTextureY(db.Name.NameMode, db.StatusText.NameMode)

  FocusUpdateTexture = UPDATE_TEXTURE_FUNCTIONS[FocusSettings.theme]
  FocusShowBorder = FocusUpdateTexture ~= UpdateSideTexture and FocusUpdateTexture ~= UpdateCenterTexture

  FocusWidget:UpdateAllFramesAfterSettingsUpdate()
end

function FocusWidget:UpdateAllFramesAfterSettingsUpdate()
  -- Update the widget if it was already created (not true for immediately after Reload UI or if it was never enabled
  -- in this since last Reload UI)
  if FocusWidgetFrame then
    self:UpdateLayout()
    self:PLAYER_FOCUS_CHANGED()
  end
end