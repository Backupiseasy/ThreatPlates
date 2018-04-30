------------------------
-- Boss Mod Widget --
------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

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
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

--
local DBM = DBM

local WidgetList = {}
local GUIDAuraList = {}
local CallbacksRegistered = false
local ConfigDB
local Enabled = false
local EnabledByBossmod = false

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
  --frame:ClearAllPoints()
  local offset_x = 0
  if frame.AurasNo > 1 then
    offset_x = (frame.AurasNo - 1) * (ConfigDB.scale + ConfigDB.AuraSpacing) / 2
  end

  local style = frame.unit.TP_Style
  if style == "NameOnly" or style == "NameOnly-Unique" then
    frame:SetPoint("CENTER", frame:GetParent(), - offset_x + ConfigDB.x_hv, ConfigDB.y_hv)
  else
    frame:SetPoint("CENTER", frame:GetParent(), - offset_x + ConfigDB.x, ConfigDB.y)
  end

  frame:SetSize(64, 64)
end

local function UpdateAuraTexture(frame, aura, index)
  if index == 1 then
    aura:SetPoint("CENTER", frame, 0, 0)
  else
    aura:SetPoint("LEFT", frame.Auras[index - 1], "RIGHT", ConfigDB.AuraSpacing, 0)
  end

  aura:SetSize(ConfigDB.scale, ConfigDB.scale)

  -- Duration Text
  local color = ConfigDB.FontColor
  aura.Time:SetFont(ThreatPlates.Media:Fetch('font', ConfigDB.Font), ConfigDB.FontSize)
  aura.Time:SetAllPoints(aura)
  aura.Time:SetTextColor(color.r, color.g, color.b)
end

local function CreateAuraTexture(frame, index)
  local aura = frame:CreateTexture(nil, "OVERLAY", -8)
  local time = frame:CreateFontString(nil, "OVERLAY") -- Duration Text

  time:SetJustifyH("CENTER")
  time:SetJustifyV("CENTER")
  time:SetShadowOffset(1, -1)
  aura.Time = time

  UpdateAuraTexture(frame, aura, index)

  return aura
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
  for i = index, frame.AurasNo do
    aura_texture = frame.Auras[i]
    aura_texture.Time:Hide()
    aura_texture:Hide()
  end

  frame.AurasNo = no_auras
  AlignWidget(frame)
end

local function OnUpdateBossModsWidget(frame, elapsed)
  if Enabled and EnabledByBossmod then
    frame.LastUpdate = frame.LastUpdate + elapsed
    if frame.LastUpdate < UPDATE_INTERVAL then
      return
    end
    frame.LastUpdate = 0

    local unit_auras = GUIDAuraList[frame.guid]
    if unit_auras and #unit_auras > 0 then
      UpdateFrameWithAuras(frame, unit_auras)
      return
    end
  end

  frame.BossModOnUpdateSet = false
  frame:SetScript("OnUpdate", nil)
  frame:_Hide()

--  if not Enabled or not EnabledByBossmod then
--    frame.BossModOnUpdateSet = false
--    frame:SetScript("OnUpdate", nil)
--    frame:_Hide()
--    return
--  end
--
--  frame.LastUpdate = frame.LastUpdate + elapsed
--  if frame.LastUpdate >= UPDATE_INTERVAL then
--    frame.LastUpdate = 0
--
--    local guid = frame.guid
--
--    local unit_auras = GUIDAuraList[guid]
--    if guid and unit_auras and #unit_auras > 0 then
--      UpdateFrameWithAuras(frame, unit_auras)
--    else
--      frame.BossModOnUpdateSet = false
--      frame:SetScript("OnUpdate", nil)
--      frame:_Hide()
--    end
--  end
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

  EnabledByBossmod = true

  -- Aura Info:
  --   1: aura texture (spell id)
  --   2: time the aura ends

  local unit_auras = GUIDAuraList[guid]
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
    GUIDAuraList[guid] = {
      {
        aura_texture,
        (duration and GetTime() + duration) or nil
      }
    }
    --guid_aura_list[guid] = unit_auras

    local frame = WidgetList[guid]
    if frame then
      UpdateFrameWithAuras(frame, GUIDAuraList[guid])
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
  local guid = (is_guid and unit) or UnitGUID(unit)
  if not guid then
    return
  end

  local unit_auras = GUIDAuraList[guid]
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
  EnabledByBossmod = false

  -- Cleanup, widget frame will be hidden on next update cycle, including with cleanup of all script handlers
  GUIDAuraList = {}
