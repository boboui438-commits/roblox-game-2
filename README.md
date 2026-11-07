# 🥚 Steal a Egg — jeu Roblox complet (Rojo + Luau)

Une recréation complète du genre **« vole l'œuf »** : chaque joueur possède une
base, y installe des œufs qui rapportent de l'argent en continu… et peut aller
voler ceux des autres. Tout est écrit en **Luau**, construit avec **Rojo**, et
la map comme les œufs sont **générés en code** : aucun asset externe, rien à
télécharger, rien à importer.

> État du projet : jouable de bout en bout, serveur autoritaire, sauvegarde
> DataStore, interface FR responsive (PC / mobile / manette).

---

## ✨ Fonctionnalités

**Boucle de jeu**
- 4 emplacements de boutique tirés au sort par rareté (8 raretés, 20 œufs).
- Revenus passifs par seconde, avec **bonus de collection** (+3 % par œuf unique).
- **Vol complet** : maintenir `E`, porter l'œuf (vitesse réduite, saut coupé),
  le sécuriser sur un socle libre de sa base.
- **Contre-jeu** : protection de base payante (90 s), alerte temps réel pour la
  victime, œuf lâché au sol que tout le monde peut ramasser.
- **Fusion** de deux œufs identiques (niveaux 1 → 5) et **revente**.
- **Agrandissement de base** : 4 → 8 socles.

**Technique**
- 100 % serveur autoritaire : argent, propriété, distance, portage, achats.
- Anti-exploit : validation stricte des `RemoteEvent`, token bucket, kick anti-flood.
- Sauvegarde DataStore avec **verrou de session** (pas de duplication multi-serveur)
  et repli automatique en mode mémoire si les DataStores sont indisponibles.
- Map générée : 12 parcelles, kiosque central, décor (arbres, rochers, routes).
- HUD animé, classement live, fil d'actualité, toasts, aide intégrée.
- File d'attente si plus de parcelles que de places (aucun joueur expulsé).

---

## 🚀 Démarrage rapide

### 1. Installer les outils

```bash
# avec Rokit (recommandé)
rokit install

# ou avec Aftman : renommer rokit.toml en aftman.toml puis
aftman install
```

