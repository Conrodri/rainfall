# Variantes de sorts (design v1)

> Statut : **document de design** (game-designer, 23/10/2026) sur commande du joueur : « ajouter des sorts alternatifs pour tous les personnages ; la variante de l'auto se débloque en gagnant une run avec le personnage ; pour le reste je te laisse décider ». Rien n'est implémenté. Les chiffres sont des points de départ à passer au simulateur (`art/tools/night/balance_sim.py`, `balance_sim_run.tscn`) puis en playtest ; **systems-designer** valide les coefs avant tout code.
> Conventions : 1 u = 64 px ; « coef » = multiple de Dégât_base(L) (commun à tous les personnages) ; recharges en secondes avant `cooldown_mult` ; portées en u ; « boss » = mini-boss et boss d'étage. Les valeurs de base citées sont celles des kits (`game/scripts/spells/<id>_kit.gd`) après l'équilibrage du 22/10/2026, qui prévalent sur les fiches.

Sommaire : 1. Principes · 2. Variantes par personnage (10 × 4) · 3. Tableau récapitulatif et ordre d'implémentation · 4. Compteurs à suivre · Annexe A : JSON à fusionner dans `characters.json` · Annexe B : contrat de déblocage (`unlock_rule`).

---

## 1. Principes

1. **Une variante remplace le sort de son emplacement** (auto, sort 1 = `spell_2`, sort 2 = `spell_3`, ultime = `spell_4`). Jamais un 5ᵉ bouton : les trois plateformes gardent 3 boutons + joystick, et le HUD ne change pas.
2. **Choix avant la run**, sur la fiche du personnage (écran Nouvelle run → variantes → mode, GDD §5). Une variante verrouillée s'affiche grisée avec sa condition (visible) ; le choix est mémorisé par personnage dans le profil (`last_variants[<perso>]`, à ajouter à `Profile`). Pas de changement en cours de run (la sauvegarde de run stocke les 4 ids de sorts actifs, comme prévu au GDD §4).
3. **Même budget de puissance : side-grade, pas upgrade.** Chaque variante garde à ±10 % le coef/s théorique de son sort de base (voir la ligne « Budget » de chaque bloc) et **déplace** la puissance : portée ↔ zone, burst ↔ durée, contrôle ↔ mobilité, défense ↔ dégâts. Une variante qui domine le sort de base dans tous les scénarios est un bug (Sirlin) ; une variante dominée est un faux choix (autodétermination : autonomie). Les 4 variantes d'un personnage, prises ensemble, doivent dessiner **un second style de jeu cohérent** (ex. Ardent « au contact » plutôt que « kite »).
4. **Identité et ressource respectées.** La variante ne touche jamais à la ressource du kit (eau, chaîne, souffle, bourse, mottes, Tension, aiguisage, membres) autrement que par le sort remplacé ; elle en change l'usage, pas la règle. Les traits intégrés (garde du Montreur, garde du bretteur, coffre-bouclier, vase compacte, Surchauffe, Iaï, levée) restent, sauf mention explicite dans le bloc.
5. **Lisibilité** : télégraphe ≥ 0,8 s pour tout effet différé, aucune mort instantanée, un VFX par variante (produit par **Codex dans Blender**, cel-shadé, même accent émissif que le personnage ; les briefs ci-dessous sont des intentions, pas des specs d'asset). Sur mobile, le ciblage automatique (S5 : paquet le plus dense) s'applique aux variantes visées comme aux sorts de base.
6. **Déblocage** : l'auto = **« Gagner une run avec <perso> »** (règle du joueur). Les trois autres : conditions **visibles**, variées (compteur cumulé sur toutes les runs, record en une run, boss d'étage vaincu, étage atteint), calibrées pour tomber **en 3 à 10 runs** d'un joueur qui joue le personnage (une run ≈ 18-20 min, 600-1 200 kills), et mesurables avec les compteurs de la §4 (aucune nouvelle infrastructure lourde : un dictionnaire de compteurs par run, additionné dans `Profile.objectives`). Le raccourci en rubis du GDD §5 reste valable pour toute variante.
7. **Pas d'icônes ni de noms repris** de Risk of Rain ni de Vampire Survivors. Ardent : les 4 ids `roaming_embers`, `flame_pillar`, `meteor_rain`, `phoenix` sont déjà câblés (`ArdentKit.VARIANT_B_IDS`, `SPELL_LIGHTS`, `SPELL_VFX`, `ICON_NAMES`, ids audio `spell.<id>` dans `data/audio/sounds.json`) : **ils sont conservés tels quels** (exception assumée à la règle « id préfixé du perso », pour ne rien casser). Tous les autres ids sont préfixés (`rictus_…`, `tocsin_…`, `morfil_…` pour Taliant).

---

## 2. Variantes par personnage

Format de chaque bloc : **Nom** (remplace *Sort de base*) · *Description joueur* (≤ 110 caractères, texte de la fiche) · Mécanique · Budget (base → variante) · Lisibilité (Codex) · Déblocage.

### 2.1 Ardent, mage de feu — second style : « le brasier au contact »
Base : Éclat de braise 0,8 / 0,6 s, traverse 1, 9 u (≈ 1,33/s) · Nova ardente 2,5 / 6 s, 3,5 u (0,42/s) · Cendres 0,5 par 0,5 s pendant 5 s / 8 s, 2,5 u (5,0 par lancer, 0,63/s) · Brasier 8,0 / 20 s, 6 u (0,40/s). Les 4 variantes esquissées dans `characters.json` sont reprises et chiffrées.

