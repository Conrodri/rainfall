class_name DodgeMove
extends RefCounted
## Esquive du joueur : stratégie interchangeable (docs/Design_Esquives.md). Le joueur (Player) ne connaît que cette
## interface ; le kit du personnage choisit l'implémentation par `make_dodge()` (sinon `CharacterData.dodge_kind`,
## sinon la roulade `RollDodge`). Une esquive gère elle-même : départ, pas par pas (déplacement balayé, jamais à
## travers un mur ni hors de la zone praticable), fin, recharge / charges, invulnérabilité et état pour le HUD.
##
## Hooks de kit lus par les esquives (tous facultatifs) : `can_dodge()`, `dodge_distance_u()`, `dodge_speed_u()`,
## `dodge_charges()`, `dodge_cooldown_s()`, `dodge_motion_dir(dir)`, `dodge_ghosts()`, `dodge_ghost_color()`,
## `dodge_label()`, `dodge_sound() -> [id, db, pitch]`, `on_dodge_start(dir)`, `on_dodge_end(from, to)`.
## Mode test : `TestMode.cdr_full` met la recharge à zéro (et les charges au maximum) comme pour les sorts.

const KIND_ROLL := &"roll"
const KIND_BLINK := &"blink"
const KIND_SLIDE := &"slide"

## Son par défaut (souffle de braise bref) : un kit le remplace par `dodge_sound()`.
const DEFAULT_SOUND := [&"spell.cendres.cast_light", -4.0, 1.3]
const DEFAULT_LABEL := "Roulade"

var player: CharacterBody2D = null
var kit: Node = null
var active := false
var dir := Vector2.ZERO ## sens réel du déplacement en cours
var cooldown_left := 0.0
var cooldown_total := Balance.DODGE_COOLDOWN_S
var invuln_left := 0.0 ## invulnérabilité restante (s)
var start_pos := Vector2.ZERO


## Esquive du personnage : le kit (`make_dodge()`), sinon le genre déclaré par CharacterData, sinon la roulade.
static func make(p: CharacterBody2D, k: Node, character: CharacterData) -> DodgeMove:
	var d: DodgeMove = null
	if k != null and k.has_method(&"make_dodge"):
		d = k.make_dodge()
	if d == null:
		var kind: StringName = character.dodge_kind if character != null else KIND_ROLL
		match kind:
			KIND_BLINK:
				d = BlinkDodge.new()
			KIND_SLIDE:
				d = SlideDodge.new()
			_:
				d = RollDodge.new()
	d.setup(p, k)
	return d


func setup(p: CharacterBody2D, k: Node) -> void:
	player = p
	kit = k
	cooldown_total = _hook_float(&"dodge_cooldown_s", Balance.DODGE_COOLDOWN_S)


## Genre (tests, HUD).
func kind() -> StringName:
	return KIND_ROLL


## Libellé du bouton (initiale affichée, nom dans la bulle).
func label() -> String:
	if kit != null and kit.has_method(&"dodge_label"):
		return str(kit.dodge_label())
	return DEFAULT_LABEL


## Prête à partir : ni en recharge, ni déjà en cours (une esquive à charges peut se relancer : voir RollDodge).
func can_start() -> bool:
	return not active and cooldown_left <= 0.0


## Lance l'esquive vers `d` (normalisé, non nul). Faux si impossible. Les sous-classes posent `active`, `dir`,
## `invuln_left`, le son et le hook du kit.
func start(_d: Vector2) -> bool:
	return false


## Un pas de physique pendant l'esquive (appelé par Player._physics_process tant que `active`).
func step(_delta: float) -> void:
	pass


## Bouton relâché (esquives au maintien seulement).
func release() -> void:
	pass


## Appui maintenu lu (Averse) : le joueur relaie le relâcher.
func is_hold() -> bool:
	return false


## Pendant l'esquive, le déplacement normal (joystick, locomotion du kit) reste-t-il permis ? (reformation d'Ardent)
func allows_move() -> bool:
	return false


## Recharge, charges, invulnérabilité : chaque image, esquive en cours ou non.
func tick(delta: float) -> void:
	invuln_left = maxf(invuln_left - delta, 0.0)
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if TestMode.cdr_full:
		cooldown_left = 0.0


func is_invulnerable() -> bool:
	return invuln_left > 0.0


## Fraction restante de l'esquive en cours (1 au départ, 0 à la fin) : arcs de Rictus et Rainette.
func progress_left() -> float:
	return 0.0


## Durée totale de l'esquive en cours (s).
func duration_s() -> float:
	return 0.0


## Longueur qui partirait maintenant (u).
func distance_u() -> float:
	return player.dodge_distance_u() if player != null else Balance.DODGE_DISTANCE_U


## État pour le HUD (DodgeButton) : recharge, charges, maintien, libellé.
func ui_state() -> Dictionary:
	return {"remaining": cooldown_left, "total": cooldown_total, "active": active,
		"charges": -1, "max_charges": 0, "hold": is_hold(), "label": label(), "kind": kind()}


## Recharge à zéro et esquive arrêtée (tests, changement de personnage).
func reset() -> void:
	active = false
	cooldown_left = 0.0
	invuln_left = 0.0


## Esquive interrompue (mort, changement de personnage) : l'état visuel du joueur est rendu.
func abort() -> void:
	reset()


# --- Aides communes ---------------------------------------------------------------------------------

func _hook_float(name: StringName, fallback: float) -> float:
	if kit != null and kit.has_method(name):
		return float(kit.call(name))
	return fallback


func _hook_bool(name: StringName, fallback: bool) -> bool:
	if kit != null and kit.has_method(name):
		return bool(kit.call(name))
	return fallback


## Sens réel du déplacement : le kit peut l'inverser (bond arrière de Rainette, repli de Vigie).
func _motion_dir(d: Vector2) -> Vector2:
	if kit != null and kit.has_method(&"dodge_motion_dir"):
		var m: Vector2 = kit.dodge_motion_dir(d)
		if m.length_squared() > 0.0001:
			return m.normalized()
	return d


func _play_sound() -> void:
	var s: Array = DEFAULT_SOUND
	if kit != null and kit.has_method(&"dodge_sound"):
		var v: Variant = kit.dodge_sound()
		if v is Array and (v as Array).size() >= 3:
			s = v
	if player != null:
		Audio.play(StringName(s[0]), player.global_position, float(s[1]), float(s[2]))


## Déplacement balayé d'un pas : les murs arrêtent, le reste glisse le long ; puis maintien dans la zone
## praticable (bords de carte sans collision, vide hors carte). Rend la collision frontale (null sinon).
func _sweep(motion: Vector2) -> KinematicCollision2D:
	var col := player.move_and_collide(motion)
	if col != null:
		var rest := col.get_remainder().slide(col.get_normal())
		if rest.length_squared() > 0.01:
			player.move_and_collide(rest)
	player.keep_walkable()
	return col


func _on_start_hook(d: Vector2) -> void:
	if kit != null and kit.has_method(&"on_dodge_start"):
		kit.on_dodge_start(d)


func _on_end_hook() -> void:
	if kit != null and kit.has_method(&"on_dodge_end"):
		kit.on_dodge_end(start_pos, player.global_position)
