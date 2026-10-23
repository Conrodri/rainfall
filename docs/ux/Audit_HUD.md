# Audit UX/UI — HUD en combat (22/10/2026)

Consultant : ux-designer (fiche `.claude/agents/ux-designer.md`). Aucun code du jeu modifié.
Périmètre : PV et ressource du kit (régén /s), sorts et recharges, or / niveau / XP, minimap et difficulté, barres de boss,
de monstres et au-dessus du joueur, chiffres de dégâts, anneau de hitbox, halo des ressources à ramasser, bulles des sorts,
inventaire d'items, jauges de kit (Bourse d'Avare, Aiguisage de Taliant, Tension de Vigie, Eau d'Averse, Membres de Tocsin).
Hors périmètre (autres audits en parallèle) : menus, écrans de choix, entrées (joystick, remappage), réglages d'accessibilité.

---

## 0. Méthode et limites

**Code lu** : `game/scripts/ui/` (hud, spell_button, resource_gauge, overhead_bars, boss_bars, item_bar, spell_hint, minimap,
key_prompt, hp_bar_style), `game/scripts/fx/` (damage_numbers, enemy_health_bars, hitbox_ring, ground_marker,
averse_water_text, tocsin_layers), `scripts/spells/*_kit.gd` (couleurs de ressource), `scripts/spells/avare_purse_tip.gd`,
`scripts/ui/game_settings.gd`, `game/CONTRACTS.md`, `docs/GDD.md`.

