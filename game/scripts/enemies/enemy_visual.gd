class_name EnemyVisual
extends Node2D
## Visuel d'un monstre. Tiers avec sprites Blender : AnimatedSprite2D (+ émission), SpriteFrames
## partagés (une ressource pour toutes les instances). Sinon : placeholder dessiné (formes).
## Interface (inchangée) :
##   configure(tier: int, radius_px: float, is_boss: bool, variant := 0, boss_id := &"")  (tier 2 : 1 = bondisseur)
##   set_phase(p: int)          boss : phase 1..3 (anim de transition puis variantes _pN du boss d'étage)
##   set_action(&"idle"|&"attack"|&"cast_a"|&"cast_b") boss : anims d'attaque/sort (cast tenu jusqu'à run/idle)
##   set_action(&"run" | &"charge")  animation jouée (charge : bondisseur pendant télégraphe et course)
##   set_flash(on: bool)        flash blanc au coup (shader partagé, drapeau par modulation)
##   set_charge(level: int)     armement d'un coup : 0 rien, 1 teinte chaude, 2 éclat (visée verrouillée)
##   set_facing(angle: float)   orientation vers la cible (radians, angle LOGIQUE : Design_Isometrique §2.6)
##   play_attack(action, impact_in, dir)  boss : coup armé, frame d'impact calée sur impact_in (s)
##   boss_tick(delta)           boss : fente / fin du coup (appelé par Enemy.tick)
##   set_frozen(on: bool)       hitstop : animation en pause
## Table tier -> sprites : si assets/sprites/monsters/<nom>/<nom>.tres existe, il est utilisé
## automatiquement. Échelle/pivot : 1 u = 64 px ; offset_y place les pieds à l'origine du nœud.

const TIER_COLORS := {
	1: Color(0.85, 0.30, 0.28), # essaim : rouge
	2: Color(0.62, 0.36, 0.78), # tireur : violet
	3: Color(0.58, 0.42, 0.24), # brute : brun
	4: Color(0.70, 0.06, 0.16), # boss : cramoisi
}
const MONSTER_DIR := "res://assets/sprites/monsters/"
## clé de sprite (tier, ou LEAPER_KEY) -> {name, scale, offset_y (px de la frame, avant échelle), energy}
const LEAPER_KEY := 21 ## tier 2, variante bondisseur
const SPRITES := {
	1: {"name": "swarm_tier1", "scale": 0.8, "offset_y": -36.0, "energy": 2.0, "render_px_per_u": Iso.RENDER_PX_PER_U},   # ~0,8 u de large ; rendu iso C5
	2: {"name": "shooter_tier2", "scale": 0.9, "offset_y": -32.0, "energy": 2.0},
	3: {"name": "brute_tier3", "scale": 0.85, "offset_y": -50.0, "energy": 2.0},
	LEAPER_KEY: {"name": "leaper_tier2", "scale": 0.8, "offset_y": -40.0, "energy": 2.0}, # frames 112 px
}
## --- Boss : sprites Blender par identifiant (dossier sous assets/sprites/bosses/).
## dim = grande dimension (px de frame) de la silhouette, moyenne repos/marche ; bottom = ligne des pieds (px de frame),
## fh = hauteur de frame. L'échelle fait tenir la silhouette dans ~BOSS_FILL x le rayon de collision.
const BOSS_DIR := "res://assets/sprites/bosses/"
const BOSS_FILL_FLOOR := 2.8
const BOSS_FILL_MINI := 2.4
const BOSS_FEET := 0.5 ## pieds à +0,5 rayon sous l'origine du nœud (cercle de collision au sol)
const BOSS_ALIASES := {&"cerf_lanterne": &"cerf"}
const BOSS_SPRITES := {
	# cerf (lot C7b) : auto = armement frame 2, impact frame 3 sur 6 (moitié, défaut) ; spell_a (lanternes
	# balancées) et spell_b (cabré) suivent une pose en sinus sur 8 frames dont le sommet est atteint à la
	# frame 3 (frames 3-4 au maximum) : impact à 3/8 pour les deux sorts (vérifié sur c7b_build.py et les planches).
	&"cerf": {"dir": "etage/cerf", "floor": true, "dim": 170.0, "bottom": 215.0, "fh": 256.0, "energy": 2.0, "impact": {&"cast_a": 0.375, &"cast_b": 0.375}},
	&"sonneur": {"dir": "etage/sonneur", "floor": true, "dim": 190.0, "bottom": 215.0, "fh": 256.0, "energy": 2.0},
	&"eclusier": {"dir": "etage/eclusier", "floor": true, "dim": 165.0, "bottom": 185.0, "fh": 256.0, "energy": 2.0},
	&"ash_lord": {"dir": "mini/ash_lord", "floor": false, "dim": 100.0, "bottom": 117.0, "fh": 170.0, "energy": 2.0},
	&"bramble_queen": {"dir": "mini/bramble_queen", "floor": false, "dim": 125.0, "bottom": 143.0, "fh": 170.0, "energy": 2.0},
	&"brood_mother": {"dir": "mini/brood_mother", "floor": false, "dim": 118.0, "bottom": 140.0, "fh": 170.0, "energy": 2.0},
	&"frost_bear": {"dir": "mini/frost_bear", "floor": false, "dim": 135.0, "bottom": 145.0, "fh": 170.0, "energy": 2.0},
	&"rust_archon": {"dir": "mini/rust_archon", "floor": false, "dim": 100.0, "bottom": 126.0, "fh": 170.0, "energy": 2.0},
	&"stone_colossus": {"dir": "mini/stone_colossus", "floor": false, "dim": 120.0, "bottom": 137.0, "fh": 170.0, "energy": 2.0},
}
## Mini-boss par boss d'étage (biome) : alternés d'une apparition à l'autre. Repli seulement : la liste
## par biome vient de data/fauna.json (minis_for_biome, filtrée sur les .tres livrés).
const MINIS_BY_FLOOR := {
	&"cerf": [&"bramble_queen", &"brood_mother"],
	&"sonneur": [&"ash_lord", &"rust_archon"],
	&"eclusier": [&"frost_bear", &"stone_colossus"],
}
const BOSS_DIRS4 := ["e", "s", "w", "n"]
const FLASH_SHADER := preload("res://scripts/fx/sprite_flash.gdshader")
const FLASH_MOD := Color(2.0, 2.0, 2.0, 1.0)

