class_name VfxSwap
extends RefCounted
## Mode test : les VRAIS sorts (personnages, boss d'étage, boss final) affichent les VFX de test pixelfx
## (VfxTestPlayer) à la place de leurs VFX actuels. Interrupteur : TestMode.vfx_test (avec TestMode.active).
## À RETIRER AVEC LE MODE TEST (accroches d'une ligne gardées par `if VfxSwap.enabled()`, voir plus bas).
##
## Principe : on ne change JAMAIS les SpriteFrames d'origine. L'effet d'origine est caché (self_modulate.a = 0,
## enfant Emission compris) et continue de tourner (durées, fin de zone, synchro des dégâts intactes) ; un
## VfxTestPlayer en mode `follow` est accroché dessous (top_level) et suit sa position globale. Il est libéré avec
## son hôte (sortie de l'arbre, hôte masqué, projectile rendu au pool).
##
## Résolution de la clé "<owner>/<sort>" (dossier de res://assets/sprites/vfx_test/), dans l'ordre :
##   1. meta "vfx_key" posée au point d'appel (sprite ou l'un de ses 3 ancêtres, zone, SpellData ; "" = jamais) ;
##   2. sort connu (zone, projectile, lancer) : "<id du personnage>/<id du sort>" ;
##   3. table PATHS (chemin d'origine du .tres ; "chemin|anim" pour une anim précise) ;
##   4. .tres d'un boss d'étage : "<boss_id>/<anim sans suffixe de direction>" via BOSS_ANIMS (corps exclus) ;
## et seulement si l'asset de test existe (VfxTestPlayer.available).
##
## Accroches (hors mode test : un test de booléen) :
##   scripts/fx/emissive_overlay.gd       apply()          -> on_sprite (tout VFX passé par l'émission)
##   scripts/spells/zone_effect.gd        setup()          -> on_zone (après _setup_vfx)
##   scripts/spells/projectile.gd         launch()         -> on_projectile (pool : réévalué à chaque lancement)
##   scripts/spells/spell_caster.gd       _cast()          -> on_cast (sorts de kit sans visuel accrochable, table CAST)
##   scripts/enemies/boss_pace.gd         strike(&"auto")  -> on_boss_auto (table AUTO pour les boss sans "<id>/auto")
##   affectations directes de sprite_frames -> on_sprite : ardent_phoenix, rictus_pendulum (couteau d'origine gardé),
##   tocsin_kit (regen), salt_king_brain (edict_ring), raid_fx.
##   accroches de kit (spawn_follow / follow_while) : rictus_kit (Saccade, Toupie, Rideau), rictus_pendulum (couteau en
##   vol), tocsin_kit (Vapeur), tocsin_limb (Bras-pilier en décharge, Tête-fumigène), ardent_phoenix_bolt (phoenix_bolt :
##   trait de feu du Phénix qui traverse les monstres ; le phénix se tourne aussi avec son VFX de test).
##   apparitions explicites (aucun VFX d'origine) -> spawn_at : jar_bearer (mother_jar_blast), salt_king
##   (procession_tide), flood_gunner (shell_crater ; shell : posé 0,45 s avant l'impact par un tween du boss), sonneur
##   (bolt_rain : au début de la chute de chaque boulon), drowned_idol (chaplet_circle, noria_wheel, cring_wave),
##   ardent_variant_kit (meteor_fall : chute d'un météore pendant son télégraphe ; l'impact reste ardent/meteor_rain).
##   meta de clé au point d'appel : vigie_kit (Fanal, Tir de signal : fusée partagée FLARE_FRAMES).
##   effets permanents dessinés en code, un VfxTestPlayer par point (track_orbit / track_polyline) :
##   ardent_ember_ring (roaming_embers : un par orbe), arpenteuse_kit (chaîne, chaîne lestée, Tendeur pendant SNAP_S,
##   bande du Halage sur chaque ligne : tuiles bout à bout).
##   projectiles ennemis poolés -> on_enemy_projectile / on_enemy_projectile_end (table ENEMY_PROJ : rivets du
##   Canonnier, impact rivet_hit ; étincelles du Fondeur) ; flood_gunner (reload_smoke : follow_while) ;
##   hermit_cedar (charge_trail : spawn_follow sur le boss) ; smelter (molten_arc : spawn_at ancré sur la coulée).
## Basculer l'interrupteur en cours de partie : seuls les VFX lancés ensuite suivent le drapeau (un projectile du
## pool ou un sprite réappliqué est rendu visible) ; les effets de test déjà en vol finissent avec leur hôte.

const META_KEY := &"vfx_key" ## clé forcée au point d'appel (String ; "" = ne jamais remplacer)
const META_FOLLOWER := &"vfx_swap_follower" ## sur l'hôte : le VfxTestPlayer qui le suit
const META_CUR := &"vfx_swap_key" ## sur l'hôte : clé actuellement affichée
const META_HIDDEN := &"vfx_swap_hidden" ## sur un sprite caché : son self_modulate.a d'origine
const META_WATCH := &"vfx_swap_watch" ## sprite multi-anims (boss) : animation_changed déjà écoutée
const META_MANAGED := &"vfx_swap_managed" ## visuel géré par on_zone / on_projectile (on_sprite l'ignore)
const CAST_MAX_S := 2.5 ## effet de test d'un lancer (suit le joueur ou posé au sol) : durée bornée (asset en boucle)
const AUTO_MAX_S := 1.5 ## coup auto d'un boss : effet de test borné (l'hôte est le boss, qui vit longtemps)
const DEDUP_S := 0.3 ## même clé, même lanceur : un seul effet de test par fenêtre (pavages, ticks, salves de zones)
const META_POINTS := &"vfx_swap_points" ## sur l'hôte d'un effet multi-points : {anchors, key, original, whole}
const META_HIDDEN_MOD := &"vfx_swap_hidden_mod" ## sur un visuel caché en entier (modulate) : son modulate.a d'origine
const META_POOLED := &"vfx_swap_pooled" ## sur un projectile ennemi poolé suivi : clé de son impact de test
const META_WHILE := &"vfx_swap_while" ## sur l'hôte : {clé: VfxTestPlayer} des effets « tant que » (follow_while)
## Posées au point d'appel sur un sprite d'origine qui ne porte ni rotation ni rayon (cône d'Averse : anim à 8
## directions, échelle = longueur) : direction logique exacte et rayon gameplay (u) de l'effet de test.
const META_DIR := &"vfx_swap_dir"
const META_RADIUS := &"vfx_swap_radius_u"
const POINTS_MAX := 8 ## effets de test par hôte multi-points (gerbes, orbes)
const TILES_MAX := 16 ## tuiles `tile_along_line` par polyligne (chaîne de 14 u, tuiles de 2 u : 7 ; cerceau compris)
const POINT_SPACING_U := 2.0 ## écart par défaut entre deux effets le long d'une polyligne

const BOSS_DIR := "res://assets/sprites/bosses/etage/"
const ZONE_SCRIPT := "res://scripts/spells/zone_effect.gd"
const DIR_SUFFIXES := ["_n", "_ne", "_e", "_se", "_s", "_sw", "_w", "_nw"]

