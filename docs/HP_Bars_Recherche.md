# Barres de vie - Recherche et spec pour Rainfall

Note de méthode : la recherche web a donné peu de sources primaires (pas de GDC talk ni d'article Game Developer retrouvé ; rien de précis sur Diablo IV, PoE, Elden Ring, Hollow Knight). Les chiffres marqués **[src]** viennent d'une source citée ; les autres sont des **valeurs de départ recommandées** (convention courante du genre, à régler en playtest), pas des mesures des jeux cités.

## 1. Principes clés

- **Lisibilité d'abord** : une barre répond à trois questions : combien reste-t-il, combien vient de partir, est-ce critique ? Tout le reste est décor. Les pistes sourcées convergent : valeur courante lisible, animation de chute pour montrer l'ampleur du coup, état critique distinct (bugnet, résumé de recherche).
- **Hiérarchie par taille et présence** : base < élite < mini-boss < boss. Plus l'ennemi compte, plus la barre est large, ornée, persistante. Un monstre de base n'a pas de cadre ; un boss a cadre, nom, titre, encoches.
- **Survivor-likes** : Vampire Survivors n'affiche pas de barres sur les ennemis de base ; la mort rapide et le flash de coup suffisent (le retour de coup remplace la barre). Une barre par monstre dans une horde de 100+ serait du bruit. Un clone cité montre que l'effacement progressif du sprite nuit à la lisibilité (itch.io, voir sources).
- **Quand afficher une barre de monstre de base** (recommandé) : cachée à pleine vie ; apparaît au premier dégât ; disparaît 2-3 s après le dernier dégât ; toujours visible pour élites et au-dessus. Un asset du commerce propose exactement ces options (cacher à pleine vie / après X s sans perte) **[src]**. En horde dense : limiter l'affichage aux N ennemis les plus proches du joueur ou ciblés (N = 8 à 12), ou n'afficher que si PV max > seuil.
- **Contraste sur fond sombre** : fond de barre quasi noir translucide (alpha 0,7), remplissage clair et saturé, liseré extérieur noir 1 px. Ne jamais compter sur la couleur seule (daltonisme) : ajouter forme/position/texture (encoches, icônes).
- **Couleur des barres ennemies vs joueur** : les barres ennemies utilisent souvent une couleur attention-grabbing distincte de celle du joueur **[src]**. Chez Rainfall : joueur = vert/teal discret en HUD ; ennemis = rouge rouille.
- **Taille selon plateforme** : cible de lisibilité à 1920x1080 ~ 4-6 px de haut pour un monstre de base, 8-12 px pour élite ; sur téléphone (écran 6", même résolution logique) prévoir x1,3 en hauteur et x1,2 en largeur, aucun texte sous 12 px logiques, et zones de doigt dégagées (aucune barre de monde dans les coins de contrôle).

## 2. Ressenti des coups sur la barre

Le modèle de référence est la **barre retard** (ghost / chip) : la barre réelle chute instantanément, une seconde barre claire derrière elle rattrape ensuite. Sources : widgets "trailing damage" (Fab), mod Grain Rot "ghost pâle + hit punch", prototype itch.io à "deux barres et un timer", barre Calamity (rouge = dégâts récents, disparaît après 0,5 s sans dégât, inspirée de Metal Gear Rising) **[src]**.

Valeurs de départ (recommandées) :

| Effet | Réglage |
|---|---|
| Barre réelle | chute instantanée (0 ms) ou 60-80 ms ease-out |
| Ghost : couleur | blanc cassé / rouge clair derrière la barre ; au premier coup blanc, puis vire rouge pâle en 100 ms |
| Ghost : délai avant rattrapage | 350-500 ms (Calamity : 500 ms sans nouveau dégât **[src]**) ; chaque nouveau coup relance le délai |
| Ghost : vitesse de rattrapage | 250-400 ms ease-in, ou vitesse constante ~ 60 % de la barre/s ; plafonner à 600 ms même pour un gros coup |
| Flash blanc de la barre | 1 frame blanc plein (~ 33-50 ms) puis retour 80 ms |
| Flash blanc du sprite ennemi | 60-100 ms, shader additif ; plus long (120 ms) sur critique |
| Tremblement de barre | amplitude 2-3 px (1-2 px base, 4 px boss), 120-160 ms, décroissant, seulement si le coup retire > 10 % PV max |
| Éclat/particules au bord | 3-6 étincelles (braise) au bord du remplissage, durée de vie 250-400 ms ; seulement boss/élites |
| Pulsation sous seuil (joueur) | sous 25 % PV : pulsation lente 1,2 s de période, +20 % luminosité, sans bouger la barre ; sous 10 % : 0,7 s |
| Gros coup vs DoT | gros coup = flash + tremblement + ghost visible ; DoT = ghost désactivé ou très fin, pas de flash (sinon strobe) ; teinte de la chute selon le statut |
| Critique | flash orange/accent plus long, tremblement x1,5, nombre de dégâts agrandi ; la barre ne change pas de forme |
| Soin | ghost inversé : segment vert/clair qui monte d'abord (150 ms), la barre réelle le rejoint ; pas de tremblement |
| Bouclier / armure | superposé : liseré ou second remplissage gris acier au-dessus de la vie, qui se consomme avant la vie ; flash bleu-gris à l'impact, cassure en 3 éclats quand il tombe à 0 |

À éviter : combiner tous les effets sur chaque coup (surcharge) ; animer des barres en monde à chaque frame sur 100 ennemis (coût CPU/overdraw : mutualiser).

## 3. Phases de boss

- **Encoches aux seuils** : petites marques verticales fines (2 px, 60 % de la hauteur) sur la barre, positions = seuils de phase (ex. 66 % et 33 %). Elles servent d'annonce : le joueur anticipe le changement.
- **Segments** : alternative = barre découpée en N segments séparés par un trait ; chaque segment se vide l'un après l'autre. La barre Calamity montre une barre par partie pour les boss multi-parties et un compteur de parties pour les bosses à nombreux segments **[src]**. Une solution de forum empile plusieurs barres pleine largeur remplies séparément (Godot) **[src]**.
- **Transition** : à l'atteinte du seuil, la barre se fige, la ghost-bar est écrasée immédiatement, le cadre se fissure (flash blanc 100 ms, tremblement 6 px, 300 ms), puis le segment suivant se remplit de gauche à droite en 0,8-1,2 s avec la nouvelle teinte (plus chaude/plus émissive, un seul accent).
- **État invulnérable** : pendant la transition (1-2 s), remplissage grisé hachuré et icône de bouclier/cadenas sur le cadre ; la barre ne reçoit aucun flash de coup. À la fin, retour à la couleur de phase. Calamity grise le nom/liseré bleu lors d'une réduction de dégâts et le fait rougeoyer à l'enrage **[src]** : bon modèle d'états de boss.
- **Nom + titre** : nom en capitales espacées au-dessus de la barre (22-28 px), titre/épithète en dessous ou à droite, plus petit et en gris (14-16 px). Apparition : barre qui se déploie du centre en 0,5 s, nom qui fade-in.
- **Position** : en haut et centrée, largeur 40-50 % de l'écran à 1080p (≈ 800-960 px), 14-18 px de haut ; sur téléphone, 70 % de la largeur, 14 px, sous la zone sûre (encoche/notch).

## 4. Statuts

Deux approches :
1. **Icônes sous la barre** : simples à lire, précises (stacks en chiffre, durée en anneau), mais encombrent les barres de monde.
2. **Barre teintée/animée** : lisible de loin, pas d'icône à déchiffrer ; coûte en assets et ne porte pas les stacks.

Recommandation : **les deux, hiérarchisés**. Barre de monde = teinte/animation du statut dominant (1 seul à la fois) ; icônes uniquement sous la barre des élites/boss (max 4-6 visibles, +N au-delà). Des assets du commerce mettent des icônes brûlure/poison sous la barre pour une durée donnée **[src]** ; un design doc note que tous les effets n'ont pas besoin d'icône, la plupart peuvent aller dans l'UI de base **[src]**.

| Statut | Barre teintée/animée | Icône | Stacks / durée |
|---|---|---|---|
| Brûlure | remplissage orange, lueur qui pulse, 2-3 braises montent du bord | flamme | stacks = chiffre ; durée = anneau radial qui se vide |
| Poison | vert acide, gouttes qui "suintent" sous la barre (texture, 1 goutte/0,8 s) | goutte | stacks = chiffre ; intensité du suintement augmente |
| Gel | liseré givre, remplissage bleu pâle, cristaux statiques ; fissure quand le gel est brisé | flocon | durée = anneau ; "brisé" = flash |
| Étourdi | barre grisée + petites étoiles/éclairs, ou petit anneau au-dessus du cadre | étoile | durée = anneau court |
| Emprisonné | cadre de chaînes autour de la barre | chaîne | durée = anneau |
| Bouclier/armure | voir section 2 | bouclier | jauge propre |

Règles : un statut = une couleur unique et constante ; un chiffre de stacks jamais plus petit que 10 px ; l'anneau de durée est plus lisible qu'un compte à rebours pour un coup d'oeil.

## 5. Recommandations pour Rainfall

Contexte : DA sombre, PBR usé, métal rouillé et fer, un seul accent émissif, iso 2:1, 1920x1080 PC + téléphones.

**Palette** (accent émissif unique = rouge-orangé braise) :
- Fond de barre : #0B0907 alpha 0,75 ; cadre fer : #2A2623 à #4A423C (usure) ; liseré 1 px #000.
- Remplissage vie ennemi : #B8321E (rouille/braise) avec dégradé léger vers #7A1F12 en bas.
- Ghost : #F2E6D8 (flash 100 ms) puis #D96A4E.
- Élite : même rouge + cadre fer plus large + pointes métal. Boss : cadre ornemental, remplissage braise émissif (seul élément qui "brille").
- Statuts : teintes désaturées sauf l'accent ; ne pas multiplier les accents brillants (brûlure = accent, poison/gel = tons ternes).
- Vie joueur (HUD) : teal sombre #2F8F83 ; bouclier : acier #8FA3B0.

**Tailles (1920x1080, @1x)**

| Élément | Largeur x hauteur | Notes |
|---|---|---|
| Monstre de base | 36-48 x 4 px | sans cadre, 1 px liseré ; visible au premier dégât, 2,5 s |
| Élite | 72 x 8 px | cadre fer 2 px, nom court, icônes de statut 12 px sous la barre |
| Mini-boss | 120 x 10 px | cadre ouvragé, nom au-dessus |
| Boss (HUD haut) | 880 x 16 px | nom 24 px, titre 14 px, encoches, icônes 20 px |
| Téléphone | x1,3 en hauteur, x1,2 en largeur sur le monde ; boss 70 % largeur | pas de texte < 12 px |

Position monde : centrée au-dessus du sprite, offset 8-12 px au-dessus du point le plus haut, projeté en espace écran pour garder la taille constante (ne pas la mettre en perspective iso).

**Timings (récap)** : barre réelle 0-80 ms ; flash sprite 80 ms ; ghost délai 400 ms, rattrapage 300 ms ; tremblement 140 ms ; apparition 120 ms fade-in ; disparition 2,5 s après dernier dégât puis fade-out 300 ms ; transition de phase boss 1,2 s ; pulsation PV bas 1,2 s.

**Code vs assets Blender**

En code (shader/UI) :
- Remplissage et ghost (deux barres + timer), flash blanc, tremblement, pulsation, particules de bord, anneaux de durée, texte de stacks, logique d'affichage/masquage, changement de teinte par statut (tinting du remplissage), animation des gouttes/givre (scroll UV).
- Gestion du nombre maximal de barres visibles, pooling.

Assets à produire (rendu Blender, PBR usé) :
- Cadres : base (aucun), élite, mini-boss, boss (9-slice : coins, bords répétables, 2 résolutions).
- Embouts/ornements du boss (gauche/droite) et plaque de nom.
- Encoches de phase (1-2 variantes), cassure de cadre (3 états : intact, fissuré, brisé).
- Textures de remplissage tuilables : braise (rouge), glace/givre, acide, métal chauffé ; masque de bruit pour le scroll.
- Icônes de statut (flamme, goutte, flocon, étoile, chaîne, bouclier, cadenas) à 64 px rendus puis réduits à 12-20 px ; versions 1x et 2x pour mobile.
- Anneau de durée (masque radial) et fond d'icône en fer.
- Atlas unique par résolution ; prévoir texture mobile à 50 % de résolution.

**Ordre d'implémentation** : (1) barre monde de base + ghost + masquage auto ; (2) barre élite + icônes ; (3) barre boss HUD + encoches/phases ; (4) teintes de statut animées ; (5) polish (particules, pulsation).

## Sources (URL)

- Widget Unreal "trailing damage" (Fab) : https://www.fab.com/listings/0ab7ee41-cdf5-4010-840f-0fd2e15c4742
- Boss Health Bar, Calamity Mod (rouge de dégâts récents, 0,5 s, états enrage/défense, d'après Metal Gear Rising) : https://calamitymod.wiki.gg/wiki/Boss_Health_Bar
- Barre de boss segmentée (Godot, barres empilées) : https://forum.godotengine.org/t/how-might-i-implement-a-segmented-health-bar-boss-phases/5845
- Devlog barre retard (jeu de combat, deux barres + timer) : https://elvenji.itch.io/deadline-fighter/devlog/957932/devlog-3-mejorando-enemigos-e-interfaz
- Mod RotVitals (ghost bar pâle + hit punch) : https://thunderstore.io/c/grain-rot/p/Mentalize/RotVitals/v/1.0.1/
- Options de visibilité et icônes de statut sous la barre (asset enemy bars) : https://www.fab.com/listings/1b1c325e-bc2b-4d4b-8ac6-8eb1cb8048ec
- Document de barre de vie en monde (statuts, effets sans icône) : https://astonishing-couch-d67.notion.site/In-World-Healthbar-Document-13004faa53928080998cdcb5b183c694
- Discussion lisibilité barre / effacement d'ennemis dans un clone survivor : https://itch.io/post/12264213
- Résumé clarté de barre de vie (affichage, chute animée, état critique) : https://bugnet.io/blog/how-to-implement-a-health-bar-that-communicates-clearly (page non vérifiable à la lecture directe ; à prendre avec prudence)
- Retour sur icônes de vie trop nombreuses (blog étudiant) : https://babel.speldesign.uu.se/2017/03/09/additions-to-the-gui/

Lacunes : pas de source primaire trouvée pour Hades, Diablo IV, PoE, Elden Ring, Darkest Dungeon, Monster Hunter, Hollow Knight, Dead Cells, LoL, Overwatch. Les timings de ce document sont des conventions à valider en jeu.
