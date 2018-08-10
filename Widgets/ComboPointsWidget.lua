---------------------------------------------------------------------------------------------------
-- Combo Points Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = Addon:NewTargetWidget("ComboPoints")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs, unpack, type = pairs, unpack, type

-- WoW APIs
local CreateFrame = CreateFrame
local UnitClass, UnitCanAttack = UnitClass, UnitCanAttack
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local GetSpecialization = GetSpecialization
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local InCombatLockdown = InCombatLockdown

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local RGB = Addon.ThreatPlates.RGB

local WATCH_POWER_TYPES = {
  COMBO_POINTS = true,
  CHI = true,
  HOLY_POWER = true,
  SOUL_SHARDS = true,
  ARCANE_CHARGES = true
}

local UNIT_POWER = {
  DRUID = {
    PowerType = Enum.PowerType.ComboPoints,
    Name = "COMBO_POINTS",
  },
  MAGE = {
    [1] = {
      PowerType = Enum.PowerType.ArcaneCharges,
      Name = "ARCANE_CHARGES",
    },
  },
  MONK = {
    [3] = {
      PowerType = Enum.PowerType.Chi,
      Name = "CHI",
    }
  },
  PALADIN = {
    [3] = {
      PowerType = Enum.PowerType.HolyPower,
      Name = "HOLY_POWER",
    }
  },
  ROGUE = {
    PowerType = Enum.PowerType.ComboPoints,
    Name = "COMBO_POINTS",
  },
  WARLOCK = {
    PowerType = Enum.PowerType.SoulShards,
    Name = "SOUL_SHARDS",
  },
}

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ComboPointsWidget\\"
local TEXTURE_INFO = {
  Squares = {
    Texture = PATH .. "ComboPointDefault",
    TextureOff = PATH .. "ComboPointDefaultOff",
    TextureWidth = 128,
    TextureHeight = 64,
    IconWidth = 62 * 0.25,
    IconHeight = 34 * 0.25,
    TexCoord = { 0, 62 / 128, 0, 34 / 64 }
  },
  Orbs = {
    Texture = PATH .. "ComboPointOrb",
    TextureOff = PATH .. "ComboPointOrbOff",
    TextureWidth = 64,
    TextureHeight = 64,
    IconWidth = 60 * 0.22,
    IconHeight = 60 * 0.22,
    TexCoord = { 2/64, 62/64, 2/64, 62/64 }
  },
  Blizzard = {
    DRUID = {
      Texture = "ClassOverlay-ComboPoint",
      TextureOff = "ClassOverlay-ComboPoint-Off",
      IconWidth = 13,
      IconHeight = 13,
      TexCoord = { 0, 1, 0, 1 }
    },
    MAGE = {
      Texture = "Mage-ArcaneCharge",
      TextureOff = { "Mage-ArcaneCharge", 0.3 },
      IconWidth = 22,
      IconHeight = 22,
      TexCoord = { 0, 1, 0, 1 }
    },
    MONK = {
      Texture = "MonkUI-LightOrb",
      TextureOff = "MonkUI-OrbOff",
      IconWidth = 15,
      IconHeight = 15,
      TexCoord = { 0, 1, 0, 1 }
    },
    PALADIN = {
      Texture = "nameplates-holypower1-on",
      TextureOff = "nameplates-holypower1-off",
      IconWidth = 25,
      IconHeight = 19,
      TexCoord = { 0, 1, 0, 1 }
    },
    ROGUE = {
      Texture = "ClassOverlay-ComboPoint",
      TextureOff = "ClassOverlay-ComboPoint-Off",
      IconWidth = 13,
      IconHeight = 13,
      TexCoord = { 0, 1, 0, 1 }
    },
    WARLOCK = {
      Texture = "Warlock-ReadyShard",
      TextureOff = "Warlock-EmptyShard",
      IconWidth = 12,
      IconHeight = 16,
      TexCoord = { 0, 1, 0, 1 }
    },
  }
}

Widget.TextureCoordinates = {}
Widget.Colors = {}

---------------------------------------------------------------------------------------------------
-- Combo Points Widget Functions
---------------------------------------------------------------------------------------------------

function Widget:DetermineUnitPower()
  local _, player_class = UnitClass("player")
  local player_spec_no = GetSpecialization()

  local power_type = UNIT_POWER[player_class] and (UNIT_POWER[player_class][player_spec_no] or UNIT_POWER[player_class])

  if power_type and power_type.Name then
    self.PowerType = power_type.PowerType
    self.UnitPowerMax = UnitPowerMax("player", self.PowerType)
  else
    self.PowerType = nil
    self.UnitPowerMax = 0
  end
end

