local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local L = Addon.ThreatPlates.L

Addon.DEBUG = Addon.ThreatPlates.Meta("version") == "@project-version@"

local function toggleDPS()
	if Addon.db.profile.optionRoleDetectionAutomatic then
		Addon.Logging.Warning(L["Role toggle not supported because automatic role detection is enabled."])
	else
		Addon:SetRole(false)
		Addon.db.profile.threat.ON = true
		Addon.Logging.Info(L["-->>|cffff0000DPS Plates Enabled|r<<--"])
		Addon.Logging.Info(L["DPS switch detected, you are now in your |cffff0000dpsing / healing|r role."])
		Addon:ForceUpdate()
	end
end

local function toggleTANK()
	if Addon.db.profile.optionRoleDetectionAutomatic then
		Addon.Logging.Warning(L["Role toggle not supported because automatic role detection is enabled."])
	else
		Addon:SetRole(true)
		Addon.db.profile.threat.ON = true
		Addon.Logging.Info(L["-->>|cff00ff00Tank Plates Enabled|r<<--"])
		Addon.Logging.Info(L["Tank switch detected, you are now in your |cff00ff00tanking|r role."])
		Addon:ForceUpdate()
	end
end

SLASH_TPTPDPS1 = "/tptpdps"
SlashCmdList["TPTPDPS"] = toggleDPS
SLASH_TPTPTANK1 = "/tptptank"
SlashCmdList["TPTPTANK"] = toggleTANK

local function TPTPTOGGLE()
	if Addon.db.profile.optionRoleDetectionAutomatic then
		Addon.Logging.Warning(L["Role toggle not supported because automatic role detection is enabled."])
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
			Addon.Logging.Warning(L["We're unable to change this while in combat"])
		else
			SetCVar("nameplateMotion", 1)
			Addon.Logging.Info(L["-->>Nameplate Overlapping is now |cffff0000OFF!|r<<--"])
		end
	else
		if InCombatLockdown() then
			Addon.Logging.Warning(L["We're unable to change this while in combat"])
		else
			SetCVar("nameplateMotion", 0)
			Addon.Logging.Info(L["-->>Nameplate Overlapping is now |cff00ff00ON!|r<<--"])
		end
	end
end

SLASH_TPTPOVERLAP1 = "/tptpol"
SlashCmdList["TPTPOVERLAP"] = TPTPOVERLAP

local function TPTPVERBOSE()
	if Addon.db.profile.verbose then
		Addon.Logging.Print(L["-->>Threat Plates verbose is now |cffff0000OFF!|r<<-- shhh!!"])
	else
		Addon.Logging.Print(L["-->>Threat Plates verbose is now |cff00ff00ON!|r<<--"])
	end
	Addon.db.profile.verbose = not Addon.db.profile.verbose
end

SLASH_TPTPVERBOSE1 = "/tptpverbose"
SlashCmdList["TPTPVERBOSE"] = TPTPVERBOSE

local function PrintHelp()
	Addon.Logging.Print(L["Usage: /tptp [options]"])
	Addon.Logging.Print(L["options:"])
	Addon.Logging.Print(L["  profile <name>          Switch the current profile to <name>"])
	Addon.Logging.Print(L["  legacy-custom-styles    Adds (legacy) default custom styles for nameplates that are deleted when migrating custom nameplates to the current format"])
	Addon.Logging.Print(L["  toggle-scripting        Enable or disable scripting support (for beta testing)"])
	Addon.Logging.Print(L["  help                    Prints this help message"])
	Addon.Logging.Print(L["  <no option>             Displays options dialog"])
	Addon.Logging.Print(L["Additional chat commands:"])
	Addon.Logging.Print(L["  /tptpverbose   Toggles addon feedback text"])
	Addon.Logging.Print(L["  /tptptoggle    Toggle Role from one to the other"])
	Addon.Logging.Print(L["  /tptpdps       Toggles DPS/Healing threat plates"])
	Addon.Logging.Print(L["  /tptptank      Toggles Tank threat plates"])
	Addon.Logging.Print(L["  /tptpol        Toggles nameplate overlapping"])
