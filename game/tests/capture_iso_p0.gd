extends Node
## Capture du prototype isométrique (docs/Design_Isometrique.md §5, lot P0-b) : terrasses_noyees en iso
## (sol en losanges, murs en diagonale, prismes provisoires), tri du joueur devant / derrière un mur.
## godot --path game --write-movie <dossier>/iso.png --fixed-fps 30 --resolution 1280x720 --quit-after 330 res://tests/capture_iso_p0.tscn
## Chronologie (s, après le lancement de l'étage) : 0-3 départ ; 3-6,5 derrière le mur de la rangée 8
## (case carte (3, 7), mur en fondu) ; 6,5-10 devant ce mur (case (3, 9)) ; 10-14 bord sud-ouest (falaises,
## abîme, case (14, 30)). --quit-after 450.

const MAP := "res://scenes/stage/maps/terrasses_noyees.tscn"
const BEHIND := Vector2i(3, 7)
const FRONT := Vector2i(3, 9)
const EDGE := Vector2i(14, 30)

var _main: Node
var _t := -1.0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load(MAP))
	_main.set(&"save_path", "user://test_capture_iso_p0.json") # jamais user://run_save.json (capture fenêtrée)
	add_child(_main)
	_main.game_ready.connect(func() -> void:
		_t = 0.0
		# capture fenêtrée : une perte de focus ouvrirait la pause et figerait la séquence -> refermée
		var hud: Node = _main.get(&"hud")
		var pm: Node = hud.get(&"pause_menu") if hud != null else null
		if pm != null and pm.has_signal(&"opened"):
			pm.opened.connect(func() -> void: pm.call_deferred(&"_close")))


func _physics_process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var stage: StageManager = _main.get(&"stage")
	var player: Node2D = _main.get(&"player")
	if stage == null or stage.map == null or player == null:
		return
	var cell := Vector2i(-1, -1)
	if _t >= 10.0:
		cell = EDGE
	elif _t >= 6.5:
		cell = FRONT
	elif _t >= 3.0:
		cell = BEHIND
	if cell.x >= 0:
		var size_px := (stage.map.get_meta(&"size_u") as Vector2) * 64.0
		var m := -size_px * 0.5 + (Vector2(cell) + Vector2(0.5, 0.5)) * 128.0
		player.global_position = stage.map.to_global(stage.map.from_map(m))
