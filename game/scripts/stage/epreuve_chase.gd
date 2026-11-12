class_name EpreuveChase
extends Epreuve
## Poursuite (docs/Design_Epreuves.md §3.3) : 6 bornes (EpreuveChasePost) espacées de 9-17 u le long d'un itinéraire ; la
## borne 0 est l'autel. « Interagir » sur l'autel pose une lumière dessus. Toutes les Balance.CHASE_JUMP_S s elle SAUTE vers une
## borne à 9-17 u de la courante (jamais celle qu'elle vient de quitter si un autre choix existe) après avoir vacillé
## Balance.CHASE_WARN_S. Un joueur vivant à <= Balance.CHASE_REACH_U de la borne allumée avant le saut marque 1 point (la borne reste
## allumée, « done »). Borne ratée : la lumière saute quand même, `misses` +1, plus de « parfait ». Balance.CHASE_POINTS points :
## la lumière se fixe, le mini-boss sort de terre dessous. `global_position` de l'épreuve = borne allumée : la zone de
## monstres et la flèche hors écran suivent la lumière. Coop : n'importe quel joueur compte ; la cible « parfait » ne baisse pas (la
## durée est fixée par les sauts, audit du 07/11/2026). Placeholders : losange par borne, disque de lumière et traînée sur l'overlay.

# Réglages : Balance.CHASE_* (docs/Design_Epreuves.md §8).

const TRAIL_S := 0.5 ## durée d'affichage de la traînée après un saut
const TINT_GOUFFRE := Color("#C27BFF") ## améthyste (Design_Etage2_Grotte.md §2)
const TINT_CRYPTES := Color("#BFF4FF") ## cristal (Design_Etages.md §3)

signal jumped(from_i: int, to_i: int) ## la lumière a sauté (borne quittée, borne atteinte)
signal point_scored(post_i: int, points: int) ## un joueur a rejoint la borne allumée

var posts: Array[EpreuveChasePost] = []
var post_pts: Array[Vector2] = [] ## positions des bornes, repère local de la carte
var lit := 0 ## borne allumée
var prev := -1 ## borne que la lumière vient de quitter
var points := 0
var misses := 0
var jump_left := 0.0 ## s avant le prochain saut
var done_posts: Array[int] = []
var _scored_here := false ## point déjà marqué sur la borne courante
var _trail_from := Vector2.ZERO ## début de la traînée (global)
var _trail_t := 0.0
var _rng := RandomNumberGenerator.new()
var _warn_played := false ## son d'avertissement déjà joué pour le saut en cours (une fois par saut)


## Poursuite sur les bornes `pts` (au moins 2, la première = autel ; repère local de la carte).
static func make(pts: Array) -> EpreuveChase:
	var e := EpreuveChase.new()
	for i in pts.size():
		e.post_pts.append(pts[i] as Vector2)
		var p := EpreuveChasePost.new()
		p.index = i
		e.posts.append(p)
	if not e.post_pts.is_empty():
		e.position = e.post_pts[0]
	for p in e.posts:
		e.add_child(p)
	e._reposition_posts()
	return e


func _init() -> void:
	super() # Pillar._init : corps de contact (voir Epreuve, en-tête)
	verb = &"poursuite"
	uses_sprite = false


func _ready() -> void:
	super._ready()
	var tint := TINT_CRYPTES if _biome_id() == &"cryptes" else TINT_GOUFFRE
	for p in posts:
		p.set_tint(tint)
		p.set_skin("crypts" if _biome_id() == &"cryptes" else "fog_forest")
	_refresh_posts()


## Biome fixé par StageManager avant add_child (champ de la base généralisée) ; vide sans lui.
func _biome_id() -> StringName:
	var b: Variant = get(&"biome")
	return StringName(String(b)) if b != null else &""


func progress() -> float:
	return clampf(float(points) / float(Balance.CHASE_POINTS), 0.0, 1.0)


