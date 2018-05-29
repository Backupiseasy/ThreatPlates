---------------------------------------------------------------------------------------------------
-- Class Icon Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Module = Addon:NewModule("ClassIcon")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local PATH = "Interface\\AddOns\\TidyPlates_ThreatPlates\\Widgets\\ClassIconWidget\\"
-- local Masque = LibStub("Masque", true)
-- local group

---------------------------------------------------------------------------------------------------
-- Module functions for creation and update
---------------------------------------------------------------------------------------------------

function Module:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code III
  --------------------------------------
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 7)
  widget_frame.Icon = widget_frame:CreateTexture(nil, "OVERLAY")
  widget_frame.Icon:SetAllPoints(widget_frame)

  -- if Masque then
  -- 	if not group then
  --  		group = Masque:Group("TidyPlatesThreat")
  -- 	end
  -- 	--Masque:Register("TidyPlatesThreat", Reskin)
  -- 	group:AddButton(frame)
  -- end

  --------------------------------------
  -- End Custom Code
  return widget_frame
end

function Module:IsEnabled()
  return TidyPlatesThreat.db.profile.classWidget.ON or TidyPlatesThreat.db.profile.classWidget.ShowInHeadlineView
end

function Module:EnabledForStyle(style, unit)
  if unit.type ~= "PLAYER" then return end

  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return TidyPlatesThreat.db.profile.classWidget.ShowInHeadlineView
  elseif style ~= "etotem" then
    return TidyPlatesThreat.db.profile.classWidget.ON
  end
end

function Module:OnUnitAdded(widget_frame, unit)
  -- Caching maybe for unknown player (no name update yet?)
  -- if db.cacheClass and unit.guid then
  -- 	-- local _, Class = GetPlayerInfoByGUID(unit.guid)
  -- 	if not db.cache[unit.name] then
  -- 		db.cache[unit.name] = unit.class
  -- 		class = unit.class
  -- 	else
  -- 		class = db.cache[unit.name]
  -- 	end
  -- else

  local db = TidyPlatesThreat.db.profile
  if (unit.reaction == "HOSTILE" and db.HostileClassIcon) or (unit.reaction == "FRIENDLY" and db.friendlyClassIcon) then
    db = db.classWidget

    -- Updates based on settings / unit style
    self:OnUpdateStyle(widget_frame, unit)

    -- Updates based on settings
    widget_frame:SetSize(db.scale, db.scale)

    -- Updates based on unit status
    widget_frame.Icon:SetTexture(PATH .. db.theme .."\\" .. unit.class)

    -- if Masque then
    -- 	group = Masque:Group("TidyPlatesThreat")
    -- 	group:ReSkin(frame)
    -- end

    widget_frame:Show()
  else
    widget_frame:Hide()
  end
end

function Module:OnUpdateStyle(widget_frame, unit)
  local db = TidyPlatesThreat.db.profile.classWidget
  if unit.style == "NameOnly" or unit.style == "NameOnly-Unique" then
    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x_hv, db.y_hv)
  else
    widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
  end
end