---------------------------------------------------------------------------------------------------
-- Quest Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon:NewWidget("Quest")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local string = string

-- WoW APIs
local WorldFrame, CreateFrame = WorldFrame, CreateFrame
local InCombatLockdown, IsInInstance = InCombatLockdown, IsInInstance
local UnitName, UnitIsUnit, UnitDetailedThreatSituation, UnitThreatSituation = UnitName, UnitIsUnit, UnitDetailedThreatSituation, UnitThreatSituation
local UnitGUID = UnitGUID
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local InCombat = false
local TooltipFrame = CreateFrame("GameTooltip", "ThreatPlates_Tooltip", nil, "GameTooltipTemplate")
local PlayerName = UnitName("player")
local ICON_COLORS = {}

---------------------------------------------------------------------------------------------------
-- Quest Functions
---------------------------------------------------------------------------------------------------

local function IsQuestUnit(unit)
  local quest_area = false
  local quest_player = false
  local quest_group = false
  local currentProgress = false

  -- Read quest information from tooltip. Thanks to Kib: QuestMobs AddOn by Tosaido.
  if unit.unitid then
    TooltipFrame:SetOwner(WorldFrame, "ANCHOR_NONE")
    --tooltip_frame:SetUnit(unitid)
    TooltipFrame:SetHyperlink("unit:" .. unit.guid)

    for i = 3, TooltipFrame:NumLines() do
      local line = _G["ThreatPlates_TooltipTextLeft" .. i]
      local text = line:GetText()
      local text_r, text_g, text_b = line:GetTextColor()

      if text_r > 0.99 and text_g > 0.82 and text_b == 0 then
        quest_area = true
      else
        local unit_name, progress = string.match(text, "^ ([^ ]-) ?%- (.+)$")
        -- local area_progress = string.match(progress, "(%d+)%%$")

        if progress then
          quest_area = nil

          if unit_name then
            local current, goal = string.match(progress, "(%d+)/(%d+)")

            -- A unit may be target of more than one quest, the quest indicator should be show if at least one quest is not completed.
            if current and goal then
              if (current ~= goal) then
                if (unit_name == "" or unit_name == PlayerName) then
                  quest_player = true
                else
                  quest_group = true
                end

                currentProgress = {
                  ['current'] = current,
                  ['goal'] = goal
                }

                break
              end
            else
              if (unit_name == "" or unit_name == PlayerName) then
                quest_player = true
              else
                quest_group = true
              end
              break
            end
          end
        end
      end
    end
  end

  local quest_type = ((quest_player or quest_area) and 1) or (quest_group and 2)

  return quest_type ~= false, quest_type, currentProgress
end

local function ShowQuestUnit(unit)
  local db = TidyPlatesThreat.db.profile.questWidget

  if IsInInstance() and db.HideInInstance then
    return false
  end

  if InCombatLockdown() or InCombat then
    if db.HideInCombat then
      return false
    elseif db.HideInCombatAttacked then
      local _, threatStatus = UnitDetailedThreatSituation("player", unit.unitid)
      return (threatStatus == nil)
    end
  end

  return true
end

local function ShowQuestUnitHealthbar(unit)
  local db = TidyPlatesThreat.db.profile.questWidget
  return db.ON and db.ModeHPBar and ShowQuestUnit(unit)
end

ThreatPlates.IsQuestUnit = IsQuestUnit
ThreatPlates.ShowQuestUnit = ShowQuestUnitHealthbar

local function EventHandler(event, ...)
  Widget:UpdateAllFramesAndNameplateColor()
end

function Widget:PLAYER_REGEN_ENABLED()
  InCombat = false
  Widget:UpdateAllFrames()
end

function Widget:PLAYER_REGEN_DISABLED()
  InCombat = true
  Widget:UpdateAllFrames()
end

function Widget:UNIT_THREAT_LIST_UPDATE(unitid)
  if not unitid or unitid == 'player' or UnitIsUnit('player', unitid) then return end

  local plate = GetNamePlateForUnit(unitid)
  if plate and plate.TPFrame.Active then
    local widget_frame = plate.TPFrame.widgets.Quest
    if widget_frame.Active then
      self:UpdateFrame(widget_frame, plate.TPFrame.unit)
      Addon:UpdateIndicatorNameplateColor(plate.TPFrame)
    end
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
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
  widget_frame.Icon = widget_frame:CreateTexture(nil, "OVERLAY")
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  return TidyPlatesThreat.db.profile.questWidget.ON or TidyPlatesThreat.db.profile.questWidget.ShowInHeadlineView
end

function Widget:OnEnable()
  self:RegisterEvent("QUEST_ACCEPTED", EventHandler)
  self:RegisterEvent("QUEST_WATCH_UPDATE", EventHandler)
  -- BfA: self:RegisterEvent("QUEST_ITEM_UPDATE", EventHandler)
  self:RegisterEvent("PLAYER_ENTERING_WORLD", EventHandler)
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("UNIT_THREAT_LIST_UPDATE")

  InCombat = InCombatLockdown()
end

function Widget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return TidyPlatesThreat.db.profile.questWidget.ShowInHeadlineView
  elseif style ~= "etotem" then
    return TidyPlatesThreat.db.profile.questWidget.ON
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  local db = TidyPlatesThreat.db.profile.questWidget
  widget_frame:SetSize(db.scale, db.scale)
  widget_frame:SetAlpha(db.alpha)

  ICON_COLORS[1] = db.ColorPlayerQuest
  ICON_COLORS[2] = db.ColorGroupQuest

  local icon_path = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\QuestWidget\\" .. db.IconTexture
  widget_frame.Icon:SetTexture(icon_path)
  widget_frame.Icon:SetAllPoints()

  self:UpdateFrame(widget_frame, unit)
end

function Widget:UpdateFrame(widget_frame, unit)
  local show, quest_type, current = IsQuestUnit(unit)

  local db = TidyPlatesThreat.db.profile.questWidget
  if show and db.ModeIcon and ShowQuestUnit(unit) then

    print(current.current .. '/' .. current.goal) --TODO: REMOVE, debugging only

    -- Updates based on settings / unit style
    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
      widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x_hv, db.y_hv)
    else
      widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
    end

    local color = ICON_COLORS[quest_type]
    widget_frame.Icon:SetVertexColor(color.r, color.g, color.b)

    widget_frame:Show()
  else
    widget_frame:Hide()
  end
end