static var _frames_cache: Dictionary = {} ## tier -> SpriteFrames (ou null si absent)
static var _flash_material: ShaderMaterial = null
static var _boss_cache: Dictionary = {} ## id -> SpriteFrames (ou null si absent/invalide)
static var _mini_count := 0
static var _warm_ms := -100000
# --- faune par biome (data/fauna.json)
static var _fauna: Dictionary = {}
static var _fauna_loaded := false
static var _mon_cache: Dictionary = {} ## biome -> {clé * 2 + élite -> [SpriteFrames|null, cfg, clé effective]}
static var _map_biome: Dictionary = {} ## map_id -> biome
static var biome_override: StringName = &"" ## tests / outils : force le biome courant (&"" = auto)
static var _biome_now: StringName = &""
static var _biome_map_id := ""
static var _biome_stage := -1
static var _biome_frame := -1
static var _sm_ref: WeakRef = null
static var _style_ver := -1 ## RenderStyle.version des caches de SpriteFrames (style 3d / cel)

var _tier := 1
var _radius := 20.0
var _flash := false
var _charge_mod := Color.WHITE ## teinte d'armement (set_charge), rendue après un flash de coup
var _poly := PackedVector2Array()
var _sprite: AnimatedSprite2D = null
var _use_sprite := false
var _dir := -1
## Octant (index de DIRS) du sprite 8 directions affiché, -1 si le visuel n'en a pas (placeholder, boss).
## Lecture seule hors de cette classe : Enemy saute set_facing quand l'octant ne change pas (perf).
var facing_octant := -1
var _tier_frames: SpriteFrames = null
var _key := 1
var _mon_cfg: Dictionary = {} ## géométrie du sprite de monstre courant (SPRITES + surcharge du biome)
var _action: StringName = &"run"
var _skin_prefix := "" ## set_skin_frames : préfixe des anims (extras `stoker_` du .tres d'un boss), "" = aucun
# --- état boss sprite
var _boss_sprite := false
var _boss_cfg: Dictionary = {}
var _boss_base: StringName = &"idle" ## idle | run
var _boss_oneshot: StringName = &"" ## attack | cast_a | cast_b | trans
var _boss_phase := 1
var _boss_pose_phase := 0 ## > 0 : variantes idle/walk de cette phase (Anguille échouée en P1-P2 = pose _p3), sans transition
var _boss_d4 := 1

## --- Coups des boss (retour joueur : attaques illisibles, ours mini-boss qui ne regarde pas le joueur).
## Les anims d'attaque et de sort ne sont rendues que vers le sud (_s) : vers un autre côté, le boss
## garde sa locomotion orientée (run_/walk_<dir>) en posture figée puis frappe ; vers le sud, l'anim
## d'attaque (accélérée ou ralentie pour que sa frame d'impact tombe pile sur le coup). Dans tous les
## cas une fente du corps vers la cible : recul d'armement pendant le télégraphe, fente qui culmine
## au moment des dégâts, retour. Repos tourné vers un autre côté que le sud : locomotion au ralenti.
## Une anim directionnelle `attack_<dir>` / `cast_a_<dir>`… livrée plus tard est prise automatiquement.
const BOSS_IMPACT_FRAC := 0.5 ## frame d'impact = moitié de l'anim (attack_s de l'ours : frame 3 sur 6) ; clé "impact" de BOSS_SPRITES
const BOSS_LUNGE_RADIUS := 0.55 ## fente (× rayon de collision, px logiques)
const BOSS_WINDBACK := 0.35 ## recul d'armement (part de la fente)
const BOSS_LUNGE_IN_S := 0.08 ## la fente part BOSS_LUNGE_IN_S avant l'impact
const BOSS_RECOVER_S := 0.25
const BOSS_SPEED_RANGE := Vector2(0.25, 3.0) ## bornes de la vitesse d'anim avant l'impact
const BOSS_IDLE_STEP_SCALE := 0.35
const BOSS_ATTACK_BASES := {&"attack": ["auto", "attack"], &"cast_a": ["spell_a", "cast_a"], &"cast_b": ["spell_b", "cast_b"]} ## [boss d'étage, mini]
var _strike_t := -1.0 ## temps écoulé depuis l'armement (< 0 : aucun coup)
var _strike_impact := 0.0
var _strike_end := 0.0
var _strike_speed := 1.0
var _strike_dir := Vector2.ZERO ## direction logique de la fente


## Style de rendu changé (RenderStyle) : les caches de SpriteFrames sont vidés (chemins `_cel`).
static func _sync_style() -> void:
	if _style_ver != RenderStyle.version:
		_style_ver = RenderStyle.version
		_frames_cache.clear()
		_mon_cache.clear()
		_boss_cache.clear()


static func frames_for_tier(tier: int) -> SpriteFrames:
	_sync_style()
	if _frames_cache.has(tier):
		return _frames_cache[tier]
	var frames: SpriteFrames = null
	if SPRITES.has(tier):
		var n: String = SPRITES[tier]["name"]
		var path := RenderStyle.resolve("%s%s/%s.tres" % [MONSTER_DIR, n, n])
		if ResourceLoader.exists(path):
			var f := load(path) as SpriteFrames
			if f != null and f.has_animation(&"run_e"):
				frames = f
	_frames_cache[tier] = frames
	return frames


## ===================== Faune par biome (data/fauna.json, docs/Design_Etages.md §5) =====================
## Biome -> rôle (essaim, tireur, bondisseur, brute ; élites) -> dossier de sprites ; mini-boss et boss
## d'étage par biome. Tout asset absent retombe proprement : élite -> sprite normal du biome -> sprites
## du biome par défaut (étage 1) -> (bondisseur) même chaîne en tireur -> placeholder. Les listes de boss
## sont filtrées sur les .tres présents : un lot Codex livré au chemin enregistré se branche seul.
const FAUNA_PATH := "res://data/fauna.json"
const FAUNA_DEFAULT_BIOME := &"terrasses"
const ROLE_BY_KEY := {1: "swarm", 2: "shooter", LEAPER_KEY: "leaper", 3: "brute"}
const FLOORS_PER_LOOP := 5


