local _, Addon = ...
local t = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local tonumber = tonumber

-- WoW APIs
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local SetNamePlateFriendlyClickThrough = C_NamePlate.SetNamePlateFriendlyClickThrough
local SetNamePlateEnemyClickThrough = C_NamePlate.SetNamePlateEnemyClickThrough
local UnitName, IsInInstance, InCombatLockdown = UnitName, IsInInstance, InCombatLockdown
local GetCVar, SetCVar, IsAddOnLoaded = GetCVar, SetCVar, IsAddOnLoaded
local C_NamePlate_SetNamePlateFriendlySize, C_NamePlate_SetNamePlateEnemySize, Lerp =  C_NamePlate.SetNamePlateFriendlySize, C_NamePlate.SetNamePlateEnemySize, Lerp
local NamePlateDriverFrame = NamePlateDriverFrame

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local LibStub = LibStub
local L = t.L

local class = t.Class()
t.Theme = {}

local task_queue_ooc = {}

---------------------------------------------------------------------------------------------------
-- Global configs and funtions
---------------------------------------------------------------------------------------------------

-- check if the correct TidyPlates version is installed
--function CheckTidyPlatesVersion()
  -- local GlobDB = TidyPlatesThreat.db.global
  -- if not GlobDB.versioncheck then
  -- 	local version_no = 0
  -- 	local version = string.gsub(TIDYPLATES_INSTALLED_VERSION, "Beta", "")
  -- 	for w in string.gmatch(version, "[0-9]+") do
  -- 		version_no = version_no * 1000 + (tonumber(w) or 0)
  -- 	end
  --
  -- 	if version_no < TIDYPLATES_MIN_VERSION_NO then
  -- 		t.Print("\n---------------------------------------\nThe current version of ThreatPlates requires at least TidyPlates "] .. TIDYPLATES_MIN_VERSION .. L[". You have installed an older or incompatible version of TidyPlates: "] .. TIDYPLATES_INSTALLED_VERSION .. L[". Please update TidyPlates, otherwise ThreatPlates will not work properly.")
  -- 	end
  -- 	GlobDB.versioncheck = true
  -- end
--end

t.Print = function(val,override)
  local db = TidyPlatesThreat.db.profile
  if override or db.verbose then
    print(t.Meta("titleshort")..": "..val)
  end
end

function TidyPlatesThreat:SpecName()
  local _,name,_,_,_,role = GetSpecializationInfo(GetSpecialization(false,false,1),nil,false)
  if name then
    return name
  else
    return L["Undetermined"]
  end
end

local tankRole = L["|cff00ff00tanking|r"]
local dpsRole = L["|cffff0000dpsing / healing|r"]

function TidyPlatesThreat:RoleText()
  if TidyPlatesThreat:GetSpecRole() then
    return tankRole
  else
    return dpsRole
  end
end

local EVENTS = {
  --"PLAYER_ALIVE",
  --"PLAYER_LEAVING_WORLD",
  --"PLAYER_TALENT_UPDATE"

  "PLAYER_ENTERING_WORLD",
  "PLAYER_LOGIN",
  "PLAYER_LOGOUT",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_REGEN_DISABLED",
  "QUEST_WATCH_UPDATE",
  "QUEST_ACCEPTED",

  "UNIT_ABSORB_AMOUNT_CHANGED",
  "UNIT_MAXHEALTH",

  -- "NAME_PLATE_CREATED",      -- processed by TidyPlatesCore

  -- "CVAR_UPDATE",
  --"NAME_PLATE_UNIT_ADDED",    -- Blizzard also uses this event
  --"NAME_PLATE_UNIT_REMOVED",  -- Blizzard also uses this event
  --"PLAYER_TARGET_CHANGED",    -- Blizzard also uses this event
  --"DISPLAY_SIZE_CHANGED",     -- Blizzard also uses this event
  --"UNIT_AURA",                -- used in auras widget
  --"VARIABLES_LOADED",         -- Blizzard also uses this event
  --"RAID_TARGET_UPDATE",       -- Blizzard also uses this event
}

local function EnableEvents()
  for i = 1, #EVENTS do
    TidyPlatesThreat:RegisterEvent(EVENTS[i])
  end
end

local function DisableEvents()
  for i = 1, #EVENTS do
    TidyPlatesThreat:UnregisterEvent(EVENTS[i])
  end
end

