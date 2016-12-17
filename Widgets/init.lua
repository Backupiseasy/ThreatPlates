local ADDON_NAME, NAMESPACE = ...
local ThreatPlates = NAMESPACE.ThreatPlates

---------------------
-- Widget Handling --
---------------------

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

local function RegisterWidget(name,create,isContext,enabled)
	if not ThreatPlatesWidgets.list[name] then
		ThreatPlatesWidgets.list[name] = {
			name = name,
			create = create,
			isContext = isContext,
			enabled = enabled
		}
	end
end

local function UnregisterWidget(name)
	ThreatPlatesWidgets.list[name] = nil
end

local function CreateWidget(plate, widget_name, widget_data)
  local w = plate.widgets

  if not w[widget_name] then
    local widget = widget_data.create(plate)
    widget.TP_Widget = true -- mark ThreatPlates widgets
    w[widget_name] = widget
  end
end

-- TidyPlatesGlobal_OnInitialize() is called when a nameplate is created or re-shown
-- activetheme is the table, not just the name
local function OnInitialize(plate, theme)
	if theme then
		local w = plate.widgets

		-- disable all non Threat Plates widgets - unless they do it themeselves
    for widgetname, widget in pairs(plate.widgets) do
			if not widget.TP_Widget then widget:Hide() end
		end

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

		for k,v in pairs(ThreatPlatesWidgets.list) do
			if v.enabled() then
        CreateWidget(plate, k, v)
			else
				if w[k] then
					w[k]:Hide()
					w[k] = nil -- deleted the disabled widget, is that what we want? no re-using it later ...
				end
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
	--ThreatPlatesWidgets.AuraWidgetDisableWatcher() -- right now, watcher still necessary for TidyPlates as well
end

-- TidyPlatesGlobal_OnUpdate() is called when other data about the unit changes, or is requested by an external controller.
local function OnUpdate(plate, unit)
	local style = TidyPlatesThreat.SetStyle(unit)
	local w = plate.widgets

	for k,v in pairs(ThreatPlatesWidgets.list) do

    if v.enabled() then
      CreateWidget(plate, k, v)

      -- Diable all widgets in headline view mode
      if style == "NameOnly" or style == "etotem" or style == "empty" then
        w[k]:_Hide()
      else
        -- context means that widget is only relevant for target (or mouse-over)
        if not v.isContext then
          w[k]:Update(unit, style)
          if unit.isTarget then	plate:SetFrameStrata("LOW") else plate:SetFrameStrata("BACKGROUND")	end
        end
      end
    else
      if w[k] then
        w[k]:Hide()
        w[k] = nil -- deleted the disabled widget, is that what we want? no re-using it later ...
      end
    end
	end
end

-- TidyPlatesGlobal_OnContextUpdate() is called when a unit is targeted or moused-over.  (Any time the unitid or GUID changes)
-- OnContextUpdate must only do something when there is something unit-dependent to display?
local function OnContextUpdate(plate, unit)
	local style = TidyPlatesThreat.SetStyle(unit)
	local w = plate.widgets

	for k,v in pairs(ThreatPlatesWidgets.list) do
    if v.enabled() then
      CreateWidget(plate, k, v)

      if style == "NameOnly" or style == "etotem" or style == "empty" then
        w[k]:_Hide()
      else
        w[k]:UpdateContext(unit, style)
        if unit.isTarget then	plate:SetFrameStrata("LOW") else plate:SetFrameStrata("BACKGROUND") end
      end
    else
      if w[k] then
        w[k]:Hide()
        w[k] = nil -- deleted the disabled widget, is that what we want? no re-using it later ...
      end
    end
	end
end

ThreatPlatesWidgets.RegisterWidget = RegisterWidget				-- used internally by ThreatPlates widgets
ThreatPlatesWidgets.UnregisterWidget = UnregisterWidget		-- used internally by ThreatPlates widgets

ThreatPlatesWidgets.OnInitialize = OnInitialize
ThreatPlatesWidgets.OnUpdate = OnUpdate
ThreatPlatesWidgets.OnContextUpdate = OnContextUpdate
ThreatPlatesWidgets.DeleteWidgets = DeleteWidgets
