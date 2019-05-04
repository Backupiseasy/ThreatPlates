---------------------------------------------------------------------------------------------------
-- Element Handler
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local ipairs = ipairs

-- WoW APIs

-- ThreatPlates APIs

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local ElementHandler = {}
Addon.Elements = ElementHandler
local Elements = {}
local ElementsPriority = {}

---------------------------------------------------------------------------------------------------
-- Element Handler code
---------------------------------------------------------------------------------------------------

function ElementHandler.NewElement(name)
  local element = {
    Name = name,
  }

  ElementsPriority[#ElementsPriority + 1] = element
  Elements[name] = element

  return element
end

function ElementHandler.GetElement(name)
  return Elements[name]
end

function ElementHandler.Created(frame)
  for i = 1, #ElementsPriority do
    ElementsPriority[i].Created(frame)
  end
 end

function ElementHandler.UnitAdded(frame)
  local element

  if frame.PlateStyle == "None" then return end

  for i = 1, #ElementsPriority do
    element = ElementsPriority[i]
    if element.UnitAdded then
      element.UnitAdded(frame)
    end
  end
end

function ElementHandler.UnitRemoved(frame)
  local element

  if frame.PlateStyle == "None" then return end

  for i = 1, #ElementsPriority do
    element = ElementsPriority[i]
    if element.UnitRemoved then
      element.UnitRemoved(frame)
    end
  end
end

function ElementHandler.UpdateStyle(frame, style)
  local element

  for i = 1, #ElementsPriority do
    element = ElementsPriority[i]
    if element.UpdateStyle then
      element.UpdateStyle(frame, style, frame.PlateStyle)
    end
  end
end

function ElementHandler.UpdateSettings()
  local element

  for i = 1, #ElementsPriority do
    element = ElementsPriority[i]
    if element.UpdateSettings then
      element.UpdateSettings()
    end
  end
end