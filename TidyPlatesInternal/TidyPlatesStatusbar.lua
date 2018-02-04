local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local GetSpellTexture = GetSpellTexture
local CreateFrame = CreateFrame

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local ART_PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Artwork\\"
local EMPTY_TEXTURE = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Empty"

local OFFSET_HIGHLIGHT = 1
local OFFSET_THREAT= 7

local fraction, range, value, barsize, final

local function UpdateBar(self)
	range = self.MaxVal - self.MinVal 
	value = self.Value - self.MinVal

	barsize = self.Dim or 1
	
	if range > 0 and value > 0 and range >= value then
		fraction = value / range
	else fraction = .01 end
	if self.Orientation == "VERTICAL" then 
		self.Bar:SetHeight(barsize * fraction)
		final = self.Bottom - ((self.Bottom - self.Top) * fraction)		-- bottom = 1, top = 0
		self.Bar:SetTexCoord(self.Left, self.Right, final, self.Bottom)
		--self.Bar:SetTexCoord(0, 1, 1-fraction, 1)
	else 
		self.Bar:SetWidth(barsize * fraction) 
		final = ((self.Right - self.Left) * fraction) + self.Left
		self.Bar:SetTexCoord(self.Left, final, self.Top, self.Bottom)
	end

end

local function UpdateSize(self)
	if self.Orientation == "VERTICAL" then self.Dim = self:GetHeight()
	else self.Dim = self:GetWidth() end
	UpdateBar(self)
end

local function SetValue(self, value) 
	if value >= self.MinVal and value <= self.MaxVal then self.Value = value end; 
	UpdateBar(self) 
end
	
local function SetStatusBarTexture(self, texture) self.Bar:SetTexture(texture) end
local function SetStatusBarColor(self, r, g, b, a) self.Bar:SetVertexColor(r,g,b,a) end
local function SetStatusBarGradient(self, r1, g1, b1, a1, r2, g2, b2, a2) self.Bar:SetGradientAlpha(self.Orientation, r1, g1, b1, a1, r2, g2, b2, a2) end

--[[
local function SetStatusBarGradientAuto(self, r, g, b, a) 
	self.Bar:SetGradientAlpha(self.Orientation, .5+(r*1.1), g*.7, b*.7, a, r*.7, g*.7, .5+(b*1.1), a) 
end

local function SetStatusBarSmartGradient(self, r1, g1, b1, r2, g2, b2) 
	self.Bar:SetGradientAlpha(self.Orientation, r1, g1, b1, 1, r2 or r1, g2 or g1, b2 or b1, 1) 
end
--]]

local function SetAllColors(self, rBar, gBar, bBar, aBar, rBackdrop, gBackdrop, bBackdrop, aBackdrop) 
	self.Bar:SetVertexColor(rBar or 1, gBar or 1, bBar or 1, aBar or 1)
	self.Backdrop:SetVertexColor(rBackdrop or 1, gBackdrop or 1, bBackdrop or 1, aBackdrop or 1)
end

local function SetOrientation(self, orientation) 
	if orientation == "VERTICAL" then
		self.Orientation = orientation
		self.Bar:ClearAllPoints()
		self.Bar:SetPoint("BOTTOMLEFT")
		self.Bar:SetPoint("BOTTOMRIGHT")
	else
		self.Orientation = "HORIZONTAL"
		self.Bar:ClearAllPoints()
		self.Bar:SetPoint("TOPLEFT")
		self.Bar:SetPoint("BOTTOMLEFT")
	end
	UpdateSize(self)
end

local function GetMinMaxValues(self)
	return self.MinVal, self.MaxVal
end


local function SetMinMaxValues(self, minval, maxval)
	if not (minval or maxval) then return end
	
	if maxval > minval then
		self.MinVal = minval
		self.MaxVal = maxval
	else 
		self.MinVal = 0
		self.MaxVal = 1
	end
	
	if self.Value > self.MaxVal then self.Value = self.MaxVal
	elseif self.Value < self.MinVal then self.Value = self.MinVal end
	
	UpdateBar(self) 
end

local function SetTexCoord(self, left,right,top,bottom)		-- 0. 1. 0. 1
	self.Left, self.Right, self.Top, self.Bottom = left or 0, right or 1, top or 0, bottom or 1
	UpdateBar(self) 
end

