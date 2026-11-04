extends Node
## Outil de revue (pas un test) : capture les VRAIS sorts lancés en jeu (arène du mode test, caméra iso du jeu) avec les
## VFX de test pixelfx actifs (TestMode.vfx_test), pour vérifier pose, rotation et taille de chaque effet.
## Fenêtré (PAS --headless), toujours via le verrou partagé :
##   sh art/tools/vfx_test/godot_locked.sh res://tests/spell_cast_capture.tscn -- <options>
##
## MODE PERSONNAGE
##   --char=<id>              personnage (défaut ardent)
##   --variant=<slot>:<id>    variante de sort sur un slot (répétable, ou liste : --variant=2:flame_pillar,3:autre)
##   --slots=1,2,3,4          slots à lancer (défaut 0.8,3,4)
##   --dirs="1,0;0,-1;0,1"    directions LOGIQUES de visée (défaut 1,0;0,-1;0,1). Les monstres factices sont posés
##                            dans cette direction, à 4-6 u du joueur ; les sorts à cible partent donc dans cette direction.
##   --times=0.15,0.4,0.8     instants de capture, en s après le lancer (défaut 0.15,0.4,0.8)
##   --orig                   VFX d'origine (TestMode.vfx_test = false) au lieu des VFX de test, pour comparer
##   --out=<dossier>          dossier de sortie (défaut user://spell_cast_capture)
##   --settle=0.8             attente (s) après les captures avant le lancer suivant (effets finis) ; défaut 0.8
##   --dummy-dist=<u>         distance moyenne des factices (défaut 5 u, soit 4-6 u) ; ex. 2.5 pour la mêlée / courte portée
##   --prewalk=<u>            le joueur parcourt <u> unités (10 u/s) avant le lancer, en finissant à sa place : pose la
##                            chaîne d'Arpenteuse (sorts 1/2/4 inutilisables à l'arrêt). Départ à N u derrière, marche vers la visée.
##                            Un sort qui refuse le lancer (ex. sort 1 passif d'Arpenteuse) est alors capturé quand même
##                            (état posé par la marche) avec un message « PAS DE LANCER ».
##   --prewalk-loop           avec --prewalk : boucle carrée (côté N/4) au lieu d'un aller droit
##   --no-legend              pas de légende texte
##   Fichiers : <perso>__s<slot>[__<variante>]__d<i>__t<ms>.png  (ex. ardent__s2__d0__t0400.png)
## MODE BOSS
##   --boss=<id>              boss / mini-boss (ex. cerf, hermit_cedar, sonneur) : invoqué sans intro
##   --attack=<nom>[,<nom>]   attaque(s) : libellé ou id de TestBossAdapter (ex. marteau, auto:_start_hammer, force:slam,
##                            spell:1) ; "all" = toutes les attaques ; "list" = les affiche et quitte
##   --dirs, --times (défaut 0.5,1.2,2.5), --orig, --out, --settle (défaut 2.0), --no-legend comme ci-dessus.
##                            Le joueur est placé à 7 u du boss dans la direction demandée (le boss vise donc cette direction).
##   Fichiers : <boss>__<attaque>__d<i>__t<ms>.png
##
## Mécanique : TestMode.begin(), main.tscn, HUD et bulles masqués, PV illimités, recharge 0, portée infinie. Monstres
## factices = Poutch (TestTools.spawn_poutch : immobiles, inoffensifs, invincibles). Le lancer passe par
## SpellCaster.cast avec aim_override sur le groupe de factices (comme la bulle de sort du mode test).
## LIMITES : le sort 1 (automatique) du joueur continue de tirer tout seul pendant les captures (parasites possibles sur les autres sorts et en mode boss) ; un sort à charge ou à maintien n'est lancé qu'une fois (appui simple, pas de maintien) ; un sort dont
## cast() renvoie faux (portée, ressource) est signalé « NON LANCE » et sauté ; le nettoyage entre deux lancers est le temps
## d'attente (--settle) + retrait des factices, les zones persistantes longues peuvent déborder sur le lancer suivant
## (augmenter --settle). Attaque de boss non forçable (cerveau sans état de repos, intro) : signalée, sautée.
## À RETIRER AVEC LE MODE TEST.

