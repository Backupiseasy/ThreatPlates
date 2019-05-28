---------------------------------------------------------------------------------------------------
-- Resource Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewTargetWidget("Resource")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local format = format
local ceil = ceil

-- WoW APIs
local CreateFrame = CreateFrame
local UnitReaction,UnitIsUnit = UnitReaction, UnitIsUnit
local UnitPower, UnitPowerMax, UnitPowerType = UnitPower, UnitPowerMax, UnitPowerType
local PowerBarColor = PowerBarColor
local SPELL_POWER_MANA = SPELL_POWER_MANA
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

---------------------------------------------------------------------------------------------------
-- Resource Widget Functions
---------------------------------------------------------------------------------------------------

function Widget:ShortNumber(no)
  if no <= 9999 then
    return no
  elseif no >= 1000000000 then
    return format("%.0fb", no /1000000000)
  elseif no >= 1000000 then
    return format("%.0fm", no /1000000)
  elseif no >= 10000 then
    return format("%.0fk", no /1000)
  end
end

function Widget:PowerMana()
  local SPELL_POWER = SPELL_POWER_MANA
  local res_value = UnitPower("target", SPELL_POWER)
  local res_max = UnitPowerMax("target", SPELL_POWER)
  local res_perc = ceil(100 * (res_value / res_max))

  local bar_value = res_perc
  local text_value = self:ShortNumber(res_value)

  return bar_value, text_value
end

function Widget:PowerGeneric()
  local res_value = UnitPower("target")
  local res_max = UnitPowerMax("target")
  local res_perc = ceil(100 * (res_value / res_max))

  return res_perc, res_value
end

--INDEX_VARIABLE              INDEX   TOKEN
--======================================================
--SPELL_POWER_MANA            0       "MANA"
--SPELL_POWER_RAGE            1       "RAGE"
--SPELL_POWER_FOCUS           2       "FOCUS"
--SPELL_POWER_ENERGY          3       "ENERGY"
--SPELL_POWER_COMBO_POINTS    4       "COMBO_POINTS"
--SPELL_POWER_RUNES           5       "RUNES"
--SPELL_POWER_RUNIC_POWER     6       "RUNIC_POWER"
--SPELL_POWER_SOUL_SHARDS     7       "SOUL_SHARDS"
--SPELL_POWER_LUNAR_POWER     8       "LUNAR_POWER"
--SPELL_POWER_HOLY_POWER      9       "HOLY_POWER"
--SPELL_POWER_ALTERNATE_POWER 10      ???
--SPELL_POWER_MAELSTROM       11      "MAELSTROM"
--SPELL_POWER_CHI             12      "CHI"
--SPELL_POWER_INSANITY        13      "INSANITY"
--SPELL_POWER_OBSOLETE        14      ???
--SPELL_POWER_OBSOLETE2       15      ???
--SPELL_POWER_ARCANE_CHARGES  16      "ARCANE_CHARGES"
--SPELL_POWER_FURY            17      "FURY"
--SPELL_POWER_PAIN            18      "PAIN"

Widget.POWER_FUNCTIONS = {
  MANA = Widget.PowerMana,
  RAGE = Widget.PowerGeneric,
  FOCUS = Widget.PowerGeneric,
  ENERGY = Widget.PowerGeneric,
  COMBO_POINTS = Widget.PowerGeneric,
  RUNES = Widget.PowerGeneric,
  RUNIC_POWER = Widget.PowerGeneric,
  SOUL_SHARDS = Widget.PowerGeneric,
  LUNAR_POWER = Widget.PowerGeneric,
  HOLY_POWER = Widget.PowerGeneric,
  --ALTERNATE_POWER = PowerGeneric,
  MAELSTROM = Widget.PowerGeneric,
  CHI = Widget.PowerGeneric,
  INSANITY = Widget.PowerGeneric,
  ARCANE_CHARGES = Widget.PowerGeneric,
  FURY = Widget.PowerGeneric,
  PAIN = Widget.PowerGeneric,
}

