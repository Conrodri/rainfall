extends Node
## Étage 1 (Terrasses noyées) : les 3 boss d'étage ont chacun leur IA, et la MÉMOIRE DES BOSS ×0,5.
## godot --headless --path game res://tests/floor1_boss_test.tscn  -> RESULT: OK
## 1. data/floors.json : étage 1 = eclusier, ox_herder, jar_bearer ; chacun, lancé par le Director avec la carte
##    des Terrasses, reçoit son cerveau (EclusierBrain / OxHerderBrain / JarBearerBrain, plus jamais l'IA
##    générique), meurt proprement (IA libérée) ;
## 2. mémoire de profil (Design_Etages §2.2, §6.2) : chaque apparition de boss d'étage est notée dans
##    Profile.last_floor_boss[étage] ; poids Balance.BOSS_MEMORY_WEIGHT (0,5) pour le dernier vu, 1 sinon ;
##    persistance (fichier de profil de TEST, aller-retour JSON) ;
## 3. tirage FloorPlan.pick_floor_boss : 20 000 tirages, fréquence du boss mémorisé ≈ 0,5 / 2,5 = 20 %, des
##    autres ≈ 40 % ; sans mémoire (ou boss mémorisé hors liste) : tirage identique à l'uniforme d'origine
##    (mêmes nombres, plans des seeds existantes inchangés) ; build() accepte la mémoire et reste déterministe.
## Profil réel jamais écrit (write_enabled coupé, chemin de test restauré).

const MAP := "res://scenes/stage/maps/terrasses_noyees.tscn"
const SAVE := "user://test_floor1_boss.json"
const PROFILE_TEST := "user://test_profile_memory.json"
const IDS := [&"eclusier", &"ox_herder", &"jar_bearer"]
const BRAINS := {&"eclusier": "EclusierBrain", &"ox_herder": "OxHerderBrain", &"jar_bearer": "JarBearerBrain"}

var _main: Node
var _fails := 0
var _step := -1
var _t := 0.0
var _i := 0
var _boss: Enemy = null
var _saved_profile := {}


func _ready() -> void:
	Profile.write_enabled = false
	_saved_profile = Profile.last_floor_boss.duplicate()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load(MAP))
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 23)
	add_child(_main)
	_main.game_ready.connect(func() -> void: _step = 0)


func _physics_process(delta: float) -> void:
	if _step < 0 or _step == 99:
		return
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	_t += delta
	var d: Director = _main.get(&"director")
	match _step:
		0:
			d.spawning_enabled = false
			if _t > 1.2:
				var fe := FloorPlan.floor_entry(1)
				_check("floors.json : étage 1 = Éclusier, Bouvier, Porteuse", fe.get("floor_bosses", []) == ["eclusier", "ox_herder", "jar_bearer"], str(fe.get("floor_bosses")))
				RunState.stage = 1
				_next(1)
		1: # un boss par seconde : apparition, cerveau, mémoire, mort
			if _boss == null:
				var id: StringName = IDS[_i]
				(_main.get(&"stage") as StageManager).floor_boss = id
				var p: Node2D = _main.get(&"player")
				_boss = d.spawn_boss(&"etage", p.global_position + Vector2(300.0, 0.0)) as Enemy
				_check("%s : apparu avec son skin" % id, _boss != null and _boss.boss_id() == id, str(_boss.boss_id() if _boss else &""))
				var bn := String(_boss.brain.get_script().get_global_name()) if _boss != null and _boss.brain != null else "aucune (IA générique)"
				_check("%s : IA %s" % [id, BRAINS[id]], bn == BRAINS[id], bn)
				_check("%s : mémoire notée pour l'étage 1" % id, Profile.last_boss_of_floor(1) == id, str(Profile.last_floor_boss))
				_check("%s : poids 0,5 au prochain tirage, 1 pour les autres" % id, is_equal_approx(Profile.floor_boss_weight(1, id), 0.5)
					and is_equal_approx(Profile.floor_boss_weight(1, IDS[(_i + 1) % 3]), 1.0) and is_equal_approx(Profile.floor_boss_weight(2, id), 1.0))
				_t = 0.0
			elif _t > 1.0:
				_boss.take_damage(_boss.hp + 1.0)
				_check("%s : mort, IA libérée" % IDS[_i], not _boss.active and _boss.brain == null)
				_boss = null
				_i += 1
				_t = 0.0
				if _i >= IDS.size():
					_next(2)
		2:
			if _t > 0.5:
				_memory_unit()
				_persistence()
				_finish()


