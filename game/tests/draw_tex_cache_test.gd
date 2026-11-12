extends Node
## Textures dessinées depuis un `_draw()` (12/11/2026, « énormes carrés bleus et des lignes ») : une texture chargée
## dans le `_draw` sans référence gardée est libérée à la fin de l'appel ; son RID meurt avant le rendu et Godot dessine
## un rectangle blanc teinté (anneaux, tracés, pontons des Épreuves en aplats bleu clair). Les aides de chargement
## utilisées en dessin doivent donc garder la texture (cache statique ou membre).
## godot --headless --path game res://tests/draw_tex_cache_test.tscn

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _ready() -> void:
	# Épreuves : chaque fichier utilisé par les draw_* d'EpreuveSprites reste vivant après l'appel
	for f in ["ring_zone.png", "ring_wave.png", "ep2_path_tile.png", "ep2_pad_start.png", "ep2_pad_end.png", "ep2_rope.png",
			"ep2_link.png", "ep2_progress_ring.png", "ep2_bar_frame.png", "ep2_bar_fill.png"]:
		var id := _drop_ref(func() -> Object: return EpreuveSprites.tex(EpreuveSprites.VFX_DIR, f))
		_check(id != 0 and is_instance_id_valid(id), "EpreuveSprites.tex(%s) garde la texture" % f)
		_check(EpreuveSprites.tex(EpreuveSprites.VFX_DIR, f) == instance_from_id(id), "EpreuveSprites.tex(%s) : même instance" % f)
	_check(EpreuveSprites.tex(EpreuveSprites.VFX_DIR, "absent_xyz.png") == null, "EpreuveSprites.tex : null si absente")
	# invites de touches dessinées par CoopPlates._draw
	for f in ["key_1x1", "pad_a", "device_gamepad_off"]:
		if not ResourceLoader.exists(KeyPrompt.DIR + f + ".png"):
			continue
		var id := _drop_ref(func() -> Object: return KeyPrompt.icon(f))
		_check(id != 0 and is_instance_id_valid(id), "KeyPrompt.icon(%s) garde la texture" % f)
	print("RESULT: ", "OK" if _fails == 0 else "FAILED (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## Appelle `f` et ne garde que l'identifiant de l'objet rendu (la référence locale tombe au retour).
func _drop_ref(f: Callable) -> int:
	var o: Object = f.call()
	return o.get_instance_id() if o != null else 0
