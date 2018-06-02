---------------------------------------------------------------------------------------------------
-- Stealth Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Module = Addon:NewModule("Stealth")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame
local UnitReaction, UnitIsPlayer, UnitBuff = UnitReaction, UnitIsPlayer, UnitBuff

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local STEALTH_ICON_TEXTURE = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\StealthWidget\\stealthicon"

local DETECTION_AURAS = {
  [18950] = true, -- Invisibility and Stealth Detection - not really sure if necessary as aura is hidden
  [34709] = true, -- Shadow Sight
  [41634] = true, -- Invisibility and Stealth Detection - not really sure if necessary as aura is hidden
  [67236] = true, -- Invisibility and Stealth Detection - not really sure if necessary as aura is hidden
  [70465] = true, -- Invisibility and Stealth Detection - not really sure if necessary as aura is hidden
  [79140] = true, -- Vendetta
  [93105] = true, -- Invisibility and Stealth Detection - not really sure if necessary as aura is hidden
  [127907] = true, -- Phosphorescence
  [127913] = true, -- Phosphorescence
  [148500] = true, -- Invisibility and Stealth Detection - not really sure if necessary as aura is hidden
  [155183] = true, -- Invisibility and Stealth Detection - not really sure if necessary as aura is hidden
  [169902] = true, -- All-Seeing Eye
  [201626] = true, -- Sight Beyond Sight
  [201746] = true, -- Weapon Scope
  [202568] = true, -- Piercing Vision
  [203149] = true, -- Animal Instincts
  [203761] = true, -- Detector
  [213486] = true, -- Demonic Vision
  [214793] = true, -- Vigilant
  [225649] = true, -- Shadow Sight
  [232143] = true, -- Demonic Senses
  [232234] = true, -- On High Alert
  [242962] = true, -- One With the Void
  [242963] = true, -- One With the Void
}

---------------------------------------------------------------------------------------------------
-- Stealth Widget Functions
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Module functions for creation and update
---------------------------------------------------------------------------------------------------

function Module:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 9)
  widget_frame:SetSize(64, 64)
  widget_frame.Icon = widget_frame:CreateTexture(nil, "OVERLAY")
  widget_frame.Icon:SetAllPoints(widget_frame)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Module:IsEnabled()
  return TidyPlatesThreat.db.profile.stealthWidget.ON or TidyPlatesThreat.db.profile.stealthWidget.ShowInHeadlineView
end

function Module:EnabledForStyle(style, unit)
  if UnitReaction(unit.unitid, "player") > 4 or unit.type == "PLAYER" then return false end

  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return TidyPlatesThreat.db.profile.stealthWidget.ShowInHeadlineView
  elseif style ~= "etotem" then
    return TidyPlatesThreat.db.profile.stealthWidget.ON
  end
end

function Module:OnUnitAdded(widget_frame, unit)
  -- name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable,
  -- nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff("unit", index or "name"[, "rank"[, "filter"]])

  local i = 1
  local found = false
  -- or check for (?=: Invisibility and Stealth Detection)
  -- TODO: for oder do-while (what#s more efficient) with break
  repeat
    local name, _, _, _, _, _, _, _, _, _, spell_id = UnitBuff(unit.unitid, i)
    if DETECTION_AURAS[spell_id] then
      found = true
    else
      i = i + 1
    end
  until found or not name

  if not found then
    widget_frame:Hide() -- not necessary as this does never change after a unit was added
    return
  end

  local db = TidyPlatesThreat.db.profile.stealthWidget

  -- Updates based on settings / unit style
  if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), "CENTER", db.x_hv, db.y_hv)
  else
    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), "CENTER", db.x, db.y)
  end

  -- Updates based on settings
  widget_frame:SetSize(db.scale, db.scale)
  widget_frame:SetAlpha(db.alpha)

  -- Updates based on unit status
  widget_frame.Icon:SetTexture(STEALTH_ICON_TEXTURE)

  widget_frame:Show()
end

--function Module:OnUpdateStyle(widget_frame, unit)
--  local db = TidyPlatesThreat.db.profile.stealthWidget
--  -- Updates based on settings / unit style
--  if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
--    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), "CENTER", db.x_hv, db.y_hv)
--  else
--    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), "CENTER", db.x, db.y)
--  end
--end