---------------------------------------------------------------------------------------------------
-- Functions called by TidyPlates
---------------------------------------------------------------------------------------------------

------------------
-- ADDON LOADED --
------------------

StaticPopupDialogs["TidyPlatesEnabled"] = {
  preferredIndex = STATICPOPUP_NUMDIALOGS,
  text = "|cffFFA500" .. t.Meta("title") .. " Warning|r \n----------------------------------------------------------\n" ..
    L["|cff89F559Threat Plates|r is no longer a theme of |cff89F559TidyPlates|r, but a standalone addon that does no longer require TidyPlates. Please disable one of these, otherwise two overlapping nameplates will be shown for units."],
  button1 = OKAY,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  OnAccept = function(self, _, _) end,
}

StaticPopupDialogs["IncompatibleAddon"] = {
  preferredIndex = STATICPOPUP_NUMDIALOGS,
  text = "|cffFFA500" .. t.Meta("title") .. " Warning|r \n----------------------------------------------------------\n" ..
    L["You currently have two nameplate addons enabled: |cff89F559Threat Plates|r and |cff89F559%s|r. Please disable one of these, otherwise two overlapping nameplates will be shown for units."],
  button1 = OKAY,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  OnAccept = function(self, _, _) end,
}

StaticPopupDialogs["SwitchToNewLookAndFeel"] = {
  preferredIndex = STATICPOPUP_NUMDIALOGS,
  text = t.Meta("title") .. L[":\n---------------------------------------\n|cff89F559Threat Plates|r v8.4 introduced a new default look and feel (currently shown). Do you want to switch to this new look and feel?\n\nYou can revert your decision by changing the default look and feel again in the options dialog (under General - Healthbar View - Default Settings).\n\nNote: Some of your custom settings may get overwritten if you switch back and forth."],
  button1 = L["Switch"],
  button2 = L["Don't Switch"],
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  OnAccept = function(self, _, _)
    TidyPlatesThreat.db.global.DefaultsVersion = "SMOOTH"
    TidyPlatesThreat.db.global.CheckNewLookAndFeel = true
    t.SwitchToCurrentDefaultSettings()
    TidyPlatesThreat:ReloadTheme()
  end,
  OnCancel = function(self, data, action)
    if action == "clicked" then
      TidyPlatesThreat.db.global.DefaultsVersion = "CLASSIC"
      TidyPlatesThreat.db.global.CheckNewLookAndFeel = true
      t.SwitchToDefaultSettingsV1()
      TidyPlatesThreat:ReloadTheme()
    end
  end,
}

function TidyPlatesThreat:ReloadTheme()
  -- Recreate all TidyPlates styles for ThreatPlates("normal", "dps", "tank", ...) - required, if theme style settings were changed
  t.SetThemes(self)

  -- ForceUpdate() is called in SetTheme(), also calls theme.OnActivateTheme,
  -- With TidyPlates:
  --if TidyPlates.GetThemeName() == t.THEME_NAME then
  --  TidyPlates:SetTheme(t.THEME_NAME)
  --end
  TidyPlatesInternal:SetTheme(t.THEME_NAME)

  ThreatPlatesWidgets.ConfigAuraWidgetFilter()
  ThreatPlatesWidgets.ConfigAuraWidget()

  -- Castbars have to be disabled everytime we login
  if TidyPlatesThreat.db.profile.settings.castbar.show or TidyPlatesThreat.db.profile.settings.castbar.ShowInHeadlineView then
    TidyPlatesInternal:EnableCastBars()
  else
    TidyPlatesInternal:DisableCastBars()
  end
end

