local _, ns = ...
local t = ns.ThreatPlates

local class = t.Class()
local AuraType = {
	DEATHKNIGHT = "presences",
	DRUID = "shapeshifts",
	PALADIN = "seals",
	WARRIOR = "stances"
}
local function ShapeshiftUpdate()
	--[[
	local db = TidyPlatesThreat.db.char[AuraType[class]]
	--[[
	if db.ON then
		TidyPlatesThreat.db.char.spec[t.Active()] = db[GetShapeshiftForm()]
		t.Update()
	end
	]]--
end

TidyPlatesThreat.ShapeshiftUpdate = ShapeshiftUpdate