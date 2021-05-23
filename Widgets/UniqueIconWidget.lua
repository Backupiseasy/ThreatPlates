---------------------------------------------------------------------------------------------------
-- Unique Icon Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewWidget("UniqueIcon")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local type = type
local pairs = pairs

-- WoW APIs
local PlatesByUnit = Addon.PlatesByUnit
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local CUSTOM_GLOW_FUNCTIONS, CUSTOM_GLOW_WRAPPER_FUNCTIONS = Addon.CUSTOM_GLOW_FUNCTIONS, Addon.CUSTOM_GLOW_WRAPPER_FUNCTIONS

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, SetPortraitTexture

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local DefaultGlowColor

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------
function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = _G.CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 14)
  widget_frame.Icon = widget_frame:CreateTexture(nil, "ARTWORK")
  widget_frame.Icon:SetAllPoints(widget_frame)

  widget_frame.Highlight = _G.CreateFrame("Frame", nil, widget_frame)
  widget_frame.Highlight:SetFrameLevel(tp_frame:GetFrameLevel() + 15)

  widget_frame.HighlightStop = Addon.LibCustomGlow.PixelGlow_Stop
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  return Addon.UseUniqueWidget -- self.ON is also checked when scanning all custom nameplates
end

-- Especially when entering an instance, the portrait might not yet be loaded, when OnUnitAdded is called.
-- So, we have to listen for this event to update it when the portrait is available.
function Widget:UNIT_PORTRAIT_UPDATE(unitid)
  if unitid == "player" or unitid == "target" then return end

  local plate = GetNamePlateForUnit(unitid)
  if plate and plate.TPFrame.Active then
    local widget_frame = plate.TPFrame.widgets.UniqueIcon
    if widget_frame.Active then
      local unique_setting = plate.TPFrame.unit.CustomPlateSettings
      if unique_setting and self.db.ON and unique_setting.showIcon and unique_setting.UseAutomaticIcon then
        local icon = widget_frame.Icon
        _G.SetPortraitTexture(icon, unitid)
        icon:SetTexCoord(0.14644660941, 0.85355339059, 0.14644660941, 0.85355339059)
      end
    end
  end
end


function Widget:OnEnable()
  self:RegisterEvent("UNIT_PORTRAIT_UPDATE")
end

function Widget:OnDisable()
  self:UnregisterEvent("UNIT_PORTRAIT_UPDATE")
end


function Widget:EnabledForStyle(style, unit)
  return style ~= "empty" -- (style == "unique" or style == "NameOnly-Unique" or style == "etotem")
end

---------------------------------------------------------------------------------------------------
-- Aura Highlighting
---------------------------------------------------------------------------------------------------

function Widget:OnUnitAdded(widget_frame, unit)
  local unique_setting = unit.CustomPlateSettings
	if not unique_setting then
		widget_frame:Hide()
		return
	end

  widget_frame:Show()

	local db = self.db

  local show_icon = self.db.ON and unique_setting.showIcon
  if show_icon then
    widget_frame:ClearAllPoints()
    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
      widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x_hv, db.y_hv)
    else
      widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
    end

    -- Updates based on settings
    widget_frame:SetSize(db.scale, db.scale)

    local icon_texture = unique_setting.icon
    local icon = widget_frame.Icon
    if unique_setting.UseAutomaticIcon then
      if unique_setting.Trigger.Type == "Name" then
        _G.SetPortraitTexture(icon, unit.unitid)
        icon:SetTexCoord(0.14644660941, 0.85355339059, 0.14644660941, 0.85355339059)
        --icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
      else
        icon:SetTexture(unique_setting.AutomaticIcon or icon_texture)
        icon:SetTexCoord(0, 1, 0, 1)
      end
    elseif type(icon_texture) == "string" and icon_texture:sub(-4) == ".blp" then
      icon:SetTexture("Interface\\Icons\\" .. unique_setting.icon)
      icon:SetTexCoord(0, 1, 0, 1)
    else
      icon:SetTexture(icon_texture)
      icon:SetTexCoord(0, 1, 0, 1)
    end

    icon:Show()
  else
    widget_frame.Icon:Hide()
  end

  local glow_highlight = unique_setting.Effects.Glow
  local glow_frame = glow_highlight.Frame

  if glow_frame == "None" then
    widget_frame.Highlight:Hide()
    return
  end

  local anchor_frame
  local style = widget_frame:GetParent().style
  local visual = widget_frame:GetParent().visual
  local frame_level_offset = 0
  if glow_frame == "Healthbar" and style.healthbar.show then
    anchor_frame = visual.healthbar.Border
    -- For healthbar, the Border glow should be shown above the healthbar (border is -1 framelevel)
    frame_level_offset = (glow_highlight.Type == "Button" and 1) or 0
  elseif glow_frame == "Castbar" and style.castbar.show then
    anchor_frame = visual.castbar.Border
  elseif glow_frame == "Icon" and show_icon then
    anchor_frame = widget_frame
  end

  if anchor_frame then
    widget_frame.Highlight:ClearAllPoints()
    widget_frame.Highlight:SetAllPoints(anchor_frame)
    widget_frame.Highlight:SetFrameLevel((anchor_frame:GetFrameLevel()))

    -- Stop the previously shown glow effect
    widget_frame.HighlightStop(widget_frame.Highlight)

    local color = (glow_highlight.CustomColor and glow_highlight.Color) or DefaultGlowColor
    local highlight_start = CUSTOM_GLOW_WRAPPER_FUNCTIONS[CUSTOM_GLOW_FUNCTIONS[glow_highlight.Type][1]]
    highlight_start(widget_frame.Highlight, color, frame_level_offset)

    widget_frame.HighlightStop = Addon.LibCustomGlow[CUSTOM_GLOW_FUNCTIONS[glow_highlight.Type][2]]

    widget_frame.Highlight:Show()
  else
    widget_frame.HighlightStop(widget_frame.Highlight)
    widget_frame.Highlight:Hide()
  end
end

function Addon.UpdateCustomStyleIcon(tp_frame, unit)
  local widget_frame = tp_frame.widgets.UniqueIcon
  if widget_frame and widget_frame.Active then
    Widget:OnUnitAdded(widget_frame, unit)
  end
end

function Widget:UpdateLayout(widget_frame)
  -- As there can be several custom styles with different glow effects be active on a unit, we have to stop all here
  Addon.LibCustomGlow["ButtonGlow_Stop"](widget_frame.Highlight)
  Addon.LibCustomGlow["PixelGlow_Stop"](widget_frame.Highlight)
  Addon.LibCustomGlow["AutoCastGlow_Stop"](widget_frame.Highlight)

  -- Update the style as custom nameplates might have been changed and some units no longer
  -- may be unique
  if widget_frame:GetParent().Active and widget_frame.Active then
    Addon:SetStyle(widget_frame.unit)
  end
end

-- Load settings from the configuration which are shared across all aura widgets
-- used (for each widget) in UpdateWidgetConfig
function Widget:UpdateSettings()
  self.db = Addon.db.profile.uniqueWidget

  DefaultGlowColor = ThreatPlates.DEFAULT_SETTINGS.profile.uniqueSettings["**"].Effects.Glow.Color
end