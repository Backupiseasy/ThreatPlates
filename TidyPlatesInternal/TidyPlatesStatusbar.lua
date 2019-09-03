local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame
local GetSpellTexture = GetSpellTexture
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local ART_PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Artwork\\"
local EMPTY_TEXTURE = ART_PATH .. "Empty"

local OFFSET_THREAT= 7.5

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

local function OnUpdateCastBar(self, elapsed)
  if self.IsCasting then
    self.Value = self.Value + elapsed

    local value, max_value = self.Value, self.MaxValue
    if value < max_value then
      self:SetValue(value)
      self.Spark:SetPoint("CENTER", self, "LEFT", (value / max_value) * self:GetWidth(), 0)
      return
    end

    self:SetValue(max_value)
  elseif self.IsChanneling then
    self.Value = self.Value - elapsed

    local value = self.Value
    if value > 0 then
      self:SetValue(value)
      self.Spark:SetPoint("CENTER", self, "LEFT", (value / self.MaxValue) * self:GetWidth(), 0)
      return
    end
  elseif (self.FlashTime > 0) then
    self.FlashTime = self.FlashTime - elapsed
    return
  end

  self:Hide()
  self:GetParent().unit.IsInterrupted = false
end

local function OnHideCastBar(self)
  -- OnStopCasting is hiding the castbar and may be triggered before or after SPELL_INTERRUPT
  -- So we have to show the castbar again or not hide it if the interrupt message should still be shown.
  if self.FlashTime > 0 then
    self:Show()
  end
end

local function OnSizeChangedCastbar(self, width, height)
  local scale_factor = height / 10
  self.InterruptShield:SetSize(14 * scale_factor, 16 * scale_factor)
  self.Spark:SetSize(3, self:GetHeight())
end

local function SetAllColors(self, rBar, gBar, bBar, aBar, rBackdrop, gBackdrop, bBackdrop, aBackdrop)
  self:SetStatusBarColor(rBar or 1, gBar or 1, bBar or 1, aBar or 1)
  self.Background:SetVertexColor(rBackdrop or 1, gBackdrop or 1, bBackdrop or 1, aBackdrop or 1)
end

local function SetHealthBarTexture(self, style)
  self:SetStatusBarTexture(style.texture or EMPTY_TEXTURE)
  self.HealAbsorb:SetTexture(style.texture or EMPTY_TEXTURE, true, false)
end

