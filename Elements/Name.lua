---------------------------------------------------------------------------------------------------
-- Element: Name
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local table_concat = table.concat
local string_len  = string.len

-- WoW APIs

-- ThreatPlates APIs
local SubscribeEvent, PublishEvent = Addon.EventService.Subscribe, Addon.EventService.Publish
local Localization, Font = Addon.Localization, Addon.Font
local SplitByWhitespace = Addon.SplitByWhitespace
local TextCache = Addon.Cache.Texts

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
  local unit = tp_frame.unit
  
  local unit_name = Localization:TransliterateCyrillicLetters(unit.name)
  
  -- Full names in headline view, otherwise
  if unit.type ~= "PLAYER" and tp_frame.PlateStyle ~= "NameMode" then 
    local db = ModeSettings[tp_frame.PlateStyle]
    local name_setting = (unit.reaction == "FRIENDLY" and db.AbbreviationForFriendlyUnits) or db.AbbreviationForEnemyUnits
    if name_setting ~= "FULL" then
      -- Use unit name here to not use the transliterated text
      local cache_entry = TextCache[unit.name]

      local abbreviated_name = cache_entry.Abbreviation
      if not abbreviated_name then
        local parts, count = SplitByWhitespace(unit_name)
        if name_setting == "INITIALS" then
          local initials = {}
          for i, p in pairs(parts) do
            if i == count then
              initials[i] = p
            else
              initials[i] = string.sub(p, 0, 1)
            end
          end
          abbreviated_name = table_concat(initials, ". ")
        else -- LAST
          abbreviated_name = parts[count]
        end

        cache_entry.Abbreviation = abbreviated_name
      end

      unit_name = abbreviated_name
    end
  end

  tp_frame.visual.NameText:SetText(unit_name)
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
  Settings =  Addon.db.profile.Name

  ModeSettings["HealthbarMode"] = Settings.HealthbarMode

  -- Settings for name mode are not complete, so complete them with the corresponding setttings from the healthbar mode
  ModeSettings["NameMode"] = Addon.CopyTable(Settings.NameMode)
  ModeSettings["NameMode"].Font.Typeface = Settings.HealthbarMode.Font.Typeface
  ModeSettings["NameMode"].Font.flags = Settings.HealthbarMode.Font.flags
  ModeSettings["NameMode"].Font.Shadow = Settings.HealthbarMode.Font.Shadow
  ModeSettings["NameMode"].Font.Width = Settings.HealthbarMode.Font.Width
  ModeSettings["NameMode"].Font.Height = Settings.HealthbarMode.Font.Height

  -- Clear cache for texts as e.g., abbreviation mode might have changed
  wipe(TextCache)

  -- Update TargetArt widget as it depends on some settings here
  Addon.Widgets:UpdateSettings("TargetArt")
end

local function UNIT_NAME_UPDATE(unitid)
  local tp_frame = Addon:GetThreatPlateForUnit(unitid)
  if tp_frame then
    tp_frame.visual.NameText:SetText(tp_frame.unit.name)
  end
end

SubscribeEvent(Element, "UNIT_NAME_UPDATE", UNIT_NAME_UPDATE)