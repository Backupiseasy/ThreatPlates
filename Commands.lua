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
	elseif command == "unit" then
		Addon.Debug.PrintUnit("target")
	elseif command == "unit-mouseover" then
		Addon.Debug.PrintUnit("mouseover")
	elseif command == "cache" then
		Addon.Debug.PrintCaches()
	elseif command == "debug" then
		local widget_name = cmd_list[2]
		if widget_name then
			local widget = Addon.Widgets.Widgets[widget_name]
			if widget then 
				widget:PrintDebug(cmd_list[3])
			end
		end
	elseif command == "custom-styles" then
		for k, v in pairs(Addon.db.profile.uniqueSettings) do
			Addon.Logging.Debug("Style:", k, "=>", v.Trigger.Type, " - ", v.Trigger[v.Trigger.Type].Input or "nil" )
		end
	elseif command == "guid" then
		local plate = C_NamePlate.GetNamePlateForUnit("target")
		if not plate then return end

		local guid = UnitGUID(plate.TPFrame.unit.unitid)
		local _, _,  _, _, _, npc_id = strsplit("-", guid)

		Addon.Logging.Debug(plate.TPFrame.unit.name, " => NPC-ID:", npc_id, "=>", guid)
	-- elseif command == "event" then
	-- 	Addon.Logging.Info("|cff89F559Threat Plates|r: Event publishing overview:")
	-- 	Addon:PrintEventService()
	elseif command == "cleanup-custom-styles" then
		local input = Addon.db.profile.uniqueSettings
		for i = #input, 1 , -1 do
			local custom_style = input[i]
			Addon.Logging.Debug(i, type(i), custom_style.Trigger.Type, custom_style.Trigger.Name.Input)
			if custom_style.Trigger.Type == "Name" and custom_style.Trigger.Name.Input == "<Enter name here>" then
				table.remove(input, i)
				Addon.Logging.Debug("Removing", i)
			end
		end
	elseif command == "cata" then
		print("Addon.ExpansionIsAtLeast()",  Addon.ExpansionIsAtLeast())
		print("Addon.WOW_USES_CLASSIC_NAMEPLATES:", Addon.WOW_USES_CLASSIC_NAMEPLATES)
		print("Addon.ExpansionIsAtLeast(LE_EXPANSION_BURNING_CRUSADE):", Addon.ExpansionIsAtLeast(LE_EXPANSION_BURNING_CRUSADE))
		print("Addon.ExpansionIsAtLeast(LE_EXPANSION_WRATH_OF_THE_LICH_KING):", Addon.ExpansionIsAtLeast(LE_EXPANSION_WRATH_OF_THE_LICH_KING))
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