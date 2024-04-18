---------------------------------------------------------------------------------------------------
-- Options dialog for custom styles
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

-- Lua APIs
local table_sort, table_insert, table_remove = table.sort, table.insert, table.remove
local tostring = tostring
local ipairs = ipairs

-- WoW APIs

-- ThreatPlates APIs
local ThreatPlates = Addon.ThreatPlates
local L = Addon.ThreatPlates.L
local CopyTable = Addon.ThreatPlates.CopyTable

local ProcessCustomStyleUpdate = Addon.ProcessCustomStyleUpdate
local CustomPlateGetExampleForEventScript = Addon.CustomPlateGetExampleForEventScript

local GetSpacerEntry = Addon.GetSpacerEntry
local GetTransparencyEntryDefault = Addon.GetTransparencyEntryDefault
local GetScaleEntryDefault = Addon.GetScaleEntryDefault
local GetValue = Addon.GetValue
local SetValue, SetValuePlain, SetValueWidget = Addon.SetValue, Addon.SetValuePlain, Addon.SetValueWidget
local SetColor, GetColor = Addon.SetColor, Addon.GetColor

  ---------------------------------------------------------------------------------------------------
-- Constants and variables
---------------------------------------------------------------------------------------------------

local DIALOG_NAME = ThreatPlates.ADDON_NAME .. "CustomStyleOptions"
local LEFT_PANE_WIDTH = 280
local PANE_PADDING = 10
local TRIGGER_TYPE_TO_NAME_PREFIX = {
  Aura = L["Aura"],
  Cast = L["Cast"],
  Name = L["Unit"],
  Script = L["Script"],
}

local CustomStylesDialog = CreateFrame("Frame", "ThreatPlatesCustomStylesDialog", UIParent, "PortraitFrameTemplate")
local SelectedListItemIndex = 1
local CustomStylesListItems = {}

---------------------------------------------------------------------------------------------------
-- Custom Style Handler
---------------------------------------------------------------------------------------------------

local function CustomStyleSetIcon(index, icon_location)
  local _, icon

  local custom_style = Addon.db.profile.uniqueSettings[index]
  if custom_style.UseAutomaticIcon then
    _, _, icon = GetSpellInfo(custom_style.Trigger[custom_style.Trigger.Type].AsArray[1])
  elseif not icon_location then
    icon = custom_style.icon
  else
    custom_style.SpellID = nil
    custom_style.SpellName = nil

    local spell_id = tonumber(icon_location)
    if spell_id then -- no string, so val should be a spell ID
      _, _, icon = GetSpellInfo(spell_id)
      if icon then
        custom_style.SpellID = spell_id
      else
        icon = spell_id -- Set icon to spell_id == icon_location, so that the value gets stored
        Addon.Logging.Error("Invalid spell ID for custom nameplate icon: " .. icon_location)
      end
    else
      icon_location = tostring(icon_location)
      _, _, icon = GetSpellInfo(icon_location)
      if icon then
        custom_style.SpellName = icon_location
      end
      icon = icon or icon_location
    end
  end

  if not icon or (type(icon) == "string" and icon:len() == 0) then
    icon = "INV_Misc_QuestionMark.blp"
  end

  custom_style.icon = icon
end

local function CustomStyleGetIcon(index)
  local _, icon

  local custom_style = Addon.db.profile.uniqueSettings[index]
  if custom_style.UseAutomaticIcon then
    icon = custom_style.icon
  else
    local spell_id = custom_style.SpellID
    if spell_id then
      _, _, icon = GetSpellInfo(spell_id)
    else
      icon = custom_style.icon
      if type(icon) == "string" and not icon:find("\\") and not icon:sub(-4) == ".blp" then
        -- Maybe a spell name
        _, _, icon = GetSpellInfo(icon)
      end
    end
  end

  if type(icon) == "string" and icon:sub(-4) == ".blp" then
    icon = "Interface\\Icons\\" .. icon
  end

  return icon
end

function Addon.GetCustomStyleTriggerType(custom_style)
  return TRIGGER_TYPE_TO_NAME_PREFIX[custom_style.Trigger.Type]
end


function Addon.GetCustomStyleName(custom_style)
  if custom_style.Name == "" then
    return custom_style.Trigger[custom_style.Trigger.Type].Input or ""
  else
    return custom_style.Name
  end
end

