---------------------------------------------------------------------------------------------------
-- Combo points are only be shown on one single nameplate. They are shown
--   - on the current target (if it is attackable) or
--   - on the current soft-enemy target (if it is attackable) and the current target cannot be attacked
-- Combo points are only shown when the player is in combat or - out of combat - when at least one CP is active.
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = Addon.Widgets:NewTargetWidget("ComboPoints")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local unpack, type, sort = unpack, type, sort
local floor, min = floor, min
local tostring, string_format = tostring, string.format

-- WoW APIs
local GetTime, tContains = GetTime, tContains
local UnitCanAttack = UnitCanAttack
local UnitPower, UnitPowerMax, GetComboPoints, GetRuneCooldown, GetRuneType = UnitPower, UnitPowerMax, GetComboPoints, GetRuneCooldown, GetRuneType
local GetUnitChargedPowerPoints, GetPowerRegenForPowerType = GetUnitChargedPowerPoints, GetPowerRegenForPowerType
local GetSpellInfo, IsSpellUsable = Addon.GetSpellInfo, C_Spell and C_Spell.IsSpellUsable
local GetShapeshiftFormID = GetShapeshiftFormID
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local InCombatLockdown = InCombatLockdown
local GetSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or _G.GetSpecialization

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
  ARCANE_CHARGES = true,
  ESSENCE = true -- Evoker
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
  EVOKER = {
    PowerType = Enum.PowerType.Essence,
    Name = "ESSENCE",
  },
  MAGE = {
    [1] = {
      PowerType = Enum.PowerType.ArcaneCharges,
      Name = "ARCANE_CHARGES",
    },
  },
  MONK = {
    [1] = Addon.ExpansionIsBetween(LE_EXPANSION_MISTS_OF_PANDARIA, LE_EXPANSION_LEGION) and {
      PowerType = Enum.PowerType.Chi,
      Name = "CHI",
    },
    [2] = Addon.ExpansionIsBetween(LE_EXPANSION_MISTS_OF_PANDARIA, LE_EXPANSION_LEGION) and {
      PowerType = Enum.PowerType.Chi,
      Name = "CHI",
    },
    [3] = {
      PowerType = Enum.PowerType.Chi,
      Name = "CHI",
    },
    [5] = Addon.ExpansionIsBetween(LE_EXPANSION_MISTS_OF_PANDARIA, LE_EXPANSION_LEGION) and {
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
    EVOKER = {
      -- Texture = "UF-Essence-Icon-Active",
      -- TextureOff = "UF-Essence-BG",
      IconWidth = 13,
      IconHeight = 13,
      -- TexCoord = { 0, 1, 0, 1 }
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
  },
  Script = {}
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
local DeathKnightSpecColor
local SettingsCooldown, ShowCooldownDuration, OnUpdateCooldownDuration

---------------------------------------------------------------------------------------------------
-- Combo Points Widget Functions
---------------------------------------------------------------------------------------------------

-- GetSpecialization: Mists - Patch 5.0.4 (2012-08-28): Replaced GetPrimaryTalentTree.
if Addon.ExpansionIsAtLeastMists then
    function Widget:DetermineUnitPower()
      local power_type = UNIT_POWER[PlayerClass]
      if power_type then
        power_type = power_type[GetSpecialization()] or power_type
      end
  
      if power_type and power_type.Name then
        self.PowerType = power_type.PowerType
        self.UnitPowerMax = UnitPowerMax("player", self.PowerType)
      else
        self.PowerType = nil
        self.UnitPowerMax = 0
      end
    end  
else
  -- This should not be necessary as in Classic only Rogues and Druids had combo points
  if PlayerClass == "ROGUE" or PlayerClass == "DRUID" then
    UnitPower = function(unitToken , powerType)
      return GetComboPoints("player", "anyenemy")
    end
  elseif PlayerClass == "DEATHKNIGHT" then
    -- Deathknight is only available after Wrath, so no check for this version necessary
    UnitPowerMax = function(unitToken , powerType)
      return 6
    end

    -- Fix the wrong ordering of GetRuneCooldown (blood/unholy/frost) compared to UI display (blood/frost/unholy)
    local GET_RUNE_COOLDOWN_MAPPING = { 1, 2, 5, 6, 3, 4 }

    GetRuneCooldown = function(rune_id)
      return _G.GetRuneCooldown(GET_RUNE_COOLDOWN_MAPPING[rune_id])
    end

    -- GetRuneType: This API only exists in Wrath Classic and Classic Era.
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

    for i = 1, self.UnitPowerMax do
      local cp_texture = widget_frame.ComboPoints[i]
      local cp_texture_off = widget_frame.ComboPointsOff[i]

      if points >= i then
        local cp_color = color[i]
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

local function UpdateComboPointsFunctionForRogues()
  if PlayerClass ~= "ROGUE" then return end

  -- Check for spell Supercharge: 470398 -- added with 11.0.5
  -- Check for spell Echoing Reprimand: 323547
  if IsPlayerSpell(470347) or IsSpellUsable(323547) then
    Widget.UpdateUnitResource = Widget.UpdateComboPointsRogueWithAnimacharge

    TEXTURE_INFO.Script["ComboPoint.Charged.On"]  = Addon:GetIconTexture("ComboPoint.Charged.On")
    TEXTURE_INFO.Script["ComboPoint.Charged.Off"] = Addon:GetIconTexture("ComboPoint.Charged.Off")
    TEXTURE_INFO.Script.IsEnabled = TEXTURE_INFO.Script.IsEnabled and TEXTURE_INFO.Script["ComboPoint.Charged.On"] ~= nil and TEXTURE_INFO.Script["ComboPoint.Charged.Off"] ~= nil
  else
    Widget.UpdateUnitResource = Widget.UpdateComboPoints
  end

  Widget.Colors.AnimaCharge = Widget.db.ColorBySpec.ROGUE.Animacharge
end

function Widget:UpdateComboPointsRogueWithAnimacharge(widget_frame)
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

    for i = 1, self.UnitPowerMax do
      cp_texture = widget_frame.ComboPoints[i]
      cp_texture_off = widget_frame.ComboPointsOff[i]

      local point_is_chared = charged_points and tContains(charged_points, i)
      if point_is_chared then
        cp_texture.IsCharged = true
        if TEXTURE_INFO.Script.IsEnabled then
          Addon:UpdateIconTexture(cp_texture, TEXTURE_INFO.Script["ComboPoint.Charged.On"])
          Addon:UpdateIconTexture(cp_texture_off, TEXTURE_INFO.Script["ComboPoint.Charged.Off"])
        elseif self.db.Style == "Blizzard" then
          cp_texture:SetAtlas("ClassOverlay-ComboPoint-Kyrian")
          cp_texture_off:SetAtlas("ClassOverlay-ComboPoint-Off-Kyrian")
        else
          cp_texture:SetTexture(self.Texture .. "Animacharge")
          cp_texture_off:SetTexture(self.TextureOff .. "Animacharge")
        end
      elseif cp_texture.IsCharged then
        cp_texture.IsCharged = false
        if TEXTURE_INFO.Script.IsEnabled then
          Addon:UpdateIconTexture(cp_texture, TEXTURE_INFO.Script["ComboPoint." .. tostring(i) .. ".On"])
          Addon:UpdateIconTexture(cp_texture_off, TEXTURE_INFO.Script["ComboPoint." .. tostring(i) .. ".Off"])
        elseif self.db.Style == "Blizzard" then
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
end

---------------------------------------------------------------------------------------------------
-- Deathknight Runes
---------------------------------------------------------------------------------------------------

local GetRuneStatus, UpdateRuneStatusActive, UpdateRuneStatusInactive

local function OnUpdateWidgetRune(cooldown_frame, elapsed)
  -- Update the number of seconds since the last update
  cooldown_frame.TimeSinceLastUpdate = cooldown_frame.TimeSinceLastUpdate + elapsed

  if cooldown_frame.TimeSinceLastUpdate >= UPDATE_INTERVAL then
    cooldown_frame.TimeSinceLastUpdate = 0
    
    local widget_frame = cooldown_frame:GetParent()
    local current_time = floor(GetTime())

    for rune_id = 1, 6 do
      local cp_texture_off = widget_frame.ComboPointsOff[rune_id]

      if cp_texture_off:IsShown() then
        local cooldown = cp_texture_off.Time.Expiration - current_time
        if cooldown < 0 then
          cp_texture_off.Time:SetText(nil)
        else
          cp_texture_off.Time:SetText(cooldown)
          if cooldown <= 3 then
            local color = Widget.Colors.Expiring
            cp_texture_off.Time:SetTextColor(color.r, color.g, color.b)
          end
        end
      end
    end
  end
end

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
  if Widget.db.Style ~= "Blizzard" or TEXTURE_INFO.Script.IsEnabled then
    local cp_color = (rune_type == RUNETYPE_DEATH and Widget.Colors.DeathRune) or Widget.Colors[rune_id][rune_id]
    cp_texture:SetVertexColor(cp_color.r, cp_color.g, cp_color.b)
    cp_texture_off:SetVertexColor(cp_color.r, cp_color.g, cp_color.b)
  else
    cp_texture:SetTexture(RUNE_TEXTURES.Texture.RuneType[rune_type])
    cp_texture_off:SetTexture(RUNE_TEXTURES.TextureOff.RuneType[rune_type])
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

  if ShowCooldownDuration then
    local rune_cd = cp_texture_off.Time
    rune_cd.Expiration = rune_expiration
    local cooldown = rune_cd.Expiration - current_time
    rune_cd:SetText(cooldown)

    if cooldown <= 3 then
      local color = Widget.Colors.Expiring
      rune_cd:SetTextColor(color.r, color.g, color.b)
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
  if ShowCooldownDuration then
    local rune_cd = cp_texture_off.Time
    rune_cd.Expiration = rune_expiration
    rune_cd:SetText(rune_cd.Expiration - current_time)
    rune_cd:SetTextColor(DeathKnightSpecColor.r, DeathKnightSpecColor.g, DeathKnightSpecColor.b)

    rune_cd:Show()
  end
end

function Widget:UpdateRunes(widget_frame)
  local current_time = floor(GetTime())

  widget_frame.CooldownDuration:Hide()
  for rune_id = 1, 6 do
    local cp_texture = widget_frame.ComboPoints[rune_id]
    local cp_texture_off = widget_frame.ComboPointsOff[rune_id]

    local rune_expiration, rune_ready = GetRuneStatus(rune_id)
    if rune_ready then
      UpdateRuneStatusActive(cp_texture, cp_texture_off, rune_id)

      if ShowCooldownDuration then
        cp_texture_off.Time:Hide()
      end    
      
      cp_texture:Show()
      cp_texture_off:Hide()
    elseif self.db.ShowOffCPs then
      UpdateRuneStatusInactive(cp_texture, cp_texture_off, rune_id, current_time, rune_expiration)

      cp_texture:Hide()
      cp_texture_off:Show()
      widget_frame.CooldownDuration:Show()
    elseif cp_texture:IsShown() or cp_texture_off:IsShown() then
      cp_texture:Hide()
      cp_texture_off:Hide()
    
      if ShowCooldownDuration then
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

---------------------------------------------------------------------------------------------------
-- Evoker Essences
---------------------------------------------------------------------------------------------------

local function OnUpdateWidgetEssence(cooldown_frame, elapsed)
  local widget_frame = cooldown_frame:GetParent()
  local essence_filling = widget_frame.ComboPointsOff[widget_frame.LastActiveEssenceNo + 1]

  local duration = essence_filling.Expiration - GetTime()
  if duration > 0 then
    essence_filling.Time:SetText(string_format("%.1f", duration))
  else
    essence_filling.Time:SetText(nil)
  end
end

local function SetEssenceCooldownDuration(widget_frame, essence_no, essence_frame_off)
  local pace, _ = GetPowerRegenForPowerType(Widget.PowerType)
  if (pace == nil or pace == 0) then
    pace = 0.2
  end
  local cooldown_duration = 1 / pace

  if ShowCooldownDuration then
    local current_time = GetTime()

    local remaining_cooldown_duration = 0
    if widget_frame.LastActiveEssenceNo and essence_no < widget_frame.LastActiveEssenceNo then
      local last_essence_filling_frame = widget_frame.ComboPointsOff[widget_frame.LastActiveEssenceNo + 1]
      if last_essence_filling_frame then
        remaining_cooldown_duration = last_essence_filling_frame.Duration - (last_essence_filling_frame.Expiration - current_time)
        if remaining_cooldown_duration < 0 then
          remaining_cooldown_duration = 0
        end
      end
    end

    essence_frame_off.Duration = cooldown_duration
    essence_frame_off.Expiration = (cooldown_duration - remaining_cooldown_duration) + current_time

    essence_frame_off.Time:SetText(string_format("%.1f", essence_frame_off.Expiration - current_time))
  end

  return cooldown_duration
end

local function UpdateEssence(self, widget_frame)
  local active_essence_no = UnitPower("player", self.PowerType) or 0
  if active_essence_no == widget_frame.LastActiveEssenceNo and not widget_frame.ForceUpdate then return end

  local color = self.Colors[active_essence_no]
  local show_cooldown = false

  for essence_no = 1, self.UnitPowerMax do
    local essence_frame = widget_frame.ComboPoints[essence_no]
    local essence_frame_off = widget_frame.ComboPointsOff[essence_no]

    if active_essence_no >= essence_no then
      local cp_color = color[essence_no]
      essence_frame:SetVertexColor(cp_color.r, cp_color.g, cp_color.b)
      essence_frame:Show()
      essence_frame_off:Hide()
      essence_frame_off.Time:Hide()
    elseif self.db.ShowOffCPs then
      essence_frame:Hide()
      essence_frame_off:Show()

      if active_essence_no + 1 == essence_no then
        -- If there was a silent update, we just have to update the resource UI, but not the actual cooldown
        if active_essence_no ~= widget_frame.LastActiveEssenceNo then
          SetEssenceCooldownDuration(widget_frame, essence_no, essence_frame_off)
        end
        show_cooldown = ShowCooldownDuration
        essence_frame_off.Time:SetShown(show_cooldown)
      else
        essence_frame_off.Time:Hide()
      end
    elseif essence_frame:IsShown() or essence_frame_off:IsShown() then
      essence_frame:Hide()
      essence_frame_off:Hide()
      essence_frame_off.Time:Hide()
    else
      break
    end
  end
  
  widget_frame.CooldownDuration:SetShown(show_cooldown)
  
  widget_frame.LastActiveEssenceNo = active_essence_no
  widget_frame.ForceUpdate = false
end

local EssenceFillingAnimationTime = 5.0

    -- Essence Filling
    -- essence_frame.EssenceFilling:Hide();
    -- essence_frame.EssenceFilling.FillingAnim:Stop();
    -- essence_frame.EssenceFilling.CircleAnim:Stop();
    
    -- Essence Fill Done
    -- essence_frame.EssenceFillDone:Show();
    -- essence_frame.EssenceFillDone.AnimInOrig:Play()
    
    -- Essence Full
    -- essence_frame.EssenceFull:Show()

    -- Essence Depleting
    -- essence_frame.EssenceDepleting:Hide();
    -- essence_frame.EssenceDepleting.AnimInOrig:Play()

    -- Essence Empty - Background
    -- essence_frame.EssenceEmpty:Hide();
local function UpdateEssenceBlizzard(self, widget_frame)
  local active_essence_no = UnitPower("player", self.PowerType) or 0
  if active_essence_no == widget_frame.LastActiveEssenceNo and not widget_frame.ForceUpdate then return end

  local show_cooldown = false

  for essence_no = 1, self.UnitPowerMax do
    local essence_frame = widget_frame.ComboPoints[essence_no]

    if essence_no <= active_essence_no then
      essence_frame.EssenceFilling:Hide()
      essence_frame.EssenceFilling.FillingAnim:Stop()
      essence_frame.EssenceFilling.CircleAnim:Stop()
      -- Show FillDone only for essence that is now filled
      -- Otherwise, there will be a initial animation when you click on a enemy unit and essences are shown the first time
      --if essence_no == widget_frame.LastActiveEssenceNo then
      if not essence_frame.EssenceFillDone:IsShown() then
        essence_frame.EssenceFillDone:Show()
        essence_frame.EssenceFillDone.AnimInOrig:Play()
      end
      essence_frame.EssenceFull:Show()
      essence_frame.EssenceEmpty:Hide()
      essence_frame:Show()

      essence_frame.Time:Hide()
    else
      essence_frame.EssenceFull:Hide()
      essence_frame.EssenceEmpty:Show()
      --essence_frame.Time:Hide()
      
      if essence_no == active_essence_no + 1 then
        -- If there was a silent update, we just have to update the resource UI, but not the actual cooldown
        if active_essence_no ~= widget_frame.LastActiveEssenceNo then
          local cooldown_duration = SetEssenceCooldownDuration(widget_frame, essence_no, essence_frame)

          if not essence_frame.EssenceFull:IsShown() then 
            local animation_speed_multiplier = EssenceFillingAnimationTime / cooldown_duration;
            essence_frame.EssenceFilling.FillingAnim:SetAnimationSpeedMultiplier(animation_speed_multiplier)
            essence_frame.EssenceFilling.CircleAnim:SetAnimationSpeedMultiplier(animation_speed_multiplier)
          end
        end
        show_cooldown = ShowCooldownDuration
        essence_frame.Time:SetShown(show_cooldown)

        if not essence_frame.EssenceFull:IsShown() then 
          -- local animation_speed_multiplier = EssenceFillingAnimationTime / cooldown_duration;
          -- essence_frame.EssenceFilling.FillingAnim:SetAnimationSpeedMultiplier(animation_speed_multiplier)
          -- essence_frame.EssenceFilling.CircleAnim:SetAnimationSpeedMultiplier(animation_speed_multiplier)
          essence_frame.EssenceFilling:Show()
          essence_frame.EssenceFillDone:Hide()
          essence_frame.EssenceFull:Hide()
          essence_frame.EssenceDepleting:Hide()
          essence_frame.EssenceEmpty:Hide()
        end
      else
        if essence_frame.EssenceFilling:IsShown() or essence_frame.EssenceFillDone:IsShown() or essence_frame.EssenceFull:IsShown() then
          if not essence_frame.EssenceDepleting:IsShown() then
            essence_frame.EssenceDepleting:Show()
            essence_frame.EssenceDepleting.AnimInOrig:Play()
          end
          essence_frame.EssenceFilling:Hide()
          essence_frame.EssenceFillDone:Hide()
          essence_frame.EssenceFillDone.AnimInOrig:Stop()
        essence_frame.EssenceFull:Hide()
          essence_frame.EssenceEmpty:Hide()
        end
        essence_frame:Show()
    
        essence_frame.Time:Hide()
      end
    end
  end

  widget_frame.CooldownDuration:SetShown(show_cooldown)
  
  widget_frame.LastActiveEssenceNo = active_essence_no
  widget_frame.ForceUpdate = false
end

local function UpdateEssenceBlizzardWhenHidden(self, widget_frame)
  local active_essence_no = UnitPower("player", self.PowerType) or 0
  if active_essence_no == widget_frame.LastActiveEssenceNo then return end

  for essence_no = 1, self.UnitPowerMax do
    if active_essence_no + 1 == essence_no then
      local essence_frame_off = widget_frame.ComboPointsOff[essence_no]
      SetEssenceCooldownDuration(widget_frame, essence_no, essence_frame_off)
    end
  end

  widget_frame.CooldownDuration:Hide()

  widget_frame.LastActiveEssenceNo = active_essence_no
  widget_frame.ForceUpdate = true
end

---------------------------------------------------------------------------------------------------
-- Helper Functions 
---------------------------------------------------------------------------------------------------

local function HideWidgetFrame(widget_frame)
  widget_frame:Hide()
  widget_frame:SetParent(nil)
end

  -- The combo points widget can only be shown once and can only be shown on either the target or on the soft-enemy target unit. 
  -- So, the widget will be shown on
  --   - on the current target (if attackable) or
  --   - on the soft-enemy target (if attackable) and the current target cannot be attacked
local function GetCurrentTargetUnitID()
  -- UnitCanAttack is false if there is no target or softenemy target
  return (UnitCanAttack("player", "target") and "target") or (UnitCanAttack("player", "softenemy") and "softenemy") or nil
end

---------------------------------------------------------------------------------------------------
-- Event Handling
---------------------------------------------------------------------------------------------------

-- This event handler only watches for events of unit == "player"
local function EventHandler(event, unitid, power_type)
  if event == "UNIT_POWER_UPDATE" and not WATCH_POWER_TYPES[power_type] then return end
  -- UNIT_POWER_FREQUENT is only registred for Evoker, so no need to check here
  -- if event == "UNIT_POWER_FREQUENT" and not WATCH_POWER_TYPES[power_type] then return end

  local widget_frame = Widget.WidgetFrame
  if widget_frame:IsShown() then
    Widget:UpdateUnitResource(widget_frame)
  end
end

local function EventHandlerEvoker(event, unitid, power_type)
  local widget_frame = Widget.WidgetFrame
  if widget_frame:IsShown() then
    Widget:UpdateUnitResource(widget_frame)
  else
    UpdateEssenceBlizzardWhenHidden(Widget, widget_frame)
  end
end

local function UpdateWidgetAfterTalentChange()
  Widget:DetermineUnitPower()

  -- Optimization, not really necessary
  if not Widget.PowerType then return end

  -- GetSpecialization: Mists - Patch 5.0.4 (2012-08-28): Replaced GetPrimaryTalentTree.
  if Addon.ExpansionIsAtLeastMists then
    ActiveSpec = GetSpecialization()
    UpdateComboPointsFunctionForRogues()
  end

  -- Update the widget if it was already created (not true for immediately after Reload UI or if it was never enabled
  -- in this since last Reload UI)
  if Widget.WidgetFrame then
    Widget:PLAYER_TARGET_CHANGED()
  end
end

-- ACTIVE_TALENT_GROUP_CHANGED fires twice, so prevent that InitializeWidget is called twice (does not hurt,
-- but is not necesary either
-- For Rogues, the availability of spells is checked, but this information is not available when this event
-- fires the first time, so in this case the widget is updated every time this event fires
--
-- Arguments of ACTIVE_TALENT_GROUP_CHANGED (curr, prev) always seem to be 1, 1
function Widget:ACTIVE_TALENT_GROUP_CHANGED(...)
  -- GetSpecialization: Mists - Patch 5.0.4 (2012-08-28): Replaced GetPrimaryTalentTree.
  local current_spec = GetSpecialization()
  if ActiveSpec ~= current_spec or PlayerClass == "ROGUE" then
    -- Player switched to a spec that has combo points
    ActiveSpec = current_spec
    self.WidgetHandler:InitializeWidget("ComboPoints")
  end
end

-- This does not fire when the specialization is changed
function Widget:TRAIT_CONFIG_UPDATED(configID)
  if PlayerClass == "ROGUE" then
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
      -- TODO: Also handle .Time elements here?
    end

    self:PLAYER_TARGET_CHANGED()
  end
end

local function PlayerTargetChanged(tp_frame, unit)
  local widget = Widget
  local widget_frame = widget.WidgetFrame

  -- If this is an update because nameplate style switched from healthbar to headline view, 
  -- the widget might be needed to be shown/hidden depending on settings
  if widget:EnabledForStyle(unit.style, unit) then
    widget_frame:SetParent(tp_frame)
    widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
    
    widget_frame:ClearAllPoints()
    -- Updates based on settings / unit style
    local db = widget.db
    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
      widget_frame:SetPoint("CENTER", tp_frame, "CENTER", db.x_hv, db.y_hv)
    else
      widget_frame:SetPoint("CENTER", tp_frame, "CENTER", db.x, db.y)
    end
    
    widget:UpdateUnitResource(widget_frame)

    widget_frame:Show()
  else
    HideWidgetFrame(widget_frame)
  end
end

-- PLAYER_TARGET_CHANGED is triggered when entering combat and a unit attacking the player
-- Therefore, combo point widget must be shonw in this case (as the player enters combat).
-- ! So, don't check for WidgetFrame:IsShown() here
function Widget:PLAYER_TARGET_CHANGED()
  local target_unitid = GetCurrentTargetUnitID()
  local tp_frame = target_unitid and Widget:GetThreatPlateForUnit(target_unitid)
  if tp_frame then
    PlayerTargetChanged(tp_frame, tp_frame.unit)
  else
    HideWidgetFrame(self.WidgetFrame)
  end
end

Widget.PLAYER_SOFT_ENEMY_CHANGED = Widget.PLAYER_TARGET_CHANGED

function Widget:PLAYER_ENTERING_WORLD()
  -- From KuiNameplates: Update icons after zoning to workaround UnitPowerMax returning 0 when
  -- zoning into/out of instanced PVP, also in timewalking dungeons
  self:DetermineUnitPower()
  UpdateComboPointsFunctionForRogues()

  self:UpdateLayout()
end

-- As this event is only registered for druid characters, ShowInShapeshiftForm is true by initialization for all other classes
function Widget:UPDATE_SHAPESHIFT_FORM()
  self.ShowInShapeshiftForm = (GetShapeshiftFormID() == 1)

  if self.ShowInShapeshiftForm then
    self:PLAYER_TARGET_CHANGED()
  else
    HideWidgetFrame(self.WidgetFrame)
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:IsEnabled()
  local db = Addon.db.profile.ComboPoints
  local enabled = db.ON or db.ShowInHeadlineView

  -- ACTIVE_TALENT_GROUP_CHANGED: WotLK - Patch 3.2.0 (2009-08-04): Added.
  -- Other possibility for Classic: PLAYER_TALENT_UPDATE, CHARACTER_POINTS_CHANGED
  -- No need to use it for Classic, as GetSpecialization is not available there and CPs don't change between first 
  -- and second spec.
  if enabled then
    -- Register ACTIVE_TALENT_GROUP_CHANGED here otherwise it won't be registered when an spec is active that does not have combo points.
    -- If you then switch to a spec with talent points, the widget won't be enabled.
    -- ACTIVE_TALENT_GROUP_CHANGED requires dual spec which was added with Wrath
    -- TRAIT_CONFIG_UPDATED is only required for detecting enabling/disabling Rogue talent Supercharger
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", Addon.ExpansionIsAtLeastMists)  -- Added in patch 3.2.0 / 1.14.4
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", Addon.ExpansionIsAtLeastMists) -- Added in patch 10.0.0 / 1.14.4
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
  self:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED")
  self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
  

  if PlayerClass == "EVOKER" then
    -- Using UNIT_POWER_FREQUENT seems to reduce some lags with essence updates that are 
    -- otherwise happening compared to Blizzard essences (Blizzard_ClassNameplateBar uses this also)
    self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player", EventHandlerEvoker)
  else
    self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player", EventHandler)
    self:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player", EventHandler)
    self:RegisterUnitEvent("UNIT_POWER_POINT_CHARGE", "player", EventHandler)

    if PlayerClass == "DRUID" then
      self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
      self.ShowInShapeshiftForm = (GetShapeshiftFormID() == 1)
    elseif PlayerClass == "DEATHKNIGHT" then
      -- Never registered for Classic, as there is no Death Knight class
      self:RegisterEvent("RUNE_POWER_UPDATE", EventHandler)
      self:RegisterEvent("RUNE_TYPE_UPDATE", EventHandler)
    end
  end

  -- self:RegisterUnitEvent("UNIT_FLAGS", "player", EventHandler)
end

function Widget:OnDisable()
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  self:UnregisterEvent("PLAYER_TARGET_CHANGED")
  self:UnregisterEvent("PLAYER_SOFT_ENEMY_CHANGED")
  self:UnregisterEvent("UNIT_MAXPOWER")

  
  self:UnregisterEvent("UNIT_POWER_FREQUENT")
  self:UnregisterEvent("UNIT_POWER_UPDATE")
  self:UnregisterEvent("UNIT_DISPLAYPOWER")
  self:UnregisterEvent("UNIT_POWER_POINT_CHARGE")
  
  self:UnregisterEvent("UPDATE_SHAPESHIFT_FORM")
  self:UnregisterEvent("RUNE_POWER_UPDATE")
  self:UnregisterEvent("RUNE_TYPE_UPDATE")

  HideWidgetFrame(self.WidgetFrame)
end

function Widget:EnabledForStyle(style, unit)
  -- Unit can get attackable at some point in time (e.g., after a roleplay sequence
  -- if not UnitCanAttack("player", "anyenemy") then return false end

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

  -- OnTargetUnitAdded and OnTargetUnitRemoved are called for all target units including soft-target units. 
  -- But the combo points widget can only be shown once and can only be shown on either the target or on the soft-enemy target unit. 
  -- So, process (and show the widget) only if
  --   - the unit is the current target or
  --   - the unit is the current soft-enemy target and the current target cannot be attacked
function Widget:OnTargetUnitAdded(tp_frame, unit)
  local target_unitid = GetCurrentTargetUnitID()
  if target_unitid and UnitIsUnit(target_unitid, unit.unitid) then 
    PlayerTargetChanged(tp_frame, unit)
  end
end

-- OnTargetUnitAdded is called when entering combat.
-- Therefore, combo point widget must be shown in this case (as the player enters combat).
-- ! So, don't check for WidgetFrame:IsShown() here
function Widget:OnTargetUnitRemoved(tp_frame, unit)
  -- OnTargetUnitAdded and OnTargetUnitRemoved are called for all target units including soft-target units. 
  -- Only hide the widget if the nameplate for the unit is removed that shows the widget
  if tp_frame ~= self.WidgetFrame:GetParent() then return end
  
  HideWidgetFrame(self.WidgetFrame)
end

local function UpdateTexturePosition(texture, resource_index)
  local scale = Widget.db.Scale
  local scaled_icon_width = scale * Widget.IconWidth
  local scaled_icon_height = scale * Widget.IconHeight
  local scaled_spacing = scale * Widget.db.HorizontalSpacing

  texture:SetSize(scaled_icon_width, scaled_icon_height)
  texture:SetPoint("LEFT", Widget.WidgetFrame, "LEFT", (Widget.WidgetFrame:GetWidth() / Widget.UnitPowerMax) * (resource_index-1) + (scaled_spacing / 2), 0)
end

local function UpdateTexture(cp_status, texture, texture_path, resource_index)
  if TEXTURE_INFO.Script.IsEnabled then
    Addon:UpdateIconTexture(texture, TEXTURE_INFO.Script["ComboPoint." .. tostring(resource_index) .. "." .. cp_status])
  elseif Widget.db.Style == "Blizzard" then
    if Addon.ExpansionIsBetween(LE_EXPANSION_WRATH_OF_THE_LICH_KING, LE_EXPANSION_LEGION) and PlayerClass == "DEATHKNIGHT" then
      local texture_data = texture_path.RuneTypes
      texture:SetTexture(texture_data[resource_index])
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
    texture:SetTexCoord(unpack(Widget.TexCoord)) -- obj:SetTexCoord(left,right,top,bottom)
  else
    texture:SetTexture(texture_path)
    texture:SetTexCoord(unpack(Widget.TexCoord)) -- obj:SetTexCoord(left,right,top,bottom)
    --Addon:UpdateIconTexture(texture, texture_path, unpack(Widget.TexCoord))   
  end

  UpdateTexturePosition(texture, resource_index)
end

local function CreateResourceTextureStandard(widget_frame, resource_index)
  -- Create the texture if it does not exists or it is a frame (used for Blizzard essences) - if ComboPoints texture
  -- must be created, same is true for ComboPointsOff texture
  local resource_texture = widget_frame.ComboPoints[resource_index]
  local resource_off_texture = widget_frame.ComboPointsOff[resource_index]
  
  if not resource_texture or resource_texture.CreateTexture then
    if resource_texture then
      resource_texture:Hide()
      resource_off_texture:Hide()
      resource_off_texture.Time:Hide()
    end

    resource_texture = widget_frame:CreateTexture(nil, "ARTWORK", nil, 0)
    resource_off_texture = widget_frame:CreateTexture(nil, "ARTWORK", nil, 1)
    resource_off_texture.Time = widget_frame:CreateFontString(nil, "ARTWORK")

    -- Copy current cooldown values from previous layout
    if widget_frame.ComboPointsOff[resource_index] then
      resource_off_texture.Duration = widget_frame.ComboPointsOff[resource_index].Duration
      resource_off_texture.RemainingDuration = widget_frame.ComboPointsOff[resource_index].RemainingDuration
    end

    widget_frame.ComboPoints[resource_index] = resource_texture
    widget_frame.ComboPointsOff[resource_index] = resource_off_texture
  end

  UpdateTexture("On", resource_texture, Widget.Texture, resource_index)
  UpdateTexture("Off", resource_off_texture, Widget.TextureOff, resource_index)
end

local function CreateResourceTextureEssence(widget_frame, resource_index)
  local essence_frame = widget_frame.ComboPoints[resource_index]
  local essence_frame_off = widget_frame.ComboPointsOff[resource_index]

  if not essence_frame or not essence_frame.CreateTexture then
    if essence_frame then
      essence_frame:Hide()    
      essence_frame_off:Hide()
      essence_frame_off.Time:Hide()   
    end
  
    essence_frame = _G.CreateFrame("Button", "EvokerResource" .. tostring(resource_index), widget_frame, "EssencePointButtonTemplate")
    essence_frame.Time = essence_frame.EssenceFilling:CreateFontString(nil, "OVERLAY")
    
    -- Copy current cooldown values from previous layout
    if essence_frame_off then
      essence_frame.Duration = essence_frame_off.Duration
      essence_frame.RemainingDuration = essence_frame_off.RemainingDuration
    end

    essence_frame.ShowAnimation = { Play = function() end, Stop = function() end }
    essence_frame.EssenceFillDone.AnimInOrig = essence_frame.EssenceFillDone.AnimIn
    essence_frame.EssenceFillDone.AnimIn = { Play = function() end, Stop = function() end }
    essence_frame.EssenceFilling.FillingAnim:SetScript("OnFinished", nil)
    essence_frame.EssenceDepleting.AnimInOrig = essence_frame.EssenceDepleting.AnimIn
    essence_frame.EssenceDepleting.AnimIn = { Play = function() end, Stop = function() end }

    widget_frame.ComboPoints[resource_index] = essence_frame
    widget_frame.ComboPointsOff[resource_index] = essence_frame
  end

  UpdateTexturePosition(essence_frame, resource_index)
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

  widget_frame.CooldownDuration = widget_frame.CooldownDuration or _G.CreateFrame("Frame", "ComboPointsCooldowns", widget_frame)
  widget_frame.CooldownDuration:SetAllPoints(widget_frame)
  widget_frame.CooldownDuration:Hide()
  
  if ShowCooldownDuration then
    widget_frame.CooldownDuration.TimeSinceLastUpdate = 0
    widget_frame.CooldownDuration:SetScript("OnUpdate", OnUpdateCooldownDuration)
  else --if widget_frame.CooldownDuration then
    widget_frame.CooldownDuration:SetScript("OnUpdate", nil)
  end

  for resource_index = 1, self.UnitPowerMax do    
    if PlayerClass == "EVOKER" and db.Style == "Blizzard" then
      CreateResourceTextureEssence(widget_frame, resource_index)
    else
      CreateResourceTextureStandard(widget_frame, resource_index)
    end

    if ShowCooldownDuration then
      Font:UpdateText(widget_frame.ComboPoints[resource_index],  widget_frame.ComboPointsOff[resource_index].Time, SettingsCooldown)
    end
  end
end

function Widget:UpdateSettings()
  self.db = Addon.db.profile.ComboPoints

  self:DetermineUnitPower()

  -- Optimization, not really necessary
  if not self.PowerType then return end

  -- Update widget variables, only dependent from settings and static information (like player's class)
  local texture_info = TEXTURE_INFO[self.db.Style][PlayerClass] or TEXTURE_INFO[self.db.Style]
  self.TexCoord = texture_info.TexCoord
  self.IconWidth = texture_info.IconWidth
  self.IconHeight = texture_info.IconHeight
  self.Texture = texture_info.Texture
  self.TextureOff = texture_info.TextureOff

  local script_texture_info = TEXTURE_INFO.Script
  
  script_texture_info.IsEnabled = true
  local texture_cp_on = Addon:GetIconTexture("ComboPoint.On")
  local texture_cp_off = Addon:GetIconTexture("ComboPoint.Off")  
  
  local colors = self.db.ColorBySpec[PlayerClass]
  for current_cp = 1, #colors do
    local icon_id_cp_on = "ComboPoint." .. tostring(current_cp) .. ".On"
    local icon_id_cp_off = "ComboPoint." .. tostring(current_cp) .. ".Off"
    
    script_texture_info[icon_id_cp_on]  = Addon:GetIconTexture(icon_id_cp_on) or texture_cp_on
    script_texture_info[icon_id_cp_off] = Addon:GetIconTexture(icon_id_cp_off) or texture_cp_off

    script_texture_info.IsEnabled = script_texture_info.IsEnabled and script_texture_info[icon_id_cp_on] ~= nil and script_texture_info[icon_id_cp_off] ~= nil

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

  -- GetSpecialization: Mists - Patch 5.0.4 (2012-08-28): Replaced GetPrimaryTalentTree.
  if Addon.ExpansionIsAtLeastMists then
    ActiveSpec = GetSpecialization()
  end

  -- Some of this could be configured outside of UpdateSettings, as it does not change based on settings, but for easier maintenance
  -- I am configuring everything here
  if PlayerClass == "DEATHKNIGHT" then
    if Addon.ExpansionIsBetween(LE_EXPANSION_WRATH_OF_THE_LICH_KING, LE_EXPANSION_LEGION) then
      GetRuneStatus = GetRuneStateWrath
      UpdateRuneStatusActive = UpdateRuneStatusActiveWrath
      UpdateRuneStatusInactive = UpdateRuneStatusInactiveWrath
      self.UpdateUnitResource = self.UpdateRunes
      DeathKnightSpecColor = self.Colors.Neutral
    else
      GetRuneStatus = GetRuneStateMainline
      UpdateRuneStatusActive = UpdateRuneStatusActiveMainline
      UpdateRuneStatusInactive = UpdateRuneStatusInactiveMainline
      self.UpdateUnitResource = self.UpdateRunesMainline
      DeathKnightSpecColor = DEATHKNIGHT_COLORS.BySpec[ActiveSpec]
    end
    SettingsCooldown = self.db.RuneCooldown
    ShowCooldownDuration = SettingsCooldown.Show
    OnUpdateCooldownDuration = OnUpdateWidgetRune

    self.Colors.DeathRune = colors.DeathRune
  elseif PlayerClass == "EVOKER" then
    if self.db.Style == "Blizzard" then
      self.UpdateUnitResource = UpdateEssenceBlizzard
    else
      self.UpdateUnitResource = UpdateEssence
    end
    SettingsCooldown = self.db.EssenceCooldown
    ShowCooldownDuration = SettingsCooldown.Show
    OnUpdateCooldownDuration = OnUpdateWidgetEssence
  elseif PlayerClass == "ROGUE" then
    UpdateComboPointsFunctionForRogues()
  else
    self.UpdateUnitResource = self.UpdateComboPoints
  end

  -- Update the widget if it was already created (not true for immediately after Reload UI or if it was never enabled
  -- in this since last Reload UI)
  if self.WidgetFrame then
    self:UpdateLayout()
    self:PLAYER_TARGET_CHANGED()
  end
end 

function Widget:PrintDebug()
  Addon.Logging.Debug("    Textures:", TEXTURE_INFO.Script.IsEnabled and "ENABLED" or "DISABLED")
  local lines = {}
  for icon_id, texture_info in pairs(TEXTURE_INFO.Script) do
    if icon_id ~= "IsEnabled" then
      local texture = (type(texture_info) == "table" and texture_info.Texture) or texture_info
      lines[#lines + 1] = "      " .. icon_id .. " =>" .. tostring(texture)
    end
  end
  sort(lines)
  for _, line in ipairs(lines) do
    Addon.Logging.Debug(line)
  end
end