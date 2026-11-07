--!nonstrict
--[[
	SceneService
	------------
	Ambiance visuelle : lumière, atmosphère, bloom, couleurs.
	(pas d'assets externes, uniquement des effets Roblox)
]]

local Lighting = game:GetService("Lighting")

local SceneService = {}

local function addEffect(className: string, props: { [string]: any }): any
	local effect = Lighting:FindFirstChildOfClass(className)
	if not effect then
		effect = Instance.new(className)
	end
	for key, value in pairs(props) do
		if key ~= "Parent" then
			effect[key] = value
		end
	end
	effect.Parent = Lighting
	return effect
end

function SceneService.init()
	Lighting.ClockTime = 15.4
	Lighting.GeographicLatitude = 12
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(86, 92, 108)
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 148, 168)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4
	Lighting.ExposureCompensation = 0.2
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.FogEnd = 900
	Lighting.FogStart = 250

	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	addEffect("Atmosphere", {
		Density = 0.34,
		Offset = 0.12,
		Color = Color3.fromRGB(210, 224, 240),
		Decay = Color3.fromRGB(120, 140, 180),
		Glare = 0.35,
		Haze = 1.4,
	})

	addEffect("BloomEffect", {
		Intensity = 0.55,
		Size = 32,
		Threshold = 1.05,
	})

	addEffect("ColorCorrectionEffect", {
		Brightness = 0.02,
		Contrast = 0.12,
		Saturation = 0.18,
		TintColor = Color3.fromRGB(255, 250, 244),
	})

	addEffect("SunRaysEffect", {
		Intensity = 0.12,
		Spread = 0.6,
	})
end

return SceneService
