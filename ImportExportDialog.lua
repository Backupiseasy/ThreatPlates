---------------------------------------------------------------------------------------------------
-- Options dialog for importing/exporting data
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

-- Lua APIs

-- WoW APIs

-- ThreatPlates APIs
local ThreatPlates = Addon.ThreatPlates
local L = Addon.ThreatPlates.L

---------------------------------------------------------------------------------------------------
-- Constants and variables
---------------------------------------------------------------------------------------------------

-- cache ImportExportFrame if used multiple times
local ImportExportFrame = nil

---------------------------------------------------------------------------------------------------
-- Import/Export Dialog
---------------------------------------------------------------------------------------------------
local function CreateImportExportFrame()
  local frame = LibAceGUI:Create("Frame")
  frame:SetTitle(L["Import/Export Profile"])
  frame:SetCallback("OnEscapePressed", function()
    frame:Hide()
  end)
  frame:SetLayout("fill")

  local editBox = LibAceGUI:Create("MultiLineEditBox")
  editBox:SetFullWidth(true)
  editBox.button:Hide()
  editBox.label:SetText(L["Paste the Threat Plates profile string into the text field below and then close the window"])

  frame:AddChild(editBox)
  frame.editBox = editBox

  function frame:OpenExport(text)
    local editBox = self.editBox

    editBox:SetMaxLetters(0)
    editBox.editBox:SetScript("OnChar", function() editBox:SetText(text); editBox:HighlightText(); end)
    editBox.editBox:SetScript("OnMouseUp", function() editBox:HighlightText(); end)
    editBox.label:Hide()
    editBox:SetText(text)
    editBox:HighlightText()

    self:Show()
    editBox:SetFocus()
  end

  function frame:OpenImport(import_handler)
    local editBox = self.editBox

    editBox:SetMaxLetters(0)
    editBox.editBox:SetScript("OnChar", nil)
    editBox.editBox:SetScript("OnMouseUp", nil)
    editBox.label:Show()
    editBox:SetText("")

    self:SetCallback("OnClose", function()
      import_handler(editBox:GetText())
    end)

    self:Show()
    editBox:SetFocus()
  end

  return frame
end

local function ImportStringData(encoded)
  --window opened by mistake etc, just ignore it
  if string.len(encoded) == 0 then
    return
  end

  local decoded = Addon.LibDeflate:DecodeForPrint(encoded)
  if not decoded then
    return
  end

  local decompressed = Addon.LibDeflate:DecompressDeflate(decoded)
  if not decompressed then
    return
  end

  local success, deserialized = Addon.LibAceSerializer:Deserialize(decompressed)

  if not success then
    return
  end

  return success, deserialized
end

---------------------------------------------------------------------------------------------------
-- Import/export profiles
---------------------------------------------------------------------------------------------------

local function ShowExportFrame(modeArg)
  ImportExportFrame = ImportExportFrame or CreateImportExportFrame()

  local serialized = Addon.LibAceSerializer:Serialize(modeArg)
  local compressed = Addon.LibDeflate:CompressDeflate(serialized)

  ImportExportFrame:OpenExport(Addon.LibDeflate:EncodeForPrint(compressed))
end

