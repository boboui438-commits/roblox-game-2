--!nonstrict
--[[
	Hud
	---
	Interface permanente : argent, revenus, statistiques, classement,
	alertes et aide.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))

local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)

local Hud = {}

local callbacks = {}
local elements = {}
local state: any = nil
local displayCash = 0
local targetCash = 0
local boardEntries = {}

local function formatMoney(value: number): string
	return "$" .. Util.formatNumber(value)
end

-- Panneaux ----------------------------------------------------------------

local function buildCashCard(parent: Instance)
	local card = UiKit.panel(parent, {
		Name = "CashCard",
		Size = UDim2.fromOffset(318, 128),
		Position = UDim2.fromOffset(18, 16),
		Gradient = { Theme.colors.panel, Theme.colors.panelHard },
		GradientRotation = 90,
	})
	elements.cashCard = card

	local accent = UiKit.create("Frame", {
		BackgroundColor3 = Theme.colors.accent,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 4, 1, -24),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 2,
	}, card)
	UiKit.corner(accent, 4)

	UiKit.text(card, {
		Text = "ARGENT",
		TextSize = 11,
		Font = Theme.fonts.bold,
		TextColor3 = Theme.colors.dim,
		Size = UDim2.fromOffset(120, 14),
		Position = UDim2.fromOffset(26, 14),
		ZIndex = 3,
	})

	elements.cashLabel = UiKit.text(card, {
		Text = "$0",
		TextSize = 32,
		Font = Theme.fonts.black,
		TextColor3 = Theme.colors.gold,
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.fromOffset(24, 28),
		ZIndex = 3,
	})

	elements.incomeBadge = UiKit.badge(card, {
		Text = "+0/s",
		Color = Theme.colors.success,
		Transparency = 0.82,
		TextColor3 = Theme.colors.success,
		Size = UDim2.fromOffset(104, 26),
		Position = UDim2.fromOffset(26, 74),
		TextSize = 13,
	})
	elements.incomeText = elements.incomeBadge:FindFirstChildOfClass("TextLabel")

	elements.bonusBadge = UiKit.badge(card, {
		Text = "Collection +0%",
		Color = Theme.colors.info,
		Transparency = 0.86,
		TextColor3 = Theme.colors.info,
		Size = UDim2.fromOffset(150, 26),
		Position = UDim2.fromOffset(138, 74),
		TextSize = 12,
	})
	elements.bonusText = elements.bonusBadge:FindFirstChildOfClass("TextLabel")

	elements.eggCounter = UiKit.text(card, {
		Text = "0 œufs · 0 vol",
		TextSize = 12,
		Font = Theme.fonts.medium,
		TextColor3 = Theme.colors.dim,
		Size = UDim2.new(1, -40, 0, 16),
		Position = UDim2.fromOffset(26, 104),
		ZIndex = 3,
	})
end

local function buildButtons(parent: Instance)
	local holder = UiKit.create("Frame", {
		Name = "MainButtons",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(360, 52),
		Position = UDim2.new(0.5, 0, 1, -22),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 10,
	}, parent)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = holder

	UiKit.button(holder, {
		Text = "Boutique  (B)",
		Size = UDim2.fromOffset(160, 46),
		Color = Theme.colors.accentDark,
		TextColor3 = Color3.fromRGB(220, 255, 244),
		Gradient = { Theme.colors.accent, Theme.colors.accentDark },
		GradientRotation = 90,
		OnClick = function()
			if callbacks.onShop then
				callbacks.onShop()
			end
		end,
	})

	local lockButton = UiKit.button(holder, {
		Text = "Protéger  (F)",
		Size = UDim2.fromOffset(160, 46),
		Color = Theme.colors.panelSoft,
		OnClick = function()
			if callbacks.onLock then
				callbacks.onLock()
			end
		end,
	})
	elements.lockButton = lockButton
	elements.lockLabel = lockButton:FindFirstChildWhichIsA("TextLabel")
end

local function buildBoard(parent: Instance)
	local panel = UiKit.panel(parent, {
		Name = "Leaderboard",
		Size = UDim2.fromOffset(268, 186),
		Position = UDim2.new(1, -18, 0, 16),
		Gradient = { Theme.colors.panel, Theme.colors.panelHard },
		GradientRotation = 90,
	})

	UiKit.text(panel, {
		Text = "CLASSEMENT",
		TextSize = 12,
		Font = Theme.fonts.bold,
		TextColor3 = Theme.colors.dim,
		Size = UDim2.new(1, -28, 0, 16),
		Position = UDim2.fromOffset(16, 12),
		ZIndex = 3,
	})

	local function rowFor(parent: Instance, index: number)
		local frame = UiKit.create("Frame", {
			BackgroundColor3 = Theme.colors.panelSoft,
			BackgroundTransparency = index == 1 and 0.2 or 0.65,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -24, 0, 24),
			Position = UDim2.fromOffset(12, 34 + (index - 1) * 28),
			ZIndex = 3,
		}, parent)
		UiKit.corner(frame, 6)

		UiKit.text(frame, {
			Text = tostring(index),
			TextSize = 12,
			Font = Theme.fonts.bold,
			TextColor3 = index == 1 and Theme.colors.gold or Theme.colors.dim,
			Size = UDim2.fromOffset(18, 24),
			Position = UDim2.fromOffset(8, 0),
			ZIndex = 4,
		})

		local name = UiKit.text(frame, {
			Text = "—",
			TextSize = 12,
			Font = Theme.fonts.medium,
			TextColor3 = Theme.colors.text,
			Size = UDim2.new(1, -110, 1, 0),
			Position = UDim2.fromOffset(30, 0),
			ZIndex = 4,
		})

		local value = UiKit.text(frame, {
			Text = "",
			TextSize = 12,
			Font = Theme.fonts.bold,
			TextColor3 = Theme.colors.gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(78, 24),
			Position = UDim2.new(1, -86, 0, 0),
			ZIndex = 4,
		})

		return { frame = frame, name = name, value = value }
	end

	elements.boardRows = {}
	for index = 1, 5 do
		elements.boardRows[index] = rowFor(panel, index)
	end
