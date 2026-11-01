# Panoplies : tenues thématiques des personnages (brief d'assets, 01/11/2026)

Catalogue : `game/data/cosmetics.json` (famille `panoplie`). Design et fiches complètes des 3 thèmes : `docs/Boutique_Rubis.md` §3.1. Contrat de base : `docs/Skins.md` (même ossature, mêmes animations, mêmes planches que le skin trophée). Ce brief donne ce qu'un développeur peut coder dès maintenant avec des placeholders et ce que Codex doit livrer.

**Décision du joueur (01/11/2026)** : v1 = un seul thème, « Avant la pluie » (`avant_la_pluie`), 4 personnages : **Averse, Vigie, Ardent, Rictus** (8,4 Mo mobile estimés). Aucun pack `.pck`. Les autres personnages et les thèmes « Garde de crue » et « Cortège des cryptes » restent documentés dans `Boutique_Rubis.md` §3.1.3-3.1.4 et ne se produisent pas tant que le joueur ne l'a pas demandé.

## 1. Convention de chemins (contrat `skins.gd`, inchangé)

- Id d'article = id de skin = `<perso>_<theme>` : `averse_avant_la_pluie`, `vigie_avant_la_pluie`, `ardent_avant_la_pluie`, `rictus_avant_la_pluie`.
- Dossier : `game/assets/sprites/characters/<perso>/skins/<perso>_<theme>/` (c'est `Skins.skin_dir(perso, id)`).
- SpriteFrames : `<dossier>/<perso>_<theme>.tres` (c'est `Skins.skin_frames_path`) : copie du `.tres` par défaut avec chaque `res://assets/sprites/characters/<perso>/<f>.png` remplacé par `res://assets/sprites/characters/<perso>/skins/<perso>_<theme>/<f>.png` ; mêmes animations, régions, cadences, boucles.
- Portrait : `<dossier>/portrait.png` 256×256 (+ `portrait_e.png` 128×128 là où le défaut en a un : Ardent et Vigie oui, Averse non, Rictus : portrait par défaut dans `ui/portraits/rictus.png`, le skin livre le sien dans son dossier). `Skins.portrait_info` le trouve.
- Aperçu de la fiche boutique : le `portrait.png` du skin (clé `preview` de `cosmetics.json`).
- Partagé, jamais livré : `effects/`, `variants/`, sous-dossiers de VFX, projectiles, invocations, `ui/portraits/` par défaut.
- Placeholder dev : tant que le dossier n'existe pas, `Skins.has_assets` est faux et le jeu affiche le défaut ; l'entrée `cosmetics.json` est `"pending": true`. Rien à dessiner.

## 2. Contrat de fichiers par personnage (v1)

Mêmes noms, tailles de planche, grilles, frames, ordre des directions `e, se, s, sw, w, nw, n, ne`, pivots que le dossier par défaut mesuré le 01/11/2026 ; `_e` à demi-résolution `((w+1)//2 × (h+1)//2)`, jamais noir ni vide, **aucun `_n`**, aucune planche > 4096 px.

| Personnage | Cellule | Planches diffuses (largeur × hauteur) | Portrait |
|---|---|---|---|
| Averse | 192 rognée | attack 1044×1136, cast 720×1168, cast_ult 896×1184, crue 1332×1136, death 992×1392, idle 736×1136, run 832×1152, stumble 348×1136, wave 936×1136 | portrait 256×256 |
| Vigie | 192 | attack 768×1536, brace 768×1536, death 1152×1536, draw 1152×1536, flare 960×1536, idle 1536×1536, net 960×1536, run 1536×1536, volley 1344×1536 | portrait 256×256 + portrait_e 128×128 |
| Ardent | 192 | attack 960×1536, cast 1152×1536, cast_ult 1536×1536, idle 1536×1536, run 1536×1536 | portrait 256×256 + portrait_e 128×128 |
| Rictus | 192 | catch 768×1536, death 1152×1536, idle 1536×1536, lift 576×1536, run 1536×1536, slash 768×1536, spin 1536×192 (1 ligne), stagger 576×1536, summon 1152×1536, throw 768×1536, throw_ult 1152×1536 | portrait 256×256 |

Chaque planche diffuse a son `<f>_e.png` si le défaut en a un (mêmes zones d'accent, IoU accent > 0,90).

## 3. Fiches « Avant la pluie » (v1)

Matières communes du thème (cel 3 tons, DA sombre de `STYLE_cel.md`, aucune saturation ajoutée, rien de rouillé ni de mouillé) : lin écru #B8AE9A, laine grise #5A5B5E, laine bleu nuit #2F3A4C, cuivre poli #B4733A, laiton #A8946E, verre clair #9FB7B8, cuir fauve #8A5A36, velours vert bouteille #2E4A3A, nacre #D9D4C7. Garde-fous : silhouette IoU alpha > 0,95 par cellule, aucun accessoire à plus de 2 px hors de la silhouette d'origine, accent émissif inchangé (teinte et zones), L\* du ton moyen ≥ 45 sur le sol du biome, aucun rouge ni orange saturé hors accent.

### 3.1 Averse : « Porteuse d'eau »
- Coiffe : foulard de lin écru noué sur la nuque, mèches sorties (le volume de la tête ne change pas).
- Corps : robe de lin écru à manches retroussées, corselet de cuir fauve lacé, sandales de corde ; plus de ciré.
- Outil : amphore de verre soufflé clair (#9FB7B8, 3 tons) cerclée de cuivre neuf ; même volume, **même fenêtre d'eau** (la zone d'accent eau #5FD4E8 reste au même endroit, même taille).
- Dos : bretelles de cuir, bâton de portage glissé dans le dos (dans la silhouette existante, ne déborde pas).
- Accent : eau #5FD4E8, mêmes zones que `averse/*_e.png`.

### 3.2 Vigie : « Guetteuse de beau temps »
- Coiffe : béret de laine bleu nuit à insigne de cuivre (remplace la capote ; même hauteur de crâne).
- Corps : vareuse de laine bleu nuit à deux rangées de boutons de cuivre, pantalon de toile grise, guêtres de cuir fauve.
- Arme : arc d'if verni clair (#8A6A3C), corde neuve ; carquois de cuir fauve à boucle de laiton.
- Dos : pèlerine courte de laine grise (dans la silhouette de la pèlerine actuelle).
- Accent : rouge de fusée #FF3A4F sur les fusées à la hanche, mêmes zones que `vigie/*_e.png` ; aucun autre rouge.

### 3.3 Ardent : « Allumeur de réverbères »
- Coiffe : casquette de cuir fauve à visière courte à la place de la capuche (même hauteur ; la visière reste dans les 2 px de la silhouette de la capuche).
- Corps : redingote de laine grise à double boutonnage de cuivre, gilet de lin écru, bottines de cuir.
- Arme : perche d'allumeur en cuivre poli, lanterne de verre clair à la pointe (même longueur et même épaisseur que le bâton) ; la braise #FF8C33 brûle dans la lanterne.
- Ceinture : bidon d'huile de cuivre (petit, dans la silhouette).
- Accent : braise #FF8C33, mêmes zones que `ardent/*_e.png` (pointe du bâton, main).

### 3.4 Rictus : « Première »
- Tête : porcelaine intacte (aucune fêlure, aucun recollage), joues peintes rose éteint #9A6E6A, cheveux de crin peignés, ruban de velours vert.
- Corps : habit de velours vert bouteille à boutons de nacre, jabot de lin, culotte de satin gris, bas blancs cassés.
- Armes : couteaux à manche de nacre, lames polies (mêmes gabarits ; les couteaux plantés et l'éventail des variantes restent partagés, rien dans `variants/`).
- Dos : fils de marionnette neufs en chanvre clair (#C9BE9C) au lieu des fils noirs.
- Accent : argent spectral #9FC8C0, mêmes zones que `rictus/*_e.png`. Le Montreur n'est pas touché.

## 4. Procédé Codex (par personnage, un lot)

1. Copier le `.blend` du héros dans `art/blender/cel/skins/<perso>_avant_la_pluie.blend` (jamais modifier ni enregistrer un `.blend` d'origine).
2. Reprendre `art/tools/night/skin_<perso>_build.py` (lot 47-51) en paramètres : id de skin, dossier de sortie, dictionnaire de matériaux (Base Color, rugosité, metallic ; émission des zones d'accent inchangée) et accessoires de surface. Rig, poses, frames, caméra `iso_rig`, pivots, rognage inchangés.
3. Rendu cel : `cel.install('creature', normals=False)`, graine fixe, Blender `--background` uniquement, Eevee 8 échantillons.
4. `.tres` par substitution de chemins ; PNG optimisés (`optimize=True, compress_level=9`).
5. Vérifs : `cel.check_sheet(..., normals=False)` par planche ; IoU alpha/accent contre le dossier par défaut dans `art/tools/cosmetics/_panoplie_<perso>_avant_la_pluie_verification.json` ; planche contact `art/tools/cosmetics/_panoplie_<perso>_avant_la_pluie_contact.png` (défaut à gauche, Panoplie à droite, idle/run/attaque/portrait, sur `game/assets/sprites/terrain/terraces/iso/ground_a.png`, ≤ 1024 px de large) ; `godot --headless --path game --import` sans erreur ; `res://tests/sprites_test.tscn` et `res://tests/texture_budget_test.tscn` ; `load(<tres>)` donne les mêmes noms d'animations que le défaut.
6. Budget : `python art/tools/texture_budget.py` avant/après, Mo png et mobile ajoutés rapportés ; `texture_budget_test` échoue déjà sur le total global : rapporter, ne rien supprimer.

## 5. Estimation Mo (mesure `docs/Skins.md`, mobile)

Averse 1,2 ; Rictus 2,2 ; Vigie 2,3 ; Ardent 2,7 : **8,4 Mo** pour la v1. Seuil d'alerte : +20 % sur un lot → l'orchestrateur arbitre avant le suivant.