func _memory_unit() -> void:
	var ids := ["eclusier", "ox_herder", "jar_bearer"]
	var mem := {"1": "eclusier"}
	var w := FloorPlan.boss_weights(ids, 1, mem)
	_check("poids du tirage : [0,5 ; 1 ; 1]", Array(w) == [0.5, 1.0, 1.0], str(w))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var n := 20000
	var count := {}
	for k in n:
		var b := FloorPlan.pick_floor_boss(ids, 1, rng, mem)
		count[b] = int(count.get(b, 0)) + 1
	var fe := float(count.get("eclusier", 0)) / n
	var fo := float(count.get("ox_herder", 0)) / n
	var fj := float(count.get("jar_bearer", 0)) / n
	print("  fréquences avec mémoire (éclusier vu) : %.3f / %.3f / %.3f" % [fe, fo, fj])
	_check("boss vu la dernière fois : ×0,5 (≈ 20 %)", absf(fe - 0.2) < 0.015, "%.3f" % fe)
	_check("autres boss : ≈ 40 % chacun", absf(fo - 0.4) < 0.015 and absf(fj - 0.4) < 0.015, "%.3f %.3f" % [fo, fj])
	# sans mémoire : mêmes nombres que l'uniforme d'origine
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 99
	r2.seed = 99
	var same := true
	for k in 200:
		var a := FloorPlan.pick_floor_boss(ids, 1, r1, {} if k % 2 == 0 else {"1": "inconnu", "2": "eclusier"})
		var b: String = ids[r2.randi_range(0, ids.size() - 1)]
		if a != b:
			same = false
	_check("sans boss mémorisé à cet étage : tirage identique à l'uniforme", same)
	_check("étage d'un seul boss : la mémoire ne change rien", FloorPlan.pick_floor_boss(["rain_sower"], 5, rng, {"5": "rain_sower"}) == "rain_sower")
	var p1 := FloorPlan.build(777, {})
	var p2 := FloorPlan.build(777, {})
	var p3 := FloorPlan.build(777, {"1": "pas_un_boss"})
	_check("build(seed, mémoire) déterministe ; mémoire hors liste sans effet", p1 == p2 and p1 == p3)


func _persistence() -> void:
	var old_path := Profile.path
	Profile.path = PROFILE_TEST
	Profile.write_enabled = true
	Profile.last_floor_boss = {}
	Profile.record_floor_boss(1, &"ox_herder")
	Profile.record_floor_boss(3, &"sonneur")
	Profile.load_profile()
	_check("profil : mémoire relue du fichier (aller-retour JSON)", Profile.last_boss_of_floor(1) == &"ox_herder" and Profile.last_boss_of_floor(3) == &"sonneur", str(Profile.last_floor_boss))
	_check("profil : seul le dernier boss vu par étage", Profile.last_boss_of_floor(2) == &"")
	Profile.record_floor_boss(1, &"jar_bearer")
	_check("profil : la run suivante remplace la mémoire de l'étage", Profile.last_boss_of_floor(1) == &"jar_bearer")
	if FileAccess.file_exists(PROFILE_TEST):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_TEST))
	Profile.write_enabled = false
	Profile.path = old_path
	Profile.load_profile()
	Profile.last_floor_boss = _saved_profile


func _next(step: int) -> void:
	_step = step
	_t = 0.0


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, "  ", detail)


func _finish() -> void:
	_step = 99
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
