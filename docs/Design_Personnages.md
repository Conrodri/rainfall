# Personnages jouables hors norme (design v1)

> Statut : **proposition de game design** (Fable, 21/10/2026) à partir du concept du joueur (« le robot qui lance ses membres »). Rien ici n'est implémenté ; les chiffres sont des points de départ dans les formules de `docs/Maths_Scaling.md` (§6, §9, §10, §14) et de `game/scripts/core/balance.gd`, à valider dans `simulateur_scaling.py` puis en playtest.
> Conventions : 1 u = 64 px logiques ; « dégâts » = coef × Dégât_base(L) (12 + 2,4/niv, **identique pour tous les personnages** : les différences passent par les coefs des sorts et les stats défensives) ; recharge effective = base × Π(1 + aᵢ)ⁿⁱ, plancher 25 % ; procs = chance × proc_coef ; recul normal plafonné à 0,6 u (`Balance.KB_MAX_U`) et pondéré par la masse (T1 1 / T2 0,7 / T3 0,4, élite ×0,6, boss ×0,08-0,04).
> Contrôles (CLAUDE.md) : sort 1 automatique partout ; PC : sorts 2-4 visent la souris (clic gauche = sort 2, clic droit = sort 3, clic molette = sort 4, touches 2-4 en secours) ; manette : stick droit, sinon l'ennemi le plus proche ; mobile : ciblage automatique, 3 boutons. DA : `art/briefs/STYLE.md` + `STYLE_boss_da.md` (PBR usé, palette sombre, **un** accent émissif) ; rendu rig CREA iso 30°, 8 directions `e, se, s, sw, w, nw, n, ne`, cadre joueur 192² à R = 90,51 px/u (`docs/Design_Isometrique.md` §4.4).

Sommaire : 1. **Tocsin** (le robot démontable, fiche complète) · 2. Cinq autres personnages (Averse, Arpenteuse, Rainette, Avare, Bourbe) · 2.6 **Rictus** (le pantin du Montreur, fiche complète) · 3. Tableau comparatif, ordre de production, systèmes à ajouter.

---

## 1. Tocsin, l'automate de crue

