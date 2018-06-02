---------------------------------------------------------------------------------------------------
-- Resource Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Module = Addon:NewModule("Resource")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local format = format
local ceil = ceil

-- WoW APIs
local CreateFrame = CreateFrame
local UnitReaction, UnitIsPlayer, UnitClassification, UnitLevel, UnitIsUnit = UnitReaction, UnitIsPlayer, UnitClassification, UnitLevel, UnitIsUnit
local UnitPower, UnitPowerMax, UnitPowerType = UnitPower, UnitPowerMax, UnitPowerType
local PowerBarColor = PowerBarColor
local SPELL_POWER_MANA = SPELL_POWER_MANA
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local CurrentTarget

---------------------------------------------------------------------------------------------------
-- Resource Widget Functions
---------------------------------------------------------------------------------------------------

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

local POWER_FUNCTIONS = {
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

local function DeterminePowerType(widget_frame)
  local unitid = widget_frame.unit.unitid

  -- The code to determine the power type could be moved to OnUnitAdded, but then code is necessary to determine when
  -- the power type on the unit changes (e.g., a druid that shapeshifts). Mabe there's even bosses that do that?!?
  local powerType, powerToken, altR, altG, altB = UnitPowerType(unitid)

  local db = TidyPlatesThreat.db.profile.ResourceWidget
  local power_func = POWER_FUNCTIONS[powerToken]

  if UnitPowerMax(unitid) == 0 or (db.ShowOnlyAltPower and power_func) then
    return nil
  elseif not power_func then
    if altR then
      power_func = PowerGeneric
    else
      return nil
    end
  end

  -- determine color for power
  local info = PowerBarColor[powerToken]
  local r, b, g
  if info then
    --The PowerBarColor takes priority
    widget_frame.BarColorRed, widget_frame.BarColorGreen, widget_frame.BarColorBlue = info.r, info.g, info.b;
  elseif not altR then
    -- Couldn't find a power token entry. Default to indexing by power type or just mana if  we don't have that either.
    info = PowerBarColor[powerType] or PowerBarColor["MANA"];
    widget_frame.BarColorRed, widget_frame.BarColorGreen, widget_frame.BarColorBlue = info.r, info.g, info.b
  else
    widget_frame.BarColorRed, widget_frame.BarColorGreen, widget_frame.BarColorBlue = altR, altG, altB
  end

  return power_func
end

local function UpdateResourceBar(widget_frame)
  local db = TidyPlatesThreat.db.profile.ResourceWidget

  local power_func = DeterminePowerType(widget_frame)

  if not power_func then
    widget_frame:Hide()
    return
  end

  local bar_value, text_value = power_func()
  local bar = widget_frame.Bar

  if db.ShowBar then
    local a = 1
    bar:SetValue(bar_value)
    bar:SetStatusBarColor(widget_frame.BarColorRed, widget_frame.BarColorGreen, widget_frame.BarColorBlue, a)

    local border = widget_frame.Border
    if db.BackgroundUseForegroundColor then
      border:SetBackdropColor(widget_frame.BarColorRed, widget_frame.BarColorGreen, widget_frame.BarColorBlue, 0.3)
    else
      local color = db.BackgroundColor
      border:SetBackdropColor(color.r, color.g, color.b, color.a)
    end

    if db.BorderUseForegroundColor then
      border:SetBackdropBorderColor(widget_frame.BarColorRed, widget_frame.BarColorGreen, widget_frame.BarColorBlue, 1)
    elseif db.BorderUseBackgroundColor then
      local color = db.BackgroundColor
      border:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
    else
      local color = db.BorderColor
      border:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
    end
    bar:Show()
  else
    bar:Hide()
  end

  if db.ShowText then
    widget_frame.Text:SetText(text_value)
    widget_frame.Text:Show()
  else
    widget_frame.Text:Hide()
  end

  widget_frame:Show()
  CurrentTarget = widget_frame
end

-- This event handler only watches for events of unit == "target"
function Module:UNIT_POWER(unitid, powerType)
  local plate = GetNamePlateForUnit("target")
  if plate then
    local widget_frame = plate.TPFrame.widgets["Resource"]
    if widget_frame.ShowWidget then
      UpdateResourceBar(widget_frame)
    end
  end
end

function Module:PLAYER_TARGET_CHANGED()
  if CurrentTarget then
    CurrentTarget:Hide()
    CurrentTarget = nil
  end

  local plate = GetNamePlateForUnit("target")
  if plate and plate.TPFrame.Active then
    CurrentTarget = plate.TPFrame.widgets.Resource

    if CurrentTarget.Active and CurrentTarget.ShowWidget then
      UpdateResourceBar(CurrentTarget)
    end
  end
end
---------------------------------------------------------------------------------------------------
-- Module functions for creation and update
---------------------------------------------------------------------------------------------------

function Module:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  widget_frame.Text = widget_frame:CreateFontString(nil, "OVERLAY")
  widget_frame.Bar = CreateFrame("StatusBar", nil, widget_frame)
  widget_frame.Border = CreateFrame("Frame", nil, widget_frame.Bar)
  -- End Custom Code

  -- Required Widget Code
  return widget_frame
end

function Module:IsEnabled()
  return TidyPlatesThreat.db.profile.ResourceWidget.ON
end

function Module:OnEnable()
  self:RegisterUnitEvent("UNIT_POWER", "target")
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
  -- Module:RegisterEvent("UNIT_DISPLAYPOWER") -- use this to determine power type changes on units
end

function Module:EnabledForStyle(style, unit)
  return not (style == "NameOnly" or style == "NameOnly-Unique" or style == "etotem")
end

function Module:OnUnitAdded(widget_frame, unit)
  local db = TidyPlatesThreat.db.profile.ResourceWidget

  widget_frame.ShowWidget = false
  if UnitReaction(unit.unitid, "player") > 4 then
    widget_frame.ShowWidget = db.ShowFriendly
  elseif unit.type == "PLAYER" then
    widget_frame.ShowWidget = db.ShowEnemyPlayer
  else
    widget_frame.ShowWidget = ((unit.isBoss or unit.isRare) and db.ShowEnemyBoss) or db.ShowEnemyNPC
  end

  if not widget_frame.ShowWidget then
    widget_frame:Hide()
    return
  end

  widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
  widget_frame:SetSize(db.BarWidth, db.BarHeight)
  widget_frame:SetFrameLevel(widget_frame:GetParent():GetFrameLevel() + 8)

  local bar = widget_frame.Bar
  if db.ShowBar then
    bar:SetStatusBarTexture(ThreatPlates.Media:Fetch('statusbar', db.BarTexture))

    bar:SetAllPoints()
    bar:SetFrameLevel(widget_frame:GetFrameLevel())
    bar:SetMinMaxValues(0, 100)

    local border = widget_frame.Border
    local bar_texture = ThreatPlates.Media:Fetch('statusbar', db.BarTexture)
    local border_texture = ThreatPlates.Media:Fetch('border', db.BorderTexture)
    border:SetBackdrop({
      bgFile = bar_texture,
      edgeFile = border_texture,
      edgeSize = db.BorderEdgeSize,
      insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    border:SetPoint("TOPLEFT", widget_frame, "TOPLEFT", - db.BorderOffset, db.BorderOffset)
    border:SetPoint("BOTTOMRIGHT", widget_frame, "BOTTOMRIGHT", db.BorderOffset, - db.BorderOffset)
    border:SetFrameLevel(widget_frame.Bar:GetFrameLevel())
  end

  local text = widget_frame.Text
  if db.ShowText then
    text:SetFont(ThreatPlates.Media:Fetch('font', db.Font), db.FontSize)
    text:SetJustifyH("CENTER")
    text:SetShadowOffset(1, -1)
    text:SetMaxLines(1)
    local font_color = db.FontColor
    text:SetTextColor(font_color.r, font_color.g, font_color.b)
    text:SetAllPoints()
  end

  --  DeterminePowerType(widget_frame)
  --
  --  if not widget_frame.PowerFunction then
  --    widget_frame:Hide()
  --    return
  --  end

  if UnitIsUnit("target", unit.unitid) then
    UpdateResourceBar(widget_frame)
  else
    widget_frame:Hide()
  end

  --self:OnTargetChanged(widget_frame, unit)
end

--function Module:OnTargetChanged(widget_frame, unit)
--  if UnitIsUnit("target", unit.unitid) and widget_frame.ShowWidget then
--    UpdateResourceBar(widget_frame)
--  else
--    widget_frame:Hide()
--  end
--end
