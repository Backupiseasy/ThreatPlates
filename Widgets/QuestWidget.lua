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
local string, tonumber, next, pairs, ipairs = string, tonumber, next, pairs, ipairs

-- WoW APIs
local _G, WorldFrame, CreateFrame = _G, WorldFrame, CreateFrame
local InCombatLockdown, IsInInstance = InCombatLockdown, IsInInstance
local UnitName, UnitIsUnit, UnitDetailedThreatSituation = UnitName, UnitIsUnit, UnitDetailedThreatSituation
local GetNumQuestLeaderBoards, GetQuestObjectiveInfo, GetQuestLogTitle, GetNumQuestLogEntries, GetQuestLogIndexByID = GetNumQuestLeaderBoards, GetQuestObjectiveInfo, GetQuestLogTitle, GetNumQuestLogEntries, GetQuestLogIndexByID
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local ON_UPDATE_INTERVAL = Addon.ON_UPDATE_PER_FRAME

local InCombat = false
local TooltipFrame = CreateFrame("GameTooltip", "ThreatPlates_Tooltip", nil, "GameTooltipTemplate")
local PlayerName = UnitName("player")
local ICON_COLORS = {}
local Font

local FONT_SCALING = 0.3
local TEXTURE_SCALING = 0.5
local ICON_PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\QuestWidget\\"

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local QuestLogNotComplete = true
local QuestUpdatePending = false
local QuestAcceptedUpdatePending = false
local QuestList, QuestIDs, QuestsToUpdate = {}, {}, {}
local QuestUnitsToUpdate = {}

local IsQuestUnit -- Function

-- Since patch 8.3, quest tooltips have a different format depending on the localization, it seems
-- at least for kill quests
local PARSER_QUEST_OBJECTIVE_BACKUP = function(text)
  local current, goal, objective_name = string.match(text,"^(%d+)/(%d+)( .*)$")

  if not objective_name then
    objective_name, current, goal = string.match(text,"^(.*): (%d+)/(%d+)$")
  end

  return objective_name, current, goal
end

--local PARSER_QUEST_OBJECTIVE_LEFT = function(text)
--  local current, goal, objective_name = string.match(text,"^(%d+)/(%d+)( .*)$")
--  return objective_name, current, goal
--end
--
--local PARSER_QUEST_OBJECTIVE_RIGHT = function(text)
--  return string.match(text,"^(.*): (%d+)/(%d+)$")
--end
--
--local STANDARD_QUEST_TARGET_PARSER = {
--  -- Objective name: x/y
--  deDE = PARSER_QUEST_OBJECTIVE_RIGHT,
--  frFR = PARSER_QUEST_OBJECTIVE_RIGHT,
--  ruRU = PARSER_QUEST_OBJECTIVE_RIGHT,
--  itIT = PARSER_QUEST_OBJECTIVE_RIGHT,
--  ptBR = PARSER_QUEST_OBJECTIVE_RIGHT,
--
--  -- x/y Objective name
--  enUS = PARSER_QUEST_OBJECTIVE_LEFT,
--  enGB = PARSER_QUEST_OBJECTIVE_LEFT,
--  esES = PARSER_QUEST_OBJECTIVE_LEFT,
--  esMX = PARSER_QUEST_OBJECTIVE_LEFT,
--  koKR = PARSER_QUEST_OBJECTIVE_LEFT,
--  zhTW = PARSER_QUEST_OBJECTIVE_LEFT,
--  zhCN = PARSER_QUEST_OBJECTIVE_LEFT,
--}
--
--local QuestTargetParser = STANDARD_QUEST_TARGET_PARSER[GetLocale()] or PARSER_QUEST_OBJECTIVE_BACKUP

---------------------------------------------------------------------------------------------------
-- Update Hook to compensate for deleyed quest information update on unit tooltips
---------------------------------------------------------------------------------------------------
local function WatchforQuestUpdateOnTooltip(self, elapsed)
  -- Update the number of seconds since the last update
  self.TimeSinceLastUpdate = (self.TimeSinceLastUpdate or 0) + elapsed

  if self.TimeSinceLastUpdate >= ON_UPDATE_INTERVAL then
    self.TimeSinceLastUpdate = 0

    -- Rest watch list and check again
    self.WatchTooltip = nil
    IsQuestUnit(self.unit)

    if not self.WatchTooltip then
      self.WatchTooltip = nil
      self:SetScript("OnUpdate", nil)

      Widget:UpdateFrame(self, self.unit) -- Calls IsQuestUnit again, but right now no way to not do that
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Quest Functions
---------------------------------------------------------------------------------------------------

