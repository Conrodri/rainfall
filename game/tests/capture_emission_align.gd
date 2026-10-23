extends Node2D
## Contrôle de l'alignement émission / diffus (masques _e pleine taille ou demi-résolution,
## art/tools/halve_emission.py) : personnage animé, boss, tuile, lanternes, VFX, sous un éclairage de nuit.
## Image fixe (frames figées) + mesure : rectangle global de l'enfant Emission == rectangle du diffus.
## godot --path game res://tests/capture_emission_align.tscn -- --out=<fichier.png>   (fenêtré : capture)
## godot --headless --path game res://tests/capture_emission_align.tscn             (mesure seule)

const CELLS := [
	["perso averse", "res://assets/sprites/characters/averse/averse.tres", &"idle_s", 2, 1.4],
	["perso ardent", "res://assets/sprites/characters/ardent/ardent.tres", &"", 3, 1.4],
	["boss cerf", "res://assets/sprites/bosses/etage/cerf/cerf.tres", &"walk_p1_e", 3, 1.0],
	["vfx nova", "res://assets/sprites/vfx/ardent_nova/ardent_nova.tres", &"", 4, 0.6],
	["tuile block_b", "res://assets/sprites/terrain/crypts/iso/block_b.png", &"", 0, 0.9],
	["lanterne cristal", "res://assets/sprites/props/crypts/crystal_lantern.png", &"", 0, 1.4],
	["lanterne sanctuaire", "res://assets/sprites/props/fog_forest/lantern_shrine.png", &"", 0, 1.4],
	["pilier actif", "res://assets/sprites/props/pillar_large_active.png", &"", 0, 0.8],
]

var _nodes: Array = [] ## [nom, nœud]
var _frames := 0
var _fails := 0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.35, 0.36, 0.42)
	bg.size = Vector2(1920, 1080)
	add_child(bg)
	var cm := CanvasModulate.new()
	cm.color = Color(0.42, 0.42, 0.55) # nuit : le diffus reste lisible, les _e (unshaded) ressortent
	add_child(cm)
	for i in CELLS.size():
		var c: Array = CELLS[i]
		var pos := Vector2(240 + (i % 4) * 480, 300 + (i / 4) * 520)
		var n := _make(c, pos)
		if n != null:
			_nodes.append([c[0], n])


func _make(c: Array, pos: Vector2) -> Node2D:
	var path: String = c[1]
	if not ResourceLoader.exists(path):
		print("absent : ", path)
		return null
	var res := load(path)
	var node: Node2D
	if res is SpriteFrames:
		var sf := res as SpriteFrames
		var a := AnimatedSprite2D.new()
		add_child(a)
		var anim: StringName = c[2] if c[2] != &"" and sf.has_animation(c[2]) else sf.get_animation_names()[0]
		EmissiveOverlay.apply(a, sf, 2.0)
		a.animation = anim
		a.frame = mini(int(c[3]), sf.get_frame_count(anim) - 1)
		a.offset = Vector2(0, -20) # posé APRÈS apply : l'émission doit suivre
		node = a
	else:
		var s := Sprite2D.new()
		s.texture = res as Texture2D
		var sz := s.texture.get_size()
		s.hframes = maxi(int(round(sz.x / sz.y)), 1) if sz.x >= 2.0 * sz.y else 1 # planche en bande (pilier)
		add_child(s)
		NormalMaps.apply_to_sprite(s)
		s.offset = Vector2(0, -30) # comme stage_map (pied de bloc posé après apply_to_sprite)
		node = s
	node.position = pos
	node.scale = Vector2.ONE * float(c[4])
	return node


func _process(_d: float) -> void:
	_frames += 1
	if _frames < 8:
		return
	for pair in _nodes:
		_measure(pair[0], pair[1])
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	if out != "" and DisplayServer.get_name() != "headless":
		CaptureUtil.save_viewport(get_viewport(), out)
		print("capture : ", out)
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(_fails)
	set_process(false)


func _measure(label: String, n: Node2D) -> void:
	var em := n.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE)) as Node2D
	if em == null:
		print("  --  %s : pas de _e" % label)
		return
	var rd := _rect(n)
	var re := _rect(em)
	var err := maxf(maxf(absf(rd.position.x - re.position.x), absf(rd.position.y - re.position.y)),
		maxf(absf(rd.end.x - re.end.x), absf(rd.end.y - re.end.y)))
	var ok := err < 0.75
	if not ok:
		_fails += 1
	print("  %s  %s : écart %.2f px (diffus %s, émission %s, échelle _e %s)" % ["ok" if ok else "FAIL", label, err, rd, re, em.scale])


func _rect(n: Node2D) -> Rect2:
	var size := Vector2.ZERO
	var ofs := Vector2.ZERO
	var centered := true
	if n is AnimatedSprite2D:
		var a := n as AnimatedSprite2D
		var t := a.sprite_frames.get_frame_texture(a.animation, a.frame)
		size = t.get_size() if t != null else Vector2.ZERO
		ofs = a.offset
		centered = a.centered
	elif n is Sprite2D:
		var s := n as Sprite2D
		size = s.region_rect.size if s.region_enabled else s.texture.get_size() / Vector2(s.hframes, s.vframes)
		ofs = s.offset
		centered = s.centered
	if centered:
		ofs -= size / 2.0
	var xf := n.get_global_transform()
	return Rect2(xf * ofs, Vector2.ZERO).expand(xf * (ofs + size))
