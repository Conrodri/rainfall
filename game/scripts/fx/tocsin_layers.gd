class_name TocsinLayers
extends RefCounted
## Rendu en calques de Tocsin (Design_Personnages §1.12, lot T5 ; système S2 côté personnage) : le nœud
## « Visual » du joueur porte le calque `torso` (SpriteFrames du personnage) ; les 6 autres calques (tête,
## vapeur de cou, bras G/D, jambes G/D) sont des AnimatedSprite2D enfants, même cadre 192², même pivot,
## asservis à l'anim et à la frame du torse. Un membre absent = calque caché. Ordre de profondeur par
## direction lu dans `layers_order.json` (back_to_front) : les calques derrière le torse passent en
## show_behind_parent. Normales et émission (_e) par calque via EmissiveOverlay (comme tout sprite du jeu).
## Assets absents : available() faux -> le kit garde un seul sprite (composite ou repli teinté).

const LAYERS: Array[StringName] = [&"torso", &"head", &"neck_steam", &"arm_l", &"arm_r", &"leg_l", &"leg_r"]
const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const ORDER_FILE := "layers_order.json"
const FURNACE_ENERGY_STEP := 0.05 ## énergie d'émission quantifiée (matériaux partagés, NormalMaps)

var visual: AnimatedSprite2D = null ## calque torse (nœud Visual du joueur)
var sprites := {} ## StringName -> AnimatedSprite2D (hors torse)
var wanted := {} ## StringName -> bool (membre présent / calque voulu)
var orders := {} ## dir -> Array[String] (arrière -> avant)
var _dir := ""
var _energy := -1.0


static func frames_path(dir: String, layer: StringName) -> String:
	return dir + "tocsin_%s.tres" % layer


## Calques livrés (au minimum torse + bras + jambes + tête).
static func available(dir: String) -> bool:
	for l in [&"torso", &"head", &"arm_l", &"arm_r", &"leg_l", &"leg_r"]:
		if not ResourceLoader.exists(frames_path(dir, l)):
			return false
	return true


## Monte les calques sous `p_visual` (déjà muni des SpriteFrames du torse par le joueur).
static func attach(p_visual: AnimatedSprite2D, dir: String) -> TocsinLayers:
	var t := TocsinLayers.new()
	t.visual = p_visual
	t._load_orders(dir + ORDER_FILE)
	for l in LAYERS:
		t.wanted[l] = l != &"neck_steam" # vapeur : seulement sans tête
		if l == &"torso":
			continue
		var p := frames_path(dir, l)
		if not ResourceLoader.exists(p):
			continue
		var sf := load(p) as SpriteFrames
		if sf == null:
			continue
		var s := AnimatedSprite2D.new()
		s.name = "Layer_%s" % l
		s.centered = p_visual.centered
		s.offset = p_visual.offset
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		p_visual.add_child(s)
		EmissiveOverlay.apply(s, sf)
		t.sprites[l] = s
	p_visual.frame_changed.connect(t.sync)
	p_visual.animation_changed.connect(t.sync)
	t.sync()
	return t


func _load_orders(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and (data as Dictionary).get("orders") is Dictionary:
		orders = (data as Dictionary)["orders"]


func set_wanted(layer: StringName, on: bool) -> void:
	if bool(wanted.get(layer, false)) != on:
		wanted[layer] = on
		sync()


func is_shown(layer: StringName) -> bool:
	if layer == &"torso":
		return visual != null and visual.visible
	var s: AnimatedSprite2D = sprites.get(layer)
	return s != null and s.visible


## Anim et frame du torse recopiées sur chaque calque ; calque sans cette anim (ex. jambe absente de `hop_l`) : caché.
func sync() -> void:
	if visual == null or not is_instance_valid(visual):
		return
	var anim := visual.animation
	var fr := visual.frame
	for l: StringName in sprites:
		var s: AnimatedSprite2D = sprites[l]
		var sf := s.sprite_frames
		var has := sf != null and sf.has_animation(anim) and sf.get_frame_count(anim) > 0
		# membre lancé : son calque reste dans l'anim throw_<membre> (il disparaît à la frame de lâcher, rendu T3)
		s.visible = has and (bool(wanted.get(l, false)) or String(anim).begins_with("throw_%s" % l))
		if not has:
			continue
		if s.animation != anim:
			s.animation = anim
		s.frame = mini(fr, sf.get_frame_count(anim) - 1)
		s.flip_h = visual.flip_h
		s.offset = visual.offset # T5 : AtlasTexture.margin reconstitue la cellule 192 ; seul l'offset du rig compte
	var d := _dir_of(String(anim))
	if d != "" and d != _dir:
		_apply_order(d)


func _dir_of(anim: String) -> String:
	var i := anim.rfind("_")
	if i < 0:
		return ""
	var d := anim.substr(i + 1)
	return d if d in DIRS else ""


## Ordre de profondeur de la direction : avant le torse = derrière le parent ; après = devant, dans l'ordre.
## L'enfant « Emission » du torse reste juste au-dessus du torse (index 0 des enfants de devant).
func _apply_order(d: String) -> void:
	_dir = d
	var order: Array = orders.get(d, [])
	if order.is_empty():
		return
	var ti := order.find("torso")
	var idx := 0
	var em := visual.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE))
	if em != null:
		visual.move_child(em, 0)
		idx = 1
	for i in order.size():
		var l := StringName(order[i])
		var s: AnimatedSprite2D = sprites.get(l)
		if s == null:
			continue
		s.show_behind_parent = ti >= 0 and i < ti
		visual.move_child(s, idx)
		idx += 1


## Énergie de l'émission du foyer (calque torse : grille pectorale, fentes ; Surchauffe).
func set_furnace(energy: float) -> void:
	var e := snappedf(energy, FURNACE_ENERGY_STEP)
	if is_equal_approx(e, _energy) or visual == null:
		return
	_energy = e
	NormalMaps.set_emission_energy(visual, e)
	for l: StringName in [&"neck_steam", &"head"]: # fentes de la cloche, braises du cou : même foyer
		var s: AnimatedSprite2D = sprites.get(l)
		if s != null:
			NormalMaps.set_emission_energy(s, e)


## Fantôme de roulade : copie figée des calques affichés (un tonneau donne un tonneau fantôme), qui s'estompe.
func spawn_ghost(parent: Node, color: Color, fade_s: float) -> void:
	if visual == null or visual.sprite_frames == null or parent == null:
		return
	var g := Node2D.new()
	parent.add_child(g)
	g.global_transform = visual.global_transform
	g.modulate = color
	var back: Array = []
	var front: Array = []
	for c in visual.get_children():
		var s := c as AnimatedSprite2D
		if s != null and s.visible and s.sprite_frames != null and String(s.name).begins_with("Layer_"):
			(back if s.show_behind_parent else front).append(s)
	for s: AnimatedSprite2D in back + [visual] + front:
		var tex := s.sprite_frames.get_frame_texture(s.animation, s.frame)
		if tex == null:
			continue
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = s.centered
		sp.offset = s.offset
		sp.flip_h = s.flip_h
		g.add_child(sp)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, fade_s)
	tw.tween_callback(g.queue_free)
