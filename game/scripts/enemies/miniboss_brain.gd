class_name MiniBossBrain
extends RefCounted
## IA des mini-boss pilotée par données (data/minibosses.json). Créée par Enemy.activate_boss pour un
## mini-boss dont l'identifiant a une fiche (méta `next_mini_id` du Director posée par le petit pilier,
## sinon le skin résolu), appelée par Enemy.tick (branche BOSS_TIER) à la place de l'IA générique.
## Chaque mini = un jeu de motifs de la bibliothèque MiniPatterns (cône, ligne, charge, éventail de
## projectiles, anneau, cercles, invocation, bond, rayon canalisé, enfouissement), télégraphés vers le
## joueur ; les dégâts tombent à la fin du télégraphe, calée sur la frame d'impact de l'anim
## (EnemyVisual.play_attack). Phase 2 sous le seuil (50 %) : transition (boss figé), lumière plus forte,
## surcharges `p2` des motifs, motifs `phase: 2`, sort d'entrée (`on_enter`), passifs perdus.
## Art absent : corps emprunté à un mini livré (fallback.sprite) teinté et mis à l'échelle ; l'art du mini
## se branche seul dès que son .tres existe (chemin enregistré dans data/fauna.json boss_sprites).

const DATA_PATH := "res://data/minibosses.json"
const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const AIM_TRACK := 0.5 ## part du télégraphe d'un sort pendant laquelle il suit le joueur
const AUTO_GAP_AFTER_SPELL := 0.5
const TINT_MIN_R := 0.78 ## le flash de coup passe par COLOR.r > 1,5 (sprite_flash) : la teinte ne doit pas l'éteindre
const HIST_KEEP_S := 1.2
## Catégorie de rythme (BossPace) d'un motif : gros coup si coef >= HEAVY_COEF ou armement JSON >= HEAVY_WINDUP.
const HEAVY_COEF := 1.8
const HEAVY_WINDUP := 1.4

enum S { CHASE, WIND, ACTIVE, RECOVER, STAGGER }

static var _data: Dictionary = {}
static var _loaded := false

var e: Enemy
var vis: EnemyVisual
var mini_id: StringName
var cfg: Dictionary = {}
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT
var cur: Dictionary = {} ## motif en cours (paramètres fusionnés phase 2 + état d'exécution)
var t := 0.0 ## temps écoulé dans l'étape courante du motif
var events: Array[Dictionary] = [] ## journal (tests) : pattern, type, kind, hit, frame, lag, armed, spawned, phase
var ai_enabled := true ## tests : false = n'agit que sur force()
var fallback_sprite: StringName = &"" ## corps emprunté (art du mini absent), &"" sinon
var rng := RandomNumberGenerator.new()
var player: Node2D = null
var ppos := Vector2.ZERO ## position réelle du joueur à ce pas
var apos := Vector2.ZERO ## position visée (aim_lag_s : position d'il y a N s)
## Rythme commun des coups (armement planté, impact, récupération immobile ; lu par les tests génériques).
var pace: BossPace

var _cd := {}
var _spell_gap := 0.0
var _auto_gap := 0.0
var _recover_left := 0.0
var _stagger_left := 0.0
var _on_enter := &""
var _forced := &""
var _speed_mult := 1.0
var _phase_speed := 1.0
var _cd_mult := 1.0
var _passives: Array = []
var _summons: Array[Enemy] = []
var _eggs: Array[Dictionary] = []
var _zones: Array[Dictionary] = []
var _teles: Array[EnemyTelegraph] = []
var _rings: Array[RecluseFx] = []
var _fx: Array[Node] = [] ## tous les nœuds créés (libérés par clear)
var _rim: LightRig.Handle = null
var _hist_t := PackedFloat32Array()
var _hist_p := PackedVector2Array()
var _clock := 0.0
var _vuln_left := 0.0
var _haste_left := 0.0
var _rage := 0.0
var _regen_done := 0.0
var _moving_t := 0.0
var _still_t := 0.0
var _last_ppos := Vector2.INF
var hidden := false ## sous terre / évanoui : invisible et intouchable
var summoned_total := 0 ## invocations nées depuis l'apparition (tests)
var _cleared := false
var hazards: MiniHazards = null ## obstacles réels et projectiles spéciaux (créé à la demande)
var jam_count := 0 ## brouillages de minimap lancés (tests)
var shocks := 0 ## électrocutions du joueur dans l'eau (tests)
var dissolved := 0.0 ## PV perdus en se dissolvant dans l'eau (tests)
var _dissolve_acc := 0.0
var _gap_tele: SmelterFx = null
static var _water_grid: Dictionary = {} ## carte (instance id) -> grille d'eau peu profonde {grid, cell, origin, frame, map}

const FROST_MULT := 0.55 ## statut « frost » (gel) : ralentissement fort et court (Player.apply_slow)
const FROST_S := 1.5
const STATUS_COLORS := {"burn": Color(1.0, 0.55, 0.2), "poison": Color(0.48, 0.88, 0.29), "frost": Color(0.62, 0.9, 1.0), "slow": Color(0.72, 0.62, 0.45)}


# --- Données -----------------------------------------------------------------

static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var txt := FileAccess.get_file_as_string(DATA_PATH)
		var d: Variant = JSON.parse_string(txt) if txt != "" else null
		_data = d if d is Dictionary else {}
	return _data


## Tests / outils : relit le JSON.
static func reload() -> void:
	_loaded = false
	data()


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in (data().get("minis", {}) as Dictionary):
		out.append(StringName(k))
	return out


static func has_config(id: StringName) -> bool:
	return (data().get("minis", {}) as Dictionary).has(String(id))


## Fiche du mini fusionnée avec les valeurs par défaut (phase2, light, speed_u, keep_u).
static func config(id: StringName) -> Dictionary:
	var d := data()
	var raw: Dictionary = (d.get("minis", {}) as Dictionary).get(String(id), {})
	if raw.is_empty():
		return {}
	var c: Dictionary = (d.get("defaults", {}) as Dictionary).duplicate(true)
	for k in raw:
		if raw[k] is Dictionary and c.get(k) is Dictionary:
			(c[k] as Dictionary).merge(raw[k], true)
		else:
			c[k] = raw[k]
	return c


