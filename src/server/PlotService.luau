--!nonstrict
--[[
	PlotService
	-----------
	Gère l'attribution des parcelles (une par joueur) et leur état visuel.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MapBuilder = require(script.Parent.MapBuilder)

local PlotService = {}

local world: any = nil
local plotByUserId: { [number]: any } = {}

function PlotService.init(builtWorld: any)
	world = builtWorld
	table.clear(plotByUserId)

	for _, plot in ipairs(world.plots) do
		plot.ownerUserId = nil
		MapBuilder.setPlotSign(plot, "Parcelle libre", "En attente d'un joueur...")
		MapBuilder.setPlotLock(plot, "", false)
		for slotIndex = 1, Config.MaxSlots do
			local price = Config.SlotUpgradeCost[slotIndex]
			MapBuilder.setSlotUnlocked(plot, slotIndex, slotIndex <= Config.StartSlots, price)
		end
	end
end

function PlotService.getWorld(): any
	return world
end

function PlotService.getPlot(index: number): any
	if not world then
		return nil
	end
	return world.plots[index]
end

function PlotService.getPlotOf(userId: number): any
	local index = plotByUserId[userId]
	if not index then
		return nil
	end
	return world and world.plots[index]
end

function PlotService.freeCount(): number
	local count = 0
	for _, plot in ipairs(world.plots) do
		if not plot.ownerUserId then
			count += 1
		end
	end
	return count
end

--- Attribue une parcelle libre au joueur (nil si complet).
function PlotService.claim(player: Player): any
	local existing = PlotService.getPlotOf(player.UserId)
	if existing then
		existing.ownerUserId = player.UserId
		return existing
	end

	for _, plot in ipairs(world.plots) do
		if not plot.ownerUserId then
			plot.ownerUserId = player.UserId
			plotByUserId[player.UserId] = plot.index
			MapBuilder.setPlotSign(plot, player.DisplayName, "Revenus : $0/s")
			return plot
		end
	end

	return nil
end

--- Libère la parcelle du joueur.
function PlotService.release(player: Player, displayName: string?)
	local plot = PlotService.getPlotOf(player.UserId)
	if not plot then
		return
	end
	plotByUserId[player.UserId] = nil
	plot.ownerUserId = nil
	MapBuilder.setPlotSign(plot, "Parcelle libre", displayName and ("Libérée par " .. displayName) or "Disponible")
	MapBuilder.setPlotLock(plot, "", false)
end

function PlotService.setSign(plot: any, title: string, subtitle: string)
	MapBuilder.setPlotSign(plot, title, subtitle)
end

function PlotService.setLock(plot: any, lockedUntil: number)
	if lockedUntil > os.clock() then
		local remaining = math.ceil(lockedUntil - os.clock())
		MapBuilder.setPlotLock(plot, "PROTÉGÉE · " .. remaining .. "s", true)
	else
		MapBuilder.setPlotLock(plot, "", false)
	end
end

function PlotService.announceLock(plot: any, lockedUntil: number)
	if lockedUntil > os.clock() then
		MapBuilder.setPlotLock(plot, "PROTÉGÉE", true)
	else
		MapBuilder.setPlotLock(plot, "", false)
	end
end

return PlotService
