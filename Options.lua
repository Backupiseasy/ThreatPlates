local _, Addon = ...
local t = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local abs = abs
local pairs = pairs
local ipairs = ipairs
local string = string
local table = table
local tonumber = tonumber
local select = select
local type = type

-- WoW APIs
local CLASS_SORT_ORDER = CLASS_SORT_ORDER
local InCombatLockdown, IsInInstance = InCombatLockdown, IsInInstance
local SetCVar, GetCVar, GetCVarBool = SetCVar, GetCVar, GetCVarBool
local GetSpellInfo = GetSpellInfo
local UnitsExists, UnitName = UnitsExists, UnitName

-- ThreatPlates APIs
local LibStub = LibStub
local L = t.L

local PATH_ART = t.Art

-- local TidyPlatesThreat = LibStub("AceAddon-3.0"):GetAddon("TidyPlatesThreat");
local TidyPlatesThreat = TidyPlatesThreat

local UNIT_TYPES = {
  {
    Faction = "Friendly", Disabled = "nameplateShowFriends",
    UnitTypes = { "Player", "NPC", "Totem", "Guardian", "Pet", "Minus"}
  },
  {
    Faction = "Enemy", Disabled = "nameplateShowEnemies",
    UnitTypes = { "Player", "NPC", "Totem", "Guardian", "Pet", "Minus" }
  },
  {
    Faction = "Neutral", Disabled = "nameplateShowEnemies",
    UnitTypes = { "NPC", "Minus" }
  }
}

local AURA_STYLE = {
  wide = {
    IconWidth = 26.5,
    IconHeight = 14.5,
    ShowBorder = true,
    Duration = {
      Anchor = "RIGHT",
      InsideAnchor = true,
      HorizontalOffset = -1,
      VerticalOffset = 8,
      Font = {
        Typeface = Addon.DEFAULT_SMALL_FONT,
        Size = 10,
        Transparency = 1,
        Color = t.RGB(255, 255, 255),
        flags = "OUTLINE",
        Shadow = true,
        HorizontalAlignment = "RIGHT",
        VerticalAlignment = "CENTER",
      }
    },
    StackCount = {
      Anchor = "RIGHT",
      InsideAnchor = true,
      HorizontalOffset = -1,
      VerticalOffset = -6,
      Font = {
        Typeface = Addon.DEFAULT_SMALL_FONT,
        Size = 10,
        Transparency = 1,
        Color = t.RGB(255, 255, 255),
        flags = "OUTLINE",
        Shadow = true,
        HorizontalAlignment = "RIGHT",
        VerticalAlignment = "CENTER",
      }
    },
  },
  square = {
    IconWidth = 16.5,
    IconHeight = 14.5,
    ShowBorder = true,
    Duration = {
      Anchor = "RIGHT",
      InsideAnchor = true,
      HorizontalOffset = 0,
      VerticalOffset = 8,
      Font = {
        Typeface = Addon.DEFAULT_SMALL_FONT,
        Size = 10,
        Transparency = 1,
        Color = t.RGB(255, 255, 255),
        flags = "OUTLINE",
        Shadow = true,
        HorizontalAlignment = "RIGHT",
        VerticalAlignment = "CENTER",
      }
    },
    StackCount = {
      Anchor = "RIGHT",
      InsideAnchor = true,
      HorizontalOffset = 0,
      VerticalOffset = -6,
      Font = {
        Typeface = Addon.DEFAULT_SMALL_FONT,
        Size = 10,
        Transparency = 1,
        Color = t.RGB(255, 255, 255),
        flags = "OUTLINE",
        Shadow = true,
        HorizontalAlignment = "RIGHT",
        VerticalAlignment = "CENTER",
      }
    },
  }
}

-- local reference to current profile
local db
-- table for storing the options dialog
local options = nil

-- Functions

local function GetSpellName(number)
  local n = GetSpellInfo(number)
  return n
end

function Addon:InitializeCustomNameplates()
  local db = TidyPlatesThreat.db.profile

  db.uniqueSettings.map = {}
  for i, unique_unit in pairs(db.uniqueSettings) do
    if type(i) == "number" and unique_unit.name and unique_unit.name ~= "<Enter name here>" then
      db.uniqueSettings.map[unique_unit.name] = unique_unit
    end
  end
end

local function UpdateSpecial() -- Need to add a way to update options table.
  Addon:InitializeCustomNameplates()
  -- Update widgets as well as at least some of them use custom nameplate settings
  Addon.Widgets:InitializeAllWidgets()
  Addon:ForceUpdate()
end

local function GetValue(info)
  local DB = TidyPlatesThreat.db.profile
  local value = DB
  local keys = info.arg
  for index = 1, #keys do
    value = value[keys[index]]
  end
  return value
end

local function CheckIfValueExists(widget_info, setting)
  local info = { arg = Addon.ConcatTables(widget_info, setting) }

  return GetValue(info) ~= nil
end

local function SetValuePlain(info, value)
  -- info: table with path to setting in options dialog, that was changed
  -- info.arg: table with parameter arg from options definition
  local DB = TidyPlatesThreat.db.profile
  local keys = info.arg
  for index = 1, #keys - 1 do
    DB = DB[keys[index]]
  end
  DB[keys[#keys]] = value
end

local function SetValue(info, value)
  SetValuePlain(info, value)
  Addon:ForceUpdate()
end

local function SetSelectValue(info, value)
  local select = info.values
  SetValue(info, select[value])
end

local function GetSelectValue(info)
  local value = GetValue(info)
  local select = info.values
  return select[value]
end

local function GetValueChar(info)
  local DB = TidyPlatesThreat.db.char
  local value = DB
  local keys = info.arg
  for index = 1, #keys do
    value = value[keys[index]]
  end
  return value
end

local function SetValueChar(info, value)
  local DB = TidyPlatesThreat.db.char
  local keys = info.arg
  for index = 1, #keys - 1 do
    DB = DB[keys[index]]
  end
  DB[keys[#keys]] = value
  Addon:ForceUpdate()
end

local function GetCVarTPTP(info)
  return tonumber(GetCVar(info.arg))
end

local function GetCVarBoolTPTP(info)
  return GetCVarBool(info.arg)
end

local function SetCVarTPTP(info, value)
  if InCombatLockdown() then
    t.Print("We're unable to change this while in combat", true)
  else
    SetCVar(info.arg, value)
    Addon:ForceUpdate()
  end
end

local function SetCVarBoolTPTP(info, value)
  --if InCombatLockdown() then
  --  t.Print("We're unable to change this while in combat", true)
  --else
    if type(info) == "table" then
      info = info.arg
    end
    SetCVar(info, (value and 1) or 0)
    Addon:ForceUpdate()
  --end
end

local function SyncGameSettings(info, val)
  if InCombatLockdown() then
    t.Print("We're unable to change this while in combat", true)
  else
    SetValue(info, val)
    TidyPlatesThreat:PLAYER_REGEN_ENABLED()
  end
end

local function SyncGameSettingsWorld(info, val)
  if InCombatLockdown() then
    t.Print("We're unable to change this while in combat", true)
  else
    SetValue(info, val)
    local isInstance, instanceType = IsInInstance()
    if isInstance then
      TidyPlatesThreat:PLAYER_ENTERING_WORLD()
    end
  end
end
-- Colors

local function GetColor(info)
  local DB = TidyPlatesThreat.db.profile
  local value = DB
  local keys = info.arg
  for index = 1, #keys do
    value = value[keys[index]]
  end
  return value.r, value.g, value.b
end

local function SetColor(info, r, g, b)
  local DB = TidyPlatesThreat.db.profile
  local keys = info.arg
  for index = 1, #keys - 1 do
    DB = DB[keys[index]]
  end
  DB[keys[#keys]].r, DB[keys[#keys]].g, DB[keys[#keys]].b = r, g, b
  Addon:ForceUpdate()
end

local function GetColorAlpha(info)
  local DB = TidyPlatesThreat.db.profile
  local value = DB
  local keys = info.arg
  for index = 1, #keys do
    value = value[keys[index]]
  end
  return value.r, value.g, value.b, value.a
end

local function SetColorAlpha(info, r, g, b, a)
  local DB = TidyPlatesThreat.db.profile
  local keys = info.arg
  for index = 1, #keys - 1 do
    DB = DB[keys[index]]
  end
  DB[keys[#keys]].r, DB[keys[#keys]].g, DB[keys[#keys]].b, DB[keys[#keys]].a = r, g, b, a
  Addon:ForceUpdate()
end

local function GetUnitVisibilitySetting(info)
  local unit_type = info.arg
  local unit_visibility = TidyPlatesThreat.db.profile.Visibility[unit_type].Show

  if type(unit_visibility)  ~= "boolean" then
    unit_visibility = GetCVarBool(unit_visibility)
  end

  return unit_visibility
end

local function SetUnitVisibilitySetting(info, value)
  local unit_type = info.arg
  local unit_visibility = TidyPlatesThreat.db.profile.Visibility[unit_type]

  if type(unit_visibility.Show) == "boolean" then
    unit_visibility.Show = value
  else
    SetCVarBoolTPTP(unit_visibility.Show, value)
  end
  Addon:ForceUpdate()
end

-- Set Theme Values

local function SetThemeValue(info, val)
  SetValuePlain(info, val)
  Addon:SetThemes(TidyPlatesThreat)

  -- Update TargetArt widget as it depends on some settings of customtext and name
  if info.arg[1] == "HeadlineView" and (info.arg[2] == "customtext" or info.arg[2] == "name") and (info.arg[3] == "y" or info.arg[3] == "size") then
    Addon.Widgets:UpdateSettings("TargetArt")
  end

  Addon:ForceUpdate()
end

local function GetFontFlags(settings, flag)
  local db_font = db
  for i = 1, #settings do
    db_font = db_font[settings[i]]
  end

  if flag == "Thick" then
    return string.find(db_font, "^THICKOUTLINE")
  elseif flag == "Outline" then
    return string.find(db_font, "^OUTLINE")
  else --if flag == "Mono" then
    return string.find(db_font, "MONOCHROME$")
  end
end

local function SetFontFlags(settings, flag, val)
  if flag == "Thick" then
    local outline = (val and "THICKOUTLINE") or (GetFontFlags(settings, "Outline") and "OUTLINE") or "NONE"
    local mono = (GetFontFlags(settings, "Mono") and ", MONOCHROME") or ""
    return outline .. mono
  elseif flag == "Outline" then
    local outline = (val and "OUTLINE") or (GetFontFlags(settings, "Thick") and "THICKOUTLINE") or "NONE"
    local mono = (GetFontFlags(settings, "Mono") and ", MONOCHROME") or ""
    return outline .. mono
  else -- flag = "Mono"
    local outline = (GetFontFlags(settings, "Thick") and "THICKOUTLINE") or (GetFontFlags(settings, "Outline") and "OUTLINE") or "NONE"
    local mono = (val and ", MONOCHROME") or ""
    return outline .. mono
  end
end

-- Set widget values

-- Key is key from options data structure for the widget, value is widget name as used in NewWidget
local MAP_OPTION_TO_WIDGET = {
  ComboPointsWidget = "ComboPoints",
  ResourceWidget = "Resource",
  AurasWidget = "Auras",
  TargetArtWidget = "TargetArt",
  ArenaWidget = "Arena",
}

local function SetValueWidget(info, val)
  SetValuePlain(info, val)
  Addon.Widgets:UpdateSettings(MAP_OPTION_TO_WIDGET[info[2]])
end

local function SetColorWidget(info, r, g, b, a)
  local DB = TidyPlatesThreat.db.profile
  local keys = info.arg
  for index = 1, #keys - 1 do
    DB = DB[keys[index]]
  end
  DB[keys[#keys]].r, DB[keys[#keys]].g, DB[keys[#keys]].b = r, g, b

  Addon.Widgets:UpdateSettings(MAP_OPTION_TO_WIDGET[info[2]])
end

local function SetColorAlphaWidget(info, r, g, b, a)
  local DB = TidyPlatesThreat.db.profile
  local keys = info.arg
  for index = 1, #keys - 1 do
    DB = DB[keys[index]]
  end
  DB[keys[#keys]].r, DB[keys[#keys]].g, DB[keys[#keys]].b, DB[keys[#keys]].a = r, g, b, a

  Addon.Widgets:UpdateSettings(MAP_OPTION_TO_WIDGET[info[2]])
end

---------------------------------------------------------------------------------------------------
-- Functions to create the options dialog
---------------------------------------------------------------------------------------------------

function Addon:SetCVarsForOcclusionDetection()
  Addon.CVars:Set("nameplateMinAlpha", 1)
  Addon.CVars:Set("nameplateMaxAlpha", 1)

  -- Create enough separation between occluded and not occluded nameplates, even for targeted units
  local occluded_alpha_mult = tonumber(GetCVar("nameplateOccludedAlphaMult"))
  if occluded_alpha_mult > 0.9  then
    occluded_alpha_mult = 0.9
    Addon.CVars:Set("nameplateOccludedAlphaMult", occluded_alpha_mult)
  end

  local selected_alpha =  tonumber(GetCVar("nameplateSelectedAlpha"))
  if not selected_alpha or (selected_alpha < occluded_alpha_mult + 0.1) then
    selected_alpha = occluded_alpha_mult + 0.1
    Addon.CVars:Set("nameplateSelectedAlpha", selected_alpha)
  end
end

---------------------------------------------------------------------------------------------------
-- Functions to create the options dialog
---------------------------------------------------------------------------------------------------

local function GetDescriptionEntry(text)
  return {
    name = text,
    order = 0,
    type = "description",
    width = "full",
  }
end

local function GetSpacerEntry(pos)
  return {
    name = "",
    order = pos,
    type = "description",
    width = "full",
  }
end

local function GetColorEntry(entry_name, pos, setting)
  return {
    name = entry_name,
    order = pos,
    type = "color",
    arg = setting,
    get = GetColor,
    set = SetColor,
    hasAlpha = false,
  }
end

local function GetColorAlphaEntry(pos, setting, disabled_func)
  return {
    name = L["Color"],
    order = pos,
    type = "color",
    width = "half",
    arg = setting,
    get = GetColorAlpha,
    set = SetColorAlpha,
    hasAlpha = true,
    disabled = disabled_func
  }
end

local function GetEnableEntry(entry_name, description, widget_info, enable_hv, func_set)
  local entry = {
    name = entry_name,
    order = 5,
    type = "group",
    inline = true,
    set = func_set,
    args = {
      Header = {
        name = description,
        order = 1,
        type = "description",
        width = "full",
      },
      Enable = {
        name = L["Show in Healthbar View"],
        order = 2,
        type = "toggle",
        width = "double",
        arg = { widget_info, "ON" },
      },
--      EnableHV = {
--        name = L["Show in Headline View"],
--        order = 3,
--        type = "toggle",
--        width = "double",
--        arg = { widget_info, "ShowInHeadlineView" },
--      },
    },
  }

    if enable_hv then
      entry.args.EnableHV = {
        name = L["Show in Headline View"],
        order = 3,
        type = "toggle",
        width = "double",
        arg = { widget_info, "ShowInHeadlineView" },
    }
    end

  return entry
end

local function GetEnableEntryTheme(entry_name, description, widget_info)
  local entry = {
    name = L["Enable"],
    order = 5,
    type = "group",
    inline = true,
    args = {
      Header = {
        name = description,
        order = 1,
        type = "description",
        width = "full",
      },
      Enable = {
        name = entry_name,
        order = 2,
        type = "toggle",
        width = "double",
        set = SetThemeValue,
        arg = { "settings", widget_info, "show" },
      },
    },
  }
  return entry
end

local function GetRangeEntry(name, pos, setting, min, max, set_func)
  local entry = {
    name = name,
    order = pos,
    type = "range",
    step = 1,
    softMin = min,
    softMax = max,
    set = set_func,
    arg = setting,
  }
  return entry
end

local function GetSizeEntry(name, pos, setting, func_disabled)
  local entry = {
    name = name,
    order = pos,
    type = "range",
    step = 1,
    softMin = 1,
    softMax = 100,
    arg = setting,
    disabled = func_disabled,
  }
  return entry
end

local function GetSizeEntryDefault(pos, setting, func_disabled)
  return GetSizeEntry(L["Size"], pos, { setting, "scale" }, func_disabled)
end

local function GetSizeEntryTheme(pos, setting)
  return GetSizeEntry(L["Size"], pos, { "settings", setting, "scale" })
end

local function GetScaleEntry(name, pos, setting, func_disabled, min_value, max_value)
  min_value = min_value or 0.3
  max_value = max_value or 2.0

  local entry = {
    name = name,
    order = pos,
    type = "range",
    step = 0.05,
    min = min_value,
    max = max_value,
    isPercent = true,
    arg = setting,
    disabled = func_disabled,
  }
  return entry
end

local function GetScaleEntryDefault(pos, setting, func_disabled)
  return GetScaleEntry(L["Scale"], pos, setting, func_disabled)
end

local function GetScaleEntryOffset(pos, setting, func_disabled)
  return GetScaleEntry(L["Scale"], pos, setting, func_disabled, -1.7, 2.0)
end

local function GetScaleEntryWidget(name, pos, setting, func_disabled)
  local entry = GetScaleEntry(name, pos, setting, func_disabled)
  entry.width = "full"
  return entry
end

local function GetScaleEntryThreat(name, pos, setting, func_disabled)
  return GetScaleEntry(name, pos, setting, func_disabled, -1.7, 2.0)
end

local function GetAnchorEntry(pos, setting, anchor, func_disabled)
  local entry = {
    name = L["Anchor Point"],
    order = pos,
    type = "select",
    values = Addon.ANCHOR_POINT,
    arg = { setting, "anchor" },
    disabled = func_disabled,
  }
  return entry
end

local function GetTransparencyEntry(name, pos, setting, func_disabled, lower_limit)
  local min_value = (lower_limit and -1) or 0

  local entry = {
    name = name,
    order = pos,
    type = "range",
    step = 0.05,
    min = min_value,
    max = 1,
    isPercent = true,
    set = function(info, val) SetValue(info, abs(val - 1)) end,
    get = function(info) return 1 - GetValue(info) end,
    arg = setting,
    disabled = func_disabled,
  }
  return entry
end

local function GetTransparencyEntryOffset(pos, setting, func_disabled)
  return GetTransparencyEntry(L["Transparency"], pos, setting, func_disabled, true)
end

local function GetTransparencyEntryDefault(pos, setting, func_disabled)
  return GetTransparencyEntry(L["Transparency"], pos, setting, func_disabled)
end

local function GetTransparencyEntryWidget(pos, setting, func_disabled)
  return GetTransparencyEntry(L["Transparency"], pos, { setting, "alpha" }, func_disabled)
end

local function GetTransparencyEntryThreat(name, pos, setting, func_disabled)
  return GetTransparencyEntry(name, pos, setting, func_disabled, true)
end

local function GetTransparencyEntryWidgetNew(pos, setting, func_disabled)
  local entry = GetTransparencyEntry(L["Transparency"], pos, setting, func_disabled)
  entry.set = function(info, val) SetValueWidget(info, abs(val - 1)) end

  return entry
end

local function GetPlacementEntry(name, pos, setting)
  local entry = {
    name = name,
    order = pos,
    type = "range",
    min = -120,
    max = 120,
    step = 1,
    arg = setting,
  }

  return entry
end

local function GetPlacementEntryTheme(pos, setting, hv_mode)
  local x_name, y_name
  if hv_mode == true then
    x_name = L["Healthbar View X"]
    y_name = L["Healthbar View Y"]
  else
    x_name = L["X"]
    y_name = L["Y"]
  end

  local entry = {
    name = L["Placement"],
    order = pos,
    type = "group",
    set = SetThemeValue,
    args = {
      X = { type = "range", order = 1, name = L["X"], min = -120, max = 120, step = 1, arg = { "settings", setting, "x" } },
      Y = { type = "range", order = 2, name = L["Y"], min = -120, max = 120, step = 1, arg = { "settings", setting, "y" } }
    }
  }

  if hv_mode then
    entry.args.HeadlineViewX = { type = "range", order = 3, name = L["Headline View X"], min = -120, max = 120, step = 1, arg = { "settings", setting, "x_hv" } }
    entry.args.HeadlineViewY = { type = "range", order = 4, name = L["Headline View Y"], min = -120, max = 120, step = 1, arg = { "settings", setting, "y_hv" } }
  end

  return entry
end

local function GetPlacementEntryWidget(pos, widget_info, hv_mode)
  local x_name, y_name
  if hv_mode == true then
    x_name = L["Healthbar View X"]
    y_name = L["Healthbar View Y"]
  else
    x_name = L["X"]
    y_name = L["Y"]
  end

  local entry = {
    name = L["Placement"],
    order = pos,
    type = "group",
    inline = true,
    args = {
      HealthbarX = { type = "range", order = 1, name = x_name, min = -120, max = 120, step = 1, arg = { widget_info, "x" } },
      HealthbarY = { type = "range", order = 2, name = y_name, min = -120, max = 120, step = 1, arg = { widget_info, "y" } },
    }
  }

  if hv_mode then
    entry.args.HeadlineViewX = { type = "range", order = 3, name = L["Headline View X"], min = -120, max = 120, step = 1, arg = { widget_info, "x_hv" } }
    entry.args.HeadlineViewY = { type = "range", order = 4, name = L["Headline View Y"], min = -120, max = 120, step = 1, arg = { widget_info, "y_hv" } }
  end

  return entry
end

local function GetWidgetOffsetEntry(pos, widget_info)
  --  local func_healthbar = function() return not db[widget_info].ON end
  --  local func_headlineview = function() return not (db[widget_info].ON and db[widget_info].ShowInHeadlineView) end

  local entry = {
    name = L["Offset"],
    order = pos,
    type = "group",
    inline = true,
    args = {
      HealthbarX = { type = "range", order = 1, name = L["Healthbar View X"], min = -120, max = 120, step = 1, arg = { widget_info, "x" } },
      HealthbarY = { type = "range", order = 2, name = L["Healthbar View Y"], min = -120, max = 120, step = 1, arg = { widget_info, "y" } },
      HeadlineViewX = { type = "range", order = 3, name = L["Headline View X"], min = -120, max = 120, step = 1, arg = { widget_info, "x_hv" } },
      HeadlineViewY = { type = "range", order = 4, name = L["Headline View Y"], min = -120, max = 120, step = 1, arg = { widget_info, "y_hv" } },
    }
  }
  return entry
end

local function GetLayoutEntry(pos, widget_info, hv_mode)
  local entry = {
    name = L["Layout"],
    order = pos,
    type = "group",
    inline = true,
    args = {
      Size = GetSizeEntryDefault(10, widget_info),
      Placement = GetPlacementEntryWidget(20, widget_info, hv_mode),
    },
  }
  return entry
end

local function GetLayoutEntryTheme(pos, widget_info, hv_mode)
  local entry = {
    name = L["Layout"],
    order = pos,
    type = "group",
    inline = true,
    args = {
      Size = GetSizeEntryTheme(10, widget_info),
      Placement = GetPlacementEntryTheme(20, widget_info, hv_mode),
    },
  }
  return entry
end

local function GetFontEntryTheme(pos, widget_info, func_disabled)
  local entry = {
    name = L["Font"],
    type = "group",
    inline = true,
    order = pos,
    disabled = func_disabled,
    args = {
      Font = {
        name = L["Typeface"],
        order = 10,
        type = "select",
        dialogControl = "LSM30_Font",
        values = AceGUIWidgetLSMlists.font,
        set = SetThemeValue,
        arg = { "settings", widget_info, "typeface" },
      },
      Size = {
        name = L["Size"],
        order = 20,
        type = "range",
        set = SetThemeValue,
        arg = { "settings", widget_info, "size" },
        max = 36,
        min = 6,
        step = 1,
        isPercent = false,
      },
      Spacer = GetSpacerEntry(35),
      Outline = {
        name = L["Outline"],
        order = 40,
        type = "toggle",
        desc = L["Add black outline."],
        set = function(info, val) SetThemeValue(info, SetFontFlags({ "settings", widget_info, "flags" }, "Outline", val)) end,
        get = function(info) return GetFontFlags({ "settings", widget_info, "flags" }, "Outline") end,
        arg = { "settings", widget_info, "flags" },
      },
      Thick = {
        name = L["Thick"],
        order = 41,
        type = "toggle",
        desc = L["Add thick black outline."],
        set = function(info, val) SetThemeValue(info, SetFontFlags({ "settings", widget_info, "flags" }, "Thick", val)) end,
        get = function(info) return GetFontFlags({ "settings", widget_info, "flags" }, "Thick") end,
        arg = { "settings", widget_info, "flags" },
      },

      Mono = {
        name = L["Mono"],
        order = 42,
        type = "toggle",
        desc = L["Render font without antialiasing."],
        set = function(info, val) SetThemeValue(info, SetFontFlags({ "settings", widget_info, "flags" }, "Mono", val)) end,
        get = function(info) return GetFontFlags({ "settings", widget_info, "flags" }, "Mono") end,
        arg = { "settings", widget_info, "flags" },
      },
      Shadow = {
        name = L["Shadow"],
        order = 43,
        type = "toggle",
        desc = L["Show shadow with text."],
        set = SetThemeValue,
        arg = { "settings", widget_info, "shadow" },
      },
    },
  }
  return entry
end

local function GetFontEntry(name, pos, widget_info)
  local entry = GetFontEntryTheme(pos, widget_info)
  entry.name = name

  return entry
end

-- Syntax for settings:
--  Font = {
--    Typeface = Addon.DEFAULT_SMALL_FONT,
--    Size = 10,
--    Transparency = 1,
--    Color = RGB(255, 255, 255),
--    flags = "OUTLINE",
--    Shadow = true,
--    HorizontalAlignment = "CENTER",
--    VerticalAlignment = "CENTER",
--  },
local function GetFontEntryDefault(name, pos, widget_info, func_disabled)
  widget_info = Addon.ConcatTables(widget_info, { "Font" } )

  -- Check if certain configuration options should be shown:
  local entry_transparency, entry_color
  if CheckIfValueExists(widget_info, { "Transparency" } ) then
    entry_transparency = GetTransparencyEntryDefault(30, Addon.ConcatTables(widget_info, { "Transparency" }) )
  end
  if CheckIfValueExists(widget_info, { "Color" } ) then
    entry_color = GetColorEntry(L["Color"], 40, Addon.ConcatTables(widget_info, { "Color" }) )
  end

  local entry = {
    type = "group",
    order = pos,
    name = name,
    inline = true,
    disabled = func_disabled,
    args = {
      Font = {
        name = L["Typeface"],
        order = 10,
        type = "select",
        dialogControl = "LSM30_Font",
        values = AceGUIWidgetLSMlists.font,
        arg = Addon.ConcatTables(widget_info, { "Typeface" }),
      },
      Size = {
        name = L["Font Size"],
        order = 20,
        type = "range",
        arg = Addon.ConcatTables(widget_info, { "Size" }),
        max = 36,
        min = 6,
        step = 1,
        isPercent = false,
      },
      Transparency = entry_transparency,
      Color = entry_color,
      Spacer = GetSpacerEntry(100),
      Outline = {
        name = L["Outline"],
        order = 101,
        type = "toggle",
        desc = L["Add black outline."],
        width = "half",
        set = function(info, val) SetValueWidget(info, SetFontFlags(Addon.ConcatTables(widget_info, { "flags" }), "Outline", val)) end,
        get = function(info) return GetFontFlags(Addon.ConcatTables(widget_info, { "flags" }), "Outline") end,
        arg = Addon.ConcatTables(widget_info, { "flags" }),
      },
      Thick = {
        name = L["Thick"],
        order = 102,
        type = "toggle",
        desc = L["Add thick black outline."],
        width = "half",
        set = function(info, val) SetValueWidget(info, SetFontFlags(Addon.ConcatTables(widget_info, { "flags" }), "Thick", val)) end,
        get = function(info) return GetFontFlags(Addon.ConcatTables(widget_info, { "flags" }), "Thick") end,
        arg = Addon.ConcatTables(widget_info, { "flags" }),
      },

      Mono = {
        name = L["Mono"],
        order = 103,
        type = "toggle",
        desc = L["Render font without antialiasing."],
        width = "half",
        set = function(info, val) SetValueWidget(info, SetFontFlags(Addon.ConcatTables(widget_info, { "flags" }), "Mono", val)) end,
        get = function(info) return GetFontFlags(Addon.ConcatTables(widget_info, { "flags" }), "Mono") end,
        arg = Addon.ConcatTables(widget_info, { "flags" }),
      },
      Shadow = {
        name = L["Shadow"],
        order = 104,
        type = "toggle",
        desc = L["Show shadow with text."],
        width = "half",
        arg = Addon.ConcatTables(widget_info, { "Shadow" }),
      },
    },
  }

  if entry_color then
    entry.args.Color.set = SetColorWidget
    entry.args.Color.width = "half"
  end

  if entry_transparency then
    entry.args.Transparency.set = function(info, val) SetValueWidget(info, abs(val - 1)) end
  end

  return entry
end

local function GetBoundariesEntry(pos, widget_info, func_disabled)
  local entry = {
    name = L["Text Boundaries"],
    order = pos,
    type = "group",
    inline = true,
    disabled = func_disabled,
    args = {
      Description = {
        type = "description",
        order = 1,
        name = L["These settings will define the space that text can be placed on the nameplate. Having too large a font and not enough height will cause the text to be not visible."],
        width = "full",
      },
      Width = { type = "range", width = "double", order = 2, name = L["Text Width"], set = SetThemeValue, arg = { "settings", widget_info, "width" }, max = 250, min = 20, step = 1, isPercent = false, },
      Height = { type = "range", width = "double", order = 3, name = L["Text Height"], set = SetThemeValue, arg = { "settings", widget_info, "height" }, max = 40, min = 8, step = 1, isPercent = false, },
    },
  }
  return entry
end

local function GetBoundariesEntryName(name, pos, widget_info, func_disabled)
  local entry = GetBoundariesEntry(pos, widget_info, func_disabled)
  entry.name = name
  return entry
end


local function AddLayoutOptions(args, pos, widget_info)
  args.Sizing = GetSizeEntryDefault(pos, widget_info)
  args.Alpha = GetTransparencyEntryWidget(pos + 10, widget_info)
  args.Placement = GetPlacementEntryWidget(pos + 20, widget_info, true)
end

local function CreateRaidMarksOptions()
  local options =  {
    name = L["Target Markers"],
    type = "group",
    order = 130,
    set = SetThemeValue,
    args = {
      Enable = {
        name = L["Enable"],
        order = 5,
        type = "group",
        inline = true,
        args = {
          Header = {
            name = L["These options allow you to control whether target marker icons are hidden or shown on nameplates and whether a nameplate's healthbar (in healthbar view) or name (in headline view) are colored based on target markers."],
            order = 1,
            type = "description",
            width = "full",
          },
          Enable = {
            name = L["Show in Healthbar View"],
            order = 2,
            type = "toggle",
            width = "double",
            arg = { "settings", "raidicon", "show" },
          },
          EnableHV = {
            name = L["Show in Headline View"],
            order = 3,
            type = "toggle",
            descStyle = "inline",
            width = "double",
            arg = {"settings", "raidicon", "ShowInHeadlineView" },
          },
          EnableHealthbarView = {
            name = L["Color Healthbar by Target Marks in Healthbar View"],
            order = 4,
            type = "toggle",
            width = "double",
            set = SetValue,
            get = GetValue,
            arg = { "settings", "raidicon", "hpColor" },
          },
          EnableHeadlineView = {
            name = L["Color Name by Target Marks in Headline View"],
            order = 5,
            type = "toggle",
            width = "double",
            set = SetValue,
            get = GetValue,
            arg = { "HeadlineView", "UseRaidMarkColoring" },
          },
        },
      },
      Layout = GetLayoutEntryTheme(10, "raidicon", true),
      Coloring = {
        name = L["Colors"],
        order = 20,
        type = "group",
        inline = true,
        get = GetColor,
        set = SetColor,
        args = {
          STAR = {
            type = "color",
            order = 30,
            name = RAID_TARGET_1,
            arg = { "settings", "raidicon", "hpMarked", "STAR" },
          },
          CIRCLE = {
            type = "color",
            order = 31,
            name = RAID_TARGET_2,
            arg = { "settings", "raidicon", "hpMarked", "CIRCLE" },
          },
          DIAMOND = {
            type = "color",
            order = 32,
            name = RAID_TARGET_3,
            arg = { "settings", "raidicon", "hpMarked", "DIAMOND" },
          },
          TRIANGLE = {
            type = "color",
            order = 33,
            name = RAID_TARGET_4,
            arg = { "settings", "raidicon", "hpMarked", "TRIANGLE" },
          },
          MOON = {
            type = "color",
            order = 34,
            name = RAID_TARGET_5,
            arg = { "settings", "raidicon", "hpMarked", "MOON" },
          },
          SQUARE = {
            type = "color",
            order = 35,
            name = RAID_TARGET_6,
            arg = { "settings", "raidicon", "hpMarked", "SQUARE" },
          },
          CROSS = {
            type = "color",
            order = 36,
            name = RAID_TARGET_7,
            arg = { "settings", "raidicon", "hpMarked", "CROSS" },
          },
          SKULL = {
            type = "color",
            order = 37,
            name = RAID_TARGET_8,
            arg = { "settings", "raidicon", "hpMarked", "SKULL" },
          },
        },
      },
    },
  }

  return options
end

local function CreateClassIconsWidgetOptions()
  local options = { name = L["Class Icon"], order = 30, type = "group",
    args = {
      Enable = GetEnableEntry(L["Enable Class Icon Widget"], L["This widget shows a class icon on the nameplates of players."], "classWidget", true, function(info, val) SetValuePlain(info, val); Addon.Widgets:InitializeWidget("ClassIcon") end),
      Options = {
        name = L["Show For"],
        type = "group",
        inline = true,
        order = 40,
--        disabled = function() return not db.classWidget.ON end,
        args = {
          FriendlyClass = {
            name = L["Friendly Units"],
            order = 1,
            type = "toggle",
            descStyle = "inline",
            width = "double",
            arg = { "friendlyClassIcon" },
          },
          HostileClass = {
            name = L["Hostile Units"],
            order = 2,
            type = "toggle",
            descStyle = "inline",
            width = "double",
            arg = { "HostileClassIcon" },
          },
--          FriendlyCaching = {
--            name = L"Friendly Caching"],
--            type = "toggle",
--            desc = L"This allows you to save friendly player class information between play sessions or nameplates going off the screen.|cffff0000(Uses more memory)"],
--            descStyle = "inline",
--            width = "full",
----            disabled = function() if not db.friendlyClassIcon or not db.classWidget.ON then return true else return false end end,
--            arg = { "cacheClass" }
--          },
        },
      },
      Textures = {
        name = L["Textures"],
        type = "group",
        inline = true,
        order = 30,
--        disabled = function() return not db.classWidget.ON end,
        args = {},
      },
      Layout = GetLayoutEntry(40, "classWidget", true),
    }
  }
  return options
end

local function CreateComboPointsWidgetOptions()
  local options = {
    name = L["Combo Points"],
    type = "group",
    order = 50,
    set = SetValueWidget,
    args = {
      Enable = GetEnableEntry(L["Enable Combo Points Widget"], L["This widget shows your combo points on your target nameplate."], "ComboPoints", true, function(info, val) SetValuePlain(info, val); Addon.Widgets:InitializeWidget("ComboPoints") end),
      Appearance = {
        name = L["Appearance"],
        type = "group",
        order = 20,
        inline = true,
        args = {
          Style = {
            name = L["Style"],
            type = "select",
            order = 10,
            values = {
              Squares = L["Squares"],
              Orbs = L["Orbs"],
              Blizzard = L["Blizzard"]
            },
            arg = { "ComboPoints", "Style" },
          },
          EmptyCPs = {
            name = L["On & Off"],
            order = 20,
            type = "toggle",
            desc = L["In combat, always show all combo points no matter if they are on or off. Off combo points are shown greyed-out."],
            arg = { "ComboPoints", "ShowOffCPs" },
          },
        },
      },
--      Preview = {
--        name = L["Preview"],
--        type = "group",
--        order = 25,
--        inline = true,
--        args = {
--          PreviewOn = {
--            name = L["On Combo Point"],
--            order = 10,
--            type = "execute",
--            image = function()
--              local texture = CreateFrame("Frame"):CreateTexture()
--              local width, height
--              if db.ComboPoints.Style == "Squares" then
--                texture:SetTexture("Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ComboPointsWidget\\ComboPointDefaultOff")
--                width, height = 64, 32
--              elseif db.ComboPoints.Style == "Orbs" then
--                texture:SetTexture("Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ComboPointsWidget\\ComboPointOrbOff")
--                width, height = 32, 32
--              else
--                texture:SetAtlas("Warlock-EmptyShard")
--                width, height = 32, 32
--              end
--              local color = db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization][1]
--              texture:SetVertexColor(color.r, color.g, color.b)
--              return texture:GetTexture(), width, height
--            end,
--            imageCoords = function()
--              if db.ComboPoints.Style == "Squares" then
--                return { 0, 62 / 128, 0, 34 / 64 }
--              elseif db.ComboPoints.Style == "Orbs" then
--                return { 2/64, 62/64, 2/64, 62/64 }
--              else
--                return { 0, 1, 0, 1 }
--              end
--            end,
--          },
--          PreviewOffCP = {
--            name = L["Off Combo Point"],
--            order = 20,
--            type = "execute",
--            image = function()
--              local texture = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ComboPointsWidget\\"
--              if db.ComboPoints.Style == "Squares" then
--                return texture .. "ComboPointDefaultOff", 64, 32
--              elseif db.ComboPoints.Style == "Orbs" then
--                  return texture .. "ComboPointOrbOff", 32, 32
--              else
--                local texture_frame = CreateFrame("Frame"):CreateTexture()
--                texture_frame:SetAtlas("Warlock-EmptyShard")
--                print(texture_frame:GetTexCoord())
--                return texture_frame:GetTexture()
--              end
--            end,
--            imageCoords = function()
--              if db.ComboPoints.Style == "Squares" then
--                return { 0, 62 / 128, 0, 34 / 64 }
--              elseif db.ComboPoints.Style == "Orbs" then
--                return { 2/64, 62/64, 2/64, 62/64 }
--              else
--                return { 0, 1, 0, 1 }
--              end
--            end,
--          },
--        },
--      },
      Coloring = {
        name = L["Coloring"],
        type = "group",
        order = 40,
        inline = true,
        args = {
          ClassAndSpec = {
            name = L["Specialization"],
            type = "select",
            order = 10,
            values = {
              --DEATHKNIGHT = L["Death Knight"],
              DRUID = L["Druid"],
              MAGE = L["Arcane Mage"],
              --MONK = L["Windwalker Monk"],
              --PALADIN = L["Retribution Paladin"],
              ROGUE = L["Rogue"],
              WARLOCK = L["Warlock"],
            },
            arg = { "ComboPoints", "Specialization" },
          },
          SameColor = {
            name = L["Uniform Color"],
            order = 20,
            type = "toggle",
            desc = L["Use the same color for all combo points shown."],
            arg = { "ComboPoints", "UseUniformColor" },
          },
          Spacer1 = GetSpacerEntry(100),
          Color1CP = {
            name = L["One"],
            type = "color",
            order = 110,
            get = function(info)
              local color = db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization][1]
              return color.r, color.g, color.b
            end,
            set = function(info, r, g, b)
              db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization][1] = t.RGB(r * 255, g * 255, b * 255)
              Addon.Widgets:UpdateSettings(MAP_OPTION_TO_WIDGET[info[2]])
            end,
            hasAlpha = false,
          },
          Color2CP = {
            name = L["Two"],
            type = "color",
            order = 120,
            get = function(info)
              local color = db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization][2]
              return color.r, color.g, color.b
            end,
            set = function(info, r, g, b)
              db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization][2] = t.RGB(r * 255, g * 255, b * 255)
              Addon.Widgets:UpdateSettings(MAP_OPTION_TO_WIDGET[info[2]])
            end,
            hasAlpha = false,
          },
          Color3CP = {
            name = L["Three"],
            type = "color",
            order = 130,
            get = function(info)
              local color = db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization][3]
              return color.r, color.g, color.b
            end,
            set = function(info, r, g, b)
              db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization][3] = t.RGB(r * 255, g * 255, b * 255)
              Addon.Widgets:UpdateSettings(MAP_OPTION_TO_WIDGET[info[2]])
            end,
            hasAlpha = false,
          },
          Color4CP = {
            name = L["Four"],
            type = "color",
            order = 140,
            get = function(info)
              local color = db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization][4]
              return color.r, color.g, color.b
            end,
            set = function(info, r, g, b)
              db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization][4] = t.RGB(r * 255, g * 255, b * 255)
              Addon.Widgets:UpdateSettings(MAP_OPTION_TO_WIDGET[info[2]])
            end,
            hasAlpha = false,
          },
          Color5CP = {
            name = L["Five"],
            type = "color",
            order = 150,
            get = function(info)
              local color = db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization][5] or t.RGB(0, 0, 0)
              return color.r, color.g, color.b
            end,
            set = function(info, r, g, b)
              db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization][5] = t.RGB(r * 255, g * 255, b * 255)
              Addon.Widgets:UpdateSettings(MAP_OPTION_TO_WIDGET[info[2]])
            end,
            hasAlpha = false,
            disabled = function() return #db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization] < 5 end
          },
          Color6CP = {
            name = L["Six"],
            type = "color",
            order = 160,
            get = function(info)
              local color = db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization][6] or t.RGB(0, 0, 0)
              return color.r, color.g, color.b
            end,
            set = function(info, r, g, b)
              db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization][6] = t.RGB(r * 255, g * 255, b * 255)
              Addon.Widgets:UpdateSettings(MAP_OPTION_TO_WIDGET[info[2]])
            end,
            hasAlpha = false,
            disabled = function() return #db.ComboPoints.ColorBySpec[db.ComboPoints.Specialization] < 6 end
          },
        },
      },
      Layout = {
        name = L["Layout"],
        order = 60,
        type = "group",
        inline = true,
        args = {
          SpacingX = {
            name = L["Spacing"],
            order = 10,
            type = "range",
            min = 0,
            max = 100,
            step = 1,
            arg = { "ComboPoints", "HorizontalSpacing" },
          },
          Scale = GetScaleEntry(L["Scale"], 20, { "ComboPoints", "Scale" }),
          Transparency = GetTransparencyEntryWidgetNew(30, { "ComboPoints", "Transparency" } ),
          Placement = GetPlacementEntryWidget(40, "ComboPoints", true),
        },
      },
      DKRuneCooldown= {
        name = L["Death Knigh Rune Cooldown"],
        order = 70,
        type = "group",
        inline = true,
        args = {
          Enable = {
            name = L["Enable"],
            order = 10,
            type = "toggle",
            arg = { "ComboPoints", "RuneCooldown", "Show" },
          },
          Font = GetFontEntryDefault(L["Font"], 20, { "ComboPoints", "RuneCooldown" } )
        },
      },
    },
  }

  return options
