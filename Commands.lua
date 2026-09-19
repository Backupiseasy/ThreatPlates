local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local L = Addon.L
local GetSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or _G.GetSpecialization

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
		Addon.Logging.Info(L["|cff00ff00Tank Plates Enabled|r"])
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
end

-- Prints the exact WoW client version (GetBuildInfo) plus how Threat Plates' expansion-detection
-- systematic (Addon.IS_*/Addon.ExpansionIsAtLeast*, see Init.lua) classifies it. Meant to be pasted
-- into bug reports, so its own output always prints (not gated behind Addon.DEBUG or the verbose
-- setting) - but note the "version" command itself is only reachable via ChatCommandDebug below, which
-- IS gated behind Addon.DEBUG (only true in unpackaged/source builds, see its definition near the top of
-- this file) - so end users running a packaged release currently can't invoke it via /tptp version.
local function PrintVersion()
	local client_version, build, build_date, toc_version = GetBuildInfo()

	Addon.Logging.Print(L["|cff89F559Threat Plates|r: Version "] .. Addon.Meta("version"))
	Addon.Logging.Print("  " .. L["WoW client:"], client_version, "(" .. L["build"], build .. ", " .. L["Interface"], toc_version .. ", " .. build_date .. ")")
	Addon.Logging.Print("  " .. L["Expansion Level:"], Addon.GetExpansionLevel())

	if Addon.IS_CLASSIC then
		if Addon.IS_CLASSIC_SOD then
			Addon.Logging.Print("  " .. L["Detected as:"], "Classic Era - Season of Discovery")
		elseif Addon.IS_CLASSIC_SOM then
			Addon.Logging.Print("  " .. L["Detected as:"], "Classic Era - Season of Mastery")
		elseif C_Seasons and (C_Seasons.GetActiveSeason() == 11 or C_Seasons.GetActiveSeason() == 12) then
			Addon.Logging.Print("  " .. L["Detected as:"], "Classic Era - Anniversary Realm")
		else
			Addon.Logging.Print("  " .. L["Detected as:"], "Classic Era")
		end
	end
	if Addon.IS_TBC_CLASSIC then
		if Addon.IS_TBC_CLASSIC_ANNIVERSARY then
			Addon.Logging.Print("  " .. L["Detected as:"], "TBC Classic - Anniversary Edition")
		else
			Addon.Logging.Print("  " .. L["Detected as:"], "TBC Classic")
		end
	end
	if Addon.IS_WRATH_CLASSIC then
		Addon.Logging.Print("  " .. L["Detected as:"], "Wrath Classic")
	end
	if Addon.IS_CATA_CLASSIC then
		Addon.Logging.Print("  " .. L["Detected as:"], "Cata Classic")
	end
	if Addon.IS_MISTS_CLASSIC then
		Addon.Logging.Print("  " .. L["Detected as:"], "Mists Classic")
	end
	if Addon.IS_MIDNIGHT then
		Addon.Logging.Print("  " .. L["Detected as:"], "Midnight")
	end
	if Addon.IS_MAINLINE then
		Addon.Logging.Print("  " .. L["Detected as:"], "Mainline")
	end
	if Addon.IS_FOREVER then
		Addon.Logging.Print("  " .. L["Detected as:"], "WoW Forever (Classic-rules content on a modern client engine)")
	end

	-- Secret values (a distinct Lua type WoW returns for restricted unit data) are not tied to a single
	-- expansion flag - e.g. they also occur on Classic clients sharing Midnight's client build. Report
	-- API availability directly instead of inferring it from Addon.IS_MIDNIGHT.
	Addon.Logging.Print("  " .. L["Secret values supported:"], tostring(_G.issecretvalue ~= nil))

	-- Raw signals behind the flags above, for clients where they disagree (e.g. a custom/private-server
	-- client reporting WOW_PROJECT_ID == WOW_PROJECT_MAINLINE despite running Classic-rules content) -
	-- GetClassicExpansionLevel is only defined on some clients, hence the existence check first.
	Addon.Logging.Print("  -- " .. L["Raw signals"] .. " --")
	Addon.Logging.Print("    WOW_PROJECT_ID:", tostring(WOW_PROJECT_ID))
	Addon.Logging.Print("    WOW_PROJECT_MAINLINE:", tostring(WOW_PROJECT_MAINLINE))
	Addon.Logging.Print("    WOW_PROJECT_CLASSIC:", tostring(WOW_PROJECT_CLASSIC))
	Addon.Logging.Print("    GetClassicExpansionLevel exists:", tostring(GetClassicExpansionLevel ~= nil))
	if GetClassicExpansionLevel then
		Addon.Logging.Print("    GetClassicExpansionLevel():", tostring(GetClassicExpansionLevel()))
	end
	if GetServerExpansionLevel then
		Addon.Logging.Print("    GetServerExpansionLevel():", tostring(GetServerExpansionLevel()))
	end
