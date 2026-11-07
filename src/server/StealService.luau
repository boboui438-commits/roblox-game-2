--!nonstrict
--[[
	StealService
	------------
	Tout le système de vol :
	  - démarrer un vol (validation serveur complète)
	  - porter l'œuf (soudé au personnage, vitesse réduite)
	  - sécuriser l'œuf dans sa base (transfert de propriété)
	  - lâcher l'œuf / mourir / quitter => œuf libre au sol puis retour
	  - protection temporaire de la base (cadenas)

	Le serveur est la seule autorité : aucune position, aucun argent et aucun
	état "je porte un œuf" ne vient du client.
]]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EggCatalog = require(Shared:WaitForChild("EggCatalog"))
local Util = require(Shared:WaitForChild("Util"))

local SessionService = require(script.Parent.SessionService)
local EggService = require(script.Parent.EggService)
local PlotService = require(script.Parent.PlotService)
local SyncService = require(script.Parent.SyncService)
local NotifyService = require(script.Parent.NotifyService)

local StealService = {}

local looseFolder: Folder? = nil
local looseEggs: { [string]: any } = {}

-- Utilitaires -------------------------------------------------------------

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function distanceTo(player: Player, position: Vector3): number
	local root = getRoot(player)
	if not root then
		return math.huge
	end
	return (root.Position - position).Magnitude
end

local function setCarryMovement(player: Player, carrying: boolean)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if carrying then
		humanoid.WalkSpeed = Config.CarryWalkSpeed
		humanoid.JumpPower = 0
		humanoid.UseJumpPower = true
		humanoid.JumpHeight = 0
	else
		humanoid.WalkSpeed = Config.NormalWalkSpeed
		humanoid.JumpPower = 50
		humanoid.UseJumpPower = true
		humanoid.JumpHeight = 7.2
	end
end

local function burst(position: Vector3, color: Color3, count: number, spread: number)
	local folder = Workspace:FindFirstChild("Effects")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Effects"
		folder.Parent = Workspace
	end

	for index = 1, count do
		local orb = Instance.new("Part")
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(0.8, 0.8, 0.8)
		orb.Material = Enum.Material.Neon
		orb.Color = color
		orb.Anchored = true
		orb.CanCollide = false
		orb.CanQuery = false
		orb.CanTouch = false
		orb.CFrame = CFrame.new(position)
		orb.Parent = folder

		local offset = Vector3.new(
			(math.random() - 0.5) * spread,
			math.random() * spread * 0.8 + 1,
			(math.random() - 0.5) * spread
		)
		TweenService:Create(orb, TweenInfo.new(0.55 + index * 0.03, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(position + offset),
			Transparency = 1,
			Size = Vector3.new(0.1, 0.1, 0.1),
		}):Play()
		task.delay(0.9, function()
			orb:Destroy()
		end)
	end
end

local function eggPosition(egg: any): Vector3
	if egg.model and egg.model.PrimaryPart then
		return egg.model.PrimaryPart.Position
	end
	return Vector3.zero
end

-- Œufs libres au sol ------------------------------------------------------

local function setFreePrompts(record: any)
	local model = record.model
	if not model or not model.PrimaryPart then
		return
	end
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("ProximityPrompt") then
			child:Destroy()
		end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Récupérer"
	prompt.ObjectText = record.def.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		StealService.pickupFree(player, record)
	end)
end

local function anchorModel(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.Massless = false
		elseif descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		end
	end
end

local function placeOnGround(model: Model, position: Vector3)
	anchorModel(model)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local result = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -80, 0), params)
	local floorY = result and result.Position.Y or 0
	model:PivotTo(CFrame.new(position.X, floorY + 3.2, position.Z))
end

