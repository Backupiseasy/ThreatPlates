local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local L = Addon.L

Addon.DEBUG = Addon.Meta("version") == "@project-version@"

local function toggleDPS()
  if Addon.db.profile.optionRoleDetectionAutomatic then
    Addon.Logging.Warning(L["Role toggle not supported because automatic role detection is enabled."])
  else
    Addon.db.char.spec[GetSpecialization()] = false
		Addon.Logging.Info(L["|cffff0000DPS Plates Enabled|r"])
		Addon.Logging.Info(L["DPS switch detected, you are now in your |cffff0000dpsing / healing|r role."])
    Addon:ForceUpdate()
  end
end

local function toggleTANK()
  if Addon.db.profile.optionRoleDetectionAutomatic then
    Addon.Logging.Warning(L["Role toggle not supported because automatic role detection is enabled."])
  else
    Addon.db.char.spec[GetSpecialization()] = true
		Addon.Logging.Info(L["cff00ff00Tank Plates Enabled|r"])
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
		if Addon.GetPlayerRole() == "tank" then
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
			Addon.Logging.Info(L["Nameplate Overlapping is now |cffff0000OFF!|r"])
		end
	else
		if InCombatLockdown() then
			Addon.Logging.Warning(L["We're unable to change this while in combat"])
		else
			SetCVar("nameplateMotion", 0)
			Addon.Logging.Info(L["Nameplate Overlapping is now |cff00ff00ON!|r"])
		end
	end
end

SLASH_TPTPOVERLAP1 = "/tptpol"
SlashCmdList["TPTPOVERLAP"] = TPTPOVERLAP