# --- Bornes fixes pendant que l'épreuve bouge
func _reposition_posts() -> void:
	for i in posts.size():
		posts[i].position = post_pts[i] - position


func _move_to(i: int) -> void:
	lit = i
	position = post_pts[i]
	_reposition_posts()
	_refresh_posts()


func _refresh_posts() -> void:
	for i in posts.size():
		var s := EpreuveChasePost.STATE_IDLE
		if done_posts.has(i):
			s = EpreuveChasePost.STATE_DONE
		elif i == lit and (is_running() or resolved):
			s = EpreuveChasePost.STATE_LIT
		posts[i].set_state(s)


# --- Déroulé
func _begin() -> void:
	points = 0
	misses = 0
	prev = -1
	done_posts.clear()
	_scored_here = false
	_warn_played = false
	_trail_t = 0.0
	_rng.seed = hash([RunState.run_seed, RunState.stage, post_pts.size()])
	_move_to(0)
	jump_left = Balance.CHASE_JUMP_S
	_check_reach()


func _run(delta: float) -> void:
	_trail_t = maxf(_trail_t - delta, 0.0)
	_refresh_posts() # après une reprise de sauvegarde, la borne allumée n'était pas encore « en cours »
	_check_reach()
	if resolved:
		return
	jump_left -= delta
	if not _warn_played and is_warning():
		_warn_played = true
		Audio.play(&"chase_warn", global_position)
	if jump_left <= 0.0:
		if not _scored_here:
			misses += 1
			clean = false
			Audio.play(&"chase_miss", global_position)
		_jump()
		_check_reach()


## Un joueur vivant à <= Balance.CHASE_REACH_U de la borne allumée avant le saut = 1 point (une fois par borne allumée).
func _check_reach() -> void:
	if _scored_here or resolved or not is_inside_tree():
		return
	if not CoopRules.any_within(global_position, Balance.CHASE_REACH_U * Balance.UNIT_PX, true):
		return
	_scored_here = true
	points += 1
	if not done_posts.has(lit):
		done_posts.append(lit)
	_refresh_posts()
	if points < Balance.CHASE_POINTS: # le dernier point est couvert par le son de note
		Audio.play(&"chase_point", global_position)
	point_scored.emit(lit, points)
	if points >= Balance.CHASE_POINTS and is_running():
		_resolve() # note calculée par la base (cible × coop pour les verbes de EPREUVE_SHARED_VERBS ; pas la Poursuite)


## Lecture (tests, HUD) de la note que donnerait la base maintenant (même calcul que Epreuve._resolve).
func compute_grade() -> StringName:
	var mult := Balance.epreuve_target_party_mult(CoopRules.party_n()) if verb in Balance.EPREUVE_SHARED_VERBS else 1.0
	return Balance.epreuve_grade(verb, elapsed / maxf(mult, 0.01), clean)


## Borne cible du prochain saut : à [MIN, MAX] u de la courante, jamais la précédente ni une borne déjà marquée si
## possible ; sans candidat, la plus proche (hors courante).
func pick_next() -> int:
	var cands: Array[int] = []
	var fallback: Array[int] = []
	for i in post_pts.size():
		if i == lit:
			continue
		var d := post_pts[i].distance_to(post_pts[lit]) / Balance.UNIT_PX
		if d < Balance.CHASE_JUMP_MIN_U or d > Balance.CHASE_JUMP_MAX_U:
			continue
		if i != prev:
			fallback.append(i)
			if not done_posts.has(i):
				cands.append(i)
	if cands.is_empty():
		cands = fallback
	if cands.is_empty():
		var best := -1
		var best_d := INF
		for i in post_pts.size():
			if i == lit:
				continue
			var d2 := post_pts[i].distance_to(post_pts[lit])
			if d2 < best_d:
				best_d = d2
				best = i
		return best
	return cands[_rng.randi_range(0, cands.size() - 1)]


