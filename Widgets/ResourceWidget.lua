------------------------
-- Resource Widget --
------------------------
local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local format = format
local ceil = ceil

-- WoW functions
local UnitPowerMax = UnitPowerMax
local UnitPower = UnitPower
local UnitPowerType = UnitPowerType
local PowerBarColor = PowerBarColor
local SPELL_POWER_MANA = SPELL_POWER_MANA
local UnitGUID = UnitGUID
local CreateFrame = CreateFrame

local WidgetList = {}
local WatcherIsEnabled = false

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function UpdateSettings(frame)
  local db = TidyPlatesThreat.db.profile.ResourceWidget

  frame:SetPoint("CENTER", frame:GetParent(), db.x, db.y)
  frame:SetSize(db.BarWidth, db.BarHeight)
  frame:SetFrameLevel(frame:GetParent():GetFrameLevel() + 8)

  local bar = frame.Bar
  if db.ShowBar then
    bar:SetStatusBarTexture(ThreatPlates.Media:Fetch('statusbar', db.BarTexture))

    bar:SetAllPoints()
    bar:SetFrameLevel(frame:GetFrameLevel())
    bar:SetMinMaxValues(0, 100)

    local border = frame.Border
    local offset = db.BorderOffset
    --border:SetBackdrop(BACKDROP)

--    local backdrop = border:GetBackdrop()
    local bar_texture = ThreatPlates.Media:Fetch('statusbar', db.BarTexture)
    local border_texture = ThreatPlates.Media:Fetch('border', db.BorderTexture)
--    if backdrop.bgFile ~= bar_texture or backdrop.edgeFile ~= border_texture or backdrop.edgeSize ~= db.BorderEdgeSize or backdrop.insets.left ~= offset then
      border:SetBackdrop({
          bgFile = bar_texture,
          edgeFile = border_texture,
          edgeSize = db.BorderEdgeSize,
          insets = { left = 0, right = 0, top = 0, bottom = 0 }
      })
--    end

    local offset_x = db.BarWidth + 2 * offset
    local offset_y = db.BarHeight + 2 * offset
    if border:GetWidth() ~= offset_x or border:GetHeight() ~= offset_y  then
      border:SetPoint("TOPLEFT", frame, "TOPLEFT", - offset, offset)
      border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offset, - offset)
      --      border:SetSize(offset_x, offset_y)
      --      border:SetPoint("CENTER", bar, "CENTER", 0, 0)
      --      border:SetFrameLevel(frame.Bar:GetFrameLevel())
    end
    border:SetFrameLevel(frame.Bar:GetFrameLevel())

    bar:Show()
  else
    bar:Hide()
  end

  local text = frame.Text
  if db.ShowText then
    text:SetFont(ThreatPlates.Media:Fetch('font', db.Font), db.FontSize)
    text:SetJustifyH("CENTER")
    text:SetShadowOffset(1, -1)
    text:SetMaxLines(1)
    local font_color = db.FontColor
    text:SetTextColor(font_color.r, font_color.g, font_color.b)
    text:SetAllPoints()
    text:Show()
  else
    text:Hide()
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

  local powerType, powerToken, altR, altG, altB = UnitPowerType("target")
  local power_func = POWER_FUNCTIONS[powerToken]
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
      bar:Show()
    else
      bar:Hide()
    end

    if db.ShowText then
      frame.Text:SetText(text_value)
      frame.Text:Show()
    else
      frame.Text:Hide()
    end

    frame:Show()
  else
    frame:_Hide()
  end
end

-- Context
local function UpdateWidgetContext(frame, unit)
  local guid = unit.guid

  --Add to Widget List
  if guid then
    if frame.guid then WidgetList[frame.guid] = nil end
    frame.guid = guid
    frame.unit = unit
    WidgetList[guid] = frame
  end

  -- Custom Code II
  --------------------------------------
  if UnitGUID("target") == guid then
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

-- EVENT: UNIT_POWER: "unitID", "powerType"
local function WatcherFrameHandler(frame, event, unitid, powerType)
  -- only watch for target units
  if unitid ~= "target" then return end
  --if not UnitIsUnit(unitid, "target") then return end

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
  local frame = CreateFrame("StatusBar", nil, parent)
  frame:Hide()

  -- Custom Code III
  --------------------------------------
  frame.Text = frame:CreateFontString(nil, "OVERLAY")
  frame.Bar = CreateFrame("StatusBar", nil, frame)
  frame.Border = CreateFrame("Frame", nil, frame.Bar)

--  local db = TidyPlatesThreat.db.profile.ResourceWidget
--  frame:SetPoint("CENTER", frame:GetParent(), db.x, db.y)
--  frame:SetSize(db.BarWidth, db.BarHeight)
--  frame:SetFrameLevel(frame:GetParent():GetFrameLevel() + 8)

--  local bar = frame.Bar
--  bar:SetStatusBarTexture(ThreatPlates.Media:Fetch('statusbar', db.BarTexture))
--  bar:SetAllPoints()
--  bar:SetFrameLevel(frame:GetFrameLevel())
--  bar:SetMinMaxValues(0, 100)

--  local border = frame.Border
--  local offset = db.BorderOffset
--  border:SetBackdrop({
--    bgFile = ThreatPlates.Media:Fetch('statusbar', db.BarTexture),
--    edgeFile = ThreatPlates.Media:Fetch('border', db.BorderTexture),
--    edgeSize = db.BorderEdgeSize,
--    insets = { left = offset, right = offset, top = offset, bottom = offset }
--  })
--  border:SetSize(db.BarWidth + 2 * offset, db.BarHeight + 2 * offset)
--  border:SetPoint("CENTER", bar, "CENTER", 0, 0)
  --border:SetFrameLevel(frame.Bar:GetFrameLevel())

--  local text = frame.Text
--  local font_color = db.FontColor
--  text:SetFont(ThreatPlates.Media:Fetch('font', db.Font), db.FontSize)
--  text:SetJustifyH("CENTER")
--  text:SetShadowOffset(1, -1)
--  text:SetMaxLines(1)
--  text:SetTextColor(font_color.r, font_color.g, font_color.b)
--  text:SetAllPoints()

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
