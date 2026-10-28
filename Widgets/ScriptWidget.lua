---------------------------------------------------------------------------------------------------
-- Script Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = Addon.Widgets:NewWidget("Script")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local next, pairs, ipairs = next, pairs, ipairs
local assert, setmetatable = assert, setmetatable
local string_format = string.format

-- WoW APIs
local pcall = pcall
local CreateFrame = CreateFrame
local loadstring, setfenv = loadstring, setfenv

-- ThreatPlates APIs
local L = Addon.L

local _G =_G

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------

Addon.SCRIPT_FUNCTIONS = {
  Standard = {
    IsEnabled = "IsEnabled", OnEnable = "OnEnable", OnDisable = "OnDisable",
    EnabledForStyle = "EnabledForStyle",
    Create = "Create", UpdateFrame = "UpdateFrame", UpdateSettings = "UpdateSettings", UpdateLayout = "UpdateLayout",
    OnUnitAdded = "OnUnitAdded", OnUnitRemoved = "OnUnitRemoved", OnUpdate = "OnUpdate",
    WoWEvent = "Event",
  },
  TargetOnly = {
    IsEnabled = "IsEnabled", OnEnable = "OnEnable", OnDisable = "OnDisable",
    EnabledForStyle = "EnabledForStyle",
    Create = "Create", UpdateFrame = "UpdateFrame", UpdateSettings = "UpdateSettings", UpdateLayout = "UpdateLayout",
    OnTargetUnitAdded = "OnTargetUnitAdded", OnTargetUnitRemoved = "OnTargetUnitRemoved", OnUpdate = "OnUpdate",
    WoWEvent = "Event",
  },
  FocusOnly = {
    IsEnabled = "IsEnabled", OnEnable = "OnEnable", OnDisable = "OnDisable",
    EnabledForStyle = "EnabledForStyle",
    Create = "Create", UpdateFrame = "UpdateFrame", UpdateSettings = "UpdateSettings", UpdateLayout = "UpdateLayout",
    OnFocusUnitAdded = "OnFocusUnitAdded", OnFocusUnitRemoved = "OnFocusUnitRemoved", OnUpdate = "OnUpdate",
    WoWEvent = "Event",
  },
}

Addon.WIDGET_EVENTS = {
  IsEnabled = {
    FunctionExample = [[
-- Example for function IsEnabled:
function()
  -- Return false or nil, to disable the script, e.g., when it should be only active on a certain class
end]]
  },
  OnEnable = {
    FunctionExample = [[
-- Example for function OnEnable:
function()
  --
end]]
  },
  OnDisable = {
    FunctionExample = [[
-- Example for function OnDisable:
function()
  --
end]]
  },
  EnabledForStyle = {
    FunctionExample = [[
-- Example for function EnabledForStyle:
function(style_name, unit)
  -- return not (style == "NameOnly" or style == "NameOnly-Unique" or style == "etotem")
end]]
  },
  Create = {
    FunctionExample = [[
-- Example for function Create:
function(widget_frame)
  -- ...
end]]
  },
  UpdateFrame = {
    FunctionExample = [[
-- Example for function UpdateFrame:
function(widget_frame, unit)
  -- ...
end]]
  },
  UpdateSettings = {
    FunctionExample = [[
-- Example for function UpdateSettings:
function()
  -- ...
end]]
  },
  UpdateLayout = {
    FunctionExample = [[
-- Example for function UpdateLayout:
function(widget_frame)
  -- ...
end]]
  },
  OnUnitAdded = {
    FunctionExample = [[
-- Example for function OnUnitAdded:
function(widget_frame, unit)
  -- ...
end]]
  },
  OnUnitRemoved = {
    FunctionExample = [[
-- Example for function OnUnitRemoved:
function(widget_frame, unit)
  -- ...
end]]
  },
  OnTargetUnitAdded = {
    FunctionExample = [[
-- Example for function OnTargetUnitAdded:
function(widget_frame, unit)
  -- ...
end]]
  },
  OnTargetUnitRemoved = {
    FunctionExample = [[
-- Example for function OnTargetUnitRemoved:
function(widget_frame, unit)
  -- ...
end]]
  },
  OnFocusUnitAdded = {
    FunctionExample = [[
-- Example for function OnFocusUnitAdded:
function(widget_frame, unit)
  -- ...
end]]
  },
  OnFocusUnitRemoved = {
    FunctionExample = [[
-- Example for function OnFocusUnitRemoved:
function(widget_frame, unit)
  -- ...
end]]
  },
  OnUpdate = {
    FunctionExample = [[
-- Example for function OnUpdate (called every frame, not for a particular nameplate):
function(elapsed)
  -- ...
end]]
  },
  WoWEvent = {
    FunctionExample = [[
-- Example for processing a WoW event:
function(...)
  -- Do some event processing
end]]
  },
}

