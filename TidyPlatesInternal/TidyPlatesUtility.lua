TidyPlatesUtility = {}

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

TidyPlatesUtility.copyTable = copytable
TidyPlatesUtility.mergeTable = mergetable







