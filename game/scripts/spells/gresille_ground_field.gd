class_name GresilleGroundField
extends Node2D
## Nappe électrisée de la Mise à la terre (docs/fiches/gresille.md §4.3) : quand la case sous Grésille est de l'eau, la
## zone n'est plus un disque, elle épouse la nappe d'eau connexe (StageMap.water_patch_at, cases de 1 u, plafond
## GresilleKit.GROUND_WATER_CELLS_MAX = 113 = rayon 6 u). Un tick toutes les `tick` s : chaque monstre dont le pied est
## dans une case du champ reçoit un coup du sort (SpellCaster.deal_damage : la Statique, le ralentissement et les procs
## passent par les hooks du kit) et devient mouillé. Dure `life` s puis disparaît.
## Rendu : la tuile `ground_tile` (lot Codex GR2, 64x64 top-down répétable) par case ; repli sur un aplat lilas translucide
## si la texture manque.

const CELL_PX := 64.0
const COLOR := Color("#B9A6FF")
const TILE_PATH := "res://assets/sprites/vfx/gresille/ground_tile/ground_tile.png"

static var _tile: Texture2D = null

var caster: SpellCaster = null
var spell: SpellData = null
var cells := {} ## Vector2i (case de 1 u, indice monde) -> true
var centers: Array[Vector2] = []
var life := 5.0
var tick_s := 0.5
var _t := 0.0
var _tick_t := 0.0
var _age := 0.0
var ended := false
var victims := {} ## instance id -> true : monstres déjà électrisés par CETTE nappe (compteur de déblocage, 1 par monstre)


func setup(new_caster: SpellCaster, new_spell: SpellData, patch: Array[Vector2], life_s: float, tick: float) -> void:
	caster = new_caster
	spell = new_spell
	life = life_s
	tick_s = tick
	z_index = -1 # au ras du sol
	for c: Vector2 in patch:
		centers.append(c)
		cells[cell_of(c)] = true
	queue_redraw()


static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i((p / CELL_PX).floor())


func contains(p: Vector2) -> bool:
	return cells.has(cell_of(p))


## Avance de delta (public : tests sans boucle de rendu).
func step(delta: float) -> void:
	if ended:
		return
	_age += delta
	_tick_t += delta
	while _tick_t >= tick_s and not ended:
		_tick_t -= tick_s
		_tick()
	if _age >= life:
		ended = true
		queue_free()
	else:
		queue_redraw()


func _process(delta: float) -> void:
	step(delta)


func _tick() -> void:
	if caster == null or caster.player == null or not is_instance_valid(caster.player):
		return
	for e in caster.player.get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and is_instance_valid(e) and e.has_method(&"take_damage") and contains((e as Node2D).global_position):
			if e.has_method(&"mark_wet"):
				e.mark_wet(tick_s + 0.2) # dans la nappe : tout le monde est mouillé
			caster.deal_damage(e, spell, {"via": &"zone"})
			if not victims.has(e.get_instance_id()) and is_instance_valid(e):
				victims[e.get_instance_id()] = true # variante Paratonnerre : « électriser 300 monstres dans l'eau »
				PlayerRef.state_of(caster.player).add_counter(GresilleKit.COUNTER_GROUNDED_WET, 1.0)


func _draw() -> void:
	if _tile == null and ResourceLoader.exists(TILE_PATH):
		_tile = load(TILE_PATH) as Texture2D
	var a := 0.16 + 0.1 * sin(_age * 12.0 * TAU * 0.1) # scintillement
	var fade := clampf((life - _age) / 0.6, 0.0, 1.0)
	var h := CELL_PX * 0.5 - 1.0
	for c: Vector2 in centers:
		var p := c - global_position
		var r := Rect2(p - Vector2(h + 1.0, h + 1.0), Vector2(h + 1.0, h + 1.0) * 2.0)
		if _tile != null:
			draw_texture_rect(_tile, r, false, Color(1.0, 1.0, 1.0, (0.85 + 2.0 * a) * fade))
		else:
			draw_rect(r, Color(COLOR.r, COLOR.g, COLOR.b, a * fade))
