local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local RGB = ThreatPlates.RGB
local GetColorByHealthDeficit = TidyPlatesThreat.GetColorByHealthDeficit

local reference = {
	FRIENDLY = { NPC = "FriendlyNPC", PLAYER = "FriendlyPlayer", },
	HOSTILE = {	NPC = "HostileNPC", PLAYER = "HostilePlayer", },
	NEUTRAL = { NPC = "NeutralUnit", PLAYER = "NeutralUnit",	},
}

local function SetNameColor(unit)
	local color
	local S = TidyPlatesThreat.SetStyle(unit)

	-- Headline View (alpha feature) uses TidyPlatesHub config and functionality
	local db = TidyPlatesThreat.db.profile.HeadlineView
	if db.ON and (S == "NameOnly") then

		if unit.reaction == "FRIENDLY" then
			if db.FriendlyTextColorMode == "CUSTOM" then -- By Custom Color
				color = db.FriendlyTextColor
			elseif db.FriendlyTextColorMode == "CLASS" and unit.type == "PLAYER" then -- By Class
				color = RAID_CLASS_COLORS[unit.class]
			elseif db.FriendlyTextColorMode == "HEALTH" then
				color = GetColorByHealthDeficit(unit)
			end
		else
			if db.EnemyTextColorMode == "CUSTOM" then -- By Custom Color
				color = db.EnemyTextColor
			elseif db.EnemyTextColorMode == "CLASS" and unit.type == "PLAYER" then -- By Class
				color = RAID_CLASS_COLORS[unit.class]
			elseif db.EnemyTextColorMode == "HEALTH" then
				color = GetColorByHealthDeficit(unit)
			end
		end

		db = TidyPlatesThreat.db.profile
		if not color then -- Default: By Reaction
			if TidyPlatesUtility.IsFriend(unit.name) or TidyPlatesUtility.IsGuildmate(unit.name) then
				color = db.ColorByReaction.GuildMember
			else
				color = db.ColorByReaction[reference[unit.reaction][unit.type]]
			end
		end

		if unit.isTapped then
			color = db.ColorByReaction.TappedUnit
		elseif db.HeadlineView.UseRaidMarkColoring and unit.isMarked then
			color = db.settings.raidicon.hpMarked[unit.raidIcon]
		end
	else
		color = TidyPlatesThreat.db.profile.settings.name.color
	end

	if not color then
		--ThreatPlates.DEBUG_PRINT_TABLE(unit)
		color = RGB(0, 255, 0)
	end

	return color.r, color.g, color.b, 1
end

TidyPlatesThreat.SetNameColor = SetNameColor