--- Transforme l'œuf porté en œuf libre au sol.
function StealService.dropToWorld(session: any, egg: any, lifetime: number)
	local model = egg.model
	if not model then
		return
	end

	local position
	local root = session.player.Character and session.player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		position = root.Position + (root.CFrame.LookVector * 2)
	else
		position = eggPosition(egg)
	end

	anchorModel(model)
	model.Parent = looseFolder
	model:SetAttribute("Free", true)
	model:SetAttribute("OwnerUserId", -1)
	model:SetAttribute("Carried", false)
	placeOnGround(model, position)
	model:SetAttribute("BaseCFrame", model:GetPivot())

	local record = {
		uid = egg.uid,
		eggId = egg.eggId,
		level = egg.level,
		def = egg.def,
		model = model,
		originalOwnerId = egg.originalOwnerId,
		ownerName = egg.ownerName,
		freeUntil = os.clock() + lifetime,
	}
	looseEggs[egg.uid] = record
	setFreePrompts(record)
end

--- Un joueur ramasse un œuf libre.
function StealService.pickupFree(player: Player, record: any)
	local session = SessionService.get(player)
	if not session then
		return
	end
	if not session.plot then
		NotifyService.notify(player, "Tu n'as pas encore de base pour poser cet œuf.", "error")
		return
	end
	if session.carrying then
		NotifyService.notify(player, "Tu portes déjà un œuf !", "error")
		return
	end
	if looseEggs[record.uid] ~= record then
		return
	end
	if not record.model or not record.model.Parent then
		return
	end
	if distanceTo(player, eggPosition(record)) > Config.StealRange + 6 then
		return
	end
	if os.clock() - session.lastStealAt < Config.StealCooldown then
		return
	end
	session.lastStealAt = os.clock()

	looseEggs[record.uid] = nil
	for _, child in ipairs(record.model:GetDescendants()) do
		if child:IsA("ProximityPrompt") then
			child:Destroy()
		end
	end

	local egg = {
		uid = record.uid,
		eggId = record.eggId,
		level = record.level,
		def = record.def,
		model = record.model,
		originalOwnerId = record.originalOwnerId,
		ownerName = record.ownerName,
	}
	if not StealService.beginCarry(session, egg) then
		looseEggs[record.uid] = record
		setFreePrompts(record)
		return
	end
	NotifyService.notify(player, ("Tu as récupéré %s ! Ramène-le à ta base."):format(record.def.name), "success")
end

-- Portage -----------------------------------------------------------------

--- Soude l'œuf au personnage et passe la session en mode "portage".
--- Retourne false (sans rien casser) si le personnage n'est pas prêt.
function StealService.beginCarry(session: any, egg: any): boolean
	local player = session.player
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local model = egg.model
	if not root or not model or not model.PrimaryPart then
		return false
	end

	local body = model.PrimaryPart

	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("ProximityPrompt") then
			child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = false
			child.CanCollide = false
			child.Massless = true
		end
	end

	-- Les décorations doivent être soudées au corps, sinon elles tombent.
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child ~= body then
			local decorationWeld = Instance.new("WeldConstraint")
			decorationWeld.Name = "DecorationWeld"
			decorationWeld.Part0 = child
			decorationWeld.Part1 = body
			decorationWeld.Parent = child
		end
	end

	model:SetAttribute("Free", false)
	model:SetAttribute("Carried", true)
	-- Le modèle reste dans le Workspace (et non dans le personnage) pour
	-- survivre à la mort du porteur.
	model.Parent = looseFolder

	model:PivotTo(root.CFrame * Config.CarryOffset)

	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = body
	weld.Part1 = root
	weld.Parent = body

	session.carrying = egg
	setCarryMovement(player, true)
	SyncService.push(session)
	return true
end

--- Enlève la soudure et rend le modèle manipulable.
local function detachFromCharacter(egg: any)
	local model = egg.model
	if not model then
		return
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		end
	end
end

-- Vol ---------------------------------------------------------------------