function TidyPlatesThreat:StartUp()
  local db = self.db.global

  if not self.db.char.welcome then
    self.db.char.welcome = true
    local Welcome = L["|cff89f559Welcome to |r|cff89f559Threat Plates!\nThis is your first time using Threat Plates and you are a(n):\n|r|cff"]..t.HCC[class]..self:SpecName().." "..UnitClass("player").."|r|cff89F559.|r\n"

    -- initialize roles for all available specs (level > 10) or set to default (dps/healing)
    for index=1, GetNumSpecializations() do
      local id, spec_name, description, icon, background, role = GetSpecializationInfo(index)
      self:SetRole(t.SPEC_ROLES[t.Class()][index], index)
    end

    t.Print(Welcome..L["|cff89f559You are currently in your "]..self:RoleText()..L["|cff89f559 role.|r"])
    t.Print(L["|cff89f559Additional options can be found by typing |r'/tptp'|cff89F559.|r"])

    -- With TidyPlates:
    --local current_theme = TidyPlates.GetThemeName()
    --if current_theme == "" then
    --  current_theme, _ = next(TidyPlatesThemeList, nil)
    --end
    --if current_theme ~= t.THEME_NAME then
    --  StaticPopup_Show("SetToThreatPlates")
    --else
    --  if db.version ~= "" and db.version ~= new_version then
    --   local new_version = tostring(t.Meta("version"))
    --    -- migrate and/or remove any old DB entries
    --    t.MigrateDatabase(db.version)
    --  end
    --  db.version = new_version
    --end

    local new_version = tostring(t.Meta("version"))
    if db.version ~= "" and db.version ~= new_version then
      -- migrate and/or remove any old DB entries
      t.MigrateDatabase(db.version)
    end
    db.version = new_version
  else
    local new_version = tostring(t.Meta("version"))
    if db.version ~= "" and db.version ~= new_version then
      -- migrate and/or remove any old DB entries
      t.MigrateDatabase(db.version)
    end
    db.version = new_version

    -- With TidyPlates: if not db.CheckNewLookAndFeel and TidyPlates.GetThemeName() == t.THEME_NAME then
    if not db.CheckNewLookAndFeel then
      StaticPopup_Show("SwitchToNewLookAndFeel")
    end
  end

  -- Check for other active nameplate addons which may create all kinds of errors and doesn't make
  -- sense anyway:
  --if TidyPlates and not db.StandalonePopup then
  if IsAddOnLoaded("TidyPlates") then
    StaticPopup_Show("TidyPlatesEnabled", "TidyPlates")
    --db.StandalonePopup = true
  end
  if IsAddOnLoaded("Kui_Nameplates") then
    StaticPopup_Show("IncompatibleAddon", "KuiNameplates")
    --db.StandalonePopup = true
  end
  if IsAddOnLoaded("ElvUI") then
    StaticPopup_Show("IncompatibleAddon", "ElvUI Nameplates")
    --db.StandalonePopup = true
  end
  if IsAddOnLoaded("Plater") then
    StaticPopup_Show("IncompatibleAddon", "Plater Nameplates")
    --db.StandalonePopup = true
  end

  TidyPlatesThreat:ReloadTheme()
end

---------------------------------------------------------------------------------------------------
-- AceAddon functions: do init tasks here, like loading the Saved Variables, or setting up slash commands.
---------------------------------------------------------------------------------------------------
-- Copied from ElvUI:
function Addon:SetBaseNamePlateSize()
  local db = TidyPlatesThreat.db.profile.settings

  local width = db.frame.width
  local height = db.frame.height
  if db.frame.SyncWithHealthbar then
    -- this wont taint like NamePlateDriverFrame.SetBaseNamePlateSize
    local zeroBasedScale = tonumber(GetCVar("NamePlateVerticalScale")) - 1.0
    local horizontalScale = tonumber(GetCVar("NamePlateHorizontalScale"))

    width = (db.healthbar.width - 10) * horizontalScale
    height = (db.healthbar.height + 35) * Lerp(1.0, 1.25, zeroBasedScale)

    db.frame.width = width
    db.frame.height = height
  end

  if not TidyPlatesThreat.db.profile.ShowFriendlyBlizzardNameplates then
    C_NamePlate_SetNamePlateFriendlySize(width, height)
  end
  C_NamePlate_SetNamePlateEnemySize(width, height)

  Addon:ConfigClickableArea(false)

  --local clampedZeroBasedScale = Saturate(zeroBasedScale)
  --C_NamePlate_SetNamePlateSelfSize(baseWidth * horizontalScale * Lerp(1.1, 1.0, clampedZeroBasedScale), baseHeight)
end