## Identifiant de mini-boss d'un boss qui apparaît : celui imposé par le petit pilier (plan de run, même
## sans art livré), sinon le skin résolu.
static func resolve_id(enemy: Enemy) -> StringName:
	var d := enemy.director
	if d != null and d.has_meta(&"next_mini_id"):
		return StringName(d.get_meta(&"next_mini_id"))
	return enemy._boss_sprite_id


static func color_of(v: Variant, def := Color.WHITE) -> Color:
	return Color.html(v) if v is String and Color.html_is_valid(v) else def


# --- Cycle de vie ---------------------------------------------------------------

func _init(enemy: Enemy, id: StringName) -> void:
	e = enemy
	vis = enemy.visual as EnemyVisual
	pace = BossPace.new(enemy)
	mini_id = id
	cfg = config(id)
	rng.seed = hash(String(id))
	_speed_mult = Balance.mini_speed_mult(float(cfg.get("speed_u", Balance.MINI_DESIGN_SPEED_REF_U)))
	_passives = (cfg.get("passives", []) as Array).duplicate(true)
	for p: Dictionary in patterns():
		_cd[p["id"]] = float(p.get("first_cd", float(p.get("cd", 4.0)) * (0.3 if p.get("auto", false) else 0.5)))
	_apply_fallback()
	_apply_light()
	_apply_outline()
	if not Events.lightning_struck.is_connected(_on_lightning):
		Events.lightning_struck.connect(_on_lightning)


func patterns() -> Array:
	return cfg.get("patterns", [])


func pattern(id: StringName) -> Dictionary:
	for p: Dictionary in patterns():
		if StringName(p["id"]) == id:
			return p
	return {}


## Mort ou retour au pool : télégraphes, zones, œufs, lumières et nœuds libérés ; visuel rendu intact.
## Les invocations déjà nées restent (monstres ordinaires).
func clear() -> void:
	_cleared = true
	if Events.lightning_struck.is_connected(_on_lightning):
		Events.lightning_struck.disconnect(_on_lightning)
	if is_instance_valid(hazards):
		hazards.release()
	hazards = null
	_gap_tele = null
	_outline = null
	if is_instance_valid(e):
		e.telegraph.hide_telegraph()
	for z in _zones:
		if z.get("light") != null:
			(z["light"] as LightRig.Handle).release()
	_zones.clear()
	_eggs.clear()
	for n in _fx:
		if is_instance_valid(n):
			n.queue_free()
	_fx.clear()
	_teles.clear()
	_rings.clear()
	_summons.clear()
	if _rim != null:
		_rim.release()
	_rim = null
	if is_instance_valid(vis):
		vis.modulate = Color.WHITE
		vis.scale = Vector2.ONE
		vis.visible = true
	if is_instance_valid(e) and e._light != null:
		e._light.set_energy(1.0)
		e._light.set_radius_mult(1.0)
		e._light.set_color(Color(0, 0, 0, 0))
	hidden = false
	cur = {}
	state = S.CHASE
	if pace != null and is_instance_valid(e):
		pace.cancel()


## Nœuds créés encore vivants (tests de nettoyage).
func live_node_count() -> int:
	var n := 0
	for x in _fx:
		if is_instance_valid(x) and not x.is_queued_for_deletion():
			n += 1
	return n


func zone_count() -> int:
	return _zones.size()


func summon_count() -> int:
	var n := 0
	for s in _summons:
		if is_instance_valid(s) and s.active and not s.is_boss:
			n += 1
	return n


## Ruée, bond, enfouissement : le motif déplace le corps ; armement et récupération : planté (ni marche, ni
## séparation de foule, ni recul).
func owns_motion() -> bool:
	return (state == S.ACTIVE and cur.get("_moving", false)) or pace.planted()


## Super-armure le temps du coup (armement, récupération) : un recul ferait glisser le mini planté.
func ignores_knockback() -> bool:
	return pace.planted()


func busy() -> bool:
	return state != S.CHASE or _forced != &"" or vis.is_attacking()


## Tests : lance le motif `id` au prochain pas libre (sans portée ni recharge).
func force(id: StringName) -> void:
	_forced = id


# --- Apparence -------------------------------------------------------------------

func _apply_fallback() -> void:
	var fb: Dictionary = cfg.get("fallback", {})
	var gain := float(cfg.get("body_gain", 1.0)) # corps éclairci : jamais une silhouette noire sur le sol de nuit
	gain *= float((cfg.get("biome_gain", {}) as Dictionary).get(String(cfg.get("biome", "")), 1.0)) # biomes nocturnes (Cité, Cryptes)
	if EnemyVisual.boss_available(mini_id):
		gain = minf(gain, maxf(NormalMaps.body_gain_cap(mini_id), 1.0)) # sprite clair (sel, os) : pas de gain qui grille
		vis.modulate = Color(gain, gain, gain)
		return
	var want := StringName(fb.get("sprite", ""))
	if want != &"" and EnemyVisual.boss_available(want):
		if want != e._boss_sprite_id:
			vis.configure(Enemy.BOSS_TIER, e.radius_px, true, 0, want)
		fallback_sprite = want
	else:
		fallback_sprite = e._boss_sprite_id
	var tint := color_of(fb.get("tint"), Color.WHITE)
	tint.r = maxf(tint.r, TINT_MIN_R)
	vis.modulate = Color(tint.r * gain, tint.g * gain, tint.b * gain)
	vis.scale = Vector2.ONE * float(fb.get("scale", 1.0))


## Liseré de silhouette (lisibilité de nuit, en attendant l'art Codex) : copie du corps, teinte unie froide non
## éclairée, décalée vers le haut-gauche (lumière du jeu) et dessinée derrière le corps : la silhouette se
## découpe sur le sol sombre même quand l'albédo du sprite est noir. Données : outline {alpha, px} (× biome_rim).
static var _outline_shader: Shader = null
var _outline: AnimatedSprite2D = null


