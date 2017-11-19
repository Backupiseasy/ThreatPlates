------------------------
-- Resource Widget --
------------------------
local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local RGB = ThreatPlates.RGB
local format = format
local ceil = ceil
-- WoW functions
--local IsInInstance = IsInInstance
local UnitPowerMax = UnitPowerMax
local UnitPower = UnitPower
local UnitPowerType = UnitPowerType
local PowerBarColor = PowerBarColor

local WidgetList = {}
local WatcherIsEnabled = false

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function UpdateSettings(frame)
  local db = TidyPlatesThreat.db.profile.ResourceWidget

  frame:ClearAllPoints()
  frame:SetPoint("CENTER", frame:GetParent(), db.x, db.y)

  local bar = frame.Bar
  if db.ShowBar then
    bar:SetStatusBarTexture(ThreatPlates.Media:Fetch('statusbar', db.BarTexture))
  --  bar:GetStatusBarTexture():SetHorizTile(false)
  --  bar:GetStatusBarTexture():SetVertTile(false)
    bar:SetSize(db.BarWidth, db.BarHeight)
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", frame)

    local border = frame.Border
    local offset = db.BorderOffset
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -offset, offset)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", offset, -offset)
    border:SetBackdrop({
      bgFile = ThreatPlates.Media:Fetch('statusbar', db.BarTexture),
      edgeFile = ThreatPlates.Media:Fetch('border', db.BorderTexture),
      tile = false, tileSize = 0, edgeSize = db.BorderEdgeSize,
      insets = { left = offset, right = offset, top = offset, bottom = offset }
    })
    bar:Show()
  else
    bar:_Hide()
  end

  local text = frame.Text
  if db.ShowText then
    local font = ThreatPlates.Media:Fetch('font', db.Font)
    text:SetFont(font, db.FontSize)
    text:SetJustifyH("CENTER")
    text:SetShadowOffset(1, -1)
    text:SetMaxLines(1)
    local font_color = db.FontColor
    text:SetTextColor(font_color.r, font_color.g, font_color.b)
    text:Show()
  else
    text:_Hide()
  end
end

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
-- 	for _, widget in pairs(WidgetList) do
-- 		widget:Hide()
-- 	end
-- 	WidgetList = {}
-- end
-- ThreatPlatesWidgets.ClearAllUniqueIconWidgets = ClearAllWidgets

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
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

local function UpdateWidgetFrame(frame, unit)
  local db = TidyPlatesThreat.db.profile.ResourceWidget

  --local reaction = UnitIsFriend("player", "target")
  local show = false

    if unit.reaction == "FRIENDLY" then
      show = db.ShowFriendly
    else
      local t = unit.type
      if t == "PLAYER" then
        show = db.ShowEnemyPlayer
      elseif t == "NPC" then
        local b, r = unit.isBoss, unit.isRare
        if b or r then
          show = db.ShowEnemyBoss
--        elseif e then
--          local in_instance, _ = IsInInstance()
--          show = (not in_instance and db.ShowEnemyBoss) or (in_instance and db.ShowEnemyNPC)
        else
          show = db.ShowEnemyNPC
        end
      end
    end

  if not show then
    frame:_Hide()
    return
  end

  local powerType, powerToken, altR, altG, altB = UnitPowerType("target");
  local power_func = POWER_FUNCTIONS[powerToken]
--  print ("Power Type: ", powerType, powerToken)
--  print (UnitPower("target"), UnitPowerMax("target"))
  if UnitPowerMax("target") == 0 or (db.ShowOnlyAltPower and power_func) then
    frame:_Hide()
    return
  elseif not power_func then
    if altR then
      power_func = PowerGeneric
    else
      frame:_Hide()
      return
    end
  end

  -- determine color for power
  local info = PowerBarColor[powerToken];
  local r, b, g
  if info then
    --The PowerBarColor takes priority
    r, g, b = info.r, info.g, info.b;
  else
    if not altR then
      -- Couldn't find a power token entry. Default to indexing by power type or just mana if  we don't have that either.
      info = PowerBarColor[powerType] or PowerBarColor["MANA"];
      r, g, b = info.r, info.g, info.b;
    else
      r, g, b = altR, altG, altB;
    end
  end

  if power_func then
    local bar_value, text_value = power_func()

    local bar = frame.Bar
    if db.ShowBar then
      local a = 1
      bar:SetValue(bar_value)
      bar:SetStatusBarColor(r, g, b, a)

      local border = frame.Border
      if db.BackgroundUseForegroundColor then
        border:SetBackdropColor(r, g, b, 0.3)
      else
        local color = db.BackgroundColor
        border:SetBackdropColor(color.r, color.g, color.b, color.a)
      end

      if db.BorderUseForegroundColor then
        border:SetBackdropBorderColor(r, g, b, 1)
      elseif db.BorderUseBackgroundColor then
        local color = db.BackgroundColor
        border:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
      else
        local color = db.BorderColor
        border:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
      end
    else
      bar:_Hide()
    end

    local text = frame.Text
    if db.ShowText then
      text:SetText(text_value)
    else
      text:_Hide()
    end

    frame:Show()
  else
    frame:_Hide()
  end
