class_name CompassStation
extends Node2D
## Boussole de rouille (docs/Ateliers_Chiffres.md §7), atelier gratuit : « Orienter » ouvre une liste de tags
## (Balance.BOUSSOLE_TAGS_SHOWN : les 4 plus présents du build + 2 tirés parmi les autres) ; le tag choisi est garanti sur la
## carte A du premier tirage des Balance.BOUSSOLE_CHARGES prochains petits ou grands coffres (RunState.compass, ChestSession).
## S'active par « interagir » seulement. Un usage par station ; le choix est définitif pour la station.
##
## Apparition : l'agent des ateliers (StationPlan / StationSpawner.make_other) appelle `StageManager.place_compass(pos)`.
## Visuel PROVISOIRE : le levier de salle secrète du biome (props/secret/lever_<biome>_{off,on}), en attendant le prop de
## art/tools/props/_boussole_vitrine.txt (props/compass/compass_{idle,used}.png : même nœud, rien d'autre ne change).

signal used(tag: String)

const SPRITE_DIR := "res://assets/sprites/props/compass/"
const LEVER_DIR := "res://assets/sprites/props/secret/"
const DEFAULT_BIOME := &"terraces"
const RENDER_PX_PER_U := 128.0 / 2.25 ## rendu du levier (art/tools/props/secret_lever_build.py)
const SPRITE_BASE_Y := 0.80
const RANGE_U := 2.2
const TINT := Color(1.0, 0.85, 0.6)

var biome: StringName = DEFAULT_BIOME ## à fixer avant add_child
var is_used := false
var chosen_tag := ""
var _sprite: Sprite2D = null
var _panel: Node = null
var _player: Node2D = null


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"compass_stations")
	_refresh_sprite()


# --- Choix des tags (pur, testé) -----------------------------------------------------------------

## Tags proposés : `Balance.BOUSSOLE_TAGS_BUILD` tags les plus présents dans `owned` (id -> exemplaires ; ordre : présence
## décroissante puis alphabétique), complétés par des tags tirés (avec `rng`) parmi ceux des objets disponibles, jusqu'à
## `Balance.BOUSSOLE_TAGS_SHOWN`. Un tag proposé a toujours au moins un objet disponible dans les tables des coffres.
static func tags_shown(owned: Dictionary, rng: RandomNumberGenerator) -> Array:
	var all_tags := catalog_tags()
	var counts := {}
	for id in owned:
		var n := int(owned[id])
		if n <= 0:
			continue
		for t in ItemDB.get_item(id).get("tags", []):
			var ts := str(t)
			if ts in all_tags:
				counts[ts] = int(counts.get(ts, 0)) + n
	var ranked: Array = counts.keys()
	ranked.sort_custom(func(a, b) -> bool: return (int(counts[a]) > int(counts[b])) or (int(counts[a]) == int(counts[b]) and str(a) < str(b)))
	var out: Array = ranked.slice(0, Balance.BOUSSOLE_TAGS_BUILD)
	var rest: Array = all_tags.filter(func(t) -> bool: return not (t in out))
	rest.sort()
	for i in range(rest.size() - 1, 0, -1): # mélange seedé
		var j := rng.randi_range(0, i)
		var tmp = rest[i]
		rest[i] = rest[j]
		rest[j] = tmp
	while out.size() < Balance.BOUSSOLE_TAGS_SHOWN and not rest.is_empty():
		out.append(rest.pop_front())
	return out


## Tags portés par au moins un objet disponible (débloqué) des tables des coffres.
static func catalog_tags() -> Array:
	var seen := {}
	for q in LootRoller.ORDER:
		for id in LootRoller.available_ids(q):
			for t in ItemDB.get_item(id).get("tags", []):
				seen[str(t)] = true
	var out: Array = seen.keys()
	out.sort()
	return out


# --- Interaction ---------------------------------------------------------------------------------

func _player_node() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D if is_inside_tree() else null
	return _player


func player_near() -> bool:
	var p := _player_node()
	return p != null and p.global_position.distance_to(global_position) <= RANGE_U * Balance.UNIT_PX


func can_interact() -> bool:
	return not is_used and not is_open() and player_near()


func is_open() -> bool:
	return _panel != null and is_instance_valid(_panel)


func interact_label() -> String:
	return "Orienter la boussole"


func interact_state() -> Dictionary:
	return {"visible": can_interact(), "enabled": true, "label": interact_label(), "hold_s": 0.0}


func interact_priority() -> int:
	return 2


func interact() -> bool:
	if not can_interact():
		return false
	return open_panel()


func open_panel() -> bool:
	if is_used or is_open():
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([RunState.run_seed, "boussole", RunState.stage])
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	_panel = CompassPanel.new()
	host.add_child(_panel)
	_panel.open(tags_shown(RunState.items, rng), RunState.compass)
	_panel.chosen.connect(choose)
	return true


## Fixe le tag (RunState.compass, BOUSSOLE_CHARGES charges) et épuise la station. Faux si déjà utilisée.
func choose(tag: String) -> bool:
	if is_used or tag == "":
		return false
	is_used = true
	chosen_tag = tag
	RunState.compass_set(tag)
	remove_from_group(&"interactable")
	_refresh_sprite()
	Audio.play(&"chest.lock", global_position)
	Events.station_used.emit(&"boussole", &"orienter", [], [tag], 0.0)
	used.emit(tag)
	return true


# --- Sauvegarde ----------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"x": position.x, "y": position.y, "used": is_used, "tag": chosen_tag}


## Restauration (après add_child) : une station déjà utilisée reste éteinte, sans signal ni son.
func from_dict(d: Dictionary) -> void:
	if bool(d.get("used", false)):
		is_used = true
		chosen_tag = String(d.get("tag", ""))
		remove_from_group(&"interactable")
		_refresh_sprite()


# --- Visuel --------------------------------------------------------------------------------------

func _refresh_sprite() -> void:
	var state := "used" if is_used else "idle"
	var path := "%scompass_%s.png" % [SPRITE_DIR, state]
	var tint := Color.WHITE
	var px_per_u := 90.51
	if not ResourceLoader.exists(path):
		path = "%slever_%s_%s.png" % [LEVER_DIR, biome, "on" if is_used else "off"]
		if not ResourceLoader.exists(path):
			path = "%slever_%s_%s.png" % [LEVER_DIR, DEFAULT_BIOME, "on" if is_used else "off"]
		tint = TINT
		px_per_u = RENDER_PX_PER_U
	if not ResourceLoader.exists(path):
		return
	if _sprite != null:
		_sprite.queue_free()
	_sprite = Sprite2D.new()
	_sprite.name = &"Sprite"
	var tex := load(path) as Texture2D
	_sprite.texture = tex
	_sprite.self_modulate = tint
	_sprite.scale = Iso.UNSQUASH * (64.0 / px_per_u)
	_sprite.offset = Vector2(0.0, -float(tex.get_height()) * (SPRITE_BASE_Y - 0.5))
	add_child(_sprite)
