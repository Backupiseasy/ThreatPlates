local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

-------------------
-- Threat Widget --
-------------------

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitIsOffTanked = ThreatPlates.UnitIsOffTanked
local ShowThreatFeedback = ThreatPlates.ShowThreatFeedback
local GetUniqueNameplateSetting = ThreatPlates.GetUniqueNameplateSetting

local UnitGUID = UnitGUID

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

--local function UpdateSettings()
--end

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

      if db.art.theme == "bar" then
        frame.LeftTexture:ClearAllPoints(frame)
        frame.LeftTexture:SetSize(265, 64)
        frame.LeftTexture:SetPoint("CENTER", frame:GetParent(), "CENTER")
        frame.LeftTexture:SetTexture(PATH .. db.art.theme.."\\"..threatLevel)
        frame.LeftTexture:SetTexCoord(0, 1, 0, 1)

        frame.RightTexture:Hide()
      else
        frame.LeftTexture:ClearAllPoints(frame)
        frame.LeftTexture:SetSize(64, 64)
        frame.LeftTexture:SetPoint("RIGHT", frame:GetParent().visual.healthbar, "LEFT", -4, 0)
        frame.LeftTexture:SetTexture(PATH .. db.art.theme.."\\"..threatLevel)
        frame.LeftTexture:SetTexCoord(0, 0.25, 0, 1)

        frame.RightTexture:SetTexture(PATH .. db.art.theme.."\\"..threatLevel)
        frame.RightTexture:SetTexCoord(0.75, 1, 0, 1)
        frame.RightTexture:Show()
      end

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
  frame:SetFrameLevel(parent:GetFrameLevel() + 7)
  frame.LeftTexture = frame:CreateTexture(nil, "OVERLAY", 6)
  frame.RightTexture = frame:CreateTexture(nil, "OVERLAY", 6)
  frame.RightTexture:SetPoint("LEFT", parent.visual.healthbar, "RIGHT", 4, 0)
  frame.RightTexture:SetSize(64, 64)

--  UpdateSettings(frame)
--  frame.UpdateConfig = UpdateSettings
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
