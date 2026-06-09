---------------------------------------------------------------------------------------------------
-- Main file for addon Threat Plates
---------------------------------------------------------------------------------------------------
local _, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local max = math.max
local select = select

-- WoW APIs
local GetCVar, IsAddOnLoaded = GetCVar, C_AddOns.IsAddOnLoaded
local C_NamePlate = C_NamePlate
local C_Timer_After = C_Timer.After
local UnitClass = UnitClass
local GetSpecializationInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or _G.GetSpecializationInfo
local LoadAddOn = C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn
local SetNamePlateFriendlySize = C_NamePlate and C_NamePlate.SetNamePlateFriendlySize
local SetNamePlateEnemySize = C_NamePlate and C_NamePlate.SetNamePlateEnemySize
local SetNamePlateSize = C_NamePlate and C_NamePlate.SetNamePlateSize

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

-- # Nameplate Hierarchy, Anchoring, and Scaling
if Addon.WOW_USES_CLASSIC_NAMEPLATES then
  local SetBlizzardNameplateSize 

  if Addon.IS_MISTS_CLASSIC then
    -- Classic Era, TBC, Wrath, Cata and MoP Classic share the same synced nameplate size
    -- (friendly and enemy nameplates have a single size in these versions).
    local function CalculateSynchedNameplateSize()
      local db = Addon.db.profile.settings

      if db.frame.SyncWithHealthbar then
        local effective_scale = UIParent:GetEffectiveScale()
        local ui_scale = (Addon.NameplateParentFrame == WorldFrame and effective_scale) or 1
        
        -- Update values in settings, so that the options dialog (clickable area) shows the correct values
        -- Without multiplying with effective scale here (<= 1), the clickable area will be a lot wider that the nameplate width (no idea why)
        -- When increasing width and height of base nameplate size, x offset is constant, but y offset scales with the height (no idea why)
        -- In Classic, the nameplate parent also scales with effective scale
        db.frame.width = (db.healthbar.width) / ui_scale
        db.frame.height = (db.healthbar.height + 6) / ui_scale
      end
    
      return db.frame.width, db.frame.height
    end
    
    Addon.SetBaseNamePlateSize = function(self)
      if InCombatLockdown() then return end

      local db = self.db.profile
  
      if db.ShowFriendlyBlizzardNameplates or db.ShowEnemyBlizzardNameplates or self.IsInPvEInstance then
        SetNamePlateSize(152, 55)
      else
        local width, height = CalculateSynchedNameplateSize()
        SetNamePlateSize(width, height)
      end
  
      Addon:ConfigClickableArea(false)
    end    
  else
    -- Classic Era, TBC, Wrath, Cata and MoP Classic share the same synced nameplate size
    -- (friendly and enemy nameplates have a single size in these versions).
    local function CalculateSynchedNameplateSize()
      local db = Addon.db.profile.settings

      if db.frame.SyncWithHealthbar then
        local effective_scale = UIParent:GetEffectiveScale()
        local ui_scale = (Addon.NameplateParentFrame ~= UIParent and effective_scale) or 1
        
        -- Update values in settings, so that the options dialog (clickable area) shows the correct values
        -- Without multiplying with effective scale here (<= 1), the clickable area will be a lot wider that the nameplate width (no idea why)
        -- When increasing width and height of base nameplate size, x offset is constant, but y offset scales with the height (no idea why)
        -- In Classic, the nameplate parent also scales with effective scale
        db.frame.width = (db.healthbar.width * effective_scale + 10) / ui_scale
        db.frame.height = (db.healthbar.height + 6) / ui_scale
      end
    
      return db.frame.width, db.frame.height
    end
    
    Addon.SetBaseNamePlateSize = function(self)
      if InCombatLockdown() then return end
      
      local db = self.db.profile
  
      if db.ShowFriendlyBlizzardNameplates or db.ShowEnemyBlizzardNameplates or self.IsInPvEInstance then
        SetNamePlateFriendlySize(128, 32)
        SetNamePlateEnemySize(128, 32)
      else
        local width, height = CalculateSynchedNameplateSize()
        SetNamePlateFriendlySize(width, height)
        SetNamePlateEnemySize(width, height)
      end
  
      Addon:ConfigClickableArea(false)
    end    
  end   
else
  Addon.SetBaseNamePlateSize = function(self)
    local db = self.db.profile.settings
    local db_frame = db.frame

    if db_frame.SyncWithHealthbar then
      local db_healthbar = db.healthbar
      
      -- Update SavedVariable dimensions (also consumed by UpdateHitTestFrame per plate).
      -- Mirrors Blizzard's SetHitTestPoints formula (Blizzard_NamePlateUnitFrame.lua):
      --   extraXOffset = 10
      --   extraYOffset = healthBarHeight / 2  → hit region extends half the bar height above/below
      local ui_scale = (Addon.NameplateParentFrame == WorldFrame and UIParent:GetEffectiveScale()) or 1
      db_frame.width = (db_healthbar.width + 10) / ui_scale
      db_frame.height = (db_healthbar.height * 2) / ui_scale
      db_frame.widthFriend = (db_healthbar.widthFriend + 10) / ui_scale
      db_frame.heightFriend = (db_healthbar.heightFriend * 2) / ui_scale
    end

    local width  = max(db_frame.widthFriend,  db_frame.width)
    local height = max(db_frame.heightFriend, db_frame.height)

      -- Nameplate size also needs to be adjusted for the HitTestFrame to work. Otherwise the bigger HitTestFrame size
    -- will be ignored.
    SetNamePlateSize(width, height)
    self.SetNamePlateClickThrough()
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
  Addon.ExecuteAfterCombatEnds(function() Addon:SetBaseNamePlateSize() end, L["Unable to change a setting while in combat."])
  Addon.SetNamePlateClickThrough()
  
  -- Update all UI elements (frames, textures, ...)
  Addon:UpdatePlatesVisible()
  Addon:UpdateFramePropertiesOfPlatesCreated()
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
  -- When reloading the UI or logging out, PLAYER_LOGOUT fires and AceDB strips defaults from the profile. 
  -- Also, NAME_PLATE_UNIT_REMOVED fires for all visible nameplates. 
  -- If a nameplate is still shown under the mouse cursor, TP hides the mouseover highlight and fires MouseoverOnLeave. 
  -- This can result in a Lua error as profile defaults are no longer available (e.g. in Transparency). 
  -- The solution is to stop publishing internal TP events (via EventService.Publish) once Addon.IsShuttingDown == true. 
  RegisterCallback(Addon, 'OnDatabaseShutdown', function() Addon.IsShuttingDown = true end)

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