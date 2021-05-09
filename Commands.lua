local ADDON_NAME, Addon = ...
local TP = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local L = TP.L

local DEBUG = TP.Meta("version"):find("Alpha") or TP.Meta("version"):find("Beta")

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

local function PrintHelp()
	TP.Print(L["Usage: /tptp [options]"], true)
	TP.Print(L["options:"], true)
	TP.Print(L["  profile <name>          Switch the current profile to <name>"], true)
	TP.Print(L["  legacy-custom-styles    Adds (legacy) default custom styles for nameplates that are deleted when migrating custom nameplates to the current format"], true)
	TP.Print(L["  toggle-scripting        Enable or disable scripting support (for beta testing)"], true)
	TP.Print(L["  help                    Prints this help message"], true)
	TP.Print(L["  <no option>             Displays options dialog"], true)
	TP.Print(L["Additional chat commands:"], true)
	TP.Print(L["  /tptpverbose   Toggles addon feedback text"], true)
	TP.Print(L["  /tptptoggle    Toggle Role from one to the other"], true)
	TP.Print(L["  /tptpdps       Toggles DPS/Healing threat plates"], true)
	TP.Print(L["  /tptptank      Toggles Tank threat plates"], true)
	TP.Print(L["  /tptpol        Toggles nameplate overlapping"], true)
end

local function SearchDBForString(db, prefix, keyword)
	for key, value in pairs(db) do
		local search_text = prefix .. "." .. key
		if type(value) == "table" then
			SearchDBForString(db[key], search_text, keyword )
		else
			if string.match(string.lower(search_text), keyword) then
				print (search_text, "=", value)
			end
		end
	end
end