Pas envie d'un gestionnaire ? Installe simplement
[Rojo](https://rojo.space) (`rojo --version` doit répondre).

### 2A. Travailler en direct avec Studio (recommandé)

```bash
rojo serve
```

1. Ouvre **Roblox Studio** sur une base **vide** (Baseplate).
2. Installe le plugin Rojo (bouton *Plugins* → *Rojo*), puis **Connect**.
3. Le dossier `src/` est synchronisé en direct dans le jeu.

### 2B. Ou générer un fichier de place

```bash
mkdir -p build
rojo build default.project.json -o build/StealAnEgg.rbxlx
```

Ouvre ensuite `build/StealAnEgg.rbxlx` dans Studio.

### 3. Activer la sauvegarde en Studio

`Game Settings` → `Security` → **Enable Studio Access to API Services**.
Sans cela, le jeu tourne quand même : il passe en *mode mémoire* et l'affiche
dans la console (`DataStore indisponible, mode mémoire`).

### 4. Publier sur Roblox

- `Game Settings` → `Places` : publie la place.
- `Game Settings` → `Basic` → **Max Players = 12** (une parcelle par joueur,
  valeur `Config.PlotCount`). Au-delà, les joueurs supplémentaires patientent
  en file d'attente et reçoivent une base dès qu'une se libère.
- Le script serveur crée lui-même la map : inutile de nettoyer la place, le
  `Baseplate` et les `SpawnLocation` existants sont supprimés au démarrage.

---

## 🎮 Comment jouer

| Touche | Action |
| --- | --- |
| `E` | Interagir : boutique, voler (maintenir), sécuriser, gérer, débloquer |
| `B` | Boutique |
| `F` | Protéger sa base |
| `Q` | Lâcher l'œuf porté |
| `H` / `/` | Aide |

1. Va au **kiosque central** et achète ton premier œuf.
2. Place-le sur un socle de ta base : il rapporte de l'argent chaque seconde.
3. Vise un œuf ennemi, **maintiens `E`** pour le voler, ramène-le chez toi.
4. Appuie sur `E` sur un socle libre pour le **sécuriser** (prime de vol incluse).
5. Fusionne deux œufs identiques pour multiplier les revenus, débloque les
   socles 5 à 8, et complète la collection des 20 œufs.

Détails complets (formules, table des œufs, probabilités) :
**[docs/GAMEPLAY.md](docs/GAMEPLAY.md)**.

---

## 🗂️ Structure

```
src/shared/    Config, EggCatalog, Remotes, Util        -> ReplicatedStorage.Shared
src/server/    Main, Data, Session, Plot, Map, Eggs,
               Steal, Shop, Sync, Notify, Net, Scene    -> ServerScriptService.Server
src/client/    Main, Hud, ShopPanel, EggPanel, CarryUi,
               Toast, PromptFilter, EggAnimator, Theme,
               UiKit                                    -> StarterPlayerScripts.Client
```

Documentation technique (flux réseau, cycle de vie joueur, sécurité,
extension) : **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

---

## ⚙️ Réglages express

Tout se règle dans `src/shared/Config.luau` :

| Constante | Effet | Défaut |
| --- | --- | --- |
| `StartingCash` | argent de départ | `150` |
| `IncomeTick` | fréquence des revenus | `1 s` |
| `CarryWalkSpeed` | vitesse en portant un œuf | `11` |
| `DroppedEggLifetime` | avant retour de l'œuf lâché | `45 s` |
| `LockDuration` / `LockCostBase` | protection de base | `90 s` / `$400` |
| `StartSlots` / `MaxSlots` / `SlotUpgradeCost` | progression des socles | `4` → `8` |
| `ShopRefreshTime` | renouvellement boutique | `15 s` |
| `PlotCount` | nombre de bases | `12` |
| `SaveInterval` | sauvegarde auto | `90 s` |

Ajouter un œuf = ajouter une entrée dans `EggCatalog.Eggs` (id, nom, rareté,
prix, revenus, couleurs, style). Le modèle 3D, la boutique, le panneau et la
sauvegarde s'adaptent automatiquement.

---

## 🔒 Sécurité

- Aucune valeur (argent, propriété, position, portage) n'est acceptée du client.
- Chaque action est revalidée : type, plage, propriétaire, distance, cooldown,
  état (`carrying`, `lockUntil`, socle libre/débloqué), solvabilité.
- Limitation de débit par joueur + compteur de requêtes invalides (kick).
- Données relues depuis le DataStore intégralement assainies (`sanitize`).
- Verrou de session : un même compte ne peut pas jouer sur deux serveurs.

---

## 🧪 CI

`.github/workflows/ci.yml` exécute à chaque push :

1. `rojo build` → artefact `StealAnEgg.rbxlx` ;
2. compilation de **tous** les fichiers `.luau` avec le compilateur officiel
   Luau (détection d'erreurs de syntaxe).

En local :

```bash
rojo build default.project.json -o build/StealAnEgg.rbxlx
python3 tests/run_logic_tests.py     # 166 assertions (économie, catalogue, sessions)
stylua --check src
selene src
```

Les tests logiques exécutent les **vrais modules** (`Config`, `Util`,
`EggCatalog`, `SessionService`) dans la VM Luau avec de simples stubs de
`CFrame`/`Color3` : aucune dépendance à Roblox. Ils vérifient l'unicité des
œufs, l'équilibrage (retour sur investissement), les formules de niveaux, le
bonus de collection, le verrouillage des socles, la revente et la
sérialisation/hydratation des sauvegardes.

---

## 📄 Licence

MIT — voir [LICENSE](LICENSE). Les noms du jeu et l'inspiration de genre
appartiennent à leurs créateurs respectifs ; ce dépôt est une implémentation
originale, sans asset ni code tiers.
