---------------------------------------------------------------------------------------------------
-- Element: Castbar
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local string_format = string.format

-- WoW APIs
local CreateFrame = CreateFrame
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or _G.GetSpellTexture -- Retail now uses C_Spell.GetSpellTexture
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local UnitIsUnit = UnitIsUnit

-- ThreatPlates APIs
local SetCastbarColor = Addon.Color.SetCastbarColor
local FontSetJustify, FontUpdateText, FontUpdateTextSize = Addon.Font.SetJustify, Addon.Font.UpdateText, Addon.Font.UpdateTextSize
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish
local BackdropTemplate = Addon.BackdropTemplate

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
  if self.IsCasting or self.IsChanneling then
    self.Value = self.Value + elapsed

    local current_value = self.MaxValue - self.Value
    if current_value > 0 then
      self:SetValue(self.Value)
      self.CastTime:SetText(string_format("%.1f", current_value))
      self.Spark:SetPoint("CENTER", self:GetStatusBarTexture(), "RIGHT")
      return
    end

    self:SetValue(self.MaxValue)
  elseif (self.FlashTime > 0) then
    self.CastTime:SetText("")
    self.FlashTime = self.FlashTime - elapsed
    return
  end

  self:Hide()
  self:GetParent().unit.IsInterrupted = false
end

local function OnUpdateMidnight(self, elapsed)
  if self.IsCasting or self.IsChanneling then
    self:SetValue(GetTimePreciseSec() * 1000)
    --self.CastTime:SetText(string_format("%.1f", max_value - value))
    self.Spark:SetPoint("CENTER", self:GetStatusBarTexture(), "RIGHT")
  elseif self.FlashTime > 0 then
    self.CastTime:SetText("")
    self.FlashTime = self.FlashTime - elapsed
  else
    self:Hide()
    self:GetParent().unit.IsInterrupted = false
  end
end

local function OnHide(self)
  -- OnUpdateCastMidway is hiding the castbar if the unit is no longer casting
  -- So we have to show the castbar again
  if self.FlashTime > 0 then
    self:Show()
  end
end

local function OnSizeChanged(self, width, height)
  local scale_factor = height / 10
  self.InterruptShield:SetSize(14 * scale_factor, 16 * scale_factor)
  self.Spark:SetSize(3, self:GetHeight())
end

---------------------------------------------------------------------------------------------------
-- Basic castbar functions
---------------------------------------------------------------------------------------------------

local function SetAllColors(self, rBar, gBar, bBar, aBar, rBackdrop, gBackdrop, bBackdrop, aBackdrop)
  self:SetStatusBarColor(rBar or 1, gBar or 1, bBar or 1, aBar or 1)
  self.Background:SetVertexColor(rBackdrop or 1, gBackdrop or 1, bBackdrop or 1, aBackdrop or 1)
end

local function SetFormat(self, show)
  local db = Addon.db.profile.settings

  self.InterruptBorder:SetAlphaFromBoolean(show, 1, 0)
  self.InterruptOverlay:SetAlphaFromBoolean(show, 1, 0)
  self.InterruptShield:SetAlphaFromBoolean(show, 1, 0)

  if not db.castnostop.ShowInterruptShield then
    self.InterruptShield:Hide(db.castnostop.ShowInterruptShield)
  end
    
  if not db.castborder.show or not db.castnostop.ShowOverlay then
    self.InterruptBorder:Hide()
    self.InterruptOverlay:Hide()
  end

  self.Spark:SetShown(db.castbar.ShowSpark)
end

