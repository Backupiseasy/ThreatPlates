---------------------
-- Widget Handling --
---------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs, next = pairs, next

-- WoW APIs

-- ThreatPlates APIs
ThreatPlatesWidgets = {}
local Modules = {}
local EnabledModules = {}
local RegisteredEventsByModule = {}

---------------------------------------------------------------------------------------------------
-- Event handling stuff
---------------------------------------------------------------------------------------------------
local function EventHandler(self, event, ...)
  local modules = RegisteredEventsByModule[event]

  if modules then
    for module, func in pairs(modules) do
      if func == true then
        module[event](module, ...)
      else
        func(event, ...)
      end
    end
  end
end

local function UnitEventHandler(self, event, ...)
  local module = self.Module
  local func = module.RegistedUnitEvents[event]

  if func == true then
    module[event](module, ...)
  else
    func(event, ...)
  end
end

local EventHandlerFrame = CreateFrame("Frame", nil, WorldFrame)
EventHandlerFrame:SetScript("OnEvent", EventHandler)

local function RegisterEvent(module, event, func)
  if not RegisteredEventsByModule[event] then
    RegisteredEventsByModule[event] = {}
  end

  RegisteredEventsByModule[event][module] = func or true
  EventHandlerFrame:RegisterEvent(event)
end

local function RegisterUnitEvent(module, event, unitid, func)
  if not module.EventHandlerFrame then
    module.EventHandlerFrame = CreateFrame("Frame", nil, WorldFrame)
    module.EventHandlerFrame.Module = module
    module.EventHandlerFrame:SetScript("OnEvent", UnitEventHandler)
  end

  module.RegistedUnitEvents[event] = func or true
  module.EventHandlerFrame:RegisterUnitEvent(event, unitid)
end

local function UnregisterEvent(module, event)
  if RegisteredEventsByModule[event] then
    RegisteredEventsByModule[event][module] = nil

    if next(RegisteredEventsByModule[event]) == nil then -- last registered module removed?
      EventHandlerFrame:UnregisterEvent(event)
    end
  end

  if module.EventHandlerFrame then
    module.EventHandlerFrame:UnregisterEvent(event)
    module.RegistedUnitEvents[event] = nil
  end
end

local function UnregisterAllEvents(module)
  for event, _ in pairs(RegisteredEventsByModule) do
    UnregisterEvent(module, event)
  end

  -- Also remove all remaining registered unit events (that are not in RegisteredEventsByModule)
  for event, _ in pairs(module.RegistedUnitEvents) do
    module.EventHandlerFrame:UnregisterEvent(event)
  end
  module.RegistedUnitEvents = {}
end

---------------------------------------------------------------------------------------------------
-- Helper functions for modules
---------------------------------------------------------------------------------------------------

local function UpdateAllFrames(module)
  for plate, _ in pairs(Addon.PlatesVisible) do
    local tp_frame = plate.TPFrame

    local widget_frame = tp_frame.widgets[module.Name]
    if widget_frame.Active then
      module:UpdateFrame(widget_frame, tp_frame.unit)
    end
  end
end

local function UpdateAllFramesAndNameplateColor(module)
  for plate, _ in pairs(Addon.PlatesVisible) do
    local tp_frame = plate.TPFrame

    local widget_frame = tp_frame.widgets[module.Name]
    if widget_frame.Active then
      module:UpdateFrame(widget_frame, tp_frame.unit)

      -- Also update healthbar and name color
      Addon:UpdateIndicatorNameplateColor(tp_frame)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Module creation and handling
-- Required functions are:
--   * Create
--   * IsEnabled
--   * EnabledForStyle
--   * OnUnitAdded
-- Optional funcations are:
--   * OnEnable
--   * OnDisable
--   * OnTargetChanged
--   * UpdateFrame (if UpdateAllFrames is used)
---------------------------------------------------------------------------------------------------
function Addon:NewModule(module_name)
  local module = {
    Name = module_name,
    RegistedUnitEvents = {},
    RegisterEvent = RegisterEvent,
    RegisterUnitEvent = RegisterUnitEvent,
    UnregisterEvent = UnregisterEvent,
    UnregisterAllEvents = UnregisterAllEvents,
    UpdateAllFrames = UpdateAllFrames,
    UpdateAllFramesAndNameplateColor = UpdateAllFramesAndNameplateColor,
  }

  Modules[module_name] = module

  return module
end

function Addon:InitializeModule(module_name)
  local module = Modules[module_name]

  if module:IsEnabled() then
    Addon:EnableModule(module_name)
  else
    Addon:DisableModule(module_name)
  end
end

function Addon:UpdateSettingsForModule(module_name)
  local module = Modules[module_name]

  for plate, _ in pairs(Addon.PlatesVisible) do
    module:UpdateSettings(plate.TPFrame.widgets[module_name])
  end
