---------------------------------------------------------------------------------------------------
-- Element: Healthbar
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local UnitIsUnit, UnitName, UnitClass = UnitIsUnit, UnitName, UnitClass
local UnitGetTotalHealAbsorbs = UnitGetTotalHealAbsorbs
local InCombatLockdown = InCombatLockdown

-- ThreatPlates APIs
local FontUpdateText, FontUpdateTextSize = Addon.Font.UpdateText, Addon.Font.UpdateTextSize
local SubscribeEvent, UnsubscribeEvent = Addon.EventService.Subscribe, Addon.EventService.Unsubscribe
local BackdropTemplate = Addon.BackdropTemplate
local TransliterateCyrillicLetters = Addon.Localization.TransliterateCyrillicLetters
local UnitIsUnitTP = Addon.UnitIsUnit

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, UnitHealth, UnitHealthMax, UnitGetTotalAbsorbs, CreateUnitHealPredictionCalculator, UnitGetDetailedHealPrediction

local IGNORED_STYLES = Addon.IGNORED_STYLES_WITH_NAMEMODE

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local Settings, SettingsHealthbar, SettingsTargetUnit, SettingsTargetUnitHide, SettingsShowOnlyForTarget

local COLOR_BLACK = Addon.RGB(0, 0, 0)

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------
local Element = Addon.Elements.NewElement("Healthbar")

---------------------------------------------------------------------------------------------------
-- Additional functions
---------------------------------------------------------------------------------------------------
-- Set to true to show hardcoded test values for all absorb UI elements (no target needed).
local ABSORBS_TEST_MODE = true

local UpdateAbsorbs

