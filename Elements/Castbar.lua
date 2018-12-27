---------------------------------------------------------------------------------------------------
-- Element: Castbar
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame
local GetSpellTexture = GetSpellTexture
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local ThreatPlates = Addon.ThreatPlates
local TidyPlatesThreat = TidyPlatesThreat

local ART_PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Artwork\\"
local INTERRUPT_BORDER_BACKDROP = {
  edgeFile = ART_PATH .. "TP_WhiteSquare",
  edgeSize = 1,
  --insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

---------------------------------------------------------------------------------------------------
-- Scripts (functions) for event handling
---------------------------------------------------------------------------------------------------

local function OnUpdate(self, elapsed)
  if self.IsCasting then
    self.Value = self.Value + elapsed

    if self.Value < self.MaxValue then
      self:SetValue(self.Value)
      return
    end

    self:SetValue(self.MaxValue)
  elseif self.IsChanneling then
    self.Value = self.Value - elapsed

    if self.Value > 0 then
      self:SetValue(self.Value)
      return
    end
  elseif (self.FlashTime > 0) then
    self.FlashTime = self.FlashTime - elapsed
    return
  end

  self:Hide()
end

local function OnHide(self)
  -- OnStopCasting is hiding the castbar and may be triggered before or after SPELL_INTERRUPT
  -- So we have to show the castbar again or not hide it if the interrupt message should still be shown.
  if self.FlashTime > 0 then
    self:Show()
  end
end

local function OnSizeChanged(self, width, height)
  local scale_factor = height / 10
  self.InterruptShield:SetSize(14 * scale_factor, 16 * scale_factor)
end

---------------------------------------------------------------------------------------------------
-- Basic castbar functions
---------------------------------------------------------------------------------------------------

local function SetAllColors(self, rBar, gBar, bBar, aBar, rBackdrop, gBackdrop, bBackdrop, aBackdrop)
  self:SetStatusBarColor(rBar or 1, gBar or 1, bBar or 1, aBar or 1)
  self.Border:SetBackdropColor(rBackdrop or 1, gBackdrop or 1, bBackdrop or 1, aBackdrop or 1)
end

local function SetShownInterruptOverlay(self, show)
  if show then
    local db = TidyPlatesThreat.db.profile.settings
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

  self.InterruptBorder:ClearAllPoints()
  self.InterruptBorder:SetPoint("TOPLEFT", self, "TOPLEFT", - offset - 1, offset + 1)
  self.InterruptBorder:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", offset + 1, - offset - 1)
  self.InterruptBorder:SetBackdrop(INTERRUPT_BORDER_BACKDROP)
  self.InterruptBorder:SetBackdropBorderColor(1, 0, 0, 1)
end

function Addon:CreateCastbar(tp_frame)
  local frame = CreateFrame("StatusBar", nil, tp_frame)
  frame:SetFrameLevel(tp_frame:GetFrameLevel() + 4)
  frame:Hide()

  frame.Border = CreateFrame("Frame", nil, frame)
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
  frame.SetStatusBarBackdrop = SetStatusBarBackdrop
  frame.SetShownInterruptOverlay = SetShownInterruptOverlay

  frame:SetStatusBarColor(1, 0.8, 0)

  frame.IsCasting = false
  frame.IsChanneling = false
  frame.FlashTime = 0
  frame.Value = 0
  frame.MaxValue = 0

  frame:SetScript("OnUpdate", OnUpdate)
  frame:SetScript("OnHide", OnHide)
  frame:SetScript("OnSizeChanged", OnSizeChanged)

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
            visual.spellicon:SetTexture(GetSpellTexture(252616))
            visual.spelltext:SetText("Cosmic Beacon")

            self.Border:SetShown(plate.TPFrame.style.castborder.show)
            self:SetShownInterruptOverlay(plate.TPFrame.style.castnostop.show)
            self.InterruptShield:SetShown(TidyPlatesThreat.db.profile.settings.castnostop.ShowInterruptShield)
            visual.spelltext:SetShown(plate.TPFrame.style.spelltext.show)
            visual.spellicon:SetShown(plate.TPFrame.style.spellicon.show)
            self:Show()
          else
            self:SetValue(0) -- don't use self:_Hide() here, otherwise OnUpdate will never be called again
            self.Border:Hide()
            self.InterruptBorder:Hide()
            self.InterruptOverlay:Hide()
            self.InterruptShield:Hide()
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
    castbar:SetScript("OnUpdate", OnUpdate)
    --castbar.SetStatusBarBackdropCastbar = SetStatusBarBackdropCastbar
    castbar.Hide = castbar._Hide
    castbar:Hide()
    EnabledConfigMode = false

    Addon:ForceUpdateOnNameplate(ConfigModePlate)
  end
end