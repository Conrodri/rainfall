extends Node
## Sons des verbes d'Épreuve (lot EP-G, docs/Design_Epreuves.md §9) : les 12 clés existent dans sounds.json, chacune
## pointe au moins un fichier chargeable de res://assets/audio/epreuves/, les sons répétés ont une limite de fréquence,
## et les scripts des verbes appellent bien Audio.play avec ces clés.
## godot --headless --path game res://tests/epreuve_sounds_test.tscn  -> RESULT: OK

const KEYS := [
	&"epreuve_start", &"chase_jump", &"chase_warn", &"chase_point", &"chase_miss", &"vein_tick",
	&"vein_geyser_warn", &"vein_geyser", &"hold_side", &"hold_bell_hit", &"hold_bell_dim", &"hold_bell_ring",
]
const REPEATED := [&"chase_warn", &"vein_tick", &"hold_bell_hit", &"hold_side", &"vein_geyser", &"vein_geyser_warn"]
const SCRIPTS := {
	"res://scripts/stage/epreuve.gd": [&"epreuve_start"],
	"res://scripts/stage/epreuve_chase.gd": [&"chase_jump", &"chase_warn", &"chase_point", &"chase_miss"],
	"res://scripts/stage/epreuve_vein.gd": [&"vein_tick", &"vein_geyser_warn", &"vein_geyser"],
	"res://scripts/stage/epreuve_hold.gd": [&"hold_side"],
	"res://scripts/stage/epreuve_hold_bell.gd": [&"hold_bell_hit", &"hold_bell_dim", &"hold_bell_ring"],
}

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _ready() -> void:
	await get_tree().process_frame
	var bank = Audio.bank
	for k in KEYS:
		_check(bank.sounds.has(String(k)), "clé %s dans sounds.json" % k)
		var streams := bank.streams_for(k)
		_check(not streams.is_empty(), "clé %s : au moins un fichier chargeable" % k)
		_check(FileAccess.file_exists("res://assets/audio/epreuves/%s.ogg" % k) or FileAccess.file_exists("res://assets/audio/epreuves/%s.ogg.import" % k), "fichier epreuves/%s.ogg" % k)
	for k in REPEATED:
		var def := bank.get_def(k)
		_check(float(def.get("min_interval_ms", 0.0)) >= 200.0, "clé %s : min_interval_ms >= 200" % k)
	for path in SCRIPTS:
		var src := FileAccess.get_file_as_string(path)
		for k in SCRIPTS[path]:
			_check(src.contains("Audio.play(&\"%s\"" % k), "%s appelle Audio.play(&\"%s\")" % [path.get_file(), k])
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