local function SetBackdropTexCoord(self, left,right,top,bottom)		-- 0. 1. 0. 1
	self.Backdrop:SetTexCoord(left or 0, right or 1,top or 0, bottom or 1)
end

local function SetBackdropTexture(self, texture)		-- 0. 1. 0. 1
	self.Backdrop:SetTexture(texture)
end

function CreateTidyPlatesInternalStatusbar(parent)
	local frame = CreateFrame("Frame", nil, parent)
	--frame:SetFrameLevel(0)

	--frame.Dim = 1
	frame:SetHeight(1)
	frame:SetWidth(1)
	frame.Value, frame.MinVal, frame.MaxVal, frame.Orientation = 1, 0, 1, "HORIZONTAL"
	frame.Left, frame.Right, frame.Top, frame.Bottom = 0, 1, 0, 1
	frame.Bar = frame:CreateTexture(nil, "BORDER", -8)
	frame.Backdrop = frame:CreateTexture(nil, "BACKGROUND")
	frame.Backdrop:SetAllPoints(frame)
        
        --AddBorders(frame)
	
	frame.SetValue = SetValue
	frame.SetMinMaxValues = SetMinMaxValues
	frame.GetMinMaxValues = GetMinMaxValues
	frame.SetOrientation = SetOrientation
	frame.SetStatusBarColor = SetStatusBarColor
	frame.SetStatusBarGradient = SetStatusBarGradient
	--frame.SetStatusBarGradientAuto = SetStatusBarGradientAuto
	--frame.SetStatusBarSmartGradient = SetStatusBarSmartGradient
	frame.SetAllColors = SetAllColors
	frame.SetStatusBarTexture = SetStatusBarTexture
	frame.SetTexCoord = SetTexCoord
	frame.SetBackdropTexCoord = SetBackdropTexCoord
	frame.SetBackdropTexture = SetBackdropTexture

  frame:SetScript("OnSizeChanged", UpdateSize)
	UpdateSize(frame)

	return frame
end

------------------------------------------------------------------------------------------------------------

--local function OnSizeChanged(self, width, height)
--  self.Border:SetSize(width + 2 * BORDER_OFFSET, height + 2 * BORDER_OFFSET)
--end

local function SetAllColorsNew(self, rBar, gBar, bBar, aBar, rBackdrop, gBackdrop, bBackdrop, aBackdrop)
  self:SetStatusBarColor(rBar or 1, gBar or 1, bBar or 1, aBar or 1)
  self.Border:SetBackdropColor(rBackdrop or 1, gBackdrop or 1, bBackdrop or 1, aBackdrop or 1)
end

