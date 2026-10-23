class_name StringRig
extends Node2D
## S15 (Design_Personnages §2.6.10, §3.3) : fils entre deux sprites synchronisés (le Montreur et Rictus).
## Un Line2D par paire (doigt -> point du pantin), 3 points : le milieu porte le balancement.
## - au repos : balancement sinus SWAY_HZ, amplitude SWAY_PX ;
## - `tension` (0..1) : fils tendus (Toupie, levée, ultime) ;
## - vibrate(s) : vibration rapide qui s'amortit (explosions des doublures).
## Points d'attache : manifeste JSON du lot M2 (rictus/strings.json), en px de cellule par rapport au pivot
## de chaque acteur (pieds du pantin ; origine propre du Montreur), par anim, direction et frame.
## Les deux rangements sont lus : actor["<anim>_<dir>"][frame] ou actor["<anim>"]["<dir>"][frame], chaque frame
## étant {"head": [x, y], "elbow_l": …, "elbow_r": …, "knee_l": …, "knee_r": …} (pantin) ou
## {"finger_0": [x, y], …, "finger_4": …} (Montreur) ; les clés d'acteur sont `rictus` et `montreur`.
## Une anim absente (ou une frame au-delà) reprend `idle` / `hover` de la même direction, sinon DEFAULT_ANCHORS.

const PAIRS := [["finger_0", "elbow_l"], ["finger_1", "knee_l"], ["finger_2", "head"],
		["finger_3", "knee_r"], ["finger_4", "elbow_r"]]
## Repères par défaut (px de cellule, relatifs au pivot ; y vers le haut = négatif), pantin de 1,3 u.
const DEFAULT_ANCHORS := {
	"puppet": {"head": Vector2(0, -100), "elbow_l": Vector2(-26, -78), "elbow_r": Vector2(26, -78),
			"knee_l": Vector2(-10, -24), "knee_r": Vector2(10, -24)},
	"handler": {"finger_0": Vector2(-28, -6), "finger_1": Vector2(-14, -2), "finger_2": Vector2(0, 0),
			"finger_3": Vector2(14, -2), "finger_4": Vector2(28, -6)},
}
const SWAY_HZ := 0.5
const SWAY_PX := 5.0
const VIBRATE_HZ := 28.0
const VIBRATE_PX := 3.0

var puppet: AnimatedSprite2D = null
var handler: AnimatedSprite2D = null
var puppet_key := "rictus" ## clé du pantin dans le manifeste
var handler_key := "montreur"
var tension := 0.0
var lines: Array[Line2D] = []
var _manifest := {}
var _t := 0.0
var _vibe_left := 0.0
var _vibe_total := 0.2


## Crée le rig sous `player` juste avant `handler` (fils sous le fantôme, au-dessus du pantin).
static func attach(player: Node2D, p_puppet: AnimatedSprite2D, p_handler: AnimatedSprite2D, manifest_path: String,
		color: Color, width_px: float, texture_path := "") -> StringRig:
	var r := StringRig.new()
	r.name = "Strings"
	r.puppet = p_puppet
	r.handler = p_handler
	if manifest_path != "" and FileAccess.file_exists(manifest_path):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if d is Dictionary:
			r._manifest = d
	var tex: Texture2D = load(texture_path) as Texture2D if texture_path != "" and ResourceLoader.exists(texture_path) else null
	for i in PAIRS.size():
		var l := Line2D.new()
		l.width = width_px
		l.default_color = color
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		l.end_cap_mode = Line2D.LINE_CAP_ROUND
		l.antialiased = true
		if tex != null:
			l.texture = tex
			l.texture_mode = Line2D.LINE_TEXTURE_TILE
		l.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
		r.add_child(l)
		r.lines.append(l)
	player.add_child(r)
	if p_handler != null and p_handler.get_parent() == player:
		player.move_child(r, p_handler.get_index())
	return r


func has_manifest() -> bool:
	return not _manifest.is_empty()


func vibrate(seconds := 0.2) -> void:
	_vibe_left = seconds
	_vibe_total = maxf(seconds, 0.01)


func is_vibrating() -> bool:
	return _vibe_left > 0.0


func _process(delta: float) -> void:
	update_lines(delta)


## Public pour les tests : recalcule les 5 fils.
func update_lines(delta: float) -> void:
	_t += delta
	_vibe_left = maxf(_vibe_left - delta, 0.0)
	if puppet == null or handler == null or not visible:
		return
	var slack := 1.0 - clampf(tension, 0.0, 1.0)
	var vib := 0.0
	if _vibe_left > 0.0:
		vib = sin(_t * TAU * VIBRATE_HZ) * VIBRATE_PX * (_vibe_left / _vibe_total)
	for i in lines.size():
		var a := pivot_point(handler, _anchor(handler, handler_key, "handler", PAIRS[i][0]))
		var b := pivot_point(puppet, _anchor(puppet, puppet_key, "puppet", PAIRS[i][1]))
		var sway := sin(_t * TAU * SWAY_HZ + i * 0.7) * SWAY_PX * slack
		var mid := (a + b) * 0.5 + Vector2(sway + vib * (1.0 if i % 2 == 0 else -1.0), 0.0)
		lines[i].points = PackedVector2Array([a, mid, b])


## Point du manifeste (px de cellule relatifs au pivot) -> espace du parent du sprite.
static func pivot_point(spr: AnimatedSprite2D, p: Vector2) -> Vector2:
	return spr.position + p * spr.scale


func _anchor(spr: AnimatedSprite2D, key: String, role: String, point: String) -> Vector2:
	var actor: Variant = _manifest.get(key, null)
	if actor is Dictionary:
		var anim := String(spr.animation)
		var n := anim.get_slice_count("_")
		var dir := anim.get_slice("_", n - 1) if n > 1 else "s"
		var base := anim.substr(0, anim.length() - dir.length() - 1) if n > 1 else anim
		var rest := "idle" if role == "puppet" else "hover"
		for frames: Variant in [_frames_of(actor, base, dir, anim), _frames_of(actor, rest, dir, rest + "_" + dir)]:
			if frames is Array and not (frames as Array).is_empty():
				var arr: Array = frames
				var f: Variant = arr[spr.frame] if spr.frame < arr.size() else arr[0]
				if f is Dictionary and f.has(point):
					var p: Array = f[point]
					return Vector2(float(p[0]), float(p[1]))
	return DEFAULT_ANCHORS[role][point]


static func _frames_of(actor: Dictionary, base: String, dir: String, full: String) -> Variant:
	if actor.has(full):
		return actor[full]
	var by_dir: Variant = actor.get(base, null)
	if by_dir is Dictionary:
		return by_dir.get(dir, null)
	if by_dir is Array: # anim à une seule direction (spin)
		return by_dir
	return null
