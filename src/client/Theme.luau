--!nonstrict
--[[
	Theme
	-----
	Palette et polices de l'interface (design system minimal).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EggCatalog = require(Shared:WaitForChild("EggCatalog"))

local Theme = {}

Theme.colors = {
	bg = Color3.fromRGB(8, 10, 15),
	scrim = Color3.fromRGB(5, 7, 11),
	panel = Color3.fromRGB(19, 22, 31),
	panelSoft = Color3.fromRGB(27, 31, 43),
	panelHard = Color3.fromRGB(13, 15, 22),
	stroke = Color3.fromRGB(58, 66, 88),
	text = Color3.fromRGB(238, 242, 252),
	dim = Color3.fromRGB(150, 160, 182),
	accent = Color3.fromRGB(72, 236, 190),
	accentDark = Color3.fromRGB(28, 120, 100),
	gold = Color3.fromRGB(255, 208, 92),
	danger = Color3.fromRGB(255, 92, 118),
	info = Color3.fromRGB(120, 180, 255),
	success = Color3.fromRGB(92, 232, 150),
}

Theme.fonts = {
	black = Enum.Font.GothamBlack,
	bold = Enum.Font.GothamBold,
	medium = Enum.Font.GothamMedium,
}

Theme.rarityColor = function(eggId: string): Color3
	return EggCatalog.rarityColor(eggId)
end

Theme.rarityName = function(eggId: string): string
	return EggCatalog.getRarity(eggId).name
end

--- Couleur de texte associée à un type de message.
function Theme.kindColor(kind: string): Color3
	if kind == "success" or kind == "reward" then
		return Theme.colors.success
	elseif kind == "error" or kind == "danger" then
		return Theme.colors.danger
	elseif kind == "rare" then
		return Theme.colors.gold
	elseif kind == "steal" then
		return Theme.colors.danger
	end
	return Theme.colors.info
end

return Theme
