class_name EpreuveVein
extends Epreuve
## Veine (docs/Design_Epreuves.md §3.4, Gouffre et Cryptes) : à la source (EpreuveVeinSource, « Suivre la veine »), un
## DISQUE de lumière de rayon Balance.VEIN_RADIUS_U glisse à Balance.VEIN_SPEED_U le long de `vein_path` (boucle continue si `closed`,
## aller-retour sinon). La charge (Balance.VEIN_CHARGE_S) n'avance que si un joueur vivant est DANS le disque (coop : au prorata
## des vivants dedans, plancher Balance.COOP_CHARGE_FLOOR) et ne retombe jamais. Toutes les Balance.VEIN_GEYSER_EVERY_S, un geyser
## est annoncé sous un joueur du disque (tour de rôle ; sans joueur, 3 u devant le centre), décalé de Balance.VEIN_GEYSER_AHEAD_U
## dans le sens d'avance (télégraphe >= 0,8 s, rester immobile est puni) : un joueur dedans à
## l'éruption reçoit un coup de mini-boss (une fois par geyser et par joueur) et la note « parfait » est perdue. Charge
## pleine : le disque s'arrête, le mini-boss apparaît (base Epreuve : BOSS_OFFSET du centre, donc dans le disque).
## `global_position` = centre du disque (la zone de monstres et la flèche hors écran le suivent) ; la source est un enfant
## recalé pour rester fixe. Visuel provisoire : disque et anneau sur l'EpreuveOverlay, source en losange.

# Réglages : Balance.VEIN_* (docs/Design_Epreuves.md §8).
const VEIN_GEYSER_ERUPT_S := 0.4 ## durée de l'éruption (pas dans le tableau §8 : constante de présentation)

const TICK_EVERY_S := 5.0 ## une pulsation sonore (`vein_tick`) toutes les 5 s de charge
const COL_FOREST := Color(0.76, 0.48, 1.0) ## améthyste #C27BFF (Gouffre)
const COL_CRYPTS := Color(0.75, 0.96, 1.0) ## cristal #BFF4FF (Cryptes)

const SECRET_RING_PX := 40.0 ## anneau de la source avant le lancement
const GEY_NONE := 0
const GEY_TELEGRAPH := 1
const GEY_ERUPT := 2

var path := PackedVector2Array() ## sommets du tracé, repère local de la carte (sans le segment de fermeture)
var closed := true ## boucle continue (vrai) ou aller-retour (faux)
var length := 0.0 ## longueur parcourue d'un bout à l'autre (px) ; boucle : fermeture comprise
var dist_along := 0.0 ## position du disque sur le tracé (px)
var dir := 1 ## +1 / -1 (aller-retour seulement)
var vein_charge := 0.0 ## s de charge accumulées (jamais décroissante)
var hits := 0 ## geysers reçus
var out_s := 0.0 ## cumul des secondes passées sans joueur dans le disque (mesure)
var pulses := 0 ## geysers émis (mesure)
var vein_skin: StringName = &"" ## &"foret" | &"cryptes" ; vide : lit la méta `biome` si présente, sinon Gouffre
var source: EpreuveVeinSource = null
var _pts := PackedVector2Array() ## sommets + fermeture éventuelle
var _seg_len := PackedFloat32Array()
var _geyser_left := Balance.VEIN_GEYSER_EVERY_S ## s avant le prochain geyser
var _gey_phase := GEY_NONE
var _gey_t := 0.0 ## s restantes de la phase courante
var _gey_pos := Vector2.ZERO ## repère local de la carte
var _gey_hit_ids: Array = [] ## joueurs déjà touchés par le geyser courant
var _inside := false ## au moins un joueur dans le disque (dernier pas)
var _gey_turn := 0 ## tour de rôle entre les joueurs du disque


## Veine sur le tracé `pts` (au moins 2 points, repère local de la carte). `is_closed` : boucle continue.
static func make(pts: PackedVector2Array, is_closed: bool = true) -> EpreuveVein:
	var e := EpreuveVein.new()
	e.set_path(pts, is_closed)
	var s := EpreuveVeinSource.new()
	s.epreuve = e
	e.source = s
	e.add_child(s)
	s.position = Vector2.ZERO
	return e


