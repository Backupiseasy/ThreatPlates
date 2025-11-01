---------------------------------------------------------------------------------------------------
-- Resource Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = Addon.Widgets:NewTargetWidget("Resource")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local format = format
local ceil = ceil

-- WoW APIs
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local PowerBarColor = PowerBarColor
local SPELL_POWER_MANA = SPELL_POWER_MANA
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local BackdropTemplate = Addon.BackdropTemplate

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, UnitPowerType

local WidgetFrame

---------------------------------------------------------------------------------------------------
-- Resource Widget Functions
---------------------------------------------------------------------------------------------------

local function HideWidgetFrame()
  local widget_frame = WidgetFrame
  widget_frame:Hide()
  widget_frame:SetParent(nil)
end

-- TODO: Use function from Localization (with one decimal)
local function ShortNumber(no)
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

local function PowerMana()
  local SPELL_POWER = SPELL_POWER_MANA
  local res_value = UnitPower("target", SPELL_POWER)
  local res_max = UnitPowerMax("target", SPELL_POWER)
  local res_perc = ceil(100 * (res_value / res_max))

  local bar_value = res_perc
  local text_value = ShortNumber(res_value)

  return bar_value, text_value
end

local function PowerGeneric()
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
  MANA = PowerMana,
  RAGE = PowerGeneric,
  FOCUS = PowerGeneric,
  ENERGY = PowerGeneric,
  COMBO_POINTS = PowerGeneric,
  RUNES = PowerGeneric,
  RUNIC_POWER = PowerGeneric,
  SOUL_SHARDS = PowerGeneric,
  LUNAR_POWER = PowerGeneric,
  HOLY_POWER = PowerGeneric,
  --ALTERNATE_POWER = PowerGeneric,
  MAELSTROM = PowerGeneric,
  CHI = PowerGeneric,
  INSANITY = PowerGeneric,
  ARCANE_CHARGES = PowerGeneric,
  FURY = PowerGeneric,
  PAIN = PowerGeneric,
}

function Widget:SetTargetPowerType(widget_frame, unit)
  -- Reset the power function by default; it will be reassigned if appropriate
  self.PowerFunction = nil

  if UnitPowerMax("target") == 0 then return end

  -- The code to determine the power type could be moved to OnUnitAdded, but then code is necessary to determine when
  -- the power type on the unit changes (e.g., a druid that shapeshifts). Mabe there's even bosses that do that?!?
  local powerType, powerToken, altR, altG, altB = _G.UnitPowerType("target")
  -- Fallback to generic function if at least alternate color exists
  local power_func = self.POWER_FUNCTIONS[powerToken] or PowerGeneric
  
  -- Alternate power detection:
  -- For normal resources, altR, altG, and altB are nil, but PowerBarColor[powerToken] is set.
  -- For alternate resources, PowerBarColor[powerToken] is nil, but altR, altG, and altB are set.
  if not altR and self.db.ShowOnlyAltPower then return end

  -- Determine power bar color
  local colorInfo = PowerBarColor[powerToken]

  if colorInfo then
    self.BarColorRed, self.BarColorGreen, self.BarColorBlue = colorInfo.r, colorInfo.g, colorInfo.b
  elseif altR then
    self.BarColorRed, self.BarColorGreen, self.BarColorBlue = altR, altG, altB
  else
    colorInfo = PowerBarColor[powerType] or PowerBarColor["MANA"]
    self.BarColorRed, self.BarColorGreen, self.BarColorBlue = colorInfo.r, colorInfo.g, colorInfo.b
  end

  self.PowerFunction = power_func
end

function Widget:UpdateResourceBar()
  local bar_value, text_value = self:PowerFunction()

  local db = self.db
  if db.ShowBar then
    WidgetFrame.Bar:SetValue(bar_value)
  end

  if db.ShowText then
    WidgetFrame.Text:SetText(text_value)
  end
end

-- UNIT_POWER_UPDATE is only registered for target unit
function Widget:UNIT_POWER_UPDATE(unitid, powerType)
  local tp_frame = Addon:GetThreatPlateForUnit("target")

  if tp_frame and WidgetFrame:IsShown() then
    self:UpdateResourceBar()
  end
end

-- UNIT_DISPLAYPOWER is only registered for target unit
function Widget:UNIT_DISPLAYPOWER(unitid)
  local tp_frame = Addon:GetThreatPlateForUnit("target")

  if tp_frame then
    self:OnTargetUnitAdded(tp_frame, tp_frame.unit)
  end
end

