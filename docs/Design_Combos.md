# Combos des personnages : préparation → récompense (design v1)

> Statut : **document de design** (Fable, game-designer, 29/10/2026), sur demande du joueur : « revoir le kit des personnages pour qu'ils aient des combos entre leurs sorts, comme Arpenteuse (dasher sur un boss, poser son piquet, puis avoir une double chaîne qui frappe grâce à son ultime et son 1er sort) ». Rien n'est implémenté ; aucun fichier de `game/` n'est modifié. Ce document **reprend et resserre** `docs/Combos_Kits.md` (v1 du 27/10, « un maximum d'interactions ») en ne gardant que ce qui forme une **séquence** lisible : un geste qui prépare, un geste qui encaisse. Il intègre les esquives **implémentées** de `docs/Design_Esquives.md` (29/10), qui remplacent les roulades v1 citées par `Combos_Kits.md`.
> Conventions : 1 u = 64 px ; « coef » = multiple de `Balance.player_base_damage(L)` ; les valeurs citées sont celles des kits (`game/scripts/spells/<id>_kit.gd`) au 29/10/2026. Cibles d'équilibrage (`docs/Equilibrage_Personnages.md`) : mono-cible dans [0,85 ; 1,20] × Ardent, Arpenteuse élite 1,30, chaque variante à ±15 % de son sort de base. Règles du projet : télégraphe ≥ 0,8 s pour tout effet différé, aucune mort instantanée, un retour visuel et un retour sonore par combo, **aucun aplat géométrique** (pas de Polygon2D ni de `_draw` : seulement des sprites, des `Line2D` texturées, des modulations HDR et des chiffres colorés).

Sommaire : 1. Grammaire d'un combo (règles, budget, plateformes, esquive) · 2. Arpenteuse · 3. Ardent · 4. Averse · 5. Les sept autres · 6. Lot transverse · 7. Récapitulatif et ordre d'implémentation · 8. Points à trancher.

---

## 1. Grammaire d'un combo

### 1.1 Ce qu'est un combo ici

Un combo est une **séquence de deux ou trois gestes** où le premier **prépare** (il pose un état : objet au sol, marque sur un monstre, statut, ressource) et le dernier **encaisse** (il lit cet état et frappe plus fort, plus large ou plus longtemps). Entre les deux : une **fenêtre** de 1,5 à 5 s, visible. L'esthétique visée (MDA) est la **Sensation** (le coup de grâce qui claque) et le **Défi** (lire le moment, tenir l'ordre) ; la dynamique attendue est « je place, je déclenche », pas « j'appuie sur tout ».

Cinq règles, toutes dérivées d'Arpenteuse, le modèle du joueur :

1. **Un seul état par personnage.** Il existe déjà dans neuf kits sur dix (chaîne, trempe, marque de Rançon, exposition, aiguisage, piliers, mottes, doublures, Gluant). Seul Ardent en reçoit un nouveau (la marque « braise »). Pas de nouvelle jauge, pas de nouveau bouton.
2. **L'ordre compte, mais les deux ordres sont valides** (Sirlin : aucune option dominée). A → B donne la récompense pleine ; B → A donne autre chose d'utile (contrôle, ressource, préparation du combo suivant). Jamais « B avant A = rien ».
3. **Le coup qui encaisse fait +20 à +30 % sur les cibles préparées** (jamais plus de +30 % sans justification écrite). Si le combo se produit « tout seul » plus d'une fois sur deux avec la visée automatique, le sort de base baisse de 5 à 10 % pour que le kit reste dans sa cible : un joueur qui ignore le combo ne descend pas sous 0,85 × Ardent, un joueur qui le maîtrise ne dépasse pas 1,20 (Arpenteuse 1,30).
4. **La fenêtre se voit sans HUD** : marqueur sur le monstre (braises, gouttes, sceau) ou sur l'objet (chaîne qui rougit, flaque qui pulse). **Et sur le HUD** : le bouton du sort qui encaisse **pulse dans la couleur d'accent** tant que la fenêtre est ouverte (nouveau hook `kit.combo_ready(slot) -> bool`, §6). C'est l'aide commune aux trois plateformes : elle dit « maintenant », pas « où ».
5. **L'esquive n'est jamais le coup qui encaisse.** `docs/Design_Esquives.md` §1 règle 6 : aucun effet d'esquive ne dépasse 5 % du DPS d'un kit. L'esquive peut **préparer** (le Trait d'Arpenteuse tend la chaîne, le Repli de Vigie bande l'arc, l'Iaï de Taliant dégaine) ou **sortir** du combo (l'Éclat d'Ardent après la Nova), jamais rapporter des dégâts directs.

### 1.2 Plateformes

