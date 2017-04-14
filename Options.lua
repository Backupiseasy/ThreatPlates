local _, ns = ...
local t = ns.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local L = t.L
local class = t.Class()
local path = t.Art
local TotemNameBySpellID = t.TotemNameBySpellID

local TidyPlatesThreat = LibStub("AceAddon-3.0"):GetAddon("TidyPlatesThreat");
local db;

local UNIT_TYPES = {
  {
    Faction = "Friendly", Disabled = "nameplateShowFriends",
    UnitTypes = { "Player", "NPC", "Totem", "Guardian", "Pet" }
  },
  {
    Faction = "Enemy", Disabled = "nameplateShowEnemies",
    UnitTypes = { "Player", "NPC", "Totem", "Guardian", "Pet", "Minor" }
  },
  {
    Faction = "Neutral", Disabled = "nameplateShowEnemies",
    UnitTypes = { "NPC", "Guardian", "Minor" }
  }
}

-- Functions

local function GetSpellName(number)
  local n = GetSpellInfo(number)
  return n
end

local function UpdateSpecial() -- Need to add a way to update options table.
  db.uniqueSettings.list = {};
  for k_c, k_v in pairs(db.uniqueSettings) do
    if db.uniqueSettings[k_c].name then
      if type(db.uniqueSettings[k_c].name) == "string" then
        db.uniqueSettings.list[k_c] = db.uniqueSettings[k_c].name
      end
    end
  end
  t.Update()
end

t.UpdateSpecial = UpdateSpecial

