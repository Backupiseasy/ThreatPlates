local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local ceil, string_format = ceil, string.format

-- WoW APIs
local GetSpellTexture = GetSpellTexture
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local Font = Addon.Font

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

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
      self.casttime:SetText(string_format("%.1f", max_value - value))
      self.Spark:SetPoint("CENTER", self, "LEFT", (value / max_value) * self:GetWidth(), 0)
      return
    end

    self:SetValue(max_value)
  elseif self.IsChanneling then
    self.Value = self.Value - elapsed

    local value = self.Value
    if value > 0 then
      self:SetValue(value)
      self.casttime:SetText(string_format("%.1f", value))
      self.Spark:SetPoint("CENTER", self, "LEFT", (value / self.MaxValue) * self:GetWidth(), 0)
      return
    end
  elseif (self.FlashTime > 0) then
    self.casttime:SetText("")
    self.FlashTime = self.FlashTime - elapsed
    return
  end

  self:Hide()
  self:GetParent().unit.IsInterrupted = false
end

local function OnHideCastBar(self)
  -- OnUpdateCastMidway is hiding the castbar if the unit is no longer casting
  -- So we have to show the castbar again
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

local function UpdateLayoutHealthbar(self, db, style)
  local healthbar_style, healthborder_style = style.healthbar, style.healthborder

  SetHealthBarTexture(self, healthbar_style)
  self:SetStatusBarBackdrop(healthbar_style.backdrop, healthborder_style.texture, healthborder_style.edgesize, healthborder_style.offset)
  self:SetShown(healthborder_style.show)
  SetEliteBorder(self, style.eliteborder.texture)

  local tp_frame = self:GetParent()
  if db.castbar.FrameOrder == "HealthbarOverCastbar" then
    self:SetFrameLevel(tp_frame:GetFrameLevel() + 5)
  else
    self:SetFrameLevel(tp_frame:GetFrameLevel() + 4)
  end
  tp_frame.visual.textframe:SetFrameLevel(self:GetFrameLevel())

  Font:UpdateText(self, self.TargetOfTarget, db.healthbar.TargetOfTarget)

  local width, height = self:GetSize()
  self.TargetOfTarget:SetSize(width, height)
  print ("Update:", db.healthbar.TargetOfTarget.Show, self.TargetOfTarget:GetText())
  self.TargetOfTarget:SetShown(self.TargetOfTarget:GetText() ~= nil)
end

local function SetTargetOfTarget(self, name)
  local target_of_target = self.TargetOfTarget

  if name then
    target_of_target:SetText(name)
  end

  local db = TidyPlatesThreat.db.profile.settings.healthbar.TargetOfTarget
  if db.UseNameplateColor then
    local r, g, b
    if self:IsShown() then
      r, g, b = self:GetStatusBarColor()
    else
      r, g, b = self:GetParent().visual.name:GetTextColor()
    end
    target_of_target:SetTextColor(r, g, b)
  else
    local color = db.CustomColor
    target_of_target:SetTextColor(color.r, color.g, color.b)
  end
end

function Addon:CreateHealthbar(parent)
	local frame = _G.CreateFrame("StatusBar", nil, parent)
  --frame:Hide()

  frame:SetFrameLevel(parent:GetFrameLevel() + 5)

  frame.Border = _G.CreateFrame("Frame", nil, frame)
  frame.Background = frame:CreateTexture(nil, "BACKGROUND")
  frame.EliteBorder = _G.CreateFrame("Frame", nil, frame)
  frame.ThreatBorder = _G.CreateFrame("Frame", nil, frame)

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
  frame.SetStatusBarBackdrop = SetStatusBarBackdropHealthbar
  frame.UpdateLayout = UpdateLayoutHealthbar
  frame.SetTargetOfTarget = SetTargetOfTarget

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

  frame.TargetOfTarget = frame:CreateFontString(nil, "ARTWORK")
  frame.TargetOfTarget:SetFont("Fonts\\FRIZQT__.TTF", 11)

	--frame:SetScript("OnSizeChanged", OnSizeChanged)
	return frame
end

--local function SetAllColorsCastbar(self, rBar, gBar, bBar, aBar, rBackdrop, gBackdrop, bBackdrop, aBackdrop)
--  --SetAllColors(self, rBar, gBar, bBar, aBar, rBackdrop, gBackdrop, bBackdrop, aBackdrop)
--  self:SetStatusBarColor(rBar or 1, gBar or 1, bBar or 1, aBar or 1)
--  self.Background:SetVertexColor(rBackdrop or 1, gBackdrop or 1, bBackdrop or 1, aBackdrop or 1)
--end

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