-- UnitGetTotalAbsorbs: Mists - Patch 5.2.0 (2013-03-05): Added.
-- UnitGetTotalHealAbsorbs: Mists - Patch 5.4.0 (2013-09-10): Added.
if Addon.WOW_FEATURE_ABSORBS then
  UpdateAbsorbs = function(tp_frame)
    local healthbar = tp_frame.visual.Healthbar

    if IGNORED_STYLES[tp_frame.style] then
      healthbar.HealAbsorbGlow:Hide()
      healthbar.HealAbsorb:Hide()
      healthbar.HealAbsorbLeftShadow:Hide()
      healthbar.HealAbsorbRightShadow:Hide()
      healthbar.AbsorbStatusBar:Hide()
      healthbar.AbsorbStatusBar.Overlay:Hide()
      healthbar.AbsorbStatusBar.Spark:Hide()
      return
    end

    if Addon.ExpansionIsAtLeastMidnight then
      -- Midnight path: use UnitHealPredictionCalculator.
      -- Values from the calculator are passed directly to C-API StatusBar methods (SetMinMaxValues,
      -- SetValue) and are safe to use even when they are secret values.
      local calc = healthbar.HealPredictionCalculator

      -- Heal absorbs: hidden on Midnight.
      healthbar.HealAbsorbGlow:Hide()
      healthbar.HealAbsorb:Hide()
      healthbar.HealAbsorbLeftShadow:Hide()
      healthbar.HealAbsorbRightShadow:Hide()

      if not calc then healthbar.AbsorbStatusBar:Hide(); return end

      -- Damage absorbs (shields): passed directly to C-API, safe with secret values.
      if Settings.ShowAbsorbs then
        local absorb_max, absorb_val, absorb_clamped
        if ABSORBS_TEST_MODE then
          -- Fake HP is also written to healthbar so AbsorbStatusBar anchor lands correctly.
          --   NPC        10% HP, 20% absorb → missing=90%, absorb<missing → val=20, no spark
          --   Friendly  30% HP, 40% absorb → missing=70%,  absorb<missing → val=40, no spark
          --   Enemy     70% HP, 50% absorb → missing=30%,  absorb>missing → val=30, spark
          local fake_health, fake_health_max
          if tp_frame.unit.type == "PLAYER" and tp_frame.unit.reaction == "FRIENDLY" then
            healthbar._test_friendly_variant = healthbar._test_friendly_variant or (math.random(2) == 1)
            if healthbar._test_friendly_variant then
              -- A: 30% HP, 40% shield absorb, no heal absorb
              fake_health, fake_health_max = 30000, 100000
              absorb_max, absorb_val, absorb_clamped = 100, 40, false
            else
              -- B: 70% HP, 20% shield absorb (heal absorb hidden on Midnight)
              fake_health, fake_health_max = 70000, 100000
              absorb_max, absorb_val, absorb_clamped = 100, 20, false
            end
          elseif tp_frame.unit.type == "PLAYER" then
            fake_health, fake_health_max = 70000, 100000
            absorb_max, absorb_val, absorb_clamped = 100, 30, true
          else
            healthbar._test_npc_variant = healthbar._test_npc_variant or (math.random(2) == 1)
            if healthbar._test_npc_variant then
              -- A: 10% HP, 20% absorb → fill visible, no spark
              fake_health, fake_health_max = 10000, 100000
              absorb_max, absorb_val, absorb_clamped = 100, 20, false
            else
              -- B: 100% HP, 20% absorb → missing=0, fill invisible, spark only
              fake_health, fake_health_max = 100000, 100000
              absorb_max, absorb_val, absorb_clamped = 100, 0, true
            end
          end
          healthbar:SetMinMaxValues(0, fake_health_max)
          healthbar:SetValue(fake_health)
        else
          local unitid = tp_frame.unit.unitid
          _G.UnitGetDetailedHealPrediction(unitid, nil, calc)
          calc:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.Default)
          absorb_max = calc:GetMaximumHealth()
          absorb_val, absorb_clamped = calc:GetDamageAbsorbs()
        end
        healthbar.AbsorbStatusBar:SetMinMaxValues(0, absorb_max)
        healthbar.AbsorbStatusBar:SetValue(absorb_val)
        healthbar.AbsorbStatusBar:Show()
        if Settings.OverlayTexture then
          healthbar.AbsorbStatusBar.Overlay:Show()
        else
          healthbar.AbsorbStatusBar.Overlay:Hide()
        end
        -- Spark: SetAlphaFromBoolean passes the secret 'clamped' bool directly to C-side alpha,
        -- avoiding a Lua branch on a potentially-secret value. Position is fixed (AlwaysFullAbsorb
        -- repositioning would require arithmetic on secret amounts).
        healthbar.AbsorbStatusBar.Spark:Show()
        healthbar.AbsorbStatusBar.Spark:SetAlphaFromBoolean(absorb_clamped, 1, 0)
      else
        healthbar.AbsorbStatusBar:Hide()
        healthbar.AbsorbStatusBar.Overlay:Hide()
        healthbar.AbsorbStatusBar.Spark:SetAlpha(0)
      end

      return
    end

    -- Non-Midnight path
    -- Code for absorb calculation see CompactUnitFrame.lua
    local health, health_max, heal_absorb, absorb
    if ABSORBS_TEST_MODE then
      -- Fake HP also written to healthbar so AbsorbStatusBar anchor lands correctly.
      --   NPC        10% HP, 20% absorb (absorb < missing → no spark)
      --   Friendly  30% HP, 40% absorb (absorb < missing → no spark)
      --   Enemy     70% HP, 50% absorb (absorb > missing → spark)
      if tp_frame.unit.type == "PLAYER" and tp_frame.unit.reaction == "FRIENDLY" then
        healthbar._test_friendly_variant = healthbar._test_friendly_variant or math.random(4)
        local fv = healthbar._test_friendly_variant
        if fv == 1 then
          -- 30% HP, 40% shield → fill, no spark, no heal absorb
          health, health_max, heal_absorb, absorb = 30000, 100000, 0, 40000
        elseif fv == 2 then
          -- 70% HP, 20% shield → fill, no spark, no heal absorb
          health, health_max, heal_absorb, absorb = 70000, 100000, 0, 20000
        elseif fv == 3 then
          -- 70% HP, 20% heal absorb + 20% shield → HealAbsorb (no glow) + both shadows + fill
          health, health_max, heal_absorb, absorb = 70000, 100000, 20000, 20000
        else
          -- 30% HP, 40% heal absorb, no shield → heal_absorb > health → HealAbsorbGlow + LeftShadow
          health, health_max, heal_absorb, absorb = 30000, 100000, 40000, 0
        end
      elseif tp_frame.unit.type == "PLAYER" then
        health, health_max, heal_absorb, absorb = 70000, 100000, 0, 50000
      else
        healthbar._test_npc_variant = healthbar._test_npc_variant or (math.random(2) == 1)
        if healthbar._test_npc_variant then
          -- A: 10% HP, 20% absorb → fill visible, no spark
          health, health_max, heal_absorb, absorb = 10000, 100000, 0, 20000
        else
          -- B: 100% HP, 20% absorb → missing=0, fill invisible, spark only
          health, health_max, heal_absorb, absorb = 100000, 100000, 0, 20000
        end
      end
      healthbar:SetMinMaxValues(0, health_max)
      healthbar:SetValue(health)
    else
      local unitid = tp_frame.unit.unitid
      health = _G.UnitHealth(unitid) or 0
      health_max = _G.UnitHealthMax(unitid) or 0
      heal_absorb = UnitGetTotalHealAbsorbs(unitid) or 0
      absorb = _G.UnitGetTotalAbsorbs(unitid) or 0
    end

    if health == 0 or health_max == 0 then
      healthbar.HealAbsorbGlow:Hide()
      healthbar.HealAbsorb:Hide()
      healthbar.HealAbsorbLeftShadow:Hide()
      healthbar.HealAbsorbRightShadow:Hide()
      healthbar.AbsorbStatusBar:Hide()
      healthbar.AbsorbStatusBar.Overlay:Hide()
      healthbar.AbsorbStatusBar.Spark:Hide()
      return
    end

    if Settings.ShowHealAbsorbs and heal_absorb > 0 then
      healthbar.HealAbsorbGlow:SetShown(heal_absorb > health)

      if heal_absorb > health then
        heal_absorb = health
      end

      local heal_absorb_pct = heal_absorb / health_max
      local healthbar_texture = healthbar:GetStatusBarTexture()
      healthbar.HealAbsorb:SetSize(heal_absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())
      healthbar.HealAbsorb:SetPoint("TOPRIGHT", healthbar_texture, "TOPRIGHT", 0, 0)
      healthbar.HealAbsorb:SetPoint("BOTTOMRIGHT", healthbar_texture, "BOTTOMRIGHT", 0, 0)
      healthbar.HealAbsorb:Show()

      local healabsorb_texture = healthbar.HealAbsorb
      healthbar.HealAbsorbLeftShadow:SetPoint("TOPLEFT", healabsorb_texture, "TOPLEFT", 0, 0);
      healthbar.HealAbsorbLeftShadow:SetPoint("BOTTOMLEFT", healabsorb_texture, "BOTTOMLEFT", 0, 0)
      healthbar.HealAbsorbLeftShadow:Show()

      -- The right shadow is only shown if there are absorbs on the health bar.
      if absorb > 0 and Settings.ShowAbsorbs then
        healthbar.HealAbsorbRightShadow:SetPoint("TOPLEFT", healabsorb_texture, "TOPRIGHT", -8, 0)
        healthbar.HealAbsorbRightShadow:SetPoint("BOTTOMLEFT", healabsorb_texture, "BOTTOMRIGHT", -8, 0)
        healthbar.HealAbsorbRightShadow:Show()
      else
        healthbar.HealAbsorbRightShadow:Hide()
      end
    else
      healthbar.HealAbsorbGlow:Hide()
      healthbar.HealAbsorb:Hide()
      healthbar.HealAbsorbLeftShadow:Hide()
      healthbar.HealAbsorbRightShadow:Hide()
    end

    -- Shield absorbs: StatusBar-based, clamped to missing health.
    if Settings.ShowAbsorbs and absorb > 0 and health_max > 0 then
      local missing_health = health_max - health
      healthbar.AbsorbStatusBar:SetMinMaxValues(0, health_max)
      healthbar.AbsorbStatusBar:SetValue(math.min(absorb, missing_health))
      healthbar.AbsorbStatusBar:Show()
      if Settings.OverlayTexture then
        healthbar.AbsorbStatusBar.Overlay:Show()
      else
        healthbar.AbsorbStatusBar.Overlay:Hide()
      end
      -- Spark: shown when absorb exceeds remaining health (over-absorb).
      if absorb > missing_health then
        local spark = healthbar.AbsorbStatusBar.Spark
        spark:ClearAllPoints()
        if Settings.AlwaysFullAbsorb then
          -- Position spark to indicate actual absorb amount (may extend left of right edge).
          local absorb_offset = math.min(absorb / health_max, 1) * healthbar:GetWidth()
          spark:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4 - absorb_offset, -1)
          spark:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4 - absorb_offset, 1)
        else
          spark:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4, -1)
          spark:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4, 1)
        end
        spark:Show()
      else
        healthbar.AbsorbStatusBar.Spark:Hide()
      end
    else
      healthbar.AbsorbStatusBar:Hide()
      healthbar.AbsorbStatusBar.Overlay:Hide()
      healthbar.AbsorbStatusBar.Spark:Hide()
    end
  end