function Widget:UpdateComboPoints(widget_frame)
  local points = UnitPower("player", self.PowerType) or 0

  if points == 0 and not InCombatLockdown() then
    for i = 1, self.UnitPowerMax do
      widget_frame.ComboPoints[i]:Hide()
      widget_frame.ComboPointsOff[i]:Hide()
    end
  else
    local color = self.Colors[points]
    local cp_texture, cp_texture_off, cp_color

    for i = 1, self.UnitPowerMax do
      cp_texture = widget_frame.ComboPoints[i]
      cp_texture_off = widget_frame.ComboPointsOff[i]

      if points >= i then
        cp_color = color[i]
        cp_texture:SetVertexColor(cp_color.r, cp_color.g, cp_color.b)
        cp_texture:Show()
        cp_texture_off:Hide()
      elseif self.db.ShowOffCPs then
        cp_texture:Hide()
        cp_texture_off:Show()
      elseif cp_texture:IsShown() or cp_texture_off:IsShown() then
        cp_texture:Hide()
        cp_texture_off:Hide()
      else
        break
      end
    end
  end
end

-- This event handler only watches for events of unit == "player"
local function EventHandler(event, unitid, power_type)
  if event == "UNIT_POWER_UPDATE" and not WATCH_POWER_TYPES[power_type] then return end

  local plate = GetNamePlateForUnit("target")
  if plate then -- not necessary, prerequisite for IsShown(): plate.TPFrame.Active and
    local widget = Widget
    local widget_frame = widget.WidgetFrame
    if widget_frame:IsShown() then
      widget:UpdateComboPoints(widget_frame)
    end
  end
end

function Widget:ACTIVE_TALENT_GROUP_CHANGED(...)
  -- Player switched to a spec that has combo points
  Addon:InitializeWidget("ComboPoints")
end

function Widget:UNIT_MAXPOWER(unitid, power_type)
  if self.PowerType then
    -- Number of max power units changed (e.g., for a rogue)
    self:DetermineUnitPower()
    self:UpdateComboPointsLayout()

    -- remove excessive CP frames (when called after talent change)
    local widget_frame = self.WidgetFrame
    for i = self.UnitPowerMax + 1, #widget_frame.ComboPoints do
      widget_frame.ComboPoints[i]:Hide()
      widget_frame.ComboPoints[i] = nil
      widget_frame.ComboPointsOff[i]:Hide()
      widget_frame.ComboPointsOff[i] = nil
    end

    self:PLAYER_TARGET_CHANGED()
  end
end

function Widget:PLAYER_TARGET_CHANGED()
  local plate = GetNamePlateForUnit("target")

  local tp_frame = plate and plate.TPFrame
  if tp_frame and tp_frame.Active then
    self:OnTargetUnitAdded(tp_frame, tp_frame.unit)
  else
    self.WidgetFrame:Hide()
    self.WidgetFrame:SetParent(nil)
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:IsEnabled()
  self:DetermineUnitPower()
  self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

  return self.PowerType and (self.db.ON or self.db.ShowInHeadlineView)
end

-- EVENTS:
-- UNIT_COMBO_POINTS: -- combo points also fire UNIT_POWER
-- UNIT_POWER_UPDATE: "unitID", "powerType"  -- CHI, COMBO_POINTS
-- UNIT_DISPLAYPOWER: Fired when the unit's mana stype is changed. Occurs when a druid shapeshifts as well as in certain other cases.
--   unitID
-- UNIT_AURA: unitID
-- UNIT_FLAGS: unitID
-- UNIT_POWER_FREQUENT: unitToken, powerToken
function Widget:OnEnable()
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
  self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player", EventHandler)
  self:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player", EventHandler)
  self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
  -- self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player", EventHandler)
  --self:RegisterUnitEvent("UNIT_FLAGS", "player", EventHandler)
end

function Widget:OnDisable()
  self.WidgetFrame:Hide()
  self.WidgetFrame:SetParent(nil)

  -- Re-register this event, so that we get notified if the player changes to a spec that has a supported
  -- power type
  self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
end

function Widget:EnabledForStyle(style, unit)
  -- Unit can get attackable at some point in time (e.g., after a roleplay sequence
  -- if not UnitCanAttack("player", "target") then return false end

  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return self.db.ShowInHeadlineView
  elseif style ~= "etotem" then
    return self.db.ON
  end
end

function Widget:Create()
  if not self.WidgetFrame then
    local widget_frame = CreateFrame("Frame", nil)
    widget_frame:Hide()

    self.WidgetFrame = widget_frame

    widget_frame:SetSize(64, 64)
    widget_frame.ComboPoints = {}
    widget_frame.ComboPointsOff = {}

    self:UpdateLayout()
  end

  self:PLAYER_TARGET_CHANGED()
end

function Widget:OnTargetUnitAdded(tp_frame, unit)
  local widget_frame = self.WidgetFrame

  if UnitCanAttack("player", "target") and self:EnabledForStyle(unit.style, unit) then
    widget_frame:SetParent(tp_frame)
    widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)

    -- Updates based on settings / unit style
    local db = self.db
    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
      widget_frame:SetPoint("CENTER", tp_frame, "CENTER", db.x_hv, db.y_hv)
    else
      widget_frame:SetPoint("CENTER", tp_frame, "CENTER", db.x, db.y)
    end

    self:UpdateComboPoints(widget_frame)

    widget_frame:Show()
  else
    widget_frame:Hide()
    widget_frame:SetParent(nil)
  end