end

local function buildAlert(parent: Instance)
	local overlay = UiKit.create("Frame", {
		Name = "AlertOverlay",
		BackgroundColor3 = Color3.fromRGB(255, 40, 70),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 40,
		Visible = false,
	}, parent)

	local banner = UiKit.panel(parent, {
		Name = "AlertBanner",
		Size = UDim2.fromOffset(560, 64),
		Position = UDim2.new(0.5, 0, 0, 172),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(46, 16, 24),
		StrokeColor = Theme.colors.danger,
		StrokeThickness = 2,
		Visible = false,
		ZIndex = 41,
	})

	local title = UiKit.text(banner, {
		Text = "ALERTE",
		TextSize = 12,
		Font = Theme.fonts.bold,
		TextColor3 = Theme.colors.danger,
		Size = UDim2.new(1, -32, 0, 16),
		Position = UDim2.fromOffset(16, 8),
		ZIndex = 42,
	})

	local message = UiKit.text(banner, {
		Text = "",
		TextSize = 16,
		Font = Theme.fonts.bold,
		TextColor3 = Color3.fromRGB(255, 222, 226),
		Size = UDim2.new(1, -32, 0, 30),
		Position = UDim2.fromOffset(16, 24),
		ZIndex = 42,
	})

	elements.alertOverlay = overlay
	elements.alertBanner = banner
	elements.alertMessage = message
	elements.alertTitle = title
end

local function buildHelp(parent: Instance)
	local scrim = UiKit.create("Frame", {
		Name = "HelpScrim",
		BackgroundColor3 = Theme.colors.scrim,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,
		Visible = false,
	}, parent)
	scrim.Active = true

	local panel = UiKit.panel(parent, {
		Name = "HelpPanel",
		Size = UDim2.fromOffset(540, 380),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 31,
		Visible = false,
	})
	UiKit.stroke(panel, Theme.colors.accent, 1, 0.4)

	UiKit.text(panel, {
		Text = "COMMENT JOUER",
		TextSize = 18,
		Font = Theme.fonts.black,
		TextColor3 = Theme.colors.accent,
		Size = UDim2.new(1, -40, 0, 24),
		Position = UDim2.fromOffset(22, 20),
		ZIndex = 32,
	})

	local helpText = table.concat({
		"1. Va au kiosque au centre (E) et achète des œufs.",
		"2. Chaque œuf posé sur ta base rapporte de l'argent chaque seconde.",
		"3. Approche-toi d'un œuf ennemi et maintiens E pour le voler.",
		"4. Ramène-le dans TA base et appuie sur E sur un socle libre.",
		"5. Si tu meurs ou lâches (Q) l'œuf, il tombe au sol pour tout le monde.",
		"6. Appuie sur F pour protéger ta base pendant 90 secondes.",
		"7. Fusionne deux œufs identiques pour multiplier leurs revenus.",
		"8. Deux joueurs ne peuvent pas voler le même œuf : sois le plus rapide !",
	}, "\n")

	UiKit.text(panel, {
		Text = helpText,
		TextSize = 14,
		Font = Theme.fonts.medium,
		TextColor3 = Theme.colors.text,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -44, 1, -110),
		Position = UDim2.fromOffset(22, 54),
		ZIndex = 32,
	})

	local close = UiKit.button(panel, {
		Text = "Fermer",
		Size = UDim2.fromOffset(120, 36),
		Position = UDim2.new(1, -22, 1, -20),
		AnchorPoint = Vector2.new(1, 1),
		Color = Theme.colors.panelSoft,
		ZIndex = 33,
	})

	local function setVisible(visible: boolean)
		scrim.Visible = visible
		panel.Visible = visible
	end

	close.Activated:Connect(function()
		setVisible(false)
	end)
	scrim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			setVisible(false)
		end
	end)

	elements.helpScrim = scrim
	elements.helpPanel = panel
	elements.helpOpen = false
	elements.setHelpVisible = setVisible
end

