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
local Widgets = {}
local EnabledWidgets = {}
local RegisteredEventsByWidget = {}

---------------------------------------------------------------------------------------------------
-- Event handling stuff
---------------------------------------------------------------------------------------------------
local function EventHandler(self, event, ...)
  local widgets = RegisteredEventsByWidget[event]

  if widgets then
    for widget, func in pairs(widgets) do
      if func == true then
        widget[event](widget, ...)
      else
        func(event, ...)
      end
    end
  end
end

local function UnitEventHandler(self, event, ...)
  local widget = self.Widget
  local func = widget.RegistedUnitEvents[event]

  if func == true then
    widget[event](widget, ...)
  else
    func(event, ...)
  end
end

local EventHandlerFrame = CreateFrame("Frame", nil, WorldFrame)
EventHandlerFrame:SetScript("OnEvent", EventHandler)

local function RegisterEvent(widget, event, func)
  if not RegisteredEventsByWidget[event] then
    RegisteredEventsByWidget[event] = {}
  end

  RegisteredEventsByWidget[event][widget] = func or true
  EventHandlerFrame:RegisterEvent(event)
end

local function RegisterUnitEvent(widget, event, unitid, func)
  if not widget.EventHandlerFrame then
    widget.EventHandlerFrame = CreateFrame("Frame", nil, WorldFrame)
    widget.EventHandlerFrame.Widget = widget
    widget.EventHandlerFrame:SetScript("OnEvent", UnitEventHandler)
  end

  widget.RegistedUnitEvents[event] = func or true
  widget.EventHandlerFrame:RegisterUnitEvent(event, unitid)
end

local function UnregisterEvent(widget, event)
  if RegisteredEventsByWidget[event] then
    RegisteredEventsByWidget[event][widget] = nil

    if next(RegisteredEventsByWidget[event]) == nil then -- last registered widget removed?
      EventHandlerFrame:UnregisterEvent(event)
    end
  end

  if widget.EventHandlerFrame then
    widget.EventHandlerFrame:UnregisterEvent(event)
    widget.RegistedUnitEvents[event] = nil
  end
end

local function UnregisterAllEvents(widget)
  for event, _ in pairs(RegisteredEventsByWidget) do
    UnregisterEvent(widget, event)
  end

  -- Also remove all remaining registered unit events (that are not in RegisteredEventsByWidget)
  for event, _ in pairs(widget.RegistedUnitEvents) do
    widget.EventHandlerFrame:UnregisterEvent(event)
  end
  widget.RegistedUnitEvents = {}
end

---------------------------------------------------------------------------------------------------
-- Helper functions for widgets
---------------------------------------------------------------------------------------------------

local function UpdateAllFrames(widget)
  for plate, _ in pairs(Addon.PlatesVisible) do
    local tp_frame = plate.TPFrame

    local widget_frame = tp_frame.widgets[widget.Name]
    if widget_frame.Active then
      widget:UpdateFrame(widget_frame, tp_frame.unit)
    end
  end
end

local function UpdateAllFramesAndNameplateColor(widget)
  for plate, _ in pairs(Addon.PlatesVisible) do
    local tp_frame = plate.TPFrame

    local widget_frame = tp_frame.widgets[widget.Name]
    if widget_frame.Active then
      widget:UpdateFrame(widget_frame, tp_frame.unit)

      -- Also update healthbar and name color
      Addon:UpdateIndicatorNameplateColor(tp_frame)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Widget creation and handling
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
function Addon:NewWidget(widget_name)
  local widget = {
    Name = widget_name,
    RegistedUnitEvents = {},
    RegisterEvent = RegisterEvent,
    RegisterUnitEvent = RegisterUnitEvent,
    UnregisterEvent = UnregisterEvent,
    UnregisterAllEvents = UnregisterAllEvents,
    UpdateAllFrames = UpdateAllFrames,
    UpdateAllFramesAndNameplateColor = UpdateAllFramesAndNameplateColor,
  }

  Widgets[widget_name] = widget

  return widget
end

function Addon:InitializeWidget(widget_name)
  local widget = Widgets[widget_name]

  if widget:IsEnabled() then
    Addon:EnableWidget(widget_name)
  else
    Addon:DisableWidget(widget_name)
  end
end

function Addon:UpdateSettingsForWidget(widget_name)
  local widget = Widgets[widget_name]

  for plate, _ in pairs(Addon.PlatesVisible) do
    widget:UpdateSettings(plate.TPFrame.widgets[widget_name])
  end
end

function Addon:InitializeAllWidgets()
  for widget_name, _ in pairs(Widgets) do
    Addon:InitializeWidget(widget_name)
  end
end