const DEFAULT_TIMES_CHAR: Array[float] = [0.15, 0.4, 0.8]
const DEFAULT_TIMES_BOSS: Array[float] = [0.5, 1.2, 2.5]
const DUMMY_OFFSETS_U: Array[Vector2] = [Vector2(5.0, 0.0), Vector2(4.2, -1.3), Vector2(4.2, 1.3), Vector2(5.8, 0.6), Vector2(5.8, -0.6)] ## (avant, côté) en u

var _out := "user://spell_cast_capture"
var _char := &"ardent"
var _loadout := {}
var _slots: Array[int] = [1, 2, 3, 4]
var _dirs: Array[Vector2] = []
var _times: Array[float] = []
var _orig := false
var _settle := -1.0
var _legend := true
var _boss := ""
var _dummy_dist := 5.0
var _prewalk := 0.0
var _prewalk_loop := false
var _attacks: Array[String] = []
var _main: Node
var _label: Label
var _player_home := Vector2.ZERO
var _clock_ms := 0 ## horloge de jeu (ms) : n'avance qu'avec le temps de jeu
var _clock_acc := 0.0


func _process(delta: float) -> void:
	_clock_acc += delta * 1000.0
	_clock_ms = int(_clock_acc)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--char="):
			_char = StringName(a.substr(7))
		elif a.begins_with("--variant="):
			for kv in a.substr(10).split(",", false):
				var p := kv.split(":")
				if p.size() == 2:
					_loadout[int(p[0])] = StringName(p[1])
		elif a.begins_with("--slots="):
			_slots.clear()
			for s in a.substr(8).split(",", false):
				_slots.append(int(s))
		elif a.begins_with("--dirs="):
			for d in a.substr(7).split(";", false):
				var p := d.split(",")
				if p.size() == 2:
					_dirs.append(Vector2(float(p[0]), float(p[1])).normalized())
		elif a.begins_with("--times="):
			for t in a.substr(8).split(",", false):
				_times.append(float(t))
		elif a.begins_with("--settle="):
			_settle = float(a.substr(9))
		elif a.begins_with("--boss="):
			_boss = a.substr(7)
		elif a.begins_with("--attack="):
			for t in a.substr(9).split(",", false):
				_attacks.append(t)
		elif a.begins_with("--dummy-dist="):
			_dummy_dist = float(a.substr(13))
		elif a.begins_with("--prewalk="):
			_prewalk = float(a.substr(10))
		elif a == "--prewalk-loop":
			_prewalk_loop = true
		elif a == "--orig":
			_orig = true
		elif a == "--no-legend":
			_legend = false
	if _dirs.is_empty():
		_dirs = [Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
	if _times.is_empty():
		_times = DEFAULT_TIMES_BOSS.duplicate() if _boss != "" else DEFAULT_TIMES_CHAR.duplicate()
	if _settle < 0.0:
		_settle = 2.0 if _boss != "" else 0.8
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	Platform.set_input_mode(Platform.InputMode.KBM)
	TestMode.begin()
	RunState.character = _char
	RunState.loadout = RunState.normalize_loadout(_loadout)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_main.set(&"run_mode", &"moyen")
	_main.set(&"run_seed", 5)
	add_child(_main)
	await _main.game_ready
	await _f(30)
	TestMode.set_flag(&"god", true)
	TestMode.set_flag(&"cdr_full", true)
	TestMode.set_flag(&"inf_range", true)
	TestMode.set_flag(&"hide_hud", true)
	TestMode.set_flag(&"vfx_test", not _orig)
	if TestBubbles.instance != null:
		TestBubbles.set_shown(false)
	var ov: Node = _main.get_node_or_null("TestOverlay")
	if ov != null:
		for nm in ["hint", "launcher"]:
			var c: Variant = ov.get(nm)
			if c is CanvasItem:
				(c as CanvasItem).visible = false
	_build_legend()
	await _f(20)
	var p := TestTools.player_of(get_tree())
	if p == null:
		push_error("spell_cast_capture : joueur introuvable")
		get_tree().quit(1)
		return
	_player_home = p.global_position
	if _boss != "":
		await _run_boss(p)
	else:
		await _run_char(p)
	get_tree().quit()


# --- Légende -----------------------------------------------------------------------------

func _build_legend() -> void:
	if not _legend:
		return
	var cl := CanvasLayer.new()
	cl.layer = 200
	add_child(cl)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override(&"font_size", 28)
	_label.add_theme_color_override(&"font_color", Color(1, 1, 0.8))
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 8)
	cl.add_child(_label)


