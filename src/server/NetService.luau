--!nonstrict
--[[
	NetService
	----------
	Point d'entrée unique des messages client -> serveur.

	Tout est validé : nom d'action, type du payload, plage de valeurs,
	distance, état serveur, limitation de débit. Un client modifié ne peut
	que se faire refuser ses requêtes.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local SessionService = require(script.Parent.SessionService)
local EggService = require(script.Parent.EggService)
local StealService = require(script.Parent.StealService)
local ShopService = require(script.Parent.ShopService)
local SyncService = require(script.Parent.SyncService)
local NotifyService = require(script.Parent.NotifyService)

local NetService = {}

local actionRemote: RemoteEvent? = nil

local buckets: { [number]: { tokens: number, last: number } } = {}
local strikes: { [number]: { count: number, since: number } } = {}

-- Validation --------------------------------------------------------------

local function isBoundedInteger(value: any, minimum: number, maximum: number): boolean
	return Util.isSafeInteger(value) and value >= minimum and value <= maximum
end

local function isUid(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= 40
end

local function allow(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player.UserId]
	if not bucket then
		bucket = { tokens = Config.ActionBurst, last = now }
		buckets[player.UserId] = bucket
	end
	bucket.tokens = math.min(Config.ActionBurst, bucket.tokens + (now - bucket.last) * Config.ActionPerSecond)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function strike(player: Player, reason: string)
	local now = os.clock()
	local record = strikes[player.UserId]
	if not record or now - record.since > 15 then
		record = { count = 0, since = now }
		strikes[player.UserId] = record
	end
	record.count += 1
	if record.count == 10 then
		warn(("[NetService] requêtes invalides répétées de %s (%s)"):format(player.Name, reason))
	end
	if record.count >= Config.MaxRemoteFlood then
		player:Kick("Comportement invalide détecté.")
	end
end

-- Actions -----------------------------------------------------------------

local handlers = {}

handlers.Ready = function(player: Player, _payload: any)
	local session = SessionService.get(player)
	if session then
		SyncService.push(session)
		SyncService.pushCash(session)
	end
end

handlers.OpenShop = function(player: Player, _payload: any)
	ShopService.open(player)
end

handlers.Buy = function(player: Player, payload: any)
	if type(payload) ~= "table" then
		return false
	end
	if not isBoundedInteger(payload.index, 1, Config.ShopSlotCount) then
		return false
	end
	ShopService.buy(player, payload.index)
	return true
end

handlers.Reroll = function(player: Player, _payload: any)
	ShopService.reroll(player)
end

handlers.BuySlot = function(player: Player, _payload: any)
	local session = SessionService.get(player)
	if not session or not session.plot then
		return
	end
	EggService.buySlot(player, session.plot, session.data.slots + 1)
end

handlers.Merge = function(player: Player, payload: any)
	if type(payload) ~= "table" or not isUid(payload.uid) then
		return false
	end
	EggService.merge(player, payload.uid)
	return true
end

handlers.Sell = function(player: Player, payload: any)
	if type(payload) ~= "table" or not isUid(payload.uid) then
		return false
	end
	EggService.sell(player, payload.uid)
	return true
end

handlers.Drop = function(player: Player, _payload: any)
	StealService.requestDrop(player)
end

handlers.Lock = function(player: Player, _payload: any)
	StealService.buyLock(player)
end

handlers.Secure = function(player: Player, payload: any)
	local session = SessionService.get(player)
	if not session or not session.plot then
		return false
	end
	if type(payload) ~= "table" then
		return false
	end
	local slot = payload.slot
	if not session.carrying then
		-- Sans œuf porté, on peut quand même proposer le premier socle libre.
		slot = SessionService.firstFreeSlot(session)
	end
	if not isBoundedInteger(slot, 1, Config.MaxSlots) then
		return false
	end
	StealService.secureAtSlot(player, session.plot, slot)
	return true
end

-- Initialisation ----------------------------------------------------------

function NetService.init()
	actionRemote = Remotes.get(Remotes.Action)

	actionRemote.OnServerEvent:Connect(function(player, action, payload)
		if type(action) ~= "string" then
			strike(player, "action non-string")
			return
		end
		local handler = handlers[action]
		if not handler then
			strike(player, "action inconnue: " .. Util.trim(action, 24))
			return
		end
		if not allow(player) then
			return
		end
		local ok, result = pcall(handler, player, payload)
		if not ok then
			warn(("[NetService] %s a provoqué une erreur (%s): %s"):format(player.Name, action, tostring(result)))
			strike(player, "erreur handler")
		elseif result == false then
			strike(player, "payload invalide: " .. action)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		buckets[player.UserId] = nil
		strikes[player.UserId] = nil
	end)
end

return NetService
