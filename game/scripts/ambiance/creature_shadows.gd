class_name CreatureShadows
extends MultiMeshInstance2D
## Ombre de contact commune sous chaque créature (joueur, monstres, boss) : UN SEUL draw pour
## toute la foule (MultiMesh, tampon de transformations réécrit d'un bloc à chaque image), au lieu
## d'un nœud ou d'une ombre dynamique par monstre. Texture `shadow_blob_256` (rendu Blender à venir,
## art/briefs/STYLE.md ; repli : disque doux neutre d'AmbianceTextures), masque = alpha, shader
## multiplicatif non éclairé (shaders/baked_shadow.gdshader) posé sous les entités
## (z Z_GROUND + 2, au-dessus des ombres cuites du décor).
## Décalque plat au sol en repère logique : disque (FLAT = 1,0), la caméra iso le fait ellipse 2:1
## (docs/Design_Isometrique.md : décalques plats au sol, jamais pré-écrasés).

const MAX_INSTANCES := 320
const WIDTH_PER_RADIUS := 2.6 ## largeur de l'ombre / rayon de collision
const FLAT := 1.0 ## hauteur / largeur en repère logique (la caméra écrase ×0,5)
const PLAYER_RADIUS_PX := 22.0
const SHADER := preload("res://shaders/baked_shadow.gdshader")

var enabled := true
var count := 0 ## ombres dessinées à la dernière image (mesure)
## Tampon MultiMesh. Contrat avec Director.fill_contact_shadows : les termes hors diagonale (indices
## 1, 2, 4, 6 de chaque instance) restent nuls, seuls l'échelle et l'origine sont réécrites.
var _buf := PackedFloat32Array()
var _mat: ShaderMaterial
var _player: Node2D = null
var _director: Director = null


func _init() -> void:
	name = "CreatureShadows"
	z_index = AmbianceManager.Z_GROUND + 2
	light_mask = 0
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.mesh = quad
	multimesh.instance_count = MAX_INSTANCES
	multimesh.visible_instance_count = 0
	_buf.resize(MAX_INSTANCES * 8)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter(&"mask_from_alpha", true)
	_mat.set_shader_parameter(&"shadow_color", Color(0.04, 0.05, 0.06, 0.55))
	material = _mat
	texture = AmbianceTextures.get_tex(&"shadow_blob_256")


## Couleur / opacité (suit la couleur d'ombre de la carte, plus dense que l'ombre portée).
func set_tint(c: Color, strength: float = 1.0) -> void:
	_mat.set_shader_parameter(&"shadow_color", c)
	_mat.set_shader_parameter(&"strength", strength)


func _process(_delta: float) -> void:
	if not enabled or not visible:
		if multimesh.visible_instance_count != 0:
			multimesh.visible_instance_count = 0
		return
	var n := 0
	var tree := get_tree()
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = tree.get_first_node_in_group(&"player") as Node2D
	if _player != null:
		n = _push(n, _player, PLAYER_RADIUS_PX)
	if not is_instance_valid(_director) or not _director.is_inside_tree():
		_director = tree.get_first_node_in_group(&"director") as Director
	if _director != null:
		# perf : le Director remplit le tampon depuis son snapshot (pas de groupe ni d'accès dynamique)
		n = _director.fill_contact_shadows(_buf, n, MAX_INSTANCES, WIDTH_PER_RADIUS, FLAT)
	else: # bancs d'essai sans Director : monstres du groupe
		for e in tree.get_nodes_in_group(&"enemies"):
			if n >= MAX_INSTANCES:
				break
			n = _push(n, e as Node2D, float(e.get(&"radius_px")))
	# Le tampon couvre toutes les instances ; seules les n premières sont dessinées.
	multimesh.buffer = _buf
	multimesh.visible_instance_count = n
	count = n


func _push(n: int, node: Node2D, radius: float) -> int:
	if node == null or not node.visible or radius <= 0.0:
		return n
	var w := radius * WIDTH_PER_RADIUS
	var pos := node.global_position
	var i := n * 8
	# TRANSFORM_2D : (x.x, y.x, 0, origine.x, x.y, y.y, 0, origine.y)
	_buf[i] = w
	_buf[i + 1] = 0.0
	_buf[i + 2] = 0.0
	_buf[i + 3] = pos.x
	_buf[i + 4] = 0.0
	_buf[i + 5] = w * FLAT
	_buf[i + 6] = 0.0
	_buf[i + 7] = pos.y + radius * (0.5 if node.get(&"is_boss") == true else 0.15)
	return n + 1