## Chemin d'origine du .tres -> clé. "chemin|anim" : seulement pour cette animation.
## Sert aux VFX qui ne passent ni par une zone ni par un projectile (kits), et aux zones internes des kits.
const PATHS := {
	# Ardent
	"res://assets/sprites/vfx/ardent_nova/ardent_nova.tres": "ardent/nova_ardente",
	"res://assets/sprites/vfx/ardent_ashes/ardent_ashes.tres": "ardent/cendres",
	"res://assets/sprites/vfx/ardent_brasier/ardent_brasier.tres": "ardent/brasier",
	"res://assets/sprites/vfx/flame_pillar/flame_pillar.tres": "ardent/flame_pillar",
	"res://assets/sprites/vfx/meteor_impact/meteor_impact.tres": "ardent/meteor_rain",
	"res://assets/sprites/vfx/phoenix/phoenix.tres": "ardent/phoenix",
	# Rictus
	"res://assets/sprites/characters/rictus/dagger_arc/dagger_arc.tres": "rictus/dagues_demi_lune",
	"res://assets/sprites/characters/rictus/variants/montreur_hand_slam/montreur_hand_slam.tres": "rictus/rictus_main_du_montreur",
	"res://assets/sprites/characters/rictus/double_burst/double_burst.tres": "rictus/doublures",
	# Toupie et couteaux (lourd, légers rappelés) : accroches de rictus_kit / rictus_pendulum (pas leurs sprites :
	# la traînée d'origine n'est visible que pendant la Toupie, le couteau planté reste l'objet d'origine).
	# Tocsin
	"res://assets/sprites/characters/tocsin/rivet/rivet.tres": "tocsin/tocsin_rivets_rougis",
	"res://assets/sprites/characters/tocsin/tocsin_blast.tres": "tocsin/tocsin_tete_cloche", # explosion de la tête
	# Averse
	"res://assets/sprites/characters/averse/effects/goutte_lame/goutte_lame.tres": "averse/goutte_lame",
	"res://assets/sprites/characters/averse/effects/wave_cone/wave_cone.tres": "averse/vague",
	"res://assets/sprites/characters/averse/effects/puddle_mirror/puddle_mirror.tres": "averse/flaque_miroir",
	"res://assets/sprites/characters/averse/effects/crue_ring/crue_ring.tres": "averse/crue",
	"res://assets/sprites/characters/averse/variants/droplet_small/droplet_small.tres": "averse/averse_bruine",
	"res://assets/sprites/characters/averse/variants/geyser/geyser.tres": "averse/averse_geyser",
	"res://assets/sprites/characters/averse/variants/monsoon_zone/monsoon_zone.tres": "averse/averse_mousson",
	# Arpenteuse
	"res://assets/sprites/characters/arpenteuse/effects/loop_blaze.tres": "arpenteuse/arpenteuse_noeud", # embrasement du Nœud (_spawn_blaze)
	"res://assets/sprites/characters/arpenteuse/effects/peg_burst.tres": "arpenteuse/arpenteuse_piquet",
	# Rainette (LAND_RING : 5 sorts ; clé posée au point d'appel ou résolue par le sort de la zone)
	"res://assets/sprites/characters/rainette/effects/tongue/tongue.tres": "rainette/rainette_langue",
	"res://assets/sprites/characters/rainette/effects/goo/goo.tres": "rainette/rainette_gluant_flaque",
	"res://assets/sprites/characters/rainette/effects/goo_projectile/goo_projectile.tres": "rainette/rainette_gluant",
	"res://assets/sprites/characters/rainette/effects/land_ring/land_ring.tres": "rainette/rainette_grand_saut",
	# Avare
	"res://assets/sprites/characters/avare/effects/coffre_arc/coffre_arc.tres": "avare/avare_coup_de_coffre",
	"res://assets/sprites/characters/avare/effects/coin_projectile/coin_projectile.tres": "avare/avare_poignee_de_pieces",
	"res://assets/sprites/characters/avare/effects/ransom_ring/ransom_ring.tres": "avare/avare_rancon",
	"res://assets/sprites/characters/avare/effects/coin_burst/coin_burst.tres": "avare/avare_faillite",
	# Bourbe (MUD_SPLASH partagé : clé posée au point d'appel)
	"res://assets/sprites/characters/bourbe/mud_slap/mud_slap.tres": "bourbe/gifle_de_vase",
	"res://assets/sprites/characters/bourbe/bog_zone/bog_zone.tres": "bourbe/bourbier",
	"res://assets/sprites/characters/bourbe/variants/mud_glob/mud_glob.tres": "bourbe/bourbe_crachat_glob", # motte en vol (l'éclatement au sol = zone bourbe/bourbe_crachat_de_vase)
	"res://assets/sprites/characters/bourbe/variants/mud_burst/mud_burst.tres": "bourbe/bourbe_eclatement",
	# Vigie
	"res://assets/sprites/characters/vigie/arrow/arrow.tres": "vigie/vigie_trait",
	"res://assets/sprites/characters/vigie/arrow_charged/arrow_charged.tres": "vigie/vigie_trait_charge",
	"res://assets/sprites/characters/vigie/flare_arrow/flare_arrow.tres": "vigie/vigie_fleche_fusee", # flèche en vol (le sort porte aussi la clé)
	"res://assets/sprites/characters/vigie/net_arrow/net_arrow.tres": "vigie/vigie_fleche_lestee", # Filet et Chausse-trapes en vol
	"res://assets/sprites/characters/vigie/net_burst/net_burst.tres": "vigie/vigie_filet",
	"res://assets/sprites/characters/vigie/hail_zone/hail_zone.tres": "vigie/vigie_grele",
	"res://assets/sprites/characters/vigie/caltrop_field/caltrop_field.tres": "vigie/vigie_chausse_trapes",
	"res://assets/sprites/characters/vigie/flare/flare.tres": "vigie/vigie_fusee", # fusée plantée (Fanal, Tir de signal : clé posée au point d'appel)
	# Taliant (morfil ; TWIN_DRAW partagé : clé posée au point d'appel)
	"res://assets/sprites/characters/morfil/cut_circle/cut_circle.tres": "morfil/taille_estoc",
	"res://assets/sprites/characters/morfil/cut_crescent/cut_crescent.tres": "morfil/fauche_lune",
	"res://assets/sprites/characters/morfil/variants/cut_kesa/cut_kesa.tres": "morfil/morfil_taille_lente",
	"res://assets/sprites/characters/morfil/variants/cut_cleave/cut_cleave.tres": "morfil/morfil_fendoir",
}

## Chemins prioritaires sur l'id du sort (même sort, deux gestes : l'estoc de Taille et estoc).
const PATHS_FIRST := {
	"res://assets/sprites/characters/morfil/cut_thrust/cut_thrust.tres": "morfil/taille_estoc_thrust",
}

## Boss : "<boss_id>/<anim sans direction>" -> clé (anims d'effet des cerveaux ; les anims de même nom que le
## dossier de test sont prises telles quelles, voir _boss_key). "" = jamais remplacé.
const BOSS_ANIMS := {
	"cerf/ground_wisp_trail": "cerf/charge_trail",
	"crane/container": "", # le conteneur qui tombe reste l'objet d'origine
	"crane/dust": "crane/container_impact", # poussière de l'impact (CraneBrain._dust, r 1,5 u)
	"crane/boom_shadow": "crane/sweep",
	"deep_eel/puddle": "deep_eel/black_pool",
	"drowned_idol/lotus_crack": "drowned_idol/prayer_flood",
	"eclusier/ground_wave": "eclusier/ground_water",
	"jar_bearer/jar": "jar_bearer/orbit",
	"salt_king/edict": "salt_king/edict_ring",
	"smelter/molten_pool": "", # bande de métal 12 × 2 u (5 s) : reste l'originale, la coulée de test (molten_arc) la couvre
	"smelter/splash": "smelter/molten_pool", # éclaboussure (r 0,9-1,2 u)
	"smelter/steam_vent": "sonneur/steam_plume", # bouche de vapeur debout (même .tres que la chaudière)
	"sonneur/ground_steam": "", # décor de vapeur au sol : reste l'original
	"sonneur/steam_vent": "sonneur/steam_plume",
	"sonneur/bolt": "", # le boulon d'origine est caché : sonneur/bolt_rain part de SonneurBrain._bolts_step (chute + impact)
	"sonneur/ground_lightning": "sonneur/strike_ring", # anneau au sol d'un éclair (r 1,5 u ; la colonne garde sonneur/lightning)
	"weaver/drop": "weaver/drop_dust",
	"weaver/ground_silk": "weaver/web_ring",
	"weaver/web": "weaver/web_ring",
}

