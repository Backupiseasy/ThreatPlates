---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Combo Points Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewTargetWidget("ComboPoints")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local unpack, type = unpack, type
local floor = floor
local sort = sort

-- WoW APIs
local CreateFrame, GetTime = CreateFrame, GetTime
local UnitClass, UnitCanAttack = UnitClass, UnitCanAttack
local UnitPower, UnitPowerMax, GetRuneCooldown = UnitPower, UnitPowerMax, GetRuneCooldown
local GetSpecialization, GetShapeshiftFormID = GetSpecialization, GetShapeshiftFormID
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local InCombatLockdown, IsInInstance = InCombatLockdown, IsInInstance

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local RGB = Addon.ThreatPlates.RGB
local Font = Addon.Font

local UPDATE_INTERVAL = Addon.ON_UPDATE_INTERVAL

local WATCH_POWER_TYPES = {
  RUNIC_POWER = true,
  COMBO_POINTS = true,
  CHI = true,
  HOLY_POWER = true,
  SOUL_SHARDS = true,
  ARCANE_CHARGES = true
}

local UNIT_POWER = {
  DEATHKNIGHT= {
    PowerType = Enum.PowerType.Runes,
    Name = "RUNIC_POWER",
  },
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
--    DEATHKNIGHT = {
--      Texture = { Texture = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-SingleRune.blp" },
--      TextureOff = "Interface\PlayerFrame\ClassOverlayDeathKnightRunes",
--      IconWidth = 16,
--      IconHeight = 16,
--      TexCoord = { 0, 1, 0, 1 }
--    },
    DEATHKNIGHT = {
      Texture = {
        [1] = { Atlas = "DK-Blood-Rune-Ready" },
        [2] = { Atlas = "DK-Frost-Rune-Ready" },
        [3] = { Atlas = "DK-Unholy-Rune-Ready" },
      },
      TextureOff = {
        [1] = { Atlas = "DK-Blood-Rune-Ready", Desaturation = 1, Alpha = 0.9 },
        [2] = { Atlas = "DK-Frost-Rune-Ready", Desaturation = 1, Alpha = 0.9 },
        [3] = { Atlas = "DK-Unholy-Rune-Ready", Desaturation = 1, Alpha = 0.9 },
      },
      IconWidth = 16,
      IconHeight = 16,
      TexCoord = { 0, 1, 0, 1 }
    },
    DRUID = {
      Texture = "ClassOverlay-ComboPoint",
      TextureOff = "ClassOverlay-ComboPoint-Off",
      IconWidth = 13,
      IconHeight = 13,
      TexCoord = { 0, 1, 0, 1 }
    },
    MAGE = {
      Texture = "Mage-ArcaneCharge",
      TextureOff = {
        [1] = { Atlas = "Mage-ArcaneCharge", Alpha = 0.3 },
      },
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

local DEATHKNIGHT_COLORS = {
  [1] = RGB(196, 30, 58),
  [2] = RGB(0, 102, 178),
  [3] = RGB(76, 204, 25),
}

Widget.TextureCoordinates = {}
Widget.Colors = {}
Widget.ShowInShapeshiftForm = true

local ActiveSpec
local RuneCooldowns = { 0, 0, 0, 0, 0, 0 }

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local DeathKnightSpecColor, ShowRuneCooldown

---------------------------------------------------------------------------------------------------
-- Combo Points Widget Functions
---------------------------------------------------------------------------------------------------

function Widget:DetermineUnitPower()
  local _, player_class = UnitClass("player")
  --local player_spec_no = GetSpecialization()

  local power_type = UNIT_POWER[player_class] --and (UNIT_POWER[player_class][player_spec_no] or UNIT_POWER[player_class])

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

local function OnUpdateWidget(widget_frame, elapsed)
  -- Update the number of seconds since the last update
  widget_frame.TimeSinceLastUpdate = widget_frame.TimeSinceLastUpdate + elapsed

  if widget_frame.TimeSinceLastUpdate >= UPDATE_INTERVAL then
    widget_frame.TimeSinceLastUpdate = 0

    local current_time = floor(GetTime())
    local cp_texture_off
    for rune_id = 1, 6 do
      cp_texture_off = widget_frame.ComboPointsOff[rune_id]

      if cp_texture_off:IsShown() then
        local cooldown = cp_texture_off.Time.Expiration - current_time
        cp_texture_off.Time:SetText(cooldown)
        if cooldown <= 3 then
          cp_texture_off.Time:SetTextColor(1, 1, 0)
        end
      end
    end
  end
end

function Widget:UpdateRunicPower(widget_frame)
  local ready_runes_no = 0

  local start, duration, rune_ready
  for rune_id = 1, 6 do
    start, duration, rune_ready = GetRuneCooldown(rune_id)
    if rune_ready then
      ready_runes_no = ready_runes_no + 1
    else
      RuneCooldowns[rune_id] = floor(start + duration)
    end
  end

  --sort(RuneCooldowns, function(a, b) return a < b  end)
  sort(RuneCooldowns)

  local current_time = floor(GetTime())

  local color, cp_texture, cp_texture_off, rune_cd, cp_color, expiration
  for rune_id = 1, 6 do
    color = self.Colors[ready_runes_no]
    cp_texture = widget_frame.ComboPoints[rune_id]
    cp_texture_off = widget_frame.ComboPointsOff[rune_id]

    if rune_id <= ready_runes_no then
      cp_color = color[rune_id]
      cp_texture:SetVertexColor(cp_color.r, cp_color.g, cp_color.b)
      cp_texture:Show()
      cp_texture_off:Hide()

      if ShowRuneCooldown then
        cp_texture_off.Time:Hide()
      end
    elseif self.db.ShowOffCPs then
      cp_texture:Hide()
      cp_texture_off:Show()

      if ShowRuneCooldown then
        rune_cd = cp_texture_off.Time

        expiration = RuneCooldowns[rune_id]
        rune_cd.Expiration = expiration

        rune_cd:SetText(expiration - current_time)
        rune_cd:SetTextColor(DeathKnightSpecColor.r, DeathKnightSpecColor.g, DeathKnightSpecColor.b)

        rune_cd:Show()
      end
    elseif cp_texture:IsShown() or cp_texture_off:IsShown() then
      cp_texture:Hide()
      cp_texture_off:Hide()

      if ShowRuneCooldown then
        cp_texture_off.Time:Hide()
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
      widget:UpdateUnitPower(widget_frame)
    end
  end
end

-- Arguments of ACTIVE_TALENT_GROUP_CHANGED (curr, prev) always seemt to be 1, 1
--function Widget:ACTIVE_TALENT_GROUP_CHANGED(...)
--  -- ACTIVE_TALENT_GROUP_CHANGED fires twice, so prevent that InitializeWidget is called twice (does not hurt,
--  -- but is not necesary either
--  local current_spec = GetSpecialization()
--  if ActiveSpec ~= current_spec then
--    -- Player switched to a spec that has combo points
--    self.WidgetHandler:InitializeWidget("ComboPoints")
--    ActiveSpec = current_spec
--  end
--end

function Widget:UNIT_MAXPOWER(unitid, power_type)
  if self.PowerType then
    -- Number of max power units changed (e.g., for a rogue)
    self:DetermineUnitPower()
    self:UpdateLayout()

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

function Widget:PLAYER_ENTERING_WORLD()
  -- From KuiNameplates: Update icons after zoning to workaround UnitPowerMax returning 0 when
  -- zoning into/out of instanced PVP, also in timewalking dungeons
  self:DetermineUnitPower()
  self:UpdateLayout()
end

-- As this event is only registered for druid characters, ShowInShapeshiftForm is true by initialization for all other classes
function Widget:UPDATE_SHAPESHIFT_FORM()
  self.ShowInShapeshiftForm = (GetShapeshiftFormID() == 1)

  if self.ShowInShapeshiftForm then
    self:PLAYER_TARGET_CHANGED()
  else
    self.WidgetFrame:Hide()
    self.WidgetFrame:SetParent(nil)
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:IsEnabled()
  local enabled = self.db.ON or self.db.ShowInHeadlineView

  if enabled then
    -- Register ACTIVE_TALENT_GROUP_CHANGED here otherwise it won't be registerd when an spec is active that does not have combo points.
    -- If you then switch to a spec with talent points, the widget won't be enabled.
    -- self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
  end

  self:DetermineUnitPower()

  return self.PowerType and enabled
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
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
  self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player", EventHandler)
  self:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player", EventHandler)
  self:RegisterUnitEvent("UNIT_MAXPOWER", "player")

  local _, player_class = UnitClass("player")
  if player_class == "DRUID" then
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    self.ShowInShapeshiftForm = (GetShapeshiftFormID() == 1)
--  elseif player_class == "DEATHKNIGHT" then
--    self:RegisterEvent("RUNE_POWER_UPDATE", EventHandler)
  end

  -- self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player", EventHandler)
  -- self:RegisterUnitEvent("UNIT_FLAGS", "player", EventHandler)
end

function Widget:OnDisable()
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  self:UnregisterEvent("PLAYER_TARGET_CHANGED")
  self:UnregisterEvent("UNIT_POWER_UPDATE")
  self:UnregisterEvent("UNIT_DISPLAYPOWER")
  self:UnregisterEvent("UNIT_MAXPOWER")
--  self:UnregisterEvent("RUNE_POWER_UPDATE")

  self.WidgetFrame:Hide()
  self.WidgetFrame:SetParent(nil)
end

function Widget:EnabledForStyle(style, unit)
  -- Unit can get attackable at some point in time (e.g., after a roleplay sequence
  -- if not UnitCanAttack("player", "target") then return false end

  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return self.db.ShowInHeadlineView and self.ShowInShapeshiftForm -- a little bit of a hack, logically would be better checked in OnTargetUnitAdded
  elseif style ~= "etotem" then
    return self.db.ON and self.ShowInShapeshiftForm
  end
end

function Widget:Create()
  if not self.WidgetFrame then
    local widget_frame = CreateFrame("Frame", nil)
    widget_frame:Hide()

    self.WidgetFrame = widget_frame
    widget_frame.ComboPoints = {}
    widget_frame.ComboPointsOff = {}

--    local frameBackground = false -- debug frame size
--    if frameBackground then
--      widget_frame.Background = widget_frame:CreateTexture(nil, "BACKGROUND")
--      widget_frame.Background:SetAllPoints()
--      widget_frame.Background:SetColorTexture(1, 1, 1, 0.5)
--    end

    self:UpdateLayout()
  end

  self:PLAYER_TARGET_CHANGED()
end

function Widget:OnTargetUnitAdded(tp_frame, unit)
  local widget_frame = self.WidgetFrame

  if UnitCanAttack("player", "target") and self:EnabledForStyle(unit.style, unit) then
    widget_frame:SetParent(tp_frame)
    widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)

    widget_frame:ClearAllPoints()
    -- Updates based on settings / unit style
    local db = self.db
    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
      widget_frame:SetPoint("CENTER", tp_frame, "CENTER", db.x_hv, db.y_hv)
    else
      widget_frame:SetPoint("CENTER", tp_frame, "CENTER", db.x, db.y)
    end

    self:UpdateUnitPower(widget_frame)

    widget_frame:Show()
  else
    widget_frame:Hide()
    widget_frame:SetParent(nil)
  end
end

function Widget:OnTargetUnitRemoved()
  self.WidgetFrame:Hide()
end

function Widget:UpdateTexture(texture, texture_path, cp_no)
  if self.db.Style == "Blizzard" then
    if type(texture_path) == "table" then
      --local texture_data = texture_path[GetSpecialization()]
      local texture_data = texture_path[1]
      texture:SetAtlas(texture_data.Atlas)
      texture:SetAlpha(texture_data.Alpha or 1)
      texture:SetDesaturated(texture_data.Desaturation) -- nil means no desaturation
    else
      texture:SetAtlas(texture_path)
    end
  else
    texture:SetTexture(texture_path)
  end

  texture:SetTexCoord(unpack(self.TexCoord)) -- obj:SetTexCoord(left,right,top,bottom)
  local scale = self.db.Scale
  local scaledIconWidth, scaledIconHeight, scaledSpacing = (scale * self.IconWidth),(scale * self.IconHeight),(scale * self.db.HorizontalSpacing)
  texture:SetSize(scaledIconWidth, scaledIconHeight)
  texture:SetPoint("LEFT", self.WidgetFrame, "LEFT", (self.WidgetFrame:GetWidth()/self.UnitPowerMax)*(cp_no-1)+(scaledSpacing/2), 0)  
end

function Widget:UpdateLayout()
  local widget_frame = self.WidgetFrame

  -- Updates based on settings
  local db = self.db
  local scale = db.Scale
  local scaledIconWidth, scaledIconHeight, scaledSpacing = (scale * self.IconWidth),(scale * self.IconHeight),(scale * db.HorizontalSpacing)

  -- This was moved into the UpdateLayout from UpdateComboPointLaout as this was not updating after a ReloadUI
  -- Combo Point position is now based off of WidgetFrame width
  widget_frame:SetAlpha(db.Transparency)
  widget_frame:SetHeight(scaledIconHeight)
  widget_frame:SetWidth((scaledIconWidth * self.UnitPowerMax) + ((self.UnitPowerMax - 1) * scaledSpacing))

  local _, player_class = UnitClass("player")
  local show_rune_cooldown = player_class == "DEATHKNIGHT" and ShowRuneCooldown

  for i = 1, self.UnitPowerMax do
    widget_frame.ComboPoints[i] = widget_frame.ComboPoints[i] or widget_frame:CreateTexture(nil, "BACKGROUND")
    self:UpdateTexture(widget_frame.ComboPoints[i], self.Texture, i)

    widget_frame.ComboPointsOff[i] = widget_frame.ComboPointsOff[i] or widget_frame:CreateTexture(nil, "ARTWORK")
    self:UpdateTexture(widget_frame.ComboPointsOff[i], self.TextureOff, i)

    if show_rune_cooldown then
      local time_text = widget_frame.ComboPointsOff[i].Time or widget_frame:CreateFontString(nil, "ARTWORK", 0)
      widget_frame.ComboPointsOff[i].Time = time_text

      Font:UpdateText(widget_frame.ComboPointsOff[i], time_text, db.RuneCooldown)
    elseif widget_frame.ComboPointsOff[i].Time then
      widget_frame.ComboPointsOff[i].Time:Hide()
    end
  end

  if show_rune_cooldown then
    widget_frame.TimeSinceLastUpdate = 0
    widget_frame:SetScript("OnUpdate", OnUpdateWidget)
  else
    widget_frame:SetScript("OnUpdate", nil)
  end
end

function Widget:UpdateSettings()
  self.db = TidyPlatesThreat.db.profile.ComboPoints

  self:DetermineUnitPower()

  -- Optimization, not really necessary
  if not self.PowerType then return end

  -- Update widget variables, only dependent from settings and static information (like player's class)
  local _, player_class = UnitClass("player")
  local texture_info = TEXTURE_INFO[self.db.Style][player_class] or TEXTURE_INFO[self.db.Style]

  self.UpdateUnitPower = self.UpdateComboPoints
  --  if player_class == "DEATHKNIGHT" then
  --    self.UpdateUnitPower = self.UpdateRunicPower
  --    DeathKnightSpecColor = DEATHKNIGHT_COLORS[GetSpecialization()]
  --    ShowRuneCooldown = self.db.RuneCooldown.Show
  --  else
  --    self.UpdateUnitPower = self.UpdateComboPoints
  --  end

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

  -- Update the widget if it was already created (not true for immediately after Reload UI or if it was never enabled
  -- in this since last Reload UI)
  if self.WidgetFrame then
    self:UpdateLayout()
    self:PLAYER_TARGET_CHANGED()
  end
end