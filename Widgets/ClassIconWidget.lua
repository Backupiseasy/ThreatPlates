---------------------------------------------------------------------------------------------------
-- Class Icon Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Widget = Addon.Widgets:NewWidget("ClassIcon")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs

-- ThreatPlates APIs
local RegisterMasqueGroup, IconCreateIcon = Addon.Icon.RegisterMasqueGroup, Addon.Icon.CreateIcon
local IsSecretValueTP = Addon.IsSecretValue

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame

-- local Masque = LibStub("Masque", true)
-- local group

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:OnEnable()
  RegisterMasqueGroup(self, "Class Icon")
  Addon.EventService.SubscribeConfig(self, "classWidget", function(p) self:OnConfigChanged(p) end)
end

function Widget:OnDisable()
  Addon.EventService.UnsubscribeAllConfig(self)
end

function Widget:OnConfigChanged(changedPath)
  Addon:ScheduleRepaint()
end

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = _G.CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code III
  --------------------------------------
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
  widget_frame.Icon = IconCreateIcon(self, widget_frame)
  widget_frame.Icon:SetAllPoints()
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  local db = Addon.db.profile.classWidget
  return db.ON or db.ShowInHeadlineView
end

function Widget:EnabledForStyle(style, unit)
  if unit.type ~= "PLAYER" then return false end

  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return Addon.db.profile.classWidget.ShowInHeadlineView
  elseif style ~= "etotem" then
    return Addon.db.profile.classWidget.ON
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  -- Blizzard returns class as a secret value for hostile players in Arenas/Battlegrounds (Patch
  -- 12.1) - concatenating it below would produce a secret icon_id, which then throws when used as
  -- a table key in Addon:GetIconTexture. Nothing to display in that case, so just hide.
  if IsSecretValueTP(unit.class) then
    widget_frame:Hide()
    return
  end

  local db = Addon.db.profile

  if (unit.reaction == "HOSTILE" and db.HostileClassIcon) or (unit.reaction == "FRIENDLY" and db.friendlyClassIcon) then
    db = db.classWidget

    -- Updates based on settings / unit style
    if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
      widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x_hv, db.y_hv)
    else
      widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
    end

    widget_frame:SetSize(db.scale, db.scale)
    widget_frame.Icon:SetIconTexture("Class." .. unit.class, unit.unitid)

    widget_frame:Show()
  else
    widget_frame:Hide()
  end
end