--!nonstrict
--[[
	Main (serveur)
	--------------
	Orchestrateur : démarre les services, gère l'arrivée / le départ des
	joueurs, les respawns, la sauvegarde automatique et la fermeture.

	Ordre de démarrage important :
	  remotes -> sync -> scène -> map -> parcelles -> œufs -> vol -> shop -> net
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent.DataService)
local SessionService = require(script.Parent.SessionService)
local PlotService = require(script.Parent.PlotService)
local MapBuilder = require(script.Parent.MapBuilder)
local EggService = require(script.Parent.EggService)
local StealService = require(script.Parent.StealService)
local ShopService = require(script.Parent.ShopService)
local SyncService = require(script.Parent.SyncService)
local NotifyService = require(script.Parent.NotifyService)
local NetService = require(script.Parent.NetService)
local SceneService = require(script.Parent.SceneService)

Players.CharacterAutoLoads = false
Players.RespawnTime = 3

local world: any = nil
local waiting: { Player } = {}

-- Leaderstats -------------------------------------------------------------

local function setupLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cash = Instance.new("IntValue")
	cash.Name = "Argent"
	cash.Value = 0
	cash.Parent = leaderstats

	local income = Instance.new("IntValue")
	income.Name = "Revenus"
	income.Value = 0
	income.Parent = leaderstats

	leaderstats.Parent = player
end

-- Parcelles ---------------------------------------------------------------

local function givePlot(session: any, plot: any)
	session.plot = plot
	EggService.rebuild(session)
	SyncService.push(session)
	SyncService.pushCash(session)
	SyncService.refreshPlotSign(session)
end

local function tryAssignPlot(session: any)
	if session.plot then
		return true
	end
	local plot = PlotService.claim(session.player)
	if not plot then
		return false
	end
	givePlot(session, plot)
	NotifyService.notify(session.player, "Ta parcelle est prête ! Achète ton premier œuf au kiosque.", "success", 6)
	return true
end

local function removeFromWaiting(player: Player)
	for index, waitingPlayer in ipairs(waiting) do
		if waitingPlayer == player then
			table.remove(waiting, index)
			break
		end
	end
end

local function processWaiting()
	while #waiting > 0 do
		local nextPlayer = waiting[1]
		local session = SessionService.get(nextPlayer)
		if not session or not nextPlayer.Parent then
			table.remove(waiting, 1)
		elseif tryAssignPlot(session) then
			table.remove(waiting, 1)
			local character = nextPlayer.Character
			if character and session.plot then
				character:PivotTo(session.plot.spawnCFrame)
			end
		else
			return -- plus de parcelle libre
		end
	end
end

-- Personnage --------------------------------------------------------------

local function placeCharacter(session: any, character: Model)
	local plot = session.plot
	if not plot then
		-- Sans parcelle : on apparaît sur la place centrale en attendant.
		character:PivotTo(CFrame.new(0, 6, 0))
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	character:PivotTo(plot.spawnCFrame)
	task.delay(0.15, function()
		if character.Parent and character:FindFirstChild("HumanoidRootPart") and session.plot then
			character:PivotTo(session.plot.spawnCFrame)
		end
	end)
end

local function onCharacterAdded(session: any, character: Model)
	local player = session.player
	local root = character:WaitForChild("HumanoidRootPart", 15)
	if root then
		placeCharacter(session, character)
	end

	local humanoid = character:WaitForChild("Humanoid", 15)
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = Config.NormalWalkSpeed
	humanoid.Died:Connect(function()
		StealService.onCharacterDied(session)
		task.delay(Players.RespawnTime + 0.5, function()
			if player.Parent and SessionService.get(player) == session and not session.respawning then
				session.respawning = true
				local ok, err = pcall(function()
					player:LoadCharacter()
				end)
				session.respawning = false
				if not ok then
					warn("[Main] respawn impossible pour " .. player.Name .. ": " .. tostring(err))
				end
			end
		end)
	end)

	SyncService.push(session)
	SyncService.pushCash(session)
end

-- Cycle de vie joueur -----------------------------------------------------

local function onPlayerAdded(player: Player)
	local data, loadError = DataService.load(player.UserId)
	if not player.Parent then
		DataService.release(player.UserId)
		return
	end

	local session = SessionService.create(player, data)
	SessionService.hydrate(session)
	setupLeaderstats(player)
	ShopService.ensureRolled(session)

	if loadError and loadError ~= "mode mémoire" then
		SessionService.destroy(player)
		if DataService.online then
			-- On préfère refuser la session plutôt que risquer d'écraser
			-- une sauvegarde en cours d'utilisation sur un autre serveur.
			player:Kick("Ta sauvegarde est en cours de chargement. Réessaie dans quelques secondes !")
			return
		end
		NotifyService.notify(
			player,
			"Sauvegarde indisponible : progression non enregistrée.",
			"danger",
			8
		)
	end

	if not tryAssignPlot(session) then
		table.insert(waiting, player)
		NotifyService.notify(player, "Toutes les parcelles sont prises : tu es en file d'attente.", "info", 8)
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(session, character)
	end)

	SyncService.push(session)
	SyncService.pushCash(session)
	local loadOk, loadErr = pcall(function()
		player:LoadCharacter()
	end)
	if not loadOk then
		warn("[Main] LoadCharacter a échoué pour " .. player.Name .. ": " .. tostring(loadErr))
	end
	session.joining = false

	if not session.plot then
		-- Respawne au centre en attendant une parcelle
		task.delay(0.5, function()
			if player.Character and not session.plot then
				player.Character:PivotTo(CFrame.new(0, 6, 0))
			end
		end)
	end

	NotifyService.notify(
		player,
		"Bienvenue ! Achète un œuf au kiosque (E), puis vole ceux des autres.",
		"info",
		6
	)
