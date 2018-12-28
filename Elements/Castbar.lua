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
local UnitIsUnit = UnitIsUnit

-- ThreatPlates APIs
local ThreatPlates = Addon.ThreatPlates
local TidyPlatesThreat = TidyPlatesThreat
local SetFontJustify = Addon.Font.SetJustify
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish

local ART_PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Artwork\\"
local INTERRUPT_BORDER_BACKDROP = {
  edgeFile = ART_PATH .. "TP_WhiteSquare",
  edgeSize = 1,
  --insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------
local Element = Addon.Elements.NewElement("Castbar")

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

---------------------------------------------------------------------------------------------------
-- Core element code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
  local castbar = CreateFrame("StatusBar", nil, tp_frame)
  castbar:SetFrameLevel(tp_frame:GetFrameLevel() + 4)
  castbar:Hide()

  castbar.Border = CreateFrame("Frame", nil, castbar)
  castbar.InterruptBorder = CreateFrame("Frame", nil, castbar)
  castbar.Overlay = CreateFrame("Frame", nil, castbar)

  castbar.Border:SetFrameLevel(castbar:GetFrameLevel())
  -- frame.InterruptBorder:SetFrameLevel(frame:GetFrameLevel())
  -- frame.Overlay:SetFrameLevel(parent:GetFrameLevel() + 1)

  castbar.InterruptOverlay = castbar.Overlay:CreateTexture(nil, "BORDER", 0)
  castbar.InterruptShield = castbar.Overlay:CreateTexture(nil, "ARTWORK", -8)

  castbar.InterruptOverlay:SetTexture(ART_PATH .. "Striped_Texture")
  castbar.InterruptOverlay:SetAllPoints(castbar)
  castbar.InterruptOverlay:SetVertexColor(1, 0, 0, 1)

  --frame.InterruptShield:SetAtlas("nameplates-InterruptShield", true)
  castbar.InterruptShield:SetTexture(ART_PATH .. "Interrupt_Shield")
  castbar.InterruptShield:SetPoint("CENTER", castbar, "LEFT")

  castbar.SetAllColors = SetAllColors
  castbar.SetShownInterruptOverlay = SetShownInterruptOverlay

  castbar:SetStatusBarColor(1, 0.8, 0)

  local spell_text = castbar.Overlay:CreateFontString(nil, "OVERLAY")

  castbar.IsCasting = false
  castbar.IsChanneling = false
  castbar.FlashTime = 0
  castbar.Value = 0
  castbar.MaxValue = 0

  castbar:SetScript("OnUpdate", OnUpdate)
  castbar:SetScript("OnHide", OnHide)
  castbar:SetScript("OnSizeChanged", OnSizeChanged)

  tp_frame.visual.Castbar = castbar
  tp_frame.visual.SpellText = spell_text
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function Element.UnitAdded(tp_frame)
end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
function Element.UnitRemoved(tp_frame)
end

-- Called in processing event: UpdateStyle in Nameplate.lua
function Element.UpdateStyle(tp_frame, style)
  local unit = tp_frame.unit

  local target_offset_x, target_offset_y = 0, 0
  if UnitIsUnit("target", unit.unitid) then
    local db = TidyPlatesThreat.db.profile.settings.castbar
    target_offset_x = db.x_target
    target_offset_y = db.y_target
  end

  local castbar, castbar_style = tp_frame.visual.Castbar, style.castbar
  if castbar_style.show then
    local castborder_style = style.castborder

    -- Set castbar color here otherwise it may be shown sometimes with non-initialized backdrop color (white)
    castbar:SetStatusBarTexture(castbar_style.texture)
    castbar:SetSize(castbar_style.width, castbar_style.height)
    castbar:ClearAllPoints()
    castbar:SetPoint(castbar_style.anchor, tp_frame, castbar_style.anchor, castbar_style.x + target_offset_x, castbar_style.y + target_offset_y)

    local offset = castborder_style.offset
    local border = castbar.Border
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", castbar, "TOPLEFT", - offset, offset)
    border:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", offset, - offset)
    border:SetBackdrop({
      bgFile = castbar_style.backdrop,
      edgeFile = castborder_style.texture,
      edgeSize = castborder_style.edgesize,
      insets = { left = offset, right = offset, top = offset, bottom = offset },
    })
    border:SetBackdropBorderColor(0, 0, 0, 1)

    border = castbar.InterruptBorder
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", castbar, "TOPLEFT", - offset - 1, offset + 1)
    border:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", offset + 1, - offset - 1)
    border:SetBackdrop(INTERRUPT_BORDER_BACKDROP)
    border:SetBackdropBorderColor(1, 0, 0, 1)

    castbar:SetAllColors(Addon:SetCastbarColor(unit))
    castbar:Show()
  else
    castbar:Hide()
  end

  local spell_text, spell_text_style = tp_frame.visual.SpellText, style.spelltext

  -- At least font must be set as otherwise it results in a Lua error when UnitAdded with SetText is called
  spell_text:SetFont(spell_text_style.typeface, spell_text_style.size, spell_text_style.flags)

  if spell_text_style.show then
    SetFontJustify(spell_text, spell_text_style.align, spell_text_style.vertical)
    if spell_text_style.shadow then
      spell_text:SetShadowColor(0,0,0, 1)
      spell_text:SetShadowOffset(1, -1)
    else
      spell_text:SetShadowColor(0,0,0,0)
    end

    spell_text:ClearAllPoints()
    spell_text:SetPoint(spell_text_style.anchor, tp_frame, spell_text_style.anchor, spell_text_style.x + target_offset_x, spell_text_style.y + target_offset_y)
    spell_text:Show()
  else
      spell_text:Hide()
  end
end

--function Element.UpdateSettings()
--end

local function TargetUpdate(tp_frame)
  local castbar, castbar_style = tp_frame.visual.Castbar, tp_frame.style.castbar
  local spell_text, spell_text_style = tp_frame.visual.SpellText, tp_frame.style.spelltext

  local target_offset_x, target_offset_y = 0, 0
  if UnitIsUnit("target", tp_frame.unit.unitid) then
    local db = TidyPlatesThreat.db.profile.settings.castbar
    target_offset_x = db.x_target
    target_offset_y = db.y_target
  end

  castbar:ClearAllPoints()
  castbar:SetPoint(castbar_style.anchor, tp_frame, castbar_style.anchor, castbar_style.x + target_offset_x, castbar_style.y + target_offset_y)

  spell_text:ClearAllPoints()
  spell_text:SetPoint(spell_text_style.anchor, tp_frame, spell_text_style.anchor, spell_text_style.x + target_offset_x, spell_text_style.y + target_offset_y)
end

SubscribeEvent(Element, "TargetGained", TargetUpdate)
SubscribeEvent(Element, "TargetLost", TargetUpdate)

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
      local castbar = visual.Castbar

      if ShowOnUnit(plate.TPFrame.unit) then
        ConfigModePlate = plate

        castbar:SetScript("OnUpdate", function(self, elapsed)
          if ShowOnUnit(plate.TPFrame.unit) then
            self:SetMinMaxValues(0, 100)
            self:SetValue(50)
            visual.SpellIcon:SetTexture(GetSpellTexture(252616))
            visual.SpellText:SetText("Cosmic Beacon")

            self.Border:SetShown(plate.TPFrame.style.castborder.show)
            self:SetShownInterruptOverlay(plate.TPFrame.style.castnostop.show)
            self.InterruptShield:SetShown(TidyPlatesThreat.db.profile.settings.castnostop.ShowInterruptShield)
            visual.SpellText:SetShown(plate.TPFrame.style.spelltext.show)
            visual.SpellIcon:SetShown(plate.TPFrame.style.spellicon.show)
            self:Show()
          else
            self:SetValue(0) -- don't use self:_Hide() here, otherwise OnUpdate will never be called again
            self.Border:Hide()
            self.InterruptBorder:Hide()
            self.InterruptOverlay:Hide()
            self.InterruptShield:Hide()
            visual.SpellText:Hide()
            visual.SpellIcon:Hide()
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
    local castbar = ConfigModePlate.TPFrame.visual.Castbar
    castbar:SetScript("OnUpdate", OnUpdate)
    castbar.Hide = castbar._Hide
    castbar:Hide()
    EnabledConfigMode = false

    Addon:ForceUpdateOnNameplate(ConfigModePlate)
  end
end