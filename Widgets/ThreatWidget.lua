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
local CreateFrame, UNKNOWNOBJECT = CreateFrame, UNKNOWNOBJECT
local UnitThreatSituation, UnitName = UnitThreatSituation, UnitName
local GetRaidTargetIndex = GetRaidTargetIndex

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ThreatWidget\\"
local THREAT_REFERENCE = Addon.THREAT_REFERENCE
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
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
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

  local name, _ = UnitName(unit.unitid) or UNKNOWNOBJECT, nil
  local unique_setting = TidyPlatesThreat.db.profile.uniqueSettings.map[name]
  if unique_setting then
    if not unique_setting.useStyle or not unique_setting.UseThreatColor then
      widget_frame:Hide()
      return
    end
  end

  local style = (Addon.PlayerRoleIsTank and "tank") or "dps"

  local threat_status = UnitThreatSituation("player", unit.unitid) or 0
  local threat_level = THREAT_REFERENCE[threat_status]

  if style == "tank" then -- Tanking uses regular textures / swapped for dps / healing
    if db.toggle.OffTank and Addon:UnitIsOffTanked(unit) then
      threat_level = "OFFTANK"
    end
  else -- dps or normal
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