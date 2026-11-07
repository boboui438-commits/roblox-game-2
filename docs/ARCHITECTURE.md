# Architecture technique

## Vue d'ensemble

Le projet est un jeu Roblox **Rojo / Luau** : le dossier `src/` est la source de
vérité, Roblox Studio n'est qu'un client d'exécution. Aucun asset externe n'est
nécessaire — la map, les œufs et toute l'interface sont générés en code.

```
.
├── default.project.json      # mapping Rojo (DataModel <-> src/)
├── rokit.toml                # rojo, stylua, selene, luau-lsp
├── selene.toml / stylua.toml # qualité de code
├── .github/workflows/ci.yml  # build .rbxlx + vérification syntaxe Luau
├── docs/
│   ├── ARCHITECTURE.md
│   └── GAMEPLAY.md
└── src/
    ├── shared/               -> ReplicatedStorage.Shared (ModuleScripts)
    │   ├── Config.luau
    │   ├── EggCatalog.luau
    │   ├── Remotes.luau
    │   └── Util.luau
    ├── server/               -> ServerScriptService.Server
    │   ├── Main.server.luau
    │   ├── DataService.luau
    │   ├── SessionService.luau
    │   ├── PlotService.luau
    │   ├── MapBuilder.luau
    │   ├── SceneService.luau
    │   ├── EggFactory.luau
    │   ├── EggService.luau
    │   ├── StealService.luau
    │   ├── ShopService.luau
    │   ├── SyncService.luau
    │   ├── NotifyService.luau
    │   └── NetService.luau
    └── client/               -> StarterPlayer.StarterPlayerScripts.Client
        ├── Main.client.luau
        ├── Theme.luau
        ├── UiKit.luau
        ├── Hud.luau
        ├── ShopPanel.luau
        ├── EggPanel.luau
        ├── CarryUi.luau
        ├── Toast.luau
        ├── PromptFilter.luau
        └── EggAnimator.luau
```

## Démarrage serveur (`Main.server.luau`)

Ordre imposé par les dépendances :

```
Remotes.setupServer()   -- crée ReplicatedStorage/Remotes
NotifyService.init()    -- récupère les RemoteEvents
SyncService.init()      -- récupère State / StateCash / Board
SceneService.init()     -- lumière, atmosphère, bloom
MapBuilder.build()      -- sol, kiosque, 12 parcelles, décor
PlotService.init(world) -- attribue/remet à zéro les parcelles
EggService.setHandlers()-- branche les prompts sur StealService
EggService.init()       -- socles, prompts, boucle de revenus
StealService.init()     -- dossier des œufs libres, boucle d'entretien
ShopService.init(world) -- prompt du kiosque, refresh des boutiques
NetService.init()       -- réception des actions client
```

Puis : `PlayerAdded` / `PlayerRemoving`, sauvegarde automatique (90 s),
classement (5 s) et `BindToClose` (sauvegarde de tous les joueurs).

### Cycle de vie d'un joueur

1. `DataService.load(userId)` — lecture DataStore + **verrou de session**
   (`UpdateAsync` avec un `sessionId` unique par serveur).
2. `SessionService.create/hydrate` — état mémoire (`data`, `eggs`, `shop`).
3. `PlotService.claim` — parcelle libre, sinon **file d'attente** (le joueur
   reste dans le jeu et reçoit une parcelle dès qu'une se libère).