--- Vérifications communes d'un vol. Retourne (ok, messageErreur).
local function validateSteal(session: any, egg: any, ownerSession: any): (boolean, string?)
	if not session or not ownerSession or not egg then
		return false, "Cible introuvable."
	end
	if not session.plot then
		return false, "Tu n'as pas encore de base."
	end
	if session.carrying then
		return false, "Tu portes déjà un œuf."
	end
	if ownerSession.userId == session.userId then
		return false, "C'est déjà ton œuf !"
	end
	if not ownerSession.plot or ownerSession.plot.ownerUserId ~= ownerSession.userId then
		return false, "Cette base n'existe plus."
	end
	if ownerSession.lockUntil > os.clock() then
		return false, "Cette base est protégée."
	end
	if not getRoot(session.player) then
		return false, "Tu dois être en vie."
	end
	if os.clock() - session.lastStealAt < Config.StealCooldown then
		return false, "Doucement..."
	end
	if distanceTo(session.player, eggPosition(egg)) > Config.StealRange + 4 then
		return false, "Trop loin de l'œuf."
	end
	return true, nil
end

--- Demande de vol (prompt) - tout est revalidé ici.
function StealService.requestSteal(player: Player, uid: string, ownerId: number)
	local session = SessionService.get(player)
	local ownerSession = SessionService.getById(ownerId)
	if not session or not ownerSession then
		return
	end
	local egg = SessionService.getEgg(ownerSession, uid)
	if not egg then
		return
	end

	local ok, err = validateSteal(session, egg, ownerSession)
	if not ok then
		NotifyService.notify(player, err or "Impossible de voler cet œuf.", "error")
		return
	end

	session.lastStealAt = os.clock()

	-- Transfert : l'œuf quitte la base de la victime
	SessionService.removeEgg(ownerSession, egg.uid)
	egg.originalOwnerId = ownerSession.userId
	egg.ownerName = ownerSession.displayName
	egg.carriedBy = session.userId

	if not StealService.beginCarry(session, egg) then
		-- Le personnage n'était pas prêt : on remet l'œuf en place.
		local restored = SessionService.addEgg(ownerSession, egg.eggId, egg.level, egg.slot)
		if restored and egg.model then
			egg.model:SetAttribute("Uid", restored.uid)
			egg.model:SetAttribute("OwnerUserId", ownerSession.userId)
			egg.model:SetAttribute("Free", false)
			egg.model:SetAttribute("Carried", false)
			EggService.adoptModel(ownerSession, restored, egg.model)
		end
		SyncService.push(ownerSession)
		NotifyService.notify(player, "Impossible de saisir l'œuf, réessaie.", "error")
		return
	end

	SyncService.push(ownerSession)
	SyncService.pushCash(ownerSession)
	SyncService.refreshPlotSign(ownerSession)
	SyncService.refreshPlotSign(session)

	NotifyService.alert(
		ownerSession.player,
		("%s te vole %s ! Cours le récupérer !"):format(session.displayName, egg.def.name)
	)
	NotifyService.notify(
		player,
		("Tu portes %s. Ramène-le à ta base !"):format(egg.def.name),
		"success"
	)
	NotifyService.feed(
		("%s vole %s à %s"):format(session.displayName, egg.def.name, ownerSession.displayName),
		"steal"
	)
	burst(eggPosition(egg), Color3.fromHex(egg.def.accent), 8, 7)
end