## Longueur (u) d'un tracé, fermeture comprise si `is_closed` : sert à la validation (Balance.VEIN_LOOP_MIN_U..VEIN_LOOP_MAX_U).
static func path_length_u(pts: PackedVector2Array, is_closed: bool) -> float:
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	if is_closed and pts.size() > 2:
		total += pts[pts.size() - 1].distance_to(pts[0])
	return total / Balance.UNIT_PX


static func length_in_range(pts: PackedVector2Array, is_closed: bool) -> bool:
	var l := path_length_u(pts, is_closed)
	return l >= Balance.VEIN_LOOP_MIN_U and l <= Balance.VEIN_LOOP_MAX_U


func _init() -> void:
	verb = &"veine"
	uses_sprite = false


func set_path(pts: PackedVector2Array, is_closed: bool = true) -> void:
	path = pts
	closed = is_closed and pts.size() > 2
	_pts = pts.duplicate()
	if closed:
		_pts.append(pts[0])
	_seg_len.clear()
	length = 0.0
	for i in range(_pts.size() - 1):
		var l := _pts[i].distance_to(_pts[i + 1])
		_seg_len.append(l)
		length += l
	dist_along = 0.0
	dir = 1
	if not _pts.is_empty():
		position = _pts[0]


func _ready() -> void:
	super._ready()
	if source != null:
		source.tint = _tint()
		source.skin = _skin_name()
		source.refresh()


func _tint() -> Color:
	var s := vein_skin
	if s == &"":
		var b: Variant = get(&"biome") # champ de la base généralisée (E0), absent du prototype
		if b != null:
			s = StringName(String(b))
	return COL_CRYPTS if s == &"cryptes" or s == &"crypts" else COL_FOREST


func _skin_name() -> String:
	return "crypts" if _tint() == COL_CRYPTS else "fog_forest"


func zone_radius() -> float:
	return Balance.VEIN_ZONE_RADIUS_U * Balance.UNIT_PX


func disc_radius() -> float:
	return Balance.VEIN_RADIUS_U * Balance.UNIT_PX


## Le pilier lui-même n'est pas interactif (il suit le disque) : c'est la source qui lance l'épreuve.
func can_interact() -> bool:
	return false


func progress() -> float:
	return clampf(vein_charge / Balance.VEIN_CHARGE_S, 0.0, 1.0)


# --- Géométrie du tracé
## Position (repère local de la carte) à la distance `s` (px) le long du tracé.
func point_at(s: float) -> Vector2:
	if _pts.is_empty():
		return position
	s = clampf(s, 0.0, length)
	for i in _seg_len.size():
		if s <= _seg_len[i] or i == _seg_len.size() - 1:
			var t := clampf(s / _seg_len[i], 0.0, 1.0) if _seg_len[i] > 0.0 else 0.0
			return _pts[i].lerp(_pts[i + 1], t)
		s -= _seg_len[i]
	return _pts[_pts.size() - 1]


## Position `px` pixels devant le disque, dans son sens de marche (boucle : on enroule ; aller-retour : on rebondit).
func point_ahead(px: float) -> Vector2:
	if length <= 0.0:
		return position
	var s := dist_along + float(dir) * px
	if closed:
		s = fposmod(s, length)
	else:
		s = fposmod(s, 2.0 * length)
		if s > length:
			s = 2.0 * length - s
	return point_at(s)


## Fait glisser le disque de `px` pixels (tests, mode test) ; ne fait rien hors épreuve.
func advance(px: float) -> void:
	if length <= 0.0 or not is_running():
		return
	if closed:
		dist_along = fposmod(dist_along + px, length)
	else:
		var s := dist_along + float(dir) * px
		while s > length or s < 0.0: # rebond (un pas ne dépasse jamais la longueur, mais par sécurité)
			if s > length:
				s = 2.0 * length - s
				dir = -1
			else:
				s = -s
				dir = 1
		dist_along = s
	_place()


func _place() -> void:
	position = point_at(dist_along)
	if source != null and not path.is_empty():
		source.position = path[0] - position # la source reste fixe à path[0]


