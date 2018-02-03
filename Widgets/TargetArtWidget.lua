local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

-----------------------
-- Target Art Widget --
-----------------------

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitGUID = UnitGUID

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\TargetArtWidget\\"
-- local WidgetList = {}

local BACKDROP = {
  default = {
    edgeFile = PATH .. "TP_Target_Default",
    edgeSize = 7,
    inset = 5,
  },
  squarethin = {
    edgeFile = PATH .. "TP_Target_Thin",
    edgeSize = 4,
    inset = 3,
  }
}

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function enabled()
	return TidyPlatesThreat.db.profile.targetWidget.ON
end

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
-- 	for _, widget in pairs(WidgetList) do
-- 		widget:Hide()
-- 	end
-- 	WidgetList = {}
-- end
-- ThreatPlatesWidgets.ClearAllTargetArtWidgets = ClearAllWidgets

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function UpdateSettings(frame)
  local db = TidyPlatesThreat.db.profile.targetWidget

  -- probably this should be moved to UpdateWidgetFrame
  if db.theme == "default" or db.theme == "squarethin" then
    local backdrop = BACKDROP[db.theme]

    --  backdrop.edgeSize = TidyPlatesThreat.db.profile.targetWidget.EdgeSize
    --  backdrop.inset = TidyPlatesThreat.db.profile.targetWidget.Offset

    db = TidyPlatesThreat.db.profile.settings.healthbar
    local offset_x = db.width + 2 * backdrop.inset
    local offset_y = db.height + 2 * backdrop.inset
    if frame:GetWidth() ~= offset_x or frame:GetHeight() ~= offset_y  then
      frame:SetPoint("TOPLEFT", frame:GetParent().visual.healthbar, "TOPLEFT", - backdrop.inset, backdrop.inset)
      frame:SetPoint("BOTTOMRIGHT", frame:GetParent().visual.healthbar, "BOTTOMRIGHT", backdrop.inset, - backdrop.inset)
      -- frame:SetSize(offset_x, offset_y)
    end
    frame:SetBackdrop({
      --edgeFile = PATH .. db.theme,
      edgeFile = backdrop.edgeFile,
      edgeSize = backdrop.edgeSize,
      insets = { left = backdrop.inset, right = backdrop.inset, top = backdrop.inset, bottom = backdrop.inset }
    })

    frame.LeftTexture:Hide()
    frame.RightTexture:Hide()
  else
    frame.LeftTexture:SetTexture(PATH .. db.theme)
    frame.LeftTexture:SetTexCoord(0, 0.25, 0, 1)
    frame.LeftTexture:SetVertexColor(db.r, db.g, db.b, db.a)
    frame.LeftTexture:Show()

    frame.RightTexture:SetTexture(PATH .. db.theme)
    frame.RightTexture:SetTexCoord(0.75, 1, 0, 1)
    frame.RightTexture:SetVertexColor(db.r, db.g, db.b, db.a)
    frame.RightTexture:Show()

    frame:SetBackdrop(nil)
  end

  local OFFSET_THREAT = TidyPlatesThreat.db.profile.Offset or 6
  local healthbar = frame:GetParent().visual.healthbar
  healthbar.ThreatBorder:SetPoint("TOPLEFT", healthbar, "TOPLEFT", - OFFSET_THREAT, OFFSET_THREAT)
  healthbar.ThreatBorder:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMRIGHT", OFFSET_THREAT, - OFFSET_THREAT)
  healthbar.ThreatBorder:SetBackdrop({
    edgeFile = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Artwork\\" .. "TP_Threat",
    edgeSize = TidyPlatesThreat.db.profile.EdgeSize or 10,
    insets = { left = OFFSET_THREAT, right = OFFSET_THREAT, top = OFFSET_THREAT, bottom = OFFSET_THREAT },
  })
  healthbar.ThreatBorder:SetBackdropBorderColor(0, 1, 0, 1)
  healthbar.ThreatBorder:Show()

end

local function UpdateWidgetFrame(frame, unit)
  if unit.TP_Style == "etotem" then
    frame:_Hide()
  else
    frame:Show()
  end
end

-- Context
local function UpdateWidgetContext(frame, unit)
	local guid = unit.guid
	frame.guid = guid

	-- Add to Widget List
	-- if guid then
	-- 	WidgetList[guid] = frame
	-- end

	-- Custom Code II
	--------------------------------------
	if UnitGUID("target") == guid then
		UpdateWidgetFrame(frame, unit)
	else
		frame:_Hide()
	end
	--------------------------------------
	-- End Custom Code
end

local function ClearWidgetContext(frame)
	local guid = frame.guid
	if guid then
		-- WidgetList[guid] = nil
		frame.guid = nil
	end
end

local function CreateWidgetFrame(parent)
	-- Required Widget Code
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()

	-- Custom Code III
	--------------------------------------
	--frame:SetPoint("CENTER", parent, "CENTER")
  frame:SetFrameLevel(parent:GetFrameLevel() + 6)

	frame.LeftTexture = frame:CreateTexture(nil, "BACKGROUND", 0)
  frame.LeftTexture:SetPoint("RIGHT", parent, "LEFT")
  frame.LeftTexture:SetSize(64, 64)
  frame.RightTexture = frame:CreateTexture(nil, "BACKGROUND", 0)
  frame.RightTexture:SetPoint("LEFT", parent, "RIGHT")
  frame.RightTexture:SetSize(64, 64)

  UpdateSettings(frame)
  frame.UpdateConfig = UpdateSettings
	--------------------------------------
	-- End Custom Code

	-- Required Widget Code
	frame.UpdateContext = UpdateWidgetContext
	frame.Update = UpdateWidgetFrame
	frame._Hide = frame.Hide
	frame.Hide = function() ClearWidgetContext(frame); frame:_Hide()
	end

	return frame
end

ThreatPlatesWidgets.RegisterWidget("TargetArtWidgetTPTP", CreateWidgetFrame, true, enabled)