---------------------------------------------------------------------------------------------------
-- (Protected) environ for scripts
---------------------------------------------------------------------------------------------------

local ScriptEnvironmentByStyle = {}
--local CurrentScriptEnvironment

-- Blocked functions and tables for WoW or Lua - thanks to WeakAuras
local BlockedFunctions = {
  -- Lua functions that may allow breaking out of the environment

  -- Block run code inside code
  getfenv = true,
  setfenv = true,
  loadstring = true,
  pcall = true,
  xpcall = true,
  RunScript = true,
  securecall = true,
  DevTools_DumpCommand = true,
  ["getglobal"] = true,
  ["setmetatable"] = true,

  -- Block access to particular frames
  BankFrame	= true,
  TradeFrame = true,
  GuildBankFrame = true,
  MailFrame = true,
  EnumerateFrames = true,

  --Block guild commands
  GuildDisband = true,
  GuildUninvite = true,
  ["C_GuildInfo"] = { -- This should block everything of C_GuildInfo
    ["RemoveFromGuild"] = true,
  },

  -- Block mail, trades, action house, banks
  SendMail = true,
  SetTradeMoney = true,
  AddTradeMoney = true,
  PickupTradeMoney = true,
  PickupPlayerMoney = true,
  AcceptTrade = true,
  SetSendMailMoney = true,
  -- On Mainline, SetTradeMoney, AddTradeMoney, and PickupTradeMoney only exist in C_TradeInfo (the last
  -- global shim, PickupTradeMoney, was removed in Patch 12.1.5); the globals above stay blocked for
  -- clients that still have them
  ["C_TradeInfo"] = true,
  ["C_AuctionHouse"] 	= true,
  ["C_Bank"] = true,
  ["C_GuildBank"] = true,

  -- Avoid creating macros
  CreateMacro = true,
  EditMacro = true,
  hash_SlashCmdList = true,
  SetBindingMacro = true,

  -- Other things
  ["C_GMTicketInfo"] = true,
}

local BlockedTables = {
  SlashCmdList = true,
}

local OverwrittenFunctionsForScripts = {
  print = function(...) print (...) end,
  PlatesByUnit = Addon.PlatesByUnit,
  PlatesByGUID = Addon.PlatesByGUID,
}


local function WarningForBlockedAccess(key)
  Addon.Logging.Warning(string_format(L["Forbidden function or table called from script: %s"], key))
end

-- Scripts get a stand-in for a blocked function or table that does nothing but warn with the blocked name:
-- calling it (SendMail(...)), calling something read from it (C_TradeInfo.SetTradeMoney(...)) or writing to it.
-- Returning WarningForBlockedAccess itself instead made a script error out when it indexed a blocked table
-- ("attempt to index ... a function value") and logged the script's first call argument instead of the name.
local BlockedAccessProxies = {}

local function GetBlockedAccessProxy(key)
  local proxy = BlockedAccessProxies[key]
  if not proxy then
    local function Warn()
      WarningForBlockedAccess(key)
    end

    proxy = setmetatable({}, {
      __index = function() return Warn end,
      __newindex = Warn,
      __call = Warn,
      __metatable = false,
    })
    BlockedAccessProxies[key] = proxy
  end

  return proxy