static func fauna() -> Dictionary:
	if not _fauna_loaded:
		_fauna_loaded = true
		_fauna = {}
		if FileAccess.file_exists(FAUNA_PATH):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FAUNA_PATH))
			if d is Dictionary:
				_fauna = d
			else:
				push_warning("EnemyVisual : %s illisible, faune de l'étage 1 partout." % FAUNA_PATH)
	return _fauna


## Tests / outils : remplace la table (null : relit le JSON) et vide les caches de faune.
static func set_fauna(d: Variant) -> void:
	_fauna = d if d is Dictionary else {}
	_fauna_loaded = d is Dictionary
	reset_fauna_caches()


static func reset_fauna_caches() -> void:
	_mon_cache.clear()
	_map_biome.clear()
	_biome_now = &""
	_biome_map_id = ""
	_biome_stage = -1
	_biome_frame = -1
	_sm_ref = null


static func default_biome() -> StringName:
	return StringName(fauna().get("default_biome", FAUNA_DEFAULT_BIOME))


static func biome_data(biome: StringName) -> Dictionary:
	var biomes: Dictionary = fauna().get("biomes", {})
	return biomes.get(String(biome), {})


static func biomes() -> Array[StringName]:
	var out: Array[StringName] = []
	for b in (fauna().get("biomes", {}) as Dictionary):
		out.append(StringName(b))
	return out


## Biome d'un étage (1-5 ; sans fin : 6 -> biome 1, 10 -> La Source). Inconnu : biome par défaut.
static func biome_for_floor(floor_n: int) -> StringName:
	var f := ((maxi(floor_n, 1) - 1) % FLOORS_PER_LOOP) + 1
	var biomes_d: Dictionary = fauna().get("biomes", {})
	for b in biomes_d:
		if int((biomes_d[b] as Dictionary).get("floor", -1)) == f:
			return StringName(b)
	return default_biome()


## Biome d'une carte : alias `maps` de fauna.json, sinon clé `biome` de data/maps/<id>.json. &"" = inconnu.
static func biome_of_map(map_id: String) -> StringName:
	if map_id == "":
		return &""
	if _map_biome.has(map_id):
		return _map_biome[map_id]
	var out := &""
	var biomes_d: Dictionary = fauna().get("biomes", {})
	if biomes_d.has(map_id):
		out = StringName(map_id)
	else:
		for b in biomes_d:
			if map_id in ((biomes_d[b] as Dictionary).get("maps", []) as Array):
				out = StringName(b)
				break
	if out == &"":
		var json_path := "res://data/maps/%s.json" % map_id
		if FileAccess.file_exists(json_path):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
			if d is Dictionary and biomes_d.has(String(d.get("biome", ""))):
				out = StringName(d["biome"])
	_map_biome[map_id] = out
	return out


## Biome dont `boss_id` est un boss d'étage (alias compris). &"" = inconnu.
static func biome_of_boss(boss_id: StringName) -> StringName:
	var id := String(BOSS_ALIASES.get(boss_id, boss_id))
	var biomes_d: Dictionary = fauna().get("biomes", {})
	for b in biomes_d:
		if id in ((biomes_d[b] as Dictionary).get("floor_bosses", []) as Array):
			return StringName(b)
	return &""


## Biome courant : carte du StageManager (map_id), sinon étage de RunState. Résolu une fois par carte
## (la recherche du StageManager est faite au plus une fois par image tant qu'il n'existe pas).
static func current_biome() -> StringName:
	if biome_override != &"":
		return biome_override
	var sm: Node = (_sm_ref.get_ref() as Node) if _sm_ref != null else null
	if sm == null:
		_sm_ref = null
		var fr := Engine.get_process_frames()
		if fr != _biome_frame:
			_biome_frame = fr
			var tree := Engine.get_main_loop() as SceneTree
			sm = tree.get_first_node_in_group(&"stage_manager") if tree != null else null
			if sm != null:
				_sm_ref = weakref(sm)
	var mid := ""
	if sm != null:
		var v: Variant = sm.get(&"map_id")
		if v is String:
			mid = v
	var st := int(RunState.stage)
	if _biome_now != &"" and mid == _biome_map_id and st == _biome_stage:
		return _biome_now
	_biome_map_id = mid
	_biome_stage = st
	var b := biome_of_map(mid)
	_biome_now = b if b != &"" else biome_for_floor(st)
	return _biome_now


## Géométrie (SPRITES du rôle + surcharge) du sprite déclaré pour (biome, clé, élite) ; {} si rien de déclaré.
static func _role_cfg(biome: StringName, key: int, elite: bool) -> Dictionary:
	var role: String = ROLE_BY_KEY.get(key, "")
	var bd := biome_data(biome)
	var spec: Variant = (bd.get("elites" if elite else "monsters", {}) as Dictionary).get(role)
	if spec == null and not elite and biome == default_biome() and SPRITES.has(key):
		spec = SPRITES[key]["name"] # repli sans fauna.json : sprites de l'étage 1
	var cfg: Dictionary = (SPRITES.get(key, {}) as Dictionary).duplicate()
	if spec is String and spec != "":
		cfg["name"] = spec
	elif spec is Dictionary and (spec as Dictionary).has("name"):
		cfg.merge(spec, true)
	else:
		return {}
	return cfg


static func _load_monster_frames(sprite_name: String) -> SpriteFrames:
	var path := RenderStyle.resolve("%s%s/%s.tres" % [MONSTER_DIR, sprite_name, sprite_name])
	if not ResourceLoader.exists(path):
		return null
	var f := load(path) as SpriteFrames
	return f if f != null and f.has_animation(&"run_e") else null


## Sprite d'un monstre courant : [SpriteFrames | null, cfg, clé effective] (cache par biome/clé/élite).
static func monster_entry(key: int, biome: StringName, elite: bool = false) -> Array:
	_sync_style()
	var per: Dictionary = _mon_cache.get(biome, {})
	if per.is_empty():
		_mon_cache[biome] = per
	var ck := key * 2 + int(elite) # clé entière : pas de formatage de chaîne par apparition
	if per.has(ck):
		return per[ck]
	var out: Array = [null, SPRITES.get(key, {}), key]
	var keys: Array = [key, 2] if key == LEAPER_KEY else [key]
	var chain: Array[StringName] = [biome]
	if default_biome() != biome:
		chain.append(default_biome())
	var done := false
	for k: int in keys:
		for b in chain:
			for el: bool in ([true, false] if elite else [false]):
				var cfg := _role_cfg(b, k, el)
				if cfg.is_empty():
					continue
				var f := _load_monster_frames(String(cfg["name"]))
				if f != null:
					out = [f, cfg, k]
					done = true
					break
			if done:
				break
		if done:
			break
	per[ck] = out
	return out


