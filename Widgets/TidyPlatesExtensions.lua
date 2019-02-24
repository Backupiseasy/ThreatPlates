local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local UnitGetTotalAbsorbs, UnitGetTotalHealAbsorbs = UnitGetTotalAbsorbs, UnitGetTotalHealAbsorbs
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

---------------------------------------------------------------------------------------------------
-- Extensions to the TidyPlates UI elements
---------------------------------------------------------------------------------------------------

local ENABLE_ABSORB = false

local IGNORED_STYLES = {
  NameOnly = true,
  ["NameOnly-Unique"] = true,
  etotem = true,
  empty= true,
}

function Addon:CreateExtensions(tp_frame)
  local visual = tp_frame.visual

  -- Fix layering of TidyPlates
  -- set parent of textFrame to extended
  --visual.name:GetParent():SetParent(extended)
  -- With TidyPlates:
  --extended.widgetParent:SetParent(extended)
  --visual.name:GetParent():SetParent(extended)
  --visual.raidicon:SetDrawLayer("OVERLAY")

  --  Absorbs on healthbar
  local db = TidyPlatesThreat.db.profile.settings.healthbar
  ENABLE_ABSORB = db.ShowAbsorbs

  local absorbbar = visual.absorbbar

  local healthbar = visual.healthbar
  if ENABLE_ABSORB then
    -- check if absorbbar and glow are created at the samel level as healthbar
    if not absorbbar then
      absorbbar = healthbar:CreateTexture(nil, "BORDER", -6)
      absorbbar:Hide()

      absorbbar.overlay = healthbar:CreateTexture(nil, "OVERLAY", 0)
      absorbbar.overlay:SetTexture("Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Striped_Texture.tga", true, true)
      absorbbar.overlay:SetHorizTile(true)
      --absorbbar.tileSize = 64
--      absorbbar.overlay:SetTexture("Interface\\RaidFrame\\Shield-Overlay", true, true);	--Tile both vertically and horizontally
--      absorbbar.overlay:SetHorizTile(true)
--      absorbbar.tileSize = 32
      absorbbar.overlay:Hide()

      local absorbglow = healthbar:CreateTexture(nil, "OVERLAY", 7)
      absorbglow:SetTexture("Interface\\RaidFrame\\Shield-Overshield")
      absorbglow:SetBlendMode("ADD")
      absorbglow:SetWidth(8)
      absorbglow:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4, -1)
      absorbglow:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4, 1)
      absorbglow:Hide()

      absorbbar.glow = absorbglow
      visual.absorbbar = absorbbar
    end

    absorbbar:SetTexture(ThreatPlates.Media:Fetch('statusbar', db.texture), true, false)
    local color = db.AbsorbColor
    absorbbar:SetVertexColor(color.r, color.g, color.b, color.a)
    color = db.OverlayColor
    absorbbar.overlay:SetVertexColor(color.r, color.g, color.b, color.a)
  elseif absorbbar then
    absorbbar.overlay:Hide()
    absorbbar.glow:Hide()
    absorbbar:Hide()
  end
end

function Addon:UpdateExtensions(tp_frame, unitid, style)
  local visual = tp_frame.visual
  local absorbbar = visual.absorbbar
  local healthbar = visual.healthbar

  -- style probably is never nil here
  if not style or IGNORED_STYLES[style] then
    healthbar.HealAbsorbGlow:Hide()
    healthbar.HealAbsorb:Hide()
    healthbar.HealAbsorbLeftShadow:Hide()
    healthbar.HealAbsorbRightShadow:Hide()

    if absorbbar then
      absorbbar.overlay:Hide()
      absorbbar.glow:Hide()
      absorbbar:Hide()
    end

    return
  end

  -- Code for absorb calculation see CompactUnitFrame.lua
  local health = UnitHealth(unitid) or 0
  local health_max = UnitHealthMax(unitid) or 0
  local heal_absorb = UnitGetTotalHealAbsorbs(unitid) or 0
  local absorb = UnitGetTotalAbsorbs(unitid) or 0

  -- heal_absorb = 0.25 * UnitHealth(unitid)
  -- absorb = UnitHealthMax(unitid) * 0.3 -- REMOVE
  -- health = health_max * 0.75 -- REMOVE
  -- visual.healthbar:SetValue(health)

  local db = TidyPlatesThreat.db.profile.settings.healthbar

  if db.ShowHealAbsorbs and heal_absorb > 0 then
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
    if absorb > 0 and ENABLE_ABSORB then
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

  if not ENABLE_ABSORB or not absorbbar then return end

  if absorb > 0 then
    local health_pct = health / health_max
    local absorb_pct = absorb / health_max

    -- Don't fill outside the the health bar with absorbs; instead show an overabsorb glow and an overlay
    absorbbar:ClearAllPoints()
    absorbbar.overlay:ClearAllPoints()
    absorbbar.glow:ClearAllPoints()

    if health + absorb < health_max then
      absorbbar.glow:Hide()

      if db.OverlayTexture or db.AlwaysFullAbsorb then
        absorbbar.overlay:SetPoint("LEFT", healthbar, "LEFT", health_pct * healthbar:GetWidth(), 0)
        absorbbar.overlay:SetSize(absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())
        --absorbbar.overlay:SetTexCoord(0, healthbar:GetWidth() / absorbbar.tileSize, 0, 1)
        absorbbar.overlay:Show()
      else
        absorbbar.overlay:Hide()
      end

      absorbbar:SetPoint("LEFT", healthbar, "LEFT", health_pct * healthbar:GetWidth(), 0)
      absorbbar:SetSize(absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())
      absorbbar:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1);
      absorbbar:Show()
    else
      if db.AlwaysFullAbsorb then
        -- Prevent the absorb bar extending to the left of the healthbar if absorb > health_max
        if absorb_pct > 1 then
          absorb_pct = 1
        end

        local absorb_offset = absorb_pct * healthbar:GetWidth()
        absorbbar.glow:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4 - absorb_offset, -1)
        absorbbar.glow:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4 - absorb_offset, 1)
        absorbbar.glow:Show()

        absorbbar.overlay:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
        absorbbar.overlay:SetSize(absorb_offset, healthbar:GetHeight())
        --absorbbar.overlay:SetTexCoord(0, healthbar:GetWidth() / absorbbar.tileSize, 0, 1)
        absorbbar.overlay:Show()

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
        absorbbar.glow:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4, -1)
        absorbbar.glow:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4, 1)
        absorbbar.glow:Show()

        -- absorb + current health >  max health => just show absorb up to max health, not outside of healthbar
        absorb = health_max - health
        if absorb > 0 then
          absorb_pct = absorb / health_max
          local absorb_offset = absorb_pct * healthbar:GetWidth()

          absorbbar:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
          absorbbar:SetSize(absorb_offset, healthbar:GetHeight())
          absorbbar:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1)
          absorbbar:Show()

          if db.OverlayTexture then
            absorbbar.overlay:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
            absorbbar.overlay:SetSize(absorb_offset, healthbar:GetHeight())
            --absorbbar.overlay:SetTexCoord(0, healthbar:GetWidth() / absorbbar.tileSize, 0, 1)
            absorbbar.overlay:Show()
          else
            absorbbar.overlay:Hide()
          end
        else
          absorbbar:Hide()
          absorbbar.overlay:Hide()
        end
      end
    end
  else
    absorbbar.overlay:Hide()
    absorbbar.glow:Hide()
    absorbbar:Hide()
  end
end