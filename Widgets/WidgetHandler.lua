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

local WidgetHandler = Addon.Widgets
WidgetHandler.Widgets = {}
WidgetHandler.EnabledWidgets = {}
WidgetHandler.EnabledTargetWidgets = {}
WidgetHandler.RegisteredEventsByWidget = {}

---------------------------------------------------------------------------------------------------
-- Event handling stuff
---------------------------------------------------------------------------------------------------
local function EventHandler(self, event, ...)
  local widgets = WidgetHandler.RegisteredEventsByWidget[event]

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

WidgetHandler.EventHandlerFrame = CreateFrame("Frame", nil, WorldFrame)
WidgetHandler.EventHandlerFrame:SetScript("OnEvent", EventHandler)

local function RegisterEvent(widget, event, func)
  if not WidgetHandler.RegisteredEventsByWidget[event] then
    WidgetHandler.RegisteredEventsByWidget[event] = {}
  end

  WidgetHandler.RegisteredEventsByWidget[event][widget] = func or true
  WidgetHandler.EventHandlerFrame:RegisterEvent(event)
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
  if WidgetHandler.RegisteredEventsByWidget[event] then
    WidgetHandler.RegisteredEventsByWidget[event][widget] = nil

    if next(WidgetHandler.RegisteredEventsByWidget[event]) == nil then -- last registered widget removed?
      WidgetHandler.EventHandlerFrame:UnregisterEvent(event)
    end
  end

  if widget.EventHandlerFrame then
    widget.EventHandlerFrame:UnregisterEvent(event)
    widget.RegistedUnitEvents[event] = nil
  end
end

