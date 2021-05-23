local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = (Addon.IS_CLASSIC and {}) or Addon.Widgets:NewWidget("Experience")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs = pairs
local string_match = string.match

-- WoW APIs
local tostring = tostring
local GetStatusBarWidgetVisualizationInfo = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo
local UnitPlayerControlled, UnitIsOwnerOrControllerOfUnit = UnitPlayerControlled, UnitIsOwnerOrControllerOfUnit

-- ThreatPlates APIs
local ANCHOR_POINT_TEXT = Addon.ANCHOR_POINT_TEXT

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS:

local MapUIWidgetToExperienceWidget = {}

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local Settings
local EnabledForStyle = {
  etotem = false,
  empty = false
}

---------------------------------------------------------------------------------------------------
-- Widget Functions
---------------------------------------------------------------------------------------------------

-- Kudos go to ElvUI for this mapping table
local NPC_ID_TO_WIDGET_ID = {
  -- BfA
  ["149805"] = 1940, -- Farseer Ori
  ["149804"] = 1613, -- Hunter Akana
  ["149803"] = 1966, -- Bladesman Inowari
  ["149904"] = 1621, -- Neri Sharpfin
  ["149902"] = 1622, -- Poen Gillbrack
  ["149906"] = 1920, -- Vim Brineheart

  ["154304"] = 1940, -- Farseer Ori
  ["150202"] = 1613, -- Hunter Akana
  ["154297"] = 1966, -- Bladesman Inowari
  ["151300"] = 1621, -- Neri Sharpfin
  ["151310"] = 1622, -- Poen Gillbrack
  ["151309"] = 1920, -- Vim Brineheart

  --["151286"] = ..., -- Child of Torcali
  -- Raising the Shadowbarb Drone
  ["163541"] = 2342, -- Voidtouched Egg
  ["163593"] = 2342, -- Bitey McStabface
  ["163595"] = 2342, -- Reginald
  ["163596"] = 2342, -- Picco
  ["163648"] = 2342, -- Bitey McStabface
  ["163592"] = 2342, -- Yu'gaz
  ["163651"] = 2342, -- Shadowbarb Hatchling

  -- Shadowlands
}

local MAX_NPC_XP_RANK = 30

local function GetNPCExperience(widgetID)
  local widget = GetStatusBarWidgetVisualizationInfo(widgetID)

  local current_xp = widget.barValue - widget.barMin
  local max_xp = widget.barMax - widget.barMin
  --local to_next_rank_xp = widget.barValue
  -- overrideBarText, possible values: Rank 12, Hetches ...
  local rank = string_match(widget.overrideBarText or "", "%d+") or widget.overrideBarText

  --  if rank == MAX_NPC_XP_RANK then
  --    max_xp, current_xp = 1, 1
  --  end

  return current_xp, max_xp, rank
end

---------------------------------------------------------------------------------------------------
-- Widget Class Functions
---------------------------------------------------------------------------------------------------

function Widget:UPDATE_UI_WIDGET(widget_info)
  local widget_frame = MapUIWidgetToExperienceWidget[widget_info.widgetID]
  if widget_frame and widget_frame:IsShown() then
    self:OnUnitAdded(widget_frame, widget_frame.unit)
  end
end

function Widget:IsEnabled()
  local db = Addon.db.profile.ExperienceWidget
  return db.ON or db.ShowInHeadlineView
end

function Widget:OnEnable()
  self:RegisterEvent("UPDATE_UI_WIDGET")
end

function Widget:OnDisable()
  self:UnregisterEvent("UPDATE_UI_WIDGET")
end

function Widget:EnabledForStyle(style, unit)
  return EnabledForStyle[style]
end

function Widget:Create(tp_frame)
  local widget_frame = Addon.CreateStatusbar(tp_frame)
  widget_frame:AddTextArea("RankText")
  widget_frame:AddTextArea("ExperienceText")

  Widget:UpdateLayout(widget_frame)

  return widget_frame
end

function Widget:OnUnitAdded(widget_frame, unit)
  local widget_id = NPC_ID_TO_WIDGET_ID[unit.NPCID]
  if not widget_id or not EnabledForStyle[unit.style] or (UnitPlayerControlled(unit.unitid) and not UnitIsOwnerOrControllerOfUnit("player", unit.unitid)) then
    widget_frame:Hide()
    return
  end

  -- Store mapping for event updates (when exp changes)
  MapUIWidgetToExperienceWidget[widget_id] = widget_frame
  local current_xp, max_xp, rank = GetNPCExperience(widget_id)

  widget_frame:SetMinMaxValues(0, max_xp)
  widget_frame:SetValue(current_xp)

  if Settings.RankText.Show then
    widget_frame.RankText:SetText(rank)
    widget_frame.RankText:Show()
  else
    widget_frame.RankText:Hide()
  end

  if Settings.ExperienceText.Show then
    widget_frame.ExperienceText:SetText(tostring(current_xp) .. "/" .. tostring(max_xp))
    widget_frame.ExperienceText:Show()
  else
    widget_frame.ExperienceText:Hide()
  end

  widget_frame:UpdatePositioning(unit, Settings)

  widget_frame:Show()
end

function Widget:OnUnitRemoved(tp_frame, unit)
  MapUIWidgetToExperienceWidget[unit.unitid or ""] = nil
end

function Widget:UpdateLayout(widget_frame)
  widget_frame:UpdateSettings(Settings)
end

function Widget:UpdateSettings()
  Settings = Addon.db.profile.ExperienceWidget

  EnabledForStyle["NameOnly"] = Settings.ShowInHeadlineView
  EnabledForStyle["NameOnly-Unique"] = Settings.ShowInHeadlineView
  EnabledForStyle["dps"] = Settings.ON
  EnabledForStyle["tank"] = Settings.ON
  EnabledForStyle["normal"] = Settings.ON
  EnabledForStyle["totem"] = Settings.ON
  EnabledForStyle["unique"] = Settings.ON
end
