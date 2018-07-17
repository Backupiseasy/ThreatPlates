---------------------------------------------------------------------------------------------------
-- <Name> Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon:NewWidget("")

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
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------

  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
end

function Widget:OnEnable()
  Widget:RegisterEvent("EVENT", EventHandler)
end

function Widget:EnabledForStyle(style, unit)
end

function Widget:OnUnitAdded(widget_frame, unit)
end

function Widget:UpdateFrame(widget_frame, unit)
end

function Widget:OnTargetChanged(widget_frame, unit)
end