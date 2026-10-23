extends Node
## Captures des étages 4 (cryptes_noyees) et 5 (la_source) dans une vraie run (fenêtré, pas headless) :
## godot --path game --resolution 1280x720 res://tests/capture_floor45.tscn
## PNG écrits dans art/tools/night/_floor45_captures/ (dossier passé par OUT). Saut d'étage par le
## téléporteur (étage n-1 terminé) ; joueur invulnérable posé sur quelques cases de la grille (repère carte).
## La Source : dernière vue après « Appeler la Source » (boss final + zone de 22 u).

const OUT := "res://../art/tools/night/_floor45_captures/"
const SAVE := "user://test_capture_floor45.json" # jamais user://run_save.json
const SHOTS := {
	3: [["cite_reference", Vector2i(11, 35)]],
	4: [["cryptes_depart", Vector2i(14, 4)], ["cryptes_nef", Vector2i(14, 12)], ["cryptes_chapelle_ouest", Vector2i(4, 14)], ["cryptes_lac", Vector2i(14, 20)]],
	5: [["source_arrivee", Vector2i(12, 21)], ["source_centre", Vector2i(12, 15)], ["source_chapelle", Vector2i(3, 3)], ["source_boss", Vector2i(12, 16)]],
}

var _main: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 45)
	add_child(_main)
	await _main.game_ready
	var stage: StageManager = _main.get(&"stage")
	var player: Node2D = _main.get(&"player")
	player.grant_invulnerability(99999.0)
	for floor_n in [3, 4, 5]:
		RunState.stage = floor_n - 1
		RunState.active_time_s = 30.0
		stage.floor_cleared = true
		stage.request_exit()
		await _wait(1.5)
		for shot in SHOTS[floor_n]:
			if String(shot[0]) == "source_boss":
				var rod: Pillar = stage.pillars[0]
				player.global_position = rod.global_position + Vector2(40, 40)
				rod._on_body_entered(player)
				rod.activate()
				await _wait(1.0)
			player.global_position = _cell(stage.map, shot[1])
			await _wait(2.5)
			# HDR 2D : texture du viewport linéaire -> sRGB (même conversion que perf_bench.gd)
			load("res://tests/perf_bench.gd").save_shot(get_viewport(), ProjectSettings.globalize_path(OUT + String(shot[0]) + ".png"))
			print("capture ", shot[0])
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()


## Centre de la case (x, y) de la grille de 2 u (repère carte) -> global.
func _cell(map: StageMap, c: Vector2i) -> Vector2:
	var size_u: Vector2 = map.get_meta(&"size_u", Vector2.ZERO)
	return map.to_global(map.from_map((Vector2(c) * 2.0 + Vector2.ONE - size_u * 0.5) * 64.0))


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout
