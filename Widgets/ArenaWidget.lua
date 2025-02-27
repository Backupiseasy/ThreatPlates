---------------------------------------------------------------------------------------------------
-- Arena Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = (Addon.IS_CLASSIC and {}) or Addon.Widgets:NewWidget("Arena")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs = pairs

-- WoW APIs
-- local GetNumArenaOpponents = GetNumArenaOpponents
local UnitExists = UnitExists
local IsInInstance = IsInInstance
local IsInBrawl = C_PvP.IsInBrawl
local UnitIsUnit = UnitIsUnit
local UnitInParty = UnitInParty
local UnitName = UnitName
local MAX_ARENA_ENEMIES = MAX_ARENA_ENEMIES or 5 -- MAX_ARENA_ENEMIES is not defined in Wrath Clasic
local GetAddOnEnableState = (C_AddOns and C_AddOns.GetAddOnEnableState)
    -- classic's GetAddonEnableState and retail's C_AddOns have their parameters swapped
    or function(name, character) return GetAddOnEnableState(character, name) end

-- ThreatPlates APIs
local Font = Addon.Font

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, UnitGUID

---------------------------------------------------------------------------------------------------
-- Constants and local variables
---------------------------------------------------------------------------------------------------
local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ArenaWidget\\"
local ICON_TEXTURE = PATH .. "BG"

local InArena = false
local PlayerGUIDToNumber = {}
--local ArenaID = {}

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local Settings
local SettingsByTeam = {
  HOSTILE = {},  
  FRIENDLY = {},
}

---------------------------------------------------------------------------------------------------
-- Arena Widget Functions
---------------------------------------------------------------------------------------------------

local ArenaUnitIdToNumber = {}
for i = 1, MAX_ARENA_ENEMIES do
  ArenaUnitIdToNumber["arena" .. i] = i
  ArenaUnitIdToNumber["arenapet" .. i] = i
  ArenaUnitIdToNumber["party" .. i] = i
  ArenaUnitIdToNumber["partypet" .. i] = i
end

-- local function GetArenaOpponents()
-- 	for i = 1, GetNumArenaOpponents() do
-- 		local player_guid = _G.UnitGUID("arena" .. i)
-- 		local pet_guid = _G.UnitGUID("arenapet" .. i)

--     if player_guid and not ArenaID[player_guid] then
--       ArenaID[player_guid] = i
-- 		end

-- 		if pet_guid and not ArenaID[pet_guid] then
-- 			ArenaID[pet_guid] = i
-- 		end
--   end
-- end

local function GetUnitArenaNumber(guid)
  return PlayerGUIDToNumber[guid]

  -- If the arena id of this unit is aleady known, don't update the list. Otherweise check for new arena players/pets
  -- GetArenaOpponents()
  --return ArenaID[guid]
end

local function GetFrameSortNumber(unitId)
  if GetAddOnEnableState("FrameSort", UnitName("player")) == 0 then
    -- framesort not installed
    return nil
  end

  local fs = FrameSortApi and FrameSortApi.v2

  if not fs then
    -- they are using an ancient unsupported version of FrameSort that doesn't have API support
    return nil
  end

  -- get an ordered list of units by their visual position
  local units = UnitInParty(unitId) and fs.Sorting:GetFriendlyUnits() or fs.Sorting:GetEnemyUnits()

  for frameNumber, unit in ipairs(units) do
    if UnitIsUnit(unitId, unit) then
      return frameNumber
    end
  end

  return nil
end

function Widget:PLAYER_ENTERING_WORLD()
  local _, instance_type = IsInInstance()
  if instance_type == "arena" and not IsInBrawl() then
    InArena = true
  
    -- Arenas are available from TBC Classic on. But ARENA_OPPONENT_UPDATE is also fired in BGs, 
    -- at least in Classic, not sure if also in Wrath/TBC Classic, so it's only enabled when in an arena
    self:RegisterEvent("ARENA_OPPONENT_UPDATE")
    -- Register GROUP_ROSTER_UPDATE here is it only should be used while in an arena, not in, e.g., a dungeon.
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
  else
    self:UnregisterEvent("ARENA_OPPONENT_UPDATE")
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")

    InArena = false
    PlayerGUIDToNumber = {}
    --ArenaID = {} -- Clear the table when we leave
  end
end

function Widget:PVP_MATCH_ACTIVE()
  PlayerGUIDToNumber = {}
end

-- function Widget:ARENA_PREP_OPPONENT_SPECIALIZATIONS()
--   --ArenaID = {} -- Clear the table when we leave
--   PlayerGUIDToNumber = {}

--   -- if IsSoloShuffle() then
--   --   -- GetArenaOpponents()
--   --   self:UpdateAllFrames()
--   -- end
-- end

function Widget:UpdateFriendyPlayerOrPet(unitid)
  if UnitExists(unitid) then
    local guid = _G.UnitGUID(unitid)
    PlayerGUIDToNumber[guid] = ArenaUnitIdToNumber[unitid]
    local widget_frame = self:GetWidgetFrameForUnit(unitid)
    if widget_frame then
      self:OnUnitAdded(widget_frame, unitid)
    end
  end
