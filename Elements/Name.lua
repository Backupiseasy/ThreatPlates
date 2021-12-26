---------------------------------------------------------------------------------------------------
-- Element: Name
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs

-- WoW APIs

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local PlatesByUnit = Addon.PlatesByUnit
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish
local Font = Addon.Font

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local Settings
local ModeSettings = {}

---------------------------------------------------------------------------------------------------
-- Element code
---------------------------------------------------------------------------------------------------
local Element = Addon.Elements.NewElement("Name")

---------------------------------------------------------------------------------------------------
-- Core element code
---------------------------------------------------------------------------------------------------

-- Called in processing event: NAME_PLATE_CREATED
function Element.Created(tp_frame)
  local name_text = tp_frame.visual.textframe:CreateFontString(nil, "ARTWORK")
  -- At least font must be set as otherwise it results in a Lua error when UnitAdded with SetText is called
  name_text:SetFont("Fonts\\FRIZQT__.TTF", 11)
  name_text:SetWordWrap(false) -- otherwise text is wrapped when plate is scaled down

  tp_frame.visual.NameText = name_text
end

-- Called in processing event: NAME_PLATE_UNIT_ADDED
function Element.UnitAdded(tp_frame)
  local name_text = tp_frame.visual.NameText
  local unit = tp_frame.unit

  name_text:SetText(unit.name)
end

-- Called in processing event: NAME_PLATE_UNIT_REMOVED
--function Element.UnitRemoved(tp_frame)
--end

---- Called in processing event: UpdateStyle in Nameplate.lua
function Element.UpdateStyle(tp_frame, style, plate_style)
  local name_text = tp_frame.visual.NameText
  local db = ModeSettings[tp_frame.PlateStyle]

  if plate_style == "None" or not db.Enabled then
    name_text:Hide()
    return
  end

  name_text:SetSize(db.Font.Width, db.Font.Height)
  Font:UpdateText(tp_frame, name_text, db)

  name_text:Show()
end

function Element.UpdateSettings()
  Settings = TidyPlatesThreat.db.profile.Name

  ModeSettings["HealthbarMode"] = Settings.HealthbarMode

  -- Settings for name mode are not complete, so complete them with the corresponding setttings from the healthbar mode
  ModeSettings["NameMode"] = Addon.CopyTable(Settings.NameMode)
  ModeSettings["NameMode"].Font.Typeface = Settings.HealthbarMode.Font.Typeface
  ModeSettings["NameMode"].Font.flags = Settings.HealthbarMode.Font.flags
  ModeSettings["NameMode"].Font.Shadow = Settings.HealthbarMode.Font.Shadow
  ModeSettings["NameMode"].Font.Width = Settings.HealthbarMode.Font.Width
  ModeSettings["NameMode"].Font.Height = Settings.HealthbarMode.Font.Height

  -- Update TargetArt widget as it depends on some settings here
  Addon.Widgets:UpdateSettings("TargetArt")
end

local function UNIT_NAME_UPDATE(unitid)
  local tp_frame = PlatesByUnit[unitid]
  if tp_frame and tp_frame.Active then
    tp_frame.visual.NameText:SetText(tp_frame.unit.name)
  end
end

SubscribeEvent(Element, "UNIT_NAME_UPDATE", UNIT_NAME_UPDATE)