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
##   3. table PATHS (chemin d'origine du .tres, `_cel` normalisé ; "chemin|anim" pour une anim précise) ;
##   4. .tres d'un boss d'étage : "<boss_id>/<anim sans suffixe de direction>" via BOSS_ANIMS (corps exclus) ;
## et seulement si l'asset de test existe (VfxTestPlayer.available).
##
## Accroches (hors mode test : un test de booléen) :
##   scripts/fx/emissive_overlay.gd       apply()          -> on_sprite (tout VFX passé par l'émission)
##   scripts/spells/zone_effect.gd        setup()          -> on_zone (après _setup_vfx)
##   scripts/spells/projectile.gd         launch()         -> on_projectile (pool : réévalué à chaque lancement)
##   scripts/spells/spell_caster.gd       _cast()          -> on_cast (sorts de kit sans visuel accrochable, table CAST)
##   scripts/enemies/boss_pace.gd         strike(&"auto")  -> on_boss_auto (table AUTO pour les boss sans "<id>/auto")
##   affectations directes de sprite_frames -> on_sprite : ardent_phoenix, rictus_kit (spin_blur), rictus_pendulum,
##   tocsin_kit (regen), salt_king_brain (edict_ring), raid_fx.
##   apparitions explicites (aucun VFX d'origine) -> spawn_at : jar_bearer (mother_jar_blast), salt_king
##   (procession_tide), flood_gunner (shell_crater), drowned_idol (chaplet_circle, noria_wheel), smelter (sparks).
##   meta de clé au point d'appel : vigie_kit (Fanal, Tir de signal : fusée partagée FLARE_FRAMES).
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

const BOSS_DIR := "res://assets/sprites/bosses/etage/"
const ZONE_SCRIPT := "res://scripts/spells/zone_effect.gd"
const DIR_SUFFIXES := ["_n", "_ne", "_e", "_se", "_s", "_sw", "_w", "_nw"]

## Chemin d'origine du .tres (normalisé, sans `_cel`) -> clé. "chemin|anim" : seulement pour cette animation.
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
	"res://assets/sprites/characters/rictus/spin_blur/spin_blur.tres": "rictus/rictus_toupie",
	"res://assets/sprites/characters/rictus/knife/knife.tres": "rictus/couteau_ficele",
	"res://assets/sprites/characters/rictus/variants/pendulum_knife/pendulum_knife.tres": "rictus/couteau_ficele",
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
	"res://assets/sprites/characters/arpenteuse/effects/loop_blaze.tres": "arpenteuse/arpenteuse_boucle",
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
	"res://assets/sprites/characters/bourbe/variants/mud_glob/mud_glob.tres": "bourbe/bourbe_crachat_de_vase",
	"res://assets/sprites/characters/bourbe/variants/mud_burst/mud_burst.tres": "bourbe/bourbe_eclatement",
	# Vigie
	"res://assets/sprites/characters/vigie/arrow/arrow.tres": "vigie/vigie_trait",
	"res://assets/sprites/characters/vigie/arrow_charged/arrow_charged.tres": "vigie/vigie_trait_charge",
	"res://assets/sprites/characters/vigie/flare_arrow/flare_arrow.tres": "vigie/vigie_fusee",
	"res://assets/sprites/characters/vigie/net_arrow/net_arrow.tres": "vigie/vigie_filet",
	"res://assets/sprites/characters/vigie/net_burst/net_burst.tres": "vigie/vigie_filet",
	"res://assets/sprites/characters/vigie/hail_zone/hail_zone.tres": "vigie/vigie_grele",
	"res://assets/sprites/characters/vigie/caltrop_field/caltrop_field.tres": "vigie/vigie_chausse_trapes",
	"res://assets/sprites/characters/vigie/flare/flare.tres": "vigie/vigie_fusee",
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
	"cerf/wisp": "cerf/wisp_bolt",
	"crane/container": "crane/container_impact",
	"crane/boom_shadow": "crane/sweep",
	"crystal_mother/orbit_shard": "crystal_mother/shard",
	"deep_eel/puddle": "deep_eel/black_pool",
	"drowned_idol/lotus_crack": "drowned_idol/prayer_flood",
	"eclusier/ground_wave": "eclusier/ground_water",
	"eclusier/ground_geyser": "eclusier/geyser",
	"jar_bearer/jar": "jar_bearer/orbit",
	"ox_herder/mud_wave": "ox_herder/dust_burst",
	"rain_sower/raindrop": "rain_sower/rain_column",
	"rain_sower/flood_water": "rain_sower/wave_front",
	"recluse/prayer_glyph": "recluse/prayer_burst",
	"salt_king/edict": "salt_king/edict_ring",
	"smelter/splash": "smelter/molten_pool",
	"smelter/steam_vent": "sonneur/steam_jet",
	"sonneur/ground_steam": "sonneur/steam_jet",
	"sonneur/steam_vent": "sonneur/steam_jet",
	"sonneur/bolt": "sonneur/bolt_rain",
	"sonneur/ground_lightning": "sonneur/lightning",
	"weaver/drop": "weaver/drop_dust",
	"weaver/ground_silk": "weaver/web_ring",
	"weaver/web": "weaver/web_ring",
}

