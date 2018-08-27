---------------------------------------------------------------------------------------------------
-- Quest Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewWidget("Quest")

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
local Font = nil

local FONT_SCALING = 0.3
local TEXTURE_SCALING = 0.5
local ICON_PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\QuestWidget\\"

local Quests = {}

---------------------------------------------------------------------------------------------------
-- Quest Functions
---------------------------------------------------------------------------------------------------

local function IsQuestUnit(unit)
  local quest_area = false
  local quest_player = false
  local quest_group = false
  local quest_title = false
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

      if text_r > 0.99 and text_g > 0.82 and text_b == 0 then --quest header
        quest_area = true
        quest_title = text
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

                local objType = false

                if Quests[quest_title] then
                  objType = Quests[quest_title].type
                end

                currentProgress = {
                  ['current'] = current,
                  ['goal'] = goal,
                  ['type'] = objType
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

function Addon:IsPlayerQuestUnit(unit)
	local show, quest_type = IsQuestUnit(unit)
	return show and (quest_type == 1) -- don't show quest color for party member#s quest targets
end

local function ShowQuestUnit(unit)
  local db = TidyPlatesThreat.db.profile.questWidget

  if IsInInstance() and db.HideInInstance then
    return false
  end

  if InCombatLockdown() or InCombat then -- InCombat is necessary here - at least was - forgot why, though
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

ThreatPlates.ShowQuestUnit = ShowQuestUnitHealthbar

local function AddQuestCacheEntry(questIndex)
  local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(questIndex)

  if not isHeader then --ignore quest log headers
    local objectives = GetNumQuestLeaderBoards(questIndex)

    for o=1, objectives do
      local text, objectiveType, finished = GetQuestObjectiveInfo(questID, o, false)

      if not finished then
        Quests[title] = {
          ["id"] = questID,
          ["type"] = objectiveType
        }

        Quests[questID] = title
        break
      end
    end
  end
end

local function GenerateQuestCache()
  local entries = GetNumQuestLogEntries()

  Quests = {}

  for questIndex=1, entries do
    AddQuestCacheEntry(questIndex)
  end
end

---------------------------------------------------------------------------------------------------
-- Event Watcher Code for Quest Widget
---------------------------------------------------------------------------------------------------
local function EventHandler(event, ...)
  Widget:UpdateAllFramesAndNameplateColor()

  if event == "QUEST_ACCEPTED" then
    local questIndex, questID = ...

    AddQuestCacheEntry(questIndex)
  end
end

function Widget:QUEST_REMOVED(questId)
  --clean up cache
  if Quests[questId] then
    local questTitle = Quests[questId]

    Quests[questTitle] = nil
    Quests[questId] = nil
  end
end

function Widget:PLAYER_REGEN_ENABLED()
  InCombat = false
  self:UpdateAllFramesAndNameplateColor()
end

function Widget:PLAYER_REGEN_DISABLED()
  InCombat = true
  self:UpdateAllFramesAndNameplateColor()
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
  local db = TidyPlatesThreat.db.profile.questWidget

  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
  widget_frame.Icon = widget_frame:CreateTexture(nil, "OVERLAY")
  widget_frame.Text = false

  if db.ShowDetail then
    local text_frame = widget_frame:CreateFontString(nil, "OVERLAY")
    local type_frame = widget_frame:CreateTexture(nil, "OVERLAY")

    text_frame:SetFont(Font, db.FontSize + (db.scale * FONT_SCALING))
    text_frame:SetShadowOffset(1, -1)
    text_frame:SetShadowColor(0,0,0,1)
    text_frame.TypeTexture = type_frame

    widget_frame.Text = text_frame
  end
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  return TidyPlatesThreat.db.profile.questWidget.ON or TidyPlatesThreat.db.profile.questWidget.ShowInHeadlineView
end

function Widget:OnEnable()
  Font = ThreatPlates.Media:Fetch('font', TidyPlatesThreat.db.profile.questWidget.Font)

	self:RegisterEvent("PLAYER_ENTERING_WORLD", EventHandler)

	self:RegisterEvent("QUEST_ACCEPTED", EventHandler)
	self:RegisterEvent("QUEST_WATCH_UPDATE", EventHandler)
	-- This event fires whenever the player turns in a quest, whether automatically with a Task-type quest
	-- (Bonus Objectives/World Quests), or by pressing the Complete button in a quest dialog window.
  -- also handles abandon quest
	self:RegisterEvent("QUEST_REMOVED", EventHandler)

	-- Handle in-combat situations:
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	-- Also use UNIT_THREAT_LIST_UPDATE as new mobs may enter the combat mid-fight (PLAYER_REGEN_DISABLED already triggered)
	self:RegisterEvent("UNIT_THREAT_LIST_UPDATE")

  InCombat = InCombatLockdown()
  GenerateQuestCache()
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

  widget_frame.Icon:SetTexture(ICON_PATH .. db.IconTexture)
  widget_frame.Icon:SetAllPoints()

  if db.ShowDetail and widget_frame.Text then
    widget_frame.Text:SetPoint("CENTER", widget_frame, db.scale * 0.5, db.scale * 0.75)
    widget_frame.Text:SetSize(db.scale * 1.4, db.scale)
    widget_frame.Text:SetFont(Font, db.FontSize + (db.scale * FONT_SCALING))
    widget_frame.Text:SetAlpha(db.alpha)

    widget_frame.Text.TypeTexture:SetPoint("CENTER", widget_frame, -(db.scale * 0.5), (db.scale * 0.75) + 1)
    widget_frame.Text.TypeTexture:SetSize(db.scale * TEXTURE_SCALING, db.scale * TEXTURE_SCALING)
    widget_frame.Text.TypeTexture:SetAlpha(db.alpha)
  end

  self:UpdateFrame(widget_frame, unit)
end

function Widget:UpdateFrame(widget_frame, unit)
  local show, quest_type, current = IsQuestUnit(unit)

  local db = TidyPlatesThreat.db.profile.questWidget
  if show and db.ModeIcon and ShowQuestUnit(unit) then

    -- Updates based on settings / unit style
    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
      widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x_hv, db.y_hv)
    else
      widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
    end

    local color = ICON_COLORS[quest_type]
    widget_frame.Icon:SetVertexColor(color.r, color.g, color.b)

    if db.ShowDetail and
      current and
      tonumber(current.goal) > 1 and --NOTE: skip showing for quests that have 1 of something, as WoW uses this for things like events eg "Push back the alliance 0/1"
      widget_frame.Text then

      local text = current.current .. '/' .. current.goal

      if current.type == "monster" then
        widget_frame.Text.TypeTexture:SetTexture(ICON_PATH .. "kill")
      elseif current.type == "item" then
        widget_frame.Text.TypeTexture:SetTexture(ICON_PATH .. "loot")
      else
        --set text to be center as no texture to load (invalid quest type)
        widget_frame.Text:SetPoint("CENTER", widget_frame, 0, db.scale * 0.75)
      end

      widget_frame.Text:SetText(text)
      widget_frame.Text:SetTextColor(color.r, color.g, color.b)
      widget_frame.Text:Show()
      widget_frame.Text.TypeTexture:Show()
    elseif widget_frame.Text then
      widget_frame.Text:Hide()
      widget_frame.Text.TypeTexture:Hide()
    end

    widget_frame:Show()
  else
    widget_frame:Hide()
  end
end
