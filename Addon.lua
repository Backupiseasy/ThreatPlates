---------------------------------------------------------------------------------------------------
-- Main file for addon Threat Plates
---------------------------------------------------------------------------------------------------
local _, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local tonumber, select, pairs = tonumber, select, pairs

-- WoW APIs
local SetNamePlateFriendlyClickThrough = C_NamePlate.SetNamePlateFriendlyClickThrough
local SetNamePlateEnemyClickThrough = C_NamePlate.SetNamePlateEnemyClickThrough
local GetCVar, IsAddOnLoaded = GetCVar, C_AddOns.IsAddOnLoaded
local C_NamePlate, Lerp =  C_NamePlate, Lerp
local C_Timer_After = C_Timer.After
local NamePlateDriverFrame = NamePlateDriverFrame
local UnitClass = UnitClass
local GetSpecializationInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or _G.GetSpecializationInfo

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local LibStub = LibStub
local L = Addon.L
local Meta = Addon.Meta
local CVars = Addon.CVars

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
Addon.PlayerName = select(1, UnitName("player"))
Addon.PlayerIsInCombat = false
-- Addon.PlayerRole -- accessed via function Addon.GetPlayerRole()

---------------------------------------------------------------------------------------------------
-- Functions different depending on WoW version
---------------------------------------------------------------------------------------------------

if Addon.WOW_USES_CLASSIC_NAMEPLATES then
  local function CalculateSynchedNameplateSize()
    local db = Addon.db.profile.settings
  
    local width = db.healthbar.width
    local height = db.healthbar.height
    if db.frame.SyncWithHealthbar then
      width = width + 6
      height = height + 22
    end

    -- Update values in settings, so that the options dialog (clickable area) shows the correct values
    db.frame.width = width
    db.frame.height = height
  
    return width, height
  end

  Addon.SetBaseNamePlateSize = function(self)
    local db = self.db.profile

    -- Classic has the same nameplate size for friendly and enemy units, so either set both or non at all (= set it to default values)
    if not db.ShowFriendlyBlizzardNameplates and not db.ShowEnemyBlizzardNameplates and not self.IsInPvEInstance then
      local width, height = CalculateSynchedNameplateSize()
      C_NamePlate.SetNamePlateFriendlySize(width, height)
      C_NamePlate.SetNamePlateEnemySize(width, height)
    else
      -- Smaller nameplates are not available in Classic
      C_NamePlate.SetNamePlateFriendlySize(128, 32)
      C_NamePlate.SetNamePlateEnemySize(128, 32)
    end

    Addon:ConfigClickableArea(false)
  end
elseif not Addon.ExpansionIsAtLeastMidnight then
  local function CalculateSynchedNameplateSize(width_key, height_key)
    local width, height
    
    local db = Addon.db.profile.settings
    if db.frame.SyncWithHealthbar then
      -- This functions were interpolated from ratio of the clickable area and the Blizzard nameplate healthbar
      -- for various sizes
      width = db.healthbar[width_key] + 24.5
      height = (db.healthbar[height_key] + 11.4507) / 0.347764  
    else
      width = db.frame[width_key]
      height = db.frame[height_key]
    end
  
    -- Update values in settings, so that the options dialog (clickable area) shows the correct values
    db.frame[width_key] = width
    db.frame[height_key] = height

    return width, height
  end

  local function CalculateSynchedNameplateSizeForEnemy()
    return CalculateSynchedNameplateSize("width", "height")
  end

  local function CalculateSynchedNameplateSizeForFriend()
    return CalculateSynchedNameplateSize("widthFriend", "heightFriend")
  end

  local function SetNameplatesToDefaultSize(nameplate_size_func)
    if NamePlateDriverFrame:IsUsingLargerNamePlateStyle() then
      nameplate_size_func(154, 64)
    else
      nameplate_size_func(110, 45)
    end
  end

  Addon.SetBaseNamePlateSize = function(self)
    local db = self.db.profile

    if db.ShowFriendlyBlizzardNameplates or self.IsInPvEInstance then
      if CVars:GetAsBool("nameplateShowOnlyNames") then
        -- The clickable area of friendly nameplates will be set to zero so that they don't interfere with enemy nameplates stacking (not in Classic or TBC Classic).
        C_NamePlate.SetNamePlateFriendlySize(0.1, 0.1)    
      else
        SetNameplatesToDefaultSize(C_NamePlate.SetNamePlateFriendlySize)
      end
    else
      local width, height = CalculateSynchedNameplateSizeForFriend()
      C_NamePlate.SetNamePlateFriendlySize(width, height)
    end

    if db.ShowEnemyBlizzardNameplates then
      SetNameplatesToDefaultSize(C_NamePlate.SetNamePlateEnemySize)
    else
      local width, height = CalculateSynchedNameplateSizeForEnemy()
      C_NamePlate.SetNamePlateEnemySize(width, height)
    end
    
    Addon:ConfigClickableArea(false)
  
    -- For personal nameplate:
    --local clampedZeroBasedScale = Saturate(zeroBasedScale)
    --C_NamePlate_SetNamePlateSelfSize(baseWidth * horizontalScale * Lerp(1.1, 1.0, clampedZeroBasedScale), baseHeight)
  end
