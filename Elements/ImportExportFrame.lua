local _, Addon = ...
local t = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local string = string
local print = print

-- WoW APIs
local GameTooltip = GameTooltip

-- ThreatPlates APIs
local LibStub = LibStub
local L = t.L
local TidyPlatesThreat = TidyPlatesThreat

-- cache copyFrame if used multiple times
local copyFrame = nil

local function CreateCopyFrame()
  local AceGUI = LibStub("AceGUI-3.0")
  local AceConfigDialog = LibStub("AceConfigDialog-3.0")

  local frame = AceGUI:Create("Frame")
  frame:SetTitle(L["Import/Export Profile"])
  frame:SetCallback("OnEscapePressed", function()
    frame:Hide()
  end)
  frame:SetLayout("fill")

  local editBox = AceGUI:Create("MultiLineEditBox")
  editBox:SetFullWidth(true)
  editBox.button:Hide()
  editBox.label:SetText(L["Paste ThreatPlates profile string into the box and then close the window"])

  frame:AddChild(editBox)
  frame.editBox = editBox

  function frame:OpenExport(text)
    --NOTE: options are closed and re-opened around the copyframe so the state of the profile is always reflected in that window
    AceConfigDialog:Close(t.ADDON_NAME)
    GameTooltip:Hide()

    local editBox = self.editBox

    editBox:SetMaxLetters(0)
    editBox.editBox:SetScript("OnChar", function() editBox:SetText(text); editBox:HighlightText(); end)
    editBox.editBox:SetScript("OnMouseUp", function() editBox:HighlightText(); end)
    editBox.label:Hide()
    editBox:SetText(text)
    editBox:HighlightText()
    editBox:SetFocus()

    self:SetCallback("OnClose", function()
      AceConfigDialog:Open(t.ADDON_NAME)
    end)

    self:Show()
  end

  function frame:OpenImport(onImportHandler)
    AceConfigDialog:Close(t.ADDON_NAME)
    GameTooltip:Hide()

    local editBox = self.editBox

    editBox:SetMaxLetters(0)
    editBox.editBox:SetScript("OnChar", nil)
    editBox.editBox:SetScript("OnMouseUp", nil)
    editBox.label:Show()
    editBox:SetText("")
    editBox:SetFocus()

    self:SetCallback("OnClose", function()
      onImportHandler(editBox:GetText())
      AceConfigDialog:Open(t.ADDON_NAME)
    end)

    self:Show()
  end

  return frame
end

function Addon:ShowCopyFrame(mode, modeArg)
  local Serializer = LibStub:GetLibrary("AceSerializer-3.0")
  local LibDeflate = LibStub:GetLibrary("LibDeflate")

  -- show the appropriate frames
  if copyFrame == nil then
    copyFrame = CreateCopyFrame()
  end

  if mode == "export" then
    local serialized = Serializer:Serialize(modeArg)
    local compressed = LibDeflate:CompressDeflate(serialized)

    copyFrame:OpenExport(LibDeflate:EncodeForPrint(compressed))
  else
    local function ImportHandler(encoded)
      --window opened by mistake etc, just ignore it
      if string.len(encoded) == 0 then
        return
      end

      local errorMsg = L["Something went wrong importing your profile, please check the import string"]
      local decoded = LibDeflate:DecodeForPrint(encoded)

      if not decoded then
        print(errorMsg)
        return
      end

      local decompressed = LibDeflate:DecompressDeflate(decoded)

      if not decompressed then
        print(errorMsg)
        return
      end

      local success, deserialized = Serializer:Deserialize(decompressed)

      if not success then
        print(errorMsg)
        return
      end

      --apply imported profile as a new profile
      TidyPlatesThreat.db:SetProfile("imported profile") --will create a new profile

      --[[
        NOTE: using merge as there appears to be an observer that writes changes to the savedvariables.
        using assignment (profile = deserialized) removes this functionality which means the imported profile is never saved.
      ]]--

      self.MergeIntoTable(TidyPlatesThreat.db.profile, deserialized)
      self:ForceUpdate()
    end

    copyFrame:OpenImport(ImportHandler)
  end
end
