---------------------------------------------------------------------------------------------------
-- Quest Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = ((Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC) and {}) or Addon.Widgets:NewWidget("Quest")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local string, tonumber, next, pairs, ipairs = string, tonumber, next, pairs, ipairs

-- WoW APIs
local WorldFrame = WorldFrame
local InCombatLockdown, IsInInstance = InCombatLockdown, IsInInstance
local UnitName, UnitIsUnit = UnitName, UnitIsUnit
local UnitExists = UnitExists
local IsInRaid, IsInGroup, GetNumGroupMembers, GetNumSubgroupMembers = IsInRaid, IsInGroup, GetNumGroupMembers, GetNumSubgroupMembers
local wipe = wipe

local RequestLoadQuestByID = C_QuestLog.RequestLoadQuestByID
local GetQuestObjectives, GetQuestInfo = C_QuestLog.GetQuestObjectives, C_QuestLog.GetInfo
local GetQuestIDForLogIndex, GetLogIndexForQuestID = C_QuestLog.GetQuestIDForLogIndex, C_QuestLog.GetLogIndexForQuestID
local GetQuestLogTitle, GetNumQuestLogEntries = C_QuestLog.GetQuestLogTitle, C_QuestLog.GetNumQuestLogEntries
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local PlayerName = Addon.PlayerName
local UnitDetailedThreatSituationWrapper = Addon.UnitDetailedThreatSituationWrapper

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

local InCombat = false
local TooltipFrame = CreateFrame("GameTooltip", "ThreatPlates_Tooltip", nil, "GameTooltipTemplate")
local ICON_COLORS = {}
local Font

local FONT_SCALING = 0.3
local TEXTURE_SCALING = 0.5
local ICON_PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\QuestWidget\\"

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local QuestLogNotComplete = true
local UnitQuestLogChanged = false
--local QuestAcceptedUpdatePending = true
local FirstPOIUpateAfterLogin = true
local QuestByTitle, QuestByID, QuestsToUpdate = {}, {}, {}
local QuestUnitsToUpdate = {}
local GroupMembers = {}

local IsQuestUnit -- Function

-- Since patch 8.3, quest tooltips have a different format depending on the localization, it seems
-- at least for kill quests
-- In Shadowlands, it seems that the format is randomly changed, at least for German, so check for
-- everything as a backup
local QUEST_OBJECTIVE_PARSER_LEFT = function(text)
  local current, goal, objective_name = string.match(text,"^(%d+)/(%d+)( .*)$")

  if not objective_name then
    objective_name, current, goal = string.match(text,"^(.*: )(%d+)/(%d+)$")
  end

  return objective_name, current, goal
end

local QUEST_OBJECTIVE_PARSER_RIGHT = function(text)
  -- Quest objective: Versucht, zu kommunizieren: 0/1
  local objective_name, current, goal = string.match(text,"^(.*: )(%d+)/(%d+)$")

  if not objective_name then
    -- Quest objective: 0/1 Besucht die Halle der Kuriositäten
    current, goal, objective_name = string.match(text,"^(%d+)/(%d+)( .*)$")
  end

  return objective_name, current, goal
end

local STANDARD_QUEST_OBJECTIVE_PARSER = {
  -- x/y Objective
  enUS = QUEST_OBJECTIVE_PARSER_LEFT,
  -- enGB = enGB clients return enUS
  esMX = QUEST_OBJECTIVE_PARSER_LEFT,
  ptBR = QUEST_OBJECTIVE_PARSER_LEFT,
  itIT = QUEST_OBJECTIVE_PARSER_LEFT,
  koKR = QUEST_OBJECTIVE_PARSER_LEFT,
  zhTW = QUEST_OBJECTIVE_PARSER_LEFT,
  zhCN = QUEST_OBJECTIVE_PARSER_LEFT,

  -- Objective: x/y
  deDE = QUEST_OBJECTIVE_PARSER_RIGHT,
  frFR = QUEST_OBJECTIVE_PARSER_RIGHT,
  esES = QUEST_OBJECTIVE_PARSER_RIGHT,
  ruRU = QUEST_OBJECTIVE_PARSER_RIGHT,
}

