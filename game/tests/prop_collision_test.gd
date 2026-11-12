extends Node
## Collision des props de décor (data/prop_collision.json, PropCollision) :
## - tout prop posé (props.json de biome, props_fixed des cartes, lampadaires) a une entrée dans la table ;
## - la collision épouse le bas visible : chaque losange (rectangle de la carte projeté à l'écran) reste dans la boîte
##   alpha du sprite, à MARGE_PX près (aucune marge invisible), et son sommet bas touche le bas du sprite ;
## - un prop solide a au moins un rectangle non dégénéré ; le miroir échange les axes ;
## - posé dans une vraie carte : la forme est un RectangleShape2D (couche 1) centré sur le point d'appui du sprite.
## godot --headless --path game res://tests/prop_collision_test.tscn  -> RESULT: OK

const MARGE_PX := 10.0 ## ~0,15 u en pixels de rendu (64 px/u horizontalement, 32 px/u verticalement)
const BIOME_DIRS := {"foret": "fog_forest", "cite": "rust_city", "cryptes": "crypts", "source": "source", "terrasses": "terraces"}

var _fails := 0
var _checked := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _ready() -> void:
	var placed := _placed_props()
	for key in placed:
		_test_prop(key as String, placed[key])
	_check(PropCollision.rects_px("noria").size() == 2, "noria : socle + roue attendus")
	_check(PropCollision.rects_px("rails").is_empty() and PropCollision.has_entry("rails"), "rails : traversables et déclarés")
	var a := PropCollision.rects_px("noria")
	var b := PropCollision.rects_px("noria", true)
	_check(is_equal_approx(b[0].get_center().x, a[0].get_center().y) and is_equal_approx(b[0].size.x, a[0].size.y), "miroir : axes non échangés")
	print("props vérifiés : ", _checked)
	print("RESULT: ", "OK" if _fails == 0 else "FAILED (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## {"dir/nom": foot [x, y]} pour tous les props que le code peut poser.
func _placed_props() -> Dictionary:
	var out := {}
	for d in BIOME_DIRS.values():
		var man_path := "res://assets/sprites/props/%s/props.json" % d
		if not FileAccess.file_exists(man_path):
			continue
		var man = JSON.parse_string(FileAccess.get_file_as_string(man_path))
		for pr in (man as Dictionary).get("props", []):
			if not ResourceLoader.exists("res://assets/sprites/props/%s/%s.png" % [d, pr["name"]]):
				continue
			if bool(pr.get("flat", false)):
				continue # décalque plat au sol (rig TOP), jamais de collision
			out["%s/%s" % [d, pr["name"]]] = pr.get("foot", null)
		for pr in (man as Dictionary).get("fixed", []):
			out["%s/%s" % [d, pr["name"]]] = pr.get("foot", null)
	for f in DirAccess.get_files_at("res://data/maps"):
		if not f.ends_with(".json"):
			continue
		var m = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + f))
		if not m is Dictionary or not (m as Dictionary).has("props_fixed"):
			continue
		var d: String = BIOME_DIRS[String(m["biome"])]
		for pr in m["props_fixed"]:
			out["%s/%s" % [d, pr["name"]]] = pr.get("foot", null)
	for k in StageMap.LIGHT_PROPS:
		for suffix in ["_se", "_sw"]:
			out["rust_city/%s%s" % [k, suffix]] = StageMap.LIGHT_PROPS[k]["foot"]
	return out


func _test_prop(key: String, foot_v: Variant) -> void:
	var parts := key.split("/")
	var name := parts[1]
	_check(PropCollision.has_entry(name), "%s : aucune entrée dans prop_collision.json" % key)
	var rects := PropCollision.rects_px(name)
	if rects.is_empty():
		return
	var tex := load("res://assets/sprites/props/%s.png" % key) as Texture2D
	if tex == null:
		_check(false, "%s : texture absente" % key)
		return
	_checked += 1
	var img := tex.get_image()
	var used := img.get_used_rect()
	var foot := Vector2(tex.get_width() * 0.5, tex.get_height() * 0.85)
	if foot_v is Array:
		foot = Vector2(float(foot_v[0]), float(foot_v[1]))
	var low := -INF
	var left := INF
	var right := -INF
	for r in rects:
		_check(r.size.x >= 0.2 * Balance.UNIT_PX and r.size.y >= 0.2 * Balance.UNIT_PX, "%s : rectangle dégénéré %s" % [key, r])
		for c in [r.position, r.position + Vector2(r.size.x, 0.0), r.position + r.size, r.position + Vector2(0.0, r.size.y)]:
			var u: Vector2 = c / Balance.UNIT_PX # u de la carte -> pixels de rendu : x = (dx - dy) * 64, y = (dx + dy) * 32
			var p := foot + Vector2((u.x - u.y) * 64.0, (u.x + u.y) * 32.0)
			low = maxf(low, p.y)
			left = minf(left, p.x)
			right = maxf(right, p.x)
	var box := Rect2(used).grow(MARGE_PX)
	_check(left >= box.position.x and right <= box.end.x, "%s : collision hors de la largeur visible (%.0f..%.0f px, sprite %d..%d)" % [key, left, right, used.position.x, used.end.x])
	_check(low <= box.end.y, "%s : collision sous le bas visible (%.0f px, sprite %d)" % [key, low, used.end.y])
	_check(low >= used.end.y - 0.7 * 64.0, "%s : collision loin au-dessus du bas du sprite (%.0f px, sprite %d)" % [key, low, used.end.y])
