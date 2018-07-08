---------------------------------------------------------------------------------------------------
-- Target Art Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon:NewWidget("TargetArt")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame
local UnitIsUnit = UnitIsUnit
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\TargetArtWidget\\"

local BACKDROP = {
  default = {
    edgeFile = ThreatPlates.Art .. "TP_WhiteSquare",
    edgeSize = 1.8,
    offset = 4,
  },
  squarethin = {
    edgeFile = ThreatPlates.Art .. "TP_WhiteSquare",
    edgeSize = 1,
    offset = 3,
  }
}

local CurrentTarget

---------------------------------------------------------------------------------------------------
-- Target Art Widget Functions
---------------------------------------------------------------------------------------------------

function Widget:PLAYER_TARGET_CHANGED()
  if CurrentTarget then
    CurrentTarget:Hide()
    CurrentTarget = nil
  end

  local plate = GetNamePlateForUnit("target")
  if plate and plate.TPFrame.Active then
    CurrentTarget = plate.TPFrame.widgets.TargetArt
    CurrentTarget:SetShown(CurrentTarget.Active)
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
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 6)
  widget_frame.LeftTexture = widget_frame:CreateTexture(nil, "BACKGROUND", 0)
  widget_frame.LeftTexture:SetPoint("RIGHT", tp_frame, "LEFT")
  widget_frame.LeftTexture:SetSize(64, 64)
  widget_frame.RightTexture = widget_frame:CreateTexture(nil, "BACKGROUND", 0)
  widget_frame.RightTexture:SetPoint("LEFT", tp_frame, "RIGHT")
  widget_frame.RightTexture:SetSize(64, 64)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  return TidyPlatesThreat.db.profile.targetWidget.ON
end

function Widget:OnEnable()
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function Widget:EnabledForStyle(style, unit)
  return not (style == "NameOnly" or style == "NameOnly-Unique" or style == "etotem")
end

function Widget:OnUnitAdded(widget_frame, unit)
  local db = TidyPlatesThreat.db.profile.targetWidget

  if db.theme == "default" or db.theme == "squarethin" then
    local backdrop = BACKDROP[db.theme]
    widget_frame:SetPoint("TOPLEFT", widget_frame:GetParent().visual.healthbar, "TOPLEFT", - backdrop.offset, backdrop.offset)
    widget_frame:SetPoint("BOTTOMRIGHT", widget_frame:GetParent().visual.healthbar, "BOTTOMRIGHT", backdrop.offset, - backdrop.offset)
    widget_frame:SetBackdrop({
      --edgeFile = PATH .. db.theme,
      edgeFile = backdrop.edgeFile,
      edgeSize = backdrop.edgeSize,
      insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    widget_frame:SetBackdropBorderColor(db.r, db.g, db.b, db.a)

    widget_frame.LeftTexture:Hide()
    widget_frame.RightTexture:Hide()
  else
    widget_frame.LeftTexture:SetTexture(PATH .. db.theme)
    widget_frame.LeftTexture:SetTexCoord(0, 0.25, 0, 1)
    widget_frame.LeftTexture:SetVertexColor(db.r, db.g, db.b, db.a)
    widget_frame.LeftTexture:Show()

    widget_frame.RightTexture:SetTexture(PATH .. db.theme)
    widget_frame.RightTexture:SetTexCoord(0.75, 1, 0, 1)
    widget_frame.RightTexture:SetVertexColor(db.r, db.g, db.b, db.a)
    widget_frame.RightTexture:Show()

    widget_frame:SetBackdrop(nil)
  end

  if UnitIsUnit("target", unit.unitid) then
    widget_frame:Show()
    CurrentTarget = widget_frame
  else
    widget_frame:Hide()
  end

  -- self:OnTargetChanged(widget_frame, unit)
end

--function Widget:OnTargetChanged(widget_frame, unit)
--  if UnitIsUnit("target", unit.unitid) then
--    widget_frame:Show()
--  else
--    widget_frame:Hide()
--  end
--end