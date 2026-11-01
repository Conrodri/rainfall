class_name Epreuve
extends Pillar
## Épreuve d'étage (prototype « Les Épreuves », docs/Boucle_Etage_Refonte.md §1 et §5.3). Remplace un petit pilier :
## c'est un Pillar (kind SMALL) dont `activate()` lance 30-40 s d'adresse au lieu d'invoquer le mini-boss. Le mini-boss
## du plan de run apparaît à la fin de l'épreuve (comme à l'activation d'un petit pilier) ; l'étage voit donc une
## Epreuve comme un petit pilier (minimap, objectifs, déverrouillage du gros pilier, rubis, journal de run).
##
## Cycle : READY -> activate() -> ACTIVE (épreuve en cours, `is_running()`) -> _resolve(note) : or versé selon la note,
## mini-boss invoqué -> mort du mini-boss -> DONE (Pillar._check_done). Un délai de sécurité (EPREUVE_BACKSTOP_S) clôt
## l'épreuve en « fait » : jamais bloqué. La zone de monstres (Balance.ZONE_SPAWN_MULT[&"epreuve"]) suit l'objet mobile ;
## l'or des kills dans cette zone est réduit (Balance.EPREUVE_ZONE_GOLD_MULT, voir zone_gold_mult) : l'or vient de la note.
## Sous-classes : EpreuveEscort (barque sur un tracé), EpreuveRitual (3 relais autour d'un cœur qui pulse).
## Visuels : placeholders (formes en code) tant que les sprites Codex ne sont pas livrés.

## Note forcée (mode test, panneau « Boucle d'étage »). &"" : la note se calcule.
static var forced_grade: StringName = &""

var verb: StringName = &"" ## &"escorte" | &"rituel"
var elapsed := 0.0 ## secondes d'épreuve écoulées (hors combat du mini-boss)
var resolved := false ## l'épreuve est terminée (note donnée, mini-boss invoqué)
var grade: StringName = &""
var gold_paid := 0.0 ## or nominal versé (avant le multiplicateur d'or du joueur)
var clean := true ## aucune faute (barque jamais immobilisée, aucun anneau reçu) : condition de la note « parfait »
var uses_sprite := true ## faux : aucun sprite de pilier (la barque est un polygone provisoire)
var _skip_run := false ## reprise de sauvegarde avec le mini-boss déjà invoqué : pas de seconde épreuve
var _overlay: EpreuveOverlay = null


func _ready() -> void:
	super._ready()
	add_to_group(&"epreuves")
	_attach_overlay.call_deferred()


func _attach_overlay() -> void:
	if not is_inside_tree() or _overlay != null:
		return
	_overlay = EpreuveOverlay.new()
	_overlay.epreuve = self
	var layer := AmbianceManager.telegraph_layer(get_tree())
	if layer != null:
		layer.add_child(_overlay)
	else:
		add_child(_overlay)
	_overlay.sync()


func _exit_tree() -> void:
	super._exit_tree()
	if _overlay != null and is_instance_valid(_overlay) and _overlay.get_parent() != self:
		_overlay.queue_free()
	_overlay = null


# --- À surcharger
func _begin() -> void:
	pass


## Un pas de l'épreuve (appelé tant qu'elle n'est pas résolue). Appeler _resolve() à la réussite.
func _run(_delta: float) -> void:
	pass


func _on_resolved() -> void:
	pass


## Progression 0..1 (HUD, tests).
func progress() -> float:
	return 0.0


## Dessin provisoire au sol (couche des télégraphes) : `c` est le Node2D qui dessine.
func draw_overlay(_c: Node2D) -> void:
	pass


func _extra_dict() -> Dictionary:
	return {}


func _extra_restore(_d: Dictionary) -> void:
	pass


## Zone de monstres de l'épreuve (px), centrée sur global_position.
func zone_radius() -> float:
	return Balance.EPREUVE_ZONE_RADIUS_U * Balance.UNIT_PX


func is_running() -> bool:
	return state == STATE_ACTIVE and not resolved


# --- Déroulé
func interact_label() -> String:
	return "Lancer l'épreuve"


## Lance l'épreuve (contact + « interagir », ou directement par les tests et le mode test).
func activate() -> bool:
	if state != STATE_READY:
		return false
	_set_state(STATE_ACTIVE)
	elapsed = 0.0
	clean = true
	grade = &""
	gold_paid = 0.0
	if _skip_run:
		_skip_run = false
		resolved = true
		_spawn_mini()
	else:
		resolved = false
		_begin()
		Events.epreuve_started.emit(verb)
	_tick_zone()
	queue_redraw()
	return true


func tick(delta: float) -> void:
	if state != STATE_ACTIVE:
		return
	if not resolved:
		elapsed += delta
		_run(delta)
		if not resolved and elapsed >= Balance.EPREUVE_BACKSTOP_S:
			_resolve(&"fait") # garde-fou : l'épreuve se clôt toute seule
	_tick_zone()
	_check_done()
	queue_redraw()


## Zone de monstres : suit le centre courant de l'épreuve, active jusqu'à la mort du mini-boss.
func _tick_zone() -> void:
	player_in_zone = is_inside_tree() and CoopRules.any_within(global_position, zone_radius(), true)
	_send_zone(true)


func _update_zone(_force: bool) -> void:
	_tick_zone()


func _send_zone(active: bool) -> void:
	var d := _director()
	if d != null:
		d.set_zone(zone_id, global_position, zone_radius(), active, &"epreuve" if (active and not resolved) else &"mini")
		_zone_sent = active


