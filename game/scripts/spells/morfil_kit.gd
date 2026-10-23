class_name MorfilKit
extends Node
## Kit de Taliant, le rōnin d'écorce (docs/Design_Personnages.md §2.8, fiche docs/fiches/morfil.md).
## Arbre-samouraï dont le bras droit EST le katana. Ressource : l'AIGUISAGE (0-100 %).
## Formule (lecture retenue de « 1 % de dégâts par % d'aiguisage ») : chaque coup de katana inflige
##   dégâts = coef du coup × Dégât_base × (1 + Σ bonus) × Π(mult) × (aiguisage / 100)
## soit 100 % des dégâts à 100 % d'aiguisage, 50 % à 50 %. Le fil ne descend jamais sous SHARP_MIN (10 %).
## Chaque coup (un geste de lame, quel que soit le nombre de monstres touchés) retire son coût d'aiguisage.
## - Sort 1 (auto) Taille et estoc : alterne coup circulaire (tout autour) et estoc (cône étroit, long).
## - Sort 2 Fauche-lune : grand demi-cercle devant lui (vers le curseur / stick / paquet le plus dense).
## - Sort 3 Aiguisage : la jauge remonte à 100 % (geste de pierre à eau, auto suspendue pendant le geste).
## - Sort 4 Lames jumelles : exige ≥ 90 % ; un second katana pousse dans l'autre main et DOUBLE chaque coup
##   pendant la moitié de la recharge (effective) de l'ultime.
## - Roulade = Iaï (le « sort 2 » de bretteur : mobilité/défense) : la roulade dégaine et tranche chaque monstre
##   traversé (une fois), invulnérable comme une roulade ; coûte un coup d'aiguisage si elle touche.
## Rendu : assets du lot Codex SA1 absents = Ardent teinté écorce (placeholder_tint) + lame jumelle dessinée.

# --- Assets attendus (lot Codex SA1, art/tools/night/_sa1.txt) ------------------------------------
const ASSET_DIR := "res://assets/sprites/characters/morfil/"
const SPRITE_FRAMES := ASSET_DIR + "morfil.tres"
const CIRCLE_FRAMES := ASSET_DIR + "cut_circle/cut_circle.tres" ## TOP, coup circulaire, centré
const THRUST_FRAMES := ASSET_DIR + "cut_thrust/cut_thrust.tres" ## TOP, estoc pointé vers +X
const CRESCENT_FRAMES := ASSET_DIR + "cut_crescent/cut_crescent.tres" ## TOP, demi-cercle centré sur +X
const TWIN_DRAW_FRAMES := ASSET_DIR + "twin_draw/twin_draw.tres" ## TOP, gerbe du dégainé jumeau
const PLACEHOLDER_TINT := Color(0.58, 0.5, 0.42) ## Ardent teinté écorce grise / bois mort, en attendant SA1
const PLACEHOLDER_SCALE := 1.05

# --- Identité ---------------------------------------------------------------------------------------
const ACCENT := Color("#CDEB6E") ## fil de sève : seul élément émissif (le tranchant du katana)
const LIGHT_SPELL := &"morfil_edge"
const BODY_COLOR := Color("#3A3129") ## écorce sombre

# --- Statistiques (§2.8.7) --------------------------------------------------------------------------
const BASE_HP := 115.0 ## cœur de bois dense (équilibrage : 105 -> 115)
const HP_PER_LEVEL := 35.0
const ARMOR := 25.0 ## écorce dure (équilibrage : dégâts subis ×2-4,5 vs Ardent à 15)
const BASE_REGEN := 0.8
const REGEN_PER_LEVEL := 0.16
const BASE_SPEED_U := 3.9
const HITBOX_U := 0.45 ## arbre maigre

# --- Aiguisage --------------------------------------------------------------------------------------
const SHARP_MAX := 100.0
const SHARP_MIN := 10.0 ## le bois garde toujours un fil : jamais 0 dégât
const SHARP_ULT_MIN := 90.0 ## seuil de l'ultime
const SHARP_AUTO_SHARPEN_BELOW := 55.0 ## auto-cast (accessibilité, simulateur) : aiguiser sous ce seuil
const COST_CIRCLE := 3.0 ## équilibrage 23/10 : 4 -> 3
const COST_THRUST := 3.0 ## équilibrage 23/10 : 4 -> 3
const COST_CRESCENT := 15.0
const COST_IAI := 4.0

# --- Sort 1 : Taille et estoc (auto) -----------------------------------------------------------------
const AUTO_INTERVAL_S := 0.7
const CIRCLE_COEF := 1.5
const CIRCLE_RADIUS_U := 2.8 ## retour joueur 23/10 : 2,3 -> 2,8
const CIRCLE_PROC := 0.8
const CIRCLE_KNOCK_U := 0.3
const THRUST_COEF := 2.0
const THRUST_RANGE_U := 3.6 ## retour joueur 23/10 : 3,2 -> 3,6
const THRUST_SPREAD_DEG := 40.0
const THRUST_PROC := 1.0
const THRUST_KNOCK_U := 0.6

# --- Sort 2 : Fauche-lune -------------------------------------------------------------------------
const CRESCENT_COEF := 4.0
const CRESCENT_RADIUS_U := 3.5
const CRESCENT_SPREAD_DEG := 180.0
const CRESCENT_CD := 6.0
const CRESCENT_PROC := 1.0
const CRESCENT_KNOCK_U := 1.0

# --- Sort 3 : Aiguisage ---------------------------------------------------------------------------
const SHARPEN_CD := 10.0
const SHARPEN_LOCK_S := 0.45 ## geste de pierre : l'auto est suspendue