local function SetStatusBackdrop(self, backdrop_texture, edge_texture, edge_size, offset)
  self.Border.BackdropBorder = edge_texture -- TODO: not ideal to store this in every frame, as it's the same for every frame, but not for healthbar/castbar

  self.Border:ClearAllPoints()
  self.Border:SetPoint("TOPLEFT", self, "TOPLEFT", - offset, offset)
  self.Border:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", offset, - offset)
  self.Border:SetBackdrop({
    bgFile = backdrop_texture,
    edgeFile = edge_texture,
    edgeSize = edge_size,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  self.Border:SetBackdropBorderColor(0, 0, 0, 1)
end

local function SetShownBorder(self, show_border)
  local backdrop = self.Border:GetBackdrop()

  if show_border then
    backdrop.edgeFile = self.Border.BackdropBorder
    self.Border:SetBackdrop(backdrop)
    self.Border:SetBackdropBorderColor(0, 0, 0, 1)
  else
    backdrop.edgeFile = nil
    self.Border:SetBackdrop(backdrop)
  end

  self.Border:Show()
end

function CreateThreatPlatesHealthbar(parent)
	local frame = CreateFrame("StatusBar", nil, parent)
  frame.Border = CreateFrame("Frame", nil, frame)
  frame.ThreatBorder = CreateFrame("Frame", nil, frame)
  frame.Highlight = CreateFrame("Frame", nil, frame)
  frame.HighlightTexture =  frame.Highlight:CreateTexture(nil, "ARTWORK", 0)

  frame:SetFrameLevel(parent:GetFrameLevel())
  frame.Border:SetFrameLevel(frame:GetFrameLevel())
  frame.ThreatBorder:SetFrameLevel(frame:GetFrameLevel())
  frame.Highlight:SetFrameLevel(frame:GetFrameLevel() + 1)

  frame.Highlight:SetPoint("TOPLEFT", frame, "TOPLEFT", - OFFSET_HIGHLIGHT, OFFSET_HIGHLIGHT)
  frame.Highlight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", OFFSET_HIGHLIGHT, - OFFSET_HIGHLIGHT)
  frame.Highlight:SetBackdrop({
    bgFile = EMPTY_TEXTURE,
    edgeFile = ART_PATH .. "TP_WhiteSquare",
    edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  frame.Highlight:SetBackdropBorderColor(1, 1, 1, 1)

  frame.ThreatBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", - OFFSET_THREAT, OFFSET_THREAT)
  frame.ThreatBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", OFFSET_THREAT, - OFFSET_THREAT)
  frame.ThreatBorder:SetBackdrop({
    bgFile = EMPTY_TEXTURE,
    edgeFile = ART_PATH .. "TP_Threat",
    edgeSize = 12,
    insets = { left = OFFSET_THREAT, right = OFFSET_THREAT, top = OFFSET_THREAT, bottom = OFFSET_THREAT },
  })

  frame.HighlightTexture:SetTexture(ART_PATH .. "TP_HealthBar_Highlight")
  frame.HighlightTexture:SetBlendMode("ADD")
  frame.HighlightTexture:SetAllPoints(frame)

	frame.SetAllColors = SetAllColorsNew
  frame.SetTexCoord = function() end
	frame.SetBackdropTexCoord = function() end
  frame.SetStatusBackdrop = SetStatusBackdrop
  frame.SetShownBorder = SetShownBorder

	--frame:SetScript("OnSizeChanged", OnSizeChanged)
	return frame
end

---------------------------------------------------------------------------------------------------
-- Show config mode
---------------------------------------------------------------------------------------------------

local EnabledConfigMode = false
local ConfigModePlate

local function ShowOnUnit(unit)
  local db = TidyPlatesThreat.db.profile.settings.castbar

  local style = unit.TP_Style
  return style ~= "etotem" and style ~= "empty" and
    ((db.ShowInHeadlineView and (style == "NameOnly" or style == "NameOnly-Unique")) or
      (db.show and not (style == "NameOnly" or style == "NameOnly-Unique")))
end

function Addon:ConfigCastbar()
  if not EnabledConfigMode then
    local plate = GetNamePlateForUnit("target")
    if plate then
      local visual = plate.TP_Extended.visual
      local castbar = visual.castbar

      if ShowOnUnit(plate.TP_Extended.unit) then
        ConfigModePlate = plate

        castbar:SetScript("OnUpdate", function(self, elapsed)
          if ShowOnUnit(plate.TP_Extended.unit) then
            self:SetAllColors(TidyPlatesThreat.SetCastbarColor(plate.TP_Extended.unit))
            self:SetValue(castbar.MaxVal * 0.5)
            visual.spellicon:SetTexture(GetSpellTexture(252616))
            visual.spelltext:SetText("Cosmic Beacon")

            self.Bar:Show()
            self.Backdrop:Show()
            visual.spellicon:SetShown(plate.TP_Extended.style.spellicon.show)
            visual.castnostop:SetShown(plate.TP_Extended.style.castnostop.show)
            visual.castborder:SetShown(plate.TP_Extended.style.castborder.show)
            visual.spelltext:SetShown(plate.TP_Extended.style.spelltext.show)
            visual.castshield:SetShown(TidyPlatesThreat.db.profile.settings.castnostop.ShowInterruptShield)
          else
            self.Bar:Hide()
            self.Backdrop:Hide()
            visual.castshield:Hide()
            visual.spellicon:Hide()
            visual.castnostop:Hide()
            visual.castborder:Hide()
            visual.spelltext:Hide()
          end
        end)

        castbar._Hide = castbar.Hide
        castbar.Hide = function() end
        castbar:Show()
        EnabledConfigMode = true
        TidyPlatesInternal:ForceUpdate()
      elseif castbar._Hide then
          castbar:_Hide()
      end
    else
      ThreatPlates.Print("Please select a target unit to enable configuration mode.", true)
    end
  else
    local castbar = ConfigModePlate.TP_Extended.visual.castbar
    castbar:SetScript("OnUpdate", nil)
    castbar.Hide = castbar._Hide
    castbar.Bar:Hide()
    castbar.Backdrop:Hide()
    castbar:Hide()
    EnabledConfigMode = false
  end
end