# --- Déroulé
func _begin() -> void:
	vein_charge = 0.0
	hits = 0
	out_s = 0.0
	pulses = 0
	dist_along = 0.0
	dir = 1
	_geyser_left = Balance.VEIN_GEYSER_EVERY_S
	_gey_phase = GEY_NONE
	_gey_hit_ids.clear()
	_inside = false
	_gey_turn = 0
	_place()
	if source != null:
		source.refresh()


func _run(delta: float) -> void:
	advance(Balance.VEIN_SPEED_U * Balance.UNIT_PX * delta)
	_step_charge(delta)
	_step_geyser(delta)
	if vein_charge >= Balance.VEIN_CHARGE_S and is_running():
		_resolve()


## Part de la vitesse de charge (0..1) : 1 solo dans le disque ; coop : vivants dedans / vivants (plancher COOP_CHARGE_FLOOR).
func vein_rate() -> float:
	if not is_inside_tree():
		return 0.0
	var alive := Players.alive_count()
	var inside := CoopRules.alive_within(global_position, disc_radius())
	if inside <= 0:
		return 0.0
	if alive <= 1:
		return 1.0
	return maxf(float(inside) / float(alive), Balance.COOP_CHARGE_FLOOR)


func _step_charge(delta: float) -> void:
	var rate := vein_rate()
	_inside = rate > 0.0
	if _inside:
		var before := vein_charge
		vein_charge = minf(vein_charge + delta * rate, Balance.VEIN_CHARGE_S)
		if int(vein_charge / TICK_EVERY_S) > int(before / TICK_EVERY_S) and vein_charge < Balance.VEIN_CHARGE_S:
			Audio.play(&"vein_tick", global_position) # lot EP-G : une pulsation toutes les 5 s de charge
	else:
		out_s += delta


func _step_geyser(delta: float) -> void:
	match _gey_phase:
		GEY_NONE:
			_geyser_left -= delta
			if _geyser_left <= 0.0:
				_gey_pos = _pick_geyser_pos()
				_gey_phase = GEY_TELEGRAPH
				_gey_t = Balance.VEIN_GEYSER_TELEGRAPH_S
				Audio.play(&"vein_geyser_warn", _geyser_global())
		GEY_TELEGRAPH:
			_gey_t -= delta
			if _gey_t <= 0.0:
				_gey_phase = GEY_ERUPT
				_gey_t = VEIN_GEYSER_ERUPT_S
				_gey_hit_ids.clear()
				pulses += 1
				Audio.play(&"vein_geyser", _geyser_global())
				_erupt_hit()
		GEY_ERUPT:
			_erupt_hit()
			_gey_t -= delta
			if _gey_t <= 0.0:
				_gey_phase = GEY_NONE
				_geyser_left = Balance.VEIN_GEYSER_EVERY_S


## Point d'impact du prochain geyser (repère local de la carte). Avec Balance.VEIN_GEYSER_ON_PLAYER : sous un joueur vivant
## du disque, à tour de rôle, décalé de Balance.VEIN_GEYSER_AHEAD_U dans le sens d'avance du disque (rester immobile est
## puni, s'écarter pendant le télégraphe est récompensé). Un joueur qui a un coffre ouvert n'est jamais visé. Sans joueur
## éligible : devant le centre, comme avant.
func _pick_geyser_pos() -> Vector2:
	var fallback := point_ahead(Balance.VEIN_GEYSER_FALLBACK_AHEAD_U * Balance.UNIT_PX)
	if not Balance.VEIN_GEYSER_ON_PLAYER or not is_inside_tree():
		return fallback
	var m := get_parent() as Node2D
	if m == null:
		return fallback
	var targets: Array[Node2D] = []
	var rad := disc_radius()
	for pl: Node2D in Players.alive():
		if pl.global_position.distance_to(global_position) <= rad and not _has_open_chest(pl):
			targets.append(pl)
	if targets.is_empty():
		return fallback
	var tgt := targets[_gey_turn % targets.size()]
	_gey_turn += 1
	var ahead := point_ahead(Balance.UNIT_PX) - position
	var off := ahead.normalized() * Balance.VEIN_GEYSER_AHEAD_U * Balance.UNIT_PX if ahead.length() > 0.001 else Vector2.ZERO
	return m.to_local(tgt.global_position) + off


