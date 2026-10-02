---------------------------------------------------------------------------------------------------
-- Social Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = Addon.Widgets:NewWidget("Social")

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

-- WoW APIs
local GetNumGuildMembers, GetGuildRosterInfo = GetNumGuildMembers, GetGuildRosterInfo
local BNET_CLIENT_WOW = BNET_CLIENT_WOW
local UnitFactionGroup = UnitFactionGroup
local C_FriendList_ShowFriends, C_FriendList_GetNumOnlineFriends = C_FriendList.ShowFriends, C_FriendList.GetNumOnlineFriends
local C_FriendList_GetFriendInfoByIndex = C_FriendList.GetFriendInfoByIndex
-- C_BattleNet is available on all supported clients (it replaced BNGetFriendInfo, which no longer exists on
-- clients with a modern engine like WoW Forever, with BfA - Patch 8.2.5).
local C_BattleNet_GetFriendAccountInfo = C_BattleNet.GetFriendAccountInfo

-- ThreatPlates APIs
local IsSecretValueTP = Addon.IsSecretValue

-- All lists are indexed by the GUID of the player, not by its name: the format of names differs between
-- clients and APIs (realm suffix, surnames on WoW Forever, ...).
local ListGuildMembers = {}
local ListFriends = {}
local ListBnetFriends = {}
local ListGuildMembersSize, ListFriendsSize = 0, 0

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: BNGetNumFriends

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local Settings, SettingsFaction
local PlateColorEnabled = {}

---------------------------------------------------------------------------------------------------
-- Social Widget Functions
---------------------------------------------------------------------------------------------------

-- Returns the GUID, if it can be used as key for the lists above. unit.guid can be a secret value in restricted
-- contexts (e.g., for hostile players in Arenas/Battlegrounds).
local function GetListKey(guid)
  if not guid or IsSecretValueTP(guid) then
    return nil
  end

  return guid
end

function Widget:FRIENDLIST_UPDATE()
  -- First check if there was actually a change to the friend list (event fires for other reasons too)
  local friendsOnline = C_FriendList_GetNumOnlineFriends()

  if ListFriendsSize ~= friendsOnline then
    -- Only wipe the friend list if a member went offline
    if friendsOnline < ListFriendsSize then
      ListFriends = {}
    end

    local no_friends = 0
    for i = 1, friendsOnline do
      local friend_info = C_FriendList_GetFriendInfoByIndex(i)
      local guid = friend_info and GetListKey(friend_info.guid)
      if guid then
        ListFriends[guid] = "Social.Friend"
        no_friends = no_friends + 1
      end
    end

    ListFriendsSize = no_friends -- as guid might be nil, friendsOnline might not be correct here

    self:UpdateAllFramesWithPublish("ClassColorUpdate")
  end
end

function Widget:GUILD_ROSTER_UPDATE()
  local numTotalGuildMembers, _, _ = GetNumGuildMembers()
  if ListGuildMembersSize ~= numTotalGuildMembers then
    -- Only wipe the guild member list if a member went offline
    if numTotalGuildMembers < ListGuildMembersSize then
      ListGuildMembers = {}
    end

    local no_guild_members_with_info = 0
    for i = 1, numTotalGuildMembers do
      -- name, rank, rankIndex, level, classDisplayName, zone, note, officernote, isOnline, ..., guid
      local guid = GetListKey(select(17, GetGuildRosterInfo(i)))
      if guid then
        ListGuildMembers[guid] = "Social.GuildMember"
        no_guild_members_with_info = no_guild_members_with_info + 1
      end
    end

    ListGuildMembersSize = no_guild_members_with_info

    self:UpdateAllFramesWithPublish("ClassColorUpdate")
  end
end

-- The list is always rebuilt completely as information about the character of a friend is no longer available
-- after he went offline.
local function UpdateBnetFriends()
  ListBnetFriends = {}

  local _, no_friends_online = _G.BNGetNumFriends()
  for i = 1, no_friends_online do
    local account_info = C_BattleNet_GetFriendAccountInfo(i)
    local game_account_info = account_info and account_info.gameAccountInfo

    if game_account_info and game_account_info.isOnline and game_account_info.clientProgram == BNET_CLIENT_WOW then
      local guid = GetListKey(game_account_info.playerGuid)
      if guid then
        ListBnetFriends[guid] = "Social.BattleNetFriend"
      end
    end
  end
end

function Widget:BN_CONNECTED()
  UpdateBnetFriends()
  self:UpdateAllFramesWithPublish("ClassColorUpdate")
end

Widget.BN_FRIEND_ACCOUNT_ONLINE = Widget.BN_CONNECTED
Widget.BN_FRIEND_ACCOUNT_OFFLINE = Widget.BN_CONNECTED

function Addon:IsFriend(unit, plate_style)
  local guid = GetListKey(unit.guid)
  return guid and PlateColorEnabled[plate_style] and (ListFriends[guid] or ListBnetFriends[guid])
end

function Addon:IsGuildmate(unit, plate_style)
  local guid = GetListKey(unit.guid)
  return guid and PlateColorEnabled[plate_style] and ListGuildMembers[guid]
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = _G.CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code III
  --------------------------------------
  widget_frame:SetSize(32, 32)
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
  widget_frame.Icon = widget_frame:CreateTexture(nil, "OVERLAY")
  widget_frame.FactionIcon = widget_frame:CreateTexture(nil, "OVERLAY")

  --------------------------------------
  -- End Custom Code
  return widget_frame
