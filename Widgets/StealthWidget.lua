---------------------------------------------------------------------------------------------------
-- Stealth Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = (Addon.CLASSIC and {}) or Addon.Widgets:NewWidget("Stealth")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local strsplit = strsplit

-- WoW APIs
local UnitReaction, UnitIsPlayer, UnitBuff = UnitReaction, UnitIsPlayer, UnitBuff

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

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
  -- Battle for Azeroth
  [230368] = true, -- Detector
  [248705] = true, -- Detector
  [311928] = true, -- Sight Beyond Sight
}

local DETECTION_UNITS = {
  -- Legion
  ["109229"] = true, -- Nightfallen Construct (Suramar)
  ["111354"] = true, -- Taintheart Befouler
  ["111528"] = true, -- Deathroot Ancient
  -- Battle for Azeroth
  ["148483"] = true, -- Ancestral Avenger (Battle of Dazar'alor)
  ["148488"] = true, -- Unliving Augur (Battle of Dazar'alor)
  ["122984"] = true, -- Dazar'ai Colossus (Atal'Dazar)
  ["154459"] = true, -- Horde Vanguard
  ["151945"] = true, -- Scavenging Dunerunner
  -- ["159425"] = true, -- Occult Shadowmender
  ["159303"] = true, -- Monstrous Behemoth
  ["159320"] = true, -- Amathet
  ["161416"] = true, -- Aqir Shadowcrafter
  ["162534"] = true, -- Anubisath Sentinel
  ["162508"] = true, -- Anubisath Sentinel
  ["162417"] = true, -- Anubisath Sentinel
  ["161571"] = true, -- Anubisath Sentinel
  ["159219"] = true, -- Umbral Seer
}

---------------------------------------------------------------------------------------------------
-- Stealth Widget Functions
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = _G.CreateFrame("Frame", nil, tp_frame)
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

function Widget:IsEnabled()
  local db = TidyPlatesThreat.db.profile.stealthWidget
  return db.ON or db.ShowInHeadlineView
end

function Widget:EnabledForStyle(style, unit)
  if UnitReaction(unit.unitid, "player") > 4 or unit.type == "PLAYER" then return false end

  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return TidyPlatesThreat.db.profile.stealthWidget.ShowInHeadlineView
  elseif style ~= "etotem" then
    return TidyPlatesThreat.db.profile.stealthWidget.ON
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  local name, spell_id

  if DETECTION_UNITS[unit.NPCID] then
    name = unit.NPCID
  else
    local DETECTION_AURAS, UnitBuff = DETECTION_AURAS, UnitBuff
    local unitid = unit.unitid
    local name, _
    for i = 1, 40 do
      name, _, _, _, _, _, _, _, _, spell_id = UnitBuff(unitid, i)
      if not name or DETECTION_AURAS[spell_id] then
        break
      end
    end
  end

  if not name then
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

--function Widget:OnUpdateStyle(widget_frame, unit)
--  local db = TidyPlatesThreat.db.profile.stealthWidget
--  -- Updates based on settings / unit style
--  if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
--    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), "CENTER", db.x_hv, db.y_hv)
--  else
--    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), "CENTER", db.x, db.y)
--  end
--end