local function SetStatusBarBackdropHealthbar(self, backdrop_texture, edge_texture, edge_size, offset)
  self.Background:SetTexture(backdrop_texture)
  self.Background:SetPoint("TOPLEFT", self:GetStatusBarTexture(), "TOPRIGHT")
  self.Background:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT")

  self.Border:ClearAllPoints()
  self.Border:SetPoint("TOPLEFT", self, "TOPLEFT", - offset, offset)
  self.Border:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", offset, - offset)
  self.Border:SetBackdrop({
    -- bgFile = backdrop_texture,
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

function Addon:CreateHealthbar(parent)
	local frame = CreateFrame("StatusBar", nil, parent)
  --frame:Hide()

  frame:SetFrameLevel(parent:GetFrameLevel() + 5)

  frame.Border = CreateFrame("Frame", nil, frame)
  frame.Background = frame:CreateTexture(nil, "BACKGROUND")
  frame.EliteBorder = CreateFrame("Frame", nil, frame)
  frame.ThreatBorder = CreateFrame("Frame", nil, frame)

  frame.Border:SetFrameLevel(frame:GetFrameLevel())
  frame.EliteBorder:SetFrameLevel(frame:GetFrameLevel() + 1)
  frame.ThreatBorder:SetFrameLevel(frame:GetFrameLevel())

  frame.ThreatBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", - OFFSET_THREAT, OFFSET_THREAT)
  frame.ThreatBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", OFFSET_THREAT, - OFFSET_THREAT)
  frame.ThreatBorder:SetBackdrop({
    edgeFile = ART_PATH .. "TP_Threat",
    edgeSize = 12,
    --insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  frame.ThreatBorder:SetBackdropBorderColor(0, 0, 0, 0) -- Transparent color as default

	frame.SetAllColors = SetAllColors
  frame.SetTexCoord = function() end
	frame.SetBackdropTexCoord = function() end
	frame.SetHealthBarTexture = SetHealthBarTexture
  frame.SetStatusBarBackdrop = SetStatusBarBackdropHealthbar
  frame.SetEliteBorder = SetEliteBorder

  local healabsorb_bar = frame:CreateTexture(nil, "OVERLAY", 0)
  healabsorb_bar:SetVertexColor(0, 0, 0)
  healabsorb_bar:SetAlpha(0.5)

  local healabsorb_glow = frame:CreateTexture(nil, "OVERLAY", 7)
  healabsorb_glow:SetTexture([[Interface\RaidFrame\Absorb-Overabsorb]])
  healabsorb_glow:SetBlendMode("ADD")
  healabsorb_glow:SetWidth(8)
  healabsorb_glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 2, 0)
  healabsorb_glow:SetPoint("TOPRIGHT", frame, "TOPLEFT", 2, 0)
  healabsorb_glow:Hide()

  frame.HealAbsorbLeftShadow = frame:CreateTexture(nil, "OVERLAY", 4)
  frame.HealAbsorbLeftShadow:SetTexture([[Interface\RaidFrame\Absorb-Edge]])
  frame.HealAbsorbRightShadow = frame:CreateTexture(nil, "OVERLAY", 4)
  frame.HealAbsorbRightShadow:SetTexture([[Interface\RaidFrame\Absorb-Edge]])
  frame.HealAbsorbRightShadow:SetTexCoord(1, 0, 0, 1) -- reverse texture (right to left)

  frame.HealAbsorb = healabsorb_bar
  frame.HealAbsorbGlow = healabsorb_glow

	--frame:SetScript("OnSizeChanged", OnSizeChanged)
	return frame
end

local function SetFormat(self, show)
  local db = TidyPlatesThreat.db.profile.settings

  if show then
    self.InterruptShield:SetShown(db.castnostop.ShowInterruptShield)
    if db.castborder.show and db.castnostop.ShowOverlay then
      self.InterruptBorder:Show()
      self.InterruptOverlay:Show()
    else
      self.InterruptBorder:Hide()
      self.InterruptOverlay:Hide()
    end
  else
    self.InterruptBorder:Hide()
    self.InterruptOverlay:Hide()
    self.InterruptShield:Hide()
  end

  self.Spark:SetShown(db.castbar.ShowSpark)
end

local function SetStatusBarBackdropCastbar(self, backdrop_texture, edge_texture, edge_size, offset)
  SetStatusBarBackdropHealthbar(self, backdrop_texture, edge_texture, edge_size, offset)

  self.InterruptBorder:ClearAllPoints()
  self.InterruptBorder:SetPoint("TOPLEFT", self, "TOPLEFT", - offset - 1, offset + 1)
  self.InterruptBorder:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", offset + 1, - offset - 1)
  self.InterruptBorder:SetBackdrop({
    edgeFile = ART_PATH .. "TP_WhiteSquare",
    edgeSize = 1,
    --insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  self.InterruptBorder:SetBackdropBorderColor(1, 0, 0, 1)
end

function Addon:CreateCastbar(parent)
  local frame = CreateFrame("StatusBar", nil, parent)
  frame:Hide()

  frame:SetFrameLevel(parent:GetFrameLevel() + 4)

  frame.Border = CreateFrame("Frame", nil, frame)
  frame.Background = frame:CreateTexture(nil, "BACKGROUND")
  frame.InterruptBorder = CreateFrame("Frame", nil, frame)
  frame.Overlay = CreateFrame("Frame", nil, frame)

  frame.Border:SetFrameLevel(frame:GetFrameLevel())
  -- frame.InterruptBorder:SetFrameLevel(frame:GetFrameLevel())
  -- frame.Overlay:SetFrameLevel(parent:GetFrameLevel() + 1)

  frame.InterruptOverlay = frame.Overlay:CreateTexture(nil, "BORDER", 0)
  frame.InterruptShield = frame.Overlay:CreateTexture(nil, "ARTWORK", -8)

  frame.InterruptOverlay:SetTexture(ART_PATH .. "Striped_Texture")
  frame.InterruptOverlay:SetAllPoints(frame)
  frame.InterruptOverlay:SetVertexColor(1, 0, 0, 1)

  --frame.InterruptShield:SetAtlas("nameplates-InterruptShield", true)
  frame.InterruptShield:SetTexture(ART_PATH .. "Interrupt_Shield")
  frame.InterruptShield:SetPoint("CENTER", frame, "LEFT")

  frame.SetAllColors = SetAllColors
  frame.SetTexCoord = function() end
  frame.SetBackdropTexCoord = function() end
  frame.SetStatusBarBackdrop = SetStatusBarBackdropCastbar
  frame.SetEliteBorder = SetEliteBorder
  frame.SetFormat = SetFormat

  frame:SetStatusBarColor(1, 0.8, 0)

  local spark = frame:CreateTexture(nil, "OVERLAY", 7)
  spark:SetTexture(ART_PATH .. "Spark")
  spark:SetBlendMode("ADD")
  frame.Spark = spark

--  frame.Flash = frame:CreateAnimationGroup()
--  local anim = frame.Flash:CreateAnimation("Alpha")
--  anim:SetOrder(1)
--  anim:SetFromAlpha(1)
--  anim:SetToAlpha(CASTBAR_FLASH_MIN_ALPHA)
--  anim:SetDuration(CASTBAR_FLASH_DURATION)
--  anim = frame.Flash:CreateAnimation("Alpha")
--  anim:SetOrder(2)
--  anim:SetFromAlpha(CASTBAR_FLASH_MIN_ALPHA)
--  anim:SetToAlpha(1)
--  anim:SetDuration(CASTBAR_FLASH_DURATION)
--  frame.Flash:SetScript("OnFinished", function(self)
--    self:GetParent():Hide()
--  end)

  frame.IsCasting = false
  frame.IsChanneling = false
  frame.FlashTime = 0
  frame.Value = 0
  frame.MaxValue = 0

  frame:SetScript("OnUpdate", OnUpdateCastBar)
  frame:SetScript("OnHide", OnHideCastBar)
  frame:SetScript("OnSizeChanged", OnSizeChangedCastbar)

  return frame
end

---------------------------------------------------------------------------------------------------
-- Show config mode
---------------------------------------------------------------------------------------------------

local EnabledConfigMode = false
local ConfigModePlate

local function ShowOnUnit(unit)
  local db = TidyPlatesThreat.db.profile.settings.castbar

  local style = unit.style
  return style ~= "etotem" and style ~= "empty" and
    ((db.ShowInHeadlineView and (style == "NameOnly" or style == "NameOnly-Unique")) or
      (db.show and not (style == "NameOnly" or style == "NameOnly-Unique")))
end

function Addon:ConfigCastbar()
  if not EnabledConfigMode then
    local plate = GetNamePlateForUnit("target")
    if plate then
      local visual = plate.TPFrame.visual
      local castbar = visual.castbar

      if ShowOnUnit(plate.TPFrame.unit) then
        ConfigModePlate = plate

        castbar:SetScript("OnUpdate", function(self, elapsed)
          if ShowOnUnit(plate.TPFrame.unit) then
            self:SetMinMaxValues(0, 100)
            self:SetValue(50)
            visual.spellicon:SetTexture(GetSpellTexture(116))
            visual.spelltext:SetText("Cosmic Beacon")

            self.Border:SetShown(plate.TPFrame.style.castborder.show)
            self:SetFormat(plate.TPFrame.style.castnostop.show)
            self.InterruptShield:SetShown(TidyPlatesThreat.db.profile.settings.castnostop.ShowInterruptShield)

            self.Spark:SetSize(3, self:GetHeight() + 1)
            self.Spark:SetPoint("CENTER", self, "LEFT", 0.5 * self:GetWidth(), 0)

            visual.spelltext:SetShown(plate.TPFrame.style.spelltext.show)
            visual.spellicon:SetShown(plate.TPFrame.style.spellicon.show)
            self:Show()
          else
            self:SetValue(0) -- don't use self:_Hide() here, otherwise OnUpdate will never be called again
            self.Border:Hide()
            self.InterruptBorder:Hide()
            self.InterruptOverlay:Hide()
            self.InterruptShield:Hide()
            self.Spark:Hide()
            visual.spelltext:Hide()
            visual.spellicon:Hide()
          end
        end)

        -- Fix an drawing error where the castbar background is shown white for a few milliseconds when changing
        -- a castbar setting several times in a second (e.g., moving a position slider left/right several times).
--        castbar.SetStatusBarBackdrop = function(self, backdrop_texture, edge_texture, edge_size, offset)
--          SetStatusBarBackdropCastbar(self, backdrop_texture, edge_texture, edge_size, offset)
--          self:SetAllColors(Addon:SetCastbarColor(plate.TPFrame.unit))
--        end

        castbar._Hide = castbar.Hide
        castbar.Hide = function() end

        castbar:Show()
        EnabledConfigMode = true
        Addon:ForceUpdate()
      elseif castbar._Hide then
        castbar:_Hide()
      end
    else
      ThreatPlates.Print("Please select a target unit to enable configuration mode.", true)
    end
  else
    local castbar = ConfigModePlate.TPFrame.visual.castbar
    castbar:SetScript("OnUpdate", OnUpdateCastBar)
    --castbar.SetStatusBarBackdropCastbar = SetStatusBarBackdropCastbar
    castbar.Hide = castbar._Hide
    castbar:Hide()
    EnabledConfigMode = false

    Addon:ForceUpdateOnNameplate(ConfigModePlate)
  end
end