func _set_legend(txt: String) -> void:
	if _label != null:
		_label.text = txt


# --- Capture -----------------------------------------------------------------------------

## Capture à `t` s après `t0` (ms), enregistre sous `base` + "__t%04d".
func _shoot_at(t0: int, t: float, base: String, legend: String) -> void:
	var target := t0 + int(t * 1000.0)
	while _clock_ms < target:
		await get_tree().process_frame
	# le temps de jeu est figé pendant l'enregistrement : le coût de la capture ne décale pas les instants suivants
	Engine.time_scale = 0.0001
	_set_legend("%s  t=%d ms" % [legend, int(t * 1000.0)])
	await _f(2)
	await RenderingServer.frame_post_draw
	var name := "%s__t%04d.png" % [base, int(round(t * 1000.0))]
	CaptureUtil.save_viewport(get_viewport(), "%s/%s" % [_out, name])
	print("capture ", name, " jeu=", _clock_ms - t0, "ms")
	Engine.time_scale = 1.0


## Mannequin factice sans son texte (compteur DPS) pour ne pas encombrer la capture.
func _dummy(pos: Vector2) -> void:
	var t := TestTools.spawn_poutch(get_tree(), &"normal", pos)
	if t != null:
		var l: Variant = t.get("_label")
		if l is CanvasItem:
			(l as CanvasItem).visible = false


## Marche du joueur (déplacement direct, image par image à 10 u/s) pour poser la traîne des kits à chaîne.
## Départ téléporté (la traîne repart de zéro), arrivée à la position d'origine.
func _walk(p: Node2D, dir: Vector2) -> void:
	var pts: Array[Vector2] = []
	var n := _prewalk * Balance.UNIT_PX
	var side := Vector2(-dir.y, dir.x)
	if _prewalk_loop:
		var q := n * 0.25
		pts = [_player_home - dir * q - side * q, _player_home + dir * q - side * q, _player_home + dir * q + side * q, _player_home - dir * q + side * q, _player_home]
	else:
		pts = [_player_home - dir * n, _player_home]
	p.global_position = pts[0]
	await _f(3)
	var speed := 10.0 * Balance.UNIT_PX
	for i in range(1, pts.size()):
		while p.global_position.distance_to(pts[i]) > 1.0:
			var d := get_process_delta_time()
			p.global_position = p.global_position.move_toward(pts[i], speed * maxf(d, 0.001))
			await get_tree().process_frame


func _clear_world() -> void:
	TestTools.clear_poutchs(get_tree())
	TestTools.clean(get_tree())


func _logical_to_player(p: Node2D, dir: Vector2, fwd_u: float, side_u: float) -> Vector2:
	var side := Vector2(-dir.y, dir.x)
	return p.global_position + (dir * fwd_u + side * side_u) * Balance.UNIT_PX


# --- Mode personnage ---------------------------------------------------------------------

