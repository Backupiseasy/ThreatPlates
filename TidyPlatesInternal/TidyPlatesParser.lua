local addonName, addon = ...

-- Requires:
-- TidyPlatesUtilityInternal
-- TidyPlatesDefaults
-- TidyPlatesInternalThemeList, TidyPlatesInternal.ThemeTemplate

local UseTheme = addon.UseTheme

-------------------------------------------------------------------------------------
--  General Helpers
-------------------------------------------------------------------------------------
local _

local copytable         -- Allows self-reference
copytable = function(original)
	local duplicate = {}
	for key, value in pairs(original) do
		if type(value) == "table" then duplicate[key] = copytable(value)
		else duplicate[key] = value end
	end
	return duplicate
end

local function mergetable(master, mate)
	local merged = {}
	local matedata
	for key, value in pairs(master) do
		if type(value) == "table" then
			matedata = mate[key]
			if type(matedata) == "table" then merged[key] = mergetable(value, matedata)
			else merged[key] = copytable(value) end
		else
			matedata = mate[key]
			if matedata == nil then merged[key] = master[key]
			else merged[key] = matedata end
		end
	end
	return merged
end

local function SetTheme(...)
	local arg1, arg2 = ...

	if arg1 == TidyPlatesInternal then themeName = arg2
	else themeName = arg1 end

	local theme 	-- This will store the pointer to the theme table

	-- Sends a nil notification to all available themes to encourage cleanup
	for themename, themetable in pairs(TidyPlatesInternalThemeList) do
		if themetable.OnActivateTheme then themetable.OnActivateTheme(nil) end
	end

	-- Get theme table
	if type(TidyPlatesInternalThemeList) == "table" then
		if type(themeName) == 'string' then
			theme = TidyPlatesInternalThemeList[themeName]
		end
	end

	-- Verify & Scrub theme data, then attempt to load...
	if type(theme) == 'table' then

		-- Multi-Style Theme   (Hub / ThreatPlates Format)
		local style, stylename
		for stylename, style in pairs(theme) do
			if type(style) == "table" and style._meta then						-- _meta tag skips parsing
				theme[stylename] = copytable(style)
			elseif type(style) == "table" then									-- merge style with template style
				theme[stylename] = mergetable(addon.ThemeTemplate, style)		-- ie. fill in the blanks
			end
		end

		-- Choices: Overwrite themeName as it's processed, or Overwrite after the processing is done
		UseTheme(theme)

		-- ie. (Theme Table, Theme Name) -- nil is sent for all themes, to reset everything (^ above ^) and then the current theme is activated
		if theme.OnActivateTheme then theme.OnActivateTheme(theme) end
		addon.activeThemeName = themeName

		TidyPlatesInternal:ForceUpdate()
		return theme
	else
		-- This block falls back to the template, and leaves the field blank...
		addon.activeThemeName = nil

		UseTheme(addon.ThemeTemplate)
		return nil
	end


end

-- /run TidyPlatesInternal:SetTheme("Neon")

TidyPlatesInternal.SetTheme = SetTheme
addon.SetTheme = SetTheme