# --- Sort 4 : Lames jumelles ----------------------------------------------------------------------
const TWIN_CD := 30.0
const TWIN_DURATION_FRAC := 0.5 ## moitié de la recharge effective
const TWIN_STRIKE_MULT := 0.6 ## équilibrage 23/10 : coup jumeau sous l'ultime ×1,0 -> ×0,7 -> ×0,6
const TWIN_DELAY_S := 0.12 ## le second katana frappe juste après le premier (lisible : deux éclats)
const TWIN_DRAW_COEF := 2.5 ## dégainé jumeau à l'activation (cercle), sans coût d'aiguisage
const TWIN_DRAW_RADIUS_U := 2.5

# --- Variantes de sorts (docs/Variantes_Sorts.md §2.10) ---------------------------------------------
const V_SLOW := &"morfil_taille_lente"
const V_CLEAVE := &"morfil_fendoir"
const V_WALK := &"morfil_affutage_en_marche"
const V_TEMPER := &"morfil_trempe"
const VAR_DIR := ASSET_DIR + "variants/" ## VFX des variantes (lot Codex TALV), absents = replis dessinés
const SLOW_FRAMES := VAR_DIR + "cut_kesa/cut_kesa.tres" ## TOP, coup en cône 90° centré sur +X
const CLEAVE_FRAMES := VAR_DIR + "cut_cleave/cut_cleave.tres" ## TOP, trait de 5 u vers +X
# Taille lente (slot 1) : un grand coup en cône par seconde
const SLOW_INTERVAL_S := 1.0
const SLOW_COEF := 2.6
const SLOW_RADIUS_U := 3.0
const SLOW_SPREAD_DEG := 90.0
const SLOW_PROC := 1.0
const SLOW_KNOCK_U := 0.8
const SLOW_TRIGGER_U := 2.6
const COST_SLOW := 5.0
const SLOW_GUARD_TAKEN_MULT := 0.65 ## posture lourde : -35 % de dégâts subis (au lieu de -45 %)
# Fendoir (slot 2) : ligne de 5 u x 1 u et un pas en avant
const CLEAVE_COEF := 4.0
const CLEAVE_LEN_U := 5.0
const CLEAVE_WIDTH_U := 1.0
const CLEAVE_CD := 6.0
const CLEAVE_PROC := 1.0
const CLEAVE_KNOCK_U := 0.6
const CLEAVE_STEP_U := 1.0
const CLEAVE_TRIGGER_U := 4.0
# Affûtage en marche (slot 3) : 3 s de posture lente, +25 %/s
const WALK_CD := 7.0
const WALK_S := 3.0
const WALK_RATE := 25.0 ## % d'aiguisage par seconde
const WALK_TICK_S := 0.25
const WALK_SPEED_MULT := 0.6
const WALK_AUTO_CLEAR_U := 2.0 ## auto-cast : seulement si aucun monstre plus près
# Trempe (slot 4) : lame trempée, plus d'usure, dégâts x1,5, une seule lame
const TEMPER_MULT := 1.5
# Compteurs de déblocage (RunState.add_counter -> Profile.stats ; règles « counter » de characters.json)
const COUNTER_SHARPEN := "morfil.sharpen_casts"
const COUNTER_CRESCENT_BIG := "morfil.crescent_big_casts"
const COUNTER_BOSS2 := "morfil.floor2_boss_kills"
const CRESCENT_BIG_HITS := 12
const BOSS_FLOOR := 2

# --- Garde du bretteur (équilibrage) -------------------------------------------------------------
## Après chaque geste de lame, la garde haute dévie les coups : −45 % de dégâts subis pendant GUARD_S.
const GUARD_TAKEN_MULT := 0.55
const GUARD_S := 0.6

# --- Roulade : Iaï ------------------------------------------------------------------------------------
const IAI_COEF := 1.5
const IAI_RADIUS_U := 0.9
const IAI_PROC := 0.8
const IAI_KNOCK_U := 0.4

## Anims d'action : base livrée par SA1, sinon le repli d'Ardent (attack / cast / cast_ult).
const ACTIONS := {
	&"circle": [&"cut_circle", &"attack"],
	&"thrust": [&"thrust", &"attack"],
	&"crescent": [&"crescent", &"cast"],
	&"sharpen": [&"sharpen", &"cast"],
	&"twin": [&"twin_draw", &"cast_ult"],
	&"slow": [&"crescent", &"cast"], ## Taille lente : demi-cercle existant (cône 90° en jeu)
	&"cleave": [&"thrust", &"attack"], ## Fendoir : geste d'estoc
}
## Frames d'impact (index 0), brief SA1 : cut_circle/thrust 6 frames -> 2 ; crescent 8 -> 4 ; sharpen 8 -> 5 ; twin 8 -> 4.
const ACTION_IMPACT_FRAMES := {&"cut_circle": 2, &"thrust": 2, &"crescent": 4, &"sharpen": 5, &"twin_draw": 4,
	&"attack": 2, &"cast": 3, &"cast_ult": 4}
const KIT_ACTIONS: Array[StringName] = [&"cut_circle", &"thrust", &"crescent", &"sharpen", &"twin_draw",
	&"attack", &"cast", &"cast_ult"]
const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