## Sprite d'effet d'un boss, par anim source "<boss>/<anim>" : options du VfxTestPlayer (taille encodée par l'hôte).
const BOSS_SPRITE_OPTS := {
	# disque de 448 px de rayon dans sa cellule de 896 (_set_flood_visual) : rayon de l'effet = rayon de la crue
	"rain_sower/flood_water": {"fit_host_px": 896.0},
	# eau noire de l'Anguille : lac (cellule de 896 px) et flaques (128 px), rayon = celui de la cellule
	"deep_eel/black_pool": {"fit_host_px": 896.0},
	"deep_eel/puddle": {"fit_host_px": 128.0},
}

## Sprites de boss dont l'échelle encode le rayon gameplay : rayon (u) = |échelle globale x| × k (éclaboussure du
## Fondeur : échelle r × UNSQUASH × 0,5, SmelterBrain._splash). Gerbes Floor1Hazards.burst_fx (échelle
## Floor1Fx.billboard(2 r, src_px) : k = src_px / 128) et anneaux du Carillon (échelle r / 576 px : k = 9).
const HOST_RADIUS_K := {
	"smelter/splash": 2.0,
	"ox_herder/dust_burst": 1.0, # src 128 px
	"jar_bearer/jar_shatter": 0.75, # src 96 px
	"eclusier/geyser": 0.53125, # src 68 px (GEYSER_SRC_PX)
	"drowned_idol/carillon_ring": 9.0, # DrownedIdolBrain.RING_SRC_R / 64
	# gerbes de la Mère-cristal et de l'Anguille : échelle UNSQUASH × SPRITE_K × r (k = 1 / SPRITE_K)
	"crystal_mother/reflect_burst": 1.0 / Iso.SPRITE_K,
	"deep_eel/emerge_splash": 1.0 / Iso.SPRITE_K,
	# anneau d'un éclair du Sonneur : échelle 2 × LIGHTNING_R_U × 64 / 102 (SonneurBrain.strike_fx)
	"sonneur/ground_lightning": 102.0 / 128.0,
	# brume de l'Averse : 20 taches à l'échelle 1,6 sur l'anneau MIST_R_U + 2 (rayon 3,2 u chacune)
	"rain_sower/mist_band": 2.0,
}

## Lignes d'origine centrées sur leur sprite, grand axe = axe y local (sillage de vague de l'Éclusier : posé au milieu
## du trajet, tourné de -90°, len_px de planche = distance parcourue, width_px = largeur du sillage) : l'effet tuilé
## part de l'origine de la vague et file jusqu'au front, relu à chaque image (VfxTestPlayer follow_axis_y / centered).
const HOST_LINE := {
	"eclusier/ground_wave": {"len_px": EclusierBrain.WAVE_SRC_W, "width_px": EclusierBrain.WAVE_SRC_T},
}

## Lignes dont l'épaisseur gameplay est la hauteur de la planche × l'échelle y du sprite d'origine (racines du Cèdre :
## échelle (len / tw, w / th)). Les autres rayons encodent leur largeur autrement (W × 64 / 64, ou rien).
const HOST_WIDTH := ["hermit_cedar/root_spike"]

## Rayon gameplay (u) des effets au sol `ground_oneshot` posés par un sprite de boss (anneaux de 1 à R u).
const RADIUS_U := {
	"recluse/bell_wave": RecluseBrain.BELL_R1_U,
	"sonneur/glas_wave": SonneurBrain.GLAS_R1_U,
	"salt_king/edict_ring": SaltKingBrain.EDICT_R1_U,
}

## Sprites de personnage dont l'échelle encode le rayon gameplay : rayon (u) = |échelle globale x| × px / 64 (px = rayon
## dessiné dans la planche d'origine : embrasement du Nœud, flaques du Gluant et du Chœur).
const SPRITE_RADIUS_PX := {
	"arpenteuse/arpenteuse_noeud": ArpenteuseKit.LOOP_BLAZE_RADIUS_PX,
	"rainette/rainette_gluant_flaque": RainetteKit.GOO_RADIUS_PX,
}

## Largeur gameplay (u) perpendiculaire des fronts `follow_front`.
const WIDTH_U := {
	"eclusier/wave": EclusierBrain.WAVE_W_U,
	"rain_sower/wave_front": RainSowerBrain.WAVE_W_U,
}

## Épaisseur (u) des tuiles posées le long d'une polyligne (track_polyline) : la chaîne d'Arpenteuse ne doit pas être
## plus grosse que sa chaîne d'origine (maillons ~0,36 u ; demande du joueur : un poil plus épaisse, pas énorme).
const POINT_WIDTH_U := {
	"arpenteuse/arpenteuse_chaine": 0.57,
	"arpenteuse/arpenteuse_tendeur": 0.57,
	"arpenteuse/arpenteuse_chaine_lestee": 0.76,
}

## Lignes dont la longueur locale (px, depuis l'origine du sprite d'origine) n'est pas l'étendue de sa planche.
const LINE_LOCAL_PX := {
	"rainette/rainette_langue": RainetteKit.TONGUE_FRAME_LEN_PX, # langue : 405 px de l'origine (bouche) à la pointe
}

## Croix de l'Éclusier (phase 3) : le sprite `ground_wave` d'un bras (étiré sur CROSS_LEN_U, échelle y > 1) devient une
## crête (eclusier/wave) qui file du boss au bout du bras en CROSS_CREST_S ; le sillage des vagues (même anim, échelle y
## quasi nulle à la création) garde sa clé.
const CROSS_SRC := "eclusier/ground_wave"
const CROSS_KEY := "eclusier/wave"
const CROSS_CREST_S := 0.5 ## durée du jet d'un bras (EclusierBrain._cross_fx)

## Effets CAST "player" posés au sol sous le personnage : z −1 relatif à lui (sinon la flaque recouvre son corps).
const UNDER_PLAYER := ["bourbe/bourbe_maree_de_vase"]

## Coup auto d'un boss sans dossier "<boss>/auto" : clé de remplacement.
const AUTO := {
	"salt_king": "salt_king/scepter",
	"flood_gunner": "flood_gunner/volley_cone", # Culasse : éclair de bouche (les rivets sont des projectiles ennemis)
}

## Sorts de kit dont le visuel n'est ni une zone, ni un projectile, ni un sprite accrochable (dessiné en code,
## corps du personnage, membres…) : l'effet de test part au lancement. at : "player" (suit le joueur) ou "aim"
## (posé au point visé ou sur l'ennemi le plus proche).
const CAST := {
	# Arpenteuse : Tendeur (tuiles qui claquent sur la chaîne, track_polyline), Nœud (PATHS loop_blaze), Jalons
	# (spawn_at au piquet) ; Avare : Coffre-bélier, Saisie (chaîne : spawn_at ; prise : zone), Trésor enterré (zone de
	# la détonation), Pièce truquée (suit la pièce) ; Rainette : Bulle (spawn_at) -> accroches dans leurs kits.
	"arpenteuse/arpenteuse_cerceau": "player", # bande de 3 u sous ses pieds (follow_ground_loop, durée du sort)
	"bourbe/detacher": "player", # motte arrachée : giclée depuis Bourbe vers la visée
	"bourbe/bourbe_bouture": "player",
	"bourbe/rappel": "player",
	"bourbe/bourbe_maree_de_vase": "player",
	# Taliant : Lames jumelles et Trempe passent par leur zone de dégainé (on_zone) ; Fendoir : spawn_at au coup (morfil_kit)
	"morfil/aiguisage": "player",
	"morfil/morfil_affutage_en_marche": "player",
	# Rictus et Tocsin : Doublures (explosions = zones), Saccade (fil vers le couteau), Rideau (fil sur la doublure du
	# milieu), Toupie, Vapeur, Bras-pilier, Tête-fumigène et Couteau ficelé partent d'accroches dans leur kit
	# (rictus_kit, rictus_pendulum, tocsin_kit, tocsin_limb : `grep VfxSwap`), au bon moment et à la bonne taille.
	"tocsin/tocsin_coup_de_tocsin": "player",
}

