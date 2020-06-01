---------------------------------------------------------------------------------------------------
-- Threat Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewWidget("Threat")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local GetRaidTargetIndex = GetRaidTargetIndex

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local GetThreatLevel = Addon.GetThreatLevel

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ThreatWidget\\"
local REVERSE_THREAT_SITUATION = {
  HIGH = "LOW",
  MEDIUM ="MEDIUM",
  LOW = "HIGH",
}

---------------------------------------------------------------------------------------------------
-- Event handling stuff
---------------------------------------------------------------------------------------------------

function Widget:ThreatUpdate(tp_frame)
  local widget_frame = tp_frame.widgets.Threat
  if widget_frame.Active then
    self:UpdateFrame(widget_frame, tp_frame.unit)
  end
end

function Widget:TargetMarkerUpdate(tp_frame)
  local widget_frame = tp_frame.widgets.Threat
  if widget_frame.Active then
    self:UpdateFrame(widget_frame, tp_frame.unit)
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = _G.CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
  widget_frame.LeftTexture = widget_frame:CreateTexture(nil, "OVERLAY", 6)
  widget_frame.RightTexture = widget_frame:CreateTexture(nil, "OVERLAY", 6)
  widget_frame.RightTexture:SetPoint("LEFT", tp_frame.visual.Healthbar, "RIGHT", 4, 0)
  widget_frame.RightTexture:SetSize(64, 64)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  return TidyPlatesThreat.db.profile.threat.art.ON
end

function Widget:OnEnable()
  self:SubscribeEvent("ThreatUpdate")
  self:SubscribeEvent("TargetMarkerUpdate")
end

function Widget:EnabledForStyle(style, unit)
  return not (unit.type == "PLAYER" or style == "NameOnly" or style == "NameOnly-Unique" or style == "etotem")
end

function Widget:OnUnitAdded(widget_frame, unit)
  local db = TidyPlatesThreat.db.profile.threat.art

  if db.theme == "bar" then
    widget_frame.LeftTexture:ClearAllPoints(widget_frame)
    widget_frame.LeftTexture:SetSize(265, 64)
    widget_frame.LeftTexture:SetPoint("CENTER", widget_frame:GetParent(), "CENTER")
    widget_frame.LeftTexture:SetTexCoord(0, 1, 0, 1)

    widget_frame.RightTexture:Hide()
  else
    widget_frame.LeftTexture:ClearAllPoints(widget_frame)
    widget_frame.LeftTexture:SetSize(64, 64)
    widget_frame.LeftTexture:SetPoint("RIGHT", widget_frame:GetParent().visual.Healthbar, "LEFT", -4, 0)
    widget_frame.LeftTexture:SetTexCoord(0, 0.25, 0, 1)

    widget_frame.RightTexture:SetTexCoord(0.75, 1, 0, 1)
    widget_frame.RightTexture:Show()
  end

  self:UpdateFrame(widget_frame, unit)
end

function Widget:UpdateFrame(widget_frame, unit)
  local db = TidyPlatesThreat.db.profile.threat

  if GetRaidTargetIndex(unit.unitid) and db.marked.art then
    widget_frame:Hide()
    return
  end

  if not Addon:ShowThreatFeedback(unit) then
    widget_frame:Hide()
    return
  end

  -- unique_setting.useStyle is already checked when setting the style of the nameplate (to custom)
  local unique_setting = unit.CustomPlateSettings
  if unique_setting and not unique_setting.UseThreatColor then
    widget_frame:Hide()
    return
  end

  local style = Addon.PlayerRole

  local threat_level = GetThreatLevel(unit, style, db.toggle.OffTank)
  if style ~= "tank" then
    -- Tanking uses regular textures / swapped for dps / healing
    threat_level = REVERSE_THREAT_SITUATION[threat_level]
  end

  if db.art.theme == "bar" then
    widget_frame.LeftTexture:SetTexture(PATH .. db.art.theme.."\\".. threat_level)
  else
    widget_frame.LeftTexture:SetTexture(PATH .. db.art.theme.."\\".. threat_level)
    widget_frame.RightTexture:SetTexture(PATH .. db.art.theme.."\\".. threat_level)
  end

  widget_frame:Show()
end

-- Load settings from the configuration which are shared across all aura widgets
-- used (for each widget) in UpdateWidgetConfig
--function Widget:UpdateSettings()
--  self.db = TidyPlatesThreat.db.profile.Threat
--
--  for _, tp_frame in pairs(Addon.PlatesCreated) do
--    local widget_frame = tp_frame.widgets.UniqueIcon
--
--    -- widget_frame could be nil if the widget as disabled and is enabled as part of a profile switch
--    -- For these frames, UpdateAuraWidgetLayout will be called anyway when the widget is initalized
--    -- (which happens after the settings update)
--    if widget_frame and tp_frame.Active then
--      -- Update the style as custom nameplates might have been changed and some units no longer
--      -- may be unique
--      Addon:SetStyle(widget_frame.unit)
--      self:OnUnitAdded(widget_frame, widget_frame.unit)
--    end
--  end
--end