--!nonstrict
--[[
	CarryUi
	-------
	Bandeau "tu portes un œuf", flèche directionnelle vers sa base et bouton
	pour lâcher l'œuf.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local EggCatalog = require(Shared:WaitForChild("EggCatalog"))

local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)

local CarryUi = {}

local callbacks = {}
local banner: Frame
local bannerTitle: TextLabel
local bannerSubtitle: TextLabel
local bannerBadge: Frame
local bannerBadgeText: TextLabel
local dropButton: TextButton
local arrow: Frame
local arrowLabel: TextLabel

local carried: any = nil
local basePosition: Vector3? = nil
local blinking = 0
local subtitlePrefix = ""

local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function setVisible(visible: boolean)
	banner.Visible = visible
	dropButton.Visible = visible
	arrow.Visible = visible
end

function CarryUi.init(parent: Instance, newCallbacks: any)
	callbacks = newCallbacks or {}

	banner = UiKit.panel(parent, {
		Name = "CarryBanner",
		Size = UDim2.fromOffset(520, 76),
		Position = UDim2.new(0.5, 0, 0, 152),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(32, 20, 46),
		StrokeColor = Color3.fromRGB(190, 140, 255),
		StrokeThickness = 2,
		Visible = false,
		ZIndex = 12,
	})

	bannerBadge = UiKit.badge(banner, {
		Text = "TU PORTES",
		Color = Color3.fromRGB(190, 140, 255),
		Transparency = 0.82,
		TextColor3 = Color3.fromRGB(220, 190, 255),
		Size = UDim2.fromOffset(96, 22),
		Position = UDim2.fromOffset(16, 14),
		TextSize = 11,
		ZIndex = 13,
	})

	bannerTitle = UiKit.text(banner, {
		Text = "",
		TextSize = 18,
		Font = Theme.fonts.black,
		TextColor3 = Color3.fromRGB(240, 225, 255),
		Size = UDim2.new(1, -140, 0, 26),
		Position = UDim2.fromOffset(16, 38),
		ZIndex = 13,
	})

	bannerSubtitle = UiKit.text(banner, {
		Text = "Ramène-le vite dans TA base !",
		TextSize = 12,
		Font = Theme.fonts.medium,
		TextColor3 = Color3.fromRGB(190, 172, 220),
		Size = UDim2.new(1, -140, 0, 16),
		Position = UDim2.fromOffset(16, 62),
		ZIndex = 13,
	})

	dropButton = UiKit.button(parent, {
		Name = "DropButton",
		Text = "Lâcher (Q)",
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.new(0.5, 0, 1, -84),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = Color3.fromRGB(64, 24, 36),
		TextColor3 = Color3.fromRGB(255, 190, 200),
		Visible = false,
		ZIndex = 12,
		OnClick = function()
			if callbacks.onDrop then
				callbacks.onDrop()
			end
		end,
	})

	arrow = UiKit.create("Frame", {
		Name = "BaseArrow",
		BackgroundColor3 = Color3.fromRGB(190, 140, 255),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(22, 22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 11,
	}, parent)
	UiKit.corner(arrow, 5)
	UiKit.stroke(arrow, Color3.fromRGB(255, 255, 255), 2, 0.35)

	arrowLabel = UiKit.text(parent, {
		Name = "BaseDistance",
		Text = "",
		TextSize = 12,
		Font = Theme.fonts.bold,
		TextColor3 = Color3.fromRGB(225, 205, 255),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(120, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 11,
	})

	RunService.RenderStepped:Connect(function(delta)
		if not carried or not basePosition then
			return
		end
		local camera = workspace.CurrentCamera
		local localPlayer = Players.LocalPlayer
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not camera or not root then
			return
		end

		local distance = (root.Position - basePosition).Magnitude
		bannerSubtitle.Text = string.format("%s%d studs de ta base", subtitlePrefix, math.floor(distance))

		local target = basePosition + Vector3.new(0, 4, 0)
		local point, onScreen = camera:WorldToViewportPoint(target)
		local screen = viewport()
		local center = Vector2.new(screen.X / 2, screen.Y / 2)
		local direction = Vector2.new(point.X - center.X, point.Y - center.Y)

		if point.Z < 0 then
			direction = Vector2.new(-direction.X, -direction.Y)
			if direction.Magnitude < 1 then
				direction = Vector2.new(0, 1)
			end
		end
		if direction.Magnitude < 1 then
			direction = Vector2.new(1, 0)
		end

		local radius = math.min(screen.X, screen.Y) * 0.34
		local position = center + direction.Unit * radius
		position = Vector2.new(
			math.clamp(position.X, 60, screen.X - 60),
			math.clamp(position.Y, 120, screen.Y - 110)
		)

		arrow.Position = UDim2.fromOffset(position.X, position.Y)
		arrow.Rotation = math.deg(math.atan2(direction.Y, direction.X))
		arrowLabel.Position = UDim2.fromOffset(position.X, position.Y - 26)
		arrowLabel.Text = string.format("%d m", math.floor(distance / 3))

		local showArrow = distance > 18
		arrow.Visible = showArrow
		arrowLabel.Visible = showArrow

		-- pulsation discrète
		blinking = (blinking + delta * 2.4) % (math.pi * 2)
		arrow.BackgroundTransparency = 0.15 + math.sin(blinking) * 0.12
	end)
end

function CarryUi.setBase(position: Vector3?)
	basePosition = position
end

function CarryUi.update(state: any)
	carried = state and state.carried or nil
	if not carried then
		setVisible(false)
		return
	end

	local def = EggCatalog.get(carried.eggId)
	setVisible(true)
	bannerTitle.Text = def and def.name or "Œuf inconnu"

	if carried.ownerName then
		subtitlePrefix = ("Volé à %s · "):format(Util.trim(carried.ownerName, 16))
	else
		subtitlePrefix = "Ramène-le à ta base · "
	end
	bannerSubtitle.Text = subtitlePrefix .. "cours !"

	local color = Theme.rarityColor(carried.eggId)
	bannerBadge.BackgroundColor3 = color
	local badgeText = bannerBadge:FindFirstChildWhichIsA("TextLabel")
	if badgeText then
		badgeText.TextColor3 = color
	end
	UiKit.stroke(banner, color)
end

function CarryUi.isCarrying(): boolean
	return carried ~= nil
end

return CarryUi
