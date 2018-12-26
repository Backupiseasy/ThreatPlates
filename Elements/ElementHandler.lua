---------------------------------------------------------------------------------------------------
-- Element Handler
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs = pairs

-- WoW APIs

-- ThreatPlates APIs

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local ElementHandler = {}
Addon.Elements = ElementHandler
local Elements = {}

---------------------------------------------------------------------------------------------------
-- Element Handler code
---------------------------------------------------------------------------------------------------

function ElementHandler.NewElement(name)
  local element = {
    Name = name,
  }

  Elements[name] = element

  return element
end

function ElementHandler.GetElement(name)
  return Elements[name]
end

function ElementHandler.Created(frame)
  local pairs, Elements = pairs, Elements

  for _, element in pairs(Elements) do
    element.Created(frame)
  end
end

function ElementHandler.UnitAdded(frame)
  local pairs, Elements = pairs, Elements

  for _, element in pairs(Elements) do
    if element.UnitAdded then
      element.UnitAdded(frame)
    end
  end
end

function ElementHandler.UnitRemoved(frame)
  local pairs, Elements = pairs, Elements

  for _, element in pairs(Elements) do
    if element.UnitRemoved then
      element.UnitRemoved(frame)
    end
  end
end

function ElementHandler.UpdateStyle(frame, style)
  local pairs, Elements = pairs, Elements

  for _, element in pairs(Elements) do
    if element.UpdateStyle then
      element.UpdateStyle(frame, style)
    end
  end
end

function ElementHandler.UpdateSettings()
  local pairs, Elements = pairs, Elements

  for _, element in pairs(Elements) do
    if element.UpdateSettings then
      element.UpdateSettings()
    end
  end
end