end

local function SearchDBForString(db, prefix, keyword)
	for key, value in pairs(db) do
		local search_text = prefix .. "." .. key
		if type(value) == "table" then
			SearchDBForString(db[key], search_text, keyword )
		else
			if string.match(string.lower(search_text), keyword) then
				Addon.Logging.Print(search_text, "=", value)
			end
		end
	end
end

local function ChatCommandDebug(cmd_list)
	local command = cmd_list[1]

	if command == "searchdb" then
		Addon.Logging.Print("|cff89F559Threat Plates|r: Searching settings:")
		SearchDBForString(Addon.db.profile, "<Profile>", string.lower(cmd_list[2]))
		SearchDBForString(Addon.db.global, "<Profile>", string.lower(cmd_list[2]))
	elseif command == "cache" then
		Addon.Debug.PrintCaches()
	elseif command == "unit" then
		Addon.Debug.PrintUnit("target")
		--elseif command == "migrate" then
		--	Addon.TestMigration()
		--	Addon.MigrateDatabase(TP.Meta("version"))
	elseif command == "print-custom-styles" then
		Addon.Debug.PrintTable(Addon.db.profile.uniqueSettings)
		--Addon.MigrateDatabase(TP.Meta("version"))
	elseif command == "migrate" then
		Addon.TestMigrateDatabase("MigrateFixAurasCyclicAnchoring")
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
		--Addon.Logging.Info("|cff89F559Threat Plates|r: Event publishing overview:")
		--Addon:PrintEventService()
	elseif command == "quest" then
		Addon:PrintQuests(cmd_list[2])
	elseif command == "social" then
		Addon.PrintFriendlist()
	elseif command == "custom-styles" then
		for k, v in pairs(Addon.db.profile.uniqueSettings) do
			print ("Style:", k, "=>", v.Trigger.Type, " - ", v.Trigger[v.Trigger.Type].Input or "nil" )
		end
	elseif command == "cleanup-custom-styles" then
		local input = Addon.db.profile.uniqueSettings
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
		Addon.Debug.PrintTable(imported_custom_style)

	elseif command == "heuristic" then
		local plate = C_NamePlate.GetNamePlateForUnit("target")
		if not plate then return end
		local unit = plate.TPFrame.unit

		Addon.GetColorByThreat(unit, unit.style, true)

		--print (unit.name, "- InCombatThreat =", unit.InCombatThreat)

		--    print ("Use Threat Table:", Addon.db.profile.threat.UseThreatTable)
		--    print ("Use Heuristic in Instances:", Addon.db.profile.threat.UseHeuristicInInstances)

		--print ("InCombat:", InCombatLockdown())

		--Addon:ShowThreatFeedback(unit,true)
		--Addon:GetThreatColor(unit, unit.style, Addon.db.profile.threat.UseThreatTable, true)
		--Addon:SetThreatColor(unit, true)
	elseif command == "version" then
		--		local unique_unit = TP.CopyTable(Addon.db.profile.uniqueSettings[1])
		--		unique_unit.UseAutomaticIcon = nil
		--		print (Addon.CheckTableStructure(TP.DEFAULT_SETTINGS.profile.uniqueSettings["**"], unique_unit))
		print ("10.2.11 < 10.3.0:", Addon.CurrentVersionIsOlderThan("10.2.11", "10.3.0"))
		print ("10.2.11 < 10.3.0-beta2:", Addon.CurrentVersionIsOlderThan("10.2.11", "10.3.0-beta2"))
		print ("10.3.0-beta2 < 9.3.0:", Addon.CurrentVersionIsOlderThan("10.3.0-beta2", "10.3.0"))
		print ("10.3.0-beta2 < 10.3.0-beta3:", Addon.CurrentVersionIsOlderThan("10.3.0-beta2", "10.3.0-beta3"))
	elseif command == "reaction" then
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    if not plate then return end
    local unit = plate.TPFrame.unit

		print("Name:", unit.name)
		print("  Reaction:", unit.reaction)
		print("    UnitReaction:", UnitReaction("target", "player"))
    print("    UnitCanAttack = ", UnitCanAttack("target", "player"))
    print("    UnitIsFriend = ", UnitIsFriend("target", "player"))
		print("    UnitSelectionColor = ", UnitSelectionColor("target"))
		print("    UnitIsPVP = ", UnitIsPVP("target"))
		if not Addon.IS_TBC_CLASSIC and not Addon.IS_CLASSIC then
			print("    UnitSelectionType = ", UnitSelectionType("target"))
		end
		elseif command == "dbm1" then
		DBM.Nameplate:Show(true, UnitGUID("target"), 255824, nil, nil, nil, true, {0.5, 0, 0.55, 0.75})
	elseif command == "dbm2" then
		DBM.Nameplate:Hide(true, UnitGUID("target"), 255824, nil, nil, nil, true, {0.5, 0, 0.55, 0.75})
	elseif command == "valid" then
		print ("Plates Created:")
		for plate, tp_frame in pairs(Addon.PlatesCreated) do
			print (tp_frame.unit and tp_frame.unit.name or "<Undefined>", "=> Active:", tp_frame.Active, "- Shown:", tp_frame:IsShown(), tp_frame.visual.healthbar:IsShown(), tp_frame.visual.customtext:IsShown())
			if not (tp_frame.unit and tp_frame.unit.name) then
				if plate == C_NamePlate.GetNamePlateForUnit("player") then
					print ("  =>Player")
				end
			end
		end
	elseif command == "test" then
		print("34.345345345", Addon.Truncate(34.345345345))
		print("-34.345345345", Addon.Truncate(-34.345345345))
		print("-99", Addon.Truncate(-99))
		print("9999.809986", Addon.Truncate(9999.809986))
		print("-15554", Addon.Truncate(-15554))
	else
		Addon.Logging.Error(L["Unknown option: "] .. command)
		PrintHelp()
	end
