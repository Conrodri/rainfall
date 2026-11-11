# Audio étages 4-5 : Cryptes noyées (cartes cryptes_noyees et cryptes_ossuaire_pluies, musique partagée) et La Source (la_source)

Modèle : terrasses/cité = séquenceur `art/tools/audio/gen_music.py` (CFG + BOSS) et `gen_ambience.py` (gen_wind, gen_decor). Étendre ces scripts par paramètres, ne rien réécrire. Synthèse procédurale seulement.

## Livrables (chemins `game/assets/audio/...`, ogg q6, 48 kHz stéréo)
Pour chaque carte-musique `cryptes_noyees` et `la_source` :
- `music/music_<c>_{base,tension,drive,climax}_01.ogg` : 4 stems synchrones, même durée (environ 100-110 s, mesures entières, boucle parfaite, comme `render_map`), niveaux STEM_RMS (-23/-25.5/-25/-24 dB RMS, crête <= -3.5).
- `music/music_boss_<c>_01.ogg` : thème de boss (rms -17, crête <= -2.5, boucle parfaite). Boss final de La Source : le système audio n'a pas de phases, donc un seul thème composé en 3 sections (3 blocs dans `order`) d'intensité croissante : I installation, II poursuite, III apothéose/lamentation, qui boucle.
- `ambience/amb_wind_<c>_01.ogg` et `ambience/amb_<c>_decor_01.ogg` : boucles de 64 s circulaires (rms vent env. -24, décor env. -27, crête <= -3).
Pluie : réutiliser les amb_rain_* existantes (ne pas en refaire).

## DA sonore
- Cryptes noyées : crypte inondée. Mineur éolien/phrygien grave, bpm 66 (couches) / 104 (boss). Cloches noyées (cloche sourde, passe-bas, longue queue, légèrement désaccordée), échos de pierre (réverbe rt60 4.5-5 s, brillance basse), piano feutré ou harpe lente, choeurs lointains en climax. Perc 'soft'/'wood'. Boss : extra 'bells' ou nouveau 'drowned_bells' + grondement d'eau. Décor : gouttes à écho long dans l'eau profonde, clapotis, pierre qui suinte, craquement d'ossements très discret, une cloche noyée lointaine (2 coups). Vent : courant d'air de galerie, souffle creux grave, peu de sifflement, léger gargouillis.
- La Source : puits monumental avec colonne de pluie centrale, tension finale, mélancolie vengeresse du Semeur (deuil du Val noyé volontairement). Mineur sombre (ré ou mi bémol), bpm 58 (couches) / 96 (boss), grande réverbe (rt60 6-7 s), drones très graves, cordes graves (cello), choeurs, cloches rares et lourdes ; thème mélodique simple et triste qui revient. Couches : base = drones + thème lent ; tension = cloches + pulsation ; drive = tambours profonds ; climax = choeur plein + cordes. Boss : tambours lourds, choeur, cloches, sections qui montent. Décor : colonne d'eau centrale (grondement continu large bande de chute d'eau + brume de gouttelettes aiguës), écho de puits (gouttes très résonantes), gouttes tombant de très haut. Vent : souffle ascendant de puits, rafales lentes 5-9 s, gémissement grave.

## Contraintes
- Boucles sans clic (mêmes techniques circulaires que les cartes existantes ; `sl.loop_seam_stats`).
- Ne pas toucher aux fichiers audio existants. Manifests (`music_manifest.json`, `ambience_manifest.json`) : n'ajouter que des lignes, en utilisant `--only <carte>` / `--only boss_<carte>` / `--only wind_<c>` / `--only decor_<c>`. Vérifier avec le statut du dépôt que seuls les nouveaux .ogg, manifests et scripts bougent.
- Étendre `art/tools/audio/verify_new.py` (CARTES) aux 2 nouvelles cartes et le lancer ; corriger jusqu'à OK (NaN, crête <= -1 dBFS, 4 stems de même longueur, boucle).
- Ne lance PAS Godot. Pas d'import. Ne lis pas de fichiers entiers (utilise rg).
- Rapport 6 lignes : fichiers, durée, crête, RMS.
