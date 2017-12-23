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

      --absorbbar = CreateFrame("StatusBar", nil, extended)
      --absorbbar:SetMinMaxValues(0, 100)
      --absorbbar:SetValue(100)
      absorbbar = healthbar:CreateTexture(nil, "BORDER", -6)
      absorbbar:Hide()

      absorbbar.overlay = healthbar:CreateTexture(nil, "OVERLAY", -5)
      --absorbbar.overlay:SetTexture("Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\stippled-bar.tga", true, false)
      --absorbbar.tileSize = 64
      absorbbar.overlay:SetTexture("Interface\\RaidFrame\\Shield-Overlay", true, false);	--Tile both vertically and horizontally
      absorbbar.tileSize = 32
      --absorbbar.overlay:SetBlendMode("ADD")
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

    --absorbbar:SetStatusBarTexture(ThreatPlates.Media:Fetch('statusbar', db.texture))
    --absorbbar:GetStatusBarTexture():SetHorizTile(false)
--    if db.StripedTexture then
--      --absorbbar:SetTexture("Interface\\RaidFrame\\Shield-Fill") -- totalAbsorb
----      absorbbar:SetTexture("Interface\\RaidFrame\\Shield-Overlay", true, true);	--Tile both vertically and horizontally
----      absorbbar.tileSize = 32
--      absorbbar:SetTexture("Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\stippled-bar.tga", true, false)
--      absorbbar.tileSize = 64
--      local r, g, b,a  = visual.healthbar.Bar:GetVertexColor()
--      absorbbar:SetVertexColor(1, 0, 0, 1)
--      --absorbbar:SetTexture("Interface\\RaidFrame\\Shield-Overshield") -- overAbsorbGlow
--      --absorbbar:SetTexture("Interface\\RaidFrame\\Absorb-Overabsorb") -- overHealAbsorbGlow
--    else
--      absorbbar:SetTexture(ThreatPlates.Media:Fetch('statusbar', db.texture), true, false)
--      absorbbar.tileSize = absorbbar:GetWidth()
--      local color = db.AbsorbColor
--      absorbbar:SetVertexColor(color.r, color.g, color.b, color.a)
--    end

    absorbbar:SetTexture(ThreatPlates.Media:Fetch('statusbar', db.texture), true, false)
    --absorbbar.tileSize = absorbbar:GetWidth()
    local color = db.AbsorbColor
    absorbbar:SetVertexColor(color.r, color.g, color.b, color.a)
  elseif absorbbar then
    absorbbar:Hide()
    absorbbar.glow:Hide()
    absorbbar.overlay:Hide()
  end
end

local function UpdateExtensions(extended, unitid, style)
  local visual = extended.visual
  local absorbbar = visual.absorbbar

  if not ENABLE_ABSORB or not absorbbar then return end

  -- Code for absorb calculation see CompactUnitFrame.lua
  local absorb = UnitGetTotalAbsorbs(unitid) or 0

  --absorb = UnitHealthMax(unitid) * 0.5 -- REMOVE

  if absorb == 0 or IGNORED_STYLES[style] then
    absorbbar.glow:Hide()
    absorbbar:Hide()
    return
  end

  local health = UnitHealth(unitid) or 0
  local health_max = UnitHealthMax(unitid) or 0

--  health = health_max * 0.8 -- REMOVE
--  visual.healthbar:SetValue(health)

  local db = TidyPlatesThreat.db.profile.settings.healthbar
  local healthbar = visual.healthbar