func _apply_outline() -> void:
	var oc: Dictionary = cfg.get("outline", {})
	var body := vis.body_sprite() if vis.has_method(&"body_sprite") else null
	if oc.is_empty() or body == null or float(oc.get("alpha", 0.0)) <= 0.0:
		return
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = "shader_type canvas_item;\nrender_mode unshaded;\nuniform vec4 rim : source_color = vec4(0.8, 0.9, 1.0, 0.5);\nvoid fragment() {\n\tCOLOR = vec4(rim.rgb, texture(TEXTURE, UV).a * rim.a);\n}\n"
	_outline = AnimatedSprite2D.new()
	_outline.name = &"MiniOutline"
	var m := ShaderMaterial.new()
	m.shader = _outline_shader
	var col := color_of((_light_cfg().get("rim", {}) as Dictionary).get("color"), Color(0.81, 0.91, 1.0))
	var rk := float((cfg.get("biome_rim", {}) as Dictionary).get(String(cfg.get("biome", "")), 1.0))
	col.a = clampf(float(oc.get("alpha", 0.5)) * sqrt(rk), 0.0, 0.9)
	m.set_shader_parameter(&"rim", col)
	_outline.material = m
	_outline.light_mask = 0
	vis.add_child(_outline)
	vis.move_child(_outline, 0) # derrière le corps
	_fx.append(_outline)
	_sync_outline()


func _sync_outline() -> void:
	if _outline == null or not is_instance_valid(_outline):
		return
	var body := vis.body_sprite()
	if body == null or not body.visible:
		_outline.visible = false
		return
	_outline.visible = true
	if _outline.sprite_frames != body.sprite_frames:
		_outline.sprite_frames = body.sprite_frames
	if _outline.animation != body.animation:
		_outline.animation = body.animation
	_outline.frame = body.frame
	_outline.flip_h = body.flip_h
	_outline.scale = body.scale
	_outline.offset = body.offset
	var px := float((cfg.get("outline", {}) as Dictionary).get("px", 2.5))
	_outline.position = body.position + Vector2(-px, -px * 1.4)


func _light_cfg() -> Dictionary:
	return cfg.get("light", {})


func _apply_light() -> void:
	var lc := _light_cfg()
	if e._light != null: # le preset « boss » reste (contrat) : couleur du JSON (sinon celle du preset historique) + énergie absolue
		var pr := StringName(lc.get("preset", "boss"))
		var col: Variant = lc.get("color", LightRig.get_preset(pr).get("color") if LightRig.has_preset(pr) else null)
		if col != null:
			e._light.set_color(color_of(col))
	var rim: Dictionary = lc.get("rim", {})
	if not rim.is_empty() and _rim == null:
		# lumière basse qui découpe la silhouette sur le sol sombre (leçon du Sonneur : jamais un corps noir)
		_rim = LightRig.attach(e, &"boss_cerf_hooves", {"color": color_of(rim.get("color"), Color.WHITE)})
	_light_phase(0.0)


func _light_phase(boost: float) -> void:
	var lc := _light_cfg()
	var i := phase - 1
	var en: Array = lc.get("energy", [1.7, 2.1])
	var ra: Array = lc.get("radius", [1.0, 1.25])
	if e._light != null: # énergie absolue du JSON -> multiplicateur du preset
		e._light.set_energy((float(en[mini(i, en.size() - 1)]) + boost) / _preset_energy(e._light.preset))
		e._light.set_radius_mult(float(ra[mini(i, ra.size() - 1)]) * (1.0 + 0.3 * boost))
	if _rim != null:
		var rk := float((cfg.get("biome_rim", {}) as Dictionary).get(String(cfg.get("biome", "")), 1.0)) # liseré renforcé la nuit
		_rim.set_energy(float((lc.get("rim", {}) as Dictionary).get("energy", 0.9)) * rk * (1.15 if phase >= 2 else 1.0) / _preset_energy(_rim.preset))


static func _preset_energy(pr: StringName) -> float:
	return maxf(float(LightRig.get_preset(pr).get("energy", 1.0)), 0.05)


## Énergie absolue de la lumière principale (tests).
func light_abs_energy() -> float:
	return e._light.energy_mult * _preset_energy(e._light.preset) if e._light != null else 0.0


func light_energy() -> float:
	return e._light.energy_mult if e._light != null else 0.0


# --- Pas d'IA ------------------------------------------------------------------------

