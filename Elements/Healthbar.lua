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
local ThreatPlates= Addon.ThreatPlates
local FontUpdateText, FontUpdateTextSize = Addon.Font.UpdateText, Addon.Font.UpdateTextSize
local SubscribeEvent, UnsubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Unsubscribe, Addon.EventService.Publish
local BackdropTemplate = Addon.BackdropTemplate
local TransliterateCyrillicLetters = Addon.Localization.TransliterateCyrillicLetters

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, UnitHealth, UnitHealthMax, UnitGetTotalAbsorbs

local IGNORED_STYLES = Addon.IGNORED_STYLES_WITH_NAMEMODE

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local Settings, SettingsTargetUnit, SettingsTargetUnitHide, SettingsShowOnlyForTarget
local BorderBackdrop = {
  bgFile = "",
  edgeFile = "",
  edgeSize = 0,
  insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------
local Element = Addon.Elements.NewElement("Healthbar")

---------------------------------------------------------------------------------------------------
-- Additional functions
---------------------------------------------------------------------------------------------------
local UpdateAbsorbs

-- UnitGetTotalAbsorbs: Mists - Patch 5.2.0 (2013-03-05): Added.
-- UnitGetTotalHealAbsorbs: Mists - Patch 5.4.0 (2013-09-10): Added.
if Addon.IS_MAINLINE then
  UpdateAbsorbs = function(tp_frame)
    local visual = tp_frame.visual
    local absorbbar = visual.Healthbar.Absorbs
    local healthbar = visual.Healthbar

    if IGNORED_STYLES[tp_frame.style] then
      healthbar.HealAbsorbGlow:Hide()
      healthbar.HealAbsorb:Hide()
      healthbar.HealAbsorbLeftShadow:Hide()
      healthbar.HealAbsorbRightShadow:Hide()

      absorbbar.Overlay:Hide()
      absorbbar.Spark:Hide()
      absorbbar:Hide()

      return
    end

    local unitid = tp_frame.unit.unitid
    -- Code for absorb calculation see CompactUnitFrame.lua
    local health = _G.UnitHealth(unitid) or 0
    local health_max = _G.UnitHealthMax(unitid) or 0
    local heal_absorb = UnitGetTotalHealAbsorbs(unitid) or 0
    local absorb = _G.UnitGetTotalAbsorbs(unitid) or 0

    -- heal_absorb = 0.25 * UnitHealth(unitid)
    -- absorb = UnitHealthMax(unitid) * 0.3 -- REMOVE
    -- health = health_max * 0.75 -- REMOVE
    -- visual.healthbar:SetValue(health)

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

    if not Settings.ShowAbsorbs then return end

    if absorb > 0 then
      local health_pct = health / health_max
      local absorb_pct = absorb / health_max

      -- Don't fill outside the the health bar with absorbs; instead show an overabsorb glow and an overlay
      absorbbar:ClearAllPoints()
      absorbbar.Overlay:ClearAllPoints()
      absorbbar.Spark:ClearAllPoints()

      if health + absorb < health_max then
        absorbbar.Spark:Hide()

        if Settings.OverlayTexture or Settings.AlwaysFullAbsorb then
          absorbbar.Overlay:SetPoint("LEFT", healthbar, "LEFT", health_pct * healthbar:GetWidth(), 0)
          absorbbar.Overlay:SetSize(absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())
          --absorbbar.overlay:SetTexCoord(0, healthbar:GetWidth() / absorbbar.tileSize, 0, 1)
          absorbbar.Overlay:Show()
        else
          absorbbar.Overlay:Hide()
        end

        absorbbar:SetPoint("LEFT", healthbar, "LEFT", health_pct * healthbar:GetWidth(), 0)
        absorbbar:SetSize(absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())
        absorbbar:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1);
        absorbbar:Show()
      else
        if Settings.AlwaysFullAbsorb then
          -- Prevent the absorb bar extending to the left of the healthbar if absorb > health_max
          if absorb_pct > 1 then
            absorb_pct = 1
          end

          local absorb_offset = absorb_pct * healthbar:GetWidth()
          absorbbar.Spark:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4 - absorb_offset, -1)
          absorbbar.Spark:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4 - absorb_offset, 1)
          absorbbar.Spark:Show()

          absorbbar.Overlay:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
          absorbbar.Overlay:SetSize(absorb_offset, healthbar:GetHeight())
          --absorbbar.overlay:SetTexCoord(0, healthbar:GetWidth() / absorbbar.tileSize, 0, 1)
          absorbbar.Overlay:Show()

          -- absorb + current health >  max health => just show absorb up to max health, not outside of healthbar
          absorb = health_max - health
          if absorb > 0 then
            absorb_pct = absorb / health_max

            absorbbar:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
            absorbbar:SetSize(absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())
            absorbbar:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1)
            absorbbar:Show()
          else
            absorbbar:Hide()
          end
        else
          -- show spark for over-absorbs
          absorbbar.Spark:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4, -1)
          absorbbar.Spark:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4, 1)
          absorbbar.Spark:Show()

          -- absorb + current health >  max health => just show absorb up to max health, not outside of healthbar
          absorb = health_max - health
          if absorb > 0 then
            absorb_pct = absorb / health_max
            local absorb_offset = absorb_pct * healthbar:GetWidth()

            absorbbar:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
            absorbbar:SetSize(absorb_offset, healthbar:GetHeight())
            absorbbar:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1)
            absorbbar:Show()

            if Settings.OverlayTexture then
              absorbbar.Overlay:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
              absorbbar.Overlay:SetSize(absorb_offset, healthbar:GetHeight())
              --absorbbar.overlay:SetTexCoord(0, healthbar:GetWidth() / absorbbar.tileSize, 0, 1)
              absorbbar.Overlay:Show()
            else
              absorbbar.Overlay:Hide()
            end
          else
            absorbbar:Hide()
            absorbbar.Overlay:Hide()
          end
        end
      end
    else
      absorbbar.Overlay:Hide()
      absorbbar.Spark:Hide()
      absorbbar:Hide()
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
    if not SettingsTargetUnit.ShowNotMyself or not UnitIsUnit("player", target_of_target_unit) then
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
  if SettingsShowOnlyForTarget and not Addon.UnitIsTarget(unit.unitid) then
    HideTargetUnit(tp_frame.visual.Healthbar)
  end
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
  border:SetBackdrop(BorderBackdrop)
  border:SetBackdropBorderColor(0, 0, 0, 1)
  healthbar.Border = border

  healthbar.Background = healthbar:CreateTexture(nil, "ARTWORK")

  if Addon.IS_MAINLINE then
    local absorbs = healthbar:CreateTexture(nil, "ARTWORK", nil, 2)
    absorbs.Overlay = healthbar:CreateTexture(nil, "ARTWORK", nil, 3)
    absorbs.Overlay:SetTexture("Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Striped_Texture.tga", true, true)
    absorbs.Overlay:SetHorizTile(true)

    --absorbbar.tileSize = 64
    --      absorbbar.overlay:SetTexture("Interface\\RaidFrame\\Shield-Overlay", true, true);	--Tile both vertically and horizontally
    --      absorbbar.overlay:SetHorizTile(true)
    --      absorbbar.tileSize = 32

    local absorbs_spark = healthbar:CreateTexture(nil, "ARTWORK", nil, 4)
    absorbs_spark:SetTexture("Interface\\RaidFrame\\Shield-Overshield")
    absorbs_spark:SetBlendMode("ADD")
    absorbs_spark:SetWidth(8)
    absorbs_spark:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4, -1)
    absorbs_spark:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4, 1)
    absorbs.Spark = absorbs_spark

    healthbar.Absorbs = absorbs

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
  end

  healthbar.TargetUnit = healthbar:CreateFontString(nil, "OVERLAY")
  healthbar.TargetUnit:SetFont("Fonts\\FRIZQT__.TTF", 11)

  --frame:SetScript("OnSizeChanged", OnSizeChanged)
  tp_frame.visual.Healthbar = healthbar
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function Element.PlateUnitAdded(tp_frame)
  local healthbar = tp_frame.visual.Healthbar
  local unit = tp_frame.unit

  healthbar:SetMinMaxValues(0, unit.healthmax)
  healthbar:SetValue(unit.health)

  if unit.healthmax == unit.health then
    healthbar.Background:Hide()
  else
    healthbar.Background:SetSize(healthbar:GetWidth() * (1 - (unit.health / unit.healthmax)), healthbar:GetHeight())
    healthbar.Background:Show()
  end

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
  border:ClearAllPoints()
  border:SetPoint("TOPLEFT", healthbar, "TOPLEFT", - offset, offset)
  border:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMRIGHT", offset, - offset)

  if Addon.IS_MAINLINE then
    -- Absorbs
    healthbar.HealAbsorb:SetTexture(healthbar_style.texture, true, false)

    local absorbs = healthbar.Absorbs
    if Settings.ShowAbsorbs then
      absorbs:SetTexture(Addon.LibSharedMedia:Fetch('statusbar', Settings.texture), true, false)
      local color = Settings.AbsorbColor
      absorbs:SetVertexColor(color.r, color.g, color.b, color.a)
      color = Settings.OverlayColor
      absorbs.Overlay:SetVertexColor(color.r, color.g, color.b, color.a)
    else
      absorbs:Hide()
      absorbs.Overlay:Hide()
      absorbs.Spark:Hide()
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

