--!nonstrict
--[[
	ShopService
	-----------
	Boutique d'œufs : 4 emplacements par joueur, rareté tirée au sort selon
	les poids du catalogue, rafraîchissement automatique, relance payante.

	Les achats sont validés côté serveur (argent + socle libre + distance).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EggCatalog = require(Shared:WaitForChild("EggCatalog"))
local Util = require(Shared:WaitForChild("Util"))

local SessionService = require(script.Parent.SessionService)
local EggService = require(script.Parent.EggService)
local SyncService = require(script.Parent.SyncService)
local NotifyService = require(script.Parent.NotifyService)

local ShopService = {}

local world: any = nil
local KIOSK_RANGE = 52

local function pickEgg(): any
	local rarity = Util.weightedPick(EggCatalog.Rarities, function(entry)
		return entry.weight
	end)
	local eggs = EggCatalog.byRarity[rarity.id]
	if not eggs or #eggs == 0 then
		eggs = EggCatalog.byRarity["commun"]
	end
	local def = Util.randomChoice(eggs)
	return def
end

--- Retire un emplacement et le remplit avec un nouvel œuf.
local function rollSlot(session: any, index: number)
	local def = pickEgg()
	session.shop[index] = { eggId = def.id }
end

--- Tire les 4 emplacements de la boutique.
function ShopService.roll(session: any)
	session.shop = {}
	for index = 1, Config.ShopSlotCount do
		rollSlot(session, index)
	end
	session.shopRefreshAt = os.clock() + Config.ShopRefreshTime
end

--- Tire la boutique si nécessaire.
function ShopService.ensureRolled(session: any)
	if not session.shop or #session.shop == 0 or session.shopRefreshAt <= 0 then
		ShopService.roll(session)
	end
end

local function nearKiosk(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not world then
		return false
	end
	return (root.Position - world.center).Magnitude <= KIOSK_RANGE
end

--- Le joueur ouvre la boutique (prompt du kiosque).
function ShopService.open(player: Player)
	local session = SessionService.get(player)
	if not session then
		return
	end
	ShopService.ensureRolled(session)
	SyncService.push(session)
	NotifyService.openPanel(player, "Shop")
end

--- Achat d'un œuf de la boutique.
function ShopService.buy(player: Player, index: number)
	local session = SessionService.get(player)
	if not session then
		return
	end
	if not Util.isSafeInteger(index) or index < 1 or index > Config.ShopSlotCount then
		return
	end
	if not nearKiosk(player) then
		NotifyService.notify(player, "Va au kiosque central pour acheter !", "error")
		return
	end

	ShopService.ensureRolled(session)
	local entry = session.shop[index]
	if not entry then
		NotifyService.notify(player, "Cet emplacement est vide.", "error")
		return
	end

	local def = EggCatalog.get(entry.eggId)
	if not def then
		return
	end

	if not session.plot then
		NotifyService.notify(player, "Attends d'avoir une parcelle libre pour acheter.", "error")
		return
	end
	if not SessionService.firstFreeSlot(session) then
		NotifyService.notify(player, "Plus de socle libre ! Agrandis ta base.", "error")
		return
	end
	if not SessionService.canAfford(session, def.price) then
		NotifyService.notify(
			player,
			("Il te manque $%s"):format(Util.formatNumber(def.price - session.data.cash)),
			"error"
		)
		return
	end

	SessionService.spend(session, def.price)
	local egg, err = EggService.addEgg(session, def.id, 1)
	if not egg then
		SessionService.award(session, def.price)
		NotifyService.notify(player, err or "Achat impossible.", "error")
		return
	end

	rollSlot(session, index)
	SyncService.push(session)
	SyncService.pushCash(session)
	SyncService.refreshPlotSign(session)
	NotifyService.notify(player, ("%s acheté ! +%s/s"):format(def.name, Util.formatNumber(def.income)), "success")

	local rarity = EggCatalog.rarityById[def.rarity]
	if rarity and rarity.order >= 5 then
		NotifyService.feed(
			("%s a obtenu un %s (%s) !"):format(session.displayName, def.name, rarity.name),
			"rare"
		)
	end
end

--- Relance payante de la boutique.
function ShopService.reroll(player: Player)
	local session = SessionService.get(player)
	if not session then
		return
	end
	if not SessionService.canAfford(session, Config.ShopRerollCost) then
		NotifyService.notify(
			player,
			("Relance à $%s"):format(Util.formatNumber(Config.ShopRerollCost)),
			"error"
		)
		return
	end
	SessionService.spend(session, Config.ShopRerollCost)
	ShopService.roll(session)
	SyncService.push(session)
	SyncService.pushCash(session)
	NotifyService.notify(player, "Boutique relancée !", "info")
end

function ShopService.init(builtWorld: any)
	world = builtWorld

	if world.shopPrompt then
		world.shopPrompt.Triggered:Connect(function(player)
			ShopService.open(player)
		end)
	end

	-- Rafraîchissement automatique
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for _, session in ipairs(SessionService.all()) do
				if session.shopRefreshAt > 0 and now >= session.shopRefreshAt then
					ShopService.roll(session)
					if session.player.Parent then
						SyncService.push(session)
					end
				end
			end
		end
	end)
end

return ShopService
