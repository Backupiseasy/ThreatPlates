local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Stuff for handling the configuration of Threat Plates - ThreatPlatesDB
---------------------------------------------------------------------------------------------------

local function ConvertHeadlineView(profile)
  -- convert old entry and save it
  local old_value = profile.alphaFeatureHeadlineView
  if not profile.headlineView then
    profile.headlineView = {}
  end
  profile.headlineView.enabled = old_value
  -- delete old entry
  profile.alphaFeatureHeadlineView = nil
end

-- Entries in the config db that should be migrated and deleted
local DEPRECATED_DB_ENTRIES = {
  alphaFeatures = true,
  optionSpecDetectionAutomatic = true,
  alphaFeatureHeadlineView = ConvertHeadlineView, -- migrate to headlineView.enabled
}

-- Remove all deprected Entries
-- Called whenever the addon is loaded and a new version number is detected
local function DeleteDeprecatedEntries()
  -- determine current addon version and compare it with the DB version
  local db_global = TidyPlatesThreat.db.global


  -- Profiles:
  if db_global.version ~= tostring(ThreatPlates.Meta("version")) then
    -- addon version is newer that the db version => check for old entries
    for profile, profile_table in pairs(TidyPlatesThreat.db.profiles) do
      -- iterate over all profiles
      for key, func in pairs(DEPRECATED_DB_ENTRIES) do
        if profile_table[key] ~= nil then
          if DEPRECATED_DB_ENTRIES[key] == true then
            ThreatPlates.Print ("Deleting deprecated DB entry \"" .. tostring(key) .. "\"")
            profile_table[key] = nil
          elseif type(DEPRECATED_DB_ENTRIES[key]) == "function" then
            ThreatPlates.Print ("Converting deprecated DB entry \"" .. tostring(key) .. "\"")
            DEPRECATED_DB_ENTRIES[key](profile_table)
          end
        end
      end
    end
  end
end

local function CleanupDatabase()
  DeleteDeprecatedEntries()
end

ThreatPlates.CleanupDatabase = CleanupDatabase
