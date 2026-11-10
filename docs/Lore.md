# Lore de Rainfall : le monde, la pluie, le Semeur et les Porteurs

> Statut : **proposition de game design** (Fable, designer-fable, 08/11/2026), sur demande du joueur : *« imaginer un lore, par personnage et pour le jeu : pourquoi les personnages se battent et cherchent à tuer le Semeur de pluie, pourquoi le Semeur fait tomber de l'eau à vie »*.
> Rien n'est implémenté ; aucun fichier de `game/` ni de `data/` n'est modifié. Tout ce qui suit s'appuie sur ce qui existe déjà (noms, biomes, boss, mécaniques, skins, présages, épreuves, Forge) et l'explique ; là où un document antérieur contenait une amorce de lore (`Design_Boss_Cartes.md` §1, `Design_Etages.md` §3-4, `Design_Personnages.md`, `docs/fiches/*`, `Skins.md`, `data/cosmetics.json`), elle est reprise telle quelle et prolongée.
> Ton : mélancolique et sérieux, « une gravité tranquille à la façon d'un conte » (`Design_Boss_Cartes.md` §1). Aucune parodie. Aucun nom ni design repris de Risk of Rain ni de Vampire Survivors (GDD §13).
>
> **Décisions du joueur (09/11/2026)** :
> 1. Le pays s'appelle **le Val** (nom commun, jamais en titre).
> 2. Le Semeur de pluie est un **vengeur**, pas un gardien fidèle : il noie le Val **volontairement**, par rancune contre la Cité qui avait asséché le pays avec ses paratonnerres. Il reste sérieux et mélancolique ; sa vengeance a une logique que le joueur comprend (§1.3, §2). Révision du 09/11/2026 : §1.2-1.4, §2, §3, §4 (étage 3), §6 (introduction), §7, §11 (introduction, Rictus, Arpenteuse, Avare, Taliant, Grésille), §12 (propositions 2 et 7).
> 3. Le personnage électrique s'appelle **Grésille** (`docs/fiches/gresille.md`).
> 4. Déblocage de Grésille : « **Foudroyer 100 monstres avec l'Éclair en bouteille** ».
> Sommaire : 1. Le monde · 2. Le Semeur de pluie · 3. La Source · 4. Les biomes et leur chute · 5. Les monstres · 6. Les Appelés (boss d'étage) et leurs serviteurs (mini-boss) · 7. Noyaux d'orage et Forge · 8. Zones secrètes, gardiens, reliquaires · 9. Présages · 10. Épreuves · 11. Les Porteurs (fiches par personnage) · 12. Propositions d'intégration en jeu (chiffrées, rien d'implémenté).

---

## 1. Le monde

### 1.1 Avant la pluie : le Val et ses trois métiers

Le pays n'a pas de nom dans les textes du jeu ; ses habitants disaient **le Val**. Une longue vallée en gradins, fermée par des montagnes au nord, qui descend vers une **cité de fondeurs** bâtie sur un canal, et dont toute l'eau finit, sous la cité, dans une caverne que les anciens appelaient **la Source** : la résurgence d'où partaient les rivières.

Trois peuples y vivaient de l'eau, chacun à sa hauteur :

- **En haut, les Terrasses** : des rizières en gradins, des murets de pierre moussue, des norias de bois et de bronze, des écluses tenues par des automates-tocsins, des digues gardées par des tours de guet. Le peuple des Terrasses vivait des moussons : deux saisons de pluie par an, attendues, mesurées, redoutées. Il avait ses usuriers, ses barges de théâtre qui passaient d'écluse en écluse, ses chevaliers des roseaux qui chassaient dans les marais.
- **Au milieu, la Forêt de brume** : des cèdres géants aux racines en arche, des étangs noirs, des sanctuaires à lanternes où l'on venait prier pour que l'eau monte ou descende. Des bûcherons, des ermites, des sabreurs sans maître. La forêt poussait sur un sol de grès creux : personne ne savait qu'elle tenait au-dessus d'un gouffre.
- **En bas, la Cité** : des fonderies, des cuves, des passerelles, une cloche d'alerte de crue au-dessus du canal, des porteuses d'eau, des allumeurs de réverbères, des géomètres qui mesuraient chaque crue au pouce près. La Cité ne subissait pas l'eau : elle la **domptait**. C'est elle qui a forgé les **paratonnerres**.

### 1.2 Les paratonnerres : tenir le déluge à distance

Les orages du Val venaient de la montagne et éclataient au-dessus de la Cité, dont les cheminées appelaient la foudre. Les fondeurs ont trouvé la parade : des **mâts de bronze vert-de-gris**, plantés profond, qui **prenaient la foudre et la rendaient à la terre**. Puis ils ont compris que ce qui vide un nuage de sa foudre le vide aussi de sa pluie : un paratonnerre bien planté **tenait le déluge à distance** (`Design_Boss_Cartes.md` §1). La Cité en a semé partout, du canal jusqu'aux rizières les plus hautes : ce sont les **piliers** que le joueur recharge à chaque étage. Pendant un siècle, les orages ont contourné le Val. Les moussons sont devenues des averses. Puis des bruines.

La Source, elle, n'appartenait pas à la Cité. Un homme en avait la garde depuis bien avant les fondeurs : le **Fontainier**, dont la charge tenait en une phrase : *que le Val ait toujours assez d'eau, et jamais trop*. Chaque année, à la cote d'étiage, il descendait au bord du lac et gravait dans la roche la hauteur de l'eau : le **registre des cotes**, une ligne par an, le seul cadastre du Val plus vieux que la Cité. Pendant le siècle des paratonnerres, les lignes n'ont fait que descendre. Il est monté trois fois à la Cité avec ses relevés. Trois fois, les fondeurs ont mesuré le canal, l'ont trouvé plein (la Cité est en bas : elle boit la dernière, donc elle ne voit rien) et l'ont renvoyé à sa caverne.

Puis ils ont planté **le dernier mât, le plus profond, le paratonnerre-mère**, là où toute l'eau du Val se rassemble : **dans la Source même**, au milieu du lac, dans le seul lieu du Val qui n'était pas à eux. Celui-là ne protégeait pas une ville : il tenait le ciel entier à distance, pour que plus jamais un orage ne traverse les fonderies. Ils ne l'ont pas demandé au Fontainier. L'année suivante, il a gravé la cote la plus basse jamais relevée : **le fond**. Sous la ligne, trois mots : *la Source est tarie*. Il a monté le registre une quatrième fois. On lui a répondu que la Source n'était qu'un puits, et que le mât restait.

### 1.3 La Grande Crue : la nuit où tout a changé

Un siècle de paratonnerres avait asséché le Val par le haut. L'année sans mousson, les Terrasses sont descendues en file jusqu'à la Source boire le peu qui restait ; la Forêt a perdu ses derniers étangs ; la Cité a continué de boire au canal et de forger. Le Fontainier a recueilli dans une fiole **la dernière goutte** qui suintait de la roche, puis il a fait ce qu'aucun gardien n'avait jamais fait : avec les chaînes qui tenaient le mât dans la roche, il a **retourné le paratonnerre-mère**. Un mât qui repousse l'orage, planté à l'envers, **l'appelle**.

Il ne voulait pas une saison de pluie. Il voulait **rendre à la Cité, en une nuit, le siècle d'eau qu'elle avait tenu à distance** : toute l'eau du Val descend vers elle, il suffisait de la faire tomber. Il avait calculé une mousson pour les hauteurs et une noyade pour le bas. Il n'avait pas calculé qu'un mât-mère retourné n'a pas de « assez ». La pluie s'est mise à tomber sur tout le Val en même temps, si fort que les fusées de détresse des guetteuses se sont noyées en plein ciel (`docs/fiches/vigie.md`), que la Barge aux Lanternes s'est retournée dans son écluse (Rictus), que les tocsins se sont démontés eux-mêmes pour caler les vannes (Tocsin), que la Forêt a cédé sous son propre poids et s'est effondrée dans le gouffre qu'elle cachait (`Design_Etage2_Grotte.md`). C'est la **Grande Crue**, et ce sont les Terrasses et la Forêt, qu'il voulait sauver, qui sont mortes les premières. La Cité, elle, a tenu des semaines : elle avait les mâts.