var player: CharacterBody2D = null
var sharpness := SHARP_MAX
var twin_left := 0.0 ## Lames jumelles actives (s)
var twin_total := 0.0
var sharpen_left := 0.0
var guard_left := 0.0 ## garde du bretteur après un geste
var next_is_thrust := false ## alternance de l'auto (commence par le coup circulaire)
var swings := 0 ## gestes de lame (tests)
var twin_strikes := 0 ## coups doublés par le second katana (tests)
var _pending: Array = [] ## [base d'anim, Callable] en attente de la frame d'impact
var _delayed: Array = [] ## [s restantes, Callable] : coups du second katana
var _iai_active := false
var _iai_paid := false
var _iai_from := Vector2.ZERO
var _last_auto: StringName = &"circle"
var walk_left := 0.0 ## posture d'Affûtage en marche (s restantes)
var temper_left := 0.0 ## Trempe active (s)
var temper_total := 0.0
var cleaves := 0 ## Fendoirs lancés (tests)
var _walk_acc := 0.0
var _guard_mult := GUARD_TAKEN_MULT
var _iai_hit := {} ## instance_id -> true (une fois par roulade)
var _iai_spell: SpellData = null
var _visual: AnimatedSprite2D = null
var _twin_blade: Node2D = null


# --- Données -------------------------------------------------------------------------------------

static func _force_for(knock_u: float) -> float:
	return clampf(inverse_lerp(Balance.KB_MIN_U, Balance.KB_MAX_U, knock_u), 0.0, 1.0)


## Multiplicateur de dégâts d'un aiguisage (%) : 1 % de dégâts par % d'aiguisage.
static func sharp_mult(sharp: float) -> float:
	return clampf(sharp, 0.0, SHARP_MAX) / 100.0


static func _spell(sid: StringName, name: String, slot: int, coef: float, cd: float) -> SpellData:
	var s := SpellData.new()
	s.id = sid
	s.display_name = name
	s.slot = slot
	s.behavior = SpellData.Behavior.KIT
	s.coef = coef
	s.base_cooldown = cd
	s.element = &"physical"
	s.color = ACCENT
	s.light_preset = LIGHT_SPELL
	return s


static func _vfx_radius(path: String) -> float:
	if not ResourceLoader.exists(path):
		return 0.0
	var sf := load(path) as SpriteFrames
	if sf == null or not sf.has_animation(&"default") or sf.get_frame_count(&"default") == 0:
		return 0.0
	var t := sf.get_frame_texture(&"default", 0)
	return float(t.get_width()) * 0.45 if t != null else 0.0


static func _with_vfx(s: SpellData, path: String) -> void:
	var r := _vfx_radius(path)
	if r > 0.0:
		s.vfx_frames = path
		s.vfx_radius_px = r
		s.vfx_floor_aspect = 1.0 # rig TOP


static func character() -> CharacterData:
	var c := CharacterData.new()
	c.id = &"morfil"
	c.display_name = "Taliant"
	c.base_hp = BASE_HP
	c.hp_per_level = HP_PER_LEVEL
	c.armor = ARMOR
	c.base_regen = BASE_REGEN
	c.regen_per_level = REGEN_PER_LEVEL
	c.base_speed_u = BASE_SPEED_U
	c.hitbox_u = HITBOX_U
	c.kit_script = MorfilKit
	c.sprite_frames_path = SPRITE_FRAMES
	c.placeholder_tint = PLACEHOLDER_TINT
	c.placeholder_scale = PLACEHOLDER_SCALE
	c.body_color = BODY_COLOR
	c.accent_color = ACCENT
	c.light_color = ACCENT
	c.light_core_color = Color("#E8F5B8")
	c.action_impact_frames = ACTION_IMPACT_FRAMES

	var s1 := _spell(&"taille_estoc", "Taille et estoc", 1, CIRCLE_COEF, AUTO_INTERVAL_S)
	s1.is_auto = true
	s1.range_u = THRUST_RANGE_U
	s1.radius_u = CIRCLE_RADIUS_U
	s1.trigger_range_u = CIRCLE_RADIUS_U # pilote du simulateur : se tient dans le coup circulaire (~1,6 u)
	s1.proc_coef = CIRCLE_PROC

	var s2 := _spell(&"fauche_lune", "Fauche-lune", 2, CRESCENT_COEF, CRESCENT_CD)
	s2.radius_u = CRESCENT_RADIUS_U
	s2.range_u = CRESCENT_RADIUS_U
	s2.spread_deg = CRESCENT_SPREAD_DEG
	s2.trigger_range_u = 3.0
	s2.target_mode = &"densest"
	s2.proc_coef = CRESCENT_PROC

	var s3 := _spell(&"aiguisage", "Aiguisage", 3, 0.0, SHARPEN_CD)
	s3.is_zone = false
	s3.range_u = 99.0
	s3.trigger_range_u = 99.0

	var s4 := _spell(&"lames_jumelles", "Lames jumelles", 4, TWIN_DRAW_COEF, TWIN_CD)
	s4.radius_u = TWIN_DRAW_RADIUS_U
	s4.trigger_range_u = 3.0
	s4.proc_coef = 1.0

	c.spells = [s1, s2, s3, s4]
	return c


## Variantes (contrat CONTRACTS.md) : SpellData de la variante `variant_id` pour `slot`, ou null (non codée).
## Coefficients ajustés par balance_sim (+-15 % du sort de base en DPS cible et zone) ; le style ne change pas.
static func variant(slot: int, variant_id: StringName) -> SpellData:
	match [slot, variant_id]:
		[1, V_SLOW]:
			var s1 := _spell(V_SLOW, "Taille lente", 1, SLOW_COEF, SLOW_INTERVAL_S)
			s1.is_auto = true
			s1.range_u = SLOW_RADIUS_U
			s1.radius_u = SLOW_RADIUS_U
			s1.spread_deg = SLOW_SPREAD_DEG
			s1.trigger_range_u = SLOW_TRIGGER_U
			s1.proc_coef = SLOW_PROC
			return s1
		[2, V_CLEAVE]:
			var s2 := _spell(V_CLEAVE, "Fendoir", 2, CLEAVE_COEF, CLEAVE_CD)
			s2.radius_u = CLEAVE_LEN_U
			s2.range_u = CLEAVE_LEN_U
			s2.trigger_range_u = CLEAVE_TRIGGER_U
			s2.target_mode = &"densest"
			s2.proc_coef = CLEAVE_PROC
			return s2
		[3, V_WALK]:
			var s3 := _spell(V_WALK, "Affûtage en marche", 3, 0.0, WALK_CD)
			s3.is_zone = false
			s3.range_u = 99.0
			s3.trigger_range_u = 99.0
			return s3
		[4, V_TEMPER]:
			var s4 := _spell(V_TEMPER, "Trempe", 4, TWIN_DRAW_COEF, TWIN_CD)
			s4.radius_u = TWIN_DRAW_RADIUS_U
			s4.trigger_range_u = 3.0
			s4.proc_coef = 1.0
			return s4
	return null


