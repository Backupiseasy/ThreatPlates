---------------------------------------------------------------------------------------------------
-- Element: Target Marker (Raid Target Marker)
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs
local GetRaidTargetIndex = GetRaidTargetIndex

-- ThreatPlates APIs
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish

-- Raid Icon Reference
local RAID_ICON_LIST = { "STAR", "CIRCLE", "DIAMOND", "TRIANGLE", "MOON", "SQUARE", "CROSS", "SKULL" }
local RAID_ICON_COORDINATE = {
  ["STAR"] = { x = 0, y =0 },
  ["CIRCLE"] = { x = 0.25, y = 0 },
  ["DIAMOND"] = { x = 0.5, y = 0 },
  ["TRIANGLE"] = { x = 0.75, y = 0},
  ["MOON"] = { x = 0, y = 0.25},
  ["SQUARE"] = { x = .25, y = 0.25},
  ["CROSS"] = { x = .5, y = 0.25},
  ["SKULL"] = { x = .75, y = 0.25},
}

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------

local Element = Addon.Elements.NewElement("TargetMarker")

function Element.TargetMarkerUpdate(tp_frame)
  local unit, style = tp_frame.unit, tp_frame.style

  -- Bug https://wow.curseforge.com/projects/tidy-plates-threat-plates/issues/304 should be fixed with this
  -- as unit.TargetMarker should only have valid values (1-8)
  local target_marker = tp_frame.visual.TargetMarker
  if unit.TargetMarker and style.raidicon.show then
    local icon_coord = RAID_ICON_COORDINATE[unit.TargetMarker]

    target_marker:SetTexCoord(icon_coord.x, icon_coord.x + 0.25, icon_coord.y,  icon_coord.y + 0.25)
    target_marker:Show()
  else
    target_marker:Hide()
  end
end

-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
  local target_marker = tp_frame.visual.textframe:CreateTexture(nil, "OVERLAY", nil, 7)
  target_marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  tp_frame.visual.TargetMarker = target_marker
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
Element.UnitAdded = Element.TargetMarkerUpdate

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.UnitRemoved(tp_frame)
--  tp_frame.visual.ThreatGlow:Hide() -- done in UpdateStyle
--end

function Element.UpdateStyle(tp_frame, style, plate_style)
  local target_marker = tp_frame.visual.TargetMarker
  local target_marker_style = style.raidicon

  if plate_style == "None" or not target_marker_style.show then
    target_marker:Hide()
    return
  end

  target_marker:SetSize(target_marker_style.width, target_marker_style.height)
  target_marker:ClearAllPoints()
  target_marker:SetPoint(target_marker_style.anchor, tp_frame, target_marker_style.anchor, target_marker_style.x, target_marker_style.y)
  target_marker:SetShown(tp_frame.unit.TargetMarker)
end

SubscribeEvent(Element, "TargetMarkerUpdate", Element.TargetMarkerUpdate)
