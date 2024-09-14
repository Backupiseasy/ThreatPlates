---------------------------------------------------------------------------------------------------
-- Target Art Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local FocusWidget = (not Addon.IS_CLASSIC and Addon.Widgets:NewFocusWidget("Focus")) or {}
local Widget = Addon.Widgets:NewTargetWidget("TargetArt")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs = pairs

-- WoW APIs
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local SetUnitCursorTexture, PixelUtil_SetPoint = SetUnitCursorTexture, PixelUtil.SetPoint
local UnitIsUnit = UnitIsUnit

-- ThreatPlates APIs
local BackdropTemplate = Addon.BackdropTemplate
local MODE_FOR_STYLE, AnchorFrameTo = Addon.MODE_FOR_STYLE, Addon.AnchorFrameTo
local CVars = Addon.CVars

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
    inset = 5,
  },
}

local ADJUST_BORDER_FOR_SMALL_HEALTHBAR = {
  threat_glow = {
    [9] = { edgeSize = 9, offset = 5, },
    [8] = { edgeSize = 9, offset = 5, },
    [7] = { edgeSize = 7, offset = 4, },
    [6] = { edgeSize = 7, offset = 4, },
    [5] = { edgeSize = 5, offset = 3, },
    [4] = { edgeSize = 5, offset = 3, },
    [3] = { edgeSize = 2, offset = 2, },
    [2] = { edgeSize = 2, offset = 2, },
    [1] = { edgeSize = 2, offset = 2, },
  },
  glow = {
    [9] = { edgeSize = 9, offset = 5, },
    [8] = { edgeSize = 9, offset = 5, },
    [7] = { edgeSize = 7, offset = 4, },
    [6] = { edgeSize = 7, offset = 4, },
    [5] = { edgeSize = 5, offset = 3, },
    [4] = { edgeSize = 5, offset = 3, },
    [3] = { edgeSize = 2, offset = 2, },
    [2] = { edgeSize = 2, offset = 2, },
    [1] = { edgeSize = 2, offset = 2, inset = 2},
  },
}

local FRAME_LEVEL_BY_TEXTURE = {
  default = 0,
  squarethin = 0,
  arrows = 6,
  arrow_down = 6,
  arrow_less_than = 6,
  glow = -2,
  threat_glow = -2,
  arrows_legacy = 6,
  bubble = 6,
  crescent = 6,
  Stripes = 0,
}

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local Settings, FocusSettings
local TargetHighlightFrames = {
  target = nil,
  softfriend = nil,
  softinteract = nil,
  softenemy = nil
}
local SoftTargetSettings = {
  target = {},
  softfriend = {},
  softinteract = {},
  softenemy = {},
  GameObject = {},
  focus = {}
}
local UpdateTexture, ShowBorder, NameModeOffsetX, NameModeOffsetY

local SettingsHV, FocusSettingsHV
local FocusWidgetFrame
local FocusUpdateTexture, FocusShowBorder, FocusNameModeOffsetX, FocusNameModeOffsetY

---------------------------------------------------------------------------------------------------
-- Common functions for target and focus widget
---------------------------------------------------------------------------------------------------

local function GetHighlightColor(widget_frame)
  -- TargetUnitID is not yet set when the widget is created
  if widget_frame.TargetUnitID then 
    local color = SoftTargetSettings[widget_frame.TargetUnitID].Color
    return color.r, color.g, color.b, color.a
  else
    return 1, 1, 1, 1 
  end
end

local  function UpdateBorderTexture(db, widget_frame, texture_frame)
  local backdrop = BACKDROP[db.theme]

  local offset = backdrop.offset
  local edge_size = backdrop.edgeSize
  local inset = backdrop.inset or 0

  local border_settings_adjustment = ADJUST_BORDER_FOR_SMALL_HEALTHBAR[db.theme]
  if border_settings_adjustment  then
    local border_settings = border_settings_adjustment[Addon.db.profile.settings.healthbar.height]
    if border_settings then
      edge_size = border_settings.edgeSize
      offset = border_settings.offset
      inset = border_settings.inset or inset
    end
  end

  texture_frame:SetBackdrop({
    bgFile = backdrop.bgFile,
    edgeFile = backdrop.edgeFile,
    edgeSize = edge_size,
    insets = { left = inset, right = inset, top = inset, bottom = inset }
  })

  texture_frame:SetPoint("TOPLEFT", widget_frame, "TOPLEFT", - offset, offset)
  texture_frame:SetPoint("BOTTOMRIGHT", widget_frame, "BOTTOMRIGHT", offset, - offset)

  local r, g, b, a = GetHighlightColor(widget_frame)
  texture_frame:SetBackdropBorderColor(r, g, b, a)
  local backdrop_alpha = a - 0.70 -- 80/255 => 1 - 0.69
  if backdrop_alpha < 0 then
    backdrop_alpha = 0
  end
  texture_frame:SetBackdropColor(r, g, b, backdrop_alpha)

  texture_frame.LeftTexture:Hide()
  texture_frame.RightTexture:Hide()
