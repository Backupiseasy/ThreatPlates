local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

--------------------
-- Arena Icon Widget
--------------------

local path = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ArenaWidget\\"
local watcherIsEnabled = false
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

	frame:ClearAllPoints()
	frame:SetPoint("CENTER",frame:GetParent(), db.x, db.y)

	local size = db.scale
	frame:SetSize(size,size)
	frame.Overlay:SetSize(size,size)
end

local function ClearWidgetContext(frame)
	local guid = frame.guid
	if guid then
		ArenaID[guid] = nil
		frame.guid = nil
	end
end

-- Watcher Frame
local WatcherFrame = CreateFrame("Frame", nil, WorldFrame)

local function WatcherFrameHandler(frame, event,...)
	if IsActiveBattlefieldArena() and GetNumArenaOpponents() >= 1 then -- If we're in arena
		BuildTable()
	else
		ArenaID = {} -- Clear the table when we leave
	end
	--TidyPlatesInternal:ForceUpdate()
end

local function EnableWatcher()
	WatcherFrame:SetScript("OnEvent", WatcherFrameHandler)
	WatcherFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	watcherIsEnabled = true
end

local function DisableWatcher()
	WatcherFrame:UnregisterAllEvents()
	WatcherFrame:SetScript("OnEvent", nil);
	watcherIsEnabled = false
	ArenaID = {}
end

local function enabled()
	local active = TidyPlatesThreat.db.profile.arenaWidget.ON

	if active then
		if not watcherIsEnabled then	EnableWatcher() end
	else
		if watcherIsEnabled then	DisableWatcher()	end
	end

	return active
end

-- Update Graphics
local function UpdateWidgetFrame(frame, unit)
	BuildTable()

	local db = TidyPlatesThreat.db.profile.arenaWidget
	if unit.guid and ArenaID[unit.guid] then
		local c = db.colors[ArenaID[unit.guid]]
		local c2 = db.numColors[ArenaID[unit.guid]]

		frame.Icon:SetTexture(path.."BG")
		frame.Icon:SetVertexColor(c.r, c.g, c.b, c.a)

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
	frame:SetSize(32, 32)
	frame:SetFrameLevel(parent:GetFrameLevel() + 7)

	frame.Icon = frame:CreateTexture(nil, "OVERLAY")
	frame.Icon:SetAllPoints(frame)

	frame.Overlay = CreateFrame("frame",nil, frame)
	frame.Overlay:SetPoint("CENTER", frame, "CENTER")

	frame.Overlay.Num = frame.Overlay:CreateTexture(nil,"OVERLAY")
	frame.Overlay.Num:SetAllPoints(frame.Overlay)

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

ThreatPlatesWidgets.RegisterWidget("ArenaWidgetTPTP", CreateArenaWidget, false, enabled)
ThreatPlatesWidgets.ArenaWidgetDisableWatcher = DisableWatcher
