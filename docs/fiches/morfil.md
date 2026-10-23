# Taliant, le rōnin d'écorce (fiche complète)

> Personnage demandé par le joueur le 22/10/2026 : le **samouraï-arbre**. Fiche autonome ; la même fiche figure dans `docs/Design_Personnages.md` §2.9. Code : `game/scripts/spells/morfil_kit.gd` (+ `morfil_twin_blade.gd`), test `game/tests/morfil_test.tscn`, brief Codex `art/tools/night/_sa1.txt`.

**Nom** : *Taliant*. Le nom vient de « taillant », le tranchant d'une lame, ce qui taille. Il dit déjà le gameplay : tout tient au fil de la lame, qu'on use à chaque coup et qu'on aiguise pour lui rendre son taillant. (Identifiant technique conservé : `morfil`.)

## 1. Lore (court)
Dans la Forêt de brume, avant la crue, un sabreur sans maître s'adossait chaque soir au même cèdre pour repasser sa lame sur une pierre à eau. Quand l'eau est montée, l'homme s'est noyé contre le tronc, le sabre encore en main. L'homme a pourri. Le sabre, lui, s'est enfoncé dans l'aubier, et l'arbre l'a gardé : en quelques saisons d'eau noire, son bras droit a poussé autour de la soie et la lame est devenue une branche. Le cèdre s'est levé. Il a gardé le chapeau, le hakama, la pierre à la ceinture, et l'habitude : la pluie émousse tout, alors **Taliant s'arrête au milieu du combat pour repasser son bras sur la pierre**.

Titre : **« Rōnin d'écorce »**. Style : mêlée lourde, gestion du tranchant. Config : **4 sorts / 0 passif** (la garde et l'Iaï sont des traits intégrés). Difficulté : **3/5**. Déblocage : ouvert pendant les tests (`characters.json` : `unlocked true`) ; proposé à la sortie : « Tuer un boss d'étage sans laisser l'aiguisage descendre sous 50 % » (indice : « Une lame de bois ne s'émousse que pour qui ne la repasse pas »).

## 2. Le principe
De **gros coups** de katana, mais **chaque coup use la lame**. Les dégâts suivent la jauge d'**Aiguisage** (0-100 %) ; Taliant frappe fort tant qu'elle est haute, puis s'arrête pour aiguiser (sort 3). L'ultime ne se lance que **lame au fil (≥ 90 %)** : un second katana pousse dans la main gauche et **double chaque coup** pendant la moitié de la recharge de l'ultime. Le rythme : frapper, sentir la lame faiblir (chiffres de dégâts qui baissent, lueur qui s'éteint), aiguiser au bon moment, puis lancer l'ultime lame neuve.

### 2.1 La formule d'aiguisage (lecture retenue)
Spécification du joueur : « 1 % de dégâts par % d'aiguisage ». Lecture retenue, la plus fidèle mot pour mot : **le pourcentage d'aiguisage EST le pourcentage de dégâts infligés**.

**dégâts d'un coup = coef × Dégât_base(L) × (1 + Σ bonus) × Π(mult) × crit × (aiguisage / 100)**

- 100 % d'aiguisage : 100 % des dégâts ; 73 % : 73 % ; 1 point d'aiguisage = 1 % de dégâts, sur toute la plage.
- Exemple (niveau 1, Dégât_base 12) : Fauche-lune (coef 4,0) = 48 à 100 %, 38,4 à 80 %, 19,2 à 40 %.
- Plancher : **l'aiguisage ne descend jamais sous 10 %** (le bois garde toujours un fil). La formule reste exacte, la jauge est bornée : jamais 0 dégât.
- Lecture écartée : « bonus de +aiguisage % » (dégâts × (1 + aiguisage/100)). Avec elle, une lame à 0 % frapperait encore à 100 % : l'usure ne coûterait jamais rien de ses « gros dégâts de base », et Aiguisage deviendrait un buff optionnel au lieu d'un geste vital. La lecture multiplicative fait des coefs élevés (les « gros dégâts de base ») une promesse qu'il faut entretenir.
- Implémentation : le kit duplique le sort au moment du coup avec `coef × aiguisage/100` ; tout le reste (items, crit, procs, `damage_add` du kit) passe par `SpellCaster.compute_damage` sans changement.

