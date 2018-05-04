local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

------------------------
-- Social Icon Widget --
------------------------
-- This widget is designed to show a single icon to display the relationship of a player's nameplate by name (regardless of faction if a bnet friend).
-- To-Do:
-- Possibly change the method to show 3 icons.
-- Change the 'guildicon' to use the emblem and border method used by blizzard frames.

-- TODO: Possible optimizations
--   * Update icons only if the unit changed since last update (or a guild/friend/Bnet friend update happend, as, e.g., someone may have been removed from the guild roster, or a configuration update)

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local type, strsplit = type, strsplit

-- WoW APIs
local WorldFrame, CreateFrame = WorldFrame, CreateFrame
local GetNumGuildMembers, GetGuildRosterInfo = GetNumGuildMembers, GetGuildRosterInfo
local GetNumFriends, GetFriendInfo = GetNumFriends, GetFriendInfo
local BNGetNumFriends, BNGetFriendInfo, BNGetToonInfo = BNGetNumFriends, BNGetFriendInfo, BNGetToonInfo
local GetUnitName, UnitGUID, UnitFactionGroup = GetUnitName, UnitGUID, UnitFactionGroup

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\SocialWidget\\"
local ICON_FRIEND = PATH .. "friendicon"
local ICON_GUILDMATE = PATH .. "guildicon"
local ICON_BNET_FRIEND = "Interface\\FriendsFrame\\PlusManz-BattleNet"
local ICON_FACTION_HORDE = PATH .. "hordeicon" -- "Interface\\ICONS\\inv_bannerpvp_01"
local ICON_FACTION_ALLIANCE = PATH .. "allianceicon" -- "Interface\\ICONS\\inv_bannerpvp_02",

-- local WidgetList = {}
local WatcherIsEnabled = false
local ListGuildMembers = {}
local ListFriends = {}
local ListBnetFriends = {}
local ListGuildMembersSize, ListFriendsSize, ListBnetFriendsSize = 0, 0, 0

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
-- 	for _, widget in pairs(WidgetList) do
-- 		widget:Hide()
-- 	end
-- 	WidgetList = {}
-- end
-- ThreatPlatesWidgets.ClearAllSocialWidgets = ClearAllWidgets

local function UpdateGuildMembers(numOnlineGuildMembers)
  -- Only wipe the guild member list if a member went offline
  if numOnlineGuildMembers < ListGuildMembersSize then
    ListGuildMembers = {}
  end

	for i = 1, numOnlineGuildMembers do
		local name, _ = GetGuildRosterInfo(i)
    ListGuildMembers[name] = ICON_GUILDMATE
  end

  ListGuildMembersSize = numOnlineGuildMembers
end

local function UpdateFriends(friendsOnline)
  -- Only wipe the friend list if a member went offline
  if friendsOnline < ListFriendsSize then
    ListFriends = {}
  end

	for i = 1, friendsOnline do
		local name, _ = GetFriendInfo(i)
    ListFriends[name] = ICON_FRIEND
  end

  ListFriendsSize = friendsOnline
end

local function UpdateBnetFriends(BnetOnline)
  -- Only wipe the Bnet friend list if a member went offline
  if BnetOnline < ListBnetFriendsSize then
    ListBnetFriends = {}
  end

	for i = 1, BnetOnline do
		local _, _, _, _, toonID, client, isOnline, _, _, _, _, _, _, _ = BNGetFriendInfo(i)
		if isOnline and toonID and client == "WoW" then
			local _, name = BNGetToonInfo(toonID)
      ListBnetFriends[name] = ICON_BNET_FRIEND
		end
  end

  ListBnetFriendsSize = BnetOnline
end

-- Watcher Frame
local WatcherFrame = CreateFrame("Frame", nil, WorldFrame)

local function WatcherFrameHandler(frame, event, ...)
  if event == "GUILD_ROSTER_UPDATE" then
    local _, numOnlineGuildMembers, _ = GetNumGuildMembers()
    if ListGuildMembersSize ~= numOnlineGuildMembers then
      UpdateGuildMembers(numOnlineGuildMembers)
    end
  elseif event == "BN_FRIEND_TOON_ONLINE" then
    local toon_id = ...
    local _, name = BNGetToonInfo(toon_id)
    ListBnetFriends[name] = ICON_BNET_FRIEND
  elseif event == "BN_FRIEND_TOON_OFFLINE" then
    local toon_id = ...
    local _, name = BNGetToonInfo(toon_id)
    ListBnetFriends[name] = nil
	elseif event == "FRIENDLIST_UPDATE" then
    -- First check if there was actually a change to the friend list (event fires for other reasons too)
    local _, friendsOnline = GetNumFriends()
    if ListFriendsSize ~= friendsOnline then
      UpdateFriends(friendsOnline)
    end
  elseif event == "BN_CONNECTED" then
    local _, BnetOnline = BNGetNumFriends()
    if ListBnetFriendsSize ~= BnetOnline then
      UpdateBnetFriends(BnetOnline)
    end
  end
  --	elseif event == "BN_FRIEND_LIST_SIZE_CHANGED" or event == "BN_CONNECTED" or
  --         event == "BN_FRIEND_ACCOUNT_ONLINE" or event == "BN_FRIEND_ACCOUNT_OFFLINE" then
end

local function EnableWatcher()
  --WatcherFrameHandler(nil, "GUILD_ROSTER_UPDATE") -- is called after login automatically
  WatcherFrameHandler(nil, "FRIENDLIST_UPDATE")
  WatcherFrameHandler(nil, "BN_CONNECTED")