function Widget:SetTargetPowerType(widget_frame)
  -- The code to determine the power type could be moved to OnUnitAdded, but then code is necessary to determine when
  -- the power type on the unit changes (e.g., a druid that shapeshifts). Mabe there's even bosses that do that?!?
  local powerType, powerToken, altR, altG, altB = UnitPowerType("target")

  local db = self.db
  local power_func = self.POWER_FUNCTIONS[powerToken]

  if UnitPowerMax("target") == 0 or (db.ShowOnlyAltPower and power_func) then
    self.PowerFunction = nil
    return
  elseif not power_func then
    if altR then
      power_func = Widget.PowerGeneric
    else
      self.PowerFunction = nil
      return
    end
  end

  -- determine color for power
  local info = PowerBarColor[powerToken]
  if info then
    --The PowerBarColor takes priority
    self.BarColorRed, self.BarColorGreen, self.BarColorBlue = info.r, info.g, info.b;
  elseif not altR then
    -- Couldn't find a power token entry. Default to indexing by power type or just mana if  we don't have that either.
    info = PowerBarColor[powerType] or PowerBarColor["MANA"];
    self.BarColorRed, self.BarColorGreen, self.BarColorBlue = info.r, info.g, info.b
  else
    self.BarColorRed, self.BarColorGreen, self.BarColorBlue = altR, altG, altB
  end

  self.PowerFunction = power_func
end

function Widget:UpdateResourceBar()
  local widget_frame = self.WidgetFrame

  local bar_value, text_value = self:PowerFunction()

  local db = self.db
  if db.ShowBar then
    widget_frame.Bar:SetValue(bar_value)
  end

  if db.ShowText then
    widget_frame.Text:SetText(text_value)
  end
end

-- This event handler only watches for events of unit == "target"
function Widget:UNIT_POWER_UPDATE(unitid, powerType)
  local plate = GetNamePlateForUnit("target")

  local tp_frame = plate and plate.TPFrame
  if tp_frame and tp_frame.Active then
    if self.ShowWidget then
      self:UpdateResourceBar()
    end
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

function Widget:Create()
  if not self.WidgetFrame then
    local widget_frame = CreateFrame("Frame", nil)
    widget_frame:Hide()

    self.WidgetFrame = widget_frame

    widget_frame.Text = widget_frame:CreateFontString(nil, "OVERLAY")

    local bar = CreateFrame("StatusBar", nil, widget_frame)
    bar:SetFrameLevel(widget_frame:GetFrameLevel())
    bar:SetMinMaxValues(0, 100)
    widget_frame.Bar = bar

    widget_frame.Background = bar:CreateTexture(nil, "BACKGROUND")

    widget_frame.Border = CreateFrame("Frame", nil, widget_frame.Bar)
    widget_frame.Border:SetFrameLevel(widget_frame:GetFrameLevel())

    self:UpdateLayout()
  end

  self:PLAYER_TARGET_CHANGED()
end

function Widget:IsEnabled()
  return TidyPlatesThreat.db.profile.ResourceWidget.ON
end

-- EVENT: UNIT_POWER_UPDATE: "unitID", "powerType"
function Widget:OnEnable()
  self:RegisterUnitEvent("UNIT_POWER_UPDATE", "target")
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
  -- Widget:RegisterEvent("UNIT_DISPLAYPOWER") -- use this to determine power type changes on units
end

function Widget:EnabledForStyle(style, unit)
  return not (style == "NameOnly" or style == "NameOnly-Unique" or style == "etotem")
end

function Widget:OnTargetUnitAdded(tp_frame, unit)
  local db = self.db
  local widget_frame = self.WidgetFrame

  if not self:EnabledForStyle(unit.style, unit) then
    widget_frame:Hide()
    widget_frame:SetParent(nil)
    return
  end

  self.ShowWidget = false