func tick(delta: float, p_player: Node2D, p_ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	player = p_player
	ppos = p_ppos
	pace.tick(delta)
	_clock += delta
	_sync_outline()
	_track_player(delta)
	_update_zones(delta)
	_update_eggs(delta)
	_update_passives(delta)
	for k in _cd:
		_cd[k] = float(_cd[k]) - delta
	_spell_gap -= delta
	_auto_gap -= delta
	_vuln_left -= delta
	_haste_left -= delta
	if phase == 1 and e.hp / e.max_hp <= float((cfg.get("phase2", {}) as Dictionary).get("threshold", Balance.MINI_BOSS_PHASE_THRESHOLD)):
		_enter_phase2()
	match state:
		S.STAGGER:
			_stagger_left -= delta
			_face(dir)
			if _stagger_left <= 0.0:
				state = S.CHASE
				if _on_enter != &"":
					_forced = _on_enter
					_on_enter = &""
			return Vector2.ZERO
		S.WIND, S.ACTIVE:
			t += delta
			if MiniPatterns.step(self, cur, delta):
				_finish()
			return Vector2.ZERO
		S.RECOVER: # récupération immobile (durée tenue par BossPace)
			_recover_left = pace.recover_left
			if not pace.recovering():
				state = S.CHASE
			return Vector2.ZERO
	# --- CHASE
	if pace.recovering():
		_face(dir)
		return Vector2.ZERO
	if _forced != &"":
		var fp := pattern(_forced)
		_forced = &""
		if not fp.is_empty():
			_start(fp, dir)
			return Vector2.ZERO
	if vis.is_attacking(): # retour de fente : planté, face au joueur
		_face(dir)
		return Vector2.ZERO
	if not ai_enabled:
		_face(dir)
		return Vector2.ZERO
	var los := path_dir == Vector2.ZERO
	var p := _pick(dist, los)
	if not p.is_empty():
		_start(p, dir)
		return Vector2.ZERO
	var keep := float(cfg.get("keep_u", 1.8)) * U + e.radius_px * 0.5
	var spd := e.speed_px * move_speed_mult()
	var kite := float(cfg.get("kite_u", 0.0)) * U
	if kite > 0.0 and dist < kite and los:
		return -dir * spd * 0.6
	if dist > keep:
		return (path_dir if path_dir != Vector2.ZERO else dir) * spd
	_face(dir)
	return Vector2.ZERO


func move_speed_mult() -> float:
	var m := _speed_mult * _phase_speed
	for ps: Dictionary in _passives:
		match String(ps.get("type", "")):
			"haste_after":
				if _haste_left > 0.0:
					m *= float(ps.get("mult", 1.2))
			"echo_speed":
				var k := float(ps.get("mult", 0.2))
				m *= (1.0 + k) if _moving_t > 0.0 else ((1.0 - k) if _still_t >= 1.0 else 1.0)
			"wader": # échasses : plus vif dans l'eau
				if in_water(e.position):
					m *= float(ps.get("mult", 1.3))
	return m


## Sort prêt et à portée (ordre de la fiche, en rotation), sinon attaque de base à portée.
func _pick(dist: float, los: bool) -> Dictionary:
	var ps := patterns()
	if ps.is_empty():
		return {}
	var off := rng.randi() % ps.size()
	for pass_auto: bool in [false, true]:
		if not pass_auto and _spell_gap > 0.0:
			continue
		if pass_auto and _auto_gap > 0.0:
			continue
		for i in ps.size():
			var p: Dictionary = ps[(i + off) % ps.size()]
			if bool(p.get("auto", false)) != pass_auto or int(p.get("phase", 1)) > phase:
				continue
			if float(_cd.get(p["id"], 0.0)) > 0.0:
				continue
			var q := _merged(p)
			if dist < float(q.get("min_u", 0.0)) * U or dist > float(q.get("max_u", 99.0)) * U + e.radius_px:
				continue
			var t_type := String(q.get("type", ""))
			if not los and t_type in ["charge", "line", "beam", "projectile_fan", "cone"]:
				continue
			return p
	return {}


## Paramètres du motif dans la phase courante (surcharges `p2`).
func _merged(p: Dictionary) -> Dictionary:
	var q := p.duplicate(true)
	if phase >= 2 and p.get("p2") is Dictionary:
		q.merge(p["p2"], true)
	q.erase("p2")
	return q


func _start(p: Dictionary, dir: Vector2) -> void:
	cur = _merged(p)
	var is_auto := bool(cur.get("auto", false))
	_cd[p["id"]] = float(cur.get("cd", 4.0)) * _cd_mult
	if is_auto:
		_auto_gap = 0.0
	else:
		_spell_gap = Balance.MINI_SPELL_GAP_S
		_auto_gap = AUTO_GAP_AFTER_SPELL
	var to := apos - e.position
	aim = to.normalized() if to.length_squared() > 1.0 else dir
	_face(aim)
	var cat := pace_kind(cur)
	cur["_cat"] = cat
	cur["_wind"] = BossPace.windup(cat, phase, Balance.mini_windup(float(cur.get("windup", 0.8)), is_auto))
	if String(cur.get("type", "")) == "projectile_fan":
		cur["_wind"] = maxf(float(cur["_wind"]), vis.attack_impact_time(StringName(cur.get("anim", "attack"))))
	cur["_repeat"] = int(cur.get("repeat", 0))
	cur["_armed"] = true
	t = 0.0
	state = S.WIND
	pace.wind(cat)
	MiniPatterns.begin(self, cur)
	e._sfx(&"telegraph.warn_light.light" if is_auto else &"telegraph.boss.heavy", -4.0 if is_auto else 0.0, not is_auto)


func _finish() -> void:
	hide_teles()
	_set_camo(false)
	if hidden:
		_set_hidden(false)
	for ps: Dictionary in _passives:
		if String(ps.get("type", "")) == "haste_after" and StringName(ps.get("pattern", "")) == StringName(cur.get("id", "")):
			_haste_left = float(ps.get("for_s", 5.0))
		if String(ps.get("type", "")) == "rage_on_hit" and StringName(ps.get("reset_on", "")) == StringName(cur.get("id", "")):
			_rage = 0.0
	# récupération immobile : recover_s de la fiche (plancher BossPace) sinon la table de la catégorie ;
	# enchaînement (repeat) : au moins la récupération de combo ; écrasé contre un mur : + _stun
	var cat := StringName(cur.get("_cat", pace_kind(cur)))
	var rec := float(cur["recover_s"]) if cur.has("recover_s") else BossPace.recover_s(cat, phase)
	if int(cur.get("repeat", 0)) > 0:
		rec = maxf(rec, BossPace.recover_s(&"combo", phase))
	rec = maxf(rec, Balance.BOSS_PACE_RECOVER_MIN_S) + float(cur.get("_stun", 0.0))
	if bool(cur.get("_impacted", false)):
		pace.recover_for(rec) # impact déjà joué (éclat du rayon, salve, canalisation)
	else:
		pace.strike(cat, phase, true, rec)
	cur = {}
	_light_phase(0.0)
	_recover_left = rec
	state = S.RECOVER


## Catégorie de rythme d'un motif (Balance.BOSS_PACE_*) : autos = mini_auto ; charge, bond, enfouissement =
## charge ; gros coups (coef >= HEAVY_COEF ou armement de fiche >= HEAVY_WINDUP) = heavy ; sinon spell.
static func pace_kind(q: Dictionary) -> StringName:
	if bool(q.get("auto", false)):
		return &"mini_auto"
	if String(q.get("type", "")) in ["charge", "leap", "burrow"]:
		return &"charge"
	if float(q.get("coef", 0.0)) >= HEAVY_COEF or float(q.get("windup", 0.0)) >= HEAVY_WINDUP:
		return &"heavy"
	return &"spell"


# --- Phase 2 ----------------------------------------------------------------------------

func _enter_phase2() -> void:
	var p2: Dictionary = cfg.get("phase2", {})
	pace.cancel()
	if state == S.WIND or state == S.ACTIVE:
		MiniPatterns.cancel(self, cur)
		hide_teles()
		_set_camo(false)
		if hidden:
			_set_hidden(false)
		cur = {}
	phase = 2
	vis.set_phase(2) # phase2_s (déjà lancée si les PV y ont mené)
	state = S.STAGGER
	_stagger_left = float(p2.get("stagger_s", 0.9))
	_phase_speed = float(p2.get("speed_mult", 1.0))
	_cd_mult = float(p2.get("cd_mult", 0.85))
	_on_enter = StringName(p2.get("on_enter", ""))
	for drop in (p2.get("drop_passives", []) as Array):
		for i in range(_passives.size() - 1, -1, -1):
			if String((_passives[i] as Dictionary).get("type", "")) == String(drop):
				_passives.remove_at(i)
	for p: Dictionary in patterns(): # les sorts de phase 2 arrivent vite
		if int(p.get("phase", 1)) == 2:
			_cd[p["id"]] = minf(float(_cd.get(p["id"], 0.0)), 1.5)
	_light_phase(0.0)
	LightRig.flash(e.global_position, StringName(_light_cfg().get("preset", "boss")), 0.45)
	e._sfx(&"telegraph.boss.heavy", 2.0, true)
	events.append({"pattern": &"", "type": "phase", "kind": &"phase", "phase": 2, "frame": Engine.get_physics_frames()})


# --- Passifs ------------------------------------------------------------------------------

## Multiplicateur de dégâts reçus (Enemy.take_damage) : gardes, carapaces, enfoui.
func damage_taken_mult() -> float:
	if hidden:
		return 0.0
	var m := 1.0
	for ps: Dictionary in _passives:
		match String(ps.get("type", "")):
			"front_guard":
				var to := ppos - e.position
				if to.length_squared() > 1.0 and absf(angle_difference(e._facing, to.angle())) <= deg_to_rad(float(ps.get("half_deg", 60.0))):
					m *= float(ps.get("mult", 0.6))
			"flat_guard":
				if _vuln_left <= 0.0:
					m *= float(ps.get("mult", 0.7))
			"summon_guard":
				if summon_count() >= int(ps.get("min", 3)):
					m *= float(ps.get("mult", 0.65))
			"far_guard":
				if ppos.distance_to(e.position) > float(ps.get("min_u", 4.0)) * U:
					m *= float(ps.get("mult", 0.7))
			"rage_on_hit":
				_rage = minf(_rage + float(ps.get("per", 0.05)), float(ps.get("max", 0.5)))
			"dry_vuln": # peau glissante : plus fragile hors de l'eau
				if not in_water(e.position):
					m *= float(ps.get("mult", 1.3))
	return maxf(m, Balance.MINI_GUARD_MIN)


## Multiplicateur des dégâts infligés (rage, meute).
func damage_out_mult() -> float:
	var m := 1.0 + _rage
	for ps: Dictionary in _passives:
		match String(ps.get("type", "")):
			"summon_rage":
				m += float(ps.get("per", 0.1)) * summon_count()
			"obstacle_rage": # aime son terrain : plus fort près de ses obstacles
				if is_instance_valid(hazards) and hazards.nearest_obstacle(e.position, StringName(ps.get("style", ""))) <= float(ps.get("near_u", 2.0)) * U:
					m += float(ps.get("mult", 0.2))
	return m


func _update_passives(delta: float) -> void:
	for ps: Dictionary in _passives:
		match String(ps.get("type", "")):
			"summon_regen":
				var cap := float(ps.get("cap", 0.08)) * e.max_hp
				if _regen_done < cap and summon_count() >= int(ps.get("min", 3)) and e.hp < e.max_hp:
					var h := minf(float(ps.get("pct_s", 0.01)) * e.max_hp * delta, cap - _regen_done)
					e.hp = minf(e.hp + h, e.max_hp)
					_regen_done += h
			"dissolve": # se dissout dans l'eau peu profonde (le joueur peut l'y attirer)
				if in_water(e.position):
					_dissolve_acc += float(ps.get("pct_s", 0.02)) * e.max_hp * delta
					if _dissolve_acc >= e.max_hp * 0.005 and e.hp > _dissolve_acc + 1.0:
						dissolved += _dissolve_acc
						e.take_damage(_dissolve_acc, false, &"poison", {"is_dot": true})
						_dissolve_acc = 0.0
			"shroud":
				if state == S.CHASE or state == S.RECOVER:
					var lit := ppos.distance_to(e.position) <= float(ps.get("near_u", 4.0)) * U or _in_light_zone(e.position)
					vis.modulate.a = 1.0 if lit else float(ps.get("alpha", 0.35))


func _in_light_zone(p: Vector2) -> bool:
	for z in _zones:
		if z.get("light") != null and p.distance_to(z["pos"]) <= float(z.get("light_r", 0.0)):
			return true
	return false


func _track_player(delta: float) -> void:
	if _last_ppos != Vector2.INF:
		if ppos.distance_squared_to(_last_ppos) > 4.0:
			_moving_t = 0.4
			_still_t = 0.0
		else:
			_moving_t -= delta
			_still_t += delta
	_last_ppos = ppos
	var lag := float(cfg.get("aim_lag_s", 0.0))
	if lag <= 0.0:
		apos = ppos
		return
	_hist_t.append(_clock)
	_hist_p.append(ppos)
	while _hist_t.size() > 2 and _clock - _hist_t[1] > HIST_KEEP_S:
		_hist_t.remove_at(0)
		_hist_p.remove_at(0)
	apos = _hist_p[0]
	for i in range(_hist_t.size() - 1, -1, -1):
		if _clock - _hist_t[i] >= lag:
			apos = _hist_p[i]
			break


# --- Aides partagées par la bibliothèque de motifs ------------------------------------------

func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


func face(d: Vector2) -> void:
	_face(d)


## Télégraphe n° i (0 = celui de l'Enemy, les suivants créés à la demande, libérés par clear).
func tele(i: int) -> EnemyTelegraph:
	if i == 0:
		return e.telegraph
	while _teles.size() < i:
		var tg := EnemyTelegraph.new()
		tg.name = &"MiniTele"
		e.add_child(tg) # passe seul sous la couche des télégraphes
		_teles.append(tg)
		_fx.append(tg)
	return _teles[i - 1]


## Alerte en anneau n° i (bande inner..radius, rouge réservé), réutilisée d'un motif à l'autre.
func ring_tele(i: int) -> RecluseFx:
	while _rings.size() <= i:
		_rings.append(make_fx(RecluseFx.Kind.RING_TELE, Color.WHITE, true))
	var f := _rings[i]
	f.visible = true
	return f


## Alerte d'anneau À BRÈCHES (bande rouge interrompue, SmelterFx en style alerte), réutilisée.
func gap_tele() -> SmelterFx:
	if not is_instance_valid(_gap_tele):
		_gap_tele = SmelterFx.make(SmelterFx.Kind.RING, Color.WHITE, 0)
		_gap_tele.name = &"MiniGapTele"
		_gap_tele.tele = true
		_gap_tele.set_meta(&"mini_tele", true)
		RecluseFx.add_to_tele_layer(_gap_tele, e.get_parent())
		_fx.append(_gap_tele)
	_gap_tele.visible = true
	return _gap_tele


func hide_teles() -> void:
	e.telegraph.hide_telegraph()
	for tg in _teles:
		if is_instance_valid(tg):
			tg.hide_telegraph()
	for n in _fx:
		if is_instance_valid(n) and n.has_meta(&"mini_tele"):
			(n as Node2D).visible = false


## Forme provisoire (RecluseFx) sous la couche des télégraphes ; `tele` = alerte réutilisable (masquée en fin de motif).
func make_fx(kind: RecluseFx.Kind, color: Color, is_tele := false) -> RecluseFx:
	var f := RecluseFx.make(kind, color, -1)
	if is_tele:
		f.set_meta(&"mini_tele", true)
	RecluseFx.add_to_tele_layer(f, e.get_parent())
	_fx.append(f)
	return f


func free_fx(n: Node) -> void:
	if is_instance_valid(n):
		n.queue_free()
	_fx.erase(n)


## Coup porté au joueur (dégâts Balance + statut + journal). Retourne vrai si le joueur est touché.
func hurt(coef: float, kind: StringName, status := "", extra := {}) -> bool:
	if player == null:
		return false
	e._hit_player(player, Balance.mini_attack_damage(e.damage, coef) * damage_out_mult())
	apply_player_status(status, e.damage * coef)
	var jam := float(cur.get("jam_s", 0.0))
	if jam > 0.0: # cri de la Nuée : brouille la minimap
		jam_minimap(jam)
	log_event(kind, true, extra)
	return true


## Statut transmis au joueur (coups, zones, projectiles) : burn | poison | slow (contrat Player.apply_status),
## frost = gel (ralentissement fort et court par Player.apply_slow, repli : slow).
func apply_player_status(status: String, hit: float) -> void:
	if status == "" or player == null:
		return
	if status == "frost":
		var fr: Dictionary = cfg.get("frost", {})
		if player.has_method(&"apply_slow"):
			player.apply_slow(float(fr.get("mult", FROST_MULT)), float(fr.get("s", FROST_S)), &"mini_frost")
			return
		status = "slow"
	if player.has_method(&"apply_status"):
		player.apply_status(StringName(status), {"hit": hit, "source": e})


## Projectile spécial (MiniHazards) reçu par le joueur.
func shot_hit(p: Node2D, dmg: float, status: String) -> void:
	player = p
	e._hit_player(p, dmg)
	apply_player_status(status, dmg)


func haz() -> MiniHazards:
	if not is_instance_valid(hazards) and not _cleared:
		hazards = MiniHazards.create(self)
	return hazards


## Brouille la minimap du HUD (Minimap.set_jammed, groupe « minimap ») pendant `s` secondes.
func jam_minimap(s: float) -> void:
	jam_count += 1
	if is_instance_valid(e) and e.is_inside_tree():
		e.get_tree().call_group(&"minimap", &"set_jammed", s)


# --- Eau ----------------------------------------------------------------------------------------------

## Vrai si `p` est dans l'eau : flaques posées par le mini (zones `water`) ou eau peu profonde de la carte (« , »).
func in_water(p: Vector2) -> bool:
	for z in _zones:
		if z.get("water", false) and MiniPatterns.zone_contains(z, p):
			return true
	return _map_shallow(p)


func _map_shallow(p: Vector2) -> bool:
	if not is_instance_valid(e) or not e.is_inside_tree():
		return false
	var sm := e.get_tree().get_first_node_in_group(&"stage_manager")
	var m: Node2D = sm.get(&"map") as Node2D if sm != null else null
	if m == null:
		return false
	var key := m.get_instance_id()
	if not _water_grid.has(key):
		_water_grid.clear()
		var g := AmbianceWater.grid_of(m)
		var has := false
		for row: String in (g.get("grid", PackedStringArray()) as PackedStringArray):
			if row.contains(","):
				has = true
				break
		_water_grid[key] = g if has else {}
	var wg: Dictionary = _water_grid[key]
	if wg.is_empty():
		return false
	var l := StageMap.frame_of(m).affine_inverse() * m.to_local(e.get_parent().to_global(p) if e.get_parent() is Node2D else p)
	var c := (l - (wg["origin"] as Vector2)) / float(wg["cell_px"])
	var grid: PackedStringArray = wg["grid"]
	var y := int(floor(c.y))
	var x := int(floor(c.x))
	if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].length():
		return false
	return grid[y][x] == ","


