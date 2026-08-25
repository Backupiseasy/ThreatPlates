---------------------------------------------------------------------------------------------------
-- Auras Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

if not Addon.ExpansionIsAtLeastMidnight then return end

local Widget = Addon.Widgets:NewWidget("Auras")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local min = min

-- ThreatPlates APIs
local FontUpdateText = Addon.Font.UpdateText
local AuraTriggerInitialize, AuraTriggerUpdateStyle = Addon.Style.AuraTriggerInitialize, Addon.Style.AuraTriggerUpdateStyle
local MODE_FOR_STYLE, AnchorFrameTo = Addon.MODE_FOR_STYLE, Addon.AnchorFrameTo
local UnitIsUnitTP = Addon.UnitIsUnit

-- Patch 12.1.0: AuraContainer/AuraButton is Blizzard's replacement for addon-side aura scanning
-- (AuraUtil.ForEachAura/C_UnitAuras.GetUnitAuras) - it's secret-safe by design (Blizzard owns aura
-- fetching internally once SetUnit() is called), whereas the old addon-side pull model can throw or
-- come back empty for nameplate unit tokens even outside restricted periods [GH-723]. This is the
-- only aura display path in this widget; there is no addon-side fallback. Feature-detected via a
-- template-existence check, since there is no dedicated expansion-level flag for this.
local HasAuraContainers = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") and true or false
local AuraContainerSortMethod = _G.AuraContainerSortMethod
local AuraContainerSortDirection = _G.AuraContainerSortDirection
local LuaCurveTypeStep = _G.Enum.LuaCurveType.Step
local DispelTypeTextureStylePreserveAsset = _G.Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset
local DurationTextBindingPropertyRemainingDuration = _G.Enum.DurationTextBindingProperty.RemainingDuration

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, UIParent, InCombatLockdown, AnchorUtil, PixelUtil

---------------------------------------------------------------------------------------------------
-- Crowd Control Auras
---------------------------------------------------------------------------------------------------

local CROWD_CONTROL_SPELLS_BY_EXPANSION = {
  MAINLINE = {},
}

Widget.CROWD_CONTROL_SPELLS = CROWD_CONTROL_SPELLS_BY_EXPANSION[Addon.GetExpansionLevel()]

---------------------------------------------------------------------------------------------------
-- Cached configuration settings
---------------------------------------------------------------------------------------------------
local HideOmniCC, ShowDuration
local EnabledForStyle = {}

---------------------------------------------------------------------------------------------------
-- AuraContainer (Patch 12.1.0)
---------------------------------------------------------------------------------------------------
-- Buffs, Debuffs, and CrowdControl are all AuraContainer-driven, for both friendly and enemy units.
--
-- Known simplifications versus the addon's pre-AuraContainer Filter*BySpell functions:
-- - Buffs and Debuffs (both reactions) support independent, freely-combinable OR-conditions via one
--   AddAuraGroup per condition (see BuildGroupConfigsFromConditions and its callers). ShowAll*/
--   ShowOn*NPCs always short-circuit into a single unrestricted group first, though - "All on NPCs" is
--   conceptually "All, but scoped to NPCs", not a peer condition, and can't be freely combined with
--   the others the normal way (no candidateFilters field for "unit is an NPC" to cross-exclude it
--   with). Buffs (both reactions) additionally supports MaxDuration as an AND-restriction on top of
--   whichever OR-condition(s) are active - filters out permanent/long-duration passive buffs (flasks,
--   food, Well Fed, ...); not offered on Debuffs, where a duration cap is rarely useful. CrowdControl
--   (either reaction) is still single-condition
--   only (All vs. Dispellable, a plain "elseif") - not converted to the multi-group pattern.
-- - A crowd-control-classified aura is strictly exclusive to the CrowdControl grid (filtered out of
--   Debuffs via "!CROWD_CONTROL"); the old per-aura fallback (show as a normal debuff if the
--   CC-specific filter rejects it) is not replicated.
-- - SwitchAreaByReaction (swapping which screen position shows buffs vs. debuffs for friendly units)
--   is not implemented - each AuraContainer's aura type (buff/debuff) is now fixed to its own screen
--   position for both reactions.
-- - SortOrder "Duration"/"Creation" have no AuraContainerSortMethod equivalent and fall back to
--   Default (None/AtoZ/TimeLeft+Reverse are supported via GetSortMethod/GetSortDirection).
-- - Per-spell FilterBySpell (spell name/ID text list) is not implemented; candidateFilters.
--   includeSpellIDs/excludeSpellIDs would only be usable for Debuffs+CrowdControl on enemies anyway
--   (Blizzard restricts spell-ID candidate filters to helpful-on-assistable/harmful-on-non-assistable).
-- - Icon size, tooltip-enable, cooldown-spiral visibility, stack-count/duration-text visibility, and
--   their font/size/color/position styling all DO propagate live to already-pooled AuraButtons (see
--   ReapplyLiveAuraButtonSettings, called from Widget:UpdateSettings) - none of AuraButton's
--   ForbiddenAspects block plain Set* calls, lazily creating a FontString the first time a toggle
--   turns on, or re-running FontUpdateText, and GetAuraGroupFrame/GetAuraGroupFrameCount are real
--   addon-facing methods to reach already-created buttons. Only whether the dispel-type border is
--   drawn at all (ShowAuraType/ShowBorder) is still create-time-only - its underlying
--   AddDispelTypeTexture call registers a whole binding, not just a property, with no known safe way
--   to swap it once registered - changing that in Options during the same session only takes effect on
--   newly-pooled buttons, not already-pooled ones.
-- - The demo/preview "Configuration Mode" and the aura-trigger custom-plate-style system (both
--   already non-functional prior to this) have no equivalent hook into AuraContainer and remain
--   unavailable.
-- - Debuffs' "dispeltype" group (FilterByType[1-4]) does not exclude the other Debuffs groups from
--   itself (an aura matching a checked dispel type AND e.g. Boss shows via both groups); this is a
--   real gap, unlike the reverse direction (other groups excluding checked dispel types from
--   themselves via candidateFilters.excludeDispelTypes), which is handled - see
--   GetEnemyDebuffsGroupConfigs/GetFriendlyDebuffsGroupConfigs.

-- Without this, auras Blizzard flags as nameplate-only are silently excluded (AuraUtil.lua's
-- IncludeNameplateOnly doc comment). Blizzard's own default nameplates always include this token in
-- both their buff and debuff filter strings (Blizzard_NamePlateAuras.lua) - matched here for parity.
local NAMEPLATE_ONLY = "INCLUDE_NAME_PLATE_ONLY"

-- Square (not Blizzard's rounded-corner atlas) dispel-type border texture, 64x64 with alpha - see
-- InitializeAuraButton's DispelBorder setup. squareline.tga (the legacy widget's Backdrop border
-- asset) turned out to be a 128x16 tileable edge *strip* built for SetBackdrop's edgeFile tiling, not
-- a square 9-slice-able frame - wrong shape for SetTextureSliceMargins, confirmed live to not work.
local AURA_BORDER_TEXTURE = Addon.ADDON_DIRECTORY .. "Artwork\\NinesliceBorder"
-- Sliced (not plain stretch): with a flush, 0-outset frame (matching the icon exactly, no gap), plain
-- stretch couples ring thickness and position - making the frame bigger to get a thicker ring also
-- pushes the ring's inner edge (and the transparent "hole" around it) away from the icon, leaving a
-- visible gap - confirmed live. SetTextureSliceMargins keeps the corner/edge band at native
-- texture-pixel size independent of the frame's overall size, so thickness can be tuned via
-- AURA_BORDER_THICKNESS below without moving the frame off the icon at all.
local AURA_BORDER_TEXTURE_BAND = 8
local AURA_BORDER_THICKNESS = 6

local AURA_CONTAINER_POOL_SIZE = 40 -- matches the practical max concurrent nameplate count
local AURA_CONTAINER_TYPES = { "Buffs", "Debuffs", "CrowdControl" }
-- AddAuraGroup keys declared per aura type - Debuffs (either reaction) and Buffs (friendly) get one
-- group per independent OR-condition (see GetEnemyDebuffsGroupConfigs/GetFriendlyDebuffsGroupConfigs/
-- GetFriendlyBuffsGroupConfigs); Buffs (enemy) and CrowdControl (either reaction) only ever use "main".
local AURA_GROUP_KEYS = {
  Buffs = { "main", "canapply", "bigdefensive", "dispellable", "magic" },
  Debuffs = { "main", "important", "importantpersonal", "boss", "priority", "dispellable", "dispeltype" },
  CrowdControl = { "main" },
}
local DISPEL_TYPE_NAMES = { "Curse", "Disease", "Magic", "Poison" } -- index matches Debuffs.FilterByType[1..4]

