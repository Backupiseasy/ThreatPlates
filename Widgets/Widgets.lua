local _, ns = ...
local t = ns.ThreatPlates

local AuraType_Index = {
	["Buff"] = 1,
	["Curse"] = 2,
	["Disease"] = 3,
	["Magic"] = 4,
	["Poison"] = 5,
	["Debuff"] = 6,
}

-- two constants from TidyPlates AuraWidget
local AURA_TARGET_HOSTILE = 1
local AURA_TARGET_FRIENDLY = 2

------------------------------------------------------------------------------
-- Local Variable
------------------------------------------------------------------------------

-- save a local version to detect a change efficiently (and not cycle through all auras for nothing)
-- local enable_cooldown_spiral

local function AuraFilter(aura)
	local DB = TidyPlatesThreat.db.profile.debuffWidget
	local isType, isShown

	if aura.reaction == AURA_TARGET_HOSTILE and DB.showEnemy then
		isShown = true
	elseif aura.reaction == AURA_TARGET_FRIENDLY and DB.showFriendly then
		isShown = true
	end

	-- only show aura types configured in the options
	if aura.type and DB.displays[aura.type] then
		isType = true
	else
		isType =  true
	end

	if isShown and isType then
		local mode = DB.mode
		local spellfound = tContains(DB.filter, aura.name)
		if spellfound then spellfound = true end
		local isMine = (aura.caster == "player")
		if mode == "whitelist" then
			return spellfound
		elseif mode == "whitelistMine" then
			if isMine then
				return spellfound
			end
		elseif mode == "all" then
			return true
		elseif mode == "allMine" then
			if isMine then
				return true
			end
		elseif mode == "blacklist" then
			return not spellfound
		elseif mode == "blacklistMine" then
			if isMine then
				return not spellfound
			end
		end
	end
end

ThreatPlatesWidgets.AuraFilter = AuraFilter

	if (TidyPlatesOptions.ActiveTheme == THREAT_PLATES_NAME) and (ProfDB.debuffWidget.style == "wide") then
-- enable/disable spiral cooldown an aura icons
-- TODO: currently disabled because no longer available in TidyPlates (since 6.18.2)
-- local function SetCooldownSpiral(frame)
--  	if (enable_cooldown_spiral ~= TidyPlatesThreat.db.profile.debuffWidget.cooldownSpiral) then
-- 		enable_cooldown_spiral = TidyPlatesThreat.db.profile.debuffWidget.cooldownSpiral
--
-- 		local AuraIconFrames = frame.AuraIconFrames
-- 		for index = 1, #AuraIconFrames do
-- 				AuraIconFrames[index].Cooldown:SetDrawEdge(enable_cooldown_spiral)
-- 				AuraIconFrames[index].Cooldown:SetDrawSwipe(enable_cooldown_spiral)
-- 		end
-- 	end
-- end

do
	local isAuraEnabled
	local function AuraEnable()
		if TidyPlatesThreat.db.profile.debuffWidget.ON then
			if not isAuraEnabled then
				TidyPlatesWidgets.EnableAuraWatcher()
				TidyPlatesWidgets.SetAuraFilter(AuraFilter)
				isAuraEnabled = true
			end
		else
			if isAuraEnabled then
				TidyPlatesWidgets.DisableAuraWatcher()
				isAuraEnabled = false
			end
		end
		return TidyPlatesThreat.db.profile.debuffWidget.ON
	end

	local function CustomAuraUpdate(frame, unit)
		if TidyPlatesThreat.db.profile.debuffWidget.targetOnly and not unit.isTarget then
			frame:Hide()
			return
		end
		-- disable auras in headline-view mode
		if t.AlphaFeatureHeadlineView() and (TidyPlatesThreat.SetStyle(unit) == "NameOnly") then
			frame:Hide()
			return
		end

		TidyPlatesWidgets.SetAuraFilter(AuraFilter)

		-- CustomAuraUpdate substitues AuraWidget.Update and AuraWidget.UpdateContext
		--   AuraWidget.Update is sometimes (first call after reload UI) called with unit.unitid = nil
		--   AuraWidget.UpdateContext is called with no unit (unit = nil)
		if (unit and unit.unitid) then
			frame.OldUpdate(frame,unit)
		end
		frame:SetScale(TidyPlatesThreat.db.profile.debuffWidget.scale)
		frame:SetPoint(TidyPlatesThreat.db.profile.debuffWidget.anchor, frame:GetParent(), TidyPlatesThreat.db.profile.debuffWidget.x, TidyPlatesThreat.db.profile.debuffWidget.y)
		--SetCooldownSpiral(frame)

		-- target nameplates are often overlapped by other nameplates, this fixes it:
		-- set frame level higher to make auras apear on top
		if (unit.isTarget) then
				frame:SetFrameStrata("LOW")
				local AuraIconFrames = frame.AuraIconFrames
			  for index = 1, #AuraIconFrames do
					AuraIconFrames[index]:SetFrameStrata("LOW")
				end
		else
		 	frame:SetFrameStrata("BACKGROUND")
		 	local AuraIconFrames = frame.AuraIconFrames
			 for index = 1, #AuraIconFrames do
				 AuraIconFrames[index]:SetFrameStrata("BACKGROUND")
			 end
		end

		frame:Show()
	end

