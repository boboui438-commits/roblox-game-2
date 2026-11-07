--!nonstrict
-- Tests logiques (générés) : catalogue, économie, sessions.
local Config = __mod.Config
local Util = __mod.Util
local Catalog = __mod.EggCatalog
local Sessions = __mod.SessionService

local failures = 0
local checks = 0
local function check(condition, label)
	checks += 1
	if not condition then
		failures += 1
		print("ECHEC: " .. label)
	end
end

-- Catalogue ---------------------------------------------------------------
check(#Catalog.Eggs == 20, "20 oeufs")
check(#Catalog.Rarities == 8, "8 raretes")
local totalWeight = 0
for _, rarity in ipairs(Catalog.Rarities) do
	totalWeight += rarity.weight
	check(#Catalog.byRarity[rarity.id] > 0, "rarete non vide: " .. rarity.id)
end
check(math.abs(totalWeight - 97.88) < 0.001, "somme des poids = 97.88")

local ids = {}
for _, def in ipairs(Catalog.Eggs) do
	check(not ids[def.id], "id unique " .. def.id)
	ids[def.id] = true
	check(def.price > 0, "prix > 0 " .. def.id)
	check(def.income > 0, "revenu > 0 " .. def.id)
	check(Catalog.rarityById[def.rarity] ~= nil, "rarete connue " .. def.id)
	check(def.body:match("^#%x%x%x%x%x%x$") ~= nil, "couleur hex " .. def.id)
	local payback = def.price / def.income
	check(payback > 40 and payback < 80, ("payback %.0fs pour %s"):format(payback, def.id))
end

-- Formatage ---------------------------------------------------------------
check(Util.formatNumber(0) == "0", "format 0 -> " .. Util.formatNumber(0))
check(Util.formatNumber(999) == "999", "format 999 -> " .. Util.formatNumber(999))
check(Util.formatNumber(1000) == "1K", "format 1000 -> " .. Util.formatNumber(1000))
check(Util.formatNumber(1500) == "1.5K", "format 1500 -> " .. Util.formatNumber(1500))
check(Util.formatNumber(2500000) == "2.5M", "format 2.5M -> " .. Util.formatNumber(2500000))
check(Util.formatClock(75) == "1:15", "clock 75 -> " .. Util.formatClock(75))
check(Util.formatClock(9) == "9s", "clock 9 -> " .. Util.formatClock(9))
check(Util.trim("abcdef", 3) == "abc", "trim")

-- Niveaux ----------------------------------------------------------------
local dragon = Catalog.get("dragon")
check(math.abs(Catalog.incomeFor(dragon, 1) - 340) < 1e-9, "revenu niv1")
check(math.abs(Catalog.incomeFor(dragon, 2) - 340 * 1.55) < 1e-9, "revenu niv2")
check(math.abs(Catalog.levelMultiplier(99) - 1.55 ^ 4) < 1e-9, "niveau plafonne a 5")

-- Session ----------------------------------------------------------------
local fakePlayer = { UserId = 42, Name = "Test", DisplayName = "Test" }
local data = {
	cash = Config.StartingCash,
	slots = Config.StartSlots,
	eggs = {},
	collect = {},
	stats = { stolen = 0, lost = 0, earned = 0, sold = 0, merged = 0, best = 0 },
}
local session = Sessions.create(fakePlayer, data)
check(Sessions.income(session) == 0, "revenus initiaux nuls")

local egg1 = Sessions.addEgg(session, "poule", 1)
check(egg1 ~= nil and egg1.slot == 1, "premier oeuf socle 1")
local egg2 = Sessions.addEgg(session, "canard", 1, 3)
check(egg2 ~= nil and egg2.slot == 3, "placement socle 3")
check(Sessions.firstFreeSlot(session) == 2, "socle libre = 2")
check(Sessions.countEggs(session) == 2, "2 oeufs")
check(math.abs(Sessions.income(session) - (1 + 5.5) * 1.06) < 1e-9, "revenus + bonus collection 2 oeufs")
check(math.abs(Sessions.collectionBonus(session) - 1.06) < 1e-9, "bonus collection 6%")

check(Sessions.addEgg(session, "poule", 1, 7) == nil, "socle 7 verrouille refuse")
check(Sessions.addEgg(session, "poule", 1, 1) == nil, "socle occupe refuse")
check(Sessions.addEgg(session, "inconnu", 1) == nil, "oeuf inconnu refuse")

check(Sessions.sellValue(egg1) == math.floor(60 * 0.6), "valeur de revente niv1")
local egg3 = Sessions.addEgg(session, "poule", 3, 2)
check(Sessions.sellValue(egg3) == math.floor(60 * 1.55 * 1.55 * 0.6), "valeur de revente niv3")

Sessions.serializeEggs(session)
check(#data.eggs == 3, "3 oeufs serialises")

local session2 = Sessions.create({ UserId = 43, Name = "B", DisplayName = "B" }, {
	cash = 999,
	slots = Config.StartSlots,
	eggs = data.eggs,
	collect = {},
	stats = { stolen = 0, lost = 0, earned = 0, sold = 0, merged = 0, best = 0 },
})
Sessions.hydrate(session2)
check(Sessions.countEggs(session2) == 3, "hydratation 3 oeufs")
check(Sessions.getEgg(session2, "faux_uid") == nil, "uid invalide ignore")
local usedSlots = {}
for _, egg in pairs(session2.eggs) do
	check(not usedSlots[egg.slot], "slots uniques apres hydratation")
	usedSlots[egg.slot] = true
end
check(Sessions.income(session2) > 0, "revenus apres hydratation")

check(Sessions.spend(session, 100) == true, "depense valide")
check(Sessions.canAfford(session, 10) == true, "solvable")
check(Sessions.spend(session, 1e12) == false, "depense impossible refusee")
Sessions.award(session, 5)
check(session.data.stats.earned >= 5, "gain trace dans les stats")
Sessions.award(session, 1e18)
check(session.data.cash <= Config.MaxCash, "argent plafonne")

print(("\n%d verifications, %d echec(s)"):format(checks, failures))
if failures > 0 then
	error("tests en echec")
end
