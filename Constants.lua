local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Stuff for handling the configuration of Threat Plates - ThreatPlatesDB
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local L = ThreatPlates.L
local RGB = ThreatPlates.RGB
local RGB_P = ThreatPlates.RGB_P
local HEX2RGB = ThreatPlates.HEX2RGB

---------------------------------------------------------------------------------------------------
-- Global contstants
---------------------------------------------------------------------------------------------------

ThreatPlates.ADDON_NAME = "Threat Plates"

Addon.ADDON_DIRECTORY = "Interface\\AddOns\\TidyPlates_ThreatPlates\\"

-- Define names for keybindings
_G["BINDING_HEADER_" .. "THREATPLATES"] = ThreatPlates.ADDON_NAME
_G["BINDING_NAME_" .. "THREATPLATES_NAMEPLATE_MODE_FOR_FRIENDLY_UNITS"] = L["Toggle Friendly Headline View"]
_G["BINDING_NAME_" .. "THREATPLATES_NAMEPLATE_MODE_FOR_NEUTRAL_UNITS"] = L["Toggle Neutral Headline View"]
_G["BINDING_NAME_" .. "THREATPLATES_NAMEPLATE_MODE_FOR_ENEMY_UNITS"] = L["Toggle Enemy Headline View"]

---------------------------------------------------------------------------------------------------
-- Color and font definitions
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

---------------------------------------------------------------------------------------------------
-- Global contstants for various stuff
---------------------------------------------------------------------------------------------------
Addon.ON_UPDATE_PER_FRAME = 1 / GetFramerate()
Addon.ON_UPDATE_INTERVAL = 0.25 -- minimum number of seconds between each update of a frame for OnUpdate handlers
Addon.PLATE_FADE_IN_TIME = 0.5
Addon.CASTBAR_INTERRUPT_HOLD_TIME = 1

Addon.UIScale = 1

Addon.TotemInformation = {} -- basic totem information
Addon.TOTEMS = {} -- mapping table for fast access to totem settings

Addon.ANCHOR_POINT = {
  TOPLEFT = L["Top Left"],
  TOP = L["Top"],
  TOPRIGHT = L["Top Right"],
  LEFT = L["Left"],
  CENTER = L["Center"],
  RIGHT = L["Right"],
  BOTTOMLEFT = L["Bottom Left"],
  BOTTOM = L["Bottom"],
  BOTTOMRIGHT = L["Bottom Right"],
}

Addon.ANCHOR_POINT_SETPOINT = {
  TOPLEFT = {"TOPLEFT", "BOTTOMLEFT"},
  TOP = {"TOP", "BOTTOM"},
  TOPRIGHT = {"TOPRIGHT", "BOTTOMRIGHT"},
  LEFT = {"LEFT", "RIGHT"},
  CENTER = {"CENTER", "CENTER"},
  RIGHT = {"RIGHT", "LEFT"},
  BOTTOMLEFT = {"BOTTOMLEFT", "TOPLEFT"},
  BOTTOM = {"BOTTOM", "TOP"},
  BOTTOMRIGHT = {"BOTTOMRIGHT", "TOPRIGHT"}
}

Addon.ANCHOR_POINT_TEXT = {
  TOPLEFT = {"TOPLEFT", "BOTTOMRIGHT"},
  TOP = {"TOP", "BOTTOM"},
  TOPRIGHT = {"TOPRIGHT", "BOTTOMLEFT"},
  LEFT = {"LEFT", "RIGHT"},
  CENTER = {"CENTER", "CENTER"},
  RIGHT = {"RIGHT", "LEFT"},
  BOTTOMLEFT = {"BOTTOMLEFT", "TOPRIGHT"},
  BOTTOM = {"BOTTOM", "TOP"},
  BOTTOMRIGHT = {"BOTTOMRIGHT", "TOPLEFT"}
}

ThreatPlates.AlignH = {LEFT = L["Left"], CENTER = L["Center"], RIGHT = L["Right"]}
ThreatPlates.AlignV = {BOTTOM = L["Bottom"], CENTER = L["Center"], TOP = L["Top"]}

ThreatPlates.AUTOMATION = {
  NONE = "No Automation",
  SHOW_COMBAT = "Show during Combat, Hide when Combat ends",
  HIDE_COMBAT = "Hide when Combat starts, Show when Combat ends",
}

Addon.GLOW_TYPES = {
  Button = L["Button"],
  Pixel = L["Pixel"],
  AutoCast = L["Auto-Cast"],
}

----------------------------------------------------------------------------------------------------
-- Paths
---------------------------------------------------------------------------------------------------

ThreatPlates.Widgets = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Widgets\\"

---------------------------------------------------------------------------------------------------
-- Global contstants for options dialog
---------------------------------------------------------------------------------------------------

Addon.AurasFilterMode = {
  ["whitelist"] = L["White List"],
  ["blacklist"] = L["Black List"],
  ["all"] = L["All Auras"],
}

ThreatPlates.SPEC_ROLES = {
  --DEATHKNIGHT = { true, false, false },
  --DEMONHUNTER = { false, true },
  DRUID 			= { false, true, true },
  HUNTER			= { false, false, false },
  MAGE				= { false, false, false },
  --MONK 				= { true, false, false },
  PALADIN 		= { false, true, false },
  PRIEST			= { false, false, false },
  ROGUE				= { false, false, false },
  SHAMAN			= { false, false, false },
  WARLOCK			= { false, false, false },
  WARRIOR			= { false, false, true },
}

ThreatPlates.FontStyle = {
  NONE = L["None"],
  OUTLINE = L["Outline"],
  THICKOUTLINE = L["Thick Outline"],
  ["NONE, MONOCHROME"] = L["No Outline, Monochrome"],
  ["OUTLINE, MONOCHROME"] = L["Outline, Monochrome"],
  ["THICKOUTLINE, MONOCHROME"] = L["Thick Outline, Monochrome"]
}