## Zones dont plusieurs effets de test partent dans la même fenêtre DEDUP_S : les six doublures explosent ensemble.
const NO_DEDUP := ["rictus/doublures"]

## Écart (u) entre deux effets de test le long d'une polyligne (track_polyline), par clé. Les effets `tile_along_line`
## (chaîne) n'y sont pas : leurs tuiles sont posées bout à bout tous les segment_u du meta.
const POINT_SPACING := {}

## Projection forcée des effets multi-points (VfxTestPlayer opts.projection). Une chaîne posée au sol : ses segments
## sont couchés dans le plan du sol logique (ground_dir, la caméra les écrase en 2:1 comme la Line2D d'origine).
const POINT_PROJECTION := {
	"arpenteuse/arpenteuse_chaine": "ground_dir",
	"arpenteuse/arpenteuse_chaine_lestee": "ground_dir",
	"arpenteuse/arpenteuse_tendeur": "ground_dir", # chaîne qui claque (SNAP_S)
	"arpenteuse/arpenteuse_boucle": "ground_dir", # bande du Halage le long de chaque ligne posée
}

## Projectiles ennemis poolés (EnemyProjectilePool) : boss tireur (id du skin) -> [clé du projectile, clé d'impact].
## Source = le boss (Culasse) ou son BarrageEmitter (Mitraille, propriété `boss`).
const ENEMY_PROJ := {
	"flood_gunner": ["flood_gunner/rivet", "flood_gunner/rivet_hit"],
	"smelter": ["smelter/sparks", ""], # Étincelles du Fondeur (6 tirs en éventail, sans impact de test)
}

## Traces (tests) : chaque remplacement {key, src, host}. Vidées par clear_trace().
static var trace_on := false
static var trace: Array[Dictionary] = []
static var _last := {} ## "clé#lanceur" -> temps (s) du dernier effet de test
static var _zone_script: Script = null
static var _tile_cache := {} ## clé -> longueur de tuile (px) ou 0
static var _bounds := PackedVector2Array() ## track_polyline : bornes des tuiles (tampon réutilisé, pas d'allocation)


## Interrupteur effectif (mode test actif + case « VFX de test »).
static func enabled() -> bool:
	return TestMode.active and TestMode.vfx_test


static func clear_trace() -> void:
	trace.clear()
	_last.clear()
	_tile_cache.clear()


static func available(key: String) -> bool:
	return key != "" and VfxTestPlayer.available(key)


# --- Résolution ---------------------------------------------------------------------------------------------

static func _norm(path: String) -> String:
	return path


static func _strip_dir(anim: String) -> String:
	for s in DIR_SUFFIXES:
		if anim.ends_with(s):
			return anim.substr(0, anim.length() - s.length())
	return anim


## Clé d'un .tres d'origine (et de son animation courante), "" si aucune.
static func key_for_path(path: String, anim: StringName = &"") -> String:
	var p := _norm(path)
	if p == "":
		return ""
	var a := String(anim)
	if a != "" and PATHS.has(p + "|" + a):
		return String(PATHS[p + "|" + a])
	if PATHS.has(p):
		return String(PATHS[p])
	return _boss_key(p, a)


static func boss_of_path(p: String) -> String:
	if not p.begins_with(BOSS_DIR):
		return ""
	var parts := p.substr(BOSS_DIR.length()).split("/")
	if parts.size() != 2 or parts[1] != parts[0] + ".tres":
		return ""
	return parts[0]


static func _boss_key(p: String, anim: String) -> String:
	var b := boss_of_path(p)
	if b == "" or anim == "":
		return ""
	var a := _strip_dir(anim)
	var k := "%s/%s" % [b, a]
	if BOSS_ANIMS.has(k):
		var r := String(BOSS_ANIMS[k]) # "" : sprite d'origine gardé ; sinon l'asset dédié, s'il existe, l'emporte
		if r == "" or not available(k):
			return r
	if a == "auto" or a.begins_with("idle") or a.begins_with("walk") or a.begins_with("spell_") or a.begins_with("trans") or a == "death":
		return "" # corps du boss (BossPace.strike fournit l'auto)
	return k


## Clé d'un sort lancé par `caster` (SpellCaster ou objet qui expose `character`).
static func key_for_spell(spell: SpellData, caster: Object) -> String:
	if spell == null:
		return ""
	if spell.has_meta(META_KEY):
		return String(spell.get_meta(META_KEY))
	var cid := _cid(caster)
	if cid != "":
		var k := "%s/%s" % [cid, String(spell.id)]
		if available(k):
			return k
	return ""


static func _cid(caster: Object) -> String:
	if caster == null or not is_instance_valid(caster):
		return ""
	var cd: Variant = caster.get(&"character")
	if cd is CharacterData:
		return String((cd as CharacterData).id)
	return ""


# --- Cacher / montrer l'effet d'origine ------------------------------------------------------------------------

static func hide_original(ci: CanvasItem) -> void:
	if ci == null or ci.has_meta(META_HIDDEN):
		return
	ci.set_meta(META_HIDDEN, ci.self_modulate.a)
	ci.self_modulate.a = 0.0
	var em := ci.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE)) as CanvasItem
	if em != null and not em.has_meta(META_HIDDEN):
		em.set_meta(META_HIDDEN, em.self_modulate.a)
		em.self_modulate.a = 0.0


static func show_original(ci: CanvasItem) -> void:
	if ci == null:
		return
	if ci.has_meta(META_HIDDEN):
		ci.self_modulate.a = float(ci.get_meta(META_HIDDEN))
		ci.remove_meta(META_HIDDEN)
	var em := ci.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE)) as CanvasItem
	if em != null and em.has_meta(META_HIDDEN):
		em.self_modulate.a = float(em.get_meta(META_HIDDEN))
		em.remove_meta(META_HIDDEN)


static func is_hidden(ci: CanvasItem) -> bool:
	return ci != null and ci.has_meta(META_HIDDEN)


static func follower_of(host: Node) -> VfxTestPlayer:
	if host == null or not host.has_meta(META_FOLLOWER):
		return null
	var v: Variant = host.get_meta(META_FOLLOWER)
	if not is_instance_valid(v):
		return null
	var p := v as VfxTestPlayer
	return p if p != null and not p.finished_flag else null


static func _stop_follower(host: Node) -> void:
	var f := follower_of(host)
	if f != null:
		f.stop()
	if host != null:
		host.remove_meta(META_FOLLOWER)
		host.remove_meta(META_CUR)


# --- Création du suiveur -----------------------------------------------------------------------------------------

## VfxTestPlayer accroché sous `host` qui suit sa position globale. `dedup` : un seul effet de cette clé par fenêtre
## DEDUP_S (sorts des personnages : zone + sprite + lancer d'un même coup, pavages, ticks ; jamais pour les
## projectiles ni les sprites de boss, légitimement plusieurs à la fois). Retourne null si la clé n'a pas d'asset
## ou si la fenêtre l'interdit.
static func spawn_follow(host: Node2D, key: String, dir: Vector2, dedup := false, opts := {}) -> VfxTestPlayer:
	if host == null or not is_instance_valid(host) or not available(key):
		return null
	if dedup and not _dedup_ok(key):
		return null
	var o := {"always": false, "follow": host, "z": 0}
	o.merge(opts, true)
	var v := VfxTestPlayer.spawn(host, key, Vector2.ZERO, dir, o) as VfxTestPlayer
	if v == null:
		return null
	host.set_meta(META_FOLLOWER, v)
	host.set_meta(META_CUR, key)
	if trace_on:
		trace.append({"key": key, "host": host.get_path() if host.is_inside_tree() else NodePath(String(host.name)), "src": String(o.get("src", ""))})
	return v