static func monster_frames(key: int, biome: StringName, elite: bool = false) -> SpriteFrames:
	return monster_entry(key, biome, elite)[0]


## Configuration de sprite d'un boss : BOSS_SPRITES (prime), sinon `boss_sprites` de fauna.json ; {} si inconnu.
static func boss_cfg(boss_id: StringName) -> Dictionary:
	if BOSS_SPRITES.has(boss_id):
		return BOSS_SPRITES[boss_id]
	var extra: Dictionary = fauna().get("boss_sprites", {})
	var c: Variant = extra.get(String(boss_id))
	return c if c is Dictionary and (c as Dictionary).has("dir") else {}


static func boss_path(boss_id: StringName) -> String:
	var cfg := boss_cfg(boss_id)
	return "" if cfg.is_empty() else "%s%s/%s.tres" % [BOSS_DIR, cfg["dir"], String(boss_id)]


## Le .tres du boss est-il livré (chemin enregistré présent) ?
static func boss_available(boss_id: StringName) -> bool:
	var p := boss_path(boss_id)
	return p != "" and ResourceLoader.exists(p)


static func _biome_boss_list(biome: StringName, field: String, available_only: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in (biome_data(biome).get(field, []) as Array):
		var sid := StringName(id)
		if not available_only or boss_available(sid):
			out.append(sid)
	return out


## Mini-boss d'un biome dans l'ordre de rotation (par défaut : seulement ceux dont le sprite est livré).
static func minis_for_biome(biome: StringName, available_only: bool = true) -> Array[StringName]:
	return _biome_boss_list(biome, "minis", available_only)


static func floor_bosses_for_biome(biome: StringName, available_only: bool = true) -> Array[StringName]:
	return _biome_boss_list(biome, "floor_bosses", available_only)


## Sprite d'une invocation de boss (ex. mist_wolf_cub, lot N2a) : SpriteFrames ou null tant que non livré.
static func summon_frames(summon_id: StringName, biome: StringName = &"") -> SpriteFrames:
	var b := biome if biome != &"" else current_biome()
	var dir: Variant = (biome_data(b).get("summons", {}) as Dictionary).get(String(summon_id))
	if not (dir is String):
		return null
	var path := RenderStyle.resolve("%s%s/%s.tres" % [BOSS_DIR, dir, String(summon_id)])
	return load(path) as SpriteFrames if ResourceLoader.exists(path) else null


## Pool de mini-boss pour le boss d'étage `floor_id` : biome du boss, sinon biome courant ; replis
## MINIS_BY_FLOOR puis biome par défaut puis les 6 historiques.
static func mini_pool(floor_id: StringName) -> Array:
	var b := biome_of_boss(floor_id)
	if b == &"":
		b = current_biome()
	var pool: Array = minis_for_biome(b)
	if pool.is_empty():
		pool = MINIS_BY_FLOOR.get(floor_id, [])
	if pool.is_empty():
		pool = minis_for_biome(default_biome())
	if pool.is_empty():
		pool = [&"ash_lord", &"bramble_queen", &"brood_mother", &"frost_bear", &"rust_archon", &"stone_colossus"]
	return pool


func configure(tier: int, radius_px: float, is_boss: bool, variant: int = 0, boss_id: StringName = &"", elite: bool = false) -> void:
	_tier = tier
	_key = LEAPER_KEY if tier == 2 and variant == 1 else tier
	_radius = radius_px
	_flash = false
	_charge_mod = Color.WHITE
	_action = &"run"
	_skin_prefix = ""
	rotation = 0.0
	position = Vector2.ZERO
	_strike_t = -1.0
	_boss_sprite = false
	facing_octant = -1
	var frames: SpriteFrames = null
	if is_boss:
		frames = boss_frames(boss_id) # null -> repli placeholder
		if frames != null:
			_boss_cfg = boss_cfg(boss_id)
	else:
		# faune du biome courant (data/fauna.json) ; replis : élite -> normal -> étage 1 -> tireur
		var me := monster_entry(_key, current_biome(), elite)
		frames = me[0]
		_mon_cfg = me[1]
		_key = me[2]
	_use_sprite = frames != null
	if _use_sprite and is_boss:
		_boss_sprite = true
		_setup_boss_sprite(frames)
		_poly = PackedVector2Array()
	elif _use_sprite:
		_setup_sprite(frames)
		_poly = PackedVector2Array()
	else:
		if _sprite != null:
			_sprite.visible = false
			_sprite.stop()
		_poly = _build_polygon(tier, radius_px)
	queue_redraw()


## SpriteFrames d'un boss (cache). null si le .tres manque ou n'a pas les anims attendues : placeholder.
static func boss_frames(boss_id: StringName) -> SpriteFrames:
	var cfg := boss_cfg(boss_id)
	if cfg.is_empty():
		return null
	_sync_style()
	if _boss_cache.has(boss_id):
		return _boss_cache[boss_id]
	var path := RenderStyle.resolve("%s%s/%s.tres" % [BOSS_DIR, cfg["dir"], String(boss_id)])
	var frames: SpriteFrames = null
	if ResourceLoader.exists(path):
		var f := load(path) as SpriteFrames
		var probe := &"idle_p1_s" if cfg["floor"] else &"idle_s"
		if f != null and f.has_animation(probe):
			frames = f
	_boss_cache[boss_id] = frames
	return frames


## Identifiant de sprite du boss qui apparaît : boss d'étage = floor_boss de la carte (StageManager ou
## méta `next_boss_id` du Director), mini-boss = l'un des deux de ce biome (alternés). &"" = inconnu.
static func resolve_boss_id(tree: SceneTree, kind: StringName, director: Node = null) -> StringName:
	var floor_id := &""
	if director != null and director.has_meta(&"next_boss_id"):
		floor_id = StringName(director.get_meta(&"next_boss_id"))
	if tree != null:
		var sm := tree.get_first_node_in_group(&"stage_manager")
		if sm != null and sm.get(&"floor_boss") != null:
			floor_id = StringName(sm.get(&"floor_boss"))
	floor_id = BOSS_ALIASES.get(floor_id, floor_id)
	if kind == &"etage":
		var fc := boss_cfg(floor_id)
		return floor_id if not fc.is_empty() and bool(fc["floor"]) else &""
	# mini-boss imposé par le plan de run (Pillar -> méta `next_mini_id`, data/floors.json) s'il est livré
	if director != null and director.has_meta(&"next_mini_id"):
		var want := StringName(director.get_meta(&"next_mini_id"))
		if boss_available(want):
			return want
	var pool := mini_pool(floor_id)
	_mini_count += 1
	return pool[(_mini_count - 1) % pool.size()]


## Précharge en tâche de fond (sans bloquer) les .tres du boss d'étage et des mini-boss de la carte,
## pour que l'apparition ne charge rien de lourd en pleine partie.
static func _warm_bosses(tree: SceneTree) -> void:
	if tree == null:
		return
	var sm := tree.get_first_node_in_group(&"stage_manager")
	if sm == null or sm.get(&"floor_boss") == null:
		return
	var fid := StringName(sm.get(&"floor_boss"))
	fid = BOSS_ALIASES.get(fid, fid)
	var ids: Array = [fid]
	ids.append_array(mini_pool(fid))
	for id in ids:
		if not _boss_cache.has(id):
			var path := boss_path(id)
			if path != "" and ResourceLoader.exists(path):
				ResourceLoader.load_threaded_request(path)


func _setup_boss_sprite(frames: SpriteFrames) -> void:
	if frames != _tier_frames:
		# nouveau sprite : l'ancien porte l'émission et les liaisons des SpriteFrames de monstre
		# (échanger les frames dessus ferait pointer l'émission vers des anims inexistantes)
		if _sprite != null:
			_sprite.queue_free()
			_sprite = null
		_ensure_sprite()
		_tier_frames = frames
		EmissiveOverlay.apply(_sprite, frames, _boss_cfg["energy"])
	_ensure_sprite()
	var fill := BOSS_FILL_FLOOR if _boss_cfg["floor"] else BOSS_FILL_MINI
	var s: float = fill * _radius / float(_boss_cfg["dim"])
	var sc := _billboard_scale(s, _boss_cfg)
	_sprite.scale = sc
	# pieds (ligne bottom) placés à BOSS_FEET x rayon sous l'origine (en y logique : l'échelle verticale du billboard compte)
	_sprite.offset = Vector2(0.0, BOSS_FEET * _radius / sc.y - float(_boss_cfg["bottom"]) + float(_boss_cfg["fh"]) * 0.5)
	_sprite.modulate = Color.WHITE
	_sprite.speed_scale = 1.0
	_sprite.visible = true
	_boss_base = &"idle"
	_boss_oneshot = &""
	_boss_phase = 1
	_boss_pose_phase = 0
	_boss_d4 = 1
	_sprite.stop()
	_boss_play(false)


## Nom d'animation du boss selon l'état (repli : idle puis première animation).
func _boss_anim_name() -> StringName:
	var floor_boss: bool = _boss_cfg["floor"]
	var act := _boss_oneshot if _boss_oneshot != &"" else _boss_base
	var n := ""
	var sf := _sprite.sprite_frames
	var dn: String = BOSS_DIRS4[_boss_d4]
	match act:
		&"run":
			n = _boss_loco_name()
		&"dash": # ruée d'un boss d'étage (cerf, lot C7D : charge_<dir>) ; repli : locomotion
			n = "charge_" + dn
			if not sf.has_animation(n):
				n = _boss_loco_name()
		&"attack", &"cast_a", &"cast_b":
			var base: String = BOSS_ATTACK_BASES[act][0 if floor_boss else 1]
			n = "%s_%s" % [base, dn]
			if not sf.has_animation(n) and _boss_d4 != 1:
				n = _boss_loco_name() # pas d'anim de coup de ce côté : posture orientée
		&"trans":
			n = ("trans_p%d_s" % _boss_phase) if floor_boss else "phase2_s"
		&"vanish", &"reappear", &"anchored", &"bogged": # poses tenues de play_special (Éclusier, Bouvier P3)
			n = String(act) + "_s"
		_:
			n = ("idle_p%d_%s" % [_look_phase(), dn]) if floor_boss else ("idle_" + dn)
			if not sf.has_animation(n) and _boss_d4 != 1:
				n = _boss_loco_name() # repos tourné vers le joueur : locomotion au ralenti (_boss_speed)
	if sf.has_animation(n):
		return StringName(n)
	var fb := ("idle_p%d_s" % _boss_phase) if floor_boss else "idle_s"
	return StringName(fb) if sf.has_animation(fb) else sf.get_animation_names()[0]


func _boss_loco_name() -> String:
	var dn: String = BOSS_DIRS4[_boss_d4]
	return ("walk_p%d_%s" % [_look_phase(), dn]) if _boss_cfg["floor"] else ("run_" + dn)


## L'anim jouée est-elle la posture de repli (locomotion) au lieu d'une vraie anim d'action ?
func _boss_is_pose(anim: StringName) -> bool:
	return String(anim).begins_with("run_") or String(anim).begins_with("walk_")


## Vitesse d'anim selon l'état : coup armé (impact calé), posture figée, repos tourné au ralenti.
func _boss_speed(anim: StringName) -> float:
	var act := _boss_oneshot if _boss_oneshot != &"" else _boss_base
	if _strike_t >= 0.0 and BOSS_ATTACK_BASES.has(act):
		if _strike_t < _strike_impact:
			return 0.0 if _boss_is_pose(anim) else _strike_speed
		return 1.0
	if act == &"idle" and _boss_is_pose(anim):
		return BOSS_IDLE_STEP_SCALE
	return 1.0


func _boss_play(keep_frame: bool) -> void:
	var anim := _boss_anim_name()
	_sprite.speed_scale = _boss_speed(anim)
	if anim == _sprite.animation and (_sprite.is_playing() or _boss_oneshot == &"vanish"):
		return # disparu (vanish fini, dernière frame vide) : tenu jusqu'à play_special(&"reappear")
	var frame := _sprite.frame
	var progress := _sprite.frame_progress
	_sprite.play(anim)
	if keep_frame and frame > 0:
		_sprite.set_frame_and_progress(mini(frame, _sprite.sprite_frames.get_frame_count(anim) - 1), progress)


func _on_sprite_anim_finished() -> void:
	if _boss_sprite and _strike_t < 0.0 and (_boss_oneshot == &"attack" or _boss_oneshot == &"trans" or _boss_oneshot == &"reappear"):
		_boss_oneshot = &""
		_boss_play(false)


## Anim spéciale d'un boss d'étage, sans fente ni coup armé (cerf : &"vanish" tenu disparu jusqu'à
## &"reappear", qui rend la main au repos à sa fin). Retourne sa durée (s), 0 si l'anim manque.
func play_special(name: StringName) -> float:
	if not _boss_sprite:
		return 0.0
	var n := StringName(String(name) + "_s")
	var sf := _sprite.sprite_frames
	if not sf.has_animation(n):
		return 0.0
	_strike_t = -1.0
	position = Vector2.ZERO
	_boss_oneshot = name
	_sprite.stop()
	_boss_play(false)
	return sf.get_frame_count(n) / maxf(sf.get_animation_speed(n), 1.0)


## Anim affichée et sa frame (tests, synchronisation des dégâts).
func current_anim() -> StringName:
	return _sprite.animation if _sprite != null else &""


func current_frame() -> int:
	return _sprite.frame if _sprite != null else -1


## Sprite du corps (couches de décor d'un boss calées sur son échelle et son pivot). null en repli.
func body_sprite() -> AnimatedSprite2D:
	return _sprite if _boss_sprite else null


## Phase des poses idle/walk : surcharge de set_pose_phase, sinon la phase du boss.
func _look_phase() -> int:
	return _boss_pose_phase if _boss_pose_phase > 0 else _boss_phase


## Boss d'étage : poses idle/walk d'une autre phase sans transition ni changement de phase (0 = phase du boss).
## Ex. l'Anguille ÉCHOUÉE après son émergence en P1-P2 prend la pose échouée (idle_p3) le temps de la fenêtre.
func set_pose_phase(p: int) -> void:
	if not _boss_sprite or p == _boss_pose_phase:
		return
	_boss_pose_phase = p
	_boss_play(false)


func pose_phase() -> int:
	return _boss_pose_phase


## Phase du boss (1..3) : une montée déclenche l'anim de transition, puis les variantes _pN.
func set_phase(p: int) -> void:
	if not _boss_sprite or p == _boss_phase:
		return
	var up := p > _boss_phase
	_boss_phase = p
	if up:
		_boss_oneshot = &"trans"
	_boss_play(not up)


func _boss_set_action(action: StringName) -> void:
	match action:
		&"run", &"idle":
			_boss_base = action
			if _strike_t < 0.0 and (_boss_oneshot == &"cast_a" or _boss_oneshot == &"cast_b"):
				_boss_oneshot = &"" # ancien usage (sans play_attack) : fin de la pose tenue
			_boss_play(true)
		&"attack", &"cast_a", &"cast_b":
			play_attack(action, -1.0, Vector2.ZERO)
		&"dash": # ruée : fin du coup armé (fente) et boucle charge_<dir> tant que le cerveau la tient
			if _boss_base == &"dash" and _boss_oneshot == &"":
				_boss_play(true)
				return
			_strike_t = -1.0
			position = Vector2.ZERO
			_boss_oneshot = &""
			_boss_base = &"dash"
			_boss_play(false)
		_:
			_boss_set_action(&"run")


## Temps naturel (vitesse 1) entre le début de l'anim de coup et sa frame d'impact.
func attack_impact_time(action: StringName) -> float:
	if not _boss_sprite or not BOSS_ATTACK_BASES.has(action):
		return 0.3
	var base: String = BOSS_ATTACK_BASES[action][0 if _boss_cfg["floor"] else 1]
	var sf := _sprite.sprite_frames
	var n := StringName(base + "_s")
	if not sf.has_animation(n):
		return 0.3
	var fps := maxf(sf.get_animation_speed(n), 1.0)
	var frac: float = (_boss_cfg.get("impact", {}) as Dictionary).get(action, BOSS_IMPACT_FRAC)
	return float(roundi(sf.get_frame_count(n) * frac)) / fps


## Coup armé d'un boss : anim de coup (ou posture orientée), fente vers `dir` (logique) qui culmine
## dans `impact_in` s, moment où le code de l'Enemy applique les dégâts. impact_in < 0 : temps naturel.
func play_attack(action: StringName, impact_in: float, dir: Vector2) -> void:
	var natural := attack_impact_time(action)
	if impact_in < 0.0:
		impact_in = natural
	impact_in = maxf(impact_in, 0.05)
	_strike_t = 0.0
	_strike_impact = impact_in
	_strike_speed = clampf(natural / impact_in, BOSS_SPEED_RANGE.x, BOSS_SPEED_RANGE.y)
	_strike_dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.ZERO
	var after := BOSS_LUNGE_IN_S + BOSS_RECOVER_S
	if _boss_sprite:
		var base: String = BOSS_ATTACK_BASES[action][0 if _boss_cfg["floor"] else 1]
		var n := StringName(base + "_s")
		var sf := _sprite.sprite_frames
		if sf.has_animation(n):
			after = maxf(after, (sf.get_frame_count(n) / maxf(sf.get_animation_speed(n), 1.0)) - natural)
		_boss_oneshot = action
		_sprite.stop() # relance même si c'est la même anim
		_boss_play(false)
	_strike_end = impact_in + after


## Décalage du coup armé par rapport à son impact (s ; < 0 avant l'impact). Journaux de test des boss.
func strike_lag() -> float:
	return _strike_t - _strike_impact


## Oriente la fente du coup armé en cours (direction logique), ex. charge qui suit le joueur.
func set_strike_dir(dir: Vector2) -> void:
	_strike_dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.ZERO


## Fraction de l'anim de coup `action` où tombe l'impact (config du boss, sinon BOSS_IMPACT_FRAC).
func boss_impact_frac(action: StringName) -> float:
	return float((_boss_cfg.get("impact", {}) as Dictionary).get(action, BOSS_IMPACT_FRAC))


## Coup de boss en cours (armement, impact ou retour) : le boss ne se déplace pas.
func is_attacking() -> bool:
	return _strike_t >= 0.0


## Direction affichée (boss : 0 e, 1 s, 2 w, 3 n ; autres : index dans DIRS).
func facing_dir4() -> int:
	return _boss_d4 if _tier == 4 else _dir


## Avance le coup armé : vitesse d'anim à l'impact, fente du corps, fin du coup.
func boss_tick(delta: float) -> void:
	if _strike_t < 0.0:
		return
	var before := _strike_t
	_strike_t += delta
	if _boss_sprite and before < _strike_impact and _strike_t >= _strike_impact:
		_sprite.speed_scale = _boss_speed(_sprite.animation)
	position = _strike_dir * _lunge_offset(_strike_t)
	if _strike_t >= _strike_end:
		_strike_t = -1.0
		position = Vector2.ZERO
		if _boss_sprite and BOSS_ATTACK_BASES.has(_boss_oneshot):
			_boss_oneshot = &""
			_boss_play(false)


## Déplacement du corps le long de la fente (px logiques) : recul, fente culminant à l'impact, retour.
func _lunge_offset(t: float) -> float:
	var reach := BOSS_LUNGE_RADIUS * _radius
	var back := -BOSS_WINDBACK * reach
	var t_in := maxf(_strike_impact - BOSS_LUNGE_IN_S, 0.0)
	if t < t_in:
		return back * smoothstep(0.0, maxf(t_in, 0.001), t)
	if t < _strike_impact:
		return lerpf(back if t_in > 0.0 else 0.0, reach, (t - t_in) / maxf(_strike_impact - t_in, 0.001))
	return lerpf(reach, 0.0, clampf((t - _strike_impact) / BOSS_RECOVER_S, 0.0, 1.0))


## Échelle d'un sprite en billboard (docs/Design_Isometrique.md §1.6) : le sprite vit sous UNSQUASH (1, 2),
## la caméra (zoom non uniforme) le remet à l'échelle nette. `render_px_per_u` (clé optionnelle de
## SPRITES / BOSS_SPRITES) : 64 pour les sprites anciens (échelle 1), 90,51 pour un rendu iso (SPRITE_K).
## L'échelle est posée sur le nœud du sprite (pas de nœud intermédiaire) : lots de rendu et caches intacts.
static func _billboard_scale(s: float, cfg: Dictionary) -> Vector2:
	var k := Balance.UNIT_PX / float(cfg.get("render_px_per_u", Balance.UNIT_PX))
	return Vector2(s * k, s * k) * Iso.UNSQUASH


func _setup_sprite(frames: SpriteFrames) -> void:
	var cfg: Dictionary = _mon_cfg if not _mon_cfg.is_empty() else SPRITES[_key]
	_ensure_sprite()
	if frames != _tier_frames:
		_tier_frames = frames
		EmissiveOverlay.apply(_sprite, frames, cfg["energy"])
		_lift_emission()
	_sprite.scale = _billboard_scale(float(cfg["scale"]), cfg)
	_sprite.offset = Vector2(0.0, cfg["offset_y"])
	_sprite.modulate = Color.WHITE
	_sprite.self_modulate = Color.WHITE # use_frames peut l'éclaircir (gain), remis à neuf à chaque configure
	_sprite.visible = true
	_dir = -1
	_play_dir(0)
	# désynchronise les foules : frame de départ aléatoire
	var n := frames.get_frame_count(_sprite.animation)
	if n > 1:
		_sprite.set_frame_and_progress(randi() % n, randf())


## Les nœuds du sprite (corps + émission) sont créés dès l'instanciation du pool, jamais en jeu.
func _ready() -> void:
	add_to_group(RenderStyle.GROUP)
	var f := frames_for_tier(1)
	if f != null:
		_ensure_sprite()
		_tier_frames = f
		EmissiveOverlay.apply(_sprite, f, SPRITES[1]["energy"])
		_lift_emission()
		_sprite.visible = false
	# précharge (tâche de fond) les sprites de boss de la carte, une fois le StageManager en place
	if Time.get_ticks_msec() - _warm_ms > 3000:
		_warm_ms = Time.get_ticks_msec()
		get_tree().create_timer(1.5).timeout.connect(EnemyVisual._warm_bosses.bind(get_tree()))


## Perf (lots de rendu) : l'émission des monstres courants passe un cran de z au-dessus de la foule.
## Dans le conteneur trié en y, corps et émissions alternaient (2 lots par monstre) ; ainsi tous les
## corps d'un même tier se suivent (1 lot), puis toutes les émissions (1 lot par tier, matériau
## partagé). Contrepartie mineure : l'accent émissif d'un monstre caché derrière un autre reste
## visible (quelques pixels additifs). Les boss gardent l'émission collée à leur corps (z 0).
const EMISSION_Z := 1


## Bascule de style à chaud (RenderStyle, F7) : mêmes anim, frame et progression, frames `_cel` ou d'origine.
func apply_render_style() -> void:
	if _sprite == null:
		return
	var f := RenderStyle.restyle_sprite(_sprite)
	if f != null:
		_tier_frames = f
		if not _boss_sprite:
			_lift_emission()


func _lift_emission() -> void:
	var em := _sprite.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE)) as CanvasItem
	if em != null:
		em.z_index = EMISSION_Z