# --- Mise en place ------------------------------------------------------------------------------

func setup(p: CharacterBody2D) -> void:
	player = p
	_visual = p.get_node_or_null(^"Visual") as AnimatedSprite2D
	if _visual != null:
		_twin_blade = MorfilTwinBlade.new()
		_twin_blade.name = "TwinBlade"
		_twin_blade.color = ACCENT
		_twin_blade.visible = false
		_visual.add_child(_twin_blade)
	_iai_spell = _strike_spell(&"iai", IAI_COEF, IAI_PROC, IAI_KNOCK_U, 0.0, false)
	Events.floor_started.connect(_on_floor_started)
	Events.player_died.connect(_on_player_died)
	Events.boss_killed.connect(_on_boss_killed)
	if p.has_signal(&"action_impact"):
		p.action_impact.connect(_on_action_impact)


func _exit_tree() -> void:
	if Events.floor_started.is_connected(_on_floor_started):
		Events.floor_started.disconnect(_on_floor_started)
	if Events.player_died.is_connected(_on_player_died):
		Events.player_died.disconnect(_on_player_died)
	if Events.boss_killed.is_connected(_on_boss_killed):
		Events.boss_killed.disconnect(_on_boss_killed)
	_pending.clear()
	_delayed.clear()


func _caster() -> SpellCaster:
	return player.spells if player != null else null


## Sous-sort d'un coup (coef plein ; l'aiguisage est appliqué au moment du coup par _scaled).
func _strike_spell(sid: StringName, coef: float, proc: float, knock_u: float, radius_u: float, zone := true) -> SpellData:
	var s := _spell(sid, String(sid), 1, coef, 0.0)
	s.proc_coef = proc
	s.hit_force = _force_for(knock_u)
	s.radius_u = radius_u
	s.is_zone = zone
	return s


## Copie du coup dont le coef porte l'aiguisage du moment : la formule de dégâts reste celle de SpellCaster.
func _scaled(s: SpellData, mult: float) -> SpellData:
	var d := s.duplicate() as SpellData
	d.coef = s.coef * mult
	return d


# --- Aiguisage ---------------------------------------------------------------------------------------

func sharp_ratio() -> float:
	return sharpness / SHARP_MAX


func damage_mult() -> float:
	return sharp_mult(sharpness)


func consume(cost: float) -> void:
	if is_tempered():
		return # Trempe : plus d'usure
	sharpness = clampf(sharpness - cost, SHARP_MIN, SHARP_MAX)


func sharpen() -> void:
	sharpness = SHARP_MAX


func is_twin() -> bool:
	return twin_left > 0.0


func is_tempered() -> bool:
	return temper_left > 0.0


## Id du sort actif d'un emplacement (base ou variante), &"" sans personnage.
func _slot_id(slot: int) -> StringName:
	if player == null or player.character == null:
		return &""
	for sp in player.character.spells:
		if sp != null and sp.slot == slot:
			return sp.id
	return &""


func can_ult() -> bool:
	return sharpness >= SHARP_ULT_MIN - 0.001


## Durée des Lames jumelles : moitié de la recharge effective de l'ultime (× cooldown_mult).
func twin_duration_s() -> float:
	var m: float = player.stat(&"cooldown_mult")
	return Balance.effective_cooldown(TWIN_CD, m if m > 0.0 else 1.0) * TWIN_DURATION_FRAC


# --- Hooks du joueur et de SpellCaster ----------------------------------------------------------

func blocks_slot(slot: int) -> bool:
	return slot == 1 and (sharpen_left > 0.0 or walk_left > 0.0)


func slot_affordable(slot: int) -> bool:
	return slot != 4 or can_ult()


func slot_cost_info(slot: int) -> Dictionary:
	match slot:
		2:
			return {"cost": "%d %% d'aiguisage" % int(COST_CRESCENT)}
		4:
			return {"cost": "aiguisage ≥ %d %%" % int(SHARP_ULT_MIN), "lack": "lame émoussée (%d %% requis)" % int(SHARP_ULT_MIN)}
	return {}


## Auto-cast (option, simulateur) : aiguiser quand la lame faiblit, l'ultime seulement au fil.
func auto_cast_ok(slot: int) -> bool:
	match slot:
		3:
			if _slot_id(3) == V_WALK: # posture lente : seulement hors de portée de morsure
				var c := _caster()
				return sharpness < SHARP_AUTO_SHARPEN_BELOW and (c == null or c.nearest_enemy(WALK_AUTO_CLEAR_U * Balance.UNIT_PX) == null)
			return sharpness < SHARP_AUTO_SHARPEN_BELOW
		4:
			return can_ult()
	return true


## Hook Player.take_damage : garde du bretteur juste après un geste de lame, et en continu sous les Lames
## jumelles (deux lames : une frappe, l'autre pare).
func damage_taken_mult(_source: Node) -> float:
	if is_twin():
		return GUARD_TAKEN_MULT
	return _guard_mult if guard_left > 0.0 else 1.0