end

local function CreateArenaWidgetOptions()
  local options = {
    name = L["Arena"],
    type = "group",
    order = 10,
    set = SetValueWidget,
    args = {
      Enable = GetEnableEntry(L["Enable Arena Widget"], L["This widget shows various icons (orbs and numbers) on enemy nameplates in arenas for easier differentiation."], "arenaWidget", false, function(info, val) SetValuePlain(info, val); Addon.Widgets:InitializeWidget("Arena") end),
      Orbs = {
        name = L["Arena Orb"],
        type = "group",
        inline = true,
        order = 10,
        args = {
          EnableOrbs = {
            name = L["Show Orb"],
            order = 10,
            type = "toggle",
            arg = { "arenaWidget", "ShowOrb" } ,
          },
          Size = GetSizeEntryDefault(20, "arenaWidget" ),
          Colors = {
            name = L["Colors"],
            type = "group",
            inline = true,
            order = 30,
            get = GetColorAlpha,
            set = SetColorAlpha,
            --                  disabled = function() return not db.arenaWidget.ON end,
            args = {
              Arena1 = {
                name = L["Arena 1"],
                type = "color",
                order = 1,
                hasAlpha = true,
                arg = { "arenaWidget", "colors", 1 },
              },
              Arena2 = {
                name = L["Arena 2"],
                type = "color",
                order = 2,
                hasAlpha = true,
                arg = { "arenaWidget", "colors", 2 },
              },
              Arena3 = {
                name = L["Arena 3"],
                type = "color",
                order = 3,
                hasAlpha = true,
                arg = { "arenaWidget", "colors", 3 },
              },
              Arena4 = {
                name = L["Arena 4"],
                type = "color",
                order = 4,
                hasAlpha = true,
                arg = { "arenaWidget", "colors", 4 },
              },
              Arena5 = {
                name = L["Arena 5"],
                type = "color",
                order = 5,
                hasAlpha = true,
                arg = { "arenaWidget", "colors", 5 },
              },
            },
          },
        },
      },
      Numbers = {
        name = L["Arena Number"],
        type = "group",
        inline = true,
        order = 20,
        args = {
          EnableNumbers = {
            name = L["Show Number"],
            order = 10,
            type = "toggle",
            arg = {"arenaWidget", "ShowNumber"},
          },
          HideUnitName = {
            name = L["Hide Name"],
            order = 20,
            type = "toggle",
            arg = {"arenaWidget", "HideName"},
          },
          Font = GetFontEntryDefault(L["Font"], 30, { "arenaWidget", "NumberText" }),
          Placement = {
            type = "group",
            order = 35,
            name = L["Placement"],
            inline = true,
            args = {
              Anchor = {
                type = "select",
                order = 10,
                name = L["Anchor Point"],
                values = Addon.ANCHOR_POINT,
                arg = { "arenaWidget", "NumberText", "Anchor" }
              },
              InsideAnchor = {
                type = "toggle",
                order = 15,
                name = L["Inside"],
                width = "half",
                arg = { "arenaWidget", "NumberText", "InsideAnchor" }
              },
              X = {
                type = "range",
                order = 20,
                name = L["Horizontal Offset"],
                max = 120,
                min = -120,
                step = 1,
                isPercent = false,
                arg = { "arenaWidget", "NumberText", "HorizontalOffset" },
              },
              Y = {
                type = "range",
                order = 30,
                name = L["Vertical Offset"],
                max = 120,
                min = -120,
                step = 1,
                isPercent = false,
                arg = { "arenaWidget", "NumberText", "VerticalOffset" },
              },
              AlignX = {
                type = "select",
                order = 40,
                name = L["Horizontal Align"],
                values = t.AlignH,
                arg = { "arenaWidget", "NumberText", "Font", "HorizontalAlignment" },
              },
              AlignY = {
                type = "select",
                order = 50,
                name = L["Vertical Align"],
                values = t.AlignV,
                arg = { "arenaWidget", "NumberText", "Font", "VerticalAlignment" },
              },
            },
          },
          numColors = {
            name = L["Colors"],
            type = "group",
            inline = true,
            order = 40,
            get = GetColorAlpha,
            set = SetColorAlpha,
            --                  disabled = function() return not db.arenaWidget.ON end,
            args = {
              Arena1 = {
                name = L["Arena 1"],
                type = "color",
                order = 1,
                hasAlpha = true,
                arg = { "arenaWidget", "numColors", 1 },
              },
              Arena2 = {
                name = L["Arena 2"],
                type = "color",
                order = 2,
                hasAlpha = true,
                arg = { "arenaWidget", "numColors", 2 },
              },
              Arena3 = {
                name = L["Arena 3"],
                type = "color",
                order = 3,
                hasAlpha = true,
                arg = { "arenaWidget", "numColors", 3 },
              },
              Arena4 = {
                name = L["Arena 4"],
                type = "color",
                order = 4,
                hasAlpha = true,
                arg = { "arenaWidget", "numColors", 4 },
              },
              Arena5 = {
                name = L["Arena 5"],
                type = "color",
                order = 5,
                hasAlpha = true,
                arg = { "arenaWidget", "numColors", 5 },
              },
            },
          },
        },
      },
      Placement = GetPlacementEntryWidget(60, "arenaWidget", false),
    },
  }

  return options
end

local function CreateQuestWidgetOptions()
  local options =  {
    name = L["Quest"],
    order = 100,
    type = "group",
    args = {
      Enable = GetEnableEntry(L["Enable Quest Widget"], L["This widget shows a quest icon above unit nameplates or colors the nameplate healthbar of units that are involved with any of your current quests."], "questWidget", true,
        function(info, val)
          SetValue(info, val) -- SetValue because nameplate healthbars must be updated (if healthbar mode is enabled)
          if db.questWidget.ON or db.questWidget.ShowInHeadlineView then
            SetCVar("showQuestTrackingTooltips", 1)
          end
          Addon.Widgets:InitializeWidget("Quest")
        end),
      Visibility = { type = "group",	order = 10,	name = L["Visibility"], inline = true,
--        disabled = function() return not db.questWidget.ON end,
        args = {
          InCombatAll = { type = "toggle", order = 10, name = L["Hide in Combat"],	arg = {"questWidget", "HideInCombat"}, },
          InCombatAttacked = { type = "toggle", order = 20, name = L["Hide on Attacked Units"],	arg = {"questWidget", "HideInCombatAttacked"}, },
          InInstance = { type = "toggle", order = 30, name = L["Hide in Instance"],	arg = {"questWidget", "HideInInstance"}, },
          ShowQuestProgress = { name = L["Quest Progress"], order = 10, type = "toggle", arg = {"questWidget", "ShowProgress"}, desc = L["Show the amount you need to loot or kill"] },
        },
      },
      ModeHealthBar = {
        name = L["Healthbar Mode"], order = 20, type = "group", inline = true,
--        disabled = function() return not db.questWidget.ON end,
        args = {
          Help = {
            type = "description",
            order = 0,
            width = "full",
            name = L["Use a custom color for the healthbar of quest mobs."],
          },
          Enable = { type = "toggle", order = 10, name = L["Enable"],	arg = {"questWidget", "ModeHPBar"}, },
          Color = {
            name = L["Color"], type = "color", desc = "", descStyle = "inline", width = "half",
            get = GetColor, set = SetColor, arg = {"questWidget", "HPBarColor"},
            order = 20,
--            disabled = function() return not db.questWidget.ModeHPBar end,
          },
        },
      },
      ModeIcon = {
        name = L["Icon Mode"], order = 301, type = "group", inline = true,
--        disabled = function() return not db.questWidget.ON end,
        args = {
          Help = { type = "description", order = 0,	width = "full",	name = L["Show an quest icon at the nameplate for quest mobs."],	},
          Enable = {
            name = L["Enable"],
            order = 10,
            type = "toggle",
            width = "half",
            arg = {"questWidget", "ModeIcon"},
          },
          Texture = {
            name = L["Symbol"],
            type = "group",
            inline = true,
            args = {
              Select = {
                name = L["Style"],
                type = "select",
                order = 10,
                set = function(info, val)
                  SetValue(info, val)
                  options.args.Widgets.args.QuestWidget.args.ModeIcon.args.Texture.args.Preview.image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\QuestWidget\\" .. db.questWidget.IconTexture;
                end,
                values = { QUESTICON = L["Blizzard"], SKULL = L["Skull"] },
                arg = { "questWidget", "IconTexture" },
              },
              Preview = {
                name = L["Preview"],
                order = 20,
                type = "execute",
                image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\QuestWidget\\" .. db.questWidget.IconTexture,
              },
              PlayerColor = {
                name = L["Color"],
                order = 30,
                type = "color",
                get = GetColor,
                set = SetColor,
                arg = {"questWidget", "ColorPlayerQuest"},
                --desc = L["Your own quests that you have to complete."],
              },
            },
          },
        },
      },
    },
  }
  AddLayoutOptions(options.args.ModeIcon.args, 20, "questWidget")
  return options
end

local function CreateStealthWidgetOptions()
  local options =  {
    name = L["Stealth"],
    order = 80,
    type = "group",
    args = {
      Enable = GetEnableEntry(L["Enable Stealth Widget"], L["This widget shows a stealth icon on nameplates of units that can detect stealth."], "stealthWidget", true, function(info, val) SetValuePlain(info, val); Addon.Widgets:InitializeWidget("Stealth") end),
      Layout = {
        name = L["Layout"],
        order = 10,
        type = "group",
        inline = true,
        args = {},
      }
    },
  }
  AddLayoutOptions(options.args.Layout.args, 80, "stealthWidget")
  return options
end

local function CreateHealerTrackerWidgetOptions()
  local options =  {
    name = L["Healer Tracker"],
    order = 60,
    type = "group",
    args = {
      Enable = GetEnableEntry(L["Enable Healer Tracker Widget"], L["This widget shows players that are healers."], "healerTracker", true, function(info, val) SetValuePlain(info, val); Addon.Widgets:InitializeWidget("HealerTracker") end),
      Layout = {
        name = L["Layout"],
        order = 10,
        type = "group",
        inline = true,
        args = {},
      }
    },
  }

  AddLayoutOptions(options.args.Layout.args, 80, "healerTracker")
  return options
end

local function CreateTargetArtWidgetOptions()
  local options = {
    name = L["Target Highlight"],
    type = "group",
    order = 90,
    args = {
      Enable = GetEnableEntry(L["Enable Target Highlight Widget"], L["This widget highlights the nameplate of your current target by showing a border around the healthbar and by coloring the nameplate's healtbar and/or name with a custom color."], "targetWidget", false, function(info, val) SetValuePlain(info, val); Addon.Widgets:InitializeWidget("TargetArt") end),
      Texture = {
        name = L["Texture"],
        order = 10,
        type = "group",
        inline = true,
        args = {
          Preview = {
            name = L["Preview"],
            order = 10,
            type = "execute",
            image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\TargetArtWidget\\" .. db.targetWidget.theme,
            imageWidth = 128,
            imageHeight = 32,
          },
          Select = {
            name = L["Style"],
            type = "select",
            order = 20,
            set = function(info, val)
              SetValueWidget(info, val)
              options.args.Widgets.args.TargetArtWidget.args.Texture.args.Preview.image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\TargetArtWidget\\" .. db.targetWidget.theme;
            end,
            values = { default = "Default", squarethin = "Thin Square", arrows = "Arrows", crescent = "Crescent", bubble = "Bubble" },
            arg = { "targetWidget", "theme" },
          },
          Color = {
            name = L["Color"],
            type = "color",
            order = 30,
            width = "half",
            get = GetColorAlpha,
            set = SetColorAlphaWidget,
            hasAlpha = true,
            arg = { "targetWidget" },
          },
        },
      },
      TargetColor = {
        name = L["Nameplate Color"],
        order = 20,
        type = "group",
        inline = true,
        args = {
          TargetColor = {
            name = L["Color"],
            order = 10,
            type = "color",
            get = GetColor,
            set = SetColorWidget,
            arg = {"targetWidget", "HPBarColor"},
          },
          EnableHealthbar = {
            name = L["Healthbar"],
            desc = L["Use a custom color for the healthbar of your current target."],
            order = 20,
            type = "toggle",
            arg = {"targetWidget", "ModeHPBar"},
          },
          EnableName = {
            name = L["Name"],
            desc = L["Use a custom color for the name of your current target (in healthbar view and in headline view)."],
            order = 30,
            type = "toggle",
            arg = {"targetWidget", "ModeNames"},
          },
        },
      },
    },
  }

  return options
end

local function CreateSocialWidgetOptions()
  local options = {
    name = L["Social"],
    type = "group",
    order = 70,
    args = {
      Enable = GetEnableEntry(L["Enable Social Widget"], L["This widget shows icons for friends, guild members, and faction on nameplates."], "socialWidget", true, function(info, val) SetValuePlain(info, val); Addon.Widgets:InitializeWidget("Social") end),
      Friends = {
        name = L["Friends & Guild Members"],
        order = 10,
        type = "group",
        inline = true,
        args = {
          ModeIcon = {
            name = L["Icon Mode"],
            order = 10,
            type = "group",
            inline = true,
            args = {
              Show = {
                name = L["Enable"],
                order = 5,
                type = "toggle",
                width = "half",
                desc = L["Shows an icon for friends and guild members next to the nameplate of players."],
                set = function(info, val) SetValuePlain(info, val); Addon.Widgets:InitializeWidget("Social") end,
                arg = { "socialWidget", "ShowFriendIcon" },
                --disabled = function() return not (db.socialWidget.ON or db.socialWidget.ShowInHeadlineView) end,
              },
              Size = GetSizeEntryDefault(10, "socialWidget"),
              --Anchor = GetAnchorEntry(20, "socialWidget"),
              Offset = GetPlacementEntryWidget(30, "socialWidget", true),
            },
          },
          ModeHealthBar = {
            name = L["Healthbar Mode"],
            order = 20,
            type = "group",
            inline = true,
            args = {
              Help = { type = "description", order = 0,	width = "full",	name = L["Use a custom color for healthbar (in healthbar view) or name (in headline view) of friends and/or guild members."],	},
              EnableFriends = {
                name = L["Enable Friends"],
                order = 10,
                type = "toggle",
                arg = {"socialWidget", "ShowFriendColor"},
              },
              ColorFriends = {
                name = L["Color"],
                order = 20,
                type = "color",
                get = GetColor,
                set = SetColor,
                arg = {"socialWidget", "FriendColor"},
              },
              EnableGuildmates = {
                name = L["Enable Guild Members"],
                order = 30,
                type = "toggle",
                arg = {"socialWidget", "ShowGuildmateColor"},
              },
              ColorGuildmates = {
                name = L["Color"],
                order = 40,
                type = "color",
                get = GetColor,
                set = SetColor,
                arg = {"socialWidget", "GuildmateColor"},
              },
            },
          },
        },
      },
      Faction = {
        name = L["Faction Icon"],
        order = 20,
        type = "group",
        inline = true,
        args = {
          Show = {
            name = L["Enable"],
            order = 5,
            type = "toggle",
            width = "half",
            desc = L["Shows a faction icon next to the nameplate of players."],
            arg = { "socialWidget", "ShowFactionIcon" },
            --                      disabled = function() return not (db.socialWidget.ON or db.socialWidget.ShowInHeadlineView) end,
          },
          Size = GetSizeEntryDefault(10, "FactionWidget"),
          Offset = GetPlacementEntryWidget(30, "FactionWidget", true),
        },
      },
    },
  }

  return options
end

local function CreateResourceWidgetOptions()
  local options = {
    name = L["Resource"],
    type = "group",
    order = 60,
    set = SetValueWidget,
    args = {
      Enable = GetEnableEntry(L["Enable Resource Widget"], L["This widget shows information about your target's resource on your target nameplate. The resource bar's color is derived from the type of resource automatically."], "ResourceWidget", false, function(info, val) SetValuePlain(info, val); Addon.Widgets:InitializeWidget("Resource") end),
      ShowFor = {
        name = L["Show For"],
        order = 10,
        type = "group",
        inline = true,
        args = {
          ShowFriendly = {
            name = L["Friendly Units"],
            order = 10,
            type = "toggle",
            arg = { "ResourceWidget", "ShowFriendly" },
          },
          ShowEnemyPlayers = {
            name = L["Enemy Players"],
            order = 20,
            type = "toggle",
            arg = { "ResourceWidget", "ShowEnemyPlayer" },
          },
          ShowEnemyNPCs = {
            name = L["Enemy NPCs"],
            order = 30,
            order = 30,
            type = "toggle",
            arg = { "ResourceWidget", "ShowEnemyNPC" },
          },
          ShowBigUnits = {
            name = L["Rares & Bosses"],
            order = 40,
            type = "toggle",
            desc = L["Shows resource information for bosses and rares."],
            arg = { "ResourceWidget", "ShowEnemyBoss" },
          },
          ShowOnlyAlternatePower = {
            name = L["Only Alternate Power"],
            order = 50,
            type = "toggle",
            desc = L["Shows resource information only for alternatve power (of bosses or rares, mostly)."],
            arg = { "ResourceWidget", "ShowOnlyAltPower" },
          },
        },
      },
      Bar = {
        name = L["Resource Bar"],
        order = 20,
        type = "group",
        inline = true,
        args = {
          Show = {
            name = L["Enable"],
            order = 5,
            type = "toggle",
            arg = { "ResourceWidget", "ShowBar" },
          },
          BarTexture = {
            name = L["Foreground Texture"],
            order = 10,
            type = "select",
            dialogControl = "LSM30_Statusbar",
            values = AceGUIWidgetLSMlists.statusbar,
            arg = { "ResourceWidget", "BarTexture" },
          },
          BarWidth = { name = L["Bar Width"], order = 20, type = "range", min = 1, max = 500, step = 1, arg = { "ResourceWidget", "BarWidth" }, },
          BarHeight = { name = L["Bar Height"], order = 30, type = "range", min = 1, max = 500, step = 1, arg = { "ResourceWidget", "BarHeight" }, },
          Spacer0 = GetSpacerEntry(70),
          BorderTexture = {
            name = L["Bar Border"],
            order = 80,
            type = "select",
            dialogControl = "LSM30_Border",
            values = AceGUIWidgetLSMlists.border,
            arg = { "ResourceWidget", "BorderTexture" },
          },
          BorderEdgeSize = {
            name = L["Edge Size"],
            order = 90,
            type = "range",
            min = 0, max = 32, step = 1,
            arg = { "ResourceWidget", "BorderEdgeSize" },
          },
          BorderOffset = {
            name = L["Offset"],
            order = 100,
            type = "range",
            min = -16, max = 16, step = 1,
            arg = { "ResourceWidget", "BorderOffset" },
          },
          Spacer1 = GetSpacerEntry(200),
          BGColorText = {
            type = "description",
            order = 210,
            width = "single",
            name = L["Background Color:"],
          },
          BGColorForegroundToggle = {
            name = L["Same as Foreground"],
            order = 220,
            type = "toggle",
            desc = L["Use the healthbar's foreground color also for the background."],
            arg = { "ResourceWidget", "BackgroundUseForegroundColor" },
          },
          BGColorCustomToggle = {
            name = L["Custom"],
            order = 230,
            type = "toggle",
            width = "half",
            desc = L["Use a custom color for the healtbar's background."],
            set = function(info, val) SetValueWidget(info, not val) end,
            get = function(info, val) return not GetValue(info, val) end,
            arg = { "ResourceWidget", "BackgroundUseForegroundColor" },
          },
          BGColorCustom = {
            name = L["Color"],
            type = "color",
            order = 235,
            get = GetColorAlpha,
            set = SetColorAlphaWidget,
            hasAlpha = true,
            arg = {"ResourceWidget", "BackgroundColor"},
            width = "half",
          },
          Spacer2 = GetSpacerEntry(300),
          BorderolorText = {
            type = "description",
            order = 310,
            width = "single",
            name = L["Border Color:"],
          },
          BorderColorForegroundToggle = {
            name = L["Same as Foreground"],
            order = 320,
            type = "toggle",
            desc = L["Use the healthbar's foreground color also for the border."],
            set = function(info, val)
              if val then
                db.ResourceWidget.BorderUseBackgroundColor = false
                SetValueWidget(info, val);
              else
                db.ResourceWidget.BorderUseBackgroundColor = false
                SetValueWidget(info, val);
              end
            end,
            --get = function(info, val) return not (db.ResourceWidget.BorderUseForegroundColor or db.ResourceWidget.BorderUseBackgroundColor) end,
            arg = { "ResourceWidget", "BorderUseForegroundColor" },
          },
          BorderColorBackgroundToggle = {
            name = L["Same as Background"],
            order = 325,
            type = "toggle",
            desc = L["Use the healthbar's background color also for the border."],
            set = function(info, val)
              if val then
                db.ResourceWidget.BorderUseForegroundColor = false
                SetValueWidget(info, val);
              else
                db.ResourceWidget.BorderUseForegroundColor = false
                SetValueWidget(info, val);
              end
            end,
            arg = { "ResourceWidget", "BorderUseBackgroundColor" },
          },
          BorderColorCustomToggle = {
            name = L["Custom"],
            order = 330,
            type = "toggle",
            width = "half",
            desc = L["Use a custom color for the healtbar's border."],
            set = function(info, val) db.ResourceWidget.BorderUseForegroundColor = false; db.ResourceWidget.BorderUseBackgroundColor = false; Addon:ForceUpdate() end,
            get = function(info, val) return not (db.ResourceWidget.BorderUseForegroundColor or db.ResourceWidget.BorderUseBackgroundColor) end,
            arg = { "ResourceWidget", "BackgroundUseForegroundColor" },
          },
          BorderColorCustom = {
            name = L["Color"],
            type = "color",
            order = 335,
            get = GetColorAlpha,
            set = SetColorAlphaWidget,
            hasAlpha = true,
            arg = {"ResourceWidget", "BorderColor"},
            width = "half",
          },
        },
      },
      Text = {
        name = L["Resource Text"],
        order = 30,
        type = "group",
        inline = true,
        args = {
          Show = {
            name = L["Enable"],
            order = 5,
            type = "toggle",
            width = "half",
            arg = { "ResourceWidget", "ShowText" },
          },
          Font = { name = L["Typeface"], type = "select", order = 10, dialogControl = "LSM30_Font", values = AceGUIWidgetLSMlists.font, arg = { "ResourceWidget", "Font" }, },
          FontSize = { name = L["Size"], order = 20, type = "range", min = 1, max = 36, step = 1, arg = { "ResourceWidget", "FontSize" }, },
          FontColor = {	name = L["Color"], type = "color",	order = 30,	get = GetColor,	set = SetColorWidget,	arg = {"ResourceWidget", "FontColor"},	hasAlpha = false, },
        },
      },
      Placement = GetPlacementEntryWidget(40, "ResourceWidget"),
    },
  }

  return options