end

function Addon:InitializeAllModules()
  for module_name, _ in pairs(Modules) do
    Addon:InitializeModule(module_name)
  end
end

function Addon:EnableModule(module_name)
   local module = Modules[module_name]

  EnabledModules[module_name] = module


  -- Nameplates are re-used by WoW, so we cannot iterate just over all visible plates, but must
  -- add the new module to all existing plates, even if they are currently not visible
  for _, tp_frame in pairs(Addon.PlatesCreated) do
    local plate_widgets = tp_frame.widgets

    if not plate_widgets[module_name] then
      plate_widgets[module_name] = module:Create(tp_frame)
    end

    -- As we are iterating over all plates created, even if no unit is assigned to it currently, we have
    -- to skip plates without units. OnUnitAdded will be called on them anyway
    if tp_frame.Active then
      local widget_frame = plate_widgets[module_name]

      widget_frame.Active = tp_frame.stylename ~= "empty" and module:EnabledForStyle(tp_frame.stylename, tp_frame.unit)
      widget_frame.unit = tp_frame.unit

      if widget_frame.Active then
        module:OnUnitAdded(widget_frame, tp_frame.unit)
      else
        widget_frame:Hide()
      end
    end
  end

  -- As events are registered in OnEnable, this must be done after all widget frames are created, otherwise an registered event
  -- may already occur before the widget frame exists.
  if module.OnEnable then
    module:OnEnable()
  end
end

function Addon:DisableModule(module_name)
  local module = EnabledModules[module_name]

  if module then
    if module.OnDisable then
      module:OnDisable()
    end

    -- Disable all events of the module
    module:UnregisterAllEvents()

    -- for all plates - hide the widget frame (alternatively: remove the widget frame)
    for plate, _ in pairs(Addon.PlatesVisible) do
      plate.TPFrame.widgets[module_name]:Hide()
    end
  end
end

function Addon:CreateModules(tp_frame)
  local plate_widgets = tp_frame.widgets

  for module_name, module in pairs(EnabledModules) do
    plate_widgets[module_name] = module:Create(tp_frame)
  end
end

-- TODO: Seperate UnitAdded from UpdateSettings/UpdateConfiguration (unit independent stuff)
--       Maybe event seperate style dependedt stuff (PlateStyleChanged)
function Addon:ModulesOnUnitAdded(tp_frame, unit)
  local plate_widgets = tp_frame.widgets

  for module_name, module in pairs(EnabledModules) do
    local widget_frame = plate_widgets[module_name]

    -- I think it could happen that a nameplate was created, then a module is enabled, and afterwise the unit is
    -- added to the nameplate, i.e., InitializedModules is called.
    --    if plate_widgets[module_name] == nil then
    --      TidyPlatesThreat.db.global.Unit = tp_frame
    --    end
    --    assert (plate_widgets[module_name] ~= nil, "Uninitialized module found: " .. module_name .. " for unit " .. unit.name .. " (" .. tp_frame:GetName() .. ")")

    widget_frame.Active = tp_frame.stylename ~= "empty" and module:EnabledForStyle(tp_frame.stylename, unit)
    widget_frame.unit = unit

    if widget_frame.Active then
      module:OnUnitAdded(widget_frame, unit)
    else
      widget_frame:Hide()
    end
  end
end

--function Addon:ModulesOnUpdate(tp_frame, unit)
--  local plate_widgets = tp_frame.widgets
--
--  for module_name, module in pairs(EnabledModules) do
--    local widget_frame = plate_widgets[module_name]
--
--    if widget_frame.Active then
--      if module.UpdateFrame then
--        module:UpdateFrame(widget_frame, unit)
--      end
--    else
--      widget_frame:Hide()
--    end
--  end
--end

function Addon:ModulesPlateModeChanged(tp_frame, unit)
  local plate_widgets = tp_frame.widgets

  for module_name, module in pairs(EnabledModules) do
    local widget_frame = plate_widgets[module_name]

    widget_frame.Active = tp_frame.stylename ~= "empty" and module:EnabledForStyle(tp_frame.stylename, unit)

    if widget_frame.Active then
      --if module.OnUpdatePlateMode then
      --  module:OnUpdatePlateMode(plate_widgets[module_name], unit)
      --end
      module:OnUnitAdded(widget_frame, unit)
    else
      widget_frame:Hide()
    end
  end
end

--function Addon:ModulesOnTargetChanged(tp_frame)
--  local plate_widgets = tp_frame.widgets
--
--  for module_name, module in pairs(EnabledModules) do
--    local widget_frame = plate_widgets[module_name]
--
--    if widget_frame.Active then
--      if module.OnTargetChanged then
--        module:OnTargetChanged(plate_widgets[module_name], tp_frame.unit)
--      end
--    else
--      plate_widgets[module_name]:Hide()
--    end
--  end
--end