---------------------------------------------------------------------------------------------------
-- Combo Points Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewTargetWidget("ComboPoints")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local unpack, type = unpack, type
local floor = floor
local sort = sort

-- WoW APIs
local GetTime = GetTime
local UnitClass, UnitCanAttack = UnitClass, UnitCanAttack
local UnitPower, UnitPowerMax, GetComboPoints, GetRuneCooldown, GetRuneType = UnitPower, UnitPowerMax, GetComboPoints, GetRuneCooldown, GetRuneType
local GetUnitChargedPowerPoints = GetUnitChargedPowerPoints
local GetShapeshiftFormID = GetShapeshiftFormID
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local InCombatLockdown, IsInInstance = InCombatLockdown, IsInInstance

-- ThreatPlates APIs
local RGB = Addon.ThreatPlates.RGB
local Font = Addon.Font
local PlayerClass = Addon.PlayerClass

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, GetSpecialization

local UPDATE_INTERVAL = Addon.ON_UPDATE_INTERVAL

local WATCH_POWER_TYPES = {
  RUNIC_POWER = true,
  COMBO_POINTS = true,
  CHI = true,
  HOLY_POWER = true,
  SOUL_SHARDS = true,
  ARCANE_CHARGES = true
}

local UNIT_POWER = {
  DEATHKNIGHT= {
    PowerType = Enum.PowerType.Runes,
    Name = "RUNIC_POWER",
  },
  DRUID = {
    PowerType = Enum.PowerType.ComboPoints,
    Name = "COMBO_POINTS",
  },
  MAGE = {
    [1] = {
      PowerType = Enum.PowerType.ArcaneCharges,
      Name = "ARCANE_CHARGES",
    },
  },
  MONK = {
    [3] = {
      PowerType = Enum.PowerType.Chi,
      Name = "CHI",
    }
  },
  PALADIN = {
    PowerType = Enum.PowerType.HolyPower,
    Name = "HOLY_POWER",
  },
  ROGUE = {
    PowerType = Enum.PowerType.ComboPoints,
    Name = "COMBO_POINTS",
  },
  WARLOCK = {
    PowerType = Enum.PowerType.SoulShards,
    Name = "SOUL_SHARDS",
  },
}

local RUNETYPE_BLOOD, RUNETYPE_FROST, RUNETYPE_UNHOLY, RUNETYPE_DEATH = 1, 2, 3, 4

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ComboPointsWidget\\"
local TEXTURE_INFO = {
  Squares = {
    Texture = PATH .. "ComboPointDefault",
    TextureOff = PATH .. "ComboPointDefaultOff",
    TextureWidth = 128,
    TextureHeight = 64,
    IconWidth = 62 * 0.25,
    IconHeight = 34 * 0.25,
    TexCoord = { 0, 62 / 128, 0, 34 / 64 }
  },
  Orbs = {
    Texture = PATH .. "ComboPointOrb",
    TextureOff = PATH .. "ComboPointOrbOff",
    TextureWidth = 64,
    TextureHeight = 64,
    IconWidth = 60 * 0.22,
    IconHeight = 60 * 0.22,
    TexCoord = { 2/64, 62/64, 2/64, 62/64 }
  },
  Blizzard = {
    DEATHKNIGHT = {
      Texture = {
        [1] = { Atlas = "DK-Blood-Rune-Ready" },
        [2] = { Atlas = "DK-Frost-Rune-Ready" },
        [3] = { Atlas = "DK-Unholy-Rune-Ready" },
        RuneType = {
          [RUNETYPE_BLOOD] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Blood",
          [RUNETYPE_FROST] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Frost",
          [RUNETYPE_UNHOLY] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Unholy",
          [RUNETYPE_DEATH] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death",
        },
      },
      TextureOff = {
        [1] = { Atlas = "DK-Blood-Rune-Ready", Desaturation = 1, Alpha = 0.9 },
        [2] = { Atlas = "DK-Frost-Rune-Ready", Desaturation = 1, Alpha = 0.9 },
        [3] = { Atlas = "DK-Unholy-Rune-Ready", Desaturation = 1, Alpha = 0.9 },
        RuneType = {
          [RUNETYPE_BLOOD] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Blood",
          [RUNETYPE_FROST] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Frost",
          [RUNETYPE_UNHOLY] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Unholy",
          [RUNETYPE_DEATH] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death",
        },
      },
      IconWidth = 16,
      IconHeight = 16,
      TexCoord = { 0, 1, 0, 1 }
    },
    DRUID = {
      Texture = "ClassOverlay-ComboPoint",
      TextureOff = "ClassOverlay-ComboPoint-Off",
      IconWidth = 13,
      IconHeight = 13,
      TexCoord = { 0, 1, 0, 1 }
    },
    MAGE = {
      Texture = "Mage-ArcaneCharge",
      TextureOff = {
        [1] = { Atlas = "Mage-ArcaneCharge", Alpha = 0.3 },
      },
      IconWidth = 22,
      IconHeight = 22,
      TexCoord = { 0, 1, 0, 1 }
    },
    MONK = {
      Texture = "MonkUI-LightOrb",
      TextureOff = "MonkUI-OrbOff",
      IconWidth = 15,
      IconHeight = 15,
      TexCoord = { 0, 1, 0, 1 }
    },
    PALADIN = {
      Texture = "nameplates-holypower1-on",
      TextureOff = "nameplates-holypower1-off",
      IconWidth = 25,
      IconHeight = 19,
      TexCoord = { 0, 1, 0, 1 }
    },
    ROGUE = {
      Texture = "ClassOverlay-ComboPoint",
      TextureOff = "ClassOverlay-ComboPoint-Off",
      IconWidth = 13,
      IconHeight = 13,
      TexCoord = { 0, 1, 0, 1 }
    },
    WARLOCK = {
      Texture = "Warlock-ReadyShard",
      TextureOff = "Warlock-EmptyShard",
      IconWidth = 12,
      IconHeight = 16,
      TexCoord = { 0, 1, 0, 1 }
    },
  }
}