end

local EnvironmentGetGlobal

--local ScriptEnvironment = setmetatable({},
--  {
--    __index = function(t, k)
--      if k == "_G" then
--        return t
--      elseif k == "getglobal" then
--        return EnvironmentGetGlobal
--      elseif k == "ScriptEnvironment" then
--        return CurrentScriptEnvironment
--      elseif BlockedFunctions[k] then
--        return WarningForBlockedAccess
--      elseif BlockedTables[k] then
--        return WarningForBlockedAccess(k)
--      elseif OverwrittenFunctionsForScripts[k] then
--        return OverwrittenFunctionsForScripts[k]
--      else
--        return _G[k]
--      end
--    end,
--    __newindex = function(table, key, value)
--      if _G[key] then
--        Addon.PrintMessage("Warning", string.format(L["The script has overwritten the global '%s', this might affect other scripts."], key))
--      end
--      rawset(table, key, value)
--    end,
--    __metatable = false,
--  })

local ScriptEnvironment =
  {
    __index = function(t, k)
      if k == "_G" then
        return t
      elseif k == "getglobal" then
        return EnvironmentGetGlobal
--      elseif k == "ScriptEnvironment" then
--        return CurrentScriptEnvironment
      elseif BlockedFunctions[k] or BlockedTables[k] then
        return GetBlockedAccessProxy(k)
      elseif OverwrittenFunctionsForScripts[k] then
        return OverwrittenFunctionsForScripts[k]
      else
        return _G[k]
      end
    end,
    __newindex = function(table, key, value)
      if _G[key] then
        Addon.Logging.Warning(string_format(L["A script has overwritten the global '%s'. This might affect other scripts."], key))
      end
      rawset(table, key, value)
    end,
    --__metatable = false,
  }

function EnvironmentGetGlobal(k)
  return ScriptEnvironment[k]
end

--function Addon.ActiveScriptEnvironment(custom_style)
--  local script_environment = ScriptEnvironmentByStyle[custom_style]
--
--  if not script_environment then
--    script_environment = {}
--    ScriptEnvironmentByStyle[custom_style] = script_environment
--  end
--
--  script_environment.Style = custom_style
--
--  CurrentScriptEnvironment = script_environment
--end

local function GetScriptEnvironment(custom_style)
  local script_environment = ScriptEnvironmentByStyle[custom_style]

  if not script_environment then
    script_environment = {
      ThreatPlates = {
        Environment = {
          Style = custom_style,
          Profile = Addon.db.profile
        },
        API = {
          v1 = {
            SetTextureForIcon = function(icon_id, icon_source)
              --local allow_types = { string = true, number = true, table = true}
              --if allow_types[type(icon_source)] then
              -- if type(icon_source) ~= "string" and type(icon_source) ~= "number" and type(icon_source) ~= "table" then
              --   Addon.Logging.Error(string_format(L["Error in custom style '%s': only numbers and strings are allowed as icon sources for function SetIcon."], Addon.CustomPlateGetHeaderName(custom_style)))
              --   return
              -- end

              if icon_id and icon_source then
                if type(icon_source) == "function" then
                  setfenv(icon_source, setmetatable({}, ScriptEnvironment))
                end
                Addon.IconTextures[icon_id] = icon_source
              end
            end,
          },          
          Data = {
            -- Not available on clients with Midnight's API surface (see Widgets/AurasWidgetMidnight.lua)
            CrowdControlAuras = Addon.Widgets.Widgets.Auras.CROWD_CONTROL_SPELLS or {},
            -- Totems = Addon.Data.Totems
          },
          --Init = {
          --  InitTotemData = Addon.InitializeTotemInformation -- Not sure if this works ...
          --},
          Logging = {
            Info = Addon.Logging.Info,
            Warning = Addon.Logging.Warning,
            Error = Addon.Logging.Error,
            Debug = Addon.Logging.Debug,
          },
          Widgets = {
            CreateStatusBar = Addon.CreateStatusbar,
            -- CreateText = Addon.CreateText,
          },
          --Util = {
            -- HEX2RGB
            -- CopyTable
            -- MergeIntoTable
            -- PrintTable
          --},
          --Debug = {}
          -- LibCustomGlow?
        },
      }
    }
    ScriptEnvironmentByStyle[custom_style] = script_environment
  end

  setmetatable(script_environment, ScriptEnvironment)

  return script_environment