## Vrai si `pl` a une session de coffre ouverte (ChestUI de son PlayerState) : en coop l'écran ne met pas le jeu en pause,
## le joueur ne doit pas se faire frapper par un geyser pendant qu'il choisit.
func _has_open_chest(pl: Node2D) -> bool:
	if not pl.has_method(&"player_state"):
		return false
	var st: Variant = pl.call(&"player_state")
	var hosts: Array[Node] = [get_tree().root]
	if get_tree().current_scene != null:
		hosts.append(get_tree().current_scene)
	for h in hosts:
		for c in h.get_children():
			if c is ChestUI and not c.is_queued_for_deletion() and c.session != null and c.session.state == st:
				return true
	return false


## Position monde du geyser courant (`_gey_pos` est dans le repère de la carte) ; repli sur l'épreuve sans parent.
func _geyser_global() -> Vector2:
	var m := get_parent() as Node2D
	return m.to_global(_gey_pos) if m != null and is_inside_tree() else global_position


## Un coup par joueur et par geyser : les joueurs vivants dans le cercle de l'éruption.
func _erupt_hit() -> void:
	if not is_inside_tree():
		return
	var m := get_parent() as Node2D
	var gp: Vector2 = m.to_global(_gey_pos) if m != null else _gey_pos
	var r := Balance.VEIN_GEYSER_RADIUS_U * Balance.UNIT_PX
	for pl: Node2D in Players.alive().duplicate():
		if _gey_hit_ids.has(pl.get_instance_id()):
			continue
		if pl.global_position.distance_to(gp) <= r:
			_gey_hit_ids.append(pl.get_instance_id())
			hits += 1
			clean = false
			if pl.has_method(&"take_damage"):
				pl.call(&"take_damage", geyser_damage(), self)


## Coup d'un geyser : coup de mini-boss de coef Balance.VEIN_GEYSER_COEF.
func geyser_damage() -> float:
	return Balance.vein_geyser_damage(RunState.difficulty())


func geyser_phase() -> int:
	return _gey_phase


func geyser_pos() -> Vector2:
	return _gey_pos


func geyser_left() -> float:
	return _geyser_left


func _on_resolved() -> void:
	_gey_phase = GEY_NONE
	_inside = false
	if source != null:
		source.refresh()


# --- Sauvegarde
func _extra_dict() -> Dictionary:
	return {"dist": dist_along, "dir": dir, "charge": vein_charge, "hits": hits, "geyser_left": _geyser_left, "out_s": out_s, "pulses": pulses}


func _extra_restore(d: Dictionary) -> void:
	dist_along = clampf(float(d.get("dist", 0.0)), 0.0, length)
	dir = -1 if int(d.get("dir", 1)) < 0 else 1
	vein_charge = clampf(float(d.get("charge", 0.0)), 0.0, Balance.VEIN_CHARGE_S)
	hits = int(d.get("hits", 0))
	out_s = float(d.get("out_s", 0.0))
	pulses = int(d.get("pulses", 0))
	_geyser_left = float(d.get("geyser_left", Balance.VEIN_GEYSER_EVERY_S))
	_gey_phase = GEY_NONE
	_gey_hit_ids.clear()
	_place()
	if source != null:
		source.refresh()


