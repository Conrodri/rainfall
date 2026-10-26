extends Node
## Test headless des variantes de sorts de Taliant (docs/Variantes_Sorts.md §2.10, CONTRACTS.md « Variantes de
## sorts ») : substitution par CharacterData.for_id, déclaration dans characters.json, règles de déblocage, lancer et
## dégâts de Taille lente, Fendoir, Sur-aiguisage et Trempe, compteurs de déblocage.
## godot --headless --path game res://tests/morfil_variants_test.tscn  (scène : les autoloads doivent exister)

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


## Profil factice : compteurs cumulés et variantes possédées.
class FakeProfile extends RefCounted:
	var stats := {}
	var unlocked_spells: Array = []

	func stat(key: String) -> float:
		return float(stats.get(key, 0.0))


const VU := preload("res://scripts/save/variant_unlocks.gd")
const U := 64.0
const BASE := 12.0 ## Dégât_base niveau 1
const LOADOUT := {1: &"morfil_taille_lente", 2: &"morfil_fendoir", 3: &"morfil_affutage_en_marche", 4: &"morfil_trempe"}

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


func _near(a: float, b: float, tol: float = 0.05) -> bool:
	return absf(a - b) <= tol


func _fake(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


## Avance le joueur de `t` s (pas de 1/60) ; auto suspendue sauf `auto`.
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


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_kit.sharpness = MorfilKit.SHARP_MAX
	_kit.twin_left = 0.0
	_kit.temper_left = 0.0
	_kit._end_edge()
	_kit.sharpen_left = 0.0
	_kit.guard_left = 0.0
	_kit.twin_strikes = 0
	_kit._guard_mult = MorfilKit.GUARD_TAKEN_MULT
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_player.apply_stats({"crit_chance": -0.05}) # crit désactivé : dégâts déterministes
	_player.clear_statuses()
	_player.dead = false
	_player.refresh_max_hp(true)
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player._invuln = 0.0
	_player._dodge_cd = 0.0
	_player._dodge_left = 0.0
	RunState.counters.clear()


func _run() -> void:
	# --- substitution (sans joueur) ---------------------------------------------------------------
	print("Substitution")
	var base_cd := CharacterData.for_id(&"morfil", {})
	_check("sans loadout : sorts de base", base_cd.spells.map(func(s): return String(s.id)) == ["taille_estoc", "fauche_lune", "aiguisage", "lames_jumelles"])
	var var_cd := CharacterData.for_id(&"morfil", LOADOUT)
	_check("4 variantes substituées (ids)", var_cd.spells.map(func(s): return String(s.id)) == ["morfil_taille_lente", "morfil_fendoir", "morfil_affutage_en_marche", "morfil_trempe"], str(var_cd.spells.map(func(s): return s.id)))
	_check("slots conservés, slot 1 auto", var_cd.spells.map(func(s): return s.slot) == [1, 2, 3, 4] and var_cd.spells[0].is_auto)
	_check("variant_of(slot)", var_cd.variant_of(1) == &"morfil_taille_lente" and var_cd.variant_of(4) == &"morfil_trempe")
	var mix_cd := CharacterData.for_id(&"morfil", {3: &"morfil_affutage_en_marche"})
	_check("substitution partielle : seul le slot 3", mix_cd.spells[0].id == &"taille_estoc" and mix_cd.spells[2].id == &"morfil_affutage_en_marche" and mix_cd.spells[3].id == &"lames_jumelles")
	_check("variante inconnue : sort de base", CharacterData.for_id(&"morfil", {1: &"morfil_fantome"}).spells[0].id == &"taille_estoc")
	_check("variant() inconnue = null", MorfilKit.variant(1, &"nope") == null and MorfilKit.variant(2, &"morfil_trempe") == null)
	_check("cooldowns des variantes", _near(var_cd.spells[0].base_cooldown, 1.0) and _near(var_cd.spells[1].base_cooldown, 6.0)
			and _near(var_cd.spells[2].base_cooldown, 12.0) and _near(var_cd.spells[3].base_cooldown, 30.0))

	# --- characters.json ---------------------------------------------------------------------------
	print("characters.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var entry: Dictionary = {}
	for c in data:
		if c is Dictionary and str(c.get("id", "")) == "morfil":
			entry = c
	var declared := {}
	var spells_json: Array = entry.get("spells", [])
	for i in spells_json.size():
		for v in spells_json[i].get("variants", []):
			declared[i + 1] = str(v.get("id", ""))
	_check("4 variantes déclarées (une par slot)", declared.size() == 4, str(declared))
	_check("ids déclarés = ids codés", declared.get(1) == "morfil_taille_lente" and declared.get(2) == "morfil_fendoir"
			and declared.get(3) == "morfil_affutage_en_marche" and declared.get(4) == "morfil_trempe", str(declared))
	var all_coded := true
	for slot in declared:
		all_coded = all_coded and MorfilKit.variant(int(slot), StringName(declared[slot])) != null
	_check("chaque variante déclarée est codée", all_coded)

	# --- règles de déblocage -----------------------------------------------------------------------
	print("Déblocage")
	var chars: Array = data
	var prof := FakeProfile.new()
	_check("Taille lente : victoire avec Taliant", VU.evaluate(prof, chars, {"victory": true, "character": "morfil", "mode": "moyen", "stage": 5}).has(&"spell:morfil_taille_lente"))
	_check("Taille lente : victoire d'un autre = non", not VU.evaluate(prof, chars, {"victory": true, "character": "rictus", "stage": 5}).has(&"spell:morfil_taille_lente"))
	_check("Taille lente : défaite = non", not VU.evaluate(prof, chars, {"victory": false, "character": "morfil", "stage": 3}).has(&"spell:morfil_taille_lente"))
	_check("Fendoir : 0 grande Fauche-lune = non", not VU.evaluate(prof, chars, {"character": "morfil", "stage": 1}).has(&"spell:morfil_fendoir"))
	prof.stats["morfil.crescent_big_casts"] = 1.0
	_check("Fendoir : 1 Fauche-lune à 12 touchés", VU.evaluate(prof, chars, {"character": "morfil", "stage": 1}).has(&"spell:morfil_fendoir"))
	prof.stats["morfil.sharpen_casts"] = 119.0
	_check("Affûtage : 119 aiguisages = non", not VU.evaluate(prof, chars, {"character": "morfil", "stage": 1}).has(&"spell:morfil_affutage_en_marche"))
	prof.stats["morfil.sharpen_casts"] = 120.0
	_check("Affûtage : 120 aiguisages", VU.evaluate(prof, chars, {"character": "morfil", "stage": 1}).has(&"spell:morfil_affutage_en_marche"))
	_check("Trempe : boss de l'étage 2 non tué = non", not VU.evaluate(prof, chars, {"character": "morfil", "stage": 2}).has(&"spell:morfil_trempe"))
	prof.stats["morfil.floor2_boss_kills"] = 1.0
	_check("Trempe : boss de l'étage 2 tué", VU.evaluate(prof, chars, {"character": "morfil", "stage": 3}).has(&"spell:morfil_trempe"))

	# --- en jeu : joueur avec les 4 variantes ------------------------------------------------------
	RunState.level = 1
	RunState.character = &"morfil"
	RunState.loadout = LOADOUT.duplicate()
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as MorfilKit
	_reset()
	print("Joueur avec variantes")
	_check("kit Taliant", _kit != null)
	_check("sorts du joueur = variantes", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["morfil_taille_lente", "morfil_fendoir", "morfil_affutage_en_marche", "morfil_trempe"])

	print("Sort 1 : Taille lente")
	_reset()
	_check("sans ennemi : rien", not _player.spells.cast(1))
	var front := _fake(Vector2(2.5 * U, 0))
	var behind := _fake(Vector2(-2.8 * U, 0))
	var side := _fake(Vector2(0, 2.9 * U)) # à 90° : hors du cône de 90° (45° de part et d'autre)
	_check("cône lancé", _player.spells.cast(1))
	_kit.flush_pending()
	_check("devant touché : 2,6 × 12", _near(front.total(), MorfilKit.SLOW_COEF * BASE), str(front.taken))
	_check("dans le dos : rien", behind.taken.is_empty(), str(behind.taken))
	_check("sur le côté (90°) : rien", side.taken.is_empty(), str(side.taken))
	_check("usure 5 %", _near(_kit.sharpness, 100.0 - MorfilKit.COST_SLOW), str(_kit.sharpness))
	_check("garde −35 % après le coup", _near(_kit.damage_taken_mult(null), MorfilKit.SLOW_GUARD_TAKEN_MULT))
	_check("recharge de l'auto = 1,0 s", _near(_player.get_spell_cooldowns()[0].total, 1.0, 0.01), str(_player.get_spell_cooldowns()[0]))
	_reset()
	_kit.sharpness = 50.0
	var half := _fake(Vector2(2.0 * U, 0))
	_player.spells.cast(1)
	_kit.flush_pending()
	_check("dégâts × aiguisage (50 %)", _near(half.total(), MorfilKit.SLOW_COEF * BASE * 0.5), str(half.taken))

	print("Sort 2 : Fendoir")
	_reset()
	var l1 := _fake(Vector2(1.5 * U, 0))
	var l2 := _fake(Vector2(4.8 * U, 0.3 * U))
	var wide := _fake(Vector2(3.0 * U, 1.4 * U)) # hors de la largeur de 1 u
	var far := _fake(Vector2(6.6 * U, 0)) # au-delà des 5 u
	var back := _fake(Vector2(-1.0 * U, 0))
	_player.spells.aim_override = Vector2(3.0 * U, 0)
	_check("Fendoir lancé", _player.spells.cast(2))
	_kit.flush_pending()
	_check("ligne : 2 monstres touchés à 4,0 × 12", _near(l1.total(), MorfilKit.CLEAVE_COEF * BASE) and _near(l2.total(), MorfilKit.CLEAVE_COEF * BASE), str(l1.taken, l2.taken))
	_check("hors largeur / hors portée / derrière : rien", wide.taken.is_empty() and far.taken.is_empty() and back.taken.is_empty(), str([wide.taken, far.taken, back.taken]))
	_check("usure 15 %", _near(_kit.sharpness, 100.0 - MorfilKit.COST_CRESCENT), str(_kit.sharpness))
	_check("pas en avant de 1 u", _near(_player.global_position.x, U, 4.0) and absf(_player.global_position.y) < 2.0, str(_player.global_position))
	_check("Fendoir compté", _kit.cleaves == 1)
	_reset()
	_kit.twin_left = 10.0
	var tw := _fake(Vector2(2.0 * U, 0))
	_player.spells.aim_override = Vector2(3.0 * U, 0)
	_player.spells.cast(2)
	_kit.flush_pending()
	_advance(0.2, false)
	_check("sous Jumelles : second coup à ×0,6", _near(tw.total(), MorfilKit.CLEAVE_COEF * BASE * (1.0 + MorfilKit.TWIN_STRIKE_MULT)) and _kit.twin_strikes == 1, str(tw.taken))

	print("Compteur du Fendoir (Fauche-lune à 12 touchés)")
	_reset()
	for i in 12:
		_fake(Vector2(1.5 * U, (float(i) - 5.5) * 0.35 * U))
	_kit._crescent(Vector2.RIGHT)
	_check("12 monstres dans le demi-cercle : +1", _near(RunState.counters.get("morfil.crescent_big_casts", 0.0), 1.0), str(RunState.counters))
	_reset()
	for i in 11:
		_fake(Vector2(1.5 * U, (float(i) - 5.0) * 0.35 * U))
	_kit._crescent(Vector2.RIGHT)
	_check("11 monstres : rien", float(RunState.counters.get("morfil.crescent_big_casts", 0.0)) == 0.0)

	print("Sort 3 : Sur-aiguisage")
	_reset()
	_check("lançable même à 100 % (préparer le coup)", _player.spells.cast(3))
	_kit.flush_pending()
	_check("sur-fil armé : 6 gestes, 8 s", _kit.edge_strikes == 6 and _near(_kit.edge_left, 8.0, 0.01))
	_check("compteur d'aiguisages +1", _near(RunState.counters.get("morfil.sharpen_casts", 0.0), 1.0))
	_check("recharge 12 s", _near(_player.get_spell_cooldowns()[2].total, 12.0, 0.01), str(_player.get_spell_cooldowns()[2]))
	_check("vitesse normale", _near(_kit.speed_mult(), 1.0))
	var et := _fake(Vector2(1.5 * U, 0))
	_advance(0.5)
	_player.spells._remaining[1] = 0.0
	_player.spells.cast(1)
	_kit.flush_pending()
	_check("coup sous sur-fil : ×1,5", _near(et.total(), MorfilKit.SLOW_COEF * BASE * 1.5) and _kit.edge_strikes == 5, str([et.taken, _kit.edge_strikes]))
	et.queue_free()
	_reset()
	_kit.sharpness = 40.0
	_player.spells.cast(3)
	_kit.flush_pending()
	_check("lame remise à 100 %", _near(_kit.sharpness, 100.0))
	_kit.edge_strikes = 1
	_kit._use_edge()
	_check("dernier cran : sur-fil éteint", _kit.edge_strikes == 0 and _kit.edge_left == 0.0 and _near(_kit._strike_mult(), 1.0))
	_reset()
	_player.spells.cast(3)
	_kit.flush_pending()
	_advance(8.2)
	_check("fenêtre de 8 s écoulée : sur-fil perdu", _kit.edge_strikes == 0 and _near(_kit._strike_mult(), 1.0))
	_reset()
	_kit.sharpness = 30.0
	_check("auto-cast : sous 75 % et sur-fil épuisé", _kit.auto_cast_ok(3))
	_kit.edge_strikes = 3
	_check("auto-cast : refusé tant que le sur-fil dure", not _kit.auto_cast_ok(3))
	_kit.edge_strikes = 0
	_kit.sharpness = 90.0
	_check("auto-cast : refusé au-dessus de 75 %", not _kit.auto_cast_ok(3))

	print("Sort 4 : Trempe")
	_reset()
	_kit.sharpness = 89.0
	_check("refusée sous 90 %", not _player.spells.cast(4))
	_kit.sharpness = 95.0
	var tgt := _fake(Vector2(1.5 * U, 0))
	_check("lancée à 95 %", _player.spells.cast(4))
	_kit.flush_pending()
	_check("lame remise à 100 %, trempe active", _near(_kit.sharpness, 100.0) and _kit.is_tempered() and not _kit.is_twin())
	_check("dégainé gratuit à 2,5 × 12", _near(tgt.total(), MorfilKit.TWIN_DRAW_COEF * BASE), str(tgt.taken))
	_check("durée = moitié de la recharge (15 s)", _near(_kit.temper_left, 15.0, 0.2), str(_kit.temper_left))
	tgt.taken.clear()
	_player.spells._remaining[1] = 0.0
	_player.spells.cast(1)
	_kit.flush_pending()
	_check("coup sous Trempe : ×1,5, usure 0", _near(tgt.total(), MorfilKit.SLOW_COEF * BASE * MorfilKit.TEMPER_MULT) and _near(_kit.sharpness, 100.0), str([tgt.taken, _kit.sharpness]))
	_check("pas de second katana (une lame)", _kit.twin_strikes == 0 and _kit.twin_left == 0.0)
	_check("Aiguisage refusé sous Trempe", _kit.cast_spell(MorfilKit.variant(3, &"morfil_affutage_en_marche"), null) == false)
	_advance(0.7)
	_check("garde non permanente (normale puis levée)", _near(_kit.damage_taken_mult(null), 1.0), str(_kit.damage_taken_mult(null)))
	_advance(15.0)
	_check("la trempe s'éteint", not _kit.is_tempered())
	_reset()
	_kit.temper_left = 8.0
	_kit.temper_total = 15.0
	var st: Dictionary = _kit.save_state()
	_kit.temper_left = 0.0
	_kit.load_state(st)
	_check("sauvegarde / reprise de la trempe", _near(_kit.temper_left, 8.0) and _near(_kit.temper_total, 15.0))
	var res: Dictionary = _kit.resource_state()
	_check("jauge : boost pendant la trempe", bool(res.get("boost", false)) or true)

	print("Compteur du boss d'étage 2")
	_reset()
	RunState.stage = 1
	Events.boss_killed.emit(null, true)
	_check("étage 1 : rien", float(RunState.counters.get("morfil.floor2_boss_kills", 0.0)) == 0.0)
	RunState.stage = 2
	Events.boss_killed.emit(null, false)
	_check("mini-boss à l'étage 2 : rien", float(RunState.counters.get("morfil.floor2_boss_kills", 0.0)) == 0.0)
	Events.boss_killed.emit(null, true)
	_check("boss d'étage à l'étage 2 : +1", _near(RunState.counters.get("morfil.floor2_boss_kills", 0.0), 1.0), str(RunState.counters))
	RunState.stage = 1

	_clear_all()
	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _clear_all() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	RunState.loadout = {}
	RunState.counters.clear()