end

-- The difference between these two is that script-triggered custom styles are used on all nameplates
-- while custom styles with no script trigger are only used on nameplates that match the custom style's
-- trigger
local ScriptsByCustomStyle = {}
local ScriptsForAllPlates = {}

local InitializedPlatesByStyle = {}
local EnabledForStyle = {}

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

-- Functions that are not called for a particular nameplate: they are called for all custom styles with scripts,
-- not only for the custom style of a unit
local SCRIPT_FUNCTIONS_WITHOUT_UNIT = {
  IsEnabled = true,
  OnEnable = true,
  OnDisable = true,
  OnUpdate = true,
}

-- arg1 can be nil, widget_frame or style, depending on the event processed
local function ProcessEvent(event, widget_frame, unit)
  local func

  --print("ProcessEvent:", event, unit and unit.CustomPlateSettings or "nil")

  if SCRIPT_FUNCTIONS_WITHOUT_UNIT[event] then
    for custom_style, funcs_by_event in pairs(ScriptsByCustomStyle) do
      func = funcs_by_event[event]
      if func then
        local call_ok, return_value = pcall(func, widget_frame)
        if not call_ok then
          Addon.Logging.Error(string_format(L["Error in event script '%s' of custom style '%s': %s"], event, Addon.CustomPlateGetHeaderName(custom_style), return_value))
        end
      end
    end
  -- unit might be nil, e.g., when ProcessEvent is called for Create
  elseif unit then
    local custom_style = unit.CustomPlateSettings

    if custom_style and ScriptsByCustomStyle[custom_style] then
      if event ~= "OnUnitAdded" or EnabledForStyle[custom_style][unit.unitid] then
        func = ScriptsByCustomStyle[custom_style][event]
        if func then
          --print ("Process Custom Style:", custom_style.Trigger.Type, custom_style.Trigger[custom_style.Trigger.Type].Input, event)
          local call_ok, return_value = pcall(func, widget_frame, unit)
          if not call_ok then
            Addon.Logging.Error(string_format(L["Error in event script '%s' of custom style '%s': %s"], event, Addon.CustomPlateGetHeaderName(custom_style), return_value))
          end
        end
      end
    end
  end

  for custom_style, _ in pairs(ScriptsForAllPlates) do
    if event ~= "OnUnitAdded" or EnabledForStyle[custom_style][unit.unitid] then
      local func = ScriptsForAllPlates[custom_style][event]
      if func then
        --print ("Process Script Trigger:", event, widget_frame, unit)
        local call_ok, return_value = pcall(func, widget_frame, unit)
        if not call_ok then
          Addon.Logging.Error(string_format(L["Error in event script '%s' of custom style '%s': %s"], event, Addon.CustomPlateGetHeaderName(custom_style), return_value))
        end
      end
    end
  end
end

local OnUpdateHandler = CreateFrame("Frame", "ThreatPlatesScriptOnUpdateHandler", UIParent)

local function OnUpdate(_, elapsed)
  ProcessEvent("OnUpdate", elapsed)
end

function Widget:IsEnabled()
  local is_enabled = Addon.ActiveScriptTrigger and Addon.db.global.ScriptingIsEnabled

  if is_enabled then
    ProcessEvent("IsEnabled")
  end

  return is_enabled
end

