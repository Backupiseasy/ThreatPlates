local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local RGB = ThreatPlates.RGB
local RGB_P = ThreatPlates.RGB_P
local COLOR_DC = ThreatPlates.COLOR_DC

local reference = {
  FRIENDLY = { NPC = "FriendlyNPC", PLAYER = "FriendlyPlayer", },
  HOSTILE = {	NPC = "HostileNPC", PLAYER = "HostilePlayer", },
  NEUTRAL = { NPC = "NeutralUnit", PLAYER = "NeutralUnit",	},
}

function ThreatPlates_IsTapDenied(unitid)
  --return frame.optionTable.greyOutWhenTapDenied and not UnitPlayerControlled(frame.unit) and UnitIsTapDenied(frame.unit);
  return not UnitPlayerControlled(unitid) and UnitIsTapDenied(unitid)
end

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

  -- return nil if class coloring is disabled
  -- if (unit.reaction == "HOSTILE" and not db.allowClass) or (unit.reaction == "FRIENDLY" and not db.friendlyClass) then
  -- 	return nil
  -- end

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


local function GetColorByHealthDeficit(unit)
  local db = TidyPlatesThreat.db.profile
  local pct = unit.health / unit.healthmax
  local r, g, b = CS:GetSmudgeColorRGB(db.aHPbarColor, db.bHPbarColor, pct)
  return RGB_P(r, g, b, 1)
end

local function UnitIsOffTanked(unit)
  local unitid = unit.unitid

  if unitid then
    local targetOf = unitid.."target"
    local targetIsTank = UnitIsUnit(targetOf, "pet") or ("TANK" == UnitGroupRolesAssigned(targetOf))

    if targetIsTank and unit.threatValue < 2 then
      return true
    end
  end

  return false
end

local function GetThreatColor(unit,style)
  local db = TidyPlatesThreat.db.profile
  local c
  -- style is normal for PLAYERS, only NPCs get tank/dps
  if (db.threat.ON and db.threat.useHPColor and InCombatLockdown() and (style == "dps" or style == "tank")) then

    local show_offtank = db.threat.toggle.OffTank
    if db.threat.nonCombat then
      --if (unit.isInCombat or (unit.health < unit.healthmax)) then
      if unit.threatValue > 0 then -- new
        local threatSituation = unit.threatSituation
        if style == "tank" and show_offtank and UnitIsOffTanked(unit) then
          threatSituation = "OFFTANK"
        end
        c = db.settings[style].threatcolor[threatSituation]
      else -- not sure, wenn this branch is used
        c = GetClassColor(unit)
      end
    else
      local threatSituation = unit.threatSituation
      if style == "tank" and show_offtank and UnitIsOffTanked(unit) then
        threatSituation = "OFFTANK"
      end
      c = db.settings[style].threatcolor[threatSituation]
    end
--	else
--		c = GetClassColor(unit)
  end
  return c
end

local function SetHealthbarColor(unit)

  local db = TidyPlatesThreat.db.profile
	local style, unique_style = TidyPlatesThreat.SetStyle(unit)

  local c, allowMarked
  if unit.unitid and not UnitIsConnected(unit.unitid) then
    -- disconnected unit: gray
    c = COLOR_DC
  elseif style == "totem" then
    local tS = db.totemSettings[ThreatPlates_Totems[unit.name]]
    if tS[2] then
      c = tS.color
    end
  elseif style == "unique" then
		allowMarked = unique_style.allowMarked
		if unique_style.UseThreatColor and InCombatLockdown() then
			c = GetThreatColor(unit, TidyPlatesThreat.GetThreatStyle(unit))
		elseif unique_style.useColor then
			c = unique_style.color
		end
		if not c then
			-- player healthbars may be colored by class overwriting any customColor, but not healthColorChange
			if unit.type == "PLAYER" then -- Prio 3: coloring by class
				if unit.reaction == "HOSTILE" and db.allowClass then
					c = GetClassColor(unit)
				elseif unit.reaction == "FRIENDLY" and db.friendlyClass then
					c = GetClassColor(unit)
				end
			end
		end
  else
    if db.healthColorChange then  -- Prio 2: coloring by HP (prio 1 is raid marks) - no other stuff applies
      local pct = unit.health / unit.healthmax
      local r,g,b = CS:GetSmudgeColorRGB(db.aHPbarColor,db.bHPbarColor,pct)
      c = {r = r,g = g, b = b}
    else
      if unit.isTapped then --and (not db.threat.nonCombat or unit.threatValue > 0) then
        c = db.ColorByReaction.TappedUnit
      elseif (db.threat.ON and db.threat.useHPColor and InCombatLockdown() and (style == "dps" or style == "tank")) then -- Need a better way to impliment this.
        c = GetThreatColor(unit,style)

        if not c then -- currently here because nonCombat = false may result in an nil color which defaults (later) to standard WoW Colors, not ColorByReaction, as it should
          c = db.ColorByReaction[reference[unit.reaction][unit.type]]
        end
      else
        -- player healthbars may be colored by class overwriting any customColor, but not healthColorChange
        if unit.type == "PLAYER" then -- Prio 3: coloring bym class
          if unit.reaction == "HOSTILE" and db.allowClass then
            c = GetClassColor(unit)
          elseif unit.reaction == "FRIENDLY" then
            if db.socialWidget.ShowFriendColor and TidyPlatesThreat.IsFriend(unit) then
              c = db.socialWidget.FriendColor
            elseif db.socialWidget.ShowGuildmateColor and TidyPlatesThreat.IsGuildmate(unit) then
              c = db.socialWidget.GuildmateColor
            elseif db.friendlyClass then
              c = GetClassColor(unit)
            else
              c = db.ColorByReaction[reference[unit.reaction][unit.type]]
            end
          else
            c = db.ColorByReaction[reference[unit.reaction][unit.type]]
          end
        else
          c = db.ColorByReaction[reference[unit.reaction][unit.type]]
        end
      end
    end
  end

  -- quest widget color overwrites everything (Color by Health, Color by Reaction, totem, unique)
  if db.questWidget.ModeHPBar and TidyPlatesThreat.ShowQuestUnit(unit) and TidyPlatesThreat.IsQuestUnit(unit) then
    c = db.questWidget.HPBarColor
  end

  -- raid mark color overwrites everything (Color by Health, Color by Reaction, also quest widget color)
  if unit.isMarked then -- Prio 1 - raid marks always take top priority
    c = GetMarkedColor(unit,c,allowMarked) -- c will set itself back to c if marked color is disabled
  end

  if not c then
    c = {r = unit.red, g = unit.green, b = unit.blue }  -- should return Blizzard default oclors (based on GetSelectionColor)
  end

  -- set background color for healthbar
  local db_healthbar = db.settings.healthbar
  local bc = c
  if not db_healthbar.BackgroundUseForegroundColor then
    bc = db_healthbar.BackgroundColor
  end

  return c.r, c.g, c.b, nil, bc.r, bc.g, bc.b, db_healthbar.BackgroundOpacity

  --	if c then
  --	else
  --		return c.r, c.g, c.b, nil, bc.r, bc.g, bc.b, db.settings.healthbar.BackgroundOpacity
  --		return unit.red, unit.green, unit.blue, nil, bc.r, bc.g, bc.b, db.settings.healthbar.BackgroundOpacity -- should return Blizzard default oclors (based on GetSelectionColor)
  --	end
end

TidyPlatesThreat.GetColorByHealthDeficit = GetColorByHealthDeficit
TidyPlatesThreat.SetHealthbarColor = SetHealthbarColor
TidyPlatesThreat.UnitIsOffTanked = UnitIsOffTanked