local DEATHKNIGHT_COLORS = {
  BySpec = {
    [1] = RGB(196, 30, 58),
    [2] = RGB(0, 102, 178),
    [3] = RGB(76, 204, 25),
  },
  -- ByRuneType = {
  --   [1] = RGB(255, 0, 0),
  --   [2] = RGB(0, 255, 255),
  --   [3] = RGB(0, 127, 0),
  --   [4] = RGB(204, 25, 255),  
  -- },
}

Widget.TextureCoordinates = {}
Widget.Colors = {
  Neutral = RGB(255, 255, 255),
  Expiring = RGB(255, 255, 0),
}
Widget.ShowInShapeshiftForm = true

-- WoW Clasic only knows one spec, so set default to 1 which is never changed as ACTIVE_TALENT_GROUP_CHANGED is never fired
local ActiveSpec = 1
local RuneCooldowns = { 0, 0, 0, 0, 0, 0 }

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local DeathKnightSpecColor, ShowRuneCooldown

---------------------------------------------------------------------------------------------------
-- Combo Points Widget Functions
---------------------------------------------------------------------------------------------------
if Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC then
  -- This should not be necessary as in Classic only Rogues and Druids had combo points
  if PlayerClass == "ROGUE" or PlayerClass == "DRUID" then
    UnitPower = function(unitToken , powerType)
      return GetComboPoints("player", "target")
    end
  elseif PlayerClass == "DEATHKNIGHT" then
    -- Deathknight is only available after Wrath, so no check for this version necessary
    UnitPowerMax = function(unitToken , powerType)
      return 6
    end

    -- Fix the wrong ordering of GetRuneCooldown (blood/unholy/frost) compared to UI display (blood/frost/unholy)
    local GET_RUNE_COOLDOWN_MAPPING = { 1, 2, 5, 6, 3, 4}

    GetRuneCooldown = function(rune_id)
      return _G.GetRuneCooldown(GET_RUNE_COOLDOWN_MAPPING[rune_id])
    end

    GetRuneType = function(rune_id)
      return _G.GetRuneType(GET_RUNE_COOLDOWN_MAPPING[rune_id])
    end
  end

  function Widget:DetermineUnitPower()
    local power_type = UNIT_POWER[PlayerClass]

    if power_type and power_type.Name then
      self.PowerType = power_type.PowerType
      self.UnitPowerMax = UnitPowerMax("player", self.PowerType)
    else
      self.PowerType = nil
      self.UnitPowerMax = 0
    end
  end