-- TidyPlates Code: Do we reset Debuff Widget?
	-- local function AddDebuffWidget(plate, enable, config)
	-- 	if enable and config then
	-- 		if not plate.widgets.DebuffWidget then
	-- 			local widget
	-- 			widget =  CreateAuraWidget(plate)
	-- 			widget:SetPoint(config.anchor or "TOP", plate, config.x or 0, config.y or 0) --15, 20)
	-- 			widget:SetFrameLevel(plate:GetFrameLevel()+1)
	-- 			--widget.Filter = DebuffFilter		-- this method of defining the filter function will be deprecated in 6.9
	-- 			plate.widgets.DebuffWidget = widget
	-- 		end
	-- 	elseif plate.widgets.DebuffWidget then
	-- 		plate.widgets.DebuffWidget:Hide()
	-- 		plate.widgets.DebuffWidget = nil
	-- 	 end
	-- end

	local function CreateAuraWidget(plate)
		-- TODO: do get better layering, all widgets must be updated in the same order, I guess? Right now, they are in a table with a random order?
		local frame = TidyPlatesWidgets.CreateAuraWidget(plate)
		--frame:SetPoint(config.anchor or "TOP", plate, config.x or 0, config.y or 0)
		frame:SetPoint(TidyPlatesThreat.db.profile.debuffWidget.anchor, plate, TidyPlatesThreat.db.profile.debuffWidget.x, TidyPlatesThreat.db.profile.debuffWidget.y)
		frame:SetFrameLevel(plate:GetFrameLevel()+1)

		frame.OldUpdate = frame.Update
		frame.Update = CustomAuraUpdate
		frame.UpdateContext = CustomAuraUpdate

		TidyPlatesWidgets.SetAuraFilter(AuraFilter)

		-- disable spiral cooldown an aura icons
		--enable_cooldown_spiral = nil
		--SetCooldownSpiral(frame)

		return frame
	end

	ThreatPlatesWidgets.RegisterWidget("AuraWidget",CreateAuraWidget,true,AuraEnable)

	-- End Aura Widget --

	------------------------
	-- Threat Line Widget --
	------------------------

	local function ThreatLineEnable()
		return TidyPlatesThreat.db.profile.tankedWidget.ON
	end

	--ThreatPlatesWidgets.RegisterWidget("ThreatLineWidget",CreateAuraWidget,true,AuraEnable)
	-- End Threat Line Widget --

	----------------------------
	-- Healer Tracking Widget --
	----------------------------

	local healerTrackerEnabled
	local function HealerTrackerEnable()
		if TidyPlatesThreat.db.profile.healerTracker.ON then
			if not healerTrackerEnabled then
				TidyPlatesUtility.EnableHealerTrack()
			end
		else
			if healerTrackerEnabled then
				TidyPlatesUtility.DisableHealerTrack()
			end
		end
		return TidyPlatesThreat.db.profile.healerTracker.ON
	end

	local function CustomHealerTrackerUpdate(frame, unit)
		-- CustomAuraUpdate substitues AuraWidget.Update and AuraWidget.UpdateContext
		--   AuraWidget.Update is sometimes (first call after reload UI) called with unit.unitid = nil
		--   AuraWidget.UpdateContext is called with no unit (unit = nil)
		if (unit and unit.unitid) then
			frame.OldUpdate(frame,unit)
		end
		frame:SetScale(TidyPlatesThreat.db.profile.healerTracker.scale)
		frame:SetPoint(TidyPlatesThreat.db.profile.healerTracker.anchor, frame:GetParent(), TidyPlatesThreat.db.profile.healerTracker.x, TidyPlatesThreat.db.profile.healerTracker.y)
		frame:Show()
	end

	local function CreateHealerTrackerWidget(plate)
		local frame
		frame = TidyPlatesWidgets.CreateHealerWidget(plate)
		frame.OldUpdate = frame.Update
		frame.Update = CustomHealerTrackerUpdate
		--frame.Filter = AuraFilter
		return frame
	end

	ThreatPlatesWidgets.RegisterWidget("HealerTracker",CreateHealerTrackerWidget,true,HealerTrackerEnable)
end