end

local function CreateBossModsWidgetOptions()
  local entry = {
    name = L["Boss Mods"],
    type = "group",
    order = 30,
    args = {
      Enable = GetEnableEntry(L["Enable Boss Mods Widget"], L["This widget shows auras from boss mods on your nameplates (since patch 7.2, hostile nameplates only in instances and raids)."], "BossModsWidget", true, function(info, val) SetValuePlain(info, val); Addon.Widgets:InitializeWidget("BossMods") end),
      Aura = {
        name = L["Aura Icon"],
        type = "group",
        order = 10,
        inline = true,
        args = {
          Font = {
            name = L["Font"],
            type = "group",
            order = 10,
            inline = true,
            args = {
              Font = { name = L["Typeface"], type = "select", order = 10, dialogControl = "LSM30_Font", values = AceGUIWidgetLSMlists.font, arg = { "BossModsWidget", "Font" }, },
              FontSize = { name = L["Size"], order = 20, type = "range", min = 1, max = 36, step = 1, arg = { "BossModsWidget", "FontSize" }, },
              FontColor = {	name = L["Color"], type = "color",	order = 30,	get = GetColor,	set = SetColorWidget,	arg = {"BossModsWidget", "FontColor"},	hasAlpha = false, },
            },
          },
          Layout = {
            name = L["Layout"],
            order = 20,
            type = "group",
            inline = true,
            args = {
              Size = GetSizeEntry(L["Size"], 10, {"BossModsWidget",  "scale" } ),
              Spacing = { name = L["Spacing"], order = 20, type = "range", min = 0, max = 100, step = 1, arg = { "BossModsWidget", "AuraSpacing" }, },
            },
          } ,
        },
      },
      Placement = GetPlacementEntryWidget(30, "BossModsWidget", true),
      Config = {
        name = L["Configuration Mode"],
        order = 40,
        type = "group",
        inline = true,
        args = {
          Toggle = {
            name = L["Toggle on Target"],
            type = "execute",
            order = 1,
            width = "full",
            func = function() Addon:ConfigBossModsWidget() end,
          },
        },
      },
    },
  }

  return entry
end

local function CreateAurasWidgetOptions()
  local options = {
    name = L["Auras"],
    type = "group",
    childGroups = "tab",
    order = 25,
    set = SetValueWidget,
    args = {
      Enable = GetEnableEntry(L["Enable Auras Widget"], L["This widget shows a unit's auras (buffs and debuffs) on its nameplate."], "AuraWidget", true, function(info, val) SetValuePlain(info, val); Addon.Widgets:InitializeWidget("Auras") end),
      Style = {
        name = L["Appearance"],
        order = 10,
        type = "group",
        inline = false,
        args = {
          Style = {
            type = "group",
            order = 10,
            name = L["Auras"],
            inline = true,
            args = {
              TargetOnly = {
                name = L["Target Only"],
                type = "toggle",
                order = 10,
                desc = L["This will toggle the auras widget to only show for your current target."],
                arg = { "AuraWidget", "ShowTargetOnly" },
              },
              CooldownSpiral = {
                name = L["Cooldown Spiral"],
                type = "toggle",
                order = 20,
                desc = L["This will toggle the auras widget to show the cooldown spiral on auras."],
                arg = { "AuraWidget", "ShowCooldownSpiral" },
              },
              Time = {
                name = L["Duration"],
                type = "toggle",
                order = 30,
                desc = L["Show time left on auras that have a duration."],
                arg = { "AuraWidget", "ShowDuration" },
                disabled = function() return db.AuraWidget.ShowOmniCC end
              },
              OmniCC = {
                name = L["OmniCC"],
                type = "toggle",
                order = 35,
                desc = L["Show the OmniCC cooldown count instead of the built-in duration text on auras."],
                arg = { "AuraWidget", "ShowOmniCC" },
              },
              Stacks = {
                name = L["Stack Count"],
                type = "toggle",
                order = 40,
                desc = L["Show stack count on auras."],
                arg = { "AuraWidget", "ShowStackCount" },
              },
              Tooltips = {
                name = L["Tooltips"],
                type = "toggle",
                order = 43,
                desc = L["Show a tooltip when hovering above an aura."],
                arg = { "AuraWidget", "ShowTooltips" },
              },
--              Spacer1 = GetSpacerEntry(45),
--              AuraTypeColors = {
--                name = L["Color by Dispel Type"],
--                type = "toggle",
--                order = 50,
--                desc = L["This will color the aura based on its type (poison, disease, magic, curse) - for Icon Mode the icon border is colored, for Bar Mode the bar itself."],
--                arg = { "AuraWidget", "ShowAuraType" },
--              },
--              DefaultBuffColor = {
--                name = L["Buff Color"], type = "color",	order = 54,	arg = {"AuraWidget", "DefaultBuffColor"},	hasAlpha = true,
--                set = SetColorAlphaWidget,
--                get = GetColorAlpha,
--              },
--              DefaultDebuffColor = {
--                name = L["Debuff Color"], type = "color",	order = 56, arg = {"AuraWidget","DefaultDebuffColor"},	hasAlpha = true,
--                set = SetColorAlphaWidget,
--                get = GetColorAlpha,
--              },
            },
          },
          Highlight = {
            type = "group",
            order = 15,
            name = L["Highlight"],
            inline = true,
            args = {
              AuraTypeColors = {
                name = L["Dispel Type"],
                type = "toggle",
                order = 10,
                desc = L["This will color the aura based on its type (poison, disease, magic, curse) - for Icon Mode the icon border is colored, for Bar Mode the bar itself."],
                arg = { "AuraWidget", "ShowAuraType" },
              },
              DefaultBuffColor = {
                name = L["Buff Color"],
                type = "color",
                order = 20,
                arg = {"AuraWidget", "DefaultBuffColor"},
                hasAlpha = true,
                set = SetColorAlphaWidget,
                get = GetColorAlpha,
              },
              DefaultDebuffColor = {
                name = L["Debuff Color"],
                type = "color",
                order = 30,
                arg = {"AuraWidget","DefaultDebuffColor"},
                hasAlpha = true,
                set = SetColorAlphaWidget,
                get = GetColorAlpha,
              },
              Spacer1 = GetSpacerEntry(35),
              EnableGlow = {
                name = L["Steal or Purge Glow"],
                type = "toggle",
                order = 40,
                desc = L["Shows a glow effect on auras that you can steal or purge."],
                arg = { "AuraWidget", "Highlight", "Enabled" },
              },
              GlowType = {
                name = L["Glow Type"],
                type = "select",
                values = Addon.GLOW_TYPES,
                order = 50,
                arg = { "AuraWidget", "Highlight", "Type" },
              },
              GlowColorEnable = {
                name = L["Glow Color"],
                type = "toggle",
                order = 60,
                arg = { "AuraWidget", "Highlight", "CustomColor" },
              },
              GlowColor = {
                name = L["Color"],
                type = "color",
                order = 70,
                arg = {"AuraWidget", "Highlight", "Color" },
                hasAlpha = true,
                set = SetColorAlphaWidget,
                get = GetColorAlpha,
              },
            },
          },
          SortOrder = {
            type = "group",
            order = 20,
            name = L["Sort Order"],
            inline = true,
            args = {
              NoSorting = {
                name = L["None"], type = "toggle",	order = 0,	 width = "half",
                desc = L["Do not sort auras."],
                get = function(info) return db.AuraWidget.SortOrder == "None" end,
                set = function(info, value) SetValueWidget(info, "None") end,
                arg = {"AuraWidget","SortOrder"},
              },
              AtoZ = {
                name = L["A to Z"], type = "toggle",	order = 10, width = "half",
                desc = L["Sort in ascending alphabetical order."],
                get = function(info) return db.AuraWidget.SortOrder == "AtoZ" end,
                set = function(info, value) SetValueWidget(info, "AtoZ") end,
                arg = {"AuraWidget","SortOrder"},
              },
              TimeLeft = {
                name = L["Time Left"], type = "toggle",	order = 20,	 width = "half",
                desc = L["Sort by time left in ascending order."],
                get = function(info) return db.AuraWidget.SortOrder == "TimeLeft" end,
                set = function(info, value) SetValueWidget(info, "TimeLeft") end,
                arg = {"AuraWidget","SortOrder"},
              },
              Duration = {
                name = L["Duration"], type = "toggle",	order = 30,	 width = "half",
                desc = L["Sort by overall duration in ascending order."],
                get = function(info) return db.AuraWidget.SortOrder == "Duration" end,
                set = function(info, value) SetValueWidget(info, "Duration") end,
                arg = {"AuraWidget","SortOrder"},
              },
              Creation = {
                name = L["Creation"], type = "toggle",	order = 40,	 width = "half",
                desc = L["Show auras in order created with oldest aura first."],
                get = function(info) return db.AuraWidget.SortOrder == "Creation" end,
                set = function(info, value) SetValueWidget(info, "Creation") end,
                arg = {"AuraWidget","SortOrder"},
              },
              ReverseOrder = {
                name = L["Reverse"], type = "toggle",	order = 50,
                desc = L['Reverse the sort order (e.g., "A to Z" becomes "Z to A").'],
                arg = { "AuraWidget", "SortReverse" }
              },
            },
          },
          Layout = {
            type = "group",
            order = 30,
            name = L["Layout"],
            inline = true,
            args = {
              Layering = {
                name = L["Frame Order"],
                order = 10,
                type = "select",
                values = { HEALTHBAR_AURAS = L["Healthbar, Auras"], AURAS_HEALTHBAR = L["Auras, Healthbar"] },
                arg = { "AuraWidget", "FrameOrder" },
              },
              Scale = {
                name = L["Scale"],
                type = "group",
                inline = true,
                order = 20,
                args = {
                  ScaleDebuffs = GetScaleEntry(L["Debuffs"], 10, { "AuraWidget", "Debuffs", "Scale", }),
                  ScaleBuffs = GetScaleEntry(L["Buffs"], 20, { "AuraWidget", "Buffs", "Scale", }),
                  ScaleCrowdControl = GetScaleEntry(L["Crowd Control"], 30, { "AuraWidget", "CrowdControl", "Scale", }),
                  Reverse = {
                    type = "toggle",
                    order = 50,
                    name = L["Swap By Reaction"],
                    desc = L["Switch scale values for debuffs and buffs for friendly units."],
                    arg = { "AuraWidget", "SwitchScaleByReaction" }
                  }
                },
              },
              Placement = {
                name = L["Placement"],
                type = "group",
                inline = true,
                order = 50,
                args = {
                  Anchor = { name = L["Anchor Point"], order = 20, type = "select", values = Addon.ANCHOR_POINT, arg = { "AuraWidget", "anchor" } },
                  X = { name = L["Offset X"], order = 30, type = "range", min = -120, max = 120, step = 1, arg = { "AuraWidget", "x" }, },
                  Y = { name = L["Offset Y"], order = 40, type = "range", min = -120, max = 120, step = 1, arg = { "AuraWidget", "y" }, },
                  Spacer = GetSpacerEntry(50),
                  AlignmentH = {
                    name = L["Horizontal Alignment"],
                    order = 60,
                    type = "select",
                    values = { LEFT = L["Left-to-right"], RIGHT = L["Right-to-left"] },
                    arg = { "AuraWidget", "AlignmentH" }
                  },
                  AlignmentV = {
                    name = L["Vertical Alignment"],
                    order = 70,
                    type = "select",
                    values = { BOTTOM = L["Bottom-to-top"], TOP = L["Top-to-bottom"] },
                    arg = { "AuraWidget", "AlignmentV" }
                  },
                  CenterAuras = {
                    type = "toggle",
                    order = 80,
                    name = L["Center Auras"],
                    arg = { "AuraWidget", "CenterAuras" },
                  }
                },
              },
            },
          },
          SpecialEffects = {
            type = "group",
            order = 40,
            name = L["Special Effects"],
            inline = true,
            args = {
              Flash = {
                type = "toggle",
                order = 10,
                name = L["Flash When Expiring"],
                arg = { "AuraWidget", "FlashWhenExpiring" },
              },
              FlashTime = {
                type = "range",
                order = 20,
                name = L["Flash Time"],
                step = 1,
                softMin = 1,
                softMax = 20,
                isPercent = false,
                arg = { "AuraWidget", "FlashTime" },
                disabled = function() return not db.AuraWidget.FlashWhenExpiring end
              },
            },
          },
        },
      },
      Debuffs = {
        name = L["Debuffs"],
        type = "group",
        order = 20,
        inline = false,
        args = {
          FriendlyUnits = {
            name = L["Friendly Units"],
            type = "group",
            order = 15,
            inline = true,
            args = {
              Show = {
                name = L["Show Debuffs"],
                order = 10,
                type = "toggle",
                arg = { "AuraWidget", "Debuffs", "ShowFriendly" },
              },
              ShowAll = {
                name = L["All"],
                order = 20,
                type = "toggle",
                desc = L["Show all debuffs on friendly units."],
                set = function(info, val)
                  local db = db.AuraWidget.Debuffs
                  if db.ShowBlizzardForFriendly or db.ShowDispellable or db.ShowBoss or
                    db.FilterByType[1] or db.FilterByType[2] or db.FilterByType[3] or db.FilterByType[4] then
                    db.ShowBlizzardForFriendly = false
                    db.ShowDispellable = false
                    db.ShowBoss = false
                    db.FilterByType[1] = false
                    db.FilterByType[2] = false
                    db.FilterByType[3] = false
                    db.FilterByType[4] = false
                    SetValueWidget(info, val)
                  end
                end,
                arg = { "AuraWidget", "Debuffs", "ShowAllFriendly" },
                disabled = function() return not db.AuraWidget.Debuffs.ShowFriendly end
              },
              Blizzard = {
                name = L["Blizzard"],
                order = 25,
                type = "toggle",
                desc = L["Show debuffs that are shown on Blizzard's default nameplates."],
                set = function(info, val)
                  local db = db.AuraWidget.Debuffs
                  db.ShowAllFriendly = not (val or db.ShowDispellable or db.ShowBoss or
                  db.FilterByType[1] or db.FilterByType[2] or db.FilterByType[3] or db.FilterByType[4])
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "Debuffs", "ShowBlizzardForFriendly" },
                disabled = function() return not db.AuraWidget.Debuffs.ShowFriendly end,
              },
              Dispellable = {
                name = L["Dispellable"],
                order = 40,
                type = "toggle",
                desc = L["Show debuffs that you can dispell."],
                set = function(info, val)
                  local db = db.AuraWidget.Debuffs
                  db.ShowAllFriendly = not (val or db.ShowBlizzardForFriendly or db.ShowBoss or
                    db.FilterByType[1] or db.FilterByType[2] or db.FilterByType[3] or db.FilterByType[4])
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "Debuffs", "ShowDispellable" },
                disabled = function() return not db.AuraWidget.Debuffs.ShowFriendly end
              },
              Boss = {
                name = L["Boss"],
                order = 45,
                type = "toggle",
                desc = L["Show debuffs that where applied by bosses."],
                set = function(info, val)
                  local db = db.AuraWidget.Debuffs
                  db.ShowAllFriendly = not (val or db.ShowBlizzardForFriendly or db.ShowDispellable or
                    db.FilterByType[1] or db.FilterByType[2] or db.FilterByType[3] or db.FilterByType[4])
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "Debuffs", "ShowBoss" },
                disabled = function() return not db.AuraWidget.Debuffs.ShowFriendly end
              },
              DispelTypeH = {
                name = L["Dispel Type"],
                type = "header",
                order = 50,
              },
              Curses = {
                name = L["Curse"],
                order = 60,
                type = "toggle",
                get = function(info) return db.AuraWidget.Debuffs.FilterByType[1] end,
                set = function(info, val)
                  local db = db.AuraWidget.Debuffs
                  db.ShowAllFriendly = not (val or db.ShowBlizzardForFriendly or db.ShowDispellable or db.ShowBoss or
                    db.FilterByType[2] or db.FilterByType[3] or db.FilterByType[4])
                  db.FilterByType[1] = val
                  Addon.Widgets:UpdateSettings("Auras")
                end,
                disabled = function() return not db.AuraWidget.Debuffs.ShowFriendly end,
              },
              Diseases = {
                name = L["Disease"],
                order = 70,
                type = "toggle",
                get = function(info) return db.AuraWidget.Debuffs.FilterByType[2] end,
                set = function(info, val)
                  local db = db.AuraWidget.Debuffs
                  db.ShowAllFriendly = not (val or db.ShowBlizzardForFriendly or db.ShowDispellable or db.ShowBoss or
                    db.FilterByType[1] or db.FilterByType[3] or db.FilterByType[4])
                  db.FilterByType[2] = val
                  Addon.Widgets:UpdateSettings("Auras")
                end,
                disabled = function() return not db.AuraWidget.Debuffs.ShowFriendly end,
              },
              Magics = {
                name = L["Magic"],
                order = 80,
                type = "toggle",
                get = function(info) return db.AuraWidget.Debuffs.FilterByType[3] end,
                set = function(info, val)
                  local db = db.AuraWidget.Debuffs
                  db.ShowAllFriendly = not (val or db.ShowBlizzardForFriendly or db.ShowDispellable or db.ShowBoss or
                    db.FilterByType[1] or db.FilterByType[2] or db.FilterByType[4])
                  db.FilterByType[3] = val
                  Addon.Widgets:UpdateSettings("Auras")
                end,
                disabled = function() return not db.AuraWidget.Debuffs.ShowFriendly end,
              },
              Poisons = {
                name = L["Poison"],
                order = 90,
                type = "toggle",
                get = function(info) return db.AuraWidget.Debuffs.FilterByType[4] end,
                set = function(info, val)
                  local db = db.AuraWidget.Debuffs
                  db.ShowAllFriendly = not (val or db.ShowBlizzardForFriendly or db.ShowDispellable or db.ShowBoss or
                    db.FilterByType[1] or db.FilterByType[2] or db.FilterByType[3])
                  db.FilterByType[4] = val
                  Addon.Widgets:UpdateSettings("Auras")
                end,
                disabled = function() return not db.AuraWidget.Debuffs.ShowFriendly end,
              },
            },
          },
          EnemyUnits = {
            name = L["Enemy Units"],
            type = "group",
            order = 16,
            inline = true,
            args = {
              ShowEnemy = {
                name = L["Show Debuffs"],
                order = 10,
                type = "toggle",
                arg = { "AuraWidget", "Debuffs", "ShowEnemy" }
              },
              ShowAll = {
                name = L["All"],
                order = 20,
                type = "toggle",
                desc = L["Show all debuffs on enemy units."],
                set = function(info, val)
                  local db = db.AuraWidget.Debuffs
                  if db.ShowOnlyMine or db.ShowBlizzardForEnemy then
                    db.ShowOnlyMine = false
                    db.ShowBlizzardForEnemy = false
                    SetValueWidget(info, val)
                  end
                end,
                arg = { "AuraWidget", "Debuffs", "ShowAllEnemy" },
                disabled = function() return not db.AuraWidget.Debuffs.ShowEnemy end,
              },
              OnlyMine = {
                name = L["Mine"],
                order = 30,
                type = "toggle",
                desc = L["Show debuffs that were applied by you."],
                set = function(info, val)
                  local db = db.AuraWidget.Debuffs
                  db.ShowAllEnemy = not (val or db.ShowBlizzardForEnemy)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "Debuffs", "ShowOnlyMine" },
                disabled = function() return not db.AuraWidget.Debuffs.ShowEnemy end,
              },
              Blizzard = {
                name = L["Blizzard"],
                order = 40,
                type = "toggle",
                desc = L["Show debuffs that are shown on Blizzard's default nameplates."],
                set = function(info, val)
                  local db = db.AuraWidget.Debuffs
                  db.ShowAllEnemy = not (val or db.ShowOnlyMine)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "Debuffs", "ShowBlizzardForEnemy" },
                disabled = function() return not db.AuraWidget.Debuffs.ShowEnemy end,
              },
            },
          },
          SpellFilter = {
            name = L["Filter by Spell"],
            order = 50,
            type = "group",
            inline = true,
            args = {
              Mode = {
                name = L["Mode"],
                type = "select",
                order = 1,
                width = "double",
                values = Addon.AurasFilterMode,
                set = function(info, val)
                  db.AuraWidget.Debuffs.FilterMode = val
                  Addon.Widgets:UpdateSettings("Auras")
                end,
                arg = { "AuraWidget", "Debuffs", "FilterMode" },
              },
              DebuffList = {
                name = L["Filtered Auras"],
                type = "input",
                order = 2,
                dialogControl = "MultiLineEditBox",
                width = "full",
                get = function(info) return t.TTS(db.AuraWidget.Debuffs.FilterBySpell) end,
                set = function(info, v)
                  local table = { strsplit("\n", v) };
                  db.AuraWidget.Debuffs.FilterBySpell = table
                  Addon.Widgets:UpdateSettings("Auras")
                end,
              },
            },
          },
        },
      },
      Buffs = {
        name = L["Buffs"],
        type = "group",
        order = 30,
        inline = false,
        args = {
          FriendlyUnits = {
            name = L["Friendly Units"],
            type = "group",
            order = 10,
            inline = true,
            args = {
              Show = {
                name = L["Show Buffs"],
                order = 10,
                type = "toggle",
                arg = { "AuraWidget", "Buffs", "ShowFriendly" },
              },
              ShowAll = {
                name = L["All"],
                order = 20,
                type = "toggle",
                desc = L["Show all buffs on friendly units."],
                arg = { "AuraWidget", "Buffs", "ShowAllFriendly" },
                set = function(info, val)
                  local db = db.AuraWidget.Buffs
                  if db.ShowOnFriendlyNPCs or db.ShowOnlyMine or db.ShowPlayerCanApply then
                    db.ShowOnFriendlyNPCs = false
                    db.ShowOnlyMine = false
                    db.ShowPlayerCanApply = false
                    SetValueWidget(info, val)
                  end
                end,
                disabled = function() return not db.AuraWidget.Buffs.ShowFriendly end
              },
              NPCs = {
                name = L["All on NPCs"],
                order = 30,
                type = "toggle",
                desc = L["Show all buffs on NPCs."],
                set = function(info, val)
                  local db = db.AuraWidget.Buffs
                  db.ShowAllFriendly = not (val or db.ShowOnlyMine or db.ShowPlayerCanApply)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "Buffs", "ShowOnFriendlyNPCs" },
                disabled = function() return not db.AuraWidget.Buffs.ShowFriendly end
              },
              OnlyMine = {
                name = L["Mine"],
                order = 40,
                type = "toggle",
                desc = L["Show buffs that were applied by you."],
                set = function(info, val)
                  local db = db.AuraWidget.Buffs
                  db.ShowAllFriendly = not (db.ShowOnFriendlyNPCs or val or db.ShowPlayerCanApply)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "Buffs", "ShowOnlyMine" },
                disabled = function() return not db.AuraWidget.Buffs.ShowFriendly end
              },
              CanApply = {
                name = L["Can Apply"],
                order = 50,
                type = "toggle",
                desc = L["Show buffs that you can apply."],
                set = function(info, val)
                  local db = db.AuraWidget.Buffs
                  db.ShowAllFriendly = not (db.ShowOnFriendlyNPCs or db.ShowOnlyMine or val)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "Buffs", "ShowPlayerCanApply" },
                disabled = function() return not db.AuraWidget.Buffs.ShowFriendly end
              },
            },
          },
          EnemyUnits = {
            name = L["Enemy Units"],
            type = "group",
            order = 20,
            inline = true,
            args = {
              ShowEnemy = {
                name = L["Show Buffs"],
                order = 10,
                type = "toggle",
                arg = { "AuraWidget", "Buffs", "ShowEnemy" }
              },
              ShowAll = {
                name = L["All"],
                order = 20,
                type = "toggle",
                desc = L["Show all buffs on enemy units."],
                set = function(info, val)
                  local db = db.AuraWidget.Buffs
                  if val and not db.ShowAllEnemy then
                    db.ShowOnEnemyNPCs = false
                    db.ShowDispellable = false
                    db.ShowMagic = false
                    SetValueWidget(info, val)
                  end
                end,
                arg = { "AuraWidget", "Buffs", "ShowAllEnemy" },
                disabled = function() return not db.AuraWidget.Buffs.ShowEnemy end
              },
              NPCs = {
                name = L["All on NPCs"],
                order = 30,
                type = "toggle",
                desc = L["Show all buffs on NPCs."],
                set = function(info, val)
                  local db = db.AuraWidget.Buffs
                  db.ShowAllEnemy = not (val or db.ShowDispellable or db.ShowMagic)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "Buffs", "ShowOnEnemyNPCs" },
                disabled = function() return not db.AuraWidget.Buffs.ShowEnemy end
              },
              Dispellable = {
                name = L["Dispellable"],
                order = 50,
                type = "toggle",
                desc = L["Show buffs that you can dispell."],
                set = function(info, val)
                  local db = db.AuraWidget.Buffs
                  db.ShowAllEnemy = not (db.ShowOnEnemyNPCs or val or db.ShowMagic)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "Buffs", "ShowDispellable" },
                disabled = function() return not db.AuraWidget.Buffs.ShowEnemy end
              },
              Magics = {
                name = L["Magic"],
                order = 60,
                type = "toggle",
                desc = L["Show buffs of dispell type Magic."],
                set = function(info, val)
                  local db = db.AuraWidget.Buffs
                  db.ShowAllEnemy = not (db.ShowOnEnemyNPCs or db.ShowDispellable or val)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "Buffs", "ShowMagic" },
                disabled = function() return not db.AuraWidget.Buffs.ShowEnemy end
              },
              Header2 = { type = "header", order = 200, name = L["Unlimited Duration"], },
              UnlimitedDuration = {
                name = L["Disable"],
                order = 210,
                type = "toggle",
                desc = L["Do not show buffs with umlimited duration."],
                arg = { "AuraWidget", "Buffs", "HideUnlimitedDuration" },
                disabled = function() return not db.AuraWidget.Buffs.ShowEnemy end
              },
              Spacer1 = GetSpacerEntry(220),
              Always = {
                name = L["Show Always"],
                order = 230,
                type = "toggle",
                desc = L["Show buffs with unlimited duration in all situations (e.g., in and out of combat)."],
                set = function(info, val)
                  local db = db.AuraWidget.Buffs
                  if val and not db.ShowUnlimitedAlways then
                    db.ShowUnlimitedInCombat = false
                    db.ShowUnlimitedInInstances = false
                    db.ShowUnlimitedOnBosses = false
                    SetValueWidget(info, val)
                  end
                end,
                arg = { "AuraWidget", "Buffs", "ShowUnlimitedAlways" },
                disabled = function() return not db.AuraWidget.Buffs.ShowEnemy end
              },
              InCombat = {
                name = L["In Combat"],
                order = 240,
                type = "toggle",
                desc = L["Show unlimited buffs in combat."],
                set = function(info, val)
                  local db = db.AuraWidget.Buffs
                  db.ShowUnlimitedAlways = not (val or db.ShowUnlimitedInInstances or db.ShowUnlimitedOnBosses)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "Buffs", "ShowUnlimitedInCombat" },
                disabled = function() return not db.AuraWidget.Buffs.ShowEnemy end
              },
              InInstances = {
                name = L["In Instances"],
                order = 250,
                type = "toggle",
                desc = L["Show unlimited buffs in instances (e.g., dungeons or raids)."],
                set = function(info, val)
                  local db = db.AuraWidget.Buffs
                  db.ShowUnlimitedAlways = not (db.ShowUnlimitedInCombat or val or db.ShowUnlimitedOnBosses)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "Buffs", "ShowUnlimitedInInstances" },
                disabled = function() return not db.AuraWidget.Buffs.ShowEnemy end
              },
              OnBosses = {
                name = L["On Bosses & Rares"],
                order = 260,
                type = "toggle",
                desc = L["Show unlimited buffs on bosses and rares."],
                set = function(info, val)
                  local db = db.AuraWidget.Buffs
                  db.ShowUnlimitedAlways = not (db.ShowUnlimitedInCombat or db.ShowUnlimitedInInstances or val)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "Buffs", "ShowUnlimitedOnBosses" },
                disabled = function() return not db.AuraWidget.Buffs.ShowEnemy end
              },
            },
          },
          SpellFilter = {
            name = L["Filter by Spell"],
            order = 50,
            type = "group",
            inline = true,
            args = {
              Mode = {
                name = L["Mode"],
                type = "select",
                order = 1,
                width = "double",
                values = Addon.AurasFilterMode,
                set = function(info, val)
                  db.AuraWidget.Buffs.FilterMode = val
                  Addon.Widgets:UpdateSettings("Auras")
                end,
                arg = { "AuraWidget", "Buffs", "FilterMode" },
              },
              DebuffList = {
                name = L["Filtered Auras"],
                type = "input",
                order = 2,
                dialogControl = "MultiLineEditBox",
                width = "full",
                get = function(info) return t.TTS(db.AuraWidget.Buffs.FilterBySpell) end,
                set = function(info, v)
                  local table = { strsplit("\n", v) };
                  db.AuraWidget.Buffs.FilterBySpell = table
                  Addon.Widgets:UpdateSettings("Auras")
                end,
              },
            },
          },
        },
      },
      CrowdControl = {
        name = L["Crowd Control"],
        type = "group",
        order = 40,
        inline = false,
        args = {
          FriendlyUnits = {
            name = L["Friendly Units"],
            type = "group",
            order = 10,
            inline = true,
            args = {
              Show = {
                name = L["Show Crowd Control"],
                order = 10,
                type = "toggle",
                arg = { "AuraWidget", "CrowdControl", "ShowFriendly" },
              },
              ShowAll = {
                name = L["All"],
                order = 20,
                type = "toggle",
                desc = L["Show all crowd control auras on friendly units."],
                set = function(info, val)
                  local db = db.AuraWidget.CrowdControl
                  if db.ShowBlizzardForFriendly or db.ShowDispellable or db.ShowBoss then
                    db.ShowBlizzardForFriendly = false
                    db.ShowDispellable = false
                    db.ShowBoss = false
                    SetValueWidget(info, val)
                  end
                end,
                arg = { "AuraWidget", "CrowdControl", "ShowAllFriendly" },
                disabled = function() return not db.AuraWidget.CrowdControl.ShowFriendly end
              },
              Blizzard = {
                name = L["Blizzard"],
                order = 30,
                type = "toggle",
                desc = L["Show crowd control auras that are shown on Blizzard's default nameplates."],
                set = function(info, val)
                  local db = db.AuraWidget.CrowdControl
                  db.ShowAllFriendly = not (val or db.ShowDispellable or db.ShowBoss)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "CrowdControl", "ShowBlizzardForFriendly" },
                disabled = function() return not db.AuraWidget.CrowdControl.ShowFriendly end,
              },
              Dispellable = {
                name = L["Dispellable"],
                order = 40,
                type = "toggle",
                desc = L["Show crowd control auras that you can dispell."],
                set = function(info, val)
                  local db = db.AuraWidget.CrowdControl
                  db.ShowAllFriendly = not (val or db.ShowBlizzardForFriendly or db.ShowBoss)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "CrowdControl", "ShowDispellable" },
                disabled = function() return not db.AuraWidget.CrowdControl.ShowFriendly end
              },
              Boss = {
                name = L["Boss"],
                order = 50,
                type = "toggle",
                desc = L["Show crowd control auras that where applied by bosses."],
                set = function(info, val)
                  local db = db.AuraWidget.CrowdControl
                  db.ShowAllFriendly = not (val or db.ShowBlizzardForFriendly or db.ShowDispellable)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "CrowdControl", "ShowBoss" },
                disabled = function() return not db.AuraWidget.CrowdControl.ShowFriendly end
              },
            },
          },
          EnemyUnits = {
            name = L["Enemy Units"],
            type = "group",
            order = 20,
            inline = true,
            args = {
              ShowEnemy = {
                name = L["Show Crowd Control"],
                order = 10,
                type = "toggle",
                arg = { "AuraWidget", "CrowdControl", "ShowEnemy" }
              },
              ShowAll = {
                name = L["All"],
                order = 20,
                type = "toggle",
                desc = L["Show all crowd control auras on enemy units."],
                set = function(info, val)
                  local db = db.AuraWidget.CrowdControl
                  if db.ShowBlizzardForEnemy then
                    db.ShowBlizzardForEnemy = false
                    SetValueWidget(info, val)
                  end
                end,
                arg = { "AuraWidget", "CrowdControl", "ShowAllEnemy" },
                disabled = function() return not db.AuraWidget.CrowdControl.ShowEnemy end
              },
              Blizzard = {
                name = L["Blizzard"],
                order = 30,
                type = "toggle",
                desc = L["Show crowd control auras hat are shown on Blizzard's default nameplates."],
                set = function(info, val)
                  local db = db.AuraWidget.CrowdControl
                  db.ShowAllEnemy = not (val)
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "CrowdControl", "ShowBlizzardForEnemy" },
                disabled = function() return not db.AuraWidget.CrowdControl.ShowEnemy end,
              },
            },
          },
          SpellFilter = {
            name = L["Filter by Spell"],
            order = 50,
            type = "group",
            inline = true,
            args = {
              Mode = {
                name = L["Mode"],
                type = "select",
                order = 1,
                width = "double",
                values = Addon.AurasFilterMode,
                set = function(info, val)
                  db.AuraWidget.CrowdControl.FilterMode = val
                  Addon.Widgets:UpdateSettings("Auras")
                end,
                arg = { "AuraWidget", "CrowdControl", "FilterMode" },
              },
              DebuffList = {
                name = L["Filtered Auras"],
                type = "input",
                order = 2,
                dialogControl = "MultiLineEditBox",
                width = "full",
                get = function(info) return t.TTS(db.AuraWidget.CrowdControl.FilterBySpell) end,
                set = function(info, v)
                  local table = { strsplit("\n", v) };
                  db.AuraWidget.CrowdControl.FilterBySpell = table
                  Addon.Widgets:UpdateSettings("Auras")
                end,
              },
            },
          },
        },
      },
      ModeIcon = {
        name = L["Icon Mode"],
        order = 50,
        type = "group",
        inline = false,
        args = {
          --Help = { type = "description", order = 0, width = "full", name = L["Show auras as icons in a grid configuration."], },
          Enable = {
            type = "toggle",
            order = 10,
            --name = L["Enable"],
            name = L["Show auras as icons in a grid configuration."],
            width = "full",
            arg = { "AuraWidget", "ModeBar", "Enabled" },
            set = function(info, val) SetValueWidget(info, false) end,
            get = function(info) return not GetValue(info) end,
          },
          Appearance = {
            name = L["Appearance"],
            order = 30,
            type = "group",
            inline = true,
            args = {
              Style = {
                name = L["Icon Style"],
                order = 10,
                type = "select",
                desc = L["This lets you select the layout style of the auras widget."],
                descStyle = "inline",
                values = { wide = L["Wide"], square = L["Square"] , custom = L["Custom"] },
                set = function(info, val)
                  if val ~= "custom" then
                    Addon.MergeIntoTable(db.AuraWidget.ModeIcon, AURA_STYLE[val])
                  end
                  SetValueWidget(info, val)
                end,
                arg = { "AuraWidget", "ModeIcon", "Style" },
              },
              Width = GetSizeEntry(L["Icon Width"], 20, { "AuraWidget", "ModeIcon", "IconWidth" }, function() return db.AuraWidget.ModeIcon.Style ~= "custom" end),
              Height = GetSizeEntry(L["Icon Height"], 30, { "AuraWidget", "ModeIcon", "IconHeight" }, function() return db.AuraWidget.ModeIcon.Style ~= "custom" end),
              Spacer1 = GetSpacerEntry(40),
              ShowBorder = {
                type = "toggle",
                order = 50,
                name = L["Border"],
                disabled = function() return db.AuraWidget.ModeIcon.Style ~= "custom" end,
                arg = { "AuraWidget", "ModeIcon", "ShowBorder" },
              },
            },
          },
          Layout = {
            name = L["Layout"],
            order = 30,
            type = "group",
            inline = true,
            args = {
              Columns = { name = L["Column Limit"], order = 20, type = "range", min = 1, max = 8, step = 1, arg = { "AuraWidget", "ModeIcon", "Columns" }, },
              Rows = { name = L["Row Limit"], order = 30, type = "range", min = 1, max = 10, step = 1, arg = { "AuraWidget", "ModeIcon", "Rows" }, },
              ColumnSpacing = { name = L["Horizontal Spacing"], order = 40, type = "range", min = 0, max = 100, step = 1, arg = { "AuraWidget", "ModeIcon", "ColumnSpacing" }, },
              RowSpacing = { name = L["Vertical Spacing"], order = 50, type = "range", min = 0, max = 100, step = 1, arg = { "AuraWidget", "ModeIcon", "RowSpacing" }, },
            },
          },
          Duration = {
            name = L["Duration"],
            order = 40,
            type = "group",
            inline = true,
            disabled = function() return db.AuraWidget.ModeIcon.Style ~= "custom" end,
            args = {
              Font = GetFontEntryDefault(L["Font"], 10, { "AuraWidget", "ModeIcon", "Duration" }),
              Placement = {
                type = "group",
                order = 20,
                name = L["Placement"],
                inline = true,
                args = {
                  Anchor = {
                    type = "select",
                    order = 10,
                    name = L["Position"],
                    values = Addon.ANCHOR_POINT,
                    arg = { "AuraWidget", "ModeIcon", "Duration", "Anchor" }
                  },
                  InsideAnchor = {
                    type = "toggle",
                    order = 15,
                    name = L["Inside"],
                    width = "half",
                    arg = { "AuraWidget", "ModeIcon", "Duration", "InsideAnchor" }
                  },
                  X = {
                    type = "range",
                    order = 20,
                    name = L["Horizontal Offset"],
                    max = 120,
                    min = -120,
                    step = 1,
                    isPercent = false,
                    arg = { "AuraWidget", "ModeIcon", "Duration", "HorizontalOffset" },
                  },
                  Y = {
                    type = "range",
                    order = 30,
                    name = L["Vertical Offset"],
                    max = 120,
                    min = -120,
                    step = 1,
                    isPercent = false,
                    arg = { "AuraWidget", "ModeIcon", "Duration", "VerticalOffset" },
                  },
                  AlignX = {
                    type = "select",
                    order = 40,
                    name = L["Horizontal Align"],
                    values = t.AlignH,
                    arg = { "AuraWidget", "ModeIcon", "Duration", "Font", "HorizontalAlignment" },
                  },
                  AlignY = {
                    type = "select",
                    order = 50,
                    name = L["Vertical Align"],
                    values = t.AlignV,
                    arg = { "AuraWidget", "ModeIcon", "Duration", "Font", "VerticalAlignment" },
                  },
                },
              },
            },
          },
          StackCount = {
            name = L["Stack Count"],
            order = 50,
            type = "group",
            inline = true,
            disabled = function() return db.AuraWidget.ModeIcon.Style ~= "custom" end,
            args = {
              Font = GetFontEntryDefault(L["Font"], 10, { "AuraWidget", "ModeIcon", "StackCount" }),
              Placement = {
                type = "group",
                order = 20,
                name = L["Placement"],
                inline = true,
                args = {
                  Anchor = {
                    type = "select",
                    order = 10,
                    name = L["Anchor Point"],
                    values = Addon.ANCHOR_POINT,
                    arg = { "AuraWidget", "ModeIcon", "StackCount", "Anchor" }
                  },
                  InsideAnchor = {
                    type = "toggle",
                    order = 15,
                    name = L["Inside"],
                    width = "half",
                    arg = { "AuraWidget", "ModeIcon", "StackCount", "InsideAnchor" }
                  },
                  X = {
                    type = "range",
                    order = 20,
                    name = L["Horizontal Offset"],
                    max = 120,
                    min = -120,
                    step = 1,
                    isPercent = false,
                    arg = { "AuraWidget", "ModeIcon", "StackCount", "HorizontalOffset" },
                  },
                  Y = {
                    type = "range",
                    order = 30,
                    name = L["Vertical Offset"],
                    max = 120,
                    min = -120,
                    step = 1,
                    isPercent = false,
                    arg = { "AuraWidget", "ModeIcon", "StackCount", "VerticalOffset" },
                  },
                  AlignX = {
                    type = "select",
                    order = 40,
                    name = L["Horizontal Align"],
                    values = t.AlignH,
                    arg = { "AuraWidget", "ModeIcon", "StackCount", "Font", "HorizontalAlignment" },
                  },
                  AlignY = {
                    type = "select",
                    order = 50,
                    name = L["Vertical Align"],
                    values = t.AlignV,
                    arg = { "AuraWidget", "ModeIcon", "StackCount", "Font", "VerticalAlignment" },
                  },
                },
              },
            },
          },
        },
      },
      ModeBar = {
        name = L["Bar Mode"],
        order = 60,
        type = "group",
        inline = false,
        args = {
          --Help = { type = "description", order = 0, width = "full", name = L["Show auras as bars (with optional icons)."], },
          Enable = {
            type = "toggle",
            order = 10,
            --name = L["Enable"],
            name = L["Show auras as bars (with optional icons)."],
            width = "full",
            set = function(info, val) SetValueWidget(info, true) end,
            get = function(info) return GetValue(info) end,
            arg = { "AuraWidget", "ModeBar", "Enabled" }
          },
          Appearance = {
            name = L["Appearance"],
            order = 30,
            type = "group",
            inline = true,
            args = {
              TextureConfig = {
                name = L["Textures"],
                order = 10,
                type = "group",
                inline = true,
                args = {
                  BarTexture = { name = L["Foreground Texture"], order = 60, type = "select", dialogControl = "LSM30_Statusbar", values = AceGUIWidgetLSMlists.statusbar, arg = { "AuraWidget", "ModeBar", "Texture" }, },
                  --Spacer2 = GetSpacerEntry(75),
                  BackgroundTexture = { name = L["Background Texture"], order = 80, type = "select", dialogControl = "LSM30_Statusbar", values = AceGUIWidgetLSMlists.statusbar, arg = { "AuraWidget", "ModeBar", "BackgroundTexture" }, },
                  BackgroundColor = {	name = L["Background Color"], type = "color",	order = 90, arg = {"AuraWidget","ModeBar", "BackgroundColor"},	hasAlpha = true,
                    get = GetColorAlpha, set = SetColorAlphaWidget,
                  },
                },
              },
              FontConfig = {
                name = L["Font"],
                order = 20,
                type = "group",
                inline = true,
                args = {
                  Font = { name = L["Typeface"], type = "select", order = 10, dialogControl = "LSM30_Font", values = AceGUIWidgetLSMlists.font, arg = { "AuraWidget", "ModeBar", "Font" }, },
                  FontSize = { name = L["Size"], order = 20, type = "range", min = 1, max = 36, step = 1, arg = { "AuraWidget", "ModeBar", "FontSize" }, },
                  FontColor = {	name = L["Color"], type = "color",	order = 30,	get = GetColor,	set = SetColorWidget,	arg = {"AuraWidget","ModeBar", "FontColor"},	hasAlpha = false, },
                  Spacer1 = GetSpacerEntry(35),
                  IndentLabel = { name = L["Label Text Offset"], order = 40, type = "range", min = -16, max = 16, step = 1, arg = { "AuraWidget", "ModeBar", "LabelTextIndent" }, },
                  IndentTime = { name = L["Time Text Offset"], order = 50, type = "range", min = -16, max = 16, step = 1, arg = { "AuraWidget", "ModeBar", "TimeTextIndent" }, },
                },
              },
            },
          },
          Layout = {
            name = L["Layout"],
            order = 60,
            type = "group",
            inline = true,
            args = {
              MaxBars = { name = L["Bar Limit"], order = 20, type = "range", min = 1, max = 20, step = 1, arg = { "AuraWidget", "ModeBar", "MaxBars" }, },
              BarWidth = { name = L["Bar Width"], order = 30, type = "range", min = 1, max = 500, step = 1, arg = { "AuraWidget", "ModeBar", "BarWidth" }, },
              BarHeight = { name = L["Bar Height"], order = 40, type = "range", min = 1, max = 500, step = 1, arg = { "AuraWidget", "ModeBar", "BarHeight" }, },
              BarSpacing = { name = L["Vertical Spacing"], order = 50, type = "range", min = 0, max = 100, step = 1, arg = { "AuraWidget", "ModeBar", "BarSpacing" }, },
            },
          },
          IconConfig = {
            name = L["Icon"],
            order = 50,
            type = "group",
            inline = true,
            args = {
              EnableIcon = { name = L["Enable"], order = 10, type = "toggle", arg = { "AuraWidget", "ModeBar", "ShowIcon" }, },
              IconAlign = { name = L["Show Icon to the Left"], order = 20, type = "toggle", arg = { "AuraWidget", "ModeBar", "IconAlignmentLeft" }, },
              IconOffset = { name = L["Offset"], order = 30, type = "range", min = -100, max = 100, step = 1, arg = { "AuraWidget", "ModeBar", "IconSpacing", }, },
            },
          },
        },
      },
    },
  }

  return options