func can_dodge() -> bool:
	return true


func speed_mult() -> float:
	return WALK_SPEED_MULT if walk_left > 0.0 else 1.0


func inertia_s() -> float:
	return 0.0


func slow_immune() -> bool:
	return false


func locks_facing() -> bool:
	return false


func dodge_ghosts() -> bool:
	return false # pas de fantômes braise d'Ardent : le fil de l'Iaï (repli) se lit seul


## Iaï : la roulade dégaine ; chaque monstre traversé est tranché une fois (tick).
func on_dodge_start(_dir: Vector2) -> void:
	_end_walk() # l'Iaï interrompt l'Affûtage en marche
	_iai_active = true
	_iai_paid = false
	_iai_hit.clear()
	_iai_from = player.global_position


func cast_spell(s: SpellData, aim: Variant) -> bool:
	match s.id:
		&"taille_estoc":
			return _cast_auto()
		V_SLOW:
			return _cast_slow()
		&"fauche_lune":
			var dir := _aim_dir(aim, CRESCENT_RADIUS_U)
			_end_walk()
			_queue(&"crescent", _crescent.bind(dir))
			player.facing = dir
			return true
		V_CLEAVE:
			var cdir := _aim_dir(aim, CLEAVE_LEN_U)
			_end_walk()
			_queue(&"cleave", _cleave.bind(cdir))
			player.facing = cdir
			return true
		&"aiguisage":
			if sharpness >= SHARP_MAX - 0.001 or is_tempered():
				return false # déjà au fil (ou lame trempée) : ne gaspille pas la recharge
			sharpen_left = SHARPEN_LOCK_S
			RunState.add_counter(COUNTER_SHARPEN)
			_queue(&"sharpen", _do_sharpen)
			return true
		V_WALK:
			if sharpness >= SHARP_MAX - 0.001 or is_tempered():
				return false
			walk_left = WALK_S
			_walk_acc = 0.0
			guard_left = 0.0 # pas de garde pendant la posture
			RunState.add_counter(COUNTER_SHARPEN)
			return true
		&"lames_jumelles":
			if not can_ult():
				return false
			_queue(&"twin", _twin_draw)
			return true
		V_TEMPER:
			if not can_ult():
				return false
			_queue(&"twin", _temper_draw)
			return true
	return false


func _aim_dir(aim: Variant, reach_u: float) -> Vector2:
	var origin := player.global_position
	var d := Vector2.ZERO
	if aim != null:
		d = (aim as Vector2) - origin
	if d.length_squared() < 1.0:
		var t := _caster().nearest_enemy(reach_u * Balance.UNIT_PX * 1.5) if _caster() != null else null
		if t != null:
			d = t.global_position - origin
	if d.length_squared() < 1.0:
		d = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
	return d.normalized()


func _zone_k() -> float:
	return 1.0 + player.stat(&"zone_size_add")


## Taille lente : un seul cône de 90° vers l'ennemi le plus proche.
func _cast_slow() -> bool:
	var c := _caster()
	if c == null:
		return false
	var t := c.nearest_enemy(SLOW_RADIUS_U * Balance.UNIT_PX * _zone_k())
	if t == null:
		return false
	var dir := t.global_position - player.global_position
	dir = dir.normalized() if dir.length_squared() > 1.0 else (player.facing if player.facing != Vector2.ZERO else Vector2.DOWN)
	player.facing = dir
	_queue(&"slow", _slow_cut.bind(dir))
	return true


## Auto : alterne circulaire / estoc ; si la cible n'est à portée que de l'autre coup, il le joue.
func _cast_auto() -> bool:
	var c := _caster()
	if c == null:
		return false
	var circle_px := CIRCLE_RADIUS_U * Balance.UNIT_PX * _zone_k()
	var thrust_px := THRUST_RANGE_U * Balance.UNIT_PX * _zone_k()
	var t := c.nearest_enemy(thrust_px)
	if t == null:
		return false
	var in_circle := t.global_position.distance_to(player.global_position) <= circle_px
	var forced := not in_circle # hors du cercle (2,3-3,2 u) : seul l'estoc porte
	var thrust := next_is_thrust or forced
	var dir := t.global_position - player.global_position
	dir = dir.normalized() if dir.length_squared() > 1.0 else (player.facing if player.facing != Vector2.ZERO else Vector2.DOWN)
	player.facing = dir
	if not forced: # équilibrage 23/10 : un estoc imposé ne consomme pas l'alternance (le cercle suit dès que la cible entre dans son rayon)
		next_is_thrust = not thrust
	_last_auto = &"thrust" if thrust else &"circle"
	if thrust:
		_queue(&"thrust", _thrust.bind(dir))
	else:
		_queue(&"circle", _circle)
	return true


## Anim d'action de chaque sort : base SA1 livrée, sinon le repli d'Ardent.
func action_for(s: SpellData) -> StringName:
	match s.id:
		&"taille_estoc":
			return _action_name(_last_auto) # le coup choisi par _cast_auto
		&"fauche_lune":
			return _action_name(&"crescent")
		&"aiguisage":
			return _action_name(&"sharpen")
		&"lames_jumelles", V_TEMPER:
			return _action_name(&"twin")
		V_SLOW:
			return _action_name(&"slow")
		V_CLEAVE:
			return _action_name(&"cleave")
		V_WALK:
			return _action_name(&"sharpen")
	return &""


func _action_name(key: StringName) -> StringName:
	var cands: Array = ACTIONS.get(key, [])
	if cands.is_empty():
		return &""
	var sf := _visual.sprite_frames if _visual != null else null
	if sf != null:
		for a: StringName in cands:
			if sf.has_animation(StringName("%s_s" % a)) or sf.has_animation(a):
				return a
	return cands[cands.size() - 1]