### 1.1 Lore (court)
Sur les Terrasses noyées, chaque écluse avait son **tocsin** : un automate de bronze au torse-chaudière, dont la tête est une cloche fêlée. Quand la crue montait, il sonnait, et quand les hommes ne venaient plus, il s'est mis à se démonter lui-même pour caler les vannes avec ses propres bras. La pluie ne s'est jamais arrêtée ; lui non plus. Il a gardé l'habitude : tout ce qu'il a, il le lance. Son foyer, nourri à la vase et aux ossements, le reconstruit pièce par pièce, rivet après rivet. (Cousin lointain du boss « Sonneur » de la Cité : même fonderie, un siècle d'écart.)

Titre : **« Automate de crue »**. Style : contrôle de foule, combos, expert. Config : **4 sorts / 0 passif**. Déblocage proposé : **disponible dès le départ** (second personnage de lancement, c'est la vitrine du jeu) ; variantes B à concevoir plus tard (ex. bras-harpon qui tire le robot vers la cible, jambes-ressorts, tête-fumigène).

### 1.2 Le principe
Le corps de Tocsin est son arsenal. Chaque membre est un sort ; un membre lancé **n'est plus sur le skin** tant que sa recharge court, et son absence change la façon dont il se déplace. La boucle de jeu : **attraper et regrouper** (bras) → **pousser** (jambes) ou **faire sauter le paquet** (tête) → **récupérer ses membres** (recharge, ou les ramasser au sol) → recommencer. Le foyer compense : chaque membre absent surchauffe la chaudière et accélère le sort 1.

### 1.3 Les sorts

| Slot | Sort | Entrée | Charges | Recharge (par charge) | Coef | Portée | proc_coef |
|---|---|---|---|---|---|---|---|
| 1 auto | **Rivets rougis** | automatique | — | 0,6 s (intervalle d'attaque) | 0,8 | 8 u (5 u sans tête) | 1,0 |
| 2 | **Bras-grappins** | clic gauche / spell_2 | 2 (bras gauche puis droit) | 8 s | 1,5 | 7 u | 0,7 |
| 3 | **Coups de botte** | clic droit / spell_3 | 2 (jambe gauche puis droite) | 9 s | 3,0 | 5 u | 1,0 |
| 4 ultime | **Tête-cloche** | clic molette / spell_4 | 1 | 22 s | 10,0 (×1,5 sur les emprisonnés) | 6 u (lob) | 1,0 |

Charges **séquentielles** (façon RoR2) : une seule charge se recharge à la fois ; deux bras lancés = 8 s pour le premier, 16 s pour le second. La recharge d'un membre **commence au lancer** (pas à la fin de son effet).

#### Sort 1 : Rivets rougis (automatique)
- Projectile tiré par la **plaque pectorale** (pas par les bras, donc disponible dans tous les états), vers l'ennemi le plus proche à 8 u ; coef 0,8, intervalle 0,6 s, vitesse 12 u/s, pas de traversée (`pierce 0`), proc 1,0. Son : un clac de rivet dont la hauteur suit la puissance (règle audio existante).
- **Surchauffe** (passif intégré au sort 1) : **+12 % de vitesse d'attaque par membre absent** (bras, jambes, tête : jusqu'à +60 % à 5 membres lancés). S'additionne aux items (plafond global +200 %). Le foyer thoracique brille plus fort à chaque palier (masque `_e` piloté par le code : intensité 1,0 → 2,0), ce qui rend l'état lisible de loin.
- Sans tête : **portée de ciblage 8 → 5 u** (il « tire à l'oreille »). La visée manuelle des sorts 2-3 n'est pas touchée (le joueur, lui, voit l'écran).

#### Sort 2 : Bras-grappins (2 charges, clic gauche)
Lancer **aller-retour, puis le bras reste au sol comme pince** :
1. **Aller (0,45 s)** : le bras part dans la direction visée (souris / stick / auto) sur 7 u, couloir de 1,2 u de large (+ `zone_size_add`), 16 u/s. Chaque monstre touché subit **150 %** (proc 0,7, car il touche souvent 5-10 cibles) et est **accroché** jusqu'au plafond ; au-delà du plafond il est seulement **ralenti de 40 % pendant 2 s** (même clé `slow` que Givre). Un mur arrête le bras (il se referme là).
2. **Retour (0,5 s)** : le bras rentre en traînant les accrochés (16 u/s, ils traversent les autres monstres sans collision) jusqu'au **point de dépôt : 2 u devant Tocsin dans l'axe du lancer**. Les accrochés y sont **regroupés** (« packés ») sur un disque de 1 u, séparation entre monstres désactivée.
3. **Pince (2,5 s)** : le bras se plante au sol et **emprisonne** le paquet : statut `imprisoned` = vitesse 0, aucune attaque ni sort, immunité au recul normal (seuls les Coups de botte et l'explosion de tête les déplacent), `is_slowed()` renvoie vrai (synergie Cœur de glace). Durée fixe, non prolongeable.
4. **Au sol (jusqu'à la fin de la recharge, 8 s après le lancer)** : la pince s'ouvre, le bras reste couché comme **objet à ramasser** (contact 0,6 u, délai 0,8 s après l'ouverture). Le ramasser **rend la charge immédiatement** (régénération 0,2 s). Sinon, à la fin de la recharge, le bras au sol disparaît en braises et se re-rivete sur le robot.

- **Plafond d'emprisonnement : 6 points par bras** (T1 = 1, T2 = 1, élite = 2, T3 brute = 3). Les **boss** (mini et étage) ne sont jamais accrochés : 150 % de dégâts et ralentissement de 20 % pendant 1 s.
- Deux bras lancés dans deux directions = **deux paquets** côte à côte (dépôts à 2 u devant, décalés de ±0,8 u pour ne pas se superposer).
- Ramasser le bras **pendant** la pince (2,5 s) est possible : la pince s'ouvre, les prisonniers sont libérés (toujours ralentis 40 % 2 s), la charge revient. Choix du joueur : garder la prison ou récupérer le bras.

#### Sort 3 : Coups de botte (2 charges, clic droit, **bloqué sans bras**)
Tocsin dévisse sa jambe (il lui faut **au moins un bras**) et la lance comme un bélier :
- Couloir de **5 u × 1,5 u** (+ `zone_size_add`), 0,4 s, **300 %** à tout ce qui est traversé, proc 1,0.
- **Poussée massive** : recul de **4 u × masse** (T1 4 u, T2 2,8 u, T3 1,6 u, élite ×0,6, mini-boss 0,3 u, boss d'étage 0,15 u), appliqué **par-dessus** le plafond `KB_MAX_U` (nouvel appel `Enemy.push(vec, 0,3 s)`), dans l'axe du lancer. Les **emprisonnés** touchés sont **libérés et poussés ×1,5** (6 u pour un T1) : « la boule de quilles ».
- **Quilles** (système optionnel S4) : un monstre poussé par une jambe qui en percute un autre lui transmet 50 % de la poussée restante et lui inflige **100 % des dégâts de base** (une fois par monstre percuté, proc 0,5). Si le système n'est pas retenu, la poussée seule reste valable.
- La jambe **s'arrête au bout du couloir ou au premier mur** et **reste au sol** (objet à ramasser, délai 0,8 s) jusqu'à la fin de sa recharge (9 s après le lancer). La ramasser rend la charge.

#### Sort 4 : Tête-cloche (ultime, clic molette, **toujours disponible**)
La tête est éjectée par la pression de la chaudière (pas besoin de bras : « le bouchon saute ») :
- **Lob** vers le point visé, 6 u maximum, 0,9 s de vol (arc affiché via `Iso.lift_px`, ombre de contact au sol qui suit), puis la cloche **tinte 0,3 s** (télégraphe audio + anneau au sol) et **explose** : rayon **4 u** (+ `zone_size_add`), **1 000 %**, proc 1,0, recul 2 u × masse. **+50 % sur les monstres emprisonnés ou accrochés** (explosion confinée). Libère les prisonniers (il en reste rarement).
- Recharge **22 s** ; la tête n'est jamais à ramasser (elle est en morceaux) : elle repousse à la fin de la recharge.
- **Sans tête** : Tocsin voit « par le foyer » : portée du sort 1 et du ciblage automatique **−3 u** (8 → 5 u, 7 → 4 u pour les bras, 5 → 4 u pour les jambes), **vignette légère** (CanvasModulate −10 % sur les bords, désactivée en qualité Bas), portrait du HUD sans tête, cou qui fume (calque `_e`). La caméra ne change pas : le joueur **est le corps**. Aucun autre malus de visée : au clavier-souris on vise toujours le curseur.

#### Combos lisibles (à enseigner par les tips)
1. **Bras → Jambe** : emprisonner, puis botter le paquet : poussée ×1,5 + quilles. Vide un couloir.
2. **Bras + Bras → Tête** : deux paquets à 2 u devant, une tête à 4 u de rayon les couvre tous les deux : jusqu'à 12 points de monstres à 1 500 %. C'est **le** moment fort du personnage (≈ 1 fois par 22 s).
3. **Jambe → Tête** : pousser la foule contre un mur, lober la tête dessus (les monstres plaqués ne s'écartent pas).
4. **Mode tonneau** : tout lancer (5 membres) : Surchauffe +60 %, le corps roule à 2 u/s ; viable avec des items de vitesse d'attaque et de recharge, suicidaire sinon. Les joueurs l'essaieront, il faut que ce soit drôle (sons de casserole, étincelles).
5. **Ramassage tactique** : lancer une jambe *vers* la zone où on veut aller, puis la ramasser : la jambe a dégagé le chemin et revient gratuitement.

### 1.4 Table d'états (membres présents → déplacement)

| Bras | Jambes | Déplacement | Vitesse (base 4,0 u/s) | Animation corps | Sorts disponibles | Roulade | Hitbox |
|---|---|---|---|---|---|---|---|
| 2 | 2 | marche | 4,0 | `walk` | tout | 3 u / 0,25 s | 0,5 u |
| 1 | 2 | marche | 4,0 | `walk` (1 calque de bras) | bras (1), jambes, tête | 3 u | 0,5 u |
| 0 | 2 | marche | 4,0 | `walk` | **jambes bloquées**, tête | 3 u | 0,5 u |
| 2 ou 1 | 1 | **cloche-pied** (sauts de 0,5 u, cadence 4/s) | **2,0** | `hop_l` / `hop_r` | bras, jambe restante (si ≥ 1 bras), tête | 1,5 u (saut) | 0,5 u |
| 0 | 1 | cloche-pied | 2,0 | `hop_*` | jambes bloquées, tête | 1,5 u | 0,5 u |
| 2 | 0 | **marche sur les mains** | **2,4** (0,6×) | `handwalk` | bras (lancer un bras → rampe), tête | 3 u (roue) | 0,5 u |
| 1 | 0 | **rampe** sur un bras | **1,4** (0,35×) | `crawl_l` / `crawl_r` | bras (→ tonneau), tête | 1,5 u | 0,45 u |
| 0 | 0 | **tonneau** (le torse roule sur le côté) | **2,0** (0,5×) | `roll` | tête seulement | 2 u (élan) | 0,45 u |

- La **tête** ne change pas la locomotion : elle retire 3 u de portée aux ciblages et ajoute la vignette (ligne « sans tête » cumulable avec chaque ligne du tableau).
- Multiplicateurs de vitesse appliqués **après** les items (`Balance.move_speed_px(bonus)` × état) et avant les ralentissements d'élite (plancher 50 % inchangé). Le cloche-pied à 2,0 u/s est **plus lent qu'un essaim T1 (2,5 u/s)** : c'est voulu, c'est le prix d'une jambe lancée ; la poussée de 4 u de la jambe compense si elle est bien visée.
- `Danseur` (+40 % en mouvement) : le tonneau et le cloche-pied comptent comme du mouvement.
- Transitions : perdre la 2ᵉ jambe joue `fall` (3 frames, 0,2 s, pas d'invulnérabilité) puis l'état cible ; retrouver une jambe en tonneau joue `fall` à l'envers (il se redresse). Lancer un bras pendant un cloche-pied est autorisé (aucune animation ne verrouille les entrées).

### 1.5 Règles de régénération
- La recharge d'un membre court dès le lancer. Quand elle se termine (ou dès le ramassage) : animation **`regen`** 0,4 s (VFX de rivets qui volent vers le moignon + bouffée de vapeur, rendu Blender, 1 direction, posé sur le pivot du membre), le membre **compte comme présent dès la première frame** (pas de clignotement du blocage des jambes). Le joueur peut bouger et lancer pendant.
- Le membre au sol est un pickup de la couche 7 (`interactables`) ramassé **au contact (0,6 u)**, jamais par l'aimant ni par le rayon de ramassage des items ; 0,8 s d'attente après la pose pour éviter de ramasser une jambe lancée dans ses pieds.
- Un membre au sol hors écran reste là ; il disparaît à la fin de sa recharge (braises + son). **Changement d'étage** : tout membre est régénéré immédiatement (état propre). **Sauvegarde** : on sauvegarde l'état des membres et les recharges restantes, pas les membres au sol (à la reprise, ils sont considérés disparus et se régénèrent normalement).
- **Mort** : le corps se disloque (`death` : les calques se dispersent).

### 1.6 Cas limites
- **Deux bras lancés puis les deux ramassés** : les charges reviennent dans l'ordre de ramassage ; les prisons s'ouvrent.
- **Jambe lancée contre un mur à 0,5 u** : couloir de 0,5 u, la jambe tombe au pied du mur (toujours ramassable).
- **Bras lancé sur un boss d'étage + 4 T1** : les T1 sont accrochés, le boss est ralenti 20 % 1 s et prend 150 %. Les T1 ramenés autour du boss : le paquet se forme devant Tocsin, pas devant le boss.
- **Tête lancée à portée d'un paquet en cours de traînage** : l'explosion touche les accrochés (×1,5) même s'ils ne sont pas encore déposés.
- **Pince et élite Brûlure/Poison** : les prisonniers ne frappent pas, donc n'appliquent pas de statuts ; un prisonnier T2 tireur ne tire pas.
- **Zone de charge** : un membre au sol hors de la zone n'empêche rien ; le joueur fait le choix d'aller le chercher ou d'attendre.
- **Ralentissement d'élite subi** pendant un cloche-pied : 2,0 × 0,7 = 1,4 u/s, plancher 50 % de l'état (jamais sous 1,0 u/s).
- **Accessibilité « sorts automatiques »** (option existante) : les bras partent sur le **paquet le plus dense** à 7 u (système S5), les jambes sur un paquet emprisonné sinon le plus dense, la tête seulement si ≥ 6 points de monstres dans son rayon à l'atterrissage prévu.

### 1.7 Roulade et items
- **Roulade** (`dodge`, 3 u / 0,25 s / 3 s) : disponible dans tous les états avec la distance du tableau ; l'invulnérabilité ne change pas. Elle n'interrompt ni la pince ni le vol d'un membre ; les fantômes de roulade reprennent les calques affichés (donc un tonneau fantôme). Pendant la roulade, les membres au sol ne sont pas ramassés (masque monde seulement).
- **`cooldown_mult`** (Sablier ×0,92ⁿ, Horloge ×0,85ⁿ, Chronomètre ×0,75ⁿ) : s'applique à **chaque charge** ; au plancher 25 % : bras 2 s, jambes 2,25 s, tête 5,5 s → « Tocsin jamais démonté ». **Chronomètre brisé** (élite tuée = −0,5 s) s'applique à la charge en cours. **Cœur du chronomancien** (remise à zéro d'un sort aléatoire) régénère instantanément un membre : très satisfaisant, à faire sonner.
- **Charges en plus** : nouvelle stat `extra_charges` (réservée aux sorts à `charges ≥ 2`, donc sans effet sur Ardent) pour un futur item « Pièces de rechange » : Tocsin peut relancer un bras **avant** que le précédent soit revenu ; visuellement, un **bras de rechange en bandoulière** sur le dos (1 calque supplémentaire, 1 pose par direction ; pas de combinatoire : on affiche « au moins 1 rechange »).
- **Procs** : bras aller 0,7 (5-10 cibles), pince 0 (aucun dégât), jambes 1,0, tête 1,0, rivets 1,0 (Surchauffe = plus de procs). `Givre` rend le ralentissement du bras redondant mais le prolonge. `Éclair en bouteille` sur un balayage de bras = chaînes de foudre sur tout le couloir.
- **3 items synergiques** : **Cœur de glace** (les emprisonnés sont « ralentis » : +50 % sur la tête et les jambes), **Rune de portée** (tête 4 → 4,8 u, couloirs plus larges, +15 % zone), **Horloge arcanique** (membres de retour plus vite + 10 % de dégâts des sorts à recharge = tout son kit).

### 1.8 Statistiques de base (comparé à Ardent, formules §6/§14)

| Stat | Ardent | **Tocsin** | Note |
|---|---|---|---|
| PV max (L) | 100 + 30 (L−1) | **130 + 36 (L−1)** | ×1,2 : il se bat à 2 u des paquets |
| Armure | 0 | **20** (réduction 16,7 %) | bronze ; les items d'armure s'additionnent |
| Régénération | 1 + 0,2 (L−1) | **0,8 + 0,16 (L−1)** | le foyer reconstruit des membres, pas de la tôle |
| Dégât_base | 12 + 2,4 (L−1) | idem | commun à tous |
| Vitesse | 4,0 u/s | 4,0 (× état) | voir §1.4 |
| Crit | 1 % × 2 | idem | |
| Roulade | 3 u / 0,25 s / 3 s | idem (× état) | |
| Hitbox | 0,5 u | 0,5 u (0,45 au sol) | |
| Coef/s mono-cible (tout touche) | ≈ 2,96 | ≈ 2,3 (+ Surchauffe jusqu'à ×1,6 sur le sort 1, +50 % tête sur paquet, quilles) | un peu sous Ardent en brut, au-dessus en foule packée |

Détail Tocsin : rivets 1,33/s ; bras 2 × 1,5 / 16 s = 0,19/s ; jambes 2 × 3,0 / 18 s = 0,33/s ; tête 10 / 22 s = 0,45/s (0,68 sur emprisonnés). À l'étage 1 (D ≈ 1,2-1,6, PV T1 ≈ 20-25), un bras à 150 % (≈ 20 dégâts à L3) **n'achève pas** un T1 : c'est voulu, le bras attrape, la jambe ou la tête tue.

### 1.9 Prise en main, forces, faiblesses
- **Courbe** : 4/5 (expert). Palier 1 (minute 0-2) : « un bras à la fois, jamais sans bras » suffit (le bras attrape, les rivets finissent). Palier 2 : jambe sur paquet. Palier 3 : double bras + tête. Palier 4 : ramassages tactiques, mode tonneau. Tips (tips.json, à ajouter par l'orchestrateur) : « Sans bras, Tocsin ne peut pas dévisser ses jambes », « Un membre au sol se ramasse en marchant dessus », « La tête explose plus fort sur un paquet emprisonné ».
- **Forces** : meilleur contrôle de foule du roster (emprisonnement = annulation totale de 12 monstres), burst d'ultime énorme et lisible, excellent dans les zones de charge (regrouper ce qui entre), scaling de recharge exceptionnel.
- **Faiblesses** : mono-cible médiocre (boss : 150/300/1 000 % sans bonus, pas d'accrochage), **mobilité conditionnelle** (une jambe lancée au mauvais moment tue), lecture mentale de 3 recharges + 5 membres, DPS brut sous Ardent sans paquets. Les mini-boss à charge (Colosse) sont son pire ennemi : la pince ne les tient pas et il est lent sur une jambe.

### 1.10 Entrées par plateforme
| Plateforme | Bras | Jambes | Tête | Visée |
|---|---|---|---|---|
| PC clavier-souris | clic gauche (ou 2) | clic droit (ou 3) | clic molette (ou 4) | curseur (point de dépôt du lob = curseur limité à 6 u) |
| Manette | spell_2 / spell_3 / spell_4 (actions `InputSetup` inchangées, ex. RT / LT / RB) | | | stick droit ; au repos : auto (S5) |
| Mobile | 3 boutons à droite, **pastilles de charges** (2 / 2 / 1) ; bouton **grisé avec icône de cause** (« pas de bras ») quand bloqué | | | auto S5 (bras → paquet le plus dense à 7 u ; jambes → paquet emprisonné sinon le plus dense ; tête → paquet emprisonné sinon le plus dense à 6 u). Option : **maintenir le bouton et glisser** pour viser (S5b, commun à tous les persos) |

HUD : les 3 icônes de recharge reçoivent des **pastilles de charges** (nouveau pour le HUD : S1) ; le portrait reflète l'état (tête / sans tête). Le corps lui-même est l'indicateur principal (membres visibles ou non).

### 1.11 Aspect
- **Silhouette** (1,4 u debout) : torse-chaudière trapu en **fer noir** (#2B2A29) cerclé de **bronze vert-de-gris** (#5F8F80), rivets **laiton** (#A8946E), coulures de rouille (#6B3A22) sous les joints ; tête = **cloche fêlée** de bronze clair (#8DBBA8) coiffée d'un petit paratonnerre tordu (asymétrie) ; bras longs à pinces à trois doigts, avant-bras en tube ; jambes en bielles avec **bottes-sabots** de fonte. Sangles de cuir, câbles qui pendent, mousse dans les creux (il a passé un siècle sous la pluie). Pas de visage : deux fentes.
- **Accent émissif unique** : le **foyer** (braise #FF7A1F) visible par la grille pectorale et les fentes de la cloche ; son intensité suit la Surchauffe ; sans tête, le cou fume et la grille brille plus fort (`_e` modulé par le code, pas de rendu supplémentaire).
- Membres au sol : même matière, la pince plantée fume ; la jambe couchée a sa botte vers le haut.

### 1.12 Animations et rendu modulaire (Codex)
**Le risque** : 3 états de bras × 3 de jambes × 2 de tête = **18 combinaisons**. Rendues naïvement (idle + locomotion + 3 lancers par combinaison, 8 directions), c'est ≈ 4 000 frames et 18 poses de rig à régler : **≈ 15-18 lots Codex**, inacceptable.

**Solution retenue : calques par membre, même cadre, même origine.** Chaque animation est rendue **une fois** depuis le rig complet, mais **sortie en 7 calques** (torse, tête, vapeur de cou, bras G, bras D, jambe G, jambe D ; Cryptomatte ou calques de vue avec holdout), tous dans le **même cadre 192²** avec le **même pivot au sol** : le jeu superpose les calques et **cache** ceux des membres absents. Pas de pivots ni de rotations à calculer : le « pivot » est l'origine du cadre. Codex exporte en plus `layers_order.json` : pour chaque direction, l'ordre de profondeur des calques (lu dans le rig : profondeur caméra de la racine de chaque partie). Les membres **projectiles / au sol** sont des assets à part (ils sont de toute façon des objets séparés en jeu).

Animations du corps (8 directions, calques) :

| Anim | Frames | Calques rendus | Usage |
|---|---|---|---|
| `idle` | 8 | 7 | tous les états debout (membres absents = calques cachés) |
| `walk` | 8 | 7 | 2 jambes (0-2 bras) |
| `hop_l`, `hop_r` | 2 × 6 | torse, tête, vapeur, bras, jambe restante | cloche-pied |
| `handwalk` | 8 | torse, tête, vapeur, 2 bras | 0 jambe, 2 bras |
| `crawl_l`, `crawl_r` | 2 × 6 | torse, tête, vapeur, 1 bras | 0 jambe, 1 bras (**coupable** : repli = `roll`) |
| `roll` | 8 | torse, tête, vapeur | tonneau |
| `throw_arm_l`, `throw_arm_r` | 2 × 4 | 7 (le bras lancé disparaît à la frame 2) | recul du torse |
| `throw_leg_l`, `throw_leg_r` | 2 × 4 | 7 | |
| `throw_head` | 6 | 7 | le bouchon saute |
| `fall` | 3 | 7 | perte de la 2ᵉ jambe (lu à l'envers pour se relever) |
| `death` | 6 | 7 | dislocation |
| **Total** | **87 frames × 8 dir = 696 rendus** | | roulade = fantômes (pas d'anim), régénération = VFX |

Assets séparés (rig CREA) : `arm_fly` 4 × 8 dir, `arm_clamp` 3 × 8, `arm_ground` 1 × 8, `leg_fly` 4 × 8, `leg_ground` 1 × 8, `head_fly` 6 × 8 (cloche qui tourne), `head_blast` 8 (TOP) + 8 (CREA, 1 dir), `regen_rivets` 6 (1 dir), 4 icônes 128 + portrait × 2. ≈ **180 images**.

Budget mémoire (à valider au lot T2) : 696 frames × 7 calques **rognés** (un bras ≈ 48 × 96 px) ≈ 35-45 Mo bruts, 10-15 Mo compressés VRAM : acceptable sur la cible ; replis : supprimer `crawl` (−96 rendus), `hop` à 4 frames, cadre 160².

Côté Godot (nouveau `PlayerVisualLayers`, S2) : 7 `Sprite2D` enfants du billboard, même index de frame et même cadence, visibilité par membre, z local par direction depuis `layers_order.json`, normal maps et `_e` par calque (CanvasTexture), la lumière du joueur (`LightRig`) inchangée.

**Coût estimé : 5 lots Codex** (Ardent complet en a coûté ≈ 3 ; son re-rendu iso C4 = 1) :
| Lot | Effort | Contenu |
|---|---|---|
| T1 | medium | modèle (7 parties nommées, pivots), matières DA, planche de contact avec Ardent et ash_lord à la même échelle |
| T2 | low | rig, locomotion (`idle`, `walk`, `hop_*`, `handwalk`, `crawl_*`, `roll`, `fall`) en calques, `layers_order.json` |
| T3 | low | lancers (×5), `death`, `regen_rivets`, vapeur de cou |
| T4 | low | membres en vol / au sol, `head_blast`, icônes, portraits |
| T5 | low (ou agent Claude : assemblage Python autorisé) | découpe des calques, atlas rognés, `.tres`, `_n`/`_e`, manifeste |

### 1.13 Implémentation (22/10/2026)
- Charges : un membre présent = une charge ; ordre gauche puis droite ; un seul membre se recharge à la fois par sort. Membre ramassé alors qu'il était en recharge : le suivant garde la progression. La recharge affichée (SpellCaster) = 0 s'il reste une charge, sinon le temps avant le prochain membre ; une réduction externe (item) est reportée sur le membre en recharge.
- Blocage : seul « jambes sans bras » grise le bouton ; charges épuisées = recharge normale (pas de grisé).
- Rivets : coef 0,8, 0,6 s, 12 u/s, 8 u (5 u sans tête), pas de traversée propre (Pointe perforante s'applique). Anim `attack` (impact frame 3) seulement à l'arrêt, debout, sans autre action : en marche le corps continue de marcher. Chaque rivet fait cracher le foyer (+0,6 d'émission pendant 0,12 s).
- Surchauffe : base_cooldown recalculée pour que l'intervalle = 0,6 / (1 + min(as + 0,12 n, 2)). Foyer (émission _e du torse, de la tête et de la vapeur) : énergie 2 × (1 + 0,2 n).
- Bras : couloir 1,2 u × (1 + zone_size_add), 16 u/s aller et retour, 7 u (4 u sans tête) × (1 + range_add) ; dépôt 2 u devant Tocsin (position courante), décalage latéral ±0,8 u si l'autre bras est en vol ou en pince ; paquet en tournesol sur 0,9 u ; retour plafonné à 1,2 s. Élite = max(points du tier, 2). Pickup posé dès que la pince se plante (délai 0,8 s), ramasser pendant la pince libère les prisonniers.
- Statut accroché/emprisonné (sans toucher Enemy) : position tenue à chaque frame physique ET rendu (nav.resolve), recul annulé, attaques/sorts repoussés de 0,3 s, télégraphe annulé, ralenti 100 % (is_slowed vrai), anim figée. À la libération : ralenti 40 % 2 s.
- Jambe : couloir 1,5 u × (1 + zone_size_add), 5 u (4 u sans tête) en 0,4 s ; frappe sans recul de coup puis Enemy.push(4 u × masse, ×1,5 si emprisonné : libéré). Quilles retenues : suivi 0,35 s par poussé, choc = contact des rayons, 50 % du recul restant + coef 1,0 (proc 0,5), une fois par monstre, en chaîne. Boss : dégâts seuls (Enemy.push ignore les boss).
- Tête : lob 0,9 s, hauteur 2,2 u, ombre de contact (shadow_blob_256), tintement 0,3 s (son telegraph.warn_heavy aigu + anneau de repli), rayon 4 u × (1 + zone_size_add), coef 10, +5 (proc 0) sur les accrochés/emprisonnés = 1 500 %, recul du coup + push 1,4 u × masse (≈ 2 u), secousse 10 px, lumière tocsin_blast 0,7 s.
- Sans tête : portées rivets 5 u / bras 4 u / jambes 4 u, vapeur de cou affichée, vignette radiale 10 % (CanvasLayer 5, coupée en qualité Bas et en headless).
- Locomotion (§1.4) : vitesse ×1 / 0,5 (cloche-pied) / 0,6 (mains) / 0,35 (rampe) / 0,5 (tonneau) ; roulade 3 / 1,5 / 3 / 1,5 / 2 u ; hitbox 0,45 u en rampe/tonneau. Cloche-pied à l'arrêt = `idle` avec la jambe absente cachée ; sans jambe, `handwalk`/`crawl`/`roll` jouent même à l'arrêt ; `fall` 0,2 s à la perte de la 2e jambe (pas de relevé à l'envers).
- Anims de lancer (frames d'impact, lot T3) : throw_arm_l/r 2, throw_leg_l/r 2, throw_head 3, attack 3. Sans jambe : pas d'anim debout, le membre part tout de suite.
- Lumières : tocsin_rivet (rivet en vol), tocsin_limb (membres en vol, pince, tête), tocsin_blast (explosion) ; toutes #FF7A1F, accent unique du foyer.
- Étage : tous les membres régénérés, recharges à zéro. Mort : membres au sol retirés, anim `death`.
- Non fait (hors périmètre) : pastilles de charges HUD (S1), portrait sans tête, sauvegarde de l'état des membres, accessibilité « tête seulement si ≥ 6 points », bras de rechange (`extra_charges`).
- **Équilibrage du 22/10/2026** (simulateur, `art/tools/night/balance_report.md` ; prévaut sur les valeurs ci-dessus) : rivets coef 0,8 **perforants** (traversée 0 -> 1 : essaim −40 % vs Ardent) ; bras 1,5 -> 1,8 ; tête 10 -> 12 (+50 % sur prisonniers = 18) et +30 % (additif) sur les boss ; bottes 3,0 inchangées. Auto-cast (`auto_cast_ok`) : le dernier bras reste tant qu'une jambe est là, une botte à la fois (avant : les bottes n'étaient jamais lancées, cible unique −62 %). Bug corrigé : membre libéré lu par affectation typée (`_limb()`). Après : cible unique +9 % vs Ardent à L6, dégâts subis ×1,8 (il se bat enfin au contact).

- Intentions d'origine conservées (§1.3-1.12) ; toute valeur citée ici est celle du code au 22/10/2026 et prévaut en cas d'écart.

---

## 2. Six autres personnages

Tous : 8 directions, rig CREA, un accent émissif, lisibles parmi 250 monstres (silhouette + accent + un élément au sol ou en l'air qui leur est propre), ciblage automatique sur mobile. Dégât_base commun. Les stats sont des multiples simples des formules d'Ardent.

### 2.1 Averse, la porteuse de pluie (distance / zone, ressource = eau)
- **Concept** : grande silhouette en ciré, une **amphore de bronze** sur le dos qui **se remplit de pluie**. Son eau est sa ressource ; **plus l'amphore est pleine, plus elle est lente** ; vider l'amphore (ultime) la rend rapide. Elle vit au rythme de la météo de chaque carte.
- **Ressource « Eau » 0-100** : +4/s sous la pluie × intensité du profil d'ambiance (0,5-1,5 ; S12), +1 par kill (« chaque monstre rend son eau »), +10/s dans l'eau des cartes. **Cryptes noyées (sans pluie)** : seuls kills et flaques : c'est son étage difficile, assumé. Vitesse = 4,4 u/s à 0 d'eau → 3,4 u/s à 100 (linéaire), appliquée avant les items.
- **Sort 1 auto « Goutte-lame »** : projectile 0,6 s, coef **0,6 + 0,4 × eau/100**, portée 9 u, traverse 1, proc 1,0, gratuit.
- **Sort 2 « Vague » (6 s, 25 d'eau)** : cône de 5 u, coef 3,0, recul 1,5 u, proc 1,0 ; les monstres touchés sont **trempés** 4 s (= ralentis 30 %, clé `slow`).
- **Sort 3 « Flaque-miroir » (8 s, 20 d'eau)** : zone au sol 2,5 u, 6 s, coef 0,5 / 0,5 s (proc 0,3), trempe ; Averse y regagne +5 d'eau/s. Sur mobile, auto-visée au paquet le plus dense (S5).
- **Sort 4 « Crue » (20 s, toute l'eau, minimum 40)** : vide l'amphore : onde de rayon 4 u + 0,02 u par point d'eau (6 u à 100), coef **10 × eau/100** (minimum 4), recul 3 u × masse, laisse une Flaque-miroir ; elle passe à 4,4 u/s jusqu'au prochain remplissage.
- **Malus signature** : amphore pleine = lente et **roulade raccourcie à 1,5 u** (elle trébuche) ; vide = pas de sorts 2-4. Il faut **dépenser pour courir**. Config : 4 sorts.
- **Stats** : PV 90 + 27/niv, armure 0, régén 1 + 0,2, vitesse 3,4-4,4, roulade 3 u (1,5 u ≥ 80 d'eau). Prise en main 2/5.
- **Aspect** : ciré gris pluie (#4A5565) à larges épaules, capuche basse, amphore de bronze cerclée de laiton, un seul accent : **l'eau cyan** (#5FD4E8) visible par une fenêtre de verre de l'amphore ; **le niveau d'eau est un masque `_e` modulé par le code** (0 rendu supplémentaire).
- **Animations** : `idle` 8, `run` 8, `cast` 4, `wave` 6, `crue` 8, `stumble` 3 (×8 dir) = 37 × 8 = 296 rendus ; VFX `wave_cone` (CREA 6), `puddle_mirror` (TOP 6), `crue_ring` (TOP 8). **≈ 2 lots** (1 modèle + anims low, 1 VFX + icônes low).
- Déblocage : visible, « Rester 60 s cumulées dans l'eau en une run ».
- **Implémenté le 22/10/2026** (valeurs retenues par le kit `game/scripts/spells/averse_kit.gd`, elles prévalent sur les chiffres ci-dessus ; les intentions d'origine restent le cap) :
  - Eau de départ 50, conservée entre étages.
  - Pluie : rain_intensity du profil < 0,05 = sec (×0) ; sinon multiplicateur 0,5 + intensité borné 0,5-1,5 ; sans AmbianceManager ×1. Eau de carte lue sur les cases « , » et « ~ ».
  - Goutte-lame (auto) : coef figé au tir, 13 u/s ; élément « frost » pour tous les sorts. Impact frame 3 (attack).
  - Vague : cône 60°, visée souris/stick sinon paquet le plus dense ; recul réel 1,5 u × masse (poussée en plus du plafond). Impact frame 3 (wave).
  - Flaque-miroir : portée de pose 7 u, ciblage par densité, trempe rafraîchie toutes les 0,25 s. Impact frame 2 (cast).
  - Crue (ultime) : trempe aussi ; recul 3 u × masse (pas les boss) ; coef = max(0,1 × eau, 4) ; rayon = 4 + 0,02 × eau. Impact frame 5 (crue / cast_ult).
  - Trébuchement (amphore ≥ 80) : roulade 1,5 u (0,125 s, invulnérabilité réduite), anim stumble, sans fantômes, puis 0,25 s à vitesse ×0,6.
  - Stats : hitbox 0,5 u, armure 0. Lumières averse_water / averse_wave / averse_crue, lumière joueur cyan froid.
  - Niveau d'eau lisible par l'énergie du masque _e de l'amphore (20 paliers).
  - Écarts assumés : eau de départ 50 (la fiche ne la fixait pas : démarrer à 0 rendait les premières secondes inertes) ; recul de la Vague réel en plus du plafond de poussée.
  - **Équilibrage du 22/10/2026** (simulateur `art/tools/night/balance_sim.py`, rapport `balance_report.md` ; ces valeurs prévalent sur celles du bloc) : Goutte-lame 0,75 + 0,4 × eau/100 (0,6 avant) ; Vague coef 3,5 (3,0) ; **+2 eau par Goutte-lame sur une élite ou un boss** (`BIG_HIT_WATER`) ; auto-cast : Crue prête -> Vague et Flaque attendent que l'amphore garde 40 d'eau. Pourquoi : hors essaim l'amphore restait à 0-14 % et la Crue n'était jamais lancée (cible unique −44 %). Pluie vérifiée : profils 0,25-1,0 -> ×0,75-1,5 (moyenne ≈ ×1,1), formule inchangée. Après : cible unique −4 % vs Ardent à L6, Crue ~4-5 fois/min contre élite et mini-boss.
  - **Refonte « l'eau est la seule limite » (demande du joueur, 22/10/2026 soir ; ces valeurs prévalent sur tout ce qui précède)** :
    - **Aucune recharge** sur Vague et Crue ; seule la **Flaque-miroir garde 5 s** (anti-spam, décision du joueur). Verrou anti-spam commun aux sorts 2-4 : jusqu'à la frame d'impact de l'anim (Vague 0,25 s, Flaque 0,17 s, Crue 0,42 s) et au moins 0,2 s, pour que deux sorts ne se marchent pas dessus dans une même anim.
    - **Coûts** : Vague 20, Flaque 18 (2 flaques au plus, la plus ancienne s'assèche), Crue = toute l'eau (min 40). Les objets de recharge deviennent des **économies d'eau** (coût × cooldown_mult, plancher 0,75).
    - **Gains** : pluie 2,5/s × carte (0,5-1,5 ; 0 aux Cryptes), **+0,5 par Goutte-lame qui touche** (+2 sur élite/boss : contre une cible unique, l'auto-attaque est la vraie source d'eau), +0,9 par kill, +4/s dans sa Flaque, +12/s dans l'eau de la carte. Plafond 100.
    - **À sec** : une Vague ou une Flaque qui vide l'amphore (< 1) fige tout gain 2 s (jauge éteinte « À SEC ») : garder une gorgée est un choix. La Crue, vidange volontaire, n'est jamais pénalisée.
    - **Crue** : coef 15 × (eau/100)^1,5 (40 → 3,8 ; 70 → 8,8 ; 100 → 15) : le rendement par goutte monte avec le remplissage, à payer en lenteur (3,4 u/s pleine) et en trébuchement (≥ 80). Tension : dépenser tout de suite (Vagues, rapide) ou remplir pour une Crue pleine (lente, fragile).
    - **Auto-cast** (accessibilité, simulateur) : Vague et Flaque ne dépensent que 60 % de l'eau gagnée (budget), une Flaque à la fois ; Crue à 75 d'eau (avant le trébuchement), ou dès 40 face à 6 monstres dans l'onde ou sous 35 % de PV.
    - **Lisibilité** : la jauge d'eau est l'info centrale (repère principal = seuil de la Crue 40, repère secondaire = trébuchement 80 ; « À SEC » ; clignote en rouge quand un sort est refusé faute d'eau) ; boutons grisés « pas assez d'eau » (plus de camembert) ; bulle « Coût : 20 d'eau » ; « +N » cyan flottants pour les gains hors pluie ; taux d'eau/s mesuré exposé par `resource_regen_per_s()` (affichage HUD).
    - **Visuels** : Flaque-miroir teintée froide et sombre, Crue en déferlante lumineuse additive (en code, en attendant le lot cel AV4 `art/tools/night/_av4.txt`, après R1).
    - Simulateur (balance_sim.py, 2 graines) vs Ardent, DPS cible / zone / TTK mini-boss : L1 +9 % / −15 % / −5 % ; L6 +17 % / +17 % / −8 % ; L12 +3 % / +16 % / +7 %. Crue lancée 1,6-15 fois/min selon le scénario (jamais nulle).

### 2.2 Arpenteuse, la géomètre de la Cité (zone / piège, ressource = chaîne au sol)
- **Concept** : elle déroule derrière elle une **chaîne de cuivre incandescente** (les 14 derniers u de son trajet). **Elle ne blesse que ce qu'elle a parcouru** : rester immobile = ne rien faire. Elle dessine des pièges avec son déplacement, donc le joystick est son arme.
- **Sort 1 auto « Chaîne »** : la traîne elle-même : zone-ligne de 0,5 u de large, coef **0,5 / 0,5 s** sur tout monstre qui la touche (proc 0,3), ralentissement 20 %. Pas de projectile. Nouveau comportement `TRAIL` (S9).
- **Sort 2 « Boucle » (6 s)** : ferme la chaîne d'un trait droit entre elle et la queue : le polygone **s'embrase** : coef 3,0 à tout ce qui est dedans + attraction de 1 u vers le centre (proc 1,0) ; **la chaîne est consommée** (traîne à zéro, elle repousse en marchant : 14 u = 3,5 s de course). Aucune visée.
- **Sort 3 « Piquet » (8 s)** : plante un piquet au point visé (6 u) : la chaîne est tendue du piquet à elle pendant 5 s et **balaie** : coef 1,0 par monstre touché par la ligne (immunité 0,3 s par monstre, proc 0,5). Mobile : piquet sur le paquet le plus dense.
- **Sort 4 « Tendeur » (20 s)** : la chaîne claque : coef 10,0 à tout ce qui est à 1 u de n'importe quel segment, puis elle **se rembobine en 0,5 s en traînant les monstres touchés** jusqu'à elle (pack) ; ils sont étourdis 1 s (statut `imprisoned` de Tocsin, réutilisé).
- **Malus signature** : fragile et **inutile à l'arrêt** ; `Boucle` la laisse 3-4 s sans chaîne ; dans un couloir étroit ses boucles sont petites. Config : 4 sorts.
- **Stats** : PV 85 + 25/niv, armure 0, régén 1 + 0,2, vitesse 4,2 (elle doit courir), roulade 3 u. Prise en main 3/5.
- **Aspect** : long manteau ciré brun (#3F2B1E), trépied de bronze replié dans le dos, **touret de chaîne** à la hanche ; accent unique **orange de cuivre chauffé** (#FF7A1F) sur la chaîne (texture répétée rendue au rig TOP, `Line2D` avec `_e`), rien d'émissif sur elle (la chaîne la signale).
- **Animations** : `idle` 8, `run` 8, `plant` 4, `loop` 4, `whip` 6 (×8 dir) = 240 rendus ; `chain_tile` (TOP, 4 frames d'incandescence), `peg` (CREA 1 × 8), `loop_blaze` (TOP 6). **≈ 2 lots**.
- Déblocage : visible, « Tuer 300 monstres avec un sort de zone persistante (Cendres) ».
- **Implémenté le 22/10/2026** (valeurs retenues par le kit `game/scripts/spells/arpenteuse_kit.gd`, elles prévalent sur les chiffres ci-dessus ; les intentions d'origine restent le cap) :
  - Chaîne = polyligne des 14 derniers u (points tous les 0,5 u, tête = sa position) ; ressource = longueur / 14 (`resource_frac()`, pas encore de jauge HUD).
  - Immobile plus de 0,6 s : le touret rembobine à 4 u/s (rester sur place = ne rien faire). Saut de position > 4 u (téléporteur, étage) : chaîne coupée.
  - Chaîne (auto) : coef 0,8 (fiche 0,5 ; un T1 de 18 PV tombe en 2 ticks), tick 0,5 s accéléré par la vitesse d'attaque, demi-largeur 0,25 u + rayon du monstre, proc 0,3, ralentit 20 % pendant 0,6 s, petit flash sans recul. Pas d'anim d'action (elle court). Le slot 1 est tenu par le kit (`blocks_slot(1)`), jamais lancé par SpellCaster.
  - Boucle : exige 3 u de chaîne (sinon refusée sans recharge). Dedans le polygone OU sur son contour (fermeture comprise) : coef 3,0, proc 1,0, attraction ≤ 1 u vers le centroïde (pas les boss). Chaîne consommée. Rendu : loop_blaze au centroïde, à l'échelle de √(aire/π), + contour qui flambe 0,45 s. Impact frame 2 (`loop`).
  - Piquet : portée 6 u (+ range_add), sinon 3 u devant ; recul hors des murs. Ligne piquet→elle 5 s : coef 1,0, proc 0,5, immunité 0,5 s par monstre (fiche 0,3 : borne un boss collé à ~2 coefs/s), recul 0,3 u perpendiculaire. Arrachée au-delà de 10 u. Un nouveau piquet remplace l'ancien. Mobile : paquet le plus dense. Impact frame 2 (`plant`).
  - Tendeur : exige 2 u de chaîne ou un piquet planté. Coef 10 à 1 u (× zone_size_add) de la chaîne ET de la ligne du piquet, proc 1,0. Claque 0,25 s (planche chain_snap) puis rembobinage 0,5 s (chain_rewind) : les non-boss touchés sont tirés jusqu'à 1 u d'elle, statut `imprisoned` 1 s + repli ralentissement 85 % 1 s ; le piquet est arraché. Impact frame 2 (`whip`).
  - Stats : PV 85 + 25, armure 0, régén 1 + 0,2, vitesse 4,2, hitbox 0,5 u, roulade standard (avec fantômes, elle déroule 3 u de chaîne d'un coup).
  - Rendu chaîne : Line2D TILE (bande 0,9 u ; 0,6 trop fin en iso), shaders arpenteuse_chain(_e).gdshader, maillons fixés au sol (décalage d'UV), gradient de chaleur queue 50 % → tête 100 %, émission 2,6 (4,5 quand elle mord) ; 2 lueurs cuivre le long de la chaîne.
  - Lumières : arpenteuse_chain (0,6 / 2,4 u, scintillement), arpenteuse_blaze (2,4 / 4,5 u), arpenteuse_snap (1,8 / 3 u), toutes #FF7A1F–#FF8A2E.
  - Frames d'impact déclarées : plant 2, loop 2, whip 2, attack 3, cast 2, cast_ult 3.
  - Écarts vs fiche : coef de la Chaîne 0,8 au lieu de 0,5 (un T1 de 18 PV tombe en 2 ticks, sinon la traîne ne tue rien) ; immunité du Piquet 0,5 s au lieu de 0,3 (borne un boss collé à ~2 coefs/s) ; Tendeur : étourdissement 1 s repris tel quel via `imprisoned`.
  - **Équilibrage du 22/10/2026** (simulateur `art/tools/night/balance_sim.py`, rapport `balance_report.md` ; ces valeurs prévalent sur celles du bloc) : Chaîne coef 1,0 (0,8), ralentissement 35 % (20 % : sa défense, ce qui la poursuit s'englue) ; Boucle 3,5 (3,0) ; Tendeur : étourdissement 1,5 s (1 s) ; **+60 % (additif) des sorts 2-4 sur élites et boss** (« la géomètre mesure les grands », boucler une cible mobile est rare). Pourquoi : cible unique −44 %, mini-boss +95 % de temps. Après : cible unique +10 % à L6, dégâts subis ×0,9 ; reste faible au niveau 12 en mixte (−37 %) et sur le mini-boss (+54 %).

### 2.3 Rainette, chevalière des roseaux (mobilité / burst, ressource = souffle)
- **Concept** : une amphibienne longiligne en cuirasse rouillée. **Elle ne marche pas, elle saute** : chaque poussée du joystick est un **bond de 2,5 u en 0,35 s** (+0,1 s d'atterrissage), **par-dessus les monstres** (pas les murs) ; en l'air elle est intouchable par le contact (masque sans la couche 3), pas par les projectiles. Vitesse effective ≈ 5,5 u/s mais **discrète** : pas de micro-ajustement.
- **Ressource « Souffle » 6** : chaque bond coûte 1, +1 par 0,4 s au sol ; à 0, elle **reprend son souffle 1 s** sur place (vulnérable). Elle doit alterner.
- **Sort 1 auto « Langue »** : fouet de 4,5 u vers le plus proche, 0,6 s, coef 0,8, proc 1,0 ; un **T1 tué par la Langue est avalé** : +1 % PV.
- **Sort 2 « Grand saut » (7 s)** : bond de 6 u vers le point visé, atterrissage coef 3,0 dans 2,5 u, étourdissement 0,5 s (proc 1,0). Ne coûte pas de souffle.
- **Sort 3 « Gluant » (8 s)** : crachat au point visé (6 u) : zone 2,5 u, 5 s, ralentissement 40 %, **les monstres dedans se collent entre eux** (séparation désactivée + attraction 0,5 u/s : pack lent) ; ses bonds depuis la zone sont +50 % plus longs.
- **Sort 4 « Chant de crue » (20 s)** : 4 s : sac vocal gonflé, chaque atterrissage inflige coef 3,0 dans 3 u et les bonds sont ×2 ; souffle illimité pendant.
- **Malus signature** : mouvement **engagé** (un bond lancé ne se corrige pas), temps d'atterrissage, essoufflement. Config : 4 sorts. Roulade remplacée par un **bond arrière** de 3 u (même recharge, invulnérable).
- **Stats** : PV 90 + 27/niv, armure 10, régén 1,2 + 0,24 (amphibienne), vitesse — (bonds), hitbox 0,45 u. Prise en main 3/5.
- **Aspect** : peau vert-gris sombre (#5B6B4F) luisante de pluie, cuirasse et jambières de fer rouillé à sangles, lance courte dans le dos ; accent unique : **sac vocal** qui luit vert pâle (#8DBBA8) et se gonfle à l'ultime. En l'air : ombre de contact au sol + `lift_px` (lisible parmi 250 monstres : elle est la seule chose en l'air).
- **Animations** : `idle` 8, `crouch` 2, `jump` 4, `land` 3, `leap` 6, `spit` 4, `breathe` 4, `belch` 6 (×8 dir) = 296 rendus ; VFX `tongue` (CREA 4, tourné par le jeu), `goo` (TOP 6), `land_ring` (TOP 4). **≈ 2,5 lots** (anims nombreuses).
- Déblocage : caché, « Terminer un étage sans être touché par un contact » (indice : « on ne l'attrape pas »).
- **Implémenté le 22/10/2026** (valeurs retenues par le kit `game/scripts/spells/rainette_kit.gd`, elles prévalent sur les chiffres ci-dessus ; les intentions d'origine restent le cap) :
  - Stats : PV 90 + 27/niv, armure 10, régén 1,2 + 0,24, hitbox 0,45 u ; vitesse nominale 5,5 u/s (sert aux items : la longueur des bonds suit move_speed / 5,5 u, ralentissements compris ; la durée reste fixe).
  - Bond : 2,5 u en 0,35 s, arc 0,55 u, +0,1 s d'atterrissage ; direction analogique figée au départ ; bonds enchaînés sans frame morte si le joystick reste poussé ; les murs arrêtent (glisse le long).
  - En l'air : un coup d'un monstre non-boss à portée de contact (rayon + 26 px + 0,35 u) est ignoré ; projectiles et boss touchent. Les affixes d'élite au contact ne sont pas encore filtrés (point ouvert).
  - Souffle 6 : −1 par bond ; +1 par 0,4 s continue au sol (le compteur repart à chaque bond : bondir sans pause ne régénère pas) ; à 0, essoufflée 1 s sur place (Langue et Gluant suspendus, Grand saut et Chant permis) puis souffle plein.
  - Langue (auto, 0,6 s) : fouet de pleine longueur 4,5 u (+ range_add) vers le plus proche, frappe tout sur la ligne (demi-largeur 0,35 u + rayon du monstre), traction 0,25 u vers elle, coef 0,8, proc 1,0. T1 tué = avalé, +1 % PV max. Impact frame 3 (attack).
  - Grand saut (7 s) : accroupie 0,12 s, vol 0,55 s, arc 1,6 u ; 1,5-6 u vers le point visé (mobile : paquet le plus dense) ; atterrissage coef 3,0 dans 2,5 u, recul fort, étourdissement 0,5 s (Enemy.stun), 0,15 s d'invulnérabilité, secousse. Sans souffle, sort de l'essoufflement ; pressé en plein bond = mis en file, part à l'atterrissage. Pas de roulade pendant.
  - Gluant (8 s) : crachat à ≤ 6 u (mobile : paquet le plus dense), impact frame 2 (spit) : éclaboussure coef 1,0 dans 2,5 u, puis flaque 5 s : ralentissement 40 % rafraîchi, attraction 0,9 u/s vers le centre (la séparation des monstres reste active : le paquet se tasse au contact). Bond qui part de la flaque : +50 %.
  - Chant de crue (20 s) : impact frame 3 (belch, repli cast_ult) ; 4 s : souffle illimité et plein, bonds ×2 en distance, ×1,6 en durée, ×1,8 en hauteur ; chaque atterrissage coef 3,0 dans 3 u (≈ 5-6 atterrissages = ≈ 15-18 coef, comparable aux Doublures). Cumulable avec l'atterrissage du Grand saut.
  - Roulade = bond arrière 3 u (Balance.DODGE_*) : sans direction, elle recule depuis le curseur / l'avant en gardant la menace en face ; avec direction, elle saute là où pousse le joystick, tournée vers l'arrière. Interdite pendant le Grand saut.
  - Lumières : rainette_jade (#8DBBA8, sorts, flaque, impacts) et rainette_sac (sac vocal pulsé pendant le chant) ; lumière du joueur refroidie en jade pâle #C9DCCF.
  - Lisibilité : ombre de contact au sol en l'air ; 6 pastilles de souffle au sol devant ses pieds (s'effacent quand le souffle est plein, clignotent essoufflée) ; anims d'état jump / crouch / leap / land / breathe / dodge ; `run` jamais utilisée.
  - Écarts vs fiche : Langue en fouet de pleine longueur qui frappe toute la ligne (la fiche disait « vers le plus proche ») ; attraction du Gluant 0,9 u/s au lieu de 0,5 (le paquet doit vraiment se tasser) ; teinte d'accent inchangée (#8DBBA8).
  - **Équilibrage du 22/10/2026** (simulateur `art/tools/night/balance_sim.py`, rapport `balance_report.md` ; ces valeurs prévalent sur celles du bloc) : Langue coef 1,0 (0,8), demi-largeur 0,5 u (0,35) ; Grand saut coef 3,8 (3,0), rayon 3 u (2,5), invulnérabilité d'atterrissage 0,35 s (0,15) ; Gluant 1,4 (1,0) ; Chant 3,6 (3,0) ; bond arrière 3,5 u (`BACK_HOP_U`, 3 u) ; en l'air le contact des **boss** est aussi ignoré (elle bondit par-dessus ; projectiles et coups armés à distance touchent). Pourquoi : cible unique −40 %, dégâts subis ×2,5, morts contre le mini-boss au niveau 1. Après : cible unique −5 % à L6, subis ×1,6, 0 mort.

### 2.4 Avare, l'usurier des Terrasses (mêlée / tank, ressource = or)
- **Concept** : un petit homme massif qui traîne un **coffre-fort cerclé de fer** au bout d'une chaîne : c'est son arme. **Son or est sa puissance** et **il saigne de l'or quand on le frappe**. Chaque coffre acheté est un vrai dilemme.
- **Puissance de l'or (la « bourse »)** : bonus de dégâts **+15 % par « P » d'or détenu** (P = prix courant d'un petit coffre, `Balance.chest_price`, donc le bonus suit le scaling), plafond +90 % (6 P). Affiché sur le HUD comme une jauge sur la bourse.
- **La bourse, expliquée au joueur (retour du 22/10/2026 au soir : « la bourse n'est pas expliquée, je ne comprends pas comment la remplir »)** :
  - *Ce que c'est* : l'or en poche (RunState.gold), rien d'autre. *À quoi elle sert* : +15 % de dégâts à tous ses sorts par P, plancher +10 %, plafond +70 % (valeurs équilibrées) ; elle paie la Poignée et la Faillite.
  - *Comment la remplir* : l'or des monstres (ramassé automatiquement comme pour tous, la Rançon en donne +50 %), les capsules, et **ses propres pièces tombées** (Poignée, Faillite, coups subis) qu'il faut aller ramasser à la main : ressources de joueur, jamais aspirées, **elles restent au sol jusqu'au ramassage**. Acheter un coffre la vide.
  - *Entre étages* : les pièces encore au sol rentrent dans la bourse, puis il garde **50 %** de la bourse (le reste devient de l'XP comme pour tous).
  - *Lisibilité* : jauge HUD « BOURSE » avec « +X % dégâts » et un repère par P ; descriptions des 4 sorts réécrites ; bulle de tutoriel courte, non bloquante, la première partie avec Avare (une fois par profil, clé `tip_seen:avare_purse` dans Profile.objectives).
- **Sort 1 auto « Coup de coffre »** : arc de 1,5 u devant lui, 0,8 s, coef 1,0 à tout ce qui est dans l'arc (zone), proc 1,0.
- **Sort 2 « Poignée de pièces » (5 s, coûte 2 % de l'or, min 5)** : 5 projectiles en cône, coef 1,2 chacun, portée 6 u, traversent 1 ; **les pièces retombent au sol** (80 % de la valeur, au sol jusqu'au ramassage) : aller les rechercher dans la foule est le jeu.
- **Sort 3 « Rançon » (9 s)** : frappe au sol : zone 3 u, coef 3,0, étourdissement 0,5 s ; les monstres marqués 4 s lâchent **+50 % d'or**.
- **Sort 4 « Faillite » (25 s, dépense 50 % de l'or)** : explosion de pièces de rayon 5 u, coef **6 + 4 × min(1, or dépensé / 4 P)**, recul 2 u ; **la moitié de l'or dépensé retombe** en pièces sur la zone (au sol jusqu'au ramassage).
- **Malus signature** : **chaque coup subi fait tomber 3 % de son or** (pièces au sol jusqu'au ramassage : la bourse baisse tant qu'il ne va pas les rechercher) ; acheter un coffre baisse ses dégâts ; aucun sort n'est gratuit sauf le 1 et le 3. Config : 4 sorts.
- **Stats** : PV 120 + 36/niv, armure 15, régén 0,8 + 0,16, vitesse 3,8, roulade 2,5 u. Prise en main 2/5 (mais gestion fine pour les experts).
- **Aspect** : manteau de cuir gras, bottes de fonte, le coffre (bois sombre, cerclages de fer noir, cadenas de laiton) traîné à la chaîne ; accent unique : **l'or** (#F2C14E) qui fuit par les jointures du coffre et sa traîne de pièces au sol (pickups existants). Lisible : la seule chose dorée qui bouge.
- **Animations** : `idle` 8, `run` 8 (coffre traîné), `swing` 4, `throw` 4, `slam` 6, `ult` 8 (×8 dir) = 304 rendus ; VFX `coin_burst` (CREA 6), `ransom_ring` (TOP 4). **≈ 2 lots** (coffre inclus dans le corps, pas de calque séparé).
- Déblocage : caché, « Finir une run avec plus de 4 P d'or en poche ».
- **Attention orchestrateur** : couplage avec l'économie (`economy_test`, budget d'or des monstres) : à simuler avant d'accepter les coûts.
- **Implémenté le 22/10/2026** (valeurs retenues par le kit `game/scripts/spells/avare_kit.gd`, elles prévalent sur les chiffres ci-dessus ; les intentions d'origine restent le cap) :
  - Stats : PV 120 + 36/niv, armure 15, régén 0,8 + 0,16, vitesse 3,8, hitbox 0,5 u. Roulade lourde : 3 u de Balance coupés à 2,5 u (fantômes conservés).
  - P = Balance.chest_price("petit", D courant, étage). Puissance de l'or = +15 % / P détenu, plafond +90 % (6 P), bonus additif sur tous ses sorts (hook générique `kit.damage_add` dans SpellCaster.compute_damage). Rappel RoR2 : l'or est converti en XP à chaque étage, la puissance repart de 0 à chaque étage.
  - Jauge lisible en jeu : énergie du masque _e d'Avare 1,0 → 3,4 et lueur dorée `avare_gold` ×0,2 → ×1,0 selon la bourse ; jauge HUD (ResourceGauge, contrat KitResource) libellée « Bourse », valeur « +X % dégâts », un repère par P.
  - Équité de l'or : ses pièces rendent leur valeur exacte (RunState.add_gold, sans gold_mult ni Events.pickup_collected) : recycler son or ne crée jamais d'or. Seule la prime de Rançon est de l'or neuf (PickupManager, comme une prime normale). **Pièces d'Avare = ressources de joueur** (GroundPickup, `PLAYER_RESOURCE`, meta `player_resource`) : ramassage manuel au contact, jamais automatique ; **sans expiration** depuis le retour du joueur (avant : 3-5 s, elles disparaissaient) ; plafond 40 au sol (au-delà la plus ancienne rentre dans la bourse) ; au changement d'étage, les pièces au sol rentrent dans la bourse avant la part gardée.
  - Coup de coffre (auto) : 0,8 s, coef 1,0, rayon 2,0 u (fiche 1,5 u, trop court au retour Rictus), arc 150°, recul 0,4 u, proc 1,0. Vers l'ennemi le plus proche, jamais le curseur ; rien sans cible. Impact frame 2 (swing).
  - Poignée de pièces : 5 s, 5 pièces en 50°, 13 u/s, 6 u, coef 1,2, traversent 1, proc 0,8, ciblage densité. Coût = max(2 % de l'or, 0,1 P) (le « min 5 » suit le scaling) ; sort grisé si la bourse ne suffit pas. Chaque pièce retombe où elle s'arrête (dernier coup, portée ou mur) : 80 % du coût / 5 par pièce, contact 0,75 u, sans expiration. Impact frame 2 (throw) ; tir immédiat.
  - Rançon : 9 s, autour de lui (sans visée), rayon 3 u, coef 3,0, recul 0,5 u, proc 1,0 ; étourdit 0,5 s (pas les boss, `Enemy.stun` = gel type hitstop) ; marque 4 s posée avant les dégâts (un monstre tué par la Rançon paie déjà) : à la mort, +50 % de la prime normale. Impact frame 3 (slam).
  - Faillite : 25 s, rayon 5 u, dépense floor(50 % de l'or) à la frame d'impact ; coef 6 + 4 × min(1, dépensé / 4 P) ; dégâts calculés avec la puissance d'AVANT la dépense ; recul 2 u × masse (pas les boss) ; 10 pièces = 50 % du dépensé, 1,2-4 u autour, ramassables après 0,3 s, sans expiration. Bourse vide : coef 6. Impact frame 5 (ult).
  - Malus : chaque coup direct subi (Events.player_damaged) fait tomber 3 % de l'or (si ≥ 0,5) en 3 pièces à 0,9-1,6 u, ramassables après 0,35 s, sans expiration. Les DoT ne font pas saigner.
  - Lumière : preset `avare_gold` (#F2C14E, 0,9, 2,2 u) pour tous les sorts et la lueur d'Avare. Flash à la Rançon (0,45 s) et à la Faillite (0,9 s, ×2) ; secousse 5 / 10 px.
  - Frames d'impact (index 0) : swing 2, throw 2, slam 3, ult 5 (attack 2, cast 3, cast_ult 4 pour mémoire).
  - Écarts vs fiche : Coup de coffre rayon 2,0 u au lieu de 1,5 u (trop court au retour du Rictus) ; coût de la Poignée = max(2 % de l'or, 0,1 P) au lieu de « min 5 » (suit le scaling) ; équité de l'or : ses pièces rendent la valeur exacte (jamais d'or créé), seule la prime de Rançon est de l'or neuf.
  - **Équilibrage du 22/10/2026** (simulateur `art/tools/night/balance_sim.py`, rapport `balance_report.md` ; ces valeurs prévalent sur celles du bloc) : armure **30** (15) ; puissance de l'or **plancher +10 %** (`GOLD_POWER_FLOOR`) et plafond **+70 %** (+90 %) ; la Poignée n'est plus grisée : bourse trop maigre = lancer gratuit sans pièces rendues ; **coffre-bouclier** : −45 % de dégâts subis pendant 0,6 s après un Coup de coffre ou une Rançon. Pourquoi : 10 morts au niveau 1 à 0 or, cible unique −42 %, dégâts subis ×5 ; puis +42 % en cible unique au niveau 12 avec le plafond à +90 %. Après : cible unique +9 % à L6, subis ×2,8, 2 morts au niveau 1.

### 2.5 Bourbe, la mère-vase de la Mangrove (invocatrice / mêlée, ressource = sa propre masse)
- **Concept** : un golem de vase et de racines cerclé de bronze. **Ses familiers sont des morceaux d'elle** : chaque « motte » détachée coûte **des PV actuels égaux à 15 % de ses PV max** (ses PV max ne baissent jamais : se soigner permet de relancer d'autres mottes). Recoller une motte rend ces PV. Son armée est sa barre de vie.
- **Taille et vitesse** : silhouette 1,3 u, vitesse 3,6 u/s **+0,15 par motte dehors** (4,2 à 4 mottes), hitbox 0,6 u → 0,45 u à 4 mottes. Plus elle se divise, plus elle est vive et fragile.
- **Sort 1 auto « Gifle de vase »** : arc de 1,5 u, 0,8 s, coef 1,0 (zone), proc 1,0. **Chaque motte** a son auto de contact : coef 0,4 / 0,8 s, PV = 15 % de ses PV max, vitesse 3,8, portée de chasse 6 u autour d'elle (S10).
- **Sort 2 « Détacher » (3 s, 4 charges séquentielles)** : lance une motte au point visé (5 u) ; elle combat 10 s puis **rampe vers Bourbe** ; se recoller rend les PV payés (× PV restants de la motte) ; une motte écrasée perd sa vase. **Jamais mortel** : refusé si Bourbe tomberait sous 35 % de ses PV max.
- **Sort 3 « Rappel » (6 s)** : toutes les mottes foncent vers elle en explosant sur ce qu'elles traversent (coef 1,5 chacune, proc 1,0) et se recollent.
- **Sort 4 « Bourbier » (22 s)** : elle s'enfonce 4 s : **inciblable**, zone 5 u où les monstres sont ralentis 50 % et prennent coef 1,0 / 0,5 s (proc 0,3) ; les mottes fusionnent dans la zone ; à la sortie, toutes réapparaissent à 4 autour d'elle (gratuites).
- **Malus signature** : une motte perdue = PV perdus ; 4 mottes dehors = 60 % de ses PV actuels engagés ; sans mottes elle n'est qu'une brute lente. Config : 4 sorts (charges sur le 2 = système S1 de Tocsin).
- **Stats** : PV 150 + 45/niv (avant division), armure 10, régén 1,5 + 0,3 (la vase repousse), vitesse 3,6-4,2, roulade 2,5 u. Prise en main 3/5.
- **Aspect** : argile sombre mouillée (#2B3340) veinée de mousse, racines-tendons, bandes de bronze vert-de-gris qui la tiennent ; accent unique : **feu follet vert froid** (#8DBBA8) dans la cavité du torse, repris **dans chaque motte** (c'est ce qui distingue une motte d'un T1 parmi 250 monstres) + anneau d'allié au sol (décalque TOP, 1 fois).
- **Animations** : Bourbe : `idle` 8, `run` 8, `slap` 4, `throw` 4, `recall` 4, `sink` 4, `rise` 4 (×8 dir) = 288 rendus ; motte (96²) : `idle` 6, `run` 6, `die` 4 (×8 dir) = 128. VFX `bog_zone` (TOP 8). **≈ 3 lots** (2 créatures ; variantes de matière par biome possibles plus tard).
- Déblocage : visible, « Tuer 3 élites avec des familiers » (reprend l'objectif de l'Invocateur du GDD).
- **Implémenté le 22/10/2026** (valeurs retenues par le kit `game/scripts/spells/bourbe_kit.gd`, elles prévalent sur les chiffres ci-dessus ; les intentions d'origine restent le cap) :
  - Code : game/scripts/spells/bourbe_kit.gd (BourbeKit, toutes les valeurs en constantes) + bourbe_motte.gd (BourbeMotte extends Decoy : provocation S14 et tirs ennemis reçus réutilisés).
  - Masse (**révisée le 22/10/2026 au soir, retour du joueur** : « Détacher retire des PV max ; il devrait faire perdre 15 % des PV max, si je me heal je pourrais relancer d'autres mottes ») : coût d'une motte = **15 % des PV max, payé en PV ACTUELS** ; les PV max ne bougent jamais (plus de `kit.max_hp_mult()`, plus de masse écrasée en attente) ; se soigner permet de relancer. Recollée (retour, Rappel, Bourbier, changement d'étage) = soin du prix payé × PV restants de la motte ; écrasée = vase perdue.
  - **Jamais mortel : refus, pas de plancher à 1 PV.** Détacher est grisé (et la jauge Mottes éteinte) si Bourbe garderait moins de **35 % de ses PV max** après paiement (il faut donc ≥ 50 % de PV ; 4 mottes depuis la pleine vie la laissent à 40 %). Pourquoi le refus : un plancher à 1 PV laisserait la golemme à un coup de la mort sur un simple clic, contraire à « on ne se tue jamais en se divisant » ; le refus se lit d'avance et un soin le lève. Pourquoi 35 % : au simulateur, avec 10 % le pilote vidait sa vie dans les mottes et mourait 3 fois au niveau 1 avec à peine 40 dégâts subis.
  - Plafond : 4 mottes vivantes (charges 4 × 3 s).
  - Vitesse 3,6 + 0,15 par motte vivante dehors ; hitbox lerp 0,6 → 0,45 u de 0 à 4 mottes. Roulade 2,5 u (hook `kit.dodge_distance_u()`).
  - Gifle de vase (auto) : ARC 150°, rayon 1,5 u, 0,8 s, coef 1,0, proc 1,0, recul 0,45 u. Impact frame 2 (slap, repli attack).
  - Détacher : 4 charges séquentielles de 3 s (× cooldown_mult) gérées par le kit (en attendant S1) ; verrou 0,35 s entre deux lancers ; visée souris/stick, sinon paquet le plus dense à 5 u, sinon devant à 3 u ; atterrissage avant les murs. Motte lancée en cloche (0,35 s, 1,2 u de haut) à la frame d'impact de throw (frame 2, repli cast).
  - Ajout « plouf » : à l'atterrissage, zone 1 u coef 0,6 proc 0,5 (le lancer se sent).
  - Motte : PV 15 % des PV max de Bourbe, vitesse 3,8, rayon 0,3 u, contact coef 0,4 / 0,8 s proc 0,5 ; chasse l'ennemi le plus proche parmi ceux à 6 u de Bourbe (laisse), sinon reste à 1,3 u d'elle ; 10 s de combat puis rampe vers elle (traverse les murs : la vase s'infiltre), recollage à 0,6 u.
  - Provocation des mottes : celle des doublures (4 u, jamais les boss) au lieu des 2 u de S10 (aucune modification partagée) ; elles encaissent aussi les tirs T2.
  - Rappel (6 s) : bloqué sans motte ; mottes à 12 u/s vers Bourbe, chaque monstre traversé (0,45 u + rayon) prend coef 1,5 proc 1,0 recul 0,8 u, une fois par motte. Impact frame 2 (recall, repli cast).
  - Bourbier (22 s) : immédiat au lancer = invulnérable 4 s, immobile, sorts et roulade bloqués, immunisée aux ralentissements ; mottes fusionnées + masses écrasées rendues tout de suite. Zone 5 u ouverte à la frame d'impact (sink frame 2, repli cast_ult frame 3) : coef 1,0 / 0,5 s (DoT) proc 0,3 ; ralentit 50 % (rafraîchi toutes les 0,25 s, 0,6 s).
  - Sortie : anim rise (frame 2, repli cast) ; ajout « gerbe de sortie » coef 1,0 rayon 2 u ; 4 mottes jaillissent sur un anneau de 1,2 u (déjà au combat), gratuites (rien à payer, rien à rendre au recollage ; plus de grâce de 3 s depuis le passage au coût en PV actuels).
  - Étage : mottes retirées sans perte (vase payée rendue en PV), charges pleines. Mort : mottes écrasées. Rien n'est sauvegardé.
  - Accent : feu follet #8DDBA8 (planche _cd_bourbe.png ; la fiche disait #8DBBA8). Lumières : bourbe_follet (éclats des sorts), bourbe_bog (zone, pulsation 0,6 Hz), bourbe_motte (petite lumière par motte, qualité Moyen+).
  - Repli visuel : Ardent teinté argile ×1,15 ; enfoncée sans anim sink = sprite à alpha 0,28 ; motte = sprite du perso ×0,6 assombri + follet dessiné ; anneau d'allié dessiné (0,42 u) ; zones = contours ZoneEffect.
  - Assets attendus (branchés automatiquement) : bourbe/bourbe.tres (idle, run, slap, throw, recall, sink, rise, attack, cast, cast_ult, death ×8 dir), bourbe/motte/motte.tres (idle 6, run 6, die 4 ×8 dir, même échelle que Bourbe), bourbe/bog_zone/bog_zone.tres (TOP, default en boucle + end facultative), bourbe/ally_ring/ally_ring.tres (TOP, default), bourbe/mud_slap/mud_slap.tres (TOP 4, arc sur +X), bourbe/mud_splash/mud_splash.tres (TOP 6, gerbe). VFX TOP : le disque/arc occupe ~90 % de la largeur de frame (rayon calé automatiquement).
  - Ressenti visé (coef/s mono-cible au contact, 4 mottes) ≈ 1,25 (gifle) + 2,0 (mottes) + 1,0 (rappel) ≈ 4,2, payé en PV : très fort quand elle ose se diviser, brute lente sinon.
  - Écarts vs fiche : accent #8DDBA8 au lieu de #8DBBA8 (lisibilité sur argile sombre, planche `_cd_bourbe.png`) ; provocation des mottes 4 u comme les doublures du Rictus (aucune modification partagée) au lieu des 2 u de S10 ; ajouts non prévus : « plouf » à l'atterrissage, gerbe de sortie du Bourbier.
  - **Équilibrage du 22/10/2026** (simulateur `art/tools/night/balance_sim.py`, rapport `balance_report.md` ; ces valeurs prévalent sur celles du bloc) : **les mottes provoquent aussi les boss** (`Decoy.lures_bosses`, 4 u) ; **vase compacte** : −30 % de dégâts subis sans motte dehors, l'avantage fond motte par motte (0 à 4 mottes) ; Gifle coef 1,0, arc 210° (150°), rayon 2 u (1,5) ; mottes 0,45 (0,4) ; plouf 1,0 dans 1,5 u (0,6 dans 1 u) ; Bourbier 1,4 / 0,5 s (1,0). Pourquoi : dégâts subis ×3-4, 4 morts au niveau 1 contre le mini-boss qui ignorait les mottes, essaim −30 %. Après : cible unique +15 % à L6, subis ×0,4, 0 mort ; essaim encore −22 %.
  - **Rééquilibrage du 22/10/2026 au soir (coût en PV actuels)** : plancher de Détacher 35 % des PV max ; mottes contact **0,40** (0,45) ; plouf **1,4 dans 2 u** (1,0 dans 1,5 u) ; Bourbier **1,2** / 0,5 s (1,4) ; mottes du Bourbier gratuites (plus de grâce). Simulateur après : DPS cible −7 % / +15 % / +19 % (L1 / L6 / L12), DPS zone −26 % / −14 % / +2 %, dégâts subis −50 à −100 %, 1 mort au niveau 1 (Ardent 2). Reste hors ±20 % : essaim au niveau 1 (−26 %, déjà −30 % avant : mêlée lente, la Gifle à 1,15 n'y changeait rien), mini-boss L6 (−28 %, favorable) et élite L12 (−30 %, favorable).

### 2.6 Rictus, le pantin du Montreur (fiche complète)

#### 2.6.1 Lore (court)
La *Barge aux Lanternes* donnait ses spectacles d'écluse en écluse sur les Terrasses ; quand la crue l'a retournée, le Montreur a coulé avec ses pantins, les mains encore sur le croisillon. Un seul est remonté : **Rictus**, le clown de la pièce, la porcelaine du visage fendue par les rochers. Mais ses fils ne sont jamais retombés : au-dessus de lui, à bout de bras dans la pluie, le Montreur continue de jouer. Personne ne sait si le pantin obéit au fantôme ou si c'est l'inverse. La pluie tambourine sur son crâne de bois comme sur une caisse claire, et le spectacle ne finit pas.

Titre : **« Pantin de la barge noyée »**. Style : mêlée rapide, leurres, burst. Config : **4 sorts / 0 passif** (le Montreur est un trait intégré, pas un slot). Déblocage proposé : **caché**, « Tuer 200 monstres avec des sorts à moins de 2 u de soi » (indice au journal : « quelqu'un tire les ficelles »).

#### 2.6.2 Le principe
Rictus est un **mêléiste de contact** : son auto balaie un demi-cercle devant lui, il projette des couteaux, il **tourne comme une toupie** et il **se dédouble** en leurres qui explosent. Le Montreur (fantôme) le tient par cinq fils d'argent : c'est lui qui le fait tourner, qui le **soulève** pour esquiver, et qui garde les doublures en main. Le moment fort : poser les doublures **puis lancer la toupie au milieu** : la toupie percute les six pantins et les expédie en étoile, chacun droit devant lui, puis ils explosent à l'impact.

#### 2.6.3 Les sorts

| Slot | Sort | Entrée | Recharge | Coef | Portée / rayon | proc_coef |
|---|---|---|---|---|---|---|
| 1 auto | **Dagues en demi-lune** | automatique | 0,6 s | 0,6 par coup, tout le demi-cercle | 2,5 u, 180° (retour joueur, était 1,8) | 0,8 |
| 2 | **Éventail** | clic gauche / spell_2 | 6 s | 1,2 × 5 couteaux | 7 u, cône 60° | 0,8 |
| 3 | **Toupie** | clic droit / spell_3 | 8 s | 0,7 / 0,25 s pendant 2,5 s (= 7,0) | 2,2 u autour (retour joueur, était 1,5) ; **invulnérable**, levée permise | 0,3 par tick |
| 4 ultime | **Les Doublures** | clic molette / spell_4 | 20 s | 2,5 par explosion (× 6 doublures) | anneau 1,2 u, explosion 2 u | 1,0 |

##### Sort 1 : Dagues en demi-lune (automatique)
- Deux dagues de bois ferré, un balayage en **demi-cercle de 1,8 u de rayon (180°)** devant lui, 0,6 s d'intervalle (`Balance.attack_interval`), **coef 0,6 à chaque monstre du demi-cercle** (sort de zone : `zone_damage_add` s'applique), proc 0,8 (il touche 3-8 cibles), léger recul 0,2 u.
- **Orientation : vers l'ennemi le plus proche à 1,8 u, sur toutes les plateformes** (le sort 1 reste purement automatique, comme pour Ardent ; pas de souris : l'auto ne doit jamais dépendre du curseur, sinon mobile et PC divergent). Sans ennemi dans le demi-cercle potentiel, il ne frappe pas (aucune consommation). Le balayage fixe `facing` pendant 0,2 s : l'animation `slash` est jouée dans la direction du balayage (8 directions).
- Pendant la Toupie, le sort 1 est **suspendu** (la toupie le remplace).

##### Sort 2 : Éventail (clic gauche)
- **5 couteaux** en éventail de 60° (−30°, −15°, 0°, +15°, +30°) depuis le point visé (souris / stick ; mobile : paquet le plus dense à 7 u, S5), 14 u/s, portée 7 u, **coef 1,2 chacun**, **traversent 1 monstre**, proc 0,8. Sur une cible unique au contact, 2-3 couteaux touchent (≈ 3,0) ; à 5 u, un seul.
- **Enrichissement « couteaux plantés »** : un couteau qui finit sa course (portée ou mur) **reste planté 4 s** ; marcher dessus (contact 0,6 u) rend **1 s de recharge** à l'Éventail (jusqu'à 5 s par salve). Même pickup que les membres de Tocsin (S6), sans délai.
- Utilisable **pendant la Toupie** (le Montreur lance pour lui : les couteaux partent du centre de la toupie).

##### Sort 3 : Toupie (clic droit)
- Rictus tourne **2,5 s** : zone de 1,5 u autour de lui, **coef 0,7 par tick toutes les 0,25 s** (10 ticks, 7,0 au total à une cible qui reste dedans), proc 0,3 par tick, recul 0,3 u par tick (les monstres sont repoussés au bord : ils « glissent » sur la toupie).
- **Déplacement pendant : oui, en glissant** : vitesse ×1,2 (4,8 u/s de base) mais **inertie** (temps de réponse 0,3 s sur les changements de direction : la toupie dérive). Mobile : le joystick dirige la dérive. Immunisé aux ralentissements d'élites pendant (le Montreur le tient droit).
- **Roulade interdite pendant la Toupie** (le Montreur a les mains prises ; bouton grisé). Sort 2 et sort 4 autorisés. Prendre un coup n'interrompt pas la toupie ; la mort oui.
- **Pousser les doublures** : toute doublure dont le centre entre dans le rayon de 1,5 u de la toupie est **percutée** : elle part **droit devant elle** (sa direction d'orientation, voir sort 4) à **10 u/s sur 4 u** (0,4 s), **une seule fois** par doublure. Lancée depuis l'anneau de 1,2 u, la toupie touche **les six d'un coup** : « l'étoile ». Les monstres traversés par une doublure en vol prennent **coef 1,0** (proc 0,5) et sont emportés de 1 u (recul normal) ; la doublure **explose à l'impact** avec le premier monstre rencontré après 1 u de vol, avec un mur, ou à la fin des 4 u (même explosion que ci-dessous). Un boss percuté : coef 1,0 et explosion sur lui (il ne bouge pas).
- Fin de toupie : 0,3 s de « vertige » (`stagger`) : vitesse ×0,5, pas d'invulnérabilité. Pas de malus de contrôle inversé (trop punitif sur mobile).

##### Sort 4 : Les Doublures (ultime, clic molette)
- Le Montreur dépose **6 doublures** de Rictus sur un **anneau de 1,2 u** autour de lui (hexagone, une doublure tous les 60°, la première dans la direction visée, sinon vers le haut de l'écran) ; chaque doublure **fait face vers l'extérieur** (dos au pantin) : c'est sa direction de poussée. Une position dans un mur est **sautée** (5 doublures ou moins) ; le même cas pour une position occupée par un monstre : la doublure apparaît quand même (le monstre est repoussé de 0,5 u).
- Une doublure est **immobile**, dure **3 s**, a **20 % des PV max de Rictus** et **provoque** : tout monstre non-boss à 4 u d'une doublure **cible la doublure la plus proche** plutôt que Rictus (statut `decoy`, S14). Les tireurs T2 lui tirent dessus. Une doublure **tuée** explose **immédiatement à 60 %** (coef 1,5) : le leurre qui meurt vite a quand même servi.
- À **3 s** (minuteur), chaque doublure **explose** : rayon **2 u** (+ `zone_size_add`), **coef 2,5**, proc 1,0, recul 1 u × masse. Six explosions superposées sur l'anneau : un monstre collé à Rictus en reçoit 2-3 (≈ 6-7,5) ; la somme théorique 15,0 est plus haute que l'ultime de référence (10,0) parce qu'elle est dispersée et différée.
- Doublure **poussée** par la Toupie : voir sort 3 (explosion à l'impact, pas au minuteur ; si rien n'est touché en 4 u, explosion à l'arrivée).
- Les doublures **portent les items de Rictus** pour les procs (`SpellCaster.deal_damage` du joueur) mais ne font pas de coups à elles seules ; elles n'ont ni auto ni déplacement propre (ce sont des leurres, pas des familiers : système léger S14, réutilisable par les mottes de Bourbe).

##### Le Montreur (fantôme) : trait intégré « Tiré par les fils »
- **Roulade = levée** : le Montreur **soulève** Rictus : saut de 3 u en 0,25 s à `lift_px(0,8)`, **au-dessus des monstres** (masque sans la couche 3, pas les murs), invulnérable comme une roulade, recharge 3 s. Même entrée `dodge`. C'est la seule roulade « aérienne » avec Rainette : le pantin pendu aux fils est lisible instantanément.
- **Fils tendus** : à la fin d'une Toupie et au moment où les doublures explosent, le Montreur **resserre les fils** : Rictus regagne **2 % de PV max** (une fois par sort ; ≈ 0,5-1 Cœur de mousse, c'est volontairement léger). Pas de second passif : le fantôme est d'abord une **présence visuelle**.

#### 2.6.4 Table d'états

| État | Déplacement | Vitesse | Sort 1 | Sort 2 | Sort 3 | Sort 4 | Roulade | Hitbox |
|---|---|---|---|---|---|---|---|---|
| normal | marche | 4,2 | demi-lune | oui | oui | oui | levée 3 u | 0,45 u |
| **toupie** (2,5 s) | glisse, inertie 0,3 s | 4,8 (×1,2), immunité aux ralentissements | suspendu | oui (depuis le centre) | — (en cours) | oui (puis poussée immédiate) | **non** | 0,5 u |
| vertige (0,3 s) | marche | 2,1 (×0,5) | oui | oui | non | oui | non | 0,45 u |
| levée (0,25 s) | vol 3 u | 12 | suspendu | non | non | non | — | invulnérable |
| doublures posées (3 s) | comme l'état courant | | | | | — (recharge) | | |

#### 2.6.5 Cas limites
- **Toupie lancée avant l'ultime** puis ultime pendant la toupie : les doublures apparaissent dans le rayon et sont **percutées à la frame suivante** : l'étoile part tout de suite. C'est la version « réflexe » du combo, autorisée.
- **Doublure poussée vers un mur à 0,5 u** : elle explose contre le mur après 0,5 u (sans la condition « 1 u de vol » qui ne concerne que les monstres).
- **Doublure dans la Flaque / sur un télégraphe** : elle ne subit pas les zones ennemies (seulement les coups directs de monstres provoqués) : rester simple.
- **Provocation et zone de charge** : les monstres provoqués restent dans la zone ; la provocation ne concerne jamais les boss (mini et étage) ni les monstres à plus de 4 u.
- **Deux doublures percutées par une chaîne de Tocsin / un sort allié** : hors sujet (1 joueur).
- **Changement d'étage / mort** : les doublures et les couteaux plantés disparaissent ; recharges conservées (règle générale).
- **Sauvegarde** : doublures et couteaux non sauvegardés (recréés = non ; ils sont perdus, comme les projectiles).
- **Ralentissement d'élite subi en marchant** : normal ; en toupie : ignoré ; pendant le vertige : cumulé (plancher 50 %).
- **Mobile, sort 4 sans visée** : première doublure vers le haut de l'écran ; la disposition hexagonale rend l'orientation sans importance.

#### 2.6.6 Items
- **cooldown_mult** : Toupie au plancher 2 s (presque permanente : une toupie de 2,5 s toutes les 2 s = jamais d'auto, c'est le build « derviche », tenable car le sort 1 vaut 1,0/s et la toupie 2,8/s) ; Doublures 5 s. **Chronomètre brisé** sur les élites tuées par les explosions : très rentable.
- **Procs** : demi-lune 0,8 (auto : porte Étincelle/Flocon/Fiole sur 3-8 cibles par coup), couteaux 0,8, toupie 0,3/tick (cohérent avec Cendres), doublures 1,0 par explosion, vol 0,5.
- **Rune de portée** (+20 % zone) : demi-lune 1,8 → 2,16 u, toupie 1,8 u, explosions 2,4 u, +15 % de dégâts sur tous ses sorts sauf les couteaux : **son meilleur item**. **Lame jumelle / Sifflet** : la demi-lune est son socle. **Danseur** (+40 % en mouvement) : la toupie glisse = en mouvement. **Éclair en bouteille** : 5 couteaux × 25 % = foudre quasi garantie par salve. **Pointe perforante** (traversée du sort 1 seulement) : sans effet sur la demi-lune ni sur les couteaux, à signaler dans l'aide de l'item.
- **3 items synergiques** : Rune de portée, Horloge arcanique (toupie + doublures plus souvent, +10 % des sorts à recharge), Éclair en bouteille.

#### 2.6.7 Statistiques de base (comparé à Ardent et Tocsin)

| Stat | Ardent | Tocsin | **Rictus** | Note |
|---|---|---|---|---|
| PV max (L) | 100 + 30 (L−1) | 130 + 36 (L−1) | **95 + 28 (L−1)** | du bois et de la porcelaine ; les leurres font le reste |
| Armure | 0 | 20 | **10** (9,1 %) | bois ferré |
| Régénération | 1 + 0,2 (L−1) | 0,8 + 0,16 (L−1) | **0,6 + 0,12 (L−1)** (+2 % PV par toupie / ultime) | le bois ne guérit pas, le Montreur recolle |
| Dégât_base | 12 + 2,4 (L−1) | idem | idem | commun |
| Vitesse | 4,0 | 4,0 (× état) | **4,2** (4,8 en toupie) | léger |
| Crit | 1 % × 2 | idem | idem | |
| Roulade | 3 u / 0,25 s / 3 s | idem (× état) | **levée aérienne** 3 u / 0,25 s / 3 s | passe au-dessus des monstres |
| Hitbox | 0,5 u | 0,5 u | **0,45 u** | |
| Coef/s mono-cible au contact | ≈ 2,96 | ≈ 2,3 | ≈ **2,9** (demi-lune 1,0 + couteaux 0,5 + toupie 0,875 + 2-3 explosions 0,3-0,4) | équivalent à Ardent, meilleur en foule, plus fragile |

#### 2.6.8 Prise en main, forces, faiblesses
- **Courbe** : 2/5 (accessible) : le kit se joue « au bouton » sans gestion d'état ; le combo étoile (ultime puis toupie) s'apprend en une run. Tips : « Lance la Toupie au milieu de tes Doublures », « Le Montreur te soulève par-dessus la foule », « Ramasse tes couteaux plantés ».
- **Forces** : excellent nettoyage de foule au contact (demi-lune + toupie), **leurres** qui coupent la pression dans les zones de charge, esquive aérienne, burst d'étoile lisible et spectaculaire.
- **Faiblesses** : fragile (95 PV, régén basse), **dépend du contact** (les tireurs T2 à distance le fatiguent : les couteaux sont sa seule réponse), toupie engageante (pas de roulade 2,5 s), boss : pas de mono-cible au-dessus de 1,2 × 3 couteaux.

#### 2.6.9 Entrées par plateforme
| Plateforme | Éventail | Toupie | Doublures | Visée |
|---|---|---|---|---|
| PC clavier-souris | clic gauche (2) | clic droit (3) | clic molette (4) | couteaux : curseur ; toupie : sans visée (le joystick/ZQSD dirige la dérive) ; doublures : première vers le curseur |
| Manette | spell_2 / spell_3 / spell_4 inchangés | | | stick droit ; au repos : auto |
| Mobile | 3 boutons ; **Toupie grisée = roulade grisée** pendant 2,5 s (icône « fils tendus ») | | | couteaux → paquet le plus dense à 7 u (S5) ; doublures → auto (hexagone) ; toupie : joystick |

#### 2.6.10 Aspect
- **Rictus (1,3 u)** : pantin articulé **très maigre et décharné** (torse étroit et creux, cage de lattes visible sous le costume déchiré, taille fine, cou long, membres fins aux articulations saillantes ; retour joueur M1) en **bois verni craquelé** (vernis brun-noir, fentes claires aux articulations, chevilles de bois visibles), visage de **porcelaine fêlée** (blanc sale #D9CFC4, fissure du front à la mâchoire, un œil de verre, l'autre orbite vide) peinte d'un **maquillage de clown malsain** dégoulinant de pluie (fond blanc craquelé, orbites barbouillées de noir qui coule, grand sourire rouge étalé jusqu'aux joues, nez rouge écaillé, cheveux verdâtres mouillés sous un bonnet de bouffon), **fraise** et costume de clown en **tissu délavé** (losanges gris pluie #4A5565 / brun-rouille #7A3B24, rapiécés, trempés), grelots de plomb muets, dagues de bois ferré. Silhouette : membres trop longs, tête penchée, genoux en dedans : **malsain par la pose, pas par la caricature** (STYLE_boss_da : pas d'yeux ronds, pas d'aplats).
- **Le Montreur** : **1,4 u au-dessus** de Rictus (`lift_px(1,4)`), **mains et croisillon seulement** lisibles (silhouette de brume dense encapuchonnée, bras longs, capuche sans visage), alpha ≈0,8 (lisible ; retour joueur M1), **jamais devant l'action** (z local sous les projectiles, décalé de 0,3 u vers le haut-gauche de l'écran pour ne pas couvrir le haut du pantin). **Cinq fils d'argent fins et discrets** (≈1 px, #9FC8C0 alpha ≈0,35 ; `Line2D` × 5, texture de fil rendue au rig TOP, 1 tuile) des doigts aux poignets, aux genoux et à la tête, **animés** (balancement sinus 0,5 Hz, tendus pendant la toupie et la levée, qui « vibrent » 0,2 s à chaque explosion).
- **Accent émissif unique : argent spectral #9FC8C0** (cyan-vert froid, désaturé) : les mains du Montreur, les fils, et son reflet dans l'œil de verre de Rictus. Rien d'autre n'émet (le bois et la porcelaine sont mats) : lisible parmi 250 monstres par le **pantin éclairé par le dessus** (le `LightRig` du joueur prend cette couleur) et le fantôme suspendu, seul élément flottant à cette hauteur avec Rainette.
- Les doublures : **même sprite que Rictus**, teinte désaturée et assombrie par un shader (−40 % saturation, +fissures via le `_e` inversé), **sans Montreur ni fils** (c'est ce qui les distingue du vrai : le joueur et les monstres les confondent, pas l'œil du joueur). Aucun rendu supplémentaire.

#### 2.6.11 Animations et rendu modulaire (Codex)
Deux acteurs rendus **séparément** (pantin, fantôme) et assemblés en jeu, synchronisés sur le même index de frame ; les fils sont du code. La toupie est **à symétrie de rotation : une seule direction** suffit (8 frames), l'éclairage reste cohérent puisque le modèle tourne. Les doublures réutilisent `idle`.

| Acteur | Anim | Frames | Dir | Usage |
|---|---|---|---|---|
| Rictus | `idle` | 8 | 8 | + doublures (shader) |
| | `run` | 8 | 8 | |
| | `slash` | 4 | 8 | demi-lune (orientée) |
| | `throw` | 4 | 8 | éventail |
| | `spin` | 8 | **1** | toupie |
| | `stagger` | 3 | 8 | vertige |
| | `summon` | 6 | 8 | ultime (bras levés par les fils) |
| | `lift` | 3 | 8 | levée (pendu aux fils) |
| | `death` | 6 | 8 | fils coupés, il s'effondre |
| Montreur | `hover` | 6 | 8 | flottement, mains qui jouent |
| | `pull` | 4 | 8 | toupie / levée / ultime (mains tendues) |
| **Total** | | **(8+8+4+4+3+6+3+6) × 8 + 8 + (6+4) × 8 = 424 rendus** | | |

Assets séparés : `knife` (CREA 4, pointe vers +X, tourné par le jeu), `knife_planted` (1 × 8 dir), `dagger_arc` (TOP 4, demi-lune au sol), `spin_blur` (CREA 4, 1 dir, additif), `double_burst` (TOP 6 + CREA 6), `string_tile` (TOP 1), 4 icônes 128, portrait. ≈ 60 images.

**Coût estimé : 3 lots Codex** (Tocsin 5, Averse 2) :
| Lot | Effort | Contenu |
|---|---|---|
| M1 | medium | modèles Rictus (articulations, porcelaine, tissu) et Montreur (brume, mains), matières, planche de contact avec Ardent / Tocsin / ash_lord |
| M2 | low | rig, anims du pantin et du fantôme, `spin` 1 direction, `.tres` |
| M3 | low | couteaux, demi-lune, explosion, fil, `spin_blur`, icônes, portrait |

Côté Godot : `CompanionSprite` (S15 : un sprite synchronisé, à hauteur `lift_px`, alpha, ordre z) + `StringRig` (5 `Line2D` entre points nommés des deux frames : le manifeste M2 exporte la position des poignets/genoux/tête par direction et par frame, comme `layers_order.json` de Tocsin). Mémoire : 424 × 192² rognés ≈ 20 Mo bruts, sans enjeu.

---

### 2.7 Équilibrage du 22/10/2026 : Rictus et Ardent
- **Rictus** (prévaut sur §2.6) : demi-lune coef 0,8 (0,6) ; Éventail 1,6 par couteau (1,2) ; Doublures 3,0 (2,5, mort 60 % = 1,8) ; **garde du Montreur** : −30 % de dégâts subis pendant 0,5 s après chaque demi-lune (les fils tirent le pantin hors des coups). Pourquoi : cible unique −36 % et dégâts subis ×1,8-2,4 vs Ardent. Après : cible unique −5 % à L6, subis ×1,4.
- **Ardent** (`ArdentKit.NOVA_COEF`, `BRASIER_COEF`) : Nova 3,0 -> 2,5, Brasier 10 -> 8. Il reste le débutant sûr (kite, zone) mais ne domine plus la cible unique (DPS L6 106 -> 92, zone inchangée).
- Hooks ajoutés pour cette passe (game/CONTRACTS.md) : `damage_taken_mult`, `auto_cast_ok`, `on_spell_hit`, `Decoy.lures_bosses`.

### 2.8 Vigie, la guetteuse de la digue (fiche complète ; archère, distance / tir chargé, ressource = Tension)

Demande du joueur (22/10/2026) : « il manque un personnage classique comme un archer ». Fiche joueur autonome : `docs/fiches/vigie.md`. Code : `game/scripts/spells/vigie_kit.gd` (VigieKit, toutes les valeurs en constantes) + `vigie_flare.gd` (VigieFlare) ; test `game/tests/vigie_test.tscn` ; capture `game/tests/vigie_capture.tscn` ; lots Codex VG1 / VG2 (`art/tools/night/_vg1.txt`, `_vg2.txt`).

#### 2.8.1 Lore (court)
Sur les Terrasses, chaque digue avait sa tour de guet et chaque tour sa vigie : une archère chargée de **tirer une fusée rouge quand l'eau montait**. La nuit de la Grande Crue, la pluie a noyé ses fusées en plein ciel avant qu'elles éclatent ; personne n'a vu le signal, la vallée s'est noyée sous ses yeux. Elle a survécu sur le toit de sa tour. Depuis, elle trempe ses pointes dans le **magnésium des phares**, un feu que la pluie n'éteint pas, et descend la rivière en tirant : plus personne ne manquera le signal.

Titre : **« Guetteuse de la digue »**. Style : distance, tir chargé, contrôle léger. Config : **4 sorts / 0 passif** (la Tension est la ressource, pas un slot). Déblocage proposé : **visible**, « Tuer 100 monstres à plus de 8 u de soi en une run » (indice : « le signal ne s'éteint pas sous la pluie »). Pendant les tests : ouverte (`characters.json` : `unlocked` true, `hidden` false, `difficulty` 2).

#### 2.8.2 Le principe
Le personnage **classique** qui manquait : une archère qui tire seule, se lit en une seconde et se joue sans gestion. Son identité Rainfall : elle **apporte la lumière** (ses fusées sont de vraies lumières rouges dans la nuit pluvieuse) et elle **bande son arc** : la **Tension** se remplit toute seule (2,2 s en marchant, **1 s ancrée**, c'est-à-dire immobile) ; pleine, le prochain tir automatique devient un **Trait d'allonge** qui perce toute la ligne. Le rythme naturel « je bouge, je m'arrête une seconde, la flèche lourde part » est la seule chose à apprendre. Ce qui la distingue du roster : Ardent kite et brûle en zone autour de lui (novas) ; Rictus récupère des couteaux plantés (elle ne ramasse rien) ; Arpenteuse ne frappe qu'en bougeant (Vigie charge mieux à l'arrêt) ; Averse gère une jauge qui ralentit ; Vigie **expose** (marque de dégâts subis) et **cloue** pour aligner ses tirs perçants.

#### 2.8.3 Les sorts

| Slot | Sort | Entrée | Recharge | Coef | Portée / rayon | proc_coef |
|---|---|---|---|---|---|---|
| 1 auto | **Trait** | automatique | 0,6 s | 0,8 (traverse 1) | 9 u, 16 u/s | 1,0 |
| 1 (Tension pleine) | **Trait d'allonge** | automatique | — | 2,0 à chaque monstre de la ligne | 12 u, 24 u/s, perce tout, recul 0,8 u | 1,0 |
| 2 | **Fusée de détresse** | clic gauche / spell_2 | 8 s | 1,2 (flèche) ; fusée 5 s : **exposés +10 %** | 9 u ; lumière 3 u | 1,0 |
| 3 | **Filet lesté** | clic droit / spell_3 | 9 s | 0,5 (flèche) + 1,2 (filet) ; **immobilisés 1,5 s** ; **Tension pleine** | 7 u ; filet 3 u | 0,5 |
| 4 ultime | **Grêle** | clic molette / spell_4 | 20 s | 0,7 / 0,25 s pendant 2,5 s (11 volées ≈ 7,7) ; ralentit 25 %, expose | 10 u ; pluie 4,5 u ; arrivée 0,45 s | 0,4 |

- **Trait (auto)** : vers l'ennemi le plus proche (jamais le curseur), rien sans cible. Anim `attack` (impact frame 2). Tension pleine : `vigie_allonge` (SpellData hors barre, `is_auto` : bonus d'auto, `item_pierce` faux), anim `draw` (impact frame 4) ; la Tension tombe à 0 au lancement.
- **Fusée de détresse** : visée souris / stick, sinon paquet le plus dense (S5). La flèche s'arrête au premier monstre (`rests_on_hit`) ou au point visé (portée du tir = distance visée), plante une `VigieFlare` : aucune dégât propre, lumière `vigie_flare` (crachotement 9 Hz, ombres), toutes les 0,2 s les monstres à 3 u (+ `zone_size_add`) reçoivent `Enemy.add_damage_taken_mod(&"vigie_expose", 1,1, 0,35 s)` (toutes sources, objets compris). Anim `flare` (impact frame 3).
- **Filet lesté** : même tir posé que la Fusée ; à l'ouverture, statut `imprisoned` 1,5 s (Tocsin/Arpenteuse, jamais les boss : ralentissement 40 % 1,5 s) puis zone instantanée coef 1,2 sans recul ; **Tension pleine**. Anim `net` (impact frame 2). Auto-cast : seulement si la Tension est sous 50 % (sinon il la gâche).
- **Grêle** : volée au ciel à la frame d'impact de `volley` (frame 4), pluie 0,45 s plus tard au point visé (≤ 10 u, sinon paquet le plus dense) : `ZoneEffect` persistante (ticks DoT), ralentissement 25 % 0,5 s rafraîchi, exposition comme la fusée.

#### 2.8.4 Ressource : Tension (0-1)
- Remplissage : `(1 + attack_speed) / T` par seconde, T = **2,2 s** en marchant, **1,0 s ancrée** (immobile depuis 0,15 s, roulade = pas ancrée). Gardée entre les étages et dans la sauvegarde (`save_state`).
- Pleine : le prochain Trait est un Trait d'allonge ; lueur `vigie_tension` sur la corde, petit éclat au moment où elle s'arme, jauge HUD « PRÊTE » qui pulse (`KitResource` id `tension`, label « Tension »).
- Masque `_e` du sprite (corde, pointes) : énergie 0,6 → 3,2 selon la Tension (10 paliers), lisible même sans HUD.
- Aucun malus caché : se faire toucher ne vide pas la Tension (personnage débutant).

#### 2.8.5 Table d'états
| État | Déplacement | Tension | Sort 1 | Sorts 2-4 | Roulade | Anim |
|---|---|---|---|---|---|---|
| marche | 4,2 u/s | +1 / 2,2 s | Trait | oui | 3 u | `run` |
| ancrée (immobile ≥ 0,15 s) | — | +1 / 1 s | Trait | oui | oui | `brace` (arc à demi bandé) |
| Tension pleine | idem | — | **Trait d'allonge** | oui | oui | `brace` / `run`, corde rouge |
| roulade | 3 u | marche | — | — | — | roulade + fantômes |

#### 2.8.6 Statistiques (comparé à Ardent)
| Stat | Ardent | **Vigie** | Note |
|---|---|---|---|
| PV max (L) | 100 + 30 (L−1) | **90 + 27 (L−1)** | fragile, comme Averse |
| Armure | 0 | **0** | ciré et roseaux |
| Régénération | 1 + 0,2 (L−1) | **1 + 0,2 (L−1)** | |
| Vitesse | 4,0 | **4,2** | elle doit pouvoir reculer |
| Roulade | 3 u | **3 u** | standard |
| Hitbox | 0,5 u | **0,45 u** | silhouette fine (l'arc ne compte pas) |
| Coef/s mono-cible | ≈ 2,8 | ≈ **2,8** (Trait 1,33 + allonge 0,46 + filet 0,32 + fusée 0,15 + grêle 0,39, × exposition ≈ 1,06) | |

#### 2.8.7 Items
- **Vitesse d'attaque** (Carquois affûté, Sifflet de chasse, Rafale d'acier) : plus de Traits **et** Tension plus rapide. **Lame jumelle** : le Trait et le Trait d'allonge sont des autos. **Cœur de glace** : cibles ralenties (Grêle) ou immobilisées (Filet, `is_slowed` vrai). **Pointe perforante** : Trait seulement (l'Allonge perce déjà tout). **Éclair en bouteille** : chaque cible de l'Allonge (proc 1,0). **Rune de portée** : lumière de la fusée, filet, Grêle (+15 % de zone sur filet et Grêle). **Danseur** : anti-synergie assumée (bonus en marche, elle charge mieux à l'arrêt).
- **3 items synergiques** : Carquois affûté, Lame jumelle, Cœur de glace.

#### 2.8.8 Prise en main, forces, faiblesses
- **Courbe** : **2/5** (débutant à intermédiaire) : tout se joue « au bouton », la seule subtilité est de s'arrêter une seconde. Tips : « Arrête-toi une seconde : ta corde se bande trois fois plus vite », « Le Filet remplit ta Tension : tire dans le paquet que tu viens de clouer », « Ce qui est dans la lumière de ta fusée prend plus de dégâts ».
- **Forces** : cible unique, élites et boss, portée 9-12 u, lignes de monstres traversées, contrôle (filet), éclaire la nuit.
- **Faiblesses** : fragile (90 PV, 0 armure), moins de zone qu'Ardent au niveau 1, s'arrêter pour charger est un risque dans les essaims.

#### 2.8.9 Entrées par plateforme
| Plateforme | Fusée | Filet | Grêle | Visée |
|---|---|---|---|---|
| PC | clic gauche | clic droit | molette | curseur |
| Manette | spell_2 | spell_3 | spell_4 | stick droit, au repos : paquet le plus dense |
| Mobile | 3 boutons | | | paquet le plus dense (S5) ; Trait toujours automatique |

#### 2.8.10 Aspect
- **Vigie (1,35 u)** : grande, sèche, un peu voûtée. Lisible parmi 250 monstres par **trois formes** : l'**arc long plus haut qu'elle** (bois de digue noirci `#2A2522`, cerclages de cuivre vert-de-gris `#4F6B5E`, corde de chanvre trempée), la **pèlerine de roseaux tressés** (`#5A5540`, triangle hirsute qui goutte sur les épaules, au-dessus d'une capuche de ciré ardoise `#3A4048`), le **carquois-tube de laiton** à la hanche d'où dépassent les têtes des fusées. Écharpe remontée sur le nez, longue-vue cabossée à la ceinture, jambières de pêcheur couvertes de vase. Peau pâle `#C9B8A8`, regard fatigué. Réaliste et usée (STYLE_boss_da), jamais héroïque ni cartoon.
- **Accent émissif unique : rouge de fusée de détresse `#FF3A4F`** : têtes des fusées dans le carquois, mèche fumante à la hanche, **corde de l'arc** (masque `_e` modulé par la Tension). Rien d'autre n'émet. Lumière du joueur : blanc de pluie à peine rosé `#E3CFC9`, cœur rouge `#FF5A66` (la mèche).
- **Rendu** : CEL validé (contrat `_cel`, lot CS1) : aplats 2-3 tons, encrage brun-noir, accent conservé.

#### 2.8.11 Animations et rendu (Codex, lots VG1 / VG2)
| Anim | Frames | Dir | Impact | Usage |
|---|---|---|---|---|
| `idle` | 8 | 8 | | repos |
| `run` | 8 | 8 | | marche (arc tenu bas) |
| `brace` | 4 | 8 | | ancrée : arc à demi bandé, boucle (s'affiche immobile) |
| `attack` | 4 | 8 | 2 | Trait (tir rapide) |
| `draw` | 6 | 8 | 4 | Trait d'allonge (bande à fond, relâche) |
| `flare` | 5 | 8 | 3 | Fusée (tir tendu, mèche allumée) |
| `net` | 5 | 8 | 2 | Filet (tir lourd, filet qui se déroule) |
| `volley` | 7 | 8 | 4 | Grêle (tir vertical) |
| `death` | 6 | 8 | | s'effondre, l'arc tombe |
| **Total** | **53 × 8 = 424 rendus** | | | |

Assets séparés (VG2) : `arrow` (CREA 4, pointe +X), `arrow_charged` (CREA 4, traînée rouge), `flare_arrow` (CREA 4, étincelles), `net_arrow` (CREA 4, filet roulé), `flare` (CREA, `default` 6 en boucle + `end` 4 : fusée plantée qui crachote), `net_burst` (TOP 96 px/u, 6 frames, filet ouvert, rayon 288 px = 3 u), `hail_zone` (TOP 64 px/u, `default` 8 en boucle + `end` 4, rayon 288 px = 4,5 u), 4 icônes 128 (`vigie_trait`, `vigie_fusee`, `vigie_filet`, `vigie_grele`), portrait. **≈ 2 lots** (VG1 corps medium, VG2 VFX/icônes low).

Replis en attendant : sprite d'Ardent teinté roseau/ardoise (`PLACEHOLDER_TINT`), anims d'action génériques (`attack`, `cast`, `cast_ult`), flèches = lame de Rictus (jamais la braise d'Ardent), fusée = cœur incandescent + anneau dessinés + vraie lumière rouge, filet / Grêle = contours ZoneEffect.

#### 2.8.12 Équilibrage du 22/10/2026 (simulateur `art/tools/night/balance_sim.py --chars vigie --seeds 3`)
Première version (Trait 0,85 sans traversée, Allonge 2,6, Tension 3 s en marche, exposition +20 %, Grêle 0,8 sur 4 u, filet 1,0 sur 2,5 u / 10 s) : cible unique **+36 %**, essaim **−39 %** au niveau 1. Valeurs retenues (celles des tableaux ci-dessus) : Trait 0,8 **traverse 1**, Allonge 2,0, Tension 2,2 s en marche, exposition +10 %, Grêle 0,7 sur 4,5 u, filet 1,2 sur 3 u / 9 s. Résultat vs Ardent : **L6** zone −6 %, mixte +1 %, cible +16 %, subis −34 % (29 vs 44 % PV/min) ; **L12** zone +15 %, mixte −5 %, cible +1 % ; **L1** zone −20 %, mixte +29 %, cible +16 % (Ardent L1 mixte est bas : 41). 0 mort au niveau 6 et 12.

### 2.9 Taliant, le rōnin d'écorce (fiche complète ; samouraï-arbre, mêlée lourde, ressource = Aiguisage)

> Personnage demandé par le joueur le 22/10/2026 : le **samouraï-arbre**. Fiche autonome identique : `docs/fiches/morfil.md`. Code : `game/scripts/spells/morfil_kit.gd` (+ `morfil_twin_blade.gd`), test `game/tests/morfil_test.tscn`, brief Codex `art/tools/night/_sa1.txt`.

**Nom** : *Taliant*. Le nom vient de « taillant », le tranchant d'une lame, ce qui taille. Il dit déjà le gameplay : tout tient au fil de la lame, qu'on use à chaque coup et qu'on aiguise pour lui rendre son taillant. (Identifiant technique conservé : `morfil`.)

#### 2.9.1 Lore (court)
Dans la Forêt de brume, avant la crue, un sabreur sans maître s'adossait chaque soir au même cèdre pour repasser sa lame sur une pierre à eau. Quand l'eau est montée, l'homme s'est noyé contre le tronc, le sabre encore en main. L'homme a pourri. Le sabre, lui, s'est enfoncé dans l'aubier, et l'arbre l'a gardé : en quelques saisons d'eau noire, son bras droit a poussé autour de la soie et la lame est devenue une branche. Le cèdre s'est levé. Il a gardé le chapeau, le hakama, la pierre à la ceinture, et l'habitude : la pluie émousse tout, alors **Taliant s'arrête au milieu du combat pour repasser son bras sur la pierre**.

Titre : **« Rōnin d'écorce »**. Style : mêlée lourde, gestion du tranchant. Config : **4 sorts / 0 passif** (la garde et l'Iaï sont des traits intégrés). Difficulté : **3/5**. Déblocage : ouvert pendant les tests (`characters.json` : `unlocked true`) ; proposé à la sortie : « Tuer un boss d'étage sans laisser l'aiguisage descendre sous 50 % » (indice : « Une lame de bois ne s'émousse que pour qui ne la repasse pas »).

#### 2.9.2 Le principe
De **gros coups** de katana, mais **chaque coup use la lame**. Les dégâts suivent la jauge d'**Aiguisage** (0-100 %) ; Taliant frappe fort tant qu'elle est haute, puis s'arrête pour aiguiser (sort 3). L'ultime ne se lance que **lame au fil (≥ 90 %)** : un second katana pousse dans la main gauche et **double chaque coup** pendant la moitié de la recharge de l'ultime. Le rythme : frapper, sentir la lame faiblir (chiffres de dégâts qui baissent, lueur qui s'éteint), aiguiser au bon moment, puis lancer l'ultime lame neuve.

##### 2.9.2.1 La formule d'aiguisage (lecture retenue)
Spécification du joueur : « 1 % de dégâts par % d'aiguisage ». Lecture retenue, la plus fidèle mot pour mot : **le pourcentage d'aiguisage EST le pourcentage de dégâts infligés**.

**dégâts d'un coup = coef × Dégât_base(L) × (1 + Σ bonus) × Π(mult) × crit × (aiguisage / 100)**

- 100 % d'aiguisage : 100 % des dégâts ; 73 % : 73 % ; 1 point d'aiguisage = 1 % de dégâts, sur toute la plage.
- Exemple (niveau 1, Dégât_base 12) : Fauche-lune (coef 4,0) = 48 à 100 %, 38,4 à 80 %, 19,2 à 40 %.
- Plancher : **l'aiguisage ne descend jamais sous 10 %** (le bois garde toujours un fil). La formule reste exacte, la jauge est bornée : jamais 0 dégât.
- Lecture écartée : « bonus de +aiguisage % » (dégâts × (1 + aiguisage/100)). Avec elle, une lame à 0 % frapperait encore à 100 % : l'usure ne coûterait jamais rien de ses « gros dégâts de base », et Aiguisage deviendrait un buff optionnel au lieu d'un geste vital. La lecture multiplicative fait des coefs élevés (les « gros dégâts de base ») une promesse qu'il faut entretenir.
- Implémentation : le kit duplique le sort au moment du coup avec `coef × aiguisage/100` ; tout le reste (items, crit, procs, `damage_add` du kit) passe par `SpellCaster.compute_damage` sans changement.

##### 2.9.2.2 L'usure : chaque coup réduit l'aiguisage
- Un **coup** = un geste de lame, quel que soit le nombre de monstres touchés (un coup circulaire dans un paquet de 8 coûte autant qu'un estoc dans le vide : pas de punition de la foule).
- Coûts : coup circulaire **4 %**, estoc **4 %**, Fauche-lune **15 %**, Iaï **4 %** (seulement s'il tranche quelque chose). Le second katana des Lames jumelles **ne coûte rien** (il double le coup, pas l'usure), le dégainé de l'ultime non plus.
- L'auto ne se lance pas sans cible (aucune usure à vide).
- Ordre de grandeur : ~6 coups d'auto par 4 s + 1 Fauche-lune toutes les 6 s ≈ 40 % perdus entre deux Aiguisages (10 s) : la jauge oscille entre 100 % et ~55-60 % si l'on aiguise dès que possible, et s'effondre si on l'oublie. Simulateur : aiguisage ≥ 50 % pendant 76-90 % du combat.

#### 2.9.3 Les sorts

| Slot | Sort | Entrée | Recharge | Coef | Portée / forme | Coût d'aiguisage | proc |
|---|---|---|---|---|---|---|---|
| 1 auto | **Taille et estoc** | automatique | 0,7 s | circulaire **1,5** / estoc **2,0** (alternance) | cercle 2,3 u (360°) / estoc 3,2 u, cône 40° | 4 % par coup | 0,8 / 1,0 |
| 2 | **Fauche-lune** | clic gauche / spell_2 | 6 s | **4,0** | demi-cercle **180°, 3,5 u** devant lui | 15 % | 1,0 |
| 3 | **Aiguisage** | clic droit / spell_3 | 10 s | — | soi | remet à **100 %** | — |
| 4 ultime | **Lames jumelles** | clic molette / spell_4 | 30 s | dégainé 2,5 puis **×2 coups** | cercle 2,5 u ; 15 s | exige **≥ 90 %** ; dégainé gratuit | 1,0 |
| roulade | **Iaï** (trait) | dodge | 3 s | 1,5 par monstre traversé | 3 u, tranche à 0,9 u | 4 % s'il touche | 0,8 |

##### Sort 1 : Taille et estoc (automatique)
- Toutes les 0,7 s (`Balance.attack_interval`), vers l'**ennemi le plus proche** (jamais le curseur, comme Ardent et Rictus), **alternance** : un **coup circulaire** (le bras-katana fait le tour du tronc : tout monstre à 2,3 u, coef 1,5, recul 0,3 u, proc 0,8), puis un **estoc** (pointe vers la cible : cône de 40° sur 3,2 u, coef 2,0, recul 0,6 u, proc 1,0), et ainsi de suite.
- Si la cible n'est à portée que de l'estoc (entre 2,3 et 3,2 u), il joue l'estoc même si c'était le tour du cercle : l'alternance ne le fait jamais frapper le vide.
- Sorts de zone (`zone_damage_add`, `zone_size_add` s'appliquent ; la Rune de portée allonge cercle, estoc et Fauche-lune). Chaque coup coûte 4 %.

##### Sort 2 : Fauche-lune (premier sort actif, clic gauche)
- Grand coup en **demi-cercle devant lui** : 180°, **3,5 u**, coef **4,0**, recul 1 u, proc 1,0. Visée : souris / stick droit ; mobile : paquet le plus dense (S5) ; sans rien, l'ennemi le plus proche puis l'orientation.
- Coûte **15 %** : c'est le coup qui use le plus. À lancer lame haute (le chiffre de dégâts le dit).

##### Sort 3 : Aiguisage (clic droit)
- Taliant passe la pierre à eau le long de son bras : l'aiguisage **remonte à 100 %** à la frame d'impact du geste (0,45 s ; l'auto est **suspendue** pendant le geste, il ne frappe pas en aiguisant). Recharge 10 s.
- **Refusé à 100 %** (bouton disponible, rien ne se passe, la recharge n'est pas consommée) : on ne gaspille pas la pierre.
- Auto-cast (accessibilité, simulateur) : seulement sous 55 %.

##### Sort 4 : Lames jumelles (ultime, clic molette)
- **Utilisable seulement si l'aiguisage est ≥ 90 %** ; en dessous, le bouton est grisé (« lame émoussée (90 % requis) ») et un appui ne consomme pas la recharge. La jauge porte un **repère à 90 %**.
- Une branche jaillit de la main gauche et se durcit en **second katana** (dégainé : cercle 2,5 u, coef 2,5, sans coût). Pendant **la moitié du temps de recharge effectif de l'ultime** (30 s → **15 s** ; avec `cooldown_mult` 0,8 : 24 s → 12 s), **chaque coup est doublé** : coup circulaire, estoc, Fauche-lune et Iaï frappent une seconde fois **0,12 s plus tard**, avec le même aiguisage, depuis la position courante. Le second coup ne coûte rien.
- Pendant les Lames jumelles, la **garde** est permanente (une lame frappe, l'autre pare : −45 % de dégâts subis).
- Combo naturel : **Aiguisage → Lames jumelles** (lame à 100 % au moment où tout se double), puis Fauche-lune ×2.

##### Le « sort 2 » de bretteur : l'Iaï (roulade) et la garde
Le jeu a 4 emplacements de sorts (auto + 2 à recharge + ultime) et la roulade. La demande du joueur nomme 4 éléments (auto, sort 1 = Fauche-lune, sort 3 = Aiguisage, ultime) et laisse un « sort 2 » de mobilité/défense. Décision : **ce « sort 2 » est la roulade de Taliant**, remplacée par un **Iaï** (dégainé), comme le Montreur remplace la roulade de Rictus par une levée. Ainsi les touches restent celles de tout le roster (spell_2 = Fauche-lune, spell_3 = Aiguisage, spell_4 = ultime, dodge = Iaï) et le numéro « sort 3 » du joueur tombe exactement sur spell_3.
- **Iaï** : la roulade normale (3 u, 0,25 s, invulnérable, recharge 3 s) **tranche chaque monstre traversé** (à 0,9 u de sa trajectoire, une fois chacun) : coef 1,5, recul 0,4 u, proc 0,8, doublé sous Lames jumelles. Coûte 4 % s'il touche au moins un monstre. Mobilité + défense + dégâts : le bretteur traverse le paquet au lieu de le fuir.
- **Garde du bretteur** (équilibrage) : après chaque geste de lame, **−45 % de dégâts subis pendant 0,6 s** (la lame dévie les coups). Mêlée au contact : la garde tient tant qu'il frappe ; elle tombe s'il court ou aiguise.

#### 2.9.4 Table d'états

| État | Déplacement | Vitesse | Sort 1 | Sort 2 | Sort 3 | Sort 4 | Roulade | Dégâts subis |
|---|---|---|---|---|---|---|---|---|
| normal | marche | 3,9 | alternance | oui | oui (si < 100 %) | si ≥ 90 % | Iaï | ×1 (×0,55 0,6 s après un coup) |
| aiguisage (0,45 s) | marche | 3,9 | **suspendu** | oui | — | si ≥ 90 % | oui | ×1 |
| Lames jumelles (15 s) | marche | 3,9 | **doublé** | **doublé** | oui | — (recharge) | Iaï doublé | **×0,55** |
| Iaï (0,25 s) | dash 3 u | 12 | oui | oui | oui | oui | — | invulnérable |

#### 2.9.5 Ressource : jauge d'Aiguisage (HUD)
- `KitResource` : id `sharpness`, label « Aiguisage », ratio = aiguisage/100, texte « 73 % », **repère à 0,9** (seuil de l'ultime), `boost` (jauge qui pulse) pendant les Lames jumelles. Affichée par le `ResourceGauge` générique (PC : à gauche de la barre de sorts ; tactile : au-dessus de la grappe).
- Sauvegarde de run : `save_state()` = {sharpness, twin_left, twin_total}. Nouvel étage : **lame repassée à 100 %** (il aiguise entre deux étages).
- Lisibilité en jeu : chiffres de dégâts (proportionnels), éclat de lumière `morfil_edge` proportionnel à l'aiguisage à chaque coup ; à venir avec SA1 : lueur `_e` du tranchant modulée par la jauge.

#### 2.9.6 Synergies (items et combos)
- **Recharge (`cooldown_mult`, Horloge arcanique)** : Aiguisage plus souvent = lame toujours haute ; l'ultime revient plus vite et sa durée suit (toujours la moitié de la recharge effective : 50 % du temps en double, quoi qu'il arrive). Son meilleur axe.
- **Vitesse d'attaque** : plus de coups = plus de dégâts mais plus d'usure (4 % par coup) : synergie à doser avec la recharge. Bon test de compréhension du kit.
- **Rune de portée** (`zone_size_add`) : cercle, estoc, Fauche-lune et dégainé plus larges : excellent.
- **Critiques, procs** : l'estoc (proc 1,0) et la Fauche-lune (1,0) portent bien Étincelle / Éclair en bouteille ; sous Lames jumelles chaque coup roule deux fois ses procs.
- **Danseur / dégâts en mouvement** : l'Iaï compte comme mouvement.
- **Items de défense** : la garde (−45 % après un coup) se cumule sous `MITIGATION_CAP`.
- **Combos** : Aiguisage → Lames jumelles → Fauche-lune ; Iaï à travers le paquet → coup circulaire au milieu ; Aiguisage juste avant un boss.

#### 2.9.7 Statistiques de base (comparé à Ardent et Rictus)

| Stat | Ardent | Rictus | **Taliant** | Note |
|---|---|---|---|---|
| PV max (L) | 100 + 30 (L−1) | 95 + 28 | **115 + 35 (L−1)** | cœur de bois dense (équilibrage 105 → 115) |
| Armure | 0 | 10 | **25** | écorce (équilibrage 15 → 25) |
| Régénération | 1 + 0,2 | 0,6 + 0,12 | **0,8 + 0,16** | sève lente |
| Dégât_base | 12 + 2,4 (L−1) | idem | idem | × aiguisage/100 |
| Vitesse | 4,0 | 4,2 | **3,9** | pas lent, posé |
| Roulade | 3 u | levée 3 u | **Iaï 3 u** (tranche) | |
| Hitbox | 0,5 u | 0,45 u | **0,45 u** | arbre maigre |
| Défense propre | — | garde du Montreur −30 % / 0,5 s | **garde du bretteur −45 % / 0,6 s** ; permanente sous Lames jumelles | |

Coef/s mono-cible au contact (aiguisage moyen ~0,8) : auto ≈ 2,5 × 0,8 = 2,0 ; Fauche-lune 0,67 × 0,8 = 0,53 ; ×2 pendant la moitié du temps (ultime) → **≈ 3,8 en moyenne** (Ardent ≈ 3,0) ; le simulateur (pilote moyen, aiguisage et ultime en auto-cast) donne une cible unique à ±10 % d'Ardent.

##### Équilibrage (simulateur `art/tools/night/balance_sim.py --chars morfil --seeds 2`, 22/10/2026)
Version 1 (circulaire 1,5 / estoc 2,6 / Fauche 5,0, coûts 3 / 12 %, Aiguisage 8 s, PV 105, armure 15, sans garde) : cible **+34 %** (L1) / **+54 %** (L6) / **+56 %** (L12), essaim −22 %, **dégâts subis ×2 à ×4,5**. Valeurs retenues : estoc 2,0, Fauche 4,0, dégainé 2,5, cercle 2,3 u, coûts 4 / 15 %, Aiguisage 10 s, PV 115 + 35, armure 25, garde −45 % / 0,6 s.

| Config | DPS zone | DPS mixte | DPS cible | Dégâts subis (% PV/min) | Morts | Aiguisage ≥ 50 % |
|---|---|---|---|---|---|---|
| L1 | −13 % | −6 % | −1 % | 74 (−18 %) | 0 | 76 % |
| L6 | −15 % | +0 % | −10 % | 42 (−4 %) | 0 | 84 % |
| L12 | +10 % | −12 % | +5 % | 43 (**+156 %**, Ardent 17) | 0 | 90 % |

Tous les dégâts sont dans ±20 % d'Ardent à tous les niveaux. Point ouvert : dégâts subis au niveau 12 (élite et mini-boss au contact : 82 et 96 % PV/min ; Ardent kite à 5,5 u), comme les autres mêléistes (Avare +108 %), sans mort (PV min 86 %). Leviers si le playtest le confirme : garde −55 %, Iaï qui laisse 0,5 s de garde.

#### 2.9.8 Prise en main, forces, faiblesses
- **Difficulté 3/5** : un seul chiffre à surveiller, mais il faut aiguiser au bon moment (pas en plein paquet : l'auto s'arrête) et garder la lame au-dessus de 90 % quand l'ultime revient. Tips : « Ta lame s'use à chaque coup : aiguise avant le gros paquet », « Lames jumelles exige une lame au fil (90 %) », « L'Iaï tranche tout ce que tu traverses ».
- **Forces** : coups lourds et lisibles, excellent mono-cible lame haute, burst énorme sous Lames jumelles, mobilité offensive (Iaï), robuste au contact (écorce + garde).
- **Faiblesses** : dégâts qui fondent si on oublie d'aiguiser, lent (3,9), mêlée pure (les tireurs l'obligent à traverser), fenêtre d'ultime contrainte (≥ 90 %).

#### 2.9.9 Entrées par plateforme
| Plateforme | Fauche-lune | Aiguisage | Lames jumelles | Iaï |
|---|---|---|---|---|
| PC | clic gauche (2), vise le curseur | clic droit (3) | molette (4), grisé sous 90 % | Maj / dodge, vers le déplacement sinon le curseur |
| Manette | spell_2, stick droit | spell_3 | spell_4 | dodge |
| Mobile | paquet le plus dense à 3,5 u | bouton | bouton grisé + texte « lame émoussée » | bouton roulade |

#### 2.9.10 Aspect (chara design)
- **Silhouette (1,45 u, plus haut qu'Ardent mais plus étroit)** : **arbre humanoïde MAIGRE**. Tronc de cèdre fendu en deux jambes noueuses, taille creuse (on voit la pluie à travers une fente du tronc), épaules étroites et hautes, cou court enfoui sous le chapeau. Posture d'iaï : légèrement voûté, genou avant fléchi, poids sur l'arrière. **Bras droit = katana** : l'écorce remonte jusqu'au coude, puis le bois se resserre en une lame longue (≈ 1 u), courbe, d'un bois noir veiné, poli au tranchant, avec la tsuba d'origine (garde de fer rouillé) prise dans les nœuds du poignet. **Bras gauche** : branche fine et noueuse, doigts-rameaux, tient le fourreau (une branche creuse) contre la hanche.
- **Habit de samouraï, délavé et trempé** : hakama de toile indigo usée jusqu'à la trame, déchiré aux chevilles où sortent des racines ; kimono croisé sous un **dō** (plastron) de lamelles d'écorce laquées rouge sombre, écaillées ; deux **sode** (épaulières) en plaques d'écorce lacées de chanvre ; obi de corde de chanvre où pend la **pierre à eau** (pierre grise, plate, usée en creux) ; mousse et lichen dans les plis.
- **Le chapeau (inspiré du Solomonk de Dofus, sans le copier)** : le Solomonk est une coiffe de Dofus (équipement niveau 118-120, objet 7143) que l'encyclopédie présente comme le chapeau d'un vieux chef pandawa, un chapeau si creux qu'il servait aussi de pot ; c'est un chapeau-bol démesuré qui écrase la silhouette. Chez Taliant : **un très large chapeau de vannerie en bol renversé**, diamètre ≈ **2,2 fois la largeur des épaules** (≈ 1 u, il dépasse nettement la silhouette vue de dessus : c'est la première chose qu'on lit en iso), **calotte basse et ronde**, **bord large presque plat qui retombe un peu** sur les côtés et cache les yeux, **tressé en lanières d'écorce et de jonc** (trame visible en tons cel), bord effiloché d'où pend la pluie, **cordon de chanvre** noué sous le « menton », mousse sur le dessus. Équivalent japonais réel : entre le **sugegasa** très aplati et le **jingasa** (chapeau de fantassin en bol bas). Rien des couleurs, motifs ou proportions exactes de l'objet Dofus : seulement l'idée « chapeau-bol énorme qui mange la silhouette ». (Les pages de l'encyclopédie et des wikis étaient inaccessibles à la recherche : description tirée du texte officiel de l'objet ; Codex peut inventer librement dans cet esprit.)
- **Visage** : sous le bord, l'ombre ; deux fentes d'écorce en guise d'yeux où perle un point de sève (même accent, très discret).
- **Palette** : écorce gris-brun #3A3129, bois mort #5E5246, toile indigo délavée #343C4A, laque rouge sombre écaillée #5A2420, chanvre #8A7A5C, mousse #4F5A3A, fer rouillé #6B3A22. **Accent émissif unique : « fil de sève » #CDEB6E** (vert-jaune pâle, froid) : **uniquement le tranchant du katana** (une ligne fine le long de la lame) et les deux points de sève des yeux. Plus la lame est aiguisée, plus le fil brille (modulation de `_e` par l'aiguisage, prévue au branchement SA1). Distinct des accents du roster (braise d'Ardent #FF8C33, cuivre #FF7A1F, eau #5FD4E8, argent spectral #9FC8C0, vase #8DDBA8).
- **Rendu CEL validé** (art/briefs/STYLE_cel.md, profil `creature`) : 3 tons, encre brun-noir, ombres relevées (jamais un tronc presque noir sur le sol de nuit), lisible par la silhouette (chapeau + bras-lame).

#### 2.9.11 Animations et VFX (lot Codex SA1)
Cellule 192, 8 directions (e, se, s, sw, w, nw, n, ne), rig CREA iso 30° comme Ardent/Rictus, pivot des pieds identique.

| Anim | Frames | Impact (index 0) | Usage |
|---|---|---|---|
| `idle` | 8 | | repos, chapeau qui goutte |
| `run` | 8 | | course basse, lame en arrière |
| `cut_circle` | 6 | 2 | auto : coup circulaire (tour complet du bras) |
| `thrust` | 6 | 2 | auto : estoc |
| `crescent` | 8 | 4 | Fauche-lune (grand arc horizontal) |
| `sharpen` | 8 | 5 | Aiguisage (pierre le long du bras, étincelle de sève) |
| `twin_draw` | 8 | 4 | ultime : la branche gauche pousse et durcit en katana |
| `dodge` | 5 | | Iaï (dégainé en traversée) |
| `hurt` | 3 | | coup reçu |
| `death` | 8 | | il s'agenouille, la lame se fend, le chapeau roule |
| `idle_dual`, `run_dual`, `cut_circle_dual`, `thrust_dual`, `crescent_dual` | 8 / 8 / 6 / 6 / 8 | idem | mêmes anims avec le second katana (Lames jumelles) |

Total ≈ (8+8+6+6+8+8+8+5+3+8) × 8 + (8+8+6+6+8) × 8 = **832 rendus**. VFX (vue TOP, 2 tons cel, profil `vfx`) : `cut_circle` (anneau, 6), `cut_thrust` (pointe vers +X, 5), `cut_crescent` (demi-cercle centré sur +X, 6), `twin_draw` (8), `iai_trail` (4), `sharpen_sparks` (CREA 6) ; anneau/arc extérieur à 45 % de la largeur de frame. 4 icônes 128 (`morfil_taille_estoc`, `morfil_fauche_lune`, `morfil_aiguisage`, `morfil_lames_jumelles`), portrait 256 (`ui/portraits/morfil.png`). Coût : **2 lots** (SA1 corps + anims, SA2 VFX/icônes si le quota coupe SA1 en deux).

Replis en attendant (code) : sprite d'Ardent teinté écorce (`PLACEHOLDER_TINT`, échelle 1,05), anims génériques (`attack` / `cast` / `cast_ult`), coups = croissants et anneaux de `ZoneEffect` à l'accent, second katana = trait de sève tenu dans la main gauche (`MorfilTwinBlade`), Iaï = fil de sève tendu sur le trajet (0,3 s), pas de fantômes braise.

## 3. Comparatif, production, systèmes

### 3.1 Tableau comparatif

| Perso | Rôle | Ressource / gimmick | PV (L) | Armure | Régén (L) | Vitesse | Roulade | Config | Prise en main | Lots Codex | Rendus |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Ardent (réf.) | zone, débutant | recharges | 100 + 30 | 0 | 1 + 0,2 | 4,0 | 3 u | 4 sorts | 1/5 | 1 (re-rendu iso) | 128 |
| **Tocsin** | contrôle, combos | **ses membres** (charges, états de locomotion) | 130 + 36 | 20 | 0,8 + 0,16 | 4,0 → 1,4 selon l'état | 3 / 1,5 / 2 u | 4 sorts | 4/5 | **5** | 696 + 180 |
| Averse | distance / zone | **eau de pluie** (poids = vitesse) | 90 + 27 | 0 | 1 + 0,2 | 3,4-4,4 | 3 u (1,5 pleine) | 4 sorts | 2/5 | 2 | 296 |
| Arpenteuse | zone / piège | **chaîne au sol** (attaque = trajet) | 85 + 25 | 0 | 1 + 0,2 | 4,2 | 3 u | 4 sorts | 3/5 | 2 | 240 |
| Rainette | mobilité / burst | **souffle** (bonds discrets) | 90 + 27 | 10 | 1,2 + 0,24 | bonds ≈ 5,5 | bond arrière 3 u | 4 sorts | 3/5 | 2,5 | 296 |
| Avare | mêlée / tank | **or** (puissance, saignement) | 120 + 36 | 15 | 0,8 + 0,16 | 3,8 | 2,5 u | 4 sorts | 2/5 | 2 | 304 |
| Bourbe | invocatrice / mêlée | **PV max = familiers** | 150 + 45 | 10 | 1,5 + 0,3 | 3,6-4,2 | 2,5 u | 4 sorts | 3/5 | 3 | 288 + 128 |
| **Rictus** | mêlée / leurres / burst | **pantin + fantôme** (toupie, doublures explosives, levée aérienne) | 95 + 28 | 10 | 0,6 + 0,12 (+2 %/sort) | 4,2 (4,8 toupie) | levée 3 u | 4 sorts | 2/5 | **3** | 424 + 60 |
| Vigie | distance / archère (§2.8) | **Tension** (tir chargé qui perce, fusées qui exposent, filet) | 90 + 27 | 0 | 1 + 0,2 | 4,2 | 3 u | 4 sorts | 2/5 | 2 | 424 + ≈ 40 |
| **Taliant** | mêlée lourde / bretteur (§2.9) | **Aiguisage** (dégâts × aiguisage/100, usure par coup, ultime ≥ 90 % qui double les coups) | 115 + 35 | 25 | 0,8 + 0,16 | 3,9 | Iaï 3 u (tranche) | 4 sorts | 3/5 | 2 | ≈ 830 + 40 |

Roster proposé au lancement (8) : Ardent + Tocsin disponibles, Averse / Arpenteuse / Bourbe visibles, Rainette / Avare / Rictus cachés. Les 5 personnages du GDD §5 (Veilleuse, Brise-Os, Chronomancienne, Invocateur, Faux-Roi) deviennent la **réserve LiveOps** (« nouveau personnage tous les 2 mois ») ou sont fusionnés (Bourbe reprend l'objectif de l'Invocateur). `characters.json` est à mettre à jour par l'orchestrateur (hors périmètre de ce doc).

### 3.2 Ordre de production recommandé
| # | Perso | Pourquoi à cette place | Nouveau pour le code |
|---|---|---|---|
| 1 | **Tocsin** | Concept du joueur, **le plus différenciant** (vitrine, bande-annonce), et ses systèmes (charges, poussée, emprisonnement, pickups de membres, ciblage par densité) **sont réutilisés** par Arpenteuse, Rainette, Bourbe. Coût élevé (5 lots + S1-S7) : à lancer en premier pour qu'il mûrisse en playtest | S1, S2, S3, S4 (option), S5, S6, S7, S0 |
| 2 | **Averse** | **Le plus rentable** : 2 lots, comportements existants (projectile, cône = nova orientée, zone au sol), 1 jauge de ressource générique (S8) qui servira à Arpenteuse, Rainette, Avare ; met à l'épreuve le lien météo (S12) | S8, S12 |
| 3 | **Rictus** | Deuxième vitrine visuelle (fantôme + fils) pour 3 lots seulement ; comportements de sorts simples (zone orientée, éventail, toupie = nova continue qui se déplace) ; ses **leurres (S14)** et le **compagnon (S15)** sont l'étape intermédiaire vers les familiers de Bourbe ; prise en main 2/5 = bon second personnage pour les joueurs qui trouvent Tocsin trop exigeant | S14, S15, S6 (couteaux plantés), S7 (toupie mobile) |
| 4 | **Arpenteuse** | Art bon marché, gimmick très lisible ; un seul système nouveau (traîne-zone S9) ; réutilise `imprisoned` | S9 |
| 5 | **Rainette** | Locomotion par bonds (S11) = premier perso qui change le `_physics_process` du joueur ; profite du billboard/`lift_px` iso et de la levée de Rictus (vol au-dessus des monstres déjà codé) | S11 |
| 6 | **Avare** | Couplage avec l'économie : à produire quand `economy_test` et le budget d'or sont stables | S13 |
| 7 | **Bourbe** | Les familiers (S10 : IA alliée, pool, ciblage ennemi→allié, lisibilité) sont le système le plus coûteux ; 3 lots d'art ; étend S14 (provocation, PV, explosion au rappel) | S10 |

### 3.3 Systèmes à ajouter (pour l'orchestrateur, dossiers partagés = orchestrateur)
- **S0 `CharacterData` étendu** : `base_hp`, `hp_per_level`, `armor`, `base_regen`, `regen_per_level`, `base_speed_u`, `dodge_distance_u`, `kit_script` (logique propre au perso : états, ressource) ; `Balance.player_max_hp/regen` prennent le personnage. `Player` lit ces valeurs au lieu des constantes.
- **S1 Charges de sorts** : `SpellData.charges` (défaut 1), recharge séquentielle dans `SpellCaster` (`_charges[slot]`, une seule charge en recharge), stat `extra_charges` (sorts à charges ≥ 2 seulement), HUD avec pastilles, `get_spell_cooldowns()` renvoie `charges`/`max_charges`. Tocsin (bras, jambes), Bourbe (mottes).
- **S2 Machine d'états de locomotion + visuel en calques** : `player/limb_state.gd` (membres présents → multiplicateur de vitesse, distance de roulade, anim, blocages), `PlayerVisualLayers` (7 sprites synchronisés, ordre par direction depuis `layers_order.json`, `_e` modulé). Tocsin seulement, mais la machine d'états sert à Rainette (bond / sol / souffle).
- **S3 Statuts et poussée côté `Enemy`** : `imprisoned` (vitesse 0, pas d'attaque, `is_slowed()` vrai, immunité au recul normal), `hooked` (traîné vers un point, sans collision), `Enemy.push(vec_px, duration)` au-dessus du plafond `KB_MAX_U` avec masse, séparation désactivable par monstre (pack). Boss : exclus de `imprisoned`/`hooked`.
- **S4 (option) Collisions monstre→monstre pendant une poussée** (« quilles ») : transfert de 50 % de la poussée + dégâts 100 % base, une fois par monstre. À prototyper sur `enemies_perf` (coût CPU à 250 monstres) ; abandonnable.
- **S5 Ciblage automatique par mode** : `SpellData.target_mode` ∈ {`nearest`, `densest` (paquet le plus dense dans la portée, grille de 1 u), `imprisoned_first`, `self`} ; S5b option « maintenir et glisser pour viser » sur mobile (commun à tous).
- **S6 Pickups de membres** : nouveau type dans `pickup_manager` (contact 0,6 u, délai, pas d'aimant, expiration = fin de recharge, callback vers le kit), rendu billboard.
- **S7 Comportements de projectile** : `BOOMERANG` (aller-retour + accrochage), `LOB` (arc via `lift_px`, ombre au sol, explosion à l'atterrissage), `CORRIDOR` (ligne qui pousse), `rests_on_ground` (l'asset reste au sol → S6). `SpellData.Behavior` s'étend ; les kits non-Ardent sortent de `ArdentKit.SPELL_LIGHTS` (table de presets par perso).
- **S8 Ressource de personnage** : `Player.resource` (0-1, nom, icône, règles de gain/coût dans le `kit_script`), jauge HUD sous les PV, sorts avec `resource_cost` et `resource_min`. Averse (eau), Arpenteuse (chaîne), Rainette (souffle), Avare (or = `RunState.gold`, affichage en P).
- **S9 Traîne-zone** : `TrailZone` (polyligne des 14 derniers u, test segment-cercle par monstre, tick 0,5 s, fermeture de boucle = polygone + test point-dans-polygone, piquet = segment dynamique). Arpenteuse.
- **S10 Familiers** : groupe `allies`, pool de `Ally` (IA simple : suivre / chasser à 6 u / revenir), les monstres ciblent l'allié le plus proche s'il est à 2 u, dégâts via `SpellCaster.deal_damage` (procs inclus), anneau d'allié, plafond 4. Bourbe (et la variante Phénix d'Ardent, déjà listée « non implémentée »).
- **S11 Locomotion par bonds** : `_physics_process` par état (sol / vol), masque de collision sans la couche 3 en vol, `lift_px` du billboard, atterrissage = zone, souffle = S8. Rainette.
- **S12 Météo lisible par le gameplay** : `AmbianceManager.rain_intensity()` (profil + variantes), `StageMap.is_water(pos)` déjà existant côté occluders à exposer. Averse.
- **S13 Or comme ressource** : `RunState.spend_gold` avec raison (`spell`), pièces qui retombent (pickups avec valeur et expiration), bonus de dégâts lu dans `compute_damage` (`gold_power_add`), prise en compte dans `economy_test`. Avare.
- **S14 Leurres** : `Decoy` (groupe `allies`, pool de 6, PV, minuteur, orientation, **provocation** : dans `Enemy`, cible = leurre le plus proche à 4 u sinon le joueur, jamais pour les boss ; explosion à la mort / au minuteur / à l'impact ; `push(dir, speed, dist)` déclenché par une zone du joueur) ; dégâts via `SpellCaster.deal_damage` (procs du joueur). Rictus ; base des familiers S10.
- **S15 Compagnon visuel** : `CompanionSprite` (sprite synchronisé sur l'animation du joueur, hauteur `lift_px`, alpha, z, décalage écran) + `StringRig` (N `Line2D` entre points nommés exportés par frame et direction dans un manifeste, texture `_e`). Rictus (le Montreur) ; réutilisable pour une variante Phénix d'Ardent ou le bras de rechange de Tocsin.
- **S7 (complément Rictus)** : `ARC` (demi-cercle orienté vers la cible la plus proche, zone instantanée), `FAN` (N projectiles, angle), `SPIN` (nova continue attachée au joueur, multiplicateur de vitesse, inertie, roulade bloquée, suspension du sort 1).
- **Transverse** : `characters.json` (nouvelles entrées, `playable`), mapping tactile (pastilles, bouton grisé avec cause), tips par personnage, sauvegarde (état des membres, ressource, charges), `test_balance.gd` (stats par perso), `sprites_test` (calques, compagnon).

### 3.4 Risques
- **Tocsin** : lisibilité des 5 recharges (parade : le corps est l'indicateur, pastilles, portrait) ; frustration du cloche-pied (parade : tip, poussée de jambe généreuse, ramassage gratuit) ; mémoire des calques (parade : rognage, replis listés §1.12) ; S4 quilles coûteux (optionnel).
- **Averse** : dépend de la météo par carte (Cryptes) : à équilibrer avec l'apport des kills ; le niveau d'eau en `_e` demande un masque propre par Codex.
- **Arpenteuse** : test polyligne × 250 monstres par tick (parade : grille spatiale, tick 0,5 s, 28 segments max).
- **Rainette** : bonds + murs iso de 1,25 u (elle ne les saute pas en v1) ; sensation « engagée » à valider au portail iso (vitesse verticale).
- **Avare** : économie (le joueur qui thésaurise n'achète plus de coffres : plafond +90 % volontairement bas).
- **Bourbe** : mottes confondues avec des T1 (parade : feu follet + anneau d'allié + silhouette 96² distincte).
- **Rictus** : le Montreur qui masque l'action (parade : alpha ≈0,8 mais silhouette fine, décalage haut-gauche, sous les projectiles ; test de lisibilité sur `capture_hit_feel`) ; coût des 5 `Line2D` + 6 leurres provoqués à 250 monstres (retarget = une distance de plus par monstre, à mesurer sur `enemies_perf`) ; toupie sans roulade jugée punitive (parade : raccourcir à 2 s si les playtests le demandent) ; le « malsain » qui glisse vers le cartoon (parade : planche de contact M1 validée avant M2).