end

local function UpdateSideTexture(db, widget_frame, texture_frame)
  local left_texture, right_texture = texture_frame.LeftTexture, texture_frame.RightTexture

  local r, g, b, a = GetHighlightColor(widget_frame)
  left_texture:SetTexture(ART_PATH .. db.theme)
  left_texture:SetTexCoord(0, 1, 0, 1)
  left_texture:SetVertexColor(r, g, b, a)
  left_texture:SetSize(db.Size, db.Size)
  left_texture:ClearAllPoints()
  left_texture:SetPoint("RIGHT", widget_frame, "LEFT", db.HorizontalOffset, db.VerticalOffset)

  right_texture:SetTexture(ART_PATH .. db.theme)
  right_texture:SetTexCoord(1, 0, 0, 1)
  right_texture:SetVertexColor(r, g, b, a)
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
  left_texture:SetVertexColor(GetHighlightColor(widget_frame))
  left_texture:SetSize(db.Size, db.Size)
  left_texture:ClearAllPoints()
  left_texture:SetPoint("CENTER", widget_frame, "CENTER", db.HorizontalOffset, db.VerticalOffset)

  left_texture:Show()
  right_texture:Hide()
  texture_frame:SetBackdrop(nil)
end

local function UpdateOverlayTexture(db, widget_frame, texture_frame)
  local left_texture, right_texture = texture_frame.LeftTexture, texture_frame.RightTexture

  left_texture:SetTexture("Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\TargetArtWidget\\" .. db.theme)
  left_texture:SetTexCoord(0, 1, 0.4375, 0.5625)
  left_texture:SetVertexColor(GetHighlightColor(widget_frame))
  left_texture:ClearAllPoints()
  left_texture:SetAllPoints(widget_frame)

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
  Stripes = UpdateOverlayTexture,
}

local function GetHeadlineViewHeight(db)
  return abs(max(db.name.y, db.customtext.y) - min(db.name.y, db.customtext.y)) + (db.name.size + db.customtext.size) / 2
end

local function GetTargetTextureY(db)
  if db.name.y >= db.customtext.y then
    -- name above status text
    return db.name.y - 10 + (db.name.size / 2) - ((GetHeadlineViewHeight(db) - 18) / 2)
  else
    -- status text above name
    return db.customtext.y - 10 + (db.customtext.size / 2) - ((GetHeadlineViewHeight(db) - 18) / 2)
  end
end

local function HideWidgetFrame(widget_frame)
  widget_frame:Hide()
  widget_frame:SetParent(nil)
end

---------------------------------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------------------------------

local function OnSoftTargetIconUpdate(widget_frame, target_unitid, unit)
  local soft_target_icon = widget_frame.SoftTargetIcon
  if SoftTargetSettings[target_unitid].Enabled then 
    local size = Settings.SoftTarget.Icon.Size
    widget_frame.SoftTargetIconFrame:SetSize(size, size)
    soft_target_icon:SetDesaturated(false)
    soft_target_icon:SetIgnoreParentAlpha(true)
    soft_target_icon:SetSize(size, size)

    -- widget_frame.unit is not defined here always, so it's only safe to use tp_frame's unit
    local unit_curser_texture =  SetUnitCursorTexture(soft_target_icon, unit.unitid, nil, true)
    if not unit_curser_texture then
      soft_target_icon:SetTexture(136243)
    end
    
    AnchorFrameTo(Settings.SoftTarget.Icon[MODE_FOR_STYLE[unit.style]] or Settings.SoftTarget.Icon.HealthbarMode, soft_target_icon, widget_frame)
    
    widget_frame.SoftTargetIconFrame:Show()
    soft_target_icon:Show()   
  else
    widget_frame.SoftTargetIconFrame:Hide()
    soft_target_icon:Hide()   
  end
end

