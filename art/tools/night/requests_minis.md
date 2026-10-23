# Demandes d'art — mini-boss sans sprites (14), un lot compact par biome

Code intégré le 22/10/2026 (aucun lot lancé) : IA pilotée par données `game/scripts/enemies/miniboss_brain.gd`
+ bibliothèque de motifs `miniboss_patterns.gd`, fiches `game/data/minibosses.json`, test `minibosses_test`.
Tant qu'un mini n'est pas livré, le jeu emprunte le corps d'un mini existant (`fallback.sprite`, teinté) ;
**chaque `.tres` se branche seul** dès qu'il existe au chemin enregistré dans `game/data/fauna.json` →
`boss_sprites.<id>` (`bosses/mini/<id>/<id>.tres`). Ne rien renommer.
Captures de référence (corps de repli) : `godot --path game --resolution 1280x720 res://tests/minibosses_test.tscn -- only=<biome> shots=<dossier absolu>`.

## Règles communes (tous les lots)
- Format mini-boss **EXACTEMENT** comme les lots C5/R9/N2a (lis `art/tools/monsters/_r9a.txt`, `_n2a.txt`, inspecte
  `game/assets/sprites/bosses/mini/frost_bear/` et son `.tres`) : cellule **170 × 170** (taille d'affichage réelle),
  planches **≤ 4096 px**, lignes = directions `e, s, w, n`, colonnes = frames ; anims `idle_s`, `run_e/s/w/n`,
  `attack_<e,s,w,n>`, `cast_a_<e,s,w,n>`, `cast_b_<e,s,w,n>` (non bouclées), `phase2_s`, `death_s` ; 12 fps (run 14).
  Pieds sur la ligne `bottom`, grande dimension ≈ `dim` de fauna.json (à recaler là si la planche change).
- **Frame d'impact = moitié de l'anim** (attack : frame 3 sur 6 ; cast_a/b : frame 4 sur 8) : le code y applique les
  dégâts (EnemyVisual.BOSS_IMPACT_FRAC). Le geste culmine exactement sur cette frame.
- `attack` = attaque de base, `cast_a` / `cast_b` = sorts listés par mini ci-dessous (correspondance du JSON).
- DA : `art/briefs/STYLE.md` en tête + `STYLE_boss_da.md`, référence `ash_lord_build.py`. PBR usé, palette sombre
  désaturée, **un seul accent émissif** (celui du biome), silhouettes anguleuses, jamais cartoon. Caméra iso du jeu,
  Eevee à échantillons modestes, rendu ×2 puis LANCZOS.
- **Lisibilité de nuit (leçon du Sonneur, OBLIGATOIRE)** : albédo moyen du corps **≥ 90/255**, liseré froid haut-gauche
  sur toute la silhouette ; contrôle sur fond du sol du biome (planche de contact). Le code éclaircit déjà les corps
  (`body_gain` 1,6) et pose une lumière basse : ne pas compter dessus pour sauver un modèle noir.
- Chaque PNG avec `<f>_n.png` (normales espace écran) et `<f>_e.png` (accent émissif seul), même découpage ; ombres cuites.
- Vérification : `sprites_test` puis `minibosses_test -- only=<biome>` → RESULT: OK ; planche
  `art/tools/night/_<lot>_contact.png` (le mini à côté d'ash_lord et du boss d'étage du biome, même échelle).
  Aucun .gd/.tscn ; jamais user://run_save.json, settings.cfg, ni un .blend hors `art/blender/`.
- Effort `low` (un mini-boss) ; consignes courtes via `sh art/tools/run_codex.sh <consigne> <journal>`.

---

## Lot N1 — Terrasses noyées (étage 1) : iron_heron, vat_toad, scarecrow_reaper
Consigne (à copier dans `_n1.txt`, effort `low`) :
> LOT N1 : mini-boss étage 1 iron_heron, vat_toad, scarecrow_reaper selon art/tools/night/requests_minis.md (fait foi :
> noms, cellules, anims) et docs/Design_Etages.md §5. Biome Terrasses : bronze vert-de-gris #8C7A4C, pierre moussue,
> eau #1F3139, accent cyan d'eau doux #5EC8FF. Sorties game/assets/sprites/bosses/mini/<id>/ ; sources
> art/blender/monsters/n1_* ; script art/tools/night/n1_build.py. Lisibilité de nuit obligatoire. Vérif sprites_test et
> minibosses_test -- only=terrasses. Le joueur dort : décide dans l'esprit de la DA et SURPRENDS. Rapport court en français.

| id | Concept | attack | cast_a | cast_b | phase2_s |
|---|---|---|---|---|---|
| `iron_heron` (dim 125, bottom 140) | Échassier 2,6 u, pattes de bronze, bec-harpon, plumes de tôle ; accent : œil cyan | coup de bec (ligne courte) / tir de plume | **harpon** : bec projeté droit devant | **envol** : s'élève, ailes ouvertes (frame 4 = départ ; le corps disparaît en jeu) | se dresse, plumes hérissées (harpon en croix) |
| `vat_toad` (115/140) | Crapaud 2,4 u au ventre-cuve de bronze qui bout, vapeur, peau visqueuse ; accent : liquide de cuve | **langue** (ligne, tire le joueur) | gonfle et **crache des bulles de boue** | **bond** (frame 4 = envol, retombe en jeu) | cuve fendue qui fuit (crache une mare) |
| `scarecrow_reaper` (115/140) | Épouvantail 2,3 u, bois noir, faux rouillée, corbeaux perchés ; accent : braises des yeux | **faux en arc** 180° | **moisson** : faux plantée, 3 sillons | **envol de corbeaux** : bras levés, corbeaux qui partent | la faux s'allonge, corbeaux plus nombreux |

---

## Lot N2 — Forêt-brume (étage 2) : **déjà couvert par N2a / N2b**
`mist_wolf` (+ invocation `mist_wolf_cub`) et `lantern_owl` = consigne **`_n2a.txt`** ; `moss_mantis` = **`_n2b.txt`**.
Ne rien relancer. Correspondance des anims pour ces lots (data/minibosses.json) :
mist_wolf attack = morsure, cast_a = **bond** / hurlement (invocation des louveteaux), cast_b = **pas de brume** (disparaît,
réapparaît derrière le joueur) ; lantern_owl attack = serres en piqué, cast_a = **cri** (cône), cast_b = **sème des follets** ;
moss_mantis attack = lame, cast_a = **ciseaux** (2 lames en V), cast_b = **embuscade** (immobile, camouflé, puis ruée).
Le louveteau `mist_wolf_cub` est enregistré dans fauna.json (`summons`) mais n'est pas encore appliqué aux invocations
(point ouvert code).

---

## Lot N3 — Cité de rouille (étage 3) : steam_hound, grinder, blind_pump
Consigne (`_n3.txt`, effort `low`) :
> LOT N3 : mini-boss étage 3 steam_hound, grinder, blind_pump selon art/tools/night/requests_minis.md et
> docs/Design_Etages.md §5. Biome Cité : fer rouillé, laiton noirci, cuves #26292E, accent orange lampe à vapeur #FF9A3C
> (petit). Sorties game/assets/sprites/bosses/mini/<id>/ ; sources art/blender/monsters/n3_* ; script
> art/tools/night/n3_build.py. Lisibilité de nuit obligatoire. Vérif sprites_test et minibosses_test -- only=cite.
> Le joueur dort : décide dans l'esprit de la DA et SURPRENDS. Rapport court en français.

| id | Concept | attack | cast_a | cast_b | phase2_s |
|---|---|---|---|---|---|
| `steam_hound` (120/140) | Quadrupède mécanique 2,4 u, chaudière sur le dos, mâchoire de piston ; accent : foyer de chaudière | morsure | **charge** : tête baissée, pistons armés (frame 4 = départ de la ruée) | **jets de vapeur** latéraux (soupapes des flancs) | chaudière surchauffée, rivets qui sautent |
| `grinder` (110/138) | Automate 2,3 u à meule, disques de scie au dos, étincelles ; accent : étincelles de meule | **meule** (cône court, geste répété : 2-3 passes) | lance **3 disques** | **tour de meule** : pivote sur lui-même (anneau) | disques supplémentaires sortis |
| `blind_pump` (125/140) | Cuve 2,6 u sur 4 pattes, sans tête, tuyaux et soufflets ; accent : huile chaude dans un hublot | jet d'huile (tuyau frontal) | **aspiration** : soufflets qui se creusent | **geysers d'huile** : tuyaux plantés au sol | soufflets déchirés, aspiration renforcée |

---

## Lot N4 — Cryptes noyées (étage 4) : ossuary_bearer, blind_swarm, salt_golem, blind_lamplighter, sarcophagus_crab
Deux sous-lots pour garder des lots petits : **N4a** = ossuary_bearer + blind_swarm + salt_golem, **N4b** =
blind_lamplighter + sarcophagus_crab (mêmes règles). Consigne (`_n4a.txt` / `_n4b.txt`, effort `low`) :
> LOT N4A (resp. N4B) : mini-boss étage 4 <ids> selon art/tools/night/requests_minis.md et docs/Design_Etages.md §5.
> Biome Cryptes : pierre de sel humide #8C8778→#B4B0A2, os, eau noire, accent cristal blanc-cyan #BFF4FF ; sol très
> sombre #2E3238 : chroma +20 %, albédo ≥ 90/255, rim froid. Sorties game/assets/sprites/bosses/mini/<id>/ ; sources
> art/blender/monsters/n4a_* (n4b_*) ; script art/tools/night/n4a_build.py (n4b). Vérif sprites_test et
> minibosses_test -- only=cryptes. Le joueur dort : décide dans l'esprit de la DA et SURPRENDS. Rapport court en français.

| id | Concept | attack | cast_a | cast_b | phase2_s |
|---|---|---|---|---|---|
| `ossuary_bearer` (120/140) | Golem 2,5 u de pierre de sel portant une niche d'os sur le dos ; accent : cristaux dans la niche | poing | **relève les morts** : frappe le sol, os qui sortent | **effondrement** : soulève la niche et l'abat | la niche s'ouvre, plus d'os |
| `blind_swarm` (110/135) | Reine chauve-souris 2,2 u, ailes membraneuses translucides, pas d'yeux, nuée autour ; accent : oreilles-cristal | griffes | **nuée** : ailes ouvertes, la nuée part | **cri** : gueule ouverte, ondes | nuée doublée |
| `salt_golem` (125/140) | Bloc de sel cristallisé 2,6 u, lent, fissures lumineuses ; accent : cœur de cristal | coup lourd | **onde de choc** : frappe des deux poings | **éclats de sel** en croix (pointes qui jaillissent du corps) | se fend en deux (le code fait naître 2 éclats-brutes) |
| `blind_lamplighter` (120/140) | Humanoïde voûté 2,4 u, aveugle, lanterne de cristal au bout d'une perche ; accent : la lanterne (reste visible quand le corps s'efface) | coup de perche | **cône de lumière** : lanterne brandie, balayage | **pose une lanterne** au sol | deux lanternes |
| `sarcophagus_crab` (130/140) | Crabe 2,8 u portant un sarcophage de pierre, pince géante ; accent : lueur dans les joints du sarcophage | pince | **claquement** : pince projetée droit devant | **se terre** (frame 4 = disparition sous terre ; il jaillit en jeu avec la même anim) | sarcophage ouvert, momie visible |

### FX facultatifs (après les corps, même lot si le quota le permet)
Formes provisoires en code aujourd'hui (RecluseFx) : traces au sol (mares de poison, boue, huile, croûte de sel, flaques
de braise), éclat du Jugement, œufs de l'Essaim-mère. À livrer en textures « sol » vues de dessus (1 u = 64 px) dans
`game/assets/sprites/fx/minis/` : `zone_poison`, `zone_mud`, `zone_oil`, `zone_salt`, `zone_ember`, `zone_ice` (disque
256 px, bord doux, boucle 8 frames), `beam_judgment` (bande 1024 × 96), `egg_brood` (64 px, 4 frames d'éclosion).
Le branchement de ces textures reste à coder (point ouvert).
