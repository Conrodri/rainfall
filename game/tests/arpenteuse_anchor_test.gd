extends Node
## Ancrage de la chaîne au sol (retour joueur 23/10/2026 : « la chaîne ne se bloque pas au sol, angles bizarres »).
## Parcours en cercle puis en zigzag à vitesse de marche : chaque point posé reste fixe (seule la queue glisse),
## l'échantillonnage est régulier (pas <= STEP_U), l'angle entre deux segments du rendu reste doux, et un
## trou de frame (saut de 1,5 u d'un coup) n'ouvre pas un segment géant.
## godot --headless --path game res://tests/arpenteuse_anchor_test.tscn  (sortie : RESULT: OK)

const U := 64.0
const DT := 1.0 / 60.0

var _fails := 0
var _player: CharacterBody2D
var _kit: Node


func _check(label: String, cond: bool, detail := "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _ready() -> void:
	_run.call_deferred()


func _step_to(pos: Vector2) -> void:
	_player.global_position = pos
	_player.tick(DT)


## Segments posés (hors tête) : tous les points stockés sauf le premier (queue glissante) doivent être
## identiques d'une frame à l'autre tant qu'ils ne sont pas rattrapés par la queue.
func _fixed_violations(trace: Array) -> int:
	var bad := 0
	for i in range(1, trace.size()):
		var a: PackedVector2Array = trace[i - 1]
		var b: PackedVector2Array = trace[i]
		# points stockés (sans la tête) de la frame i-1 qui existent encore en i : doivent avoir la même place
		for k in range(1, a.size() - 1):
			var found := false
			for q in b:
				if q.distance_to(a[k]) < 0.01:
					found = true
					break
			if not found and k > 1: # k = 1 : peut être devenu la queue
				# le point a disparu sans être la queue : il a bougé ou été supprimé hors de la queue
				if b.size() > 2 and a[k].distance_to(b[0]) > 1.0 and not _tail_ate(a, b, k):
					bad += 1
	return bad


## Vrai si la queue a mangé le point k (tous les points avant lui ont disparu).
func _tail_ate(a: PackedVector2Array, b: PackedVector2Array, k: int) -> bool:
	# la queue de b doit se situer au-delà de a[k] le long de la polyligne a
	var s_b := _arc_pos(a, b[0])
	var s_k := 0.0
	for i in range(1, k + 1):
		s_k += a[i - 1].distance_to(a[i])
	return s_b >= s_k - 0.5


func _arc_pos(pts: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	var at := 0.0
	var run := 0.0
	for i in range(1, pts.size()):
		var c := Geometry2D.get_closest_point_to_segment(p, pts[i - 1], pts[i])
		var d := p.distance_to(c)
		if d < best:
			best = d
			at = run + pts[i - 1].distance_to(c)
		run += pts[i - 1].distance_to(pts[i])
	return at


func _max_turn_deg(pts: PackedVector2Array) -> float:
	var worst := 0.0
	for i in range(2, pts.size()):
		var u := pts[i - 1] - pts[i - 2]
		var v := pts[i] - pts[i - 1]
		if u.length() < 0.001 or v.length() < 0.001:
			continue
		worst = maxf(worst, rad_to_deg(absf(u.angle_to(v))))
	return worst


func _max_seg(pts: PackedVector2Array) -> float:
	var m := 0.0
	for i in range(1, pts.size()):
		m = maxf(m, pts[i - 1].distance_to(pts[i]))
	return m


func _run() -> void:
	RunState.level = 1
	RunState.character = &"arpenteuse"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit
	_kit.clear_transients()
	_kit._last_head = Vector2.ZERO
	_player.global_position = Vector2.ZERO
	_player.tick(DT)

	print("Cercle de 3 u à 4,2 u/s")
	var trace: Array = []
	var r := 3.0 * U
	var w := 4.2 * U / r
	var ang := 0.0
	var worst_turn := 0.0
	var worst_seg := 0.0
	for i in 600:
		ang += w * DT
		_step_to(Vector2(cos(ang), sin(ang)) * r - Vector2(r, 0))
		var pts: PackedVector2Array = _kit.chain_points()
		trace.append(pts)
		if i > 120:
			worst_turn = maxf(worst_turn, _max_turn_deg(pts))
			worst_seg = maxf(worst_seg, _max_seg(pts))
	print("  pire virage ", worst_turn, "° ; plus long segment ", worst_seg / U, " u")
	_check("points posés fixes (cercle)", _fixed_violations(trace) == 0, str(_fixed_violations(trace)))
	_check("segment posé <= pas d'échantillonnage", worst_seg <= ArpenteuseKit.CHAIN_STEP_U * U + 1.0, str(worst_seg))
	_check("virage entre segments <= 30°", worst_turn <= 30.0, str(worst_turn))

	print("Zigzag à angle vif")
	_kit.clear_transients()
	_kit._last_head = _player.global_position
	trace.clear()
	worst_turn = 0.0
	var pos := _player.global_position
	var dirv := Vector2(1, 0)
	for leg in 8:
		dirv = Vector2.from_angle(deg_to_rad(60.0 if leg % 2 == 0 else -60.0))
		for i in 40:
			pos += dirv * 4.2 * U * DT
			_step_to(pos)
			trace.append(_kit.chain_points())
	_check("points posés fixes (zigzag)", _fixed_violations(trace) == 0, str(_fixed_violations(trace)))

	print("Trou de frame (saut de 1,5 u)")
	_kit.clear_transients()
	_kit._last_head = _player.global_position
	pos = _player.global_position
	for i in 20:
		pos += Vector2(1, 0) * 4.2 * U * DT
		_step_to(pos)
	pos += Vector2(1, 0) * 1.5 * U
	_step_to(pos)
	var pts2: PackedVector2Array = _kit.chain_points()
	_check("aucun segment géant après un saut", _max_seg(pts2) <= ArpenteuseKit.CHAIN_STEP_U * U + 1.0, str(_max_seg(pts2) / U))

	print("Tête de chaîne collée au joueur")
	_kit.clear_transients()
	_kit._last_head = _player.global_position
	pos = _player.global_position
	var worst_head := 0.0
	var worst_render := 0.0
	for i in 90:
		pos += Vector2.from_angle(float(i) * 0.05) * 4.2 * U * DT
		_step_to(pos)
		var cp: PackedVector2Array = _kit.chain_points()
		worst_head = maxf(worst_head, cp[cp.size() - 1].distance_to(_player.global_position))
		var rp: PackedVector2Array = _kit.line.base.points
		if rp.size() > 0: # rendu : la tête est la main, soit HAND_H_U au-dessus de la position
			worst_render = maxf(worst_render, rp[rp.size() - 1].distance_to(_player.global_position + Vector2(0, Iso.lift_logical(ArpenteuseKit.HAND_H_U))))
	_check("tête de chaîne < 0,1 u du joueur", worst_head < 0.1 * U, str(worst_head / U))
	_check("rendu : tête à la main (< 0,1 u)", worst_render < 0.1 * U, str(worst_render / U))

	print("Sorts : chaîne intacte, plus de rappel")
	_kit._tick_t = -99.0
	for i in 240: # chaîne pleine (14 u) puis on continue de marcher pendant chaque sort (immobile = touret)
		pos += Vector2(1, 0) * 4.2 * U * DT
		_step_to(pos)
	for slot in [2, 3, 4]:
		var before: float = _kit.chain_length()
		_player.spells.aim_override = _player.global_position + Vector2(3 * U, 0)
		_player.spells._remaining[slot] = 0.0
		_check("sort %d lancé" % slot, _player.spells.cast(slot))
		for i in 60:
			pos += Vector2(0, 1) * 4.2 * U * DT
			_step_to(pos)
		_check("sort %d : chaîne intacte" % slot, _kit.chain_length() > before - 0.5 * U and _kit.chain_length() > 10.0 * U, "%.1f -> %.1f u" % [before / U, _kit.chain_length() / U])
		_kit._tick_t = -99.0
	_check("aucun aperçu de fermeture (Line2D BouclePreview absent)", _kit.fx_root.get_node_or_null(^"BouclePreview") == null)

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
