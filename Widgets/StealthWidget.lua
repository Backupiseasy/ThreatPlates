-----------------------
-- Stealth Widget --
-----------------------
local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitGUID = UnitGUID
local UnitBuff = UnitBuff

local path = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\StealthWidget\\"
-- local WidgetList = {}

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
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function enabled()
	return TidyPlatesThreat.db.profile.stealthWidget.ON
end

local function EnabledInHeadlineView()
	return TidyPlatesThreat.db.profile.stealthWidget.ShowInHeadlineView
end

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
-- 	for _, widget in pairs(WidgetList) do
-- 		widget:Hide()
-- 	end
-- 	WidgetList = {} -- should not be necessary, as Hide() does that, just to be sure
-- end
-- ThreatPlatesWidgets.ClearAllQuestWidgets = ClearAllWidgets

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function UpdateSettings(frame)
  local db = TidyPlatesThreat.db.profile.stealthWidget

  local size = db.scale
  frame:SetSize(size, size)
  frame:SetPoint("CENTER", frame:GetParent(), db.x, db.y)
  frame:SetAlpha(db.alpha)
  frame.Icon:SetTexture(path.."stealthicon")
end

-- Update Graphics
local function UpdateWidgetFrame(frame, unit)
  if not unit.unitid then return end

  -- name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable,
  -- nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff("unit", index or "name"[, "rank"[, "filter"]])

  local i = 1
  local found = false
  -- or check for (?=: Invisibility and Stealth Detection)
  repeat
    local name, _, _, _, _, _, _, _, _, _, spell_id = UnitBuff(unit.unitid, i)
    --print ("Aura: ", name, spell_id)
    if DETECTION_AURAS[spell_id] then
      found = true
    else
      i = i + 1
    end
  until found or not name

  if found then
		frame:Show()
  else
    frame:_Hide()
  end
end

-- Context - GUID or unitid should only change here, i.e., class changes should be determined here
local function UpdateWidgetContext(frame, unit)
	local guid = unit.guid
	frame.guid = guid

	-- Add to Widget List
	-- if guid then
	-- 	WidgetList[guid] = frame
	-- end

	-- Custom Code II
	--------------------------------------
	if UnitGUID("target") == guid then
		UpdateWidgetFrame(frame, unit)
	else
		frame:_Hide()
	end
	--------------------------------------
	-- End Custom Code
end

local function ClearWidgetContext(frame)
	local guid = frame.guid
	if guid then
		-- WidgetList[guid] = nil
		frame.guid = nil
	end
end

local function CreateWidgetFrame(parent)
	-- Required Widget Code
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()

  -- Custom Code III
  --------------------------------------
  frame:SetFrameLevel(parent:GetFrameLevel() + 9)
  frame:SetSize(64, 64)
  frame.Icon = frame:CreateTexture(nil, "OVERLAY")
  frame.Icon:SetAllPoints(frame)

  UpdateSettings(frame)
  frame.UpdateConfig = UpdateSettings
	--------------------------------------
	-- End Custom Code

	-- Required Widget Code
	frame.UpdateContext = UpdateWidgetContext
	frame.Update = UpdateWidgetFrame
	frame._Hide = frame.Hide
	frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end

	return frame
end

ThreatPlatesWidgets.RegisterWidget("StealthWidgetTPTP", CreateWidgetFrame, false, enabled, EnabledInHeadlineView)
