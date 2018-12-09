local _, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs = pairs

-- WoW APIs

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
local SubscribersByEvent = {}

---------------------------------------------------------------------------------------------------
-- WoW Event Handler
---------------------------------------------------------------------------------------------------

local EventHandlerFrame = CreateFrame("Frame", nil, WorldFrame)

local function EventHandler(self, event, ...)
  --print ("EVENT:", event)

  local subscriber = RegisteredEvents[event]
  if subscriber then
    --print ("Processing event", event)
    if subscriber == Addon then
      subscriber[event](subscriber, ...)
    else
      subscriber(event, ...)
    end
  end

  local all_subscribers = SubscribersByEvent[event]
  if all_subscribers then
    for subscriber, func in pairs(all_subscribers) do
      --print ("Publishing", event)
      if func == true then
        subscriber[event](subscriber, ...)
      else
        func(event, ...)
      end
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


function EventService.RegisterEvent(event, func)
  --print ("EventService: Register", event)

  RegisteredEvents[event] = func or Addon
  EventHandlerFrame:RegisterEvent(event)
  -- TidyPlatesThreat:RegisterEvent(event)
end


--function EventService.RegisterUnitEvent(widget, event, unitid, func)
--  if not widget.EventHandlerFrame then
--    widget.EventHandlerFrame = CreateFrame("Frame", nil, WorldFrame)
--    widget.EventHandlerFrame.Widget = widget
--    widget.EventHandlerFrame:SetScript("OnEvent", UnitEventHandler)
--  end
--
--  widget.RegistedUnitEvents[event] = func or true
--  widget.EventHandlerFrame:RegisterUnitEvent(event, unitid)
--end
--
--function EventService.UnregisterEvent(widget, event)
--  if SubscribersByEvent[event] then
--    SubscribersByEvent[event][widget] = nil
--
--    if next(SubscribersByEvent[event]) == nil then -- last registered widget removed?
--      EventHandlerFrame:UnregisterEvent(event)
--    end
--  end
--
--  if widget.EventHandlerFrame then
--    widget.EventHandlerFrame:UnregisterEvent(event)
--    widget.RegistedUnitEvents[event] = nil
--  end
--end
--
---- To subscribe for an event, the event must be registered at WoW (it's not registered as part of the subscription
--function EventService.Subscribe(subscriber, event, func)
--  SubscribersByEvent[event] = SubscribersByEvent[event] or {}
--  --  if not SubscribersByEvent[event] then
--  --    SubscribersByEvent[event] = {}
--  --  end
--
--  SubscribersByEvent[event][subscriber] = func or true
--  EventHandlerFrame:RegisterEvent(event)
--end