local function buildSplash(parent: Instance)
	local splash = UiKit.create("Frame", {
		Name = "Splash",
		BackgroundColor3 = Theme.colors.bg,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
	}, parent)

	local title = UiKit.text(splash, {
		Text = "STEAL A EGG",
		TextScaled = true,
		Font = Theme.fonts.black,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(640, 90),
		Position = UDim2.fromScale(0.5, 0.44),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 61,
	})
	UiKit.gradient(title, { Theme.colors.gold, Theme.colors.accent }, 0)

	local subtitle = UiKit.text(splash, {
		Text = "Vole. Défends. Collectionne.",
		TextSize = 18,
		Font = Theme.fonts.medium,
		TextColor3 = Theme.colors.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(640, 30),
		Position = UDim2.fromScale(0.5, 0.53),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 61,
	})

	task.delay(1.6, function()
		UiKit.tween(splash, { BackgroundTransparency = 1 }, 0.6)
		UiKit.tween(title, { TextTransparency = 1 }, 0.5)
		UiKit.tween(subtitle, { TextTransparency = 1 }, 0.5)
		task.delay(0.8, function()
			splash:Destroy()
		end)
	end)
end

-- API ---------------------------------------------------------------------

function Hud.init(parent: Instance, newCallbacks: any)
	callbacks = newCallbacks or {}
	buildCashCard(parent)
	buildButtons(parent)
	buildBoard(parent)
	buildAlert(parent)
	buildHelp(parent)
	buildSplash(parent)

	RunService.RenderStepped:Connect(function(delta)
		if displayCash ~= targetCash then
			local difference = targetCash - displayCash
			local step = math.max(math.abs(difference) * math.min(delta * 8, 1), delta * 8)
			if math.abs(difference) <= step then
				displayCash = targetCash
			else
				displayCash += difference > 0 and step or -step
			end
			elements.cashLabel.Text = formatMoney(displayCash)
		end
	end)
end

function Hud.update(newState: any)
	state = newState
	targetCash = newState.cash or 0
	elements.cashLabel.Text = formatMoney(displayCash ~= 0 and displayCash or targetCash)

	elements.incomeText.Text = "+" .. Util.formatNumber(newState.income or 0) .. "/s"
	local bonusPercent = math.floor(((newState.bonus or 1) - 1) * 100 + 0.5)
	elements.bonusText.Text = "Collection +" .. bonusPercent .. "%"

	local eggCount = 0
	if newState.eggs then
		eggCount = #newState.eggs
	end
	elements.eggCounter.Text = string.format(
		"%d/%d œufs · %d vols · Collection %d/%d",
		eggCount,
		newState.slots or 0,
		newState.stats and newState.stats.stolen or 0,
		newState.collect and newState.collect.count or 0,
		newState.collect and newState.collect.total or 0
	)
end

--- Affiche l'état de protection de la base sur le bouton "Protéger".
function Hud.setLock(remaining: number, cost: number)
	if not elements.lockLabel then
		return
	end
	if remaining > 0 then
		elements.lockLabel.Text = string.format("Protégée · %ds", math.ceil(remaining))
		elements.lockLabel.TextColor3 = Theme.colors.accent
	else
		elements.lockLabel.Text = string.format("Protéger · $%s  (F)", Util.formatNumber(cost))
		elements.lockLabel.TextColor3 = Theme.colors.text
	end
end

function Hud.setBoard(entries: { any })
	if not elements.boardRows then
		return
	end
	for index, row in ipairs(elements.boardRows) do
		local entry = entries and entries[index]
		if entry then
			row.frame.Visible = true
			row.name.Text = Util.trim(entry.name or "?", 16)
			row.value.Text = formatMoney(entry.cash or 0)
			row.frame.BackgroundTransparency = index == 1 and 0.25 or 0.7
		else
			row.frame.Visible = false
		end
	end
end

function Hud.alert(text: string)
	if not elements.alertBanner then
		return
	end
	elements.alertMessage.Text = Util.trim(text, 90)
	elements.alertBanner.Visible = true
	elements.alertOverlay.Visible = true
	elements.alertOverlay.BackgroundTransparency = 0.86
	elements.alertBanner.Position = UDim2.new(0.5, 0, 0, 160)

	UiKit.tween(elements.alertOverlay, { BackgroundTransparency = 1 }, 0.9)
	UiKit.tween(elements.alertBanner, { Position = UDim2.new(0.5, 0, 0, 172) }, 0.25)

	task.delay(2.4, function()
		UiKit.tween(elements.alertBanner, {
			Position = UDim2.new(0.5, 0, 0, 140),
			BackgroundTransparency = 1,
		}, 0.35)
		task.delay(0.4, function()
			elements.alertBanner.Visible = false
			elements.alertBanner.BackgroundTransparency = 0
			elements.alertOverlay.Visible = false
		end)
	end)
end

function Hud.toggleHelp()
	if not elements.setHelpVisible then
		return
	end
	elements.helpOpen = not elements.helpOpen
	elements.setHelpVisible(elements.helpOpen)
end

function Hud.isModalOpen(): boolean
	return elements.helpOpen == true
end

return Hud