func _ensure_sprite() -> void:
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = &"Sprite"
		_sprite.material = _get_flash_material()
		_sprite.animation_finished.connect(_on_sprite_anim_finished)
		add_child(_sprite)


static func _get_flash_material() -> ShaderMaterial:
	if _flash_material == null:
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = FLASH_SHADER
	return _flash_material


func _play_dir(d: int) -> void:
	if d == _dir:
		return
	var frame := _sprite.frame
	var progress := _sprite.frame_progress
	_dir = d
	facing_octant = d
	var anim := StringName("%s%s_%s" % [_skin_prefix, _action, DIRS[d]])
	if not _sprite.sprite_frames.has_animation(anim):
		anim = StringName(_skin_prefix + "run_" + DIRS[d])
		if not _sprite.sprite_frames.has_animation(anim): # corps à 4 directions (invocation de mini-boss : use_frames)
			anim = StringName(_skin_prefix + "run_" + DIRS4_OF8[d])
	_sprite.play(anim)
	if frame > 0 or progress > 0.0:
		_sprite.set_frame_and_progress(frame, progress)


const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const DIRS4_OF8 := ["e", "s", "s", "w", "w", "n", "n", "e"]


## Corps d'invocation de mini-boss (louveteau du Loup de brume, data/fauna.json summons) à la place du sprite de
## monstre du biome, jusqu'au prochain configure() (retour au pool). `cfg` : scale, offset_y, energy,
## render_px_per_u, gain (éclaircit le corps la nuit, plafonné à 1,45) (défauts : tier 1). Anims run_<e|s|w|n> acceptées (repli 8 -> 4 directions).
func use_frames(frames: SpriteFrames, cfg: Dictionary = {}) -> void:
	if frames == null or _boss_sprite:
		return
	var c: Dictionary = (SPRITES[1] as Dictionary).duplicate()
	c.merge(cfg, true)
	_mon_cfg = c
	_use_sprite = true
	_poly = PackedVector2Array()
	_setup_sprite(frames)
	var g := minf(float(c.get("gain", 1.0)), 1.45) # < 1,5 : le flash de coup passe par COLOR.r > 1,5
	_sprite.self_modulate = Color(g, g, g)
	queue_redraw()