function Widget:OnEnable()
  -- Target and focus scripts must also be called when the (soft) target or focus changes
  self:SubscribeEvent("TargetGained")
  self:SubscribeEvent("TargetLost")
  self:SubscribeEvent("FocusGained")
  self:SubscribeEvent("FocusLost")

  ProcessEvent("OnEnable")
end

function Widget:OnDisable()
  for _, custom_style in ipairs(Addon.Cache.CustomPlateTriggers.Script) do
    for event, _ in pairs(custom_style.Scripts.Code.Events) do
      --print ("Unregistering:", event)
      self:UnsubscribeEvent(event)
    end
  end

  self:UnsubscribeEvent("TargetGained")
  self:UnsubscribeEvent("TargetLost")
  self:UnsubscribeEvent("FocusGained")
  self:UnsubscribeEvent("FocusLost")

  -- Target and focus scripts must be called again once the widget is enabled again
  for _, tp_frame in pairs(Addon.PlatesCreated) do
    local widget_frame = tp_frame.widgets and tp_frame.widgets[self.Name]
    if widget_frame then
      widget_frame.TargetScriptsActive = nil
      widget_frame.FocusScriptsActive = nil
    end
  end

  ProcessEvent("OnDisable")
end

function Widget:EnabledForStyle(style, unit)
  local func

  --print("ProcessEvent:", "EnabledForStyle", unit and unit.CustomPlateSettings or "nil")

  -- Don't process the event if the custom style is not enabled for this the current style:
  -- OnUnitAdded => widget_frame.Active
  -- Store Ative / EnabledForStyle for each custom style => EnabledForStyleByCustomStyle

  local custom_style = unit.CustomPlateSettings
  if custom_style and ScriptsByCustomStyle[custom_style] then
    func = ScriptsByCustomStyle[custom_style].EnabledForStyle
    if func then
      --print ("Process Custom Style:", custom_style.Trigger.Type, custom_style.Trigger[custom_style.Trigger.Type].Input, "EnabledForStyle")
      local call_ok, return_value = pcall(func, style, unit)
      if call_ok then
        EnabledForStyle[custom_style][unit.unitid] = return_value == true
      else
        Addon.Logging.Error(string_format(L["Error in event script '%s' of custom style '%s': %s"], "EnabledForStyle", Addon.CustomPlateGetHeaderName(custom_style), return_value))
        EnabledForStyle[custom_style][unit.unitid] = false
      end
    else
      EnabledForStyle[custom_style][unit.unitid] = true
    end
  end

  for custom_style, _ in pairs(ScriptsForAllPlates) do
    local func = ScriptsForAllPlates[custom_style].EnabledForStyle
    if func then
      --print ("Process Script Trigger: EnabledForStyle", style, unit)
      local call_ok, return_value = pcall(func, style, unit)
      if call_ok then
        EnabledForStyle[custom_style][unit.unitid] = return_value == true
      else
        Addon.Logging.Error(string_format(L["Error in event script '%s' of custom style '%s': %s"], "EnabledForStyle", Addon.CustomPlateGetHeaderName(custom_style), return_value))
        EnabledForStyle[custom_style][unit.unitid] = false
      end
    else
      EnabledForStyle[custom_style][unit.unitid] = true
    end
  end

  return true
end

-- Calls the Create script of a custom style once for a widget frame. A widget frame is only marked as initialized
-- if the custom style has a Create script, so that a Create script added later (or a custom style created after the
-- nameplate) is still called for already existing nameplates.
local function CallCreateScript(custom_style, funcs_by_event, widget_frame)
  local func = funcs_by_event and funcs_by_event.Create
  if not func then return end

  local custom_style_init = InitializedPlatesByStyle[custom_style] or {}
  InitializedPlatesByStyle[custom_style] = custom_style_init

  if not custom_style_init[widget_frame] then
    custom_style_init[widget_frame] = true

    local call_ok, return_value = pcall(func, widget_frame)
    if not call_ok then
      Addon.Logging.Error(string_format(L["Error in event script '%s' of custom style '%s': %s"], "Create", Addon.CustomPlateGetHeaderName(custom_style), return_value))
    end
  end
