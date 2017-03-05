local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local RGB = ThreatPlates.RGB

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
	if db.Enabled and (S == "NameOnly") then

		if unit.reaction == "FRIENDLY" then
			if db.FriendlyTextColorMode == 1 then -- By Custom Color
				color = db.FriendlyTextColor
			elseif db.FriendlyTextColorMode == 2 and unit.type == "PLAYER" then -- By Class
					color = RAID_CLASS_COLORS[unit.class]
			end
		else
			if db.EnemyTextColorMode == 1 then -- By Custom Color
				color = db.EnemyTextColor
			elseif db.EnemyTextColorMode == 2 and unit.type == "PLAYER" then -- By Class
				color = RAID_CLASS_COLORS[unit.class]
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
			color = db.ColorByReaction.Tapped_Unit
		elseif db.HeadlineView.UseRaidMarkColoring and unit.isMarked then
			color = db.settings.raidicon.hpMarked[unit.raidIcon]
		end
	else
		color = TidyPlatesThreat.db.profile.settings.name.color
	end

--	if not color then
--		color = RGB(0, 255, 0)
--	end

	return color.r, color.g, color.b, 1
end

TidyPlatesThreat.SetNameColor = SetNameColor
