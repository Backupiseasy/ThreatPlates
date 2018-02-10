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
	TidyPlatesInternal:ForceUpdate()
end

local function toggleTANK()
	TidyPlatesThreat:SetRole(true)
	TidyPlatesThreat.db.profile.threat.ON = true
	if TidyPlatesThreat.db.profile.verbose then
		TP.Print(L["-->>|cff00ff00Tank Plates Enabled|r<<--"])
		TP.Print(L["|cff89F559Threat Plates|r: Tank switch detected, you are now in your |cff00ff00tanking|r role."])
	end
	TidyPlatesInternal:ForceUpdate()
end

SLASH_TPTPDPS1 = "/tptpdps"
SlashCmdList["TPTPDPS"] = toggleDPS
SLASH_TPTPTANK1 = "/tptptank"
SlashCmdList["TPTPTANK"] = toggleTANK

local function TPTPTOGGLE()
	if (TidyPlatesThreat.db.profile.optionRoleDetectionAutomatic and TidyPlatesThreat.db.profile.verbose) then
		TP.Print(L["|cff89F559Threat Plates|r: Role toggle not supported because automatic role detection is enabled."])
	else
		if TidyPlatesThreat:GetSpecRole() then
			toggleDPS()
		else
			toggleTANK()
		end
	end
end

SLASH_TPTPTOGGLE1 = "/tptptoggle"
SlashCmdList["TPTPTOGGLE"] = TPTPTOGGLE

local function TPTPOVERLAP()
	local _, build = GetBuildInfo()
	if tonumber(build) > 13623 then
		if GetCVar("nameplateMotion") == "3" then
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
				SetCVar("nameplateMotion", 3)
				TP.Print(L["-->>Nameplate Overlapping is now |cff00ff00ON!|r<<--"])
			end
		end
	else
		if GetCVar("spreadnameplates") == "0" then
			TP.Print(L["-->>Nameplate Overlapping is now |cff00ff00ON!|r<<--"])
		else
			TP.Print(L["-->>Nameplate Overlapping is now |cffff0000OFF!|r<<--"])
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
	if input == "nameplate-size" then
    print ("IsUsingLargerNamePlateStyle: ", NamePlateDriverFrame:IsUsingLargerNamePlateStyle())
    print ("CVar nameplateGlobalScale: ", GetCVar("nameplateGlobalScale"))
    print ("Config OldNameplateGlobalScale: ", TidyPlatesThreat.db.profile.Automation.OldNameplateGlobalScale)
    return
      --	elseif input == "big" then
--    SetCVar("NamePlateVerticalScale", 1)
--    SetCVar("NamePlateHorizontalScale", 1)
--    NamePlateDriverFrame:UpdateNamePlateOptions()
--		SetCVar("NamePlateVerticalScale", 2.7)
--		SetCVar("NamePlateHorizontalScale", 1.4)
--		NamePlateDriverFrame:UpdateNamePlateOptions()
----		print ("GetBaseNamePlateWidth: ", NamePlateDriverFrame:GetBaseNamePlateWidth())
----		print ("GetBaseNamePlateHeight: ", NamePlateDriverFrame:GetBaseNamePlateHeight())
----		print ("NamePlateHorizontalScale: ", GetCVar("NamePlateHorizontalScale"))
----		print ("IsUsingLargerNamePlateStyle: ", NamePlateDriverFrame:IsUsingLargerNamePlateStyle())
----		TidyPlatesThreat.db.profile.Automation.OldNameplateGlobalScale = nil
--		--SetCVar("NamePlateVerticalScale", "1.0")
--		--SetCVar("NamePlateHorizontalScale", "1.0")
--    --SetCVar("nameplateGlobalScale", "0.4") -- to set height
--		--C_NamePlate.SetNamePlateFriendlySize(300, 100) -- to adjust width, height is ignored
--		--NamePlateDriverFrame:UpdateNamePlateOptions()
--    --NamePlateDriverFrame:SetBaseNamePlateSize( 300, 200 )
--		return
--	elseif input == "test" then
--		print ("GetBaseNamePlateWidth: ", NamePlateDriverFrame:GetBaseNamePlateWidth())
--		print ("GetBaseNamePlateHeight: ", NamePlateDriverFrame:GetBaseNamePlateHeight())
--		print ("NamePlateHorizontalScale: ", GetCVar("NamePlateHorizontalScale"))
--		print ("NamePlateVerticalScale: ", GetCVar("NamePlateVerticalScale"))
--		print ("IsUsingLargerNamePlateStyle: ", NamePlateDriverFrame:IsUsingLargerNamePlateStyle())
--		print ("----------------")
--		local baseWidth = NamePlateDriverFrame:GetBaseNamePlateWidth()
--		local baseHeight = NamePlateDriverFrame:GetBaseNamePlateHeight()
--		local zeroBasedScale = tonumber(GetCVar("NamePlateVerticalScale")) - 1.0
--		local horizontalScale = tonumber(GetCVar("NamePlateHorizontalScale"))
--		print ("BaseNamePlateSize: ", baseWidth * horizontalScale, baseHeight * Lerp(1.0, 1.25, zeroBasedScale))
--
--		--		TidyPlatesThreatTest = true
----		TidyPlatesInternal:ForceUpdate()
--		return
--	elseif input == "end" then
--		TidyPlatesThreatTest = nil
--		TidyPlatesInternal:ForceUpdate()
--		return
	end

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