---------------------
-- Widget Handling --
---------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs = pairs
local next = next

-- WoW APIs

-- ThreatPlates APIs
local DEBUG = ThreatPlates.DEBUG

ThreatPlatesWidgets = {}

---------------------------------------------------------------------------------------------------
-- Event handling stuff
---------------------------------------------------------------------------------------------------
local EventHandlerFrame = CreateFrame("Frame", nil, WorldFrame )
local RegisteredEventsByModule = {}

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

EventHandlerFrame:SetScript("OnEvent", EventHandler)

local function RegisterEvent(module, event, func)
  if not RegisteredEventsByModule[event] then
    RegisteredEventsByModule[event] = {}
  end

  RegisteredEventsByModule[event][module] = func or true

  EventHandlerFrame:RegisterEvent(event)
end

local function UnregisterEvent(module, event)
  if RegisteredEventsByModule[event] then
    RegisteredEventsByModule[event][module] = nil

    if next(RegisteredEventsByModule[event]) == nil then -- last registered module removed?
      EventHandlerFrame:UnregisterEvent(event)
    end
  end
end

local function UnregisterAllEvents(module)
  for event, _ in pairs(RegisteredEventsByModule) do
    UnregisterEvent(module, event)
  end
end

---------------------------------------------------------------------------------------------------
-- Helper functions for modules
---------------------------------------------------------------------------------------------------

local function UpdateAllFrames(module)
  for plate, _ in pairs(Addon.PlatesVisible) do
    local tp_frame = plate.TPFrame

    if module:EnabledForStyle(tp_frame.stylename, tp_frame.unit) and tp_frame.stylename ~= "empty" then
      module:UpdateFrame(tp_frame.widgets[module.Name], tp_frame.unit)
    end
  end
end

local function UpdateAllFramesAndNameplateColor(module)
  for plate, _ in pairs(Addon.PlatesVisible) do
    local tp_frame = plate.TPFrame

    if module:EnabledForStyle(tp_frame.stylename, tp_frame.unit) and tp_frame.stylename ~= "empty" then
      module:UpdateFrame(tp_frame.widgets[module.Name], tp_frame.unit)

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
local Modules = {}
local EnabledModules = {}

function Addon:NewModule(module_name)
  local module = {
    Name = module_name,
    RegisterEvent = RegisterEvent,
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
    if tp_frame.Active and module:EnabledForStyle(tp_frame.stylename, tp_frame.unit) then
      module:OnUnitAdded(plate_widgets[module_name], tp_frame.unit)
    else
      plate_widgets[module_name]:Hide()
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
    -- I think it could happen that a nameplate was created, then a module is enabled, and afterwise the unit is
    -- added to the nameplate, i.e., InitializedModules is called.
    --    if plate_widgets[module_name] == nil then
    --      TidyPlatesThreat.db.global.Unit = tp_frame
    --    end
    --    assert (plate_widgets[module_name] ~= nil, "Uninitialized module found: " .. module_name .. " for unit " .. unit.name .. " (" .. tp_frame:GetName() .. ")")

    local widget_frame = plate_widgets[module_name]
    widget_frame.unit = unit

    if module:EnabledForStyle(tp_frame.stylename, unit) and tp_frame.stylename ~= "empty" then
      module:OnUnitAdded(widget_frame, unit)
    else
      tp_frame.widgets[module_name]:Hide()
    end
  end
end

function Addon:ModulesOnUpdate(tp_frame, unit)
  local plate_widgets = tp_frame.widgets

  for module_name, module in pairs(EnabledModules) do
    if module:EnabledForStyle(tp_frame.stylename, unit) and module.UpdateFrame and tp_frame.stylename ~= "empty" then
      module:UpdateFrame(plate_widgets[module_name], unit)
    else
      plate_widgets[module_name]:Hide()
    end
  end
end

function Addon:ModulesOnUpdateStyle(tp_frame, unit)
  local plate_widgets = tp_frame.widgets

  for module_name, module in pairs(EnabledModules) do
    if module:EnabledForStyle(tp_frame.stylename, unit) and tp_frame.stylename ~= "empty" then
      if module.UpdateFrame then
        module:UpdateFrame(plate_widgets[module_name], unit)
      end
      -- if module.UpdateStyle then
      --   module:UpdateStyle(plate_widgets[module_name], unit)
      -- end
    else
      plate_widgets[module_name]:Hide()
    end
  end
end

-- TODO: Optimize this by storing (at registration) which modules want to process TargetChanged
function Addon:ModulesOnTargetChanged(tp_frame)
  local plate_widgets = tp_frame.widgets

  for module_name, module in pairs(EnabledModules) do
    if module:EnabledForStyle(tp_frame.stylename, tp_frame.unit) and tp_frame.stylename ~= "empty" then
      if module.OnTargetChanged then
        module:OnTargetChanged(plate_widgets[module_name], tp_frame.unit)
      end
    else
      plate_widgets[module_name]:Hide()
    end
  end
end