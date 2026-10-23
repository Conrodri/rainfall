extends Node
## Capture de l'étage 3 (cite_rouille) en iso dans une vraie run : départ à l'étage 1, deux sorties par le
## téléporteur, puis visite de la cité (tuiles du lot cité F3, terrain/rust_city/iso).
## godot --path game --write-movie <dossier>/cite.png --fixed-fps 30 --resolution 1280x720 --quit-after 600 res://tests/capture_cite_iso.tscn
## Option : `-- --floor=1` (terrasses, sans téléporteur) ou `-- --floor=2` (forêt) pour contrôler les autres étages.
## Chronologie (s, après l'arrivée à l'étage) : 0-3 départ (bord du canal) ; 3-6 derrière le mur de la
## rangée 7 (case carte (6, 6), mur en fondu) ; 6-9 rive ouest du canal (9, 10) ; 9-12 grande place
## du sud (11, 35) ; 12-15 bord sud-ouest (falaises, abîme, case (2, 38)) ; 15-18 coin est (21, 2).

const SAVE := "user://test_capture_cite_iso.json" # jamais user://run_save.json (capture fenêtrée)
const STEPS := {
	3: [[3.0, Vector2i(6, 6)], [6.0, Vector2i(9, 10)], [9.0, Vector2i(11, 35)], [12.0, Vector2i(2, 38)], [15.0, Vector2i(21, 2)]],
	2: [[3.0, Vector2i(8, 5)], [6.0, Vector2i(7, 9)], [9.0, Vector2i(6, 10)], [12.0, Vector2i(14, 26)]],
	1: [[3.0, Vector2i(10, 10)], [6.0, Vector2i(5, 20)], [9.0, Vector2i(14, 28)]],
}

var _main: Node
var _t := -1.0
var _floor := 3
var _hops := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--floor="):
			_floor = clampi(int(a.trim_prefix("--floor=")), 1, 3)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 23)
	add_child(_main)
	_main.game_ready.connect(func() -> void:
		var hud: Node = _main.get(&"hud")
		var pm: Node = hud.get(&"pause_menu") if hud != null else null
		if pm != null and pm.has_signal(&"opened"):
			pm.opened.connect(func() -> void: pm.call_deferred(&"_close"))
		_next_floor())


## Fin d'étage simulée (interaction avec le téléporteur) jusqu'à l'étage voulu.
func _next_floor() -> void:
	var stage: StageManager = _main.get(&"stage")
	if RunState.stage >= _floor:
		_t = 0.0
		return
	stage.floor_cleared = true
	stage.teleporter.set_active(true)
	stage.teleporter.used.emit()
	_hops += 1
	get_tree().create_timer(0.5).timeout.connect(_next_floor)


func _physics_process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var stage: StageManager = _main.get(&"stage")
	var player: Node2D = _main.get(&"player")
	if stage == null or stage.map == null or player == null:
		return
	var cell := Vector2i(-1, -1)
	for s in STEPS[_floor]:
		if _t >= float(s[0]):
			cell = s[1]
	if cell.x >= 0:
		var size_px := (stage.map.get_meta(&"size_u") as Vector2) * 64.0
		var m := -size_px * 0.5 + (Vector2(cell) + Vector2(0.5, 0.5)) * 128.0
		player.global_position = stage.map.to_global(stage.map.from_map(m))


func _exit_tree() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
