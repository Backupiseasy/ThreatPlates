local _, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs, next = pairs, next

-- WoW APIs
local WorldFrame = WorldFrame

-- ThreatPlates APIs

---------------------------------------------------------------------------------------------------
-- Event service - the interface to call all functions for event handling
---------------------------------------------------------------------------------------------------

local EventService = {}
Addon.EventService = EventService

---------------------------------------------------------------------------------------------------
-- Data structures to store event and event subscribers
---------------------------------------------------------------------------------------------------
local RegisteredEvents = {}
local RegisteredUnitEvents = {}
local SubscribersByEvent = {}

---------------------------------------------------------------------------------------------------
-- WoW Event Handler
---------------------------------------------------------------------------------------------------

local EventHandlerFrame = _G.CreateFrame("Frame")

local function EventHandler(self, event, ...)
  --print ("Publishing Event", event, ...)

  -- Process the main subscriber that regestered the event
  local subscriber = RegisteredEvents[event]
  if subscriber then
    --print ("Processing event", event)
    if subscriber == Addon then
      subscriber[event](subscriber, ...)
    else
      subscriber(...)
    end
  end

  -- Process all other subscribers that subscribed to the event
  local all_subscribers = SubscribersByEvent[event]
  if all_subscribers then
    for subscriber, func in pairs(all_subscribers) do
      --print ("Publishing", event)
      if func == true then
        subscriber[event](subscriber, ...)
      else
        func( ...)
      end
    end
  end
end

local function UnitEventHandler(event_handler_frame, event, ...)
  --print ("Publishing Unit Event", event, ...)

  local all_subscribers = event_handler_frame.Events[event]
  for subscriber, func in pairs(all_subscribers) do
    if func == true then
      subscriber[event](subscriber, ...)
    else
      func(event, ...)
    end
  end
end

-- EventHandlerFrame:SetFrameStrata("TOOLTIP") 	-- When parented to WorldFrame, causes OnUpdate handler to run close to last
EventHandlerFrame:SetScript("OnEvent", EventHandler)

---------------------------------------------------------------------------------------------------
-- Threat-Plates-internal events
---------------------------------------------------------------------------------------------------
local INTERNAL_EVENTS = {
  -- Payload:
  --   { Name = "tp_frame", Type = "table", Nilable = false }
  --   { Name = "unitid", Type = "string", Nilable = false }
  ThreatUpdate = true,
  MouseoverOnEnter = true,    -- Parameters: tp_frame
  MouseoverOnLeave = true,    -- Parameters: tp_frame
  CastingStarted = true,      -- Parameters: tp_frame
  CastingStopped = true,      -- Parameters: tp_frame
  TargetMarkerUpdate = true,  -- Parameters: tp_frame
  TargetGained = true,        -- Parameters: tp_frame
  TargetLost = true,          -- Parameters: tp_frame
  FocusGained = true,         -- Parameters: tp_frame
  FocusLost = true,           -- Parameters: tp_frame
  -- Payload:
  --   tp_frame: Frame (table), Nilable = false
  FactionUpdate = true,
  -- Payload:
  --   tp_frame: Frame (table), Nilable = false
  --   { Name = "style", Type = "table", Nilable = false }
  --   { Name = "stylename", Type = "string", Nilable = false }
  StyleUpdate = true,
  -- Payload:
  --   tp_frame: Frame (table), Nilable = false
  --   color: Color (table), Nilable = false
  SituationalColorUpdate = true, -- Curently: Updates for Quest (Unit Color) and
  -- Event: ClassColorUpdate
  --   Fired when the class color of a unit must be re-evaluated
  --   Event(frame)
  ClassColorUpdate = true,
  -- Event: CustomStyleUpdate
  --   Fires when a nameplate should apply a custom style
  --   Event(frame)
  -- CustomStyleUpdate = true
  ThreatColorUpdate = true,
  --   Fired when the threat-based color of a unit must be re-evaluated
  --   Event(frame)

  NameColorUpdate = true,
  -- Parameters: TPFrame, color
  --   Fired when the situational color (e.g., target, target mark) must be re-evaluated
  --   Event(frame)
  HealthbarColorUpdate = true,
  -- Parameters: TPFrame, color
}

---------------------------------------------------------------------------------------------------
-- Event Service Functions
---------------------------------------------------------------------------------------------------

-- Register as main subscriber (only one is supported) for a WoW event - all other subscribers
-- will receive the event after the main subscriber
function EventService.RegisterEvent(event, func, register_for_current_expansion)
  if not INTERNAL_EVENTS[event] and not Addon:ExpansionSupportsEvent(event, register_for_current_expansion) then return end

  local previous_subscriber = RegisteredEvents[event]
  RegisteredEvents[event] = func or Addon

  -- Register at WoW only once,
  if not previous_subscriber then
    Addon:RegisterEvent(EventHandlerFrame, event)
  end
end

-- Unregister as main subscriber all other subscribers
function EventService.UnregisterEvent(event, func, register_for_current_expansion)
  if not INTERNAL_EVENTS[event] and not Addon:ExpansionSupportsEvent(event, register_for_current_expansion) then return end

  local previous_subscriber = RegisteredEvents[event]
  RegisteredEvents[event] = nil

  if previous_subscriber and not (SubscribersByEvent[event] and next(SubscribersByEvent[event])) then
    Addon:UnregisterEvent(EventHandlerFrame, event)
  end
