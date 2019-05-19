local ADDON_NAME, Addon = ...
local TP = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

local DEBUG = true

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local L = TP.L

local function toggleDPS()
  if TidyPlatesThreat.db.profile.optionRoleDetectionAutomatic then
    TP.Print(L["|cff89F559Threat Plates|r: Role toggle not supported because automatic role detection is enabled."], true)
  else
    TidyPlatesThreat.db.char.spec[GetSpecialization()] = false
    TidyPlatesThreat.db.profile.threat.ON = true
    TP.Print(L["-->>|cffff0000DPS Plates Enabled|r<<--"])
    TP.Print(L["|cff89F559Threat Plates|r: DPS switch detected, you are now in your |cffff0000dpsing / healing|r role."])
    Addon:ForceUpdate()
  end
end

local function toggleTANK()
  if TidyPlatesThreat.db.profile.optionRoleDetectionAutomatic then
    TP.Print(L["|cff89F559Threat Plates|r: Role toggle not supported because automatic role detection is enabled."], true)
  else
    TidyPlatesThreat.db.char.spec[GetSpecialization()] = true
    TidyPlatesThreat.db.profile.threat.ON = true
    TP.Print(L["-->>|cff00ff00Tank Plates Enabled|r<<--"])
    TP.Print(L["|cff89F559Threat Plates|r: Tank switch detected, you are now in your |cff00ff00tanking|r role."])
    Addon:ForceUpdate()
  end
end

SLASH_TPTPDPS1 = "/tptpdps"
SlashCmdList["TPTPDPS"] = toggleDPS
SLASH_TPTPTANK1 = "/tptptank"
SlashCmdList["TPTPTANK"] = toggleTANK

local function TPTPTOGGLE()
	if TidyPlatesThreat.db.profile.optionRoleDetectionAutomatic then
		TP.Print(L["|cff89F559Threat Plates|r: Role toggle not supported because automatic role detection is enabled."], true)
	else
		if Addon.PlayerRole == "tank" then
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
  elseif DEBUG then
    if command == "prune" then
      TP.Print("|cff89F559Threat Plates|r: Pruning deprecated data from addon settings ...", true)
      Addon:DeleteDeprecatedSettings()
    elseif input == "event" then
      TP.Print("|cff89F559Threat Plates|r: Event publishing overview:", true)
      Addon:PrintEventService()
    elseif command == "searchdb" then
      TP.Print("|cff89F559Threat Plates|r: Searching settings:", true)
      SearchDBForString(TidyPlatesThreat.db.profile, "<Profile>", string.lower(cmd_list[2]))
    else
      TidyPlatesThreat:ChatCommandDebug(cmd_list)
    end
  end
end

function TidyPlatesThreat:ChatCommandDebug(cmd_list)
	local command = cmd_list[1]
	if input == "combat" and DEBUG then
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
		local nameplate_style = ((stylename == "NameOnly" or stylename == "NameOnly-Unique") and "NameMode") or "HealthbarMode"

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
	elseif command == "unit" then
		local plate = C_NamePlate.GetNamePlateForUnit("target")
		if not plate then return end
		local unit = plate.TPFrame.unit

		TP.DEBUG_PRINT_UNIT(unit, true)
    local type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-", unit.guid)
    print ("GUID:", type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid)
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
    for i = 1, 100 do
      --
      Addon.GetSituationalColorHealthbar(unit, plate.TPFrame.PlateStyle)
      Addon.GetSituationalColorName(unit, plate.TPFrame.PlateStyle)
      --
    end
    local timeUsed = debugprofilestop()  -beginTime
    print("Both: "..timeUsed)

    local beginTime = debugprofilestop()
    for i = 1, 100 do
      --
      Addon.GetSituationalColorCombined(unit, plate.TPFrame.PlateStyle)
      --
    end
    local timeUsed = debugprofilestop()  -beginTime
    print("One : "..timeUsed)
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
--		local profile = TidyPlatesThreat.db.profile
--		local prefix = { "HeadlineView", "customtext" }
--		print ("profile.StatusText.NameMode.Size =", Addon:TestGetValueOrDefault(profile, prefix, "size"))
--		print ("profile.StatusText.NameMode.HorizontalOffset =", Addon:TestGetValueOrDefault(profile, prefix, "x"))
--		print ("profile.StatusText.NameMode.VerticalOffset =", Addon:TestGetValueOrDefault(profile, prefix, "y"))
--		print ("profile.StatusText.NameMode.HorizontalAlignment =", Addon:TestGetValueOrDefault(profile, prefix, "align"))
--		print ("profile.StatusText.NameMode.VerticalAlignment =", Addon:TestGetValueOrDefault(profile, prefix, "vertical"))
		print ("Migrate with current version = 9.3.0:")
		Addon.MigrateEntries("9.3.0")
		print ("Migrate with current version = 9.1.0:")
		Addon.MigrateEntries("9.1.0")
		print ("Migrate with current version = 9.2.0:")
		Addon.MigrateEntries("9.2.0")
	elseif command == "migrate" then
		Addon.MigrateDatabase(cmd_list[2])
  elseif command == "role" then

    local spec_roles = TidyPlatesThreat.db.char.spec
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

--
--    for index = 1, GetNumSpecializations() do
--      local id, name, description, icon, role, primaryStat = GetSpecializationInfo(index)
--      --local id, name, description, texture, role, class = GetSpecializationInfoByID(specID);
--      print (name, "(", id, ") =>", role)
--    end
--
--    for i = 1, GetNumClasses() do
--      local _, class, classID = GetClassInfo(i)
--      for j = 1, GetNumSpecializationsForClassID(classID) do
--        local _, spec, _, _, role = GetSpecializationInfoForClassID(classID, j)
--        print (class .. ":", spec, "=>", role)
--      end
--    end

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