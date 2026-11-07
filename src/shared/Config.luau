--!nonstrict
--[[
	Config
	------
	Toutes les constantes de gameplay du jeu "Steal a Egg".
	Un seul endroit à modifier pour équilibrer le jeu.
]]

local Config = {}

Config.GameName = "STEAL A EGG"
Config.DataVersion = 3
Config.DataStoreName = "StealAnEgg_Data_v1"

-- Économie ---------------------------------------------------------------
Config.StartingCash = 150
Config.MaxCash = 1e15
Config.IncomeTick = 1 -- secondes
Config.SaveInterval = 90 -- secondes
Config.MaxEggLevel = 5
Config.LevelIncomeStep = 1.55 -- multiplicateur de revenu par niveau
Config.SellRefund = 0.6 -- % du prix de l'œuf rendu à la revente
Config.CollectionBonusPerEgg = 0.03 -- +3% de revenu par œuf unique collectionné
Config.StealBonusBase = 60
Config.StealBonusPercent = 0.05 -- +5% du prix de l'œuf volé

-- Base / parcelles --------------------------------------------------------
Config.PlotCount = 12
Config.StartSlots = 4
Config.MaxSlots = 8
Config.SlotUpgradeCost = {
	[5] = 3000,
	[6] = 20000,
	[7] = 150000,
	[8] = 1500000,
}

-- Boutique ----------------------------------------------------------------
Config.ShopSlotCount = 4
Config.ShopRefreshTime = 15
Config.ShopRerollCost = 250

-- Vol ---------------------------------------------------------------------
Config.CarryWalkSpeed = 11
Config.NormalWalkSpeed = 16
Config.StealRange = 16
Config.SecureRange = 22
Config.StealCooldown = 1.2
Config.DroppedEggLifetime = 45 -- secondes avant retour au propriétaire
Config.StealHoldDuration = 0.6
Config.LockDuration = 90
Config.LockCostBase = 400
Config.LockCostIncomeFactor = 25 -- coût = base + revenu/s * facteur
Config.LockCooldown = 5

-- Anti exploit ------------------------------------------------------------
Config.MaxEggsPerPlayer = 8
Config.ActionBurst = 12
Config.ActionPerSecond = 8
Config.MaxRemoteFlood = 60

-- Divers ------------------------------------------------------------------
Config.PlotSize = 34
Config.PlotRadius = 118
Config.GroundSize = 560
Config.CarryOffset = CFrame.new(0, 2.6, 0)
Config.LooseEggFolderName = "LooseEggs"

return Config