local QuestObjectiveParser = STANDARD_QUEST_OBJECTIVE_PARSER[GetLocale()] or QUEST_OBJECTIVE_PARSER_LEFT

---------------------------------------------------------------------------------------------------
-- Quest Functions
---------------------------------------------------------------------------------------------------

function IsQuestUnit(unit)
  if not unit.unitid then return false, false, nil end

  local quest_title
  local quest_progress_player = false

  -- Read quest information from tooltip. Thanks to Kib: QuestMobs AddOn by Tosaido.
  TooltipFrame:SetOwner(WorldFrame, "ANCHOR_NONE")
  --TooltipFrame:SetUnit(unitid)
  TooltipFrame:SetHyperlink("unit:" .. unit.guid)

  for i = 3, TooltipFrame:NumLines() do
    local line = _G["ThreatPlates_TooltipTextLeft" .. i]
    local text = line:GetText()
    local text_r, text_g, text_b = line:GetTextColor()

    if text_r > 0.99 and text_g > 0.82 and text_b == 0 then
      -- A line with this color is either the quest title or a player name (if on a group quest, but always after the quest title)
      if text == PlayerName then
        quest_progress_player = true
      elseif not GroupMembers[text] then
        quest_progress_player = true
        quest_title = text
      else
        quest_progress_player = false
      end
    elseif quest_progress_player then
      local objective_name, current, goal
      local objective_type = false

      -- Check if area / progress quest
      if string.find(text, "%%") then
        objective_name, current, goal = string.match(text, "^(.*) %(?(%d+)%%%)?$")
        objective_type = "area"
        --print ("  ", unit.name, "=> ", "Area: <" .. text .. ">", objective_name, current, goal)
      else
        -- Standard x/y /pe quest
        objective_name, current, goal = QuestObjectiveParser(text)
        --print ("  ", unit.name, "=> ", "Standard: <" .. text .. ">", objective_name, current, goal, "|")
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
        local quest = QuestByTitle[quest_title]
        local quest_objective
        if quest then
          quest_objective = quest.Objectives[objective_name]
        --else
        --  print ("<< Quest No Cached >> =>", quest_title)
        end

        -- A unit may be target of more than one quest, the quest indicator should be show if at least one quest is not completed.
        if current and goal then
          if (current ~= goal) then
            return true, 1, quest_objective or { numFulfilled = current, numRequired = goal, type = objective_type }
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
  local db = Addon.db.profile.questWidget

  if IsInInstance() and db.HideInInstance then
    return false
  end

  if InCombatLockdown() or InCombat then -- InCombat is necessary here - at least was - forgot why, though
    if db.HideInCombat then
      return false
    elseif db.HideInCombatAttacked then
      local _, threatStatus = UnitDetailedThreatSituationWrapper("player", unit.unitid)
      return (threatStatus == nil)
    end
  end

  return true
end

local function ShowQuestUnitHealthbar(unit)
  local db = Addon.db.profile.questWidget
  return db.ON and db.ModeHPBar and ShowQuestUnit(unit)
end

ThreatPlates.ShowQuestUnit = ShowQuestUnitHealthbar

local function CacheQuestObjectives(quest)
  quest.Objectives = quest.Objectives or {}

  local all_objectives = GetQuestObjectives(quest.questID)

  local objective
  for objIndex = 1, #all_objectives do
    objective = all_objectives[objIndex]

    -- Occasionally the game will return nil text, this happens when
    -- some world quests/bonus area quests finish (the objective no longer exists)
    -- Does not make sense to add "progressbar" type quests here as there progress is not
    -- updated via QUEST_WATCH_UPDATE
    if objective.text and objective.type ~= "progressbar" then
      local objective_name = string.gsub(objective.text, "(%d+)/(%d+)", "")
      -- Normally, the quest objective should come before the :, but while the QUEST_LOG_UPDATE events (after login/reload)

      -- It does seem that this is no longer necessary
      QuestLogNotComplete = QuestLogNotComplete or (objective_name == " : ")
      -- assert (objectiveName ~= " : ", "Error: " ..  objectiveName)

      --only want to track quests in this format
      -- numRequired > 1 prevents quest like "...: 0/1" from being tracked - not sure why it was/is here
      if objective.numRequired and objective.numRequired >= 1 then
        quest.Objectives[objective_name] = objective
      end
    end
  end