## Direction affichée d'un sprite d'effet : rotation globale (rig TOP tourné vers sa cible), flip_h, sinon droite.
static func _dir_of(n: Node2D) -> Vector2:
	if n == null:
		return Vector2.RIGHT
	if n.has_meta(META_DIR):
		return n.get_meta(META_DIR)
	var r := n.global_rotation
	if absf(r) > 0.001:
		return Vector2.from_angle(r)
	if n is AnimatedSprite2D and (n as AnimatedSprite2D).flip_h:
		return Vector2.LEFT
	if n.global_scale.x < 0.0:
		return Vector2.LEFT
	return Vector2.RIGHT


# --- Accroches ---------------------------------------------------------------------------------------------------

## Tout AnimatedSprite2D branché par EmissiveOverlay.apply ou par une affectation directe de sprite_frames.
static func on_sprite(anim: AnimatedSprite2D, frames: SpriteFrames) -> void:
	if anim == null or frames == null or _excluded(anim):
		return
	var p := _norm(frames.resource_path)
	if boss_of_path(p) != "" and not anim.has_meta(META_WATCH):
		# .tres de boss : l'anim est posée APRÈS apply (puis rejouée : wisp -> wisp_explode) ; on écoute ses changements
		anim.set_meta(META_WATCH, true)
		anim.animation_changed.connect(_reevaluate.bind(anim), CONNECT_DEFERRED) # différé : échelle, offset et rotation posés après l'anim
	# différé (fin de l'image, avant le rendu) : l'émission, l'animation et la meta de clé sont posées après apply
	_reevaluate.call_deferred(anim)


## Corps et objets à ne jamais remplacer (EnemyVisual, joueur, pavage et vfx de zone : on_zone s'en charge).
static func _excluded(anim: Node) -> bool:
	var par := anim.get_parent()
	if par == null:
		return false
	if par is EnemyVisual:
		return true
	if _zone_script == null:
		_zone_script = load(ZONE_SCRIPT)
	return par.get_script() == _zone_script and (anim.name == &"Vfx" or String(anim.name).begins_with("VfxTile"))


## Le sprite ou l'un de ses 3 premiers ancêtres porte la meta de clé (posée au point d'appel, avant setup).
static func _tagged(n: Node) -> Node:
	for i in 4:
		if n == null:
			return null
		if n.has_meta(META_KEY):
			return n
		n = n.get_parent()
	return null


static func _reevaluate(anim: AnimatedSprite2D) -> void:
	if not is_instance_valid(anim) or anim.has_meta(META_MANAGED):
		return
	var key := ""
	if enabled():
		var tagged := _tagged(anim)
		if tagged != null:
			key = String(tagged.get_meta(META_KEY))
		elif anim.sprite_frames != null:
			key = key_for_path(anim.sprite_frames.resource_path, anim.animation)
		if not available(key):
			key = ""
	if key == "" and trace_on and anim.sprite_frames != null:
		trace.append({"miss": "%s|%s" % [_norm(anim.sprite_frames.resource_path), anim.animation], "src": "sprite"})
	var cur := String(anim.get_meta(META_CUR, ""))
	if key == cur and (key == "" or follower_of(anim) != null):
		return
	_stop_follower(anim)
	if key == "":
		show_original(anim)
		return
	hide_original(anim)
	var boss_id := boss_of_path(_norm(anim.sprite_frames.resource_path)) if anim.sprite_frames != null else ""
	var src_anim := "%s/%s" % [boss_id, _strip_dir(String(anim.animation))] if boss_id != "" else ""
	if src_anim == CROSS_SRC and anim.scale.y > 1.0:
		_cross_crest(anim)
		return
	var opts := {"src": "sprite"}
	var dir := _dir_of(anim)
	if boss_id != "":
		opts["hide_with_host"] = true # sprite de boss masqué puis rendu (brume, crue, rayons) : l'effet le suit
		if BOSS_SPRITE_OPTS.has(src_anim):
			opts.merge(BOSS_SPRITE_OPTS[src_anim], true)
		if HOST_RADIUS_K.has(src_anim):
			opts["radius_u"] = absf(anim.global_scale.x) * float(HOST_RADIUS_K[src_anim])
	var usage := VfxTestPlayer.usage_of(key)
	if HOST_LINE.has(src_anim) and usage in VfxTestPlayer.LINE_USAGES:
		var hl: Dictionary = HOST_LINE[src_anim]
		opts["follow_line"] = float(hl["len_px"])
		opts["follow_axis_y"] = true
		opts["follow_centered"] = true
		opts["width_u"] = absf(anim.global_scale.x) * float(hl["width_px"]) / Balance.UNIT_PX
		dir = anim.global_transform.y
	elif usage in VfxTestPlayer.LINE_USAGES:
		# ligne d'origine (fil, racines, langue, rayons) : départ = origine du sprite, direction et longueur relues
		# sur sa transformation globale (VfxTestPlayer opts.follow_line)
		var ll := _host_line_local(anim, key)
		if ll > 0.0:
			opts["follow_line"] = ll
			dir = anim.global_transform.x
		if key in HOST_WIDTH:
			var th := _host_tex_size(anim).y
			if th > 0.0:
				opts["width_u"] = th * absf(anim.global_scale.y) / Balance.UNIT_PX
	if RADIUS_U.has(key):
		opts["radius_u"] = RADIUS_U[key]
	if WIDTH_U.has(key):
		opts["width_u"] = WIDTH_U[key]
	if SPRITE_RADIUS_PX.has(key):
		opts["radius_u"] = absf(anim.global_scale.x) * float(SPRITE_RADIUS_PX[key]) / Balance.UNIT_PX
	if anim.has_meta(META_RADIUS):
		opts["radius_u"] = float(anim.get_meta(META_RADIUS))
	spawn_follow(anim, key, dir, boss_id == "", opts)


## Longueur locale (px) de la ligne dessinée par un sprite d'origine, mesurée depuis son origine (= le pivot) :
## fin de la planche (offset compris) ou LINE_LOCAL_PX ; 0 si inconnue.
static func _host_line_local(anim: AnimatedSprite2D, key: String) -> float:
	if LINE_LOCAL_PX.has(key):
		return float(LINE_LOCAL_PX[key])
	var tw := _host_tex_size(anim).x
	if tw <= 0.0:
		return 0.0
	return maxf(anim.offset.x + (tw * 0.5 if anim.centered else tw), 0.0)


## Taille de la planche courante d'un sprite (px, 0 si inconnue).
static func _host_tex_size(anim: AnimatedSprite2D) -> Vector2:
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim.animation):
		return Vector2.ZERO
	var tex := anim.sprite_frames.get_frame_texture(anim.animation, 0)
	return tex.get_size() if tex != null else Vector2.ZERO


## Bras de la croix de l'Éclusier : une crête par bras, orientée sur le bras, à la largeur du bras, qui file du boss
## au bout du bras (le sprite d'origine, centré sur le bras, est caché et libéré par son cerveau).
static func _cross_crest(anim: AnimatedSprite2D) -> void:
	anim.set_meta(META_CUR, CROSS_KEY)
	if not available(CROSS_KEY) or anim.get_parent() == null:
		return
	var d := Vector2.from_angle(anim.global_rotation + PI * 0.5) # ground_wave : bras le long de l'axe y local
	var start := anim.global_position - d * EclusierBrain.CROSS_LEN_U * Balance.UNIT_PX * 0.5
	var v := VfxTestPlayer.spawn(anim.get_parent(), CROSS_KEY, start, d, {
		"always": false, "z": 0, "width_u": EclusierBrain.CROSS_W_U,
		"move_speed_u": EclusierBrain.CROSS_LEN_U / CROSS_CREST_S, "move_range_u": EclusierBrain.CROSS_LEN_U,
	})
	if v != null and trace_on:
		trace.append({"key": CROSS_KEY, "host": NodePath(), "src": "cross"})


