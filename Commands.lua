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
		elseif UnitExists("mouseover") then
			Addon.Debug.PrintUnit("mouseover")
		end
	elseif command == "cache" then
		Addon.Debug.PrintCaches()
	elseif command == "debug" then
		local component_name = cmd_list[2]
		if not component_name then return end

		Addon.Logging.Debug(component_name .. ":")
		local widget = Addon.Widgets.Widgets[component_name]
		if widget then 
			widget:PrintDebug(cmd_list[3])
		elseif component_name == "WidgetHandler" then
			Addon:DebugWidgetHandler()
		elseif component_name == "Compatibility" then
			Addon:DebugCompatibility()
		elseif component_name == "EventService" then
			Addon:PrintEventService()
		elseif component_name == "Color" then 
			Addon.Color.PrintDebug()
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
	elseif command == "version" then
		Addon.Logging.Debug("Expansion Level:", Addon.GetExpansionLevel())
		if Addon.IS_CLASSIC then
			if Addon.IS_CLASSIC_SOD then
				Addon.Logging.Debug("Version: Classic Era - Season of Discovery")
			elseif C_Seasons and (C_Seasons.GetActiveSeason() == 11 or C_Seasons.GetActiveSeason() == 12) then
				Addon.Logging.Debug("Version: Classic Era - Anniversary Realm")
			else
				Addon.Logging.Debug("Version: Classic Era")
			end
		end
		if Addon.IS_TBC_CLASSIC then
			if C_Seasons and (C_Seasons.GetActiveSeason() == 125) then
				Addon.Logging.Debug("Version: TBC Classic - Anniversary Edition")
			else
				Addon.Logging.Debug("Version: TBC Classic")
			end
		end
		if Addon.IS_MISTS_CLASSIC then
			Addon.Logging.Debug("Version: Mists Classic")
		end
		if Addon.IS_MIDNIGHT then
			Addon.Logging.Debug("Version: Midnight")
		end
		if Addon.IS_MAINLINE then
			Addon.Logging.Debug("Version: Mainline")
		end

		Addon.Logging.Debug("-- Enabled Features --")
		Addon.Logging.Debug("  WOW_USES_CLASSIC_NAMEPLATES:", Addon.WOW_USES_CLASSIC_NAMEPLATES)
		Addon.Logging.Debug("  WOW_FEATURE_ABSORBS:", Addon.WOW_FEATURE_ABSORBS)
		Addon.Logging.Debug("  WOW_FEATURE_BLIZZARD_AURA_FILTER:", Addon.WOW_FEATURE_BLIZZARD_AURA_FILTER)
		Addon.Logging.Debug("  NAMEPLATE_MAX_DISTANCE_MAX_VALUE:", Addon.NAMEPLATE_MAX_DISTANCE_MAX_VALUE[Addon.GetExpansionLevel()])
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
	elseif command == "test" then
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    if not plate then return end

		print("SetSize")
	  plate.UnitFrame.healthBar:SetSize(300, 80)
		plate.UnitFrame:SetSize(300, 80)
	elseif command == "restrictions" then
		local cvar_type = cmd_list[2]
		local all = {
			"secretCombatRestrictionsForced",
			"secretEncounterRestrictionsForced",
			"secretChallengeModeRestrictionsForced",
			"secretPvPMatchRestrictionsForced",
			"secretMapRestrictionsForced",
		}

		-- If we're in combat, bail out once before making any changes
		if InCombatLockdown() then
			Addon.Logging.Warning(L["We're unable to change this while in combat"])
			return
		end

		-- If no type specified, set all CVars to false
		if not cvar_type then
			for _, name in ipairs(all) do
				SetCVar(name, 0)
			end
			Addon.Logging.Info(L["All restriction CVars are now |cffff0000OFF!|r"]) 
			return
		end

		local map_type = {
			combat = "secretCombatRestrictionsForced",
			encounter = "secretEncounterRestrictionsForced",
			challenge = "secretChallengeModeRestrictionsForced",
			pvp = "secretPvPMatchRestrictionsForced",
			map = "secretMapRestrictionsForced",
		}
		local target_cvar = map_type[string.lower(cvar_type)]
		if not target_cvar then
			Addon.Logging.Error(L["Unknown restrictions type: "] .. (cvar_type or ""))
			Addon.Logging.Print(L["Valid types: combat, encounter, challenge, pvp, map"]) 
			return
		end

		local selected_on = GetCVar(target_cvar) == "1"

		for _, name in ipairs(all) do
			SetCVar(name, (name == target_cvar and not selected_on) and 1 or 0)
		end

		if selected_on then
			Addon.Logging.Info(L["All restriction CVars are now |cffff0000OFF!|r"]) 
		else
			Addon.Logging.Info(L["Set restriction: "] .. cvar_type)
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
	elseif command == "clickable-area" then
		for unitid, plate in pairs(C_NamePlate.GetNamePlates()) do				
			if not plate._TPBackground then				
				plate._TPBackground = _G.CreateFrame("Frame", nil, plate, Addon.BackdropTemplate)
				plate._TPBackground:SetBackdrop({
					bgFile = Addon.PATH_ARTWORK .. "TP_WhiteSquare.tga",
					edgeFile = Addon.PATH_ARTWORK .. "TP_WhiteSquare.tga",
					edgeSize = 2,
					insets = { left = 0, right = 0, top = 0, bottom = 0 },
				})
				plate._TPBackground:SetBackdropColor(0,0,0,.3)
				plate._TPBackground:SetBackdropBorderColor(0, 0, 0, 0.8)
			end
				
			plate._TPBackground:ClearAllPoints()
			plate._TPBackground:SetParent(plate)
			plate._TPBackground:SetAllPoints(plate.UnitFrame)
			plate._TPBackground:Show()
		end	
	
	elseif Addon.DEBUG then
		ChatCommandDebug(cmd_list)
	else
		Addon.Logging.Error(L["Unknown option: "] .. command)
		PrintHelp()
	end
end