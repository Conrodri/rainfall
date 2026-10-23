# GDD v3 : Survivor-like 2D mobile (nom de travail : « Ember Run »)

> Vampire Survivors (boucle, densité) x Risk of Rain 1/2 (coffres, items empilables, difficulté progressive, variantes de sorts, déblocages par objectifs).
> Cible : Android (Google Play), puis iOS. Moteur conseillé : Unity 2D (URP) ou Godot 4.
> **Run par étages (3 cartes dessinées à la main, piliers à charger), interruptible à tout moment, avec sauvegarde. 3 modes : Facile, Moyen, Difficile.**
> Chiffres détaillés : voir `Maths_Scaling.md` et `simulateur_scaling.py`.

---

## 1. Piliers

1. **Satisfaction immédiate** : chaque kill, sort et pièce se voit et s'entend.
2. **Builds lisibles** : le joueur comprend pourquoi il est fort.
3. **Difficulté progressive à la RoR2** : elle monte sans cesse, le joueur doit suivre.
4. **Sessions courtes et respectueuses** : pause et reprise à tout moment.
5. **Monétisation saine** : aucune puissance à vendre.

---

## 2. Structure d'une run : étages, piliers et zones de charge

**Boucle** : déplacement au pouce (joystick flottant), sort 1 automatique, sorts 2-4 au toucher (ou automatiques en option d'accessibilité) -> kills = or + XP -> coffres posés sur la carte -> choix d'items -> piliers -> boss -> étage suivant.

### Cartes
3 cartes **dessinées à la main** (décor, obstacles, zones de combat), avec des **points d'apparition** prédéfinis. À chaque étage, coffres et piliers sont tirés au hasard parmi ces points (la seed est sauvegardée).

### Un étage
1. À l'arrivée, **tous les coffres sont posés au sol** : 8 petits, 2 grands, parfois 1 légendaire (25 %). Chacun affiche son prix (or), qui **augmente avec l'étage et le temps écoulé**.
2. Le joueur tue des monstres, ramasse l'or et achète les coffres qu'il veut, quand il veut.
3. **2 petits piliers** : en activer un fait apparaître un **mini-boss aléatoire** et une **zone de combat** autour du pilier (×1,5 de monstres dedans), **sans jauge de charge**. Le pilier est terminé à la mort du mini-boss.
4. On peut activer les **deux petits piliers en même temps** (deux mini-boss, deux zones qui s'additionnent) : plus risqué, mais plus rapide.
5. Le **gros pilier** ne s'active qu'une fois les deux petits terminés. Il fait apparaître le **boss d'étage** et une **zone de charge de 90 s** qui n'avance que si le joueur est dedans. Il est terminé quand la zone est chargée **ET** le boss mort ; le boss d'étage lâche alors un **coffre gratuit Rare ou mieux**.
6. Ensuite, le joueur choisit : **rester** pour tuer des monstres et acheter les coffres restants, ou **passer à l'étage suivant** (nouvelle disposition aléatoire, mêmes règles, prix plus élevés).

### Fin de partie
- **Remplacé (21/10/2026, docs/Design_Etages.md)** : une run compte **5 étages** (≈ 18-20 min) ; l'étage 5 « La Source » se termine par le boss final à 3 phases, puis le joueur choisit : **terminer la partie** ou **continuer en mode sans fin** (boucle étages 1-4 puis 5). Ancienne règle : fin après le boss de l'étage 3.
- Il n'y a **pas de Fureur ni de boss à heure fixe**. La pression de fin vient uniquement du scaling : en sans fin, la difficulté s'accélère (pente de temps ×1,5, multiplicateur d'étage ×1,25).

### Modes de jeu
| Mode | Vitesse de scaling | Pour qui |
|---|---|---|
| Facile | ×0,7 | Découvrir, farmer des objectifs |
| Moyen | ×1,0 | Mode de référence |
| Difficile | ×1,5 | Joueurs qui maîtrisent leur build |
Les modes plus durs se débloquent en terminant le précédent ; les rubis gagnés augmentent avec le mode (×0,8 / ×1 / ×1,3).

### Durée (retenue : petits piliers sans charge, gros pilier 90 s)
Un étage dure **3:10 à 3:40** (exploration, deux combats de mini-boss, trajets, 90 s au gros pilier). Une run de **3 étages dure ≈ 10:00** sans farmer (2 étages ≈ 7:00). Farmer après un boss d'étage ajoute du temps.

**Un joueur obtient ≈ 28 items par run (30 en farmant)** (3 étages) en comptant les coffres de boss, plus les relances.

### Événements de carte
- **Sanctuaire de risque**, **Autel de fortune**, **Marchand de l'ombre**, **Coffre piégé** (voir ci-dessus, 1 événement par étage au plus).

### Difficulté progressive visible
Jauge fine dans le HUD : **Calme -> Tendu -> Hostile -> Furieux -> Cataclysme**, avec changement de couleur et de musique.

---

## 3. Menu principal

Quatre boutons dans la moitié basse de l'écran (zone du pouce), grands (≥ 48 dp), avec **Jouer** plus large que les autres.

```
+--------------------------------+
|  [rubis 120]        [reglages] |
|                                |
|     Scène animée : le héros    |
|     près d'un feu de camp,     |
|     braises, musique douce     |
|                                |
|  Defi du jour : 0/1  [!]       |
|                                |
|  [       JOUER / REPRENDRE   ] |
|  [  Personnalisations        ] |
|  [  Boutique                 ] |
|  [  Quitter                  ] |
+--------------------------------+
```

- **Jouer** : s'il y a une run sauvegardée, l'écran propose **Reprendre (Ardent, 4:12)** en bouton principal et **Nouvelle run** (avec confirmation d'écrasement). Sinon : choix du personnage -> variantes de sorts -> mode (Facile / Moyen / Difficile) -> départ.
- **Personnalisations** : skins de personnages, effets de sorts, auras, thèmes de carte, choix des variantes favorites. Tout est visualisable en aperçu animé.
- **Boutique** : « Sans pub », skins, packs de contenu, pass de saison. Pas de pack de rubis, pas de hasard.
- **Quitter** : confirmation, sauvegarde automatique de la run en cours, puis fermeture. (Sur iOS ce bouton est déconseillé par Apple : à masquer sur cette plateforme.)
- **Accueil chaleureux** : petite animation, pastille de défi du jour, point de notification quand un objectif est complété, musique douce, aucun pop-up de vente à l'ouverture.

---

## 4. Pause et sauvegarde

### Pause
- Bouton **pause** toujours visible en haut à droite (appui long de 0,3 s ou zone dégagée, pour éviter les faux appuis).
- **Pause automatique** : appel entrant, passage en arrière-plan, verrouillage de l'écran, notification système.
- Menu de pause : **Reprendre**, **Réglages** (son, vibration, secousses, boutons de sorts), **Sauvegarder et quitter**, **Abandonner la run** (avec confirmation, donne les rubis déjà gagnés).
- À la reprise : compte à rebours de 3 s, puis 1,5 s de protection.
- Le temps de pause, les écrans de coffre et les pubs **ne comptent pas** dans le temps de jeu actif (difficulté et charge des zones figées).

### Sauvegarde de run (un emplacement)
Quand sauvegarder : à la pause, quand l'app passe en arrière-plan, **toutes les 15 s** (écriture asynchrone et atomique : fichier temporaire puis renommage), à chaque choix d'item, et **juste avant une pub** (l'app peut être tuée pendant une pub).

Contenu sauvegardé : graine aléatoire et **état du générateur** (impossible de relancer un coffre en quittant puis revenant), temps de jeu actif, **carte, graine de l'étage, numéro d'étage et mode**, **état des piliers** (non activé / activé, % de charge, PV du boss, zone), liste des coffres posés (position, type, acheté ou non), joueur (position, PV, niveau, XP, or, items et stacks, recharges, variantes), état des coffres (achetés, qualité, items proposés), compteurs (pity, relances à l'or et par pub), événements actifs, monstres vivants (type, position, PV, affixes, recharge de sort, jusqu'à 250 : ≈ 10-20 Ko). Les projectiles ne sont pas sauvegardés (recréés au prochain tir).

Règles :
- Si l'app est tuée **pendant le choix d'un item**, la reprise affiche **les mêmes 2 items** (même qualité).
- Somme de contrôle (CRC) et numéro de version ; si une mise à jour rend la sauvegarde incompatible, la run est convertie en rubis (jamais perdue sans compensation).
- **Sauvegarde cloud optionnelle** (Google Play Jeux) pour changer d'appareil.

---

## 5. Personnages, sorts et passifs

### Emplacements
- Slot 1 : sort **automatique** (verrouillé). Slot 2 : sort à **recharge** (verrouillé).
- Slots 3 et 4 : sort à recharge **ou** passif.
- Configurations : **4 sorts / 0 passif**, **3 sorts + 1 passif**, **2 sorts + 2 passifs**.
- **2 variantes par emplacement** (base + débloquable) : **8 options maximum**. Pas de mana, seulement des recharges réductibles par items.

### Roster de lancement (8 personnages)

Mise à jour 22/10/2026 : l'ancien roster (Veilleuse, Brise-Os, Chronomancienne, Invocateur, Faux-Roi) est retiré de `data/characters.json` et mis en **réserve LiveOps** (idées de personnages futurs). Le roster est celui de `docs/Design_Personnages.md` ; tous ont **4 sorts** (auto, 2 recharges, ultime).

| # | Personnage | Style | Config | Déblocage |
|---|---|---|---|---|
| 1 | **Ardent** (mage de feu) | Zone, débutant | 4 sorts | Disponible |
| 2 | **Rictus** (pantin du Montreur) | Mêlée rapide, leurres, burst | 4 sorts | Visible : tuer 200 monstres à moins de 2 u de soi |
| 3 | **Tocsin** (automate de crue) | Membres lancés, risque/récompense | 4 sorts | Proposé dans Design_Personnages §1 (ouvert pendant les tests) |
| 4 | **Averse** (porteuse de pluie) | Distance / zone, ressource eau | 4 sorts | Visible : rester 60 s cumulées dans l'eau en une run |
| 5 | **Arpenteuse** (géomètre de la Cité) | Zone / piège, ressource chaîne | 4 sorts | Visible : tuer 300 monstres avec un sort de zone persistante |
| 6 | **Rainette** (chevalière des roseaux) | Mobilité / burst, ressource souffle | 4 sorts | **Caché** : terminer un étage sans être touché par un contact |
| 7 | **Avare** (usurier des Terrasses) | Mêlée / tank, ressource or | 4 sorts | **Caché** : finir une run avec plus de 4 P d'or en poche |
| 8 | **Bourbe** (mère-vase de la Mangrove) | Invocatrice / mêlée, ressource masse | 4 sorts | Visible : tuer 3 élites avec des familiers |

Exemple de kit, **Ardent** :

| Slot | Variante A | Variante B (objectif) |
|---|---|---|
| 1 Auto | Éclat de braise (projectile) | Braises errantes (orbes) |
| 2 CD | Nova ardente (zone, 6 s) | Pilier de flamme |
| 3 CD | Cendres (zone persistante) | Pluie de météores |
| 4 CD (ultime) | Brasier | Phénix (invocation) |

### Objectifs de déblocage
- **Visibles** : barre de progression dans le menu (« Tuer 3 élites avec des familiers avec Bourbe »).
- **Cachés** : environ 1/3 des objectifs, indice dans le journal, révélés une fois réussis.
- **Raccourci en rubis** (gagnés en jeu, jamais achetés) pour un personnage ou une variante, pour les joueurs qui n'aiment pas les objectifs cachés.
- Les objectifs sont adaptés à des runs de 3 étages : « tuer 300 monstres avec le sort X », « finir une run en mode Difficile ».

---

## 6. Coffres et relance par pub

### Déroulé d'une ouverture
1. Le joueur dépense l'or. Le coffre tremble, particules de la couleur de qualité.
2. **Dé de qualité (d100)** animé : il s'arrête sur Commun / Peu commun / Rare / Légendaire.
3. **Deux cartes d'items** se retournent (description, tags, « vous en avez déjà X »).
4. Choix : **A**, **B**, ou **Relancer**.

### Relance
- **Relancer (pub)** : le joueur regarde une pub récompensée, puis le jeu propose **2 nouveaux items de la même qualité** (le dé de qualité n'est pas relancé, les items déjà montrés sont exclus tant que la table le permet).
- **Relance à l'or** : alternative sans pub, prix croissant (0,6 × le prix du coffre, ×1,5 à chaque relance).
- **Plafond : 1 relance par coffre, 3 relances par pub par run.**
- **Exemple** : « J'ouvre un coffre -> Rare -> 2 items proposés -> je prends l'un des deux, ou je regarde une pub et on me propose 2 autres items Rare. »
- Joueurs ayant acheté « Sans pub » : la relance reste disponible **sans regarder de pub** (même plafond), pour ne pas les désavantager.
- **Garde-fous** : si aucune pub n'est disponible, le bouton se transforme en relance à l'or ; on voit la qualité et les probabilités dans l'aide ; la pub ne se déclenche jamais sans appui explicite.

### Coffres sur la carte
- Les coffres payants sont **visibles dès l'arrivée** sur l'étage, avec leur prix et leur couleur de type (petit, grand, légendaire). Le prix suit `base × D^1,25`, donc il augmente tant que le joueur attend.
- Petit : 150 d'or de base ; grand : 300 (80 % Peu commun / 20 % Rare) ; légendaire : 1 200 (100 % Légendaire).
- **Boss d'étage** : coffre gratuit Rare ou mieux (90 % / 10 %), avec la même relance. Les mini-boss donnent de l'or et de l'XP.

---

## 7. Ennemis

### Règle générale
Comme le joueur, **chaque monstre a une attaque automatique + 1 sort OU 1 passif**. Les sorts à zone sont télégraphiés au sol (≥ 0,8 s) pour rester lisibles sur mobile.

| Tier | Rôle | Attaque auto | Sort ou passif (exemples) |
|---|---|---|---|
| 1 Essaim | Foule | Contact | Meute (+vitesse en groupe) / Explosion à la mort |
| 2 | Tireur, bondisseur | Projectile | Salve de 3 / Charge télégraphiée |
| 3 Brute | Tank | Coup en cône | Carapace frontale / Onde de choc |

### Élites et buffs
Un monstre élite (aura colorée, icône, PV ×3,5) porte **1 affixe** (2 quand D ≥ 4) :
- **Brûlure** (orange) : ses coups font brûler le joueur sur 3 s.
- **Ralentissement** (bleue) : ses coups ralentissent le joueur de 30 % pendant 1,5 s (jamais de blocage total).
- **Poison** (verte) : ses coups empoisonnent (jusqu'à 5 cumuls) et coupent la régénération.

Les mêmes statuts existent côté joueur (items, variantes de sorts), d'où des synergies lisibles. Des items « contre » existent (Antidote : -40 % des dégâts de brûlure et de poison subis, bottes, bouclier). Les coefficients des statuts diffèrent selon le sens (voir `Maths_Scaling.md`), car les ennemis frappent plus souvent que le joueur ne touche chaque cible.

### Mini-boss et boss d'étage

**Mini-boss** (un tirage aléatoire parmi 6 à chaque petit pilier) et **boss d'étage** (un par carte).

| Boss | Thème | Mécaniques |
|---|---|---|
| **Colosse de pierre** (mini) | Charge et onde de choc | Passif : peau de pierre (-30 % dégâts reçus) jusqu'à ce que sa charge le fasse s'écraser contre un mur : 4 s de vulnérabilité |
| **Reine des ronces** (mini) | Poison et invocations | Épines (projectiles), mares de poison, essaims ; phase 2 à 50 % PV (+25 % vitesse) |
| **Seigneur des cendres** (mini) | Feu | Boules de feu, pluie de météores télégraphiée, mur de flammes |
| **Ours de givre, Essaim-mère, Archonte rouillé** (mini) | À concevoir | Pool de 6 mini-boss au lancement |
| **Boss d'étage** (3, un par carte) | À concevoir | Phases à 70 % et 35 % PV ; zone plus grande |

Un boss a une auto + 2 sorts + un passif de phase (extension de la règle des monstres, à confirmer). Le combat dure 20-40 s ; la zone reste le vrai défi (zone active pendant les combats de mini-boss, 90 s de charge au gros pilier). **Enrage** de boss : +1,5 %/s de dégâts après 60 s de combat.

---

## 8. Game feel

### Visuel
- **Hit-stop** de 30-50 ms sur crits et gros coups, **screen shake** léger et désactivable.
- Flash blanc sur chaque monstre touché, particules de mort différentes par type.
- Chiffres de dégâts : blancs (normal), jaunes (crit), colorés par élément, regroupés en mode foule.
- Projectiles du joueur vifs, ennemis plus sourds, pour garder la lisibilité avec 250 monstres.
- La taille et l'éclat des sorts augmentent avec les items (stacks visibles).

### Audio
- **Pièces d'or** : « ting » dont la hauteur monte à chaque pièce ramassée en chaîne (gamme pentatonique, réinitialisation après 1,5 s).
- **Rubis** : timbre cristallin, plus long, avec une courte reverb.
- **Kills** : sons courts, 3-4 variantes pitchées, nombre de voix limité.
- **Coffre** : séquence verrou, ouverture, révélation ; musique différente par qualité (Légendaire : montée, silence, impact).
- **Montée de niveau** : jingle court ; **sort prêt** : petit son discret.
- Musique de combat qui s'intensifie avec la jauge de difficulté, ducking lors des événements.
- **Haptique** légère aux coffres, ultimes et boss (désactivable).

---

## 9. Progression smooth

- Pas de mur : la difficulté dépend du temps de jeu actif et des boss tués.
- Modes **Facile / Moyen / Difficile**, débloqués en terminant le précédent, avec plus de rubis ; un mode Cauchemar (scaling ×2-3) pourra arriver en LiveOps.
- Pity sur les coffres pour éviter les débuts de run vides.
- À la fin de run : « il te manque 40 kills pour débloquer X » (effet de proximité).
- Mode sans fin optionnel après le boss final.

---

## 10. Monétisation saine

| Source | Prix | Règle |
|---|---|---|
| **Relance de coffre par pub** | gratuit | Opt-in, 1 par coffre, 3 par run max |
| **Autres pubs récompensées** | gratuit | Seconde chance (1/run), x2 rubis de fin de run |
| **« Sans pub »** (achat unique) | 3,99 € | Plus aucune pub imposée, relances et bonus offerts sans pub |
| **Skins** (personnages, effets de sorts, auras) | 0,99-2,99 € | 100 % cosmétique, aperçu en jeu |
| **Packs de contenu** (personnage + biome + items) | 2,99-4,99 € | Contenu aussi débloquable en jouant |
| **Pass de saison cosmétique** | 4,99 € | Piste gratuite généreuse |
| **Pack Fondateur** | 7,99 € | Skin exclusif et crédits |

**Maximum 5 pubs par run** (3 relances + seconde chance + x2 rubis), toutes demandées par le joueur. Aucune pub en plein combat.

### Charte éthique
- Aucune puissance à vendre, aucun hasard payant, aucun pack de rubis.
- Pas de faux timers, pas de culpabilisation, prix transparents.
- Conformité RGPD (consentement pubs personnalisées), décision « Families / moins de 13 ans » dès le départ car elle change les SDK.

### Ordre de grandeur (hypothèses à valider)
`ARPDAU pub = pubs vues par DAU × eCPM / 1000` : avec 3,5 pubs par joueur actif et par jour et un eCPM de 10 €, on obtient environ 0,035 € par joueur actif et par jour (à valider avec ton réseau de médiation), auxquels s'ajoutent les achats (« Sans pub », skins). LTV 30 jours visée : 0,50-1,20 €, donc un coût par installation maximal supportable d'environ 0,40 €.

---

## 11. LiveOps

| Rythme | Contenu |
|---|---|
| Quotidien | Défi du jour (seed fixe), récompense en rubis |
| Hebdomadaire | Défi de la semaine avec mutateur (« tous les monstres sont élites »), classement |
| Mensuel | Événement thématique, 2-3 nouveaux items |
| Tous les 2 mois | Nouveau personnage (avec un objectif caché) |
| Trimestriel | Nouveau biome et boss, saison cosmétique |

Run courte = beaucoup de runs par jour : les défis et les seeds partagées créent la rétention. Mutateurs inspirés des Artefacts de RoR2.

---

## 12. Roadmap de production (6 mois)

| Mois | Objectif | Livrables |
|---|---|---|
| 1 | Prototype | Joueur, sort auto, spawn, XP/or, 1 coffre, 20 monstres, test 250 monstres sur Android bas de gamme |
| 2 | Cœur du jeu | Director + difficulté D, **1 carte jouable** avec coffres posés, 3 piliers, zones de charge, 6 mini-boss + 1 boss d'étage, d100 + 2 items + relance, 1 personnage complet |
| 3 | Contenu | **Cartes 2 et 3 dessinées à la main** (points d'apparition), menu, pause et sauvegarde (état des piliers et des coffres), 3 modes, 3 personnages, 30 items, audio/VFX passe 1 |
| 4 | Monétisation | Pubs récompensées, « Sans pub », skins, défi quotidien, analytics |
| 5 | Soft launch (Philippines, Pologne, Canada) | Mesure J1/J7/J30, équilibrage via télémétrie |
| 6 | Lancement mondial | 8 personnages, 50 items, pass de saison |

Indicateurs go/no-go : rétention J1 ≥ 38 %, J7 ≥ 14 %, J30 ≥ 5 % ; durée médiane de run conforme à la durée retenue ± 10 % ; première run terminée ≥ 50 % ; note ≥ 4,3.

---

## 13. Risques

| Risque | Parade |
|---|---|
| Marché saturé de clones | Identité : coffres RoR, 2 variantes par sort, objectifs cachés, relance de coffre |
| 250 monstres sur mobile | Pooling d'objets, rendu par lots, test bas de gamme dès le mois 1 |
| Sauvegarde corrompue | Écriture atomique, CRC, sauvegarde avant pub, conversion en rubis en cas d'incompatibilité |
| Abus de la relance par pub | Plafond par coffre et par run, qualité figée |
| Pubs perçues comme intrusives | Opt-in seulement, « Sans pub » |
| Propriété intellectuelle | S'inspirer des mécaniques uniquement, pas des noms, assets ni designs de RoR2 / VS |

---

## 14. Points à confirmer

1. **Durée de run** : retenu petits piliers sans charge + gros pilier 90 s, 3 étages ≈ 10:00 sans farm. À revalider en playtest.
2. **Confirmé** : la charge n'avance que dans la zone ; un petit pilier est terminé quand sa zone est chargée et son boss mort ; mini-boss = or et XP ; boss d'étage = coffre gratuit Rare+. **Confirmé** : le ralentissement des élites reste à -30 % pendant 1,5 s au lancement. À valider : boss avec auto + 2 sorts + passif.
3. « Sans pub » : relance de coffre gratuite sans pub (avec le même plafond).
4. Cible d'âge (changement de SDK de pubs si < 13 ans).
