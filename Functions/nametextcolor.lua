local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitIsConnected = UnitIsConnected

local RGB = ThreatPlates.RGB
local GetColorByHealthDeficit = ThreatPlates.GetColorByHealthDeficit

local reference = {
	FRIENDLY = { NPC = "FriendlyNPC", PLAYER = "FriendlyPlayer", },
	HOSTILE = {	NPC = "HostileNPC", PLAYER = "HostilePlayer", },
	NEUTRAL = { NPC = "NeutralUnit", PLAYER = "NeutralUnit",	},
}

local function SetNameColor(unit)
	local color

	local db = TidyPlatesThreat.db.profile
	local db_hv = db.HeadlineView

	local style, unique_style = TidyPlatesThreat.SetStyle(unit)
	if db_hv.ON and (style == "NameOnly" or style == "NameOnly-Unique") then
		if unit.unitid and not UnitIsConnected(unit.unitid) then
			color = db.ColorByReaction.DisconnectedUnit
		elseif unit.isTapped then
			color = db.ColorByReaction.TappedUnit
		elseif style == "NameOnly-Unique" then
			if unit.isMarked and unique_style.allowMarked then
				color = db.settings.raidicon.hpMarked[unit.raidIcon]
			elseif unique_style.useColor then
				color = unique_style.color
			end
		elseif style == "NameOnly" then
			if unit.isMarked and db_hv.UseRaidMarkColoring then
				color = db.settings.raidicon.hpMarked[unit.raidIcon]
			end
		end

		local IsFriend = TidyPlatesThreat.IsFriend
		local IsGuildmate = TidyPlatesThreat.IsGuildmate
		local unit_reaction = unit.reaction

		if not color then
			if unit_reaction == "FRIENDLY" then
				if db_hv.FriendlyTextColorMode == "CUSTOM" then -- By Custom Color
					color = db_hv.FriendlyTextColor
				elseif db_hv.FriendlyTextColorMode == "CLASS" and unit.type == "PLAYER" then -- By Class
					local db_social = db.socialWidget
					if db_social.ShowFriendColor and IsFriend(unit) then
						color = db_social.FriendColor
					elseif db_social.ShowGuildmateColor and IsGuildmate(unit) then
						color = db_social.GuildmateColor
					else
						color = RAID_CLASS_COLORS[unit.class]
					end
				elseif db_hv.FriendlyTextColorMode == "HEALTH" then
					color = GetColorByHealthDeficit(unit)
				end
			else
				if db_hv.EnemyTextColorMode == "CUSTOM" then -- By Custom Color
					color = db_hv.EnemyTextColor
				elseif db_hv.EnemyTextColorMode == "CLASS" and unit.type == "PLAYER" then -- By Class
					color = RAID_CLASS_COLORS[unit.class]
				elseif db_hv.EnemyTextColorMode == "HEALTH" then
					color = GetColorByHealthDeficit(unit)
				end
			end
		end

		if not color then -- Default: By Reaction
			if unit_reaction == "FRIENDLY" then
				local db_social = db.socialWidget
				if db_social.ShowFriendColor and IsFriend(unit) then
					color = db_social.FriendColor
				elseif db_social.ShowGuildmateColor and IsGuildmate(unit) then
					color = db_social.GuildmateColor
				else
					color = db.ColorByReaction[reference[unit_reaction][unit.type]]
				end
			else
				color = db.ColorByReaction[reference[unit_reaction][unit.type]]
			end
		end

		-- if no color was found, default back to WoW default colors (based on GetSelectionColor)
		if not color then
			color = { r = unit.red, g = unit.green, b = unit.blue}
		end
	else
		color = db.settings.name.color
	end

	return color.r, color.g, color.b, 1
end

TidyPlatesThreat.SetNameColor = SetNameColor
