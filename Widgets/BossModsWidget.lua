local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewWidget("BossMods")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local floor = math.floor
local type = type

-- WoW APIs
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or _G.GetSpellTexture -- Retail now uses C_Spell.GetSpellTexture
local GetTime = GetTime
local tremove, sort = tremove, sort
local strbyte, strsub = strbyte, strsub

-- ThreatPlates APIs
local L = Addon.ThreatPlates.L
local BackdropTemplate = Addon.BackdropTemplate
local RGB, RGB_P, RGB_WITH_HEX = ThreatPlates.RGB, ThreatPlates.RGB_P, ThreatPlates.RGB_WITH_HEX
local Font = Addon.Font
local MODE_FOR_STYLE, AnchorFrameTo = Addon.MODE_FOR_STYLE, Addon.AnchorFrameTo
local CUSTOM_GLOW_FUNCTIONS, CUSTOM_GLOW_WRAPPER_FUNCTIONS = Addon.CUSTOM_GLOW_FUNCTIONS, Addon.CUSTOM_GLOW_WRAPPER_FUNCTIONS

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, UnitGUID

local AurasForUnit = {}
local TimersForUnit = {}
local TimersByID = {}
local SortedAlertsForUnit = {}
local AurasAreEnabled = false
local TestModeIsEnabled = false
local GlowHighlightStartFunction, GlowHighlightStopFunction
local Settings
local DefaultGlowColor

local UPDATE_INTERVAL = 0.1
local COLOR_TRANSPARENT = RGB(0, 0, 0, 0) -- opaque

---------------------------------------------------------------------------------------------------
-- Boss Mods Widget Functions
---------------------------------------------------------------------------------------------------

local function UpdateIconFrameLayout(widget_frame, icon_frame, index)
  if index == 1 then
    icon_frame:SetPoint("TOPLEFT", widget_frame, "TOPLEFT", 0, 0)
  else
    icon_frame:SetPoint("LEFT", widget_frame.Timers[index - 1], "RIGHT", Settings.AuraSpacing, 0)
  end

  icon_frame:SetSize(Settings.scale, Settings.scale)

  -- Duration Text
  local color = Settings.FontColor
  icon_frame.Time:SetFont(Addon.LibSharedMedia:Fetch('font', Settings.Font), Settings.FontSize)
  icon_frame.Time:SetAllPoints(icon_frame)
  icon_frame.Time:SetTextColor(color.r, color.g, color.b)

  -- Label Text
  Font:UpdateText(icon_frame, icon_frame.Label, Settings.LabelText)
end

local function InitiateIconFrame(icon_frame, alert, remaining_time)
  if not remaining_time or remaining_time > 5 then
    GlowHighlightStopFunction(icon_frame.Highlight)
    icon_frame.Highlight:Hide()
  end

  icon_frame.Icon:SetTexture(alert.Texture)

  icon_frame.Label:SetText(alert.Label)
  local color = alert.Color
  if color then
    icon_frame.Label:SetTextColor(color.r, color.g, color.b, color.a)
    icon_frame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
  else
    icon_frame:SetBackdropBorderColor(COLOR_TRANSPARENT.r, COLOR_TRANSPARENT.g, COLOR_TRANSPARENT.b, COLOR_TRANSPARENT.a)
  end

  icon_frame:Show()
end

local function UpdateIconFrame(icon_frame, alert, remaining_time)
  if icon_frame.Data ~= alert then
    InitiateIconFrame(icon_frame, alert, remaining_time)
    icon_frame.Data = alert
  end

  if not remaining_time then return end

  if remaining_time > 5 then
    remaining_time = floor(remaining_time)
  else
    remaining_time = string.format("%.1f", floor(remaining_time * 10) / 10)

    if not icon_frame.Highlight:IsShown() then
      local alert_priority = Settings.Glow.Priority
      if alert_priority == "All" or (alert_priority == "Important" and alert.IsPriority) then
        GlowHighlightStopFunction(icon_frame.Highlight)
        local color = (Settings.Glow.CustomColor and Settings.Glow.Color) or DefaultGlowColor
        GlowHighlightStartFunction(icon_frame.Highlight, color, 0)
        icon_frame.Highlight:Show()
      end
    end
  end

  icon_frame.Time:SetText(remaining_time)
end