end

-- Read-only existence checks only - never calls anything - so this is safe to run without side effects
-- (a game-state-changing call, e.g. CreateUnitHealPredictionCalculator(), would need a real unit context
-- to be meaningful anyway). "path" is a dot-separated lookup starting from _G, e.g. "C_Spell.GetSpellInfo".
local function ResolvePath(path)
	local value = _G
	for key in path:gmatch("[^.]+") do
		if type(value) ~= "table" then return nil end
		value = value[key]
	end
	return value
end

-- The set of Midnight-exclusive (or Midnight-introduced) APIs this addon's Midnight-only code paths
-- depend on. Grouped by the subsystem that uses them, so a missing entry points straight at the
-- Addon.ExpansionIsAtLeastMidnight branch in that file that needs a feature-detection guard instead.
local MIDNIGHT_API_CHECKS = {
	{ "Secret values", "issecretvalue" },
	{ "Healthbar - heal prediction", "CreateUnitHealPredictionCalculator" },
	{ "Healthbar - heal prediction", "UnitGetDetailedHealPrediction" },
	{ "Healthbar - heal prediction", "Enum.UnitMaximumHealthMode" },
	{ "Healthbar - heal prediction", "Enum.UnitDamageAbsorbClampMode" },
	{ "Healthbar - heal prediction", "Enum.UnitHealAbsorbClampMode" },
	{ "Healthbar - heal prediction", "Enum.UnitHealAbsorbMode" },
	{ "Healthbar - heal prediction", "Enum.UnitIncomingHealClampMode" },
	{ "StatusText - health percent/curves", "UnitHealthPercent" },
	{ "StatusText/Color - curves", "C_CurveUtil.CreateCurve" },
	{ "StatusText/Color - curves", "C_CurveUtil.CreateColorCurve" },
	{ "StatusText/Color - curves", "C_CurveUtil.EvaluateColorValueFromBoolean" },
	{ "StatusText/Color - curves", "Enum.LuaCurveType" },
	{ "Color - class color", "C_ClassColor.GetClassColor" },
	{ "Init - spell info", "C_Spell.GetSpellInfo" },
	{ "Init - solo shuffle", "C_PvP.IsSoloShuffle" },
	{ "Elements/QuestWidget - tooltip scanning", "C_TooltipInfo.GetUnit" },
	{ "QuestWidget - tooltip line types", "Enum.TooltipDataLineType" },
	{ "AurasWidget - aura API", "C_UnitAuras.GetAuraSlots" },
	{ "AurasWidget - aura API", "C_UnitAuras.GetAuraDataBySlot" },
	{ "AurasWidget - aura API", "C_UnitAuras.GetAuraDataByAuraInstanceID" },
	{ "AurasWidget - aura API", "C_UnitAuras.GetUnitAuras" },
	{ "AurasWidget - aura API", "C_UnitAuras.GetBuffDataByIndex" },
	{ "AurasWidget - aura API", "C_UnitAuras.IsAuraFilteredOutByInstanceID" },
	{ "Compatibility - server expansion", "GetServerExpansionLevel" },
	{ "Castbar - cast target/timer", "UnitSpellTargetName" },
	{ "Castbar - cast target/timer", "UnitSpellTargetClass" },
	{ "Castbar - cast target/timer", "UnitChannelDuration" },
	{ "Castbar - cast target/timer", "UnitCastingDuration" },
	{ "Castbar - cast target/timer", "WrapTextInColor" },
	{ "Castbar - cast target/timer", "GetClassColor" },
}

-- StatusBar/Frame mixin methods can't be looked up on _G - they only exist on frame instances - so they
-- need a throwaway frame to test against, same approach as PrintCompatibilityCheck below.
local MIDNIGHT_FRAME_METHOD_CHECKS = {
	{ "Healthbar/Color - alpha from secret bool", "SetAlphaFromBoolean" },
	{ "Castbar - timer duration", "SetTimerDuration" },
}

-- Unit types whose visibility Threat Plates controls via a CVar (Constants.lua, Visibility[...].Show).
local CVAR_UNIT_TYPE_CHECKS = { "FriendlyNPC", "FriendlyMinion", "FriendlyPet", "FriendlyGuardian", "FriendlyTotem" }

