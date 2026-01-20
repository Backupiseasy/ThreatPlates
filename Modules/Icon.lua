---------------------------------------------------------------------------------------------------
-- Module: Icon
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs

-- ThreatPlates APIs

local masque_groups = {}

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: 

---------------------------------------------------------------------------------------------------
-- Module Setup
---------------------------------------------------------------------------------------------------
local IconModule = Addon.Icon

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local UseMasque, UseBorderlessIcons

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------

-- Callbacks for changes in Masque settings
-- local function LibMasqueCallback(...) --self, Addon, Group, SkinID, Backdrop, Shadow, Gloss, Colors, Disabled)
--   Addon.Widgets:UpdateSettings("UniqueIcon")
-- end

function IconModule.RegisterMasqueGroup(widget, name)
  if UseMasque then
    local masque_group = Addon.LibMasque:Group(Addon.ADDON_NAME, name)
    masque_group:RegisterCallback(function() Addon.Widgets:UpdateSettings(widget.Name) end)
    masque_groups[widget] = masque_group
  end
end

local function GetIconTexture(self)
  return (UseMasque and self.icon) or self
end

local function SetIconTexture(self, texture)
  local icon_texture = self:GetIconTexture()

  icon_texture:SetTexture(texture)

  if UseBorderlessIcons then
    icon_texture:SetTexCoord(.08, .92, .08, .92)
  else
    icon_texture:SetTexCoord(0, 1, 0, 1)
  end

  if UseMasque then
    self.MasqueGroup:ReSkin(self)
  end
end

local function GetParentFrame(self)
  return (UseMasque and self) or self:GetParent()
end

local function SetIconTexture(self, texture_info, unitid)
  local icon = (UseMasque and self.icon) or self
  Addon:SetIconTexture(icon, texture_info, unitid)
end

-- local function ReSkin(self)
--   if UseMasque then
--     self.MasqueGroup:ReSkin(self)
--   end
-- end

-- * Icon is an potentical candidate for converting it to a class, I guess
function IconModule.CreateIcon(widget, parent)
  local icon
  if UseMasque then
    icon = _G.CreateFrame("Button", nil, parent, "ActionButtonTemplate")
    icon:EnableMouse(false)
    
    icon.icon = icon:CreateTexture(nil, "BACKGROUND")
    icon.icon:SetAllPoints()

    local masque_group = masque_groups[widget]
    icon.MasqueGroup = masque_group
    masque_group:AddButton(icon)
  else
    icon = parent:CreateTexture(nil, "BACKGROUND")
  end

  icon.SetIconTexture = SetIconTexture
  icon.GetIconTexture = GetIconTexture
  icon.GetParentFrame = GetParentFrame
  icon.SetTPIconTexture = SetIconTexture
  --icon.ReSkin = ReSkin

  return icon
end

function IconModule.UpdateSettings()
  UseMasque = Addon.db.profile.Appearance.UseMasque and Addon.LibMasque
  UseBorderlessIcons = Addon.db.profile.Appearance.UseBorderlessIcons
end