-- "By Threat", "By Level Color", "By Normal/Elite/Boss"
ThreatPlates.ENEMY_TEXT_COLOR = {
  CLASS = L["By Class"],
  CUSTOM = L["By Custom Color"],
  REACTION = L["By Reaction"],
  HEALTH = L["By Health"],
}

ThreatPlates.FRIENDLY_TEXT_COLOR = {
  CLASS = L["By Class"],
  CUSTOM = L["By Custom Color"],
  REACTION = L["By Reaction"],
  HEALTH = L["By Health"],
}

-- NPC Role, Guild, or Quest", "Quest",
ThreatPlates.ENEMY_SUBTEXT = {
  NONE = L["None"],
  HEALTH = L["Health"],
  ROLE = L["NPC Role"],
  ROLE_GUILD = L["NPC Role, Guild"],
  ROLE_GUILD_LEVEL = L["NPC Role, Guild, or Level"],
  LEVEL = L["Level"],
  ALL = L["Everything"],
}

-- "NPC Role, Guild, or Quest", "Quest"
ThreatPlates.FRIENDLY_SUBTEXT = {
  NONE = L["None"],
  HEALTH = L["Health"],
  ROLE = L["NPC Role"],
  ROLE_GUILD = L["NPC Role, Guild"],
  ROLE_GUILD_LEVEL = L["NPC Role, Guild, or Level"],
  LEVEL = L["Level"],
  ALL = L["Everything"],
}

-------------------------------------------------------------------------------
-- Totem data - define it one time for the whole addon
-------------------------------------------------------------------------------

local TOTEM_DATA = {
  -- Earth Totems
  { SpellID = 25361,   ID = "E1", GroupColor = "8B4513", Ranks = 5, },	  -- Strength of Earth Totem
  { SpellID = 10408,   ID = "E2", GroupColor = "8B4513", Ranks = 6, },	  -- Stoneskin Totem
  { SpellID = 10428,   ID = "E3", GroupColor = "8B4513", Ranks = 6, },	  -- Stoneclaw Totem
  { SpellID = 2484,    ID = "E4", GroupColor = "8B4513", },           	  -- Earthbind Totem
  { SpellID = 8143,    ID = "E5", GroupColor = "8B4513", },	              -- Tremor Totem

  -- Fire Totems
  { SpellID = 10438, ID = "F1", GroupColor = "ff8f8f", Ranks = 6, }, 	  -- Searing Totem
  { SpellID = 10479, ID = "F2", GroupColor = "ff8f8f", Ranks = 3, }, 	  -- Frost Resistance Totem
  { SpellID = 11315, ID = "F3", GroupColor = "ff8f8f", Ranks = 5, }, 	  -- Fire Nova Totem
  { SpellID = 10587, ID = "F4", GroupColor = "ff8f8f", Ranks = 4, }, 	  -- Magma Totem
  { SpellID = 16387, ID = "F5", GroupColor = "ff8f8f", Ranks = 4, }, 	  -- Flametongue Totem

  -- Air Totems
  { SpellID = 25359,  ID = "A1", GroupColor = "ffb31f", Ranks = 3, },		-- Grace of Air Totem
  { SpellID = 10601,  ID = "A2", GroupColor = "ffb31f", Ranks = 3, },		-- Nature Resistance Totem
  { SpellID = 15112,  ID = "A3", GroupColor = "ffb31f", Ranks = 3, },		-- Windwall Totem
  { SpellID = 10614,  ID = "A4", GroupColor = "ffb31f", Ranks = 3, },		-- Windfury Totem
  { SpellID = 8177,   ID = "A5", GroupColor = "ffb31f", },          		-- Grounding Totem
  { SpellID = 6495,   ID = "A6", GroupColor = "ffb31f", },		          -- Sentry Totem
  { SpellID = 25908,  ID = "A7", GroupColor = "ffb31f", },		          -- Tranquil Air Totem

  -- Water Totems
  { SpellID = 10463,  ID = "W1", GroupColor = "b8d1ff", Ranks = 5, },		-- Healing Stream Totem
  { SpellID = 10497,  ID = "W2", GroupColor = "b8d1ff", Ranks = 4, },		-- Mana Spring Totem
  { SpellID = 10538,  ID = "W3", GroupColor = "b8d1ff", Ranks = 3, },		-- Fire Resistance Totem
  { SpellID = 17359,  ID = "W4", GroupColor = "b8d1ff", Ranks = 3, },		-- Mana Tide Totem
  { SpellID = 8170,   ID = "W5", GroupColor = "b8d1ff", },		          -- Disease Cleansing Totem
  { SpellID = 8166,   ID = "W6", GroupColor = "b8d1ff", },        		  -- Poison Cleansing Totem
}

function Addon:InitializeTotemInformation()
  local totem_name_suffix = { " II", " III", " IV", " V", " VI" }

  for i, totem_data in ipairs(TOTEM_DATA) do
    local name = GetSpellInfo(totem_data.SpellID)
    if name then
      totem_data.Name = name
      totem_data.Color = RGB(HEX2RGB(totem_data.GroupColor))
      totem_data.SortKey = totem_data.ID:sub(1, 1) .. name
      totem_data.Style = "normal"
      totem_data.ShowNameplate = true
      totem_data.ShowHPColor = true
      totem_data.ShowIcon = true

      Addon.TotemInformation[name] = totem_data
      Addon.TOTEMS[name] = totem_data.ID

      for rank = 1, (totem_data.Ranks or 1) - 1  do
        Addon.TOTEMS[name .. totem_name_suffix[rank]] = totem_data.ID
      end
    end
  end
end

