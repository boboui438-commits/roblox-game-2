--!nonstrict
--[[
	EggService
    ----------
	Cœur du jeu côté serveur :
	  - création / destruction des modèles d'œufs (socles)
	  - revenus passifs
	  - fusion et revente
	  - déblocage des socles
	  - prompts des œufs et des socles
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EggCatalog = require(Shared:WaitForChild("EggCatalog"))
local Util = require(Shared:WaitForChild("Util"))

local SessionService = require(script.Parent.SessionService)
local PlotService = require(script.Parent.PlotService)
local MapBuilder = require(script.Parent.MapBuilder)
local EggFactory = require(script.Parent.EggFactory)
local SyncService = require(script.Parent.SyncService)
local NotifyService = require(script.Parent.NotifyService)

local EggService = {}

local handlers = {
	onStealRequest = nil :: ((player: Player, uid: string, ownerId: number) -> ())?,
	onSecureRequest = nil :: ((player: Player, plot: any, slotIndex: number) -> ())?,
	onManageRequest = nil :: ((player: Player, uid: string) -> ())?,
}

function EggService.setHandlers(newHandlers: any)
	for key, value in pairs(newHandlers) do
		handlers[key] = value
	end
end

-- Helpers modèles ---------------------------------------------------------

local function eggsFolder(plot: any): Folder
	local folder = plot.model:FindFirstChild("Eggs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Eggs"
		folder.Parent = plot.model
	end
	return folder
end

local function makePrompt(parent: BasePart, name: string, actionText: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = ""
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt.Parent = parent
	return prompt
end

local function connectPrompts(model: Model, def: any)
	local body = model.PrimaryPart
	if not body then
		return
	end

	local stealPrompt = makePrompt(body, "StealPrompt", "Voler", Config.StealHoldDuration)
	stealPrompt.ObjectText = def.name

	local managePrompt = makePrompt(body, "ManagePrompt", "Gérer", 0)
	managePrompt.ObjectText = def.name

	local function guard(player: Player): boolean
		if not model.Parent then
			return false
		end
		if model:GetAttribute("Free") == true then
			return false
		end
		local session = SessionService.get(player)
		if not session then
			return false
		end
		if session.carrying then
			return false
		end
		return true
	end

	stealPrompt.Triggered:Connect(function(player)
		if not guard(player) then
			return
		end
		local uid = model:GetAttribute("Uid")
		local ownerId = model:GetAttribute("OwnerUserId")
		if type(uid) ~= "string" or type(ownerId) ~= "number" then
			return
		end
		if ownerId == player.UserId then
			return
		end
		if handlers.onStealRequest then
			handlers.onStealRequest(player, uid, ownerId)
		end
	end)

	managePrompt.Triggered:Connect(function(player)
		if not guard(player) then
			return
		end
		local uid = model:GetAttribute("Uid")
		local ownerId = model:GetAttribute("OwnerUserId")
		if type(uid) ~= "string" or ownerId ~= player.UserId then
			return
		end
		if handlers.onManageRequest then
			handlers.onManageRequest(player, uid)
		end
	end)
end

local function positionModel(egg: any, cframe: CFrame)
	local model = egg.model
	if not model then
		return
	end
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Anchored = true
		elseif child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end
	model:PivotTo(cframe)
end

--- Place le modèle d'œuf au-dessus de son socle.
function EggService.snapToSlot(session: any, egg: any)
	local plot = session.plot
	if not plot then
		return
	end
	local slot = plot.slots[egg.slot]
	if not slot then
		return
	end
	positionModel(egg, slot.anchor.CFrame)
	if egg.model then
		egg.model:SetAttribute("BaseCFrame", slot.anchor.CFrame)
		egg.model.Parent = eggsFolder(plot)
	end
end

function EggService.spawnModel(session: any, egg: any)
	if not session.plot then
		return
	end
	local model = EggFactory.build(egg.def, egg.level)
	model:SetAttribute("Uid", egg.uid)
	model:SetAttribute("OwnerUserId", session.userId)
	model:SetAttribute("Free", false)
	if egg.ownerName then
		model:SetAttribute("OwnerName", egg.ownerName)
	end
	egg.model = model
	connectPrompts(model, egg.def)
	EggService.snapToSlot(session, egg)
end

--- Détruit le modèle d'un œuf.
function EggService.destroyModel(egg: any)
	if egg.model then
		egg.model:Destroy()
		egg.model = nil
	end
end

--- Vide tous les modèles d'œufs d'une parcelle.
function EggService.clearPlot(plot: any)
	if not plot then
		return
	end
	local folder = plot.model:FindFirstChild("Eggs")
	if folder then
		folder:Destroy()
	end
end

--- Reconstruit visuellement tous les œufs d'une session.
function EggService.rebuild(session: any)
	if not session.plot then
		return
	end
	EggService.clearPlot(session.plot)
	EggService.refreshSlotLocks(session)
	for _, egg in ipairs(SessionService.eggsSorted(session)) do
		EggService.spawnModel(session, egg)
	end
end

--- Met à jour les socles verrouillés / déverrouillés.
function EggService.refreshSlotLocks(session: any)
	if not session.plot then
		return
	end
	for slotIndex = 1, Config.MaxSlots do
		local unlocked = slotIndex <= session.data.slots
		MapBuilder.setSlotUnlocked(session.plot, slotIndex, unlocked, Config.SlotUpgradeCost[slotIndex])
	end
end

--- (Re)branche les prompts standards sur un modèle existant.
function EggService.attachPrompts(model: Model, def: any)
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("ProximityPrompt") then
			child:Destroy()
		end
	end
	connectPrompts(model, def)
end

--- Adopte un modèle existant (œuf volé porté puis sécurisé).
function EggService.adoptModel(session: any, egg: any, model: Model)
	egg.model = model
	EggService.attachPrompts(model, egg.def)
	EggService.snapToSlot(session, egg)
end

-- Recherche ---------------------------------------------------------------

--- Retrouve un œuf (et sa session) à partir de son uid.
function EggService.findEgg(uid: string): (any?, any?)
	if type(uid) ~= "string" then
		return nil, nil
	end
	for _, session in ipairs(SessionService.all()) do
		local egg = session.eggs[uid]
		if egg then
			return egg, session
		end
	end
	return nil, nil
end

-- Achat d'œufs ------------------------------------------------------------

--- Ajoute un œuf et son modèle à la base du joueur.
function EggService.addEgg(session: any, eggId: string, level: number, slot: number?): (any?, string?)
	if not session.plot then
		return nil, "Tu n'as pas encore de parcelle."
	end
	if SessionService.countEggs(session) >= Config.MaxEggsPerPlayer then
		return nil, "Ta base est pleine !"
	end
	if not SessionService.firstFreeSlot(session) then
		return nil, "Aucun socle libre : agrandis ta base."
	end
	local egg = SessionService.addEgg(session, eggId, level, slot)
	if not egg then
		return nil, "Impossible de placer cet œuf."
	end
	EggService.spawnModel(session, egg)
	SyncService.refreshPlotSign(session)
	return egg, nil
end

--- Débloque le prochain socle de la parcelle.
function EggService.buySlot(player: Player, plot: any, slotIndex: number)
	local session = SessionService.get(player)
	if not session or session.plot ~= plot then
		return
	end
	if slotIndex ~= session.data.slots + 1 then
		return
	end
	local cost = Config.SlotUpgradeCost[slotIndex]
	if not cost then
		return
	end
	if not SessionService.canAfford(session, cost) then
		NotifyService.notify(player, ("Il te faut $%s pour ce socle."):format(Util.formatNumber(cost)), "error")
		return
	end

	SessionService.spend(session, cost)
	session.data.slots = slotIndex
	EggService.refreshSlotLocks(session)
	SyncService.push(session)
	SyncService.pushCash(session)
	NotifyService.notify(player, ("Socle %d débloqué !"):format(slotIndex), "success")
end

-- Fusion / revente --------------------------------------------------------

--- Cherche un œuf identique (même espèce, même niveau) dans la base.
function EggService.findMergePartner(session: any, egg: any): any?
	for _, other in pairs(session.eggs) do
		if other.uid ~= egg.uid and other.eggId == egg.eggId and other.level == egg.level then
			return other
		end
	end
	return nil
end

function EggService.merge(player: Player, uid: string)
	local session = SessionService.get(player)
	if not session then
		return
	end
	local egg = SessionService.getEgg(session, uid)
	if not egg then
		return
	end
	if egg.level >= Config.MaxEggLevel then
		NotifyService.notify(player, "Cet œuf est déjà au niveau maximum.", "error")
		return
	end
	local partner = EggService.findMergePartner(session, egg)
	if not partner then
		NotifyService.notify(
			player,
			"Il faut deux œufs identiques du même niveau pour fusionner.",
			"error"
		)
		return
	end

	EggService.destroyModel(partner)
	SessionService.removeEgg(session, partner.uid)
	egg.level += 1
	if egg.model then
		EggFactory.refreshBillboard(egg.model, egg.def, egg.level)
	end
	session.data.stats.merged += 1

	SyncService.push(session)
	SyncService.pushCash(session)
	SyncService.refreshPlotSign(session)
	NotifyService.notify(
		player,
		("Fusion réussie : %s niveau %d !"):format(egg.def.name, egg.level),
		"success"
	)
	NotifyService.feed(("%s a fusionné un %s (Niv.%d)"):format(session.displayName, egg.def.name, egg.level), "merge")
end

function EggService.sell(player: Player, uid: string)
	local session = SessionService.get(player)
	if not session then
		return
	end
	local egg = SessionService.getEgg(session, uid)
	if not egg then
		return
	end
	local value = SessionService.sellValue(egg)
	EggService.destroyModel(egg)
	SessionService.removeEgg(session, egg.uid)
	SessionService.award(session, value)
	session.data.stats.sold += 1

	SyncService.push(session)
	SyncService.pushCash(session)
	SyncService.refreshPlotSign(session)
	NotifyService.notify(player, ("Vendu pour $%s"):format(Util.formatNumber(value)), "reward")
end

-- Revenus passifs ---------------------------------------------------------

function EggService.startIncomeLoop()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Config.IncomeTick)
			local now = os.clock()
			local delta = math.min(now - last, 5)
			last = now

			for _, session in ipairs(SessionService.all()) do
				if session.plot and not session.joining then
					local income = SessionService.income(session)
					if income > 0 then
						local before = session.data.cash
						SessionService.award(session, income * delta)
						local gained = session.data.cash - before
						if gained > 0 then
							session.data.stats.best = math.max(session.data.stats.best, math.floor(session.data.cash))
							SyncService.pushCash(session)
						end
					end
				end
			end
		end
	end)
end

-- Initialisation ----------------------------------------------------------

function EggService.init()
	local world = PlotService.getWorld()
	if not world then
		warn("[EggService] map absente")
		return
	end

	for _, plot in ipairs(world.plots) do
		for slotIndex, slot in ipairs(plot.slots) do
			slot.securePrompt.Triggered:Connect(function(player)
				local session = SessionService.get(player)
				if not session or session.plot ~= plot then
					return
				end
				if handlers.onSecureRequest then
					handlers.onSecureRequest(player, plot, slotIndex)
				end
			end)

			slot.upgradePrompt.Triggered:Connect(function(player)
				local session = SessionService.get(player)
				if not session or session.plot ~= plot then
					return
				end
				EggService.buySlot(player, plot, slotIndex)
			end)
		end
	end

	EggService.startIncomeLoop()
end

--- Nettoyage complet quand un joueur quitte.
function EggService.clearSession(session: any)
	for _, egg in pairs(session.eggs) do
		EggService.destroyModel(egg)
	end
	table.clear(session.eggs)
	EggService.clearPlot(session.plot)
end

return EggService