local function UpdateLayoutCastbar(self, db, style)
  local castbar_style, castborder_style = style.castbar, style.castborder

  self:SetStatusBarTexture(castbar_style.texture or EMPTY_TEXTURE)
  self:SetStatusBarBackdrop(castbar_style.backdrop, castborder_style.texture, castborder_style.edgesize, castborder_style.offset)
  self.Border:SetShown(castborder_style.show)

  if db.castbar.FrameOrder == "HealthbarOverCastbar" then
    self:SetFrameLevel(self:GetParent():GetFrameLevel() + 2)
  else
    self:SetFrameLevel(self:GetParent():GetFrameLevel() + 5)
  end
  self.Border:SetFrameLevel(self:GetFrameLevel())
  --self.InterruptBorder:SetFrameLevel(self:GetFrameLevel())
  --self.Overlay:SetFrameLevel(self:GetFrameLevel())

  Font:UpdateText(self, self.CastTarget, db.castbar.CastTarget)

  local width, height = self:GetSize()
  self.CastTarget:SetSize(width, height)
  self.CastTarget:SetShown(db.castbar.CastTarget.Show)
end

function Addon:CreateCastbar(parent)
  local frame = _G.CreateFrame("StatusBar", nil, parent)
  frame:Hide()

  frame.Border = _G.CreateFrame("Frame", nil, frame)
  frame.Background = frame:CreateTexture(nil, "BACKGROUND")
  frame.InterruptBorder = _G.CreateFrame("Frame", nil, frame)
  frame.Overlay = _G.CreateFrame("Frame", nil, frame)

  frame.InterruptOverlay = frame.Overlay:CreateTexture(nil, "BORDER", 0)
  frame.InterruptShield = frame.Overlay:CreateTexture(nil, "OVERLAY")

  frame.InterruptOverlay:SetTexture(ART_PATH .. "Striped_Texture")
  frame.InterruptOverlay:SetAllPoints(frame)
  frame.InterruptOverlay:SetVertexColor(1, 0, 0, 1)

  --frame.InterruptShield:SetAtlas("nameplates-InterruptShield", true)
  frame.InterruptShield:SetTexture(ART_PATH .. "Interrupt_Shield")
  frame.InterruptShield:SetPoint("CENTER", frame, "LEFT")

  frame.SetAllColors = SetAllColors
  frame.SetStatusBarBackdrop = SetStatusBarBackdropCastbar
  frame.SetFormat = SetFormat
  frame.UpdateLayout = UpdateLayoutCastbar

  frame:SetStatusBarColor(1, 0.8, 0)

  local spark = frame:CreateTexture(nil, "OVERLAY", 7)
  spark:SetTexture(ART_PATH .. "Spark")
  spark:SetBlendMode("ADD")
  frame.Spark = spark

  -- Remaining cast time
  frame.casttime = frame.Overlay:CreateFontString(nil, "ARTWORK")
  frame.casttime:SetFont("Fonts\\FRIZQT__.TTF", 11)
  frame.casttime:SetAllPoints(frame)
  frame.casttime:SetJustifyH("RIGHT")

  frame.CastTarget = frame:CreateFontString(nil, "ARTWORK")
  frame.CastTarget:SetFont("Fonts\\FRIZQT__.TTF", 11)

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
            local db = TidyPlatesThreat.db.profile.settings

            self:SetMinMaxValues(0, 100)
            self:SetValue(50)
            visual.spellicon:SetTexture(GetSpellTexture(116))
            visual.spelltext:SetText("Frostbolt")
            self.casttime:SetText(3.5)
            self.CastTarget:SetText("Temple Guard")

            self.Border:SetShown(plate.TPFrame.style.castborder.show)
            self:SetFormat(plate.TPFrame.style.castnostop.show)
            self.InterruptShield:SetShown(db.castnostop.ShowInterruptShield)

            self.Spark:SetSize(3, self:GetHeight() + 1)
            self.Spark:SetPoint("CENTER", self, "LEFT", 0.5 * self:GetWidth(), 0)

            visual.spelltext:SetShown(plate.TPFrame.style.spelltext.show)
            visual.castbar.casttime:SetShown(db.castbar.ShowCastTime)
            visual.spellicon:SetShown(plate.TPFrame.style.spellicon.show)
            self.CastTarget:SetShown(db.castbar.CastTarget.Show)
            self:Show()
          else
            self:SetValue(0) -- don't use self:_Hide() here, otherwise OnUpdate will never be called again
            self.Border:Hide()
            self.InterruptBorder:Hide()
            self.InterruptOverlay:Hide()
            self.InterruptShield:Hide()
            self.Spark:Hide()
            visual.spelltext:Hide()
            visual.castbar.casttime:Hide()
            visual.spellicon:Hide()
            self.CastTarget:Hide()
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

    if ConfigModePlate and ConfigModePlate.TPFrame.Active then
      Addon:ForceUpdateOnNameplate(ConfigModePlate)
    end
  end
end