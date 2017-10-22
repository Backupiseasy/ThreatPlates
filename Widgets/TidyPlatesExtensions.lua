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

--local function UpdateAbsorbs(extended, elapsed, unitid)
--  if not ENABLE_ABSORB then return end
--
--  local visual = extended.visual
--  local absorbbar = visual.absorbbar
--
--  unitid = unitid or extended.unit.unitid
--
--  -- Code for absorb calculation see CompactUnitFrame.lua
--  local absorb = UnitGetTotalAbsorbs(unitid) or 0
--
--  if absorb == 0 or IGNORED_STYLES[extended.unit.TP_Style] then
--    absorbbar.glow:Hide()
--    absorbbar:Hide()
--    return
--  end
--
--  local health = UnitHealth(unitid) or 0
--  local health_max = UnitHealthMax(unitid) or 0
--
--  -- Don't fill outside the the health bar with absorbs; instead show an overabsorb glow
--  if health + absorb >= health_max then
--    -- absorb + current health >  max health => just show absorb up to max health, not outside of healthbar
--    absorb = health_max - health
--    if absorb < 0 then
--      absorb = 0
--    end
--
--    -- show spark for over-absorbs
--    absorbbar.glow:Show()
--  else
--    absorbbar.glow:Hide()
--  end
--
--  local healthbar = visual.healthbar
--  if absorb > 0 then
--    absorbbar:SetPoint("LEFT", healthbar, "LEFT", (health / health_max) * healthbar:GetWidth(), 0)
--    absorbbar:SetSize((absorb / health_max) * healthbar:GetWidth(), healthbar:GetHeight())
--    absorbbar:Show()
--  else
--    absorbbar:Hide()
--  end
--end

local function CreateExtensions(extended)
  --  Absorbs on healthbar
  local db = TidyPlatesThreat.db.profile.settings.healthbar
  ENABLE_ABSORB = db.ShowAbsorbs

  local visual = extended.visual
  local absorbbar = visual.absorbbar

  if ENABLE_ABSORB then
    if not absorbbar then
      -- check if absorbbar and glow are created at the samel level as healthbar
      local healthbar = visual.healthbar

      absorbbar = CreateFrame("StatusBar", nil, extended)
      absorbbar:SetMinMaxValues(0, 100)
      absorbbar:SetValue(100)
      absorbbar:Hide()

      local absorbglow = healthbar:CreateTexture(nil, "OVERLAY") -- (nil, 'ARTWORK',nil,7)?
      absorbglow:SetTexture("Interface\\RaidFrame\\Shield-Overshield")
      absorbglow:SetBlendMode("ADD")
      absorbglow:SetWidth(8)
      absorbglow:SetPoint("BOTTOMLEFT", healthbar, "BOTTOMRIGHT", -4, -1)
      absorbglow:SetPoint("TOPLEFT", healthbar, "TOPRIGHT", -4, 1)
      absorbglow:Hide()

      absorbbar.glow = absorbglow
      visual.absorbbar = absorbbar

      --extended:HookScript("OnUpdate", UpdateAbsorbs)
    end

    absorbbar:SetStatusBarTexture(ThreatPlates.Media:Fetch('statusbar', db.texture))
    absorbbar:GetStatusBarTexture():SetHorizTile(false)
    --absorbbar:SetStatusBarTexture("Interface\\RaidFrame\\Shield-Fill");
    local color = db.AbsorbColor
    absorbbar:SetStatusBarColor(color.r, color.g, color.b)
  elseif absorbbar then
    absorbbar:Hide()
    absorbbar.glow:Hide()
  end
end