## Zone (ZoneEffect) : un seul effet de test par zone, suit le nœud de la zone ; vfx et pavage cachés.
static func on_zone(zone: Node2D) -> void:
	var spell: SpellData = zone.get(&"spell")
	var caster: Object = zone.get(&"caster")
	var key := ""
	if zone.has_meta(META_KEY):
		key = String(zone.get_meta(META_KEY))
	elif spell != null and PATHS_FIRST.has(_norm(spell.vfx_frames)):
		key = String(PATHS_FIRST[_norm(spell.vfx_frames)])
	else:
		key = key_for_spell(spell, caster)
		if key == "" and spell != null and not spell.has_meta(META_KEY):
			key = key_for_path(spell.vfx_frames)
	if not available(key):
		if trace_on and spell != null:
			trace.append({"miss": "zone %s/%s %s" % [_cid(caster), spell.id, spell.vfx_frames], "src": "zone"})
		return
	var vfx := zone.get(&"vfx") as AnimatedSprite2D
	if vfx != null:
		vfx.set_meta(META_MANAGED, true)
		hide_original(vfx)
	for t in zone.get(&"_tiles"):
		hide_original(t as CanvasItem)
	var dir := Vector2.RIGHT
	if float(zone.get(&"arc_half")) < PI:
		dir = zone.get(&"arc_dir")
	elif caster != null and is_instance_valid(caster) and caster.get(&"player") is Node2D:
		var d: Vector2 = zone.global_position - (caster.get(&"player") as Node2D).global_position
		if d.length_squared() > 4.0:
			dir = d.normalized()
	var opts := {"src": "zone"}
	var r: Variant = zone.get(&"radius")
	if VfxTestPlayer.usage_of(key) in VfxTestPlayer.RADIUS_USAGES and (r is float or r is int) and float(r) > 0.0:
		opts["radius_u"] = float(r) / Balance.UNIT_PX # rayon réel de la zone (bonus de taille compris)
	spawn_follow(zone, key, dir, not key in NO_DEDUP, opts)


## Projectile (poolé) : à chaque lancement, l'ancien effet de test est arrêté, le visuel rendu, puis réévalué.
static func on_projectile(proj: Node2D, visual: AnimatedSprite2D) -> void:
	if visual == null:
		return
	visual.set_meta(META_MANAGED, true)
	_stop_follower(visual)
	show_original(visual)
	if not enabled():
		return
	var spell: SpellData = proj.get(&"spell")
	var key := key_for_spell(spell, proj.get(&"caster"))
	if key == "" and spell != null and not spell.has_meta(META_KEY):
		key = key_for_path(spell.projectile_frames)
		if key == "" and spell.projectile_frames == "":
			key = _default_projectile_key(proj.get(&"caster"))
	if not available(key):
		if trace_on and spell != null:
			trace.append({"miss": "proj %s/%s %s" % [_cid(proj.get(&"caster")), spell.id, spell.projectile_frames], "src": "projectile"})
		return
	hide_original(visual)
	spawn_follow(visual, key, proj.get(&"direction"), false, {"src": "projectile"})


## Éclat de braise de la scène (projectile sans frames propres) : sort 1 d'Ardent.
static func _default_projectile_key(caster: Object) -> String:
	return "ardent/eclat_de_braise" if _cid(caster) == "ardent" else ""


## Lancer d'un sort de kit sans visuel accrochable (table CAST) : effet posé au lancement.
static func on_cast(caster: Object, spell: SpellData, aim_dir: Vector2, fx_pos: Vector2) -> void:
	if spell == null or caster == null:
		return
	var key := String(spell.get_meta(META_KEY)) if spell.has_meta(META_KEY) else "%s/%s" % [_cid(caster), String(spell.id)]
	if not CAST.has(key) or not available(key):
		if trace_on:
			trace.append({"miss": "cast " + key, "src": "cast"})
		return
	var player := caster.get(&"player") as Node2D
	if player == null:
		return
	var dir := aim_dir.normalized() if aim_dir.length_squared() > 1.0 else Vector2.ZERO
	var target: Node2D = null
	if caster.has_method(&"nearest_enemy"):
		target = caster.call(&"nearest_enemy", 10.0 * Balance.UNIT_PX) as Node2D
	if dir == Vector2.ZERO:
		if target != null:
			dir = (target.global_position - player.global_position).normalized()
		else:
			var f: Variant = player.get(&"facing")
			dir = (f as Vector2).normalized() if f is Vector2 and (f as Vector2) != Vector2.ZERO else Vector2.RIGHT
	if String(VfxTestPlayer.resolve(key).get("projection", "")) == "projectile":
		# projectile de test (sans hôte) : part du joueur et vole seul vers la visée
		if not _dedup_ok(key):
			return
		var par: Node = caster.call(&"effects_parent") if caster.has_method(&"effects_parent") else player.get_parent()
		var v := VfxTestPlayer.spawn(par, key, player.global_position + Vector2(0.0, Iso.lift_logical(0.5)), dir, {"always": false, "z": 0})
		if v != null and trace_on:
			trace.append({"key": key, "host": NodePath(), "src": "cast"})
		return
	if String(CAST[key]) == "player":
		var max_s := CAST_MAX_S
		if VfxTestPlayer.usage_of(key) == "follow_ground_loop" and spell.duration > 0.0:
			max_s = spell.duration # zone au sol qui suit le joueur tant que dure l'état (Marée de vase)
		# flaque sous les pieds : dessinée sous le personnage (sinon elle le recouvre)
		spawn_follow(player, key, dir, true, {"src": "cast", "max_s": max_s, "z": -1 if key in UNDER_PLAYER else 0})
		return
	var parent: Node = caster.call(&"effects_parent") if caster.has_method(&"effects_parent") else player.get_parent()
	if parent == null:
		return
	var at := fx_pos
	if at.distance_squared_to(player.global_position) < 4.0:
		at = target.global_position if target != null else player.global_position + dir * 3.0 * Balance.UNIT_PX
	_spawn_anchored(parent, key, at, dir, true, "cast")


static func _dedup_ok(key: String) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if _last.has(key) and now - float(_last[key]) < DEDUP_S:
		return false
	_last[key] = now
	return true


## Effet posé au sol en `at` : un porteur invisible (Node2D) libéré avec l'effet ; durée bornée à CAST_MAX_S.
static func _spawn_anchored(parent: Node, key: String, at: Vector2, dir: Vector2, dedup: bool, src: String, opts := {}) -> VfxTestPlayer:
	var anchor := Node2D.new()
	anchor.name = "VfxSwapAnchor"
	parent.add_child(anchor)
	anchor.global_position = at
	var o := {"src": src, "max_s": CAST_MAX_S}
	o.merge(opts, true)
	var v := spawn_follow(anchor, key, dir, dedup, o)
	if v == null:
		anchor.queue_free()
		return null
	v.finished.connect(func(_p: VfxTestPlayer) -> void:
		if is_instance_valid(anchor):
			anchor.queue_free())
	return v