end

local function CreateHeadlineViewShowEntry()
  local args = {}
  local pos = 0

  for i, value in ipairs(UNIT_TYPES) do
    local faction = value.Faction
    args[faction .. "Units"] = {
      name = L[faction .. " Units"],
      order = pos,
      type = "group",
      inline = true,
      args = {},
    }

    for i, unit_type in ipairs(value.UnitTypes) do
      args[faction .. "Units"].args["UnitType" .. faction .. unit_type] = {
        name = L[unit_type.."s"],
        order = pos + i,
        type = "toggle",
        arg = { "Visibility", faction..unit_type, "UseHeadlineView" }
      }
    end

    pos = pos + 10
  end

  return args
end

local function CreateUnitGroupsVisibility(args, pos)
  for i, value in ipairs(UNIT_TYPES) do
    local faction = value.Faction
    args[faction.."Units"] = {
      name = L["Show "..faction.." Units"],
      order = pos,
      type = "group",
      inline = true,
      args = {},
    }

    for i, unit_type in ipairs(value.UnitTypes) do
      args[faction.."Units"].args["UnitType"..faction..unit_type] = {
        name = L[unit_type.."s"],
        order = pos + i,
        type = "toggle",
        arg = faction..unit_type,
        get = GetUnitVisibilitySetting,
        set = SetUnitVisibilitySetting,
      }
    end

    pos = pos + 10
  end
end

local function CreateVisibilitySettings()
  local args = {
    name = L["Visibility"],
    type = "group",
    order = 10,
    args = {
      GeneralUnits = {
        name = L["General Nameplate Settings"],
        order = 10,
        type = "group",
        inline = true,
        width = "full",
        get = GetCVarBoolTPTP,
        set = SetCVarBoolTPTP,
        args = {
          Description = GetDescriptionEntry(L["These options allow you to control which nameplates are visible within the game field while you play."]),
          Spacer0 = GetSpacerEntry(1),
          AllPlates = {
            name = L["Always Show Nameplates"],
            desc = L["Show nameplates at all times."],
            type = "toggle",
            order = 10,
            width = "full",
            arg = "nameplateShowAll"
          },
          AllUnits = {
            name = L["Show All Nameplates (Friendly and Enemy Units) (CTRL-V)"],
            order = 20,
            type = "toggle",
            width = "full",
            set = function(info, value)
              Addon.CVars:OverwriteProtected("nameplateShowFriends", (value and 1) or 0)
              Addon.CVars:OverwriteProtected("nameplateShowEnemies", (value and 1) or 0)
            end,
            get = function(info)
              return GetCVarBool("nameplateShowFriends") and GetCVarBool("nameplateShowEnemies")
            end,
          },
          AllFriendly = {
            name = L["Show Friendly Nameplates (SHIFT-V)"],
            type = "toggle",
            order = 30,
            width = "full",
            arg = "nameplateShowFriends"
          },
          AllHostile = {
            name = L["Show Enemy Nameplates (ALT-V)"],
            order = 40,
            type = "toggle",
            width = "full",
            arg = "nameplateShowEnemies"
          },
          Header = { type = "header", order = 45, name = "", },
          ShowBlizzardFriendlyNameplates = {
            name = L["Show Blizzard Nameplates for Friendly Units"],
            order = 50,
            type = "toggle",
            width = "full",
            set = function(info, val)
              info = t.CopyTable(info)
              Addon:CallbackWhenOoC(function()
                SetValue(info, val)
                Addon:SetBaseNamePlateSize() -- adjust clickable area if switching from Blizzard plates to Threat Plate plates
                for plate, unitid in pairs(Addon.PlatesVisible) do
                  Addon:UpdateNameplateStyle(plate, unitid)
                end
              end, L["Unable to change a setting while in combat."])
            end,
            get = GetValue,
            desc = L["Use Blizzard default nameplates for friendly nameplates and disable ThreatPlates for these units."],
            arg = { "ShowFriendlyBlizzardNameplates" },
          },
          ShowBlizzardEnemyNameplates = {
            name = L["Show Blizzard Nameplates for Neutral and Enemy Units"],
            order = 60,
            type = "toggle",
            width = "full",
            set = function(info, val)
              info = t.CopyTable(info)
              Addon:CallbackWhenOoC(function()
                SetValue(info, val)
                Addon:SetBaseNamePlateSize() -- adjust clickable area if switching from Blizzard plates to Threat Plate plates
                for plate, unitid in pairs(Addon.PlatesVisible) do
                  Addon:UpdateNameplateStyle(plate, unitid)
                end
              end, L["Unable to change a setting while in combat."])
            end,
            get = GetValue,
            desc = L["Use Blizzard default nameplates for neutral and enemy nameplates and disable ThreatPlates for these units."],
            arg = { "ShowEnemyBlizzardNameplates" },
          },
        },
      },
      SpecialUnits = {
        name = L["Hide Nameplates"],
        type = "group",
        order = 50,
        inline = true,
        width = "full",
        args = {
          HideNormal = { name = L["Normal Units"], order = 1, type = "toggle", arg = { "Visibility", "HideNormal" }, },
          HideElite = { name = L["Rares & Elites"], order = 2, type = "toggle", arg = { "Visibility", "HideElite" }, },
          HideBoss = { name = L["Bosses"], order = 3, type = "toggle", arg = { "Visibility", "HideBoss" }, },
          HideTapped = { name = L["Tapped Units"], order = 4, type = "toggle", arg = { "Visibility", "HideTapped" }, },
          ModeHideFriendlyInCombat = {
            name = L["Friendly Units in Combat"],
            order = 10,
            type = "toggle",
            width = "double",
            arg = { "Visibility", "HideFriendlyInCombat" }
          },
        },
      },
      Clickthrough = {
        name = L["Nameplate Clickthrough"],
        type = "group",
        order = 70,
        inline = true,
        width = "full",
        args = {
          ClickthroughFriendly = {
            name = L["Friendly Units"],
            order = 1,
            type = "toggle",
            width = "double",
            desc = L["Enable nameplate clickthrough for friendly units."],
            set = function(info, val) t.SetNamePlateClickThrough(val, db.NamePlateEnemyClickThrough) end,
            -- return in-game value for clickthrough as config values may be wrong because of in-combat restrictions when changing them
            get = function(info) return C_NamePlate.GetNamePlateFriendlyClickThrough() end,
            arg = { "NamePlateFriendlyClickThrough" },
          },
          ClickthroughEnemy = {
            name = L["Enemy Units"],
            order = 2,
            type = "toggle",
            width = "double",
            desc = L["Enable nameplate clickthrough for enemy units."],
            set = function(info, val) t.SetNamePlateClickThrough(db.NamePlateFriendlyClickThrough, val) end,
            -- return in-game value for clickthrough as config values may be wrong because of in-combat restrictions when changing them
            get = function(info) return C_NamePlate.GetNamePlateEnemyClickThrough() end,
            arg = { "NamePlateEnemyClickThrough" },
          },
        },
      },
    },
  }
  CreateUnitGroupsVisibility(args.args, 20)

  return args
end

local function CreateBlizzardSettings()
-- nameplateGlobalScale
  -- rmove /tptp command for stacking, not-stacking nameplates
  -- don'T allow to change all cvar related values in Combat, either by using the correct CVarTPTP function
  -- or by disabling the options in this case

  local entry = {
    name = L["Blizzard Settings"],
    order = 140,
    type = "group",
    set = SetCVarTPTP,
    get = GetCVarTPTP,
    -- diable while in Combat - überprüfen
    args = {
      Note = {
        name = L["Note"],
        order = 1,
        type = "group",
        inline = true,
        args = {
          Header = {
            name = L["Changing these options may interfere with other nameplate addons or Blizzard default nameplates as console variables (CVars) are changed."],
            order = 1,
            type = "description",
            width = "full",
          },
        },
      },
      Resolution = {
        name = L["UI Scale"],
        order = 5,
        type = "group",
        inline = true,
        args = {
          UIScale = {
            name = L["UI Scale"],
            order = 10,
            type = "range",
            min = 0.64,
            max = 1,
            step = 0.01,
            disabled = function() return db.Scale.IgnoreUIScale or db.Scale.PixelPerfectUI end,
            arg = "uiScale",
          },
          IgnoreUIScale = {
            name = L["Ignore UI Scale"],
            order = 20,
            type = "toggle",
            set = function(info, val)
              SetValuePlain(info, val)
              db.Scale.PixelPerfectUI = not val and db.Scale.PixelPerfectUI
              Addon:UIScaleChanged()
              Addon:ForceUpdate()
            end,
            get = GetValue,
            arg = { "Scale", "IgnoreUIScale" },
          },
          PixelPerfectUI = {
            name = L["Pixel-Perfect UI"],
            order = 30,
            type = "toggle",
            set = function(info, val)
              SetValuePlain(info, val)
              db.Scale.IgnoreUIScale = not val and db.Scale.IgnoreUIScale
              Addon:UIScaleChanged()
              Addon:ForceUpdate()
            end,
            get = GetValue,
            arg = { "Scale", "PixelPerfectUI" },
          },
        },
      },
      Clickarea = {
        name = L["Clickable Area"],
        order = 10,
        type = "group",
        inline = true,
        set = SetValue,
        get = GetValue,
        disabled = function() return db.ShowFriendlyBlizzardNameplates or db.ShowEnemyBlizzardNameplates end,
        args = {
          Description = {
            type = "description",
            order = 1,
            name = L["Because of side effects with Blizzard nameplates, this function is disabled in instances or when Blizzard nameplates are used for friendly or neutral/enemy units (see General - Visibility)."],
            hidden = function() return not db.ShowFriendlyBlizzardNameplates and not db.ShowEnemyBlizzardNameplates end,
            width = "full",
          },
          ToggleSync = {
            name = L["Healthbar Sync"],
            order = 10,
            type = "toggle",
            desc = L["The size of the clickable area is always derived from the current size of the healthbar."],
            set = function(info, val)
              if InCombatLockdown() then
                t.Print("We're unable to change this while in combat", true)
              else
                SetValue(info, val)
                Addon:SetBaseNamePlateSize()
              end
            end,
            arg = { "settings", "frame", "SyncWithHealthbar"},
          },
          Width = {
            name = L["Width"],
            order = 20,
            type = "range",
            min = 1,
            max = 500,
            step = 1,
            set = function(info, val)
              if InCombatLockdown() then
                t.Print("We're unable to change this while in combat", true)
              else
                SetValue(info, val)
                Addon:SetBaseNamePlateSize()
              end
            end,
            disabled = function() return db.settings.frame.SyncWithHealthbar end,
            arg = { "settings", "frame", "width" },
          },
          Height = {
            name = L["Height"],
            order = 30,
            type = "range",
            min = 1,
            max = 100,
            step = 1,
            set = function(info, val)
              if InCombatLockdown() then
                t.Print("We're unable to change this while in combat", true)
              else
                SetValue(info, val)
                Addon:SetBaseNamePlateSize()
              end
            end,
            disabled = function() return db.settings.frame.SyncWithHealthbar end,
            arg = { "settings", "frame", "height"},
          },
          ShowArea = {
            name = L["Configuration Mode"],
            type = "execute",
            order = 40,
            desc = "Toggle a background showing the area of the clicable area.",
            func = function()
              Addon:ConfigClickableArea(true)
            end,
          }
        },
      },
      Motion = {
        name = L["Motion & Overlap"],
        order = 20,
        type = "group",
        inline = true,
        args = {
          Motion = {
            name = L["Movement Model"],
            order = 10,
            type = "select",
            desc = L["Defines the movement/collision model for nameplates."],
            values = { Overlapping = L["Overlapping"], Stacking = L["Stacking"] },
            set = function(info, value) SetCVarTPTP(info, (value == "Overlapping" and "0") or "1") end,
            get = function(info) return (GetCVarBoolTPTP(info) and "Stacking") or "Overlapping" end,
            arg = "nameplateMotion",
          },
          MotionSpeed = {
            name = L["Motion Speed"],
            order = 20,
            type = "range",
            min = 0,
            max = 1,
            step = 0.01,
            desc = L["Controls the rate at which nameplate animates into their target locations [0.0-1.0]."],
            arg = "nameplateMotionSpeed",
          },
          OverlapH = {
            name = L["Horizontal Overlap"],
            order = 30,
            type = "range",
            min = 0,
            max = 1.5,
            step = 0.01,
            isPercent = true,
            desc = L["Percentage amount for horizontal overlap of nameplates."],
            arg = "nameplateOverlapH",
          },
          OverlapV = {
            name = L["Vertical Overlap"],
            order = 40,
            type = "range",
            min = 0,
            max = 1.5,
            step = 0.01,
            isPercent = true,
            desc = L["Percentage amount for vertical overlap of nameplates."],
            arg = "nameplateOverlapV",
          },
        },
      },
      Distance = {
        name = L["Distance"],
        order = 30,
        type = "group",
        inline = true,
        args = {
          MaxDistance = {
            name = L["Max Distance"],
            order = 10,
            type = "range",
            min = 0,
            max = 20,
            step = 1,
            width = "double",
            desc = L["The max distance to show nameplates."],
            arg = "nameplateMaxDistance",
          },
          MaxDistanceBehindCam = {
            name = L["Max Distance Behind Camera"],
            order = 20,
            type = "range",
            min = 0,
            max = 100,
            step = 1,
            width = "double",
            desc = L["The max distance to show the target nameplate when the target is behind the camera."],
            arg = "nameplateTargetBehindMaxDistance",
          },
        },
      },
      Insets = {
        name = L["Insets"],
        order = 40,
        type = "group",
        inline = true,
        args = {
          OtherTopInset = {
            name = L["Top Inset"],
            order = 10,
            type = "range",
            min = -0.2,
            max = 0.3,
            step = 0.01,
            isPercent = true,
            desc = L["The inset from the top (in screen percent) that the non-self nameplates are clamped to."],
            arg = "nameplateOtherTopInset",
          },
          OtherBottomInset = {
            name = L["Bottom Inset"],
            order = 20,
            type = "range",
            min = -0.2,
            max = 0.3,
            step = 0.01,
            isPercent = true,
            desc = L["The inset from the bottom (in screen percent) that the non-self nameplates are clamped to."],
            arg = "nameplateOtherBottomInset",
          },
          LargeTopInset = {
            name = L["Large Top Inset"],
            order = 30,
            type = "range",
            min = -0.2,
            max = 0.3,
            step = 0.01,
            isPercent = true,
            desc = L["The inset from the top (in screen percent) that large nameplates are clamped to."],
            arg = "nameplateLargeTopInset",
          },
          LargeBottomInset = {
            name = L["Large Bottom Inset"],
            order = 40,
            type = "range",
            min = -0.2,
            max = 0.3,
            step = 0.01,
            isPercent = true,
            desc = L["The inset from the bottom (in screen percent) that large nameplates are clamped to."],
            arg = "nameplateLargeBottomInset",
          },
          ClampTarget = {
            name = L["Clamp Target Nameplate to Screen"],
            order = 50,
            type = "toggle",
            width = "double",
            set = SetCVarBoolTPTP,
            get = GetCVarBoolTPTP,
            desc = L["Clamps the target's nameplate to the edges of the screen, even if the target is off-screen."],
            arg = "clampTargetNameplateToScreen",
          },
        },
      },
--      Alpha = {
--        name = L["Alpha"],
--        order = 43,
--        type = "group",
--        inline = true,
--        args = {
--          OccludedUnits = {
--            name = L["Mult for Occluded Units"],
--            order = 10,
--            type = "range",
--            min = -10,
--            max = 10,
--            step = 0.01,
--            isPercent = false,
--            set = function(info, value) SetCVarTPTP(info, value); Addon:ForceUpdate() end,
--            desc = L["Alpha multiplier of nameplates for occluded units."],
--            arg = "nameplateOccludedAlphaMult",
--          },
--          MinAlpha = {
--            name = L["Min Alpha"],
--            order = 20,
--            type = "range",
--            min = 0,
--            max = 1,
--            step = 0.01,
--            isPercent = false,
--            set = function(info, value) SetCVarTPTP(info, value); Addon:ForceUpdate() end,
--            desc = L["The minimum alpha of nameplates."],
--            arg = "nameplateMinAlpha",
--          },
--          MaxAlpha = {
--            name = L["Max Alpha"],
--            order = 30,
--            type = "range",
--            min = 0,
--            max = 1,
--            step = 0.01,
--            isPercent = false,
--            set = function(info, value) SetCVarTPTP(info, value); Addon:ForceUpdate() end,
--            desc = L["The max alpha of nameplates."],
--            arg = "nameplateMaxAlpha",
--          },
--        },
--      },
--      PersonalNameplate = {
--        name = L["Personal Nameplate"],
--        order = 45,
--        type = "group",
--        inline = true,
--        args = {
--          HideBuffs = {
--            type = "toggle",
--            order = 10,
--            name = L["Hide Buffs"],
--            set = function(info, val)
--              db.PersonalNameplate.HideBuffs = val
--              local plate = C_NamePlate.GetNamePlateForUnit("player")
--              if plate and plate:IsShown() then
--                plate.UnitFrame.BuffFrame:SetShown(not val)
--              end
--            end,
--            get = GetValue,
--            arg = { "PersonalNameplate", "HideBuffs"},
--          },
--          ShowResources = {
--            type = "toggle",
--            order = 20,
--            name = L["Resources on Targets"],
--            desc = L["Enable this if you want to show Blizzards special resources above the target nameplate."],
--            width = "double",
--            set = function(info, val)
--              SetValuePlain(info, val)
--              Addon.CVars:OverwriteBoolProtected("nameplateResourceOnTarget", val)
--            end,
--            get = GetValue,
--            arg = { "PersonalNameplate", "ShowResourceOnTarget"},
--          },
--        },
--      },
      Reset = {
        name = L["Reset"],
        order = 50,
        type = "group",
        inline = true,
        args = {
          Reset = {
            name = L["Reset to Defaults"],
            order = 10,
            type = "execute",
            width = "double",
            func = function()
              if InCombatLockdown() then
                t.Print("We're unable to change this while in combat", true)
              else
                local cvars = {
                  "nameplateOtherTopInset", "nameplateOtherBottomInset", "nameplateLargeTopInset", "nameplateLargeBottomInset", "clampTargetNameplateToScreen",
                  "nameplateMotion", "nameplateMotionSpeed", "nameplateOverlapH", "nameplateOverlapV",
                  "nameplateMaxDistance", "nameplateTargetBehindMaxDistance",
                  -- "nameplateGlobalScale" -- Reset it to 1, if it get's somehow corrupted
                }
                for k, v in pairs(cvars) do
                  Addon.CVars:SetToDefault(v)
                end
                Addon:ForceUpdate()
              end
            end,
          },
          OpenBlizzardSettings = {
            name = L["Open Blizzard Settings"],
            order = 20,
            type = "execute",
            width = "double",
            func = function()
              InterfaceOptionsFrame_OpenToCategory(_G["InterfaceOptionsNamesPanel"])
              Addon.LibAceConfigDialog:Close("Threat Plates");
            end,
          },
        },
      },
    },
    --  ["ShowNamePlateLoseAggroFlash"] = "When enabled, if you are a tank role and lose aggro, the nameplate with briefly flash.",
  }

  return entry
