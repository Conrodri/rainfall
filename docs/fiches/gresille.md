# Grésille, la paratonnerrière (fiche complète ; électricité, distance moyenne, statut « Statique »)

> *« Un mât qu'on retourne appelle. Je sais aussi retourner. »*

> Statut : **proposition de game design** (Fable, designer-fable, 08/11/2026), sur demande du joueur : *« il faudrait un personnage avec des dégâts électriques »*. Rien n'est implémenté ; aucun fichier de `game/` ni de `data/` n'est modifié. Lore : `docs/Lore.md` §11.11.
> **Décisions du joueur (09/11/2026)** : le nom **Grésille** est retenu ; le déblocage est « **Foudroyer 100 monstres avec l'Éclair en bouteille** » ; le Semeur de pluie est un **vengeur** qui noie le Val volontairement, par rancune contre la Cité et ses paratonnerres (`docs/Lore.md` §1.2-1.3, §2) : §1 de cette fiche révisé en conséquence. Restent à trancher : §13 (accent lilas, statut « mouillé » partagé). Modèle de fiche : `docs/fiches/vigie.md` (lecture joueur) et `docs/fiches/morfil.md` (détail technique) ; cadre d'équilibrage : `docs/Equilibrage_Personnages.md` (mono-cible dans [0,85 ; 1,20] × Ardent), `docs/Design_Combos.md` (un état par personnage, +20 à +30 % sur les cibles préparées), `docs/Design_Feel_Sorts.md` (frames d'impact, hitstop, cancel), `docs/Variantes_Sorts.md` (±15 % du sort de base), `docs/Design_Esquives.md` (l'esquive ne dépasse jamais 5 % du DPS), `docs/Skins.md`.
> Conventions : 1 u = 64 px ; « coef » = multiple de `Balance.player_base_damage(L)` = 12 + 2,4 (L−1), commun à tous ; recharge effective = base × `cooldown_mult`, plancher `Balance.COOLDOWN_FLOOR` = 0,35 ; procs = chance × proc_coef. Télégraphes ennemis ≥ 0,8 s ; aucune mort instantanée ; trois plateformes (sort 1 automatique partout, sorts 2-4 au curseur sur PC, stick droit à la manette, ciblage automatique sur mobile).

