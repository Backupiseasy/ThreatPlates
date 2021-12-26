---------------------------------------------------------------------------------------------------
-- Main file for addon Threat Plates
---------------------------------------------------------------------------------------------------
local _, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local tonumber, select, pairs = tonumber, select, pairs

-- WoW APIs
local SetNamePlateFriendlyClickThrough = C_NamePlate.SetNamePlateFriendlyClickThrough
local SetNamePlateEnemyClickThrough = C_NamePlate.SetNamePlateEnemyClickThrough
local IsInInstance = IsInInstance
local GetCVar, IsAddOnLoaded = GetCVar, IsAddOnLoaded
local GetNamePlates = C_NamePlate.GetNamePlates
local C_NamePlate, Lerp =  C_NamePlate, Lerp
local C_Timer_After = C_Timer.After
local NamePlateDriverFrame = NamePlateDriverFrame
local UnitClass, GetNumSpecializations, GetSpecializationInfo = UnitClass, GetNumSpecializations, GetSpecializationInfo

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local LibStub = LibStub
local L = Addon.L
local LSM = Addon.LSM
local Meta = Addon.Meta

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS:

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
local LSMUpdateTimer
---------------------------------------------------------------------------------------------------
-- Global configs and funtions
---------------------------------------------------------------------------------------------------

Addon.PlayerClass = select(2, UnitClass("player"))

ThreatPlates.Print = function(val,override)
  local db = TidyPlatesThreat.db.profile
  if override or db.verbose then
    print(Meta("titleshort")..": "..val)
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
  text = "|cffFFA500" .. Meta("title") .. " Warning|r \n---------------------------------------\n" ..
    L["|cff89F559Threat Plates|r is no longer a theme of |cff89F559TidyPlates|r, but a standalone addon that does no longer require TidyPlates. Please disable one of these, otherwise two overlapping nameplates will be shown for units."],
  button1 = OKAY,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  OnAccept = function(self, _, _) end,
}

StaticPopupDialogs["IncompatibleAddon"] = {
  preferredIndex = STATICPOPUP_NUMDIALOGS,
  text = "|cffFFA500" .. Meta("title") .. " Warning|r \n---------------------------------------\n" ..
    L["You currently have two nameplate addons enabled: |cff89F559Threat Plates|r and |cff89F559%s|r. Please disable one of these, otherwise two overlapping nameplates will be shown for units."],
  button1 = OKAY,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  OnAccept = function(self, _, _) end,
}

function TidyPlatesThreat:ReloadTheme()
  -- Recreate all TidyPlates styles for ThreatPlates("normal", "dps", "tank", ...) - required, if theme style settings were changed
  Addon:SetThemes(self)

  -- Re-read all cached settings, ideally do not update any UI elements here
  Addon:InitializeCustomNameplates()
  Addon:UpdateSettings()
  Addon.Widgets:InitializeAllWidgets() -- UpdateSettings and enable widgets

  -- Update existing nameplates as certain settings may have changed that are not covered by ForceUpdate()
  Addon:UIScaleChanged()

  -- Do this after combat ends, not in PLAYER_ENTERING_WORLD as it won't get set if the player is on combat when
  -- that event fires.
  Addon:CallbackWhenOoC(function() Addon:SetBaseNamePlateSize() end, L["Unable to change a setting while in combat."])
  Addon:CallbackWhenOoC(function()
    local db = self.db.profile
    SetNamePlateFriendlyClickThrough(db.NamePlateFriendlyClickThrough)
    SetNamePlateEnemyClickThrough(db.NamePlateEnemyClickThrough)
  end)

  -- CVars setup for nameplates of occluded units
  if TidyPlatesThreat.db.profile.nameplate.toggle.OccludedUnits then
    Addon:CallbackWhenOoC(function()
      Addon:SetCVarsForOcclusionDetection()
    end)
  end

  Addon.CVars:OverwriteBoolProtected("nameplateResourceOnTarget", self.db.profile.PersonalNameplate.ShowResourceOnTarget)

  local frame
  for _, plate in pairs(GetNamePlates()) do
    frame = plate and plate.TPFrame
    if frame and frame.Active then
      Addon:UpdateNameplateStyle(plate, frame.unit.unitid)
    end
  end

  -- Update all UI elements (frames, textures, ...)
  Addon:UpdateAllPlates()
end

