local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

------------------------------
-- Elite Art Overlay Widget --
------------------------------

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitGUID = UnitGUID

-- local WidgetList = {}

local BACKDROP = {
  TP_EliteBorder_Default = {
    edgeFile = ThreatPlates.Art .. "TP_WhiteSquare",
    edgeSize = 2,
    offset = 2,
  },
  TP_EliteBorder_Thin = {
    edgeFile = ThreatPlates.Art .. "TP_WhiteSquare",
    edgeSize = 0.9,
    offset = 1.1,
  }
}

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function enabled()
	return TidyPlatesThreat.db.profile.settings.elitehealthborder.show
end

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
-- 	for _, widget in pairs(WidgetList) do
-- 		widget:Hide()
-- 	end
-- 	WidgetList = {}
-- end
-- ThreatPlatesWidgets.ClearAllEliteArtOverlayWidgets = ClearAllWidgets

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function UpdateSettings(frame)
	local db = TidyPlatesThreat.db.profile.settings.elitehealthborder
  local backdrop = BACKDROP[db.texture]

  --  backdrop.edgeSize = TidyPlatesThreat.db.profile.settings.elitehealthborder.EdgeSize
  --  backdrop.offset = TidyPlatesThreat.db.profile.settings.elitehealthborder.Offset

  db = TidyPlatesThreat.db.profile.settings.healthbar
  local offset_x = db.width + 2 * backdrop.offset
  local offset_y = db.height + 2 * backdrop.offset
  if frame:GetWidth() ~= offset_x or frame:GetHeight() ~= offset_y  then
    frame:SetPoint("TOPLEFT", frame:GetParent().visual.healthbar, "TOPLEFT", - backdrop.offset, backdrop.offset)
    frame:SetPoint("BOTTOMRIGHT", frame:GetParent().visual.healthbar, "BOTTOMRIGHT", backdrop.offset, - backdrop.offset)
    --    frame:SetSize(width, height)
  end
	frame:SetBackdrop({
    edgeFile = backdrop.edgeFile,
    edgeSize = backdrop.edgeSize,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
	})
	frame:SetBackdropBorderColor(1, 0.85, 0, 1)
end


local function UpdateWidgetFrame(frame, unit)
	if unit.isElite and not unit.isMouseover then
		frame:Show()
	else
		frame:_Hide()
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
	frame:SetFrameLevel(parent:GetFrameLevel() + 6)

	frame.UpdateConfig = UpdateSettings
	UpdateSettings(frame)
	--------------------------------------
	-- End Custom Code

	-- Required Widget Code
	frame.UpdateContext = UpdateWidgetContext
	frame.Update = UpdateWidgetFrame
	frame._Hide = frame.Hide
	frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end

	return frame
end

ThreatPlatesWidgets.RegisterWidget("EliteBorderTPTP", CreateWidgetFrame, false, enabled)
