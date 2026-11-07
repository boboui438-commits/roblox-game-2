--!nonstrict
--[[
	MapBuilder
	----------
	Construit toute la map en code (aucun asset externe requis) :
	  - sol, routes, place centrale + kiosque boutique
	  - 12 parcelles joueur avec 8 socles chacune, clôtures, panneaux
	  - décorations (arbres, rochers, arches)

	Retourne une table `world` utilisée par PlotService / EggService.
]]

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local MapBuilder = {}

local MAP_NAME = "StealAnEggMap"

local PLOT_COLORS = {
	"#4FC3F7",
	"#FF8A65",
	"#AED581",
	"#BA68C8",
	"#FFD54F",
	"#4DD0E1",
	"#F06292",
	"#9575CD",
	"#81C784",
	"#FFB74D",
	"#64B5F6",
	"#E57373",
}

-- Helpers -----------------------------------------------------------------

local function newPart(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = Vector3.new(1, 1, 1)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end

local function newLabel(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextWrapped = true
	for key, value in pairs(props) do
		label[key] = value
	end
	label.Parent = parent
	return label
end

local function makeBillboard(adornee: BasePart, size: UDim2, offset: Vector3): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Info"
	billboard.Adornee = adornee
	billboard.Size = size
	billboard.StudsOffsetWorldSpace = offset
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 220
	billboard.LightInfluence = 0
	billboard.Parent = adornee
	return billboard
end

local function rounded(frame: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
end

-- Construction ------------------------------------------------------------

local function clearOldMap()
	local old = Workspace:FindFirstChild(MAP_NAME)
	if old then
		old:Destroy()
	end
	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
end

local function buildGround(parent: Instance)
	local ground = newPart(parent, {
		Name = "Ground",
		Size = Vector3.new(Config.GroundSize, 4, Config.GroundSize),
		CFrame = CFrame.new(0, -2, 0),
		Color = Color3.fromRGB(96, 172, 108),
		Material = Enum.Material.Grass,
	})

	local plaza = newPart(parent, {
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 130, 130),
		CFrame = CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(206, 200, 186),
		Material = Enum.Material.Cobblestone,
	})
	plaza.CanCollide = true

	-- Liseré lumineux autour de la place
	for index = 1, 2 do
		local ring = newPart(parent, {
			Name = "PlazaRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 130 + index * 14, 130 + index * 14),
			CFrame = CFrame.new(0, 0.72, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = index == 1 and Color3.fromRGB(120, 240, 200) or Color3.fromRGB(255, 215, 120),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		ring.CanQuery = false
	end

	-- Routes vers chaque parcelle
	for index = 1, Config.PlotCount do
		local angle = ((index - 1) / Config.PlotCount) * math.pi * 2
		local distance = Config.PlotRadius - 24
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local center = direction * (32 + distance * 0.5)
		local road = newPart(parent, {
			Name = "Path",
			Size = Vector3.new(14, 0.4, distance - 24),
			CFrame = CFrame.new(center + Vector3.new(0, 0.22, 0))
				* CFrame.Angles(0, -angle + math.pi / 2, 0),
			Color = Color3.fromRGB(186, 178, 160),
			Material = Enum.Material.Slate,
		})
		road.CanCollide = false
	end

	return ground, plaza
end

local function buildKiosk(parent: Instance, center: Vector3): ProximityPrompt
	local model = Instance.new("Model")
	model.Name = "ShopKiosk"
	model.Parent = parent

	local base = newPart(model, {
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 30, 30),
		CFrame = CFrame.new(center + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(42, 46, 58),
		Material = Enum.Material.Concrete,
	})
	base.Name = "Base"

	newPart(model, {
		Name = "Glow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.18, 34, 34),
		CFrame = CFrame.new(center + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(90, 255, 210),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})

	-- Grand œuf décoratif au centre
	local egg = newPart(model, {
		Name = "BigEgg",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(13, 17, 13),
		CFrame = CFrame.new(center + Vector3.new(0, 13, 0)),
		Color = Color3.fromRGB(255, 246, 214),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	egg.CanQuery = false

	local halo = newPart(model, {
		Name = "Halo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.16, 22, 22),
		CFrame = CFrame.new(center + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 205, 100),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	halo.CanQuery = false

	-- Panneau titre
	local titlePart = newPart(model, {
		Name = "Title",
		Size = Vector3.new(0.4, 8, 34),
		CFrame = CFrame.new(center + Vector3.new(-22, 12, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(24, 26, 34),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.15,
	})
	titlePart.CanCollide = false

	local titleGui = Instance.new("SurfaceGui")
	titleGui.Name = "TitleGui"
	titleGui.Face = Enum.NormalId.Right
	titleGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	titleGui.PixelsPerStud = 50
	titleGui.LightInfluence = 0
	titleGui.Parent = titlePart

	newLabel(titleGui, {
		Name = "Main",
		Size = UDim2.fromScale(1, 0.55),
		Position = UDim2.fromScale(0, 0.08),
		Text = "STEAL A EGG",
		TextColor3 = Color3.fromRGB(255, 226, 140),
		TextStrokeTransparency = 0.55,
	})
	newLabel(titleGui, {
		Name = "Sub",
		Size = UDim2.fromScale(1, 0.25),
		Position = UDim2.fromScale(0, 0.62),
		Text = "Vole. Défends. Collectionne.",
		TextColor3 = Color3.fromRGB(150, 255, 225),
		TextStrokeTransparency = 0.7,
	})

	-- Texte flottant au-dessus du kiosque
	local floating = newPart(model, {
		Name = "FloatingSign",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(center + Vector3.new(0, 26, 0)),
		Transparency = 1,
		CanCollide = false,
	})
	floating.CanQuery = false
	local floatingGui = makeBillboard(floating, UDim2.fromOffset(420, 110), Vector3.zero)
	floatingGui.AlwaysOnTop = true
	newLabel(floatingGui, {
		Name = "Caption",
		Size = UDim2.fromScale(1, 1),
		Text = "STEAL A EGG",
		TextColor3 = Color3.fromRGB(255, 236, 170),
		TextStrokeTransparency = 0.2,
		TextStrokeColor3 = Color3.fromRGB(70, 40, 0),
		TextScaled = true,
	})

	local promptPad = newPart(model, {
		Name = "ShopPad",
		Size = Vector3.new(12, 0.4, 12),
		CFrame = CFrame.new(center + Vector3.new(0, 2.55, 0)),
		Color = Color3.fromRGB(60, 240, 190),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Ouvrir la boutique"
	prompt.ObjectText = "Boutique d'œufs"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = promptPad

	return prompt
end

local function buildPlot(parent: Instance, index: number): any
	local angle = ((index - 1) / Config.PlotCount) * math.pi * 2
	local position = Vector3.new(math.cos(angle) * Config.PlotRadius, 0, math.sin(angle) * Config.PlotRadius)
	local plotCFrame = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
	local accent = Color3.fromHex(PLOT_COLORS[((index - 1) % #PLOT_COLORS) + 1])

	local model = Instance.new("Model")
	model.Name = "Plot_" .. index
	model:SetAttribute("PlotIndex", index)
	model.Parent = parent

	local function at(localCFrame: CFrame): CFrame
		return plotCFrame * localCFrame
	end

	-- Sol de la parcelle
	newPart(model, {
		Name = "Floor",
		Size = Vector3.new(36, 1, 36),
		CFrame = at(CFrame.new(0, 0.1, 0)),
		Color = Color3.fromRGB(58, 62, 74),
		Material = Enum.Material.Slate,
	})

	-- Liseré coloré
	local trim = newPart(model, {
		Name = "Trim",
		Size = Vector3.new(36.6, 0.5, 36.6),
		CFrame = at(CFrame.new(0, 0.62, 0)),
		Color = accent,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
	})
	trim.CanQuery = false

	-- Clôtures (3 côtés, ouverture vers le centre)
	local walls = {
		{ size = Vector3.new(36, 7, 1), offset = Vector3.new(0, 3.5, 18) },
		{ size = Vector3.new(1, 7, 36), offset = Vector3.new(18, 3.5, 0) },
		{ size = Vector3.new(1, 7, 36), offset = Vector3.new(-18, 3.5, 0) },
	}
	for wallIndex, wall in ipairs(walls) do
		newPart(model, {
			Name = "Wall" .. wallIndex,
			Size = wall.size,
			CFrame = at(CFrame.new(wall.offset)),
			Color = accent,
			Material = Enum.Material.Glass,
			Transparency = 0.55,
			CanCollide = true,
		})
	end

	-- Poteaux aux coins
	for _, corner in ipairs({
		Vector3.new(-18, 3.5, -18),
		Vector3.new(18, 3.5, -18),
		Vector3.new(-18, 3.5, 18),
		Vector3.new(18, 3.5, 18),
	}) do
		newPart(model, {
			Name = "Post",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(7.4, 1.2, 1.2),
			CFrame = at(CFrame.new(corner) * CFrame.Angles(0, 0, math.rad(90))),
			Color = accent,
			Material = Enum.Material.Neon,
			Transparency = 0.25,
		})
	end

	-- Socles ------------------------------------------------------------
	local slotOffsets = {
		Vector3.new(-7.5, 0, -9),
		Vector3.new(7.5, 0, -9),
		Vector3.new(-7.5, 0, -3),
		Vector3.new(7.5, 0, -3),
		Vector3.new(-7.5, 0, 3),
		Vector3.new(7.5, 0, 3),
		Vector3.new(-7.5, 0, 9),
		Vector3.new(7.5, 0, 9),
	}

	local slots = {}
	for slotIndex = 1, Config.MaxSlots do
		local offset = slotOffsets[slotIndex]
		local pedestalCFrame = at(CFrame.new(offset + Vector3.new(0, 0.9, 0)))

		local pedestal = newPart(model, {
			Name = "Pedestal" .. slotIndex,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.8, 6, 6),
			CFrame = pedestalCFrame * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(46, 50, 62),
			Material = Enum.Material.Concrete,
		})
		pedestal.CanQuery = false
		pedestal:SetAttribute("SlotIndex", slotIndex)

		local ring = newPart(model, {
			Name = "Ring" .. slotIndex,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.22, 6.4, 6.4),
			CFrame = at(CFrame.new(offset + Vector3.new(0, 1.85, 0))) * CFrame.Angles(0, 0, math.rad(90)),
			Color = accent,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Transparency = 0.25,
		})
		ring.CanQuery = false

		-- Point d'ancrage de l'œuf
		local anchor = newPart(model, {
			Name = "EggAnchor" .. slotIndex,
			Size = Vector3.new(0.4, 0.4, 0.4),
			CFrame = at(CFrame.new(offset + Vector3.new(0, 4.1, 0))),
			Transparency = 1,
			CanCollide = false,
		})
		anchor.CanQuery = false

		-- Panneau "verrouillé"
		local lockPart = newPart(model, {
			Name = "Lock" .. slotIndex,
			Size = Vector3.new(3.2, 3.2, 0.5),
			CFrame = at(CFrame.new(offset + Vector3.new(0, 6.4, 0))) * CFrame.Angles(0, math.rad(180), 0),
			Color = Color3.fromRGB(255, 120, 120),
			Material = Enum.Material.Neon,
			Transparency = 0.45,
			CanCollide = false,
		})
		lockPart:SetAttribute("SlotIndex", slotIndex)
		local lockGui = makeBillboard(lockPart, UDim2.fromOffset(190, 60), Vector3.new(0, 1.6, 0))
		local lockLabel = newLabel(lockGui, {
			Name = "Label",
			Size = UDim2.fromScale(1, 1),
			Text = "VERROUILLÉ",
			TextColor3 = Color3.fromRGB(255, 190, 190),
			TextStrokeTransparency = 0.4,
		})

		local securePrompt = Instance.new("ProximityPrompt")
		securePrompt.Name = "SecurePrompt"
		securePrompt.ActionText = "Sécuriser l'œuf"
		securePrompt.ObjectText = "Socle"
		securePrompt.KeyboardKeyCode = Enum.KeyCode.E
		securePrompt.HoldDuration = 0
		securePrompt.MaxActivationDistance = 14
		securePrompt.RequiresLineOfSight = false
		securePrompt.Enabled = false
		securePrompt.Parent = pedestal

		local upgradePrompt = Instance.new("ProximityPrompt")
		upgradePrompt.Name = "UpgradePrompt"
		upgradePrompt.ActionText = "Débloquer le socle"
		upgradePrompt.ObjectText = "Socle verrouillé"
		upgradePrompt.KeyboardKeyCode = Enum.KeyCode.E
		upgradePrompt.HoldDuration = 0.2
		upgradePrompt.MaxActivationDistance = 14
		upgradePrompt.RequiresLineOfSight = false
		upgradePrompt.Enabled = false
		upgradePrompt.Parent = lockPart

		table.insert(slots, {
			index = slotIndex,
			offset = offset,
			pedestal = pedestal,
			ring = ring,
			anchor = anchor,
			lockPart = lockPart,
			lockLabel = lockLabel,
			securePrompt = securePrompt,
			upgradePrompt = upgradePrompt,
			position = (at(CFrame.new(offset + Vector3.new(0, 4.1, 0)))).Position,
			locked = slotIndex > Config.StartSlots,
		})
	end

	-- Panneau de la parcelle -------------------------------------------
	local sign = newPart(model, {
		Name = "Sign",
		Size = Vector3.new(18, 7, 0.6),
		CFrame = at(CFrame.new(0, 5.6, 17.4)),
		Color = Color3.fromRGB(28, 31, 40),
		Material = Enum.Material.SmoothPlastic,
	})
	sign.CanCollide = false

	newPart(model, {
		Name = "SignPost",
		Size = Vector3.new(1, 5, 1),
		CFrame = at(CFrame.new(-6, 2.5, 17.4)),
		Color = Color3.fromRGB(60, 64, 76),
	})
	newPart(model, {
		Name = "SignPost",
		Size = Vector3.new(1, 5, 1),
		CFrame = at(CFrame.new(6, 2.5, 17.4)),
		Color = Color3.fromRGB(60, 64, 76),
	})

	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "SignGui"
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 40
	signGui.LightInfluence = 0
	signGui.Parent = sign

	local signTitle = newLabel(signGui, {
		Name = "Title",
		Size = UDim2.fromScale(1, 0.45),
		Position = UDim2.fromScale(0, 0.05),
		Text = "Parcelle libre",
		TextColor3 = accent,
		TextStrokeTransparency = 0.6,
	})
	local signUpgrade = newLabel(signGui, {
		Name = "Upgrade",
		Size = UDim2.fromScale(1, 0.35),
		Position = UDim2.fromScale(0, 0.52),
		Text = "Disponible",
		TextColor3 = Color3.fromRGB(210, 216, 230),
		Font = Enum.Font.GothamMedium,
		TextStrokeTransparency = 0.7,
	})

	-- Barre de progression du verrou (affichée quand la base est protégée)
	local signLock = newLabel(signGui, {
		Name = "Lock",
		Size = UDim2.fromScale(1, 0.18),
		Position = UDim2.fromScale(0, 0.85),
		Text = "",
		TextColor3 = Color3.fromRGB(120, 255, 200),
		Font = Enum.Font.GothamBold,
		TextStrokeTransparency = 0.6,
	})

	local spawn = newPart(model, {
		Name = "Spawn",
		Size = Vector3.new(8, 0.4, 8),
		CFrame = at(CFrame.new(0, 0.65, -14.5)),
		Color = accent,
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
	})
	spawn.CanQuery = false

	local spawnCFrame = at(CFrame.new(0, 4.5, -14.5)) * CFrame.Angles(0, math.rad(180), 0)

	return {
		index = index,
		model = model,
		cframe = plotCFrame,
		accent = accent,
		slots = slots,
		sign = sign,
		signTitle = signTitle,
		signUpgrade = signUpgrade,
		signLock = signLock,
		spawnCFrame = spawnCFrame,
		ownerUserId = nil,
	}
end

local function buildDecor(parent: Instance)
	local random = Random.new(2024)

	-- Arbres
	for _ = 1, 46 do
		local angle = random:NextNumber() * math.pi * 2
		local radius = random:NextNumber() < 0.4 and random:NextNumber(34, 70) or random:NextNumber(160, 250)
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

		local tree = Instance.new("Model")
		tree.Name = "Tree"
		tree.Parent = parent

		newPart(tree, {
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(random:NextNumber(8, 13), 2.2, 2.2),
			CFrame = CFrame.new(position + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(112, 79, 52),
			Material = Enum.Material.Wood,
		})
		for leafIndex = 1, 3 do
			newPart(tree, {
				Name = "Leaf" .. leafIndex,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1, 1, 1) * random:NextNumber(9, 14) * (1 + leafIndex * 0.12),
				CFrame = CFrame.new(position + Vector3.new(0, 9 + leafIndex * 3.2, 0)),
				Color = Color3.fromRGB(
					random:NextInteger(64, 96),
					random:NextInteger(140, 186),
					random:NextInteger(78, 112)
				),
				Material = Enum.Material.Grass,
				CanCollide = false,
			})
		end
	end

	-- Rochers
	for _ = 1, 26 do
		local angle = random:NextNumber() * math.pi * 2
		local radius = random:NextNumber(40, 245)
		local size = random:NextNumber(3, 7)
		newPart(parent, {
			Name = "Rock",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size * 0.7, size * 1.2),
			CFrame = CFrame.new(math.cos(angle) * radius, 0.4, math.sin(angle) * radius)
				* CFrame.Angles(random:NextNumber(0, 3), random:NextNumber(0, 3), 0),
			Color = Color3.fromRGB(120, 124, 132),
			Material = Enum.Material.Rock,
		})
	end
end

--- Construit la map complète.
function MapBuilder.build(): any
	clearOldMap()

	local folder = Instance.new("Folder")
	folder.Name = MAP_NAME
	folder.Parent = Workspace

	buildGround(folder)

	local world = {
		folder = folder,
		center = Vector3.zero,
		plots = {},
	}

	world.shopPrompt = buildKiosk(folder, world.center)

	for index = 1, Config.PlotCount do
		local plot = buildPlot(folder, index)
		table.insert(world.plots, plot)
	end

	buildDecor(folder)

	return world
end

--- Met à jour l'apparence "verrouillé / déverrouillé" d'un socle.
function MapBuilder.setSlotUnlocked(plot: any, slotIndex: number, unlocked: boolean, price: number?)
	local slot = plot.slots[slotIndex]
	if not slot then
		return
	end
	slot.locked = not unlocked
	slot.lockPart.Transparency = unlocked and 1 or 0.45
	slot.lockPart.CanCollide = false
	slot.ring.Transparency = unlocked and 0.25 or 0.75
	if unlocked then
		slot.lockLabel.Text = ""
	else
		slot.lockLabel.Text = "DÉBLOQUER\n$" .. (price and Util.formatNumber(price) or "?")
	end
end

--- Met à jour le panneau d'une parcelle (nom du propriétaire, revenus).
function MapBuilder.setPlotSign(plot: any, title: string, subtitle: string, color: Color3?)
	plot.signTitle.Text = title
	plot.signUpgrade.Text = subtitle
	if color then
		plot.signTitle.TextColor3 = color
	end
end

--- Affiche / cache le statut "base protégée".
function MapBuilder.setPlotLock(plot: any, text: string, locked: boolean)
	plot.signLock.Text = text
	plot.signLock.TextColor3 = locked and Color3.fromRGB(120, 255, 200) or Color3.fromRGB(255, 170, 120)
	plot.signLock.Visible = text ~= ""
end

return MapBuilder
