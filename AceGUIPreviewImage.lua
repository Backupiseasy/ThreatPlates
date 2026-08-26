--------------------------------------------------------------------------------------------------
-- AceGUI Widget Preview Image for options
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

local Type, Version = "ThreatPlatesImagePreview", 1

local LibAceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not LibAceGUI or (LibAceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs

-- WoW APIs

---------------------------------------------------------------------------------------------------
-- Constants and variables
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Methods
---------------------------------------------------------------------------------------------------
local Methods = {
	["OnAcquire"] = function(self)
		self:SetImage(nil)
		self:SetDisabled(false)
	end,

	["OnRelease"] = function(self)
    self.image:SetTexture(nil)
		self.border:SetTexture(nil)
	end,

	["SetImage"] = function(self, texture, ...)
		self.image:SetTexture(texture)

		local n = select("#", ...)
		if n == 4 or n == 8 then
			self.image:SetTexCoord(...)
		else
			self.image:SetTexCoord(0, 1, 0, 1)
		end
	end,

  ["SetImageSize"] = function(self, width, height)
		self.image:SetSize(width, height)
		self.frame:SetSize(width, height)
	end,

	["SetDisabled"] = function(self, disabled)
		self.disabled = disabled
		if disabled then
			self.frame:Disable()
			self.image:SetVertexColor(0.5, 0.5, 0.5, 0.5)
			self.border:SetVertexColor(0.5, 0.5, 0.5, 0.5)
		else
			self.frame:Enable()
			self.image:SetVertexColor(1, 1, 1, 1)
			self.border:SetVertexColor(1, 1, 1, 1)
		end
  end,

  ["SetLabel"] = function(self, label)
		-- Highlight Border
		local value = (type(label) == "function" and label()) or label
    if value == "Highlight" then
			self.border:SetTexture(Addon.PATH_ARTWORK .. "HighlightBorder")
	  else
			self.border:SetTexture()
    end
	end,

	["SetText"] = function() end,
	["SetFontObject"] = function() end,
}

local function Constructor()
	local name = Type .. LibAceGUI:GetNextWidgetNum(Type)
  local frame = CreateFrame("Button", name, UIParent)
	frame:Hide()
  frame:EnableMouse(false)

  local image = frame:CreateTexture(nil, "ARTWORK")
	image:SetPoint("TOP", 0, 0)

  local border = frame:CreateTexture(nil, "OVERLAY", nil, 1)
	border:SetAllPoints(image)	

	local widget = {
    frame = frame,
    image = image,
		border = border,
    type  = Type,
  }

  for method, func in pairs(Methods) do
    widget[method] = func
  end

  return LibAceGUI:RegisterAsWidget(widget)
end

LibAceGUI:RegisterWidgetType(Type, Constructor, Version)