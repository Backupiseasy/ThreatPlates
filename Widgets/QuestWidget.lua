-----------------------
-- Quest Widget --
-----------------------
local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local InCombatLockdown = InCombatLockdown
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local IsInInstance = IsInInstance
local UnitGUID = UnitGUID
local WorldFrame = WorldFrame

local TidyPlatesThreat = TidyPlatesThreat

-- local WidgetList = {}
local tooltip_frame = CreateFrame("GameTooltip", "ThreatPlates_Tooltip", nil, "GameTooltipTemplate")
local player_name = UnitName("player")
local ICON_COLORS = {}

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

local function IsQuestUnit(unit)
  local unitid = unit.unitid

	local quest_area = false
	local quest_player = false
	local quest_group = false

	-- Read quest information from tooltip. Thanks to Kib: QuestMobs AddOn by Tosaido.
	if unitid then
		tooltip_frame:SetOwner(WorldFrame, "ANCHOR_NONE")
		--tooltip_frame:SetUnit(unitid)
		tooltip_frame:SetHyperlink("unit:" .. unit.guid)

		for i = 3, tooltip_frame:NumLines() do
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
								if (unit_name == "" or unit_name == player_name) then
									quest_player = true
								else
									quest_group = true
								end
								break
							end
						else
							if (unit_name == "" or unit_name == player_name) then
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

  return quest_type ~= false, quest_type
end

local function ShowQuestUnit(unit)
	local db = TidyPlatesThreat.db.profile.questWidget

  local show_quest_mark = true
  if InCombatLockdown() then
    if db.HideInCombat then
      show_quest_mark = false
    elseif db.HideInCombatAttacked and unit.unitid then
      local _, threatStatus = UnitDetailedThreatSituation("player", unit.unitid);
      show_quest_mark = (threatStatus == nil)
    end
  end

  if IsInInstance() and db.HideInInstance then
    show_quest_mark = false
  end

  return  show_quest_mark
end

local function ShowQuestUnitHealthbar(unit)
  local db = TidyPlatesThreat.db.profile.questWidget
  return db.ON and db.ModeHPBar and ShowQuestUnit(unit)
end

local function enabled()
	local db = TidyPlatesThreat.db.profile.questWidget
	return db.ON and db.ModeIcon
end

local function EnabledInHeadlineView()
	local db = TidyPlatesThreat.db.profile.questWidget
	return db.ShowInHeadlineView and db.ModeIcon
end

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
-- 	for _, widget in pairs(WidgetList) do
-- 		widget:Hide()
-- 	end
-- 	WidgetList = {} -- should not be necessary, as Hide() does that, just to be sure
-- end
-- ThreatPlatesWidgets.ClearAllQuestWidgets = ClearAllWidgets

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function UpdateSettings(frame)
	local db = TidyPlatesThreat.db.profile.questWidget
	local size = db.scale
	frame:SetSize(size, size)
	frame:SetAlpha(db.alpha)

	ICON_COLORS[1] = db.ColorPlayerQuest
	ICON_COLORS[2] = db.ColorGroupQuest

	local icon_path = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\QuestWidget\\" .. db.IconTexture
	frame.Icon:SetTexture(icon_path)
	frame.Icon:SetAllPoints()
end

-- Update Graphics
local function UpdateWidgetFrame(frame, unit)
	local show, quest_type = IsQuestUnit(unit)

  if ShowQuestUnit(unit) and show then
    local db = TidyPlatesThreat.db.profile.questWidget

    local style = unit.TP_Style
    if style == "NameOnly" or style == "NameOnly-Unique" then
			frame:SetPoint("CENTER", frame:GetParent(), db.x_hv, db.y_hv)
		else
			frame:SetPoint("CENTER", frame:GetParent(), db.x, db.y)
		end

		local color = ICON_COLORS[quest_type]
		frame.Icon:SetVertexColor(color.r, color.g, color.b)

		frame:Show()
	else
		frame:_Hide()
	end
end

-- Context - GUID or unitid should only change here, i.e., class changes should be determined here
local function UpdateWidgetContext(frame, unit)
	local guid = unit.guid
	frame.guid = guid

	-- Add to Widget List
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

local function ClearWidgetContext(frame)
	local guid = frame.guid
	if guid then
		-- WidgetList[guid] = nil
		frame.guid = nil
	end
end

local function CreateWidgetFrame(parent)
	-- Required Widget Code
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()

	-- Custom Code III
	--------------------------------------
	frame:SetFrameLevel(parent:GetFrameLevel() + 2)
	frame.Icon = frame:CreateTexture(nil, "OVERLAY")

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

ThreatPlates.IsQuestUnit = IsQuestUnit
ThreatPlates.ShowQuestUnit = ShowQuestUnitHealthbar

ThreatPlatesWidgets.RegisterWidget("QuestWidgetTPTP", CreateWidgetFrame, false, enabled, EnabledInHeadlineView)