func _jump() -> void:
	var to_i := pick_next()
	jump_left = Balance.CHASE_JUMP_S
	_scored_here = false
	_warn_played = false
	if to_i < 0:
		return
	var from_i := lit
	_trail_from = global_position
	_trail_t = TRAIL_S
	prev = from_i
	_move_to(to_i)
	Audio.play(&"chase_jump", global_position)
	jumped.emit(from_i, to_i)


func is_warning() -> bool:
	return is_running() and not _scored_here and jump_left <= Balance.CHASE_WARN_S


func _on_resolved() -> void:
	_trail_t = 0.0
	_refresh_posts()


# --- Sauvegarde
func _extra_dict() -> Dictionary:
	return {"lit": lit, "prev": prev, "points": points, "misses": misses, "jump_left": jump_left, "done_posts": done_posts.duplicate(), "scored": _scored_here}


func _extra_restore(d: Dictionary) -> void:
	done_posts.clear()
	for i in d.get("done_posts", []):
		if int(i) >= 0 and int(i) < post_pts.size():
			done_posts.append(int(i))
	points = int(d.get("points", 0))
	misses = int(d.get("misses", 0))
	prev = int(d.get("prev", -1))
	jump_left = float(d.get("jump_left", Balance.CHASE_JUMP_S))
	_scored_here = bool(d.get("scored", false))
	_rng.seed = hash([RunState.run_seed, RunState.stage, post_pts.size(), points, misses])
	_trail_t = 0.0
	_move_to(clampi(int(d.get("lit", 0)), 0, maxi(post_pts.size() - 1, 0)))


# --- Dessin provisoire (overlay centré sur la lumière)
func draw_overlay(c: Node2D) -> void:
	if state == Pillar.STATE_DONE or (state == Pillar.STATE_READY and not resolved):
		return
	var u := Balance.UNIT_PX
	var col := TINT_CRYPTES if _biome_id() == &"cryptes" else TINT_GOUFFRE
	# traînée du dernier saut
	if _trail_t > 0.0:
		var a := _trail_t / TRAIL_S
		c.draw_line(c.to_local(_trail_from), Vector2.ZERO, Color(col.r, col.g, col.b, 0.7 * a), 5.0 * a + 1.0)
	if is_running():
		# anneau de portée de la borne allumée, jauge du saut
		var ring_col := Color(col.r, col.g, col.b, 0.25 if _scored_here else 0.7)
		if not EpreuveSprites.draw_ring(c, "ring_zone.png", Vector2.ZERO, Balance.CHASE_REACH_U * u, ring_col):
			c.draw_arc(Vector2.ZERO, Balance.CHASE_REACH_U * u, 0.0, TAU, 40, ring_col, 3.0)
		var fill := clampf(jump_left / Balance.CHASE_JUMP_S, 0.0, 1.0)
		c.draw_arc(Vector2.ZERO, 56.0, -PI * 0.5, -PI * 0.5 + TAU * fill, 40, Color(1.0, 0.85, 0.5, 0.85), 4.0)
	# lumière : disque 0,6 u, vacille à 6 Hz avant le saut
	var alpha := 1.0
	if is_warning():
		alpha = 1.0 if int(floor(elapsed * 12.0)) % 2 == 0 else 0.25
	var skin := "crypts" if _biome_id() == &"cryptes" else "fog_forest"
	if EpreuveSprites.draw_light(c, skin, Vector2.ZERO, 2.4 * u, alpha): # lot EP-I (feu follet / éclat Codex)
		return
	c.draw_circle(Vector2.ZERO, 0.6 * u * 1.6, Color(col.r, col.g, col.b, 0.18 * alpha))
	c.draw_circle(Vector2.ZERO, 0.6 * u, Color(1.0, 1.0, 1.0, 0.9 * alpha).lerp(Color(col.r, col.g, col.b, 0.9 * alpha), 0.35))
