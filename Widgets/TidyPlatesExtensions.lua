local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local CreateFrame = CreateFrame
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
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

local function CreateExtensions(extended)
  local visual = extended.visual

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

  if ENABLE_ABSORB then
    -- check if absorbbar and glow are created at the samel level as healthbar
    if not absorbbar then
      local healthbar = visual.healthbar
      absorbbar = healthbar:CreateTexture(nil, "BORDER", -6)
      absorbbar:Hide()

      absorbbar.overlay = healthbar:CreateTexture(nil, "Border", -4)
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

local function UpdateExtensions(extended, unitid, style)
  local visual = extended.visual
  local absorbbar = visual.absorbbar

  if not ENABLE_ABSORB or not absorbbar then return end

  -- Code for absorb calculation see CompactUnitFrame.lua
  local absorb = UnitGetTotalAbsorbs(unitid) or 0

--  absorb = UnitHealthMax(unitid) * 0.5 -- REMOVE

  -- style probably is never nil here
  if absorb == 0 or not style or IGNORED_STYLES[style] then
    absorbbar.overlay:Hide()
    absorbbar.glow:Hide()
    absorbbar:Hide()
    return
  end

  local health = UnitHealth(unitid) or 0
  local health_max = UnitHealthMax(unitid) or 0

--  health = health_max * 0.75 -- REMOVE
--  visual.healthbar:SetValue(health)

  local db = TidyPlatesThreat.db.profile.settings.healthbar
  local healthbar = visual.healthbar

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
end

ThreatPlates.CreateExtensions = CreateExtensions
ThreatPlates.UpdateExtensions = UpdateExtensions