local function CreateIconFrame(widget_frame, index)
  local icon_frame = _G.CreateFrame("Button", nil, widget_frame, BackdropTemplate)
  icon_frame:EnableMouse(false)
  icon_frame:SetBackdrop({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1})

  icon_frame.Icon = icon_frame:CreateTexture(nil, "BORDER")
  icon_frame.Icon:SetPoint("TOPLEFT", icon_frame, "TOPLEFT", 1, -1)
  icon_frame.Icon:SetPoint("BOTTOMRIGHT", icon_frame, "BOTTOMRIGHT", -1, 1)

  local time = icon_frame:CreateFontString(nil, "OVERLAY") -- Duration Text
  time:SetJustifyH("CENTER")
  time:SetJustifyV("MIDDLE")
  time:SetShadowOffset(1, -1)
  icon_frame.Time = time

  icon_frame.Label = icon_frame:CreateFontString(nil, "OVERLAY")
  icon_frame.Label:SetFont("Fonts\\FRIZQT__.TTF", 11)

  icon_frame.Highlight = _G.CreateFrame("Frame", nil, icon_frame)
  icon_frame.Highlight:SetAllPoints(icon_frame)
  icon_frame.Highlight:SetFrameLevel(widget_frame:GetFrameLevel() + 15)

  UpdateIconFrameLayout(widget_frame, icon_frame, index)

  return icon_frame
end

local function UnitHasActiveAlerts(guid)
  local auras_for_unit = AurasForUnit[guid]
  local timers_for_unit = TimersForUnit[guid]

  return (AurasAreEnabled and auras_for_unit and next(auras_for_unit)) or (timers_for_unit and next(timers_for_unit))
end

local function GetAlertsForType(alert_type)
  return (alert_type == "Aura" and AurasForUnit) or TimersForUnit
end

local function GetTimeLeftForTimer(alert, current_time)
  return (alert.Duration or 0) - ((alert.IsPaused and alert.PauseStartTime or current_time) - alert.StartTime)
end

-- local function SortFunctionForAlerts(a, b, current_time)
--   -- Sort by: alert type, paused state, priority, time_left
--   if a.Type == "Aura" and b.Type == "Timer" then
--     return true
--   elseif a.Type == "Timer" and b.Type == "Aura" then
--     return false
--   elseif a.IsPaused and not b.IsPaused then
--     return false
--   elseif not a.IsPaused and b.IsPaused then
--     return true
--   elseif a.IsPriority and not b.IsPriority then
--     return true
--   elseif b.IsPriority and not a.IsPriority then
--     return false
--   else
--     return GetTimeLeftForTimer(a, current_time) < GetTimeLeftForTimer(b, current_time)
--   end    
-- end