else
  Addon.SetBaseNamePlateSize = function(self, plate) 
    local db = Addon.db.profile.settings.healthbar
    --C_NamePlate.SetNamePlateSize(db.width + 40, db.height + 40)
    C_NamePlate.SetNamePlateSize(db.width, db.height)
    
    C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Enemy, -10000, -10000, -10000, -10000)
    C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Friendly, -10000, -10000, -10000, -10000)
  end
end

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
  button2 = L["Don't Ask Again"],
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  OnAccept = function(self, _, _) end,
  OnCancel = function(self, _, _)
    Addon.db.profile.CheckForIncompatibleAddons = false
  end,
}


function Addon:ReloadTheme()
  -- Recreate all TidyPlates styles for ThreatPlates("normal", "dps", "tank", ...) - required, if theme style settings were changed
  Addon:SetThemes()

  -- Re-read all cached settings, ideally do not update any UI elements here
  Addon:InitializeCustomNameplates()
  Addon:InitializeIconTextures()
  Addon:UpdateSettings()
  Addon.Widgets:InitializeAllWidgets() -- UpdateSettings and enable widgets

  -- Update existing nameplates as certain settings may have changed that are not covered by ForceUpdate()
  Addon:UIScaleChanged()

  -- Do this after combat ends, not in PLAYER_ENTERING_WORLD as it won't get set if the player is on combat when
  -- that event fires.
  if not Addon.ExpansionIsAtLeastMidnight then
    Addon:CallbackWhenOoC(function() Addon:SetBaseNamePlateSize() end, L["Unable to change a setting while in combat."])
    Addon:CallbackWhenOoC(function()
      local db = self.db.profile
      SetNamePlateFriendlyClickThrough(db.NamePlateFriendlyClickThrough)
      SetNamePlateEnemyClickThrough(db.NamePlateEnemyClickThrough)
    end)
  end
  
  -- Update all UI elements (frames, textures, ...)
  Addon:UpdateAllPlates()
end

function Addon:CheckForFirstStartUp()
  local db = self.db.global

  -- GetNumSpecializations: Mists - Patch 5.0.4 (2012-08-28): Replaced GetNumTalentTabs.
  if Addon.ExpansionIsAtLeastMists then
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

  --Addon.MigrateDatabase(db.version)
end

function Addon:CheckForIncompatibleAddons()
  -- Check for other active nameplate addons which may create all kinds of errors and doesn't make
  -- sense anyway:
  if Addon.db.profile.CheckForIncompatibleAddons then
    if IsAddOnLoaded("TidyPlates") then
      StaticPopup_Show("TidyPlatesEnabled", "TidyPlates")
    end
    if IsAddOnLoaded("Kui_Nameplates") then
      StaticPopup_Show("IncompatibleAddon", "KuiNameplates")
    end
    if IsAddOnLoaded("ElvUI") and ElvUI[1] and ElvUI[1].private and ElvUI[1].private.nameplates and ElvUI[1].private.nameplates.enable then
    --if IsAddOnLoaded("ElvUI") and ElvUI[1].private.nameplates.enable then
      StaticPopup_Show("IncompatibleAddon", "ElvUI Nameplates")
    end
    if IsAddOnLoaded("Plater") then
      StaticPopup_Show("IncompatibleAddon", "Plater Nameplates")
    end
    if IsAddOnLoaded("SpartanUI") and SUI.IsModuleEnabled and SUI:IsModuleEnabled("Nameplates") then
      StaticPopup_Show("IncompatibleAddon", "SpartanUI Nameplates")
    end
  end
end

---------------------------------------------------------------------------------------------------
-- AceAddon functions: do init tasks here, like loading the Saved Variables, or setting up slash commands.
---------------------------------------------------------------------------------------------------