-- CVars that only exist on some clients; Threat Plates has to skip them if missing.
local CVAR_OPTIONAL_CHECKS = { "nameplateResourceOnTarget", "nameplateLargerScale", "nameplateGlobalScale" }

-- Reports for the CVars Threat Plates uses to show friendly units whether the client knows them (GetCVar returns nil
-- for unknown CVars). Called by PrintMidnightAPICheck.
local function PrintNameplateCVarCheck()
	local function Value(cvar)
		local ok, value = pcall(C_CVar.GetCVar, cvar)
		if not ok then return "ERROR" end
		return value == nil and "MISSING" or tostring(value)
	end

	Addon.Logging.Print("CVar check (Addon.HAS_MIDNIGHT_API = " .. tostring(Addon.HAS_MIDNIGHT_API) .. "):")
	local problem_count = 0
	for _, unit_type in ipairs(CVAR_UNIT_TYPE_CHECKS) do
		local cvar = Addon.db.profile.Visibility[unit_type].Show
		local value = type(cvar) == "string" and Value(cvar) or "MISSING"
		local exists = value ~= "MISSING" and value ~= "ERROR"
		if not exists then problem_count = problem_count + 1 end
		Addon.Logging.Print(("  %s: %s uses %s = %s"):format(exists and "OK  " or "WRONG", unit_type, tostring(cvar), value))
	end

	for _, cvar in ipairs(CVAR_OPTIONAL_CHECKS) do
		Addon.Logging.Print(("  %s = %s"):format(cvar, Value(cvar)))
	end

	Addon.Logging.Print(("CVar check done: %d unknown CVar(s)."):format(problem_count))
end