## Coup auto d'un boss sans dossier "<boss>/auto" : clé de remplacement.
const AUTO := {
	"salt_king": "salt_king/scepter",
	"flood_gunner": "flood_gunner/volley_cone", # Culasse : éclair de bouche (les rivets sont des projectiles ennemis)
}

## Sorts de kit dont le visuel n'est ni une zone, ni un projectile, ni un sprite accrochable (dessiné en code,
## corps du personnage, membres…) : l'effet de test part au lancement. at : "player" (suit le joueur) ou "aim"
## (posé au point visé ou sur l'ennemi le plus proche).
const CAST := {
	"ardent/roaming_embers": "player",
	"arpenteuse/arpenteuse_chaine": "player",
	"arpenteuse/arpenteuse_chaine_lestee": "player",
	"arpenteuse/arpenteuse_tendeur": "player",
	"arpenteuse/arpenteuse_noeud": "aim",
	"arpenteuse/arpenteuse_jalons": "aim",
	"arpenteuse/arpenteuse_cerceau": "player",
	"averse/averse_gouttiere": "aim",
	"avare/avare_coffre_belier": "player",
	"avare/avare_saisie": "aim",
	"avare/avare_tresor_enterre": "aim",
	"bourbe/detacher": "aim",
	"bourbe/bourbe_bouture": "aim",
	"bourbe/rappel": "player",
	"bourbe/bourbe_maree_de_vase": "player",
	"morfil/aiguisage": "player",
	"morfil/morfil_affutage_en_marche": "player",
	"morfil/morfil_trempe": "player",
	"morfil/lames_jumelles": "player",
	"morfil/morfil_fendoir": "player",
	"rictus/doublures": "player",
	"tocsin/tocsin_coup_de_tocsin": "player",
	"avare/avare_piece_truquee": "player",
	"rainette/rainette_bulle": "aim",
	"rictus/rictus_saccade": "player",
	"rictus/rictus_rideau": "player",
	"tocsin/tocsin_bras_pilier": "aim",
	"tocsin/tocsin_vapeur": "player",
	"tocsin/tocsin_tete_fumigene": "aim",
}

## Traces (tests) : chaque remplacement {key, src, host}. Vidées par clear_trace().
static var trace_on := false
static var trace: Array[Dictionary] = []
static var _last := {} ## "clé#lanceur" -> temps (s) du dernier effet de test
static var _zone_script: Script = null


## Interrupteur effectif (mode test actif + case « VFX de test »).
static func enabled() -> bool:
	return TestMode.active and TestMode.vfx_test


static func clear_trace() -> void:
	trace.clear()
	_last.clear()


static func available(key: String) -> bool:
	return key != "" and VfxTestPlayer.available(key)


# --- Résolution ---------------------------------------------------------------------------------------------

static func _norm(path: String) -> String:
	return RenderStyle.original_path(path) if path != "" else ""


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
		return String(BOSS_ANIMS[k])
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
		anim.animation_changed.connect(_reevaluate.bind(anim))
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
	var boss := anim.sprite_frames != null and boss_of_path(_norm(anim.sprite_frames.resource_path)) != ""
	spawn_follow(anim, key, _dir_of(anim), not boss, {"src": "sprite"})


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
	spawn_follow(zone, key, dir, true, {"src": "zone"})


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
		spawn_follow(player, key, dir, true, {"src": "cast", "max_s": CAST_MAX_S})
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
static func _spawn_anchored(parent: Node, key: String, at: Vector2, dir: Vector2, dedup: bool, src: String) -> VfxTestPlayer:
	var anchor := Node2D.new()
	anchor.name = "VfxSwapAnchor"
	parent.add_child(anchor)
	anchor.global_position = at
	var v := spawn_follow(anchor, key, dir, dedup, {"src": src, "max_s": CAST_MAX_S})
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
	if brain != null and brain is Object and (brain as Object).get(&"aim") is Vector2:
		dir = (brain as Object).get(&"aim")
	spawn_follow(e, key, dir, false, {"src": "boss_auto", "max_s": AUTO_MAX_S})


## Apparition explicite (effets sans VFX d'origine, appelée par un cerveau ou un kit) : effet posé au sol en `pos`
## (classe projectile : vole seul depuis `pos` vers `dir`). `placeholder` : visuel provisoire dessiné en code à masquer
## (self_modulate.a = 0 ; il continue de vivre et de s'effacer comme avant).
static func spawn_at(parent: Node, key: String, pos: Vector2, dir: Vector2, placeholder: CanvasItem = null) -> VfxTestPlayer:
	if not enabled() or parent == null or not available(key):
		return null
	if placeholder != null:
		hide_original(placeholder)
	if String(VfxTestPlayer.resolve(key).get("projection", "")) == "projectile":
		var v := VfxTestPlayer.spawn(parent, key, pos, dir, {"always": false, "z": 0})
		if v != null and trace_on:
			trace.append({"key": key, "host": NodePath(), "src": "spawn_at"})
		return v
	return _spawn_anchored(parent, key, pos, dir, false, "spawn_at")