Il l'a su tout de suite : toute l'eau du Val finit dans la Source, et l'eau de cette nuit-là lui a apporté des jarres d'offrande, des bras de tocsin, des lanternes de sanctuaire, bien avant le premier rivet de la Cité. Il pouvait lâcher les chaînes. Il ne l'a pas fait : **lâcher, c'était avoir noyé les Terrasses pour rien**. Il a tenu le mât retourné jusqu'à ce que la cloche de la Cité se taise, et la foudre qu'il avait appelée l'a trouvé les mains sur le bronze. Elle ne l'a pas tué. Elle l'a **soudé** à ce qu'il tenait.

### 1.4 Après : un monde qui coule vers le bas

Depuis, il pleut. Pas un déluge continu : la pluie du Val a des humeurs (bruine, averses, rideaux, orages : c'est la **jauge de difficulté**, Calme → Cataclysme), mais elle ne cesse jamais tout à fait, et toute cette eau descend : des Terrasses au Gouffre, du Gouffre au canal de la Cité, du canal aux Cryptes, des Cryptes à la Source, où elle nourrit l'orage qui la fait tomber. **Le Val est devenu une boucle d'eau**, et le Semeur en est le cœur.

Ce que l'eau stagnante garde trop longtemps, elle le rend changé : ce sont les monstres (§5). Ce que la foudre du Semeur a touché, elle l'a fait sien : ce sont les Appelés (§6). Les paratonnerres sont éteints, couverts de vert-de-gris, mais **ils tiennent debout** : du bronze de fonderie, planté profond, fait pour durer. Pour le Semeur, chaque mât encore debout est une main de la Cité restée sur le ciel ; **il pleuvra tant qu'il en restera un**. Les recharger les fait **tirer la foudre à nouveau**, un étage à la fois : c'est exactement le geste de la Cité, et c'est pour ça que le Semeur envoie ses Appelés les défendre, et que les piliers rayonnent en blanc froid quand ils sont chargés (`Design_Boss_Cartes.md` §1). Tout le jeu se lit ainsi : **le joueur redescend le chemin de l'eau en rallumant ce que la Cité avait planté, et celui qui noie le Val le prend pour la Cité qui revient**.

Les survivants se nomment eux-mêmes **les Porteurs** (succès « Tous les porteurs », `data/achievements.json`) : chacun porte une chose que la pluie n'a pas pu prendre : une braise, une amphore, une chaîne, une corde d'arc, un or, un sabre. C'est le roster.

---

## 2. Le Semeur de pluie

### 2.1 Qui il est

Le Fontainier, soudé au paratonnerre-mère par la foudre qu'il a appelée, et qui **n'a jamais lâché**. Une figure de **4,5 u**, encapuchonnée de **bronze noirci** (le bronze du mât), les bras devenus les **chaînes** avec lesquelles il a retourné le mât et le tient encore à l'envers, et dans la poitrine, à la place du cœur, **une goutte de cristal blanc** (`Design_Etages.md` §4) : la dernière goutte de la Source, celle de la fiole, l'année où la Cité l'a tarie. Il se souvient de tout, ligne par ligne : c'est un homme de registre. C'est ce qui le rend dangereux, et c'est ce qui le rend triste.

### 2.2 Pourquoi la pluie ne s'arrête jamais

Trois raisons, qui sont la même racontée trois fois :

1. **Le mât est à l'envers.** Un paratonnerre retourné appelle l'orage au lieu de le rendre à la terre ; il n'a pas de « assez ». Tant qu'il est planté, il appelle.
2. **La boucle se nourrit.** La pluie remplit la Source, la Source charge le mât, le mât appelle la pluie. Le Val tout entier est devenu le réservoir de son propre orage.
3. **Il n'a pas fini.** La Cité est noyée, mais ses mâts tiennent : du bronze planté profond, qui attend qu'on le polisse. Tant qu'un paratonnerre de la Cité est debout, la Cité n'est pas morte, elle est **en attente**. Il pleuvra sur le bronze jusqu'à ce que le dernier mât soit rendu à la terre en vert-de-gris. Il n'est pas fou et il ne jubile pas : il **tient un compte**, un siècle d'eau contre une nuit, et le compte n'est pas fermé.

### 2.3 Ce qu'il cherche

**Que plus un mât de la Cité ne tienne debout.** Il n'a pas d'armée et n'en veut pas : la pluie est patiente, et la rouille fait son travail. Il n'envoie ses Appelés que là où quelqu'un **recharge un paratonnerre** : à ses yeux, qui rallume un mât de la Cité est la Cité. C'est la tragédie des Porteurs : presque aucun d'eux n'est fondeur, la plupart sont des gens des Terrasses, de la Forêt ou des petits métiers du canal, les gens pour qui il a retourné le mât ; et il ne peut pas les voir autrement que comme la main qui revient sur le ciel. Quand le joueur arrive à la Source, il descend dans la colonne de pluie pour **voir qui est venu** (entrée de 2,2 s, `rain_sower_brain.gd`) : il regarde si c'est un fondeur. Ce n'en est jamais un. Il frappe quand même : lâcher maintenant, ce serait avoir noyé le Val pour rien.

### 2.4 Ses trois phases, racontées

Les phases reprennent les biomes traversés (`Design_Etages.md` §4) ; voici ce qu'elles disent de lui.

| Phase (PV) | Nom | Ce qu'il fait | Ce que ça raconte |
|---|---|---|---|
| 1 (100 → 70 %) | **Averse** | fouet de chaîne, cercles de pluie autour du joueur, vague en couloir | **La mousson qu'il devait aux hauteurs** : une averse de rizière, mesurée, qui tombe où on marche. C'est le Fontainier qui rend l'eau aux Terrasses, comme il l'avait calculé. Il sait encore arroser. |
| Transition « la crue monte » | | l'eau du bassin monte à 6 u autour du mât | La nuit où le calcul a cédé : la pluie n'a pas de « assez ». |
| 2 (70 → 35 %) | **Crue** | bassin infranchissable (noyade), anneau de brume qui ralentit les bords, débordements, vagues en éventail | **La vengeance elle-même** : la Cité prise par le canal et par le ciel, l'arène qui rétrécit comme la Cité s'est réduite à ses toits. C'est ce qu'il voulait ; on ne le voit pas s'en réjouir. |
| Transition « l'ancrage » | | il glisse jusqu'au mât, l'eau reflue vers lui, la foudre frappe le paratonnerre | Il retourne aux chaînes pour **tenir** le mât à l'envers quand la foudre descend, comme cette nuit-là. Il pouvait lâcher. Il ne lâche pas. |
| 3 (35 → 0 %) | **Orage** | ancré, immobile, +20 % de dégâts reçus ; quatre lignes en croix qui tournent, foudre sur le joueur toutes les 4 s, tourbillon de chaînes au contact, « Rafale » qui fait sauter la croix de 45° | **Ce qu'il est** : un homme qui tient un mât retourné contre le ciel, et contre quiconque viendrait le remettre à l'endroit. La croix est l'ombre des quatre chaînes. C'est sa fenêtre de faiblesse parce qu'on ne peut pas à la fois tenir et frapper : il a choisi de tenir. |
| Mort | | la pluie s'arrête ; éclair, rayons de lumière dans le puits | La goutte de cristal se brise. Le mât n'est plus tenu. Le ciel se vide une dernière fois, puis se tait. Succès « **La Source est tarie** » : les trois mots qu'il avait gravés sous la dernière cote, l'année du mât-mère. Le joueur les lui rend, au sens propre : l'eau redescend, la Source est à sec. |

**Mode sans fin** : « continuer » après sa mort, c'est constater que la pluie reprend : la Source n'était qu'une bouche ; l'eau revient par le haut, les paratonnerres s'éteignent à nouveau, et il faut redescendre. Le Semeur qu'on retrouve à l'étage 10 n'est pas ressuscité : **le mât a pris la rancune comme le bronze prend la charge, et il refait un Fontainier avec ce qu'il trouve**. Le jeu n'a pas besoin de le dire ; une ligne à l'écran de victoire suffit (§12).

---

## 3. La Source

Au fond des Cryptes, une caverne ouverte sur le ciel par un **puits vertical** : la pluie y tombe en **une seule colonne** au centre, sur un lac circulaire peu profond où le paratonnerre-mère est planté **la pointe en bas** (`Design_Etages.md` §4). Huit colonnes en cercle (les anciens contreforts du Fontainier), quatre chapelles en périphérie (ses réserves, où dorment les derniers coffres du Val : c'est le dernier marché).

Avant la Grande Crue, c'était un sanctuaire : on y descendait une fois l'an porter l'eau des trois peuples (une jarre des Terrasses, une lanterne de la Forêt, un seau de la Cité) pour qu'elle se mêle à la Source. Les dernières années, le seau de la Cité n'est plus descendu : elle avait le canal et les mâts, elle n'avait plus besoin d'une caverne. Le Fontainier a compté les années sans seau comme il comptait les cotes. Les skins « trophée de Difficile » (`Skins.md`) reprennent ce fil : **ce que chaque Porteur devient après avoir traversé la Source** : refondu, blanchi, verni, cuit. La Source transforme ce qui la traverse ; le Semeur en est la preuve, les skins en sont la version apaisée.

Le gros pilier de la Source est le mât lui-même : « **Appeler la Source** » (interaction) ne l'éteint pas : il le fait répondre.

---

## 4. Les biomes et leur chute

Chaque étage est un lieu du Val **au moment où la pluie l'a pris**, et le joueur les traverse dans l'ordre de l'eau : du haut vers le bas.

| Étage | Lieu | Avant | La chute | Ce qu'il reste (en jeu) |
|---|---|---|---|---|
| 1 | **Terrasses noyées** (variantes : Terrasses noyées, Rizières hautes) | rizières, norias, écluses, digues, tours de guet, barges de théâtre | La Grande Crue a noyé la vallée en une nuit. Les guetteuses n'ont pas pu donner le signal (Vigie). Les tocsins ont calé les vannes avec leurs bras. La Barge aux Lanternes a coulé. | Fin d'après-midi sous les nuages, bruine, bassins qui débordent à Hostile. La noria des Rizières hautes « repart » toute seule : l'eau est si haute qu'elle la pousse. Premier paratonnerre à recharger. |
| 2 | **Le Gouffre luisant** (variantes : Le Gouffre, Les Galeries noyées ; ids `foret_brume`, `foret_mangrove_lanternes`) | la Forêt de brume : cèdres, sanctuaires à lanternes, mangrove, étangs | Gorgée d'eau, la forêt s'est **effondrée dans le karst** qu'elle couvrait. Les cèdres pendent des voûtes par leurs racines mortes ; les lanternes des sanctuaires sont tombées au fond avec les prières. Dans les fissures, un **mycélium** violet s'est mis à luire : la seule vie qui a trouvé la chute à son goût. | Pas de pluie : des gouttes, de la poussière dans trois puits de jour, la rivière d'infiltration (l'eau des rizières qui descend). Le mycélium s'éteint par vagues à Furieux. |
| 3 | **Cité de rouille** (variantes : Cité de rouille, Fonderie du canal) | la Cité des fondeurs, le canal, la cloche d'alerte, les fonderies, les paratonnerres | La Cité a tenu le plus longtemps : elle avait les mâts. Mais c'est pour elle que la pluie avait été faite : l'eau est venue **par en dessous**, par le canal, et par en haut quand les mâts se sont éteints faute d'hommes pour les polir. La cloche a sonné des semaines. Les fonderies ont coulé leur dernier métal dans l'eau. | Crépuscule d'orage, lampes à vapeur orange, tonnerre : c'est **le seul étage où la foudre tombe encore** (le Sonneur, la Fonderie). Les paratonnerres sont nombreux et tous éteints. |
| 4 | **Cryptes noyées** (variantes : Cryptes noyées, Ossuaire des pluies) | les catacombes de la Cité : ossuaires, chapelles basses, galeries, cristaux de sel | **Là où toute l'eau finit.** Les morts de la Cité y reposaient au sec ; l'eau noire les a rejoints et les cristaux ont poussé sur les os. Plus de pluie : des gouttes, et une **crue lente** qui monte. | Sans soleil : la lumière vient des cristaux blanc-cyan et du joueur. Le silence avant la Source. Les cristaux « s'éteignent par vagues » à Furieux : la Source respire en dessous. |
| 5 | **La Source** | le sanctuaire du Fontainier | voir §2-3 | une arène, un mât, un homme qui n'en est plus un |

**Pourquoi les biomes gardent leur DA à chaque run** (décision du joueur, 21/10/2026, `Design_Etages.md`) : le Val n'a qu'une géographie. Deux variantes par étage = deux chemins dans le même lieu (la ruine centrale ou l'écluse, le Gouffre ou les Galeries). Le joueur apprend le Val comme on apprend un pays, pas comme on tire des cartes.

**La lumière** (`Direction_Lumiere_Ambiance.md`) : le joueur est **la seule source chaude** à l'écran (braise, lanterne, feu de camp du menu). C'est littéral dans le lore : la pluie a éteint tous les feux du Val sauf ceux que les Porteurs transportent.

---

## 5. Les monstres : ce que l'eau stagnante rend

Les créatures du Val sont « **nées de l'eau stagnante** » (`Design_Boss_Cartes.md` §1). Ce que la pluie noie et garde trop longtemps, elle le **rend** : pas ressuscité, **refait** avec ce qu'il y avait autour. C'est pour ça que les mêmes silhouettes reviennent à chaque étage dans une autre matière (variante « vase / mycélium / rouille / sel » proposée en P2, `Design_Etages.md` §5.6) : la même noyade, un autre fond.

| Tier | Nom de métier (lore) | Ce que c'est |
|---|---|---|
| 1 Essaim | **les Rendus** | les plus nombreux : ce que l'eau a pris en premier. Petits, vite, en bancs, comme les poissons des rizières. Ils ne haïssent pas : ils **coulent vers ce qui est chaud**. |
| 2 Tireur / Bondisseur | **les Cracheurs**, **les Sauteurs** | ce qui a appris à cracher l'eau qu'il a avalée ; ce qui a gardé les jambes des grenouilles et des chevreuils noyés. |
| 3 Brute | **les Engloutis** | ce qui a coulé lourd : bêtes de somme, gardiens de pierre, bûcherons. Le contour sombre de deux pixels autour de chaque monstre (`Design_Boss_Cartes.md` §1) est la ligne d'eau. |
| Élites | **les Marqués** | ceux que la foudre du Semeur a frôlés : **Brûlure** (la fonderie en eux), **Ralentissement** (le froid de l'eau noire), **Poison** (la stagnation). Un Marqué porte sa marque comme une aura : c'est la couleur de l'affixe. |

**Pourquoi ils lâchent de l'or** : les Rendus remontent avec ce qu'ils avaient : les pièces des noyés, les bagues, les boutons de cuivre. L'or du Val n'a plus de valeur que pour les Porteurs, qui s'en servent pour **payer les coffres**.

**Les coffres** : les caisses de secours du Val, scellées de bronze par la Cité « contre la crue », posées à chaque étage par le **Marchand de l'ombre** (événement de carte existant), un colporteur qui a traversé la Grande Crue en barque et vend depuis aux vivants ce que les morts ont laissé. Leur prix monte avec la pluie parce que **lui** sait qu'elle monte. (La relance gratuite d'un coffre est une faveur du Marchand ; la relance à l'or est son métier.) Le Sanctuaire de risque, l'Autel de fortune et le Coffre piégé sont les trois façons qu'avait le Val de prier pour l'eau : on y mise encore.

**Les élites qui portent la clé, les stèles de défi, l'autel de la pluie** (`Design_Zones_Secretes.md` §2) : des rites du Val restés armés.

---

## 6. Les Appelés : boss d'étage et mini-boss

La foudre du Semeur a **touché** ce qui tenait l'eau à chaque étage : la vanne, la lanterne, la cloche, la cloche de silence. Ce qu'elle a touché est devenu un **Appelé** : il porte l'ordre du Semeur, qui ne peut pas quitter ses chaînes (*qu'aucun mât de la Cité ne soit rallumé*), et il y met ce qui reste de son métier : il défend le paratonnerre de son étage comme il tenait l'eau. Il **laisse une trace au sol** en mourant (règle existante des boss) : sa dernière fonction, accomplie une dernière fois. Chaque Appelé lâche un **Noyau d'orage** (§7) : la foudre qui l'habitait. Les mini-boss sont leurs **serviteurs** : moins touchés, plus nombreux, réveillés par les rites des Épreuves (§10).

### 6.1 Étage 1 : Terrasses noyées

| | Nom (`id`) | Une ligne |
|---|---|---|
| Boss | **L'Éclusier** (`eclusier`) | Gardien de la grande vanne ; il l'a fermée la nuit de la Crue et n'a jamais rouvert la main. Sa trace : l'eau qu'il relâche enfin. |
| Boss | **Le Bouvier** (`ox_herder`) | Le buffle de pierre qui tirait les charrues des rizières, harnaché de bronze ; il laboure encore, en sillons d'eau. |
| Boss | **La Porteuse de jarres** (`jar_bearer`) | L'esprit de la lanterne de pierre où l'on déposait l'eau des offrandes ; elle porte six jarres qu'elle n'a jamais pu vider dans la Source. |
| Boss | **L'Idole noyée** (`drowned_idol`) | La statue du sanctuaire des Terrasses, celle à qui l'on demandait la pluie. Elle a été exaucée. Ses trois cloches sont les trois moussons qu'on lui promettait. |
| Mini | **Colosse de pierre** (`stone_colossus`) | Un gardien de muret descellé par l'eau ; il charge parce qu'il ne sait plus où était son mur. |
| Mini | **Ours de givre** (`frost_bear`) | Descendu de la montagne quand la neige a fondu sous la pluie ; il porte le froid d'en haut. |
| Mini | **Héron de fer** (`iron_heron`) | L'automate qui harponnait les carpes des bassins ; il n'y a plus que des Rendus à pêcher. |
| Mini | **Crapaud-cuve** (`vat_toad`) | Une cuve de teinturier noyée dans laquelle un crapaud a grandi ; le ventre bout toujours. |
| Mini | **Épouvantail faucheur** (`scarecrow_reaper`) | Le dernier épouvantail d'une rizière qui n'a plus de riz ; il fauche ce qui passe, corbeaux compris. |

### 6.2 Étage 2 : Le Gouffre luisant

| | Nom (`id`) | Une ligne |
|---|---|---|
| Boss | **Le Cerf-Lanterne** (`cerf`) | L'esprit de la forêt tombée ; ses bois portent les lanternes des sanctuaires engloutis, et les follets qui le suivent sont les prières qui n'ont pas été entendues. |
| Boss | **La Tisseuse** (`weaver`) | Une araignée-sanctuaire dont l'abdomen est la lanterne fêlée d'un autel ; elle retisse la forêt en fils, puisqu'il n'y a plus de branches. |
| Boss | **L'Ermite des racines** (`hermit_cedar`) | Le cèdre d'un ermite qui a refusé de partir ; l'arbre a gardé la lanterne et le refus. |
| Mini | **Reine du mycélium** (`bramble_queen`) | Ce qui a poussé en premier sur la forêt pourrie ; elle règne sur la seule chose vivante du Gouffre. |
| Mini | **Essaim-mère** (`brood_mother`) | Les ruches des cèdres, tombées avec eux ; elle soigne son essaim avec ce qu'il tue. |
| Mini | **Loup des gouffres** (`mist_wolf`) | La meute qui vivait sous la canopée ; elle chasse dans le noir avec les yeux des lanternes. |
| Mini | **Chouette-lanterne** (`lantern_owl`) | Nichée dans un sanctuaire ; elle a pris la lanterne pour des yeux. Elle craint la lumière des autres. |
| Mini | **Mante de lichen** (`moss_mantis`) | Les lames des bûcherons, sous le lichen ; elle attend comme attendaient les bûcherons. |

### 6.3 Étage 3 : Cité de rouille

| | Nom (`id`) | Une ligne |
|---|---|---|
| Boss | **Le Sonneur** (`sonneur`) | L'automate-cloche de l'alerte de crue ; il a sonné jusqu'à rouiller et ne sonne plus que la foudre : **c'est lui qui a appris aux Porteurs que l'orage avait un cœur**. Cousin de Tocsin, un siècle plus jeune. |
| Boss | **La Grue** (`crane`) | La grue du canal, qui déchargeait les barges ; elle décharge encore, des conteneurs vides, en spirale. |
| Boss | **Le Fondeur** (`smelter`) | L'automate-forge qui coulait le bronze des paratonnerres ; il coule du métal dans l'eau et l'orage le trempe. |
| Boss | **Le Canonnier de crue** (`flood_gunner`) | La batterie qui tirait des fusées de signal depuis les remparts du canal ; ses soutiers ont coulé avec lui et le rechargent encore. |
| Mini | **Seigneur des cendres** (`ash_lord`) | Le dernier feu de fonderie, debout. Référence de la DA : tout le Val a cette gueule-là. |
| Mini | **Archonte rouillé** (`rust_archon`) | Un magistrat de la Cité dans son armure de parade ; il juge encore, au perforant. |
| Mini | **Molosse à vapeur** (`steam_hound`) | Le chien de garde des fonderies, chaudière sur le dos ; il charge les murs comme il chargeait les voleurs. |
| Mini | **Le Rémouleur** (`grinder`) | L'automate qui affûtait les outils de la Cité ; plus on le frappe, plus il s'aiguise. |
| Mini | **Pompe aveugle** (`blind_pump`) | La pompe du canal, sans tête ; elle aspire là où l'eau était il y a une demi-seconde. |

### 6.4 Étage 4 : Cryptes noyées

| | Nom (`id`) | Une ligne |
|---|---|---|
| Boss | **Le Reclus** (`recluse`) | Le moine de silence des Cryptes, cristal dans la poitrine ; sa cloche coupe les sorts parce qu'elle coupait les voix. Il éteint les cristaux pour que les morts dorment. |
| Boss | **La Mère-Cristal** (`crystal_mother`) | Le sel de toutes les larmes de la Cité, cristallisé en silhouette ; elle réfracte la lumière parce qu'elle n'en a jamais eu. |
| Boss | **L'Anguille des profondeurs** (`deep_eel`) | Ce qui vit dans le lac des Cryptes depuis avant la Cité ; la crue est sa marée. Elle s'échoue parce que l'eau, pour une fois, redescend quand on la blesse. |
| Boss | **Le Roi de sel** (`salt_king`) | Le fondateur de la Cité, dans sa chapelle sèche qui tourne ; seule une pleine charge d'un Porteur le rompt, parce qu'il n'a jamais cédé à moins. |
| Mini | **Porte-ossuaire** (`ossuary_bearer`) | Un golem qui porte une niche de morts sur le dos ; il les réveille pour qu'ils le défendent. |
| Mini | **Nuée aveugle** (`blind_swarm`) | Les chauves-souris des voûtes ; leur cri brouille la minimap parce qu'il brouillait la nuit. |
| Mini | **Golem de sel** (`salt_golem`) | Un bloc de sel qui a pris forme ; l'eau peu profonde le dissout : c'est la seule chose des Cryptes que la pluie défait. |
| Mini | **Lanternier aveugle** (`blind_lamplighter`) | Le dernier allumeur des Cryptes ; sa lanterne de cristal éclaire pour les monstres, plus pour les vivants. Ardent le reconnaîtrait. |
| Mini | **Crabe-sarcophage** (`sarcophagus_crab`) | Un crabe des Cryptes qui a pris un sarcophage pour carapace ; il s'ouvre à 50 % et il y a quelqu'un dedans. |

### 6.5 Étage 5 : Le Semeur de pluie (`rain_sower`) : §2.

---

## 7. Noyaux d'orage et Forge

Un **Noyau d'orage** (`Design_Forge.md`) est ce qui reste d'un Appelé quand il tombe : la **charge que le Semeur avait mise en lui**, un caillot de foudre froide, gros comme un poing, qui grésille sous la pluie sans s'éteindre. Un par boss d'étage (étages 1-4), un de plus au fond du reliquaire des gardiens (§8) ; jamais au mini-boss (pas assez touché), jamais au Semeur (sa charge, c'est la pluie entière). On n'en porte pas plus de deux : **à trois, on brûle**.

La **Forge** est le geste des fondeurs retrouvé : avec un Noyau pour chaleur et deux objets pour matière, un Porteur **soude** ce que le Val n'a jamais fabriqué. Forger avec la foudre du Semeur, c'est retourner sa vengeance contre lui à la manière de la Cité, et c'est la seule chose du Val qu'il n'a pas inscrite dans son compte. Les six objets forgés racontent ce mariage :

| Objet forgé | Ce que c'est |
|---|---|
| **Mèche-silex** | une mèche de fusée de guetteuse trempée dans l'huile d'une fonderie : le critique qui met le feu |
| **Rosée figée** | la rosée des rizières saisie par le froid d'en haut : l'armure qui soigne au contact du gel |
| **Rouage de traque** | un rouage de tocsin monté sur un arc : le sort 1 qui remonte les recharges |
| **Sève rampante** | la sève de la Forêt tombée, qui va de mort en mort : le poison qui se propage |
| **Écorce de pluie** | l'écorce d'un cèdre qui a tenu : la barrière après le gros coup |
| **Prisme de grêle** | un cristal des Cryptes taillé par le Fondeur : la zone qui gèle |

« Un mort peut forger en coop » (décision du 06/11/2026) : en lore, le Noyau se forge **par la pensée du Porteur**, pas par ses mains ; un spectateur tient encore sa charge.

---

## 8. Zones secrètes, gardiens et reliquaires

Chaque carte du Val a une **salle scellée** (`Design_Zones_Secretes.md`, `Design_Variantes_B.md` §9-12) : une citerne, un cercle de brume, une salle des pompes, une chapelle basse. Ce sont les **caches des trois peuples** : là où l'on mettait à l'abri ce qui comptait quand l'eau montait. Deux plaques, une porte, deux gardiens, deux reliquaires. Un secret par run au plus, un sur trois : le Val ne livre pas ses caches à tout le monde.

**Les gardiens** sont nommés (barre de vie nommée) et vont **par deux** : ce sont les deux hommes laissés en garde devant chaque cache la nuit de la Crue, noyés sur place, **rendus** en brutes élites, et toujours à leur poste. Leurs noms sont ce qu'ils gardaient :

| Carte | Gardiens | Ce qu'ils étaient |
|---|---|---|
| Terrasses A | **Vase** et **Crue** | les deux éclusiers du bassin de vanne |
| Terrasses B | **Les Noyés** : *Orme* et *Aulne* | les deux gardes de la citerne, du nom des arbres de la digue |
| Gouffre A | **Mousse** et **Fougère** | les deux veilleurs du cercle de brume |
| Gouffre B | **Les Veilleurs** : *Lierre* et *Houx* | les gardiens du sanctuaire |
| Cité A | **Boulon** et **Chaudron** | les deux mécaniciens de la salle des pompes |
| Cité B | **Les Chaudronniers** : *Rivet* et *Soudure* | les deux ouvriers de la porte blindée |
| Cryptes A | **Algue** et **Nef** | les deux fossoyeurs de la chapelle basse |

Un **reliquaire** est un coffre dont la **chaîne est rompue** (lumière verte `#9CF0C8`) : la cache rendue à qui a su l'ouvrir. Il ne disparaît jamais, il ne donne jamais de Commun : ce qu'on cachait valait la peine. Le Noyau d'orage qu'on trouve à côté est celui du gardien le plus touché des deux.

---

## 9. Présages

À l'arrivée sur un étage (étages 2 à 5), un **présage** (`data/omens.json`, `Ateliers_Chiffres.md` §9) : la pluie a des humeurs, et le Val a toujours su les lire **dans les flaques**. Ce que le joueur voit, c'est ce que voyait une guetteuse : un signe, et ses conséquences.

| Présage | Lecture du Val |
|---|---|
| **Pluie de cendres** | les fonderies de la Cité brûlent encore quelque part ; tout frappe plus fort, le Val et les Porteurs |
| **Carapaces** | l'eau noire a durci ce qu'elle porte ; les gros monstres résistent, les Porteurs aussi |
| **Fièvre** | la nuit de la Crue, les survivants avaient la fièvre : on souffre plus, on agit plus vite |
| **Éveil des élites** | la foudre du Semeur a frôlé plus de monde que d'habitude : deux fois plus de Marqués |
| **Marché noir** | le Marchand de l'ombre a eu peur : tout est plus cher, sauf ce qui brille |
| **Offrande** | le Val fait un don : un reliquaire attend à l'arrivée, les monstres rendent moins |
| **Usure** | l'Appelé de l'étage n'a plus rien à donner ; les coffres sont moins chers pour compenser |
| **Marée** | l'eau monte : plus de Rendus, donc plus d'or et d'expérience |

---

## 10. Épreuves

Les **Épreuves** (`Design_Epreuves.md`, `data/epreuves.json`) remplacent les petits piliers : deux par étage, chacune réveille un mini-boss. En lore, ce sont **les gestes des anciens métiers**, refaits par un Porteur pour que l'eau se souvienne qu'on la tenait :

| Verbe | Étages | Le geste |
|---|---|---|
| **Escorte** (« Lancer la barque ») | Terrasses | mener la barque de la noria au bout de son canal, comme on menait le riz à l'écluse |
| **Rituel** (« Réveiller l'écluse », « Réveiller la pompe ») | Terrasses, Cité | fermer les vannes dans l'ordre, fermer les soupapes : l'ancien rite de la crue |
| **Poursuite** (« Réveiller le follet », « Éveiller l'éclat ») | Gouffre, Cryptes | suivre une lumière vivante de borne en borne, comme les ermites suivaient les follets jusqu'aux sanctuaires |
| **Veine** (« Suivre la veine », « Suivre l'eau noire ») | Gouffre, Cryptes | remonter la rivière d'infiltration ou l'eau noire dans un disque de lumière : le chemin de l'eau, à pied |
| **Tenue** (« Sonner la cloche ») | Cité | tenir la cloche d'alerte 40 s, ce que le Sonneur a fait jusqu'à rouiller |

Le mini-boss qui vient à la fin est le **serviteur** qui accomplissait ce geste avant la Crue. Un « parfait » vaut un rubis : le Val reconnaît un geste bien fait.

**Les rubis** (cosmétiques seulement, décision du 01/11/2026) : de la **résine de cèdre fossilisée par la foudre**, rouge, qu'on trouve dans tout le Val depuis la chute de la Forêt. Elle ne vaut rien pour se battre ; les Porteurs s'en servent pour **se souvenir** : tenues d'avant la pluie, traînées de pas, heures du jour qu'ils n'ont plus (`data/cosmetics.json` : « Nuit de lanternes », « Après-midi d'orage », « Canicule de cendres »…).

---

## 11. Les Porteurs

Dix fiches. Format commun : **origine · pourquoi la Source · son biome · les autres · le kit, c'est son histoire · une réplique**. Les amorces existantes (`Design_Personnages.md`, `docs/fiches/*`, descriptions de skins de `characters.json` et `cosmetics.json`) sont reprises mot pour mot quand elles existent ; le reste les prolonge.

Fil commun : aucun d'eux ne part « tuer le Semeur ». Ils partent chacun pour une raison plus petite, et la raison les mène tous **vers le bas**, parce que c'est là que va l'eau. Ce qu'ils savent du Semeur, ils l'ont appris en chemin : **le Sonneur**, qui sonne la foudre dans la Cité, leur a appris que l'orage avait un cœur ; **l'Arpenteuse**, qui mesure, leur a dit où il bat ; **Grésille**, qui a senti le mât tirer dans le mauvais sens, leur a dit pourquoi. Aucun d'eux ne conteste la rancune : les gens des Terrasses savaient depuis longtemps ce que les mâts leur coûtaient, et ceux de la Cité l'ont compris en coulant. Ce qu'ils contestent, c'est la sentence : on n'assèche pas un tort en noyant une vallée. Ils ne se connaissent pas tous ; en coop, ils se rencontrent.

### 11.1 Ardent, mage de feu (« le porteur de braise »)

- **Origine** : allumeur de réverbères de la Cité (skin « Allumeur de réverbères », `cosmetics.json`) : chaque soir, une perche de cuivre et une braise au bout, pour les lampes du canal. La nuit de la Crue, il a allumé les lampes quand même, une à une, pendant que l'eau montait, jusqu'à ce que la dernière s'éteigne sous lui. La braise de sa perche, elle, ne s'est pas éteinte : elle n'a plus jamais voulu. Il l'a mise dans sa main.
- **Pourquoi la Source** : il est le **porteur de braise** du pitch : la seule chaleur qui reste au Val. Il descend rallumer les paratonnerres parce que c'est son métier : allumer ce qui est éteint. Il ne hait pas le Semeur ; il veut rallumer la dernière lampe.
- **Son biome** : la Cité (étage 3), qu'il connaît lampe par lampe ; le Lanternier aveugle des Cryptes est ce qu'il serait devenu en restant.
- **Les autres** : il est le premier à être parti, et le seul que tous connaissent : on suit sa lumière. Tocsin l'appelle « la petite flamme » ; Averse le trouve imprudent ; Vigie tire au-dessus de lui.
- **Le kit, c'est son histoire** : l'Éclat de braise est la braise de la perche ; la Nova est la lampe qui s'allume d'un coup ; les Cendres, ce qu'une lampe laisse ; le Brasier, toutes les lampes du canal en même temps. Son esquive (« Éclat ») : il se disperse en braises et se reforme : il a appris la nuit de la Crue qu'une braise ne se noie pas si elle vole.
- **Réplique** : *« Une lampe à la fois. J'ai le temps : il pleut. »*

### 11.2 Rictus, pantin de la barge noyée

- **Origine** (`Design_Personnages.md` §2.6.1) : la *Barge aux Lanternes* donnait ses spectacles d'écluse en écluse sur les Terrasses ; la Crue l'a retournée, le Montreur a coulé avec ses pantins, les mains encore sur le croisillon. Un seul est remonté : Rictus, le clown de la pièce, la porcelaine fendue par les rochers. Mais ses fils ne sont jamais retombés : au-dessus de lui, dans la pluie, le Montreur continue de jouer.
- **Pourquoi la Source** : la pièce que jouait la Barge s'appelait *La Dernière Averse* : un vieux conte des Terrasses où un fontainier retourne un mât contre la ville qui a volé la pluie. Les rizières l'applaudissaient depuis des générations ; la Cité l'avait interdite sur le canal. Le Fontainier l'a jouée pour de vrai, et le conte n'avait jamais dit ce qu'il arrivait au village. Le Montreur veut **finir la représentation là où elle se passe**. Rictus, lui, ne veut rien : il est tiré. Personne ne sait si le pantin obéit au fantôme ou l'inverse.
- **Son biome** : les Terrasses (la barge gît dans l'écluse de la variante B, « Rizières hautes »).
- **Les autres** : Avare a assisté à la pièce et prétend qu'elle était mauvaise. Tocsin reconnaît la barge : il a ouvert l'écluse qui l'a retournée, et il l'ignore.
- **Le kit, c'est son histoire** : les Dagues sont les couteaux de la pièce ; l'Éventail, le numéro de lancer ; la Toupie, le Montreur qui le fait tourner ; les Doublures, les autres pantins, remontés pour trois secondes et qui éclatent parce que le bois pourri éclate. La Levée : le Montreur le soulève hors de l'eau, comme il aurait dû le faire cette nuit-là.
- **Réplique** : *« Le spectacle ne s'arrête pas. Il pleut sur la salle, c'est tout. »*

### 11.3 Tocsin, automate de crue

- **Origine** (`Design_Personnages.md` §1.1) : chaque écluse des Terrasses avait son tocsin : un automate de bronze au torse-chaudière, dont la tête est une cloche fêlée. Quand la crue montait, il sonnait, et quand les hommes ne sont plus venus, il s'est démonté lui-même pour caler les vannes avec ses propres bras. La pluie ne s'est jamais arrêtée ; lui non plus. Cousin du Sonneur de la Cité : même fonderie, un siècle d'écart.
- **Pourquoi la Source** : son foyer se nourrit de vase et d'ossements, et il sait, comme toute machine sait d'où vient son bronze, que **le mât de la Source est sorti de la même coulée que lui**. Il descend fermer la dernière vanne : il n'a jamais rien fait d'autre.
- **Son biome** : les Terrasses ; la Cité est sa fonderie natale.
- **Les autres** : il tient Ardent pour un apprenti ; il ne parle pas au Sonneur mais le reconnaît comme on reconnaît un frère devenu fou. Il ne lance jamais sa tête vers Rictus.
- **Le kit, c'est son histoire** : les Rivets sont sa chaudière qui crache ; les Bras-grappins ont calé des vannes toute une nuit ; les Coups de botte, ce qu'il a fait pour écarter l'eau ; la Tête-cloche, le dernier tocsin qu'il sonne avant de se refaire. Il se **reconstruit** rivet après rivet parce que le foyer n'a jamais eu l'ordre de s'arrêter.
- **Réplique** : *« Il manque un bras. Il manquera toujours un bras. Avance. »*

### 11.4 Averse, porteuse de pluie

- **Origine** : porteuse d'eau de la Cité (skin « Porteuse d'eau », `cosmetics.json` : robe de lin écru, amphore de verre soufflé) : avant la pluie, l'eau du canal ne montait pas aux étages, et les porteuses la portaient, amphore sur le dos. La nuit de la Crue, elle a continué : elle montait l'eau à des gens qui se noyaient. Depuis, l'amphore est de bronze et **se remplit toute seule** : la pluie la trouve.
- **Pourquoi la Source** : « **L'eau l'appelle, et elle s'y attarde** » (`characters.json`). Elle est la seule à ne pas descendre pour éteindre : elle descend **rendre l'eau**. L'amphore est pleine de la Crue ; elle veut la vider dans la Source d'où elle vient, puis repartir légère. La Crue, son ultime, est ce geste répété en chemin.
- **Son biome** : la Cité (le canal) ; les Cryptes, sans pluie, sont son étage dur : l'amphore ne se remplit que de ce qu'elle tue.
- **Les autres** : elle et Ardent se connaissaient : elle montait l'eau aux lampes qu'il allumait. Elle méprise Avare qui vend l'eau qu'elle portait. Elle tient Vigie pour une sœur : deux femmes qui ont fait leur travail la nuit où ça ne servait plus.
- **Le kit, c'est son histoire** : la Goutte-lame est l'eau du canal jetée au visage ; la Vague, l'amphore renversée d'un coup ; la Flaque-miroir, l'eau qu'elle pose pour qu'on s'y voie ; la Crue, tout ce qu'elle porte. **Plus l'amphore est pleine, plus elle est lente** : elle a porté l'eau toute sa vie, elle connaît le poids. Elle n'a aucune recharge : **l'eau est la seule limite**.
- **Réplique** : *« Je la remonte depuis toujours. Je vais la redescendre une fois. »*

### 11.5 Arpenteuse, géomètre de la Cité

- **Origine** : chef-géomètre de la Cité (skin « Cadastre » : uniforme, trépied, insigne). Son métier : mesurer les crues et tracer, à la chaîne d'arpenteur, les lignes où l'eau s'arrêterait. La nuit de la Crue, ses lignes ont été fausses pour la première fois. Elle a continué à mesurer pendant que la ville coulait ; sa chaîne de cuivre a pris la foudre d'un paratonnerre voisin et **ne refroidit plus**.
- **Pourquoi la Source** : elle est la seule à **avoir compris où va l'eau**. En mesurant, elle a vu que rien ne s'écoule hors du Val : tout descend sous la Cité. Elle veut aller **relever la cote de la Source** : si l'eau a un fond, elle a une fin. Elle ne croit pas au Semeur ; elle croit aux chiffres, et les chiffres mènent au même endroit. Elle sait aussi, par les archives du cadastre, qu'un gardien de la Source est monté quatre fois à la Cité avec des relevés que personne n'a lus : le registre des cotes est le seul cadastre plus vieux que le sien, et elle descend le lire. Elle sait déjà ce qu'il dit.
- **Son biome** : la Cité ; les Cryptes sont sous son cadastre.
- **Les autres** : c'est elle qui a dit aux autres où aller ; aucun ne l'a remerciée. Elle supporte Taliant, qui ne parle pas. Elle trouve Vigie inexacte (« à plus de 8 u » n'est pas une mesure).
- **Le kit, c'est son histoire** : la Chaîne derrière elle, c'est la chaîne d'arpenteur qui trace la ligne ; la Boucle, le polygone fermé qu'on relève ; le Piquet, le jalon ; le Tendeur, la chaîne qu'on tend d'un coup pour la lecture finale. Elle **ne blesse que ce qu'elle a parcouru** : on ne mesure que ce qu'on a arpenté.
- **Réplique** : *« L'eau descend. Tout descend. J'ai les relevés. »*

### 11.6 Rainette, chevalière des roseaux

- **Origine** : les chevaliers des roseaux étaient la garde des marais des Terrasses : des amphibiens longilignes en cuirasse de fer, qui bondissaient de butte en butte pour chasser ce qui montait des étangs. Quand la Crue est venue, il n'y a plus eu de buttes. Rainette est la dernière de son ordre, celle qui a appris à **sauter sur l'eau même**, ou par-dessus ce qui en sort.
- **Pourquoi la Source** : son ordre avait une devise : *on ne l'attrape pas* (son indice de déblocage). Elle descend parce qu'**un chevalier des roseaux ne laisse pas une chose dans l'eau** : et le Fontainier est dans l'eau depuis la Crue. Elle vient le sortir, d'une façon ou d'une autre.
- **Son biome** : les Terrasses ; elle est chez elle dans l'eau peu profonde de toutes les cartes.
- **Les autres** : elle protège Averse sans le lui dire. Elle et Bourbe sont les deux seules créatures du roster nées du Val et non de la Cité ; elles se comprennent sans mots.
- **Le kit, c'est son histoire** : la Langue est l'arme des marais ; le Grand saut, la charge de son ordre ; le Gluant, le crachat qui englue le gibier ; le Chant de crue, le chant que les chevaliers poussaient à la montée des eaux pour s'appeler. Elle **ne marche pas, elle saute** : il n'y a plus de sol sûr dans le Val.
- **Réplique** : *« L'eau n'a jamais rien gardé que j'aie voulu reprendre. »*

### 11.7 Avare, usurier des Terrasses

- **Origine** : l'usurier qui prêtait aux rizières entre deux moussons, et qu'on payait en or quand le riz rentrait. La nuit de la Crue, il a sauvé son coffre et rien d'autre ; le coffre est cerclé de fer et il le traîne au bout d'une chaîne parce que **l'or est la seule chose du Val que l'eau n'a pas changée**. Il saigne de l'or quand on le frappe : il a fini par en être fait.
- **Pourquoi la Source** : le Val lui **doit**. Toutes les Terrasses avaient une dette chez lui ; elles sont noyées. Il descend réclamer au seul débiteur qui reste : celui qui a tout noyé. Que le Semeur tienne lui aussi un compte (un siècle d'eau contre une nuit) ne l'impressionne pas : deux créanciers dans une vallée, c'est un de trop, et l'autre ne paie pas en or. « Elle ne dépense que contrainte » (indice, `characters.json`) : la contrainte, c'est le Semeur.
- **Son biome** : les Terrasses ; la Cité est son coffre-fort préféré (skin « Créancier »).
- **Les autres** : il méprise tout le monde et paie Rictus pour qu'il joue. Il est le seul à parler au Marchand de l'ombre d'égal à égal.
- **Le kit, c'est son histoire** : le Coup de coffre est l'usurier qui cogne ; la Poignée de pièces, l'or qu'il jette et va rechercher à quatre pattes ; la Rançon, la dette marquée ; la Faillite, tout l'or d'un coup, et la moitié qui retombe : il ne perd jamais tout.
- **Réplique** : *« On me doit une vallée. Je prends des acomptes. »*

### 11.8 Bourbe, mère-vase de la Mangrove

- **Origine** : avant la chute, la mangrove de la Forêt de brume avait sa gardienne : un golem de vase et de racines, cerclé de bronze par les ermites, qui gardait les étangs noirs et leur feu follet. Quand la Forêt est tombée dans le Gouffre, elle est tombée avec et s'est **reformée** au fond avec ce qu'il y avait : de la vase, des racines mortes, le même follet.
- **Pourquoi la Source** : elle ne descend pas : elle **remonte le courant à l'envers**. La vase de la Source est la sienne : c'est de là que les ermites l'ont tirée. Elle veut retrouver le fond d'où elle vient, et elle le cherche en se **divisant** : chaque motte est un morceau d'elle envoyé devant. « Ce qui s'est détaché frappe pour elle. »
- **Son biome** : le Gouffre luisant ; la variante B « Galeries noyées » est l'ancienne Mangrove des lanternes.
- **Les autres** : Taliant est né à côté d'elle, contre un cèdre qu'elle gardait ; elle le reconnaît à l'odeur de sève. Elle n'aime pas la chaleur d'Ardent, qui sèche la vase.
- **Le kit, c'est son histoire** : la Gifle de vase, la Mangrove qui se défend ; Détacher, une motte pour voir ; le Rappel, les mottes qui reviennent à la mère ; le Bourbier, elle qui redevient étang quatre secondes. **Ses familiers sont des morceaux d'elle** : sa barre de vie est son armée.
- **Réplique** : *« Je ne me perds pas. Je m'étale. »*

### 11.9 Vigie, guetteuse de la digue

- **Origine** (`docs/fiches/vigie.md`) : chaque digue des Terrasses avait sa tour de guet, et chaque tour sa vigie : une archère dont le seul travail était de tirer une fusée rouge quand l'eau montait. La nuit de la Grande Crue, il pleuvait si fort que ses fusées se sont noyées en plein ciel avant d'éclater. Personne n'a vu le signal. Elle a survécu sur le toit de sa tour, l'arc à la main, et trempe depuis ses pointes dans le magnésium des phares : **un feu que la pluie ne peut pas éteindre**.
- **Pourquoi la Source** : elle a vu la Crue venir **avant tout le monde** et n'a pas pu le dire. Elle descend pour **tirer le signal là où il sera vu** : dans le puits de la Source, sous les yeux de celui qui a fait monter l'eau. Plus personne ne manquera le signal : lui non plus.
- **Son biome** : les Terrasses ; elle éclaire la nuit des Cryptes et c'est là qu'on la suit à ses fusées.
- **Les autres** : Averse est sa sœur de garde. Elle a vu passer la Barge aux Lanternes la nuit de la Crue et n'a rien pu faire : elle évite Rictus. Elle s'arrête pour guetter ; Arpenteuse trouve ça inexact, Taliant trouve ça juste.
- **Le kit, c'est son histoire** : le Trait, le tir de guetteuse ; la Fusée de détresse, le signal qui éclaire enfin (et expose : ce qu'elle voit, les autres le frappent) ; le Filet lesté, le filet des pêcheurs de la digue ; la Grêle, la volée qu'on tirait au ciel pour appeler la tour voisine. Le **Guet** monte quand elle est **ancrée** : une vigie ne guette pas en courant.
- **Réplique** : *« Ce soir-là, la pluie a éteint mes fusées avant qu'elles éclatent. Plus jamais. »*

### 11.10 Taliant, rōnin d'écorce (id `morfil`)

- **Origine** (`docs/fiches/morfil.md`) : dans la Forêt de brume, avant la crue, un sabreur sans maître s'adossait chaque soir au même cèdre pour repasser sa lame sur une pierre à eau. Quand l'eau est montée, l'homme s'est noyé contre le tronc, le sabre encore en main. L'homme a pourri ; le sabre s'est enfoncé dans l'aubier, et l'arbre l'a gardé : son bras droit a poussé autour de la soie et la lame est devenue une branche. Le cèdre s'est levé. Il a gardé le chapeau, le hakama, la pierre à la ceinture, et l'habitude.
- **Pourquoi la Source** : un rōnin cherche un maître ou une fin. Il a entendu le Sonneur sonner la foudre et a compris qu'il y avait, au fond du Val, **quelqu'un qui n'a pas lâché** : un homme planté comme lui, qui tient son mât par volonté comme lui tient sa lame. Un rōnin sait ce que vaut une rancune tenue trop longtemps : une lame qu'on n'a jamais posée. Il descend lui proposer le duel que ni l'un ni l'autre n'a eu : « Un duel où presque rien ne passe » (son indice).
- **Son biome** : la Forêt de brume, c'est-à-dire le Gouffre ; les racines qui pendent des voûtes sont ses cousines.
- **Les autres** : il parle peu. Bourbe le reconnaît. Il respecte Vigie, qui s'arrête pour viser comme lui s'arrête pour aiguiser. Il ne comprend pas Rictus et n'essaie pas.
- **Le kit, c'est son histoire** : Taille et estoc, la lame qui s'use à chaque coup parce que **la pluie émousse tout** ; la Fauche-lune, le coup du sabreur ; l'Aiguisage, la pierre à eau de chaque soir ; les Lames jumelles, le second katana qui **pousse** dans la main gauche : il est un arbre, il bourgeonne. L'Iaï : le dégainé qu'il n'a pas eu le temps de faire la nuit de la Crue.
- **Réplique** : *« Le bois garde toujours un fil. Il suffit de s'arrêter. »*

### 11.11 Onzième Porteur : Grésille, la paratonnerrière (électricité)

Fiche complète : `docs/fiches/gresille.md` (nom et déblocage tranchés le 09/11/2026). Résumé de lore : la femme qui **entretenait les paratonnerres de la Cité** (grimper, polir, vérifier la mise à la terre), la seule du Val à avoir compris, la nuit de la Crue, que l'orage n'était pas venu : qu'il avait été **appelé**. Elle est, de tout le roster, celle que le Semeur a le plus de raisons de haïr : la main qui polissait les mâts. Elle le sait, elle ne conteste pas que la Cité a eu tort, et elle descend quand même **remettre le mât à l'endroit**, la foudre en bouteilles de Leyde dans le dos. Sa réplique : *« Un mât qu'on retourne appelle. Je sais aussi retourner. »*

---

## 12. Propositions d'intégration en jeu (chiffrées, rien d'implémenté)

Toutes sobres, compatibles mobile (texte court, aucune cinématique vidéo, tout « passable »), sans nouveau système lourd. Efforts en **jours-agent** (Sonnet pour le code, Codex pour les images). Les assets d'images restent soumis à la règle absolue : **rendus Blender par Codex**, jamais dessinés en code.

| # | Proposition | Où | Détail | Effort | Priorité |
|---|---|---|---|---|---|
| 1 | **Champ `lore` court par personnage** | fiche perso de l'écran Nouvelle run (`characters.json`) | 1 phrase d'origine + 1 phrase de motivation (≤ 240 caractères au total), sous le titre ; même police que `style`. Les 11 textes sont prêts (§11, « Origine » condensée + « Pourquoi la Source »). | **0,5 j** (champ JSON + un `Label` adaptatif, repli vide) | **1.0** |
| 2 | **Répliques de fin de run** | écran de victoire / défaite | 3 répliques par personnage et par issue (victoire, défaite, victoire en sans fin), tirées au sort, affichées sous le portrait en italique ; ≤ 90 caractères. 11 × 9 = 99 lignes (la réplique du §11 en est une). En défaite, 1 ligne sur 3 est **du Semeur** plutôt que du Porteur (même police, en gris) : « Un siècle d'eau contre une nuit. Le compte n'est pas fermé. » · « Je regarde qui vient. Jamais un fondeur. » · « Il reste des mâts debout. » | **1 j** (données `data/quotes.json` + affichage) | **1.0** |
| 3 | **Épitaphes des Appelés** | mort d'un boss d'étage (bandeau de nom existant, `BossBars`) | la ligne « Une ligne » du §6 s'affiche 3 s sous le nom au moment de la trace au sol ; rien pour les mini-boss. 16 textes prêts. | **0,5 j** (champ `epitaph` dans `floors.json` `boss_names` → dictionnaire, affichage) | **1.0** |
| 4 | **Tips de chargement « le Val »** | écran de chargement / début d'étage (`tips.json`) | 20 tips de lore d'une phrase (ex. « Les paratonnerres tenaient le déluge à distance. Ils sont éteints. ») mêlés aux tips de jeu, 1 sur 3. | **0,5 j** | **1.0** |
| 5 | **Intro texte + images fixes** | première run du profil, puis dans Réglages > Jeu > « Revoir l'intro » | 4 cartons (image 1920×1080 rendue par Codex + 2 lignes de texte chacun, fondu 0,6 s, 6 s par carton, « Passer » visible dès la 1re seconde) : (1) le Val et ses paratonnerres, (2) la Grande Crue, (3) le Fontainier retourne le mât, (4) les Porteurs descendent. Texte prêt (§1.2-1.4). | **2 j** code + **2 lots Codex** low (4 rendus, caméra iso, pas d'anim) | 1.0 si le quota Codex suit, sinon 1.1 |
| 6 | **Carnet des Porteurs (codex)** | menu principal, onglet à côté des Succès | entrées déverrouillées par : chaque boss d'étage tué (16), chaque mini-boss (20), chaque gardien de secret (14), chaque perso joué (11), la Source (1), un « parfait » d'épreuve par verbe (5) = **67 entrées**, chacune = nom + image existante (portrait / sprite idle) + 2-4 lignes du §6/§8/§11. Compteur « 23 / 67 » sur l'onglet. | **3 j** (écran liste + détail, `data/codex.json`, clés dans `Profile.objectives`, 67 textes issus de ce document) | 1.1 |
| 7 | **Écran de victoire narratif** | après la mort du Semeur | 3 cartons comme l'intro, 2 lignes chacun : (1) la goutte se brise : « La dernière goutte de la Source. Il l'avait gardée un siècle. » ; (2) la pluie s'arrête : « L'eau redescend. Pour la seconde fois, la Source est tarie. » ; (3) la lumière dans le puits : « Les mâts tiennent encore. Quelqu'un devra décider quoi en faire. » ; puis le choix « Terminer / Continuer ». En sans fin, un carton unique : « La pluie reprend. Le bronze n'oublie pas. » | **1 j** + **1 lot Codex** low (3 rendus) | 1.1 |
| 8 | **Noms de lore dans les textes existants** | partout où le jeu dit « monstres » | aucun changement de code : seulement relire `tips.json`, `achievements.json`, descriptions d'objets, pour glisser « les Rendus », « les Marqués », « les Appelés », « le Val » là où c'est naturel (10-20 chaînes). | **0,5 j** (Haiku) | 1.0 |
| 9 | **Stèles lisibles en jeu** | props « interagir » sur les cartes | une stèle par carte (8) avec un texte de 2 lignes dans une bulle ; immersif mais coûte un prop Codex par biome et une interaction qui concurrence le téléporteur. | 1,5 j + 1 lot Codex | **non recommandé v1** |

Recommandation : **1, 2, 3, 4, 8 dans la 1.0** (≈ 3 j-agent, zéro asset nouveau), **5 et 7** dès que deux lots Codex `low` sont disponibles (7 rendus fixes au total), **6** en 1.1 (c'est le seul qui demande un écran). Aucune de ces propositions ne touche aux fichiers partagés autrement que par des données JSON et un `Label`.

### Question au joueur (lore)

1. **Le sans fin** : « le mât refait un Fontainier » (une ligne à l'écran de victoire, proposition 7) ou ne rien expliquer ? **Reco : une ligne**, pas plus.

---

## Mode sans fin (proposition, à valider par le joueur)

> Proposition du 10/11/2026 ; rien d'implémenté. Si elle est validée, elle complète la note « Mode sans fin » du §2.4 et répond à la question ci-dessus. Mécanique de référence (`stage_manager.gd`, `floor_plan.gd`, `balance.gd`) : après le Semeur, « Continuer » enchaîne les étages 6-9 (biomes 1-4, **variante de carte opposée**), puis la Source à l'étage 10 avec le Semeur, et ainsi de suite sans nouveau choix de fin ; la difficulté ne redescend jamais ; Épreuves gardées aux étages 6-9 ; plus de présage ni de Marchand de l'ombre ; la run finit par la mort du Porteur (fin attendue après 2 à 4 étages, `Maths_Scaling.md` §11).

**Recommandation : « le compte rouvert ».** Le Semeur est tombé, mais le mât-mère est toujours planté la pointe en bas, et les paratonnerres que le Porteur a rechargés en descendant brillent maintenant dans tout le Val : pour le bronze qui a pris la rancune, c'est la Cité revenue, et la pluie reprend plus fort qu'avant. « Continuer », c'est remonter et redescendre par l'autre chemin pour rallumer les mâts qui restent, en croyant tenir le déluge à distance comme les fondeurs ; à la Source, le mât a refait un Fontainier avec ce qu'il a trouvé, et le compte ne se ferme plus. Le Porteur est devenu la Cité : c'est lui que la pluie finit par prendre.

Ce que la proposition explique sans rien changer au jeu :

- **variante opposée** : l'autre chemin du même lieu, donc d'autres mâts à rallumer ;
- **difficulté qui ne retombe pas** : chaque mât rallumé est une main de plus sur le ciel (§1.4) ;
- **Épreuves gardées** : les gestes des métiers sont à refaire, l'eau les a oubliés (§10) ;
- **plus de présage, plus de Marchand** : la pluie n'a plus d'humeurs à lire dans les flaques, elle monte ; le Marchand le sait et il est parti ;
- **pas de seconde victoire** : personne ne finit le sans fin, on y compte les étages tenus.

Texte en jeu : les cartons déjà proposés suffisent (§12, proposition 7) : « Les mâts tiennent encore. Quelqu'un devra décider quoi en faire. » avant le choix, puis « La pluie reprend. Le bronze n'oublie pas. » en sans fin.

Alternatives :

- **« Le bronze n'oublie pas »** (note actuelle du §2.4) : la Source n'était qu'une bouche, la pluie reprend d'elle-même et le mât refait un Fontainier ; rien n'est dit sur la cause, une ligne suffit.
- **« La décrue »** : la pluie s'est vraiment arrêtée et le sans fin suit le siècle d'eau qui redescend vers la Source à sec, où l'eau stagnante a **rendu** le Fontainier comme elle rend tout ce qu'elle a noyé (§5) ; plus doux, mais contredit la pluie qui tombe encore à l'écran aux étages 6 et suivants.