- **Sort 1 automatique partout** : quand il participe (Chaîne, Goutte-lame, Éclat de braise), c'est comme prolongateur ou rechargeur de fenêtre, jamais comme déclencheur à viser.
- **Mobile, visée automatique** (`SpellCaster.densest_point`) : chaque combo est noté « naturel » (il se produit avec le paquet le plus dense sans aide), « aidé » (`kit.auto_cast_ok(slot)` retarde ou avance le sort de 0,5 s au plus, seulement dans la branche auto-cast, contrat `CONTRACTS.md`) ou « placement » (c'est le joystick qui le fait : esquive, position).
- **PC** : sorts 2-4 visés au curseur ; **manette** : stick droit sinon le plus proche. Les combos à marque sont plus faciles à la souris (on vise les marqués) : c'est l'écart de maîtrise accepté, pas un écart de viabilité (le mobile reçoit l'aide du point 4 et les règles `auto_cast_ok`).

### 1.3 Budget d'équilibrage (systems-designer à valider)

| Grandeur | Règle | Vérification |
|---|---|---|
| Bonus sur les cibles préparées | +20 à +30 % du coef du sort qui encaisse (ou +0,5 à +1,0 coef si le sort est ≥ 3,5) | `balance_sim_run.tscn --chars=<id>` avant / après, avec et sans la règle `auto_cast_ok` |
| Gain net du kit à réalisation réaliste | +5 à +10 % au plus, ≤ 0 sans combo | mono [0,85 ; 1,20], mini-boss [0,8 ; 1,25] |
| Fenêtre | 1,5 s (marque sur monstre) à 5 s (objet au sol) ; prolongeable par le sort 1 jusqu'à ×2 | lisible : le marqueur s'éteint quand la fenêtre se ferme |
| Esquive | ≤ 5 % du DPS, et seulement par préparation | `tests/dodge_test` inchangé |
| Perf mobile | aucune boucle par monstre et par image : marques en dictionnaire du kit (modèle `AvareKit.marks`), sondages à 0,25 s | 250 monstres : `capture_hit_feel` |

Les mesures de référence du 23/10 (`docs/Equilibrage_Personnages.md` §1) : Ardent 1,00 ; Averse 1,03 en bot (**manuel non mesuré, Crue jugée critique**) ; Arpenteuse 0,83 global, 1,03 mono, 0,55 zone (biais du bot qui ne trace pas la chaîne). Une mesure à jour est lancée pour ce document (§7.3).

---

## 2. Arpenteuse, la géomètre de la Cité (`arpenteuse_kit.gd`) : la référence

**Identité** : elle ne blesse que ce qu'elle a parcouru ; son déplacement dessine le piège, ses sorts le ferment.

**État** : la chaîne posée (`chain_points()`, 14 u) et ses prolongements (ligne du piquet `peg_segment()`, ligne A-B des Jalons). Les trois sorts 2-4 lisent `_lines()` ; le Trait (esquive) déroule 3 u d'un coup et tend la chaîne 1,5 s (`TAUT_S`, ralentissement `TAUT_SLOW_PCT` 0,5). Tout est déjà codé ; ce chapitre nomme les séquences, en chiffre les fenêtres et ajoute **deux lectures** qui manquaient pour que l'ordre se voie dans un chiffre.

### 2.1 AR-1 « Double chaîne » (le combo du joueur, existant, à rendre lisible)

| Étape | Geste | Ce qui se passe | Constantes |
|---|---|---|---|
| Préparation 1 | **Trait** (esquive) sur ou à travers le boss | 3 u de chaîne sous lui, tendue 1,5 s : ralenti 50 %, chaque tick de Chaîne 1,0 / 0,5 s | `TAUT_S` 1,5, `TAUT_SLOW_PCT` 0,5, `CHAIN_COEF` 1,0, `CHAIN_TICK_S` 0,5 |
| Préparation 2 | **Piquet** planté de l'autre côté du boss (curseur ; mobile : paquet dense) | la ligne piquet → elle traverse le boss : 1,0 (+25 % élite / boss) toutes les 0,65 s pendant 5 s | `PIQUET_COEF` 1,0, `PEG_IMMUNITY_S` 0,65, `PEG_LIFE_S` 5, `BIG_TARGET_ADD` 0,25 |
| Fenêtre | 5 s (vie du piquet), elle reste à ≤ 10 u | le boss est sur **deux lignes** : ≈ 2,0 + 1,9 = **3,9 coef/s** contre 2,0 sur la chaîne seule | `PEG_SNAP_U` 10 |
| Récompense | **Tendeur** | 10 (+25 %) sur tout ce qui est à 1 u de la chaîne **et** de la ligne du piquet ; les non-boss sont traînés et emprisonnés 1,5 s ; les lignes restent | `TENDEUR_COEF` 10, `TENDEUR_REACH_U` 1, `TENDEUR_STUN_S` 1,5 |

- **Ordre inverse** (Piquet → Trait) : valide, la ligne du piquet suit Arpenteuse, donc le Trait replace la ligne ; moins fort (la chaîne tendue vient après), utile pour fuir en gardant le boss sur la ligne.
- **Lecture à ajouter** : un monstre touché **par les deux lignes** dans le même tick est « croisé » : la chaîne rougit plus fort à son contact (`HEAT_FLASH_ENERGY` 4,5 → nouvelle `CROSS_FLASH_ENERGY` 6,0, 0,18 s) et le bouton du Tendeur pulse (`combo_ready(4)` vrai si ≥ 1 croisé ou ≥ 3 monstres sur les lignes). Aucun dégât en plus : le double tick **est** déjà la récompense (+95 % de DPS de lignes sur la cible). Son : variante « lourde » du tick de chaîne sur un croisé (règle audio existante « le son suit la puissance du coup »).
- **Mobile** : Trait = bouton + joystick, Piquet = paquet dense (le boss est le paquet), Tendeur sans visée : **naturel**.
- **Équilibrage** : rien ne change ; cible élite 1,30 conservée (`docs/Equilibrage_Personnages.md` §2.4).

### 2.2 AR-2 « Tendeur → Halage » (ordre fort, chiffré)

- **Préparation** : Tendeur (les non-boss sont à 1 u d'elle, emprisonnés 1,5 s, `is_imprisoned()`).
- **Fenêtre** : 1,5 s (`TENDEUR_STUN_S`) ; le bouton du Halage pulse.
- **Récompense** : Halage sur des emprisonnés : attraction 1,5 u → 0 (ils sont tenus) et **+0,5 coef** sur eux (3,5 → 4,0 ; nouvelle `HALAGE_HELD_ADD` 0,5, plage sûre 0,3-0,7). Le +25 % élite reste additif.
- **Ordre inverse** (Halage → Tendeur) : l'attraction de 1,5 u ramène le paquet sur la chaîne, le Tendeur en attrape davantage : valide, c'est l'ordre « zone ».
- **Retour** : chiffres en accent cuivre (`hit["combo"]`), chaîne qui mord (flash existant), son Halage « lourd ».
- **Équilibrage** : +0,5 sur ≤ 6 monstres une fois par 20 s : < 2 % du DPS, aucune compensation. Variante Nœud : +0,5 s de prison sur des emprisonnés du Tendeur (`NOEUD_PRISON_S` 1 → 1,5 dans ce cas) au lieu du +0,5 coef.

### 2.3 AR-3 « Trait → Halage » (l'esquive qui prépare)

- **Préparation** : Trait (3 u de chaîne tendue 1,5 s, ralentissement 50 %). Tip déjà écrit (`Design_Esquives.md` §3.5) : après un Halage, un Trait redonne de quoi boucler (`BOUCLE_MIN_U` 3).
- **Fenêtre** : `TAUT_S` 1,5 s.
- **Récompense** : Halage lancé pendant que `taut_left > 0` : **+0,5 coef** sur les monstres de la bande du **segment tendu** seulement (nouvelle `HALAGE_TAUT_ADD` 0,5, plage 0,3-0,6). Ailleurs sur la chaîne, Halage normal.
- **Mobile** : esquive puis bouton 2, sans visée : **naturel**. `auto_cast_ok(2)` : si `taut_left > 0` et ≥ 2 monstres sur le segment tendu, lancer tout de suite (règle actuelle `LOOP_AUTO_MIN_HITS` 2 conservée).
- **Équilibrage** : +0,5 × ≤ 4 monstres par 6 s au mieux ≈ +0,3/s sur ≈ 10/s en zone : 3 %, sous le plafond des 5 % de l'esquive. Aucune compensation.
- **Risque** : le Trait devient « offensif » dans la tête du joueur et il l'use en i-frames : la recharge de 3 s et la règle 5 bornent cela ; si le simulateur manuel montre > 5 %, `HALAGE_TAUT_ADD` 0,3.

Rien d'autre. Arpenteuse reste 5/5 : ne pas toucher `TENDEUR_COEF`, `PEG_IMMUNITY_S`, `BIG_TARGET_ADD`.

---

## 3. Ardent, mage de feu (`ardent_kit.gd`, `ardent_variant_kit.gd`, `ardent_tracker.gd`)

**Identité** : le débutant sûr : il pose le feu, recule, laisse brûler. Il n'a besoin d'aucune gestion ; il peut avoir **un** combo lisible : « ce qui brûle explose plus fort ».

**État nouveau (le seul du document)** : la marque **« braise »** par monstre, dans un dictionnaire du kit (`marks {instance_id: fin}`, modèle `AvareKit.marks`, protégé contre le recyclage du pool). Durée `EMBER_MARK_S` **1,5 s**, rafraîchie à chaque pose, plafond `EMBER_MARK_MAX_S` **3 s**. Posée par : chaque tick de Cendres (déjà suivi par `ArdentTracker`), chaque impact de Pluie de météores, chaque piqué du Phénix, la **silhouette de braises de l'Éclat** (esquive, §3.3). Visuel : 1 particule de `ardent_ashes` à l'échelle 0,4 u qui monte du monstre (sprite existant, aucun rendu nouveau) ; le bouton de la Nova pulse tant qu'un marqué est à ≤ 3,5 u. Contrat : **Ardent de base n'a pas de nœud kit** (`ArdentVariantKit` n'existe qu'avec une variante) : le lot crée `ArdentBaseKit` (ou promeut `ArdentTracker`) ; décision orchestrateur.

### 3.1 A-1 « Cendres → Nova » (combo principal)

| Étape | Geste | Effet | Constantes |
|---|---|---|---|
| Préparation | **Cendres** sur le paquet (mobile : paquet dense à 7 u ; PC : curseur) | marque braise sur chaque monstre à chaque tick (0,5 s) | `EMBER_MARK_S` 1,5 |
| Fenêtre | tant qu'ils brûlent + 1,5 s après être sortis de la zone ; l'Éclat de braise (auto) qui touche un marqué **prolonge de 0,6 s** (plafond 3 s) et **perce +1** | il peut reculer sans perdre la fenêtre | `EMBER_MARK_EXTEND_S` 0,6, `EMBER_MARK_MAX_S` 3 |
| Récompense | **Nova ardente** (auto-déclenchée à 3 u, ou lancée) | **+30 %** sur les marqués (nouvelle `NOVA_EMBER_MULT` 1,3, plage 1,2-1,4) ; la marque est consommée ; la Cendres qui l'a posée **gagne +1 s** (une fois par Cendres, `ASH_EXTEND_S` 1,0) | `NOVA_COEF` 2,5 → **2,3** |

- **Ordre inverse** (Nova → Cendres) : valide : la Nova repousse (recul) le paquet dans la Cendres que l'on pose derrière lui ; pas de bonus, mais le paquet brûle plus longtemps : c'est l'ordre « zone ».
- **Mobile** : les deux sorts visent le paquet dense ; le combo se produit quand le paquet quitte la Cendres vers Ardent (il le fait toujours : il le poursuit). **Naturel.** Aide : `auto_cast_ok(2)` retarde la Nova de 0,5 s au plus si ≥ 2 marqués sont entre 3,5 et 4,5 u.
- **Retour** : la Cendres pulse (modulate HDR ×1,6 pendant 0,3 s sur `ZoneEffect.vfx`), chiffres orange, son Nova « lourd » +2 demi-tons. Aucun VFX nouveau.
- **Équilibrage** : marqués estimés 50 % des cibles de Nova en zone, 30 % sur boss. Zone : 2,3 × (1 + 0,3 × 0,5) = 2,65 (+6 %) ; boss : 2,3 × 1,09 = 2,5 (0 %). Sans combo : −8 %, dans la cible.
- **Variantes** : Pilier de flamme (remplace la Nova) : son premier tick sur un marqué fait +30 % et consomme ; Pluie de météores (remplace Cendres) : chaque impact marque, pas de +1 s ; Braises errantes (sort 1) : chaque touche d'orbe prolonge la marque de 0,6 s comme l'Éclat.

### 3.2 A-2 « Cendres → Brasier » (flambée)

- **Préparation** : une Cendres active dans les 6 u du Brasier, avec des marqués dedans.
- **Fenêtre** : vie de la Cendres (5 s, 6 s si A-1 l'a prolongée).
- **Récompense** : **Brasier** (ou explosion finale du Phénix) : **+1,0 coef par marqué** (nouvelle `BRASIER_EMBER_ADD` 1,0, plage 0,6-1,2 ; sur un boss marqué 7,4 + 1,0 = 8,4, soit +14 % sur lui) ; toute Cendres dans le rayon **s'éteint en flambée** instantanée coef 2,0 dans ses 2,5 u (`ASH_FLARE_COEF` 2,0, proc 1,0). `BRASIER_COEF` 8 → **7,4**.
- **Ordre inverse** (Brasier → Cendres) : valide : la Cendres posée après prolonge la brûlure sur un paquet déjà repoussé ; pas de flambée.
- **Mobile** : Brasier autour de lui, Cendres sur le paquet dense : naturel dès qu'il combat sur sa Cendres (ce que A-1 encourage).
- **Retour** : la Cendres se contracte puis éclate (anim `end` de `ardent_ashes` à ×2 de vitesse + `ardent_nova` à l'échelle 2,5 u), grondement « lourd ».
- **Équilibrage** : zone 5 avec une Cendres : 5 × 7,4 + 3 × 1,0 + 5 × 2,0 = 50 contre 40 aujourd'hui (+25 % sur la fenêtre, borne haute : justifié parce que l'ultime d'Ardent est le plus faible du roster en zone et que le gain exige une Cendres bien placée) ; boss : 8,4 contre 8 (+5 %). Sans combo : 7,4 (−8 %).

### 3.3 A-3 « Éclat → Nova » (l'esquive qui prépare, sans Cendres)

- **Préparation** : **Éclat** (téléportation 3 u). La **silhouette de braises** laissée au départ (0,35 s, existante) **marque** les monstres à ≤ 1,2 u d'elle (`BLINK_MARK_U` 1,2) : ceux qui étaient sur lui. **Aucun dégât** (règle 5).
- **Fenêtre** : 1,5 s, prolongée par l'Éclat de braise (auto) qui tire sur le plus proche, donc sur eux pendant qu'ils le poursuivent (+0,6 s par touche, plafond 3 s). Un T1 à 2,5 u/s refait les 3 u en 1,2 s : il arrive **marqué** à portée de Nova.
- **Récompense** : la Nova (auto à 3 u) fait +30 % sur eux (même constante `NOVA_EMBER_MULT`). Séquence complète du débutant : encerclé → Éclat → ils reviennent → Nova.
- **Mobile** : bouton d'esquive + joystick, Nova automatique : **naturel**, sans visée.
- **Retour** : la silhouette de braises **souffle** sur les marqués (la gerbe `out` existante, orientée vers eux), braises qui montent.
- **Équilibrage** : une Nova par 6 s sur ≈ 3 marqués : +0,3 × 2,3 × 3 / 6 s ≈ +0,35/s sur ≈ 10/s en zone = 3,5 %, sous le plafond de 5 % de l'esquive. Aucune compensation au-delà de `NOVA_COEF` 2,3.
- **Risque** : Ardent apprend à blinker **dans** le paquet pour la Nova (ordre agressif). C'est permis et dangereux (recharge 3 s, il ressort à pied) : c'est la ligne de maîtrise du débutant, pas une dégénérescence. Garde-fou : la marque n'est posée qu'au **départ**, jamais à l'arrivée.

---

## 4. Averse, la porteuse de pluie (`averse_kit.gd`)

**Identité** : l'eau est sa seule limite ; elle dépense pour frapper, pour courir, et récupère sur ce qu'elle a mouillé.

**État** : la **trempe** (`_soak`, clé `slow` 30 % 4 s, dictionnaire `_soaked_until`), posée par Vague, Flaque, Crue, Geyser, Gouttière, Mousson, et **lue par rien**. À exposer par `is_soaked(e)`. Visuel : gouttes cyan qui perlent sur le monstre (particule unique de `puddle_mirror` à l'échelle 0,3 u, teinte `PUDDLE_VFX_TINT`) ; les boutons de la Crue et de la Vague pulsent quand ≥ 3 trempés (ou un boss trempé) sont dans leur rayon. Ses sorts 2 et 4 n'ont **pas de recharge** (seule l'eau) : les fenêtres se paient en eau, c'est la différence avec les autres kits.

### 4.1 AV-1 « Vague → Crue » (combo principal : emporter)

| Étape | Geste | Effet | Constantes |
|---|---|---|---|
| Préparation | **Vague** (20 d'eau ; PC curseur, manette stick, mobile paquet dense) | cône 6 u / 70° : 3,5, trempés 4 s, recul 1,5 u | `WAVE_COST` 20, `WAVE_COEF` 3,5, `SOAK_S` 4 |
| Fenêtre | 4 s (`SOAK_S`) ; chaque Goutte-lame sur un trempé **rend +1,0 d'eau** en plus (AV-3) : la fenêtre **re-remplit** l'amphore pour la Crue | l'eau de la Vague revient en partie | `SOAK_HIT_WATER` 1,0 |
| Récompense | **Crue** (≥ 40 d'eau, `CRUE_CD` 12 s) | **+20 %** sur les trempés (nouvelle `CRUE_SOAK_MULT` 1,2, plage 1,15-1,3) et recul 3 → **4,5 u × masse** (`CRUE_SOAK_KNOCK_U` 4,5 ; boss : +20 % seulement) ; laisse sa Flaque | `CRUE_COEF_FULL` 9 → **8,6** (mesure du 29/10, §7.3 ; 8,2 seulement si le scénario manuel « Crue à 100 » dépasse 35 %) |

- **Ordre inverse** (Crue → Vague) : valide : la Crue trempe et laisse une Flaque ; la Vague lancée **depuis** cette Flaque est une Vague de fond (AV-2). Les deux ordres s'enchaînent en boucle : Vague → Crue → (Flaque) → Vague de fond → Gouttes qui rendent l'eau → Crue.
- **Mobile** : Vague sur le paquet dense, Crue autour d'elle : naturel dès que le paquet approche. Aide : `auto_cast_ok(4)` attend 0,5 s au plus après une Vague (ses trempés arrivent) ; règle `AUTO_CRUE_AT` 75 conservée.
- **Retour** : anneau de Crue plus brillant sur son passage (`CRUE_VFX_TINT` ×1,2 pendant 0,3 s), chiffres cyan, grondement « lourd ». Aucun VFX nouveau.
- **Équilibrage** : trempés estimés 70 % en zone, 90 % sur boss (AV-3 incite à tremper). Boss : 8,6 × (0,9 × 1,2 + 0,1) = 10,1 (+13 % sur la Crue, ≈ +5 % du kit) ; zone : +10 %. Sans combo : −4 % (le bot est déjà à 0,86-0,96, §7.3 : pas de marge pour une baisse plus forte). Le retour joueur « la Crue tape énormément » impose de rester sous +8 % sur boss : **levier 8,0** si le scénario « Crue à 100 » de l'audit sort de la cible (part de l'ultime ≤ 35 % du DPS). À 100 d'eau, une Crue vaut aujourd'hui 9,0 : la Vague à 20 d'eau rapporte 3,5 dans un cône + le +20 % de la Crue suivante : la Vague devient **rentable par rapport à l'attente** (elle ne l'était pas : audit §2.3 « la Crue écrase la Vague »).
- **Variantes** : Mousson (zone attachée 6 s) : ses ticks font +20 % sur les trempés, le premier tick trempe : elle se prépare elle-même après 0,5 s, acceptable (dégâts étalés) ; Geyser (remplace la Vague) : projection 0,8 s + trempe prépare la Crue à l'identique.

### 4.2 AV-2 « Flaque → Vague » (Vague de fond)

- **Préparation** : **Flaque-miroir** posée (18 d'eau, recharge 5 s, r 3, 6 s) ou la Flaque laissée par la Crue.
- **Fenêtre** : vie de la Flaque, 6 s.
- **Récompense** : **Vague** dont le cône traverse le centre de la Flaque, ou lancée **depuis** la Flaque : les touchés sont trempés **8 s / −40 %** au lieu de 4 s / −30 % (`WAVE_PUDDLE_SOAK_S` 8, `WAVE_PUDDLE_SOAK_PCT` 0,4) et prennent **+0,5 coef** (`WAVE_PUDDLE_ADD` 0,5, plage 0,3-0,7) ; la Flaque **n'est pas consommée** (elle pulse : `puddle_mirror` +15 % d'échelle 0,3 s).
- **Ordre inverse** (Vague → Flaque) : valide : la Flaque posée sur le paquet trempé prolonge la trempe et rend l'eau (`PUDDLE_GAIN_PER_S` 2,5 si Averse y reste) : c'est l'ordre « économie ».
- **Mobile** : Flaque et Vague visent le paquet dense : le cône traverse la Flaque dans la majorité des cas. **Naturel.**
- **Équilibrage** : +0,5 sur ≈ 50 % des Vagues ; `WAVE_COEF` 3,5 → **3,4** (3,3 si le simulateur manuel le demande). Trempe 8 s : la fenêtre de AV-1 double ; avec AV-3 l'eau revient plus vite sur un boss : surveiller l'économie d'eau (§4.4).
- **Variantes** : Gouttière (ligne 6 u) : Vague dans l'axe (≤ 35°) : même bonus ; Geyser sur Flaque : projection 0,8 → 1,2 s, trempe 8 s.

### 4.3 AV-3 « Goutte sur trempé » (le sort 1 recharge la fenêtre)

- **Déclencheur** : Goutte-lame (auto) qui touche un trempé.
- **Effet** : **+1,0 d'eau** en plus (0,5 → 1,5 ; élite / boss 1,0 → 2,0 ; `SOAK_HIT_WATER` 1,0) et **+0,25 coef** sur le trempé (`SOAK_GOUTTE_ADD` 0,25). Compensation : `HIT_WATER` 0,5 → **0,4**, `GOUTTE_COEF_MIN` 0,75 → **0,7**.
- **Pourquoi** : c'est ce qui fait de la trempe une **ressource** et non un simple ralentissement : mouiller d'abord, récolter ensuite. Sur un boss trempé en permanence, l'eau par Goutte revient à 2,0 (valeur d'avant l'audit P1) **mais seulement si Averse paie 20 d'eau toutes les 4 s** (ou 8 s avec AV-2) : le cycle est neutre à légèrement positif, la Vague reste un investissement.
- **Mobile** : automatique.
- **Retour** : « +N » cyan existant, plus gros ; éclaboussure (`mud_splash` teinté cyan en repli ; Codex : `splash_small`, 1 planche de 4 frames, facultatif).
- **Variante Bruine** : +0,33 d'eau par goutte sur trempé, plafond de salve `BRUINE_VOLLEY_WATER_CAP` 1,0 → 2,0.

### 4.4 AV-4 « Glissade → Crue » (l'esquive qui prépare : le sillage)

- **Préparation** : **Glissade** (esquive au maintien, 10 d'eau + 25/s, contact ignoré pendant, trace d'eau `slide_wake` 1 s). Proposition : la **trace** trempe les monstres qu'elle traverse ou qui la traversent : `slow` 30 % pendant **2 s** (`WAKE_SOAK_S` 2, `WAKE_SOAK_PCT` 0,3), **sans dégât**, sondage toutes les 0,25 s sur la polyligne (≤ 80 points, même méthode que `ArpenteuseKit._enemies_on`). C'est du contrôle (autorisé par la règle 6 des esquives) et une préparation.
- **Fenêtre** : 2 s de trempe (plus courte que la Vague : l'eau porte, elle ne mouille pas autant).
- **Récompense** : la Crue (ou la Vague) qui suit lit les trempés comme en AV-1 : +20 %. Séquence : encerclée → elle glisse **à travers** le paquet (contact ignoré) → ils sont dans son sillage, trempés → elle relâche, Crue. Coût réel : 10 + 25 × 0,5 s ≈ 22 d'eau pour traverser 4,5 u, comparable à une Vague (20) : la Vague fait des dégâts, la Glissade sauve la peau ; aucune des deux ne domine (règle 2).
- **Ordre inverse** (Crue → Glissade) : la Flaque laissée divise le drain par 2 (`SLIDE_WATER_DRAIN_MULT` 0,5, existant) : la Crue prépare la fuite. Déjà codé, à écrire dans le tip.
- **Mobile** : maintien du bouton + joystick, Crue sans visée : **placement**, pas de visée.
- **Retour** : la trace d'eau pulse là où un monstre la traverse (modulate ×1,4 sur le point de la `Line2D`, 0,2 s), gouttes sur le monstre. Aucun VFX nouveau.
- **Équilibrage** : aucun dégât direct ; +20 % de Crue sur ≈ 4 monstres une fois par 12 s au plus : ≈ 2 % du DPS. Risque : glisser **pour** tremper devient le réflexe et elle se fait tuer par les tireurs (projectiles non ignorés) : c'est le prix voulu (`Design_Esquives.md` §7 : lever 0,15 → 0,25 s d'i-frames si les tireurs dominent, jamais la trempe).

### 4.5 Économie d'eau (à passer au simulateur manuel)

AV-1 + AV-3 montent l'eau rendue sur un boss trempé : Goutte 2,0 × 1,67/s = 3,3/s au lieu de 1,67/s, soit **+1,67/s** contre une dépense de 20 par 4 s (5/s) pour entretenir la trempe à la Vague seule, ou 20 par 8 s (2,5/s) avec AV-2. Le cycle Vague de fond + Gouttes rend donc ≈ 1,67 − 2,5 = **−0,8/s** : la trempe reste un investissement, pas un moteur gratuit. Si le scénario « Crue à 100 » de l'audit (part de l'ultime) dépasse 35 %, baisser dans l'ordre : `CRUE_COEF_FULL` 8,2, puis `SOAK_HIT_WATER` 0,75. Ne pas toucher aux coûts (`WAVE_COST`, `PUDDLE_COST`) : la décision « l'eau est la seule limite » (22/10) tient.

---

## 5. Les sept autres personnages

Format court : identité · combo principal (séquence → récompense, chiffres) · esquive · changements de kit · retour · risque et garde-fou. Les détails de variantes et les combos secondaires restent dans `docs/Combos_Kits.md` §2 (références R, T, RN, AVR, B, V, TA) ; seuls les chiffres **repris ici** font foi en cas d'écart.

### 5.1 Rictus, pantin de la barge noyée (`rictus_kit.gd`, `decoy.gd`)
- **Identité** : le Montreur place ses doublures, le pantin les fait danser.
- **Combo principal « L'étoile armée »** : **Doublures** (6 sur un anneau de 1,2 u, 3 s) → **Éventail** : chaque couteau qui traverse une doublure la **charge** (une charge par doublure ; 2-3 par salve) → **Toupie** : les chargées expédiées font 1,2 → **1,6** en vol et explosent à 2,4 → **3,1** (`DECOY_CHARGE_ADD` 0,7, `FLIGHT_CHARGED_COEF` 1,6). Fenêtre 3 s (`DECOY_LIFE_S`). Ordre inverse (Toupie → Doublures) : valide, les doublures posées pendant la Toupie provoquent le paquet qu'elle traverse. Compensation `DECOY_COEF` 2,4 → **2,2** (sans combo −8 %, avec +4 %).
- **Esquive « Levée »** : atterrir à ≤ 2,4 u de doublures en attente les **détone tout de suite** (`LIFT_DETONATE_U` 2,4 ; charges comprises) : le joueur choisit le moment, l'invulnérabilité couvre l'explosion. Aucun dégât en plus (règle 5).
- **Changements** : `Decoy.charged` (0-1) lu par `explode_spell` / `flight_spell` (`decoy.gd` est partagé avec Bourbe : orchestrateur) ; `Decoy.hit_by` sur la trajectoire des couteaux.
- **Retour** : fissures `_e` de la doublure allumées en argent spectral (paramètre `charged`), grelot à la charge, six explosions synchrones à la Levée.
- **Risque** : la Levée devient un bouton d'ultime à retardement : elle a 3 s de recharge et les doublures 3 s de vie, la fenêtre d'abus est nulle. Mobile : les couteaux partent du centre de l'anneau, ils traversent toujours 1-2 doublures : naturel.

### 5.2 Tocsin, automate de crue (`tocsin_kit.gd`, `tocsin_limb.gd`)
- **Identité** : il se démonte pour frapper ; chaque membre lancé est une pièce posée sur la carte.
- **Combo principal « La cloche sur le pilier »** : **Bras-pilier** (zone 2,2 u, 10 ticks de 0,75 / 0,5 s, chaque tick pose l'étiquette `&"tocsin_charge"` via `add_damage_taken_mod(id, 1.0, 0.6)` : « électrisé ») → **Tête-cloche** à ≤ 4 u du pilier : **+50 %** sur les électrisés (`HEAD_CHARGE_ADD` 0,5, cumul additif avec `HEAD_BOSS_ADD` 0,3 : 1,8 sur un boss électrisé) et le pilier **sonne** : ses ticks restants partent d'un coup (0,75 × restants, plafond 5,0) puis le bras tombe, ramassable. Fenêtre 5 s (`PILLAR_S`). Ordre inverse (Tête → Bras) : valide, le pilier posé dans le cratère de la Tête ralentit (25 %) et finit le paquet repoussé. Compensation `HEAD_COEF` 10 → **8,5** ; ramassage du bras rendu bridé par la règle P7 de l'audit (recharge restante ×0,5 au ramassage, `PICKUP_CD_REFUND` 0,5), à coder dans le même lot.
- **Secondaire « Le Coup qui fait sonner »** : **Coup de tocsin** dont l'onde (3 u) atteint un pilier : décharge supplémentaire 1,5 dans ses 2,2 u et +2 ticks ; un bras au sol se **redresse** 2 s. `TOLL_COEF` 2,5 → **2,2**, `PILLAR_COEF` 0,75 → **0,7**.
- **Esquive « Vapeur »** : le nuage (1,2 u, 0,6 s, ralentissement 30 % 1 s) lâché **dans** un pilier en décharge ralentit les électrisés à **50 %** au lieu de 30 % (`STEAM_CHARGED_SLOW_PCT` 0,5) : contrôle, pas de dégâts. Naturel : il dashe vers son pilier pour ramasser le bras.
- **Retour** : `pillar_arc` flashe blanc 0,2 s puis s'éteint, tintement + crépitement « lourd ».
- **Risque** : le pilier vidé puis ramassé relance la boucle trop vite : P7 borne ; mobile : Tête et Bras visent le paquet dense : naturel, `auto_cast_ok(4)` : la Tête part si ≥ 4 monstres dans le rayon **ou** un pilier avec ≥ 2 monstres à portée.

### 5.3 Rainette, chevalière des roseaux (`rainette_kit.gd`, `rainette_goo.gd`)
- **Identité** : elle colle, puis elle écrase.
- **Combo principal « Écrasement »** : **Gluant** (flaque 2,5 u, 5 s, −40 %, attraction 0,9 u/s) → **Grand saut** qui atterrit **dans** la flaque : **+30 %** sur les collés (`CRUSH_ADD` 0,3 ; 3,4 → 4,4), étourdissement 0,5 → **1,0 s** (`CRUSH_STUN_S`), la flaque **éclate** : 1,2 dans 2,5 u (consommée). Fenêtre 5 s (`GOO_DURATION_S`). Ordre inverse (Grand saut → Gluant) : valide, le paquet étourdi 0,5 s se colle et reste : c'est l'ordre « tenir ». Compensation `LEAP_COEF` 3,8 → **3,4**, `GOO_SPLASH_COEF` 1,4 → **1,2** (DPS neutre, le gain est le burst et le contrôle). Audit P5 (Grand saut pendant le Chant = un seul impact) dans le même lot.
- **Secondaire « Langue sur étourdi »** : Langue dont la cible est étourdie ou collée : 1,1 → **1,6** et traction 0,25 → **0,75 u** (`TONGUE_STUN_COEF`, `TONGUE_STUN_PULL_U`). `TONGUE_COEF` 1,15 → **1,1**. Contrat : `Enemy.is_stunned()` (§6).
- **Esquive « Bond »** (arrière 3,5 u) : depuis une flaque de Gluant, le Bond prend le **+50 %** de distance des bonds (`GOO_HOP_BONUS`, déjà appliqué aux bonds : à étendre au Bond) ; aucun autre lien : l'esquive de Rainette est sa fuite, pas sa préparation.
- **Retour** : `goo` joue son `end` à ×2 + `land_ring` ×1,2, « splotch » lourd (Codex facultatif : `goo_burst`, 6 frames).
- **Risque** : sur mobile, Gluant et Grand saut visent tous deux le paquet dense : **le combo est le cas par défaut** ; la compensation de base est donc obligatoire. `auto_cast_ok(2)` attend le Gluant si sa recharge est < 1 s.

### 5.4 Avare, usurier des Terrasses (`avare_kit.gd`, `avare_bounce_coin.gd`)
- **Identité** : il marque ses débiteurs, puis il encaisse.
- **Combo principal « Rançon → Poignée »** : **Rançon** (r 3, étourdit 0,5 s, marque 4 s `RANSOM_MARK_S`, `is_marked(e)`) → **Poignée de pièces** : 1,1 → **1,8** par pièce sur un marqué (`COIN_MARKED_COEF` 1,8) et la pièce retombe à **100 %** de sa part du coût au lieu de 80 % (`COIN_MARKED_REFUND` 1,0 : le marqué rembourse ; **aucun or neuf**). Fenêtre 4 s. Ordre inverse (Poignée → Rançon) : valide, la Rançon étourdit le paquet sur les pièces tombées pour la Râfle. Compensation `COINS_COEF` 1,2 → **1,1**.
- **Secondaire « Faillite des marqués »** : Faillite +1,0 coef par marqué (`RUIN_MARKED_ADD`), or neuf inchangé ; `RUIN_BASE_COEF` 5 → **4,6**. « Coffre qui prolonge » : Coup de coffre sur un marqué : marque +0,5 s (plafond 6 s), coffre-bouclier 0,4 → 0,6 s.
- **Esquive « Râfle »** (2,5 u, ramasse ses pièces à 1,2 u) : elle est déjà la fin de la séquence Rançon → Poignée → Râfle (les pièces à 100 % reviennent en un geste). Aucun bonus de dégâts.
- **Retour** : pièce qui tinte en or, « ting » montant (son de rebond de la Pièce truquée), sceau `ransom_ring` qui re-pulse.
- **Risque** : économie : le 100 % ne crée pas d'or, `economy_test` à relancer ; Avare est déjà à 1,35 en mono (audit) : si le simulateur sort de 1,20, `COIN_MARKED_COEF` 1,6 avant toute autre chose.

### 5.5 Bourbe, mère-vase de la Mangrove (`bourbe_kit.gd`, `bourbe_motte.gd`)
- **Identité** : elle se partage en mottes ; se battre **au milieu** d'elles est sa position.
- **Combo principal « Gifle transmise »** : **Détacher** (mottes dehors, 15 % de masse chacune) → **Gifle de vase** dont l'arc passe sur une motte alliée (une fois par motte toutes les 2 s, `SLAP_FEED_CD_S`) : la motte regagne **10 %** de PV (`SLAP_FEED_HEAL` 0,1) et son prochain coup de contact fait **×3** (0,35 → 1,05 ; `SLAP_FEED_MULT` 3,0, Bouture ×2). Fenêtre : tant que la motte vit. Ordre inverse (Gifle → Détacher) : rien à lire, mais la motte lancée atterrit en plouf (1,4) sur le paquet giflé : valide. Compensation `SLAP_COEF` 1,0 → **0,85**, `MOTTE_CONTACT_COEF` 0,40 → **0,35** (net ≈ +8 %, levier `SLAP_COEF` 0,8).
- **Secondaire « La vase revient en déchirant »** : Bourbier lancé avec des mottes dehors : chaque motte éclate 1,0 dans 1,5 u avant de fusionner (`BOG_MOTTE_BURST_COEF`) ; `BOG_COEF` 1,2 → **1,1**. « Plouf de garde » : Rappel avec une motte à ≤ 1 u : plouf 1,4 autour d'elle au lieu d'une traversée vide.
- **Esquive « Coulée »** (traînée de vase 2 s, ralentissement 30 %) : les mottes qui **marchent dans la traînée** vont à 3,8 → **4,8 u/s** (`FLOW_TRAIL_MOTTE_SPEED_U`, elles suivent la mère dans sa vase) : elles rejoignent la Gifle plus vite ; contrôle et locomotion, pas de dégâts.
- **Retour** : follet de la motte qui flambe (`_e` ×2, 0,4 s), `mud_slap` qui déborde, « splotch » doublé.
- **Risque** : audit P4 : vérifier `Decoy.lures_bosses` faux pour `BourbeMotte` dans le même lot ; sinon Bourbe reste sans dégât subi sur mini-boss (critique).

### 5.6 Vigie, guetteuse de la digue (`vigie_kit.gd`, `vigie_flare.gd`)
- **Identité** : elle cloue, elle éclaire, elle perce.
- **Combo principal « Filet → Fusée → Allonge »** (la séquence complète) : **Filet lesté** (cloue 1,5 s, `imprisoned`, rend la Tension pleine) → **Fusée** qui s'arrête sur un cloué : la lumière s'allume **dans** le filet : exposition ×1,1 → **×1,25** tant qu'il tient, et le filet tient **+0,5 s** (`NET_FLARE_EXPOSE` 1,25, `NET_FLARE_EXTEND_S` 0,5) → **Trait d'allonge** (Tension pleine, perce tout) : 1,8 → **2,6** sur chaque exposé (`ALLONGE_EXPOSED_COEF` 2,6) et ravive la fusée (+1 s, plafond 7 s). Fenêtre 2 s de tenue. Ordre inverse (Fusée → Filet) : valide, le filet lancé dans la lumière cloue des exposés ; pas de ×1,25. Compensation `ALLONGE_COEF` 2,0 → **1,8**, `FUSEE_COEF` 1,2 → **1,0**.
- **Secondaire « Grêle sur cloués »** : +40 % par volée sur les cloués (`HAIL_NETTED_MULT` 1,4 ; Tir de signal 1,2) ; `GRELE_COEF` 0,7 → **0,64**.
- **Esquive « Repli »** (3 dashs de 1 u, +8 % de Tension chacun) : c'est déjà la préparation de l'Allonge (Tension) ; un Allonge tiré dans les 0,5 s après le **3e** dash part **sans** le délai d'ancrage (`ANCHOR_DELAY_S` 0,15 ignoré) : confort, pas de dégâts. Naturel : elle rompt vers l'arrière en gardant la cible en face (`dodge_motion_dir`).
- **Retour** : filet (`net_burst`) teinté rouge pendant la tenue, traînée `arrow_charged` plus longue, éclat de magnésium sur la fusée.
- **Risque** : sur un boss exposé en permanence (Fusée + Grêle), l'Allonge seule gagne +20 % : ≈ +7 % du kit, limite haute ; levier `ALLONGE_COEF` 1,7.

### 5.7 Taliant, rōnin d'écorce (`morfil_kit.gd`)
- **Identité** : une lame qui s'use à chaque geste et qu'un seul geste rend.
- **Combo principal (existant)** : **Aiguisage** (100 %) → **Lames jumelles** (seuil `SHARP_ULT_MIN` 90 %) → **Fauche-lune** à 100 % (4,0 ; à 50 % : 2,0). La ressource est la fenêtre ; rien à ajouter.
- **Esquive « Iaï »** (dash tranchant 1,5, 4 % d'aiguisage s'il touche) : **Iaï → Fauche-lune** dans les 1,5 s (`IAI_OPEN_S`) : coût 15 → **8 %** d'aiguisage (`COST_CRESCENT_AFTER_IAI` 8) et recul 1,0 → 1,4 u (la lame est déjà dégainée). Gain ≈ +3 % d'aiguisage moyen, sous le plafond de 5 %. Mobile : esquive puis bouton 2, la Fauche vise le paquet qu'il vient de traverser : **naturel**.
- **Secondaire « Garde qui rend »** : un coup encaissé sous garde (`guard_left > 0`) rend **+2 %** d'aiguisage, une fois par 0,3 s (`PARRY_SHARP` 2, `PARRY_CD_S` 0,3) : atténue la faiblesse « début de run » de l'audit (0,79 en mini-boss L6) sans toucher aux coefs.
- **Retour** : `iai_trail` qui reste 0,3 s de plus et s'embrase à la Fauche ; scintillement du fil de sève à la parade (Codex : 1 son `morfil_parry`).
- **Risque** : aucun ; Taliant est déjà 4/5 d'interactivité.

---

## 6. Lot transverse (orchestrateur, avant les lots par personnage)

| Élément | Fichier | Contenu |
|---|---|---|
| Retour générique de combo | `scripts/spells/spell_caster.gd` (affichage des chiffres), `data/audio/sounds.json` | `deal_damage(enemy, s, hit)` lit `hit["combo"] == true` : chiffre dans la couleur d'accent du personnage (`ACCENT` du kit, blanc sinon) ; son du sort en variante « lourde » existante **+2 demi-tons** (modulation déjà codée, règle « le son suit la puissance du coup »). Un son `spell.<perso>.combo` par personnage est **facultatif** (Codex `art/tools/audio/`, lot audio ultérieur). |
| Fenêtre visible sur le HUD | `scripts/ui/` (barre de sorts, boutons tactiles), contrat `CONTRACTS.md` | nouveau hook facultatif `kit.combo_ready(slot) -> bool` sondé toutes les 0,1 s : le bouton du sort **pulse** dans la couleur d'accent (modulate du cadre existant, 0,6 s de période, aucun sprite nouveau). Tactile, barre PC et manette : le même cadre. ux-designer à consulter pour l'amplitude (lisible sans gêner). |
| Étiquette lisible par tous | `scripts/enemies/enemy.gd`, `CONTRACTS.md` | convention : `add_damage_taken_mod(id, 1.0, duration)` = étiquette sans effet (Tocsin `&"tocsin_charge"`) ; `Enemy.is_stunned() -> bool` (`_stop_left > 0`) pour Rainette et Avare. |
| Marque de kit | modèle `AvareKit.marks` | dictionnaire `{instance_id: fin}` + `is_marked(e)`, nettoyé par le temps et protégé contre le recyclage du pool ; copié par Ardent (`marks` braise) ; Averse expose `is_soaked(e)` sur `_soaked_until`. |
| Nœud kit d'Ardent | `scripts/spells/ardent_base_kit.gd` (nouveau) ou `ArdentTracker` promu | chargé par `CharacterData.for_id` même sans variante ; `ArdentVariantKit` en hérite ; porte `marks`, `on_dodge_end` (marque au départ : la position de départ est `from`), `on_spell_hit`. |
| Doublures partagées | `scripts/spells/decoy.gd` | champ `charged := 0.0` lu par `explode_spell` / `flight_spell` (coef × (1 + charged)) ; sans effet pour Bourbe tant qu'elle ne le pose pas. |
| Aide de visée mobile (option, §8 Q3) | `SpellCaster.densest_point(range_px)` | pondère ×1,5 les monstres pour lesquels `kit.is_marked(e)` est vrai (Ardent, Avare, Tocsin, Vigie, Averse via `is_soaked`) : une seule règle pour tous les combos à marque, derrière l'option d'accessibilité « visée automatique ». |

---

## 7. Récapitulatif et ordre d'implémentation

### 7.1 Tableau

| Perso | Combo principal (préparation → récompense) | Bonus sur la fenêtre | Fenêtre | Esquive | Compensation | Mobile | Nouvelles constantes (kit) |
|---|---|---|---|---|---|---|---|
| **Arpenteuse** | Trait → Piquet → Tendeur (double chaîne) ; Tendeur → Halage ; Trait → Halage | existant (+95 % de ticks de lignes) ; +0,5 sur emprisonnés ; +0,5 sur segment tendu | 5 s / 1,5 s / 1,5 s | **prépare** (chaîne tendue) | aucune | naturel | `HALAGE_HELD_ADD` 0,5, `HALAGE_TAUT_ADD` 0,5, `CROSS_FLASH_ENERGY` 6,0 |
| **Ardent** | Cendres → Nova ; Cendres → Brasier ; Éclat → Nova | +30 % sur marqués, Cendres +1 s ; +1,0 par marqué + flambée 2,0 ; +30 % | 1,5 s (3 s max) / vie de la Cendres / 1,5 s | **prépare** (silhouette de braises marque) | `NOVA_COEF` 2,3, `BRASIER_COEF` 7,4 | naturel, aidé | `EMBER_MARK_S` 1,5, `EMBER_MARK_MAX_S` 3, `EMBER_MARK_EXTEND_S` 0,6, `NOVA_EMBER_MULT` 1,3, `ASH_EXTEND_S` 1,0, `BRASIER_EMBER_ADD` 1,0, `ASH_FLARE_COEF` 2,0, `BLINK_MARK_U` 1,2 |
| **Averse** | Vague → Crue ; Flaque → Vague ; Goutte sur trempé ; Glissade → Crue | +20 % et recul 4,5 u ; +0,5 et trempe 8 s / 40 % ; +1 d'eau, +0,25 ; sillage qui trempe 2 s | 4 s (8 s) / 6 s / — / 2 s | **prépare** (sillage) et **sort** (Flaque ÷2 drain) | `CRUE_COEF_FULL` 8,6 (plage 8,2-9,0, §7.3), `WAVE_COEF` 3,4, `HIT_WATER` 0,4, `GOUTTE_COEF_MIN` 0,7 | naturel, aidé | `CRUE_SOAK_MULT` 1,2, `CRUE_SOAK_KNOCK_U` 4,5, `WAVE_PUDDLE_ADD` 0,5, `WAVE_PUDDLE_SOAK_S` 8, `WAVE_PUDDLE_SOAK_PCT` 0,4, `SOAK_HIT_WATER` 1,0, `SOAK_GOUTTE_ADD` 0,25, `WAKE_SOAK_S` 2, `WAKE_SOAK_PCT` 0,3, `is_soaked(e)` |
| Rictus | Doublures → Éventail (charge) → Toupie | +0,7 par doublure chargée, vol 1,6 | 3 s | **déclenche** (Levée détone, sans bonus) | `DECOY_COEF` 2,2 | naturel | `DECOY_CHARGE_ADD` 0,7, `FLIGHT_CHARGED_COEF` 1,6, `LIFT_DETONATE_U` 2,4 |
| Tocsin | Bras-pilier → Tête-cloche ; Coup → pilier | +50 % sur électrisés + décharge ≤ 5,0 ; 1,5 + 2 ticks | 5 s | **contrôle** (Vapeur dans le pilier : 50 %) | `HEAD_COEF` 8,5, `TOLL_COEF` 2,2, `PILLAR_COEF` 0,7, P7 ×0,5 | naturel, aidé | `CHARGE_TAG`, `HEAD_CHARGE_ADD` 0,5, `PILLAR_RING_COEF` 1,5, `PILLAR_RING_TICKS` 2, `PICKUP_CD_REFUND` 0,5, `STEAM_CHARGED_SLOW_PCT` 0,5 |
| Rainette | Gluant → Grand saut ; Langue sur étourdi | +30 %, étourdit 1 s, flaque éclate 1,2 ; 1,6 et traction 0,75 u | 5 s / 1 s | **fuite** (Bond +50 % depuis le Gluant) | `LEAP_COEF` 3,4, `GOO_SPLASH_COEF` 1,2, `TONGUE_COEF` 1,1 | naturel (par défaut) | `CRUSH_ADD` 0,3, `CRUSH_STUN_S` 1,0, `TONGUE_STUN_COEF` 1,6, `TONGUE_STUN_PULL_U` 0,75 |
| Avare | Rançon → Poignée ; Faillite sur marqués | 1,8 par pièce + retombée 100 % ; +1,0 | 4 s (6 s) | **termine** (Râfle ramasse) | `COINS_COEF` 1,1, `RUIN_BASE_COEF` 4,6 | naturel, aidé | `COIN_MARKED_COEF` 1,8, `COIN_MARKED_REFUND` 1,0, `RUIN_MARKED_ADD` 1,0, `SWING_MARK_EXTEND_S` 0,5, `MARK_MAX_S` 6, `SWING_MARKED_GUARD_S` 0,6 |
| Bourbe | Détacher → Gifle sur motte ; Bourbier avec mottes | soin 10 %, coup suivant ×3 ; éclat 1,0 par motte | vie de la motte / — | **locomotion** (mottes 4,8 u/s dans la traînée) | `SLAP_COEF` 0,85, `MOTTE_CONTACT_COEF` 0,35, `BOG_COEF` 1,1 | placement | `SLAP_FEED_HEAL` 0,1, `SLAP_FEED_MULT` 3,0, `SLAP_FEED_CD_S` 2, `BOG_MOTTE_BURST_COEF` 1,0, `RECALL_HOME_U` 1,0, `FLOW_TRAIL_MOTTE_SPEED_U` 4,8 |
| Vigie | Filet → Fusée → Allonge ; Grêle sur cloués | ×1,25 + 0,5 s, Allonge 2,6 ; +40 % | 2 s | **prépare** (Tension +24 %, ancrage ignoré) | `ALLONGE_COEF` 1,8, `FUSEE_COEF` 1,0, `GRELE_COEF` 0,64 | naturel, aidé | `ALLONGE_EXPOSED_COEF` 2,6, `NET_FLARE_EXPOSE` 1,25, `NET_FLARE_EXTEND_S` 0,5, `FLARE_REVIVE_S` 1,0, `HAIL_NETTED_MULT` 1,4, `SIGNAL_NETTED_MULT` 1,2 |
| Taliant | Aiguisage → Lames jumelles → Fauche-lune (existant) ; Iaï → Fauche-lune | coût 15 → 8 %, recul 1,4 u ; parade +2 % | 1,5 s | **prépare** (Iaï dégaine) | aucune | naturel | `IAI_OPEN_S` 1,5, `COST_CRESCENT_AFTER_IAI` 8, `IAI_OPEN_KNOCK_U` 1,4, `PARRY_SHARP` 2, `PARRY_CD_S` 0,3 |

### 7.2 Ordre recommandé

1. **Lot 0 transverse** (§6, orchestrateur : `spell_caster.gd`, `enemy.gd`, HUD, `CONTRACTS.md`) : retour `hit["combo"]`, hook `combo_ready(slot)`, `is_stunned()`, convention d'étiquette. Sans lui, aucun combo ne se lit.
2. **Arpenteuse** (`HALAGE_HELD_ADD`, `HALAGE_TAUT_ADD`, `CROSS_FLASH_ENERGY`, `combo_ready`) : le plus petit lot, sur le personnage que le joueur connaît le mieux : il **valide le retour générique et la pulsation du HUD** sur des combos déjà ressentis, avant d'en inventer. Test : `tests/arpenteuse_combos_test.tscn` (Tendeur puis Halage → 4,0 sur emprisonnés, attraction 0 ; Trait puis Halage → 4,0 sur le segment tendu seulement).
3. **Averse** (`is_soaked`, AV-1 à AV-4) : état existant, personnage très joué, et la Crue est le point critique de l'audit : le lot règle les deux en même temps. Test : `tests/averse_combos_test.tscn` + relance du scénario « Crue à 100 » (part de l'ultime ≤ 35 %) et de `dodge_test` (sillage).
4. **Ardent** (`ArdentBaseKit`, marque braise, A-1 à A-3) : demande un contrat (nœud kit de base), donc après les deux premiers ; personnage de référence du simulateur : mesurer avec et sans `auto_cast_ok`. Test : `tests/ardent_combos_test.tscn`.
5. Puis, en parallèle (périmètres disjoints, un agent Sonnet par lot) : **Rainette** (combo par défaut sur mobile : compensation urgente), **Tocsin** (+50 % orphelin de la Tête), **Vigie**, **Avare** (relancer `economy_test`), **Rictus** et **Bourbe** (tous deux via `decoy.gd` : séquentiels ou orchestrateur), **Taliant** (léger).
6. Après chaque lot : `balance_sim_run.tscn --chars=<id> --cfg=L1,L6,L12`, avec et sans la règle `auto_cast_ok` (systems-designer) ; descriptions de sorts dans `data/characters.json` (fichier partagé : textes livrés dans le rapport, fusion par l'orchestrateur) ; un tip par combo (`tips.json`) ; 5 min de `capture_hit_feel` par personnage pour les combos de placement.

### 7.3 Mesures de référence (29/10/2026)

Combats scriptés `balance_sim_run.tscn --chars=ardent,averse,arpenteuse --cfg=L6,L12 --scen=mixed,elite,miniboss` (bot en lancer automatique, 1 graine, `RESULT: OK`, 0 erreur). Ratio = durée d'Ardent / durée du personnage (> 1 : plus rapide qu'Ardent) ; ils servent de « avant » pour les lots 2-4.

| Perso | L6 mixte | L6 élite | L6 mini-boss | L12 mixte | L12 élite | L12 mini-boss | Dégâts subis (L6 mixte / mini-boss) |
|---|---|---|---|---|---|---|---|
| Ardent | 18,7 s (réf.) | 23,4 s | 19,2 s | 15,8 s | 13,1 s | 20,7 s | 38 / 62 |
| Averse | 21,7 s → **0,86** | 24,6 s → 0,95 | 22,1 s → **0,87** | 16,7 s → 0,95 | 13,6 s → 0,96 | 23,4 s → **0,88** | 13 / 144 |
| Arpenteuse | 30,4 s → **0,61** | 17,1 s → **1,37** | 17,6 s → 1,09 | 18,7 s → 0,85 | 9,6 s → **1,36** | 18,6 s → 1,11 | 153 / 151 |

Lecture : **Averse en bot est tombée à 0,86-0,96** (audit du 23/10 : 1,03) depuis les baisses P1 et la recharge de 12 s de la Crue : la compensation `CRUE_COEF_FULL` 9 → 8,2 proposée en §4.1 la mettrait **sous 0,85 sans combo**. Révision : **`CRUE_COEF_FULL` 9,0 → 8,6** (plage 8,2-9,0), `WAVE_COEF` 3,5 → 3,4, et ne descendre à 8,2 que si le scénario manuel « Crue à 100 » (part de l'ultime) dépasse 35 % : le problème critique de l'audit est le jeu **manuel** (Crue toujours pleine), que le bot ne reproduit pas. Arpenteuse élite 1,37 (cible 1,30) : légèrement au-dessus, sans rapport avec ce document (`PEG_IMMUNITY_S` 0,65 → 0,7 si le joueur veut la ramener) ; zone 0,61 = biais du bot. Rappel des limites (`docs/Equilibrage_Personnages.md` §0) : le bot ne trace pas la chaîne d'Arpenteuse, lance la Crue à 75 d'eau, n'enchaîne aucun combo à ordre : les gains ci-dessus sont **estimés** tant qu'un lot n'a pas encodé sa règle `auto_cast_ok`.

---

## 8. Points à trancher par le joueur

1. **Compensation des bases** (règle 3) : baisser le sort de base de 5-10 % pour que le combo « se sente » (recommandé, Sirlin : la version sans combo devient un peu plus faible, c'est le prix d'une courbe d'apprentissage) **ou** base inchangée et combos à la moitié des chiffres (+10-15 %, plus discrets).
2. **Ardent, A-3** : la silhouette de braises de l'Éclat marque-t-elle les monstres (esquive qui prépare, recommandé) **ou** l'esquive d'Ardent reste-t-elle purement défensive (le débutant n'a alors que Cendres → Nova / Brasier) ?
3. **Aide de visée mobile** : `densest_point` pondéré ×1,5 sur les marqués / trempés (une règle pour cinq personnages, derrière l'option « visée automatique », recommandé) **ou** aucune aide (les combos à marque se font sur le paquet dense de toute façon) ?
4. **Averse, AV-4** : le sillage de la Glissade trempe-t-il (recommandé : c'est la seule façon d'intégrer son esquive au combo, et elle paie déjà en eau) **ou** la Glissade reste-t-elle une pure fuite ?
5. **Averse, AV-2** : la Vague de fond ne consomme pas la Flaque (recommandé : la Flaque est sa source d'eau) **ou** la consomme contre un bonus plus gros (+1,0) ?
6. **Pulsation du bouton** (`combo_ready`) : sur les trois plateformes (recommandé) **ou** seulement en tactile (sur PC le joueur voit les marques) ?
