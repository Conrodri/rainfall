## Usage prevu
- spells : `spell_eclat_de_braise_cast/hit_*` (id `spell.eclat_de_braise.cast`, `.hit_light|medium|heavy`), `spell_nova_ardente_cast_*`, `spell_cendres_cast_*` (BOUCLE 4 s, zone), `spell_brasier_cast_*`, `spell_ultimate`; variantes B : `spell_flame_pillar`, `spell_meteor_rain`, `spell_phoenix`, `spell_roaming_embers_start/loop` (boucle 3 s). Le jeu choisit light/medium/heavy selon les degats puis module hauteur (jusqu a +-12 %) et volume.
- impacts : `hit_light/medium/heavy`, `hit_crit` (crack), `hit_<fire|ice|poison|lightning>_<niveau>`, `status_*`, `lightning_chain_medium`, `death_t1..t4`, `death_elite`, `death_boss_heavy`, `enemy_*` (contact, tir, cone de la brute, onde de choc), `telegraph_*` (montees d alerte), `player_hurt/death/heal`, `boss_spawn`, `boss_defeat`, `stage_cleared` (ids `boss.spawn`, `boss.defeat`, `stage.cleared` : deja livres, non regeneres).
- footsteps : `step_<player|monster_t1|monster_t2|monster_t3|boss>_<stone|wet|water|dirt|grass|metal>` ; plus fichiers par sujet detailles (`step_ardent`, `step_swarm`, etc. deja fusionnes dans les ids ci-dessus).

## Lot 2 : ambiances, UI/coffres, musiques (synthese Claude, intérim Codex)
Scripts : `art/tools/audio/synth_lib.py` (DSP : oscillateurs a table d ondes, piano/harpe/cloche/flute/cordes/cuivres/choeur/percussions, reverberation a convolution synthetique circulaire), `gen_ambience.py`, `gen_ui.py`, `gen_music.py` (partitions ecrites dans le dict `CFG`/`BOSS`/`MENU`), `verify_new.py` (controle numerique), `build_manifest.py` (ce fichier). Tout est reproductible (`--seed`, `--only`). Remplacable a l identique par Codex (memes noms).

**Ambiances** (dossier `ambience/`, ogg q4, stereo, boucles de 64 s a raccord circulaire ; RMS cible -22,5 a -27,5 dBFS) :

| id logique | fichier(s) | note |
|---|---|---|
| `amb.rain` | `amb_rain_01` (= moyenne) | pluie par defaut |
| `amb.rain.light/medium/heavy` | `amb_rain_light_01`, `amb_rain_medium_01`, `amb_rain_heavy_01` | 3 intensites (a router par palier de difficulte ; le dict `maps` actuel n utilise que `amb.rain`) |
| `amb.wind` | `amb_wind_01` | vent intermediaire generique |
| `amb.wind.cite_rouille` | `amb_wind_cite_rouille_01` | tres venteux, sifflements metalliques, grincements |
| `amb.wind.foret_brume` | `amb_wind_foret_brume_01` | calme, bruissements de feuillage |
| `amb.wind.terrasses_noyees` | `amb_wind_terrasses_noyees_01` | ouvert, creux, ruissellement leger |
| `amb.<carte>.decor` | `amb_terrasses_noyees_decor_01`, `amb_foret_brume_decor_01`, `amb_cite_rouille_decor_01` | decors par carte |
| `amb.thunder_close` / `amb.thunder_far` | `amb_thunder_close_01..04`, `amb_thunder_far_01..04` | one-shots (non boucle) |

Contrat a noter pour l orchestrateur : `sounds.json` reference `amb.wind` pour la Cite et les Terrasses et rien pour la Foret ; pour le vent propre a chaque carte, utiliser les ids `amb.wind.cite_rouille`, `amb.wind.terrasses_noyees`, `amb.wind.foret_brume` (le fichier `amb_wind_cite_rouille_01.ogg` est trouve par la regle `.` -> `_`), et `amb.rain.light|medium|heavy` pour router la pluie par palier.

**UI / recompenses / coffres** (dossier `ui/`, ogg q5, stereo, RMS utile ~ -20 dBFS, crete <= -1,5 dBFS) : `pickup_coin` (4), `pickup_xp` (4), `pickup_ruby` (3), `ui_click` (4), `ui_level_up` (2), `ui_spell_ready` (3), `ui_dice` (4), `ui_item_pick` (3), `chest_lock` (3), `chest_open_petit|large|legendaire|boss` (3/3/2/2), `chest_reveal` (3), `chest_legendary_rise` (2, ~3,8 s), `chest_legendary_impact` (2). Ids : `pickup.coin`, `chest.open.petit`, `chest.legendary.rise`, etc. (`.` -> `_`). `boss.spawn`, `boss.defeat`, `stage.cleared` : voir dossier `impacts/` (lot 1).

**Musiques** (dossier `music/`, ogg q4, stereo, boucles) :

| id logique | fichier | tempo / tonalite | duree |
|---|---|---|---|
| `music.terrasses_noyees.base/tension/drive/climax` | `music_terrasses_noyees_<stem>_01` | 72 BPM, re eolien (piano, harpe, cloches) | 32 mesures = 106,67 s |
| `music.foret_brume.base/tension/drive/climax` | `music_foret_brume_<stem>_01` | 64 BPM, mi dorien (flute, cordes pincees, pads) | 32 mesures = 120,00 s |
| `music.cite_rouille.base/tension/drive/climax` | `music_cite_rouille_<stem>_01` | 84 BPM, do phrygien (cordes graves, metal, drones) | 36 mesures = 102,86 s |
| `music.boss.terrasses_noyees` | `music_boss_terrasses_noyees_01` | 112 BPM, re mineur (cuivres, eau, tambours) | 48 mesures |
| `music.boss.foret_brume` | `music_boss_foret_brume_01` | 120 BPM, mi dorien/phrygien (bois, tambours de troncs) | 56 mesures |
| `music.boss.cite_rouille` | `music_boss_cite_rouille_01` | 126 BPM, do phrygien (cloches dissonantes, choeur grave) | 56 mesures |
| `music.menu` | `music_menu_01` | 60 BPM, la mineur, feu de camp, pluie lointaine | 24 mesures = 96 s |

Les 4 stems d une carte ont exactement le meme nombre d echantillons et demarrent ensemble (verifie par `verify_new.py`). Le raccord est circulaire (queues de reverb repliees sur le debut).

Niveaux des stems : RMS base -23, tension -25,5, drive -25, climax -24 dBFS (crete <= -8,3 dBFS). Somme au palier 4 du `sounds.json` (-3/-4/-1/0 dB) : crete -1,3 dBFS (Terrasses, Foret) et -2,2 dBFS (Cite) ; sans gain de palier, la somme brute des 4 stems peut depasser 0 dBFS (bus Music a laisser avec limiteur ou -2 dB).
Boucles : encodees en Vorbis q6 (les q inferieures laissent un petit ecart de codec au raccord du fichier) ; verification LPC du raccord sur le .ogg decode (`verify_new.py`).
Remplacement des ids lot 1 : `boss.spawn`, `boss.defeat`, `stage.cleared` existent deja dans `impacts/`.
