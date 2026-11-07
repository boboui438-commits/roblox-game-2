--!nonstrict
--[[
	DataService
	-----------
	Sauvegarde / chargement des données joueur avec DataStore.

	- Verrou de session (session locking) pour éviter les doublons entre serveurs.
	- Nettoyage agressif des données (anti corruption / anti injection).
	- Fonctionne en mode "mémoire" si les DataStores sont indisponibles
	  (Studio sans API Services, par exemple) : le jeu reste jouable.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EggCatalog = require(Shared:WaitForChild("EggCatalog"))

local DataService = {}

local SESSION_TIMEOUT = 90 -- secondes avant de considérer un verrou comme périmé
local MAX_RETRIES = 4
local SESSION_ID = HttpService:GenerateGUID(false)

local store: DataStore? = nil
local storeReady = false

DataService.online = false

local function keyFor(userId: number): string
	return "player_" .. tostring(userId)
end

local function initStore()
	if storeReady then
		return store
	end
	storeReady = true
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
		DataService.online = true
	else
		warn("[DataService] DataStore indisponible, mode mémoire:", result)
		store = nil
	end
	return store
end

--- Données par défaut d'un nouveau joueur.
function DataService.defaultData(): any
	return {
		version = Config.DataVersion,
		cash = Config.StartingCash,
		slots = Config.StartSlots,
		eggs = {},
		collect = {},
		stats = {
			stolen = 0,
			lost = 0,
			earned = 0,
			sold = 0,
			merged = 0,
			best = 0,
		},
		lastSeen = os.time(),
	}
end

local function sanitizeStats(raw: any): any
	local stats = {
		stolen = 0,
		lost = 0,
		earned = 0,
		sold = 0,
		merged = 0,
		best = 0,
	}
	if type(raw) == "table" then
		for key in pairs(stats) do
			local value = raw[key]
			if type(value) == "number" and value == value and value > 0 and value < 1e15 then
				stats[key] = math.floor(value)
			end
		end
	end
	return stats
end

--- Valide et répare les données lues (ou reçues) avant usage.
function DataService.sanitize(raw: any): any
	local data = DataService.defaultData()
	if type(raw) ~= "table" then
		return data
	end

	local cash = raw.cash
	if type(cash) == "number" and cash == cash and cash >= 0 then
		data.cash = math.floor(math.min(cash, Config.MaxCash))
	end

	local slots = raw.slots
	if type(slots) == "number" and slots == slots then
		data.slots = math.clamp(math.floor(slots), Config.StartSlots, Config.MaxSlots)
	end

	-- Œufs ---------------------------------------------------------------
	local usedSlots = {}
	local seenUid = {}
	if type(raw.eggs) == "table" then
		for _, entry in ipairs(raw.eggs) do
			if type(entry) == "table" and #data.eggs < Config.MaxEggsPerPlayer then
				local def = type(entry.eggId) == "string" and EggCatalog.get(entry.eggId) or nil
				local level = tonumber(entry.level)
				local slot = tonumber(entry.slot)
				if def and level and slot and level >= 1 and level <= Config.MaxEggLevel then
					level = math.floor(level)
					slot = math.floor(slot)
					if slot >= 1 and slot <= data.slots and not usedSlots[slot] then
						usedSlots[slot] = true
						table.insert(data.eggs, {
							eggId = def.id,
							level = level,
							slot = slot,
						})
					end
				end
			end
		end
	end

	-- Collection ----------------------------------------------------------
	if type(raw.collect) == "table" then
		for eggId, value in pairs(raw.collect) do
			if type(eggId) == "string" and value == true and EggCatalog.get(eggId) then
				data.collect[eggId] = true
			end
		end
	end
	for _, entry in ipairs(data.eggs) do
		data.collect[entry.eggId] = true
	end

	data.stats = sanitizeStats(raw.stats)
	data.version = Config.DataVersion
	data.lastSeen = os.time()
	return data
end

local function deepCopyTable(source: any): any
	if type(source) ~= "table" then
		return source
	end
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = deepCopyTable(value)
	end
	return copy
end

--- Charge les données d'un joueur. Retourne (data, erreur|nil).
function DataService.load(userId: number): (any, string?)
	local db = initStore()
	if not db then
		return DataService.defaultData(), "mode mémoire"
	end

	local lastError = "inconnue"
	for attempt = 1, MAX_RETRIES do
		local key = keyFor(userId)
		local ok, result = pcall(function()
			return db:UpdateAsync(key, function(old)
				old = type(old) == "table" and old or {}
				local lock = old.lock
				local now = os.time()
				if
					type(lock) == "table"
					and lock.session ~= SESSION_ID
					and type(lock.time) == "number"
					and (now - lock.time) < SESSION_TIMEOUT
				then
					return nil -- verrouillé par un autre serveur
				end
				return {
					data = old.data,
					lock = { session = SESSION_ID, time = now },
				}
			end)
		end)

		if ok then
			if result == nil then
				lastError = "session déjà verrouillée"
			else
				return DataService.sanitize(result.data), nil
			end
		else
			lastError = tostring(result)
			warn(("[DataService] chargement %d échoué (essai %d): %s"):format(userId, attempt, lastError))
		end
		task.wait(1.5 * attempt)
	end

	return DataService.defaultData(), lastError
end

--- Sauvegarde les données d'un joueur. Retourne (ok, erreur|nil).
function DataService.save(userId: number, data: any): (boolean, string?)
	local db = initStore()
	if not db then
		return false, "mode mémoire"
	end

	local payload = deepCopyTable(DataService.sanitize(data))
	local key = keyFor(userId)

	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(function()
			return db:UpdateAsync(key, function(old)
				old = type(old) == "table" and old or {}
				local lock = old.lock
				if type(lock) == "table" and lock.session ~= SESSION_ID then
					-- Un autre serveur a repris la session : on n'écrase rien.
					return nil
				end
				return {
					data = payload,
					lock = { session = SESSION_ID, time = os.time() },
				}
			end)
		end)

		if ok then
			return true, nil
		end
		warn(("[DataService] sauvegarde %d échouée (essai %d): %s"):format(userId, attempt, tostring(result)))
		task.wait(1.5 * attempt)
	end

	return false, "échec de sauvegarde"
end

--- Libère le verrou de session (à appeler après la sauvegarde de départ).
function DataService.release(userId: number)
	local db = initStore()
	if not db then
		return
	end
	local key = keyFor(userId)
	pcall(function()
		db:UpdateAsync(key, function(old)
			if type(old) ~= "table" then
				return nil
			end
			if type(old.lock) == "table" and old.lock.session == SESSION_ID then
				return { data = old.data }
			end
			return nil
		end)
	end)
end

return DataService