else
  function Widget:DetermineUnitPower()
    local power_type = UNIT_POWER[PlayerClass]
    if power_type then
      power_type = power_type[_G.GetSpecialization()] or power_type
    end

    if power_type and power_type.Name then
      self.PowerType = power_type.PowerType
      self.UnitPowerMax = UnitPowerMax("player", self.PowerType)
    else
      self.PowerType = nil
      self.UnitPowerMax = 0
    end
  end
end

function Widget:UpdateComboPoints(widget_frame)
  local points = UnitPower("player", self.PowerType) or 0

  if points == 0 and not InCombatLockdown() then
    for i = 1, self.UnitPowerMax do
      widget_frame.ComboPoints[i]:Hide()
      widget_frame.ComboPointsOff[i]:Hide()
    end
  else
    local color = self.Colors[points]
    local cp_texture, cp_texture_off, cp_color

    for i = 1, self.UnitPowerMax do
      cp_texture = widget_frame.ComboPoints[i]
      cp_texture_off = widget_frame.ComboPointsOff[i]

      if points >= i then
        cp_color = color[i]
        cp_texture:SetVertexColor(cp_color.r, cp_color.g, cp_color.b)
        cp_texture:Show()
        cp_texture_off:Hide()
      elseif self.db.ShowOffCPs then
        cp_texture:Hide()
        cp_texture_off:Show()
      elseif cp_texture:IsShown() or cp_texture_off:IsShown() then
        cp_texture:Hide()
        cp_texture_off:Hide()
      else
        break
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Rogue Combo Points: Anima Charges (Shadowlands)
---------------------------------------------------------------------------------------------------

