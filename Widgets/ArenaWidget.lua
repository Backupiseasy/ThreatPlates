---------------------------------------------------------------------------------------------------
-- Arena Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Module = Addon:NewModule("Arena")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame
local GetNumArenaOpponents, UnitGUID, UnitReaction = GetNumArenaOpponents, UnitGUID, UnitReaction
local IsInInstance, IsInBrawl = IsInInstance, C_PvP.IsInBrawl

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ArenaWidget\\"
local ICON_TEXTURE = PATH .. "BG"
local InArena = false
local ArenaID = {}

---------------------------------------------------------------------------------------------------
-- Arena Widget Functions
---------------------------------------------------------------------------------------------------

local function GetArenaOpponents()
	for i = 1, GetNumArenaOpponents() do
		local player_guid = UnitGUID("arena" .. i)
		local pet_guid = UnitGUID("arenapet" .. i)

    if player_guid and not ArenaID[player_guid] then
      ArenaID[player_guid] = i
		end

		if pet_guid and not ArenaID[pet_guid] then
			ArenaID[pet_guid] = i
		end
  end
end

function Module:PLAYER_ENTERING_WORLD()
  local _, instance_type = IsInInstance()
  if instance_type == "arena" and not IsInBrawl() then
    InArena = true
  else
    InArena = false
    ArenaID = {} -- Clear the table when we leave
  end
end

---------------------------------------------------------------------------------------------------
-- Module functions for creation and update
---------------------------------------------------------------------------------------------------

function Module:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------
  -- widget_frame:SetSize(32, 32)
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)

  widget_frame.Icon = widget_frame:CreateTexture(nil, "ARTWORK")
  widget_frame.Icon:SetAllPoints(widget_frame)
  widget_frame.Icon:SetTexture(ICON_TEXTURE)

  widget_frame.Num = widget_frame:CreateTexture(nil,"OVERLAY")
  widget_frame.Num:SetAllPoints(widget_frame)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Module:IsEnabled()
  return TidyPlatesThreat.db.profile.arenaWidget.ON
end

function Module:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  --Module:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
  --Module:RegisterEvent("ARENA_OPPONENT_UPDATE")
end

function Module:EnabledForStyle(style, unit)
  return UnitReaction(unit.unitid, "player") < 4 and not (style == "NameOnly" or style == "NameOnly-Unique" or style == "etotem")
end

function Module:OnUnitAdded(widget_frame, unit)
  if not InArena then
    widget_frame:Hide()
    return
  end

  GetArenaOpponents()

  local arena_no = ArenaID[unit.guid]
  if not arena_no then
    widget_frame:Hide()
    return
  end

  -- Updates based on settings
  local db = TidyPlatesThreat.db.profile.arenaWidget
  widget_frame:SetPoint("CENTER",widget_frame:GetParent(), db.x, db.y)
  widget_frame:SetSize(db.scale, db.scale)

  local icon_color = db.colors[arena_no]
  local number_color = db.numColors[arena_no]

  widget_frame.Icon:SetVertexColor(icon_color.r, icon_color.g, icon_color.b, icon_color.a)
  widget_frame.Num:SetTexture(PATH .. arena_no)
  widget_frame.Num:SetVertexColor(number_color.r, number_color.g, number_color.b, number_color.a)

  widget_frame:Show()
end