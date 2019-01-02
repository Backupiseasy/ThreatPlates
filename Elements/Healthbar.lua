---------------------------------------------------------------------------------------------------
-- Element: Healthbar
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame
local UnitHealth, UnitHealthMax, UnitGetTotalAbsorbs = UnitHealth, UnitHealthMax, UnitGetTotalAbsorbs

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
  if not Settings.ShowAbsorbs then return end

  local unit, visual = tp_frame.unit, tp_frame.visual
  local unitid = unit.unitid
  local absorbs = visual.Healthbar.Absorbs

  -- Code for absorb calculation see CompactUnitFrame.lua
  local absorbs_value = UnitGetTotalAbsorbs(unitid) or 0

  -- absorb = UnitHealthMax(unitid) * 0.3 -- REMOVE

  -- style probably is never nil here
  if absorbs_value == 0 or IGNORED_STYLES[tp_frame.style] then
    absorbs.Overlay:Hide()
    absorbs.Spark:Hide()
    absorbs:Hide()
    return
  end

  local health = UnitHealth(unitid) or 0
  local health_max = UnitHealthMax(unitid) or 0

  --  health = health_max * 0.75 -- REMOVE
  --  visual.healthbar:SetValue(health)

  local healthbar = visual.Healthbar

  local health_pct = health / health_max
  local absorb_pct = absorbs_value / health_max

  -- Don't fill outside the the health bar with absorbs; instead show an overabsorb glow and an overlay
  absorbs:ClearAllPoints()
  absorbs.Overlay:ClearAllPoints()
  absorbs.Spark:ClearAllPoints()

  if health + absorbs_value < health_max then
    absorbs.Spark:Hide()

    if Settings.OverlayTexture or Settings.AlwaysFullAbsorb then
      absorbs.Overlay:SetPoint("LEFT", healthbar, "LEFT", health_pct * healthbar:GetWidth(), 0)
      absorbs.Overlay:SetSize(absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())
      --absorbbar.overlay:SetTexCoord(0, healthbar:GetWidth() / absorbbar.tileSize, 0, 1)
      absorbs.Overlay:Show()
    else
      absorbs.Overlay:Hide()
    end

    absorbs:SetPoint("LEFT", healthbar, "LEFT", health_pct * healthbar:GetWidth(), 0)
    absorbs:SetSize(absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())
    absorbs:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1);
    absorbs:Show()
  else
    if Settings.AlwaysFullAbsorb then
      -- Prevent the absorb bar extending to the left of the healthbar if absorb > health_max
      if absorb_pct > 1 then
        absorb_pct = 1
      end

      local absorb_offset = absorb_pct * healthbar:GetWidth()
      absorbs.Spark:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4 - absorb_offset, -1)
      absorbs.Spark:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4 - absorb_offset, 1)
      absorbs.Spark:Show()

      absorbs.Overlay:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
      absorbs.Overlay:SetSize(absorb_offset, healthbar:GetHeight())
      --absorbbar.overlay:SetTexCoord(0, healthbar:GetWidth() / absorbbar.tileSize, 0, 1)
      absorbs.Overlay:Show()

      -- absorb + current health >  max health => just show absorb up to max health, not outside of healthbar
      absorbs_value = health_max - health
      if absorbs_value > 0 then
        absorb_pct = absorbs_value / health_max

        absorbs:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
        absorbs:SetSize(absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())
        absorbs:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1)
        absorbs:Show()
      else
        absorbs:Hide()
      end
    else
      -- show spark for over-absorbs
      absorbs.Spark:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4, -1)
      absorbs.Spark:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4, 1)
      absorbs.Spark:Show()

      -- absorb + current health >  max health => just show absorb up to max health, not outside of healthbar
      absorbs_value = health_max - health
      if absorbs_value > 0 then
        absorb_pct = absorbs_value / health_max
        local absorb_offset = absorb_pct * healthbar:GetWidth()

        absorbs:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
        absorbs:SetSize(absorb_offset, healthbar:GetHeight())
        absorbs:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1)
        absorbs:Show()

        if Settings.OverlayTexture then
          absorbs.Overlay:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
          absorbs.Overlay:SetSize(absorb_offset, healthbar:GetHeight())
          --absorbbar.overlay:SetTexCoord(0, healthbar:GetWidth() / absorbbar.tileSize, 0, 1)
          absorbs.Overlay:Show()
        else
          absorbs.Overlay:Hide()
        end
      else
        absorbs:Hide()
        absorbs.Overlay:Hide()
      end
    end
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

  healthbar.Border = CreateFrame("Frame", nil, healthbar)
  healthbar.Border:SetFrameLevel(healthbar:GetFrameLevel())

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
function Element.UpdateStyle(tp_frame, style)
  local healthbar, healthbar_style = tp_frame.visual.Healthbar, style.healthbar
  local healthborder_style = style.healthborder

  if healthbar_style.show then
    healthbar:SetStatusBarTexture(healthbar_style.texture)
    healthbar:SetSize(healthbar_style.width, healthbar_style.height)
    healthbar:ClearAllPoints()
    healthbar:SetPoint(healthbar_style.anchor, tp_frame, healthbar_style.anchor, healthbar_style.x, healthbar_style.y)

    local offset = healthborder_style.offset
    local border = healthbar.Border
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", healthbar, "TOPLEFT", - offset, offset)
    border:SetPoint("BOTTOMRIGHT", healthbar, "BOTTOMRIGHT", offset, - offset)
    border:SetBackdrop(BorderBackdrop)
    border:SetBackdropBorderColor(0, 0, 0, 1)

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
  else
    healthbar:Hide()
  end
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

local function UNIT_HEALTH_FREQUENT(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    local healthbar = tp_frame.visual.Healthbar
    local unit = tp_frame.unit

    if healthbar:IsShown() then
      healthbar:SetMinMaxValues(0, unit.healthmax)
      healthbar:SetValue(unit.health)
    end
  end
end

local function UnitAbsorbsUpdate(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    local healthbar = tp_frame.visual.Healthbar

    if healthbar:IsShown() then
      UpdateAbsorbs(tp_frame)
    end
  end
end

local function ColorUpdate(tp_frame, fg_color, bg_color)
  local healthbar = tp_frame.visual.Healthbar

  if healthbar:IsShown() then
    healthbar:SetStatusBarColor(fg_color.r, fg_color.g, fg_color.b, 1)
    healthbar.Border:SetBackdropColor(bg_color.r, bg_color.g, bg_color.b, bg_color.a)

    assert (bg_color.r ~= 0 or bg_color.g ~= 0 or bg_color.b ~= 0 or bg_color.a ~= 0, "Not initialized background: " .. tostring(bg_color.r) .. " - " .. tostring(bg_color.g) .. " - " .. tostring(bg_color.b) .. " - " .. tostring(bg_color.a))
  end
end


SubscribeEvent(Element, "UNIT_HEALTH_FREQUENT", UNIT_HEALTH_FREQUENT)
SubscribeEvent(Element, "UNIT_ABSORB_AMOUNT_CHANGED", UnitAbsorbsUpdate)
SubscribeEvent(Element, "UNIT_MAXHEALTH", UnitAbsorbsUpdate)