end

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)

  -- Custom Code
  --------------------------------------
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel())
  widget_frame:SetAllPoints(tp_frame)
  widget_frame:Hide()

  for custom_style, funcs_by_event in pairs(ScriptsForAllPlates) do
    CallCreateScript(custom_style, funcs_by_event, widget_frame)
  end
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

-- Widget frames can already exist when a custom style or its Create script is added, so Create is (also) called
-- here before any other script of the custom style processes the nameplate
local function InitializeScripts(widget_frame, unit)
  for custom_style, funcs_by_event in pairs(ScriptsForAllPlates) do
    CallCreateScript(custom_style, funcs_by_event, widget_frame)
  end

  local custom_style = unit.CustomPlateSettings
  if custom_style then
    CallCreateScript(custom_style, ScriptsByCustomStyle[custom_style], widget_frame)
  end
end

-- Target and focus scripts are called when a nameplate becomes or is no longer the (soft) target/focus, either
-- when the target/focus changes (TargetGained, ...) or when the nameplate is (re-)initialized (OnUnitAdded,
-- OnUnitRemoved). The widget frame remembers if the Added script was called, so that each script is called only
-- once per change.
local function UpdateTargetScripts(widget_frame, unit, is_target)
  if is_target and not widget_frame.TargetScriptsActive then
    widget_frame.TargetScriptsActive = true
    ProcessEvent("OnTargetUnitAdded", widget_frame, unit)
  elseif not is_target and widget_frame.TargetScriptsActive then
    widget_frame.TargetScriptsActive = false
    ProcessEvent("OnTargetUnitRemoved", widget_frame, unit)
  end
end

local function UpdateFocusScripts(widget_frame, unit, is_focus)
  if is_focus and not widget_frame.FocusScriptsActive then
    widget_frame.FocusScriptsActive = true
    ProcessEvent("OnFocusUnitAdded", widget_frame, unit)
  elseif not is_focus and widget_frame.FocusScriptsActive then
    widget_frame.FocusScriptsActive = false
    ProcessEvent("OnFocusUnitRemoved", widget_frame, unit)
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  InitializeScripts(widget_frame, unit)
  ProcessEvent("OnUnitAdded", widget_frame, unit)

  UpdateTargetScripts(widget_frame, unit, unit.IsSoftTarget)
  UpdateFocusScripts(widget_frame, unit, unit.IsFocus)

  --widget_frame:Show()
  widget_frame:SetShown(unit.CustomPlateSettings or next(ScriptsForAllPlates))
end

function Widget:OnUnitRemoved(widget_frame, unit)
  ProcessEvent("OnUnitRemoved", widget_frame, unit)

  UpdateTargetScripts(widget_frame, unit, false)
  UpdateFocusScripts(widget_frame, unit, false)

  --widget_frame:SetShown(unit.CustomPlateSettings or next(ScriptsForAllPlates))
end

local function GetActiveWidgetFrame(tp_frame)
  local widget_frame = tp_frame.widgets and tp_frame.widgets[Widget.Name]
  return widget_frame and widget_frame.Active and widget_frame
end

function Widget:TargetGained(tp_frame)
  local widget_frame = GetActiveWidgetFrame(tp_frame)
  if widget_frame then
    UpdateTargetScripts(widget_frame, tp_frame.unit, true)
  end
end

function Widget:TargetLost(tp_frame)
  local widget_frame = GetActiveWidgetFrame(tp_frame)
  if widget_frame then
    -- Another (soft) target meta unit might still point to this unit
    UpdateTargetScripts(widget_frame, tp_frame.unit, tp_frame.unit.IsSoftTarget)
  end
end

function Widget:FocusGained(tp_frame)
  local widget_frame = GetActiveWidgetFrame(tp_frame)
  if widget_frame then
    UpdateFocusScripts(widget_frame, tp_frame.unit, true)
  end
end

