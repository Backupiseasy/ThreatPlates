------------------------
-- Social Icon Widget --
------------------------
-- This widget is designed to show a single icon to display the relationship of a player's nameplate by name (regardless of faction if a bnet friend).
-- To-Do:
-- Possibly change the method to show 3 icons.
-- Change the 'guildicon' to use the emblem and border method used by blizzard frames.

local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local UnitFactionGroup = UnitFactionGroup
local GetNumGuildMembers = GetNumGuildMembers
local GetGuildRosterInfo = GetGuildRosterInfo
local GetNumFriends = GetNumFriends
local GetFriendInfo = GetFriendInfo
local BNGetNumFriends = BNGetNumFriends
local BNGetFriendInfo = BNGetFriendInfo
local BNGetToonInfo = BNGetToonInfo
local UnitGUID = UnitGUID
local CreateFrame = CreateFrame

local tContains = tContains

local TidyPlatesThreat = TidyPlatesThreat
local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\SocialWidget\\"
local ICON_FRIEND = PATH .."friendicon"
local ICON_GUILDMATE = PATH .."guildicon"
local ICON_BNET_FRIEND = "Interface\\FriendsFrame\\PlusManz-BattleNet"
local ICON_FACTION = {
--  Horde = "Interface\\ICONS\\inv_bannerpvp_01",
--  Alliance = "Interface\\ICONS\\inv_bannerpvp_02",
	Horde = PATH .. "hordeicon",
	Alliance = PATH .. "allianceicon",
}

-- local WidgetList = {}
local watcherIsEnabled = false

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

local ListTable = {
	g = {},
	b = {},
	f = {}
}

local function ParseRealm(input)
	local output, _
	if type(input) == "string" then
		output,_ = strsplit("-",input,2)
	else
		output = ""
	end
	return output
end

local function UpdateGlist()
	ListTable.g = {}
	for i=1,GetNumGuildMembers() do
		local name = select(1,GetGuildRosterInfo(i))
		tinsert(ListTable.g, ParseRealm(name))
	end
end

local function UpdateFlist()
	ListTable.f = {}
	local friendsTotal, friendsOnline = GetNumFriends()
	for i=1,friendsOnline do
		local name, level, class, area, connected, status, note = GetFriendInfo(i)
		tinsert(ListTable.f, ParseRealm(name))
	end
end

local function UpdateBnetList()
	ListTable.b = {}
	local BnetTotal, BnetOnline = BNGetNumFriends()
	for i=1, BnetOnline do
		local presenceID, givenName, surname, toonName, toonID, client, isOnline, lastOnline, isAFK, isDND, broadcastText, noteText, isFriend, broadcastTime  = BNGetFriendInfo(i)
		if isOnline and toonID and client == "WoW" then
			local _,name, _, realmName, faction, race, class, guild, area, lvl = BNGetToonInfo(toonID)
			tinsert(ListTable.b, ParseRealm(name))
		end
	end
end

-- Watcher Frame
local WatcherFrame = CreateFrame("Frame", nil, WorldFrame)

local function WatcherFrameHandler(frame, event,...)
	if event == "GUILD_ROSTER_UPDATE" then
		UpdateGlist()
	elseif event == "FRIENDLIST_UPDATE" then
		UpdateFlist()
	elseif event == "BN_FRIEND_LIST_SIZE_CHANGED" or event == "BN_CONNECTED" or event == "BN_FRIEND_ACCOUNT_ONLINE" or
				 event == "BN_FRIEND_ACCOUNT_OFFLINE" then
		UpdateBnetList()
	end
	--TidyPlatesInternal:ForceUpdate()
end

local function EnableWatcher()
	UpdateGlist()
	UpdateFlist()
	UpdateBnetList()
	WatcherFrame:SetScript("OnEvent", WatcherFrameHandler)
	WatcherFrame:RegisterEvent("FRIENDLIST_UPDATE")
	WatcherFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
	WatcherFrame:RegisterEvent("BN_CONNECTED")
	WatcherFrame:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
	WatcherFrame:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
	WatcherFrame:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED")
	watcherIsEnabled = true
