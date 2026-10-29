extends Node
## Effets des objets non légendaires à logique propre (champ `special` de items.json) sur un vrai joueur en scène, avec
## Ardent et des personnages à kit (Rictus, Vigie) : acquisition (RunState.add_item + apply_stats), effet, cumul et reprise
## de sauvegarde. Les 6 légendaires sont dans legendary_items_test.
## godot --headless --path game res://tests/item_effects_test.tscn   (RESULT: OK)

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []
	var max_hp := 100.0
	var burning := false
	var poisoned := false
	var slowed := false
	var is_elite := false
	var is_boss := false

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func is_slowed() -> bool:
		return slowed

	func is_burning() -> bool:
		return burning

	func is_poisoned() -> bool:
		return poisoned

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t

	func status_data(s: StringName) -> Dictionary:
		for x in statuses:
			if x[0] == s:
				return x[1]
		return {}


## special -> où il est branché. Un `special` ajouté à items.json sans entrée ici fait échouer le test.
const HANDLED := {
	&"piece_soin": "ItemEffects (or ramassé)", &"riposte": "ItemEffects (coup subi)", &"morsure_vorace": "ItemEffects (kill)",
	&"orbe_veille": "ItemEffects (bouclier)", &"pointe_perforante": "stat pierce -> SpellCaster",
	&"chronometre_brise": "ItemEffects (élite tuée)", &"tempete_braises": "ItemEffects (mort en brûlant)",
	&"peste_vivante": "ItemEffects (mort empoisonné)", &"bouclier_reactif": "ItemEffects.absorb_hit",
	&"faveur_marchand": "ItemEffects + Chest + ChestSession", &"phenix": "ItemEffects.try_revive",
	&"rafale_acier": "ItemEffects (sort 1)", &"coeur_chronomancien": "ItemEffects", &"couronne_echo": "ItemEffects",
	&"nova_infinie": "ItemEffects", &"moisson": "ItemEffects", &"de_pipe": "ChestSession",
}
const CHARS := [&"ardent", &"rictus", &"vigie"]
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


func _fake(pos: Vector2, in_group := true) -> FakeEnemy:
	var e := FakeEnemy.new()
	if in_group:
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


## Joueur neuf (état des effets remis à zéro) pour le personnage donné.
func _spawn(char_id: StringName) -> void:
	_clear_fakes()
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
		await get_tree().process_frame
	RunState.character = char_id
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_player.global_position = Vector2.ZERO
	_player.shield = 0.0


## Run neuve avec les items donnés ({id: n}) via RunState.add_item, puis stats appliquées comme à l'acquisition.
func _give(items: Dictionary) -> void:
	RunState.start_run(&"moyen", 777)
	RunState.level = 1
	for id in items:
		for i in int(items[id]):
			RunState.add_item(StringName(id))
	_player.apply_stats(ItemStats.compute(RunState.items))
	_player.hp = _player.max_hp


func _spell1() -> SpellData:
	return _player.spells.character.spells[0]


func _dmg(e: Node = null, crit := false) -> float:
	return _player.spells.compute_damage(_spell1(), e, crit)


func _hit(amount: float, src: Node = null) -> float:
	_player._invuln = 0.0
	var before: float = _player.hp
	_player.take_damage(amount, src)
	return before - _player.hp


func _kill(e: Node2D, elite := false) -> void:
	e.remove_from_group("enemies") # comme Enemy.deactivate, après l'émission du signal
	Events.enemy_killed.emit(e, e.global_position, 0, elite)


func _cd_slots() -> Array:
	return _player.spells.character.spells.filter(func(x): return not x.is_auto)


func _arm_cds(seconds := 20.0) -> void:
	for sp in _cd_slots():
		_player.spells.set_cooldown(sp.slot, seconds, seconds)