--- Sécurise l'œuf porté dans un socle de sa base.
function StealService.secureAtSlot(player: Player, plot: any, slotIndex: number)
	local session = SessionService.get(player)
	if not session or session.plot ~= plot then
		return
	end
	local egg = session.carrying
	if not egg then
		return
	end
	if slotIndex < 1 or slotIndex > session.data.slots then
		NotifyService.notify(player, "Ce socle est verrouillé.", "error")
		return
	end
	if SessionService.eggAtSlot(session, slotIndex) then
		NotifyService.notify(player, "Ce socle est déjà occupé.", "error")
		return
	end

	local slot = plot.slots[slotIndex]
	if not slot then
		return
	end
	if distanceTo(player, slot.anchor.Position) > Config.SecureRange then
		NotifyService.notify(player, "Rapproche-toi de ton socle.", "error")
		return
	end

	local newEgg = SessionService.addEgg(session, egg.eggId, egg.level, slotIndex)
	if not newEgg then
		NotifyService.notify(player, "Impossible de poser cet œuf ici.", "error")
		return
	end

	-- Réutilise le modèle porté pour éviter tout "pop" visuel
	local model = egg.model
	detachFromCharacter(egg)
	if model then
		for _, child in ipairs(model:GetDescendants()) do
			if child:IsA("ProximityPrompt") then
				child:Destroy()
			end
		end
		model:SetAttribute("Carried", false)
		model:SetAttribute("Free", false)
		model:SetAttribute("Uid", newEgg.uid)
		model:SetAttribute("OwnerUserId", session.userId)
		EggService.adoptModel(session, newEgg, model)
	end

	session.carrying = nil
	setCarryMovement(player, false)

	-- Récompenses
	local bonus = math.floor(Config.StealBonusBase + egg.def.price * Config.StealBonusPercent)
	SessionService.award(session, bonus)
	session.data.stats.stolen += 1

	local victimSession = egg.originalOwnerId and SessionService.getById(egg.originalOwnerId) or nil
	if victimSession then
		victimSession.data.stats.lost += 1
		SyncService.push(victimSession)
		SyncService.pushCash(victimSession)
		SyncService.refreshPlotSign(victimSession)
		if victimSession.player.Parent then
			NotifyService.notify(
				victimSession.player,
				("%s a sécurisé ton %s. Reprends-en un !"):format(session.displayName, egg.def.name),
				"danger"
			)
		end
		NotifyService.feed(
			("%s a volé %s à %s et l'a sécurisé !"):format(
				session.displayName,
				egg.def.name,
				victimSession.displayName
			),
			"steal"
		)
	else
		NotifyService.feed(("%s a récupéré un %s"):format(session.displayName, egg.def.name), "steal")
	end

	SyncService.push(session)
	SyncService.pushCash(session)
	SyncService.refreshPlotSign(session)
	NotifyService.notify(
		player,
		("%s sécurisé ! +$%s de prime"):format(egg.def.name, Util.formatNumber(bonus)),
		"reward"
	)
	burst(slot.anchor.Position, EggCatalog.rarityGlow(egg.eggId), 12, 9)
end

--- Le joueur lâche volontairement l'œuf.
function StealService.dropCarried(session: any, lifetime: number?)
	local egg = session.carrying
	if not egg then
		return
	end
	session.carrying = nil
	setCarryMovement(session.player, false)
	StealService.dropToWorld(session, egg, lifetime or Config.DroppedEggLifetime)
	SyncService.push(session)
	SyncService.pushCash(session)
	NotifyService.notify(session.player, "Tu as lâché l'œuf ! N'importe qui peut le prendre.", "danger")
	if egg.originalOwnerId then
		local ownerSession = SessionService.getById(egg.originalOwnerId)
		if ownerSession then
			NotifyService.notify(
				ownerSession.player,
				("%s a lâché ton %s ! Va le récupérer."):format(session.displayName, egg.def.name),
				"info"
			)
		end
	end
end

function StealService.requestDrop(player: Player)
	local session = SessionService.get(player)
	if not session or not session.carrying then
		return
	end
	StealService.dropCarried(session, Config.DroppedEggLifetime)
end

-- Mort / départ -----------------------------------------------------------

function StealService.onCharacterDied(session: any)
	if not session or not session.carrying then
		return
	end
	task.delay(0.1, function()
		if session.carrying and session.carrying.model then
			StealService.dropCarried(session, Config.DroppedEggLifetime)
		end
	end)
end