end

local function onPlayerRemoving(player: Player)
	removeFromWaiting(player)
	local session = SessionService.get(player)
	if not session then
		return
	end

	StealService.onPlayerLeaving(session)
	SessionService.serializeEggs(session)
	session.data.lastSeen = os.time()

	local userId = session.userId
	local data = session.data

	EggService.clearSession(session)
	PlotService.release(player, player.DisplayName)
	SessionService.destroy(player)

	task.spawn(function()
		local ok, err = DataService.save(userId, data)
		if not ok then
			warn("[Main] sauvegarde de départ échouée: " .. tostring(err))
		end
		DataService.release(userId)
	end)

	-- Une parcelle vient de se libérer : on la donne au joueur suivant.
	task.delay(0.2, processWaiting)
	task.delay(1, SyncService.broadcastBoard)
end

-- Démarrage ---------------------------------------------------------------

local function bootstrap()
	Remotes.setupServer()

	NotifyService.init()
	SyncService.init()

	SceneService.init()

	world = MapBuilder.build()
	PlotService.init(world)

	EggService.setHandlers({
		onStealRequest = StealService.requestSteal,
		onSecureRequest = StealService.secureAtSlot,
		onManageRequest = function(player: Player, uid: string)
			local session = SessionService.get(player)
			if session and SessionService.getEgg(session, uid) then
				NotifyService.openPanel(player, "Egg", { uid = uid })
			end
		end,
	})

	EggService.init()
	StealService.init()
	ShopService.init(world)
	NetService.init()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Sauvegarde automatique
	task.spawn(function()
		while true do
			task.wait(Config.SaveInterval)
			for _, session in ipairs(SessionService.all()) do
				SessionService.serializeEggs(session)
				task.spawn(function()
					DataService.save(session.userId, session.data)
				end)
			end
		end
	end)

	-- Classement
	task.spawn(function()
		while true do
			task.wait(5)
			SyncService.broadcastBoard()
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, session in ipairs(SessionService.all()) do
			SessionService.serializeEggs(session)
			session.data.lastSeen = os.time()
			pending += 1
			task.spawn(function()
				DataService.save(session.userId, session.data)
				DataService.release(session.userId)
			end)
		end
		if pending > 0 then
			task.wait(4)
		end
	end)

	print(("[Steal a Egg] serveur prêt · %d parcelles · DataStore %s"):format(
		#world.plots,
		DataService.online and "actif" or "indisponible (mode mémoire)"
	))
end

bootstrap()