end

local function CacheQuestByQuestLogIndex(quest_log_index, quest_id)
  if quest_log_index then
    local quest = GetQuestInfo(quest_log_index)
    if quest then
      -- Ignore certain quests that need not to be tracked
      -- quest_info.isOnMap => would need to scan quest log when entering new areas
      if quest.title and not quest.isHeader then
        QuestByID[quest.questID] = quest.title -- So it can be found by remove
        QuestByTitle[quest.title] = quest

        CacheQuestObjectives(quest)
      end
    else
      QuestByID[quest_id] = "UpdatePending"
    end
  end
end

local function CacheQuestByQuestID(quest_id)
  if quest_id then
    local quest_log_index = GetLogIndexForQuestID(quest_id)
    CacheQuestByQuestLogIndex(quest_log_index, quest_id)
  end
end

function Widget:GenerateQuestCache()
  QuestByTitle = {}
  QuestByID = {}

  for quest_log_index = 1, GetNumQuestLogEntries() do
    CacheQuestByQuestLogIndex(quest_log_index)
  end
end

---------------------------------------------------------------------------------------------------
-- Event Watcher Code for Quest Widget
---------------------------------------------------------------------------------------------------

function Widget:QUEST_ACCEPTED(quest_id)

  CacheQuestByQuestID(quest_id)
  if QuestByID[quest_id] == "UpdatePending" then
    --print ("QUEST_ACCEPTED:", quest_id)
    --print ("  => Requesting quest information")
    RequestLoadQuestByID(quest_id)
    -- QuestAcceptedUpdatePending = true
  end
end

--function Widget:QUEST_AUTOCOMPLETE(quest_id)
--  print ("QUEST_AUTOCOMPLETE:", quest_id)
--end
--
--function Widget:QUEST_COMPLETE(quest_id)
--  print ("QUEST_COMPLETE:", quest_id)
--end

function Widget:QUEST_DATA_LOAD_RESULT(quest_id, success)
  if success and QuestByID[quest_id] == "UpdatePending" then
    --print ("QUEST_DATA_LOAD_RESULT:", quest_id, success)
    --print ("  => Loading delayed quest information")
    CacheQuestByQuestID(quest_id)
    self:UpdateAllFramesAndNameplateColor()
  end
end

--function Widget:QUEST_DETAIL(questStartItemID)
--  print ("QUEST_DETAIL:", questStartItemID)
--end
--
--function Widget:QUEST_LOG_CRITERIA_UPDATE(questID, specificTreeID, description, numFulfilled, numRequired)
--  print ("QUEST_LOG_CRITERIA_UPDATE:", questID, specificTreeID, description, numFulfilled, numRequired)
--end

function Widget:QUEST_LOG_UPDATE()
  -- UnitQuestLogChanged being true means that UNIT_QUEST_LOG_CHANGED was fired (possibly several times)
  -- So there should be quest progress => update all plates with the current progress.
  if UnitQuestLogChanged then
    --print ("QUEST_LOG_UPDATE => UnitQuestLogChanged")
    UnitQuestLogChanged = false

    -- Update the cached quest progress (for non-progressbar quests) after QUEST_WATCH_UPDATE
    for quest_id, title in pairs(QuestsToUpdate) do
      local quest = QuestByTitle[title]
      if quest then
        CacheQuestObjectives(quest)
      else
        -- For whatever reason it doesn't exist, so just add it
        CacheQuestByQuestID(quest_id)
      end

      QuestsToUpdate[quest_id] = nil
    end

    -- We need to do this to update all progressbar quests - their quest progress cannot be cached
    self:UpdateAllFramesAndNameplateColor()
  end

  -- It does seem that this is no longer necessary
  if QuestLogNotComplete then
    QuestLogNotComplete = false
    self:GenerateQuestCache()
  end
