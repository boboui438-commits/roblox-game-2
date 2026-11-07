--!nonstrict
--[[
	SyncService
	-----------
	Construit et envoie l'état du joueur au client (snapshot + mises à jour
	légères), et diffuse le classement général.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EggCatalog = require(Shared:WaitForChild("EggCatalog"))
local Util = require(Shared:WaitForChild("Util"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local SessionService = require(script.Parent.SessionService)
local PlotService = require(script.Parent.PlotService)

local SyncService = {}

local stateRemote: RemoteEvent? = nil
local cashRemote: RemoteEvent? = nil
local boardRemote: RemoteEvent? = nil

function SyncService.init()
	stateRemote = Remotes.get(Remotes.State)
	cashRemote = Remotes.get(Remotes.StateCash)
	boardRemote = Remotes.get(Remotes.Board)
end

local function eggPayload(session: any): { any }
	local eggs = {}
	for _, egg in ipairs(SessionService.eggsSorted(session)) do
		table.insert(eggs, {
			uid = egg.uid,
			eggId = egg.eggId,
			level = egg.level,
			slot = egg.slot,
			income = EggCatalog.incomeFor(egg.def, egg.level),
		})
	end
	return eggs
end

local function shopPayload(session: any): { any }
	local slots = {}
	for index, entry in ipairs(session.shop) do
		if entry and entry.eggId and EggCatalog.get(entry.eggId) then
			slots[index] = {
				eggId = entry.eggId,
				price = EggCatalog.get(entry.eggId).price,
			}
		else
			slots[index] = false
		end
	end
	return slots
end

--- Snapshot complet de l'état d'un joueur.
function SyncService.buildState(session: any): any
	local plot = session.plot
	local carrying = session.carrying
	local nextSlotCost = Config.SlotUpgradeCost[session.data.slots + 1]

	return {
		cash = math.floor(session.data.cash),
		income = SessionService.income(session),
		bonus = SessionService.collectionBonus(session),
		slots = session.data.slots,
		eggs = eggPayload(session),
		plotIndex = plot and plot.index or nil,
		basePosition = plot and plot.spawnCFrame.Position or nil,
		lockRemaining = math.max(0, session.lockUntil - os.clock()),
		carried = carrying and {
			uid = carrying.uid,
			eggId = carrying.eggId,
			level = carrying.level,
			ownerName = carrying.ownerName,
		} or nil,
		shop = shopPayload(session),
		shopRefresh = math.max(0, session.shopRefreshAt - os.clock()),
		nextSlotCost = nextSlotCost,
		lockCost = math.floor(Config.LockCostBase + SessionService.income(session) * Config.LockCostIncomeFactor),
		stats = {
			stolen = session.data.stats.stolen,
			lost = session.data.stats.lost,
			earned = session.data.stats.earned,
			sold = session.data.stats.sold,
			merged = session.data.stats.merged,
		},
		collect = {
			count = SessionService.collectCount(session),
			total = EggCatalog.totalUnique(),
		},
		displayName = session.displayName,
	}
end

--- Envoie l'état complet au joueur.
function SyncService.push(session: any)
	if not stateRemote or not session.player.Parent then
		return
	end
	stateRemote:FireClient(session.player, SyncService.buildState(session))
end

--- Mise à jour légère (argent / revenus) + leaderstats.
function SyncService.pushCash(session: any)
	local cash = math.floor(session.data.cash)
	local income = SessionService.income(session)

	local leaderstats = session.player:FindFirstChild("leaderstats")
	if leaderstats then
		local cashValue = leaderstats:FindFirstChild("Argent")
		if cashValue and cashValue:IsA("IntValue") then
			cashValue.Value = math.min(cash, 2 ^ 31 - 1)
		end
		local incomeValue = leaderstats:FindFirstChild("Revenus")
		if incomeValue and incomeValue:IsA("IntValue") then
			incomeValue.Value = math.min(math.floor(income), 2 ^ 31 - 1)
		end
	end

	if cashRemote and session.player.Parent then
		cashRemote:FireClient(session.player, {
			cash = cash,
			income = income,
			bonus = SessionService.collectionBonus(session),
		})
	end
end

--- Rafraîchit le panneau de la parcelle (nom + revenus).
function SyncService.refreshPlotSign(session: any)
	local plot = session.plot
	if not plot then
		return
	end
	local income = SessionService.income(session)
	local subtitle = ("Revenus : $%s/s  ·  %d œufs"):format(Util.formatNumber(income), SessionService.countEggs(session))
	PlotService.setSign(plot, session.displayName, subtitle)
end

--- Diffuse le classement à tous les clients.
function SyncService.broadcastBoard()
	if not boardRemote then
		return
	end

	local entries = {}
	for _, session in ipairs(SessionService.all()) do
		table.insert(entries, {
			name = session.displayName,
			cash = math.floor(session.data.cash),
			stolen = session.data.stats.stolen,
			eggs = SessionService.countEggs(session),
		})
	end

	table.sort(entries, function(a, b)
		if a.cash == b.cash then
			return a.stolen > b.stolen
		end
		return a.cash > b.cash
	end)

	local top = {}
	for index = 1, math.min(5, #entries) do
		top[index] = entries[index]
	end

	boardRemote:FireAllClients(top)
end

function SyncService.broadcastBoardSoon()
	task.delay(0.4, SyncService.broadcastBoard)
end

--- Envoie l'état complet à tous les joueurs connectés.
function SyncService.pushAll()
	for _, session in ipairs(SessionService.all()) do
		SyncService.push(session)
	end
end

return SyncService
