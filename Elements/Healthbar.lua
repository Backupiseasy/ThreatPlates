---------------------------------------------------------------------------------------------------
-- Element: Healthbar
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitGetTotalAbsorbs, UnitGetTotalHealAbsorbs = UnitGetTotalAbsorbs, UnitGetTotalHealAbsorbs

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local ThreatPlates = Addon.ThreatPlates
local PlatesByUnit = Addon.PlatesByUnit
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish

local IGNORED_STYLES = {
  NameOnly = true,
  ["NameOnly-Unique"] = true,
  etotem = true,
  empty= true,
}

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local Settings
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

local function UpdateAbsorbs(tp_frame)
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
  local health = UnitHealth(unitid) or 0
  local health_max = UnitHealthMax(unitid) or 0
  local heal_absorb = UnitGetTotalHealAbsorbs(unitid) or 0
  local absorb = UnitGetTotalAbsorbs(unitid) or 0

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

---------------------------------------------------------------------------------------------------
-- Core element code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
  local healthbar = CreateFrame("StatusBar", nil, tp_frame)
  healthbar:SetFrameLevel(tp_frame:GetFrameLevel() + 5)
  --frame:Hide()

  local border = CreateFrame("Frame", nil, healthbar)
  border:SetFrameLevel(healthbar:GetFrameLevel())
  border:SetBackdrop(BorderBackdrop)
  border:SetBackdropBorderColor(0, 0, 0, 1)
  healthbar.Border = border

  -- Save border backdrop color for restoring it later as it will be reset (to white) when updating the backdrop
  -- => not necessary any more as the backdrop is only changed when the element is created now
  -- local r, g, b, a = border:GetBackdropColor()
  -- border:SetBackdropColor(r, g, b, a)

  local absorbs = healthbar:CreateTexture(nil, "BORDER", -6)
  absorbs.Overlay = healthbar:CreateTexture(nil, "OVERLAY", 0)
  absorbs.Overlay:SetTexture("Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Striped_Texture.tga", true, true)
  absorbs.Overlay:SetHorizTile(true)

  --absorbbar.tileSize = 64
  --      absorbbar.overlay:SetTexture("Interface\\RaidFrame\\Shield-Overlay", true, true);	--Tile both vertically and horizontally
  --      absorbbar.overlay:SetHorizTile(true)
  --      absorbbar.tileSize = 32

  local absorbs_spark = healthbar:CreateTexture(nil, "OVERLAY", 7)
  absorbs_spark:SetTexture("Interface\\RaidFrame\\Shield-Overshield")
  absorbs_spark:SetBlendMode("ADD")
  absorbs_spark:SetWidth(8)
  absorbs_spark:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4, -1)
  absorbs_spark:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4, 1)
  absorbs.Spark = absorbs_spark

  healthbar.Absorbs = absorbs

  local healabsorb_bar = healthbar:CreateTexture(nil, "OVERLAY", 0)
  healabsorb_bar:SetVertexColor(0, 0, 0)
  healabsorb_bar:SetAlpha(0.5)

  local healabsorb_glow = healthbar:CreateTexture(nil, "OVERLAY", 7)
  healabsorb_glow:SetTexture([[Interface\RaidFrame\Absorb-Overabsorb]])
  healabsorb_glow:SetBlendMode("ADD")
  healabsorb_glow:SetWidth(8)
  healabsorb_glow:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMLEFT", 2, 0)
  healabsorb_glow:SetPoint("TOPRIGHT", healthbar, "TOPLEFT", 2, 0)
  healabsorb_glow:Hide()

  healthbar.HealAbsorbLeftShadow = healthbar:CreateTexture(nil, "OVERLAY", 4)
  healthbar.HealAbsorbLeftShadow:SetTexture([[Interface\RaidFrame\Absorb-Edge]])
  healthbar.HealAbsorbRightShadow = healthbar:CreateTexture(nil, "OVERLAY", 4)
  healthbar.HealAbsorbRightShadow:SetTexture([[Interface\RaidFrame\Absorb-Edge]])
  healthbar.HealAbsorbRightShadow:SetTexCoord(1, 0, 0, 1) -- reverse texture (right to left)

  healthbar.HealAbsorb = healabsorb_bar
  healthbar.HealAbsorbGlow = healabsorb_glow

  --frame:SetScript("OnSizeChanged", OnSizeChanged)
  tp_frame.visual.Healthbar = healthbar
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function Element.UnitAdded(tp_frame)
  local healthbar = tp_frame.visual.Healthbar
  local unit = tp_frame.unit

  healthbar:SetMinMaxValues(0, unit.healthmax)
  healthbar:SetValue(unit.health)
  UpdateAbsorbs(tp_frame)