-- The OnInitialize() method of your addon object is called by AceAddon when the addon is first loaded
-- by the game client. It's a good time to do things like restore saved settings (see the info on
-- AceConfig for more notes about that).
function TidyPlatesThreat:OnInitialize()
  local defaults = t.DEFAULT_SETTINGS

  -- change back defaults old settings if wanted preserved it the user want's to switch back
  if ThreatPlatesDB and ThreatPlatesDB.global and ThreatPlatesDB.global.DefaultsVersion == "CLASSIC" then
    -- copy default settings, so that their original values are
    defaults = t.GetDefaultSettingsV1(defaults)
  end

  local db = LibStub('AceDB-3.0'):New('ThreatPlatesDB', defaults, 'Default')
  self.db = db

  local RegisterCallback = db.RegisterCallback
  RegisterCallback(self, 'OnProfileChanged', 'ProfChange')
  RegisterCallback(self, 'OnProfileCopied', 'ProfChange')
  RegisterCallback(self, 'OnProfileReset', 'ProfChange')

  -- Setup Interface panel options
  local app_name = t.ADDON_NAME
  local dialog_name = app_name .. " Dialog"
  LibStub("AceConfig-3.0"):RegisterOptionsTable(dialog_name, t.GetInterfaceOptionsTable())
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions(dialog_name, t.ADDON_NAME)

  -- Setup chat commands
  self:RegisterChatCommand("tptp", "ChatCommand")
end

local function SetCVarHook(name, value, c)
  if name == "NamePlateVerticalScale" then
    local db = TidyPlatesThreat.db.profile.Automation
    local isInstance, instanceType = IsInInstance()

    if not NamePlateDriverFrame:IsUsingLargerNamePlateStyle() then
      if db.OldNameplateGlobalScale then
        -- reset to previous setting when switched of in an instance (called if setting is changed in an instance)
        SetCVar("nameplateGlobalScale", db.OldNameplateGlobalScale)
        db.OldNameplateGlobalScale = nil
      end
    elseif db.SmallPlatesInInstances and isInstance then
      db.OldNameplateGlobalScale = GetCVar("nameplateGlobalScale")
      SetCVar("nameplateGlobalScale", 0.4)
    end
  end
end

-- The OnEnable() and OnDisable() methods of your addon object are called by AceAddon when your addon is
-- enabled/disabled by the user. Unlike OnInitialize(), this may occur multiple times without the entire
-- UI being reloaded.
-- AceAddon function: Do more initialization here, that really enables the use of your addon.
-- Register Events, Hook functions, Create Frames, Get information from the game that wasn't available in OnInitialize
function TidyPlatesThreat:OnEnable()
  TidyPlatesInternalThemeList[t.THEME_NAME] = t.Theme

  self:StartUp()

  Addon:SetBaseNamePlateSize()
  -- Do this after combat ends, not in PLAYER_ENTERING_WORLD as it won't get set if the player is on combat when
  -- that event fires.
  Addon:CallbackWhenOoC(function()
    local db = self.db.profile
    SetNamePlateFriendlyClickThrough(db.NamePlateFriendlyClickThrough)
    SetNamePlateEnemyClickThrough(db.NamePlateEnemyClickThrough)
  end)

  -- Get updates for changes regarding: Large Nameplates
  hooksecurefunc("SetCVar", SetCVarHook)

  -- TODO: check with what this  was replaces
  --TidyPlatesUtilityInternal:EnableGroupWatcher()
  -- TPHUub: if LocalVars.AdvancedEnableUnitCache then TidyPlatesUtilityInternal:EnableUnitCache() else TidyPlatesUtilityInternal:DisableUnitCache() end
  -- TPHUub: TidyPlatesUtilityInternal:EnableHealerTrack()
  -- if TidyPlatesThreat.db.profile.healerTracker.ON then
  -- 	if not healerTrackerEnabled then
  -- 		TidyPlatesUtilityInternal.EnableHealerTrack()
  -- 	end
  -- else
  -- 	if healerTrackerEnabled then
  -- 		TidyPlatesUtilityInternal.DisableHealerTrack()
  -- 	end
  -- end
  -- TidyPlatesWidgets:EnableTankWatch()

  EnableEvents()
end

-- Called when the addon is disabled
function TidyPlatesThreat:OnDisable()
  DisableEvents()
end

