---------------------------------------------------------------------------------------------------
-- Boss Mod Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewWidget("BossMods")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local floor = math.floor

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
local GUIDAuraList = {}
local ConfigDB
local EnabledByBossmod = false

local MAX_AURAS_NO = 5
local UPDATE_INTERVAL = 0.5

---------------------------------------------------------------------------------------------------
-- Boss Mods Widget Functions
---------------------------------------------------------------------------------------------------

local function AlignWidget(widget_frame)
  local db = TidyPlatesThreat.db.profile.BossModsWidget

  local offset_x = 0
  if widget_frame.AurasNo > 1 then
    offset_x = (widget_frame.AurasNo - 1) * (db.scale + db.AuraSpacing) / 2
  end

  local style = widget_frame:GetParent().stylename
  if style == "NameOnly" or style == "NameOnly-Unique" then
    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), - offset_x + db.x_hv, db.y_hv)
  else
    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), - offset_x + db.x, db.y)
  end

  widget_frame:SetSize(64, 64)
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

local function UpdateFrameWithAuras(widget_frame, unit_auras)
  local aura_texture, aura_info

  local no_auras = #unit_auras
  local index = 1
  while index <= no_auras do
    aura_info = unit_auras[index]

    aura_texture = widget_frame.Auras[index]
    if not aura_texture then
      aura_texture = CreateAuraTexture(widget_frame, index)
      widget_frame.Auras[index] = aura_texture
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
  for i = index, widget_frame.AurasNo do
    aura_texture = widget_frame.Auras[i]
    aura_texture.Time:Hide()
    aura_texture:Hide()
  end

  widget_frame.AurasNo = no_auras
  AlignWidget(widget_frame)
end

local function OnUpdateBossModsWidget(widget_frame, elapsed)
  widget_frame.LastUpdate = widget_frame.LastUpdate + elapsed
  if widget_frame.LastUpdate < UPDATE_INTERVAL then
    return
  end
  widget_frame.LastUpdate = 0

  if not EnabledByBossmod then
    widget_frame:Hide()
    return
  end

  local unit_auras = GUIDAuraList[widget_frame.unit.guid]
  if not unit_auras or #unit_auras == 0 then
    widget_frame:Hide()
    return
  end

  UpdateFrameWithAuras(widget_frame, unit_auras)
end

---------------------------------------------------------------------------------------------------
-- Callback functions for DBM
---------------------------------------------------------------------------------------------------

-- DBM:FireEvent("BossMod_ShowNameplateAura", isGUID, unit, currentTexture, duration, desaturate, addLine, lineColor)
local function BossMod_ShowNameplateAura(msg, is_guid, unit, aura_texture, duration, desaturate, addLine, lineColor)
  local guid = (is_guid and unit) or UnitGUID(unit)
  if not guid then
    -- ThreatPlates.DEBUG('bossmods show discarded unmatched name: ' .. unit)
    return
  end

  EnabledByBossmod = true

  -- Aura Info:
  --   1: aura texture (spell id)
  --   2: time the aura ends

  local no_auras = 0
  local unit_auras = GUIDAuraList[guid]
  if unit_auras then
    no_auras = #unit_auras
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
        (duration and (GetTime() + duration)) or nil,
      }
    end
  else
    GUIDAuraList[guid] = {
      {
        aura_texture,
        (duration and GetTime() + duration) or nil,
      }
    }
    --guid_aura_list[guid] = unit_auras
  end

  -- Show frame is this is the first aura shown (no_auras == 0 in this case)
  if no_auras == 0 then
    local plate = Addon.PlatesByGUID[guid]
    if plate then
      local widget_frame = plate.TPFrame.widgets["BossMods"]
      UpdateFrameWithAuras(widget_frame, GUIDAuraList[guid])

      widget_frame.LastUpdate = 0.5 -- to show the update immediately
      widget_frame:Show()
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

        local plate = Addon.PlatesByGUID[guid]
        if plate then
          UpdateFrameWithAuras(plate.TPFrame.widgets["BossMods"], unit_auras)
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
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 2)
  widget_frame.Auras = {}
  widget_frame.AurasNo = 0

  widget_frame.LastUpdate = 0.5
  widget_frame:SetScript("OnUpdate", OnUpdateBossModsWidget)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  return TidyPlatesThreat.db.profile.BossModsWidget.ON or TidyPlatesThreat.db.profile.BossModsWidget.ShowInHeadlineView
end

function Widget:OnEnable()
  if DBM then
    DBM:RegisterCallback('BossMod_ShowNameplateAura', BossMod_ShowNameplateAura)
    DBM:RegisterCallback('BossMod_DisableFriendlyNameplates', BossMod_DisableFriendlyNameplates)
    DBM:RegisterCallback('BossMod_HideNameplateAura', BossMod_HideNameplateAura)
    DBM:RegisterCallback('BossMod_DisableHostileNameplates', BossMod_DisableHostileNameplates)
  end
end

function Widget:OnDisable()
  if DBM then
    DBM:UnregisterCallback('BossMod_ShowNameplateAura', BossMod_ShowNameplateAura)
    DBM:UnregisterCallback('BossMod_HideNameplateAura', BossMod_HideNameplateAura)
    DBM:UnregisterCallback('BossMod_DisableFriendlyNameplates', BossMod_DisableFriendlyNameplates)
    DBM:UnregisterCallback('BossMod_DisableHostileNameplates', BossMod_DisableHostileNameplates)
  end
end

function Widget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return TidyPlatesThreat.db.profile.BossModsWidget.ShowInHeadlineView
  elseif style ~= "etotem" then
    return TidyPlatesThreat.db.profile.BossModsWidget.ON
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  ConfigDB = TidyPlatesThreat.db.profile.BossModsWidget

  if not EnabledByBossmod then
    widget_frame:Hide()
    return
  end

  local unit_auras = GUIDAuraList[unit.guid]

  if not unit_auras or #unit_auras == 0 then
    widget_frame:Hide()
    return
  end

  -- Update auras and alignment if settings were change or plate is re-shown
  for i = 1, widget_frame.AurasNo do
    UpdateAuraTexture(widget_frame, widget_frame.Auras[i], i)
  end
  UpdateFrameWithAuras(widget_frame, unit_auras)

  widget_frame:Show()
end

--function Widget:OnUpdateStyle(widget_frame, unit)
--  local db = TidyPlatesThreat.db.profile.BossModsWidget
--
--  local offset_x = 0
--  if widget_frame.AurasNo > 1 then
--    offset_x = (widget_frame.AurasNo - 1) * (db.scale + db.AuraSpacing) / 2
--  end
--
--  if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
--    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), - offset_x + db.x_hv, db.y_hv)
--  else
--    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), - offset_x + db.x, db.y)
--  end
--end

---------------------------------------------------------------------------------------------------
-- Configuration Mode
---------------------------------------------------------------------------------------------------

local EnabledConfigMode = false
function Addon:ConfigBossModsWidget()
  if not EnabledConfigMode then
    local guid = UnitGUID("target")
    if guid then
      BossMod_ShowNameplateAura("Configuration Mode", true, guid, GetSpellTexture(241600), nil, false, true, {1, 1, 0.5, 1})
      BossMod_ShowNameplateAura("Configuration Mode", true, guid, GetSpellTexture(207327), 7, false, true, {0, 0, 1, 1})
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