end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.UnitRemoved(tp_frame)
--end

-- Called in processing event: UpdateStyle in Nameplate.lua
function Element.UpdateStyle(tp_frame, style, plate_style)
  local healthbar, healthbar_style = tp_frame.visual.Healthbar, style.healthbar

  if plate_style == "NONE" or not healthbar_style.show then
    healthbar:Hide()
    return
  end

  local healthborder_style = style.healthborder

  healthbar:SetStatusBarTexture(healthbar_style.texture)
  healthbar:SetSize(healthbar_style.width, healthbar_style.height)
  healthbar:ClearAllPoints()
  healthbar:SetPoint(healthbar_style.anchor, tp_frame, healthbar_style.anchor, healthbar_style.x, healthbar_style.y)

  healthbar.HealAbsorb:SetTexture(healthbar_style.texture, true, false)

  local border = healthbar.Border
  local offset = healthborder_style.offset
  border:ClearAllPoints()
  border:SetPoint("TOPLEFT", healthbar, "TOPLEFT", - offset, offset)
  border:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMRIGHT", offset, - offset)

  -- Absorbs
  local absorbs = healthbar.Absorbs
  if Settings.ShowAbsorbs then
    absorbs:SetTexture(ThreatPlates.Media:Fetch('statusbar', Settings.texture), true, false)
    local color = Settings.AbsorbColor
    absorbs:SetVertexColor(color.r, color.g, color.b, color.a)
    color = Settings.OverlayColor
    absorbs.Overlay:SetVertexColor(color.r, color.g, color.b, color.a)
  else
    absorbs:Hide()
    absorbs.Overlay:Hide()
    absorbs.Spark:Hide()
  end

  healthbar:Show()
end

function Element.UpdateSettings()
  Settings = TidyPlatesThreat.db.profile.settings.healthbar

  local db = TidyPlatesThreat.db.profile.settings.healthborder
  BorderBackdrop.bgFile = ThreatPlates.Media:Fetch('statusbar', Settings.backdrop, true)
  BorderBackdrop.edgeFile = (db.show and ThreatPlates.Art .. db.texture) or nil
  BorderBackdrop.edgeSize = db.EdgeSize
  BorderBackdrop.insets.left = db.Offset
  BorderBackdrop.insets.right = db.Offset
  BorderBackdrop.insets.top = db.Offset
  BorderBackdrop.insets.bottom = db.Offset
end

--function Element.UpdateFrame()
--end

local function UnitHealthbarUpdate(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    local healthbar = tp_frame.visual.Healthbar

    if healthbar:IsShown() then
      local unit = tp_frame.unit
      healthbar:SetMinMaxValues(0, unit.healthmax)
      healthbar:SetValue(unit.health)

      UpdateAbsorbs(tp_frame)
    end
  end
end

SubscribeEvent(Element, "UNIT_HEALTH_FREQUENT", UnitHealthbarUpdate)
SubscribeEvent(Element, "UNIT_MAXHEALTH", UnitHealthbarUpdate)
SubscribeEvent(Element, "UNIT_ABSORB_AMOUNT_CHANGED", UnitHealthbarUpdate)
SubscribeEvent(Element, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", UnitHealthbarUpdate)