function TidyPlatesThreat:CheckForFirstStartUp()
  local db = self.db.global

  if not Addon.CLASSIC then
    local spec_roles = self.db.char.spec
    if #spec_roles ~= GetNumSpecializations() then
      for i = 1, GetNumSpecializations() do
        if spec_roles[i] == nil then
          local _, _, _, _, role = GetSpecializationInfo(i)
          spec_roles[i] = (role == "TANK" and true) or false
        end
      end
    end
  end

  local new_version = tostring(Meta("version"))
  if db.version ~= "" and db.version ~= new_version then
    -- migrate and/or remove any old DB entries
    Addon.MigrateDatabase(db.version)
  end
  db.version = new_version
end

function TidyPlatesThreat:CheckForIncompatibleAddons()
  -- Check for other active nameplate addons which may create all kinds of errors and doesn't make
  -- sense anyway:
  if IsAddOnLoaded("TidyPlates") then
    StaticPopup_Show("TidyPlatesEnabled", "TidyPlates")
  end
  if IsAddOnLoaded("Kui_Nameplates") then
    StaticPopup_Show("IncompatibleAddon", "KuiNameplates")
  end
  if IsAddOnLoaded("ElvUI") and ElvUI[1].private.nameplates.enable then
    StaticPopup_Show("IncompatibleAddon", "ElvUI Nameplates")
  end
  if IsAddOnLoaded("Plater") then
    StaticPopup_Show("IncompatibleAddon", "Plater Nameplates")
  end
  if IsAddOnLoaded("SpartanUI") and SUI.DB.EnabledComponents.Nameplates then
    StaticPopup_Show("IncompatibleAddon", "SpartanUI Nameplates")
  end
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
    -- this wont taint like NamePlateDriverFrame:SetBaseNamePlateSize

    -- The default size of Threat Plates healthbars is based on large nameplates with these defaults:
    --   NamePlateVerticalScale = 1.7
    --   NamePlateVerticalScale = 1.4
    local zeroBasedScale = 0.7  -- tonumber(GetCVar("NamePlateVerticalScale")) - 1.0
    local horizontalScale = 1.4 -- tonumber(GetCVar("NamePlateVerticalScale"))

    width = (db.healthbar.width - 10) * horizontalScale
    height = (db.healthbar.height + 35) * Lerp(1.0, 1.25, zeroBasedScale)

    db.frame.width = width
    db.frame.height = height
  end

  -- Set to default values if Blizzard nameplates are enabled or in an instance (for friendly players)
  local isInstance, instanceType = IsInInstance()
  isInstance = isInstance and (instanceType == "party" or instanceType == "raid")

  db = TidyPlatesThreat.db.profile
  if Addon.CLASSIC then
    -- Classic has the same nameplate size for friendly and enemy units, so either set both or non at all (= set it to default values)
    if not db.ShowFriendlyBlizzardNameplates and not db.ShowEnemyBlizzardNameplates and not isInstance then
      C_NamePlate.SetNamePlateFriendlySize(width, height)
      C_NamePlate.SetNamePlateEnemySize(width, height)
    else
      -- Smaller nameplates are not available in Classic
      C_NamePlate.SetNamePlateFriendlySize(128, 32)
      C_NamePlate.SetNamePlateEnemySize(128, 32)
    end
  else
    if db.ShowFriendlyBlizzardNameplates or isInstance then
      if NamePlateDriverFrame:IsUsingLargerNamePlateStyle() then
        C_NamePlate.SetNamePlateFriendlySize(154, 64)
      else
        C_NamePlate.SetNamePlateFriendlySize(110, 45)
      end
    else
      C_NamePlate.SetNamePlateFriendlySize(width, height)
    end

    if db.ShowEnemyBlizzardNameplates then
      if NamePlateDriverFrame:IsUsingLargerNamePlateStyle() then
        C_NamePlate.SetNamePlateEnemySize(154, 64)
      else
        C_NamePlate.SetNamePlateEnemySize(110, 45)
      end
    else
      C_NamePlate.SetNamePlateEnemySize(width, height)
    end
  end

  Addon:ConfigClickableArea(false)

  -- For personal nameplate:
  --local clampedZeroBasedScale = Saturate(zeroBasedScale)
  --C_NamePlate_SetNamePlateSelfSize(baseWidth * horizontalScale * Lerp(1.1, 1.0, clampedZeroBasedScale), baseHeight)