end

function Widget:OnTargetUnitRemoved()
  self.WidgetFrame:Hide()
end

--function Widget:OnModeChange(tp_frame, unit)
--  local widget_frame = self.WidgetFrame
--  if UnitCanAttack("player", "target") and self:EnabledForStyle(unit.style, unit) then
--
--    widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
--
--    -- Updates based on settings / unit style
--    local db = self.db
--    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
--      widget_frame:SetPoint("CENTER", tp_frame, "CENTER", db.x_hv, db.y_hv)
--    else
--      widget_frame:SetPoint("CENTER", tp_frame, "CENTER", db.x, db.y)
--    end
--
--    if not widget_frame:IsShown() then
--      self:UpdateComboPoints(widget_frame)
--      widget_frame:Show()
--    end
--  else
--    widget_frame:Hide()
--  end
--end

function Widget:UpdateTexture(texture, texture_path, cp_no)
  if self.db.Style == "Blizzard" then
    if type(texture_path) == "table" then
      texture:SetAtlas(texture_path[1])
      texture:SetAlpha(texture_path[2])
    else
      texture:SetAtlas(texture_path)
    end
  else
    texture:SetTexture(texture_path)
  end

  texture:SetTexCoord(unpack(self.TexCoord)) -- obj:SetTexCoord(left,right,top,bottom)
  texture:SetSize(self.IconWidth, self.IconHeight)
  texture:SetScale(self.db.Scale)
  texture:SetPoint("CENTER", self.WidgetFrame, "CENTER", self.TextureCoordinates[cp_no], 0)
end

function Widget:UpdateLayout()
  local widget_frame = self.WidgetFrame

  -- Updates based on settings
  local db = self.db
  widget_frame:SetAlpha(db.Transparency)

  for i = 1, self.UnitPowerMax do
    widget_frame.ComboPoints[i] = widget_frame.ComboPoints[i] or widget_frame:CreateTexture(nil, "BACKGROUND")
    self:UpdateTexture(widget_frame.ComboPoints[i], self.Texture, i)

    widget_frame.ComboPointsOff[i] = widget_frame.ComboPointsOff[i] or widget_frame:CreateTexture(nil, "ARTWORK")
    self:UpdateTexture(widget_frame.ComboPointsOff[i], self.TextureOff, i)
  end
end

function Widget:UpdateComboPointsLayout()
  -- Update widget variables, dependent from non-static information (talents)
  local offset_from_center = ( (self.db.Scale * self.UnitPowerMax * self.IconWidth) + ((self.UnitPowerMax - 1) * self.db.HorizontalSpacing) - (self.IconWidth * self.db.Scale)) / 2
  for i = 1, self.UnitPowerMax do
    self.TextureCoordinates[i] = (i - 1) * self.db.Scale * (self.IconWidth + self.db.HorizontalSpacing) - offset_from_center
  end
end

function Widget:UpdateSettings()
  self.db = TidyPlatesThreat.db.profile.ComboPoints

  self:DetermineUnitPower()

  -- Optimization, not really necessary
  if not self.PowerType then return end

  -- Update widget variables, only dependent from settings and static information (like player's class)
  -- TODO: check what happens if player does not yet have a spec, e.g. < level 10
  local _, player_class = UnitClass("player")
  local texture_info = TEXTURE_INFO[self.db.Style][player_class] or TEXTURE_INFO[self.db.Style]

  self.TexCoord = texture_info.TexCoord
  self.IconWidth = texture_info.IconWidth
  self.IconHeight = texture_info.IconHeight
  self.Texture = texture_info.Texture
  self.TextureOff = texture_info.TextureOff

  local colors = self.db.ColorBySpec[player_class]
  for current_cp = 1, #colors do
    for cp_no = 1, #colors do

      self.Colors[current_cp] = self.Colors[current_cp] or {}
      if self.db.Style == "Blizzard" then
        self.Colors[current_cp][cp_no] = RGB(255, 255, 255)
      elseif self.db.UseUniformColor then
        self.Colors[current_cp][cp_no] = colors[current_cp]
      else
        self.Colors[current_cp][cp_no] = colors[cp_no]
      end
    end
  end

  self:UpdateComboPointsLayout()

  -- Update the widget if it was already created (not true for immediately after Reload UI or if it was never enabled
  -- in this since last Reload UI)
  if self.WidgetFrame then
    self:UpdateLayout()
    self:PLAYER_TARGET_CHANGED()
  end
end
