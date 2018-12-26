local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Element Handler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs = pairs

-- WoW APIs

-- ThreatPlates APIs

---------------------------------------------------------------------------------------------------
-- Attributes for Element Handler
---------------------------------------------------------------------------------------------------

Addon.Elements = {}

local ElementHandler = Addon.Elements
local Elements = {}

function ElementHandler.NewElement(name)
  local element = {
    Name = name,
  }

  Elements[name] = element

  return element
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
    element.UnitAdded(frame)
  end
end

function ElementHandler.UnitRemoved(frame)
  local pairs, Elements = pairs, Elements

  for _, element in pairs(Elements) do
    element.UnitRemoved(frame)
  end
end

function ElementHandler.UpdateStyle(frame, style)
  local pairs, Elements = pairs, Elements

  for _, element in pairs(Elements) do
    element.UpdateStyle(frame, style)
  end
end

function ElementHandler.UpdateSettings()
  local pairs, Elements = pairs, Elements

  for _, element in pairs(Elements) do
    element.UpdateSettings()
  end
end