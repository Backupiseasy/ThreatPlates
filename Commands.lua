local ADDON_NAME, Addon = ...
local TP = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local L = TP.L

local function toggleDPS()
	TidyPlatesThreat:SetRole(false)
	TidyPlatesThreat.db.profile.threat.ON = true
	if TidyPlatesThreat.db.profile.verbose then
		TP.Print(L["-->>|cffff0000DPS Plates Enabled|r<<--"])
		TP.Print(L["|cff89F559Threat Plates|r: DPS switch detected, you are now in your |cffff0000dpsing / healing|r role."])
	end
	Addon:ForceUpdate()
end

local function toggleTANK()
	TidyPlatesThreat:SetRole(true)
	TidyPlatesThreat.db.profile.threat.ON = true
	if TidyPlatesThreat.db.profile.verbose then
		TP.Print(L["-->>|cff00ff00Tank Plates Enabled|r<<--"])
		TP.Print(L["|cff89F559Threat Plates|r: Tank switch detected, you are now in your |cff00ff00tanking|r role."])
	end
	Addon:ForceUpdate()
end

SLASH_TPTPDPS1 = "/tptpdps"
SlashCmdList["TPTPDPS"] = toggleDPS
SLASH_TPTPTANK1 = "/tptptank"
SlashCmdList["TPTPTANK"] = toggleTANK

local function TPTPTOGGLE()
	if (TidyPlatesThreat.db.profile.optionRoleDetectionAutomatic and TidyPlatesThreat.db.profile.verbose) then
		TP.Print(L["|cff89F559Threat Plates|r: Role toggle not supported because automatic role detection is enabled."])
	else
		if Addon:PlayerRoleIsTank() then
			toggleDPS()
		else
			toggleTANK()
		end
	end
end

SLASH_TPTPTOGGLE1 = "/tptptoggle"
SlashCmdList["TPTPTOGGLE"] = TPTPTOGGLE

local function TPTPOVERLAP()
	if GetCVar("nameplateMotion") == "0" then
		if InCombatLockdown() then
			TP.Print(L["We're unable to change this while in combat"])
		else
			SetCVar("nameplateMotion", 1)
			TP.Print(L["-->>Nameplate Overlapping is now |cffff0000OFF!|r<<--"])
		end
	else
		if InCombatLockdown() then
			TP.Print(L["We're unable to change this while in combat"])
		else
			SetCVar("nameplateMotion", 0)
			TP.Print(L["-->>Nameplate Overlapping is now |cff00ff00ON!|r<<--"])
		end
	end
end

SLASH_TPTPOVERLAP1 = "/tptpol"
SlashCmdList["TPTPOVERLAP"] = TPTPOVERLAP

local function TPTPVERBOSE()
	if TidyPlatesThreat.db.profile.verbose then
		TP.Print(L["-->>Threat Plates verbose is now |cffff0000OFF!|r<<-- shhh!!"])
	else
		TP.Print(L["-->>Threat Plates verbose is now |cff00ff00ON!|r<<--"], true)
	end
	TidyPlatesThreat.db.profile.verbose = not TidyPlatesThreat.db.profile.verbose
end

SLASH_TPTPVERBOSE1 = "/tptpverbose"
SlashCmdList["TPTPVERBOSE"] = TPTPVERBOSE

--local function PrintHelp()
--	t.Print(L["Usage: /tptp [options]"], true)
--	t.Print(L["options:"], true)
----	t.Print(L["  update-profiles    Migrates deprecated settings in your configuration"], true)
--	t.Print(L["  help               Prints this help message"], true)
--	t.Print(L["  <no option>        Displays options dialog"], true)
--end

-- Command: /tptp
function TidyPlatesThreat:ChatCommand(input)
	TidyPlatesThreat:OpenOptions()
end

--local function SearchDBForString(db, prefix, keyword)
--  for key, value in pairs(db) do
--    local search_text = prefix .. "." .. key
--    if type(value) == "table" then
--      SearchDBForString(db[key], search_text, keyword )
--    else
--      if string.match(string.lower(search_text), keyword) then
--        print (search_text, "=", value)
--      end
--    end
--  end
--end

--function TidyPlatesThreat:ChatCommand(input)
--	local cmd_list = {}
--	for w in input:gmatch("%S+") do cmd_list[#cmd_list + 1] = w end
--
--	local command = cmd_list[1]
--	if not command or command == "" then
--		TidyPlatesThreat:OpenOptions()
--	elseif command == "test" then
--		local plate = C_NamePlate.GetNamePlateForUnit("target")
--		if not plate then return end
--		local unit = plate.TPFrame.unit
--
--		local status = UnitThreatSituation("player", "target")
--		print ("Threat: ", status)
--
--		local isTanking, status, threatpct, rawthreatpct, threatvalue = UnitDetailedThreatSituation("player", "target")
--		print ("Detailed Threat: ", isTanking, status, threatpct, rawthreatpct, threatvalue)
--
--		-- Unit is in combat and attacking the player (if unit has not threat list, this is the only way to determine if unit is attacking player)
--		-- Maybe even: UnitIsUnit("playertarget", "target)
--		local is_attacking = UnitAffectingCombat("target") and (UnitIsUnit("targettarget", "player") or UnitIsUnit("targettarget", "vehicle") or UnitIsUnit("targettarget", "pet"))
--	  print ("Attacking:", is_attacking)
--
--		-- party, partypet, raid, raidpet, arena
----		local party_member = Unit("targettarget", "party")
----		print ("Attacking:", is_attacking)
--
--
--		TP.DEBUG_PRINT_UNIT(unit, true)
--  elseif command == "heuristic" then
--    local plate = C_NamePlate.GetNamePlateForUnit("target")
--    if not plate then return end
--    local unit = plate.TPFrame.unit
--
----    print ("Use Threat Table:", TidyPlatesThreat.db.profile.threat.UseThreatTable)
----    print ("Use Heuristic in Instances:", TidyPlatesThreat.db.profile.threat.UseHeuristicInInstances)
--
--    print ("InCombat:", InCombatLockdown())
--
--    --Addon:ShowThreatFeedback(unit,true)
--    --Addon:GetThreatColor(unit, unit.style, TidyPlatesThreat.db.profile.threat.UseThreatTable, true)
--    Addon:SetThreatColor(unit, true)
--  elseif command == "quest" then
--		Addon:PrintQuests()
--	elseif command == "tank" then
--		print ("GUID:", UnitGUID("target"))
--
--		local unit_type, _,  _, _, _, npc_id, _ = strsplit("-", UnitGUID("target"))
--		print ("  =>:", unit_type, npc_id)
--	elseif command == "migrate" then
--		Addon.MigrateDatabase(cmd_list[2])
----	elseif command == "help" then
----		--PrintHelp()
----	else
----		TP.Print(L["Unknown option: "] .. input, true)
----		PrintHelp()
--	elseif command == "db" then
--		print ("Searching settings:")
--		SearchDBForString(TidyPlatesThreat.db.profile, "<Profile>", string.lower(cmd_list[2]))
--	end
--end

-----------------------------------------------------
-- External
-----------------------------------------------------