function Widget:UpdateComboPointsRogueAnimacharge(widget_frame)
  local points = UnitPower("player", self.PowerType) or 0

  if points == 0 and not InCombatLockdown() then
    for i = 1, self.UnitPowerMax do
      widget_frame.ComboPoints[i]:Hide()
      widget_frame.ComboPointsOff[i]:Hide()
    end
  else
    local color = self.Colors[points]
    local cp_texture, cp_texture_off, cp_color

    local charged_points = GetUnitChargedPowerPoints("player")
    -- for i = 1, #charged_points do
    --   widget_frame.ComboPoints[charged_points[i].MarkAsCharged = true
    -- end

    for i = 1, self.UnitPowerMax do
      cp_texture = widget_frame.ComboPoints[i]
      cp_texture_off = widget_frame.ComboPointsOff[i]

      local point_is_chared = charged_points and tContains(charged_points, i)
      if point_is_chared then
        cp_texture.IsCharged = true
        if self.db.Style == "Blizzard" then
          cp_texture:SetAtlas("ClassOverlay-ComboPoint-Kyrian")
          cp_texture_off:SetAtlas("ClassOverlay-ComboPoint-Off-Kyrian")
        else
          cp_texture:SetTexture(self.Texture .. "Animacharge")
          cp_texture_off:SetTexture(self.TextureOff .. "Animacharge")
        end
      elseif cp_texture.IsCharged then
        cp_texture.IsCharged = false
        if self.db.Style == "Blizzard" then
          cp_texture:SetAtlas("ClassOverlay-ComboPoint")
          cp_texture_off:SetAtlas("ClassOverlay-ComboPoint-Off")
        else
          cp_texture:SetTexture(self.Texture)
          cp_texture_off:SetTexture(self.TextureOff)
        end
      end

      if points >= i then
        if self.db.Style ~= "Blizzard" then
          cp_color = (cp_texture.IsCharged and self.Colors.AnimaCharge) or color[i]
          cp_texture:SetVertexColor(cp_color.r, cp_color.g, cp_color.b)
        end
        cp_texture:Show()
        cp_texture_off:Hide()
      elseif self.db.ShowOffCPs then
        cp_texture:Hide()
        cp_texture_off:Show()
      elseif cp_texture:IsShown() or cp_texture_off:IsShown() then
        cp_texture:Hide()
        cp_texture_off:Hide()
      else
        break
      end
    end
  end

  --cp_texture.MarkAsCharged = false
end

---------------------------------------------------------------------------------------------------
-- Deathknight Runes
---------------------------------------------------------------------------------------------------

local GetRuneStatus, UpdateRuneStatusActive, UpdateRuneStatusInactive

local function GetRuneStateMainline(rune_id)
  return RuneCooldowns[rune_id], RuneCooldowns[rune_id] == 0
end

local function GetRuneStateWrath(rune_id)
  local start, duration, rune_ready = GetRuneCooldown(rune_id)
  return floor(start + duration), rune_ready
end

local RUNE_TEXTURES = TEXTURE_INFO.Blizzard.DEATHKNIGHT

local function UpdateRuneStatusActiveWrath(cp_texture, cp_texture_off, rune_id)
  local rune_type = GetRuneType(rune_id)
  if Widget.db.Style == "Blizzard" then
    cp_texture:SetTexture(RUNE_TEXTURES.Texture.RuneType[rune_type])
    cp_texture_off:SetTexture(RUNE_TEXTURES.TextureOff.RuneType[rune_type])
  else
    local cp_color = (rune_type == RUNETYPE_DEATH and Widget.Colors.DeathRune) or Widget.Colors[rune_id][rune_id]
    cp_texture:SetVertexColor(cp_color.r, cp_color.g, cp_color.b)
    cp_texture_off:SetVertexColor(cp_color.r, cp_color.g, cp_color.b)
  end
end

local function UpdateRuneStatusActiveMainline(cp_texture, cp_texture_off, rune_id, ready_runes_no)
  if Widget.db.Style ~= "Blizzard" then
    local cp_color = Widget.Colors[RuneCooldowns.NoRunesReady][rune_id]
    cp_texture:SetVertexColor(cp_color.r, cp_color.g, cp_color.b)
  end  
end

local function UpdateRuneStatusInactiveWrath(cp_texture, cp_texture_off, rune_id, current_time, rune_expiration)
  UpdateRuneStatusActiveWrath(cp_texture, cp_texture_off, rune_id)

  if ShowRuneCooldown then
    local rune_cd = cp_texture_off.Time
    rune_cd.Expiration = rune_expiration
    local cooldown = rune_cd.Expiration - current_time
    rune_cd:SetText(cooldown)

    if cooldown <= 3 then
      local color = Widget.Colors.Expiring
      cp_texture_off.Time:SetTextColor(color.r, color.g, color.b)
    else
      rune_cd:SetTextColor(DeathKnightSpecColor.r, DeathKnightSpecColor.g, DeathKnightSpecColor.b)
      
      -- local rune_type = GetRuneType(rune_id)
      -- if Widget.db.Style == "Blizzard" or rune_type == RUNETYPE_DEATH then
      --   local color = DEATHKNIGHT_COLORS.ByRuneType[rune_type]
      --   rune_cd:SetTextColor(color.r, color.g, color.b)
      -- else
      -- end
    end

    rune_cd:Show()
  end
end

local function UpdateRuneStatusInactiveMainline(cp_texture, cp_texture_off, rune_id, current_time, rune_expiration)
  if ShowRuneCooldown then
    local rune_cd = cp_texture_off.Time
    rune_cd.Expiration = rune_expiration
    rune_cd:SetText(rune_cd.Expiration - current_time)
    rune_cd:SetTextColor(DeathKnightSpecColor.r, DeathKnightSpecColor.g, DeathKnightSpecColor.b)

    rune_cd:Show()
  end
end

function Widget:UpdateRunes(widget_frame)
  local current_time = floor(GetTime())

  for rune_id = 1, 6 do
    local cp_texture = widget_frame.ComboPoints[rune_id]
    local cp_texture_off = widget_frame.ComboPointsOff[rune_id]

    local rune_expiration, rune_ready = GetRuneStatus(rune_id)
    if rune_ready then
      UpdateRuneStatusActive(cp_texture, cp_texture_off, rune_id)

      if ShowRuneCooldown then
        cp_texture_off.Time:Hide()
      end    
      
      cp_texture:Show()
      cp_texture_off:Hide()
    elseif self.db.ShowOffCPs then
      UpdateRuneStatusInactive(cp_texture, cp_texture_off, rune_id, current_time, rune_expiration)

      cp_texture:Hide()
      cp_texture_off:Show()
    elseif cp_texture:IsShown() or cp_texture_off:IsShown() then
      cp_texture:Hide()
      cp_texture_off:Hide()
    
      if ShowRuneCooldown then
        cp_texture_off.Time:Hide()
      end
    end
  end
end

function Widget:UpdateRunesMainline(widget_frame)
  local ready_runes_no = 0
  for rune_id = 1, 6 do
    local start, duration, rune_ready = GetRuneCooldown(rune_id)
    if rune_ready then
      ready_runes_no = ready_runes_no + 1
      RuneCooldowns[rune_id] = 0
    else
      RuneCooldowns[rune_id] = floor(start + duration)
    end
  end

  RuneCooldowns.NoRunesReady = ready_runes_no

  sort(RuneCooldowns)

  self:UpdateRunes(widget_frame)
end

-- function Widget:UpdateRunesWrath(widget_frame)
--   UpdateRunes(widget_frame)
-- end

---------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------

local function OnUpdateWidget(widget_frame, elapsed)
  -- Update the number of seconds since the last update
  widget_frame.TimeSinceLastUpdate = widget_frame.TimeSinceLastUpdate + elapsed

  if widget_frame.TimeSinceLastUpdate >= UPDATE_INTERVAL then
    widget_frame.TimeSinceLastUpdate = 0

    local current_time = floor(GetTime())
    local cp_texture_off
    for rune_id = 1, 6 do
      cp_texture_off = widget_frame.ComboPointsOff[rune_id]

      if cp_texture_off:IsShown() then
        local cooldown = cp_texture_off.Time.Expiration - current_time
        cp_texture_off.Time:SetText(cooldown)
        if cooldown <= 3 then
          local color = Widget.Colors.Expiring
          cp_texture_off.Time:SetTextColor(color.r, color.g, color.b)
        end
      end
    end
  end
end

-- This event handler only watches for events of unit == "player"
local function EventHandler(event, unitid, power_type)
  if event == "UNIT_POWER_UPDATE" and not WATCH_POWER_TYPES[power_type] then return end

  local plate = GetNamePlateForUnit("target")
  if plate then -- not necessary, prerequisite for IsShown(): plate.TPFrame.Active and
    local widget = Widget
    local widget_frame = widget.WidgetFrame
    if widget_frame:IsShown() then
      widget:UpdateUnitPower(widget_frame)
    end
  end
end

-- Arguments of ACTIVE_TALENT_GROUP_CHANGED (curr, prev) always seemt to be 1, 1
function Widget:ACTIVE_TALENT_GROUP_CHANGED(...)
  -- ACTIVE_TALENT_GROUP_CHANGED fires twice, so prevent that InitializeWidget is called twice (does not hurt,
  -- but is not necesary either
  local current_spec = _G.GetSpecialization()
  if ActiveSpec ~= current_spec then
    -- Player switched to a spec that has combo points
    ActiveSpec = current_spec
    self.WidgetHandler:InitializeWidget("ComboPoints")
  end
end

function Widget:UNIT_MAXPOWER(unitid, power_type)
  if self.PowerType then
    -- Number of max power units changed (e.g., for a rogue)
    self:DetermineUnitPower()
    self:UpdateLayout()

    -- remove excessive CP frames (when called after talent change)
    local widget_frame = self.WidgetFrame
    for i = self.UnitPowerMax + 1, #widget_frame.ComboPoints do
      widget_frame.ComboPoints[i]:Hide()
      widget_frame.ComboPoints[i] = nil
      widget_frame.ComboPointsOff[i]:Hide()
      widget_frame.ComboPointsOff[i] = nil
    end

    self:PLAYER_TARGET_CHANGED()
  end
end

function Widget:PLAYER_TARGET_CHANGED()
  local plate = GetNamePlateForUnit("target")

  local tp_frame = plate and plate.TPFrame
  if tp_frame and tp_frame.Active then
    self:OnTargetUnitAdded(tp_frame, tp_frame.unit)
  else
    self.WidgetFrame:Hide()
    self.WidgetFrame:SetParent(nil)
  end
end

function Widget:PLAYER_ENTERING_WORLD()
  -- From KuiNameplates: Update icons after zoning to workaround UnitPowerMax returning 0 when
  -- zoning into/out of instanced PVP, also in timewalking dungeons
  self:DetermineUnitPower()
  self:UpdateLayout()
end

-- As this event is only registered for druid characters, ShowInShapeshiftForm is true by initialization for all other classes
function Widget:UPDATE_SHAPESHIFT_FORM()
  self.ShowInShapeshiftForm = (GetShapeshiftFormID() == 1)

  if self.ShowInShapeshiftForm then
    self:PLAYER_TARGET_CHANGED()
  else
    self.WidgetFrame:Hide()
    self.WidgetFrame:SetParent(nil)
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:IsEnabled()
  local db = Addon.db.profile.ComboPoints
  local enabled = db.ON or db.ShowInHeadlineView

  if enabled and not (Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC) then
    -- Register ACTIVE_TALENT_GROUP_CHANGED here otherwise it won't be registered when an spec is active that does not have combo points.
    -- If you then switch to a spec with talent points, the widget won't be enabled.
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
  end

  self:DetermineUnitPower()

  return self.PowerType and enabled
end

-- EVENTS:
-- UNIT_COMBO_POINTS: -- combo points also fire UNIT_POWER
-- UNIT_POWER_UPDATE: "unitID", "powerType"  -- CHI, COMBO_POINTS
-- UNIT_DISPLAYPOWER: Fired when the unit's mana stype is changed. Occurs when a druid shapeshifts as well as in certain other cases.
--   unitID
-- UNIT_AURA: unitID
-- UNIT_FLAGS: unitID
-- UNIT_POWER_FREQUENT: unitToken, powerToken
function Widget:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
  self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
  
  if Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC then
    self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player", EventHandler)
  else
    self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player", EventHandler)
    self:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player", EventHandler)
    self:RegisterUnitEvent("UNIT_POWER_POINT_CHARGE", "player", EventHandler)
  end

  if PlayerClass == "DRUID" then
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    self.ShowInShapeshiftForm = (GetShapeshiftFormID() == 1)
  elseif PlayerClass == "DEATHKNIGHT" then
    -- Never registered for Classic, as there is no Death Knight class
    self:RegisterEvent("RUNE_POWER_UPDATE", EventHandler)
    if Addon.IS_WRATH_CLASSIC then
      self:RegisterEvent("RUNE_TYPE_UPDATE", EventHandler)
    end
  end

  -- self:RegisterUnitEvent("UNIT_FLAGS", "player", EventHandler)
end

function Widget:OnDisable()
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  self:UnregisterEvent("PLAYER_TARGET_CHANGED")
  self:UnregisterEvent("UNIT_MAXPOWER")
  
  if Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC then
    self:UnregisterEvent("UNIT_POWER_FREQUENT")
  else
    self:UnregisterEvent("UNIT_POWER_UPDATE")
    self:UnregisterEvent("UNIT_DISPLAYPOWER")
    self:UnregisterEvent("UNIT_POWER_POINT_CHARGE")
  end
  
  self:UnregisterEvent("UPDATE_SHAPESHIFT_FORM")
  if Addon.IS_WRATH_CLASSIC or Addon.IS_MAINLINE then
    self:UnregisterEvent("RUNE_POWER_UPDATE")
  end
  if Addon.IS_WRATH_CLASSIC then
    self:UnregisterEvent("RUNE_TYPE_UPDATE")
  end

  self.WidgetFrame:Hide()
  self.WidgetFrame:SetParent(nil)
end

function Widget:EnabledForStyle(style, unit)
  -- Unit can get attackable at some point in time (e.g., after a roleplay sequence
  -- if not UnitCanAttack("player", "target") then return false end

  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return self.db.ShowInHeadlineView and self.ShowInShapeshiftForm -- a little bit of a hack, logically would be better checked in OnTargetUnitAdded
  elseif style ~= "etotem" then
    return self.db.ON and self.ShowInShapeshiftForm
  end
end

function Widget:Create()
  if not self.WidgetFrame then
    local widget_frame = _G.CreateFrame("Frame", nil)
    widget_frame:Hide()

    self.WidgetFrame = widget_frame
    widget_frame.ComboPoints = {}
    widget_frame.ComboPointsOff = {}

--    local frameBackground = false -- debug frame size
--    if frameBackground then
--      widget_frame.Background = widget_frame:CreateTexture(nil, "BACKGROUND")
--      widget_frame.Background:SetAllPoints()
--      widget_frame.Background:SetColorTexture(1, 1, 1, 0.5)
--    end

    self:UpdateLayout()
  end

  self:PLAYER_TARGET_CHANGED()
end

function Widget:OnTargetUnitAdded(tp_frame, unit)
  local widget_frame = self.WidgetFrame

  if UnitCanAttack("player", "target") and self:EnabledForStyle(unit.style, unit) then
    widget_frame:SetParent(tp_frame)
    widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)

    widget_frame:ClearAllPoints()
    -- Updates based on settings / unit style
    local db = self.db
    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
      widget_frame:SetPoint("CENTER", tp_frame, "CENTER", db.x_hv, db.y_hv)
    else
      widget_frame:SetPoint("CENTER", tp_frame, "CENTER", db.x, db.y)
    end

    self:UpdateUnitPower(widget_frame)

    widget_frame:Show()
  else
    widget_frame:Hide()
    widget_frame:SetParent(nil)
  end
end

function Widget:OnTargetUnitRemoved()
  self.WidgetFrame:Hide()
end

function Widget:UpdateTexture(texture, texture_path, cp_no)
  if self.db.Style == "Blizzard" then
    if Addon.IS_WRATH_CLASSIC and PlayerClass == "DEATHKNIGHT" then
      local texture_data = texture_path.RuneType
      texture:SetTexture(texture_data[cp_no])
      texture:SetAlpha(texture_data.Alpha or 1)
      texture:SetVertexColor(1, 1, 1)
      texture:SetDesaturated(texture_data.Desaturation) -- nil means no desaturation
    elseif type(texture_path) == "table" then
      local texture_data = texture_path[ActiveSpec]
      texture:SetAtlas(texture_data.Atlas)
      texture:SetAlpha(texture_data.Alpha or 1)
      texture:SetVertexColor(1, 1, 1)
      texture:SetDesaturated(texture_data.Desaturation) -- nil means no desaturation
    else
      texture:SetAtlas(texture_path)
    end
  else
    texture:SetTexture(texture_path)
  end

  texture:SetTexCoord(unpack(self.TexCoord)) -- obj:SetTexCoord(left,right,top,bottom)
  local scale = self.db.Scale
  local scaledIconWidth, scaledIconHeight, scaledSpacing = (scale * self.IconWidth),(scale * self.IconHeight),(scale * self.db.HorizontalSpacing)
  texture:SetSize(scaledIconWidth, scaledIconHeight)
  texture:SetPoint("LEFT", self.WidgetFrame, "LEFT", (self.WidgetFrame:GetWidth()/self.UnitPowerMax)*(cp_no-1)+(scaledSpacing/2), 0)  
end

function Widget:UpdateLayout()
  local widget_frame = self.WidgetFrame

  -- Updates based on settings
  local db = self.db
  local scale = db.Scale
  local scaledIconWidth, scaledIconHeight, scaledSpacing = (scale * self.IconWidth),(scale * self.IconHeight),(scale * db.HorizontalSpacing)

  -- This was moved into the UpdateLayout from UpdateComboPointLaout as this was not updating after a ReloadUI
  -- Combo Point position is now based off of WidgetFrame width
  widget_frame:SetAlpha(db.Transparency)
  widget_frame:SetHeight(scaledIconHeight)
  widget_frame:SetWidth((scaledIconWidth * self.UnitPowerMax) + ((self.UnitPowerMax - 1) * scaledSpacing))

  local show_rune_cooldown = (PlayerClass == "DEATHKNIGHT") and ShowRuneCooldown

  for i = 1, self.UnitPowerMax do
    widget_frame.ComboPoints[i] = widget_frame.ComboPoints[i] or widget_frame:CreateTexture(nil, "ARTWORK", nil, 0)
    self:UpdateTexture(widget_frame.ComboPoints[i], self.Texture, i)

    widget_frame.ComboPointsOff[i] = widget_frame.ComboPointsOff[i] or widget_frame:CreateTexture(nil, "ARTWORK", nil, 1)
    self:UpdateTexture(widget_frame.ComboPointsOff[i], self.TextureOff, i)

    if show_rune_cooldown then
      local time_text = widget_frame.ComboPointsOff[i].Time or widget_frame:CreateFontString(nil, "ARTWORK")
      widget_frame.ComboPointsOff[i].Time = time_text

      Font:UpdateText(widget_frame.ComboPointsOff[i], time_text, db.RuneCooldown)
    elseif widget_frame.ComboPointsOff[i].Time then
      widget_frame.ComboPointsOff[i].Time:Hide()
    end
  end

  if show_rune_cooldown then
    widget_frame.TimeSinceLastUpdate = 0
    widget_frame:SetScript("OnUpdate", OnUpdateWidget)
  else
    widget_frame:SetScript("OnUpdate", nil)
  end
end

-- Do this here, not in UpdateSettings as it does not change with settings, but only with player class and WoW version
if PlayerClass == "DEATHKNIGHT" and Addon.IS_WRATH_CLASSIC then
  GetRuneStatus = GetRuneStateWrath
  UpdateRuneStatusActive = UpdateRuneStatusActiveWrath
  UpdateRuneStatusInactive = UpdateRuneStatusInactiveWrath
else
  GetRuneStatus = GetRuneStateMainline
  UpdateRuneStatusActive = UpdateRuneStatusActiveMainline
  UpdateRuneStatusInactive = UpdateRuneStatusInactiveMainline
end

function Widget:UpdateSettings()
  self.db = Addon.db.profile.ComboPoints

  self:DetermineUnitPower()

  -- Optimization, not really necessary
  if not self.PowerType then return end

  -- Update widget variables, only dependent from settings and static information (like player's class)
  local texture_info = TEXTURE_INFO[self.db.Style][PlayerClass] or TEXTURE_INFO[self.db.Style]

  if not (Addon.IS_CLASSIC or Addon.IS_TBC_CLASSIC or Addon.IS_WRATH_CLASSIC) then
    ActiveSpec = _G.GetSpecialization()
  end

  if PlayerClass == "DEATHKNIGHT" then
    if Addon.IS_WRATH_CLASSIC then
      self.UpdateUnitPower = self.UpdateRunes
      DeathKnightSpecColor = self.Colors.Neutral
    else
      self.UpdateUnitPower = self.UpdateRunesMainline
      DeathKnightSpecColor = DEATHKNIGHT_COLORS.BySpec[ActiveSpec]
    end
    ShowRuneCooldown = self.db.RuneCooldown.Show
  elseif PlayerClass == "ROGUE" then
    -- Check for spell Echoing Reprimand: (IDs) 312954, 323547, 323560, 323558, 323559
    local name = GetSpellInfo(323560) -- Get localized name for Echoing Reprimand
    if GetSpellInfo(name) then
      self.UpdateUnitPower = self.UpdateComboPointsRogueAnimacharge
    else
      self.UpdateUnitPower = self.UpdateComboPoints
    end
  else
    self.UpdateUnitPower = self.UpdateComboPoints
  end
  --print ("Echoing Reprimand:", self.UpdateUnitPower == self.UpdateComboPointsRogueAnimacharge)

  self.TexCoord = texture_info.TexCoord
  self.IconWidth = texture_info.IconWidth
  self.IconHeight = texture_info.IconHeight
  self.Texture = texture_info.Texture
  self.TextureOff = texture_info.TextureOff

  local colors = self.db.ColorBySpec[PlayerClass]
  for current_cp = 1, #colors do
    for cp_no = 1, #colors do

      self.Colors[current_cp] = self.Colors[current_cp] or {}
      if self.db.Style == "Blizzard" then
        self.Colors[current_cp][cp_no] = self.Colors.Neutral
      elseif self.db.UseUniformColor then
        -- Could add to the if clause: and not (Addon.IS_WRATH_CLASSIC and PlayerClass == "DEATHKNIGHT") 
        self.Colors[current_cp][cp_no] = colors[current_cp]
      else
        self.Colors[current_cp][cp_no] = colors[cp_no]
      end
    end
  end

  if PlayerClass == "ROGUE" then
    self.Colors.AnimaCharge = colors.Animacharge
  elseif PlayerClass == "DEATHKNIGHT" then
    self.Colors.DeathRune = colors.DeathRune
  end

  -- Update the widget if it was already created (not true for immediately after Reload UI or if it was never enabled
  -- in this since last Reload UI)
  if self.WidgetFrame then
    self:UpdateLayout()
    self:PLAYER_TARGET_CHANGED()
  end
end