end

--function Widget:QUEST_POI_UPDATE()
--  print ("QUEST_POI_UPDATE:")
--  if QuestAcceptedUpdatePending then
--    -- After login, sometimes the quest list is empty when the widget is loaded.
--    -- So, update the internal quest list after the first POI update after login.
--    -- At that point, the quest list is available
--    if FirstPOIUpateAfterLogin then
--      FirstPOIUpateAfterLogin = false
--      -- The following should be an alternative as QUEST_LOG_UPDATE seems to be fired after QUEST_POI_UPDATE in every case
--      -- QuestLogNotComplete = true
--      self:GenerateQuestCache()
--    end
--
--    self:UpdateAllFramesAndNameplateColor()
--    QuestAcceptedUpdatePending = false
--  end
--end

function Widget:QUEST_REMOVED(quest_id, _)
  --print ("QUEST_REMOVED:", quest_id)

  -- Clean up cache
  local quest_title = QuestByID[quest_id]

  QuestByID[quest_id] = nil
  QuestsToUpdate[quest_id] = nil

  -- Plates only need to be updated if the quest was actually tracked
  if quest_title then
    QuestByTitle[quest_title] = nil
    self:UpdateAllFramesAndNameplateColor()
  end
end

--function Widget:QUEST_TURNED_IN(questID, xpReward, moneyReward)
--  print ("QUEST_TURNED_IN:", questID, xpReward, moneyReward)
--end
--
--function Widget:QUEST_WATCH_LIST_CHANGED(questID, added)
--  print ("QUEST_WATCH_LIST_CHANGED:", questID, added)
--end

function Widget:QUEST_WATCH_UPDATE(quest_id)
  --print ("QUEST_WATCH_UPDATE:", quest_id)
  local quest_log_index = GetLogIndexForQuestID(quest_id)
  if quest_log_index then
    local info = GetQuestInfo(quest_log_index)
    if info and info.title then
      QuestsToUpdate[quest_id] = info.title
    end
  end
end

--function Widget:QUESTLINE_UPDATE(requestRequired)
--end

--function Widget:WORLD_QUEST_COMPLETED_BY_SPELL(questID)
--  print ("QUEST_WATCH_LIST_CHANGED:", questID)
--end

function Widget:UNIT_QUEST_LOG_CHANGED(unitid)
  --if unitid ~= "player" then
  --  print ("UNIT_QUEST_LOG_CHANGED:", unitid)
  --end

  if unitid == "player" then
    UnitQuestLogChanged = true
  end
end

function Widget:PLAYER_ENTERING_WORLD()
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

function Widget:GROUP_ROSTER_UPDATE()
  local group_size = (IsInRaid() and GetNumGroupMembers()) or (IsInGroup() and GetNumSubgroupMembers()) or 0

--  local is_in_raid = IsInRaid()
--  local is_in_group = is_in_raid or IsInGroup()

  wipe(GroupMembers)

  if group_size > 0 then
    local group_type = (IsInRaid() and "raid") or IsInGroup() and "party" or "solo"

    for i = 1, group_size do
      --local unit_name = UnitName(group_type .. i)
      if UnitExists(group_type .. i) then
        --print("Adding member:", UnitName(group_type .. i))
        GroupMembers[UnitName(group_type .. i)] = true
      end
    end
  end


--  if is_in_group then
--    for i = 1, ((is_in_raid and GetNumGroupMembers()) or GetNumSubgroupMembers()) do
--      local unit_name = UnitName(group_type .. i)
--      --if unit_name then
--      --- end
--      if UnitExists(group_type .. i) then
--        print("Adding member:", UnitName(group_type .. i))
--        GroupMembers[UnitName(group_type .. i)] = true
--      end
--    end
--  end