end

-- The OnInitialize() method of your addon object is called by AceAddon when the addon is first loaded
-- by the game client. It's a good time to do things like restore saved settings (see the info on
-- AceConfig for more notes about that).
function TidyPlatesThreat:OnInitialize()
  local defaults = ThreatPlates.DEFAULT_SETTINGS

  -- change back defaults old settings if wanted preserved it the user want's to switch back
  if ThreatPlatesDB and ThreatPlatesDB.global and ThreatPlatesDB.global.DefaultsVersion == "CLASSIC" then
    -- copy default settings, so that their original values are
    defaults = ThreatPlates.GetDefaultSettingsV1(defaults)
  end

  local db = LibStub('AceDB-3.0'):New('ThreatPlatesDB', defaults, 'Default')
  self.db = db

  -- Change defaults if deprecated custom nameplates are used (not yet migrated)
  Addon.SetDefaultsForCustomNameplates()

  local RegisterCallback = db.RegisterCallback
  RegisterCallback(self, 'OnProfileChanged', 'ProfChange')
  RegisterCallback(self, 'OnProfileCopied', 'ProfChange')
  RegisterCallback(self, 'OnProfileReset', 'ProfChange')

  -- Setup Interface panel options
  local app_name = ThreatPlates.ADDON_NAME
  local dialog_name = app_name .. " Dialog"
  LibStub("AceConfig-3.0"):RegisterOptionsTable(dialog_name, ThreatPlates.GetInterfaceOptionsTable())
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions(dialog_name, ThreatPlates.ADDON_NAME)

  -- Setup chat commands
  self:RegisterChatCommand("tptp", "ChatCommand")

  if Addon.CLASSIC then
    local LibClassicCasterino = Addon.LibClassicCasterino

    -- Register callsbacks for spellcasting library
    LibClassicCasterino.RegisterCallback(self,"UNIT_SPELLCAST_START", Addon.UNIT_SPELLCAST_START)
    LibClassicCasterino.RegisterCallback(self,"UNIT_SPELLCAST_DELAYED", Addon.UnitSpellcastMidway) -- only for player
    LibClassicCasterino.RegisterCallback(self,"UNIT_SPELLCAST_STOP", Addon.UNIT_SPELLCAST_STOP)
    LibClassicCasterino.RegisterCallback(self,"UNIT_SPELLCAST_FAILED", Addon.UNIT_SPELLCAST_STOP)
    LibClassicCasterino.RegisterCallback(self,"UNIT_SPELLCAST_INTERRUPTED", Addon.UNIT_SPELLCAST_INTERRUPTED)
    LibClassicCasterino.RegisterCallback(self,"UNIT_SPELLCAST_CHANNEL_START", Addon.UNIT_SPELLCAST_CHANNEL_START)
    LibClassicCasterino.RegisterCallback(self,"UNIT_SPELLCAST_CHANNEL_UPDATE", Addon.UnitSpellcastMidway) -- only for player
    LibClassicCasterino.RegisterCallback(self,"UNIT_SPELLCAST_CHANNEL_STOP", Addon.UNIT_SPELLCAST_CHANNEL_STOP)
  end
end

local function SetCVarHook(name, value, c)
  -- Used as detection for switching between small and large nameplates
  if name == "NamePlateVerticalScale" then
    local db = TidyPlatesThreat.db.profile.Automation
    local isInstance, instanceType = IsInInstance()

    if not NamePlateDriverFrame:IsUsingLargerNamePlateStyle() then
      -- reset to previous setting
      Addon.CVars:RestoreFromProfile("nameplateGlobalScale")
    elseif db.SmallPlatesInInstances and isInstance then
      Addon.CVars:Set("nameplateGlobalScale", 0.4)
    end

    Addon:CallbackWhenOoC(function() Addon:SetBaseNamePlateSize() end)
  end
end