else
  UpdateAbsorbs = function() end
end

local function HideTargetUnit(healthbar)
  healthbar.TargetUnit:SetText(nil)
  healthbar.TargetUnit:Hide()
end

local function ShowTargetUnit(healthbar, unitid)
  local target_of_target = healthbar.TargetUnit

  -- If just the color should be updated, unitid will be nil
  if unitid then
    local target_of_target_unit = unitid .. "target"
    if not SettingsTargetUnit.ShowNotMyself or not UnitIsUnitTP("player", target_of_target_unit) then
      local target_of_target_name = UnitName(target_of_target_unit)
      if target_of_target_name then
        target_of_target_name = 
        TransliterateCyrillicLetters(target_of_target_name)
        if SettingsTargetUnit.ShowBrackets then
          target_of_target_name = "|cffffffff[|r " .. target_of_target_name .. " |cffffffff]|r" 
        end
        target_of_target:SetText(target_of_target_name)

        local _, class_name = UnitClass(target_of_target_unit)   
        target_of_target.ClassName = class_name
        
        target_of_target:Show()
      else
        HideTargetUnit(healthbar)
      end
    else
      HideTargetUnit(healthbar)
    end
  end

  -- Update the color if the element is shown
  if target_of_target:IsShown() then
    local color
    if SettingsTargetUnit.UseClassColor and target_of_target.ClassName then
      color = Addon.db.profile.Colors.Classes[target_of_target.ClassName]
    else
      color = SettingsTargetUnit.CustomColor
    end
    target_of_target:SetTextColor(color.r, color.g, color.b)
  end