function StealService.onPlayerLeaving(session: any)
	if not session then
		return
	end
	local egg = session.carrying
	if egg then
		session.carrying = nil
		if egg.model then
			StealService.dropToWorld(session, egg, 12)
		end
	end

	-- Rendre les œufs libres qui appartenaient à ce joueur
	for _, record in pairs(looseEggs) do
		if record.originalOwnerId == session.userId then
			record.freeUntil = math.min(record.freeUntil, os.clock() + 5)
		end
	end
end

-- Cadenas ---------------------------------------------------------------

function StealService.lockCost(session: any): number
	return math.floor(Config.LockCostBase + SessionService.income(session) * Config.LockCostIncomeFactor)
end

function StealService.buyLock(player: Player)
	local session = SessionService.get(player)
	if not session or not session.plot then
		return
	end
	if session.lockUntil > os.clock() then
		NotifyService.notify(player, "Ta base est déjà protégée.", "error")
		return
	end
	if os.clock() - session.lastLockAt < Config.LockCooldown then
		return
	end
	if SessionService.countEggs(session) == 0 then
		NotifyService.notify(player, "Pose au moins un œuf avant de protéger ta base.", "error")
		return
	end

	local cost = StealService.lockCost(session)
	if not SessionService.canAfford(session, cost) then
		NotifyService.notify(player, ("Il te faut $%s pour protéger ta base."):format(Util.formatNumber(cost)), "error")
		return
	end

	SessionService.spend(session, cost)
	session.lastLockAt = os.clock()
	session.lockUntil = os.clock() + Config.LockDuration
	PlotService.setLock(session.plot, session.lockUntil)
	SyncService.push(session)
	SyncService.pushCash(session)
	NotifyService.notify(
		player,
		("Base protégée pendant %d secondes (-$%s)"):format(Config.LockDuration, Util.formatNumber(cost)),
		"success"
	)
	NotifyService.feed(("%s protège sa base !"):format(session.displayName), "info")
end

-- Boucle d'entretien ------------------------------------------------------

function StealService.init()
	looseFolder = Workspace:FindFirstChild(Config.LooseEggFolderName)
	if looseFolder then
		looseFolder:Destroy()
	end
	looseFolder = Instance.new("Folder")
	looseFolder.Name = Config.LooseEggFolderName
	looseFolder.Parent = Workspace

	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()

			-- Retour automatique des œufs abandonnés
			for uid, record in pairs(looseEggs) do
				local expired = now >= record.freeUntil
				local modelGone = not record.model or not record.model.Parent
				if expired or modelGone then
					looseEggs[uid] = nil
					local ownerSession = record.originalOwnerId and SessionService.getById(record.originalOwnerId) or nil
					if ownerSession and ownerSession.plot then
						local slot = SessionService.firstFreeSlot(ownerSession)
						if slot then
							local egg = SessionService.addEgg(ownerSession, record.eggId, record.level, slot)
							if egg and record.model then
								record.model:SetAttribute("Uid", egg.uid)
								record.model:SetAttribute("OwnerUserId", ownerSession.userId)
								record.model:SetAttribute("Free", false)
								EggService.adoptModel(ownerSession, egg, record.model)
								NotifyService.notify(
									ownerSession.player,
									("Ton %s est revenu à ta base."):format(record.def.name),
									"success"
								)
								SyncService.push(ownerSession)
								SyncService.pushCash(ownerSession)
								SyncService.refreshPlotSign(ownerSession)
								continue
							end
						end
					end
					if record.model then
						record.model:Destroy()
					end
				end
			end

			-- Fin des protections
			for _, session in ipairs(SessionService.all()) do
				if session.lockUntil > 0 then
					if now >= session.lockUntil then
						session.lockUntil = 0
						PlotService.setLock(session.plot, 0)
						SyncService.push(session)
					else
						PlotService.setLock(session.plot, session.lockUntil)
					end
				end
			end
		end
	end)
end

return StealService