end

-- Context
local function UpdateWidgetContext(frame, unit)
  local guid = unit.guid
  frame.guid = guid
  frame.unit = unit

  --Add to Widget List
  if guid then
    WidgetList[guid] = frame
  end

  -- Custom Code II
  --------------------------------------
  if UnitGUID("target") == guid then
--    WidgetList[guid] = frame
    UpdateWidgetFrame(frame, unit)
  else
    frame:_Hide()
  end
  --------------------------------------
  -- End Custom Code
end

local function ClearWidgetContext(frame)
  local guid = frame.guid
  if guid then
    WidgetList[guid] = nil
    frame.guid = nil
    frame.unit = nil
  end
end

-- Watcher Frame
local WatcherFrame = CreateFrame("Frame", nil, WorldFrame)

local function WatcherFrameHandler(frame, event, unitid, powerType)
  -- EVENT UNIT_POWER: "unitID", "powerType"

  --if UnitExists("target") then
  -- only watch for target unitsm
  local guid = UnitGUID("target")
  if guid then
    local widget = WidgetList[guid]
    if widget then
      UpdateWidgetFrame(widget, widget.unit)
    end
    -- To update all, use: for guid, widget in pairs(WidgetList) do UpdateWidgetFrame(widget) end
  end
end

local function EnableWatcher()
  WatcherFrame:SetScript("OnEvent", WatcherFrameHandler)
  WatcherFrame:RegisterEvent("UNIT_POWER")
  WatcherIsEnabled = true
end

local function DisableWatcher()
  WatcherFrame:UnregisterAllEvents()
  WatcherFrame:SetScript("OnEvent", nil)
  WatcherIsEnabled = false
end

local function enabled()
  local active = TidyPlatesThreat.db.profile.ResourceWidget.ON

  if active then
    if not WatcherIsEnabled then EnableWatcher() end
  else
    if WatcherIsEnabled then DisableWatcher()	end
  end

  return active
end

--local function EnabledInHeadlineView()
--  return TidyPlatesThreat.db.profile.ResourceWidget.ShowInHeadlineView
--end

local function CreateWidgetFrame(parent)
  -- Required Widget Code
  local frame = CreateFrame("Frame", nil, parent)
  frame:Hide()

  -- Custom Code III
  --------------------------------------
  frame:SetSize(32, 32)
  frame:SetFrameLevel(parent:GetFrameLevel() + 3)

  local text = frame:CreateFontString(nil, "OVERLAY")
  frame.Text = text
  text:SetAllPoints()

  local bar = CreateFrame("StatusBar", nil, frame)
  frame.Bar = bar
  bar:SetFrameLevel(frame:GetFrameLevel() - 1)
  bar:SetMinMaxValues(0, 100)

  local border = CreateFrame("Frame", nil, bar)
  frame.Border = border
  border:SetFrameLevel(bar:GetFrameLevel())

  UpdateSettings(frame)
  frame.UpdateConfig = UpdateSettings
  --------------------------------------
  -- End Custom Code

  -- Required Widget Code
  frame.UpdateContext = UpdateWidgetContext
  frame.Update = UpdateWidgetFrame
  frame._Hide = frame.Hide
  frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end

  return frame
end

ThreatPlatesWidgets.RegisterWidget("ResourceWidgetTPTP", CreateWidgetFrame, true, enabled)
ThreatPlatesWidgets.ResourceWidgetDisableWatcher = DisableWatcher