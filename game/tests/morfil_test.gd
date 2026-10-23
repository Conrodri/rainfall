extends Node
## Test headless de Taliant, rōnin d'écorce (docs/Design_Personnages.md §2.8) : stats, 4 sorts, formule
## d'aiguisage (dégâts × aiguisage / 100), coût par coup, plancher, alternance circulaire / estoc, Fauche-lune
## (demi-cercle devant), Aiguisage (remonte à 100 %), ultime (seuil 90 %, doublement des coups pendant la
## moitié de la recharge effective), Iaï (roulade qui tranche), ressource HUD, sauvegarde, lumière, anims.
## godot --headless --path game res://tests/morfil_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var radius_px := 16.0

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass

	func is_slowed() -> bool:
		return false

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t


const U := 64.0
const BASE := 12.0

var _fails := 0
var _player: CharacterBody2D
var _kit: MorfilKit
var _junk: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _near(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) <= tol


func _fake(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


## Avance le joueur de `t` s (pas de 1/60) ; auto suspendue sauf `auto`. Les zones instantanées frappent à
## leur création ; on les laisse vivre (pas de _process utile ici).
func _advance(t: float, auto := false) -> void:
	var n := int(ceil(t * 60.0))
	for i in n:
		if not auto:
			_player.spells._remaining[1] = 99.0
		if _player.is_dodging():
			_player._dodge_step(1.0 / 60.0)
		_player.tick(1.0 / 60.0)
	if not auto:
		_player.spells._remaining[1] = 0.0


func _clear_enemies() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()


func _reset() -> void:
	_clear_enemies()
	_kit.clear_transients()
	_kit.sharpness = MorfilKit.SHARP_MAX
	_kit.twin_left = 0.0
	_kit.sharpen_left = 0.0
	_kit.next_is_thrust = false
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.refresh_max_hp(true)
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player._invuln = 0.0
	_player._dodge_cd = 0.0
	_player._dodge_left = 0.0


func _cast(slot: int) -> bool:
	return _player.spells.cast(slot)


func _run() -> void:
	RunState.level = 1
	RunState.character = &"morfil"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as MorfilKit
	_reset()

	print("Personnage")
	_check("kit Taliant (CharacterData.for_id)", _kit != null)
	_check("4 sorts / ids", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["taille_estoc", "fauche_lune", "aiguisage", "lames_jumelles"])
	_check("PV L1 = 115", _near(_player.max_hp, MorfilKit.BASE_HP), str(_player.max_hp))
	_check("armure 25", _near(_player.armor(), MorfilKit.ARMOR))
	_check("régén 0,8", _near(_player.regen_per_s(), 0.8))
	_check("vitesse 3,9 u/s", _near(_player.move_speed(), 3.9 * U), str(_player.move_speed()))
	var cfg: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var entry: Dictionary = {}
	for c in cfg:
		if c["id"] == "morfil":
			entry = c
	_check("characters.json : entrée ouverte, difficulté, 4 sorts", not entry.is_empty() and entry.get("unlocked") == true
		and int(entry.get("difficulty", 0)) == 3 and (entry.get("spells", []) as Array).size() == 4)
	_check("lumière de sort morfil_edge (accent, pas la braise)", not LightRig.get_preset(&"morfil_edge").is_empty())
	_check("repli visuel : Ardent teinté écorce", (_player.get_node("Visual") as CanvasItem).self_modulate.is_equal_approx(MorfilKit.PLACEHOLDER_TINT)
		or ResourceLoader.exists(MorfilKit.SPRITE_FRAMES))

	print("Formule d'aiguisage")
	_check("100 % -> ×1,0 ; 50 % -> ×0,5 ; 1 % par %", _near(MorfilKit.sharp_mult(100.0), 1.0) and _near(MorfilKit.sharp_mult(50.0), 0.5)
		and _near(MorfilKit.sharp_mult(73.0) - MorfilKit.sharp_mult(72.0), 0.01))

	print("Sort 1 : Taille et estoc (alternance, coût par coup)")
	var e1 := _fake(Vector2(1.5 * U, 0))
	_check("auto lancée (cible à 1,5 u)", _cast(1))
	_check("anim d'action (repli attack, ou cut_circle SA1)", _player.action_base() in [&"attack", &"cut_circle"], str(_player.action_base()))
	_check("effet en attente de la frame d'impact", _kit.has_pending())
	_advance(0.3)
	_check("coup circulaire = coef × 12 × 100 %", _near(e1.total(), MorfilKit.CIRCLE_COEF * BASE, 0.05), str(e1.taken))
	_check("coût par coup : 100 - 4 = 96 %", _near(_kit.sharpness, 100.0 - MorfilKit.COST_CIRCLE), str(_kit.sharpness))
	var behind := _fake(Vector2(-2.0 * U, 0)) # plus loin : e1 reste la cible
	_kit.sharpness = 50.0
	_player.spells._remaining[1] = 0.0
	_check("2e auto lancée", _cast(1))
	_advance(0.3)
	_check("estoc (alternance) = coef × 12 × 50 %", _near(e1.taken.back(), MorfilKit.THRUST_COEF * BASE * 0.5, 0.05), str(e1.taken))
	_check("estoc étroit : le monstre derrière n'est pas touché", behind.taken.is_empty(), str(behind.taken))
	_check("coût par coup : 50 - 4 = 46 %", _near(_kit.sharpness, 50.0 - MorfilKit.COST_THRUST), str(_kit.sharpness))
	_check("compteur de coups", _kit.swings == 2)
	_reset()
	var far := _fake(Vector2(3.3 * U, 0))
	_cast(1)
	_advance(0.3)
	_check("cible hors du cercle mais à portée d'estoc : estoc joué", _near(far.total(), MorfilKit.THRUST_COEF * BASE, 0.05), str(far.taken))
	_reset()
	_check("sans cible : rien lancé, rien consommé", not _cast(1) and _near(_kit.sharpness, 100.0))
	_kit.sharpness = 12.0
	_kit.consume(30.0)
	_check("plancher : jamais sous 10 %", _near(_kit.sharpness, MorfilKit.SHARP_MIN))

	print("Sort 2 : Fauche-lune (demi-cercle devant)")
	_reset()
	var front := _fake(Vector2(3.0 * U, 0.5 * U))
	var back := _fake(Vector2(-2.0 * U, 0))
	_player.spells.aim_override = Vector2(5 * U, 0)
	_check("Fauche-lune lancée", _cast(2))
	_advance(0.5)
	_check("devant touché : coef × 12", _near(front.total(), MorfilKit.CRESCENT_COEF * BASE, 0.05), str(front.taken))
	_check("derrière épargné", back.taken.is_empty())
	_check("coût 15 % : 85 %", _near(_kit.sharpness, 100.0 - MorfilKit.COST_CRESCENT), str(_kit.sharpness))
	_check("recharge 6 s", _near(_player.spells.cooldown_remaining(2), 6.0, 0.6))

	print("Sort 3 : Aiguisage")
	_reset()
	_check("au fil (100 %) : refusé, recharge gardée", not _cast(3) and _near(_player.spells.cooldown_remaining(3), 0.0))
	_kit.sharpness = 31.0
	_check("Aiguisage lancé à 31 %", _cast(3))
	_check("auto suspendue pendant le geste", _player.spells.is_slot_blocked(1))
	_advance(0.6)
	_check("aiguisage remonté à 100 %", _near(_kit.sharpness, 100.0), str(_kit.sharpness))
	_check("recharge 10 s", _near(_player.spells.cooldown_remaining(3), MorfilKit.SHARPEN_CD, 0.7))
	_check("auto-cast : n'aiguise que sous 55 %", not _kit.auto_cast_ok(3))

	print("Sort 4 : Lames jumelles (seuil 90 %, doublement, moitié de la recharge)")
	_reset()
	_kit.sharpness = 89.0
	_check("89 % : ultime refusé", not _cast(4))
	_check("89 % : recharge non consommée", _near(_player.spells.cooldown_remaining(4), 0.0))
	_check("89 % : bouton grisé (slot_affordable faux)", not _player.spells.slot_affordable(4))
	_kit.sharpness = 90.0
	_check("90 % : ultime lancé", _cast(4))
	_advance(0.5)
	var total4: float = 0.0
	for c in _player.get_spell_cooldowns():
		if c["slot"] == 4:
			total4 = c["total"]
	_check("Lames jumelles actives", _kit.is_twin())
	_check("durée = moitié de la recharge (30 s -> 15 s)", _near(_kit.twin_total, total4 * 0.5, 0.01) and _near(total4, 30.0), "%s / %s" % [_kit.twin_total, total4])
	_check("le dégainé ne coûte rien", _near(_kit.sharpness, 90.0), str(_kit.sharpness))
	var t1 := _fake(Vector2(1.2 * U, 0))
	_kit.next_is_thrust = false
	_player.spells._remaining[1] = 0.0
	_cast(1)
	_advance(0.35)
	var expect := MorfilKit.CIRCLE_COEF * BASE * 0.9
	_check("coup doublé : second coup x0,7 (23/10)", t1.taken.size() == 2 and _near(t1.taken[0], expect, 0.05) and _near(t1.taken[1], expect * MorfilKit.TWIN_STRIKE_MULT, 0.05), str(t1.taken))
	_check("un seul coût par geste doublé (90 -> 86)", _near(_kit.sharpness, 90.0 - MorfilKit.COST_CIRCLE), str(_kit.sharpness))
	_check("compteur du second katana", _kit.twin_strikes >= 1)
	_check("ressource : boost pendant les Lames jumelles", bool(KitResource.of(_player).get("boost", false)))
	_advance(15.0)
	_check("fin après 15 s", not _kit.is_twin())
	t1.taken.clear()
	_player.spells._remaining[1] = 0.0
	_cast(1)
	_advance(0.35)
	_check("après : un seul coup", t1.taken.size() == 1, str(t1.taken))
	# cooldown_mult : la durée suit la recharge effective
	_reset()
	_player.apply_stats({"crit_chance": -0.05, "cooldown_mult": 0.8})
	_cast(4)
	_advance(0.5)
	var eff := Balance.effective_cooldown(MorfilKit.TWIN_CD, 0.8)
	_check("cooldown_mult 0,8 : durée = recharge effective / 2", _near(_kit.twin_total, eff * 0.5, 0.01), "%s vs %s" % [_kit.twin_total, eff * 0.5])
	_player.apply_stats({"crit_chance": -0.05})

	print("Garde du bretteur")
	_reset()
	_check("hors garde : dégâts subis × 1", _near(_kit.damage_taken_mult(null), 1.0))
	var g := _fake(Vector2(1.2 * U, 0))
	_cast(1)
	_advance(0.3)
	_check("après un geste : × 0,55", _near(_kit.damage_taken_mult(null), MorfilKit.GUARD_TAKEN_MULT))
	_advance(0.7)
	_check("garde retombée", _near(_kit.damage_taken_mult(null), 1.0))
	_kit.twin_left = 5.0
	_check("Lames jumelles : garde continue", _near(_kit.damage_taken_mult(null), MorfilKit.GUARD_TAKEN_MULT))
	_kit.twin_left = 0.0
	g.taken.clear()

	print("Roulade : Iaï")
	_reset()
	var cut := _fake(Vector2(1.5 * U, 0))
	var cut2 := _fake(Vector2(2.2 * U, 0.2 * U))
	_check("roulade lancée", _player.dodge(Vector2.RIGHT))
	_advance(0.4)
	_check("monstres traversés tranchés une fois (1,5 × 12)", cut.taken.size() == 1 and cut2.taken.size() == 1
		and _near(cut.taken[0], MorfilKit.IAI_COEF * BASE, 0.05), "%s %s" % [cut.taken, cut2.taken])
	_check("un seul coût par roulade (96 %)", _near(_kit.sharpness, 100.0 - MorfilKit.COST_IAI), str(_kit.sharpness))

	print("Ressource, sauvegarde, étage")
	_reset()
	_kit.sharpness = 64.0
	var r := KitResource.of(_player)
	_check("KitResource : id, ratio, repère 90 %", r.get("id") == &"sharpness" and _near(float(r["ratio"]), 0.64) and _near(float(r["mark"]), 0.9), str(r))
	_check("texte « 64 % »", str(r.get("text")) == "64 %")
	var st := _kit.save_state()
	_kit.sharpness = 100.0
	_kit.load_state(st)
	_check("sauvegarde : aiguisage restauré", _near(_kit.sharpness, 64.0))
	Events.floor_started.emit(2)
	_check("nouvel étage : lame repassée à 100 %", _near(_kit.sharpness, 100.0))

	_clear_enemies()
	_player.queue_free()
	director.queue_free()
	await get_tree().process_frame
	if _fails == 0:
		print("RESULT: OK")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _fails)
		get_tree().quit(1)