-- Register callbacks at LSM, so that we can refresh everything if additional media is added after TP is loaded
function Addon.MediaUpdate(addon_name, name, mediatype, key)
  if mediatype ~= Addon.LibSharedMedia.MediaType.SOUND and not LSMUpdateTimer then
    LSMUpdateTimer = true

    -- Delay the update for one second to avoid firering this several times when multiple media are registered by another addon
    C_Timer_After(1, function()
      LSMUpdateTimer = nil
      -- Basically, ReloadTheme but without CVar and some other stuff
      Addon:SetThemes()
      -- no media used: Addon:UpdateConfigurationStatusText()
      -- no media used: Addon:InitializeCustomNameplates()
      Addon.Widgets:InitializeAllWidgets()
      Addon:ForceUpdate()
    end)
  end
end

function Addon.LoadLibraryDogTag()
	local db = Addon.db.profile.StatusText

	-- Enable or disable LibDogTagSupport based on custom status text being actually used
	if db.HealthbarMode.FriendlySubtext == "CUSTOM" or db.HealthbarMode.EnemySubtext == "CUSTOM" or db.NameMode.FriendlySubtext == "CUSTOM" or db.NameMode.EnemySubtext == "CUSTOM" then
		if Addon.LibDogTag == nil then
			LoadAddOn("LibDogTag-3.0")
			Addon.LibDogTag = LibStub("LibDogTag-3.0", true)
			if not Addon.LibDogTag then
				Addon.LibDogTag = false
				Addon.Logging.Error(L["Custom status text requires LibDogTag-3.0 to function."])
			else
				LoadAddOn("LibDogTag-Unit-3.0")
			  if not LibStub("LibDogTag-Unit-3.0", true) then
					Addon.LibDogTag = false
					Addon.Logging.Error(L["Custom status text requires LibDogTag-Unit-3.0 to function."])
				elseif not Addon.LibDogTag.IsLegitimateUnit or not Addon.LibDogTag.IsLegitimateUnit["nameplate1"] then
					Addon.LibDogTag = false
					Addon.Logging.Error(L["Your version of LibDogTag-Unit-3.0 does not support nameplates. You need to install at least v90000.3 of LibDogTag-Unit-3.0."])
				end
			end
		end
	end
end

function Addon.LoadLibraryMasque()
  local masque, masque_version = LibStub("Masque", true)
  if masque then
    Addon.LibMasque = masque
  end
end

-- The OnInitialize() method of your addon object is called by AceAddon when the addon is first loaded
-- by the game client. It's a good time to do things like restore saved settings (see the info on
-- AceConfig for more notes about that).
function TidyPlatesThreat:OnInitialize()
  local defaults = Addon.DEFAULT_SETTINGS

  -- change back defaults old settings if wanted preserved it the user want's to switch back
  if ThreatPlatesDB and ThreatPlatesDB.global and ThreatPlatesDB.global.DefaultsVersion == "CLASSIC" then
    -- copy default settings, so that their original values are
    defaults = Addon.GetDefaultSettingsV1(defaults)
  end

  local db = LibStub('AceDB-3.0'):New('ThreatPlatesDB', defaults, 'Default')
  Addon.db = db

  Addon.LibAceConfigDialog = LibStub("AceConfigDialog-3.0")
  Addon.LibAceConfigRegistry = LibStub("AceConfigRegistry-3.0")
  Addon.LibSharedMedia = LibStub("LibSharedMedia-3.0")
  Addon.LibCustomGlow = LibStub("LibCustomGlow-1.0")

  Addon.LoadLibraryMasque() -- Masque support
  Addon.LoadLibraryDogTag() -- LibDogTag support

  local RegisterCallback = db.RegisterCallback
  RegisterCallback(Addon, 'OnProfileChanged', 'ProfChange')
  RegisterCallback(Addon, 'OnProfileCopied', 'ProfChange')
  RegisterCallback(Addon, 'OnProfileReset', 'ProfChange')

  -- Register callbacks at LSM, so that we can refresh everything if additional media is added after TP is loaded
  -- Register this callback after ReloadTheme as media will be updated there anyway
  Addon.LibSharedMedia.RegisterCallback(Addon, "LibSharedMedia_SetGlobal", "MediaUpdate" )
  Addon.LibSharedMedia.RegisterCallback(Addon, "LibSharedMedia_Registered", "MediaUpdate" )
  
  -- Setup Interface panel options
  local app_name = Addon.ADDON_NAME
  local dialog_name = app_name .. " Dialog"
  LibStub("AceConfig-3.0"):RegisterOptionsTable(dialog_name, Addon.GetInterfaceOptionsTable())
  Addon.LibAceConfigDialog:AddToBlizOptions(dialog_name, Addon.ADDON_NAME)

  -- Setup chat commands
  self:RegisterChatCommand("tptp", "ChatCommand")

  Addon.CVars:Initialize()
  Addon:CheckForFirstStartUp()
  Addon:CheckForIncompatibleAddons()

  -- Registering events here as otherwise PLAYER_LOGIN is not received
  Addon:EnableEvents()

  if not Addon.WOW_USES_CLASSIC_NAMEPLATES then
    CVars:OverwriteBool("nameplateResourceOnTarget", Addon.db.profile.PersonalNameplate.ShowResourceOnTarget)
  end

  -- Get updates for CVar changes (e.g, for large nameplates, nameplage scale and alpha)
  CVars.RegisterCVarHook()

  Addon:ReloadTheme()
