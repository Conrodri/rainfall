class_name ChainLightningFx
extends Node2D
## Arcs électriques de la foudre en chaîne (Éclair en bouteille). Un seul nœud, deux pools fixes de Sprite2D créés
## au _ready : un segment étiré par paire de monstres (planche chain_arc.png, cellule 256×48, 4 variantes en lignes
## × 4 frames en colonnes), un éclat par monstre touché (chain_spark.png, 64×64, 4 frames). Textures rendues dans
## Blender ; repli sur arc_8x64.png (8 frames de 64×64) tant que la planche n'est pas importée.
## Les segments apparaissent à la file (STEP_S) pour qu'on voie la chaîne courir, durent LIFE_S puis s'estompent.
## Plafond MAX_ARCS : au-delà, le segment le plus ancien est recyclé. Espace billboard comme HitFx (échelle UNSQUASH).
## API : ChainLightningFx.chain(points_logiques : Array[Vector2]) ; points[0] = victime d'origine.

const ARC_SHEET := "res://assets/sprites/vfx/chain_arc/chain_arc.png"
const ARC_EMIT := "res://assets/sprites/vfx/chain_arc/chain_arc_e.png"
const SPARK_SHEET := "res://assets/sprites/vfx/chain_arc/chain_spark.png"
const FALLBACK_ARC := "res://assets/sprites/ambiance/arc_8x64.png"
const CELL := Vector2(256.0, 48.0)
const VARIANTS := 4
const FRAMES := 4
const SPARK_CELL := 64.0
const MAX_ARCS := 24
const MAX_SPARKS := 24
const STEP_S := 0.04 ## délai entre deux rebonds
const LIFE_S := 0.18
const FPS := 22.0
const ARC_H_PX := 34.0 ## épaisseur affichée (cellule 48 px -> ~34 px)
const SPARK_PX := 56.0
const HIT_LIFT_U := 0.7 ## hauteur du point d'accroche au-dessus des pieds
const Z := 31

static var _inst: ChainLightningFx = null

var _arcs: Array[Sprite2D] = []
var _arc_t: PackedFloat32Array = PackedFloat32Array() ## âge ; < 0 = en attente ; >= LIFE_S + 1 = libre
var _arc_var: PackedInt32Array = PackedInt32Array()
var _sparks: Array[Sprite2D] = []
var _spark_t: PackedFloat32Array = PackedFloat32Array()
var _next_arc := 0
var _next_spark := 0
var _arc_tex: Texture2D = null
var _arc_real := false
var _spark_tex: Texture2D = null
var _rng := RandomNumberGenerator.new()
var live_arcs := 0 ## pour les tests


static func ensure(parent: Node) -> ChainLightningFx:
	if _inst != null and is_instance_valid(_inst) and not _inst.is_queued_for_deletion():
		return _inst
	if parent == null:
		return null
	_inst = ChainLightningFx.new()
	_inst.name = &"ChainLightningFx"
	parent.add_child(_inst)
	return _inst


## Dessine la chaîne : points = positions logiques des pieds (y logique)
## ; la hauteur du corps est ajoutée ici).
static func chain(points: Array, parent: Node) -> void:
	if points.size() < 2:
		return
	var fx := ensure(parent)
	if fx != null:
		fx._chain(points)


func _ready() -> void:
	top_level = true
	scale = Iso.UNSQUASH
	z_index = Z
	light_mask = 0
	_rng.randomize()
	_arc_real = ResourceLoader.exists(ARC_SHEET)
	_arc_tex = load(ARC_SHEET if _arc_real else FALLBACK_ARC) as Texture2D
	if ResourceLoader.exists(SPARK_SHEET):
		_spark_tex = load(SPARK_SHEET) as Texture2D
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for i in MAX_ARCS:
		var s := Sprite2D.new()
		s.texture = _arc_tex
		s.region_enabled = true
		s.material = add
		s.visible = false
		add_child(s)
		_arcs.append(s)
		_arc_t.append(LIFE_S + 1.0)
		_arc_var.append(0)
	for i in MAX_SPARKS:
		var s := Sprite2D.new()
		s.texture = _spark_tex if _spark_tex != null else _arc_tex
		s.region_enabled = true
		s.material = add
		s.visible = false
		add_child(s)
		_sparks.append(s)
		_spark_t.append(LIFE_S + 1.0)
	set_process(false)


