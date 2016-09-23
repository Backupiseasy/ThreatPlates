local ADDON_NAME, NAMESPACE = ...
ThreatPlates = NAMESPACE.ThreatPlates

-----------------------
-- Auras Widget --
-----------------------

local isAuraEnabled
local OldUpdate
local OldUpdateConfig

-- two constants from TidyPlates AuraWidget
local AURA_TARGET_HOSTILE = 1
local AURA_TARGET_FRIENDLY = 2
local AURA_TYPE = { Buff = 1, Curse = 2, Disease = 3, Magic = 4, Poison = 5, Debuff = 6, }

-- local OldUseSquareDebuffIcon = nil
-- local OldUseWideDebuffIcon = nil

-- save a local version to detect a change efficiently (and not cycle through all auras for nothing)
local enable_cooldown_spiral

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function enabled()
	if TidyPlatesThreat.db.profile.debuffWidget.ON then
		if not isAuraEnabled then
			TidyPlatesWidgets.EnableAuraWatcher()
			--TidyPlatesWidgets.SetAuraFilter(AuraFilter)
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

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
	-- for _, widget in pairs(WidgetList) do
	-- 	widget:Hide()
	-- end
	-- WidgetList = {}
-- end
-- ThreatPlatesWidgets.ClearAllAuraWidgets = ClearAllWidgets

-- return value: show, priority, r, g, b (color for ?)
local function AuraFilter(aura)
	local DB = TidyPlatesThreat.db.profile.debuffWidget
	local isType, isShown

	if aura.reaction == AURA_TARGET_HOSTILE and DB.showEnemy then
		isShown = true
	elseif aura.reaction == AURA_TARGET_FRIENDLY and DB.showFriendly then
		isShown = true
	end

	if aura.effect == "HELPFUL" and DB.displays[AURA_TYPE.Buff] then
		isType = true
	elseif aura.effect == "HARMFUL" and DB.displays[AURA_TYPE.Debuff] then
		-- only show aura types configured in the options
		if aura.type then
			isType = DB.displays[AURA_TYPE[aura.type]]
		else
			isType = true
		end
	end

	if isShown and isType then
		local mode = DB.mode
		local spellfound = tContains(DB.filter, aura.name)
		if spellfound then spellfound = true end
		local isMine = (aura.caster == "player") or (aura.caster == "pet")
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

-- enable/disable spiral cooldown an aura icons
local function SetCooldownSpiral(frame)
	local db = TidyPlatesThreat.db.profile.debuffWidget

 	if (enable_cooldown_spiral ~= db.cooldownSpiral) then
		enable_cooldown_spiral = db.cooldownSpiral

		local AuraIconFrames = frame.AuraIconFrames
		for index = 1, #AuraIconFrames do
				AuraIconFrames[index].Cooldown:SetDrawEdge(enable_cooldown_spiral)
				AuraIconFrames[index].Cooldown:SetDrawSwipe(enable_cooldown_spiral)
		end
	end
end

-- local function ThreatPlatesUseSquareDebuffIcon()
-- 	local ProfDB = TidyPlatesThreat.db.profile
-- 	-- Overwrite default behaviour if ThreatPlates is actually the active theme
-- 	if (TidyPlatesOptions.ActiveTheme == THREAD_PLATES_NAME) and (ProfDB.debuffWidget.style == "wide") then
-- 		OldUseWideDebuffIcon()
-- 	else
-- 		OldUseSquareDebuffIcon()
-- 	end
-- end
-- ThreatPlatesWidgets.UseSquareDebuffIcon = ThreatPlatesUseSquareDebuffIcon
--
-- local function ThreatPlatesUseWideDebuffIcon()
-- 	local ProfDB = TidyPlatesThreat.db.profile
-- 	-- Overwrite default behaviour if ThreatPlates is actually the active theme
-- 	if (TidyPlatesOptions.ActiveTheme == THREAD_PLATES_NAME) and (ProfDB.debuffWidget.style == "square") then
-- 		OldUseSquareDebuffIcon()
-- 	else
-- 		OldUseWideDebuffIcon()
-- 	end
-- end
-- ThreatPlatesWidgets.UseWideDebuffIcon = ThreatPlatesUseWideDebuffIcon