function Addon:CallbackWhenOoC(func, msg)
  if InCombatLockdown() then
    if msg then
      t.Print(msg .. L[" The change will be applied after you leave combat."], true)
    end
    task_queue_ooc[#task_queue_ooc + 1] = func
  else
    func()
  end
end

-----------------------------------------------------------------------------------
-- WoW EVENTS --
-----------------------------------------------------------------------------------

--function TidyPlatesThreat:PLAYER_ALIVE()
--end

-- Fired when the player enters the world, reloads the UI, enters/leaves an instance or battleground, or respawns at a graveyard.
-- Also fires any other time the player sees a loading screen
function TidyPlatesThreat:PLAYER_ENTERING_WORLD()
  -- Sync internal settings with Blizzard CVars
  SetCVar("ShowClassColorInNameplate", 1)

  local db = self.db.profile.questWidget
  if db.ON or db.ShowInHeadlineView then
    SetCVar("showQuestTrackingTooltips", 1)
  end

  local db = self.db.profile.Automation
  local isInstance, instanceType = IsInInstance()
  if db.HideFriendlyUnitsInInstances then
    if isInstance then
      if not db.OldNameplateShowFriends then
        db.OldNameplateShowFriends = GetCVar("nameplateShowFriends")
        SetCVar("nameplateShowFriends", 0)
      end
    elseif db.OldNameplateShowFriends then
      -- reset to previous setting
      SetCVar("nameplateShowFriends", db.OldNameplateShowFriends)
      db.OldNameplateShowFriends = nil
    end
  elseif isInstance and db.OldNameplateShowFriends then
    -- reset to previous setting when switched of in an instance (called if setting is changed in an instance)
    SetCVar("nameplateShowFriends", db.OldNameplateShowFriends) -- or GetCVarDefault("nameplateShowFriends"))
    db.OldNameplateShowFriends = nil
  end

  if db.SmallPlatesInInstances and NamePlateDriverFrame:IsUsingLargerNamePlateStyle() then
    if isInstance then
      if not db.OldNameplateGlobalScale then
        db.OldNameplateGlobalScale = GetCVar("nameplateGlobalScale")
        SetCVar("nameplateGlobalScale", 0.4)
        --NamePlateDriverFrame:SetBaseNamePlateSize(168, 112.5)
      end
    elseif db.OldNameplateGlobalScale then
      -- reset to previous setting
      SetCVar("nameplateGlobalScale", db.OldNameplateGlobalScale)
      db.OldNameplateGlobalScale = nil
    end
  elseif db.OldNameplateGlobalScale and isInstance then
    -- reset to previous setting when switched of in an instance (called if setting is changed in an instance)
    SetCVar("nameplateGlobalScale", db.OldNameplateGlobalScale)
    db.OldNameplateGlobalScale = nil
  end

--  if db.SmallPlatesInInstances then
--    if isInstance then
--      db.OldLargerNamePlateStyle = true
--      SetCVar("NamePlateVerticalScale", 1)
--      SetCVar("NamePlateHorizontalScale", 1)
--      NamePlateDriverFrame:UpdateNamePlateOptions()
--    elseif db.OldLargerNamePlateStyle then
--      -- reset to previous setting
--      SetCVar("NamePlateVerticalScale", 2.7)
--      SetCVar("NamePlateHorizontalScale", 1.4)
--      NamePlateDriverFrame:UpdateNamePlateOptions()
--      db.OldLargerNamePlateStyle = nil
--    end
--  elseif db.OldLargerNamePlateStyle and isInstance then
--    -- reset to previous setting when switched of in an instance
--    SetCVar("NamePlateVerticalScale", 2.7)
--    SetCVar("NamePlateHorizontalScale", 1.4)
--    NamePlateDriverFrame:UpdateNamePlateOptions()
--    db.OldLargerNamePlateStyle = nil
--  end
end

--function TidyPlatesThreat:PLAYER_LEAVING_WORLD()
--end

function TidyPlatesThreat:PLAYER_LOGIN(...)
  self.db.profile.cache = {}

  -- With TidyPlates: if self.db.char.welcome and (TidyPlatesOptions.ActiveTheme == t.THEME_NAME) then
  if self.db.char.welcome then
    t.Print(L["|cff89f559Threat Plates:|r Welcome back |cff"]..t.HCC[class]..UnitName("player").."|r!!")
  end
  -- if class == "WARRIOR" or class == "DRUID" or class == "DEATHKNIGHT" or class == "PALADIN" then
  -- 	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
  -- end
end

function TidyPlatesThreat:PLAYER_LOGOUT(...)
  self.db.profile.cache = {}
end

