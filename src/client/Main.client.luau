--!nonstrict
--[[
	Main (client)
	-------------
	Assemble l'interface, branche les remotes et gère les entrées clavier.
	Aucune décision de gameplay ici : on affiche l'état envoyé par le serveur
	et on envoie des intentions ("Buy", "Merge", "Drop", ...).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UiKit = require(script.Parent.UiKit)
local Hud = require(script.Parent.Hud)
local ShopPanel = require(script.Parent.ShopPanel)
local EggPanel = require(script.Parent.EggPanel)
local Toast = require(script.Parent.Toast)
local CarryUi = require(script.Parent.CarryUi)
local PromptFilter = require(script.Parent.PromptFilter)
local EggAnimator = require(script.Parent.EggAnimator)

-- Interface ---------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StealAnEggUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

local root = UiKit.create("Frame", {
	Name = "Root",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 1,
}, screenGui)

-- État --------------------------------------------------------------------

local state: any = nil
local lockRemaining = 0
local lastLockUpdate = 0
local waitingNoticeShown = false

local actionRemote = Remotes.get(Remotes.Action)
local stateRemote = Remotes.get(Remotes.State)
local cashRemote = Remotes.get(Remotes.StateCash)
local notifyRemote = Remotes.get(Remotes.Notify)
local alertRemote = Remotes.get(Remotes.Alert)
local panelRemote = Remotes.get(Remotes.Panel)
local feedRemote = Remotes.get(Remotes.Feed)
local boardRemote = Remotes.get(Remotes.Board)

local function fire(action: string, payload: any?)
	actionRemote:FireServer(action, payload)
end

local function refreshAll()
	if not state then
		return
	end
	Hud.update(state)
	Hud.setLock(lockRemaining, state.lockCost or 0)
	ShopPanel.update(state)
	EggPanel.update(state)
	CarryUi.update(state)
	CarryUi.setBase(state.basePosition)
	PromptFilter.update(state)
end

local function onState(newState: any)
	if type(newState) ~= "table" then
		return
	end
	state = newState
	lockRemaining = newState.lockRemaining or 0
	refreshAll()

	if not newState.plotIndex and not waitingNoticeShown then
		waitingNoticeShown = true
		Toast.push("Aucune parcelle libre pour l'instant : tu entres dans la file d'attente.", "info", 6)
	elseif newState.plotIndex then
		waitingNoticeShown = false
	end
end

-- Modules -----------------------------------------------------------------

Hud.init(root, {
	onShop = function()
		if state then
			ShopPanel.toggle(state)
		end
	end,
	onLock = function()
		fire("Lock")
	end,
})

ShopPanel.init(root, {
	onBuy = function(index: number)
		fire("Buy", { index = index })
	end,
	onReroll = function()
		fire("Reroll")
	end,
})

EggPanel.init(root, {
	onMerge = function(uid: string)
		fire("Merge", { uid = uid })
	end,
	onSell = function(uid: string)
		fire("Sell", { uid = uid })
	end,
})

CarryUi.init(root, {
	onDrop = function()
		fire("Drop")
	end,
})

Toast.init(root)
PromptFilter.init()
EggAnimator.init()

-- Remotes -----------------------------------------------------------------

stateRemote.OnClientEvent:Connect(onState)

cashRemote.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" or not state then
		return
	end
	state.cash = payload.cash or state.cash
	state.income = payload.income or state.income
	state.bonus = payload.bonus or state.bonus
	refreshAll()
end)

notifyRemote.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	Toast.push(tostring(payload.text or ""), payload.kind, payload.duration)
end)

alertRemote.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	Hud.alert(tostring(payload.text or "Alerte !"))
end)

panelRemote.OnClientEvent:Connect(function(panelName: string, payload: any)
	if panelName == "Shop" then
		if state then
			ShopPanel.show(state)
		end
	elseif panelName == "Egg" and type(payload) == "table" and payload.uid and state then
		EggPanel.show(tostring(payload.uid), state)
	end
end)

feedRemote.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	Toast.feed(tostring(payload.text or ""), payload.kind)
end)

boardRemote.OnClientEvent:Connect(function(entries: any)
	if type(entries) == "table" then
		Hud.setBoard(entries)
	end
end)

-- Entrées ----------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or not state then
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	local key = input.KeyCode
	if key == Enum.KeyCode.B then
		ShopPanel.toggle(state)
	elseif key == Enum.KeyCode.F then
		fire("Lock")
	elseif key == Enum.KeyCode.Q then
		fire("Drop")
	elseif key == Enum.KeyCode.H or key == Enum.KeyCode.Slash then
		Hud.toggleHelp()
	end
end)

-- Boucle ------------------------------------------------------------------

RunService.RenderStepped:Connect(function(delta)
	if lockRemaining > 0 then
		lockRemaining = math.max(0, lockRemaining - delta)
		lastLockUpdate += delta
		if lastLockUpdate >= 0.2 then
			lastLockUpdate = 0
			Hud.setLock(lockRemaining, state and state.lockCost or 0)
		end
	end
	ShopPanel.tick(delta)
end)

player.CharacterAdded:Connect(function()
	task.delay(1, function()
		fire("Ready")
	end)
end)

-- Demande de synchronisation initiale (le serveur peut avoir envoyé l'état
-- avant que l'interface soit prête).
task.delay(0.4, function()
	fire("Ready")
end)

print("[Steal a Egg] client prêt (" .. Config.GameName .. ")")