func _queue(key: StringName, f: Callable) -> void:
	_pending.append([_action_name(key), f])


## Frame d'impact d'une anim : l'effet en attente part (dans l'ordre des lancers).
func _on_action_impact(base: StringName) -> void:
	if not (base in KIT_ACTIONS):
		return
	for i in _pending.size():
		if _pending[i][0] == base:
			var f: Callable = _pending[i][1]
			_pending.remove_at(i)
			if player != null and not player.dead:
				f.call()
			return


func has_pending() -> bool:
	return not _pending.is_empty()


## Déclenche tout de suite les effets en attente (tests).
func flush_pending() -> void:
	var fx := _pending.duplicate()
	_pending.clear()
	for p in fx:
		if player != null and not player.dead:
			(p[1] as Callable).call()


func on_cast(_s: SpellData) -> void:
	pass


# --- Coups --------------------------------------------------------------------------------------------

## Un geste de lame : dégâts × aiguisage du moment, coût retiré, second katana s'il est là.
func _swing(s: SpellData, cost: float, pos: Vector2, arc_dir := Vector2.ZERO, guard_mult := GUARD_TAKEN_MULT) -> void:
	var c := _caster()
	if c == null:
		return
	var hit := _scaled(s, _strike_mult())
	swings += 1
	guard_left = GUARD_S
	_guard_mult = guard_mult
	consume(cost)
	c.spawn_zone(hit, pos, arc_dir)
	LightRig.flash(pos, LIGHT_SPELL, 0.25 * damage_mult() + 0.1)
	if is_twin():
		_delayed.append([TWIN_DELAY_S, _twin_strike.bind(_scaled(hit, TWIN_STRIKE_MULT), arc_dir)])


## Multiplicateur d'un coup : aiguisage x Trempe.
func _strike_mult() -> float:
	return damage_mult() * (TEMPER_MULT if is_tempered() else 1.0)


## Le second katana : même coup (même aiguisage), depuis la position courante, sans coût.
func _twin_strike(hit: SpellData, arc_dir: Vector2) -> void:
	var c := _caster()
	if c == null or player.dead:
		return
	twin_strikes += 1
	c.spawn_zone(hit, player.global_position, arc_dir)
	if _twin_blade != null:
		_twin_blade.flash()


func _circle() -> void:
	var s := _strike_spell(&"taille_estoc", CIRCLE_COEF, CIRCLE_PROC, CIRCLE_KNOCK_U, CIRCLE_RADIUS_U)
	s.is_auto = true
	_with_vfx(s, CIRCLE_FRAMES)
	_swing(s, COST_CIRCLE, player.global_position)


func _thrust(dir: Vector2) -> void:
	var s := _strike_spell(&"taille_estoc", THRUST_COEF, THRUST_PROC, THRUST_KNOCK_U, THRUST_RANGE_U)
	s.is_auto = true
	s.spread_deg = THRUST_SPREAD_DEG
	_with_vfx(s, THRUST_FRAMES)
	_swing(s, COST_THRUST, player.global_position, dir)


func _crescent(dir: Vector2) -> void:
	var s := _strike_spell(&"fauche_lune", CRESCENT_COEF, CRESCENT_PROC, CRESCENT_KNOCK_U, CRESCENT_RADIUS_U)
	s.spread_deg = CRESCENT_SPREAD_DEG
	_with_vfx(s, CRESCENT_FRAMES)
	if _count_in_arc(dir, CRESCENT_RADIUS_U * Balance.UNIT_PX * _zone_k(), deg_to_rad(CRESCENT_SPREAD_DEG) * 0.5) >= CRESCENT_BIG_HITS:
		RunState.add_counter(COUNTER_CRESCENT_BIG) # déblocage du Fendoir
	_swing(s, COST_CRESCENT, player.global_position, dir)


## Monstres dans un secteur (déblocage du Fendoir : 12 touchés d'une seule Fauche-lune).
func _count_in_arc(dir: Vector2, radius_px: float, half_rad: float) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
		var rel: Vector2 = e.global_position - player.global_position
		if rel.length() <= radius_px + er and (rel.length_squared() < 1.0 or absf(dir.angle_to(rel)) <= half_rad):
			n += 1
	return n


## Taille lente : cône de 90°, coup lourd, garde moins haute.
func _slow_cut(dir: Vector2) -> void:
	var s := _strike_spell(V_SLOW, SLOW_COEF, SLOW_PROC, SLOW_KNOCK_U, SLOW_RADIUS_U)
	s.is_auto = true
	s.spread_deg = SLOW_SPREAD_DEG
	_with_vfx(s, SLOW_FRAMES)
	_swing(s, COST_SLOW, player.global_position, dir, SLOW_GUARD_TAKEN_MULT)


## Fendoir : ligne de 5 u x 1 u, puis un pas de 1 u dans l'axe (pas d'invulnérabilité).
func _cleave(dir: Vector2) -> void:
	var c := _caster()
	if c == null:
		return
	var s := _strike_spell(V_CLEAVE, CLEAVE_COEF, CLEAVE_PROC, CLEAVE_KNOCK_U, 0.0, false)
	_with_vfx(s, CLEAVE_FRAMES)
	var hit := _scaled(s, _strike_mult())
	cleaves += 1
	swings += 1
	guard_left = GUARD_S
	_guard_mult = GUARD_TAKEN_MULT
	consume(COST_CRESCENT)
	_cleave_line(hit, player.global_position, dir)
	LightRig.flash(player.global_position, LIGHT_SPELL, 0.25 * damage_mult() + 0.1)
	player.move_and_collide(dir * CLEAVE_STEP_U * Balance.UNIT_PX)
	if is_twin():
		_delayed.append([TWIN_DELAY_S, _twin_cleave.bind(_scaled(hit, TWIN_STRIKE_MULT), dir)])