end

-- Parameters: unitToken, updateReason
--   updateReason: seen, destroyed, unseen, cleared
function Widget:ARENA_OPPONENT_UPDATE(unitid, update_reason)
  -- Only registered when in solo shuffles
  local guid = _G.UnitGUID(unitid)
  if guid then
    if update_reason == "seen" then
      PlayerGUIDToNumber[guid] = ArenaUnitIdToNumber[unitid]
    else
      PlayerGUIDToNumber[guid] = nil
    end

    local widget_frame = self:GetWidgetFrameForUnit(unitid)
    if widget_frame then
      self:OnUnitAdded(widget_frame, unitid)
    end
  end
end

function Widget:GROUP_ROSTER_UPDATE()
  for i = 1, 5 do
    self:UpdateFriendyPlayerOrPet("party" .. i)
    self:UpdateFriendyPlayerOrPet("partypet" .. i)
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = _G.CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------
  -- widget_frame:SetSize(32, 32)
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)

  widget_frame.Icon = widget_frame:CreateTexture(nil, "ARTWORK")
  widget_frame.Icon:SetAllPoints(widget_frame)
  widget_frame.Icon:SetTexture(ICON_TEXTURE)

  widget_frame.NumText = widget_frame:CreateFontString(nil, "ARTWORK")

  self:UpdateLayout(widget_frame)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  return Addon.db.profile.arenaWidget.ON
end

function Widget:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  if Addon.IS_MAINLINE then
    self:RegisterEvent("PVP_MATCH_ACTIVE")
  end

  self:PLAYER_ENTERING_WORLD()
end

function Widget:EnabledForStyle(style, unit)
  return unit.reaction ~= "NEUTRAL" and not (style == "NameOnly" or style == "NameOnly-Unique" or style == "etotem")
end

function Widget:OnUnitAdded(widget_frame, unit)
  if not InArena then
    widget_frame:Hide()
    return
  end

  local arena_no = GetUnitArenaNumber(unit.guid)

  if not arena_no then
    widget_frame:Hide()
    return
  end

  local settings = SettingsByTeam[unit.reaction]

  if settings.UseFrameSort then
    local fsNumber = GetFrameSortNumber(unit.unitid)
    arena_no = fsNumber or arena_no
  end

  widget_frame.Random = arena_no

  if settings.ShowOrb then
    local icon_color = settings.OrbColors[arena_no]
    widget_frame.Icon:SetVertexColor(icon_color.r, icon_color.g, icon_color.b, icon_color.a)
    widget_frame.Icon:Show()
  else
    widget_frame.Icon:Hide()
  end

  if settings.ShowNumber then
    local number_color = settings.NumberColors[arena_no]
    widget_frame.NumText:SetTextColor(number_color.r, number_color.g, number_color.b)
    widget_frame.NumText:SetText(arena_no)
    widget_frame.NumText:Show()
  else
    widget_frame.NumText:Hide()
  end

  if settings.HideName then
    widget_frame:GetParent().visual.name:Hide()
  elseif Addon.db.profile.settings.name.show then
    widget_frame:GetParent().visual.name:Show()
  end

  widget_frame:Show()
end

-- Used in ARENA_PREP_OPPONENT_SPECIALIZATIONS
-- Widget.UpdateFrame = Widget.OnUnitAdded

function Widget:UpdateLayout(widget_frame)
  -- Updates based on settings
  widget_frame:SetPoint("CENTER", widget_frame:GetParent(), Settings.x, Settings.y)
  widget_frame:SetSize(Settings.scale, Settings.scale)

  Font:UpdateText(widget_frame, widget_frame.NumText, Settings.NumberText)
end

function Widget:UpdateSettings()
  Settings = Addon.db.profile.arenaWidget

  SettingsByTeam.HOSTILE.ShowOrb = Settings.ShowOrb
  SettingsByTeam.HOSTILE.ShowNumber = Settings.ShowNumber
  SettingsByTeam.HOSTILE.HideName = Settings.HideName
  SettingsByTeam.HOSTILE.UseFrameSort = Settings.UseFrameSort
  SettingsByTeam.HOSTILE.OrbColors = Settings.colors
  SettingsByTeam.HOSTILE.NumberColors = Settings.numColors
  SettingsByTeam.FRIENDLY = Settings.Allies

  -- If the widget is enabled when in an arena, PLAYER_ENTERING_WORLD was already fired, so we have to update
  -- call it manually
  self:PLAYER_ENTERING_WORLD()

  for unitid, _ in pairs(ArenaUnitIdToNumber) do
    if UnitExists(unitid) then
      local guid = _G.UnitGUID(unitid)
      -- The nameplate is updated after the settings update by WidgetHandler
      PlayerGUIDToNumber[guid] = ArenaUnitIdToNumber[unitid]
    end
  end
end