local function AddAlertsToSortedAlerts(timers, sorted_timers)
  if timers then
    for _, entry in pairs(timers) do 
      sorted_timers[#sorted_timers + 1] = entry
    end
  end
end

local function SortAlerts(guid)
  local sorted_alerts = {}

  AddAlertsToSortedAlerts(AurasForUnit[guid], sorted_alerts)
  AddAlertsToSortedAlerts(TimersForUnit[guid], sorted_alerts)

  local current_time = GetTime()
  sort(sorted_alerts, function(a,b) 
    -- Sort by: alert type, paused state, priority, time_left
    if a.Type == "Aura" and b.Type == "Timer" then
      return true
    elseif a.Type == "Timer" and b.Type == "Aura" then
      return false
    elseif a.IsPaused and not b.IsPaused then
      return false
    elseif not a.IsPaused and b.IsPaused then
      return true
    elseif a.IsPriority and not b.IsPriority then
      return true
    elseif b.IsPriority and not a.IsPriority then
      return false
    else
      return GetTimeLeftForTimer(a, current_time) < GetTimeLeftForTimer(b, current_time)
    end   
    --SortFunctionForAlerts(a, b, current_time)
  end)

  SortedAlertsForUnit[guid] = sorted_alerts
end

local function UpdateIconFrameWidget(widget_frame)
  local alerts_for_unit = SortedAlertsForUnit[widget_frame.unit.guid]
  local current_time = GetTime()
  
  -- Timers are sorted, so < 0 should be at the front. So, we just could skip all at the front (and remove them)
  -- : -4, -3, -1, ===> 0, 1, 5, 10
  local index = 1
  while index <= #alerts_for_unit do
    local alert = alerts_for_unit[index]

    local icon_frame = widget_frame.Timers[index]
    if not icon_frame then
      icon_frame = CreateIconFrame(widget_frame, index)
      widget_frame.Timers[index] = icon_frame
    end

    if alert.Duration then -- aura with duration
      local remaining_time = GetTimeLeftForTimer(alert, current_time)
      if remaining_time > 0 then
        UpdateIconFrame(icon_frame, alert, remaining_time)
        index = index + 1
      else -- aura has run out
        GetAlertsForType(alert.Type)[alert.ID] = nil
        TimersByID[alert.ID] = nil
      
        tremove(alerts_for_unit, index)
      end
    else -- aura without duration
      UpdateIconFrame(icon_frame, alert)
      index = index + 1
    end
  end

  -- Hide all unused aura textures
  for i = index, widget_frame.TimerNo do
    widget_frame.Timers[i]:Hide()
  end

  widget_frame.TimerNo = #alerts_for_unit

  widget_frame:SetSize(widget_frame.TimerNo * Settings.scale + (widget_frame.TimerNo - 1 ) * Settings.AuraSpacing, Settings.scale)
end

local function OnUpdateWidget(widget_frame, elapsed)
  widget_frame.LastUpdate = widget_frame.LastUpdate + elapsed
  if widget_frame.LastUpdate < UPDATE_INTERVAL then return end  
  
  widget_frame.LastUpdate = 0

  if UnitHasActiveAlerts(widget_frame.unit.guid) then
    UpdateIconFrameWidget(widget_frame)
    -- As all timers might have expired now, check this and hide the widget if there are no active alerts anymore
    widget_frame:SetShown(widget_frame.TimerNo > 0)
  else
    widget_frame:Hide()
  end
end

---------------------------------------------------------------------------------------------------
-- Callback functions for DBM
---------------------------------------------------------------------------------------------------

local function GetDBMClassificationColor(colorId)
	local red, green, blue = 1, 1, 1

  if DBT and DBT.GetColorForType then 
    red, green, blue = DBT:GetColorForType(colorId)
  end

  return RGB_P(red or 0, green or 0, blue or 0)
end

-- From DBM (DBM-Nameplate.lua)
local function CleanSubString(text, i, j)
	if type(text) == "string" and text ~= "" and i and i > 0 and j and j > 0 then
		i = floor(i)
		j = floor(j)
		local b1 = (#text > 0) and strbyte(strsub(text, #text, #text)) or nil
		local b2 = (#text > 1) and strbyte(strsub(text, #text-1, #text)) or nil
		local b3 = (#text > 2) and strbyte(strsub(text, #text-2, #text)) or nil

		if b1 and (b1 < 194 or b1 > 244) then
			text = strsub (text, i, j)
		elseif b1 and b1 >= 194 and b1 <= 244 then
			text = strsub (text, i*2 - 1, j*2)

		elseif b2 and b2 >= 224 and b2 <= 244 then
			text = strsub (text, i*3 - 2, j*3)

		elseif b3 and b3 >= 240 and b3 <= 244 then
			text = strsub (text, i*4 - 3, j*3)
		end
	end

	return text
end

local function UpdateWidgetFrame(guid)
  local plate = Addon.PlatesByGUID[guid]
  if plate and plate.TPFrame.Active then
    local widget_frame = plate.TPFrame.widgets.BossMods
    if widget_frame and widget_frame.Active then
      Widget:OnUnitAdded(widget_frame, widget_frame.unit)
    end
  end
end

local function CreateTimerAlert(id, guid, duration, icon_texture, label, spell_id, color_id, is_priority)
  return {
    Type = "Timer",
    ID = id,
    GUID = guid,
    StartTime = GetTime(),
    Duration = duration,
    Texture = icon_texture,
    Label = label,
    Color = GetDBMClassificationColor(color_id),
    IsPriority = is_priority,
  }
end

local function CreateAuraAlert(icon_texture, guid, duration)
  return {
    Type = "Aura",
    ID = icon_texture,
    GUID = guid,
    StartTime = GetTime(),
    Duration = duration,
    Texture = icon_texture,
  }
end

local function AddAlertForUnit(alert)
  local is_first_alert = UnitHasActiveAlerts(alert.GUID)

  local alerts_for_type = GetAlertsForType(alert.Type)

  local alerts_for_unit = alerts_for_type[alert.GUID]
  if not alerts_for_unit then
    alerts_for_unit = {}
    alerts_for_type[alert.GUID] = alerts_for_unit
  end

  alerts_for_unit[alert.ID] = alert
  TimersByID[alert.ID] = alert

  SortAlerts(alert.GUID)

  -- Show frame is this is the first aura shown (no_auras == 0 in this case)
  -- It is not guaranteed that there is a nameplate for the unit at this point.
  if is_first_alert then
    UpdateWidgetFrame(alert.GUID)
  end
end

local function RemoveAlertForUnit(id)
  local alert = TimersByID[id]
  if not alert then return end

  GetAlertsForType(alert.Type)[alert.GUID][id] = nil
  TimersByID[id] = nil

  -- Could also only remove the alert from the sorted alerts list
  SortAlerts(alert.GUID)
  UpdateWidgetFrame(alert.GUID)
end

local function RemoveAllActiveAlerts(alert_type)
  local alerts_for_type = GetAlertsForType(alert_type)
  for guid, alerts_for_unit in pairs(alerts_for_type) do
    for id, alert in pairs(alerts_for_unit) do
      TimersByID[alert.ID] = nil
    end
    alerts_for_type[guid] = nil

    SortAlerts(guid)
    UpdateWidgetFrame(guid)
  end
end

-- DBM:FireEvent("bossmods_ShowNameplateAura", isGUID, unit, currentTexture, duration, desaturate, addLine, lineColor)
local function BossMods_ShowNameplateAura(msg, is_guid, unit, aura_texture, duration, desaturate, addLine, lineColor)
  -- Addon.Logging.Debug("BossMod - ShowNameplateAura:", msg, is_guid, unit, aura_texture, duration, desaturate, addLine, lineColor)
  
  local guid = (is_guid and unit) or _G.UnitGUID(unit)
  if not guid then return end

  AddAlertForUnit(CreateAuraAlert(aura_texture, guid, duration, aura_texture))
end

-- DBM:FireEvent("bossmods_HideNameplateAura", isGUID, unit, currentTexture)
local function BossMods_HideNameplateAura(msg, is_guid, unit, aura_texture)
  -- Addon.Logging.Debug("BossMod - HideNameplateAura:", msg, is_guid, unit, aura_texture)
  local guid = (is_guid and unit) or _G.UnitGUID(unit)
  if not guid then return end

  RemoveAlertForUnit(aura_texture)
end

local function BossMods_EnableHostileNameplates()
  -- Addon.Logging.Debug("BossMod - EnableHostileNameplates")
  AurasAreEnabled = true
end

local function BossMods_DisableHostileNameplates()
  AurasAreEnabled = false

  -- Cleanup, widget frame will be hidden on next update cycle, including with cleanup of all script handlers
  RemoveAllActiveAlerts("Aura")
end

local function BossMods_TestModStarted(event, timer)
  -- Addon.Logging.Debug("BossMod:", event, timer)
  TestModeIsEnabled = true

  -- Disable test mode after a fixed time:
  C_Timer.After(tonumber(timer) or 60, function() TestModeIsEnabled = false end)
end

--id: Internal DBM timer ID
--msg: Timer Text (Do not use msg has an event trigger, it varies language to language or based on user timer options. Use this to DISPLAY only (such as timer replacement UI). use spellId field 99% of time
--timer: Raw timer value (number).
--Icon: Texture Path for Icon
--type: Timer type, which is one of only 7 possible types: "cd" for coolodwns, "target" for target bars such as debuff on a player, 
--      "stage" for any kind of stage timer (stage ends, next stage, or even just a warmup timer like "fight begins"), and then 
--      "cast" timer which is used for both a regular cast and a channeled cast (ie boss is casting frostbolt, or boss is 
--      channeling whirlwind). Lastly, break, pull, and berserk timers are "breaK", "pull", and "berserk" respectively
--spellId: Raw spellid if available (most timers will have spellId or EJ ID unless it's a specific timer not tied to ability such as pull or combat start or rez timers. EJ id will be in format ej%d
--colorID: Type classification (1-Add, 2-Aoe, 3-targeted ability, 4-Interrupt, 5-Role, 6-Stage, 7-User(custom))
--Mod ID: Encounter ID as string, or a generic string for mods that don't have encounter ID (such as trash, dummy/test mods)
--Keep: true or nil, whether or not to keep bar on screen when it expires (if true, timer should be retained until an actual TimerStop occurs or a new TimerStart with same barId happens (in which case you replace bar with new one)
--fade: true or nil, whether or not to fade a bar (set alpha to usersetting/2)
--name: Sent so users can use a spell name instead of spellId, if they choose. Mostly to be more classic wow friendly, spellID is still preferred method (even for classic)
--MobGUID if it could be parsed out of args
--timerCount if current timer is a count timer. Returns number (count value) needed to have weak auras that trigger off a specific timer count without using localized message text
--isPriority: If true, this ability has been flagged as extra important. Can be used for weak auras or nameplate addons to add extra emphasis onto specific timer like a glow
--fullType (the true type of timer, for those who really want to filter timers by DBM classifications such as "adds" or "interrupt")
--NOTE, nameplate variant has same args as timer variant, but is sent to a different event (DBM_NameplateStart)

-- DBM:FireEvent("DBM_TimerStart", isGUID, unit, currentTexture)
local function BossMods_TimerStart(event, id, msg, timer, icon, barType, spellId, colorId, modId, keep, fade, name, guid, timerCount, isPriority)
  -- Addon.Logging.Debug("BossMod:", event, id, msg, timer, icon, barType, spellId, colorId, modId, keep, fade, name, guid, timerCount, isPriority)
  --if not id or (barType ~= "cdnp" and barType ~= "castnp") then return end

  local label = CleanSubString(string.match(name or msg or "", "^%s*(.-)%s*$" ), 1, 20)

  if guid then
    local timer_entry = CreateTimerAlert(id, guid, timer, icon, label, spellId, colorId, isPriority)
    AddAlertForUnit(timer_entry)
  elseif TestModeIsEnabled then
    guid = _G.UnitGUID("target")
    if guid then 
      local timer_entry = CreateTimerAlert(id, guid, timer, icon, label, spellId, colorId, isPriority)
      AddAlertForUnit(timer_entry)
    else
      Addon.Logging.Warning(L["Please select a target unit with a nameplate to enable configuration mode."])
    end
  end 
end

local function BossMods_TimerUpdate(event, id, elapsed, total_time)
  -- Addon.Logging.Debug("BossMod:", event, id, elapsed, total_time) 
  if not id or not elapsed or not total_time then return end

  local alert = TimersByID[id]
  if not alert then return end

  local current_time = GetTime()
  alert.StartTime = current_time - elapsed
  alert.Duration = total_time

  if alert.IsPaused then
    alert.PauseStartTime = current_time
  end

  SortAlerts(alert.GUID)
  UpdateWidgetFrame(alert.GUID)
end

local function BossMods_TimerPause(event, id)
  -- Addon.Logging.Debug("BossMod:", event, id)
  if not id then return end

  local alert = TimersByID[id] 
  if not TimersByID[id] then return end

  alert.IsPaused = true
  alert.PauseStartTime = GetTime()

  SortAlerts(alert.GUID)
  UpdateWidgetFrame(alert.GUID)
end

local function BossMods_TimerResume(event, id)
  -- Addon.Logging.Debug("BossMod:", event, id)
  if not id then return end

  local alert = TimersByID[id]
  if not alert or not alert.IsPaused then return end

  alert.IsPaused = nil
  alert.StartTime = alert.StartTime + (GetTime() - alert.PauseStartTime)
  alert.PauseStartTime = alert.StartTime

  SortAlerts(alert.GUID)
  UpdateWidgetFrame(alert.GUID)
end

local function BossMods_TimerStop(event, id)
  -- Addon.Logging.Debug("BossMod:", event, id)
  if not id then return end

  RemoveAlertForUnit(id)
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:IsEnabled()
  local db = Addon.db.profile.BossModsWidget
  return db.ON or db.ShowInHeadlineView
end

function Widget:Create(tp_frame)
  local widget_frame = _G.CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel())
  widget_frame.Timers = {}
  widget_frame.TimerNo = 0
  self:UpdateLayout(widget_frame)
  
  widget_frame:SetScript("OnUpdate", OnUpdateWidget)

  return widget_frame
end

function Widget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return Settings.ShowInHeadlineView
  elseif style ~= "etotem" then
    return Settings.ON
  end
end

-- local AURA_AREA_BY_REACTION = {
--   Buffs = "Debuffs",
--   Debuffs = "Buffs",
--   CrowdControl = "CrowdControl"
-- }

local function SetAnchorForWidget(widget_frame)
  -- local tp_frame = widget_frame:GetParent()
  -- local anchor_frame
  -- if Settings.AnchorTo ~= "Healthbar" then
  --   local auras_widget_frame = tp_frame.widgets.Auras
  --   if auras_widget_frame and auras_widget_frame.Active then
  --     local auras_anchor = Settings.AnchorTo
  --     if Addon.db.profile.AuraWidget.SwitchAreaByReaction and widget_frame.unit.reaction == "FRIENDLY" then
  --       auras_anchor = AURA_AREA_BY_REACTION[auras_anchor]
  --     end

  --     anchor_frame = auras_widget_frame[auras_anchor]

  --     if not anchor_frame:IsShown() then
  --       anchor_frame = tp_frame.visual.healthbar
  --     end
  --   end
  -- end

  -- anchor_frame = anchor_frame or tp_frame.visual.healthbar

  AnchorFrameTo(Settings[MODE_FOR_STYLE[widget_frame.unit.style]], widget_frame, widget_frame:GetParent().visual.healthbar)
end

function Widget:OnUnitAdded(widget_frame, unit)
  if not Settings.ShowAuras and not Settings.ShowTimers then 
    widget_frame:Hide()
    return
  end
  
  if not UnitHasActiveAlerts(unit.guid) then 
    widget_frame:Hide()
    return
  end

  UpdateIconFrameWidget(widget_frame)
  SetAnchorForWidget(widget_frame)

  widget_frame.LastUpdate = 0.5
  widget_frame:Show()
end

function Widget:UpdateLayout(widget_frame)
  for i = 1, #widget_frame.Timers do
    local icon_frame = widget_frame.Timers[i]
    CUSTOM_GLOW_WRAPPER_FUNCTIONS.Glow_Stop(icon_frame.Highlight)
    UpdateIconFrameLayout(widget_frame, icon_frame, i)
    icon_frame.Data = nil
  end
end

function Widget:UpdateSettings()
  Settings = Addon.db.profile.BossModsWidget

  GlowHighlightStartFunction = CUSTOM_GLOW_WRAPPER_FUNCTIONS[CUSTOM_GLOW_FUNCTIONS[Settings.Glow.Type][1]]
  GlowHighlightStopFunction = Addon.LibCustomGlow[CUSTOM_GLOW_FUNCTIONS[Settings.Glow.Type][2]]
  DefaultGlowColor = ThreatPlates.DEFAULT_SETTINGS.profile.uniqueSettings["**"].Effects.Glow.Color

  if DBM and DBM.RegisterCallback and DBM.UnregisterCallback then
    if Settings.ShowAuras then
      DBM:RegisterCallback('BossMod_ShowNameplateAura', BossMods_ShowNameplateAura)
      DBM:RegisterCallback('BossMod_HideNameplateAura', BossMods_HideNameplateAura)
      DBM:RegisterCallback('BossMod_EnableHostileNameplates', BossMods_EnableHostileNameplates)
      DBM:RegisterCallback('BossMod_DisableHostileNameplates', BossMods_DisableHostileNameplates)
      -- BossMod_DisableFriendlyNameplates
      -- BossMod_EnableFriendlyNameplates
    else
      DBM:UnregisterCallback('BossMod_ShowNameplateAura', BossMods_ShowNameplateAura)
      DBM:UnregisterCallback('BossMod_HideNameplateAura', BossMods_HideNameplateAura)
      DBM:UnregisterCallback('BossMod_DisableFriendlyNameplates', BossMods_EnableHostileNameplates)
      DBM:UnregisterCallback('BossMod_DisableHostileNameplates', BossMods_DisableHostileNameplates)

      -- Delete all currently active auras
      RemoveAllActiveAlerts("Aura")
    end

    if Settings.ShowTimers then
      DBM:RegisterCallback('DBM_TestModStarted', BossMods_TestModStarted)
      DBM:RegisterCallback('DBM_NameplateStart', BossMods_TimerStart)
      DBM:RegisterCallback('DBM_NameplateUpdate', BossMods_TimerUpdate)
      DBM:RegisterCallback('DBM_NameplatePause', BossMods_TimerPause)
      DBM:RegisterCallback('DBM_NameplateResume', BossMods_TimerResume)
      DBM:RegisterCallback('DBM_NameplateStop', BossMods_TimerStop)
        
      DBM:RegisterCallback('DBM_TimerStart', BossMods_TimerStart)
      DBM:RegisterCallback('DBM_TimerUpdate', BossMods_TimerUpdate)
      DBM:RegisterCallback('DBM_TimerPause', BossMods_TimerPause)
      DBM:RegisterCallback('DBM_TimerResume', BossMods_TimerResume)
      DBM:RegisterCallback('DBM_TimerStop', BossMods_TimerStop)
      -- DBM_TimerFadeUpdate
      -- DBM_TimerUpdateIcon
    else
      DBM:UnregisterCallback('DBM_TestModStarted', BossMods_TestModStarted)
      DBM:UnregisterCallback('DBM_NameplateStart', BossMods_TimerStart)
      DBM:UnregisterCallback('DBM_NameplateStop', BossMods_TimerUpdate)
      DBM:UnregisterCallback('DBM_NameplatePause', BossMods_TimerPause)
      DBM:UnregisterCallback('DBM_NameplateResume', BossMods_TimerResume)
      DBM:UnregisterCallback('DBM_NameplateUpdate', BossMods_TimerStop)

      DBM:UnregisterCallback('DBM_TimerStart', BossMods_TimerStart)
      DBM:UnregisterCallback('DBM_TimerUpdate', BossMods_TimerUpdate)
      DBM:UnregisterCallback('DBM_TimerPause', BossMods_TimerPause)
      DBM:UnregisterCallback('DBM_TimerResume', BossMods_TimerResume)
      DBM:UnregisterCallback('DBM_TimerStop', BossMods_TimerStop)

      -- Delete all currently active timers
      RemoveAllActiveAlerts("Timer")
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Configuration Mode
---------------------------------------------------------------------------------------------------

local EnabledConfigMode = false
function Addon:ConfigBossModsWidget()
  local event = "Configuration Mode"
  
  if not EnabledConfigMode then
    local tp_frame = Widget:GetThreatPlateForUnit("target")
    if tp_frame then
      local guid = _G.UnitGUID("target")
      
      if Settings.ShowAuras then
        BossMods_EnableHostileNameplates()
        BossMods_ShowNameplateAura(event, true, guid, GetSpellTexture(6603), nil, false, true, {1, 1, 0.5, 1})
        BossMods_ShowNameplateAura(event, true, guid, GetSpellTexture(7620), 7, false, true, {0, 0, 1, 1})
        BossMods_ShowNameplateAura(event, true, guid, GetSpellTexture(818), 60)
      end
      
      if Settings.ShowTimers then
        BossMods_TestModStarted(event, 65)
        BossMods_TimerStart(event, 1, "Test Bar", 10, "136116", "cd", nil, 0, "TestMod", nil, nil, nil, guid, nil, nil)
        BossMods_TimerStart(event, 2, "Adds", 30, "134170", "cd", nil, 1, "TestMod", nil, nil, nil, guid, nil, nil)
        BossMods_TimerStart(event, 3, "Evil Debuff", 43, "136194", "next", nil, 3, "TestMod", nil, nil, nil, guid, nil, nil)
        BossMods_TimerStart(event, 4, "Important Interrupt", 20, "136175", "cd", nil, 4, "TestMod", nil, nil, nil, guid, nil, true)
        BossMods_TimerStart(event, 5, "Boom!", 60, "135826", "next", nil, 2, "TestMod", nil, nil, nil, guid, nil, nil)
        BossMods_TimerStart(event, 6, "Handle your Role", 35, "135826", "next", nil, 5, "TestMod", nil, nil, nil, guid, nil, nil)

        C_Timer.After(5, function()
          BossMods_TimerPause(event, 2)
        end)

        C_Timer.After(10, function()
          BossMods_TimerResume(event, 2)
        end)

        C_Timer.After(15, function()
          BossMods_TimerUpdate(event, 3, 15, 43 + 20)
        end)
      end
      
      EnabledConfigMode = true
    else
      Addon.Logging.Warning(L["Please select a target unit with a nameplate to enable configuration mode."])
    end
  else
    BossMods_DisableHostileNameplates()

    BossMods_TimerStop(event, 1)
    BossMods_TimerStop(event, 2)
    BossMods_TimerStop(event, 3)
    BossMods_TimerStop(event, 4)
    BossMods_TimerStop(event, 5)
    BossMods_TimerStop(event, 6)

    EnabledConfigMode = false
  end
end