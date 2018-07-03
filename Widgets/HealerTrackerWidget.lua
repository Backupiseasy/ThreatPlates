-----------------------
-- Healer Tracker Widget --
-----------------------
local ADDON_NAME, Addon = ...

local Widget = Addon:NewWidget("HealerTracker")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\HealerTrackerWidget\\"
local HEALER_SPECS = {
	"Restoration",
	"Mistweaver",
	"Holy",
	"Discipline"
};

local HEALER_SPELLS = {
    -- Priest
	----------
    [47540] = "PRIEST", -- Penance
    [88625] = "PRIEST", -- Holy Word: Chastise
    [88684] = "PRIEST", -- Holy Word: Serenity
    [88685] = "PRIEST", -- Holy Word: Sanctuary
    [89485] = "PRIEST", -- Inner Focus
    [10060] = "PRIEST", -- Power Infusion
    [33206] = "PRIEST", -- Pain Suppression
    [62618] = "PRIEST", -- Power Word: Barrier
    [724]   = "PRIEST", -- Lightwell
    [14751] = "PRIEST", -- Chakra
    [34861] = "PRIEST", -- Circle of Healing
    [47788] = "PRIEST", -- Guardian Spirit

    -- Druid (The affinity traits on the other specs makes this difficult)
    ---------
    [17116] = "DRUID", -- Nature's Swiftness
    [33891] = "DRUID", -- Tree of Life
	[33763] = "DRUID", -- Lifebloom
	[88423] = "DRUID", -- Nature's Cure
	[102342] = "DRUID", -- Ironbark
	[145205] = "DRUID", -- Efflorescence
	[740] = "DRUID", -- Tranquility

    -- Shaman
	---------
    [17116] = "SHAMAN", -- Nature's Swiftness
    [16190] = "SHAMAN", -- Mana Tide Totem
    [61295] = "SHAMAN", -- Riptide
	[5394] = "SHAMAN", -- Healing Stream Totem
	[1064] = "SHAMAN", -- Chain Heal
	[77130] = "SHAMAN", -- Purify Spirit
	[77472] = "SHAMAN", -- Healing Wave
	[98008] = "SHAMAN", -- Spirit Link Totem

    -- Paladin
	----------
    [20473] = "PALADIN", -- Holy Shock
    [53563] = "PALADIN", -- Beacon of Light
    [31821] = "PALADIN", -- Aura Mastery
    [85222] = "PALADIN", -- Light of Dawn
	[4987] = "PALADIN", -- Cleanse
	[82326] = "PALADIN", -- Holy Light

    -- Monk
	---------
    [115175] = "MONK", -- Soothing Mist
    [115294] = "MONK", -- Mana Tea
    [115310] = "MONK", -- Revival
    [116670] = "MONK", -- Uplift
    [116680] = "MONK", -- Thunder Focus Tea
    [116849] = "MONK", -- Life Cocoon
    [116995] = "MONK", -- Surging mist
    [119611] = "MONK", -- Renewing mist
    [132120] = "MONK", -- Envelopping Mist
};

---------------------------------------------------------------------------------------------------
-- Variables
---------------------------------------------------------------------------------------------------

local healerList = {
	guids = {},
	names = {}
};

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function EnabledInHeadlineView()
	return TidyPlatesThreat.db.profile.healerTracker.ShowInHeadlineView
end

local function UpdateSettings(frame)
    local db = TidyPlatesThreat.db.profile.healerTracker
	local size = db.scale
    local alpha = db.alpha

	frame:SetSize(size, size)
    frame:SetAlpha(alpha);
end

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

--NOTE: used for testing
local function dumpLists()
	print("dumping lists");

	print("name");
	for i, v in ipairs(healerList.names) do
		print(v);
	end;

	print("guid");
	for i, v in ipairs(healerList.guids) do
		print(v);
	end;
end;

local function InsertUnique(list, value)
	for i, v in ipairs(list) do
		--it already exists
		if v == value then
			return;
		end;
	end;

	table.insert(list, value);
end;

local function IsHealerSpec(spec)
	local isHealer = false;

	for i, v in ipairs(HEALER_SPECS) do
		if v == spec then
			isHealer = true;
			break;
		end;
	end;

	return isHealer;