func _run() -> void:
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	ItemDB.reload()
	await _spawn(&"ardent")

	_cur = "données"
	print("Données")
	for id in ItemDB.all_ids():
		var it := ItemDB.get_item(id)
		var sp := str(it.get("special", "")) if it.get("special") != null else ""
		if sp == "" or sp == "null" or sp == "<null>":
			continue
		_check("%s : special « %s » branché (%s)" % [id, sp, HANDLED.get(StringName(sp), "?")], HANDLED.has(StringName(sp)))
		if sp != "pointe_perforante":
			_check("%s : special_data défini" % id, not ItemEffects.data_of(StringName(sp)).is_empty())
		_give({id: 1})
		_check("%s : acquisition RunState.add_item -> special_stacks(%s) = 1" % [id, sp], _player.special_stacks(StringName(sp)) == 1)
		_give({id: 3})
		_check("%s : 3 exemplaires cumulés" % id, _player.special_stacks(StringName(sp)) == 3)

	for ch in CHARS:
		print("== Personnage : %s ==" % ch)
		await _test_piece(ch)
		await _test_epines(ch)
		await _test_morsure(ch)
		await _test_orbe(ch)
		await _test_chronometre(ch)
		await _test_braises(ch)
		await _test_peste(ch)
		await _test_bouclier(ch)
		await _test_faveur(ch)
		await _test_phenix(ch)
		await _test_rafale(ch)
		await _test_pointe(ch)
		await _test_boss(ch)
		await _test_conditionnels(ch)
	await _test_procs()
	await _test_save_load()
	_clear_fakes()

	print("")
	print("Bilan par item :")
	for k in _results:
		print("  %-26s FAIL : %s" % [k, " | ".join(_results[k])])
	print("RESULT: ", "OK" if _fails == 0 else "FAILED (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


# --- Pièce porte-bonheur -------------------------------------------------------------

func _test_piece(ch: StringName) -> void:
	_cur = "piece_porte_bonheur"
	await _spawn(ch)
	for n in [1, 2]:
		_give({"piece_porte_bonheur": n})
		_check("[%s] pièce x%d : or gagné +%d %%" % [ch, n, n * 10], _near(_player.gold_mult(), 1.0 + 0.10 * n))
		_player.hp = _player.max_hp * 0.5
		var h0: float = _player.hp
		Events.pickup_collected.emit(&"gold", 100.0)
		var want: float = 0.0005 * n * 100.0 * _player.max_hp
		_check("[%s] pièce x%d : 100 or = +%.2f PV (%.2f)" % [ch, n, want, _player.hp - h0], _near(_player.hp - h0, want, 0.01))
		var h1: float = _player.hp
		Events.pickup_collected.emit(&"xp", 100.0)
		_check("[%s] pièce : l'XP ne soigne pas" % ch, _near(_player.hp, h1))
	_give({})
	_player.hp = _player.max_hp * 0.5
	var h2: float = _player.hp
	Events.pickup_collected.emit(&"gold", 100.0)
	_check("[%s] sans pièce : pas de soin" % ch, _near(_player.hp, h2))


# --- Épines ------------------------------------------------------------------------------

func _test_epines(ch: StringName) -> void:
	_cur = "epines"
	await _spawn(ch)
	for n in [1, 2]:
		_clear_fakes()
		_give({"epines": n})
		_player.item_fx.tick(0.6) # délai de riposte de la passe précédente
		var src := _fake(Vector2(1.0 * U, 0.0), false) # l'attaquant : pas dans le groupe, hors cibles
		var foes: Array = []
		for i in 8:
			foes.append(_fake(Vector2((2.0 + i * 0.1) * U, 0.0)))
		var far := _fake(Vector2(20.0 * U, 0.0))
		var lost := _hit(5.0, src)
		var base := Balance.player_base_damage(RunState.level)
		var hit_n := foes.filter(func(e): return e.taken.size() == 1).size()
		_check("[%s] épines x%d : %d cibles touchées (attendu %d), perte %.1f PV" % [ch, n, hit_n, 5 + 2 * (n - 1), lost], hit_n == 5 + 2 * (n - 1) and lost > 0.0)
		_check("[%s] épines x%d : 160 %% du dégât de base (%.2f vs %.2f)" % [ch, n, foes[0].total(), 1.6 * base], _near(foes[0].total(), 1.6 * base, 0.01))
		_check("[%s] épines : ennemi hors portée épargné" % ch, far.taken.is_empty())
		_hit(5.0, src)
		var again := foes.filter(func(e): return e.taken.size() >= 2).size()
		_check("[%s] épines x%d : une fois par 0,5 s" % [ch, n], again == 0)
		_player.item_fx.tick(0.6)
		_hit(5.0, src)
		again = foes.filter(func(e): return e.taken.size() >= 2).size()
		_check("[%s] épines x%d : riposte à nouveau après 0,5 s" % [ch, n], again == 5 + 2 * (n - 1))
	_clear_fakes()
	_give({})
	var src2 := _fake(Vector2(U, 0.0), false)
	var foe := _fake(Vector2(2.0 * U, 0.0))
	_hit(5.0, src2)
	_check("[%s] sans épines : pas de riposte" % ch, foe.taken.is_empty())


# --- Morsure vorace --------------------------------------------------------------------

func _test_morsure(ch: StringName) -> void:
	_cur = "morsure_vorace"
	await _spawn(ch)
	for n in [1, 2]:
		_give({"morsure_vorace": n})
		_player.hp = _player.max_hp * 0.5
		var h0: float = _player.hp
		Events.enemy_killed.emit(null, Vector2.ZERO, 0, false)
		var want: float = 0.002 * n * _player.max_hp
		_check("[%s] morsure x%d : un kill rend %.2f PV (%.2f)" % [ch, n, want, _player.hp - h0], _near(_player.hp - h0, want, 0.01))
	_give({})
	_player.hp = _player.max_hp * 0.5
	Events.enemy_killed.emit(null, Vector2.ZERO, 0, false)
	_check("[%s] sans morsure : pas de soin" % ch, _near(_player.hp, _player.max_hp * 0.5))


# --- Orbe de veille ----------------------------------------------------------------------

func _test_orbe(ch: StringName) -> void:
	_cur = "orbe_de_veille"
	await _spawn(ch)
	for n in [1, 2]:
		await _spawn(ch)
		_give({"orbe_de_veille": n})
		_player.item_fx.tick(0.1)
		var cap: float = 0.28 * n * _player.max_hp
		_check("[%s] orbe x%d : bouclier de %d %% des PV max dès l'acquisition (%.1f/%.1f)" % [ch, n, 28 * n, _player.shield, cap], _near(_player.shield, cap, 0.01))
		var lost := _hit(10.0)
		_check("[%s] orbe x%d : le bouclier encaisse (perte de PV %.2f)" % [ch, n, lost], lost < 0.001 and _player.shield < cap)
		var part: float = _player.shield
		_player.item_fx.tick(4.5)
		_check("[%s] orbe x%d : pas de reformation avant 5 s sans dégâts" % [ch, n], _near(_player.shield, part, 0.01))
		_player.item_fx.tick(0.6)
		_check("[%s] orbe x%d : reformé après 5 s (%.1f/%.1f)" % [ch, n, _player.shield, cap], _near(_player.shield, cap, 0.01))
		_hit(10.0)
		_player.item_fx.tick(3.0)
		_hit(10.0)
		_player.item_fx.tick(3.0)
		_check("[%s] orbe x%d : un nouveau coup relance le délai" % [ch, n], _player.shield < cap - 0.01)
	await _spawn(ch)
	_give({})
	_player.item_fx.tick(6.0)
	_check("[%s] sans orbe : aucun bouclier" % ch, _player.shield == 0.0)


# --- Chronomètre brisé --------------------------------------------------------------------

func _test_chronometre(ch: StringName) -> void:
	_cur = "chronometre_brise"
	await _spawn(ch)
	_give({})
	var base_cd: float = _player.spells._cooldown_of(_cd_slots()[0])
	for n in [1, 2]:
		_give({"chronometre_brise": n})
		var cd: float = _player.spells._cooldown_of(_cd_slots()[0])
		var want: float = Balance.haste_cooldown_mult(0.35 + 0.20 * (n - 1)) # hâte [0,35, 0,20] : 1 / (1 + H)
		_check("[%s] chronomètre x%d : recharge x%.4f (%.2f -> %.2f)" % [ch, n, want, base_cd, cd], _near(cd, base_cd * want, 0.01))
		_arm_cds()
		Events.enemy_killed.emit(null, Vector2.ZERO, 0, false)
		var plain := _cd_slots().all(func(s): return _near(_player.spells.cooldown_remaining(s.slot), 20.0, 0.001))
		_check("[%s] chronomètre : un monstre normal ne rend rien" % ch, plain)
		Events.enemy_killed.emit(null, Vector2.ZERO, 0, true)
		var refund: float = 0.5 + 0.25 * (n - 1) # 0,5 s puis +0,25 s par exemplaire supplémentaire
		var okc := _cd_slots().all(func(s): return _near(_player.spells.cooldown_remaining(s.slot), 20.0 - refund, 0.001))
		_check("[%s] chronomètre x%d : élite tuée = %.2f s rendues à tous les sorts" % [ch, n, refund], okc)
	_give({})
	_arm_cds()
	Events.enemy_killed.emit(null, Vector2.ZERO, 0, true)
	_check("[%s] sans chronomètre : élite tuée ne rend rien" % ch, _cd_slots().all(func(s): return _near(_player.spells.cooldown_remaining(s.slot), 20.0, 0.001)))


# --- Tempête de braises ---------------------------------------------------------------------

func _test_braises(ch: StringName) -> void:
	_cur = "tempete_de_braises"
	await _spawn(ch)
	for n in [1, 2]:
		_clear_fakes()
		_give({"tempete_de_braises": n})
		var dying := _fake(Vector2.ZERO)
		dying.burning = true
		dying.max_hp = 100.0 # sous le plafond Balance.BLAST_HP_CAP_HITS (12 coups de base = 144 au niveau 1)
		var near: Array = []
		for i in 6:
			near.append(_fake(Vector2((1.0 + i * 0.2) * U, 0.0)))
		var far := _fake(Vector2(15.0 * U, 0.0))
		_kill(dying)
		_player.item_fx.tick(0.016)
		var hit_n := near.filter(func(e): return e.taken.size() == 1).size()
		_check("[%s] braises x%d : 4 ennemis proches touchés (%d)" % [ch, n, hit_n], hit_n == 4)
		_check("[%s] braises x%d : %d %% des PV max du mort (%.1f)" % [ch, n, 30 * n, near[0].total()], _near(near[0].total(), 100.0 * 0.30 * n, 0.01))
		_check("[%s] braises : les plus proches d'abord, hors portée épargné" % ch, near[3].taken.size() == 1 and near[4].taken.is_empty() and far.taken.is_empty())
		_clear_fakes()
		var calm := _fake(Vector2.ZERO)
		var other := _fake(Vector2(U, 0.0))
		_kill(calm)
		_player.item_fx.tick(0.016)
		_check("[%s] braises : un monstre qui ne brûle pas n'explose pas" % ch, other.taken.is_empty())
	_clear_fakes()
	_give({})
	var d2 := _fake(Vector2.ZERO)
	d2.burning = true
	var o2 := _fake(Vector2(U, 0.0))
	_kill(d2)
	_player.item_fx.tick(0.016)
	_check("[%s] sans braises : pas d'explosion" % ch, o2.taken.is_empty())
	# Plafond d'une brute (monstre ordinaire à PV énormes) : BLAST_HP_CAP_HITS coups de dégât de base.
	_clear_fakes()
	_give({"tempete_de_braises": 1})
	var big := _fake(Vector2.ZERO)
	big.burning = true
	big.max_hp = 1.0e6
	var victim := _fake(Vector2(U, 0.0))
	_kill(big)
	_player.item_fx.tick(0.016)
	var cap_brute := Balance.BLAST_HP_CAP_HITS * Balance.player_base_damage(RunState.level)
	_check("[%s] braises : brute plafonnée à %.0f coups de base (%.1f)" % [ch, Balance.BLAST_HP_CAP_HITS, victim.total()], _near(victim.total(), cap_brute * 0.30, 0.01))
	# Réaction en chaîne : un voisin qui brûle meurt de l'explosion et explose à son tour, étalé sur les images (pas de récursion).
	_clear_fakes()
	_give({"tempete_de_braises": 1})
	var a := _fake(Vector2.ZERO)
	a.burning = true
	var b := _fake(Vector2(U, 0.0))
	var c := _fake(Vector2(2.5 * U, 0.0))
	_kill(a)
	_player.item_fx.tick(0.016)
	_check("[%s] braises : l'explosion atteint B" % ch, b.taken.size() == 1 and c.taken.size() == 1)
	_check("[%s] braises : au plus %d explosions par image" % [ch, ItemEffects.MAX_BLASTS_PER_TICK], ItemEffects.MAX_BLASTS_PER_TICK >= 1)


# --- Peste vivante ------------------------------------------------------------------------------

func _test_peste(ch: StringName) -> void:
	_cur = "peste_vivante"
	await _spawn(ch)
	for n in [1, 2]:
		_clear_fakes()
		_give({"peste_vivante": n})
		var dying := _fake(Vector2.ZERO)
		dying.poisoned = true
		dying.max_hp = 100.0 # sous le plafond (144 PV au niveau 1)
		var near: Array = []
		for i in 6:
			near.append(_fake(Vector2((1.0 + i * 0.2) * U, 0.0)))
		_kill(dying)
		_player.item_fx.tick(0.016)
		var hit_n := near.filter(func(e): return e.taken.size() == 1).size()
		_check("[%s] peste x%d : 4 ennemis proches touchés (%d)" % [ch, n, hit_n], hit_n == 4)
		_check("[%s] peste x%d : 25 %% des PV max (fixe, %.1f)" % [ch, n, near[0].total()], _near(near[0].total(), 25.0, 0.01))
		var pd: Dictionary = near[0].status_data(&"poison")
		var want := 1.8 * Balance.player_base_damage(RunState.level)
		_check("[%s] peste x%d : 1 cumul de poison (%.2f vs %.2f)" % [ch, n, float(pd.get("total", 0.0)), want], _near(float(pd.get("total", 0.0)), want, 0.01) and float(pd.get("duration", 0.0)) == 4.0)
		_check("[%s] peste : le 5e voisin épargné" % ch, near[4].taken.is_empty() and near[4].statuses.is_empty())
	_clear_fakes()
	_give({"peste_vivante": 1})
	var calm := _fake(Vector2.ZERO)
	var other := _fake(Vector2(U, 0.0))
	_kill(calm)
	_player.item_fx.tick(0.016)
	_check("[%s] peste : un monstre sain ne libère rien" % ch, other.taken.is_empty())


# --- Bouclier réactif ---------------------------------------------------------------------------

func _test_bouclier(ch: StringName) -> void:
	_cur = "bouclier_reactif"
	await _spawn(ch)
	_give({"bouclier_reactif": 1})
	_check("[%s] bouclier : 2 charges à l'acquisition" % ch, _player.item_fx.shield_charges() == 2)
	_check("[%s] bouclier : coup 1 annulé" % ch, _hit(10.0) == 0.0)
	_check("[%s] bouclier : coup 2 annulé" % ch, _hit(10.0) == 0.0 and _player.item_fx.shield_charges() == 0)
	_check("[%s] bouclier : coup 3 passe" % ch, _hit(10.0) > 0.0)
	_player.item_fx.tick(3.3)
	_check("[%s] bouclier : pas de charge avant 3,4 s" % ch, _player.item_fx.shield_charges() == 0)
	_player.item_fx.tick(0.2)
	_check("[%s] bouclier : une charge après 3,4 s" % ch, _player.item_fx.shield_charges() == 1)
	_check("[%s] bouclier : la charge revenue annule un coup" % ch, _hit(10.0) == 0.0)
	_player.item_fx.tick(3.5)
	_player.item_fx.tick(3.5)
	_check("[%s] bouclier : retour à 2 charges, sans dépasser" % ch, _player.item_fx.shield_charges() == 2)
	_player._invuln = 0.0
	_player.take_damage(10.0, null)
	_player.take_damage(10.0, null) # coup simultané : le répit protège la 2e charge
	_check("[%s] bouclier : coups simultanés ne vident pas les 2 charges" % ch, _player.item_fx.shield_charges() == 1)
	# vitesse de recharge : Sablier fêlé (hâte 0,10 : x1/1,1)
	await _spawn(ch)
	_give({"bouclier_reactif": 1, "sablier_fele": 1})
	_hit(0.0)
	_player.item_fx.absorb_hit()
	_player.item_fx.absorb_hit()
	_player.item_fx.tick(3.05)
	_check("[%s] bouclier : recharge affectée par le Sablier (3,4 / 1,1 = 3,09 s)" % ch, _player.item_fx.shield_charges() == 0)
	_player.item_fx.tick(0.1)
	_check("[%s] bouclier : une charge après 3,09 s" % ch, _player.item_fx.shield_charges() == 1)
	# plancher (bogue de l'audit du 28/10/2026) : 10 Chronomètres + 3 Boucliers -> jamais sous 1,2 s
	await _spawn(ch)
	_give({"bouclier_reactif": 3, "chronometre_brise": 10})
	_check("[%s] bouclier : cooldown_mult au plancher (%.3f)" % [ch, _player.stat(&"cooldown_mult")], _near(_player.stat(&"cooldown_mult"), Balance.COOLDOWN_FLOOR, 0.001))
	_hit(0.0)
	_player.item_fx.absorb_hit()
	_player.item_fx.absorb_hit()
	_player.item_fx.tick(1.1)
	_check("[%s] bouclier : pas de charge avant 1,2 s (plancher absolu)" % ch, _player.item_fx.shield_charges() == 0)
	_player.item_fx.tick(0.15)
	_check("[%s] bouclier : une charge après 1,2 s" % ch, _player.item_fx.shield_charges() == 1)
	_give({})
	await _spawn(ch)
	_give({})
	_check("[%s] sans bouclier : le coup passe" % ch, _hit(10.0) > 0.0)


# --- Faveur du marchand -------------------------------------------------------------------------

func _test_faveur(ch: StringName) -> void:
	_cur = "faveur_du_marchand"
	await _spawn(ch)
	_give({"faveur_du_marchand": 1})
	_check("[%s] faveur : Chance +1" % ch, _near(_player.luck(), 1.0))
	_check("[%s] faveur : prix des coffres x0,85" % ch, _near(ItemEffects.chest_price_mult(), 0.85, 0.0001))
	var chest := (load("res://scenes/chests/chest.tscn") as PackedScene).instantiate() as Chest
	chest.setup(&"petit", 1)
	get_tree().root.add_child(chest)
	var want := Balance.chest_price(&"petit", RunState.difficulty(), 1) * 0.85
	_check("[%s] faveur : Chest.current_price = %.2f (%.2f)" % [ch, want, chest.current_price()], _near(chest.current_price(), want, 0.01))
	chest.queue_free()
	RunState.gold = 0.0
	var s1 := ChestSession.new(&"petit", 1, 100.0)
	s1.start()
	_check("[%s] faveur : 1re relance à l'or gratuite (prix %.1f)" % [ch, s1.gold_reroll_price()], s1.gold_reroll_price() == 0.0 and s1.can_gold_reroll())
	var g0 := RunState.gold
	_check("[%s] faveur : relance effectuée sans or" % ch, s1.do_gold_reroll() and _near(RunState.gold, g0))
	_check("[%s] faveur : 2e relance payante (%.1f)" % [ch, s1.gold_reroll_price()], s1.gold_reroll_price() > 0.0 and not s1.can_gold_reroll())
	var s2 := ChestSession.new(&"petit", 1, 100.0)
	_check("[%s] faveur : autre coffre du même étage = payant" % ch, s2.gold_reroll_price() > 0.0)
	var s3 := ChestSession.new(&"petit", 2, 100.0)
	_check("[%s] faveur : nouvel étage = gratuite à nouveau" % ch, s3.gold_reroll_price() == 0.0)
	_check("[%s] faveur : libellé « Gratuite » à prix nul, prix sinon" % ch, ChestUI.gold_button_text(0.0).ends_with("Gratuite") and ChestUI.gold_button_text(s2.gold_reroll_price()).ends_with(" or") and not ChestUI.gold_button_text(12.2).contains("Gratuite"))
	_give({"faveur_du_marchand": 2})
	_check("[%s] faveur x2 : prix x0,7225" % ch, _near(ItemEffects.chest_price_mult(), 0.7225, 0.0001))
	_give({})
	_check("[%s] sans faveur : prix normal, relance payante" % ch, ItemEffects.chest_price_mult() == 1.0 and ChestSession.new(&"petit", 1, 100.0).gold_reroll_price() > 0.0)


# --- Phénix de poche -----------------------------------------------------------------------------

func _test_phenix(ch: StringName) -> void:
	_cur = "phenix_de_poche"
	for n in [1, 2]:
		await _spawn(ch)
		_give({"phenix_de_poche": n})
		var deaths := [0]
		var c := func() -> void: deaths[0] += 1
		Events.player_died.connect(c)
		for k in n:
			_player.hp = 1.0
			_hit(50.0)
			_check("[%s] phénix x%d : mort %d évitée, PV à 50 %% (%.1f/%.1f)" % [ch, n, k + 1, _player.hp, _player.max_hp], not _player.dead and _near(_player.hp, _player.max_hp * 0.5, 0.01))
			_check("[%s] phénix : répit après la résurrection" % ch, _player.is_invulnerable())
		_check("[%s] phénix x%d : usage compté (%d)" % [ch, n, int(RunState.counters.get("phenix_used", 0))], int(RunState.counters.get("phenix_used", 0)) == n and _player.item_fx.revives_left() == 0)
		_player.hp = 1.0
		_hit(50.0)
		_check("[%s] phénix x%d : à court de charges, le joueur meurt" % [ch, n], _player.dead and deaths[0] == 1)
		Events.player_died.disconnect(c)
	await _spawn(ch)
	_give({})
	_player.hp = 1.0
	_hit(50.0)
	_check("[%s] sans phénix : mort" % ch, _player.dead)


# --- Rafale d'acier ------------------------------------------------------------------------------

## Lancers du sort 1 réellement émis (spell_cast) pour `casts` tirs principaux, rejeux d'écho/rafale compris.
func _auto_casts(casts: int) -> int:
	_clear_fakes()
	_fake(Vector2(2.0 * U, 0.0))
	var sp: SpellCaster = _player.spells
	var box := [0]
	var cb := func(_s: SpellData) -> void: box[0] += 1
	sp.spell_cast.connect(cb)
	for i in casts:
		sp.set_cooldown(_spell1().slot, 0.0, 1.0)
		sp.cast(_spell1().slot)
		sp.flush_pending()
		_player.item_fx.tick(0.02)
		_player.item_fx.tick(0.6)
	sp.spell_cast.disconnect(cb)
	return box[0]


func _auto_shots(casts: int) -> int:
	_clear_fakes()
	_fake(Vector2(3.0 * U, 0.0))
	var sp: SpellCaster = _player.spells
	for p in sp.get("_pool"):
		p.active = false
	sp.flush_pending()
	for i in casts:
		sp.set_cooldown(_spell1().slot, 0.0, 1.0)
		sp.cast(_spell1().slot)
		sp.flush_pending()
		_player.item_fx.tick(0.02)
		_player.item_fx.tick(0.6)
	return sp.active_projectile_count()


func _test_rafale(ch: StringName) -> void:
	_cur = "rafale_d_acier"
	var rd: Dictionary = ItemDB.get_item(&"rafale_d_acier")
	var every := int((rd.get("special_data", {}) as Dictionary).get("every", 5))
	var aspd := float((rd.get("stats", {}) as Dictionary).get("attack_speed", 0.15))
	await _spawn(ch)
	_give({})
	var plain := _auto_shots(every)
	await _spawn(ch)
	_give({"rafale_d_acier": 1})
	_check("[%s] rafale : +%d %% de vitesse d'attaque" % [ch, roundi(aspd * 100.0)], _near(_player.stat(&"attack_speed"), aspd))
	var proj := _spell1().behavior == SpellData.Behavior.PROJECTILE
	var shots := _auto_shots(every)
	var shots3 := _auto_shots(every - 1)
	if proj:
		var per_shot := plain / every
		_check("[%s] rafale : %d tirs = %d projectiles de base + 2 en plus (%d)" % [ch, every, plain, shots], shots == plain + 2)
		_check("[%s] rafale : %d tirs suivants = pas de rafale (%d projectiles)" % [ch, every - 1, shots3], shots3 == plain - per_shot)
		await _spawn(ch)
		_give({"rafale_d_acier": 1})
		var shots8 := _auto_shots(2 * every)
		_check("[%s] rafale : %d tirs = 2 rafales (%d vs %d)" % [ch, 2 * every, shots8, 2 * plain + 4], shots8 == 2 * plain + 4)
	else:
		# Kit : pas d'éventail ; 2 rejeux du sort tous les `every` tirs (même mécanisme que la Couronne d'écho).
		await _spawn(ch)
		_give({})
		var c_plain := _auto_casts(every)
		await _spawn(ch)
		_give({"rafale_d_acier": 1})
		var c4 := _auto_casts(every)
		await _spawn(ch)
		_give({"rafale_d_acier": 1})
		var c3 := _auto_casts(every - 1)
		await _spawn(ch)
		_give({"rafale_d_acier": 1})
		var c8 := _auto_casts(2 * every)
		_check("[%s] rafale (kit) : %d tirs = %d lancers + 2 rejeux (%d)" % [ch, every, c_plain, c4], c_plain == every and c4 == every + 2)
		_check("[%s] rafale (kit) : %d tirs = pas de rafale (%d)" % [ch, every - 1, c3], c3 == every - 1)
		_check("[%s] rafale (kit) : %d tirs = 2 rafales (%d)" % [ch, 2 * every, c8], c8 == 2 * every + 4)
	print("   (%s : sort 1 comportement %s, %d/%d projectiles)" % [ch, _spell1().behavior, shots, shots3])
	_clear_fakes()


# --- Mort d'un boss (boss_killed, jamais enemy_killed) ---------------------------------------------

func _kill_boss(e: Node2D, floor_boss := false) -> void:
	e.remove_from_group("enemies")
	Events.boss_killed.emit(e, floor_boss)


func _test_boss(ch: StringName) -> void:
	_cur = "boss_killed"
	await _spawn(ch)
	var boss := _fake(Vector2.ZERO)
	boss.is_boss = true
	boss.add_to_group("bosses")
	_give({"morsure_vorace": 1})
	_player.hp = _player.max_hp * 0.5
	var h0: float = _player.hp
	_kill_boss(boss)
	_check("[%s] boss : morsure vorace soigne (%.2f)" % [ch, _player.hp - h0], _near(_player.hp - h0, 0.002 * _player.max_hp, 0.01))
	_give({"chronometre_brise": 1})
	_arm_cds()
	_kill_boss(_fake(Vector2.ZERO), true)
	_check("[%s] boss : chronomètre rend 0,5 s (comme une élite)" % ch, _cd_slots().all(func(s): return _near(_player.spells.cooldown_remaining(s.slot), 19.5, 0.001)))
	# Braises et peste : explosion plafonnée (BOSS_BLAST_HITS coups de dégât de base) autour d'un boss à PV énormes.
	for item in ["tempete_de_braises", "peste_vivante"]:
		_clear_fakes()
		_give({item: 1})
		var b := _fake(Vector2.ZERO)
		b.is_boss = true
		b.add_to_group("bosses")
		b.max_hp = 1.0e9
		if item == "tempete_de_braises":
			b.burning = true
		else:
			b.poisoned = true
		var near := _fake(Vector2(U, 0.0))
		_kill_boss(b)
		_player.item_fx.tick(0.016)
		var cap := ItemEffects.BOSS_BLAST_HITS * Balance.player_base_damage(RunState.level)
		var pct := 0.3 if item == "tempete_de_braises" else 0.25
		_check("[%s] boss : %s explose, dégâts plafonnés (%.1f)" % [ch, item, near.total()], near.taken.size() == 1 and _near(near.total(), cap * pct, 0.01))
	_clear_fakes()
	_give({"moisson": 1})
	var m0: float = RunState.counters.get(ItemEffects.COUNTER_MOISSON, 0)
	_kill_boss(_fake(Vector2.ZERO))
	_check("[%s] boss : moisson compte la mort" % ch, float(RunState.counters.get(ItemEffects.COUNTER_MOISSON, 0)) == m0 + 1.0)
	_give({"coeur_du_chronomancien": 1})
	_arm_cds()
	for i in 9:
		Events.enemy_killed.emit(null, Vector2.ZERO, 0, false)
	_kill_boss(_fake(Vector2.ZERO))
	_check("[%s] boss : 10e mort = boss, cœur du chronomancien remet un sort à zéro" % ch, _cd_slots().any(func(s): return _player.spells.cooldown_remaining(s.slot) < 0.001))
	_clear_fakes()


# --- Pointe perforante ---------------------------------------------------------------------------

func _test_pointe(ch: StringName) -> void:
	_cur = "pointe_perforante"
	await _spawn(ch)
	for n in [0, 1, 3, 8]:
		_give({"pointe_perforante": n} if n > 0 else {})
		var want := mini(n, Balance.PIERCE_CAP)
		_check("[%s] pointe x%d : stat pierce = %d (plafond %d)" % [ch, n, int(_player.stat(&"pierce")), Balance.PIERCE_CAP], int(_player.stat(&"pierce")) == want)
	if _spell1().behavior != SpellData.Behavior.PROJECTILE:
		return
	_give({"pointe_perforante": 2})
	_clear_fakes()
	var foe := _fake(Vector2(3.0 * U, 0.0))
	var sp: SpellCaster = _player.spells
	for p in sp.get("_pool"):
		p.active = false
	sp.fire_at(_spell1(), foe, Vector2.RIGHT)
	var hits := 0
	for p in sp.get("_pool"):
		if p.active:
			hits = p.hits_left
	var expect := 1 + _spell1().pierce + (2 if _spell1().item_pierce else 0)
	_check("[%s] pointe x2 : le projectile peut toucher %d cibles (attendu %d)" % [ch, hits, expect], hits == expect)
	_clear_fakes()


# --- Effets conditionnels portés par des stats (code dans SpellCaster / Player) ------------------

func _test_conditionnels(ch: StringName) -> void:
	_cur = "conditionnels"
	await _spawn(ch)
	_give({})
	var d0 := _dmg()
	var slowed := _fake(Vector2(U, 0.0))
	slowed.slowed = true
	var elite := _fake(Vector2(U, 0.0))
	elite.is_elite = true
	_give({"coeur_de_glace": 1})
	_check("[%s] cœur de glace : +35 %% sur cible ralentie" % ch, _near(_dmg(slowed), d0 * 1.35, d0 * 0.01) and _near(_dmg(elite), d0, d0 * 0.01))
	_give({"coeur_de_glace": 2})
	_check("[%s] cœur de glace x2 : +50 %%" % ch, _near(_dmg(slowed), d0 * 1.5, d0 * 0.01))
	_give({"marque_du_chasseur": 1})
	_check("[%s] marque du chasseur : +30 %% sur élite seulement" % ch, _near(_dmg(elite), d0 * 1.3, d0 * 0.01) and _near(_dmg(slowed), d0, d0 * 0.01))
	_give({"sang_chaud": 1})
	_check("[%s] sang chaud : rien à PV pleins" % ch, _near(_dmg(), d0, d0 * 0.01))
	_player.hp = _player.max_hp * 0.3
	_check("[%s] sang chaud : +40 %% sous 35 %% de PV" % ch, _near(_dmg(), d0 * 1.4, d0 * 0.01))
	_give({"danseur": 1})
	_player.is_moving = false
	_check("[%s] danseur : rien à l'arrêt" % ch, _near(_dmg(), d0, d0 * 0.01))
	_player.is_moving = true
	_check("[%s] danseur : +35 %% en mouvement" % ch, _near(_dmg(), d0 * 1.35, d0 * 0.01))
	_player.is_moving = false
	_give({"oeil_du_predateur": 1})
	_check("[%s] œil du prédateur : critique x2,4" % ch, _near(_player.crit_mult(), 2.4))
	_give({"antidote": 1})
	_check("[%s] antidote : DoT subis -20 %% (hyperbolique, 1 exemplaire)" % ch, _near(_player.stat(&"dot_taken_reduction"), 0.2, 0.001))
	if _cd_slots().size() > 0:
		var cd: SpellData = _cd_slots()[0]
		_give({})
		var c0: float = _player.spells.compute_damage(cd, null, false)
		_give({"horloge_arcanique": 1})
		_check("[%s] horloge : +10 %% de dégâts des sorts à recharge, pas du sort 1" % ch, _near(_player.spells.compute_damage(cd, null, false), c0 * 1.1, c0 * 0.005) and _near(_dmg(), d0, d0 * 0.005))
	_clear_fakes()


# --- Procs de statuts ---------------------------------------------------------------------------

func _count_status(status: StringName, item: String, n: int, tries: int) -> int:
	_give({item: n})
	var e := _fake(Vector2(2.0 * U, 0.0))
	for i in tries:
		_player.spells.deal_damage(e, _spell1())
	var c := 0
	for x in e.statuses:
		if x[0] == status:
			c += 1
	_clear_fakes()
	return c


func _test_procs() -> void:
	_cur = "procs"
	print("Procs de statuts (Ardent)")
	await _spawn(&"ardent")
	_give({})
	_check("sans item : aucun statut", _count_status(&"burn", "", 0, 50) == 0)
	_check("étincelle : brûlure (10 %%)", _count_status(&"burn", "etincelle", 1, 400) > 10)
	_check("fiole verte : poison (5 %%)", _count_status(&"poison", "fiole_verte", 1, 600) > 5)
	_check("flocon : ralentissement", _count_status(&"slow", "flocon", 1, 400) > 10)
	_check("cristal de feu : brûlure", _count_status(&"burn", "cristal_de_feu", 1, 400) > 10)
	_check("venin concentré : poison", _count_status(&"poison", "venin_concentre", 1, 400) > 10)
	_give({"givre": 2})
	var e := _fake(Vector2(2.0 * U, 0.0))
	_player.spells.deal_damage(e, _spell1())
	var sd: Dictionary = e.status_data(&"slow")
	_check("givre x2 : chaque coup ralentit 40 %% pendant 4 s (%s)" % str(sd), _near(float(sd.get("pct", 0.0)), 0.4) and _near(float(sd.get("duration", 0.0)), 4.0))
	_clear_fakes()
	_give({"eclair_en_bouteille": 1})
	var v := _fake(Vector2(2.0 * U, 0.0))
	var chain := [_fake(Vector2(3.0 * U, 0.0)), _fake(Vector2(3.0 * U, U)), _fake(Vector2(3.0 * U, -U)), _fake(Vector2(3.5 * U, 0.0))]
	for i in 200:
		_player.spells.deal_damage(v, _spell1())
	var struck := chain.filter(func(x): return x.taken.size() > 0).size()
	_check("éclair en bouteille : foudre sur les voisins (%d touchés)" % struck, struck >= 3)
	_clear_fakes()
	await _test_chain_lightning()


## Foudre en chaîne (Ukulele RoR2) : cibles 3 / 5 / 7, rebond de proche en proche, jamais deux fois, 80 %, portée.
func _test_chain_lightning() -> void:
	print("Éclair en bouteille : chaîne")
	for n in [1, 2, 3]:
		_give({"eclair_en_bouteille": n})
		var data: Dictionary = _player.procs[0]["data"]
		var want: int = 3 + 2 * (int(n) - 1)
		_check("chaîne x%d : %d cibles prévues" % [n, want], int(data.get("targets", 0)) == want)
		var v := _fake(Vector2(2.0 * U, 0.0))
		var line: Array = []
		for i in 12: # ligne courbe, pas de 3 u (< portée 5 u), l'ordre de création est mélangé
			var a := float(i) * 0.35
			line.append(_fake(Vector2((5.0 + 3.0 * i * cos(a * 0.4)) * U, 3.0 * i * sin(a * 0.4) * U)))
		line.shuffle()
		var reach: float = (Balance.CHAIN_LIGHTNING_RANGE_U + Balance.CHAIN_LIGHTNING_RANGE_STACK_U * float(int(n) - 1)) * U
		var ch: Array = _player.spells.chain_targets(v, want, reach)
		_check("chaîne x%d : %d cibles prises" % [n, want], ch.size() == want)
		var ok := true
		var prev: Node2D = v
		var seen := {}
		for e in ch:
			if e.global_position.distance_to(prev.global_position) > reach + 0.01 or seen.has(e) or e == v:
				ok = false
			seen[e] = true
			prev = e
		_check("chaîne x%d : chaque cible à ≤ portée de la précédente, jamais deux fois" % n, ok)
		var zaps0 := ChainLightningFx.zaps_played
		_player.spells._lightning(v, 100.0, data)
		await get_tree().create_timer(0.3).timeout
		_check("chaîne x%d : %d zaps sonores (un par impact)" % [n, want], ChainLightningFx.zaps_played - zaps0 >= want)
		var hits := 0
		var dmg_ok := true
		for e in line:
			if e.taken.size() > 0:
				hits += 1
				if e.taken.size() != 1 or not _near(e.taken[0], 80.0):
					dmg_ok = false
		_check("chaîne x%d : %d touchés, 80 %% du coup, un seul coup chacun (pas de re-proc)" % [n, want], hits == want and dmg_ok and v.taken.is_empty())
		_clear_fakes()
	# portée : 5,2 u d'écart = hors de portée à 1 exemplaire, atteint à 2 (5,5 u)
	_give({"eclair_en_bouteille": 1})
	var v1 := _fake(Vector2.ZERO)
	_fake(Vector2(5.2 * U, 0.0))
	_check("portée x1 : 5,2 u hors de portée", _player.spells.chain_targets(v1, 3, 5.0 * U).is_empty())
	_check("portée x2 : 5,2 u atteint", _player.spells.chain_targets(v1, 3, 5.5 * U).size() == 1)
	_clear_fakes()


# --- Sauvegarde ----------------------------------------------------------------------------------

func _test_save_load() -> void:
	_cur = "sauvegarde"
	print("Sauvegarde de run")
	await _spawn(&"rictus")
	_give({"phenix_de_poche": 2, "orbe_de_veille": 1, "bouclier_reactif": 1, "faveur_du_marchand": 1, "epines": 1,
		"piece_porte_bonheur": 1, "morsure_vorace": 1, "chronometre_brise": 1, "tempete_de_braises": 1, "peste_vivante": 1})
	_player.item_fx.absorb_hit() # charges du bouclier et orbe épuisés : le coup mortel arrive jusqu'au phénix
	_player.item_fx.absorb_hit()
	_player.shield = 0.0
	_player.hp = 1.0
	_hit(50.0) # un phénix consommé
	var s1 := ChestSession.new(&"petit", 1, 100.0)
	s1.start()
	s1.do_gold_reroll() # relance gratuite de l'étage 1 consommée
	var json := JSON.stringify(RunState.to_dict())
	RunState.start_run(&"moyen", 1)
	await _spawn(&"rictus") # nouvelle scène, run vierge
	RunState.from_dict(JSON.parse_string(json))
	_player.apply_stats(ItemStats.compute(RunState.items)) # comme main._restore
	_player.hp = _player.max_hp
	_cur = "phenix_de_poche"
	_check("[load] phénix : 1 charge restante sur 2", _player.item_fx.revives_left() == 1)
	_player.item_fx.absorb_hit()
	_player.item_fx.absorb_hit()
	_player.shield = 0.0
	_player.hp = 1.0
	_hit(50.0)
	_check("[load] phénix : ressuscite encore une fois", not _player.dead)
	_player.hp = 1.0
	_player._invuln = 0.0
	_hit(50.0)
	_check("[load] phénix : puis meurt", _player.dead)
	await _spawn(&"rictus")
	RunState.from_dict(JSON.parse_string(json))
	_player.apply_stats(ItemStats.compute(RunState.items))
	_cur = "orbe_de_veille"
	_player.item_fx.tick(0.1)
	_check("[load] orbe : bouclier présent après chargement (%.1f)" % _player.shield, _player.shield > 0.0)
	_cur = "bouclier_reactif"
	_check("[load] bouclier réactif : 2 charges", _player.item_fx.shield_charges() == 2)
	_cur = "faveur_du_marchand"
	_check("[load] faveur : relance gratuite déjà prise à l'étage 1", ChestSession.new(&"petit", 1, 100.0).gold_reroll_price() > 0.0)
	_check("[load] faveur : étage 2 gratuit", ChestSession.new(&"petit", 2, 100.0).gold_reroll_price() == 0.0)
	_check("[load] faveur : prix x0,85 et Chance +1", _near(ItemEffects.chest_price_mult(), 0.85) and _near(_player.luck(), 1.0))
	_cur = "piece_porte_bonheur"
	_player.hp = _player.max_hp * 0.5
	var h0: float = _player.hp
	Events.pickup_collected.emit(&"gold", 100.0)
	_check("[load] pièce : soigne", _player.hp > h0)
	_cur = "morsure_vorace"
	h0 = _player.hp
	Events.enemy_killed.emit(null, Vector2.ZERO, 0, false)
	_check("[load] morsure : soigne", _player.hp > h0)
	_cur = "epines"
	var src := _fake(Vector2(U, 0.0), false)
	var foe := _fake(Vector2(2.0 * U, 0.0))
	_player.shield = 0.0
	_player.item_fx.absorb_hit()
	_player.item_fx.absorb_hit()
	_hit(5.0, src)
	_check("[load] épines : riposte", foe.taken.size() == 1)
	_cur = "chronometre_brise"
	_arm_cds()
	Events.enemy_killed.emit(null, Vector2.ZERO, 0, true)
	_check("[load] chronomètre : élite = 0,5 s rendue", _cd_slots().all(func(s): return _near(_player.spells.cooldown_remaining(s.slot), 19.5, 0.001)))
	_cur = "tempete_de_braises"
	_clear_fakes()
	var burn := _fake(Vector2.ZERO)
	burn.burning = true
	var nb := _fake(Vector2(U, 0.0))
	_kill(burn)
	_player.item_fx.tick(0.016)
	_check("[load] braises : explosion", nb.taken.size() == 1)
	_cur = "peste_vivante"
	_clear_fakes()
	var pz := _fake(Vector2.ZERO)
	pz.poisoned = true
	var np := _fake(Vector2(U, 0.0))
	_kill(pz)
	_player.item_fx.tick(0.016)
	_check("[load] peste : nuage", np.taken.size() == 1)
	_clear_fakes()