## Termine l'épreuve : note (calculée, `g` imposée, ou forced_grade), or versé, mini-boss invoqué. Public (mode test).
func finish_now(g: StringName = &"") -> void:
	if state == STATE_ACTIVE and not resolved:
		_resolve(g)


func _resolve(g: StringName = &"") -> void:
	if resolved:
		return
	resolved = true
	if TestMode.active and forced_grade != &"": # note imposée par le panneau du mode test
		grade = forced_grade
	elif g != &"":
		grade = g
	else:
		# coop : la cible « parfait » des épreuves partageables (Rituel) baisse de 8 % par joueur en plus (Balance)
		var t_mult := Balance.epreuve_target_party_mult(CoopRules.party_n()) if verb == &"rituel" else 1.0
		grade = Balance.epreuve_grade(verb, elapsed / maxf(t_mult, 0.01), clean)
	gold_paid = _pay()
	_on_resolved()
	Events.epreuve_finished.emit(verb, grade, elapsed, gold_paid)
	_spawn_mini()


## Or de la note, en P du début d'étage (Balance.epreuve_gold). Versé comme une prime (PickupManager.drop : pièces visibles,
## multiplicateur d'or du joueur) ; sans PickupManager (tests), crédité directement.
func _pay() -> float:
	var amount := Balance.epreuve_gold(grade, Balance.station_price_p(RunState.floor_start_d, RunState.stage))
	if amount <= 0.0:
		return 0.0
	var pm := get_tree().get_first_node_in_group(&"pickups") as PickupManager if is_inside_tree() else null
	if pm != null:
		pm.drop(global_position, PickupManager.KIND_GOLD, amount)
	else:
		CoopRules.credit_party_gold(amount, false) # sans PickupManager (tests) : la note est versée à chaque joueur
	return amount


## Invoque le mini-boss du plan de run (mêmes gestes que Pillar.activate pour un petit pilier).
func _spawn_mini() -> void:
	var d := _director()
	if d == null:
		push_warning("Epreuve : aucun Director (groupe `director`), pas de mini-boss.")
		return
	if boss_id != &"":
		d.set_meta(&"next_boss_id", boss_id)
		d.set_meta(&"next_mini_id", boss_id) # EnemyVisual.resolve_boss_id
	_boss = d.spawn_boss(&"mini", global_position + BOSS_OFFSET)
	if d.has_meta(&"next_mini_id"):
		d.remove_meta(&"next_mini_id")
	if _boss != null and boss_id != &"":
		_boss.set_meta(&"boss_id", boss_id)
	_send_zone(true)


## Multiplicateur d'or des kills en `pos` : Balance.EPREUVE_ZONE_GOLD_MULT dans la zone d'une épreuve en cours (jusqu'à
## la mort de son mini-boss), 1 ailleurs. Lu par PickupManager à chaque kill (au plus deux épreuves par étage).
static func zone_gold_mult(tree: SceneTree, pos: Vector2) -> float:
	for n in tree.get_nodes_in_group(&"epreuves"):
		var e := n as Epreuve
		if e != null and e.state == STATE_ACTIVE and pos.distance_to(e.global_position) <= e.zone_radius():
			return Balance.EPREUVE_ZONE_GOLD_MULT
	return 1.0


# --- Visuel
func _update_sprite() -> void:
	if uses_sprite:
		super._update_sprite()


func _draw() -> void:
	super._draw()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.sync()


# --- Sauvegarde
func to_dict() -> Dictionary:
	var d := super.to_dict()
	var e := {
		"verb": String(verb), "resolved": resolved, "elapsed": elapsed, "grade": String(grade), "clean": clean,
		"gold": gold_paid,
	}
	e.merge(_extra_dict())
	d["epreuve"] = e
	return d


## Épreuve en cours : reprise là où elle en était. Mini-boss déjà invoqué : revient à « prêt » et ne rejoue pas l'épreuve
## (le boss n'est pas sauvegardé, le pilier relance seulement le mini-boss).
func from_dict(d: Dictionary) -> void:
	super.from_dict(d)
	var e: Dictionary = d.get("epreuve", {}) if d.get("epreuve") is Dictionary else {}
	if e.is_empty():
		return
	elapsed = float(e.get("elapsed", 0.0))
	grade = StringName(String(e.get("grade", "")))
	clean = bool(e.get("clean", true))
	gold_paid = float(e.get("gold", 0.0))
	var was_active := StringName(d.get("state", "ready")) == STATE_ACTIVE
	if bool(e.get("resolved", false)):
		resolved = true
		_skip_run = state == STATE_READY # mini-boss à relancer sans épreuve
		return
	if was_active and state == STATE_READY: # épreuve interrompue : reprise du déroulé
		resolved = false
		_extra_restore(e)
		_set_state(STATE_ACTIVE)
		_tick_zone()


# --- Dessin provisoire
## Calque unique : les formes au sol de l'épreuve (tracé, corde, anneau du cœur) sur la couche des télégraphes.
class EpreuveOverlay extends Node2D:
	static var _unshaded: CanvasItemMaterial = null
	var epreuve: Epreuve = null

	func _init() -> void:
		name = &"EpreuveOverlay"
		light_mask = 0
		z_index = -1
		if _unshaded == null:
			_unshaded = CanvasItemMaterial.new()
			_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = _unshaded

	func sync() -> void:
		if epreuve == null or not is_instance_valid(epreuve) or not epreuve.is_inside_tree():
			return
		global_position = epreuve.global_position
		visible = epreuve.state != Pillar.STATE_DONE
		queue_redraw()

	func _draw() -> void:
		if epreuve != null and is_instance_valid(epreuve) and epreuve.is_inside_tree():
			epreuve.draw_overlay(self)