## Foudre (Events.lightning_struck, orage d'ambiance) : toute flaque conductrice du mini s'électrise ; le
## joueur qui s'y tient prend `shock_coef` et un ralentissement. Appelable directement (tests, autres sources).
func electrify(_intensity := 1.0, _pos := Vector2.ZERO) -> bool:
	var any := false
	var zapped := false
	for z in _zones:
		if not z.get("conduct", false):
			continue
		any = true
		z["shock"] = 0.6
		if is_instance_valid(z.get("node")) and z["node"] is MiniFx:
			(z["node"] as MiniFx).set_glow(1.0)
		if not zapped and player != null and MiniPatterns.zone_contains(z, ppos):
			zapped = true
			shocks += 1
			e._hit_player(player, Balance.mini_attack_damage(e.damage, float(z.get("shock_coef", 0.5))))
			apply_player_status("slow", e.damage)
	if any and is_instance_valid(e):
		e._sfx(&"enemy.shockwave.heavy", -2.0, true)
	return zapped


func _on_lightning(intensity: float, pos: Vector2) -> void:
	if not _cleared and is_instance_valid(e):
		electrify(intensity, pos)


func log_event(kind: StringName, hit: bool, extra := {}) -> void:
	var ev := {"pattern": StringName(cur.get("id", "")), "type": String(cur.get("type", "")), "kind": kind, "hit": hit,
		"frame": Engine.get_physics_frames(), "phase": phase, "armed": bool(cur.get("_armed", false)),
		"lag": vis.strike_lag() if vis.is_attacking() else 0.0, "anim": vis.current_anim(), "auto": bool(cur.get("auto", false))}
	ev.merge(extra, true)
	cur["_armed"] = false # seul le premier impact tombe sur la frame d'impact de l'anim
	events.append(ev)


