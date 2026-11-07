--!nonstrict
--[[
	EggCatalog
	----------
	Catalogue de tous les œufs + raretés.

	Chaque œuf :
		id      : identifiant stable (sauvegarde) - ne jamais renommer
		name    : nom affiché
		rarity  : clé de rareté
		price   : prix boutique (aussi base de la valeur de revente)
		income  : revenus par seconde au niveau 1
		body    : couleur de la coquille (hex)
		accent  : couleur du socle / accessoire (hex)
		style   : "plain" | "ring" | "spikes" | "halo" | "aura" | "crown" | "crack"
		scale   : taille relative du modèle
]]

local Config = require(script.Parent.Config)

local EggCatalog = {}

EggCatalog.Rarities = {
	{
		id = "commun",
		name = "Commun",
		weight = 40,
		color = "#A9B7C4",
		glow = "#D6E2EC",
		order = 1,
	},
	{
		id = "peu_commun",
		name = "Peu commun",
		weight = 26,
		color = "#7ED9A7",
		glow = "#B6F5D2",
		order = 2,
	},
	{
		id = "rare",
		name = "Rare",
		weight = 16,
		color = "#63B8FF",
		glow = "#A8D9FF",
		order = 3,
	},
	{
		id = "epique",
		name = "Épique",
		weight = 9,
		color = "#B07CFF",
		glow = "#DBC2FF",
		order = 4,
	},
	{
		id = "legendaire",
		name = "Légendaire",
		weight = 4.5,
		color = "#FFC24A",
		glow = "#FFE3A3",
		order = 5,
	},
	{
		id = "mythique",
		name = "Mythique",
		weight = 1.8,
		color = "#FF7B54",
		glow = "#FFB396",
		order = 6,
	},
	{
		id = "divin",
		name = "Divin",
		weight = 0.5,
		color = "#FF6BD5",
		glow = "#FFB3EC",
		order = 7,
	},
	{
		id = "secret",
		name = "SECRET",
		weight = 0.08,
		color = "#35F5D0",
		glow = "#A6FFF1",
		order = 8,
	},
}