function CustomStyleCheckIfTriggerIsUnique(trigger_type, triggers, selected_plate)
  local duplicate_triggers = {}

  if trigger_type == "Script" then
    return true, duplicate_triggers
  end

  for i, trigger_value in ipairs(triggers) do
    if trigger_value ~= nil and trigger_value ~= "" then
      -- Check if here is already another custom nameplate with the same trigger:
      local custom_plate = Addon.Cache.CustomPlateTriggers[trigger_type][trigger_value]

      if not (custom_plate == nil or custom_plate.Enable.Never or selected_plate.Enable.Never or custom_plate == selected_plate) then
        duplicate_triggers[#duplicate_triggers + 1] = trigger_value
      end
    end
  end


  return #duplicate_triggers == 0, duplicate_triggers
end

function CustomStyleCheckIfTriggerIsUniqueWithErrorMessage(trigger_type, triggers, selected_plate)
  local check_ok, duplicate_triggers = CustomStyleCheckIfTriggerIsUnique(trigger_type, triggers, selected_plate)

  if not check_ok then
    StaticPopup_Show("TriggerAlreadyExists", table.concat(duplicate_triggers, "; "))
  end

  return check_ok
end

function CustomStyleCheckAndUpdateEntry(info, val, index)
  local selected_style = Addon.db.profile.uniqueSettings[index]
  local trigger_type = selected_style.Trigger.Type

  local triggers = Addon.Split(val)
  -- Convert spell or aura IDs to numerical values, otherwise they won't be recognized
  for i, trigger in ipairs(triggers) do
    if  trigger_type == "Aura" or trigger_type == "Cast" then
      triggers[i] = tonumber(trigger) or trigger
    else
      triggers[i] = trigger
    end
  end

  -- Check if here is already another custom nameplate with the same trigger:
  if CustomStyleCheckIfTriggerIsUniqueWithErrorMessage(trigger_type, triggers, selected_style) then
    selected_style.Trigger[trigger_type].Input = val
    selected_style.Trigger[trigger_type].AsArray = triggers
    CustomStyleSetIcon(SelectedListItemIndex)
    Addon.ProcessCustomStyleUpdate()
  end
end

local function CustomStyleCheckAndUpdateEntry(info, val, index)
  local selected_plate = Addon.db.profile.uniqueSettings[index]
  local trigger_type = selected_plate.Trigger.Type

  local triggers = Addon.Split(val)
  -- Convert spell or aura IDs to numerical values, otherwise they won't be recognized
  for i, trigger in ipairs(triggers) do
    if  trigger_type == "Aura" or trigger_type == "Cast" then
      triggers[i] = tonumber(trigger) or trigger
    else
      triggers[i] = trigger
    end
  end

  -- Check if here is already another custom nameplate with the same trigger:
  if CustomStyleCheckIfTriggerIsUniqueWithErrorMessage(trigger_type, triggers, selected_plate) then
    selected_plate.Trigger[trigger_type].Input = val
    selected_plate.Trigger[trigger_type].AsArray = triggers
    CustomStyleSetIcon(SelectedListItemIndex)
    ProcessCustomStyleUpdate()
  end
end

local function GetSelectedCustomStyle()
  return Addon.db.profile.uniqueSettings[SelectedListItemIndex]
end

local function GetCustomStyleID(custom_style)
  return tostring(custom_style)
end

local function GetCustomStyleListItemByIndex(index)
  local id = GetCustomStyleID(Addon.db.profile.uniqueSettings[index])
  return CustomStylesListItems[id], id
end

local function GetCustomStyleListItem(custom_style)
  local id = GetCustomStyleID(custom_style)
  return CustomStylesListItems[id], id
end

local function GetSelectedCustomStyleListItem()
  return GetCustomStyleListItemByIndex(SelectedListItemIndex)
end


-- Filtering and sorting custom styles
local function SortCustomStylesAtoZ(a, b)
  local a_key = a.Trigger.Type .. a.Trigger[a.Trigger.Type].Input .. tostring(a.Enable.Never)
  local b_key = b.Trigger.Type .. b.Trigger[b.Trigger.Type].Input .. tostring(b.Enable.Never)
  return a_key < b_key
end

local function SortCustomStylesZtoA(a, b)
  local b_key = b.Trigger.Type .. b.Trigger[b.Trigger.Type].Input .. tostring(b.Enable.Never)
  local a_key = a.Trigger.Type .. a.Trigger[a.Trigger.Type].Input .. tostring(a.Enable.Never)
  return a_key > b_key
end

local function SortCustomStylesByIndex(a, b)
  return a.Index < b.Index
end

---------------------------------------------------------------------------------------------------
-- Scrollable Item List 
---------------------------------------------------------------------------------------------------

local function CreateListPane(custom_styles_dialog)
  -- Left side container with list of custom styles
  local left_container = Addon.LibAceGUI:Create("InlineGroup")
  left_container.frame:SetParent(custom_styles_dialog)
  left_container.frame:SetPoint("TOPLEFT", custom_styles_dialog, "TOPLEFT", PANE_PADDING + 4, -65 - PANE_PADDING)
  left_container.frame:SetPoint("BOTTOMRIGHT", custom_styles_dialog, "BOTTOMLEFT", LEFT_PANE_WIDTH + PANE_PADDING + 12, PANE_PADDING)
  left_container.frame:Show()

  -- Scrollable list for left side container
  local item_list = Addon.LibAceGUI:Create("ScrollFrame")
  item_list:SetLayout("ThreatPlatesScrollLayout")
  item_list.width = "fill"
  item_list.height = "fill"
  left_container:SetLayout("Fill")
  left_container:AddChild(item_list)
  item_list.frame:Show()

  function item_list:DeleteChild(list_item_to_delete)
    for index, list_item in ipairs(self.children) do
      if list_item == list_item_to_delete then
        table_remove(self.children, index)
      end
    end
    list_item_to_delete:OnRelease()
    self:DoLayout()
  end

  function item_list:GetScrollPos()
    local status = self.status or self.localstatus
    return status.offset, status.offset + self.scrollframe:GetHeight()
  end

  -- override SetScroll to make children visible as needed
  local oldSetScroll = item_list.SetScroll
  function item_list:SetScroll(value)
    oldSetScroll(self, value)
    self.LayoutFunc(self.content, self.children, true)
  end

  function item_list:SetScrollPos(top, bottom)
    local status = self.status or self.localstatus
    local viewheight = self.scrollframe:GetHeight()
    local height = self.content:GetHeight()
    local move

    local viewtop = -1 * status.offset
    local viewbottom = -1 * (status.offset + viewheight)
    if top > viewtop then
      move = top - viewtop
    elseif bottom < viewbottom then
      move = bottom - viewbottom
    else
      move = 0
    end

    status.offset = status.offset - move

    self.content:ClearAllPoints()
    self.content:SetPoint("TOPLEFT", 0, status.offset)
    self.content:SetPoint("TOPRIGHT", 0, status.offset)

    status.scrollvalue = status.offset / ((height - viewheight) / 1000.0)
  end

  function item_list:CenterOnPicked(selected_item)
    local _, _, _, _, yOffset = selected_item.frame:GetPoint(1)
    if not yOffset then
      yOffset = selected_item.frame.yOffset
    end
    if yOffset then
      local top, bottom = yOffset, yOffset - selected_item.frame:GetHeight()

      local status = self.status or self.localstatus
      local viewheight = self.scrollframe:GetHeight()
      local height = self.content:GetHeight()
      local middle_offset = viewheight / 2
      local move

      local viewtop = -1 * status.offset
      local viewbottom = -1 * (status.offset + viewheight)
      if top > viewtop then
        -- Offset must be negative, so we can move to offset == 0 at most
        move = min(top - viewtop + middle_offset, status.offset)
      elseif bottom < viewbottom then
        move = bottom - viewbottom - middle_offset
      else
        move = 0
        -- This would center the currently selected item: move = top - (viewtop - middle_offset)
      end
      
      status.offset = status.offset - move

      self.content:ClearAllPoints()
      self.content:SetPoint("TOPLEFT", 0, status.offset)
      self.content:SetPoint("TOPRIGHT", 0, status.offset)

      status.scrollvalue = status.offset / ((height - viewheight) / 1000.0)
    end
  end

  custom_styles_dialog.List = item_list
end

local function CreateListItem(index, custom_style)
  local list_item = Addon.LibAceGUI:Create("ThreatPlatesListItem")
  list_item:Initialize(CustomStylesDialog)
  list_item:SetCustomStyle(custom_style)
  list_item:SetIndex(index)
  
  CustomStylesDialog.List:AddChild(list_item)
  
  local id = GetCustomStyleID(custom_style)
  CustomStylesListItems[GetCustomStyleID(custom_style)] = list_item

  return list_item
end

local function UpdateListItem(index)
  local list_item = GetCustomStyleListItemByIndex(index)
  list_item:SetCustomStyle(data)
  list_item:SetIndex(index)

  return list_item
end

function SwitchListItems(index, index_to_switch_with)
  local custom_style_list = Addon.db.profile.uniqueSettings

  -- Don't move up the first or the last entry
  if index_to_switch_with > 0 and index_to_switch_with <  (#Addon.db.profile.uniqueSettings + 1) then
    custom_style_list[index], custom_style_list[index_to_switch_with] = custom_style_list[index_to_switch_with], custom_style_list[index]

    -- Also adjust the selected item as it has a different index now
    SelectedListItemIndex = index_to_switch_with

    CustomStylesDialog:SortCustomStylesList() 
    CustomStylesDialog.List:DoLayout()
  end
end

---------------------------------------------------------------------------------------------------
-- Options for a Custom Style
--------------------------------------------------------------------------------------------------

local function CreateOptionsPane(custom_styles_dialog)
    -- Right side container with custom style options
    local custom_style_options = Addon.LibAceGUI:Create("InlineGroup")
    custom_style_options.frame:SetParent(custom_styles_dialog)
    custom_style_options.frame:SetPoint("TOPLEFT", custom_styles_dialog.ButtonMoveUp.frame, "BOTTOMLEFT", 0, PANE_PADDING)
    custom_style_options.frame:SetPoint("BOTTOMRIGHT", custom_styles_dialog, "BOTTOMRIGHT", -PANE_PADDING, PANE_PADDING)
    --right_container.frame:SetClipsChildren(true)
    custom_style_options:SetLayout("Fill")
    custom_style_options.titletext:Hide()
    custom_style_options.frame:Show()
    -- Hide the border
    -- custom_style_options.content:GetParent():SetBackdrop(nil)
    -- custom_style_options.content:SetPoint("TOPLEFT", 0, -28)
    -- custom_style_options.content:SetPoint("BOTTOMRIGHT", 0, 0)

    custom_styles_dialog.CustomStylesOptionsTable = {
      name = "CustomStyleOptions",
      type = "group",
      childGroups = "tab",
      set = SetValue,
      get = GetValue,
      args = {}
    }
    Addon.LibAceConfig:RegisterOptionsTable(DIALOG_NAME, custom_styles_dialog.CustomStylesOptionsTable)
    --Addon.LibAceConfigDialog:Open(DIALOG_NAME, custom_styles_dialog.Options)

    custom_styles_dialog.Options = custom_style_options
end

local function 
  CreateNewCustomStylePane(custom_styles_dialog)
    local custom_style_new_options = Addon.LibAceGUI:Create("InlineGroup")
    custom_style_new_options.frame:SetParent(custom_styles_dialog)
    custom_style_new_options.frame:SetPoint("TOPLEFT", custom_styles_dialog.ButtonMoveUp.frame, "BOTTOMLEFT", 0, PANE_PADDING)
    custom_style_new_options.frame:SetPoint("BOTTOMRIGHT", custom_styles_dialog, "BOTTOMRIGHT", -PANE_PADDING, PANE_PADDING)
    --right_container.frame:SetClipsChildren(true)
    custom_style_new_options:SetLayout("Flow")
    custom_style_new_options.titletext:Hide()
    custom_style_new_options.frame:Show()

    local item_new = Addon.LibAceGUI:Create("ThreatPlatesListItem")
    item_new:Initialize(CustomStylesDialog)
    item_new:SetTitle(L["New"])
    item_new:SetIcon("Trade_Engineering.blp")
    custom_style_new_options:AddChild(item_new)
    
    local item_duplicate = Addon.LibAceGUI:Create("ThreatPlatesListItem")
    item_duplicate:Initialize(CustomStylesDialog)
    item_duplicate:SetTitle(L["Duplicate"])
    item_duplicate:SetIcon("UI_MajorFaction_Centaur.tga")
    custom_style_new_options:AddChild(item_duplicate)

    local item_import = Addon.LibAceGUI:Create("ThreatPlatesListItem")
    item_import:Initialize(CustomStylesDialog)
    item_import:SetTitle(L["Import"])
    item_import:SetIcon("Trade_Engineering.blp")
    custom_style_new_options:AddChild(item_import)

  -- local button_new = Addon.LibAceGUI:Create("Button")
  -- button_new:SetText(L["New"])
  -- button_new.frame:SetParent(custom_style_options.frame)
  -- button_new:SetPoint("TOP", custom_style_options.frame, "TOP", 0, -100)
  -- button_new:SetWidth(200)
  -- button_new:SetWidth(60)
  -- button_new.frame:Show()

  -- local button_duplicate = Addon.LibAceGUI:Create("Button")
  -- button_duplicate:SetText(L["Duplicate"])
  -- button_duplicate.frame:SetParent(custom_style_options.frame)
  -- button_duplicate:SetPoint("TOP", custom_style_options.frame, "TOP", 0, -200)
  -- button_duplicate:SetWidth(200)
  -- button_duplicate:SetWidth(60)
  -- button_duplicate.frame:Show()

  -- local import = Addon.LibAceGUI:Create("Button")
  -- import:SetText(L["Import"])
  -- import.frame:SetParent(custom_style_options.frame)
  -- import:SetPoint("TOP", custom_style_options.frame, "TOP", 0, -300)
  -- import:SetWidth(200)
  -- import:SetWidth(60)
  -- import.frame:Show()

  -- button_new:SetCallback("OnClick", function(widget) 
  --   local custom_style = CopyTable(ThreatPlates.DEFAULT_SETTINGS.profile.uniqueSettings["**"])
  --   custom_style.Trigger.Name.Input = ""
    
  --   local index = SelectedListItemIndex or 1
  --   table_insert(Addon.db.profile.uniqueSettings, index, custom_style)
  --   local list_item = CreateListItem(index, custom_style)

  --   CustomStylesDialog:SortCustomStylesList() 
  --   CustomStylesDialog:DisplayPick(list_item)
  -- end)

end

--------------------------------------------------------------------------------------------------
-- Toolbar for the Item List
--------------------------------------------------------------------------------------------------

local function CreateToolbarPane(custom_styles_dialog)
  -- Toolbar
  local toolbar_container = CreateFrame("Frame", nil, custom_styles_dialog)
  toolbar_container:SetParent(custom_styles_dialog)
  toolbar_container:Show()
  
  local button_delete = Addon.LibAceGUI:Create("Button")
  button_delete:SetText(L["Delete"])
  button_delete.frame:SetParent(toolbar_container)
  button_delete:SetPoint("BOTTOMRIGHT", custom_styles_dialog, "TOPLEFT", LEFT_PANE_WIDTH + PANE_PADDING + 10, -65 + PANE_PADDING)
  button_delete:SetWidth(110)
  button_delete.frame:Show()
  custom_styles_dialog.ButtonDelete = button_delete
  button_delete:SetCallback("OnClick", function(widget) 
    if SelectedListItemIndex then
      local list_item, id = GetCustomStyleListItemByIndex(SelectedListItemIndex)
      
      table_remove(Addon.db.profile.uniqueSettings, SelectedListItemIndex)

      CustomStylesDialog.List:DeleteChild(list_item)
      CustomStylesListItems[id] = nil
      
      CustomStylesDialog:SortCustomStylesList() 
      CustomStylesDialog:DisplayPick(min(SelectedListItemIndex, #Addon.db.profile.uniqueSettings))
    end
  end)

  local button_new = Addon.LibAceGUI:Create("Button")
  button_new:SetText(L["New"])
  button_new.frame:SetParent(toolbar_container)
  button_new:SetPoint("BOTTOMRIGHT", button_delete.frame, "BOTTOMLEFT", -PANE_PADDING, 0)
  button_new:SetWidth(110)
  button_new.frame:Show()
  button_new:SetCallback("OnClick", function(widget) 
    local custom_style = CopyTable(ThreatPlates.DEFAULT_SETTINGS.profile.uniqueSettings["**"])
    custom_style.Trigger.Name.Input = ""
    
    local index = SelectedListItemIndex or 1
    table_insert(Addon.db.profile.uniqueSettings, index, custom_style)
    local list_item = CreateListItem(index, custom_style)

    CustomStylesDialog:SortCustomStylesList() 
    CustomStylesDialog:DisplayPick(list_item)
  end)

  local button_move_up = Addon.LibAceGUI:Create("Button")
  button_move_up:SetText(L["Move Up"])
  button_move_up.frame:SetParent(toolbar_container)
  button_move_up.frame:Show()
  custom_styles_dialog.ButtonMoveUp = button_move_up
  button_move_up:SetCallback("OnClick", function(widget) 
    SwitchListItems(SelectedListItemIndex, SelectedListItemIndex - 1)
  end)

  local button_move_down = Addon.LibAceGUI:Create("Button")
  button_move_down:SetText(L["Move Down"])
  button_move_down.frame:SetParent(toolbar_container)
  button_move_down.frame:Show()
  custom_styles_dialog.ButtonMoveDown = button_move_down
  button_move_down:SetCallback("OnClick", function(widget) 
    SwitchListItems(SelectedListItemIndex, SelectedListItemIndex + 1)
  end)

  local button_sort_az = Addon.LibAceGUI:Create("Button")
  button_sort_az:SetText(L["Sort A-Z"])
  button_sort_az.frame:SetParent(toolbar_container)
  button_sort_az.frame:Show()
  custom_styles_dialog.ButtonSortAtoZ = button_sort_az
  button_sort_az:SetCallback("OnClick", function() 
    CustomStylesDialog:SortCustomStylesList(SortCustomStylesAtoZ) 
  end)

  local button_sort_za = Addon.LibAceGUI:Create("Button")
  button_sort_za:SetText(L["Sort Z-A"])
  button_sort_za.frame:SetParent(toolbar_container)
  button_sort_za.frame:Show()
  custom_styles_dialog.ButtonSortZtoA = button_sort_za
  button_sort_za:SetCallback("OnClick", function() 
    CustomStylesDialog:SortCustomStylesList(SortCustomStylesZtoA) 
  end)

  button_move_up:SetPoint("BOTTOMLEFT", button_delete.frame, "BOTTOMRIGHT", PANE_PADDING / 2, -0)
  button_move_up:SetPoint("TOPRIGHT", button_move_down.frame, "TOPLEFT", -PANE_PADDING, 0)
  button_move_down:SetPoint("TOPRIGHT", button_sort_az.frame, "TOPLEFT", -PANE_PADDING, 0)
  button_sort_az:SetPoint("TOPRIGHT", button_sort_za.frame, "TOPLEFT", -PANE_PADDING, 0)
  button_sort_za:SetPoint("BOTTOMRIGHT", custom_styles_dialog, "TOPRIGHT", -PANE_PADDING, -65 + PANE_PADDING)
end

---------------------------------------------------------------------------------------------------
-- Custom style options pane
---------------------------------------------------------------------------------------------------

local function CreateNewCustomStyleOptions()
  local entry = {
    NewSlot = {
      name = L["New"],
      order = 10,
      type = "execute",
      width = "half",
      desc = L["Insert a new custom nameplate slot after the currently selected slot."],
      func = function(info)
        local custom_style = CopyTable(ThreatPlates.DEFAULT_SETTINGS.profile.uniqueSettings["**"])
        custom_style.Trigger.Name.Input = ""
        
        local index = SelectedListItemIndex or 1
        table_insert(Addon.db.profile.uniqueSettings, index, custom_style)
        local list_item = CreateListItem(index, custom_style)
    
        CustomStylesDialog:SortCustomStylesList() 
        CustomStylesDialog:DisplayPick(list_item)
      end,
    },
    Duplicate = {
      name = L["Duplicate"],
      order = 20,
      type = "execute",
      func = function()
        local selected_item_index = GetSelectedCustomStyle()
        local duplicated_style = CopyTable(selected_item_index)

        -- Clean trigger settings as it does not make sense to duplicate them (would create a error message and prevent pasting)
        local copy_trigger = duplicated_style.Trigger
        duplicated_style.Trigger = CopyTable(ThreatPlates.DEFAULT_SETTINGS.profile.uniqueSettings["**"].Trigger)
        duplicated_style.Trigger.Name.Input = ""
        duplicated_style.Trigger.Type = copy_trigger.Type

        -- Insert new style at position after the style that was duplicated
        table_insert(Addon.db.profile.uniqueSettings, selected_item_index, duplicated_style)
        local list_item = CreateListItem(selected_item_index, duplicated_style)

        CustomStylesDialog:SortCustomStylesList() 
        CustomStylesDialog:DisplayPick(list_item)
      end,
    },

  }

  return entry
end

local function CreateCustomStylesOptions()
  local entry = {
    Duplicate = {
      name = L["Duplicate"],
      order = 1,
      type = "execute",
      func = function()
        local selected_item_index = GetSelectedCustomStyle()
        local duplicated_style = CopyTable(selected_item_index)

        -- Clean trigger settings as it does not make sense to duplicate them (would create a error message and prevent pasting)
        local copy_trigger = duplicated_style.Trigger
        duplicated_style.Trigger = CopyTable(ThreatPlates.DEFAULT_SETTINGS.profile.uniqueSettings["**"].Trigger)
        duplicated_style.Trigger.Name.Input = ""
        duplicated_style.Trigger.Type = copy_trigger.Type

        -- Insert new style at position after the style that was duplicated
        table_insert(Addon.db.profile.uniqueSettings, selected_item_index, duplicated_style)
        local list_item = CreateListItem(selected_item_index, duplicated_style)

        CustomStylesDialog:SortCustomStylesList() 
        CustomStylesDialog:DisplayPick(list_item)
      end,
    },
    Copy = { 
      name = L["Copy"],
      order = 2,
      type = "execute",
      func = function()
        clipboard = CopyTable(SelectedListItemIndex)

        -- Clean trigger settings as it does not make sense to duplicate them (would create a error message and prevent pasting)
        local copy_trigger = clipboard.Trigger
        clipboard.Trigger = CopyTable(ThreatPlates.DEFAULT_SETTINGS.profile.uniqueSettings["**"].Trigger)
        clipboard.Trigger.Name.Input = ""
        clipboard.Trigger.Type = copy_trigger.Type
      end,
    },
    Paste = {
      name = L["Paste"],
      order = 3,
      type = "execute",
      func = function()
        -- Check for valid content could be better
        if type(clipboard) == "table" and clipboard.Trigger then
          local trigger_type = clipboard.Trigger.Type
          local triggers = (clipboard).Trigger[trigger_type].AsArray
          local check_ok = CustomStyleCheckIfTriggerIsUniqueWithErrorMessage(trigger_type, triggers, clipboard)
          if check_ok then
            local index = SelectedListItemIndex
            Addon.db.profile.uniqueSettings[index] = CopyTable(clipboard)
            clipboard = nil

            -- Update the icon and the list item for the custom style
            CustomStyleSetIcon(SelectedListItemIndex)
            local list_item = UpdateListItem(index, GetSelectedCustomStyle())
            
            CustomStylesDialog:SortCustomStylesList() 
            Addon.CustomStylesDialog:DisplayPick(list_item)

            ProcessCustomStyleUpdate()
          end
        else
          Addon.Logging.Warning(L["Nothing to paste!"])
        end
      end,
    },
    Export = {
      name = L["Export"],
      order = 4,
      type = "execute",
      func = function()
        local export_data = {
          Version = ThreatPlates.Meta("version"),
          CustomStyles = { GetSelectedCustomStyle() }
        }

        Addon.OpenExportDialogForCustomStyles(export_data)
      end,
    },
    --Spacer = GetSpacerEntry(5),
    Trigger = {
      name = L["Trigger"],
      order = 10,
      type = "group",
      inline = false,
      args = {
        NameOfCustomStyle = {
          name = L["Name"],
          type = "input",
          order = 5,
          width = "full",
          set = function(info, val)
            SetValue(info, val)

            local custom_style = GetSelectedCustomStyle()
            local list_item = GetCustomStyleListItem(custom_style)
            list_item:SetTitle(Addon.GetCustomStyleName(custom_style))
          end,
          arg = { "uniqueSettings", SelectedListItemIndex, "Name" },
        },
        TriggerType = {
          name = L["Type"],
          type = "select",
          order = 10,
          values = { Name = L["Unit"], Aura = L["Aura"], Cast = L["Cast"], Script = (Addon.db.global.ScriptingIsEnabled and L["Script"]) or nil },
          set = function(info, val)
            -- If the uses switches to a trigger that is already in use, the current custom nameplate
            -- is disabled (otherwise, if we would not switch to it, the user could not change it at all.
            local custom_style = GetSelectedCustomStyle()
            local triggers = custom_style.Trigger[val].AsArray
            local check_ok, duplicate_triggers = CustomStyleCheckIfTriggerIsUnique(val, triggers, custom_style)
            if not check_ok then
              StaticPopup_Show("TriggerAlreadyExistsDisablingIt", duplicate_triggers)
              custom_style.Enable.Never = true
            end
            custom_style.Trigger.Type = val
            CustomStyleSetIcon(SelectedListItemIndex)
            ProcessCustomStyleUpdate()
          end,
          arg = { "uniqueSettings", SelectedListItemIndex, "Trigger", "Type" },
        },
        Spacer1 = GetSpacerEntry(15),
        -- Unit Trigger
        UnitTrigger = {
          name = L["Unit (Names or NPC IDs)"],
          type = "input",
          order = 20,
          width = "full",
          desc = L["Apply these custom settings to the nameplate of a unit with a particular name or NPC ID. You can add multiple entries separated by a semicolon. You can use use * as wildcard character in names."],
          set = function(info, val)
            -- Only "*" and "." should be allowed, so check for other magic characters: ( ) . % + ? [ ^ $
            -- "." is allowed as there a units names with this character
            local position, _ = string.find(val, "[%(%)%%%+%?%[%]%^%$]")
            if position then
              Addon.Logging.Error(L["Illegal character used in Unit trigger at position: "] .. tostring(position))
            else
              CustomStyleCheckAndUpdateEntry(info, val, SelectedListItemIndex)
            end
          end,
          get = function(info)
            return GetSelectedCustomStyle().Trigger["Name"].Input or ""
          end,
          hidden = function() return GetSelectedCustomStyle().Trigger.Type ~= "Name" end,
        },
        UseTargetName = {
          name = L["Target's Name"],
          type = "execute",
          order = 30,
          func = function()
            if UnitExists("target") then
              local target_unit = UnitName("target")
              local triggers = { target_unit }
              local custom_style = GetSelectedCustomStyle()
              local check_ok = CustomStyleCheckIfTriggerIsUniqueWithErrorMessage("Name", triggers, custom_style)
              if check_ok then
                custom_style.Trigger["Name"].Input = target_unit
                custom_style.Trigger["Name"].AsArray = triggers
                CustomStyleSetIcon(SelectedListItemIndex)
                ProcessCustomStyleUpdate()
              end
            else
              Addon.Logging.Warning(L["No target found."])
            end
          end,
          hidden = function() return GetSelectedCustomStyle().Trigger.Type ~= "Name" end,
        },
        UseTargetNPCID_Name = {
          name = L["Target's NPC ID"],
          type = "execute",
          order = 31,
          width = "single",
          func = function()
            if UnitExists("target") then
              local guid = _G.UnitGUID("target")
              local _, _, _, _, _, npc_id = strsplit("-", guid or "")
              local triggers = { npc_id }
              local custom_style = GetSelectedCustomStyle()
              local check_ok = CustomStyleCheckIfTriggerIsUniqueWithErrorMessage("Name", triggers, custom_style)
              if check_ok then
                custom_style.Trigger["Name"].Input = npc_id
                custom_style.Trigger["Name"].AsArray = triggers
                CustomStyleSetIcon(SelectedListItemIndex)
                ProcessCustomStyleUpdate()
              end
            else
              Addon.Logging.Warning(L["No target found."])
            end
          end,
          hidden = function() return GetSelectedCustomStyle().Trigger.Type ~= "Name" end,
        },
        -- Aura Trigger
        AuraTrigger = {
          name = L["Auras (Name or ID)"],
          type = "input",
          order = 20,
          width = "full",
          desc = L["Apply these custom settings to the nameplate when a particular aura is present on the unit. You can add multiple entries separated by a semicolon."],
          set = function(info, val) CustomStyleCheckAndUpdateEntry(info, tonumber(val) or val, SelectedListItemIndex) end,
          get = function(info)
            return tostring(GetSelectedCustomStyle().Trigger["Aura"].Input or "")
          end,
          disabled = function() return not Addon.db.profile.AuraWidget.ON and not Addon.db.profile.AuraWidget.ShowInHeadlineView end,
          hidden = function() return GetSelectedCustomStyle().Trigger.Type ~= "Aura" end,
        },
        AuraTriggerOnlyMine = {
          name = L["Only Mine"],
          type = "toggle",
          order = 25,
          set = function(info, val)
            SetValuePlain(info, val)
            ProcessCustomStyleUpdate()
          end,
          arg = { "uniqueSettings", SelectedListItemIndex, "Trigger", "Aura", "ShowOnlyMine" },
          disabled = function() return not Addon.db.profile.AuraWidget.ON and not Addon.db.profile.AuraWidget.ShowInHeadlineView end,
          hidden = function() return GetSelectedCustomStyle().Trigger.Type ~= "Aura" end,
        },
        AuraWidgetWarning = {
          type = "description",
          order = 30,
          width = "full",
          name = L["|cffFF0000The Auras widget must be enabled (see Widgets - Auras) to use auras as trigger for custom nameplates.|r"],
          hidden = function() 
            local custom_style = GetSelectedCustomStyle()
            return (custom_style.Trigger.Type ~= "Aura") or (custom_style.Trigger.Type == "Aura" and (Addon.db.profile.AuraWidget.ON or Addon.db.profile.AuraWidget.ShowInHeadlineView)) 
          end,
        },
        -- Cast Trigger
        CastTrigger = {
          name = L["Spells (Name or ID)"],
          type = "input",
          order = 20,
          width = "full",
          desc = L["Apply these custom settings to a nameplate when a particular spell is cast by the unit. You can add multiple entries separated by a semicolon"],
          set = function(info, val) CustomStyleCheckAndUpdateEntry(info, tonumber(val) or val, SelectedListItemIndex) end,
          get = function(info)
            return tostring(GetSelectedCustomStyle().Trigger["Cast"].Input or "")
          end,
          hidden = function() return GetSelectedCustomStyle().Trigger.Type ~= "Cast" end,
        },
      },
    },
    Enable = {
      name = L["Enable"],
      type = "group",
      inline = false,
      order = 20,
      args = {
        Disable = {
          name = L["Never"],
          order = 10,
          type = "toggle",
          set = function(info, val)
            local custom_style = GetSelectedCustomStyle()
            local trigger_type = custom_style.Trigger.Type
            local triggers = custom_style.Trigger[trigger_type].AsArray

            -- Update never before check for unique trigger, otherwise it would use the old Never value
            custom_style.Enable.Never = val

            local check_ok, duplicate_triggers = CustomStyleCheckIfTriggerIsUnique(trigger_type, triggers, custom_style)
            if not check_ok then
              StaticPopup_Show("TriggerAlreadyExistsDisablingIt", table.concat(duplicate_triggers, "; "))
              custom_style.Enable.Never = true
            end

            CustomStyleSetIcon(SelectedListItemIndex)

            ProcessCustomStyleUpdate()
          end,
          arg = { "uniqueSettings", SelectedListItemIndex, "Enable", "Never" },
        },
        Spacer1 = GetSpacerEntry(15),
        FriendlyUnits = {
          name = L["Friendly Units"],
          order = 20,
          type = "toggle",
          desc = L["Enable this custom nameplate for friendly units."],
          set = function(info, val)
            GetSelectedCustomStyle().Enable.UnitReaction["FRIENDLY"] = val
            ProcessCustomStyleUpdate()
          end,
          get = function(info)
            return GetSelectedCustomStyle().Enable.UnitReaction["FRIENDLY"]
          end,
        },
        EnemyUnits = {
          name = L["Enemy Units"],
          order = 30,
          type = "toggle",
          desc = L["Enable this custom nameplate for neutral and hostile units."],
          set = function(info, val)
            local custom_style = GetSelectedCustomStyle()
            custom_style.Enable.UnitReaction["HOSTILE"] = val
            custom_style.Enable.UnitReaction["NEUTRAL"] = val
            ProcessCustomStyleUpdate()
          end,
          get = function(info)
            return GetSelectedCustomStyle().Enable.UnitReaction["HOSTILE"]
          end,
        },
        Spacer2 = GetSpacerEntry(35),
        OutOfInstances = {
          name = L["Out Of Instances"],
          order = 40,
          type = "toggle",
          desc = L["Enable this custom nameplate out of instances (in the wider game world)."],
          set = function(info, val)
            SetValuePlain(info, val);
            ProcessCustomStyleUpdate()
          end,
          arg = { "uniqueSettings", SelectedListItemIndex, "Enable", "OutOfInstances" },
        },
        InInstances = {
          name = L["In Instances"],
          order = 50,
          type = "toggle",
          desc = L["Enable this custom nameplate in instances."],
          set = function(info, val)
            SetValuePlain(info, val);
            ProcessCustomStyleUpdate()
          end,
          arg = { "uniqueSettings", SelectedListItemIndex, "Enable", "InInstances" },
        },
        Spacer3 = GetSpacerEntry(55),
        ZoneIDEnable = {
          name = L["Instance IDs"],
          order = 60,
          type = "toggle",
          set = function(info, val)
            SetValuePlain(info, val);
            ProcessCustomStyleUpdate()
          end,
          arg = { "uniqueSettings", SelectedListItemIndex, "Enable", "InstanceIDs", "Enabled" },
          disabled = function()
            return not GetSelectedCustomStyle().Enable.InInstances
          end,
        },
        ZoneIDInput = {
          name = L["Instance IDs"],
          type = "input",
          order = 70,
          width = "double",
          desc = function()
            local instance_name, _, _, _, _, _, _, instance_id = GetInstanceInfo()
            return L["|cffFFD100Current Instance:|r"] .. "\n" .. instance_name .. ": " .. instance_id .. "\n\n" .. L["Supports multiple entries, separated by commas."]
          end,
          set = function(info, val)
            SetValuePlain(info, val);
            ProcessCustomStyleUpdate()
          end,
          arg = { "uniqueSettings", SelectedListItemIndex, "Enable", "InstanceIDs", "IDs" },
          disabled = function()
            local custom_style = GetSelectedCustomStyle()
            return not custom_style.Enable.InInstances or not custom_style.Enable.InstanceIDs.Enabled
          end,
        },
      },
    },
    Appearance = {
      name = L["Appearance"],
      type = "group",
      order = 30,
      inline = false,
      args = {
        NameplateStyle = {
          name = L["Nameplate Style"],
          type = "group",
          inline = true,
          order = 10,
          args = {
            UseStyle = {
              name = L["Enable"],
              order = 10,
              type = "toggle",
              desc = L["This option allows you to control whether custom settings for nameplate style, color, transparency and scaling should be used for this nameplate."],
              set = function(info, val)
                SetValuePlain(info, val);
                ProcessCustomStyleUpdate()
              end,
              arg = { "uniqueSettings", SelectedListItemIndex, "useStyle" },
            },
            HeadlineView = {
              name = L["Healthbar View"],
              order = 20,
              type = "toggle",
              set = function(info, val)
                if val then
                  GetSelectedCustomStyle().ShowHeadlineView = false;
                  SetValuePlain(info, val);
                  ProcessCustomStyleUpdate()
                end
              end,
              arg = { "uniqueSettings", SelectedListItemIndex, "showNameplate" },
            },
            HealthbarView = {
              name = L["Headline View"],
              order = 30,
              type = "toggle",
              set = function(info, val)
                if val then
                  GetSelectedCustomStyle().showNameplate = false;
                  SetValuePlain(info, val);
                  ProcessCustomStyleUpdate()
                end
              end,
              arg = { "uniqueSettings", SelectedListItemIndex, "ShowHeadlineView" },
            },
            HideNameplate = {
              name = L["Hide Nameplate"],
              order = 40,
              type = "toggle",
              desc = L["Disables nameplates (healthbar and name) for the units of this type and only shows an icon (if enabled)."],
              set = function(info, val)
                if val then
                  local custom_style = GetSelectedCustomStyle()
                  custom_style.showNameplate = false;
                  custom_style.ShowHeadlineView = false;
                  ProcessCustomStyleUpdate()
                end
              end,
              get = function(info)
                local custom_style = GetSelectedCustomStyle()
                return not (custom_style.showNameplate or custom_style.ShowHeadlineView)
              end,
            },
          },
        },
        Appearance = {
          name = L["Appearance"],
          type = "group",
          order = 20,
          inline = true,
          args = {
            CustomColor = {
              name = L["Color"],
              order = 1,
              type = "toggle",
              desc = L["Define a custom color for this nameplate and overwrite any other color settings."],
              arg = { "uniqueSettings", SelectedListItemIndex, "useColor" },
            },
            ColorSetting = {
              name = L["Color"],
              order = 2,
              type = "color",
              disabled = function()
                return not GetSelectedCustomStyle().useColor
              end,
              get = GetColor,
              set = SetColor,
              arg = { "uniqueSettings", SelectedListItemIndex, "color" },
            },
            UseRaidMarked = {
              name = L["Color by Target Mark"],
              order = 4,
              type = "toggle",
              desc = L["Additionally color the nameplate's healthbar or name based on the target mark if the unit is marked."],
              disabled = function()
                return not GetSelectedCustomStyle().useColor
              end,
              arg = { "uniqueSettings", SelectedListItemIndex, "allowMarked" },
            },
            Spacer1 = GetSpacerEntry(10),
            CustomAlpha = {
              name = L["Transparency"],
              order = 11,
              type = "toggle",
              desc = L["Define a custom transparency for this nameplate and overwrite any other transparency settings."],
              set = function(info, val)
                SetValue(info, not val)
              end,
              get = function(info)
                return not GetValue(info)
              end,
              arg = { "uniqueSettings", SelectedListItemIndex, "overrideAlpha" },
            },
            AlphaSetting = GetTransparencyEntryDefault(12, { "uniqueSettings", SelectedListItemIndex, "alpha" }, function()
              return GetSelectedCustomStyle().overrideAlpha
            end),
            CustomScale = {
              name = L["Scale"],
              order = 21,
              type = "toggle",
              desc = L["Define a custom scaling for this nameplate and overwrite any other scaling settings."],
              set = function(info, val)
                SetValue(info, not val)
              end,
              get = function(info)
                return not GetValue(info)
              end,
              arg = { "uniqueSettings", SelectedListItemIndex, "overrideScale" },
            },
            ScaleSetting = GetScaleEntryDefault(22, { "uniqueSettings", SelectedListItemIndex, "scale" }, function()
              return GetSelectedCustomStyle().overrideScale
            end),
          },
        },
        Glow = {
          name = L["Highlight"],
          type = "group",
          order = 30,
          inline = true,
          args = {
            GlowFrame = {
              name = L["Glow Frame"],
              type = "select",
              order = 31,
              values = Addon.CUSTOM_PLATES_GLOW_FRAMES,
              desc = L["Shows a glow effect on this custom nameplate."],
              set = SetValueWidget,
              arg = { "uniqueSettings", SelectedListItemIndex, "Effects", "Glow", "Frame" },
            },
            GlowType = {
              name = L["Glow Type"],
              type = "select",
              values = Addon.GLOW_TYPES,
              order = 32,
              set = SetValueWidget,
              arg = { "uniqueSettings", SelectedListItemIndex, "Effects", "Glow", "Type" },
            },
            GlowColorEnable = {
              name = L["Glow Color"],
              type = "toggle",
              order = 33,
              set = SetValueWidget,
              arg = { "uniqueSettings", SelectedListItemIndex, "Effects", "Glow", "CustomColor" },
            },
            GlowColor = {
              name = L["Color"],
              type = "color",
              order = 34,
              width = "half",
              hasAlpha = true,
              set = function(info, r, g, b, a)
                local color = GetSelectedCustomStyle().Effects.Glow.Color
                color[1], color[2], color[3], color[4] = r, g, b, a

                Addon.Widgets:UpdateSettings("UniqueIcon")
              end,
              get = function(info)
                local color = GetSelectedCustomStyle().Effects.Glow.Color
                return unpack(color)
              end,
              arg = { "uniqueSettings", SelectedListItemIndex, "Effects", "Glow", "Color" },
            },
          }
        },
        InCombat = {
          name = L["In Combat"],
          type = "group",
          order = 40,
          inline = true,
          args = {
            ThreatGlow = {
              name = L["Threat Glow"],
              order = 41,
              type = "toggle",
              desc = L["Shows a glow based on threat level around the nameplate's healthbar (in combat)."],
              arg = { "uniqueSettings", SelectedListItemIndex, "UseThreatGlow" },
            },
            ThreatSystem = {
              name = L["Enable Threat System"],
              order = 42,
              type = "toggle",
              desc = L["In combat, use coloring, transparency, and scaling based on threat level as configured in the threat system. Custom settings are only used out of combat."],
              arg = { "uniqueSettings", SelectedListItemIndex, "UseThreatColor" },
            },
          },
        },
      },
    },
    Icon = {
      name = L["Icon"],
      type = "group",
      order = 50,
      inline = false,
      args = {
        Enable = {
          name = L["Enable"],
          type = "toggle",
          order = 1,
          desc = L["This option allows you to control whether the custom icon is hidden or shown on this nameplate."],
          arg = { "uniqueSettings", SelectedListItemIndex, "showIcon" }
        },
        AutomaticIcon = {
          name = L["Automatic Icon"],
          type = "toggle",
          order = 2,
          set = function(info, val)
            SetValue(info, val)
            CustomStyleSetIcon(SelectedListItemIndex)
            ProcessCustomStyleUpdate()
          end,
          arg = { "uniqueSettings", SelectedListItemIndex, "UseAutomaticIcon" },
          desc = L["Find a suitable icon based on the current trigger. For Unit triggers, the preview does not work. For multi-value triggers, the preview always is the icon of the first trigger entered."],
        },
        Spacer1 = GetSpacerEntry(3),
        Icon = {
          name = L["Preview"],
          type = "execute",
          width = "full",
          disabled = function() return not GetSelectedCustomStyle().showIcon or not Addon.db.profile.uniqueWidget.ON end,
          order = 4,
          image = function() return CustomStyleGetIcon(SelectedListItemIndex) end,
          imageWidth = 64,
          imageHeight = 64,
        },
        Description = {
          type = "description",
          order = 5,
          name = L["Enter an icon's name (with the *.blp ending), a spell ID, a spell name or a full icon path (using '\\' to separate directory folders)."],
          width = "full",
          hidden = function() return GetSelectedCustomStyle().UseAutomaticIcon end
        },
        SetIcon = {
          name = L["Set Icon"],
          type = "input",
          order = 6,
          disabled = function() return not GetSelectedCustomStyle().showIcon or not Addon.db.profile.uniqueWidget.ON end,
          width = "full",
          set = function(info, val) CustomStyleSetIcon(SelectedListItemIndex, val) end,
          get = function(info)
            local custom_style = GetSelectedCustomStyle()
            local val = custom_style.SpellID or custom_style.SpellName or GetValue(info)
            return tostring(val)
          end,
          arg = { "uniqueSettings", SelectedListItemIndex, "icon" },
          hidden = function() return GetSelectedCustomStyle().UseAutomaticIcon end
        },
      },
    },
    Script = {
      name = L["Scripts"],
      order = 60,
      type = "group",
      width = "full",
      inline = false,
      hidden = function() return not Addon.db.global.ScriptingIsEnabled end,
      args = {
        WidgetType = {
          name = L["Type"],
          order = 10,
          type = "select",
          values = { Standard = L["Standard"], TargetOnly = L["Target Only"], FocusOnly = L["Focus Only"], },
          arg = { "uniqueSettings", SelectedListItemIndex, "Scripts", "Type" },
        },
        WidgetFunction = {
          name = L["Function"],
          order = 20,
          type = "select",
          values = function()
            local custom_style = GetSelectedCustomStyle()
            local script_functions = CopyTable(Addon.SCRIPT_FUNCTIONS[custom_style.Scripts.Type])

            for key, function_name in pairs(script_functions) do
              local color = "ffffff"
              if key == "WoWEvent" then
                -- If no WoW event is defined, color the entry in grey
                if next(custom_style.Scripts.Code.Events) then
                  color = "00ff00"
                end
              elseif custom_style.Scripts.Code.Functions[function_name] then
                color = "00ff00"
              end
              script_functions[key] = "|cff" .. color .. function_name .. "|r"
            end

            if custom_style.Scripts.Code.Legacy and custom_style.Scripts.Code.Legacy ~= "" then
              script_functions.Legacy = "|cffff0000Legacy Code|r"
            end

            return script_functions
          end,
          get = function(info)
            local val = GetValue(info)
            local values = info.option.values()

            -- If the current value is no longer valid (LegacyCode removed or type switch), change it to some valid value
            if not values[val] then
              val = ThreatPlates.DEFAULT_SETTINGS.profile.uniqueSettings["**"].Scripts.Function
              GetSelectedCustomStyle().Scripts.Function = val
            end

            return val
          end,
          arg = { "uniqueSettings", SelectedListItemIndex, "Scripts", "Function" },
        },
        WoWEventName = {
          name = L["Event Name"],
          order = 30,
          type = "input",
          width = "double",
          set = function(info, val)
            if val ~= "" then
              val = string.upper(val)
              local custom_style = GetSelectedCustomStyle()
              if not custom_style.Scripts.Code.Events[val] then
                custom_style.Scripts.Code.Events[val] = ""
              end
            end
            SetValue(info, val)
          end,
          get = function(info)
            local wow_event
            local custom_style = GetSelectedCustomStyle()
            if custom_style.Scripts.Function == "WoWEvent" then
              wow_event = custom_style.Scripts.Event
              if not custom_style.Scripts.Code.Events[wow_event] then
                -- Script for event was deleted, so switch to another event (if available) as function still is WoWEvent
                -- Set (WoW) event to the first non-internal event or to nil
                custom_style.Scripts.Event = wow_event
              end
            end
            return wow_event
          end,
          arg = { "uniqueSettings", SelectedListItemIndex, "Scripts", "Event" },
          disabled = function() return GetSelectedCustomStyle().Scripts.Function ~= "WoWEvent" end,
        },
        Spacer1 = GetSpacerEntry(40),
        Spacer2 =  { name = "", order = 41, type = "description", width = "double", },
        WoWEventWithScript = {
          name = L["Events with Script"],
          order = 50,
          type = "select",
          width = "double",
          values = function()
            local events_with_scripts = { }
            for event, script in pairs(GetSelectedCustomStyle().Scripts.Code.Events) do
              events_with_scripts[event] = event
            end
            return events_with_scripts
          end,
          arg = { "uniqueSettings", SelectedListItemIndex, "Scripts", "Event" },
          disabled = function() 
            local custom_style = GetSelectedCustomStyle() 
            return custom_style.Scripts.Function ~= "WoWEvent" or not next(custom_style.Scripts.Code.Events) 
          end,
        },
        Spacer3 = GetSpacerEntry(55),
        Script = {
          name = L["Script"],
          order = 60,
          type = "input",
          multiline = 12,
          width = "full",
          set = function(info, val)
            -- Delete the event from the list
            if val and val:gsub("^%s*(.-)%s*$", "%1"):len() == 0 then
              val = nil
            end

            local custom_style = GetSelectedCustomStyle() 
            if custom_style.Scripts.Function == "WoWEvent" then
              custom_style.Scripts.Code.Events[custom_style.Scripts.Event] = val
            elseif custom_style.Scripts.Function == "Legacy" then
              custom_style.Scripts.Code.Legacy = val
            else
              custom_style.Scripts.Code.Functions[custom_style.Scripts.Function] = val
            end

            -- Empty input field and drop down showing the current event (as it was deleted)
            if not val then
              custom_style.Scripts.Event = nil
            end

            Addon:InitializeCustomNameplates()
            Addon.Widgets:UpdateSettings("Script")
          end,
          get = function(info)
            local custom_style = GetSelectedCustomStyle() 
            return CustomPlateGetExampleForEventScript(custom_style, custom_style.Scripts.Function)
          end,
        },
        Extend = {
          name = L["Extend"],
          order = 61,
          type = "execute",
          func = function(info)
            if not Addon.ScriptEditor then
              local frame = Addon.LibAceGUI:Create("Window")
              frame:SetTitle(L["Threat Plates Script Editor"])
              frame:SetCallback("OnClose", function(widget) frame:_Cancel() end)
              frame:SetLayout("fill")
              Addon.ScriptEditor = frame

              local group = Addon.LibAceGUI:Create("InlineGroup");
              group.frame:SetParent(frame.frame)
              group.frame:SetPoint("BOTTOMRIGHT", frame.frame, "BOTTOMRIGHT", -17, 12)
              group.frame:SetPoint("TOPLEFT", frame.frame, "TOPLEFT", 17, -10)
              group:SetLayout("fill")
              frame:AddChild(group)

              local editor = Addon.LibAceGUI:Create("MultiLineEditBox")
              editor:SetWidth(400)
              editor.button:Hide()
              editor:SetFullWidth(true)
              editor.frame:SetFrameStrata("FULLSCREEN")
              editor:SetLabel("")
              group:AddChild(editor)
              editor.frame:SetClipsChildren(true)
              frame.Editor = editor

              IndentationLib.enable(editor.editBox)

              local cancel_button = CreateFrame("Button", nil, group.frame, "UIPanelButtonTemplate")
              cancel_button:SetScript("OnClick", function() frame:_Cancel() end)
              cancel_button:SetPoint("BOTTOMRIGHT", -27, 13);
              cancel_button:SetFrameLevel(cancel_button:GetFrameLevel() + 1)
              cancel_button:SetHeight(20);
              cancel_button:SetWidth(100);
              cancel_button:SetText(L["Cancel"]);

              local close_button = CreateFrame("Button", nil, group.frame, "UIPanelButtonTemplate")
              close_button:SetScript("OnClick", function() frame:_Done() end)
              close_button:SetPoint("RIGHT", cancel_button, "LEFT", -10, 0)
              close_button:SetFrameLevel(close_button:GetFrameLevel() + 1)
              close_button:SetHeight(20);
              close_button:SetWidth(100);
              close_button:SetText(L["Done"]);

              -- CTRL + S saves and closes, ESC cancels and closes
              editor.editBox:HookScript("OnKeyDown", function(_, key)
                if IsControlKeyDown() and key == "S" then
                  frame:_Done()
                end
                if key == "ESCAPE" then
                  frame:_Cancel()
                end
              end)

              function frame._Cancel(self)
                frame:Hide()
              end

              function frame._Done(self)
                -- Delete the event from the list
                local val = Addon.ScriptEditor.Editor:GetText()
                if val and val:gsub("^%s*(.-)%s*$", "%1"):len() == 0 then
                  val = nil
                end

                local custom_style = GetSelectedCustomStyle() 
                if custom_style.Scripts.Function == "WoWEvent" then
                  custom_style.Scripts.Code.Events[custom_style.Scripts.Event] = val
                elseif custom_style.Scripts.Function == "Legacy" then
                  custom_style.Scripts.Code.Legacy = val
                else
                  custom_style.Scripts.Code.Functions[custom_style.Scripts.Function] = val
                end

                -- Empty input field and drop down showing the current event (as it was deleted)
                if not val then
                  custom_style.Scripts.Event = nil
                end

                Addon:InitializeCustomNameplates()
                Addon.Widgets:UpdateSettings("Script")

                frame:Hide()
                Addon.LibAceConfigDialog:Open(ThreatPlates.ADDON_NAME)
              end
            end

            local label
            local custom_style = GetSelectedCustomStyle() 
            if custom_style.Scripts.Function == "WoWEvent" then
              label = "WoW Event: " .. custom_style.Scripts.Event
            else
              label = "Event: " .. custom_style.Scripts.Function
            end
            Addon.ScriptEditor.Editor:SetLabel(label)

            Addon.ScriptEditor.Editor:SetText(CustomPlateGetExampleForEventScript(custom_style, custom_style.Scripts.Function))

            Addon.LibAceConfigDialog:Close(ThreatPlates.ADDON_NAME)
            Addon.ScriptEditor:Show()
          end,
        },
      },
    },
  }

  return entry
end

---------------------------------------------------------------------------------------------------
-- Filter Box
---------------------------------------------------------------------------------------------------

local function FilterCustomStyleList(self)
  SearchBoxTemplate_OnTextChanged(self)

  wipe(CustomStylesDialog.List.children)

  local filter_text = self:GetText():lower() -- or ""
  local use_filter = filter_text and filter_text ~= ""

  local custom_styles_matching_filter = {}
  if use_filter then
    for k, custom_style in ipairs(Addon.db.profile.uniqueSettings) do
      local list_item, id = GetCustomStyleListItem(custom_style)
      local item_title = list_item:GetTitle()

      if item_title:lower():find(filter_text, 1, true) then
        custom_styles_matching_filter[id] = true
      end
    end
  end
  
  for id, list_item in pairs(CustomStylesListItems) do
    if custom_styles_matching_filter[id] or not use_filter then
      table_insert(CustomStylesDialog.List.children, list_item);
      list_item.frame:Show()
    else
      list_item.frame:Hide()
    end
  end
  
  table_sort(CustomStylesDialog.List.children, function(a, b) return a.Index < b.Index end)

  CustomStylesDialog.List:DoLayout()
end

local function CreateFilterBoxPane(custom_styles_dialog)
  local filter_box = CreateFrame("EditBox", "ThreatPlatesCustomStyleFilterInput", custom_styles_dialog, "SearchBoxTemplate")
  filter_box:SetPoint("TOPRIGHT", custom_styles_dialog.ButtonDelete.frame, "BOTTOMRIGHT", 0, -PANE_PADDING)
  filter_box:SetSize(LEFT_PANE_WIDTH, 15)
  filter_box:SetFont(STANDARD_TEXT_FONT, 10, "")
  filter_box:SetScript("OnTextChanged", FilterCustomStyleList)
  filter_box:Show()

  custom_styles_dialog.FilterBox = filter_box
end

---------------------------------------------------------------------------------------------------
-- Custom Style Dialog - Main Window
--------------------------------------------------------------------------------------------------

function CustomStylesDialog:SortCustomStylesList(sort_function)
  -- Also adjust the selected item as it has a different index now
  local selected_item = GetCustomStyleListItemByIndex(SelectedListItemIndex)

    -- Sorting is only necessary, if the order is not the array order itself
  if sort_function then
    table_sort(Addon.db.profile.uniqueSettings, sort_function)
  end

  for index, custom_style in ipairs(Addon.db.profile.uniqueSettings) do
    GetCustomStyleListItem(custom_style):SetIndex(index)
  end

  table_sort(self.List.children, SortCustomStylesByIndex)

  self.List:DoLayout()

  -- Also adjust the selected item as it has a different index now
  SelectedListItemIndex = selected_item:GetIndex()

  self.List:CenterOnPicked(selected_item)

  -- local _, _, _, _, yOffset = selected_item.frame:GetPoint(1)

  -- if not yOffset then
  --   yOffset = selected_item.frame.yOffset
  -- end
  -- if yOffset then
  --   self.List:SetScrollPos(yOffset, yOffset - selected_item.frame:GetHeight())
  -- end
end

local function CreateFrameResizer(frame)
  local left, right, top, bottom = 0, 1, 0, 1
  local xOffset1, yOffset1 = 0, 1
  local xOffset2, yOffset2 = -1, 0

  local handle = CreateFrame("Button", nil, frame)
  handle:SetPoint("BOTTOMRIGHT", frame)
  handle:SetSize(25, 25)
  handle:EnableMouse()

  handle:SetScript("OnMouseDown", function()
    frame:StartSizing("BOTTOMRIGHT")
  end)

  handle:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
  end)

  local normal = handle:CreateTexture(nil, "OVERLAY")
  normal:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  normal:SetTexCoord(left, right, top, bottom)
  normal:SetPoint("BOTTOMLEFT", handle, xOffset1, yOffset1)
  normal:SetPoint("TOPRIGHT", handle, xOffset2, yOffset2)
  handle:SetNormalTexture(normal)

  local pushed = handle:CreateTexture(nil, "OVERLAY")
  pushed:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  pushed:SetTexCoord(left, right, top, bottom)
  pushed:SetPoint("BOTTOMLEFT", handle, xOffset1, yOffset1)
  pushed:SetPoint("TOPRIGHT", handle, xOffset2, yOffset2)
  handle:SetPushedTexture(pushed)

  local highlight = handle:CreateTexture(nil, "OVERLAY")
  highlight:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  highlight:SetTexCoord(left, right, top, bottom)
  highlight:SetPoint("BOTTOMLEFT", handle, xOffset1, yOffset1)
  highlight:SetPoint("TOPRIGHT", handle, xOffset2, yOffset2)
  handle:SetHighlightTexture(highlight)

  return handle
end

local function CreateDialog()
  local custom_styles_dialog = CustomStylesDialog -- CreateFrame("Frame", "ThreatPlatesCustomStylesDialog", UIParent, "PortraitFrameTemplate")
  custom_styles_dialog:SetPoint("CENTER", UIParent, "CENTER")
  custom_styles_dialog:SetSize(1020, 680)
  custom_styles_dialog:SetResizable(true)
  custom_styles_dialog:SetMovable(true)
  custom_styles_dialog:SetFrameStrata("DIALOG")
  custom_styles_dialog:EnableMouse(true)
  custom_styles_dialog:SetResizeBounds(640, 480)
  -- Workaround classic issue
  ThreatPlatesCustomStylesDialogPortrait:SetTexture([[Interface\Addons\TidyPlates_ThreatPlates\Artwork\LogoWithBackground.tga]])
  ThreatPlatesCustomStylesDialogTitleText:SetText("Threat Plates - Custom Styles")

  local r, g, b = CreateColorFromHexString("FF1F1E21"):GetRGB() -- PANEL_BACKGROUND_COLOR
  custom_styles_dialog.Bg:SetColorTexture(r, g, b, 0.8)

  custom_styles_dialog.Resizer = CreateFrameResizer(custom_styles_dialog)

  if not custom_styles_dialog.TitleContainer then
    custom_styles_dialog.TitleContainer = CreateFrame("Frame", nil, custom_styles_dialog)
    custom_styles_dialog.TitleContainer:SetAllPoints(custom_styles_dialog.TitleBg)
  end

  custom_styles_dialog.TitleContainer:SetScript("OnMouseDown", function()
    custom_styles_dialog:StartMoving()
  end)
  custom_styles_dialog.TitleContainer:SetScript("OnMouseUp", function()
    custom_styles_dialog:StopMovingOrSizing()
  end)

  -- From WeakAuras
  Addon.LibAceGUI:RegisterLayout("ThreatPlatesScrollLayout", function(content, children, skipLayoutFinished)
    local yOffset = 0
    local scrollTop, scrollBottom = content.obj:GetScrollPos()
    for i = 1, #children do
      local child = children[i]
      local frame = child.frame;

      if not child.dragging then
        local frameHeight = (frame.height or frame:GetHeight() or 0);
        frame:ClearAllPoints();
        if (-yOffset + frameHeight > scrollTop and -yOffset - frameHeight < scrollBottom) then
          frame:Show();
          frame:SetPoint("LEFT", content);
          frame:SetPoint("RIGHT", content);
          frame:SetPoint("TOP", content, "TOP", 0, yOffset)
        else
          frame:Hide();
          frame.yOffset = yOffset
        end
        yOffset = yOffset - (frameHeight + 2);
      end

      if child.DoLayout then
        child:DoLayout()
      end

    end
    if(content.obj.LayoutFinished and not skipLayoutFinished) then
      content.obj:LayoutFinished(nil, yOffset * -1)
    end
  end)

  CreateToolbarPane(custom_styles_dialog)
  CreateListPane(custom_styles_dialog)
  CreateFilterBoxPane(custom_styles_dialog)
  CreateOptionsPane(custom_styles_dialog)
  --CreateNewCustomStylePane(custom_styles_dialog)

  local function DialogOnSizeChangedHandler(self, _, _)
    local button_width = (self.Options.frame:GetSize() - 3 * PANE_PADDING) / 4
    self.ButtonMoveUp.frame:SetWidth(button_width)
    self.ButtonMoveDown.frame:SetWidth(button_width)
    self.ButtonSortAtoZ.frame:SetWidth(button_width)
    self.ButtonSortZtoA.frame:SetWidth(button_width)
  end

  custom_styles_dialog:SetScript("OnSizeChanged", DialogOnSizeChangedHandler)
  DialogOnSizeChangedHandler(custom_styles_dialog)
end

function CustomStylesDialog:DisplayPick(selected_item)
  for id, list_item in pairs(CustomStylesListItems) do
    list_item:ClearPick()
  end
  
  if type(selected_item) == "number" then
    selected_item = GetCustomStyleListItemByIndex(selected_item)
  end
  
  if selected_item then
    selected_item:Pick()
    SelectedListItemIndex = selected_item:GetIndex()

    local _, _, _, _, yOffset = selected_item.frame:GetPoint(1)
    if not yOffset then
      yOffset = selected_item.frame.yOffset
    end
    if yOffset then
      self.List:SetScrollPos(yOffset, yOffset - 32)
    end

    self.CustomStylesOptionsTable.args = CreateCustomStylesOptions()
    Addon.LibAceConfigDialog:Open(DIALOG_NAME, CustomStylesDialog.Options)
  else
    self.CustomStylesOptionsTable.args = nil
    Addon.LibAceConfigDialog:Open(DIALOG_NAME, CustomStylesDialog.Options)
  end
end

function CustomStylesDialog:Initialize()
    -- Initialize the dialog with the current custom styles
  wipe(CustomStylesListItems)

  -- Iterate the table in reverse order, to savely delete all entries
  local list_entries = self.List.children
  for index = #list_entries, 1, -1 do
    list_entries[index]:OnRelease()
    list_entries[index] = nil
  end

  for index, custom_style in ipairs(Addon.db.profile.uniqueSettings) do
    CreateListItem(index, custom_style)
  end
  self.List:DoLayout()
end

Addon.CustomStylesDialog = CustomStylesDialog

function CustomStylesDialog:ShowDialog()
  if not self.List then
    CreateDialog()
  end

  self:Initialize()
  self:DisplayPick(SelectedListItemIndex)
  self:Show()
end