end;

local function IsHealer(guid)
	for i, v in ipairs(healerList.guids) do
		if v == guid then
			return true;
		end;
	end;

	return false;
end;

local nextUpdate = 0;
local function RequestBgScoreData()
	local now = GetTime();

	--throttle update to every 3 seconds
	if now > nextUpdate then
		nextUpdate = now + 3;
	else
		return;
	end;

	RequestBattlefieldScoreData();
end;

--look at the scoreboard and assign healers from there
local function FindHealersInBgScoreboard()
	local scores = GetNumBattlefieldScores();

	for i = 1, scores do
		local name, killingBlows, honorableKills, deaths, honorGained, faction, race, class, classToken, damageDone, healingDone, bgRating, ratingChange, preMatchMMR, mmrChange, talentSpec = GetBattlefieldScore(i);

		if IsHealerSpec(talentSpec) then
			name = string.gsub(name, "-.+", ""); --remove realm part of name
			InsertUnique(healerList.names, name);
		end;
	end;

	--dumpLists();
end;

local SPELL_EVENTS = {
	["SPELL_HEAL"] = true,
	["SPELL_AURA_APPLIED"] = true,
	["SPELL_CAST_START"] = true,
	["SPELL_CAST_SUCCESS"] = true,
	["SPELL_PERIODIC_HEAL"] = true,
};

local function FindHealersViaCombatLog()
	local timestamp, combatevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlag, spellid = CombatLogGetCurrentEventInfo();

	if sourceGUID and sourceName and SPELL_EVENTS[combatevent] and HEALER_SPELLS[spellid] then
		InsertUnique(healerList.guids, sourceGUID);
	end;
end;

local function ResolveName(unit)
	for i, v in ipairs(healerList.names) do
		if v == unit.name then --a healer identified via scoreboard, add it to main guid list
			InsertUnique(healerList.guids, unit.guid);
			return;
		end;
	end;
end;

-- Update Graphics
--Life cycle
local function UpdateWidgetFrame(frame, unit)
    local db = TidyPlatesThreat.db.profile.healerTracker

	RequestBgScoreData();

	--TODO: use inspect api to determine spec if bg score data does not help?

	if unit.type ~= "PLAYER" then
		frame:Hide();
		return;
	end;

	ResolveName(unit);

	frame:SetPoint(db.anchor, frame:GetParent(), db.x, db.y)
	frame.Icon:SetTexture(PATH .. "healer")

	if IsHealer(unit.guid) then --show it
		frame:Show()
	else --hide it
		frame:Hide()
	end;
end

-- Context - GUID or unitid should only change here, i.e., class changes should be determined here
--Life cycle
local function UpdateWidgetContext(frame, unit)
	local guid = unit.guid

	frame.guid = guid
end

--Life cycle
local function ClearWidgetContext(frame)
	local guid = frame.guid

	if guid then
		frame.guid = nil
	end
end

function Widget:UPDATE_BATTLEFIELD_SCORE()
	FindHealersInBgScoreboard();
end;

--triggered when enter and leave instances
function Widget:PLAYER_ENTERING_WORLD()
	healerList.names = table.wipe(healerList.names);
	healerList.guids = table.wipe(healerList.guids);
end;

function Widget:COMBAT_LOG_EVENT_UNFILTERED()
	FindHealersViaCombatLog();
end;

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
    -- Required Widget Code
	local frame = CreateFrame("Frame", nil, tp_frame)
	frame:Hide()

	-- Custom Code III
	--------------------------------------
	frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	frame.Icon:SetAllPoints(frame)

	UpdateSettings(frame)
	frame.UpdateConfig = UpdateSettings
	--------------------------------------
	-- End Custom Code

	-- Required Widget Code
	frame.UpdateContext = UpdateWidgetContext
	frame.Update = UpdateWidgetFrame
	frame._Hide = frame.Hide
	frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end

	return frame
end

function Widget:IsEnabled()
    local enabled = TidyPlatesThreat.db.profile.healerTracker.ON

	if enabled then
		self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	else
		self:UnregisterAllEvents()
	end

	return enabled
end

function Widget:EnabledForStyle(style, unit)

end

function Widget:OnUnitAdded(widget_frame, unit)

end