end

-- Subscribe to an event (WoW event or ThreatPlates internal event)
function EventService.Subscribe(subscriber, event, func, register_for_current_expansion)
  if not INTERNAL_EVENTS[event] and not Addon:ExpansionSupportsEvent(event, register_for_current_expansion) then return end

  if not RegisteredEvents[event] and not INTERNAL_EVENTS[event] then
    Addon:RegisterEvent(EventHandlerFrame, event, register_for_current_expansion)
  end

  SubscribersByEvent[event] = SubscribersByEvent[event] or {}
  SubscribersByEvent[event][subscriber] = func or true
end

function EventService.SubscribeUnitEvent(subscriber, event, unitid, func, register_for_current_expansion)
  if not INTERNAL_EVENTS[event] and not Addon:ExpansionSupportsEvent(event, register_for_current_expansion) then return end

  local event_handler_frame = RegisteredUnitEvents[unitid]
  if not event_handler_frame then
    event_handler_frame = CreateFrame("Frame", nil, WorldFrame)

    event_handler_frame.Events = {}
    event_handler_frame:SetScript("OnEvent", UnitEventHandler)

    RegisteredUnitEvents[unitid] = event_handler_frame
  end

  local subscribers_for_event = event_handler_frame.Events[event]
  if not subscribers_for_event then
    subscribers_for_event = {}
    event_handler_frame.Events[event] = subscribers_for_event

    Addon:RegisterUnitEvent(event_handler_frame, event, unitid, register_for_current_expansion)
  end

  subscribers_for_event[subscriber] = func or true
end

function EventService.Publish(event, ...)
  --print ("Publishing event", event, "=>", ...)

  -- Process all subscribers that subscribed to the event
  local all_subscribers = SubscribersByEvent[event]
  if all_subscribers then
    for subscriber, func in pairs(all_subscribers) do
      if func == true then
        subscriber[event](subscriber, ...)
      else
        func(...)
      end
    end
  end
end

-- Unregister the event if the last subscriber was removed an there is no main subscriber
local function UnregisterGameEvent(event, subscribers_for_event, subscriber, event_handler_frame)
  subscribers_for_event[subscriber] = nil
  if not INTERNAL_EVENTS[event] and next(subscribers_for_event) == nil then
    Addon:UnregisterEvent(event_handler_frame, event)
  end
end

-- Unscubscribe to an event
function EventService.Unsubscribe(subscriber, event)
  if not INTERNAL_EVENTS[event] and not Addon:ExpansionSupportsEvent(event) then return end

  local subscribers_for_event = SubscribersByEvent[event]
  if subscribers_for_event then
    UnregisterGameEvent(event, subscribers_for_event, subscriber, EventHandlerFrame)
  end

  -- unitid, event_handler_frame for unit
  for _, event_handler_frame in pairs(RegisteredUnitEvents) do
    local subscribers_for_event = event_handler_frame.Events and event_handler_frame.Events[event]
    if subscribers_for_event then
      UnregisterGameEvent(event, subscribers_for_event, subscriber, event_handler_frame)
    end
  end
end

-- Unsubscribes to all events (including unit-based events) for a subscriber
function EventService.UnsubscribeAll(subscriber)
  for event, subscribers_for_event in pairs(SubscribersByEvent) do
    if Addon:ExpansionSupportsEvent(event) then     
      UnregisterGameEvent(event, subscribers_for_event, EventHandlerFrame)
    end
  end

  for _, event_handler_frame in pairs(RegisteredUnitEvents) do
    for event, subscribers_for_event in pairs(event_handler_frame.Events) do
      if Addon:ExpansionSupportsEvent(event) then     
        UnregisterGameEvent(event, subscribers_for_event, subscriber, event_handler_frame)
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Debug functions
---------------------------------------------------------------------------------------------------

local function SortFunction(a,b)
  if type(a) == "table"  then
    a = a.Name
  end
  if type(b) == "table" then
    b = b.Name
  end

  return (a or "") < (b or "")
end

local function PairsByKeys (t)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, SortFunction)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

function Addon:PrintEventService()
  print ("EventService: Registered Events")
  for event, _ in PairsByKeys(RegisteredEvents) do
    print ("  " .. event)
  end

  print ("EventService: Subscribed Events")
  for event, all_subscribers in PairsByKeys(SubscribersByEvent) do
    print ("  " .. event .. ": #Subscribers =", Addon.Debug:TableSize(all_subscribers))
    for subscriber, func in PairsByKeys(all_subscribers) do
      print ("    ->", subscriber.Name or subscriber)
    end
  end

  print ("EventService: Subscribed Events for Units")
  for unitid, event_handler_frame in pairs(RegisteredUnitEvents) do
    print ("  " .. unitid .. ": #Events =", Addon.Debug:TableSize(event_handler_frame.Events))
    for event, all_subscribers in pairs(event_handler_frame.Events) do
      print ("    " .. event .. ": #Subscribers =", Addon.Debug:TableSize(all_subscribers))
      for subscriber, func in pairs(all_subscribers) do
        print ("      ->", subscriber.Name or subscriber)
      end
    end
  end
end