function IsQuestUnit(unit, create_watcher)
  if not unit.unitid then return false, false, nil end

  local quest_title
  -- local unit_name
  local quest_player = true
  local quest_progress = false

  -- Read quest information from tooltip. Thanks to Kib: QuestMobs AddOn by Tosaido.
  TooltipFrame:SetOwner(WorldFrame, "ANCHOR_NONE")
  --TooltipFrame:SetUnit(unitid)
  TooltipFrame:SetHyperlink("unit:" .. unit.guid)

  for i = 3, TooltipFrame:NumLines() do
    local line = _G["ThreatPlates_TooltipTextLeft" .. i]
    local text = line:GetText()
    local text_r, text_g, text_b = line:GetTextColor()

    -- print ("Line: |" .. text .. "|")
    -- print ("  => ", text_r, text_g, text_b)
    if text_r > 0.99 and text_g > 0.82 and text_b == 0 then
      -- A line with this color is either the quest title or a player name (if on a group quest, but always after the quest title)
      if quest_title then
        quest_player = (text == PlayerName)
        -- unit_name = text
      else
        quest_title = text
      end
    elseif quest_title and quest_player then
      local objective_name, current, goal
      local objective_type = false

      -- Check if area / progress quest
      if string.find(text, "%%") then
        objective_name, current, goal = string.match(text, "^(.*) %((%d+)%%%)$")
        objective_type = "area"
        --print (unit_name, "=> ", "Area: |" .. text .. "|",  string.match(text, "^(.*) %((%d+)%%%)$"))
      else
        -- Standard x/y /pe quest
        objective_name, current, goal = PARSER_QUEST_OBJECTIVE_BACKUP(text)
        -- objective_name, current, goal = QuestTargetParser(text)
        -- print (unit_name, "=> ", "Standard: |" .. text .. "|", objective_name, current, goal, "|")
      end

      if objective_name then
        current = tonumber(current)

        if objective_type then
          goal = 100
        else
          goal = tonumber(goal)
        end

        -- Note: "progressbar" type quest (area quest) progress cannot get via the API, so for this tooltips
        -- must be used. That's also the reason why their progress is not cached.
        local Quests = QuestList
        -- print ("Goal:", quest_title, objective_name, current, goal)
        if Quests[quest_title] then
          local quest_objective = Quests[quest_title].objectives[objective_name]
          if quest_objective then
            current = quest_objective.current
            goal = quest_objective.goal
            objective_type = quest_objective.type
          end
        end

        -- A unit may be target of more than one quest, the quest indicator should be show if at least one quest is not completed.
        if current and goal then
          if (current ~= goal) then
            return true, 1, { current = current, goal = goal, type = objective_type }
          end
        else
          -- Line after quest title with quest information, so we can stop here
          return false
        end
      end
    end
  end

  return false
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

function Widget:CreateQuest(questID, questIndex)
  local Quest = {
    ["id"] = questID,
    ["index"] = questIndex,
    ["objectives"] = {}
  }

  function Quest:UpdateObjectives()
    local objectives = GetNumQuestLeaderBoards(self.index)

    for objIndex = 1, objectives do
      local text, objectiveType, finished, numFulfilled, numRequired = GetQuestObjectiveInfo(self.id, objIndex, false)

      -- Occasionally the game will return nil text, this happens when some world quests/bonus area quests finish (the objective no longer exists)
      -- Does not make sense to add "progressbar" type quests here as there progress is not updated via QUEST_WATCH_UPDATE
      if text and objectiveType ~= "progressbar" then
        local objectiveName = string.gsub(text, "(%d+)/(%d+)", "")

        -- Normally, the quest objective should come before the :, but while the QUEST_LOG_UPDATE events (after login/reload)
        -- GetQuestObjectiveInfo just returns nil as text
        QuestLogNotComplete = QuestLogNotComplete or (objectiveName == " : ")

        --only want to track quests in this format
        if numRequired and numRequired > 1 then
          if self.objectives[objectiveName] then
            local obj = self.objectives[objectiveName]

            obj.current = numFulfilled
            obj.goal = numRequired
          else --new objective
            self.objectives[objectiveName] = {
              ["type"] = objectiveType,
              ["current"] = numFulfilled,
              ["goal"] = numRequired
            }
          end
        end
      end
    end
  end

  return Quest