end

-- The OnEnable() and OnDisable() methods of your addon object are called by AceAddon when your addon is
-- enabled/disabled by the user. Unlike OnInitialize(), this may occur multiple times without the entire
-- UI being reloaded.
-- AceAddon function: Do more initialization here, that really enables the use of your addon.
-- Register Events, Hook functions, Create Frames, Get information from the game that wasn't available in OnInitialize
-- function TidyPlatesThreat:OnEnable()
--   --Addon:EnableEvents()
-- end

-- Called when the addon is disabled
-- function TidyPlatesThreat:OnDisable()
--   -- Reset all CVars to its initial values
--   -- CVars:RestoreAllFromProfile()
  
--   -- DisableEvents()
-- end

-----------------------------------------------------------------------------------
-- Functions for keybindings and addon compartment
-----------------------------------------------------------------------------------

function TidyPlatesThreat:ToggleNameplateModeFriendlyUnits()
  local db = Addon.db.profile

  db.Visibility.FriendlyPlayer.UseHeadlineView = not db.Visibility.FriendlyPlayer.UseHeadlineView
  db.Visibility.FriendlyNPC.UseHeadlineView = not db.Visibility.FriendlyNPC.UseHeadlineView
  -- db.Visibility.FriendlyMinion.UseHeadlineView = not db.Visibility.FriendlyTotem.UseHeadlineView
  db.Visibility.FriendlyPet.UseHeadlineView = not db.Visibility.FriendlyPet.UseHeadlineView
  db.Visibility.FriendlyGuardian.UseHeadlineView = not db.Visibility.FriendlyGuardian.UseHeadlineView
  db.Visibility.FriendlyTotem.UseHeadlineView = not db.Visibility.FriendlyTotem.UseHeadlineView
  db.Visibility.FriendlyMinus.UseHeadlineView = not db.Visibility.FriendlyMinus.UseHeadlineView

  Addon:ForceUpdate()
end

function TidyPlatesThreat:ToggleNameplateModeNeutralUnits()
  local db = Addon.db.profile

  db.Visibility.NeutralNPC.UseHeadlineView = not db.Visibility.NeutralNPC.UseHeadlineView
  db.Visibility.NeutralMinus.UseHeadlineView = not db.Visibility.NeutralMinus.UseHeadlineView

  Addon:ForceUpdate()
end

function TidyPlatesThreat:ToggleNameplateModeEnemyUnits()
  local db = Addon.db.profile

  db.Visibility.EnemyPlayer.UseHeadlineView = not db.Visibility.EnemyPlayer.UseHeadlineView
  db.Visibility.EnemyNPC.UseHeadlineView = not db.Visibility.EnemyNPC.UseHeadlineView
  -- db.Visibility.EnemyMinion.UseHeadlineView = not db.Visibility.EnemyPet.UseHeadlineView
  db.Visibility.EnemyPet.UseHeadlineView = not db.Visibility.EnemyPet.UseHeadlineView
  db.Visibility.EnemyGuardian.UseHeadlineView = not db.Visibility.EnemyGuardian.UseHeadlineView
  db.Visibility.EnemyTotem.UseHeadlineView = not db.Visibility.EnemyTotem.UseHeadlineView
  db.Visibility.EnemyMinus.UseHeadlineView = not db.Visibility.EnemyMinus.UseHeadlineView

  Addon:ForceUpdate()
end

function TidyPlatesThreat_OnAddonCompartmentClick(addonName, buttonName)
  -- addonName: TidyPlates_ThreatPlates (name of directory)
  Addon:OpenOptions()
end