local function UpdateExtensions(extended, unitid, style)
  local visual = extended.visual
  local absorbbar = visual.absorbbar

  if not ENABLE_ABSORB or not absorbbar then return end

  -- Code for absorb calculation see CompactUnitFrame.lua
  local absorb = UnitGetTotalAbsorbs(unitid) or 0

  if absorb == 0 or IGNORED_STYLES[style] then
    absorbbar.glow:Hide()
    absorbbar:Hide()
    return
  end

  local health = UnitHealth(unitid) or 0
  local health_max = UnitHealthMax(unitid) or 0

  -- Don't fill outside the the health bar with absorbs; instead show an overabsorb glow
  if health + absorb >= health_max then
    -- absorb + current health >  max health => just show absorb up to max health, not outside of healthbar
    absorb = health_max - health
    if absorb < 0 then
      absorb = 0
    end

    -- show spark for over-absorbs
    absorbbar.glow:Show()
  else
    absorbbar.glow:Hide()
  end

  local healthbar = visual.healthbar
  if absorb > 0 then
    absorbbar:SetPoint("LEFT", healthbar, "LEFT", (health / health_max) * healthbar:GetWidth(), 0)
    absorbbar:SetSize((absorb / health_max) * healthbar:GetWidth(), healthbar:GetHeight())
    absorbbar:Show()
  else
    absorbbar:Hide()
  end
end

--local TEST_INTERVAL = 5
--local time_window
--local test_counter = -1
--local TEST_VALUES = {
--  { health = 0.00, absorb = 0.80, },
--  { health = 0.25, absorb = 0.80, },
--  { health = 1.00, absorb = 0.80, },
--  { health = 0.00, absorb = 0.20, },
--  { health = 0.25, absorb = 0.20, },
--  { health = 0.50, absorb = 0.20, },
--  { health = 0.75, absorb = 0.20, },
--  { health = 1.00, absorb = 0.20, },
----    { health = 0.20, absorb = 0.20, },
--}
--
--local function Test_UnitGetTotalAbsorbs(unitid)
--  if UnitIsUnit("target", unitid) then
--    if (time() > (time_window or 0)) then
--      test_counter = (test_counter + 1) % (#TEST_VALUES)
--    end
--    return UnitHealthMax(unitid) * TEST_VALUES[test_counter + 1].absorb
--  else
--    return UnitGetTotalAbsorbs(unitid) or 0
--  end
--end
--
--local function Test_UnitHealth(unitid)
--  if UnitIsUnit("target", unitid) then
--    if (time() > (time_window or 0)) then
--      time_window = time() + TEST_INTERVAL
--    end
--    return UnitHealthMax(unitid) * TEST_VALUES[test_counter + 1].health
--  else
--    return UnitHealth(unitid) or 0
--  end
--end
--
--local function Test_UpdateExtensions(extended, unitid, style)
--  if not ENABLE_ABSORB then return end
--
--  local visual = extended.visual
--  local absorbbar = visual.absorbbar
--  local absorbglow = absorbbar.glow
--
--  if IGNORED_STYLES[style] then
--    absorbglow:Hide()
--    absorbbar:Hide()
--    return
--  end
--
--  -- Code for absorb calculation see CompactUnitFrame.lua
--  local absorb = Test_UnitGetTotalAbsorbs(unitid) or 0
--  if absorb == 0 then
--    absorbglow:Hide()
--    absorbbar:Hide()
--    return
--  end
--
--  local healthbar = visual.healthbar
--  local health = Test_UnitHealth(unitid) or 0
--  local health_max = UnitHealthMax(unitid) or 0
--
--  -- Don't fill outside the the health bar with absorbs; instead show an overabsorb glow
--  if health + absorb >= health_max then
--    -- absorb + current health >  max health => just show absorb up to max health, not outside of healthbar
--    absorb = health_max - health
--    if absorb < 0 then
--      absorb = 0
--    end
--
--    -- show spark for over-absorbs
--    absorbglow:Show()
--  else
--    absorbglow:Hide()
--  end
--
--  if absorb > 0 then
--    --healthbar:SetValue(health)
--    --absorbbar:SetMinMaxValues(0, health_max)
--    --absorbbar:SetValue(absorb / health_max)
--    --absorbbar:SetValue(absorb)
--    --absorbbar:ClearAllPoints()
--    absorbbar:SetPoint("LEFT", healthbar, "LEFT", (health / health_max) * healthbar:GetWidth(), 0)
--    absorbbar:SetSize((absorb / health_max) * healthbar:GetWidth(), healthbar:GetHeight())
--
--    absorbbar:Show()
--  else
--    absorbbar:Hide()
--  end
--end

ThreatPlates.CreateExtensions = CreateExtensions
-- ThreatPlates.UpdateExtensions = UpdateAbsorbs
ThreatPlates.UpdateExtensions = UpdateExtensions
--ThreatPlates.UpdateExtensions = Test_UpdateExtensions