local function ProfileImportHandler(encoded)
  local success, import_data = ImportStringData(encoded)

  if success then
    if not import_data.Version or not import_data.Profile and not import_data.ProfileName or type (import_data.ProfileName) ~= "string" then
      Addon.Logging.Error(L["The import string has an unknown format and cannot be imported. Verify that the import string was generated from the same Threat Plates version that you are using currently."])
    else
      if import_data.Version ~= array.Meta("version") then
        Addon.Logging.Error(L["The import string contains a profile from an different Threat Plates version. The profile will still be imported (and migrated as far as possible), but some settings from the imported profile might be lost."])
      end

      local imported_profile_name = import_data.ProfileName

      -- Adjust the profile name if there is a name conflict:
      local imported_profile_no = 1
      while Addon.db.profiles[imported_profile_name] do
        imported_profile_name = import_data.ProfileName .. " (" .. tostring(imported_profile_no) .. ")"
        imported_profile_no = imported_profile_no + 1
      end
      --        for profile_name, profile in pairs(Addon.db.profiles) do
      --          local no = profile_name:match("^" .. import_data.ProfileName .. " %((%d+)%)$") or (profile_name == import_data.ProfileName and 0)
      --          if tonumber(no) and tonumber(no) >= imported_profile_no then
      --            imported_profile_no = tonumber(no) + 1
      --          end
      --        end
      --        local imported_profile_name = import_data.ProfileName .. ((imported_profile_no == 0 and "") or (" (" .. tostring(imported_profile_no) .. ")"))

      Addon.ImportProfile(import_data.Profile, imported_profile_name, import_data.Version)
      Addon:ProfChange()
    end
  else
    Addon.Logging.Error(L["The import string has an unknown format and cannot be imported. Verify that the import string was generated from the same Threat Plates version that you are using currently."])
  end
end

local function OpenImportDialogForProfiles()
  ImportExportFrame = ImportExportFrame or CreateImportExportFrame()
  
  ImportExportFrame:OpenImport(ProfileImportHandler)
end

---------------------------------------------------------------------------------------------------
-- Import/export custom styles
---------------------------------------------------------------------------------------------------

local function CustomStylesImportHandler(encoded)
  local success, import_data = ImportStringData(encoded)

  if success then
    if not import_data.Version or not import_data.CustomStyles then
      Addon.Logging.Error(L["The import string has an invalid format and cannot be imported. Verify that the import string was generated from the same Threat Plates version that you are using currently."])
    else
      if import_data.Version ~= array.Meta("version") then
        Addon.Logging.Error(L["The import string contains custom nameplate settings from a different Threat Plates version. The custom nameplates will still be imported (and migrated as far as possible), but some settings from the imported custom nameplates might be lost."])
      end

      local imported_custom_styles  = {}

      for i, custom_style  in ipairs (import_data.CustomStyles) do
        -- Import all values from the custom style as long the are valid entries with the correct type
        -- based on the default custom style "**"
        custom_style = Addon.ImportCustomStyle(custom_style)  -- replace the original imported custom style with the merged one

        local trigger_type = custom_style.Trigger.Type
        local triggers = custom_style.Trigger[trigger_type].AsArray

        local check_ok, duplicate_triggers = CustomPlateCheckIfTriggerIsUnique(trigger_type, triggers, custom_style)
        if not check_ok then
          Addon.Logging.Error(L["A custom nameplate with this trigger already exists: "] .. table.concat(duplicate_triggers, "; ") .. L[". You cannot use two custom nameplates with the same trigger. The imported custom nameplate will be disabled."])
          custom_style.Enable.Never = true
        end

        imported_custom_styles[#imported_custom_styles + 1] = custom_style
      end

      -- Only insert custom styles if all have a valid format (format checking is currently not implemented/not working
      if success then
        local slot_no = #db.uniqueSettings
        for i, custom_style  in ipairs (imported_custom_styles) do
          table.insert(db.uniqueSettings, slot_no + i, custom_style)
        end

        CreateCustomNameplatesGroup()
      end
    end
  else
    Addon.Logging.Error(L["The import string has an unknown format and cannot be imported. Verify that the import string was generated from the same Threat Plates version that you are using currently."])
  end
end

function Addon:OpenImportDialogForCustomStyles()
  ImportExportFrame = ImportExportFrame or CreateImportExportFrame()

  ImportExportFrame:OpenImport(CustomStylesImportHandler)
end

function Addon.OpenExportDialogForCustomStyles(export_data)
  ImportExportFrame = ImportExportFrame or CreateImportExportFrame()

  local serialized = Addon.LibAceSerializer:Serialize(export_data)
  local compressed = Addon.LibDeflate:CompressDeflate(serialized)

  ListItemTooltip:Hide()

  ImportExportFrame:OpenExport(Addon.LibDeflate:EncodeForPrint(compressed))
end