---------------------------------------------------------------------------------------------------
-- <Name> Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Module = Addon:NewModule("")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

---------------------------------------------------------------------------------------------------
-- Widget Functions
---------------------------------------------------------------------------------------------------

local function EventHandler(event, ...)
end


---------------------------------------------------------------------------------------------------
-- Module functions for creation and update
---------------------------------------------------------------------------------------------------

function Module:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------

  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Module:IsEnabled()
end

function Module:OnEnable()
  Module:RegisterEvent("EVENT", EventHandler)
end

function Module:EnabledForStyle(style, unit)
end

function Module:OnUnitAdded(widget_frame, unit)
end

function Module:UpdateFrame(widget_frame, unit)
end

function Module:OnTargetChanged(widget_frame, unit)
end