class_name AmbientEvents
extends Node2D
## Événement ambiant de la carte (clé `ambient_event` de data/maps/<id>.json, docs/Design_Variantes_B.md §7) :
## {"threshold_difficulty", "name", "effect" (texte de design), "effects": [{"type", ...}]}. Enfant de
## l'AmbianceManager (« AmbientEvents ») : il lit la clé au chargement de l'étage, crée un AmbientEffect par
## entrée de `effects` (un script par type, table TYPES) et les démarre / arrête quand la difficulté franchit leur
## seuil (seuil de l'événement, ou palier supérieur « tier » : Furieux, Cataclysme…). Visuel et sonore
## seulement, aucun effet de jeu.
##
## Coût : un effet inactif ne fait rien (setup léger, aucun nœud) ; tick() ne compare que des seuils tant que
## rien n'est actif. Les nœuds créés par un effet (pluie locale, roue animée…) sont ses enfants ou ceux de la
## carte et sont libérés à stop() ; changer d'étage arrête tout (clear()).

const TYPES := {
	"flood": preload("res://scripts/ambiance/events/fx_flood.gd"),
	"decor_lightning": preload("res://scripts/ambiance/events/fx_decor_lightning.gd"),
	"prop_pulse": preload("res://scripts/ambiance/events/fx_prop_pulse.gd"),
	"light_waves": preload("res://scripts/ambiance/events/fx_light_waves.gd"),
	"shaft_veil": preload("res://scripts/ambiance/events/fx_shaft_veil.gd"),
	"gusts": preload("res://scripts/ambiance/events/fx_gusts.gd"),
	"rain_column": preload("res://scripts/ambiance/events/fx_rain_column.gd"),
	"local_rain": preload("res://scripts/ambiance/events/fx_local_rain.gd"),
	"prop_anim": preload("res://scripts/ambiance/events/fx_prop_anim.gd"),
}

var mgr: AmbianceManager = null
var map: Node2D = null
var map_id := ""
var event_name := "" ## `ambient_event.name`, "" si la carte n'en a pas
var threshold := 99.0 ## `ambient_event.threshold_difficulty`
var effects: Array[AmbientEffect] = []
var unknown_types: PackedStringArray = PackedStringArray() ## types de `effects` sans script (tests)
var difficulty := 1.0
var _active_n := 0
## Vérification à l'œil (À RETIRER OU MASQUER AVANT LA SORTIE) : le forçage de D d'ambiance vit dans TestMode
## (`TestMode.ambient_d`, réglé par le panneau du mode test, onglet Cartes, ou par `-- --ambient-d=<D>`). Il impose une
## difficulté minimale aux SEULS événements ambiants (aucun effet de jeu : spawns, PV, or suivent toujours RunState).


func _ready() -> void:
	name = &"AmbientEvents"
	z_index = 0


## Lit l'événement de `m` (StageMap, méta `map_id`). Même carte qu'avant : les effets actifs sont rafraîchis
## (lumières de la carte reconstruites par l'AmbianceManager) sans repartir de zéro ; autre carte : tout est
## arrêté puis relu.
func bind(p_mgr: AmbianceManager, m: Node2D) -> void:
	mgr = p_mgr
	var id := String(m.get_meta(&"map_id", "")) if m != null else ""
	if m != null and m == map and id == map_id:
		refresh()
		return
	clear()
	map = m
	map_id = id
	if m == null or id == "":
		return
	var ev := read_event(id)
	if ev.is_empty():
		return
	event_name = String(ev.get("name", ""))
	threshold = float(ev.get("threshold_difficulty", 99.0))
	var list: Variant = ev.get("effects", [])
	if not list is Array:
		return
	for d in list:
		if not d is Dictionary:
			continue
		var t := String((d as Dictionary).get("type", ""))
		if not TYPES.has(t):
			unknown_types.append(t)
			continue
		var fx: AmbientEffect = (TYPES[t] as GDScript).new()
		fx.init(t, d, AmbientEffect.threshold_of(d, threshold), mgr, m)
		fx.setup()
		effects.append(fx)


## `ambient_event` du JSON de la carte ({} si absent).
static func read_event(id: String) -> Dictionary:
	var path := "res://data/maps/%s.json" % id
	if id == "" or not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and (data as Dictionary).get("ambient_event") is Dictionary:
		return (data as Dictionary)["ambient_event"]
	return {}


## Arrête et oublie tout (changement d'étage, carte retirée).
func clear() -> void:
	for fx in effects:
		if fx.active:
			fx.active = false
			fx.stop()
	effects.clear()
	unknown_types.clear()
	_active_n = 0
	map = null
	map_id = ""
	event_name = ""
	threshold = 99.0


## Reconstruction de l'ambiance sur la même carte : les effets actifs relisent leurs cibles.
func refresh() -> void:
	for fx in effects:
		if fx.active:
			fx.refresh()


func on_quality() -> void:
	for fx in effects:
		if fx.active:
			fx.on_quality()


## Appelé à chaque image par l'AmbianceManager : démarre / arrête au franchissement des seuils, fait vivre les
## effets actifs.
func tick(delta: float, D: float) -> void:
	var forced_d := TestMode.ambient_forced_d()
	if forced_d > 0.0:
		D = maxf(D, forced_d)
	difficulty = D
	if effects.is_empty():
		return
	if map == null or not is_instance_valid(map) or not map.is_inside_tree():
		clear() # carte libérée sans nouveau bind (fin de partie) : coupure propre
		return
	var n := 0
	for fx in effects:
		var want := D >= fx.threshold
		if want != fx.active:
			fx.active = want
			if want:
				fx.start_count += 1
				fx.start()
			else:
				fx.stop()
		if fx.active:
			n += 1
			fx.process(delta)
	_active_n = n


## Vrai si l'événement de la carte est en cours (D >= seuil de l'événement).
func event_active(D: float) -> bool:
	return event_name != "" and maxf(D, TestMode.ambient_forced_d()) >= threshold


func active_count() -> int:
	return _active_n


## Premier effet de ce type (tests), ou null.
func find(t: String) -> AmbientEffect:
	for fx in effects:
		if fx.type == t:
			return fx
	return null


## Assets Codex attendus et absents, tous effets confondus.
func missing_assets() -> PackedStringArray:
	var out := PackedStringArray()
	for fx in effects:
		for m in fx.missing:
			if not out.has(m):
				out.append(m)
	return out