-- The OnEnable() and OnDisable() methods of your addon object are called by AceAddon when your addon is
-- enabled/disabled by the user. Unlike OnInitialize(), this may occur multiple times without the entire
-- UI being reloaded.
-- AceAddon function: Do more initialization here, that really enables the use of your addon.
-- Register Events, Hook functions, Create Frames, Get information from the game that wasn't available in OnInitialize
function TidyPlatesThreat:OnEnable()
  TidyPlatesThreat:CheckForFirstStartUp()
  TidyPlatesThreat:CheckForIncompatibleAddons()

  if not Addon.CLASSIC then
    Addon.CVars:OverwriteBoolProtected("nameplateResourceOnTarget", self.db.profile.PersonalNameplate.ShowResourceOnTarget)
  end
  TidyPlatesThreat:ReloadTheme()

  -- Register callbacks at LSM, so that we can refresh everything if additional media is added after TP is loaded
  -- Register this callback after ReloadTheme as media will be updated there anyway
  LSM.RegisterCallback(self, "LibSharedMedia_SetGlobal", "MediaUpdate" )
  LSM.RegisterCallback(self, "LibSharedMedia_Registered", "MediaUpdate" )
  -- Get updates for changes regarding: Large Nameplates
  hooksecurefunc("SetCVar", SetCVarHook)

  Addon:EnableEvents()
end

-- Called when the addon is disabled
function TidyPlatesThreat:OnDisable()
  -- DisableEvents()

  -- Reset all CVars to its initial values
  -- Addon.CVars:RestoreAllFromProfile()
end

-- Register callbacks at LSM, so that we can refresh everything if additional media is added after TP is loaded
function TidyPlatesThreat.MediaUpdate(addon_name, name, mediatype, key)
  if mediatype ~= LSM.MediaType.SOUND and not LSMUpdateTimer then
    LSMUpdateTimer = true

    -- Delay the update for one second to avoid firering this several times when multiple media are registered by another addon
    C_Timer_After(1, function()
      LSMUpdateTimer = nil
      -- Basically, ReloadTheme but without CVar and some other stuff
      Addon:SetThemes(TidyPlatesThreat)
      -- no media used: Addon:UpdateConfigurationStatusText()
      -- no media used: Addon:InitializeCustomNameplates()
      Addon.Widgets:InitializeAllWidgets()
      Addon:ForceUpdate()
    end)
  end
end

-----------------------------------------------------------------------------------
-- Functions for keybindings
-----------------------------------------------------------------------------------

function TidyPlatesThreat:ToggleNameplateModeFriendlyUnits()
  local db = TidyPlatesThreat.db.profile

  db.Visibility.FriendlyPlayer.UseHeadlineView = not db.Visibility.FriendlyPlayer.UseHeadlineView
  db.Visibility.FriendlyNPC.UseHeadlineView = not db.Visibility.FriendlyNPC.UseHeadlineView
  db.Visibility.FriendlyTotem.UseHeadlineView = not db.Visibility.FriendlyTotem.UseHeadlineView
  db.Visibility.FriendlyGuardian.UseHeadlineView = not db.Visibility.FriendlyGuardian.UseHeadlineView
  db.Visibility.FriendlyPet.UseHeadlineView = not db.Visibility.FriendlyPet.UseHeadlineView
  db.Visibility.FriendlyMinus.UseHeadlineView = not db.Visibility.FriendlyMinus.UseHeadlineView

  Addon:ForceUpdate()
end

function TidyPlatesThreat:ToggleNameplateModeNeutralUnits()
  local db = TidyPlatesThreat.db.profile

  db.Visibility.NeutralNPC.UseHeadlineView = not db.Visibility.NeutralNPC.UseHeadlineView
  db.Visibility.NeutralMinus.UseHeadlineView = not db.Visibility.NeutralMinus.UseHeadlineView

  Addon:ForceUpdate()
end

function TidyPlatesThreat:ToggleNameplateModeEnemyUnits()
  local db = TidyPlatesThreat.db.profile

  db.Visibility.EnemyPlayer.UseHeadlineView = not db.Visibility.EnemyPlayer.UseHeadlineView
  db.Visibility.EnemyNPC.UseHeadlineView = not db.Visibility.EnemyNPC.UseHeadlineView
  db.Visibility.EnemyTotem.UseHeadlineView = not db.Visibility.EnemyTotem.UseHeadlineView
  db.Visibility.EnemyGuardian.UseHeadlineView = not db.Visibility.EnemyGuardian.UseHeadlineView
  db.Visibility.EnemyPet.UseHeadlineView = not db.Visibility.EnemyPet.UseHeadlineView
  db.Visibility.EnemyMinus.UseHeadlineView = not db.Visibility.EnemyMinus.UseHeadlineView

  Addon:ForceUpdate()
end