-- work around TidyPlateHubs overwriting debuff size of non-Hub-compatible themes
-- if not OldUseSquareDebuffIcon then
-- 	-- Backup original fuctions for setting debuff size
-- 	OldUseSquareDebuffIcon = TidyPlatesWidgets.UseSquareDebuffIcon
-- 	OldUseWideDebuffIcon = TidyPlatesWidgets.UseWideDebuffIcon
--
-- 	-- And replace them with new functions which respect ThreatPlates settings
-- 	TidyPlatesWidgets.UseSquareDebuffIcon = ThreatPlatesWidgets.UseSquareDebuffIcon
-- 	TidyPlatesWidgets.UseWideDebuffIcon = ThreatPlatesWidgets.UseWideDebuffIcon
-- end


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

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function CustomUpdateWidgetFrame(frame, unit)
	if TidyPlatesThreat.db.profile.debuffWidget.targetOnly and not unit.isTarget then
		frame:_Hide()
		return
	end

	--TidyPlatesWidgets.SetAuraFilter(AuraFilter)

	-- CustomAuraUpdate substitues AuraWidget.Update and AuraWidget.UpdateContext
	--   AuraWidget.Update is sometimes (first call after reload UI) called with unit.unitid = nil
	if (unit and unit.unitid) then
		frame.OldUpdate(frame, unit)
	end
	--frame.UpdateConfig(frame)

	frame:SetScale(TidyPlatesThreat.db.profile.debuffWidget.scale)
	frame:SetPoint(TidyPlatesThreat.db.profile.debuffWidget.anchor, frame:GetParent(), TidyPlatesThreat.db.profile.debuffWidget.x, TidyPlatesThreat.db.profile.debuffWidget.y)
	--frame:SetPoint(TidyPlatesThreat.db.profile.debuffWidget.anchor, frame:GetParent(), "CENTER", TidyPlatesThreat.db.profile.debuffWidget.x, TidyPlatesThreat.db.profile.debuffWidget.y)
	SetCooldownSpiral(frame)

	-- target nameplates are often overlapped by other nameplates, this fixes it:
	-- set frame level higher to make auras apear on top
	if (unit and unit.isTarget) then
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

local function CreateAuraWidget(plate)
	-- Required Widget Code
	-- local frame = CreateFrame("Frame", nil, parent)
	-- frame:Hide()

	-- Custom Code III
	--------------------------------------
	local frame = TidyPlatesWidgets.CreateAuraWidget(plate)
	frame:Hide()

	--frame:SetPoint(config.anchor or "TOP", plate, config.x or 0, config.y or 0)
	frame:SetPoint(TidyPlatesThreat.db.profile.debuffWidget.anchor, plate, TidyPlatesThreat.db.profile.debuffWidget.x, TidyPlatesThreat.db.profile.debuffWidget.y)
	frame:SetFrameLevel(plate:GetFrameLevel() + 1)

	TidyPlatesWidgets.SetAuraFilter(AuraFilter)
	frame.OldUpdate = frame.Update
	frame.OldUpdateConfig = frame.UpdateConfig
	frame.Update = CustomUpdateWidgetFrame
	frame.UpdateContext = CustomUpdateWidgetFrame
	frame.UpdateConfig = CustomUpdateConfig
	-- frame.UpdateTarget = UpdateWidgetTarget - not yet used, I think

	-- disable spiral cooldown an aura icons
	enable_cooldown_spiral = nil
	SetCooldownSpiral(frame)
	--------------------------------------
	-- End Custom Code
	-- frame.UpdateContext = UpdateWidgetContext
	-- Required Widget Code
	-- frame.Update = UpdateWidgetFrame
	-- frame._Hide = frame.Hide
	-- frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end
	frame._Show = frame.Show
	frame.Show = function() if (TidyPlatesOptions.ActiveTheme ~= THREAD_PLATES_NAME) then	frame:_Hide()	else frame:_Show() end end

	return frame
end

ThreatPlatesWidgets.RegisterWidget("AuraWidgetThreatPlates", CreateAuraWidget, false, enabled)

------------------------
-- Threat Line Widget --
------------------------

-- local function ThreatLineEnable()
-- 	return TidyPlatesThreat.db.profile.tankedWidget.ON
-- end

--ThreatPlatesWidgets.RegisterWidget("ThreatLineWidget",CreateAuraWidget,true,AuraEnable)
-- End Threat Line Widget --
