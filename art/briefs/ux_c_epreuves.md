# Lot UX-C : Épreuves, interface

Source : docs/Audit_UX_Ajouts_2026-11-07.md §8 (lot UX-C), docs/Design_Epreuves.md. Face caméra (pas d'iso), fond transparent, liseré sombre 2 px à la taille source, DA sombre désaturée + UN accent émissif (STYLE_boss_da.md), cel-shadé sans normal maps. Lisibles à 1920x1080 et sur téléphone : silhouettes distinctes SANS la couleur, contraste >= 3:1 sur #1A1C20. PNG optimisés (budget mobile, ~2 Mo de marge pour tout le projet : viser < 4 Ko par 64 px, < 12 Ko par 128 px).
Script à créer : art/tools/ui/ux_c_build.py (s'inspirer de art/tools/ui/prompts.py et ui_kit.py ; Blender --background).

| Fichier | Taille | Dossier | Forme |
|---|---|---|---|
| minimap_epreuve_escorte.png | 64 | game/assets/sprites/ui/da/ | barque vue de dessus (coque pointue, un banc) |
| minimap_epreuve_rituel.png | 64 | idem | anneau avec 3 relais (plots) |
| minimap_epreuve_poursuite.png | 64 | idem | flamme/lanterne courante, goutte penchée |
| minimap_epreuve_veine.png | 64 | idem | cristal facetté avec filon (tracé) |
| minimap_epreuve_tenue.png | 64 | idem | cloche |
| epreuve_grade_parfait.png + epreuve_grade_parfait_e.png | 128 (e : 64) | idem | médaillon à TROIS pointes, or, accent émissif |
| epreuve_grade_bien.png | 128 | idem | médaillon à DEUX pointes, vert-de-gris |
| epreuve_grade_fait.png | 128 | idem | médaillon rond simple, fer |
| cue_epreuve.png | 96 | game/assets/sprites/ui/cues/ | chevron DOUBLE orienté vers +X, même trait que cue_elite.png, gris neutre clair (#D8D8D8-#F0F0F0), teinté au verbe par modulate |

Les 5 icônes de verbe : couleur propre discrète (l'accent est le verbe) mais forme décisive. La forme porte la note (3/2/0 pointes), la couleur la double. `_e` : masque d'émission (accent seulement), non vide, jamais noir.
