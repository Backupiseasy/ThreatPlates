local ADDON_NAME, NAMESPACE = ...
ThreatPlates = NAMESPACE.ThreatPlates

--------------------
-- Arena Icon Widget
--------------------

local path = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ArenaWidget\\"
local ArenaID = {}
local WidgetList = {}

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

-- hides/destroys all widgets of this type created by Threat Plates
local function ClearAllWidgets()
	for _, widget in pairs(WidgetList) do
		widget:Hide()
	end
end
ThreatPlatesWidgets.ClearAllAreanaWidgets = ClearAllWidgets

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

local WatcherFrame = CreateFrame("frame")
local isEnabled = false
local function EnableWatcherFrame(arg)
	isEnabled = arg
	if arg then
		WatcherFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	else
		WatcherFrame:UnregisterAllEvents()
		wipe(ArenaID)
	end
end

WatcherFrame:SetScript("OnEvent",function(self,event,...)
	if IsActiveBattlefieldArena() and GetNumArenaOpponents() >= 1 then -- If we're in arena
		BuildTable()
	else
		wipe(ArenaID) -- Clear the table when we leave
	end
	TidyPlates:ForceUpdate()
end)

local function enabled()
	local db = TidyPlatesThreat.db.profile.arenaWidget
	if db.ON then
		if not isEnabled then
			EnableWatcherFrame(true)
		end
	else
		if isEnabled then
			EnableWatcherFrame(false)
		end
	end
	return db.ON
end

local function UpdateSettings(frame)
	local db = TidyPlatesThreat.db.profile.arenaWidget
	frame:SetFrameLevel(frame:GetParent():GetFrameLevel()+2)
	frame:SetSize(db.scale,db.scale)
	frame.Overlay:SetSize(db.scale,db.scale)
	frame:SetPoint("CENTER",frame:GetParent(),db.anchor, db.x, db.y)
end

local UpdateArenaWidget = function(frame, unit)
	if enabled() then
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
			frame:Hide()
		end
	else
		frame:Hide()
	end
end

local function CreateArenaWidget(parent)
	local frame = CreateFrame("Frame", nil, parent)
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
	frame:Show()
	frame:Hide()
	frame.Update = UpdateArenaWidget
	return frame
end

ThreatPlatesWidgets.RegisterWidget("ArenaWidget",CreateArenaWidget,false,enabled)