end

local function DisableWatcher()
	WatcherFrame:UnregisterAllEvents()
	WatcherFrame:SetScript("OnEvent", nil)
	watcherIsEnabled = false
end

local function enabled()
	local db = TidyPlatesThreat.db.profile.socialWidget

	if not (db.ON or db.ShowInHeadlineView) then
    if watcherIsEnabled then	DisableWatcher()	end
  else
    if not watcherIsEnabled then	EnableWatcher() end
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
  local size = db.scale
  --local anchor = db.anchor
  --friend_icon_anchor, friend_icon_anchor_relative = ANCHOR_POINT[anchor][2], ANCHOR_POINT[anchor][1]
  local icon = frame.Icon
  icon:SetSize(size, size)

  db = TidyPlatesThreat.db.profile.FactionWidget
  size = db.scale
  --anchor = db.anchor
  --faction_icon_anchor, faction_icon_anchor_relative = ANCHOR_POINT[anchor][2], ANCHOR_POINT[anchor][1]
  icon = frame.FactionIcon
  icon:SetSize(size, size)
end

local function UpdateWidgetFrame(frame, unit)
	-- I will probably expand this to a table with 'friend = true','guild = true', and 'bnet = true' and have 3 textuers show.
	local db = TidyPlatesThreat.db.profile.socialWidget

	local friend_texture
	if db.ShowFriendIcon then
		if tContains(ListTable.f, unit.name) then
			friend_texture = ICON_FRIEND
		elseif tContains(ListTable.b, unit.name) then
			friend_texture = ICON_BNET_FRIEND
		elseif tContains(ListTable.g, unit.name) then
			friend_texture = ICON_GUILDMATE
		end
	end

	local faction_texture
	local unitid = unit.unitid
	if db.ShowFactionIcon and unit.type == "PLAYER" and unitid then
		local faction = UnitFactionGroup(unitid)
		if faction then
    	faction_texture = ICON_FACTION[faction]
		end
	end

	if friend_texture or faction_texture then
    local db = TidyPlatesThreat.db.profile.socialWidget
    local x, y

    local style = unit.TP_Style
    local icon = frame.Icon
    if friend_texture then
      if style == "NameOnly" or style == "NameOnly-Unique" then
        x, y = db.x_hv, db.y_hv
      else
        x, y = db.x, db.y
      end
      --icon:ClearAllPoints()
      --icon:SetPoint(friend_icon_anchor, frame:GetParent(), friend_icon_anchor_relative, x, y)
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
      if style == "NameOnly" or style == "NameOnly-Unique" then
        x, y = db.x_hv, db.y_hv
      else
        x, y = db.x, db.y
      end
      --icon:ClearAllPoints()
      --icon:SetPoint(faction_icon_anchor, frame:GetParent().visual.healthbar, faction_icon_anchor_relative, x, y)
      icon:SetPoint("CENTER", frame:GetParent(), x, y)
      icon:SetTexture(faction_texture)
      icon:Show()
    else
      icon:Hide()
    end

		frame:Show()
	else
		frame:_Hide()
	end
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
  frame:SetFrameLevel(parent:GetFrameLevel() + 7)
  frame:SetSize(32, 32)
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

	--if not isEnabled then EnableWatcherFrame(true) end
	return frame
end

local function IsFriend(unit)
  return enabled() and (tContains(ListTable.f, unit.name) or tContains(ListTable.b, unit.name))
end

local function IsGuildmate(unit)
  return enabled() and tContains(ListTable.g, unit.name)
end

ThreatPlates.IsFriend = IsFriend
ThreatPlates.IsGuildmate = IsGuildmate

ThreatPlatesWidgets.RegisterWidget("SocialWidgetTPTP", CreateWidgetFrame, false, enabled, EnabledInHeadlineView)
ThreatPlatesWidgets.SocialWidgetDisableWatcher = DisableWatcher