--  if UnitIsUnit("target", unitid) then
--    print ("Absorb:", absorb)
--    print ("Absorb Percentage Raw:", floor(absorb * 100 / health_max))
--  end

  if db.AlwaysFullAbsorb then
    local absorb_pct = absorb / health_max
    local health_pct = health / health_max

    -- Prevent the absorb bar extending to the left of the healthbar if absorb > health_max
    if absorb_pct > 1 then
      absorb_pct = 1
    end

    local absorb_offset = absorb_pct * healthbar:GetWidth()
    --absorbbar:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
    if health + absorb >= health_max then
      absorbbar.glow:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4 - absorb_offset, -1)
      absorbbar.glow:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4 - absorb_offset, 1)
      absorbbar.glow:Show()

      absorbbar.overlay:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
      absorbbar.overlay:SetSize(absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())

      absorbbar:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
      absorbbar:SetSize(absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())
      absorbbar:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1)
    else
      absorbbar.glow:Hide()

      absorbbar.overlay:SetPoint("LEFT", healthbar, "LEFT", health_pct * healthbar:GetWidth(), 0)
      absorbbar.overlay:SetSize(absorb_offset, healthbar:GetHeight())

      absorbbar:SetPoint("LEFT", healthbar, "LEFT", health_pct * healthbar:GetWidth(), 0)
      absorbbar:SetSize(absorb_offset, healthbar:GetHeight())
      absorbbar:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1)
    end

    --    if db.StripedTexture then
    --      absorbbar:SetTexCoord(0, healthbar:GetWidth() / absorbbar.tileSize, 0, 1);
    --    else
    --      absorbbar:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1);
    --    end

    if db.StripedTexture then
      absorbbar.overlay:SetTexCoord(0, healthbar:GetWidth() / absorbbar.tileSize, 0, 1)
      absorbbar.overlay:Show()
    else
      absorbbar.overlay:Hide()
    end

    absorbbar:Show()
  else
    -- Don't fill outside the the health bar with absorbs; instead show an overabsorb glow
    if health + absorb >= health_max then
      -- absorb + current health >  max health => just show absorb up to max health, not outside of healthbar
      absorb = health_max - health
      if absorb < 0 then
        absorb = 0
      end

      -- show spark for over-absorbs
      absorbbar.glow:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4, -1)
      absorbbar.glow:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4, 1)
      absorbbar.glow:Show()
    else
      absorbbar.glow:Hide()
    end

    if absorb > 0 then
      local absorb_pct = absorb / health_max
      local health_pct = health / health_max

      absorbbar:SetPoint("LEFT", healthbar, "LEFT", health_pct * healthbar:GetWidth(), 0)
      absorbbar:SetSize(absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())
      absorbbar:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1);
      absorbbar:Show()
    else
      absorbbar:Hide()
    end
  end
end

local function UpdateExtensions2(extended, unitid, style)
  local visual = extended.visual
  local absorbbar = visual.absorbbar

  if not ENABLE_ABSORB or not absorbbar then return end

  -- Code for absorb calculation see CompactUnitFrame.lua
  local absorb = UnitGetTotalAbsorbs(unitid) or 0

  --absorb = UnitHealthMax(unitid) * 0.5 -- REMOVE

  if absorb == 0 or IGNORED_STYLES[style] then
    absorbbar.glow:Hide()
    absorbbar:Hide()
    return
  end

  local health = UnitHealth(unitid) or 0
  local health_max = UnitHealthMax(unitid) or 0

  local health_absorb = health_max - health
  local over_absorb = 0
  if health_absorb > absorb then
    health_absorb = absorb
  else
    over_absorb = absorb - health_absorb
  end

  local db = TidyPlatesThreat.db.profile.settings.healthbar
  local healthbar = visual.healthbar

  -- show spark for over-absorbs
  if over_absorb > 0 then
    local offset = 0
    if db.AlwaysFullAbsorb then
      offset = (absorb / health_max) * healthbar:GetWidth()
    end
    absorbbar.glow:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4 - offset, -1)
    absorbbar.glow:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4 - offset, 1)
    absorbbar.glow:Show()
  else
    absorbbar.glow:Hide()
  end

  if db.AlwaysFullAbsorb then
    local absorb_pct = health_absorb / health_max
    local health_pct = health / health_max

    -- Prevent the absorb bar extending to the left of the healthbar if absorb > health_max
    if absorb_pct > 1 then
      absorb_pct = 1
    end

    local absorb_offset = absorb_pct * healthbar:GetWidth()

    if over_absorb then
      absorbbar.overlay:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
      absorbbar.overlay:SetSize(absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())

      absorbbar:SetPoint("RIGHT", healthbar, "RIGHT", 0, 0)
      absorbbar:SetSize(absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())
      absorbbar:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1)
    else
      absorbbar.overlay:SetPoint("LEFT", healthbar, "LEFT", health_pct * healthbar:GetWidth(), 0)
      absorbbar.overlay:SetSize(absorb_offset, healthbar:GetHeight())

      absorbbar:SetPoint("LEFT", healthbar, "LEFT", health_pct * healthbar:GetWidth(), 0)
      absorbbar:SetSize(absorb_offset, healthbar:GetHeight())
      absorbbar:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1)
    end

    if db.StripedTexture then
      absorbbar.overlay:SetTexCoord(0, healthbar:GetWidth() / absorbbar.tileSize, 0, 1)
      absorbbar.overlay:Show()
    else
      absorbbar.overlay:Hide()
    end

    absorbbar:Show()
  else
    if health_absorb > 0 then
      local absorb_pct = health_absorb / health_max
      local health_pct = health / health_max

      absorbbar:SetPoint("LEFT", healthbar, "LEFT", absorb_pct * healthbar:GetWidth(), 0)
      absorbbar:SetSize(absorb_pct * healthbar:GetWidth(), healthbar:GetHeight())
      absorbbar:SetTexCoord(health_pct, health_pct + absorb_pct, 0, 1);
      absorbbar:Show()
    else
      absorbbar:Hide()
    end
  end
end

ThreatPlates.CreateExtensions = CreateExtensions
ThreatPlates.UpdateExtensions = UpdateExtensions
