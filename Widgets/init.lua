---------------------
-- Widget Handling --
---------------------
local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------
local DEBUG = ThreatPlates.DEBUG
local SetStyle = TidyPlatesThreat.SetStyle

-- Information about widget layering, from highest to lowest
--    +2: combo points
-- 		+1: auras
--  widgets: frame level + 3
--  highest frame: cast bar -> spell icon, spell text
--  middle frame: raid icon, elite icon, skull icon, target
--    customtext, name, level
--  lower frame: healthbar -> health border, threat border, highlight (like healborder)
-- Current state:
--   name text is layered above combo point widget

ThreatPlatesWidgets = {}
ThreatPlatesWidgets.list = {}

---------------------------------------------------------------------------------------------------

local function DummyFalse() return false end

local function RegisterWidget(name,create,isContext,enabled, enabled_hv)
  if not ThreatPlatesWidgets.list[name] then
    ThreatPlatesWidgets.list[name] = {
      name = name,
      create = create,
      isContext = isContext,
      enabled = enabled,
      EnabledInHeadlineView = enabled_hv or DummyFalse
    }
  end
end

local function UnregisterWidget(name)
  ThreatPlatesWidgets.list[name] = nil
end

local function HideWidget(widget_list, widget_name)
  local widget = widget_list[widget_name]
  if widget then
    widget:Hide()
    widget_list[widget_name] = nil -- deleted the disabled widget, is that what we want? no re-using it later ...
  end
end

-- TidyPlatesGlobal_OnInitialize() is called when a nameplate is created or re-shown
-- activetheme is the table, not just the name
local function OnInitialize(plate, theme)
  if theme then
    local widget_list = plate.widgets

    -- disable all non Threat Plates widgets - unless they do it themeselves, better is  to use /reload after a theme switch
--    for widgetname, widget in pairs(plate.widgets) do
--			if not widget.TP_Widget then
--        widget:Hide()
--      end
--		end

--		for k,v in pairs(ThreatPlatesWidgets.list) do
--			if (not w[k]) or (not w[k].TP_Widget) then
--				local widget = v.create(plate)
--				widget.TP_Widget = true -- mark ThreatPlates widgets
--				w[k] = widget
--			end
--			-- widgets create hidden in there create function, so not necessary?
--			-- right now still necessary to enable event watchers in enabled()
--			if not v.enabled() then
--				w[k]:Hide()
--				w[k] = nil -- deleted the disabled widget, is that what we want? no re-using it later ...
--			end
--		end

    for name,v in pairs(ThreatPlatesWidgets.list) do
      if v.enabled() then
        local widget = widget_list[name]

        if not widget then
          widget = v.create(plate) -- UpdateConfig should/must be called in create()
--          widget.TP_Widget = true -- mark ThreatPlates widgets
          widget_list[name] = widget
        else
          if widget.UpdateConfig then widget:UpdateConfig() end
        end
      else
        HideWidget(widget_list, name)
      end
    end

  end
end

-- Hide all ThreatPlates widgets as another theme was selected in TidyPlates
local function DeleteWidgets()
  -- for all widgets types of Threat Plates, call ClearAllWidgets
  -- ThreatPlatesWidgets.ClearAllArenaWidgets()							-- done
  -- ThreatPlatesWidgets.ClearAllClassIconWidgets()					-- done
  -- ThreatPlatesWidgets.ClearAllComboPointWidgets() 				-- done
  -- ThreatPlatesWidgets.ClearAllEliteArtOverlayWidgets()		-- done
  -- ThreatPlatesWidgets.ClearAllSocialWidgets()							-- done
  -- ThreatPlatesWidgets.ClearAllTargetArtWidgets()					-- done
  -- ThreatPlatesWidgets.ClearAllThreatWidgets()							-- done
  -- ThreatPlatesWidgets.ClearAllTotemIconWidgets()					-- done
  -- ThreatPlatesWidgets.ClearAllUniqueIconWidgets()					-- done
  -- ThreatPlatesWidgets.ClearAllAuraWidgets()								-- done
  -- ThreatPlatesWidgets.ClearAllHealerTrackerWidgets()			-- disabled

  -- disable all event watchers
  ThreatPlatesWidgets.ComboPointWidgetDisableWatcher()
  ThreatPlatesWidgets.ArenaWidgetDisableWatcher()
  ThreatPlatesWidgets.SocialWidgetDisableWatcher()
  ThreatPlatesWidgets.ResourceWidgetDisableWatcher()
  --ThreatPlatesWidgets.AuraWidgetDisableWatcher() -- right now, watcher still necessary for TidyPlates as well
