local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

----------------------------
-- Healer Tracking Widget --
----------------------------

local OldUpdate
local WidgetList

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local healerTrackerEnabled
local function enabled()
  if TidyPlatesThreat.db.profile.healerTracker.ON then
    if not healerTrackerEnabled then
      TidyPlatesUtilityInternal.EnableHealerTrack()
      healerTrackerEnabled = true
    end
  else
    if healerTrackerEnabled then
      TidyPlatesUtilityInternal.DisableHealerTrack()
      healerTrackerEnabled = false
    end
  end
  return TidyPlatesThreat.db.profile.healerTracker.ON
end

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
-- 	-- for _, widget in pairs(WidgetList) do
-- 	-- 	widget:Hide()
-- 	-- end
--   TidyPlatesUtilityInternal.DisableHealerTrack()
--   healerTrackerEnabled = false
-- end
-- ThreatPlatesWidgets.ClearAllHealerTrackerWidgets = ClearAllWidgets

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function CustomUpdateWidgetFrame(frame, unit)
  -- CustomAuraUpdate substitues AuraWidget.Update and AuraWidget.UpdateContext
  --   AuraWidget.Update is sometimes (first call after reload UI) called with unit.unitid = nil
  -- possibly add: if not unit then return end
	if unit.type == "PLAYER" and TidyPlatesUtilityInternal.IsHealer(unit.name)  then
    if (unit and unit.unitid) then
      frame.OldUpdate(frame,unit)
    end
    frame:SetScale(TidyPlatesThreat.db.profile.healerTracker.scale)
    frame:SetPoint(TidyPlatesThreat.db.profile.healerTracker.anchor, frame:GetParent(), TidyPlatesThreat.db.profile.healerTracker.x, TidyPlatesThreat.db.profile.healerTracker.y)
    frame:Show()
  else
    frame:_Hide()
  end
end

local function CreateWidgetFrame(plate)
  -- Required Widget Code
  -- local frame = CreateFrame("Frame", nil, parent)
	-- frame:Hide()

	-- Custom Code III
	--------------------------------------
  local frame = TidyPlatesWidgets.CreateHealerWidget(plate)

  frame.OldUpdate = frame.Update
  frame.Update = CustomUpdateWidgetFrame
  -- frame.UpdateContext = UpdateWidgetContext - no need to overwrite this, but be aware that it calls UpdateWidgetFrame (internal)
  if not WidgetList then WidgetList = frame.WidgetList end
  --------------------------------------
	-- End Custom Code

	-- Required Widget Code
	-- frame.UpdateContext = UpdateWidgetContext
	-- frame.Update = UpdateWidgetFrame
	-- frame._Hide = frame.Hide
	-- frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end
	return frame
end

ThreatPlatesWidgets.RegisterWidget("HealerTrackerWidgetTPTP", CreateWidgetFrame, false, enabled)
