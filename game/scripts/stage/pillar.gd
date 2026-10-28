class_name Pillar
extends Area2D
## Pilier d'étage. Petit : mini-boss + zone de combat, terminé à la mort du boss.
## Gros : verrouillé tant que les petits ne sont pas finis ; boss d'étage + zone de charge
## (Balance.PILLAR_CHARGE_S s, n'avance que joueur dedans) ; terminé quand chargé ET boss mort.
## Couche 7 (interactables), masque 2 (joueur).

signal finished(pillar: Pillar)

enum Kind { SMALL, BIG }

const STATE_LOCKED := &"locked"
const STATE_READY := &"ready"
const STATE_ACTIVE := &"active"
const STATE_DONE := &"done"

const SMALL_ZONE_RADIUS := 512.0 ## 8 u
const BIG_ZONE_RADIUS := 576.0 ## 9 u
const BOSS_OFFSET := Vector2(200.0, 0.0)

var kind: Kind = Kind.SMALL
var zone_id := 0
var boss_id: StringName = &"" ## id du boss d'étage (carte), transmis au Director
var state: StringName = STATE_READY
var charge := 0.0 ## secondes de charge (gros pilier)
var boss_dead := false
var player_in_zone := false
var _boss: Node2D = null
var _player_touching := false
var _zone_sent := false
var _light: LightRig.Handle = null ## lumière d'état (pillar_<état>)
var _charge_light: LightRig.Handle = null ## gros pilier : monte avec la charge
var _sprite: Sprite2D = null ## sprite Blender (props/pillar_<small|large>_<off|active|done>.png + _n/_e)
var _sprite_key := ""
var _anim_t := 0.0
var _zone_vis: PillarZone = null ## zone dessinée sur la couche des télégraphes (non éclairée)
## --- La Source (étage final, docs/Design_Etages.md §4) : paratonnerre-mère = gros pilier unique, sans
## petits piliers. L'interaction « Appeler la Source » fait apparaître le boss final (boss_id du plan,
## rain_sower) ; zone de charge sur tout l'anneau (rayon 22 u, pression ×2,33 du gros pilier) ; la charge
## continue mais le pilier n'est terminé qu'à la MORT du boss.
var final_boss := false
var final_hp_mult := 1.0
var _zone_radius_px := 0.0 ## > 0 : remplace BIG_ZONE_RADIUS / SMALL_ZONE_RADIUS


func _init() -> void:
	collision_layer = 1 << 6
	collision_mask = 1 << 1
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 56.0
	cs.shape = circle
	add_child(cs)


