--!nonstrict
--[[
	SessionService
	--------------
	Conteneur en mémoire de l'état d'un joueur pendant sa session :
	  data (sauvegardé), œufs posés, boutique, œuf porté, protection.

	Aucun accès réseau ici : c'est la couche modèle.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EggCatalog = require(Shared:WaitForChild("EggCatalog"))

local SessionService = {}

local byUserId: { [number]: any } = {}

local function newUid(session: any): string
	session._uidCounter += 1
	return string.format("%d_%d", session.userId, session._uidCounter)
end

--- Crée une session (données déjà chargées).
function SessionService.create(player: Player, data: any): any
	local session = {
		player = player,
		userId = player.UserId,
		name = player.Name,
		displayName = player.DisplayName,
		data = data,
		plot = nil,
		eggs = {},
		_uidCounter = 0,
		shop = {},
		shopRefreshAt = 0,
		carrying = nil,
		lockUntil = 0,
		lastLockAt = 0,
		lastStealAt = 0,
		joining = true,
	}

	byUserId[player.UserId] = session
	return session
end

function SessionService.destroy(player: Player)
	byUserId[player.UserId] = nil
end

function SessionService.get(player: Player): any
	return byUserId[player.UserId]
end

function SessionService.getById(userId: number): any
	return byUserId[userId]
end

function SessionService.all(): { any }
	local list = {}
	for _, session in pairs(byUserId) do
		table.insert(list, session)
	end
	return list
end

-- Argent -------------------------------------------------------------------

function SessionService.canAfford(session: any, amount: number): boolean
	return session.data.cash >= amount
end

function SessionService.spend(session: any, amount: number): boolean
	amount = math.max(0, math.floor(amount))
	if session.data.cash < amount then
		return false
	end
	session.data.cash -= amount
	return true
end

function SessionService.award(session: any, amount: number)
	if amount <= 0 then
		return
	end
	session.data.cash = math.min(Config.MaxCash, session.data.cash + amount)
	session.data.stats.earned += amount
end

-- Œufs ---------------------------------------------------------------------

--- Ajoute un œuf dans un socle libre (ou le socle demandé).
function SessionService.addEgg(session: any, eggId: string, level: number, slot: number?): any
	local def = EggCatalog.get(eggId)
	if not def then
		return nil
	end

	slot = slot or SessionService.firstFreeSlot(session)
	if not slot then
		return nil
	end
	if slot > session.data.slots or slot < 1 then
		return nil
	end
	if SessionService.eggAtSlot(session, slot) then
		return nil
	end

	local egg = {
		uid = newUid(session),
		eggId = eggId,
		level = math.clamp(level or 1, 1, Config.MaxEggLevel),
		slot = slot,
		def = def,
		model = nil,
	}
	session.eggs[egg.uid] = egg
	session.data.collect[eggId] = true
	return egg
end

function SessionService.removeEgg(session: any, uid: string): any
	local egg = session.eggs[uid]
	if not egg then
		return nil
	end
	session.eggs[uid] = nil
	return egg
end

function SessionService.getEgg(session: any, uid: string): any
	if type(uid) ~= "string" then
		return nil
	end
	return session.eggs[uid]
end

function SessionService.eggsSorted(session: any): { any }
	local list = {}
	for _, egg in pairs(session.eggs) do
		table.insert(list, egg)
	end
	table.sort(list, function(a, b)
		if a.slot == b.slot then
			return a.uid < b.uid
		end
		return a.slot < b.slot
	end)
	return list
end

function SessionService.countEggs(session: any): number
	local count = 0
	for _ in pairs(session.eggs) do
		count += 1
	end
	return count
end

function SessionService.eggAtSlot(session: any, slot: number): any
	for _, egg in pairs(session.eggs) do
		if egg.slot == slot then
			return egg
		end
	end
	return nil
end

function SessionService.firstFreeSlot(session: any): number?
	for slot = 1, session.data.slots do
		if not SessionService.eggAtSlot(session, slot) then
			return slot
		end
	end
	return nil
end

-- Revenus ------------------------------------------------------------------

function SessionService.income(session: any): number
	local total = 0
	for _, egg in pairs(session.eggs) do
		total += EggCatalog.incomeFor(egg.def, egg.level)
	end
	return total * SessionService.collectionBonus(session)
end

function SessionService.collectCount(session: any): number
	local count = 0
	for _ in pairs(session.data.collect) do
		count += 1
	end
	return count
end

function SessionService.collectionBonus(session: any): number
	return 1 + SessionService.collectCount(session) * Config.CollectionBonusPerEgg
end

--- Valeur de revente d'un œuf.
function SessionService.sellValue(egg: any): number
	return math.floor(egg.def.price * EggCatalog.levelMultiplier(egg.level) * Config.SellRefund)
end

-- Sauvegarde ---------------------------------------------------------------

--- Reconstruit la table persistée `data.eggs` depuis la session.
function SessionService.serializeEggs(session: any)
	local eggs = {}
	for _, egg in ipairs(SessionService.eggsSorted(session)) do
		table.insert(eggs, {
			eggId = egg.eggId,
			level = egg.level,
			slot = egg.slot,
		})
	end
	session.data.eggs = eggs
end

--- Recharge les œufs depuis `data.eggs` (au moment de l'arrivée du joueur).
function SessionService.hydrate(session: any)
	session.eggs = {}
	for _, entry in ipairs(session.data.eggs or {}) do
		local def = EggCatalog.get(entry.eggId)
		local slot = tonumber(entry.slot)
		if def and slot and slot >= 1 and slot <= session.data.slots and not SessionService.eggAtSlot(session, slot) then
			local egg = {
				uid = newUid(session),
				eggId = def.id,
				level = math.clamp(tonumber(entry.level) or 1, 1, Config.MaxEggLevel),
				slot = slot,
				def = def,
				model = nil,
			}
			session.eggs[egg.uid] = egg
			session.data.collect[def.id] = true
		end
	end
	SessionService.serializeEggs(session)
end

return SessionService