---------------------------------------------------------------------------------------------------
-- Core element code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_CREATED
function Element.PlateCreated(tp_frame)
  local castbar = CreateFrame("StatusBar", nil, tp_frame)
  -- ! Set the texture here; without a set texture, color changes with SetStatusBarColor will not be applied and
  -- ! the set color will be lost
  castbar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
  castbar:Hide()

  castbar.Border = CreateFrame("Frame", nil, castbar, BackdropTemplate)
  castbar.Background = castbar:CreateTexture(nil, "ARTWORK")
  castbar.InterruptBorder = CreateFrame("Frame", nil, castbar, BackdropTemplate)
  castbar.Overlay = CreateFrame("Frame", nil, castbar)

  castbar.InterruptOverlay = castbar.Overlay:CreateTexture(nil, "ARTWORK", nil, 2)
  castbar.InterruptShield = castbar.Overlay:CreateTexture(nil, "OVERLAY", nil, 0)

  castbar.InterruptOverlay:SetTexture(ART_PATH .. "Striped_Texture")
  castbar.InterruptOverlay:SetAllPoints(castbar)
  castbar.InterruptOverlay:SetVertexColor(1, 0, 0, 1)

  --frame.InterruptShield:SetAtlas("nameplates-InterruptShield", true)
  castbar.InterruptShield:SetTexture(ART_PATH .. "Interrupt_Shield")
  castbar.InterruptShield:SetPoint("CENTER", castbar, "LEFT")

  castbar.SetAllColors = SetAllColors
  castbar.SetFormat = SetFormat

  castbar:SetStatusBarColor(1, 0.8, 0)

  local spark = castbar:CreateTexture(nil, "ARTWORK", nil, 1)
  spark:SetTexture(ART_PATH .. "Spark")
  spark:SetBlendMode("ADD")
  castbar.Spark = spark

  local spell_text = castbar.Overlay:CreateFontString(nil, "ARTWORK")
  spell_text:SetFont("Fonts\\FRIZQT__.TTF", 11)
  spell_text:SetWordWrap(false) -- otherwise text is wrapped when plate is scaled down

  -- Remaining cast time
  castbar.CastTime = castbar.Overlay:CreateFontString(nil, "ARTWORK")
  castbar.CastTime:SetFont("Fonts\\FRIZQT__.TTF", 11)
  castbar.CastTime:SetAllPoints(castbar)
  castbar.CastTime:SetJustifyH("RIGHT")

  castbar.CastTarget = castbar:CreateFontString(nil, "ARTWORK")
  castbar.CastTarget:SetFont("Fonts\\FRIZQT__.TTF", 11)

  castbar.IsCasting = false
  castbar.IsChanneling = false
  castbar.FlashTime = 0
  castbar.Value = 0
  castbar.MaxValue = 0

  if Addon.ExpansionIsAtLeastMidnight then
    castbar:SetScript("OnUpdate", OnUpdateMidnight)
  else
    castbar:SetScript("OnUpdate", OnUpdate)
  end
  castbar:SetScript("OnHide", OnHide)
  castbar:SetScript("OnSizeChanged", OnSizeChanged)

  tp_frame.visual.Castbar = castbar
  tp_frame.visual.SpellText = spell_text
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function Element.PlateUnitAdded(tp_frame)
  tp_frame.visual.Castbar.FlashTime = 0  -- Set FlashTime to 0 so that the castbar is actually hidden (see statusbar OnHide hook function)
end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.PlateUnitRemoved(tp_frame)
--end

-- Called in processing event: UpdateStyle in Nameplate.lua
function Element.UpdateStyle(tp_frame, style)
  local unit = tp_frame.unit

  local db = Addon.db.profile.settings.castbar

  local target_offset_x, target_offset_y = 0, 0
  if UnitIsUnit("target", unit.unitid) then
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

    local background = castbar.Background
    background:SetTexture(castbar_style.backdrop)
    background:SetPoint("TOPLEFT", castbar:GetStatusBarTexture(), "TOPRIGHT")
    background:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT")

    local offset = castborder_style.offset
    local border = castbar.Border
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", castbar, "TOPLEFT", - offset, offset)
    border:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", offset, - offset)
    border:SetBackdrop({
      edgeFile = castborder_style.texture,
      edgeSize = castborder_style.edgesize,
      insets = { left = offset, right = offset, top = offset, bottom = offset },
    })
    border:SetBackdropBorderColor(0, 0, 0, 1)
    border:SetShown(castborder_style.show)


    border = castbar.InterruptBorder
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", castbar, "TOPLEFT", - offset - 1, offset + 1)
    border:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", offset + 1, - offset - 1)
    border:SetBackdrop(INTERRUPT_BORDER_BACKDROP)
    border:SetBackdropBorderColor(1, 0, 0, 1)

    castbar:SetAllColors(SetCastbarColor(unit))
    castbar:Show()
  else
    castbar:Hide()
  end

  local spell_text, spell_text_style = tp_frame.visual.SpellText, style.spelltext

  -- At least font must be set as otherwise it results in a Lua error when UnitAdded with SetText is called
  spell_text:SetFont(spell_text_style.typeface, spell_text_style.size, spell_text_style.flags)

  if spell_text_style.show then
    FontSetJustify(spell_text, spell_text_style.align, spell_text_style.vertical)
    if spell_text_style.shadow then
      spell_text:SetShadowColor(0,0,0, 1)
      spell_text:SetShadowOffset(1, -1)
    else
      spell_text:SetShadowColor(0,0,0,0)
    end

    spell_text:ClearAllPoints()
    spell_text:SetSize(spell_text_style.width, spell_text_style.height)
    spell_text:SetPoint(spell_text_style.anchor, castbar, spell_text_style.anchor, db.SpellNameText.HorizontalOffset + target_offset_x, db.SpellNameText.VerticalOffset + target_offset_y)

    spell_text:SetWordWrap(false)

    spell_text:Show()
  else
    spell_text:Hide()
  end

  local cast_time = castbar.CastTime

  cast_time:SetFont(spell_text_style.typeface, spell_text_style.size, spell_text_style.flags)
  if db.ShowCastTime then
    FontSetJustify(cast_time, db.CastTimeText.Font.HorizontalAlignment, db.CastTimeText.Font.VerticalAlignment)
    if spell_text_style.shadow then
      cast_time:SetShadowColor(0,0,0, 1)
      cast_time:SetShadowOffset(1, -1)
    else
      cast_time:SetShadowColor(0,0,0,0)
    end

    cast_time:ClearAllPoints()
    cast_time:SetSize(castbar:GetSize())
    cast_time:SetPoint("CENTER", castbar, "CENTER", db.CastTimeText.HorizontalOffset, db.CastTimeText.VerticalOffset)

    cast_time:Show()
  else
    cast_time:Hide()
  end

  FontUpdateText(castbar, castbar.CastTarget, db.CastTarget)
  FontUpdateTextSize(castbar, castbar.CastTarget, db.CastTarget)

  castbar.CastTarget:SetShown(db.CastTarget.Show)

  if db.FrameOrder == "HealthbarOverCastbar" then
    castbar:SetFrameLevel(castbar:GetParent():GetFrameLevel() + 2)
  else
    castbar:SetFrameLevel(castbar:GetParent():GetFrameLevel() + 5)
  end
  castbar.Border:SetFrameLevel(castbar:GetFrameLevel())
  --self.InterruptBorder:SetFrameLevel(self:GetFrameLevel())
  --self.Overlay:SetFrameLevel(self:GetFrameLevel())
