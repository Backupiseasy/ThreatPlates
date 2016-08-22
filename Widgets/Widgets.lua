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

local OldUseSquareDebuffIcon = nil
local OldUseWideDebuffIcon = nil

------------------------------------------------------------------------------
-- Local Variable
------------------------------------------------------------------------------

local function AuraFilter(aura)
	local DB = TidyPlatesThreat.db.profile.debuffWidget
	local isType, isShown

	-- if aura.reaction == 1 and DB.showEnemy then
	-- 	isShown = true
	-- elseif aura.reaction == 2 and DB.showFriendly then
	-- 	isShown = true
	-- end
	-- aura.reaction seems no longer to be available in auras
	-- This is a dirty hack, I think
	local reaction = UnitReaction("player", aura.unit)
	if reaction < 5 and DB.showEnemy then
		isShown = true
	elseif reaction >= 5 and DB.showFriendly then
		isShown = true
	 end

	-- auras now always seem to be debuffs, so only Disease, Curse, ... is relevant
	-- don't know how to show buffs
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

local function ThreatPlatesUseSquareDebuffIcon()
	local ProfDB = TidyPlatesThreat.db.profile
	-- Overwrite default behaviour if ThreatPlates is actually the active theme
	if (TidyPlatesOptions.ActiveTheme == "Threat Plates") and (ProfDB.debuffWidget.style == "wide") then
		OldUseWideDebuffIcon()
	else
		OldUseSquareDebuffIcon()
	end
end
ThreatPlatesWidgets.UseSquareDebuffIcon = ThreatPlatesUseSquareDebuffIcon

local function ThreatPlatesUseWideDebuffIcon()
	local ProfDB = TidyPlatesThreat.db.profile
	-- Overwrite default behaviour if ThreatPlates is actually the active theme
	if (TidyPlatesOptions.ActiveTheme == "Threat Plates") and (ProfDB.debuffWidget.style == "square") then
		OldUseSquareDebuffIcon()
	else
		OldUseWideDebuffIcon()
	end
end
ThreatPlatesWidgets.UseWideDebuffIcon = ThreatPlatesUseWideDebuffIcon

do
	-- work around TidyPlateHubs overwriting debuff size of non-Hub-compatible themes
	if not OldUseSquareDebuffIcon then
		-- Backup original fuctions for setting debuff size
		OldUseSquareDebuffIcon = TidyPlatesWidgets.UseSquareDebuffIcon
		OldUseWideDebuffIcon = TidyPlatesWidgets.UseWideDebuffIcon

		-- And replace them with new functions which respect ThreatPlates settings
		TidyPlatesWidgets.UseSquareDebuffIcon = ThreatPlatesWidgets.UseSquareDebuffIcon
		TidyPlatesWidgets.UseWideDebuffIcon = ThreatPlatesWidgets.UseWideDebuffIcon
	end

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

		-- CustomAuraUpdate substitues AuraWidget.Update and AuraWidget.UpdateContext
		--   AuraWidget.Update is sometimes (first call after reload UI) called with unit.unitid = nil
		--   AuraWidget.UpdateContext is called with no unit (unit = nil)
		if (unit and unit.unitid) then
			frame.OldUpdate(frame,unit)
		end
		frame:SetScale(TidyPlatesThreat.db.profile.debuffWidget.scale)
		frame:SetPoint(TidyPlatesThreat.db.profile.debuffWidget.anchor, frame:GetParent(), TidyPlatesThreat.db.profile.debuffWidget.x, TidyPlatesThreat.db.profile.debuffWidget.y)
		frame:Show()
	end

	local function CreateAuraWidget(plate)
		local frame

		frame = TidyPlatesWidgets.CreateAuraWidget(plate)
		frame.OldUpdate = frame.Update
		frame.Update = CustomAuraUpdate
		frame.UpdateContext = CustomAuraUpdate
		-- this method of defining the filter function will be deprecated in 6.9
		frame.Filter = AuraFilter

		-- disable spiral cooldown an aura icons
		if not TidyPlatesThreat.db.profile.debuffWidget.cooldownSpiral then
			local AuraIconFrames = frame.AuraIconFrames
			for index = 1, #AuraIconFrames do
					AuraIconFrames[index].Cooldown:SetDrawEdge(false)
					AuraIconFrames[index].Cooldown:SetDrawSwipe(false)
			end
		end

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