## Déplace le joueur (attirance, poussée), en restant hors des murs : déplacement BALAYÉ (Player.push,
## move_and_collide) — une téléportation + resolve pouvait traverser un mur fin et éjecter hors carte.
func move_player(offset: Vector2) -> void:
	if player == null or offset == Vector2.ZERO:
		return
	if player.has_method(&"push"):
		player.push(offset, -1.0, 0.0)
		return
	var np := player.global_position + offset
	player.global_position = e.nav.resolve(np, PLAYER_R) if e.nav else np


func walkable(p: Vector2) -> Vector2:
	return e.nav.resolve(p, e.radius_px) if e.nav else p


func set_hidden(on: bool) -> void:
	_set_hidden(on)


func _set_hidden(on: bool) -> void:
	hidden = on
	vis.visible = not on
	if on and e._light != null:
		e._light.set_energy(0.15)
	elif not on:
		_light_phase(0.0)


func set_camo(on: bool) -> void:
	_set_camo(on)


func _set_camo(on: bool) -> void:
	if cur.get("camo", false) or not on:
		vis.modulate.a = 0.4 if on else 1.0


func set_stun(s: float) -> void:
	cur["_stun"] = s
	for ps: Dictionary in _passives:
		if String(ps.get("type", "")) == "flat_guard":
			_vuln_left = float(ps.get("off_after_crash_s", 4.0))