-- Fires when the player leaves combat status
-- Syncs addon settings with game settings in case changes weren't possible during startup, reload
-- or profile reset because character was in combat.
function TidyPlatesThreat:PLAYER_REGEN_ENABLED()
  -- Execute functions which will fail when executed while in combat
  for i = #task_queue_ooc, 1, -1 do -- add -1 so that an empty list does not result in a Lua error
    task_queue_ooc[i]()
    task_queue_ooc[i] = nil
  end

  local db = TidyPlatesThreat.db.profile.threat
  -- Required for threat/aggro detection
  if db.ON and (GetCVar("threatWarning") ~= 3) then
    SetCVar("threatWarning", 3)
  elseif not db.ON and (GetCVar("threatWarning") ~= 0) then
    SetCVar("threatWarning", 0)
  end

  local db = TidyPlatesThreat.db.profile.Automation
  -- Dont't use automation for friendly nameplates if in an instance and Hide Friendly Nameplates is enabled (db.OldNameplateShowFriends ~= nil)
  if db.FriendlyUnits ~= "NONE" and not db.OldNameplateShowFriends then
    SetCVar("nameplateShowFriends", (db.FriendlyUnits == "SHOW_COMBAT" and 0) or 1)
  end
  if db.EnemyUnits ~= "NONE" then
    SetCVar("nameplateShowEnemies", (db.EnemyUnits == "SHOW_COMBAT" and 0) or 1)
  end
end

-- Fires when the player enters combat status
function TidyPlatesThreat:PLAYER_REGEN_DISABLED()
  local db = self.db.profile.Automation
  -- Dont't use automation for friendly nameplates if in an instance and Hide Friendly Nameplates is enabled (db.OldNameplateShowFriends ~= nil)
  if db.FriendlyUnits ~= "NONE" and not db.OldNameplateShowFriends then
    SetCVar("nameplateShowFriends", (db.FriendlyUnits == "SHOW_COMBAT" and 1) or 0)
  end  if db.EnemyUnits ~= "NONE" then
    SetCVar("nameplateShowEnemies", (db.EnemyUnits == "SHOW_COMBAT" and 1) or 0)
  end
end

-- Disabled events PLAYER_TALENT_UPDATE, UPDATE_SHAPESHIFT_FORM, ACTIVE_TALENT_GROUP_CHANGED
-- as they are not used currently

-- With TidyPlates:
-- nameplate color can change when factions change (e.g., with disguises)
-- Legion example: Suramar city and Masquerade
--function TidyPlatesThreat:UNIT_FACTION(event, unitid)
--  TidyPlates:ForceUpdate()
--end

-- QuestWidget needs to update all nameplates when a quest was completed
function TidyPlatesThreat:QUEST_WATCH_UPDATE(event, quest_index)
  if TidyPlatesThreat.db.profile.questWidget.ON then
    TidyPlatesInternal:ForceUpdate()
  end
end
function TidyPlatesThreat:QUEST_ACCEPTED(event, quest_index, _)
  if TidyPlatesThreat.db.profile.questWidget.ON then
    TidyPlatesInternal:ForceUpdate()
  end
end

-- function TidyPlatesThreat:PLAYER_TALENT_UPDATE()
-- 	--
-- end

-- function TidyPlatesThreat:UPDATE_SHAPESHIFT_FORM()
-- end

-- Fires when the player switches to another specialication or everytime the player changes a talent
-- Completely handled by TidyPlates
-- function TidyPlatesThreat:ACTIVE_TALENT_GROUP_CHANGED()
-- With TidyPlates:	if (TidyPlatesOptions.ActiveTheme == t.THEME_NAME) and self.db.profile.verbose then
-- if self.db.profile.verbose then
-- 		t.Print(L"|cff89F559Threat Plates|r: Player spec change detected: |cff"]..t.HCC[class]..self:SpecName()..L"|r, you are now in your "]..self:RoleText()..L[" role."])
-- 	end
-- end

function TidyPlatesThreat:UNIT_ABSORB_AMOUNT_CHANGED(event, unitid)
  local plate = GetNamePlateForUnit(unitid)

  -- With TidyPlates:
  --if plate and plate.extended then
  --  t.UpdateExtensions(plate.extended, unitid)
  --end
  if plate and plate.TPFrame then
    t.UpdateExtensions(plate.TPFrame, unitid)
  end
end

function TidyPlatesThreat:UNIT_MAXHEALTH(event, unitid)
  local plate = GetNamePlateForUnit(unitid)

  -- With TidyPlates:
  --if plate and plate.extended then
  --  t.UpdateExtensions(plate.extended, unitid)
  --end
  if plate and plate.TPFrame then
    t.UpdateExtensions(plate.TPFrame, unitid)
  end
end