end

--function Element.UpdateSettings()
--end

local function TargetUpdate(tp_frame)
  local castbar, castbar_style = tp_frame.visual.Castbar, tp_frame.style.castbar
  local spell_text, spell_text_style = tp_frame.visual.SpellText, tp_frame.style.spelltext

  local target_offset_x, target_offset_y = 0, 0
  if Addon.UnitIsTarget(tp_frame.unit.unitid) then
    local db = Addon.db.profile.settings.castbar
    target_offset_x = db.x_target
    target_offset_y = db.y_target
  end

  castbar:ClearAllPoints()
  castbar:SetPoint(castbar_style.anchor, tp_frame, castbar_style.anchor, castbar_style.x + target_offset_x, castbar_style.y + target_offset_y)
end

SubscribeEvent(Element, "TargetGained", TargetUpdate)
SubscribeEvent(Element, "TargetLost", TargetUpdate)

---------------------------------------------------------------------------------------------------
-- Show config mode
---------------------------------------------------------------------------------------------------

local EnabledConfigMode = false
local ConfigModePlate

local function ShowOnUnit(unit)
  local db = Addon.db.profile.settings.castbar

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
            local db = Addon.db.profile.settings

            self:SetMinMaxValues(0, 100)
            self:SetValue(50)
            visual.SpellIcon:SetTexture(GetSpellTexture(252616))
            visual.SpellText:SetText("Cosmic Beacon")
            self.CastTime:SetText(3.5)
            self.CastTarget:SetText("Temple Guard")

            self.Border:SetShown(plate.TPFrame.style.castborder.show)
            self:SetFormat(plate.TPFrame.style.castnostop.show)
            self.InterruptShield:SetShown(db.castnostop.ShowInterruptShield)

            self.Spark:SetSize(3, self:GetHeight() + 1)
            self.Spark:SetPoint("CENTER", self, "LEFT", 0.5 * self:GetWidth(), 0)

            visual.SpellText:SetShown(plate.TPFrame.style.spelltext.show)
            self.CastTime:SetShown(db.castbar.ShowCastTime)
            visual.SpellIcon:SetShown(plate.TPFrame.style.spellicon.show)
            self.CastTarget:SetShown(db.castbar.CastTarget.Show)
            self:Show()
          else
            self:SetValue(0) -- don't use self:_Hide() here, otherwise OnUpdate will never be called again
            self.Border:Hide()
            self.InterruptBorder:Hide()
            self.InterruptOverlay:Hide()
            self.InterruptShield:Hide()
            self.Spark:Hide()
            visual.SpellText:Hide()
            self.CastTime:Hide()
            visual.SpellIcon:Hide()
            self.CastTarget:Hide()
          end
        end)

        -- Fix an drawing error where the castbar background is shown white for a few milliseconds when changing
        -- a castbar setting several times in a second (e.g., moving a position slider left/right several times).
        --        castbar.SetStatusBarBackdrop = function(self, backdrop_texture, edge_texture, edge_size, offset)
        --          SetStatusBarBackdropCastbar(self, backdrop_texture, edge_texture, edge_size, offset)
        --          self:SetAllColors(Color:SetCastbarColor(plate.TPFrame.unit))
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
      Addon.Logging.Warning(L["Please select a target unit to enable configuration mode."])
    end
  else
    local castbar = ConfigModePlate.TPFrame.visual.Castbar
    castbar:SetScript("OnUpdate", OnUpdate)
    castbar.Hide = castbar._Hide
    castbar:Hide()
    EnabledConfigMode = false

    if ConfigModePlate and ConfigModePlate.TPFrame.Active then
      Addon:ForceUpdateOnNameplate(ConfigModePlate)
    end
  end
end