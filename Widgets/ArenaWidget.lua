---------------------------------------------------------------------------------------------------
-- Arena Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = Addon.Widgets:NewWidget("Arena")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs = pairs

-- WoW APIs
local CreateFrame = CreateFrame
local GetNumArenaOpponents, UnitGUID, UnitReaction = GetNumArenaOpponents, UnitGUID, UnitReaction
local IsInInstance, IsInBrawl = IsInInstance, C_PvP.IsInBrawl

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local Font = Addon.Font

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ArenaWidget\\"
local ICON_TEXTURE = PATH .. "BG"
local InArena = false
local ArenaID = {}

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local Settings

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

function Widget:PLAYER_ENTERING_WORLD()
  local _, instance_type = IsInInstance()
  if instance_type == "arena" and not IsInBrawl() then
    InArena = true
  else
    InArena = false
    ArenaID = {} -- Clear the table when we leave
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
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

  widget_frame.NumText = widget_frame:CreateFontString(nil, "ARTWORK", 0)

  self:UpdateLayout(widget_frame)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  return TidyPlatesThreat.db.profile.arenaWidget.ON
end

function Widget:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  --Widget:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
  --Widget:RegisterEvent("ARENA_OPPONENT_UPDATE")
end

function Widget:EnabledForStyle(style, unit)
  return UnitReaction(unit.unitid, "player") < 4 and not (style == "NameOnly" or style == "NameOnly-Unique" or style == "etotem")
end

function Widget:OnUnitAdded(widget_frame, unit)
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

  if Settings.ShowOrb then
    local icon_color = Settings.colors[arena_no]
    widget_frame.Icon:SetVertexColor(icon_color.r, icon_color.g, icon_color.b, icon_color.a)
  end

  if Settings.ShowNumber then
    local number_color = Settings.numColors[arena_no]
    widget_frame.NumText:SetTextColor(number_color.r, number_color.g, number_color.b)
    widget_frame.NumText:SetText(arena_no)
  end

  if Settings.HideName then
    widget_frame:GetParent().visual.name:Hide()
  elseif TidyPlatesThreat.db.profile.settings.name.show then
    widget_frame:GetParent().visual.name:Show()
  end

  widget_frame:Show()
end

function Widget:UpdateLayout(widget_frame)
  -- Updates based on settings
  widget_frame:SetPoint("CENTER", widget_frame:GetParent(), Settings.x, Settings.y)
  widget_frame:SetSize(Settings.scale, Settings.scale)

  if Settings.ShowOrb then
    widget_frame.Icon:Show()
  else
    widget_frame.Icon:Hide()
  end

  if Settings.ShowNumber then
    Font:UpdateText(widget_frame, widget_frame.NumText, Settings.NumberText)
    widget_frame.NumText:Show()
  else
    widget_frame.NumText:Hide()
  end
end

function Widget:UpdateSettings()
  Settings = TidyPlatesThreat.db.profile.arenaWidget

  for _, tp_frame in pairs(Addon.PlatesCreated) do
    local widget_frame = tp_frame.widgets.Arena

    -- widget_frame could be nil if the widget as disabled and is enabled as part of a profile switch
    -- For these frames, UpdateAuraWidgetLayout will be called anyway when the widget is initalized
    -- (which happens after the settings update)
    if widget_frame then
      self:UpdateLayout(widget_frame)
      if widget_frame.Active then -- equals: plate is visible and widget is active, i.e., show currently
        self:OnUnitAdded(widget_frame, widget_frame.unit)
      end
    end
  end
end
