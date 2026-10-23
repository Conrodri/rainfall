extends Node
## Capture de l'étage 2 (foret_brume) en iso dans une vraie run : départ à l'étage 1, sortie par le
## téléporteur, puis visite de la forêt (tuiles du lot forêt F2, terrain/fog_forest/iso).
## godot --path game --write-movie <dossier>/foret.png --fixed-fps 30 --resolution 1280x720 --quit-after 450 res://tests/capture_foret_iso.tscn
## Chronologie (s, après l'arrivée à l'étage 2) : 0-3 départ ; 3-6 derrière le mur de la rangée 6
## (case carte (8, 5), mur en fondu) ; 6-9 devant ce mur (8, 7) ; 9-12 bord de l'étang (7, 9) ;
## 12-15 bord sud-ouest (falaises, abîme, case (14, 26)).

const SAVE := "user://test_capture_foret_iso.json" # jamais user://run_save.json (capture fenêtrée)
const STEPS := [[3.0, Vector2i(8, 5)], [6.0, Vector2i(8, 7)], [9.0, Vector2i(7, 9)], [12.0, Vector2i(14, 26)]]

var _main: Node
var _t := -1.0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 23)
	add_child(_main)
	_main.game_ready.connect(func() -> void:
		var hud: Node = _main.get(&"hud")
		var pm: Node = hud.get(&"pause_menu") if hud != null else null
		if pm != null and pm.has_signal(&"opened"):
			pm.opened.connect(func() -> void: pm.call_deferred(&"_close"))
		var stage: StageManager = _main.get(&"stage")
		stage.floor_cleared = true # fin d'étage 1 simulée : interaction avec le téléporteur
		stage.teleporter.set_active(true)
		stage.teleporter.used.emit()
		_t = 0.0)


func _physics_process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var stage: StageManager = _main.get(&"stage")
	var player: Node2D = _main.get(&"player")
	if stage == null or stage.map == null or player == null:
		return
	var cell := Vector2i(-1, -1)
	for s in STEPS:
		if _t >= float(s[0]):
			cell = s[1]
	if cell.x >= 0:
		var size_px := (stage.map.get_meta(&"size_u") as Vector2) * 64.0
		var m := -size_px * 0.5 + (Vector2(cell) + Vector2(0.5, 0.5)) * 128.0
		player.global_position = stage.map.to_global(stage.map.from_map(m))


func _exit_tree() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
