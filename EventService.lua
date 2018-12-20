local _, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs, next = pairs, next

-- WoW APIs
local WorldFrame, CreateFrame = WorldFrame, CreateFrame

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
local UnitEventHandlerFrames = {}
local SubscribersByEvent = {}

---------------------------------------------------------------------------------------------------
-- WoW Event Handler
---------------------------------------------------------------------------------------------------

local EventHandlerFrame = CreateFrame("Frame", nil, WorldFrame)

local function EventHandler(self, event, ...)
  local pairs, Addon, RegisteredEvents,SubscribersByEvent = pairs, Addon, RegisteredEvents, SubscribersByEvent
  --print ("EVENT:", event)

  -- Process the main subscriber that regestered the event
  local subscriber = RegisteredEvents[event]
  if subscriber then
    --print ("Processing event", event)
    if subscriber == Addon then
      subscriber[event](subscriber, ...)
    else
      subscriber(event, ...)
    end
  end

  -- Process all other subscribers that subscribed to the event
  local all_subscribers = SubscribersByEvent[event]
  if all_subscribers then
    for subscriber, func in pairs(all_subscribers) do
      print ("Publishing", event)
      if func == true then
        subscriber[event](subscriber, ...)
      else
        func(event, ...)
      end
    end
  end

  -- Process all subscribers that only subscribed for the event for a specific unit
--  all_subscribers = RegisteredUnitEvents[event]
--  if all_subscribers then
--    local unitid, _ = ...
--    all_subscribers = RegisteredUnitEvents[event][unitid]
--    if all_subscribers then
--      for subscriber, func in pairs(all_subscribers) do
--        print ("Publishing Unit Event", event)
--        if func == true then
--          subscriber[event](subscriber, ...)
--        else
--          func(event, ...)
--        end
--      end
--    end
--  end
end

--local function UnitEventHandler(event_handler_frame, event, ...)
--  print ("Publishing Unit Event", event, ...)
--
--  local func = event_handler_frame.UnitEvents[event]
--  if func == true then
--    local subscriber = event_handler_frame.Subscriber
--    subscriber[event](subscriber, ...)
--  else
--    func(event, ...)
--  end
--end

local function UnitEventHandler(event_handler_frame, event, ...)
  print ("Publishing Unit Event", event, ...)

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
-- Event Service Functions
---------------------------------------------------------------------------------------------------

-- RegisterWoWEvent
-- Subscribe (to event, message)
-- Publish (to event, messag)
-- Unsubscribe (to event, message)


-- Register as main subscriber (only one is supported) for a WoW event - all other subscribers
-- will receive the event after the main subscriber
function EventService.RegisterEvent(event, func)
  print ("EventService: Register", event)

  RegisteredEvents[event] = func or Addon
  EventHandlerFrame:RegisterEvent(event)
  -- TidyPlatesThreat:RegisterEvent(event)
end

-- Subscribe to an event (WoW event or ThreatPlates internal event)
function EventService.Subscribe(subscriber, event, func)
  print ("EventService: Subscribe", event)

  if not RegisteredEvents[event] then
    EventHandlerFrame:RegisterEvent(event)
  end

  SubscribersByEvent[event] = SubscribersByEvent[event] or {}
  SubscribersByEvent[event][subscriber] = func or true
end

function EventService.SubscribeUnitEvent(subscriber, event, unitid, func)
  print ("EventService: Subscribe", event, "for", unitid)

  local event_handler_frame = RegisteredUnitEvents[unitid]
  if not event_handler_frame then
    event_handler_frame = CreateFrame("Frame", nil, WorldFrame)

    event_handler_frame.Events = {}
    event_handler_frame:SetScript("OnEvent", UnitEventHandler)

    RegisteredUnitEvents[unitid] = event_handler_frame
  end

  local all_subscribers = event_handler_frame.Events[event]
  if not all_subscribers then
    all_subscribers = {}
    event_handler_frame.Events[event] = all_subscribers

    event_handler_frame:RegisterUnitEvent(event, unitid)
  end

  all_subscribers[subscriber] = func or true
end

