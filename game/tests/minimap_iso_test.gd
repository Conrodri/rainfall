extends Node
## Minimap isométrique + invites de touches sous les sorts (réglage « Afficher les touches sous les sorts »).
## godot --headless --path game res://tests/minimap_iso_test.tscn
## Réglages sur un fichier injecté (GameSettings.cfg_path) : jamais user://settings.cfg ni user://run_save.json.

const MAP := "res://scenes/stage/maps/terrasses_noyees.tscn"
const CFG := "user://test_minimap_iso_settings.cfg"

var _fails := 0
var _main: Node


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _ready() -> void:
	GameSettings.cfg_path = CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	Platform.set_input_mode(Platform.InputMode.KBM)
	_check(not GameSettings.key_hints(), "réglage « touches sous les sorts » désactivé par défaut")
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 777)
	_main.set(&"map_scene", load(MAP))
	_main.set(&"save_path", "user://test_minimap_iso_run.json")
	add_child(_main)
	await _main.game_ready
	await _wait(0.4)
	var hud: Hud = _main.hud
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	player.grant_invulnerability(1.0e6)
	_main.director.spawning_enabled = false
	_main.director.despawn_all()

	# --- Minimap iso
	var mm := hud.minimap
	_check(stage.map is StageMap and (stage.map as StageMap).is_iso(), "carte terrasses_noyees en iso")
	_check(mm.iso and mm.visible and mm.map_texture != null, "minimap en mode iso")
	var gs := Vector2(mm._grid_size)
	var mr := mm.map_rect()
	_check(absf(mr.size.x / mr.size.y - 2.0) < 0.05, "losange 2:1 (%.3f)" % (mr.size.x / mr.size.y))
	_check(Rect2(Vector2.ZERO, mm.size).encloses(mr), "losange dans le contrôle %s / %s" % [mr, mm.size])
	# point logique connu : cellule carte (3, 7) -> repère logique -> pixel attendu calculé à la main
	var map: StageMap = stage.map
	# cellule de sol « . » la plus proche du centre (les cartes organiques ont du vide près des coins)
	var probe := Vector2(3.5, 7.5)
	var best := 1.0e9
	for gy in mm._grid.size():
		var row := String(mm._grid[gy])
		for gx in row.length():
			if row[gx] == "." and Vector2(gx + 0.5, gy + 0.5).distance_to(gs * 0.5) < best:
				best = Vector2(gx + 0.5, gy + 0.5).distance_to(gs * 0.5)
				probe = Vector2(gx + 0.5, gy + 0.5)
	var m_px := -gs * 128.0 * 0.5 + probe * 128.0 ## repère carte, origine au centre
	var l := Transform2D(PI / 4.0, Vector2.ZERO) * m_px ## Rot(+45°) = repère logique
	var span_x := (gs.x + gs.y) * 128.0 * cos(PI / 4.0) ## largeur logique du losange
	var k := mr.size.x / span_x
	var expected := mr.get_center() + Vector2(l.x, l.y * 0.5) * k
	var gp := map.to_global(map.from_map(m_px))
	var uv := mm._uv(gp)
	var got := mm.uv_to_screen(uv)
	_check(got.distance_to(expected) < 0.5, "point logique -> pixel : %s attendu %s" % [got, expected])
	# orientation : +x carte vers le bas-droite, +y carte vers le bas-gauche (comme l'écran)
	var o := mm.uv_to_screen(Vector2(0.5, 0.5))
	var dx := mm.uv_to_screen(Vector2(0.6, 0.5)) - o
	var dy := mm.uv_to_screen(Vector2(0.5, 0.6)) - o
	_check(dx.x > 0.0 and dx.y > 0.0, "carte +x -> bas-droite %s" % dx)
	_check(dy.x < 0.0 and dy.y > 0.0, "carte +y -> bas-gauche %s" % dy)
	# le joueur placé sur ce point retombe sur le même pixel
	player.global_position = gp
	await _wait(0.3)
	_check(mm.uv_to_screen(mm._player_pos).distance_to(expected) < 1.0, "marqueur du joueur au bon pixel")
	# flèche : direction logique (1, 0) -> écran (1, 0) ; (0, 1) -> (0, 1) ; diagonale logique -> écrasée
	mm._player_dir = Vector2(1, 1).normalized()
	var d := mm.player_screen_dir()
	_check(absf(d.angle() - atan2(0.5, 1.0)) < 0.01, "flèche en direction écran (%.1f°)" % rad_to_deg(d.angle()))
	# perfs : pas de redessin sans changement
	player.set(&"facing", Vector2.RIGHT)
	await _wait(0.4)
	var rc := mm.redraw_count
	await _wait(0.6)
	_check(mm.redraw_count == rc, "aucun redessin sans changement (%d -> %d)" % [rc, mm.redraw_count])
	_check(mm.build_count == 1, "image construite une fois")
	_check(Minimap.ui_texture("minimap_player.png") == null or Minimap.ui_texture("minimap_player.png") is Texture2D, "textures U1 tolérées absentes")

	# --- Invites de touches
	_check(hud.bar_keys.size() == 4 and hud.bar_keys[0].modulate.a > 0.99, "invites visibles au début de partie")
	_check(not hud.key_hints_always, "invites non permanentes par défaut")
	await _wait(4.0)
	var a_mid := hud.bar_keys[1].modulate.a
	_check(a_mid < 1.0, "fondu en cours ou terminé (%.2f)" % a_mid)
	await _wait(1.0)
	_check(hud.bar_keys[1].modulate.a < 0.01 and hud.bar_dodge_key.modulate.a < 0.01, "invites disparues après 5 s + fondu")
	GameSettings.set_key_hints(true)
	await _wait(0.7)
	_check(GameSettings.key_hints() and hud.key_hints_always and hud.bar_keys[1].modulate.a > 0.99, "réglage activé : toujours visibles")
	GameSettings.set_key_hints(false)
	await _wait(0.7)
	_check(hud.bar_keys[1].modulate.a < 0.01, "réglage désactivé : de nouveau masquées")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	GameSettings.cfg_path = GameSettings.PATH
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