-- Command: /tptp
function TidyPlatesThreat:ChatCommand(input)
	local cmd_list = {}
	for w in input:gmatch("%S+") do cmd_list[#cmd_list + 1] = w end

	local command = cmd_list[1]
	if not command or command == "" then
		TidyPlatesThreat:OpenOptions()
	elseif command == "help" then
		PrintHelp()
	elseif command == "legacy-custom-styles" then
		Addon.RestoreLegacyCustomNameplates()
	elseif command == "profile" then
		local profile_name = cmd_list[2]
		if profile_name and profile_name ~= "" then
			-- Check if profile exists
			if TidyPlatesThreat.db.profiles[profile_name] then
				TidyPlatesThreat.db:SetProfile(profile_name)
			else
				TP.Print(L["|cff89F559Threat Plates|r: Unknown profile: "] .. profile_name, true)
			end
		else
			TP.Print(L["|cff89F559Threat Plates|r: No profile specified"], true)
		end
	elseif input == "toggle-scripting" then
		TidyPlatesThreat.db.global.ScriptingIsEnabled = not TidyPlatesThreat.db.global.ScriptingIsEnabled
		if TidyPlatesThreat.db.global.ScriptingIsEnabled then
			TP.Print(L["Scriping for custom styles for nameplates is now |cff00ff00enabled!|r."])
		else
			TP.Print(L["Scriping for custom styles for nameplates is now |cffff0000disabled!|r."])
		end
		Addon.UpdateCustomStyles()
		TidyPlatesThreat:ConfigTableChanged()
--	elseif command == "toggle-view-friendly-units" then
--		TidyPlatesThreat:ToggleNameplateModeFriendlyUnits()
--	elseif command == "toggle-view-neutral-units" then
--		TidyPlatesThreat:ToggleNameplateModeNeutralUnits()
--	elseif command == "toggle-view-enemy-units" then
--		TidyPlatesThreat:ToggleNameplateModeEnemyUnits()
	elseif DEBUG then
		TidyPlatesThreat:ChatCommandDebug(cmd_list)
	else
		TP.Print(L["Unknown option: "] .. input, true)
		PrintHelp()
	end
end

function TidyPlatesThreat:ChatCommandDebug(cmd_list)
	local command = cmd_list[1]

	if command == "searchdb" then
		TP.Print("|cff89F559Threat Plates|r: Searching settings:", true)
		SearchDBForString(TidyPlatesThreat.db.profile, "<Profile>", string.lower(cmd_list[2]))
		SearchDBForString(TidyPlatesThreat.db.global, "<Profile>", string.lower(cmd_list[2]))
	elseif command == "cache" then
		Addon.DebugPrintCaches()
	elseif command == "unit" then
		local plate = C_NamePlate.GetNamePlateForUnit("target")
		if not plate then return end
		TP.DEBUG_PRINT_UNIT(plate.TPFrame.unit, true)
	--elseif command == "migrate" then
	--	Addon.TestMigration()
	--	Addon.MigrateDatabase(TP.Meta("version"))
	elseif command == "print-custom-styles" then
		TP.DEBUG_PRINT_TABLE(TidyPlatesThreat.db.profile.uniqueSettings)
		--Addon.MigrateDatabase(TP.Meta("version"))
	elseif command == "guid" then
		local plate = C_NamePlate.GetNamePlateForUnit("target")
		if not plate then return end

		local guid = UnitGUID(plate.TPFrame.unit.unitid)
		local _, _,  _, _, _, npc_id = strsplit("-", guid)

		print(plate.TPFrame.unit.name, " => NPC-ID:", npc_id, "=>", guid)

		local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(C_UIWidgetManager.GetPowerBarWidgetSetID())
		for i, w in pairs(widgets) do
			print (i, w)
		end
	elseif command == "event" then
		--TP.Print("|cff89F559Threat Plates|r: Event publishing overview:", true)
		--Addon:PrintEventService()
	elseif command == "quest" then
		Addon:PrintQuests(cmd_list[2])
	elseif command == "social" then
		Addon.PrintFriendlist()
 	elseif command == "custom-styles" then
		for k, v in pairs(TidyPlatesThreat.db.profile.uniqueSettings) do
			print ("Style:", k, "=>", v.Trigger.Type, " - ", v.Trigger[v.Trigger.Type].Input or "nil" )
		end
	elseif command == "cleanup-custom-styles" then
		local input = TidyPlatesThreat.db.profile.uniqueSettings
		for i = #input, 1 , -1 do
			local custom_style = input[i]
			print (i, type(i), custom_style.Trigger.Type, custom_style.Trigger.Name.Input)
			if custom_style.Trigger.Type == "Name" and custom_style.Trigger.Name.Input == "<Enter name here>" then
				table.remove(input, i)
				print ("Removing", i)
			end
		end
	elseif command == "import" then
		local custom_style = {
			Trigger = {
				Type = "Name",
				Name = {
					Input = "Wurzebrumpf",
					AsArray = { "fsadfsd" },
				}
			},
			UseAutomaticIcon = false,
			icon = false,
			XYZ = true,
			SpellID = 234234,
		}
		local imported_custom_style = Addon.ImportCustomStyle(custom_style)
		TP.DEBUG_PRINT_TABLE(imported_custom_style)

  elseif command == "heuristic" then
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    if not plate then return end
    local unit = plate.TPFrame.unit

    Addon.GetColorByThreat(unit, unit.style, true)

		--print (unit.name, "- InCombatThreat =", unit.InCombatThreat)

		--    print ("Use Threat Table:", TidyPlatesThreat.db.profile.threat.UseThreatTable)
    --    print ("Use Heuristic in Instances:", TidyPlatesThreat.db.profile.threat.UseHeuristicInInstances)

    --print ("InCombat:", InCombatLockdown())

    --Addon:ShowThreatFeedback(unit,true)
    --Addon:GetThreatColor(unit, unit.style, TidyPlatesThreat.db.profile.threat.UseThreatTable, true)
    --Addon:SetThreatColor(unit, true)
	elseif command == "test" then
--		local unique_unit = TP.CopyTable(TidyPlatesThreat.db.profile.uniqueSettings[1])
--		unique_unit.UseAutomaticIcon = nil
--		print (Addon.CheckTableStructure(TP.DEFAULT_SETTINGS.profile.uniqueSettings["**"], unique_unit))
		print ("9.1.20 < 9.2.0-Beta1:", Addon.CurrentVersionIsOlderThan("9.1.20", "9.2.0-Beta1"))
		print ("9.2.0-Beta1 < 9.1.20:", Addon.CurrentVersionIsOlderThan("9.2.0-Beta1", "9.1.20"))
		print ("9.2.0-Beta2 < 9.2.0-Beta1:", Addon.CurrentVersionIsOlderThan("9.2.0-Beta2", "9.2.0-Beta1"))
		print ("9.2.0-Beta1 < 9.2.0-Beta2:", Addon.CurrentVersionIsOlderThan("9.2.0-Beta1", "9.2.0-Beta2"))
	elseif command == "dbm1" then
		DBM.Nameplate:Show(true, UnitGUID("target"), 255824, nil, nil, nil, true, {0.5, 0, 0.55, 0.75})
	elseif command == "dbm2" then
		DBM.Nameplate:Hide(true, UnitGUID("target"), 255824, nil, nil, nil, true, {0.5, 0, 0.55, 0.75})
	else
		TP.Print(L["Unknown option: "] .. command, true)
		PrintHelp()
	end
end

-----------------------------------------------------
-- External
-----------------------------------------------------