end

local function UpdateTargetUnit(healthbar, unitid)
  if Addon.ExpansionIsAtLeastMidnight then return end

  if SettingsTargetUnitHide or (SettingsShowOnlyForTarget and not UnitIsUnit("target", unitid)) or (SettingsTargetUnit.ShowOnlyInCombat and not InCombatLockdown()) then
    HideTargetUnit(healthbar)
  else
    ShowTargetUnit(healthbar, unitid)
  end
end

-- The event triggering this function is only subscribed for when target unit is enabled
local function UNIT_TARGET(unitid)
  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    UpdateTargetUnit(tp_frame.visual.Healthbar, unitid)
  end
end

-- The event triggering this function is only subscribed for when target unit is enabled
local function UnitThreatUpdate(tp_frame, unit)
  UpdateTargetUnit(tp_frame.visual.Healthbar, unit.unitid)
end

-- The event triggering this function is only subscribed for when target unit is enabled
local function PlayerTargetGained(tp_frame)
  UpdateTargetUnit(tp_frame.visual.Healthbar, tp_frame.unit.unitid)
end

-- The event triggering this function is only subscribed for when target unit is enabled
local function PlayerTargetLost(tp_frame)
  if SettingsShowOnlyForTarget and not Addon.UnitIsTarget(tp_frame.unit.unitid) then
    HideTargetUnit(tp_frame.visual.Healthbar)
  end
end

-- Also called directly from Element.UpdateStyle to restore the border color after SetBackdrop
-- resets it to white.
local function ColorUpdate(tp_frame, color)
  if tp_frame.PlateStyle ~= "HealthbarMode" then return end

  local healthbar = tp_frame.visual.Healthbar
  if Addon.ExpansionIsAtLeastMidnight then
    healthbar:GetStatusBarTexture():SetVertexColor(color.r, color.g, color.b)
  else
    healthbar:SetStatusBarColor(color.r, color.g, color.b, 1)
  end

  if not SettingsHealthbar.BackgroundUseForegroundColor then
    color = SettingsHealthbar.BackgroundColor
  end
  healthbar.Background:SetVertexColor(color.r, color.g, color.b, 1 - SettingsHealthbar.BackgroundOpacity)

  -- For simplicity, border color is uneffected by marks, threat, etc.
  local border_color
  if tp_frame.stylename == "unique" then
    local unique_setting = tp_frame.unit.CustomPlateSettings
    border_color = (unique_setting and unique_setting.UseBorderColor and unique_setting.BorderColor) or COLOR_BLACK
  elseif SettingsHealthbar.BorderUseForegroundColor then
    border_color = color
  else
    border_color = SettingsHealthbar.BorderColor
  end
  -- 100% color values are not saved in the database
  healthbar.Border:SetBackdropBorderColor(border_color.r or 1, border_color.g or 1, border_color.b or 1, 1)
