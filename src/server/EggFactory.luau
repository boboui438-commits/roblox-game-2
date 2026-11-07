--!nonstrict
--[[
	EggFactory
	----------
	Fabrique les modèles 3D des œufs uniquement avec des primitives Roblox
	(aucun asset externe => rien ne peut casser).

	Chaque modèle :
		Body (PrimaryPart, Ball) + accessoires selon `style`
		BillboardGui avec le nom, le niveau et les revenus
		Attributs EggId / Level / Rarity pour le client
]]

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EggCatalog = require(Shared:WaitForChild("EggCatalog"))
local Util = require(Shared:WaitForChild("Util"))

local EggFactory = {}

local function part(props: { [string]: any }, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(1, 1, 1)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			p[key] = value
		end
	end
	if parent then
		p.Parent = parent
	end
	return p
end

local function addLight(model: Model, body: BasePart, color: Color3, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = 10
	light.Shadows = false
	light.Parent = body
end

local function decorate(model: Model, body: BasePart, def: any, scale: number, accent: Color3)
	local style = def.style
	local up = CFrame.new(0, body.Size.Y * 0.5, 0)

	if style == "ring" then
		part({
			Name = "Ring",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.28 * scale, body.Size.X * 0.62, body.Size.X * 0.62),
			CFrame = body.CFrame * CFrame.new(0, -body.Size.Y * 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = accent,
			Material = Enum.Material.Neon,
		}, model)
	elseif style == "halo" then
		part({
			Name = "Halo",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.22 * scale, body.Size.X * 1.75, body.Size.X * 1.75),
			CFrame = body.CFrame
				* CFrame.new(0, 0.4, 0)
				* CFrame.Angles(math.rad(18), 0, 0)
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = accent,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		}, model)
		addLight(model, body, accent, 0.6)
	elseif style == "spikes" then
		local count = 7
		for index = 1, count do
			local angle = (index / count) * math.pi * 2
			part({
				Name = "Spike",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.5, 1.5, 0.5) * scale,
				CFrame = body.CFrame
					* CFrame.Angles(0, angle, 0)
					* CFrame.new(0, 0.35, -body.Size.X * 0.42)
					* CFrame.Angles(math.rad(-25), 0, 0),
				Color = accent,
				Material = Enum.Material.Neon,
			}, model)
		end
		addLight(model, body, accent, 0.35)
	elseif style == "aura" then
		part({
			Name = "Aura",
			Shape = Enum.PartType.Ball,
			Size = body.Size * 1.45,
			CFrame = body.CFrame,
			Color = accent,
			Material = Enum.Material.Neon,
			Transparency = 0.82,
		}, model)
		for index = 1, 3 do
			local angle = (index / 3) * math.pi * 2
			part({
				Name = "Orb",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.55, 0.55, 0.55) * scale,
				CFrame = body.CFrame
					* CFrame.Angles(0, angle, 0)
					* CFrame.new(0, body.Size.Y * 0.15, -body.Size.X * 0.95),
				Color = accent,
				Material = Enum.Material.Neon,
			}, model)
		end
		addLight(model, body, accent, 1.2)
	elseif style == "crown" then
		part({
			Name = "CrownBase",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4 * scale, body.Size.X * 0.75, body.Size.X * 0.75),
			CFrame = body.CFrame * up * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 214, 92),
			Material = Enum.Material.Neon,
		}, model)
		for index = 1, 5 do
			local angle = (index / 5) * math.pi * 2
			part({
				Name = "CrownPoint",
				Size = Vector3.new(0.35, 1.1, 0.35) * scale,
				CFrame = body.CFrame
					* up
					* CFrame.Angles(0, angle, 0)
					* CFrame.new(0, 0.5 * scale, -body.Size.X * 0.26)
					* CFrame.Angles(math.rad(-14), 0, 0),
				Color = accent,
				Material = Enum.Material.Neon,
			}, model)
		end
		addLight(model, body, accent, 1.4)
	elseif style == "crack" then
		for index = 1, 3 do
			local angle = (index / 3) * math.pi * 2 + 0.6
			part({
				Name = "Speck",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.55, 0.75, 0.3) * scale,
				CFrame = body.CFrame
					* CFrame.Angles(0, angle, 0)
					* CFrame.new(0, (index - 2) * 0.55 * scale, -body.Size.X * 0.44),
				Color = accent,
				Material = Enum.Material.SmoothPlastic,
			}, model)
		end
	end
end

local function buildBillboard(body: BasePart, def: any, level: number): BillboardGui
	local rarity = EggCatalog.rarityById[def.rarity] or EggCatalog.rarityById["commun"]
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EggInfo"
	billboard.Adornee = body
	billboard.Size = UDim2.fromOffset(210, 78)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.9, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 140
	billboard.LightInfluence = 0
	billboard.Parent = body

	local name = Instance.new("TextLabel")
	name.Name = "EggName"
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.55)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextWrapped = true
	name.TextStrokeTransparency = 0.35
	name.TextColor3 = Color3.fromHex(rarity.color)
	name.Text = def.name
	name.Parent = billboard

	local stats = Instance.new("TextLabel")
	stats.Name = "EggStats"
	stats.BackgroundTransparency = 1
	stats.Position = UDim2.fromScale(0, 0.56)
	stats.Size = UDim2.fromScale(1, 0.34)
	stats.Font = Enum.Font.GothamMedium
	stats.TextScaled = true
	stats.TextStrokeTransparency = 0.45
	stats.TextColor3 = Color3.fromRGB(226, 232, 244)
	stats.Text = string.format("Niv.%d  ·  +%s/s", level, Util.formatNumber(EggCatalog.incomeFor(def, level)))
	stats.Parent = billboard

	return billboard
end

--- Construit le modèle 3D d'un œuf.
function EggFactory.build(def: any, level: number): Model
	local scale = def.scale or 1
	local bodyColor = Color3.fromHex(def.body)
	local accentColor = Color3.fromHex(def.accent)

	local model = Instance.new("Model")
	model.Name = "Egg_" .. def.id
	model:SetAttribute("EggId", def.id)
	model:SetAttribute("Level", level)
	model:SetAttribute("Rarity", def.rarity)

	local body = part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.0, 4.35, 3.0) * scale,
		Color = bodyColor,
	}, model)
	body.CanQuery = false

	if def.rarity == "secret" or def.rarity == "divin" then
		body.Material = Enum.Material.Neon
	elseif def.rarity == "mythique" then
		body.Material = Enum.Material.Metal
	end

	decorate(model, body, def, scale, accentColor)
	buildBillboard(body, def, level)

	model.PrimaryPart = body
	model:SetAttribute("BaseCFrame", body.CFrame)
	CollectionService:AddTag(model, "EggVisual")
	return model
end

--- Met à jour le texte du panneau d'un œuf (niveau / revenus).
function EggFactory.refreshBillboard(model: Model, def: any, level: number)
	local body = model.PrimaryPart or model:FindFirstChild("Body")
	if not body then
		return
	end
	local billboard = body:FindFirstChild("EggInfo")
	if not billboard then
		return
	end
	local stats = billboard:FindFirstChild("EggStats")
	if stats then
		stats.Text = string.format(
			"Niv.%d  ·  +%s/s",
			level,
			Util.formatNumber(EggCatalog.incomeFor(def, level))
		)
	end
	model:SetAttribute("Level", level)
end

return EggFactory
