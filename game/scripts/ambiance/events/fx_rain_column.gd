extends AmbientEffect
## « Colonne de pluie » (La Source, Furieux et au-delà) : la colonne centrale (SourceColumn, posée par StageManager
## sous la carte ; VFX Codex `vfx/source/rain_column.png`) s'épaissit avec la difficulté : largeur × 1 -> `width_max`
## et lumière `light_preset` × 1 -> `light_max`, de D = seuil à D = `d_full`, lissé. Aucun nœud créé, aucun effet de jeu.
## Paramètres : "node" ("SourceColumn"), "width_max" (1,6), "alpha_max" (1,15 : opacité du VFX), "d_full" (8),
## "light_preset" ("source_column"), "light_max" (1,4).

var column: Node2D = null
var k := 0.0 ## épaississement lissé 0..1
var _base_scale := Vector2.ONE
var _base_mod := Color.WHITE
var _seek_t := 0.0
var _light_k := -1.0


func start() -> void:
	k = 0.0
	_light_k = -1.0
	_seek()


func _seek() -> void:
	column = map.get_node_or_null(NodePath(String(def.get("node", "SourceColumn")))) as Node2D
	if column != null:
		_base_scale = column.scale
		_base_mod = column.modulate


func process(delta: float) -> void:
	if column == null or not is_instance_valid(column):
		column = null
		_seek_t -= delta
		if _seek_t <= 0.0: # colonne posée après le début de l'étage : on la cherche 2 fois par seconde
			_seek_t = 0.5
			_seek()
		if column == null:
			return
	var d_full := maxf(float(def.get("d_full", 8.0)), threshold + 0.01)
	var want := clampf((mgr.events.difficulty - threshold) / (d_full - threshold), 0.0, 1.0)
	k = move_toward(k, want, delta / 3.0)
	column.scale = Vector2(_base_scale.x * lerpf(1.0, float(def.get("width_max", 1.6)), k), _base_scale.y)
	var a := minf(_base_mod.a * lerpf(1.0, float(def.get("alpha_max", 1.15)), k), 1.0)
	column.modulate = Color(_base_mod.r, _base_mod.g, _base_mod.b, a)
	if absf(k - _light_k) > 0.02: # réglage des lumières de la carte : seulement quand ça bouge
		_light_k = k
		mgr.set_preset_light_mult(StringName(def.get("light_preset", "source_column")), lerpf(1.0, float(def.get("light_max", 1.4)), k))


## Lumières de la carte reconstruites : le multiplicateur de la colonne est gardé par l'AmbianceManager ; la largeur
## lissée continue sans repartir de 1.
func refresh() -> void:
	_light_k = -1.0


func stop() -> void:
	if column != null and is_instance_valid(column):
		column.scale = _base_scale
		column.modulate = _base_mod
	column = null
	k = 0.0
	if mgr != null and is_instance_valid(mgr):
		mgr.set_preset_light_mult(StringName(def.get("light_preset", "source_column")), 1.0)


func describe() -> Dictionary:
	var d := super.describe()
	d["k"] = k
	d["found"] = column != null
	return d
