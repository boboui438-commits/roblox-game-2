--!nonstrict
--[[
	EggPanel
	--------
	Panneau d'action d'un œuf de sa base : fusionner / vendre.
	Ouvert par le prompt "Gérer" (le serveur envoie l'évènement Panel).
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local EggCatalog = require(Shared:WaitForChild("EggCatalog"))
local Config = require(Shared:WaitForChild("Config"))

local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)

local EggPanel = {}

local callbacks = {}
local scrim: Frame
local panel: Frame
local iconHolder: Frame
local nameLabel: TextLabel
local rarityLabel: TextLabel
local statsLabel: TextLabel
local mergeHint: TextLabel
local mergeButton: TextButton
local mergeLabel: TextLabel
local sellButton: TextButton
local sellLabel: TextLabel
local blur: BlurEffect

local isOpen = false
local currentUid: string? = nil
local currentState: any = nil

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	currentUid = nil
	UiKit.tween(scrim, { BackgroundTransparency = 1 }, 0.14)
	UiKit.tween(panel, { Position = UDim2.new(0.5, 0, 0.5, 10) }, 0.14)
	task.delay(0.16, function()
		if not isOpen then
			scrim.Visible = false
			panel.Visible = false
		end
	end)
	if blur then
		TweenService:Create(blur, TweenInfo.new(0.2), { Size = 0 }):Play()
	end
end

local function findEgg(state: any, uid: string): any?
	if not state or not state.eggs then
		return nil
	end
	for _, egg in ipairs(state.eggs) do
		if egg.uid == uid then
			return egg
		end
	end
	return nil
end

local function findPartner(state: any, egg: any): any?
	for _, other in ipairs(state.eggs or {}) do
		if other.uid ~= egg.uid and other.eggId == egg.eggId and other.level == egg.level then
			return other
		end
	end
	return nil
end

local function refresh()
	if not currentState or not currentUid then
		return
	end
	local egg = findEgg(currentState, currentUid)
	if not egg then
		close()
		return
	end

	local def = EggCatalog.get(egg.eggId)
	if not def then
		close()
		return
	end

	local rarity = EggCatalog.rarityById[def.rarity] or EggCatalog.rarityById["commun"]
	local rarityColor = Color3.fromHex(rarity.color)

	iconHolder:ClearAllChildren()
	local icon = UiKit.eggIcon(iconHolder, def.id, 96)
	icon.Size = UDim2.fromScale(1, 1)

	nameLabel.Text = def.name
	nameLabel.TextColor3 = rarityColor
	rarityLabel.Text = rarity.name:upper() .. "  ·  NIVEAU " .. egg.level
	rarityLabel.TextColor3 = rarityColor
	statsLabel.Text = ("Revenus : +%s/s     Valeur : $%s"):format(
		Util.formatNumber(egg.income),
		Util.formatNumber(math.floor(def.price * EggCatalog.levelMultiplier(egg.level) * Config.SellRefund))
	)

	local partner = findPartner(currentState, egg)
	local maxed = egg.level >= Config.MaxEggLevel
	if maxed then
		mergeHint.Text = "Niveau maximum atteint."
		mergeHint.TextColor3 = Theme.colors.gold
	elseif partner then
		mergeHint.Text = "Deuxième œuf identique détecté : prêt à fusionner !"
		mergeHint.TextColor3 = Theme.colors.success
	else
		mergeHint.Text = ("Il te faut un 2e %s niveau %d pour fusionner."):format(def.name, egg.level)
		mergeHint.TextColor3 = Theme.colors.dim
	end

	local canMerge = partner ~= nil and not maxed
	mergeButton.Active = canMerge
	mergeButton.BackgroundTransparency = canMerge and 0 or 0.55
	mergeLabel.TextColor3 = canMerge and Theme.colors.text or Theme.colors.dim
	mergeLabel.Text = canMerge and "Fusionner" or "Fusion indisponible"

	local sellValue = math.floor(def.price * EggCatalog.levelMultiplier(egg.level) * Config.SellRefund)
	sellLabel.Text = "Vendre · $" .. Util.formatNumber(sellValue)
end

local function open(uid: string, state: any)
	currentUid = uid
	currentState = state

	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local width = 420
	local height = 380
	if viewport.X < 560 then
		width = math.min(viewport.X - 40, 420)
		height = math.min(viewport.Y - 60, 380)
	end
	panel.Size = UDim2.fromOffset(width, height)

	refresh()

	if isOpen then
		return
	end
	isOpen = true
	scrim.Visible = true
	panel.Visible = true
	scrim.BackgroundTransparency = 1
	panel.Position = UDim2.new(0.5, 0, 0.5, 10)

	UiKit.tween(scrim, { BackgroundTransparency = 0.35 }, 0.16)
	UiKit.tween(panel, { Position = UDim2.new(0.5, 0, 0.5, 0) }, 0.2, Enum.EasingStyle.Back)

	if blur then
		blur.Size = 0
		TweenService:Create(blur, TweenInfo.new(0.2), { Size = 12 }):Play()
	end
end

function EggPanel.init(parent: Instance, newCallbacks: any)
	callbacks = newCallbacks or {}

	blur = Lighting:FindFirstChildOfClass("BlurEffect")

	scrim = UiKit.create("Frame", {
		Name = "EggScrim",
		BackgroundColor3 = Theme.colors.scrim,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 30,
	}, parent)
	scrim.Active = true

	panel = UiKit.panel(parent, {
		Name = "EggPanel",
		Size = UDim2.fromOffset(420, 380),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 31,
		Gradient = { Theme.colors.panel, Theme.colors.panelHard },
		GradientRotation = 110,
	})
	UiKit.stroke(panel, Theme.colors.stroke, 1, 0.4)

	UiKit.text(panel, {
		Text = "GÉRER L'ŒUF",
		TextSize = 13,
		Font = Theme.fonts.bold,
		TextColor3 = Theme.colors.dim,
		Size = UDim2.new(1, -100, 0, 18),
		Position = UDim2.fromOffset(20, 14),
		ZIndex = 32,
	})

	UiKit.button(panel, {
		Name = "CloseButton",
		Text = "✕",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(1, -14, 0, 10),
		AnchorPoint = Vector2.new(1, 0),
		Color = Theme.colors.panelSoft,
		OnClick = function()
			close()
		end,
		ZIndex = 33,
	})

	iconHolder = UiKit.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(100, 100),
		Position = UDim2.new(0, 20, 0, 44),
		ZIndex = 32,
	}, panel)

	nameLabel = UiKit.text(panel, {
		Text = "Œuf",
		TextSize = 19,
		Font = Theme.fonts.black,
		TextColor3 = Theme.colors.text,
		Size = UDim2.new(1, -160, 0, 26),
		Position = UDim2.fromOffset(132, 48),
		ZIndex = 32,
	})

	rarityLabel = UiKit.text(panel, {
		Text = "COMMUN",
		TextSize = 12,
		Font = Theme.fonts.bold,
		TextColor3 = Theme.colors.dim,
		Size = UDim2.new(1, -160, 0, 18),
		Position = UDim2.fromOffset(132, 76),
		ZIndex = 32,
	})

	statsLabel = UiKit.text(panel, {
		Text = "",
		TextSize = 13,
		Font = Theme.fonts.medium,
		TextColor3 = Theme.colors.text,
		Size = UDim2.new(1, -160, 0, 34),
		Position = UDim2.fromOffset(132, 98),
		ZIndex = 32,
	})

	mergeHint = UiKit.text(panel, {
		Text = "",
		TextSize = 12,
		Font = Theme.fonts.medium,
		TextColor3 = Theme.colors.dim,
		TextWrapped = true,
		Size = UDim2.new(1, -40, 0, 34),
		Position = UDim2.fromOffset(20, 160),
		ZIndex = 32,
	})

	mergeButton = UiKit.button(panel, {
		Name = "MergeButton",
		Text = "Fusionner",
		Size = UDim2.new(1, -40, 0, 44),
		Position = UDim2.fromOffset(20, 202),
		Color = Theme.colors.panelSoft,
		Gradient = { Color3.fromRGB(120, 96, 240), Color3.fromRGB(72, 52, 160) },
		OnClick = function()
			if not currentUid or not mergeButton.Active then
				return
			end
			if callbacks.onMerge then
				callbacks.onMerge(currentUid)
			end
		end,
		ZIndex = 33,
	})
	mergeLabel = mergeButton:FindFirstChildWhichIsA("TextLabel")

	sellButton = UiKit.button(panel, {
		Name = "SellButton",
		Text = "Vendre",
		Size = UDim2.new(1, -40, 0, 44),
		Position = UDim2.fromOffset(20, 256),
		Color = Theme.colors.panelHard,
		OnClick = function()
			if not currentUid then
				return
			end
			if callbacks.onSell then
				callbacks.onSell(currentUid)
			end
		end,
		ZIndex = 33,
	})
	sellLabel = sellButton:FindFirstChildWhichIsA("TextLabel")

	UiKit.button(panel, {
		Name = "DoneButton",
		Text = "Fermer",
		Size = UDim2.new(1, -40, 0, 38),
		Position = UDim2.fromOffset(20, 310),
		Color = Theme.colors.panelSoft,
		OnClick = function()
			close()
		end,
		ZIndex = 33,
	})

	scrim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			close()
		end
	end)

	EggPanel.close = close
end

function EggPanel.show(uid: string, state: any)
	open(uid, state)
end

function EggPanel.update(state: any)
	currentState = state
	if isOpen then
		refresh()
	end
end

function EggPanel.isOpen(): boolean
	return isOpen
end

return EggPanel