local function GetDefaultTotemSettings()
  Addon:InitializeTotemInformation()

  local settings = {
    hideHealthbar = false
  }

  for _, data in pairs(Addon.TotemInformation) do
    settings[data.ID] = data
  end

  return settings
end

---------------------------------------------------------------------------------------------------
-- Default settings for ThreatPlates
---------------------------------------------------------------------------------------------------

ThreatPlates.DEFAULT_SETTINGS = {
  global = {
    version = "",
    DefaultsVersion = "SMOOTH",
    CustomNameplatesVersion = 1,
  },
  char = {
    welcome = false,
    specInfo = {
      [1] = {
        name = "",
        role = "",
      },
      [2] = {
        name = "",
        role = "",
      },
    },
    -- Still using table here for compatibility with non-classic version of Threat Plates, although only [1] is used in classic.
    spec = {
      [1] = false,
      [2] = false,
    },
  },
  profile = {
    cache = {},
    -- OldSetting = true, - removed in 8.7.0
    verbose = false,
    -- blizzFadeA = { -- removed in 8.5.1
    --   toggle  = true,
    --   amount = 0.7
    -- },
    blizzFadeS = {
      toggle  = true,
      amount = -0.3
    },
    tidyplatesFade = false,
    healthColorChange = false,
    customColor =  false,
    allowClass = true, -- old default: false,
    friendlyClass = true, -- old default: false,
    friendlyClassIcon = false,
    HostileClassIcon = true,
    cacheClass = false,
    optionRoleDetectionAutomatic = true, -- old default: false,
    ShowThreatGlowOnAttackedUnitsOnly = true,
    ShowThreatGlowOffTank = true,
    NamePlateEnemyClickThrough = false,
    NamePlateFriendlyClickThrough = false,
    ShowFriendlyBlizzardNameplates = false,
    ShowEnemyBlizzardNameplates = false,
    Automation = {
      FriendlyUnits = "NONE",
      EnemyUnits = "NONE",
      SmallPlatesInInstances = false,
      HideFriendlyUnitsInInstances = false,
    },
    Scale = {
      IgnoreUIScale = true,
      PixelPerfectUI = false,
    },
    HeadlineView = {
      -- ON = false, -- removed in 9.1.0
      name = {
        size = 10,
        -- width = 140, -- same as for healthbar view -- old default: 116,
        -- height = 14, -- same as for healthbar view
        x = 0,
        y = 4,
        align = "CENTER",
        vertical = "CENTER",
      },
      customtext = {
        size = 8,
        -- shadow = true,  -- never used
        -- flags = "NONE", -- never used
        -- width = 140,    -- never used, same as for healthbar view
        -- height = 14,    -- never used, same as for healthbar view
        x = 0,
        y = -6,
        align = "CENTER",
        vertical = "CENTER",
      },
      useAlpha = false,
      -- blizzFading = true, -- removed in 8.5.1
      -- blizzFadingAlpha = 1, -- removed in 8.5.1
      useScaling = false,
      ShowTargetHighlight = true,
      ShowMouseoverHighlight = true,
      ForceHealthbarOnTarget = false,
      ForceOutOfCombat = false,
      ForceNonAttackableUnits = false,
      ForceFriendlyInCombat = "NONE",
      --
      EnemyTextColorMode = "CLASS",
      EnemyTextColor = RGB(0, 255, 0),
      FriendlyTextColorMode = "CLASS",
      FriendlyTextColor = RGB(0, 255, 0),
      UseRaidMarkColoring = false,
      SubtextColorUseHeadline = false,
      SubtextColorUseSpecific = true,
      SubtextColor =  RGB(255, 255, 255, 1),
      --
      EnemySubtext = "ROLE_GUILD_LEVEL",
      FriendlySubtext = "ROLE_GUILD",
    },
    Visibility = {
      --				showNameplates = true,
      --				showHostileUnits = true,
      --				showFriendlyUnits = false,
      FriendlyPlayer = { Show = true, UseHeadlineView = false },
      FriendlyNPC = { Show = "nameplateShowFriendlyNPCs", UseHeadlineView = false },
      FriendlyTotem = { Show = "nameplateShowFriendlyTotems", UseHeadlineView = false },
      FriendlyGuardian = { Show = "nameplateShowFriendlyGuardians", UseHeadlineView = false },
      FriendlyPet = { Show = "nameplateShowFriendlyPets", UseHeadlineView = false },
      FriendlyMinus = { Show = true, UseHeadlineView = false },
      EnemyPlayer = { Show = true, UseHeadlineView = false },
      EnemyNPC = { Show = true, UseHeadlineView = false },
      EnemyTotem = { Show = "nameplateShowEnemyTotems", UseHeadlineView = false },
      EnemyGuardian = { Show = "nameplateShowEnemyGuardians", UseHeadlineView = false },
      EnemyPet = { Show = "nameplateShowEnemyPets", UseHeadlineView = false },
      EnemyMinus = { Show = "nameplateShowEnemyMinus", UseHeadlineView = false },
      NeutralNPC = { Show = true, UseHeadlineView = false },
      --        NeutralGuardian = { Show = true, UseHeadlineView = false },
      NeutralMinus = { Show = true, UseHeadlineView = false },
      -- special units
      HideNormal = false,
      HideBoss = false,
      HideElite = false,
      HideTapped = false,
      HideFriendlyInCombat = false,
    },
    castbarColor = {
      -- toggle = true, -- removed in 8.7.0
      r = 1,
      g = 0.56,
      b = 0.06,
      a = 1
    },
    castbarColorShield = {
      --toggle = true,  -- removed in 8.7.0
      r = 1,
      g = 0,
      b = 0,
      a = 1
    },
    castbarColorInterrupted = RGB(255, 0, 255, 1),
    aHPbarColor = RGB_P(0, 1, 0),
    bHPbarColor = RGB_P(1, 1, 0),
--    cHPbarColor = {
--      r = 1,
--      g = 0,
--      b = 0
--    },
--    fHPbarColor = RGB(0, 255, 0),
--    nHPbarColor = RGB(255, 255, 0),
--    tapHPbarColor = RGB(100, 100, 100),
--    HPbarColor = RGB(255, 0, 0),
--    tHPbarColor = {
--      r = 0,
--      g = 0.5,
--      b = 1,
--    },
    ColorByReaction = {
      FriendlyPlayer = RGB(0, 0, 255),           -- blue
      FriendlyNPC = RGB(0, 255, 0),              -- green
      HostileNPC = RGB(255, 0, 0),               -- red
      HostilePlayer = RGB(255, 0, 0),            -- red
      NeutralUnit = RGB(255, 255, 0),            -- yellow
      TappedUnit = RGB(110, 110, 110, 1),	       -- grey
      DisconnectedUnit = RGB(128, 128, 128, 1),  -- dray, darker than tapped color
      UnfriendlyFaction = RGB(255, 153, 51, 1),  -- brown/orange for unfriendly, hostile, non-attackable units (unit reaction = 3)
    },
    text = {
      amount = false, -- old default: true,
      percent = true,
      full = false,
      max = false,
      deficit = false,
      truncate = true,
      LocalizedUnitSymbol = false,
      -- Absorbs
      AbsorbsAmount = false,
      AbsorbsShorten = true,
      AbsorbsPercentage = false,
    },
    totemWidget = {
      ON = true,
      scale = 35,
      x = 0,
      y = 35,
      level = 1,
      anchor = "CENTER"
    },
    arenaWidget = {
      ON = false, --old default: true,
      scale = 16,
      x = 36,
      y = -6,
      anchor = "CENTER",
      ShowOrb = true,
      ShowNumber = true,
      HideName = false,
      colors = {
        [1] = RGB_P(1, 0, 0, 1),
        [2] = RGB_P(1, 1, 0, 1),
        [3] = RGB_P(0, 1, 0, 1),
        [4] = RGB_P(0, 1, 1, 1),
        [5] = RGB_P(0, 0, 1, 1),
      },
      numColors = {
        [1] = RGB_P(1, 1, 1, 1),
        [2] = RGB_P(1, 1, 1, 1),
        [3] = RGB_P(1, 1, 1, 1),
        [4] = RGB_P(1, 1, 1, 1),
        [5] = RGB_P(1, 1, 1, 1),
      },
      NumberText = {
        Anchor = "CENTER",
        InsideAnchor = true,
        HorizontalOffset = 1,
        VerticalOffset = 0,
        Font = {
          Typeface = Addon.DEFAULT_FONT,
          Size = 12,
          flags = "OUTLINE",
          Shadow = true,
          HorizontalAlignment = "CENTER",
          VerticalAlignment = "CENTER",
        },
      },
    },
    healerTracker = {
      ON = false,
      scale = 22,
      x = 0,
      y = 35,
      level = 1,
      alpha = 1,
      anchor = "RIGHT",
      ShowInHeadlineView = false
    },
    AuraWidget = {
      ON = true,
      x = 0,
      y = 16,
      x_hv = 0,
      y_hv = 16,
      scale = 1, -- Removed in 8.8.0
      FrameOrder = "HEALTHBAR_AURAS",
      anchor = "TOP",
      ShowInHeadlineView = false,
      -- ShowEnemy = true, -- Removed in 8.8.0
      -- ShowFriendly = true, -- Removed in 8.8.0
      -- FilterMode = "blacklistMine", -- Moved to Debuffs in 8.8.0
      -- ShowDebuffsOnFriendly = false, -- Moved to Debuffs in 8.8.0
      -- FilterBySpell = {}, -- Moved to Debuffs in 8.8.0
      ShowTargetOnly = false,
      ShowCooldownSpiral = false,
      ShowDuration = true,
      ShowOmnicCC = false,
      ShowStackCount = true,
      ShowTooltips = false,
      ShowAuraType = true,
      DefaultBuffColor = RGB(102, 0, 51, 1),
      DefaultDebuffColor = 	RGB(204, 0, 0, 1),
      Highlight = {
        Enabled = true,
        Type = "Button",
        CustomColor = false,
        Color = RGB_P(0.95, 0.95, 0.32, 1),
      },
      SortOrder = "TimeLeft",
      SortReverse = false,
      AlignmentH = "LEFT",
      AlignmentV = "BOTTOM",
      CenterAuras = true,
      SwitchScaleByReaction = true,
      FlashWhenExpiring = false,
      FlashTime = 5,
      Debuffs = {
        ShowFriendly = false,
        ShowAllFriendly = false,
        ShowBlizzardForFriendly = true,
        ShowDispellable = true,
        ShowBoss = true,
        ShowEnemy = true,
        ShowAllEnemy = false,
        ShowOnlyMine = true,
        ShowBlizzardForEnemy = false,
        Scale = 1.0,
        FilterMode = "blacklist",
        FilterBySpell = {},
        FilterByType = {
          --[1] = true, -- Removed in 8.8.0
          [1] = false,  -- Moved to Debuffs and negated meaning in 8.8.0
          [2] = false,  -- Moved to Debuffs and negated meaning in 8.8.0
          [3] = false,  -- Moved to Debuffs and negated meaning in 8.8.0
          [4] = false,  -- Moved to Debuffs and negated meaning in 8.8.0
          --[6] = true, -- Removed in 8.8.0
        },
      },
      Buffs = {
        ShowFriendly = false,
        ShowAllFriendly = false,
        ShowOnFriendlyNPCs = true,
        ShowOnlyMine = false,
        ShowPlayerCanApply = false,
        ShowEnemy = true,
        ShowAllEnemy = false,
        ShowOnEnemyNPCs = true,
        ShowDispellable = true,
        ShowMagic = false,
        ShowUnlimitedAlways = false,
        ShowUnlimitedInCombat = true,
        ShowUnlimitedInInstances = true,
        ShowUnlimitedOnBosses = true,
        HideUnlimitedDuration = false,
        Scale = 1.5,
        FilterMode = "blacklist",
        FilterBySpell = {},
      },
      CrowdControl = {
        ShowFriendly = true,
        ShowAllFriendly = false,
        ShowBlizzardForFriendly = true,
        ShowDispellable = true,
        ShowBoss = true,
        ShowEnemy = true,
        ShowAllEnemy = false,
        ShowBlizzardForEnemy = true,
        Scale = 2.0,
        FilterMode = "blacklist",
        FilterBySpell = {},
      },
      ModeIcon = {
        Style = "square",
        IconWidth = 16.5,
        IconHeight = 14.5,
        ShowBorder = true,
        Columns = 5,
        Rows = 3,
        ColumnSpacing = 5,
        RowSpacing = 8,
        Duration = {
          Anchor = "RIGHT",
          InsideAnchor = true,
          HorizontalOffset = 0,
          VerticalOffset = 8,
          Font = {
            Typeface = Addon.DEFAULT_SMALL_FONT,
            Size = 10,
            Transparency = 1,
            Color = RGB(255, 255, 255),
            flags = "OUTLINE",
            Shadow = true,
            HorizontalAlignment = "RIGHT",
            VerticalAlignment = "CENTER",
          }
        },
        StackCount = {
          Anchor = "RIGHT",
          InsideAnchor = true,
          HorizontalOffset = 0,
          VerticalOffset = -6,
          Font = {
            Typeface = Addon.DEFAULT_SMALL_FONT,
            Size = 10,
            Transparency = 1,
            Color = RGB(255, 255, 255),
            flags = "OUTLINE",
            Shadow = true,
            HorizontalAlignment = "RIGHT",
            VerticalAlignment = "CENTER",
          }
        },
      },
      ModeBar = {
        Enabled = false,
        BarHeight = 14,
        BarWidth = 100,
        BarSpacing = 2,
        MaxBars = 10,
        Texture = "Smooth", -- old default: "Aluminium",
        Font = Addon.DEFAULT_SMALL_FONT,
        FontSize = 10,
        FontColor = RGB(255, 255, 255),
        LabelTextIndent = 4,
        TimeTextIndent = 4,
        BackgroundTexture = "Smooth",
        BackgroundColor = RGB(0, 0, 0, 0.3),
        -- BackgroundBorder = "ThreatPlatesBorder", -- not used
        -- BackgroundBorderEdgeSize = 1, -- not used
        -- BackgroundBorderInset = 1, -- not used
        -- BackgroundBorderColor = RGB(0, 0, 0, 0.3), -- not used
        ShowIcon = true,
        IconSpacing = 2,
        IconAlignmentLeft = true,
      },
    },
    uniqueWidget = {
      ON = true,
      scale = 22, -- old default: 35,
      x = 0,
      y = 30, -- old default:  24,
      x_hv = 0,
      y_hv = 22,
      level = 1,
      anchor = "CENTER"
    },
    classWidget = {
      ON = true,
      scale = 22,
      x = -76,
      y = -7,
      x_hv = -74,
      y_hv = -7,
      theme = "default",
      anchor = "CENTER",
      ShowInHeadlineView = false,
    },
    targetWidget = {
      ON = true,
      theme = "default",
      r = 1,
      g = 1,
      b = 1,
      a = 1,
      ModeHPBar = false,
      ModeNames = false,
      HPBarColor = RGB(255, 0, 255), -- Magenta / Fuchsia
    },
    threatWidget = {
      ON = false,
      x = 0,
      y = 26,
      anchor = "CENTER",
    },
    tankedWidget = {
      ON = false,
      scale = 1,
      x = 65,
      y = 6,
      anchor = "CENTER",
    },
    ComboPoints = {
      ON = false,
      ShowInHeadlineView = false,
      Style = "Orbs",
      HorizontalSpacing = 0,
      UseUniformColor = true,
      ShowOffCPs = false,
      Scale = 1,
      Transparency = 1,
      x = 0,
      y = -10,
      x_hv = 0,
      y_hv = -20,
      Specialization = "DRUID",
      ColorBySpec = {
        DEATHKNIGHT = {
          [1] = RGB(255, 0, 255),
          [2] = RGB(255, 0, 255),
          [3] = RGB(255, 0, 255),
          [4] = RGB(255, 0, 255),
          [5] = RGB(255, 0, 255),
          [6] = RGB(255, 0, 255),
        },
        DRUID = {
          [1] = RGB(0, 0, 255),
          [2] = RGB(0, 150, 255),
          [3] = RGB(0, 255, 0),
          [4] = RGB(255, 105, 0),
          [5] = RGB(255, 0, 0),
        },
        MAGE = {
          [1] = RGB(105, 204, 240),
          [2] = RGB(105, 204, 240),
          [3] = RGB(105, 204, 240),
          [4] = RGB(105, 204, 240),
        },
        MONK = {
          [1] = RGB(0, 225, 255), -- Cyan
          [2] = RGB(0, 225, 255),
          [3] = RGB(0, 225, 255),
          [4] = RGB(0, 225, 255),
          [5] = RGB(0, 225, 255),
          [6] = RGB(0, 225, 255),
        },
        PALADIN = {
          [1] = RGB(255, 255, 0),
          [2] = RGB(255, 255, 0),
          [3] = RGB(255, 255, 0),
          [4] = RGB(255, 255, 0),
          [5] = RGB(255, 255, 0),
        },
        ROGUE = {
          [1] = RGB(0, 0, 255),
          [2] = RGB(0, 150, 255),
          [3] = RGB(0, 255, 0),
          [4] = RGB(255, 105, 0),
          [5] = RGB(255, 0, 0),
          [6] = RGB(255, 0, 0),
        },
        WARLOCK = {
          [1] = RGB(148, 130, 201),
          [2] = RGB(148, 130, 201),
          [3] = RGB(148, 130, 201),
          [4] = RGB(148, 130, 201),
          [5] = RGB(148, 130, 201),
        },
      },
      RuneCooldown = {
        Show = true,
        HorizontalOffset = 1,
        VerticalOffset = 0,
        Font = {
          Typeface = Addon.DEFAULT_FONT,
          Size = 10,
          flags = "OUTLINE",
          Shadow = true,
        },
      },
    },
    socialWidget = {
      ON = false,
      scale = 16,
      x = 65,
      y = 6,
      x_hv = 65,
      y_hv = 6,
      --anchor = "Top",
      ShowInHeadlineView = false,
      ShowFriendIcon = true,
      ShowFactionIcon = true,
      ShowFriendColor = false,
      FriendColor = RGB(29, 39, 61),      -- Blizzard friend dark blue, color for healthbars of friends
      ShowGuildmateColor = false,
      GuildmateColor = RGB(60, 168, 255), -- light blue, color for healthbars of guildmembers
    },
    FactionWidget = {
      --ON = false,
      scale = 16,
      x = 0,
      y = 28,
      x_hv = 0,
      y_hv = 20,
      --anchor = "Top",
    },
    questWidget = {
      ON = true, -- old default: false
      scale = 26,
      x = 0,
      y = 30,
      x_hv = 0,
      y_hv = 30,
      alpha = 1,
      anchor = "CENTER",
      ModeHPBar = false, -- old default: true
      ModeIcon = true,
      HPBarColor = RGB(218, 165, 32), -- Golden rod
      ColorPlayerQuest = RGB(255, 215, 0), -- Golden
      ColorGroupQuest = RGB(32, 217, 114), -- See green-ish
      IconTexture = "QUESTICON",
      HideInCombat = false,
      HideInCombatAttacked = true,
      HideInInstance = true,
      ShowInHeadlineView = false,
      ShowProgress = true,
      Font = Addon.DEFAULT_FONT,
      FontSize = 3
    },
    stealthWidget = {
      ON = false,
      scale = 28,
      x = 0,
      y = 0,
      alpha = 1,
      anchor = "CENTER",
      ShowInHeadlineView = false,
    },
    ResourceWidget  = {
      ON = false,
      --ShowInHeadlineView = false,
      --scale = 28,
      x = 0,
      y = -18,
      ShowFriendly = false,
      ShowEnemyPlayer = false,
      ShowEnemyNPC = false,
      ShowEnemyBoss = true,
      ShowOnlyAltPower = true,
      ShowBar = true,
      BarHeight = 12,
      BarWidth = 80,
      BarTexture = "Smooth", -- old default: "Aluminium"
      BackgroundUseForegroundColor = false,
      BackgroundColor = RGB(0, 0, 0, 0.3),
      BorderTexture = "ThreatPlatesBorder",
      BorderEdgeSize = 1,
      BorderOffset = 1,
      BorderUseForegroundColor = false,
      BorderUseBackgroundColor = false,
      BorderColor = RGB(0, 0, 0, 1),
      --BorderInset = 4,
      --BorderTileSize = 16,
      ShowText = true,
      Font = Addon.DEFAULT_FONT,
      FontSize = 10,
      FontColor = RGB(255, 255, 255),
    },
    BossModsWidget = {
      ON = true,
      ShowInHeadlineView = true,
      x = 0,
      y = 66,
      x_hv = 0,
      y_hv = 40,
      scale = 40,
      AuraSpacing = 4,
      Font = Addon.DEFAULT_FONT,
      FontSize = 24,
      FontColor = RGB(255, 255, 255),
      -- TODO: add font flags like for custom text
      --ShowTrackingLine = true, -- Removed in 9.1.9
      --TrackingLineThickness = 4  -- Removed in 9.1.9
    },
--    TestWidget = {
--      ON = true,
--      BarWidth = 120,
--      BarHeight = 10,
--      BarTexture = "Smooth",
--      BorderTexture = "TP_Border_1px",
--      BorderBackground = "ThreatPlatesEmpty",
--      EdgeSize = 5,
--      Offset = 5,
--      Inset = 5,
--      Scale = 1,
--    },
    PersonalNameplate = {
      HideBuffs = false,
      ShowResourceOnTarget = false,
    },
    totemSettings = GetDefaultTotemSettings(),
    uniqueSettings = {
      map = {},
      ["**"] = {
        name = "<Enter name here>",
        showNameplate = true,
        ShowHeadlineView = false,
        showIcon = true,
        useStyle = true,
        useColor = true,
        UseThreatColor = false,
        UseThreatGlow = false,
        allowMarked = true,
        overrideScale = false,
        overrideAlpha = false,
        icon = "spell_shadow_shadowfiend.blp",
        scale = 1,
        alpha = 1,
        color = {
          r = 1,
          g = 1,
          b = 1,
        },
      },
    },
    CVarsBackup = {}, -- Backup for CVars that should be restored when TP is disabled
    settings = {
      frame = {
        x = 0,
        y = 0,
        width = 110,
        height = 45,
        SyncWithHealthbar = true,
      },
      highlight = {
        -- texture = "TP_HealthBarHighlight", -- removed in 8.7.0
        show = true,
      },
      elitehealthborder = {
        texture = "TP_EliteBorder_Default",
        show = false, -- old default: true
      },
      healthborder = {
        texture = "TP_Border_Thin", -- old default: "TP_HealthBarOverlay",
        backdrop = "",
        EdgeSize = 1,
        Offset = 1,
        show = true,
      },
      threatborder = {
        show = true,
      },
      healthbar = {
        width = 120,
        height = 10,
        texture = "Smooth", -- old default: "ThreatPlatesBar",
        backdrop = "Smooth", -- old default: "ThreatPlatesEmpty",
        BackgroundUseForegroundColor = false,
        BackgroundOpacity = 0.7, -- old default: 1,
        BackgroundColor = RGB(0, 0, 0),
        ShowHealAbsorbs = true,
        ShowAbsorbs = true,
        AbsorbColor = RGB(0, 255, 255, 1),
        AlwaysFullAbsorb = false,
        OverlayTexture = true,
        OverlayColor = RGB(0, 128, 255, 1),
      },
      castnostop = {
        show = true, -- no longer used
        ShowOverlay = false,
        ShowInterruptShield = false,
      },
      castborder = {
        texture = "TP_Castbar_Border_Thin", -- old default: "TP_CastBarOverlay",
        EdgeSize = 1,
        Offset = 1,
        show = true,
      },
      castbar = {
        width = 120,
        height = 10,
        texture = "Smooth", -- old default: "ThreatPlatesBar",
        backdrop = "Smooth",
        BackgroundUseForegroundColor = false,
        BackgroundOpacity = 0.7,
        BackgroundColor = RGB(0, 0, 0),
        x = 0,
        y = -15,
        x_hv = 0,
        y_hv = -20,
        x_target = 0,
        y_target = 0,
        show = true,
        ShowInHeadlineView = false,
        ShowSpark = true,
      },
      name = { -- Names for Healthbar View
        show = true,
        typeface = Addon.DEFAULT_FONT, -- old default: "Accidental Presidency",
        size = 10, -- old default: 14
        shadow = true,
        flags = "NONE",
        width = 140, -- old default: 116,
        height = 14,
        x = 0,
        y = 13,
        align = "CENTER",
        vertical = "CENTER",
        --
        EnemyTextColorMode = "CUSTOM",
        EnemyTextColor = RGB(255, 255, 255),
        FriendlyTextColorMode = "CUSTOM",
        FriendlyTextColor = RGB(255, 255, 255),
        UseRaidMarkColoring = false,
      },
      level = {
        typeface = Addon.DEFAULT_FONT, -- old default: "Accidental Presidency",
        size = 9, -- old default: 12,
        size = 9, -- old default: 12,
        width = 20,
        height = 10, -- old default: 14,
        x = 49, -- old default: 50,
        y = 0,
        align = "RIGHT",
        vertical = "CENTER", -- old default: "TOP",
        shadow = true,
        flags = "NONE",
        show = true,
      },
      eliteicon = {
        show = true,
        theme = "default",
        scale = 15,
        x = 61, -- old default: 64
        y = 7, -- old default: 9
        level = 22,
        anchor = "CENTER"
      },
      customtext = {
        typeface = Addon.DEFAULT_FONT, -- old default: "Accidental Presidency",
        size = 9, -- old default: 12,
        width = 110,
        height = 14,
        x = 0,
        y = 0, -- old default: 1,
        align = "CENTER",
        vertical = "CENTER",
        shadow = true,
        flags = "NONE",
        --
        FriendlySubtext = "HEALTH",
        EnemySubtext = "HEALTH",
        SubtextColorUseHeadline = false,
        SubtextColorUseSpecific = false,
        SubtextColor =  RGB(255, 255, 255, 1),
      },
      spelltext = {
        typeface = Addon.DEFAULT_FONT, -- old default: "Accidental Presidency",
        size = 8,  -- old default: 12
        width = 110,
        height = 14,
        x = 0,
        y = -15,  -- old default: -13
        x_hv = 0,
        y_hv = -20,  -- old default: -13
        align = "CENTER",
        vertical = "CENTER",
        shadow = true,
        flags = "NONE",
        show = true,
      },
      raidicon = {
        scale = 20,
        x = -78,
        y = 0, -- old default: 27
        x_hv = 0,
        y_hv = 25,
        anchor = "CENTER",
        hpColor = true,
        show = true,
        ShowInHeadlineView = false,
        hpMarked = {
          ["STAR"] = RGB_P(0.85, 0.81, 0.27),
          ["MOON"] = RGB_P(0.60, 0.75, 0.85),
          ["CIRCLE"] = RGB_P(0.93, 0.51,0.06),
          ["SQUARE"] = RGB_P(0, 0.64, 1),
          ["DIAMOND"] = RGB_P(0.7, 0.06, 0.84),
          ["CROSS"] = RGB_P(0.82, 0.18, 0.18),
          ["TRIANGLE"] = RGB_P(0.14, 0.66, 0.14),
          ["SKULL"] = RGB_P(0.89, 0.83, 0.74),
        },
      },
      spellicon = {
        scale = 20,
        x = 76,
        y = -7,
        x_hv = 75,
        y_hv = -7,
        anchor = "CENTER",
        show = true,
      },
      customart = {
        scale = 22,
        x = -74,
        y = -7,
        anchor = "CENTER",
        show = true,
      },
      skullicon = {
        scale = 16,
        x = 51, -- old default: 55
        y = 0,
        anchor = "CENTER",
        show = true,
      },
      unique = {
        threatcolor = {
          LOW = RGB_P(0, 0, 0, 0),
          MEDIUM = RGB_P(0, 0, 0, 0),
          HIGH = RGB_P(0, 0, 0, 0),
        },
      },
      totem = {
        threatcolor = {
          LOW = RGB_P(0, 0, 0, 0),
          MEDIUM = RGB_P(0, 0, 0, 0),
          HIGH = RGB_P(0, 0, 0, 0),
        },
      },
      normal = {
        threatcolor = {
          LOW = RGB_P(1, 1, 1, 1),
          MEDIUM = RGB_P(1, 1, 0, 1),
          HIGH = RGB_P(1, 0, 0, 1),
        },
      },
      dps = {
        threatcolor = {
          LOW = RGB_P(0, 1, 0, 1),
          MEDIUM = RGB_P(1, 1, 0, 1),
          HIGH = RGB_P(1, 0, 0, 1),
        },
      },
      tank = {
        threatcolor = {
          LOW = RGB_P(1, 0, 0, 1),
          MEDIUM = RGB_P(1, 1, 0, 1),
          HIGH = RGB_P(0, 1, 0, 1),
          OFFTANK = RGB(15, 170, 200, 1),
        },
      },
    },
    threat = {
      ON = true,
      marked = false,
      -- nonCombat = true, -- removed in 9.1.3
      UseThreatTable = true,
      UseHeuristicInInstances = false,
      -- hideNonCombat = false, -- no longer used, removed in 9.1.3
      useType = true,
      useScale = true,
      AdditiveScale = false,
      useAlpha = true,
      AdditiveAlpha = false,
      useHPColor = true,
      art = {
        ON = true,
        theme = "default",
      },
      --        scaleType = {
      --          ["Normal"] = -0.2,
      --          ["Elite"] = 0,
      --          ["Boss"] = 0.2,
      --          ["Minus"] = -0.2,
      --        },
      toggle = {
        ["Boss"]	= true,
        ["Elite"]	= true,
        ["Normal"]	= true,
        ["Neutral"]	= true,
        ["Minus"] 	= true,
        ["Tapped"] 	= true,
        ["OffTank"] = true,
        ["InstancesOnly"] = false,
      },
      dps = {
        scale = {
          LOW 		= 0.8,
          MEDIUM		= 0.9,
          HIGH 		= 1.0, -- old default: 1.25,
        },
        alpha = {
          LOW 		= 1,
          MEDIUM		= 1,
          HIGH 		= 1
        },
      },
      tank = {
        scale = {
          LOW 		= 1.0, -- old default: 1.25,
          MEDIUM		= 0.9,
          HIGH 		= 0.8,
          OFFTANK = 0.8
        },
        alpha = {
          LOW 		= 1,
          MEDIUM		= 0.85,
          HIGH 		= 0.75,
          OFFTANK = 0.75
        },
      },
      marked = {
        alpha = false,
        art = false,
        scale = false
      },
    },
    nameplate = {
      toggle = {
        ["Boss"]	= true,
        ["Elite"]	= true,
        ["Normal"]	= true,
        ["Neutral"]	= true,
        ["Minus"]	= true,
        ["Tapped"] 	= true,
        ["TargetA"]  = false,   -- Target Alpha
        ["NonTargetA"]	= true, -- Non-Target Alpha
        ["NoTargetA"]  = false, -- No Target Alpha
        ["TargetS"]  = false,   -- Target Scale
        ["NonTargetS"]	= false, -- Non-Target Scale
        ["NoTargetS"]  = false, -- No Target Scale
        ["MarkedA"] = false,
        ["MarkedS"] = false,
        ["CastingUnitAlpha"] = false, -- Friendly Unit Alpha
        ["CastingEnemyUnitAlpha"] = false,
        ["CastingUnitScale"] = false, -- Friendly Unit Scale
        ["CastingEnemyUnitScale"] = false,
        ["MouseoverUnitAlpha"] = false,
        ["MouseoverUnitScale"] = false,
        OccludedUnits        = false,
      },
      scale = {
        AbsoluteTargetScale  = false,
        ["Target"]	  	     = 0.3,
        ["NonTarget"]	       = -0.3,
        ["NoTarget"]	       = 0,
        ["Totem"]		         = 0.75,
        ["Marked"] 		       = 1.3,
        --["Normal"]		     = 1,
        ["CastingUnit"]      = 1.3,  -- Friendly Unit Scale
        ["CastingEnemyUnit"] = 1.3,
        ["MouseoverUnit"]    = 1.3,
        ["FriendlyPlayer"]   = 1,
        ["FriendlyNPC"]      = 1,
        ["Neutral"]		       = 0.9,
        ["EnemyPlayer"]      = 1,
        ["EnemyNPC"]         = 1,
        ["Elite"]		         = 1.04,
        ["Boss"]		         = 1.1,
        ["Guardian"]         = 0.75,
        ["Pet"]              = 0.75,
        ["Minus"]	           = 0.6,
        ["Tapped"] 		       = 0.9,
      },
      alpha = {
        AbsoluteTargetAlpha  = false,
        ["Target"]		       = 1,
        ["NonTarget"]	       = 0.7,
        ["NoTarget"]	       = 1,
        ["Totem"]		         = 1,
        ["Marked"] 		       = 1,
        --["Normal"]		     = 1,
        ["CastingUnit"]	     = 1,  -- Friendly Unit Alpha
        ["CastingEnemyUnit"] = 1,
        ["MouseoverUnit"]	   = 1,
        ["FriendlyPlayer"]   = 1,
        ["FriendlyNPC"]      = 1,
        ["Neutral"]		       = 1,
        ["EnemyPlayer"]      = 1,
        ["EnemyNPC"]         = 1,
        ["Elite"]		         = 1,
        ["Boss"]		         = 1,
        ["Guardian"]         = 0.8,
        ["Pet"]              = 0.8,
        ["Minus"]	           = 0.8,
        ["Tapped"]		       = 1,
        OccludedUnits        = 0,
      },
    },
    Transparency = {
      Fadeing = true,
    },
  }
}
