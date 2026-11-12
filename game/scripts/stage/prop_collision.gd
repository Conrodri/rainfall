class_name PropCollision
extends RefCounted
## Collision des props de décor : une seule source, `data/prop_collision.json` (clé = nom du sprite).
## Règle : un prop qui paraît solide bloque avec des rectangles alignés sur la grille de la carte (donc des losanges
## à l'écran) posés sur le BAS visible de l'objet ; un prop plat, bas ou suspendu est déclaré `"solid": []`.
## Coordonnées d'un rectangle `[cx, cy, w, h]` en u, relatives au point d'appui du sprite (le pixel `foot` posé au
## centre de l'emprise) : x = vers le bas-droite de l'écran, y = vers le bas-gauche. Le sprite miroir (`flip`)
## échange les axes x et y. Utilisé par StageMap (props de biome, props fixes des variantes B, lampadaires).

const PATH := "res://data/prop_collision.json"

static var _table := {}
static var _loaded := false
static var _warned := {}


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if d is Dictionary and (d as Dictionary).get("props") is Dictionary:
		_table = (d as Dictionary)["props"]


## Vrai si le prop est déclaré (solide ou volontairement traversable).
static func has_entry(prop: String) -> bool:
	_ensure()
	return _table.has(prop)


## Rectangles de collision (px, relatifs au point d'appui, repère carte) ; vide = traversable ou non déclaré.
static func rects_px(prop: String, flip := false) -> Array[Rect2]:
	_ensure()
	var out: Array[Rect2] = []
	var e = _table.get(prop)
	if not e is Dictionary:
		if OS.is_debug_build() and not _warned.has(prop):
			_warned[prop] = true
			push_warning("prop_collision.json : aucune entrée pour « %s » (traversable)" % prop)
		return out
	for r in (e as Dictionary).get("solid", []):
		if not r is Array or (r as Array).size() != 4:
			continue
		var c := Vector2(float(r[0]), float(r[1]))
		var s := Vector2(float(r[2]), float(r[3]))
		if flip: # miroir horizontal à l'écran = échange des axes de la carte
			c = Vector2(c.y, c.x)
			s = Vector2(s.y, s.x)
		out.append(Rect2((c - s * 0.5) * Balance.UNIT_PX, s * Balance.UNIT_PX))
	return out


## Fondu quand le joueur passe derrière (entrée `fade`), `fallback` si le prop n'a pas d'entrée ou de clé.
static func fade(prop: String, fallback: bool) -> bool:
	_ensure()
	var e = _table.get(prop)
	if e is Dictionary and (e as Dictionary).has("fade"):
		return bool((e as Dictionary)["fade"])
	return fallback
