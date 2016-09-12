local _, ns = ...
local t = ns.ThreatPlates

-- TODO: rework, TidyPlates has several new attributes to make this easier, e.g., isBoss
local function GetGeneral(unit)
	local r, d, e, m = unit.reaction, unit.isDangerous, unit.isElite, unit.isMini
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
		elseif m then
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

local function ShowUnit(unit)
	local db = TidyPlatesThreat.db.profile
	local T = GetType(unit)

	local faction = ""
	local unit_type = "NPC"
	local show = false
	local headline_view = false

	if unit.reaction == "FRIENDLY" then
		faction = "Friendly"
		if unit.type == "PLAYER" then
			unit_type = "Player"
		elseif T == "Totem" then
			unit_type = "Totem"
		elseif UnitPlayerControlled(unit.unitid) then
			unit_type = "Guardian"
		elseif UnitIsOtherPlayersPet(unit.unitid) then
			unit_type =  "Pet"
		else --if unit.type == "NPC" then
			unit_type = "NPC"
		end
		-- missing: Guardina, Creature & Properties
	elseif unit.reaction == "HOSTILE" then
		faction = "Hostile"
		if unit.isMini then
			unit_type = "Minor"
		elseif unit.type == "PLAYER" then
			unit_type = "Player"
		elseif T == "Totem" then
			unit_type = "Totem"
		elseif UnitPlayerControlled(unit.unitid) then
			unit_type = "Guardian"
		elseif UnitIsOtherPlayersPet(unit.unitid) then
			unit_type =  "Pet"
		else  --if unit.type == "NPC" then
			unit_type = "NPC"
		end

		-- missing: Guardina, Creature & Properties
	elseif unit.reaction == "NEUTRAL" then
		faction = "Neutral"
		if unit.isMini then
			unit_type = "Minor"
		else  --if unit.type == "NPC" then
			unit_type = "NPC"
		end
		-- missing: Guardian
	end

	show = db.visibility["show"..faction..unit_type]
	headline_view = db.visibility["show"..faction..unit_type.."HeadlineView"]

	if (unit.isElite and db.visibility.hideElite) or (unit.isBoss and db.visibility.hideBoss) or
		(unit.isTapped and db.visibility.hideTapped) then
		show = false
	elseif db.visibility.hideNormal and not (unit.isElite or unit.isBoss or unit.isDangerous) then
		show = false
	-- TODO: add configuration option for enable/disable
	elseif UnitIsBattlePet(unit.unitid) then
		show = false
	end

	return show, headline_view
end

local function IsUnitActive(unit)
	return (unit.health < unit.healthmax) or (unit.threatValue > 1) or unit.isMarked	-- or unit.isInCombat
end

local function SetStyle(unit)
	local db = TidyPlatesThreat.db.profile
	local T = GetType(unit)
	local style

	-- just for alpha feature alphaFeatureHeadlineView
	if t.AlphaFeatureHeadlineView() then
		local hub_style = TidyPlatesHubFunctions.SetStyleNamed(unit)
		if (hub_style == "NameOnly") then
			return "NameOnly"
		end
	end

	if T == "Totem" then
		local tS = db.totemSettings[ThreatPlates_Totems[unit.name]]
		if tS[1] then
			if db.totemSettings.hideHealthbar then
				style = "etotem"
			else
				style = "totem"
			end
		end
	elseif T == "Unique" then
		for k_c,k_v in pairs(db.uniqueSettings.list) do
			if k_v == unit.name then
				if db.uniqueSettings[k_c].showNameplate then
					style = "unique"
				end
			end
		end
	elseif T then
		if unit.reaction == "FRIENDLY" then
			if db.nameplate.toggle[T] then
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

	local  show, headline_view = ShowUnit(unit)

	if unit.isTarget then
		-- TODO: Guardian, Creature & Pet, Boss, Elite, Tapped
		-- t.DEBUG("unit.name = ", unit.name)
		-- 	t.DEBUG("unit.type = ", unit.type)
		-- 	t.DEBUG("unit.class = ", unit.class)
		-- t.DEBUG("unit.reaction = ", unit.reaction)
		-- 	t.DEBUG("unit.isMini = ", unit.isMini)
		-- 	t.DEBUG("unit.isTapped = ", unit.isTapped)
		-- 	t.DEBUG("unit SetStyle = ", style)
		-- 	t.DEBUG("unit GetType = ", TidyPlatesThreat.GetType(unit))
		-- t.DEBUG("ShowUnit: ", unit.reaction, " ",  unit.type, " -> show = ", show, " + headline view = ", headline_view)

		-- local enemy_totems = GetCVar("nameplateShowEnemyTotems")
		-- local enemy_guardians = GetCVar("nameplateShowEnemyGuardians")
		-- local enemy_pets = GetCVar("nameplateShowEnemyPets")
		-- local enemy_minus = GetCVar("nameplateShowEnemyMinus")
		-- print ("CVars Enemy: totems = ", enemy_totems, " / guardians = ", enemy_guardians, " / pets = ", enemy_pets, " / minus = ", enemy_minus)
		--
		-- local friendly_totems = GetCVar("nameplateShowFriendlyTotems")
		-- local friendly_guardians = GetCVar("nameplateShowFriendlyGuardians")
		-- local friendly_pets = GetCVar("nameplateShowFriendlyPets")
		-- print ("CVars Friendly: totems = ", friendly_totems, " / guardians = ", friendly_guardians, " / pets = ", friendly_pets)
		-- t.DEBUG("unit.isPet = ", UnitIsOtherPlayersPet(unit))
		-- t.DEBUG("unit.isControlled = ", UnitPlayerControlled(unit.unitid))
		-- t.DEBUG("unit.isBattlePet = ", UnitIsBattlePet(unit.unitid))
	end

	if not show then
		style = "empty"
	end

	if style then
	  return style
	else
		return "etotem"
	end
end
TidyPlatesThreat.GetGeneral = GetGeneral
TidyPlatesThreat.GetType = GetType
TidyPlatesThreat.SetStyle = SetStyle