# --- Dessin provisoire
func draw_overlay(c: Node2D) -> void:
	var m := get_parent() as Node2D
	if m == null or _pts.size() < 2 or state == Pillar.STATE_DONE:
		return
	var col := _tint()
	var pl := PackedVector2Array()
	for p in _pts:
		pl.append(c.to_local(m.to_global(p)))
	var trail_col := Color(col.r, col.g, col.b, 0.55)
	for i in pl.size() - 1: # lot EP-II : tuile de trajet Codex, repli polyligne
		if not EpreuveSprites.draw_strip(c, "ep2_path_tile.png", pl[i], pl[i + 1], 30.0, trail_col):
			c.draw_polyline(pl, Color(col.r, col.g, col.b, 0.28), 4.0)
			break
	var active := is_running()
	if state == Pillar.STATE_READY:
		var ready_col := Color(col.r, col.g, col.b, 0.5)
		if not EpreuveSprites.draw_ring(c, "ring_zone.png", c.to_local(m.to_global(path[0])), SECRET_RING_PX, ready_col):
			c.draw_arc(c.to_local(m.to_global(path[0])), SECRET_RING_PX, 0.0, TAU, 32, ready_col, 3.0)
		return
	var rad := disc_radius()
	var disc := EpreuveSprites.tex(EpreuveSprites.VFX_DIR, "vein_disc_%s.png" % _skin_name())
	if disc != null: # lot EP-D : planche 4 frames de pulsation, anneau à ~96 % du bord
		var fw := float(disc.get_height())
		var fr := int(Time.get_ticks_msec() / 160) % maxi(int(disc.get_width() / fw), 1)
		var half := rad / 0.96
		c.draw_texture_rect_region(disc, Rect2(-half, -half, half * 2.0, half * 2.0), Rect2(fr * fw, 0.0, fw, fw), Color(1, 1, 1, 1.0 if _inside else 0.7))
	else:
		var glow := 0.30 if _inside and active else 0.16
		c.draw_circle(Vector2.ZERO, rad, Color(col.r, col.g, col.b, glow))
		c.draw_arc(Vector2.ZERO, rad, 0.0, TAU, 96, Color(col.r, col.g, col.b, 0.85 if _inside else 0.5), 6.0)
	if not active:
		return
	# charge : arc plein autour du disque
	if EpreuveSprites.draw_pie(c, Vector2.ZERO, rad + 18.0, 1.0, Color(0.1, 0.1, 0.1, 0.45)): # lot EP-II : rail sombre + secteur Codex
		EpreuveSprites.draw_pie(c, Vector2.ZERO, rad + 18.0, progress(), Color(1.0, 0.9, 0.5, 0.95))
	else:
		c.draw_arc(Vector2.ZERO, rad + 14.0, -PI * 0.5, -PI * 0.5 + TAU * progress(), 64, Color(1.0, 0.9, 0.5, 0.9), 6.0)
	# geyser : télégraphe rouge qui se renforce, puis flash blanc
	if _gey_phase != GEY_NONE:
		var gp := c.to_local(m.to_global(_gey_pos))
		var gr := Balance.VEIN_GEYSER_RADIUS_U * Balance.UNIT_PX
		if _gey_phase == GEY_TELEGRAPH:
			var k := 1.0 - clampf(_gey_t / Balance.VEIN_GEYSER_TELEGRAPH_S, 0.0, 1.0)
			if not EpreuveSprites.draw_ground(c, "ep2_geyser_tele.png", gp, gr * 2.0 / 0.96, Color(1.0, 0.3, 0.2, 0.35 + 0.6 * k)): # lot EP-II
				c.draw_circle(gp, gr, Color(1.0, 0.25, 0.2, 0.06 + 0.14 * k))
				c.draw_arc(gp, gr, 0.0, TAU, 48, Color(1.0, 0.3, 0.2, 0.35 + 0.55 * k), 4.0)
		else:
			var gtex := EpreuveSprites.tex(EpreuveSprites.VFX_DIR, "vein_geyser_%s.png" % _skin_name())
			if gtex != null: # lot EP-D : 6 frames 128x192 sur la durée de l'éruption
				var gw := float(gtex.get_width()) / 6.0
				var gh := float(gtex.get_height())
				var gf := clampi(int(Time.get_ticks_msec() / 70) % 6, 0, 5)
				if not EpreuveSprites.draw_ground(c, "ep2_geyser_flash.png", gp, gr * 2.4, Color(1.0, 1.0, 1.0, 0.8)):
					c.draw_circle(gp, gr, Color(1.0, 1.0, 1.0, 0.25))
				c.draw_set_transform(gp, 0.0, Iso.UNSQUASH * (gr * 2.0 / gw))
				c.draw_texture_rect_region(gtex, Rect2(-gw * 0.5, -gh * 0.85, gw, gh), Rect2(gf * gw, 0.0, gw, gh))
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				c.draw_circle(gp, gr, Color(1.0, 1.0, 1.0, 0.75))

