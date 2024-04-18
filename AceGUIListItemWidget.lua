--------------------------------------------------------------------------------------------------
-- AceGUI Widget: Ttem for list box
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Type, Version = "ThreatPlatesListItem", 1

local LibAceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not LibAceGUI or (LibAceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs

-- WoW APIs

-- ThreatPlates APIs
local L = Addon.ThreatPlates.L


---------------------------------------------------------------------------------------------------
-- Constants and variables
---------------------------------------------------------------------------------------------------
local ListItemTooltip = CreateFrame("GameTooltip", "ThreatPlatesListItemTooltip", UIParent, "GameTooltipTemplate")

---------------------------------------------------------------------------------------------------
-- Tooltip functions
---------------------------------------------------------------------------------------------------

local function HideTooltip(self)
  ListItemTooltip:Hide()
end

local function ShowTooltip(self, description)
  ListItemTooltip:SetOwner(self, "ANCHOR_NONE")
  ListItemTooltip:ClearAllPoints()
  ListItemTooltip:SetPoint("LEFT", self, "RIGHT")
  ListItemTooltip:ClearLines()

  for line_no, line_text in ipairs(description) do
    if line_no == 1 then
      ListItemTooltip:AddLine("|cFFFFD100" .. line_text .. "|r")
    else
      ListItemTooltip:AddLine(line_text, 1, 1, 1, 1)
    end
  end

  -- local line = 1
  -- for i,v in pairs(description) do
  --   if(type(v) == "string") then
  --     if(line > 1) then
  --       GameTooltip:AddLine(v, 1, 1, 1, 1);
  --     else
  --       GameTooltip:AddLine(v);
  --     end
  --   elseif(type(v) == "table") then
  --     if(i == 1) then
  --       GameTooltip:AddDoubleLine(v[1], v[2]..(v[3] and (" |T"..v[3]..":12:12:0:0:64:64:4:60:4:60|t") or ""));
  --     else
  --       GameTooltip:AddDoubleLine(v[1], v[2]..(v[3] and (" |T"..v[3]..":12:12:0:0:64:64:4:60:4:60|t") or ""),
  --                                 1, 1, 1, 1, 1, 1, 1, 1);
  --     end
  --   end
  --   line = line + 1;
  -- end

  ListItemTooltip:Show()
end

---------------------------------------------------------------------------------------------------
-- Methods
---------------------------------------------------------------------------------------------------
local Methods = {
  ["OnAcquire"] = function(self)
		self:SetWidth(1000)
    self:SetHeight(32)
  end,
  ["OnRelease"] = function(self)
    self:Enable()
    self.frame:Hide()
    self.title:Hide()
    self.frame:SetScript("OnClick", nil);
    self.frame:ClearAllPoints()
    --self.frame = nil
    --self.Data = nil
  end,  
  ["Initialize"] = function(self, dialog)
    self.Dialog = dialog
    self.Description = {}

    function self.OnClick(frame, mouseButton)
      self.Dialog:DisplayPick(self)
    end

    self.frame:SetScript("OnClick", self.OnClick)
    self.frame:EnableKeyboard(false)
    self.frame:Hide()
    
    self:Enable()
  end,  
  ["Enable"] = function(self)
    self.frame:Enable()
    self.background:Show()
  end,
  ["Disable"] = function(self)
    self.frame:Disable()
    self.background:Hide()
  end,
  ["IsEnabled"] = function(self)
    return self.frame:IsEnabled()
  end,
  -- ["SetData"] = function(self, custom_style)
  --   self.Data = custom_style 
  -- end,
  ["SetCustomStyle"] = function(self, custom_style)
    local custom_style_name = Addon.GetCustomStyleName(custom_style)
    self:SetTitle(custom_style_name)
    local icon_texture
    if custom_style.UseAutomaticIcon then
      self:SetIcon(custom_style.AutomaticIcon or custom_style.icon)
    elseif custom_style.icon then
      self:SetIcon(custom_style.icon)
    else
      self:SetIcon("INV_Misc_QuestionMark.blp")
    end

    local tooltip = CreateFrame("GameTooltip", "ThreatPlatesListItemTooltip", UIParent, "GameTooltipTemplate")

    self:SetDescription(custom_style_name, 
      L["Trigger Type: "] .. Addon.GetCustomStyleTriggerType(custom_style))

    self.frame:SetScript("OnEnter", function() ShowTooltip(self.frame, self.Description) end)
    self.frame:SetScript("OnLeave", HideTooltip)
  end,
  -- ["GetData"] = function(self)
  --   return self.Data
  -- end,
  ["SetIndex"] = function(self, index)
    self.Index = index
  end,
  ["GetIndex"] = function(self)
    return self.Index
  end,
  ["SetTitle"] = function(self, title)
    self.title:SetText(title)
  end,
  -- ["GetTitle"] = function(self)
  --   return self.title:GetText()
  -- end,
  ["SetDescription"] = function(self, ...)
    self.Description = {...}
  end,  
  ["Pick"] = function(self)
    self.frame:LockHighlight()
  end,
  ["ClearPick"] = function(self)
    self.frame:UnlockHighlight()
  end,
  ["SetIcon"] = function(self, texture_asset)    
    local file_extension = type(texture_asset) == "string" and texture_asset:sub(-4)
    if (file_extension == ".blp" or file_extension == ".tga") then
      self.icon:SetTexture("Interface\\Icons\\" .. texture_asset)
    else
      self.icon:SetTexture(texture_asset)
    end
    self.icon:Show()
  end,
  -- ["SetDefaultIcon"] = function(self)
  --   self:SetIcon("INV_Misc_QuestionMark.blp")
  -- end,  
}

local function Constructor()
  local name = "ThreatPlatesListItem" .. LibAceGUI:GetNextWidgetNum(Type)

  local frame = CreateFrame("Button", name, UIParent, "OptionsListButtonTemplate")
  frame:SetWidth(1000)
  frame:SetHeight(32)

  local offset = CreateFrame("Frame", nil, frame)
  offset:SetPoint("TOP", frame, "TOP")
  offset:SetPoint("BOTTOM", frame, "BOTTOM")
  offset:SetPoint("LEFT", frame, "LEFT")
  offset:SetWidth(1)

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight2.blp")
  background:SetBlendMode("ADD")
  background:SetVertexColor(0.5, 0.5, 0.5, 0.25)
  background:SetAllPoints()

  local icon = frame:CreateTexture(nil, "OVERLAY")
  icon:SetWidth(32)
  icon:SetHeight(32)
  icon:SetPoint("LEFT", offset, "RIGHT")

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetHeight(14)
  title:SetJustifyH("LEFT")
  title:SetPoint("TOP", frame, "TOP", 0, -2)
  title:SetPoint("LEFT", icon, "RIGHT", 2, 0)
  title:SetPoint("RIGHT", frame, "RIGHT")

  local widget = {
    frame = frame,
    background = background,
    offset = offset,
    title = title,
    icon = icon,
  }

  for method, func in pairs(Methods) do
    widget[method] = func
  end

  -- frame.Data = {}
  -- button.icon

  return LibAceGUI:RegisterAsWidget(widget)
end

LibAceGUI:RegisterWidgetType(Type, Constructor, Version)