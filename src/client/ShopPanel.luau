--!nonstrict
--[[
	ShopPanel
	---------
	Boutique : 4 cartes d'œufs, timer de rafraîchissement, relance payante.
	La logique d'achat est 100% serveur, ce panneau n'est qu'une vue.
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local EggCatalog = require(Shared:WaitForChild("EggCatalog"))

local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)

local ShopPanel = {}

local callbacks = {}
local scrim: Frame
local panel: Frame
local cardsHolder: Frame
local timerBar: Frame
local timerText: TextLabel
local blur: BlurEffect

local isOpen = false
local currentState: any = nil

local function viewportSize(): Vector2
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	UiKit.tween(scrim, { BackgroundTransparency = 1 }, 0.16)
	UiKit.tween(panel, { Position = UDim2.new(0.5, 0, 0.5, 14) }, 0.16)
	task.delay(0.18, function()
		if not isOpen then
			scrim.Visible = false
			panel.Visible = false
		end
	end)
	if blur then
		TweenService:Create(blur, TweenInfo.new(0.2), { Size = 0 }):Play()
	end
end

local function open()
	if isOpen then
		return
	end
	isOpen = true
	local viewport = viewportSize()
	local width = math.clamp(viewport.X * 0.92, 300, 920)
	local height = math.clamp(viewport.Y * 0.88, 300, 540)

	panel.Size = UDim2.fromOffset(width, height)
	panel.Position = UDim2.new(0.5, 0, 0.5, 14)
	if currentState then
		render(currentState)
	end
	scrim.Visible = true
	panel.Visible = true
	scrim.BackgroundTransparency = 1

	UiKit.tween(scrim, { BackgroundTransparency = 0.35 }, 0.18)
	UiKit.tween(panel, { Position = UDim2.new(0.5, 0, 0.5, 0) }, 0.24, Enum.EasingStyle.Back)

	if blur then
		blur.Size = 0
		TweenService:Create(blur, TweenInfo.new(0.25), { Size = 14 }):Play()
	end
end

-- Une carte de la boutique -------------------------------------------------

local function makeCard(index: number, entry: any, cash: number): Frame
	local def = entry and EggCatalog.get(entry.eggId) or nil
	local card = UiKit.panel(cardsHolder, {
		Name = "Card" .. index,
		Size = UDim2.new(0.25, -8, 1, 0),
		BackgroundColor3 = Theme.colors.panelSoft,
		StrokeColor = def and EggCatalog.rarityColor(def.id) or Theme.colors.stroke,
		StrokeTransparency = 0.55,
		Gradient = { Theme.colors.panelSoft, Theme.colors.panelHard },
		GradientRotation = 90,
	})

	if not def then
		UiKit.text(card, {
			Text = "Emplacement vide",
			TextSize = 13,
			TextColor3 = Theme.colors.dim,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
		})
		return card
	end

	local rarity = EggCatalog.rarityById[def.rarity] or EggCatalog.rarityById["commun"]
	local rarityColor = Color3.fromHex(rarity.color)

	local strip = UiKit.create("Frame", {
		BackgroundColor3 = rarityColor,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 4),
		ZIndex = 4,
	}, card)
	UiKit.corner(strip, 2)

	local icon = UiKit.eggIcon(card, def.id, 84)
	icon.Size = UDim2.fromScale(0.52, 0.34)
	icon.Position = UDim2.fromScale(0.5, 0.07)
	icon.AnchorPoint = Vector2.new(0.5, 0)

	UiKit.badge(card, {
		Text = rarity.name:upper(),
		Color = rarityColor,
		Transparency = 0.82,
		TextColor3 = rarityColor,
		Size = UDim2.new(0.8, 0, 0, 19),
		Position = UDim2.fromScale(0.5, 0.43),
		AnchorPoint = Vector2.new(0.5, 0),
		TextSize = 10,
	})

	UiKit.text(card, {
		Text = def.name,
		TextSize = 14,
		Font = Theme.fonts.bold,
		TextColor3 = Theme.colors.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Size = UDim2.new(1, -14, 0, 32),
		Position = UDim2.fromScale(0.5, 0.53),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 3,
	})

	UiKit.text(card, {
		Text = "+" .. Util.formatNumber(def.income) .. "/s",
		TextSize = 13,
		Font = Theme.fonts.bold,
		TextColor3 = Theme.colors.success,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromScale(0.5, 0.68),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 3,
	})

	UiKit.text(card, {
		Text = "$" .. Util.formatNumber(def.price),
		TextSize = 18,
		Font = Theme.fonts.black,
		TextColor3 = cash >= def.price and Theme.colors.gold or Theme.colors.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromScale(0.5, 0.78),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 3,
	})

	local affordable = cash >= def.price
	local buyButton = UiKit.button(card, {
		Text = affordable and "Acheter" or ("Il manque $" .. Util.formatNumber(def.price - cash)),
		Size = UDim2.new(1, -18, 0, 34),
		Position = UDim2.new(0, 9, 1, -10),
		AnchorPoint = Vector2.new(0, 1),
		Color = affordable and Theme.colors.accentDark or Theme.colors.panelHard,
		TextColor3 = affordable and Color3.fromRGB(215, 255, 244) or Theme.colors.dim,
		TextSize = 13,
		Gradient = affordable and { Theme.colors.accent, Theme.colors.accentDark } or nil,
		OnClick = function()
			if not affordable then
				return
			end
			if callbacks.onBuy then
				callbacks.onBuy(index)
			end
			local label = buyButton:FindFirstChildWhichIsA("TextLabel")
			if label then
				label.Text = "Achat..."
			end
		end,
	})
	buyButton.Name = "BuyButton"

	return card