local function PlayerTargetChanged(target_unitid)
  local widget_frame = TargetHighlightFrames[target_unitid]
  
  -- ! Don't overwrite the target with a style if it's becoming a action target as well
  local tp_frame = Widget:GetThreatPlateForUnit(target_unitid)
  if tp_frame and (not UnitIsUnit("target", tp_frame.unit.unitid) or target_unitid == "target") then
    local unit = tp_frame.unit
    if Widget:EnabledForStyle(unit.style, unit) then
      local healthbar = tp_frame.visual.healthbar
      widget_frame:SetParent(tp_frame)
      widget_frame:SetFrameLevel(healthbar:GetFrameLevel() + FRAME_LEVEL_BY_TEXTURE[Settings.theme])
      --widget_frame.HealthbarMode:SetFrameLevel(widget_frame:GetFrameLevel())
      widget_frame:ClearAllPoints()
      widget_frame:SetAllPoints(healthbar)
    
      Widget:UpdateTargetUnitHighlight(widget_frame, target_unitid, unit)
      OnSoftTargetIconUpdate(widget_frame, target_unitid, unit)

      widget_frame:Show()
    else
      HideWidgetFrame(widget_frame)
    end
  else
    HideWidgetFrame(widget_frame)
  end
end

function Widget:PLAYER_TARGET_CHANGED()
  PlayerTargetChanged("target")  
end

function Widget:PLAYER_SOFT_ENEMY_CHANGED()
  PlayerTargetChanged("softenemy")
end

function Widget:PLAYER_SOFT_FRIEND_CHANGED()
  PlayerTargetChanged("softfriend")
end

function Widget:PLAYER_SOFT_INTERACT_CHANGED(oldTarget, newTarget)
  PlayerTargetChanged("softinteract")
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

local function UpdateTargetHighlightFrame(widget_frame)
  UpdateTexture(Settings, widget_frame, widget_frame.HealthbarMode)
  widget_frame.NameModeTexture:SetSize(128, 32 * GetHeadlineViewHeight(SettingsHV) / 18)
  widget_frame.NameModeTexture:SetPoint("CENTER", widget_frame, "CENTER", NameModeOffsetX, NameModeOffsetY)
end

local function CreateTargetHighlightFrame(target_unitid)
  if not TargetHighlightFrames[target_unitid] then
    local widget_frame = _G.CreateFrame("Frame", nil)
    widget_frame:Hide()

    widget_frame.TargetUnitID = target_unitid

    local healthbar_mode_frame = _G.CreateFrame("Frame", nil, widget_frame, BackdropTemplate)
    healthbar_mode_frame:SetFrameLevel(widget_frame:GetFrameLevel())
    healthbar_mode_frame.LeftTexture = widget_frame:CreateTexture(nil, "ARTWORK", nil, 7)
    healthbar_mode_frame.RightTexture = widget_frame:CreateTexture(nil, "ARTWORK", nil, 0)
    widget_frame.HealthbarMode = healthbar_mode_frame

    widget_frame.NameModeTexture = widget_frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    widget_frame.NameModeTexture:SetTexture(ThreatPlates.Art .. "Target")

    -- Create soft target / interact icon
    local soft_target_icon_frame = _G.CreateFrame("Frame",nil, widget_frame, BackdropTemplate)
    local soft_target_icon = soft_target_icon_frame:CreateTexture("$parentIcon", "OVERLAY")
    soft_target_icon:SetParent(widget_frame)
    soft_target_icon:SetTexture(136243)
    soft_target_icon:Show()
    
    soft_target_icon_frame:SetFrameLevel(widget_frame:GetFrameLevel())
    soft_target_icon_frame.Mask = soft_target_icon_frame:CreateMaskTexture(nil, "OVERLAY", nil, 1)
    soft_target_icon_frame.Mask:Show()
    soft_target_icon_frame.Mask:SetAtlas("CircleMaskScalable", true)

    soft_target_icon:AddMaskTexture(soft_target_icon_frame.Mask)

    soft_target_icon_frame.Mask:ClearAllPoints()
    PixelUtil_SetPoint(soft_target_icon_frame.Mask, "CENTER", soft_target_icon_frame, "CENTER", 0, 0)
    soft_target_icon_frame.Mask:SetAllPoints(soft_target_icon)
    soft_target_icon_frame:Hide()     

    widget_frame.SoftTargetIconFrame = soft_target_icon_frame
    widget_frame.SoftTargetIcon = soft_target_icon

    UpdateTargetHighlightFrame(widget_frame)
    
    TargetHighlightFrames[target_unitid] = widget_frame
  end