func _run_char(p: Node2D) -> void:
	var sc: SpellCaster = p.get(&"spells") as SpellCaster
	var vtag := ""
	for s in _loadout:
		vtag += "__" + String(_loadout[s])
	var vlabel := ""
	if not _loadout.is_empty():
		vlabel = " var=" + ",".join(PackedStringArray(_loadout.keys().map(func(k: Variant) -> String: return "%s:%s" % [k, _loadout[k]])))
	for slot in _slots:
		if sc == null or not sc.has_slot(slot):
			print("slot ", slot, " absent pour ", _char, " : saute")
			continue
		for di in _dirs.size():
			var dir := _dirs[di]
			p.global_position = _player_home
			_clear_world()
			# nettoyage : le changement de personnage (sur place) purge projectiles, zones et nœuds de kit du lancer précédent
			TestTools.switch_character(get_tree(), _char, RunState.normalize_loadout(_loadout))
			await _f(6)
			sc = p.get(&"spells") as SpellCaster
			if sc == null or not sc.has_slot(slot):
				print("slot ", slot, " absent pour ", _char, " : saute")
				break
			var targets: Array[Vector2] = []
			for off in DUMMY_OFFSETS_U:
				var pos := _logical_to_player(p, dir, off.x * _dummy_dist / 5.0, off.y)
				targets.append(pos)
				_dummy(pos)
			await _wait(0.5)
			var aim := _logical_to_player(p, dir, _dummy_dist, 0.0)
			if _prewalk > 0.0:
				await _walk(p, dir)
			sc.refill_kit_resource()
			sc.set_cooldown(slot, 0.0, 1.0)
			sc.aim_override = aim
			var t0 := _clock_ms
			var ok := sc.cast(slot)
			sc.aim_override = null
			if not ok:
				if _prewalk <= 0.0:
					print("NON LANCE : ", _char, " slot ", slot, " dir ", di)
					continue
				# avec --prewalk : sort passif (ex. chaîne d'Arpenteuse, sort 1) ou non lançable ; on capture l'état posé
				print("PAS DE LANCER (passif ou refusé) : ", _char, " slot ", slot, " dir ", di, " : capture de l'état posé par la marche")
			var base := "%s__s%d%s__d%d" % [_char, slot, vtag, di]
			var legend := "%s s%d%s d%d (%.1f,%.1f)%s" % [_char, slot, vlabel, di, dir.x, dir.y, " ORIG" if _orig else ""]
			for t in _times:
				await _shoot_at(t0, t, base, legend)
			await _wait(_settle)
	_clear_world()


# --- Mode boss ---------------------------------------------------------------------------

func _boss_entry() -> Dictionary:
	for e in TestTools.monster_catalog():
		if String(e.get("boss_id", "")) == _boss and e.kind != &"tier":
			return e
	return {}


func _attack_matches(atk: Dictionary, want: String) -> bool:
	var id := String(atk.id)
	return want == id or want == String(atk.label) or id.ends_with(":" + want) or want == id.get_slice(":", 1)


func _safe(s: String) -> String:
	return s.replace(":", "_").replace(" ", "_").replace(".", "")


func _run_boss(p: Node2D) -> void:
	var entry := _boss_entry()
	if entry.is_empty():
		push_error("spell_cast_capture : boss inconnu « %s »" % _boss)
		return
	var kind: StringName = entry.kind
	TestMode.set_flag(&"god", true)
	var b := TestTools.spawn_boss(get_tree(), StringName(_boss), kind, _player_home + Vector2(0, -7.0 * Balance.UNIT_PX))
	if b == null or not (b is Enemy):
		push_error("spell_cast_capture : invocation de « %s » impossible" % _boss)
		return
	var boss := b as Enemy
	await _f(30)
	var list := TestBossAdapter.attacks(boss)
	if _attacks.has("list") or _attacks.is_empty():
		for a in list:
			print("attaque id=", a.id, " label=", a.label, " ok=", a.ok, " kind=", a.kind)
		return
	var chosen: Array[Dictionary] = []
	if _attacks.has("all"):
		for a in list:
			if a.kind != &"phase":
				chosen.append(a)
	else:
		for w in _attacks:
			var found := false
			for a in list:
				if _attack_matches(a, w):
					chosen.append(a)
					found = true
					break
			if not found:
				print("attaque inconnue : ", w)
	for atk in chosen:
		for di in _dirs.size():
			var dir := _dirs[di]
			if not is_instance_valid(boss) or not boss.active:
				print("boss disparu")
				return
			# le joueur vient se placer dans la direction demandée, à 7 u du boss
			p.global_position = boss.global_position + dir * 7.0 * Balance.UNIT_PX
			await _wait(0.6)
			var t0 := _clock_ms
			if not TestBossAdapter.fire(boss, atk, p.global_position):
				print("NON LANCE : ", _boss, " ", atk.id)
				continue
			var base := "%s__%s__d%d" % [_boss, _safe(String(atk.label)), di]
			var legend := "%s %s d%d (%.1f,%.1f)%s" % [_boss, atk.label, di, dir.x, dir.y, " ORIG" if _orig else ""]
			for t in _times:
				await _shoot_at(t0, t, base, legend)
			await _wait(_settle)
