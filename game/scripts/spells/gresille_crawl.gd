class_name GresilleCrawl
extends Node2D
## Arcs qui courent sur les monstres chargés de Grésille (docs/fiches/gresille.md §5, VFX `static_crawl` du lot GR2) :
## de 3 cumuls de Statique, des filets lilas lèchent le corps (plus vifs et plus lumineux à 4-5 cumuls). Purement visuel.
##
## Performance : aucun coût sans cumul (aucun nœud actif, `_process` éteint). Un pool FIXE de POOL_MAX sprites créé une
## fois ; le plafond de sprites actifs est POOL_MAX x CAP_MULT[palier de qualité] (comme StatusFx : Bas 9, Moyen 27,
## Haut 60), divisé par deux en « réduction des mouvements ». Le kit appelle `refresh()` toutes les REFRESH_S avec les
## monstres à >= MIN_STACKS ; seuls les plus chargés visibles à l'écran (puis les plus proches du joueur) sont habillés.

const FRAMES_PATH := "res://assets/sprites/vfx/gresille/static_crawl/static_crawl.tres"
const POOL_MAX := 60
const CAP_MULT: Array[float] = [0.15, 0.45, 1.0] ## paliers Quality.Tier (LOW, MEDIUM, HIGH)
const MIN_STACKS := 3
const REFRESH_S := 0.2
const Z := 26 ## au-dessus de StatusFx (25), sous les étincelles d'impact (30)
const VIEW_MARGIN_PX := 96.0
const FRAME_PX := 64.0 ## frame 64x64 = un corps d'environ 1 u
const ALPHA_BY_STACKS: Array[float] = [0.0, 0.0, 0.0, 0.55, 0.85, 1.0]
const SPEED_BY_STACKS: Array[float] = [1.0, 1.0, 1.0, 0.8, 1.1, 1.6] ## multiplicateur de vitesse d'animation

var _slots: Array = [] ## [{holder: Node2D, sp: AnimatedSprite2D, target: Node2D}]
var _active := 0
var _frames: SpriteFrames = null
var _material: CanvasItemMaterial = null
var _ready_done := false


func _ready() -> void:
	set_process(false)
	if not ResourceLoader.exists(FRAMES_PATH):
		return
	_frames = load(FRAMES_PATH) as SpriteFrames
	if _frames == null:
		return
	_material = CanvasItemMaterial.new()
	_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for i in POOL_MAX:
		var holder := Node2D.new() # espace billboard : x, y logique / 2, comme StatusFx et HitFx
		holder.top_level = true
		holder.scale = Iso.UNSQUASH
		holder.z_index = Z
		holder.visible = false
		var sp := AnimatedSprite2D.new()
		sp.sprite_frames = _frames
		sp.material = _material
		sp.animation = &"default"
		holder.add_child(sp)
		add_child(holder)
		_slots.append({"holder": holder, "sp": sp, "target": null})
	_ready_done = true


## Plafond de sprites actifs au palier courant (public : tests).
static func cap() -> int:
	var tier: int = clampi(int(Quality.tier), 0, CAP_MULT.size() - 1)
	var n := int(floorf(float(POOL_MAX) * CAP_MULT[tier]))
	if GameSettings.reduce_motion():
		n /= 2
	return clampi(n, 0, POOL_MAX)


func active_count() -> int:
	return _active


func pool_size() -> int:
	return _slots.size()


## Remplace la sélection : `cands` = monstres à >= MIN_STACKS, `stacks_of(e) -> int`, `center` = position du joueur
## (départage). Hors écran = rien ; aucun candidat = tout éteint.
func refresh(cands: Array, stacks_of: Callable, center: Vector2) -> void:
	if not _ready_done or not StatusFx.enabled:
		_clear_slots()
		return
	var limit := cap()
	if cands.is_empty() or limit <= 0:
		_clear_slots()
		return
	var view := _view_rect()
	var picks: Array = [] # [{e, n, d}]
	for e: Node2D in cands:
		if not is_instance_valid(e) or not e.is_inside_tree():
			continue
		if view.size != Vector2.ZERO and not view.has_point(e.global_position):
			continue
		var n: int = clampi(int(stacks_of.call(e)), 0, ALPHA_BY_STACKS.size() - 1)
		if n < MIN_STACKS:
			continue
		picks.append({"e": e, "n": n, "d": e.global_position.distance_squared_to(center)})
	picks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["n"] > b["n"] or (a["n"] == b["n"] and a["d"] < b["d"]))
	var count := mini(picks.size(), mini(limit, _slots.size()))
	for i in count:
		var p: Dictionary = picks[i]
		var slot: Dictionary = _slots[i]
		var e: Node2D = p["e"]
		var n: int = p["n"]
		var r := float(e.get(&"radius_px")) if &"radius_px" in e else 20.0
		var holder: Node2D = slot["holder"]
		var sp: AnimatedSprite2D = slot["sp"]
		slot["target"] = e
		slot["r"] = r
		sp.scale = Vector2.ONE * clampf(r * 2.6 / FRAME_PX, 0.55, 4.0)
		sp.position = Vector2(0.0, -r * 1.2)
		sp.modulate = Color(1.0, 1.0, 1.0, ALPHA_BY_STACKS[n])
		sp.speed_scale = SPEED_BY_STACKS[n]
		if not holder.visible:
			holder.visible = true
			sp.frame = randi() % maxi(_frames.get_frame_count(&"default"), 1) # arcs non synchronisés
			sp.play(&"default")
		holder.position = e.global_position
	for i in range(count, _active):
		_hide(i)
	_active = count
	set_process(_active > 0)


func clear() -> void:
	_clear_slots()


func _clear_slots() -> void:
	for i in _active:
		_hide(i)
	_active = 0
	set_process(false)


func _hide(i: int) -> void:
	var slot: Dictionary = _slots[i]
	slot["target"] = null
	var holder: Node2D = slot["holder"]
	holder.visible = false
	(slot["sp"] as AnimatedSprite2D).stop()


## Suit les monstres entre deux sélections ; un monstre mort ou rendu au pool éteint son sprite sur-le-champ.
func _process(_delta: float) -> void:
	for i in _active:
		var slot: Dictionary = _slots[i]
		var t: Variant = slot["target"]
		var holder: Node2D = slot["holder"]
		if t == null or not is_instance_valid(t) or not (t as Node).is_inside_tree() or t.get(&"active") == false:
			slot["target"] = null
			holder.visible = false
			continue
		holder.position = (t as Node2D).global_position


## Rectangle monde visible (marge VIEW_MARGIN_PX) ; taille nulle = inconnu (pas de filtrage, ex. test sans fenêtre).
func _view_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	var r := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	return r.grow(VIEW_MARGIN_PX)
