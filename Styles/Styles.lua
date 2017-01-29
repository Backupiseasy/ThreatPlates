local _, ns = ...
local t = ns.ThreatPlates

---------------------------------------------------------------------------------------------------

-- TODO: rework, TidyPlates has several new attributes to make this easier, e.g., isBoss
local function GetGeneral(unit)
	local r, d, e = unit.reaction, unit.isDangerous, unit.isElite
	if unit.isTapped then
		return "Tapped"
	elseif r == "NEUTRAL" then
		if m then
			return "Mini"
		else
			return "Neutral"
		end
	elseif r ~= "NEUTRAL" and r~= "TAPPED" then
		if d and e then
			return "Boss"
		elseif not d and e then
			return "Elite"
		elseif unit.isMini then
			return "Mini"
		elseif not d and not e then
			return "Normal"
		end
	else
		return "empty"
	end
end

local function GetType(unit)
	local db = TidyPlatesThreat.db.profile
	local unitRank
	local totem = ThreatPlates_Totems[unit.name]
	local unique = tContains(db.uniqueSettings.list, unit.name)
	if totem then
		unitRank = "Totem"
	elseif unique then
		for k_c,k_v in pairs(db.uniqueSettings.list) do
			if k_v == unit.name then
				if db.uniqueSettings[k_c].useStyle then
					unitRank = "Unique"
				else
					unitRank = GetGeneral(unit)
				end
			end
		end
	else
		unitRank = GetGeneral(unit)
	end
	return unitRank
end

local function GetUniqueType(unit)
	local db = TidyPlatesThreat.db.profile
	local unitRank

	local totem = ThreatPlates_Totems[unit.name]
	local unique = tContains(db.uniqueSettings.list, unit.name)

	if totem then
		unitRank = "Totem"
	elseif unique then
		for k_c,k_v in pairs(db.uniqueSettings.list) do
			if k_v == unit.name then
				if db.uniqueSettings[k_c].useStyle then
					unitRank = "Unique"
				end
			end
		end
	end

	return unitRank
end

local function ShowUnit(unit)
	local db = TidyPlatesThreat.db.profile
	local faction = ""
	local unit_type = "NPC"
	local show = false
	local headline_view = false

	local unit_type = GetUniqueType(unit)
	if unit_type == "Unique" then
		show = true
	else
		if unit.reaction == "NEUTRAL" then
			faction = "Neutral"
			if unit.isMini then
				unit_type = "Minor"
			elseif UnitPlayerControlled(unit.unitid) then
				unit_type = "Guardian"
			else  --if unit.type == "NPC" then
				unit_type = "NPC"
			end
		else
			if unit.reaction == "FRIENDLY" then
				faction = "Friendly"
			elseif unit.reaction == "HOSTILE" then
				faction = "Hostile"
			end

			if unit.reaction == "HOSTILE" and unit.isMini then -- no minor mobs for friendly, as far as I know
				unit_type = "Minor"
			elseif unit.type == "PLAYER" then
				unit_type = "Player"
			-- elseif unit_type == "Totem" then
			-- 	unit_type = "Totem"
			elseif UnitIsOtherPlayersPet(unit.unitid) then -- player pets are also considered guardians, so this check has priority
				unit_type =  "Pet"
			elseif UnitPlayerControlled(unit.unitid) then
				unit_type = "Guardian"
			elseif unit_type ~= "Totem" then --if unit.type == "NPC" then
				unit_type = "NPC"
			end
		end

		show = db.visibility["show"..faction..unit_type]
		headline_view = db.visibility["show"..faction..unit_type.."HeadlineView"]

		if (unit.isElite and db.visibility.hideElite) or (unit.isBoss and db.visibility.hideBoss) or
			(unit.isTapped and db.visibility.hideTapped) then
			show = false
		elseif db.visibility.hideNormal and not (unit.isElite or unit.isBoss or unit.isDangerous) then
			show = false
		elseif unit.unitid and UnitIsBattlePet(unit.unitid) then
			-- TODO: add configuration option for enable/disable
			show = false
		end
	end

	--t.PrintTargetInfo(unit)

	return show, unit_type, headline_view
end

local function IsUnitActive(unit)
	return (unit.health < unit.healthmax) or (unit.threatValue > 1) or unit.isMarked	-- or unit.isInCombat
end

-- Returns style based on threat (currently checks for in combat, should not do hat)
local function GetThreatStyle(unit)
	local db = TidyPlatesThreat.db.profile
	local style

	-- style tank/dps only used for NPCs/non-player units
	if InCombatLockdown() and unit.type == "NPC" and db.threat.ON then
		--		if db.threat.toggle[T] then
			if db.threat.nonCombat  then
				-- db.thread.nonCombat not nessessary in following if statement?!?
				if (unit.isInCombat or (unit.health < unit.healthmax)) and db.threat.nonCombat then
					if TidyPlatesThreat:GetSpecRole() then
						style = "tank"
					else
						style = "dps"
					end
				end
			else
				if TidyPlatesThreat:GetSpecRole()	then
					style = "tank"
				else
					style = "dps"
				end
			end
--		end
	end
	if not style then
		style = "normal"
	end

	return style
end

local function SetStyle(unit)
	local db = TidyPlatesThreat.db.profile
	local style, unique_setting

	local  show, unit_type, headline_view = ShowUnit(unit)

	if not show then
		style = "empty"
	elseif show and headline_view and t.AlphaFeatureHeadlineView() then
		TidyPlatesHubFunctions.SetStyleNamed(unit)
		style = "NameOnly"
	else
		if unit_type == "Totem" then
			local tS = db.totemSettings[ThreatPlates_Totems[unit.name]]
			if tS[1] then
				if db.totemSettings.hideHealthbar then
					style = "etotem"
				else
					style = "totem"
				end
			end
		elseif unit_type == "Unique" then
			for k_c,k_v in pairs(db.uniqueSettings.list) do
				if k_v == unit.name then
				unique_setting = db.uniqueSettings[k_c]
				if unique_setting.showNameplate then
						style = "unique"
					end
				end
			end
		elseif unit_type then
			if unit.reaction == "FRIENDLY" then
				style = "normal"
			end
		else
			if db.nameplate.toggle[T] then
				-- style tank/dps only used for NPCs/non-player units, old: unit.class == "UNKNOWN"
				if InCombatLockdown() and unit.type == "NPC" and db.threat.ON then
					if db.threat.toggle[T] then
						if db.threat.nonCombat  then
							-- db.thread.nonCombat not nessessary in following if statement?!?
							if (unit.isInCombat or (unit.health < unit.healthmax)) and db.threat.nonCombat then
								if TidyPlatesThreat:GetSpecRole() then
									style = "tank"
								else
									style = "dps"
								end
							end
						else
							if TidyPlatesThreat:GetSpecRole()	then
								style = "tank"
							else
								style = "dps"
							end
						end
					end
				end
				if not style then
					style = "normal"
				end
			end
		end
	end

	-- t.PrintTargetInfo(unit)
	if not style then style = "etotem" end

	return style, unique_setting
end

TidyPlatesThreat.GetGeneral = GetGeneral
TidyPlatesThreat.GetType = GetType
TidyPlatesThreat.SetStyle = SetStyle
TidyPlatesThreat.GetStyle = GetStyle
TidyPlatesThreat.GetThreatStyle = GetThreatStyle
