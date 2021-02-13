local MAJOR_VERSION = "LibDogTag-3.0"
local MINOR_VERSION = 90000 + (tonumber(("2016052752106"):match("%d+")) or 33333333333333)

if MINOR_VERSION > _G.DogTag_MINOR_VERSION then
	_G.DogTag_MINOR_VERSION = MINOR_VERSION
end

if GetLocale() == "koKR" then

DogTag_funcs[#DogTag_funcs+1] = function(DogTag)
	local L = DogTag.L
	
	L["DogTag Help"] = "DogTag 도움말"
	L["True"] = "True" -- check
end

end