**Captures en jeu** (scène temporaire `game/tests/_tmp_ux_hud_cap.*`, supprimée) : vraie scène `main.tscn`, boss d'étage
« L'Éclusier » + 8 monstres blessés (dont 1 élite), 10 items, 476 or, niveau 4, sorts 2 et 3 lancés ; 3 images par passage
(combat, bulle de sort, bulle d'item).

| Personnage | PC 1920×1080 KBM | Mobile 2400×1080 tactile (`--mobile`) |
|---|---|---|
| Avare | oui | oui |
| Tocsin | oui | oui |
| Taliant | oui | — |
| Vigie | — | oui |

Images (scratchpad de la session, non versionnées) : `…/scratchpad/uxhud/<perso>_pc2_*.png`, `<perso>_mob2_*.png`.

**Piège de mesure découvert (important pour tous les agents)** : le projet a `rendering/viewport/hdr_2d=true`.
`get_viewport().get_texture().get_image()` rend alors une image **RGBH linéaire** ; l'enregistrer telle quelle donne une
capture **2 à 3 fois trop sombre** (icônes, jauges et sol paraissent quasi noirs). Mes premières mesures donnaient des
contrastes de 1,1:1 qui étaient des artefacts. Correction : `img.convert(Image.FORMAT_RGBA8); img.linear_to_srgb()` avant
`save_png`. Les scènes existantes `tests/capture_*.gd` (ex. `capture_kit_hud.gd`) **n'ont pas cette conversion** : toute
décision de réglage prise sur leurs images (alpha d'anneau, luminosité d'icônes…) est à revérifier. Voir lot H0.

**Non évalué (capture à faire)** — arrêt des lancements Godot demandé par l'orchestrateur en cours d'audit :
- Averse (jauge Eau, « +N » d'eau flottants), Rainette, Bourbe, Arpenteuse : lus dans le code seulement.
- Mode manette (invites, focus), tablette 4:3, PC 21:9.
- PV bas (< 25 % et < 10 %, pulsation), mort, montée de niveau, coffre, bouton Interagir, minimap agrandie,
  panneau d'objectifs (absent des captures), horde de 250 monstres (plafond des barres et des chiffres), transitions de phase du boss.
- Daltonisme (simulations deutéranopie / protanopie) : non mesuré sur capture.
- Taille physique réelle sur téléphone : **estimée** (voir § 3.1), pas mesurée sur appareil.

---

## 1. Constat global

Le HUD est **complet et techniquement soigné** (pool de barres, plafonds, fondus, zones sûres, échelle `ui_scale`), mais il
s'est construit par couches : chaque ajout du jour a sa propre taille de texte, sa propre couleur et son propre cercle au sol.
Résultat visible sur capture :

1. **La hiérarchie est inversée** : le chrono (46 px) et l'or (40 px) sont les plus gros textes de l'écran, le libellé
   « Auto » sous le sort 1 (≈ 34 px) est plus gros que les PV (16 px). Or le joueur doit lire PV > recharges > ressource > reste.
2. **Le mobile utilise exactement les tailles du PC** (`ui_scale` = 1,0 aux deux formats) alors que l'écran physique est
   ≈ 4,7 fois plus petit : 16 px = 0,9 mm sur un 6,1 pouces.
3. **Des boutons de sort sans icône** (Taliant, Vigie) affichent le nom en texte, et le chiffre de recharge s'imprime
   **par-dessus** ce nom : illisible.
4. **Quatre sortes d'anneaux au sol** se ressemblent (hitbox joueur, repère de ramassage, élite bleue, zones de sorts).
5. **Plusieurs bulles peuvent s'empiler** (tutoriel de Bourse + bulle de sort), sans arbitre.
6. Les **textes de prix des coffres** (« 50 or », jaune 34 px) imitent le compteur d'or du HUD et passent par-dessus la grappe
   de sorts tactiles.

---

## 2. Tableau des problèmes

Gravité : S1 = empêche de jouer ou de comprendre une info vitale ; S2 = gêne forte / critère WCAG raté ; S3 = gêne modérée ;
S4 = finition. BLOQUANT = à corriger avant de nouveaux ajouts au HUD ; CONSEIL = amélioration.

| # | Constat (écran / fichier / capture) | Critère | Gravité | Statut | Recommandation |
|---|---|---|---|---|---|
| H1 | Mobile : toutes les tailles = PC (`hud.gd::_apply_layout`, `s = clamp(min(vp)/1080, 0.6, 1)` → 1,0 en 2400×1080). PV 16 px, régén 14 px, nom 20 px, libellés de jauge ≈ 16 px → 0,8 à 1,2 mm sur un 6,1 pouces (estimé). `tocsin_mob2_combat` | WCAG 1.4.4 (esprit), GAG « texte lisible » | S1 | BLOQUANT | Facteur `HUD_MOBILE_TEXT_K = 1,5` sur les textes et barres du HUD en mode mobile (§ 4.2) ; plancher 26 px à 1080 de haut sur mobile. |
| H2 | Taliant, Vigie : sorts sans icône → nom en texte dans le rond ; le chiffre de recharge (≈ 40 px) est dessiné par-dessus le nom (voile 0,5) : « 4.9 » sur « …auchoir », « 6.9 » sur « Fusée de détresse ». `morfil_pc2_combat`, `vigie_mob2_combat` (`spell_button.gd` l. 207-240) | Lisibilité, WCAG 1.4.3 | S1 | BLOQUANT | En recharge, **masquer la légende texte** (alpha 0) ; ne garder que le camembert + chiffre. Brief Codex des icônes manquantes (lot G). |
| H3 | Hiérarchie typographique inversée : chrono 46 px, or 40 px, « Auto » 34 px (invite) > PV 16 px, XP 8 px de haut. `avare_pc2_combat` | Hiérarchie visuelle (fiche § Cadres) | S2 | BLOQUANT | Échelle à 5 niveaux (§ 4.1) : PV 22 px / barre 28 px, chrono 34 px, or 30 px, invites 22 px. |
| H4 | Doublon « AUTO » (dans le rond, `spell_button.gd` l. 251) + invite « Auto » (KeyPrompt sous le sort 1). Le sort 1 ne se déclenche par aucune touche : l'invite n'a pas lieu d'être. | Hick, bruit | S3 | BLOQUANT | Supprimer l'invite sous le sort 1 (colonne vide de même hauteur pour l'alignement) ; garder l'étiquette « AUTO » 16 px dans le rond. |
| H5 | Bulles empilées : le tutoriel « La bourse d'Avare » (`avare_purse_tip.gd`, 11 s, 560 px) recouvre la bulle de sort « Rançon » dont la ligne « Recharge 10 s » est masquée. `avare_pc2_tip` | Lisibilité, divulgation progressive | S2 | BLOQUANT | Arbitre unique de bulles (§ 4.6) : une seule bulle à la fois, priorité bulle demandée (survol / appui long) > tutoriel ; le tutoriel se met en pause pendant ce temps. |
| H6 | Prix des coffres dans le monde « 50 or » (jaune #FFDF4F, ≈ 34 px, `loot/chest.gd` l. 118) : même style que le compteur d'or du HUD ; passe au-dessus de la grappe tactile (`*_mob2_combat`, x ≈ 2100, y ≈ 670) et en bord d'écran PC (coupé à x = 1920). | Modèle mental, GAG « UI ne recouvre pas les contrôles » | S2 | BLOQUANT | Étiquette monde plus petite (22 px billboard), blanc cassé + icône pièce 20 px, alpha 0,85, masquée si son rectangle écran croise une zone HUD réservée (§ 3.2) ou à plus de 6 u du joueur. |
| H7 | Quatre anneaux au sol de forme voisine : hitbox joueur (blanc bleuté alpha 0,2), repère de ramassage (`ground_marker.gd`, halo chaud + cercle fin), élite (ellipse bleue pleine), zones de sorts (ex. ellipse jaune-vert de Taliant, cercle rouge de Vigie). `tocsin_mob2_combat`, `morfil_pc2_combat` | Hiérarchie menace > joueur > butin ; GAG « ne pas reposer sur la couleur seule » | S2 | CONSEIL | Grammaire des formes (§ 4.5) : hitbox = anneau fin continu + 4 crans ; butin = losange pointillé pulsant, jamais un cercle ; élite = couronne au-dessus de la barre, pas d'ellipse au sol ; zones alliées = bord pointillé ; télégraphes ennemis = seuls à avoir rouge plein + remplissage progressif. |
| H8 | PV joueur : barre HUD **rouge** (`hud.gd` `Color(0.85,0.2,0.25)`) mais barre au-dessus de la tête **verte** (`overhead_bars.gd` `COL_HP #52C45A`). Même information, deux couleurs ; et le rouge HUD = rouge des monstres. | Cohérence (même info = même signe) | S2 | BLOQUANT | Vert #52C45A partout pour les PV du joueur, rouge #D9483A sous 25 % (règle déjà dans OverheadBars) ; le rouge reste aux ennemis. |
| H9 | Ressource au-dessus de la tête collée aux PV (2 px) et teintée de l'accent du kit : Taliant #CDEB6E (vert-jaune) sous des PV verts ; Vigie #FF3A4F (rouge) proche des PV bas ; Bourbe #8DDBA8 (vert). `morfil_pc2_combat` | WCAG 1.4.1 (couleur seule) | S2 | CONSEIL | Distinguer par la **forme** : ressource 4 px, segmentée tous les 10 % (encoches 1 px sombres), écart 3 px ; PV 10 px pleins avec liseré clair. Pas de changement des accents (DA). |
| H10 | Icônes de sorts, de l'or et de pause sombres : textures moyennes ≈ 50/255 (icônes de sorts 128 px, `icon_gold.png` 64 px), `icon_pause.png` ≈ 32/255. Contraste mesuré icône/fond du rond : 2,7:1 (Avare sort 4), or 1,5:1, pause 2,0:1. | WCAG 1.4.11 (≥ 3:1) | S2 | BLOQUANT | Brief Codex (lot G) : liseré clair 2 px (#E8E2D6, alpha 0,9) + rim-light haut-gauche ; ou en attendant, sous-couche disque clair alpha 0,18 dans le rond. Cible ≥ 3:1 mesuré sur capture sRGB. |
| H11 | Jauge des Membres (Tocsin) : pastilles pleines orange sombre vs cases vides : 2,25:1 ; pastilles 26 px. | WCAG 1.4.11 | S3 | CONSEIL | Pastille pleine = accent ×1,3 + liseré clair 2 px ; vide = contour seul pointillé ; ≥ 3:1 entre les deux états. |
| H12 | Jauges continues (Bourse, Aiguisage, Tension) : remplissage texturé, contraste remplissage/fond ≈ 2,5-3:1 ; l'état « plein » ne se distingue que par le texte (« +70 % dégâts », « PRÊTE »). | WCAG 1.4.11 | S3 | CONSEIL | Fond de jauge plus sombre (#0B0907 alpha 0,9), remplissage ≥ 3:1 ; état plein = cadre qui pulse (1 Hz, alpha 0,35→0,7) + texte : deux canaux. |
| H13 | Régénération « +1,3/s » : 14 px vert pâle dans la barre rouge ; contraste 4,7:1 correct mais **taille < 18 px** et rouge/vert (paire daltonienne). | WCAG 1.4.3 / 1.4.1 | S3 | CONSEIL | 18 px PC / 26 px mobile, blanc cassé #E8E2D6, préfixe « + » et « /s » gardés ; hors de la barre (à droite, sur la plaque) si la barre fait < 28 px de haut. |
| H14 | Barre d'XP 8 px de haut, sans chiffre ; le niveau est dans un médaillon de 62 px à gauche, loin de la barre. | Lisibilité | S4 | CONSEIL | 10 px, liseré 1 px ; au survol / appui long de la plaque : « Niveau 4 — 40 / 120 XP ». |
| H15 | Bandeau du boss : plaque noire alpha 0,55 de ≈ 560 × 130 px qui recouvre le haut du boss lui-même (capture : le boss est sous sa propre barre). | Hiérarchie menace d'abord | S3 | CONSEIL | Plaque alpha 0,35, hauteur 84 px (nom 26 px + barre 22 px + marges), posée à 12 px sous le chrono ; si le boss est dans le tiers haut de l'écran, la plaque passe en alpha 0,2. |
| H16 | Chiffres de dégâts : normaux 19 px beige #CCBDA3 alpha 0,88 (≈ 4:1 sur sol), critiques 27 px rouge-orange + icône. Hiérarchie correcte, mais les normaux se perdent sur les zones de sorts claires (Taliant) et chevauchent la barre au-dessus du joueur. | Retour < 0,5 s | S4 | CONSEIL | Garder ; contour 3 → 4 px pour les normaux ; zone d'exclusion de 48 px autour du bloc OverheadBars. Réglage `damage_text_scale` existe déjà : OK. |
| H17 | Libellé de difficulté « Calme » 22 px vert sur fond de jeu, barre fine 340 × 10 px sous la minimap ; info portée aussi par le texte : OK (1.4.1). Mais pas de plaque : le texte flotte sur le décor (contraste mesuré 6,7:1 sur sol sombre, non garanti sur sol clair). | WCAG 1.4.3 | S4 | CONSEIL | Plaque `panel_small_9slice` alpha 0,5 commune minimap + difficulté. |
| H18 | Bouton Roulade sans icône : texte « Roulade » 14 px dans un rond de 88 px (PC) ; 36 px en tactile. | Affordance | S3 | CONSEIL | Brief icône Roulade (lot G) ; en attendant, texte 18 px PC. |
| H19 | Inventaire mobile : une rangée défilante de 4 cases visibles, la 5e coupée à mi-case sans indice de défilement. `tocsin_mob2_combat` | Affordance | S3 | CONSEIL | Dernière case visible = « +6 » (compteur des items cachés) ; appui = menu pause onglet Items. |
| H20 | Contours blancs de grands losanges au sol traversant la barre de sorts (bas d'écran, toutes captures). Probablement un élément de carte (plaques / zones) : à identifier. | Bruit sous le HUD | S4 | CONSEIL | NON ÉVALUÉ (origine) : si c'est un repère de gameplay, alpha ≤ 0,4 quand il est sous une zone HUD réservée. |
| H21 | Outillage : captures `tests/capture_*.gd` enregistrées en linéaire (HDR 2D) → images trop sombres. | Fiabilité des décisions | S2 | BLOQUANT | Lot H0 : conversion sRGB dans toutes les scènes de capture. |

---

## 3. Hiérarchie visuelle cible

### 3.1 Contexte physique (estimé)

| Écran | Hauteur physique de 1080 px | mm / px | 18 px de texte | 128 px de bouton |
|---|---|---|---|---|
| Moniteur 24" 16:9 | 299 mm | 0,277 | 5,0 mm | 35 mm |
| Téléphone 6,1" 20:9 (2400×1080) | 64 mm | 0,059 | 1,1 mm | 7,5 mm |
| Téléphone 6,7" 20:9 | 70 mm | 0,065 | 1,2 mm | 8,3 mm |

Conséquences : sur téléphone, il faut ≈ 26-28 px de texte à 1080 de haut pour retrouver ≈ 1,6 mm (lisible à 30 cm) ;
une cible de 9 mm = **153 px** sur 6,1" (la fiche indique 120 px pour 6" 16:9, trop juste en 20:9).

### 3.2 Zones (positions relatives, ratio libre, base 1080 de haut)

```
┌───────────────────────────────────────────────────────────────────────┐
│ Z1 JOUEUR (haut-gauche)        Z2 TEMPS + BOSS (haut-centre)  Z3 CARTE │
│ portrait·niveau·PV·XP·régén    chrono · barre(s) de boss      or·pause │
│ Z1b items (sous Z1)                                           minimap  │
│                                                               difficulté│
│                                                               objectifs│
│                       Z0 MONDE (centre ±35 % largeur, ±30 % hauteur)    │
│                     joueur · overhead · télégraphes · dégâts            │
│                                                                         │
│ Z5 (tactile) joystick flottant         Z4 ACTION (PC : bas-centre ;     │
│ moitié gauche, rien d'autre            tactile : grappe bas-droite)     │
│                                        jauge de kit + sorts + roulade   │
└───────────────────────────────────────────────────────────────────────┘
```

| Zone | Ancre | Étendue max (à 1080) | Priorité | Règle |
|---|---|---|---|---|
| Z0 Monde | centre | rien de HUD dans 0,35 L × 0,30 H autour du joueur | 1 menace / 2 joueur | Seuls overhead, chiffres, anneaux. |
| Z1 Joueur | haut-gauche + zone sûre | 520 × 130 px (PC), 600 × 150 px (mobile) | 2 | PV = élément le plus contrasté du HUD. |
| Z1b Items | sous Z1 | 3 lignes de 56 px (PC) ; 1 rangée de 64→84 px (mobile) | 5 | Jamais au-dessus de 0,35 H. |
| Z2 Temps + boss | haut-centre | 600 × 200 px | 3 (boss = 1 quand présent) | Chrono plus petit que les PV ; boss sous le chrono. |
| Z3 Carte | haut-droite + zone sûre | 400 × 520 px (PC) ; 300 × 420 (mobile) | 4 | Or, pause, minimap, difficulté, objectifs : une seule colonne alignée à droite. |
| Z4 Action | PC : bas-centre ; tactile : bas-droite | PC 900 × 190 px ; tactile 640 × 560 px | 2 | Recharges lisibles en vision périphérique. Zone **réservée** : aucun texte du monde ne s'y dessine. |
| Z5 Joystick | bas-gauche (tactile) | 0,48 L × 0,5 H | — | Vide de HUD. |

Ordre de priorité de lecture (contraste et taille décroissants) : **télégraphe ennemi > PV joueur > recharges / ressource du kit
> barre de boss > chiffres critiques > or / niveau > minimap / difficulté > items > chrono**.

---

## 4. Recommandations chiffrées

Toutes les valeurs sont à 1080 px de haut, multipliées par `ui_scale` ; « mobile » = `Platform.is_mobile()`. Les constantes
vont dans `Balance` (section `HUD_*`) ou dans une ressource `HudMetrics` unique — pas de nombres magiques dispersés.

### 4.1 Échelle typographique (5 niveaux)

| Niveau | Usage | PC | Mobile (×1,5, plancher 26) | Contour |
|---|---|---|---|---|
| T1 | PV « 228 / 228 », chiffre de recharge | 22 px (recharge 40) | 32 px (recharge 52) | 4 px noir 0,9 |
| T2 | Chrono, or, nom du boss | 34 / 30 / 26 px | 40 / 38 / 34 px | 4 px |
| T3 | Libellé de jauge, valeur (« +70 % dégâts », « 96 % ») | 18 px | 28 px | 3 px |
| T4 | Nom du perso, régén, « AUTO », difficulté | 18 px | 26 px | 3 px |
| T5 | Badges ×3, invites de touches | 18 px | 26 px | 2 px |

Aucun texte du HUD sous 18 px (PC) / 26 px (mobile). Contraste texte ≥ 4,5:1 sur sa plaque (pas sur le décor).

### 4.2 Dimensions

| Élément | PC | Mobile | Notes |
|---|---|---|---|
| Barre de PV | 300 × 28 px | 360 × 36 px | vert #52C45A, < 25 % #D9483A + pulsation existante |
| Barre d'XP | 300 × 10 px | 360 × 12 px | cyan #59CCFF |
| Médaillon niveau / portrait | 62 / 72 px | 80 / 92 px | |
| Boutons de sort | 110 px (barre) | 150 px ; roulade 184 px | ≥ 9 mm (153 px sur 6,1") pour la roulade et l'ultime ; espacement ≥ 16 px |
| Indicateur sort 1 (non cliquable) | 110 px | 72 px | |
| Jauge de kit | 250 × 76 px | 330 × 96 px | à gauche des sorts (PC), au-dessus du sort 2 (tactile) |
| Minimap | 380 px | 300 px (au lieu de 274) | plaque commune avec la difficulté |
| Overhead | 72-120 × 10 px PV + 4 px ressource, écart 3 px | idem × 1,25 | |
| Barres monstres | 6 px base, 8 élite, 10 mini | idem × 1,25 | |

### 4.3 Alpha et plaques

| Élément | Alpha |
|---|---|
| Plaques HUD (`panel_small_9slice`) | 0,55 fond, liseré 0,85 |
| Plaque boss | 0,35 (0,20 si le boss est dans le tiers haut) |
| Voile de recharge (camembert) | 0,55 (inchangé) ; icône ×0,55 ; légende texte **0** |
| Anneau hitbox repos / coup | 0,20 / 0,80 (inchangé, à revalider sur capture sRGB) |
| Repère de ramassage | lueur 0,25, contour 0,6 |
| Étiquettes monde (prix) | 0,85 ; 0 dans une zone HUD réservée |
| Tutoriel de kit | 0,92, mis en pause si une autre bulle s'ouvre |

### 4.4 Contrastes cibles (à mesurer sur capture **sRGB**)

| Paire | Actuel (mesuré) | Cible |
|---|---|---|
| Texte PV / barre | 6,3:1 | ≥ 4,5:1 |
| Icône de sort / fond du rond | 2,7:1 | ≥ 3:1 |
| Icône or / plaque | 1,5:1 | ≥ 3:1 |
| Icône pause / fond | 2,0:1 | ≥ 3:1 |
| Remplissage jauge / fond (Bourse, Aiguisage) | 3,0 / 2,5:1 | ≥ 3:1 |
| Pastille pleine / vide (Membres) | 2,25:1 | ≥ 3:1 |
| Chiffre de dégât normal / sol | ≈ 4:1 | ≥ 3:1 (OK) |
| Libellé difficulté / décor | 6,7:1 (sol sombre) | ≥ 4,5:1 garanti par plaque |

### 4.5 Grammaire des formes au sol (H7)

| Sens | Forme | Couleur | Mouvement |
|---|---|---|---|
| Hitbox du joueur | anneau continu fin (2 px) + 4 crans cardinaux | blanc bleuté | fixe ; éclat directionnel au coup |
| Butin / membres / pièces | losange pointillé (8 tirets) + petite lueur | chaud #F2C14E | pulsation 0,8 Hz (déjà dans le shader) |
| Élite | couronne / chevron au-dessus de la barre de PV, **pas d'ellipse** | cadre fer clair | fixe |
| Zone alliée (sort) | bord pointillé, remplissage ≤ 0,12 | accent du kit | fondu |
| Télégraphe ennemi | bord plein épais + remplissage progressif | rouge/orange | ≥ 0,8 s, seule forme « pleine » |

### 4.6 Arbitre des bulles (H5)

Une seule bulle ouverte à la fois dans tout le HUD (`SpellHint`, infobulle d'item, tutoriel de kit) :
priorité 1 = bulle demandée par le joueur (survol, appui long) ; 2 = tutoriel ; ouverture d'une bulle de priorité 1 → le
tutoriel se masque (fondu 0,15 s) et son minuteur s'arrête, puis reprend. Bulles hors Z0 et hors Z4 tactile.
Délai d'ouverture au survol : 0,25 s ; appui long tactile : 0,4 s (existant).

### 4.7 Options étudiées pour la hiérarchie (H1/H3)

1. **(Recommandé) Échelle à 5 niveaux + facteur mobile 1,5** : un seul tableau de tailles, tout le HUD suit. Avantage :
   cohérence, conforme Fitts et WCAG ; inconvénient : la colonne Z3 mobile grandit (vérifier qu'elle reste hors de la grappe,
   ce qui est le cas en 20:9 : 2400 px de large).
2. Facteur mobile 1,3 seulement : moins d'encombrement, mais textes T4 à 23 px (≈ 1,4 mm) : limite.
3. Réglage « Taille du HUD » 80-150 % dans les options (audit accessibilité) : complémentaire de 1, pas un remplaçant
   (défaut mobile = 150 %).

---

## 5. Plan d'implémentation (lots indépendants)

Chaque lot ne touche que ses fichiers. `hud.gd` est partagé : seul le lot B le modifie franchement ; les autres n'y font
aucun changement. Contrat commun : `docs/ux/_dev_contract.md`. **Toute capture : conversion sRGB (lot H0).**

| Lot | Contenu (problèmes) | Fichiers | Dépend de | Test / vérif |
|---|---|---|---|---|
| **H0 — Captures fiables** (à faire en premier, 15 min) | Conversion linéaire → sRGB dans toutes les scènes de capture ; helper `CaptureUtil.save_viewport_png(vp, path)` (H21) | `game/tests/capture_*.gd`, nouveau `game/tests/capture_util.gd` | — | une capture avant/après |
| **A — Boutons de sorts** | Légende masquée en recharge (H2) ; « AUTO » 18 px ; pas d'invite sous le sort 1 (H4 : `KeyPrompt` vide) ; Roulade 18 px (H18) ; sous-couche claire alpha 0,18 derrière les icônes sombres (H10, provisoire) | `scripts/ui/spell_button.gd`, `scripts/ui/dodge_button.gd`, `scripts/ui/key_prompt.gd` | H0 | `spell_tooltip_test`, `hud_layout_wave3_test` + nouveau `spell_button_caption_test` |
| **B — Échelle et hiérarchie du HUD** | Tableau T1-T5 + facteur mobile (H1, H3) ; PV verts unifiés (H8) ; XP 10 px (H14) ; régén 18/26 px blanc cassé (H13) ; plaque commune minimap + difficulté (H17) ; dimensions § 4.2 (boutons tactiles 150/184) | `scripts/ui/hud.gd`, `scripts/core/balance.gd` (constantes `HUD_*`, ajout minime) | H0 | `hud_overlays_test`, `hud_layout_wave3_test`, `platform_layout_test` ; captures PC + mobile |
| **C — Jauges de kit et overhead** | Ressource overhead 4 px segmentée, écart 3 px (H9) ; contrastes jauges continues et pastilles (H11, H12) ; état plein pulsé ; tailles mobile de la jauge (330 × 96) | `scripts/ui/resource_gauge.gd`, `scripts/ui/overhead_bars.gd`, `scripts/fx/rainette_breath_pips.gd`, `scripts/fx/averse_water_text.gd` (taille 22 → 26 px mobile) | H0 | `hp_bars_test` + test jauge ; captures Avare, Tocsin, Taliant, Vigie, **Averse** |
| **D — Lisibilité du monde** | Grammaire des formes (H7) : losange pointillé du butin, couronne d'élite au lieu de l'ellipse ; chiffres : contour 4 px, exclusion autour de l'overhead (H16) ; étiquettes de prix (H6) | `scripts/fx/ground_marker.gd`, `scripts/fx/hitbox_ring.gd`, `scripts/fx/damage_numbers.gd`, `scripts/fx/enemy_health_bars.gd`, `scripts/loot/chest.gd` (étiquette seule) | H0 ; zones réservées exposées par B (`Hud.reserved_rects()`, contrat à ajouter) — sinon test de rectangle local en attendant | `hitbox_test`, `hp_bars_test` ; capture horde |
| **E — Arbitre des bulles** | Une bulle à la fois, pause du tutoriel (H5) ; inventaire mobile « +N » (H19) | `scripts/ui/spell_hint.gd`, `scripts/ui/item_bar.gd`, `scripts/spells/avare_purse_tip.gd`, `scripts/menu/spell_tooltip.gd` | — | `spell_tooltip_test`, `hud_overlays_test` + test « deux bulles » |
| **F — Barre de boss** | Plaque 0,35 / 0,20, hauteur 84 px, placement sous le chrono (H15) | `scripts/ui/boss_bars.gd`, `scripts/ui/boss_health_bar.gd` | H0 (le placement final vient de B : `_place_boss_bars` reste dans hud.gd, ne pas y toucher) | `hp_bars_test` ; capture boss en haut d'écran |
| **G — Briefs Codex (assets)** | Icônes manquantes Taliant (4) et Vigie (4), icône Roulade, liseré clair 2 px + rim-light sur toutes les icônes de sorts, `icon_gold` et `icon_pause` éclaircis (≥ 3:1 sur #14110C) ; 128 px, états normal / recharge (voile fait en code) / désactivé ; cel-shadé, sans normal map, `_e` à demi-résolution | `art/tools/night/_uxhud_icons.txt` + groupe en fin de `queue.txt` (ne pas lancer Codex) | — | relecture des rendus sur capture sRGB |

Ordre conseillé : H0 → (A, B, C, D, E, F, G en parallèle) → passe de captures commune (3 persos × 2 formats + Averse + horde
+ PV bas) pour lever les « NON ÉVALUÉ ».

**Besoins de contrat (pour l'orchestrateur, CONTRACTS.md)** :
- `Hud.reserved_rects() -> Array[Rect2]` (zones Z1-Z4 en coordonnées écran) pour que le monde (étiquettes, chiffres)
  évite le HUD.
- `HudMetrics` / `Balance.HUD_*` : table T1-T5 et facteur mobile, lue par tous les éléments du HUD.
- `CaptureUtil` (tests) : seule voie d'enregistrement d'image.

---

## 6. Risques

- **Encombrement mobile** (lot B) : +50 % de texte en Z1/Z3. En 20:9 la place existe ; en **4:3 (tablette)** la colonne Z3 peut
  descendre vers la grappe : NON ÉVALUÉ, à capturer en 2048×1536.
- **Accessibilité** : tant que H1 n'est pas corrigé, le jeu mobile ne passe pas l'esprit de WCAG 1.4.4 (S1).
- **Performance** : les losanges pointillés et couronnes d'élite doivent rester dans les lots groupés existants (même matériau,
  même z), sans `_process` par objet ; barres et chiffres restent plafonnés (64 barres riches, pool de 64 chiffres).
- **DA** : aucun accent de kit n'est changé ; la distinction PV / ressource passe par la forme.
- **À trancher par le joueur** : PV du joueur en vert partout (recommandé, cohérent avec l'overhead) ou rouge partout.

---

## 7. Sources

Normes et guides (références de la fiche de rôle ; pas de recherche web pendant cet audit) :
- WCAG 2.1 — 1.4.3 Contraste minimum : https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html
- WCAG 2.1 — 1.4.11 Contraste du non-textuel : https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html
- WCAG 2.1 — 1.4.1 Utilisation de la couleur : https://www.w3.org/WAI/WCAG21/Understanding/use-of-color.html
- WCAG 2.1 — 1.4.4 Redimensionnement du texte : https://www.w3.org/WAI/WCAG21/Understanding/resize-text.html
- WCAG 2.1 — 2.3.1 Pas plus de trois flashs : https://www.w3.org/WAI/WCAG21/Understanding/three-flashes-or-below-threshold.html
- Game Accessibility Guidelines : https://gameaccessibilityguidelines.com/
- Godot 4 — `Viewport.use_hdr_2d` (texture en espace linéaire) : https://docs.godotengine.org/en/stable/classes/class_viewport.html
- Formule de luminance relative et ratio de contraste : WCAG 2.1, définitions « relative luminance » / « contrast ratio ».

Projet : `docs/HP_Bars_Recherche.md`, `docs/GDD.md` (§ 2 « Difficulté progressive visible », § 8 Game feel),
`game/CONTRACTS.md` (HitboxRing, ressource de kit, SpellHint, BossBars, EnemyHealthBars), `docs/ux/_dev_contract.md`.

Mesures : contrastes calculés sur captures converties en sRGB (luminance relative WCAG, percentiles 5 % / 50 % / 95 % de la
zone) ; tailles physiques **estimées** à partir de la diagonale et du ratio des écrans.