local function GetValue(info)
  local DB = TidyPlatesThreat.db.profile
  local value = DB
  local keys = info.arg
  for index = 1, #keys do
    value = value[keys[index]]
  end
  return value
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
  -- info: table with path to setting in options dialog, that was changed
  -- info.arg: table with parameter arg from options definition
  local DB = TidyPlatesThreat.db.profile
  local keys = info.arg
  for index = 1, #keys - 1 do
    DB = DB[keys[index]]
  end
  DB[keys[#keys]] = value
  t.Update()
end

local function SetValueForceUpdate(info, value)
	SetValuePlain(info, value)
	--TidyPlates:ResetWidgets()
	TidyPlates:ForceUpdate()
end

local function SetValueResetWidgets(info, value)
	SetValuePlain(info, value)
	TidyPlates:ResetWidgets()
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
  t.Update()
end

local function GetCvar(info)
  local value = GetCVar(info.arg)
  if value == "1" then
    return true
  else
    return false
  end
end

local function SetCvar(info)
	if InCombatLockdown() then
		t.Print("We're unable to change this while in combat", true)
	else
    local value = abs(GetCVar(info.arg) - 1)
    SetCVar(info.arg, value)
    t.Update()
	end
end

local function GetWoWCVar(cvar)
  return (GetCVar(cvar) == "1")
end

local function SetWoWCVar(cvar, value)
  if InCombatLockdown() then
    t.Print("We're unable to change this while in combat", true)
  else
    SetCVar(cvar, (value and 1) or 0)
    t.Update()
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
  t.Update()
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
  t.Update()
end

local function SetColorAlphaAuraWidget(info, r, g, b, a)
  local DB = TidyPlatesThreat.db.profile
  local keys = info.arg
  for index = 1, #keys - 1 do
    DB = DB[keys[index]]
  end
  DB[keys[#keys]].r, DB[keys[#keys]].g, DB[keys[#keys]].b, DB[keys[#keys]].a = r, g, b, a
	ThreatPlatesWidgets.ForceAurasUpdate()
	TidyPlates:ForceUpdate()
end

local function SetColorAuraWidget(info, r, g, b)
	local DB = TidyPlatesThreat.db.profile
	local keys = info.arg
	for index = 1, #keys - 1 do
		DB = DB[keys[index]]
	end
	DB[keys[#keys]].r, DB[keys[#keys]].g, DB[keys[#keys]].b = r,g,b
	ThreatPlatesWidgets.ForceAurasUpdate()
  TidyPlates:ForceUpdate()
end

local function GetUnitVisibilitySetting(info)
  local unit_type = info.arg
  local unit_visibility = TidyPlatesThreat.db.profile.Visibility[unit_type].Show

  if type(unit_visibility)  ~= "boolean" then
    unit_visibility = (GetCVar(unit_visibility) == "1")
  end

  return unit_visibility
end

local function SetUnitVisibilitySetting(info, value)
  local unit_type = info.arg
  local unit_visibility = TidyPlatesThreat.db.profile.Visibility[unit_type]

  if type(unit_visibility.Show) == "boolean" then
    unit_visibility.Show = value
  else
    SetWoWCVar(unit_visibility.Show, value)
  end
  TidyPlates:ForceUpdate()
end

-- Set Theme Values

local function SetThemeValue(info, val)
  SetValue(info, val)
  t.SetThemes(TidyPlatesThreat)
  -- TODO: should not be necessary here
  if (TidyPlatesOptions.ActiveTheme == t.THEME_NAME) then
    TidyPlates:SetTheme(t.THEME_NAME)
  end
end

-- Set widget values

local function SetValueAuraWidget(info, val)
  SetValuePlain(info, val)
  ThreatPlatesWidgets.ConfigAuraWidget()
  TidyPlates:ForceUpdate()
end

---- Validate functions for AceConfig
--local function ValidatePercentage(info, val)
----  if string:match(val, "^%d+%%") then
----    return true
----  else
--  print ("lksjdflsjlfjslkfj")
--    return "ERROR - Input must be a percentage (number + '%')"
----  end
--end

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

local function GetColorEntry(pos, setting, disabled_func)
  return {
    name = L["Color"],
    order = pos,
    type = "color",
    width = "half",
    arg = setting,
    get = GetColor,
    set = SetColor,
    hasAlpha = false,
    disabled = disabled_func
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

---------------------------------------------------------------------------------------------------
-- Functions to generate TP options elemements
---------------------------------------------------------------------------------------------------

local function GetEnableEntry(entry_name, description, widget_info, enable_hv)
  local entry = {
    name = entry_name,
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
        name = L["Show in Healthbar View"],
        order = 2,
        type = "toggle",
        width = "double",
        arg = { widget_info, "ON" },
      },
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

local function GetEnableEntryTheme(entry_name, description, widget_info, enable_hv)
  local entry = {
    name = L["Enable "] .. entry_name,
    order = 5,
    type = "group",
    inline = true,
    desc = description,
    descStyle = "inline",
    args = {
      Enable = {
        name = L["Show in Healthbar View"],
        order = 1,
        type = "toggle",
        width = "double",
        set = SetThemeValue,
        arg = { "settings", widget_info, "show" },
      },
    },
  }

  if enable_hv then
    entry.args.EnableHV = {
      name = L["Show in Headline View"],
      order = 2,
      type = "toggle",
      descStyle = "inline",
      width = "double",
      set = SetThemeValue,
      arg = {"settings", widget_info, "ShowInHeadlineView" },
    }
  else
    entry.args.EoL = {
      name = "",
      order = 2,
      type = "description",
      width = "full",
    }
  end

  return entry
end

local function GetSizeEntry(pos, setting, func_disabled)
  local entry = {
    name = L["Size"],
    order = pos,
    type = "range",
    step = 1,
    arg = { setting, "scale" },
    disabled = func_disabled,
  }
  return entry
end

local function GetSizeEntryTheme(pos, setting)
  local entry = {
    name = L["Size"],
    order = pos,
    type = "range",
    step = 1,
    arg = { "settings", setting, "scale" },
  }
  return entry
end

local function GetScaleEntryBase(pos, setting)
  local entry = {
    name = L["Scale"],
    order = pos,
    type = "range",
    arg = setting,
    step = 0.05,
    softMin = 0.6,
    softMax = 1.3,
    isPercent = true,
    arg = setting,
  }
  return entry
end

local function GetScaleEntryBase200(pos, setting)
  local entry = GetScaleEntryBase(pos, setting)
  entry.softMax = 2.0
  return entry
end

local function GetUnitScaleEntry(entry_name, pos, setting)
  local entry = {
    name = entry_name,
    order = pos,
    type = "range",
    --width = "full",
    step = 0.05,
    softMin = 0.6,
    softMax = 1.3,
    isPercent = true,
    arg = setting,
  }
  return entry
end

local function GetAnchorEntry(pos, setting, anchor, func_disabled)
  local entry = {
    name = L["Anchor Point"],
    order = pos,
    type = "select",
    values = t.ANCHOR_POINT,
    arg = { setting, "anchor" },
    disabled = func_disabled,
  }
  return entry
end

local function GetAlphaEntry(pos, setting, func_disabled)
  local entry = {
    name = L["Alpha"],
    order = pos,
    type = "range",
    step = 0.05,
    min = 0,
    max = 1,
    isPercent = true,
    arg = { setting, "alpha" },
    disabled = func_disabled,
  }
  return entry
end

local function GetAlphaEntryBase(pos, setting)
  local entry = {
    name = L["Alpha"],
    order = pos,
    type = "range",
    step = 0.05,
    min = 0,
    max = 1,
    isPercent = true,
    arg = setting
  }
  return entry
end

local function GetAlphaEntryUnit(entry_name, pos, setting)
  local entry = {
    name = entry_name,
    order = pos,
    type = "range",
    step = 0.05,
    min = 0,
    max = 1,
    isPercent = true,
    arg = setting,
  }
  return entry
end

local function GetPlacementEntryTheme(pos, setting, hv_mode)
  local x_name, y_name
  if hv_mode == true then
    x_name = L["Healthbar X"]
    y_name = L["Healthbar Y"]
  else
    x_name = L["X"]
    y_name = L["Y"]
  end

  local entry = {
    name = L["Placement"],
    order = pos,
    type = "group",
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
    x_name = L["Healthbar X"]
    y_name = L["Healthbar Y"]
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
      HealthbarX = { type = "range", order = 1, name = L["Healthbar X"], min = -120, max = 120, step = 1, arg = { widget_info, "x" } },
      HealthbarY = { type = "range", order = 2, name = L["Healthbar Y"], min = -120, max = 120, step = 1, arg = { widget_info, "y" } },
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
      Size = GetSizeEntry(10, widget_info),
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

local function AddLayoutOptions(args, pos, widget_info)
  args.Sizing = GetSizeEntry(pos, widget_info)
  args.Alpha = GetAlphaEntry(pos + 10, widget_info)
  args.Placement = GetPlacementEntryWidget(pos + 20, widget_info, true)
end

local function RaidMarksOptions()
  local options =  {
    name = L["Raid Marks"],
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
--            Header = {
--              name = L["Enables the showing of the raid mark icon on nameplates."],
--              order = 1,
--              type = "description",
--              width = "full",
--            },
          Enable = {
            name = L["Show Raid Mark Icon in Healthbar View"],
            order = 2,
            type = "toggle",
            width = "double",
            arg = { "settings", "raidicon", "show" },
          },
          EnableHV = {
            name = L["Show Raid Mark Icon in Headline View"],
            order = 3,
            type = "toggle",
            descStyle = "inline",
            width = "double",
            arg = {"settings", "raidicon", "ShowInHeadlineView" },
          },
          EnableHealthbarView = {
            name = L["Color Healthbar by Raid Marks in Healthbar View"],
            order = 4,
            type = "toggle",
            width = "double",
            set = SetValue,
            get = GetValue,
            arg = { "settings", "raidicon", "hpColor" },
          },
          EnableHeadlineView = {
            name = L["Color Name Text by Raid Marks in Headline View"],
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
        disabled = function() return not (db.settings.raidicon.hpColor or db.HeadlineView.UseRaidMarkColoring) end,
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
          SquestwidgetUARE = {
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

local function ClassIconsWidgetOptions()
  local options = { name = L["Class Icons"], order = 30, type = "group",
    args = {
      Enable = GetEnableEntry(L["Enable Class Icons Widget"], L["This widget will display class icons on nameplate with the settings you set below."], "classWidget", true),
      Options = {
        name = L["Options"],
        type = "group",
        inline = true,
        order = 20,
--        disabled = function() return not db.classWidget.ON end,
        args = {
          FriendlyClass = {
            name = L["Enable Friendly Icons"],
            type = "toggle",
            desc = L["Enable the showing of friendly player class icons."],
            descStyle = "inline",
            width = "full",
            arg = { "friendlyClassIcon" },
          },
          FriendlyCaching = {
            name = L["Friendly Caching"],
            type = "toggle",
            desc = L["This allows you to save friendly player class information between play sessions or nameplates going off the screen.|cffff0000(Uses more memory)"],
            descStyle = "inline",
            width = "full",
--            disabled = function() if not db.friendlyClassIcon or not db.classWidget.ON then return true else return false end end,
            arg = { "cacheClass" }
          },
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

local function QuestWidgetOptions()
  local options =  {
    name = L["Quest"],
    order = 90,
    type = "group",
    args = {
      Enable = GetEnableEntry(L["Enable Quest Widget"], L["Enables highlighting of nameplates of mobs involved with any of your current quests."], "questWidget", true),
      Visibility = { type = "group",	order = 10,	name = L["Visibility"], inline = true,
--        disabled = function() return not db.questWidget.ON end,
        args = {
          InCombatAll = { type = "toggle", order = 10, name = L["Hide in Combat"],	arg = {"questWidget", "HideInCombat"}, },
          InCombatAttacked = { type = "toggle", order = 20, name = L["Hide on Attacked Units"],	arg = {"questWidget", "HideInCombatAttacked"}, },
          InInstance = { type = "toggle", order = 30, name = L["Hide in Instance"],	arg = {"questWidget", "HideInInstance"}, },
        },
      },
      ModeHealthBar = {
        name = L["Healthbar Mode"], order = 20, type = "group", inline = true,
--        disabled = function() return not db.questWidget.ON end,
        args = {
          Help = { type = "description", order = 0,	width = "full",	name = L["Use a custom color for the healthbar of quest mobs."],	},
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
          Help = { type = "description", order = 0,	width = "full",	name = L["Show an indicator icon at the nameplate for quest mobs."],	},
          Enable = {
            name = L["Enable"],
            order = 10,
            type = "toggle",
            width = "half",
            arg = {"questWidget", "ModeIcon"},
          },
        },
      },
    },
  }
  AddLayoutOptions(options.args.ModeIcon.args, 80, "questWidget")
  return options
end

local function StealthWidgetOptions()
  local options =  {
    name = L["Stealth"],
    order = 60,
    type = "group",
    args = {
      Enable = GetEnableEntry(L["Enable Stealth Widget (Feature not yet fully implemented!)"], L["Shows a stealth icon above the nameplate of units that can detect you while stealthed."], "stealthWidget", true),
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
      disabled = function() return not (GetWoWCVar("nameplateShowAll") and TidyPlatesThreat.db.profile.HeadlineView.ON) end,
      args = {},
    }

    for i, unit_type in ipairs(value.UnitTypes) do
      args[faction .. "Units"].args["UnitType" .. faction .. unit_type] = {
        name = L[unit_type],
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
      disabled = function() return not (GetWoWCVar("nameplateShowAll") and GetWoWCVar(value.Disabled)) end,
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


local function CreateTabGeneralSettings()
  local args = {
    name = L["Visibility"],
    type = "group",
    order = 10,
    args = {
      TidyPlates = {
        name = "Tidy Plates Fading",
        type = "group",
        order = 10,
        inline = true,
        args = {
          Enable = {
            type = "toggle",
            order = 1,
            name = "Enable",
            desc = "This allows you to disable or enable the nameplates fading in or out when displayed or hidden.",
            descStyle = "inline",
            width = "full",
            set = function(info, val)
              SetValue(info, val)
              if db.tidyplatesFade then TidyPlates:EnableFadeIn() else TidyPlates:DisableFadeIn() end
            end,
            arg = { "tidyplatesFade" },
          },
        },
      },
      GeneralUnits = {
        name = L["General Nameplate Settings"],
        order = 20,
        type = "group",
        inline = true,
        width = "full",
--        get = GetCVarSettingSync,
--        set = SetCVarSettingSync,
        get = GetCvar,
        set = SetCvar,
        args = {
          Description = GetDescriptionEntry(L["This allows to configure which nameplates should be shown while you are playing."]),
          Spacer0 = GetSpacerEntry(1),
          AllUnits = { name = L["Enable Nameplates"], order = 10, type = "toggle", arg = "nameplateShowAll" },
          AllUnitsDesc = { name = L["Show all name plates (CTRL-V)."], order = 15, type = "description", width = "double", },
          Spacer1 = { type = "description", name = "", order = 19, },
          AllFriendly = { name = L["Enable Friendly"], order = 20, type = "toggle", arg = "nameplateShowFriends", disabled = function() return not GetWoWCVar("nameplateShowAll") end },
          AllFriendlyDesc = { name = L["Show friendly name plates (SHIFT-V)."], order = 25, type = "description", width = "double", },
          Spacer2 = { type = "description", name = "", order = 29, },
          AllHostile = { name = L["Enable Enemy"], order = 30, type = "toggle", arg = "nameplateShowEnemies", disabled = function() return not GetWoWCVar("nameplateShowAll") end },
          AllHostileDesc = { name = L["Show enemy name plates (ALT-V)."], order = 35, type = "description", width = "double", },
        },
      },
      -- TidyPlatesHub calls this Unit Filter
      SpecialUnits = {
        name = L["Hide Special Units"],
        type = "group",
        order = 90,
        inline = true,
        width = "full",
        disabled = function() return not GetWoWCVar("nameplateShowAll") end,
        args = {
          HideNormal = { name = L["Normal"], order = 1, type = "toggle", arg = { "Visibility", "HideNormal" }, },
          HideElite = { name = L["Rare & Elite"], order = 2, type = "toggle", arg = { "Visibility", "HideElite" }, },
          HideBoss = { name = L["Boss"], order = 3, type = "toggle", arg = { "Visibility", "HideBoss" }, },
          HideTapped = { name = L["Tapped"], order = 4, type = "toggle", arg = { "Visibility", "HideTapped" }, },
        },
      },
      Clickthrough = {
        name = L["Nameplate Clickthrough"],
        type = "group",
        order = 100,
        inline = true,
        width = "full",
        disabled = function() return not GetWoWCVar("nameplateShowAll") end,
        args = {
          ClickthroughFriendly = {
            name = L["Enable for Friendly Nameplates"],
            order = 1,
            type = "toggle",
            width = "double",
            set = function(info, val)
              db.NamePlateFriendlyClickThrough = val
              C_NamePlate.SetNamePlateFriendlyClickThrough(val)
            end,
            get = function(info) return db.NamePlateFriendlyClickThrough end,
          },
          ClickthroughEnemy = {
            name = L["Enable for Enemy Nameplates"],
            order = 2,
            type = "toggle",
            width = "double",
            set = function(info, val)
              db.NamePlateEnemyClickThrough = val
              C_NamePlate.SetNamePlateEnemyClickThrough(val) end,
            get = function(info) return db.NamePlateEnemyClickThrough end,
          },
        },
      },
--      OpenBlizzardSettings = {
--        name = L["Open Blizzard Settings"],
--        order = 90,
--        type = "execute",
--        func = function()
--          InterfaceOptionsFrame_OpenToCategory(_G["InterfaceOptionsNamesPanel"])
--          LibStub("AceConfigDialog-3.0"):Close("Tidy Plates: Threat Plates");
--        end,
--      },
    },
  }

  CreateUnitGroupsVisibility(args.args, 30)

  return args
end

-- Return the Options table
local options = nil;
local function GetOptions()
  -- Create a list of specs for the player's class
  local dialog_specs = {
    Automatic_Spec_Detection = {
      name = L["Determine your role (tank/dps/healing) automatically based on current spec."],
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
      args = {}
    }
  }

  for index = 1, GetNumSpecializations() do
    local id, spec_name, description, icon, background, role = GetSpecializationInfo(index)
    dialog_specs["SpecGroup"]["args"][spec_name] = {
      name = spec_name,
      type = "group",
      inline = true,
      order = index + 2,
      disabled = function() return TidyPlatesThreat.db.profile.optionRoleDetectionAutomatic end,
      args = {
        Tank = {
          name = L["Tank"],
          type = "toggle",
          order = 1,
          desc = L["Sets your spec "] .. spec_name .. L[" to tanking."],
          get = function()
            local spec = TidyPlatesThreat.db.char.spec[index]
            if spec == nil then
              return t.SPEC_ROLES[t.Class()][index]
            else
              return spec
            end
          end,
          set = function() TidyPlatesThreat.db.char.spec[index] = true; t.Update() end,
        },
        DPS = {
          name = L["DPS/Healing"],
          type = "toggle",
          order = 2,
          desc = L["Sets your spec "] .. spec_name .. L[" to DPS."],
          get = function()
            local spec = TidyPlatesThreat.db.char.spec[index]
            if spec == nil then
              return not t.SPEC_ROLES[t.Class()][index]
            else
              return not spec
            end
          end,
          set = function() TidyPlatesThreat.db.char.spec[index] = false; t.Update() end,
        },
      },
    }
  end

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
          name = L["Nameplate Settings"],
          type = "group",
          order = 10,
          args = {
            GeneralSettings = CreateTabGeneralSettings(),
            HealthBarView = {
              name = L["Healthbar View"],
              type = "group",
              inline = false,
              order = 20,
              args = {
                HealthBarGroup = {
                  name = L["Textures"],
                  type = "group",
                  inline = true,
                  order = 10,
                  args = {
                    HealthBarTexture = {
                      name = L["Foreground Texture"],
                      type = "select",
                      order = 1,
                      dialogControl = "LSM30_Statusbar",
                      values = AceGUIWidgetLSMlists.statusbar,
                      set = SetThemeValue,
                      arg = { "settings", "healthbar", "texture" },
                    },
                    BGTexture = {
                      name = L["Background Texture"],
                      type = "select",
                      order = 10,
                      dialogControl = "LSM30_Statusbar",
                      values = AceGUIWidgetLSMlists.statusbar,
                      set = SetThemeValue,
                      arg = { "settings", "healthbar", "backdrop" },
                    },
                    Spacer1 = GetSpacerEntry(14),
                    BGColorText = {
                      type = "description",
                      order = 15,
                      width = "single",
                      name = L["Background Color:"],
                    },
                    BGColorForegroundToggle = {
                      name = L["Same as Foreground"],
                      order = 20,
                      type = "toggle",
                      desc = L["Use the healthbar's foreground color also for the background."],
                      set = SetThemeValue,
                      arg = { "settings", "healthbar", "BackgroundUseForegroundColor" },
                    },
                    BGColorCustomToggle = {
                      name = L["Custom"],
                      order = 30,
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
                      name = L["Color"], type = "color",	order = 35,	get = GetColor, set = SetColor, arg = {"settings", "healthbar", "BackgroundColor"},
                      width = "half",
                      disabled = function() return db.settings.healthbar.BackgroundUseForegroundColor end,
                    },
                    BackgroundOpacity = {
                      name = L["Background Opacity"],
                      order = 40,
                      type = "range",
                      min = 0,
                      max = 1,
                      step = 0.01,
                      isPercent = true,
                      arg = { "settings", "healthbar", "BackgroundOpacity" },
                    },
                    Header1 = {
                      type = "header",
                      order = 50,
                      name = "",
                    },
                    HealthBorderToggle = {
                      type = "toggle",
                      width = "double",
                      order = 60,
                      name = L["Show Border"],
                      set = SetThemeValue,
                      arg = { "settings", "healthborder", "show" },
                    },
                    HealthBorder = {
                      type = "select",
                      width = "double",
                      order = 70,
                      name = L["Normal Border"],
                      set = SetThemeValue,
                      disabled = function() if db.settings.healthborder.show then return false else return true end end,
                      values = { TP_HealthBarOverlay = "Default", TP_HealthBarOverlayThin = "Thin" },
                      arg = { "settings", "healthborder", "texture" },
                    },
                    Header2 = {
                      type = "header",
                      order = 75,
                      name = "",
                    },
                    EliteHealthBorderToggle = {
                      type = "toggle",
                      width = "double",
                      order = 80,
                      name = L["Show Elite Border"],
                      arg = { "settings", "elitehealthborder", "show" },
                    },
                    EliteBorder = {
                      type = "select",
                      width = "double",
                      order = 90,
                      name = L["Elite Border"],
                      disabled = function() if db.settings.elitehealthborder.show then return false else return true end end,
                      values = { TP_HealthBarEliteOverlay = "Default", TP_HealthBarEliteOverlayThin = "Thin" },
                      arg = { "settings", "elitehealthborder", "texture" }
                    },
                    Header3 = {
                      type = "header",
                      order = 95,
                      name = "",
                    },
                    Mouseover = {
                      type = "select",
                      width = "double",
                      order = 100,
                      name = L["Mouseover"],
                      set = SetThemeValue,
                      values = { TP_HealthBarHighlight = "Default", Empty = "None" },
                      arg = { "settings", "highlight", "texture" },
                    },
                  },
                },
                Placement = {
                  name = L["Placement"],
                  type = "group",
                  inline = true,
                  order = 20,
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
                ColorSettings = {
                  name = L["Coloring"],
                  type = "group",
                  inline = true,
                  order = 10,
                  args = {
                    HPAmount = {
                      name = L["Color by Health"],
                      order = 2,
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
                        Header = { name = "Colors", type = "header", order = 20, },
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
                          name = L["Enable Enemy Class Colors"],
                          order = 1,
                          type = "toggle",
                          desc = L["Enable the showing of hostile player class color on hp bars."],
                          descStyle = "inline",
                          width = "full",
                          arg = { "allowClass" }
                        },
                        FriendlyClass = {
                          name = L["Enable Friendly Class Colors"],
                          order = 2,
                          type = "toggle",
                          desc = L["Enable the showing of friendly player class color on hp bars."],
                          descStyle = "inline",
                          width = "full",
                          arg = { "friendlyClass" },
                        },
                        FriendlyCaching = {
                          name = L["Friendly Caching"],
                          order = 3,
                          type = "toggle",
                          desc = L["This allows you to save friendly player class information between play sessions or nameplates going off the screen. |cffff0000(Uses more memory)"],
                          descStyle = "inline",
                          width = "full",
                          arg = { "cacheClass" },
                        },
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
                        Header = { name = "Colors", type = "header", order = 10, },
                        FriendlyColorNPC = { name = L["Friendly NPC"], order = 20, type = "color", arg = { "ColorByReaction", "FriendlyNPC", }, },
                        FriendlyColorPlayer = { name = L["Friendly Player"], order = 30, type = "color", arg = { "ColorByReaction", "FriendlyPlayer" }, },
                        EnemyColorNPC = { name = L["Hostile NPC"], order = 40, type = "color", arg = { "ColorByReaction", "HostileNPC" }, },
                        EnemyColorPlayer = { name = L["Hostile Player"], order = 50, type = "color", arg = { "ColorByReaction", "HostilePlayer" }, },
                        NeutralColor = { name = L["Neutral Unit"], order = 60, type = "color", arg = { "ColorByReaction", "NeutralUnit" }, },
                        TappedColor = { name = L["Tapped Unit"], order = 70, type = "color", arg = { "ColorByReaction", "TappedUnit" }, },
                        --FriendColor = { name = L["Friend"], order = 80, type = "color", arg = { "ColorByReaction", "Friend" }, },
                        --GuildMemberColor = { name = L["Guild Member"], order = 80, type = "color", arg = { "ColorByReaction", "GuildMember" }, },
                      },
                    },
                    RaidMark = {
                      name = L["Color by Raid Mark"],
                      order = 40,
                      type = "group",
                      inline = true,
                      get = GetColor,
                      set = SetColor,
                      args = {
                        EnableRaidMarks = {
                          name = L["Additionally color the healthbar based on the raid mark if the nameplate is marked."],
                          order = 1,
                          type = "toggle",
                          width = "full",
                          set = SetValue,
                          get = GetValue,
                          arg = { "settings", "raidicon", "hpColor" },
                        },
                        Header = { name = "Colors", type = "header", order = 20, },
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
                        SquestwidgetUARE = {
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
                    ThreatColors = {
                      name = L["Threat Coloring"],
                      order = 50,
                      type = "group",
                      get = GetColorAlpha,
                      set = SetColorAlpha,
                      inline = true,
                      args = {
                        ThreatGlow = {
                          type = "toggle",
                          order = 1,
                          name = L["Show Threat Glow"],
                          get = GetValue,
                          set = SetThemeValue,
                          arg = { "settings", "threatborder", "show" },
                        },
                        OnlyAttackedUnits = {
                          type = "toggle",
                          order = 2,
                          name = L["Only on Attacked Units"],
                          desc = L["Show threat glow only on units in combat with the player."],
                          get = GetValue,
                          set = SetValue,
                          arg = { "ShowThreatGlowOnAttackedUnitsOnly" },
                        },
                        OffTankToggle = {
                          type = "toggle",
                          order = 3,
                          name = L["Show Off-Tank"],
                          desc = L["Show threat glow in different color for mobs on off-tanks (only if in tank spec)."],
                          get = GetValue,
                          set = SetValue,
                          arg = { "ShowThreatGlowOffTank" },
                        },
                        Header = { name = "Colors", type = "header", order = 10, },
                        Low = {
                          name = L["|cff00ff00Low Threat|r"],
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
                        OffTank = {
                          name = L["|cff0faac8Off-Tank|r"],
                          type = "color",
                          order = 50,
                          arg = { "settings", "normal", "threatcolor", "OFFTANK" },
                          hasAlpha = true,
                        },

                      },
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
                Enable = GetEnableEntry(L["Enable Headline View (Text-Only)"], L["This will enable headline view (text-only) for nameplates."], "HeadlineView"),
                ShowByUnitType = {
                  name = L["Show By Unit Type"],
                  order = 10,
                  type = "group",
                  inline = true,
                  disabled = function() return not TidyPlatesThreat.db.profile.HeadlineView.ON  end,
                  args = CreateHeadlineViewShowEntry(),
                },
                ShowByStatus = {
                  name = L["Show By Status"],
                  order = 15,
                  type = "group",
                  inline = true,
                  disabled = function() return not TidyPlatesThreat.db.profile.HeadlineView.ON  end,
                  args = {
                    ModeOnTarget = {
                    name = L["Force Healthbars on Target"],
                    order = 1,
                    type = "toggle",
                    width = "double",
                    arg = { "HeadlineView", "ForceHealthbarOnTarget" }
                    },
                    ModeOoC = {
                      name = L["Force Headline View while Out-of-Combat"],
                      order = 2,
                      type = "toggle",
                      width = "double",
                      arg = { "HeadlineView", "ForceOutOfCombat" }
                    }
                  }
                },
                Appearance = {
                  name = L["Appearance"],
                  type = "group",
                  inline = true,
                  order = 20,
                  args = {
                    ColorSettings = {
                      name = L["Colors"],
                      order = 10,
                      type = "group",
                      inline = true,
                      disabled = function() return not TidyPlatesThreat.db.profile.HeadlineView.ON end,
                      args = {
                        FriendlyColor = {
                          name = L["Friendly Headline Color"],
                          order = 10,
                          type = "select",
                          values = t.FRIENDLY_TEXT_COLOR,
                          arg = { "HeadlineView", "FriendlyTextColorMode" }
                        },
                        FriendlyColorCustom = GetColorAlphaEntry(15, { "HeadlineView", "FriendlyTextColor" }),
                        EnemyColor = {
                          name = L["Enemy Headline Color"],
                          order = 20,
                          type = "select",
                          values = t.ENEMY_TEXT_COLOR,
                          arg = { "HeadlineView", "EnemyTextColorMode" }
                        },
                        EnemyColorCustom = GetColorAlphaEntry(25, { "HeadlineView", "EnemyTextColor" }),
                        Spacer1 = GetSpacerEntry(30),
                        EnableRaidMarks = {
                          name = L["Color by Raid Marks"],
                          order = 70,
                          type = "toggle",
                          width = "full",
                          desc = L["Additionally color the name text based on the raid mark if the nameplate is marked."],
                          descStyle = "inline",
                          set = SetValue,
                          arg = { "HeadlineView", "UseRaidMarkColoring" },
                        },
                      },
                    },
                    SubtextSettings = {
                      name = L["Subtext"],
                      order = 20,
                      type = "group",
                      inline = true,
                      disabled = function()return not TidyPlatesThreat.db.profile.HeadlineView.ON end,
                      args = {
                        FriendlySubtext = {
                          name = L["FriendlySubtext"],
                          order = 10,
                          type = "select",
                          values = t.FRIENDLY_SUBTEXT,
                          arg = {"HeadlineView", "FriendlySubtext"}
                        },
                        Spacer1 = { name = "", order = 15, type = "description", width = "half", },
                        EnemySubtext = {
                          name = L["EnemySubtext"],
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
                              name = L["Same as Headline"],
                              order = 10,
                              type = "toggle",
                              arg = { "HeadlineView", "SubtextColorUseHeadline" },
                              set = function(info, val)
                                TidyPlatesThreat.db.profile.HeadlineView.SubtextColorUseSpecific = false
                                SetValue(info, true)
                              end,
                            },
                            SubtextColorSpecific = {
                              name = L["Subtext-specific"],
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
                                TidyPlates:ForceUpdate()
                              end,
                              get = function(info) return not (TidyPlatesThreat.db.profile.HeadlineView.SubtextColorUseHeadline or TidyPlatesThreat.db.profile.HeadlineView.SubtextColorUseSpecific) end,
                            },
                            SubtextColorCustomColor = GetColorAlphaEntry(35, { "HeadlineView", "SubtextColor" },
                              function() return (TidyPlatesThreat.db.profile.HeadlineView.SubtextColorUseHeadline or TidyPlatesThreat.db.profile.HeadlineView.SubtextColorUseSpecific) end ),
                          },
                        },
                      },
                    },
                    TextureSettings = {
                      name = L["Highlight Texture"],
                      order = 30,
                      type = "group",
                      inline = true,
                      disabled = function()return not TidyPlatesThreat.db.profile.HeadlineView.ON end,
                      args = {
                        TargetHighlight = {
                          name = L["Show Target"],
                          order = 10,
                          type = "toggle",
                          arg = { "HeadlineView", "ShowTargetHighlight" },
                          set = SetThemeValue,
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
                    Alpha = {
                      name = L["Alpha & Scaling"],
                      order = 40,
                      type = "group",
                      inline = true,
                      disabled = function() return not TidyPlatesThreat.db.profile.HeadlineView.ON  end,
                      args = {
                        Alpha = {
                          name = L["Apply alpha settings of healthbar view also to headline view."],
                          type = "toggle",
                          order = 1,
                          width = "full",
                          arg = { "HeadlineView", "useAlpha" },
                        },
                        Enable = {
                          name = L["Enable Blizzard 'On-Target' Fading"],
                          type = "toggle",
                          desc = L["Enabling this will allow you to set the alpha adjustment for non-target names in headline view."],
                          descStyle = "inline",
                          order = 2,
                          width = "double",
                          arg = { "HeadlineView", "blizzFading" },
                          disabled = function() return db.HeadlineView.useAlpha end
                        },
                        blizzFade = {
                          name = L["Non-Target Alpha"],
                          type = "range",
                          order = 3,
                          min = -1,
                          max = 0,
                          step = 0.01,
                          isPercent = true,
                          arg = { "HeadlineView", "blizzFadingAlpha" },
                          disabled = function() return db.HeadlineView.useAlpha end
                        },
                        Spacer = GetSpacerEntry(5),
                        Scaling = {
                          name = L["Apply scaling settings of healthbar view also to headline view."],
                          type = "toggle",
                          order = 10,
                          width = "full",
                          arg = { "HeadlineView", "useScaling" },
                        },
                      },
                    },
                    FontSize = {
                      name = L["Text Bounds and Sizing"],
                      order = 50,
                      type = "group",
                      inline = true,
                      disabled = function() return not TidyPlatesThreat.db.profile.HeadlineView.ON  end,
                      args = {
                        FontSize = { name = L["Font Size"], type = "range", width = "full", order = 1, set = SetThemeValue, arg = { "HeadlineView", "name", "size" }, max = 36, min = 6, step = 1, isPercent = false, },
                        TextBounds = {
                          name = L["Text Boundaries"],
                          type = "group",
                          order = 2,
                          args = {
                            Description = {
                              type = "description",
                              order = 1,
                              name = L["These settings will define the space that text can be placed on the nameplate.\nHaving too large a font and not enough height will cause the text to be not visible."],
                              width = "full",
                            },
                            Width = { type = "range", width = "full", order = 2, name = L["Text Width"], set = SetThemeValue, arg = { "HeadlineView", "name", "width" }, max = 250, min = 20, step = 1, isPercent = false, },
                            Height = { type = "range", width = "full", order = 3, name = L["Text Height"], set = SetThemeValue, arg = { "HeadlineView", "name", "height" }, max = 40, min = 8, step = 1, isPercent = false, },
                          },
                        },
                      },
                    },
                  },
                },
                Placement = {
                  name = L["Placement"],
                  order = 60,
                  type = "group",
                  inline = true,
                  disabled = function() return not TidyPlatesThreat.db.profile.HeadlineView.ON  end,
                  args = {
                    X = { name = L["X"], type = "range", order = 1, set = SetThemeValue, arg = { "HeadlineView", "name", "x" }, max = 120, min = -120, step = 1, isPercent = false, },
                    Y = { name = L["Y"], type = "range", order = 2, set = SetThemeValue, arg = { "HeadlineView", "name", "y" }, max = 120, min = -120, step = 1, isPercent = false, },
                    AlignH = { name = L["Horizontal Align"], type = "select", order = 4, values = t.AlignH, set = SetThemeValue, arg = { "HeadlineView", "name", "align" }, },
                    AlignV = { name = L["Vertical Align"], type = "select", order = 5, values = t.AlignV, set = SetThemeValue, arg = { "HeadlineView", "name", "vertical" }, },
                  },
                },
              },
            },
            CastBarSettings = {
              name = L["Castbar"],
              type = "group",
              order = 30,
              args = {
                Toggles = {
                  name = L["Enable"],
                  type = "group",
                  inline = true,
                  order = 1,
                  args = {
--                    Header = {
--                      name = L["Enables the showing of the castbar on nameplates."],
--                      order = 1,
--                      type = "description",
--                      width = "full",
--                    },
                    Enable = {
                      name = L["Show Castbar"],
                      order = 2,
                      type = "toggle",
                      desc = L["Enables the showing of the castbar on nameplates."],
                      --descStyle = "inline",
                      width = "double",
                      get = GetCvar,
											set = function(info, val)
                        SetCvar(info, val)
                        if val then
                          TidyPlates:EnableCastBars()
                        else
                          TidyPlates:DisableCastBars()
                        end
                      end,
                      arg = "ShowVKeyCastbar",
                    },
                    EnableHV = {
                      name = L["Show Castbar in Headline View"],
                      order = 3,
                      type = "toggle",
                      width = "double",
                      set = SetThemeValue,
                      arg = {"settings", "castbar", "ShowInHeadlineView" },
                      disabled = function() return GetCVar("ShowVKeyCastbar") == "0" end,
                    }
                  },
                },
                Textures = {
                  name = L["Textures"],
                  type = "group",
                  inline = true,
                  order = 1,
                  disabled = function() if GetCVar("ShowVKeyCastbar") == "1" then return false else return true end end,
                  args = {
                    CastBarTexture = {
                      name = L["Castbar"],
                      type = "select",
                      order = 1,
                      dialogControl = "LSM30_Statusbar",
                      values = AceGUIWidgetLSMlists.statusbar,
                      set = SetThemeValue,
                      arg = { "settings", "castbar", "texture" },
                    },
                    Spacer1 = GetSpacerEntry(5),
                    CastBarBorderToggle = {
                      type = "toggle",
                      order = 10,
                      name = L["Show Border"],
                      desc = L["Shows a border around the castbar of nameplates (requires /reload)."],
                      set = SetThemeValue,
                      arg = { "settings", "castborder", "show" },
                    },
                    CastBarBorder = {
                      type = "select",
                      order = 20,
                      name = L["Border Texture"],
                      set = SetThemeValue,
                      disabled = function() if db.settings.castborder.show then return false else return true end end,
                      values = { TP_CastBarOverlay = "Default", TP_CastBarOverlayThin = "Thin" },
                      arg = { "settings", "castborder", "texture" },
                    },
                    CastBarOverlay = {
                      name = L["Show Overlay for Uninterruptable Casts"],
                      order = 30,
                      type = "toggle",
                      width = "double",
                      set = SetThemeValue,
                      arg = { "settings", "castnostop", "ShowOverlay" },
                      disabled = function() return not db.settings.castborder.show end
                    },
                  },
                },
                Placement = {
                  name = L["Placement"],
                  type = "group",
                  inline = true,
                  order = 20,
                  disabled = function() if GetCVar("ShowVKeyCastbar") == "1" then return false else return true end end,
                  args = {
                    PlacementX = {
                      name = L["Healthbar X"],
                      order = 1,
                      type = "range",
                      min = -60,
                      max = 60,
                      step = 1,
                      set = function(info, val)
                        local b1 = {}; b1.arg = { "settings", "castborder", "x" };
                        local b2 = {}; b2.arg = { "settings", "castnostop", "x" };
                        SetThemeValue(b1, val)
                        SetThemeValue(b2, val)
                        SetThemeValue(info, val)
                      end,
                      arg = { "settings", "castbar", "x" },
                    },
                    PlacementY = {
                      name = L["Healthbar Y"],
                      order = 2,
                      type = "range",
                      min = -60,
                      max = 60,
                      step = 1,
                      set = function(info, val)
                        local b1 = {}; b1.arg = { "settings", "castborder", "y" };
                        local b2 = {}; b2.arg = { "settings", "castnostop", "y" };
                        SetThemeValue(b1, val)
                        SetThemeValue(b2, val)
                        SetThemeValue(info, val)
                      end,
                      arg = { "settings", "castbar", "y" },
                    },
                    HeadlineViewX = {
                      name = L["Headline View X"],
                      type = "range",
                      order = 3,
                      min = -60,
                      max = 60,
                      step = 1,
                      arg = { "settings", "castbar", "x_hv" },
                      set = SetThemeValue,
                      disabled = function() return not db.settings.castbar.ShowInHeadlineView or (GetCVar("ShowVKeyCastbar") == "0") end
                    },
                    HeadlineViewY = {
                      name = L["Headline View Y"],
                      order = 4,
                      type = "range",
                      min = -60,
                      max = 60,
                      step = 1,
                      arg = { "settings", "castbar", "y_hv" },
                      set = SetThemeValue,
                      disabled = function() return not db.settings.castbar.ShowInHeadlineView or (GetCVar("ShowVKeyCastbar") == "0") end
                    }
                  },
                },
                Coloring = {
                  name = L["Coloring"],
                  type = "group",
                  inline = true,
                  order = 30,
                  args = {
                    Enable = {
                      name = L["Enable Coloring"],
                      type = "toggle",
                      order = 1,
                      disabled = function() if GetCVar("ShowVKeyCastbar") == "1" then return false else return true end end,
                      arg = { "castbarColor", "toggle" },
                    },
                    Interruptable = {
                      name = L["Interruptable Casts"],
                      type = "color",
                      order = 2,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
                      disabled = function() if not db.castbarColor.toggle or GetCVar("ShowVKeyCastbar") ~= "1" then return true else return false end end,
                      arg = { "castbarColor" },
                    },
                    Header1 = {
                      type = "header",
                      order = 3,
                      name = "",
                    },
                    Enable2 = {
                      name = L["Shielded Coloring"],
                      type = "toggle",
                      order = 4,
                      disabled = function() if not db.castbarColor.toggle or GetCVar("ShowVKeyCastbar") ~= "1" then return true else return false end end,
                      arg = { "castbarColorShield", "toggle" },
                    },
                    Shielded = {
                      name = L["Uninterruptable Casts"],
                      type = "color",
                      order = 5,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
                      disabled = function() if GetCVar("ShowVKeyCastbar") ~= "1" or not db.castbarColor.toggle or not db.castbarColorShield.toggle then return true else return false end end,
                      arg = { "castbarColorShield" }
                    },
                  },
                },
              },
            },
            Alpha = {
              name = L["Alpha"],
              type = "group",
              order = 40,
              args = {
                BlizzFadeEnable = {
                  name = L["Blizzard Target Fading"],
                  type = "group",
                  order = 1,
                  inline = true,
                  args = {
                    Enable = {
                      name = L["Enable Blizzard 'On-Target' Fading"],
                      type = "toggle",
                      desc = L["Enabling this will allow you to set the alpha adjustment for non-target nameplates."],
                      descStyle = "inline",
                      order = 1,
                      width = "full",
                      arg = { "blizzFadeA", "toggle" },
                    },
                    blizzFade = {
                      name = L["Non-Target Alpha"],
                      type = "range",
                      order = 2,
                      width = "full",
                      disabled = function() return not db.blizzFadeA.toggle end,
                      min = -1,
                      max = 0,
                      step = 0.01,
                      isPercent = true,
                      arg = { "blizzFadeA", "amount" },
                    },
                  },
                },
                Target = {
                  name = "Target and No Target",
                  type = "group",
                  order = 10,
                  inline = true,
                  args = {
                    CustomAlphaTarget = {
                      name = "Custom Target Alpha",
                      type = "toggle",
                      desc = "If enabled your target's alpha will always be the setting below.",
                      descStyle = "inline",
                      order = 1,
                      width = "full",
                      arg = { "nameplate", "toggle", "TargetA" },
                    },
                    CustomAlphaTargetSet = {
                      name = "",
                      type = "range",
                      order = 2,
                      width = "full",
                      disabled = function() return not db.nameplate.toggle.TargetA end,
                      min = 0,
                      max = 1,
                      step = 0.01,
                      isPercent = true,
                      arg = { "nameplate", "alpha", "Target" },
                    },
                    CustomAlphaNoTarget = {
                      name = "Custom No-Target Alpha",
                      type = "toggle",
                      desc = "If enabled your nameplates alpha will always be the setting below when you have no target.",
                      descStyle = "inline",
                      order = 3,
                      width = "full",
                      arg = { "nameplate", "toggle", "NoTargetA" },
                    },
                    CustomAlphaNoTargetSet = {
                      name = "",
                      type = "range",
                      order = 4,
                      width = "full",
                      disabled = function() return not db.nameplate.toggle.NoTargetA end,
                      min = 0,
                      max = 1,
                      step = 0.01,
                      isPercent = true,
                      arg = { "nameplate", "alpha", "NoTarget" },
                    },
                  },
                },
                Options = {
                  name = L["Adjust Alpha for"],
                  type = "group",
                  order = 20,
                  inline = true,
                  args = {
                    CastingUnitEnable = {
                      name = L["Casting Unit"],
                      order = 10,
                      type = "toggle",
                      arg = { "nameplate", "toggle", "CastingUnitAlpha" },
                    },
                    CastingUnitScale = GetAlphaEntryBase(20, { "nameplate", "alpha", "CastingUnit" }),
                    CustomAlphaMarked = {
                      name = L["Raid Marked Unit"],
                      type = "toggle",
                      desc = "If enabled your marked units alpha will always be the setting below.",
                      order = 30,
                      arg = { "nameplate", "toggle", "MarkedA" },
                    },
                    CustomAlphaMarkedSet = GetAlphaEntryBase(40, { "nameplate", "alpha", "Marked" }),
                    MouseoverUnitEnable = {
                      name = L["Mouseover Unit"],
                      order = 50,
                      type = "toggle",
                      arg = { "nameplate", "toggle", "MouseoverUnitAlpha" },
                    },
                    MouseoverUnitScale = GetAlphaEntryBase(60, { "nameplate", "alpha", "MouseoverUnit" }),
                  },
                },
--                NameplateAlpha = {
--                  name = L["Base Alpha Settings by Unit"],
--                  type = "group",
--                  order = 30,
--                  inline = true,
--                  args = {
--                    Minus = GetUnitAlphaEntry(L["Minor"], 1, { "nameplate", "alpha", "Minus" }),
--                    Normal = GetUnitAlphaEntry(PLAYER_DIFFICULTY1, 2, { "nameplate", "alpha", "Normal" }),
--                    Elite = GetUnitAlphaEntry(L["Rare & Elite"], 4, { "nameplate", "alpha", "Elite" }),
--                    Boss = GetUnitAlphaEntry(BOSS, 5, { "nameplate", "alpha", "Boss" }),
--                    Header1 = { type = "header", order = 10, name = "", },
--                    Tapped =  GetUnitAlphaEntry(L["Tapped"], 11, { "nameplate", "alpha", "Tapped" }),
--                    Neutral = GetUnitAlphaEntry(COMBATLOG_FILTER_STRING_NEUTRAL_UNITS, 12, { "nameplate", "alpha", "Neutral" }),
--                  },
--                },
                NameplateAlpha = {
                  name = L["Base Alpha Settings by Unit"],
                  type = "group",
                  order = 40,
                  inline = true,
                  args = {
                    Help = {
                      name = L["Define base alpha settings for various unit types. Only one of these settings is applied to a unit at the same time, i.e., they are mutually exclusive."],
                      order = 0,
                      type = "description",
                      width = "full",
                    },
                    Header1 = { type = "header", order = 10, name = "Friendly & Neutral Units", },
                    FriendlyPlayers = GetAlphaEntryUnit(L["Friendly Players"], 11, { "nameplate", "alpha", "FriendlyPlayer" }),
                    FriendlyNPCs = GetAlphaEntryUnit(L["Friendly NPCs"], 12, { "nameplate", "alpha", "FriendlyNPC" }),
                    NeutralNPCs = GetAlphaEntryUnit(L["Neutral NPCs"], 13, { "nameplate", "alpha", "Neutral" }),
                    Header2 = { type = "header", order = 20, name = "Enemy Units", },
                    EnemyPlayers = GetAlphaEntryUnit(L["Enemy Players"], 21, { "nameplate", "alpha", "EnemyPlayer" }),
                    EnemyNPCs = GetAlphaEntryUnit(L["Enemy NPCs"], 22, { "nameplate", "alpha", "EnemyNPC" }),
                    EnemyElite = GetAlphaEntryUnit(L["Rare & Elite"], 23, { "nameplate", "alpha", "Elite" }),
                    EnemyBoss = GetAlphaEntryUnit(BOSS, 24, { "nameplate", "alpha", "Boss" }),
                    Header3 = { type = "header", order = 30, name = "Minions & By Status", },
                    Guardians = GetAlphaEntryUnit(L["Guardians"], 31, { "nameplate", "alpha", "Guardian" }),
                    Pets = GetAlphaEntryUnit(L["Pets"], 32, { "nameplate", "alpha", "Pet" }),
                    Minus = GetAlphaEntryUnit(L["Minor"], 33, { "nameplate", "alpha", "Minus" }),
                    Tapped =  GetAlphaEntryUnit(L["Tapped Units"], 41, { "nameplate", "alpha", "Tapped" }),
                  },
                },

              },
            },
            Scale = {
              name = L["Scale"],
              type = "group",
              order = 50,
              args = {
                Target = {
                  name = "Target and No Target",
                  type = "group",
                  order = 10,
                  inline = true,
                  args = {
                    CustomScaleTarget = {
                      name = "Custom Target Scale",
                      type = "toggle",
                      desc = "If enabled your target's scale will always be the setting below.",
                      descStyle = "inline",
                      order = 1,
                      width = "full",
                      arg = { "nameplate", "toggle", "TargetS" },
                    },
                    CustomScaleTargetSet = {
                      name = "",
                      type = "range",
                      order = 2,
                      width = "full",
                      disabled = function() return not db.nameplate.toggle.TargetS end,
                      step = 0.05,
                      softMin = 0.6,
                      softMax = 1.3,
                      isPercent = true,
                      arg = { "nameplate", "scale", "Target" },
                    },
                    CustomScaleNoTarget = {
                      name = "Custom No-Target Scale",
                      type = "toggle",
                      desc = "If enabled your nameplates scale will always be the setting below when you have no target.",
                      descStyle = "inline",
                      order = 3,
                      width = "full",
                      arg = { "nameplate", "toggle", "NoTargetS" },
                    },
                    CustomScaleNoTargetSet = {
                      name = "",
                      type = "range",
                      order = 4,
                      width = "full",
                      disabled = function() return not db.nameplate.toggle.NoTargetS end,
                      step = 0.05,
                      softMin = 0.6,
                      softMax = 1.3,
                      isPercent = true,
                      arg = { "nameplate", "scale", "NoTarget" },
                    },
                  },
                },
                Options = {
                  name = L["Adjust Scale for"],
                  type = "group",
                  order = 20,
                  inline = true,
                  args = {
                    CastingUnitsEnable = {
                      name = L["Casting Unit"],
                      order = 10,
                      type = "toggle",
                      arg = { "nameplate", "toggle", "CastingUnitScale" },
                    },
                    CastingUnitsScale = GetScaleEntryBase200(20, { "nameplate", "scale", "CastingUnit" }),
                    CustomScaleMarked = {
                      name = L["Raid Marked Unit"],
                      type = "toggle",
                      desc = "If enabled your marked units scale will always be the setting below.",
--                      descStyle = "inline",
                      order = 30,
                      arg = { "nameplate", "toggle", "MarkedS" },
                    },
                    CustomScaleMarkedSet = GetScaleEntryBase200(40, { "nameplate", "scale", "Marked" }),
                    MouseoverEnable = {
                      name = L["Mouseover Unit"],
                      order = 50,
                      type = "toggle",
                      arg = { "nameplate", "toggle", "MouseoverUnitScale" },
                    },
                    MouseoverScale = GetScaleEntryBase200(60, { "nameplate", "scale", "MouseoverUnit" }),
                  },
                },
--                NameplateScale = {
--                  name = L["Base Scale Settings by Unit"],
--                  type = "group",
--                  order = 40,
--                  inline = true,
--                  args = {
--                    Minus = GetUnitScaleEntry(L["Minor"], 1, { "nameplate", "scale", "Minus" }),
--                    Normal = GetUnitScaleEntry(PLAYER_DIFFICULTY1, 2, { "nameplate", "scale", "Normal" }),
--                    Elite = GetUnitScaleEntry(L["Rare & Elite"], 4, { "nameplate", "scale", "Elite" }),
--                    Boss = GetUnitScaleEntry(BOSS, 5, { "nameplate", "scale", "Boss" }),
--                    Header1 = { type = "header", order = 10, name = "", },
--                    Tapped =  GetUnitScaleEntry(L["Tapped"], 11, { "nameplate", "scale", "Tapped" }),
--                    Neutral = GetUnitScaleEntry(COMBATLOG_FILTER_STRING_NEUTRAL_UNITS, 12, { "nameplate", "scale", "Neutral" }),
--                  },
--                },
                NameplateScale = {
                  name = L["Base Scale Settings by Unit"],
                  type = "group",
                  order = 40,
                  inline = true,
                  args = {
                    Help = {
                      name = L["Define base scale settings for various unit types. Only one of these settings is applied to a unit at the same time, i.e., they are mutually exclusive."],
                      order = 0,
                      type = "description",
                      width = "full",
                    },
                    Header1 = { type = "header", order = 10, name = "Friendly & Neutral Units", },
                    FriendlyPlayers = GetUnitScaleEntry(L["Friendly Players"], 11, { "nameplate", "scale", "FriendlyPlayer" }),
                    FriendlyNPCs = GetUnitScaleEntry(L["Friendly NPCs"], 12, { "nameplate", "scale", "FriendlyNPC" }),
                    NeutralNPCs = GetUnitScaleEntry(L["Neutral NPCs"], 13, { "nameplate", "scale", "Neutral" }),
                    Header2 = { type = "header", order = 20, name = "Enemy Units", },
                    EnemyPlayers = GetUnitScaleEntry(L["Enemy Players"], 21, { "nameplate", "scale", "EnemyPlayer" }),
                    EnemyNPCs = GetUnitScaleEntry(L["Enemy NPCs"], 22, { "nameplate", "scale", "EnemyNPC" }),
                    EnemyElite = GetUnitScaleEntry(L["Rare & Elite"], 23, { "nameplate", "scale", "Elite" }),
                    EnemyBoss = GetUnitScaleEntry(BOSS, 24, { "nameplate", "scale", "Boss" }),
                    Header3 = { type = "header", order = 30, name = "Minions & By Status", },
                    Guardians = GetUnitScaleEntry(L["Guardians"], 31, { "nameplate", "scale", "Guardian" }),
                    Pets = GetUnitScaleEntry(L["Pets"], 32, { "nameplate", "scale", "Pet" }),
                    Minus = GetUnitScaleEntry(L["Minor"], 33, { "nameplate", "scale", "Minus" }),
                    Tapped =  GetUnitScaleEntry(L["Tapped Units"], 41, { "nameplate", "scale", "Tapped" }),
                  },
                },
              },
            },
            Nametext = {
                name = L["Name Text"],
                type = "group",
                order = 60,
                args = {
                  Enable = {
                    name = L["Enable"],
                    type = "group",
                    order = 1,
                    inline = true,
                    args = {
                      Enable = {
                        name = L["Enable Name Text"],
                        type = "toggle",
                        desc = L["Enables the showing of text on nameplates."],
                        descStyle = "inline",
                        width = "full",
                        order = 1,
                        set = SetThemeValue,
                        arg = { "settings", "name", "show" },
                      },
                    },
                  },
                  Options = {
                    name = L["Options"],
                    type = "group",
                    order = 2,
                    inline = true,
                    disabled = function() return not db.settings.name.show end,
                    args = {
                      FontLooks = {
                        name = L["Font"],
                        type = "group",
                        inline = true,
                        order = 1,
                        args = {
                          Font = {
                            name = L["Font"],
                            type = "select",
                            order = 1,
                            dialogControl = "LSM30_Font",
                            values = AceGUIWidgetLSMlists.font,
                            set = SetThemeValue,
                            arg = { "settings", "name", "typeface" },
                          },
                          FontStyle = {
                            type = "select",
                            order = 2,
                            name = L["Font Style"],
                            desc = L["Set the outlining style of the text."],
                            values = t.FontStyle,
                            set = SetThemeValue,
                            arg = { "settings", "name", "flags" },
                          },
                          Shadow = {
                            name = L["Enable Shadow"],
                            order = 4,
                            type = "toggle",
                            width = "full",
                            set = SetThemeValue,
                            arg = { "settings", "name", "shadow" },
                          },
                          Header1 = {
                            type = "header",
                            order = 3,
                            name = "",
                          },
                          Color = {
                            type = "color",
                            order = 3,
                            name = L["Color"],
                            width = "full",
                            get = GetColor,
                            set = SetColor,
                            arg = { "settings", "name", "color" },
                            hasAlpha = false,
                          },
                        },
                      },
                      FontSize = {
                        name = L["Text Bounds and Sizing"],
                        type = "group",
                        order = 2,
                        inline = true,
                        args = {
                          FontSize = {
                            name = L["Font Size"],
                            type = "range",
                            width = "full",
                            order = 1,
                            set = SetThemeValue,
                            arg = { "settings", "name", "size" },
                            max = 36,
                            min = 6,
                            step = 1,
                            isPercent = false,
                          },
                          TextBounds = {
                            name = L["Text Boundaries"],
                            type = "group",
                            order = 2,
                            args = {
                              Description = {
                                type = "description",
                                order = 1,
                                name = L["These settings will define the space that text can be placed on the nameplate.\nHaving too large a font and not enough height will cause the text to be not visible."],
                                width = "full",
                              },
                              Width = {
                                type = "range",
                                width = "full",
                                order = 2,
                                name = L["Text Width"],
                                set = SetThemeValue,
                                arg = { "settings", "name", "width" },
                                max = 250,
                                min = 20,
                                step = 1,
                                isPercent = false,
                              },
                              Height = {
                                type = "range",
                                width = "full",
                                order = 3,
                                name = L["Text Height"],
                                set = SetThemeValue,
                                arg = { "settings", "name", "height" },
                                max = 40,
                                min = 8,
                                step = 1,
                                isPercent = false,
                              },
                            },
                          },
                        },
                      },
                      Placement = {
                        name = L["Placement"],
                        order = 3,
                        type = "group",
                        inline = true,
                        args = {
                          X = {
                            name = L["X"],
                            type = "range",
                            width = "full",
                            order = 1,
                            set = SetThemeValue,
                            arg = { "settings", "name", "x" },
                            max = 120,
                            min = -120,
                            step = 1,
                            isPercent = false,
                          },
                          Y = {
                            name = L["Y"],
                            type = "range",
                            width = "full",
                            order = 2,
                            set = SetThemeValue,
                            arg = { "settings", "name", "y" },
                            max = 120,
                            min = -120,
                            step = 1,
                            isPercent = false,
                          },
                          AlignH = {
                            name = L["Horizontal Align"],
                            type = "select",
                            width = "full",
                            order = 3,
                            values = t.AlignH,
                            set = SetThemeValue,
                            arg = { "settings", "name", "align" },
                          },
                          AlignV = {
                            name = L["Vertical Align"],
                            type = "select",
                            width = "full",
                            order = 4,
                            values = t.AlignV,
                            set = SetThemeValue,
                            arg = { "settings", "name", "vertical" },
                          },
                        },
                      },
                    },
                  },
                },
              },
            Healthtext = {
              name = L["Health Text"],
              type = "group",
              order = 70,
              args = {
                Enable = {
                  name = L["Enable"],
                  type = "group",
                  order = 1,
                  inline = true,
                  args = {
                    Enable = {
                      name = L["Enable Health Text"],
                      type = "toggle",
                      desc = L["Enables the showing of text on nameplates."],
                      descStyle = "inline",
                      width = "full",
                      order = 1,
                      set = SetThemeValue,
                      arg = { "settings", "customtext", "show" },
                    },
                  },
                },
                Options = {
                  name = L["Options"],
                  type = "group",
                  order = 2,
                  inline = true,
                  disabled = function() if db.settings.customtext.show then return false else return true end end,
                  args = {
                    DisplaySettings = {
                      name = L["Display Settings"],
                      type = "group",
                      order = 0,
                      inline = true,
                      args = {
                        Full = {
                          name = L["Text at Full HP"],
                          type = "toggle",
                          order = 0,
                          width = "full",
                          desc = L["Display health text on targets with full HP."],
                          descStyle = "inline",
                          arg = { "text", "full" }
                        },
                        EnablePercent = {
                          name = L["Percent Text"],
                          type = "toggle",
                          order = 1,
                          width = "full",
                          desc = L["Display health percentage text."],
                          descStyle = "inline",
                          arg = { "text", "percent" }
                        },
                        EnableAmount = {
                          name = L["Amount Text"],
                          type = "toggle",
                          order = 2,
                          width = "full",
                          desc = L["Display health amount text."],
                          descStyle = "inline",
                          arg = { "text", "amount" }
                        },
                        AmountSettings = {
                          name = L["Amount Text Formatting"],
                          type = "group",
                          order = 3,
                          inline = true,
                          disabled = function() if not db.text.amount or not db.settings.customtext.show then return true else return false end end,
                          args = {
                            Truncate = {
                              name = L["Truncate Text"],
                              type = "toggle",
                              order = 1,
                              width = "full",
                              desc = L["This will format text to a simpler format using M or K for millions and thousands. Disabling this will show exact HP amounts."],
                              descStyle = "inline",
                              arg = { "text", "truncate" }
                            },
                            MaxHP = {
                              name = L["Max HP Text"],
                              type = "toggle",
                              order = 2,
                              width = "full",
                              desc = L["This will format text to show both the maximum hp and current hp."],
                              descStyle = "inline",
                              arg = { "text", "max" }
                            },
                            Deficit = {
                              name = L["Deficit Text"],
                              type = "toggle",
                              order = 3,
                              width = "full",
                              desc = L["This will format text to show hp as a value the target is missing."],
                              descStyle = "inline",
                              arg = { "text", "deficit" }
                            },
                          },
                        },
                      },
                    },
                    FontLooks = {
                      name = L["Font"],
                      type = "group",
                      inline = true,
                      order = 1,
                      args = {
                        Font = {
                          name = L["Font"],
                          type = "select",
                          order = 1,
                          dialogControl = "LSM30_Font",
                          values = AceGUIWidgetLSMlists.font,
                          set = SetThemeValue,
                          arg = { "settings", "customtext", "typeface" },
                        },
                        FontStyle = {
                          type = "select",
                          order = 2,
                          name = L["Font Style"],
                          desc = L["Set the outlining style of the text."],
                          values = t.FontStyle,
                          set = SetThemeValue,
                          arg = { "settings", "customtext", "flags" },
                        },
                        Shadow = {
                          name = L["Enable Shadow"],
                          order = 4,
                          type = "toggle",
                          width = "full",
                          set = SetThemeValue,
                          arg = { "settings", "customtext", "shadow" },
                        },
                      },
                    },
                    FontSize = {
                      name = L["Text Bounds and Sizing"],
                      type = "group",
                      order = 2,
                      inline = true,
                      args = {
                        FontSize = {
                          name = L["Font Size"],
                          type = "range",
                          width = "full",
                          order = 1,
                          set = SetThemeValue,
                          arg = { "settings", "customtext", "size" },
                          max = 36,
                          min = 6,
                          step = 1,
                          isPercent = false,
                        },
                        TextBounds = {
                          name = L["Text Boundaries"],
                          type = "group",
                          order = 2,
                          args = {
                            Description = {
                              type = "description",
                              order = 1,
                              name = L["These settings will define the space that text can be placed on the nameplate.\nHaving too large a font and not enough height will cause the text to be not visible."],
                              width = "full",
                            },
                            Width = {
                              type = "range",
                              width = "full",
                              order = 2,
                              name = L["Text Width"],
                              set = SetThemeValue,
                              arg = { "settings", "customtext", "width" },
                              max = 250,
                              min = 20,
                              step = 1,
                              isPercent = false,
                            },
                            Height = {
                              type = "range",
                              width = "full",
                              order = 3,
                              name = L["Text Height"],
                              set = SetThemeValue,
                              arg = { "settings", "customtext", "height" },
                              max = 40,
                              min = 8,
                              step = 1,
                              isPercent = false,
                            },
                          },
                        },
                      },
                    },
                    Placement = {
                      name = L["Placement"],
                      order = 3,
                      type = "group",
                      inline = true,
                      args = {
                        X = {
                          name = L["X"],
                          type = "range",
                          width = "full",
                          order = 1,
                          set = SetThemeValue,
                          arg = { "settings", "customtext", "x" },
                          max = 120,
                          min = -120,
                          step = 1,
                          isPercent = false,
                        },
                        Y = {
                          name = L["Y"],
                          type = "range",
                          width = "full",
                          order = 2,
                          set = SetThemeValue,
                          arg = { "settings", "customtext", "y" },
                          max = 120,
                          min = -120,
                          step = 1,
                          isPercent = false,
                        },
                        AlignH = {
                          name = L["Horizontal Align"],
                          type = "select",
                          width = "full",
                          order = 3,
                          values = t.AlignH,
                          set = SetThemeValue,
                          arg = { "settings", "customtext", "align" },
                        },
                        AlignV = {
                          name = L["Vertical Align"],
                          type = "select",
                          width = "full",
                          order = 4,
                          values = t.AlignV,
                          set = SetThemeValue,
                          arg = { "settings", "customtext", "vertical" },
                        },
                      },
                    },
                  },
                },
              },
            },
            SpellText = {
              name = L["Spell Text"],
              type = "group",
              order = 80,
              args = {
                Enable = {
                  name = L["Enable"],
                  type = "group",
                  order = 1,
                  inline = true,
                  args = {
                    Enable = {
                      name = L["Enable Spell Text"],
                      type = "toggle",
                      desc = L["Enables the showing of text on nameplates."],
                      descStyle = "inline",
                      width = "full",
                      order = 1,
                      set = SetThemeValue,
                      arg = { "settings", "spelltext", "show" },
                    },
                  },
                },
                Options = {
                  name = L["Options"],
                  type = "group",
                  order = 2,
                  inline = true,
                  disabled = function() if db.settings.spelltext.show then return false else return true end end,
                  args = {
                    FontLooks = {
                      name = L["Font"],
                      type = "group",
                      inline = true,
                      order = 1,
                      args = {
                        Font = {
                          name = L["Font"],
                          type = "select",
                          order = 1,
                          dialogControl = "LSM30_Font",
                          values = AceGUIWidgetLSMlists.font,
                          set = SetThemeValue,
                          arg = { "settings", "spelltext", "typeface" },
                        },
                        FontStyle = {
                          type = "select",
                          order = 2,
                          name = L["Font Style"],
                          desc = L["Set the outlining style of the text."],
                          values = t.FontStyle,
                          set = SetThemeValue,
                          arg = { "settings", "spelltext", "flags" },
                        },
                        Shadow = {
                          name = L["Enable Shadow"],
                          order = 4,
                          type = "toggle",
                          width = "full",
                          set = SetThemeValue,
                          arg = { "settings", "spelltext", "shadow" },
                        },
                      },
                    },
                    FontSize = {
                      name = L["Text Bounds and Sizing"],
                      type = "group",
                      order = 2,
                      inline = true,
                      args = {
                        FontSize = {
                          name = L["Font Size"],
                          type = "range",
                          width = "full",
                          order = 1,
                          set = SetThemeValue,
                          arg = { "settings", "spelltext", "size" },
                          max = 36,
                          min = 6,
                          step = 1,
                          isPercent = false,
                        },
                        TextBounds = {
                          name = L["Text Boundaries"],
                          type = "group",
                          order = 2,
                          args = {
                            Description = {
                              type = "description",
                              order = 1,
                              name = L["These settings will define the space that text can be placed on the nameplate.\nHaving too large a font and not enough height will cause the text to be not visible."],
                              width = "full",
                            },
                            Width = {
                              type = "range",
                              width = "full",
                              order = 2,
                              name = L["Text Width"],
                              set = SetThemeValue,
                              arg = { "settings", "spelltext", "width" },
                              max = 250,
                              min = 20,
                              step = 1,
                              isPercent = false,
                            },
                            Height = {
                              type = "range",
                              width = "full",
                              order = 3,
                              name = L["Text Height"],
                              set = SetThemeValue,
                              arg = { "settings", "spelltext", "height" },
                              max = 40,
                              min = 8,
                              step = 1,
                              isPercent = false,
                            },
                          },
                        },
                      },
                    },
                    Placement = {
                      name = L["Placement"],
                      order = 3,
                      type = "group",
                      inline = true,
                      args = {
                        X = {
                          name = L["Healthbar X"],
                          order = 1,
                          type = "range",
                          set = SetThemeValue,
                          arg = { "settings", "spelltext", "x" },
                          max = 120,
                          min = -120,
                          step = 1,
                          isPercent = false,
                        },
                        Y = {
                          name = L["Healthbar Y"],
                          order = 2,
                          type = "range",
                          set = SetThemeValue,
                          arg = { "settings", "spelltext", "y" },
                          max = 120,
                          min = -120,
                          step = 1,
                          isPercent = false,
                        },
                        HeadlineViewX = {
                          name = L["Headline View X"],
                          order = 3,
                          type = "range",
                          min = -120,
                          max = 120,
                          step = 1,
                          arg = { "settings", "spelltext", "x_hv" },
                          set = SetThemeValue,
                          disabled = function() return not db.settings.castbar.ShowInHeadlineView end
                        },
                        HeadlineViewY = {
                          name = L["Headline View Y"],
                          order = 4,
                          type = "range",
                          min = -120,
                          max = 120,
                          step = 1,
                          arg = { "settings", "spelltext", "y_hv" },
                          set = SetThemeValue,
                          disabled = function() return not db.settings.castbar.ShowInHeadlineView end
                        },
                        Spacer = GetSpacerEntry(5),
                        AlignH = {
                          name = L["Horizontal Align"],
                          type = "select",
                          width = "double",
                          order = 6,
                          values = t.AlignH,
                          set = SetThemeValue,
                          arg = { "settings", "spelltext", "align" },
                        },
                        AlignV = {
                          name = L["Vertical Align"],
                          type = "select",
                          width = "double",
                          order = 7,
                          values = t.AlignV,
                          set = SetThemeValue,
                          arg = { "settings", "spelltext", "vertical" },
                        },
                      },
                    },
                  },
                },
              },
            },
            Leveltext = {
              name = L["Level Text"],
              type = "group",
              order = 90,
              args = {
                Enable = {
                  name = L["Enable"],
                  type = "group",
                  order = 1,
                  inline = true,
                  args = {
                    Enable = {
                      name = L["Enable Level Text"],
                      type = "toggle",
                      desc = L["Enables the showing of text on nameplates."],
                      descStyle = "inline",
                      width = "full",
                      order = 1,
                      set = SetThemeValue,
                      arg = { "settings", "level", "show" },
                    },
                  },
                },
                Options = {
                  name = L["Options"],
                  type = "group",
                  order = 2,
                  inline = true,
                  disabled = function() if db.settings.level.show then return false else return true end end,
                  args = {
                    FontLooks = {
                      name = L["Font"],
                      type = "group",
                      inline = true,
                      order = 1,
                      args = {
                        Font = {
                          name = L["Font"],
                          type = "select",
                          order = 1,
                          dialogControl = "LSM30_Font",
                          values = AceGUIWidgetLSMlists.font,
                          set = SetThemeValue,
                          arg = { "settings", "level", "typeface" },
                        },
                        FontStyle = {
                          type = "select",
                          order = 2,
                          name = L["Font Style"],
                          desc = L["Set the outlining style of the text."],
                          values = t.FontStyle,
                          set = SetThemeValue,
                          arg = { "settings", "level", "flags" },
                        },
                        Shadow = {
                          name = L["Enable Shadow"],
                          order = 4,
                          type = "toggle",
                          width = "full",
                          set = SetThemeValue,
                          arg = { "settings", "level", "shadow" },
                        },
                      },
                    },
                    FontSize = {
                      name = L["Text Bounds and Sizing"],
                      type = "group",
                      order = 2,
                      inline = true,
                      args = {
                        FontSize = {
                          name = L["Font Size"],
                          type = "range",
                          width = "full",
                          order = 1,
                          set = SetThemeValue,
                          arg = { "settings", "level", "size" },
                          max = 36,
                          min = 6,
                          step = 1,
                          isPercent = false,
                        },
                        TextBounds = {
                          name = L["Text Boundaries"],
                          type = "group",
                          order = 2,
                          args = {
                            Description = {
                              type = "description",
                              order = 1,
                              name = L["These settings will define the space that text can be placed on the nameplate.\nHaving too large a font and not enough height will cause the text to be not visible."],
                              width = "full",
                            },
                            Width = {
                              type = "range",
                              width = "full",
                              order = 2,
                              name = L["Text Width"],
                              set = SetThemeValue,
                              arg = { "settings", "level", "width" },
                              max = 250,
                              min = 20,
                              step = 1,
                              isPercent = false,
                            },
                            Height = {
                              type = "range",
                              width = "full",
                              order = 3,
                              name = L["Text Height"],
                              set = SetThemeValue,
                              arg = { "settings", "level", "height" },
                              max = 40,
                              min = 8,
                              step = 1,
                              isPercent = false,
                            },
                          },
                        },
                      },
                    },
                    Placement = {
                      name = L["Placement"],
                      order = 3,
                      type = "group",
                      inline = true,
                      args = {
                        X = {
                          name = L["X"],
                          type = "range",
                          order = 1,
                          width = "full",
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
                          width = "full",
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
                          width = "full",
                          order = 3,
                          values = t.AlignH,
                          set = SetThemeValue,
                          arg = { "settings", "level", "align" },
                        },
                        AlignV = {
                          name = L["Vertical Align"],
                          type = "select",
                          width = "full",
                          order = 4,
                          values = t.AlignV,
                          set = SetThemeValue,
                          arg = { "settings", "level", "vertical" },
                        },
                      },
                    },
                  },
                },
              },
            },
            EliteIcon = {
              name = L["Elite Icon"],
              type = "group",
              order = 100,
              set = SetThemeValue,
              args = {
                Enable = {
                  name = L["Enable"],
                  type = "group",
                  order = 1,
                  inline = true,
                  args = {
                    Enable = {
                      name = L["Enable Elite Icon"],
                      type = "toggle",
                      desc = L["Enables the showing of the elite icon for elite units on nameplates."],
                      descStyle = "inline",
                      width = "full",
                      order = 1,
                      set = SetThemeValue,
                      arg = { "settings", "eliteicon", "show" },
                    },
                  },
                },
                Texture = {
                  name = L["Texture"],
                  type = "group",
                  inline = true,
                  order = 20,
                  --                  disabled = function() if db.settings.eliteicon.show then return false else return true end end,
                  args = {
                    Preview = {
                      name = L["Preview"],
                      type = "execute",
                      order = 1,
                      image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\EliteArtWidget\\" .. db.settings.eliteicon.theme,
                    },
                    Style = {
                      type = "select",
                      order = 2,
                      name = L["Elite Icon Style"],
                      values = { default = "Default", skullandcross = "Skull and Crossbones" },
                      set = function(info, val)
                        SetThemeValue(info, val)
                        options.args.NameplateSettings.args.EliteIcon.args.Texture.args.Preview.image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\EliteArtWidget\\" .. val
                        t.Update()
                      end,
                      arg = { "settings", "eliteicon", "theme" },
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
              args = {
                Enable = {
                  name = L["Enable"],
                  type = "group",
                  order = 1,
                  inline = true,
                  args = {
                    Enable = {
                      name = L["Enable Skull Icon"],
                      type = "toggle",
                      desc = L["Enables the showing of the skull icon for rare units on nameplates."],
                      descStyle = "inline",
                      width = "full",
                      order = 1,
                      set = SetThemeValue,
                      arg = { "settings", "skullicon", "show" },
                    },
                  },
                },
                Layout = GetLayoutEntryTheme(20, "skullicon"),
              },
            },
            SpellIcon = {
              name = L["Spell Icon"],
              type = "group",
              order = 120,
              args = {
                Enable = {
                  name = L["Enable"],
                  type = "group",
                  order = 1,
                  inline = true,
                  args = {
                    Enable = {
                      name = L["Enable Spell Icon"],
                      type = "toggle",
                      desc = L["Enables the showing of the spell icon on nameplates."],
                      descStyle = "inline",
                      width = "full",
                      order = 1,
                      set = SetThemeValue,
                      arg = { "settings", "spellicon", "show" },
                    },
                  },
                },
                Layout = GetLayoutEntryTheme(20, "skullicon", true),
              },
            },
            RaidMarks = RaidMarksOptions(),
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
              set = function(info, val)
                SetValue(info, val)
                local inInstance, iType = IsInInstance()
                if iType == "party" or iType == "raid" or iType == "none" then
                  db.OldSetting = val
                end
              end,
              arg = { "threat", "ON" }
            },
            GeneralSettings = {
              name = L["General Settings"],
              type = "group",
              order = 0,
              disabled = function() return not db.threat.ON end,
              args = {
                AdditionalToggles = {
                  name = L["Additional Toggles"],
                  type = "group",
                  order = 1,
                  inline = true,
                  args = {
                    IgnoreNonCombat = {
                      type = "toggle",
                      name = L["Ignore Non-Combat Threat"],
                      order = 1,
                      width = "full",
                      desc = L["If checked, threat feedback from mobs you're currently not in combat with will be ignored."],
                      descStyle = "inline",
                      arg = { "threat", "nonCombat" },
                    },
                    OffTank = {
                      type = "toggle",
                      name = L["Highlight Mobs on Off-Tanks"],
                      order = 2,
                      width = "full",
                      desc = L["If checked, mobs attacking another tank can be shown with different color, scale, and opacity."],
                      descStyle = "inline",
                      arg = { "threat", "toggle", "OffTank" },
                    },
                    Mini = {
                      type = "toggle",
                      name = L["Show Minor Threat"],
                      order = 3,
                      width = "full",
                      desc = L["Disables threat feedback from minor mobs."],
                      descStyle = "inline",
                      arg = { "threat", "toggle", "Minus" },
                    },
                    Normal = {
                      type = "toggle",
                      name = L["Show Normal Threat"],
                      order = 4,
                      width = "full",
                      desc = L["Disables threat feedback from normal mobs."],
                      descStyle = "inline",
                      arg = { "threat", "toggle", "Normal" },
                    },
                    Elite = {
                      type = "toggle",
                      name = L["Show Elite and Rare Threat"],
                      order = 5,
                      width = "full",
                      desc = L["Disables threat feedback from elite and rare mobs."],
                      descStyle = "inline",
                      arg = { "threat", "toggle", "Elite" },
                    },
                    Boss = {
                      type = "toggle",
                      name = L["Show Boss Threat"],
                      order = 6,
                      width = "full",
                      desc = L["Disables threat feedback from boss level mobs."],
                      descStyle = "inline",
                      arg = { "threat", "toggle", "Boss" },
                    },
                    Tapped = {
                      type = "toggle",
                      name = L["Show Tapped Threat"],
                      order = 7,
                      width = "full",
                      desc = L["Disables threat feedback from tapped mobs regardless of boss or elite levels."],
                      descStyle = "inline",
                      arg = { "threat", "toggle", "Tapped" },
                    },
                    Neutral = {
                      type = "toggle",
                      name = L["Show Neutral Threat"],
                      order = 8,
                      width = "full",
                      desc = L["Disables threat feedback from neutral mobs regardless of boss or elite levels."],
                      descStyle = "inline",
                      arg = { "threat", "toggle", "Neutral" },
                    },
                  },
                },
              },
            },
            Alpha = {
              name = L["Alpha"],
              type = "group",
              desc = L["Set alpha settings for different threat reaction types."],
              disabled = function() return not db.threat.ON end,
              order = 1,
              args = {
                Enable = {
                  name = L["Enable Alpha Threat"],
                  type = "group",
                  inline = true,
                  order = 0,
                  args = {
                    Enable = {
                      type = "toggle",
                      name = L["Enable"],
                      desc = L["Enable nameplates to change alpha depending on the levels you set below."],
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
                    Low = {
                      name = L["|cffff0000Low Threat|r"],
                      type = "range",
                      order = 1,
                      arg = { "threat", "tank", "alpha", "LOW" },
                      min = 0.01,
                      max = 1,
                      step = 0.01,
                      isPercent = true,
                    },
                    Med = {
                      name = L["|cffffff00Medium Threat|r"],
                      type = "range",
                      order = 2,
                      arg = { "threat", "tank", "alpha", "MEDIUM" },
                      min = 0.01,
                      max = 1,
                      step = 0.01,
                      isPercent = true,
                    },
                    High = {
                      name = L["|cff00ff00High Threat|r"],
                      type = "range",
                      order = 3,
                      arg = { "threat", "tank", "alpha", "HIGH" },
                      min = 0.01,
                      max = 1,
                      step = 0.01,
                      isPercent = true,
                    },
                    OffTank = {
                      name = L["|cff0faac8Off-Tank|r"],
                      type = "range",
                      order = 4,
                      arg = { "threat", "tank", "alpha", "OFFTANK" },
                      min = 0.01,
                      max = 1,
                      step = 0.01,
                      isPercent = true,
                      disabled = function() return not db.threat.toggle.OffTank end
                    },
                  },
                },
                DPS = {
                  name = L["|cffff0000DPS/Healing|r"],
                  type = "group",
                  inline = true,
                  order = 2,
                  disabled = function() if db.threat.useAlpha then return false else return true end end,
                  args = {
                    Low = {
                      name = L["|cff00ff00Low Threat|r"],
                      type = "range",
                      order = 1,
                      arg = { "threat", "dps", "alpha", "LOW" },
                      min = 0.01,
                      max = 1,
                      step = 0.01,
                      isPercent = true,
                    },
                    Med = {
                      name = L["|cffffff00Medium Threat|r"],
                      type = "range",
                      order = 2,
                      arg = { "threat", "dps", "alpha", "MEDIUM" },
                      min = 0.01,
                      max = 1,
                      step = 0.01,
                      isPercent = true,
                    },
                    High = {
                      name = L["|cffff0000High Threat|r"],
                      type = "range",
                      order = 3,
                      arg = { "threat", "dps", "alpha", "HIGH" },
                      min = 0.01,
                      max = 1,
                      step = 0.01,
                      isPercent = true,
                    },
                  },
                },
                Marked = {
                  name = L["Marked Targets"],
                  type = "group",
                  inline = true,
                  order = 3,
                  disabled = function() if db.threat.useAlpha then return false else return true end end,
                  args = {
                    Toggle = {
                      name = L["Ignore Marked Targets"],
                      type = "toggle",
                      order = 2,
                      width = "full",
                      desc = L["This will allow you to disabled threat alpha changes on marked targets."],
                      descStyle = "inline",
                      arg = { "threat", "marked", "alpha" }
                    },
                    Alpha = {
                      name = L["Ignored Alpha"],
                      order = 3,
                      type = "range",
                      disabled = function() if not db.threat.marked.alpha or not db.threat.useAlpha then return true else return false end end,
                      step = 0.05,
                      min = 0,
                      max = 1,
                      isPercent = true,
                      arg = { "nameplate", "alpha", "Marked" },
                    },
                  },
                },
              },
            },
            Scale = {
              name = L["Scale"],
              type = "group",
              desc = L["Set scale settings for different threat reaction types."],
              disabled = function() return not db.threat.ON end,
              order = 1,
              args = {
                Enable = {
                  name = L["Enable Scale Threat"],
                  type = "group",
                  inline = true,
                  order = 0,
                  args = {
                    Enable = {
                      type = "toggle",
                      name = L["Enable"],
                      desc = L["Enable nameplates to change scale depending on the levels you set below."],
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
                  disabled = function() if db.threat.useScale then return false else return true end end,
                  args = {
                    Low = {
                      name = L["|cffff0000Low Threat|r"],
                      type = "range",
                      order = 1,
                      arg = { "threat", "tank", "scale", "LOW" },
                      min = 0.01,
                      max = 2,
                      step = 0.01,
                      isPercent = true,
                    },
                    Med = {
                      name = L["|cffffff00Medium Threat|r"],
                      type = "range",
                      order = 2,
                      arg = { "threat", "tank", "scale", "MEDIUM" },
                      min = 0.01,
                      max = 2,
                      step = 0.01,
                      isPercent = true,
                    },
                    High = {
                      name = L["|cff00ff00High Threat|r"],
                      type = "range",
                      order = 3,
                      arg = { "threat", "tank", "scale", "HIGH" },
                      min = 0.01,
                      max = 2,
                      step = 0.01,
                      isPercent = true,
                    },
                    OffTank = {
                      name = L["|cff0faac8Off-Tank|r"],
                      type = "range",
                      order = 4,
                      arg = { "threat", "tank", "scale", "OFFTANK" },
                      min = 0.01,
                      max = 2,
                      step = 0.01,
                      isPercent = true,
                      disabled = function() return not db.threat.toggle.OffTank end
                    },
                  },
                },
                DPS = {
                  name = L["|cffff0000DPS/Healing|r"],
                  type = "group",
                  inline = true,
                  order = 2,
                  disabled = function() if db.threat.useScale then return false else return true end end,
                  args = {
                    Low = {
                      name = L["|cff00ff00Low Threat|r"],
                      type = "range",
                      order = 1,
                      arg = { "threat", "dps", "scale", "LOW" },
                      min = 0.01,
                      max = 2,
                      step = 0.01,
                      isPercent = true,
                    },
                    Med = {
                      name = L["|cffffff00Medium Threat|r"],
                      type = "range",
                      order = 2,
                      arg = { "threat", "dps", "scale", "MEDIUM" },
                      min = 0.01,
                      max = 2,
                      step = 0.01,
                      isPercent = true,
                    },
                    High = {
                      name = L["|cffff0000High Threat|r"],
                      type = "range",
                      order = 3,
                      arg = { "threat", "dps", "scale", "HIGH" },
                      min = 0.01,
                      max = 2,
                      step = 0.01,
                      isPercent = true,
                    },
                  },
                },
                Marked = {
                  name = L["Marked Targets"],
                  type = "group",
                  inline = true,
                  order = 3,
                  disabled = function() return not db.threat.useScale end,
                  args = {
                    Toggle = {
                      name = L["Ignore Marked Targets"],
                      type = "toggle",
                      order = 2,
                      width = "full",
                      desc = L["This will allow you to disabled threat scale changes on marked targets."],
                      descStyle = "inline",
                      arg = { "threat", "marked", "scale" }
                    },
                    Scale = {
                      name = L["Ignored Scaling"],
                      type = "range",
                      order = 3,
                      disabled = function() if not db.threat.marked.scale or not db.threat.useScale then return true else return false end end,
                      step = 0.05,
                      min = 0.3,
                      max = 2,
                      isPercent = true,
                      arg = { "nameplate", "scale", "Marked" },
                    },
                  },
                },
                TypeSpecific = {
                  name = L["Additional Adjustments"],
                  type = "group",
                  inline = true,
                  order = 4,
                  disabled = function() if db.threat.useScale then return false else return true end end,
                  args = {
                    Toggle = {
                      name = L["Enable Adjustments"],
                      order = 1,
                      type = "toggle",
                      width = "full",
                      desc = L["This will allow you to add additional scaling changes to specific mob types."],
                      descStyle = "inline",
                      arg = { "threat", "useType" }
                    },
                    AdditionalSliders = {
                      name = L["Additional Adjustments"],
                      type = "group",
                      order = 3,
                      inline = true,
                      disabled = function() if not db.threat.useType or not db.threat.useScale then return true else return false end end,
                      args = {
                        Mini = {
                          name = L["Minor"],
                          order = 0.5,
                          type = "range",
                          width = "double",
                          arg = { "threat", "scaleType", "Minus" },
                          min = -0.5,
                          max = 0.5,
                          step = 0.01,
                          isPercent = true,
                        },
                        NormalNeutral = {
                          name = PLAYER_DIFFICULTY1 .. " & " .. COMBATLOG_FILTER_STRING_NEUTRAL_UNITS,
                          order = 1,
                          type = "range",
                          width = "double",
                          arg = { "threat", "scaleType", "Normal" },
                          min = -0.5,
                          max = 0.5,
                          step = 0.01,
                          isPercent = true,
                        },
                        Elite = {
                          name = ELITE,
                          order = 2,
                          type = "range",
                          width = "double",
                          arg = { "threat", "scaleType", "Elite" },
                          min = -0.5,
                          max = 0.5,
                          step = 0.01,
                          isPercent = true,
                        },
                        Boss = {
                          name = BOSS,
                          order = 3,
                          type = "range",
                          width = "double",
                          arg = { "threat", "scaleType", "Boss" },
                          min = -0.5,
                          max = 0.5,
                          step = 0.01,
                          isPercent = true,
                        },
                      },
                    },
                  },
                },
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
                  name = L["Toggles"],
                  order = 1,
                  type = "group",
                  inline = true,
                  args = {
                    UseHPColor = {
                      name = L["Color HP by Threat"],
                      type = "toggle",
                      order = 1,
                      desc = L["This allows HP color to be the same as the threat colors you set below."],
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
              name = L["Spec Roles"],
              type = "group",
              desc = L["Set the roles your specs represent."],
              disabled = function() return not db.threat.ON end,
              order = 5,
              args = dialog_specs,
            },
            Textures = {
              name = L["Textures"],
              type = "group",
              order = 3,
              desc = L["Set threat textures and their coloring options here."],
              disabled = function() return not db.threat.ON end,
              args = {
                ThreatArt = {
                  name = L["Enable"],
                  type = "group",
                  order = 1,
                  inline = true,
                  args = {
                    Enable = {
                      name = L["Enable"],
                      type = "toggle",
                      order = 1,
                      desc = L["These options are for the textures shown on nameplates at various threat levels. Dps/healing uses regular textures, for tanking textures are swapped."],
                      descStyle = "inline",
                      width = "full",
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
                      name = L["Marked Targets"],
                      type = "group",
                      inline = true,
                      order = 20,
                      args = {
                        Toggle = {
                          name = L["Ignore Marked Targets"],
                          order = 2,
                          type = "toggle",
                          desc = L["This will allow you to disabled threat art on marked targets."],
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
        Widgets = {
          name = L["Widgets"],
          type = "group",
          order = 40,
          args = {
            ArenaWidget = {
              name = "Arena",
              type = "group",
              order = 10,
              args = {
                Enable = GetEnableEntry(L["Enable Arena Widget"], L["Enables the showing of indicators (orbs and numbers) for arena opponents."], "arenaWidget"),
                Colors = {
                  name = "Arena Orb Colors",
                  type = "group",
                  inline = true,
                  order = 40,
                  --                  disabled = function() return not db.arenaWidget.ON end,
                  args = {
                    Arena1 = {
                      name = "Arena 1",
                      type = "color",
                      order = 1,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
                      hasAlpha = true,
                      arg = { "arenaWidget", "colors", 1 },
                    },
                    Arena2 = {
                      name = "Arena 2",
                      type = "color",
                      order = 2,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
                      hasAlpha = true,
                      arg = { "arenaWidget", "colors", 2 },
                    },
                    Arena3 = {
                      name = "Arena 3",
                      type = "color",
                      order = 3,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
                      hasAlpha = true,
                      arg = { "arenaWidget", "colors", 3 },
                    },
                    Arena4 = {
                      name = "Arena 4",
                      type = "color",
                      order = 4,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
                      hasAlpha = true,
                      arg = { "arenaWidget", "colors", 4 },
                    },
                    Arena5 = {
                      name = "Arena 5",
                      type = "color",
                      order = 5,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
                      hasAlpha = true,
                      arg = { "arenaWidget", "colors", 5 },
                    },
                  },
                },
                numColors = {
                  name = "Arena Number Colors",
                  type = "group",
                  inline = true,
                  order = 50,
                  --                  disabled = function() return not db.arenaWidget.ON end,
                  args = {
                    Arena1 = {
                      name = "Arena 1",
                      type = "color",
                      order = 1,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
                      hasAlpha = true,
                      arg = { "arenaWidget", "numColors", 1 },
                    },
                    Arena2 = {
                      name = "Arena 2",
                      type = "color",
                      order = 2,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
                      hasAlpha = true,
                      arg = { "arenaWidget", "numColors", 2 },
                    },
                    Arena3 = {
                      name = "Arena 3",
                      type = "color",
                      order = 3,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
                      hasAlpha = true,
                      arg = { "arenaWidget", "numColors", 3 },
                    },
                    Arena4 = {
                      name = "Arena 4",
                      type = "color",
                      order = 4,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
                      hasAlpha = true,
                      arg = { "arenaWidget", "numColors", 4 },
                    },
                    Arena5 = {
                      name = "Arena 5",
                      type = "color",
                      order = 5,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
                      hasAlpha = true,
                      arg = { "arenaWidget", "numColors", 5 },
                    },
                  },
                },
                Layout = GetLayoutEntry(60, "arenaWidget"),
              },
            },
            AuraWidget = {
              name = L["Aura"],
              type = "group",
              order = 20,
              args = {
                Enable = {
                  name = L["Enable"],
                  type = "group",
                  inline = true,
                  order = 10,
                  args = {
                    Toggle = {
                      name = L["Enable"],
                      type = "toggle",
                      order = 1,
                      desc = L["This widget will display auras that match your filtering on your target nameplate and others you recently moused over."],
                      descStyle = "inline",
                      width = "full",
                      arg = { "debuffWidget", "ON" },
                    },
                    Show = {
                      name = "Display Locations",
                      type = "group",
                      order = 2,
                      inline = true,
                      disabled = function() return not db.debuffWidget.ON end,
                      args = {
                        ShowFriendly = {
                          name = L["Show Friendly"],
                          order = 1,
                          type = "toggle",
                          arg = { "debuffWidget", "showFriendly" },
                        },
                        ShowEnemy = {
                          name = L["Show Enemy"],
                          order = 2,
                          type = "toggle",
                          arg = { "debuffWidget", "showEnemy" }
                        }
                      },
                    },
                    Display = {
                      name = "Show Aura Type",
                      type = "multiselect",
                      order = 3,
                      disabled = function() return not db.debuffWidget.ON end,
                      values = {
                        [1] = "Buff",
                        [2] = "Curse",
                        [3] = "Disease",
                        [4] = "Magic",
                        [5] = "Poison",
                        [6] = "Debuff"
                      },
                      get = function(info, k)
                        return db.debuffWidget.displays[k]
                      end,
                      set = function(info, k, v)
                        db.debuffWidget.displays[k] = v
                        TidyPlates:ForceUpdate()
                      end,
                    },
                  },
                },
                Style = {
                  name = L["Style"],
                  type = "group",
                  inline = true,
                  disabled = function() return not db.debuffWidget.ON end,
                  order = 13,
                  args = {
                    Style = {
                      name = L["Style"],
                      type = "select",
                      order = 2,
                      desc = L["This lets you select the layout style of the aura widget. (requires /reload)"],
                      descStyle = "inline",
                      width = "full",
                      values = { wide = L["Wide"], square = L["Square"] },
                      set = function(info, val)
                        SetValue(info, val)
                        if db.debuffWidget.style == "square" then
                          TidyPlatesWidgets.UseSquareDebuffIcon()
                        elseif db.debuffWidget.style == "wide" then
                          TidyPlatesWidgets.UseWideDebuffIcon()
                        end
                      end,
                      arg = { "debuffWidget", "style" },
                    },
                    TargetOnly = {
                      name = L["Target Only"],
                      type = "toggle",
                      order = 1,
                      desc = L["This will toggle the aura widget to only show for your current target."],
                      descStyle = "inline",
                      width = "full",
                      set = function(info, val)
                        SetValue(info, val)
                      end,
                      arg = { "debuffWidget", "targetOnly" },
                    },
                    CooldownSpiral = {
                      name = L["Cooldown Spiral"],
                      type = "toggle",
                      order = 3,
                      desc = L["This will toggle the aura widget to show the cooldown spiral on auras. (requires /reload)"],
                      descStyle = "inline",
                      width = "full",
                      set = function(info, val)
                        SetValue(info, val)
                        TidyPlates:ForceUpdate()
                      end,
                      arg = { "debuffWidget", "cooldownSpiral" },
                    }
                  },
                },
                Sizing = {
                  name = L["Sizing"],
                  type = "group",
                  order = 15,
                  inline = true,
                  disabled = function() return not db.debuffWidget.ON end,
                  args = {
                    Scale = {
                      name = L["Scale"],
                      type = "range",
                      order = 1,
                      width = "full",
                      step = 0.05,
                      softMin = 0.6,
                      softMax = 1.3,
                      isPercent = true,
                      arg = { "debuffWidget", "scale", }
                    },
                  },
                },
                Placement = {
                  name = L["Placement"],
                  type = "group",
                  inline = true,
                  order = 20,
                  disabled = function() return not db.debuffWidget.ON end,
                  args = {
                    X = {
                      name = L["X"],
                      type = "range",
                      order = 1,
                      min = -120,
                      max = 120,
                      step = 1,
                      arg = { "debuffWidget", "x" },
                    },
                    Y = {
                      name = L["Y"],
                      type = "range",
                      order = 2,
                      min = -120,
                      max = 120,
                      step = 1,
                      arg = { "debuffWidget", "y" },
                    },
                    Anchor = {
                      name = L["Anchor"],
                      type = "select",
                      order = 3,
                      values = t.FullAlign,
                      arg = { "debuffWidget", "anchor" }
                    },
                  },
                },
                Filtering = {
                  name = L["Filtering"],
                  order = 30,
                  type = "group",
                  inline = true,
                  disabled = function() return not db.debuffWidget.ON end,
                  args = {
                    Mode = {
                      name = L["Mode"],
                      type = "select",
                      order = 1,
                      width = "double",
                      values = t.DebuffMode,
                      arg = { "debuffWidget", "mode" },
                    },
                    DebuffList = {
                      name = L["Filtered Auras"],
                      type = "input",
                      order = 2,
                      dialogControl = "MultiLineEditBox",
                      width = "full",
                      get = function(info) return t.TTS(db.debuffWidget.filter) end,
                      set = function(info, v)
                        local table = { strsplit("\n", v) };
                        db.debuffWidget.filter = table
                        ThreatPlatesWidgets.ConfigAuraWidgetFilter()
                        TidyPlates:ForceUpdate()
                      end,
                    },
                  },
                },
              },
            },
            AuraWidget2 = {
              name = L["Aura 2.0"],
              type = "group",
              order = 25,
              set = SetValueAuraWidget,
              args = {
                Enable = GetEnableEntry(L["Enable Aura Widget 2.0"], L["This widget will display auras that match your filtering on your target nameplate and others you recently moused over. The old aura widget (Aura) must be disabled first."], "AuraWidget", true),
                Filtering = {
                  name = L["Filtering"],
                  type = "group",
                  inline = true,
                  order = 10,
                  disabled = function() return not db.AuraWidget.ON end,
                  args = {
                    Show = {
                      name = L["Filter by Unit Reaction"],
                      type = "group",
                      order = 2,
                      inline = true,
                      args = {
                        ShowFriendly = {
                          name = L["Show Friendly"],
                          order = 1,
                          type = "toggle",
                          arg = { "AuraWidget", "ShowFriendly" },
                        },
                        ShowEnemy = {
                          name = L["Show Enemy"],
                          order = 2,
                          type = "toggle",
                          arg = { "AuraWidget", "ShowEnemy" }
                        }
                      },
                    },
                    Display = {
                      name = L["Filter by Dispel Type"],
                      type = "multiselect",
                      order = 3,
                      values = {
                        [1] = "Buff",
                        [2] = "Curse",
                        [3] = "Disease",
                        [4] = "Magic",
                        [5] = "Poison",
                        [6] = "Debuff"
                      },
                      get = function(info, k)
                        return db.AuraWidget.FilterByType[k]
                      end,
                      set = function(info, k, v)
                        db.AuraWidget.FilterByType[k] = v
                        ThreatPlatesWidgets.ForceAurasUpdate()
                        TidyPlates:ForceUpdate()
                      end,
                    },
                    Filtering = {
                      name = L["Filter by Spell"],
                      order = 30,
                      type = "group",
                      inline = true,
                      args = {
                        Mode = {
                          name = L["Mode"],
                          type = "select",
                          order = 1,
                          width = "double",
                          values = t.DebuffMode,
                          arg = { "AuraWidget", "FilterMode" },
                        },
                        DebuffList = {
                          name = L["Filtered Auras"],
                          type = "input",
                          order = 2,
                          dialogControl = "MultiLineEditBox",
                          width = "full",
                          get = function(info) return t.TTS(db.AuraWidget.FilterBySpell) end,
                          set = function(info, v)
                            local table = { strsplit("\n", v) };
                            db.AuraWidget.FilterBySpell = table
                            ThreatPlatesWidgets.ConfigAuraWidgetFilter()
                            TidyPlates:ForceUpdate()
                          end,
                        },
                      },
                    },
                  },
                },
                Style = {
                  name = L["Appearance"],
                  order = 13,
                  type = "group",
                  inline = true,
                  disabled = function() return not db.AuraWidget.ON end,
                  args = {
                    TargetOnly = {
                      name = L["Target Only"],
                      type = "toggle",
                      order = 10,
                      desc = L["This will toggle the aura widget to only show for your current target."],
                      arg = { "AuraWidget", "ShowTargetOnly" },
                    },
                    CooldownSpiral = {
                      name = L["Cooldown Spiral"],
                      type = "toggle",
                      order = 20,
                      desc = L["This will toggle the aura widget to show the cooldown spiral on auras."],
                      arg = { "AuraWidget", "ShowCooldownSpiral" },
                    },
                    Stacks = {
                      name = L["Stack Count"],
                      type = "toggle",
                      order = 30,
                      desc = L["Show stack count as overlay on aura icon."],
                      arg = { "AuraWidget", "ShowStackCount" },
                    },
                    AuraTypeColors = {
                      name = L["Color by Dispel Type"],
                      type = "toggle",
                      order = 50,
                      desc = L["This will color the aura based on its type (poison, disease, magic, curse) - for Icon Mode the icon border is colored, for Bar Mode the bar itself."],
                      width = "full",
                      arg = { "AuraWidget", "ShowAuraType" },
                    },
                    DefaultBuffColor = {
                      name = L["Default Buff Color"], type = "color",	order = 54,	arg = {"AuraWidget", "DefaultBuffColor"},	hasAlpha = true,
                      get = GetColorAlpha, set = SetColorAlphaAuraWidget,
                    },
                    DefaultDebuffColor = {
                      name = L["Default Debuff Color"], type = "color",	order = 56, arg = {"AuraWidget","DefaultDebuffColor"},	hasAlpha = true,
                      get = GetColorAlpha, set = SetColorAlphaAuraWidget,
                    },
                  },
                },
                SortOrder = {
                  name = L["Sort Order"], order = 15,	type = "group",	inline = true, disabled = function() return not db.AuraWidget.ON end,
                  args = {
                    NoSorting = {
                      name = L["None"], type = "toggle",	order = 0,	 width = "half",
                      desc = L["Do not sort auras."],
                      get = function(info) return db.AuraWidget.SortOrder == "None" end,
                      set = function(info, value) SetValueAuraWidget(info, "None") end,
                      arg = {"AuraWidget","SortOrder"},
                    },
                    AtoZ = {
                      name = L["A to Z"], type = "toggle",	order = 10, width = "half",
                      desc = L["Sort in ascending alphabetical order."],
                      get = function(info) return db.AuraWidget.SortOrder == "AtoZ" end,
                      set = function(info, value) SetValueAuraWidget(info, "AtoZ") end,
                      arg = {"AuraWidget","SortOrder"},
                    },
                    TimeLeft = {
                      name = L["Time Left"], type = "toggle",	order = 20,	 width = "half",
                      desc = L["Sort by time left in ascending order."],
                      get = function(info) return db.AuraWidget.SortOrder == "TimeLeft" end,
                      set = function(info, value) SetValueAuraWidget(info, "TimeLeft") end,
                      arg = {"AuraWidget","SortOrder"},
                    },
                    Duration = {
                      name = L["Duration"], type = "toggle",	order = 30,	 width = "half",
                      desc = L["Sort by overall duration in ascending order."],
                      get = function(info) return db.AuraWidget.SortOrder == "Duration" end,
                      set = function(info, value) SetValueAuraWidget(info, "Duration") end,
                      arg = {"AuraWidget","SortOrder"},
                    },
                    Creation = {
                      name = L["Creation"], type = "toggle",	order = 40,	 width = "half",
                      desc = L["Show auras in order created with oldest aura first."],
                      get = function(info) return db.AuraWidget.SortOrder == "Creation" end,
                      set = function(info, value) SetValueAuraWidget(info, "Creation") end,
                      arg = {"AuraWidget","SortOrder"},
                    },
                    ReverseOrder = {
                      name = L["Reverse Order"], type = "toggle",	order = 50,	desc = L['Reverse the sort order (e.g., "A to Z" becomes "Z to A").'],	arg = { "AuraWidget", "SortReverse" }
                    },
                  },
                },
                Layout = {
                  name = L["Layout"],
                  order = 20,
                  type = "group",
                  inline = true,
                  disabled = function() return not db.AuraWidget.ON end,
                  args = {
                    Sizing = {
                      name = L["Sizing"],
                      type = "group",
                      order = 15,
                      inline = true,
                      disabled = function() return not db.AuraWidget.ON end,
                      args = {
                        Scale = {
                          name = L["Scale"],
                          type = "range",
                          order = 1,
                          width = "full",
                          step = 0.05,
                          softMin = 0.6,
                          softMax = 1.3,
                          isPercent = true,
                          arg = { "AuraWidget", "scale", }
                        },
                      },
                    },
                    Placement = {
                      name = L["Placement"],
                      type = "group",
                      inline = true,
                      order = 20,
                      disabled = function() return not db.AuraWidget.ON end,
                      args = {
                        Anchor = { name = L["Anchor Point"], order = 1, type = "select", values = t.ANCHOR_POINT, arg = { "AuraWidget", "anchor" } },
                        X = { name = L["Offset X"], order = 2, type = "range", min = -120, max = 120, step = 1, arg = { "AuraWidget", "x" }, },
                        Y = { name = L["Offset Y"], order = 3, type = "range", min = -120, max = 120, step = 1, arg = { "AuraWidget", "y" }, },
                        Spacer = GetSpacerEntry(5),
                        AlignmentH = { name = L["Horizontal Alignment"], order = 6, type = "select", values = { LEFT = L["Left-to-right"], RIGHT = L["Right-to-left"] }, arg = { "AuraWidget", "AlignmentH" } },
                        AlignmentV = { name = L["Vertical Alignment"], order = 7, type = "select", values = { BOTTOM = L["Bottom-to-top"], TOP = L["Top-to-bottom"] }, arg = { "AuraWidget", "AlignmentV" } }
                      },
                    },
                  },
                },
                ModeIcon = {
                  name = L["Icon Mode"],
                  order = 30,
                  type = "group",
                  inline = true,
                  disabled = function() return not db.AuraWidget.ON or db.AuraWidget.ModeBar.Enabled end,
                  args = {
                    Help = { type = "description", order = 0, width = "full", name = L["Show auras as icons in a grid configuration."], },
                    Enable = {
                      type = "toggle",
                      order = 10,
                      name = L["Enable"],
                      width = "full",
                      arg = { "AuraWidget", "ModeBar", "Enabled" },
                      disabled = function() return not db.AuraWidget.ON end,
                      set = function(info, val) SetValueAuraWidget(info, false) end,
                      get = function(info) return not GetValue(info, val) end,
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
                          desc = L["This lets you select the layout style of the aura widget."],
                          descStyle = "inline",
                          values = { wide = L["Wide"], square = L["Square"] },
                          arg = { "AuraWidget", "ModeIcon", "Style" },
                        },
                      },
                    },
                    Layout = {
                      name = L["Layout"],
                      order = 40,
                      type = "group",
                      inline = true,
                      args = {
                        Columns = { name = L["Column Limit"], order = 20, type = "range", min = 1, max = 8, step = 1, arg = { "AuraWidget", "ModeIcon", "Columns" }, },
                        Rows = { name = L["Row Limit"], order = 30, type = "range", min = 1, max = 10, step = 1, arg = { "AuraWidget", "ModeIcon", "Rows" }, },
                        ColumnSpacing = { name = L["Horizontal Spacing"], order = 40, type = "range", min = 0, max = 100, step = 1, arg = { "AuraWidget", "ModeIcon", "ColumnSpacing" }, },
                        RowSpacing = { name = L["Vertical Spacing"], order = 50, type = "range", min = 0, max = 100, step = 1, arg = { "AuraWidget", "ModeIcon", "RowSpacing" }, },
                      },
                    },
                  },
                },
                ModeBar = {
                  name = L["Bar Mode"],
                  order = 40,
                  type = "group",
                  inline = true,
                  disabled = function() return not db.AuraWidget.ON or not db.AuraWidget.ModeBar.Enabled end,
                  args = {
                    Help = { type = "description", order = 0, width = "full", name = L["Show auras as bars (with optional icons)."], },
                    Enable = { type = "toggle", order = 10, name = L["Enable"], width = "full", arg = { "AuraWidget", "ModeBar", "Enabled" }, disabled = function() return not db.AuraWidget.ON end, },
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
                              get = GetColorAlpha, set = SetColorAlphaAuraWidget,
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
                            FontColor = {	name = L["Color"], type = "color",	order = 30,	get = GetColor,	set = SetColorAuraWidget,	arg = {"AuraWidget","ModeBar", "FontColor"},	hasAlpha = false, },
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
            },
            ClassIconWidget = ClassIconsWidgetOptions(),
            ComboPointWidget = {
              name = L["Combo Points"],
              type = "group",
              order = 40,
              args = {
                Enable = GetEnableEntry(L["Enable Combo Points Widget"], L["This widget will display combo points on your target nameplate."], "comboWidget", true),
                Layout = {
                  name = L["Layout"],
                  order = 10,
                  type = "group",
                  inline = true,
                  args = {
                    Scale = GetUnitScaleEntry(L["Scale"], 10, { "comboWidget", "scale" }),
                    Placement = GetPlacementEntryWidget(20, "comboWidget", true),
                  },
                },
              },
            },
            PowerWidget = {
              name = L["Resource"],
              type = "group",
              order = 45,
              args = {
                Enable = GetEnableEntry(L["Enable Resource Widget"], L["This widget will display the current resource of your current target on the nameplate. The bar#s color is derived from the type of resource by the game."], "ResourceWidget"),
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
                      type = "toggle",
                      arg = { "ResourceWidget", "ShowEnemyNPC" },
                    },
                    ShowBigUnits = {
                      name = L["Rares, Elites & Bosses"],
                      order = 40,
                      type = "toggle",
                      desc = L["Shows resource information for bosses, rares and elites (elites only if not in an instance)"],
                      arg = { "ResourceWidget", "ShowEnemyBoss" },
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
                      width = "half",
                      arg = { "ResourceWidget", "ShowBar" },
                    },
                    BarWidth = { name = L["Bar Width"], order = 30, type = "range", min = 1, max = 500, step = 1, arg = { "ResourceWidget", "BarWidth" }, },
                    BarHeight = { name = L["Bar Height"], order = 40, type = "range", min = 1, max = 500, step = 1, arg = { "ResourceWidget", "BarHeight" }, },
                    BarTexture = { name = L["Foreground Texture"], order = 60, type = "select", dialogControl = "LSM30_Statusbar", values = AceGUIWidgetLSMlists.statusbar, arg = { "ResourceWidget", "BarTexture" }, },
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
                      set = function(info, val) SetValue(info, not val) end,
                      get = function(info, val) return not GetValue(info, val) end,
                      arg = { "ResourceWidget", "BackgroundUseForegroundColor" },
                    },
                    BGColorCustom = {
                      name = L["Color"],
                      type = "color",
                      order = 235,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
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
                          SetValue(info, val);
                        else
                          db.ResourceWidget.BorderUseBackgroundColor = false
                          SetValue(info, val);
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
                          SetValue(info, val);
                        else
                          db.ResourceWidget.BorderUseForegroundColor = false
                          SetValue(info, val);
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
                      set = function(info, val) db.ResourceWidget.BorderUseForegroundColor = false; db.ResourceWidget.BorderUseBackgroundColor = false; t.Update() end,
                      get = function(info, val) return not (db.ResourceWidget.BorderUseForegroundColor or db.ResourceWidget.BorderUseBackgroundColor) end,
                      arg = { "ResourceWidget", "BackgroundUseForegroundColor" },
                    },
                    BorderColorCustom = {
                      name = L["Color"],
                      type = "color",
                      order = 335,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
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
                    FontColor = {	name = L["Color"], type = "color",	order = 30,	get = GetColor,	set = SetColorAuraWidget,	arg = {"ResourceWidget", "FontColor"},	hasAlpha = false, },
                  },
                },
                Placement = GetPlacementEntryWidget(40, "ResourceWidget"),
              },
            },
            SocialWidget = {
              name = L["Social"],
              type = "group",
              order = 50,
              args = {
                Enable = GetEnableEntry(L["Enable Social Widget"], L["Enables the showing of indicator icons for (BNET) friends, guild members, and faction."], "socialWidget", true),
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
                          desc = L["Shows an indicator icon for friends and guild members next to the nameplate of players."],
                          arg = { "socialWidget", "ShowFriendIcon" },
                          --disabled = function() return not (db.socialWidget.ON or db.socialWidget.ShowInHeadlineView) end,
                        },
                        Size = GetSizeEntry(10, "socialWidget"),
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
                        Help = { type = "description", order = 0,	width = "full",	name = L["Use a custom color for the healthbar of friends and/or guild members."],	},
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
                    Size = GetSizeEntry(10, "FactionWidget"),
                    Offset = GetPlacementEntryWidget(30, "FactionWidget", true),
                  },
                },
              },
            },
            StealthWidget = StealthWidgetOptions(),
            TargetArtWidget = {
              name = L["Target Highlight"],
              type = "group",
              order = 70,
              args = {
                Enable = GetEnableEntry(L["Enable Target Highlight Widget"], L["Enables the showing of a texture on your target nameplate"], "targetWidget"),
                Texture = {
                  name = L["Texture"],
                  type = "group",
                  inline = true,
--                  disabled = function() if db.targetWidget.ON then return false else return true end end,
                  args = {
                    Preview = {
                      name = L["Preview"],
                      order = 0,
                      width = "full",
                      type = "execute",
                      image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\TargetArtWidget\\" .. db.targetWidget.theme,
                      imageWidth = 256,
                      imageHeight = 64,
                    },
                    Color = {
                      name = L["Color"],
                      type = "color",
                      width = "full",
                      order = 1,
                      get = GetColorAlpha,
                      set = SetColorAlpha,
                      hasAlpha = true,
                      arg = { "targetWidget" },
                    },
                    Select = {
                      name = L["Style"],
                      type = "select",
                      width = "full",
                      order = 3,
                      set = function(info, val)
                        SetValue(info, val)
                        options.args.Widgets.args.TargetArtWidget.args.Texture.args.Preview.image = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\TargetArtWidget\\" .. db.targetWidget.theme;
                      end,
                      values = { default = "Default", squarethin = "Thin Square", arrows = "Arrows", crescent = "Crescent", bubble = "Bubble" },
                      arg = { "targetWidget", "theme" },
                    },
                  },
                },
              },
            },
            QuestWidget = QuestWidgetOptions(),
          },
        },
        Totems = {
          name = L["Totem Nameplates"],
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
              name = L["Clear and easy to use nameplate theme for use with TidyPlates.\n\nCurrent version: "] .. GetAddOnMetadata("TidyPlates_ThreatPlates", "version") .. L["\n\nFeel free to email me at |cff00ff00threatplates@gmail.com|r\n\n--\n\nBlacksalsify\n\n(Original author: Suicidal Katt - |cff00ff00Shamtasticle@gmail.com|r)"],
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
--						Translators2 = {
--							type = "description",
--							order = 5,
--							width = "full",
--							name = "esES: Need Translator!!"
--						},
--						Translators3 = {
--							type = "description",
--							order = 6,
--							width = "full",
--							name = "esMX: Need Translator!!"
--						},
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
            Translators7 = {
              type = "description",
              order = 10,
              width = "full",
              name = "zhCN: y123ao6 (CurseForge)"
            },
--						Translators8 = {
--							type = "description",
--							order = 11,
--							width = "full",
--							name = "zhTW: Need Translator!!"
--						},
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
      values = { default = "Default", transparent = "Transparent" },
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
              arg = { "totemSettings", "hideHealthbar" },
            },
--            Header1 = {
--              type = "header",
--              order = 2,
--              name = "",
--            },
--            ShowEnemy = {
--              name = L["Show Enemy Totems"],
--              type = "toggle",
--              order = 3,
--              get = GetCvar,
--              set = SetCvar,
--              arg = "nameplateShowEnemyTotems",
--            },
--            ShowFriend = {
--              name = L["Show Friendly Totems"],
--              type = "toggle",
--              order = 4,
--              get = GetCvar,
--              set = SetCvar,
--              arg = "nameplateShowFriendlyTotems",
--            },
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
              width = "half",
              arg = { "totemWidget", "ON" },
            },
            Size = GetSizeEntry(10, "totemWidget"),
            Offset = GetPlacementEntryWidget(30, "totemWidget"),
          },
        },
        Alpha = {
          name = L["Alpha"],
          type = "group",
          order = 3,
          inline = true,
          args = {
            TotemAlpha = {
              name = L["Totem Alpha"],
              order = 1,
              type = "range",
              width = "full",
              arg = { "nameplate", "alpha", "Totem" },
              step = 0.05,
              min = 0,
              max = 1,
              isPercent = true,
            },
          },
        },
        Scale = {
          name = L["Scale"],
          type = "group",
          order = 4,
          inline = true,
          args = {
            TotemAlpha = {
              name = L["Totem Scale"],
              order = 1,
              type = "range",
              width = "full",
              arg = { "nameplate", "scale", "Totem" },
              step = 0.05,
              softMin = 0.6,
              softMax = 1.3,
              isPercent = true,
            },
          },
        },
      },
    },
  };

  local totemID = TidyPlatesThreat.TOTEM_DATA
  table.sort(totemID, function(a, b) return (string.sub(a[2], 1, 1)..TotemNameBySpellID(a[1])) < (string.sub(b[2], 1, 1)..TotemNameBySpellID(b[1])) end)
  for k_c, v_c in ipairs(totemID) do
    TotemOpts[GetSpellName(totemID[k_c][1])] = {
      name = "|cff" .. totemID[k_c][3] .. GetSpellName(totemID[k_c][1]) .. "|r",
      type = "group",
      order = k_c,
      args = {
        Header = {
          name = "> |cff" .. totemID[k_c][3] .. GetSpellName(totemID[k_c][1]) .. "|r <",
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
              arg = { "totemSettings", totemID[k_c][2], 1 },
            },
          },
        },
        HealthColor = {
          name = L["Health Coloring"],
          type = "group",
          order = 2,
          inline = true,
          disabled = function() if db.totemSettings[totemID[k_c][2]][1] then return false else return true end end,
          args = {
            Enable = {
              name = L["Enable Custom Colors"],
              type = "toggle",
              order = 1,
              arg = { "totemSettings", totemID[k_c][2], 2 },
            },
            Color = {
              name = L["Color"],
              type = "color",
              order = 2,
              get = GetColor,
              set = SetColor,
              disabled = function() if not db.totemSettings[totemID[k_c][2]][1] or not db.totemSettings[totemID[k_c][2]][2] then return true else return false end end,
              arg = { "totemSettings", totemID[k_c][2], "color" },
            },
          },
        },
        Textures = {
          name = L["Textures"],
          type = "group",
          order = 3,
          inline = true,
          disabled = function() if db.totemSettings[totemID[k_c][2]][1] then return false else return true end end,
          args = {
            Icon = {
              name = "",
              type = "execute",
              width = "full",
              order = 0,
              image = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\TotemIconWidget\\" .. db.totemSettings[totemID[k_c][2]][7] .. "\\" .. totemID[k_c][2],
            },
            Style = {
              name = "",
              type = "select",
              order = 1,
              width = "full",
              set = function(info, val)
                SetValue(info, val)
                options.args.Totems.args[GetSpellName(totemID[k_c][1])].args.Textures.args.Icon.image = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\TotemIconWidget\\" .. db.totemSettings[totemID[k_c][2]][7] .. "\\" .. totemID[k_c][2];
              end,
              values = { normal = "Normal", special = "Special" },
              arg = { "totemSettings", totemID[k_c][2], 7 },
            },
          },
        },
      },
    }
  end
  options.args.Totems.args = TotemOpts;
  local CustomOpts_OrderCnt = 30;
  local CustomOpts = {
    GeneralSettings = {
      name = L["|cffffffffGeneral Settings|r"],
      type = "group",
      order = 0,
      args = {
        Icon = {
          name = L["Icon"],
          type = "group",
          order = 1,
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
              arg = { "uniqueWidget", "ON" }
            },
            Size = GetSizeEntry(10, "uniqueWidget"),
--            Anchor = {
--              name = L["Anchor"],
--              type = "select",
--              order = 20,
--              values = t.FullAlign,
--              arg = { "uniqueWidget", "anchor" }
--            },
            Placement = GetPlacementEntryWidget(30, "uniqueWidget"),
          },
        },
      },
    },
  };
  local CustomOpts_OrderCnt = 30;
  local clipboard = nil;
  for k_c, v_c in ipairs(db.uniqueSettings) do
    CustomOpts["#" .. k_c] = {
      name = "#" .. k_c .. ". " .. db.uniqueSettings[k_c].name,
      type = "group",
      --disabled = function() if db.totemSettings[totemID[k_c][2]][1] then return false else return true end end,
      order = CustomOpts_OrderCnt,
      args = {
        Header = {
          name = db.uniqueSettings[k_c].name,
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
              name = db.uniqueSettings[k_c].name,
              type = "input",
              order = 1,
              width = "full",
              set = function(info, val)
                SetValue(info, val)
                options.args.Custom.args["#" .. k_c].name = "#" .. k_c .. ". " .. val
                options.args.Custom.args["#" .. k_c].args.Header.name = val
                options.args.Custom.args["#" .. k_c].args.Name.args.SetName.name = val
                UpdateSpecial()
              end,
              arg = { "uniqueSettings", k_c, "name" },
            },
            TargetButton = {
              name = L["Use Target's Name"],
              type = "execute",
              order = 2,
              width = "single",
              func = function()
                if UnitExists("Target") then
                  local target = UnitName("Target")
                  db.uniqueSettings[k_c].name = target
                  options.args.Custom.args["#" .. k_c].name = "#" .. k_c .. ". " .. target
                  options.args.Custom.args["#" .. k_c].args.Header.name = target
                  options.args.Custom.args["#" .. k_c].args.Name.args.SetName.name = target
                  UpdateSpecial()
                else
                  t.Print(L["No target found."])
                end
              end,
            },
            ClearButton = {
              name = L["Clear"],
              type = "execute",
              order = 3,
              width = "single",
              func = function()
                db.uniqueSettings[k_c].name = ""
                options.args.Custom.args["#" .. k_c].name = "#" .. k_c .. ". " .. ""
                options.args.Custom.args["#" .. k_c].args.Header.name = ""
                options.args.Custom.args["#" .. k_c].args.Name.args.SetName.name = ""
                UpdateSpecial()
              end,
            },
            Header1 = {
              name = "",
              order = 4,
              type = "header",
            },
            Copy = {
              name = L["Copy"],
              order = 5,
              type = "execute",
              func = function()
                clipboard = {}
                clipboard = t.CopyTable(db.uniqueSettings[k_c])
                t.Print(L["Copied!"])
              end,
            },
            Paste = {
              name = L["Paste"],
              order = 6,
              type = "execute",
              func = function()
                if type(clipboard) == "table" and clipboard.name then
                  db.uniqueSettings[k_c] = t.CopyTable(clipboard)
                  t.Print(L["Pasted!"])
                else
                  t.Print(L["Nothing to paste!"])
                end
                options.args.Custom.args["#" .. k_c].name = "#" .. k_c .. ". " .. db.uniqueSettings[k_c].name
                options.args.Custom.args["#" .. k_c].args.Header.name = db.uniqueSettings[k_c].name
                options.args.Custom.args["#" .. k_c].args.Name.args.SetName.name = db.uniqueSettings[k_c].name
                if tonumber(db.uniqueSettings[k_c].icon) == nil then
                  options.args.Custom.args["#" .. k_c].args.Icon.args.Icon.image = db.uniqueSettings[k_c].icon
                else
                  local icon = select(3, GetSpellInfo(tonumber(db.uniqueSettings[k_c].icon)))
                  if icon then
                    options.args.Custom.args["#" .. k_c].args.Icon.args.Icon.image = icon
                  else
                    options.args.Custom.args["#" .. k_c].args.Icon.args.Icon.image = "Interface\\Icons\\Temp"
                  end
                end
                UpdateSpecial()
                clipboard = nil
              end,
            },
            Header2 = {
              name = "",
              order = 7,
              type = "header",
            },
            ResetDefault = {
              type = "execute",
              name = L["Restore Defaults"],
              order = 8,
              func = function()
                local defaults = {
                  name = "",
                  showNameplate = true,
                  showIcon = true,
                  useStyle = true,
                  useColor = true,
                  allowMarked = true,
                  overrideScale = false,
                  overrideAlpha = false,
                  icon = "",
                  scale = 1,
                  alpha = 1,
                  color = {
                    r = 1,
                    g = 1,
                    b = 1
                  },
                }
                db.uniqueSettings[k_c] = defaults
                options.args.Custom.args["#" .. k_c].name = "#" .. k_c .. ". " .. ""
                options.args.Custom.args["#" .. k_c].args.Header.name = ""
                options.args.Custom.args["#" .. k_c].args.Name.args.SetName.name = ""
                options.args.Custom.args["#" .. k_c].args.Icon.args.Icon.image = ""
                UpdateSpecial()
              end,
            },
          },
        },
        Enabled = {
          name = L["Enable"],
          type = "group",
          inline = true,
          order = 2,
          args = {
            UseStyle = {
              name = L["Use Custom Settings"],
              type = "toggle",
              order = 1,
              arg = { "uniqueSettings", k_c, "useStyle" },
            },
            Header1 = {
              type = "header",
              order = 2,
              name = "",
            },
            Namplate = {
              name = L["Show Nameplate"],
              type = "toggle",
              disabled = function() if db.uniqueSettings[k_c].useStyle then return false else return true end end,
              order = 3,
              arg = { "uniqueSettings", k_c, "showNameplate" },
            },
            CustomSettings = {
              name = L["Custom Settings"],
              type = "group",
              inline = true,
              order = 4,
              disabled = function() if not db.uniqueSettings[k_c].useStyle or not db.uniqueSettings[k_c].showNameplate then return true else return false end end,
              args = {
                AlphaSettings = {
                  name = L["Alpha"],
                  type = "group",
                  order = 1,
                  inline = true,
                  args = {
                    DisableOverride = {
                      name = L["Disable Custom Alpha"],
                      type = "toggle",
                      desc = L["Disables the custom alpha setting for this nameplate and instead uses your normal alpha settings."],
                      descStyle = "inline",
                      width = "full",
                      order = 1,
                      arg = { "uniqueSettings", k_c, "overrideAlpha" },
                    },
                    AlphaSetting = {
                      name = L["Custom Alpha"],
                      type = "range",
                      order = 2,
                      disabled = function() if db.uniqueSettings[k_c].overrideAlpha or not db.uniqueSettings[k_c].useStyle or not db.uniqueSettings[k_c].showNameplate then return true else return false end end,
                      min = 0,
                      max = 1,
                      step = 0.05,
                      isPercent = true,
                      arg = { "uniqueSettings", k_c, "alpha" },
                    },
                  },
                },
                ScaleSettings = {
                  name = L["Scale"],
                  type = "group",
                  order = 1,
                  inline = true,
                  args = {
                    DisableOverride = {
                      name = L["Disable Custom Scale"],
                      type = "toggle",
                      desc = L["Disables the custom scale setting for this nameplate and instead uses your normal scale settings."],
                      descStyle = "inline",
                      width = "full",
                      order = 1,
                      arg = { "uniqueSettings", k_c, "overrideScale" },
                    },
                    ScaleSetting = {
                      name = L["Custom Scale"],
                      type = "range",
                      order = 2,
                      disabled = function() if db.uniqueSettings[k_c].overrideScale or not db.uniqueSettings[k_c].useStyle or not db.uniqueSettings[k_c].showNameplate then return true else return false end end,
                      min = 0,
                      max = 1.4,
                      step = 0.05,
                      isPercent = true,
                      arg = { "uniqueSettings", k_c, "scale" },
                    },
                  },
                },
                HealthColor = {
                  name = L["Health Coloring"],
                  type = "group",
                  order = 3,
                  inline = true,
                  args = {
                    UseRaidMarked = {
                      name = L["Color by Raid Marks"],
                      type = "toggle",
                      desc = L["Additionally color the healthbar based on the raid mark if the nameplate is marked."],
                      descStyle = "inline",
                      width = "full",
                      order = 1,
                      arg = { "uniqueSettings", k_c, "allowMarked" },
                    },
                    Enable = {
                      name = L["Enable Custom Colors"],
                      type = "toggle",
                      order = 2,
                      arg = { "uniqueSettings", k_c, "useColor" },
                    },
                    Color = {
                      name = L["Color"],
                      type = "color",
                      order = 3,
                      get = GetColor,
                      set = SetColor,
                      disabled = function() if not db.uniqueSettings[k_c].useColor or not db.uniqueSettings[k_c].useStyle or not db.uniqueSettings[k_c].showNameplate then return true else return false end end,
                      arg = { "uniqueSettings", k_c, "color" },
                    },
                  Spacer = GetSpacerEntry(4),
                  ThreatColor = {
                    name = L["Use Threat Colors"],
                    order = 5,
                    type = "toggle",
                    desc = L["Use coloring based an threat level (configured in Threat System) in combat (custom color is only used out of combat)."],
                    arg = {"uniqueSettings", k_c, "UseThreatColor"},
                  },
                  ThreatGlow = {
                    name = L["Show Threat Glow"],
                    order = 5,
                    type = "toggle",
                    desc = L["Show a glow based on threat level around the nameplate's healthbar (in combat)."],
                    arg = {"uniqueSettings", k_c, "UseThreatGlow"},
                  }
                  },
                },
              },
            },
          },
        },
        Icon = {
          name = L["Icon"],
          type = "group",
          order = 3,
          inline = true,
          disabled = function() if not db.uniqueWidget.ON or not db.uniqueSettings[k_c].showNameplate then return true else return false end end,
          args = {
            Enable = {
              name = L["Enable"],
              type = "toggle",
              order = 1,
              desc = L["Enable the showing of the custom nameplate icon for this nameplate."],
              descStyle = "inline",
              width = "full",
              arg = { "uniqueSettings", k_c, "showIcon" }
            },
            Icon = {
              name = L["Preview"],
              type = "execute",
              width = "full",
              disabled = function() if not db.uniqueSettings[k_c].showIcon or not db.uniqueWidget.ON or not db.uniqueSettings[k_c].showNameplate then return true else return false end end,
              order = 2,
              image = function()
                if tonumber(db.uniqueSettings[k_c].icon) == nil then
                  return db.uniqueSettings[k_c].icon
                else
                  local icon = select(3, GetSpellInfo(tonumber(db.uniqueSettings[k_c].icon)))
                  if icon then
                    return icon
                  else
                    return "Interface\\Icons\\Temp"
                  end
                end
              end,
              imageWidth = 64,
              imageHeight = 64,
            },
            Description = {
              type = "description",
              order = 3,
              name = L["Type direct icon texture path using '\\' to separate directory folders, or use a spellid."],
              width = "full",
            },
            SetIcon = {
              name = L["Set Icon"],
              type = "input",
              order = 4,
              disabled = function() if not db.uniqueSettings[k_c].showIcon or not db.uniqueWidget.ON or not db.uniqueSettings[k_c].showNameplate then return true else return false end end,
              width = "full",
              set = function(info, val)
                if tonumber(val) then
                  val = select(3, GetSpellInfo(tonumber(val)))
                end
                SetValue(info, val)
                if val then
                  options.args.Custom.args["#" .. k_c].args.Icon.args.Icon.image = val
                else
                  options.args.Custom.args["#" .. k_c].args.Icon.args.Icon.image = "Interface\\Icons\\Temp"
                end
                UpdateSpecial()
              end,
              arg = { "uniqueSettings", k_c, "icon" },
            },
          },
        },
      },
    }
    CustomOpts_OrderCnt = CustomOpts_OrderCnt + 10;
  end
  options.args.Custom.args = CustomOpts;
  return options
end

local intoptions = nil;
local function GetIntOptions()
  if not intoptions then
    intoptions = {
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
          name = L["Open Config"],
          image = path .. "Logo",
          width = "full",
          imageWidth = 256,
          imageHeight = 32,
          func = function()
            TidyPlatesThreat:OpenOptions()
          end,
          order = 20,
        },
      },
    };
  end
  return intoptions;
end

function TidyPlatesThreat:OpenOptions()
  HideUIPanel(InterfaceOptionsFrame)
  HideUIPanel(GameMenuFrame)
  if not options then TidyPlatesThreat:SetUpOptions() end
  LibStub("AceConfigDialog-3.0"):Open("Tidy Plates: Threat Plates");
end

function TidyPlatesThreat:ChatCommand(input)
  TidyPlatesThreat.ParseCommandLine(input)
end

function TidyPlatesThreat:ConfigRefresh()
  db = self.db.profile;
  t.SetThemes(self)
  UpdateSpecial()
end

function TidyPlatesThreat:SetUpInitialOptions()
  -- Chat Command
  self:RegisterChatCommand("tptp", "ChatCommand");

  -- Interface panel options

  LibStub("AceConfig-3.0"):RegisterOptionsTable("Tidy Plates: Threat Plates Dialog", GetIntOptions);

  self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Tidy Plates: Threat Plates Dialog", "Tidy Plates: Threat Plates");
end

function TidyPlatesThreat:AddOptions(class)
  local AddOptionsTable = {
    DEATHKNIGHT = {
      AuraType = L["Presences"],
      index = "presences",
      names = {
        [1] = GetSpellInfo(48263), -- Blood
        [2] = GetSpellInfo(48266), -- Frost
        [3] = GetSpellInfo(48265) -- Unholy
      },
    },
    DRUID = {
      AuraType = L["Shapeshifts"],
      index = "shapeshifts",
      names = {
        [1] = GetSpellInfo(5487), -- Bear Form
        [2] = GetSpellInfo(783), -- Cat Form
        [3] = GetSpellInfo(783), -- Travel Form
        [4] = GetSpellInfo(114282) .. ", " .. GetSpellInfo(24858) -- Tree of Life (Glyphed), Moonkin
      },
    },
    PALADIN = {
      AuraType = L["Seals"],
      index = "seals",
      names = {
        [1] = GetSpellInfo(465), -- Devotion Aura
        [2] = GetSpellInfo(7294), -- Retribution Aura
        [3] = GetSpellInfo(19746), -- Concentration Aura
        [4] = GetSpellInfo(19891), -- Resistance Aura
        [5] = GetSpellInfo(32223) -- Crusader Aura
      },
    },
    WARRIOR = {
      AuraType = L["Stances"],
      index = "stances",
      names = {
        [1] = GetSpellInfo(2457), -- Battle Stance
        [2] = GetSpellInfo(71), -- Defensive Stance
        [3] = GetSpellInfo(2458) -- Berserker Stance
      },
    },
  }
  local index = AddOptionsTable[class].index
  local _db = TidyPlatesThreat.db.char[index]
  local AdditionalOptions = {
    type = "group",
    name = AddOptionsTable[class].AuraType,
    order = 70,
    args = {
      Enable = {
        type = "toggle",
        order = 1,
        name = L["Enable"],
        get = GetValueChar,
        set = SetValueChar,
        arg = { index, "ON" },
      },
      Options = {
        type = "group",
        order = 2,
        inline = false,
        disabled = function() if not _db.ON or not TidyPlatesThreat.db.profile.threat.ON then return true else return false end end,
        name = L["Options"],
        args = {},
      },
    },
  }
  local addorder = 20
  for k_c, k_v in pairs(AddOptionsTable[class].names) do
    -- t.DEBUG(k_c.. " "..k_v)
    AdditionalOptions.args.Options.args[index .. k_c] = {
      type = "group",
      name = k_v,
      inline = true,
      order = k_c,
      args = {
        Tank = {
          type = "toggle",
          order = 1,
          name = L["|cff00ff00Tank|r"],
          get = function(info) if _db[k_c] then return true else return false end end,
          set = function(info, val) _db[k_c] = true; TidyPlatesThreat.ShapeshiftUpdate() end,
        },
        DPS = {
          type = "toggle",
          order = 2,
          name = L["|cffff0000DPS/Healing|r"],
          get = function(info) if not _db[k_c] then return true else return false end end,
          set = function(info, val) _db[k_c] = false; TidyPlatesThreat.ShapeshiftUpdate() end,
        },
      },
    }
    addorder = addorder + 10
  end
  options.args.Stances = {};
  options.args.Stances = AdditionalOptions;
end

function TidyPlatesThreat:SetUpOptions()
  db = self.db.profile;

  -- Options Window
  GetOptions();
  UpdateSpecial();
  t.Update();

  if class == "DEATHKNIGHT" or class == "DRUID" or class == "PALADIN" or class == "WARRIOR" then
    --TidyPlatesThreat:AddOptions(class)
  end

  options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db);
  options.args.profiles.order = 10000;

  LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Tidy Plates: Threat Plates", options);
  LibStub("AceConfigDialog-3.0"):SetDefaultSize("Tidy Plates: Threat Plates", 1000, 640)
end