func _twin_cleave(hit: SpellData, dir: Vector2) -> void:
	if _caster() == null or player.dead:
		return
	twin_strikes += 1
	_cleave_line(hit, player.global_position, dir)
	if _twin_blade != null:
		_twin_blade.flash()


## Frappe tous les monstres dans le rectangle [origine, origine + 5 u] x largeur (zone_size_add sur la largeur).
func _cleave_line(hit: SpellData, origin: Vector2, dir: Vector2) -> int:
	var c := _caster()
	if c == null:
		return 0
	var len_px := CLEAVE_LEN_U * Balance.UNIT_PX
	var half_w := CLEAVE_WIDTH_U * Balance.UNIT_PX * _zone_k() * 0.5
	var n := 0
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
		var rel: Vector2 = e.global_position - origin
		var along := rel.dot(dir)
		if along < -er or along > len_px + er or absf(rel.cross(dir)) > half_w + er:
			continue
		n += 1
		c.deal_damage(e, hit, {"source_pos": e.global_position - dir * Balance.UNIT_PX}) # recul dans l'axe
	if player.get_parent() != null:
		var fx := MorfilCleaveFx.new()
		fx.color = ACCENT
		fx.dir = dir
		fx.length_px = len_px
		fx.width_px = half_w * 2.0
		player.get_parent().add_child(fx)
		fx.global_position = origin
	return n


func _end_walk() -> void:
	walk_left = 0.0
	_walk_acc = 0.0


func _do_sharpen() -> void:
	sharpen()
	LightRig.flash(player.global_position, LIGHT_SPELL, 0.5)
	Audio.play(&"pickup.coin", player.global_position, -10.0, 2.2) # crissement de pierre (repli sonore)


func _twin_draw() -> void:
	twin_total = twin_duration_s()
	twin_left = twin_total
	var s := _strike_spell(&"lames_jumelles", TWIN_DRAW_COEF, 1.0, 0.8, TWIN_DRAW_RADIUS_U)
	_with_vfx(s, TWIN_DRAW_FRAMES)
	var c := _caster()
	if c != null:
		c.spawn_zone(_scaled(s, damage_mult()), player.global_position) # dégainé : sans coût
	LightRig.flash(player.global_position, LIGHT_SPELL, 0.9)


## Trempe : lame au fil (100 %), dégainé gratuit, puis plus d'usure et dégâts x1,5 pendant la moitié de la recharge.
func _temper_draw() -> void:
	sharpen()
	temper_total = twin_duration_s()
	temper_left = temper_total
	var s := _strike_spell(V_TEMPER, TWIN_DRAW_COEF, 1.0, 0.8, TWIN_DRAW_RADIUS_U)
	_with_vfx(s, TWIN_DRAW_FRAMES)
	var c := _caster()
	if c != null:
		c.spawn_zone(_scaled(s, damage_mult()), player.global_position)
	LightRig.flash(player.global_position, LIGHT_SPELL, 1.0)


func _iai_step() -> void:
	var c := _caster()
	if c == null:
		return
	var r := IAI_RADIUS_U * Balance.UNIT_PX
	var any := false
	var hit := _scaled(_iai_spell, _strike_mult())
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or _iai_hit.has(e.get_instance_id()):
			continue
		var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
		if e.global_position.distance_to(player.global_position) <= r + er:
			_iai_hit[e.get_instance_id()] = true
			c.deal_damage(e, hit, {"source_pos": player.global_position})
			if is_twin():
				twin_strikes += 1
				c.deal_damage(e, hit, {"source_pos": player.global_position})
			any = true
	if any:
		if not _iai_paid: # un seul coût par roulade
			_iai_paid = true
			swings += 1
			consume(COST_IAI)
		LightRig.flash(player.global_position, LIGHT_SPELL, 0.15)


## PLACEHOLDER (VFX `iai_trail` du lot SA1) : un fil de sève tendu sur le trajet de l'Iaï, qui s'éteint en 0,3 s.
const IAI_TRAIL_S := 0.3
func _iai_trail(a: Vector2, b: Vector2) -> void:
	if player.get_parent() == null or a.distance_squared_to(b) < 64.0:
		return
	var l := Line2D.new()
	l.width = 3.0
	l.default_color = Color(ACCENT.r * 1.6, ACCENT.g * 1.6, ACCENT.b * 1.6, 0.9)
	l.points = PackedVector2Array([a, b])
	l.z_index = 5
	player.get_parent().add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, ^"modulate:a", 0.0, IAI_TRAIL_S)
	tw.tween_callback(l.queue_free)


# --- Boucle (appelée par Player.tick, avant les sorts) -------------------------------------------

func tick(delta: float) -> void:
	if player == null or player.dead:
		return
	sharpen_left = maxf(sharpen_left - delta, 0.0)
	guard_left = maxf(guard_left - delta, 0.0)
	if twin_left > 0.0:
		twin_left = maxf(twin_left - delta, 0.0)
	if temper_left > 0.0:
		temper_left = maxf(temper_left - delta, 0.0)
	if walk_left > 0.0:
		walk_left = maxf(walk_left - delta, 0.0)
		_walk_acc += delta
		while _walk_acc >= WALK_TICK_S:
			_walk_acc -= WALK_TICK_S
			sharpness = minf(sharpness + WALK_RATE * WALK_TICK_S, SHARP_MAX)
		if sharpness >= SHARP_MAX - 0.001:
			_end_walk() # lame au fil : la posture se termine
	if not _delayed.is_empty():
		var due: Array = []
		for d in _delayed:
			d[0] -= delta
			if d[0] <= 0.0:
				due.append(d)
		for d in due:
			_delayed.erase(d)
			(d[1] as Callable).call()
	if _iai_active:
		if player.is_dodging():
			_iai_step()
		else:
			_iai_active = false
			_iai_trail(_iai_from, player.global_position)
	_update_look()