### 2.2 L'usure : chaque coup réduit l'aiguisage
- Un **coup** = un geste de lame, quel que soit le nombre de monstres touchés (un coup circulaire dans un paquet de 8 coûte autant qu'un estoc dans le vide : pas de punition de la foule).
- Coûts : coup circulaire **4 %**, estoc **4 %**, Fauche-lune **15 %**, Iaï **4 %** (seulement s'il tranche quelque chose). Le second katana des Lames jumelles **ne coûte rien** (il double le coup, pas l'usure), le dégainé de l'ultime non plus.
- L'auto ne se lance pas sans cible (aucune usure à vide).
- Ordre de grandeur : ~6 coups d'auto par 4 s + 1 Fauche-lune toutes les 6 s ≈ 40 % perdus entre deux Aiguisages (10 s) : la jauge oscille entre 100 % et ~55-60 % si l'on aiguise dès que possible, et s'effondre si on l'oublie. Simulateur : aiguisage ≥ 50 % pendant 76-90 % du combat.

## 3. Les sorts

| Slot | Sort | Entrée | Recharge | Coef | Portée / forme | Coût d'aiguisage | proc |
|---|---|---|---|---|---|---|---|
| 1 auto | **Taille et estoc** | automatique | 0,7 s | circulaire **1,5** / estoc **2,0** (alternance) | cercle 2,3 u (360°) / estoc 3,2 u, cône 40° | 4 % par coup | 0,8 / 1,0 |
| 2 | **Fauche-lune** | clic gauche / spell_2 | 6 s | **4,0** | demi-cercle **180°, 3,5 u** devant lui | 15 % | 1,0 |
| 3 | **Aiguisage** | clic droit / spell_3 | 10 s | — | soi | remet à **100 %** | — |
| 4 ultime | **Lames jumelles** | clic molette / spell_4 | 30 s | dégainé 2,5 puis **×2 coups** | cercle 2,5 u ; 15 s | exige **≥ 90 %** ; dégainé gratuit | 1,0 |
| roulade | **Iaï** (trait) | dodge | 3 s | 1,5 par monstre traversé | 3 u, tranche à 0,9 u | 4 % s'il touche | 0,8 |

### Sort 1 : Taille et estoc (automatique)
- Toutes les 0,7 s (`Balance.attack_interval`), vers l'**ennemi le plus proche** (jamais le curseur, comme Ardent et Rictus), **alternance** : un **coup circulaire** (le bras-katana fait le tour du tronc : tout monstre à 2,3 u, coef 1,5, recul 0,3 u, proc 0,8), puis un **estoc** (pointe vers la cible : cône de 40° sur 3,2 u, coef 2,0, recul 0,6 u, proc 1,0), et ainsi de suite.
- Si la cible n'est à portée que de l'estoc (entre 2,3 et 3,2 u), il joue l'estoc même si c'était le tour du cercle : l'alternance ne le fait jamais frapper le vide.
- Sorts de zone (`zone_damage_add`, `zone_size_add` s'appliquent ; la Rune de portée allonge cercle, estoc et Fauche-lune). Chaque coup coûte 4 %.

### Sort 2 : Fauche-lune (premier sort actif, clic gauche)
- Grand coup en **demi-cercle devant lui** : 180°, **3,5 u**, coef **4,0**, recul 1 u, proc 1,0. Visée : souris / stick droit ; mobile : paquet le plus dense (S5) ; sans rien, l'ennemi le plus proche puis l'orientation.
- Coûte **15 %** : c'est le coup qui use le plus. À lancer lame haute (le chiffre de dégâts le dit).

### Sort 3 : Aiguisage (clic droit)
- Taliant passe la pierre à eau le long de son bras : l'aiguisage **remonte à 100 %** à la frame d'impact du geste (0,45 s ; l'auto est **suspendue** pendant le geste, il ne frappe pas en aiguisant). Recharge 10 s.
- **Refusé à 100 %** (bouton disponible, rien ne se passe, la recharge n'est pas consommée) : on ne gaspille pas la pierre.
- Auto-cast (accessibilité, simulateur) : seulement sous 55 %.

### Sort 4 : Lames jumelles (ultime, clic molette)
- **Utilisable seulement si l'aiguisage est ≥ 90 %** ; en dessous, le bouton est grisé (« lame émoussée (90 % requis) ») et un appui ne consomme pas la recharge. La jauge porte un **repère à 90 %**.
- Une branche jaillit de la main gauche et se durcit en **second katana** (dégainé : cercle 2,5 u, coef 2,5, sans coût). Pendant **la moitié du temps de recharge effectif de l'ultime** (30 s → **15 s** ; avec `cooldown_mult` 0,8 : 24 s → 12 s), **chaque coup est doublé** : coup circulaire, estoc, Fauche-lune et Iaï frappent une seconde fois **0,12 s plus tard**, avec le même aiguisage, depuis la position courante. Le second coup ne coûte rien.
- Pendant les Lames jumelles, la **garde** est permanente (une lame frappe, l'autre pare : −45 % de dégâts subis).
- Combo naturel : **Aiguisage → Lames jumelles** (lame à 100 % au moment où tout se double), puis Fauche-lune ×2.

### Le « sort 2 » de bretteur : l'Iaï (roulade) et la garde
Le jeu a 4 emplacements de sorts (auto + 2 à recharge + ultime) et la roulade. La demande du joueur nomme 4 éléments (auto, sort 1 = Fauche-lune, sort 3 = Aiguisage, ultime) et laisse un « sort 2 » de mobilité/défense. Décision : **ce « sort 2 » est la roulade de Taliant**, remplacée par un **Iaï** (dégainé), comme le Montreur remplace la roulade de Rictus par une levée. Ainsi les touches restent celles de tout le roster (spell_2 = Fauche-lune, spell_3 = Aiguisage, spell_4 = ultime, dodge = Iaï) et le numéro « sort 3 » du joueur tombe exactement sur spell_3.
- **Iaï** : la roulade normale (3 u, 0,25 s, invulnérable, recharge 3 s) **tranche chaque monstre traversé** (à 0,9 u de sa trajectoire, une fois chacun) : coef 1,5, recul 0,4 u, proc 0,8, doublé sous Lames jumelles. Coûte 4 % s'il touche au moins un monstre. Mobilité + défense + dégâts : le bretteur traverse le paquet au lieu de le fuir.
- **Garde du bretteur** (équilibrage) : après chaque geste de lame, **−45 % de dégâts subis pendant 0,6 s** (la lame dévie les coups). Mêlée au contact : la garde tient tant qu'il frappe ; elle tombe s'il court ou aiguise.

## 4. Table d'états

| État | Déplacement | Vitesse | Sort 1 | Sort 2 | Sort 3 | Sort 4 | Roulade | Dégâts subis |
|---|---|---|---|---|---|---|---|---|
| normal | marche | 3,9 | alternance | oui | oui (si < 100 %) | si ≥ 90 % | Iaï | ×1 (×0,55 0,6 s après un coup) |
| aiguisage (0,45 s) | marche | 3,9 | **suspendu** | oui | — | si ≥ 90 % | oui | ×1 |
| Lames jumelles (15 s) | marche | 3,9 | **doublé** | **doublé** | oui | — (recharge) | Iaï doublé | **×0,55** |
| Iaï (0,25 s) | dash 3 u | 12 | oui | oui | oui | oui | — | invulnérable |

## 5. Ressource : jauge d'Aiguisage (HUD)
- `KitResource` : id `sharpness`, label « Aiguisage », ratio = aiguisage/100, texte « 73 % », **repère à 0,9** (seuil de l'ultime), `boost` (jauge qui pulse) pendant les Lames jumelles. Affichée par le `ResourceGauge` générique (PC : à gauche de la barre de sorts ; tactile : au-dessus de la grappe).
- Sauvegarde de run : `save_state()` = {sharpness, twin_left, twin_total}. Nouvel étage : **lame repassée à 100 %** (il aiguise entre deux étages).
- Lisibilité en jeu : chiffres de dégâts (proportionnels), éclat de lumière `morfil_edge` proportionnel à l'aiguisage à chaque coup ; à venir avec SA1 : lueur `_e` du tranchant modulée par la jauge.

## 6. Synergies (items et combos)
- **Recharge (`cooldown_mult`, Horloge arcanique)** : Aiguisage plus souvent = lame toujours haute ; l'ultime revient plus vite et sa durée suit (toujours la moitié de la recharge effective : 50 % du temps en double, quoi qu'il arrive). Son meilleur axe.
- **Vitesse d'attaque** : plus de coups = plus de dégâts mais plus d'usure (4 % par coup) : synergie à doser avec la recharge. Bon test de compréhension du kit.
- **Rune de portée** (`zone_size_add`) : cercle, estoc, Fauche-lune et dégainé plus larges : excellent.
- **Critiques, procs** : l'estoc (proc 1,0) et la Fauche-lune (1,0) portent bien Étincelle / Éclair en bouteille ; sous Lames jumelles chaque coup roule deux fois ses procs.
- **Danseur / dégâts en mouvement** : l'Iaï compte comme mouvement.
- **Items de défense** : la garde (−45 % après un coup) se cumule sous `MITIGATION_CAP`.
- **Combos** : Aiguisage → Lames jumelles → Fauche-lune ; Iaï à travers le paquet → coup circulaire au milieu ; Aiguisage juste avant un boss.

## 7. Statistiques de base (comparé à Ardent et Rictus)

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

### Équilibrage (simulateur `art/tools/night/balance_sim.py --chars morfil --seeds 2`, 22/10/2026)
Version 1 (circulaire 1,5 / estoc 2,6 / Fauche 5,0, coûts 3 / 12 %, Aiguisage 8 s, PV 105, armure 15, sans garde) : cible **+34 %** (L1) / **+54 %** (L6) / **+56 %** (L12), essaim −22 %, **dégâts subis ×2 à ×4,5**. Valeurs retenues : estoc 2,0, Fauche 4,0, dégainé 2,5, cercle 2,3 u, coûts 4 / 15 %, Aiguisage 10 s, PV 115 + 35, armure 25, garde −45 % / 0,6 s.

| Config | DPS zone | DPS mixte | DPS cible | Dégâts subis (% PV/min) | Morts | Aiguisage ≥ 50 % |
|---|---|---|---|---|---|---|
| L1 | −13 % | −6 % | −1 % | 74 (−18 %) | 0 | 76 % |
| L6 | −15 % | +0 % | −10 % | 42 (−4 %) | 0 | 84 % |
| L12 | +10 % | −12 % | +5 % | 43 (**+156 %**, Ardent 17) | 0 | 90 % |

Tous les dégâts sont dans ±20 % d'Ardent à tous les niveaux. Point ouvert : dégâts subis au niveau 12 (élite et mini-boss au contact : 82 et 96 % PV/min ; Ardent kite à 5,5 u), comme les autres mêléistes (Avare +108 %), sans mort (PV min 86 %). Leviers si le playtest le confirme : garde −55 %, Iaï qui laisse 0,5 s de garde.

## 8. Prise en main, forces, faiblesses
- **Difficulté 3/5** : un seul chiffre à surveiller, mais il faut aiguiser au bon moment (pas en plein paquet : l'auto s'arrête) et garder la lame au-dessus de 90 % quand l'ultime revient. Tips : « Ta lame s'use à chaque coup : aiguise avant le gros paquet », « Lames jumelles exige une lame au fil (90 %) », « L'Iaï tranche tout ce que tu traverses ».
- **Forces** : coups lourds et lisibles, excellent mono-cible lame haute, burst énorme sous Lames jumelles, mobilité offensive (Iaï), robuste au contact (écorce + garde).
- **Faiblesses** : dégâts qui fondent si on oublie d'aiguiser, lent (3,9), mêlée pure (les tireurs l'obligent à traverser), fenêtre d'ultime contrainte (≥ 90 %).

## 9. Entrées par plateforme
| Plateforme | Fauche-lune | Aiguisage | Lames jumelles | Iaï |
|---|---|---|---|---|
| PC | clic gauche (2), vise le curseur | clic droit (3) | molette (4), grisé sous 90 % | Maj / dodge, vers le déplacement sinon le curseur |
| Manette | spell_2, stick droit | spell_3 | spell_4 | dodge |
| Mobile | paquet le plus dense à 3,5 u | bouton | bouton grisé + texte « lame émoussée » | bouton roulade |

## 10. Aspect (chara design)
- **Silhouette (1,45 u, plus haut qu'Ardent mais plus étroit)** : **arbre humanoïde MAIGRE**. Tronc de cèdre fendu en deux jambes noueuses, taille creuse (on voit la pluie à travers une fente du tronc), épaules étroites et hautes, cou court enfoui sous le chapeau. Posture d'iaï : légèrement voûté, genou avant fléchi, poids sur l'arrière. **Bras droit = katana** : l'écorce remonte jusqu'au coude, puis le bois se resserre en une lame longue (≈ 1 u), courbe, d'un bois noir veiné, poli au tranchant, avec la tsuba d'origine (garde de fer rouillé) prise dans les nœuds du poignet. **Bras gauche** : branche fine et noueuse, doigts-rameaux, tient le fourreau (une branche creuse) contre la hanche.
- **Habit de samouraï, délavé et trempé** : hakama de toile indigo usée jusqu'à la trame, déchiré aux chevilles où sortent des racines ; kimono croisé sous un **dō** (plastron) de lamelles d'écorce laquées rouge sombre, écaillées ; deux **sode** (épaulières) en plaques d'écorce lacées de chanvre ; obi de corde de chanvre où pend la **pierre à eau** (pierre grise, plate, usée en creux) ; mousse et lichen dans les plis.
- **Le chapeau (inspiré du Solomonk de Dofus, sans le copier)** : le Solomonk est une coiffe de Dofus (équipement niveau 118-120, objet 7143) que l'encyclopédie présente comme le chapeau d'un vieux chef pandawa, un chapeau si creux qu'il servait aussi de pot ; c'est un chapeau-bol démesuré qui écrase la silhouette. Chez Taliant : **un très large chapeau de vannerie en bol renversé**, diamètre ≈ **2,2 fois la largeur des épaules** (≈ 1 u, il dépasse nettement la silhouette vue de dessus : c'est la première chose qu'on lit en iso), **calotte basse et ronde**, **bord large presque plat qui retombe un peu** sur les côtés et cache les yeux, **tressé en lanières d'écorce et de jonc** (trame visible en tons cel), bord effiloché d'où pend la pluie, **cordon de chanvre** noué sous le « menton », mousse sur le dessus. Équivalent japonais réel : entre le **sugegasa** très aplati et le **jingasa** (chapeau de fantassin en bol bas). Rien des couleurs, motifs ou proportions exactes de l'objet Dofus : seulement l'idée « chapeau-bol énorme qui mange la silhouette ». (Les pages de l'encyclopédie et des wikis étaient inaccessibles à la recherche : description tirée du texte officiel de l'objet ; Codex peut inventer librement dans cet esprit.)
- **Visage** : sous le bord, l'ombre ; deux fentes d'écorce en guise d'yeux où perle un point de sève (même accent, très discret).
- **Palette** : écorce gris-brun #3A3129, bois mort #5E5246, toile indigo délavée #343C4A, laque rouge sombre écaillée #5A2420, chanvre #8A7A5C, mousse #4F5A3A, fer rouillé #6B3A22. **Accent émissif unique : « fil de sève » #CDEB6E** (vert-jaune pâle, froid) : **uniquement le tranchant du katana** (une ligne fine le long de la lame) et les deux points de sève des yeux. Plus la lame est aiguisée, plus le fil brille (modulation de `_e` par l'aiguisage, prévue au branchement SA1). Distinct des accents du roster (braise d'Ardent #FF8C33, cuivre #FF7A1F, eau #5FD4E8, argent spectral #9FC8C0, vase #8DDBA8).
- **Rendu CEL validé** (art/briefs/STYLE_cel.md, profil `creature`) : 3 tons, encre brun-noir, ombres relevées (jamais un tronc presque noir sur le sol de nuit), lisible par la silhouette (chapeau + bras-lame).

## 11. Animations et VFX (lot Codex SA1)
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