end

-- Command: /tptp
function TidyPlatesThreat:ChatCommand(input)
	local cmd_list = Addon.SplitByWhitespace(input)

	local command = cmd_list[1]
	if not command or command == "" then
		Addon:OpenOptions()
	elseif command == "help" then
		PrintHelp()
	elseif command == "legacy-custom-styles" then
		Addon.RestoreLegacyCustomNameplates()
	elseif command == "profile" then
		local profile_name = cmd_list[2]
		if profile_name and profile_name ~= "" then
			-- Check if profile exists
			if Addon.db.profiles[profile_name] then
				Addon.db:SetProfile(profile_name)
			else
				Addon.Logging.Error(L["|cff89F559Threat Plates|r: Unknown profile: "] .. profile_name)
			end
		else
			Addon.Logging.Error(L["|cff89F559Threat Plates|r: No profile specified"])
		end
	elseif command == "toggle-scripting" then
		Addon.db.global.ScriptingIsEnabled = not Addon.db.global.ScriptingIsEnabled
		if Addon.db.global.ScriptingIsEnabled then
			Addon.Logging.Info(L["Scriping for custom styles for nameplates is now |cff00ff00enabled!|r."])
		else
			Addon.Logging.Info(L["Scriping for custom styles for nameplates is now |cffff0000disabled!|r."])
		end
		Addon.UpdateCustomStyles()
		TidyPlatesThreat:ConfigTableChanged()
--	elseif command == "toggle-view-friendly-units" then
--		TidyPlatesThreat:ToggleNameplateModeFriendlyUnits()
--	elseif command == "toggle-view-neutral-units" then
--		TidyPlatesThreat:ToggleNameplateModeNeutralUnits()
--	elseif command == "toggle-view-enemy-units" then
--		TidyPlatesThreat:ToggleNameplateModeEnemyUnits()
	elseif Addon.DEBUG then
		ChatCommandDebug(cmd_list)
	else
		Addon.Logging.Error(L["Unknown option: "] .. command)
		PrintHelp()
	end
end

-----------------------------------------------------
-- External
-----------------------------------------------------