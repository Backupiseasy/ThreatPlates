local _,ns = ...
local t = ns.ThreatPlates


local isTanked
local reference = {
	["FRIENDLY"] = "fHPbarColor",
	["NEUTRAL"] = "nHPbarColor",
	["TAPPED"] = "tapHPbarColor",
	["HOSTILE"] = "HPbarColor",
	["UNKNOWN"] = "HPbarColor"
}

local function GetMarkedColor(unit,a,var)
	local db = TidyPlatesThreat.db.profile
	local c
	if ((var ~= nil and var == false) or (not db.settings.raidicon.hpColor)) then
		c = a
	else
		c = db.settings.raidicon.hpMarked[unit.raidIcon]
	end
	if c then
		return c
	end
end

local function GetClassColor(unit)
	local db = TidyPlatesThreat.db.profile

	local c, class
	-- if unit.class and (unit.class ~= "UNKNOWN") and (unit.type ~= "NPC") then
	-- (unit.class == nil) if the unit is an NPC (not a player)
	if unit.class and unit.class ~= "" then
		class = unit.class
	elseif db.friendlyClass then
		if unit.guid then
			local _, Class = GetPlayerInfoByGUID(unit.guid)
			if not db.cache[unit.name] then
				if db.cacheClass then
					db.cache[unit.name] = Class
				end
				class = Class
			else
				class = db.cache[unit.name]
			end
		end
	end
	if class then
		c = RAID_CLASS_COLORS[class]
	end
	return c
end

local CS = CreateFrame("ColorSelect")

function CS:GetSmudgeColorRGB(colorA, colorB, perc)
	self:SetColorRGB(colorA.r,colorA.g,colorA.b)
	local h1, s1, v1 = self:GetColorHSV()
	self:SetColorRGB(colorB.r,colorB.g,colorB.b)
	local h2, s2, v2 = self:GetColorHSV()
	local h3 = floor(h1-(h1-h2)*perc)
	if abs(h1-h2) > 180 then
        local radius = (360-abs(h1-h2))*perc/100
		if h1 < h2 then
			h3 = floor(h1-radius)
			if h3 < 0 then
				h3 = 360+h3
			end
        else
			h3 = floor(h1+radius)
			if h3 > 360 then
				h3 = h3-360
			end
        end
    end
    local s3 = s1-(s1-s2)*perc
    local v3 = v1-(v1-v2)*perc
    self:SetColorHSV(h3, s3, v3)
    local r,g,b = self:GetColorRGB()
    return r,g,b
end

local function GetThreatColor(unit,style)
	local db = TidyPlatesThreat.db.profile
	local c
	if (db.threat.ON and db.threat.useHPColor and InCombatLockdown() and (style == "dps" or style == "tank")) then
		if not isTanked then -- This value is going to be determined in the SetStyles function.
			if db.threat.nonCombat then
				if (unit.isInCombat or (unit.health < unit.healthmax)) then
					c = db.settings[style].threatcolor[unit.threatSituation]
				else
					c = GetClassColor(unit)
				end
			else
				c = db.settings[style].threatcolor[unit.threatSituation]
			end
		else
			c = db.tHPbarColor
		end
	else -- this branch should not be nesssary as
		c = GetClassColor(unit)
	end
	return c
end

local function SetHealthbarColor(unit)
	local db = TidyPlatesThreat.db.profile
	local style = TidyPlatesThreat.SetStyle(unit)

	-- if unit.isTarget then
	-- 	t.DEBUG("unit.name = ", unit.name)
	-- 	t.DEBUG("unit.type = ", unit.type)
	-- 	t.DEBUG("unit.class = ", unit.class)
	-- 	t.DEBUG("unit.reaction = ", unit.reaction)
	-- 	t.DEBUG("unit.isMini = ", unit.isMini)
	-- 	t.DEBUG("unit.isTapped = ", unit.isTapped)
	-- 	t.DEBUG("unit SetStyle = ", style)
	-- 	t.DEBUG("unit GetType = ", TidyPlatesThreat.GetType(unit))
	-- end

	local c, allowMarked
	if style == "totem" then
		local tS = db.totemSettings[ThreatPlates_Totems[unit.name]]
		if tS[2] then
			c = tS.color
		end
	elseif style == "unique" then
		for k_c,k_v in pairs(db.uniqueSettings.list) do
			if k_v == unit.name then
				local u = db.uniqueSettings[k_c]
				allowMarked = u.allowMarked
				if u.useColor then
					c = u.color
				else
					c = GetThreatColor(unit,style)
				end
			end
		end
	else
		if db.healthColorChange then  -- Prio 2: coloring by HP (prio 1 is raid marks)
			local pct = unit.health / unit.healthmax
			local r,g,b = CS:GetSmudgeColorRGB(db.aHPbarColor,db.bHPbarColor,pct)
			c = {r = r,g = g, b = b}
		else
			if db.customColor then  -- Prio 5: coloring by custom color
				if (db.threat.ON and db.threat.useHPColor and InCombatLockdown() and (style == "dps" or style == "tank")) then -- Need a better way to impliment this.
					c = GetThreatColor(unit,style)
				else
					if unit.isTapped then
						c = db[reference["TAPPED"]]
					else
						c = db[reference[unit.reaction]]
					end
				end
			else -- Prio 4: coloring by threat, color by HP amount and class colors overwrite this
				c = GetThreatColor (unit, style)
			end

			-- player healthbars may be colored by class overwriting any customColor, but not healthColorChange
			if unit.type == "PLAYER" then -- Prio 3: coloring by class
				if unit.reaction == "HOSTILE" and db.allowClass then
					c = GetClassColor(unit)
				elseif unit.reaction == "FRIENDLY" and db.friendlyClass then
					c = GetClassColor(unit)
				end
			end
		end
	end

	if unit.isMarked then -- Prio 1 - raid marks always take top priority
		c = GetMarkedColor(unit,c,allowMarked) -- c will set itself back to c if marked color is disabled
	end

	if c then
		return c.r, c.g, c.b
	else
		return unit.red, unit.green, unit.blue -- should return Blizzard default oclors (based on GetSelectionColor)
	end
end

TidyPlatesThreat.SetHealthbarColor = SetHealthbarColor
