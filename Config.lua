local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Stuff for handling the configuration of Threat Plates - ThreatPlatesDB
---------------------------------------------------------------------------------------------------

local function ConvertHeadlineView()
  -- Convert old to new entry
end

-- Entries in the config db that should be migrated and deleted
local DEPRECATED_DB_ENTRIES = {
  alphaFeatures = true,
  optionSpecDetectionAutomatic = true,
  --alphaFeatureHeadlineView = ConvertHeadlineView, -- migrate to headlineView.enabled
}

-- Remove all deprected Entries
-- Called whenever the addon is loaded and a new version number is detected
local function DeleteDeprecatedEntries()
  -- determine current addon version and compare it with the DB version
  local db_global = TidyPlatesThreat.db.global

  if db_global.version ~= "newest" then -- tostring(ThreatPlates.Meta("version")) then
    -- addon version is newer that the db version => check for old entries
    for key, func in pairs(DEPRECATED_DB_ENTRIES) do
      if TidyPlatesThreat.db.profile[key] ~= nil then
        if DEPRECATED_DB_ENTRIES[key] == true then
          ThreatPlates.Print ("Deleting deprecated DB entry \"" .. tostring(key) .. "\"")
          TidyPlatesThreat.db.profile[key] = nil
        elseif type(DEPRECATED_DB_ENTRIES[key]) == "function" then
          ThreatPlates.Print ("Converting deprecated DB entry \"" .. tostring(key) .. "\"")
          DEPRECATED_DB_ENTRIES[key]()
        end
      end
    end
  end
end

local function CleanupDatabase()
  DeleteDeprecatedEntries()
end

ThreatPlates.CleanupDatabase = CleanupDatabase
