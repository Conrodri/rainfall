class_name UnlockTracker
extends Node
## Mesures de run lues par les conditions de déblocage des personnages (Profile.UNLOCK_ON_RUN / UNLOCK_ON_OBJECTIVE,
## docs/Design_Personnages.md). Créé par l'autoload Profile ; tout passe par le bus Events, aucun autre système n'est touché
## (hors `Enemy.last_hit_via`, posé par les zones persistantes et les familiers). Rien n'est mesuré hors run, en mode test
## (TestMode / Profile.sandbox) ni pendant une pause. Mémoire seulement : une run reprise après « Sauvegarder et quitter »
## repart de zéro. Coop locale : tous les joueurs comptent pour le profil (comme le journal de run).
##
## Mesures (metrics) :
## - water_s : secondes passées dans l'eau (case d'eau de la carte ou flaque d'Averse), meilleur joueur Averse de la run ;
## - zone_kills : monstres dont le dernier coup vient d'une zone persistante (zone_effect, quel que soit le personnage) ;
## - familiar_elite_kills : élites dont le dernier coup vient d'un familier (mottes de Bourbe, doublures de Rictus) ;
## - far_kills : monstres tués à plus de FAR_KILL_U du tueur ;
## - clean_floors : étages terminés sans aucun coup de contact subi (source = un monstre) ;
## - light_boss_kills : boss d'étage tués en ayant subi au plus LIGHT_BOSS_MAX_HITS coups pendant le combat.
## - lightning_kills : monstres dont le dernier coup est la foudre en chaîne de l'Éclair en bouteille (Grésille, tout personnage) ;

const FAR_KILL_U := 8.0
const LIGHT_BOSS_MAX_HITS := 3

var water_s := 0.0
var zone_kills := 0
var familiar_elite_kills := 0
var far_kills := 0
var lightning_kills := 0 ## dernier coup = foudre en chaîne de l'Éclair en bouteille (via `eclair_bouteille`, tout personnage)
var clean_floors := 0
var light_boss_kills := 0

var _water_by_player := {} ## id -> secondes
var _floor_touched := false ## un contact a touché un joueur depuis le début de l'étage
var _boss_alive := false
var _boss_hits := 0


func _ready() -> void:
	Events.run_started.connect(func(_resumed: bool) -> void: reset())
	Events.enemy_killed_by.connect(_on_enemy_killed_by)
	Events.player_damaged_by.connect(_on_player_damaged_by)
	Events.floor_started.connect(func(_s: int) -> void: _floor_touched = false)
	Events.floor_cleared.connect(_on_floor_cleared)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_killed.connect(_on_boss_killed)


func reset() -> void:
	water_s = 0.0
	zone_kills = 0
	familiar_elite_kills = 0
	far_kills = 0
	lightning_kills = 0
	clean_floors = 0
	light_boss_kills = 0
	_water_by_player.clear()
	_floor_touched = false
	_boss_alive = false
	_boss_hits = 0


## Mesures de la run en cours (clés de Profile.UNLOCK_ON_*).
func metrics() -> Dictionary:
	return {
		"water_s": water_s, "zone_kills": zone_kills, "familiar_elite_kills": familiar_elite_kills,
		"far_kills": far_kills, "lightning_kills": lightning_kills, "clean_floors": clean_floors, "light_boss_kills": light_boss_kills,
	}


## Mesure active : run en cours, hors mode test.
func _counting() -> bool:
	return RunState.running and not TestMode.active and not Profile.sandbox


func _process(delta: float) -> void:
	if not _counting() or get_tree().paused:
		return
	for n in Players.all():
		var kit: Variant = n.get(&"kit")
		if kit == null or not (&"in_map_water" in kit):
			continue
		if bool(kit.get(&"in_map_water")) or bool(kit.get(&"in_puddle")):
			var id := Players.id_of(n)
			var t := float(_water_by_player.get(id, 0.0)) + delta
			_water_by_player[id] = t
			water_s = maxf(water_s, t)


func _on_enemy_killed_by(player_id: int, enemy: Node2D, pos: Vector2, _tier: int, is_elite: bool) -> void:
	if not _counting() or enemy == null:
		return
	var via: Variant = enemy.get(&"last_hit_via")
	if via == &"zone":
		zone_kills += 1
	elif via == &"familiar" and is_elite:
		familiar_elite_kills += 1
	if via == &"eclair_bouteille":
		lightning_kills += 1
	var killer: Node2D = Players.by_id(player_id) if player_id >= 0 else Players.local()
	if killer != null and pos.distance_to(killer.global_position) > FAR_KILL_U * Balance.UNIT_PX:
		far_kills += 1


func _on_player_damaged_by(_player_id: int, _amount: float, source: Node) -> void:
	if not _counting():
		return
	if source != null and is_instance_valid(source) and source.is_in_group(&"enemies"):
		_floor_touched = true
	if _boss_alive:
		_boss_hits += 1


func _on_floor_cleared(_stage: int) -> void:
	if _counting() and not _floor_touched:
		clean_floors += 1


func _on_boss_spawned(_boss: Node2D, is_floor_boss: bool) -> void:
	if is_floor_boss:
		_boss_alive = true
		_boss_hits = 0


func _on_boss_killed(_boss: Node2D, is_floor_boss: bool) -> void:
	if not is_floor_boss or not _boss_alive:
		return
	_boss_alive = false
	if _counting() and _boss_hits <= LIGHT_BOSS_MAX_HITS:
		light_boss_kills += 1