| | |
|---|---|
| **Nom** | **Grésille** (id technique : `gresille` ; nom tranché le 09/11/2026) : *grésiller*, le crépitement d'un arc électrique sous la pluie ; *grésil*, la pluie qui pique. Un mot, féminin, comme Averse, Vigie, Bourbe. |
| **Titre** | « Paratonnerrière de la Cité » |
| **Rôle** | Électricité : distance moyenne (7-8 u), arcs qui rebondissent, **Statique** qui s'empile et foudroie ; conduction dans l'eau |
| **Difficulté** | ★★☆☆☆ (2/5) : se joue au bouton ; la subtilité est de laisser monter la Statique avant de décharger |
| **Config** | 4 sorts / 0 passif (la Statique est l'état du kit, pas un slot ; « Isolée » est un trait intégré) |
| **Accent** | lilas d'arc `#B9A6FF`, cœur blanc `#F2EEFF` |
| **Points forts** | paquets moyens (3-8), cibles **mouillées**, contrôle par étourdissement, synergie coop avec Averse |
| **Points faibles** | fragile (95 PV, armure 5), rien de persistant à longue portée, dépend d'ennemis groupés pour ses arcs, lente à monter en Statique sur un boss seul |

---

## 1. L'histoire

La Cité avait semé des paratonnerres du canal jusqu'aux rizières, et il fallait quelqu'un pour **grimper dessus** : polir le bronze, vérifier la mise à la terre, remplacer les isolateurs de verre. C'était son métier. Elle montait aux mâts par tous les temps, des bouteilles de Leyde dans le dos pour **mesurer la charge** qu'ils rendaient au sol, et elle connaissait chaque mât du Val au toucher.

Elle savait aussi ce que les mâts coûtaient. On ne grimpe pas cent fois par an au-dessus du Val sans voir les rizières se fendre, les norias tourner à vide, la file des Terrasses descendre boire à la Source l'année sans mousson. Elle l'a dit aux fondeurs, à sa hauteur d'ouvrière, et on lui a répondu ce qu'on avait répondu au Fontainier : le canal est plein. Elle a continué à polir. C'était son métier, et elle avait des bouteilles à remplir.

La nuit de la Grande Crue, elle était en haut d'un mât quand l'orage est arrivé. Elle a senti, par la paume, **le bronze tirer dans le mauvais sens** : le mât n'écoulait plus la foudre vers la terre, il la **tirait du ciel**. Tous les mâts du Val se sont mis à appeler la même nuit, parce que le mât-mère, à la Source, venait d'être retourné. Elle est redescendue vivante parce qu'elle portait ses bottes de gutta-percha. Ses bouteilles de Leyde, elles, étaient pleines à craquer. Elles le sont restées.

Depuis, elle descend le chemin de l'eau avec la foudre dans le dos. Elle est la seule du Val à savoir **ce qui s'est passé** : l'orage n'est pas venu, il a été appelé, et elle sait par qui et pourquoi : par le gardien de la Source à qui la Cité avait planté un clou dans son lac, et que personne n'a écouté, elle comprise. Elle ne conteste pas la rancune. Elle conteste la sentence : on n'assèche pas un tort en noyant une vallée, et un mât qui appelle, on peut le remettre à l'endroit. Elle ne veut pas tuer le Semeur de pluie. Elle veut **mettre la main sur le mât**, et il faudra passer par lui : de tout le Val, elle est la main qu'il a le plus de raisons de haïr, celle qui polissait le bronze.

---

## 2. À quoi elle ressemble

- **Silhouette** (1,35 u) : une femme compacte, carrée d'épaules, **pas d'arme longue** (ce qui la distingue de Vigie et de son arc, de Taliant et de son sabre, d'Arpenteuse et de son trépied). Ce qu'on reconnaît de loin, au milieu de 250 monstres :
  - deux **bouteilles de Leyde** (bocaux de verre fumé cerclés de cuivre, gros comme des jarres de 0,4 u) portées dans le dos sur un **râtelier de bois ciré**, d'où partent des câbles gainés de tissu jusqu'à ses gants ;
  - une **tige de paratonnerre courte** (0,9 u, bronze vert-de-gris, pointe polie) tenue à la main droite comme un bâton de marche, avec **trois isolateurs de verre bleu** empilés sous la pointe, comme des assiettes ;
  - une **cape-treillis** : une cotte de mailles fines de cuivre sur les épaules, qui goutte et scintille (sa cage de Faraday : c'est pour ça qu'elle est encore vivante).
- **Détails** : **bottes de gutta-percha** noires, lourdes et lisses comme des bottes de scaphandrier ; gants de toile caoutchoutée à manchettes ; une **ceinture d'outils** (pince, brosse de laiton, mètre à ruban) ; cheveux serrés en chignon traversé d'épingles de cuivre (quelques mèches **se dressent** quand la Statique monte autour d'elle) ; peau olive, cernes, bouche serrée. Pas d'héroïsme : une ouvrière des hauteurs.
- **Palette** : cuivre vert-de-gris `#4F6B5E` (tige, cerclages, cape), cuir ciré noir `#1F2124` (bottes, râtelier), verre fumé `#3B4A5C` (bouteilles, isolateurs éteints), laine grise `#5A5E66` (veste), toile brune `#4A3F33` (gants, ceinture), peau olive `#B89E86`. Tout est mat et mouillé sauf **une seule chose qui luit : le lilas d'arc `#B9A6FF`**, dans les bouteilles de Leyde (un arc qui court à l'intérieur, plus vif quand une Décharge est prête), sur les isolateurs de la tige, et dans ses cheveux dressés quand elle canalise l'ultime. Le masque `_e` des bouteilles est **modulé par le code** : recharge de la Décharge 0 → 100 % = énergie 0,6 → 3,0 (10 paliers, même mécanisme que l'amphore d'Averse).
- **Lisibilité** : la seule chose **violette** du roster ; ses arcs sont des `Line2D` lumineuses d'un blanc lilas, les seules lignes brisées à l'écran (la chaîne d'Arpenteuse est continue et cuivre). Dans le Gouffre luisant (mycélium `#C27BFF`), le lilas est plus pâle et plus bleu que le biome ; si la planche de contact montre une confusion, le liseré `body_gain` du biome ou un cœur plus blanc tranchera (question §13.1).
- **Rendu** : CEL (contrat `_cel`, aplats 2-3 tons, encrage brun-noir), DA `STYLE_boss_da.md`, rig CREA iso 30°, 8 directions, cadre 192² à R = 90,51 px/u, pas de `_n`, `_e` pour l'accent.

---

## 3. Le principe

Grésille **charge** ce qu'elle touche. Chaque arc dépose une **Statique** (1 à 5 cumuls, 6 s) sur le monstre ; à 3 cumuls il est **crispé** (ralenti 20 %) ; à 5, le prochain coup de Grésille le **foudroie** (étourdi 0,5 s, cumuls remis à zéro). Sa **Décharge** lit les cumuls de sa cible et les **libère en arcs** vers les voisins : plus la cible est chargée, plus la Décharge se propage. **L'eau conduit** : un monstre **mouillé** (trempé par Averse, dans une case d'eau `,` ou dans une flaque) prend **deux** cumuls par coup au lieu d'un, et les arcs sautent **2 u plus loin** vers lui ou depuis lui. Sa **Mise à la terre** électrise le sol sous ses pieds, et si ce sol est de l'eau, toute la nappe d'eau connexe s'électrise avec.

Le rythme : **arquer** le paquet (le sort 1 fait le travail), **voir** la Statique monter (arcs qui courent sur les monstres, chiffre de cumuls sur la cible visée), **décharger** sur le plus chargé, **foudroyer** ce qui atteint 5, et garder l'Orage pour quand le paquet est dense et mouillé. Elle ne gère ni jauge ni ressource : **l'état est sur les monstres**, pas sur elle (règle de `Design_Combos.md` : un seul état par personnage).

Ce qui la distingue du roster : Ardent brûle en zone autour de lui et sur la durée ; Vigie cloue et expose à longue portée ; Arpenteuse frappe ce qu'elle a parcouru ; Averse trempe et emporte ; **Grésille propage** : son dégât va de monstre en monstre, et il va plus loin dans l'eau. C'est la première interaction **élément × terrain** du jeu, dans un monde où il pleut : l'électricité y est à la fois l'arme la plus logique et la plus dangereuse.

---

## 4. Les sorts

| Slot | Sort | Entrée | Recharge | Coef | Portée / forme | proc |
|---|---|---|---|---|---|---|
| 1 auto | **Arc** | automatique | 0,6 s | **0,8** sur la cible + **rebond 0,45** sur un voisin à ≤ 2,5 u (≤ 4,5 u si mouillé) | 7 u, instantané (pas de projectile) | 0,9 (rebond 0,5) |
| 2 | **Décharge** | clic gauche / spell_2 | 7 s | **2,8 + 0,15 × n** sur la cible (n = cumuls consommés, ≤ 5 : +27 % au plus) ; **n arcs de 0,6** vers n voisins distincts à ≤ 3 u (≤ 5 u si mouillé) | 8 u, instantané | 1,0 (arcs 0,6) |
| 3 | **Mise à la terre** | clic droit / spell_3 | 10 s | zone **3 u** sous elle, 5 s : **0,45 / 0,5 s**, ralentissement 20 %, **+1 Statique par tick** ; sur de l'eau : la zone **suit la nappe connexe** jusqu'à 6 u de rayon | soi | 0,3 |
| 4 ultime | **Orage appelé** | clic molette / spell_4 | 22 s | canalisé **3 s** (marche à 70 %) : **6 coups de foudre** (1 / 0,5 s) sur le monstre le plus chargé à ≤ 7 u : cercle **1,5 u**, **1,3 + 0,05 × n** par coup, +1 Statique | 7 u | 1,0 |
| esquive | **Court-circuit** (trait) | dodge | 3 s | aucun dégât ; sillage 0,5 s : **+1 Statique** à tout monstre traversé | 3 u / 0,25 s, invulnérable | — |

### 4.1 Arc (automatique)
- Toutes les 0,6 s (`Balance.attack_interval`), un arc **instantané** (hitscan : aucun projectile, aucun temps de vol) de la pointe de la tige au monstre le plus proche à **7 u** (jamais le curseur, comme tous les sorts 1). Coef **0,8**, recul 0,2 u, proc 0,9. Puis l'arc **rebondit** une fois sur le voisin le plus proche de la cible à ≤ **2,5 u** (≤ **4,5 u** si la cible ou le voisin est mouillé) : coef **0,45**, proc 0,5, jamais deux fois le même monstre. Les deux reçoivent **1 Statique** (2 s'ils sont mouillés).
- Sans cible : rien (aucun arc à vide). Anim `attack` (4 frames, impact frame 2) : elle tend la tige, l'arc part à la frame d'impact. En marche, le haut du corps joue `attack`, les jambes continuent (comme Vigie).
- **Items** : `Lame jumelle` (auto), `Pointe perforante` : la traversée devient **un rebond de plus** (le Trait de Vigie traverse ; l'Arc saute), `Éclair en bouteille` : chaque arc qui touche tente sa foudre en chaîne (`SpellCaster._lightning`) : c'est **son objet**, le lore dit pourquoi (les bouteilles de Leyde sont dans son dos).

### 4.2 Décharge (clic gauche, 7 s)
- Visée : souris / stick ; mobile et manette au repos : **le monstre le plus chargé** à 8 u, sinon le plus proche (nouveau `target_mode` `&"most_stacked"`, qui retombe sur `nearest`). Instantané à la frame d'impact de `cast` (frame 3).
- Sur la cible : coef **2,8 + 0,15 × n**, n = ses cumuls de Statique, **consommés** (n ≤ 5 : 2,8 → 3,55, soit **+27 %** : dans la règle « +20 à +30 % sur les cibles préparées »). Recul 0,5 u, proc 1,0.
- Puis **n arcs** (un par cumul consommé) vers **n voisins distincts** à ≤ 3 u de la cible (≤ 5 u si la cible est mouillée ; un voisin mouillé est atteignable à 5 u même si la cible est sèche), coef **0,6** chacun, proc 0,6, **+1 Statique** à chaque voisin touché (2 si mouillé). Moins de voisins que de cumuls : les arcs en trop sont perdus (pas de double coup sur un même voisin : c'est la propagation qui est récompensée, pas la concentration). Les arcs ne déclenchent pas d'autres arcs (aucune chaîne infinie ; même règle que `_lightning` : « aucun proc en chaîne »).
- Sur un **boss** : cumuls consommés et bonus appliqués, arcs normaux vers ses serviteurs. Un boss à 5 cumuls déchargé n'est pas étourdi (§5) : il prend **+10 % de dégâts subis pendant 2 s** (`Enemy.add_damage_taken_mod(&"gresille_foudre", 1,1, 2,0)`).
- Justification écrite du bonus : le +27 % mono reste dans la règle ; les arcs sont un gain de **zone** (jusqu'à 5 × 0,6 = 3,0 répartis sur 5 monstres), pas de mono-cible, et ils demandent des voisins. Sans voisins, la Décharge vaut 2,8-3,55 : un sort 2 ordinaire (Nova d'Ardent 2,3 en zone, Fusée de Vigie 2,1 + exposition).

### 4.3 Mise à la terre (clic droit, 10 s)
- Elle plante la tige **à ses pieds** (anim `ground`, 6 frames, impact frame 3 : la tige entre dans le sol, un anneau lilas court au sol). Aucune visée : c'est son outil de **contact**, celui qui la sauve quand le paquet l'a rattrapée.
- Zone au sol **3 u** (+ `zone_size_add`), **5 s**, tick **0,5 s** : coef **0,45**, proc 0,3, **ralentissement 20 %** rafraîchi (clé `slow`, `is_slowed()` vrai : Cœur de glace), **+1 Statique par tick** (2 si mouillé, et dans la zone **tout le monde est mouillé** si la zone est sur l'eau). Un monstre qui reste 5 s dedans prend 4,5 coef et atteint 5 cumuls en 2,5 s : le prochain Arc le foudroie.
- **Conduction** : si la case sous Grésille est de l'eau (`,` ou `~` de la carte, `RaidKit.in_shallow` / `StageMap`) ou une Flaque-miroir d'Averse, la zone **n'est plus un disque** : elle **épouse la nappe d'eau connexe** (remplissage de proche en proche sur la grille de 1 u, plafonné à l'équivalent d'un rayon de **6 u** : 113 cellules). Le bassin entier grésille. C'est le moment signature du personnage sur les Terrasses, aux Cryptes et dans la Source ; dans la Cité et le Gouffre, l'eau est rare : le disque de 3 u suffit.
- Elle peut **s'éloigner** : la zone reste. Une seule Mise à la terre à la fois (relancer déplace la zone).
- **Items** : Rune de portée (+15 % de zone), Prisme de grêle forgé (zone qui ralentit), Cœur de glace.

### 4.4 Orage appelé (ultime, clic molette, 22 s)
- Elle lève la tige à deux mains (anim `call`, 8 frames : 2 frames de montée, impact frame 2, puis **boucle** de canalisation) et **devient le paratonnerre** : pendant **3 s**, un **coup de foudre toutes les 0,5 s** (6 coups) tombe sur **le monstre le plus chargé** à ≤ 7 u d'elle (égalité : le plus proche ; aucun monstre : le coup tombe à 1,5 u devant elle et ne fait rien). Chaque coup : cercle **1,5 u** (+ `zone_size_add`), coef **1,3 + 0,05 × n** (n = cumuls de la cible principale, **non consommés**, +25 % au plus), proc 1,0, recul 0,8 u × masse, **+1 Statique** à tout ce qui est dans le cercle (2 si mouillé). Un monstre à 5 cumuls frappé est **foudroyé** (§5) : l'ultime enchaîne naturellement les étourdissements sur ce qu'elle a chargé.
- Pendant la canalisation : elle **marche à 70 %**, le sort 1 est **suspendu** (la tige est levée), Décharge et Mise à la terre sont **permises** (la main gauche), l'esquive **interrompt** l'Orage (les coups restants sont perdus : le choix du joueur). Elle n'est **pas invulnérable** : l'Orage se lance d'une position sûre ou dans une Mise à la terre.
- Total : 6 × 1,3 = **7,8** sur une cible qui reste (jusqu'à 9,3 sur une cible à 5 cumuls), dans la fourchette des ultimes (Brasier 7,4 persistant, Grêle ≈ 9,4 en 2,5 s, Tête-cloche 12 instantanée).
- Visée : aucune (le ciblage par cumuls est la visée). Mobile : identique. Mode « sorts automatiques » : permis si ≥ 4 monstres à 6 u ou si une cible a ≥ 3 cumuls.

### 4.5 Court-circuit (esquive)
- `RollDodge` + hook : **3 u en 0,25 s**, invulnérable, recharge 3 s (`Balance.DODGE_*`), fantômes lilas. Le sillage **grésille 0,5 s** (`Line2D` texturée, largeur 0,6 u) : tout monstre dont le centre est traversé reçoit **+1 Statique** (2 si mouillé). **Aucun dégât** (`Design_Esquives.md` §1 règle 6 : l'esquive prépare, jamais n'encaisse). Sans direction : elle rompt à l'opposé de la visée.

---

## 5. L'état : Statique (et Foudroiement)

| Cumuls | Effet sur le monstre | Lecture |
|---|---|---|
| 1-2 | rien | un petit arc court sur lui (VFX `static_crawl`, 1 frame sur 3) |
| 3-4 | **crispé** : ralenti 20 % (clé `slow`, rafraîchi tant que les cumuls tiennent) | deux arcs, les membres tremblent (pas d'anim : modulation `_e` + VFX) |
| 5 | **au prochain coup de Grésille** (Arc, rebond, Décharge, arc de Décharge, tick de Mise à la terre, coup d'Orage ; pas le sillage) : **Foudroiement** : étourdi **0,5 s** (`Enemy.stun`), cumuls remis à **0**, flash blanc `#F2EEFF` 0,08 s, son « claquement ». **Boss** : jamais étourdi ; +10 % de dégâts subis 2 s à la place | chiffre « 5 » lilas au-dessus de la cible visée ; corps blanchi 1 frame |

- Durée d'un cumul : **6 s**, rafraîchie à chaque application (tous les cumuls expirent ensemble).
- **Mouillé** (voir §6) : chaque application donne **2 cumuls** au lieu d'un.
- Un monstre ne peut être foudroyé plus d'une fois par **1,5 s** (immunité courte : l'Orage ne verrouille pas un T3 en boucle ; 6 coups = 2 foudroiements au plus).
- La Statique est portée par le **kit** (dictionnaire `instance_id → {stacks, until}`, nettoyé à la mort du monstre), pas par `Enemy` : aucune modification partagée (comme `is_soaked` d'Averse aujourd'hui). Elle apparaît dans `Enemy.status_list()` via un hook du kit si le HUD l'affiche (facultatif).
- **Items qui la lisent** : Cœur de glace (crispé = ralenti), Rosée figée forgée (toucher une cible ralentie soigne), Marque du chasseur (boss à +10 %).

---

## 6. L'eau : la synergie de tout le kit

Dans un monde où il pleut, l'électricité **conduit**. Trois sources de « mouillé », une seule règle :

| Source | Comment c'est lu | Effet |
|---|---|---|
| **Trempé par Averse** (Vague, Flaque-miroir, Crue, Glissade ; coop) | aujourd'hui `AverseKit.is_soaked(enemy)` (local au kit) ; proposé : `Enemy.is_wet()` partagé (§11) | +1 Statique par application, arcs +2 u |
| **Dans l'eau de la carte** (`,` peu profonde ; `~` pour les monstres qui y vivent) | `RaidKit.in_shallow(from, gpos)` / `StageMap` | idem ; la Mise à la terre épouse la nappe |
| **Dans une flaque de sort** (Flaque-miroir d'Averse ; flaques `water` des mini-boss : Crapaud-cuve, Pompe aveugle) | zones `water` de `MinibossBrain` (elles « conduisent la foudre », `shock_coef`) | idem ; **Isolée** (ci-dessous) protège Grésille de leur `shock_coef` à 50 % et de leur ralentissement |

- **Isolée** (trait intégré) : bottes de gutta-percha et cape-treillis. Les **eaux électrisées des mini-boss** (`water` → `shock_coef`) lui font **−50 % de dégâts** et **aucun ralentissement**. La foudre du Sonneur et du Semeur (sorts de boss, coef 2,5) la touche normalement : c'est l'orage, pas une flaque.
- Pas de bonus de dégâts **direct** sur mouillé (ce serait une seconde marque) : le mouillé agit par la **Statique** (deux fois plus vite au Foudroiement) et par la **portée des arcs**. Un paquet dans un bassin des Terrasses se foudroie en trois Arcs et ses arcs vont à 4,5 u : c'est visible, c'est sa carte.
- **Coop avec Averse** : la Vague trempe un cône, l'Arc de Grésille y saute à 4,5 u et dépose 2 cumuls par coup, la Décharge y propage 5 arcs à 5 u. Combo d'équipe lisible sans texte : les deux accents (cyan et lilas) sur le même paquet. À mesurer dans `multi/` (hôte autoritaire : la Statique vit chez l'hôte comme les statuts).
- **Cryptes et Source** : lac d'eau noire, bassin du mât-mère : ses meilleurs étages. **Gouffre et Cité** : eau rare : elle joue « sec », au disque de 3 u et aux arcs de 2,5 u. C'est l'asymétrie assumée, symétrique de celle d'Averse (dure aux Cryptes sans pluie).

---

## 7. Combos (grammaire de `Design_Combos.md`)

| Id | Séquence | Fenêtre | Récompense | Ordre inverse | Mobile |
|---|---|---|---|---|---|
| **GR-1 « Arc → Décharge »** (principal) | 3-5 Arcs sur le même paquet (3 s), puis Décharge sur le plus chargé | 6 s (durée des cumuls) | +27 % mono et jusqu'à 5 arcs ; HUD : le bouton 2 **pulse lilas** dès qu'une cible à ≥ 4 cumuls est à 8 u (`kit.combo_ready(2)`) | Décharge d'abord : 2,8 + 0 arc, mais la cible repart avec 1 cumul et les voisins 0 : utile pour ouvrir | **naturel** (cible = le plus chargé) |
| **GR-2 « Mise à la terre → Orage »** | électriser le sol (idéalement une nappe d'eau), laisser le paquet y entrer (2,5 s → 5 cumuls), puis Orage | 5 s | les 6 coups frappent des cibles à 5 cumuls : foudroiements en chaîne, +25 % par coup | Orage puis Mise à la terre : les cibles ont 1-2 cumuls, le sol finit le travail : correct | **naturel** (l'Orage vise le plus chargé) |
| **GR-3 « Court-circuit → Arc »** (l'esquive qui prépare) | traverser le paquet (1 cumul chacun), puis les Arcs rebondissent sur des monstres déjà chargés | 6 s | le paquet entier atteint 5 cumuls un Arc plus tôt | — | **placement** (joystick) |

Règle des +30 % respectée : la Décharge fait +27 % au plus sur la cible préparée ; l'Orage +25 % ; le reste des gains est de la **propagation** (zone), payée par la nécessité d'avoir des voisins et de l'eau.

---

## 8. Statistiques

| | Ardent (référence) | **Grésille** | Note |
|---|---|---|---|
| PV max (L) | 100 + 30 (L−1) | **95 + 28 (L−1)** | entre Rictus (95) et Ardent |
| Armure | 0 | **5** (4,8 %) | cuir et gutta-percha |
| Régénération | 1 + 0,2 (L−1) | **1 + 0,2 (L−1)** | |
| Vitesse | 4,0 u/s | **4,1 u/s** | 2,9 u/s pendant l'Orage |
| Esquive | 3 u / 0,25 s / 3 s | **Court-circuit** 3 u / 0,25 s / 3 s | sillage qui charge |
| Hitbox | 0,5 u | **0,45 u** | |
| Crit | 1 % × 2 | idem | |

**Coef/s mono-cible, tout touche, cible seule (estimé, à mesurer)** : Arc 0,8 / 0,6 = 1,33 ; Décharge (2,8 + 0,6 en moyenne) / 7 = 0,49 ; Mise à la terre 4,5 / 10 × 0,65 (présence) = 0,29 ; Orage 7,8 / 22 = 0,35 ; total **≈ 2,46**, soit **0,83-0,88 × Ardent** (2,8-2,96) ; avec le +10 % de Foudroiement sur boss (uptime ≈ 60 %) : **≈ 0,9 ×**. En paquet de 5 : Arc 2,1/s, Décharge + 3,0 d'arcs, Orage à +25 % : nettement au-dessus d'Ardent en zone moyenne, en dessous en essaim dispersé (aucune zone large). **Dans la cible [0,85 ; 1,20]** sur le papier ; à vérifier avec `balance_sim_run.tscn --chars=gresille --seeds=3` (scénarios `mixed`, `elite`, `miniboss`, L1/L6/L12). Leviers si trop bas en mono : Arc 0,8 → 0,9 ; si trop haut en zone : rebond 0,45 → 0,35.

---

## 9. Prise en main, forces, faiblesses, objets

- **Courbe** : 2/5. Palier 1 : « laisse le sort 1 travailler, décharge sur le chiffre 5 ». Palier 2 : Mise à la terre dans l'eau. Palier 3 : Orage après la Mise à la terre, esquive à travers le paquet. Tips : « Ce qui est mouillé conduit : tes arcs vont plus loin », « Décharge sur le monstre le plus chargé : il transmet », « Plante ta tige dans l'eau : tout le bassin grésille ».
- **Forces** : paquets de 3-8 (le rythme visé du jeu), eau, contrôle (crispé puis foudroyé), coop avec Averse, DPS mono correct sur boss accompagné.
- **Faiblesses** : fragile ; rien à longue portée (7-8 u) ; l'Orage s'interrompt à l'esquive ; un boss **seul et sec** monte lentement en Statique (Arc 0,6 s → 5 cumuls en 3 s, sans voisins pour les arcs) ; étages sans eau.

| Objet | Pourquoi |
|---|---|
| **Éclair en bouteille** | son objet de lore et de kit : chaque arc tente une foudre en chaîne (25 %) ; les rebonds se cumulent |
| **Cœur de glace** | crispé (≥ 3 cumuls) = ralenti ; une Mise à la terre = +50 % sur tout ce qui est dedans |
| **Lame jumelle, Carquois affûté, Sifflet** | l'Arc est un auto : plus d'arcs, plus de Statique |
| Pointe perforante | un rebond de plus par Arc |
| Rune de portée | Mise à la terre, cercles d'Orage, +15 % de zone |
| Horloge arcanique, Sablier | Décharge plus souvent ; au plancher 0,35 : Décharge 2,45 s, Orage 7,7 s |
| Marque du chasseur, Œil du prédateur | boss à +10 % pendant 2 s après chaque Foudroiement |
| Rosée figée (forgée) | toucher une cible crispée soigne |
| Danseur | neutre (elle marche pendant l'Orage à 70 %) |

---

## 10. Entrées par plateforme et HUD

| Plateforme | Décharge | Mise à la terre | Orage | Visée |
|---|---|---|---|---|
| PC clavier-souris | clic gauche (2) | clic droit (3) | molette (4) | Décharge : curseur ; les deux autres : sans visée |
| Manette | spell_2 | spell_3 | spell_4 | stick droit ; au repos : le plus chargé |
| Mobile | 3 boutons | | | Décharge → le plus chargé à 8 u (`most_stacked`), sinon le plus proche ; Orage et Mise à la terre : automatiques par nature |

HUD : aucune jauge (pas de `KitResource`). Lecture sur les monstres : petits arcs (`static_crawl`), chiffre de cumuls **sur la cible visée seulement** (sinon 250 chiffres), bouton 2 qui pulse lilas quand une cible ≥ 4 cumuls est à portée, bouton 4 grisé « tige levée » pendant la canalisation pour le sort 1 (icône barrée). Portrait : bouteilles qui luisent selon la recharge de la Décharge. Accessibilité : les arcs sont des `Line2D` 2 px minimum, les flashs de Foudroiement passent par `GameSettings.flashes_level()`.

---

## 11. Code à écrire (Sonnet) et contrats à signaler (orchestrateur)

Fichiers propres au personnage (dossier `game/scripts/spells/`) :
- `gresille_kit.gd` (`GresilleKit`, toutes les valeurs en constantes : `ARC_COEF 0.8`, `ARC_RANGE_U 7.0`, `BOUNCE_COEF 0.45`, `BOUNCE_U 2.5`, `WET_BONUS_U 2.0`, `DISCHARGE_COEF 2.8`, `DISCHARGE_PER_STACK 0.15`, `DISCHARGE_ARC_COEF 0.6`, `DISCHARGE_ARC_U 3.0`, `GROUND_*`, `STORM_*`, `STATIC_MAX 5`, `STATIC_S 6.0`, `CRISP_AT 3`, `CRISP_SLOW 0.2`, `ZAP_STUN_S 0.5`, `ZAP_BOSS_MULT 1.1`, `ZAP_IMMUNE_S 1.5`, `WET_STACKS 2`) ; hooks existants : `action_for`, `ACTION_IMPACT_FRAMES` (`attack` 2, `cast` 3, `ground` 3, `call` 2), `auto_cast_ok`, `combo_ready(slot)`, `blocks_slot(1)` pendant l'Orage, `damage_add`.
- `gresille_static.gd` : registre des cumuls (`instance_id → {stacks, until}`), `add(enemy, n)`, `stacks(enemy)`, `consume(enemy) -> int`, `zap(enemy)` (stun / mod boss, immunité 1,5 s), nettoyage sur `Events.enemy_killed` ; `is_wet(enemy)` qui agrège les trois sources (§6) en attendant un contrat partagé.
- `gresille_ground_field.gd` (`ZoneEffect` dérivée ou zone + masque de cellules) : remplissage de proche en proche sur la grille 1 u depuis la case de Grésille si elle est de l'eau (plafond 113 cellules), sinon disque 3 u ; tick 0,5 s ; rendu : décalque `ground_field` répété par cellule d'eau (TOP) + anneau pour le disque.
- Rendu des arcs : **réutiliser `ChainLightningFx.chain(pts, parent)`** (déjà écrit pour l'Éclair en bouteille) avec une teinte lilas ; `static_crawl` posé par `EnemyVisual` via un hook `kit.status_fx(enemy)` ou directement par le kit (un `AnimatedSprite2D` enfant, pool de 60).
- Lumières (presets `LightRig`, tous `#B9A6FF`) : `gresille_arc` (flash 0,1 s), `gresille_discharge` (0,3 s), `gresille_ground` (lumière de zone, scintillement 12 Hz), `gresille_storm` (colonne, 0,2 s par coup) ; lumière du joueur blanc de pluie à peine violet `#D9D4E8`.
- Sons (synthèse Codex, `art/tools/audio/`) : `spell.gresille_arc.cast_light/medium/heavy` (crépitement court, hauteur selon la puissance), `spell.gresille_discharge.*` (claquement + queue), `spell.gresille_ground.loop` (bourdonnement 50 Hz + grésil, 5 s), `spell.gresille_storm.*` (tonnerre sec, 6 coups), `gresille.zap` (claquement blanc du Foudroiement), `gresille.jars` (grésillement des bouteilles quand la Décharge est prête, discret).
- `data/characters.json` : entrée `gresille` (`unlocked true`, `hidden false` pendant les tests, comme les autres ; à la sortie : condition §12), `kit_script`, stats, 4 sorts, skin.
- Tests : `tests/gresille_test.tscn` (cumuls 1→5 et expiration, Foudroiement + immunité 1,5 s, boss = mod +10 % sans stun, Décharge : bonus +0,15 × n et n arcs sur voisins distincts, portée 3 → 5 u si mouillé, Mise à la terre : disque sec vs nappe d'eau connexe plafonnée, Orage : 6 coups, cible la plus chargée, interruption par l'esquive, sort 1 suspendu, auto-cast ; Isolée : −50 % / pas de ralentissement sur une zone `water` de mini-boss), `balance_sim_run.tscn --chars=gresille`, `unlock_conditions_test` (compteur).

**Contrats à signaler à l'orchestrateur** (fichiers partagés, non modifiés par le personnage) :
1. **Statut « mouillé » partagé** : `Enemy.is_wet() -> bool` (trempe d'Averse + case d'eau + flaque `water`), alimenté par `AverseKit` (qui garde `is_soaked` pour ses combos) et par `MinibossBrain` pour ses flaques. Aujourd'hui, la trempe est locale au kit d'Averse : sans contrat, Grésille ne lit qu'une partie de l'eau en coop. **Reco : l'ajouter** (une méthode, un champ `_wet_until`).
2. `SpellData.target_mode` : nouvelle valeur `&"most_stacked"` résolue par un hook `kit.pick_target(range)` (sinon `nearest`) : utile aussi pour Vigie (le plus exposé) et Avare (le marqué par la Rançon).
3. `SpellData.element` : valeur `&"lightning"` déjà utilisée par `_lightning` (`take_damage(..., &"lightning")`) : à déclarer dans l'énumération des éléments si elle existe côté `Enemy` (réactions, couleur des chiffres).
4. Exposition de l'eau de la carte au kit : `RaidKit.in_shallow(from, gpos)` existe ; un `StageMap.water_cells_connected(cell, cap)` (remplissage) serait à placer côté `scripts/stage` (orchestrateur) ou dans le kit avec un accès lecture à la grille.
5. Compteurs de déblocage et de variantes : `lightning_kills` (kills dont le dernier coup est `element == &"lightning"`, toutes sources), `gresille_grounded_wet` (monstres électrisés par une Mise à la terre posée sur l'eau), `kills_by_spell:gresille_storm`.

---

## 12. Déblocage, variantes, skin

### 12.1 Déblocage (à la sortie ; ouverte pendant les tests comme les autres)
- **Visible, tranché le 09/11/2026** : « **Foudroyer 100 monstres avec l'Éclair en bouteille** » (cumul sur le profil, n'importe quel personnage : tout dernier coup d'élément `lightning` venu d'un proc d'objet ; compteur `lightning_kills`). Indice (si cachée un jour) : « Elle a mis l'orage en bouteille la première. »
- Pourquoi : l'objet existe, il est peu commun (débloqué après 3 runs), il **apprend la conduction** avant le personnage, et il relie lore et kit (les bouteilles de Leyde). L'alternative « Vaincre le Sonneur » a été écartée : le boss de l'étage 3 est tiré parmi 4, la condition dépendait du hasard.

### 12.2 Variantes de sorts (2 ; règle ±15 % du sort de base)

- **Paratonnerre** (remplace *Mise à la terre*, sort 3)
  - *Plante la tige à distance : la foudre tombe dessus toutes les secondes pendant 6 s.*
  - Mécanique : recharge **10 s**, tige plantée au point visé (≤ 7 u ; mobile : paquet le plus dense ; pas un obstacle : un prop), **6 s** : toutes les **1,0 s** un coup de foudre sur la tige : cercle **2 u** (+ `zone_size_add`), coef **0,8**, proc 0,7, **+1 Statique** (2 si mouillé). Pas de ralentissement, pas de conduction de nappe : la tige **attire** au lieu de répandre. Une seule tige.
  - Budget : 10 ticks × 0,45 = 4,5 + ralentissement 20 % + nappe → 6 × 0,8 = **4,8** à distance, sans contrôle : +7 %, dans les ±15 %. Pour qui préfère tenir le paquet loin de soi.
  - Lisibilité : prop `rod_planted` (CREA 1 × 8 dir, tige de 1 u avec isolateurs, `_e`), `bolt_strike` (CREA 6, colonne, 1 dir, le même que l'Orage), petit cercle lilas au sol 0,8 s avant chaque coup (c'est un sort du joueur : aucun télégraphe exigé, mais il aide à lire où ça tombe).
  - Déblocage : **Électriser 300 monstres dans l'eau avec la Mise à la terre** (`gresille_grounded_wet` ≥ 300).
- **Bouteille de Leyde** (remplace *Orage appelé*, ultime)
  - *Tu jettes une bouteille : elle éclate en 4 u et libère d'un coup toute la Statique du paquet.*
  - Mécanique : recharge **22 s**, lob **0,8 s** (`LOB`, `lift_px`, ombre au sol) jusqu'à **8 u** (mobile : paquet le plus dense), puis éclat **4 u** (+ `zone_size_add`) : coef **6,5 + 0,3 × n** par monstre (n = ses cumuls, **consommés**), proc 1,0, recul 1,5 u × masse ; tout monstre à 5 cumuls est **foudroyé** (immunité 1,5 s respectée). Instantané : aucune canalisation, l'esquive est libre. Les deux bouteilles du dos : la jetée **manque** sur le sprite pendant la recharge (calque `_jar_r` masqué, comme un membre de Tocsin).
  - Budget : 7,8-9,3 en 3 s canalisées, sur une cible → **6,5-8,0** instantanés sur toute la zone. Moins de mono (−15 %), zone immédiate, pas de fenêtre de vulnérabilité : le même poids payé autrement.
  - Lisibilité : `jar_fly` (CREA 4, bouteille qui tourne), `jar_burst` (TOP 8, éclat lilas 4 u), secousse 10 px. Son : verre brisé + tonnerre court.
  - Déblocage : **Tuer 300 monstres avec Orage appelé** (`kills_by_spell:gresille_storm` ≥ 300).

### 12.3 Skin « trophée de Difficile » : **Fulgurite** (`gresille_skin1`)
- Idée (`Skins.md` : ce que le personnage devient après avoir traversé la Source) : la foudre de la Source a **vitrifié** son équipement. La tige de bronze est devenue une **fulgurite** (verre de sable fondu par la foudre, tube noir et grenu aux reflets gris), les bouteilles de Leyde sont en **verre fumé presque noir cerclé d'argent**, la cape-treillis en **mailles d'argent**, les bottes de gutta-percha **blanches** (le caoutchouc cuit), la veste de laine remplacée par un **manteau de cuir ciré noir**. Plus de vert-de-gris nulle part. L'accent lilas est conservé, zones et teinte identiques (IoU accent > 0,90).
- Déblocage : « Gagner une run en mode Difficile avec Grésille. » (`win_with`, `character: gresille`, `mode: difficile`).
- Description (une phrase, `characters.json`) : « La foudre de la Source a cuit son attirail : tige de fulgurite noire, bouteilles de verre fumé cerclées d'argent, mailles d'argent sur les épaules et bottes blanchies ; l'arc court toujours dans les mêmes bocaux. »

---

## 13. Points à trancher par le joueur (avec recommandation)

Tranchés le 09/11/2026 : le nom (**Grésille**) et la condition de déblocage (§12.1). Restent :

1. **L'accent lilas `#B9A6FF` face au mycélium du Gouffre `#C27BFF`.** Reco : **garder le lilas** (c'est la couleur de l'arc électrique, la seule teinte libre du roster) et vérifier sur la planche de contact de l'étage 2 ; repli : cœur plus blanc (`#F2EEFF` dominant) ou liseré `body_gain` du biome. Alternative : bleu-blanc d'arc `#A9D4FF`, mais il se confond avec Averse (`#5FD4E8`) et les cristaux des Cryptes (`#BFF4FF`).
2. **Le statut « mouillé » partagé (`Enemy.is_wet()`).** Reco : **oui**, c'est un contrat d'une méthode qui profite à Averse (coop), aux mini-boss à flaques et à Grésille ; sans lui, la synergie Averse × Grésille ne marche qu'à moitié. Alternative : lecture directe de `AverseKit.is_soaked` par le kit de Grésille (couplage entre kits, à éviter).

---

## 14. Assets Codex (lots proposés) et estimation

| Lot | Effort | Contenu |
|---|---|---|
| **GR1** (corps) | medium | modèle (femme compacte, râtelier à deux bouteilles, tige courte à isolateurs, cape-treillis, bottes de gutta-percha), matières DA, planche de contact avec Ardent, Vigie, Averse et ash_lord à la même échelle ; anims ×8 dir : `idle` 8, `run` 8, `attack` 4 (impact 2), `cast` 5 (Décharge, impact 3), `ground` 6 (impact 3), `call` 8 (2 de montée + 6 en boucle), `death` 6 = **45 × 8 = 360 rendus** ; `_e` des bouteilles, isolateurs et cheveux ; `portrait.png` 256², `portrait_e.png` 128² |
| **GR2** (VFX, icônes) | low | `arc_tile` (TOP, 4 frames, texture de `Line2D` pour les arcs, blanc lilas), `static_crawl` (CREA 4, petits arcs, 1 dir, 64²), `discharge_burst` (CREA 6, 1 dir), `ground_field` (TOP 64 px/u : `default` 8 en boucle + `end` 3, disque 3 u ; + tuile 1 u répétable pour la nappe), `bolt_strike` (CREA 6, colonne de foudre 1 dir, 1,5 u au sol), `zap_flash` (CREA 3), fantôme d'esquive (teinte seulement) ; 4 icônes 128 (`gresille_arc`, `gresille_decharge`, `gresille_terre`, `gresille_orage`) + 2 icônes de variantes (`gresille_paratonnerre`, `gresille_leyde`) ; ≈ **60 images** |
| **GR3** (variantes, skin) | low | `rod_planted` (CREA 1 × 8), `jar_fly` (CREA 4), `jar_burst` (TOP 8) ; planche skin `gresille_skin1` = **mêmes fichiers** que GR1 (360 rendus + portraits) |
| **Audio** | (Codex, synthèse) | 6 familles §11 |

Total : **≈ 3 lots Codex** (comme Rictus), 2 pour jouer (GR1 + GR2), 1 pour la sortie. Code : ≈ **3 j-agent Sonnet** (kit, registre, nappe, tests) + **0,5 j orchestrateur** (contrats §11). Repli en attendant les assets : sprite d'Ardent teinté `#4F6B5E` (`PLACEHOLDER_TINT`), arcs via `ChainLightningFx` existant (déjà un vrai rendu), zone = contour `ZoneEffect` lilas, foudre = flash de `LightRig`.
