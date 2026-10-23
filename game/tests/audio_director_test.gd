extends Node
## Transitions des stems selon la difficulté, synchronisation, boss, fichiers manquants.
## godot --headless --path game res://tests/audio_director_test.tscn

const SynthFallback := preload("res://scripts/audio/synth_fallback.gd")
var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)
	else:
		print("ok:   ", msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _ready() -> void:
	await get_tree().process_frame
	var A := Audio
	var D = A.director
	var bank = A.bank
	var wav := SynthFallback.make_ting(220.0, 2.0)
	for id in ["t.base", "t.tension", "t.drive", "t.climax", "t.boss", "t.rain"]:
		bank.set_override(StringName(id), [wav])
	bank.maps["test"] = {
		"music": [
			{"id": "t.base", "db": [0, 0, 0, -2, -3], "fade_s": 0.3},
			{"id": "t.tension", "db": [-80, -3, -1, -3, -4], "fade_s": 0.3},
			{"id": "t.drive", "db": [-80, -80, -2, 0, -1], "fade_s": 0.3},
			{"id": "t.climax", "db": [-80, -80, -80, -4, 0], "fade_s": 0.3},
		],
		"boss": [{"id": "t.boss", "db": [0, 0, 0, 0, 0], "fade_s": 0.3}],
		"ambience": [{"id": "t.rain", "db": [-14, -12, -10, -8, -6], "rain": true, "fade_s": 0.3},
			{"id": "t.manquant", "db": [-10, -10, -10, -10, -10]}],
		"surfaces": {".": "stone"},
	}
	RunState.running = false
	A.start_map("test")
	D.set_tier(0)
	await _wait(0.6)
	var rep: Dictionary = D.stem_report()
	_check(rep.has("t.base") and not rep.has("t.manquant"), "stem sans fichier ignoré, les autres chargés")
	_check(rep["t.base"].playing and not rep["t.tension"].playing, "Calme : seule la base joue")
	_check(rep["t.rain"].playing, "pluie jouée")

	RunState.difficulty_changed.emit(2.0, &"Tendu")
	await _wait(0.8)
	rep = D.stem_report()
	_check(rep["t.tension"].playing and rep["t.tension"].amp > 0.5, "Tendu : stem tension monte en fondu")
	_check(not rep["t.drive"].playing, "Tendu : drive absent")
	RunState.difficulty_changed.emit(3.0, &"Hostile")
	await _wait(0.8)
	rep = D.stem_report()
	_check(rep["t.drive"].playing, "Hostile : drive actif")
	RunState.difficulty_changed.emit(7.0, &"Cataclysme")
	await _wait(0.8)
	rep = D.stem_report()
	_check(rep["t.climax"].playing and rep["t.climax"].amp > 0.9, "Cataclysme : climax plein")
	var pos: Array[float] = []
	for s in D.stems:
		if s.group == "music" and s.player.playing:
			pos.append(s.player.get_playback_position())
	var spread := 0.0
	if pos.size() > 1:
		spread = pos.max() - pos.min()
	_check(pos.size() >= 4 and (spread < 0.25 or spread > 1.75), "stems synchronisés (écart %.3f s sur %d stems)" % [spread, pos.size()])
	RunState.difficulty_changed.emit(1.0, &"Calme")
	await _wait(0.9)
	rep = D.stem_report()
	_check(not rep["t.climax"].playing and not rep["t.drive"].playing, "retour au Calme : couches arrêtées")

	Events.boss_spawned.emit(null, true)
	await _wait(0.8)
	rep = D.stem_report()
	_check(rep["t.boss"].playing and rep["t.boss"].amp > 0.9 and rep["t.base"].amp < 0.1, "boss d'étage : thème boss, musique normale coupée")
	Events.boss_spawned.emit(null, false)
	_check(D.boss_active, "mini-boss ne change pas le thème")
	Events.boss_killed.emit(null, true)
	await _wait(0.9)
	rep = D.stem_report()
	_check(not D.boss_active and rep["t.base"].amp > 0.9 and not rep["t.boss"].playing, "mort du boss : retour à la normale")

	# carte dont aucun stem n'a de fichier (la carte « default » a désormais de vrais fichiers livrés)
	bank.maps["carte_sans_fichiers"] = {"music": [{"id": "x.absent.base"}], "ambience": [{"id": "x.absent.amb"}], "boss": [{"id": "x.absent.boss"}]}
	A.start_map("carte_sans_fichiers")
	await _wait(3.0)
	_check(D._dying.is_empty(), "anciens stems libérés après fondu")
	_check(D.stems.is_empty(), "carte sans fichiers : aucun stem, aucun crash")

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
