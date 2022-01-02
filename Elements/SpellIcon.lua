---------------------------------------------------------------------------------------------------
-- Element: Spell Icon
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs

-- ThreatPlates APIs
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------
local Element = Addon.Elements.NewElement("SpellIcon")

---------------------------------------------------------------------------------------------------
-- Core element code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
  local spell_icon = tp_frame.visual.Castbar:CreateTexture(nil, "OVERLAY", nil, 7)

  tp_frame.visual.SpellIcon = spell_icon
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
--function Element.UnitAdded(tp_frame)
--end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.UnitRemoved(tp_frame)
--end

---- Called in processing event: UpdateStyle in Nameplate.lua
function Element.UpdateStyle(tp_frame, style, plate_style)
  local spell_icon, spell_icon_style = tp_frame.visual.SpellIcon, style.spellicon

  if plate_style == "None" or not spell_icon_style.show then
    spell_icon:Hide()
    return
  end

  spell_icon:SetTexture(spell_icon_style.texture)
  spell_icon:SetSize(spell_icon_style.width, spell_icon_style.height)
  spell_icon:ClearAllPoints()
  spell_icon:SetPoint(spell_icon_style.anchor, tp_frame, spell_icon_style.anchor, spell_icon_style.x, spell_icon_style.y)
  spell_icon:Show()
end

--function Element.UpdateSettings()
--end

