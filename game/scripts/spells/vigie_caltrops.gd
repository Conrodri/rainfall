class_name VigieCaltrops
extends Node2D
## Champ de pointes des Chausse-trapes de Vigie (variante, VigieKit) : zone persistante sans dégâts périodiques.
## À l'ENTRÉE d'un monstre (une fois par monstre) : coup VigieKit.CHAUSSE_ENTRY_COEF + Tension +25 % ; tant qu'un monstre
## reste dedans il est ralenti (50 %, boss 25 %, rafraîchi). Visuel : `caltrop_field.tres` (TOP, boucle + `end`, brief
## art/tools/night/_vigv.txt) ; sans asset : repli dessiné (cercle pointillé + pointes), placeholder.

const FADE_S := 0.4
const TICK_S := 0.1

var kit: Object = null
var spike: SpellData = null
var radius := 192.0
var life := 6.0
var entered := {} ## instance_id -> true (entrée déjà comptée)
var _t := 0.0
var _tick := 0.0
var _ending := false
var _vfx: AnimatedSprite2D = null
var _spikes: PackedVector2Array = PackedVector2Array()


func setup(new_kit: Object, spike_spell: SpellData, at: Vector2, radius_px: float, life_s: float) -> void:
	kit = new_kit
	spike = spike_spell
	global_position = at
	radius = radius_px
	life = life_s
	z_index = -1
	var path: String = VigieKit.CHAUSSE_FRAMES
	if ResourceLoader.exists(path):
		var frames := load(path) as SpriteFrames
		if frames != null and frames.has_animation(&"default") and frames.get_frame_count(&"default") > 0:
			_vfx = AnimatedSprite2D.new()
			_vfx.name = "Vfx"
			add_child(_vfx)
			EmissiveOverlay.apply(_vfx, frames)
			var k := radius / VigieKit.CHAUSSE_RADIUS_PX
			_vfx.scale = Vector2(k, k) # rig TOP : jamais pré-écrasé (comme la Grêle)
			_vfx.play(&"default")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 31.0 + at.y * 17.0)
	for i in 14: # pointes du repli, fixes pour la durée de vie
		var a := rng.randf() * TAU
		_spikes.append(Vector2.from_angle(a) * radius * sqrt(rng.randf()) * 0.92)
	ZoneOutline.attach(self, radius, VigieKit.ACCENT, life) # contour de la zone (ZoneOutline)
	_scan() # les monstres déjà dans le champ à la pose comptent comme une entrée


func is_ending() -> bool:
	return _ending


func entry_count() -> int:
	return entered.size()


func step(delta: float) -> void: ## public pour les tests sans boucle de rendu
	_t += delta
	if not _ending:
		_tick += delta
		while _tick >= TICK_S:
			_tick -= TICK_S
			_scan()
		if _t >= life:
			_ending = true
			if _vfx != null and _vfx.sprite_frames.has_animation(&"end"):
				_vfx.sprite_frames.set_animation_loop(&"end", false)
				_vfx.play(&"end")
	else:
		var k := clampf((_t - life) / FADE_S, 0.0, 1.0)
		modulate.a = 1.0 - k
		if k >= 1.0:
			queue_free()
	if _vfx == null:
		queue_redraw()


func _process(delta: float) -> void:
	step(delta)


func _scan() -> void:
	if kit == null or not is_instance_valid(kit):
		return
	var caster: SpellCaster = kit.get(&"player").spells if kit.get(&"player") != null else null
	if caster == null:
		return
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"take_damage"):
			continue
		if (e as Node2D).global_position.distance_to(global_position) > radius:
			continue
		var boss: bool = e.get(&"is_boss") == true
		if e.has_method(&"apply_status"):
			e.apply_status(&"slow", {"pct": VigieKit.CHAUSSE_BOSS_SLOW_PCT if boss else VigieKit.CHAUSSE_SLOW_PCT,
					"duration": VigieKit.CHAUSSE_SLOW_S})
		var id: int = e.get_instance_id()
		if entered.has(id):
			continue
		entered[id] = true
		caster.deal_damage(e, spike, {"source_pos": global_position})
		kit.on_caltrop_entry(e)


func _draw() -> void:
	if _vfx != null:
		return
	var a := clampf(1.0 - maxf(_t - life, 0.0) / FADE_S, 0.0, 1.0)
	var c := VigieKit.ACCENT
	draw_circle(Vector2.ZERO, radius, Color(0.12, 0.12, 0.13, 0.22 * a))
	for p in _spikes: # pointes de fer sombre, reflet rouge
		draw_line(p + Vector2(0, 5), p + Vector2(0, -5), Color(0.18, 0.18, 0.2, 0.95 * a), 2.0)
		draw_circle(p + Vector2(0, -5), 1.6, Color(c.r, c.g, c.b, 0.8 * a))
