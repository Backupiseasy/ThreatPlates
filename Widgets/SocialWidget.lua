local ADDON_NAME, NAMESPACE = ...
ThreatPlates = NAMESPACE.ThreatPlates

------------------------
-- Social Icon Widget --
------------------------
-- This widget is designed to show a single icon to display the relationship of a player's nameplate by name (regardless of faction if a bnet friend).
-- To-Do:
-- Possibly change the method to show 3 icons.
-- Change the 'guildicon' to use the emblem and border method used by blizzard frames.

local path = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\SocialWidget\\"
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

ListTable = {
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
	--TidyPlates:ForceUpdate()
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
	local active = TidyPlatesThreat.db.profile.socialWidget.ON

	if active then
		if not watcherIsEnabled then	EnableWatcher() end
	else
		if watcherIsEnabled then	DisableWatcher()	end
	end

	return active
end

local function EnabledInHeadlineView()
	return TidyPlatesThreat.db.profile.socialWidget.ShowInHeadlineView
end

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function UpdateSettings(frame, style)
	local db = TidyPlatesThreat.db.profile.socialWidget
	frame:SetFrameLevel(frame:GetParent():GetFrameLevel()+2)
	frame:SetPoint("CENTER",frame:GetParent(),db.anchor, db.x, db.y)

	if style == "NameOnly" and db.ShowInHeadlineView then
		frame:SetPoint(db.anchor, frame:GetParent(), db.x_hv, db.y_hv)
	else
		frame:SetPoint(db.anchor, frame:GetParent(), db.x, db.y)
	end

	frame:SetSize(db.scale,db.scale)
end

local function UpdateWidgetFrame(frame, unit, style)
	-- I will probably expand this to a table with 'friend = true','guild = true', and 'bnet = true' and have 3 textuers show.
	local texture
	if tContains(ListTable.f, unit.name) then
		texture = path.."friendicon"
	elseif tContains(ListTable.b, unit.name) then
		texture = "Interface\\FriendsFrame\\PlusManz-BattleNet"
	elseif tContains(ListTable.g, unit.name) then
		texture = path.."guildicon"
	end

	if texture then
		UpdateSettings(frame, style)
		frame.Icon:SetTexture(texture)
		frame:Show()
	else
		frame:_Hide()
	end
end

-- Context
local function UpdateWidgetContext(frame, unit, style)
	local guid = unit.guid
	frame.guid = guid

	-- Add to Widget List
	-- if guid then
	-- 	WidgetList[guid] = frame
	-- end

	-- Custom Code II
	--------------------------------------
	if UnitGUID("target") == guid then
		UpdateWidgetFrame(frame, unit, style)
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
	frame:SetHeight(32)
	frame:SetWidth(32)
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	frame.Icon:SetAllPoints(frame)
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

ThreatPlatesWidgets.RegisterWidget("SocialWidgetTPTP", CreateWidgetFrame, false, enabled, EnabledInHeadlineView)
ThreatPlatesWidgets.SocialWidgetDisableWatcher = DisableWatcher
