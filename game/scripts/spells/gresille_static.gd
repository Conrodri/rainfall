class_name GresilleStatic
extends RefCounted
## Registre de la Statique de Grésille (docs/fiches/gresille.md §5) : cumuls 1-5 portés par le KIT (instance_id du
## monstre -> {e, stacks, until}), jamais par Enemy. Tous les cumuls d'un monstre expirent ensemble, STATIC_S après la
## dernière application. Le Foudroiement (5 cumuls, prochain coup) est résolu ici : étourdissement 0,5 s (boss : +10 %
## de dégâts subis 2 s), cumuls remis à zéro, immunité ZAP_IMMUNE_S. L'horloge `now` est celle du kit (s).

const STATIC_MAX := 5
const STATIC_S := 6.0
const CRISP_AT := 3 ## cumuls pour être « crispé » (ralenti)
const CRISP_SLOW := 0.2
const ZAP_AT := 5
const ZAP_STUN_S := 0.5
const ZAP_BOSS_MULT := 1.1
const ZAP_BOSS_MOD_S := 2.0
const ZAP_IMMUNE_S := 2.5 ## audit 10/11/2026 (R3) : 1,5 -> 2,5, l'étourdissement d'une élite plafonne à ~19 %
const WET_STACKS := 2 ## cumuls par application sur un monstre mouillé
const BOSS_MOD_ID := &"gresille_foudre"

var _d := {} ## instance id -> {e: Node, stacks: int, until: float, immune: float}


func clear() -> void:
	_d.clear()


## Monstres portant au moins un cumul vivant à `now` (purge les morts, les expirés et les monstres du pool inactifs).
func live(now: float) -> Array:
	var out: Array = []
	for id in _d.keys():
		var r: Dictionary = _d[id]
		var e: Variant = r["e"]
		if not is_instance_valid(e) or e.get(&"active") == false:
			_d.erase(id)
			continue
		if float(r["until"]) <= now:
			if float(r.get("immune", 0.0)) <= now:
				_d.erase(id)
			else:
				r["stacks"] = 0
			continue
		if int(r["stacks"]) > 0:
			out.append(e)
	return out


func stacks(e: Node, now: float) -> int:
	if e == null or not is_instance_valid(e):
		return 0
	var r: Variant = _d.get(e.get_instance_id(), null)
	if r == null or float(r["until"]) <= now:
		return 0
	return int(r["stacks"])


func forget(e: Node) -> void:
	if e != null:
		_d.erase(e.get_instance_id())


## Ajoute `n` cumuls (plafonné) et rafraîchit les 6 s. Retourne les cumuls obtenus.
func add(e: Node, n: int, now: float) -> int:
	if e == null or not is_instance_valid(e) or n <= 0:
		return 0
	var id := e.get_instance_id()
	var r: Dictionary = _d.get(id, {"e": e, "stacks": 0, "until": 0.0, "immune": 0.0})
	var cur := int(r["stacks"]) if float(r["until"]) > now else 0
	r["e"] = e
	r["stacks"] = mini(cur + n, STATIC_MAX)
	r["until"] = now + STATIC_S
	_d[id] = r
	return int(r["stacks"])


## Consomme tous les cumuls : retourne leur nombre (la Décharge en lit n).
func consume(e: Node, now: float) -> int:
	var n := stacks(e, now)
	if n > 0:
		(_d[e.get_instance_id()] as Dictionary)["stacks"] = 0
	return n


## Foudroiement possible : 5 cumuls et hors immunité.
func can_zap(e: Node, now: float) -> bool:
	if stacks(e, now) < ZAP_AT:
		return false
	return float((_d[e.get_instance_id()] as Dictionary).get("immune", 0.0)) <= now


## Foudroie : cumuls à zéro, immunité, étourdi 0,5 s (un boss n'est jamais étourdi : +10 % de dégâts subis 2 s à la place).
## Faux (rien fait) si pas 5 cumuls ou immunité en cours.
func zap(e: Node, now: float) -> bool:
	if not can_zap(e, now):
		return false
	var r: Dictionary = _d[e.get_instance_id()]
	r["stacks"] = 0
	r["immune"] = now + ZAP_IMMUNE_S
	if e.has_method(&"add_damage_taken_mod") and (e.get(&"is_boss") == true):
		e.add_damage_taken_mod(BOSS_MOD_ID, ZAP_BOSS_MULT, ZAP_BOSS_MOD_S)
	elif e.has_method(&"stun"):
		e.stun(ZAP_STUN_S)
	return true


## Monstre le plus chargé (≥ `min_stacks`) à ≤ `range_px` de `origin` ; égalité : le plus proche. Null si aucun.
func most_stacked(origin: Vector2, range_px: float, now: float, min_stacks := 1, exclude: Node = null) -> Node2D:
	var best: Node2D = null
	var best_n := 0
	var best_d := INF
	for e: Node2D in live(now):
		if e == exclude:
			continue
		var d := e.global_position.distance_to(origin)
		if d > range_px:
			continue
		var n := stacks(e, now)
		if n < min_stacks:
			continue
		if n > best_n or (n == best_n and d < best_d):
			best = e
			best_n = n
			best_d = d
	return best
