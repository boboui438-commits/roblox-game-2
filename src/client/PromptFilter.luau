--!nonstrict
--[[
	PromptFilter
	------------
	Les ProximityPrompt vivent sur le serveur (pour que le serveur reçoive
	les déclenchements), mais leur visibilité est filtrée localement :
	  - "Voler"   : œufs des autres joueurs
	  - "Gérer"   : ses propres œufs
	  - "Sécuriser": ses propres socles, uniquement en portant un œuf
	  - "Débloquer": le prochain socle verrouillé de sa base

	Le serveur revalide de toute façon chaque action.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local PromptFilter = {}

local localPlayer = Players.LocalPlayer
local state: any = nil
local lastRefresh = 0

local function setEnabled(prompt: Instance?, enabled: boolean)
	if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled ~= enabled then
		prompt.Enabled = enabled
	end
end

local function applyEgg(model: Instance)
	if not model:IsA("Model") or not model.PrimaryPart then
		return
	end
	local ownerId = model:GetAttribute("OwnerUserId")
	local free = model:GetAttribute("Free") == true
	local carried = model:GetAttribute("Carried") == true
	local busy = state and state.carried ~= nil

	local stealPrompt = model.PrimaryPart:FindFirstChild("StealPrompt")
	local managePrompt = model.PrimaryPart:FindFirstChild("ManagePrompt")

	if free or carried then
		setEnabled(stealPrompt, false)
		setEnabled(managePrompt, false)
		return
	end

	local isMine = ownerId == localPlayer.UserId
	if isMine then
		setEnabled(stealPrompt, false)
		setEnabled(managePrompt, not busy)
	else
		setEnabled(stealPrompt, not busy)
		setEnabled(managePrompt, false)
	end
end

local function slotHasEgg(slotIndex: number): boolean
	if not state or not state.eggs then
		return false
	end
	for _, egg in ipairs(state.eggs) do
		if egg.slot == slotIndex then
			return true
		end
	end
	return false
end

local function applyPedestal(plotModel: Instance)
	local plotIndex = plotModel:GetAttribute("PlotIndex")
	if not plotIndex or not state then
		return
	end
	local isMyPlot = state.plotIndex == plotIndex
	local carrying = state.carried ~= nil
	local maxSlots = state.slots or 0

	for _, child in ipairs(plotModel:GetChildren()) do
		if child:IsA("BasePart") then
			local securePrompt = child:FindFirstChild("SecurePrompt")
			local slotIndex = child:GetAttribute("SlotIndex")
			if securePrompt and child.Name:match("^Pedestal") and slotIndex then
				local allowed = isMyPlot
					and carrying
					and slotIndex <= maxSlots
					and not slotHasEgg(slotIndex)
				setEnabled(securePrompt, allowed)
			end

			local upgradePrompt = child:FindFirstChild("UpgradePrompt")
			if upgradePrompt and slotIndex then
				local isNextSlot = isMyPlot and slotIndex == maxSlots + 1
				setEnabled(upgradePrompt, isNextSlot and not carrying)
			end
		end
	end
end

local function apply()
	if not state then
		return
	end

	for _, model in ipairs(CollectionService:GetTagged("EggVisual")) do
		applyEgg(model)
	end

	local map = Workspace:FindFirstChild("StealAnEggMap")
	if map then
		for _, child in ipairs(map:GetChildren()) do
			if child:IsA("Model") and child.Name:match("^Plot_") then
				applyPedestal(child)
			end
		end
	end
end

function PromptFilter.update(newState: any)
	state = newState
	apply()
end

function PromptFilter.init()
	CollectionService:GetInstanceAddedSignal("EggVisual"):Connect(function()
		task.defer(apply)
	end)

	-- Filet de sécurité : l'activation des prompts est un état local, on la
	-- réapplique régulièrement pour résister aux réplications du serveur.
	task.spawn(function()
		while true do
			task.wait(0.7)
			apply()
		end
	end)
end

return PromptFilter
