extends Node
## Changement de personnage en mode test = spawn propre : l'arbre visuel du joueur après chaque switch doit être
## identique à celui d'un joueur fraîchement instancié pour le même personnage (et le même skin).
## godot --headless --path game res://tests/character_switch_test.tscn  -> RESULT: OK

const PLAYER_SCENE := "res://scenes/player/player.tscn"

var _fails := 0
var _main: Node
var _player: CharacterBody2D
var _skip_frames := false ## .tres du personnage illisible (assets en cours de modification) : comparaison des frames ignorée


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if not cond:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Signature récursive d'un nœud : nom, classe, script (hors nœuds jetables/tweens), animation d'un sprite.
func _sig(n: Node, depth: int = 0) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Timer:
			continue
		var s := ""
		if c.get_script() != null:
			s = str((c.get_script() as Script).resource_path.get_file())
		var nm := String(c.name)
		if nm.begins_with("@"): # nom auto (@Line2D@2488) : on ne garde que la classe
			nm = nm.split("@")[1] if nm.split("@").size() > 1 else nm
		var line := "%s%s:%s:%s" % ["  ".repeat(depth), nm, c.get_class(), s]
		if c is AnimatedSprite2D and (c as AnimatedSprite2D).sprite_frames != null:
			line += ":" + (c as AnimatedSprite2D).sprite_frames.resource_path.get_file()
		out.append(line)
		out.append_array(_sig(c, depth + 1))
	out.sort() # l'ordre des enfants dépend de la séquence d'ajout, pas de l'état
	return out


func _fresh_signature(cid: StringName, loadout: Dictionary) -> Dictionary:
	var saved_char := RunState.character
	var saved_lo := RunState.loadout
	RunState.character = cid
	RunState.loadout = loadout.duplicate()
	var holder := Node2D.new()
	add_child(holder)
	var p := (load(PLAYER_SCENE) as PackedScene).instantiate()
	holder.add_child(p)
	await _frames(2)
	var d := _describe(p)
	holder.queue_free()
	RunState.character = saved_char
	RunState.loadout = saved_lo
	return d


func _describe(p: Node) -> Dictionary:
	var vis := p.get_node("Visual") as AnimatedSprite2D
	var em := vis.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE)) as AnimatedSprite2D
	return {
		"tree": _sig(p),
		"frames": vis.sprite_frames.resource_path if vis.sprite_frames != null else "",
		"emission_frames": em.sprite_frames.resource_path if em != null and em.sprite_frames != null else "",
		"emission_anim_ok": em == null or em.sprite_frames == null or em.sprite_frames.has_animation(em.animation),
		"anim_ok": vis.sprite_frames != null and vis.sprite_frames.has_animation(vis.animation),
		"scale": vis.scale, "offset": vis.offset, "self_modulate": vis.self_modulate, "modulate": vis.modulate,
		"material": vis.material, "rotation": vis.rotation, "flip_h": vis.flip_h, "position": vis.position,
		"children_visual": _sig(vis),
		"character": str(p.get("character").id),
	}


func _compare(label: String, cur: Dictionary, ref: Dictionary) -> void:
	if _skip_frames: # frames illisibles : on ne compare que les nœuds hors sprites d'animation / émission
		for d: Dictionary in [cur, ref]:
			d["frames"] = ""
			d["emission_frames"] = ""
			for k in ["tree", "children_visual"]:
				d[k] = (d[k] as Array).filter(func(l: String) -> bool: return not l.contains("Emission:")).map(func(l: String) -> String: return l.get_slice(".tres", 0).get_slice(":emissive_overlay.gd", 0))
	for k in ["tree", "frames", "emission_frames", "scale", "offset", "children_visual", "character", "rotation", "flip_h", "position"]:
		if cur[k] != ref[k]:
			_fails += 1
			print("  FAIL ", label, " ", k, "\n    actuel: ", cur[k], "\n    neuf:   ", ref[k])
	if not _skip_frames:
		_check(label + " anim existe", cur["anim_ok"], "animation absente du SpriteFrames")
	_check(label + " anim émission existe", cur["emission_anim_ok"], "animation d'émission absente")
	_check(label + " modulate neutre", (cur["self_modulate"] as Color).is_equal_approx(ref["self_modulate"]) and (cur["modulate"] as Color).is_equal_approx(Color.WHITE), str(cur["self_modulate"]) + " " + str(cur["modulate"]))
	_check(label + " matériau", (cur["material"] == null) == (ref["material"] == null))


func _frames_loadable(cid: StringName) -> bool:
	var path := Skins.resolve_frames(cid, CharacterData.for_id(cid, {}).sprite_frames_path)
	if path == "":
		path = "res://assets/sprites/characters/ardent/ardent.tres" # frames de la scène du joueur
	var ok := ResourceLoader.exists(path) and load(path) is SpriteFrames
	if not ok:
		print("  note : SpriteFrames de ", cid, " illisible (", path, "), frames ignorées")
	return ok


func _run() -> void:
	TestMode.begin()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 77)
	add_child(_main)
	await _main.game_ready
	await _frames(5)
	_player = _main.get(&"player")

	var ids: Array[StringName] = []
	for c in TestTools.characters():
		ids.append(StringName(str(c.get("id", ""))))
	print("personnages : ", ids)
	var order: Array[StringName] = []
	order.append_array(ids)
	var rev := ids.duplicate()
	rev.reverse()
	order.append_array(rev)
	for i in ids.size(): # ordre varié : paires décalées
		order.append(ids[(i * 3 + 1) % ids.size()])
	var step := 0
	for cid in order:
		step += 1
		for skin_pass in 2:
			var skin := ""
			if skin_pass == 1:
				var skins: Array = []
				for c in TestTools.characters():
					if str(c.get("id", "")) == String(cid):
						for s in c.get("skins", []):
							if Skins.has_assets(cid, str(s.get("id", ""))):
								skins.append(str(s.get("id", "")))
				if skins.is_empty():
					continue
				skin = skins[0]
			TestMode.set_skin(cid, skin)
			_skip_frames = not _frames_loadable(cid)
			var ok := TestTools.switch_character(get_tree(), cid, {})
			_check("switch %s" % cid, ok)
			await _frames(3)
			var label := "#%d %s skin=%s" % [step, cid, skin]
			var cur := _describe(_player)
			var ref: Dictionary = await _fresh_signature(cid, {})
			_compare(label, cur, ref)
			TestMode.set_skin(cid, "")
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	TestMode.end()
	get_tree().quit(0 if _fails == 0 else 1)