end

-- TidyPlatesGlobal_OnUpdate() is called when other data about the unit changes, or is requested by an external controller.
local function OnUpdate(plate, unit)
  local widget_list = plate.widgets

--  if unit.isTarget then
--    ThreatPlates.DEBUG_PRINT_TABLE(plate)
--  end

  for name,v in pairs(ThreatPlatesWidgets.list) do
    local show_healthbar_view = v.enabled()
    local show_headline_view = v.EnabledInHeadlineView()

    if show_healthbar_view or show_headline_view then
      local widget = widget_list[name]

      -- Because widgets can be disabled anytime, it is not guaranteed that it exists after OnInitialize
      if not widget then
        widget = v.create(plate)
        widget_list[name] = widget
      end

      local style = SetStyle(unit)
      if style == "NameOnly" or style == "NameOnly-Unique" then
        if show_headline_view then
          if not v.isContext then
            unit.TP_Style = style
            widget:Update(unit)
            if unit.isTarget then	plate:SetFrameStrata("LOW") else plate:SetFrameStrata("BACKGROUND")	end
          end
        else
          widget:Hide()
        end
      elseif style == "etotem" or style == "empty" then
        widget:Hide()
      elseif show_healthbar_view then -- any other style
        -- context means that widget is only relevant for target (or mouse-over)
        if not v.isContext then
          unit.TP_Style = style
          widget:Update(unit)
          if unit.isTarget then	plate:SetFrameStrata("LOW") else plate:SetFrameStrata("BACKGROUND") end
        end
      else
        widget:Hide()
      end
    else
      HideWidget(widget_list, name)
    end
  end
end

-- TidyPlatesGlobal_OnContextUpdate() is called when a unit is targeted or moused-over.  (Any time the unitid or GUID changes)
-- OnContextUpdate must only do something when there is something unit-dependent to display?
local function OnContextUpdate(plate, unit)
  local widget_list = plate.widgets

  for name,v in pairs(ThreatPlatesWidgets.list) do
    local show_healthbar_view = v.enabled()
    local show_headline_view = v.EnabledInHeadlineView()

    if show_healthbar_view or show_headline_view then
      local widget = widget_list[name]

      -- Because widgets can be disabled anytime, it is not guaranteed that it exists after OnInitialize
      if not widget then
        widget = v.create(plate)
        widget_list[name] = widget
      end

      local style = SetStyle(unit)
      if style == "NameOnly" or style == "NameOnly-Unique" then
        if show_headline_view then
          unit.TP_Style = style
          widget:UpdateContext(unit)
          if unit.isTarget then	plate:SetFrameStrata("LOW") else plate:SetFrameStrata("BACKGROUND") end
        else
          widget:Hide()
        end
      elseif style == "etotem" or style == "empty" then
        widget:Hide()
      elseif show_healthbar_view then -- any other style
        unit.TP_Style = style
        widget:UpdateContext(unit)
        if unit.isTarget then	plate:SetFrameStrata("LOW") else plate:SetFrameStrata("BACKGROUND") end
      else
        widget:Hide()
      end
    else
      HideWidget(widget_list, name)
    end
  end
end

ThreatPlatesWidgets.RegisterWidget = RegisterWidget				-- used internally by ThreatPlates widgets
ThreatPlatesWidgets.UnregisterWidget = UnregisterWidget		-- used internally by ThreatPlates widgets

ThreatPlatesWidgets.OnInitialize = OnInitialize
ThreatPlatesWidgets.OnUpdate = OnUpdate
ThreatPlatesWidgets.OnContextUpdate = OnContextUpdate
ThreatPlatesWidgets.DeleteWidgets = DeleteWidgets