func _bright() -> float:
	match Quality.flashes_level:
		0: return 0.4
		1: return 0.7
	return 1.0


## p : point du monde en y logique -> espace billboard local (x, y/2) relevé à hauteur de corps.
func _local(p: Vector2) -> Vector2:
	return Vector2(p.x, p.y * 0.5 + Iso.lift_px(HIT_LIFT_U))


func _chain(points: Array) -> void:
	for i in points.size() - 1:
		var a := _local(points[i])
		var b := _local(points[i + 1])
		var k := _next_arc
		_next_arc = (k + 1) % MAX_ARCS
		var s := _arcs[k]
		var d := b - a
		var seg := maxf(d.length(), 8.0)
		s.position = (a + b) * 0.5
		s.rotation = d.angle()
		s.scale = Vector2(seg / (CELL.x if _arc_real else 64.0), ARC_H_PX / (CELL.y if _arc_real else 64.0))
		_arc_t[k] = -STEP_S * i
		_arc_var[k] = _rng.randi() % VARIANTS
		s.visible = false
		var sk := _next_spark
		_next_spark = (sk + 1) % MAX_SPARKS
		var sp := _sparks[sk]
		sp.position = b
		sp.rotation = _rng.randf() * TAU
		_spark_t[sk] = -STEP_S * i
		sp.visible = false
	set_process(true)


func _set_arc_frame(s: Sprite2D, var_i: int, f: int) -> void:
	if _arc_real:
		s.region_rect = Rect2(f * CELL.x, var_i * CELL.y, CELL.x, CELL.y)
	else:
		s.region_rect = Rect2(f * 64.0, 0.0, 64.0, 64.0)


func _process(delta: float) -> void:
	var bright := _bright()
	var any := false
	var live := 0
	for k in MAX_ARCS:
		var t := _arc_t[k]
		if t >= LIFE_S + 1.0:
			continue
		t += delta
		_arc_t[k] = t
		var s := _arcs[k]
		if t < 0.0:
			any = true
			continue
		if t >= LIFE_S:
			s.visible = false
			_arc_t[k] = LIFE_S + 1.0
			continue
		any = true
		live += 1
		s.visible = true
		var f := int(t * FPS) % (FRAMES if _arc_real else 8)
		_set_arc_frame(s, _arc_var[k], f)
		var a := 1.0 - pow(t / LIFE_S, 2.0)
		s.modulate = Color(1.6 * bright, 1.6 * bright, 2.0 * bright, a)
	for k in MAX_SPARKS:
		var t := _spark_t[k]
		if t >= LIFE_S + 1.0:
			continue
		t += delta
		_spark_t[k] = t
		var s := _sparks[k]
		if t < 0.0:
			any = true
			continue
		if t >= LIFE_S:
			s.visible = false
			_spark_t[k] = LIFE_S + 1.0
			continue
		any = true
		s.visible = true
		var f := int(t * FPS) % FRAMES
		if _spark_tex != null:
			s.region_rect = Rect2(f * SPARK_CELL, 0.0, SPARK_CELL, SPARK_CELL)
			s.scale = Vector2.ONE * (SPARK_PX / SPARK_CELL)
		else:
			s.region_rect = Rect2((f % 8) * 64.0, 0.0, 64.0, 64.0)
			s.scale = Vector2.ONE * (SPARK_PX / 64.0)
		s.modulate = Color(1.6 * bright, 1.6 * bright, 2.0 * bright, 1.0 - pow(t / LIFE_S, 2.0))
	live_arcs = live
	if not any:
		set_process(false)