end

function Widget:Create()
  CreateTargetHighlightFrame("target")
  CreateTargetHighlightFrame("softfriend")
  CreateTargetHighlightFrame("softinteract")
  CreateTargetHighlightFrame("softenemy")
end

function Widget:IsEnabled()
  local db = Addon.db.profile
  return db.targetWidget.ON or db.HeadlineView.ShowTargetHighlight
end

function Widget:OnEnable()
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
  self:RegisterEvent("PLAYER_SOFT_FRIEND_CHANGED")
  self:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED")
  self:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
end

function Widget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return SettingsHV.ShowTargetHighlight
  else
    return Settings.ON
  end
end

function Widget:UpdateTargetUnitHighlight(widget_frame, target_unitid, unit)
  local healthbar_mode_frame = widget_frame.HealthbarMode
  if not SoftTargetSettings[target_unitid].Highlight or unit.style == "etotem" then 
    healthbar_mode_frame.LeftTexture:Hide()
    healthbar_mode_frame.RightTexture:Hide()
    healthbar_mode_frame:Hide()

    widget_frame.NameModeTexture:Hide()
  elseif unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
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
      healthbar_mode_frame.RightTexture:SetShown(UpdateTexture == UpdateSideTexture)
    end

    widget_frame.NameModeTexture:Hide()
  end
end

function Widget:OnTargetUnitAdded(tp_frame, unit)
  -- For now, we must initialize all targets here as this is not only called when the target
  -- changes, but also wenn initially initializing the unit or when there is a style update

  -- This unit is only called when the current unit is also the current target
  -- After login/reload, SOFT_TARGET events are fired, but GetNamePlateForUnit does not yet return a Nameplate
  -- for these unitids ...
  if unit.isTarget then    
    PlayerTargetChanged("target")
  elseif unit.IsSoftInteractTarget then
    PlayerTargetChanged("softinteract")
  elseif unit.IsSoftEnemyTarget then        
    PlayerTargetChanged("softenemy")
  elseif unit.IsSoftFriendTarget then    
    PlayerTargetChanged("softfriend")
  else
    HideWidgetFrame(TargetHighlightFrames.target)
    HideWidgetFrame(TargetHighlightFrames.softfriend)
    HideWidgetFrame(TargetHighlightFrames.softenemy)
    HideWidgetFrame(TargetHighlightFrames.softinteract)
  end
end

function Widget:OnTargetUnitRemoved(tp_frame, unit)
  if unit.isTarget then    
    HideWidgetFrame(TargetHighlightFrames.target)
  end
  if unit.IsSoftInteractTarget then
    HideWidgetFrame(TargetHighlightFrames.softfriend)
  end
  if unit.IsSoftEnemyTarget then        
    HideWidgetFrame(TargetHighlightFrames.softenemy)
  end
  if unit.IsSoftFriendTarget then    
    HideWidgetFrame(TargetHighlightFrames.softinteract)
  end
end

function Widget:UpdateSettings()
  Settings = Addon.db.profile.targetWidget
  SettingsHV = Addon.db.profile.HeadlineView

  NameModeOffsetX = SettingsHV.name.x
  NameModeOffsetY = GetTargetTextureY(SettingsHV)

  UpdateTexture = UPDATE_TEXTURE_FUNCTIONS[Settings.theme]
  ShowBorder = (UpdateTexture == UpdateBorderTexture)

  -- Update mouseover settings as they depend on target highlight being shown or not
  Addon.Element_Mouseover_UpdateSettings()

  SoftTargetSettings.target.Enabled = Settings.SoftTarget.Icon.SoftTargetIconTarget
  SoftTargetSettings.softenemy.Enabled = CVars:GetAsBool("SoftTargetIconEnemy")
  SoftTargetSettings.softfriend.Enabled = CVars:GetAsBool("SoftTargetIconFriend")
  SoftTargetSettings.softinteract.Enabled = CVars:GetAsBool("SoftTargetIconInteract")
  SoftTargetSettings.GameObject.Enabled = CVars:GetAsBool("SoftTargetIconGameObject")

  SoftTargetSettings.target.Highlight = Settings.ON
  SoftTargetSettings.softenemy.Highlight = Settings.SoftTarget.HighlightForEnemy
  SoftTargetSettings.softfriend.Highlight = Settings.SoftTarget.HighlightForFriend
  SoftTargetSettings.softinteract.Highlight = Settings.SoftTarget.HighlightForInteract

  SoftTargetSettings.target.Color = Settings
  SoftTargetSettings.softenemy.Color = Settings.SoftTarget.HighlightColorForEnemy
  SoftTargetSettings.softfriend.Color = Settings.SoftTarget.HighlightColorForFriend
  SoftTargetSettings.softinteract.Color = Settings.SoftTarget.HighlightColorForInteract

  -- Update the widget if it was already created (not true for immediately after Reload UI or if it was never enabled
  -- in this since last Reload UI)
  for target_unitid, widget_frame in pairs(TargetHighlightFrames) do
    UpdateTargetHighlightFrame(widget_frame)
    if widget_frame:GetParent() then
      PlayerTargetChanged(target_unitid)
    end
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
    HideWidgetFrame(FocusWidgetFrame)
  end