--  local show = (UnitReaction(unit.unitid, "player") > 4 and db.ShowFriendly) or
--               (unit.type == "PLAYER" and db.ShowEnemyPlayer) or
--               ((unit.isBoss or unit.isRare) and db.ShowEnemyBoss) or
--               db.ShowEnemyNPC

  local show
  if unit.type == "PLAYER" then
    show = (UnitReaction(unit.unitid, "player") > 4 and db.ShowFriendly) or db.ShowEnemyPlayer
  else
    show = ((unit.isBoss or unit.isRare) and db.ShowEnemyBoss) or db.ShowEnemyNPC
  end

  if not show then
    widget_frame:Hide()
    widget_frame:SetParent(nil)
    return
  end

  self:SetTargetPowerType()
  if not self.PowerFunction then
    widget_frame:Hide()
    widget_frame:SetParent(nil)
    return
  end

  self.ShowWidget = true

  widget_frame:SetParent(tp_frame)
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 8)
  widget_frame:ClearAllPoints()
  widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)

  if db.ShowBar then
    widget_frame.Bar:SetStatusBarColor(self.BarColorRed, self.BarColorGreen, self.BarColorBlue, 1)

    if db.BackgroundUseForegroundColor then
      widget_frame.Background:SetVertexColor(self.BarColorRed, self.BarColorGreen, self.BarColorBlue, 0.3)
    else
      local color = db.BackgroundColor
      widget_frame.Background:SetVertexColor(color.r, color.g, color.b, color.a)
    end

    if db.BorderUseForegroundColor then
      widget_frame.Border:SetBackdropBorderColor(self.BarColorRed, self.BarColorGreen, self.BarColorBlue, 1)
    elseif db.BorderUseBackgroundColor then
      local color = db.BackgroundColor
      widget_frame.Border:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
    else
      local color = db.BorderColor
      widget_frame.Border:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
    end
  end

  self:UpdateResourceBar()

  widget_frame:Show()
end

function Widget:OnTargetUnitRemoved()
  self.WidgetFrame:Hide()
end

function Widget:UpdateLayout()
  local widget_frame = self.WidgetFrame

  -- Updates based on settings
  local db = self.db

  widget_frame:SetSize(db.BarWidth, db.BarHeight)

  local bar = widget_frame.Bar
  if db.ShowBar then
    local bar_texture = ThreatPlates.Media:Fetch('statusbar', db.BarTexture)

    bar:SetAllPoints()
    bar:SetStatusBarTexture(bar_texture)

    local background = widget_frame.Background
    background:SetTexture(bar_texture)
    background:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPRIGHT")
    background:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")

    local border = widget_frame.Border
    border:SetBackdrop({
      --bgFile = bar_texture,
      edgeFile = ThreatPlates.Media:Fetch('border', db.BorderTexture),
      edgeSize = db.BorderEdgeSize,
      insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    border:SetPoint("TOPLEFT", widget_frame, "TOPLEFT", - db.BorderOffset, db.BorderOffset)
    border:SetPoint("BOTTOMRIGHT", widget_frame, "BOTTOMRIGHT", db.BorderOffset, - db.BorderOffset)
  end

  bar:SetShown(db.ShowBar)

  local text = widget_frame.Text
  if db.ShowText then
    text:SetAllPoints()

    text:SetFont(ThreatPlates.Media:Fetch('font', db.Font), db.FontSize)
    text:SetJustifyH("CENTER")
    text:SetShadowOffset(1, -1)
    text:SetMaxLines(1)

    local font_color = db.FontColor
    text:SetTextColor(font_color.r, font_color.g, font_color.b)
  end

  text:SetShown(db.ShowText)
end

function Widget:UpdateSettings()
  self.db = TidyPlatesThreat.db.profile.ResourceWidget

  -- Update the widget if it was already created (not true for immediately after Reload UI or if it was never enabled
  -- in this since last Reload UI)
  if self.WidgetFrame then
    self:UpdateLayout()
    self:PLAYER_TARGET_CHANGED()
  end
end
