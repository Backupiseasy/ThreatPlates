local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- ThreatPlates APIs
local TextCache = Addon.Cache.Texts

---------------------------------------------------------------------------------------------------
-- localized constants and functions
---------------------------------------------------------------------------------------------------

Addon.DEFAULT_FONT = "Cabin"
Addon.DEFAULT_SMALL_FONT = "Arial Narrow"

local locale = GetLocale()
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

if MAP_FONT[locale] then
  Addon.DEFAULT_FONT = MAP_FONT[locale].DefaultFont
  Addon.DEFAULT_SMALL_FONT = MAP_FONT[locale].DefaultSmallFont
end

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
    local transliterated_text = TextCache[text]
    if not transliterated_text then
      transliterated_text = text:gsub(' ', '  ')  -- Deals with spaces so that sub can work with cyrillic guild names that have spaces
      transliterated_text = transliterated_text:gsub("..", TRANSLITERATE_CHARS) -- '..' pattern matches a single cyrillic letter, or double space from above which gets replaced by single space

      TextCache[text] = transliterated_text
    end

    return transliterated_text
  end

  return text
end