4. `EggService.rebuild` — recrée les modèles d'œufs sauvegardés.
5. `LoadCharacter()` + téléportation sur la parcelle (`PivotTo`).
6. Départ : `StealService.onPlayerLeaving` (lâche l'œuf porté), sauvegarde,
   libération du verrou, nettoyage de la parcelle, attribution au suivant.

## Modèle de données

Session (mémoire uniquement) :

```lua
session = {
  player, userId, name, displayName,
  data = {                     -- persisté
    version, cash, slots,
    eggs = { { eggId, level, slot } },
    collect = { [eggId] = true },
    stats = { stolen, lost, earned, sold, merged, best },
    lastSeen,
  },
  eggs = { [uid] = { uid, eggId, level, slot, def, model } },
  shop = { { eggId }, ... },   -- 4 emplacements
  shopRefreshAt, lockUntil, lastLockAt, lastStealAt,
  carrying = egg | nil,
  plot = plot | nil,
}
```

Les `uid` sont **régénérés** à chaque session (jamais persistés) : aucune
collision possible et aucune confiance dans les identifiants client.

## Réseau

| Remote | Sens | Contenu |
| --- | --- | --- |
| `Action` | client → serveur | `(actionName: string, payload)` |
| `State` | serveur → client | snapshot complet de la session |
| `StateCash` | serveur → client | `{ cash, income, bonus }` (1×/s) |
| `Notify` | serveur → client | `{ text, kind, duration }` |
| `Alert` | serveur → client | `{ text }` (vol en cours) |
| `Panel` | serveur → client | `("Shop" \| "Egg", payload)` |
| `Feed` | serveur → tous | fil d'actualité |
| `Board` | serveur → tous | top 5 (argent, vols) |

Actions acceptées (`NetService`) : `Ready`, `OpenShop`, `Buy`, `Reroll`,
`BuySlot`, `Merge`, `Sell`, `Drop`, `Lock`, `Secure`.

Chaque action a :
* une validation de type stricte (`Util.isSafeInteger`, `isUid`, taille de table) ;
* un **token bucket** (`Config.ActionBurst` / `Config.ActionPerSecond`) ;
* un compteur de requêtes invalides (kick au-delà de `Config.MaxRemoteFlood`) ;
* une re-validation de l'état serveur (propriétaire, distance, argent, cooldown).

## Flux d'un vol

```
Prompt "Voler" (serveur)
  └─ StealService.requestSteal(player, uid, ownerId)
       ├─ validateSteal : vie, distance < 16, pas de portage, base non protégée,
       │                  cooldown, propriétaire réel
       ├─ SessionService.removeEgg(victime)          -- revenus stoppés
       ├─ StealService.beginCarry :
       │    prompts détruits, pièces dé-soudées du socle, soudées au HumanoidRootPart,
       │    vitesse 11 / saut 0, modèle déplacé dans Workspace.LooseEggs
       ├─ alerte victime + feed + sync des deux joueurs
       └─ échec éventuel → l'œuf est remis en place (aucune perte)
```

Sécurisation :

```
Prompt "Sécuriser" (socle de sa base)
  └─ StealService.secureAtSlot(player, plot, slot)
       ├─ vérifie : portage en cours, socle débloqué + libre, distance < 22
       ├─ SessionService.addEgg(session, eggId, niveau, slot)  -- nouveau uid
       ├─ réutilise le modèle porté (EggService.adoptModel)     -- zéro "pop"
       ├─ +prime de vol, stats (stolen/lost), collection, feed, effets
       └─ SyncService.push + refresh du panneau de parcelle
```

Mort / départ / lâcher → `dropToWorld` : l'œuf est ancré au sol, marqué
`Free`, doté d'un prompt « Récupérer », et possède une échéance
(`freeUntil`) au terme de laquelle il retourne chez son propriétaire s'il a un
socle libre.

## Prompts : pourquoi sur le serveur ?

Les `ProximityPrompt` sont créés **côté serveur** afin que `PromptTriggered`
soit reçu par le serveur (et non par le client). Pour autant, l'affichage doit
dépendre du joueur (Voler vs Gérer, Sécuriser seulement en portant un œuf…).
Solution retenue :

* le serveur crée les prompts une seule fois et **ne touche plus** à `Enabled` ;
* `PromptFilter` (client) active/désactive localement le bon prompt selon
  l'état synchronisé ;
* toute action reste de toute façon revalidée côté serveur — le filtrage
  client n'est qu'esthétique.

## Interface

`screenGui` (ResetOnSpawn = false) → `Root` (Frame plein écran) :

* `Hud` : carte argent animée, revenus, collection, stats, classement,
  boutons, alerte plein écran, aide, splash d'ouverture ;
* `ShopPanel` : 4 cartes, timer, relance, achat (distance kiosque requise) ;
* `EggPanel` : fusion / vente de l'œuf sélectionné ;
* `CarryUi` : bandeau de portage, distance, flèche directionnelle vers la base,
  bouton « Lâcher » ;
* `Toast` : notifications + fil d'actualité ;
* `EggAnimator` : flottement/rotation des œufs proches (≤ 10, 20 Hz).

Le placement est responsive : les modales se dimensionnent d'après
`Camera.ViewportSize`, le HUD utilise des offsets compacts compatibles mobile.

## Map générée

`MapBuilder` place 12 parcelles sur un cercle de rayon 118, orientées vers le
centre. Chaque parcelle contient :

* sol 36×36, liseré néon, clôtures sur 3 côtés (ouverture vers le centre) ;
* 8 socles (2 colonnes × 4 rangées) avec anneau lumineux et point d'ancrage ;
* un panneau `SurfaceGui` (nom du joueur + revenus + état de protection) ;
* une zone de spawn aux pieds du joueur.

Le centre accueille un kiosque cylindrique avec un gros œuf néon, le prompt de
boutique et un panneau titre. Les arbres/rochers sont générés avec une graine
fixe (`Random.new(2024)`) pour un rendu déterministe.

## Sauvegarde

* Clé DataStore : `player_<userId>` dans `StealAnEgg_Data_v1`.
* Écriture via `UpdateAsync` avec verrou `{ session, time }` (90 s de péremption).
* `DataService.sanitize` valide **tout** ce qui est relu : ids d'œufs connus,
  niveaux 1–5, socles uniques, plafonds d'argent, stats entières.
* Sauvegarde : au départ, toutes les 90 s, et à la fermeture du serveur.
* Si les DataStores sont indisponibles (Studio sans API Services), le jeu passe
  automatiquement en **mode mémoire** (jouable, non persisté) et l'annonce au
  joueur.

## Points d'extension

| Besoin | Où intervenir |
| --- | --- |
| Ajouter un œuf | `EggCatalog.Eggs` (+ style dans `EggFactory`) |
| Rééquilibrer | `Config.luau` |
| Changer la map | `MapBuilder.buildPlot` / `buildGround` |
| Nouvelle action client | `NetService.handlers` + `fire()` côté client |
| Nouvel écran | nouveau module client + `Main.client.luau` |
| Traduire les textes | chaînes `NotifyService` / modules client |