function Widget:FocusLost(tp_frame)
  local widget_frame = GetActiveWidgetFrame(tp_frame)
  if widget_frame then
    UpdateFocusScripts(widget_frame, tp_frame.unit, false)
  end
end

function Widget:UpdateFrame(widget_frame, unit)
  ProcessEvent("UpdateFrame", widget_frame, unit)
end

function Widget:UpdateLayout(widget_frame)
  -- UpdateLayout runs before OnUnitAdded after a settings change, so Create of script-triggered custom styles
  -- added since the widget frame was created must be called here first
  for custom_style, funcs_by_event in pairs(ScriptsForAllPlates) do
    CallCreateScript(custom_style, funcs_by_event, widget_frame)
  end

  -- unit is passed so that the script of the unit's custom style is called too, but only if its Create script
  -- (if it has one) was already called for this widget frame
  local unit = widget_frame.unit
  local custom_style = unit and unit.CustomPlateSettings
  local funcs_by_event = custom_style and ScriptsByCustomStyle[custom_style]
  local is_initialized = funcs_by_event and (not funcs_by_event.Create or
    (InitializedPlatesByStyle[custom_style] and InitializedPlatesByStyle[custom_style][widget_frame]))
  ProcessEvent("UpdateLayout", widget_frame, is_initialized and unit or nil)
end

local ScriptsForWoWEvents = {}

local function HandleWoWEvent(event, ...)
  local custom_styles = ScriptsForWoWEvents[event]
  if custom_styles then
    for custom_style, func in pairs(custom_styles) do
      local call_ok, error_message = pcall(func, ...)
      if not call_ok then
        Addon.Logging.Error(string_format(L["Error in event script '%s' of custom style '%s': %s"], event, Addon.CustomPlateGetHeaderName(custom_style), error_message))
      end
    end
  end
end

