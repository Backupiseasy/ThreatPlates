local _, ns = ...
local t = ns.ThreatPlates
local L = t.L
local class = t.Class()

t.Theme = {}

TidyPlatesThreat = LibStub("AceAddon-3.0"):NewAddon("TidyPlatesThreat", "AceConsole-3.0", "AceEvent-3.0")

local RBG = function(red, green, blue)
	return { r = red/255, g = green/255, b = blue/255 }
end

---------------------------------------------------------------------------------------------------
-- Global configs and funtions
---------------------------------------------------------------------------------------------------

local TIDYPLATES_VERSIONS = { "6.18.10" }
local TIDYPLATES_INSTALLED_VERSION = GetAddOnMetadata("TidyPlates", "version") or ""

-- check if the correct TidyPlates version is installed
function CheckTidyPlatesVersion()
	-- local GlobDB = TidyPlatesThreat.db.global
	-- if not GlobDB.versioncheck then
	-- 	local version_no = 0
	-- 	local version = string.gsub(TIDYPLATES_INSTALLED_VERSION, "Beta", "")
	-- 	for w in string.gmatch(version, "[0-9]+") do
	-- 		version_no = version_no * 1000 + (tonumber(w) or 0)
	-- 	end
	--
	-- 	if version_no < TIDYPLATES_MIN_VERSION_NO then
	-- 		t.Print("\n---------------------------------------\nThe current version of ThreatPlates requires at least TidyPlates "] .. TIDYPLATES_MIN_VERSION .. L[". You have installed an older or incompatible version of TidyPlates: "] .. TIDYPLATES_INSTALLED_VERSION .. L[". Please update TidyPlates, otherwise ThreatPlates will not work properly.")
	-- 	end
	-- 	GlobDB.versioncheck = true
	-- end
end

local function AlphaFeatureHeadlineView()
	return TidyPlatesThreat.db.profile.headlineView.enabled and TidyPlatesHubFunctions
end
t.AlphaFeatureHeadlineView = AlphaFeatureHeadlineView

t.Print = function(val,override)
	local db = TidyPlatesThreat.db.profile
	if override or db.verbose then
		print(t.Meta("titleshort")..": "..val)
	end
end

local SPEC_ROLES = {
	DEATHKNIGHT = { true, false, false },
	DEMONHUNTER = { false, true },
	DRUID 			= { false, false, true, false },
	HUNTER			= { false, false, false },
	MAGE				= { false, false, false },
	MONK 				= { true, false, false },
	PALADIN 		= { false, true, false },
	PRIEST			= { false, false, false },
	ROGUE				= { false, false, false },
	SHAMAN			= { false, false, false },
	WARLOCK			= { false, false, false },
	WARRIOR			= { false, false, true },
}

-- Returns if the currently active spec is tank (true) or dps/heal (false)
function TidyPlatesThreat:GetSpecRole()
	local active_role

	if (self.db.profile.optionRoleDetectionAutomatic) then
		active_role = SPEC_ROLES[t.Class()][t.Active()]
		if not active_role then active_role = false end
	else
		active_role = self.db.char.spec[t.Active()]
	end

	return active_role
end

-- Sets the role of the index spec or the active spec to tank (value = true) or dps/healing
function TidyPlatesThreat:SetRole(value,index)
	if index then
		self.db.char.spec[index] = value
	else
		self.db.char.spec[t.Active()] = value
	end
end

local tankRole = L["|cff00ff00tanking|r"]
local dpsRole = L["|cffff0000dpsing / healing|r"]

function TidyPlatesThreat:RoleText()
	if TidyPlatesThreat:GetSpecRole() then
		return tankRole
	else
		return dpsRole
	end
end

function TidyPlatesThreat:SpecName()
	local _,name,_,_,_,role = GetSpecializationInfo(GetSpecialization(false,false,1),nil,false)
	if name then
		return name
	else
		return L["Undetermined"]
	end
end

---------------------------------------------------------------------------------------------------

StaticPopupDialogs["SetToThreatPlates"] = {
	preferredIndex = STATICPOPUP_NUMDIALOGS,
	text = t.Meta("title")..L[":\n----------\nWould you like to \nset your theme to |cff89F559Threat Plates|r?\n\nClicking '|cff00ff00Yes|r' will set you to Threat Plates & reload UI. \n Clicking '|cffff0000No|r' will open the Tidy Plates options."],
	button1 = L["Yes"],
	button2 = L["Cancel"],
	button3 = L["No"],
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function()
		TidyPlates:SetTheme(THREAT_PLATES_NAME)
		TidyPlatesThreat:StartUp()
		t.Update()
	end,
	OnAlt = function()
		InterfaceOptionsFrame_OpenToCategory("Tidy Plates")
	end,
	OnCancel = function()
		t.Print(L["-->>|cffff0000Activate Threat Plates from the Tidy Plates options!|r<<--"])
	end,
}