func light_boost(b: float) -> void:
	_light_phase(b)


# --- Invocations -------------------------------------------------------------------------------

func summon_at(pos: Vector2, tier: int, hp_frac: float, affix: StringName) -> Enemy:
	var d := e.director
	if d == null or not d.has_method(&"spawn_enemy") or summon_count() >= Balance.MINI_SUMMON_CAP:
		return null
	var aff: Array[StringName] = []
	if affix != &"":
		aff.append(affix)
	var m: Enemy = d.spawn_enemy(tier, walkable(pos), affix != &"", aff)
	if m == null:
		return null
	m.max_hp *= hp_frac
	m.hp = m.max_hp
	var spr := StringName(cur.get("summon_sprite", ""))
	if spr != &"" and m.visual != null and m.visual.has_method(&"use_frames"):
		# corps propre de l'invocation (louveteaux du Loup de brume : fauna.json summons) ; repli : monstre du biome
		var sf := EnemyVisual.summon_frames(spr)
		if sf == null: # mini hors de son biome (tests, mode sans fin) : invocation déclarée dans un autre biome
			sf = EnemyVisual.summon_frames(spr, StringName(cfg.get("biome", "")))
		if sf != null:
			var g: Dictionary = (cfg.get("summon_bodies", {}) as Dictionary).get(String(spr), {})
			m.visual.use_frames(sf, g)
			m.set_meta(&"summon_sprite", spr)
	elif m.has_meta(&"summon_sprite"):
		m.remove_meta(&"summon_sprite")
	_summons.append(m)
	summoned_total += 1
	return m


func add_egg(pos: Vector2, delay: float, tier: int, hp_frac: float) -> void:
	var f := make_fx(RecluseFx.Kind.DISC, Color(0.85, 0.9, 0.45, 0.85))
	f.global_position = pos
	f.width = 3.0
	f.set_param(0.3 * U)
	_eggs.append({"pos": pos, "left": delay, "tier": tier, "hp": hp_frac, "node": f})


func _update_eggs(delta: float) -> void:
	for i in range(_eggs.size() - 1, -1, -1):
		var g: Dictionary = _eggs[i]
		g["left"] = float(g["left"]) - delta
		if float(g["left"]) <= 0.0:
			free_fx(g["node"])
			summon_at(g["pos"], int(g["tier"]), float(g["hp"]), &"")
			_eggs.remove_at(i)


func egg_count() -> int:
	return _eggs.size()


# --- Zones au sol (traces) ------------------------------------------------------------------------

