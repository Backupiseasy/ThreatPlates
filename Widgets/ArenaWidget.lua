local ADDON_NAME, NAMESPACE = ...
ThreatPlates = NAMESPACE.ThreatPlates

--------------------
-- Arena Icon Widget
--------------------

local path = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ArenaWidget\\"
local ArenaID = {}

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
-- ThreatPlatesWidgets.ClearAllArenaWidgets = ClearAllWidgets

local function BuildTable() -- ArenaId[unit name] = ArenaID #
	for i = 1, GetNumArenaOpponents() do
		local name = UnitGUID("arena"..i)
		local petname = UnitGUID("arenapet"..i)
		if name and not ArenaID[name] then
			ArenaID[name] = i
		end
		if petname and not ArenaID[petname] then
			ArenaID[petname] = i
		end
	end
end

---------------------------------------------------------------------------------------------------
-- TidyPlates ComboPointWidget functions
---------------------------------------------------------------------------------------------------

local function UpdateSettings(frame)
	local db = TidyPlatesThreat.db.profile.arenaWidget
	frame:SetFrameLevel(frame:GetParent():GetFrameLevel()+2)
	frame:SetSize(db.scale,db.scale)
	frame.Overlay:SetSize(db.scale,db.scale)
	frame:SetPoint("CENTER",frame:GetParent(),db.anchor, db.x, db.y)
end

local function ClearWidgetContext(frame)
	local guid = frame.guid
	if guid then
		ArenaID[guid] = nil
		frame.guid = nil
	end
end

-- Watcher Frame
local WatcherFrame = CreateFrame("Frame", nil, WorldFrame )
local isEnabled = false

local function WatcherFrameHandler(frame, event,...)
	if IsActiveBattlefieldArena() and GetNumArenaOpponents() >= 1 then -- If we're in arena
		BuildTable()
	else
		ArenaID = {} -- Clear the table when we leave
	end
	--TidyPlates:ForceUpdate()
end

local function EnableWatcherFrame(arg)
	isEnabled = arg
	if arg then
		WatcherFrame:SetScript("OnEvent", WatcherFrameHandler)
		WatcherFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	else
		WatcherFrame:UnregisterAllEvents()
		WatcherFrame:SetScript("OnEvent", nil);
		ArenaID = {}
	end
end

local function enabled()
	local active = TidyPlatesThreat.db.profile.arenaWidget.ON

	if active then
		if not isEnabled then	EnableWatcherFrame(true) end
	else
		if isEnabled then	EnableWatcherFrame(false)	end
	end

	return active
end

-- Update Graphics
local function UpdateWidgetFrame(frame, unit)
	BuildTable()
	UpdateSettings(frame)

	if unit.guid and ArenaID[unit.guid] then
		local c = TidyPlatesThreat.db.profile.arenaWidget.colors[ArenaID[unit.guid]]
		local c2 = TidyPlatesThreat.db.profile.arenaWidget.numColors[ArenaID[unit.guid]]
		frame.Icon:SetTexture(path.."BG")
		frame.Icon:SetVertexColor(c.r,c.g,c.b,c.a)
		frame.Overlay.Num:SetTexture(path..ArenaID[unit.guid])
		frame.Overlay.Num:SetVertexColor(c2.r,c2.g,c2.b,c2.a)
		frame:Show()
	else
		frame.Icon:SetTexture(nil)
		frame.Overlay.Num:SetTexture(nil)
		frame:_Hide()
	end
end

-- Context
local function UpdateWidgetContext(frame, unit)
	local guid = unit.guid
	frame.guid = guid

	-- Add to Widget List - done in EventWatcher, only necessary for arena opponents
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

local function CreateArenaWidget(parent)
	-- Required Widget Code
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()

	-- Custom Code III
	--------------------------------------
	frame:SetHeight(32)
	frame:SetWidth(32)
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	frame.Icon:SetAllPoints(frame)
	frame.Overlay = CreateFrame("frame",nil, frame)
	frame.Overlay:SetHeight(32)
	frame.Overlay:SetWidth(32)
	frame.Overlay:SetPoint("CENTER",frame,"CENTER")
	frame.Overlay:SetFrameStrata(frame:GetFrameStrata())
	frame.Overlay:SetFrameLevel(frame:GetFrameLevel()+1)
	frame.Overlay.Num = frame.Overlay:CreateTexture(nil,"OVERLAY")
	frame.Overlay.Num:SetAllPoints(frame.Overlay)

	--------------------------------------
	-- End Custom Code

	-- Required Widget Code
	frame.UpdateContext = UpdateWidgetContext
	frame.Update = UpdateWidgetFrame
	frame._Hide = frame.Hide
	frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end

	return frame
end

ThreatPlatesWidgets.RegisterWidget("ArenaWidget", CreateArenaWidget, false, enabled)
