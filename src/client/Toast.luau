--!nonstrict
--[[
	Toast
	-----
	Notifications empilées en haut à droite + fil d'actualité.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)

local Toast = {}

local container: Frame
local feedContainer: Frame
local active: { Frame } = {}
local feedEntries: { Frame } = {}
local MAX_TOASTS = 4
local MAX_FEED = 3

function Toast.init(parent: Instance)
	container = UiKit.create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 330, 0, 420),
		Position = UDim2.new(1, -18, 0, 130),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 20,
	}, parent)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Parent = container

	feedContainer = UiKit.create("Frame", {
		Name = "Feed",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 400, 0, 90),
		Position = UDim2.new(0, 18, 1, -160),
		AnchorPoint = Vector2.new(0, 1),
		ZIndex = 18,
	}, parent)

	local feedLayout = Instance.new("UIListLayout")
	feedLayout.Padding = UDim.new(0, 4)
	feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
	feedLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	feedLayout.Parent = feedContainer
end

local function removeToast(toast: Frame)
	for index, item in ipairs(active) do
		if item == toast then
			table.remove(active, index)
			break
		end
	end
	if toast.Parent then
		toast:Destroy()
	end
end

function Toast.push(text: string, kind: string?, duration: number?)
	if not container then
		return
	end
	duration = duration or 3.5
	local color = Theme.kindColor(kind or "info")

	while #active >= MAX_TOASTS do
		removeToast(active[1])
	end

	local toast = UiKit.create("Frame", {
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.new(1, 40, 0, 0),
		ZIndex = 21,
	}, container)
	UiKit.corner(toast, 10)
	UiKit.stroke(toast, Theme.colors.stroke, 1, 0.5)

	local accent = UiKit.create("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 4, 1, -14),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 22,
	}, toast)
	UiKit.corner(accent, 4)

	UiKit.text(toast, {
		Text = text,
		TextSize = 14,
		Font = Theme.fonts.medium,
		TextColor3 = Theme.colors.text,
		TextWrapped = true,
		Size = UDim2.new(1, -30, 1, -8),
		Position = UDim2.fromOffset(20, 4),
		ZIndex = 22,
	})

	table.insert(active, toast)

	local tweenIn = TweenService:Create(
		toast,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, 0, 0, 0) }
	)
	tweenIn:Play()

	task.delay(duration, function()
		if not toast.Parent then
			return
		end
		local tweenOut = TweenService:Create(
			toast,
			TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(1, 60, 0, 0), BackgroundTransparency = 1 }
		)
		tweenOut:Play()
		tweenOut.Completed:Once(function()
			removeToast(toast)
		end)
	end)
end

--- Ligne du fil d'actualité global (bas gauche).
function Toast.feed(text: string, kind: string?)
	if not feedContainer then
		return
	end

	while #feedEntries >= MAX_FEED do
		local oldest = table.remove(feedEntries, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end

	local color = Theme.kindColor(kind or "info")
	local frame = UiKit.create("Frame", {
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 18,
	}, feedContainer)
	UiKit.corner(frame, 6)

	local dot = UiKit.create("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.new(0, 10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 19,
	}, frame)
	UiKit.corner(dot, 999)

	UiKit.text(frame, {
		Text = text,
		TextSize = 12,
		Font = Theme.fonts.medium,
		TextColor3 = Theme.colors.dim,
		Size = UDim2.new(1, -28, 1, 0),
		Position = UDim2.fromOffset(22, 0),
		ZIndex = 19,
	})

	table.insert(feedEntries, frame)
	frame.BackgroundTransparency = 1
	UiKit.tween(frame, { BackgroundTransparency = 0.35 }, 0.2)

	task.delay(7, function()
		for index, entry in ipairs(feedEntries) do
			if entry == frame then
				table.remove(feedEntries, index)
				break
			end
		end
		if frame.Parent then
			UiKit.tween(frame, { BackgroundTransparency = 1 }, 0.3)
			task.delay(0.35, function()
				frame:Destroy()
			end)
		end
	end)
end

function Toast.info(text: string)
	Toast.push(text, "info")
end

return Toast