end

---------------------------------------------------------------------------------------------------
-- Core element code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_CREATED
function Element.PlateCreated(tp_frame)
  local healthbar = _G.CreateFrame("StatusBar", nil, tp_frame)
  healthbar:SetFrameLevel(tp_frame:GetFrameLevel() + 5)
  -- ! Set the texture here; without a set texture, color changes with SetStatusBarColor will not be applied and
  -- ! the set color will be lost
  healthbar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
  --healthbar:Hide()

  local border = _G.CreateFrame("Frame", nil, healthbar, BackdropTemplate)
  border:SetFrameLevel(healthbar:GetFrameLevel())
  healthbar.Border = border

  healthbar.Background = healthbar:CreateTexture(nil, "ARTWORK")

  if Addon.WOW_FEATURE_ABSORBS then
    local healabsorb_bar = healthbar:CreateTexture(nil, "ARTWORK", nil, 2)
    healabsorb_bar:SetVertexColor(0, 0, 0)
    healabsorb_bar:SetAlpha(0.5)

    local healabsorb_glow = healthbar:CreateTexture(nil, "ARTWORK", nil, 4)
    healabsorb_glow:SetTexture([[Interface\RaidFrame\Absorb-Overabsorb]])
    healabsorb_glow:SetBlendMode("ADD")
    healabsorb_glow:SetWidth(8)
    healabsorb_glow:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMLEFT", 2, 0)
    healabsorb_glow:SetPoint("TOPRIGHT", healthbar, "TOPLEFT", 2, 0)
    healabsorb_glow:Hide()

    healthbar.HealAbsorbLeftShadow = healthbar:CreateTexture(nil, "ARTWORK", nil, 3)
    healthbar.HealAbsorbLeftShadow:SetTexture([[Interface\RaidFrame\Absorb-Edge]])
    healthbar.HealAbsorbRightShadow = healthbar:CreateTexture(nil, "ARTWORK", nil, 3)
    healthbar.HealAbsorbRightShadow:SetTexture([[Interface\RaidFrame\Absorb-Edge]])
    healthbar.HealAbsorbRightShadow:SetTexCoord(1, 0, 0, 1) -- reverse texture (right to left)

    healthbar.HealAbsorb = healabsorb_bar
    healthbar.HealAbsorbGlow = healabsorb_glow

    -- Absorb StatusBar: used for shield display on all Mainline versions.
    -- Anchored to the right edge of the health texture so it fills into the missing-health region.
    local absorb_statusbar = _G.CreateFrame("StatusBar", nil, healthbar)
    absorb_statusbar:SetFrameLevel(healthbar:GetFrameLevel() + 1)
    absorb_statusbar:SetStatusBarTexture("Interface\\RaidFrame\\Shield-Fill")
    absorb_statusbar:SetPoint("TOPLEFT", healthbar:GetStatusBarTexture(), "TOPRIGHT")
    absorb_statusbar:SetPoint("BOTTOMLEFT", healthbar:GetStatusBarTexture(), "BOTTOMRIGHT")
    absorb_statusbar:Hide()

    local absorb_overlay = absorb_statusbar:CreateTexture(nil, "ARTWORK", nil, 1)
    absorb_overlay:SetTexture("Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Striped_Texture.tga", true, true)
    absorb_overlay:SetHorizTile(true)
    absorb_overlay:SetPoint("TOPLEFT", absorb_statusbar:GetStatusBarTexture(), "TOPLEFT")
    absorb_overlay:SetPoint("BOTTOMRIGHT", absorb_statusbar:GetStatusBarTexture(), "BOTTOMRIGHT")
    absorb_overlay:Hide()
    absorb_statusbar.Overlay = absorb_overlay

    -- Spark is a texture on absorb_statusbar (not healthbar) so it renders above the StatusBar fill.
    -- A texture on healthbar would be hidden behind absorb_statusbar's child frame (frameLevel+1).
    local absorb_spark = absorb_statusbar:CreateTexture(nil, "ARTWORK", nil, 4)
    absorb_spark:SetTexture("Interface\\RaidFrame\\Shield-Overshield")
    absorb_spark:SetBlendMode("ADD")
    absorb_spark:SetWidth(8)
    absorb_spark:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4, -1)
    absorb_spark:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4, 1)
    absorb_spark:Hide()
    absorb_statusbar.Spark = absorb_spark

    healthbar.AbsorbStatusBar = absorb_statusbar

    if Addon.ExpansionIsAtLeastMidnight then
      -- Midnight heal prediction calculator (one per nameplate frame, reused across updates).
      local calc = _G.CreateUnitHealPredictionCalculator()
      calc:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MissingHealthWithoutIncomingHeals)
      calc:SetHealAbsorbClampMode(Enum.UnitHealAbsorbClampMode.MaximumHealth)
      calc:SetHealAbsorbMode(Enum.UnitHealAbsorbMode.Total)
      calc:SetIncomingHealClampMode(Enum.UnitIncomingHealClampMode.MissingHealth)
      calc:SetIncomingHealOverflowPercent(1)
      healthbar.HealPredictionCalculator = calc
    end
  end

  healthbar.TargetUnit = healthbar:CreateFontString(nil, "OVERLAY")
  healthbar.TargetUnit:SetFont("Fonts\\FRIZQT__.TTF", 11)

  --frame:SetScript("OnSizeChanged", OnSizeChanged)
  tp_frame.visual.Healthbar = healthbar
  tp_frame.visual.healthbar = healthbar -- for backwards compatibility with WeakAuras
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function Element.PlateUnitAdded(tp_frame)
  local healthbar = tp_frame.visual.Healthbar
  local unit = tp_frame.unit

  healthbar:SetMinMaxValues(0, unit.healthmax)
  healthbar:SetValue(unit.health)

  UpdateAbsorbs(tp_frame)
  UpdateTargetUnit(healthbar, unit.unitid)