end

function Widget:AddQuestCacheEntry(questIndex)
  local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(questIndex)

  if not isHeader and title then --ignore quest log headers
    local quest = Widget:CreateQuest(questID, questIndex)

    quest:UpdateObjectives()

    QuestList[title] = quest
    QuestIDs[questID] = title --so it can be found by remove
  end
end

function Widget:UpdateQuestCacheEntry(questIndex, title)
  if not QuestList[title] then --for whatever reason it doesn't exist, so just add it
    self:AddQuestCacheEntry(questIndex)
    return
  end

  --update Objectives
  local quest = QuestList[title]

  quest:UpdateObjectives()
  quest.index = questIndex
end

function Widget:GenerateQuestCache()
  local entries = GetNumQuestLogEntries()

  QuestList = {}
  QuestIDs = {}

  for questIndex = 1, entries do
    self:AddQuestCacheEntry(questIndex)
  end
end

---------------------------------------------------------------------------------------------------
-- Event Watcher Code for Quest Widget
---------------------------------------------------------------------------------------------------

function Widget:PLAYER_ENTERING_WORLD()
	self:UpdateAllFramesAndNameplateColor()
end

function Widget:QUEST_WATCH_UPDATE(questIndex)
  local title, _, _, _, _, _, _, questID = GetQuestLogTitle(questIndex)

  if not title then
    return
  end

  QuestsToUpdate[questID] = title
end

function Widget:UNIT_QUEST_LOG_CHANGED(...)
  QuestUpdatePending = true
end

function Widget:QUEST_LOG_UPDATE()
  -- QuestUpdatePending being true means that UNIT_QUEST_LOG_CHANGED was fired (possibly several times)
  -- So there should be quest progress => update all plates with the current progress.
  if QuestUpdatePending then
    QuestUpdatePending = false

    -- Update the cached quest progress (for non-progressbar quests) after QUEST_WATCH_UPDATE
    local QuestsToUpdate = QuestsToUpdate
    for questID, title in pairs(QuestsToUpdate) do
      local questIndex = GetQuestLogIndexByID(questID)

      self:UpdateQuestCacheEntry(questIndex, title)
      QuestsToUpdate[questID] = nil
    end

    -- We need to do this to update all progressbar quests - their quest progress cannot be cached
    self:UpdateAllFramesAndNameplateColor()
  end

  if QuestLogNotComplete then
    QuestLogNotComplete = false
    self:GenerateQuestCache()
  end
end

function Widget:QUEST_ACCEPTED(questIndex, questID)
  self:AddQuestCacheEntry(questIndex)
  QuestAcceptedUpdatePending = true
end

function Widget:QUEST_POI_UPDATE()
  -- print ("QUEST_POI_UPDATE: ", QuestAcceptedUpdatePending)
  if QuestAcceptedUpdatePending then
    self:UpdateAllFramesAndNameplateColor()
    QuestAcceptedUpdatePending = false
  end
end

function Widget:QUEST_REMOVED(quest_id)
  local quest_title = QuestIDs[quest_id]

  --clean up cache
  if quest_title then
    QuestIDs[quest_id] = nil
    QuestList[quest_title] = nil
    QuestsToUpdate[quest_id] = nil
  end

  self:UpdateAllFramesAndNameplateColor()
end

function Widget:PLAYER_REGEN_DISABLED()
  InCombat = true
  self:UpdateAllFramesAndNameplateColor()
  end

function Widget:PLAYER_REGEN_ENABLED()
  InCombat = false
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

  local text_frame = widget_frame:CreateFontString(nil, "OVERLAY")
  local type_frame = widget_frame:CreateTexture(nil, "OVERLAY")

  text_frame:SetFont(Font, db.FontSize + (db.scale * FONT_SCALING))
  text_frame:SetShadowOffset(1, - 1)
  text_frame:SetShadowColor(0, 0, 0, 1)
  text_frame.TypeTexture = type_frame

  widget_frame.Text = text_frame
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  return TidyPlatesThreat.db.profile.questWidget.ON or TidyPlatesThreat.db.profile.questWidget.ShowInHeadlineView
end

