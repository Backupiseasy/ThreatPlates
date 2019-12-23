---------------------------------------------------------------------------------------------------
-- Social Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

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
local CreateFrame = CreateFrame
local GetNumGuildMembers, GetGuildRosterInfo = GetNumGuildMembers, GetGuildRosterInfo
local BNGetNumFriends, BNGetFriendInfo, BNGetToonInfo, BNGetFriendInfoByID = BNGetNumFriends, BNGetFriendInfo, BNGetToonInfo, BNGetFriendInfoByID
local BNet_GetValidatedCharacterName = BNet_GetValidatedCharacterName
local UnitName, GetRealmName, UnitFactionGroup = UnitName, GetRealmName, UnitFactionGroup
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local C_FriendList_ShowFriends, C_FriendList_GetNumOnlineFriends = C_FriendList.ShowFriends, C_FriendList.GetNumOnlineFriends
local C_FriendList_GetFriendInfo = C_FriendList.GetFriendInfo

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\SocialWidget\\"
local ICON_FRIEND = PATH .. "friendicon"
local ICON_GUILDMATE = PATH .. "guildicon"
local ICON_BNET_FRIEND = "Interface\\FriendsFrame\\PlusManz-BattleNet"
local ICON_FACTION_HORDE = PATH .. "hordeicon" -- "Interface\\ICONS\\inv_bannerpvp_01"
local ICON_FACTION_ALLIANCE = PATH .. "allianceicon" -- "Interface\\ICONS\\inv_bannerpvp_02",

local ListGuildMembers = {}
local ListFriends = {}
local ListBnetFriends = {}
local ListGuildMembersSize, ListFriendsSize, ListBnetFriendsSize = 0, 0, 0

---------------------------------------------------------------------------------------------------
-- Social Widget Functions
---------------------------------------------------------------------------------------------------

function Widget:FRIENDLIST_UPDATE()
--  local plate = C_NamePlate.GetNamePlateForUnit("target")
--  if plate then
--    ListFriendsSize = ListFriendsSize + 1
--  end


  -- First check if there was actually a change to the friend list (event fires for other reasons too)
  local friendsOnline = C_FriendList_GetNumOnlineFriends()

  if ListFriendsSize ~= friendsOnline then
    -- Only wipe the friend list if a member went offline
    if friendsOnline < ListFriendsSize then
      ListFriends = {}
    end

    local no_friends = 0
    for i = 1, friendsOnline do
      local name, _ = C_FriendList_GetFriendInfo(i)
      if name then
        ListFriends[name] = ICON_FRIEND
        no_friends = no_friends + 1
      end
    end

    ListFriendsSize = no_friends -- as name might be nil, friendsOnline might not be correct here

--    if plate then
--      local unit = plate.TPFrame.unit
--      if unit.fullname and not ListFriends[unit.fullname] then
--        print ("Adding: ", unit.fullname)
--        ListFriends[unit.fullname] = ICON_FRIEND
--        ListFriendsSize = ListFriendsSize + 1
--      end
--    end

    self:UpdateAllFramesAndNameplateColor()
  end
end

function Widget:GUILD_ROSTER_UPDATE()
  local numTotalGuildMembers, _, _ = GetNumGuildMembers()
  if ListGuildMembersSize ~= numTotalGuildMembers then
    -- Only wipe the guild member list if a member went offline
    if numTotalGuildMembers < ListGuildMembersSize then
      ListGuildMembers = {}
    end

    for i = 1, numTotalGuildMembers do
      local name, rank, rankIndex, level, classDisplayName, zone, note, officernote, isOnline, _ = GetGuildRosterInfo(i)
      ListGuildMembers[name] = ICON_GUILDMATE
    end

    ListGuildMembersSize = numTotalGuildMembers

    self:UpdateAllFramesAndNameplateColor()
  end
end

function Widget:BN_CONNECTED()
  local _, BnetOnline = BNGetNumFriends()
  if ListBnetFriendsSize ~= BnetOnline then
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

    self:UpdateAllFramesAndNameplateColor()
  end
end

function Widget:BN_FRIEND_TOON_ONLINE(toon_id)
  local _, name = BNGetToonInfo(toon_id)
  ListBnetFriends[name] = ICON_BNET_FRIEND

  self:UpdateAllFramesAndNameplateColor()
end

function Widget:BN_FRIEND_TOON_OFFLINE(toon_id)
  local _, name = BNGetToonInfo(toon_id)
  ListBnetFriends[name] = nil

  self:UpdateAllFramesAndNameplateColor()
end

function Widget:BN_FRIEND_ACCOUNT_ONLINE(presence_id)
  local bnetIDAccount, accountName, battle_tag, isBattleTag, character_name, bnetIDGameAccount, client = BNGetFriendInfoByID(presence_id)

  -- don't display a the friend if we didn't get the data in time or the are not logged in into WoW
  --if not accountName or client ~= "BNET_CLIENT_WOW" then	return end

  if (battle_tag) then
    character_name = BNet_GetValidatedCharacterName(character_name, battle_tag, client) or ""
  end

  ListBnetFriends[character_name] = ICON_BNET_FRIEND

  self:UpdateAllFramesAndNameplateColor()
end

