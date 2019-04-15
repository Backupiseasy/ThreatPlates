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
		if Addon.PlayerRoleIsTank then
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

function TidyPlatesThreat:ChatCommand(input)
	local cmd_list = {}
	for w in input:gmatch("%S+") do cmd_list[#cmd_list + 1] = w end

	local command = cmd_list[1]
	if not command or command == "" then
		TidyPlatesThreat:OpenOptions()
	elseif input == "event" then
		Addon:PrintEventService()
	elseif input == "combat" then
		local plate = C_NamePlate.GetNamePlateForUnit("target")
		if not plate then return end

		print ("In Combat:", IsInCombat())
		print ("In Combat with Player:", UnitAffectingCombat("target", "player"))
	elseif input == "debug" then
		local plate = C_NamePlate.GetNamePlateForUnit("target")
		if not plate then return end

		local tp_frame = plate.TPFrame
		local unit = tp_frame.unit
		local stylename = tp_frame.stylename
		local nameplate_style = ((stylename == "NameOnly" or stylename == "NameOnly-Unique") and "NAME") or "HEALTHBAR"

		print ("Unit Name:", unit.name)
		print ("Unit Reaction:", unit.reaction)
		print ("Frame Style:", stylename)
		print ("Plate Style:", nameplate_style)
		print ("Color Statusbar:", Addon.Debug:ColorToString(tp_frame.visual.Healthbar:GetStatusBarColor()))
		print ("Color Border:", Addon.Debug:ColorToString(tp_frame.visual.Healthbar.Border:GetBackdropColor()))
	elseif input == "plate" then
		local plate = C_NamePlate.GetNamePlateForUnit("target")
		if not plate then return end

		local tp_frame = plate.TPFrame
		local unit = tp_frame.unit

		local stylename = "dps"
		local style = Addon.Theme[stylename]

		local NAMEPLATE_STYLES_BY_THEME = {
			dps = "HEALTHBAR",
			tank = "HEALTHBAR",
			normal = "HEALTHBAR",
			totem = "HEALTHBAR",
			unique = "HEALTHBAR",
			empty = "NONE",
			etotem = "NONE",
			NameOnly = "NAME",
			["NameOnly-Unique"] = "NAME",
		}

		tp_frame.PlateStyle = NAMEPLATE_STYLES_BY_THEME[stylename]
		tp_frame.stylename = stylename
		tp_frame.style = style
		unit.style = stylename

		Addon.Elements.GetElement("Healthbar").UpdateStyle(tp_frame, style)
	elseif command == "unit" then
		local plate = C_NamePlate.GetNamePlateForUnit("target")
		if not plate then return end
		local unit = plate.TPFrame.unit

		TP.DEBUG_PRINT_UNIT(unit, true)
    local type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-", unit.guid)
    print ("GUID:", type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid)
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
  elseif command == "quest" then
		Addon:PrintQuests()
	elseif command == "test" then
    for k, v in pairs(Addon.LibCustomGlow) do
      print(k, v)
    end
	elseif command == "migrate" then
		Addon.MigrateDatabase(cmd_list[2])
		--		--PrintHelp()
--	else
--		TP.Print(L["Unknown option: "] .. input, true)
--		PrintHelp()
	elseif command == "db" then
		print ("Searching settings:")
		SearchDBForString(TidyPlatesThreat.db.profile, "<Profile>", string.lower(cmd_list[2]))
	end
end

-----------------------------------------------------
-- External
-----------------------------------------------------