function Addon:EnableWidget(widget_name)
   local widget = Widgets[widget_name]

  EnabledWidgets[widget_name] = widget


  -- Nameplates are re-used by WoW, so we cannot iterate just over all visible plates, but must
  -- add the new widget to all existing plates, even if they are currently not visible
  for _, tp_frame in pairs(Addon.PlatesCreated) do
    local plate_widgets = tp_frame.widgets

    if not plate_widgets[widget_name] then
      plate_widgets[widget_name] = widget:Create(tp_frame)
    end

    -- As we are iterating over all plates created, even if no unit is assigned to it currently, we have
    -- to skip plates without units. OnUnitAdded will be called on them anyway
    if tp_frame.Active then
      local widget_frame = plate_widgets[widget_name]

      widget_frame.Active = tp_frame.stylename ~= "empty" and widget:EnabledForStyle(tp_frame.stylename, tp_frame.unit)
      widget_frame.unit = tp_frame.unit

      if widget_frame.Active then
        widget:OnUnitAdded(widget_frame, tp_frame.unit)
      else
        widget_frame:Hide()
      end
    end
  end

  -- As events are registered in OnEnable, this must be done after all widget frames are created, otherwise an registered event
  -- may already occur before the widget frame exists.
  if widget.OnEnable then
    widget:OnEnable()
  end
end

function Addon:DisableWidget(widget_name)
  local widget = EnabledWidgets[widget_name]

  if widget then
    if widget.OnDisable then
      widget:OnDisable()
    end

    -- Disable all events of the widget
    widget:UnregisterAllEvents()

    -- for all plates - hide the widget frame (alternatively: remove the widget frame)
    for plate, _ in pairs(Addon.PlatesVisible) do
      plate.TPFrame.widgets[widget_name]:Hide()
    end
  end
end

function Addon:WidgetsOnPlateCreated(tp_frame)
  local plate_widgets = tp_frame.widgets

  for widget_name, widget in pairs(EnabledWidgets) do
    plate_widgets[widget_name] = widget:Create(tp_frame)
  end
end


function Addon:WidgetsOnUnitRemoved(frame)
  for _, widget_frame in pairs(frame.widgets) do
    widget_frame.Active = false
    widget_frame:Hide()
  end

--  local plate_widgets = frame.widgets
--  for widget_name, _ in pairs(EnabledWidgets) do
--    local widget_frame = plate_widgets[widget_name]
--    widget_frame.Active = false
--    widget_frame:Hide()
--  end
end

-- TODO: Seperate UnitAdded from UpdateSettings/UpdateConfiguration (unit independent stuff)
--       Maybe event seperate style dependedt stuff (PlateStyleChanged)
function Addon:WidgetsOnUnitAdded(tp_frame, unit)
  local plate_widgets = tp_frame.widgets

  for widget_name, widget in pairs(EnabledWidgets) do
    local widget_frame = plate_widgets[widget_name]

    -- I think it could happen that a nameplate was created, then a widget is enabled, and afterwise the unit is
    -- added to the nameplate, i.e., InitializedWidgets is called.
    --    if plate_widgets[widget_name] == nil then
    --      TidyPlatesThreat.db.global.Unit = tp_frame
    --    end
    --    assert (plate_widgets[widget_name] ~= nil, "Uninitialized widget found: " .. widget_name .. " for unit " .. unit.name .. " (" .. tp_frame:GetName() .. ")")

    widget_frame.Active = tp_frame.stylename ~= "empty" and widget:EnabledForStyle(tp_frame.stylename, unit)
    widget_frame.unit = unit

    if widget_frame.Active then
      widget:OnUnitAdded(widget_frame, unit)
    else
      widget_frame:Hide()
    end
  end
end

--function Addon:WidgetsOnUpdate(tp_frame, unit)
--  local plate_widgets = tp_frame.widgets
--
--  for widget_name, widget in pairs(EnabledWidgets) do
--    local widget_frame = plate_widgets[widget_name]
--
--    if widget_frame.Active then
--      if widget.UpdateFrame then
--        widget:UpdateFrame(widget_frame, unit)
--      end
--    else
--      widget_frame:Hide()
--    end
--  end
--end

function Addon:WidgetsPlateModeChanged(tp_frame, unit)
  local plate_widgets = tp_frame.widgets

  for widget_name, widget in pairs(EnabledWidgets) do
    local widget_frame = plate_widgets[widget_name]

    widget_frame.Active = tp_frame.stylename ~= "empty" and widget:EnabledForStyle(tp_frame.stylename, unit)

    if widget_frame.Active then
      --if widget.OnUpdatePlateMode then
      --  widget:OnUpdatePlateMode(plate_widgets[widget_name], unit)
      --end
      widget:OnUnitAdded(widget_frame, unit)
    else
      widget_frame:Hide()
    end
  end
end

--function Addon:WidgetsOnTargetChanged(tp_frame)
--  local plate_widgets = tp_frame.widgets
--
--  for widget_name, widget in pairs(EnabledWidgets) do
--    local widget_frame = plate_widgets[widget_name]
--
--    if widget_frame.Active then
--      if widget.OnTargetChanged then
--        widget:OnTargetChanged(plate_widgets[widget_name], tp_frame.unit)
--      end
--    else
--      plate_widgets[widget_name]:Hide()
--    end
--  end
--end