## Trace : shape circle (r) | line (angle, len, w) | ring (r, inner) ; dégâts par tick ou ralentissement seul.
func add_zone(z: Dictionary, zc: Dictionary) -> void:
	var col := color_of(zc.get("color"), Color(0.6, 0.6, 0.6))
	col.a = 0.12
	var f: Node2D
	var style := String(zc.get("style", "water" if zc.get("water", false) else ("salt" if zc.get("salt", false) else "")))
	if z.has("gaps") and style == "":
		style = "chain"
	match style:
		"water", "salt": # flaque d'eau (héron, crapaud) / croûte de sel (golem) : forme provisoire MiniFx
			var mf := _zone_fx(MiniFx.Kind.WATER if style == "water" else MiniFx.Kind.SALT, color_of(zc.get("color"), Color(0.33, 0.55, 0.7)))
			if String(z["shape"]) == "line":
				mf.length = float(z["len"])
				mf.width = float(z["w"])
				mf.rotation = float(z["angle"])
			else:
				mf.radius = float(z["r"])
			f = mf
		"chain": # anneau de chaînes à brèches (Archonte)
			var cf := _zone_fx(MiniFx.Kind.CHAIN, color_of(zc.get("color"), Color(0.56, 0.64, 0.69)))
			cf.color2 = color_of(_light_cfg().get("color"), Color(0.42, 0.88, 1.0))
			cf.radius = (float(z["r"]) + float(z["inner"])) * 0.5
			cf.width = maxf(float(z["r"]) - float(z["inner"]), 16.0)
			cf.gaps = z["gaps"]
			cf.gap_half = float(z["gap_half"])
			f = cf
	if f != null:
		f.global_position = z["pos"]
		z["node"] = f
		z["water"] = style == "water"
		z["conduct"] = bool(zc.get("conduct", style == "water"))
		z["shock_coef"] = float(zc.get("shock_coef", 0.5))
		z["slow_mult"] = float(zc.get("slow_mult", 0.0))
		z["left"] = float(zc.get("linger_s", 3.0))
		z["tick_s"] = float(zc.get("tick_s", 0.5))
		z["tick"] = float(z["tick_s"])
		z["coef"] = 0.0 if zc.get("slow_only", false) else float(zc.get("coef", 0.0))
		z["status"] = String(zc.get("status", "slow" if zc.get("slow_only", false) and z["slow_mult"] <= 0.0 else ""))
		_zones.append(z)
		return
	var rf: RecluseFx
	match String(z["shape"]):
		"line":
			rf = make_fx(RecluseFx.Kind.BEAM, col)
			rf.width = float(z["w"])
			rf.rotation = float(z["angle"])
			rf.set_param(float(z["len"]))
		"ring":
			rf = make_fx(RecluseFx.Kind.BAND, col)
			rf.width = 2.0
			rf.set_param(float(z["r"]), float(z["inner"]))
		_:
			rf = make_fx(RecluseFx.Kind.DISC, col)
			rf.width = 2.0
			rf.set_param(float(z["r"]))
	rf.color2 = col.lightened(0.4)
	f = rf
	f.global_position = z["pos"]
	z["node"] = f
	z["left"] = float(zc.get("linger_s", 3.0))
	z["tick_s"] = float(zc.get("tick_s", 0.5))
	z["tick"] = float(z["tick_s"])
	z["coef"] = 0.0 if zc.get("slow_only", false) else float(zc.get("coef", 0.0))
	z["status"] = String(zc.get("status", "slow" if zc.get("slow_only", false) else ""))
	if zc.get("light", false):
		var lr := float(zc.get("radius_u", 4.0))
		z["light"] = LightRig.attach_at(z["pos"], &"boss", {"color": col, "radius": lr / 3.0})
		z["light_r"] = lr * U
	_zones.append(z)


## Trace au sol dessinée (MiniFx) : sous les corps (z -2, comme les coulées du Fondeur), dans le monde éclairé.
func _zone_fx(kind: MiniFx.Kind, col: Color) -> MiniFx:
	var f := MiniFx.make(kind, col, -2 if kind != MiniFx.Kind.CHAIN else -1)
	var h := haz()
	if h != null:
		h.add_child(f)
	else:
		RecluseFx.add_to_tele_layer(f, e.get_parent())
	_fx.append(f)
	return f


func _update_zones(delta: float) -> void:
	for i in range(_zones.size() - 1, -1, -1):
		var z: Dictionary = _zones[i]
		z["left"] = float(z["left"]) - delta
		z["tick"] = float(z["tick"]) - delta
		if float(z["tick"]) <= 0.0:
			z["tick"] = float(z["tick_s"])
			if player != null and MiniPatterns.zone_contains(z, ppos):
				if float(z["coef"]) > 0.0:
					e._hit_player(player, Balance.mini_attack_damage(e.damage, float(z["coef"])) * damage_out_mult())
				apply_player_status(String(z["status"]), e.damage * maxf(float(z["coef"]), 0.3))
				if float(z.get("slow_mult", 0.0)) > 0.0 and player.has_method(&"apply_slow"): # eau, boue : ralenti paramétré
					player.apply_slow(float(z["slow_mult"]), float(z["tick_s"]) + 0.15, &"mini_zone")
		if z.has("shock"): # flaque électrisée : la lueur retombe
			z["shock"] = float(z["shock"]) - delta
			if is_instance_valid(z.get("node")) and z["node"] is MiniFx:
				(z["node"] as MiniFx).set_glow(clampf(float(z["shock"]) / 0.6, 0.0, 1.0))
			if float(z["shock"]) <= 0.0:
				z.erase("shock")
		if float(z["left"]) <= 0.0:
			free_fx(z["node"])
			if z.get("light") != null:
				(z["light"] as LightRig.Handle).release()
			_zones.remove_at(i)


## Point où le joueur prend le motif en cours (tests ; aussi utile au debug).
func harm_point() -> Vector2:
	return MiniPatterns.harm_point(self, cur) if not cur.is_empty() else ppos
