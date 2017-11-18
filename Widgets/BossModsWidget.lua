------------------------
-- Boss Mod Widget --
------------------------
local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local floor = math.floor
local pairs = pairs

-- WoW APIs
local CreateFrame = CreateFrame
local UnitGUID = UnitGUID
local GetSpellTexture = GetSpellTexture
local GetTime = GetTime
local tremove = tremove

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

--
local DBM = DBM

local WidgetList = {}
local guid_aura_list = {}
local callbacks_registered = false
local CONFIG_DB
local ENABLED = false
local enabled_by_bossmods = false
local configmode_enabled = false

local MAX_AURAS_NO = 5
local UPDATE_INTERVAL = 0.5

---------------------------------------------------------------------------------------------------
-- Threat Plates functions
---------------------------------------------------------------------------------------------------

-- hides/destroys all widgets of this type created by Threat Plates
-- local function ClearAllWidgets()
-- 	for _, widget in pairs(WidgetList) do
-- 		widget:Hide()
-- 	end
-- 	WidgetList = {}
-- end

---------------------------------------------------------------------------------------------------
-- Register functions with DBM
---------------------------------------------------------------------------------------------------

local function AlignWidget(frame)
  frame:ClearAllPoints()

  local offset_x = 0
  if frame.AurasNo > 1 then
    offset_x = (frame.AurasNo - 1) * (CONFIG_DB.scale + CONFIG_DB.AuraSpacing) / 2
  end

  local style = frame.unit.TP_Style
  if style == "NameOnly" or style == "NameOnly-Unique" then
    frame:SetPoint("CENTER", frame:GetParent(), - offset_x + CONFIG_DB.x_hv, CONFIG_DB.y_hv)
  else
    frame:SetPoint("CENTER", frame:GetParent(), - offset_x + CONFIG_DB.x, CONFIG_DB.y)
  end

  frame:SetSize(64, 64)
end

local function UpdateAuraTexture(frame, aura, index)
  if index == 1 then
    aura:SetPoint("CENTER", frame, 0, 0)
  else
    aura:SetPoint("LEFT", frame.Auras[index - 1], "RIGHT", CONFIG_DB.AuraSpacing, 0)
  end
  aura:SetSize(CONFIG_DB.scale, CONFIG_DB.scale)

  -- Duration Text
  local time = aura.Time
  local color = CONFIG_DB.FontColor
  time:SetFont(ThreatPlates.Media:Fetch('font', CONFIG_DB.Font), CONFIG_DB.FontSize)
  time:SetAllPoints(aura)
  time:SetTextColor(color.r, color.g, color.b)
end

local function CreateAuraTexture(frame, index)
  local aura = frame:CreateTexture(nil, "BACKGROUND")
  local time = frame:CreateFontString(nil, "OVERLAY") -- Duration Text

  time:SetJustifyH("CENTER")
  time:SetJustifyV("CENTER")
  time:SetShadowOffset(1, -1)
  aura.Time = time

  UpdateAuraTexture(frame, aura, index)

  return aura
end

local function UpdateSettings(frame)
  for i = 1, #frame.Auras do
    UpdateAuraTexture(frame, frame.Auras[i], i)
  end

  -- Update alignment if unit is aligned to the nameplate
  if frame.unit then
    AlignWidget(frame)
  end
  
  frame.LastUpdate = 0.5 -- to show the update immediately
end

local function UpdateFrameWithAuras(frame, unit_auras)
  local aura_texture, aura_info

  local no_auras = #unit_auras
  local index = 1
  while index <= no_auras do
    aura_info = unit_auras[index]

    aura_texture = frame.Auras[index]
    if not aura_texture then
      aura_texture = CreateAuraTexture(frame, index)
      frame.Auras[index] = aura_texture

    end

    if aura_info[2] then -- aura with duration
      local remaining_time = floor(aura_info[2] - GetTime())
      if remaining_time >= 0 then
        aura_texture:SetTexture(aura_info[1])
        aura_texture.Time:SetText(remaining_time)

        aura_texture.Time:Show()
        aura_texture:Show()

        index = index + 1
      else -- aura has run out
        tremove(unit_auras, index)
        no_auras = no_auras - 1
      end
    else -- aura without duration
      aura_texture:SetTexture(aura_info[1])
      aura_texture.Time:SetText(nil)

      aura_texture.Time:Show()
      aura_texture:Show()

      index = index + 1
    end
  end

  -- Hide all unused aura textures
  for i = index, #frame.Auras do
    aura_texture = frame.Auras[i]
    aura_texture.Time:Hide()
    aura_texture:Hide()
  end

  frame.AurasNo = no_auras
  AlignWidget(frame)
