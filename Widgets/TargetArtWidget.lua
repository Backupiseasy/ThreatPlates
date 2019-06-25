---------------------------------------------------------------------------------------------------
-- Target Art Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewTargetWidget("TargetArt")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

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
  }
}

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local Settings
local SettingsHV
local WidgetFrame
local NameModeOffsetX, NameModeOffsetY

---------------------------------------------------------------------------------------------------
-- Target Art Widget Functions
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
    local widget_frame = CreateFrame("Frame", nil)
    widget_frame:Hide()

    WidgetFrame = widget_frame

    local healthbar_mode_frame = CreateFrame("Frame", nil, widget_frame)
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
  return Settings.ON or SettingsHV.ShowTargetHighlight
end

function Widget:OnEnable()
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function Widget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return SettingsHV.ShowTargetHighlight
  elseif style ~= "etotem" then
    return Settings.ON
  end

  return false
end

function Widget:OnTargetUnitAdded(tp_frame, unit)
  local db = Settings
  local widget_frame = WidgetFrame

  if self:EnabledForStyle(unit.style, unit) then
    widget_frame:SetParent(tp_frame)
    widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 6)
    widget_frame:ClearAllPoints()
    widget_frame:SetAllPoints(tp_frame.visual.healthbar)

    local healthbar_mode_frame = widget_frame.HealthbarMode
    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
      healthbar_mode_frame.LeftTexture:Hide()
      healthbar_mode_frame.RightTexture:Hide()
      healthbar_mode_frame:Hide()

      widget_frame.NameModeTexture:Show()
    else
      if db.theme == "default" or db.theme == "squarethin" then
        healthbar_mode_frame:Show()
        healthbar_mode_frame.LeftTexture:Hide()
        healthbar_mode_frame.RightTexture:Hide()
      else
        healthbar_mode_frame:Hide()
        healthbar_mode_frame.LeftTexture:Show()
        healthbar_mode_frame.RightTexture:Show()
      end

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

local function GetHeadlineViewHeight()
  local db = SettingsHV

  return abs(max(db.name.y, db.customtext.y) - min(db.name.y, db.customtext.y)) + (db.name.size + db.customtext.size) / 2
end

local function GetTargetTextureY()
  local db = SettingsHV

  if db.name.y >= db.customtext.y then
    -- name above status text
    return db.name.y - 10 + (db.name.size / 2) - ((GetHeadlineViewHeight() - 18) / 2)
  else
    -- status text above name
    return db.customtext.y - 10 + (db.customtext.size / 2) - ((GetHeadlineViewHeight() - 18) / 2)
  end
end

function Widget:UpdateLayout()
  local db = Settings
  local widget_frame = WidgetFrame

  local healthbar_mode_frame = widget_frame.HealthbarMode
  if db.theme == "default" or db.theme == "squarethin" then
    local backdrop = BACKDROP[db.theme]
    healthbar_mode_frame:SetBackdrop({
      --edgeFile = PATH .. db.theme,
      edgeFile = backdrop.edgeFile,
      edgeSize = backdrop.edgeSize,
      insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })

    local offset = backdrop.offset
    healthbar_mode_frame:SetPoint("TOPLEFT", widget_frame, "TOPLEFT", - backdrop.offset, offset)
    healthbar_mode_frame:SetPoint("BOTTOMRIGHT", widget_frame, "BOTTOMRIGHT", offset, - offset)

    healthbar_mode_frame:SetBackdropBorderColor(db.r, db.g, db.b, db.a)

    healthbar_mode_frame.LeftTexture:Hide()
    healthbar_mode_frame.RightTexture:Hide()
  else
    healthbar_mode_frame.LeftTexture:SetTexture(ART_PATH .. db.theme)
    healthbar_mode_frame.LeftTexture:SetTexCoord(0, 0.25, 0, 1)
    healthbar_mode_frame.LeftTexture:SetVertexColor(db.r, db.g, db.b, db.a)
    healthbar_mode_frame.LeftTexture:SetSize(64, 64)
    healthbar_mode_frame.LeftTexture:SetPoint("RIGHT", widget_frame, "LEFT")

    healthbar_mode_frame.RightTexture:SetTexture(ART_PATH .. db.theme)
    healthbar_mode_frame.RightTexture:SetTexCoord(0.75, 1, 0, 1)
    healthbar_mode_frame.RightTexture:SetVertexColor(db.r, db.g, db.b, db.a)
    healthbar_mode_frame.RightTexture:SetSize(64, 64)
    healthbar_mode_frame.RightTexture:SetPoint("LEFT", widget_frame, "RIGHT")

    healthbar_mode_frame.LeftTexture:Show()
    healthbar_mode_frame.RightTexture:Show()
    healthbar_mode_frame:SetBackdrop(nil)
  end

  widget_frame.NameModeTexture:SetSize(128, 32 * GetHeadlineViewHeight() / 18)
  widget_frame.NameModeTexture:SetPoint("CENTER", widget_frame, "CENTER", NameModeOffsetX, NameModeOffsetY)
end

function Widget:UpdateSettings()
  Settings = TidyPlatesThreat.db.profile.targetWidget
  SettingsHV = TidyPlatesThreat.db.profile.HeadlineView

  NameModeOffsetX = SettingsHV.name.x
  NameModeOffsetY = GetTargetTextureY()

  -- Update the widget if it was already created (not true for immediately after Reload UI or if it was never enabled
  -- in this since last Reload UI)
  if WidgetFrame then
    self:UpdateLayout()
    self:PLAYER_TARGET_CHANGED()
  end
end