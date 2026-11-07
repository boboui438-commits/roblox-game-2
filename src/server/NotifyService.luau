--!nonstrict
--[[
	NotifyService
	-------------
	Toasts joueur, alertes et fil d'actualité global.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local NotifyService = {}

local notifyRemote: RemoteEvent? = nil
local alertRemote: RemoteEvent? = nil
local feedRemote: RemoteEvent? = nil
local panelRemote: RemoteEvent? = nil

function NotifyService.init()
	notifyRemote = Remotes.get(Remotes.Notify)
	alertRemote = Remotes.get(Remotes.Alert)
	feedRemote = Remotes.get(Remotes.Feed)
	panelRemote = Remotes.get(Remotes.Panel)
end

-- Types de toast : "info" | "success" | "error" | "reward" | "danger"
function NotifyService.notify(player: Player, text: string, kind: string?, duration: number?)
	if not notifyRemote or not player.Parent then
		return
	end
	notifyRemote:FireClient(player, {
		text = Util.trim(text, 140),
		kind = kind or "info",
		duration = duration or 3.5,
	})
end

function NotifyService.alert(player: Player, text: string)
	if not alertRemote or not player.Parent then
		return
	end
	alertRemote:FireClient(player, {
		text = Util.trim(text, 140),
	})
end

function NotifyService.feed(text: string, kind: string?)
	if not feedRemote then
		return
	end
	feedRemote:FireAllClients({
		text = Util.trim(text, 160),
		kind = kind or "info",
	})
end

function NotifyService.openPanel(player: Player, panel: string, payload: any?)
	if not panelRemote or not player.Parent then
		return
	end
	panelRemote:FireClient(player, panel, payload)
end

return NotifyService
