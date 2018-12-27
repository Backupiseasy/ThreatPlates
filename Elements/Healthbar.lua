---------------------------------------------------------------------------------------------------
-- Element: Healthbar
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame

-- ThreatPlates APIs
local ThreatPlates = Addon.ThreatPlates

local ELITE_BACKDROP = {
  TP_EliteBorder_Default = {
    edgeFile = ThreatPlates.Art .. "TP_WhiteSquare",
    edgeSize = 1.5,
    offset = 1.8,
  },
  TP_EliteBorder_Thin = {
    edgeFile = ThreatPlates.Art .. "TP_WhiteSquare",
    edgeSize = 0.9,
    offset = 1.1,
  }
}

------------------------------------------------------------------------------------------------------------

local function SetAllColors(self, rBar, gBar, bBar, aBar, rBackdrop, gBackdrop, bBackdrop, aBackdrop)
  self:SetStatusBarColor(rBar or 1, gBar or 1, bBar or 1, aBar or 1)
  self.Border:SetBackdropColor(rBackdrop or 1, gBackdrop or 1, bBackdrop or 1, aBackdrop or 1)
end

local function SetStatusBarBackdrop(self, backdrop_texture, edge_texture, edge_size, offset)
  self.Border:ClearAllPoints()
  self.Border:SetPoint("TOPLEFT", self, "TOPLEFT", - offset, offset)
  self.Border:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", offset, - offset)
  self.Border:SetBackdrop({
    bgFile = backdrop_texture,
    edgeFile = edge_texture,
    edgeSize = edge_size,
    insets = { left = offset, right = offset, top = offset, bottom = offset },
  })
  self.Border:SetBackdropBorderColor(0, 0, 0, 1)
end

local function SetEliteBorder(self, texture)
  local backdrop = ELITE_BACKDROP[texture]

  self.EliteBorder:SetPoint("TOPLEFT", self, "TOPLEFT", - backdrop.offset, backdrop.offset)
  self.EliteBorder:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", backdrop.offset, - backdrop.offset)

  self.EliteBorder:SetBackdrop({
    edgeFile = backdrop.edgeFile,
    edgeSize = backdrop.edgeSize,
    --insets = { left = 0, right = 0, top = 0, bottom = 0 }
  })
  --self.EliteBorder:SetBackdropBorderColor(1, 0.85, 0, 1)
end

function Addon:CreateHealthbar(tp_frame)
	local frame = CreateFrame("StatusBar", nil, tp_frame)
  frame:SetFrameLevel(tp_frame:GetFrameLevel() + 5)
  --frame:Hide()

  frame.Border = CreateFrame("Frame", nil, frame)
  frame.EliteBorder = CreateFrame("Frame", nil, frame)

  frame.Border:SetFrameLevel(frame:GetFrameLevel())
  frame.EliteBorder:SetFrameLevel(frame:GetFrameLevel() + 1)

	frame.SetAllColors = SetAllColors
  frame.SetStatusBarBackdrop = SetStatusBarBackdrop
  frame.SetEliteBorder = SetEliteBorder

	--frame:SetScript("OnSizeChanged", OnSizeChanged)
	return frame
end