end

function Widget:IsEnabled()
  local db = Addon.db.profile.socialWidget
  return (db.ON or db.ShowInHeadlineView) and
         (db.ShowFriendIcon or db.ShowFriendColor or db.ShowGuildmateColor or db.ShowFactionIcon)
end

function Widget:OnEnable()
  local db = Addon.db.profile.socialWidget
  if db.ShowFriendIcon or db.ShowFriendColor or db.ShowGuildmateColor then
    self:SubscribeEvent("FRIENDLIST_UPDATE")
    self:SubscribeEvent("GUILD_ROSTER_UPDATE")
    self:SubscribeEvent("BN_CONNECTED")
    self:SubscribeEvent("BN_FRIEND_ACCOUNT_ONLINE")
    self:SubscribeEvent("BN_FRIEND_ACCOUNT_OFFLINE")
    --Widget:SubscribeEvent("BN_FRIEND_LIST_SIZE_CHANGED", EventHandler)

    --self:FRIENDLIST_UPDATE()
    C_FriendList_ShowFriends() -- Will fire FRIENDLIST_UPDATE
    self:BN_CONNECTED()
    --self:GUILD_ROSTER_UPDATE() -- called automatically by game
  else
    self:UnsubscribeAllEvents()
  end
end

-- function Widget:OnDisable()
--   self:UnsubscribeAllEvents()
-- end

function Widget:EnabledForStyle(style, unit)
  if unit.type ~= "PLAYER" then return false end

  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return Addon.db.profile.socialWidget.ShowInHeadlineView
  elseif style ~= "etotem" then
    return Addon.db.profile.socialWidget.ON
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  widget_frame.Icon:SetSize(Settings.scale, Settings.scale)

  widget_frame.FactionIcon:SetSize(SettingsFaction.scale, SettingsFaction.scale)

  self:UpdateFrame(widget_frame, unit)
end

function Widget:UpdateFrame(widget_frame, unit)
  -- I will probably expand this to a table with 'friend = true','guild = true', and 'bnet = true' and have 3 textuers show.
  local db = Addon.db.profile.socialWidget

  local faction_texture
  if db.ShowFactionIcon then
    -- faction can be nil, e.g., for Pandarians that not yet have chosen a faction
    local faction = UnitFactionGroup(unit.unitid)
    faction_texture = faction and ("Social.".. faction) or nil
  end

  -- I will probably expand this to a table with 'friend = true','guild = true', and 'bnet = true' and have 3 textuers show.
  local guid = GetListKey(unit.guid)
  local friend_texture = Settings.ShowFriendIcon and guid
    and (ListFriends[guid] or ListBnetFriends[guid] or ListGuildMembers[guid])

  -- Need to hide the frame here as it may have been shown before
  if not (friend_texture or faction_texture) then
    widget_frame:Hide()
    return
  end

  local name_style = unit.style == "NameOnly" or unit.style == "NameOnly-Unique"

  local icon = widget_frame.Icon
  if friend_texture then
    -- db = Addon.db.profile.socialWidget
    if name_style then
      icon:SetPoint("CENTER", widget_frame:GetParent(), Settings.x_hv, Settings.y_hv)
    else
      icon:SetPoint("CENTER", widget_frame:GetParent(), Settings.x, Settings.y)
    end
    Addon:SetIconTexture(icon, friend_texture, unit.unitid)

    icon:Show()
  else
    icon:Hide()
  end

  icon = widget_frame.FactionIcon
  if faction_texture then
    -- apply settings to faction icon
    if name_style then
      icon:SetPoint("CENTER", widget_frame:GetParent(), SettingsFaction.x_hv, SettingsFaction.y_hv)
    else
      icon:SetPoint("CENTER", widget_frame:GetParent(), SettingsFaction.x, SettingsFaction.y)
    end
    Addon:SetIconTexture(icon, faction_texture, unit.unitid)

    icon:Show()
  else
    icon:Hide()
  end

  widget_frame:Show()
end

function Widget:UpdateSettings()
  Settings = Addon.db.profile.socialWidget
  SettingsFaction = Addon.db.profile.FactionWidget

  PlateColorEnabled["HealthbarMode"] = Settings.ON
  PlateColorEnabled["NameMode"] = Settings.ShowInHeadlineView
end

function Widget:PrintDebug()
  Addon.Logging.Debug("BNet Friends:")
  local _, no_friends_online = _G.BNGetNumFriends()
  for i = 1, no_friends_online do
    local account_info = C_BattleNet_GetFriendAccountInfo(i)
    local game_account_info = account_info and account_info.gameAccountInfo
    if game_account_info then
      Addon.Logging.Debug("  " .. tostring(i) .. ":", game_account_info.clientProgram, game_account_info.characterName, game_account_info.realmName, game_account_info.isOnline, game_account_info.playerGuid)
    end
  end

  for list_name, list in pairs({ ["BNet Friends"] = ListBnetFriends, Friends = ListFriends, ["Guild Members"] = ListGuildMembers }) do
    local size = 0
    for _ in pairs(list) do size = size + 1 end
    Addon.Logging.Debug("List " .. list_name .. ":", size)
  end
end