- **Braises errantes** (remplace *Éclat de braise*, auto)
  - *Trois braises tournent autour d'Ardent et brûlent tout ce qu'elles frôlent.*
  - Mécanique : 3 orbes sur un cercle de **1,8 u** (+ `range_add` × 0,5), rotation 1 tour / 1,2 s (accélérée par la vitesse d'attaque : période = 1,2 / (1 + as)), chaque orbe inflige **coef 0,55** à tout monstre qu'il touche (rayon d'orbe 0,35 u + rayon du monstre), **immunité 0,4 s par monstre et par orbe**, proc 0,6, recul 0,15 u. Pas de projectile, pas de ciblage : il faut aller au contact. `item_pierce` sans effet (à signaler dans l'aide de Pointe perforante).
  - Budget : 1,33/s à 9 u → un monstre collé reçoit 3 orbes / 1,2 s × 0,55 ≈ **1,37/s**, mais à 1,8 u seulement ; en foule les 3 orbes touchent 3-6 cibles (meilleur en essaim, nul sur un tireur à 7 u).
  - Lisibilité : 3 sprites `ember_orb` (CREA 4 frames, 1 dir, accent braise #FF8C33) à `lift_px(0,4)` avec traînée courte ; l'anneau au sol n'est pas dessiné (les orbes suffisent). Son : crépitement continu bas, « tchak » à chaque touche.
  - Déblocage : **Gagner une run avec Ardent.**
- **Pilier de flamme** (remplace *Nova ardente*, sort 1)
  - *Une colonne de feu jaillit au point visé et brûle 2,5 s tout ce qui passe dedans.*
  - Mécanique : point visé ≤ **6 u** (mobile : paquet le plus dense), télégraphe 0,3 s (anneau au sol ; le pilier n'est pas un piège : il monte vite mais annonce sa place), puis colonne **rayon 1,2 u** (+ `zone_size_add`) pendant **2,5 s** : **coef 0,5 par 0,25 s** (10 ticks = 5,0 à une cible qui reste), proc 0,3, pas de recul (la colonne retient : ralentissement 30 % dedans). Recharge **6 s**.
  - Budget : 2,5 instantané sur 3,5 u autour de soi → 5,0 étalé sur 1,2 u au point visé ; réaliste ≈ 2,5-3,0 par lancer (les monstres traversent). Perte : la Nova est aussi une défense de contact (recul) ; gain : portée 6 u, Ardent peut le poser derrière lui en fuyant.
  - Lisibilité : `flame_pillar` déjà listé dans `ArdentKit.SPELL_VFX` (rayon 50 px, à re-rendre iso cel) ; lumière `flame_pillar` existante. Télégraphe : anneau braise 0,3 s + son `telegraph.warn_light`.
  - Déblocage : **Toucher 15 monstres d'un seul lancer de Nova ardente** (record en une run : `max_hits_one_cast:nova_ardente` ≥ 15 ; condition d'origine conservée, elle enseigne à attendre le paquet).
- **Pluie de météores** (remplace *Cendres*, sort 2)
  - *Cinq météores s'abattent en 2 s sur la zone visée ; chaque impact est annoncé au sol.*
  - Mécanique : zone visée ≤ **7 u**, disque de **3 u** ; 5 impacts tirés au hasard dans le disque (grille de 1 u, jamais deux sur la même case), un toutes les **0,4 s**, chacun télégraphié **0,8 s** (cercle au sol) puis **coef 1,0** dans **1 u** (+ `zone_size_add`), proc 0,8, recul 0,5 u. Recharge **8 s**. Boss : chaque impact touche ; un boss immobile en prend 2-3.
  - Budget : 5,0 par lancer en DoT persistant (Cendres, 5 s, zone de déni) → 5,0 en 5 bursts aléatoires (meilleur contre un paquet dense ou un boss lent, pire comme zone de déni : rien ne reste au sol).
  - Lisibilité : `meteor_impact` déjà listé dans `SPELL_VFX` (rayon 85 px) ; ajouter `meteor_fall` (CREA 4, trait de feu qui descend, 1 dir) et le cercle de télégraphe commun. Son : sifflement 0,8 s puis impact lourd (variante « lourde » du sort).
  - Déblocage : **Tuer 300 monstres avec Cendres** (`kills_by_spell:cendres` ≥ 300 ; conservée).
- **Phénix** (remplace *Brasier*, ultime)
  - *Un phénix de flammes combat 12 s aux côtés d'Ardent, puis explose en se consumant.*
  - Mécanique : familier volant (S10 ; réutilise `Decoy`/`BourbeMotte` : pool, ciblage, dégâts via `SpellCaster.deal_damage`) à `lift_px(1,2)`, **invulnérable** (il est en feu), vitesse 6 u/s, laisse à 8 u d'Ardent ; toutes les **1,5 s** il **pique** sur le paquet le plus dense à 8 u : ligne de 3 u × 1 u, **coef 1,0**, proc 0,7, brûlure 2 s (statut `burn` existant, coef 0,2/0,5 s). À **12 s** (ou à la mort d'Ardent) il se consume : explosion **rayon 3 u, coef 2,0**, proc 1,0. Recharge **20 s** (la recharge court dès l'invocation : 8 s sans phénix). Un seul phénix.
  - Budget : 8,0 instantané sur 6 u → 8 piqués × 1,0 + 2,0 = **10,0 étalés sur 12 s** et dispersés (≈ 8,0 utile) : le Brasier sauve d'un encerclement, le Phénix nettoie en continu et fait les procs d'items sur 12 s.
  - Lisibilité : `phoenix` (CREA 6 idle + 4 piqué, 8 dir, accent braise, traînée), ombre de contact au sol ; lumière `phoenix` existante. Seule chose en l'air avec Rainette et le Montreur. Son : cri bref au piqué, souffle à l'explosion.
  - Déblocage : **Vaincre le boss de l'étage 2 avec Ardent** (`boss_kill`, étage 2 ; conservée).

### 2.2 Rictus, pantin de la barge noyée — second style : « le Montreur joue à ta place »
Base : Dagues en demi-lune 0,8 / 0,6 s, 2,5 u 180° (1,33/s par cible dans l'arc) + garde −30 % 0,5 s · Éventail 5 × 1,6 / 6 s, couteaux plantés (+1 s de recharge chacun) · Toupie 0,7 × 10 ticks / 8 s, 2,2 u, roulade bloquée, vertige · Les Doublures 6 × 3,0 / 20 s, anneau 1,2 u, 3 s.

- **Main du Montreur** (remplace *Dagues en demi-lune*, auto)
  - *La main du fantôme claque au sol sur le paquet le plus dense à 4 u. Près de toi, elle te protège encore.*
  - Mécanique : toutes les 0,6 s, disque de **1,4 u** (+ `zone_size_add`) sur le paquet le plus dense à **4 u** (sinon l'ennemi le plus proche), **coef 0,8**, proc 0,8, recul 0,2 u. La **garde du Montreur** (−30 % 0,5 s) ne s'applique que si le claquement tombe à ≤ 1,5 u de Rictus : jouer à distance coûte la garde.
  - Budget : identique par cible (0,8 / 0,6 s), zone un peu plus petite (1,4 u disque ≈ 6,2 u² vs demi-disque 2,5 u ≈ 9,8 u²) mais portée 4 u : il frappe les tireurs T2 sans les toucher. Défense conditionnelle.
  - Lisibilité : main spectrale `montreur_hand_slam` (TOP 5, argent spectral #9FC8C0) qui descend du haut de l'écran (lift 1,4 → 0) ; les fils du `StringRig` se tendent vers le point d'impact 0,2 s. Son : claquement sourd + grelots.
  - Déblocage : **Gagner une run avec Rictus.**
- **Lame-pendule** (remplace *Éventail*, sort 1)
  - *Un couteau lourd au bout d'un fil : il part à 7 u et revient en tranchant tout sur la ligne.*
  - Mécanique : projectile `BOOMERANG` (S7, bras de Tocsin) : aller 7 u à 14 u/s, retour vers Rictus (position courante), **coef 2,5 à l'aller et 2,5 au retour** à tout monstre traversé (perce tout, 1 touche par passage), proc 0,8, recul 0,4 u. Recharge **6 s**. Rien n'est planté, rien à ramasser. Lançable pendant la Toupie (depuis le centre).
  - Budget : 5 × 1,6 = 8,0 dispersés (2-3 touchent une cible : 3,2-4,8) + jusqu'à −5 s de recharge en ramassant → **5,0 garantis** à tout ce qui est sur la ligne, sans ramassage. Style : le ramasseur de couteaux devient un tireur en ligne.
  - Lisibilité : `pendulum_knife` (CREA 4, pointe +X, tourne sur lui-même) + fil argent `Line2D` depuis la main du Montreur. Son : sifflement aller/retour, hauteur montante au retour.
  - Déblocage : **Ramasser 150 couteaux plantés** (`rictus_knives_picked` ≥ 150 ; ≈ 30-40 par run).
- **Pirouette** (remplace *Toupie*, sort 2)
  - *Un tour sur toi-même, bref et invulnérable : tout autour est frappé et repoussé. Pas de vertige.*
  - Mécanique : **0,6 s** de rotation, invulnérable, immobile (pas de glisse), **coef 4,0** dans **2,2 u** (+ `zone_size_add`) à la frame d'impact (0,3 s), proc 0,8, recul **1,0 u × masse**. **Roulade non bloquée**, **pas de vertige**, sort 1 non suspendu. Percute les doublures dans le rayon (l'étoile fonctionne : 1 fois par doublure). Recharge **8 s**.
  - Budget : 7,0 théoriques sur 2,5 s (réaliste ≈ 4,2 : les monstres glissent dehors) et 2,5 s d'engagement → **4,0 instantanés**, 0,6 s d'engagement. Perd l'immunité aux ralentissements et la vitesse ×1,2 ; gagne la liberté de roulade.
  - Lisibilité : `spin` (8 frames, 1 dir) jouée à ×4 ; `spin_blur` additif existant 0,3 s ; les fils claquent. Son : « fouet » court.
  - Déblocage : **Expédier 30 doublures avec la Toupie** (`rictus_doubles_launched` ≥ 30 ; une étoile complète = 6, soit 5 étoiles ; apprend le combo).
- **Rideau** (remplace *Les Doublures*, ultime)
  - *Six doublures en ligne devant toi forment un rideau 6 s : il attire, encaisse, puis explose.*
  - Mécanique : 6 doublures sur une **ligne perpendiculaire à la visée**, à 2 u devant Rictus, espacées de 1 u (positions dans un mur sautées), **dos à Rictus** (poussée vers l'avant) ; **6 s** de vie, **30 % des PV max** chacune, provocation 4 u (jamais les boss). Explosion à la mort ou à 6 s : **rayon 2 u, coef 2,5**, proc 1,0, recul 1 u × masse ; doublure tuée : 60 % (1,5). Percutées par la Toupie/Pirouette : toutes partent **dans la même direction** (la charge : 4 u, coef 1,0 par monstre traversé). Recharge **20 s**.
  - Budget : 6 × 3,0 = 18 dispersés en hexagone 3 s → 6 × 2,5 = **15 alignés 6 s** (chaque monstre en reçoit 1-2 : la ligne superpose moins que l'anneau). Style : défense à 360° → mur frontal pour tenir un couloir ou une porte de zone de charge.
  - Lisibilité : mêmes doublures (shader désaturé), un fil argent les relie en « rideau » ; télégraphe d'explosion : fissures `_e` qui s'allument 0,8 s avant 6 s. Son : grelots qui s'accélèrent.
  - Déblocage : **Atteindre l'étage 3 avec Rictus** (`floor_reached` 3).

### 2.3 Tocsin, automate de crue — second style : « le bélier à vapeur »
> **Mise à jour 23/10/2026 (retours du joueur).** Tocsin ne lance plus ses jambes. Slot 2 : *Bras-grappins* remplacé par le *Bras-pilier* (bras lancé au point visé, décharge électrique 5 s, rayon 2,2 u, puis ramassable). Slot 3 : *Coups de botte* remplacés par le *Coup de tocsin* (onde autour de lui, 3 u). Les variantes **Bras-harpon** (slot 2) et **Jambes-ressorts** (slot 3) sont **retirées** (code et déblocages `tocsin.imprisoned` / `tocsin.pushed` supprimés) ; restent **Vapeur** et **Tête-fumigène**. Les paragraphes Bras-harpon et Jambes-ressorts ci-dessous sont historiques.
Base : Rivets rougis 0,8 / 0,6 s, traverse 1, 8 u (5 sans tête), Surchauffe +12 % cadence par membre absent · Bras-grappins 2 ch. / 8 s, 1,8, couloir 7 u, prison 2,5 s (6 points) · Coups de botte 2 ch. / 9 s, 3,0, couloir 5 u, poussée 4 u × masse (×1,5 prison) · Tête-cloche 22 s, 12 (18 sur prisonniers, +30 % boss), 4 u.

- **Vapeur** (remplace *Rivets rougis*, auto)
  - *Le foyer crache un cône de vapeur brûlante à 3 u. Sans tête, la vapeur fuit par le cou tout autour.*
  - Mécanique : toutes les 0,6 s, cône **60°, 3 u** (+ `range_add` × 0,5) vers l'ennemi le plus proche, **coef 0,55** à tout monstre du cône, proc 0,6, recul 0,2 u, ralentissement 20 % 0,6 s (vapeur qui englue). Surchauffe inchangée (+12 % cadence par membre absent). **Sans tête** : le cône devient un **anneau 360° de 2 u** (même coef).
  - Budget : 0,8 traverse 1 à 8 u (1,33/s sur 1-2 cibles) → 0,55 / 0,6 s = 0,92/s par cible mais sur 3-8 cibles à 3 u. Tocsin perd son seul outil de portée : il doit se battre à 2-3 u, où ses paquets sont.
  - Lisibilité : `steam_cone` (TOP 5, cône blanc-orangé translucide, accent foyer), `steam_ring` (TOP 5) sans tête ; le foyer `_e` pulse à chaque bouffée. Son : « pschhh » court, grave si Surchauffe haute.
  - Déblocage : **Gagner une run avec Tocsin.**
- **Bras-harpon** (remplace *Bras-grappins*, sort 1)
  - *Le bras harponne le premier monstre touché, même un boss, et tire Tocsin jusqu'à lui.*
  - Mécanique : 2 charges / **8 s** ; tir droit **8 u** (5 u sans tête), 20 u/s, s'arrête au **premier monstre** (ou au mur) : **coef 1,8** à la cible, puis Tocsin est **tiré** vers elle (16 u/s, traverse les monstres, invulnérable au contact pendant le trajet, 0,5 s max) et s'arrête à 1 u ; à l'arrivée, **onde 1,5 u : recul 1 u × masse**, sans dégâts (il écarte le paquet). Le bras **reste planté sur la cible 2,5 s** (ralentie 40 %) puis tombe au sol : pickup qui rend la charge. **Fonctionne sur les boss** (le harpon tient, le boss n'est pas ralenti). Sans bras : les jambes restent bloquées (règle du kit).
  - Budget : 2 × 1,8 + emprisonnement de 6 points (annulation totale 2,5 s) → 2 × 1,8 + un déplacement de 8 u et une ouverture de paquet. Tocsin perd le meilleur contrôle de foule du roster et gagne la mobilité qui lui manque (cloche-pied compensé) et un vrai engagement de boss (Tête-cloche posée au contact).
  - Lisibilité : `arm_fly` existant + câble `Line2D` bronze depuis l'épaule ; Tocsin glisse en `handwalk`/`walk` figé, étincelles au sol. Son : « clang » d'accroche, treuil qui siffle.
  - Déblocage : **Emprisonner 400 monstres avec les Bras-grappins** (`tocsin_imprisoned` ≥ 400 ; ≈ 60-100 par run).
- **Jambes-ressorts** (remplace *Coups de botte*, sort 2)
  - *La jambe te propulse : saute jusqu'à 5 u et écrase l'atterrissage. La jambe reste au point de départ.*
  - Mécanique : 2 charges / **9 s**, **ne demande pas de bras** (il se détend sur la jambe) ; saut `LOB` 0,5 s vers le point visé ≤ **5 u** (4 u sans tête), invulnérable au contact en l'air, atterrissage : **rayon 2 u (+ `zone_size_add`), coef 3,0**, proc 1,0, **poussée radiale 2 u × masse** (×1,5 et libération sur les emprisonnés : la boule de quilles en étoile). La **jambe reste au point de décollage** (pickup, délai 0,8 s) ; état de locomotion ensuite selon la table §1.4 de la fiche.
  - Budget : couloir 5 u × 1,5 u à 3,0 + poussée 4 u linéaire → disque 2 u à 3,0 + poussée 2 u radiale + un saut de 5 u. Perd la portée de poussée (le couloir vide une ligne) ; gagne un déplacement et l'atterrissage sur un paquet emprisonné. Attention : sauter loin d'une jambe qu'on veut ramasser.
  - Lisibilité : `leg_fly` existant inversé (la jambe reste, le corps vole) ; arc via `Iso.lift_px`, ombre de contact ; `stomp_ring` (TOP 5) à l'atterrissage, secousse 8 px. Son : ressort comprimé, choc de fonte.
  - Déblocage : **Pousser 300 monstres avec les Coups de botte** (`tocsin_pushed` ≥ 300 ; 1 par monstre et par botte).
- **Tête-fumigène** (remplace *Tête-cloche*, ultime)
  - *La tête tinte 5 s là où elle tombe : tout autour est étourdi puis ralenti et brûlé par la fumée.*
  - Mécanique : lob **6 u** (0,9 s, arc, ombre), tintement 0,3 s, puis la tête **reste au sol 5 s** : à l'arrivée, **étourdissement 1 s** (`imprisoned` ; boss : ralentissement 40 %) dans **4 u** (+ `zone_size_add`) ; pendant 5 s, zone **coef 1,5 par 0,5 s** (10 ticks = 15), proc 0,3, ralentissement 50 % rafraîchi, **+50 % sur les emprisonnés** (ils restent dedans). Recharge **22 s** ; Tocsin est **sans tête 5 s de plus** que d'habitude (portées réduites, vignette), la tête repousse à la fin de la recharge comme aujourd'hui.
  - Budget : 12 instantané (18 prison, +30 % boss) → 15 étalés (22,5 prison), sans le bonus boss. Burst lisible et sûr → zone de contrôle de 5 s qui tient un paquet entier ; moins bon contre un boss qui en sort.
  - Lisibilité : `head_fly` existant, `head_smoke_zone` (TOP 8 en boucle + `end` 4, fumée orangée basse, accent foyer) ; télégraphe = tintement + anneau de repli existants. Son : cloche qui tinte toutes les 1 s, sifflement de vapeur.
  - Déblocage : **Vaincre un boss d'étage avec Tocsin pendant qu'il est sans tête** (`tocsin_headless_boss_kills` ≥ 1 : la Tête-cloche lancée sur le boss suffit si le boss meurt dans les 22 s).

### 2.4 Averse, porteuse de pluie — second style : « la pluie qui tient »
Base (refonte « l'eau est la seule limite ») : Goutte-lame 0,75 + 0,4 × eau/100 / 0,6 s, traverse 1, 9 u, +0,5 eau par touche (+2 élite/boss) · Vague 20 d'eau, sans recharge, cône 5 u 60°, 3,5, recul 1,5 u, trempe 4 s · Flaque-miroir 18 d'eau / 5 s, 2,5 u, 0,5 par 0,5 s pendant 6 s, +4 eau/s dedans, 2 max · Crue toute l'eau (min 40), 15 × (eau/100)^1,5, rayon 4 + 0,02 × eau.

- **Bruine** (remplace *Goutte-lame*, auto)
  - *Trois gouttes en éventail à 7 u : moins précises, plus de monstres touchés et plus d'eau rendue en foule.*
  - Mécanique : toutes les 0,6 s, **3 projectiles** en éventail de 30° vers l'ennemi le plus proche, **7 u**, 13 u/s, **sans traversée**, **coef 0,30 + 0,15 × eau/100** chacun (figé au tir), proc 0,6 ; **+0,5 d'eau par goutte qui touche**, plafonné à **+1,0 par salve** (+2 sur élite/boss, une fois par salve). Impact frame 3 (`attack`).
  - Budget : 0,75-1,15 traverse 1 à 9 u → 0,90-1,35 si les 3 touchent (au contact ou en paquet), 0,30-0,45 à distance sur un monstre isolé ; eau : ×2 en foule, ×1 en cible unique. Averse « foule et contact » plutôt que « ligne et portée ».
  - Lisibilité : `droplet_small` (CREA 3, cyan #5FD4E8) ×3 ; `+N` cyan flottants existants. Son : trois gouttes rapprochées, hauteur selon le remplissage.
  - Déblocage : **Gagner une run avec Averse.**
- **Geyser** (remplace *Vague*, sort 1)
  - *20 d'eau : un geyser jaillit sous le point visé, projette les monstres en l'air 0,8 s et les trempe.*
  - Mécanique : coût **20 d'eau** (× économie des objets de recharge), **sans recharge** (verrou anti-spam 0,25 s de la refonte), point visé ≤ **6 u** (mobile : paquet le plus dense), télégraphe **0,3 s** (bouillonnement au sol) puis **rayon 2 u** (+ `zone_size_add`) : **coef 3,5**, proc 1,0, **projection en l'air 0,8 s** (`imprisoned` + `lift_px` 1,0 ; boss : ralentissement 40 % 1 s), **trempe 4 s**, aucun recul. Règle « à sec » inchangée.
  - Budget : cône 5 u 60° (≈ 13 u²) 3,5 + recul 1,5 u (kite) → disque 2 u (≈ 12,6 u²) 3,5 + 0,8 s de maintien en l'air, à 6 u. La Vague repousse (défense), le Geyser **fixe** (prépare une Flaque ou une Crue pleine).
  - Lisibilité : `geyser` (TOP 6 : bouillon puis colonne d'eau, additif, cyan) ; les monstres montent avec leur ombre de contact (lisible : ils flottent). Son : « bloup » puis jet.
  - Déblocage : **Tremper 1 000 monstres** (`averse_soaked` ≥ 1 000 ; Vague, Flaque et Crue comptent, un monstre par application).
- **Gouttière** (remplace *Flaque-miroir*, sort 2)
  - *18 d'eau : un ruisseau de 6 u coule devant toi 6 s ; il ronge les monstres et te porte plus vite.*
  - Mécanique : coût **18 d'eau**, recharge **5 s** (conservée : anti-spam), ligne de **6 u × 1 u** depuis Averse vers le point visé (mobile : vers le paquet le plus dense), **6 s** : **coef 0,5 par 0,5 s** aux monstres dessus, proc 0,3, trempe rafraîchie ; Averse dessus : **+4 d'eau/s** et **vitesse +25 %** (le courant la porte, même amphore pleine : 3,4 → 4,25 u/s). **2 gouttières max** (la plus ancienne s'assèche). Rayon de pose : l'origine est Averse elle-même.
  - Budget : disque 2,5 u (19,6 u²) → ligne 6 u² ; même DoT, même gain d'eau, mais la zone est un **chemin** : couloir de fuite rapide et de ravitaillement plutôt qu'un point de camp.
  - Lisibilité : `rivulet_tile` (TOP 4 frames en boucle, bande 1 u, défilement d'UV façon chaîne d'Arpenteuse, shader `averse_rivulet`), éclaboussures aux pieds d'Averse. Son : ruissellement en boucle.
  - Déblocage : **Récupérer 1 500 d'eau dans tes Flaques-miroir** (`averse_puddle_water` ≥ 1 500 ; ≈ 200-400 par run).
- **Mousson** (remplace *Crue*, ultime)
  - *Vide l'amphore : 6 s de déluge qui te suit, trempe et ronge ; l'amphore se remplit sous l'averse.*
  - Mécanique : coût **toute l'eau (min 40)**, sans recharge, immédiat : zone **rayon 5 u** (+ `zone_size_add`) **attachée à Averse** pendant **6 s** : dégâts totaux **15 × (eau/100)^1,5** répartis en **12 ticks de 0,5 s** (40 → 0,32/tick ; 100 → 1,25/tick), proc 0,3, **trempe** rafraîchie, ralentissement 30 % ; pendant 6 s, **+3 d'eau/s** (il pleut à verse : 18 d'eau rendus) ; Averse est à 4,4 u/s dès le lancement (amphore vide). Pas de recul.
  - Budget : même formule de dégâts, instantanée sur 4-6 u avec recul 3 u → étalée sur 6 s sur 5 u mobile, sans recul, + 18 d'eau. La Crue sauve d'un encerclement et laisse une Flaque ; la Mousson accompagne une course et relance l'économie (18 d'eau ≈ une Vague). À vérifier par systems-designer : le remboursement ne doit pas permettre Mousson → Mousson en boucle (à 100 d'eau, elle gagne 18 + pluie ≈ 30 en 6 s : il faut ~25 s de plus pour revenir à 100 ; acceptable).
  - Lisibilité : `monsoon_zone` (TOP 8 en boucle + `end` 4 : rideau de pluie dense, cyan, additif), lumière `averse_crue` prolongée 6 s, pluie d'ambiance ×2 dans la zone. Son : déluge continu, grondement bas.
  - Déblocage : **Lancer 5 Crues à 100 d'eau** (`averse_full_crues` ≥ 5 ; lancée à ≥ 99 d'eau).

### 2.5 Arpenteuse, géomètre de la Cité — second style : « la chaîne qui reste »
Base (24/10/2026, après le rework du Halage) : Chaîne 14 u de traîne, 1,0 par 0,5 s, ralentissement 35 %, rembobinage 4 u/s immobile · Halage (ex-Boucle) 6 s, 3,5 dans une bande de 1,2 u le long de TOUTE la chaîne posée (traîne, ligne du piquet, ligne A-B des Jalons), attraction 1,5 u, rien n'est consommé (≥ 3 u de chaîne posée) · Piquet 8 s, 6 u, ligne piquet→elle 5 s, 1,0 par passage (immunité 0,5 s) · Tendeur 20 s, 10 à 1 u de la chaîne et de la ligne, traîne les monstres jusqu'à elle et les emprisonne 1,5 s (plus de rembobinage : chaîne et piquet restent) ; +40 % des sorts 2-4 sur élites et boss.

Adaptations du 26/10/2026 (le doc d'origine supposait la Boucle consommatrice et le Tendeur rembobinant) :
- La *Boucle* s'appelle désormais *Halage* ; le déblocage du Nœud compte les monstres frappés par le Halage de base (compteur `arpenteuse.boucle_hits` ≥ 500), celui des Jalons les coups de ligne du Piquet de base (`arpenteuse.piquet_hits` ≥ 800).
- Le Halage de base n'exige plus d'encercler ni ne consomme la chaîne ; le Nœud garde donc sa propre règle : il **consomme** 4 u de queue (c'est son coût), là où le Halage ne coûte rien. Son auto-cast attend 2 monstres dans le disque (1 si élite ou boss), comme le Halage sur sa bande.
- Le Cerceau n'a plus de rembobinage à éviter : la chaîne « retombe pleine » = elle est prolongée droit derrière sa queue jusqu'à 14 u (7 u avec la Chaîne lestée) à la fin de l'anneau, et le touret attend 0,6 s avant de rembobiner.
- Le Tendeur de base ne rembobine plus ; la comparaison « burst + chaîne rendue » du Cerceau se lit donc : 10 instantanés + emprisonnement 1,5 s → 8 × 1,15 = 9,2 étalés sur 4 s en barrière.
- Le Piquet de base reste mobile (la ligne suit la joueuse) ; les Jalons deviennent une clôture fixe. Le Tendeur claque sur la ligne A-B comme sur celle du piquet.
- Correctif prioritaire du 26/10 : avec la chaîne attachée au poteau (Piquet planté), le Halage frappe aussi la ligne poteau→joueuse et se lance même si la traîne a été rembobinée (`tests/arpenteuse_peg_test`).

- **Chaîne lestée** (remplace *Chaîne*, auto)
  - *7 u de chaîne seulement, mais deux fois plus lourde : elle brûle plus fort et englue ce qui la touche.*
  - Mécanique : traîne de **7 u** (points tous les 0,25 u), **coef 2,0 par 0,5 s**, proc 0,3, **ralentissement 50 %** 0,6 s, demi-largeur 0,3 u ; immobile > 0,6 s : rembobinage **8 u/s**. Ressource = longueur / 7 (seuils du Halage 3 u, du Nœud 4 u et du Tendeur 2 u inchangés : le Halage revient en 0,75 s de course au lieu de 3,5 s).
  - Budget : 14 u × 1,0 = 14 « coef-u » → 7 u × 2,0 = 14. Même puissance totale, deux fois plus dense et deux fois plus courte : boucles petites mais rapides, moins de surface de piège, meilleure défense rapprochée (ce qui la suit s'englue à 50 %). Simulateur : ×1,03 de la Chaîne.
  - Lisibilité : même `Line2D` TILE, bande **1,1 u**, maillons plus gros (`arpenteuse_chain_heavy` : texture 1 tuile), émission 3,2. Son : traînement plus grave.
  - Déblocage : **Gagner une run avec Arpenteuse.**
- **Nœud** (remplace *Halage*, sort 2)
  - *Les 4 derniers u de chaîne se nouent sur place : tout ce qui est pris dans le nœud flambe et reste coincé 1 s.*
  - Mécanique : recharge **6 s**, exige **≥ 4 u** de traîne ; la **queue** (les 4 u les plus anciens) se resserre en **0,25 s** autour de son centroïde : disque **2 u** (+ `zone_size_add`) : **coef 3,5**, proc 1,0, **`imprisoned` 1 s** (boss : ralentissement 40 %), pas d'attraction. **Seuls 4 u sont consommés** (la chaîne repousse de 4 u : 1 s de course). Aucune visée : le nœud est toujours là où elle était il y a 10-14 u (3-7 u avec la Chaîne lestée).
  - Budget : bande de 1,2 u le long de toute la chaîne + attraction, rien de consommé → disque fixe 2 u à la queue, 3,5 + 1 s d'emprisonnement, 4 u consommés. Le Halage frappe ce qui est proche de la chaîne ; le Nœud fait de la chaîne une **tourelle arrière** : courir droit et nouer ce qui suit. Simulateur : ×0,95 du Halage (×0,89 en cible unique).
  - Lisibilité : `chain_knot` (TOP 6 : maillons qui se resserrent puis flambent, cuivre #FF7A1F), lumière `arpenteuse_blaze`. Son : cliquetis rapide puis claquement. Placeholder : la `Line2D` de la queue qui se resserre + le `loop_blaze` existant.
  - Déblocage : **Frapper 500 monstres avec le Halage** (`arpenteuse.boucle_hits` ≥ 500).
- **Jalons** (remplace *Piquet*, sort 3)
  - *Deux piquets plantés coup sur coup tendent un fil fixe de 8 u pendant 6 s : la clôture balaie sans toi.*
  - Mécanique : 1ʳᵉ pression : piquet A au point visé ≤ **6 u** (mobile : paquet le plus dense) ; 2ᵉ pression dans les **3 s** (acceptée après 0,6 s) : piquet B ≤ **8 u de A** (sans visée : à 4 u de A dans la direction de A ; B à moins de 3 u de A : fil allongé à 6 u) ; la **ligne A-B** est tendue **6 s** : **coef 1,0 par passage**, immunité 0,5 s par monstre, proc 0,5, recul 0,3 u perpendiculaire ; **indépendante de sa position** (elle est libre). Sans 2ᵉ pression à 3 s : B se plante tout seul à 4 u de A. Le sort reste prêt entre les deux pressions, recharge **8 s** après la pose de B. Un nouveau jalon remplace l'ancien. Le Tendeur claque aussi sur la ligne A-B.
  - Budget : ligne piquet→elle 5 s, mobile (elle la dirige) → ligne fixe 8 u 6 s. Même coef ; la ligne de base balaie en bougeant (active), les Jalons tiennent une porte ou un couloir pendant qu'elle fait autre chose (passive). Simulateur : ×0,96 du Piquet (×0,85 en cible unique : une clôture fixe n'attrape pas un élite qui la poursuit).
  - Lisibilité : 2 `peg` existants + `Line2D` chaîne tendue (texture existante, émission fixe 2,6) ; fil qui vibre au passage. Son : deux coups de maillet, bourdon du fil.
  - Déblocage : **Balayer 800 monstres avec le Piquet** (`arpenteuse.piquet_hits` ≥ 800).
- **Cerceau** (remplace *Tendeur*, ultime)
  - *La chaîne se soulève et tourne 4 s autour de toi à 3 u : elle fauche tout, puis repousse entière.*
  - Mécanique : recharge **20 s**, exige **≥ 2 u** de chaîne, un piquet ou une ligne de Jalons ; la traîne quitte le sol et forme un **anneau de 3 u** (bande 1 u : 2,5-3,5 u, + `zone_size_add`) qui tourne **1 tour / 1 s** pendant **4 s** : **coef 1,15 par 0,5 s** à tout monstre dans la bande (8 ticks = 9,2 à qui reste ; 1,25 au premier jet, abaissé au simulateur), proc 0,4, recul **0,6 u vers l'extérieur** par tick (barrière). Pendant 4 s, pas de traîne au sol (l'auto est le cerceau) ni de Halage/Nœud. À la fin, **la chaîne retombe pleine (14 u / 7 u)**. +40 % élites/boss conservé.
  - Budget : 10 instantanés + emprisonnement 1,5 s → 9,2 étalés sur 4 s en barrière + chaîne rendue pleine. Le Tendeur **ramène** (burst, pack pour le Halage/Nœud) ; le Cerceau **tient à distance** (survie, zones de charge). Simulateur : ×1,0 du Tendeur (×1,09 avant l'abaissement du coef).
  - Lisibilité : `chain_hoop` (TOP 8 en boucle : anneau de maillons incandescents, flou de rotation) à `lift_px(0,5)` ; lumière `arpenteuse_snap` en boucle. Son : sifflement rotatif, impacts métalliques. Placeholder : la `Line2D` de la chaîne redessinée en anneau.
  - Déblocage : **Atteindre l'étage 3 avec Arpenteuse** (`floor_reached` 3).

### 2.6 Rainette, chevalière des roseaux — second style : « la grenouille qui reste au sol »
> **Refonte du 26/10/2026 (retours du joueur).** Le système de **souffle** est supprimé : les bonds sont gratuits et enchaînés sans limite, orientables en l'air (virage doux vers le joystick, 4,5 rad/s). Plus de jauge, plus d'essoufflement, plus de pastilles au HUD (le passif « Avalement » n'a pas d'icône en jeu). Le kit gagne un vrai **monocible** : la Langue frappe sa *cible principale* (le boss de la ligne, sinon l'élite, sinon le monstre le plus proche) à **coef 1,15**, et le reste de la ligne à **coef 0,9** (avant : 1,1 pour toute la ligne). Difficulté de la fiche : 3 → 2. Les variantes ci-dessous sont écrites pour ce nouveau kit.

Base : Langue 1,15 sur la cible principale, 0,9 sur le reste de la ligne / 0,6 s, ligne 4,5 u (demi-largeur 0,5 u), traction 0,25 u, T1 tué avalé +1 % PV · Grand saut 7 s, 1,5-6 u, 3,8 dans 3 u, étourdit 0,5 s, invulnérable 0,35 s · Gluant 8 s, 6 u, 1,4 à l'impact, flaque 5 s −40 % + attraction, bonds +50 % · Chant de crue 20 s, 4 s : bonds ×2, atterrissages 2,8 dans 3 u. Bonds : 2,5 u en 0,35 s, gratuits.

Écart simulateur (balance_sim, 3 graines, rapport à Ardent) : nouveau kit DPS cible (élite + mini-boss) ×1,14-1,24, mini-boss ×1,11-1,22 (temps pour tuer ×0,82-0,90), essaim ×0,91-1,12, dégâts subis ×0,54 de l'ancien kit (34 % PV/min contre 62 % ; Ardent 44 %), 0 mort. Chaque variante est mesurée contre ce kit de base.

- **Croassement** (remplace *Langue*, auto)
  - *Un croassement repousse tout à 2,5 u autour de toi ; chaque petit monstre qu'il tue raccourcit la recharge de ton Grand saut.*
  - Mécanique : toutes les 0,6 s si un ennemi est à 2,5 u : anneau **2,5 u** (+ `zone_size_add`), **coef 1,2**, proc 0,7, **recul 0,4 u × masse** ; **T1 tué : Grand saut −0,25 s de recharge** (1 s au plus par croassement ; remplace l'avalement : plus de +1 % PV). Pas de cible principale : tout le monde prend le même coup.
  - Budget (simulateur) : essaim ×1,08, mixte ×1,0, élite ×0,86, mini-boss ×0,82 (global ×0,95) : l'anneau perd le monocible de la Langue et la portée, gagne le 360° et le recul ; le prix est la mêlée (2,5 u au lieu de 4,5 u). Les kills d'essaim relancent le Grand saut.
  - Lisibilité : `croak_ring` (TOP 4, onde jade #8DBBA8 translucide), sac vocal `_e` qui gonfle 0,15 s. Son : croassement grave, hauteur selon le nombre de cibles. Repli en jeu : `land_ring` existant.
  - Déblocage : **Gagner une run avec Rainette.**
- **Ricochet** (remplace *Grand saut*, sort 2)
  - *Deux bonds moyens au lieu d'un grand : chaque atterrissage écrase 2 u, et le second bond part tout seul.*
  - Mécanique : recharge **7 s** ; bond de **1,5-3,5 u** vers le point visé (vol 0,35 s, accroupie 0,06 s, invulnérable 0,2 s à l'atterrissage) : **coef 1,9 dans 2 u**, étourdit 0,3 s ; à l'atterrissage, un **second bond identique part automatiquement** (visée rafraîchie au départ : curseur, ou paquet le plus dense sur mobile, sinon dans la direction du premier). **Aucun second appui à réussir**, aucun déplacement imposé au joueur (révision 26/10 : le second appui chronométré de la première version rendait le sort difficile). Pressé en plein bond : mis en file (règle existante).
  - Budget (simulateur) : essaim ×1,0, mixte ×1,0, élite ×1,02, mini-boss ×0,87 (global ×0,97). 3,8 dans 3 u, 6 u → 2 × 1,9 dans 2 u, 2 × 3,5 u : même total ; moins de burst sur un paquet, plus de repositionnement et deux fenêtres d'invulnérabilité.
  - Lisibilité : `land_ring` existant à l'échelle 2 u, traînée jade entre les deux bonds. Son : deux impacts, le second plus aigu.
  - Déblocage : **Étourdir 300 monstres avec le Grand saut** (`rainette.leap_stuns` ≥ 300, hors boss ; le Ricochet ne compte pas).
- **Bulle** (remplace *Gluant*, sort 3)
  - *Une bulle de vase gobe les monstres du point visé 1,5 s dans les airs, puis éclate et les lâche.*
  - Mécanique : recharge **8 s**, crachat ≤ **6 u** (mobile : paquet le plus dense), impact frame 2 (`spit`) : les non-boss dans **2,5 u** (+ `zone_size_add`) sont **soulevés 1,5 s** (statut `imprisoned`, sprite à 0,8 u, ils flottent ensemble vers le centre : attraction 1 u sur la durée) ; boss : ralentissement 40 % 1,5 s. À l'éclatement : **coef 1,4 dans 2 u** (boss compris), proc 1,0, recul 0,3 u. **Aucune flaque**, aucun bonus de bond.
  - Budget (simulateur) : essaim ×1,03, mixte ×0,98, élite ×1,06, mini-boss ×0,95 (global ×1,01), dégâts subis ×0,76. Le Gluant **prépare** (zone qui dure, tremplin) ; la Bulle **fige** (fenêtre pour un Ricochet/Grand saut ou le Chant), puis plus rien.
  - Lisibilité : `goo_bubble` (CREA 6 : bulle translucide jade qui gonfle puis éclate, 1 dir) ; repli en jeu : disque jade dessiné. Les monstres montent avec leur ombre (même lecture que le Geyser d'Averse). Son : « glop » puis éclatement humide.
  - Déblocage : **Coller 600 monstres dans le Gluant** (`rainette.glued` ≥ 600 ; un monstre compte une fois par flaque ; les mini-flaques du Chœur ne comptent pas).
- **Chœur des roseaux** (remplace *Chant de crue*, ultime)
  - *8 s : chaque atterrissage écrase 2,5 u et laisse une petite flaque gluante 2 s.*
  - Mécanique : recharge **20 s** ; **8 s** de **bonds normaux** (2,5 u, pas ×2), chaque atterrissage (bond ou saut) : **coef 1,8 dans 2,5 u** (+ `zone_size_add`), proc 0,8 (l'atterrissage d'un Grand saut garde son seul impact, plus fort), et pose une **mini-flaque 1,5 u, 2 s, −40 %** (sans attraction, bonds +50 % depuis elle ; 10 flaques vivantes au plus, la plus ancienne disparaît).
  - Budget (simulateur) : essaim ×1,08, mixte ×1,0, élite ×1,0, mini-boss ×1,01 (global ×1,03). 4 s × ≈ 5 atterrissages × 2,8 → 8 s × ≈ 8 atterrissages × 1,8 : moins de dégâts bruts par atterrissage, plus long, plus de contrôle ; le Chant reste le choix « burst et traversée ».
  - Lisibilité : sac vocal `_e` gonflé 8 s, `goo` existant à l'échelle 1,5 u par atterrissage, `land_ring` 2,5 u. Son : chœur de croassements en couche (2 voix), impacts sourds.
  - Déblocage : **Avaler 200 monstres avec la Langue** (`rainette.swallowed` ≥ 200).

Icônes attendues (Codex) : `icons/spells/rainette_croassement.png`, `rainette_ricochet.png`, `rainette_bulle.png`, `rainette_choeur.png`. Icône de passif facultative : `icons/passives/avalement.png` (le passif n'a pas d'icône au HUD).

### 2.7 Avare, usurier des Terrasses — second style : « l'usurier qui va chercher son dû »
Base : Coup de coffre 1,0 / 0,8 s, arc 150° 2 u, coffre-bouclier −45 % 0,6 s · Poignée de pièces 5 s, 5 × 1,2 en cône 50° 6 u, coûte max(2 % or, 0,1 P), pièces au sol 80 % · Rançon 9 s, 3 u, 3,0, étourdit 0,5 s, marque 4 s +50 % d'or · Faillite 25 s, dépense 50 % de l'or, 5 u, 6 + 4 × min(1, dépensé / 4 P), 50 % retombe en pièces ; bourse +15 %/P (plancher +10 %, plafond +70 %).

- **Coffre-bélier** (remplace *Coup de coffre*, auto)
  - *Le coffre part droit devant en bélier : ligne de 3,5 u, plus forte, qui repousse. Le bouclier dure plus.*
  - Mécanique : toutes les 0,8 s, ligne **3,5 u × 1 u** vers l'ennemi le plus proche (jamais le curseur), **coef 1,1** à tout monstre de la ligne, proc 1,0, **recul 0,8 u × masse** ; **coffre-bouclier 0,8 s** (au lieu de 0,6 : le coffre est devant lui). Impact frame 2 (`swing`).
  - Budget : arc 150° de 2 u (≈ 5,2 u²) 1,0 → ligne 3,5 u² 1,1 : moins de cibles, un peu plus de dégâts et de portée (3,5 u : il touche un tireur T2 en approche), recul double. Il ouvre un couloir vers ses pièces au lieu de tenir un cercle. Perd : la défense à 360° (les monstres de côté ne sont plus repoussés).
  - Lisibilité : `chest_ram` (TOP 5 : traînée dorée en ligne, accent or #F2C14E), anim `swing` conservée (ou `thrust` si Codex la livre). Son : choc de bois cerclé, plus grave que l'arc.
  - Déblocage : **Gagner une run avec Avare.**
- **Pièce truquée** (remplace *Poignée de pièces*, sort 1)
  - *Une seule pièce, payée par la bourse, qui rebondit 4 fois de monstre en monstre avant de tomber au sol.*
  - Mécanique : recharge **5 s**, coût **max(2 % de l'or, 0,1 P)** (bourse trop maigre : lancer gratuit sans pièce rendue, règle existante) ; projectile vers le point visé ≤ 6 u (mobile : paquet le plus dense), 13 u/s, **coef 1,5** au premier monstre puis **rebondit** vers le monstre le plus proche non encore touché à ≤ **3 u**, jusqu'à **4 rebonds** (5 touches), proc 0,8 ; la pièce **tombe où elle s'arrête** : **80 % du coût** en une pièce, contact 0,75 u, sans expiration. Boss : touché une fois, rebond possible.
  - Budget : 5 × 1,2 = 6,0 en cône (2-3 par cible au contact, 1 à 5 u) → 5 × 1,5 = 7,5 en chaîne sur 5 monstres distincts (1,5 par cible) ; une seule pièce à aller chercher (plus loin, dans la foule). Cône = burst frontal ; chaîne = nettoyage dispersé, un seul ramassage.
  - Lisibilité : pièce `coin_big` (CREA 4, dorée, tourne), fil doré bref entre deux rebonds (`Line2D` 0,1 s). Son : « ting » par rebond, hauteur montante.
  - Déblocage : **Ramasser 500 de tes propres pièces** (`avare_coins_picked` ≥ 500 ; Poignée, Faillite et pièces saignées ; ≈ 60-120 par run).
- **Saisie** (remplace *Rançon*, sort 2)
  - *La chaîne du coffre harponne un paquet à 5 u et le ramène à tes pieds, marqué : il paiera +50 % d'or.*
  - Mécanique : recharge **9 s**, point visé ≤ **5 u** (mobile : paquet le plus dense) : disque **2 u** (+ `zone_size_add`) ; les non-boss sont **tirés** (`hooked` de Tocsin, 16 u/s, 0,4 s max) jusqu'à **1,5 u** devant Avare et **tassés**, **coef 2,0**, proc 1,0, **marque 4 s (+50 % d'or à la mort)** posée avant les dégâts ; pas d'étourdissement. Boss : coef 2,0 et marque, pas de traction. **Coffre-bouclier** déclenché (comme la Rançon).
  - Budget : 3,0 autour de soi + 0,5 s d'étourdissement → 2,0 à 5 u + traction d'un paquet entier à ses pieds (il va chercher l'or : les pièces des marqués tombent à portée de main). Rançon = sécurité au contact ; Saisie = engagement choisi, moins de dégâts, plus d'or ramassable sans courir.
  - Lisibilité : chaîne du coffre `Line2D` fer noir + maillons dorés, `ransom_ring` existant à l'arrivée. Son : chaîne qui file, choc, pièces qui tintent.
  - Déblocage : **Encaisser 2 000 d'or de primes de Rançon** (`avare_ransom_gold` ≥ 2 000 ; valeur de l'or neuf de la prime, scalée par D ; ≈ 300-600 par run).
- **Trésor enterré** (remplace *Faillite*, ultime)
  - *Enterre la moitié de ta bourse : le trésor explose à 3 s ou dès que 6 monstres l'écrasent. Tout l'or retombe.*
  - Mécanique : recharge **25 s** ; à la frame d'impact, **floor(50 % de l'or)** sort de la bourse et un **coffre-mine** est posé aux pieds d'Avare (télégraphe : cercle 5 u qui se remplit en **3 s**) ; détonation à **3 s** ou dès que **≥ 6 points de monstres** (élite 2, T3 3) sont dans **2 u** du coffre (jamais avant 0,8 s) : **rayon 5 u** (+ `zone_size_add`), **coef 5 + 3 × min(1, enterré / 4 P)** (dégâts calculés avec la puissance d'AVANT la dépense), proc 1,0, recul 2 u × masse ; **100 % de l'or enterré retombe** en **12 pièces** sur 1,5-4,5 u (ramassables après 0,3 s, sans expiration). Bourse vide : coef 5, pas de pièces.
  - Budget : 6-10 instantanés, 50 % de l'or rendu (la Faillite coûte vraiment) → 5-8 différés (3 s sans la moitié de sa puissance) mais rien de perdu si l'on ramasse. Faillite = burst de panique au prix de l'or ; Trésor = piège préparé, économe, qui demande de tenir 3 s et de revenir chercher 12 pièces dans la zone qu'on vient de vider. À simuler (systems-designer) : le remboursement intégral ne doit pas rendre la Faillite dominée ; levier : 85 % si besoin.
  - Lisibilité : coffre posé `chest_mine` (CREA 1 × 8 dir, cadenas qui luit), cercle de télégraphe doré qui se remplit, `coin_burst` existant ×2 à la détonation. Son : cliquetis de cadenas qui s'accélère, explosion de pièces.
  - Déblocage : **Vaincre le boss de l'étage 2 avec Avare** (`boss_kill`, étage 2).

### 2.8 Bourbe, mère-vase de la Mangrove — second style : « la vase qui tient à distance »
Base : Gifle de vase 1,0 / 0,8 s, arc 210° 2,6 u (26/10 : 2,0 -> 2,6) ; vase compacte −30 % subis sans motte (fond motte par motte) · Détacher 4 charges / 3 s, 15 % PV max payés en PV actuels (refus sous 35 %), motte 10 s (PV 15 %, 0,40 / 0,8 s, provoque 4 u, boss compris), plouf 1,4 dans 2 u · Rappel 6 s, 1,5 par motte traversante · Bourbier 22 s, 4 s invulnérable, 5 u, 1,2 par 0,5 s, −50 %, 4 mottes gratuites à la sortie.

- **Crachat de vase** (remplace *Gifle de vase*, auto)
  - *Une motte crachée à 6 u éclate sur 0,8 u et englue ce qu'elle touche. Tes mottes tiennent la ligne.*
  - Mécanique : toutes les **0,6 s** (calé au simulateur 26/10 : 0,8 s -> 0,6 s, rayon 1,2 -> 0,8 u), projectile `LOB` (arc 0,8 u, 0,45 s) vers l'ennemi le plus proche ≤ **6 u**, éclatement **rayon 0,8 u** (+ `zone_size_add`) : **coef 1,0**, proc 0,8, **ralentissement 25 % 1 s**, recul 0,2 u. Vase compacte inchangée (c'est son corps, pas son coup).
  - Budget : arc 210° de 2 u (≈ 7,3 u²) 1,0 au contact → disque 1,2 u (≈ 4,5 u²) 1,0 à 6 u + ralentissement. Moins de cibles, portée : Bourbe reste derrière ses mottes (qui provoquent à 4 u) au lieu de se battre avec elles ; la brute lente sans motte devient une tireuse lente sans défense de contact.
  - Lisibilité : `mud_glob` (CREA 3, boule d'argile avec feu follet #8DDBA8), `mud_splash` existant à l'impact. Son : « plof » puis éclaboussure.
  - Déblocage : **Gagner une run avec Bourbe.**
- **Bouture** (remplace *Détacher*, sort 1)
  - *2 grosses mottes au lieu de 4 : chacune coûte 30 % de tes PV, frappe deux fois plus fort et tient 15 s.*
  - Mécanique : **2 charges séquentielles / **4 s** (calé 26/10)** ; coût **30 % des PV max** payés en PV actuels, refus sous **35 %** (il faut ≥ 65 % de PV) ; motte : **PV 30 %** des PV max, rayon 0,45 u, contact **coef 0,45 / 0,4 s** (deux fois plus de coups que la petite motte), proc 0,6, vitesse 3,6, provoque **5 u** (rayon par leurre, `Decoy.provoke_range_u` ; pas les boss, audit 23/10), **Rappel coef 3,0** (x2) ; plouf **coef 1,6 dans 2 u** (calé 26/10), **15 s** de combat puis rampe vers elle . Recollée : soin du prix payé × PV restants. Vitesse de Bourbe +0,3 par grosse motte (= +0,15 × 2), hitbox 0,6 → 0,45 à 2 mottes.
  - Budget : 4 × (15 % PV, 0,40 / 0,8 s) = 60 % PV engagés, 2,0/s de contact, 4 corps qui provoquent → 2 × (30 %, 0,9) = 60 %, 2,25/s, 2 corps plus durs (une grosse motte survit à un T3 ; 4 petites couvrent plus de terrain). Moins de leurres, plus de tank ; le Rappel ne traverse qu'en 2 lignes (2 × 1,5 au lieu de 4 × 1,5 : compensé par les 0,9 de contact) ; le Bourbier sort toujours 4 mottes **normales** gratuites.
  - Lisibilité : `motte_big` (motte existante ×1,5, 128², même anims idle/run/die), anneau d'allié 0,6 u, follet plus gros. Son : pas lourds.
  - Déblocage : **Recoller 200 mottes** (`bourbe_mottes_recalled` ≥ 200 ; retour, Rappel, Bourbier, étage ; ≈ 25-50 par run).
- **Éclatement** (remplace *Rappel*, sort 2)
  - *Toutes tes mottes éclatent sur place et leur vase te revient d'un coup : tu récupères leurs PV.*
  - Mécanique : recharge **6 s**, bloqué sans motte ; chaque motte vivante **explose** : **rayon 1,5 u (+ `zone_size_add`), coef 2,0 × (PV restants / PV max de la motte, min 0,5)**, proc 1,0, recul 0,8 u × masse, ralentissement 30 % 1 s ; la vase **revient instantanément** à Bourbe (soin = prix payé × PV restants, comme un recollage). Toutes les mottes sont consommées (plus de leurres jusqu'au prochain Détacher).
  - Budget : 4 lignes × 1,5 par monstre traversé (0,45 u de large : 2-4 monstres par ligne) → 4 disques 1,5 u × 2,0 (× PV restants) là où les mottes se battent. Le Rappel ramène les mottes à elle (défense : la vase revient en corps à corps) ; l'Éclatement frappe **là où les monstres sont** et soigne sans délai, mais Bourbe reste seule après.
  - Lisibilité : `mud_burst` (TOP 6, gerbe d'argile + follet qui file vers Bourbe en traînée), lumière `bourbe_follet`. Son : 4 éclatements décalés de 0,05 s.
  - Déblocage : **Écraser 800 monstres avec le Rappel** (`hits_by_spell:rappel` ≥ 800).
- **Marée de vase** (remplace *Bourbier*, ultime)
  - *Tu gonfles 6 s : bouclier de vase (50 % PV), gifles élargies, mottes absorbées ; puis 4 mottes jaillissent.*
  - Mécanique : recharge **22 s**, immédiat : Bourbe **grossit** (échelle ×1,35, hitbox 0,75 u) pendant **6 s** : **bouclier = 50 % des PV max** (absorbe avant les PV, perdu à la fin), **immunisée aux ralentissements**, auto (Gifle **ou** Crachat) **rayon ×1,5** et **coef ×1,3**, roulade permise ; toutes les mottes vivantes **sont absorbées** (soin plein du prix payé, quel que soit leur état) ; à la fin : **4 mottes gratuites** jaillissent sur un anneau de 1,2 u (comme le Bourbier). Pas de zone de dégâts, pas d'invulnérabilité.
  - Budget : 4 s invulnérable + zone 1,2 × 8 = 9,6 (−50 %) + 4 mottes → bouclier 50 % PV (≈ 2 Bourbiers de dégâts encaissés à L6) + 6 s d'auto ×1,3 sur ×1,5 de rayon (≈ 6 × 1,25 × 1,3 ≈ 9,8 coef) + 4 mottes. Le Bourbier **disparaît** (reset total, zone de déni) ; la Marée **reste au combat** et frappe (agressive, prend des coups : le bouclier fond).
  - Lisibilité : Bourbe à l'échelle ×1,35 (sprite existant, pas de rendu nouveau), bouclier = couche de vase luisante (`_e` + contour jade, shader `bourbe_shield`), `mud_splash` ×1,5 par gifle. Son : vase qui bout, gifles plus lourdes.
  - Déblocage : **Vaincre 3 mini-boss avec 4 mottes dehors** (`bourbe_miniboss_4mottes` ≥ 3 ; le kit lit le nombre de mottes vivantes à `boss_killed`, mini-boss seulement).

### 2.9 Vigie, guetteuse de la digue — second style : « la vigie au corps à corps »
Base : Trait 0,8 / 0,6 s, traverse 1, 9 u ; Tension pleine → Trait d'allonge 2,0 à toute la ligne 12 u · Fusée de détresse 8 s, 9 u, 1,2, lumière 3 u 5 s : exposés +10 % · Filet lesté 9 s, 7 u, 0,5 + 1,2, `imprisoned` 1,5 s dans 3 u, Tension pleine · Grêle 20 s, 10 u, 0,7 par 0,25 s pendant 2,5 s dans 4,5 u, −25 %, expose ; Tension : 2,2 s en marche, 1 s ancrée.

- **Tir double** (remplace *Trait*, auto)
  - *Deux flèches légères sur les deux monstres les plus proches. Tension pleine : volée de trois traits perçants.*
  - Mécanique : toutes les 0,6 s, **2 flèches** (coef **0,42** chacune, **sans traversée**, 8 u, 16 u/s, proc 0,8) vers les **deux ennemis les plus proches** (un seul ennemi : les deux sur lui). **Tension pleine** : **Volée d'allonge** : **3 traits** en éventail de 20°, **coef 1,2** chacun, **percent tout**, 12 u, recul 0,5 u, proc 1,0 ; Tension à 0. Anims `attack` / `draw` conservées.
  - Budget : 0,8 traverse 1 (1-2 cibles en ligne) → 2 × 0,42 = 0,84 sur 2 cibles distinctes (0,84 sur une seule) ; Allonge 2,0 × toute la ligne → 3 × 1,2 = 3,6 répartis sur 3 lignes (1,2 par cible, 3,6 au contact). Moins bon contre un boss isolé à distance (1,2 vs 2,0 par Allonge), meilleur en essaim dispersé et au contact.
  - Lisibilité : `arrow` existant ×2, `arrow_charged` ×3 en éventail. Son : double « tac », volée plus grave.
  - Déblocage : **Gagner une run avec Vigie.**
- **Fanal** (remplace *Fusée de détresse*, sort 1)
  - *La fusée brûle sur ton arc : 5 s de lumière autour de toi qui expose et bande ta corde même en marchant.*
  - Mécanique : recharge **8 s**, immédiat, sans visée ni flèche : lumière **3 u** (+ `zone_size_add`) **attachée à Vigie** pendant **5 s** : exposés **+10 %** (`vigie_expose`, toutes sources) ; pendant 5 s, la Tension se remplit **au rythme ancré (1 s) même en marche** ; ancrée : **0,7 s**. Aucun dégât propre.
  - Budget : 1,2 (flèche) + exposition 3 u à 9 u, posée (5 s) → 0 dégât + exposition 3 u **sur elle** + ≈ 2 Allonges de plus sur 5 s (≈ +4,0 coef). La Fusée éclaire une zone que Vigie **évite** ; le Fanal éclaire la zone où elle **est** : archère au contact qui charge en courant, et qui attire le regard (les monstres exposés sont ceux qui la touchent).
  - Lisibilité : `flare` existant tenu à la pointe de l'arc (position de la main, par direction), lumière `vigie_flare` sur le joueur 5 s. Son : crachotement de magnésium continu.
  - Déblocage : **Exposer 1 000 monstres avec la Fusée de détresse** (`vigie_exposed` ≥ 1 000 ; un monstre par fusée).
- **Chausse-trapes** (remplace *Filet lesté*, sort 2)
  - *La flèche sème des pointes sur 3 u pendant 6 s : ce qui entre est ralenti, blessé, et bande ta corde.*
  - Mécanique : recharge **9 s**, même tir posé que le Filet (7 u, s'arrête au premier monstre ou au point visé ; flèche **coef 0,5**) ; champ de pointes **3 u** (+ `zone_size_add`) **6 s** : à l'**entrée** d'un monstre (une fois par monstre) : **coef 0,6**, proc 0,5, **ralentissement 50 % 1 s** rafraîchi tant qu'il reste ; **Tension +25 % par entrée** (plafond : pleine). Boss : entrée comptée, ralentissement 25 %.
  - Budget : 0,5 + 1,2 + `imprisoned` 1,5 s sur 3 u + Tension pleine instantanée → 0,5 + 0,6 × N entrées (N ≈ 4-8 : 2,4-4,8) + ralentissement 6 s + Tension pleine en 4 entrées (≈ 1-2 s en essaim, jamais seule). Le Filet **cloue** (fenêtre d'Allonge garantie, boss compris) ; les Chausse-trapes **tiennent un passage** et nourrissent la Tension dans la durée, sans effet immédiat sur un boss.
  - Lisibilité : `caltrop_field` (TOP 6 en boucle + `end` 3 : pointes de fer sombre, reflets rouges #FF3A4F), flash de Tension sur la corde à chaque entrée. Son : crissement de fer à chaque entrée.
  - Déblocage : **Immobiliser 500 monstres avec le Filet lesté** (`vigie_netted` ≥ 500).
- **Tir de signal** (remplace *Grêle*, ultime)
  - *Une flèche énorme tirée au ciel retombe 1,2 s plus tard : fracas, étourdissement et 8 s de lumière.*
  - Mécanique : recharge **20 s**, tir au ciel à la frame d'impact de `volley`, point visé ≤ **10 u** (mobile : paquet le plus dense), **télégraphe 1,2 s** (cercle rouge qui se referme + sifflement) puis impact : **rayon 3,5 u** (+ `zone_size_add`), **coef 7,0**, proc 1,0, **`imprisoned` 1 s** (boss : ralentissement 40 % 1,5 s), recul 1,5 u × masse ; la flèche reste plantée et **éclaire 8 s** (exposés +10 % dans 3,5 u, lumière rouge).
  - Budget : 0,7 × 11 volées ≈ 7,7 sur 2,5 s dans 4,5 u (réaliste ≈ 5-6 : les monstres sortent) + −25 % → 7,0 instantanés dans 3,5 u + 1 s d'étourdissement + 8 s d'exposition. La Grêle **tient** une zone 2,5 s ; le Tir de signal **punit** un paquet immobile (Chausse-trapes / Filet → Tir : la boucle du personnage) et éclaire longtemps.
  - Lisibilité : `signal_arrow_fall` (CREA 4, flèche de 1 u avec traînée de magnésium), cercle de télégraphe rouge 1,2 s (commun), `flare` existant ×1,5 planté 8 s, secousse 10 px. Son : sifflement descendant 1,2 s, impact lourd, crachotement 8 s.
  - Déblocage : **Tuer 300 monstres avec la Grêle** (`kills_by_spell:vigie_grele` ≥ 300).

### 2.10 Taliant (id `morfil`), rōnin d'écorce — second style : « la lame patiente »
Base : Taille et estoc 0,7 s, alternance cercle 2,3 u (1,5) / estoc cône 40° 3,2 u (2,0), 4 % d'usure par coup, garde −45 % 0,6 s · Fauche-lune 6 s, 180° 3,5 u, 4,0, 15 % · Aiguisage 10 s → 100 % (refusé à 100 %), auto suspendue 0,45 s · Lames jumelles 30 s, exige ≥ 90 %, dégainé 2,5 dans 2,5 u, chaque coup doublé pendant 15 s, garde permanente · Iaï (roulade) 1,5 par monstre traversé, 4 % s'il touche. Dégâts × aiguisage/100 (plancher 10 %).

- **Taille lente** (remplace *Taille et estoc*, auto)
  - *Un seul grand coup en cône toutes les secondes : plus lourd, moins d'usure par coup, garde un peu plus courte.*
  - Mécanique : toutes les **1,0 s** (`attack_interval` du kit ; la vitesse d'attaque s'applique), **cône 90°, 3,0 u** (+ `zone_size_add`) vers l'ennemi le plus proche, **coef 2,6** × aiguisage/100, recul 0,8 u, proc 1,0, **usure 5 %** ; **garde −35 % 0,6 s** après chaque coup (la posture lourde pare moins). Pas de cercle à 360° : les monstres dans le dos ne sont pas touchés. Doublé sous Lames jumelles.
  - Budget : (1,5 + 2,0) / 2 / 0,7 s = 2,5/s, 5,7 % d'usure/s, 360° un coup sur deux → 2,6/s, 5,0 %/s, 90° seulement. Même DPS, un peu moins d'usure, moins de procs (1 coup/s au lieu de 1,43) et un dos exposé. Pour qui aime les gros chiffres et les paquets devant lui.
  - Lisibilité : `cut_crescent` existant en 90° (ou `cut_kesa`, TOP 6, diagonale) ; chiffre de dégâts unique et gros. Son : coup lourd, fil de sève plus grave.
  - Déblocage : **Gagner une run avec Taliant.**
- **Fendoir** (remplace *Fauche-lune*, sort 1)
  - *Un coup vertical qui fend une ligne de 5 u devant toi, et un pas en avant. Même usure que la Fauche-lune.*
  - Mécanique : recharge **6 s**, ligne **5 u × 1 u** (+ `zone_size_add` sur la largeur) dans la direction visée (mobile : vers le paquet le plus dense à 5 u), **coef 4,0** × aiguisage/100, recul 0,6 u (dans l'axe), proc 1,0, **usure 15 %** ; Taliant **avance de 1 u** pendant le coup (pas d'invulnérabilité). Doublé sous Lames jumelles (second coup depuis la nouvelle position).
  - Budget : demi-disque 180° de 3,5 u (≈ 19 u²) 4,0 → ligne 5 u² 4,0 + 1 u de pas. Moins de cibles, 1,5 u de portée en plus : il atteint les tireurs T2 et aligne un couloir ; la Fauche-lune reste le coup d'essaim.
  - Lisibilité : `cut_cleave` (TOP 6, trait vertical qui fend le sol en ligne, fil de sève #CDEB6E), traînée courte du pas. Son : coup sec, fente de bois.
  - Déblocage : **Toucher 12 monstres d'une seule Fauche-lune** (`max_hits_one_cast:fauche_lune` ≥ 12).
- **Sur-aiguisage** (id conservé `morfil_affutage_en_marche` ; remplace *Aiguisage*, sort 3 ; ex-« Affûtage en marche », retiré le 26/10 : l'aiguisage de base étant déjà quasi instantané, la posture lente n'apportait rien)
  - *Lame remise à 100 % et sur-fil : tes 6 prochains gestes (8 s) frappent ×1,5. Lançable même lame au fil. Recharge 12 s.*
  - Mécanique : recharge **12 s** (base 10 s) ; geste identique à l'Aiguisage (auto suspendue 0,45 s), lame à **100 %**, puis **6 gestes de lame** (auto, Fauche-lune/Fendoir, Iaï ; un geste = un cran, quel que soit le nombre de touchés) à **dégâts ×1,5**, dans une fenêtre de **8 s** (le reste est perdu). Contrairement à l'Aiguisage, **lançable à 100 %** : on arme le sur-fil avant un paquet ou un boss. Refusé sous Trempe (usure déjà nulle, pas de cumul ×2,25). Auto-cast (accessibilité) : sur-fil épuisé et aiguisage sous 75 %. La jauge pulse (`boost`) tant que le sur-fil dure. Le sur-fil se cumule avec l'aiguisage du moment (×1,5 de 100 % = 150 % de dégâts) et s'applique aussi au second katana des Lames jumelles.
  - Budget : +3 gestes équivalents de dégâts (6 × 0,5) par lancer, pour 2 s de recharge en plus ; en échange il faut les dépenser dans les 8 s (cadence auto 0,7 s : ~11 gestes possibles). Simulateur `balance_sim_run` (L6/L12, essaim/mixte/élite, 2 lancers par combat) : DPS cible **×1,00** vs le sort de base (de ×0,89 en essaim court à ×1,11 en élite), ressource moyenne inchangée.
  - Lisibilité : anim `sharpen` + éclat de lumière plus fort (réutilise le VFX existant, aucun nouvel asset) ; jauge en `boost` pendant le sur-fil. À faire pour Codex (optionnel) : liseré de sève plus vif sur la lame tant que le sur-fil dure. Son : pierre à eau puis tintement aigu.
  - Déblocage : **Aiguiser 120 fois** (`morfil_sharpen_casts` ≥ 120 ; ≈ 15-25 par run).
- **Trempe** (remplace *Lames jumelles*, ultime)
  - *Exige 90 %. 15 s de lame trempée : plus d'usure et dégâts ×1,5 ; une seule lame, garde non permanente.*
  - Mécanique : recharge **30 s**, exige **≥ 90 %** (bouton grisé sinon, recharge non consommée), dégainé **coef 2,5 dans 2,5 u** (gratuit), puis pendant **la moitié de la recharge effective** (15 s) : **usure 0 %** sur tous les coups (auto, Fauche-lune/Fendoir, Iaï), **dégâts ×1,5**, Aiguisage/Sur-aiguisage refusés (inutiles) ; **garde normale** (−45 % 0,6 s après un coup, pas permanente). La jauge pulse (`boost`).
  - Budget : Jumelles = ×2 coups pendant 15 s à un aiguisage moyen ≈ 80 % (≈ ×1,6 effectif) + garde permanente (×0,55 subis) → Trempe = ×1,5 à **100 %** constant pendant 15 s (≈ ×1,5-1,8 selon l'usure qu'on aurait subie), moitié moins de touches (procs ×1), défense normale. Jumelles : burst et survie ; Trempe : 15 s de Fauche-lune/Fendoir sans compter, puis la lame est à 100 % pour enchaîner.
  - Lisibilité : fil de sève `_e` à l'intensité max + reflet d'eau sur la lame (shader `morfil_tempered`, bleu-vert froid), pas de `MorfilTwinBlade`. Son : trempe (sifflement d'eau sur métal) au lancement, coups avec queue cristalline.
  - Déblocage : **Vaincre le boss de l'étage 2 avec Taliant** (`boss_kill`, étage 2).

---

## 3. Récapitulatif et ordre d'implémentation

### 3.1 Tableau (perso × emplacement : variante — déblocage)

| Perso | Auto | Sort 1 (`spell_2`) | Sort 2 (`spell_3`) | Ultime (`spell_4`) |
|---|---|---|---|---|
| **Ardent** | Braises errantes — gagner une run | Pilier de flamme — 15 monstres d'une Nova | Pluie de météores — 300 kills Cendres | Phénix — boss étage 2 |
| **Rictus** | Main du Montreur — gagner une run | Lame-pendule — 150 couteaux ramassés | Pirouette — 30 doublures expédiées | Rideau — étage 3 atteint |
| **Tocsin** | Vapeur — gagner une run | Bras-harpon — 400 emprisonnés | Jambes-ressorts — 300 poussés | Tête-fumigène — boss d'étage tué sans tête |
| **Averse** | Bruine — gagner une run | Geyser — 1 000 trempés | Gouttière — 1 500 d'eau en Flaque | Mousson — 5 Crues à 100 |
| **Arpenteuse** | Chaîne lestée — gagner une run | Nœud — 500 frappés (Halage) | Jalons — 800 balayés (Piquet) | Cerceau — étage 3 atteint |
| **Rainette** | Croassement — gagner une run | Ricochet — 300 étourdis (Grand saut) | Bulle — 600 collés (Gluant) | Chœur des roseaux — 200 avalés |
| **Avare** | Coffre-bélier — gagner une run | Pièce truquée — 500 pièces ramassées | Saisie — 2 000 d'or de Rançon | Trésor enterré — boss étage 2 |
| **Bourbe** | Crachat de vase — gagner une run | Bouture — 200 mottes recollées | Éclatement — 800 écrasés (Rappel) | Marée de vase — 3 mini-boss à 4 mottes |
| **Vigie** | Tir double — gagner une run | Fanal — 1 000 exposés | Chausse-trapes — 500 immobilisés | Tir de signal — 300 kills Grêle |
| **Taliant** | Taille lente — gagner une run | Fendoir — 12 monstres d'une Fauche | Sur-aiguisage — 120 aiguisages | Trempe — boss étage 2 |

40 variantes : 10 « gagner une run », 21 compteurs cumulés, 2 records en une run, 4 boss d'étage 2, 2 étages atteints, 1 condition d'état (sans tête).

### 3.2 Ordre d'implémentation recommandé (un lot par personnage, après un lot 0 transverse)

| Lot | Contenu | Pourquoi à cette place |
|---|---|---|
| **0 transverse** (orchestrateur : `scripts/core`, `save`, menus) | `RunState.counters` + `RunState.count(key, n)` ; `main.gd` passe `counters`, `max_stage`, `floor_bosses_killed` à `Profile.add_run_result` ; `Profile` lit les `unlock_rule` de `characters.json` (Annexe B) au lieu de `UNLOCK_ON_OBJECTIVE` figé ; `SpellCaster` : `hits_by_spell`, `kills_by_spell` (via `Enemy.last_hit_spell`), `max_hits_one_cast` ; `CharacterData.for_id(id, variants)` qui substitue les sorts ; écran Nouvelle run : choix des variantes sur la fiche (ux-designer) ; sauvegarde des ids actifs. | Tout le reste en dépend ; sans ça, aucune variante ne se débloque ni ne se choisit. |
| **1 Ardent** | 4 variantes (ids, lumières, VFX `flame_pillar`/`meteor_impact` et icônes déjà prévus) ; Phénix = premier familier volant (réutilise `Decoy`). | Le plus avancé côté assets et données ; valide la substitution de sorts sur le personnage de référence du simulateur. |
| **2 Vigie** | Tir double, Fanal, Chausse-trapes, Tir de signal. | Kit simple (projectiles, zones, statuts existants) : variantes rapides, bon test du compteur `vigie_exposed`. |
| **3 Rictus** | Main du Montreur, Lame-pendule (`BOOMERANG`), Pirouette, Rideau. | Réutilise les doublures et le `BOOMERANG` de Tocsin ; teste la garde conditionnelle. |
| **4 Taliant** | Taille lente, Fendoir, Sur-aiguisage, Trempe. | Kit récent et propre (toutes les valeurs en constantes) ; variantes = paramètres et un état. |
| **5 Averse** | Bruine, Geyser (lift), Gouttière (ligne), Mousson (zone attachée). | Teste `imprisoned` + `lift_px` (partagé avec la Bulle de Rainette) et une zone qui suit le joueur. |
| **6 Tocsin** | Vapeur, Bras-harpon (traction du joueur), Jambes-ressorts (`LOB` du joueur), Tête-fumigène. | Le plus complexe (locomotion, membres au sol) : à faire quand la substitution est stable. |
| **7 Arpenteuse** | Chaîne lestée (paramètres), Nœud, Jalons (ligne fixe A-B), Cerceau (anneau tournant). | Variantes de la polyligne ; le Cerceau demande un test de perf (anneau × 250 monstres par tick). |
| **8 Rainette** | Croassement, Ricochet (bond chaîné), Bulle, Chœur. | Bonds (sans souffle depuis le 26/10) : logique d'état dense, à aborder après Averse (lift). |
| **9 Avare** | Coffre-bélier, Pièce truquée (chaîne de rebonds), Saisie (`hooked`), Trésor enterré. | Couplage économie : `economy_test` à relancer (remboursement 100 %, primes de Saisie). |
| **10 Bourbe** | Crachat, Bouture (grosse motte), Éclatement, Marée (bouclier). | Familiers : la grosse motte et le bouclier touchent `Decoy`/`BourbeMotte` et les PV du joueur. |

Chaque lot : code (Sonnet), puis `balance_sim_run.tscn --chars=<id>` **avec et sans** variantes (systems-designer compare : chaque variante dans ±15 % du sort de base en DPS cible et zone à L1/L6/L12 ; sinon ajuster le coef, jamais le style), puis brief Codex des VFX listés (lot `<ID>V`, effort low).

---

## 4. Compteurs à suivre

Mécanisme : `RunState.counters: Dictionary` (clé texte → float), `RunState.count(key, n := 1.0)` ; vidé au début de la run ; `main.gd` le passe dans `add_run_result` (`"counters"`), avec `"max_stage"` (étage le plus haut atteint) et `"floor_bosses_killed"` (liste des étages dont le boss est tombé). `Profile` additionne les compteurs cumulés dans `objectives[key]`, garde le max des records dans `objectives["max:" + key]`, et évalue les `unlock_rule` de toutes les variantes de `characters.json` (Annexe B). Les clés préfixées par un perso ne comptent que pour lui ; les clés génériques (`kills_by_spell:…`) sont par id de sort, donc par perso de fait.

### 4.1 Génériques (`SpellCaster`, tous les personnages)
| Clé | Incrémentée par |
|---|---|
| `hits_by_spell:<spell_id>` | `SpellCaster.deal_damage` : +1 par monstre touché par ce sort (ticks de DoT compris : pour les DoT, Arpenteuse Piquet et Rappel comptent par passage, règle existante d'immunité). |
| `kills_by_spell:<spell_id>` | `Enemy` mémorise `last_hit_spell` dans `deal_damage` ; à `Events.enemy_killed`, +1 sur ce sort. |
| `max_hits_one_cast:<spell_id>` | Record : nombre de monstres distincts touchés par **un lancer** (zones instantanées : la résolution ; projectiles : les touches du même tir). `Profile` garde le max. |
| `max_stage` | `main.gd` à `floor_started` (max). Règle `floor_reached`. |
| `floor_bosses_killed` | `main.gd` à `Events.boss_killed(_, true)` : ajoute `RunState.stage`. Règle `boss_kill`. |
| victoire | déjà dans le résultat (`victory`, `character`). Règle `victory`. |

### 4.2 Par kit
| Clé | Perso | Incrémentée par |
|---|---|---|
| `rictus_knives_picked` | Rictus | ramassage d'un couteau planté (callback pickup de l'Éventail). |
| `rictus_doubles_launched` | Rictus | doublure percutée par la Toupie/Pirouette (+1 par doublure). |
| `tocsin_imprisoned` | Tocsin | monstre emprisonné par une pince (+1 par monstre, pas par point). |
| `tocsin_pushed` | Tocsin | `Enemy.push` déclenché par une botte (+1 par monstre, quilles comprises). |
| `tocsin_headless_boss_kills` | Tocsin | `boss_killed(_, true)` alors que la tête est en recharge (+1). |
| `averse_soaked` | Averse | application du statut trempé (+1 par monstre et par sort, pas par rafraîchissement). |
| `averse_puddle_water` | Averse | eau gagnée dans une Flaque-miroir (+4/s × dt, en points d'eau). |
| `averse_full_crues` | Averse | Crue lancée avec ≥ 99 d'eau (+1). |
| `rainette.glued` | Rainette | monstre entré dans une flaque de Gluant (+1 par monstre et par flaque). |
| `rainette.swallowed` | Rainette | T1 avalé par la Langue (+1). |
| `avare_coins_picked` | Avare | pièce d'Avare ramassée (`PLAYER_RESOURCE`, +1 par pièce). |
| `avare_ransom_gold` | Avare | or neuf de la prime de Rançon (+valeur, scalée par D). |
| `bourbe_mottes_recalled` | Bourbe | motte recollée (retour, Rappel, Bourbier, étage ; +1). |
| `bourbe_miniboss_4mottes` | Bourbe | `boss_killed(_, false)` avec 4 mottes vivantes (+1). |
| `vigie_exposed` | Vigie | monstre entré dans la lumière d'une fusée (+1 par monstre et par fusée). |
| `vigie_netted` | Vigie | monstre immobilisé par un filet (+1). |
| `morfil_sharpen_casts` | Taliant | Aiguisage effectif (non refusé ; +1). |

Coût : 17 clés de kit (une ligne `RunState.count` chacune) + 3 hooks génériques dans `SpellCaster`/`Enemy`. Aucune nouvelle sauvegarde de run (les compteurs d'une run interrompue sont perdus avec elle : acceptable ; si la reprise doit les garder, ajouter `counters` au `RunSave`).

---

## Annexe A : JSON à fusionner dans `characters.json`

Pour chaque personnage, remplacer le tableau `variants` du sort indiqué par le bloc ci-dessous (Ardent : retirer `"todo_design": true`). Champs : `id`, `name`, `desc` (≤ 110 caractères), `unlock_text`, `unlock_key` (= `spell:<id>`, clé lue par `Profile.is_unlocked`), `unlock_rule` (Annexe B).

```json
{
  "ardent": {
    "eclat_de_braise": [{"id": "roaming_embers", "name": "Braises errantes", "desc": "Trois braises tournent autour d'Ardent et brûlent tout ce qu'elles frôlent.", "unlock_text": "Gagner une run avec Ardent.", "unlock_key": "spell:roaming_embers", "unlock_rule": {"type": "victory", "character": "ardent"}}],
    "nova_ardente": [{"id": "flame_pillar", "name": "Pilier de flamme", "desc": "Une colonne de feu jaillit au point visé et brûle 2,5 s tout ce qui passe dedans.", "unlock_text": "Toucher 15 monstres d'un seul lancer de Nova ardente.", "unlock_key": "spell:flame_pillar", "unlock_rule": {"type": "run_max", "key": "max_hits_one_cast:nova_ardente", "threshold": 15}}],
    "cendres": [{"id": "meteor_rain", "name": "Pluie de météores", "desc": "Cinq météores s'abattent en 2 s sur la zone visée ; chaque impact est annoncé au sol.", "unlock_text": "Tuer 300 monstres avec Cendres.", "unlock_key": "spell:meteor_rain", "unlock_rule": {"type": "counter", "key": "kills_by_spell:cendres", "threshold": 300}}],
    "brasier": [{"id": "phoenix", "name": "Phénix", "desc": "Un phénix de flammes combat 12 s aux côtés d'Ardent, puis explose en se consumant.", "unlock_text": "Vaincre le boss de l'étage 2 avec Ardent.", "unlock_key": "spell:phoenix", "unlock_rule": {"type": "boss_kill", "character": "ardent", "floor": 2}}]
  },
  "rictus": {
    "dagues_demi_lune": [{"id": "rictus_main_du_montreur", "name": "Main du Montreur", "desc": "La main du fantôme claque au sol sur le paquet le plus dense à 4 u. Près de toi, elle te protège encore.", "unlock_text": "Gagner une run avec Rictus.", "unlock_key": "spell:rictus_main_du_montreur", "unlock_rule": {"type": "victory", "character": "rictus"}}],
    "eventail": [{"id": "rictus_lame_pendule", "name": "Lame-pendule", "desc": "Un couteau lourd au bout d'un fil : il part à 7 u et revient en tranchant tout sur la ligne.", "unlock_text": "Ramasser 150 couteaux plantés.", "unlock_key": "spell:rictus_lame_pendule", "unlock_rule": {"type": "counter", "key": "rictus_knives_picked", "threshold": 150}}],
    "toupie": [{"id": "rictus_pirouette", "name": "Pirouette", "desc": "Un tour sur toi-même, bref et invulnérable : tout autour est frappé et repoussé. Pas de vertige.", "unlock_text": "Expédier 30 doublures avec la Toupie.", "unlock_key": "spell:rictus_pirouette", "unlock_rule": {"type": "counter", "key": "rictus_doubles_launched", "threshold": 30}}],
    "doublures": [{"id": "rictus_rideau", "name": "Rideau", "desc": "Six doublures en ligne devant toi forment un rideau 6 s : il attire, encaisse, puis explose.", "unlock_text": "Atteindre l'étage 3 avec Rictus.", "unlock_key": "spell:rictus_rideau", "unlock_rule": {"type": "floor_reached", "character": "rictus", "floor": 3}}]
  },
  "tocsin": {
    "tocsin_rivets_rougis": [{"id": "tocsin_vapeur", "name": "Vapeur", "desc": "Le foyer crache un cône de vapeur brûlante à 3 u. Sans tête, la vapeur fuit par le cou tout autour.", "unlock_text": "Gagner une run avec Tocsin.", "unlock_key": "spell:tocsin_vapeur", "unlock_rule": {"type": "victory", "character": "tocsin"}}],
    "tocsin_bras_grappins": [{"id": "tocsin_bras_harpon", "name": "Bras-harpon", "desc": "Le bras harponne le premier monstre touché, même un boss, et tire Tocsin jusqu'à lui.", "unlock_text": "Emprisonner 400 monstres avec les Bras-grappins.", "unlock_key": "spell:tocsin_bras_harpon", "unlock_rule": {"type": "counter", "key": "tocsin_imprisoned", "threshold": 400}}],
    "tocsin_coups_de_botte": [{"id": "tocsin_jambes_ressorts", "name": "Jambes-ressorts", "desc": "La jambe te propulse : saute jusqu'à 5 u et écrase l'atterrissage. La jambe reste au point de départ.", "unlock_text": "Pousser 300 monstres avec les Coups de botte.", "unlock_key": "spell:tocsin_jambes_ressorts", "unlock_rule": {"type": "counter", "key": "tocsin_pushed", "threshold": 300}}],
    "tocsin_tete_cloche": [{"id": "tocsin_tete_fumigene", "name": "Tête-fumigène", "desc": "La tête tinte 5 s là où elle tombe : tout autour est étourdi puis ralenti et brûlé par la fumée.", "unlock_text": "Vaincre un boss d'étage avec Tocsin pendant qu'il est sans tête.", "unlock_key": "spell:tocsin_tete_fumigene", "unlock_rule": {"type": "counter", "key": "tocsin_headless_boss_kills", "threshold": 1}}]
  },
  "averse": {
    "goutte_lame": [{"id": "averse_bruine", "name": "Bruine", "desc": "Trois gouttes en éventail à 7 u : moins précises, plus de monstres touchés et plus d'eau rendue en foule.", "unlock_text": "Gagner une run avec Averse.", "unlock_key": "spell:averse_bruine", "unlock_rule": {"type": "victory", "character": "averse"}}],
    "vague": [{"id": "averse_geyser", "name": "Geyser", "desc": "20 d'eau : un geyser jaillit sous le point visé, projette les monstres en l'air 0,8 s et les trempe.", "unlock_text": "Tremper 1 000 monstres.", "unlock_key": "spell:averse_geyser", "unlock_rule": {"type": "counter", "key": "averse_soaked", "threshold": 1000}, "role": "20 d'eau"}],
    "flaque_miroir": [{"id": "averse_gouttiere", "name": "Gouttière", "desc": "18 d'eau : un ruisseau de 6 u coule devant toi 6 s ; il ronge les monstres et te porte plus vite.", "unlock_text": "Récupérer 1 500 d'eau dans tes Flaques-miroir.", "unlock_key": "spell:averse_gouttiere", "unlock_rule": {"type": "counter", "key": "averse_puddle_water", "threshold": 1500}, "role": "18 d'eau · 5 s"}],
    "crue": [{"id": "averse_mousson", "name": "Mousson", "desc": "Vide l'amphore : 6 s de déluge qui te suit, trempe et ronge ; l'amphore se remplit sous l'averse.", "unlock_text": "Lancer 5 Crues à 100 d'eau.", "unlock_key": "spell:averse_mousson", "unlock_rule": {"type": "counter", "key": "averse_full_crues", "threshold": 5}, "role": "Ultime · toute l'eau"}]
  },
  "arpenteuse": {
    "arpenteuse_chaine": [{"id": "arpenteuse_chaine_lestee", "name": "Chaîne lestée", "desc": "7 u de chaîne seulement, mais deux fois plus lourde : elle brûle plus fort et englue ce qui la touche.", "unlock_text": "Gagner une run avec Arpenteuse.", "unlock_key": "spell:arpenteuse_chaine_lestee", "unlock_rule": {"type": "victory", "character": "arpenteuse"}}],
    "arpenteuse_boucle": [{"id": "arpenteuse_noeud", "name": "Nœud", "desc": "Les 4 derniers u de chaîne se nouent sur place : tout ce qui est pris dans le nœud flambe et reste coincé 1 s.", "unlock_text": "Embraser 500 monstres avec la Boucle.", "unlock_key": "spell:arpenteuse_noeud", "unlock_rule": {"type": "counter", "key": "hits_by_spell:arpenteuse_boucle", "threshold": 500}}],
    "arpenteuse_piquet": [{"id": "arpenteuse_jalons", "name": "Jalons", "desc": "Deux piquets plantés coup sur coup tendent un fil fixe de 8 u pendant 6 s : la clôture balaie sans toi.", "unlock_text": "Balayer 800 monstres avec le Piquet.", "unlock_key": "spell:arpenteuse_jalons", "unlock_rule": {"type": "counter", "key": "hits_by_spell:arpenteuse_piquet", "threshold": 800}}],
    "arpenteuse_tendeur": [{"id": "arpenteuse_cerceau", "name": "Cerceau", "desc": "La chaîne se soulève et tourne 4 s autour de toi à 3 u : elle fauche tout, puis repousse entière.", "unlock_text": "Atteindre l'étage 3 avec Arpenteuse.", "unlock_key": "spell:arpenteuse_cerceau", "unlock_rule": {"type": "floor_reached", "character": "arpenteuse", "floor": 3}}]
  },
  "rainette": {
    "rainette_langue": [{"id": "rainette_croassement", "name": "Croassement", "desc": "Un croassement repousse tout à 2,5 u autour de toi ; chaque petit monstre qu'il tue te rend 1 de souffle.", "unlock_text": "Gagner une run avec Rainette.", "unlock_key": "spell:rainette_croassement", "unlock_rule": {"type": "victory", "character": "rainette"}}],
    "rainette_grand_saut": [{"id": "rainette_ricochet", "name": "Ricochet", "desc": "Deux bonds moyens au lieu d'un grand : chaque atterrissage écrase 2 u ; le second part tout de suite.", "unlock_text": "Étourdir 300 monstres avec le Grand saut.", "unlock_key": "spell:rainette_ricochet", "unlock_rule": {"type": "counter", "key": "hits_by_spell:rainette_grand_saut", "threshold": 300}}],
    "rainette_gluant": [{"id": "rainette_bulle", "name": "Bulle", "desc": "Une bulle de vase gobe les monstres du point visé 1,5 s dans les airs, puis éclate et les lâche.", "unlock_text": "Coller 600 monstres dans le Gluant.", "unlock_key": "spell:rainette_bulle", "unlock_rule": {"type": "counter", "key": "rainette_glued", "threshold": 600}}],
    "rainette_chant_de_crue": [{"id": "rainette_choeur_des_roseaux", "name": "Chœur des roseaux", "desc": "8 s de souffle illimité : chaque atterrissage écrase 2,5 u et laisse une petite flaque gluante 2 s.", "unlock_text": "Avaler 200 monstres avec la Langue.", "unlock_key": "spell:rainette_choeur_des_roseaux", "unlock_rule": {"type": "counter", "key": "rainette_swallowed", "threshold": 200}}]
  },
  "avare": {
    "avare_coup_de_coffre": [{"id": "avare_coffre_belier", "name": "Coffre-bélier", "desc": "Le coffre part droit devant en bélier : ligne de 3,5 u, plus forte, qui repousse. Le bouclier dure plus.", "unlock_text": "Gagner une run avec Avare.", "unlock_key": "spell:avare_coffre_belier", "unlock_rule": {"type": "victory", "character": "avare"}}],
    "avare_poignee_de_pieces": [{"id": "avare_piece_truquee", "name": "Pièce truquée", "desc": "Une seule pièce, payée par la bourse, qui rebondit 4 fois de monstre en monstre avant de tomber au sol.", "unlock_text": "Ramasser 500 de tes propres pièces.", "unlock_key": "spell:avare_piece_truquee", "unlock_rule": {"type": "counter", "key": "avare_coins_picked", "threshold": 500}}],
    "avare_rancon": [{"id": "avare_saisie", "name": "Saisie", "desc": "La chaîne du coffre harponne un paquet à 5 u et le ramène à tes pieds, marqué : il paiera +50 % d'or.", "unlock_text": "Encaisser 2 000 d'or de primes de Rançon.", "unlock_key": "spell:avare_saisie", "unlock_rule": {"type": "counter", "key": "avare_ransom_gold", "threshold": 2000}}],
    "avare_faillite": [{"id": "avare_tresor_enterre", "name": "Trésor enterré", "desc": "Enterre la moitié de ta bourse : le trésor explose à 3 s ou dès que 6 monstres l'écrasent. Tout l'or retombe.", "unlock_text": "Vaincre le boss de l'étage 2 avec Avare.", "unlock_key": "spell:avare_tresor_enterre", "unlock_rule": {"type": "boss_kill", "character": "avare", "floor": 2}}]
  },
  "bourbe": {
    "gifle_de_vase": [{"id": "bourbe_crachat_de_vase", "name": "Crachat de vase", "desc": "Une motte crachée à 6 u éclate sur 1,2 u et englue ce qu'elle touche. Tes mottes tiennent la ligne.", "unlock_text": "Gagner une run avec Bourbe.", "unlock_key": "spell:bourbe_crachat_de_vase", "unlock_rule": {"type": "victory", "character": "bourbe"}}],
    "detacher": [{"id": "bourbe_bouture", "name": "Bouture", "desc": "2 grosses mottes au lieu de 4 : chacune coûte 30 % de tes PV, frappe deux fois plus fort et tient 15 s.", "unlock_text": "Recoller 200 mottes.", "unlock_key": "spell:bourbe_bouture", "unlock_rule": {"type": "counter", "key": "bourbe_mottes_recalled", "threshold": 200}}],
    "rappel": [{"id": "bourbe_eclatement", "name": "Éclatement", "desc": "Toutes tes mottes éclatent sur place et leur vase te revient d'un coup : tu récupères leurs PV.", "unlock_text": "Écraser 800 monstres avec le Rappel.", "unlock_key": "spell:bourbe_eclatement", "unlock_rule": {"type": "counter", "key": "hits_by_spell:rappel", "threshold": 800}}],
    "bourbier": [{"id": "bourbe_maree_de_vase", "name": "Marée de vase", "desc": "Tu gonfles 6 s : bouclier de vase (50 % PV), gifles élargies, mottes absorbées ; puis 4 mottes jaillissent.", "unlock_text": "Vaincre 3 mini-boss avec 4 mottes dehors.", "unlock_key": "spell:bourbe_maree_de_vase", "unlock_rule": {"type": "counter", "key": "bourbe_miniboss_4mottes", "threshold": 3}}]
  },
  "vigie": {
    "vigie_trait": [{"id": "vigie_tir_double", "name": "Tir double", "desc": "Deux flèches légères sur les deux monstres les plus proches. Tension pleine : volée de trois traits perçants.", "unlock_text": "Gagner une run avec Vigie.", "unlock_key": "spell:vigie_tir_double", "unlock_rule": {"type": "victory", "character": "vigie"}}],
    "vigie_fusee": [{"id": "vigie_fanal", "name": "Fanal", "desc": "La fusée brûle sur ton arc : 5 s de lumière autour de toi qui expose et bande ta corde même en marchant.", "unlock_text": "Exposer 1 000 monstres avec la Fusée de détresse.", "unlock_key": "spell:vigie_fanal", "unlock_rule": {"type": "counter", "key": "vigie_exposed", "threshold": 1000}}],
    "vigie_filet": [{"id": "vigie_chausse_trapes", "name": "Chausse-trapes", "desc": "La flèche sème des pointes sur 3 u pendant 6 s : ce qui entre est ralenti, blessé, et bande ta corde.", "unlock_text": "Immobiliser 500 monstres avec le Filet lesté.", "unlock_key": "spell:vigie_chausse_trapes", "unlock_rule": {"type": "counter", "key": "vigie_netted", "threshold": 500}}],
    "vigie_grele": [{"id": "vigie_tir_de_signal", "name": "Tir de signal", "desc": "Une flèche énorme tirée au ciel retombe 1,2 s plus tard : fracas, étourdissement et 8 s de lumière.", "unlock_text": "Tuer 300 monstres avec la Grêle.", "unlock_key": "spell:vigie_tir_de_signal", "unlock_rule": {"type": "counter", "key": "kills_by_spell:vigie_grele", "threshold": 300}}]
  },
  "morfil": {
    "taille_estoc": [{"id": "morfil_taille_lente", "name": "Taille lente", "desc": "Un seul grand coup en cône toutes les secondes : plus lourd, moins d'usure par coup, garde un peu plus courte.", "unlock_text": "Gagner une run avec Taliant.", "unlock_key": "spell:morfil_taille_lente", "unlock_rule": {"type": "victory", "character": "morfil"}}],
    "fauche_lune": [{"id": "morfil_fendoir", "name": "Fendoir", "desc": "Un coup vertical qui fend une ligne de 5 u devant toi, et un pas en avant. Même usure que la Fauche-lune.", "unlock_text": "Toucher 12 monstres d'une seule Fauche-lune.", "unlock_key": "spell:morfil_fendoir", "unlock_rule": {"type": "run_max", "key": "max_hits_one_cast:fauche_lune", "threshold": 12}}],
    "aiguisage": [{"id": "morfil_affutage_en_marche", "name": "Sur-aiguisage", "desc": "Lame remise à 100 % et sur-fil : tes 6 prochains gestes (8 s) frappent ×1,5. Lançable même lame au fil. Recharge 12 s.", "unlock_text": "Aiguiser 120 fois.", "unlock_key": "spell:morfil_affutage_en_marche", "unlock_rule": {"type": "counter", "key": "morfil_sharpen_casts", "threshold": 120}}],
    "lames_jumelles": [{"id": "morfil_trempe", "name": "Trempe", "desc": "Exige 90 %. 15 s de lame trempée : plus d'usure et dégâts ×1,5 ; une seule lame, garde non permanente.", "unlock_text": "Vaincre le boss de l'étage 2 avec Taliant.", "unlock_key": "spell:morfil_trempe", "unlock_rule": {"type": "boss_kill", "character": "morfil", "floor": 2}}]
  }
}
```

(La clé de premier niveau est l'`id` du personnage, la clé de second niveau l'`id` du sort de base ; la valeur est le tableau `variants` à écrire. Les champs `role` d'Averse reprennent ceux des sorts de base pour l'affichage du coût.)

## Annexe B : contrat de déblocage (`unlock_rule`)

Évalué par `Profile.add_run_result(r)` pour chaque variante de chaque personnage de `characters.json` dont `unlock_key` n'est pas déjà débloquée ; `r` contient `victory`, `character`, `counters` (dict), `max_stage` (int), `floor_bosses_killed` (Array[int]).

| `type` | Champs | Débloque si |
|---|---|---|
| `victory` | `character` | `r.victory` et `r.character == character`. |
| `counter` | `key`, `threshold` | `objectives[key] += counters.get(key, 0)` puis `objectives[key] >= threshold` (cumul sur toutes les runs, tous personnages confondus : les clés sont déjà propres à un sort ou à un perso). |
| `run_max` | `key`, `threshold` | `objectives["max:" + key] = max(ancien, counters.get(key, 0))` puis `>= threshold` (record en une run). |
| `boss_kill` | `character`, `floor` | `r.character == character` et `floor in r.floor_bosses_killed`. |
| `floor_reached` | `character`, `floor` | `r.character == character` et `r.max_stage >= floor`. |

Affichage sur la fiche (ux-designer) : `counter` et `run_max` montrent une barre « 212 / 300 » ; `victory`, `boss_kill`, `floor_reached` montrent le texte seul. Le raccourci en rubis (GDD §5) débloque la clé sans condition ; prix à fixer par systems-designer (proposition : 1 variante = le prix d'un personnage caché × 0,5).