end

function Widget:GROUP_LEFT()
  wipe(GroupMembers)
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  local db = Addon.db.profile.questWidget

  -- Required Widget Code
  local widget_frame = _G.CreateFrame("Frame", nil, tp_frame)
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
  local db = Addon.db.profile.questWidget
  return db.ON or db.ShowInHeadlineView
end

function Widget:OnEnable()
  self:GenerateQuestCache()

  self:RegisterEvent("QUEST_ACCEPTED")
  --self:RegisterEvent("QUEST_AUTOCOMPLETE")
  --self:RegisterEvent("QUEST_COMPLETE")
  self:RegisterEvent("QUEST_DATA_LOAD_RESULT")
  --self:RegisterEvent("QUEST_DETAIL")
  --self:RegisterEvent("QUEST_LOG_CRITERIA_UPDATE")
  self:RegisterEvent("QUEST_LOG_UPDATE")
  --self:RegisterEvent("QUEST_POI_UPDATE")
  -- QUEST_REMOVED fires whenever the player turns in a quest, whether automatically with a Task-type quest
  -- (Bonus Objectives/World Quests), or by pressing the Complete button in a quest dialog window.
  -- also handles abandon quest
  self:RegisterEvent("QUEST_REMOVED")
  --self:RegisterEvent("QUEST_TURNED_IN")
  --self:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
  self:RegisterEvent("QUEST_WATCH_UPDATE")
  --self:RegisterEvent("QUESTLINE_UPDATE")
  --self:RegisterEvent("WORLD_QUEST_COMPLETED_BY_SPELL")
  self:RegisterUnitEvent("UNIT_QUEST_LOG_CHANGED", "player")

  self:RegisterEvent("PLAYER_ENTERING_WORLD")

  -- Handle in-combat situations:
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  -- Also use UNIT_THREAT_LIST_UPDATE as new mobs may enter the combat mid-fight (PLAYER_REGEN_DISABLED already triggered)
  self:RegisterEvent("UNIT_THREAT_LIST_UPDATE")

  -- To handle objectives correctly when quest objectives of group memebers are shown in the tooltip, we need to keep a
  -- list of all players in the group
  self:RegisterEvent("GROUP_ROSTER_UPDATE")
  self:RegisterEvent("GROUP_LEFT")

  InCombat = InCombatLockdown()
  self:GROUP_ROSTER_UPDATE()
end

function Widget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return Addon.db.profile.questWidget.ShowInHeadlineView
  elseif style ~= "etotem" then
    return Addon.db.profile.questWidget.ON
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  local db = Addon.db.profile.questWidget
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

  local db = Addon.db.profile.questWidget
  if show and db.ModeIcon and ShowQuestUnit(unit) then

    -- Updates based on settings / unit style
    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
      widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x_hv, db.y_hv)
    else
      widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
    end

    local color = ICON_COLORS[quest_type]
    widget_frame.Icon:SetVertexColor(color.r, color.g, color.b)

    if db.ShowProgress and current and current.numRequired > 1 then
      --NOTE: skip showing for quests that have 1 of something, as WoW uses this for things like events eg "Push back the alliance 0/1"

      local text
      if current.type == "area" then
        text = current.numFulfilled .. '%'

        if unit.reaction ~= "FRIENDLY" then
          widget_frame.Text.TypeTexture:SetTexture(ICON_PATH .. "kill")
        end
      else
        text = current.numFulfilled .. '/' .. current.numRequired

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

-- Load settings from the configuration which are shared across all aura widgets
-- used (for each widget) in UpdateWidgetConfig
function Widget:UpdateSettings()
  Font = Addon.LibSharedMedia:Fetch('font', Addon.db.profile.questWidget.Font)
end