end

local function render(state: any)
	if not state then
		return
	end
	currentState = state
	cardsHolder:ClearAllChildren()

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = cardsHolder

	local entries = state.shop or {}
	for index = 1, 4 do
		local card = makeCard(index, entries[index], state.cash or 0)
		card.LayoutOrder = index
	end

	local remaining = math.max(0, state.shopRefresh or 0)
	timerText.Text = string.format("Nouveaux œufs dans %s", Util.formatClock(remaining))
	timerBar.Size = UDim2.fromScale(math.clamp(remaining / 15, 0, 1), 1)
end

-- Initialisation ----------------------------------------------------------

function ShopPanel.init(parent: Instance, newCallbacks: any)
	callbacks = newCallbacks or {}

	blur = Lighting:FindFirstChildOfClass("BlurEffect")
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Size = 0
		blur.Parent = Lighting
	end

	scrim = UiKit.create("Frame", {
		Name = "ShopScrim",
		BackgroundColor3 = Theme.colors.scrim,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 30,
	}, parent)
	scrim.Active = true

	panel = UiKit.panel(parent, {
		Name = "ShopPanel",
		Size = UDim2.fromOffset(860, 480),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 31,
		Gradient = { Theme.colors.panel, Theme.colors.panelHard },
		GradientRotation = 110,
	})
	UiKit.stroke(panel, Theme.colors.accent, 1, 0.55)

	UiKit.text(panel, {
		Text = "BOUTIQUE D'ŒUFS",
		TextSize = 22,
		Font = Theme.fonts.black,
		TextColor3 = Theme.colors.accent,
		Size = UDim2.new(1, -120, 0, 30),
		Position = UDim2.fromOffset(24, 16),
		ZIndex = 32,
	})

	local closeButton = UiKit.button(panel, {
		Text = "✕",
		Size = UDim2.fromOffset(38, 38),
		Position = UDim2.new(1, -20, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		Color = Theme.colors.panelSoft,
		Font = Theme.fonts.black,
		OnClick = function()
			close()
		end,
		ZIndex = 33,
	})
	closeButton.Name = "CloseButton"

	timerText = UiKit.text(panel, {
		Text = "",
		TextSize = 12,
		Font = Theme.fonts.medium,
		TextColor3 = Theme.colors.dim,
		Size = UDim2.new(0, 280, 0, 16),
		Position = UDim2.fromOffset(24, 48),
		ZIndex = 32,
	})

	local _, fill = UiKit.bar(panel, {
		Size = UDim2.new(0, 280, 0, 5),
		Position = UDim2.fromOffset(24, 68),
		FillColor = Theme.colors.accent,
	})
	timerBar = fill

	cardsHolder = UiKit.create("Frame", {
		Name = "Cards",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -48, 1, -146),
		Position = UDim2.fromOffset(24, 84),
		ZIndex = 32,
	}, panel)

	local footer = UiKit.create("Frame", {
		Name = "Footer",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -48, 0, 42),
		Position = UDim2.new(0, 24, 1, -52),
		ZIndex = 33,
	}, panel)

	UiKit.text(footer, {
		Text = "Astuce : les œufs rares rapportent beaucoup. Vole ceux des autres !",
		TextSize = 13,
		TextColor3 = Theme.colors.dim,
		Size = UDim2.new(1, -230, 1, 0),
		ZIndex = 34,
	})

	UiKit.button(footer, {
		Name = "RerollButton",
		Text = "Relancer · $" .. Util.formatNumber(250),
		Size = UDim2.fromOffset(200, 42),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		Color = Theme.colors.panelSoft,
		OnClick = function()
			if callbacks.onReroll then
				callbacks.onReroll()
			end
		end,
		ZIndex = 34,
	})

	scrim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			close()
		end
	end)

	ShopPanel.close = close
end

function ShopPanel.update(state: any)
	currentState = state
	if isOpen then
		render(state)
	end
end

--- Met à jour le timer (appelé chaque frame par Main).
function ShopPanel.tick(delta: number)
	if not isOpen or not currentState then
		return
	end
	local remaining = math.max(0, (currentState.shopRefresh or 0) - delta)
	currentState.shopRefresh = remaining
	timerText.Text = string.format("Nouveaux œufs dans %s", Util.formatClock(remaining))
	timerBar.Size = UDim2.fromScale(math.clamp(remaining / 15, 0, 1), 1)
end

function ShopPanel.show(state: any)
	ShopPanel.update(state)
	open()
end

function ShopPanel.isOpen(): boolean
	return isOpen
end

function ShopPanel.toggle(state: any)
	if isOpen then
		close()
	else
		ShopPanel.show(state)
	end
end

return ShopPanel