--  local _, numOnlineGuildMembers, _ = GetNumGuildMembers()
--	UpdateGlist(numOnlineGuildMembers)
--
--  local _, friendsOnline = GetNumFriends()
--	UpdateFlist(friendsOnline)
--
--  local _, BnetOnline = BNGetNumFriends()
--	UpdateBnetList(BnetOnline)

	WatcherFrame:SetScript("OnEvent", WatcherFrameHandler)

	WatcherFrame:RegisterEvent("FRIENDLIST_UPDATE")
	WatcherFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
	WatcherFrame:RegisterEvent("BN_CONNECTED")
  WatcherFrame:RegisterEvent("BN_FRIEND_TOON_ONLINE")
  WatcherFrame:RegisterEvent("BN_FRIEND_TOON_OFFLINE")
  --WatcherFrame:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
  --WatcherFrame:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
  --WatcherFrame:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED")

	WatcherIsEnabled = true
end

local function DisableWatcher()
	WatcherFrame:UnregisterAllEvents()
	WatcherFrame:SetScript("OnEvent", nil)
	WatcherIsEnabled = false
end

local function enabled()
	local db = TidyPlatesThreat.db.profile.socialWidget

	if not (db.ON or db.ShowInHeadlineView) then
    if WatcherIsEnabled then	DisableWatcher()	end
  else
    if not WatcherIsEnabled then	EnableWatcher() end
  end

	return db.ON
end

local function EnabledInHeadlineView()
	return TidyPlatesThreat.db.profile.socialWidget.ShowInHeadlineView
end

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

-- Update all non-unit or style dependent settings
local function UpdateSettings(frame)
  local db = TidyPlatesThreat.db.profile.socialWidget
  frame.Icon:SetSize(db.scale, db.scale)

  db = TidyPlatesThreat.db.profile.FactionWidget
  frame.FactionIcon:SetSize(db.scale, db.scale)
end

local function UpdateWidgetFrame(frame, unit)
  if unit.type ~= "PLAYER" or not unit.unitid then
    frame:_Hide()
    return
  end

  local name = GetUnitName(unit.unitid, true)

  --  if unit.isTarget and not ListFriends[name] then
--    ListFriends[name] = ICON_FRIEND
--  end

	-- I will probably expand this to a table with 'friend = true','guild = true', and 'bnet = true' and have 3 textuers show.
  local db = TidyPlatesThreat.db.profile.socialWidget
  local friend_texture = db.ShowFriendIcon and (ListFriends[name] or ListBnetFriends[name] or ListGuildMembers[name])

  local faction_texture
	if db.ShowFactionIcon then
    -- faction can be nil, e.g., for Pandarians that not yet have choosen a faction
    local faction = UnitFactionGroup(unit.unitid)
    if faction == "Horde" then
      faction_texture = ICON_FACTION_HORDE
    elseif faction == "Alliance" then
      faction_texture = ICON_FACTION_ALLIANCE
    end
	end

  if not (friend_texture or faction_texture) then
    frame:_Hide()
    return
  end

  local x, y
  local name_style = unit.TP_Style == "NameOnly" or unit.TP_Style == "NameOnly-Unique"
  local icon = frame.Icon
  if friend_texture then
    -- db = TidyPlatesThreat.db.profile.socialWidget
    if name_style then
      x, y = db.x_hv, db.y_hv
    else
      x, y = db.x, db.y
    end
    icon:SetPoint("CENTER", frame:GetParent(), x, y)
    icon:SetTexture(friend_texture)
    icon:Show()
  else
    icon:Hide()
  end

  icon = frame.FactionIcon
  if faction_texture then
    -- apply settings to faction icon
    db = TidyPlatesThreat.db.profile.FactionWidget
    if name_style then
      x, y = db.x_hv, db.y_hv
    else
      x, y = db.x, db.y
    end
    icon:SetPoint("CENTER", frame:GetParent(), x, y)
    icon:SetTexture(faction_texture)
    icon:Show()
  else
    icon:Hide()
  end

  frame:Show()
end

-- Context
local function UpdateWidgetContext(frame, unit)
	local guid = unit.guid
	frame.guid = guid

	-- Add to Widget List
	-- if guid then
	-- 	WidgetList[guid] = frame
	-- end

	-- Custom Code II
	--------------------------------------
	if UnitGUID("target") == guid then
		UpdateWidgetFrame(frame, unit)
	else
		frame:_Hide()
	end
	--------------------------------------
	-- End Custom Code
end

local function ClearWidgetContext(frame)
	local guid = frame.guid
	if guid then
		-- WidgetList[guid] = nil
		frame.guid = nil
	end
end

local function CreateWidgetFrame(parent)
	-- Required Widget Code
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()

	-- Custom Code III
	--------------------------------------
  frame:SetSize(32, 32)
  frame:SetFrameLevel(parent:GetFrameLevel() + 7)
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	frame.FactionIcon = frame:CreateTexture(nil, "OVERLAY")

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

local function IsFriend(unit)
  local name = GetUnitName(unit.unitid, true)
  return enabled() and (ListFriends[name] or ListBnetFriends[name])
end

local function IsGuildmate(unit)
  return enabled() and ListGuildMembers[GetUnitName(unit.unitid, true)]
end

ThreatPlates.IsFriend = IsFriend
ThreatPlates.IsGuildmate = IsGuildmate

ThreatPlatesWidgets.RegisterWidget("SocialWidgetTPTP", CreateWidgetFrame, false, enabled, EnabledInHeadlineView)
ThreatPlatesWidgets.SocialWidgetDisableWatcher = DisableWatcher