func set_flash(on: bool) -> void:
	if on == _flash:
		return
	_flash = on
	if _use_sprite:
		_sprite.modulate = FLASH_MOD if on else _charge_mod
	else:
		queue_redraw()


## Armement d'un coup (monstres : tireur, brute, bondisseur ; docs/Comportements_Monstres.md) : teinte chaude
## sur le sprite et son émission, plus vive au niveau 2 (visée verrouillée, coup imminent). Rouge < 1,5 : jamais
## confondue avec le drapeau du flash de coup ; alpha > 1 = lueur chaude additive du shader et émission avivée
## (sprite_flash.gdshader). Un appel par changement de niveau.
const CHARGE_MODS: Array[Color] = [Color.WHITE, Color(1.2, 1.08, 0.9, 1.3), Color(1.45, 1.3, 1.0, 1.95)]


func set_charge(level: int) -> void:
	var m: Color = CHARGE_MODS[clampi(level, 0, 2)]
	if m == _charge_mod:
		return
	_charge_mod = m
	if _flash:
		return
	if _use_sprite:
		_sprite.modulate = m
	else:
		queue_redraw()


## Hitstop : animation figée (le corps et l'émission restent synchronisés par frame_changed).
func set_frozen(on: bool) -> void:
	if _sprite != null:
		_sprite.speed_scale = 0.0 if on else 1.0