end

local function CreateAutomationSettings()
  -- Small nameplates: in combat, out of instances, ...
  -- show names or show them automatically, complicated, lots of CVars
  -- Additional options: disable friendly NPCs in instancesf
  local entry = {
    name = L["Automation"],
    order = 15,
    type = "group",
    args = {
      InCombat = {
        name = L["Combat"],
        order = 10,
        type = "group",
        inline = true,
        set = SyncGameSettings,
        args = {
          FriendlyUnits = {
            name = L["Friendly Units"],
            order = 10,
            type = "select",
            width = "double",
            values = t.AUTOMATION,
            arg = { "Automation", "FriendlyUnits" },
          },
          HostileUnits = {
            name = L["Enemy Units"],
            order = 20,
            type = "select",
            width = "double",
            values = t.AUTOMATION,
            arg = { "Automation", "EnemyUnits" },
          },
          SpacerAuto = GetSpacerEntry(30),
          ModeOoC = {
            name = L["Headline View Out of Combat"],
            order = 40,
            type = "toggle",
            width = "double",
            set = SetValue,
            arg = { "HeadlineView", "ForceOutOfCombat" }
          },
          HeadlineViewOnFriendly = {
            name = L["Nameplate Mode for Friendly Units in Combat"],
            order = 50,
            type = "select",
            values = { NAME = L["Headline View"], HEALTHBAR = L["Healthbar View"], NONE = L["None"] },
            style = "dropdown",
            width = "double",
            set = SetValue,
            arg = { "HeadlineView", "ForceFriendlyInCombat" }
          },
        },
      },
      InInstances = {
        name = L["Instances"],
        order = 20,
        type = "group",
        inline = true,
        set = SyncGameSettingsWorld,
        args = {
          SmallNameplates = {
            name = L["Small Blizzard Nameplates"],
            order = 50,
            type = "toggle",
            width = "double",
            desc = L["Reduce the size of the Blizzard's default large nameplates in instances to 50%."],
            arg = { "Automation", "SmallPlatesInInstances" },
          },
          HideFriendlyInInstances = {
            name = L["Hide Friendly Nameplates"],
            order = 60,
            type = "toggle",
            width = "double",
            desc = L["Hide the Blizzard default nameplates for friendly units in instances."],
            arg = { "Automation", "HideFriendlyUnitsInInstances" },
          },
        },
      },
    },
  }

  return entry
end

local function CreateCastbarOptions()
  local entry = {
    name = L["Castbar"],
    type = "group",
    order = 30,
    set = SetThemeValue,
    args = {
      Toggles = {
        name = L["Enable"],
        type = "group",
        inline = true,
        order = 1,
        args = {
          Header = {
            name = L["These options allow you to control whether the castbar is hidden or shown on nameplates."],
            order = 10,
            type = "description",
            width = "full",
          },
          Enable = {
            name = L["Show in Healthbar View"],
            order = 20,
            type = "toggle",
            desc = L["These options allow you to control whether the castbar is hidden or shown on nameplates."],
            width = "double",
            set = function(info, val)
              if val or db.settings.castbar.ShowInHeadlineView then
                Addon:EnableCastBars()
              else
                Addon:DisableCastBars()
              end
              SetThemeValue(info, val)
            end,
            arg = { "settings", "castbar", "show" },
          },
          EnableHV = {
            name = L["Show in Headline View"],
            order = 30,
            type = "toggle",
            width = "double",
            set = function(info, val)
              if val or db.settings.castbar.show then
                Addon:EnableCastBars()
              else
                Addon:DisableCastBars()
              end
              SetThemeValue(info, val)
            end,
            arg = {"settings", "castbar", "ShowInHeadlineView" },
          },
        },
      },
      Format = {
        name = L["Format"],
        order = 5,
        type = "group",
        inline = true,
        set = SetThemeValue,
        args = {
          Width = GetRangeEntry(L["Bar Width"], 10, { "settings", "castbar", "width" }, 5, 500),
          Height = GetRangeEntry(L["Bar Height"], 20, {"settings", "castbar", "height" }, 1, 100),
          Spacer1 = GetSpacerEntry(25),
          EnableSpellText = {
            name = L["Spell Text"],
            order = 30,
            type = "toggle",
            desc = L["This option allows you to control whether a spell's name is hidden or shown on castbars."],
            arg = { "settings", "spelltext", "show" },
          },
          EnableSpellIcon = {
            name = L["Spell Icon"],
            order = 40,
            type = "toggle",
            desc = L["This option allows you to control whether a spell's icon is hidden or shown on castbars."],
            arg = { "settings", "spellicon", "show" },
          },
          EnableSpark = {
            name = L["Spark"],
            order = 45,
            type = "toggle",
            arg = { "settings", "castbar", "ShowSpark" },
          },
          EnableCastBarBorder = {
            type = "toggle",
            order = 50,
            name = L["Border"],
            desc = L["Shows a border around the castbar of nameplates (requires /reload)."],
            arg = { "settings", "castborder", "show" },
          },
          EnableCastBarOverlay = {
            name = L["Interrupt Overlay"],
            order = 60,
            type = "toggle",
            disabled = function() return not db.settings.castborder.show end,
            arg = { "settings", "castnostop", "ShowOverlay" },
          },
          EnableInterruptShield = {
            name = L["Interrupt Shield"],
            order = 70,
            type = "toggle",
            arg = { "settings", "castnostop", "ShowInterruptShield" },
          },
        },
      },
      Textures = {
        name = L["Textures & Colors"],
        order = 10,
        type = "group",
        inline = true,
        args = {
          CastBarTexture = {
            name = L["Foreground"],
            type = "select",
            order = 10,
            dialogControl = "LSM30_Statusbar",
            values = AceGUIWidgetLSMlists.statusbar,
            arg = { "settings", "castbar", "texture" },
          },
          BGTexture = {
            name = L["Background"],
            type = "select",
            order = 20,
            dialogControl = "LSM30_Statusbar",
            values = AceGUIWidgetLSMlists.statusbar,
            arg = { "settings", "castbar", "backdrop" },
          },
          CastBarBorder = {
            type = "select",
            order = 25,
            name = L["Border"],
            values = { TP_Castbar_Border_Default = "Default", TP_Castbar_Border_Thin = "Thin" },
            set = function(info, val)
              if val == "TP_Castbar_Border_Default" then
                db.settings.castborder.EdgeSize = 2
                db.settings.castborder.Offset = 2
              else
                db.settings.castborder.EdgeSize = 1
                db.settings.castborder.Offset = 1
              end
              SetThemeValue(info, val)
            end,
            arg = { "settings", "castborder", "texture" },
          },
          Spacer1 = GetSpacerEntry(30),
          BGColorText = {
            type = "description",
            order = 40,
            width = "single",
            name = L["Background Color:"],
          },
          BGColorForegroundToggle = {
            name = L["Same as Foreground"],
            order = 50,
            type = "toggle",
            desc = L["Use the castbar's foreground color also for the background."],
            arg = { "settings", "castbar", "BackgroundUseForegroundColor" },
          },
          BGColorCustomToggle = {
            name = L["Custom"],
            order = 60,
            type = "toggle",
            width = "half",
            desc = L["Use a custom color for the castbar's background."],
            set = function(info, val)
              SetThemeValue(info, not val)
            end,
            get = function(info, val)
              return not GetValue(info, val)
            end,
            arg = { "settings", "castbar", "BackgroundUseForegroundColor" },
          },
          BGColorCustom = {
            name = L["Color"], type = "color",	order = 70,	get = GetColor, set = SetColor, arg = {"settings", "castbar", "BackgroundColor"},
            width = "half",
            disabled = function() return db.settings.castbar.BackgroundUseForegroundColor end,
          },
          BackgroundOpacity = {
            name = L["Background Transparency"],
            order = 80,
            type = "range",
            min = 0,
            max = 1,
            step = 0.01,
            isPercent = true,
            arg = { "settings", "castbar", "BackgroundOpacity" },
          },
          Spacer2 = GetSpacerEntry(90),
          SpellColor = {
            type = "description",
            order = 100,
            width = "single",
            name = L["Spell Color:"],
          },
          Interruptable = {
            name = L["Interruptable"],
            type = "color",
            order = 110,
            --width = "double",
            get = GetColorAlpha,
            set = SetColorAlpha,
            arg = { "castbarColor" },
          },
          Shielded = {
            name = L["Non-Interruptable"],
            type = "color",
            order = 120,
            --width = "double",
            get = GetColorAlpha,
            set = SetColorAlpha,
            arg = { "castbarColorShield" }
          },
          Interrupted = {
            name = L["Interrupted"],
            type = "color",
            order = 130,
            --width = "double",
            get = GetColorAlpha,
            set = SetColorAlpha,
            arg = { "castbarColorInterrupted" }
          },
        },
      },
      Appeareance = {
        name = L["Appearance"],
        order = 20,
        type = "group",
        inline = true,
        args = {
          Size = GetSizeEntry(L["Spell Icon Size"], 10, { "settings", "spellicon", "scale" }),
          Font = GetFontEntry(L["Spell Text"], 20, "spelltext"),
          Align = {
            name = L["Spell Text Alignment"],
            order = 30,
            type = "group",
            inline = true,
            args = {
              AlignH = {
                name = L["Horizontal Align"],
                type = "select",
                width = "double",
                order = 110,
                values = t.AlignH,
                arg = { "settings", "spelltext", "align" },
              },
              AlignV = {
                name = L["Vertical Align"],
                type = "select",
                width = "double",
                order = 120,
                values = t.AlignV,
                arg = { "settings", "spelltext", "vertical" },
              },
            },
          },
          Boundaries = GetBoundariesEntryName(L["Spell Text Boundaries"], 40, "spelltext"),
        },
      },
      Placement = {
        name = L["Placement"],
        type = "group",
        inline = true,
        order = 40,
        args = {
          Castbar = {
            name = L["Castbar"],
            order = 20,
            type = "group",
            inline = true,
            args = {
              Castbar_X_HB = {
                name = L["Healthbar View X"],
                order = 10,
                type = "range",
                min = -60,
                max = 60,
                step = 1,
                set = SetThemeValue,
                arg = { "settings", "castbar", "x" },
              },
              Castbar_Y_HB = {
                name = L["Healthbar View Y"],
                order = 20,
                type = "range",
                min = -60,
                max = 60,
                step = 1,
                set = SetThemeValue,
                arg = { "settings", "castbar", "y" },
              },
              Castbar_X_Names = GetPlacementEntry(L["Headline View X"], 30, { "settings", "castbar", "x_hv" } ),
              Castbar_Y_Names = GetPlacementEntry(L["Headline View Y"], 40, { "settings", "castbar", "y_hv" }),
              Spacer1 = GetSpacerEntry(50),
              TargetOffsetX = GetPlacementEntry(L["Target Offset X"], 60, { "settings", "castbar", "x_target" } ),
              TargetOffsetY = GetPlacementEntry(L["Target Offset Y"], 70, { "settings", "castbar", "y_target" } ),
            },
          },
          Spellicon = {
            name = L["Spell Icon"],
            order = 20,
            type = "group",
            inline = true,
            args = {
              Spellicon_X_HB = GetPlacementEntry(L["Healthbar View X"], 150, { "settings", "spellicon", "x" }),
              Spellicon_Y_HB = GetPlacementEntry(L["Healthbar View Y"], 160, { "settings", "spellicon", "y" }),
              Spellicon_X_Names = GetPlacementEntry(L["Headline View X"], 170, { "settings", "spellicon", "x_hv" }),
              Spellicon_Y_Names = GetPlacementEntry(L["Headline View Y"], 180, { "settings", "spellicon", "y_hv" }),
            },
          },
          Spelltext = {
            name = L["Spell Text"],
            order = 30,
            type = "group",
            inline = true,
            args = {
              Spelltext_X_HB = GetPlacementEntry(L["Healthbar View X"], 60, { "settings", "spelltext", "x" }),
              Spelltext_Y_HB = GetPlacementEntry(L["Healthbar View Y"], 70, { "settings", "spelltext", "y" }),
              Spelltext_X_Names = GetPlacementEntry(L["Headline View X"], 80, { "settings", "spelltext", "x_hv" }),
              Spelltext_Y_Names = GetPlacementEntry(L["Headline View Y"], 90, { "settings", "spelltext", "y_hv" }),
            },
          },
        },
      },
      Config = {
        name = L["Configuration Mode"],
        order = 100,
        type = "group",
        inline = true,
        args = {
          Toggle = {
            name = L["Toggle on Target"],
            type = "execute",
            order = 1,
            width = "full",
            func = function()
              Addon:ConfigCastbar()
            end,
          },
        },
      },
    },
  }

  return entry
end

local function CreateWidgetOptions()
  local options = {
    name = L["Widgets"],
    type = "group",
    order = 40,
    args = {
      --ArenaWidget = CreateArenaWidgetOptions(),
      AurasWidget = CreateAurasWidgetOptions(),
      BossModsWidget = CreateBossModsWidgetOptions(),
      ClassIconWidget = CreateClassIconsWidgetOptions(),
      ComboPointsWidget = CreateComboPointsWidgetOptions(),
      ResourceWidget = CreateResourceWidgetOptions(),
      SocialWidget = CreateSocialWidgetOptions(),
      --StealthWidget = CreateStealthWidgetOptions(),
      TargetArtWidget = CreateTargetArtWidgetOptions(),
      --QuestWidget = CreateQuestWidgetOptions(),
      HealerTrackerWidget = CreateHealerTrackerWidgetOptions(),
    },
  }

  return options
end

local function CreateSpecRoles()
  -- Create a list of specs for the player's class
  local result = {
    Automatic_Spec_Detection = {
      name = L["Determine your role (tank/dps/healing) automatically based on current stance (Warrior) or form (Druid)."],
      type = "toggle",
      width = "full",
      order = 1,
      arg = { "optionRoleDetectionAutomatic" }
    },
    SpecGroup = {
      name = " ",
      type = "group",
      inline = true,
      order = 3,
      args = {
        Tank = {
          name = L["Tank"],
          type = "toggle",
          order = 1,
          desc = L["Sets your role to tanking."],
          get = function()
            return TidyPlatesThreat.db.char.spec[1]
          end,
          set = function() TidyPlatesThreat.db.char.spec[1] = true; Addon:ForceUpdate() end,
        },
        DPS = {
          name = L["DPS/Healing"],
          type = "toggle",
          order = 2,
          desc = L["Sets your role to DPS."],
          get = function()
            return not TidyPlatesThreat.db.char.spec[1]
          end,
          set = function() TidyPlatesThreat.db.char.spec[1] = false; Addon:ForceUpdate() end,
        },
      }
    }
  }

  return result
end

local function CreateCustomNameplatesGroup()
  local entry = {
    NewSlot = {
      name = L["New"],
      order = 1,
      type = "execute",
      width = "half",
      func = function(info)
        local slot_no = #db.uniqueSettings + 1
        local unique_unit = db.uniqueSettings[slot_no]
        unique_unit.name = ""

        options.args.Custom.args = CreateCustomNameplatesGroup()
        UpdateSpecial()

        Addon.LibAceConfigDialog:SelectGroup(t.ADDON_NAME, "Custom", "#" ..  slot_no)
      end,
      hidden = function() return TidyPlatesThreat.db.global.CustomNameplatesVersion == 1 end,
    },
    DeleteSlot = {
      name = L["Delete"],
      order = 2,
      type = "execute",
      width = "half",
      func = function()
        local statustable = Addon.LibAceConfigDialog:GetStatusTable(t.ADDON_NAME, { "Custom" })
        local selected = statustable.groups.selected

        local slot_no = selected:match("#(.*)")
        if slot_no then
          table.remove(db.uniqueSettings, slot_no)

          options.args.Custom.args = CreateCustomNameplatesGroup()
          UpdateSpecial()
        end
      end,
      confirm = function(info)
        local statustable = Addon.LibAceConfigDialog:GetStatusTable(t.ADDON_NAME, { "Custom" })
        local selected = statustable.groups.selected
        local slot_no = selected:match("#(.*)")

        if slot_no then
          return L["|cffFF0000DELETE CUSTOM NAMEPLATE|r\nAre you sure you want to delete the selected custom nameplate?"]
        else
          t.Print(L["You cannot delete General Settings, only custom nameplates entries."], true)
          return false
        end
      end,
      hidden = function() return TidyPlatesThreat.db.global.CustomNameplatesVersion == 1 end,
    },
    MigrateVersion1 = {
      name = L["|cffFFFFFFMigrate Custom Nameplates Settings|r"],
      order = 3,
      type = "execute",
      width = "full",
      func = function()
        Addon.MigrationCustomNameplatesV1()

        options.args.Custom.args = CreateCustomNameplatesGroup()
        UpdateSpecial()
      end,
      confirm = function(info) return L["|cffFF0000NOTE|r\nMigration should only delete deprecated default custom nameplates and re-order the remaining ones. Nevertheless, it is highly advised to backup your settings (the SavedVariables file TidyPlates_ThreatPlates.lua) in case something goes wrong.\n\nAre you sure you want to migrate your custom nameplates?"] end,
      hidden = function() return TidyPlatesThreat.db.global.CustomNameplatesVersion > 1 end,
    },
    Spacer1 = GetSpacerEntry(3),
    GeneralSettings = {
      name = L["|cffffffffGeneral Settings|r"],
      type = "group",
      order = 10,
      args = {
        Icon = {
          name = L["Icon"],
          type = "group",
          order = 20,
          inline = true,
          args = {
            Help = {
              name = L["Disabling this will turn off all icons for custom nameplates without harming other custom settings per nameplate."],
              order = 0,
              type = "description",
              width = "full",
            },
            Enable = {
              name = L["Enable"],
              order = 10,
              type = "toggle",
              width = "half",
              set = function(info, val)
                SetValuePlain(info, val);
                Addon.Widgets:InitializeWidget("UniqueIcon")
              end,
              arg = { "uniqueWidget", "ON" }
            },
            Size = GetSizeEntryDefault(10, "uniqueWidget"),
            Placement = GetPlacementEntryWidget(30, "uniqueWidget", true),
          },
        },
      },
    },
  }

  local clipboard = nil;

  for index, unique_unit in pairs(db.uniqueSettings) do
    if type(index) == "number" and unique_unit.name and unique_unit.name ~= "<Enter name here>" then
      entry["#" .. index] = {
        name = "#" .. index .. ". " .. db.uniqueSettings[index].name,
        type = "group",
        order = 30 + index,
        args = {
          Header = {
            name = db.uniqueSettings[index].name,
            type = "header",
            order = 0,
          },
          Name = {
            name = L["Set Name"],
            order = 1,
            type = "group",
            inline = true,
            args = {
              SetName = {
                name = db.uniqueSettings[index].name,
                type = "input",
                order = 1,
                width = "full",
                set = function(info, val)
                  SetValue(info, val)
                  options.args.Custom.args["#" .. index].name = "#" .. index .. ". " .. val
                  options.args.Custom.args["#" .. index].args.Header.name = val
                  options.args.Custom.args["#" .. index].args.Name.args.SetName.name = val
                  UpdateSpecial()
                end,
                arg = { "uniqueSettings", index, "name" },
              },
              TargetButton = {
                name = L["Use Target's Name"],
                type = "execute",
                order = 2,
                width = "single",
                func = function()
                  if UnitExists("target") then
                    local target = UnitName("target")
                    db.uniqueSettings[index].name = target
                    options.args.Custom.args["#" .. index].name = "#" .. index .. ". " .. target
                    options.args.Custom.args["#" .. index].args.Header.name = target
                    options.args.Custom.args["#" .. index].args.Name.args.SetName.name = target
                    UpdateSpecial()
                  else
                    t.Print(L["No target found."])
                  end
                end,
              },
              Copy = {
                name = L["Copy"],
                order = 5,
                type = "execute",
                func = function()
                  clipboard = {}
                  clipboard = t.CopyTable(db.uniqueSettings[index])
                  t.Print(L["Copied!"])
                end,
              },
              Paste = {
                name = L["Paste"],
                order = 6,
                type = "execute",
                func = function()
                  if type(clipboard) == "table" and clipboard.name then
                    db.uniqueSettings[index] = t.CopyTable(clipboard)
                    t.Print(L["Pasted!"])
                  else
                    t.Print(L["Nothing to paste!"])
                  end
                  options.args.Custom.args["#" .. index].name = "#" .. index .. ". " .. db.uniqueSettings[index].name
                  options.args.Custom.args["#" .. index].args.Header.name = db.uniqueSettings[index].name
                  options.args.Custom.args["#" .. index].args.Name.args.SetName.name = db.uniqueSettings[index].name
                  local spell_id = db.uniqueSettings[index].SpellID
                  if spell_id then
                    local _, _, icon = GetSpellInfo(spell_id)
                    options.args.Custom.args["#" .. index].args.Icon.args.Icon.image = icon
                  else
                    local icon_path = db.uniqueSettings[index].icon
                    if icon_path:sub(-4) == ".blp" then
                      options.args.Custom.args["#" .. index].args.Icon.args.Icon.image = "Interface\\Icons\\" .. icon_path
                    else
                      options.args.Custom.args["#" .. index].args.Icon.args.Icon.image = icon_path
                    end
                  end
                  UpdateSpecial()
                  clipboard = nil
                end,
              },
            },
          },
          Enable = {
            name = L["Nameplate Style"],
            type = "group",
            inline = true,
            order = 10,
            args = {
              UseStyle = {
                name = L["Enable"],
                order = 1,
                type = "toggle",
                desc = L["This option allows you to control whether custom settings for nameplate style, color, transparency and scaling should be used for this nameplate."],
                arg = { "uniqueSettings", index, "useStyle" },
              },
              HeadlineView = {
                name = L["Healthbar View"],
                order = 20,
                type = "toggle",
                disabled = function() return not db.uniqueSettings[index].useStyle end,
                set = function(info, val) if val then db.uniqueSettings[index].ShowHeadlineView = false; SetValue(info, val) end end,
                arg = { "uniqueSettings", index, "showNameplate" },
              },
              HealthbarView = {
                name = L["Headline View"],
                order = 30,
                type = "toggle",
                disabled = function() return not db.uniqueSettings[index].useStyle end,
                set = function(info, val) if val then db.uniqueSettings[index].showNameplate = false; SetValue(info, val) end end,
                arg = { "uniqueSettings", index, "ShowHeadlineView" },
              },
              HideNameplate = {
                name = L["Hide Nameplate"],
                order = 40,
                type = "toggle",
                desc = L["Disables nameplates (healthbar and name) for the units of this type and only shows an icon (if enabled)."],
                disabled = function() return not db.uniqueSettings[index].useStyle end,
                set = function(info, val)
                  if val then
                    db.uniqueSettings[index].showNameplate = false;
                    db.uniqueSettings[index].ShowHeadlineView = false;
                    Addon:ForceUpdate()
                  end
                end,
                get = function(info) return not(db.uniqueSettings[index].showNameplate or db.uniqueSettings[index].ShowHeadlineView) end,
              },
            },
          },
          Appearance = {
            name = L["Appearance"],
            type = "group",
            order = 30,
            inline = true,
            disabled = function() return not db.uniqueSettings[index].useStyle end,
            args = {
              CustomColor = {
                name = L["Custom Color"],
                order = 1,
                type = "toggle",
                desc = L["Define a custom color for this nameplate and overwrite any other color settings."],
                arg = { "uniqueSettings", index, "useColor" },
              },
              ColorSetting = {
                name = L["Color"],
                order = 2,
                type = "color",
                disabled = function() return not db.uniqueSettings[index].useStyle or not db.uniqueSettings[index].useColor end,
                get = GetColor,
                set = SetColor,
                arg = { "uniqueSettings", index, "color" },
              },
              --            ColorThreatSystem = {
              --              name = L["Use Threat Coloring"],
              --              order = 3,
              --              type = "toggle",
              --              desc = L["In combat, use coloring based on threat level as configured in the threat system. The custom color is only used out of combat."],
              --              disabled = function() return not db.uniqueSettings[k_c].useStyle or not db.uniqueSettings[k_c].useColor end,
              --              arg = {"uniqueSettings", k_c, "UseThreatColor"},
              --            },
              UseRaidMarked = {
                name = L["Color by Target Mark"],
                order = 4,
                type = "toggle",
                desc = L["Additionally color the nameplate's healthbar or name based on the target mark if the unit is marked."],
                disabled = function() return not db.uniqueSettings[index].useStyle or not db.uniqueSettings[index].useColor end,
                arg = { "uniqueSettings", index, "allowMarked" },
              },
              Spacer1 = GetSpacerEntry(10),
              CustomAlpha = {
                name = L["Custom Transparency"],
                order = 11,
                type = "toggle",
                desc = L["Define a custom transparency for this nameplate and overwrite any other transparency settings."],
                set = function(info, val) SetValue(info, not val) end,
                get = function(info) return not GetValue(info) end,
                arg = { "uniqueSettings", index, "overrideAlpha" },
              },
              AlphaSetting = GetTransparencyEntryDefault(12, { "uniqueSettings", index, "alpha" }, function() return not db.uniqueSettings[index].useStyle or db.uniqueSettings[index].overrideAlpha end),
              --            AlphaThreatSystem = {
              --              name = L["Use Threat Alpha"],
              --              order = 13,
              --              type = "toggle",
              --              desc = L["In combat, use alpha based on threat level as configured in the threat system. The custom alpha is only used out of combat."],
              --              disabled = function() return not db.uniqueSettings[k_c].useStyle or db.uniqueSettings[k_c].overrideAlpha end,
              --              arg = {"uniqueSettings", k_c, "UseThreatColor"},
              --            },
              Spacer2 = GetSpacerEntry(14),
              CustomScale = {
                name = L["Custom Scale"],
                order = 21,
                type = "toggle",
                desc = L["Define a custom scaling for this nameplate and overwrite any other scaling settings."],
                set = function(info, val) SetValue(info, not val) end,
                get = function(info) return not GetValue(info) end,
                arg = { "uniqueSettings", index, "overrideScale" },
              },
              ScaleSetting = GetScaleEntryDefault(22, { "uniqueSettings", index, "scale" }, function() return not db.uniqueSettings[index].useStyle or db.uniqueSettings[index].overrideScale end),
              --            ScaleThreatSystem = {
              --              name = L["Use Threat Scale"],
              --              order = 23,
              --              type = "toggle",
              --              desc = L["In combat, use scaling based on threat level as configured in the threat system. The custom scale is only used out of combat."],
              --              disabled = function() return not db.uniqueSettings[k_c].useStyle or db.uniqueSettings[k_c].overrideScale end,
              --              arg = {"uniqueSettings", k_c, "UseThreatColor"},
              --            },
              --            Spacer3 = GetSpacerEntry(24),
              Header = { type = "header", order = 24, name = "Threat Options", },
              ThreatGlow = {
                name = L["Threat Glow"],
                order = 31,
                type = "toggle",
                desc = L["Shows a glow based on threat level around the nameplate's healthbar (in combat)."],
                disabled = function() return not db.uniqueSettings[index].useStyle end,
                arg = { "uniqueSettings", index, "UseThreatGlow"},
              },
              ThreatSystem = {
                name = L["Enable Threat System"],
                order = 32,
                type = "toggle",
                desc = L["In combat, use coloring, transparency, and scaling based on threat level as configured in the threat system. Custom settings are only used out of combat."],
                disabled = function() return not db.uniqueSettings[index].useStyle end,
                arg = { "uniqueSettings", index, "UseThreatColor"},
              },
            },
          },
          Icon = {
            name = L["Icon"],
            type = "group",
            order = 40,
            inline = true,
            disabled = function() return not db.uniqueWidget.ON end,
            args = {
              Enable = {
                name = L["Enable"],
                type = "toggle",
                order = 1,
                desc = L["This option allows you to control whether the custom icon is hidden or shown on this nameplate."],
                descStyle = "inline",
                width = "full",
                arg = { "uniqueSettings", index, "showIcon" }
              },
              Icon = {
                name = L["Preview"],
                type = "execute",
                width = "full",
                disabled = function() return not db.uniqueSettings[index].showIcon or not db.uniqueWidget.ON end,
                order = 2,
                image = function()
                  local spell_id = db.uniqueSettings[index].SpellID
                  if spell_id then
                    local _, _, icon = GetSpellInfo(spell_id)
                    return icon
                  else
                    local icon_path = db.uniqueSettings[index].icon
                    if icon_path:sub(-4) == ".blp" then
                      return "Interface\\Icons\\" .. icon_path
                    else
                      return icon_path
                    end
                  end
                end,
                imageWidth = 64,
                imageHeight = 64,
              },
              Description = {
                type = "description",
                order = 3,
                name = L["Enter an icons name (with the *.blp ending), a spell ID or a full icon path (using '\\' to separate directory folders)."],
                width = "full",
              },
              SetIcon = {
                name = L["Set Icon"],
                type = "input",
                order = 4,
                disabled = function() return not db.uniqueSettings[index].showIcon or not db.uniqueWidget.ON end,
                width = "full",
                set = function(info, val)
                  local spell_id = tonumber(val)
                  if spell_id then -- no string, so val should be a spell ID
                    local _, _, icon = GetSpellInfo(spell_id)
                    if icon then
                      db.uniqueSettings[index].SpellID = spell_id
                      val = select(3, GetSpellInfo(spell_id))
                    else
                      t.Print("Invalid spell ID for custom nameplate icon: " .. val, true)
                      db.uniqueSettings[index].SpellID = nil
                    end
                  else
                    db.uniqueSettings[index].SpellID = nil
                  end
                  -- Either store the path to the icon or the icon ID
                  SetValue(info, val)
                  if val then
                    if val:sub(-4) == ".blp" then
                      options.args.Custom.args["#" .. index].args.Icon.args.Icon.image = "Interface\\Icons\\" .. val
                    else
                      options.args.Custom.args["#" .. index].args.Icon.args.Icon.image = val
                    end
                  else
                    options.args.Custom.args["#" .. index].args.Icon.args.Icon.image = "Interface\\Icons\\Temp"
                  end
                  UpdateSpecial()
                end,
                get = function(info)
                  local spell_id = db.uniqueSettings[index].SpellID
                  if spell_id then
                    return tostring(spell_id)
                  else
                    return GetValue(info)
                  end
                end,
                arg = { "uniqueSettings", index, "icon" },
              },
            },
          },
        },
      }
    end
  end

  return entry