local function UnregisterAllEvents(widget)
  for event, _ in pairs(WidgetHandler.RegisteredEventsByWidget) do
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
--   * InitializeWidget and InitializeAllWidgets
--       - To initialize a widget, first Widget:IsEnabled() is called. You should at least check if the
--         widget is enabled in general (db.ON, db.ShowInHeadlineView).
--         You may check additional conditions (like Combo Points widget checks for the current
--         spec actually having combo points). But if these conditions may change without Reload UI
--         make sure to keep a even active (e.g., ACTIVE_TALENT_GROUP_CHANGED) to be able to react
--         to that.
--           - If you are using Widget:UpdateSettings() to cache settings from the configuration, make sure that
--             it is called before Widget:Create() as it probably will depend on some of these settings.
--       - After that, eithr WidgetHandler:EnableWidget() or WidgetHandler:DisableWidget() are called.
--         For EnableWidget(): Here, for all nameplates created
--           - the widget frame is created (if not already done) with Widget:Create(),
--           - afterwards,
--             - it is checked if the widget is enabled for the plate's current style
--               with Widget:EnabledForStyle()
--             - if true, the widget frame is set to Active and initialized with the nameplate's
--               unit with Widget:OnUnitAdded()
--           - At last, Widget:OnEnable() is called (if implemented) or . Here, you can register events
--         For DisableWidget():
--           - Widget:OnDisable() is called if immplemented. Here, you can disable all events if the are
--             required when the widget is disabled (for Combo Points widget, e.g, ACTIVE_TALENT_GROUP_CHANGED
--             will be active even afterwards as the player may switch to a spec with combo points).
--           - Afterwards, all widget frames for all nameplates created will be hidden (if it's not a
--             target only widget)
--             For target-only widgets, you have to hide the widget frame in Widget:OnDisable()
--
-- Optional funcations are:
--   * OnEnable
--   * OnDisable
--   * UpdateFrame (if UpdateAllFrames is used)
--   * UpdateSettings (not yet fully implemented)
--
-- If using UpdateSettings (like Auras and ComboPoints do it right now):
--   Whenever another widget function is called, make sure the settings (stored in the widget object
--   are up-to-date. Otherwise widget frames are created/updated/accessed with deprecated settings
--   which may - worst case scenario - result in Lua errors.
--   <to be described>
-- When iterating over widget frames (PlatesVisible or PlatesCreated) be sure to always consider the
-- following:
--
---------------------------------------------------------------------------------------------------
function WidgetHandler:NewWidget(widget_name)
  local widget = {
    Name = widget_name,
    WidgetHandler = WidgetHandler,
    --
    RegistedUnitEvents = {},
    --
    RegisterEvent = RegisterEvent,
    RegisterUnitEvent = RegisterUnitEvent,
    UnregisterEvent = UnregisterEvent,
    UnregisterAllEvents = UnregisterAllEvents,
    --
    UpdateAllFrames = UpdateAllFrames,
    UpdateAllFramesAndNameplateColor = UpdateAllFramesAndNameplateColor,
    -- Default functions for enabling/disabling the widget
    OnEnable = function(self) end, -- do nothing
    OnDisable = function(self)
      self:UnregisterAllEvents()
    end,
  }

  self.Widgets[widget_name] = widget

  return widget
end

function WidgetHandler:NewTargetWidget(widget_name)
  local widget = self:NewWidget(widget_name)

  widget.TargetOnly = true

  return widget
end

function WidgetHandler:InitializeWidget(widget_name)
  local widget = self.Widgets[widget_name]

  if widget.UpdateSettings then
    widget:UpdateSettings()
  end

  if widget:IsEnabled() then
    self:EnableWidget(widget_name)
  else
    self:DisableWidget(widget_name)
  end
end

function WidgetHandler:InitializeAllWidgets()
  for widget_name, _ in pairs(self.Widgets) do
    self:InitializeWidget(widget_name)
  end
end

function WidgetHandler:EnableWidget(widget_name)
  -- Enable widgets only once
  if self.EnabledTargetWidgets[widget_name] or self.EnabledWidgets[widget_name] then
    return
  end

  local widget = self.Widgets[widget_name]
  if widget.TargetOnly then
    self.EnabledTargetWidgets[widget_name] = widget
    widget:Create()
  else
    self.EnabledWidgets[widget_name] = widget

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
  end

  -- As events are registered in OnEnable, this must be done after all widget frames are created, otherwise an registered event
  -- may already occur before the widget frame exists.
  widget:OnEnable()
end

function WidgetHandler:DisableWidget(widget_name)
  -- Disable widgets only once
  if not (self.EnabledTargetWidgets[widget_name] or self.EnabledWidgets[widget_name]) then
    return
  end

  local widget = self.Widgets[widget_name]
  if widget.TargetOnly then
    self.EnabledTargetWidgets[widget_name] = nil

    widget:OnDisable()
    widget:OnTargetUnitRemoved()
  else
    local widget = self.EnabledWidgets[widget_name]

    if widget then
      self.EnabledWidgets[widget_name] = nil

      widget:OnDisable()
      for plate, _ in pairs(Addon.PlatesVisible) do
        plate.TPFrame.widgets[widget_name]:Hide()
      end
    end
  end
end

function WidgetHandler:OnPlateCreated(tp_frame)
  local plate_widgets = tp_frame.widgets

  for widget_name, widget in pairs(self.EnabledWidgets) do
    plate_widgets[widget_name] = widget:Create(tp_frame)
  end
end

-- TODO: Seperate UnitAdded from UpdateSettings/UpdateConfiguration (unit independent stuff)
--       Maybe event seperate style dependedt stuff (PVlateStyleChanged)
function WidgetHandler:OnUnitAdded(tp_frame, unit)
  local plate_widgets = tp_frame.widgets

  if unit.isTarget then
    for _, widget in pairs(self.EnabledTargetWidgets) do
      widget:OnTargetUnitAdded(tp_frame, unit)
    end
  end

  for widget_name, widget in pairs(self.EnabledWidgets) do
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

function WidgetHandler:OnUnitRemoved(tp_frame, unit)
  --  for widget_name, widget_frame in pairs(tp_frame.widgets) do
  --    widget_frame.Active = false
  --    widget_frame:Hide()
  --
  --    local widget = EnabledWidgets[widget_name]
  --    if widget.OnUnitRemoved then
  --      widget:OnUnitRemoved(widget_frame)
  --    end
  --  end

  if unit.isTarget then
    for _, widget in pairs(self.EnabledTargetWidgets) do
      widget:OnTargetUnitRemoved()
    end
  end

  local plate_widgets = tp_frame.widgets
  for widget_name, widget in pairs(self.EnabledWidgets) do
    local widget_frame = plate_widgets[widget_name]
    widget_frame.Active = false
    widget_frame:Hide()

    if widget.OnUnitRemoved then
      widget:OnUnitRemoved(widget_frame)
    end
  end
end

function WidgetHandler:UpdateSettings(widget_name)
  local widget = self.Widgets[widget_name]

  widget:UpdateSettings()
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

-- Currently only working for target-only widgets
--function Addon:WidgetsModeChanged(tp_frame, unit)
--  if unit.isTarget then
--    for _, widget in pairs(EnabledTargetWidgets) do
--      widget:OnModeChange(tp_frame, unit)
--    end
--  end
--end

  --function Addon:WidgetsPlateModeChanged(tp_frame, unit)
--  local plate_widgets = tp_frame.widgets
--
--  for widget_name, widget in pairs(EnabledWidgets) do
--    local widget_frame = plate_widgets[widget_name]
--
--    widget_frame.Active = tp_frame.stylename ~= "empty" and widget:EnabledForStyle(tp_frame.stylename, unit)
--
--    if widget_frame.Active then
--      --if widget.OnUpdatePlateMode then
--      --  widget:OnUpdatePlateMode(plate_widgets[widget_name], unit)
--      --end
--      widget:OnUnitAdded(widget_frame, unit)
--    else
--      widget_frame:Hide()
--    end
--  end
--end

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