end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.PlateUnitRemoved(tp_frame)
--end

-- Called in processing event: UpdateStyle in Nameplate.lua
function Element.UpdateStyle(tp_frame, style, plate_style)
  local healthbar, healthbar_style = tp_frame.visual.Healthbar, style.healthbar

  if plate_style == "None" or not healthbar_style.show then
    healthbar:Hide()
    return
  end

  local healthborder_style = style.healthborder

  healthbar:SetStatusBarTexture(healthbar_style.texture)
  healthbar:ClearAllPoints()
  healthbar:SetSize(healthbar_style[tp_frame.unit.reaction].width, healthbar_style[tp_frame.unit.reaction].height)
  healthbar:SetPoint(healthbar_style.anchor, tp_frame, healthbar_style.anchor, healthbar_style.x, healthbar_style.y)

  local background = healthbar.Background
  background:SetTexture(Addon.LibSharedMedia:Fetch('statusbar', Settings.backdrop, true))
  background:SetPoint("TOPLEFT", healthbar:GetStatusBarTexture(), "TOPRIGHT")
  background:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMRIGHT")

  local border = healthbar.Border
  local offset = healthborder_style.offset
  -- A fresh table is passed every time (rather than reusing/mutating one shared table) because
  -- SetBackdrop no-ops when given the same table reference it already has applied, which would
  -- prevent already-created borders from picking up texture/size changes (e.g., re-enabling the
  -- border after disabling it) until the nameplate frame is recreated.
  border:SetBackdrop({
    edgeFile = healthborder_style.texture,
    edgeSize = healthborder_style.edgesize,
    insets = { left = offset, right = offset, top = offset, bottom = offset },
  })
  border:ClearAllPoints()
  border:SetPoint("TOPLEFT", healthbar, "TOPLEFT", - offset, offset)
  border:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMRIGHT", offset, - offset)
  -- SetBackdrop resets the border color to white, so restore it right after
  ColorUpdate(tp_frame, tp_frame.HealthbarColor)

  if Addon.WOW_FEATURE_ABSORBS then
    -- Absorbs
    healthbar.HealAbsorb:SetTexture(healthbar_style.texture, true, false)

    local absorb_sb = healthbar.AbsorbStatusBar
    absorb_sb:SetWidth(healthbar_style[tp_frame.unit.reaction].width)
    if Settings.ShowAbsorbs then
      absorb_sb:SetStatusBarTexture(Addon.LibSharedMedia:Fetch('statusbar', Settings.texture), true, false)
      local color = Settings.AbsorbColor
      absorb_sb:SetStatusBarColor(color.r, color.g, color.b, color.a)
      color = Settings.OverlayColor
      absorb_sb.Overlay:SetVertexColor(color.r, color.g, color.b, color.a)
    else
      absorb_sb:Hide()
      absorb_sb.Overlay:Hide()
      absorb_sb.Spark:Hide()
    end
  end

  local db_target_unit = Settings.TargetUnit
  FontUpdateText(healthbar, healthbar.TargetUnit, db_target_unit)
  FontUpdateTextSize(healthbar, healthbar.TargetUnit, db_target_unit)
  healthbar.TargetUnit:SetShown(healthbar.TargetUnit:GetText() ~= nil and db_target_unit.Show)

  local frame_level
  if Addon.db.profile.settings.castbar.FrameOrder == "HealthbarOverCastbar" then
    frame_level = tp_frame:GetFrameLevel() + 5
  else
    frame_level = tp_frame:GetFrameLevel() + 4
  end
  healthbar:SetFrameLevel(frame_level)
  if Addon.WOW_FEATURE_ABSORBS then
    healthbar.AbsorbStatusBar:SetFrameLevel(frame_level + 1)
  end
  border:SetFrameLevel(frame_level - 1)
  tp_frame.visual.EliteBorder:SetFrameLevel(frame_level)
  tp_frame.visual.ThreatGlow:SetFrameLevel(frame_level - 1)

  tp_frame.visual.textframe:SetFrameLevel(frame_level)

  healthbar:Show()