function Widget:OnEnable()
  Font = ThreatPlates.Media:Fetch('font', TidyPlatesThreat.db.profile.questWidget.Font)

  self:GenerateQuestCache()

  self:RegisterEvent("PLAYER_ENTERING_WORLD")

  self:RegisterEvent("QUEST_ACCEPTED")
  -- This event fires whenever the player turns in a quest, whether automatically with a Task-type quest
  -- (Bonus Objectives/World Quests), or by pressing the Complete button in a quest dialog window.
  -- also handles abandon quest
  self:RegisterEvent("QUEST_REMOVED")
  self:RegisterEvent("QUEST_WATCH_UPDATE")

  self:RegisterEvent("QUEST_LOG_UPDATE")
  self:RegisterEvent("QUEST_POI_UPDATE")
  self:RegisterUnitEvent("UNIT_QUEST_LOG_CHANGED", "player")

  -- Handle in-combat situations:
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  -- Also use UNIT_THREAT_LIST_UPDATE as new mobs may enter the combat mid-fight (PLAYER_REGEN_DISABLED already triggered)
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

  widget_frame.Icon:SetTexture(ICON_PATH .. db.IconTexture)
  widget_frame.Icon:SetAllPoints()

  self:UpdateFrame(widget_frame, unit)
end

function Widget:UpdateFrame(widget_frame, unit)
  local show, quest_type, current = IsQuestUnit(unit, true)

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

    if db.ShowProgress and current and current.goal > 1 then
      --NOTE: skip showing for quests that have 1 of something, as WoW uses this for things like events eg "Push back the alliance 0/1"

      local text
      if current.type == "area" then
        text = current.current .. '%'

        if unit.reaction ~= "FRIENDLY" then
          widget_frame.Text.TypeTexture:SetTexture(ICON_PATH .. "kill")
        end
      else
        text = current.current .. '/' .. current.goal

        if current.type == "monster" then
          widget_frame.Text.TypeTexture:SetTexture(ICON_PATH .. "kill")
        elseif current.type == "item" then
          widget_frame.Text.TypeTexture:SetTexture(ICON_PATH .. "loot")
        end
      end

      widget_frame.Text:SetText(text)
      widget_frame.Text:SetTextColor(color.r, color.g, color.b)

      widget_frame.Text:SetPoint("CENTER", widget_frame, db.scale * 0.1, db.scale * 0.9)

      widget_frame.Text:SetFont(Font, db.FontSize + (db.scale * FONT_SCALING))
      widget_frame.Text:SetJustifyH("LEFT");

      widget_frame.Text.TypeTexture:SetPoint("LEFT", widget_frame.Text, db.scale * -0.6, 1)
      widget_frame.Text.TypeTexture:SetSize(db.scale * TEXTURE_SCALING, db.scale * TEXTURE_SCALING)

      widget_frame.Text:Show()
      widget_frame.Text.TypeTexture:Show()
    else
      widget_frame.Text:Hide()
      widget_frame.Text.TypeTexture:Hide()
    end

    widget_frame:Show()
  else
    widget_frame:Hide()
  end
end

local function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function Addon:PrintQuests()
  print ("Quests List:", tablelength(QuestIDs))
  for quest_id, title in pairs(QuestIDs) do
    local quest = QuestList[title]
    if quest.objectives and tablelength(quest.objectives) > 0 then
      print ("*", title .. " [ID:" .. tostring(quest_id) .. "]")
      for name, val in pairs (quest.objectives) do
        print ("  - |", name .."| :", val.current, "/", val.goal, "[" .. val.type .. "]")
      end
    end
  end

  -- Only plates of units that are quest units are stored in QuestUnitsToUpdate
  for index, unitid in ipairs(QuestUnitsToUpdate) do
    QuestUnitsToUpdate[index] = nil

    local plate = GetNamePlateForUnit(unitid)
    if plate and plate.TPFrame.Active then
      local widget_frame = plate.TPFrame.widgets.Quest
      self:UpdateFrame(widget_frame, plate.TPFrame.unit)
    end

    print ("Updating Quest Unit", unitid)
  end

  print ("QuestUnitsToUpdate:", tablelength(QuestUnitsToUpdate))

  print ("Waiting for quest log updates for the following quests:")
  for questID, title in pairs(QuestsToUpdate) do
    local questIndex = GetQuestLogIndexByID(questID)
    print ("  Quest:", title .. " [" .. tostring(questIndex) .. "]")
  end
end