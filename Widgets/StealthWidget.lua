local ADDON_NAME, NAMESPACE = ...
ThreatPlates = NAMESPACE.ThreatPlates

-----------------------
-- Stealth Widget --
-----------------------
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
  [202568] = true, -- Piercing Vision
  [203149] = true, -- Animal Instincts
  [203761] = true, -- Detector
  [213486] = true, -- Demonic Vision
  [225649] = true, -- Shadow Sight
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

-- local function UpdateWidgetConfig(frame)
-- end

-- Update Graphics
local function UpdateWidgetFrame(frame, unit)
  if not unit.unitid then return end

  -- local name, _, icon, stacks, auraType, duration, expiration, caster, _, _, spell_id = UnitAura(unit.unitid, "Invisibility and Stealth Detection")
  -- print ("Spell detection: ", name)

  local i = 1
  local found = false
  -- or check for (?=: Invisibility and Stealth Detection)
  repeat
    local name, _, icon, stacks, auraType, duration, expiration, caster, _, _, spell_id = UnitAura(unit.unitid, i)
    --print ("Aura: ", name, spell_id)
    if DETECTION_AURAS[spell_id] then
      found = true
    else
      i = i + 1
    end
  until found or not name

  if found then
		local db = TidyPlatesThreat.db.profile.stealthWidget
		frame:SetHeight(db.scale)
		frame:SetWidth(db.scale)
		frame:SetPoint(db.anchor, frame:GetParent(), db.x, db.y)
		frame:SetAlpha(db.alpha)
    frame.Icon:SetTexture(path.."stealthicon")
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
	frame:SetHeight(64)
	frame:SetWidth(64)
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	frame.Icon:SetAllPoints(frame)

	--frame.UpdateConfig = UpdateWidgetConfig
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
