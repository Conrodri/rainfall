extends Node
## Test des 6 items légendaires sur un vrai joueur en scène (Ardent, Rictus, Averse), avec ennemis factices et dégâts réels :
## données, tirages (coffres, Chance), RunState.add_item, effet à l'acquisition (apply_stats) et après chargement de run.
## godot --headless --path game res://tests/legendary_items_test.tscn   (RESULT: OK)

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func is_slowed() -> bool:
		return false

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t

	func has_status(s: StringName) -> bool:
		for x in statuses:
			if x[0] == s:
				return true
		return false


const LEGENDARY := [&"coeur_du_chronomancien", &"couronne_d_echo", &"nova_infinie", &"armure_du_colosse", &"moisson", &"de_pipe"]
const U := 64.0

var _fails := 0
var _results := {} ## item -> Array d'échecs
var _player: CharacterBody2D
var _junk: Array = []
var _cur := ""


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)
		if not _results.has(_cur):
			_results[_cur] = []
		(_results[_cur] as Array).append(label + " " + detail)


func _near(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) <= tol


func _fake(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


func _clear_fakes() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()


func _spawn(char_id: StringName) -> void:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
		await get_tree().process_frame
	RunState.character = char_id
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_player.global_position = Vector2.ZERO


## Run neuve avec les items donnés ({id: n}) via RunState.add_item, puis stats appliquées comme à l'acquisition.
func _give(items: Dictionary) -> void:
	RunState.start_run(&"moyen", 777)
	RunState.level = 1
	for id in items:
		for i in int(items[id]):
			RunState.add_item(StringName(id))
	_player.apply_stats(ItemStats.compute(RunState.items))
	_player.hp = _player.max_hp


func _no_crit() -> void:
	_player.stats["crit_chance"] = -0.05


func _kills(n: int) -> void:
	for i in n:
		Events.enemy_killed.emit(null, Vector2.ZERO, 0, false)


func _dmg(s: SpellData) -> float:
	return _player.spells.compute_damage(s, null, false)


func _spell1() -> SpellData:
	return _player.spells.character.spells[0]


func _run() -> void:
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	ItemDB.reload()
	await _spawn(&"ardent")

	_cur = "données"
	print("Données")
	var leg: Array = ItemDB.ids_of_quality(&"legendaire")
	_check("6 légendaires dans items.json", leg.size() == 6, str(leg))
	for id in LEGENDARY:
		_cur = String(id)
		var it := ItemDB.get_item(id)
		_check("%s présent, qualité légendaire, texte" % id, not it.is_empty() and it.quality == "legendaire" and str(it.effect_text) != "")
		var sp := str(it.get("special", "")) if it.get("special") != null else ""
		if sp != "" and sp != "null" and sp != "<null>":
			_check("%s : special_data défini pour « %s »" % [id, sp], not ItemEffects.data_of(StringName(sp)).is_empty())

	await _test_loot()
	for ch in [&"ardent", &"rictus", &"averse"]:
		print("== Personnage : %s ==" % ch)
		await _spawn(ch)
		_cur = "données"
		_check("[%s] nœud ItemEffects sur le joueur" % ch, _player.item_fx != null)
		await _test_colosse(ch)
		await _test_moisson(ch)
		await _test_chrono(ch)
		await _test_echo(ch)
		await _test_nova(ch)
		_test_de_pipe(ch)
	await _test_save_load()

	print("")
	print("Bilan par item :")
	for id in LEGENDARY:
		var f: Array = _results.get(String(id), [])
		print("  %-26s %s" % [id, "OK" if f.is_empty() else "FAIL : " + " | ".join(f)])
	for k in ["données", "loot", "sauvegarde"]:
		if _results.has(k):
			print("  (%s) FAIL : %s" % [k, " | ".join(_results[k])])
	print("RESULT: ", "OK" if _fails == 0 else "FAILED (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


# --- Tirages ------------------------------------------------------------------------

func _test_loot() -> void:
	print("Tirages et RunState")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var seen := {}
	_cur = "loot"
	for i in 400:
		var q: StringName = LootRoller.roll_quality(&"legendaire", rng)["quality"]
		if q != &"legendaire":
			_check("coffre légendaire donne toujours un légendaire", false, str(q))
			break
		for id in LootRoller.pick_pair(q, {}, [], rng):
			seen[id] = true
	for id in LEGENDARY:
		_cur = String(id)
		_check("%s sort du coffre légendaire (pick_pair)" % id, seen.has(String(id)))
	_cur = "loot"
	var legendary_large := 0
	for i in 20000:
		if LootRoller.roll_quality(&"large", rng)["quality"] == &"legendaire":
			legendary_large += 1
	_check("grand coffre : ~2 %% de légendaires (%d/20000)" % legendary_large, legendary_large > 200 and legendary_large < 700)
	var small_leg := 0
	for i in 5000:
		if LootRoller.roll_quality(&"petit", rng)["quality"] == &"legendaire":
			small_leg += 1
	_check("petit coffre : jamais de légendaire", small_leg == 0)
	var up := 0
	var base_n := 0
	for i in 20000:
		if LootRoller.roll_quality(&"large", rng, 0)["quality"] == &"legendaire":
			base_n += 1
		if LootRoller.roll_quality(&"large", rng, 1)["quality"] == &"legendaire":
			up += 1
	_check("Chance +1 augmente les légendaires du grand coffre (%d -> %d)" % [base_n, up], up > base_n)
	RunState.start_run(&"moyen", 5)
	var session := ChestSession.new(&"legendaire", 1, 0.0)
	session.start()
	_check("ChestSession légendaire : qualité légendaire, 2 propositions", session.quality == &"legendaire" and session.offered.size() == 2 and session.offered.all(func(i): return ItemDB.get_item(i).quality == "legendaire"), str(session.offered))
	var pick := StringName(session.offered[0])
	session.choose(get_tree(), 0)
	_check("choose() ajoute via RunState.add_item (%s)" % pick, RunState.stacks(pick) == 1)
	RunState.add_item(&"moisson")
	RunState.add_item(&"moisson")
	_check("add_item cumule les exemplaires", RunState.stacks(&"moisson") >= 2)
	var st := ItemStats.compute({&"moisson": 2, &"nova_infinie": 1})
	_check("ItemStats.compute : specials {moisson:2, nova_infinie:1}", st["specials"] == {&"moisson": 2, &"nova_infinie": 1}, str(st["specials"]))


# --- Armure du colosse ---------------------------------------------------------------

func _taken(amount: float) -> float:
	_player.hp = _player.max_hp
	_player._invuln = 0.0
	_player.take_damage(amount, null)
	return _player.max_hp - _player.hp


func _test_colosse(ch: StringName) -> void:
	_cur = "armure_du_colosse"
	_give({})
	var hp0: float = _player.max_hp
	var t0: float = _taken(5.0)
	var d0: float = _dmg(_spell1())
	_give({"armure_du_colosse": 1})
	_check("[%s] colosse : PV max +50 %% (%.1f -> %.1f)" % [ch, hp0, _player.max_hp], _near(_player.max_hp, hp0 * 1.5, 0.5))
	var t1 := _taken(5.0)
	_check("[%s] colosse : dégâts reçus -20 %% (%.2f -> %.2f)" % [ch, t0, t1], _near(t1, t0 * 0.8, 0.05))
	_check("[%s] colosse : dégâts infligés x0,9" % ch, _near(_dmg(_spell1()), d0 * 0.9, d0 * 0.005))
	_give({"armure_du_colosse": 2})
	var t2 := _taken(5.0)
	_check("[%s] colosse x2 : réduction 33 %% (%.2f vs %.2f)" % [ch, t2, t0 * 0.6667], _near(t2, t0 * 0.6667, 0.06))
	_check("[%s] colosse x2 : dégâts infligés x0,81" % ch, _near(_dmg(_spell1()), d0 * 0.81, d0 * 0.005))
	_give({})


# --- Moisson -------------------------------------------------------------------------

func _test_moisson(ch: StringName) -> void:
	_cur = "moisson"
	_give({})
	var s := _spell1()
	var d0: float = _dmg(s)
	_give({"moisson": 1})
	_check("[%s] moisson : 0 kill = 0 bonus" % ch, _near(_dmg(s), d0))
	_kills(100)
	_check("[%s] moisson : 100 kills = +20 %% (%.3f)" % [ch, _dmg(s) / d0], _near(_dmg(s), d0 * 1.2, d0 * 0.005))
	_kills(500)
	_check("[%s] moisson : plafonné à +60 %% (%.3f)" % [ch, _dmg(s) / d0], _near(_dmg(s), d0 * 1.6, d0 * 0.005))
	_player.apply_stats(ItemStats.compute(RunState.items)) # recalcul de stats : le bonus conservé dans la run revient
	_check("[%s] moisson : bonus conservé après apply_stats" % ch, _near(_dmg(s), d0 * 1.6, d0 * 0.005))
	_give({"moisson": 2})
	_kills(1000)
	_check("[%s] moisson x2 : plafond +90 %% (%.3f)" % [ch, _dmg(s) / d0], _near(_dmg(s), d0 * 1.9, d0 * 0.005))
	_give({})


# --- Cœur du chronomancien -----------------------------------------------------------

func _cd_slots() -> Array:
	return _player.spells.character.spells.filter(func(x): return not x.is_auto)


func _arm_cds() -> void:
	for sp in _cd_slots():
		_player.spells.set_cooldown(sp.slot, 20.0, 20.0)


func _on_cd() -> int:
	return _cd_slots().filter(func(x): return _player.spells.cooldown_remaining(x.slot) > 0.0).size()


func _test_chrono(ch: StringName) -> void:
	_cur = "coeur_du_chronomancien"
	_give({"coeur_du_chronomancien": 1})
	_arm_cds()
	var n_all := _cd_slots().size()
	_kills(9)
	_check("[%s] chrono : 9 kills = rien" % ch, _on_cd() == n_all)
	_kills(1)
	_check("[%s] chrono : 10 kills en 3 s = un sort remis à zéro (%d/%d en recharge)" % [ch, _on_cd(), n_all], _on_cd() == n_all - 1)
	_kills(10)
	_check("[%s] chrono : délai interne 2 s respecté" % ch, _on_cd() == n_all - 1)
	_player.item_fx.tick(2.1)
	_kills(10)
	_check("[%s] chrono : redéclenché après le délai" % ch, _on_cd() == n_all - 2)
	_give({"coeur_du_chronomancien": 1})
	_player.item_fx.tick(3.5) # les kills du scénario précédent sortent de la fenêtre
	_arm_cds()
	for i in 10:
		_kills(1)
		_player.item_fx.tick(0.5)
	_check("[%s] chrono : 10 kills en 5 s = rien" % ch, _on_cd() == n_all)
	_give({})


# --- Couronne d'écho -----------------------------------------------------------------

func _test_echo(ch: StringName) -> void:
	_cur = "couronne_d_echo"
	_clear_fakes()
	for n in [0, 1, 2]:
		_give({"couronne_d_echo": n} if n > 0 else {})
		_fake(Vector2(3.0 * U, 0.0))
		_player.spells.aim_override = null
		_player.spells.set_cooldown(1, 0.0, 1.0)
		var casts := [0]
		var c := func(_s: SpellData) -> void: casts[0] += 1
		_player.spells.spell_cast.connect(c)
		var ok: bool = _player.spells.cast(1)
		_player.item_fx.tick(0.2 * (n + 1))
		_player.spells.spell_cast.disconnect(c)
		_check("[%s] écho x%d : sort 1 lancé %d fois (attendu %d, premier lancer ok=%s)" % [ch, n, casts[0], 1 + n, ok], ok and casts[0] == 1 + n)
		_check("[%s] écho x%d : recharge du sort 1 intacte" % [ch, n], _player.spells.cooldown_remaining(1) > 0.0)
		_clear_fakes()
		await get_tree().process_frame
	_give({})


# --- Nova infinie --------------------------------------------------------------------

func _test_nova(ch: StringName) -> void:
	_cur = "nova_infinie"
	_clear_fakes()
	_give({"nova_infinie": 1})
	_no_crit()
	var near := _fake(Vector2(2.0 * U, 0.0))
	var far := _fake(Vector2(12.0 * U, 0.0))
	var ref := SpellData.new()
	ref.coef = 4.0
	var want: float = _player.spells.compute_damage(ref, null, false)
	_player.item_fx.tick(3.5)
	_check("[%s] nova : rien avant 4 s" % ch, near.taken.is_empty())
	_player.item_fx.tick(0.6)
	_check("[%s] nova : dégâts 400 %% (%.1f, attendu %.1f)" % [ch, near.total(), want], near.taken.size() == 1 and _near(near.total(), want, want * 0.01))
	_check("[%s] nova : brûlure, ralentissement et poison appliqués" % ch, near.has_status(&"burn") and near.has_status(&"slow") and near.has_status(&"poison"))
	_check("[%s] nova : ennemi hors zone épargné" % ch, far.taken.is_empty() and far.statuses.is_empty())
	var fx := _player.spells.get("_container") as Node2D
	_check("[%s] nova : zone/VFX créé" % ch, fx.get_child_count() > 0)
	_player.item_fx.tick(3.0)
	_check("[%s] nova : une seule par période" % ch, near.taken.size() == 1)
	_player.item_fx.tick(1.1)
	_check("[%s] nova : se redéclenche (4 s)" % ch, near.taken.size() == 2)
	_clear_fakes()
	_give({"nova_infinie": 2})
	_no_crit()
	var e2 := _fake(Vector2(2.0 * U, 0.0))
	_player.item_fx.tick(4.1)
	_check("[%s] nova x2 : dégâts doublés (%.1f)" % [ch, e2.total()], _near(e2.total(), want * 2.0, want * 0.02))
	_clear_fakes()
	await get_tree().process_frame
	_give({})


# --- Dé pipé -------------------------------------------------------------------------

func _test_de_pipe(ch: StringName) -> void:
	_cur = "de_pipe"
	_give({"de_pipe": 1})
	_check("[%s] dé pipé : Chance +1 sur le joueur" % ch, _near(_player.luck(), 1.0))
	if ch != &"ardent":
		_give({})
		return
	var bad := 0
	for sd in 300:
		RunState.start_run(&"moyen", 1000 + sd)
		RunState.add_item(&"de_pipe")
		var s1 := ChestSession.new(&"petit", 2, 50.0, RunState.rng)
		s1.start()
		if LootRoller.quality_rank(s1.quality) < 1:
			bad += 1
	_check("dé pipé : 1er petit coffre de l'étage >= Peu commun (%d échecs/300)" % bad, bad == 0)
	RunState.start_run(&"moyen", 31)
	RunState.add_item(&"de_pipe")
	var commons := 0
	for i in 200:
		var s2 := ChestSession.new(&"petit", 1, 50.0, RunState.rng)
		s2.start()
		if i > 0 and s2.quality == &"commun":
			commons += 1
	_check("dé pipé : petits coffres suivants du même étage normaux (%d communs)" % commons, commons > 50)
	var s3 := ChestSession.new(&"petit", 2, 50.0, RunState.rng)
	s3.start()
	_check("dé pipé : nouvel étage = nouveau coffre garanti", LootRoller.quality_rank(s3.quality) >= 1)
	RunState.start_run(&"moyen", 32)
	var base_commons := 0
	var n := 300
	for i in n:
		var sx := ChestSession.new(&"petit", 1, 50.0, RunState.rng)
		sx.start()
		if sx.quality == &"commun":
			base_commons += 1
	_check("sans dé pipé : communs fréquents (%d/%d)" % [base_commons, n], base_commons > n / 2)
	_give({})


# --- Sauvegarde de run -----------------------------------------------------------------

func _test_save_load() -> void:
	_cur = "sauvegarde"
	print("Sauvegarde de run")
	await _spawn(&"rictus")
	_give({})
	var d_empty: float = _dmg(_spell1())
	var hp_empty: float = _player.max_hp
	_give({"moisson": 1, "nova_infinie": 1, "coeur_du_chronomancien": 1, "couronne_d_echo": 1, "de_pipe": 1})
	_kills(150)
	var json := JSON.stringify(RunState.to_dict())
	RunState.start_run(&"moyen", 1) # run vierge
	await _spawn(&"rictus") # nouvelle scène
	RunState.from_dict(JSON.parse_string(json))
	_player.apply_stats(ItemStats.compute(RunState.items)) # comme main._restore
	_cur = "moisson"
	_check("[load] moisson : +30 %% restauré (150 kills) (%.3f)" % (_dmg(_spell1()) / d_empty), _near(_dmg(_spell1()), d_empty * 1.3, d_empty * 0.01))
	_cur = "nova_infinie"
	_clear_fakes()
	var e := _fake(Vector2(2.0 * U, 0.0))
	_player.item_fx.tick(4.1)
	_check("[load] nova active après chargement", e.total() > 0.0)
	_clear_fakes()
	_cur = "coeur_du_chronomancien"
	_arm_cds()
	_kills(10)
	_check("[load] chrono actif après chargement", _on_cd() == _cd_slots().size() - 1)
	_cur = "couronne_d_echo"
	_fake(Vector2(3.0 * U, 0.0))
	var casts := [0]
	var c := func(_s: SpellData) -> void: casts[0] += 1
	_player.spells.spell_cast.connect(c)
	_player.spells.set_cooldown(1, 0.0, 1.0)
	var ok: bool = _player.spells.cast(1)
	_player.item_fx.tick(0.5)
	_check("[load] écho actif après chargement (%d lancers)" % casts[0], ok and casts[0] == 2)
	_clear_fakes()
	_cur = "de_pipe"
	_check("[load] dé pipé : Chance restaurée", _near(_player.luck(), 1.0))
	_give({"armure_du_colosse": 1})
	var json2 := JSON.stringify(RunState.to_dict())
	RunState.start_run(&"moyen", 2)
	_player.apply_stats(ItemStats.compute(RunState.items))
	var hp_none: float = _player.max_hp
	RunState.from_dict(JSON.parse_string(json2))
	_player.apply_stats(ItemStats.compute(RunState.items))
	_cur = "armure_du_colosse"
	_check("[load] colosse : PV max +50 %% après chargement (%.1f -> %.1f, base %.1f)" % [hp_none, _player.max_hp, hp_empty], _near(_player.max_hp, hp_none * 1.5, 0.5))
	_give({})
