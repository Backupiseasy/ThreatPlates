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
		if Addon.PlayerRoleIsTank() then
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
	if input == "event" then
    Addon:PrintEventService()
    return
  end

	--	if input == "plate" then
--		local plate = C_NamePlate.GetNamePlateForUnit("target")
--		if not plate then return end
--
--		print ("Nameplate FrameStrata:", plate:GetFrameStrata())
--		print ("Nameplate FrameLevel :", plate:GetFrameLevel())
--		print ("Nameplate Parent:", (plate:GetParent() == UIParent and "UIParent") or (plate:GetParent() == WorldFrame and "WorldFrame") or ("---"))
--		print ("------------------------------------------")
--		print ("Nameplate UnitFrame FrameStrata:", plate.UnitFrame:GetFrameStrata())
--		print ("Nameplate UnitFrame FrameLevel :", plate.UnitFrame:GetFrameLevel())
--		print ("Nameplate UnitFrame Parent:", (plate.UnitFrame:GetParent() == UIParent and "UIParent") or (plate.UnitFrame:GetParent() == WorldFrame and "WorldFrame") or ("---"))
--		print ("------------------------------------------")
--		print ("TPFrame FrameStrata:", plate.TPFrame:GetFrameStrata())
--		print ("TPFrame FrameLevel :", plate.TPFrame:GetFrameLevel())
--		print ("TPFrame Parent:", (plate.TPFrame:GetParent() == UIParent and "UIParent") or (plate.TPFrame:GetParent() == WorldFrame and "WorldFrame") or ("---"))
--		print ("------------------------------------------")
--		print ("Healthbar FrameStrata:", plate.TPFrame.visual.healthbar:GetFrameStrata())
--		print ("Healthbar FrameLevel :", plate.TPFrame.visual.healthbar:GetFrameLevel())
--    return
--  elseif input == "cp" then
--      local plate = C_NamePlate.GetNamePlateForUnit("target")
--      if not plate then return end
--
--      print ("TPFrame FrameLevel :", plate.TPFrame:GetFrameLevel())
--      print ("ComboPointsFrameStrata:", Addon.Widgets.ComboPoints.WidgetFrame:GetFrameLevel())
--      print ("TargetHighlight FrameLevel :", plate.TPFrame.widgets.TargetArt:GetFrameLevel())
--		return
--	elseif input == "occ" then
--		local plate = C_NamePlate.GetNamePlateForUnit("mouseover")
--		if not plate then return end
--
--		print ("Plate Alpha:", plate:GetAlpha())
--		print ("TP Alpha::", plate.TPFrame:GetAlpha(), " => Current:", plate.TPFrame.CurrentAlpha)
--		print ("Occluded Alpha:", plate.TPFrame.OccludedAlpha)
--
--    Addon:UpdatePlate_TransparencyTest(plate.TPFrame, plate.TPFrame.unit)
--
--    print ("Plate Alpha:", plate:GetAlpha())
--    print ("TP Alpha::", plate.TPFrame:GetAlpha(), " => Current:", plate.TPFrame.CurrentAlpha)
--    print ("Occluded Alpha:", plate.TPFrame.OccludedAlpha)
--		return
--  elseif input == "print" then
--    print ("nameplateMinAlpha:", GetCVar("nameplateMinAlpha"))
--    print ("nameplateMaxAlpha:", GetCVar("nameplateMaxAlpha"))
--    print ("nameplateSelectedAlpha:", GetCVar("nameplateSelectedAlpha"))
--    print ("nameplateOccludedAlphaMult:", GetCVar("nameplateOccludedAlphaMult"))
--    return
--  elseif input == "set-occ" then
--    Addon.CVars:Set("nameplateMinAlpha", 1)
--    Addon.CVars:Set("nameplateMaxAlpha", 1)
--
--    -- Create enough separation between occluded and not occluded nameplates, even for targeted units
--    local occluded_alpha_mult = tonumber(GetCVar("nameplateOccludedAlphaMult"))
--    if occluded_alpha_mult > 0.9  then
--      occluded_alpha_mult = 0.9
--      Addon.CVars:Set("nameplateOccludedAlphaMult", occluded_alpha_mult)
--    end
--
--    local selected_alpha =  tonumber(GetCVar("nameplateSelectedAlpha"))
--    if not selected_alpha or (selected_alpha < occluded_alpha_mult + 0.1) then
--      selected_alpha = occluded_alpha_mult + 0.1
--      Addon.CVars:Set("nameplateSelectedAlpha", selected_alpha)
--    end
--
--    return
--  elseif input == "reset-occ" then
--    Addon.CVars:RestoreAllFromProfile()
--    return
--  elseif input == "cache-occ" then
--    for cvar, value in pairs(TidyPlatesThreat.db.profile.CVarsBackup) do
--      print (cvar .. ":", value)
--    end
--    return
--  end

	TidyPlatesThreat:OpenOptions()

--	local cmd_list = {}
--	for w in input:gmatch("%S+") do cmd_list[#cmd_list + 1] = w end
--
--	local command = cmd_list[1]
--	if command == "" then
--		-- do something
--	elseif command == "help" then
--		PrintHelp()
--	else
--		t.Print(L["Unknown option: "] .. input, true)
--		PrintHelp()
--	end
end

-----------------------------------------------------
-- External
-----------------------------------------------------