local function TPTPVERBOSE()
	if Addon.db.profile.verbose then
		Addon.Logging.Print(L["Threat Plates verbose is now |cffff0000OFF!|r"])
	else
		Addon.Logging.Print(L["Threat Plates verbose is now |cff00ff00ON!|r"])
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
		if UnitExists("target") then
			Addon.Debug.PrintUnit("target")
		else
			Addon.Debug.PrintUnit("mouseover")
		end
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
	elseif command == "combat" and Addon.DEBUG then
		--Addon.Logging.Info("|cff89F559Threat Plates|r: Event publishing overview:")
		if not plate then return end

		print ("In Combat:", IsInCombat())
		print ("In Combat with Player:", UnitAffectingCombat("target", "player"))
	elseif command == "alpha" then
		local plate = C_NamePlate.GetNamePlateForUnit("mouseover")
		if not plate then return end

		local tp_frame = plate.TPFrame
		local unit = tp_frame.unit

		print("Plate:")
		print("    Alpha:", plate:GetAlpha())
		print("    Scale:", plate:GetScale())
		print("Threat Plate:")
		print("    Alpha:", tp_frame:GetAlpha())
		print("    Scale:", tp_frame:GetScale())
		print("    CurrentAlpha:", tp_frame.CurrentAlpha)
		print("    Hiding Scale:", tp_frame.HidingScale)
		print("    IsShowing:", tp_frame.IsShowing)
	elseif command == "debug" then
		local plate = C_NamePlate.GetNamePlateForUnit("target")
		if not plate then return end

		local tp_frame = plate.TPFrame
		local unit = tp_frame.unit
		local stylename = tp_frame.stylename
		local nameplate_style = ((stylename == "NameOnly" or stylename == "NameOnly-Unique") and "NameMode") or "HealthbarMode"

		print ("Unit Name:", unit.name)
		print ("Unit Reaction:", unit.reaction)
		print ("Frame Style:", stylename)
		print ("Plate Style:", nameplate_style)
		print ("Color Statusbar:", Addon.Debug:ColorToString(tp_frame.visual.Healthbar:GetStatusBarColor()))
		print ("Color Border:", Addon.Debug:ColorToString(tp_frame.visual.Healthbar.Border:GetBackdropColor()))
	elseif command == "plate" then
		local plate = C_NamePlate.GetNamePlateForUnit("target")
		if not plate then return end

		local tp_frame = plate.TPFrame
		local unit = tp_frame.unit

		local stylename = "dps"
		local style = Addon.Theme[stylename]

		local NAMEPLATE_STYLES_BY_THEME = {
			dps = "HealthbarMode",
			tank = "HealthbarMode",
			normal = "HealthbarMode",
			totem = "HealthbarMode",
			unique = "HealthbarMode",
			empty = "None",
			etotem = "None",
			NameOnly = "NameMode",
			["NameOnly-Unique"] = "NameMode",
		}

		tp_frame.PlateStyle = NAMEPLATE_STYLES_BY_THEME[stylename]
		tp_frame.stylename = stylename
		tp_frame.style = style
		unit.style = stylename

		Addon.Elements.GetElement("Healthbar").UpdateStyle(tp_frame, style)
	elseif command == "color" then
		local plate = C_NamePlate.GetNamePlateForUnit("target")
		if not plate then return end
		local unit = plate.TPFrame.unit

		local beginTime = debugprofilestop()
		for i = 1, 100 do
			--
			unit.health = i
			unit.healthmax = 100
			Addon.TestColorByHealth(unit)
			--
		end
		local timeUsed = debugprofilestop()  -beginTime
		print("Ohne Cache: "..timeUsed)

		-- Fill cache
		for i = 1, 100 do
			unit.health = i
			unit.healthmax = 100
			Addon.TestColorByHealthCache(unit)
		end

		local beginTime = debugprofilestop()
		for i = 1, 100 do
			--
			unit.health = i
			unit.healthmax = 100
			Addon.TestColorByHealthCache(unit)
			--
		end
		local timeUsed = debugprofilestop()  -beginTime
		print("Mit Cache: "..timeUsed)
	elseif command == "perf" then

		local plate = C_NamePlate.GetNamePlateForUnit("target")
		if not plate then return end
		local unit = plate.TPFrame.unit
		local unitid = unit.unitid

		local beginTime = debugprofilestop()
		for i = 1, 1000 do
			--
			Addon.TestColorNormal(plate.TPFrame)
			--
		end
		local timeUsed = debugprofilestop()  -beginTime
		print("Normal: "..timeUsed)

		local beginTime = debugprofilestop()
		for i = 1, 1000 do
			--
			Addon.TestColorNormalOpt(plate.TPFrame)
			--
		end
		local timeUsed = debugprofilestop()  -beginTime
		print("Opt : "..timeUsed)
	elseif command == "heuristic" then
		local plate = C_NamePlate.GetNamePlateForUnit("target")
		if not plate then return end
		local unit = plate.TPFrame.unit

		Addon.GetColorByThreat(unit, unit.style, true)

		--print (unit.name, "- InCombatThreat =", unit.InCombatThreat)

		--    print ("Use Threat Table:", Addon.db.profile.threat.UseThreatTable)
		--    print ("Use Heuristic in Instances:", Addon.db.profile.threat.UseHeuristicInInstances)

		--print ("InCombat:", InCombatLockdown())
	elseif command == "version" then
		--		local unique_unit = Addon.CopyTable(Addon.db.profile.uniqueSettings[1])
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
		if not Addon.IS_CLASSIC and not Addon.IS_TBC_CLASSIC and not Addon.IS_WRATH_CLASSIC then
			print("    UnitSelectionType = ", UnitSelectionType("target"))
		end
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
	elseif command == "wow-version" then
		local wowVersionString, wowBuild, _, wowTOC = GetBuildInfo()

		print("WOW_PROJECT_ID:", WOW_PROJECT_ID)
		print("LE_EXPANSION_LEVEL_CURRENT:", LE_EXPANSION_LEVEL_CURRENT)
		print("GetClassicExpansionLevel():", GetClassicExpansionLevel and GetClassicExpansionLevel() or nil)		
		print("TOC Version:", wowTOC)		
		print("Addon --------")		
		print("    IS_CLASSIC:", Addon.IS_CLASSIC)		
		print("    IS_TBC_CLASSIC:", Addon.IS_TBC_CLASSIC)		
		print("    IS_WRATH_CLASSIC:", Addon.IS_WRATH_CLASSIC)		
		print("    IS_MAINLINE:", Addon.IS_MAINLINE)
	elseif command == "test" then
		print("")
	elseif command == "threat" then
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    if not plate then return end
    local unit = plate.TPFrame.unit

		Addon.Logging.Info("    Player:", UnitDetailedThreatSituation("player", unit.unitid))
    Addon.Logging.Info("    Pet:", UnitDetailedThreatSituation("pet", unit.unitid))
    Addon.Logging.Info("    Combat State:", _G.UnitAffectingCombat("player"), "-", _G.UnitAffectingCombat("pet"))
    Addon.Logging.Info("    ThreatLevel:", unit.ThreatLevel)
    Addon.Logging.Info("    InCombat:", unit.InCombat)
    Addon.Logging.Info("    Threat.ShowFeedback:", Addon.Threat.ShowFeedback(unit))
    Addon.Logging.Info("    Style:GetThreatStyle:", Addon.Style:GetThreatStyle(unit))
		local color = Addon.Color.GetThreatColor(unit, Addon.Style:GetThreatStyle(unit))
		if color then
			Addon.Logging.Info("    GetThreatColor:", color.r, color.g, color.b)
		end
	elseif command == "role" then
		local spec_roles = Addon.db.char.spec
		for i, is_tank in pairs(spec_roles) do
			print (i, "=", is_tank)
		end

		local spec_roles = self.db.char.spec
		if #spec_roles + 1 ~= GetNumSpecializations() then
			for i = 1, GetNumSpecializations() do
				local is_tank = spec_roles[i]
				if is_tank == nil then
					local id, spec_name, _, _, role = GetSpecializationInfo(i)
					local role = (role == "TANK" and true) or false
					spec_roles[i] = role
					print ("Role", i, " => ", is_tank, " to ", role)
				else
					print ("Role", i, " => ", is_tank)
				end
			end
		end
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