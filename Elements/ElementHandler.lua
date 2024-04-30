---------------------------------------------------------------------------------------------------
-- Element Handler
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

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

function ElementHandler.PlateCreated(frame)
  for i = 1, #ElementsPriority do
    ElementsPriority[i].PlateCreated(frame)
  end
end

function ElementHandler.PlateUnitAdded(frame)
  if frame.PlateStyle == "None" then return end

  for i = 1, #ElementsPriority do
    local element = ElementsPriority[i]
    if element.PlateUnitAdded then
      element.PlateUnitAdded(frame)
    end
  end
end

function ElementHandler.PlateUnitRemoved(frame)
  if frame.PlateStyle == "None" then return end

  for i = 1, #ElementsPriority do
    local element = ElementsPriority[i]
    if element.PlateUnitRemoved then
      element.PlateUnitRemoved(frame)
    end
  end
end

function ElementHandler.UpdateStyle(frame, style)
  for i = 1, #ElementsPriority do
    local element = ElementsPriority[i]
    if element.UpdateStyle then
      element.UpdateStyle(frame, style, frame.PlateStyle)
    end
  end
end

function ElementHandler.UpdateSettings()
  for i = 1, #ElementsPriority do
    local element = ElementsPriority[i]
    if element.UpdateSettings then
      element.UpdateSettings()
    end
  end
end