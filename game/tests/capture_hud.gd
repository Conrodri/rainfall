extends Node
## Capture de contrôle du HUD (minimap, barres de vie, barre de boss, inventaire, infobulle, menu pause).
## Debug seulement : les items sont ajoutés ICI, rien n'est laissé dans le jeu.
## PC     : godot --path game --write-movie <dossier>/pc.png --fixed-fps 30 res://tests/capture_hud.tscn
## Mobile : idem avec `-- --mobile` (paysage 960×540, tactile émulé).
## Chronologie (s) : 0,5 items + monstres blessés + boss ; 2 infobulle ; 3 minimap plein écran ;
## 4 menu pause « Objets » ; 5 fin.

var _main: Node
var _t := 0.0
var _step := 0
var _enemies: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # continue pendant le menu pause
	_main = load("res://scenes/main.tscn").instantiate()
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	_main.set(&"run_seed", 2024)
	add_child(_main)


func _process(delta: float) -> void:
	if _main == null or not bool(_main.get(&"is_ready")):
		return
	_t += delta
	var hud: Hud = _main.hud
	if Platform.is_mobile() and Platform.input_mode != Platform.InputMode.TOUCH:
		Platform.set_input_mode(Platform.InputMode.TOUCH) # la souris réelle de l'aperçu repasse en KBM
	if _step < 4 and hud.pause_menu.is_open:
		hud.pause_menu._close() # pause automatique (fenêtre sans focus au lancement)
	if _step == 0 and _t > 0.5:
		_step = 1
		_main.player.grant_invulnerability(1.0e6)
		var ids := ItemDB.all_ids()
		for i in 3:
			RunState.add_item(StringName(ids[0]))
		for k in [1, 5, 12, 20, 33, 41, 47]:
			RunState.add_item(StringName(ids[k % ids.size()]))
		RunState.add_item(StringName(ids[5]))
		var d: Director = _main.director
		var pp: Vector2 = _main.player.global_position
		for i in 6:
			var e := d.spawn_enemy(1 + i % 3, pp + Vector2.from_angle(i * TAU / 6.0) * 330.0, i == 4)
			_enemies.append(e)
		d.spawn_boss(&"etage", pp + Vector2(520, -260))
	if _step >= 1 and _step < 4 and fmod(_t, 0.5) < delta:
		for e in _enemies: # coups réguliers : barres visibles
			if is_instance_valid(e) and e.active:
				e.take_damage(e.max_hp * 0.08)
	if _step == 1 and _t > 2.0:
		_step = 2
		hud.item_bar.show_tooltip(StringName(ItemDB.all_ids()[0]))
	if _step == 2 and _t > 3.0:
		_step = 3
		hud.item_bar.hide_tooltip()
		hud.minimap.set_expanded(true)
	if _step == 3 and _t > 4.0:
		_step = 4
		hud.minimap.set_expanded(false)
		hud.pause_menu.open()
		hud.pause_menu._fill_items()
		hud.pause_menu._show_only(hud.pause_menu._panel_items)
	if _step == 4 and _t > 5.0:
		RunState.items.clear()
		get_tree().quit()