end

local function OnUpdateBossModsWidget(frame, elapsed)
  if not ENABLED or not enabled_by_bossmods then
    frame.BossModOnUpdateSet = false
    frame:SetScript("OnUpdate", nil)
    frame:_Hide()
    return
  end

  frame.LastUpdate = frame.LastUpdate + elapsed
  if frame.LastUpdate >= UPDATE_INTERVAL then
    frame.LastUpdate = 0

    local guid = frame.guid

    local unit_auras = guid_aura_list[guid]
    if guid and unit_auras and #unit_auras > 0 then
      UpdateFrameWithAuras(frame, unit_auras)
    else
      frame.BossModOnUpdateSet = false
      frame:SetScript("OnUpdate", nil)
      frame:_Hide()
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Callback functions for DBM
---------------------------------------------------------------------------------------------------

-- Events from: DBM
--   DBM:FireEvent("BossMod_DisableFriendlyNameplates")
--   DBM:FireEvent("BossMod_DisableHostileNameplates")
--   DBM:FireEvent("BossMod_ShowNameplateAura", isGUID, unit, currentTexture, duration, desaturate)
--   DBM:FireEvent("BossMod_HideNameplateAura", isGUID, unit, currentTexture)

-- DBM:FireEvent("BossMod_ShowNameplateAura", isGUID, unit, currentTexture, duration, desaturate)
local function BossMod_ShowNameplateAura(msg, is_guid, unit, aura_texture, duration, desaturate)
  local guid = (is_guid and unit) or UnitGUID(unit)
  if not guid then
    -- ThreatPlates.DEBUG('bossmods show discarded unmatched name: ' .. unit)
    return
  end

  enabled_by_bossmods = true

  -- Aura Info:
  --   1: aura texture (spell id)
  --   2: time the aura ends

  local unit_auras = guid_aura_list[guid]
  if unit_auras then
    local no_auras = #unit_auras
    if no_auras < MAX_AURAS_NO then
      for i = 1, no_auras do
        if unit_auras[i][1] == aura_texture then
          unit_auras[i][2] = (duration and (GetTime() + duration)) or nil
          return
        end
      end

      -- append a new aura
      unit_auras[no_auras + 1] = {
        aura_texture,
        (duration and (GetTime() + duration)) or nil
      }
    end
  else
    guid_aura_list[guid] = {
      {
        aura_texture,
        (duration and GetTime() + duration) or nil
      }
    }
    --guid_aura_list[guid] = unit_auras

    local frame = WidgetList[guid]
    if frame then
      UpdateFrameWithAuras(frame, guid_aura_list[guid])
      frame.LastUpdate = 0.5 -- to show the update immediately
      if not frame.BossModOnUpdateSet then
        frame:SetScript("OnUpdate", OnUpdateBossModsWidget)
        frame.BossModOnUpdateSet = true
      end

      frame:Show()
    end
  end
end

-- DBM:FireEvent("BossMod_HideNameplateAura", isGUID, unit, currentTexture)
local function BossMod_HideNameplateAura(msg, is_guid, unit, aura_texture)
  ThreatPlates.DEBUG("BossMods_HideNameplateAura: ", msg, is_guid, unit, aura_texture)

  local guid = (is_guid and unit) or UnitGUID(unit)
  if not guid then
    --ThreatPlates.DEBUG('bossmods show discarded unmatched name: ' .. unit)
    return
  end

  local unit_auras = guid_aura_list[guid]
  if unit_auras then
    for i = 1, #unit_auras do
      if unit_auras[i][1] == aura_texture then
        tremove(unit_auras, i)

        local frame = WidgetList[guid]
        if frame then
          UpdateFrameWithAuras(frame, unit_auras)
          --frame.LastUpdate = 0.5 -- to show the update immediately
        end

        return
      end
    end
  end
end

local function BossMod_DisableFriendlyNameplates()
  enabled_by_bossmods = false

  -- Cleanup, widget frame will be hidden on next update cycle, including with cleanup of all script handlers
  guid_aura_list = {}
end

local function BossMod_DisableHostileNameplates()
  enabled_by_bossmods = false

  -- Cleanup, widget frame will be hidden on next update cycle, including with cleanup of all script handlers
  guid_aura_list = {}