end

function FocusWidget:Create()
  if not FocusWidgetFrame then
    local widget_frame = _G.CreateFrame("Frame", nil)
    widget_frame:Hide()

    FocusWidgetFrame = widget_frame
    
    widget_frame.TargetUnitID = "focus"
    
    -- Focus highlight textures should be shown behind target highlight textures
    local healthbar_mode_frame = _G.CreateFrame("Frame", nil, widget_frame, BackdropTemplate)
    healthbar_mode_frame:SetFrameLevel(widget_frame:GetFrameLevel())
    healthbar_mode_frame.LeftTexture = widget_frame:CreateTexture(nil, "ARTWORK", nil, 6)
    healthbar_mode_frame.RightTexture = widget_frame:CreateTexture(nil, "ARTWORK", nil, -1)
    widget_frame.HealthbarMode = healthbar_mode_frame

    widget_frame.NameModeTexture = widget_frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    widget_frame.NameModeTexture:SetTexture(ThreatPlates.Art .. "Target")

    self:UpdateLayout()
  end

  self:PLAYER_FOCUS_CHANGED()
end

function FocusWidget:IsEnabled()
  local db = Addon.db.profile
  return db.FocusWidget.ON or db.HeadlineView.ShowFocusHighlight
end

function FocusWidget:OnEnable()
  self:RegisterEvent("PLAYER_FOCUS_CHANGED")
end

function FocusWidget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return FocusSettingsHV.ShowFocusHighlight
  elseif style ~= "etotem" then
    return FocusSettings.ON
  end

  return false
end

function FocusWidget:OnFocusUnitAdded(tp_frame, unit)
  local widget_frame = FocusWidgetFrame

  if self:EnabledForStyle(unit.style, unit) then
    local healthbar = tp_frame.visual.healthbar
    widget_frame:SetParent(tp_frame)
    widget_frame:SetFrameLevel(healthbar:GetFrameLevel() + FRAME_LEVEL_BY_TEXTURE[FocusSettings.theme])
    --widget_frame.HealthbarMode:SetFrameLevel(widget_frame:GetFrameLevel())
    widget_frame:ClearAllPoints()
    widget_frame:SetAllPoints(healthbar)

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
        healthbar_mode_frame.RightTexture:SetShown(FocusUpdateTexture == UpdateSideTexture)
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
  HideWidgetFrame(FocusWidgetFrame)
end

function FocusWidget:UpdateLayout()
  local widget_frame = FocusWidgetFrame

  FocusUpdateTexture(FocusSettings, widget_frame, widget_frame.HealthbarMode)
  widget_frame.NameModeTexture:SetSize(128, 32 * GetHeadlineViewHeight(FocusSettingsHV) / 18)
  widget_frame.NameModeTexture:SetPoint("CENTER", widget_frame, "CENTER", FocusNameModeOffsetX, FocusNameModeOffsetY)
end

function FocusWidget:UpdateSettings()
  FocusSettings = Addon.db.profile.FocusWidget
  FocusSettingsHV = Addon.db.profile.HeadlineView

  FocusNameModeOffsetX = FocusSettingsHV.name.x
  FocusNameModeOffsetY = GetTargetTextureY(FocusSettingsHV)

  FocusUpdateTexture = UPDATE_TEXTURE_FUNCTIONS[FocusSettings.theme]
  FocusShowBorder = (FocusUpdateTexture == UpdateBorderTexture)

  SoftTargetSettings.focus.Color = FocusSettings

  -- Update the widget if it was already created (not true for immediately after Reload UI or if it was never enabled
  -- in this since last Reload UI)
  if FocusWidgetFrame then
    self:UpdateLayout()
    self:PLAYER_FOCUS_CHANGED()
  end
end