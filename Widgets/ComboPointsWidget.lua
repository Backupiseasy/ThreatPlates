  ---------------------------------------------------------------------------------------------------
-- Combo Points Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = Addon:NewWidget("ComboPoints")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs, unpack, type = pairs, unpack, type

-- WoW APIs
local CreateFrame = CreateFrame
local UnitClass, UnitCanAttack, UnitIsUnit = UnitClass, UnitCanAttack, UnitIsUnit
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
    local widget_frame = plate.TPFrame.widgets.ComboPoints
    if widget_frame:IsShown() then
      Widget:UpdateComboPoints(widget_frame)
    end
  end
end

function Widget:ACTIVE_TALENT_GROUP_CHANGED(...)
  -- Player switched to a spec that has combo points
  self:UpdateSettings()
  Addon:InitializeWidget("ComboPoints")
end

function Widget:UNIT_MAXPOWER(unitid, power_type)
  if self.PowerType then
    -- Number of max power units changed (e.g., for a rogue)
    self:DetermineUnitPower()
    self:UpdateComboPointsLayout()

    -- Update all widgets created until now
    for plate, tp_frame in pairs(Addon.PlatesCreated) do
      local widget_frame = tp_frame.widgets.ComboPoints
      if tp_frame.Active then
        self:OnUnitAdded(widget_frame, widget_frame.unit)

        -- remove excessive CP frames (when called after talent change)
        for i = self.UnitPowerMax + 1, #widget_frame.ComboPoints do
          widget_frame.ComboPoints[i]:Hide()
          widget_frame.ComboPoints[i] = nil
          widget_frame.ComboPointsOff[i]:Hide()
          widget_frame.ComboPointsOff[i] = nil
        end
      end
    end

    --self:PLAYER_TARGET_CHANGED()
  end
end

function Widget:PLAYER_TARGET_CHANGED()
  if self.CurrentTarget then
    self.CurrentTarget:Hide()
    self.CurrentTarget = nil
  end

  local plate = GetNamePlateForUnit("target")
  if plate and plate.TPFrame.Active and UnitCanAttack("player", "target") and self.PowerType then
    self.CurrentTarget = plate.TPFrame.widgets.ComboPoints
    if self.CurrentTarget.Active then
      self:UpdateComboPoints(self.CurrentTarget)
      self.CurrentTarget:Show()
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
  widget_frame:SetSize(64, 64)
  widget_frame.ComboPoints = {}
  widget_frame.ComboPointsOff = {}
  -- End Custom Code

  -- Required Widget Code
  return widget_frame
end

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
  self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player", EventHandler)
  self:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player", EventHandler)
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
  -- self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player", EventHandler)
  --self:RegisterUnitEvent("UNIT_FLAGS", "player", EventHandler)

  self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
end

function Widget:OnDisable()
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

function Widget:UpdateTexture(widget_frame, texture, texture_path, cp_no)
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
  texture:SetPoint("CENTER", widget_frame, "CENTER", self.TextureCoordinates[cp_no], 0)
end

function Widget:OnUnitAdded(widget_frame, unit)
  if not self.PowerType then return end

  --self.db = TidyPlatesThreat.db.profile.ComboPoints
  local db = self.db

  -- Updates based on settings / unit style
  if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), "CENTER", db.x_hv, db.y_hv)
  else
    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), "CENTER", db.x, db.y)
  end

  -- Updates based on settings
  widget_frame:SetAlpha(db.Transparency)

  for i = 1, self.UnitPowerMax do
    widget_frame.ComboPoints[i] = widget_frame.ComboPoints[i] or widget_frame:CreateTexture(nil, "BACKGROUND")
    self:UpdateTexture(widget_frame, widget_frame.ComboPoints[i], self.Texture, i)

    widget_frame.ComboPointsOff[i] = widget_frame.ComboPointsOff[i] or widget_frame:CreateTexture(nil, "ARTWORK")
    self:UpdateTexture(widget_frame, widget_frame.ComboPointsOff[i], self.TextureOff, i)
  end

  if UnitIsUnit("target", unit.unitid) and UnitCanAttack("player", "target") then --and self.PowerType then
    -- Updates based on unit status
    self.CurrentTarget = widget_frame
    self:UpdateComboPoints(widget_frame)
    widget_frame:Show()
  else
    widget_frame:Hide()
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

--  -- Don't update any widget frame if the widget isn't enabled
--  if not self:IsEnabled() then return end

  -- Update all widgets created until now
  for _, tp_frame in pairs(Addon.PlatesCreated) do
    local widget_frame = tp_frame.widgets.ComboPoints

    -- widget_frame could be nil if the widget as disabled and is enabled as part of a profile switch
    -- For these frames, UpdateAuraWidgetLayout will be called anyway when the widget is initalized
    -- (which happens after the settings update)
    if widget_frame then
      if tp_frame.Active then -- equals: plate is visible, i.e., show currently
        self:OnUnitAdded(widget_frame, widget_frame.unit)
      end
    end
  end
end