end

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function UpdateWidgetFrame(frame, unit)
  if enabled_by_bossmods and unit.guid then
    local unit_auras = guid_aura_list[unit.guid]
    if unit_auras and #unit_auras > 0 then
      -- if frame is currently hidden, update auras so that times are correct when the frame is shown (otherwise there's a small delay)
      if not frame:IsShown() then
        UpdateFrameWithAuras(frame, unit_auras)
      end
      if not frame.BossModOnUpdateSet then
        frame:SetScript("OnUpdate", OnUpdateBossModsWidget)
        frame.BossModOnUpdateSet = true
      end

      frame:Show()
      return
    end
  end

  frame:_Hide()
end

local function UpdateWidgetContext(frame, unit)
  local guid = unit.guid

  if not guid then
    frame:_Hide()
    return
  end

  local old_guid = frame.guid
  if old_guid then WidgetList[old_guid] = nil end
  frame.guid = guid
  frame.unit = unit
  WidgetList[guid] = frame

  if UnitGUID("target") == guid then
    UpdateWidgetFrame(frame, unit)
  else
    frame:_Hide()
  end
end

local function ClearWidgetContext(frame)
  local guid = frame.guid
  if guid then
    WidgetList[guid] = nil
    frame.guid = nil
    frame.unit = nil
  end
end

local function enabled()
  CONFIG_DB = TidyPlatesThreat.db.profile.BossModsWidget
  ENABLED = CONFIG_DB.ON

  if ENABLED then
    if DBM and not callbacks_registered then
      DBM:RegisterCallback('BossMod_ShowNameplateAura', BossMod_ShowNameplateAura)
      DBM:RegisterCallback('BossMod_HideNameplateAura', BossMod_HideNameplateAura)
      DBM:RegisterCallback('BossMod_DisableFriendlyNameplates', BossMod_DisableFriendlyNameplates)
      DBM:RegisterCallback('BossMod_DisableHostileNameplates', BossMod_DisableHostileNameplates)
      callbacks_registered = true
    end
  else -- not ENABLED
    if DBM and callbacks_registered then
      DBM:UnregisterCallback('BossMod_ShowNameplateAura', BossMod_ShowNameplateAura)
      DBM:UnregisterCallback('BossMod_HideNameplateAura', BossMod_HideNameplateAura)
      DBM:UnregisterCallback('BossMod_DisableFriendlyNameplates', BossMod_DisableFriendlyNameplates)
      DBM:UnregisterCallback('BossMod_DisableHostileNameplates', BossMod_DisableHostileNameplates)
      callbacks_registered = false
    end
  end

  return ENABLED
end

local function EnabledInHeadlineView()
  return TidyPlatesThreat.db.profile.BossModsWidget.ShowInHeadlineView
end

-- Widget Creation
local function CreateWidgetFrame(parent)
  -- Required Widget Code
  local frame = CreateFrame("Frame", nil, parent)
  frame:Hide()

  -- Custom Code
  frame.Auras = {}
  frame.AurasNo = 0
  frame.LastUpdate = 0.5
  frame.BossModOnUpdateSet = false

  UpdateSettings(frame)
  frame.UpdateConfig = UpdateSettings
  -- End Custom Code

  -- Required Widget Code
  frame.UpdateContext = UpdateWidgetContext
  frame.Update = UpdateWidgetFrame
  frame._Hide = frame.Hide
  frame.Hide = function() ClearWidgetContext(frame); frame:_Hide() end
  return frame
end

---------------------------------------------------------------------------------------------------
-- Configuration Mode
---------------------------------------------------------------------------------------------------

local function ConfigBossModsWidget()
  if not configmode_enabled then
    local guid = UnitGUID("target")
    if guid then
      BossMod_ShowNameplateAura("Configuration Mode", true, guid, GetSpellTexture(241600), nil)
      BossMod_ShowNameplateAura("Configuration Mode", true, guid, GetSpellTexture(207327), 7)
      BossMod_ShowNameplateAura("Configuration Mode", true, guid, GetSpellTexture(236513), 60)

      configmode_enabled = true
    else
      ThreatPlates.Print("Please select a target unit to enable configuration mode.", true)
    end
  else
    BossMod_DisableHostileNameplates()
    BossMod_DisableFriendlyNameplates()
    configmode_enabled = false
  end
end

ThreatPlatesWidgets.ConfigBossModsWidget = ConfigBossModsWidget


ThreatPlatesWidgets.RegisterWidget("BossModsWidgetTPTP", CreateWidgetFrame, false, enabled, EnabledInHeadlineView)