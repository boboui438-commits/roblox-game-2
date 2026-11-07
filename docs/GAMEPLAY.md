# Gameplay & équilibrage

Tous les chiffres vivent dans **`src/shared/Config.luau`** (constantes) et
**`src/shared/EggCatalog.luau`** (œufs + raretés). Modifier un seul fichier suffit
pour rééquilibrer le jeu, côté serveur comme côté client.

## Boucle de jeu

1. **Acheter** — le kiosque central propose 4 œufs (rareté tirée au sort selon
   les poids du catalogue). Les prix montent avec la rareté.
2. **Encaisser** — chaque œuf posé sur un socle de sa base rapporte son revenu
   chaque seconde (`Config.IncomeTick`).
3. **Voler** — maintenir `E` sur un œuf ennemi, le porter jusqu'à sa base
   (vitesse réduite à `Config.CarryWalkSpeed`), puis `E` sur un socle libre.
4. **Défendre** — `F` achète une protection de 90 s (coût indexé sur les revenus).
5. **Progresser** — fusionner deux œufs identiques (niveau max 5), vendre,
   débloquer les socles 5 à 8 et compléter la collection.

## Raretés et probabilités

| Rareté | Poids | Chance relative |
| --- | --- | --- |
| Commun | 40 | 40,9 % |
| Peu commun | 26 | 26,6 % |
| Rare | 16 | 16,3 % |
| Épique | 9 | 9,2 % |
| Légendaire | 4,5 | 4,6 % |
| Mythique | 1,8 | 1,8 % |
| Divin | 0,5 | 0,5 % |
| SECRET | 0,08 | 0,1 % |

Le tirage se fait en deux temps : une rareté (poids ci-dessus) puis un œuf
uniformément dans cette rareté (`ShopService.pickEgg`). La boutique est
personnelle (4 emplacements par joueur) et se renouvelle toutes les 15 s.

## Catalogue (20 œufs)

| Œuf | Rareté | Prix | Revenus/s | Retour sur investissement | Style |
| --- | --- | --- | --- | --- | --- |
| Œuf de Poule | Commun | $60 | 1/s | ~60s | `plain` |
| Œuf Tacheté | Commun | $140 | 2.4/s | ~58s | `crack` |
| Œuf de Canard | Commun | $340 | 5.5/s | ~62s | `plain` |
| Œuf de Grenouille | Peu commun | $560 | 9/s | ~62s | `ring` |
| Œuf d'Escargot | Peu commun | $950 | 16/s | ~59s | `ring` |
| Œuf de Pingouin | Peu commun | $1 600 | 27/s | ~59s | `crack` |
| Œuf de Renard | Rare | $3 200 | 60/s | ~53s | `ring` |
| Œuf de Panda | Rare | $5 200 | 95/s | ~55s | `crack` |
| Œuf de Poulpe | Rare | $7 800 | 140/s | ~56s | `ring` |
| Œuf de Dragon | Épique | $18 000 | 340/s | ~53s | `spikes` |
| Œuf de Licorne | Épique | $26 000 | 490/s | ~53s | `halo` |
| Œuf du Néant | Épique | $40 000 | 760/s | ~53s | `aura` |
| Œuf de Phénix | Légendaire | $120 000 | 2300/s | ~52s | `aura` |
| Œuf du Kraken | Légendaire | $180 000 | 3500/s | ~51s | `ring` |
| Œuf d'Astronaute | Légendaire | $260 000 | 5000/s | ~52s | `halo` |
| Œuf Cosmique | Mythique | $700 000 | 13500/s | ~52s | `aura` |
| Œuf de Trou Noir | Mythique | $1 100 000 | 21000/s | ~52s | `aura` |
| Œuf Divin | Divin | $3 500 000 | 65000/s | ~54s | `crown` |
| Œuf du Temps | Divin | $6 000 000 | 115000/s | ~52s | `halo` |
| Œuf du Créateur | SECRET | $25 000 000 | 480000/s | ~52s | `crown` |

> Le « retour sur investissement » est le temps nécessaire pour rembourser
> l'achat avec les seuls revenus de l'œuf (hors bonus de collection). Il est
> volontairement homogène (~55–65 s) pour que chaque palier reste attractif.

## Formules

| Élément | Formule | Constante |
| --- | --- | --- |
| Revenus d'un œuf | `income × 1,55^(niveau−1)` | `LevelIncomeStep`, `MaxEggLevel = 5` |
| Bonus de collection | `1 + 0,03 × œufs uniques` | `CollectionBonusPerEgg` |
| Revenus totaux | `Σ revenus × bonus` | — |
| Revente | `price × 1,55^(niveau−1) × 0,6` | `SellRefund` |
| Prime de vol | `60 + 5 % du prix` | `StealBonusBase`, `StealBonusPercent` |
| Coût de protection | `400 + revenus/s × 25` | `LockCostBase`, `LockCostIncomeFactor` |
| Socles 5→8 | 3 000 · 20 000 · 150 000 · 1 500 000 | `SlotUpgradeCost` |

## Règles de vol (détaillées)

* Impossible de voler un œuf de sa propre base.
* Impossible de voler si la base est **protégée** (`lockUntil > maintenant`).
* Le voleur doit être **en vie**, à moins de 16 studs de l'œuf, et ne pas
  déjà porter un œuf (cooldown de 1,2 s entre deux tentatives).
* Au début du vol, l'œuf **quitte immédiatement** la base de la victime :
  ses revenus s'arrêtent, sa collection est déjà validée.
* En portant : vitesse 11, saut désactivé, l'œuf est soudé au-dessus de la tête.
* Mort ou départ du voleur → l'œuf **tombe au sol** et devient libre :
  n'importe qui peut le ramasser avec `E`.
* Un œuf libre non ramassé **revient à son propriétaire** après 45 s
  (`DroppedEggLifetime`) s'il a un socle libre, sinon il disparaît.
* La sécurisation n'est possible que sur **son propre socle libre**, à moins de
  22 studs, et donne la prime de vol.
* Un œuf sécurisé garde son **niveau** (un œuf niveau 3 volé reste niveau 3).

## Contre-jeu

| Situation | Réponse |
| --- | --- |
| Un joueur campe ta base | Protection 90 s (coût indexé sur tes revenus) |
| On te vole un œuf | Alerte écran + notification + œuf traçable au sol |
| Ta base est pleine | Vends un œuf ou débloque un socle |
| Un joueur est trop fort | Vole ses œufs les plus rares : les revenus suivent l'œuf |

## Commandes

| Touche | Action |
| --- | --- |
| `E` | Interagir (boutique, voler, sécuriser, gérer, débloquer) |
| `B` | Ouvrir / fermer la boutique |
| `F` | Protéger sa base |
| `Q` | Lâcher l'œuf porté |
| `H` / `/` | Aide |
| Molette / caméra | Vue libre (le portage n'affecte pas la caméra) |
