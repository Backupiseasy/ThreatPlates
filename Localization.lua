local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local format = format

-- ThreatPlates APIs
local TextCache = Addon.Cache.Texts

---------------------------------------------------------------------------------------------------
-- Default fonts by country
---------------------------------------------------------------------------------------------------

Addon.DEFAULT_FONT = "Cabin"
Addon.DEFAULT_SMALL_FONT = "Arial Narrow"

local client_locale = GetLocale()
local MAP_FONT = {
  koKR = { -- Korrean
    DefaultFont = "기본 글꼴",      -- "2002"
    DefaultSmallFont = "기본 글꼴", -- "2002"
  },
  zhCN = { -- Simplified Chinese
    DefaultFont = "默认",      -- "AR ZhongkaiGBK Medium"
    DefaultSmallFont = "默认", -- "AR ZhongkaiGBK Medium"
  },
  zhTW = { -- Traditional Chinese
    DefaultFont = "傷害數字",       -- "AR Kaiti Medium B5"
    DefaultSmallFont = "傷害數字",  -- "AR Kaiti Medium B5"
  },
  ruRU = { -- Russian
    DefaultFont = "Friz Quadrata TT", -- "FrizQuadrataCTT"
    DefaultSmallFont = "Arial Narrow",
  }
}

if MAP_FONT[client_locale] then
  Addon.DEFAULT_FONT = MAP_FONT[client_locale].DefaultFont
  Addon.DEFAULT_SMALL_FONT = MAP_FONT[client_locale].DefaultSmallFont
end

---------------------------------------------------------------------------------------------------
-- Totem names
---------------------------------------------------------------------------------------------------

local TOTEM_CREATURE_TYPE = {
  enUS = "Totem",
  deDE = "Totem",
  esES = "Tótem",
  esMX = "Totém",
  frFR = "Totem",
  itIT = "Totem",
  ptBR = "Totem",
  ruRU = "Тотем",
  koKR = "토템",
  zhCN = "图腾",
  zhTW = "圖騰",
}

Addon.TotemCreatureType = TOTEM_CREATURE_TYPE[client_locale] or TOTEM_CREATURE_TYPE.enUS

---------------------------------------------------------------------------------------------------
-- Determine correct number units: Western or East Asian Nations (CJK)
---------------------------------------------------------------------------------------------------

local TruncateWestern = function(value)
	local abs_value = (value >= 0 and value) or (-1 * value)

  if abs_value >= 1e6 then
    return format("%.1fm", value / 1e6)
  elseif abs_value >= 1e4 then
    return format("%.1fk", value / 1e3)
  else
    return format("%i", value)
  end
end

local MAP_LOCALE_TO_UNIT_SYMBOL = {
  koKR = { -- Korrean
    Unit_1K = "천",
    Unit_10K = "만",
    Unit_1B = "억",
  },
  zhCN = { -- Simplified Chinese
    Unit_1K = "千",
    Unit_10K = "万",
    Unit_1B = "亿",
  },
  zhTW = { -- Traditional Chinese
    Unit_1K = "千",
    Unit_10K = "萬",
    Unit_1B = "億",
  },
}

local TruncateEastAsian = TruncateWestern

if MAP_LOCALE_TO_UNIT_SYMBOL[client_locale] then
  local Format_Unit_1K = "%.1f" .. MAP_LOCALE_TO_UNIT_SYMBOL[client_locale].Unit_1K
  local Format_Unit_10K = "%.1f" .. MAP_LOCALE_TO_UNIT_SYMBOL[client_locale].Unit_10K
  local Format_Unit_1B = "%.1f" .. MAP_LOCALE_TO_UNIT_SYMBOL[client_locale].Unit_1B

  TruncateEastAsian = function(value)
    local abs_value = (value > 0 and value) or (-1 * value)

    if abs_value >= 1e8 then
      return format(Format_Unit_1B, value / 1e8)
    elseif abs_value >= 1e4 then
      return format(Format_Unit_10K, value / 1e4)
    elseif abs_value >= 1e3 then
      return format(Format_Unit_1K, value / 1e3)
    else
      return format("%i", value)
    end
  end
end

Addon.Truncate = TruncateWestern

---------------------------------------------------------------------------------------------------
-- Transliteration
---------------------------------------------------------------------------------------------------

local TRANSLITERATE_CHARS = {
  ["А"] = "A", ["а"] = "a", ["Б"] = "B", ["б"] = "b", ["В"] = "V", ["в"] = "v", ["Г"] = "G", ["г"] = "g", ["Д"] = "D", ["д"] = "d", ["Е"] = "E",
  ["е"] = "e", ["Ё"] = "e", ["ё"] = "e", ["Ж"] = "Zh", ["ж"] = "zh", ["З"] = "Z", ["з"] = "z", ["И"] = "I", ["и"] = "i", ["Й"] = "Y", ["й"] = "y",
  ["К"] = "K", ["к"] = "k", ["Л"] = "L", ["л"] = "l", ["М"] = "M", ["м"] = "m", ["Н"] = "N", ["н"] = "n", ["О"] = "O", ["о"] = "o", ["П"] = "P",
  ["п"] = "p", ["Р"] = "R", ["р"] = "r", ["С"] = "S", ["с"] = "s", ["Т"] = "T", ["т"] = "t", ["У"] = "U", ["у"] = "u", ["Ф"] = "F", ["ф"] = "f",
  ["Х"] = "Kh", ["х"] = "kh", ["Ц"] = "Ts", ["ц"] = "ts", ["Ч"] = "Ch", ["ч"] = "ch", ["Ш"] = "Sh", ["ш"] = "sh", ["Щ"] = "Shch",	["щ"] = "shch",
  ["Ъ"] = "", ["ъ"] = "", ["Ы"] = "Y", ["ы"] = "y", ["Ь"] = "", ["ь"] = "", ["Э"] = "E", ["э"] = "e", ["Ю"] = "Yu", ["ю"] = "yu", ["Я"] = "Ya",
  ["я"] = "ya", ["  "] = " ",
}

function Addon.TransliterateCyrillicLetters(text)
  if Addon.db.profile.Localization.TransliterateCyrillicLetters and text and text:len() > 1 then
    local cache_entry = TextCache[text]

    local transliterated_text = cache_entry.Transliteration
    if not transliterated_text then
      transliterated_text = text:gsub(' ', '  ')  -- Deals with spaces so that sub can work with cyrillic guild names that have spaces
      transliterated_text = transliterated_text:gsub("..", TRANSLITERATE_CHARS) -- '..' pattern matches a single cyrillic letter, or double space from above which gets replaced by single space

      cache_entry.Transliteration = transliterated_text
    end

    return transliterated_text
  end

  return text
end

---------------------------------------------------------------------------------------------------
-- Update of settings
---------------------------------------------------------------------------------------------------

function Addon:UpdateConfigurationLocalization()
  self.Truncate = (self.db.profile.text.LocalizedUnitSymbol and TruncateEastAsian) or TruncateWestern
end