func _ready() -> void:
	add_to_group(&"pillars")
	add_to_group(&"interactable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Events.boss_killed.connect(_on_boss_killed)
	_light = LightRig.attach(self, StringName("pillar_%s" % state))
	_attach_zone_visual.call_deferred()
	_update_sprite()
	queue_redraw()


## La zone (cercle + arc de charge) vit sous AmbianceManager.telegraph_layer : ni éclairée, ni
## étalonnée. Sans AmbianceManager (tests), elle reste enfant du pilier.
func _attach_zone_visual() -> void:
	if not is_inside_tree() or _zone_vis != null:
		return
	_zone_vis = PillarZone.new()
	_zone_vis.pillar = self
	var layer := AmbianceManager.telegraph_layer(get_tree())
	if layer != null:
		layer.add_child(_zone_vis)
	else:
		add_child(_zone_vis)
	_zone_vis.sync()


func setup(new_kind: Kind, id: int, locked: bool = false) -> void:
	kind = new_kind
	zone_id = id
	_set_state(STATE_LOCKED if locked else STATE_READY)


## Gros pilier de la Source (après setup) : boss final, zone `zone_radius_px`, PV du boss × `hp_mult`.
func setup_final(zone_radius_px: float, hp_mult: float) -> void:
	final_boss = true
	final_hp_mult = maxf(hp_mult, 0.01)
	_zone_radius_px = zone_radius_px
	_sprite_key = "" # sprite du paratonnerre-mère s'il est livré
	_update_sprite()


func zone_radius() -> float:
	if _zone_radius_px > 0.0:
		return _zone_radius_px
	return SMALL_ZONE_RADIUS if kind == Kind.SMALL else BIG_ZONE_RADIUS


func charge_ratio() -> float:
	return clampf(charge / Balance.PILLAR_CHARGE_S, 0.0, 1.0)


func is_charged() -> bool:
	return charge >= Balance.PILLAR_CHARGE_S


func unlock() -> void:
	if state == STATE_LOCKED:
		_set_state(STATE_READY)


## Active le pilier (contact ou interact). Retourne true si l'activation a eu lieu.
func activate() -> bool:
	if state != STATE_READY:
		return false
	_set_state(STATE_ACTIVE)
	var d := _director()
	if d != null:
		var boss_kind := &"mini" if kind == Kind.SMALL else &"etage"
		if boss_id != &"":
			d.set_meta(&"next_boss_id", boss_id)
			if kind == Kind.SMALL: # mini-boss du plan de run (EnemyVisual.resolve_boss_id)
				d.set_meta(&"next_mini_id", boss_id)
		_boss = d.spawn_boss(boss_kind, global_position + BOSS_OFFSET)
		if d.has_meta(&"next_mini_id"):
			d.remove_meta(&"next_mini_id")
		if _boss != null and boss_id != &"":
			_boss.set_meta(&"boss_id", boss_id)
		if _boss != null and final_boss:
			_boss.set_meta(&"final_boss", true) # cerveau du boss final : phases, pas de second multiplicateur
		# PV × boss final (FINAL_BOSS_HP_MULT) × mode (BOSS_HP_MODE_MULT, gros pilier seulement : boss d'étage, raids,
		# final). Les cerveaux lisent max_hp au moment de s'en servir (seuils, soutiers, points faibles) : rescaler ici suffit.
		var hp_mult := Balance.boss_hp_mode_mult(boss_kind, RunState.mode) * (final_hp_mult if final_boss else 1.0)
		if _boss != null and hp_mult != 1.0 and &"max_hp" in _boss:
			_boss.set(&"max_hp", float(_boss.get(&"max_hp")) * hp_mult)
			_boss.set(&"hp", float(_boss.get(&"max_hp")))
	else:
		push_warning("Pillar : aucun Director (groupe `director`), pas de boss.")
	_update_zone(true)
	queue_redraw()
	return true


func _physics_process(delta: float) -> void:
	tick(delta)


## Avance la logique d'un pas (appelé chaque frame physique ; public pour les tests).
func tick(delta: float) -> void:
	if state != STATE_ACTIVE:
		return
	_update_zone(false)
	if kind == Kind.BIG and player_in_zone and not is_charged():
		charge = minf(charge + delta, Balance.PILLAR_CHARGE_S)
		Events.pillar_charge_progress.emit(self, charge_ratio())
		_update_charge_light()
		queue_redraw()
	_check_done()


func _update_charge_light() -> void:
	if _charge_light == null:
		return
	var c := charge_ratio()
	_charge_light.set_radius_mult(lerpf(1.0, 4.5, c))
	_charge_light.set_energy(lerpf(1.0, 2.0, c))
	_charge_light.set_flicker_override(-1.0 if player_in_zone else 0.3, 2.0)


func _update_zone(force: bool) -> void:
	var inside := _player_inside()
	if inside != player_in_zone or force:
		player_in_zone = inside
		_send_zone(inside)
		_update_charge_light()
		queue_redraw()


func _player_inside() -> bool:
	var p := get_tree().get_first_node_in_group(&"player") as Node2D
	return p != null and p.global_position.distance_to(global_position) <= zone_radius()


func _send_zone(active: bool) -> void:
	var d := _director()
	if d != null:
		d.set_zone(zone_id, global_position, zone_radius(), active, &"mini" if kind == Kind.SMALL else &"etage")
		_zone_sent = active


func _on_boss_killed(boss: Node2D, _is_floor_boss: bool) -> void:
	if state == STATE_ACTIVE and boss == _boss:
		boss_dead = true
		_check_done()


func _check_done() -> void:
	if state != STATE_ACTIVE or not boss_dead:
		return
	if kind == Kind.BIG and not is_charged() and not final_boss:
		return
	_set_state(STATE_DONE)
	if _zone_sent:
		_send_zone(false)
	player_in_zone = false
	queue_redraw()
	finished.emit(self)


func _set_state(new_state: StringName) -> void:
	var old := state
	state = new_state
	_apply_state_light(old)
	_update_sprite()
	Events.pillar_state_changed.emit(self, state)
	queue_redraw()


## Lumières (Direction §4.6) : activation en rampe, charge qui monte (gros pilier), éclair à la fin.
func _apply_state_light(old: StringName) -> void:
	if _light == null:
		return
	if state == STATE_ACTIVE and old != STATE_ACTIVE and is_inside_tree():
		_light.set_preset(&"pillar_activation")
		_light.set_radius_mult(1.0 if kind == Kind.SMALL else 9.0 / 7.0)
		_light.ramp(0.0, 1.0 if kind == Kind.SMALL else 9.0 / 7.0, 1.6, 0.7 / 1.6, 0.6 if kind == Kind.SMALL else 0.8)
		get_tree().create_timer(0.9, false).timeout.connect(func() -> void:
			if state == STATE_ACTIVE and _light != null:
				_light.set_preset(&"pillar_active")
				_light.set_radius_mult(1.0)
				_light.set_energy(1.0))
		if kind == Kind.BIG and _charge_light == null:
			_charge_light = LightRig.attach(self, &"pillar_charge")
			_update_charge_light()
		return
	if state == STATE_ACTIVE:
		return
	_light.set_preset(StringName("pillar_%s" % state))
	_light.set_radius_mult(1.0)
	_light.set_energy(1.0)
	if state == STATE_DONE:
		if _charge_light != null:
			_charge_light.release()
			_charge_light = null
		if old == STATE_ACTIVE and is_inside_tree():
			var am := AmbianceManager.find(get_tree())
			if am != null:
				am.strike_lightning(global_position, 0.5, true) # pilier terminé : 0,5 + tonnerre immédiat
		_light.release() # terminé : pilier éteint (lisibilité : seuls les piliers activables brillent)
		_light = null


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_touching = true
	queue_redraw()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group(&"player"):
		_player_touching = false


func _director() -> Node:
	return get_tree().get_first_node_in_group(&"director") if is_inside_tree() else null


func _exit_tree() -> void:
	if _zone_sent:
		_send_zone(false)
	if _zone_vis != null and is_instance_valid(_zone_vis) and _zone_vis.get_parent() != self:
		_zone_vis.queue_free()
	_zone_vis = null


# --- Sauvegarde
func to_dict() -> Dictionary:
	return {
		"kind": int(kind), "zone_id": zone_id, "state": String(state),
		"charge": charge, "boss_dead": boss_dead,
		"x": global_position.x, "y": global_position.y,
	}


## Restaure l'état. Un pilier actif sans boss vivant retourne à « ready » (le boss
## n'est pas sauvegardé) pour ne jamais rester bloqué ; la charge est conservée.
func from_dict(d: Dictionary) -> void:
	kind = int(d.get("kind", 0)) as Kind
	zone_id = int(d.get("zone_id", 0))
	charge = float(d.get("charge", 0.0))
	boss_dead = bool(d.get("boss_dead", false))
	var s := StringName(d.get("state", "ready"))
	if s == STATE_ACTIVE and not boss_dead:
		s = STATE_READY
	_boss = null
	_set_state(s)


# --- Visuel : sprite rendu dans Blender (planche horizontale de frames carrées pour « active »)
const SPRITE_PATH := "res://assets/sprites/props/pillar_%s_%s.png"
const SPRITE_FPS := 10.0
const SPRITE_BASE_Y := 0.82 ## socle du pilier à 82 % de la hauteur de frame : posé sur sa position
const MOTHER_ROD_PATH := "res://assets/sprites/props/source/mother_rod_%s.png" ## off | active | done (+ _n, _e)
const MOTHER_ROD_FALLBACK_SCALE := 1.6 ## repli : gros pilier agrandi (le paratonnerre-mère domine l'arène)
const MOTHER_ROD_FALLBACK_TINT := Color(0.78, 0.92, 1.0) ## repli : vers le cristal blanc-cyan de la Source


func _update_sprite() -> void:
	# clarté (retour joueur) : allumé quand on peut l'activer, éteint une fois terminé ou verrouillé
	var st := "off"
	match state:
		STATE_READY: st = "done" # planche statique illuminée (_e) : « active-moi »
		STATE_ACTIVE: st = "active"
	var key := SPRITE_PATH % ["small" if kind == Kind.SMALL else "large", st]
	var rod := final_boss and ResourceLoader.exists(MOTHER_ROD_PATH % st)
	if rod: # paratonnerre-mère (lot C5, requests_floor45.md) ; absent : gros pilier teinté cristal
		key = MOTHER_ROD_PATH % st
	if key == _sprite_key or not is_inside_tree():
		return
	_sprite_key = key
	if not ResourceLoader.exists(key):
		return
	if _sprite != null:
		_sprite.queue_free() # l'enfant d'émission (_e) dépend de la texture : on repart de zéro
	_sprite = Sprite2D.new()
	_sprite.name = &"Sprite"
	var tex := load(key) as Texture2D
	_sprite.texture = tex
	var h := float(tex.get_height())
	_sprite.hframes = maxi(int(round(tex.get_width() / h)), 1)
	_sprite.scale = Iso.UNSQUASH # billboard (docs/Design_Isometrique.md §1.6) : sprite ancien, 64 px/u
	_sprite.offset = Vector2(0.0, -h * (SPRITE_BASE_Y - 0.5))
	# verrouillé : socle éteint et assombri ; prêt : socle éteint, pleine lumière
	_sprite.modulate = Color(0.6, 0.6, 0.65) if state == STATE_LOCKED else Color.WHITE
	if final_boss and not rod:
		_sprite.scale *= MOTHER_ROD_FALLBACK_SCALE
		_sprite.self_modulate = MOTHER_ROD_FALLBACK_TINT
	elif rod:
		_sprite.scale = Iso.UNSQUASH * (64.0 / Iso.RENDER_PX_PER_U) # rendu iso 90,51 px/u
	add_child(_sprite)
	NormalMaps.apply_to_sprite(_sprite)


func _process(delta: float) -> void:
	if _sprite != null and _sprite.hframes > 1:
		_anim_t += delta
		_sprite.frame = int(_anim_t * SPRITE_FPS) % _sprite.hframes


func _draw() -> void:
	if _zone_vis != null and is_instance_valid(_zone_vis):
		_zone_vis.sync()


## Zone de combat / de charge (placeholder dessiné, couche des télégraphes : unshaded, light_mask 0).
class PillarZone extends Node2D:
	static var _unshaded: CanvasItemMaterial = null
	const ZONE_FADE_PX := 96.0 ## largeur du dégradé intérieur le long du bord
	const ZONE_FADE_STEPS := 6
	var pillar: Pillar = null

	func _init() -> void:
		name = &"PillarZone"
		light_mask = 0
		z_index = -2
		if _unshaded == null:
			_unshaded = CanvasItemMaterial.new()
			_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = _unshaded

	func sync() -> void:
		if pillar == null or not is_instance_valid(pillar) or not pillar.is_inside_tree():
			return
		global_position = pillar.global_position
		visible = pillar.state == Pillar.STATE_ACTIVE
		queue_redraw()

	func _draw() -> void:
		if pillar == null or not is_instance_valid(pillar) or pillar.state != Pillar.STATE_ACTIVE:
			return
		var zr := pillar.zone_radius()
		# voile léger (retour joueur : l'aplat 12-25 % masquait le sol) + dégradé doux vers le bord
		var k := 1.6 if pillar.player_in_zone else 1.0
		draw_circle(Vector2.ZERO, zr, Color(0.81, 0.91, 1.0, 0.018 * k))
		for i in ZONE_FADE_STEPS:
			var w := ZONE_FADE_PX / ZONE_FADE_STEPS
			var a := 0.03 * k * (1.0 - float(i) / ZONE_FADE_STEPS)
			draw_arc(Vector2.ZERO, zr - w * (i + 0.5), 0.0, TAU, 96, Color(0.81, 0.91, 1.0, a), w)
		draw_arc(Vector2.ZERO, zr, 0.0, TAU, 96, Color(0.81, 0.91, 1.0, 0.55), 3.0)
		if pillar.kind == Pillar.Kind.BIG:
			draw_arc(Vector2.ZERO, zr - 14.0, -PI * 0.5, -PI * 0.5 + TAU * pillar.charge_ratio(), 96, Color(0.4, 0.9, 1.0, 0.85), 10.0)


# --- Interaction (contrat « Interaction mobile »)
func can_interact() -> bool:
	return state == STATE_READY and _player_touching


func interact_label() -> String:
	if state == STATE_LOCKED:
		return "Verrouillé"
	return "Appeler la Source" if final_boss else "Activer le pilier"


## Appelé par le répartiteur unique du HUD (le pilier ne lit plus l'entrée).
func interact() -> bool:
	if not can_interact():
		return false
	return activate()


## Invite : prêt = activable ; verrouillé = grisée, avec la raison écrite (« petits piliers 1/2 »).
func interact_state() -> Dictionary:
	if state == STATE_LOCKED and _player_touching:
		var done := 0
		var total := 0
		if is_inside_tree():
			for p in get_tree().get_nodes_in_group(&"pillars"):
				if p is Pillar and (p as Pillar).kind == Kind.SMALL:
					total += 1
					if (p as Pillar).state == STATE_DONE:
						done += 1
		var why := "Verrouillé"
		if total > 0:
			why = "Verrouillé — petits piliers %d/%d" % [done, total]
		return {"visible": true, "enabled": false, "label": why, "hold_s": 0.0}
	return {"visible": can_interact(), "enabled": true, "label": interact_label(), "hold_s": 0.0}


func interact_priority() -> int:
	return 1
