class_name BossPace
extends RefCounted
## Rythme commun des coups de boss d'étage et de mini-boss (retour joueur 22/10/2026 : « les monstres au
## corps à corps ne marquent pas le temps d'arrêt sur les coups, même les boss ») :
## 1. ARMEMENT planté : le boss s'arrête net, pose ou télégraphe déjà présent ;
## 2. IMPACT à la frame d'impact : court arrêt sur image du corps, secousse de caméra pour les gros coups ;
## 3. RÉCUPÉRATION immobile : fenêtre de punition lisible (aucune marche, aucun nouveau coup).
## Les ruées et bonds gardent leur mouvement pendant l'action (étape ACTIVE) mais s'arrêtent net avant
## (armement) et après (récupération). Valeurs : Balance.BOSS_PACE_* (docs/Comportements_Monstres.md).
##
## Usage dans un cerveau (une instance par cerveau, `var pace: BossPace`) :
##   pace = BossPace.new(e)                          # _init
##   pace.tick(delta)                                # en tête de tick() (timers, fin de l'arrêt sur image)
##   _dur = BossPace.windup(&"spell", phase, natural) # durée d'armement (catégorie, phase, plancher propre)
##   pace.wind(&"spell")                             # début d'armement (le cerveau rend Vector2.ZERO)
##   pace.act()                                      # ruée / bond lancés : mouvement propre du cerveau
##   pace.strike(&"spell", phase)                    # frame d'impact : arrêt sur image + récupération
##   pace.strike(&"auto", phase, false)              # coup intermédiaire d'un enchaînement (reste planté)
##   pace.cancel()                                   # coup annulé (transition de phase…)
##   CHASE : `if pace.recovering(): _face(dir); return Vector2.ZERO` (immobile, aucun nouveau coup)
##   owns_motion() : `... or pace.planted()`         # ni marche, ni séparation de foule pendant le coup
##   ignores_knockback() : `pace.planted()`          # super-armure : un recul ferait glisser le boss planté

enum P { FREE, WIND, ACTIVE, RECOVER }

var e: Enemy
var stage := P.FREE
var kind := &""
var recover_left := 0.0
var recover_total := 0.0
var wind_count := 0 ## tests : armements commencés
var recover_count := 0 ## tests : récupérations commencées
var last_recover := 0.0 ## tests : durée de la dernière récupération
var _freeze_left := 0.0


func _init(enemy: Enemy) -> void:
	e = enemy


## Valeur d'une table [p1, p2, p3] pour la phase (mini-boss : 1-2), bornée au dernier élément.
static func _by_phase(table: Dictionary, k: StringName, phase: int) -> float:
	var arr: Array = table.get(k, table[&"spell"])
	return float(arr[clampi(phase - 1, 0, arr.size() - 1)])


## Durée d'armement d'un coup de la catégorie `k` (auto, mini_auto, spell, heavy, charge, combo) à cette phase.
## `at_least` : plancher propre au coup (temps naturel jusqu'à la frame d'impact de l'anim…).
static func windup(k: StringName, phase: int, at_least := 0.0) -> float:
	return maxf(_by_phase(Balance.BOSS_PACE_WINDUP, k, phase), at_least)


## Durée de récupération immobile après un coup de la catégorie `k` à cette phase.
static func recover_s(k: StringName, phase: int) -> float:
	return maxf(_by_phase(Balance.BOSS_PACE_RECOVER, k, phase), Balance.BOSS_PACE_RECOVER_MIN_S)


## À appeler en tête du tick du cerveau.
func tick(delta: float) -> void:
	if _freeze_left > 0.0:
		_freeze_left -= delta
		# réaffirmé à chaque pas : EnemyVisual.boss_tick (avant le cerveau) peut franchir l'impact une image plus tard
		_set_frozen(_freeze_left > 0.0)
	if stage == P.RECOVER:
		recover_left -= delta
		if recover_left <= 0.0:
			recover_left = 0.0
			stage = P.FREE


## Début d'armement : le boss se plante (recul en cours annulé).
func wind(k: StringName) -> void:
	kind = k
	stage = P.WIND
	wind_count += 1
	recover_left = 0.0
	e._kb = Vector2.ZERO
	if _freeze_left > 0.0: # nouvel armement pendant l'arrêt sur image : il démarre à sa propre vitesse
		_freeze_left = 0.0
		_set_frozen(false)


## Ruée / bond : mouvement propre du cerveau pendant l'action.
func act() -> void:
	stage = P.ACTIVE


## Frame d'impact : arrêt sur image du corps, secousse (gros coups), puis récupération immobile
## (`last` faux : coup intermédiaire d'un enchaînement, le boss reste planté en armement).
## `recover` >= 0 impose la durée de récupération (bornée au plancher Balance.BOSS_PACE_RECOVER_MIN_S).
func strike(k: StringName, phase: int, last := true, recover := -1.0) -> void:
	kind = k
	impact(k)
	if not last:
		stage = P.WIND
		return
	recover_for(recover_s(k, phase) if recover < 0.0 else maxf(recover, Balance.BOSS_PACE_RECOVER_MIN_S))


## Récupération immobile de `s` secondes (sans impact : fin d'un sort sans coup, ruée arrêtée…).
func recover_for(s: float) -> void:
	stage = P.RECOVER
	recover_total = s
	recover_left = s
	last_recover = s
	recover_count += 1
	e._kb = Vector2.ZERO
	var vis := e.visual as EnemyVisual
	if vis != null:
		vis.set_action(&"idle") # fin du coup tenue en place, puis repos (jamais la boucle de course)


## Arrêt sur image et secousse de l'impact (sans changer d'étape).
func impact(k: StringName) -> void:
	var fr := float(Balance.BOSS_PACE_FREEZE_S.get(k, 0.0))
	if fr > 0.0 and GameSettings.hitstop_enabled():
		_freeze_left = fr
		_set_frozen(true)
	var px := float(Balance.BOSS_PACE_SHAKE_PX.get(k, 0.0))
	if px > 0.0:
		Haptics.pulse(Haptics.Kind.BOSS_IMPACT)
		var n: Node = e
		while n != null:
			if n.has_method(&"shake"):
				n.shake(px, Balance.BOSS_PACE_SHAKE_HZ, Balance.BOSS_PACE_SHAKE_S)
				break
			n = n.get_parent()


## Coup annulé (transition de phase, mort…) : libre, corps rendu à sa vitesse.
func cancel() -> void:
	stage = P.FREE
	recover_left = 0.0
	if _freeze_left > 0.0:
		_freeze_left = 0.0
		_set_frozen(false)


## Récupération immobile en cours : ni marche ni nouveau coup.
func recovering() -> bool:
	return stage == P.RECOVER


## Armement ou récupération : le boss ne bouge pas d'un pixel (owns_motion, ignores_knockback).
func planted() -> bool:
	return stage == P.WIND or stage == P.RECOVER


## Étape lisible (tests, debug) : &"free", &"wind", &"active", &"recover".
func stage_name() -> StringName:
	return [&"free", &"wind", &"active", &"recover"][stage]


func _set_frozen(on: bool) -> void:
	var vis := e.visual as EnemyVisual
	if vis == null or not is_instance_valid(vis):
		return
	if on or not vis._boss_sprite or vis._sprite == null:
		vis.set_frozen(on)
		return
	# dégel : vitesse que l'anim courante doit avoir (un nouvel armement peut avoir démarré pendant le gel :
	# pose tenue à 0 ou vitesse calée sur son impact), jamais 1 d'office
	vis._sprite.speed_scale = vis._boss_speed(vis._sprite.animation)