-- Dispel-type border coloring (AuraWidget.ShowAuraType, shared across Buffs/Debuffs/CrowdControl -
-- see Constants.lua). AddDispelTypeTexture's customDispelColorMap wants real Color objects (needs
-- :GetRGBA()), not the plain {r=,g=,b=} tables _G.DebuffTypeColor (or the legacy AurasWidget.lua
-- fallback of the same shape) provides - built once here. customDispelColorCurve (a C_CurveUtil color
-- curve) is the alternative Blizzard also supports, but customDispelColorMap is a plain name->color
-- table and needs no curve object to reconstruct, so it's used here instead.
local function BuildDispelTypeColorMap()
  local source = _G.DebuffTypeColor or {
    Magic = { r = 0.20, g = 0.60, b = 1.00 },
    Disease = { r = 0.60, g = 0.40, b = 0.00 },
    Poison = { r = 0.00, g = 0.60, b = 0.00 },
    Curse = { r = 0.60, g = 0.00, b = 1.00 },
  }
  local map = {}
  for _, dispel_name in ipairs(DISPEL_TYPE_NAMES) do
    local color = source[dispel_name]
    if color then
      map[dispel_name] = _G.CreateColor(color.r, color.g, color.b, 1)
    end
  end
  return map
end

local DISPEL_TYPE_COLOR_MAP = BuildDispelTypeColorMap()