end

-- Return the Options table
local function CreateOptionsTable()
  if not options then
    options = {
      name = GetAddOnMetadata("TidyPlates_ThreatPlates", "title"),
      handler = TidyPlatesThreat,
      type = "group",
      childGroups = "tab",
      get = GetValue,
      set = SetValue,
      args = {
        -- Config Guide
        NameplateSettings = {
          name = L["General"],
          type = "group",
          order = 10,
          args = {
            GeneralSettings = CreateVisibilitySettings(),
            AutomationSettings = CreateAutomationSettings(),
            HealthBarView = {
              name = L["Healthbar View"],
              type = "group",
              inline = false,
              order = 20,
              args = {
                Design = {
                  name = L["Default Settings (All Profiles)"],
                  type = "group",
                  inline = true,
                  order = 1,
                  args = {
                    HealthBarTexture = {
                      name = L["Look and Feel"],
                      order = 1,
                      type = "select",
                      desc = L["Changes the default settings to the selected design. Some of your custom settings may get overwritten if you switch back and forth.."],
                      values = { CLASSIC = "Classic", SMOOTH = "Smooth" } ,
                      set = function(info, val)
                        TidyPlatesThreat.db.global.DefaultsVersion = val
                        if val == "CLASSIC" then
                          t.SwitchToDefaultSettingsV1()
                        else -- val == "SMOOTH"
                          t.SwitchToCurrentDefaultSettings()
                        end
                        TidyPlatesThreat:ReloadTheme()
                      end,
                      get = function(info) return TidyPlatesThreat.db.global.DefaultsVersion end,
                    },
                  },
                },
                Format = {
                  name = L["Format"],
                  order = 5,
                  type = "group",
                  inline = true,
                  set = SetThemeValue,
                  args = {
                    Width = GetRangeEntry(L["Bar Width"], 10, { "settings", "healthbar", "width" }, 5, 500,
                      function(info, val)
                        if InCombatLockdown() then
                          t.Print("We're unable to change this while in combat", true)
                        else
                          SetThemeValue(info, val)
                          Addon:SetBaseNamePlateSize()
                        end
                      end),
                    Height = GetRangeEntry(L["Bar Height"], 20, {"settings", "healthbar", "height" }, 1, 100,
                      function(info, val)
                        if InCombatLockdown() then
                          t.Print("We're unable to change this while in combat", true)
                        else
                          SetThemeValue(info, val)
                          Addon:SetBaseNamePlateSize()
                        end
                      end),
                    Spacer1 = GetSpacerEntry(25),
                    --ShowHealAbsorbs = {
                    --  name = L["Heal Absorbs"],
                    --  order = 29,
                    --  type = "toggle",
                    --  arg = { "settings", "healthbar", "ShowHealAbsorbs" },
                    --},
                    --ShowAbsorbs = {
                    --  name = L["Absorbs"],
                    --  order = 30,
                    --  type = "toggle",
                    --  arg = { "settings", "healthbar", "ShowAbsorbs" },
                    --},
                    ShowMouseoverHighlight = {
                      type = "toggle",
                      order = 40,
                      name = L["Mouseover"],
                      set = SetThemeValue,
                      arg = { "settings", "highlight", "show" },
                    },
                    ShowBorder = {
                      type = "toggle",
                      order = 50,
                      name = L["Border"],
                      set = SetThemeValue,
                      arg = { "settings", "healthborder", "show" },
                    },
                    ShowEliteBorder = {
                      type = "toggle",
                      order = 60,
                      name = L["Elite Border"],
                      arg = { "settings", "elitehealthborder", "show" },
                    },
                  }
                },
                HealthBarGroup = {
                  name = L["Textures"],
                  type = "group",
                  inline = true,
                  order = 10,
                  args = {
                    HealthBarTexture = {
                      name = L["Foreground"],
                      type = "select",
                      order = 10,
                      dialogControl = "LSM30_Statusbar",
                      values = AceGUIWidgetLSMlists.statusbar,
                      set = SetThemeValue,
                      arg = { "settings", "healthbar", "texture" },
                    },
                    BGTexture = {
                      name = L["Background"],
                      type = "select",
                      order = 20,
                      dialogControl = "LSM30_Statusbar",
                      values = AceGUIWidgetLSMlists.statusbar,
                      set = SetThemeValue,
                      arg = { "settings", "healthbar", "backdrop" },
                    },
                    HealthBorder = {
                      type = "select",
                      order = 25,
                      name = L["Border"],
                      set = function(info, val)
                        if val == "TP_Border_Default" then
                          db.settings.healthborder.EdgeSize = 2
                          db.settings.healthborder.Offset = 2
                        else
                          db.settings.healthborder.EdgeSize = 1
                          db.settings.healthborder.Offset = 1
                        end
                        SetThemeValue(info, val)
                      end,
                      values = { TP_Border_Default = "Default", TP_Border_Thin = "Thin" },
                      arg = { "settings", "healthborder", "texture" },
                    },
                    EliteBorder = {
                      type = "select",
                      order = 26,
                      name = L["Elite Border"],
                      values = { TP_EliteBorder_Default = "Default", TP_EliteBorder_Thin = "Thin" },
                      set = SetThemeValue,
                      arg = { "settings", "elitehealthborder", "texture" }
                    },
                    Spacer1 = GetSpacerEntry(30),
                    BGColorText = {
                      type = "description",
                      order = 40,
                      width = "single",
                      name = L["Background Color:"],
                    },
                    BGColorForegroundToggle = {
                      name = L["Same as Foreground"],
                      order = 50,
                      type = "toggle",
                      desc = L["Use the healthbar's foreground color also for the background."],
                      set = SetThemeValue,
                      arg = { "settings", "healthbar", "BackgroundUseForegroundColor" },
                    },
                    BGColorCustomToggle = {
                      name = L["Custom"],
                      order = 60,
                      type = "toggle",
                      width = "half",
                      desc = L["Use a custom color for the healtbar's background."],
                      set = function(info, val)
                        SetThemeValue(info, not val)
                      end,
                      get = function(info, val)
                        return not GetValue(info, val)
                      end,
                      arg = { "settings", "healthbar", "BackgroundUseForegroundColor" },
                    },
                    BGColorCustom = {
                      name = L["Color"],
                      order = 70,
                      type = "color",
                      get = GetColor, set = SetColor, arg = {"settings", "healthbar", "BackgroundColor"},
                      width = "half",
                      disabled = function() return db.settings.healthbar.BackgroundUseForegroundColor end,
                    },
                    BackgroundOpacity = {
                      name = L["Background Transparency"],
                      order = 80,
                      type = "range",
                      min = 0,
                      max = 1,
                      step = 0.01,
                      isPercent = true,
                      arg = { "settings", "healthbar", "BackgroundOpacity" },
                    },
                    --AbsorbGroup = {
                    --  name = L["Absorbs"],
                    --  order = 90,
                    --  type = "group",
                    --  inline = true,
                    --  args = {
                    --    AbsorbColor = {
                    --      name = L["Color"],
                    --      order = 110,
                    --      type = "color",
                    --      get = GetColorAlpha,
                    --      set = SetColorAlpha,
                    --      hasAlpha = true,
                    --      arg = { "settings", "healthbar", "AbsorbColor" },
                    --    },
                    --    AlwaysFullAbsorb = {
                    --      name = L["Full Absorbs"],
                    --      order = 120,
                    --      type = "toggle",
                    --      desc = L["Always shows the full amount of absorbs on a unit. In overabsorb situations, the absorbs bar ist shifted to the left."],
                    --      arg = { "settings", "healthbar", "AlwaysFullAbsorb" },
                    --    },
                    --    OverlayTexture = {
                    --      name = L["Striped Texture"],
                    --      order = 130,
                    --      type = "toggle",
                    --      desc = L["Use a striped texture for the absorbs overlay. Always enabled if full absorbs are shown."],
                    --      get = function(info) return GetValue(info) or db.settings.healthbar.AlwaysFullAbsorb end,
                    --      disabled = function() return db.settings.healthbar.AlwaysFullAbsorb end,
                    --      arg = { "settings", "healthbar", "OverlayTexture" },
                    --    },
                    --    OverlayColor = {
                    --      name = L["Striped Texture Color"],
                    --      order = 140,
                    --      type = "color",
                    --      get = GetColorAlpha,
                    --      set = SetColorAlpha,
                    --      hasAlpha = true,
                    --      arg = { "settings", "healthbar", "OverlayColor" },
                    --    },
                    --  },
                    --},
                  },
                },
                ShowByStatus = {
                  name = L["Force View By Status"],
                  order = 15,
                  type = "group",
                  inline = true,
                  args = {
                    ModeOnTarget = {
                      name = L["On Target"],
                      order = 1,
                      type = "toggle",
                      width = "double",
                      arg = { "HeadlineView", "ForceHealthbarOnTarget" }
                    },
                  }
                },
                ColorSettings = {
                  name = L["Coloring"],
                  type = "group",
                  inline = true,
                  order = 20,
                  args = {
                    General = {
                      name = L["General Colors"],
                      order = 10,
                      type = "group",
                      inline = true,
                      get = GetColor,
                      set = SetColor,
                      args = {
                        TappedColor = { name = L["Tapped Units"], order = 1, type = "color", arg = { "ColorByReaction", "TappedUnit" }, },
                        DCedColor = { name = L["Disconnected Units"], order = 2, type = "color", arg = { "ColorByReaction", "DisconnectedUnit" }, },
                      },
                    },
                    HPAmount = {
                      name = L["Color by Health"],
                      order = 20,
                      type = "group",
                      inline = true,
                      args = {
                        ColorByHPLevel = {
                          name = L["Change the color depending on the amount of health points the nameplate shows."],
                          order = 10,
                          type = "toggle",
                          width = "full",
                          arg = { "healthColorChange" },
                        },
                        Header = { name = L["Colors"], type = "header", order = 20, },
                        ColorLow = {
                          name = "Low Color",
                          order = 30,
                          type = "color",
                          desc = "",
                          descStyle = "inline",
                          get = GetColor,
                          set = SetColor,
                          arg = { "aHPbarColor" },
                        },
                        ColorHigh = {
                          name = "High Color",
                          order = 40,
                          type = "color",
                          desc = "",
                          descStyle = "inline",
                          get = GetColor,
                          set = SetColor,
                          arg = { "bHPbarColor" },
                        },
                      },
                    },
                    ClassColors = {
                      name = L["Color By Class"],
                      order = 30,
                      type = "group",
                      disabled = function() return db.healthColorChange end,
                      inline = true,
                      args = {
                        Enable = {
                          name = L["Color Healthbar By Enemy Class"],
                          order = 1,
                          type = "toggle",
                          descStyle = "inline",
                          width = "double",
                          arg = { "allowClass" }
                        },
                        FriendlyClass = {
                          name = L["Color Healthbar By Friendly Class"],
                          order = 2,
                          type = "toggle",
                          descStyle = "inline",
                          width = "double",
                          arg = { "friendlyClass" },
                        },
--                        FriendlyCaching = {
--                          name = L["Friendly Caching"],
--                          order = 3,
--                          type = "toggle",
--                          desc = L["This allows you to save friendly player class information between play sessions or nameplates going off the screen. |cffff0000(Uses more memory)"],
--                          descStyle = "inline",
--                          width = "full",
--                          arg = { "cacheClass" },
--                        },
                      },
                    },
                    Reaction = {
                      order = 20,
                      name = L["Color by Reaction"],
                      type = "group",
                      inline = true,
                      get = GetColor,
                      set = SetColor,
                      args = {
                        ColorByReaction = {
                          name = L["Change the color depending on the reaction of the unit (friendly, hostile, neutral)."],
                          type = "toggle",
                          width = "full",
                          order = 1,
                          arg = { "healthColorChange" }, -- false, if Color by Reaction (customColor), true if Color by Health
                          get = function(info) return not GetValue(info) end,
                          set = function(info, val) SetValue(info, not val) end,
                        },
                        Header = { name = L["Colors"], type = "header", order = 10, },
                        FriendlyColorNPC = { name = L["Friendly NPCs"], order = 20, type = "color", arg = { "ColorByReaction", "FriendlyNPC", }, },
                        FriendlyColorPlayer = { name = L["Friendly Players"], order = 30, type = "color", arg = { "ColorByReaction", "FriendlyPlayer" }, },
                        EnemyColorNPC = { name = L["Hostile NPCs"], order = 40, type = "color", arg = { "ColorByReaction", "HostileNPC" }, },
                        EnemyColorPlayer = { name = L["Hostile Players"], order = 50, type = "color", arg = { "ColorByReaction", "HostilePlayer" }, },
                        NeutralColor = { name = L["Neutral Units"], order = 60, type = "color", arg = { "ColorByReaction", "NeutralUnit" }, },
                      },
                    },
                    RaidMark = {
                      name = L["Color by Target Mark"],
                      order = 40,
                      type = "group",
                      inline = true,
                      get = GetColor,
                      set = SetColor,
                      args = {
                        EnableRaidMarks = {
                          name = L["Additionally color the healthbar based on the target mark if the unit is marked."],
                          order = 1,
                          type = "toggle",
                          width = "full",
                          set = SetValue,
                          get = GetValue,
                          arg = { "settings", "raidicon", "hpColor" },
                        },
                        Header = { name = L["Colors"], type = "header", order = 20, },
                        STAR = {
                          type = "color",
                          order = 30,
                          name = RAID_TARGET_1,
                          arg = { "settings", "raidicon", "hpMarked", "STAR" },
                        },
                        CIRCLE = {
                          type = "color",
                          order = 31,
                          name = RAID_TARGET_2,
                          arg = { "settings", "raidicon", "hpMarked", "CIRCLE" },
                        },
                        DIAMOND = {
                          type = "color",
                          order = 32,
                          name = RAID_TARGET_3,
                          arg = { "settings", "raidicon", "hpMarked", "DIAMOND" },
                        },
                        TRIANGLE = {
                          type = "color",
                          order = 33,
                          name = RAID_TARGET_4,
                          arg = { "settings", "raidicon", "hpMarked", "TRIANGLE" },
                        },
                        MOON = {
                          type = "color",
                          order = 34,
                          name = RAID_TARGET_5,
                          arg = { "settings", "raidicon", "hpMarked", "MOON" },
                        },
                        SQUARE = {
                          type = "color",
                          order = 35,
                          name = RAID_TARGET_6,
                          arg = { "settings", "raidicon", "hpMarked", "SQUARE" },
                        },
                        CROSS = {
                          type = "color",
                          order = 36,
                          name = RAID_TARGET_7,
                          arg = { "settings", "raidicon", "hpMarked", "CROSS" },
                        },
                        SKULL = {
                          type = "color",
                          order = 37,
                          name = RAID_TARGET_8,
                          arg = { "settings", "raidicon", "hpMarked", "SKULL" },
                        },
                      },
                    },
                  },
                },
                ThreatColors = {
                  name = L["Warning Glow for Threat"],
                  order = 30,
                  type = "group",
                  get = GetColorAlpha,
                  set = SetColorAlpha,
                  inline = true,
                  args = {
                    ThreatGlow = {
                      type = "toggle",
                      order = 1,
                      name = L["Enable"],
                      get = GetValue,
                      set = SetThemeValue,
                      arg = { "settings", "threatborder", "show" },
                    },
                    OnlyAttackedUnits = {
                      type = "toggle",
                      order = 2,
                      name = L["Threat Detection Heuristic"],
                      desc = L["Use a heuristic instead of a mob's threat table to detect if you are in combat with a mob (see Threat System - General Settings for a more detailed explanation)."],
                      width = "double",
                      set = function(info, val) SetValue(info, not val) end,
                      get = function(info) return not GetValue(info) end,
                      arg = { "ShowThreatGlowOnAttackedUnitsOnly" },
                    },
                    Header = { name = L["Colors"], type = "header", order = 10, },
                    Low = {
                      name = L["|cffffffffLow Threat|r"],
                      type = "color",
                      order = 20,
                      arg = { "settings", "normal", "threatcolor", "LOW" },
                      hasAlpha = true,
                    },
                    Med = {
                      name = L["|cffffff00Medium Threat|r"],
                      type = "color",
                      order = 30,
                      arg = { "settings", "normal", "threatcolor", "MEDIUM" },
                      hasAlpha = true,
                    },
                    High = {
                      name = L["|cffff0000High Threat|r"],
                      type = "color",
                      order = 40,
                      arg = { "settings", "normal", "threatcolor", "HIGH" },
                      hasAlpha = true,
                    },
                  },
                },
                Placement = {
                  name = L["Placement"],
                  type = "group",
                  inline = true,
                  order = 40,
                  args = {
                    Warning = {
                      type = "description",
                      order = 1,
                      name = L["Changing these settings will alter the placement of the nameplates, however the mouseover area does not follow. |cffff0000Use with caution!|r"],
                    },
                    OffsetX = {
                      name = L["Offset X"],
                      type = "range",
                      min = -60,
                      max = 60,
                      step = 1,
                      order = 2,
                      set = SetThemeValue,
                      arg = { "settings", "frame", "x" },
                    },
                    Offsety = {
                      name = L["Offset Y"],
                      type = "range",
                      min = -60,
                      max = 60,
                      step = 1,
                      order = 3,
                      set = SetThemeValue,
                      arg = { "settings", "frame", "y" },
                    },
                  },
                },
              },
            },
            HeadlineViewSettings = {
              name = L["Headline View"],
              type = "group",
              inline = false,
              order = 25,
              args = {
--                Enable = {
--                  name = L["Enable"],
--                  order = 5,
--                  type = "group",
--                  inline = true,
--                  args = {
--                    Header = {
--                      name = L["This option allows you to control whether headline view (text-only) is enabled for nameplates."],
--                      order = 1,
--                      type = "description",
--                      width = "full",
--                    },
--                    Enable = {
--                      name = L["Enable Headline View (Text-Only)"],
--                      order = 2,
--                      type = "toggle",
--                      width = "double",
--                      arg = { "HeadlineView", "ON" },
--                    },
--                  },
--                },
                ShowByUnitType = {
                  name = L["Show By Unit Type"],
                  order = 10,
                  type = "group",
                  inline = true,
                  args = CreateHeadlineViewShowEntry(),
                },
                ShowByStatus = {
                  name = L["Force View By Status"],
                  order = 15,
                  type = "group",
                  inline = true,
                  args = {
--                    ModeOoC = {
--                      name = L["Out of Combat"],
--                      order = 1,
--                      type = "toggle",
--                      width = "double",
--                      arg = { "HeadlineView", "ForceOutOfCombat" }
--                    },
--                    ModeFriendlyInCombat = {
--                      name = L["On Friendly Units in Combat"],
--                      order = 2,
--                      type = "toggle",
--                      width = "double",
--                      arg = { "HeadlineView", "ForceFriendlyInCombat" }
--                    },
                    ModeCNA = {
                      name = L["On Enemy Units You Cannot Attack"],
                      order = 3,
                      type = "toggle",
                      width = "double",
                      arg = { "HeadlineView", "ForceNonAttackableUnits" }
                    },
                  }
                },
                Appearance = {
                  name = L["Appearance"],
                  type = "group",
                  inline = true,
                  order = 20,
                  args = {
                    TextureSettings = {
                      name = L["Highlight Texture"],
                      order = 30,
                      type = "group",
                      inline = true,
                      args = {
                        TargetHighlight = {
                          name = L["Show Target"],
                          order = 10,
                          type = "toggle",
                          arg = { "HeadlineView", "ShowTargetHighlight" },
                          set = function(info, val)
                            SetValuePlain(info, val)
                            Addon.Widgets:UpdateSettings("TargetArt")
                          end,
                        },
                        TargetMouseoverHighlight = {
                          name = L["Show Mouseover"],
                          order = 20,
                          type = "toggle",
                          desc = L["Show the mouseover highlight on all units."],
                          arg = { "HeadlineView", "ShowMouseoverHighlight" },
                          set = SetThemeValue,
                        },
                      },
                    },
                    Transparency = {
                      name = L["Transparency & Scaling"],
                      order = 40,
                      type = "group",
                      inline = true,
                      args = {
                        Transparency = {
                          name = L["Use transparency settings of Healthbar View also for Headline View."],
                          type = "toggle",
                          order = 1,
                          width = "full",
                          arg = { "HeadlineView", "useAlpha" },
                        },
                        Scaling = {
                          name = L["Use scale settings of Healthbar View also for Headline View."],
                          type = "toggle",
                          order = 10,
                          width = "full",
                          arg = { "HeadlineView", "useScaling" },
                        },
                      },
                    },
                  },
                },
              },
            },
            CastBarSettings = CreateCastbarOptions(),
            Transparency = {
              name = L["Transparency"],
              type = "group",
              order = 40,
              args = {
                Fading = {
                  name = L["Fading"],
                  type = "group",
                  order = 5,
                  inline = true,
                  args = {
                    Enable = {
                      type = "toggle",
                      order = 10,
                      name = "Enable Fade-In",
                      desc = L["This option allows you to control whether nameplates should fade in when displayed."],
                      width = "full",
                      arg = { "Transparency", "Fading" },
                    },
                  },
                },
                Situational = {
                  name = L["Situational Transparency"],
                  type = "group",
                  order = 10,
                  inline = true,
                  args = {
                    Help = {
                      name = L["Change the transparency of nameplates in certain situations, overwriting all other settings."],
                      order = 0,
                      type = "description",
                      width = "full",
                    },
                    MarkedUnitEnable = {
                      name = L["Target Marked"],
                      order = 10,
                      type = "toggle",
                      arg = { "nameplate", "toggle", "MarkedA" },
                    },
                    MarkedUnitAlpha = GetTransparencyEntryDefault(11, { "nameplate", "alpha", "Marked" }),
                    MouseoverUnitEnable = {
                      name = L["Mouseover"],
                      order = 20,
                      type = "toggle",
                      arg = { "nameplate", "toggle", "MouseoverUnitAlpha" },
                    },
                    MouseoverUnitAlpha = GetTransparencyEntryDefault(21, { "nameplate", "alpha", "MouseoverUnit" }),
                    CastingFriendlyUnitEnable = {
                      name = L["Friendly Casting"],
                      order = 30,
                      type = "toggle",
                      arg = { "nameplate", "toggle", "CastingUnitAlpha" },
                    },
                    CastingFriendlyUnitAlpha = GetTransparencyEntryDefault(31, { "nameplate", "alpha", "CastingUnit" }),
                    CastingEnemyUnitEnable = {
                      name = L["Enemy Casting"],
                      order = 40,
                      type = "toggle",
                      arg = { "nameplate", "toggle", "CastingEnemyUnitAlpha" },
                    },
                    CastingEnemyUnitAlpha = GetTransparencyEntryDefault(41, { "nameplate", "alpha", "CastingEnemyUnit" }),
                  },
                },
                Target = {
                  name = L["Target-based Transparency"],
                  type = "group",
                  order = 20,
                  inline = true,
                  args = {
                    Help = {
                      name = L["Change the transparency of nameplates depending on whether a target unit is selected or not. As default, this transparency is added to the unit base transparency."],
                      order = 0,
                      type = "description",
                      width = "full",
                    },
                    AlphaTarget = {
                      name = L["Target"],
                      order = 10,
                      type = "toggle",
                      desc = L["The target nameplate's transparency if a target unit is selected."],
                      arg = { "nameplate", "toggle", "TargetA" },
                    },
                    AlphaTargetSet = GetTransparencyEntryOffset(11, { "nameplate", "alpha", "Target" }),
                    AlphaNonTarget = {
                      name = L["Non-Target"],
                      order = 20,
                      type = "toggle",
                      desc = L["The transparency of non-target nameplates if a target unit is selected."],
                      arg = { "nameplate", "toggle", "NonTargetA" },
                    },
                    AlphaNonTargetSet = GetTransparencyEntryOffset(21, { "nameplate", "alpha", "NonTarget" }),
                    AlphaNoTarget = {
                      name = L["No Target"],
                      order = 30,
                      type = "toggle",
                      desc = L["The transparency of all nameplates if you have no target unit selected."],
                      arg = { "nameplate", "toggle", "NoTargetA" },
                    },
                    AlphaNoTargetSet = GetTransparencyEntryOffset(32, { "nameplate", "alpha", "NoTarget" }),
                    Spacer = GetSpacerEntry(40),
                    AddTargetAlpha = {
                      --name = L["Absolut Transparency"],
                      name = L["Use target-based transparency as absolute transparency and ignore unit base transparency."],
                      order = 50,
                      type = "toggle",
                      width = "full",
                      --desc = L["Uses the target-based transparency as absolute transparency and ignore unit base transparency."],
                      arg = { "nameplate", "alpha", "AbsoluteTargetAlpha" },
                    },
                  },
                },
                OccludedUnits = {
                  name = L["Occluded Units"],
                  type = "group",
                  order = 25,
                  inline = true,
                  args = {
                    Help = {
                      name = L["Change the transparency of nameplates for occluded units (e.g., units behind walls)."],
                      order = 0,
                      type = "description",
                      width = "full",
                    },
                    ImportantNotice = {
                      name = L["|cffff0000IMPORTANT: Enabling this feature changes console variables (CVars) which will change the appearance of default Blizzard nameplates. Disabling this feature will reset these CVars to the original value they had when you enabled this feature.|r"],
                      order = 1,
                      type = "description",
                      width = "full",
                    },
                    OccludedUnitsEnable = {
                      name = L["Enable"],
                      order = 10,
                      type = "toggle",
                      set = function(info, value)
                        info = t.CopyTable(info)

                        Addon:CallbackWhenOoC(function()
                          if value then
                            Addon:SetCVarsForOcclusionDetection()
                          else
                            Addon.CVars:RestoreFromProfile("nameplateMinAlpha")
                            Addon.CVars:RestoreFromProfile("nameplateMaxAlpha")
                            Addon.CVars:RestoreFromProfile("nameplateSelectedAlpha")
                            Addon.CVars:RestoreFromProfile("nameplateOccludedAlphaMult")
                          end
                          SetValue(info, value)
                        end, L["Unable to change transparency for occluded units while in combat."])
                      end,
                      arg = { "nameplate", "toggle", "OccludedUnits" },
                    },
                    OccludedUnitsAlpha = GetTransparencyEntryDefault(11, { "nameplate", "alpha", "OccludedUnits" }),
                  },
                },
                NameplateAlpha = {
                  name = L["Unit Base Transparency"],
                  type = "group",
                  order = 30,
                  inline = true,
                  args = {
                    Help = {
                      name = L["Define base alpha settings for various unit types. Only one of these settings is applied to a unit at the same time, i.e., they are mutually exclusive."],
                      order = 0,
                      type = "description",
                      width = "full",
                    },
                    Header1 = { type = "header", order = 10, name = L["Friendly & Neutral Units"], },
                    FriendlyPlayers = GetTransparencyEntry(L["Friendly Players"], 11, { "nameplate", "alpha", "FriendlyPlayer" }),
                    FriendlyNPCs = GetTransparencyEntry(L["Friendly NPCs"], 12, { "nameplate", "alpha", "FriendlyNPC" }),
                    NeutralNPCs = GetTransparencyEntry(L["Neutral NPCs"], 13, { "nameplate", "alpha", "Neutral" }),
                    Header2 = { type = "header", order = 20, name = L["Enemy Units"], },
                    EnemyPlayers = GetTransparencyEntry(L["Enemy Players"], 21, { "nameplate", "alpha", "EnemyPlayer" }),
                    EnemyNPCs = GetTransparencyEntry(L["Enemy NPCs"], 22, { "nameplate", "alpha", "EnemyNPC" }),
                    EnemyElite = GetTransparencyEntry(L["Rares & Elites"], 23, { "nameplate", "alpha", "Elite" }),
                    EnemyBoss = GetTransparencyEntry(L["Bosses"], 24, { "nameplate", "alpha", "Boss" }),
                    Header3 = { type = "header", order = 30, name = L["Minions & By Status"], },
                    Guardians = GetTransparencyEntry(L["Guardians"], 31, { "nameplate", "alpha", "Guardian" }),
                    Pets = GetTransparencyEntry(L["Pets"], 32, { "nameplate", "alpha", "Pet" }),
                    Minus = GetTransparencyEntry(L["Minor"], 33, { "nameplate", "alpha", "Minus" }),
                    Tapped =  GetTransparencyEntry(L["Tapped Units"], 41, { "nameplate", "alpha", "Tapped" }),
                  },
                },
              },
            },
            Scale = {
              name = L["Scale"],
              type = "group",
              order = 50,
              args = {
                Situational = {
                  name = L["Situational Scale"],
                  type = "group",
                  order = 10,
                  inline = true,
                  args = {
                    Help = {
                      name = L["Change the scale of nameplates in certain situations, overwriting all other settings."],
                      order = 0,
                      type = "description",
                      width = "full",
                    },
                    MarkedUnitEnable = {
                      name = L["Target Marked"],
                      type = "toggle",
                      order = 10,
                      arg = { "nameplate", "toggle", "MarkedS" },
                    },
                    MarkedUnitScale = GetScaleEntryDefault(11, { "nameplate", "scale", "Marked" }),
                    MouseoverUnitEnable = {
                      name = L["Mouseover"],
                      order = 20,
                      type = "toggle",
                      arg = { "nameplate", "toggle", "MouseoverUnitScale" },
                    },
                    MouseoverUnitScale = GetScaleEntryDefault(21, { "nameplate", "scale", "MouseoverUnit" }),
                    CastingFriendlyUnitsEnable = {
                      name = L["Friendly Casting"],
                      order = 30,
                      type = "toggle",
                      arg = { "nameplate", "toggle", "CastingUnitScale" },
                    },
                    CastingFriendlyUnitsScale = GetScaleEntryDefault(31, { "nameplate", "scale", "CastingUnit" }),
                    CastingEnemyUnitsEnable = {
                      name = L["Enemy Casting"],
                      order = 40,
                      type = "toggle",
                      arg = { "nameplate", "toggle", "CastingEnemyUnitScale" },
                    },
                    CastingEnemyUnitsScale = GetScaleEntryDefault(41, { "nameplate", "scale", "CastingEnemyUnit" }),
                  },
                },
                Target = {
                  name = L["Target-based Scale"],
                  type = "group",
                  order = 20,
                  inline = true,
                  args = {
                    Help = {
                      name = L["Change the scale of nameplates depending on whether a target unit is selected or not. As default, this scale is added to the unit base scale."],
                      order = 0,
                      type = "description",
                      width = "full",
                    },
                    ScaleTarget = {
                      name = L["Target"],
                      order = 10,
                      type = "toggle",
                      desc = L["The target nameplate's scale if a target unit is selected."],
                      arg = { "nameplate", "toggle", "TargetS" },
                    },
                    ScaleTargetSet = GetScaleEntryOffset(11, { "nameplate", "scale", "Target" }),
                    ScaleNonTarget = {
                      name = L["Non-Target"],
                      order = 20,
                      type = "toggle",
                      desc = L["The scale of non-target nameplates if a target unit is selected."],
                      arg = { "nameplate", "toggle", "NonTargetS" },
                    },
                    ScaleNonTargetSet = GetScaleEntryOffset(21, { "nameplate", "scale", "NonTarget" }),
                    ScaleNoTarget = {
                      name = L["No Target"],
                      order = 30,
                      type = "toggle",
                      desc = L["The scale of all nameplates if you have no target unit selected."],
                      arg = { "nameplate", "toggle", "NoTargetS" },
                    },
                    ScaleNoTargetSet = GetScaleEntryOffset(31, { "nameplate", "scale", "NoTarget" }),
                    Spacer = GetSpacerEntry(40),
                    AddTargetScale = {
                      name = L["Use target-based scale as absolute scale and ignore unit base scale."],
                      order = 50,
                      type = "toggle",
                      width = "full",
                      arg = { "nameplate", "scale", "AbsoluteTargetScale" },
                    },
                  },
                },
                NameplateScale = {
                  name = L["Unit Base Scale"],
                  type = "group",
                  order = 30,
                  inline = true,
                  args = {
                    Help = {
                      name = L["Define base scale settings for various unit types. Only one of these settings is applied to a unit at the same time, i.e., they are mutually exclusive."],
                      order = 0,
                      type = "description",
                      width = "full",
                    },
                    Header1 = { type = "header", order = 10, name = "Friendly & Neutral Units", },
                    FriendlyPlayers = GetScaleEntry(L["Friendly Players"], 11, { "nameplate", "scale", "FriendlyPlayer" }),
                    FriendlyNPCs = GetScaleEntry(L["Friendly NPCs"], 12, { "nameplate", "scale", "FriendlyNPC" }),
                    NeutralNPCs = GetScaleEntry(L["Neutral NPCs"], 13, { "nameplate", "scale", "Neutral" }),
                    Header2 = { type = "header", order = 20, name = "Enemy Units", },
                    EnemyPlayers = GetScaleEntry(L["Enemy Players"], 21, { "nameplate", "scale", "EnemyPlayer" }),
                    EnemyNPCs = GetScaleEntry(L["Enemy NPCs"], 22, { "nameplate", "scale", "EnemyNPC" }),
                    EnemyElite = GetScaleEntry(L["Rares & Elites"], 23, { "nameplate", "scale", "Elite" }),
                    EnemyBoss = GetScaleEntry(L["Bosses"], 24, { "nameplate", "scale", "Boss" }),
                    Header3 = { type = "header", order = 30, name = "Minions & By Status", },
                    Guardians = GetScaleEntry(L["Guardians"], 31, { "nameplate", "scale", "Guardian" }),
                    Pets = GetScaleEntry(L["Pets"], 32, { "nameplate", "scale", "Pet" }),
                    Minus = GetScaleEntry(L["Minor"], 33, { "nameplate", "scale", "Minus" }),
                    Tapped =  GetScaleEntry(L["Tapped Units"], 41, { "nameplate", "scale", "Tapped" }),
                  },
                },
              },
            },
            Names = {
              name = L["Names"],
              type = "group",
              order = 65,
              args = {
                HealthbarView = {
                  name = L["Healthbar View"],
                  order = 10,
                  type = "group",
                  inline = true,
                  args = {
                    Enable = GetEnableEntryTheme(L["Show Name Text"], L["This option allows you to control whether a unit's name is hidden or shown on nameplates."], "name"),
                    Font = GetFontEntryTheme(10, "name"),
                    Color = {
                      name = L["Colors"],
                      order = 20,
                      type = "group",
                      inline = true,
                      set = SetThemeValue,
                      args = {
                        FriendlyColor = {
                          name = L["Friendly Name Color"],
                          order = 10,
                          type = "select",
                          values = t.FRIENDLY_TEXT_COLOR,
                          arg = { "settings", "name", "FriendlyTextColorMode" }
                        },
                        FriendlyColorCustom = GetColorEntry(L["Custom Color"], 20, { "settings", "name", "FriendlyTextColor" }),
                        EnemyColor = {
                          name = L["Enemy Name Color"],
                          order = 30,
                          type = "select",
                          values = t.ENEMY_TEXT_COLOR,
                          arg = { "settings", "name", "EnemyTextColorMode" }
                        },
                        EnemyColorCustom = GetColorEntry(L["Custom Color"], 40, { "settings", "name", "EnemyTextColor" }),
                        Spacer1 = GetSpacerEntry(50),
                        EnableRaidMarks = {
                          name = L["Color by Target Mark"],
                          order = 60,
                          type = "toggle",
                          width = "full",
                          desc = L["Additionally color the name based on the target mark if the unit is marked."],
                          descStyle = "inline",
                          set = SetValue,
                          arg = { "settings", "name", "UseRaidMarkColoring" },
                        },
                      },
                    },
                    Placement = {
                      name = L["Placement"],
                      order = 30,
                      type = "group",
                      inline = true,
                      args = {
                        X = { name = L["X"], type = "range", order = 1, set = SetThemeValue, arg = { "settings", "name", "x" }, max = 120, min = -120, step = 1, isPercent = false, },
                        Y = { name = L["Y"], type = "range", order = 2, set = SetThemeValue, arg = { "settings", "name", "y" }, max = 120, min = -120, step = 1, isPercent = false, },
                        AlignH = { name = L["Horizontal Align"], type = "select", order = 4, values = t.AlignH, set = SetThemeValue, arg = { "settings", "name", "align" }, },
                        AlignV = { name = L["Vertical Align"], type = "select", order = 5, values = t.AlignV, set = SetThemeValue, arg = { "settings", "name", "vertical" }, },
                      },
                    },
                  },
                },
                HeadlineView = {
                  name = L["Headline View"],
                  order = 20,
                  type = "group",
                  inline = true,
                  args = {
                    Font = {
                      name = L["Font"],
                      type = "group",
                      inline = true,
                      order = 10,
                      args = {
                        Size = {
                          name = L["Size"],
                          order = 20,
                          type = "range",
                          set = SetThemeValue,
                          arg = { "HeadlineView", "name", "size" },
                          max = 36,
                          min = 6,
                          step = 1,
                          isPercent = false,
                        },
                      },
                    },
                    Color = {
                      name = L["Colors"],
                      order = 20,
                      type = "group",
                      inline = true,
                      args = {
                        FriendlyColor = {
                          name = L["Friendly Names Color"],
                          order = 10,
                          type = "select",
                          values = t.FRIENDLY_TEXT_COLOR,
                          arg = { "HeadlineView", "FriendlyTextColorMode" }
                        },
                        FriendlyColorCustom = GetColorEntry(L["Custom Color"], 20, { "HeadlineView", "FriendlyTextColor" }),
                        EnemyColor = {
                          name = L["Enemy Name Color"],
                          order = 30,
                          type = "select",
                          values = t.ENEMY_TEXT_COLOR,
                          arg = { "HeadlineView", "EnemyTextColorMode" }
                        },
                        EnemyColorCustom = GetColorEntry(L["Custom Color"], 40, { "HeadlineView", "EnemyTextColor" }),
                        Spacer1 = GetSpacerEntry(50),
                        EnableRaidMarks = {
                          name = L["Color by Target Mark"],
                          order = 60,
                          type = "toggle",
                          width = "full",
                          desc = L["Additionally color the name based on the target mark if the unit is marked."],
                          descStyle = "inline",
                          set = SetValue,
                          arg = { "HeadlineView", "UseRaidMarkColoring" },
                        },
                      },
                    },
                    Placement = {
                      name = L["Placement"],
                      order = 30,
                      type = "group",
                      inline = true,
                      args = {
                        X = { name = L["X"], type = "range", order = 1, set = SetThemeValue, arg = { "HeadlineView", "name", "x" }, max = 120, min = -120, step = 1, isPercent = false, },
                        Y = { name = L["Y"], type = "range", order = 2, set = SetThemeValue, arg = { "HeadlineView", "name", "y" }, max = 120, min = -120, step = 1, isPercent = false, },
                        AlignH = { name = L["Horizontal Align"], type = "select", order = 4, values = t.AlignH, set = SetThemeValue, arg = { "HeadlineView", "name", "align" }, },
                        AlignV = { name = L["Vertical Align"], type = "select", order = 5, values = t.AlignV, set = SetThemeValue, arg = { "HeadlineView", "name", "vertical" }, },
                      },
                    },
                  },
                },
                Boundaries = GetBoundariesEntry(30, "name"),
              },
            },
            Statustext = {
              name = L["Status Text"],
              type = "group",
              order = 70,
              args = {
                HealthbarView = {
                  name = L["Healthbar View"],
                  order = 10,
                  type = "group",
                  inline = true,
                  args = {
                    -- Enable = GetEnableEntryTheme(L["Show Health Text"], L["This option allows you to control whether a unit's health is hidden or shown on nameplates."], "customtext"),
                    FriendlySubtext = {
                      name = L["Friendly Status Text"],
                      order = 10,
                      type = "select",
                      values = t.FRIENDLY_SUBTEXT,
                      arg = { "settings", "customtext", "FriendlySubtext"}
                    },
                    Spacer1 = { name = "", order = 15, type = "description", width = "half", },
                    EnemySubtext = {
                      name = L["Enemy Status Text"],
                      order = 20,
                      type = "select",
                      values = t.ENEMY_SUBTEXT,
                      arg = { "settings", "customtext", "EnemySubtext"}
                    },
                    Spacer2 = GetSpacerEntry(30),
                    SubtextColor = {
                      name = L["Color"],
                      order = 40,
                      type = "group",
                      inline = true,
                      args = {
                        SubtextColorHeadline = {
                          name = L["Same as Name"],
                          order = 10,
                          type = "toggle",
                          set = function(info, val)
                            TidyPlatesThreat.db.profile.settings.customtext.SubtextColorUseSpecific = false
                            SetValue(info, true)
                          end,
                          arg = { "settings", "customtext", "SubtextColorUseHeadline" },
                        },
                        SubtextColorSpecific = {
                          name = L["Status Text"],
                          order = 20,
                          type = "toggle",
                          arg = { "settings", "customtext", "SubtextColorUseSpecific" },
                          set = function(info, val)
                            TidyPlatesThreat.db.profile.settings.customtext.SubtextColorUseHeadline = false
                            SetValue(info, true)
                          end,
                        },
                        SubtextColorCustom = {
                          name = L["Custom"],
                          order = 30,
                          type = "toggle",
                          width = "half",
                          set = function(info, val)
                            TidyPlatesThreat.db.profile.settings.customtext.SubtextColorUseHeadline = false
                            TidyPlatesThreat.db.profile.settings.customtext.SubtextColorUseSpecific = false
                            Addon:ForceUpdate()
                          end,
                          get = function(info) return not (TidyPlatesThreat.db.profile.settings.customtext.SubtextColorUseHeadline or TidyPlatesThreat.db.profile.settings.customtext.SubtextColorUseSpecific) end,
                        },
                        SubtextColorCustomColor = GetColorAlphaEntry(35, { "settings", "customtext", "SubtextColor" },
                          function() return (TidyPlatesThreat.db.profile.settings.customtext.SubtextColorUseHeadline or TidyPlatesThreat.db.profile.settings.customtext.SubtextColorUseSpecific) end ),
                      },
                    },
                    Font = GetFontEntryTheme(50, "customtext"),
                    Placement = {
                      name = L["Placement"],
                      order = 60,
                      type = "group",
                      inline = true,
                      set = SetThemeValue,
                      args = {
                        X = { name = L["X"], type = "range", order = 1, arg = { "settings", "customtext", "x" }, max = 120, min = -120, step = 1, isPercent = false, },
                        Y = { name = L["Y"], type = "range", order = 2, arg = { "settings", "customtext", "y" }, max = 120, min = -120, step = 1, isPercent = false, },
                        AlignH = { name = L["Horizontal Align"], type = "select", order = 4, values = t.AlignH, arg = { "settings", "customtext", "align" }, },
                        AlignV = { name = L["Vertical Align"], type = "select", order = 5, values = t.AlignV, arg = { "settings", "customtext", "vertical" }, },
                      },
                    },
                  },
                },
                HeadlineView = {
                  name = L["Headline View"],
                  order = 20,
                  type = "group",
                  inline = true,
                  args = {
                    FriendlySubtext = {
                      name = L["Friendly Custom Text"],
                      order = 10,
                      type = "select",
                      values = t.FRIENDLY_SUBTEXT,
                      arg = {"HeadlineView", "FriendlySubtext"}
                    },
                    Spacer1 = { name = "", order = 15, type = "description", width = "half", },
                    EnemySubtext = {
                      name = L["Enemy Custom Text"],
                      order = 20,
                      type = "select",
                      values = t.ENEMY_SUBTEXT,
                      arg = {"HeadlineView", "EnemySubtext"}
                    },
                    Spacer2 = GetSpacerEntry(25),
                    SubtextColor = {
                      name = L["Color"],
                      order = 40,
                      type = "group",
                      inline = true,
                      args = {
                        SubtextColorHeadline = {
                          name = L["Same as Name"],
                          order = 10,
                          type = "toggle",
                          arg = { "HeadlineView", "SubtextColorUseHeadline" },
                          set = function(info, val)
                            TidyPlatesThreat.db.profile.HeadlineView.SubtextColorUseSpecific = false
                            SetValue(info, true)
                          end,
                        },
                        SubtextColorSpecific = {
                          name = L["Status Text"],
                          order = 20,
                          type = "toggle",
                          arg = { "HeadlineView", "SubtextColorUseSpecific" },
                          set = function(info, val)
                            TidyPlatesThreat.db.profile.HeadlineView.SubtextColorUseHeadline = false
                            SetValue(info, true)
                          end,
                        },
                        SubtextColorCustom = {
                          name = L["Custom"],
                          order = 30,
                          type = "toggle",
                          width = "half",
                          set = function(info, val)
                            TidyPlatesThreat.db.profile.HeadlineView.SubtextColorUseHeadline = false
                            TidyPlatesThreat.db.profile.HeadlineView.SubtextColorUseSpecific = false
                            Addon:ForceUpdate()
                          end,
                          get = function(info) return not (TidyPlatesThreat.db.profile.HeadlineView.SubtextColorUseHeadline or TidyPlatesThreat.db.profile.HeadlineView.SubtextColorUseSpecific) end,
                        },
                        SubtextColorCustomColor = GetColorAlphaEntry(35, { "HeadlineView", "SubtextColor" },
                          function() return (TidyPlatesThreat.db.profile.HeadlineView.SubtextColorUseHeadline or TidyPlatesThreat.db.profile.HeadlineView.SubtextColorUseSpecific) end ),
                      },
                    },
                    -- Font = GetFontEntry(50, { "HeadlineView", "name" } ),
                    Font = {
                      name = L["Font"],
                      type = "group",
                      inline = true,
                      order = 50,
                      args = {
                        Size = {
                          name = L["Size"],
                          order = 20,
                          type = "range",
                          set = SetThemeValue,
                          arg = { "HeadlineView", "customtext", "size" },
                          max = 36,
                          min = 6,
                          step = 1,
                          isPercent = false,
                        },
                      },
                    },
                    Placement = {
                      name = L["Placement"],
                      order = 60,
                      type = "group",
                      inline = true,
                      set = SetThemeValue,
                      args = {
                        X = { name = L["X"], type = "range", order = 1, arg = { "HeadlineView", "customtext", "x" }, max = 120, min = -120, step = 1, isPercent = false, },
                        Y = { name = L["Y"], type = "range", order = 2, arg = { "HeadlineView", "customtext", "y" }, max = 120, min = -120, step = 1, isPercent = false, },
                        AlignH = { name = L["Horizontal Align"], type = "select", order = 4, values = t.AlignH, arg = { "HeadlineView", "customtext", "align" }, },
                        AlignV = { name = L["Vertical Align"], type = "select", order = 5, values = t.AlignV, arg = { "HeadlineView", "customtext", "vertical" }, },
                      },
                    },
                  },
                },
                HealthText = {
                  name = L["Health Text"],
                  order = 30,
                  type = "group",
                  inline = true,
                  set = SetThemeValue,
                  args = {
                    EnableAmount = {
                      name = L["Amount"],
                      type = "toggle",
                      order = 10,
                      desc = L["Display health amount text."],
                      arg = { "text", "amount" }
                    },
                    MaxHP = {
                      name = L["Max Health"],
                      type = "toggle",
                      order = 20,
                      desc = L["This will format text to show both the maximum hp and current hp."],
                      arg = { "text", "max" },
                      disabled = function() return not db.text.amount end
                    },
                    Deficit = {
                      name = L["Deficit"],
                      type = "toggle",
                      order = 30,
                      desc = L["This will format text to show hp as a value the target is missing."],
                      arg = { "text", "deficit" },
                      disabled = function() return not db.text.amount end
                    },
                    EnablePercent = {
                      name = L["Percentage"],
                      type = "toggle",
                      order = 40,
                      desc = L["Display health percentage text."],
                      arg = { "text", "percent" }
                    },
                    Spacer1 = GetSpacerEntry(50),
                    Full = {
                      name = L["Full Health"],
                      type = "toggle",
                      order = 60,
                      desc = L["Display health text on units with full health."],
                      arg = { "text", "full" }
                    },
                    Truncate = {
                      name = L["Shorten"],
                      type = "toggle",
                      order = 70,
                      desc = L["This will format text to a simpler format using M or K for millions and thousands. Disabling this will show exact health amounts."],
                      arg = { "text", "truncate" },
                    },
                    UseLocalizedUnit = {
                      name = L["Localization"],
                      type = "toggle",
                      order = 80,
                      desc = L["If enabled, the truncated health text will be localized, i.e. local metric unit symbols (like k for thousands) will be used."],
                      arg = { "text", "LocalizedUnitSymbol" }
                    },
                  },
                },
                --AbsorbsText = {
                --  name = L["Absorbs Text"],
                --  order = 35,
                --  type = "group",
                --  inline = true,
                --  set = SetThemeValue,
                --  args = {
                --    EnableAmount = {
                --      name = L["Amount"],
                --      type = "toggle",
                --      order = 10,
                --      desc = L["Display absorbs amount text."],
                --      arg = { "text", "AbsorbsAmount" }
                --    },
                --    EnableShorten = {
                --      name = L["Shorten"],
                --      type = "toggle",
                --      order = 20,
                --      desc = L["This will format text to a simpler format using M or K for millions and thousands. Disabling this will show exact absorbs amounts."],
                --      arg = { "text", "AbsorbsShorten" },
                --      disabled = function() return not db.text.AbsorbsAmount end
                --    },
                --    EnablePercentage = {
                --      name = L["Percentage"],
                --      type = "toggle",
                --      order = 30,
                --      desc = L["Display absorbs percentage text."],
                --      arg = { "text", "AbsorbsPercentage" }
                --    },
                --  },
                --},
                Boundaries = GetBoundariesEntry(40, "customtext"),
              },
            },
            Leveltext = {
              name = L["Level Text"],
              type = "group",
              order = 90,
              args = {
                Enable = GetEnableEntryTheme(L["Show Level Text"], L["This option allows you to control whether a unit's level is hidden or shown on nameplates."], "level"),
                Font = GetFontEntryTheme(10, "level"),
                Placement = {
                  name = L["Placement"],
                  order = 20,
                  type = "group",
                  inline = true,
                  args = {
                    X = {
                      name = L["X"],
                      type = "range",
                      order = 1,
                      set = SetThemeValue,
                      arg = { "settings", "level", "x" },
                      max = 120,
                      min = -120,
                      step = 1,
                      isPercent = false,
                    },
                    Y = {
                      name = L["Y"],
                      type = "range",
                      order = 2,
                      set = SetThemeValue,
                      arg = { "settings", "level", "y" },
                      max = 120,
                      min = -120,
                      step = 1,
                      isPercent = false,
                    },
                    AlignH = {
                      name = L["Horizontal Align"],
                      type = "select",
                      order = 3,
                      values = t.AlignH,
                      set = SetThemeValue,
                      arg = { "settings", "level", "align" },
                    },
                    AlignV = {
                      name = L["Vertical Align"],
                      type = "select",
                      order = 4,
                      values = t.AlignV,
                      set = SetThemeValue,
                      arg = { "settings", "level", "vertical" },
                    },
                  },
                },
                Boundaries = GetBoundariesEntry(30, "level"),
              },
            },
            EliteIcon = {
              name = L["Rares & Elites"],
              type = "group",
              order = 100,
              set = SetThemeValue,
              args = {
                Enable = GetEnableEntryTheme(L["Show Icon for Rares & Elites"], L["This option allows you to control whether the icon for rare & elite units is hidden or shown on nameplates."], "eliteicon"),
                Texture = {
                  name = L["Symbol"],
                  type = "group",
                  inline = true,
                  order = 20,
                  --                  disabled = function() if db.settings.eliteicon.show then return false else return true end end,
                  args = {
                    Style = {
                      type = "select",
                      order = 10,
                      name = L["Icon Style"],
                      --Blizzard Dragon <- TARGETINGFRAME\\Nameplates.png
                      values = { default = "Default", stddragon = "Blizzard Dragon", skullandcross = "Skull and Crossbones" },
                      set = function(info, val)
                        SetThemeValue(info, val)
                        options.args.NameplateSettings.args.EliteIcon.args.Texture.args.PreviewRare.image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\EliteArtWidget\\" .. val
                        options.args.NameplateSettings.args.EliteIcon.args.Texture.args.PreviewElite.image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\EliteArtWidget\\" .. "elite-" .. val
                        Addon:ForceUpdate()
                      end,
                      arg = { "settings", "eliteicon", "theme" },
                    },
                    PreviewRare = {
                      name = L["Preview Rare"],
                      type = "execute",
                      order = 20,
                      image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\EliteArtWidget\\" .. db.settings.eliteicon.theme,
                    },
                    PreviewElite = {
                      name = L["Preview Elite"],
                      type = "execute",
                      order = 30,
                      image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\EliteArtWidget\\" .. "elite-" .. db.settings.eliteicon.theme,
                    },
                  },
                },
                Layout = GetLayoutEntryTheme(30, "eliteicon"),
              },
            },
            SkullIcon = {
              name = L["Skull Icon"],
              type = "group",
              order = 110,
              set = SetThemeValue,
              args = {
                Enable = GetEnableEntryTheme(L["Show Skull Icon"], L["This option allows you to control whether the skull icon for boss units is hidden or shown on nameplates."], "skullicon"),
                Layout = GetLayoutEntryTheme(20, "skullicon"),
              },
            },
            RaidMarks = CreateRaidMarksOptions(),
            BlizzardSettings = CreateBlizzardSettings(),
--            TestSettings = {
--              name = "Test Settings",
--              type = "group",
--              order = 1000,
--              set = SetThemeValue,
--              hidden = true,
--              args = {
--                HealthHeaderBorder = { name = "Healthbar Border", type = "header", order = 10, },
--                HealthBorder = {
--                  type = "select",
--                  order = 20,
--                  name = "Border",
--                  dialogControl = "LSM30_Border",
--                  values = AceGUIWidgetLSMlists.border,
--                  arg = { "settings", "healthborder", "texture" },
--                },
--                HealthBorderEdgeSize = {
--                  name = "Edge Size",
--                  order = 30,
--                  type = "range",
--                  min = 0, max = 32, step = 0.5,
--                  set = SetThemeValue,
--                  arg = { "settings", "healthborder", "EdgeSize" },
--                },
--                HealthBorderOffset = {
--                  name = "Offset",
--                  order = 40,
--                  type = "range",
--                  min = -16, max = 16, step = 0.5,
--                  set = SetThemeValue,
--                  arg = { "settings", "healthborder", "Offset" },
--                },
--                EliteHeaderBorder = { name = L["Elite Border"], type = "header", order = 110, },
--                EliteBorder = {
--                  type = "select",
--                  order = 120,
--                  name = "Elite Border",
--                  values = { TP_EliteBorder_Default = "Default", TP_EliteBorder_Thin = "Thin" },
--                  arg = { "settings", "elitehealthborder", "texture" }
--                },
--                EliteBorderEdgeSize = {
--                  name = "Edge Size",
--                  order = 130,
--                  type = "range",
--                  min = 0, max = 32, step = 0.5,
--                  set = SetThemeValue,
--                  arg = { "settings", "elitehealthborder", "EdgeSize" },
--                },
--                EliteBorderOffset = {
--                  name = "Offset",
--                  order = 140,
--                  type = "range",
--                  min = -16, max = 16, step = 0.5,
--                  set = SetThemeValue,
--                  arg = { "settings", "elitehealthborder", "Offset" },
--                },
--                TargetHeaderBorder = { name = "Target Border", type = "header", order = 210, },
--                TargetBorder = {
--                  type = "select",
--                  order = 220,
--                  name = "Target Border",
--                  values = { default = "Default", squarethin = "Thin Square" },
--                  arg = { "targetWidget", "theme" },
--                },
--                TargetBorderEdgeSize = {
--                  name = "Edge Size",
--                  order = 230,
--                  type = "range",
--                  min = 0, max = 32, step = 1,
--                  set = SetThemeValue,
--                  arg = { "targetWidget", "EdgeSize" },
--                },
--                TargetBorderOffset = {
--                  name = "Offset",
--                  order = 240,
--                  type = "range",
--                  min = -16, max = 16, step = 0.5,
--                  set = SetThemeValue,
--                  arg = { "targetWidget", "Offset" },
--                },
--                MouseoverHeaderBorder = { name = "Mouseover Border", type = "header", order = 310, },
--                MouseoverBorderEdgeSize = {
--                  name = L["Edge Size"],
--                  order = 330,
--                  type = "range",
--                  min = 0, max = 32, step = 0.5,
--                  set = SetThemeValue,
--                  arg = { "settings", "highlight", "EdgeSize" },
--                },
--                MouseoverBorderOffset = {
--                  name = "Offset",
--                  order = 340,
--                  type = "range",
--                  min = -16, max = 16, step = 0.5,
--                  set = SetThemeValue,
--                  arg = { "settings", "highlight", "Offset" },
--                },
--                ThreatHeaderBorder = { name = "Threat Glow Border", type = "header", order = 410, },
--                ThreatBorderEdgeSize = {
--                  name = "Edge Size",
--                  order = 430,
--                  type = "range",
--                  min = 0, max = 32, step = 0.5,
--                  set = SetThemeValue,
--                  arg = { "settings", "threatborder", "EdgeSize" },
--                },
--                ThreatBorderOffset = {
--                  name = "Offset",
--                  order = 440,
--                  type = "range",
--                  min = -16, max = 16, step = 0.5,
--                  set = SetThemeValue,
--                  arg = { "settings", "threatborder", "Offset" },
--                },
--                TestHeaderBorder = { name = "Test Widget", type = "header", order = 500, },
--                Width = GetRangeEntry("Bar Width", 501, { "TestWidget", "BarWidth" }, 5, 500),
--                Height = GetRangeEntry("Bar Height", 502, { "TestWidget", "BarHeight" }, 1, 100),
--                TestBarTexture = {
--                  name = "Foreground",
--                  type = "select",
--                  order = 505,
--                  dialogControl = "LSM30_Statusbar",
--                  values = AceGUIWidgetLSMlists.statusbar,
--                  set = SetThemeValue,
--                  arg = { "TestWidget", "BarTexture" },
--                },
--                TestBarBorder = {
--                  type = "select",
--                  order = 510,
--                  name = "Border Texture",
--                  dialogControl = "LSM30_Border",
--                  values = AceGUIWidgetLSMlists.border,
--                  arg = { "TestWidget", "BorderTexture" },
--                },
--                TestBarBackgroundTexture = {
--                  name = "Background",
--                  type = "select",
--                  order = 520,
--                  dialogControl = "LSM30_Statusbar",
--                  values = AceGUIWidgetLSMlists.statusbar,
--                  arg = { "TestWidget", "BorderBackground" },
--                },
--                TestBorderEdgeSize = {
--                  name = "Edge Size",
--                  order = 530,
--                  type = "range",
--                  min = 0, max = 32, step = 0.1,
--                  arg = { "TestWidget", "EdgeSize" },
--                },
--                TestBorderOffset = {
--                  name = "Offset",
--                  order = 540,
--                  type = "range",
--                  min = -16, max = 16, step = 0.1,
--                  arg = { "TestWidget", "Offset" },
--                },
--                TestBorderInset = {
--                  name = "Inset",
--                  order = 545,
--                  type = "range",
--                  min = -16, max = 16, step = 0.1,
--                  arg = { "TestWidget", "Inset" },
--                },
--                TestSacle = GetScaleEntry("Scale", 550, { "TestWidget", "Scale" }, nil, 0, 5.0)
--              },
--            },
          },
        },
        ThreatOptions = {
          name = L["Threat System"],
          type = "group",
          order = 30,
          args = {
            Enable = {
              name = L["Enable Threat System"],
              type = "toggle",
              order = 1,
              arg = { "threat", "ON" }
            },
            GeneralSettings = {
              name = L["General Settings"],
              type = "group",
              order = 0,
              disabled = function() return not db.threat.ON end,
              args = {
                ByUnitType = {
                  name = L["Show For"],
                  type = "group",
                  order = 10,
                  inline = true,
                  args = {
                    Help = {
                      name = L["Show threat feedback based on unit type or status or environmental conditions."],
                      order = 0,
                      type = "description",
                    },
                    Header1 = { type = "header", order = 10, name = L["Enemy Units"], },
                    EnemyNPCs = {
                      type = "toggle",
                      name = L["Enemy NPCs"],
                      order = 12,
                      desc = L["If checked, threat feedback from normal mobs will be shown."],
                      arg = { "threat", "toggle", "Normal" },
                    },
                    EnemyElite = {
                      type = "toggle",
                      name = L["Rares & Elites"],
                      order = 13,
                      desc = L["If checked, threat feedback from elite and rare mobs will be shown."],
                      arg = { "threat", "toggle", "Elite" },
                    },
                    EnemyBoss = {
                      type = "toggle",
                      name = L["Bosses"],
                      order = 14,
                      desc = L["If checked, threat feedback from boss level mobs will be shown."],
                      arg = { "threat", "toggle", "Boss" },
                    },
                    Header2 = { type = "header", order = 20, name = L["Neutral Units & Minions"], },
                    NeutralNPCs = {
                      type = "toggle",
                      name = L["Neutral NPCs"],
                      order = 21,
                      desc = L["If checked, threat feedback from neutral mobs will be shown."],
                      arg = { "threat", "toggle", "Neutral" },
                    },
                    Minus = {
                      type = "toggle",
                      name = L["Minor"],
                      order = 22,
                      desc = L["If checked, threat feedback from minor mobs will be shown."],
                      arg = { "threat", "toggle", "Minus" },
                    },
                    Header3 = { type = "header", order = 30, name = L["Status & Environment"], },
                    Tapped = {
                      type = "toggle",
                      name = L["Tapped Units"],
                      order = 40,
                      desc = L["If checked, threat feedback from tapped mobs will be shown regardless of unit type."],
                      arg = { "threat", "toggle", "Tapped" },
                    },
                    OnlyInInstances = {
                      type = "toggle",
                      name = L["Only in Instances"],
                      order = 50,
                      desc = L["If checked, threat feedback will only be shown in instances (dungeons, raids, arenas, battlegrounds), not in the open world."],
                      arg = { "threat", "toggle", "InstancesOnly" },
                    },
                  },
                },
                General = {
                  name = L["Special Effects"],
                  type = "group",
                  order = 10,
                  inline = true,
                  args = {
                    OffTank = {
                      type = "toggle",
                      name = L["Highlight Mobs on Off-Tanks"],
                      order = 10,
                      width = "full",
                      desc = L["If checked, nameplates of mobs attacking another tank can be shown with different color, scale, and transparency."],
                      descStyle = "inline",
                      arg = { "threat", "toggle", "OffTank" },
                    },
                  },
                },
                ThreatHeuristic = {
                  name = L["Threat Detection"],
                  type = "group",
                  order = 20,
                  inline = true,
                  args = {
                    Note = {
                      name = L["By default, the threat system works based on a mob's threat table. Some mobs do not have such a threat table even if you are in combat with them. The threat detection heuristic uses other factors to determine if you are in combat with a mob. This works well in instances. In the open world, this can show units in combat with you that are actually just in combat with another player (and not you)."],
                      order = 0,
                      type = "description",
                    },
                    ThreatTable = {
                      type = "toggle",
                      name = L["Threat Table"],
                      order = 10,
                      arg = { "threat", "UseThreatTable" },
                    },
                    Heuristic = {
                      type = "toggle",
                      name = L["Heuristic"],
                      order = 20,
                      set = function(info, val) SetValue(info, not val) end,
                      get = function(info) return not GetValue(info) end,
                      arg = { "threat", "UseThreatTable" },
                    },
                    HeuristicOnlyInInstances = {
                      type = "toggle",
                      name = L["Heuristic In Instances"],
                      order = 30,
                      desc = L["Use a heuristic to detect if a mob is in combat with you, but only in instances (like dungeons or raids)."],
                      arg = { "threat", "UseHeuristicInInstances" },
                    },
                  },
                },
              },
            },
            Alpha = {
              name = L["Transparency"],
              type = "group",
              desc = L["Set transparency settings for different threat levels."],
              disabled = function() return not db.threat.ON end,
              order = 1,
              args = {
                Enable = {
                  name = L["Enable Threat Transparency"],
                  type = "group",
                  inline = true,
                  order = 0,
                  args = {
                    Enable = {
                      type = "toggle",
                      name = L["Enable"],
                      desc = L["This option allows you to control whether threat affects the transparency of nameplates."],
                      width = "full",
                      descStyle = "inline",
                      order = 2,
                      arg = { "threat", "useAlpha" }
                    },
                  },
                },
                Tank = {
                  name = L["|cff00ff00Tank|r"],
                  type = "group",
                  inline = true,
                  order = 1,
                  disabled = function() if db.threat.useAlpha then return false else return true end end,
                  args = {
                    Low = GetTransparencyEntryThreat(L["|cffff0000Low Threat|r"], 1, { "threat", "tank", "alpha", "LOW" }),
                    Med = GetTransparencyEntryThreat(L["|cffffff00Medium Threat|r"], 2, { "threat", "tank", "alpha", "MEDIUM" }),
                    High = GetTransparencyEntryThreat(L["|cff00ff00High Threat|r"], 3, { "threat", "tank", "alpha", "HIGH" }),
                    OffTank = GetTransparencyEntryThreat(L["|cff0faac8Off-Tank|r"], 4, { "threat", "tank", "alpha", "OFFTANK" }),
                  },
                },
                DPS = {
                  name = L["|cffff0000DPS/Healing|r"],
                  type = "group",
                  inline = true,
                  order = 2,
                  disabled = function() if db.threat.useAlpha then return false else return true end end,
                  args = {
                    Low = GetTransparencyEntryThreat(L["|cff00ff00Low Threat|r"], 1, { "threat", "dps", "alpha", "LOW" }),
                    Med = GetTransparencyEntryThreat(L["|cffffff00Medium Threat|r"], 2, { "threat", "dps", "alpha", "MEDIUM" }),
                    High = GetTransparencyEntryThreat(L["|cffff0000High Threat|r"], 3, { "threat", "dps", "alpha", "HIGH" }),
                  },
                },
                Marked = {
                  name = L["Additional Adjustments"],
                  type = "group",
                  inline = true,
                  order = 3,
                  disabled = function() if db.threat.useAlpha then return false else return true end end,
                  args = {
                    DisableSituational = {
                      name = L["Disable threat transparency for target marked, mouseover or casting units."],
                      type = "toggle",
                      order = 10,
                      width = "full",
                      desc = L["This setting will disable threat transparency for target marked, mouseover or casting units and instead use the general transparency settings."],
                      arg = { "threat", "marked", "alpha" }
                    },
                    AbsoluteThreatAlpha = {
                      name = L["Use threat transparency as additive transparency and add or substract it from the general transparency settings."],
                      order = 20,
                      type = "toggle",
                      width = "full",
                      arg = { "threat", "AdditiveAlpha" },
                    },
                  },
                },
              },
            },
            Scale = {
              name = L["Scale"],
              type = "group",
              desc = L["Set scale settings for different threat levels."],
              disabled = function() return not db.threat.ON end,
              order = 1,
              args = {
                Enable = {
                  name = L["Enable Threat Scale"],
                  type = "group",
                  inline = true,
                  order = 0,
                  args = {
                    Enable = {
                      type = "toggle",
                      name = L["Enable"],
                      desc = L["This option allows you to control whether threat affects the scale of nameplates."],
                      descStyle = "inline",
                      width = "full",
                      order = 2,
                      arg = { "threat", "useScale" }
                    },
                  },
                },
                Tank = {
                  name = L["|cff00ff00Tank|r"],
                  type = "group",
                  inline = true,
                  order = 1,
                  disabled = function() return not db.threat.useScale end,
                  args = {
                    Low = GetScaleEntryThreat(L["|cffff0000Low Threat|r"], 1, { "threat", "tank", "scale", "LOW" }),
                    Med = GetScaleEntryThreat(L["|cffffff00Medium Threat|r"], 2, { "threat", "tank", "scale", "MEDIUM" }),
                    High = GetScaleEntryThreat(L["|cff00ff00High Threat|r"], 3, { "threat", "tank", "scale", "HIGH" }),
                    OffTank = GetScaleEntryThreat(L["|cff0faac8Off-Tank|r"], 4, { "threat", "tank", "scale", "OFFTANK" }),
                  },
                },
                DPS = {
                  name = L["|cffff0000DPS/Healing|r"],
                  type = "group",
                  inline = true,
                  order = 2,
                  disabled = function() return not db.threat.useScale end,
                  args = {
                    Low = GetScaleEntryThreat(L["|cff00ff00Low Threat|r"], 1, { "threat", "dps", "scale", "LOW" }),
                    Med = GetScaleEntryThreat(L["|cffffff00Medium Threat|r"], 2, { "threat", "dps", "scale", "MEDIUM" }),
                    High = GetScaleEntryThreat(L["|cffff0000High Threat|r"], 3, { "threat", "dps", "scale", "HIGH" }),
                  },
                },
                Marked = {
                  name = L["Additional Adjustments"],
                  type = "group",
                  inline = true,
                  order = 3,
                  disabled = function() return not db.threat.useScale end,
                  args = {
                    DisableSituational = {
                      name = L["Disable threat scale for target marked, mouseover or casting units."],
                      type = "toggle",
                      order = 10,
                      width = "full",
                      desc = L["This setting will disable threat scale for target marked, mouseover or casting units and instead use the general scale settings."],
                      arg = { "threat", "marked", "scale" }
                    },
                    AbsoluteThreatScale = {
                      name = L["Use threat scale as additive scale and add or substract it from the general scale settings."],
                      order = 20,
                      type = "toggle",
                      width = "full",
                      arg = { "threat", "AdditiveScale" },
                    },
                  },
                },
--                TypeSpecific = {
--                  name = L["Additional Adjustments"],
--                  type = "group",
--                  inline = true,
--                  order = 4,
--                  disabled = function() if db.threat.useScale then return false else return true end end,
--                  args = {
--                    Toggle = {
--                      name = L["Enable Adjustments"],
--                      order = 1,
--                      type = "toggle",
--                      width = "full",
--                      desc = L["This will allow you to add additional scaling changes to specific mob types."],
--                      descStyle = "inline",
--                      arg = { "threat", "useType" }
--                    },
--                    AdditionalSliders = {
--                      name = L["Additional Adjustments"],
--                      type = "group",
--                      order = 3,
--                      inline = true,
--                      disabled = function() if not db.threat.useType or not db.threat.useScale then return true else return false end end,
--                      args = {
--                        Mini = {
--                          name = L["Minor"],
--                          order = 0.5,
--                          type = "range",
--                          width = "double",
--                          arg = { "threat", "scaleType", "Minus" },
--                          min = -0.5,
--                          max = 0.5,
--                          step = 0.01,
--                          isPercent = true,
--                        },
--                        NormalNeutral = {
--                          name = PLAYER_DIFFICULTY1 .. " & " .. COMBATLOG_FILTER_STRING_NEUTRAL_UNITS,
--                          order = 1,
--                          type = "range",
--                          width = "double",
--                          arg = { "threat", "scaleType", "Normal" },
--                          min = -0.5,
--                          max = 0.5,
--                          step = 0.01,
--                          isPercent = true,
--                        },
--                        Elite = {
--                          name = ELITE,
--                          order = 2,
--                          type = "range",
--                          width = "double",
--                          arg = { "threat", "scaleType", "Elite" },
--                          min = -0.5,
--                          max = 0.5,
--                          step = 0.01,
--                          isPercent = true,
--                        },
--                        Boss = {
--                          name = BOSS,
--                          order = 3,
--                          type = "range",
--                          width = "double",
--                          arg = { "threat", "scaleType", "Boss" },
--                          min = -0.5,
--                          max = 0.5,
--                          step = 0.01,
--                          isPercent = true,
--                        },
--                      },
--                    },
--                  },
--                },
              },
            },
            Coloring = {
              name = L["Coloring"],
              type = "group",
              order = 4,
              get = GetColorAlpha,
              set = SetColorAlpha,
              disabled = function() return not db.threat.ON end,
              args = {
                Toggles = {
                  name = L["Enable Threat Coloring of Healthbar"],
                  order = 1,
                  type = "group",
                  inline = true,
                  args = {
                    UseHPColor = {
                      name = L["Enable"],
                      type = "toggle",
                      order = 1,
                      desc = L["This option allows you to control whether threat affects the healthbar color of nameplates."],
                      get = GetValue,
                      set = SetValue,
                      descStyle = "inline",
                      width = "full",
                      arg = { "threat", "useHPColor" }
                    },
                  },
                },
                Tank = {
                  name = L["|cff00ff00Tank|r"],
                  type = "group",
                  inline = true,
                  order = 2,
                  --disabled = function() if db.threat.useHPColor then return false else return true end end,
                  args = {
                    Low = {
                      name = L["|cffff0000Low Threat|r"],
                      type = "color",
                      order = 1,
                      arg = { "settings", "tank", "threatcolor", "LOW" },
                      hasAlpha = true,
                    },
                    Med = {
                      name = L["|cffffff00Medium Threat|r"],
                      type = "color",
                      order = 2,
                      arg = { "settings", "tank", "threatcolor", "MEDIUM" },
                      hasAlpha = true,
                    },
                    High = {
                      name = L["|cff00ff00High Threat|r"],
                      type = "color",
                      order = 3,
                      arg = { "settings", "tank", "threatcolor", "HIGH" },
                      hasAlpha = true,
                    },
                    OffTank = {
                      name = L["|cff0faac8Off-Tank|r"],
                      type = "color",
                      order = 5,
                      arg = { "settings", "tank", "threatcolor", "OFFTANK" },
                      hasAlpha = true,
                      disabled = function() return not db.threat.toggle.OffTank end
                    },
                  },
                },
                DPS = {
                  name = L["|cffff0000DPS/Healing|r"],
                  type = "group",
                  inline = true,
                  order = 3,
                  --disabled = function() if db.threat.useHPColor then return false else return true end end,
                  args = {
                    Low = {
                      name = L["|cff00ff00Low Threat|r"],
                      type = "color",
                      order = 1,
                      arg = { "settings", "dps", "threatcolor", "LOW" },
                      hasAlpha = true,
                    },
                    Med = {
                      name = L["|cffffff00Medium Threat|r"],
                      type = "color",
                      order = 2,
                      arg = { "settings", "dps", "threatcolor", "MEDIUM" },
                      hasAlpha = true,
                    },
                    High = {
                      name = L["|cffff0000High Threat|r"],
                      type = "color",
                      order = 3,
                      arg = { "settings", "dps", "threatcolor", "HIGH" },
                      hasAlpha = true,
                    },
                  },
                },
              },
            },
            DualSpec = {
              name = L["Role"],
              type = "group",
              desc = L["Set the roles your specs represent."],
              disabled = function() return not db.threat.ON end,
              order = 5,
              args = CreateSpecRoles(),
            },
            Textures = {
              name = L["Textures"],
              type = "group",
              order = 3,
              desc = L["Set threat textures and their coloring options here."],
              disabled = function() return not db.threat.ON end,
              args = {
                ThreatArt = {
                  name = L["Enable Threat Textures"],
                  type = "group",
                  order = 1,
                  inline = true,
                  args = {
                    Enable = {
                      name = L["Enable"],
                      type = "toggle",
                      order = 1,
                      desc = L["This option allows you to control whether textures are hidden or shown on nameplates for different threat levels. Dps/healing uses regular textures, for tanking textures are swapped."],
                      descStyle = "inline",
                      width = "full",
                      set = function(info, val) SetValuePlain(info, val); Addon.Widgets:InitializeWidget("Threat") end,
                      arg = { "threat", "art", "ON" },
                    },
                  },
                },
                Options = {
                  name = L["Art Options"],
                  type = "group",
                  order = 2,
                  inline = true,
                  disabled = function() return not db.threat.art.ON end,
                  args = {
                    PrevOffTank = {
                      name = L["Off-Tank"],
                      type = "execute",
                      order = 1,
                      width = "full",
                      image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ThreatWidget\\" .. db.threat.art.theme .. "\\" .. "OFFTANK",
                      imageWidth = 256,
                      imageHeight = 64,
                      disabled = function() return not db.threat.toggle.OffTank end
                    },
                    PrevLow = {
                      name = L["Low Threat"],
                      type = "execute",
                      order = 2,
                      width = "full",
                      image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ThreatWidget\\" .. db.threat.art.theme .. "\\" .. "HIGH",
                      imageWidth = 256,
                      imageHeight = 64,
                    },
                    PrevMed = {
                      name = L["Medium Threat"],
                      type = "execute",
                      order = 3,
                      width = "full",
                      image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ThreatWidget\\" .. db.threat.art.theme .. "\\" .. "MEDIUM",
                      imageWidth = 256,
                      imageHeight = 64,
                    },
                    PrevHigh = {
                      name = L["High Threat"],
                      type = "execute",
                      order = 4,
                      width = "full",
                      image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ThreatWidget\\" .. db.threat.art.theme .. "\\" .. "LOW",
                      imageWidth = 256,
                      imageHeight = 64,
                    },
                    Style = {
                      name = L["Style"],
                      type = "group",
                      order = 10,
                      inline = true,
                      args = {
                        Dropdown = {
                          name = "",
                          type = "select",
                          order = 1,
                          set = function(info, val)
                            SetValue(info, val)
                            local i = options.args.ThreatOptions.args.Textures.args.Options.args
                            local p = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ThreatWidget\\"
                            i.PrevOffTank.image = p .. db.threat.art.theme .. "\\" .. "OFFTANK"
                            i.PrevLow.image = p .. db.threat.art.theme .. "\\" .. "HIGH"
                            i.PrevMed.image = p .. db.threat.art.theme .. "\\" .. "MEDIUM"
                            i.PrevHigh.image = p .. db.threat.art.theme .. "\\" .. "LOW"
                          end,
                          values = { default = "Default", bar = "Bar Style" },
                          arg = { "threat", "art", "theme" }
                        },
                      },
                    },
                    Marked = {
                      name = L["Target Marked Units"],
                      type = "group",
                      inline = true,
                      order = 20,
                      args = {
                        Toggle = {
                          name = L["Ignore Marked Units"],
                          order = 2,
                          type = "toggle",
                          desc = L["This will allow you to disable threat art on target marked units."],
                          descStyle = "inline",
                          width = "full",
                          arg = { "threat", "marked", "art" }
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
        Widgets = CreateWidgetOptions(),
        Totems = {
          name = L["Totems"],
          type = "group",
          childGroups = "list",
          order = 50,
          args = {},
        },
        Custom = {
          name = L["Custom Nameplates"],
          type = "group",
          childGroups = "list",
          order = 60,
          args = {},
        },
        About = {
          name = L["About"],
          type = "group",
          order = 80,
          args = {
            AboutInfo = {
              type = "description",
              order = 2,
              width = "full",
              name = L["Clear and easy to use threat-reactive nameplates.\n\nCurrent version: "] .. GetAddOnMetadata("TidyPlates_ThreatPlates", "version") .. L["\n\nFeel free to email me at |cff00ff00threatplates@gmail.com|r\n\n--\n\nBlacksalsify\n\n(Original author: Suicidal Katt - |cff00ff00Shamtasticle@gmail.com|r)"],
            },
            Header1 = {
              order = 3,
              type = "header",
              name = "Translators",
            },
            Translators1 = {
              type = "description",
              order = 4,
              width = "full",
              name = "deDE: Blacksalsify (original  author: Aideen@Perenolde/EU)"
            },
						Translators2 = {
							type = "description",
							order = 5,
							width = "full",
							name = "esES: Woopy"
						},
						Translators3 = {
							type = "description",
							order = 6,
							width = "full",
							name = "esMX: Woopy"
						},
--						Translators4 = {
--							type = "description",
--							order = 7,
--							width = "full",
--							name = "frFR: Need Translator!!"
--						},
            Translators5 = {
              type = "description",
              order = 8,
              width = "full",
              name = "koKR: yuk6196 (CurseForge)"
            },
--						Translators6 = {
--							type = "description",
--							order = 9,
--							width = "full",
--							name = "ruRU: Need Translator!!"
--						},
--            Translators7 = {
--              type = "description",
--              order = 10,
--              width = "full",
--              name = "zhCN: y123ao6 (CurseForge)"
--            },
						Translators8 = {
							type = "description",
							order = 11,
							width = "full",
							name = "zhTW: gaspy10 (CurseForge)"
						},
          },
        },
      },
    }
  end
  local ClassOpts_OrderCount = 1
  local ClassOpts = {
    Style = {
      name = "Style",
      order = -1,
      type = "select",
      width = "full",
      set = function(info, val)
        SetValue(info, val)
        for k_c, v_c in pairs(CLASS_SORT_ORDER) do
          options.args.Widgets.args.ClassIconWidget.args.Textures.args["Prev" .. k_c].image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ClassIconWidget\\" .. db.classWidget.theme .. "\\" .. CLASS_SORT_ORDER[k_c]
        end
      end,
      values = { default = "Default", transparent = "Transparent", crest = "Crest", clean = "Clean" },
      arg = { "classWidget", "theme" },
    },
  };
  for k_c, v_c in pairs(CLASS_SORT_ORDER) do
    ClassOpts["Prev" .. k_c] = {
      name = CLASS_SORT_ORDER[k_c],
      type = "execute",
      order = ClassOpts_OrderCount,
      image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ClassIconWidget\\" .. db.classWidget.theme .. "\\" .. CLASS_SORT_ORDER[k_c],
    }
    ClassOpts_OrderCount = ClassOpts_OrderCount + 1
  end
  options.args.Widgets.args.ClassIconWidget.args.Textures.args = ClassOpts

  local TotemOpts = {
    TotemSettings = {
      name = L["|cffffffffTotem Settings|r"],
      type = "group",
      order = 0,
      get = GetValue,
      set = SetValue,
      args = {
        Toggles = {
          name = L["Toggling"],
          type = "group",
          order = 1,
          inline = true,
          args = {
            HideHealth = {
              name = L["Hide Healthbars"],
              type = "toggle",
              order = 1,
              width = "double",
              arg = { "totemSettings", "hideHealthbar" },
            },
          },
        },
        Icon = {
          name = L["Icon"],
          type = "group",
          order = 2,
          inline = true,
          args = {
            Show = {
              name = L["Enable"],
              order = 5,
              type = "toggle",
              set = function(info, val) SetValuePlain(info, val); Addon.Widgets:InitializeWidget("TotemIcon") end,
              arg = { "totemWidget", "ON" },
            },
            Size = GetSizeEntryDefault(10, "totemWidget"),
            Offset = GetPlacementEntryWidget(30, "totemWidget"),
          },
        },
        Alpha = {
          name = L["Transparency"],
          type = "group",
          order = 3,
          inline = true,
          args = {
            TotemAlpha = {
              name = L["Totem Transparency"],
              order = 1,
              type = "range",
              width = "full",
              step = 0.05,
              min = 0,
              max = 1,
              isPercent = true,
              set = function(info, val) SetValue(info, abs(val - 1)) end,
              get = function(info) return 1 - GetValue(info) end,
              arg = { "nameplate", "alpha", "Totem" },
            },
          },
        },
        Scale = {
          name = L["Scale"],
          type = "group",
          order = 4,
          inline = true,
          args = {
            TotemScale = GetScaleEntryWidget(L["Totem Scale"], 1, { "nameplate", "scale", "Totem" }),
          }
        },
      },
    },
  };

  local totem_list = {}
  local i = 1
  for name, data in pairs(Addon.TotemInformation) do
    totem_list[i] = data
    i = i + 1
  end

  -- properly no longer possible if 7.3.5+ GetSpellInfo changes go live
  table.sort(totem_list, function(a, b) return a.SortKey  < b.SortKey end)

  for i, totem_info in ipairs(totem_list) do
    TotemOpts[totem_info.Name] = {
      name = "|cff" .. totem_info.GroupColor .. totem_info.Name .. "|r",
      type = "group",
      order = i,
      args = {
        Header = {
          name = "> |cff" .. totem_info.GroupColor .. totem_info.Name .. "|r <",
          type = "header",
          order = 0,
        },
        Enabled = {
          name = L["Enable"],
          type = "group",
          inline = true,
          order = 1,
          args = {
            Toggle = {
              name = L["Show Nameplate"],
              type = "toggle",
              arg = { "totemSettings", totem_info.ID, "ShowNameplate" },
            },
          },
        },
        HealthColor = {
          name = L["Health Coloring"],
          type = "group",
          order = 2,
          inline = true,
          args = {
            Enable = {
              name = L["Enable Custom Color"],
              type = "toggle",
              order = 1,
              arg = { "totemSettings", totem_info.ID, "ShowHPColor" },
            },
            Color = {
              name = L["Color"],
              type = "color",
              order = 2,
              get = GetColor,
              set = SetColor,
              arg = { "totemSettings", totem_info.ID, "Color" },
            },
          },
        },
        Textures = {
          name = L["Icon"],
          type = "group",
          order = 3,
          inline = true,
          args = {
            Icon = {
              name = "",
              type = "execute",
              width = "full",
              order = 0,
              image = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\TotemIconWidget\\" .. db.totemSettings[totem_info.ID].Style .. "\\" .. totem_info.ID,
            },
            Style = {
              name = "",
              type = "select",
              order = 1,
              width = "full",
              set = function(info, val)
                SetValue(info, val)
                options.args.Totems.args[totem_info.Name].args.Textures.args.Icon.image = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\TotemIconWidget\\" .. db.totemSettings[totem_info.ID].Style .. "\\" .. totem_info.ID;
              end,
              values = { normal = "Normal", special = "Special" },
              arg = { "totemSettings", totem_info.ID, "Style" },
            },
          },
        },
      },
    }
  end

  options.args.Totems.args = TotemOpts;

  options.args.Custom.args = CreateCustomNameplatesGroup()
  UpdateSpecial()

  options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(TidyPlatesThreat.db)
  options.args.profiles.order = 10000;
end

local function GetInterfaceOptionsTable()
  local interface_options = {
    name = t.Meta("title") .. " v" .. t.Meta("version"),
    handler = TidyPlatesThreat,
    type = "group",
    args = {
      note = {
        type = "description",
        name = L["You can access the "] .. t.Meta("titleshort") .. L[" options by typing: /tptp"],
        order = 10,
      },
      openoptions = {
        type = "execute",
        name = L["Open Options"],
        image = PATH_ART .. "Logo",
        width = "full",
        imageWidth = 256,
        imageHeight = 32,
        func = function()
          TidyPlatesThreat:OpenOptions()
        end,
        order = 20,
      },
    },
  }

  return interface_options
end

function TidyPlatesThreat:ProfChange()
  db = self.db.profile

  Addon:InitializeCustomNameplates()

  -- Update preview icons: EliteArtWidget, TargetHighlightWidget, ClassIconWidget, QuestWidget, Threat Textures, Totem Icons, Custom Nameplate Icons
  local path = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\"

  -- Update options stuff after profile change
  if options then
    options.args.NameplateSettings.args.EliteIcon.args.Texture.args.PreviewRare.image = path .. "EliteArtWidget\\" .. db.settings.eliteicon.theme
    options.args.NameplateSettings.args.EliteIcon.args.Texture.args.PreviewElite.image = path .. "EliteArtWidget\\" .. "elite-" .. db.settings.eliteicon.theme

    local base = options.args.Widgets.args
    base.TargetArtWidget.args.Texture.args.Preview.image = path .. "TargetArtWidget\\" .. db.targetWidget.theme;
    for k_c, v_c in pairs(CLASS_SORT_ORDER) do
      base.ClassIconWidget.args.Textures.args["Prev" .. k_c].image = path .. "ClassIconWidget\\" .. db.classWidget.theme .. "\\" .. CLASS_SORT_ORDER[k_c]
    end
    --base.QuestWidget.args.ModeIcon.args.Texture.args.Preview.image = path .. "QuestWidget\\" .. db.questWidget.IconTexture

    local threat_path = path .. "ThreatWidget\\" .. db.threat.art.theme .. "\\"
    base = options.args.ThreatOptions.args.Textures.args.Options.args
    base.PrevOffTank.image = threat_path .. "OFFTANK"
    base.PrevLow.image = threat_path .. "HIGH"
    base.PrevMed.image = threat_path .. "MEDIUM"
    base.PrevHigh.image = threat_path .. "LOW"

    for _, totem_info in pairs(Addon.TotemInformation) do
      options.args.Totems.args[totem_info.Name].args.Textures.args.Icon.image = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\TotemIconWidget\\" .. db.totemSettings[totem_info.ID].Style .. "\\" .. totem_info.ID
    end

    options.args.Custom.args = CreateCustomNameplatesGroup()
  end

  TidyPlatesThreat:ReloadTheme()
end

function TidyPlatesThreat:OpenOptions()
  db = self.db.profile

  HideUIPanel(InterfaceOptionsFrame)
  HideUIPanel(GameMenuFrame)

  if not options then
    CreateOptionsTable()
    Addon:ForceUpdate()

    -- Setup options dialog
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(t.ADDON_NAME, options)
    Addon.LibAceConfigDialog:SetDefaultSize(t.ADDON_NAME, 1000, 640)
  end

  LibStub("AceConfigDialog-3.0"):Open(t.ADDON_NAME);
end

-----------------------------------------------------
-- External
-----------------------------------------------------
t.GetInterfaceOptionsTable = GetInterfaceOptionsTable