## Animation d'action (run, charge, attack, cast…). Sans animation correspondante : run.
## restart : rejouée depuis la frame 0 (armement d'un coup ; sinon la frame de la course est reprise).
## Habillage d'un add de boss (Design_Boss_Raid §1.4) : les anims `<prefix>run_<dir>` (8 ou 4 directions, ex.
## `stoker_run_e`) des extras du .tres du boss remplacent le sprite de monstre jusqu'au prochain configure()
## (retour au pool). Retourne false (rien changé, placeholder gardé) si `frames` n'a aucune anim de ce préfixe.
func set_skin_frames(frames: SpriteFrames, prefix: StringName, cfg: Dictionary = {}) -> bool:
	if frames == null or _boss_sprite:
		return false
	var pre := String(prefix)
	if not (frames.has_animation(StringName(pre + "run_e")) or frames.has_animation(StringName(pre + "run_s"))):
		return false
	_skin_prefix = pre
	use_frames(frames, cfg)
	return true


func skin_prefix() -> String:
	return _skin_prefix


func set_action(action: StringName, restart := false) -> void:
	if _boss_sprite:
		_boss_set_action(action)
		return
	if action == _action and not restart:
		return
	_action = action
	if _use_sprite and _dir >= 0:
		var d := _dir
		_dir = -1
		_play_dir(d)
		if restart:
			_sprite.set_frame_and_progress(0, 0.0)


