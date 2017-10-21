-------------------
-- Threat Widget --
-------------------
local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitIsOffTanked = ThreatPlates.UnitIsOffTanked
local ShowThreatFeedback = ThreatPlates.ShowThreatFeedback
local GetUniqueNameplateSetting = ThreatPlates.GetUniqueNameplateSetting

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ThreatWidget\\"
-- local WidgetList = {}

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function enabled()
	return TidyPlatesThreat.db.profile.threat.art.ON
end

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
-- 	for _, widget in pairs(WidgetList) do
-- 		widget:Hide()
-- 	end
-- end
-- ThreatPlatesWidgets.ClearAllThreatWidgets = ClearAllWidgets

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function UpdateWidgetFrame(frame, unit)
	local db = TidyPlatesThreat.db.profile.threat

  if unit.isMarked and db.marked.art then
    frame:_Hide()
  else
    local style = unit.TP_Style

    if style == "unique" then
      local unique_setting = GetUniqueNameplateSetting(unit)
      if unique_setting.UseThreatColor then
        -- set style to tank/dps or normal
        style = ThreatPlates.GetThreatStyle(unit)
      end
    end

    -- Check for InCombatLockdown() and unit.type == "NPC" and unit.reaction ~= "FRIENDLY" not necessary
    -- for dps/tank as these styles automatically require that
    local show = (style == "dps" or style == "tank")

    if show and ShowThreatFeedback(unit) then
      local threatLevel
      if style == "tank" then -- Tanking uses regular textures / swapped for dps / healing
        if db.toggle.OffTank and UnitIsOffTanked(unit) then
          threatLevel = "OFFTANK"
        else
          threatLevel = unit.threatSituation
        end
      else -- dps or normal
        if unit.threatSituation == "HIGH" then
          threatLevel = "LOW"
        elseif unit.threatSituation == "LOW" then
          threatLevel = "HIGH"
        elseif unit.threatSituation == "MEDIUM" then
          threatLevel = "MEDIUM"
        end
      end

      frame.Icon:SetTexture(PATH .. db.art.theme.."\\"..threatLevel)
      frame:Show()
    else
      frame:_Hide()
    end
  end
end

-- Context
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
	frame:SetFrameLevel(parent.visual.healthbar:GetFrameLevel() + 2)
	frame:SetSize(265, 64)
	frame:SetPoint("CENTER", parent, "CENTER")
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	frame.Icon:SetAllPoints(frame)
	--------------------------------------
	-- End Custom Code

	-- Required Widget Code
	frame.UpdateContext = UpdateWidgetContext
	frame.Update = UpdateWidgetFrame
	frame._Hide = frame.Hide
	frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end

	return frame
end

ThreatPlatesWidgets.RegisterWidget("ThreatArtWidgetTPTP", CreateWidgetFrame, false, enabled)