-- Checks whether this client's API surface actually has what Threat Plates' Midnight-only code paths
-- (everything gated behind Addon.ExpansionIsAtLeastMidnight) call. A client that reports itself as not
-- Midnight but still returns secret values for unit data (e.g. "WoW Forever" - see Addon.IS_FOREVER in
-- Init.lua) may or may not also have the rest of Midnight's new APIs; this settles that empirically
-- instead of guessing. Invoke with /tptp debug MidnightAPI.
local function PrintMidnightAPICheck()
	local available_count, total_count = 0, 0

	for _, check in ipairs(MIDNIGHT_API_CHECKS) do
		local subsystem, path = check[1], check[2]
		total_count = total_count + 1
		local exists = ResolvePath(path) ~= nil
		if exists then available_count = available_count + 1 end
		Addon.Logging.Print(("  %s: %s (%s)"):format(exists and "OK  " or "MISSING", path, subsystem))
	end

	local frame = CreateFrame("StatusBar")
	for _, check in ipairs(MIDNIGHT_FRAME_METHOD_CHECKS) do
		local subsystem, method = check[1], check[2]
		total_count = total_count + 1
		local exists = type(frame[method]) == "function"
		if exists then available_count = available_count + 1 end
		Addon.Logging.Print(("  %s: %s (%s)"):format(exists and "OK  " or "MISSING", method, subsystem))
	end

	Addon.Logging.Print(("Midnight API check done: %d/%d available."):format(available_count, total_count))

	PrintNameplateCVarCheck()
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
	
	if command == "version" then
		PrintVersion()
	elseif command == "searchdb" then
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
		elseif component_name == "MidnightAPI" then
			PrintMidnightAPICheck()
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
	elseif command == "version-history" then
		-- Ad-hoc checks for Addon.CurrentVersionIsOlderThan, kept as a manual test since there is no
		-- automated test runner for this addon (see CLAUDE.md).
		Addon.Logging.Debug("10.2.11 < 10.3.0:", Addon.CurrentVersionIsOlderThan("10.2.11", "10.3.0"))
		Addon.Logging.Debug("10.2.11 < 10.3.0-beta2:", Addon.CurrentVersionIsOlderThan("10.2.11", "10.3.0-beta2"))
		Addon.Logging.Debug("10.3.0-beta2 < 9.3.0:", Addon.CurrentVersionIsOlderThan("10.3.0-beta2", "10.3.0"))
		Addon.Logging.Debug("10.3.0-beta2 < 10.3.0-beta3:", Addon.CurrentVersionIsOlderThan("10.3.0-beta2", "10.3.0-beta3"))
	elseif command == "reaction" then
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    if not plate then return end
    local unit = plate.TPFrame.unit

		Addon.Logging.Debug("Name:", unit.name)
		Addon.Logging.Debug("  Reaction:", unit.reaction)
		Addon.Logging.Debug("    UnitReaction:", Addon.GetUnitReactionToPlayer("target"))
    Addon.Logging.Debug("    UnitCanAttack = ", UnitCanAttack("target", "player"))
    Addon.Logging.Debug("    UnitIsFriend = ", UnitIsFriend("target", "player"))
		Addon.Logging.Debug("    UnitSelectionColor = ", UnitSelectionColor("target"))
		Addon.Logging.Debug("    UnitIsPVP = ", UnitIsPVP("target"))
		if not Addon.IS_CLASSIC and not Addon.IS_TBC_CLASSIC and not Addon.IS_WRATH_CLASSIC then
			Addon.Logging.Debug("    UnitSelectionType = ", UnitSelectionType("target"))
		end
	elseif command == "auras" then
		-- Temporary diagnostic: dumps the same aura fields ProcessAllUnitAuras() in AurasWidget.lua reads,
		-- to check whether nameplateShowAll/nameplateShowPersonal are actually populated by the client.
		if not C_UnitAuras or not C_UnitAuras.GetAuraSlots then
			Addon.Logging.Debug("C_UnitAuras.GetAuraSlots not available on this client.")
			return
		end

		local unitid = "target"
		Addon.Logging.Debug("Auras for", UnitName(unitid) or unitid, "- WOW_FEATURE_BLIZZARD_AURA_FILTER =", Addon.WOW_FEATURE_BLIZZARD_AURA_FILTER)

		for _, filter in ipairs({ "HARMFUL", "HELPFUL" }) do
			Addon.Logging.Debug("--", filter, "--")
			local continuation_token
			repeat
				local slots = { C_UnitAuras.GetAuraSlots(unitid, filter, 40, continuation_token) }
				continuation_token = slots[1]

				for i = 2, #slots do
					local aura = C_UnitAuras.GetAuraDataBySlot(unitid, slots[i])
					if aura then
						Addon.Logging.Debug(string.format("  %s (spellId=%s)", tostring(aura.name), tostring(aura.spellId)))
						Addon.Logging.Debug("    nameplateShowAll:", aura.nameplateShowAll)
						Addon.Logging.Debug("    nameplateShowPersonal:", aura.nameplateShowPersonal)
						Addon.Logging.Debug("    isBossAura:", aura.isBossAura, " isStealable:", aura.isStealable)
						Addon.Logging.Debug("    sourceUnit:", aura.sourceUnit, " duration:", aura.duration)

						-- Checks whether the modern aura filter tokens used in AurasWidgetMidnight.lua (PLAYER,
						-- RAID, INCLUDE_NAME_PLATE_ONLY, EXTERNAL_DEFENSIVE, CROWD_CONTROL, RAID_IN_COMBAT,
						-- RAID_PLAYER_DISPELLABLE, BIG_DEFENSIVE, IMPORTANT) are also usable on this client.
						if C_UnitAuras.IsAuraFilteredOutByInstanceID then
							for _, token in ipairs({
								"PLAYER", "RAID", "INCLUDE_NAME_PLATE_ONLY", "EXTERNAL_DEFENSIVE", "CROWD_CONTROL",
								"RAID_IN_COMBAT", "RAID_PLAYER_DISPELLABLE", "BIG_DEFENSIVE", "IMPORTANT",
							}) do
								local call_ok, is_filtered_out = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unitid, aura.auraInstanceID, filter .. "|" .. token)
								if call_ok then
									Addon.Logging.Debug("    " .. token .. ":", not is_filtered_out)
								else
									Addon.Logging.Debug("    " .. token .. " errored:", is_filtered_out)
								end
							end
						else
							Addon.Logging.Debug("    C_UnitAuras.IsAuraFilteredOutByInstanceID not available on this client.")
						end
					end
				end
			until continuation_token == nil
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
			Addon.Logging.Debug(i, "=", is_tank)
		end

		local spec_roles = Addon.db.char.spec
		if #spec_roles + 1 ~= GetNumSpecializations() then
			for i = 1, GetNumSpecializations() do
				local is_tank = spec_roles[i]
				if is_tank == nil then
					local id, spec_name, _, _, role = GetSpecializationInfo(i)
					local role = (role == "TANK" and true) or false
					spec_roles[i] = role
					Addon.Logging.Debug("Role", i, " => ", is_tank, " to ", role)
				else
					Addon.Logging.Debug("Role", i, " => ", is_tank)
				end
			end
		end
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
	elseif command == "test" then
    local plate = C_NamePlate.GetNamePlateForUnit("target", true)
    if not plate then return end

		Addon.Logging.Debug("Addon.UnitIsTarget:", Addon.UnitIsTarget)
		Addon.Logging.Debug("Addon.UnitIsUnit:", Addon.UnitIsUnit)
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