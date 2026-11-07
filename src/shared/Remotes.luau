--!nonstrict
--[[
	Remotes
	-------
	Noms des RemoteEvents + helpers de récupération.
	Le dossier ReplicatedStorage/Remotes est créé par le serveur au démarrage.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.FolderName = "Remotes"

-- Client -> serveur : toutes les actions du joueur (achat, vol, fusion, ...)
Remotes.Action = "Action"
-- Serveur -> client : état complet du joueur
Remotes.State = "State"
-- Serveur -> client : mise à jour légère de l'argent / revenus
Remotes.StateCash = "StateCash"
-- Serveur -> client : toast de notification
Remotes.Notify = "Notify"
-- Serveur -> client : alerte (on te vole un œuf)
Remotes.Alert = "Alert"
-- Serveur -> client : ouvrir un panneau ("Shop" | "Egg" | "Help")
Remotes.Panel = "Panel"
-- Serveur -> tous : fil d'actualité (vols, ventes...)
Remotes.Feed = "Feed"
-- Serveur -> tous : classement (top joueurs)
Remotes.Board = "Board"

--- Crée le dossier des remotes et tous les events (serveur uniquement).
function Remotes.setupServer(): Folder
	local folder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = Remotes.FolderName

	for _, name in ipairs({
		Remotes.Action,
		Remotes.State,
		Remotes.StateCash,
		Remotes.Notify,
		Remotes.Alert,
		Remotes.Panel,
		Remotes.Feed,
		Remotes.Board,
	}) do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end

	folder.Parent = ReplicatedStorage
	return folder
end

--- Récupère un remote (attend qu'il existe, serveur ou client).
function Remotes.get(name: string): RemoteEvent
	local folder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if not folder then
		folder = ReplicatedStorage:WaitForChild(Remotes.FolderName, 30)
		if not folder then
			error("Dossier Remotes introuvable")
		end
	end
	return folder:WaitForChild(name, 30) :: RemoteEvent
end

return Remotes