end

--function Element.UpdateFrame()
--end

local function UnitMaxHealthUpdate(unitid)
  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    local healthbar = tp_frame.visual.Healthbar

    if healthbar:IsShown() then
      local unit = tp_frame.unit
      healthbar:SetMinMaxValues(0, unit.healthmax)
      healthbar:SetValue(unit.health)
      UpdateAbsorbs(tp_frame)
    end
  end
end

local function UnitHealthbarUpdate(unitid)
  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    local healthbar = tp_frame.visual.Healthbar

    if healthbar:IsShown() then
      local unit = tp_frame.unit
      healthbar:SetValue(unit.health)
      UpdateAbsorbs(tp_frame)
    end
  end
end

function Element.UpdateSettings()
  Settings = Addon.db.profile.settings.healthbar
  SettingsHealthbar = Addon.db.profile.Healthbar

  SettingsTargetUnit = Settings.TargetUnit
  SettingsTargetUnitHide = not SettingsTargetUnit.Show
  SettingsShowOnlyForTarget = SettingsTargetUnit.ShowOnlyForTarget

  SubscribeEvent(Element, "HealthbarColorUpdate", ColorUpdate)

  if not Addon.ExpansionIsAtLeastMidnight and SettingsTargetUnit.Show then
    SubscribeEvent(Element, "UNIT_TARGET", UNIT_TARGET)
    SubscribeEvent(Element, "ThreatUpdate", UnitThreatUpdate)
    SubscribeEvent(Element, "TargetLost", PlayerTargetLost)
    SubscribeEvent(Element, "TargetGained", PlayerTargetGained)
  else
    UnsubscribeEvent(Element, "UNIT_TARGET")
    UnsubscribeEvent(Element, "ThreatUpdate")
    UnsubscribeEvent(Element, "TargetLost")
    UnsubscribeEvent(Element, "TargetGained")
  end
end

SubscribeEvent(Element, "UNIT_MAXHEALTH", UnitMaxHealthUpdate)
SubscribeEvent(Element, "UNIT_HEALTH", UnitHealthbarUpdate)
SubscribeEvent(Element, "UNIT_HEALTH_FREQUENT", UnitHealthbarUpdate)
-- UnitGetTotalAbsorbs: Mists - Patch 5.2.0 (2013-03-05): Added.
SubscribeEvent(Element, "UNIT_ABSORB_AMOUNT_CHANGED", UnitHealthbarUpdate)
-- UnitGetTotalHealAbsorbs: Mists - Patch 5.4.0 (2013-09-10): Added.
SubscribeEvent(Element, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", UnitHealthbarUpdate)