--function EventService.SubscribeUnitEvent(subscriber, event, unitid, func)
--  local event_handler_frame = UnitEventHandlerFrames[subscriber]
--
--  if not event_handler_frame then
--    event_handler_frame = CreateFrame("Frame", nil, WorldFrame)
--
--    event_handler_frame.UnitEvents = {}
--    event_handler_frame.Subscriber = subscriber
--    event_handler_frame:SetScript("OnEvent", UnitEventHandler)
--
--    UnitEventHandlerFrames[subscriber] = event_handler_frame
--  end
--
--  event_handler_frame.UnitEvents[event] = func or true
--  event_handler_frame:RegisterUnitEvent(event, unitid)
--end

--function EventService.SubscribeUnitEvent(subscriber, event, unitid, func)
--  if not RegisteredEvents[event] then
--    EventHandlerFrame:RegisterEvent(event)
--  end
--
--  RegisteredUnitEvents[event] = RegisteredUnitEvents[event] or {}
--  RegisteredUnitEvents[event][unitid] = RegisteredUnitEvents[event][event] or {}
--  RegisteredUnitEvents[event][unitid][subscriber] = func or true
--end


-- Unscubscribe to an event
function EventService.Unsubscribe(subscriber, event)
  print ("EventService: Unsubscribe", event)

  if SubscribersByEvent[event] then
    SubscribersByEvent[event][subscriber] = nil

    -- Unregister the event if the last subscriber was removed an there is no main subscriber
    if next(SubscribersByEvent[event]) == nil and RegisteredEvents[event] == nil then
      print ("EventService: Unregistering event", event)
      EventHandlerFrame:UnregisterEvent(event)
    end
  end

  for unitid, event_handler_frame in pairs(RegisteredUnitEvents) do
    if event_handler_frame.Events[event] then
      print ("EventService: Removing event", event, "for", unitid)
      event_handler_frame.Events[event][subscriber] = nil

      -- Was the last subscriber for the unit event removed?
      if next(event_handler_frame.Events[event]) == nil then
        print ("EventService: Unregistering event", event, "for", unitid)
        event_handler_frame:UnregisterEvent(event)
      end
    end
  end
end

-- Unsubscribes to all events (including unit-based events) for a subscriber
function EventService.UnsubscribeAll(subscriber)
  print ("EventService: Unsubscribe All")

  for event, all_subscribers in pairs(SubscribersByEvent) do
    all_subscribers[subscriber] = nil

    -- Unregister the event if the last subscriber was removed an there is no main subscriber
    -- Don't bother to set SubscribersByEvent[event] to nil - should not impact performance as it's a hash table
    if next(all_subscribers) == nil and RegisteredEvents[event] == nil then
      print ("EventService: Unregistering event", event)
      EventHandlerFrame:UnregisterEvent(event)
    end
  end

  for unitid, event_handler_frame in pairs(RegisteredUnitEvents) do
    for event, all_subscribers in pairs(event_handler_frame.Events) do
      if all_subscribers[subscriber] then
        print ("EventService: Removing event", event, "for", unitid)
      end
      all_subscribers[subscriber] = nil

      -- Was the last subscriber for the unit event removed?
      if next(all_subscribers) == nil then
        print ("EventService: Unregistering event", event, "for", unitid)
        event_handler_frame:UnregisterEvent(event)
      end
    end
  end
end

local function Size(table)
  local no = 0
  for key, value in pairs(table) do
    no = no + 1
  end

  return no
end

function Addon:PrintEventService()
  print ("EventService: Registered Events")
  for event, _ in pairs(RegisteredEvents) do
    print ("  " .. event)
  end

  print ("EventService: Subscribed Events")
  for event, all_subscribers in pairs(SubscribersByEvent) do
    print ("  " .. event .. ": #Subscribers =", Size(all_subscribers))
    for subscriber, func in pairs(all_subscribers) do
      print ("    ->", subscriber.Name or subscriber)
    end
  end

  print ("EventService: Subscribed Events for Units")
  for unitid, event_handler_frame in pairs(RegisteredUnitEvents) do
    print ("  " .. unitid .. ": #Events =", Size(event_handler_frame.Events))
    for event, all_subscribers in pairs(event_handler_frame.Events) do
      print ("    " .. event .. ": #Subscribers =", Size(all_subscribers))
      for subscriber, func in pairs(all_subscribers) do
        print ("      ->", subscriber.Name or subscriber)
      end
    end
  end
end