local function ColorUpdate(tp_frame, color)
  local healthbar = tp_frame.visual.Healthbar

  if not healthbar:IsShown() then return end

  healthbar:SetStatusBarColor(color.r, color.g, color.b, 1)
  if not SettingsHealthbar.BackgroundUseForegroundColor then
    color = SettingsHealthbar.BackgroundColor
  end
  healthbar.Background:SetVertexColor(color.r, color.g, color.b, 1 - SettingsHealthbar.BackgroundOpacity)
end

function Element.UpdateSettings()
  Settings = Addon.db.profile.settings.healthbar
  SettingsHealthbar = Addon.db.profile.Healthbar

  local db = Addon.db.profile.settings.healthborder
  BorderBackdrop.edgeFile = (db.show and ThreatPlates.Art .. db.texture) or nil
  BorderBackdrop.edgeSize = db.EdgeSize
  BorderBackdrop.insets.left = db.Offset
  BorderBackdrop.insets.right = db.Offset
  BorderBackdrop.insets.top = db.Offset
  BorderBackdrop.insets.bottom = db.Offset

  SettingsTargetUnit = Settings.TargetUnit
  SettingsTargetUnitHide = not SettingsTargetUnit.Show
  SettingsShowOnlyForTarget = SettingsTargetUnit.ShowOnlyForTarget

  SubscribeEvent(Element, "HealthbarColorUpdate", ColorUpdate)

  if SettingsTargetUnit.Show then
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

if Addon.IS_MAINLINE then  
  -- UNIT_HEALTH, UNIT_HEALTH_FREQUENT: 
  --   Shadowlands Patch 9.0.1 (2020-10-13): Removed. Replaced by UNIT HEALTH which is no longer aggressively throttled.
  --   Cataclysm Patch 4.0.6 (2011-02-08): Added.
  SubscribeEvent(Element, "UNIT_HEALTH", UnitHealthbarUpdate)
    -- Absorbs should have been added with Mists
  SubscribeEvent(Element, "UNIT_ABSORB_AMOUNT_CHANGED", UnitHealthbarUpdate)
  SubscribeEvent(Element, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", UnitHealthbarUpdate)
else
  SubscribeEvent(Element, "UNIT_HEALTH_FREQUENT", UnitHealthbarUpdate)
end
