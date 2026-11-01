# Parements d'interface : cadres et thèmes d'UI (brief d'assets, 01/11/2026)

Catalogue : `game/data/cosmetics.json` (famille `parement`, `target` `""`). Design : `docs/Boutique_Rubis.md` §3.5. Système (dev) : un `Theme` par Parement chargé depuis `cosmetics.json`, substitution des `StyleBoxTexture` et des textures de cadre par chemin ; les JSON de 9-slice sont ceux de `ui/da/` (copiés tels quels dans le dossier du Parement).

## 1. Convention de chemins

`game/assets/sprites/ui/parements/<id>/` : **mêmes noms et mêmes tailles** que les fichiers par défaut (mesure du 01/11/2026). Les JSON de 9-slice (`<nom>.json`) sont **copiés sans modification** depuis `ui/da/` (marges et `content_insets` identiques). Pour un fichier qui a un `_e` par défaut (`button_hover_e`, `button_danger_e`, `button_primary_e`, `button_primary_hover_e`, `button_primary_pressed_e`), le Parement livre un `_e` de même taille que le `_e` par défaut, mêmes zones ; les autres n'en ont pas.

| Fichier | Taille | Défaut | Ce qui change |
|---|---|---|---|
| `bar_frame_hp.png` (+ `.json`) | 512×48 | `ui/da/` | matière du cadre ; la fenêtre du remplissage (zone intérieure définie par `content_insets`) reste 100 % transparente |
| `bar_frame_xp.png` (+ `.json`) | 512×28 | `ui/da/` | idem |
| `bar_frame_boss.png` (+ `.json`) | 1024×64 | `ui/da/` | idem |
| `button_normal.png`, `button_hover.png`, `button_pressed.png`, `button_disabled.png`, `button_danger.png`, `button_primary.png`, `button_primary_hover.png`, `button_primary_pressed.png` (+ `.json` chacun) | 320×96 | `ui/da/` | matière, ornements d'angle ; états lisibles entre eux (hover plus clair, pressed plus sombre, disabled désaturé) ; `danger` garde un liseré rouge sombre #7A2A22 (seul rouge autorisé, hors HUD de combat) |
| `panel_9slice.png` (+ `.json`) | 384×384 | `ui/da/` | fond et bord des panneaux de menu |
| `panel_small_9slice.png` (+ `.json`) | 192×192 | `ui/da/` | idem, petits panneaux |
| `header_banner.png` (+ `.json`) | 640×96 | `ui/da/` | bandeau de titre |
| `divider.png` | 512×24 | `ui/da/` | séparateur |
| `timer_plate.png` (+ `.json`) | 256×80 | `ui/da/` | plaque du chrono |
| `spell_frame.png`, `spell_frame_pressed.png`, `spell_frame_cooldown.png` | 160×160 | `ui/` | cadre des 4 sorts ; l'anneau de recharge `spell_cooldown_ring.png` et les icônes de sorts ne sont pas livrés |

Inchangés et jamais livrés : `bar_fill_*`, icônes (`icon_*`, `minimap_*`), `keycap_9slice`, `level_badge`, `vignette_hit`, police, invites de touches, chiffres de dégâts. Aperçu de fiche : `game/assets/sprites/cosmetics/previews/<id>.png` 256×256 (un bouton primaire, un cadre de PV et un cadre de sort du Parement, composés sur fond sombre, rendu Blender).

Placeholder dev : dossier absent = thème par défaut ; l'article reste `pending`.

## 2. Les 4 Parements v1 (matières des skins trophée, cel profil `ui` : 2 tons + encre 1 px)

| Id | Nom | Matière | Tons (base) | Ornement |
|---|---|---|---|---|
| `bronze_de_cloche` | Bronze de cloche | bronze poli de cloche, cerclages de cuivre rouge, inscriptions gravées (Tocsin « Carillon ») | bronze #8C6A3E, cuivre #8A4A2E, fond #241E18 | rivets aux angles, un cerclage sur les barres |
| `celadon` | Céladon | porcelaine céladon craquelée cerclée d'argent (Averse « Céladon ») | céladon #7FA394, craquelures #4E6B60, argent #9AA0A6, fond #1E2624 | cerclage d'argent fin, craquelures dans les panneaux |
| `laque_noire` | Laque noire et or | laque noire, filets d'or, nacre recollée (Rictus « Gala noir ») | laque #17151A, or #A8863C, nacre #C9C2B5, fond #121014 | filet d'or à 2 px du bord, éclat de nacre à un angle |
| `argent_noirci` | Argent noirci | argent noirci gravé de plumes (Vigie « Cormoran ») | argent #6A6E74, creux #2E3034, fond #1B1D20 | plumes gravées sur le bandeau et les panneaux |

## 3. Garde-fous et vérifs

- Le cadre **ne couvre jamais le remplissage** : la zone intérieure de chaque `bar_frame_*` (rectangle `content_insets` du JSON) est entièrement alpha 0 ; vérifié par script.
- Contraste cadre/fond ≥ 3:1 (luminance relative), tailles de police intouchées, mêmes marges 9-slice (JSON identiques octet pour octet au défaut).
- Script de vérif : dimensions exactes de chaque fichier, JSON identiques, alpha de la fenêtre des barres, contraste ; planche contact ≤ 1024 px (HUD composé : barre de PV à 20 %, 4 cadres de sorts, 2 boutons).
- `godot --headless --path game --import` ; `res://tests/texture_budget_test.tscn` -> RESULT: OK (≈ 0,4 Mo par Parement, lossless).
- Capture de validation en jeu (dev) : HUD avec le Parement, PV à 20 % lisible.
