# Fiche Google Play Console : Rainfall

Texte prêt à coller dans Play Console > Développer la présence sur le Play Store > Fiche principale du Store.
Limites Google : titre 30 caractères, description courte 80, description complète 4 000.
État du jeu au 28/10/2026 (version 0.1.2, tests internes). À relire avant la sortie : les chiffres de contenu évoluent.

## 1. Détails de l'application

**Nom de l'application** (8/30)
```
Rainfall
```

**Description courte** (79/80)
```
Survivor-like sombre : fauchez des hordes, empilez les objets, brisez les boss.
```

**Description complète**
```
La pluie n'a jamais cessé. Les terrasses ont sombré, la forêt s'est noyée de brume, la cité a rouillé jusqu'à l'os. Quelque part sous les eaux, la Source attend.

Rainfall est un survivor-like en vue isométrique, entre la frénésie des hordes et la profondeur des roguelites à objets. Déplacez-vous au pouce, votre premier sort tire tout seul : à vous de placer les trois autres, de lire le terrain et de survivre à une difficulté qui ne cesse de monter.

DES RUNS COURTES ET INTENSES
• 5 étages, environ 20 minutes par run, pause et reprise à tout moment.
• Plus vous traînez, plus le monde devient hostile : le bandeau de difficulté défile de Calme à Cataclysme.
• Achetez les coffres avec l'or des monstres, activez les piliers, puis affrontez le boss d'étage dans sa zone de charge.

10 PERSONNAGES, 10 FAÇONS DE JOUER
• Un mage de braises, une archère qui bande sa corde, un samouraï-arbre qui aiguise sa lame, un sonneur qui lance ses propres bras de cloche, un avare qui se bat avec son or…
• Chaque héros a un kit de 4 sorts conçus pour se répondre, et des variantes de sorts à débloquer en jouant.

48 OBJETS QUI S'EMPILENT
• Communs, rares, légendaires : chaque exemplaire renforce le précédent.
• Brûlure, poison, givre, ricochets, novas, échos : construisez un build que vous comprenez, puis poussez-le jusqu'à la démesure.

DES BOSS QUI SE MÉRITENT
• Plus de 15 boss d'étage, 20 mini-boss et un boss final en trois phases.
• Certains se combattent comme des boss de raid : boucliers à briser, abris où se cacher, zones à esquiver, points faibles à aller chercher.

UN MONDE PLUVIEUX ET VIVANT
• 4 biomes et leurs variantes : Terrasses noyées, Forêt-brume, Cité de rouille, Cryptes noyées, puis La Source.
• Éclairage dynamique, pluie, brume et ambiance sonore propres à chaque carte.

PROGRESSION ET DÉFIS
• Trois modes : Facile, Moyen, Difficile.
• Débloquez personnages, variantes de sorts, objets et skins « trophée » en terminant le mode Difficile.
• Meilleures runs enregistrées pour chaque personnage et chaque mode.

JOUABLE COMME VOUS VOULEZ
• Joystick flottant, sorts au toucher ou automatiques (option d'accessibilité).
• Manette prise en charge.
• Aucune puissance à vendre.
```

## 2. Éléments graphiques à fournir

Tous les visuels viennent de Codex / Blender (règle du projet) ; aucun n'existe encore au format Play Store.

| Élément | Format exigé | Proposition |
|---|---|---|
| Icône de l'application | 512 × 512 PNG 32 bits, 1 Mo max | Goutte de pluie émissive sur fond sombre, ou silhouette d'Ardent sous la pluie (même DA que l'icône Android du jeu) |
| Image de présentation | 1 024 × 500 JPG ou PNG 24 bits | Héros de dos face à un boss dans la pluie, titre « Rainfall » à gauche |
| Captures téléphone | 2 à 8, 16:9 paysage, côté de 320 à 3 840 px | 1920 × 1080 en jeu : horde + sorts, coffre ouvert, boss de raid avec bouclier, fiche de personnage, bandeau de difficulté en Cataclysme, écran de fin de run |
| Captures tablette 7" et 10" | facultatives (recommandées) | Mêmes scènes en 2560 × 1600 |
| Vidéo | facultative, lien YouTube | Bande-annonce de 30 s à faire plus tard |

## 3. Catégorisation

- **Type** : Jeu
- **Catégorie** : Action (alternative : Arcade)
- **Tags proposés** : Action, Roguelite, Hack and slash, Survie, Hors connexion, Solo, Fantasy sombre

## 4. Coordonnées

- **E-mail** : contact@peakdevelopment.fr
- **Site web** : facultatif
- **Règles de confidentialité** : page prête dans `docs/store/confidentialite.html`, à mettre en ligne (proposition : https://peakdevelopment.fr/rainfall/confidentialite.html) puis coller l'URL dans Play Console > Règles et programmes > Contenu de l'application > Règles de confidentialité.

## 5. Classification du contenu (questionnaire IARC)

Réponses à vérifier au moment de remplir le questionnaire :
- **Violence** : fantastique, contre des créatures non humaines, sans sang réaliste ni démembrement.
- **Peur / horreur** : thèmes sombres (cryptes, ossements, créatures), pas de contenu effrayant intense.
- **Langage grossier, sexualité, drogues, jeux d'argent** : non. Les coffres s'achètent avec l'or gagné en jeu, sans argent réel ni objet payant aléatoire.
- **Interactions entre utilisateurs, partage de position, achats numériques** : non pour l'instant.
- Classification attendue : PEGI 7 à 12.

## 6. Sécurité des données

État actuel du build Android : permission Internet désactivée (`game/export_presets.cfg`), aucune analyse ni publicité ni compte.
- **L'application collecte-t-elle ou partage-t-elle des données ?** Non.
- **Données chiffrées en transit** : sans objet.
- **Suppression des données** : la sauvegarde est locale à l'appareil (supprimée avec l'application).

À revoir dès que les publicités (relance de coffre) ou les achats (pass « Sans pub ») seront branchés : il faudra alors déclarer les identifiants publicitaires et les données d'achat, et réactiver la permission Internet.

## 7. Prix et public

- **Prix** : gratuit (mobile). La version PC est payante, hors Play Store.
- **Contient des annonces** : Non pour l'instant (à passer à Oui avec les pubs).
- **Achats intégrés** : Non pour l'instant.
- **Public cible** : 13 ans et plus (éviter la tranche « enfants », qui impose le programme Familles).
- **Pays** : France et pays francophones d'abord ; le jeu n'est qu'en français.

## 8. À faire avant la publication

1. Produire l'icône 512, l'image de présentation et les captures (lot Codex « store »).
2. Mettre en ligne `docs/store/confidentialite.html` et renseigner son URL.
3. Remettre les déblocages des personnages ouverts pour les tests, retirer le mode test et l'interrupteur des variantes (voir CLAUDE.md).
4. Vérifier le nom « Rainfall » sur le Play Store (homonymes possibles) ; repli : « Rainfall : La Source ».
5. Traduction anglaise pour élargir la fiche (facultatif).
