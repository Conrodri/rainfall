class_name EpreuveGeom
extends RefCounted
## Géométrie des Épreuves (docs/Design_Epreuves.md §7.1) : lecture et validation des clés JSON de carte par verbe,
## conversion u (repère carte, origine en haut à gauche) -> repère local de la carte, distances et points d'ancrage.
## Entièrement statique. Une carte dont une clé manque ou est invalide donne {} (étage classique, jamais de plantage).
##
## Forme d'une géométrie (repère local, px), une par verbe :
##   escorte   {"path": PackedVector2Array}
##   rituel    {"heart": Vector2, "relays": Array[Vector2]}
##   poursuite {"posts": Array[Vector2]}                          (posts[0] = autel de départ)
##   veine     {"path": PackedVector2Array, "closed": bool}
##   tenue     {"pos": Vector2, "sides": Array[Vector2]}          (côtés = vecteurs unitaires, repère local)
## Une « géométrie en u » (parse_u) a la même forme avec des Vector2 en u de carte (côtés de la Tenue non convertis).

const UNIT := 64.0
const MAPS_DIR := "res://data/maps"


## Géométries des `verbs` pour la carte courante : {verbe: géométrie locale}, {} si un verbe n'a pas sa clé valide.
static func load_for(map: StageMap, map_id: String, verbs: Array) -> Dictionary:
	var path := "%s/%s.json" % [MAPS_DIR, map_id]
	if map == null or verbs.is_empty() or not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or not data.has("size_px"):
		return {}
	var half := Vector2(float(data["size_px"][0]), float(data["size_px"][1])) * 0.5
	var raw := parse_u(data, verbs, map_id)
	if raw.is_empty():
		return {}
	return to_local(raw, map, half)


## Géométries en u de carte des `verbs` lues dans le dictionnaire JSON de la carte ; {} si l'une est absente ou invalide
## (avertissement avec `map_id`).
static func parse_u(data: Dictionary, verbs: Array, map_id: String = "") -> Dictionary:
	var out := {}
	for v in verbs:
		var g := _parse_verb(String(v), data)
		var err := validate(String(v), g) if not g.is_empty() else "clé absente"
		if err != "":
			push_warning("EpreuveGeom : carte %s, verbe %s : %s (étage classique)." % [map_id, String(v), err])
			return {}
		out[StringName(v)] = g
	return out


