# Rainfall - Visuels d'état sur les monstres

Demande du joueur (08/11/2026) : « des effets de brûlure, de poison, de debuff mouillé pour Averse, qui se voient en
VFX sur les mobs : bulles rondes vertes pour le poison, feu / cendres pour les brûlures, gouttes qui tombent et
vêtements plus sombres pour les mouillés, arcs électriques pour ceux qui viennent de prendre un coup électrique ».

Code : `game/scripts/enemies/status_fx.gd` (`StatusFx`). Textures : `game/assets/sprites/vfx/status/` (lot Codex,
brief `art/briefs/status_fx.md`), replis existants en attendant. Test : `game/tests/status_fx_test.tscn`.

## 1. Inventaire des états (08/11/2026)

| État | Où il vit | Qui l'applique | Durée | Visuel avant ce lot | Visuel d'état (ce lot) |
|---|---|---|---|---|---|
| Brûlure `burn` | `Enemy._burn_*` (cumuls, `is_burning`) | Étincelle (10 %), Cristal de feu (10 %), Nova infinie, Mèche-silex (Forge), Phénix d'Ardent | 3 s (Phénix 2 s), cumuls indépendants | son `status.burn`, une flammèche `HitFx.dot` par tick (0,5 s), pictogramme sur la barre de PV | flammèches pointues sur le corps + braises qui montent + paillettes de cendre qui tournoient |
| Poison `poison` | `Enemy._poison_*` (`is_poisoned`) | Fiole verte (5 %), Venin concentré (10 %), Nova infinie, Peste vivante, Sève rampante (Forge) | 4 s, cumuls | son, une bulle `HitFx.dot` par tick, pictogramme | bulles rondes vertes qui montent du corps et éclatent |
| Trempé (Averse) | `AverseKit._soaked_until` (kit) + ralentissement `slow` | Vague, Flaque-miroir, Geyser, Gouttière, Crue / Mousson, sillage de la Glissade | 4 s (Vague de fond et déversement de la Gouttière 8 s, sillage 2 s) | marque au-dessus de la tête (`MarkIndicator`, accent d'Averse), pictogramme « gel » du ralentissement | gouttes qui tombent du corps jusqu'au sol + corps assombri et bleuté (« vêtements mouillés ») |
| Électrique, coup | coup `take_damage(…, &"lightning")` | Éclair en bouteille (foudre en chaîne, 25 %) | instantané | arcs entre les cibles (`ChainLightningFx`), étincelles en zigzag à l'impact | arcs brefs sur le corps pendant 0,45 s |
| Électrisé (Tocsin) | étiquette `tocsin_charge` (`add_damage_taken_mod`) | ticks du Bras-pilier en décharge | 0,6 s, rafraîchie toutes les 0,5 s | marque `MarkIndicator` (accent de Tocsin) | arcs sur le corps tant qu'il est électrisé |
| Étourdi `stun()` | `Enemy._stop_left` (gel) | Rançon d'Avare, saut / ricochet / écrasement de Rainette ; les boss l'ignorent | 0,3 à 1,0 s | animation figée, pictogramme si > 0,1 s | 3 étoiles qui tournent au-dessus de la tête |
| Ralenti `slow` (gel) | `Enemy._slow_*` | Flocon, Givre, Prisme de grêle, Nova infinie, et une dizaine de sorts (boue de Bourbe, vapeur de Tocsin, chausse-trapes et grêle de Vigie, chaîne d'Arpenteuse, glu de Rainette…) | 0,6 à 8 s | son `status.frost`, pictogramme « gel » | **inchangé** : la source n'est pas connue du monstre (de la glace sur un monstre ralenti par la boue serait faux) ; la trempe d'Averse a son visuel propre |
| Emprisonné `imprisoned` | `Enemy._held_*` | pince et fumigène de Tocsin, Tendeur et Nœud d'Arpenteuse, Geyser d'Averse, bulle de Rainette, filet et signal de Vigie | 0,8 à 3 s | visuel propre à chaque kit (chaîne, bulle, filet), pictogramme | **inchangé** (déjà lisible) |
| Marques de kit | dictionnaires des kits (`is_marked`) | braise d'Ardent (1,5 s), rançon d'Avare (4 s), cloué / exposé de Vigie, électrisé de Tocsin, trempé d'Averse | selon le kit | `MarkIndicator` au-dessus de la tête, teinté de l'accent du kit | **inchangé** |

## 2. Système

- **Piloté par l'état réel, sans effet de jeu.** `Enemy.apply_status` (brûlure, poison), `Enemy.stun` et
  `Enemy.take_damage` (élément `&"lightning"`) appellent `StatusFx.track / stun / shock` ; `AverseKit._soak` appelle
  `StatusFx.wet(e, durée)` (même règle : une trempe courte n'écourte pas une trempe en cours) ; le pilier de Tocsin
  appelle `StatusFx.shock(e, 0,6 s)`. La fin de la brûlure et du poison est lue dans `Enemy.status_mask()`.
- **Aucun coût sans état** : un monstre n'est suivi que lorsqu'un état visible le touche ; il est relâché à la fin de
  ses états, à sa mort et à son retour au pool. Sans monstre suivi ni particule vivante, `_process` est éteint.
- **Relecture toutes les 0,1 s** (anticipée à 50 ms quand un nouvel état arrive) : fin des états, teinte mouillée,
  choix des émetteurs. Entre deux relectures, seuls les émetteurs et les particules vivantes sont traités.
- **Niveau de détail** : un monstre hors de l'écran (marge 96 px) n'émet rien. Par état, au plus N émetteurs : boss
  d'abord, puis les monstres proches du centre de l'écran, puis les autres à l'écran.
- **Pool fixe** : 464 particules CPU (tableaux packés alloués au `_ready`), rendues par une `MultiMeshInstance2D` par
  sorte et variante de texture (au plus 7 × 4 lots, masqués quand vides). Aucun nœud créé en jeu, aucune allocation
  par image. Les particules héritent la vitesse du monstre à leur apparition : elles restent sur le corps le temps de
  leur vie sans lecture de position par particule.
- **Taille** : hauteur du corps = rayon de collision × 2,0 (essaim), 3,0 (tireur), 2,6 (brute), 2,3 (boss et
  mini-boss) ; les boss émettent deux fois plus et des particules plus grosses (jusqu'à × 1,7). Les élites suivent leur tier.

### Plafonds par palier de qualité

| Palier | Émetteurs par état | Débit | Particules (par sorte, Haut : bulles 96, flammèches 96, braises 32, cendres 48, gouttes 80, arcs 64, étoiles 48) |
|---|---|---|---|
| Bas | 3 | × 0,45 | × 0,15 ; braises et cendres coupées (la flammèche suffit) ; la teinte mouillée reste |
| Moyen | 8 | × 0,75 | × 0,45 |
| Haut | 16 | × 1 | × 1 |

### Teinte « mouillé »
`EnemyVisual.set_wet(on)` : `self_modulate` du corps × (0,60 ; 0,66 ; 0,78) — plus sombre, un peu bleuté, jamais
noir. Composée avec ce qui est déjà posé (gain des invocations, `BODY_GAIN` des cerveaux de boss) : la valeur d'origine
est rendue à la fin si personne ne l'a réécrite entre-temps. L'émission (enfant du sprite, `modulate` hérité) n'est pas
touchée. Pendant un flash de coup la teinte est levée (sinon `FLASH_MOD × teinte` repasserait sous le seuil 1,5 du
drapeau de `sprite_flash.gdshader`), puis remise. Un cadavre laissé par un monstre trempé garde la teinte.

### Accessibilité
- **Daltonisme** : les états se distinguent par la forme et le mouvement, pas seulement la couleur — bulles rondes qui
  montent, flammèches pointues + paillettes qui tournoient, gouttes qui tombent, zigzags qui scintillent, étoiles qui
  tournent au-dessus de la tête.
- **Réduction des mouvements** (`GameSettings.reduce_motion`) : débit divisé par deux, arcs tenus 0,2-0,3 s sans
  scintillement, étoiles quasi immobiles, cendres qui tournent moins.
- **Flashs** (`Quality.flashes_level`) : à 1 les arcs sont atténués (× 0,75), à 0 (× 0,5) et sans HDR.

## 3. Perf mesurée (08/11/2026, `status_fx_test`, PC de dev, headless, `--fixed-fps 60`)
Banc : 250 monstres tous empoisonnés, en feu, trempés et électrisés, palier Haut.

| Mesure | Sans visuels d'état | Avec |
|---|---|---|
| Image médiane (mur), 2 passages | 0,53-0,55 ms | 0,69-0,77 ms |
| Coût de StatusFx par image | - | médiane 0,16-0,17 ms, p90 0,36-0,39 ms (images de relecture) |
| Particules vivantes au plus | - | Haut ~275, Moyen ~105, Bas 20 |
| Émetteurs par état | - | Haut 16, Moyen 8, Bas 3 (plafonds tenus) |

Headless : le rendu des MultiMesh (un lot par sorte et variante) n'est pas compté ; il reste borné à 28 lots au plus.
Mobile bas de gamme ≈ × 5-8 sur le coût CPU : ~1 ms en Haut, bien moins en Bas (3 émetteurs, 20 particules).

## 4. Vérifier en mode test
- Poison : objet Fiole verte ou Venin concentré (mode test, onglet objets, plusieurs exemplaires) puis taper un groupe
  ou le Poutch : bulles vertes rondes qui montent du corps, disparaissent 4 s après le dernier coup.
- Brûlure : Étincelle ou Cristal de feu, ou le Phénix d'Ardent : flammèches sur le corps, braises et cendres qui
  s'envolent (Moyen et Haut), fin 3 s après.
- Trempé : Averse, Vague (sort 2) ou Flaque-miroir (sort 3) : gouttes qui tombent jusqu'au sol, corps nettement plus
  sombre ; fin au bout de 4 s (8 s pour la Vague de fond). Frapper un trempé : le flash blanc reste blanc.
- Électrique : Éclair en bouteille (chaque proc), ou le Bras-pilier de Tocsin : arcs brefs sur les corps touchés.
- Étourdi : Rainette (saut écrasant) ou la Rançon d'Avare : étoiles qui tournent au-dessus de la tête.
- Réglages : Graphismes Bas -> teinte + très peu de particules ; Accessibilité « Réduire les mouvements » -> moins de
  particules, arcs tenus ; boss (raid ou mini-boss invoqués) -> particules plus grosses et plus denses.
