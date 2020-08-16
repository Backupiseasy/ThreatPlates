local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewWidget("Experience")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs = pairs
local string_match = string.match

-- WoW APIs
local tonumber, strsplit, tostring = tonumber, strsplit, tostring
local GetStatusBarWidgetVisualizationInfo = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo
local UnitIsOwnerOrControllerOfUnit = UnitIsOwnerOrControllerOfUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local ANCHOR_POINT_TEXT = Addon.ANCHOR_POINT_TEXT

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS:

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

local NPC_ID_TO_WIDGET_ID = {
  ["154304"] = 1940, -- Farseer Ori
  ["150202"] = 1613, -- Hunter Akana
  ["154297"] = 1966, -- Bladesman Inowari
  ["151300"] = 1621, -- Neri Sharpfin
  ["151310"] = 1622, -- Poen Gillbrack
  ["151309"] = 1920, -- Vim Brineheart
  --["151286"] = 1920, -- Child of Torcali
}

local function GetBodyguardXP(widgetID)
  local widget = GetStatusBarWidgetVisualizationInfo(widgetID)
  -- Rank, current xp, max rank xp, ???
  return string_match(widget.overrideBarText, "%d+"), widget.barValue - widget.barMin, widget.barMax - widget.barMin, widget.barValue
end

---------------------------------------------------------------------------------------------------
-- Widget Class Functions
---------------------------------------------------------------------------------------------------

function Widget:IsEnabled()
  return Settings.ON or Settings.ShowInHeadlineView
end

--function Widget:OnEnable()
--end

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
  local _, _,  _, _, _, npc_id = strsplit("-", unit.guid or "")

  local widget_id = NPC_ID_TO_WIDGET_ID[npc_id]
  if not widget_id or (Settings.ShowOnlyMine and not UnitIsOwnerOrControllerOfUnit("player", unit.unitid)) or not EnabledForStyle[unit.style] then
    widget_frame:Hide()
    return
  end

  local rank, current, next, total = GetBodyguardXP(widget_id)

  widget_frame:SetMinMaxValues(0, next)
  widget_frame:SetValue(current)

  if Settings.RankText.Show then
    widget_frame.RankText:SetText(rank)
    widget_frame.RankText:Show()
  else
    widget_frame.RankText:Hide()
  end

  if Settings.ExperienceText.Show then
    widget_frame.ExperienceText:SetText(tostring(current) .. "/" .. tostring(next))
    widget_frame.ExperienceText:Show()
  else
    widget_frame.ExperienceText:Hide()
  end

  widget_frame:UpdatePositioning(unit, Settings)

  widget_frame:Show()
end

function Widget:UpdateLayout(widget_frame)
  widget_frame:UpdateSettings(Settings)
end

function Widget:UpdateSettings()
  Settings = TidyPlatesThreat.db.profile.ExperienceWidget

  EnabledForStyle["NameOnly"] = Settings.ShowInHeadlineView
  EnabledForStyle["NameOnly-Unique"] = Settings.ShowInHeadlineView
  EnabledForStyle["dps"] = Settings.ON
  EnabledForStyle["tank"] = Settings.ON
  EnabledForStyle["normal"] = Settings.ON
  EnabledForStyle["totem"] = Settings.ON
  EnabledForStyle["unique"] = Settings.ON

  for _, tp_frame in pairs(Addon.PlatesCreated) do
    local widget_frame = tp_frame.widgets[Widget.Name]

    -- Update the layout of all nameplates that were created as they might be re-used later. For that case, the layout
    -- must be up to date.
    -- widget_frame could be nil if the widget as disabled and is enabled as part of a profile switch
    if widget_frame then
      self:UpdateLayout(widget_frame)
      -- Also, update all currently shown nameplates as it is not guarnanteed that ForceUpdate() is called to
      -- trigger an update via OnUnitAdded
      if widget_frame.Active then
        self:OnUnitAdded(widget_frame, widget_frame.unit)
      end
    end
  end
end