function Widget:PLAYER_TARGET_CHANGED()
  local tp_frame = Addon:GetThreatPlateForUnit("target")

  if tp_frame then
    self:OnTargetUnitAdded(tp_frame, tp_frame.unit)
  else
    HideWidgetFrame()
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

    widget_frame.Text = widget_frame:CreateFontString(nil, "OVERLAY")

    local bar = _G.CreateFrame("StatusBar", nil, widget_frame)
    bar:SetFrameLevel(widget_frame:GetFrameLevel())
    bar:SetMinMaxValues(0, 100)
    widget_frame.Bar = bar

    widget_frame.Background = bar:CreateTexture(nil, "BACKGROUND")

    widget_frame.Border = _G.CreateFrame("Frame", nil, widget_frame.Bar, BackdropTemplate)
    widget_frame.Border:SetFrameLevel(widget_frame:GetFrameLevel())

    self:UpdateLayout()
  end

  self:PLAYER_TARGET_CHANGED()
end

function Widget:IsEnabled()
  return Addon.db.profile.ResourceWidget.ON
end

-- EVENT: UNIT_POWER_UPDATE: "unitID", "powerType"
function Widget:OnEnable()
  self:SubscribeEvent("PLAYER_TARGET_CHANGED")
  self:SubscribeUnitEvent("UNIT_POWER_UPDATE", "target")
  self:SubscribeUnitEvent("UNIT_DISPLAYPOWER", "target")
end

-- function Widget:OnDisable()
--   self:UnsubscribeAllEvents()
-- end

function Widget:EnabledForStyle(style, unit)
  return not (style == "NameOnly" or style == "NameOnly-Unique" or style == "etotem")
end

function Widget:OnTargetUnitAdded(tp_frame, unit)
  if not unit.isTarget then return end

  local widget_frame = WidgetFrame
  if not self:EnabledForStyle(unit.style, unit) then 
    HideWidgetFrame()
    return
  end

  local db = self.db
  local show_for_unit
  if unit.reaction == "FRIENDLY" then
    show_for_unit = db.ShowFriendly
  else
    if unit.type == "PLAYER" then
      show_for_unit = db.ShowEnemyPlayer
    elseif unit.isBoss or unit.isRare then
      show_for_unit = db.ShowEnemyBoss
    else
      show_for_unit = db.ShowEnemyNPC
    end
  end
  if not show_for_unit then 
    HideWidgetFrame()
    return
  end

  self:SetTargetPowerType(widget_frame, unit)
  if not self.PowerFunction then 
    HideWidgetFrame()
    return
  end

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

function Widget:OnTargetUnitRemoved(tp_frame, unit)
  -- OnTargetUnitAdded and OnTargetUnitRemoved are called for all target units including soft-target units. 
  -- Only hide the widget if the nameplate for the unit is removed that shows the widget
  if tp_frame == WidgetFrame:GetParent() then
    HideWidgetFrame()
  end  
end

function Widget:UpdateLayout()
  local widget_frame = WidgetFrame

  -- Updates based on settings
  local db = self.db

  widget_frame:SetSize(db.BarWidth, db.BarHeight)

  local bar = widget_frame.Bar
  if db.ShowBar then
    local bar_texture = Addon.LibSharedMedia:Fetch('statusbar', db.BarTexture)

    bar:SetAllPoints()
    bar:SetStatusBarTexture(bar_texture)

    local background = widget_frame.Background
    background:SetTexture(bar_texture)
    background:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPRIGHT")
    background:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")

    local border = widget_frame.Border
    border:SetBackdrop({
      --bgFile = bar_texture,
      edgeFile = Addon.LibSharedMedia:Fetch('border', db.BorderTexture),
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

    text:SetFont(Addon.LibSharedMedia:Fetch('font', db.Font), db.FontSize)
    text:SetJustifyH("CENTER")
    text:SetShadowOffset(1, -1)
    text:SetMaxLines(1)

    local font_color = db.FontColor
    text:SetTextColor(font_color.r, font_color.g, font_color.b)
  end

  text:SetShown(db.ShowText)
end

function Widget:UpdateSettings()
  self.db = Addon.db.profile.ResourceWidget
end

--function Widget:UpdateAllFramesAfterSettingsUpdate()
--  -- Update the widget if it was already created (not true for immediately after Reload UI or if it was never enabled
--  -- in this since last Reload UI)
--  if WidgetFrame then
--    self:UpdateLayout()
--    self:PLAYER_TARGET_CHANGED()
--  end
--end