-- customDispelColorMap's lookup key for an aura with no dispel type is the literal string "None"
-- (Blizzard_CustomAuraButton.lua's GetDispelTypeMapKey: `auraData.dispelName or "None"`) - adding a
-- "None" entry here is what lets AuraWidget.DefaultBuffColor/DefaultDebuffColor (Options: Appearance
-- -> Highlight -> Buff/Debuff Color) actually take effect, matching the legacy widget's
-- Widget:GetColorForAura (DebuffTypeColor[dispelName] or DefaultDebuffColor for harmful auras,
-- DefaultBuffColor otherwise). Built per aura_type (not once globally, unlike DISPEL_TYPE_COLOR_MAP
-- above) since Buffs vs. Debuffs/CrowdControl need a different default color - CrowdControl auras are
-- always harmful, so they share Debuffs' DefaultDebuffColor, same as the legacy widget's
-- `aura.effect == "HARMFUL"` check.
-- One map per aura_type, not rebuilt on every call (InitializeAuraButton calls this per button - up
-- to 40x per pool - plus once per button again on every ReapplyLiveAuraButtonSettings recolor pass).
-- Unlike GetExpiringColorCurve's cache, this one DOES need invalidating - DefaultBuffColor/
-- DefaultDebuffColor/ShowAuraType can change live and the recolor pass depends on picking that up (see
-- ReapplyLiveAuraButtonSettings) - InvalidateDispelTypeColorMapCache is called from
-- Widget:UpdateSettings, before anything reads this, so a changed color always rebuilds fresh before
-- it's used.
local DispelTypeColorMapCache = {}
local function InvalidateDispelTypeColorMapCache()
  DispelTypeColorMapCache = {}
end
local function GetDispelTypeColorMapForAuraType(aura_type)
  local map = DispelTypeColorMapCache[aura_type]
  if not map then
    map = {}
    for dispel_name, color in pairs(DISPEL_TYPE_COLOR_MAP) do
      map[dispel_name] = color
    end
    local default_color = (aura_type == "Buffs") and Widget.db.DefaultBuffColor or Widget.db.DefaultDebuffColor
    map.None = _G.CreateColor(default_color.r, default_color.g, default_color.b, default_color.a or 1)
    DispelTypeColorMapCache[aura_type] = map
  end
  return map
end

-- ModeIcon.ShowBorder off + AuraWidget.ShowAuraType off (legacy: AurasWidget.lua:3049,
-- SetBackdropBorderColor(0, 0, 0, 1) at border creation, never overwritten unless ShowAuraType is
-- also on) - a flat black map for every possible customDispelColorMap key, reusing the same
-- AddDispelTypeTexture mechanism instead of a second, separate border texture/code path.
local BLACK_DISPEL_COLOR_MAP = {}
do
  local black = _G.CreateColor(0, 0, 0, 1)
  for _, dispel_name in ipairs(DISPEL_TYPE_NAMES) do
    BLACK_DISPEL_COLOR_MAP[dispel_name] = black
  end
  BLACK_DISPEL_COLOR_MAP.None = black
end

local AuraContainerPool = { Buffs = {}, Debuffs = {}, CrowdControl = {} }
local NextAuraContainerIndex = { Buffs = 1, Debuffs = 1, CrowdControl = 1 }

-- Icon crop per ModeIcon.Style - removes each icon texture's own baked-in border pixels (not related
-- to ModeIcon.ShowBorder/the dispel-type border texture, which is a separate overlay). Previously
-- hardcoded to the "square" crop unconditionally regardless of Style, in both this widget and the
-- legacy AurasWidget.lua (which even carries the intended "wide" crop as a dead, commented-out line -
-- AurasWidget.lua:3036, typo'd "Widee" - never wired up). A "wide" icon's aspect ratio needs a bigger
-- vertical crop than "square" to look right; using the square crop on a wide icon under-crops
-- vertically, leaving the source texture's border artifacts visible - which reads as the dispel-type
-- border (drawn at a fixed -3/+3 outset from the icon, unaffected by TexCoord) sitting too far inward
-- relative to the visibly-uncropped icon content. "custom" (arbitrary width/height, no fixed aspect)
-- has no clean formula - falls back to the square crop, matching prior behavior.
local AURA_ICON_TEX_COORD = {
  square = { .10, 1 - .07, .12, 1 - .12 },
  wide = { .07, 1 - .07, .23, 1 - .23 },
}

-- Midnight replacement for AuraWidget.FlashWhenExpiring/FlashTime (Classic-only - no equivalent exists
-- on Midnight, AuraButton has no script-hook for addon-attached icon effects, see the wiki's
-- AddDispelTypeTexture/glow discussion). Colors the duration text itself via a live Blizzard-driven
-- binding (SetDurationText's options.textColor) instead of flashing the icon - a Step curve (no
-- interpolation, hard cutoff at ExpiringColorThreshold) snapping to ExpiringColor below the threshold
-- and back to the aura_type's normal duration-text color above it. AddPoint needs real Color objects
-- (colorRGBA/ColorMixin), not the plain {r=,g=,b=,a=} tables this addon's own color fields use - same
-- CreateColor() wrapping GetDispelTypeColorMapForAuraType already does for the same reason.
local function BuildExpiringColorCurve(normal_color)
  local curve = _G.C_CurveUtil.CreateColorCurve()
  curve:SetType(LuaCurveTypeStep)
  local expiring_color = Widget.db.ExpiringColor
  curve:AddPoint(0, _G.CreateColor(expiring_color.r, expiring_color.g, expiring_color.b, expiring_color.a or 1))
  curve:AddPoint(Widget.db.ExpiringColorThreshold, _G.CreateColor(normal_color.r, normal_color.g, normal_color.b, normal_color.a or 1))
  return curve
end

-- One curve per aura_type (Buffs/Debuffs/CrowdControl), not per AuraButton - ExpiringColor/
-- ExpiringColorThreshold are global and the "normal" endpoint color only varies by aura_type, so every
-- button of the same type would otherwise build (and leak) an identical curve object. Never
-- invalidated - ExpiringColor/ExpiringColorThreshold/Duration.Font.Color are create-time-only anyway
-- (SetDurationText's binding is never re-registered live - see ReapplyLiveAuraButtonSettings), and the
-- pool is only ever built once per session (PreallocateAuraContainers guards on #pool == 0), so a
-- stale cache entry can't outlive a /reload.
local ExpiringColorCurveCache = {}
local function GetExpiringColorCurve(aura_type, normal_color)
  local curve = ExpiringColorCurveCache[aura_type]
  if not curve then
    curve = BuildExpiringColorCurve(normal_color)
    ExpiringColorCurveCache[aura_type] = curve
  end
  return curve
end

local function InitializeAuraButton(auraButton, aura_type)
  local db_icon = Widget.db[aura_type].ModeIcon
  local tex_coord = AURA_ICON_TEX_COORD[db_icon.Style] or AURA_ICON_TEX_COORD.square

  auraButton.Icon = auraButton:CreateTexture(nil, "ARTWORK", nil, -5)
  auraButton.Icon:SetAllPoints(auraButton)
  auraButton.Icon:SetTexCoord(tex_coord[1], tex_coord[2], tex_coord[3], tex_coord[4])
  auraButton:SetIcon(auraButton.Icon)

  -- Rounds the icon's own corners to match the dispel-type border ring's rounded corners - without
  -- this, the icon (a plain rectangle, same size as the button) pokes its sharp square corners out
  -- past the border's rounded corner artwork, since the border sits 3px *outside* the icon (see
  -- below) and never overlaps/covers the icon's corner pixels at all. TexCoord can't fix this (it only
  -- crops which part of the source texture is sampled, not the icon's on-screen shape). Blizzard's own
  -- reference (CooldownViewer.xml) applies the identical fix to its icon via the same atlas.
  local iconMask = auraButton:CreateMaskTexture(nil, "ARTWORK", nil, -4)
  iconMask:SetAtlas("SquareMask", false)
  iconMask:SetAllPoints(auraButton.Icon)
  auraButton.Icon:AddMaskTexture(iconMask)

  -- ModeIcon.ShowBorder is the master on/off (legacy: AurasWidget.lua:3039/3053, Border:Show()/
  -- Hide()); AuraWidget.ShowAuraType only controls whether it's colored per dispel type or flat
  -- black - matching the legacy widget exactly (SetBackdropBorderColor(0,0,0,1) at creation, only
  -- overwritten by GetColorForAura's result when ShowAuraType is also on). Border style, always
  -- drawn once shown (showWithoutDispelType=true) - dispel-typed auras get their
  -- DISPEL_TYPE_COLOR_MAP color, everything else falls back to DefaultBuffColor/DefaultDebuffColor
  -- via the "None" map key (see GetDispelTypeColorMapForAuraType) when ShowAuraType is on.
  --
  -- style = PreserveAsset (not Border) + our own square texture - Blizzard's Border/BorderWithIcon
  -- styles are locked to Blizzard's own dispel-type atlas (ui-debuff-border-<type>-noicon), which is
  -- rounded-corner; PreserveAsset keeps whatever texture we already set via SetTexture below and
  -- only recolors it (AuraUtil.SetAuraBorderColor's own tint, then immediately overridden by our
  -- customDispelColorMap below - same override order as the Border style before it, confirmed from
  -- Blizzard_CustomAuraButton.lua's ApplyDispelTypeTextureStyle -> ApplyCustomDispelTypeTextureColor
  -- call order). Same safe mechanism either way - the color itself is still resolved without this
  -- widget ever reading auraData.dispelName in Lua.
  --
  -- The texture region itself is created unconditionally (not gated on ShowBorder) so it always
  -- originates from InitializeAuraButton's securecallfunction-wrapped context (same as everything
  -- else here), even if ShowBorder starts off - ReapplyLiveAuraButtonSettings only ever registers/
  -- clears AddDispelTypeTexture on this already-existing, already-validated texture object, never
  -- creates it from plain/tainted code itself.
  auraButton.DispelBorder = auraButton:CreateTexture(nil, "OVERLAY")
  auraButton.DispelBorder:SetTexture(AURA_BORDER_TEXTURE)
  auraButton.DispelBorder:SetTextureSliceMargins(AURA_BORDER_TEXTURE_BAND, AURA_BORDER_TEXTURE_BAND, AURA_BORDER_TEXTURE_BAND, AURA_BORDER_TEXTURE_BAND)
  -- Flush, 0 outset - see the AURA_BORDER_TEXTURE_BAND comment above for why thickness is tuned via
  -- SetScale instead of moving this frame off the icon.
  auraButton.DispelBorder:SetAllPoints(auraButton.Icon)
  auraButton.DispelBorder:SetScale(AURA_BORDER_THICKNESS / AURA_BORDER_TEXTURE_BAND)
  if db_icon.ShowBorder then
    auraButton:AddDispelTypeTexture(auraButton.DispelBorder, {
      style = DispelTypeTextureStylePreserveAsset,
      showWhenHarmful = true,
      showWhenHelpful = true,
      showWithoutDispelType = true,
      customDispelColorMap = Widget.db.ShowAuraType and GetDispelTypeColorMapForAuraType(aura_type) or BLACK_DISPEL_COLOR_MAP,
    })
  else
    -- A freshly CreateTexture()'d region is Shown by default with no vertex color applied - without
    -- ever calling AddDispelTypeTexture (which is what makes Blizzard's engine take over managing the
    -- texture's Shown/color state - see AddSecretAspect(Enum.SecretAspect.Shown) in
    -- Blizzard_CustomAuraButton.lua), it just stays visible as-is: the raw, untinted NinesliceBorder
    -- texture (looks white). Hide it explicitly for this case.
    auraButton.DispelBorder:Hide()
  end

  auraButton.Cooldown = Addon.CreateCooldown(auraButton, HideOmniCC)
  auraButton.Cooldown:SetShownSwipe(Widget.db.ShowCooldownSpiral, HideOmniCC)
  auraButton:SetDurationCooldown(auraButton.Cooldown)

  -- Always created (like DispelBorder above) so ReapplyLiveAuraButtonSettings never needs to create
  -- anything itself, only Show()/Hide() and restyle - matches how the FontString-creation-outside-
  -- Create taint risk was already avoided for DispelBorder.
  --
  -- Font must be set before SetApplicationCount below: it triggers an immediate
  -- UpdateAuraDisplay() -> FontString:SetText(), which errors ("Font not set") on a FontString
  -- that was just created with CreateFontString(nil, ...) and has no font applied yet.
  auraButton.Stacks = auraButton:CreateFontString(nil, "OVERLAY")
  auraButton.Stacks:SetJustifyH("right")
  auraButton.Stacks:SetPoint("BOTTOMRIGHT", 3, -2)
  FontUpdateText(auraButton, auraButton.Stacks, db_icon.StackCount)
  auraButton:SetApplicationCount(auraButton.Stacks)
  if not Widget.db.ShowStackCount then
    auraButton.Stacks:Hide()
  end

  -- Same font-before-Set* ordering requirement as SetApplicationCount above.
  auraButton.TimeLeft = auraButton:CreateFontString(nil, "OVERLAY")
  FontUpdateText(auraButton, auraButton.TimeLeft, db_icon.Duration)
  if Widget.db.ShowExpiringColor then
    auraButton:SetDurationText(auraButton.TimeLeft, {
      textColor = {
        curve = GetExpiringColorCurve(aura_type, db_icon.Duration.Font.Color),
        property = DurationTextBindingPropertyRemainingDuration,
      },
    })
  else
    auraButton:SetDurationText(auraButton.TimeLeft)
  end
  if not ShowDuration then
    auraButton.TimeLeft:Hide()
  end

  -- AuraButton tooltips are managed by Blizzard automatically (OnEnter/OnLeave are intrinsic, wired
  -- in Blizzard_AuraButton.xml, not addon-scriptable) - but ShowTooltip() calls
  -- tooltip:SetOwner(self, self:GetTooltipAnchorPoint()), and GetTooltipAnchorPoint() returns
  -- self.tooltipAnchorPoint, which is nil until SetTooltipAnchorPoint() is called at least once
  -- (OnLoad_Intrinsic never initializes it). Without this, SetOwner got a nil anchor and no tooltip
  -- ever appeared - confirmed by user report ("mouse over aura shows nothing") even with ShowTooltips
  -- enabled and SetMouseMotionEnabled/SetHideTooltipInCombat both correctly set.
  -- false, not true: Blizzard's own default unit-frame auras still show tooltips in combat (verified
  -- live by user), so hiding ours in combat was an unnecessary restriction, not something matching
  -- Blizzard's own behavior.
  auraButton:SetTooltipAnchorPoint("ANCHOR_RIGHT")
  auraButton:SetMouseMotionEnabled(Widget.db.ShowTooltips)
  auraButton:SetHideTooltipInCombat(false)

  PixelUtil.SetSize(auraButton, db_icon.IconWidth, db_icon.IconHeight)
end

-- Icon size, tooltip-enable, cooldown-spiral-visibility, stack-count/duration-text visibility, and
-- their font/size/color/position styling are the subset of InitializeAuraButton's settings that CAN be
-- safely reapplied to already-created AuraButtons after the fact - none of the AuraButton's
-- ForbiddenAspects (UntrustedScriptExecution, ChangeParent, ... - see Blizzard_AuraButton.xml) block
-- them. This function never *creates* anything itself (2026-08-21) - Stacks/TimeLeft/DispelBorder are
-- all created unconditionally in InitializeAuraButton now (same reasoning as DispelBorder's own
-- comment: keeps every CreateTexture/CreateFontString call inside InitializeAuraButton's
-- securecallfunction-wrapped context, never from this plain/tainted one), so this only ever restyles
-- (FontUpdateText - plain Set* calls) and toggles Show()/Hide() for ShowStackCount/ShowDuration.
-- Border re-coloring (not existence) is the one exception that still touches a binding
-- (AddDispelTypeTexture) live - see its own comment below for why that's confirmed safe while the
-- existence toggle isn't. The dispel-type border's *existence* (ShowBorder) is **not** covered here -
-- unlike a FontString's Show()/Hide(), toggling whether the border is registered at all turned out
-- unreliable on already-displayed buttons, so it still only takes effect on newly-pooled
-- buttons.
-- GetAuraGroupFrame/GetAuraGroupFrameCount are real addon-facing AuraContainer methods (not
-- Forbidden), so every already-created button - active or currently unused/available in the pool -
-- can be reached and re-styled. Called from Widget:UpdateSettings so changing IconWidth/IconHeight/
-- ShowTooltips/ShowCooldownSpiral/ShowStackCount/ShowDuration in Options actually takes effect
-- immediately, not just for auras created after the change.
--
-- AuraButton carries AccessRestrictionFlags = DenyTaintedAccessWhenAurasAreSecret
-- (Blizzard_AuraContainerShared.lua), and this call happens from plain (tainted) addon code, unlike
-- InitializeAuraButton's initial Set* calls, which run inside Blizzard's own securecallfunction
-- wrapper (Blizzard_AuraContainerFrameProviders.lua:79) and are therefore not tainted. Rather than
-- risk that restriction denying/erroring on individual buttons, deferred via Addon.ExecuteAfterCombatEnds
-- like every other setting this addon can't safely change mid-combat - warns once and re-runs
-- automatically after combat ends instead of silently doing nothing until the next settings change.
--
-- 2026-08-21, under active live testing: two conflicting data points so far - (1) with the
-- ExecuteAfterCombatEnds wrapper temporarily disabled for testing and the player actually in combat,
-- plain auraButton:SetSize() threw "Attempt to access forbidden object from code tainted by an AddOn"
-- (not just PixelUtil.SetSize's internal GetEffectiveScale - the object itself, any method); (2) with
-- PixelUtil.SetSize and the wrapper enabled, it reportedly worked fine out of combat. Consistent with
-- the restriction being genuinely combat/secret-aura-gated after all (as the flag name suggests), not
-- an unconditional Forbidden-object block as briefly concluded mid-session - that conclusion was drawn
-- from an in-combat test that had the deferral wrapper manually disabled, which explains the crash
-- without implicating PixelUtil specifically. Restored to the original PixelUtil.SetSize +
-- ExecuteAfterCombatEnds combination for further, more careful testing rather than left on the
-- untested plain-SetSize variant.
local function ReapplyLiveAuraButtonSettings(aura_type)
  if not HasAuraContainers then return end

  Addon.ExecuteAfterCombatEnds(function()
    local db_icon = Widget.db[aura_type].ModeIcon
    for _, container in ipairs(AuraContainerPool[aura_type]) do
      for _, group_key in ipairs(AURA_GROUP_KEYS[aura_type]) do
        for i = 1, container:GetAuraGroupFrameCount(group_key) do
          local auraButton = container:GetAuraGroupFrame(group_key, i)
          PixelUtil.SetSize(auraButton, db_icon.IconWidth, db_icon.IconHeight)
          auraButton:SetMouseMotionEnabled(Widget.db.ShowTooltips)
          if auraButton.Cooldown then
            auraButton.Cooldown:SetShownSwipe(Widget.db.ShowCooldownSpiral, HideOmniCC)
          end

          -- Stacks/TimeLeft always exist (created unconditionally in InitializeAuraButton, like
          -- DispelBorder - see its comment) - this never creates or (re)binds SetApplicationCount/
          -- SetDurationText itself, only restyles (FontUpdateText - plain Set* calls, nothing
          -- restricted) and toggles Show()/Hide() for ShowStackCount/ShowDuration.
          FontUpdateText(auraButton, auraButton.Stacks, db_icon.StackCount)
          auraButton.Stacks:SetShown(Widget.db.ShowStackCount)

          FontUpdateText(auraButton, auraButton.TimeLeft, db_icon.Duration)
          auraButton.TimeLeft:SetShown(ShowDuration)

          -- Dispel-type border EXISTENCE (ShowBorder true<->false) reverted to create-time-only
          -- (2026-08-21) - AddDispelTypeTexture/RemoveDispelTypeTexture/ClearDispelTypeTextures turned
          -- out not to work reliably on AuraButtons that have already displayed an aura (confirmed by
          -- live testing, exact failure mode not fully diagnosed). Changing ShowBorder in Options only
          -- affects newly-pooled buttons again, same as before this session's live-update experiments -
          -- see InitializeAuraButton's own DispelBorder setup.
          --
          -- Re-coloring (ShowAuraType/DefaultBuffColor/DefaultDebuffColor) on a border that's *already
          -- registered*, without touching existence - narrower than the reverted existence-toggle
          -- attempt above. Gated on GetDispelTypeTextureCount() > 0 so this never registers a border
          -- for the first time on a button that never had one (that stays reload-only, per the revert
          -- above) - only re-applies fresh color to one that was already shown. Confirmed live
          -- 2026-08-21: unlike the broader existence-toggle case, Remove+AddDispelTypeTexture works
          -- reliably here for recoloring an already-shown border.
          if db_icon.ShowBorder and auraButton:GetDispelTypeTextureCount() > 0 then
            auraButton:RemoveDispelTypeTexture(1)
            auraButton:AddDispelTypeTexture(auraButton.DispelBorder, {
              style = DispelTypeTextureStylePreserveAsset,
              showWhenHarmful = true,
              showWhenHelpful = true,
              showWithoutDispelType = true,
              customDispelColorMap = Widget.db.ShowAuraType and GetDispelTypeColorMapForAuraType(aura_type) or BLACK_DISPEL_COLOR_MAP,
            })
          end
        end
      end
    end
  end, "Unable to update the appearance of auras while in combat.")
end

-- Maps the widget's SortOrder setting to the closest AuraContainerSortMethod. Duration/Creation have
-- no equivalent sort method and fall back to Default.
local function GetSortMethod(sort_order)
  if sort_order == "AtoZ" then
    return AuraContainerSortMethod.Name
  elseif sort_order == "TimeLeft" then
    return AuraContainerSortMethod.Expiration
  end

  return AuraContainerSortMethod.Default
end

local function GetSortDirection(sort_reverse)
  return sort_reverse and AuraContainerSortDirection.Reverse or AuraContainerSortDirection.Normal
end

local function CreateAuraContainer(aura_type)
  local container = _G.CreateFrame("AuraContainer", nil, _G.UIParent, "CustomAuraContainerTemplate")
  local effect = (aura_type == "Buffs" and "HELPFUL") or "HARMFUL"
  local group_options = {
    initializeFrame = function(auraButton) InitializeAuraButton(auraButton, aura_type) end,
    sortMethod = GetSortMethod(Widget.db.SortOrder),
    sortDirection = GetSortDirection(Widget.db.SortReverse),
  }

  for _, group_key in ipairs(AURA_GROUP_KEYS[aura_type]) do
    container:AddAuraGroup(group_key, effect, group_options)
  end
  container:SetEnabled(false)

  return container
end

-- AuraContainers cannot be created during combat, so the pools are built once up front (called from
-- Widget:OnEnable, which runs at login/reload - effectively always out of combat - and retried from
-- Widget:PLAYER_REGEN_ENABLED/DISABLED in case the widget was first enabled mid-combat) rather than
-- lazily per-plate like the rest of this widget's frames.
local function PreallocateAuraContainers()
  if not HasAuraContainers then return end

  if _G.InCombatLockdown() then
    Addon.Logging.Debug("    Auras: could not pre-allocate AuraContainer pools - in combat, will retry after combat ends.")
    return
  end

  for _, aura_type in ipairs(AURA_CONTAINER_TYPES) do
    local pool = AuraContainerPool[aura_type]
    if #pool == 0 then
      for i = 1, AURA_CONTAINER_POOL_SIZE do
        pool[i] = CreateAuraContainer(aura_type)
      end
    end
  end
end

local function AcquireAuraContainer(aura_type)
  local pool = AuraContainerPool[aura_type]
  local index = NextAuraContainerIndex[aura_type]
  local container = pool[index]
  if container then
    NextAuraContainerIndex[aura_type] = index + 1
  else
    Addon.Logging.Error("|cffFF8800[AuraDebug]|r", aura_type, "pool exhausted at index", index, "- this plate will show no", aura_type)
  end

  return container
end

-- Composes the AuraFilters string/candidateFilters for each type/reaction combination from today's
-- boolean settings. See the simplifications note above the pool constant.

-- Shared multi-group builder: turns a list of independent OR-conditions into one AddAuraGroup config
-- per condition. base_filter_parts is the always-present prefix (aura type plus any fixed exclusions,
-- e.g. {"HARMFUL", "!CROWD_CONTROL", NAMEPLATE_ONLY}). dispel_types/has_dispel_type (optional) apply
-- candidateFilters.excludeDispelTypes to every non-"dispeltype" condition - a "dispeltype" condition's
-- own candidateFilters.includeDispelTypes is a table, so it can't be negated into a "!token"/
-- false-boolean like every other condition; this is the inverse fix for that (see the comment on
-- GetEnemyDebuffsGroupConfigs for the full duplication story this prevents).
--
-- Exclusion is *ordered*, not symmetric: each condition excludes only the conditions *before* it in
-- the list, never the ones after. Excluding every other condition in both directions (as an earlier
-- version of this function did) means an aura matching two simultaneously-active conditions fails
-- *both* groups' restrictions and vanishes entirely - neither shown twice nor once, just gone. Ordered
-- exclusion instead gives every aura exactly one home: it shows via the earliest-listed condition it
-- satisfies, and every later condition explicitly excludes that earlier one from itself. Which
-- condition "wins" for a double-matching aura is an arbitrary but deterministic tie-break (list order
-- = the order each condition is pushed into `conditions` by the caller); the important part is that it
-- always shows via exactly one group.
--
-- Returns a table keyed by group name -> { filterString = ..., candidateFilters = ... }; a group key
-- from AURA_GROUP_KEYS[aura_type] missing from the result means "disable this group" (caller sets
-- maxFrameCount to 0).
local function BuildGroupConfigsFromConditions(conditions, base_filter_parts, dispel_types, has_dispel_type)
  local configs = {}
  for i, condition in ipairs(conditions) do
    local filter_parts = {}
    for _, part in ipairs(base_filter_parts) do
      filter_parts[#filter_parts + 1] = part
    end
    local candidate_filters = {}
    for field, value in pairs(condition.candidateFilters) do
      candidate_filters[field] = value
    end
    for _, token in ipairs(condition.filterTokens) do
      filter_parts[#filter_parts + 1] = token
    end

    if condition.key ~= "dispeltype" then
      for j = 1, i - 1 do
        local other = conditions[j]
        for _, token in ipairs(other.filterTokens) do
          filter_parts[#filter_parts + 1] = "!" .. token
        end
        for field, value in pairs(other.candidateFilters) do
          if type(value) == "boolean" and candidate_filters[field] == nil then
            candidate_filters[field] = false
          end
        end
      end

      if has_dispel_type then
        candidate_filters.excludeDispelTypes = dispel_types
      end
    end

    configs[condition.key] = { filterString = table.concat(filter_parts, "|"), candidateFilters = candidate_filters }
  end

  return configs
end

-- Buffs (friendly): ShowAllFriendly/ShowOnFriendlyNPCs (unit.type == "NPC" only) short-circuit into an
-- unrestricted "main" group, same as "All" everywhere else - "All on NPCs" is conceptually "All, but
-- scoped to NPCs", not a peer condition, so it can't be freely combined with Mine/CanApply/
-- BigDefensives the normal way (there's no candidateFilters field for "unit is an NPC" to cross-
-- exclude it with; combining it as a peer group would double-render every other active condition's
-- auras on NPC targets). Otherwise Mine/PlayerCanApply/BigDefensives are independent,
-- freely-combinable OR-conditions.
local function GetFriendlyBuffsGroupConfigs(db, unit)
  -- MaxDuration (Patch 12.1.0): non-nil implicitly hides permanent buffs too, per Blizzard's own
  -- documentation - applied as an extra AND-restriction on every active group below (not its own
  -- OR-condition/group), regardless of which other toggle(s) are active. Makes more sense here than
  -- on Debuffs (where it originally lived) - hiding long-duration/permanent auras is mainly useful for
  -- filtering out passive self-buffs (flasks, food, Well Fed, ...), not debuffs.
  local max_duration = (db.MaxDurationFriendly and db.MaxDurationFriendly > 0) and db.MaxDurationFriendly or nil

  if db.ShowAllFriendly or (db.ShowOnFriendlyNPCs and unit.type == "NPC") then
    return { main = { filterString = "HELPFUL|" .. NAMEPLATE_ONLY, candidateFilters = { maxDuration = max_duration } } }
  end

  local conditions = {}
  if db.ShowOnlyMine then
    conditions[#conditions + 1] = { key = "main", filterTokens = { "PLAYER" }, candidateFilters = {} }
  end
  if db.ShowPlayerCanApply then
    conditions[#conditions + 1] = { key = "canapply", filterTokens = {}, candidateFilters = { canApplyAura = true } }
  end
  if db.ShowFriendlyBigDefensives then
    conditions[#conditions + 1] = { key = "bigdefensive", filterTokens = { "BIG_DEFENSIVE" }, candidateFilters = {} }
  end

  local configs = BuildGroupConfigsFromConditions(conditions, { "HELPFUL", NAMEPLATE_ONLY })
  for _, config in pairs(configs) do
    config.candidateFilters.maxDuration = max_duration
  end

  return configs
end

-- Buffs (enemy): same pattern as Friendly above - ShowAllEnemy/ShowOnEnemyNPCs short-circuit,
-- Dispellable/Magic are independent, freely-combinable OR-conditions. MaxDurationEnemy is the
-- separate enemy-reaction field - see the comment on MaxDurationFriendly in GetFriendlyBuffsGroupConfigs.
local function GetEnemyBuffsGroupConfigs(db, unit)
  local max_duration = (db.MaxDurationEnemy and db.MaxDurationEnemy > 0) and db.MaxDurationEnemy or nil

  if db.ShowAllEnemy or (db.ShowOnEnemyNPCs and unit.type == "NPC") then
    return { main = { filterString = "HELPFUL|" .. NAMEPLATE_ONLY, candidateFilters = { maxDuration = max_duration } } }
  end

  local conditions = {}
  if db.ShowDispellable then
    -- DISPELLABLE (Patch 12.1.0): dispellable by anyone, not just RAID_PLAYER_DISPELLABLE's "a raid
    -- member's kit can dispel this specifically" - broader, matches what the "Dispellable" label implies.
    conditions[#conditions + 1] = { key = "dispellable", filterTokens = { "DISPELLABLE" }, candidateFilters = {} }
  end
  if db.ShowMagic then
    conditions[#conditions + 1] = { key = "magic", filterTokens = {}, candidateFilters = { includeDispelTypes = { Magic = true } } }
  end

  local configs = BuildGroupConfigsFromConditions(conditions, { "HELPFUL", NAMEPLATE_ONLY })
  for _, config in pairs(configs) do
    config.candidateFilters.maxDuration = max_duration
  end

  return configs
end

-- Debuffs (friendly): same multi-group independent-OR-condition pattern as Debuffs (enemy) below,
-- except Dispellable+FilterByType are combined rather than independent - see the note in
-- GetEnemyDebuffsGroupConfigs (Dispellable/Boss/FilterByType are the legacy friendly-only fields, see
-- the note above their Constants.lua defaults). ShowAllFriendly short-circuits everything into "main"
-- alone.
local function GetFriendlyDebuffsGroupConfigs(db)
  if db.ShowAllFriendly then
    return { main = { filterString = "HARMFUL|!CROWD_CONTROL|" .. NAMEPLATE_ONLY, candidateFilters = {} } }
  end

  local conditions = {}
  if db.ShowBoss then
    conditions[#conditions + 1] = { key = "boss", filterTokens = {}, candidateFilters = { isBossAura = true } }
  end

  -- Dispellable ("Bannbar") and Dispel Type ("Bannart") are combined, not independent - see the same
  -- note in GetEnemyDebuffsGroupConfigs. Bannbar no longer has its own standalone group; it only
  -- gates whether "dispeltype" exists, and that group always requires DISPELLABLE too.
  local dispel_types, has_dispel_type = {}, false
  if db.ShowDispellable then
    for i, dispel_name in ipairs(DISPEL_TYPE_NAMES) do
      if db.FilterByType[i] then
        dispel_types[dispel_name] = true
        has_dispel_type = true
      end
    end
    if has_dispel_type then
      conditions[#conditions + 1] = { key = "dispeltype", filterTokens = { "DISPELLABLE" }, candidateFilters = { includeDispelTypes = dispel_types } }
    end
  end

  return BuildGroupConfigsFromConditions(conditions, { "HARMFUL", "!CROWD_CONTROL", NAMEPLATE_ONLY }, dispel_types, has_dispel_type)
end

local function GetCrowdControlFilterString(db, is_friendly)
  if db.ShowAllFriendly or db.ShowAllEnemy then
    return "HARMFUL|CROWD_CONTROL|" .. NAMEPLATE_ONLY
  elseif is_friendly and db.ShowDispellable then
    -- ShowDispellable only has a Friendly Options entry (Enemy Midnight panel exposes no such
    -- toggle) - gate on is_friendly to keep it from also gating on a Boolean the enemy UI can't set.
    return "HARMFUL|CROWD_CONTROL|DISPELLABLE|" .. NAMEPLATE_ONLY
  end

  return nil
end

-- Builds the full set of AddAuraGroup configs (per AURA_GROUP_KEYS.Debuffs key) for enemy-reaction
-- Debuffs from today's boolean settings. ShowAllEnemy short-circuits everything into "main" alone.
-- Otherwise each of ShowOnlyMine ("main"), ShowBlizzardForEnemy ("important" + "importantpersonal" -
-- two peer groups, IMPORTANT/!IMPORTANT split, both PLAYER-restricted and nameplateShowPersonal-gated -
-- see the comment at its condition below), ShowBoss ("boss", candidateFilters.isBossAura), and
-- ShowPriority ("priority",
-- candidateFilters.isPriorityAura) is an
-- independent, freely-combinable OR-condition: every group's
-- filter string/candidateFilters excludes every *earlier-listed* active condition (see
-- BuildGroupConfigsFromConditions), so an aura matching more than one toggle is always assigned to
-- exactly one group - the earliest one it satisfies - instead of showing twice or (with the naive
-- "exclude every other condition in both directions" approach this used to have) vanishing from both.
-- ShowDispellableEnemy ("Bannbar") and FilterByTypeEnemy[1-4] ("Bannart") are combined, not
-- independent: Bannart only ever produces a "dispeltype" group when Bannbar is also on, and that
-- group always includes the DISPELLABLE token - so it's not "every other group excludes the checked
-- dispel types", it's "dispeltype only exists, and only matches dispellable auras, while Bannbar is
-- on". Every *other* group still explicitly excludes the checked dispel types via
-- candidateFilters.excludeDispelTypes whenever Bannbar+Bannart together produce a "dispeltype" group,
-- so an aura matching e.g. both a checked dispellable type and Boss only ever shows via "dispeltype".
--
-- Returns a table keyed by group name -> { filterString = ..., candidateFilters = ... }; a group
-- key that's missing from the result means "disable this group" (caller sets maxFrameCount to 0).
local function GetEnemyDebuffsGroupConfigs(db)
  if db.ShowAllEnemy then
    return { main = { filterString = "HARMFUL|!CROWD_CONTROL|" .. NAMEPLATE_ONLY, candidateFilters = {} } }
  end

  local conditions = {}
  if db.ShowOnlyMine then
    -- PLAYER filter-string token, not candidateFilters.isFromPlayerOrPlayerPet - live-tested and
    -- confirmed candidateFilters.isFromPlayerOrPlayerPet doesn't actually restrict anything on this
    -- client (debug dump showed it built/applied correctly - candidateFilters={isFromPlayerOrPlayerPet=true}
    -- - yet all enemy debuffs still showed, not just self-cast ones). Switching to PLAYER fixed it,
    -- confirmed by isolated retest (only "Mine" active): only self-cast debuffs shown afterwards.
    conditions[#conditions + 1] = { key = "main", filterTokens = { "PLAYER" }, candidateFilters = {} }
  end
  if db.ShowBlizzardForEnemy then
    -- Two peer groups, split by IMPORTANT/!IMPORTANT, both PLAYER-restricted and both gated on
    -- candidateFilters.nameplateShowPersonal - not the single-group nameplateShowPersonal-only version
    -- this addon shipped for one day (2026-08-17, reverted here). "important" catches Blizzard-flagged
    -- self-cast debuffs (IMPORTANT token); "importantpersonal" catches every other self-cast debuff
    -- Blizzard's own nameplates show (!IMPORTANT, still nameplateShowPersonal-gated) - together, the
    -- same nameplateShowAll/Personal coverage the very first "Blizzard" fix (2026-08-16) had, but
    -- expressed as IMPORTANT/!IMPORTANT instead of nameplateShowAll/nameplateShowPersonal (see
    -- AurasWidgetImplementation.md §6 for why nameplateShowAll can't combine with a single-group
    -- PLAYER restriction).
    --
    -- Known tradeoff, reintroduced on purpose: two concurrently-active groups for this one toggle
    -- means SortOrder (e.g. TimeLeft) won't be globally correct across them when "Blizzard" is
    -- active - Blizzard's AuraContainer never merges sort order *across* AddAuraGroups, only within
    -- each one (§6). This is the exact same architectural cost the 2026-08-17 single-group fix was
    -- built to avoid - reintroduced here per explicit user request.
    conditions[#conditions + 1] = { key = "important", filterTokens = { "IMPORTANT", "PLAYER" }, candidateFilters = { nameplateShowPersonal = true } }
  end
  if db.ShowBossEnemy then
    conditions[#conditions + 1] = { key = "boss", filterTokens = {}, candidateFilters = { isBossAura = true } }
  end
  if db.ShowPriority then
    conditions[#conditions + 1] = { key = "priority", filterTokens = {}, candidateFilters = { isPriorityAura = true } }
  end
  -- Dispellable ("Bannbar") and Dispel Type ("Bannart") are combined, not independent: Bannart is
  -- inert (and grayed out in Options) unless Bannbar is also on, and once it is, only *dispellable*
  -- debuffs of a checked type show - not every dispellable debuff regardless of type like before.
  -- So there's no separate standalone "dispellable" condition/group anymore - Bannbar's own toggle
  -- only gates whether the "dispeltype" group exists at all.
  local dispel_types, has_dispel_type = {}, false
  if db.ShowDispellableEnemy then
    for i, dispel_name in ipairs(DISPEL_TYPE_NAMES) do
      if db.FilterByTypeEnemy[i] then
        dispel_types[dispel_name] = true
        has_dispel_type = true
      end
    end
    if has_dispel_type then
      -- "dispeltype" is exempt from BuildGroupConfigsFromConditions' earlier-condition exclusion (see
      -- its comment - includeDispelTypes is a table, can't be negated like a boolean/token), so Mine's
      -- PLAYER token never reaches it through that mechanism. Add it directly here instead, so Mine +
      -- a checked dispel type combine ("only my Curses/Diseases/...") instead of dispeltype always
      -- showing every player's matching debuffs regardless of Mine.
      local dispeltype_tokens = { "DISPELLABLE" }
      if db.ShowOnlyMine then
        dispeltype_tokens[#dispeltype_tokens + 1] = "PLAYER"
      end
      conditions[#conditions + 1] = { key = "dispeltype", filterTokens = dispeltype_tokens, candidateFilters = { includeDispelTypes = dispel_types } }
    end
  end

  local configs = BuildGroupConfigsFromConditions(conditions, { "HARMFUL", "!CROWD_CONTROL", NAMEPLATE_ONLY }, dispel_types, has_dispel_type)

  -- "importantpersonal" is "important"'s IMPORTANT/!IMPORTANT twin (see the comment on the
  -- ShowBlizzardForEnemy condition above) - built by cloning "important"'s already-fully-excluded
  -- result and flipping its IMPORTANT token, same technique the original 2026-08-16
  -- nameplateShowAll/Personal split used (gsub count=1 is safe: "IMPORTANT" appears nowhere else in
  -- the filter string at this point - not in HARMFUL/CROWD_CONTROL/NAMEPLATE_ONLY/PLAYER, and no
  -- "!IMPORTANT" exists yet to double-negate).
  if configs.important then
    local filter_string = configs.important.filterString:gsub("IMPORTANT", "!IMPORTANT", 1)
    local candidate_filters = {}
    for field, value in pairs(configs.important.candidateFilters) do
      candidate_filters[field] = value
    end
    configs.importantpersonal = { filterString = filter_string, candidateFilters = candidate_filters }
  end

  return configs
end

-- Derives AuraContainer flow-layout anchor/growth direction from the widget's AlignmentH/AlignmentV
-- settings (same semantics as the addon's other grid-layout alignment settings).
local function GetFlowLayoutForAlignment(alignment_h, alignment_v)
  local anchor_point = alignment_v .. alignment_h
  local horizontal_direction = (alignment_h == "LEFT") and AnchorUtil.FlowDirection.Right or AnchorUtil.FlowDirection.Left
  local vertical_direction = (alignment_v == "BOTTOM") and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down

  return anchor_point, horizontal_direction, vertical_direction
end

-- Configures the plate's pooled AuraContainer for aura_type ("Buffs"/"Debuffs"/"CrowdControl") for
-- the current settings/unit and assigns the unit to it. Returns true if the container was enabled
-- for this unit - the container manages its own aura-level visibility internally and
-- asynchronously, so there is no "has active auras" count available here; callers use this return
-- value (whether display was enabled at all, independent of actual aura presence) as a stand-in.
-- group_configs: table keyed by group name ("main", and for Debuffs also "important"/"boss"/
-- "priority"/"dispellable"/"dispeltype") -> { filterString = ..., candidateFilters = ... }. A group
-- key from AURA_GROUP_KEYS[aura_type] missing from group_configs is disabled (maxFrameCount = 0).
-- Buffs/CrowdControl callers only ever populate "main"; Debuffs callers may populate several.
function Widget:UpdateAuraContainer(widget_frame, aura_type, group_configs, unit)
  local container = widget_frame[aura_type .. "AuraContainer"]
  if not container then return false end

  if not group_configs or not next(group_configs) then
    container:SetEnabled(false)
    return false
  end

  -- SwitchAreaByReaction (friendly units only, Buffs<->Debuffs - matches the legacy widget's own
  -- scope, CrowdControl was never swapped there either): swaps which type's *layout* (icon size,
  -- columns/rows/spacing, sort, alignment, anchor - everything below except the actual filter data,
  -- which stays on the real aura_type/container) Buffs/Debuffs use. Matches the legacy widget's
  -- behavior of feeding buff data straight into the already-Debuffs-styled physical Debuffs frame
  -- (AurasWidget.lua ~2156: `local buff_aura_grid = (db.SwitchAreaByReaction and
  -- widget_frame.Debuffs) or widget_frame.Buffs`) - not just relocating buffs to debuffs' screen
  -- position, but rendering them as if they were configured as debuffs (that reads oddly for
  -- "switch position", but is what the legacy widget actually did, so replicated here for parity).
  -- Known edge case, not specially guarded: if AnchorTo on the *swapped* config names the other of
  -- Buffs/Debuffs (stacking one below the other) while this setting is also on, the two containers'
  -- anchor chains can reference each other in a way that wasn't possible before switching was
  -- implemented - not expected to be a common configuration.
  local layout_type = aura_type
  if unit.reaction == "FRIENDLY" and self.db.SwitchAreaByReaction then
    if aura_type == "Buffs" then
      layout_type = "Debuffs"
    elseif aura_type == "Debuffs" then
      layout_type = "Buffs"
    end
  end

  local db = self.db[layout_type]
  local db_icon = db.ModeIcon
  local max_auras = min(db_icon.MaxAuras, db_icon.Rows * db_icon.Columns)
  local anchor_point, horizontal_direction, vertical_direction = GetFlowLayoutForAlignment(db.AlignmentH, db.AlignmentV)
  local sort_method = GetSortMethod(self.db.SortOrder)
  local sort_direction = GetSortDirection(self.db.SortReverse)
  local layout = {
    elementWidth = db_icon.IconWidth,
    elementHeight = db_icon.IconHeight,
    elementSpacing = db_icon.ColumnSpacing,
    lineSpacing = db_icon.RowSpacing,
  }

  for _, group_key in ipairs(AURA_GROUP_KEYS[aura_type]) do
    local config = group_configs[group_key]
    if config then
      container:SetAuraGroupFilterString(group_key, config.filterString)
      container:SetAuraGroupCandidateFilters(group_key, config.candidateFilters)
      container:SetAuraGroupMaxFrameCount(group_key, max_auras)
      container:SetAuraGroupSortMethod(group_key, sort_method, sort_direction)
      container:SetAuraGroupLayout(group_key, layout)
    else
      -- Not an active condition this update - disable without touching its filter string.
      container:SetAuraGroupMaxFrameCount(group_key, 0)
    end
  end

  container:SetFlowLayoutAnchorPoint(anchor_point)
  container:SetFlowLayoutGrowthDirection(horizontal_direction, vertical_direction)
  container:SetFlowLayoutMaximumLineSize(db_icon.Columns * (db_icon.IconWidth + db_icon.ColumnSpacing))

  container:SetUnit(unit.unitid)
  container:SetEnabled(true)

  -- AnchorTo can reference "Healthbar" (this widget's own frame) or another aura type's name
  -- ("Buffs"/"Debuffs"/"CrowdControl", meaning "stack above/below that grid"). We cannot anchor
  -- directly to that sibling AuraContainer's live edge: its size changes dynamically as auras are
  -- added/removed, and addons have no OnSizeChanged access to react to that (Forbidden Aspects
  -- block it) - the anchor would only ever reflect whatever the sibling's size happened to be at our
  -- last update, causing overlap as it grows afterwards. Instead, anchor to Healthbar like the
  -- sibling itself does, and add the sibling's *configured* (not live) max height to the offset, so
  -- there's always enough room regardless of how many auras it's currently showing.
  --
  -- Dynamic sizing was attempted (candidateFilters-free counter via
  -- CustomAuraContainerSharedMixin:GetAuraGroupFrameCount) but reverted: that counter reflects the
  -- group's frame *pool* size (grows in batches, never shrinks), not the currently-displayed aura
  -- count, so it made the reserved height "stuck at historical peak" instead of "always max" - a
  -- different bug, not a fix. No safely addon-exposed "currently active aura count" API was found;
  -- revisit if Blizzard ever exposes one.
  local anchor_to_db = db.AnchorTo
  local anchor_config = db[MODE_FOR_STYLE[unit.style]]
  local anchor_to = widget_frame

  if anchor_to_db ~= "Healthbar" then
    local sibling_icon = self.db[anchor_to_db].ModeIcon
    local sibling_height = sibling_icon.Rows * sibling_icon.IconHeight + (sibling_icon.Rows - 1) * sibling_icon.RowSpacing
    anchor_config = {
      Anchor = anchor_config.Anchor,
      InsideAnchor = anchor_config.InsideAnchor,
      HorizontalOffset = anchor_config.HorizontalOffset,
      VerticalOffset = (anchor_config.VerticalOffset or 0) + sibling_height,
    }
  end

  AnchorFrameTo(anchor_config, container, anchor_to)

  return true
end

---------------------------------------------------------------------------------------------------
-- Auras Module / Handler
---------------------------------------------------------------------------------------------------

local function IgnoreAuraUpdateForUnit(widget_frame, unit)
  -- ! "Target Only" only supports the direct target, not action targets
  local unit_is_target = UnitIsUnitTP("target", unit.unitid)
  if Widget.db.ShowTargetOnly then
    if unit_is_target then
      Widget.CurrentTarget = widget_frame
    elseif not Addon.ActiveAuraTriggers then
      -- Continue with aura scanning for non-target units if there are aura triggers that might change the nameplates style
      widget_frame:Hide()
      return true
    end
  end

  AuraTriggerInitialize(unit)

  widget_frame.HideAuras = not EnabledForStyle[unit.style] or (Widget.db.ShowTargetOnly and not unit_is_target)
end

local function AuraGridUpdateForUnitNotNecessary(widget_frame, unit)
  AuraTriggerUpdateStyle(unit)

  if widget_frame.HideAuras then
    widget_frame:Hide()
    return true
  end
end

-- Wraps a plain filter string into the single-"main"-group config shape UpdateAuraContainer expects.
local function SingleGroupConfig(filter_string, candidate_filters)
  return filter_string and { main = { filterString = filter_string, candidateFilters = candidate_filters or {} } } or nil
end

function Widget:UpdateAurasGrids(widget_frame, unit)
  local db = self.db
  local is_friendly = unit.reaction == "FRIENDLY"

  -- Deliberately not "is_friendly and X or Y": when X is a legitimate nil/false (e.g. no friendly
  -- toggle matches this unit), that idiom falls through to Y - the *other* reaction's settings -
  -- instead of correctly yielding "nothing to show" for this reaction.
  local buffs_configs, debuffs_configs, enabled_cc
  if is_friendly then
    buffs_configs = db.Buffs.ShowFriendly and GetFriendlyBuffsGroupConfigs(db.Buffs, unit)
    debuffs_configs = db.Debuffs.ShowFriendly and GetFriendlyDebuffsGroupConfigs(db.Debuffs)
    enabled_cc = db.CrowdControl.ShowFriendly
  else
    buffs_configs = db.Buffs.ShowEnemy and GetEnemyBuffsGroupConfigs(db.Buffs, unit)
    debuffs_configs = db.Debuffs.ShowEnemy and GetEnemyDebuffsGroupConfigs(db.Debuffs)
    enabled_cc = db.CrowdControl.ShowEnemy
  end
  local cc_configs = enabled_cc and SingleGroupConfig(GetCrowdControlFilterString(db.CrowdControl, is_friendly))

  local buffs_active = self:UpdateAuraContainer(widget_frame, "Buffs", buffs_configs, unit)
  local debuffs_active = self:UpdateAuraContainer(widget_frame, "Debuffs", debuffs_configs, unit)
  local cc_active = self:UpdateAuraContainer(widget_frame, "CrowdControl", cc_configs, unit)

  if AuraGridUpdateForUnitNotNecessary(widget_frame, unit) then
    for _, aura_type in ipairs(AURA_CONTAINER_TYPES) do
      local container = widget_frame[aura_type .. "AuraContainer"]
      if container then container:SetEnabled(false) end
    end
    return
  end

  widget_frame:SetShown(buffs_active or debuffs_active or cc_active)
end

function Widget:UpdateAuras(widget_frame, unit)
  if not IgnoreAuraUpdateForUnit(widget_frame, unit) then
    self:UpdateAurasGrids(widget_frame, unit)
  end
end

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------

function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = _G.CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------
  widget_frame:SetAllPoints(tp_frame)

  for _, aura_type in ipairs(AURA_CONTAINER_TYPES) do
    local container = AcquireAuraContainer(aura_type)
    if container then
      container:SetParent(widget_frame)
      container:SetEnabled(false)
      widget_frame[aura_type .. "AuraContainer"] = container
    end
  end

  widget_frame.Widget = self

  self:UpdateLayout(widget_frame)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  self.db = Addon.db.profile.AuraWidget
  return self.db.ON or self.db.ShowInHeadlineView
end

function Widget:OnEnable()
  self:SubscribeEvent("PLAYER_TARGET_CHANGED")
  self:SubscribeEvent("PLAYER_REGEN_ENABLED")
  self:SubscribeEvent("PLAYER_REGEN_DISABLED")

  PreallocateAuraContainers()
end

function Widget:EnabledForStyle(style, unit)
  if (style == "NameOnly" or style == "NameOnly-Unique") then
    return self.db.ShowInHeadlineView or Addon.ActiveAuraTriggers
  elseif style ~= "etotem" then
    return self.db.ON or Addon.ActiveAuraTriggers
  end
end

function Widget:OnUnitAdded(widget_frame, unit)
  self:UpdateAuras(widget_frame, unit)
end

-- Initialize the aura container layout, don't update auras themselves as not unitid know at this point
function Widget:UpdateLayout(widget_frame)
  local frame_level
  if self.db.FrameOrder == "HEALTHBAR_AURAS" then
    frame_level = widget_frame:GetParent():GetFrameLevel() + 1
  else
    frame_level = widget_frame:GetParent():GetFrameLevel() + 9
  end
  widget_frame:SetFrameLevel(frame_level)

  for _, aura_type in ipairs(AURA_CONTAINER_TYPES) do
    local container = widget_frame[aura_type .. "AuraContainer"]
    if container then
      container:SetFrameLevel(frame_level)
    end
  end
end

function Widget:PLAYER_TARGET_CHANGED()
  if not self.db.ShowTargetOnly then return end

  if self.CurrentTarget then
    self.CurrentTarget:Hide()
    self.CurrentTarget = nil
  end

  local tp_frame = Addon:GetThreatPlateForTarget()
  if tp_frame then
    self.CurrentTarget = tp_frame.widgets.Auras

    if self.CurrentTarget.Active then
      self:UpdateAuras(self.CurrentTarget, tp_frame.unit)
    end
  end
end

function Widget:PLAYER_REGEN_ENABLED()
  -- Retries pool creation if the widget was first enabled mid-combat (e.g. /reload during a fight),
  -- so the AuraContainer pools never got a chance to be created. No-op once the pools already exist.
  -- Also fires (harmlessly, InCombatLockdown() guards it) on the aliased PLAYER_REGEN_DISABLED.
  PreallocateAuraContainers()
end

Widget.PLAYER_REGEN_DISABLED = Widget.PLAYER_REGEN_ENABLED

-- Load settings from the configuration which are shared across all aura widgets
-- used (for each widget) in UpdateWidgetConfig
function Widget:UpdateSettings()
  self.db = Addon.db.profile.AuraWidget

  HideOmniCC = not self.db.ShowOmniCC or Addon.ExpansionIsAtLeastMidnight
  ShowDuration = self.db.ShowDuration and HideOmniCC

  EnabledForStyle["NameOnly"] = self.db.ShowInHeadlineView
  EnabledForStyle["NameOnly-Unique"] = self.db.ShowInHeadlineView
  EnabledForStyle["dps"] = self.db.ON
  EnabledForStyle["tank"] = self.db.ON
  EnabledForStyle["normal"] = self.db.ON
  EnabledForStyle["totem"] = self.db.ON
  EnabledForStyle["unique"] = self.db.ON
  EnabledForStyle["etotem"] = false
  EnabledForStyle["empty"] = false

  -- Must happen before ReapplyLiveAuraButtonSettings below (its recolor pass reads
  -- GetDispelTypeColorMapForAuraType) - otherwise a changed DefaultBuffColor/DefaultDebuffColor/
  -- ShowAuraType would keep serving the stale cached map.
  InvalidateDispelTypeColorMapCache()

  for _, aura_type in ipairs(AURA_CONTAINER_TYPES) do
    ReapplyLiveAuraButtonSettings(aura_type)
  end

  -- Filter/layout/sort/alignment/anchor settings (Mine/Blizzard/Boss/.../SortOrder/Columns/Rows/...)
  -- are otherwise only recomputed at Widget:UpdateAuras time (OnUnitAdded/target-change) - a pure
  -- Options change doesn't retrigger that for already-displayed plates on its own. UpdateAllFrames
  -- (WidgetHandler.lua, calls Widget:UpdateFrame per active plate) reruns exactly that same per-plate
  -- code path immediately instead. Safe to call directly, unlike ReapplyLiveAuraButtonSettings above -
  -- these are the same AuraContainer group-config setters (SetAuraGroupFilterString/
  -- CandidateFilters/etc.) already called from plain addon code on every OnUnitAdded/target-change,
  -- including mid-combat (that's the widget's whole reason for existing - see §1) - so no
  -- DenyTaintedAccessWhenAurasAreSecret risk here, unlike per-AuraButton Set* calls issued outside
  -- Blizzard's securecallfunction wrapper.
  self:UpdateAllFrames()
end

function Widget:UpdateFrame(widget_frame, unit)
  self:UpdateAuras(widget_frame, unit)
end

---------------------------------------------------------------------------------------------------
-- Configuration Mode / Debug - stubs only, kept so external call sites (Options.lua's
-- "Configuration Mode" toggle, Commands.lua's "/tptp debug Auras ...") don't error. Neither the
-- demo/preview aura fabrication nor the debug aura dump has an equivalent hook into AuraContainer
-- (Blizzard owns aura fetching internally via SetUnit() on a real unit token).
---------------------------------------------------------------------------------------------------

function Widget:ToggleConfigurationMode()
  Addon.Logging.Debug("    Auras: configuration/preview mode is not available with AuraContainer.")
end

function Widget:PrintDebug(command)
  Addon.Logging.Debug("    Auras: per-aura debug dump is not available with AuraContainer.")
end