static func _vec(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _vec_list(a) -> Array:
	var out: Array = []
	if a is Array:
		for p in a:
			if p is Array and (p as Array).size() >= 2:
				out.append(_vec(p))
	return out


static func _parse_verb(verb: String, data: Dictionary) -> Dictionary:
	match verb:
		"escorte":
			if not data.has("escort_path"):
				return {}
			return {"path": PackedVector2Array(_vec_list(data["escort_path"]))}
		"rituel":
			var rit = data.get("ritual")
			if not (rit is Dictionary) or not (rit as Dictionary).has("heart"):
				return {}
			var hp = rit["heart"]
			if not (hp is Array) or (hp as Array).size() < 2:
				return {}
			return {"heart": _vec(hp), "relays": _vec_list(rit.get("relays", []))}
		"poursuite":
			if not data.has("chase_posts"):
				return {}
			return {"posts": _vec_list(data["chase_posts"])}
		"veine":
			if not data.has("vein_path"):
				return {}
			return {"path": PackedVector2Array(_vec_list(data["vein_path"])), "closed": bool(data.get("vein_closed", false))}
		"tenue":
			var h = data.get("hold")
			if not (h is Dictionary) or not (h as Dictionary).has("pos"):
				return {}
			var pp = h["pos"]
			if not (pp is Array) or (pp as Array).size() < 2:
				return {}
			return {"pos": _vec(pp), "sides": _vec_list(h.get("sides", []))}
	return {}


## Longueur (u ou px, selon l'unité des points) d'une polyligne, refermée si `closed`.
static func path_length(pts: PackedVector2Array, closed: bool) -> float:
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	if closed and pts.size() > 2:
		total += pts[pts.size() - 1].distance_to(pts[0])
	return total


## Contrôle de structure d'une géométrie EN U ; "" si valide, sinon le motif du refus (Balance.CHASE_*, VEIN_*, HOLD_*,
## RITUAL_RELAYS). La praticabilité des cases se contrôle en jeu (tests/epreuve_test).
static func validate(verb: String, g: Dictionary) -> String:
	match verb:
		"escorte":
			if (g["path"] as PackedVector2Array).size() < 2:
				return "tracé de moins de 2 points"
		"rituel":
			if (g["relays"] as Array).size() != Balance.RITUAL_RELAYS:
				return "il faut %d relais" % Balance.RITUAL_RELAYS
		"poursuite":
			var posts: Array = g["posts"]
			if posts.size() != Balance.CHASE_POSTS:
				return "il faut %d bornes" % Balance.CHASE_POSTS
			for i in posts.size():
				var near := false
				for j in posts.size():
					var d: float = (posts[i] as Vector2).distance_to(posts[j])
					if i != j and d >= Balance.CHASE_JUMP_MIN_U and d <= Balance.CHASE_JUMP_MAX_U:
						near = true
						break
				if not near:
					return "la borne %d n'a aucune voisine à %.0f-%.0f u" % [i, Balance.CHASE_JUMP_MIN_U, Balance.CHASE_JUMP_MAX_U]
		"veine":
			var pts: PackedVector2Array = g["path"]
			if pts.size() < 2:
				return "tracé de moins de 2 points"
			var len := path_length(pts, bool(g["closed"]))
			if len < Balance.VEIN_LOOP_MIN_U - 0.001 or len > Balance.VEIN_LOOP_MAX_U + 0.001:
				return "longueur %.1f u hors de %.0f-%.0f u" % [len, Balance.VEIN_LOOP_MIN_U, Balance.VEIN_LOOP_MAX_U]
		"tenue":
			var sides: Array = g["sides"]
			if sides.size() != Balance.HOLD_SIDES:
				return "il faut %d côtés" % Balance.HOLD_SIDES
			for s in sides:
				if (s as Vector2).length() < 0.001:
					return "côté nul"
		_:
			return "verbe inconnu"
	return ""


## u de carte -> repère local de la carte (`half` = moitié de size_px, comme les marqueurs).
static func _to_local_point(map: StageMap, half: Vector2, u: Vector2) -> Vector2:
	return map.from_map(u * UNIT - half)


## Géométries en u -> géométries locales.
static func to_local(raw: Dictionary, map: StageMap, half: Vector2) -> Dictionary:
	var out := {}
	for k in raw.keys():
		var g: Dictionary = raw[k]
		var r := {}
		match String(k):
			"escorte":
				r["path"] = _local_path(g["path"], map, half)
			"rituel":
				r["heart"] = _to_local_point(map, half, g["heart"])
				var rl: Array = []
				for u in g["relays"]:
					rl.append(_to_local_point(map, half, u))
				r["relays"] = rl
			"poursuite":
				var ps: Array = []
				for u in g["posts"]:
					ps.append(_to_local_point(map, half, u))
				r["posts"] = ps
			"veine":
				r["path"] = _local_path(g["path"], map, half)
				r["closed"] = g["closed"]
			"tenue":
				r["pos"] = _to_local_point(map, half, g["pos"])
				var origin := map.from_map(Vector2.ZERO)
				var sd: Array = []
				for d in g["sides"]:
					sd.append((map.from_map((d as Vector2).normalized() * UNIT) - origin).normalized())
				r["sides"] = sd
		out[k] = r
	return out


static func _local_path(u_pts: PackedVector2Array, map: StageMap, half: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for u in u_pts:
		pts.append(_to_local_point(map, half, u))
	return pts


## Point d'ancrage de l'épreuve (position du Pillar avant mouvement) : départ du tracé, cœur, autel, cloche.
static func anchor(verb, g: Dictionary) -> Vector2:
	match String(verb):
		"escorte", "veine":
			return (g["path"] as PackedVector2Array)[0]
		"rituel":
			return g["heart"]
		"poursuite":
			return (g["posts"] as Array)[0]
		"tenue":
			return g["pos"]
	return Vector2.ZERO


## Distance (px) de `p` à l'objet d'épreuve : tracé (escorte, veine, refermé si `closed`), cœur et relais, bornes, cloche.
static func dist(verb, g: Dictionary, p: Vector2) -> float:
	var best := INF
	match String(verb):
		"escorte", "veine":
			var pts: PackedVector2Array = g["path"]
			for i in range(pts.size() - 1):
				best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
			if bool(g.get("closed", false)) and pts.size() > 2:
				best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[pts.size() - 1], pts[0])))
		"rituel":
			best = p.distance_to(g["heart"])
			for r in g["relays"]:
				best = minf(best, p.distance_to(r))
		"poursuite":
			for b in g["posts"]:
				best = minf(best, p.distance_to(b))
		"tenue":
			best = p.distance_to(g["pos"])
	return best


## Points à contrôler pour la praticabilité (repère local) : tracé échantillonné tous les `step` px, cœur, relais, bornes,
## cloche et, pour la Tenue, les points de chaque côté à 6 et 10 u.
static func sample_points(verb, g: Dictionary, step: float = 32.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	match String(verb):
		"escorte", "veine":
			var pts: PackedVector2Array = g["path"]
			var n := pts.size()
			var last := n if (bool(g.get("closed", false)) and n > 2) else n - 1
			for i in last:
				var a := pts[i]
				var b := pts[(i + 1) % n]
				var cnt := maxi(int(ceil(a.distance_to(b) / step)), 1)
				for k in cnt:
					out.append(a.lerp(b, float(k) / float(cnt)))
			if last == n - 1:
				out.append(pts[n - 1])
		"rituel":
			out.append(g["heart"])
			for r in g["relays"]:
				out.append(r)
		"poursuite":
			for b in g["posts"]:
				out.append(b)
		"tenue":
			out.append(g["pos"])
			for s in g["sides"]:
				out.append((g["pos"] as Vector2) + (s as Vector2) * 6.0 * UNIT)
				out.append((g["pos"] as Vector2) + (s as Vector2) * 10.0 * UNIT)
	return out