## Coup automatique d'un boss d'étage (BossPace.strike(&"auto")) : aucun VFX d'origine, effet ajouté sur le boss.
static func on_boss_auto(e: Node2D) -> void:
	if e == null or not is_instance_valid(e):
		return
	var bid := String(e.get(&"_boss_sprite_id"))
	var key := String(AUTO.get(bid, "%s/auto" % bid))
	if bid == "" or not available(key):
		return
	var dir := Vector2.RIGHT
	var brain: Variant = e.get(&"brain")
	if brain is HermitCedarBrain and (brain as HermitCedarBrain).state == HermitCedarBrain.S.TENDRIL:
		return # vrille du Cèdre (coup auto de phase 2) : sa racine (hermit_cedar/root_spike) est déjà l'effet du coup
	if brain is CerfBrain and (brain as CerfBrain).state == CerfBrain.S.AUTO:
		return # tir de follet du Cerf (coup auto de loin) : le follet (cerf/wisp_bolt) est l'effet, pas le coup de bois
	if brain is RainSowerBrain and (brain as RainSowerBrain).state == RainSowerBrain.S.WHIRL:
		key = "rain_sower/whirl" # coup auto de phase 3 : tourbillon (disque de WHIRL_R_U autour d'elle), pas le fouet
		if not available(key):
			return
	if brain != null and brain is Object and (brain as Object).get(&"aim") is Vector2:
		dir = (brain as Object).get(&"aim")
	spawn_follow(e, key, dir, false, {"src": "boss_auto", "max_s": AUTO_MAX_S})


## Apparition explicite (effets sans VFX d'origine, appelée par un cerveau ou un kit) : effet posé au sol en `pos`
## (classe projectile : vole seul depuis `pos` vers `dir`). `placeholder` : visuel provisoire dessiné en code à masquer
## (self_modulate.a = 0 ; il continue de vivre et de s'effacer comme avant). `opts` : options de VfxTestPlayer.spawn
## (max_s, scale_mult, speed_u, range_u…) ; anchored = true : un effet de classe projectile reste posé en `pos`
## (orienté vers `dir`, sans déplacement propre : coulée, traînée).
static func spawn_at(parent: Node, key: String, pos: Vector2, dir: Vector2, placeholder: CanvasItem = null, opts := {}) -> VfxTestPlayer:
	if not enabled() or parent == null or not available(key):
		return null
	if placeholder != null:
		hide_original(placeholder)
	var o := opts.duplicate()
	var anchored := bool(o.get("anchored", false))
	o.erase("anchored")
	if not anchored and String(VfxTestPlayer.resolve(key).get("projection", "")) == "projectile":
		var po := {"always": false, "z": 0}
		po.merge(o, true)
		var v := VfxTestPlayer.spawn(parent, key, pos, dir, po) as VfxTestPlayer
		if v != null and trace_on:
			trace.append({"key": key, "host": NodePath(), "src": "spawn_at"})
		return v
	return _spawn_anchored(parent, key, pos, dir, false, "spawn_at", o)


## Projectile de test qui part de `from` et arrive en `to` en `secs` s (obus en cloche : vitesse et portée ajustées).
static func spawn_travel(parent: Node, key: String, from: Vector2, to: Vector2, secs: float) -> VfxTestPlayer:
	var d := to - from
	var dist_u := d.length() / Balance.UNIT_PX
	if dist_u < 0.05:
		return spawn_at(parent, key, to, Vector2.RIGHT)
	return spawn_at(parent, key, from, d / (dist_u * Balance.UNIT_PX), null,
		{"speed_u": dist_u / maxf(secs, 0.05), "range_u": dist_u})


# --- Effets « tant que » (état d'un cerveau : rechargement…) ------------------------------------------------------

## Tant que `on`, un VfxTestPlayer `key` suit `host` (créé au front montant, arrêté au front descendant). `max_s` borne
## sa vie : l'interrupteur coupé en cours d'état ne laisse rien derrière. Aucun travail si `on` est faux et rien n'est suivi.
static func follow_while(host: Node2D, key: String, on: bool, dir := Vector2.RIGHT, max_s := CAST_MAX_S, offset := Vector2.ZERO) -> void:
	if host == null or not is_instance_valid(host):
		return
	if not on and not host.has_meta(META_WHILE):
		return
	var cur: Dictionary = host.get_meta(META_WHILE) if host.has_meta(META_WHILE) else {}
	var v: Variant = cur.get(key, null)
	var live: bool = v != null and is_instance_valid(v) and not (v as VfxTestPlayer).finished_flag
	if on and enabled():
		if live or not available(key):
			return
		var o := {"always": false, "follow": host, "follow_offset": offset, "z": 0, "max_s": max_s}
		var p := VfxTestPlayer.spawn(host, key, Vector2.ZERO, dir, o) as VfxTestPlayer
		if p == null:
			return
		cur[key] = p
		host.set_meta(META_WHILE, cur)
		if trace_on:
			trace.append({"key": key, "host": host.get_path() if host.is_inside_tree() else NodePath(String(host.name)), "src": "while"})
		return
	if live:
		(v as VfxTestPlayer).stop()
	cur.erase(key)
	if cur.is_empty():
		host.remove_meta(META_WHILE)


# --- Effets multi-points (permanents, dessinés en code) -------------------------------------------------------------

## Cache tout un visuel (modulate : enfants compris, ex. les deux Line2D d'une chaîne).
static func hide_whole(ci: CanvasItem) -> void:
	if ci == null or ci.has_meta(META_HIDDEN_MOD):
		return
	ci.set_meta(META_HIDDEN_MOD, ci.modulate.a)
	ci.modulate.a = 0.0


static func show_whole(ci: CanvasItem) -> void:
	if ci == null or not ci.has_meta(META_HIDDEN_MOD):
		return
	ci.modulate.a = float(ci.get_meta(META_HIDDEN_MOD))
	ci.remove_meta(META_HIDDEN_MOD)


## Accroche des effets permanents : vrai si l'hôte doit être tenu à jour (interrupteur allumé, ou effets à rendre).
static func points_on(owner: Node) -> bool:
	return enabled() or (owner != null and owner.has_meta(META_POINTS))


## Orbes en orbite (Braises errantes) : un effet de test par orbe, orienté sur la tangente (sens de rotation),
## à `lift` px logiques au-dessus du sol. Le dessin d'origine (`owner`, _draw) est caché (self_modulate).
static func track_orbit(owner: Node2D, key: String, pts: Array[Vector2], center: Vector2, lift: float) -> void:
	var anchors := _sync_points(owner, key, pts.size(), owner, false)
	for i in anchors.size():
		var a := anchors[i] as Node2D
		a.global_position = pts[i] + Vector2(0.0, lift)
		var r := pts[i] - center
		_feed_point(a, key, Vector2(-r.y, r.x))