## Ressource (contrat KitResource) : jauge continue d'aiguisage, repère au seuil de l'ultime.
func resource_state() -> Dictionary:
	return KitResource.make(&"sharpness", "Aiguisage", sharp_ratio(), ACCENT,
		{"text": "%d %%" % roundi(sharpness), "mark": SHARP_ULT_MIN / SHARP_MAX, "boost": is_twin() or is_tempered()})


func save_state() -> Dictionary:
	return {"sharpness": sharpness, "twin_left": twin_left, "twin_total": twin_total,
		"temper_left": temper_left, "temper_total": temper_total}


func load_state(d: Dictionary) -> void:
	sharpness = clampf(float(d.get("sharpness", SHARP_MAX)), SHARP_MIN, SHARP_MAX)
	twin_left = maxf(float(d.get("twin_left", 0.0)), 0.0)
	twin_total = maxf(float(d.get("twin_total", twin_left)), twin_left)
	temper_left = maxf(float(d.get("temper_left", 0.0)), 0.0)
	temper_total = maxf(float(d.get("temper_total", temper_left)), temper_left)


# --- Nettoyage ---------------------------------------------------------------------------------

func clear_transients() -> void:
	_pending.clear()
	_delayed.clear()
	_iai_active = false
	_iai_hit.clear()
	_end_walk()


## Entre deux étages, Taliant repasse la pierre : lame au fil.
func _on_floor_started(_n: int) -> void:
	clear_transients()
	sharpness = SHARP_MAX


## Boss d'étage vaincu à l'étage 2 (déblocage de la Trempe).
func _on_boss_killed(_boss: Node2D, is_floor_boss: bool) -> void:
	if is_floor_boss and RunState.stage == BOSS_FLOOR:
		RunState.add_counter(COUNTER_BOSS2)


func _on_player_died() -> void:
	twin_left = 0.0
	temper_left = 0.0
	clear_transients()
	if _twin_blade != null:
		_twin_blade.visible = false
	if _visual != null and _visual.sprite_frames != null:
		var anim := _resolve(&"death", _dir_name())
		if anim != &"":
			_visual.sprite_frames.set_animation_loop(anim, false)
			_visual.play(anim)


# --- Rendu ----------------------------------------------------------------------------------------

func _dir_name() -> String:
	var i := roundi(player.facing.angle() / (TAU / 8.0)) % 8
	return DIR_NAMES[(i + 8) % 8]


func _resolve(base: StringName, dir: String) -> StringName:
	if _visual == null or _visual.sprite_frames == null:
		return &""
	for a: StringName in [StringName("%s_%s" % [base, dir]), base]:
		if _visual.sprite_frames.has_animation(a):
			return a
	return &""


## Roulade : `dodge_<dir>` (Iaï) si livrée ; Lames jumelles : variante `<base>_dual_<dir>` si livrée.
func visual_anim(fallback: StringName) -> StringName:
	if player.is_dodging():
		var a := _resolve(&"dodge", _dir_name())
		if a != &"":
			return a
	if player.hurt_flash_left() > 0.0 and player.action_left() <= 0.0: # coup reçu : `hurt_<dir>` (SA1)
		var h := _resolve(&"hurt", _dir_name())
		if h != &"":
			return h
	if is_twin() and _visual != null and _visual.sprite_frames != null:
		var s := String(fallback)
		var i := s.rfind("_")
		if i > 0:
			var dual := StringName("%s_dual%s" % [s.substr(0, i), s.substr(i)])
			if _visual.sprite_frames.has_animation(dual):
				return dual
	return fallback


## Repli de la lame jumelle (tant que les anims `_dual` de SA1 manquent) : un fil de sève tenu dans l'autre main.
func _update_look() -> void:
	if _twin_blade == null:
		return
	var has_dual := _visual != null and _visual.sprite_frames != null and _visual.sprite_frames.has_animation(&"idle_dual_s")
	_twin_blade.visible = is_twin() and not has_dual
	if _twin_blade.visible:
		_twin_blade.facing = player.facing
		_twin_blade.fade = clampf(twin_left / 1.0, 0.0, 1.0) # s'éteint sur la dernière seconde
		_twin_blade.queue_redraw()



# --- Passif expliqué (infobulle du HUD ; contrat KitResource.passive) ------------------------------------

static func passive_info() -> Dictionary:
	var f := KitResource.fmt
	return KitResource.passive("Aiguisage", &"aiguisage",
		"Le katana s'émousse à chaque geste. Tes dégâts suivent le fil de la lame.",
		"le sort Aiguisage (recharge %s s) remonte la lame à %s %%." % [f.call(SHARPEN_CD), f.call(SHARP_MAX)],
		"chaque geste de lame retire des points : Taille ou estoc %s, Fauche-lune %s, roulade Iaï %s. Jamais sous %s %%." % [
			f.call(COST_CIRCLE), f.call(COST_CRESCENT), f.call(COST_IAI), f.call(SHARP_MIN)],
		"tes coups infligent autant de pour cent de leurs dégâts que d'aiguisage (100 %% = dégâts pleins, 50 %% = moitié). Lames jumelles (sort 4) : %s %% minimum." % f.call(SHARP_ULT_MIN))


## SpellHint : les coups réels portent déjà l'aiguisage dans leur coef (`_scaled`), l'aperçu l'applique ici.
func preview_mult(_s: SpellData) -> float:
	return damage_mult()