function Widget:BN_FRIEND_ACCOUNT_OFFLINE(presence_id)
  local bnetIDAccount, accountName, battle_tag, isBattleTag, character_name, bnetIDGameAccount, client = BNGetFriendInfoByID(presence_id)

  -- don't display a the friend if we didn't get the data in time or the are not logged in into WoW
  --if not accountName or client ~= "BNET_CLIENT_WOW" then	return end

  if (battle_tag) then
    character_name = BNet_GetValidatedCharacterName(character_name, battle_tag, client) or ""
  end

  ListBnetFriends[character_name] = nil

  self:UpdateAllFramesAndNameplateColor()
end

function Widget:UNIT_NAME_UPDATE(unitid)
  local plate = GetNamePlateForUnit(unitid)

  if plate and plate.TPFrame.Active then
    local widget_frame = plate.TPFrame.widgets.Social
    if widget_frame.Active then
      local unit = plate.TPFrame.unit
      local name, realm = UnitName(unitid)
      unit.fullname = name .. "-" .. (realm or GetRealmName())

      self:OnUnitAdded(widget_frame, unit)
    end
  end
end

local function IsFriend(unit)
  -- no need to check for ShowInHeadlineView as this is for coloring the healthbar
  return TidyPlatesThreat.db.profile.socialWidget.ON and (ListFriends[unit.fullname] or ListBnetFriends[unit.fullname])
end

local function IsGuildmate(unit)
  -- no need to check for ShowInHeadlineView as this is for coloring the healthbar
  return TidyPlatesThreat.db.profile.socialWidget.ON and ListGuildMembers[unit.fullname]
end

ThreatPlates.IsFriend = IsFriend
ThreatPlates.IsGuildmate = IsGuildmate

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
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
  return TidyPlatesThreat.db.profile.socialWidget.ON or TidyPlatesThreat.db.profile.socialWidget.ShowInHeadlineView
end

function Widget:OnEnable()
  if TidyPlatesThreat.db.profile.socialWidget.ShowFriendIcon then
    self:RegisterEvent("FRIENDLIST_UPDATE")
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    self:RegisterEvent("BN_CONNECTED")
    self:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
    self:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
    self:RegisterEvent("UNIT_NAME_UPDATE")
    --Widget:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED", EventHandler)

    --self:FRIENDLIST_UPDATE()
    C_FriendList_ShowFriends() -- Will fire FRIENDLIST_UPDATE
    self:BN_CONNECTED()
    --self:GUILD_ROSTER_UPDATE() -- called automatically by game
  else
    self:UnregisterAllEvents()
  end
end

function Widget:EnabledForStyle(style, unit)
  if unit.type ~= "PLAYER" then return false end

  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return TidyPlatesThreat.db.profile.socialWidget.ShowInHeadlineView
  elseif style ~= "etotem" then
    return TidyPlatesThreat.db.profile.socialWidget.ON
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  local db = TidyPlatesThreat.db.profile.socialWidget
  widget_frame.Icon:SetSize(db.scale, db.scale)

  db = TidyPlatesThreat.db.profile.FactionWidget
  widget_frame.FactionIcon:SetSize(db.scale, db.scale)

  local name, realm = UnitName(unit.unitid)
  unit.fullname = name .. "-" .. (realm or GetRealmName())

  self:UpdateFrame(widget_frame, unit)
end

function Widget:UpdateFrame(widget_frame, unit)
  -- I will probably expand this to a table with 'friend = true','guild = true', and 'bnet = true' and have 3 textuers show.
  local db = TidyPlatesThreat.db.profile.socialWidget
  local friend_texture = db.ShowFriendIcon and (ListFriends[unit.name] or ListBnetFriends[unit.fullname] or ListGuildMembers[unit.fullname])
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

  -- Need to hide the frame here as it may have been shown before
  if not (friend_texture or faction_texture) then
    widget_frame:Hide()
    return
  end

  local name_style = unit.style == "NameOnly" or unit.style == "NameOnly-Unique"
  local icon = widget_frame.Icon
  if friend_texture then
    -- db = TidyPlatesThreat.db.profile.socialWidget
    if name_style then
      icon:SetPoint("CENTER", widget_frame:GetParent(), db.x_hv, db.y_hv)
    else
      icon:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
    end
    icon:SetTexture(friend_texture)

    icon:Show()
  else
    icon:Hide()
  end

  icon = widget_frame.FactionIcon
  if faction_texture then
    -- apply settings to faction icon
    db = TidyPlatesThreat.db.profile.FactionWidget
    if name_style then
      icon:SetPoint("CENTER", widget_frame:GetParent(), db.x_hv, db.y_hv)
    else
      icon:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
    end
    icon:SetTexture(faction_texture)

    icon:Show()
  else
    icon:Hide()
  end

  widget_frame:Show()
end

--function Widget:OnUpdateStyle(widget_frame, unit)
--  local name_style = unit.style == "NameOnly" or unit.style == "NameOnly-Unique"
--  if widget_frame.Icon:IsShown() then
--    local db = TidyPlatesThreat.db.profile.socialWidget
--    if name_style then
--      widget_frame.Icon:SetPoint("CENTER", widget_frame:GetParent(), db.x_hv, db.y_hv)
--    else
--      widget_frame.Icon:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
--    end
--  end
--
--  if widget_frame.FactionIcon:IsShown() then
--    -- apply settings to faction icon
--    local db = TidyPlatesThreat.db.profile.FactionWidget
--    if name_style then
--      widget_frame.FactionIcon:SetPoint("CENTER", widget_frame:GetParent(), db.x_hv, db.y_hv)
--    else
--      widget_frame.FactionIcon:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
--    end
--  end
--end