EggCatalog.Eggs = {
	-- COMMUN ---------------------------------------------------------------
	{
		id = "poule",
		name = "Œuf de Poule",
		rarity = "commun",
		price = 60,
		income = 1,
		body = "#F5EBD8",
		accent = "#D8C6A5",
		style = "plain",
		scale = 0.9,
	},
	{
		id = "tachete",
		name = "Œuf Tacheté",
		rarity = "commun",
		price = 140,
		income = 2.4,
		body = "#EADFC8",
		accent = "#8B6B4A",
		style = "crack",
		scale = 0.9,
	},
	{
		id = "canard",
		name = "Œuf de Canard",
		rarity = "commun",
		price = 340,
		income = 5.5,
		body = "#DFF3FF",
		accent = "#8FC3E8",
		style = "plain",
		scale = 0.95,
	},
	-- PEU COMMUN -----------------------------------------------------------
	{
		id = "grenouille",
		name = "Œuf de Grenouille",
		rarity = "peu_commun",
		price = 560,
		income = 9,
		body = "#B6F5C8",
		accent = "#3FA36B",
		style = "ring",
		scale = 0.95,
	},
	{
		id = "escargot",
		name = "Œuf d'Escargot",
		rarity = "peu_commun",
		price = 950,
		income = 16,
		body = "#FFE7B8",
		accent = "#C98E4A",
		style = "ring",
		scale = 1,
	},
	{
		id = "pingouin",
		name = "Œuf de Pingouin",
		rarity = "peu_commun",
		price = 1600,
		income = 27,
		body = "#D8ECFF",
		accent = "#3B5C7A",
		style = "crack",
		scale = 1,
	},
	-- RARE -----------------------------------------------------------------
	{
		id = "renard",
		name = "Œuf de Renard",
		rarity = "rare",
		price = 3200,
		income = 60,
		body = "#FFD9A8",
		accent = "#E2762F",
		style = "ring",
		scale = 1.05,
	},
	{
		id = "panda",
		name = "Œuf de Panda",
		rarity = "rare",
		price = 5200,
		income = 95,
		body = "#F7F7F7",
		accent = "#2B2B2B",
		style = "crack",
		scale = 1.05,
	},
	{
		id = "poulpe",
		name = "Œuf de Poulpe",
		rarity = "rare",
		price = 7800,
		income = 140,
		body = "#FFC4E1",
		accent = "#C4388C",
		style = "ring",
		scale = 1.05,
	},
	-- ÉPIQUE ---------------------------------------------------------------
	{
		id = "dragon",
		name = "Œuf de Dragon",
		rarity = "epique",
		price = 18000,
		income = 340,
		body = "#8CF06A",
		accent = "#2F7D2A",
		style = "spikes",
		scale = 1.1,
	},
	{
		id = "licorne",
		name = "Œuf de Licorne",
		rarity = "epique",
		price = 26000,
		income = 490,
		body = "#FFD7F5",
		accent = "#A24EDB",
		style = "halo",
		scale = 1.1,
	},
	{
		id = "neant",
		name = "Œuf du Néant",
		rarity = "epique",
		price = 40000,
		income = 760,
		body = "#3A3350",
		accent = "#9D6BFF",
		style = "aura",
		scale = 1.1,
	},
	-- LÉGENDAIRE -----------------------------------------------------------
	{
		id = "phenix",
		name = "Œuf de Phénix",
		rarity = "legendaire",
		price = 120000,
		income = 2300,
		body = "#FFB347",
		accent = "#FF4D00",
		style = "aura",
		scale = 1.15,
	},
	{
		id = "kraken",
		name = "Œuf du Kraken",
		rarity = "legendaire",
		price = 180000,
		income = 3500,
		body = "#1E6E8C",
		accent = "#5FE0FF",
		style = "ring",
		scale = 1.15,
	},
	{
		id = "astro",
		name = "Œuf d'Astronaute",
		rarity = "legendaire",
		price = 260000,
		income = 5000,
		body = "#E8EEFF",
		accent = "#4A6BFF",
		style = "halo",
		scale = 1.15,
	},
	-- MYTHIQUE -------------------------------------------------------------
	{
		id = "cosmique",
		name = "Œuf Cosmique",
		rarity = "mythique",
		price = 700000,
		income = 13500,
		body = "#2A1B4A",
		accent = "#C77DFF",
		style = "aura",
		scale = 1.2,
	},
	{
		id = "trounoir",
		name = "Œuf de Trou Noir",
		rarity = "mythique",
		price = 1100000,
		income = 21000,
		body = "#100C18",
		accent = "#FF8A3D",
		style = "aura",
		scale = 1.2,
	},
	-- DIVIN ----------------------------------------------------------------
	{
		id = "divin",
		name = "Œuf Divin",
		rarity = "divin",
		price = 3500000,
		income = 65000,
		body = "#FFF6C4",
		accent = "#FFD447",
		style = "crown",
		scale = 1.25,
	},
	{
		id = "temps",
		name = "Œuf du Temps",
		rarity = "divin",
		price = 6000000,
		income = 115000,
		body = "#BFF7FF",
		accent = "#3AC7E8",
		style = "halo",
		scale = 1.25,
	},
	-- SECRET ---------------------------------------------------------------
	{
		id = "createur",
		name = "Œuf du Créateur",
		rarity = "secret",
		price = 25000000,
		income = 480000,
		body = "#FFFFFF",
		accent = "#FF4FD8",
		style = "crown",
		scale = 1.35,
	},
}

-- Index ------------------------------------------------------------------
EggCatalog.byId = {}
EggCatalog.byRarity = {}

for _, def in ipairs(EggCatalog.Eggs) do
	assert(EggCatalog.byId[def.id] == nil, "Egg id dupliqué: " .. def.id)
	EggCatalog.byId[def.id] = def
	EggCatalog.byRarity[def.rarity] = EggCatalog.byRarity[def.rarity] or {}
	table.insert(EggCatalog.byRarity[def.rarity], def)
end

EggCatalog.rarityById = {}
for _, rarity in ipairs(EggCatalog.Rarities) do
	EggCatalog.rarityById[rarity.id] = rarity
end

function EggCatalog.get(id: string)
	return EggCatalog.byId[id]
end

function EggCatalog.getRarity(id: string)
	local def = EggCatalog.byId[id]
	if not def then
		return EggCatalog.rarityById["commun"]
	end
	return EggCatalog.rarityById[def.rarity] or EggCatalog.rarityById["commun"]
end

function EggCatalog.rarityColor(id: string): Color3
	return Color3.fromHex(EggCatalog.getRarity(id).color)
end

function EggCatalog.rarityGlow(id: string): Color3
	return Color3.fromHex(EggCatalog.getRarity(id).glow)
end

function EggCatalog.levelMultiplier(level: number): number
	level = math.clamp(level or 1, 1, Config.MaxEggLevel)
	return Config.LevelIncomeStep ^ (level - 1)
end

function EggCatalog.incomeFor(def, level: number): number
	return def.income * EggCatalog.levelMultiplier(level)
end

function EggCatalog.totalUnique(): number
	return #EggCatalog.Eggs
end

return EggCatalog