## Polyligne posée au sol (chaîne) : effets répartis tous les POINT_SPACING[key] u (POINTS_MAX au plus), orientés le
## long des segments. Effet `tile_along_line` (meta usage, segment_u) : une tuile tous les segment_u, posée bout à bout
## depuis le début de la polyligne et tournée sur son tronçon, la dernière mise à l'échelle du reste (TILES_MAX au plus).
## `original` (nœud de la chaîne) est caché en entier (modulate : ses Line2D comprises).
static func track_polyline(owner: Node2D, key: String, poly: PackedVector2Array, original: CanvasItem) -> void:
	var total := 0.0
	for i in range(1, poly.size()):
		total += poly[i - 1].distance_to(poly[i])
	var seg_px := _tile_segment_px(key) if enabled() else 0.0
	var tiled := seg_px > 0.0
	var lay := Vector2.ZERO
	var n := 0
	if tiled:
		lay = VfxTestPlayer.tile_layout(total, seg_px)
		n = 0 if poly.size() < 2 or total < 0.25 * Balance.UNIT_PX else mini(int(lay.x), TILES_MAX)
	else:
		var spacing := float(POINT_SPACING.get(key, POINT_SPACING_U)) * Balance.UNIT_PX
		n = 0 if poly.size() < 2 or total < 0.5 * Balance.UNIT_PX else clampi(int(total / spacing), 1, POINTS_MAX)
	var anchors := _sync_points(owner, key, n, original, true, TILES_MAX if tiled else POINTS_MAX)
	if anchors.is_empty():
		return
	# échantillons le long de la polyligne (un seul passage). Tuiles : bornes à k × segment_u (la dernière au bout de
	# la chaîne) ; chaque tuile va d'une borne à la suivante (corde : ni trou ni chevauchement dans les virages).
	var m := anchors.size()
	var count := m + 1 if tiled else m
	_bounds.resize(count)
	var seg := 1
	var acc := 0.0
	for k in count:
		var want := (float(k) + 0.5) * total / float(m)
		if tiled:
			want = total if k == m and m == int(lay.x) else minf(seg_px * k, total)
		while seg < poly.size() - 1 and acc + poly[seg - 1].distance_to(poly[seg]) < want:
			acc += poly[seg - 1].distance_to(poly[seg])
			seg += 1
		var a0 := poly[seg - 1]
		var a1 := poly[seg]
		var l := a0.distance_to(a1)
		var t := clampf((want - acc) / l, 0.0, 1.0) if l > 0.001 else 0.0
		_bounds[k] = a0.lerp(a1, t)
		if not tiled:
			var anc := anchors[k] as Node2D
			anc.global_position = _bounds[k]
			_feed_point(anc, key, (a1 - a0) if l > 0.001 else Vector2.RIGHT)
	if tiled:
		for k in m:
			var anc := anchors[k] as Node2D
			anc.global_position = _bounds[k]
			var chord := _bounds[k + 1] - _bounds[k]
			_feed_point(anc, key, chord, maxf(chord.length(), 1.0))


## Longueur (px) d'une tuile `tile_along_line` de `key` (segment_u du meta), 0 si l'effet n'est pas tuilé ou absent.
## Mise en cache : track_polyline est appelé à chaque image.
static func _tile_segment_px(key: String) -> float:
	if not _tile_cache.has(key):
		var seg := 0.0
		if available(key) and VfxTestPlayer.usage_of(key) == "tile_along_line":
			var m := VfxTestPlayer.load_meta(String(VfxTestPlayer.resolve(key).get("asset_key", key)))
			seg = float(m.get("segment_u", 2.0)) * Balance.UNIT_PX
		_tile_cache[key] = seg
	return float(_tile_cache[key])


## Porteurs (Node2D sous `owner`) au nombre de `n` ; libère tout et rend l'original si l'interrupteur est coupé ou
## si l'asset manque. Retourne les porteurs à placer (vide = rien à faire).
static func _sync_points(owner: Node2D, key: String, n: int, original: CanvasItem, whole: bool, cap := POINTS_MAX) -> Array:
	if owner == null or not is_instance_valid(owner):
		return []
	var st: Dictionary = owner.get_meta(META_POINTS) if owner.has_meta(META_POINTS) else {}
	if not st.is_empty() and String(st.get("key", "")) != key:
		release_points(owner) # variante changée : on repart de zéro
		st = {}
	if not enabled() or not available(key):
		release_points(owner)
		return []
	if st.is_empty():
		st = {"anchors": [], "key": key, "original": original, "whole": whole}
		owner.set_meta(META_POINTS, st)
	if whole:
		hide_whole(original)
	else:
		hide_original(original)
	var anchors: Array = st["anchors"]
	n = mini(n, cap)
	while anchors.size() > n:
		_free_anchor(anchors.pop_back())
	while anchors.size() < n:
		var a := Node2D.new()
		a.name = "VfxSwapPoint"
		owner.add_child(a)
		anchors.append(a)
	return anchors


## Effet de test du porteur (recréé s'il a fini : asset sans boucle, gerbe répétée) et orientation suivant `d`.
## `line_px` > 0 : tuile `tile_along_line` de cette longueur.
static func _feed_point(a: Node2D, key: String, d: Vector2, line_px := 0.0) -> void:
	var dir := d.normalized() if d.length_squared() > 0.0001 else Vector2.RIGHT
	var f := follower_of(a)
	if f == null:
		var o := {"src": "points"}
		if POINT_PROJECTION.has(key):
			o["projection"] = POINT_PROJECTION[key]
		if line_px > 0.0:
			o["line_px"] = line_px
		if POINT_WIDTH_U.has(key):
			o["width_u"] = POINT_WIDTH_U[key]
		spawn_follow(a, key, dir, false, o)
		return
	if line_px > 0.0:
		if not dir.is_equal_approx(f.dir) or absf(line_px - f.line_px) > 0.5:
			f.set_line(dir, line_px)
	else:
		f.set_dir(dir)


static func _free_anchor(a: Variant) -> void:
	if a == null or not is_instance_valid(a):
		return
	var f := follower_of(a as Node)
	if f != null:
		f.stop()
	(a as Node).queue_free()


## Libère les effets multi-points de `owner` et rend son visuel d'origine.
static func release_points(owner: Node) -> void:
	if owner == null or not owner.has_meta(META_POINTS):
		return
	var st: Dictionary = owner.get_meta(META_POINTS)
	owner.remove_meta(META_POINTS)
	for a in st.get("anchors", []):
		_free_anchor(a)
	var orig: Variant = st.get("original", null)
	if orig != null and is_instance_valid(orig):
		if bool(st.get("whole", false)):
			show_whole(orig as CanvasItem)
		else:
			show_original(orig as CanvasItem)


# --- Projectiles ennemis poolés (EnemyProjectilePool) ------------------------------------------------------------

## Au tir (pool) : rend le visuel du projectile recyclé, puis, interrupteur allumé et tireur listé dans ENEMY_PROJ,
## le cache sous un effet de test qui le suit (libéré quand le pool masque le projectile). Hors mode test, le pool
## n'appelle ceci que pour un projectile encore marqué (META_POOLED).
static func on_enemy_projectile(p: Node2D, source: Node2D, velocity: Vector2) -> void:
	if p == null:
		return
	var vis := p.get_node_or_null(^"Visual") as CanvasItem
	if p.has_meta(META_POOLED):
		p.remove_meta(META_POOLED)
		_stop_follower(p)
		show_original(vis)
	if not enabled():
		return
	var keys: Array = ENEMY_PROJ.get(_shooter_id(source), [])
	if keys.is_empty() or not available(String(keys[0])):
		return
	hide_original(vis)
	p.set_meta(META_POOLED, String(keys[1]) if keys.size() > 1 else "")
	spawn_follow(p, String(keys[0]), velocity, false, {"src": "enemy_projectile"})


## À la libération (pool, interrupteur allumé) : impact de test là où le projectile s'arrête (joueur, doublure, mur,
## abri), jamais en bout de course (durée de vie écoulée) ni au nettoyage de fin d'étage (clear_all) : `expired`.
static func on_enemy_projectile_end(p: Node2D, expired: bool) -> void:
	if p == null or not p.has_meta(META_POOLED):
		return
	var hit := String(p.get_meta(META_POOLED))
	if expired or hit == "" or not available(hit) or p.get_parent() == null:
		return
	var vel: Variant = p.get(&"velocity")
	var dir: Vector2 = (vel as Vector2) if vel is Vector2 and (vel as Vector2).length_squared() > 0.01 else Vector2.RIGHT
	var v := spawn_at(p.get_parent(), hit, p.global_position, dir) # gerbe orientée dans le sens du tir
	if v != null and trace_on:
		trace.append({"key": hit, "host": NodePath(), "src": "enemy_projectile_hit"})


## Id du boss tireur : l'ennemi lui-même ou le porteur d'un émetteur (BarrageEmitter.boss).
static func _shooter_id(source: Node2D) -> String:
	if source == null or not is_instance_valid(source):
		return ""
	var s: Object = source
	if not (s is Enemy):
		var b: Variant = source.get(&"boss")
		if not (b is Enemy) or not is_instance_valid(b):
			return ""
		s = b
	return String(s.get(&"_boss_sprite_id"))