func set_facing(angle: float) -> void:
	if _boss_sprite:
		var c := cos(angle)
		var sn := sin(angle)
		var d4 := (0 if c >= 0.0 else 2) if absf(c) >= absf(sn) else (1 if sn > 0.0 else 3)
		if d4 != _boss_d4:
			_boss_d4 = d4
			_boss_play(true)
	elif _tier == 4: # boss sans sprite (repli) : orientation suivie pour les tests, hexagone tourné
		var c4 := cos(angle)
		var s4 := sin(angle)
		_boss_d4 = (0 if c4 >= 0.0 else 2) if absf(c4) >= absf(s4) else (1 if s4 > 0.0 else 3)
		rotation = angle
	elif _use_sprite:
		_play_dir(posmod(roundi(angle / (TAU / 8.0)), 8))
	elif _tier != 1:
		rotation = angle


func _build_polygon(tier: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match tier:
		2: # losange pointé vers l'avant (+x)
			pts = PackedVector2Array([Vector2(r * 1.2, 0), Vector2(0, r * 0.8), Vector2(-r * 0.9, 0), Vector2(0, -r * 0.8)])
		3: # bloc trapu
			pts = PackedVector2Array([Vector2(r, -r * 0.7), Vector2(r, r * 0.7), Vector2(-r * 0.8, r), Vector2(-r * 0.8, -r)])
		4: # hexagone
			for i in 6:
				pts.append(Vector2.from_angle(TAU * i / 6.0) * r)
	return pts


func _draw() -> void:
	if _use_sprite:
		return
	var c: Color = Color.WHITE if _flash else (TIER_COLORS.get(_tier, Color.MAGENTA) as Color) * _charge_mod
	if _poly.is_empty():
		draw_circle(Vector2.ZERO, _radius, c)
	else:
		draw_colored_polygon(_poly, c)
	if not _flash:
		# repère frontal (yeux) pour lire l'orientation
		var eye := c.darkened(0.6)
		draw_circle(Vector2(_radius * 0.45, -_radius * 0.25), _radius * 0.14, eye)
		draw_circle(Vector2(_radius * 0.45, _radius * 0.25), _radius * 0.14, eye)