end

local function BossMod_DisableHostileNameplates()
  EnabledByBossmod = false

  -- Cleanup, widget frame will be hidden on next update cycle, including with cleanup of all script handlers
  GUIDAuraList = {}
end

---------------------------------------------------------------------------------------------------
-- Widget Functions for TidyPlates
---------------------------------------------------------------------------------------------------

local function UpdateSettings(frame)
  for i = 1, frame.AurasNo do
    UpdateAuraTexture(frame, frame.Auras[i], i)
  end

  frame.ConfigUpdatePending = true
end

local function UpdateWidgetFrame(frame, unit)
  if EnabledByBossmod and unit.guid then
    local unit_auras = GUIDAuraList[unit.guid]
    if unit_auras and #unit_auras > 0 then
      -- Update auras and alignment if settings were change or plate is re-shown
      if frame.ConfigUpdatePending then
        UpdateFrameWithAuras(frame, unit_auras)
        frame.ConfigUpdatePending = false
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
  if not unit.guid then
    frame:_Hide()
    return
  end

  if frame.guid then
    WidgetList[frame.guid] = nil
  end

  frame.guid = unit.guid
  frame.unit = unit
  WidgetList[unit.guid] = frame

--  if UnitGUID("target") == guid then
--    UpdateWidgetFrame(frame, unit)
--  else
--    frame:_Hide()
--  end
end

local function ClearWidgetContext(frame)
  if frame.guid then
    WidgetList[frame.guid] = nil
    frame.guid = nil
    frame.unit = nil
  end
end

local function enabled()
  ConfigDB = TidyPlatesThreat.db.profile.BossModsWidget
  Enabled = ConfigDB.ON or ConfigDB.ShowInHeadlineView

  if not Enabled then
    if DBM and CallbacksRegistered then
      DBM:UnregisterCallback('BossMod_ShowNameplateAura', BossMod_ShowNameplateAura)
      DBM:UnregisterCallback('BossMod_HideNameplateAura', BossMod_HideNameplateAura)
      DBM:UnregisterCallback('BossMod_DisableFriendlyNameplates', BossMod_DisableFriendlyNameplates)
      DBM:UnregisterCallback('BossMod_DisableHostileNameplates', BossMod_DisableHostileNameplates)
      CallbacksRegistered = false
    end
  else -- not ENABLED
    if DBM and not CallbacksRegistered then
      DBM:RegisterCallback('BossMod_ShowNameplateAura', BossMod_ShowNameplateAura)
      DBM:RegisterCallback('BossMod_HideNameplateAura', BossMod_HideNameplateAura)
      DBM:RegisterCallback('BossMod_DisableFriendlyNameplates', BossMod_DisableFriendlyNameplates)
      DBM:RegisterCallback('BossMod_DisableHostileNameplates', BossMod_DisableHostileNameplates)
      CallbacksRegistered = true
    end
  end

  return ConfigDB.ON
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
  frame:SetFrameLevel(frame:GetFrameLevel() + 2)
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

local EnabledConfigMode = false
function Addon:ConfigBossModsWidget()
  if not EnabledConfigMode then
    local guid = UnitGUID("target")
    if guid then
      BossMod_ShowNameplateAura("Configuration Mode", true, guid, GetSpellTexture(241600), nil)
      BossMod_ShowNameplateAura("Configuration Mode", true, guid, GetSpellTexture(207327), 7)
      BossMod_ShowNameplateAura("Configuration Mode", true, guid, GetSpellTexture(236513), 60)

      EnabledConfigMode = true
    else
      ThreatPlates.Print("Please select a target unit to enable configuration mode.", true)
    end
  else
    BossMod_DisableHostileNameplates()
    BossMod_DisableFriendlyNameplates()
    EnabledConfigMode = false
  end
end

ThreatPlatesWidgets.RegisterWidget("BossModsWidgetTPTP", CreateWidgetFrame, false, enabled, EnabledInHeadlineView)