-- Load settings from the configuration which are shared across all aura widgets
-- used (for each widget) in UpdateWidgetConfig
function Widget:UpdateSettings()
  self.CustomStyles = Addon.db.profile.uniqueSettings

  ScriptsForAllPlates = {}
  ScriptsByCustomStyle = {}
  ScriptsForWoWEvents = {}
  EnabledForStyle = {}

  if not self:IsEnabled() then return end

  local on_update_script_used = false

  for i, custom_style in ipairs(Addon.Cache.CustomPlateTriggers.Script) do
    --Addon.Logging.Debug("Reloading Script Style:", i, "=>", Addon.CustomPlateGetHeaderName(custom_style))
    EnabledForStyle[custom_style] = EnabledForStyle[custom_style] or {}

    -- Register scripting events
    for event, script in pairs(custom_style.Scripts.Code.Functions) do
      --Addon.Logging.Debug("=> Event:", event)
      -- Don't add OnUnitAdded for target/focus-based scripts
      if script and script ~= "" and Addon.SCRIPT_FUNCTIONS[custom_style.Scripts.Type][event] then
        local func = Addon.LoadScript(script, custom_style, event)
        if func then
          if custom_style.Trigger.Type == "Script" then
            ScriptsForAllPlates[custom_style] = ScriptsForAllPlates[custom_style] or {}
            ScriptsForAllPlates[custom_style][event] = func
          else
            ScriptsByCustomStyle[custom_style] = ScriptsByCustomStyle[custom_style] or {}
            ScriptsByCustomStyle[custom_style][event] = func
          end

          on_update_script_used = on_update_script_used or event == "OnUpdate"
        end
      end
    end

    -- Register WoW events
    for event, script in pairs(custom_style.Scripts.Code.Events) do
      --Addon.Logging.Debug("=> WoW Event:", event)
      if script and script ~= "" then
        local func = Addon.LoadScript(script, custom_style, event)
        if func then
          ScriptsForWoWEvents[event] = ScriptsForWoWEvents[event] or {}
          ScriptsForWoWEvents[event][custom_style] = func
          -- EventService calls a function subscriber with the event's payload only, without the event name
          if not pcall(self.SubscribeEvent, self, event, function(...) HandleWoWEvent(event, ...) end) then
            Addon.Logging.Error(string_format(L["Attempt to register script for unknown WoW event \"%s\""], event))
          end
        end
      end
    end
  end

  for custom_style, funcs_by_event in pairs(ScriptsForAllPlates) do
    --Addon.Logging.Debug("All Plates:", Addon.CustomPlateGetHeaderName(custom_style))

    -- Only load enabled scripts
    local script_is_enabled = true
    local func = funcs_by_event.IsEnabled
    if func then
      local call_ok, return_value = pcall(func)
      if call_ok then
        script_is_enabled = return_value
      else
        Addon.Logging.Error(string_format(L["Error in event script '%s' of custom style '%s': %s"], "IsEnabled", Addon.CustomPlateGetHeaderName(custom_style), return_value))
        script_is_enabled = false
      end
    end

    --Addon.Logging.Debug("  =>", (script_is_enabled and "Enabled") or "Disabled")

    if script_is_enabled then
      local func = funcs_by_event.UpdateSettings
      if func then
        local call_ok, return_value = pcall(func)
        if not call_ok then
          Addon.Logging.Error(string_format(L["Error in event script '%s' of custom style '%s': %s"], "UpdateSettings", Addon.CustomPlateGetHeaderName(custom_style), return_value))
        end
      end
    else
      ScriptsForAllPlates[custom_style] = nil
    end
  end

  for custom_style, funcs_by_event in pairs(ScriptsByCustomStyle) do
    --Addon.Logging.Debug ("By Custom Style Plates:", Addon.CustomPlateGetHeaderName(custom_style))

    -- Only load enabled scripts
    local script_is_enabled = true
    local func = funcs_by_event.IsEnabled
    if func then
      local call_ok, return_value = pcall(func)
      if call_ok then
        script_is_enabled = return_value
      else
        Addon.Logging.Error(string_format(L["Error in event script '%s' of custom style '%s': %s"], "IsEnabled", Addon.CustomPlateGetHeaderName(custom_style), return_value))
        script_is_enabled = false
      end
    end

    --Addon.Logging.Debug("  =>", (script_is_enabled and "Enabled") or "Disabled")

    if script_is_enabled then
      func = funcs_by_event.UpdateSettings
      if func then
        local call_ok, error_message = pcall(func)
        if not call_ok then
          Addon.Logging.Error(string_format(L["Error in event script '%s' of custom style '%s': %s"], "UpdateSettings", Addon.CustomPlateGetHeaderName(custom_style), error_message))
        end
      end
    else
      ScriptsByCustomStyle[custom_style] = nil
    end
  end

  if on_update_script_used then
    --Addon.Logging.Debug("Enabling OnUpdate handling.")
    OnUpdateHandler:SetScript("OnUpdate", OnUpdate)
  else
    --Addon.Logging.Debug("Disabling OnUpdate handling.")
    OnUpdateHandler:SetScript("OnUpdate", nil)
  end
end

local ScriptFunctionCache = {}

function Addon.LoadScript(script_code, custom_style, event)
  --Addon.Logging.Debug("Loading Script:", event)

  local script_func = ScriptFunctionCache[script_code]
  if script_func then
    return script_func
  else
    --local info_header = "--[==[ Error in event script '" .. event .. "' of custom style '" .. (Addon.CustomPlateGetHeaderName(custom_style)) .. "' ]==] "
    local loaded_func, error_message = loadstring("return " .. script_code)
    if not loaded_func then
      Addon.Logging.Error(string_format(L["Syntax error in event script '%s' of custom style '%s': %s"], event, Addon.CustomPlateGetHeaderName(custom_style), error_message))
    else
      setfenv(loaded_func, GetScriptEnvironment(custom_style))

      local call_ok, func = pcall(assert(loaded_func))
      if call_ok then
        ScriptFunctionCache[script_code] = func
        return func
      end
    end
  end
end