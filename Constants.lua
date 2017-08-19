local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Stuff for handling the configuration of Threat Plates - ThreatPlatesDB
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local L = ThreatPlates.L
local RGB = ThreatPlates.RGB
local RGB_P = ThreatPlates.RGB_P
local TotemNameBySpellID = ThreatPlates.TotemNameBySpellID
local HEX2RGB = ThreatPlates.HEX2RGB

---------------------------------------------------------------------------------------------------
-- Color and font definitions
---------------------------------------------------------------------------------------------------

local DEFAULT_FONT = "Cabin"

---------------------------------------------------------------------------------------------------
-- Global contstants for various stuff
---------------------------------------------------------------------------------------------------

ThreatPlates.ADDON_NAME = "Tidy Plates: Threat Plates"
ThreatPlates.THEME_NAME = "Threat Plates"
-- ThreatPlates.TIDYPLATES_VERSIONS = { "6.18.10" }
-- ThreatPlates.TIDYPLATES_INSTALLED_VERSION = GetAddOnMetadata("TidyPlates", "version") or ""

ThreatPlates.ANCHOR_POINT = {
  TOPLEFT = "Top Left",
  TOP = "Top",
  TOPRIGHT = "Top Right",
  LEFT = "Left",
  CENTER = "Center",
  RIGHT = "Right",
  BOTTOMLEFT = "Bottom Left",
  BOTTOM = "Bottom ",
  BOTTOMRIGHT = "Bottom Right"
}

