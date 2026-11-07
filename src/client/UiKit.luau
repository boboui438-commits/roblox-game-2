--!nonstrict
--[[
	UiKit
	-----
	Petites fabriques d'UI : frames, textes, boutons, barres, images.
	Tout est construit sans asset externe (formes + dégradés + texte).
]]

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(script.Parent.Theme)

local UiKit = {}

function UiKit.create(className: string, props: { [string]: any }, parent: Instance?): Instance
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UiKit.corner(instance: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

function UiKit.stroke(instance: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.colors.stroke
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

function UiKit.gradient(instance: Instance, colors: { Color3 }, rotation: number?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colors)
	gradient.Rotation = rotation or 90
	gradient.Parent = instance
	return gradient
end

function UiKit.tween(instance: Instance, props: { [string]: any }, duration: number?, style: Enum.EasingStyle?): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

--- Frame "panneau" avec fond, coins arrondis et contour.
function UiKit.panel(parent: Instance, props: { [string]: any }, radius: number?): Frame
	local frame = UiKit.create("Frame", {
		BackgroundColor3 = props.BackgroundColor3 or Theme.colors.panel,
		BackgroundTransparency = props.BackgroundTransparency or 0,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(200, 100),
		Position = props.Position or UDim2.fromOffset(0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Visible = props.Visible ~= false,
		ClipsDescendants = props.ClipsDescendants ~= false,
		ZIndex = props.ZIndex or 1,
		Name = props.Name or "Panel",
	}, parent)
	UiKit.corner(frame, radius or 14)
	if props.Stroke ~= false then
		UiKit.stroke(frame, props.StrokeColor, props.StrokeThickness or 1, props.StrokeTransparency or 0.25)
	end
	if props.Gradient then
		UiKit.gradient(frame, props.Gradient, props.GradientRotation)
	end
	return frame
end

function UiKit.text(parent: Instance, props: { [string]: any }): TextLabel
	local label = UiKit.create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = props.Font or Theme.fonts.medium,
		Text = props.Text or "",
		TextColor3 = props.TextColor3 or Theme.colors.text,
		TextSize = props.TextSize or 16,
		TextScaled = props.TextScaled == true,
		TextWrapped = props.TextWrapped ~= false,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromOffset(0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = props.ZIndex or 2,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
	if props.Stroke then
		label.TextStrokeTransparency = props.StrokeTransparency or 0.4
		label.TextStrokeColor3 = props.StrokeColor3 or Color3.fromRGB(0, 0, 0)
	end
	return label
end

--- Bouton complet (fond, contour, label, animations hover/press).
function UiKit.button(parent: Instance, props: { [string]: any }): TextButton
	local color = props.Color or Theme.colors.panelSoft
	local button = UiKit.create("TextButton", {
		BackgroundColor3 = color,
		BackgroundTransparency = props.Transparency or 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Size = props.Size or UDim2.fromOffset(160, 44),
		Position = props.Position or UDim2.fromOffset(0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Visible = props.Visible ~= false,
		ZIndex = props.ZIndex or 3,
	}, parent)
	UiKit.corner(button, props.Radius or 10)
	local stroke = UiKit.stroke(button, props.StrokeColor or Theme.colors.stroke, 1, 0.35)

	local label = UiKit.text(button, {
		Text = props.Text or "Bouton",
		Font = props.Font or Theme.fonts.bold,
		TextColor3 = props.TextColor3 or Theme.colors.text,
		TextSize = props.TextSize or 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Size = UDim2.fromScale(1, 1),
	})
	if props.Padding then
		label.Size = UDim2.new(1, -(props.Padding * 2), 1, 0)
		label.Position = UDim2.fromOffset(props.Padding, 0)
	end

	if props.Gradient then
		UiKit.gradient(button, props.Gradient, props.GradientRotation)
	end

	button.MouseEnter:Connect(function()
		if button.Active then
			UiKit.tween(button, { BackgroundTransparency = math.max(0, button.BackgroundTransparency - 0.1) }, 0.12)
			stroke.Transparency = 0.1
		end
	end)
	button.MouseLeave:Connect(function()
		UiKit.tween(button, { BackgroundTransparency = props.Transparency or 0 }, 0.12)
		stroke.Transparency = 0.35
	end)
	button.MouseButton1Down:Connect(function()
		UiKit.tween(button, { Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset, button.Size.Y.Scale, button.Size.Y.Offset) }, 0.05)
		label.TextTransparency = 0.25
	end)
	button.MouseButton1Up:Connect(function()
		label.TextTransparency = 0
	end)
	button.MouseLeave:Connect(function()
		label.TextTransparency = 0
	end)

	if props.OnClick then
		button.Activated:Connect(props.OnClick)
	end

	button:SetAttribute("BaseColor", color)
	return button
end

--- Barre de progression simple.
function UiKit.bar(parent: Instance, props: { [string]: any }): (Frame, Frame)
	local track = UiKit.create("Frame", {
		BackgroundColor3 = props.TrackColor or Theme.colors.panelHard,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.new(1, 0, 0, 6),
		Position = props.Position or UDim2.fromOffset(0, 0),
		ZIndex = props.ZIndex or 2,
	}, parent)
	UiKit.corner(track, 999)

	local fill = UiKit.create("Frame", {
		BackgroundColor3 = props.FillColor or Theme.colors.accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(props.Value or 1, 1),
		ZIndex = (props.ZIndex or 2) + 1,
	}, track)
	UiKit.corner(fill, 999)
	if props.Gradient then
		UiKit.gradient(fill, props.Gradient, 0)
	end
	return track, fill
end

--- Petit badge coloré.
function UiKit.badge(parent: Instance, props: { [string]: any }): Frame
	local badge = UiKit.create("Frame", {
		BackgroundColor3 = props.Color or Theme.colors.accent,
		BackgroundTransparency = props.Transparency or 0.85,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(90, 22),
		Position = props.Position or UDim2.fromOffset(0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = props.ZIndex or 2,
	}, parent)
	UiKit.corner(badge, 999)
	UiKit.text(badge, {
		Text = props.Text or "",
		TextColor3 = props.TextColor3 or Theme.colors.text,
		Font = Theme.fonts.bold,
		TextSize = props.TextSize or 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = (props.ZIndex or 2) + 1,
	})
	return badge
end

--- Représentation stylisée d'un œuf (ovale + anneau de rareté).
function UiKit.eggIcon(parent: Instance, eggId: string, size: number): Frame
	local rarityColor = Theme.rarityColor(eggId)
	local holder = UiKit.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		ZIndex = 3,
	}, parent)

	local glow = UiKit.create("Frame", {
		BackgroundColor3 = rarityColor,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.92, 0.92),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 2,
	}, holder)
	UiKit.corner(glow, 999)

	local egg = UiKit.create("Frame", {
		BackgroundColor3 = Theme.rarityColor(eggId),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.48, 0.62),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
	}, holder)
	UiKit.corner(egg, 999)
	UiKit.stroke(egg, Color3.fromRGB(255, 255, 255), 1, 0.5)
	UiKit.gradient(egg, {
		Color3.fromRGB(255, 255, 255),
		Theme.rarityColor(eggId),
		Color3.fromRGB(0, 0, 0),
	}, 90)

	return holder
end

return UiKit
