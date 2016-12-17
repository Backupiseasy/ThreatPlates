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
				t.Print("We're unable to change this while in combat")
			else
				SetCVar("nameplateMotion", 1)
				t.Print(L["-->>Nameplate Overlapping is now |cffff0000OFF!|r<<--"])
			end
		else
			if InCombatLockdown() then
				t.Print("We're unable to change this while in combat")
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

local function TPTPPERF()
	if TidyPlatesThreat.db.profile.verbose then
		UpdateAddOnMemoryUsage()
		local mem = GetAddOnMemoryUsage("TidyPlates_ThreatPlates")
		t.Print("-->> Threat Plates memory usage: "..tostring(mem))
	end
end

SLASH_TPTPPERF1 = "/tptpperformance"
SlashCmdList["TPTPPERF"] = TPTPPERF

local function TPTPUPDATE()
	if TidyPlatesThreat.db.profile.verbose then
		t.Print("Updating settings ...")
	end
	t.UpdateConfiguration()
end

SLASH_TPTPUPDATE1 = "/tptpupdate"
SlashCmdList["TPTPUPDATE"] = TPTPUPDATE
