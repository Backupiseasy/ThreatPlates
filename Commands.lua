local _,ns = ...
local t = ns.ThreatPlates
local L = t.L

local Active = function() return GetActiveSpecGroup() end

local function toggleDPS()
	TidyPlatesThreat:SetRole(false)
	TidyPlatesThreat.db.profile.threat.ON = true
	if TidyPlatesThreat.db.profile.verbose then
	t.Print(L["-->>|cffff0000DPS Plates Enabled|r<<--"])
	t.Print(L["|cff89F559Threat Plates|r: DPS switch detected, you are now in your |cffff0000dpsing / healing|r role."])
	end
	TidyPlates:ForceUpdate()
end

local function toggleTANK()
	TidyPlatesThreat:SetRole(true)
	TidyPlatesThreat.db.profile.threat.ON = true
	if TidyPlatesThreat.db.profile.verbose then
	t.Print(L["-->>|cff00ff00Tank Plates Enabled|r<<--"])
	t.Print(L["|cff89F559Threat Plates|r: Tank switch detected, you are now in your |cff00ff00tanking|r role."])
	end
	TidyPlates:ForceUpdate()
end

SLASH_TPTPDPS1 = "/tptpdps"
SlashCmdList["TPTPDPS"] = toggleDPS
SLASH_TPTPTANK1 = "/tptptank"
SlashCmdList["TPTPTANK"] = toggleTANK

local function TPTPTOGGLE()
	if (TidyPlatesThreat.db.profile.optionRoleDetectionAutomatic and TidyPlatesThreat.db.profile.verbose) then
		t.Print(L["|cff89F559Threat Plates|r: Role toggle not supported because automatic role detection is enabled."])
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
				t.Print(L["We're unable to change this while in combat"])
			else
				SetCVar("nameplateMotion", 1)
				t.Print(L["-->>Nameplate Overlapping is now |cffff0000OFF!|r<<--"])
			end
		else
			if InCombatLockdown() then
				t.Print(L["We're unable to change this while in combat"])
			else
				SetCVar("nameplateMotion", 3)
				t.Print(L["-->>Nameplate Overlapping is now |cff00ff00ON!|r<<--"])
			end
		end
	else
		if GetCVar("spreadnameplates") == "0" then
			t.Print(L["-->>Nameplate Overlapping is now |cff00ff00ON!|r<<--"])
		else
			t.Print(L["-->>Nameplate Overlapping is now |cffff0000OFF!|r<<--"])
		end
	end
end

SLASH_TPTPOVERLAP1 = "/tptpol"
SlashCmdList["TPTPOVERLAP"] = TPTPOVERLAP

local function TPTPVERBOSE()
	if TidyPlatesThreat.db.profile.verbose then
		t.Print(L["-->>Threat Plates verbose is now |cffff0000OFF!|r<<-- shhh!!"])
	else
		t.Print(L["-->>Threat Plates verbose is now |cff00ff00ON!|r<<--"], true)
	end
	TidyPlatesThreat.db.profile.verbose = not TidyPlatesThreat.db.profile.verbose
end

SLASH_TPTPVERBOSE1 = "/tptpverbose"
SlashCmdList["TPTPVERBOSE"] = TPTPVERBOSE

local function PrintHelp()
	t.Print(L["Usage: /tptp [options]"], true)
	t.Print(L["options:"], true)
--	t.Print(L["  update-profiles    Migrates deprecated settings in your configuration"], true)
	t.Print(L["  classic-design     Reverts default settings back to look and feel before 8.4"], true)
  t.Print(L["  8.4-design         Changes default settings to new look and feel (introduced with 8.4)"], true)
	t.Print(L["  help               Prints this help message"], true)
	t.Print(L["  <no option>        Displays options dialog"], true)
end

-- /tptp
local function ParseCommandLine(message)
	-- split commands by space
	--for word in message:gmatch("%S+") do
	if message == "" then
		TidyPlatesThreat:OpenOptions()
--	elseif message == "update-profiles" then
--		t.Print(L["Migrating deprecated settings in configuration ..."])
--		t.UpdateConfiguration()
	elseif message == "classic-design" then
		t.Print(L["Reverting default settings back to look and feel before 8.4 ..."])
    TidyPlatesThreat.db.global.DefaultsVersion = 1
		t.SwitchToDefaultSettingsV1()
    t.SetThemes(TidyPlatesThreat)
    TidyPlates:ForceUpdate()
  elseif message == "8.4-design" then
    t.Print(L["Changing default settings to updated look and feel introduced with 8.4 ..."])
    TidyPlatesThreat.db.global.DefaultsVersion = 2
		t.SwitchToCurrentDefaultSettings()
		t.SetThemes(TidyPlatesThreat)
		TidyPlates:ForceUpdate()
	elseif message == "internal" then
		TidyPlatesThreat.db.global.CheckNewLookAndFeel = nil
	elseif message == "help" then
		PrintHelp()
	else
		t.Print(L["Unknown option: "] .. message, true)
		PrintHelp()
	end
end

-----------------------------------------------------
-- External
-----------------------------------------------------

TidyPlatesThreat.ParseCommandLine = ParseCommandLine