-- Callback Functions
function TidyPlatesThreat:ProfChange()
	t.SetThemes(self)
	--t.ClearTidyPlatesWidgets(self)
	--t.SetTidyPlatesWidgets(self)
	t.Update()
	self:ConfigRefresh();
	self:StartUp();
	TidyPlates:ForceUpdate();
end

--[[Options and Default Settings]]--

-- AceAddon function: do init tasks here, like loading the Saved Variables, or setting up slash commands.
function TidyPlatesThreat:OnInitialize()
	local defaults 	= {
		global = {
			version = "",
			versioncheck = false,
		},
		char = {
			welcome = false,
			specInfo = {
				[1] = {
					name = "",
					role = "",
				},
				[2] = {
					name = "",
					role = "",
				},
			},
			spec = {
				[1] = false,
				[2] = false,
			},
			stances = {
				ON = false,
				[0] = false, -- No Stance
				[1] = false, -- Battle Stance
				[2] = true, -- Defensive Stance
				[3] = false -- Berserker Stance
			},
			shapeshifts = {
				ON = false,
				[0] = false, -- Caster Form
				[1] = true, -- Bear Form
				[2] = false, -- Cat Form
				[3] = false, -- Travel Form
				[4] = false, -- Moonkin Form, Tree of Life
			},
			presences = {
				ON = false,
				[0] = false, -- No Presence
				[1] = true, -- Blood
				[2] = false, -- Frost
				[3] = false -- Unholy
			},
			seals = {
				ON = false,
				[0] = false, -- No Aura
				[1] = true, -- Devotion Aura
				[2] = false, -- Retribution Aura
				[3] = false, -- Concentration Aura
				[4] = false, -- Resistance Aura
				[5] = false -- Crusader Aura
			},
		},
		profile = {
			cache = {},
			OldSetting = true,
			verbose = true,
			blizzFadeA = {
				toggle  = true,
				amount = -0.3
			},
			blizzFadeS = {
				toggle  = true,
				amount = -0.3
			},
			tidyplatesFade = false,
			healthColorChange = false,
			customColor =  false,
			allowClass = false,
			friendlyClass = false,
			friendlyClassIcon = false,
			cacheClass = false,
			optionRoleDetectionAutomatic = false,
			headlineView = {
				enabled = false,
				useAlpha = false,
				blizzFading = true,
				blizzFadingAlpha = 1,
				useScaling = false,
				name = { size = 10, width = 116, height = 14, x = 0, y = 4, align = "CENTER", vertical = "CENTER", },
				useHostileClassColoring = false,
				useFriendlyClassColoring = false,
				useRaidMarkColoring = false,
			},
			visibility = {
				showNameplates = true,
				showHostileUnits = true,
				showFriendlyUnits = false,
				showNormal = true,
				showNormalHeadlineView = false,
				showBoss = true,
				showBossHeadlineView = false,
				showElite = true,
				showEliteHeadlineView = false,
				showFriendlyPet = true,
				showFriendlyPetHeadlineView = false,
				showFriendlyGuardian = true,
				showFriendlyGuardianHeadlineView = false,
				showFriendlyNPC = true,
				showFriendlyNPCHeadlineView = false,
				showFriendlyPlayer = true,
				showFriendlyPlayerHeadlineView = false,
				showFriendlyTotem = true,
				showFriendlyTotemHeadlineView = false,
				showHostilePet = true,
				showHostilePetHeadlineView = false,
				showHostileGuardian = true,
				showHostileGuardianHeadlineView = false,
				showHostileMinor = true,
				showHostileMinorHeadlineView = false,
				showHostileNPC = true,
				showHostileNPCHeadlineView = false,
				showHostilePlayer = true,
				showHostilePlayerHeadlineView = false,
				showHostileTotem = true,
				showHostileTotemHeadlineView = false,
				showNeutralGuardians = true,
				showNeutralGuardiansHeadlineView = false,
				showNeutralNPC = true,
				showNeutralNPCHeadlineView = false,
				showNeutralMinor = true,
				showNeutralMinorHeadlineView = false,
				showTapped = true,
				showTappedHeadlineView = false,
			},
			castbarColor = {
				toggle = true,
				r = 1,
				g = 0.56,
				b = 0.06,
				a = 1
			},
			castbarColorShield = {
				toggle = true,
				r = 1,
				g = 0,
				b = 0,
				a = 1
			},
			aHPbarColor = {	r = 0, g = 1, b = 0},
			bHPbarColor = {r = 1,g = 1,b = 0},
			cHPbarColor = {r = 1,g = 0,b = 0},
			fHPbarColor = {r = 1,g = 1,b = 1},
			nHPbarColor = {r = 1,g = 1,b = 1},
			tapHPbarColor = {r = 1,g = 1,b = 1},
			HPbarColor = {r = 1,g = 1,b = 1},
			tHPbarColor = {r = 0,g = 0.5,b = 1,},
			ColorByReaction = {
				FriendlyPlayer = { r = 0, g = 0, b = 1, },		-- blue
				FriendlyNPC = { r = 0, g = 1, b = 0, },			-- green
				HostileNPC = { r = 1, g = 0, b = 0, },				-- red
				HostilePlayer = { r = 1, g = 0, b = 0, },		-- red
				NeutralUnit = { r = 1, g = 1, b = 0, },			-- yellow
				TappedUnit = { r = 110/255, g = 110/255, b = 110/255, },	-- grey
				GuildMember = { r = 60/255, g = 168/255, b = 255/255, }, -- light blue
			},
			text = {
				amount = true,
				percent = true,
				full = false,
				max = false,
				deficit = false,
				truncate = true
			},
			totemWidget = {
				ON = true,
				scale = 35,
				x = 0,
				y = 35,
				level = 1,
				anchor = "CENTER"
			},
			arenaWidget = {
				ON = true,
				scale = 16,
				x = 36,
				y = -6,
				anchor = "CENTER",
				colors = {
					[1] = {
						r = 1,
						g = 0,
						b = 0,
						a = 1
					},
					[2] = {
						r = 1,
						g = 1,
						b = 0,
						a = 1
					},
					[3] = {
						r = 0,
						g = 1,
						b = 0,
						a = 1
					},
					[4] = {
						r = 0,
						g = 1,
						b = 1,
						a = 1
					},
					[5] = {
						r = 0,
						g = 0,
						b = 1,
						a = 1
					},
				},
				numColors = {
					[1] = {
						r = 1,
						g = 1,
						b = 1,
						a = 1
					},
					[2] = {
						r = 1,
						g = 1,
						b = 1,
						a = 1
					},
					[3] = {
						r = 1,
						g = 1,
						b = 1,
						a = 1
					},
					[4] = {
						r = 1,
						g = 1,
						b = 1,
						a = 1
					},
					[5] = {
						r = 1,
						g = 1,
						b = 1,
						a = 1
					},
				},
			},
			healerTracker = {
				ON = true,
				scale = 1,
				x = 0,
				y = 35,
				level = 1,
				anchor = "CENTER"
			},
			debuffWidget = {
				ON = true,
				x = 18,
				y = 32,
				mode = "whitelist",
				style = "square",
				displays = {
					[1] = true,
					[2] = true,
					[3] = true,
					[4] = true,
					[5] = true,
					[6] = true
				},
				targetOnly = false,
				cooldownSpiral = true,
				showFriendly = true,
				showEnemy = true,
				scale = 1,
				anchor = "CENTER",
				filter = {}
			},
			uniqueWidget = {
				ON = true,
				scale = 35,
				x = 0,
				y = 35,
				level = 1,
				anchor = "CENTER"
			},
			classWidget = {
				ON = true,
				scale = 22,
				x = -74,
				y = -7,
				theme = "default",
				anchor = "CENTER",
			},
			targetWidget = {
				ON = true,
				theme = "default",
				r = 1,
				g = 1,
				b = 1,
				a = 1
			},
			threatWidget = {
				ON = false,
				x = 0,
				y = 26,
				anchor = "CENTER",
			},
			tankedWidget = {
				ON = false,
				scale = 1,
				x = 65,
				y = 6,
				anchor = "CENTER",
			},
			comboWidget = {
				ON = false,
				scale = 1,
				x = 0,
				y = -8,
			},
			eliteWidget = {
				ON = true,
				theme = "default",
				scale = 15,
				x = 64,
				y = 9,
				anchor = "CENTER"
			},
			socialWidget = {
				ON = false,
				scale = 16,
				x = 65,
				y = 6,
				anchor = "CENTER",
			},
			questWidget = {	ON = false,	scale = 26,	x = 0, y = 30, alpha = 1, anchor = "CENTER",
				ModeHPBar = true,
				ModeIcon = true,
				HPBarColor = RBG(255, 140, 0),
				HideInCombat = true,
				HideInInstance = true,
			},
			stealthWidget = {	ON = false, scale = 28, x = 0, y = 0,	alpha = 1, anchor = "CENTER", },
			totemSettings = ThreatPlatesWidgets.TOTEM_SETTINGS,
			uniqueSettings = {
				list = {},
				["**"] = {
					name = "",
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "",
					scale = 1,
					alpha = 1,
					color = {
						r = 1,
						g = 1,
						b = 1
					},
				},
				[1] = {
					name = L["Shadow Fiend"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U1",
					scale = 0.45,
					alpha = 1,
					color = {
						r = 0.61,
						g = 0.40,
						b = 0.86
					},
				},
				[2] = {
					name = L["Spirit Wolf"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U2",
					scale = 0.45,
					alpha = 1,
					color = {
						r = 0.32,
						g = 0.7,
						b = 0.89
					},
				},
				[3] = {
					name = L["Ebon Gargoyle"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U3",
					scale = 0.45,
					alpha = 1,
					color = {
						r = 1,
						g = 0.71,
						b = 0
					},
				},
				[4] = {
					name = L["Water Elemental"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U4",
					scale = 0.45,
					alpha = 1,
					color = {
						r = 0.33,
						g = 0.72,
						b = 0.44
					},
				},
				[5] = {
					name = L["Treant"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U5",
					scale = 0.45,
					alpha = 1,
					color = {
						r = 1,
						g = 0.71,
						b = 0
					},
				},
				[6] = {
					name = L["Viper"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U6",
					scale = 0.45,
					alpha = 1,
					color = {
						r = 0.39,
						g = 1,
						b = 0.11
					},
				},
				[7] = {
					name = L["Venomous Snake"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U6",
					scale = 0.45,
					alpha = 1,
					color = {
						r = 0.75,
						g = 0,
						b = 0.02
					},
				},
				[8] = {
					name = L["Army of the Dead Ghoul"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U7",
					scale = 0.45,
					alpha = 1,
					color = {
						r = 0.87,
						g = 0.78,
						b = 0.88
					},
				},
				[9] = {
					name = L["Shadowy Apparition"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U8",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.62,
						g = 0.19,
						b = 1
					},
				},
				[10] = {
					name = L["Shambling Horror"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U9",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.69,
						g = 0.26,
						b = 0.25
					},
				},
				[11] = {
					name = L["Web Wrap"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U10",
					scale = 0.75,
					alpha = 1,
					color = {
						r = 1,
						g = 0.39,
						b = 0.96
					},
				},
				[12] = {
					name = L["Immortal Guardian"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U11",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.33,
						g = 0.33,
						b = 0.33
					},
				},
				[13] = {
					name = L["Marked Immortal Guardian"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U12",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.75,
						g = 0,
						b = 0.02
					},
				},
				[14] = {
					name = L["Empowered Adherent"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U13",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.29,
						g = 0.11,
						b = 1
					},
				},
				[15] = {
					name = L["Deformed Fanatic"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U14",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.55,
						g = 0.7,
						b = 0.29
					},
				},
				[16] = {
					name = L["Reanimated Adherent"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U15",
					scale = 1,
					alpha = 1,
					color = {
						r = 1,
						g = 0.88,
						b = 0.61
					},
				},
				[17] = {
					name = L["Reanimated Fanatic"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U15",
					scale = 1,
					alpha = 1,
					color = {
						r = 1,
						g = 0.88,
						b = 0.61
					},
				},
				[18] = {
					name = L["Bone Spike"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U16",
					scale = 1,
					alpha = 1,
					color = {
						r = 1,
						g = 1,
						b = 1
					},
				},
				[19] = {
					name = L["Onyxian Whelp"],
					showNameplate = false,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U17",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.33,
						g = 0.28,
						b = 0.71
					},
				},
				[20] = {
					name = L["Gas Cloud"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U18",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.96,
						g = 0.56,
						b = 0.07
					},
				},
				[21] = {
					name = L["Volatile Ooze"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U19",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.36,
						g = 0.95,
						b = 0.33
					},
				},
				[22] = {
					name = L["Darnavan"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U20",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.78,
						g = 0.61,
						b = 0.43
					},
				},
				[23] = {
					name = L["Val'kyr Shadowguard"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U21",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.47,
						g = 0.89,
						b = 1
					},
				},
				[24] = {
					name = L["Kinetic Bomb"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U22",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.91,
						g = 0.71,
						b = 0.1
					},
				},
				[25] = {
					name = L["Lich King"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U23",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.77,
						g = 0.12,
						b = 0.23
					},
				},
				[26] = {
					name = L["Raging Spirit"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U24",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.77,
						g = 0.27,
						b = 0
					},
				},
				[27] = {
					name = L["Drudge Ghoul"],
					showNameplate = true,
					showIcon = false,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U25",
					scale = 0.85,
					alpha = 1,
					color = {
						r = 0.43,
						g = 0.43,
						b = 0.43
					},
				},
				[28] = {
					name = L["Living Inferno"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U27",
					scale = 1,
					alpha = 1,
					color = {
						r = 0,
						g = 1,
						b = 0
					},
				},
				[29] = {
					name = L["Living Ember"],
					showNameplate = true,
					showIcon = false,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U28",
					scale = 0.60,
					alpha = 0.75,
					color = {
						r = 0.25,
						g = 0.25,
						b = 0.25
					},
				},
				[30] = {
					name = L["Fanged Pit Viper"],
					showNameplate = false,
					showIcon = false,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "",
					scale = 0,
					alpha = 0,
					color = {
						r = 1,
						g = 1,
						b = 1
					},
				},
				[31] = {
					name = L["Canal Crab"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U29",
					scale = 1,
					alpha = 1,
					color = {
						r = 0,
						g = 1,
						b = 1
					},
				},
				[32] = {
					name = L["Muddy Crawfish"],
					showNameplate = true,
					showIcon = true,
					useStyle = true,
					useColor = true,
					allowMarked = true,
					overrideScale = false,
					overrideAlpha = false,
					icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U30",
					scale = 1,
					alpha = 1,
					color = {
						r = 0.96,
						g = 0.36,
						b = 0.34
					},
				},
				[33] = {},
				[34] = {},
				[35] = {},
				[36] = {},
				[37] = {},
				[38] = {},
				[39] = {},
				[40] = {},
				[41] = {},
				[42] = {},
				[43] = {},
				[44] = {},
				[45] = {},
				[46] = {},
				[47] = {},
				[48] = {},
				[49] = {},
				[50] = {},
				[51] = {},
				[52] = {},
				[53] = {},
				[54] = {},
				[55] = {},
				[56] = {},
				[57] = {},
				[58] = {},
				[59] = {},
				[60] = {},
				[61] = {},
				[62] = {},
				[63] = {},
				[64] = {},
				[65] = {},
				[66] = {},
				[67] = {},
				[68] = {},
				[69] = {},
				[70] = {},
				[71] = {},
				[72] = {},
				[73] = {},
				[74] = {},
				[75] = {},
				[76] = {},
				[77] = {},
				[78] = {},
				[79] = {},
				[80] = {},
			},
			settings = {
				frame = {
					y = 0,
				},
				highlight = {
					texture = "TP_HealthBarHighlight",
				},
				elitehealthborder = {
					texture = "TP_HealthBarEliteOverlay",
					show = true,
				},
				healthborder = {
					texture = "TP_HealthBarOverlay",
					backdrop = "",
					show = true,
				},
				threatborder = {
					show = true,
				},
				healthbar = {
					texture = "ThreatPlatesBar",
				},
				castnostop = {
					texture = "TP_CastBarLock",
					x = 0,
					y = -15,
					show = true,
				},
				castborder = {
					texture = "TP_CastBarOverlay",
					x = 0,
					y = -15,
					show = true,
				},
				castbar = {
					texture = "ThreatPlatesBar",
					x = 0,
					y = -15,
					show = true,
				},
				name = {
					typeface = "Accidental Presidency",
					width = 116,
					height = 14,
					size = 14,
					x = 0,
					y = 13,
					align = "CENTER",
					vertical = "CENTER",
					shadow = true,
					flags = "NONE",
					color = {
						r = 1,
						g = 1,
						b = 1
					},
					show = true,
				},
				level = {
					typeface = "Accidental Presidency",
					size = 12,
					width = 20,
					height = 14,
					x = 50,
					y = 0,
					align = "RIGHT",
					vertical = "TOP",
					shadow = true,
					flags = "NONE",
					show = true,
				},
				eliteicon = {
					show = true,
					theme = "default",
					scale = 15,
					x = 64,
					y = 9,
					level = 22,
					anchor = "CENTER"
				},
				customtext = {
					typeface = "Accidental Presidency",
					size = 12,
					width = 110,
					height = 14,
					x = 0,
					y = 1,
					align = "CENTER",
					vertical = "CENTER",
					shadow = true,
					flags = "NONE",
					show = true,
				},
				spelltext = {
					typeface = "Accidental Presidency",
					size = 12,
					width = 110,
					height = 14,
					x = 0,
					y = -13,
					align = "CENTER",
					vertical = "CENTER",
					shadow = true,
					flags = "NONE",
					show = true,
				},
				raidicon = {
					scale = 20,
					x = 0,
					y = 27,
					anchor = "CENTER",
					hpColor = true,
					show = true,
					hpMarked = {
						["STAR"] = {
							r = 0.85,
							g = 0.81,
							b = 0.27
						},
						["MOON"] = {
							r = 0.60,
							g = 0.75,
							b = 0.85
						},
						["CIRCLE"] = {
							r = 0.93,
							g = 0.51,
							b = 0.06
						},
						["SQUARE"] = {
							r = 0,
							g = 0.64,
							b = 1
						},
						["DIAMOND"] = {
							r = 0.7,
							g = 0.06,
							b = 0.84
						},
						["CROSS"] = {
							r = 0.82,
							g = 0.18,
							b = 0.18
						},
						["TRIANGLE"] = {
							r = 0.14,
							g = 0.66,
							b = 0.14
						},
						["SKULL"] = {
							r = 0.89,
							g = 0.83,
							b = 0.74
						},
					},
				},
				spellicon = {
					scale = 20,
					x = 75,
					y = -7,
					anchor = "CENTER",
					show = true,
				},
				customart = {
					scale = 22,
					x = -74,
					y = -7,
					anchor = "CENTER",
					show = true,
				},
				skullicon = {
					scale = 16,
					x = 55,
					y = 0,
					anchor = "CENTER",
					show = true,
				},
				unique = {
					threatcolor = {
						LOW = {
							r = 0,
							g = 0,
							b = 0,
							a = 0
						},
						MEDIUM = {
							r = 0,
							g = 0,
							b = 0,
							a = 0
						},
						HIGH = {
							r = 0,
							g = 0,
							b = 0,
							a = 0
						},
					},
				},
				totem = {
					threatcolor = {
						LOW = {
							r = 0,
							g = 0,
							b = 0,
							a = 0
						},
						MEDIUM = {
							r = 0,
							g = 0,
							b = 0,
							a = 0
						},
						HIGH = {
							r = 0,
							g = 0,
							b = 0,
							a = 0
						},
					},
				},
				normal = {
					threatcolor = {
						LOW = {
							r = 1,
							g = 1,
							b = 1,
							a = 1
						},
						MEDIUM = {
							r = 1,
							g = 1,
							b = 0,
							a = 1
						},
						HIGH = {
							r = 1,
							g = 0,
							b = 0,
							a = 1
						},
					},
				},
				dps = {
					threatcolor = {
						LOW = {
							r = 0,
							g = 1,
							b = 0,
							a = 1
						},
						MEDIUM = {
							r = 1,
							g = 1,
							b = 0,
							a = 1
						},
						HIGH = {
							r = 1,
							g = 0,
							b = 0,
							a = 1
						},
					},
				},
				tank = {
					threatcolor = {
						LOW = {
							r = 1,
							g = 0,
							b = 0,
							a = 1
						},
						MEDIUM = {
							r = 1,
							g = 1,
							b = 0,
							a = 1
						},
						HIGH = {
							r = 0,
							g = 1,
							b = 0,
							a = 1
						},
					},
				},
			},
			threat = {
				ON = true,
				marked = false,
				nonCombat = true,
				hideNonCombat = false,
				useType = true,
				useScale = true,
				useAlpha = true,
				useHPColor = true,
				art = {
					ON = true,
					theme = "default",
				},
				scaleType = {
					["Normal"] = -0.2,
					["Elite"] = 0,
					["Boss"] = 0.2,
					["Mini"] = -0.2,
				},
				toggle = {
					["Boss"]	= true,
					["Elite"]	= true,
					["Normal"]	= true,
					["Neutral"]	= true,
					["Mini"] 	= true,
					["Tapped"] 	= true
				},
				dps = {
					scale = {
						LOW 		= 0.8,
						MEDIUM		= 0.9,
						HIGH 		= 1.25
					},
					alpha = {
						LOW 		= 1,
						MEDIUM		= 1,
						HIGH 		= 1
					},
				},
				tank = {
					scale = {
						LOW 		= 1.25,
						MEDIUM		= 0.9,
						HIGH 		= 0.8
					},
					alpha = {
						LOW 		= 1,
						MEDIUM		= 0.85,
						HIGH 		= 0.75
					},
				},
				marked = {
					alpha = false,
					art = false,
					scale = false
				},
			},
			nameplate = {
				toggle = {
					["Boss"]	= true,
					["Elite"]	= true,
					["Normal"]	= true,
					["Neutral"]	= true,
					["Mini"]	= true,
					["Tapped"] 	= true,
					["TargetA"]  = false, -- Custom Target Alpha
					["NoTargetA"]  = false, -- Custom Target Alpha
					["TargetS"]  = false, -- Custom Target Scale
					["NoTargetS"]  = false, -- Custom Target Alpha
					["MarkedA"] = false,
					["MarkedS"] = false
				},
				scale = {
					["Target"]		= 1,
					["NoTarget"]	= 1,
					["Totem"]		= 0.75,
					["Boss"]		= 1.1,
					["Elite"]		= 1.04,
					["Normal"]		= 1,
					["Neutral"]		= 0.9,
					["Mini"]	= 0.7,
					["Tapped"] 		= 0.9,
					["Marked"] 		= 1
				},
				alpha = {
					["Target"]		= 1,
					["NoTarget"]	= 1,
					["Totem"]		= 1,
					["Boss"]		= 1,
					["Elite"]		= 1,
					["Normal"]		= 1,
					["Neutral"]		= 1,
					["Mini"]	= 1,
					["Tapped"]		= 1,
					["Marked"] 		= 1
				},
			},
		}
    }
	local db = LibStub('AceDB-3.0'):New('ThreatPlatesDB', defaults, 'Default')
	self.db = db

	local RegisterCallback = db.RegisterCallback

	RegisterCallback(self, 'OnProfileChanged', 'ProfChange')
	RegisterCallback(self, 'OnProfileCopied', 'ProfChange')
	RegisterCallback(self, 'OnProfileReset', 'ProfChange')

	self:SetUpInitialOptions()
end

local function ShowConfigPanel()
	TidyPlatesThreat:OpenOptions()
end
TidyPlatesThreat.ShowConfigPanel = ShowConfigPanel

---------------------------------------------------------------------------------------------------
-- Functions called by TidyPlates
---------------------------------------------------------------------------------------------------

function ActivateTheme()

	-- 	Set aura widget style
	local ProfDB = TidyPlatesThreat.db.profile
	if ProfDB.debuffWidget.style == "square" then
		TidyPlatesWidgets.UseSquareDebuffIcon()
	elseif ProfDB.debuffWidget.style == "wide" then
		TidyPlatesWidgets.UseWideDebuffIcon()
	end

	-- TODO: check with what this  was replaces
	--TidyPlatesUtility:EnableGroupWatcher()
	-- TPHUub: if LocalVars.AdvancedEnableUnitCache then TidyPlatesUtility:EnableUnitCache() else TidyPlatesUtility:DisableUnitCache() end
	-- TPHUub: TidyPlatesUtility:EnableHealerTrack()
	-- if TidyPlatesThreat.db.profile.healerTracker.ON then
	-- 	if not healerTrackerEnabled then
	-- 		TidyPlatesUtility.EnableHealerTrack()
	-- 	end
	-- else
	-- 	if healerTrackerEnabled then
	-- 		TidyPlatesUtility.DisableHealerTrack()
	-- 	end
	-- end
	-- TidyPlatesWidgets:EnableTankWatch()

	TidyPlatesWidgets.SetAuraFilter(AuraFilter)
end

local function OnActivateTheme(themeTable)
	-- Sends a reset notification to all available themes, ie. themeTable == nil
	if not themeTable then
		ThreatPlatesWidgets.DeleteWidgets()
	else
		--CheckTidyPlatesVersion()
		ActivateTheme()
	end
end
TidyPlatesThreat.OnActivateTheme = OnActivateTheme

local function OnChangeProfile(theme, profile)
	if t.AlphaFeatureHeadlineView() then
		if profile then
			TidyPlatesHubFunctions.UseVariables(profile)
			TidyPlates:ForceUpdate()
		end
	end
end
TidyPlatesThreat.OnChangeProfile = OnChangeProfile

-- called by TidyPlatesHub when changes in the options panel were made (CallForStyleUpdate)
local function ApplyProfileSettings(theme, ...)
	TidyPlates:ForceUpdate()
end
TidyPlatesThreat.ApplyProfileSettings = ApplyProfileSettings

------------------
-- ADDON LOADED --
------------------

local function ApplyHubFunctions(theme)
	theme.SetStyle = TidyPlatesThreat.SetStyle
	theme.SetScale = TidyPlatesThreat.SetScale
	theme.SetAlpha = TidyPlatesThreat.SetAlpha
	theme.SetCustomText = TidyPlatesThreat.SetCustomText
	theme.SetNameColor = TidyPlatesThreat.SetNameColor
	theme.SetThreatColor = TidyPlatesThreat.SetThreatColor
	theme.SetCastbarColor = TidyPlatesThreat.SetCastbarColor
	theme.SetHealthbarColor = TidyPlatesThreat.SetHealthbarColor

	-- TidyPlatesGlobal_OnInitialize() is called when a nameplate is created or re-shown
	-- TidyPlatesGlobal_OnUpdate() is called when other data about the unit changes, or is requested by an external controller.
	-- TidyPlatesGlobal_OnContextUpdate() is called when a unit is targeted or moused-over.  (Any time the unitid or GUID changes)
	theme.OnInitialize = ThreatPlatesWidgets.OnInitialize -- Need to provide widget positions
	theme.OnUpdate = ThreatPlatesWidgets.OnUpdate
	theme.OnContextUpdate = ThreatPlatesWidgets.OnContextUpdate

	theme.OnActivateTheme = TidyPlatesThreat.OnActivateTheme -- called by Tidy Plates Core, Theme Loader
	theme.OnChangeProfile = TidyPlatesThreat.OnChangeProfile -- used by TidyPlates when a specialication change occurs or the profile is changed
	theme.ApplyProfileSettings = TidyPlatesThreat.ApplyProfileSettings

	theme.ShowConfigPanel = TidyPlatesThreat.ShowConfigPanel

	return theme
end

-- AceAddon function: Do more initialization here, that really enables the use of your addon.
-- Register Events, Hook functions, Create Frames, Get information from the game that wasn't available in OnInitialize
function TidyPlatesThreat:OnEnable()
	local ProfDB = self.db.profile

	TidyPlatesThemeList[THREAD_PLATES_NAME] = t.Theme
	ApplyHubFunctions(t.Theme)
	ActivateTheme()

	self:StartUp()

	local events = {
		"PLAYER_ALIVE",
		"PLAYER_ENTERING_WORLD",
		"PLAYER_LEAVING_WORLD",
		"PLAYER_LOGIN",
		"PLAYER_LOGOUT",
		--"PLAYER_REGEN_DISABLED",
		"PLAYER_REGEN_ENABLED",
		--"PLAYER_TALENT_UPDATE"
		"UNIT_FACTION",
	}
	for i=1,#events do
		self:RegisterEvent(events[i])
	end
end

function TidyPlatesThreat:StartUp()
	if not self.db.char.welcome then
		self.db.char.welcome = true
		local Welcome = L["|cff89f559Welcome to |rTidy Plates: |cff89f559Threat Plates!\nThis is your first time using Threat Plates and you are a(n):\n|r|cff"]..t.HCC[class]..self:SpecName().." "..UnitClass("player").."|r|cff89F559.|r\n"

		-- initialize roles for all available specs (level > 10) or set to default (dps/healing)
		for index=1, GetNumSpecializations() do
			local id, spec_name, description, icon, background, role = GetSpecializationInfo(index)
			self:SetRole(SPEC_ROLES[t.Class()][index], index)
		end

		t.Print(Welcome..L["|cff89f559You are currently in your "]..self:RoleText()..L["|cff89f559 role.|r"])
		t.Print(L["|cff89f559Additional options can be found by typing |r'/tptp'|cff89F559.|r"])
		if (TidyPlatesOptions.ActiveTheme ~= THREAT_PLATES_NAME) then
			StaticPopup_Show("SetToThreatPlates")
		end
	else
		-- remove (and convert) any old DB entries
		t.CleanupDatabase()

		local GlobDB = self.db.global
		-- TODO: why not just overwrite the old version entry?
		if GlobDB.version ~= tostring(t.Meta("version")) then
			GlobDB.version = tostring(t.Meta("version"))
			GlobDB.versioncheck = false
		end

		--CheckTidyPlatesVersion()
	end

	t.SetThemes(self)
	--t.SetTidyPlatesWidgets(self)
	t.Update()
	-- initialize widgets
	ThreatPlatesWidgets.PrepareFilter()
end

-----------------------------------------------------------------------------------
-- WoW EVENTS --
-----------------------------------------------------------------------------------

local set = false
function TidyPlatesThreat:SetCvars()

	if not set then
		SetCVar("ShowClassColorInNameplate", 1)
		local ProfDB = self.db.profile
		if GetCVar("nameplateShowEnemyTotems") == "1" then
			ProfDB.nameplate.toggle["Totem"] = true
		else
			ProfDB.nameplate.toggle["Totem"] = false
		end

		if GetCVar("ShowVKeyCastbar") == "1" then
			ProfDB.settings.castbar.show = true
		else
			ProfDB.settings.castbar.show = false
		end

		set = true
	end
end

function TidyPlatesThreat:SetGlows()
	local ProfDB = self.db.profile.threat
	-- Required for threat/aggro detection
	if ProfDB.ON and (GetCVar("threatWarning") ~= 3) then
		SetCVar("threatWarning", 3)
	elseif not ProfDB.ON and (GetCVar("threatWarning") ~= 0) then
		SetCVar("threatWarning", 0)
	end
end

function TidyPlatesThreat:PLAYER_ALIVE()

end

function TidyPlatesThreat:PLAYER_ENTERING_WORLD()
	local _,type = IsInInstance()
	local ProfDB = self.db.profile
	if type == "pvp" or type == "arena" then
		ProfDB.OldSetting = ProfDB.threat.ON
		ProfDB.threat.ON = false
	else
		ProfDB.threat.ON = ProfDB.OldSetting
	end

	-- overwrite things TidyPlatesHub does on PLAYER_ENTERING_WORLD
	ActivateTheme()
	--self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
end

function TidyPlatesThreat:PLAYER_LEAVING_WORLD()

end

function TidyPlatesThreat:PLAYER_LOGIN(...)
	self.db.profile.cache = {}
	if self.db.char.welcome and (TidyPlatesOptions.ActiveTheme == THREAT_PLATES_NAME) then
		t.Print(L["|cff89f559Threat Plates:|r Welcome back |cff"]..t.HCC[class]..UnitName("player").."|r!!")
	end
	-- if class == "WARRIOR" or class == "DRUID" or class == "DEATHKNIGHT" or class == "PALADIN" then
	-- 	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
	-- end
end

function TidyPlatesThreat:PLAYER_LOGOUT(...)
	self.db.profile.cache = {}
end

-- Disabled events PLAYER_REGEN_DISABLED, PLAYER_TALENT_UPDATE, UPDATE_SHAPESHIFT_FORM, ACTIVE_TALENT_GROUP_CHANGED
-- as they are not used currently

-- function TidyPlatesThreat:PLAYER_REGEN_DISABLED()
-- 	-- Disabled while 5.4.8 changes are being officilizedself
-- 	--self:SetGlows()
-- end

function TidyPlatesThreat:PLAYER_REGEN_ENABLED()
	self:SetGlows()
	self:SetCvars()
end

 -- nameplate color can change when factions change (e.g., with disguises)
 -- Legion example: Suramar city and Masquerade
function TidyPlatesThreat:UNIT_FACTION(event,unitid)
	TidyPlatesThreat.ApplyProfileSettings()
end

-- function TidyPlatesThreat:PLAYER_TALENT_UPDATE()
-- 	--
-- end

-- function TidyPlatesThreat:UPDATE_SHAPESHIFT_FORM()
-- 	--self.ShapeshiftUpdate()
-- end

-- Fires when the player switches to another specialication or everytime the player changes a talent
-- Completely handled by TidyPlates
-- function TidyPlatesThreat:ACTIVE_TALENT_GROUP_CHANGED()
-- 	if (TidyPlatesOptions.ActiveTheme == THREAT_PLATES_NAME) and self.db.profile.verbose then
-- 		t.Print(L["|cff89F559Threat Plates|r: Player spec change detected: |cff"]..t.HCC[class]..self:SpecName()..L["|r, you are now in your "]..self:RoleText()..L[" role."])
-- 	end
-- end