function Addon:PrintQuests(command)
  local quest_id = tonumber(command)
  if quest_id then
    local quest_log_index = GetLogIndexForQuestID(quest_id)
    Addon.Logging.Debug("Quest" .. tostring(quest_id) .. ": Log-Nr =", quest_log_index)
    if quest_log_index then
      local quest_info = GetQuestInfo(quest_log_index)
      if quest_info then
        Addon.Debug.PrintTable(quest_info)

        local objectives = GetQuestObjectives(quest_id)
        Addon.Debug.PrintTable(objectives)
      end
    end
  elseif command == "tooltip" then
    if not UnitExists("target") then return end

    for name, _ in pairs(GroupMembers) do
      Addon.Logging.Debug("Character:", name)
    end

    local quest_title
    local quest_progress_player = false

    -- Read quest information from tooltip. Thanks to Kib: QuestMobs AddOn by Tosaido.
    TooltipFrame:SetOwner(WorldFrame, "ANCHOR_NONE")
    --TooltipFrame:SetUnit(unitid)
    TooltipFrame:SetHyperlink("unit:" .. UnitGUID("target"))

    for i = 3, TooltipFrame:NumLines() do
      local line = _G["ThreatPlates_TooltipTextLeft" .. i]
      local text = line:GetText()
      local text_r, text_g, text_b = line:GetTextColor()

      Addon.Logging.Debug("=== Line:", text)
      if text_r > 0.99 and text_g > 0.82 and text_b == 0 then
        -- A line with this color is either the quest title or a player name (if on a group quest, but always after the quest title)
        -- if quest_title_found then
        --   quest_player = (text == PlayerName)
        -- else
        if text == PlayerName then
          quest_progress_player = true
          Addon.Logging.Debug("  Player:", text)
        elseif not GroupMembers[text] then
          Addon.Logging.Debug("Quest:", text)
          quest_progress_player = true
          quest_title = text
        else
          quest_progress_player = false
          Addon.Logging.Debug("  Character:", text)
        end
      elseif quest_progress_player then
        local objective_name, current, goal
        local objective_type = false

        Addon.Logging.Debug("    => Objective:", text)
        -- Check if area / progress quest
        if string.find(text, "%%") then
          objective_name, current, goal = string.match(text, "^(.*) %(?(%d+)%%%)?$")
          objective_type = "area"
          Addon.Logging.Debug("    => Area: <" .. text .. ">", objective_name, current, goal)
        else
          -- Standard x/y /pe quest
          objective_name, current, goal = QuestObjectiveParser(text)
          Addon.Logging.Debug("    => Standard: <" .. text .. ">", objective_name, current, goal)
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
          local quest = QuestByTitle[quest_title]
          local quest_objective
          if quest then
            quest_objective = quest.Objectives[objective_name]
            --else
            --  print ("<< Quest No Cached >> =>", quest_title)
          end

          -- A unit may be target of more than one quest, the quest indicator should be show if at least one quest is not completed.
          if current and goal then
            if current == goal then
              Addon.Logging.Debug("  => Finished!")
            end
          end
        end
      end
    end
  else
    Addon.Logging.Debug("Quests List:", tablelength(QuestByID))
    for quest_id, title in pairs(QuestByID) do
      if not command or string.find(title, command) then
        local quest = QuestByTitle[title]
        if quest.Objectives then --and tablelength(quest.objectives) > 0 then
          Addon.Logging.Debug("*", title .. " [ID:" .. tostring(quest_id) .. "]")
          for name, val in pairs (quest.Objectives) do
            Addon.Logging.Debug("  - |" .. name .."| :", val.numFulfilled, "/", val.numRequired, "[" .. val.type .. "]")
          end
        end
      end
    end

    Addon.Logging.Debug("QuestUnitsToUpdate:", tablelength(QuestUnitsToUpdate))

    Addon.Logging.Debug("Waiting for quest log updates for the following quests:")
    for questID, title in pairs(QuestsToUpdate) do
      local questIndex = GetLogIndexForQuestID(questID)
      Addon.Logging.Debug("  Quest:", title .. " [" .. tostring(questIndex) .. "]")
    end
  end
end