ThreatPlates.ANCHOR_POINT_SETPOINT = {
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

-- only used by DebuffWidget (old Auras)
ThreatPlates.FullAlign = {TOPLEFT = "TOPLEFT",TOP = "TOP",TOPRIGHT = "TOPRIGHT",LEFT = "LEFT",CENTER = "CENTER",RIGHT = "RIGHT",BOTTOMLEFT = "BOTTOMLEFT",BOTTOM = "BOTTOM",BOTTOMRIGHT = "BOTTOMRIGHT"}

ThreatPlates.AlignH = {LEFT = "LEFT", CENTER = "CENTER", RIGHT = "RIGHT"}
ThreatPlates.AlignV = {BOTTOM = "BOTTOM", CENTER = "CENTER", TOP = "TOP"}

----------------------------------------------------------------------------------------------------
-- Paths
---------------------------------------------------------------------------------------------------

ThreatPlates.Art = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\"
ThreatPlates.Widgets = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Widgets\\"

---------------------------------------------------------------------------------------------------
-- Global contstants for options dialog
---------------------------------------------------------------------------------------------------

ThreatPlates.DebuffMode = {
  ["whitelist"] = L["White List"],
  ["blacklist"] = L["Black List"],
  ["whitelistMine"] = L["White List (Mine)"],
  ["blacklistMine"] = L["Black List (Mine)"],
  ["all"] = L["All Auras"],
  ["allMine"] = L["All Auras (Mine)"]
}

ThreatPlates.SPEC_ROLES = {
  DEATHKNIGHT = { true, false, false },
  DEMONHUNTER = { false, true },
  DRUID 			= { false, false, true, false },
  HUNTER			= { false, false, false },
  MAGE				= { false, false, false },
  MONK 				= { true, false, false },
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
  CLASS = "By Class",
  CUSTOM = "By Custom Color",
  REACTION = "By Reaction",
  HEALTH = "By Health",
}

ThreatPlates.FRIENDLY_TEXT_COLOR = {
  CLASS = "By Class",
  CUSTOM = "By Custom Color",
  REACTION = "By Reaction",
  HEALTH = "By Health",
}

-- NPC Role, Guild, or Quest", "Quest",
ThreatPlates.ENEMY_SUBTEXT = {
  NONE = "None",
  HEALTH = "Health",
  ROLE = "NPC Role",
  ROLE_GUILD = "NPC Role, Guild",
  ROLE_GUILD_LEVEL = "NPC Role, Guild, or Level",
  LEVEL = "Level",
  ALL = "Everything"
}

-- "NPC Role, Guild, or Quest", "Quest"
ThreatPlates.FRIENDLY_SUBTEXT = {
  NONE = "None",
  HEALTH = "Health",
  ROLE = "NPC Role",
  ROLE_GUILD = "NPC Role, Guild",
  ROLE_GUILD_LEVEL = "NPC Role, Guild, or Level",
  LEVEL = "Level",
  ALL = "Everything"
}

-------------------------------------------------------------------------------
-- Totem data - define it one time for the whole addon
-------------------------------------------------------------------------------

ThreatPlates.TOTEM_DATA = {
  -- Totems from Totem Mastery
  [1]  = {202188, "M1",  "b8d1ff"}, 	-- Resonance Totem
  [2]  = {210651, "M2",	 "b8d1ff"},		-- Storm Totem
  [3]  = {210657, "M3",  "b8d1ff"},		-- Ember Totem
  [4]  = {210660, "M4",  "b8d1ff"},		-- Tailwind Totem

  -- Totems from spezialization
  [5]  = {98008,  "S1",  "ffb31f"},		-- Spirit Link Totem
  [6]  = {5394,	  "S2",  "ffb31f"},		-- Healing Stream Totem
  [7]  = {108280, "S3",  "ffb31f"},		-- Healing Tide Totem
  [8]  = {160161, "S4",  "ffb31f"}, 	-- Earthquake Totem
  [9]  = {2484, 	"S5",	 "ffb31f"},  	-- Earthbind Totem (added patch 7.2, TP v8.4.0)

  -- Lonely fire totem
  [10] = {192222, "F1",  "ff8f8f"}, 	-- Liquid Magma Totem

  -- Totems from talents
  [11] = {157153, "N1",  "4c9900"},		-- Cloudburst Totem
  [12] = {51485,  "N2",  "4c9900"},		-- Earthgrab Totem
  [13] = {192058, "N3",  "4c9900"},		-- Lightning  Surge Totem
  [14] = {207399, "N4",  "4c9900"},		-- Ancestral Protection Totem
  [15] = {192077, "N5",  "4c9900"},		-- Wind Rush Totem
  [16] = {196932, "N6",  "4c9900"},		-- Voodoo Totem
  [17] = {198838, "N7",  "4c9900"},		-- Earthen Shield Totem

  -- Totems from PVP talents
  [18] = {204331, "P1",  "2b76ff"},	-- Counterstrike Totem
  [19] = {204330, "P2",  "2b76ff"},	-- Skyfury Totem
  [20] = {204332, "P3",  "2b76ff"},	-- Windfury Totem
  [21] = {204336, "P4",  "2b76ff"},	-- Grounding Totem
}

ThreatPlates.TOTEMS = {}

local function GetTotemSettings()
  local totem_list = ThreatPlates.TOTEMS

  local settings = { hideHealthbar = false }
  for no, totem_data in ipairs(ThreatPlates.TOTEM_DATA) do
    local totem_spell_id = totem_data[1]
    local totem_id = totem_data[2]
    local totem_color = RGB(HEX2RGB(totem_data[3]))

    totem_list[TotemNameBySpellID(totem_spell_id)] = totem_id

    --	["Reference"] = {allow totem nameplate, allow hp color, r, g, b, show icon, style}
    settings[totem_id] = {
      true, -- allow totem nameplate
      true, -- allow hp color
      true, -- show icon
      nil,
      nil,
      nil,
      "normal", -- style
      color = totem_color, -- color of totem's healtbar
    }
  end

  return settings
end

---------------------------------------------------------------------------------------------------
-- Default settings for ThreatPlates
---------------------------------------------------------------------------------------------------

ThreatPlates.DEFAULT_SETTINGS = {
  global = {
    version = "",
    -- versioncheck = false,
    CheckNewLookAndFeel = false,
    DefaultsVersion = "SMOOTH",
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
    spec = {
      [1] = false,
      [2] = false,
    },
    stances = {
      ON = false,
      [0] = false, -- No Stance
      [1] = false, -- Battle Stance
      [2] = true, -- Defensive Stance
      [3] = false -- Berserker Stance
    },
    shapeshifts = {
      ON = false,
      [0] = false, -- Caster Form
      [1] = true, -- Bear Form
      [2] = false, -- Cat Form
      [3] = false, -- Travel Form
      [4] = false, -- Moonkin Form, Tree of Life
    },
    presences = {
      ON = false,
      [0] = false, -- No Presence
      [1] = true, -- Blood
      [2] = false, -- Frost
      [3] = false -- Unholy
    },
    seals = {
      ON = false,
      [0] = false, -- No Aura
      [1] = true, -- Devotion Aura
      [2] = false, -- Retribution Aura
      [3] = false, -- Concentration Aura
      [4] = false, -- Resistance Aura
      [5] = false -- Crusader Aura
    },
  },
  profile = {
    cache = {},
    OldSetting = true,
    verbose = false,
    blizzFadeA = {
      toggle  = true,
      amount = -0.3
    },
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
    cacheClass = false,
    optionRoleDetectionAutomatic = true, -- old default: false,
    ShowThreatGlowOnAttackedUnitsOnly = true,
    ShowThreatGlowOffTank = true,
    NamePlateEnemyClickThrough = false,
    NamePlateFriendlyClickThrough = false,
    ShowFriendlyBlizzardNameplates = false,
    HeadlineView = {
      ON = false,
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
      blizzFading = true,
      blizzFadingAlpha = 1,
      useScaling = false,
      ShowTargetHighlight = true,
      ShowMouseoverHighlight = true,
      ForceHealthbarOnTarget = false,
      ForceOutOfCombat = false,
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
    },
    castbarColor = {
      toggle = true,
      r = 1,
      g = 0.56,
      b = 0.06,
      a = 1
    },
    castbarColorShield = {
      toggle = true,
      r = 1,
      g = 0,
      b = 0,
      a = 1
    },
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
    },
    text = {
      amount = false, -- old default: true,
      percent = true,
      full = false,
      max = false,
      deficit = false,
      truncate = true
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
    },
    healerTracker = {
      ON = true,
      scale = 1,
      x = 0,
      y = 35,
      level = 1,
      anchor = "CENTER"
    },
    debuffWidget = {
      ON = false,
      x = 18,
      y = 32,
      mode = "blacklistMine",
      style = "square",
      displays = {
        [1] = true,
        [2] = true,
        [3] = true,
        [4] = true,
        [5] = true,
        [6] = true
      },
      targetOnly = false,
      cooldownSpiral = true,
      showFriendly = true,
      showEnemy = true,
      scale = 1,
      anchor = "CENTER",
      filter = {}
    },
    AuraWidget = {
      ON = true,
      x = 0,
      y = 5,
      x_hv = 0,
      y_hv = 5,
      scale = 1,
      anchor = "TOP",
      ShowInHeadlineView = false,
      ShowEnemy = true,
      ShowFriendly = true,
      FilterMode = "blacklistMine",
      FilterByType = {
        [1] = true,
        [2] = true,
        [3] = true,
        [4] = true,
        [5] = true,
        [6] = true
      },
      FilterBySpell = {},
      ShowTargetOnly = false,
      ShowCooldownSpiral = false,
      ShowStackCount = true,
      ShowAuraType = true,
      DefaultBuffColor = RGB(102, 0, 51, 1),
      DefaultDebuffColor = 	RGB(204, 0, 0, 1),
      -- DebuffTypeColor["none"]	= { r = 0.80, g = 0, b = 0 };
      SortOrder = "TimeLeft",
      SortReverse = false,
      AlignmentH = "LEFT",
      AlignmentV = "BOTTOM",
      ModeIcon = {
        Columns = 5,
        Rows = 3,
        ColumnSpacing = 5,
        RowSpacing = 8,
        Style = "square",
      },
      ModeBar = {
        Enabled = false,
        BarHeight = 14,
        BarWidth = 100,
        BarSpacing = 2,
        MaxBars = 10,
        Texture = "Smooth", -- old default: "Aluminium",
        Font = "Arial Narrow",
        FontSize = 10,
        FontColor = RGB(255, 255, 255),
        LabelTextIndent = 4,
        TimeTextIndent = 4,
        BackgroundTexture = "Smooth",
        BackgroundColor = RGB(0, 0, 0, 0.3),
        BackgroundBorder = "squareline",
        BackgroundBorderEdgeSize = 2,
        BackgroundBorderInset = -4,
        BackgroundBorderColor = RGB(0, 0, 0, 0.3),
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
      x = -74,
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
    comboWidget = {
      ON = false,
      scale = 1,
      x = 0,
      y = -8,
      x_hv = 0,
      y_hv = -8,
      ShowInHeadlineView = false,
    },
    --      eliteWidget = {
    --        ON = true,
    --        theme = "default",
    --        scale = 15,
    --        x = 64,
    --        y = 9,
    --        anchor = "CENTER"
    --      },
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
      BorderTexture = "squareline",
      BorderEdgeSize = 8,
      BorderOffset = 2,
      BorderUseForegroundColor = false,
      BorderUseBackgroundColor = false,
      BorderColor = RGB(255, 255, 255, 1),
      --BorderInset = 4,
      --BorderTileSize = 16,
      ShowText = true,
      Font = DEFAULT_FONT,
      FontSize = 10,
      FontColor = RGB(255, 255, 255),
    },
    totemSettings = GetTotemSettings(),
    uniqueSettings = {
      list = {},
      ["**"] = {
        name = "",
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
        icon = "",
        scale = 1,
        alpha = 1,
        color = {
          r = 1,
          g = 1,
          b = 1
        },
      },
      [1] = {
        name = L["Shadow Fiend"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U1",
        scale = 0.45,
        alpha = 1,
        color = {
          r = 0.61,
          g = 0.40,
          b = 0.86
        },
      },
      [2] = {
        name = L["Spirit Wolf"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U2",
        scale = 0.45,
        alpha = 1,
        color = {
          r = 0.32,
          g = 0.7,
          b = 0.89
        },
      },
      [3] = {
        name = L["Ebon Gargoyle"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U3",
        scale = 0.45,
        alpha = 1,
        color = {
          r = 1,
          g = 0.71,
          b = 0
        },
      },
      [4] = {
        name = L["Water Elemental"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U4",
        scale = 0.45,
        alpha = 1,
        color = {
          r = 0.33,
          g = 0.72,
          b = 0.44
        },
      },
      [5] = {
        name = L["Treant"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U5",
        scale = 0.45,
        alpha = 1,
        color = {
          r = 1,
          g = 0.71,
          b = 0
        },
      },
      [6] = {
        name = L["Viper"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U6",
        scale = 0.45,
        alpha = 1,
        color = {
          r = 0.39,
          g = 1,
          b = 0.11
        },
      },
      [7] = {
        name = L["Venomous Snake"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U6",
        scale = 0.45,
        alpha = 1,
        color = {
          r = 0.75,
          g = 0,
          b = 0.02
        },
      },
      [8] = {
        name = L["Army of the Dead Ghoul"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U7",
        scale = 0.45,
        alpha = 1,
        color = {
          r = 0.87,
          g = 0.78,
          b = 0.88
        },
      },
      [9] = {
        name = L["Shadowy Apparition"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U8",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.62,
          g = 0.19,
          b = 1
        },
      },
      [10] = {
        name = L["Shambling Horror"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U9",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.69,
          g = 0.26,
          b = 0.25
        },
      },
      [11] = {
        name = L["Web Wrap"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U10",
        scale = 0.75,
        alpha = 1,
        color = {
          r = 1,
          g = 0.39,
          b = 0.96
        },
      },
      [12] = {
        name = L["Immortal Guardian"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U11",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.33,
          g = 0.33,
          b = 0.33
        },
      },
      [13] = {
        name = L["Marked Immortal Guardian"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U12",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.75,
          g = 0,
          b = 0.02
        },
      },
      [14] = {
        name = L["Empowered Adherent"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U13",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.29,
          g = 0.11,
          b = 1
        },
      },
      [15] = {
        name = L["Deformed Fanatic"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U14",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.55,
          g = 0.7,
          b = 0.29
        },
      },
      [16] = {
        name = L["Reanimated Adherent"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U15",
        scale = 1,
        alpha = 1,
        color = {
          r = 1,
          g = 0.88,
          b = 0.61
        },
      },
      [17] = {
        name = L["Reanimated Fanatic"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U15",
        scale = 1,
        alpha = 1,
        color = {
          r = 1,
          g = 0.88,
          b = 0.61
        },
      },
      [18] = {
        name = L["Bone Spike"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U16",
        scale = 1,
        alpha = 1,
        color = {
          r = 1,
          g = 1,
          b = 1
        },
      },
      [19] = {
        name = L["Onyxian Whelp"],
        showNameplate = false,
        ShowHealthbarView = true,
        ShowHeadlineView = false,
        showIcon = true,
        useStyle = true,
        useColor = true,
        UseThreatColor = false,
        UseThreatGlow = false,
        allowMarked = true,
        overrideScale = false,
        overrideAlpha = false,
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U17",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.33,
          g = 0.28,
          b = 0.71
        },
      },
      [20] = {
        name = L["Gas Cloud"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U18",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.96,
          g = 0.56,
          b = 0.07
        },
      },
      [21] = {
        name = L["Volatile Ooze"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U19",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.36,
          g = 0.95,
          b = 0.33
        },
      },
      [22] = {
        name = L["Darnavan"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U20",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.78,
          g = 0.61,
          b = 0.43
        },
      },
      [23] = {
        name = L["Val'kyr Shadowguard"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U21",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.47,
          g = 0.89,
          b = 1
        },
      },
      [24] = {
        name = L["Kinetic Bomb"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U22",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.91,
          g = 0.71,
          b = 0.1
        },
      },
      [25] = {
        name = L["Lich King"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U23",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.77,
          g = 0.12,
          b = 0.23
        },
      },
      [26] = {
        name = L["Raging Spirit"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U24",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.77,
          g = 0.27,
          b = 0
        },
      },
      [27] = {
        name = L["Drudge Ghoul"],
        showNameplate = true,
        ShowHeadlineView = false,
        showIcon = false,
        useStyle = true,
        useColor = true,
        UseThreatColor = false,
        UseThreatGlow = false,
        allowMarked = true,
        overrideScale = false,
        overrideAlpha = false,
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U25",
        scale = 0.85,
        alpha = 1,
        color = {
          r = 0.43,
          g = 0.43,
          b = 0.43
        },
      },
      [28] = {
        name = L["Living Inferno"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U27",
        scale = 1,
        alpha = 1,
        color = {
          r = 0,
          g = 1,
          b = 0
        },
      },
      [29] = {
        name = L["Living Ember"],
        showNameplate = true,
        ShowHeadlineView = false,
        showIcon = false,
        useStyle = true,
        useColor = true,
        UseThreatColor = false,
        UseThreatGlow = false,
        allowMarked = true,
        overrideScale = false,
        overrideAlpha = false,
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U28",
        scale = 0.60,
        alpha = 0.75,
        color = {
          r = 0.25,
          g = 0.25,
          b = 0.25
        },
      },
      [30] = {
        name = L["Fanged Pit Viper"],
        showNameplate = false,
        ShowHealthbarView = true,
        ShowHeadlineView = false,
        showIcon = false,
        useStyle = true,
        useColor = true,
        UseThreatColor = false,
        UseThreatGlow = false,
        allowMarked = true,
        overrideScale = false,
        overrideAlpha = false,
        icon = "",
        scale = 0,
        alpha = 0,
        color = {
          r = 1,
          g = 1,
          b = 1
        },
      },
      [31] = {
        name = L["Canal Crab"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U29",
        scale = 1,
        alpha = 1,
        color = {
          r = 0,
          g = 1,
          b = 1
        },
      },
      [32] = {
        name = L["Muddy Crawfish"],
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
        icon = "Interface\\Addons\\TidyPlates_ThreatPlates\\Widgets\\UniqueIconWidget\\U30",
        scale = 1,
        alpha = 1,
        color = {
          r = 0.96,
          g = 0.36,
          b = 0.34
        },
      },
      [33] = {},
      [34] = {},
      [35] = {},
      [36] = {},
      [37] = {},
      [38] = {},
      [39] = {},
      [40] = {},
      [41] = {},
      [42] = {},
      [43] = {},
      [44] = {},
      [45] = {},
      [46] = {},
      [47] = {},
      [48] = {},
      [49] = {},
      [50] = {},
      [51] = {},
      [52] = {},
      [53] = {},
      [54] = {},
      [55] = {},
      [56] = {},
      [57] = {},
      [58] = {},
      [59] = {},
      [60] = {},
      [61] = {},
      [62] = {},
      [63] = {},
      [64] = {},
      [65] = {},
      [66] = {},
      [67] = {},
      [68] = {},
      [69] = {},
      [70] = {},
      [71] = {},
      [72] = {},
      [73] = {},
      [74] = {},
      [75] = {},
      [76] = {},
      [77] = {},
      [78] = {},
      [79] = {},
      [80] = {},
    },
    settings = {
      frame = {
        y = 0,
      },
      highlight = {
        texture = "TP_HealthBarHighlight",
      },
      elitehealthborder = {
        texture = "TP_HealthBarEliteOverlay",
        show = false, -- old default: true
      },
      healthborder = {
        texture = "TP_HealthBarOverlayThin", -- old default: "TP_HealthBarOverlay",
        backdrop = "",
        show = true,
      },
      threatborder = {
        show = true,
      },
      healthbar = {
        texture = "Smooth", -- old default: "ThreatPlatesBar",
        --backdrop = nil,
        backdrop = "Smooth", -- old default: "ThreatPlatesEmpty",
        BackgroundUseForegroundColor = false,
        BackgroundOpacity = 0.3, -- old default: 1,
        BackgroundColor = RGB(0, 0, 0),
      },
      castnostop = {
        texture = "TP_CastBarLock",
        x = 0,
        y = -15,
        show = true,
        ShowOverlay = true,
      },
      castborder = {
        texture = "TP_CastBarOverlayThin", -- old default: "TP_CastBarOverlay",
        x = 0,
        y = -15,
        show = true,
      },
      castbar = {
        texture = "Smooth", -- old default: "ThreatPlatesBar",
        x = 0,
        y = -15,
        x_hv = 0,
        y_hv = -15,
        show = true,
        ShowInHeadlineView = false,
      },
      name = { -- Names for Healthbar View
        show = true,
        typeface = DEFAULT_FONT, -- old default: "Accidental Presidency",
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
        typeface = DEFAULT_FONT, -- old default: "Accidental Presidency",
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
        typeface = DEFAULT_FONT, -- old default: "Accidental Presidency",
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
        typeface = DEFAULT_FONT, -- old default: "Accidental Presidency",
        size = 8,  -- old default: 12
        width = 110,
        height = 14,
        x = 0,
        y = -14,  -- old default: -13
        x_hv = 0,
        y_hv = -14,  -- old default: -13
        align = "CENTER",
        vertical = "CENTER",
        shadow = true,
        flags = "NONE",
        show = true,
      },
      raidicon = {
        scale = 20,
        x = 0,
        y = 30, -- old default: 27
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
        x = 75,
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
      nonCombat = true,
      hideNonCombat = false,
      useType = true,
      useScale = true,
      useAlpha = true,
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
        ["TargetA"]  = false, -- Custom Target Alpha
        ["NoTargetA"]  = false, -- Custom Target Alpha
        ["TargetS"]  = false, -- Custom Target Scale
        ["NoTargetS"]  = false, -- Custom Target Alpha
        ["MarkedA"] = false,
        ["MarkedS"] = false,
        ["CastingUnitAlpha"] = false, -- Friendly Unit Alpha
        ["CastingEnemyUnitAlpha"] = false,
        ["CastingUnitScale"] = false, -- Friendly Unit Scale
        ["CastingEnemyUnitScale"] = false,
        ["MouseoverUnitAlpha"] = false,
      },
      scale = {
        ["Target"]	  	     = 1,
        ["NoTarget"]	       = 1,
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
        ["Target"]		       = 1,
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
      },
    },
  }
}