class_name RecluseGloom
extends Node
## Obscurité du Reclus (docs/Design_Etages.md §5.4) : dès sa phase 2, les cristaux de l'arène (lumières de
## la carte, AmbianceManager.map_lights()) tombent à DIM_K de leur énergie, en cascade de pannes ; les
## télégraphes (couche non éclairée) ne changent pas, la lumière du joueur et celle du boss non plus.
## Créé par RecluseBrain à l'entrée en phase 2 ; à la mort du boss, reste tant que la charge du gros pilier
## n'est pas finie (trace), puis rend la lumière. Garde-fou : seules les lumières de la carte baissent,
## jamais le CanvasModulate (Direction_Lumiere_Ambiance §1.1).

const DIM_K := 0.5
const REAPPLY_S := 0.5 ## le changement de palier de difficulté remet les énergies : réappliqué
const FADE_S := 1.2 ## fondu des cristaux pendant l'obscurité (au lieu des 10 s de la carte)
const CASCADE_MS := 260.0
const MAX_S := 180.0

var boss_alive := true
var dimmed := 0 ## lumières baissées au dernier passage (tests)
var _pillar: Node = null
var _t := 0.0
var _life := 0.0
## Extension (Mère-Cristal, Anguille des profondeurs, étage 4) : facteur propre, zone limitée et nœuds de
## trace qui vivent et meurent avec l'obscurité (blocs de cristal, crue). create() du Reclus inchangé.
var dim_k := DIM_K
var center := Vector2.ZERO
var radius := 0.0 ## > 0 : seules les lumières de la carte à moins de `radius` (px) de `center` baissent
var _trace: Array[Node] = []


## Variante paramétrable : opts {dim_k, center, radius, name}. Même trace que le Reclus (reste après la mort
## du boss tant que la charge du gros pilier continue).
static func create_with(e: Enemy, opts: Dictionary) -> RecluseGloom:
	var host := e.get_parent()
	if host == null:
		return null
	var g := RecluseGloom.new()
	g.name = StringName(opts.get("name", "RecluseGloom"))
	g.dim_k = float(opts.get("dim_k", DIM_K))
	g.center = opts.get("center", Vector2.ZERO)
	g.radius = float(opts.get("radius", 0.0))
	host.add_child(g)
	g._apply(true)
	return g


## Zone ou facteur qui changent (crue qui monte, Mère qui boit plus de lumière) : réappliqué tout de suite.
func set_area(c: Vector2, r: float, k := -1.0) -> void:
	center = c
	radius = r
	if k >= 0.0:
		dim_k = k
	_apply(false)


## Nœud de trace libéré avec l'obscurité (release) ; le propriétaire peut le libérer avant.
func keep(n: Node) -> void:
	if is_instance_valid(n) and not _trace.has(n):
		_trace.append(n)


## Trace encore en vie (tests).
func trace_count() -> int:
	var k := 0
	for n in _trace:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			k += 1
	return k


static func create(e: Enemy) -> RecluseGloom:
	var host := e.get_parent()
	if host == null:
		return null
	var g := RecluseGloom.new()
	g.name = &"RecluseGloom"
	host.add_child(g)
	g._apply(true)
	return g


## Mort du boss : la trace reste si un gros pilier actif charge encore ; sinon la lumière revient.
func on_boss_dead() -> void:
	boss_alive = false
	_pillar = null
	if is_inside_tree():
		for p in get_tree().get_nodes_in_group(&"pillars"):
			if p is Pillar and (p as Pillar).kind == Pillar.Kind.BIG and (p as Pillar).state == Pillar.STATE_ACTIVE and not (p as Pillar).is_charged():
				_pillar = p
				break
	if _pillar == null:
		release()


## Rend la lumière et se libère.
func release() -> void:
	_set_lights(1.0, false)
	for n in _trace:
		if is_instance_valid(n):
			n.queue_free()
	_trace.clear()
	queue_free()


func _physics_process(delta: float) -> void:
	_life += delta
	if not boss_alive:
		var p := _pillar as Pillar
		if _life > MAX_S or not is_instance_valid(p) or p.state != Pillar.STATE_ACTIVE:
			release()
			return
	_t += delta
	if _t >= REAPPLY_S:
		_t = 0.0
		_apply(false)


func _apply(first: bool) -> void:
	dimmed = _set_lights(dim_k, first)


func _set_lights(k: float, cascade: bool) -> int:
	if not is_inside_tree():
		return 0
	var am := AmbianceManager.find(get_tree())
	if am == null:
		return 0
	var n := 0
	var i := 0
	for ml in am.map_lights():
		var h := ml["handle"] as LightRig.Handle
		var d: Dictionary = ml["def"]
		if h == null:
			continue
		if radius > 0.0 and k < 1.0 and (d.get("global", center) as Vector2).distance_to(center) > radius:
			continue # hors de la zone (crue de l'Anguille) : intacte
		var on := am.map_light_on(d)
		h.set_energy((float(d.get("energy", 1.0)) if on else 0.0) * k)
		h.set_fade(FADE_S if k < 1.0 else AmbianceManager.LIGHT_FADE_S)
		if cascade:
			h.outage(CASCADE_MS * (1.0 + 0.5 * (i % 4)))
		i += 1
		if on:
			n += 1
	return n
