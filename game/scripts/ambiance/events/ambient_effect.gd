class_name AmbientEffect
extends RefCounted
## Un effet d'événement ambiant de carte (clé `ambient_event.effects` de data/maps/<id>.json), piloté par
## AmbientEvents. Visuel / sonore seulement : aucun effet de jeu.
##
## Cycle de vie (tout est appelé par AmbientEvents, jamais par l'effet lui-même) :
## - setup() : au chargement de l'étage. Doit rester léger (préparer des données, jamais créer de nœud par
##   image) ; un effet inactif ne coûte rien ensuite ;
## - start() quand `RunState.difficulty()` atteint `threshold` (une seule fois tant que D reste au-dessus) ;
## - process(delta) à chaque image tant que l'effet est actif (aucune allocation) ;
## - stop() quand D redescend, au changement d'étage ou à la reconstruction de l'ambiance : tout ce que start()
##   a créé est libéré et tout ce qu'il a modifié est rétabli ;
## - on_quality() : palier de qualité changé (Bas / Moyen / Haut) pendant que l'effet est actif ;
## - refresh() : ambiance reconstruite sur la même carte pendant que l'effet est actif.
##
## Champs communs d'une entrée `effects` : {"type", "tier" (nom de palier, optionnel) ou "threshold_difficulty"
## (optionnel ; défaut = seuil de l'événement)}, puis les paramètres propres à chaque type (voir chaque fx_*.gd).

const U := 64.0
## D minimale de chaque palier de la jauge (Balance / docs/Design_Etages.md) : Calme, Tendu, Hostile, Furieux, Cataclysme.
const TIER_MIN_D := {"Calme": 1.0, "Tendu": 1.5, "Hostile": 2.5, "Furieux": 4.0, "Cataclysme": 6.0}

var type := ""
var def: Dictionary = {}
var threshold := 99.0
var mgr: AmbianceManager = null
var map: Node2D = null
var active := false
var start_count := 0 ## nombre de start() (tests : idempotence)
## Assets Codex attendus et absents (chemins / ids) : l'effet passe en repli discret, la liste remonte au rapport.
var missing: PackedStringArray = PackedStringArray()


## Seuil d'un effet : "tier" (nom de palier) > "threshold_difficulty" > seuil de l'événement.
static func threshold_of(d: Dictionary, event_threshold: float) -> float:
	var t := String(d.get("tier", ""))
	if TIER_MIN_D.has(t):
		return float(TIER_MIN_D[t])
	return float(d.get("threshold_difficulty", event_threshold))


func init(p_type: String, p_def: Dictionary, p_threshold: float, p_mgr: AmbianceManager, p_map: Node2D) -> void:
	type = p_type
	def = p_def
	threshold = p_threshold
	mgr = p_mgr
	map = p_map


func setup() -> void:
	pass


func start() -> void:
	pass


func stop() -> void:
	pass


func process(_delta: float) -> void:
	pass


func on_quality() -> void:
	pass


## Ambiance reconstruite sur la même carte (lumières de la carte refaites, eau rebâtie) : défaut stop() + start().
func refresh() -> void:
	stop()
	start()


## État lisible (tests, panneau de debug).
func describe() -> Dictionary:
	return {"type": type, "active": active, "threshold": threshold, "missing": missing}


# --- Aides communes ------------------------------------------------------------

## Palier de qualité courant : 0 Bas, 1 Moyen, 2 Haut.
static func tier() -> int:
	return clampi(int(Quality.tier), 0, 2)


## Valeur par palier : `v` peut être un nombre (identique partout) ou un tableau [Bas, Moyen, Haut].
static func per_tier(v: Variant, fallback: float = 0.0) -> float:
	if v is Array:
		var a: Array = v
		if a.is_empty():
			return fallback
		return float(a[mini(tier(), a.size() - 1)])
	if v == null:
		return fallback
	return float(v)


## Intervalle [min, max] d'un paramètre (tableau de 2 nombres), tiré au hasard.
static func rand_range_of(v: Variant, fallback: Vector2) -> float:
	var r := fallback
	if v is Array and (v as Array).size() >= 2:
		r = Vector2(float(v[0]), float(v[1]))
	return randf_range(r.x, r.y)


## Props fixes de la carte (StageMap._build_props_fixed : Sprite2D « FP_<nom>_<x>_<y> » sous Blocks).
func fixed_props(prop_name: String) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	var root := map.get_node_or_null(^"Blocks") if map != null else null
	if root == null:
		return out
	var prefix := "FP_%s_" % prop_name
	for c in root.get_children():
		if c is Sprite2D and String(c.name).begins_with(prefix):
			out.append(c as Sprite2D)
	return out


## Nœud d'émission d'un sprite (NormalMaps.apply_to_sprite, masque `_e`), ou null.
static func emission_of(n: Node) -> CanvasItem:
	return n.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE)) as CanvasItem if n != null else null


func note_missing(what: String) -> void:
	if not missing.has(what):
		missing.append(what)


static func audio() -> Node:
	var ml := Engine.get_main_loop() as SceneTree
	return ml.root.get_node_or_null(^"Audio") if ml != null else null
